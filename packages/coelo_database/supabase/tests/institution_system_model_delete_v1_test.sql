-- Prova do candidato 20260911170600_institution_system_model_delete_v1 (P45 = B).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

-- Ator de plataforma (como owner) e ator de instituicao com institution.roles.manage.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('a0700000-0000-4000-8000-000000000001','authenticated','authenticated','r06-platform@invalid.test',now(),now(),now(),'{}','{}'),
  ('a0700000-0000-4000-8000-000000000002','authenticated','authenticated','r06-institution@invalid.test',now(),now(),now(),'{}','{}');
insert into public.people(id,person_type,first_name,last_name,display_name) values
  ('a0700000-0000-4000-8000-000000000011','adult','Plataforma','R06','Plataforma R06'),
  ('a0700000-0000-4000-8000-000000000012','adult','Instituicao','R06','Instituicao R06');
insert into public.person_auth_links(person_id,auth_user_id) values
  ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000001'),
  ('a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000002');
insert into public.platform_roles(id,code,name,max_scope_kind) values
  ('a0700000-0000-4000-8000-000000000021','qa_r06_platform_actor','QA R06 plataforma','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
  select 'a0700000-0000-4000-8000-000000000021',id,'allow' from public.platform_permissions where status='active';
insert into public.institutions(id,public_name,slug,status) values
  ('a0700000-0000-4000-8000-000000000031','Escola QA R06','escola-qa-r06-perfis','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id) values
  ('a0700000-0000-4000-8000-000000000011','a0700000-0000-4000-8000-000000000021','active','platform',null),
  ('a0700000-0000-4000-8000-000000000012','a0700000-0000-4000-8000-000000000021','active','institution','a0700000-0000-4000-8000-000000000031');

-- Dois modelos do sistema criados pela plataforma (P31/170300) e um perfil proprio da instituicao.
select set_config('request.jwt.claims',
  jsonb_build_object('sub','a0700000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text, true);
create temporary table r06_profiles(key text primary key, result jsonb not null);
insert into r06_profiles values ('model', public.superadmin_access_profile_save(gen_random_uuid(), 0, 'prova R06',
  jsonb_build_object('domain','institution','name','Modelo QA R06','description','modelo do sistema','status','active',
    'max_scope_kind','unit','capabilities','[]'::jsonb)));
insert into r06_profiles values ('model2', public.superadmin_access_profile_save(gen_random_uuid(), 0, 'prova R06',
  jsonb_build_object('domain','institution','name','Modelo QA R06 b','description','modelo do sistema b','status','active',
    'max_scope_kind','unit','capabilities','[]'::jsonb)));
select is((select (result->'profile'->>'is_system')::boolean from r06_profiles where key='model'), true,
  'fixture: modelo do sistema criado pela plataforma');

-- 2. instituicao com institution.roles.manage nao exclui modelo do sistema (hierarquia)
select set_config('request.jwt.claims',
  jsonb_build_object('sub','a0700000-0000-4000-8000-000000000002','role','authenticated','aal','aal1')::text, true);
select throws_ok(format($$select public.superadmin_access_profile_delete_and_reassign(gen_random_uuid(),'institution',%L,1,null,'tentativa')$$,
  (select result->>'profile_id' from r06_profiles where key='model')), '42501', 'system profile is protected',
  'perfil escopado em instituicao nao exclui modelo do sistema');

-- 3-5. plataforma (como owner) exclui; auditoria e recibo
select set_config('request.jwt.claims',
  jsonb_build_object('sub','a0700000-0000-4000-8000-000000000001','role','authenticated','aal','aal1')::text, true);
select throws_ok(format($$select public.superadmin_access_profile_delete_and_reassign(gen_random_uuid(),'institution',%L,99,null,'versao errada')$$,
  (select result->>'profile_id' from r06_profiles where key='model')), '40001', 'stale profile version',
  'versao esperada continua obrigatoria');
select is((public.superadmin_access_profile_delete_and_reassign('a0700000-0000-4000-8000-000000000041','institution',
  (select (result->>'profile_id')::uuid from r06_profiles where key='model'),1,null,'modelo descartado pelo Superadmin (P45)')->>'deleted_profile_id'),
  (select result->>'profile_id' from r06_profiles where key='model'), 'plataforma exclui modelo do sistema criado pelo Superadmin (P45 = B)');
select is((select count(*) from public.institution_roles where id=(select (result->>'profile_id')::uuid from r06_profiles where key='model')), 0::bigint,
  'modelo excluido nao existe mais');

-- 6. auditoria registrou a exclusao
select is((select count(*) from audit.audit_logs where object_type='institution_access_profile'
  and object_id=(select (result->>'profile_id')::uuid from r06_profiles where key='model') and outcome='success'
  and action_code='membership_changed'), 1::bigint,
  'exclusao auditada');

-- 7. modelo de plataforma (owner) continua protegido
select throws_ok(format($$select public.superadmin_access_profile_delete_and_reassign(gen_random_uuid(),'platform',%L,%s,null,'x')$$,
  (select id from public.platform_roles where code='owner'), (select version from public.platform_roles where code='owner')),
  '42501', 'system profile is protected', 'modelo de plataforma continua protegido');

select * from finish();
rollback;
