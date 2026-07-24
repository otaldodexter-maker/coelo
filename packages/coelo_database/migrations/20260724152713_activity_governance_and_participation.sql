-- Activity governance, promotion, capability policy and child participation.

alter table public.activity_definitions
  add column distribution_scope text not null default 'unit_local'
    check (distribution_scope in ('institution_standard','unit_local')),
  add column governance_kind text not null default 'optional'
    check (governance_kind in ('optional','mandatory','fixed')),
  add column promoted_by_person_id uuid references public.people(id) on delete restrict,
  add column promoted_at timestamptz,
  add constraint activity_definitions_promotion_check check (
    (distribution_scope = 'unit_local'
      and promoted_by_person_id is null and promoted_at is null)
    or distribution_scope = 'institution_standard'
  );

update public.activity_definitions
set distribution_scope = case
  when origin_scope_kind = 'institution' then 'institution_standard'
  else 'unit_local' end;

alter table public.activity_group_links
  add column participation_mode text not null default 'all'
    check (participation_mode in ('all','selected'));

create table public.activity_capability_policies (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activity_definitions(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete cascade,
  capability_id uuid not null references public.activity_capabilities(id) on delete restrict,
  policy_mode text not null
    check (policy_mode in ('required','default_on','default_off','prohibited')),
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_id, capability_id)
);
create index activity_capability_policies_institution_idx
  on public.activity_capability_policies(institution_id, policy_mode);

create table public.activity_group_capability_settings (
  id uuid primary key default gen_random_uuid(),
  activity_group_link_id uuid not null
    references public.activity_group_links(id) on delete cascade,
  capability_id uuid not null references public.activity_capabilities(id) on delete restrict,
  is_enabled boolean not null,
  changed_by_person_id uuid not null references public.people(id) on delete restrict,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_group_link_id, capability_id)
);

