-- pgTAP: app_private.access_profile_detail_v3 e o wrapper
-- public.superadmin_access_profile_detail (candidato
-- candidatos/acessos-pessoas/20260910171700_access_profile_detail_v3_draft_and_matrix.sql).
-- Transacao com rollback; fixtures sinteticas, sem dados reais.
begin;

create extension if not exists pgtap with schema extensions;

select plan(37);

-- ---------------------------------------------------------------------------
-- Contrato estrutural e ACL
-- ---------------------------------------------------------------------------
select has_function('app_private', 'access_profile_detail_v3', array['text', 'uuid'],
  'v3 existe em app_private');
select function_returns('app_private', 'access_profile_detail_v3', array['text', 'uuid'], 'jsonb',
  'v3 devolve jsonb');
select ok(
  (select procedure.prosecdef and procedure.provolatile = 's'
      and procedure.proconfig @> array['search_path=""']
     from pg_proc procedure
    where procedure.oid = 'app_private.access_profile_detail_v3(text,uuid)'::regprocedure),
  'v3 e stable, security definer e search_path vazio');
select ok(
  pg_get_functiondef('public.superadmin_access_profile_detail(text,uuid)'::regprocedure)
    like '%app_private.access_profile_detail_v3(p_domain, p_profile_id)%',
  'wrapper publico delega a v3');
select ok(
  (select procedure.prosecdef and procedure.provolatile = 's'
      and procedure.proconfig @> array['search_path=""']
     from pg_proc procedure
    where procedure.oid = 'public.superadmin_access_profile_detail(text,uuid)'::regprocedure),
  'wrapper publico continua stable, security definer e search_path vazio');
select ok(not has_function_privilege('anon',
  'public.superadmin_access_profile_detail(text,uuid)', 'EXECUTE'),
  'anon nao executa o wrapper publico');
select ok(has_function_privilege('authenticated',
  'public.superadmin_access_profile_detail(text,uuid)', 'EXECUTE'),
  'authenticated executa o wrapper publico');
select ok(not has_function_privilege('authenticated',
  'app_private.access_profile_detail_v3(text,uuid)', 'EXECUTE'),
  'authenticated nao executa a v3 diretamente');
select has_function('app_private', 'access_profile_detail_v2', array['text', 'uuid'],
  'v2 permanece para save/duplicate/delete');

-- ---------------------------------------------------------------------------
-- Fixtures sinteticas
-- ---------------------------------------------------------------------------
insert into auth.users(id, aud, role, email, email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data)
values ('98000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
  'r04-detail-v3-actor@invalid.test', now(), now(), now(), '{}', '{}');

insert into public.people(id, person_type, first_name, last_name, display_name)
values
  ('98100000-0000-4000-8000-000000000001', 'adult', 'Ator', 'R04', 'Ator R04'),
  ('98100000-0000-4000-8000-000000000002', 'adult', 'Bruna', 'Vinculada', 'Bruna Vinculada'),
  ('98100000-0000-4000-8000-000000000003', 'adult', 'Caio', 'Revogado', 'Caio Revogado');

insert into public.person_auth_links(id, person_id, auth_user_id)
values ('98200000-0000-4000-8000-000000000001',
  '98100000-0000-4000-8000-000000000001', '98000000-0000-4000-8000-000000000001');

-- Perfil do ator: gerencia perfis (platform e institution) e le auditoria.
insert into public.platform_roles(id, code, name, max_scope_kind)
values
  ('98300000-0000-4000-8000-000000000001', 'qa_r04_detail_actor', 'QA R04 ator', 'platform'),
  ('98300000-0000-4000-8000-000000000002', 'qa_r04_detail_target', 'QA R04 alvo', 'platform');

insert into public.platform_role_permissions(role_id, permission_id, effect)
select '98300000-0000-4000-8000-000000000001', id, 'allow'
from public.platform_permissions
where code in ('platform.roles.manage', 'institution.roles.manage', 'audit.read', 'platform.read');

-- Perfil alvo: duas permissoes concedidas.
insert into public.platform_role_permissions(role_id, permission_id, effect)
select '98300000-0000-4000-8000-000000000002', id, 'allow'
from public.platform_permissions
where code in ('platform.read', 'people.create');

insert into public.platform_memberships(id, person_id, role_id, status, scope_kind)
values
  ('98400000-0000-4000-8000-000000000001', '98100000-0000-4000-8000-000000000001',
    '98300000-0000-4000-8000-000000000001', 'active', 'platform'),
  ('98400000-0000-4000-8000-000000000002', '98100000-0000-4000-8000-000000000002',
    '98300000-0000-4000-8000-000000000002', 'active', 'platform');
insert into public.platform_memberships(id, person_id, role_id, status, scope_kind, revoked_at)
values
  ('98400000-0000-4000-8000-000000000003', '98100000-0000-4000-8000-000000000003',
    '98300000-0000-4000-8000-000000000002', 'revoked', 'platform', now());

