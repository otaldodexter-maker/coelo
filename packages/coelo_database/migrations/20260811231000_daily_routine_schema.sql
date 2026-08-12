-- Daily routine model, inheritance and launch schema. Media is intentionally out of scope.

insert into public.platform_permissions(
 code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status
) values
 ('routine.read','routine','daily_routine','read','Read routine configuration and launches.','normal',false,'active'),
 ('routine.manage_models','routine','daily_routine','manage_models','Manage routine models.','high',false,'active'),
 ('routine.manage_applications','routine','daily_routine','manage_applications','Manage routine inheritance.','high',false,'active'),
 ('routine.record','routine','daily_routine','record','Record routine drafts.','high',false,'active'),
 ('routine.publish','routine','daily_routine','publish','Publish child routine data.','critical',true,'active'),
 ('routine.correct','routine','daily_routine','correct','Correct published routine data.','critical',true,'active'),
 ('routine.import','routine','daily_routine','import','Import routine configuration.','critical',true,'active'),
 ('routine.export','routine','daily_routine','export','Export routine configuration.','critical',true,'active')
on conflict(code) do update set description=excluded.description,risk_level=excluded.risk_level,
 requires_mfa=excluded.requires_mfa,status='active';

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select r.id,p.id,'allow','active' from public.platform_roles r
join public.platform_permissions p on p.code like 'routine.%'
where r.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

create table public.routine_models(
 id uuid primary key default gen_random_uuid(),institution_id uuid references public.institutions(id) on delete cascade,
 origin_scope_kind text not null check(origin_scope_kind in ('platform','institution','unit')),
 origin_unit_id uuid references public.units(id) on delete cascade,
 name text not null check(btrim(name)<>'' and char_length(name)<=120),
 description text not null default '' check(char_length(description)<=1000),is_system boolean not null default false,
 status text not null default 'draft' check(status in ('draft','active','inactive','archived')),
 current_version integer not null default 0 check(current_version>=0),management_version bigint not null default 1 check(management_version>0),
 created_by_person_id uuid references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),archived_at timestamptz,
 check((origin_scope_kind='platform' and institution_id is null and origin_unit_id is null)
  or (origin_scope_kind='institution' and institution_id is not null and origin_unit_id is null)
  or (origin_scope_kind='unit' and institution_id is not null and origin_unit_id is not null)),unique(id,institution_id)
);
create index routine_models_directory_idx on public.routine_models(origin_scope_kind,institution_id,origin_unit_id,status,lower(name),id);

create table public.routine_model_versions(
 id uuid primary key default gen_random_uuid(),model_id uuid not null references public.routine_models(id) on delete cascade,
 version_no integer not null check(version_no>0),governance_kind text not null default 'optional'
  check(governance_kind in ('optional','mandatory','fixed')),
 status text not null default 'draft' check(status in ('draft','published','archived')),
 valid_from date,valid_until date,created_by_person_id uuid references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),published_at timestamptz,
 checksum_sha256 text check(checksum_sha256 is null or checksum_sha256~'^[0-9a-f]{64}$'),
 unique(model_id,version_no),unique(id,model_id),check(valid_until is null or valid_from is null or valid_until>=valid_from)
);
create index routine_model_versions_model_idx on public.routine_model_versions(model_id,version_no desc);

