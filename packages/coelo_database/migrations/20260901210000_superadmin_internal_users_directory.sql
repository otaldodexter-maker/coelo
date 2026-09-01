begin;

insert into public.platform_permissions(
  code,module_code,module_label,screen_code,screen_label,action_code,action_label,
  description,risk_level,requires_mfa
) values
  ('platform.member.read','platform','Superadmin','members','Usuários internos','read','Ver',
   'Consultar o diretório privado de usuários internos Coelo.','high',true),
  ('platform.member.update','platform','Superadmin','members','Usuários internos','update','Editar',
   'Editar cadastro, perfil e alcance de usuários internos Coelo.','high',true),
  ('platform.member.suspend','platform','Superadmin','members','Usuários internos','status','Gerenciar',
   'Suspender, reativar ou revogar vínculos internos Coelo.','high',true)
on conflict(code) do update set
  module_code=excluded.module_code,
  module_label=excluded.module_label,
  screen_code=excluded.screen_code,
  screen_label=excluded.screen_label,
  action_code=excluded.action_code,
  action_label=excluded.action_label,
  description=excluded.description,
  risk_level=excluded.risk_level,
  requires_mfa=excluded.requires_mfa,
  status='active';

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code in(
    'platform.member.read','platform.member.update','platform.member.suspend')
where role_record.code='owner'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record
join public.platform_permissions permission_record
  on permission_record.code='platform.member.read'
where role_record.code='auditor'
on conflict(role_id,permission_id) do update set
  effect='allow',status='active',revoked_at=null;

