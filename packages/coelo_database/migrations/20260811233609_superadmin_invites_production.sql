-- Production Superadmin invitations.
-- Clear invitation tokens are returned once by command RPCs and are never persisted.

insert into public.platform_permissions(
  code, module_code, screen_code, action_code, description, risk_level, requires_mfa, status,
  module_label, screen_label, action_label
) values
  ('platform.invites.read', 'platform', 'invites', 'read',
   'Read the platform invitation directory.', 'normal', false, 'active',
   'Plataforma', 'Convites', 'Visualizar'),
  ('platform.invites.manage', 'platform', 'invites', 'manage',
   'Issue, resend and revoke platform invitations.', 'high', true, 'active',
   'Plataforma', 'Convites', 'Gerenciar')
on conflict (code) do update set
  module_code = excluded.module_code,
  screen_code = excluded.screen_code,
  action_code = excluded.action_code,
  description = excluded.description,
  risk_level = excluded.risk_level,
  requires_mfa = excluded.requires_mfa,
  module_label = excluded.module_label,
  screen_label = excluded.screen_label,
  action_label = excluded.action_label,
  status = 'active',
  updated_at = now();

insert into public.platform_role_permissions(role_id, permission_id, effect, conditions_json, status, revoked_at)
select role_record.id, permission_record.id, 'allow', '{}'::jsonb, 'active', null
from public.platform_roles role_record
cross join public.platform_permissions permission_record
where role_record.code = 'owner'
  and role_record.status = 'active'
  and permission_record.code in ('platform.invites.read', 'platform.invites.manage')
on conflict (role_id, permission_id) do update set
  effect = 'allow', conditions_json = '{}'::jsonb, status = 'active', revoked_at = null;

alter table public.invitations
  add column if not exists target_kind text,
  add column if not exists profile_id uuid,
  add column if not exists channels text[] not null default array['link']::text[],
  add column if not exists version bigint not null default 1,
  add column if not exists validity_hours integer not null default 48,
  add column if not exists updated_at timestamptz not null default now();

update public.invitations
set validity_hours = least(
  720,
  greatest(1, ceil(extract(epoch from (expires_at - created_at)) / 3600)::integer)
)
where validity_hours is null or validity_hours not between 1 and 720;

update public.invitations invitation
set target_kind = case when invitation.target_person_id is not null then 'person' else 'email' end
where invitation.target_kind is null;

update public.invitations invitation
set profile_id = (
  select role_candidate.id
  from public.institution_roles role_candidate
  where lower(role_candidate.code) = lower(invitation.role_code)
    and role_candidate.status = 'active'
    and (role_candidate.institution_id = invitation.institution_id or role_candidate.institution_id is null)
  order by (role_candidate.institution_id is not null) desc
  limit 1
)
where invitation.profile_id is null and invitation.role_code is not null;

update public.invitations
set status = case when invitation_state in ('pending', 'accepted')
  then 'active'::public.record_status else 'inactive'::public.record_status end;

do $$
begin
  if exists (
    select 1 from public.invitations invitation
    where invitation.target_kind is null
       or invitation.profile_id is null
       or invitation.invited_by is null
  ) then
    raise exception 'existing invitations require target, profile and issuer remediation before production hardening';
  end if;
end $$;

alter table public.invitations
  alter column target_kind set not null,
  alter column profile_id set not null,
  alter column invited_by set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.invitations'::regclass
      and conname = 'invitations_profile_id_fkey'
  ) then
    alter table public.invitations
      add constraint invitations_profile_id_fkey
      foreign key (profile_id) references public.institution_roles(id) on delete restrict;
  end if;
end $$;

alter table public.invitations
  drop constraint if exists invitations_target_check,
  drop constraint if exists invitations_send_count_check,
  drop constraint if exists invitations_target_kind_check,
  drop constraint if exists invitations_target_shape_check,
  drop constraint if exists invitations_channels_check,
  drop constraint if exists invitations_scope_shape_check,
  drop constraint if exists invitations_token_hash_check,
  drop constraint if exists invitations_version_check,
  drop constraint if exists invitations_validity_hours_check,
  drop constraint if exists invitations_lifecycle_check;

alter table public.invitations
  add constraint invitations_target_kind_check
    check (target_kind in ('person', 'email')),
  add constraint invitations_target_shape_check check (
    (target_kind = 'person' and target_person_id is not null and target_contact_hash is null)
    or
    (target_kind = 'email' and target_person_id is null and target_contact_hash ~ '^[0-9a-f]{64}$'
      and masked_destination is not null and btrim(masked_destination) <> '')
  ),
  add constraint invitations_channels_check check (
    cardinality(channels) between 1 and 2
    and channels <@ array['email', 'link']::text[]
    and (cardinality(channels) = 1 or channels[1] <> channels[2])
  ),
  add constraint invitations_scope_shape_check check (
    (scope_kind = 'institution' and institution_id is not null and unit_id is null and group_id is null)
    or (scope_kind = 'unit' and institution_id is not null and unit_id is not null and group_id is null)
    or (scope_kind = 'group' and institution_id is not null and unit_id is not null and group_id is not null)
  ),
  add constraint invitations_token_hash_check check (token_hash ~ '^[0-9a-f]{64}$'),
  add constraint invitations_send_count_check check (send_count >= 0),
  add constraint invitations_version_check check (version > 0),
  add constraint invitations_validity_hours_check check (validity_hours between 1 and 720),
  add constraint invitations_lifecycle_check check (
    (invitation_state = 'pending' and accepted_at is null and accepted_by is null and revoked_at is null and status = 'active')
    or (invitation_state = 'expired' and accepted_at is null and accepted_by is null and revoked_at is null and status = 'inactive')
    or (invitation_state = 'revoked' and accepted_at is null and accepted_by is null and revoked_at is not null and status = 'inactive')
    or (invitation_state = 'accepted' and accepted_at is not null and accepted_by is not null and revoked_at is null and status = 'active')
  );

