-- Additive closure for Access Profile Models and the app -> module -> screen ->
-- action catalog. Profiles remain domain-specific snapshots: this migration
-- does not infer memberships or widen an assignment's concrete scope.

begin;

do $preflight$
declare postgres_role oid:=(select oid from pg_catalog.pg_roles where rolname='postgres');
begin
  if current_user<>'postgres' then
    raise exception using errcode='42501',
      message='access profile models migration must run as postgres';
  end if;
  if pg_catalog.to_regprocedure(
      'app_private.require_superadmin_internal_context(text)') is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_superadmin_internal_denial_if_identified(text,text,text,uuid,uuid)') is null
    or pg_catalog.to_regprocedure(
      'app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid)') is null
    or pg_catalog.to_regclass(
      'app_private.superadmin_internal_identities') is null then
    raise exception using errcode='55000',
      message='superadmin internal auth foundation is required';
  end if;
  if pg_catalog.to_regclass('public.access_profile_templates') is null
    or pg_catalog.to_regclass(
      'public.access_profile_template_platform_permissions') is null
    or pg_catalog.to_regclass(
      'public.access_profile_template_institution_permissions') is null
    or pg_catalog.to_regclass(
      'public.access_profile_template_principal_capabilities') is null then
    raise exception using errcode='55000',
      message='access profile capability core is required';
  end if;
  if pg_catalog.to_regclass(
      'app_private.access_profile_model_command_receipts') is not null then
    raise exception using errcode='55000',
      message='access profile model internal-v2 package already exists';
  end if;
  if not exists(
    select 1 from pg_catalog.pg_default_acl default_acl
    where default_acl.defaclrole=postgres_role
      and default_acl.defaclobjtype='f'
      and default_acl.defaclnamespace=0
      and not exists(
        select 1 from pg_catalog.aclexplode(default_acl.defaclacl) grant_item
        where grant_item.privilege_type='EXECUTE'
          and grant_item.grantee<>postgres_role)) then
    raise exception using errcode='55000',
      message='default function execute privilege hardening is required';
  end if;
end
$preflight$;

alter table public.platform_permissions
  add column if not exists application_code text not null default 'superadmin';
alter table public.institution_permissions
  add column if not exists application_code text not null default 'admin';
alter table public.guardian_permission_capabilities
  add column if not exists application_code text not null default 'principal';

alter table public.access_profile_templates
  add column if not exists created_by_internal_identity_id uuid
    references app_private.superadmin_internal_identities(id) on delete restrict;
create index if not exists access_profile_templates_created_by_internal_idx
  on public.access_profile_templates(created_by_internal_identity_id)
  where created_by_internal_identity_id is not null;

create table app_private.access_profile_model_command_receipts(
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  command_kind text not null check(command_kind in(
    'model_create','model_update','model_delete','model_duplicate','model_import_confirm')),
  request_hash bytea not null check(octet_length(request_hash)=32),
  result_json jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default(now()+interval '30 days')
);
create index access_profile_model_command_receipts_actor_idx
  on app_private.access_profile_model_command_receipts(
    actor_internal_identity_id,created_at desc);
create index access_profile_model_command_receipts_expiry_idx
  on app_private.access_profile_model_command_receipts(expires_at);
alter table app_private.access_profile_model_command_receipts enable row level security;
alter table app_private.access_profile_model_command_receipts force row level security;
revoke all on app_private.access_profile_model_command_receipts
  from public,anon,authenticated,service_role;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.platform_permissions'::regclass
      and conname = 'platform_permissions_application_code_check'
  ) then
    alter table public.platform_permissions
      add constraint platform_permissions_application_code_check
      check (application_code = 'superadmin');
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.institution_permissions'::regclass
      and conname = 'institution_permissions_application_code_check'
  ) then
    alter table public.institution_permissions
      add constraint institution_permissions_application_code_check
      check (application_code = 'admin');
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.guardian_permission_capabilities'::regclass
      and conname = 'guardian_capabilities_application_code_check'
  ) then
    alter table public.guardian_permission_capabilities
      add constraint guardian_capabilities_application_code_check
      check (application_code = 'principal');
  end if;
end $$;

insert into public.platform_permissions(
  code,module_code,screen_code,action_code,description,risk_level,requires_mfa,
  status,module_label,screen_label,action_label,application_code
)
select definition.code,'access','access_profile_models',definition.action_code,
  definition.description,definition.risk_level,definition.requires_mfa,'active',
  'Acessos','Modelos de perfil',definition.action_label,'superadmin'