create table app_private.superadmin_internal_profiles(
  internal_identity_id uuid primary key
    references app_private.superadmin_internal_identities(id) on delete restrict,
  first_name text not null check(length(btrim(first_name)) between 1 and 80),
  last_name text not null check(length(btrim(last_name)) between 1 and 120),
  display_name text not null default '' check(length(display_name)<=160),
  birth_date date,
  cpf text not null check(cpf~'^[0-9]{11}$'),
  cpf_hash bytea generated always as(
    extensions.digest(pg_catalog.convert_to(cpf,'UTF8'),'sha256')) stored,
  professional_email text not null
    check(professional_email=lower(btrim(professional_email))
      and length(professional_email)<=254 and professional_email like '%@%'),
  mobile text not null default '' check(length(mobile)<=24),
  additional_phone text not null default '' check(length(additional_phone)<=24),
  job_title text not null check(length(btrim(job_title)) between 1 and 120),
  department text not null default '' check(length(department)<=120),
  internal_function text not null default '' check(length(internal_function)<=120),
  professional_notes text not null default '' check(length(professional_notes)<=1000),
  postal_code text not null default '' check(length(postal_code)<=12),
  street text not null default '' check(length(street)<=160),
  address_number text not null default '' check(length(address_number)<=24),
  complement text not null default '' check(length(complement)<=120),
  neighborhood text not null default '' check(length(neighborhood)<=120),
  city text not null default '' check(length(city)<=120),
  state text not null default '' check(length(state)<=80),
  country text not null default 'Brasil' check(length(country) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version bigint not null default 1 check(version>0)
);

create unique index superadmin_internal_profiles_cpf_uidx
  on app_private.superadmin_internal_profiles(cpf_hash);
create unique index superadmin_internal_profiles_email_uidx
  on app_private.superadmin_internal_profiles(lower(professional_email));
create index superadmin_internal_profiles_name_idx
  on app_private.superadmin_internal_profiles(lower(last_name),lower(first_name),internal_identity_id);

create table app_private.superadmin_internal_membership_scopes(
  membership_id uuid not null
    references app_private.superadmin_internal_memberships(id) on delete cascade,
  institution_id uuid not null references public.institutions(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(membership_id,institution_id)
);
create index superadmin_internal_membership_scopes_institution_idx
  on app_private.superadmin_internal_membership_scopes(institution_id,membership_id);

create table app_private.superadmin_internal_user_command_receipts(
  request_id uuid primary key,
  actor_internal_identity_id uuid not null
    references app_private.superadmin_internal_identities(id) on delete restrict,
  action_code text not null check(action_code in('update','status')),
  request_hash bytea not null check(octet_length(request_hash)=32),
  result jsonb not null,
  created_at timestamptz not null default now()
);
create index superadmin_internal_user_command_receipts_actor_idx
  on app_private.superadmin_internal_user_command_receipts(
    actor_internal_identity_id,created_at desc);

alter table app_private.superadmin_internal_profiles enable row level security;
alter table app_private.superadmin_internal_profiles force row level security;
alter table app_private.superadmin_internal_membership_scopes enable row level security;
alter table app_private.superadmin_internal_membership_scopes force row level security;
alter table app_private.superadmin_internal_user_command_receipts enable row level security;
alter table app_private.superadmin_internal_user_command_receipts force row level security;
revoke all on app_private.superadmin_internal_profiles
  from public,anon,authenticated,service_role;
revoke all on app_private.superadmin_internal_membership_scopes
  from public,anon,authenticated,service_role;
revoke all on app_private.superadmin_internal_user_command_receipts
  from public,anon,authenticated,service_role;

create function app_private.superadmin_internal_user_projection(
  p_identity_id uuid,p_include_sensitive boolean
)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'id',identity_record.id,
    'version',pg_catalog.greatest(profile_record.version,membership_record.version,auth_link.version),
    'identity',pg_catalog.jsonb_build_object(
      'id',identity_record.id,'first_name',profile_record.first_name,
      'last_name',profile_record.last_name,'display_name',profile_record.display_name,
      'birth_date',case when p_include_sensitive then profile_record.birth_date else null end,
      'cpf',case when p_include_sensitive then profile_record.cpf
        else repeat('0',9)||right(profile_record.cpf,2) end,
      'professional_email',case when p_include_sensitive then profile_record.professional_email
        else left(profile_record.professional_email,1)||'***@'||split_part(profile_record.professional_email,'@',2) end,
      'mobile',case when p_include_sensitive then profile_record.mobile
        when profile_record.mobile='' then '' else repeat('0',7)||right(profile_record.mobile,4) end,
      'additional_phone',case when p_include_sensitive then profile_record.additional_phone else '' end,
      'job_title',profile_record.job_title,
      'department',profile_record.department,'internal_function',profile_record.internal_function,
      'professional_notes',case when p_include_sensitive then profile_record.professional_notes else '' end,
      'postal_code',case when p_include_sensitive then profile_record.postal_code else '' end,
      'street',case when p_include_sensitive then profile_record.street else '' end,
      'number',case when p_include_sensitive then profile_record.address_number else '' end,
      'complement',case when p_include_sensitive then profile_record.complement else '' end,
      'neighborhood',case when p_include_sensitive then profile_record.neighborhood else '' end,
      'city',case when p_include_sensitive then profile_record.city else '' end,
      'state',case when p_include_sensitive then profile_record.state else '' end,
      'country',case when p_include_sensitive then profile_record.country else 'Brasil' end),
    'credential',pg_catalog.jsonb_build_object('status',case auth_link.status
      when 'active' then 'active' when 'suspended' then 'blocked' else 'noAccess' end),
    'memberships',pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'id',membership_record.id,'status',membership_record.status,
      'scope',case when membership_record.scope_kind='platform' then 'platform' else 'limited' end,
      'scope_ids',coalesce((select pg_catalog.jsonb_agg(scope_record.institution_id order by institution.public_name)
        from app_private.superadmin_internal_membership_scopes scope_record
        join public.institutions institution on institution.id=scope_record.institution_id
        where scope_record.membership_id=membership_record.id),
        case when membership_record.scope_institution_id is null then '[]'::jsonb
          else pg_catalog.jsonb_build_array(membership_record.scope_institution_id) end),
      'scope_names',coalesce((select pg_catalog.jsonb_agg(institution.public_name order by institution.public_name)
        from app_private.superadmin_internal_membership_scopes scope_record
        join public.institutions institution on institution.id=scope_record.institution_id
        where scope_record.membership_id=membership_record.id),
        case when membership_record.scope_institution_id is null then '[]'::jsonb
          else pg_catalog.jsonb_build_array((select institution.public_name
            from public.institutions institution
            where institution.id=membership_record.scope_institution_id)) end),
      'started_at',membership_record.created_at,'ended_at',coalesce(membership_record.revoked_at,membership_record.suspended_at),
      'profile',pg_catalog.jsonb_build_object(
        'id',role_record.id,'name',role_record.name,'code',role_record.code,
        'allows_global',role_record.max_scope_kind='platform','active',role_record.status='active',
        'permissions',coalesce((select pg_catalog.jsonb_agg(permission_record.code order by permission_record.code)
          from public.platform_role_permissions role_permission
          join public.platform_permissions permission_record on permission_record.id=role_permission.permission_id
          where role_permission.role_id=role_record.id and role_permission.status='active'
            and role_permission.revoked_at is null and role_permission.effect='allow'
            and permission_record.status='active'),'[]'::jsonb)))),
    'invitation',pg_catalog.jsonb_build_object(
      'id',auth_link.id,'email',profile_record.professional_email,'status','accepted',
      'attempts',1,'updated_at',auth_link.created_at),
    'history',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'at',audit_record.occurred_at,'title',case audit_record.action_code
          when 'superadmin.internal-users.update' then 'Cadastro atualizado'
          when 'superadmin.internal-users.suspend' then 'Acesso suspenso'
          when 'superadmin.internal-users.reactivate' then 'Acesso reativado'
          when 'superadmin.internal-users.revoke' then 'Vínculo revogado'
          else 'Alteração de acesso' end,
        'detail',coalesce(audit_record.reason_code,'Operação auditada.')) order by audit_record.occurred_at)
      from audit.audit_logs audit_record
      where audit_record.object_type='superadmin_internal_identity'
        and audit_record.object_id=identity_record.id),'[]'::jsonb))
  from app_private.superadmin_internal_identities identity_record
  join app_private.superadmin_internal_profiles profile_record
    on profile_record.internal_identity_id=identity_record.id
  join lateral(select membership_item.*
    from app_private.superadmin_internal_memberships membership_item
    where membership_item.internal_identity_id=identity_record.id
    order by (membership_item.status='active') desc,membership_item.created_at desc limit 1
  ) membership_record on true
  join public.platform_roles role_record on role_record.id=membership_record.platform_role_id
  join lateral(select auth_item.*
    from app_private.superadmin_internal_auth_links auth_item
    where auth_item.internal_identity_id=identity_record.id
    order by (auth_item.status='active') desc,auth_item.created_at desc limit 1
  ) auth_link on true
  where identity_record.id=p_identity_id
