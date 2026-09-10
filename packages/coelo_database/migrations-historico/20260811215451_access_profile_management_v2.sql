-- Versioned access-profile templates, typed contextual overrides and guarded
-- access-profile commands. Templates are copied snapshots: authorization never
-- reads them after a profile/context is created.

alter table public.platform_permissions
  add column if not exists module_label text,
  add column if not exists screen_label text,
  add column if not exists action_label text;
alter table public.institution_permissions
  add column if not exists module_label text,
  add column if not exists screen_label text,
  add column if not exists action_label text;
alter table public.guardian_permission_capabilities
  add column if not exists module_code text not null default 'principal',
  add column if not exists module_label text not null default 'Principal',
  add column if not exists screen_code text not null default 'permissions',
  add column if not exists screen_label text not null default 'Permissões',
  add column if not exists action_code text not null default 'view',
  add column if not exists action_label text not null default 'Ver',
  add column if not exists risk_level text not null default 'high',
  add column if not exists requires_mfa boolean not null default false;

update public.platform_permissions permission_record set
  module_label = case permission_record.module_code
    when 'activities' then 'Atividades' when 'analytics' then 'Indicadores'
    when 'audit' then 'Auditoria' when 'groups' then 'Turmas'
    when 'imports' then 'Importações' when 'institutions' then 'Instituições'
    when 'notices' then 'Avisos' when 'people' then 'Pessoas'
    when 'plans' then 'Planos' when 'platform' then 'Superadmin'
    when 'support' then 'Suporte' when 'units' then 'Unidades'
    else initcap(replace(permission_record.module_code, '_', ' ')) end,
  screen_label = initcap(replace(coalesce(permission_record.screen_code, permission_record.module_code), '_', ' ')),
  action_label = case permission_record.action_code
    when 'read' then 'Ver' when 'export' then 'Exportar'
    when 'import' then 'Importar' when 'update' then 'Editar'
    else 'Gerenciar' end;
update public.institution_permissions permission_record set
  module_label = case permission_record.module_code
    when 'activities' then 'Atividades' when 'attendance' then 'Presença'
    when 'authorization' then 'Perfis e permissões' when 'chat' then 'Chat'
    when 'family' then 'Famílias' when 'groups' then 'Turmas'
    when 'people' then 'Pessoas' else initcap(replace(permission_record.module_code, '_', ' ')) end,
  screen_label = initcap(replace(coalesce(permission_record.screen_code, permission_record.module_code), '_', ' ')),
  action_label = case permission_record.action_code
    when 'read' then 'Ver' when 'export' then 'Exportar'
    when 'import' then 'Importar' when 'update' then 'Editar'
    else 'Gerenciar' end;
update public.guardian_permission_capabilities capability set
  screen_code = case capability.code
    when 'view_context' then 'context' when 'message' then 'messages'
    when 'react' then 'reactions' when 'manage_authorized_people' then 'authorized_people'
    when 'manage_attendance_notices' then 'attendance_notices' else 'permissions' end,
  screen_label = case capability.code
    when 'view_context' then 'Contexto da criança' when 'message' then 'Mensagens'
    when 'react' then 'Reações' when 'manage_authorized_people' then 'Pessoas autorizadas'
    when 'manage_attendance_notices' then 'Avisos de presença' else capability.name end,
  action_code = case capability.code when 'view_context' then 'view' else 'manage' end,
  action_label = case capability.code when 'view_context' then 'Ver' else 'Gerenciar' end,
  risk_level = case capability.code
    when 'view_context' then 'high' when 'react' then 'normal' else 'critical' end;
alter table public.platform_permissions
  alter column module_label set not null,
  alter column screen_label set not null,
  alter column action_label set not null;
alter table public.institution_permissions
  alter column module_label set not null,
  alter column screen_label set not null,
  alter column action_label set not null;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status,
  module_label,screen_label,action_label
) values
  ('platform.roles.export','platform','roles','export','Exportar perfis Superadmin por job auditado.','high',true,'active','Superadmin','Perfis e permissões','Exportar'),
  ('platform.roles.import','platform','roles','import','Importar perfis Superadmin por job auditado.','critical',true,'active','Superadmin','Perfis e permissões','Importar'),
  ('institution.roles.export','institutions','roles','export','Exportar perfis Admin por job auditado.','high',true,'active','Instituições','Perfis e permissões','Exportar'),
  ('institution.roles.import','institutions','roles','import','Importar perfis Admin por job auditado.','critical',true,'active','Instituições','Perfis e permissões','Importar')
on conflict(code) do update set
  description=excluded.description,risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,status='active',module_label=excluded.module_label,
  screen_label=excluded.screen_label,action_label=excluded.action_label,updated_at=now();
insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,status)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active'
from public.platform_roles role_record
join public.platform_permissions permission_record on permission_record.code in(
  'platform.roles.export','platform.roles.import','institution.roles.export','institution.roles.import'
)
where role_record.code='owner'
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;

create table app_private.access_profile_catalog_versions(
  domain text primary key check(domain in('platform','institution','principal')),
  version bigint not null check(version>0),
  updated_at timestamptz not null default now()
);
insert into app_private.access_profile_catalog_versions(domain,version)
values('platform',1),('institution',1),('principal',1)
on conflict(domain) do nothing;
revoke all on app_private.access_profile_catalog_versions from public,anon,authenticated;

