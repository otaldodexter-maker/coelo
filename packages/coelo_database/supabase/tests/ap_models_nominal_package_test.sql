-- Pacote nominal de Modelos de acesso: asserções de pós-aplicação.
--
-- Até 10/09/2026 este arquivo carregava, embutido, o candidato
-- AP-MODELS-NOMINAL-20260909-v1 (fixture do cursor legado de produção +
-- 20260901170731 + 193000 + 20260908021821 + 182839 + 20260909174500 +
-- revoke de export/import) seguido destas oito asserções. Desde a baseline de
-- produção 20260910000000 o pacote vive em
-- candidatos/acessos-pessoas/20260910171300_access_profile_models_catalog_v2_baseline.sql
-- e é aplicado com psql ANTES deste teste. O preflight embutido (md5 do cursor
-- legado, ausência de access_profile_require_model_action) contradizia o
-- estado pós-pacote e os `alter table ... drop default` iniciais rodavam fora
-- de transação, alterando o espelho; por isso o trecho foi removido.
-- Somente as asserções, inalteradas, permanecem.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);
select ok(to_regprocedure('app_private.access_profile_require_model_action(text,text,boolean)') is not null,
  'nominal package persists internal Models foundation after commit');
select ok(not has_function_privilege('authenticated',
  'public.superadmin_access_profile_models_export(text)','execute'), 'MVP export remains unavailable by direct RPC');
select ok(not has_function_privilege('authenticated',
  'public.superadmin_access_profile_models_import_preview(text,jsonb)','execute'), 'MVP import preview remains unavailable by direct RPC');
select ok(not has_function_privilege('authenticated',
  'public.superadmin_access_profile_models_import_confirm(uuid,text,jsonb,text)','execute'), 'MVP import confirm remains unavailable by direct RPC');
select ok(has_function_privilege('authenticated',
  'public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)','execute')
  and not has_function_privilege('service_role',
  'public.superadmin_access_profile_models_cursor(text,text,text,text,integer,text,uuid)','execute'),
  'reader uses authenticated API without service-role gateway');
select ok(not has_function_privilege('authenticated',
  'app_private.access_profile_require_model_action(text,text,boolean)','execute'),
  'private authorization helper stays inaccessible to client');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid='app_private.access_profile_model_command_receipts'::regclass), 'receipts remain forced RLS');
select is((select count(*) from pg_attribute a where a.attrelid in(
  'public.platform_permissions'::regclass,'public.institution_permissions'::regclass)
  and a.attname in('module_label','screen_label','action_label') and a.attnotnull
  and not a.attisdropped and not a.atthasdef),6::bigint,'package requires and preserves actual label constraints');
select * from finish();
rollback;