create or replace function app_private.validate_production_invitation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  profile_record public.institution_roles%rowtype;
  unit_institution_id uuid;
  group_institution_id uuid;
  group_unit_id uuid;
begin
  if new.target_kind is null then
    new.target_kind := case when new.target_person_id is not null then 'person' else 'email' end;
  end if;
  if new.profile_id is null and new.role_code is not null then
    select role_candidate.* into profile_record
    from public.institution_roles role_candidate
    where lower(role_candidate.code) = lower(new.role_code)
      and role_candidate.status = 'active'
      and (role_candidate.institution_id = new.institution_id or role_candidate.institution_id is null)
    order by (role_candidate.institution_id is not null) desc
    limit 1;
    new.profile_id := profile_record.id;
  else
    select role_candidate.* into profile_record
    from public.institution_roles role_candidate where role_candidate.id = new.profile_id;
  end if;
  if profile_record.id is null or profile_record.status <> 'active'
     or (profile_record.institution_id is not null and profile_record.institution_id <> new.institution_id)
     or app_private.access_scope_rank(
       case when new.group_id is not null then 'group'
         when new.unit_id is not null then 'unit' else 'institution' end
     ) > app_private.access_scope_rank(profile_record.max_scope_kind) then
    raise invalid_parameter_value using message = 'invalid invitation profile';
  end if;
  new.role_code := profile_record.code;

  if new.unit_id is not null then
    select unit_record.institution_id into unit_institution_id
    from public.units unit_record where unit_record.id = new.unit_id and unit_record.status = 'active';
    if unit_institution_id is distinct from new.institution_id then
      raise invalid_parameter_value using message = 'invalid invitation hierarchy';
    end if;
  end if;
  if new.group_id is not null then
    select group_record.institution_id, group_record.unit_id
      into group_institution_id, group_unit_id
    from public.groups group_record where group_record.id = new.group_id and group_record.status = 'active';
    if group_institution_id is distinct from new.institution_id
       or group_unit_id is distinct from new.unit_id then
      raise invalid_parameter_value using message = 'invalid invitation hierarchy';
    end if;
  end if;
  if not exists (
    select 1 from public.institutions institution_record
    where institution_record.id = new.institution_id and institution_record.status = 'active'
  ) then
    raise invalid_parameter_value using message = 'invalid invitation hierarchy';
  end if;
  if new.target_person_id is not null and not exists (
    select 1 from public.people person_record
    where person_record.id = new.target_person_id
      and person_record.status = 'active' and person_record.person_type = 'adult'
  ) then
    raise invalid_parameter_value using message = 'invalid invitation recipient';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists invitations_production_validate on public.invitations;
create trigger invitations_production_validate
before insert or update on public.invitations
for each row execute function app_private.validate_production_invitation();

drop index if exists public.invitations_active_person_institution_uidx;
drop index if exists public.invitations_active_contact_institution_uidx;
create unique index invitations_active_person_scope_profile_uidx
  on public.invitations(target_person_id, institution_id, coalesce(unit_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), profile_id)
  where target_person_id is not null and invitation_state = 'pending';
create unique index invitations_active_email_scope_profile_uidx
  on public.invitations(target_contact_hash, institution_id, coalesce(unit_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(group_id, '00000000-0000-0000-0000-000000000000'::uuid), profile_id)
  where target_contact_hash is not null and invitation_state = 'pending';
create index invitations_directory_cursor_idx
  on public.invitations(created_at desc, id desc);
create index invitations_directory_filters_idx
  on public.invitations(institution_id, invitation_state, created_at desc);
create index invitations_profile_idx on public.invitations(profile_id, created_at desc);
create index if not exists invitations_invited_by_idx on public.invitations(invited_by);

create table app_private.superadmin_invite_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete restrict,
  command_kind text not null check (command_kind in ('issue', 'resend', 'revoke')),
  invitation_id uuid not null references public.invitations(id) on delete cascade,
  payload_hash bytea not null,
  result_json jsonb not null,
  created_at timestamptz not null default now()
);

create table app_private.superadmin_invite_email_outbox (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.invitations(id) on delete cascade,
  destination_hash text not null check (destination_hash ~ '^[0-9a-f]{64}$'),
  masked_destination text not null check (btrim(masked_destination) <> ''),
  channel text not null default 'email' check (channel = 'email'),
  token_hash_snapshot text not null check (token_hash_snapshot ~ '^[0-9a-f]{64}$'),
  state text not null default 'pending' check (state in ('pending', 'sent', 'failed', 'cancelled')),
  attempts integer not null default 0 check (attempts >= 0),
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  available_at timestamptz not null default now(),
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(invitation_id, token_hash_snapshot, channel)
);
create index superadmin_invite_email_outbox_pending_idx
  on app_private.superadmin_invite_email_outbox(available_at, id) where state = 'pending';
create index superadmin_invite_email_outbox_invitation_latest_idx
  on app_private.superadmin_invite_email_outbox(invitation_id, created_at desc, id desc);
create index if not exists audit_logs_invitation_object_timeline_idx
  on audit.audit_logs(object_id, occurred_at, id)
  where object_type = 'invitation' and action_code in ('invite.issue','invite.resend','invite.revoke');
comment on table app_private.superadmin_invite_email_outbox is
  'Hash-only delivery intent. A provider worker remains disabled until canonical encrypted destination/token infrastructure exists; pending is never reported as sent.';
comment on column app_private.superadmin_invite_email_outbox.token_hash_snapshot is
  'SHA-256 verification material only; never a recoverable invitation token.';
revoke all on table app_private.superadmin_invite_command_receipts from public, anon, authenticated;
revoke all on table app_private.superadmin_invite_email_outbox from public, anon, authenticated;