create table public.access_profile_templates(
  id uuid primary key default gen_random_uuid(),
  domain text not null check(domain in('platform','institution','principal')),
  code text not null,
  name text not null check(char_length(btrim(name)) between 2 and 120),
  description text,
  max_scope_kind text not null,
  version bigint not null default 1 check(version>0),
  is_system boolean not null default true,
  status public.record_status not null default 'active',
  created_by uuid references public.people(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint access_profile_templates_code_check check(code=lower(code) and code ~ '^[a-z0-9][a-z0-9_-]{2,63}$'),
  constraint access_profile_templates_scope_check check(
    (domain='platform' and max_scope_kind in('platform','institution')) or
    (domain='institution' and max_scope_kind in('institution','unit','group')) or
    (domain='principal' and max_scope_kind='child_context')
  ),
  unique(domain,code)
);
create table public.access_profile_template_platform_permissions(
  template_id uuid not null references public.access_profile_templates(id) on delete cascade,
  permission_id uuid not null references public.platform_permissions(id),
  effect public.permission_effect not null default 'allow',
  primary key(template_id,permission_id)
);
create table public.access_profile_template_institution_permissions(
  template_id uuid not null references public.access_profile_templates(id) on delete cascade,
  permission_id uuid not null references public.institution_permissions(id),
  effect public.permission_effect not null default 'allow',
  primary key(template_id,permission_id)
);
create table public.access_profile_template_principal_capabilities(
  template_id uuid not null references public.access_profile_templates(id) on delete cascade,
  capability_id uuid not null references public.guardian_permission_capabilities(id),
  effect public.permission_effect not null default 'allow',
  primary key(template_id,capability_id)
);
create index access_profile_templates_cursor_idx
  on public.access_profile_templates(domain,status,lower(name),id);
create index access_profile_template_platform_permission_idx
  on public.access_profile_template_platform_permissions(permission_id);
create index access_profile_template_institution_permission_idx
  on public.access_profile_template_institution_permissions(permission_id);
create index access_profile_template_principal_capability_idx
  on public.access_profile_template_principal_capabilities(capability_id);

alter table public.access_profile_templates enable row level security;
alter table public.access_profile_templates force row level security;
alter table public.access_profile_template_platform_permissions enable row level security;
alter table public.access_profile_template_platform_permissions force row level security;
alter table public.access_profile_template_institution_permissions enable row level security;
alter table public.access_profile_template_institution_permissions force row level security;
alter table public.access_profile_template_principal_capabilities enable row level security;
alter table public.access_profile_template_principal_capabilities force row level security;
revoke all on public.access_profile_templates,
  public.access_profile_template_platform_permissions,
  public.access_profile_template_institution_permissions,
  public.access_profile_template_principal_capabilities from public,anon,authenticated;
grant all on public.access_profile_templates,
  public.access_profile_template_platform_permissions,
  public.access_profile_template_institution_permissions,
  public.access_profile_template_principal_capabilities to service_role;

alter table public.platform_roles
  add column if not exists source_template_id uuid references public.access_profile_templates(id),
  add column if not exists source_template_version bigint;
alter table public.institution_roles
  add column if not exists source_template_id uuid references public.access_profile_templates(id),
  add column if not exists source_template_version bigint;
alter table public.guardian_context_permissions
  add column if not exists source_template_id uuid references public.access_profile_templates(id),
  add column if not exists source_template_version bigint,
  add column if not exists version bigint not null default 1;
alter table public.platform_memberships add column if not exists version bigint not null default 1;
alter table public.institution_role_assignments add column if not exists version bigint not null default 1;
alter table public.import_jobs add column if not exists version bigint not null default 1;
alter table public.platform_roles add constraint platform_roles_template_snapshot_check
  check((source_template_id is null)=(source_template_version is null));
alter table public.institution_roles add constraint institution_roles_template_snapshot_check
  check((source_template_id is null)=(source_template_version is null));
alter table public.guardian_context_permissions add constraint guardian_context_template_snapshot_check
  check((source_template_id is null)=(source_template_version is null));

-- Replace generic UUID scope decisions with typed institution/unit/group FKs.
do $$ begin
  if exists(select 1 from public.institution_member_permission_overrides
    where scope_kind in('activity','child')) then
    raise check_violation using message='typed override migration requires activity/child overrides to use their domain tables';
  end if;
end $$;
alter table public.institution_member_permission_overrides
  add column if not exists institution_id uuid references public.institutions(id),
  add column if not exists scope_unit_id uuid references public.units(id),
  add column if not exists scope_group_id uuid references public.groups(id),
  add column if not exists version bigint not null default 1;
update public.institution_member_permission_overrides override_record set
  institution_id=membership.institution_id,
  scope_unit_id=case when override_record.scope_kind='unit' then override_record.scope_id
    when override_record.scope_kind='group' then (
      select group_record.unit_id from public.groups group_record
      where group_record.id=override_record.scope_id
    ) else null end,
  scope_group_id=case when override_record.scope_kind='group' then override_record.scope_id else null end
from public.institution_memberships membership
where membership.id=override_record.membership_id;
alter table public.institution_member_permission_overrides alter column institution_id set not null;
alter table public.institution_member_permission_overrides
  drop constraint if exists institution_member_permission_overrides_scope_check;
alter table public.institution_member_permission_overrides
  add constraint institution_member_permission_overrides_typed_scope_check check(
    (scope_kind='institution' and scope_id is null and scope_unit_id is null and scope_group_id is null) or
    (scope_kind='unit' and scope_id=scope_unit_id and scope_unit_id is not null and scope_group_id is null) or
    (scope_kind='group' and scope_id=scope_group_id and scope_unit_id is not null and scope_group_id is not null)
  );
create index institution_member_permission_overrides_typed_scope_idx
  on public.institution_member_permission_overrides(institution_id,scope_kind,scope_unit_id,scope_group_id)
  where status='active' and revoked_at is null;

create or replace function app_private.normalize_institution_permission_override_scope()
returns trigger language plpgsql set search_path='' as $$
declare membership_institution uuid; unit_institution uuid; group_institution uuid; group_unit uuid;
begin
  select membership.institution_id into membership_institution
  from public.institution_memberships membership where membership.id=new.membership_id;
  if membership_institution is null then raise check_violation using message='membership not found'; end if;
  if new.institution_id is null then new.institution_id:=membership_institution; end if;
  if new.institution_id<>membership_institution then raise check_violation using message='override tenant mismatch'; end if;
  if new.scope_kind='institution' then
    new.scope_unit_id:=null;new.scope_group_id:=null;new.scope_id:=null;
  elsif new.scope_kind='unit' then
    select unit_record.institution_id into unit_institution from public.units unit_record where unit_record.id=new.scope_unit_id;
    if unit_institution is distinct from new.institution_id then raise check_violation using message='override unit tenant mismatch'; end if;
    new.scope_group_id:=null;new.scope_id:=new.scope_unit_id;
  elsif new.scope_kind='group' then
    select group_record.institution_id,group_record.unit_id into group_institution,group_unit
    from public.groups group_record where group_record.id=new.scope_group_id;
    if group_institution is distinct from new.institution_id or group_unit is distinct from new.scope_unit_id then
      raise check_violation using message='override group hierarchy mismatch';
    end if;
    new.scope_id:=new.scope_group_id;
  else raise invalid_parameter_value using message='unsupported override scope'; end if;
  if tg_op='UPDATE' then new.version:=old.version+1; end if;
  return new;
end $$;
create trigger a_institution_permission_override_typed_scope
before insert or update on public.institution_member_permission_overrides
for each row execute function app_private.normalize_institution_permission_override_scope();

-- Consolidate the legacy allow-only grant path into the typed override source.
insert into public.institution_member_permission_overrides(
  membership_id,permission_code,effect,scope_kind,scope_id,reason,starts_at,expires_at,
  status,changed_by_person_id,institution_id,scope_unit_id,scope_group_id
)
select grant_record.membership_id,grant_record.permission_code,'allow',grant_record.scope_kind,
  grant_record.scope_id,'Migrado do grant direto legado.',grant_record.starts_at,grant_record.expires_at,
  grant_record.status,coalesce(grant_record.granted_by,membership.person_id),membership.institution_id,
  case when grant_record.scope_kind='unit' then grant_record.scope_id
    when grant_record.scope_kind='group' then group_record.unit_id end,
  case when grant_record.scope_kind='group' then grant_record.scope_id end
from public.institution_role_grants grant_record
join public.institution_memberships membership on membership.id=grant_record.membership_id
left join public.groups group_record on group_record.id=grant_record.scope_id
where grant_record.status='active' and grant_record.scope_kind in('institution','unit','group')
  and not exists(select 1 from public.institution_member_permission_overrides override_record
    where override_record.membership_id=grant_record.membership_id
      and override_record.permission_code=grant_record.permission_code
      and override_record.scope_kind=grant_record.scope_kind
      and override_record.scope_id is not distinct from grant_record.scope_id
      and override_record.status='active' and override_record.revoked_at is null);
update public.institution_role_grants set status='inactive' where status='active';
revoke insert,update,delete on public.institution_role_grants from anon,authenticated;

create or replace function app_private.has_context_permission(
  target_institution_id uuid,target_permission_code text,target_unit_id uuid default null,
  target_group_id uuid default null,target_activity_id uuid default null,
  target_child_context_id uuid default null,require_institution_scope boolean default false
) returns boolean language sql stable security definer set search_path='' as $$
  with active_memberships as(
    select membership.id from public.institution_memberships membership
    where membership.person_id=app_private.current_person_id()
      and membership.institution_id=target_institution_id and membership.status='active'
      and membership.revoked_at is null
  ),role_effects as(
    select role_permission.effect from active_memberships membership
    join public.institution_role_assignments assignment on assignment.membership_id=membership.id
      and assignment.status='active' and (assignment.starts_at is null or assignment.starts_at<=now())
      and (assignment.expires_at is null or assignment.expires_at>now())
    join public.institution_roles role_record on role_record.id=assignment.role_id
      and role_record.status='active' and (role_record.institution_id is null or role_record.institution_id=target_institution_id)
    join public.institution_role_permissions role_permission on role_permission.role_id=role_record.id
      and role_permission.status='active' and role_permission.revoked_at is null
    join public.institution_permissions permission_record on permission_record.id=role_permission.permission_id
      and permission_record.code=target_permission_code and permission_record.status='active'
    where (require_institution_scope and assignment.scope_kind='institution') or
      (not require_institution_scope and (assignment.scope_kind='institution'
        or (assignment.scope_kind='unit' and assignment.scope_unit_id=target_unit_id)
        or (assignment.scope_kind='group' and assignment.scope_group_id=target_group_id
          and (target_unit_id is null or assignment.scope_unit_id=target_unit_id))))
  ),individual_effects as(
    select override_record.effect from active_memberships membership
    join public.institution_member_permission_overrides override_record on override_record.membership_id=membership.id
      and override_record.institution_id=target_institution_id
      and override_record.permission_code=target_permission_code
      and override_record.status='active' and override_record.revoked_at is null
      and (override_record.starts_at is null or override_record.starts_at<=now())
      and (override_record.expires_at is null or override_record.expires_at>now())
    where (require_institution_scope and override_record.scope_kind='institution') or
      (not require_institution_scope and (override_record.scope_kind='institution'
        or (override_record.scope_kind='unit' and override_record.scope_unit_id=target_unit_id)
        or (override_record.scope_kind='group' and override_record.scope_group_id=target_group_id
          and (target_unit_id is null or override_record.scope_unit_id=target_unit_id))))
  )
  select not exists(select 1 from individual_effects where effect='deny')
    and not exists(select 1 from role_effects where effect='deny')
    and (exists(select 1 from individual_effects where effect='allow')
      or exists(select 1 from role_effects where effect='allow'))
$$;

create table app_private.access_profile_command_receipts_v2(
  request_id uuid primary key,
  actor_person_id uuid not null references public.people(id),
  command_kind text not null,
  request_hash bytea not null,
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default(now()+interval '30 days')
);
create index access_profile_command_receipts_v2_expiry_idx
  on app_private.access_profile_command_receipts_v2(expires_at);
revoke all on app_private.access_profile_command_receipts_v2 from public,anon,authenticated;

create or replace function app_private.access_profile_require_mutation(target_domain text)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id(); required_permission text;
begin
  required_permission:=case target_domain when 'platform' then 'platform.roles.manage'
    when 'institution' then 'institution.roles.manage'
    when 'principal' then 'institution.roles.manage' end;
  if actor is null or required_permission is null or not app_private.has_platform_permission(required_permission) then
    raise insufficient_privilege using message='profile management permission required';
  end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required'; end if;
  return actor;
end $$;

create or replace function app_private.access_profile_replay(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare receipt app_private.access_profile_command_receipts_v2%rowtype;
  wanted_hash bytea:=extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256');
begin
  if p_request_id is null then raise invalid_parameter_value using message='request id required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into receipt from app_private.access_profile_command_receipts_v2
    where request_id=p_request_id for update;
  if receipt.request_id is null then return null; end if;
  if receipt.actor_person_id<>p_actor then raise insufficient_privilege using message='idempotency receipt actor mismatch'; end if;
  if receipt.command_kind<>p_command or receipt.request_hash<>wanted_hash then
    raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json||jsonb_build_object('replayed',true);
end $$;
create or replace function app_private.access_profile_store_receipt(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb,p_result jsonb
) returns void language sql volatile security definer set search_path='' as $$
  insert into app_private.access_profile_command_receipts_v2(
    request_id,actor_person_id,command_kind,request_hash,result_json
  ) values(p_request_id,p_actor,p_command,
    extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256'),p_result)
$$;

create or replace function app_private.access_profile_detail_v2(p_domain text,p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform app_private.require_profile_authority(p_domain);
  if p_domain='platform' then
    select to_jsonb(role_record)||jsonb_build_object('domain','platform',
      'linked_people_count',(select count(*) from public.platform_memberships membership
        where membership.role_id=role_record.id and membership.status='active' and membership.revoked_at is null),
      'capability_count',(select count(*) from public.platform_role_permissions grant_record
        where grant_record.role_id=role_record.id and grant_record.status='active' and grant_record.revoked_at is null))
    into result from public.platform_roles role_record where role_record.id=p_profile_id;
  elsif p_domain='institution' then
    select to_jsonb(role_record)||jsonb_build_object('domain','institution',
      'linked_people_count',(select count(*) from public.institution_role_assignments assignment
        where assignment.role_id=role_record.id and assignment.status='active'
          and (assignment.expires_at is null or assignment.expires_at>now())),
      'capability_count',(select count(*) from public.institution_role_permissions grant_record
        where grant_record.role_id=role_record.id and grant_record.status='active' and grant_record.revoked_at is null))
    into result from public.institution_roles role_record where role_record.id=p_profile_id;
  else raise invalid_parameter_value using message='unsupported profile domain'; end if;
  if result is null then raise no_data_found using message='access profile not found'; end if;
  return result;
end $$;

create or replace function app_private.access_profile_create_internal(
  p_actor uuid,p_draft jsonb,p_source_template_id uuid default null,p_source_template_version bigint default null
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare domain text:=p_draft->>'domain'; profile_id uuid; generated_code text;
  capability jsonb; capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
begin
  if domain not in('platform','institution') or nullif(btrim(p_draft->>'name'),'') is null
    or jsonb_typeof(capabilities)<>'array' then raise invalid_parameter_value using message='invalid profile draft'; end if;
  generated_code:=trim(both '-' from regexp_replace(lower(btrim(p_draft->>'name')),'[^a-z0-9]+','-','g'))
    ||'-'||left(replace(gen_random_uuid()::text,'-',''),8);
  if domain='platform' then
    if coalesce(p_draft->>'max_scope_kind','platform') not in('platform','institution') then
      raise invalid_parameter_value using message='invalid platform profile scope'; end if;
    for capability in select value from jsonb_array_elements(capabilities) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.platform_permissions
        where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability'; end if;
      if capability->>'effect'='allow' and not app_private.has_platform_permission(capability->>'code') then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold'; end if;
    end loop;
    insert into public.platform_roles(code,name,description,status,is_system,created_by,max_scope_kind,
      source_template_id,source_template_version)
    values(generated_code,btrim(p_draft->>'name'),nullif(btrim(p_draft->>'description'),''),
      coalesce(p_draft->>'status','active')::public.record_status,false,p_actor,
      coalesce(p_draft->>'max_scope_kind','platform'),p_source_template_id,p_source_template_version)
    returning id into profile_id;
    insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}'::jsonb,p_actor,'active'
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions permission_record on permission_record.code=item.value->>'code';
  else
    if coalesce(p_draft->>'max_scope_kind','institution') not in('institution','unit','group') then
      raise invalid_parameter_value using message='invalid institution profile scope'; end if;
    for capability in select value from jsonb_array_elements(capabilities) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.institution_permissions
        where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability'; end if;
    end loop;
    insert into public.institution_roles(institution_id,code,name,description,status,is_system,max_scope_kind,
      source_template_id,source_template_version)
    values(null,generated_code,btrim(p_draft->>'name'),nullif(btrim(p_draft->>'description'),''),
      coalesce(p_draft->>'status','active')::public.record_status,false,
      coalesce(p_draft->>'max_scope_kind','institution'),p_source_template_id,p_source_template_version)
    returning id into profile_id;
    insert into public.institution_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}'::jsonb,p_actor,'active'
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions permission_record on permission_record.code=item.value->>'code';
  end if;
  return app_private.access_profile_detail_v2(domain,profile_id);
end $$;

create or replace function app_private.superadmin_access_profiles_cursor(
  p_query text default null,p_domain text default null,p_status text default null,
  p_scope text default null,p_limit integer default 25,p_after_name text default null,p_after_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare size_no int:=least(greatest(coalesce(p_limit,25),1),100); result jsonb;
begin
  if p_domain not in('platform','institution') then raise invalid_parameter_value using message='unsupported profile domain'; end if;
  perform app_private.require_profile_authority(p_domain);
  if p_domain='platform' then
    with rows as(select role_record.id,'platform'::text domain,role_record.code,role_record.name,
      role_record.description,role_record.status::text,role_record.max_scope_kind,role_record.version,
      role_record.source_template_id,role_record.source_template_version,role_record.is_system,
      (select count(*) from public.platform_memberships membership where membership.role_id=role_record.id
        and membership.status='active' and membership.revoked_at is null)::int linked_people_count,
      (select count(*) from public.platform_role_permissions grant_record where grant_record.role_id=role_record.id
        and grant_record.status='active' and grant_record.revoked_at is null)::int capability_count
      from public.platform_roles role_record where (nullif(btrim(p_query),'') is null or role_record.name ilike '%'||btrim(p_query)||'%')
        and (p_status is null or role_record.status::text=p_status) and (p_scope is null or role_record.max_scope_kind=p_scope)
        and (p_after_name is null or (lower(role_record.name),role_record.id)>(lower(p_after_name),p_after_id))),
    page as(select * from rows order by lower(name),id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
      filter(where row_number<=size_no),'[]'::jsonb),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',name,'id',id) from page order by lower(name),id offset size_no-1 limit 1) end)
    into result from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  else
    with rows as(select role_record.id,'institution'::text domain,role_record.code,role_record.name,
      role_record.description,role_record.status::text,role_record.max_scope_kind,role_record.version,
      role_record.source_template_id,role_record.source_template_version,role_record.is_system,
      (select count(*) from public.institution_role_assignments assignment where assignment.role_id=role_record.id
        and assignment.status='active' and (assignment.expires_at is null or assignment.expires_at>now()))::int linked_people_count,
      (select count(*) from public.institution_role_permissions grant_record where grant_record.role_id=role_record.id
        and grant_record.status='active' and grant_record.revoked_at is null)::int capability_count
      from public.institution_roles role_record where (nullif(btrim(p_query),'') is null or role_record.name ilike '%'||btrim(p_query)||'%')
        and (p_status is null or role_record.status::text=p_status) and (p_scope is null or role_record.max_scope_kind=p_scope)
        and (p_after_name is null or (lower(role_record.name),role_record.id)>(lower(p_after_name),p_after_id))),
    page as(select * from rows order by lower(name),id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
      filter(where row_number<=size_no),'[]'::jsonb),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',name,'id',id) from page order by lower(name),id offset size_no-1 limit 1) end)
    into result from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  end if;
  return result;
end $$;

create or replace function app_private.superadmin_access_profile_models_cursor(
  p_query text default null,p_domain text default null,p_status text default null,
  p_scope text default null,p_limit integer default 25,p_after_name text default null,p_after_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare size_no int:=least(greatest(coalesce(p_limit,25),1),100); result jsonb;
begin
  if p_domain not in('platform','institution','principal') then raise invalid_parameter_value using message='unsupported profile domain'; end if;
  perform app_private.require_profile_authority(case when p_domain='principal' then 'principal' else p_domain end);
  with rows as(select template.id,template.domain,template.code,template.name,template.description,
    template.status::text,template.max_scope_kind,template.version,template.is_system,
    case template.domain when 'platform' then (select count(*) from public.access_profile_template_platform_permissions item where item.template_id=template.id)
      when 'institution' then (select count(*) from public.access_profile_template_institution_permissions item where item.template_id=template.id)
      else (select count(*) from public.access_profile_template_principal_capabilities item where item.template_id=template.id) end::int capability_count
    from public.access_profile_templates template
    where template.domain=p_domain and (nullif(btrim(p_query),'') is null or template.name ilike '%'||btrim(p_query)||'%')
      and (p_status is null or template.status::text=p_status) and (p_scope is null or template.max_scope_kind=p_scope)
      and (p_after_name is null or (lower(template.name),template.id)>(lower(p_after_name),p_after_id))),
  page as(select * from rows order by lower(name),id limit size_no+1)
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
    filter(where row_number<=size_no),'[]'::jsonb),'next_cursor',case when count(*)>size_no then
    (select jsonb_build_object('name',name,'id',id) from page order by lower(name),id offset size_no-1 limit 1) end)
  into result from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  return result;
end $$;

create or replace function app_private.superadmin_access_profile_capability_catalog(
  p_domain text,p_profile_id uuid default null,p_assignment_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb; catalog_version bigint; profile_version bigint:=0;
begin
  perform app_private.require_profile_authority(p_domain);
  select version into catalog_version from app_private.access_profile_catalog_versions where domain=p_domain;
  if p_domain='platform' then
    select version into profile_version from public.platform_roles where id=p_profile_id;
    select jsonb_build_object('catalog_version',catalog_version,'profile_version',coalesce(profile_version,0),
      'items',coalesce(jsonb_agg(jsonb_build_object('id',permission_record.id,'code',permission_record.code,
        'module_code',permission_record.module_code,'module_label',permission_record.module_label,
        'screen_code',coalesce(permission_record.screen_code,permission_record.module_code),'screen_label',permission_record.screen_label,
        'action_code',case permission_record.action_code when 'read' then 'view' when 'update' then 'edit' else permission_record.action_code end,
        'action_label',permission_record.action_label,'description',permission_record.description,'risk',permission_record.risk_level,
        'requires_mfa',permission_record.requires_mfa,'configured_effect',coalesce(profile_grant.effect::text,'inherit'),
        'inherited_effect','none','effective_effect',case when assignment_override.effect='deny' then 'deny'
          when assignment_override.effect='allow' then 'allow' when profile_grant.effect='allow' then 'allow' else 'deny' end,
        'origin_code',case when assignment_override.effect is not null then 'member_override'
          when profile_grant.effect is not null then 'profile' else 'default_deny' end,
        'origin_label',case when assignment_override.effect is not null then 'Personalização da pessoa'
          when profile_grant.effect is not null then 'Perfil' else 'Negado por padrão' end,
        'grantable',app_private.has_platform_permission(permission_record.code),
        'disabled_reason',case when app_private.has_platform_permission(permission_record.code) then null
          else 'Você não pode conceder uma permissão que não possui.' end)
        order by permission_record.module_code,permission_record.screen_code,permission_record.action_code,permission_record.code),'[]'::jsonb))
    into result from public.platform_permissions permission_record
    left join public.platform_role_permissions profile_grant on profile_grant.role_id=p_profile_id
      and profile_grant.permission_id=permission_record.id and profile_grant.status='active' and profile_grant.revoked_at is null
    left join public.platform_member_permission_overrides assignment_override on assignment_override.membership_id=p_assignment_id
      and assignment_override.permission_id=permission_record.id and assignment_override.status='active'
      and (assignment_override.starts_at is null or assignment_override.starts_at<=now())
      and (assignment_override.expires_at is null or assignment_override.expires_at>now())
    where permission_record.status='active';
  elsif p_domain='institution' then
    select version into profile_version from public.institution_roles where id=p_profile_id;
    select jsonb_build_object('catalog_version',catalog_version,'profile_version',coalesce(profile_version,0),
      'items',coalesce(jsonb_agg(jsonb_build_object('id',permission_record.id,'code',permission_record.code,
        'module_code',permission_record.module_code,'module_label',permission_record.module_label,
        'screen_code',coalesce(permission_record.screen_code,permission_record.module_code),'screen_label',permission_record.screen_label,
        'action_code',case permission_record.action_code when 'read' then 'view' when 'update' then 'edit' else permission_record.action_code end,
        'action_label',permission_record.action_label,'description',permission_record.description,'risk',permission_record.risk_level,
        'requires_mfa',permission_record.requires_mfa,'configured_effect',coalesce(profile_grant.effect::text,'inherit'),
        'inherited_effect',coalesce(profile_grant.effect::text,'none'),
        'effective_effect',case when bool_or(assignment_override.effect='deny') then 'deny'
          when bool_or(assignment_override.effect='allow') then 'allow' when profile_grant.effect='allow' then 'allow' else 'deny' end,
        'origin_code',case when count(assignment_override.id)>0 then 'member_override'
          when profile_grant.effect is not null then 'profile' else 'default_deny' end,
        'origin_label',case when count(assignment_override.id)>0 then 'Personalização da pessoa'
          when profile_grant.effect is not null then 'Perfil' else 'Negado por padrão' end,
        'grantable',app_private.has_platform_permission('institution.roles.manage'),
        'disabled_reason',case when app_private.has_platform_permission('institution.roles.manage') then null
          else 'Você não pode conceder permissões administrativas.' end)
        order by permission_record.module_code,permission_record.screen_code,permission_record.action_code,permission_record.code),'[]'::jsonb))
    into result from public.institution_permissions permission_record
    left join public.institution_role_permissions profile_grant on profile_grant.role_id=p_profile_id
      and profile_grant.permission_id=permission_record.id and profile_grant.status='active' and profile_grant.revoked_at is null
    left join public.institution_role_assignments assignment on assignment.id=p_assignment_id
    left join public.institution_member_permission_overrides assignment_override
      on assignment_override.membership_id=assignment.membership_id and assignment_override.permission_code=permission_record.code
      and assignment_override.status='active' and assignment_override.revoked_at is null
      and (assignment_override.starts_at is null or assignment_override.starts_at<=now())
      and (assignment_override.expires_at is null or assignment_override.expires_at>now())
    where permission_record.status='active'
    group by permission_record.id,profile_grant.effect;
  elsif p_domain='principal' then
    select version into profile_version from public.guardian_context_permissions where id=p_assignment_id;
    select jsonb_build_object('catalog_version',catalog_version,'profile_version',coalesce(profile_version,0),
      'items',coalesce(jsonb_agg(jsonb_build_object('id',capability.id,'code',capability.code,
        'module_code',capability.module_code,'module_label',capability.module_label,'screen_code',capability.screen_code,
        'screen_label',capability.screen_label,'action_code',capability.action_code,'action_label',capability.action_label,
        'description',capability.description,'risk',capability.risk_level,'requires_mfa',capability.requires_mfa,
        'configured_effect',coalesce(context_grant.effect::text,'inherit'),'inherited_effect','none',
        'effective_effect',case when context_grant.effect='allow' then 'allow' else 'deny' end,
        'origin_code',case when context_grant.effect is not null then 'guardian_grant' else 'default_deny' end,
        'origin_label',case when context_grant.effect is not null then 'Permissão do contexto' else 'Negado por padrão' end,
        'grantable',app_private.has_platform_permission('institution.roles.manage'),
        'disabled_reason',case when app_private.has_platform_permission('institution.roles.manage') then null
          else 'Você não pode conceder permissões familiares.' end)
        order by capability.screen_code,capability.action_code,capability.code),'[]'::jsonb))
    into result from public.guardian_permission_capabilities capability
    left join public.guardian_context_permission_grants context_grant
      on context_grant.guardian_context_permission_id=p_assignment_id and context_grant.capability_id=capability.id
      and context_grant.status='active' and context_grant.revoked_at is null
    where capability.status='active';
  else raise invalid_parameter_value using message='unsupported profile domain'; end if;
  return result;
end $$;

create or replace function app_private.superadmin_access_profile_create(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid; replay jsonb; profile jsonb; result jsonb; domain text:=p_draft->>'domain';
begin
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'create',p_draft);if replay is not null then return replay;end if;
  profile:=app_private.access_profile_create_internal(actor,p_draft);
  result:=jsonb_build_object('profile',profile,'profile_id',profile->>'id','domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',(profile->>'id')::uuid,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Criação de perfil.'),profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'create',p_draft,result);
  return result;
end $$;

create or replace function app_private.superadmin_access_profile_create_from_model(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare template public.access_profile_templates%rowtype;actor uuid;replay jsonb;profile jsonb;result jsonb;
  capabilities jsonb;context_id uuid;before_data jsonb;
begin
  select * into template from public.access_profile_templates where id=nullif(p_draft->>'model_id','')::uuid for update;
  if template.id is null or template.status<>'active' then raise no_data_found using message='access profile model not found';end if;
  actor:=app_private.access_profile_require_mutation(template.domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'create_from_model',p_draft);if replay is not null then return replay;end if;
  if template.domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',item.effect::text)
      order by permission_record.code),'[]'::jsonb) into capabilities
    from public.access_profile_template_platform_permissions item
    join public.platform_permissions permission_record on permission_record.id=item.permission_id where item.template_id=template.id;
  elsif template.domain='institution' then
    select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',item.effect::text)
      order by permission_record.code),'[]'::jsonb) into capabilities
    from public.access_profile_template_institution_permissions item
    join public.institution_permissions permission_record on permission_record.id=item.permission_id where item.template_id=template.id;
  else
    context_id:=nullif(p_draft->>'guardian_context_permission_id','')::uuid;
    select to_jsonb(context_record) into before_data from public.guardian_context_permissions context_record
      where context_record.id=context_id for update;
    if before_data is null then raise no_data_found using message='guardian context not found';end if;
    insert into public.guardian_context_permission_grants(
      guardian_context_permission_id,capability_id,effect,status,changed_by_person_id,reason
    ) select context_id,item.capability_id,item.effect,'active',actor,'Modelo copiado como snapshot.'
      from public.access_profile_template_principal_capabilities item where item.template_id=template.id
    on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
      changed_by_person_id=excluded.changed_by_person_id,reason=excluded.reason,revoked_at=null,updated_at=now();
    update public.guardian_context_permissions set source_template_id=template.id,
      source_template_version=template.version,version=version+1,updated_at=now() where id=context_id;
    profile:=jsonb_build_object('id',context_id,'domain','principal','version',
      (select version from public.guardian_context_permissions where id=context_id),
      'source_template_id',template.id,'source_template_version',template.version);
    result:=jsonb_build_object('profile',profile,'profile_id',context_id,'domain','principal',
      'version',profile->'version','replayed',false);
    insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
    values(actor,'aal2','permission_changed','principal_context_permissions',context_id,'success',
      coalesce(nullif(btrim(p_draft->>'reason'),''),'Aplicação de modelo Principal.'),before_data,profile);
    perform app_private.access_profile_store_receipt(p_request_id,actor,'create_from_model',p_draft,result);
    return result;
  end if;
  profile:=app_private.access_profile_create_internal(actor,
    jsonb_build_object('domain',template.domain,'name',coalesce(nullif(btrim(p_draft->>'name'),''),template.name),
      'description',coalesce(p_draft->>'description',template.description),'status','active',
      'max_scope_kind',coalesce(p_draft->>'max_scope_kind',template.max_scope_kind),'capabilities',capabilities),
    template.id,template.version);
  result:=jsonb_build_object('profile',profile,'profile_id',profile->>'id','domain',template.domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed',template.domain||'_access_profile',(profile->>'id')::uuid,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Criação a partir de modelo.'),profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'create_from_model',p_draft,result);
  return result;
end $$;

create or replace function app_private.superadmin_access_profile_duplicate(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare source_id uuid:=nullif(p_draft->>'source_profile_id','')::uuid;domain text;
  actor uuid;replay jsonb;source jsonb;capabilities jsonb;profile jsonb;result jsonb;
begin
  if p_draft ? 'source_model_id' then
    return app_private.superadmin_access_profile_create_from_model(p_request_id,
      (p_draft-'source_model_id')||jsonb_build_object('model_id',p_draft->>'source_model_id'));
  end if;
  select case when exists(select 1 from public.platform_roles where id=source_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=source_id) then 'institution' end into domain;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'duplicate',p_draft);if replay is not null then return replay;end if;
  source:=app_private.access_profile_detail_v2(domain,source_id);
  if domain='platform' then select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',grant_record.effect::text)),'[]')
    into capabilities from public.platform_role_permissions grant_record join public.platform_permissions permission_record
      on permission_record.id=grant_record.permission_id where grant_record.role_id=source_id and grant_record.status='active' and grant_record.revoked_at is null;
  else select coalesce(jsonb_agg(jsonb_build_object('code',permission_record.code,'effect',grant_record.effect::text)),'[]')
    into capabilities from public.institution_role_permissions grant_record join public.institution_permissions permission_record
      on permission_record.id=grant_record.permission_id where grant_record.role_id=source_id and grant_record.status='active' and grant_record.revoked_at is null;end if;
  profile:=app_private.access_profile_create_internal(actor,jsonb_build_object('domain',domain,
    'name',coalesce(nullif(btrim(p_draft->>'name'),''),source->>'name'||' (cópia)'),
    'description',coalesce(p_draft->>'description',source->>'description'),'status','active',
    'max_scope_kind',source->>'max_scope_kind','capabilities',capabilities));
  result:=jsonb_build_object('profile',profile,'profile_id',profile->>'id','domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',(profile->>'id')::uuid,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Duplicação de perfil.'),source,profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'duplicate',p_draft,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_update(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare domain text:=p_draft->>'domain';profile_id uuid:=nullif(p_draft->>'id','')::uuid;actor uuid;
  replay jsonb;before_data jsonb;profile jsonb;result jsonb;capability jsonb;
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'update',p_draft);if replay is not null then return replay;end if;
  perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
  before_data:=app_private.access_profile_detail_v2(domain,profile_id);
  if (before_data->>'is_system')::boolean then raise insufficient_privilege using message='system profile is protected';end if;
  if (before_data->>'version')::bigint is distinct from expected_version then raise serialization_failure using message='stale profile version';end if;
  if jsonb_typeof(coalesce(p_draft->'capabilities','[]'))<>'array' then raise invalid_parameter_value using message='invalid capabilities';end if;
  if domain='platform' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.platform_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
      if capability->>'effect'='allow' and not app_private.has_platform_permission(capability->>'code') then
        raise insufficient_privilege using message='cannot delegate capability operator does not hold';end if;
    end loop;
    update public.platform_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.platform_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.platform_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.platform_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    for capability in select value from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) loop
      if capability->>'effect' not in('allow','deny') or not exists(select 1 from public.institution_permissions where code=capability->>'code' and status='active') then
        raise invalid_parameter_value using message='unknown or invalid capability';end if;
    end loop;
    update public.institution_roles set name=btrim(p_draft->>'name'),description=nullif(btrim(p_draft->>'description'),''),
      status=coalesce(p_draft->>'status',status::text)::public.record_status,
      max_scope_kind=coalesce(p_draft->>'max_scope_kind',max_scope_kind),version=version+1,updated_at=now() where id=profile_id;
    update public.institution_role_permissions set status='inactive',revoked_at=now() where role_id=profile_id and status='active';
    insert into public.institution_role_permissions(role_id,permission_id,effect,conditions_json,granted_by,status)
    select profile_id,permission_record.id,(item.value->>'effect')::public.permission_effect,'{}',actor,'active'
    from jsonb_array_elements(coalesce(p_draft->'capabilities','[]')) item
    join public.institution_permissions permission_record on permission_record.code=item.value->>'code'
    on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null,granted_by=actor;
  else raise invalid_parameter_value using message='unsupported profile domain';end if;
  profile:=app_private.access_profile_detail_v2(domain,profile_id);
  result:=jsonb_build_object('profile',profile,'profile_id',profile_id,'domain',domain,
    'version',(profile->>'version')::bigint,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,before_json,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile',profile_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Atualização de perfil.'),before_data,profile);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'update',p_draft,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_assignment_candidates(
  p_profile_id uuid,p_query text default null,p_limit integer default 25,p_after_name text default null,p_after_person_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare domain text;size_no int:=least(greatest(coalesce(p_limit,25),1),100);result jsonb;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=p_profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=p_profile_id) then 'institution' end;
  perform app_private.require_profile_authority(domain);
  if not app_private.has_platform_permission('people.read') then raise insufficient_privilege using message='people read permission required';end if;
  if domain='platform' then
    with rows as(select person_record.id person_id,person_record.display_name,null::uuid membership_id,null::uuid institution_id
      from public.people person_record where person_record.status='active' and person_record.deleted_at is null
        and (nullif(btrim(p_query),'') is null or person_record.display_name ilike '%'||btrim(p_query)||'%')
        and (p_after_name is null or (lower(person_record.display_name),person_record.id)>(lower(p_after_name),p_after_person_id))
        and not exists(select 1 from public.platform_memberships membership where membership.person_id=person_record.id
          and membership.role_id=p_profile_id and membership.status='active' and membership.revoked_at is null)),
    page as(select * from rows order by lower(display_name),person_id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(display_name),person_id)
      filter(where row_number<=size_no),'[]'),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',display_name,'id',person_id) from page order by lower(display_name),person_id offset size_no-1 limit 1) end)
    into result from(select page.*,row_number() over(order by lower(display_name),person_id) row_number from page) page;
  else
    with rows as(select person_record.id person_id,person_record.display_name,membership.id membership_id,membership.institution_id
      from public.institution_memberships membership join public.people person_record on person_record.id=membership.person_id
      join public.institution_roles role_record on role_record.id=p_profile_id
      where membership.status='active' and membership.revoked_at is null and person_record.deleted_at is null
        and (role_record.institution_id is null or role_record.institution_id=membership.institution_id)
        and (nullif(btrim(p_query),'') is null or person_record.display_name ilike '%'||btrim(p_query)||'%')
        and (p_after_name is null or (lower(person_record.display_name),person_record.id)>(lower(p_after_name),p_after_person_id))
        and not exists(select 1 from public.institution_role_assignments assignment where assignment.membership_id=membership.id
          and assignment.role_id=p_profile_id and assignment.status='active'
          and (assignment.expires_at is null or assignment.expires_at>now()))),
    page as(select * from rows order by lower(display_name),person_id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(display_name),person_id)
      filter(where row_number<=size_no),'[]'),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',display_name,'id',person_id) from page order by lower(display_name),person_id offset size_no-1 limit 1) end)
    into result from(select page.*,row_number() over(order by lower(display_name),person_id) row_number from page) page;
  end if;return result;
