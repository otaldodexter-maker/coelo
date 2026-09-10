begin;

-- PostgreSQL grants EXECUTE to PUBLIC for newly created functions.  The
-- import/export bridge invokes these routines internally through guarded
-- public gateways or service-role workers; no browser role may invoke an
-- implementation function directly.
revoke all on function app_private.import_export_job_direction(text)
  from public, anon, authenticated, service_role;
revoke all on function app_private.import_export_job_domain(text)
  from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_preview_unit_import_from_edge(
  uuid, uuid, jsonb, jsonb, text, bigint, text, text
) from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_materialize_unit_export_from_edge(uuid)
  from public, anon, authenticated, service_role;
revoke all on function app_private.superadmin_unit_export_page_v2(uuid, bigint, integer)
  from public, anon, authenticated, service_role;

commit;
