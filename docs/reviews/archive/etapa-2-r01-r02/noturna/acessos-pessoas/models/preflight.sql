-- Exact legacy cursor observed by catalog-only production read, 2026-09-09.
do $nominal_preflight$
begin
  if current_user <> 'postgres'
    or to_regprocedure('app_private.access_profile_require_model_action(text,text,boolean)') is not null
    or to_regclass('app_private.access_profile_model_command_receipts') is not null
    or exists(select 1 from public.platform_permissions where code like '%.role_models.%')
    or (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_proc where oid=to_regprocedure(
      'app_private.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'))
      is distinct from '80c967df71bf2b81820320533b9f790b'
    or (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_proc where oid=to_regprocedure(
      'public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)'))
      is distinct from '4d7d0a2b65a0021dba3adbb4766bdc6c'
    or (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_proc where oid=to_regprocedure(
      'app_private.require_superadmin_internal_context(text)'))
      is distinct from '5cdb28081d40e15232ef50912edd8082' then
    raise exception using errcode='55000',message='Models nominal baseline drift';
  end if;
  if (select count(*) from pg_attribute a where a.attrelid in(
      'public.platform_permissions'::regclass,'public.institution_permissions'::regclass)
      and a.attname in('module_label','screen_label','action_label') and a.attnotnull
      and not a.attisdropped and not a.atthasdef) <> 6 then
    raise exception using errcode='55000',message='Models nominal requires NOT NULL labels without replay defaults';
  end if;
end
$nominal_preflight$;
