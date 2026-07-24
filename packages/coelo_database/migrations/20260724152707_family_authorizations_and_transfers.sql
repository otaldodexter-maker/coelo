-- Family relationships, guardian capabilities, operational authorizations,
-- contextual notifications and unit transfers.

create table public.family_relationship_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  sort_order integer not null default 0,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.family_relationship_types(code, name, sort_order)
values
  ('father', 'Pai', 10), ('mother', 'Mae', 20),
  ('grandfather', 'Avô', 30), ('grandmother', 'Avó', 40),
  ('brother', 'Irmao', 50), ('sister', 'Irma', 60),
  ('stepfather', 'Padrasto', 70), ('stepmother', 'Madrasta', 80),
  ('cousin_male', 'Primo', 90), ('cousin_female', 'Prima', 100),
  ('uncle', 'Tio', 110), ('aunt', 'Tia', 120), ('other', 'Outros', 999)
on conflict (code) do update set name = excluded.name, sort_order = excluded.sort_order,
  status = 'active', updated_at = now();

alter table public.guardian_links
  add column relationship_type_id uuid
    references public.family_relationship_types(id) on delete restrict,
  add column relationship_detail text;

update public.guardian_links guardian
set relationship_type_id = relationship.id,
    relationship_detail = guardian.relation_type
from public.family_relationship_types relationship
where guardian.relationship_type_id is null
  and relationship.code = case lower(btrim(guardian.relation_type))
    when 'pai' then 'father' when 'mae' then 'mother'
    else 'other' end;

alter table public.guardian_links
  alter column relationship_type_id set not null,
  add constraint guardian_links_relationship_detail_check
    check (relationship_detail is null or btrim(relationship_detail) <> '');

create table public.guardian_permission_capabilities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  description text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.guardian_permission_capabilities(code, name, description)
values
  ('view_context', 'Visualizar contexto', 'Visualizar dados autorizados da crianca.'),
  ('message', 'Conversar', 'Conversar nos contextos autorizados.'),
  ('react', 'Reagir', 'Reagir a publicacoes autorizadas.'),
  ('manage_authorized_people', 'Gerenciar pessoas autorizadas',
   'Cadastrar e consultar pessoas autorizadas para a crianca.'),
  ('manage_attendance_notices', 'Gerenciar avisos de presenca',
   'Informar ausencia, atraso, presenca esperada e saida antecipada.')
on conflict (code) do update set name = excluded.name,
  description = excluded.description, status = 'active', updated_at = now();

create table public.guardian_context_permission_grants (
  id uuid primary key default gen_random_uuid(),
  guardian_context_permission_id uuid not null
    references public.guardian_context_permissions(id) on delete cascade,
  capability_id uuid not null
    references public.guardian_permission_capabilities(id) on delete restrict,
  effect public.permission_effect not null default 'allow',
  status public.record_status not null default 'active',
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(guardian_context_permission_id, capability_id)
);
create index guardian_context_permission_grants_capability_idx
  on public.guardian_context_permission_grants(capability_id, status);

