-- Child safety production schema: global identity, contextual authorization,
-- independent approval/lifecycle, restrictions, alerts and private evidence.

do $$ begin
  create type public.child_safety_decision_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.child_safety_severity as enum ('information','attention','high','critical');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.child_safety_alert_status as enum ('open','acknowledged','resolved');
exception when duplicate_object then null; end $$;

alter table public.authorized_people
  add column if not exists person_id uuid references public.people(id) on delete restrict,
  add column if not exists owner_guardian_person_id uuid references public.people(id) on delete restrict;

drop index if exists public.authorized_people_owner_person_uidx;
create unique index authorized_people_owner_person_uidx
  on public.authorized_people(institution_id, owner_guardian_person_id, person_id)
  where owner_guardian_person_id is not null and person_id is not null and status <> 'archived';
create index if not exists authorized_people_person_idx
  on public.authorized_people(person_id) where person_id is not null;

alter table public.authorized_person_authorizations
  add column if not exists decision_status public.child_safety_decision_status,
  add column if not exists decision_reason text,
  add column if not exists decided_by_person_id uuid references public.people(id) on delete restrict,
  add column if not exists decided_at timestamptz,
  add column if not exists version bigint not null default 1,
  add column if not exists request_reason text;

-- Existing authorizations predate unit review. Preserve them as approved while
-- making the migration safe on databases that already contain production rows.
update public.authorized_person_authorizations
set decision_status = coalesce(decision_status, 'approved'::public.child_safety_decision_status),
    decided_by_person_id = coalesce(decided_by_person_id, created_by_person_id),
    decided_at = coalesce(decided_at, updated_at, created_at),
    decision_reason = coalesce(nullif(btrim(decision_reason), ''), 'Migrated legacy authorization')
where decision_status is null
   or (decision_status = 'approved' and (
     decided_by_person_id is null or decided_at is null
     or nullif(btrim(decision_reason), '') is null
   ));

alter table public.authorized_person_authorizations
  alter column decision_status set default 'pending',
  alter column decision_status set not null;

alter table public.authorized_person_authorizations
  drop constraint if exists authorized_person_authorizations_decision_check,
  add constraint authorized_person_authorizations_decision_check check (
    (decision_status = 'pending' and decided_by_person_id is null and decided_at is null and decision_reason is null)
    or (decision_status in ('approved','rejected') and decided_by_person_id is not null
      and decided_at is not null and nullif(btrim(decision_reason), '') is not null)
  ),
  drop constraint if exists authorized_person_authorizations_version_check,
  add constraint authorized_person_authorizations_version_check check (version > 0),
  drop constraint if exists authorized_person_authorizations_request_reason_check,
  add constraint authorized_person_authorizations_request_reason_check
    check (request_reason is null or char_length(btrim(request_reason)) between 3 and 500);

create index if not exists authorized_person_authorizations_directory_idx
  on public.authorized_person_authorizations(
    institution_id, unit_id, decision_status, status, created_at desc, child_context_id
  );
create index if not exists authorized_person_authorizations_person_idx
  on public.authorized_person_authorizations(authorized_person_id, child_context_id, unit_id);

