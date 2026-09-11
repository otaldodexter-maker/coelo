-- Prova da migration 20260910230021_mfa_fora_do_mvp_v1 (ADR 0034, Decisao 12).
-- Catalogo sem requires_mfa e portao has_mfa_aal2 aceitando aal1; anonimo e sem JWT continuam negados.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

select is((select count(*) from public.platform_permissions where requires_mfa), 0::bigint,
  'platform_permissions: nenhuma capacidade exige MFA');
select is((select count(*) from public.institution_permissions where requires_mfa), 0::bigint,
  'institution_permissions: nenhuma capacidade exige MFA');
select is((select count(*) from public.guardian_permission_capabilities where requires_mfa), 0::bigint,
  'guardian_permission_capabilities: nenhuma capacidade exige MFA');
select ok((select count(*) from public.platform_permissions where status = 'active') > 0,
  'catalogo de plataforma continua populado');

select set_config('request.jwt.claims', '', true);
select ok(not app_private.has_mfa_aal2(), 'sem JWT o portao nega');

select set_config('request.jwt.claims',
  jsonb_build_object('sub', '00000000-0000-4000-8000-000000000001', 'role', 'authenticated')::text, true);
select ok(not app_private.has_mfa_aal2(), 'JWT sem claim aal nega');

select set_config('request.jwt.claims',
  jsonb_build_object('sub', '00000000-0000-4000-8000-000000000001', 'aal', 'aal1', 'role', 'authenticated')::text, true);
select ok(app_private.has_mfa_aal2(), 'aal1 satisfaz o portao no MVP');

select set_config('request.jwt.claims',
  jsonb_build_object('sub', '00000000-0000-4000-8000-000000000001', 'aal', 'aal2', 'role', 'authenticated')::text, true);
select ok(app_private.has_mfa_aal2(), 'aal2 continua satisfazendo o portao');

select ok(not has_function_privilege('anon', 'app_private.has_mfa_aal2()', 'execute'),
  'anon nao executa has_mfa_aal2');
select ok((select provolatile = 's' and not prosecdef from pg_proc
  where oid = 'app_private.has_mfa_aal2()'::regprocedure),
  'has_mfa_aal2 continua stable e sem security definer');

select * from finish();
rollback;
