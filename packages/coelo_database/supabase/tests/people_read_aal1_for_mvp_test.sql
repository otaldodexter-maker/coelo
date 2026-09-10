-- Prova do candidato 20260910120000_people_read_aal1_for_mvp.sql.
--
-- O que precisa ficar provado, nesta ordem de importancia:
--   1. a LEITURA passa em AAL1 (o defeito que a migration resolve);
--   2. toda ESCRITA continua negada em AAL1 (o risco que a migration NAO pode
--      introduzir), inclusive os dois codigos de vinculo que sao faceis de
--      esquecer: people.memberships.manage e people.child_contexts.manage;
--   3. a regra e fail-closed: um codigo NOVO, que ninguem lembrou de listar,
--      continua exigindo AAL2;
--   4. AAL2 continua funcionando para tudo;
--   5. sem permissao, nega em qualquer AAL, e a mensagem de negativa por
--      permissao nao se confunde com a de MFA.
--
-- Fixture sintetica, tudo em transacao com rollback. Nenhuma conta real.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- ---------------------------------------------------------------- fixture
insert into public.people(id, person_type, first_name, last_name, display_name)
values
  ('aa100000-0000-4000-8000-000000000001', 'adult', 'AAL', 'Leitor', 'AAL Leitor'),
  ('aa100000-0000-4000-8000-000000000002', 'adult', 'AAL', 'Sem Permissao', 'AAL Sem Permissao');

insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
                       raw_app_meta_data, raw_user_meta_data)
values
  ('aa110000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'aal-leitor@invalid.test', now(), now(), now(), '{}', '{}'),
  ('aa110000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'aal-sem-permissao@invalid.test', now(), now(), now(), '{}', '{}');

insert into public.person_auth_links(id, person_id, auth_user_id, status, linked_at)
values
  ('aa120000-0000-4000-8000-000000000001', 'aa100000-0000-4000-8000-000000000001',
   'aa110000-0000-4000-8000-000000000001', 'active', now()),
  ('aa120000-0000-4000-8000-000000000002', 'aa100000-0000-4000-8000-000000000002',
   'aa110000-0000-4000-8000-000000000002', 'active', now());

-- Um codigo novo, para provar que a regra e fail-closed por construcao.
insert into public.platform_permissions(
  code, module_code, module_label, screen_code, screen_label, action_code, action_label,
  description, risk_level, requires_mfa, status
) values (
  'people.synthetic_future', 'platform', 'Superadmin', 'people', 'Pessoas',
  'synthetic_future', 'Sintetico futuro',
  'Codigo sintetico do teste: prova que um codigo novo continua exigindo AAL2.',
  'high', true, 'active'
);

insert into public.platform_roles(id, code, name, max_scope_kind)
values ('aa130000-0000-4000-8000-000000000001', 'aal_people_probe', 'AAL people probe', 'platform');

insert into public.platform_role_permissions(role_id, permission_id, effect)
select 'aa130000-0000-4000-8000-000000000001', id, 'allow'
from public.platform_permissions
where code in ('people.read', 'people.create', 'people.update',
               'people.memberships.manage', 'people.child_contexts.manage',
               'people.synthetic_future');

insert into public.platform_memberships(id, person_id, role_id, scope_kind, status)
values ('aa140000-0000-4000-8000-000000000001', 'aa100000-0000-4000-8000-000000000001',
        'aa130000-0000-4000-8000-000000000001', 'platform', 'active');

-- Coleta o resultado de cada tentativa sem abortar a transacao.
create temporary table aal_probe(caso text primary key, erro text);

create function pg_temp.probe(p_caso text, p_code text) returns void
language plpgsql as $probe$
begin
  begin
    perform app_private.assert_people_permission(p_code);
    insert into aal_probe values (p_caso, null);
  exception when others then
    insert into aal_probe values (p_caso, sqlerrm);
  end;
end
$probe$;

-- --------------------------------------------------------- ator AAL1 com permissao
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', 'aa110000-0000-4000-8000-000000000001',
  'aal', 'aal1', 'role', 'authenticated')::text, true);

