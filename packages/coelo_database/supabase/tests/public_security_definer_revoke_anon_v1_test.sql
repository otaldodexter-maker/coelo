-- Revoke em lote de anon nas funcoes security definer de public
-- (candidato 20260910190900_public_security_definer_revoke_anon_v1).
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

select is(
  (select count(*)::bigint from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')),
  0::bigint,
  'anon nao executa nenhuma funcao security definer de public');

select ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('authenticated', p.oid, 'execute')) >= 199,
  'authenticated mantem os grants explicitos nas funcoes security definer');

select ok(has_function_privilege('authenticated', 'public.superadmin_auth_bootstrap_context()', 'execute'),
  'bootstrap do contexto interno continua com authenticated');
select ok(has_function_privilege('authenticated', 'public.list_visible_happens_feed(uuid,uuid,uuid,uuid,timestamptz,text,uuid,integer)', 'execute'),
  'feed misto do Acontece continua com authenticated');
select ok(has_function_privilege('service_role', 'public.redeem_happens_media_read_ticket(uuid,uuid)', 'execute'),
  'resgate de ticket de midia continua com service_role');
select ok(not has_function_privilege('anon', 'public.superadmin_auth_bootstrap_context()', 'execute'),
  'anon nao chama o bootstrap do contexto interno');

select ok(not exists(
  select 1 from pg_default_acl d join pg_roles r on r.oid = d.defaclrole join pg_namespace n on n.oid = d.defaclnamespace
  where r.rolname = 'postgres' and n.nspname = 'public' and d.defaclobjtype = 'f'
    and array_to_string(d.defaclacl, ',') like '%anon=%'),
  'funcoes futuras de postgres em public nao nascem executaveis por anon');

select * from finish();
rollback;
