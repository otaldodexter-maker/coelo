-- Seguranca basica (ADR 0034, revisao profunda antecipada): anon deixa de ter
-- privilegio direto em tabelas, sequencias e funcoes dos schemas da aplicacao.
--
-- Medido em producao em 10/09/2026 22:40 (somente leitura):
--   - public: 30 tabelas com grants a anon (24 delas com ALL, inclusive
--     DELETE/TRUNCATE), 1 sequencia; RLS ligada barrava, mas o grant nao
--     deveria existir (mesmo achado de Cardapios e do chat em 240000);
--   - public: 0 de 393 funcoes executaveis por anon (toda migration revoga de
--     PUBLIC explicitamente); no Postgres local os privilegios padrao do
--     Supabase dao execute a anon em 205 funcoes, e este pacote alinha os dois;
--   - app_private: 15 funcoes executaveis por anon (11 triggers de validacao,
--     4 helpers security definer); anon nao tem USAGE no schema, entao o
--     caminho estava fechado, mas o privilegio e removido mesmo assim;
--   - nenhuma policy `to anon`; as policies `{public}` de meal_plans dependem
--     de pessoa autenticada. O Superadmin nao le tabela nem chama RPC antes da
--     sessao; o Site nao usa Supabase.
-- Fora do pacote: storage, realtime e cron (schemas da plataforma) e os
-- privilegios padrao (ALTER DEFAULT PRIVILEGES): o teste no descartavel mostrou
-- que nao impedem o EXECUTE via PUBLIC em funcao nova; a regra continua sendo
-- o revoke explicito em cada migration.
-- Idempotente e presence-based: revoga o que existir, sem grant novo.
begin;

do $$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message='anon revoke migration must run as postgres';
  end if;
end
$$;

revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public from anon;

do $$
declare s text;
begin
  foreach s in array array['app_private','audit','analytics'] loop
    if exists(select 1 from pg_namespace where nspname=s) then
      execute format('revoke all on all tables in schema %I from anon', s);
      execute format('revoke all on all sequences in schema %I from anon', s);
      execute format('revoke execute on all functions in schema %I from anon', s);
    end if;
  end loop;
end
$$;

-- Funcao que anon ainda executa herda o EXECUTE de PUBLIC (acl nula ou `=X`):
-- em producao sao as 15 de app_private. Revogar de anon nao basta; revoga-se
-- de PUBLIC e devolve-se, explicitamente, o que authenticated e service_role
-- tinham de fato, para nada alem de anon mudar.
do $$
declare f record; had_authenticated boolean; had_service_role boolean;
begin
  for f in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','app_private','audit','analytics')
      and p.prokind='f'
      and has_function_privilege('anon',p.oid,'execute')
  loop
    had_authenticated := has_function_privilege('authenticated',f.signature,'execute');
    had_service_role := has_function_privilege('service_role',f.signature,'execute');
    execute format('revoke all on function %s from public, anon', f.signature);
    if had_authenticated then
      execute format('grant execute on function %s to authenticated', f.signature);
    end if;
    if had_service_role then
      execute format('grant execute on function %s to service_role', f.signature);
    end if;
  end loop;
end
$$;

commit;