from (values
  ('platform.role_models.read','read','Consultar modelos Superadmin.','normal',false,'Visualizar'),
  ('platform.role_models.create','create','Criar modelos Superadmin.','high',true,'Criar'),
  ('platform.role_models.update','update','Editar modelos Superadmin.','high',true,'Editar'),
  ('platform.role_models.delete','delete','Inativar modelos Superadmin.','critical',true,'Excluir'),
  ('platform.role_models.import','import','Importar modelos Superadmin.','critical',true,'Importar'),
  ('platform.role_models.export','export','Exportar modelos Superadmin.','high',true,'Exportar'),
  ('institution.role_models.read','read','Consultar modelos Admin.','normal',false,'Visualizar'),
  ('institution.role_models.create','create','Criar modelos Admin.','high',true,'Criar'),
  ('institution.role_models.update','update','Editar modelos Admin.','high',true,'Editar'),
  ('institution.role_models.delete','delete','Inativar modelos Admin.','critical',true,'Excluir'),
  ('institution.role_models.import','import','Importar modelos Admin.','critical',true,'Importar'),
  ('institution.role_models.export','export','Exportar modelos Admin.','high',true,'Exportar'),
  ('principal.role_models.read','read','Consultar modelos Principal.','high',false,'Visualizar'),
  ('principal.role_models.create','create','Criar modelos Principal.','critical',true,'Criar'),
  ('principal.role_models.update','update','Editar modelos Principal.','critical',true,'Editar'),
  ('principal.role_models.delete','delete','Inativar modelos Principal.','critical',true,'Excluir'),
  ('principal.role_models.import','import','Importar modelos Principal.','critical',true,'Importar'),
  ('principal.role_models.export','export','Exportar modelos Principal.','high',true,'Exportar')
) as definition(code,action_code,description,risk_level,requires_mfa,action_label)
on conflict(code) do update set
  module_code=excluded.module_code,
  screen_code=excluded.screen_code,
  action_code=excluded.action_code,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active',
  module_label=excluded.module_label,
  screen_label=excluded.screen_label,
  action_label=excluded.action_label,
  application_code=excluded.application_code,
  updated_at=now();

insert into public.platform_role_permissions(
  role_id,permission_id,effect,conditions_json,status
)
select role_record.id,permission_record.id,'allow','{}'::jsonb,'active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on (permission_record.code like 'platform.role_models.%'
    or permission_record.code like 'institution.role_models.%'
    or permission_record.code like 'principal.role_models.%')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

create or replace function app_private.access_profile_require_model_action(
  p_domain text,
  p_action text,
  p_require_mfa boolean default true
) returns uuid
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  context_record app_private.superadmin_internal_context;
  permission_code text;
begin
  if p_domain not in ('platform','institution','principal')
    or p_action not in ('read','create','update','delete','import','export') then
    raise invalid_parameter_value using message='unsupported access model action';
  end if;
  permission_code:=p_domain||'.role_models.'||p_action;
  select * into strict context_record
  from app_private.require_superadmin_internal_context(permission_code);
  if context_record.scope_kind<>'platform'
    or context_record.platform_role_code<>'owner' then
    raise insufficient_privilege using
      message='access model permission required',detail='SAI_PERMISSION_DENIED';
  end if;
  if p_require_mfa and context_record.aal<>'aal2' then
    raise insufficient_privilege using
      message='MFA AAL2 required',detail='SAI_MFA_REQUIRED';
  end if;
  return context_record.internal_identity_id;
end
$$;

