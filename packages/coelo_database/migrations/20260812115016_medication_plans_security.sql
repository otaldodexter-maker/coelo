-- Medication plans: health data, schedules, execution and private assets.
-- Activation remains fail-closed until the legal health-processing gate is approved.
begin;

create table public.medication_plans (
  id uuid primary key default gen_random_uuid(),
  child_person_id uuid not null references public.people(id) on delete restrict,
  scope_kind text not null check (scope_kind in ('home','institution')),
  institution_id uuid references public.institutions(id) on delete restrict,
  unit_id uuid references public.units(id) on delete restrict,
  group_id uuid references public.groups(id) on delete restrict,
  child_context_id uuid references public.child_contexts(id) on delete restrict,
  status text not null default 'draft'
    check (status in ('draft','active','suspended','ended')),
  current_version bigint not null default 1 check (current_version > 0),
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  updated_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medication_plans_scope_check check (
    (scope_kind='home' and institution_id is null and unit_id is null
      and group_id is null and child_context_id is null)
    or (scope_kind='institution' and institution_id is not null
      and child_context_id is not null)
  )
);
create index medication_plans_child_status_idx
  on public.medication_plans(child_person_id,status,updated_at desc);
create index medication_plans_institution_directory_idx
  on public.medication_plans(institution_id,unit_id,group_id,status,updated_at desc)
  where institution_id is not null;
create unique index medication_plans_id_child_uidx
  on public.medication_plans(id,child_person_id);

create table public.medication_plan_versions (
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  version bigint not null check (version > 0),
  medication_name text not null check (char_length(btrim(medication_name)) between 2 and 160),
  dose_amount numeric(12,4) not null check (dose_amount > 0),
  dose_unit text not null check (dose_unit in ('mg','mcg','g','ml','unit','drop','tablet','capsule')),
  administration_route text not null
    check (administration_route in ('oral','topical','inhaled','nasal','ocular','otic','subcutaneous','intramuscular')),
  route_details text check (route_details is null or char_length(btrim(route_details)) between 2 and 200),
  valid_from date not null,
  valid_until date,
  timezone text not null check (timezone ~ '^[A-Za-z_]+/[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)?$'),
  instructions text check (instructions is null or char_length(instructions) <= 2000),
  change_reason text not null check (char_length(btrim(change_reason)) between 3 and 500),
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(plan_id,version),
  constraint medication_plan_versions_period_check
    check (valid_until is null or valid_until >= valid_from)
);

create table public.medication_schedules (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null,
  plan_version bigint not null,
  time_of_day time without time zone not null,
  frequency_kind text not null default 'weekly'
    check (frequency_kind in ('daily','weekly','as_needed')),
  start_date date not null,
  end_date date,
  max_occurrences_per_day smallint check (max_occurrences_per_day between 1 and 24),
  created_at timestamptz not null default now(),
  foreign key(plan_id,plan_version)
    references public.medication_plan_versions(plan_id,version) on delete cascade,
  constraint medication_schedules_period_check check (end_date is null or end_date >= start_date),
  unique(plan_id,plan_version,id)
);
create index medication_schedules_plan_version_idx
  on public.medication_schedules(plan_id,plan_version,time_of_day);

create table public.medication_schedule_weekdays (
  schedule_id uuid not null references public.medication_schedules(id) on delete cascade,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  primary key(schedule_id,iso_weekday)
);

create table public.medication_plan_reviews (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  plan_version bigint not null,
  decision text not null check (decision in ('pending','approved','rejected')),
  reason text check (reason is null or char_length(btrim(reason)) between 3 and 500),
  reviewed_by_person_id uuid references public.people(id) on delete restrict,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key(plan_id,plan_version)
    references public.medication_plan_versions(plan_id,version) on delete cascade,
  constraint medication_plan_reviews_decision_check check (
    (decision='pending' and reviewed_by_person_id is null and reviewed_at is null)
    or (decision in ('approved','rejected') and reviewed_by_person_id is not null
      and reviewed_at is not null and reason is not null)
  )
);
create index medication_plan_reviews_plan_idx
  on public.medication_plan_reviews(plan_id,created_at desc);

create table public.medication_plan_responsibles (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete restrict,
  membership_id uuid references public.institution_memberships(id) on delete restrict,
  status text not null default 'active' check (status in ('active','revoked')),
  added_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(plan_id,person_id),
  constraint medication_plan_responsibles_status_check check (
    (status='active' and revoked_at is null) or (status='revoked' and revoked_at is not null)
  )
);
create index medication_plan_responsibles_person_idx
  on public.medication_plan_responsibles(person_id,status,plan_id);

create table public.medication_plan_suspensions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  plan_version bigint not null,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  suspended_by_person_id uuid not null references public.people(id) on delete restrict,
  suspended_at timestamptz not null default now(),
  foreign key(plan_id,plan_version)
    references public.medication_plan_versions(plan_id,version) on delete restrict
);