select pg_temp.probe('aal1_read', 'people.read');
select pg_temp.probe('aal1_create', 'people.create');
select pg_temp.probe('aal1_update', 'people.update');
select pg_temp.probe('aal1_memberships', 'people.memberships.manage');
select pg_temp.probe('aal1_child_contexts', 'people.child_contexts.manage');
select pg_temp.probe('aal1_codigo_novo', 'people.synthetic_future');

-- --------------------------------------------------------- ator AAL2 com permissao
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', 'aa110000-0000-4000-8000-000000000001',
  'aal', 'aal2', 'role', 'authenticated')::text, true);

select pg_temp.probe('aal2_read', 'people.read');
select pg_temp.probe('aal2_create', 'people.create');
select pg_temp.probe('aal2_memberships', 'people.memberships.manage');

-- --------------------------------------------------------- ator sem permissao
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', 'aa110000-0000-4000-8000-000000000002',
  'aal', 'aal1', 'role', 'authenticated')::text, true);

select pg_temp.probe('sem_permissao_aal1_read', 'people.read');

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', 'aa110000-0000-4000-8000-000000000002',
  'aal', 'aal2', 'role', 'authenticated')::text, true);

select pg_temp.probe('sem_permissao_aal2_read', 'people.read');

-- --------------------------------------------------------- sem sessao
select set_config('request.jwt.claims', '{}', true);
select pg_temp.probe('anonimo_read', 'people.read');

-- ---------------------------------------------------------------- assercoes
select is(
  (select erro from aal_probe where caso = 'aal1_read'), null,
  'AAL1 com people.read passa: e isto que faz o diretorio de Pessoas abrir no MVP'
);
select is(
  (select erro from aal_probe where caso = 'aal1_create'), 'people permission requires aal2',
  'AAL1 continua negado em people.create'
);
select is(
  (select erro from aal_probe where caso = 'aal1_update'), 'people permission requires aal2',
  'AAL1 continua negado em people.update'
);
select is(
  (select erro from aal_probe where caso = 'aal1_memberships'), 'people permission requires aal2',
  'AAL1 continua negado em people.memberships.manage'
);
select is(
  (select erro from aal_probe where caso = 'aal1_child_contexts'), 'people permission requires aal2',
  'AAL1 continua negado em people.child_contexts.manage'
);
select is(
  (select erro from aal_probe where caso = 'aal1_codigo_novo'), 'people permission requires aal2',
  'a regra e fail-closed: um codigo novo continua exigindo AAL2 sem ninguem lembrar dele'
);
select is(
  (select erro from aal_probe where caso = 'aal2_read'), null,
  'AAL2 com people.read continua passando'
);
select is(
  (select erro from aal_probe where caso = 'aal2_create'), null,
  'AAL2 com people.create continua passando'
);
select is(
  (select erro from aal_probe where caso = 'aal2_memberships'), null,
  'AAL2 com people.memberships.manage continua passando'
);
select is(
  (select erro from aal_probe where caso = 'sem_permissao_aal1_read'), 'people permission denied',
  'sem a permissao, AAL1 nega por PERMISSAO e nao por MFA'
);
select is(
  (select erro from aal_probe where caso = 'sem_permissao_aal2_read'), 'people permission denied',
  'sem a permissao, nem AAL2 abre a leitura'
);
select is(
  (select erro from aal_probe where caso = 'anonimo_read'), 'people permission denied',
  'sem sessao, nega'
);

-- A migration nao pode ter afrouxado a superficie da funcao.
select ok(
  not pg_catalog.has_function_privilege(
    'authenticated', 'app_private.assert_people_permission(text)', 'EXECUTE')
  and not pg_catalog.has_function_privilege(
    'anon', 'app_private.assert_people_permission(text)', 'EXECUTE'),
  'o portao continua fora do alcance de anon e authenticated'
);
select ok(
  (select prosecdef and provolatile = 's'
     and coalesce(proconfig, array[]::text[]) @> array['search_path=""']::text[]
   from pg_catalog.pg_proc
   where oid = pg_catalog.to_regprocedure('app_private.assert_people_permission(text)')),
  'o portao continua security definer, stable e com search_path vazio'
);

select finish();
rollback;