create table if not exists public.child_safety_restrictions (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  restriction_code text not null check (restriction_code ~ '^[a-z][a-z0-9_]{2,63}$'),
  title text not null check (char_length(btrim(title)) between 3 and 120),
  description text not null check (char_length(btrim(description)) between 3 and 1000),
  severity public.child_safety_severity not null,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  status public.record_status not null default 'active',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  updated_by_person_id uuid not null references public.people(id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint child_safety_restrictions_validity_check
    check (valid_until is null or valid_until > valid_from)
);
create index if not exists child_safety_restrictions_context_idx
  on public.child_safety_restrictions(
    institution_id, unit_id, child_context_id, status, severity, valid_from desc
  );

create table if not exists public.child_safety_alerts (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  authorization_id uuid references public.authorized_person_authorizations(id) on delete cascade,
  restriction_id uuid references public.child_safety_restrictions(id) on delete cascade,
  event_code text not null check (event_code ~ '^[a-z][a-z0-9_.]{2,79}$'),
  severity public.child_safety_severity not null,
  status public.child_safety_alert_status not null default 'open',
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  acknowledged_by_person_id uuid references public.people(id) on delete restrict,
  acknowledged_at timestamptz,
  resolution_reason text,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint child_safety_alerts_subject_check check (
    num_nonnulls(authorization_id, restriction_id) = 1
  ),
  constraint child_safety_alerts_ack_check check (
    (status = 'open' and acknowledged_by_person_id is null and acknowledged_at is null)
    or (status <> 'open' and acknowledged_by_person_id is not null and acknowledged_at is not null)
  )
);
create index if not exists child_safety_alerts_context_idx
  on public.child_safety_alerts(
    institution_id, unit_id, child_context_id, status, severity, created_at desc
  );

create table if not exists public.child_safety_evidence (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  child_context_id uuid not null references public.child_contexts(id) on delete cascade,
  authorization_id uuid references public.authorized_person_authorizations(id) on delete cascade,
  restriction_id uuid references public.child_safety_restrictions(id) on delete cascade,
  alert_id uuid references public.child_safety_alerts(id) on delete cascade,
  bucket_id text not null default 'child-safety-evidence'
    check (bucket_id = 'child-safety-evidence'),
  object_path text not null check (
    object_path ~ '^child-safety/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]{2,8}$'
  ),
  file_name text not null check (char_length(btrim(file_name)) between 1 and 180),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','application/pdf')),
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  checksum_sha256 text not null check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  status public.record_status not null default 'draft',
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint child_safety_evidence_exactly_one_subject_check check (
    num_nonnulls(authorization_id, restriction_id, alert_id) = 1
  ),
  unique(bucket_id, object_path)
);
create index if not exists child_safety_evidence_context_idx
  on public.child_safety_evidence(institution_id, unit_id, child_context_id, created_at desc);

create table if not exists app_private.child_safety_command_receipts (
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  command_code text not null,
  request_hash bytea not null,
  target_id uuid,
  response_json jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  constraint child_safety_command_receipts_expiry_check check (expires_at > created_at)
);
create index if not exists child_safety_command_receipts_expiry_idx
  on app_private.child_safety_command_receipts(expires_at);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'child-safety-evidence', 'child-safety-evidence', false, 10485760,
  array['image/jpeg','image/png','application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
  ('child_safety.read','child_safety','directory','read',
   'Visualizar segurança da criança no escopo autorizado.','critical',true,'active'),
  ('child_safety.manage','child_safety','management','manage',
   'Gerenciar autorizações, restrições e alertas infantis.','critical',true,'active'),
  ('child_safety.export','child_safety','files','export',
   'Exportar dados minimizados de segurança da criança.','critical',true,'active')
on conflict (code) do update set
  module_code=excluded.module_code,screen_code=excluded.screen_code,
  action_code=excluded.action_code,description=excluded.description,
  risk_level=excluded.risk_level,requires_mfa=true,status='active',updated_at=now();

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in ('child_safety.read','child_safety.manage','child_safety.export')
where role_record.code='owner'
on conflict (role_id,permission_id) do update set effect='allow',status='active',revoked_at=null,updated_at=now();

create or replace function app_private.validate_child_safety_context()
returns trigger language plpgsql security definer set search_path=''
as $$ begin
  if not exists (
    select 1 from public.child_contexts child_context
    join public.child_unit_links child_unit
      on child_unit.child_context_id=child_context.id and child_unit.unit_id=new.unit_id
     and child_unit.status in ('active','awaiting_allocation')
    join public.units unit_record on unit_record.id=new.unit_id
    where child_context.id=new.child_context_id
      and child_context.institution_id=new.institution_id
      and unit_record.institution_id=new.institution_id
  ) then raise check_violation using message='invalid child safety context'; end if;
  return new;
end $$;
revoke all on function app_private.validate_child_safety_context() from public,anon,authenticated;

drop trigger if exists child_safety_restrictions_validate on public.child_safety_restrictions;
create trigger child_safety_restrictions_validate before insert or update
on public.child_safety_restrictions for each row execute function app_private.validate_child_safety_context();
drop trigger if exists child_safety_alerts_validate on public.child_safety_alerts;
create trigger child_safety_alerts_validate before insert or update
on public.child_safety_alerts for each row execute function app_private.validate_child_safety_context();
drop trigger if exists child_safety_evidence_validate on public.child_safety_evidence;
create trigger child_safety_evidence_validate before insert or update
on public.child_safety_evidence for each row execute function app_private.validate_child_safety_context();

alter table public.authorized_people enable row level security;
alter table public.authorized_people force row level security;
alter table public.authorized_person_authorizations enable row level security;
alter table public.authorized_person_authorizations force row level security;
alter table public.authorized_person_authorization_capabilities enable row level security;
alter table public.authorized_person_authorization_capabilities force row level security;
alter table public.child_safety_restrictions enable row level security;
alter table public.child_safety_restrictions force row level security;
alter table public.child_safety_alerts enable row level security;
alter table public.child_safety_alerts force row level security;
alter table public.child_safety_evidence enable row level security;
alter table public.child_safety_evidence force row level security;

revoke all on public.child_safety_restrictions,public.child_safety_alerts,
  public.child_safety_evidence from public,anon,authenticated;
grant select on public.child_safety_restrictions,public.child_safety_alerts,
  public.child_safety_evidence to authenticated;
grant all on public.child_safety_restrictions,public.child_safety_alerts,
  public.child_safety_evidence to service_role;

drop policy if exists authorized_people_context_read on public.authorized_people;
create policy authorized_people_context_read on public.authorized_people
for select to authenticated using (
  exists (
    select 1 from public.authorized_person_authorizations authorization_row
    where authorization_row.authorized_person_id=authorized_people.id
      and (
        app_private.guardian_has_capability(authorization_row.child_context_id,'manage_authorized_people')
        or app_private.has_context_permission(
          authorization_row.institution_id,'family.read',authorization_row.unit_id,
          null,null,authorization_row.child_context_id,false
        )
        or app_private.has_platform_permission('child_safety.read')
      )
  )
);

create policy child_safety_restrictions_context_read on public.child_safety_restrictions
for select to authenticated using (
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(
    institution_id,'family.read',unit_id,null,null,child_context_id,false
  )
);
create policy child_safety_alerts_context_read on public.child_safety_alerts
for select to authenticated using (
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(
    institution_id,'family.read',unit_id,null,null,child_context_id,false
  )
);
create policy child_safety_evidence_context_read on public.child_safety_evidence
for select to authenticated using (
  app_private.has_platform_permission('child_safety.read')
  or app_private.has_context_permission(
    institution_id,'family.read',unit_id,null,null,child_context_id,false
  )
);

revoke all on function app_private.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) from public,anon,authenticated;
revoke all on function public.create_authorized_person_authorization(
  uuid,uuid,text,text,text,bytea,text,text,text,text[],date,date
) from public,anon,authenticated;
revoke all on function app_private.suspend_authorized_person_authorization(uuid,text)
  from public,anon,authenticated;
revoke all on function public.suspend_authorized_person_authorization(uuid,text)
  from public,anon,authenticated;

revoke all on app_private.child_safety_command_receipts from public,anon,authenticated;
grant all on app_private.child_safety_command_receipts to service_role;
