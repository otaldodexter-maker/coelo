-- Prova do candidato 20260910171100_follow_links_automatic_hierarchy_v1 (D1).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Estrutura sintetica: instituicao X, unidade U, turma G.
insert into public.institution_types(id,code,name,status)
values('d1000000-0000-4000-8000-000000000001','d1-type','D1 type','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('d1000000-0000-4000-8000-000000000011','D1 instituicao X','d1-x','d1000000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status)
values('d1000000-0000-4000-8000-000000000002','d1-unit-type','D1 unit type','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('d1000000-0000-4000-8000-000000000021','d1000000-0000-4000-8000-000000000011','d1000000-0000-4000-8000-000000000002','D1 unidade U','d1-u','d1unitu');
insert into public.groups(id,institution_id,unit_id,name) values
('d1000000-0000-4000-8000-000000000031','d1000000-0000-4000-8000-000000000011','d1000000-0000-4000-8000-000000000021','D1 turma G');

-- Pessoas: crianca C, responsavel P, terceira pessoa Q (sem vinculo).
insert into public.people(id,person_type,first_name,last_name,display_name) values
('d1000000-0000-4000-8000-000000000041','child','D1','Crianca','D1 crianca C'),
('d1000000-0000-4000-8000-000000000042','adult','D1','Responsavel','D1 responsavel P'),
('d1000000-0000-4000-8000-000000000043','adult','D1','Terceira','D1 pessoa Q');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('d1000000-0000-4000-8000-000000000052','authenticated','authenticated','d1-p@invalid.test',now(),now(),now(),'{}','{}'),
('d1000000-0000-4000-8000-000000000053','authenticated','authenticated','d1-q@invalid.test',now(),now(),now(),'{}','{}');
insert into public.person_auth_links(person_id,auth_user_id) values
('d1000000-0000-4000-8000-000000000042','d1000000-0000-4000-8000-000000000052'),
('d1000000-0000-4000-8000-000000000043','d1000000-0000-4000-8000-000000000053');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id) values
('d1000000-0000-4000-8000-000000000061','d1000000-0000-4000-8000-000000000042','d1000000-0000-4000-8000-000000000041','father',
 (select id from public.family_relationship_types where code='father'));

-- Cadastro da crianca: contexto na instituicao, vinculo com a unidade e com a turma.
insert into public.child_contexts(id,child_person_id,institution_id) values
('d1000000-0000-4000-8000-000000000071','d1000000-0000-4000-8000-000000000041','d1000000-0000-4000-8000-000000000011');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
('d1000000-0000-4000-8000-000000000081','d1000000-0000-4000-8000-000000000071','d1000000-0000-4000-8000-000000000021','active','d1000000-0000-4000-8000-000000000042',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
('d1000000-0000-4000-8000-000000000091','d1000000-0000-4000-8000-000000000081','d1000000-0000-4000-8000-000000000031','active');

create function pg_temp.d1_session(auth_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'role','authenticated','aal','aal1')::text end, true)
$$;
create function pg_temp.d1_active_automatic() returns bigint language sql as $$
  select count(*) from public.follow_links where origin='automatic' and status='active'
$$;

-- 1. cadastro gera a cadeia inteira para a crianca e o responsavel
select is(pg_temp.d1_active_automatic(), 6::bigint,
  'crianca e responsavel acompanham instituicao, unidade e turma automaticamente (6 linhas)');
select is((select count(*) from public.follow_links where follower_person_id='d1000000-0000-4000-8000-000000000041' and status='active'), 3::bigint,
  'crianca segue os 3 niveis');
select is((select count(*) from public.follow_links where follower_person_id='d1000000-0000-4000-8000-000000000042' and source_relationship='guardian' and status='active'), 3::bigint,
  'responsavel segue os 3 niveis por procedencia guardian');

-- 4-6. leitura pelo responsavel P (sem people.read)
select pg_temp.d1_session('d1000000-0000-4000-8000-000000000052');
select is((public.follow_summary('institution','d1000000-0000-4000-8000-000000000011')->>'followers_count')::int, 2,
  'instituicao tem 2 seguidores (crianca e responsavel)');
select is((public.follow_summary('person','d1000000-0000-4000-8000-000000000042')->>'following_count')::int, 3,
  'responsavel segue 3 alvos');
select is(jsonb_array_length(public.follow_following_list('d1000000-0000-4000-8000-000000000042')), 3,
  'a propria pessoa lista o que segue');
select throws_ok($$select public.follow_following_list('d1000000-0000-4000-8000-000000000041')$$, '42501',
  'follow list permission denied', 'sem people.read nao le o Seguindo de outra pessoa (a crianca)');
