begin;

-- The hub may only advertise domains that have a complete guarded worker
-- lifecycle.  At this point Units is the sole supported domain.  Keeping
-- the remaining entries visible but unavailable lets the UI explain scope
-- without creating a client-side authorization path or a fake workflow.
create or replace function app_private.can_access_import_export_job(p_target_domain text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_target_domain
    when 'units' then app_private.has_platform_permission('units.import')
    when 'units_export' then app_private.has_platform_permission('units.export')
    else false
  end
$$;

create or replace function app_private.superadmin_import_export_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app_private.assert_import_export_hub_actor();
  return jsonb_build_object('domains', jsonb_build_array(
    jsonb_build_object(
      'domain', 'institutions', 'label', 'Institui\u00e7\u00f5es', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'units', 'label', 'Unidades', 'template_version', 'v2',
      'import_available', true, 'export_available', true,
      'import_authorized', app_private.has_platform_permission('units.import'),
      'export_authorized', app_private.has_platform_permission('units.export')
    ),
    jsonb_build_object(
      'domain', 'groups', 'label', 'Turmas', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'activities', 'label', 'Atividades', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'people', 'label', 'Pessoas', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    ),
    jsonb_build_object(
      'domain', 'internal_users', 'label', 'Usu\u00e1rios internos', 'template_version', null,
      'import_available', false, 'export_available', false,
      'import_authorized', false, 'export_authorized', false
    )
  ));
end;
$$;

-- SECURITY DEFINER helpers are implementation details.  Explicit revokes are
-- required because PostgreSQL grants EXECUTE to PUBLIC for new functions.
revoke all on function app_private.assert_import_export_hub_actor() from public, anon, authenticated, service_role;
revoke all on function app_private.can_access_import_export_job(text) from public, anon, authenticated, service_role;
revoke all on function app_private.import_export_job_payload(uuid) from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_import_export_catalog() from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_list_import_export_jobs(text[], text[], timestamptz, uuid, integer)
  from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_get_import_export_job(uuid) from public, anon, authenticated, service_role;

commit;
