begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

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
-- OQ-028: mapeamento A entre ticket_status (UX) e o enum status.
reset role;
create temporary table sid as select (body->>'id')::uuid id from support_assign_responses where label='create';
grant select on sid to authenticated;
select is((select status::text from public.support_sessions where id=(select id from sid)),'open','Novo nasce open');
set local role authenticated;
insert into support_assign_responses select 'st_prog', public.superadmin_support_set_status('84400000-0000-4000-8000-000000000011',id,'in_progress',1) from sid;
reset role;
select is((select status::text from public.support_sessions where id=(select id from sid)),'pending','Em andamento vira pending');
set local role authenticated;
insert into support_assign_responses select 'st_wait', public.superadmin_support_set_status('84400000-0000-4000-8000-000000000012',id,'waiting_requester',2) from sid;
reset role;
select is((select status::text||'/'||ticket_status from public.support_sessions where id=(select id from sid)),'pending/waiting_requester','Aguardando solicitante e pending com a flag no ticket_status');
set local role authenticated;
insert into support_assign_responses select 'st_done', public.superadmin_support_set_status('84400000-0000-4000-8000-000000000013',id,'completed',3) from sid;
reset role;
select is((select status::text from public.support_sessions where id=(select id from sid)),'resolved','Concluido vira resolved');
select is((select body->>'closure_reason' from support_assign_responses where label='st_done'),null,'concluido normal nao tem motivo de encerramento');
set local role authenticated;
insert into support_assign_responses select 'st_new', public.superadmin_support_set_status('84400000-0000-4000-8000-000000000014',id,'new',4) from sid;
reset role;
select is((select status::text from public.support_sessions where id=(select id from sid)),'open','voltar a Novo reabre como open');
update public.support_sessions set status='expired' where id=(select id from sid);
select is((select ticket_status from public.support_sessions where id=(select id from sid)),'completed','expirado aparece como Concluido');
set local role authenticated;
insert into support_assign_responses select 'get_expired', public.superadmin_support_get(id) from sid;
select is((select (body->>'status')||'/'||(body->>'closure_reason') from support_assign_responses where label='get_expired'),'completed/expired','get expoe Concluido com motivo expired');
insert into support_assign_responses values('list_expired', public.superadmin_support_list('',array['completed'],null,null,null,false,1,25));
select ok((select bool_or(item->>'closure_reason'='expired') from support_assign_responses, jsonb_array_elements(body->'items') item where label='list_expired'),'list expoe o motivo de encerramento');
select * from finish(); rollback;