end $$;

create or replace function app_private.superadmin_access_profile_assignments_cursor(
  p_profile_id uuid,p_limit integer default 25,p_after_name text default null,p_after_person_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare domain text;size_no int:=least(greatest(coalesce(p_limit,25),1),100);result jsonb;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=p_profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=p_profile_id) then 'institution' end;
  perform app_private.require_profile_authority(domain);
  if domain='platform' then
    with rows as(select membership.id assignment_id,membership.person_id,person_record.display_name,
      membership.scope_kind,membership.scope_institution_id institution_id,null::uuid unit_id,null::uuid group_id,membership.version
      from public.platform_memberships membership join public.people person_record on person_record.id=membership.person_id
      where membership.role_id=p_profile_id and membership.status='active' and membership.revoked_at is null
        and (p_after_name is null or (lower(person_record.display_name),person_record.id)>(lower(p_after_name),p_after_person_id))),
    page as(select * from rows order by lower(display_name),person_id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(display_name),person_id)
      filter(where row_number<=size_no),'[]'),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',display_name,'id',person_id) from page order by lower(display_name),person_id offset size_no-1 limit 1) end)
    into result from(select page.*,row_number() over(order by lower(display_name),person_id) row_number from page) page;
  else
    with rows as(select assignment.id assignment_id,membership.person_id,person_record.display_name,
      assignment.scope_kind,membership.institution_id,assignment.scope_unit_id unit_id,assignment.scope_group_id group_id,assignment.version
      from public.institution_role_assignments assignment join public.institution_memberships membership on membership.id=assignment.membership_id
      join public.people person_record on person_record.id=membership.person_id where assignment.role_id=p_profile_id
        and assignment.status='active' and (assignment.expires_at is null or assignment.expires_at>now())
        and (p_after_name is null or (lower(person_record.display_name),person_record.id)>(lower(p_after_name),p_after_person_id))),
    page as(select * from rows order by lower(display_name),person_id limit size_no+1)
    select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(page) order by lower(display_name),person_id)
      filter(where row_number<=size_no),'[]'),'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',display_name,'id',person_id) from page order by lower(display_name),person_id offset size_no-1 limit 1) end)
    into result from(select page.*,row_number() over(order by lower(display_name),person_id) row_number from page) page;
  end if;return result;
