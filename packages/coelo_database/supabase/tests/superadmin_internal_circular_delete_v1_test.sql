begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select has_function('public','superadmin_circular_delete_v2',
  array['uuid','uuid','bigint'],'internal circular delete RPC exists');
select ok(has_function_privilege(
  'authenticated',
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)',
  'execute'
), 'authenticated can execute the internal delete wrapper');
select ok(not has_function_privilege(
  'anon',
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)',
  'execute'
), 'anon cannot execute the internal delete wrapper');
select ok(not has_function_privilege(
  'service_role',
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)',
  'execute'
), 'service role is not a client bypass');
select ok(position('circulars.manage' in pg_get_functiondef(
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)'::regprocedure
)) > 0, 'delete checks the internal manage capability');
select ok(position('deleted_at' in pg_get_functiondef(
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)'::regprocedure
)) > 0, 'delete is logical');
select ok(position('superadmin_circular_command_receipts' in pg_get_functiondef(
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)'::regprocedure
)) > 0, 'delete is idempotent through the internal receipt ledger');
select ok(position('request_hash' in pg_get_functiondef(
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)'::regprocedure
)) > 0, 'reused request ids are fingerprinted');
select ok(position('circular_deleted' in pg_get_functiondef(
  'public.superadmin_circular_delete_v2(uuid,uuid,bigint)'::regprocedure
)) > 0, 'delete is audited');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='app_private.superadmin_circular_command_receipts'::regclass
    and pg_get_constraintdef(oid) like '%delete%'
), 'the internal receipt ledger accepts delete commands');

select * from finish();
rollback;