$$;

revoke all on function app_private.superadmin_internal_user_projection(uuid,boolean)
  from public,anon,authenticated,service_role;

create function app_private.superadmin_internal_user_target_allowed(
  p_ctx app_private.superadmin_internal_context,p_internal_identity_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select p_internal_identity_id is not null and exists(
    select 1 from app_private.superadmin_internal_profiles profile_record
    join lateral(select membership_item.*
      from app_private.superadmin_internal_memberships membership_item
      where membership_item.internal_identity_id=profile_record.internal_identity_id
      order by (membership_item.status='active') desc,membership_item.created_at desc limit 1
    ) membership_record on true
    join lateral(select auth_item.*
      from app_private.superadmin_internal_auth_links auth_item
      where auth_item.internal_identity_id=profile_record.internal_identity_id
      order by (auth_item.status='active') desc,auth_item.created_at desc limit 1
    ) auth_link on true
    where profile_record.internal_identity_id=p_internal_identity_id
      and (p_ctx.scope_kind='platform' or (
        membership_record.scope_kind='institution' and (
          membership_record.scope_institution_id=p_ctx.scope_institution_id or exists(
            select 1 from app_private.superadmin_internal_membership_scopes scope_record
            where scope_record.membership_id=membership_record.id
              and scope_record.institution_id=p_ctx.scope_institution_id))))
  )
$$;

create function app_private.superadmin_internal_user_denial_code(
  p_sqlstate text,p_detail text
) returns text language sql immutable security invoker set search_path='' as $$
  select case
    when p_detail in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID','SAI_INTERNAL_CONTEXT_DENIED',
      'SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED',
      'SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then p_detail
    when p_sqlstate='40001' then 'SAI_CONCURRENT_CHANGE'
    when p_sqlstate in('22023','23503','23514','22P02','22001') then 'SAI_INVALID_INPUT'
    when p_sqlstate in('P0002','42501') then 'SAI_PERMISSION_DENIED'
    else 'SAI_INTERNAL_ERROR' end
$$;

create function app_private.superadmin_internal_user_error_envelope(
  p_code text,p_correlation_id uuid
) returns jsonb language sql immutable security invoker set search_path='' as $$
  select pg_catalog.jsonb_build_object('ok',false,'data',null,'error',
    pg_catalog.jsonb_build_object(
      'code',case when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID',
        'SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED','SAI_MEMBERSHIP_REVOKED',
        'SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED','SAI_LAST_OWNER_PROTECTED',
        'SAI_CONCURRENT_CHANGE','SAI_INVALID_INPUT') then p_code else 'SAI_INTERNAL_ERROR' end,
      'message',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 'Autenticação necessária.'
        when p_code='SAI_MFA_REQUIRED' then 'Confirme o segundo fator.'
        when p_code='SAI_INVALID_INPUT' then 'Revise os dados enviados.'
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE')
          then 'O estado mudou. Recarregue e tente novamente.'
        when p_code like 'SAI_%DENIED' or p_code like 'SAI_MEMBERSHIP_%'
          then 'Acesso não autorizado.'
        else 'Não foi possível concluir a operação.' end,
      'correlation_id',p_correlation_id,
      'http_status',case
        when p_code in('SAI_AUTH_REQUIRED','SAI_SESSION_INVALID') then 401
        when p_code in('SAI_LAST_OWNER_PROTECTED','SAI_CONCURRENT_CHANGE') then 409
        when p_code='SAI_INVALID_INPUT' then 422
        when p_code in('SAI_INTERNAL_CONTEXT_DENIED','SAI_MEMBERSHIP_SUSPENDED',
          'SAI_MEMBERSHIP_REVOKED','SAI_PERMISSION_DENIED','SAI_MFA_REQUIRED') then 403
        else 500 end))
