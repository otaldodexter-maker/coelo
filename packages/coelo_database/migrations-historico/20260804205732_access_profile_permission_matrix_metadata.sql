-- Additive read-contract refinement for the Superadmin permission matrix.
-- Authorization, grants, RLS, mutation payloads and audit behavior are unchanged.

create or replace function public.superadmin_access_profile_detail(
  p_domain text,
  p_profile_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  result jsonb;
begin
  perform app_private.require_profile_authority(p_domain);

  if p_domain = 'platform' then
    select jsonb_build_object(
      'domain', p_domain,
      'id', coalesce(role_record.id::text, ''),
      'code', coalesce(role_record.code, ''),
      'name', coalesce(role_record.name, ''),
      'description', coalesce(role_record.description, ''),
      'status', coalesce(role_record.status::text, 'active'),
      'max_scope_kind', coalesce(role_record.max_scope_kind, 'platform'),
      'version', coalesce(role_record.version, 0),
      'is_system', coalesce(role_record.is_system, false),
      'membership_count', (
        select count(*) from public.platform_memberships where role_id = role_record.id
      ),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', membership.id,
          'person_name', person_record.display_name,
          'scope', case
            when membership.scope_kind = 'platform' then 'Plataforma'
            else 'Instituição: ' || membership.scope_institution_id::text
          end
        ) order by lower(person_record.display_name))
        from public.platform_memberships membership
        join public.people person_record on person_record.id = membership.person_id
        where membership.role_id = role_record.id
          and membership.status = 'active'
          and membership.revoked_at is null
      ), '[]'),
      'permissions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'code', permission_record.code,
          'module', permission_record.module_code,
          'screen_code', permission_record.screen_code,
          'action_code', permission_record.action_code,
          'name', permission_record.description,
          'description', permission_record.description,
          'risk', permission_record.risk_level,
          'requires_mfa', permission_record.requires_mfa,
          'selected', grant_record.id is not null and grant_record.effect = 'allow',
          'grantable', app_private.has_platform_permission(permission_record.code),
          'unavailable_reason', case
            when app_private.has_platform_permission(permission_record.code) then null
            else 'Você não pode conceder uma permissão que não possui.'
          end
        ) order by permission_record.module_code, permission_record.screen_code,
          permission_record.action_code, permission_record.code)
        from public.platform_permissions permission_record
        left join public.platform_role_permissions grant_record
          on grant_record.permission_id = permission_record.id
          and grant_record.role_id = role_record.id
          and grant_record.status = 'active'
          and grant_record.revoked_at is null
        where permission_record.status = 'active'
      ), '[]'),
      'audit', case when app_private.has_platform_permission('audit.read') then
        coalesce((
          select jsonb_agg(jsonb_build_object(
            'action', audit_record.action_code,
            'reason', audit_record.reason,
            'occurred_at', audit_record.occurred_at
          ) order by audit_record.occurred_at desc)
          from (
            select * from audit.audit_logs
            where object_id = role_record.id
            order by occurred_at desc
            limit 10
          ) audit_record
        ), '[]')
      else null end
    )
    into result
    from (
      select * from public.platform_roles where id = p_profile_id
      union all
      select null, null, null, null, 'active', false, null, now(), now(), 'platform', 0
      where p_profile_id is null
      limit 1
    ) role_record;
  elsif p_domain = 'institution' then
    select jsonb_build_object(
      'domain', p_domain,
      'id', coalesce(role_record.id::text, ''),
      'institution_id', role_record.institution_id,
      'code', coalesce(role_record.code, ''),
      'name', coalesce(role_record.name, ''),
      'description', coalesce(role_record.description, ''),
      'status', coalesce(role_record.status::text, 'active'),
      'max_scope_kind', coalesce(role_record.max_scope_kind, 'institution'),
      'version', coalesce(role_record.version, 0),
      'is_system', coalesce(role_record.is_system, false),
      'membership_count', (
        select count(*) from public.institution_role_assignments where role_id = role_record.id
      ),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', assignment.id,
          'person_name', person_record.display_name,
          'scope', case assignment.scope_kind
            when 'institution' then 'Instituição'
            when 'unit' then 'Unidade: ' || assignment.scope_unit_id::text
            when 'group' then 'Turma: ' || assignment.scope_group_id::text
          end
        ) order by lower(person_record.display_name))
        from public.institution_role_assignments assignment
        join public.institution_memberships membership on membership.id = assignment.membership_id
        join public.people person_record on person_record.id = membership.person_id
        where assignment.role_id = role_record.id
          and assignment.status = 'active'
          and (assignment.expires_at is null or assignment.expires_at > now())
      ), '[]'),
      'permissions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'code', permission_record.code,
          'module', permission_record.module_code,
          'screen_code', permission_record.screen_code,
          'action_code', permission_record.action_code,
          'name', permission_record.description,
          'description', permission_record.description,
          'risk', permission_record.risk_level,
          'requires_mfa', permission_record.requires_mfa,
          'selected', grant_record.id is not null and grant_record.effect = 'allow',
          'grantable', app_private.has_platform_permission('institution.roles.manage')
            and coalesce(grant_record.effect, 'allow') <> 'deny',
          'unavailable_reason', case
            when grant_record.effect = 'deny'
              then 'Uma negação explícita deve ser tratada separadamente.'
            when not app_private.has_platform_permission('institution.roles.manage')
              then 'Você não pode conceder permissões institucionais.'
            else null
          end
        ) order by permission_record.module_code, permission_record.screen_code,
          permission_record.action_code, permission_record.code)
        from public.institution_permissions permission_record
        left join public.institution_role_permissions grant_record
          on grant_record.permission_id = permission_record.id
          and grant_record.role_id = role_record.id
          and grant_record.status = 'active'
          and grant_record.revoked_at is null
        where permission_record.status = 'active'
      ), '[]'),
      'audit', case when app_private.has_platform_permission('audit.read') then
        coalesce((
          select jsonb_agg(jsonb_build_object(
            'action', audit_record.action_code,
            'reason', audit_record.reason,
            'occurred_at', audit_record.occurred_at
          ) order by audit_record.occurred_at desc)
          from (
            select * from audit.audit_logs
            where object_id = role_record.id
            order by occurred_at desc
            limit 10
          ) audit_record
        ), '[]')
      else null end
    )
    into result
    from (
      select * from public.institution_roles where id = p_profile_id
      union all
      select null, null, null, null, null, false, 'active', now(), now(), 'institution', 0
      where p_profile_id is null
      limit 1
    ) role_record;
  else
    raise invalid_parameter_value using message = 'unsupported profile domain';
  end if;

  if result is null then
    raise no_data_found using message = 'access profile not found';
  end if;
  return result;
end
$$;