create table public.medication_dose_occurrences (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  plan_version bigint not null,
  schedule_id uuid,
  scheduled_for timestamptz not null,
  status text not null default 'scheduled'
    check (status in ('scheduled','claimed','administered','omitted','refused','paused','late')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key(plan_id,plan_version)
    references public.medication_plan_versions(plan_id,version) on delete restrict,
  foreign key(plan_id,plan_version,schedule_id)
    references public.medication_schedules(plan_id,plan_version,id) on delete restrict,
  unique(plan_id,scheduled_for)
);
create index medication_dose_occurrences_agenda_idx
  on public.medication_dose_occurrences(plan_id,status,scheduled_for);

create table public.medication_administration_events (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references public.medication_dose_occurrences(id) on delete restrict,
  event_kind text not null check (event_kind in ('administration','omission','refusal','correction')),
  reason text check (reason is null or char_length(btrim(reason)) between 2 and 500),
  notes text check (notes is null or char_length(notes) <= 2000),
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  actor_person_id uuid not null references public.people(id) on delete restrict,
  corrects_event_id uuid references public.medication_administration_events(id) on delete restrict,
  request_id uuid not null,
  constraint medication_administration_events_correction_check check (
    (event_kind='correction' and corrects_event_id is not null and reason is not null)
    or (event_kind<>'correction' and corrects_event_id is null)
  ),
  unique(actor_person_id,request_id)
);
create index medication_administration_events_occurrence_idx
  on public.medication_administration_events(occurrence_id,recorded_at);

create table public.medication_assets (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.medication_plans(id) on delete cascade,
  asset_kind text not null check (asset_kind in ('medication_image','prescription')),
  storage_bucket text not null default 'coelo-medication-private'
    check (storage_bucket='coelo-medication-private'),
  storage_path text not null unique,
  mime_type text not null,
  size_bytes bigint not null,
  checksum_sha256 text check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  status text not null default 'pending_upload'
    check (status in ('pending_upload','active','revoked')),
  created_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  revoked_at timestamptz,
  constraint medication_assets_lifecycle_check check (
    (status='pending_upload' and activated_at is null and revoked_at is null)
    or (status='active' and activated_at is not null and revoked_at is null)
    or (status='revoked' and revoked_at is not null)
  )
);
create index medication_assets_plan_idx on public.medication_assets(plan_id,status,asset_kind);

create table public.medication_transfer_jobs (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid references public.institutions(id) on delete restrict,
  child_person_id uuid references public.people(id) on delete restrict,
  job_kind text not null check (job_kind in ('import','export')),
  template_version text not null check (template_version ~ '^medication-v[0-9]+$'),
  status text not null default 'pending'
    check (status in ('pending','validating','awaiting_confirmation','processing','completed','failed','cancelled')),
  source_asset_id uuid references public.medication_assets(id) on delete restrict,
  requested_by_person_id uuid not null references public.people(id) on delete restrict,
  error_summary text,
  result_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);
create index medication_transfer_jobs_requester_idx
  on public.medication_transfer_jobs(requested_by_person_id,status,created_at desc);

create table app_private.medication_command_receipts (
  actor_person_id uuid not null references public.people(id) on delete cascade,
  request_id uuid not null,
  command_code text not null,
  request_hash bytea not null,
  response_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key(actor_person_id,request_id)
);
create table app_private.medication_upload_intents (
  request_id uuid primary key,
  asset_id uuid not null unique references public.medication_assets(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  storage_path text not null unique,
  expires_at timestamptz not null default (now()+interval '15 minutes'),
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);
create index medication_upload_intents_actor_expiry_idx
  on app_private.medication_upload_intents(actor_person_id,expires_at);

insert into public.institution_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
 ('medication.read','medication','plans','read','Read medication plans in an authorized child scope.','critical',true,'active'),
 ('medication.manage','medication','plans','manage','Create, update and suspend medication plans.','critical',true,'active'),
 ('medication.administer','medication','administration','administer','Record medication administration events.','critical',true,'active'),
 ('medication.export','medication','files','export','Export minimized medication data.','critical',true,'active')
on conflict(code) do update set description=excluded.description,risk_level='critical',
  requires_mfa=true,status='active',updated_at=now();

create or replace function app_private.medication_release_ready()
returns boolean language sql stable security definer set search_path=''
as $$ select app_private.health_domain_is_release_ready() $$;

create or replace function app_private.validate_medication_scope()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
  if not exists(select 1 from public.people p where p.id=new.child_person_id and p.person_type='child') then
    raise check_violation using message='invalid medication child';
  end if;
  if new.scope_kind='institution' and not exists(
    select 1 from public.child_contexts c
    where c.id=new.child_context_id and c.child_person_id=new.child_person_id
      and c.institution_id=new.institution_id and c.status='active'
      and (new.unit_id is null or exists(select 1 from public.child_unit_links ul
        where ul.child_context_id=c.id and ul.unit_id=new.unit_id and ul.status='active'))
      and (new.group_id is null or exists(select 1 from public.child_group_links gl
        join public.child_unit_links ul on ul.id=gl.child_unit_link_id
        where ul.child_context_id=c.id and gl.group_id=new.group_id and gl.status='active'))
  ) then raise check_violation using message='invalid medication institutional scope'; end if;
  return new;
end $$;
create trigger medication_plans_scope_validate before insert or update
on public.medication_plans for each row execute function app_private.validate_medication_scope();

create or replace function app_private.keep_medication_child_immutable()
returns trigger language plpgsql security invoker set search_path=''
as $$ begin
 if new.child_person_id<>old.child_person_id or new.scope_kind<>old.scope_kind
    or new.institution_id is distinct from old.institution_id
    or new.unit_id is distinct from old.unit_id
    or new.group_id is distinct from old.group_id
    or new.child_context_id is distinct from old.child_context_id then
   raise check_violation using message='medication child and ownership scope are immutable';
 end if; return new;
end $$;
create trigger medication_plans_child_immutable before update on public.medication_plans
for each row execute function app_private.keep_medication_child_immutable();

create or replace function app_private.reject_medication_event_mutation()
returns trigger language plpgsql security invoker set search_path=''
as $$ begin raise check_violation using message='medication event history is append-only'; end $$;
create trigger medication_reviews_append_only before update or delete on public.medication_plan_reviews
for each row execute function app_private.reject_medication_event_mutation();
create trigger medication_suspensions_append_only before update or delete on public.medication_plan_suspensions
for each row execute function app_private.reject_medication_event_mutation();
create trigger medication_administration_append_only before update or delete on public.medication_administration_events
for each row execute function app_private.reject_medication_event_mutation();

create or replace function app_private.can_read_medication_plan(p_plan_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$
 select app_private.medication_release_ready() and exists(
  select 1 from public.medication_plans p where p.id=p_plan_id and (
   exists(select 1 from public.guardian_links g
    where g.guardian_person_id=app_private.current_person_id()
      and g.child_person_id=p.child_person_id and g.status='active' and g.revoked_at is null)
   or (p.scope_kind='institution' and app_private.has_context_permission(
      p.institution_id,'medication.read',p.unit_id,p.group_id,null,p.child_context_id,false))
   or exists(select 1 from public.medication_plan_responsibles r
      where r.plan_id=p.id and r.person_id=app_private.current_person_id() and r.status='active')
  ))
$$;

create or replace function app_private.assert_medication_write_access(
  p_plan_id uuid,p_institution_id uuid,p_child_context_id uuid,p_child_person_id uuid
) returns void language plpgsql stable security definer set search_path=''
as $$
begin
 if (select auth.uid()) is null then raise insufficient_privilege using message='not found'; end if;
 if not app_private.medication_release_ready() then
   raise insufficient_privilege using message='medication feature unavailable';
 end if;
 if coalesce((select auth.jwt()->>'aal'),'')<>'aal2' then
   raise insufficient_privilege using message='strong authentication required';
 end if;
 if p_institution_id is null then
   if not exists(select 1 from public.guardian_links g where
      g.guardian_person_id=app_private.current_person_id() and g.child_person_id=p_child_person_id
      and g.status='active' and g.revoked_at is null) then
     raise insufficient_privilege using message='not found';
   end if;
 else
   if not app_private.has_context_permission(p_institution_id,'medication.manage',null,null,null,p_child_context_id,false)
      or not exists(select 1 from public.professional_child_assignments a
        join public.institution_memberships m on m.id=a.membership_id
        where a.child_context_id=p_child_context_id and a.status='active' and a.revoked_at is null
          and m.person_id=app_private.current_person_id() and m.institution_id=p_institution_id
          and m.status='active' and m.revoked_at is null) then
     raise insufficient_privilege using message='not found';
   end if;
 end if;
 if p_plan_id is not null and not exists(select 1 from public.medication_plans p
   where p.id=p_plan_id and p.child_person_id=p_child_person_id
     and p.institution_id is not distinct from p_institution_id
     and p.child_context_id is not distinct from p_child_context_id) then
   raise insufficient_privilege using message='not found';
 end if;
end $$;

create or replace function app_private.validate_medication_storage_object(
 p_path text,p_mime text,p_size bigint
) returns boolean language sql immutable set search_path=''
as $$ select coalesce(
 p_path ~ '^medication/[0-9a-f-]{36}/[0-9a-f-]{36}/(medication_image|prescription)/[0-9a-f-]{36}\.(jpg|jpeg|png|webp|pdf)$'
 and p_mime in ('image/jpeg','image/png','image/webp','application/pdf')
 and p_size between 1 and case when p_mime='application/pdf' then 10485760 else 5242880 end,false) $$;

create or replace function app_private.has_medication_upload_intent(p_path text)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from app_private.medication_upload_intents i
 where i.storage_path=p_path and i.actor_person_id=app_private.current_person_id()
   and i.expires_at>now() and i.consumed_at is null) $$;

create or replace function app_private.medication_receipt(
 p_request_id uuid,p_command text,p_payload jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ declare actor uuid:=app_private.current_person_id(); prior app_private.medication_command_receipts%rowtype;
begin
 select * into prior from app_private.medication_command_receipts r
  where r.actor_person_id=actor and r.request_id=p_request_id;
 if found then
  if prior.command_code<>p_command or prior.request_hash<>extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256') then
   raise unique_violation using message='idempotency key reused'; end if;
  return prior.response_json;
 end if;
 return null;
end $$;

create or replace function app_private.save_medication_receipt(
 p_request_id uuid,p_command text,p_payload jsonb,p_response jsonb
) returns jsonb language plpgsql security definer set search_path=''
as $$ begin
 insert into app_private.medication_command_receipts(actor_person_id,request_id,command_code,request_hash,response_json)
 values(app_private.current_person_id(),p_request_id,p_command,extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256'),p_response);
 return p_response;
end $$;

create or replace function public.create_medication_plan(p_request_id uuid,p_payload jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare p public.medication_plans%rowtype; prior jsonb; schedule jsonb; schedule_id uuid; response jsonb;
begin
 prior:=app_private.medication_receipt(p_request_id,'create',p_payload); if prior is not null then return prior; end if;
 if jsonb_typeof(p_payload->'schedules') <> 'array'
    or jsonb_array_length(p_payload->'schedules') = 0 then
   raise invalid_parameter_value using message='at least one schedule is required'; end if;
 perform app_private.assert_medication_write_access(null,nullif(p_payload->>'institution_id','')::uuid,
   nullif(p_payload->>'child_context_id','')::uuid,(p_payload->>'child_person_id')::uuid);
 insert into public.medication_plans(child_person_id,scope_kind,institution_id,unit_id,group_id,child_context_id,
   status,created_by_person_id,updated_by_person_id)
 values((p_payload->>'child_person_id')::uuid,p_payload->>'scope_kind',nullif(p_payload->>'institution_id','')::uuid,
   nullif(p_payload->>'unit_id','')::uuid,nullif(p_payload->>'group_id','')::uuid,
   nullif(p_payload->>'child_context_id','')::uuid,'draft',app_private.current_person_id(),app_private.current_person_id()) returning * into p;
 insert into public.medication_plan_versions(plan_id,version,medication_name,dose_amount,dose_unit,administration_route,
   route_details,valid_from,valid_until,timezone,instructions,change_reason,created_by_person_id)
 values(p.id,1,p_payload->>'medication_name',(p_payload->>'dose_amount')::numeric,p_payload->>'dose_unit',
   p_payload->>'administration_route',nullif(p_payload->>'route_details',''),(p_payload->>'valid_from')::date,
   nullif(p_payload->>'valid_until','')::date,p_payload->>'timezone',nullif(p_payload->>'instructions',''),
   coalesce(nullif(p_payload->>'change_reason',''),'Initial medication plan'),app_private.current_person_id());
 for schedule in select value from jsonb_array_elements(coalesce(p_payload->'schedules','[]'::jsonb)) loop
   insert into public.medication_schedules(plan_id,plan_version,time_of_day,frequency_kind,start_date,end_date,max_occurrences_per_day)
   values(p.id,1,(schedule->>'time_of_day')::time,schedule->>'frequency_kind',(schedule->>'start_date')::date,
     nullif(schedule->>'end_date','')::date,nullif(schedule->>'max_occurrences_per_day','')::smallint) returning id into schedule_id;
   insert into public.medication_schedule_weekdays(schedule_id,iso_weekday)
   select schedule_id,value::smallint from jsonb_array_elements_text(coalesce(schedule->'weekdays','[]'::jsonb));
 end loop;
 response:=jsonb_build_object('id',p.id,'version',1,'status',p.status);
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,after_json)
 values(app_private.current_person_id(),'aal2','medication.plan.create','medication_plan',p.id,p.institution_id,response);
 return app_private.save_medication_receipt(p_request_id,'create',p_payload,response);
exception when invalid_text_representation or datetime_field_overflow or check_violation or not_null_violation or foreign_key_violation then
 raise invalid_parameter_value using message='invalid medication payload'; end $$;

create or replace function public.update_medication_plan(
 p_request_id uuid,p_plan_id uuid,p_expected_version bigint,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare p public.medication_plans%rowtype; prior jsonb; next_version bigint; response jsonb; schedule jsonb; schedule_id uuid;
begin
 prior:=app_private.medication_receipt(p_request_id,'update',jsonb_build_object('plan_id',p_plan_id,'expected',p_expected_version,'payload',p_payload));
 if prior is not null then return prior; end if;
 if jsonb_typeof(p_payload->'schedules') <> 'array'
    or jsonb_array_length(p_payload->'schedules') = 0 then
   raise invalid_parameter_value using message='at least one schedule is required'; end if;
 select * into p from public.medication_plans where id=p_plan_id for update;
 if not found then raise insufficient_privilege using message='not found'; end if;
 perform app_private.assert_medication_write_access(p.id,p.institution_id,p.child_context_id,p.child_person_id);
 if p.current_version<>p_expected_version then raise serialization_failure using message='stale medication version'; end if;
 next_version:=p.current_version+1;
 insert into public.medication_plan_versions(plan_id,version,medication_name,dose_amount,dose_unit,administration_route,
   route_details,valid_from,valid_until,timezone,instructions,change_reason,created_by_person_id)
 values(p.id,next_version,p_payload->>'medication_name',(p_payload->>'dose_amount')::numeric,p_payload->>'dose_unit',
   p_payload->>'administration_route',nullif(p_payload->>'route_details',''),(p_payload->>'valid_from')::date,
   nullif(p_payload->>'valid_until','')::date,p_payload->>'timezone',nullif(p_payload->>'instructions',''),
   p_payload->>'change_reason',app_private.current_person_id());
 for schedule in select value from jsonb_array_elements(coalesce(p_payload->'schedules','[]'::jsonb)) loop
   insert into public.medication_schedules(plan_id,plan_version,time_of_day,frequency_kind,start_date,end_date,max_occurrences_per_day)
   values(p.id,next_version,(schedule->>'time_of_day')::time,schedule->>'frequency_kind',(schedule->>'start_date')::date,
     nullif(schedule->>'end_date','')::date,nullif(schedule->>'max_occurrences_per_day','')::smallint) returning id into schedule_id;
   insert into public.medication_schedule_weekdays(schedule_id,iso_weekday)
   select schedule_id,value::smallint from jsonb_array_elements_text(coalesce(schedule->'weekdays','[]'::jsonb));
 end loop;
 update public.medication_plans set current_version=next_version,updated_by_person_id=app_private.current_person_id(),updated_at=now()
 where id=p.id;
 response:=jsonb_build_object('id',p.id,'version',next_version,'status',p.status);
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,institution_id,
  before_json,after_json) values(app_private.current_person_id(),'aal2','medication.plan.update','medication_plan',p.id,p.institution_id,
  jsonb_build_object('version',p.current_version),response);
 return app_private.save_medication_receipt(p_request_id,'update',
  jsonb_build_object('plan_id',p_plan_id,'expected',p_expected_version,'payload',p_payload),response);
end $$;

create or replace function public.add_medication_responsible(
 p_request_id uuid,p_plan_id uuid,p_expected_version bigint,p_person_id uuid
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare p public.medication_plans%rowtype; membership uuid; response jsonb; prior jsonb;
begin
 prior:=app_private.medication_receipt(p_request_id,'add_responsible',
  jsonb_build_object('plan_id',p_plan_id,'expected',p_expected_version,'person_id',p_person_id));
 if prior is not null then return prior; end if;
 select * into p from public.medication_plans where id=p_plan_id for update;
 if not found then raise insufficient_privilege using message='not found'; end if;
 perform app_private.assert_medication_write_access(p.id,p.institution_id,p.child_context_id,p.child_person_id);
 if p.current_version<>p_expected_version then raise serialization_failure using message='stale medication version'; end if;
 if p.institution_id is not null then select id into membership from public.institution_memberships
   where person_id=p_person_id and institution_id=p.institution_id and status='active' and revoked_at is null;
   if membership is null then raise invalid_parameter_value using message='invalid responsible'; end if;
 end if;
 insert into public.medication_plan_responsibles(plan_id,person_id,membership_id,added_by_person_id)
 values(p.id,p_person_id,membership,app_private.current_person_id());
 update public.medication_plans set updated_by_person_id=app_private.current_person_id(),updated_at=now() where id=p.id;
 response:=jsonb_build_object('plan_id',p.id,'person_id',p_person_id,'version',p.current_version);
 return app_private.save_medication_receipt(p_request_id,'add_responsible',
  jsonb_build_object('plan_id',p.id,'expected',p_expected_version,'person_id',p_person_id),response);
end $$;

create or replace function public.suspend_medication_plan(
 p_request_id uuid,p_plan_id uuid,p_expected_version bigint,p_reason text
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare p public.medication_plans%rowtype; response jsonb; prior jsonb;
begin
 prior:=app_private.medication_receipt(p_request_id,'suspend',
  jsonb_build_object('plan_id',p_plan_id,'expected',p_expected_version,'reason',p_reason));
 if prior is not null then return prior; end if;
 select * into p from public.medication_plans where id=p_plan_id for update;
 if not found then raise insufficient_privilege using message='not found'; end if;
 perform app_private.assert_medication_write_access(p.id,p.institution_id,p.child_context_id,p.child_person_id);
 if p.current_version<>p_expected_version then raise serialization_failure using message='stale medication version'; end if;
 insert into public.medication_plan_suspensions(plan_id,plan_version,reason,suspended_by_person_id)
 values(p.id,p.current_version,p_reason,app_private.current_person_id());
 update public.medication_plans set status='suspended',
  updated_by_person_id=app_private.current_person_id(),updated_at=now() where id=p.id;
 response:=jsonb_build_object('id',p.id,'status','suspended','version',p.current_version);
 return app_private.save_medication_receipt(p_request_id,'suspend',
  jsonb_build_object('plan_id',p.id,'expected',p_expected_version,'reason',p_reason),response);
end $$;

create or replace function app_private.assert_medication_occurrence_access(p_occurrence_id uuid,p_permission text)
returns public.medication_dose_occurrences language plpgsql stable security definer set search_path=''
as $$ declare occurrence public.medication_dose_occurrences%rowtype; p public.medication_plans%rowtype;
begin
 select * into occurrence from public.medication_dose_occurrences where id=p_occurrence_id;
 select * into p from public.medication_plans where id=occurrence.plan_id;
 perform app_private.assert_medication_write_access(p.id,p.institution_id,p.child_context_id,p.child_person_id);
 if p.institution_id is not null and not app_private.has_context_permission(
   p.institution_id,p_permission,p.unit_id,p.group_id,null,p.child_context_id,false) then
   raise insufficient_privilege using message='not found'; end if;
 return occurrence;
end $$;

create or replace function public.record_medication_administration(
 p_request_id uuid,p_occurrence_id uuid,p_event_kind text,p_notes text,p_occurred_at timestamptz
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare o public.medication_dose_occurrences%rowtype; event_id uuid; response jsonb; prior jsonb; payload jsonb;
begin
 payload:=jsonb_build_object('occurrence_id',p_occurrence_id,'event_kind',p_event_kind,'notes',p_notes,'occurred_at',p_occurred_at);
 prior:=app_private.medication_receipt(p_request_id,'record_administration',payload);
 if prior is not null then return prior; end if;
 o:=app_private.assert_medication_occurrence_access(p_occurrence_id,'medication.administer');
 if p_event_kind not in ('administration','omission','refusal') then raise invalid_parameter_value; end if;
 insert into public.medication_administration_events(occurrence_id,event_kind,notes,occurred_at,actor_person_id,request_id)
 values(o.id,p_event_kind,nullif(p_notes,''),p_occurred_at,app_private.current_person_id(),p_request_id) returning id into event_id;
 update public.medication_dose_occurrences set status=case p_event_kind when 'administration' then 'administered'
  when 'omission' then 'omitted' else 'refused' end,updated_at=now() where id=o.id;
 response:=jsonb_build_object('id',event_id,'occurrence_id',o.id,'event_kind',p_event_kind);
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,after_json)
 values(app_private.current_person_id(),'aal2','medication.administration.record','medication_administration_event',event_id,response);
 return app_private.save_medication_receipt(p_request_id,'record_administration',payload,response);
end $$;

create or replace function public.correct_medication_administration(
 p_request_id uuid,p_event_id uuid,p_reason text,p_notes text
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare corrected public.medication_administration_events%rowtype; o public.medication_dose_occurrences%rowtype; event_id uuid; response jsonb; prior jsonb; payload jsonb;
begin
 payload:=jsonb_build_object('event_id',p_event_id,'reason',p_reason,'notes',p_notes);
 prior:=app_private.medication_receipt(p_request_id,'correct_administration',payload);
 if prior is not null then return prior; end if;
 select * into corrected from public.medication_administration_events where id=p_event_id;
 if not found or corrected.event_kind='correction' then raise insufficient_privilege using message='not found'; end if;
 o:=app_private.assert_medication_occurrence_access(corrected.occurrence_id,'medication.administer');
 insert into public.medication_administration_events(occurrence_id,event_kind,reason,notes,occurred_at,
  actor_person_id,corrects_event_id,request_id) values(o.id,'correction',p_reason,nullif(p_notes,''),now(),
  app_private.current_person_id(),corrected.id,p_request_id) returning id into event_id;
 response:=jsonb_build_object('id',event_id,'corrects_event_id',corrected.id,'occurrence_id',o.id);
 insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,before_json,after_json)
 values(app_private.current_person_id(),'aal2','medication.administration.correct','medication_administration_event',event_id,
  jsonb_build_object('corrected_event_id',corrected.id),response);
 return app_private.save_medication_receipt(p_request_id,'correct_administration',payload,response);
end $$;

create or replace function public.create_medication_asset_upload_intent(
 p_request_id uuid,p_plan_id uuid,p_asset_kind text,p_mime_type text,p_size_bytes bigint
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare p public.medication_plans%rowtype; asset_id uuid:=gen_random_uuid(); extension text; object_path text; response jsonb; prior jsonb; payload jsonb;
begin
 payload:=jsonb_build_object('plan_id',p_plan_id,'asset_kind',p_asset_kind,'mime_type',p_mime_type,'size_bytes',p_size_bytes);
 prior:=app_private.medication_receipt(p_request_id,'create_asset_upload_intent',payload);
 if prior is not null then return prior; end if;
 select * into p from public.medication_plans where id=p_plan_id;
 if not found then raise insufficient_privilege using message='not found'; end if;
 perform app_private.assert_medication_write_access(p.id,p.institution_id,p.child_context_id,p.child_person_id);
 if p_asset_kind='medication_image' and p_mime_type not in ('image/jpeg','image/png','image/webp') then raise invalid_parameter_value; end if;
 if p_asset_kind='prescription' and p_mime_type not in ('image/jpeg','image/png','image/webp','application/pdf') then raise invalid_parameter_value; end if;
 extension:=case p_mime_type when 'image/jpeg' then 'jpg' when 'image/png' then 'png' when 'image/webp' then 'webp' else 'pdf' end;
 object_path:=format('medication/%s/%s/%s/%s.%s',p.child_person_id,p.id,p_asset_kind,asset_id,extension);
 if not app_private.validate_medication_storage_object(object_path,p_mime_type,p_size_bytes) then raise invalid_parameter_value; end if;
 insert into public.medication_assets(id,plan_id,asset_kind,storage_path,mime_type,size_bytes,created_by_person_id)
 values(asset_id,p.id,p_asset_kind,object_path,p_mime_type,p_size_bytes,app_private.current_person_id());
 insert into app_private.medication_upload_intents(request_id,asset_id,actor_person_id,storage_path)
 values(p_request_id,asset_id,app_private.current_person_id(),object_path);
 response:=jsonb_build_object('asset_id',asset_id,'bucket','coelo-medication-private','path',object_path,'expires_in_seconds',900);
 return app_private.save_medication_receipt(p_request_id,'create_asset_upload_intent',payload,response);
end $$;

create or replace function app_private.finalize_medication_asset_upload(
 p_asset_id uuid,p_checksum_sha256 text,p_detected_mime_type text,p_detected_size_bytes bigint
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$ declare asset public.medication_assets%rowtype; intent app_private.medication_upload_intents%rowtype; response jsonb;
begin
 select * into asset from public.medication_assets where id=p_asset_id for update;
 select * into intent from app_private.medication_upload_intents where asset_id=p_asset_id for update;
 if not found or asset.id is null then raise no_data_found using message='upload intent not found'; end if;
 if asset.status='active' and asset.checksum_sha256=p_checksum_sha256 then
   return jsonb_build_object('asset_id',asset.id,'status',asset.status);
 end if;
 if intent.consumed_at is not null or intent.expires_at<=now()
    or p_checksum_sha256 !~ '^[0-9a-f]{64}$'
    or p_detected_mime_type<>asset.mime_type or p_detected_size_bytes<>asset.size_bytes
    or not app_private.validate_medication_storage_object(asset.storage_path,p_detected_mime_type,p_detected_size_bytes)
    or not exists(select 1 from storage.objects o where o.bucket_id=asset.storage_bucket and o.name=asset.storage_path) then
   raise invalid_parameter_value using message='uploaded medication asset failed validation';
 end if;
 update public.medication_assets set checksum_sha256=p_checksum_sha256,status='active',activated_at=now()
 where id=asset.id;
 update app_private.medication_upload_intents set consumed_at=now() where asset_id=asset.id;
 response:=jsonb_build_object('asset_id',asset.id,'status','active');
 return response;
end $$;

create or replace function public.medication_plan_detail(p_plan_id uuid)
returns jsonb language sql stable security definer set search_path=''
as $$ select case when app_private.can_read_medication_plan(p_plan_id) then (
 select to_jsonb(p)||jsonb_build_object(
  'version',(select to_jsonb(v) from public.medication_plan_versions v where v.plan_id=p.id and v.version=p.current_version),
  'schedules',coalesce((select jsonb_agg(to_jsonb(s)||jsonb_build_object('weekdays',
    coalesce((select jsonb_agg(w.iso_weekday order by w.iso_weekday) from public.medication_schedule_weekdays w where w.schedule_id=s.id),'[]'::jsonb))
    order by s.time_of_day) from public.medication_schedules s where s.plan_id=p.id and s.plan_version=p.current_version),'[]'::jsonb),
  'responsibles',coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at) from public.medication_plan_responsibles r
    where r.plan_id=p.id and r.status='active'),'[]'::jsonb)) from public.medication_plans p where p.id=p_plan_id)
 else null end $$;

create view public.medication_plan_directory with (security_invoker=true) as
select p.id,p.child_person_id,p.scope_kind,p.institution_id,p.unit_id,p.group_id,p.child_context_id,
 p.status,p.current_version,v.medication_name,v.dose_amount,v.dose_unit,v.administration_route,
 v.valid_from,v.valid_until,v.timezone,p.updated_at
from public.medication_plans p join public.medication_plan_versions v
 on v.plan_id=p.id and v.version=p.current_version;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('coelo-medication-private','coelo-medication-private',false,10485760,
 array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists medication_asset_select on storage.objects;
create policy medication_asset_select on storage.objects for select to authenticated using(
 bucket_id='coelo-medication-private' and exists(select 1 from public.medication_assets a
  where a.storage_path=name and app_private.can_read_medication_plan(a.plan_id)));
drop policy if exists medication_asset_insert on storage.objects;
create policy medication_asset_insert on storage.objects for insert to authenticated with check(
 bucket_id='coelo-medication-private' and app_private.has_medication_upload_intent(name));

do $$ declare t text; begin foreach t in array array[
 'medication_plans','medication_plan_versions','medication_schedules',
 'medication_schedule_weekdays','medication_plan_reviews','medication_plan_responsibles',
 'medication_plan_suspensions','medication_dose_occurrences','medication_administration_events',
 'medication_assets','medication_transfer_jobs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop; end $$;

create policy medication_plans_read on public.medication_plans for select to authenticated
 using(app_private.can_read_medication_plan(id));
create policy medication_plan_versions_read on public.medication_plan_versions for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_schedules_read on public.medication_schedules for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_schedule_weekdays_read on public.medication_schedule_weekdays for select to authenticated
 using(exists(select 1 from public.medication_schedules s where s.id=schedule_id and app_private.can_read_medication_plan(s.plan_id)));
create policy medication_plan_reviews_read on public.medication_plan_reviews for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_plan_responsibles_read on public.medication_plan_responsibles for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_plan_suspensions_read on public.medication_plan_suspensions for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_dose_occurrences_read on public.medication_dose_occurrences for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_administration_events_read on public.medication_administration_events for select to authenticated
 using(exists(select 1 from public.medication_dose_occurrences o where o.id=occurrence_id and app_private.can_read_medication_plan(o.plan_id)));
create policy medication_assets_read on public.medication_assets for select to authenticated
 using(app_private.can_read_medication_plan(plan_id));
create policy medication_transfer_jobs_read on public.medication_transfer_jobs for select to authenticated
 using(requested_by_person_id=app_private.current_person_id() and
  app_private.medication_release_ready());

revoke all on app_private.medication_command_receipts,app_private.medication_upload_intents from public,anon,authenticated;
grant all on app_private.medication_command_receipts,app_private.medication_upload_intents to service_role;
revoke all on function app_private.medication_release_ready(),app_private.validate_medication_scope(),
 app_private.keep_medication_child_immutable(),app_private.reject_medication_event_mutation(),
 app_private.can_read_medication_plan(uuid),app_private.assert_medication_write_access(uuid,uuid,uuid,uuid),
 app_private.validate_medication_storage_object(text,text,bigint),app_private.has_medication_upload_intent(text),
 app_private.medication_receipt(uuid,text,jsonb),app_private.save_medication_receipt(uuid,text,jsonb,jsonb),
 app_private.assert_medication_occurrence_access(uuid,text),app_private.finalize_medication_asset_upload(uuid,text,text,bigint)
 from public,anon,authenticated;
grant execute on function app_private.can_read_medication_plan(uuid),app_private.has_medication_upload_intent(text) to authenticated;
grant execute on function app_private.finalize_medication_asset_upload(uuid,text,text,bigint) to service_role;

revoke all on function public.medication_plan_detail(uuid),public.create_medication_plan(uuid,jsonb),
 public.update_medication_plan(uuid,uuid,bigint,jsonb),public.add_medication_responsible(uuid,uuid,bigint,uuid),
 public.suspend_medication_plan(uuid,uuid,bigint,text),public.record_medication_administration(uuid,uuid,text,text,timestamptz),
 public.correct_medication_administration(uuid,uuid,text,text),
 public.create_medication_asset_upload_intent(uuid,uuid,text,text,bigint) from public,anon,authenticated,service_role;
grant execute on function public.medication_plan_detail(uuid),public.create_medication_plan(uuid,jsonb),
 public.update_medication_plan(uuid,uuid,bigint,jsonb),public.add_medication_responsible(uuid,uuid,bigint,uuid),
 public.suspend_medication_plan(uuid,uuid,bigint,text),public.record_medication_administration(uuid,uuid,text,text,timestamptz),
 public.correct_medication_administration(uuid,uuid,text,text),
 public.create_medication_asset_upload_intent(uuid,uuid,text,text,bigint) to authenticated;
revoke all on public.medication_plan_directory from public,anon,authenticated;
grant select on public.medication_plan_directory to authenticated;

commit;
