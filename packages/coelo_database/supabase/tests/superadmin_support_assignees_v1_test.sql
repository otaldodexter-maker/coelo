begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

-- Fixtures no realm people (mesma forma de superadmin_support_create_internal_scope_test.sql).
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at) values
 ('84100000-0000-4000-8000-000000000001','authenticated','authenticated','assign-owner@test.invalid',now(),now(),now()),
 ('84100000-0000-4000-8000-000000000002','authenticated','authenticated','assign-denied@test.invalid',now(),now(),now());
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('84110000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001',now(),now(),'aal1',now()+interval '1 hour'),
 ('84110000-0000-4000-8000-000000000002','84100000-0000-4000-8000-000000000002',now(),now(),'aal1',now()+interval '1 hour');
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('84200000-0000-4000-8000-000000000001','adult','Suporte','Owner','Suporte Owner','active'),
 ('84200000-0000-4000-8000-000000000002','adult','Suporte','Denied','Suporte Denied','active'),
 ('84200000-0000-4000-8000-000000000003','adult','Escopo','Instituicao','Escopo Instituicao','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('84200000-0000-4000-8000-000000000001','84100000-0000-4000-8000-000000000001','active'),
 ('84200000-0000-4000-8000-000000000002','84100000-0000-4000-8000-000000000002','active');
insert into public.platform_roles(id,code,name,status,is_system,max_scope_kind) values
 ('84300000-0000-4000-8000-000000000001','support_assign_test_denied','Support assign denied','active',true,'platform');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,mfa_required)
select '84500000-0000-4000-8000-000000000001','84200000-0000-4000-8000-000000000001',id,'active','platform',false
from public.platform_roles where code='owner';
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,mfa_required) values
 ('84500000-0000-4000-8000-000000000002','84200000-0000-4000-8000-000000000002','84300000-0000-4000-8000-000000000001','active','platform',false);
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '84300000-0000-4000-8000-000000000001',id,'allow','active'
from public.platform_permissions where code='platform.read';
-- Membership de instituicao (papel owner, escopo institution): nao pode ser responsavel.
insert into public.institutions(id,public_name,slug,status) values
 ('84600000-0000-4000-8000-000000000001','Instituicao Suporte','instituicao-suporte-assign','active');
insert into public.platform_memberships(id,person_id,role_id,status,scope_kind,scope_institution_id,mfa_required)
select '84500000-0000-4000-8000-000000000003','84200000-0000-4000-8000-000000000003',id,'active','institution',
  '84600000-0000-4000-8000-000000000001',false
from public.platform_roles where code='owner';

create temporary table support_assign_responses(label text primary key, body jsonb not null);
grant select, insert on support_assign_responses to authenticated;

-- Sem sessao: nega antes de qualquer leitura.
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.superadmin_support_team_members()$$,
  '28000','authentication_required','anonymous session cannot list the support team');
select throws_ok(
  $$select public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000000','84700000-0000-4000-8000-000000000000',1,null)$$,
  '28000','authentication_required','anonymous session cannot assign a ticket');
reset role;

-- Ator sem support.manage: nega mesmo autenticado.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000002',
  'session_id','84110000-0000-4000-8000-000000000002',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select throws_ok($$select public.superadmin_support_team_members()$$,
  '42501','permission_denied','actor without support.manage cannot list the support team');
select throws_ok(
  $$select public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000001','84700000-0000-4000-8000-000000000000',1,null)$$,
  '42501','permission_denied','actor without support.manage cannot assign a ticket');
reset role;

-- Owner de plataforma: equipe, chamado e atribuicao.
select set_config('request.jwt.claims',jsonb_build_object(
  'sub','84100000-0000-4000-8000-000000000001',
  'session_id','84110000-0000-4000-8000-000000000001',
  'aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into support_assign_responses values('team', public.superadmin_support_team_members());
insert into support_assign_responses values('create',
  public.superadmin_support_create('84400000-0000-4000-8000-000000000002',null,null,
    'Responsavel do chamado','support','support','Sem responsavel definido','QA Superadmin','normal'));
insert into support_assign_responses
select 'get_before', public.superadmin_support_get((body->>'id')::uuid) from support_assign_responses where label='create';
insert into support_assign_responses
select 'assign', public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000003',
  (body->>'id')::uuid,1,'84500000-0000-4000-8000-000000000001') from support_assign_responses where label='create';
insert into support_assign_responses
select 'assign_again', public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000003',
  (body->>'id')::uuid,1,'84500000-0000-4000-8000-000000000001') from support_assign_responses where label='create';
insert into support_assign_responses
select 'get_after', public.superadmin_support_get((body->>'id')::uuid) from support_assign_responses where label='create';
select throws_ok(
  format($f$select public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000004',%L,1,'84500000-0000-4000-8000-000000000001')$f$,
    (select body->>'id' from support_assign_responses where label='create')),
  '40001','support_revision_conflict','stale revision is rejected');
select throws_ok(
  format($f$select public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000005',%L,2,'84500000-0000-4000-8000-0000000000ff')$f$,
    (select body->>'id' from support_assign_responses where label='create')),
  '22023','assignee_invalid','unknown membership cannot be assignee');
