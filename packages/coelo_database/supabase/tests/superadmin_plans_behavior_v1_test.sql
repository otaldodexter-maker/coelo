-- Gate de Back-end de plans.list, plans.create e plans.edit (Superadmin ->
-- Planos), regua do MVP (ADR 0034): anonimo nega, ator sem plan.change nega,
-- Owner de plataforma lista/cria/edita com recibo idempotente e revisao
-- otimista, membership escopada a instituicao nao alcanca o catalogo, e as
-- tabelas nao entregam linha a authenticated fora das RPCs.
-- Exige o candidato candidatos/operacoes/20260911200000_superadmin_plans_platform_scope_v1.sql
-- (negativa por instituicao e status padrao no save).
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

-- Fixtures no realm people: person_auth_links + platform_memberships.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at) values
 ('84100000-0000-4000-8000-000000000001','authenticated','authenticated','plans-owner@test.invalid',now(),now(),now()),
 ('84100000-0000-4000-8000-000000000002','authenticated','authenticated','plans-reader@test.invalid',now(),now(),now()),
 ('84100000-0000-4000-8000-000000000003','authenticated','authenticated','plans-institution@test.invalid',now(),now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('84110000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
 ('84110000-0000-4000-8000-000000000002','84100000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour'),
 ('84110000-0000-4000-8000-000000000003','84100000-0000-4000-8000-000000000003',now(),now(),'aal1',now()+interval '1 hour');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('84200000-0000-4000-8000-000000000001','adult','Plans','Owner','Plans Owner','active'),
 ('84200000-0000-4000-8000-000000000002','adult','Plans','Reader','Plans Reader','active'),
 ('84200000-0000-4000-8000-000000000003','adult','Plans','Institution','Plans Institution','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('84200000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001','active'),
 ('84200000-0000-4000-8000-000000000002','84100000-0000-4000-8000-000000000002','active'),
 ('84200000-0000-4000-8000-000000000003','84100000-0000-4000-8000-000000000003','active');
insert into public.institutions(id,public_name,legal_name,slug,status) values
 ('84500000-0000-4000-8000-000000000001','Escola Teste Planos','Escola Teste Planos','escola-teste-planos','active');
-- Papel de plataforma so com platform.read (le, nao muda).
insert into public.platform_roles(id,code,name,status,is_system,max_scope_kind) values
 ('84300000-0000-4000-8000-000000000001','plans_test_reader','Plans reader','active',true,'platform'),
 ('84300000-0000-4000-8000-000000000002','plans_test_institution','Plans institution','active',true,'institution');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '84300000-0000-4000-8000-000000000001',id,'allow','active'
from public.platform_permissions where code='platform.read';
-- Papel de instituicao que concede ate plan.change: mesmo assim nao alcanca o catalogo da plataforma.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '84300000-0000-4000-8000-000000000002',id,'allow','active'
from public.platform_permissions where code in ('platform.read','plan.change');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '84200000-0000-4000-8000-000000000001',id,'active','platform',false
from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
 ('84200000-0000-4000-8000-000000000002','84300000-0000-4000-8000-000000000001','active','platform',false);
insert into public.platform_memberships(person_id,role_id,status,scope_kind,scope_institution_id,mfa_required) values
 ('84200000-0000-4000-8000-000000000003','84300000-0000-4000-8000-000000000002','active','institution','84500000-0000-4000-8000-000000000001',false);

create temporary table plans_test_responses(label text primary key, body jsonb not null);
grant select, insert on plans_test_responses to authenticated;

-- Leitura direta como authenticated: sem grant vira 42501, com grant o RLS filtra; em ambos, nenhuma linha.
create function pg_temp.plans_visible_rows() returns bigint language plpgsql as $$
declare v bigint;
begin
  select count(*) into v from public.plans;
  return v;
exception when insufficient_privilege then return 0;
end $$;
grant execute on function pg_temp.plans_visible_rows() to authenticated;

-- 1-2. Sem sessao: nega antes de qualquer leitura.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.superadmin_plans_list('',null,null,1,11)$$,
  '28000','authentication_required','anonymous session cannot list plans');
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000000',null,null,'{"name":"Basico","code":"basico","description":"Plano basico"}','motivo')$$,
  '28000','authentication_required','anonymous session cannot save a plan');
reset role;

-- 3-4. Leitor de plataforma (platform.read, sem plan.change): lista mas nao salva.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000002',
  'session_id','84110000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into plans_test_responses values('reader_list', public.superadmin_plans_list('',null,null,1,11));
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000001',null,null,'{"name":"Basico","code":"basico","description":"Plano basico"}','motivo')$$,
  '42501','permission_denied','actor without plan.change cannot save a plan');
