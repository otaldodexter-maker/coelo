begin;
create extension if not exists pgtap with schema extensions;
select plan(4);
select ok(has_table_privilege('authenticated','public.plans','select')
  and not has_table_privilege('authenticated','public.plans','insert')
  and not has_table_privilege('authenticated','public.plans','update')
  and not has_table_privilege('authenticated','public.plans','delete'),'authenticated so le plans');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.plans'::regclass),'RLS forcada em plans');
-- sessao autenticada sem platform.read: a view responde (sem erro de privilegio) e sem linhas de plano visiveis
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
set local role authenticated;
select lives_ok($$select count(*) from public.institution_directory$$,'institution_directory nao falha mais por privilegio em plans');
select is((select count(*) from public.plans),0::bigint,'sem platform.read nenhuma linha de plans e visivel');
reset role;
select * from finish();
rollback;