end $$;

create or replace function app_private.superadmin_access_profile_assignment_link(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare profile_id uuid:=nullif(p_draft->>'profile_id','')::uuid;domain text;actor uuid;replay jsonb;
  person_id uuid:=nullif(p_draft->>'person_id','')::uuid;membership public.institution_memberships%rowtype;
  assignment_id uuid;result jsonb;scope_kind text:=coalesce(p_draft->>'scope_kind','institution');permission_code text;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=profile_id) then 'institution'
    when exists(select 1 from public.access_profile_templates where id=profile_id and domain='principal') then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'assignment_link',p_draft);if replay is not null then return replay;end if;
  if domain='platform' then
    perform 1 from public.people where id=person_id and status='active' and deleted_at is null for update;
    if not found then raise no_data_found using message='person not found';end if;
    if person_id=actor and exists(select 1 from public.platform_role_permissions grant_record
      join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
      where grant_record.role_id=profile_id and grant_record.effect='allow' and grant_record.status='active'
        and grant_record.revoked_at is null and not app_private.has_platform_permission(permission_record.code)) then
      raise insufficient_privilege using message='cannot elevate own access';end if;
    insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required,invited_by)
    values(person_id,profile_id,'active',coalesce(p_draft->>'scope_kind','platform'),
      nullif(p_draft->>'institution_id','')::uuid,true,actor) returning id into assignment_id;
  elsif domain='institution' then
    select * into membership from public.institution_memberships where id=nullif(p_draft->>'membership_id','')::uuid for update;
    if membership.id is null or membership.person_id<>person_id or membership.status<>'active' or membership.revoked_at is not null then
      raise no_data_found using message='authorized membership not found';end if;
    if person_id=actor then for permission_code in select permission_record.code from public.institution_role_permissions grant_record
      join public.institution_permissions permission_record on permission_record.id=grant_record.permission_id
      where grant_record.role_id=profile_id and grant_record.effect='allow' and grant_record.status='active' and grant_record.revoked_at is null loop
      if not app_private.has_context_permission(membership.institution_id,permission_code,
        nullif(p_draft->>'unit_id','')::uuid,nullif(p_draft->>'group_id','')::uuid) then
        raise insufficient_privilege using message='cannot elevate own access';end if;end loop;end if;
    insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id,scope_group_id,
      starts_at,expires_at,granted_by,status) values(membership.id,profile_id,scope_kind,
      nullif(p_draft->>'unit_id','')::uuid,nullif(p_draft->>'group_id','')::uuid,
      nullif(p_draft->>'starts_at','')::timestamptz,nullif(p_draft->>'expires_at','')::timestamptz,actor,'active')
      returning id into assignment_id;
  else
    return app_private.superadmin_access_profile_create_from_model(p_request_id,
      jsonb_build_object('model_id',profile_id,'guardian_context_permission_id',p_draft->>'guardian_context_permission_id',
        'reason',coalesce(p_draft->>'reason','Vínculo de modelo Principal.')));
  end if;
  result:=jsonb_build_object('assignment_id',assignment_id,'profile_id',profile_id,'domain',domain,'version',1,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','membership_changed',domain||'_access_profile_assignment',assignment_id,'success',
    coalesce(nullif(btrim(p_draft->>'reason'),''),'Vínculo de pessoa ao perfil.'),result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'assignment_link',p_draft,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_assignment_unlink(
  p_request_id uuid,p_assignment_id uuid,p_expected_version bigint,p_reason text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare domain text;actor uuid;payload jsonb:=jsonb_build_object('assignment_id',p_assignment_id,
  'expected_version',p_expected_version,'reason',p_reason);replay jsonb;current_version bigint;result jsonb;
begin
  domain:=case when exists(select 1 from public.platform_memberships where id=p_assignment_id) then 'platform'
    when exists(select 1 from public.institution_role_assignments where id=p_assignment_id) then 'institution'
    when exists(select 1 from public.guardian_context_permissions where id=p_assignment_id) then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'assignment_unlink',payload);if replay is not null then return replay;end if;
  if nullif(btrim(p_reason),'') is null then raise invalid_parameter_value using message='reason required';end if;
  if domain='platform' then
    perform pg_advisory_xact_lock(hashtextextended('access-profile-full-authority',0));
    select version into current_version from public.platform_memberships where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    update public.platform_memberships set status='revoked',revoked_at=now(),version=version+1 where id=p_assignment_id;
    perform app_private.assert_full_authority_remains();
  elsif domain='institution' then
    select version into current_version from public.institution_role_assignments where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    update public.institution_role_assignments set status='inactive',version=version+1,updated_at=now() where id=p_assignment_id;
  elsif domain='principal' then
    select version into current_version from public.guardian_context_permissions where id=p_assignment_id for update;
    if current_version is distinct from p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    update public.guardian_context_permissions set status='inactive',version=version+1,updated_at=now() where id=p_assignment_id;
  else raise no_data_found using message='assignment not found';end if;
  result:=jsonb_build_object('assignment_id',p_assignment_id,'domain',domain,'version',current_version+1,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','membership_changed',domain||'_access_profile_assignment',p_assignment_id,'success',p_reason,result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'assignment_unlink',payload,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_assignment_overrides_save(
  p_request_id uuid,p_assignment_id uuid,p_expected_version bigint,p_overrides jsonb,p_reason text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare domain text;actor uuid;payload jsonb:=jsonb_build_object('assignment_id',p_assignment_id,
  'expected_version',p_expected_version,'overrides',p_overrides,'reason',p_reason);replay jsonb;
  assignment public.institution_role_assignments%rowtype;membership public.institution_memberships%rowtype;
  item jsonb;permission public.institution_permissions%rowtype;capability public.guardian_permission_capabilities%rowtype;
  current_version bigint;result jsonb;platform_membership public.platform_memberships%rowtype;platform_permission public.platform_permissions%rowtype;
begin
  if jsonb_typeof(p_overrides)<>'array' or nullif(btrim(p_reason),'') is null then raise invalid_parameter_value using message='invalid overrides';end if;
  domain:=case when exists(select 1 from public.platform_memberships where id=p_assignment_id) then 'platform'
    when exists(select 1 from public.institution_role_assignments where id=p_assignment_id) then 'institution'
    when exists(select 1 from public.guardian_context_permissions where id=p_assignment_id) then 'principal' end;
  actor:=app_private.access_profile_require_mutation(domain);
  replay:=app_private.access_profile_replay(p_request_id,actor,'overrides_save',payload);if replay is not null then return replay;end if;
  if domain='platform' then
    select * into platform_membership from public.platform_memberships where id=p_assignment_id for update;
    if platform_membership.version<>p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into platform_permission from public.platform_permissions where code=item->>'capability_code' and status='active';
      if platform_permission.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if platform_membership.person_id=actor and item->>'intent'='allow' and not app_private.has_platform_permission(platform_permission.code) then
        raise insufficient_privilege using message='cannot elevate own access';end if;
      if item->>'intent'='inherit' then update public.platform_member_permission_overrides set status='inactive'
        where membership_id=p_assignment_id and permission_id=platform_permission.id;
      else insert into public.platform_member_permission_overrides(membership_id,permission_id,effect,conditions_json,granted_by,status)
        values(p_assignment_id,platform_permission.id,(item->>'intent')::public.permission_effect,'{}',actor,'active')
        on conflict(membership_id,permission_id) do update set effect=excluded.effect,status='active',granted_by=actor;end if;
    end loop;
    update public.platform_memberships set version=version+1 where id=p_assignment_id returning version into current_version;
  elsif domain='institution' then
    select * into assignment from public.institution_role_assignments where id=p_assignment_id for update;
    if assignment.version<>p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    select * into membership from public.institution_memberships where id=assignment.membership_id;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into permission from public.institution_permissions where code=item->>'capability_code' and status='active';
      if permission.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if membership.person_id=actor and item->>'intent'='allow' and not app_private.has_context_permission(
        membership.institution_id,permission.code,assignment.scope_unit_id,assignment.scope_group_id) then
        raise insufficient_privilege using message='cannot elevate own access';end if;
      if item->>'intent'='inherit' then update public.institution_member_permission_overrides set status='inactive',revoked_at=now(),
        changed_by_person_id=actor where membership_id=membership.id and permission_code=permission.code
          and institution_id=membership.institution_id and scope_kind=assignment.scope_kind
          and scope_unit_id is not distinct from assignment.scope_unit_id and scope_group_id is not distinct from assignment.scope_group_id;
      else insert into public.institution_member_permission_overrides(membership_id,permission_code,effect,scope_kind,scope_id,
        reason,status,changed_by_person_id,institution_id,scope_unit_id,scope_group_id)
        values(membership.id,permission.code,(item->>'intent')::public.permission_effect,assignment.scope_kind,
          case assignment.scope_kind when 'unit' then assignment.scope_unit_id when 'group' then assignment.scope_group_id end,
          p_reason,'active',actor,membership.institution_id,assignment.scope_unit_id,assignment.scope_group_id)
        on conflict(membership_id,permission_code,scope_kind,(coalesce(scope_id,'00000000-0000-0000-0000-000000000000'::uuid)))
          where status='active' and revoked_at is null do update set effect=excluded.effect,reason=excluded.reason,
            changed_by_person_id=actor,updated_at=now();end if;
    end loop;
    update public.institution_role_assignments set version=version+1,updated_at=now() where id=p_assignment_id returning version into current_version;
  elsif domain='principal' then
    select version into current_version from public.guardian_context_permissions where id=p_assignment_id for update;
    if current_version<>p_expected_version then raise serialization_failure using message='stale assignment version';end if;
    for item in select value from jsonb_array_elements(p_overrides) loop
      if item->>'intent' not in('inherit','allow','deny') then raise invalid_parameter_value using message='invalid override intent';end if;
      select * into capability from public.guardian_permission_capabilities where code=item->>'capability_code' and status='active';
      if capability.id is null then raise invalid_parameter_value using message='unknown capability';end if;
      if item->>'intent'='inherit' then update public.guardian_context_permission_grants set status='inactive',revoked_at=now(),
        changed_by_person_id=actor,updated_at=now() where guardian_context_permission_id=p_assignment_id and capability_id=capability.id;
      else insert into public.guardian_context_permission_grants(guardian_context_permission_id,capability_id,effect,status,
        changed_by_person_id,reason) values(p_assignment_id,capability.id,(item->>'intent')::public.permission_effect,'active',actor,p_reason)
        on conflict(guardian_context_permission_id,capability_id) do update set effect=excluded.effect,status='active',
          changed_by_person_id=actor,reason=p_reason,revoked_at=null,updated_at=now();end if;
    end loop;
    update public.guardian_context_permissions set version=version+1,updated_at=now() where id=p_assignment_id returning version into current_version;
  else raise no_data_found using message='assignment not found';end if;
  result:=jsonb_build_object('assignment_id',p_assignment_id,'domain',domain,'version',current_version,'replayed',false,
    'capabilities',app_private.superadmin_access_profile_capability_catalog(domain,null,p_assignment_id));
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed',domain||'_access_profile_override',p_assignment_id,'success',p_reason,result-'capabilities');
  perform app_private.access_profile_store_receipt(p_request_id,actor,'overrides_save',payload,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_export_request(p_request_id uuid,p_filters jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();domain text:=coalesce(p_filters->>'domain','platform');job public.import_jobs%rowtype;
  request_hash bytea:=extensions.digest(convert_to(p_filters::text,'UTF8'),'sha256');required_permission text;
begin
  required_permission:=case domain when 'platform' then 'platform.roles.export' else 'institution.roles.export' end;
  if actor is null or domain not in('platform','institution') or not app_private.has_platform_permission(required_permission)
    or not app_private.has_mfa_aal2() then raise insufficient_privilege using message='profile export permission and MFA required';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into job from public.import_jobs where request_id=p_request_id for update;
  if job.id is not null then
    if job.created_by<>actor or job.request_hash<>request_hash or job.target_domain<>'access_profiles_export' then
      raise invalid_parameter_value using message='idempotency key reused';end if;
    return app_private.superadmin_access_profile_file_job(job.id);
  end if;
  insert into public.import_jobs(request_id,request_hash,target_domain,target_table,source_format,source_locale,target_locale,
    status,processing_state,summary,created_by)
  values(p_request_id,request_hash,'access_profiles_export','access_profiles','csv','pt-BR','pt-BR','draft','PENDENTE',
    jsonb_build_object('format_version','access-profiles-v1','phase','queued','filters',p_filters),actor) returning * into job;
  update public.import_jobs set summary=summary||jsonb_build_object('storage_bucket','coelo-operations','storage_path',
    'access-profile-files/'||actor||'/'||job.id||'/output/access-profiles-v1.csv') where id=job.id returning * into job;
  return jsonb_build_object('job_id',job.id,'status',job.processing_state,'version',job.version,
    'format_version','access-profiles-v1','bucket','coelo-operations','path',job.summary->>'storage_path');
end $$;

create or replace function app_private.superadmin_access_profile_import_create(
  p_request_id uuid,p_file_name text,p_file_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;payload jsonb;
  request_hash bytea;safe_name text:=btrim(p_file_name);
begin
  if actor is null or (not app_private.has_platform_permission('platform.roles.import')
    and not app_private.has_platform_permission('institution.roles.import')) or not app_private.has_mfa_aal2() then
    raise insufficient_privilege using message='profile import permission and MFA required';end if;
  if safe_name is null or char_length(safe_name)>128 or safe_name!~'^[^/\\]+[.]csv$'
    or p_file_sha256!~'^[0-9A-Fa-f]{64}$' then raise invalid_parameter_value using message='invalid CSV file metadata';end if;
  payload:=jsonb_build_object('file_name',safe_name,'sha256',lower(p_file_sha256),'format_version','access-profiles-v1');
  request_hash:=extensions.digest(convert_to(payload::text,'UTF8'),'sha256');
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  select * into job from public.import_jobs where request_id=p_request_id for update;
  if job.id is not null then
    if job.created_by<>actor or job.request_hash<>request_hash or job.target_domain<>'access_profiles_import' then
      raise invalid_parameter_value using message='idempotency key reused';end if;
    return app_private.superadmin_access_profile_file_job(job.id);
  end if;
  insert into public.import_jobs(request_id,request_hash,target_domain,target_table,source_format,source_locale,target_locale,
    status,processing_state,summary,created_by)
  values(p_request_id,request_hash,'access_profiles_import','access_profiles','csv','pt-BR','pt-BR','draft','PENDENTE',
    jsonb_build_object('format_version','access-profiles-v1','phase','awaiting_upload','source_name',safe_name),actor)
  returning * into job;
  update public.import_jobs set summary=summary||jsonb_build_object('storage_bucket','coelo-operations','storage_path',
    'access-profile-files/'||actor||'/'||job.id||'/input/access-profiles-v1.csv') where id=job.id returning * into job;
  insert into public.import_files(import_job_id,storage_path,file_name,mime_type,checksum_sha256,expires_at)
  values(job.id,job.summary->>'storage_path',safe_name,'text/csv',lower(p_file_sha256),now()+interval '24 hours');
  return jsonb_build_object('job_id',job.id,'status',job.processing_state,'version',job.version,
    'format_version','access-profiles-v1','bucket','coelo-operations','path',job.summary->>'storage_path');
end $$;

create or replace function app_private.superadmin_access_profile_import_stage(p_job_id uuid,p_rows jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;row_item jsonb;row_no int:=0;
  invalid_reason text;valid_count int:=0;error_count int:=0;code_item text;
begin
  if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>500 then raise invalid_parameter_value using message='invalid import rows';end if;
  select * into job from public.import_jobs where id=p_job_id for update;
  if job.id is null or job.target_domain<>'access_profiles_import' or job.created_by<>actor then
    raise insufficient_privilege using message='import job unavailable';end if;
  if not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required';end if;
  delete from public.import_errors where import_job_id=job.id;delete from public.import_rows where import_job_id=job.id;
  for row_item in select value from jsonb_array_elements(p_rows) loop
    row_no:=row_no+1;invalid_reason:=null;
    if row_item->>'domain' not in('platform','institution') then invalid_reason:='unsupported_domain';
    elsif nullif(btrim(row_item->>'name'),'') is null then invalid_reason:='name_required';
    elsif jsonb_typeof(coalesce(row_item->'capabilities','[]'))<>'array' then invalid_reason:='invalid_capabilities';
    else for code_item in select value->>'code' from jsonb_array_elements(coalesce(row_item->'capabilities','[]')) loop
      if (row_item->>'domain'='platform' and not exists(select 1 from public.platform_permissions where code=code_item and status='active'))
        or (row_item->>'domain'='institution' and not exists(select 1 from public.institution_permissions where code=code_item and status='active')) then
        invalid_reason:='unknown_capability';exit;end if;end loop;end if;
    insert into public.import_rows(import_job_id,row_number,payload_json,status,error_code)
    values(job.id,row_no,row_item,case when invalid_reason is null then 'active' else 'inactive' end,
      invalid_reason);
    if invalid_reason is null then valid_count:=valid_count+1;else error_count:=error_count+1;
      insert into public.import_errors(import_job_id,row_number,error_code,message)
      values(job.id,row_no,invalid_reason,'Linha inválida para access-profiles-v1.');end if;
  end loop;
  update public.import_jobs set version=version+1,updated_at=now(),summary=summary||jsonb_build_object(
    'phase','preview_ready','valid_count',valid_count,'error_count',error_count) where id=job.id returning * into job;
  return app_private.superadmin_access_profile_import_preview(job.id);
end $$;

create or replace function app_private.superadmin_access_profile_import_preview(p_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;
begin
  select * into job from public.import_jobs where id=p_job_id;
  if job.id is null or job.target_domain<>'access_profiles_import' or job.created_by<>actor then
    raise insufficient_privilege using message='import job unavailable';end if;
  return jsonb_build_object('job_id',job.id,'status',job.processing_state,'version',job.version,
    'format_version','access-profiles-v1','phase',job.summary->>'phase','summary',job.summary,
    'rows',coalesce((select jsonb_agg(jsonb_build_object('row_number',row_record.row_number,
      'payload',row_record.payload_json,'valid',row_record.error_code is null,'error_code',row_record.error_code)
      order by row_record.row_number) from public.import_rows row_record where row_record.import_job_id=job.id),'[]'),
    'errors',coalesce((select jsonb_agg(jsonb_build_object('row_number',error_record.row_number,
      'column',error_record.column_name,'code',error_record.error_code,'message',error_record.message)
      order by error_record.row_number,error_record.id) from public.import_errors error_record where error_record.import_job_id=job.id),'[]'));
end $$;

create or replace function app_private.superadmin_access_profile_import_confirm(
  p_request_id uuid,p_job_id uuid,p_expected_version bigint
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;row_record record;
  created_count int:=0;profile jsonb;result jsonb;payload jsonb:=jsonb_build_object('job_id',p_job_id,'version',p_expected_version);replay jsonb;
begin
  if actor is null or not app_private.has_mfa_aal2() then raise insufficient_privilege using message='MFA AAL2 required';end if;
  replay:=app_private.access_profile_replay(p_request_id,actor,'import_confirm',payload);if replay is not null then return replay;end if;
  select * into job from public.import_jobs where id=p_job_id for update;
  if job.id is null or job.target_domain<>'access_profiles_import' or job.created_by<>actor then raise insufficient_privilege using message='import job unavailable';end if;
  if job.version<>p_expected_version then raise serialization_failure using message='stale import version';end if;
  if exists(select 1 from public.import_errors where import_job_id=job.id) then raise check_violation using message='import validation errors must be resolved';end if;
  for row_record in select * from public.import_rows where import_job_id=job.id and error_code is null order by row_number loop
    perform app_private.access_profile_require_mutation(row_record.payload_json->>'domain');
    profile:=app_private.access_profile_create_internal(actor,row_record.payload_json);created_count:=created_count+1;
  end loop;
  insert into public.import_results(import_job_id,created_count,completed_at) values(job.id,created_count,now())
    on conflict(import_job_id) do update set created_count=excluded.created_count,completed_at=excluded.completed_at;
  update public.import_jobs set processing_state='SUCESSO',status='active',finished_at=now(),version=version+1,
    updated_at=now(),summary=summary||jsonb_build_object('phase','completed','created_count',created_count)
    where id=job.id returning * into job;
  result:=jsonb_build_object('job_id',job.id,'status',job.processing_state,'version',job.version,
    'created_count',created_count,'replayed',false);
  insert into audit.audit_logs(actor_person_id,mfa_aal,action_code,object_type,object_id,outcome,reason,after_json)
  values(actor,'aal2','permission_changed','access_profile_import',job.id,'success','Confirmação de importação access-profiles-v1.',result);
  perform app_private.access_profile_store_receipt(p_request_id,actor,'import_confirm',payload,result);return result;
end $$;

create or replace function app_private.superadmin_access_profile_export_materialize(p_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;csv text;domain text;
begin
  select * into job from public.import_jobs where id=p_job_id for update;
  if job.id is null or job.target_domain<>'access_profiles_export' or job.created_by<>actor then
    raise insufficient_privilege using message='export job unavailable';end if;
  domain:=job.summary#>>'{filters,domain}';
  if not app_private.has_platform_permission(case domain when 'platform' then 'platform.roles.export' else 'institution.roles.export' end)
    or not app_private.has_mfa_aal2() then raise insufficient_privilege using message='profile export permission and MFA required';end if;
  if domain='platform' then
    select 'format_version,domain,name,description,max_scope_kind,status,capabilities'||E'\n'||coalesce(string_agg(
      'access-profiles-v1,platform,"'||replace(role_record.name,'"','""')||'","'||replace(coalesce(role_record.description,''),'"','""')||'",'
      ||role_record.max_scope_kind||','||role_record.status||',"'||coalesce((select string_agg(permission_record.code||':'||grant_record.effect,'|' order by permission_record.code)
        from public.platform_role_permissions grant_record join public.platform_permissions permission_record on permission_record.id=grant_record.permission_id
        where grant_record.role_id=role_record.id and grant_record.status='active' and grant_record.revoked_at is null),'')||'"',E'\n' order by lower(role_record.name),role_record.id),'')
      into csv from public.platform_roles role_record where role_record.status='active';
  else
    select 'format_version,domain,name,description,max_scope_kind,status,capabilities'||E'\n'||coalesce(string_agg(
      'access-profiles-v1,institution,"'||replace(role_record.name,'"','""')||'","'||replace(coalesce(role_record.description,''),'"','""')||'",'
      ||role_record.max_scope_kind||','||role_record.status||',"'||coalesce((select string_agg(permission_record.code||':'||grant_record.effect,'|' order by permission_record.code)
        from public.institution_role_permissions grant_record join public.institution_permissions permission_record on permission_record.id=grant_record.permission_id
        where grant_record.role_id=role_record.id and grant_record.status='active' and grant_record.revoked_at is null),'')||'"',E'\n' order by lower(role_record.name),role_record.id),'')
      into csv from public.institution_roles role_record where role_record.status='active';
  end if;
  update public.import_jobs set processing_state='PROCESSANDO',started_at=coalesce(started_at,now()),version=version+1,
    summary=summary||jsonb_build_object('phase','materialized','row_count',greatest(array_length(string_to_array(csv,E'\n'),1)-1,0)),updated_at=now()
    where id=job.id returning * into job;
  return jsonb_build_object('job_id',job.id,'version',job.version,'path',job.summary->>'storage_path','csv',csv);
end $$;

create or replace function app_private.superadmin_access_profile_file_job(p_job_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=app_private.current_person_id();job public.import_jobs%rowtype;
begin
  select * into job from public.import_jobs where id=p_job_id;
  if job.id is null or job.target_domain not in('access_profiles_import','access_profiles_export') or job.created_by<>actor then
    raise no_data_found using message='file job not found';end if;
  return jsonb_build_object('job_id',job.id,'kind',job.target_domain,'status',job.processing_state,
    'version',job.version,'format_version','access-profiles-v1','phase',job.summary->>'phase',
    'bucket',job.summary->>'storage_bucket','path',job.summary->>'storage_path','summary',job.summary,
    'result',(select to_jsonb(result_record) from public.import_results result_record where result_record.import_job_id=job.id),
    'error_count',(select count(*) from public.import_errors where import_job_id=job.id));
end $$;

-- Eighteen immutable system models: six per application context.
insert into public.access_profile_templates(domain,code,name,description,max_scope_kind,is_system,status)
values
('platform','platform-owner','Owner','Condicao sistemica protegida do Owner; a duplicacao copia apenas grants explicitos.','platform',true,'active'),
('platform','platform-master','Master Superadmin','Todas as capabilities explicitas do contexto Superadmin, sem a condicao de Owner.','platform',true,'active'),
('platform','platform-authorized','Autorizado Superadmin','Conjunto explicito de operacao autorizada.','platform',true,'active'),
('platform','platform-operations',U&'Opera\00E7\00F5es','Operacao de instituicoes, unidades, turmas e atividades.','platform',true,'active'),
('platform','platform-support-communication',U&'Suporte e comunica\00E7\00E3o','Atendimento, avisos e comunicacao com leitura minimizada.','platform',true,'active'),
('platform','platform-auditor','Auditoria','Leitura e evidencias sem gestao.','platform',true,'active'),
('institution','institution-master','Master institucional','Todas as capabilities explicitas do contexto Admin.','institution',true,'active'),
('institution','institution-authorized','Autorizado Admin','Conjunto explicito de leitura administrativa.','institution',true,'active'),
('institution','institution-management',U&'Administra\00E7\00E3o institucional','Administracao da instituicao e de seus vinculos.','institution',true,'active'),
('institution','institution-secretariat','Secretaria','Pessoas, vinculos, turmas e presenca no escopo institucional.','institution',true,'active'),
('institution','institution-pedagogy',U&'Gest\00E3o pedag\00F3gica','Turmas, atividades e presenca.','group',true,'active'),
('institution','institution-professional','Profissional','Operacao pedagogica e comunicacao no escopo atribuido.','group',true,'active'),
('principal','principal-master','Master Principal','Acesso explícito completo do responsável no contexto da criança.','child_context',true,'active'),
('principal','principal-authorized','Autorizado Principal','Visualização e mensagem explicitamente autorizadas.','child_context',true,'active'),
('principal','principal-communication','Comunicação Principal','Mensagens e reações.','child_context',true,'active'),
('principal','principal-attendance','Presença Principal','Visualização e avisos de presença.','child_context',true,'active'),
('principal','principal-authorized-people','Pessoas autorizadas Principal','Gestão de pessoas autorizadas.','child_context',true,'active'),
('principal','principal-read-only','Somente leitura Principal','Visualização sem ações de gestão.','child_context',true,'active')
on conflict(domain,code) do update set name=excluded.name,description=excluded.description,
  max_scope_kind=excluded.max_scope_kind,is_system=true,status='active',updated_at=now();

with definitions(code,codes) as(values
('platform-owner',null::text[]),
('platform-master',null::text[]),
('platform-authorized',array['platform.read','institution.update','units.read','groups.read','people.read','activities.read','support.manage']::text[]),
('platform-operations',array['platform.read','institution.activate','institution.update','institution.status.change','units.read','units.create','units.update','groups.read','groups.manage','activities.read','activities.create','activities.manage','activities.link_groups','activities.link_units','imports.read','imports.manage']::text[]),
('platform-support-communication',array['platform.read','support.manage','people.read','units.read','groups.read','activities.read','notice.publish','activities.create','activities.manage','activities.templates.manage']::text[]),
('platform-auditor',array['platform.read','audit.read','analytics.read','imports.read','activities.read','units.read','groups.read','people.read']::text[]))
insert into public.access_profile_template_platform_permissions(template_id,permission_id,effect)
select template.id,permission_record.id,'allow' from definitions
join public.access_profile_templates template on template.domain='platform' and template.code=definitions.code
join public.platform_permissions permission_record on permission_record.status='active'
  and (definitions.codes is null or permission_record.code=any(definitions.codes))
on conflict(template_id,permission_id) do update set effect='allow';

with definitions(code,codes) as(values
('institution-master',null::text[]),
('institution-authorized',array['family.read','people.read','activities.read','attendance.read','chat.read','groups.read']::text[]),
('institution-management',array['permissions.manage','family.read','family.manage','authorized_people.manage','people.read','people.manage','transfers.manage','groups.read','groups.manage','groups.access.manage','activities.read','activities.create','activities.manage','activities.assign_people','activities.link_groups','activities.link_units','activities.manage_permissions','attendance.read','attendance.manage','chat.read','chat.manage']::text[]),
('institution-secretariat',array['family.read','family.manage','authorized_people.manage','people.read','people.manage','transfers.manage','groups.read','groups.manage','attendance.read','attendance.manage']::text[]),
('institution-pedagogy',array['people.read','groups.read','groups.manage','activities.read','activities.create','activities.manage','activities.assign_people','attendance.read','attendance.manage']::text[]),
('institution-professional',array['people.read','groups.read','activities.read','activities.create','activities.assign_people','attendance.read','attendance.manage','chat.read']::text[]))
insert into public.access_profile_template_institution_permissions(template_id,permission_id,effect)
select template.id,permission_record.id,'allow' from definitions
join public.access_profile_templates template on template.domain='institution' and template.code=definitions.code
join public.institution_permissions permission_record on permission_record.status='active'
  and (definitions.codes is null or permission_record.code=any(definitions.codes))
on conflict(template_id,permission_id) do update set effect='allow';

with definitions(code,codes) as(values
('principal-master',null::text[]),
('principal-authorized',array['view_context','message']::text[]),
('principal-communication',array['view_context','message','react']::text[]),
('principal-attendance',array['view_context','manage_attendance_notices']::text[]),
('principal-authorized-people',array['view_context','manage_authorized_people']::text[]),
('principal-read-only',array['view_context']::text[]))
insert into public.access_profile_template_principal_capabilities(template_id,capability_id,effect)
select template.id,capability.id,'allow' from definitions
join public.access_profile_templates template on template.domain='principal' and template.code=definitions.code
join public.guardian_permission_capabilities capability on capability.status='active'
  and (definitions.codes is null or capability.code=any(definitions.codes))
on conflict(template_id,capability_id) do update set effect='allow';

create or replace function app_private.bump_access_profile_catalog_version()
returns trigger language plpgsql security definer set search_path='' as $$
declare target_domain text:=tg_argv[0];
begin
  update app_private.access_profile_catalog_versions set version=version+1,updated_at=now() where domain=target_domain;
  return coalesce(new,old);
end $$;
create trigger platform_permissions_catalog_version after insert or update or delete on public.platform_permissions
for each statement execute function app_private.bump_access_profile_catalog_version('platform');
create trigger institution_permissions_catalog_version after insert or update or delete on public.institution_permissions
for each statement execute function app_private.bump_access_profile_catalog_version('institution');
create trigger principal_capabilities_catalog_version after insert or update or delete on public.guardian_permission_capabilities
for each statement execute function app_private.bump_access_profile_catalog_version('principal');

-- Public Data API wrappers remain invoker functions; privileged code stays in
-- the unexposed app_private schema with explicit authenticated EXECUTE only.
create or replace function public.superadmin_access_profiles_cursor(text,text,text,text,integer,text,uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profiles_cursor($1,$2,$3,$4,$5,$6,$7)$$;
create or replace function public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_models_cursor($1,$2,$3,$4,$5,$6,$7)$$;
create or replace function public.superadmin_access_profile_capability_catalog(text,uuid,uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_capability_catalog($1,$2,$3)$$;
create or replace function public.superadmin_access_profile_create(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_create($1,$2)$$;
create or replace function public.superadmin_access_profile_update(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_update($1,$2)$$;
create or replace function public.superadmin_access_profile_duplicate(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_duplicate($1,$2)$$;
create or replace function public.superadmin_access_profile_create_from_model(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_create_from_model($1,$2)$$;
create or replace function public.superadmin_access_profile_assignment_candidates(uuid,text,integer,text,uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_assignment_candidates($1,$2,$3,$4,$5)$$;
create or replace function public.superadmin_access_profile_assignments_cursor(uuid,integer,text,uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_assignments_cursor($1,$2,$3,$4)$$;
create or replace function public.superadmin_access_profile_assignment_link(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_assignment_link($1,$2)$$;
create or replace function public.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_assignment_unlink($1,$2,$3,$4)$$;
create or replace function public.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_assignment_overrides_save($1,$2,$3,$4,$5)$$;
create or replace function public.superadmin_access_profile_export_request(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_export_request($1,$2)$$;
create or replace function public.superadmin_access_profile_import_create(uuid,text,text)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_import_create($1,$2,$3)$$;
create or replace function public.superadmin_access_profile_import_stage(uuid,jsonb)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_import_stage($1,$2)$$;
create or replace function public.superadmin_access_profile_import_preview(uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_import_preview($1)$$;
create or replace function public.superadmin_access_profile_import_confirm(uuid,uuid,bigint)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_import_confirm($1,$2,$3)$$;
create or replace function public.superadmin_access_profile_export_materialize(uuid)
returns jsonb language sql volatile security invoker set search_path='' as $$select app_private.superadmin_access_profile_export_materialize($1)$$;
create or replace function public.superadmin_access_profile_file_job(uuid)
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_file_job($1)$$;

-- Compatibility gateways now use the same guarded v2 implementations.
create or replace function public.superadmin_access_profiles_list(
  p_domain text,
  p_search text,
  p_status text,
  p_scope text,
  p_page integer,
  p_page_size integer
)
returns jsonb language sql stable security invoker set search_path=''
as $$select app_private.superadmin_access_profiles_cursor(p_search,p_domain,p_status,p_scope,p_page_size,null,null)$$;
create or replace function public.superadmin_access_profile_detail(
  p_domain text,
  p_profile_id uuid
)
returns jsonb language sql stable security invoker set search_path=''
as $$select app_private.access_profile_detail_v2(p_domain,p_profile_id)$$;
create or replace function public.superadmin_access_profile_save(
  p_request_id uuid,
  p_expected_version bigint,
  p_reason text,
  p_draft jsonb
)
returns jsonb language sql volatile security invoker set search_path=''
as $$select case when nullif(p_draft->>'id','') is null
  then app_private.superadmin_access_profile_create(p_request_id,p_draft||jsonb_build_object('reason',p_reason))
  else app_private.superadmin_access_profile_update(p_request_id,p_draft||jsonb_build_object('reason',p_reason,'expected_version',p_expected_version)) end$$;
create or replace function public.superadmin_principal_capabilities_summary()
returns jsonb language sql stable security invoker set search_path='' as $$select app_private.superadmin_access_profile_capability_catalog('principal',null,null)$$;

do $$
declare routine regprocedure;
begin
  foreach routine in array array[
    'app_private.superadmin_access_profiles_cursor(text,text,text,text,integer,text,uuid)'::regprocedure,
    'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'::regprocedure,
    'app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::regprocedure,
    'app_private.superadmin_access_profile_create(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_update(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_duplicate(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_create_from_model(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_assignment_candidates(uuid,text,integer,text,uuid)'::regprocedure,
    'app_private.superadmin_access_profile_assignments_cursor(uuid,integer,text,uuid)'::regprocedure,
    'app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text)'::regprocedure,
    'app_private.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text)'::regprocedure,
    'app_private.superadmin_access_profile_export_request(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_import_create(uuid,text,text)'::regprocedure,
    'app_private.superadmin_access_profile_import_stage(uuid,jsonb)'::regprocedure,
    'app_private.superadmin_access_profile_import_preview(uuid)'::regprocedure,
    'app_private.superadmin_access_profile_import_confirm(uuid,uuid,bigint)'::regprocedure,
    'app_private.superadmin_access_profile_export_materialize(uuid)'::regprocedure,
    'app_private.superadmin_access_profile_file_job(uuid)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public,anon,authenticated',routine);
  end loop;
end $$;
revoke all on function public.superadmin_access_profiles_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_capability_catalog(text,uuid,uuid),
  public.superadmin_access_profile_create(uuid,jsonb),public.superadmin_access_profile_update(uuid,jsonb),
  public.superadmin_access_profile_duplicate(uuid,jsonb),public.superadmin_access_profile_create_from_model(uuid,jsonb),
  public.superadmin_access_profile_assignment_candidates(uuid,text,integer,text,uuid),
  public.superadmin_access_profile_assignments_cursor(uuid,integer,text,uuid),
  public.superadmin_access_profile_assignment_link(uuid,jsonb),
  public.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text),
  public.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text),
  public.superadmin_access_profile_export_request(uuid,jsonb),public.superadmin_access_profile_import_create(uuid,text,text),
  public.superadmin_access_profile_import_stage(uuid,jsonb),public.superadmin_access_profile_import_preview(uuid),
  public.superadmin_access_profile_import_confirm(uuid,uuid,bigint),
  public.superadmin_access_profile_export_materialize(uuid),public.superadmin_access_profile_file_job(uuid)
  from public,anon;
grant execute on function public.superadmin_access_profiles_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_capability_catalog(text,uuid,uuid),
  public.superadmin_access_profile_create(uuid,jsonb),public.superadmin_access_profile_update(uuid,jsonb),
  public.superadmin_access_profile_duplicate(uuid,jsonb),public.superadmin_access_profile_create_from_model(uuid,jsonb),
  public.superadmin_access_profile_assignment_candidates(uuid,text,integer,text,uuid),
  public.superadmin_access_profile_assignments_cursor(uuid,integer,text,uuid),
  public.superadmin_access_profile_assignment_link(uuid,jsonb),
  public.superadmin_access_profile_assignment_unlink(uuid,uuid,bigint,text),
  public.superadmin_access_profile_assignment_overrides_save(uuid,uuid,bigint,jsonb,text),
  public.superadmin_access_profile_export_request(uuid,jsonb),
  public.superadmin_access_profile_import_create(uuid,text,text),
  public.superadmin_access_profile_import_stage(uuid,jsonb),public.superadmin_access_profile_import_preview(uuid),
  public.superadmin_access_profile_import_confirm(uuid,uuid,bigint),
  public.superadmin_access_profile_export_materialize(uuid),public.superadmin_access_profile_file_job(uuid),
  public.superadmin_access_profiles_list(text,text,text,text,integer,integer),
  public.superadmin_access_profile_detail(text,uuid),public.superadmin_access_profile_save(uuid,bigint,text,jsonb),
  public.superadmin_principal_capabilities_summary() to authenticated;

revoke all on function app_private.access_profile_require_mutation(text),
  app_private.access_profile_replay(uuid,uuid,text,jsonb),
  app_private.access_profile_store_receipt(uuid,uuid,text,jsonb,jsonb),
  app_private.access_profile_detail_v2(text,uuid),
  app_private.access_profile_create_internal(uuid,jsonb,uuid,bigint),
  app_private.bump_access_profile_catalog_version(),
  app_private.normalize_institution_permission_override_scope() from public,anon,authenticated;

