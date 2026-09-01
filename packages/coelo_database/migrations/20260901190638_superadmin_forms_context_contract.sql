begin;

create or replace function public.superadmin_forms_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := app_private.current_person_id();
  is_owner boolean := false;
  can_manage boolean := false;
begin
  if (select auth.uid()) is null or actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;

  select exists(
    select 1
    from public.platform_memberships membership
    join public.platform_roles role_record on role_record.id = membership.role_id
    where membership.person_id = actor
      and membership.status = 'active'
      and membership.revoked_at is null
      and membership.scope_kind = 'platform'
      and membership.scope_institution_id is null
      and role_record.status = 'active'
      and role_record.code = 'owner'
  ) into is_owner;

  can_manage := app_private.has_platform_permission('forms.manage');
  return jsonb_build_object(
    'capabilities', jsonb_build_object(
      'read', app_private.has_platform_permission('forms.read'),
      'manage', can_manage,
      'publish', app_private.has_platform_permission('forms.publish'),
      'manage_applications', app_private.has_platform_permission('forms.manage_applications'),
      'monitor', app_private.has_platform_permission('forms.monitor'),
      'responses_read', app_private.has_platform_permission('forms.responses.read'),
      'responses_export', app_private.has_platform_permission('forms.responses.export'),
      'transfer_cross_institution', app_private.has_platform_permission('forms.transfer_cross_institution'),
      'anonymous_read', is_owner and app_private.has_platform_permission('forms.anonymous_participation.read'),
      'anonymous_export', is_owner and app_private.has_platform_permission('forms.anonymous_participation.export'),
      'respond', app_private.has_platform_permission('forms.respond')
    ),
    'institutions', case when can_manage then coalesce((
      select jsonb_agg(
        jsonb_build_object('id', institution_record.id, 'name', institution_record.public_name)
        order by lower(institution_record.public_name), institution_record.id
      )
      from public.institutions institution_record
      where institution_record.status = 'active'
        and institution_record.deleted_at is null
        and app_private.audit_actor_has_permission(
          actor, 'forms.manage', institution_record.id, false
        )
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

revoke all on function public.superadmin_forms_context()
  from public, anon, authenticated, service_role;
grant execute on function public.superadmin_forms_context() to authenticated;

commit;
