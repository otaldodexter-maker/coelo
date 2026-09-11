-- Seguranca basica (ADR 0034; achado da R04 em 10/09/2026): anon tinha EXECUTE
-- em 199 funcoes SECURITY DEFINER do schema public na baseline de producao.
--
-- Causa raiz: o privilegio padrao do Supabase para o papel postgres em public
-- concede EXECUTE em toda funcao nova a anon, authenticated e service_role
-- (baseline, ALTER DEFAULT PRIVILEGES ... GRANT ALL ON FUNCTIONS TO "anon").
-- As migrations revogam de PUBLIC, mas o grant explicito a anon sobrevive.
-- Nenhuma dessas funcoes e chamada sem sessao: todas exigem auth.uid() ou o
-- worker (service_role). O cliente Superadmin usa a chave publicavel so para
-- autenticar; depois disso o papel e authenticated.
--
-- Forward-only e decidido por presenca: revoga de anon toda funcao security
-- definer de public que anon ainda execute, e muda o privilegio padrao para as
-- funcoes futuras nao nascerem com anon. authenticated e service_role mantem
-- os grants explicitos que ja tem (0 funcoes dependiam so de PUBLIC).
-- Funcoes SECURITY INVOKER ficam fora deste pacote (12 na baseline): sao
-- guardadas por RLS e podem ter uso legitimo em policies; registradas como
-- pendencia para a revisao profunda.
begin;

do $$
declare
  target record;
  revoked integer := 0;
begin
  for target in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and has_function_privilege('anon', p.oid, 'execute')
  loop
    execute format('revoke execute on function %s from anon', target.signature);
    revoked := revoked + 1;
  end loop;
  raise notice 'public security definer: EXECUTE revogado de anon em % funcoes', revoked;
end $$;

-- Funcoes novas criadas por postgres em public deixam de nascer executaveis
-- por anon; quem precisar de anon concede explicitamente na propria migration.
alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

commit;
