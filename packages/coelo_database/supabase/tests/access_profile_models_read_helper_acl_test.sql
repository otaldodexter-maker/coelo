-- Nominal Models READ helper catalog proof for the coordinated GREEN50 replay.
-- All TAP and catalog assertions run after RESET ROLE; API privileges are inspected,
-- never granted, and this fixture does not call the private helper.
begin;
reset role;
create extension if not exists pgtap with schema extensions;
select plan(10);

select is(current_user::text,'postgres','helper ACL assertions run as postgres');
select ok(
  pg_catalog.to_regprocedure('app_private.access_profile_require_any_model_read()') is not null,
  'the nominal Models READ helper exists');
select is(
  (select pg_catalog.pg_get_userbyid(procedure_record.proowner)::text
   from pg_catalog.pg_proc procedure_record
   where procedure_record.oid=pg_catalog.to_regprocedure(
     'app_private.access_profile_require_any_model_read()')),
  'postgres','the Models READ helper is owned by postgres');
select ok(coalesce(
  (select procedure_record.prosecdef
   from pg_catalog.pg_proc procedure_record
   where procedure_record.oid=pg_catalog.to_regprocedure(
     'app_private.access_profile_require_any_model_read()')),false),
  'the Models READ helper is SECURITY DEFINER');
select is(
  (select procedure_record.provolatile::text
   from pg_catalog.pg_proc procedure_record
   where procedure_record.oid=pg_catalog.to_regprocedure(
     'app_private.access_profile_require_any_model_read()')),
  's','the Models READ helper is STABLE');
select ok(coalesce(
  (select procedure_record.proconfig=array['search_path=""']::text[]
   from pg_catalog.pg_proc procedure_record
   where procedure_record.oid=pg_catalog.to_regprocedure(
     'app_private.access_profile_require_any_model_read()')),false),
  'the Models READ helper has an empty search_path');
select ok(coalesce(
  (select not exists(
     select 1
     from pg_catalog.aclexplode(coalesce(
       procedure_record.proacl,
       pg_catalog.acldefault('f',procedure_record.proowner))) privilege_record
     where privilege_record.grantee=0 and privilege_record.privilege_type='EXECUTE')
   from pg_catalog.pg_proc procedure_record
   where procedure_record.oid=pg_catalog.to_regprocedure(
     'app_private.access_profile_require_any_model_read()')),false),
  'PUBLIC has no EXECUTE on the Models READ helper');
select ok(not coalesce(pg_catalog.has_function_privilege('anon',
  pg_catalog.to_regprocedure('app_private.access_profile_require_any_model_read()'),'EXECUTE'),true),
  'anon has no effective EXECUTE on the Models READ helper');
select ok(not coalesce(pg_catalog.has_function_privilege('authenticated',
  pg_catalog.to_regprocedure('app_private.access_profile_require_any_model_read()'),'EXECUTE'),true),
  'authenticated has no effective EXECUTE on the Models READ helper');
select ok(not coalesce(pg_catalog.has_function_privilege('service_role',
  pg_catalog.to_regprocedure('app_private.access_profile_require_any_model_read()'),'EXECUTE'),true),
  'service_role has no effective EXECUTE on the Models READ helper');

select * from finish();
rollback;