select throws_ok($$select public.follow_followers_list('institution','d1000000-0000-4000-8000-000000000011')$$, '42501',
  'follow list permission denied', 'sem people.read nao lista seguidores (dado de crianca)');

-- 9-10. com people.read (membership de plataforma), a lista abre e traz a crianca
insert into public.platform_roles(id,code,name,max_scope_kind) values
('d1000000-0000-4000-8000-000000000101','d1_reader','D1 leitor','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'd1000000-0000-4000-8000-000000000101',id,'allow' from public.platform_permissions where code='people.read';
insert into public.platform_memberships(person_id,role_id,status,scope_kind) values
('d1000000-0000-4000-8000-000000000042','d1000000-0000-4000-8000-000000000101','active','platform');
select is(jsonb_array_length(public.follow_followers_list('institution','d1000000-0000-4000-8000-000000000011')), 2,
  'com people.read a lista de seguidores da instituicao tem 2 pessoas');
select ok(public.follow_followers_list('institution','d1000000-0000-4000-8000-000000000011') @> '[{"person_type":"child"}]'::jsonb,
  'a crianca aparece na lista para quem tem people.read');

-- 11-13. botao Acompanhar (manual) pela pessoa Q
select pg_temp.d1_session('d1000000-0000-4000-8000-000000000053');
select is((public.follow_set('institution','d1000000-0000-4000-8000-000000000011',true)->>'following')::boolean, true,
  'Acompanhar cria vinculo manual');
select lives_ok($$select public.follow_set('institution','d1000000-0000-4000-8000-000000000011',true)$$,
  'Acompanhar repetido e idempotente');
select is((select count(*) from public.follow_links where follower_person_id='d1000000-0000-4000-8000-000000000043' and status='active'), 1::bigint,
  'uma unica linha manual ativa');
select is((public.follow_summary('institution','d1000000-0000-4000-8000-000000000011')->>'followers_count')::int, 3,
  'instituicao passa a ter 3 seguidores');

-- 15-17. a estrutura muda: a turma sai, depois a unidade, depois o responsavel
update public.child_group_links set status='inactive' where id='d1000000-0000-4000-8000-000000000091';
select is(pg_temp.d1_active_automatic(), 4::bigint, 'turma revogada: somem as 2 linhas de turma');
update public.child_unit_links set status='revoked', revoked_at=now() where id='d1000000-0000-4000-8000-000000000081';
select is(pg_temp.d1_active_automatic(), 2::bigint, 'unidade revogada: ficam so as 2 linhas de instituicao');
update public.guardian_links set status='inactive', revoked_at=now() where id='d1000000-0000-4000-8000-000000000061';
select is(pg_temp.d1_active_automatic(), 1::bigint, 'responsavel revogado: fica so a crianca na instituicao');
select is((select count(*) from public.follow_links where origin='manual' and status='active'), 1::bigint,
  'a mudanca de estrutura nunca toca o vinculo manual');
select ok((select bool_and(status='inactive' and revoked_at is not null) from public.follow_links where origin='automatic' and status<>'active'),
  'linhas automaticas revogadas guardam revoked_at');

-- 20-21. deixar de acompanhar e regras do comando
select is((public.follow_set('institution','d1000000-0000-4000-8000-000000000011',false)->>'following')::boolean, false,
  'deixar de acompanhar revoga o manual');
select throws_ok($$select public.follow_set('person','d1000000-0000-4000-8000-000000000043',true)$$, '22023',
  'a person cannot follow themselves', 'pessoa nao segue a si mesma');
select throws_ok($$select public.follow_set('institution','d1000000-0000-4000-8000-0000000000ff',true)$$, 'P0002',
  'follow target not found', 'alvo inexistente nega');

-- 23-24. sem sessao e ACL/RLS
select pg_temp.d1_session(null);
select throws_ok($$select public.follow_summary('institution','d1000000-0000-4000-8000-000000000011')$$, '42501',
  'follow summary requires a session', 'sem sessao nega ate a contagem');
select ok(
  not has_table_privilege('authenticated','public.follow_links','select')
  and not has_table_privilege('anon','public.follow_links','select')
  and (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.follow_links'::regclass)
  and not has_function_privilege('anon','public.follow_set(text,uuid,boolean)','execute')
  and has_function_privilege('authenticated','public.follow_set(text,uuid,boolean)','execute'),
  'tabela sem grant direto, RLS forcado, anon sem execute, authenticated executa');

select * from finish();
rollback;
