-- Prova do pacote 20260910240500: anon sem privilegio direto nos schemas da
-- aplicacao; authenticated e service_role preservados.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

select is((select count(*) from information_schema.role_table_grants
  where grantee='anon' and table_schema in ('public','app_private','audit','analytics')), 0::bigint,
  'anon has no table privilege in the application schemas');
select is((select count(*) from information_schema.role_usage_grants
  where grantee='anon' and object_type='SEQUENCE'
    and object_schema in ('public','app_private','audit','analytics')), 0::bigint,
  'anon has no sequence privilege in the application schemas');
select is((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','app_private','audit','analytics')
    and has_function_privilege('anon',p.oid,'execute')), 0::bigint,
  'anon cannot execute any function in the application schemas');
select is((select count(*) from pg_policies where roles::text like '%anon%'), 0::bigint,
  'no policy targets anon');

-- O que os clientes autenticados usam continua igual.
select ok(has_table_privilege('authenticated','public.institutions','select'),
  'authenticated keeps select on institutions');
select ok(has_function_privilege('authenticated','public.superadmin_chat_inbox_v2(timestamptz,uuid,integer,text,boolean)','execute'),
  'authenticated keeps execute on the chat gateway');
select ok(has_function_privilege('authenticated','public.superadmin_internal_users_list(text,uuid[],text[],text[],integer,integer)','execute'),
  'authenticated keeps execute on an internal directory RPC');
select ok(has_table_privilege('service_role','public.people','select')
  and has_table_privilege('service_role','public.people','insert'),
  'service_role keeps its privileges');
select ok((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and has_function_privilege('authenticated',p.oid,'execute')) > 300,
  'authenticated still executes the public RPC surface');

select * from finish();
rollback;
