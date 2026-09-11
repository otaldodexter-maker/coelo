-- R05 realm-interno (2): revoke de INSERT/UPDATE/DELETE/SELECT de `authenticated`
-- em tabelas com RLS ligada e sem policy para o comando.
--
-- Continuacao dos pacotes 240500 (anon) e 240600 (TRUNCATE/REFERENCES/TRIGGER)
-- e da varredura docs/reviews/evidence/etapa-2/r04-realm-interno/
-- varredura-authenticated-2026-09-11.md (producao em 11/09: INSERT 23,
-- UPDATE 26, DELETE 18, SELECT 7 objetos sem policy; 0 tabelas com RLS
-- desligada e grant).
--
-- Regra aplicada, calculada no momento da aplicacao (presence-based, idempotente):
--   * tabela (relkind r/p) em public/app_private/audit/analytics, com RLS
--     ligada, com grant de um comando a `authenticated` e sem policy
--     (cmd igual ou ALL, roles contendo authenticated ou {public}) -> revoke
--     desse comando. RLS ja negava; a negacao passa a ocorrer no privilegio.
--   * view (relkind v/m): revoke de INSERT/UPDATE/DELETE (view nao tem policy;
--     escrita por view cai no RLS das bases). SELECT das views e mantido: o
--     RLS das tabelas base decide (security_invoker).
--   * tabela com RLS desligada e grant: NAO tocada; apenas listada em NOTICE
--     para a revisao profunda (producao: nenhuma em 11/09).
--   * excecao unica: public.person_auth_links ganha a policy
--     person_auth_links_self_read (person_id = app_private.current_person_id())
--     antes da varredura, para que person_directory.has_active_login deixe de
--     sair sempre false em leitura direta; o SELECT dela fica.
--   * nenhum grant novo e concedido (as policies permissivas sem grant da
--     Tabela C continuam mortas de proposito: escrita e por RPC).
--
-- Neutralidade: todas as escritas do cliente passam por RPCs security definer
-- de dono postgres (BYPASSRLS), que nao dependem de grant de authenticated.
-- O Dart so usa .from() em profile_about_* (que tem policies proprias).
--
-- Reversao: nao ha grant a devolver automaticamente; o dump do lote guarda
-- os ACLs anteriores.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

do $preflight$
begin
  if current_user <> 'postgres' then
    raise insufficient_privilege using message = 'revoke package must run as postgres';
  end if;
  if to_regclass('public.person_auth_links') is null
    or to_regprocedure('app_private.current_person_id()') is null then
    raise object_not_in_prerequisite_state using message = 'person_auth_links and current_person_id are required';
  end if;
end
$preflight$;

-- person_auth_links: leitura da propria linha (antes da varredura)
do $policy$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'person_auth_links'
      and policyname = 'person_auth_links_self_read'
  ) then
    create policy person_auth_links_self_read on public.person_auth_links
      for select to authenticated
      using (person_id = app_private.current_person_id());
  end if;
end
$policy$;

do $revoke$
declare
  before_count integer;
  after_count integer;
  rls_off text;
  target record;
begin
  create temporary table revoke_targets on commit drop as
  with grants as (
    select g.table_schema as s, g.table_name as t, g.privilege_type as cmd
    from information_schema.role_table_grants g
    where g.grantee = 'authenticated'
      and g.table_schema in ('public','app_private','audit','analytics')
      and g.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
  ),
  policies as (
    select p.schemaname as s, p.tablename as t, p.cmd, p.roles
    from pg_policies p
    where p.schemaname in ('public','app_private','audit','analytics')
  ),
  meta as (
    select n.nspname as s, c.relname as t, c.relkind, c.relrowsecurity as rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public','app_private','audit','analytics')
      and c.relkind in ('r','p','v','m')
  )
  select m.s, m.t, m.relkind, m.rls, grants.cmd
  from grants
  join meta m on m.s = grants.s and m.t = grants.t
  where not exists (
    select 1 from policies p
    where p.s = grants.s and p.t = grants.t
      and (p.cmd = grants.cmd or p.cmd = 'ALL')
      and ('authenticated' = any(p.roles) or p.roles = '{public}'::name[])
  );

  select count(*) into before_count from revoke_targets;

  select string_agg(s || '.' || t || ':' || cmd, ', ' order by s, t, cmd) into rls_off
  from revoke_targets where relkind in ('r','p') and not rls;
  if rls_off is not null then
    raise notice 'tabelas com RLS desligada e grant a authenticated (nao tocadas): %', rls_off;
  end if;

  for target in
    select s, t, cmd from revoke_targets
    where (relkind in ('r','p') and rls)
       or (relkind in ('v','m') and cmd in ('INSERT','UPDATE','DELETE'))
    order by s, t, cmd
  loop
    execute format('revoke %s on table %I.%I from authenticated', target.cmd, target.s, target.t);
  end loop;

  select count(*) into after_count
  from information_schema.role_table_grants g
  join pg_class c on c.relname = g.table_name
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = g.table_schema
  where g.grantee = 'authenticated'
    and g.table_schema in ('public','app_private','audit','analytics')
    and g.privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
    and c.relkind in ('r','p') and c.relrowsecurity
    and not exists (
      select 1 from pg_policies p
      where p.schemaname = g.table_schema and p.tablename = g.table_name
        and (p.cmd = g.privilege_type or p.cmd = 'ALL')
        and ('authenticated' = any(p.roles) or p.roles = '{public}'::name[])
    );

  raise notice 'grants de authenticated sem policy: % antes (tabelas e views), % depois (tabelas com RLS)',
    before_count, after_count;
  if after_count <> 0 then
    raise exception 'revoke package left % grants without policy', after_count;
  end if;
end
$revoke$;

commit;