create or replace function app_private.superadmin_invite_require(p_permission text, p_require_aal2 boolean)
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare actor_person_id uuid;
begin
  if (select auth.uid()) is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  actor_person_id := app_private.current_person_id();
  if actor_person_id is null or not app_private.has_platform_permission(p_permission) then
    raise insufficient_privilege using message = p_permission || ' required';
  end if;
  if p_require_aal2 and not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message = 'MFA AAL2 required';
  end if;
  return actor_person_id;
end $$;

create or replace function app_private.superadmin_invite_validate_channels(p_channels text[])
returns text[] language plpgsql immutable security invoker set search_path = ''
as $$
declare normalized text[];
begin
  select coalesce(array_agg(distinct lower(btrim(value)) order by lower(btrim(value))), '{}'::text[])
    into normalized from unnest(coalesce(p_channels, '{}'::text[])) value;
  if cardinality(normalized) not between 1 and 2
     or not normalized <@ array['email', 'link']::text[] then
    raise invalid_parameter_value using message = 'invalid invitation channels';
  end if;
  return normalized;
end $$;

create or replace function app_private.superadmin_invite_mask_email(p_email text)
returns text language sql immutable security invoker set search_path = ''
as $$
  select left(split_part(p_email, '@', 1), 1) || '***@' || split_part(p_email, '@', 2)
$$;

create or replace function app_private.superadmin_invite_payload_hash(p_payload jsonb)
returns bytea language sql immutable security invoker set search_path = ''
as $$
  select extensions.digest(convert_to(p_payload::text, 'UTF8'), 'sha256')
$$;

create or replace function app_private.superadmin_invite_public_origin()
returns text language sql immutable security definer set search_path = ''
as $$
  select 'https://app.coelo.me'::text
$$;
comment on function app_private.superadmin_invite_public_origin() is
  'Allowlisted production origin for one-time invitation links. Change only through a reviewed migration; never from client input or a mutable request GUC.';

create or replace view app_private.superadmin_invite_read_model
with (security_invoker = true)
as
  select invitation.id as invite_id, jsonb_build_object(
    'invite_id', invitation.id,
    'status', case when invitation.invitation_state = 'pending' and invitation.expires_at <= now()
      then 'expired' else invitation.invitation_state::text end,
    'channels', to_jsonb(invitation.channels),
    'scope_kind', invitation.scope_kind,
    'institution_id', invitation.institution_id,
    'unit_id', invitation.unit_id,
    'group_id', invitation.group_id,
    'scope_label', concat_ws(' / ', institution_record.public_name, unit_record.name, group_record.name),
    'profile_id', invitation.profile_id,
    'profile_label', profile_record.name,
    'target_person_id', invitation.target_person_id,
    'recipient_label', coalesce(recipient.display_name, invitation.masked_destination),
    'recipient_masked', coalesce(invitation.masked_destination, delivery.masked_destination),
    'issuer_person_id', invitation.invited_by,
    'issuer_label', issuer.display_name,
    'email_delivery_status', case
      when not ('email' = any(invitation.channels)) then 'not_requested'
      when delivery.state = 'pending' then 'queued'
      when delivery.state = 'sent' then 'sent'
      when delivery.state = 'failed' then 'failed'
      else 'not_requested'
    end,
    'management_version', invitation.version,
    'created_at', invitation.created_at,
    'expires_at', invitation.expires_at,
    'accepted_at', invitation.accepted_at,
    'revoked_at', invitation.revoked_at,
    'timeline', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'label', case audit_record.action_code
            when 'invite.issue' then 'Convite emitido'
            when 'invite.resend' then 'Convite reenviado'
            when 'invite.revoke' then 'Convite revogado'
            else 'Convite atualizado'
          end,
          'occurred_at', audit_record.occurred_at
        ) order by audit_record.occurred_at, audit_record.id
      )
      from audit.audit_logs audit_record
      where audit_record.object_type = 'invitation'
        and audit_record.object_id = invitation.id
        and audit_record.action_code in ('invite.issue','invite.resend','invite.revoke')
    ), '[]'::jsonb)
  ) as payload
  from public.invitations invitation
  join public.institutions institution_record on institution_record.id = invitation.institution_id
  left join public.units unit_record on unit_record.id = invitation.unit_id
  left join public.groups group_record on group_record.id = invitation.group_id
  join public.institution_roles profile_record on profile_record.id = invitation.profile_id
  join public.people issuer on issuer.id = invitation.invited_by
  left join public.people recipient on recipient.id = invitation.target_person_id
  left join lateral (
    select outbox.state, outbox.masked_destination
    from app_private.superadmin_invite_email_outbox outbox
    where outbox.invitation_id = invitation.id
    order by outbox.created_at desc, outbox.id desc
    limit 1
  ) delivery on true
;
revoke all on table app_private.superadmin_invite_read_model from public, anon, authenticated;