create table public.guardian_invitation_children (
  id uuid primary key default gen_random_uuid(),
  invitation_id uuid not null references public.invitations(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  relationship_type_id uuid not null
    references public.family_relationship_types(id) on delete restrict,
  relationship_detail text,
  initial_capabilities text[] not null default array[
    'view_context','message','react','manage_authorized_people',
    'manage_attendance_notices'
  ]::text[],
  created_at timestamptz not null default now(),
  unique(invitation_id, child_context_id),
  constraint guardian_invitation_children_detail_check
    check (relationship_detail is null or btrim(relationship_detail) <> '')
);

create table public.authorized_people (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  display_name text not null check (btrim(display_name) <> ''),
  document_type text,
  document_ciphertext bytea,
  document_fingerprint text,
  document_last4 text check (
    document_last4 is null or document_last4 ~ '^[0-9]{4}$'
  ),
  phone_ciphertext bytea,
  notes text,
  status public.record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint authorized_people_document_check check (
    (document_ciphertext is null and document_fingerprint is null
      and document_type is null and document_last4 is null)
    or (document_ciphertext is not null and document_fingerprint is not null
      and document_type is not null)
  )
);
create index authorized_people_institution_status_idx
  on public.authorized_people(institution_id, status);
create unique index authorized_people_document_fingerprint_uidx
  on public.authorized_people(institution_id, document_fingerprint)
  where document_fingerprint is not null and status <> 'archived';

create table public.authorized_person_authorizations (
  id uuid primary key default gen_random_uuid(),
  authorized_person_id uuid not null
    references public.authorized_people(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  relationship_type_id uuid not null
    references public.family_relationship_types(id) on delete restrict,
  relationship_detail text,
  created_by_guardian_link_id uuid
    references public.guardian_links(id) on delete restrict,
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  status public.record_status not null default 'active',
  valid_from date not null default current_date,
  valid_until date,
  suspended_by_person_id uuid references public.people(id) on delete restrict,
  suspended_at timestamptz,
  suspension_reason text,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint authorized_person_authorizations_dates_check
    check (valid_until is null or valid_until >= valid_from),
  constraint authorized_person_authorizations_suspension_check check (
    (status <> 'suspended' and suspended_by_person_id is null
      and suspended_at is null and suspension_reason is null)
    or (status = 'suspended' and suspended_by_person_id is not null
      and suspended_at is not null and btrim(suspension_reason) <> '')
  ),
  constraint authorized_person_authorizations_detail_check
    check (relationship_detail is null or btrim(relationship_detail) <> '')
);
create unique index authorized_person_authorizations_active_uidx
  on public.authorized_person_authorizations(
    authorized_person_id, child_context_id, unit_id
  ) where status = 'active' and revoked_at is null;
create index authorized_person_authorizations_child_unit_idx
  on public.authorized_person_authorizations(child_context_id, unit_id, status);

create table public.authorized_person_authorization_capabilities (
  authorization_id uuid not null
    references public.authorized_person_authorizations(id) on delete cascade,
  capability_code text not null
    check (capability_code in ('emergency_contact', 'pickup', 'transport')),
  created_at timestamptz not null default now(),
  primary key(authorization_id, capability_code)
);

create table public.context_notification_events (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid references public.units(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  activity_id uuid references public.activity_definitions(id) on delete cascade,
  child_context_id uuid references public.child_contexts(id) on delete cascade,
  event_code text not null check (btrim(event_code) <> ''),
  object_type text not null check (btrim(object_type) <> ''),
  object_id uuid,
  payload_json jsonb not null default '{}'::jsonb,
  deliver_at timestamptz not null default now(),
  created_by_person_id uuid references public.people(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint context_notification_events_payload_object_check
    check (jsonb_typeof(payload_json) = 'object')
);
create index context_notification_events_delivery_idx
  on public.context_notification_events(deliver_at, event_code);
create index context_notification_events_context_idx
  on public.context_notification_events(institution_id, unit_id, group_id);

create table public.context_notification_recipients (
  event_id uuid not null
    references public.context_notification_events(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  read_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  primary key(event_id, person_id)
);
create index context_notification_recipients_person_idx
  on public.context_notification_recipients(person_id, read_at, created_at desc);

create table public.child_unit_transfer_requests (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  source_unit_id uuid not null references public.units(id) on delete restrict,
  destination_unit_id uuid not null references public.units(id) on delete restrict,
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected','changes_requested','cancelled')),
  message text,
  decision_reason text,
  decided_by_person_id uuid references public.people(id) on delete restrict,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint child_unit_transfer_requests_units_check
    check (source_unit_id <> destination_unit_id),
  constraint child_unit_transfer_requests_decision_check check (
    (status = 'pending' and decided_by_person_id is null and decided_at is null)
    or (status in ('accepted','rejected','changes_requested')
        and decided_by_person_id is not null and decided_at is not null)
    or status = 'cancelled'
  )
);
create index child_unit_transfer_requests_destination_idx
  on public.child_unit_transfer_requests(destination_unit_id, status, created_at);

create table public.child_unit_transfer_items (
  id uuid primary key default gen_random_uuid(),
  transfer_request_id uuid not null
    references public.child_unit_transfer_requests(id) on delete cascade,
  child_unit_link_id uuid not null
    references public.child_unit_links(id) on delete restrict,
  suggested_group_id uuid references public.groups(id) on delete set null,
  destination_child_unit_link_id uuid
    references public.child_unit_links(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(transfer_request_id, child_unit_link_id)
);

create or replace function app_private.guardian_has_capability(
  target_child_context_id uuid,
  target_capability_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.child_contexts child_context
    join public.guardian_links guardian
      on guardian.child_person_id = child_context.child_person_id
     and guardian.guardian_person_id = app_private.current_person_id()
     and guardian.status = 'active'
     and guardian.revoked_at is null
    join public.guardian_context_permissions context_permission
      on context_permission.guardian_link_id = guardian.id
     and context_permission.child_context_id = child_context.id
     and context_permission.status = 'active'
     and (context_permission.starts_at is null
          or context_permission.starts_at <= pg_catalog.now())
     and (context_permission.expires_at is null
          or context_permission.expires_at > pg_catalog.now())
    join public.guardian_context_permission_grants capability_grant
      on capability_grant.guardian_context_permission_id = context_permission.id
     and capability_grant.status = 'active'
     and capability_grant.revoked_at is null
     and capability_grant.effect = 'allow'
    join public.guardian_permission_capabilities capability
      on capability.id = capability_grant.capability_id
     and capability.code = target_capability_code
     and capability.status = 'active'
    where child_context.id = target_child_context_id
  )
$$;

create or replace function app_private.validate_family_context_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_institution uuid;
  related_institution uuid;
begin
  if tg_table_name = 'authorized_person_authorizations' then
    select child_context.institution_id into expected_institution
    from public.child_contexts child_context where child_context.id = new.child_context_id;
    select unit_record.institution_id into related_institution
    from public.units unit_record where unit_record.id = new.unit_id;
    if expected_institution is null or related_institution <> expected_institution
       or new.institution_id <> expected_institution
       or not exists (
         select 1 from public.authorized_people person_record
         where person_record.id = new.authorized_person_id
           and person_record.institution_id = expected_institution
       ) then
      raise exception 'authorization contexts must share one institution';
    end if;
  elsif tg_table_name = 'child_unit_transfer_requests' then
    select source_unit.institution_id into expected_institution
    from public.units source_unit where source_unit.id = new.source_unit_id;
    select destination_unit.institution_id into related_institution
    from public.units destination_unit where destination_unit.id = new.destination_unit_id;
    if expected_institution is null or related_institution <> expected_institution
       or new.institution_id <> expected_institution then
      raise exception 'transfer units must share one institution';
    end if;
  elsif tg_table_name = 'child_unit_transfer_items' then
    if not exists (
      select 1
      from public.child_unit_transfer_requests request_record
      join public.child_unit_links child_link on child_link.id = new.child_unit_link_id
      join public.child_contexts child_context
        on child_context.id = child_link.child_context_id
      where request_record.id = new.transfer_request_id
        and child_link.unit_id = request_record.source_unit_id
        and child_context.institution_id = request_record.institution_id
        and (
          new.suggested_group_id is null
          or exists (
            select 1 from public.groups group_record
            where group_record.id = new.suggested_group_id
              and group_record.unit_id = request_record.destination_unit_id
              and group_record.institution_id = request_record.institution_id
          )
        )
    ) then
      raise exception 'transfer item is outside request context';
    end if;
  end if;
  return new;
end;
$$;

create trigger authorized_person_authorizations_validate
before insert or update on public.authorized_person_authorizations
for each row execute function app_private.validate_family_context_row();
create trigger child_unit_transfer_requests_validate
before insert or update on public.child_unit_transfer_requests
for each row execute function app_private.validate_family_context_row();
create trigger child_unit_transfer_items_validate
before insert or update on public.child_unit_transfer_items
for each row execute function app_private.validate_family_context_row();

create or replace function app_private.create_authorized_person_authorization(
  target_child_context_id uuid,
  target_unit_id uuid,
  target_display_name text,
  target_relationship_code text,
  target_relationship_detail text,
  target_document_ciphertext bytea,
  target_document_fingerprint text,
  target_document_last4 text,
  target_document_type text,
  target_capability_codes text[],
  target_valid_from date,
  target_valid_until date
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  target_institution_id uuid;
  guardian_link_id uuid;
  relationship_id uuid;
  authorized_person_id uuid;
  authorization_id uuid;
  notification_id uuid;
begin
  select child_context.institution_id into target_institution_id
  from public.child_contexts child_context
  where child_context.id = target_child_context_id
    and child_context.status = 'active';
  if target_institution_id is null or not exists (
    select 1 from public.units unit_record
    where unit_record.id = target_unit_id
      and unit_record.institution_id = target_institution_id
  ) then
    raise exception 'invalid child or unit context';
  end if;

  select guardian.id into guardian_link_id
  from public.guardian_links guardian
  join public.child_contexts child_context
    on child_context.child_person_id = guardian.child_person_id
  where child_context.id = target_child_context_id
    and guardian.guardian_person_id = actor_person_id
    and guardian.status = 'active'
    and guardian.revoked_at is null;

  if guardian_link_id is null
     or not app_private.guardian_has_capability(
       target_child_context_id, 'manage_authorized_people'
     ) then
    raise exception 'guardian cannot manage authorized people';
  end if;

  select relationship.id into relationship_id
  from public.family_relationship_types relationship
  where relationship.code = target_relationship_code and relationship.status = 'active';
  if relationship_id is null then raise exception 'invalid relationship code'; end if;
  if target_relationship_code = 'other'
     and nullif(btrim(target_relationship_detail), '') is null then
    raise exception 'relationship detail is required for other';
  end if;

  insert into public.authorized_people(
    institution_id, display_name, document_type, document_ciphertext,
    document_fingerprint, document_last4
  ) values (
    target_institution_id, btrim(target_display_name), target_document_type,
    target_document_ciphertext, target_document_fingerprint, target_document_last4
  ) returning id into authorized_person_id;

  insert into public.authorized_person_authorizations(
    authorized_person_id, institution_id, child_context_id, unit_id,
    relationship_type_id, relationship_detail, created_by_guardian_link_id,
    created_by_person_id, valid_from, valid_until
  ) values (
    authorized_person_id, target_institution_id, target_child_context_id,
    target_unit_id, relationship_id, nullif(btrim(target_relationship_detail), ''),
    guardian_link_id, actor_person_id, coalesce(target_valid_from, current_date),
    target_valid_until
  ) returning id into authorization_id;

  insert into public.authorized_person_authorization_capabilities(
    authorization_id, capability_code
  )
  select distinct authorization_id, capability_code
  from unnest(target_capability_codes) capability_code
  where capability_code in ('emergency_contact','pickup','transport');

  insert into public.context_notification_events(
    institution_id, unit_id, child_context_id, event_code, object_type,
    object_id, payload_json, created_by_person_id
  ) values (
    target_institution_id, target_unit_id, target_child_context_id,
    'authorized_person_created', 'authorized_person_authorization',
    authorization_id, jsonb_build_object('status', 'active'), actor_person_id
  ) returning id into notification_id;

  insert into public.context_notification_recipients(event_id, person_id)
  select notification_id, guardian.guardian_person_id
  from public.guardian_links guardian
  join public.child_contexts child_context
    on child_context.child_person_id = guardian.child_person_id
  where child_context.id = target_child_context_id
    and guardian.status = 'active' and guardian.revoked_at is null
  on conflict do nothing;

  return authorization_id;
end;
$$;

create or replace function public.create_authorized_person_authorization(
  child_context_id uuid,
  unit_id uuid,
  display_name text,
  relationship_code text,
  relationship_detail text,
  document_ciphertext bytea,
  document_fingerprint text,
  document_last4 text,
  document_type text,
  capability_codes text[],
  valid_from date default current_date,
  valid_until date default null
)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select app_private.create_authorized_person_authorization(
    child_context_id, unit_id, display_name, relationship_code,
    relationship_detail, document_ciphertext, document_fingerprint,
    document_last4, document_type, capability_codes, valid_from, valid_until
  )
$$;

create or replace function app_private.suspend_authorized_person_authorization(
  target_authorization_id uuid,
  target_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  authorization_record public.authorized_person_authorizations%rowtype;
  notification_id uuid;
begin
  select * into authorization_record
  from public.authorized_person_authorizations
  where id = target_authorization_id for update;
  if authorization_record.id is null then raise exception 'authorization not found'; end if;
  if not app_private.has_context_permission(
    authorization_record.institution_id, 'authorized_people.manage',
    authorization_record.unit_id, null, null,
    authorization_record.child_context_id, false
  ) then raise exception 'not authorized to suspend'; end if;
  if nullif(btrim(target_reason), '') is null then raise exception 'reason required'; end if;

  update public.authorized_person_authorizations
  set status = 'suspended', suspended_by_person_id = actor_person_id,
      suspended_at = now(), suspension_reason = btrim(target_reason),
      updated_at = now()
  where id = target_authorization_id;

  insert into public.context_notification_events(
    institution_id, unit_id, child_context_id, event_code, object_type,
    object_id, payload_json, created_by_person_id
  ) values (
    authorization_record.institution_id, authorization_record.unit_id,
    authorization_record.child_context_id, 'authorized_person_suspended',
    'authorized_person_authorization', target_authorization_id,
    jsonb_build_object('status','suspended','reason',btrim(target_reason)),
    actor_person_id
  ) returning id into notification_id;

  insert into public.context_notification_recipients(event_id, person_id)
  select notification_id, guardian.guardian_person_id
  from public.guardian_links guardian
  join public.child_contexts child_context
    on child_context.child_person_id = guardian.child_person_id
  where child_context.id = authorization_record.child_context_id
    and guardian.status = 'active' and guardian.revoked_at is null
  on conflict do nothing;
end;
$$;

create or replace function public.suspend_authorized_person_authorization(
  authorization_id uuid,
  reason text
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app_private.suspend_authorized_person_authorization(authorization_id, reason)
$$;

create or replace function app_private.decide_child_unit_transfer(
  target_request_id uuid,
  target_decision text,
  target_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  request_record public.child_unit_transfer_requests%rowtype;
  item_record record;
  destination_link_id uuid;
begin
  if target_decision not in ('accepted','rejected','changes_requested') then
    raise exception 'invalid transfer decision';
  end if;
  select * into request_record from public.child_unit_transfer_requests
  where id = target_request_id and status = 'pending' for update;
  if request_record.id is null then raise exception 'pending transfer not found'; end if;
  if not app_private.has_context_permission(
    request_record.institution_id, 'transfers.manage',
    request_record.destination_unit_id, null, null, null, false
  ) then raise exception 'destination authorization required'; end if;

  update public.child_unit_transfer_requests
  set status = target_decision, decision_reason = nullif(btrim(target_reason), ''),
      decided_by_person_id = actor_person_id, decided_at = now(), updated_at = now()
  where id = target_request_id;

  if target_decision = 'accepted' then
    for item_record in
      select item.*, source_link.child_context_id
      from public.child_unit_transfer_items item
      join public.child_unit_links source_link on source_link.id = item.child_unit_link_id
      where item.transfer_request_id = target_request_id and item.status = 'pending'
      for update of item
    loop
      update public.child_group_links
      set status = 'inactive', ends_at = coalesce(ends_at, now()), updated_at = now()
      where child_unit_link_id = item_record.child_unit_link_id and status = 'active';
      update public.child_unit_links
      set status = 'inactive', revoked_at = now(), updated_at = now()
      where id = item_record.child_unit_link_id;

      insert into public.child_unit_links(
        child_context_id, unit_id, status, accepted_by, accepted_at
      ) values (
        item_record.child_context_id, request_record.destination_unit_id,
        case when item_record.suggested_group_id is null
          then 'awaiting_allocation'::public.child_unit_link_status
          else 'active'::public.child_unit_link_status end,
        actor_person_id, now()
      )
      on conflict (child_context_id, unit_id) do update set
        status = excluded.status, accepted_by = excluded.accepted_by,
        accepted_at = excluded.accepted_at, revoked_at = null, updated_at = now()
      returning id into destination_link_id;

      if item_record.suggested_group_id is not null then
        insert into public.child_group_links(child_unit_link_id, group_id, starts_at)
        values (destination_link_id, item_record.suggested_group_id, now())
        on conflict (child_unit_link_id, group_id) do update set
          status = 'active', starts_at = excluded.starts_at, ends_at = null,
          updated_at = now();
      end if;
      update public.child_unit_transfer_items
      set status = 'accepted', destination_child_unit_link_id = destination_link_id,
          updated_at = now()
      where id = item_record.id;
    end loop;
  else
    update public.child_unit_transfer_items set status = 'rejected', updated_at = now()
    where transfer_request_id = target_request_id and status = 'pending';
  end if;
end;
$$;

create or replace function public.decide_child_unit_transfer(
  request_id uuid,
  decision text,
  reason text default null
)
returns void
language sql
security invoker
set search_path = ''
as $$ select app_private.decide_child_unit_transfer(request_id, decision, reason) $$;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'family_relationship_types','guardian_permission_capabilities',
    'guardian_context_permission_grants','guardian_invitation_children',
    'authorized_people','authorized_person_authorizations',
    'authorized_person_authorization_capabilities','context_notification_events',
    'context_notification_recipients','child_unit_transfer_requests',
    'child_unit_transfer_items'
  ] loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('revoke all on public.%I from public, anon, authenticated', current_table);
    execute format('grant all on public.%I to service_role', current_table);
  end loop;
end;
$$;

grant select on public.family_relationship_types,
  public.guardian_permission_capabilities to authenticated;
grant select on public.guardian_context_permission_grants,
  public.guardian_invitation_children, public.authorized_people,
  public.authorized_person_authorizations,
  public.authorized_person_authorization_capabilities,
  public.context_notification_events, public.context_notification_recipients,
  public.child_unit_transfer_requests, public.child_unit_transfer_items
to authenticated;
grant insert, update on public.guardian_context_permission_grants,
  public.guardian_invitation_children, public.child_unit_transfer_requests,
  public.child_unit_transfer_items to authenticated;
grant update on public.context_notification_recipients to authenticated;

create policy family_relationship_types_read on public.family_relationship_types
for select to authenticated using (status = 'active');
create policy guardian_permission_capabilities_read
on public.guardian_permission_capabilities for select to authenticated
using (status = 'active');

create policy guardian_context_permission_grants_context_read
on public.guardian_context_permission_grants for select to authenticated
using (
  exists (
    select 1
    from public.guardian_context_permissions context_permission
    join public.guardian_links guardian on guardian.id = context_permission.guardian_link_id
    join public.child_contexts child_context on child_context.id = context_permission.child_context_id
    where context_permission.id = guardian_context_permission_id
      and (
        guardian.guardian_person_id = app_private.current_person_id()
        or app_private.has_context_permission(
          child_context.institution_id, 'family.read',
          null, null, null, child_context.id, false
        )
      )
  )
);
create policy guardian_context_permission_grants_manage
on public.guardian_context_permission_grants for all to authenticated
using (
  exists (
    select 1 from public.guardian_context_permissions context_permission
    join public.child_contexts child_context on child_context.id = context_permission.child_context_id
    where context_permission.id = guardian_context_permission_id
      and app_private.has_context_permission(
        child_context.institution_id, 'family.manage',
        null, null, null, child_context.id, false
      )
  )
)
with check (
  exists (
    select 1 from public.guardian_context_permissions context_permission
    join public.child_contexts child_context on child_context.id = context_permission.child_context_id
    where context_permission.id = guardian_context_permission_id
      and app_private.has_context_permission(
        child_context.institution_id, 'family.manage',
        null, null, null, child_context.id, false
      )
  )
);

create policy authorized_people_context_read on public.authorized_people
for select to authenticated using (
  exists (
    select 1 from public.authorized_person_authorizations authorization_row
    where authorization_row.authorized_person_id = id
      and (
        app_private.guardian_has_capability(
          authorization_row.child_context_id, 'manage_authorized_people'
        )
        or app_private.has_context_permission(
          authorization_row.institution_id, 'family.read', authorization_row.unit_id,
          null, null, authorization_row.child_context_id, false
        )
      )
  )
);
create policy authorized_person_authorizations_context_read
on public.authorized_person_authorizations for select to authenticated
using (
  app_private.guardian_has_capability(child_context_id, 'manage_authorized_people')
  or app_private.has_context_permission(
    institution_id, 'family.read', unit_id, null, null, child_context_id, false
  )
);
create policy authorized_person_authorization_capabilities_context_read
on public.authorized_person_authorization_capabilities for select to authenticated
using (
  exists (
    select 1 from public.authorized_person_authorizations authorization_row
    where authorization_row.id = authorization_id
      and (
        app_private.guardian_has_capability(
          authorization_row.child_context_id, 'manage_authorized_people'
        )
        or app_private.has_context_permission(
          authorization_row.institution_id, 'family.read', authorization_row.unit_id,
          null, null, authorization_row.child_context_id, false
        )
      )
  )
);

create policy context_notification_events_recipient_read
on public.context_notification_events for select to authenticated
using (
  exists (
    select 1 from public.context_notification_recipients recipient
    where recipient.event_id = id
      and recipient.person_id = app_private.current_person_id()
  )
  or app_private.has_context_permission(
    institution_id, 'family.read', unit_id, group_id, activity_id,
    child_context_id, false
  )
);
create policy context_notification_recipients_own_read
on public.context_notification_recipients for select to authenticated
using (person_id = app_private.current_person_id());
create policy context_notification_recipients_own_update
on public.context_notification_recipients for update to authenticated
using (person_id = app_private.current_person_id())
with check (person_id = app_private.current_person_id());

create policy child_unit_transfer_requests_context_read
on public.child_unit_transfer_requests for select to authenticated
using (
  app_private.has_context_permission(
    institution_id, 'transfers.manage', source_unit_id, null, null, null, false
  )
  or app_private.has_context_permission(
    institution_id, 'transfers.manage', destination_unit_id, null, null, null, false
  )
);
create policy child_unit_transfer_requests_context_insert
on public.child_unit_transfer_requests for insert to authenticated
with check (
  app_private.has_context_permission(
    institution_id, 'transfers.manage', source_unit_id, null, null, null, false
  )
);
create policy child_unit_transfer_items_context_read
on public.child_unit_transfer_items for select to authenticated
using (
  exists (
    select 1 from public.child_unit_transfer_requests request_record
    where request_record.id = transfer_request_id
      and (
        app_private.has_context_permission(
          request_record.institution_id, 'transfers.manage',
          request_record.source_unit_id, null, null, null, false
        )
        or app_private.has_context_permission(
          request_record.institution_id, 'transfers.manage',
          request_record.destination_unit_id, null, null, null, false
        )
      )
  )
);
create policy child_unit_transfer_items_context_insert
on public.child_unit_transfer_items for insert to authenticated
with check (
  exists (
    select 1 from public.child_unit_transfer_requests request_record
    where request_record.id = transfer_request_id
      and app_private.has_context_permission(
        request_record.institution_id, 'transfers.manage',
        request_record.source_unit_id, null, null, null, false
      )
  )
);

create policy guardian_invitation_children_context_read
on public.guardian_invitation_children for select to authenticated
using (
  exists (
    select 1 from public.child_contexts child_context
    where child_context.id = guardian_invitation_children.child_context_id
      and app_private.has_context_permission(
        child_context.institution_id, 'family.read',
        null, null, null, child_context.id, false
      )
  )
);
create policy guardian_invitation_children_context_insert
on public.guardian_invitation_children for insert to authenticated
with check (
  exists (
    select 1 from public.invitations invitation
    join public.child_contexts child_context
      on child_context.id = guardian_invitation_children.child_context_id
    where invitation.id = guardian_invitation_children.invitation_id
      and invitation.institution_id = child_context.institution_id
      and app_private.has_context_permission(
        child_context.institution_id, 'family.manage', invitation.unit_id,
        invitation.group_id, null, child_context.id, invitation.unit_id is null
      )
  )
);

revoke all on function app_private.guardian_has_capability(uuid,text)
  from public, anon;
grant execute on function app_private.guardian_has_capability(uuid,text)
  to authenticated, service_role;
revoke all on function app_private.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) from public, anon;
grant execute on function app_private.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) to authenticated, service_role;
revoke all on function public.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) from public, anon;
grant execute on function public.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) to authenticated;
revoke all on function app_private.suspend_authorized_person_authorization(uuid,text)
  from public, anon;
grant execute on function app_private.suspend_authorized_person_authorization(uuid,text)
  to authenticated, service_role;
revoke all on function public.suspend_authorized_person_authorization(uuid,text)
  from public, anon;
grant execute on function public.suspend_authorized_person_authorization(uuid,text)
  to authenticated;
revoke all on function app_private.decide_child_unit_transfer(uuid,text,text)
  from public, anon;
grant execute on function app_private.decide_child_unit_transfer(uuid,text,text)
  to authenticated, service_role;
revoke all on function public.decide_child_unit_transfer(uuid,text,text)
  from public, anon;
grant execute on function public.decide_child_unit_transfer(uuid,text,text)
  to authenticated;
revoke all on function app_private.validate_family_context_row()
  from public, anon, authenticated;

with table_catalog(table_name, table_label, table_description, domain) as (
  values
    ('family_relationship_types','Tipos de vinculo familiar','Catalogo normalizado de vinculos.','family'),
    ('guardian_permission_capabilities','Capacidades familiares','Catalogo de capacidades do responsavel.','family'),
    ('guardian_context_permission_grants','Permissoes familiares','Matriz normalizada por responsavel e crianca.','family'),
    ('guardian_invitation_children','Criancas do convite','Vinculo e capacidades por crianca convidada.','family'),
    ('authorized_people','Pessoas autorizadas','Identificacao protegida sem acesso ao app.','family'),
    ('authorized_person_authorizations','Autorizacoes operacionais','Autorizacao por crianca e unidade.','family'),
    ('authorized_person_authorization_capabilities','Tipos de autorizacao','Emergencia, retirada e transporte.','family'),
    ('context_notification_events','Eventos de notificacao','Outbox contextual minimizada.','notifications'),
    ('context_notification_recipients','Destinatarios de notificacao','Entrega e leitura por pessoa.','notifications'),
    ('child_unit_transfer_requests','Transferencias de unidade','Solicitacao e decisao pelo destino.','tenancy'),
    ('child_unit_transfer_items','Criancas da transferencia','Itens processados em lote.','tenancy')
)
insert into public.schema_tables(
  schema_name,table_name,table_label,table_description,domain,status,version,updated_at
)
select 'public',table_name,table_label,table_description,domain,'active',1,now()
from table_catalog
on conflict (schema_name,table_name,version) do update set
  table_label=excluded.table_label,table_description=excluded.table_description,
  domain=excluded.domain,status=excluded.status,updated_at=now();

insert into public.schema_columns(
  schema_table_id,column_name,column_label,column_description,column_type,
  is_required,is_nullable,is_unique,is_filterable,is_importable,is_active,
  position,allowed_locales_json,aliases_json,examples_json,updated_at
)
select st.id,c.column_name,replace(c.column_name,'_',' '),
  'Campo contextual '||c.column_name||'.',c.data_type,c.is_nullable='NO',
  c.is_nullable='YES',false,c.column_name in (
    'institution_id','unit_id','group_id','child_context_id','status','event_code'
  ),false,true,c.ordinal_position,'["pt-BR"]'::jsonb,'{}'::jsonb,'[]'::jsonb,now()
from information_schema.columns c
join public.schema_tables st on st.schema_name=c.table_schema
  and st.table_name=c.table_name and st.version=1
where c.table_schema='public' and c.table_name in (
  'family_relationship_types','guardian_permission_capabilities',
  'guardian_context_permission_grants','guardian_invitation_children',
  'authorized_people','authorized_person_authorizations',
  'authorized_person_authorization_capabilities','context_notification_events',
  'context_notification_recipients','child_unit_transfer_requests',
  'child_unit_transfer_items'
)
on conflict (schema_table_id,column_name) do update set
  column_type=excluded.column_type,is_required=excluded.is_required,
  is_nullable=excluded.is_nullable,is_filterable=excluded.is_filterable,
  is_active=true,position=excluded.position,updated_at=now();
