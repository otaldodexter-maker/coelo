-- Nominal catalog gate for AgendaReadContractRed53; no application calls or data.
begin;
reset role;
create extension if not exists pgtap with schema extensions;
select plan(10);
select is(current_user::text,'postgres','AG catalog gate runs as postgres');
select ok(to_regtype('auth.aal_level') is not null,'real Auth aal_level exists');
select ok(coalesce((select array_agg(enumlabel::text order by enumsortorder) @> array['aal1','aal2']
  from pg_enum where enumtypid=to_regtype('auth.aal_level')),false),'Auth enum includes aal1 and aal2');
select ok(exists(select 1 from pg_attribute where attrelid=to_regclass('auth.sessions')
  and attname='aal' and not attisdropped and atttypid=to_regtype('auth.aal_level')),
  'auth.sessions.aal uses the real Auth enum');
select ok(to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)') is not null,
  'exact audit14 appender exists');
select ok(exists(select 1 from pg_proc p where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)')
  and p.pronargs=14 and p.prorettype='uuid'::regtype),'audit14 has exact arity and UUID return');
select ok(exists(select 1 from pg_proc p join pg_roles r on r.oid=p.proowner
  where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)')
  and r.rolname='postgres' and p.prosecdef and p.provolatile='v'),
  'audit14 is postgres-owned volatile SECURITY DEFINER');
select ok(exists(select 1 from pg_proc p where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)')
  and p.proconfig @> array['search_path=""']),'audit14 fixes an empty search_path');
select ok(exists(select 1 from pg_proc p where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)')
  and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where a.grantee=0 and a.privilege_type='EXECUTE')),'audit14 excludes PUBLIC EXECUTE');
select ok(coalesce((select count(*)=3 and bool_and(not has_function_privilege(r.oid,p.oid,'EXECUTE'))
  from pg_proc p cross join pg_roles r where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)')
    and r.rolname in('anon','authenticated','service_role')),false),'all three API roles lack effective audit14 EXECUTE');
select diag(jsonb_build_object(
  'probe','agenda_auth_audit14',
  'current_user',current_user,
  'server_version_num',current_setting('server_version_num')::integer,
  'auth_enum_oid',to_regtype('auth.aal_level')::oid,
  'auth_enum_labels',(select jsonb_agg(enumlabel::text order by enumsortorder) from pg_enum where enumtypid=to_regtype('auth.aal_level')),
  'auth_session_aal_type',(select format_type(atttypid,atttypmod) from pg_attribute where attrelid=to_regclass('auth.sessions') and attname='aal' and not attisdropped),
  'audit14',(select jsonb_build_object(
      'oid',p.oid,'arguments',pg_get_function_identity_arguments(p.oid),
      'return_type',format_type(p.prorettype,null),'owner',r.rolname,
      'security_definer',p.prosecdef,'volatility',p.provolatile,'config',p.proconfig,
      'api_execute',(select jsonb_object_agg(ar.rolname,has_function_privilege(ar.oid,p.oid,'EXECUTE')) from pg_roles ar where ar.rolname in('anon','authenticated','service_role')))
    from pg_proc p join pg_roles r on r.oid=p.proowner where p.oid=to_regprocedure('app_private.audit_append_superadmin_internal(uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,text,uuid,uuid,text,uuid,jsonb)'))
)::text);
select * from finish();
rollback;