create table public.activity_group_participants (
  id uuid primary key default gen_random_uuid(),
  activity_group_link_id uuid not null
    references public.activity_group_links(id) on delete cascade,
  child_group_link_id uuid not null
    references public.child_group_links(id) on delete cascade,
  status public.record_status not null default 'active',
  added_by_person_id uuid not null references public.people(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  removed_at timestamptz
);
create unique index activity_group_participants_active_uidx
  on public.activity_group_participants(activity_group_link_id, child_group_link_id)
  where status = 'active' and removed_at is null;
create index activity_group_participants_child_idx
  on public.activity_group_participants(child_group_link_id, status);

create or replace function app_private.validate_activity_governance_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'activity_capability_policies' then
    if not exists (
      select 1 from public.activity_definitions activity
      where activity.id = new.activity_id
        and activity.institution_id = new.institution_id
    ) then raise exception 'activity policy tenant mismatch'; end if;
  elsif tg_table_name = 'activity_group_capability_settings' then
    if exists (
      select 1
      from public.activity_group_links group_link
      join public.activity_capability_policies policy
        on policy.activity_id = group_link.activity_id
       and policy.capability_id = new.capability_id
      where group_link.id = new.activity_group_link_id
        and (
          (policy.policy_mode = 'required' and not new.is_enabled)
          or (policy.policy_mode = 'prohibited' and new.is_enabled)
        )
    ) then raise exception 'institution capability policy is locked'; end if;
  elsif tg_table_name = 'activity_group_participants' then
    if not exists (
      select 1
      from public.activity_group_links activity_link
      join public.child_group_links child_link
        on child_link.id = new.child_group_link_id
       and child_link.group_id = activity_link.group_id
      join public.child_unit_links child_unit
        on child_unit.id = child_link.child_unit_link_id
       and child_unit.unit_id = activity_link.unit_id
      join public.child_contexts child_context
        on child_context.id = child_unit.child_context_id
       and child_context.institution_id = activity_link.institution_id
      where activity_link.id = new.activity_group_link_id
    ) then raise exception 'activity participant is outside group context'; end if;
  end if;
  return new;
end;
$$;

create trigger activity_capability_policies_validate
before insert or update on public.activity_capability_policies
for each row execute function app_private.validate_activity_governance_row();
create trigger activity_group_capability_settings_validate
before insert or update on public.activity_group_capability_settings
for each row execute function app_private.validate_activity_governance_row();
create trigger activity_group_participants_validate
before insert or update on public.activity_group_participants
for each row execute function app_private.validate_activity_governance_row();

create or replace function app_private.promote_activity_to_institution_standard(
  target_activity_id uuid,
  target_governance_kind text,
  target_reason text
)
returns public.activity_definitions
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_person_id uuid := app_private.current_person_id();
  activity_record public.activity_definitions%rowtype;
begin
  if target_governance_kind not in ('optional','mandatory','fixed') then
    raise exception 'invalid governance kind';
  end if;
  select * into activity_record from public.activity_definitions
  where id = target_activity_id for update;
  if activity_record.id is null then raise exception 'activity not found'; end if;
  if not app_private.has_context_permission(
    activity_record.institution_id, 'activities.manage',
    null, null, activity_record.id, null, true
  ) then raise exception 'institution activity management required'; end if;

  update public.activity_definitions
  set distribution_scope = 'institution_standard',
      governance_kind = target_governance_kind,
      promoted_by_person_id = coalesce(promoted_by_person_id, actor_person_id),
      promoted_at = coalesce(promoted_at, now()),
      updated_at = now()
  where id = target_activity_id
  returning * into activity_record;

  insert into audit.audit_logs(
    actor_person_id, action_code, object_type, object_id, institution_id,
    reason, after_json
  ) values (
    actor_person_id, 'activity.promoted', 'activity_definition',
    activity_record.id, activity_record.institution_id,
    nullif(btrim(target_reason), ''), to_jsonb(activity_record)
  );
  return activity_record;
end;
$$;

create or replace function public.promote_activity_to_institution_standard(
  activity_id uuid,
  governance_kind text default 'optional',
  reason text default null
)
returns public.activity_definitions
language sql
volatile
security invoker
set search_path = ''
as $$
  select app_private.promote_activity_to_institution_standard(
    activity_id, governance_kind, reason
  )
$$;

create or replace function app_private.has_activity_capability(
  target_activity_id uuid,
  target_group_id uuid,
  target_capability_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with current_assignment as (
    select assignment.id, group_link.id as group_link_id,
           group_link.permission_profile_id
    from public.activity_group_assignments assignment
    join public.activity_group_links group_link
      on group_link.id = assignment.activity_group_link_id
     and group_link.institution_id = assignment.institution_id
    join public.activity_definitions activity
      on activity.id = group_link.activity_id
     and activity.institution_id = group_link.institution_id
    where assignment.person_id = app_private.current_person_id()
      and assignment.status = 'active' and assignment.revoked_at is null
      and group_link.status = 'active' and activity.status = 'active'
      and activity.id = target_activity_id and group_link.group_id = target_group_id
    limit 1
  ),
  target_capability as (
    select id from public.activity_capabilities
    where code = target_capability_code and status = 'active'
  ),
  individual_override as (
    select override_row.effect
    from current_assignment assignment
    join public.activity_assignment_permission_overrides override_row
      on override_row.assignment_id = assignment.id
    join target_capability capability on capability.id = override_row.capability_id
    limit 1
  ),
  institution_policy as (
    select policy.policy_mode
    from public.activity_capability_policies policy
    join target_capability capability on capability.id = policy.capability_id
    where policy.activity_id = target_activity_id
    limit 1
  ),
  group_setting as (
    select setting.is_enabled
    from current_assignment assignment
    join public.activity_group_capability_settings setting
      on setting.activity_group_link_id = assignment.group_link_id
    join target_capability capability on capability.id = setting.capability_id
    limit 1
  ),
  profile_permission as (
    select profile_capability.effect
    from current_assignment assignment
    join public.activity_permission_profile_capabilities profile_capability
      on profile_capability.profile_id = assignment.permission_profile_id
    join target_capability capability on capability.id = profile_capability.capability_id
    limit 1
  )
  select case
    when not exists (select 1 from current_assignment) then false
    when exists (select 1 from individual_override where effect='deny') then false
    when exists (select 1 from institution_policy where policy_mode='prohibited') then false
    when exists (select 1 from individual_override where effect='allow') then true
    when exists (select 1 from institution_policy where policy_mode='required') then true
    when exists (select 1 from group_setting) then
      (select is_enabled from group_setting)
    when exists (select 1 from institution_policy where policy_mode='default_on') then true
    when exists (select 1 from institution_policy where policy_mode='default_off') then false
    when exists (select 1 from profile_permission where effect='allow') then true
    else false
  end
$$;

do $$
declare current_table text;
begin
  foreach current_table in array array[
    'activity_capability_policies','activity_group_capability_settings',
    'activity_group_participants'
  ] loop
    execute format('alter table public.%I enable row level security', current_table);
    execute format('revoke all on public.%I from public, anon, authenticated', current_table);
    execute format('grant all on public.%I to service_role', current_table);
    execute format('grant select, insert, update on public.%I to authenticated', current_table);
  end loop;
end;
$$;

create policy activity_capability_policies_read
on public.activity_capability_policies for select to authenticated
using (
  app_private.has_activity_context_access(activity_id, null, null)
  or app_private.has_context_permission(
    institution_id,'activities.read',null,null,activity_id,null,false
  )
);
create policy activity_capability_policies_manage
on public.activity_capability_policies for all to authenticated
using (
  app_private.has_context_permission(
    institution_id,'activities.manage_permissions',null,null,activity_id,null,true
  )
)
with check (
  app_private.has_context_permission(
    institution_id,'activities.manage_permissions',null,null,activity_id,null,true
  )
);

create policy activity_group_capability_settings_read
on public.activity_group_capability_settings for select to authenticated
using (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and (
        app_private.has_activity_context_access(
          group_link.activity_id,group_link.unit_id,group_link.group_id
        )
        or app_private.has_context_permission(
          group_link.institution_id,'activities.read',group_link.unit_id,
          group_link.group_id,group_link.activity_id,null,false
        )
      )
  )
);
create policy activity_group_capability_settings_manage
on public.activity_group_capability_settings for all to authenticated
using (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and app_private.has_context_permission(
        group_link.institution_id,'activities.manage_permissions',
        group_link.unit_id,group_link.group_id,group_link.activity_id,null,false
      )
  )
)
with check (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and app_private.has_context_permission(
        group_link.institution_id,'activities.manage_permissions',
        group_link.unit_id,group_link.group_id,group_link.activity_id,null,false
      )
  )
);