$$;

revoke all on function app_private.superadmin_internal_user_target_allowed(
  app_private.superadmin_internal_context,uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_internal_user_denial_code(text,text)
  from public,anon,authenticated,service_role;
revoke all on function app_private.superadmin_internal_user_error_envelope(text,uuid)
  from public,anon,authenticated,service_role;

create function public.superadmin_internal_user_profiles()
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();result jsonb;
  error_state text;error_detail text;reason_code text;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.read');
  select pg_catalog.jsonb_build_object('items',coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'id',role_record.id,'code',role_record.code,'name',role_record.name,
      'active',role_record.status='active','allows_global',role_record.max_scope_kind='platform',
      'permissions',coalesce((select pg_catalog.jsonb_agg(permission_record.code order by permission_record.code)
        from public.platform_role_permissions role_permission
        join public.platform_permissions permission_record on permission_record.id=role_permission.permission_id
        where role_permission.role_id=role_record.id and role_permission.status='active'
          and role_permission.revoked_at is null and role_permission.effect='allow'
          and permission_record.status='active'),'[]'::jsonb)) order by role_record.name),'[]'::jsonb))
    into result from public.platform_roles role_record where role_record.status='active';
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.read',ctx.aal,'superadmin.internal-users.profiles','success',null,correlation);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.read','superadmin.internal-users.profiles',reason_code,correlation);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

