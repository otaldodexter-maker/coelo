begin;

revoke execute on function public.form_save_application(uuid, bigint, jsonb)
  from service_role;
revoke execute on function public.form_save_schedule(uuid, bigint, jsonb)
  from service_role;

commit;
