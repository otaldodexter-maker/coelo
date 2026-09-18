-- ADR0031/current MVP: these operations remain unavailable, including direct RPC.
revoke all on function
  public.superadmin_access_profile_models_export(text),
  public.superadmin_access_profile_models_import_preview(text,jsonb),
  public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)
from public,anon,authenticated,service_role;

do $nominal_postflight$
declare item record; deferred boolean;
begin
  for item in select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in('public','app_private') and (
      p.proname like 'access_profile_model_%' or p.proname like 'superadmin_access_profile_model%'
      or p.proname in('access_profile_require_model_action','access_profile_require_any_model_read',
                     'superadmin_access_permission_catalog'))
  loop
    deferred := item.proname in('superadmin_access_profile_models_export',
      'superadmin_access_profile_models_import_preview','superadmin_access_profile_models_import_confirm');
    if item.proowner <> 'postgres'::regrole
      or item.proconfig is distinct from array['search_path=""']::text[]
      or exists(select 1 from aclexplode(coalesce(item.proacl,acldefault('f',item.proowner))) a
        where a.grantee <> item.proowner and (item.nspname <> 'public' or deferred
          or a.grantee <> 'authenticated'::regrole or a.is_grantable))
      or (item.nspname='public' and not deferred and
        not has_function_privilege('authenticated',item.oid,'EXECUTE')) then
      raise exception using errcode='55000',message='Models nominal function metadata/ACL drift';
    end if;
  end loop;
  if not exists(select 1 from pg_class where oid='app_private.access_profile_model_command_receipts'::regclass
    and relrowsecurity and relforcerowsecurity) then
    raise exception using errcode='55000',message='Models receipts RLS required';
  end if;
end
$nominal_postflight$;
