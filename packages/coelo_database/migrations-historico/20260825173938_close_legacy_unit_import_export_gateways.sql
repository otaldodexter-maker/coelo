-- The import/export hub is the authenticated entry point.  Keep the original
-- Unit implementation callable only from guarded SECURITY DEFINER code.
revoke all on function public.superadmin_create_unit_import_job(text, text, text, uuid)
  from public, anon, authenticated, service_role;

-- The two-argument failure function predates the Edge execution-scope token.
-- Remove both exposed and private overloads after the scoped three-argument
-- implementation has been installed.
drop function if exists public.superadmin_fail_unit_file_job(uuid, text);
drop function if exists app_private.superadmin_fail_unit_file_job(uuid, text);
