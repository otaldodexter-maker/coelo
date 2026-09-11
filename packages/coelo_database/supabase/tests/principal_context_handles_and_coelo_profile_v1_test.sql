-- @ no contexto do Principal, arrobas reservados e perfil Coelo (pacote 20260911130100).
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

-- Fixture: pessoa people-based P com membership em instituicao X (unidade U).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('d1000000-0000-4000-8000-000000000001','authenticated','authenticated','handles-p@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('d6000000-0000-4000-8000-000000000001','adult','Pessoa','Handles','Pessoa Handles','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('d6000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('d7000000-0000-4000-8000-000000000001','Handles X','Handles X','handles-x','active');
insert into public.units(id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle,status) values
  ('d8000000-0000-4000-8000-000000000001','d7000000-0000-4000-8000-000000000001','Unidade H','unidade-h',
   (select id from public.unit_types where status='active' order by id limit 1),'Unidade de teste','unidade.handlesx','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id) values
  ('d9000000-0000-4000-8000-000000000001','d6000000-0000-4000-8000-000000000001','d7000000-0000-4000-8000-000000000001','teacher','active','unit','d8000000-0000-4000-8000-000000000001');

-- 1-3: contrato do resolver
select ok(
  pg_get_function_result('public.list_my_principal_contexts()'::regprocedure) =
    'TABLE(membership_id uuid, person_id uuid, institution_id uuid, institution_name text, role_code text, scope_kind text, unit_id uuid, unit_name text, group_id uuid, group_name text, institution_handle text, unit_handle text)',
  'resolver expoe institution_handle e unit_handle no fim da projecao');
select ok(has_function_privilege('authenticated','public.list_my_principal_contexts()','execute')
  and not has_function_privilege('anon','public.list_my_principal_contexts()','execute'),
  'grants do resolver preservados');
select set_config('request.jwt.claims',jsonb_build_object('sub','d1000000-0000-4000-8000-000000000001','session_id','d2000000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.p_ctx', (select institution_handle||'|'||coalesce(unit_handle,'') from public.list_my_principal_contexts() where institution_id='d7000000-0000-4000-8000-000000000001'), true);
reset role;
select is(current_setting('test.p_ctx',true), 'handles-x|unidade.handlesx', 'o @ da instituicao (slug) e da unidade (handle) chegam ao cliente');

-- 4-8: arrobas reservados
select has_table('public','reserved_handles','tabela de arrobas reservados existe');
select ok(not has_table_privilege('authenticated','public.reserved_handles','select')
  and not has_table_privilege('anon','public.reserved_handles','select'), 'reserved_handles sem grant a cliente');
select is((select count(*)::int from public.reserved_handles where handle in ('coelo','coelo.me')), 2, 'coelo e coelo.me reservados');
select throws_ok($$insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('d7000000-0000-4000-8000-000000000002','Falsa Coelo','Falsa Coelo','coelo','active')$$,
  '23514','handle_reserved','instituicao nao pode usar o @coelo');
select throws_ok($$insert into public.units(id,institution_id,name,slug,unit_type_id,unit_type_other_description,handle,status) values
  ('d8000000-0000-4000-8000-000000000002','d7000000-0000-4000-8000-000000000001','Unidade falsa','unidade-falsa',
   (select id from public.unit_types where status='active' order by id limit 1),'Unidade de teste','coelo.me','active')$$,
  '23514','handle_reserved','unidade nao pode usar o @coelo.me');
select lives_ok($$insert into public.institutions(id,public_name,legal_name,slug,status) values
  ('d7000000-0000-4000-8000-000000000003','Handles Y','Handles Y','handles-y','active')$$,
  'handle comum continua aceito');

-- 10-14: perfil Coelo segue e e seguido por todos
select is((select display_name from public.people where id='c0e10000-0000-4000-8000-000000000001'), 'Coelo', 'pessoa de servico Coelo existe');
select ok(exists(select 1 from public.follow_links where follower_person_id='d6000000-0000-4000-8000-000000000001'
  and target_kind='person' and target_id='c0e10000-0000-4000-8000-000000000001' and status='active'),
  'pessoa nova acompanha a Coelo (gatilho de people)');
select ok(exists(select 1 from public.follow_links where follower_person_id='c0e10000-0000-4000-8000-000000000001'
  and target_kind='person' and target_id='d6000000-0000-4000-8000-000000000001' and status='active'),
  'a Coelo acompanha a pessoa nova');
select is(app_private.coelo_profile_follow_sync(), 0, 'sincronizacao repetida e no-op');
select is((select count(*)::int from public.follow_links where follower_person_id='c0e10000-0000-4000-8000-000000000001'
  and target_id='c0e10000-0000-4000-8000-000000000001'), 0, 'a Coelo nao segue a si mesma');

select * from finish();
rollback;