create table public.routine_sections(
 id uuid primary key default gen_random_uuid(),model_version_id uuid not null references public.routine_model_versions(id) on delete cascade,
 name text not null check(btrim(name)<>'' and char_length(name)<=120),sort_order integer not null check(sort_order>=0),
 created_at timestamptz not null default now(),unique(model_version_id,sort_order),unique(id,model_version_id)
);
create table public.routine_fields(
 id uuid primary key default gen_random_uuid(),model_version_id uuid not null references public.routine_model_versions(id) on delete cascade,
 section_id uuid not null,label text not null check(btrim(label)<>'' and char_length(label)<=240),
 field_kind text not null check(field_kind in ('short_text','long_text','single_choice','multiple_choice','number','boolean')),
 is_required boolean not null default false,initial_value jsonb,min_value numeric,max_value numeric,
 sort_order integer not null check(sort_order>=0),created_at timestamptz not null default now(),
 foreign key(section_id,model_version_id) references public.routine_sections(id,model_version_id) on delete cascade,
 check((min_value is null or max_value is null or min_value<=max_value)
  and (field_kind='number' or (min_value is null and max_value is null))),
 unique(section_id,sort_order),unique(id,model_version_id)
);
create table public.routine_field_options(
 id uuid primary key default gen_random_uuid(),model_version_id uuid not null references public.routine_model_versions(id) on delete cascade,
 field_id uuid not null,label text not null check(btrim(label)<>'' and char_length(label)<=160),
 value_code text not null check(value_code~'^[a-z0-9][a-z0-9_-]{0,63}$'),sort_order integer not null check(sort_order>=0),
 foreign key(field_id,model_version_id) references public.routine_fields(id,model_version_id) on delete cascade,
 unique(field_id,value_code),unique(field_id,sort_order),unique(id,field_id,model_version_id)
);
create table public.routine_field_conditions(
 id uuid primary key default gen_random_uuid(),model_version_id uuid not null references public.routine_model_versions(id) on delete cascade,
 source_field_id uuid not null,source_option_id uuid,boolean_value boolean,target_field_id uuid not null,
 foreign key(source_field_id,model_version_id) references public.routine_fields(id,model_version_id) on delete cascade,
 foreign key(source_option_id,source_field_id,model_version_id)
  references public.routine_field_options(id,field_id,model_version_id) on delete cascade,
 foreign key(target_field_id,model_version_id) references public.routine_fields(id,model_version_id) on delete cascade,
 check(source_field_id<>target_field_id),check((source_option_id is null)<>(boolean_value is null)),
 unique nulls not distinct(source_field_id,source_option_id,boolean_value,target_field_id)
);
create index routine_field_conditions_target_idx on public.routine_field_conditions(model_version_id,target_field_id);

create table public.routine_applications(
 id uuid primary key default gen_random_uuid(),institution_id uuid not null references public.institutions(id) on delete cascade,
 unit_id uuid references public.units(id) on delete cascade,group_id uuid references public.groups(id) on delete cascade,
 activity_id uuid references public.activity_definitions(id) on delete set null,
 scope_kind text not null check(scope_kind in ('institution','unit','group')),
 source_model_version_id uuid not null references public.routine_model_versions(id) on delete restrict,
 parent_application_id uuid references public.routine_applications(id) on delete restrict,
 inheritance_mode text not null default 'inherited' check(inheritance_mode in ('inherited','customized')),
 visibility text not null default 'authorized_guardians' check(visibility in ('staff_only','authorized_guardians')),
 valid_from date,valid_until date,starts_at time,ends_at time,
 status text not null default 'draft' check(status in ('draft','active','inactive','archived')),
 management_version bigint not null default 1 check(management_version>0),created_by_person_id uuid references public.people(id) on delete restrict,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(valid_until is null or valid_from is null or valid_until>=valid_from),check(ends_at is null or starts_at is null or ends_at>starts_at),
 check((scope_kind='institution' and unit_id is null and group_id is null)
  or (scope_kind='unit' and unit_id is not null and group_id is null)
  or (scope_kind='group' and unit_id is not null and group_id is not null)),unique(id,institution_id)
);
create index routine_applications_scope_idx on public.routine_applications(institution_id,unit_id,group_id,activity_id,status);

create table public.routine_application_revisions(
 id uuid primary key default gen_random_uuid(),application_id uuid not null references public.routine_applications(id) on delete cascade,
 revision_no integer not null check(revision_no>0),source_model_version_id uuid not null references public.routine_model_versions(id) on delete restrict,
 origin_application_id uuid references public.routine_applications(id) on delete restrict,
 effective_definition jsonb not null check(jsonb_typeof(effective_definition)='object'),
 created_by_person_id uuid not null references public.people(id) on delete restrict,created_at timestamptz not null default now(),
 unique(application_id,revision_no),unique(id,application_id)
);
create table public.routine_application_assignees(
 application_id uuid not null references public.routine_applications(id) on delete cascade,
 institution_id uuid not null references public.institutions(id) on delete cascade,
 membership_id uuid not null references public.institution_memberships(id) on delete restrict,
 responsibility text not null default 'record' check(responsibility in ('record','review','publish')),
 created_at timestamptz not null default now(),primary key(application_id,membership_id,responsibility)
);
create index routine_application_assignees_membership_idx on public.routine_application_assignees(membership_id);

