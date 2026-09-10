begin;

do $$
begin
  if (
    select count(*) <> 1
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'institution_member_permission_overrides'
      and relation.relkind in ('r', 'p')
      and pg_catalog.pg_get_userbyid(relation.relowner) = 'postgres'
  ) or (
    select count(*) <> 7
    from pg_catalog.pg_attribute attribute
    join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'institution_member_permission_overrides'
      and attribute.attnum > 0
      and not attribute.attisdropped
      and (
        (attribute.attname = 'membership_id' and attribute.atttypid = 'uuid'::pg_catalog.regtype and attribute.attnotnull)
        or (attribute.attname = 'permission_code' and attribute.atttypid = 'text'::pg_catalog.regtype and attribute.attnotnull)
        or (attribute.attname = 'effect' and attribute.atttypid = 'public.permission_effect'::pg_catalog.regtype and attribute.attnotnull)
        or (attribute.attname = 'scope_kind' and attribute.atttypid = 'text'::pg_catalog.regtype and attribute.attnotnull)
        or (attribute.attname = 'scope_id' and attribute.atttypid = 'uuid'::pg_catalog.regtype)
        or (attribute.attname = 'status' and attribute.atttypid = 'public.record_status'::pg_catalog.regtype and attribute.attnotnull)
        or (attribute.attname = 'revoked_at' and attribute.atttypid = 'timestamp with time zone'::pg_catalog.regtype)
      )
  ) or (
    select count(*) <> 2
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'app_private'
      and procedure.oid in (
        'app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)'::pg_catalog.regprocedure,
        'app_private.superadmin_access_profile_assignment_link(uuid,jsonb)'::pg_catalog.regprocedure
      )
      and pg_catalog.pg_get_userbyid(procedure.proowner) = 'postgres'
      and procedure.prosecdef
  ) or exists (
    select 1
    from public.institution_member_permission_overrides override_record
    where override_record.scope_id = '00000000-0000-0000-0000-000000000000'::uuid
  ) or exists (
    select 1
    from public.institution_member_permission_overrides override_record
    where override_record.status='active' and override_record.revoked_at is null
    group by override_record.membership_id, override_record.permission_code,
      override_record.scope_kind,
      coalesce(override_record.scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
    having count(*) > 1
  ) then
    raise exception using
      errcode = '55000',
      message = 'unexpected access profile capability core contract';
  end if;
end;
$$;

create unique index institution_member_permission_overrides_active_scope_uidx
  on public.institution_member_permission_overrides(
    membership_id,
    permission_code,
    scope_kind,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where status='active' and revoked_at is null;

alter table public.institution_member_permission_overrides
  add constraint institution_member_permission_overrides_nonzero_scope_check
  check (
    scope_id is null
    or scope_id <> '00000000-0000-0000-0000-000000000000'::uuid
  );

create or replace function app_private.resolve_institution_assignment_override_effect(
  p_membership_id uuid,
  p_permission_code text,
  p_scope_kind text,
  p_scope_unit_id uuid,
  p_scope_group_id uuid
)
returns public.permission_effect
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when bool_or(override_record.effect = 'deny') then 'deny'::public.permission_effect
    when bool_or(override_record.effect = 'allow') then 'allow'::public.permission_effect
    else null
  end
  from public.institution_member_permission_overrides override_record
  where override_record.membership_id = p_membership_id
    and override_record.permission_code = p_permission_code
    and override_record.scope_kind = p_scope_kind
    and override_record.scope_unit_id is not distinct from p_scope_unit_id
    and override_record.scope_group_id is not distinct from p_scope_group_id
    and override_record.status = 'active'
    and override_record.revoked_at is null
    and (override_record.starts_at is null or override_record.starts_at <= now())
    and (override_record.expires_at is null or override_record.expires_at > now())
$$;

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
        'effective_effect',case when assignment_override.effect='deny' then 'deny'
          when assignment_override.effect='allow' then 'allow' when profile_grant.effect='allow' then 'allow' else 'deny' end,
        'origin_code',case when assignment_override.effect is not null then 'member_override'
          when profile_grant.effect is not null then 'profile' else 'default_deny' end,
        'origin_label',case when assignment_override.effect is not null then 'Personalização da pessoa'
          when profile_grant.effect is not null then 'Perfil' else 'Negado por padrão' end,
        'grantable',app_private.has_platform_permission('institution.roles.manage'),
        'disabled_reason',case when app_private.has_platform_permission('institution.roles.manage') then null
          else 'Você não pode conceder permissões administrativas.' end)
        order by permission_record.module_code,permission_record.screen_code,permission_record.action_code,permission_record.code),'[]'::jsonb))
    into result from public.institution_permissions permission_record
    left join public.institution_role_permissions profile_grant on profile_grant.role_id=p_profile_id
      and profile_grant.permission_id=permission_record.id and profile_grant.status='active' and profile_grant.revoked_at is null
    left join public.institution_role_assignments assignment on assignment.id=p_assignment_id
    left join lateral (
      select app_private.resolve_institution_assignment_override_effect(
        assignment.membership_id,
        permission_record.code,
        assignment.scope_kind,
        assignment.scope_unit_id,
        assignment.scope_group_id
      ) as effect
    ) assignment_override on true
    where permission_record.status='active';
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

create or replace function app_private.superadmin_access_profile_assignment_link(p_request_id uuid,p_draft jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare profile_id uuid:=nullif(p_draft->>'profile_id','')::uuid;domain text;actor uuid;replay jsonb;
  person_id uuid:=nullif(p_draft->>'person_id','')::uuid;membership public.institution_memberships%rowtype;
  assignment_id uuid;result jsonb;scope_kind text:=coalesce(p_draft->>'scope_kind','institution');permission_code text;
begin
  domain:=case when exists(select 1 from public.platform_roles where id=profile_id) then 'platform'
    when exists(select 1 from public.institution_roles where id=profile_id) then 'institution'
    when exists(select 1 from public.access_profile_templates template_record where template_record.id=profile_id and template_record.domain='principal') then 'principal' end;
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

alter function app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid) owner to postgres;
alter function app_private.superadmin_access_profile_assignment_link(uuid,jsonb) owner to postgres;
alter function app_private.resolve_institution_assignment_override_effect(uuid,text,text,uuid,uuid) owner to postgres;

revoke all on function app_private.superadmin_access_profile_capability_catalog(text,uuid,uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_access_profile_assignment_link(uuid,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function app_private.resolve_institution_assignment_override_effect(uuid,text,text,uuid,uuid)
  from public, anon, authenticated, service_role;

create or replace function public.superadmin_access_profile_capability_catalog(text,uuid,uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select app_private.superadmin_access_profile_capability_catalog($1,$2,$3)
$$;

create or replace function public.superadmin_access_profile_assignment_link(uuid,jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select app_private.superadmin_access_profile_assignment_link($1,$2)
$$;

alter function public.superadmin_access_profile_capability_catalog(text,uuid,uuid) owner to postgres;
alter function public.superadmin_access_profile_assignment_link(uuid,jsonb) owner to postgres;
revoke all on function public.superadmin_access_profile_capability_catalog(text,uuid,uuid)
  from public, anon, service_role;
revoke all on function public.superadmin_access_profile_assignment_link(uuid,jsonb)
  from public, anon, service_role;
grant execute on function public.superadmin_access_profile_capability_catalog(text,uuid,uuid)
  to authenticated;
grant execute on function public.superadmin_access_profile_assignment_link(uuid,jsonb)
  to authenticated;

commit;