create policy activity_group_participants_read
on public.activity_group_participants for select to authenticated
using (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and (
        app_private.has_activity_context_access(
          group_link.activity_id,group_link.unit_id,group_link.group_id
        )
        or app_private.has_context_permission(
          group_link.institution_id,'activities.read',group_link.unit_id,
          group_link.group_id,group_link.activity_id,null,false
        )
      )
  )
);
create policy activity_group_participants_manage
on public.activity_group_participants for all to authenticated
using (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and app_private.has_context_permission(
        group_link.institution_id,'activities.link_groups',group_link.unit_id,
        group_link.group_id,group_link.activity_id,null,false
      )
  )
)
with check (
  exists (
    select 1 from public.activity_group_links group_link
    where group_link.id = activity_group_link_id
      and app_private.has_context_permission(
        group_link.institution_id,'activities.link_groups',group_link.unit_id,
        group_link.group_id,group_link.activity_id,null,false
      )
  )
);

revoke all on function app_private.validate_activity_governance_row()
  from public,anon,authenticated;
revoke all on function app_private.promote_activity_to_institution_standard(uuid,text,text)
  from public,anon;
grant execute on function app_private.promote_activity_to_institution_standard(uuid,text,text)
  to authenticated,service_role;
revoke all on function public.promote_activity_to_institution_standard(uuid,text,text)
  from public,anon;
grant execute on function public.promote_activity_to_institution_standard(uuid,text,text)
  to authenticated;

with table_catalog(table_name,table_label,table_description,domain) as (
  values
    ('activity_capability_policies','Politicas de capacidade','Regra institucional por atividade e capacidade.','activities'),
    ('activity_group_capability_settings','Capacidades por turma','Valor efetivo administrado pela unidade.','activities'),
    ('activity_group_participants','Participantes da atividade','Selecao explicita de criancas na turma.','activities')
)
insert into public.schema_tables(
  schema_name,table_name,table_label,table_description,domain,status,version,updated_at
)
select 'public',table_name,table_label,table_description,domain,'active',1,now()
from table_catalog
on conflict(schema_name,table_name,version) do update set
  table_label=excluded.table_label,table_description=excluded.table_description,
  domain=excluded.domain,status=excluded.status,updated_at=now();

insert into public.schema_columns(
  schema_table_id,column_name,column_label,column_description,column_type,
  is_required,is_nullable,is_unique,is_filterable,is_importable,is_active,
  position,allowed_locales_json,aliases_json,examples_json,updated_at
)
select st.id,c.column_name,replace(c.column_name,'_',' '),
  'Campo de atividade '||c.column_name||'.',c.data_type,c.is_nullable='NO',
  c.is_nullable='YES',false,c.column_name in (
    'activity_id','institution_id','activity_group_link_id','child_group_link_id',
    'capability_id','policy_mode','status'
  ),false,true,c.ordinal_position,'["pt-BR"]'::jsonb,'{}'::jsonb,'[]'::jsonb,now()
from information_schema.columns c join public.schema_tables st
  on st.schema_name=c.table_schema and st.table_name=c.table_name and st.version=1
where c.table_schema='public' and c.table_name in (
  'activity_capability_policies','activity_group_capability_settings',
  'activity_group_participants'
)
on conflict(schema_table_id,column_name) do update set
  column_type=excluded.column_type,is_required=excluded.is_required,
  is_nullable=excluded.is_nullable,is_filterable=excluded.is_filterable,
  is_active=true,position=excluded.position,updated_at=now();