-- Dominio institution.
insert into public.institutions(id, public_name, slug, status)
values ('98500000-0000-4000-8000-000000000001', 'Escola QA R04', 'escola-qa-r04-detail', 'active');

insert into public.institution_roles(id, institution_id, code, name, max_scope_kind)
values ('98600000-0000-4000-8000-000000000001', '98500000-0000-4000-8000-000000000001',
  'qa_r04_detail_role', 'QA R04 papel', 'institution');

insert into public.institution_role_permissions(role_id, permission_id, effect)
select '98600000-0000-4000-8000-000000000001', id, 'allow'
from public.institution_permissions where code = 'activities.create';
insert into public.institution_role_permissions(role_id, permission_id, effect)
select '98600000-0000-4000-8000-000000000001', id, 'deny'
from public.institution_permissions where code = 'activities.manage';

insert into public.institution_memberships(id, person_id, institution_id, role_code, status)
values ('98700000-0000-4000-8000-000000000001', '98100000-0000-4000-8000-000000000002',
  '98500000-0000-4000-8000-000000000001', 'qa_r04_detail_role', 'active');

insert into public.institution_role_assignments(id, membership_id, role_id, scope_kind, status)
values ('98800000-0000-4000-8000-000000000001', '98700000-0000-4000-8000-000000000001',
  '98600000-0000-4000-8000-000000000001', 'institution', 'active');

create temporary table detail_results(key text primary key, result jsonb not null);
grant select, insert on detail_results to authenticated;

-- ---------------------------------------------------------------------------
-- Sem sessao: nega
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_access_profile_detail('platform', null)$$,
  '42501', 'profile management permission required',
  'sem sessao o rascunho e negado com 42501');
select throws_ok(
  $$select public.superadmin_access_profile_detail('platform', '98300000-0000-4000-8000-000000000002')$$,
  '42501', 'profile management permission required',
  'sem sessao o detalhe e negado com 42501');
reset role;

-- ---------------------------------------------------------------------------
-- Sessao do ator
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', '98000000-0000-4000-8000-000000000001',
  'aal', 'aal1', 'role', 'authenticated')::text, true);
set local role authenticated;

insert into detail_results values
  ('platform_draft', public.superadmin_access_profile_detail('platform', null)),
  ('platform_target', public.superadmin_access_profile_detail('platform',
    '98300000-0000-4000-8000-000000000002')),
  ('institution_draft', public.superadmin_access_profile_detail('institution', null)),
  ('institution_role', public.superadmin_access_profile_detail('institution',
    '98600000-0000-4000-8000-000000000001'));

select throws_ok(
  $$select public.superadmin_access_profile_detail('platform', '00000000-0000-4000-8000-00000000dead')$$,
  'P0002', 'access profile not found', 'id inexistente devolve P0002');
select throws_ok(
  $$select public.superadmin_access_profile_detail('principal', null)$$,
  '22023', 'unsupported profile domain', 'dominio principal nao tem detalhe editavel');
select throws_ok(
  $$select public.superadmin_access_profile_detail('bogus', null)$$,
  '42501', 'profile management permission required',
  'dominio desconhecido e negado antes de qualquer leitura (deny-by-default)');
reset role;

-- Rascunho platform
select is(
  (select result - 'permissions' - 'memberships' - 'audit' from detail_results where key = 'platform_draft'),
  jsonb_build_object('domain', 'platform', 'id', '', 'code', '', 'name', '', 'description', '',
    'status', 'active', 'max_scope_kind', 'platform', 'version', 0, 'is_system', false,
    'membership_count', 0),
  'rascunho platform devolve cabecalho em branco');
select is((select result -> 'memberships' from detail_results where key = 'platform_draft'),
  '[]'::jsonb, 'rascunho platform nao tem vinculos');
select is(
  (select jsonb_array_length(result -> 'permissions') from detail_results where key = 'platform_draft'),
  (select count(*)::int from public.platform_permissions where status = 'active'),
  'rascunho platform traz o catalogo completo de permissoes ativas');
