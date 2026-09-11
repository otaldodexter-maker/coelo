-- Prova do pacote 20260910240600: authenticated sem TRUNCATE/REFERENCES/TRIGGER
-- nos schemas da aplicacao; leitura e escrita por RLS preservadas.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select is((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and privilege_type in ('TRUNCATE','REFERENCES','TRIGGER')
    and table_schema in ('public','app_private','audit','analytics')), 0::bigint,
  'authenticated has no TRUNCATE, REFERENCES or TRIGGER privilege in the application schemas');
select ok(not has_table_privilege('authenticated','public.people','truncate')
  and not has_table_privilege('authenticated','public.messages','truncate')
  and not has_table_privilege('authenticated','public.institutions','truncate'),
  'people, messages and institutions cannot be truncated by an authenticated session');
select ok(has_table_privilege('authenticated','public.people','select')
  and has_table_privilege('authenticated','public.messages','select')
  and has_table_privilege('authenticated','public.institutions','select'),
  'authenticated keeps select (RLS decides the rows)');
select ok(has_table_privilege('authenticated','public.conversation_participants','insert'),
  'authenticated keeps the insert grants that policies rely on');
select ok(has_table_privilege('service_role','public.people','truncate'),
  'service_role (server-only) is untouched');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and privilege_type='SELECT') > 100,
  'the authenticated select surface is intact');

select * from finish();
rollback;