create function public.superadmin_internal_users_list(
  p_search text default null,p_profile_ids uuid[] default null,
  p_statuses text[] default null,p_scopes text[] default null,
  p_page integer default 1,p_page_size integer default 11
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();
  result jsonb;safe_page integer;safe_size integer;
  error_state text;error_detail text;reason_code text;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.read');
  if length(coalesce(p_search,''))>160
    or coalesce(p_page,1) not between 1 and 10000
    or coalesce(p_page_size,11) not in(8,11,20,50,100)
    or coalesce(cardinality(p_profile_ids),0)>100
    or coalesce(cardinality(p_statuses),0)>4
    or coalesce(cardinality(p_scopes),0)>2
    or exists(select 1 from unnest(coalesce(p_statuses,'{}'::text[])) item
      where item not in('invited','active','suspended','revoked'))
    or exists(select 1 from unnest(coalesce(p_scopes,'{}'::text[])) item
      where item not in('platform','limited'))
    or exists(select 1 from unnest(coalesce(p_profile_ids,'{}'::uuid[])) profile_id
      where not exists(select 1 from public.platform_roles role_record
        where role_record.id=profile_id and role_record.status='active')) then
    raise invalid_parameter_value using message='invalid internal user directory filters';
  end if;
  safe_page:=coalesce(p_page,1);
  safe_size:=coalesce(p_page_size,11);
  with filtered as(
    select identity_record.id,profile_record.first_name,profile_record.last_name
    from app_private.superadmin_internal_identities identity_record
    join app_private.superadmin_internal_profiles profile_record
      on profile_record.internal_identity_id=identity_record.id
    join lateral(select membership_item.*
      from app_private.superadmin_internal_memberships membership_item
      where membership_item.internal_identity_id=identity_record.id
      order by (membership_item.status='active') desc,membership_item.created_at desc limit 1
    ) membership_record on true
    where (ctx.scope_kind='platform' or (membership_record.scope_kind='institution' and (
      membership_record.scope_institution_id=ctx.scope_institution_id or exists(
        select 1 from app_private.superadmin_internal_membership_scopes scope_record
        where scope_record.membership_id=membership_record.id
          and scope_record.institution_id=ctx.scope_institution_id))))
      and (nullif(btrim(p_search),'') is null or concat_ws(' ',profile_record.first_name,
        profile_record.last_name,profile_record.professional_email,profile_record.job_title)
        ilike '%'||btrim(p_search)||'%')
      and (p_profile_ids is null or membership_record.platform_role_id=any(p_profile_ids))
      and (p_statuses is null or membership_record.status::text=any(p_statuses))
      and (p_scopes is null or case when membership_record.scope_kind='platform'
        then 'platform' else 'limited' end=any(p_scopes))
  ),paged as(
    select * from filtered order by lower(last_name),lower(first_name),id
    offset (safe_page-1)*safe_size limit safe_size
  ) select pg_catalog.jsonb_build_object(
      'items',coalesce((select pg_catalog.jsonb_agg(
        app_private.superadmin_internal_user_projection(paged.id,false)
        order by lower(paged.last_name),lower(paged.first_name),paged.id) from paged),'[]'::jsonb),
      'total',(select count(*) from filtered),'page',safe_page,'page_size',safe_size)
    into result;
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.read',ctx.aal,'superadmin.internal-users.list','success',null,correlation);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.read','superadmin.internal-users.list',reason_code,correlation);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

create function public.superadmin_internal_user_detail(p_internal_identity_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();result jsonb;
  error_state text;error_detail text;reason_code text;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.read');
  if not app_private.superadmin_internal_user_target_allowed(ctx,p_internal_identity_id) then
    raise insufficient_privilege using message='internal user unavailable',detail='SAI_PERMISSION_DENIED';
  end if;
  result:=app_private.superadmin_internal_user_projection(p_internal_identity_id,true);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.read',ctx.aal,'superadmin.internal-users.detail','success',null,
    correlation,null,'superadmin_internal_identity',p_internal_identity_id);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.read','superadmin.internal-users.detail',reason_code,correlation);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