create table public.routine_launches(
 id uuid primary key default gen_random_uuid(),institution_id uuid not null references public.institutions(id) on delete cascade,
 unit_id uuid not null references public.units(id) on delete restrict,group_id uuid not null references public.groups(id) on delete restrict,
 activity_id uuid references public.activity_definitions(id) on delete restrict,application_id uuid not null,application_revision_id uuid not null,
 service_date date not null,status text not null default 'draft' check(status in ('draft','published','corrected','cancelled')),
 author_membership_id uuid not null references public.institution_memberships(id) on delete restrict,
 management_version bigint not null default 1 check(management_version>0),created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),published_at timestamptz,corrected_at timestamptz,
 foreign key(application_id,institution_id) references public.routine_applications(id,institution_id) on delete restrict,
 foreign key(application_revision_id,application_id) references public.routine_application_revisions(id,application_id) on delete restrict
);
create unique index routine_launches_active_uidx on public.routine_launches(
 application_id,group_id,service_date,coalesce(activity_id,'00000000-0000-0000-0000-000000000000'::uuid)) where status<>'cancelled';
create index routine_launches_scope_date_idx on public.routine_launches(institution_id,unit_id,group_id,service_date desc);

create table public.routine_child_entries(
 id uuid primary key default gen_random_uuid(),launch_id uuid not null references public.routine_launches(id) on delete cascade,
 child_context_id uuid not null references public.child_contexts(id) on delete restrict,
 child_group_link_id uuid not null references public.child_group_links(id) on delete restrict,
 status text not null default 'draft' check(status in ('draft','complete','published')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(launch_id,child_context_id),unique(id,launch_id)
);
create table public.routine_answers(
 id uuid primary key default gen_random_uuid(),child_entry_id uuid not null references public.routine_child_entries(id) on delete cascade,
 field_id uuid not null references public.routine_fields(id) on delete restrict,value_json jsonb,
 answered_by_person_id uuid not null references public.people(id) on delete restrict,answered_at timestamptz not null default now(),
 unique(child_entry_id,field_id)
);
create table public.routine_launch_revisions(
 id uuid primary key default gen_random_uuid(),launch_id uuid not null references public.routine_launches(id) on delete cascade,
 revision_no integer not null check(revision_no>0),reason text not null check(btrim(reason)<>'' and char_length(reason)<=1000),
 before_json jsonb not null,after_json jsonb not null,changed_by_person_id uuid not null references public.people(id) on delete restrict,
 changed_at timestamptz not null default now(),unique(launch_id,revision_no)
);

create table app_private.routine_command_receipts(
 request_id uuid primary key,actor_person_id uuid not null references public.people(id) on delete restrict,
 command_name text not null,aggregate_id uuid not null,response_json jsonb not null,created_at timestamptz not null default now()
);

do $$ declare t text; begin
 foreach t in array array['routine_models','routine_model_versions','routine_sections','routine_fields',
  'routine_field_options','routine_field_conditions','routine_applications','routine_application_revisions',
  'routine_application_assignees','routine_launches','routine_child_entries','routine_answers','routine_launch_revisions'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('alter table public.%I force row level security',t);
  execute format('create policy %I on public.%I for select to authenticated using ((select app_private.has_platform_permission(''routine.read'')))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check (false)',t||'_insert_denied',t);
  execute format('create policy %I on public.%I for update to authenticated using (false) with check (false)',t||'_update_denied',t);
  execute format('create policy %I on public.%I for delete to authenticated using (false)',t||'_delete_denied',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end $$;
alter table app_private.routine_command_receipts enable row level security;
alter table app_private.routine_command_receipts force row level security;
revoke all on app_private.routine_command_receipts from public,anon,authenticated;
