begin;
create extension if not exists pgtap with schema extensions;
select plan(2);
select ok(to_regprocedure('public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)') is not null,
  'chat thread contract remains available');
select ok(position('asset_id' in pg_get_functiondef(
  'public.superadmin_chat_thread_v2(uuid,timestamptz,uuid,integer)'::regprocedure)) > 0,
  'chat thread envelope exposes the catalog identity as asset_id');
select * from finish();
rollback;