select is(
  (select count(*)::int from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_draft' and (item ->> 'selected')::boolean),
  0, 'rascunho platform nao tem permissao selecionada');
select is(
  (select item ->> 'grantable' from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_draft' and item ->> 'code' = 'platform.roles.manage'),
  'true', 'ator pode conceder permissao que possui');
select is(
  (select item ->> 'grantable' from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_draft' and item ->> 'code' = 'people.create'),
  'false', 'ator nao pode conceder permissao que nao possui');
select is(
  (select item ->> 'unavailable_reason' from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_draft' and item ->> 'code' = 'people.create'),
  'Você não pode conceder uma permissão que não possui.',
  'permissao nao concedivel explica o motivo');
select ok(
  (select bool_and(item ?& array['code', 'module', 'screen_code', 'action_code', 'name', 'risk',
      'requires_mfa', 'selected', 'grantable', 'inherited', 'unavailable_reason'])
     from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_draft'),
  'cada permissao expoe as chaves lidas por AccessPermission.fromJson');
select is((select jsonb_typeof(result -> 'audit') from detail_results where key = 'platform_draft'),
  'array', 'ator com audit.read recebe audit como lista (vazia no rascunho)');

-- Perfil platform existente
select is(
  (select result - 'permissions' - 'memberships' - 'audit' from detail_results where key = 'platform_target'),
  jsonb_build_object('domain', 'platform', 'id', '98300000-0000-4000-8000-000000000002',
    'code', 'qa_r04_detail_target', 'name', 'QA R04 alvo', 'description', '',
    'status', 'active', 'max_scope_kind', 'platform', 'version', 1, 'is_system', false,
    'membership_count', 1),
  'perfil platform devolve cabecalho e membership_count somente de vinculos ativos');
select is(
  (select array_agg(item ->> 'code' order by item ->> 'code')
     from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'platform_target' and (item ->> 'selected')::boolean),
  array['people.create', 'platform.read'],
  'perfil platform marca selected somente nas permissoes concedidas');
select is(
  (select jsonb_array_length(result -> 'permissions') from detail_results where key = 'platform_target'),
  (select count(*)::int from public.platform_permissions where status = 'active'),
  'perfil platform tambem traz o catalogo completo');
select is(
  (select result -> 'memberships' from detail_results where key = 'platform_target'),
  jsonb_build_array(jsonb_build_object('id', '98400000-0000-4000-8000-000000000002',
    'person_name', 'Bruna Vinculada', 'scope', 'Plataforma')),
  'perfil platform lista somente vinculos ativos com nome e escopo');
select ok(
  not (select result ? 'linked_people_count' or result ? 'capability_count'
    from detail_results where key = 'platform_target'),
  'forma da v2 nao e mais a devolvida pelo wrapper publico');

-- Rascunho institution
select is(
  (select result - 'permissions' - 'memberships' - 'audit' from detail_results where key = 'institution_draft'),
  jsonb_build_object('domain', 'institution', 'id', '', 'institution_id', null, 'code', '', 'name', '',
    'description', '', 'status', 'active', 'max_scope_kind', 'institution', 'version', 0,
    'is_system', false, 'membership_count', 0),
  'rascunho institution devolve cabecalho em branco');
select is(
  (select jsonb_array_length(result -> 'permissions') from detail_results where key = 'institution_draft'),
  (select count(*)::int from public.institution_permissions where status = 'active'),
  'rascunho institution traz o catalogo completo de permissoes institucionais');
select is(
  (select count(*)::int from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'institution_draft' and (item ->> 'selected')::boolean),
  0, 'rascunho institution nao tem permissao selecionada');
select is(
  (select count(*)::int from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'institution_draft' and not (item ->> 'grantable')::boolean),
  0, 'ator com institution.roles.manage pode conceder todo o catalogo institucional');

-- Perfil institution existente
select is(
  (select result - 'permissions' - 'memberships' - 'audit' from detail_results where key = 'institution_role'),
  jsonb_build_object('domain', 'institution', 'id', '98600000-0000-4000-8000-000000000001',
    'institution_id', '98500000-0000-4000-8000-000000000001', 'code', 'qa_r04_detail_role',
    'name', 'QA R04 papel', 'description', '', 'status', 'active', 'max_scope_kind', 'institution',
    'version', 1, 'is_system', false, 'membership_count', 1),
  'perfil institution devolve cabecalho com institution_id');
select is(
  (select array_agg(item ->> 'code' order by item ->> 'code')
     from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'institution_role' and (item ->> 'selected')::boolean),
  array['activities.create'],
  'perfil institution marca selected somente na concessao allow');
select is(
  (select item ->> 'grantable' || '|' || (item ->> 'unavailable_reason')
     from detail_results, jsonb_array_elements(result -> 'permissions') item
    where key = 'institution_role' and item ->> 'code' = 'activities.manage'),
  'false|Uma negação explícita deve ser tratada separadamente.',
  'negacao explicita nao e concedivel pela matriz');
select is(
  (select result -> 'memberships' from detail_results where key = 'institution_role'),
  jsonb_build_array(jsonb_build_object('id', '98800000-0000-4000-8000-000000000001',
    'person_name', 'Bruna Vinculada', 'scope', 'Instituição')),
  'perfil institution lista a atribuicao ativa com escopo legivel');

-- Ator sem audit.read nao recebe a lista de auditoria
delete from public.platform_role_permissions
where role_id = '98300000-0000-4000-8000-000000000001'
  and permission_id = (select id from public.platform_permissions where code = 'audit.read');
set local role authenticated;
select is(
  (select jsonb_typeof(public.superadmin_access_profile_detail('platform',
    '98300000-0000-4000-8000-000000000002') -> 'audit')),
  'null', 'sem audit.read a chave audit vem nula');
reset role;

select * from finish();
rollback;