reset role;
select is((select (body->>'total_items')::int from plans_test_responses where label='reader_list'),0,'platform.read alone lists the (empty) catalog');

-- 5-12. Owner de plataforma cria, com replay idempotente do mesmo request_id.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000001',
  'session_id','84110000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into plans_test_responses values('create',
  public.superadmin_plan_save('84400000-0000-4000-8000-000000000002',null,null,
    jsonb_build_object('name','Plano Essencial','code','essencial','description','Plano de entrada','status','active',
      'entitlements',jsonb_build_object(
        'feature.communication',jsonb_build_object('enabled',true),'feature.agenda',jsonb_build_object('enabled',true),
        'feature.invitations',jsonb_build_object('enabled',false),'feature.chat',jsonb_build_object('enabled',true),
        'feature.notices',jsonb_build_object('enabled',true),'feature.routine',jsonb_build_object('enabled',false),
        'feature.happens',jsonb_build_object('enabled',false),'feature.now',jsonb_build_object('enabled',false),
        'feature.moments',jsonb_build_object('enabled',false),
        'limit.units',jsonb_build_object('value',2),'limit.memberships',jsonb_build_object('value',100),
        'limit.storage_gb',jsonb_build_object('value',10),'limit.media_gb',jsonb_build_object('value',5))),
    'Criacao do plano de entrada'));
insert into plans_test_responses values('create_again',
  public.superadmin_plan_save('84400000-0000-4000-8000-000000000002',null,null,
    jsonb_build_object('name','Plano Essencial','code','essencial','description','Plano de entrada','status','active'),
    'Criacao do plano de entrada'));
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000003',null,null,'{"name":"Ruim","code":"Codigo Invalido","description":"x"}','motivo')$$,
  '22023','invalid_plan_code','plan code must be a slug');
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000004',null,null,'{"name":"Ruim","code":"ruim","description":"x","entitlements":{"feature.nope":{"enabled":true}}}','motivo')$$,
  '22023','invalid_entitlement','unknown entitlement key is rejected');
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000005',null,null,'{"name":"Ruim","code":"ruim","description":"x"}','')$$,
  '22023','reason_required','reason is mandatory');
reset role;

select is((select body->>'code' from plans_test_responses where label='create'),'essencial','create returns the plan by code');
select is((select (body->>'revision')::bigint from plans_test_responses where label='create'),1::bigint,'created plan starts at revision 1');
select is((select body->>'status' from plans_test_responses where label='create'),'active','created plan is active');
select is((select jsonb_typeof(body->'entitlements'->'feature.chat'->'enabled') from plans_test_responses where label='create'),'boolean','entitlements are returned as objects the client parses');
select is((select count(*) from public.plan_entitlements pe join public.plans p on p.id=pe.plan_id where p.code='essencial' and pe.status='active'),13::bigint,'13 entitlements persisted');
select is((select body->>'id' from plans_test_responses where label='create'),
  (select body->>'id' from plans_test_responses where label='create_again'),
  'same request_id returns the same plan (idempotent create)');
select is((select count(*) from public.plans where code='essencial'),1::bigint,'only one plan row was written');
select is((select count(*) from public.plan_change_receipts where request_id='84400000-0000-4000-8000-000000000002'),1::bigint,'replay writes no second receipt');
select is((select action from public.plan_change_receipts where request_id='84400000-0000-4000-8000-000000000002'),'create','create receipt records the action');
select is((select actor_person_id from public.plan_change_receipts where request_id='84400000-0000-4000-8000-000000000002'),
  '84200000-0000-4000-8000-000000000001'::uuid,'receipt records the acting person');

-- 13-21. Edicao com revisao otimista, conflito, codigo imutavel, get e list.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000001',
  'session_id','84110000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into plans_test_responses
select 'edit', public.superadmin_plan_save('84400000-0000-4000-8000-000000000006',(body->>'id')::uuid,1,
  jsonb_build_object('name','Plano Essencial Plus','code','essencial','description','Plano de entrada revisado','status','active',
    'entitlements',jsonb_build_object('feature.chat',jsonb_build_object('enabled',true),'limit.units',jsonb_build_object('value',3))),
  'Ajuste de nome e limite') from plans_test_responses where label='create';
select throws_ok(format($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000007',%L,1,'{"name":"Velho","code":"essencial","description":"x","status":"active"}','motivo')$$,
  (select body->>'id' from plans_test_responses where label='create')),
  '40001','plan_revision_conflict','stale expected_revision is rejected');
select throws_ok(format($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000008',%L,2,'{"name":"Novo","code":"outro","description":"x","status":"active"}','motivo')$$,
  (select body->>'id' from plans_test_responses where label='create')),
  '22023','plan_code_immutable','plan code cannot change on edit');
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000009','84900000-0000-4000-8000-000000000000',1,'{"name":"Novo","code":"x","description":"x"}','motivo')$$,
  'P0002','plan_not_found','editing an unknown plan is not found');
