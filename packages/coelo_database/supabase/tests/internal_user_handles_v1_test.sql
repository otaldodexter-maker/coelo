-- Prova do candidato 20260911170500_internal_user_handles_v1 (P46 = A: @ do
-- usuario interno pela pessoa de servico). Projeto descartavel LOCAL:
-- fixtures sinteticas em transacao com rollback. Roda depois do 220400
-- (ponte de ator) e do 170100 (@ de pessoas).
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create function pg_temp.iuh_session(auth_user uuid, session uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    case when auth_user is null then ''
      else jsonb_build_object('sub',auth_user,'session_id',session,'role','authenticated','aal','aal1')::text end, true)
$$;
create function pg_temp.iuh_service_person(identity uuid) returns uuid language sql as $$
  select person_id from app_private.superadmin_internal_actor_people where internal_identity_id=identity
$$;
create function pg_temp.iuh_handle(person uuid) returns text language sql as $$
  select normalized_handle from public.person_handles where person_id=person and status='active' and revoked_at is null
$$;

-- Duas identidades internas: Owner de plataforma (O) e Operacoes (P), com
-- perfil ANTES da membership para o @ nascer do nome do perfil.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
  ('a1500000-0000-4000-8000-000000000001','authenticated','authenticated','iuh-owner@invalid.test',now(),now(),now(),'{}','{}'),
  ('a1500000-0000-4000-8000-000000000002','authenticated','authenticated','iuh-ops@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
  ('a2500000-0000-4000-8000-000000000001','a1500000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
  ('a2500000-0000-4000-8000-000000000002','a1500000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
  ('a3500000-0000-4000-8000-000000000001'),('a3500000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(internal_identity_id,auth_user_id) values
  ('a3500000-0000-4000-8000-000000000001','a1500000-0000-4000-8000-000000000001'),
  ('a3500000-0000-4000-8000-000000000002','a1500000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_profiles(internal_identity_id,first_name,last_name,cpf,professional_email,job_title) values
  ('a3500000-0000-4000-8000-000000000001','Olívia','Coelho','52998224725','iuh-owner@invalid.test','Owner'),
  ('a3500000-0000-4000-8000-000000000002','Ana','Lima','11144477735','iuh-ops@invalid.test','Operações');
insert into app_private.superadmin_internal_memberships(internal_identity_id,platform_role_id,scope_kind) values
  ('a3500000-0000-4000-8000-000000000001',(select id from public.platform_roles where code='owner'),'platform'),
  ('a3500000-0000-4000-8000-000000000002',(select id from public.platform_roles where code='operations'),'platform');

-- 1-2. a pessoa de servico nasce com o @ do nome do perfil interno
select is(pg_temp.iuh_handle(pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000001')), 'olivia.coelho',
  'pessoa de servico do Owner nasce com @nome.sobrenome do perfil interno');
select is(pg_temp.iuh_handle(pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002')), 'ana.lima',
  'pessoa de servico de Operacoes nasce com @ do perfil interno');

-- 3. pessoa de servico fora da ponte de ator nao recebe @ (o @ do interno vem pela ponte)
insert into public.people(id,person_type,first_name,last_name,display_name) values
  ('a4500000-0000-4000-8000-000000000001','service','Servico','Avulso','Servico Avulso');
select is(pg_temp.iuh_handle('a4500000-0000-4000-8000-000000000001'), null,
  'pessoa de servico fora da ponte nao recebe @');

-- 4. @ de pessoa de servico e sempre privado
select throws_ok(format($$update public.person_handles set visibility='public' where person_id=%L$$,
  pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000001')), '23514',
  'child and service handles must remain private', 'visibilidade do @ de servico nao pode ser publica');

-- 5. anonimo nao resolve a pessoa de servico
select pg_temp.iuh_session(null,null);
select throws_ok($$select public.superadmin_internal_user_service_person_v1('a3500000-0000-4000-8000-000000000002')$$, '42501',
  'internal authorization denied', 'anonimo nao resolve a pessoa de servico de um usuario interno');

-- 6-9. Owner (platform.member.read/update) resolve, le e troca o @ de outro interno
select pg_temp.iuh_session('a1500000-0000-4000-8000-000000000001','a2500000-0000-4000-8000-000000000001');
select is(public.superadmin_internal_user_service_person_v1('a3500000-0000-4000-8000-000000000002')->'data'->>'person_id',
  pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002')::text,
  'Owner resolve a pessoa de servico do usuario interno');
select throws_ok($$select public.superadmin_internal_user_service_person_v1('a3500000-0000-4000-8000-0000000000ff')$$, '42501',
  'internal user unavailable', 'identidade inexistente nao e enumeravel');
select is(public.superadmin_person_handle_get(pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002'))->'data'->>'can_edit', 'true',
  'Owner ve e pode editar o @ da pessoa de servico');
select is(public.superadmin_person_handle_set(gen_random_uuid(), pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002'),
  '@Ana_Ops','ajuste pelo superadmin')->'data'->>'handle', 'ana_ops', 'Owner troca o @ do usuario interno (normalizado)');

-- 10. trava de 30 dias vale para a pessoa de servico
select throws_ok(format($$select public.superadmin_person_handle_set(gen_random_uuid(), %L, 'ana.denovo', 'de novo')$$,
  pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002')), '22023',
  'person handle unavailable', 'segunda troca dentro de 30 dias e negada para o interno');

-- 11-12. o proprio interno (Operacoes, sem platform.member.update) le o seu @; nao troca o de outro
select pg_temp.iuh_session('a1500000-0000-4000-8000-000000000002','a2500000-0000-4000-8000-000000000002');
select is(public.superadmin_person_handle_get(pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000002'))->'data'->>'handle', 'ana_ops',
  'o proprio usuario interno le o seu @ pela pessoa de servico');
select throws_ok(format($$select public.superadmin_person_handle_set(gen_random_uuid(), %L, 'olivia.x', 'invasao')$$,
  pg_temp.iuh_service_person('a3500000-0000-4000-8000-000000000001')), '42501',
  'person handle permission denied', 'interno sem platform.member.update nao troca o @ de outro interno');

select * from finish();
rollback;