create function public.superadmin_internal_user_update(
  p_request_id uuid,p_internal_identity_id uuid,p_expected_version bigint,
  p_reason text,p_draft jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();
  profile_record app_private.superadmin_internal_profiles%rowtype;
  membership_record app_private.superadmin_internal_memberships%rowtype;
  target_role public.platform_roles%rowtype;scope_id uuid;result jsonb;
  fingerprint bytea;receipt app_private.superadmin_internal_user_command_receipts%rowtype;
  error_state text;error_detail text;reason_code text;audit_institution_id uuid;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.update');
  audit_institution_id:=case when ctx.scope_kind='institution'
    then ctx.scope_institution_id else null end;
  if p_request_id is null or p_internal_identity_id is null
    or p_expected_version is null or p_expected_version<1
    or length(btrim(coalesce(p_reason,''))) not between 8 and 500
    or p_draft is null or pg_column_size(p_draft)>32768
    or jsonb_typeof(p_draft)<>'object' or jsonb_typeof(p_draft->'identity')<>'object'
    or (select array_agg(key order by key) from jsonb_object_keys(p_draft) key)
      is distinct from array['identity','profile_id','scope','scope_ids']::text[]
    or (select array_agg(key order by key) from jsonb_object_keys(p_draft->'identity') key)
      is distinct from array['additional_phone','birth_date','city','complement','country','cpf','department',
        'display_name','first_name','internal_function','job_title','last_name','mobile',
        'neighborhood','number','postal_code','professional_email','professional_notes','state',
        'street']::text[]
    or jsonb_typeof(p_draft->'profile_id')<>'string'
    or jsonb_typeof(p_draft->'scope')<>'string'
    or p_draft->>'scope' is null or p_draft->>'scope' not in('platform','limited')
    or jsonb_typeof(p_draft->'scope_ids')<>'array'
    or jsonb_array_length(p_draft->'scope_ids')>100
    or (select count(*)<>count(distinct value)
      from jsonb_array_elements_text(p_draft->'scope_ids')) then
    raise invalid_parameter_value using message='invalid internal user command';
  end if;
  if not app_private.superadmin_internal_user_target_allowed(ctx,p_internal_identity_id) then
    raise insufficient_privilege using message='internal user unavailable',detail='SAI_PERMISSION_DENIED';
  end if;
  if ctx.scope_kind='institution' and (
    p_draft->>'scope'<>'limited' or jsonb_array_length(p_draft->'scope_ids')<>1
    or (p_draft->'scope_ids'->>0)::uuid is distinct from ctx.scope_institution_id) then
    raise insufficient_privilege using message='internal user scope escalation denied',detail='SAI_PERMISSION_DENIED';
  end if;
  fingerprint:=extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'identity_id',p_internal_identity_id,'expected_version',p_expected_version,
    'reason',btrim(p_reason),'draft',p_draft)::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.internal-user-command:'||p_request_id::text,0));
  select * into receipt from app_private.superadmin_internal_user_command_receipts
    where request_id=p_request_id;
  if receipt.request_id is not null then
    if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
      or receipt.action_code<>'update' or receipt.request_hash<>fingerprint then
      raise invalid_parameter_value using message='idempotency key reused with another command';
    end if;
    return receipt.result;
  end if;
  select * into strict profile_record from app_private.superadmin_internal_profiles
    where internal_identity_id=p_internal_identity_id for update;
  select * into strict membership_record from app_private.superadmin_internal_memberships
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  if pg_catalog.greatest(profile_record.version,membership_record.version)<>p_expected_version then
    raise serialization_failure using message='concurrent internal user change',detail='SAI_CONCURRENT_CHANGE';
  end if;
  if lower(btrim(p_draft#>>'{identity,professional_email}'))
      is distinct from profile_record.professional_email then
    raise object_not_in_prerequisite_state using
      message='active internal credential email is immutable';
  end if;
  select * into strict target_role from public.platform_roles
    where id=(p_draft->>'profile_id')::uuid and status='active';
  if target_role.code='owner' and p_draft->>'scope'<>'platform' then
    raise check_violation using message='owner requires platform scope';
  end if;
  update app_private.superadmin_internal_profiles set
    first_name=btrim(p_draft#>>'{identity,first_name}'),
    last_name=btrim(p_draft#>>'{identity,last_name}'),
    display_name=coalesce(btrim(p_draft#>>'{identity,display_name}'),''),
    birth_date=nullif(p_draft#>>'{identity,birth_date}','')::date,
    cpf=regexp_replace(coalesce(p_draft#>>'{identity,cpf}',''),'\D','','g'),
    professional_email=lower(btrim(p_draft#>>'{identity,professional_email}')),
    mobile=coalesce(btrim(p_draft#>>'{identity,mobile}'),''),
    additional_phone=coalesce(btrim(p_draft#>>'{identity,additional_phone}'),''),
    job_title=btrim(p_draft#>>'{identity,job_title}'),
    department=coalesce(btrim(p_draft#>>'{identity,department}'),''),
    internal_function=coalesce(btrim(p_draft#>>'{identity,internal_function}'),''),
    professional_notes=coalesce(btrim(p_draft#>>'{identity,professional_notes}'),''),
    postal_code=coalesce(btrim(p_draft#>>'{identity,postal_code}'),''),
    street=coalesce(btrim(p_draft#>>'{identity,street}'),''),
    address_number=coalesce(btrim(p_draft#>>'{identity,number}'),''),
    complement=coalesce(btrim(p_draft#>>'{identity,complement}'),''),
    neighborhood=coalesce(btrim(p_draft#>>'{identity,neighborhood}'),''),
    city=coalesce(btrim(p_draft#>>'{identity,city}'),''),
    state=coalesce(btrim(p_draft#>>'{identity,state}'),''),
    country=coalesce(nullif(btrim(p_draft#>>'{identity,country}'),''),'Brasil'),
    updated_at=now(),version=version+1
  where internal_identity_id=p_internal_identity_id;
  update app_private.superadmin_internal_memberships set
    platform_role_id=target_role.id,
    scope_kind=case when p_draft->>'scope'='platform' then 'platform'
      else 'institution' end::app_private.superadmin_internal_scope_kind,
    scope_institution_id=case when p_draft->>'scope'='platform' then null
      else (p_draft->'scope_ids'->>0)::uuid end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=membership_record.id;
  delete from app_private.superadmin_internal_membership_scopes
    where membership_id=membership_record.id;
  if p_draft->>'scope'='limited' then
    for scope_id in select value::uuid from pg_catalog.jsonb_array_elements_text(
      coalesce(p_draft->'scope_ids','[]'::jsonb)) loop
      if not exists(select 1 from public.institutions institution where institution.id=scope_id) then
        raise foreign_key_violation using message='unknown institution scope';
      end if;
      insert into app_private.superadmin_internal_membership_scopes(membership_id,institution_id)
        values(membership_record.id,scope_id) on conflict do nothing;
    end loop;
    if not exists(select 1 from app_private.superadmin_internal_membership_scopes
      where membership_id=membership_record.id) then
      raise check_violation using message='limited scope requires institution';
    end if;
  end if;
  result:=app_private.superadmin_internal_user_projection(p_internal_identity_id,true);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.update',ctx.aal,'superadmin.internal-users.update','success',null,
    correlation,null,'superadmin_internal_identity',p_internal_identity_id);
  insert into app_private.superadmin_internal_user_command_receipts(
    request_id,actor_internal_identity_id,action_code,request_hash,result
  ) values(p_request_id,ctx.internal_identity_id,'update',fingerprint,result);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.update','superadmin.internal-users.update',reason_code,correlation,
    audit_institution_id);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

create function public.superadmin_internal_user_change_status(
  p_request_id uuid,p_internal_identity_id uuid,p_expected_version bigint,
  p_status text,p_reason text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context;correlation uuid:=gen_random_uuid();
  membership_record app_private.superadmin_internal_memberships%rowtype;
  auth_link app_private.superadmin_internal_auth_links%rowtype;result jsonb;action_code text;
  fingerprint bytea;receipt app_private.superadmin_internal_user_command_receipts%rowtype;
  error_state text;error_detail text;reason_code text;audit_institution_id uuid;
begin
  select * into strict ctx
    from app_private.require_superadmin_internal_context('platform.member.suspend');
  audit_institution_id:=case when ctx.scope_kind='institution'
    then ctx.scope_institution_id else null end;
  if p_request_id is null or p_internal_identity_id is null
    or p_expected_version is null or p_expected_version<1
    or p_status is null or p_status not in('active','suspended','revoked')
    or length(btrim(coalesce(p_reason,''))) not between 8 and 500 then
    raise invalid_parameter_value using message='invalid internal status command';
  end if;
  if not app_private.superadmin_internal_user_target_allowed(ctx,p_internal_identity_id) then
    raise insufficient_privilege using message='internal user unavailable',detail='SAI_PERMISSION_DENIED';
  end if;
  fingerprint:=extensions.digest(pg_catalog.convert_to(pg_catalog.jsonb_build_object(
    'identity_id',p_internal_identity_id,'expected_version',p_expected_version,
    'status',p_status,'reason',btrim(p_reason))::text,'UTF8'),'sha256');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('coelo.internal-user-command:'||p_request_id::text,0));
  select * into receipt from app_private.superadmin_internal_user_command_receipts
    where request_id=p_request_id;
  if receipt.request_id is not null then
    if receipt.actor_internal_identity_id is distinct from ctx.internal_identity_id
      or receipt.action_code<>'status' or receipt.request_hash<>fingerprint then
      raise invalid_parameter_value using message='idempotency key reused with another command';
    end if;
    return receipt.result;
  end if;
  select * into strict membership_record from app_private.superadmin_internal_memberships
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  select * into strict auth_link from app_private.superadmin_internal_auth_links
    where internal_identity_id=p_internal_identity_id
    order by (status='active') desc,created_at desc limit 1 for update;
  if pg_catalog.greatest(membership_record.version,auth_link.version)<>p_expected_version then
    raise serialization_failure using message='concurrent internal user change',detail='SAI_CONCURRENT_CHANGE';
  end if;
  if membership_record.status='revoked' then
    raise object_not_in_prerequisite_state using message='revoked internal access is terminal';
  end if;
  update app_private.superadmin_internal_memberships set
    status=p_status::app_private.superadmin_internal_membership_status,
    suspended_at=case when p_status='suspended' then now() else null end,
    revoked_at=case when p_status='revoked' then now() else null end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=membership_record.id;
  update app_private.superadmin_internal_auth_links set
    status=p_status::app_private.superadmin_internal_auth_link_status,
    suspended_at=case when p_status='suspended' then now() else null end,
    revoked_at=case when p_status='revoked' then now() else null end,
    changed_by_internal_identity_id=ctx.internal_identity_id,version=version+1
  where id=auth_link.id;
  action_code:=case p_status when 'suspended' then 'superadmin.internal-users.suspend'
    when 'active' then 'superadmin.internal-users.reactivate'
    else 'superadmin.internal-users.revoke' end;
  result:=app_private.superadmin_internal_user_projection(p_internal_identity_id,true);
  perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,
    ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    'platform.member.suspend',ctx.aal,action_code,'success',null,correlation,
    null,'superadmin_internal_identity',p_internal_identity_id);
  insert into app_private.superadmin_internal_user_command_receipts(
    request_id,actor_internal_identity_id,action_code,request_hash,result
  ) values(p_request_id,ctx.internal_identity_id,'status',fingerprint,result);
  return result;
exception when others then
  get stacked diagnostics error_state=returned_sqlstate,error_detail=pg_exception_detail;
  reason_code:=app_private.superadmin_internal_user_denial_code(error_state,error_detail);
  perform app_private.audit_superadmin_internal_denial_if_identified(
    'platform.member.suspend','superadmin.internal-users.status',reason_code,correlation,
    audit_institution_id);
  return app_private.superadmin_internal_user_error_envelope(reason_code,correlation);
end
$$;

revoke all on function public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_internal_user_detail(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)
  from public,anon,authenticated,service_role;
revoke all on function public.superadmin_internal_user_profiles()
  from public,anon,authenticated,service_role;
grant execute on function public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)
  to authenticated;
grant execute on function public.superadmin_internal_user_detail(uuid) to authenticated;
grant execute on function public.superadmin_internal_user_update(uuid,uuid,bigint,text,jsonb)
  to authenticated;
grant execute on function public.superadmin_internal_user_change_status(uuid,uuid,bigint,text,text)
  to authenticated;
grant execute on function public.superadmin_internal_user_profiles() to authenticated;

commit;