create function app_private.access_profile_model_replay_internal(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare receipt app_private.access_profile_model_command_receipts%rowtype;
  wanted_hash bytea;
begin
  if p_request_id is null then
    raise invalid_parameter_value using message='request id required';
  end if;
  wanted_hash:=extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.access-profile-model:'||p_request_id::text,0));
  select * into receipt from app_private.access_profile_model_command_receipts
    where request_id=p_request_id for update;
  if receipt.request_id is null then return null; end if;
  if receipt.actor_internal_identity_id is distinct from p_actor then
    raise insufficient_privilege using
      message='idempotency receipt actor mismatch',detail='SAI_PERMISSION_DENIED';
  end if;
  if receipt.command_kind<>p_command or receipt.request_hash<>wanted_hash then
    raise invalid_parameter_value using message='idempotency key reused';
  end if;
  return receipt.result_json||pg_catalog.jsonb_build_object('replayed',true);
end
$$;

create function app_private.access_profile_model_store_receipt_internal(
  p_request_id uuid,p_actor uuid,p_command text,p_payload jsonb,p_result jsonb
) returns void language sql volatile security definer set search_path='' as $$
  insert into app_private.access_profile_model_command_receipts(
    request_id,actor_internal_identity_id,command_kind,request_hash,result_json
  ) values(p_request_id,p_actor,p_command,
    extensions.digest(pg_catalog.convert_to(p_payload::text,'UTF8'),'sha256'),p_result)
$$;

create function app_private.access_profile_model_internal_can_delegate(
  p_actor uuid,p_domain text,p_capability_code text
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from app_private.superadmin_internal_memberships membership_record
    join public.platform_roles role_record
      on role_record.id=membership_record.platform_role_id
     and role_record.status='active'
    where membership_record.internal_identity_id=p_actor
      and membership_record.status='active'
      and membership_record.scope_kind='platform'
      and role_record.code='owner'
      and (
        p_domain in('institution','principal')
        or exists(
          select 1 from public.platform_role_permissions role_permission
          join public.platform_permissions permission_record
            on permission_record.id=role_permission.permission_id
           and permission_record.status='active'
          where role_permission.role_id=role_record.id
            and permission_record.code=p_capability_code
            and role_permission.effect='allow'
            and role_permission.status='active'
            and role_permission.revoked_at is null)))
$$;

create function app_private.access_profile_model_audit_success(
  p_actor uuid,p_domain text,p_action text,p_object_id uuid default null
) returns void language plpgsql volatile security definer set search_path='' as $$
declare context_record app_private.superadmin_internal_context;
  permission_code text:=p_domain||'.role_models.'||p_action;
begin
  select * into strict context_record
    from app_private.require_superadmin_internal_context(permission_code);
  if context_record.internal_identity_id is distinct from p_actor then
    raise insufficient_privilege using
      message='internal model actor changed',detail='SAI_PERMISSION_DENIED';
  end if;
  perform app_private.audit_append_superadmin_internal(
    context_record.internal_identity_id,context_record.internal_auth_link_id,
    context_record.internal_membership_id,context_record.session_id,
    permission_code,context_record.aal,
    'superadmin.access-profile-models.'||p_action,'success',
    'MODEL_'||upper(p_action),gen_random_uuid(),null,
    'access_profile_model',p_object_id);
end
$$;

create or replace function app_private.access_profile_model_detail(
  p_model_id uuid,
  p_authorize boolean default true
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  capabilities jsonb;
begin
  select * into model_record
  from public.access_profile_templates model
  where model.id=p_model_id;
  if model_record.id is null then
    raise no_data_found using message='access profile model not found';
  end if;
  if p_authorize then
    perform app_private.access_profile_require_model_action(model_record.domain,'read',false);
  end if;
  if model_record.domain='platform' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_platform_permissions model_permission
    join public.platform_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  elsif model_record.domain='institution' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',permission_record.code,'effect',model_permission.effect::text
    ) order by permission_record.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_institution_permissions model_permission
    join public.institution_permissions permission_record
      on permission_record.id=model_permission.permission_id
    where model_permission.template_id=model_record.id;
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'code',capability.code,'effect',model_capability.effect::text
    ) order by capability.code),'[]'::jsonb)
    into capabilities
    from public.access_profile_template_principal_capabilities model_capability
    join public.guardian_permission_capabilities capability
      on capability.id=model_capability.capability_id
    where model_capability.template_id=model_record.id;
  end if;
  return to_jsonb(model_record)||jsonb_build_object(
    'application_code',case model_record.domain
      when 'platform' then 'superadmin'
      when 'institution' then 'admin'
      else 'principal' end,
    'capabilities',capabilities,
    'capability_count',jsonb_array_length(capabilities)
  );
end
$$;

