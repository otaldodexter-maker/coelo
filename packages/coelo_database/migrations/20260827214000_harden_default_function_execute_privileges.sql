-- Functions are private by default; public RPC access is granted explicitly.
begin;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema app_private
  revoke execute on functions from public, anon, authenticated;

revoke all on function app_private.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated;
revoke all on function app_private.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated;

revoke all on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_prepare(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  from public, anon, authenticated, service_role;
revoke all on function public.superadmin_file_job_fail(uuid,text)
  from public, anon, authenticated, service_role;

grant execute on function public.superadmin_group_import_apply(uuid,uuid,jsonb,jsonb)
  to authenticated;
grant execute on function public.superadmin_group_export_prepare(uuid)
  to authenticated;
grant execute on function public.superadmin_group_export_complete(uuid,text,text,text,bigint,text,integer)
  to service_role;
grant execute on function public.superadmin_file_job_fail(uuid,text)
  to service_role;

commit;