select throws_ok(
  format($f$select public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000006',%L,2,'84500000-0000-4000-8000-000000000003')$f$,
    (select body->>'id' from support_assign_responses where label='create')),
  '22023','assignee_invalid','institution-scoped membership cannot be assignee');
insert into support_assign_responses
select 'clear', public.superadmin_support_set_assignee('84400000-0000-4000-8000-000000000007',
  (body->>'id')::uuid,2,null) from support_assign_responses where label='create';
insert into support_assign_responses
select 'get_cleared', public.superadmin_support_get((body->>'id')::uuid) from support_assign_responses where label='create';
insert into support_assign_responses values('list',
  public.superadmin_support_list('Responsavel do chamado',null,null,null,null,false,1,25));
reset role;

-- Equipe de suporte.
select ok((select body->'items' @> jsonb_build_array(jsonb_build_object('membership_id','84500000-0000-4000-8000-000000000001'))
  from support_assign_responses where label='team'),'team lists the acting owner membership');
select ok(not (select body->'items' @> jsonb_build_array(jsonb_build_object('membership_id','84500000-0000-4000-8000-000000000002'))
  from support_assign_responses where label='team'),'team omits membership without support.manage');
select ok(not (select body->'items' @> jsonb_build_array(jsonb_build_object('membership_id','84500000-0000-4000-8000-000000000003'))
  from support_assign_responses where label='team'),'team omits institution-scoped membership');
select is((select i->>'display_name' from support_assign_responses, jsonb_array_elements(body->'items') i
  where label='team' and i->>'membership_id'='84500000-0000-4000-8000-000000000001'),'Suporte Owner','team item carries the person display name');
select is((select i->>'initials' from support_assign_responses, jsonb_array_elements(body->'items') i
  where label='team' and i->>'membership_id'='84500000-0000-4000-8000-000000000001'),'SO','team item derives initials from the name');
select is((select i->>'role' from support_assign_responses, jsonb_array_elements(body->'items') i
  where label='team' and i->>'membership_id'='84500000-0000-4000-8000-000000000001'),'owner','team item carries the platform role code');
select is((select (body->>'total')::int from support_assign_responses where label='team'),
  (select jsonb_array_length(body->'items') from support_assign_responses where label='team'),'team total matches items');

-- Envelope de get e atribuicao.
select ok((select body ? 'assignee_membership_id' and body->>'assignee_membership_id' is null
  from support_assign_responses where label='get_before'),'get carries a null assignee before assignment');
select is((select (body->>'revision')::bigint from support_assign_responses where label='assign'),2::bigint,'assignment bumps the revision');
select is((select body->>'assignee_membership_id' from support_assign_responses where label='assign'),
  '84500000-0000-4000-8000-000000000001','assignment persists the membership');
select is((select body->>'assignee_membership_id' from support_assign_responses where label='get_after'),
  '84500000-0000-4000-8000-000000000001','get returns the assignee after assignment');
select is((select body from support_assign_responses where label='assign_again'),
  (select body from support_assign_responses where label='assign'),'same request_id replays the same receipt');
select is((select count(*) from public.support_command_receipts where request_id='84400000-0000-4000-8000-000000000003'),
  1::bigint,'replay writes no second receipt');
select is((select (body->>'revision')::bigint from support_assign_responses where label='clear'),3::bigint,'clearing bumps the revision');
select ok((select body ? 'assignee_membership_id' and body->>'assignee_membership_id' is null
  from support_assign_responses where label='clear'),'clearing with null removes the assignee');
select ok((select body ? 'assignee_membership_id' and body->>'assignee_membership_id' is null
  from support_assign_responses where label='get_cleared'),'get returns a null assignee after clearing');
select is((select assigned_to_membership_id from public.support_sessions where subject='Responsavel do chamado'),
  null,'table row has no assignee after clearing');

-- Auditoria.
select is((select count(*) from audit.support_session_actions a join public.support_sessions s on s.id=a.support_session_id
  where s.subject='Responsavel do chamado' and a.action_code='support.assign'),2::bigint,'assign and clear are audited once each (replay adds none)');
-- Os dois eventos nascem na mesma transacao (mesmo occurred_at); identifica-os pelo conteudo.
select is((select count(*) from audit.support_session_actions a join public.support_sessions s on s.id=a.support_session_id
  where s.subject='Responsavel do chamado' and a.action_code='support.assign'
    and a.metadata_json = jsonb_build_object('actor_person_id','84200000-0000-4000-8000-000000000001',
      'assignee_membership_id','84500000-0000-4000-8000-000000000001','previous_assignee_membership_id',null)),
  1::bigint,'assign event records actor, assignee and null previous assignee');
select is((select count(*) from audit.support_session_actions a join public.support_sessions s on s.id=a.support_session_id
  where s.subject='Responsavel do chamado' and a.action_code='support.assign'
    and a.metadata_json = jsonb_build_object('actor_person_id','84200000-0000-4000-8000-000000000001',
      'assignee_membership_id',null,'previous_assignee_membership_id','84500000-0000-4000-8000-000000000001')),
  1::bigint,'clear event records null assignee and the previous assignee');
select is((select (body->>'total_items')::int from support_assign_responses where label='list'),1,'directory still lists the ticket');

select * from finish();
rollback;
