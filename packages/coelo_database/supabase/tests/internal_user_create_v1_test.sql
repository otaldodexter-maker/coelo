-- Prova do candidato 20260911170800_internal_user_create_v1 (internal-users.create:
-- autorizacao com o token do operador + criacao pela Edge Function como service_role).
-- Projeto descartavel LOCAL: fixtures sinteticas em transacao com rollback.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

create function pg_temp.iuc_session(auth_user uuid, session uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'session_id',session,'role','authenticated','aal','aal1')::text end, true)
$$;
create function pg_temp.iuc_draft(email text, cpf text, scope text, scope_ids jsonb) returns jsonb language sql as $$
  select jsonb_build_object('identity',jsonb_build_object(
    'first_name','Novo','last_name','Interno','display_name','Novo Interno','birth_date','1990-01-01','cpf',cpf,
    'professional_email',email,'mobile','','additional_phone','','job_title','Operacoes','department','','internal_function','',
    'professional_notes','','postal_code','','street','','number','','complement','','neighborhood','','city','','state','','country','Brasil'),
    'profile_id',(select id from public.platform_roles where code='operations'),'scope',scope,'scope_ids',scope_ids)
$$;

-- Owner de plataforma (ator), interno escopado em instituicao e um auth user novo sem vinculo.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('a1800000-0000-4000-8000-000000000001','authenticated','authenticated','iuc-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1800000-0000-4000-8000-000000000002','authenticated','authenticated','iuc-scoped@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1800000-0000-4000-8000-000000000009','authenticated','authenticated','iuc-novo@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('a2800000-0000-4000-8000-000000000001','a1800000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('a2800000-0000-4000-8000-000000000002','a1800000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into public.institutions(id,public_name,slug,status) values
  ('a3800000-0000-4000-8000-000000000031','Escola QA IUC','escola-qa-iuc','active');
insert into app_private.superadmin_internal_identities(id) values
  ('a3800000-0000-4000-8000-000000000001'),('a3800000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(internal_identity_id,auth_user_id) values
  ('a3800000-0000-4000-8000-000000000001','a1800000-0000-4000-8000-000000000001'),
  ('a3800000-0000-4000-8000-000000000002','a1800000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_profiles(internal_identity_id,first_name,last_name,cpf,professional_email,job_title) values
  ('a3800000-0000-4000-8000-000000000001','Olívia','Coelho','52998224725','iuc-owner@invalid.test','Owner'),
  ('a3800000-0000-4000-8000-000000000002','Ana','Lima','11144477735','iuc-scoped@invalid.test','Operações');
insert into app_private.superadmin_internal_memberships(internal_identity_id,platform_role_id,scope_kind,scope_institution_id) values
  ('a3800000-0000-4000-8000-000000000001',(select id from public.platform_roles where code='owner'),'platform',null),
  ('a3800000-0000-4000-8000-000000000002',(select id from public.platform_roles where code='owner'),'institution','a3800000-0000-4000-8000-000000000031');

-- 1. anonimo nao autoriza
select pg_temp.iuc_session(null,null);
select is(public.superadmin_internal_user_create_authorize_v1(pg_temp.iuc_draft('novo@invalid.test','98765432100','platform','[]'))->>'ok', 'false',
  'anonimo recebe envelope de erro');

-- 2-4. Owner de plataforma autoriza; CPF/e-mail ja usados sao recusados
select pg_temp.iuc_session('a1800000-0000-4000-8000-000000000001','a2800000-0000-4000-8000-000000000001');
select is(public.superadmin_internal_user_create_authorize_v1(pg_temp.iuc_draft('Novo@Invalid.test','98765432100','platform','[]'))->'data'->>'actor_internal_identity_id',
  'a3800000-0000-4000-8000-000000000001', 'Owner de plataforma autoriza e recebe o proprio id de ator');
select is(public.superadmin_internal_user_create_authorize_v1(pg_temp.iuc_draft('outro@invalid.test','52998224725','platform','[]'))->>'ok', 'false',
  'CPF ja registrado e recusado');
select is(public.superadmin_internal_user_create_authorize_v1(pg_temp.iuc_draft('iuc-owner@invalid.test','98765432100','platform','[]'))->>'ok', 'false',
  'e-mail ja registrado e recusado');

-- 5. interno escopado em instituicao nao autoriza criacao
select pg_temp.iuc_session('a1800000-0000-4000-8000-000000000002','a2800000-0000-4000-8000-000000000002');
select is(public.superadmin_internal_user_create_authorize_v1(pg_temp.iuc_draft('novo@invalid.test','98765432100','platform','[]'))->>'ok', 'false',
  'identidade escopada em instituicao nao cria usuario interno');

-- 6. authenticated nao executa a funcao do worker
select ok(not has_function_privilege('authenticated','public.superadmin_internal_user_create_for_worker_v1(uuid,uuid,uuid,jsonb)','execute')
  and has_function_privilege('service_role','public.superadmin_internal_user_create_for_worker_v1(uuid,uuid,uuid,jsonb)','execute'),
  'funcao do worker so para service_role');

-- 7-9. worker cria identidade + perfil + vinculo + membership; ponte da pessoa de servico e @; replay devolve a mesma
select pg_temp.iuc_session(null,null);
create temporary table iuc_result as
  select public.superadmin_internal_user_create_for_worker_v1('a4800000-0000-4000-8000-000000000001',
    'a3800000-0000-4000-8000-000000000001','a1800000-0000-4000-8000-000000000009',
    pg_temp.iuc_draft('Novo@Invalid.test','98765432100','limited',jsonb_build_array('a3800000-0000-4000-8000-000000000031'))) as r;
select is((select r->'data'->'identity'->>'professional_email' from iuc_result), 'novo@invalid.test',
  'worker cria o usuario interno e devolve a projecao');
select is((select h.normalized_handle from app_private.superadmin_internal_auth_links l
  join app_private.superadmin_internal_actor_people a on a.internal_identity_id=l.internal_identity_id
  join public.person_handles h on h.person_id=a.person_id and h.status='active'
  where l.auth_user_id='a1800000-0000-4000-8000-000000000009'), 'novo.interno',
  'ponte de ator criou a pessoa de servico com o @ do perfil (P46)');
select is((select public.superadmin_internal_user_create_for_worker_v1('a4800000-0000-4000-8000-000000000001',
    'a3800000-0000-4000-8000-000000000001','a1800000-0000-4000-8000-000000000009',
    pg_temp.iuc_draft('Novo@Invalid.test','98765432100','limited',jsonb_build_array('a3800000-0000-4000-8000-000000000031')))->'data'->>'id'),
  (select r->'data'->>'id' from iuc_result), 'replay com o mesmo auth user devolve a mesma identidade');

select * from finish();
rollback;