insert into plans_test_responses
select 'archive', public.superadmin_plan_save('84400000-0000-4000-8000-000000000010',(body->>'id')::uuid,2,
  jsonb_build_object('name','Plano Essencial Plus','code','essencial','description','Plano de entrada revisado','status','archived',
    'entitlements',jsonb_build_object('feature.chat',jsonb_build_object('enabled',true),'limit.units',jsonb_build_object('value',3))),
  'Arquivar plano') from plans_test_responses where label='create';
insert into plans_test_responses
select 'get', public.superadmin_plan_get((body->>'id')::uuid) from plans_test_responses where label='create';
select throws_ok($$select public.superadmin_plan_get('84900000-0000-4000-8000-000000000000')$$,
  'P0002','plan_not_found','get of an unknown plan is not found');
insert into plans_test_responses values('list', public.superadmin_plans_list('essen',null,null,1,11));
insert into plans_test_responses values('list_archived', public.superadmin_plans_list('','archived',null,1,11));
insert into plans_test_responses values('list_feature_chat', public.superadmin_plans_list('',null,'chat',1,11));
insert into plans_test_responses values('list_feature_now', public.superadmin_plans_list('',null,'now',1,11));
select throws_ok($$select public.superadmin_plans_list('','deleted',null,1,11)$$,
  '22023','invalid_status','unknown status filter is rejected');
select throws_ok($$select public.superadmin_plans_list('',null,null,0,11)$$,
  '22023','invalid_pagination','page below 1 is rejected');
-- Payload sem status usa o padrao 'active' (o cliente sempre envia; a RPC nao pode quebrar sem ele).
insert into plans_test_responses values('create_default_status',
  public.superadmin_plan_save('84400000-0000-4000-8000-000000000011',null,null,
    jsonb_build_object('name','Plano Sem Status','code','sem-status','description','Sem status no payload'),
    'Criacao sem status'));
reset role;

select is((select (body->>'revision')::bigint from plans_test_responses where label='edit'),2::bigint,'edit bumps the revision');
select is((select body->>'name' from plans_test_responses where label='edit'),'Plano Essencial Plus','edit persists the new name');
select is((select count(*) from public.plan_entitlements pe join public.plans p on p.id=pe.plan_id where p.code='essencial' and pe.status='active'),2::bigint,'each save replaces the whole entitlement set');
select is((select action from public.plan_change_receipts where request_id='84400000-0000-4000-8000-000000000010'),'archive','archiving is receipted as archive');
select is((select body->>'status' from plans_test_responses where label='get'),'archived','get reflects the persisted status');
select is((select (body->>'revision')::bigint from plans_test_responses where label='get'),3::bigint,'get reflects the persisted revision');
select is((select (body->>'used_by_institution_count')::int from plans_test_responses where label='get'),0,'get counts linked institutions');
select is((select (body->>'total_items')::int from plans_test_responses where label='list'),1,'search by name finds the plan');
select is((select body->'items'->0->>'code' from plans_test_responses where label='list'),'essencial','list item carries the code');
select is((select (body->>'total_items')::int from plans_test_responses where label='list_archived'),1,'status filter finds the archived plan');
select is((select (body->>'total_items')::int from plans_test_responses where label='list_feature_chat'),1,'feature filter matches an enabled feature');
select is((select (body->>'total_items')::int from plans_test_responses where label='list_feature_now'),0,'feature filter skips a disabled feature');
select is((select body->>'status' from plans_test_responses where label='create_default_status'),'active','missing status defaults to active');

-- 22-24. Ator escopado a uma instituicao (mesmo com plan.change no perfil) nao alcanca o catalogo da plataforma.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000003',
  'session_id','84110000-0000-4000-8000-000000000003',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_plan_save('84400000-0000-4000-8000-000000000012',null,null,'{"name":"Invasor","code":"invasor","description":"x","status":"active"}','motivo')$$,
  '42501','permission_denied','institution-scoped membership cannot save platform plans');
select throws_ok($$select public.superadmin_plans_list('',null,null,1,11)$$,
  '42501','permission_denied','institution-scoped membership cannot list platform plans');
select is(pg_temp.plans_visible_rows(),0::bigint,'authenticated sees no plan row outside the RPCs');
reset role;

-- 25. RLS ligado e forcado nas tres tabelas do catalogo.
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class
  where oid in ('public.plans'::regclass,'public.plan_entitlements'::regclass,'public.plan_change_receipts'::regclass)),
  'plans, entitlements and receipts keep RLS forced');

select * from finish();
rollback;
