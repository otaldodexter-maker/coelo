-- Ponte de ator do Principal (pacote 20260911130000, R05 principal-chat-sistema).
-- Protege: a sessao interna do Superadmin resolve contexto e ator em Acontece,
-- Agora e Momentos pelo espelho (P35 "Superadmin ve tudo"); o realm people-based
-- continua com precedencia e a negativa cross-tenant continua fechada.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- Fixture: A = identidade interna owner (sem pessoa); B = pessoa adulta do realm
-- people-based, guardian em Y; C = auth user sem realm.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('c1000000-0000-4000-8000-000000000001','authenticated','authenticated','bridge-internal@invalid.test',now(),now(),now(),'{}','{}'),
  ('c1000000-0000-4000-8000-000000000002','authenticated','authenticated','bridge-people@invalid.test',now(),now(),now(),'{}','{}'),
  ('c1000000-0000-4000-8000-000000000003','authenticated','authenticated','bridge-nobody@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('c2000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('c2000000-0000-4000-8000-000000000002','c1000000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
  ('c2000000-0000-4000-8000-000000000003','c1000000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('c3000000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
  ('c4000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'c5000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('c6000000-0000-4000-8000-000000000002','adult','Pessoa','Do realm','Pessoa Do realm','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('c6000000-0000-4000-8000-000000000002','c1000000-0000-4000-8000-000000000002','active');
-- instituicoes nascem DEPOIS do espelho: o gatilho de institutions cobre A
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('c7000000-0000-4000-8000-000000000001','Bridge X','Bridge X','bridge-x','active'),
  ('c7000000-0000-4000-8000-000000000002','Bridge Y','Bridge Y','bridge-y','active'),
  ('c7000000-0000-4000-8000-000000000003','Bridge Z inativa','Bridge Z','bridge-z','inactive');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind) values
  ('c8000000-0000-4000-8000-000000000002','c6000000-0000-4000-8000-000000000002','c7000000-0000-4000-8000-000000000002','guardian','active','institution');

-- 1-3: helper e grants
select has_function('app_private','person_id_for_auth_user',array['uuid'],'helper parametrizado existe');
select ok(not has_function_privilege('authenticated','app_private.person_id_for_auth_user(uuid)','execute')
  and not has_function_privilege('anon','app_private.person_id_for_auth_user(uuid)','execute'),
  'helper sem execute para cliente');
select ok(not has_function_privilege('anon','public.list_my_principal_contexts()','execute')
  and has_function_privilege('authenticated','public.list_my_principal_contexts()','execute'),
  'list_my_principal_contexts: authenticated executa, anon nao');

-- 4-6: resolucao por auth user
select is(app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000001'),
  (select person_id from app_private.superadmin_internal_actor_people where internal_identity_id='c3000000-0000-4000-8000-000000000001'),
  'sessao interna resolve para a pessoa de servico');
select is(app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000002'),
  'c6000000-0000-4000-8000-000000000002'::uuid, 'realm people-based tem precedencia');
select is(app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000003'), null::uuid,
  'auth user sem realm nao vira ninguem');

-- 7-10: Superadmin ve tudo: membership + institution_admin nas instituicoes ativas
select is((select count(*)::int from public.institution_memberships m
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  where a.internal_identity_id='c3000000-0000-4000-8000-000000000001' and m.status='active' and m.revoked_at is null
    and m.institution_id in ('c7000000-0000-4000-8000-000000000001','c7000000-0000-4000-8000-000000000002')),
  2, 'o espelho interno ganhou membership owner nas duas instituicoes ativas (gatilho de institutions)');
select is((select count(*)::int from public.institution_memberships m
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  where a.internal_identity_id='c3000000-0000-4000-8000-000000000001' and m.institution_id='c7000000-0000-4000-8000-000000000003'),
  0, 'instituicao inativa nao recebe membership');
select is((select count(*)::int from public.institution_role_assignments asg
  join public.institution_memberships m on m.id=asg.membership_id
  join app_private.superadmin_internal_actor_people a on a.person_id=m.person_id
  join public.institution_roles r on r.id=asg.role_id
  where a.internal_identity_id='c3000000-0000-4000-8000-000000000001' and r.code='institution_admin' and asg.status='active'),
  2, 'cada membership recebeu o papel de sistema institution_admin');
select is(app_private.superadmin_internal_actor_institution_access_sync(), 0, 'segunda sincronizacao e no-op (idempotente)');

-- 11-15: como A (sessao interna)
select set_config('request.jwt.claims',jsonb_build_object('sub','c1000000-0000-4000-8000-000000000001','session_id','c2000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.a_ctx', (select count(*)::text from public.list_my_principal_contexts() where institution_id in ('c7000000-0000-4000-8000-000000000001','c7000000-0000-4000-8000-000000000002')), true);
select set_config('test.a_role', (select string_agg(distinct role_code, ',') from public.list_my_principal_contexts() where institution_id in ('c7000000-0000-4000-8000-000000000001','c7000000-0000-4000-8000-000000000002')), true);
reset role;
-- as funcoes de ator sao app_private (sem execute para cliente): chamadas como postgres com os mesmos claims
select set_config('test.a_happens', coalesce((select person_id::text from app_private.happens_actor('c7000000-0000-4000-8000-000000000001','happens.posts.create',null,null)),''), true);
select set_config('test.a_now', coalesce((select person_id::text from app_private.now_actor('c7000000-0000-4000-8000-000000000002','now.publications.create',null,null)),''), true);
select set_config('test.a_moments', coalesce((select person_id::text from app_private.moments_actor_for_auth_user('c1000000-0000-4000-8000-000000000001','c7000000-0000-4000-8000-000000000001','moments.publications.read',null,null)),''), true);
select is(current_setting('test.a_ctx',true), '2', 'A enxerga as duas instituicoes ativas como contexto do Principal');
select is(current_setting('test.a_role',true), 'owner', 'contexto de A e owner');
select is(current_setting('test.a_happens',true), app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000001')::text, 'happens_actor reconhece a sessao interna com happens.posts.create');
select is(current_setting('test.a_now',true), app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000001')::text, 'now_actor reconhece a sessao interna com now.publications.create');
select is(current_setting('test.a_moments',true), app_private.person_id_for_auth_user('c1000000-0000-4000-8000-000000000001')::text, 'moments_actor_for_auth_user reconhece a sessao interna');

-- 16-19: como B (people-based, guardian em Y): precedencia e negativa cross-tenant
select set_config('request.jwt.claims',jsonb_build_object('sub','c1000000-0000-4000-8000-000000000002','session_id','c2000000-0000-4000-8000-000000000002','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.b_ctx', (select string_agg(institution_id::text||':'||role_code, ',') from public.list_my_principal_contexts()), true);
reset role;
select throws_ok($$select * from app_private.happens_actor('c7000000-0000-4000-8000-000000000001','happens.posts.read',null,null)$$,
  '42501','happens_permission_denied','B nao entra no Acontece da instituicao X (cross-tenant negado)');
select throws_ok($$select * from app_private.now_actor('c7000000-0000-4000-8000-000000000001','now.publications.read',null,null)$$,
  '42501','now_permission_denied','B nao entra no Agora da instituicao X (cross-tenant negado)');
select throws_ok($$select * from app_private.moments_actor_for_auth_user('c1000000-0000-4000-8000-000000000002','c7000000-0000-4000-8000-000000000001','moments.publications.read',null,null)$$,
  '42501','moments_permission_denied','B nao entra nos Momentos da instituicao X (cross-tenant negado)');
select is(current_setting('test.b_ctx',true), 'c7000000-0000-4000-8000-000000000002:guardian', 'B continua vendo so o proprio contexto guardian em Y');

-- 20-21: sem realm e sem sessao
select set_config('request.jwt.claims',jsonb_build_object('sub','c1000000-0000-4000-8000-000000000003','session_id','c2000000-0000-4000-8000-000000000003','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.c_ctx', (select count(*)::text from public.list_my_principal_contexts()), true);
reset role;
select is(current_setting('test.c_ctx',true), '0', 'auth user sem realm nao tem contexto');
set local role anon;
select throws_ok($$select * from public.list_my_principal_contexts()$$, '42501', null, 'anon nao executa o resolver');
reset role;

-- 22: resgate de ticket nao aceita ticket inexistente para a sessao interna
select throws_ok($$select public.redeem_happens_media_read_ticket('00000000-0000-4000-8000-000000000000','c1000000-0000-4000-8000-000000000001')$$,
  '42501','media_read_ticket_invalid','resgate sem ticket continua negando');

select * from finish();
rollback;
