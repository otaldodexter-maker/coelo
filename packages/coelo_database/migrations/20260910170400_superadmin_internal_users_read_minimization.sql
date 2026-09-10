-- Recarimbada em 2026-09-10 para a faixa 2026091017xxxx do grupo acessos-pessoas.
-- Origem: migrations-historico/20260908021644_superadmin_internal_users_read_minimization.sql
-- Pacote: AP-INTERNAL-USERS-V2
-- Motivo: com a baseline de producao 20260910000000_baseline_producao.sql, a
-- cadeia antiga virou historico. Este pacote nunca chegou a producao, entao
-- volta como migration forward-only SOBRE a baseline. Conteudo inalterado em
-- relacao ao historico, salvo correcoes ja registradas nos commits do grupo.

-- Forward-only corrective READ package; no grants, mutations, or Auth changes.
-- Preserve sensitive detail projection and all existing function ACLs.

create or replace function app_private.superadmin_internal_user_projection(
  p_identity_id uuid,p_include_sensitive boolean
)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'id',identity_record.id,
    'version',greatest(profile_record.version,membership_record.version,auth_link.version),
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
      'id',auth_link.id,'email',case when p_include_sensitive then profile_record.professional_email
        else left(profile_record.professional_email,1)||'***@'||split_part(profile_record.professional_email,'@',2) end,
      'status','accepted',
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

create or replace function public.superadmin_internal_users_list(
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
      and exists(select 1 from app_private.superadmin_internal_auth_links auth_item
        where auth_item.internal_identity_id=identity_record.id)
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