create or replace function app_private.superadmin_access_profile_models_cursor(
  p_query text default null,
  p_domain text default null,
  p_status text default null,
  p_scope text default null,
  p_limit integer default 25,
  p_after_name text default null,
  p_after_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  size_no integer:=least(greatest(coalesce(p_limit,25),1),100);
  result jsonb;
begin
  perform app_private.access_profile_require_model_action(p_domain,'read',false);
  if p_domain not in('platform','institution','principal')
    or char_length(coalesce(p_query,''))>120
    or (p_status is not null and p_status not in('active','inactive'))
    or (p_after_name is null)<>(p_after_id is null) then
    raise invalid_parameter_value using message='invalid access model query';
  end if;
  with rows as (
    select model.id,model.domain,model.code,model.name,model.description,
      model.status::text,model.max_scope_kind,model.version,model.is_system,
      case model.domain
        when 'platform' then (select count(*) from public.access_profile_template_platform_permissions item where item.template_id=model.id)
        when 'institution' then (select count(*) from public.access_profile_template_institution_permissions item where item.template_id=model.id)
        else (select count(*) from public.access_profile_template_principal_capabilities item where item.template_id=model.id)
      end::integer capability_count
    from public.access_profile_templates model
    where model.domain=p_domain
      and (nullif(btrim(p_query),'') is null or model.name ilike '%'||btrim(p_query)||'%')
      and (p_status is null or model.status::text=p_status)
      and (p_scope is null or model.max_scope_kind=p_scope)
      and (p_after_name is null or (lower(model.name),model.id)>(lower(p_after_name),p_after_id))
  ), page as (
    select * from rows order by lower(name),id limit size_no+1
  )
  select jsonb_build_object(
    'items',coalesce(jsonb_agg(to_jsonb(page) order by lower(name),id)
      filter(where row_number<=size_no),'[]'::jsonb),
    'next_cursor',case when count(*)>size_no then
      (select jsonb_build_object('name',name,'id',id)
        from page order by lower(name),id offset size_no-1 limit 1) end
  ) into result
  from (select page.*,row_number() over(order by lower(name),id) row_number from page) page;
  return result;
end
$$;

create or replace function app_private.access_profile_model_create_internal(
  p_actor uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_id uuid;
  domain text:=p_draft->>'domain';
  generated_code text;
  base_code text;
  capability_item jsonb;
  capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
  scope_kind text:=p_draft->>'max_scope_kind';
begin
  if domain not in ('platform','institution','principal')
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536
    or char_length(btrim(coalesce(p_draft->>'name',''))) not between 2 and 120
    or coalesce(nullif(p_draft->>'status',''),'active') not in ('active','inactive')
    or jsonb_typeof(capabilities)<>'array'
    or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid access model draft';
  end if;
  scope_kind:=coalesce(nullif(scope_kind,''),case domain
    when 'platform' then 'platform'
    when 'institution' then 'institution'
    else 'child_context' end);
  if (domain='platform' and scope_kind not in ('platform','institution'))
    or (domain='institution' and scope_kind not in ('institution','unit','group'))
    or (domain='principal' and scope_kind<>'child_context') then
    raise invalid_parameter_value using message='invalid access model scope';
  end if;
  if jsonb_array_length(capabilities)<>(
    select count(distinct item.value->>'code')
    from jsonb_array_elements(capabilities) item
  ) then
    raise invalid_parameter_value using message='duplicate access model capability';
  end if;
  for capability_item in select value from jsonb_array_elements(capabilities) loop
    if capability_item->>'effect' not in ('allow','deny') then
      raise invalid_parameter_value using message='invalid access model capability effect';
    end if;
    if domain='platform' and not exists(
      select 1 from public.platform_permissions permission_record
      where permission_record.code=capability_item->>'code' and permission_record.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    elsif domain='institution' and not exists(
      select 1 from public.institution_permissions permission_record
      where permission_record.code=capability_item->>'code' and permission_record.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    elsif domain='principal' and not exists(
      select 1 from public.guardian_permission_capabilities capability
      where capability.code=capability_item->>'code' and capability.status='active'
    ) then
      raise invalid_parameter_value using message='unknown access model capability';
    end if;
    if capability_item->>'effect'='allow'
      and not app_private.access_profile_model_internal_can_delegate(
        p_actor,domain,capability_item->>'code') then
      raise insufficient_privilege using message='cannot delegate capability operator does not hold';
    end if;
  end loop;
  base_code:=trim(both '-' from regexp_replace(
    lower(btrim(p_draft->>'name')),'[^a-z0-9]+','-','g'
  ));
  if char_length(base_code)<3 then base_code:='model'; end if;
  generated_code:=base_code||'-'||left(replace(gen_random_uuid()::text,'-',''),8);
  insert into public.access_profile_templates(
    domain,code,name,description,max_scope_kind,is_system,status,
    created_by_internal_identity_id
  ) values(
    domain,generated_code,btrim(p_draft->>'name'),
    nullif(btrim(p_draft->>'description'),''),scope_kind,false,
    coalesce(nullif(p_draft->>'status',''),'active')::public.record_status,p_actor
  ) returning id into model_id;
  if domain='platform' then
    insert into public.access_profile_template_platform_permissions(
      template_id,permission_id,effect
    )
    select model_id,permission_record.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions permission_record
      on permission_record.code=item.value->>'code';
  elsif domain='institution' then
    insert into public.access_profile_template_institution_permissions(
      template_id,permission_id,effect
    )
    select model_id,permission_record.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions permission_record
      on permission_record.code=item.value->>'code';
  else
    insert into public.access_profile_template_principal_capabilities(
      template_id,capability_id,effect
    )
    select model_id,capability.id,
      (item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.guardian_permission_capabilities capability
      on capability.code=item.value->>'code';
  end if;
  return app_private.access_profile_model_detail(model_id,false);
end
$$;

create or replace function app_private.superadmin_access_profile_model_create(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  replay jsonb;
  model jsonb;
  result jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_draft->>'domain','create');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_create',p_draft);
  if replay is not null then return replay; end if;
  model:=app_private.access_profile_model_create_internal(actor,p_draft);
  result:=jsonb_build_object('model',model,'model_id',model->>'id',
    'version',(model->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,p_draft->>'domain','create',(model->>'id')::uuid);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_create',p_draft,result
  );
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_update(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
  capability_item jsonb;
  capabilities jsonb:=coalesce(p_draft->'capabilities','[]'::jsonb);
  expected_version bigint:=nullif(p_draft->>'expected_version','')::bigint;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=nullif(p_draft->>'id','')::uuid for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'update');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536 then
    raise invalid_parameter_value using message='invalid access model update';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_update',p_draft);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from expected_version then
    raise serialization_failure using message='stale access model version';
  end if;
  if char_length(btrim(coalesce(p_draft->>'name',''))) not between 2 and 120
    or coalesce(nullif(p_draft->>'status',''),model_record.status::text) not in ('active','inactive')
    or jsonb_typeof(capabilities)<>'array' or jsonb_array_length(capabilities)>500 then
    raise invalid_parameter_value using message='invalid access model draft';
  end if;
  if jsonb_array_length(capabilities)<>(
    select count(distinct item.value->>'code')
    from jsonb_array_elements(capabilities) item
  ) then
    raise invalid_parameter_value using message='duplicate access model capability';
  end if;
  -- Reuse create validation inside the domain-specific loops without creating a row.
  for capability_item in select value from jsonb_array_elements(capabilities) loop
    if capability_item->>'effect' not in ('allow','deny')
      or (model_record.domain='platform' and not exists(select 1 from public.platform_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='institution' and not exists(select 1 from public.institution_permissions p where p.code=capability_item->>'code' and p.status='active'))
      or (model_record.domain='principal' and not exists(select 1 from public.guardian_permission_capabilities p where p.code=capability_item->>'code' and p.status='active')) then
      raise invalid_parameter_value using message='unknown or invalid access model capability';
    end if;
    if capability_item->>'effect'='allow'
      and not app_private.access_profile_model_internal_can_delegate(
        actor,model_record.domain,capability_item->>'code') then
      raise insufficient_privilege using message='cannot delegate capability operator does not hold';
    end if;
  end loop;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set
    name=btrim(p_draft->>'name'),
    description=nullif(btrim(p_draft->>'description'),''),
    max_scope_kind=coalesce(nullif(p_draft->>'max_scope_kind',''),max_scope_kind),
    status=coalesce(nullif(p_draft->>'status',''),status::text)::public.record_status,
    version=version+1,
    updated_at=now()
  where id=model_record.id;
  delete from public.access_profile_template_platform_permissions where template_id=model_record.id;
  delete from public.access_profile_template_institution_permissions where template_id=model_record.id;
  delete from public.access_profile_template_principal_capabilities where template_id=model_record.id;
  if model_record.domain='platform' then
    insert into public.access_profile_template_platform_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.platform_permissions p on p.code=item.value->>'code';
  elsif model_record.domain='institution' then
    insert into public.access_profile_template_institution_permissions(template_id,permission_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.institution_permissions p on p.code=item.value->>'code';
  else
    insert into public.access_profile_template_principal_capabilities(template_id,capability_id,effect)
    select model_record.id,p.id,(item.value->>'effect')::public.permission_effect
    from jsonb_array_elements(capabilities) item
    join public.guardian_permission_capabilities p on p.code=item.value->>'code';
  end if;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model',after_data,'model_id',model_record.id,
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'update',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_update',p_draft,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_delete(
  p_request_id uuid,
  p_model_id uuid,
  p_expected_version bigint,
  p_reason text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  model_record public.access_profile_templates%rowtype;
  actor uuid;
  payload jsonb:=jsonb_build_object('model_id',p_model_id,'expected_version',p_expected_version,'reason',p_reason);
  replay jsonb;
  before_data jsonb;
  after_data jsonb;
  result jsonb;
begin
  select * into model_record from public.access_profile_templates model
  where model.id=p_model_id for update;
  if model_record.id is null then raise no_data_found using message='access profile model not found'; end if;
  actor:=app_private.access_profile_require_model_action(model_record.domain,'delete');
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_delete',payload);
  if replay is not null then return replay; end if;
  if model_record.is_system then raise insufficient_privilege using message='system access model is protected'; end if;
  if model_record.version is distinct from p_expected_version then
    raise serialization_failure using message='stale access model version';
  end if;
  if nullif(btrim(p_reason),'') is null or char_length(p_reason)>500 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  before_data:=app_private.access_profile_model_detail(model_record.id,false);
  update public.access_profile_templates set status='inactive',version=version+1,updated_at=now()
  where id=model_record.id;
  after_data:=app_private.access_profile_model_detail(model_record.id,false);
  result:=jsonb_build_object('model_id',model_record.id,'status','inactive',
    'version',(after_data->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,model_record.domain,'delete',model_record.id);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_delete',payload,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_model_duplicate(
  p_request_id uuid,
  p_draft jsonb
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  source jsonb:=app_private.access_profile_model_detail(
    nullif(p_draft->>'source_model_id','')::uuid,false
  );
  actor uuid;
  replay jsonb;
  model jsonb;
  result jsonb;
  create_draft jsonb;
begin
  actor:=app_private.access_profile_require_model_action(source->>'domain','create');
  if nullif(btrim(p_draft->>'reason'),'') is null
    or char_length(p_draft->>'reason')>500
    or octet_length(pg_catalog.convert_to(p_draft::text,'UTF8'))>65536 then
    raise invalid_parameter_value using message='invalid access model duplication';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_duplicate',p_draft);
  if replay is not null then return replay; end if;
  create_draft:=jsonb_build_object(
    'domain',source->>'domain',
    'name',coalesce(nullif(btrim(p_draft->>'name'),''),source->>'name'||' (cópia)'),
    'description',coalesce(p_draft->>'description',source->>'description'),
    'max_scope_kind',source->>'max_scope_kind',
    'status','inactive',
    'capabilities',source->'capabilities'
  );
  model:=app_private.access_profile_model_create_internal(actor,create_draft);
  result:=jsonb_build_object('model',model,'model_id',model->>'id',
    'version',(model->>'version')::bigint,'replayed',false);
  perform app_private.access_profile_model_audit_success(
    actor,source->>'domain','create',(model->>'id')::uuid);
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_duplicate',p_draft,result);
  return result;
end
$$;

create or replace function app_private.superadmin_access_profile_models_export(
  p_domain text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  csv text;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'export');
  select 'format_version,domain,name,description,max_scope_kind,status,capabilities'||E'\n'||
    coalesce(string_agg(
      'access-profile-models-v1,'||model.domain||',"'||
      replace(app_private.audit_spreadsheet_cell(model.name),'"','""')||'","'||
      replace(app_private.audit_spreadsheet_cell(coalesce(model.description,'')),'"','""')||'",'||
      model.max_scope_kind||','||model.status||',"'||
      replace(coalesce((app_private.access_profile_model_detail(model.id,false)->'capabilities')::text,'[]'),'"','""')||'"',
      E'\n' order by lower(model.name),model.id
    ),'')
  into csv
  from public.access_profile_templates model
  where model.domain=p_domain;
  perform app_private.access_profile_model_audit_success(
    actor,p_domain,'export',null);
  return jsonb_build_object('format_version','access-profile-models-v1',
    'domain',p_domain,'mime_type','text/csv','csv',csv);
end
$$;

create or replace function app_private.superadmin_access_profile_models_import_preview(
  p_domain text,
  p_rows jsonb
) returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  actor uuid;
  row_item jsonb;
  capability_item jsonb;
  row_number integer:=0;
  error_code text;
  valid_count integer:=0;
  error_count integer:=0;
  preview_rows jsonb:='[]'::jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'import');
  if jsonb_typeof(p_rows)<>'array'
    or jsonb_array_length(p_rows) not between 1 and 100
    or octet_length(pg_catalog.convert_to(p_rows::text,'UTF8'))>1048576 then
    raise invalid_parameter_value using message='invalid access model import rows';
  end if;
  for row_item in select value from jsonb_array_elements(p_rows) loop
    row_number:=row_number+1;
    error_code:=null;
    if row_item ?| array['person_id','membership_id','assignment_id','institution_id',
      'unit_id','group_id','child_context_id','created_by','is_system'] then
      error_code:='mass_assignment_field';
    elsif coalesce(row_item->>'domain',p_domain)<>p_domain then
      error_code:='domain_mismatch';
    elsif char_length(btrim(coalesce(row_item->>'name',''))) not between 2 and 120 then
      error_code:='invalid_name';
    elsif jsonb_typeof(coalesce(row_item->'capabilities','[]'::jsonb))<>'array'
      or jsonb_array_length(coalesce(row_item->'capabilities','[]'::jsonb))>500 then
      error_code:='invalid_capabilities';
    elsif jsonb_array_length(coalesce(row_item->'capabilities','[]'::jsonb))<>(
      select count(distinct item.value->>'code')
      from jsonb_array_elements(coalesce(row_item->'capabilities','[]'::jsonb)) item
    ) then
      error_code:='duplicate_capability';
    else
      for capability_item in
        select value from jsonb_array_elements(coalesce(row_item->'capabilities','[]'::jsonb))
      loop
        if capability_item->>'effect' not in ('allow','deny')
          or (p_domain='platform' and not exists(select 1 from public.platform_permissions p where p.code=capability_item->>'code' and p.status='active'))
          or (p_domain='institution' and not exists(select 1 from public.institution_permissions p where p.code=capability_item->>'code' and p.status='active'))
          or (p_domain='principal' and not exists(select 1 from public.guardian_permission_capabilities p where p.code=capability_item->>'code' and p.status='active')) then
          error_code:='unknown_or_invalid_capability';
          exit;
        end if;
        if capability_item->>'effect'='allow'
          and not app_private.access_profile_model_internal_can_delegate(
            actor,p_domain,capability_item->>'code') then
          error_code:='capability_not_delegable';
          exit;
        end if;
      end loop;
    end if;
    preview_rows:=preview_rows||jsonb_build_array(jsonb_build_object(
      'row_number',row_number,
      'valid',error_code is null,
      'error_code',error_code,
      'payload',(row_item-array['person_id','membership_id','assignment_id',
        'institution_id','unit_id','group_id','child_context_id','created_by','is_system'])
        ||jsonb_build_object('domain',p_domain,'status','inactive')
    ));
    if error_code is null then valid_count:=valid_count+1;
    else error_count:=error_count+1; end if;
  end loop;
  return jsonb_build_object(
    'format_version','access-profile-models-v1','domain',p_domain,
    'valid_count',valid_count,'error_count',error_count,'rows',preview_rows
  );
end
$$;

create or replace function app_private.superadmin_access_profile_models_import_confirm(
  p_request_id uuid,
  p_domain text,
  p_rows jsonb,
  p_reason text
) returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  actor uuid;
  payload jsonb:=jsonb_build_object('domain',p_domain,'rows',p_rows,'reason',p_reason);
  replay jsonb;
  preview jsonb;
  preview_row jsonb;
  model jsonb;
  created_models jsonb:='[]'::jsonb;
  result jsonb;
begin
  actor:=app_private.access_profile_require_model_action(p_domain,'import');
  if nullif(btrim(p_reason),'') is null or char_length(p_reason)>500
    or octet_length(pg_catalog.convert_to(p_rows::text,'UTF8'))>1048576 then
    raise invalid_parameter_value using message='audit reason required';
  end if;
  replay:=app_private.access_profile_model_replay_internal(
    p_request_id,actor,'model_import_confirm',payload);
  if replay is not null then return replay; end if;
  preview:=app_private.superadmin_access_profile_models_import_preview(p_domain,p_rows);
  if (preview->>'error_count')::integer<>0 then
    raise check_violation using message='access model import validation errors must be resolved';
  end if;
  for preview_row in select value from jsonb_array_elements(preview->'rows') loop
    model:=app_private.access_profile_model_create_internal(actor,preview_row->'payload');
    created_models:=created_models||jsonb_build_array(jsonb_build_object(
      'id',model->>'id','name',model->>'name','version',(model->>'version')::bigint
    ));
    perform app_private.access_profile_model_audit_success(
      actor,p_domain,'import',(model->>'id')::uuid);
  end loop;
  result:=jsonb_build_object(
    'format_version','access-profile-models-v1','domain',p_domain,
    'created_count',jsonb_array_length(created_models),'models',created_models,
    'replayed',false
  );
  perform app_private.access_profile_model_store_receipt_internal(
    p_request_id,actor,'model_import_confirm',payload,result
  );
  return result;
end
$$;

create or replace function app_private.superadmin_access_permission_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare result jsonb;
begin
  perform app_private.access_profile_require_model_action('platform','read',false);
  with catalog as (
    select permission.application_code,permission.module_code,permission.module_label,
      coalesce(permission.screen_code,permission.module_code) screen_code,
      permission.screen_label,permission.action_code,permission.action_label,
      permission.code,permission.description,permission.risk_level,
      permission.requires_mfa
    from public.platform_permissions permission where permission.status='active'
    union all
    select permission.application_code,permission.module_code,permission.module_label,
      coalesce(permission.screen_code,permission.module_code),permission.screen_label,
      permission.action_code,permission.action_label,permission.code,
      permission.description,permission.risk_level,permission.requires_mfa
    from public.institution_permissions permission where permission.status='active'
    union all
    select capability.application_code,capability.module_code,capability.module_label,
      capability.screen_code,capability.screen_label,capability.action_code,
      capability.action_label,capability.code,capability.description,
      capability.risk_level,capability.requires_mfa
    from public.guardian_permission_capabilities capability where capability.status='active'
  )
  select jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(catalog)
    order by application_code,module_code,screen_code,action_code,code),'[]'::jsonb))
  into result from catalog;
  return result;
end
$$;

create function app_private.access_profile_model_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in(
        'SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
        'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_INVALID_ARGUMENT',
        'SAI_CONCURRENT_CHANGE') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_ARGUMENT' then 'Revise os dados informados.'
        when p_code='SAI_CONCURRENT_CHANGE' then 'O estado mudou. Recarregue e tente novamente.'
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED') then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code='SAI_INVALID_ARGUMENT' then 400
        when p_code='SAI_CONCURRENT_CHANGE' then 409
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

create function app_private.access_profile_model_call(
  p_operation text,p_args jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;domain text;permission_action text;actor uuid;
  correlation uuid:=gen_random_uuid();error_code text;error_detail text;sql_state text;
  object_id uuid;
begin
  begin
    domain:=case
      when p_operation in('list','create','export','import_preview','import_confirm')
        then coalesce(p_args->>'domain',p_args#>>'{draft,domain}')
      when p_operation='catalog' then 'platform'
      when p_operation in('detail','delete') then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args->>'model_id','')::uuid)
      when p_operation='update' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,id}','')::uuid)
      when p_operation='duplicate' then (
        select model.domain from public.access_profile_templates model
        where model.id=nullif(p_args#>>'{draft,source_model_id}','')::uuid)
    end;
    permission_action:=case p_operation
      when 'list' then 'read' when 'detail' then 'read' when 'catalog' then 'read'
      when 'duplicate' then 'create' when 'import_preview' then 'import'
      when 'import_confirm' then 'import' else p_operation end;
    if p_operation='list' then
      result:=app_private.superadmin_access_profile_models_cursor(
        p_args->>'query',domain,p_args->>'status',p_args->>'scope',
        coalesce((p_args->>'limit')::integer,25),p_args->>'after_name',
        nullif(p_args->>'after_id','')::uuid);
    elsif p_operation='detail' then
      result:=app_private.access_profile_model_detail(
        nullif(p_args->>'model_id','')::uuid,true);
    elsif p_operation='create' then
      result:=app_private.superadmin_access_profile_model_create(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='update' then
      result:=app_private.superadmin_access_profile_model_update(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='delete' then
      result:=app_private.superadmin_access_profile_model_delete(
        nullif(p_args->>'request_id','')::uuid,
        nullif(p_args->>'model_id','')::uuid,(p_args->>'expected_version')::bigint,
        p_args->>'reason');
    elsif p_operation='duplicate' then
      result:=app_private.superadmin_access_profile_model_duplicate(
        nullif(p_args->>'request_id','')::uuid,p_args->'draft');
    elsif p_operation='export' then
      result:=app_private.superadmin_access_profile_models_export(domain);
    elsif p_operation='import_preview' then
      result:=app_private.superadmin_access_profile_models_import_preview(
        domain,p_args->'rows');
    elsif p_operation='import_confirm' then
      result:=app_private.superadmin_access_profile_models_import_confirm(
        nullif(p_args->>'request_id','')::uuid,domain,p_args->'rows',p_args->>'reason');
    elsif p_operation='catalog' then
      result:=app_private.superadmin_access_permission_catalog();
    else
      raise invalid_parameter_value using message='unsupported model operation';
    end if;
    if p_operation in('list','detail','catalog','import_preview') then
      actor:=app_private.access_profile_require_model_action(
        coalesce(domain,'platform'),permission_action,false);
      object_id:=case when p_operation='detail'
        then nullif(p_args->>'model_id','')::uuid else null end;
      perform app_private.access_profile_model_audit_success(
        actor,coalesce(domain,'platform'),permission_action,object_id);
    end if;
  exception when others then
    get stacked diagnostics error_detail=pg_exception_detail,sql_state=returned_sqlstate;
    error_code:=case
      when error_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
        'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED')
        then error_detail
      when sql_state='40001' then 'SAI_CONCURRENT_CHANGE'
      when sql_state in('22023','22P02','23514','23505','22001')
        then 'SAI_INVALID_ARGUMENT'
      when sql_state in('P0002','42501') then 'SAI_PERMISSION_DENIED'
      else 'SAI_INTERNAL_ERROR' end;
    perform app_private.audit_superadmin_internal_denial_if_identified(
      coalesce(case when domain in('platform','institution','principal')
        then domain else 'platform' end||'.role_models.'||
        coalesce(permission_action,'read'),'platform.role_models.read'),
      'superadmin.access-profile-models.'||coalesce(p_operation,'invalid'),
      error_code,correlation,null);
    return app_private.access_profile_model_error_envelope(error_code,correlation);
  end;
  return pg_catalog.jsonb_build_object('ok',true,'data',result,'error',null);
end
$$;

create or replace function public.superadmin_access_profile_model_detail(uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('detail',
  pg_catalog.jsonb_build_object('model_id',$1))$$;
create or replace function public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('list',pg_catalog.jsonb_build_object(
  'query',$1,'domain',$2,'status',$3,'scope',$4,'limit',$5,
  'after_name',$6,'after_id',$7))$$;
create or replace function public.superadmin_access_profile_model_create(uuid,jsonb)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('create',
  pg_catalog.jsonb_build_object('request_id',$1,'draft',$2))$$;
create or replace function public.superadmin_access_profile_model_update(uuid,jsonb)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('update',
  pg_catalog.jsonb_build_object('request_id',$1,'draft',$2))$$;
create or replace function public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('delete',pg_catalog.jsonb_build_object(
  'request_id',$1,'model_id',$2,'expected_version',$3,'reason',$4))$$;
create or replace function public.superadmin_access_profile_model_duplicate(uuid,jsonb)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('duplicate',
  pg_catalog.jsonb_build_object('request_id',$1,'draft',$2))$$;
create or replace function public.superadmin_access_profile_models_export(text)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('export',
  pg_catalog.jsonb_build_object('domain',$1))$$;
create or replace function public.superadmin_access_profile_models_import_preview(text,jsonb)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('import_preview',
  pg_catalog.jsonb_build_object('domain',$1,'rows',$2))$$;
create or replace function public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('import_confirm',
  pg_catalog.jsonb_build_object('request_id',$1,'domain',$2,'rows',$3,'reason',$4))$$;
create or replace function public.superadmin_access_permission_catalog()
returns jsonb language sql volatile security definer set search_path=''
as $$select app_private.access_profile_model_call('catalog','{}'::jsonb)$$;

revoke all on function
  app_private.access_profile_require_model_action(text,text,boolean),
  app_private.access_profile_model_replay_internal(uuid,uuid,text,jsonb),
  app_private.access_profile_model_store_receipt_internal(uuid,uuid,text,jsonb,jsonb),
  app_private.access_profile_model_internal_can_delegate(uuid,text,text),
  app_private.access_profile_model_audit_success(uuid,text,text,uuid),
  app_private.access_profile_model_error_envelope(text,uuid),
  app_private.access_profile_model_call(text,jsonb),
  app_private.access_profile_model_detail(uuid,boolean),
  app_private.access_profile_model_create_internal(uuid,jsonb),
  app_private.superadmin_access_profile_model_create(uuid,jsonb),
  app_private.superadmin_access_profile_model_update(uuid,jsonb),
  app_private.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  app_private.superadmin_access_profile_model_duplicate(uuid,jsonb),
  app_private.superadmin_access_profile_models_export(text),
  app_private.superadmin_access_profile_models_import_preview(text,jsonb),
  app_private.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text),
  app_private.superadmin_access_permission_catalog()
from public,anon,authenticated,service_role;

revoke all on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text),
  public.superadmin_access_permission_catalog()
from public,anon,service_role;

grant execute on function
  public.superadmin_access_profile_model_detail(uuid),
  public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid),
  public.superadmin_access_profile_model_create(uuid,jsonb),
  public.superadmin_access_profile_model_update(uuid,jsonb),
  public.superadmin_access_profile_model_delete(uuid,uuid,bigint,text),
  public.superadmin_access_profile_model_duplicate(uuid,jsonb),
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text),
  public.superadmin_access_permission_catalog()
to authenticated;

revoke all on table
  public.access_profile_templates,
  public.access_profile_template_platform_permissions,
  public.access_profile_template_institution_permissions,
  public.access_profile_template_principal_capabilities
from public,anon,authenticated,service_role;

commit;
