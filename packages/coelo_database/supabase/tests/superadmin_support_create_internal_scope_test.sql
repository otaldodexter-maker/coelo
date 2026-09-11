begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- Fixtures no realm people (a ponte com o realm interno e pacote do coordenador).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at) values
 ('83100000-0000-4000-8000-000000000001','authenticated','authenticated','support-owner@test.invalid',now(),now(),now()),
 ('83100000-0000-4000-8000-000000000002','authenticated','authenticated','support-denied@test.invalid',now(),now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('83110000-0000-4000-8000-000000000001','83100000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
 ('83110000-0000-4000-8000-000000000002','83100000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('83200000-0000-4000-8000-000000000001','adult','Support','Owner','Support Owner','active'),
 ('83200000-0000-4000-8000-000000000002','adult','Support','Denied','Support Denied','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('83200000-0000-4000-8000-000000000001','83100000-0000-4000-8000-000000000001','active'),
 ('83200000-0000-4000-8000-000000000002','83100000-0000-4000-8000-000000000002','active');
insert into public.platform_roles(id,code,name,status,is_system) values
 ('83300000-0000-4000-8000-000000000001','support_test_denied','Support denied','active',true);
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '83200000-0000-4000-8000-000000000001',id,'active','platform',false
from public.platform_roles where code='owner';
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required) values
 ('83200000-0000-4000-8000-000000000002','83300000-0000-4000-8000-000000000001','active','platform',false);
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '83300000-0000-4000-8000-000000000001',id,'allow','active'
from public.platform_permissions where code='platform.read';

create temporary table support_test_responses(label text primary key, body jsonb not null);
grant select, insert on support_test_responses to authenticated;

-- Sem sessao: nega antes de qualquer leitura.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_support_create('83400000-0000-4000-8000-000000000000',null,null,'Assunto','support','support','Relato','Solicitante','normal')$$,
  '28000','authentication_required','anonymous session cannot open an internal ticket');
reset role;

-- Ator sem support.manage: nega mesmo autenticado no realm people.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','83100000-0000-4000-8000-000000000002',
  'session_id','83110000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(
  $$select public.superadmin_support_create('83400000-0000-4000-8000-000000000001',null,null,'Assunto','support','support','Relato','Solicitante','normal')$$,
  '42501','permission_denied','actor without support.manage cannot open a ticket');
reset role;

-- Owner de plataforma: chamado interno sem instituicao.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','83100000-0000-4000-8000-000000000001',
  'session_id','83110000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into support_test_responses values('create',
  public.superadmin_support_create('83400000-0000-4000-8000-000000000002',null,null,
    'Botao de Bug','activities','activity_directory','Tela travou ao salvar','QA Superadmin','normal'));
insert into support_test_responses values('create_again',
  public.superadmin_support_create('83400000-0000-4000-8000-000000000002',null,null,
    'Botao de Bug','activities','activity_directory','Tela travou ao salvar','QA Superadmin','normal'));
select throws_ok(
  $$select public.superadmin_support_create('83400000-0000-4000-8000-000000000003',null,'83600000-0000-4000-8000-000000000001','Assunto','support','support','Relato','Solicitante','normal')$$,
  '22023','invalid_support_request','unit without institution is rejected');
select throws_ok(
  $$select public.superadmin_support_create('83400000-0000-4000-8000-000000000004',null,null,'Assunto','support','support','Relato','Solicitante','absurd')$$,
  '22023','invalid_support_request','unknown priority is rejected');
reset role;

select is((select body->>'status' from support_test_responses where label='create'),'new','internal ticket opens as new');
select is((select (body->>'revision')::bigint from support_test_responses where label='create'),1::bigint,'internal ticket starts at revision 1');
select is((select body->>'institution_id' from support_test_responses where label='create'),null,'internal ticket carries no institution');
select is((select body->>'id' from support_test_responses where label='create'),
  (select body->>'id' from support_test_responses where label='create_again'),
  'same request_id returns the same ticket (idempotent create)');
select is((select count(*) from public.support_sessions where subject='Botao de Bug'),1::bigint,'only one session row was written');
select is((select scope_kind from public.support_sessions where subject='Botao de Bug'),'platform','ticket without institution is platform scoped');
select is((select reason_code from public.support_sessions where subject='Botao de Bug'),'internal_report','reason_code is filled (NOT NULL in production)');
select is((select opened_by_person_id from public.support_sessions where subject='Botao de Bug'),
  '83200000-0000-4000-8000-000000000001'::uuid,'ticket records the acting person');
select is((select count(*) from audit.support_session_actions a join public.support_sessions s on s.id=a.support_session_id
  where s.subject='Botao de Bug' and a.action_code='support.create'),1::bigint,'create is audited once');

-- Responder e mudar status sobre o chamado criado.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','83100000-0000-4000-8000-000000000001',
  'session_id','83110000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into support_test_responses
select 'reply', public.superadmin_support_reply('83400000-0000-4000-8000-000000000005',
  (body->>'id')::uuid,'Estamos verificando.',1) from support_test_responses where label='create';
insert into support_test_responses
select 'status', public.superadmin_support_set_status('83400000-0000-4000-8000-000000000006',
  (body->>'id')::uuid,'in_progress',2) from support_test_responses where label='create';
insert into support_test_responses values('list',
  public.superadmin_support_list('Botao de Bug',null,null,null,null,false,1,25));
reset role;

select is((select (body->>'revision')::bigint from support_test_responses where label='reply'),2::bigint,'reply bumps the revision');
select is((select jsonb_array_length(body->'messages') from support_test_responses where label='reply'),1,'reply is stored as a support message');
select is((select body->>'status' from support_test_responses where label='status'),'in_progress','status change persists');
select is((select (body->>'total_items')::int from support_test_responses where label='list'),1,'directory lists the internal ticket');

select * from finish();
rollback;