create or replace function app_private.superadmin_invite_json(p_invite_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select read_model.payload
  from app_private.superadmin_invite_read_model read_model
  where read_model.invite_id = p_invite_id
$$;

create or replace function app_private.superadmin_invite_replay(
  p_request_id uuid, p_actor_person_id uuid, p_command_kind text, p_payload_hash bytea
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare receipt app_private.superadmin_invite_command_receipts%rowtype;
begin
  select * into receipt from app_private.superadmin_invite_command_receipts
  where request_id = p_request_id;
  if receipt.request_id is null then return null; end if;
  if receipt.actor_person_id <> p_actor_person_id
     or receipt.command_kind <> p_command_kind
     or receipt.payload_hash <> p_payload_hash then
    raise invalid_parameter_value using message = 'idempotency key conflict';
  end if;
  return receipt.result_json || jsonb_build_object('link', null, 'replayed', true);
end $$;

create or replace function app_private.superadmin_invite_directory(
  p_search text default '', p_statuses text[] default '{}', p_channels text[] default '{}',
  p_institution_ids uuid[] default '{}', p_unit_ids uuid[] default '{}',
  p_group_ids uuid[] default '{}', p_profile_ids uuid[] default '{}',
  p_created_from timestamptz default null, p_created_to timestamptz default null,
  p_limit integer default 25, p_offset integer default 0,
  p_sort text default 'created_at', p_sort_ascending boolean default false
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.superadmin_invite_require('platform.invites.read', false);
  if p_limit is null or p_limit not between 1 and 100
     or p_offset is null or p_offset not between 0 and 10000
     or p_sort is null or p_sort not in ('created_at', 'expires_at', 'recipient', 'status')
     or p_sort_ascending is null
     or length(coalesce(p_search, '')) > 200
     or p_statuses is null or cardinality(p_statuses) > 4
     or p_channels is null or cardinality(p_channels) > 2
     or p_institution_ids is null or cardinality(p_institution_ids) > 100
     or p_unit_ids is null or cardinality(p_unit_ids) > 100
     or p_group_ids is null or cardinality(p_group_ids) > 100
     or p_profile_ids is null or cardinality(p_profile_ids) > 100
     or exists (select 1 from unnest(p_statuses) value where value is null or value not in ('pending','accepted','expired','revoked'))
     or exists (select 1 from unnest(p_channels) value where value is null or value not in ('email','link'))
     or exists (select 1 from unnest(p_institution_ids) value where value is null)
     or exists (select 1 from unnest(p_unit_ids) value where value is null)
     or exists (select 1 from unnest(p_group_ids) value where value is null)
     or exists (select 1 from unnest(p_profile_ids) value where value is null)
     or (p_created_from is not null and p_created_to is not null and p_created_from >= p_created_to) then
    raise invalid_parameter_value using message = 'invalid invitation directory filters';
  end if;
  with filtered as (
    select invitation.id,
      case when invitation.invitation_state = 'pending' and invitation.expires_at <= now()
        then 'expired' else invitation.invitation_state::text end effective_status,
      coalesce(recipient.display_name, invitation.masked_destination, '') recipient_sort,
      invitation.created_at, invitation.expires_at
    from public.invitations invitation
    left join public.people recipient on recipient.id = invitation.target_person_id
    join public.institutions institution_record on institution_record.id = invitation.institution_id
    join public.institution_roles profile_record on profile_record.id = invitation.profile_id
    where (coalesce(btrim(p_search), '') = ''
      or recipient.display_name ilike '%' || btrim(p_search) || '%'
      or invitation.masked_destination ilike '%' || btrim(p_search) || '%'
      or institution_record.public_name ilike '%' || btrim(p_search) || '%'
      or profile_record.name ilike '%' || btrim(p_search) || '%')
      and (cardinality(p_statuses) = 0 or (case when invitation.invitation_state = 'pending' and invitation.expires_at <= now()
        then 'expired' else invitation.invitation_state::text end) = any(p_statuses))
      and (cardinality(p_channels) = 0 or invitation.channels && p_channels)
      and (cardinality(p_institution_ids) = 0 or invitation.institution_id = any(p_institution_ids))
      and (cardinality(p_unit_ids) = 0 or invitation.unit_id = any(p_unit_ids))
      and (cardinality(p_group_ids) = 0 or invitation.group_id = any(p_group_ids))
      and (cardinality(p_profile_ids) = 0 or invitation.profile_id = any(p_profile_ids))
      and (p_created_from is null or invitation.created_at >= p_created_from)
      and (p_created_to is null or invitation.created_at < p_created_to)
  ), ranked as (
    select filtered.*, row_number() over (order by
      case when p_sort = 'created_at' and p_sort_ascending then created_at end asc,
      case when p_sort = 'created_at' and not p_sort_ascending then created_at end desc,
      case when p_sort = 'expires_at' and p_sort_ascending then expires_at end asc,
      case when p_sort = 'expires_at' and not p_sort_ascending then expires_at end desc,
      case when p_sort = 'recipient' and p_sort_ascending then recipient_sort end asc,
      case when p_sort = 'recipient' and not p_sort_ascending then recipient_sort end desc,
      case when p_sort = 'status' and p_sort_ascending then effective_status end asc,
      case when p_sort = 'status' and not p_sort_ascending then effective_status end desc,
      id desc
    ) as ordinal from filtered
  ), page as (
    select * from ranked
    order by ordinal
    limit p_limit offset p_offset
  )
  select jsonb_build_object(
    'items', coalesce(jsonb_agg(read_model.payload order by page.ordinal), '[]'::jsonb),
    'total_count', (select count(*) from filtered)
  ) into result
  from page
  join app_private.superadmin_invite_read_model read_model on read_model.invite_id = page.id;
  return result;
end $$;

create or replace function app_private.superadmin_invite_options(
  p_search text default '', p_institution_id uuid default null,
  p_unit_id uuid default null, p_group_id uuid default null, p_limit integer default 50
) returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.superadmin_invite_require('platform.invites.read', false);
  if p_limit is null or p_limit not between 1 and 100 or length(coalesce(p_search, '')) > 200 then
    raise invalid_parameter_value using message = 'invalid options input';
  end if;
  if (p_institution_id is null and (p_unit_id is not null or p_group_id is not null))
     or (p_unit_id is null and p_group_id is not null) then
    raise invalid_parameter_value using message = 'invalid invitation hierarchy';
  end if;
  if p_institution_id is not null and not exists (
    select 1 from public.institutions institution_record
    where institution_record.id = p_institution_id and institution_record.status = 'active'
  ) then raise invalid_parameter_value using message = 'invalid invitation hierarchy'; end if;
  if p_unit_id is not null and not exists (
    select 1 from public.units unit_record where unit_record.id = p_unit_id
      and unit_record.institution_id = p_institution_id and unit_record.status = 'active'
  ) then raise invalid_parameter_value using message = 'invalid invitation hierarchy'; end if;
  if p_group_id is not null and not exists (
    select 1 from public.groups group_record where group_record.id = p_group_id
      and group_record.institution_id = p_institution_id
      and group_record.unit_id is not distinct from p_unit_id and group_record.status = 'active'
  ) then raise invalid_parameter_value using message = 'invalid invitation hierarchy'; end if;
  select jsonb_build_object(
    'scopes', coalesce((select jsonb_agg(scope_record.item order by scope_record.label)
      from (
        select jsonb_build_object(
          'scope_kind','institution','scope_id',institution_record.id,'label',institution_record.public_name,
          'institution_id',institution_record.id,'unit_id',null,'group_id',null
        ) item, institution_record.public_name label
        from public.institutions institution_record
        where institution_record.status = 'active' and p_institution_id is null
          and (coalesce(btrim(p_search),'') = '' or institution_record.public_name ilike '%'||btrim(p_search)||'%')
        union all
        select jsonb_build_object(
          'scope_kind','unit','scope_id',unit_record.id,'label',unit_record.name,
          'institution_id',unit_record.institution_id,'unit_id',unit_record.id,'group_id',null
        ), unit_record.name
        from public.units unit_record where unit_record.status = 'active'
          and unit_record.institution_id = p_institution_id and p_unit_id is null
          and (coalesce(btrim(p_search),'') = '' or unit_record.name ilike '%'||btrim(p_search)||'%')
        union all
        select jsonb_build_object(
          'scope_kind','group','scope_id',group_record.id,'label',group_record.name,
          'institution_id',group_record.institution_id,'unit_id',group_record.unit_id,'group_id',group_record.id
        ), group_record.name
        from public.groups group_record where group_record.status = 'active'
          and group_record.institution_id = p_institution_id and group_record.unit_id = p_unit_id
          and (p_group_id is null or group_record.id = p_group_id)
          and (coalesce(btrim(p_search),'') = '' or group_record.name ilike '%'||btrim(p_search)||'%')
        order by label
        limit p_limit
      ) scope_record), '[]'::jsonb),
    'profiles', coalesce((select jsonb_agg(profile.item order by profile.label)
      from (
        select jsonb_build_object(
          'profile_id',role_record.id,'label',role_record.name,'institution_id',p_institution_id,
          'unit_id',p_unit_id,'group_id',p_group_id
        ) item, role_record.name label
        from public.institution_roles role_record
        where p_institution_id is not null and role_record.status = 'active'
          and (role_record.institution_id = p_institution_id or role_record.institution_id is null)
          and app_private.access_scope_rank(
            case when p_group_id is not null then 'group'
              when p_unit_id is not null then 'unit' else 'institution' end
          ) <= app_private.access_scope_rank(role_record.max_scope_kind)
          and (coalesce(btrim(p_search),'') = '' or role_record.name ilike '%'||btrim(p_search)||'%')
        order by role_record.name, role_record.id
        limit p_limit
      ) profile), '[]'::jsonb),
    'recipients', coalesce((select jsonb_agg(recipient.item order by recipient.label)
      from (
        select jsonb_build_object(
          'person_id',person_record.id,'label',person_record.display_name,'masked_email',email_contact.masked_value
        ) item, person_record.display_name label
        from public.people person_record
        left join lateral (
          select contact.masked_value
          from public.person_contacts contact
          where contact.person_id = person_record.id and contact.contact_type = 'email' and contact.status = 'active'
          order by contact.verified_at desc nulls last, contact.created_at desc
          limit 1
        ) email_contact on true
        where p_institution_id is not null
          and person_record.status = 'active' and person_record.person_type = 'adult'
          and (coalesce(btrim(p_search),'') = '' or person_record.display_name ilike '%'||btrim(p_search)||'%')
        order by person_record.display_name, person_record.id
        limit p_limit
      ) recipient), '[]'::jsonb)
  ) into result;
  return result;
end $$;

create or replace function app_private.superadmin_invite_get(p_invite_id uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  perform app_private.superadmin_invite_require('platform.invites.read', false);
  result := app_private.superadmin_invite_json(p_invite_id);
  if result is null then raise no_data_found using message = 'invitation not found'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_invite_issue(
  p_request_id uuid, p_institution_id uuid, p_unit_id uuid, p_group_id uuid,
  p_profile_id uuid, p_target_person_id uuid, p_recipient_email text,
  p_channels text[], p_expires_in_hours integer
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
<<invite_issue_command>>
declare
  actor_person_id uuid;
  normalized_channels text[];
  normalized_email text;
  destination_hash text;
  masked_destination text;
  derived_scope_kind text;
  raw_token text;
  hashed_token text;
  invitation_id uuid;
  request_payload jsonb;
  request_hash bytea;
  replay jsonb;
  result jsonb;
begin
  actor_person_id := app_private.superadmin_invite_require('platform.invites.manage', true);
  if p_request_id is null or p_institution_id is null or p_profile_id is null
     or p_expires_in_hours not between 1 and 720
     or ((p_target_person_id is null)::int + (nullif(btrim(p_recipient_email),'') is null)::int) <> 1 then
    raise invalid_parameter_value using message = 'invalid invitation input';
  end if;
  normalized_channels := app_private.superadmin_invite_validate_channels(p_channels);
  if p_target_person_id is null then
    normalized_email := lower(btrim(p_recipient_email));
    if length(normalized_email) > 254 or normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
      raise invalid_parameter_value using message = 'invalid invitation email';
    end if;
    destination_hash := encode(extensions.digest(convert_to(normalized_email,'UTF8'),'sha256'),'hex');
    masked_destination := app_private.superadmin_invite_mask_email(normalized_email);
  elsif 'email' = any(normalized_channels) then
    select contact.normalized_value_hash, contact.masked_value
      into destination_hash, masked_destination
    from public.person_contacts contact
    where contact.person_id = p_target_person_id and contact.contact_type = 'email' and contact.status = 'active'
    order by contact.verified_at desc nulls last, contact.created_at desc limit 1;
    if destination_hash is null or destination_hash !~ '^[0-9a-f]{64}$'
       or nullif(btrim(masked_destination), '') is null then
      raise invalid_parameter_value using message = 'recipient has no deliverable email';
    end if;
  end if;
  derived_scope_kind := case when p_group_id is not null then 'group' when p_unit_id is not null then 'unit' else 'institution' end;
  request_payload := jsonb_build_object('institution_id',p_institution_id,'unit_id',p_unit_id,'group_id',p_group_id,
    'profile_id',p_profile_id,'target_person_id',p_target_person_id,'recipient_hash',destination_hash,
    'channels',normalized_channels,'expires_in_hours',p_expires_in_hours);
  request_hash := app_private.superadmin_invite_payload_hash(request_payload);
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  replay := app_private.superadmin_invite_replay(p_request_id, actor_person_id, 'issue', request_hash);
  if replay is not null then return replay; end if;
  if (select count(*) from app_private.superadmin_invite_command_receipts receipt
      where receipt.actor_person_id = invite_issue_command.actor_person_id
        and receipt.created_at > now() - interval '1 minute') >= 20 then
    raise insufficient_privilege using message = 'invitation command rate limit exceeded';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(
    concat_ws('|', p_institution_id::text, coalesce(p_unit_id::text, ''), coalesce(p_group_id::text, ''),
      p_profile_id::text, coalesce(p_target_person_id::text, destination_hash)),
    1
  ));
  update public.invitations existing_invitation
  set invitation_state = 'expired', status = 'inactive'
  where existing_invitation.invitation_state = 'pending'
    and existing_invitation.expires_at <= now()
    and existing_invitation.institution_id = p_institution_id
    and existing_invitation.unit_id is not distinct from p_unit_id
    and existing_invitation.group_id is not distinct from p_group_id
    and existing_invitation.profile_id = p_profile_id
    and existing_invitation.target_person_id is not distinct from p_target_person_id
    and existing_invitation.target_contact_hash is not distinct from
      (case when p_target_person_id is null then destination_hash else null end);
  if exists (
    select 1 from public.invitations existing_invitation
    where existing_invitation.invitation_state = 'pending'
      and existing_invitation.institution_id = p_institution_id
      and existing_invitation.unit_id is not distinct from p_unit_id
      and existing_invitation.group_id is not distinct from p_group_id
      and existing_invitation.profile_id = p_profile_id
      and existing_invitation.target_person_id is not distinct from p_target_person_id
      and existing_invitation.target_contact_hash is not distinct from
        (case when p_target_person_id is null then destination_hash else null end)
  ) then
    raise unique_violation using message = 'active invitation already exists';
  end if;

  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  hashed_token := encode(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),'hex');
  insert into public.invitations(
    scope_kind,institution_id,unit_id,group_id,target_kind,target_person_id,target_contact_hash,
    masked_destination,profile_id,role_code,token_hash,expires_at,invitation_state,status,
    invited_by,channels,send_count,sent_at,last_sent_at,version,validity_hours
  ) select derived_scope_kind,p_institution_id,p_unit_id,p_group_id,
      case when p_target_person_id is null then 'email' else 'person' end,
      p_target_person_id,case when p_target_person_id is null then destination_hash else null end,
      case when p_target_person_id is null then masked_destination else null end,
      p_profile_id,profile.code,hashed_token,now()+make_interval(hours=>p_expires_in_hours),
      'pending','active',actor_person_id,normalized_channels,0,null,null,1,p_expires_in_hours
    from public.institution_roles profile where profile.id = p_profile_id
  returning id into invitation_id;
  if invitation_id is null then raise invalid_parameter_value using message = 'invalid invitation profile'; end if;
  if 'email' = any(normalized_channels) then
    insert into app_private.superadmin_invite_email_outbox(
      invitation_id,destination_hash,masked_destination,token_hash_snapshot,requested_by_person_id
    ) values (invitation_id,destination_hash,masked_destination,hashed_token,actor_person_id);
  end if;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,after_json)
  values(actor_person_id,auth.jwt()->>'aal','invite.issue','invitation',invitation_id,p_institution_id,'success',
    jsonb_build_object('scope_kind',derived_scope_kind,'profile_id',p_profile_id,'channels',normalized_channels,'version',1));
  result := jsonb_build_object('invite',app_private.superadmin_invite_json(invitation_id),
    'link',case when 'link'=any(normalized_channels)
      then app_private.superadmin_invite_public_origin()||'/convites/'||raw_token else null end,
    'replayed',false);
  insert into app_private.superadmin_invite_command_receipts(
    request_id,actor_person_id,command_kind,invitation_id,payload_hash,result_json
  ) values(p_request_id,actor_person_id,'issue',invitation_id,request_hash,result-'link');
  return result;
end $$;

create or replace function app_private.superadmin_invite_resend(
  p_invite_id uuid, p_request_id uuid, p_expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
<<invite_resend_command>>
declare
  actor_person_id uuid;
  invitation public.invitations%rowtype;
  normalized_channels text[];
  destination_hash text;
  masked_destination text;
  raw_token text;
  hashed_token text;
  request_hash bytea;
  replay jsonb;
  result jsonb;
begin
  actor_person_id := app_private.superadmin_invite_require('platform.invites.manage', true);
  if p_invite_id is null or p_request_id is null or p_expected_version is null then
    raise invalid_parameter_value using message = 'invalid invitation input';
  end if;
  request_hash := app_private.superadmin_invite_payload_hash(jsonb_build_object(
    'invite_id',p_invite_id,'expected_version',p_expected_version));
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  replay := app_private.superadmin_invite_replay(p_request_id, actor_person_id, 'resend', request_hash);
  if replay is not null then return replay; end if;
  if (select count(*) from app_private.superadmin_invite_command_receipts receipt
      where receipt.actor_person_id = invite_resend_command.actor_person_id
        and receipt.created_at > now() - interval '1 minute') >= 20 then
    raise insufficient_privilege using message = 'invitation command rate limit exceeded';
  end if;
  select * into invitation from public.invitations where id = p_invite_id for update;
  if invitation.id is null then raise no_data_found using message = 'invitation not found'; end if;
  if invitation.version <> p_expected_version then raise serialization_failure using message = 'invitation version conflict'; end if;
  if invitation.invitation_state not in ('pending','expired')
     or (invitation.invitation_state = 'pending' and invitation.expires_at > now()) then
    raise invalid_parameter_value using message = 'invitation cannot be resent';
  end if;
  normalized_channels := app_private.superadmin_invite_validate_channels(invitation.channels);
  if 'email' = any(normalized_channels) then
    if invitation.target_kind = 'email' then
      destination_hash := invitation.target_contact_hash;
      masked_destination := invitation.masked_destination;
    else
      select contact.normalized_value_hash, contact.masked_value into destination_hash,masked_destination
      from public.person_contacts contact where contact.person_id=invitation.target_person_id
        and contact.contact_type='email' and contact.status='active'
      order by contact.verified_at desc nulls last,contact.created_at desc limit 1;
    end if;
    if destination_hash is null or destination_hash !~ '^[0-9a-f]{64}$'
       or nullif(btrim(masked_destination), '') is null then
      raise invalid_parameter_value using message = 'recipient has no deliverable email';
    end if;
  end if;
  raw_token := encode(extensions.gen_random_bytes(32),'hex');
  hashed_token := encode(extensions.digest(convert_to(raw_token,'UTF8'),'sha256'),'hex');
  update public.invitations set token_hash=hashed_token,expires_at=now()+make_interval(hours=>invitation.validity_hours),
    invitation_state='pending',status='active',revoked_at=null,channels=normalized_channels,
    send_count=send_count+1,last_sent_at=now(),version=version+1
  where id=p_invite_id;
  update app_private.superadmin_invite_email_outbox set state='cancelled',updated_at=now()
  where invitation_id=p_invite_id and state='pending';
  if 'email'=any(normalized_channels) then
    insert into app_private.superadmin_invite_email_outbox(
      invitation_id,destination_hash,masked_destination,token_hash_snapshot,requested_by_person_id
    ) values(p_invite_id,destination_hash,masked_destination,hashed_token,actor_person_id);
  end if;
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,before_json,after_json)
  values(actor_person_id,auth.jwt()->>'aal','invite.resend','invitation',p_invite_id,invitation.institution_id,'success',
    jsonb_build_object('status',invitation.invitation_state,'version',invitation.version),
    jsonb_build_object('status','pending','version',invitation.version+1,'channels',normalized_channels));
  result:=jsonb_build_object('invite',app_private.superadmin_invite_json(p_invite_id),
    'link',case when 'link'=any(normalized_channels)
      then app_private.superadmin_invite_public_origin()||'/convites/'||raw_token else null end,
    'replayed',false);
  insert into app_private.superadmin_invite_command_receipts(request_id,actor_person_id,command_kind,invitation_id,payload_hash,result_json)
  values(p_request_id,actor_person_id,'resend',p_invite_id,request_hash,result-'link');
  return result;
end $$;

create or replace function app_private.superadmin_invite_revoke(
  p_invite_id uuid, p_request_id uuid, p_expected_version bigint, p_reason text
) returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
<<invite_revoke_command>>
declare actor_person_id uuid; invitation public.invitations%rowtype; request_hash bytea; replay jsonb; result jsonb;
begin
  actor_person_id:=app_private.superadmin_invite_require('platform.invites.manage',true);
  if p_invite_id is null or p_request_id is null or p_expected_version is null
     or length(btrim(coalesce(p_reason,''))) not between 4 and 500 then
    raise invalid_parameter_value using message='invalid revocation input';
  end if;
  request_hash:=app_private.superadmin_invite_payload_hash(jsonb_build_object(
    'invite_id',p_invite_id,'expected_version',p_expected_version,'reason',btrim(p_reason)));
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  replay:=app_private.superadmin_invite_replay(p_request_id,actor_person_id,'revoke',request_hash);
  if replay is not null then return replay; end if;
  if (select count(*) from app_private.superadmin_invite_command_receipts receipt
      where receipt.actor_person_id=invite_revoke_command.actor_person_id
        and receipt.created_at>now()-interval '1 minute')>=20 then
    raise insufficient_privilege using message='invitation command rate limit exceeded';
  end if;
  select * into invitation from public.invitations where id=p_invite_id for update;
  if invitation.id is null then raise no_data_found using message='invitation not found'; end if;
  if invitation.version<>p_expected_version then raise serialization_failure using message='invitation version conflict'; end if;
  if invitation.invitation_state<>'pending' or invitation.expires_at<=now() then
    raise invalid_parameter_value using message='invitation cannot be revoked';
  end if;
  update public.invitations set invitation_state='revoked',status='inactive',revoked_at=now(),version=version+1
  where id=p_invite_id;
  update app_private.superadmin_invite_email_outbox set state='cancelled',updated_at=now()
  where invitation_id=p_invite_id and state='pending';
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,outcome,reason,before_json,after_json)
  values(actor_person_id,auth.jwt()->>'aal','invite.revoke','invitation',p_invite_id,invitation.institution_id,'success',
    left(btrim(p_reason),500),jsonb_build_object('status','pending','version',invitation.version),
    jsonb_build_object('status','revoked','version',invitation.version+1));
  result:=jsonb_build_object('invite',app_private.superadmin_invite_json(p_invite_id),'link',null,'replayed',false);
  insert into app_private.superadmin_invite_command_receipts(request_id,actor_person_id,command_kind,invitation_id,payload_hash,result_json)
  values(p_request_id,actor_person_id,'revoke',p_invite_id,request_hash,result);
  return result;
end $$;

-- These six wrappers are intentionally SECURITY DEFINER: SECURITY INVOKER
-- cannot call revoked app_private implementations. They contain no business
-- logic, pin an empty search_path, and every private implementation immediately
-- recalculates auth.uid(), current person, live capability and AAL2 when needed.
create or replace function public.superadmin_invite_directory(
  p_search text default '', p_statuses text[] default '{}', p_channels text[] default '{}',
  p_institution_ids uuid[] default '{}', p_unit_ids uuid[] default '{}',p_group_ids uuid[] default '{}',
  p_profile_ids uuid[] default '{}',p_created_from timestamptz default null,p_created_to timestamptz default null,
  p_limit integer default 25,p_offset integer default 0,p_sort text default 'created_at',p_sort_ascending boolean default false
) returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_invite_directory(p_search,p_statuses,p_channels,p_institution_ids,p_unit_ids,p_group_ids,p_profile_ids,p_created_from,p_created_to,p_limit,p_offset,p_sort,p_sort_ascending) $$;
create or replace function public.superadmin_invite_options(p_search text default '',p_institution_id uuid default null,p_unit_id uuid default null,p_group_id uuid default null,p_limit integer default 50)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_invite_options(p_search,p_institution_id,p_unit_id,p_group_id,p_limit) $$;
create or replace function public.superadmin_invite_get(p_invite_id uuid)
returns jsonb language sql stable security definer set search_path = ''
as $$ select app_private.superadmin_invite_get(p_invite_id) $$;
create or replace function public.superadmin_invite_issue(p_request_id uuid,p_institution_id uuid,p_unit_id uuid,p_group_id uuid,p_profile_id uuid,p_target_person_id uuid,p_recipient_email text,p_channels text[],p_expires_in_hours integer)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_invite_issue(p_request_id,p_institution_id,p_unit_id,p_group_id,p_profile_id,p_target_person_id,p_recipient_email,p_channels,p_expires_in_hours) $$;
create or replace function public.superadmin_invite_resend(p_invite_id uuid,p_request_id uuid,p_expected_version bigint)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_invite_resend(p_invite_id,p_request_id,p_expected_version) $$;
create or replace function public.superadmin_invite_revoke(p_invite_id uuid,p_request_id uuid,p_expected_version bigint,p_reason text)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.superadmin_invite_revoke(p_invite_id,p_request_id,p_expected_version,p_reason) $$;

alter table public.invitations enable row level security;
alter table public.invitations force row level security;
do $$ declare policy_record record; begin
  for policy_record in select policyname from pg_policies where schemaname='public' and tablename='invitations'
  loop execute format('drop policy %I on public.invitations',policy_record.policyname); end loop;
end $$;
create policy invitations_self_read on public.invitations for select to authenticated
using (target_person_id=(select app_private.current_person_id()));

revoke all on table public.invitations from public, anon, authenticated;
grant select (
  id, scope_kind, institution_id, unit_id, group_id, target_kind,
  target_person_id, masked_destination, profile_id, role_code, channels,
  expires_at, accepted_at, accepted_by, revoked_at, invitation_state,
  status, send_count, version, validity_hours, created_at, updated_at
) on table public.invitations to authenticated;
revoke all on function public.superadmin_invite_directory(text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,integer,integer,text,boolean) from public,anon,authenticated;
revoke all on function public.superadmin_invite_options(text,uuid,uuid,uuid,integer) from public,anon,authenticated;
revoke all on function public.superadmin_invite_get(uuid) from public,anon,authenticated;
revoke all on function public.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer) from public,anon,authenticated;
revoke all on function public.superadmin_invite_resend(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function public.superadmin_invite_revoke(uuid,uuid,bigint,text) from public,anon,authenticated;
grant execute on function public.superadmin_invite_directory(text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,integer,integer,text,boolean) to authenticated;
grant execute on function public.superadmin_invite_options(text,uuid,uuid,uuid,integer) to authenticated;
grant execute on function public.superadmin_invite_get(uuid) to authenticated;
grant execute on function public.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer) to authenticated;
grant execute on function public.superadmin_invite_resend(uuid,uuid,bigint) to authenticated;
grant execute on function public.superadmin_invite_revoke(uuid,uuid,bigint,text) to authenticated;

revoke all on function app_private.superadmin_invite_directory(text,text[],text[],uuid[],uuid[],uuid[],uuid[],timestamptz,timestamptz,integer,integer,text,boolean) from public,anon,authenticated;
revoke all on function app_private.superadmin_invite_options(text,uuid,uuid,uuid,integer) from public,anon,authenticated;
revoke all on function app_private.superadmin_invite_get(uuid) from public,anon,authenticated;
revoke all on function app_private.superadmin_invite_issue(uuid,uuid,uuid,uuid,uuid,uuid,text,text[],integer) from public,anon,authenticated;
revoke all on function app_private.superadmin_invite_resend(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function app_private.superadmin_invite_revoke(uuid,uuid,bigint,text) from public,anon,authenticated;

revoke all on function app_private.validate_production_invitation() from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_require(text,boolean) from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_validate_channels(text[]) from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_mask_email(text) from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_payload_hash(jsonb) from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_public_origin() from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_json(uuid) from public, anon, authenticated;
revoke all on function app_private.superadmin_invite_replay(uuid,uuid,text,bytea) from public, anon, authenticated;
