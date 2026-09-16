-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova da migration 20260916152000_child_safety_lifecycle_timeout_fix_v1 (R14 Sessao 8,
-- ADR 0041 D4): versao defasada nas quatro RPCs de mutacao de Seguranca da crianca
-- responde SQLSTATE PT409 (HTTP 409 no PostgREST, sem retentativa) e nao muta a linha;
-- a versao correta continua mudando o ciclo de vida com recibo idempotente.
-- Contexto: SQLSTATE 40001 (serialization_failure) faz o PostgREST 14.5 reexecutar a
-- transacao sem limite ate o 504 do gateway (reproduzido no espelho em 16/09/2026).
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

-- Estrutura: nenhuma das quatro funcoes usa serialization_failure; todas usam PT409.
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('child_safety_change_lifecycle',
    'child_safety_decide_authorization','child_safety_edit_pending_authorization',
    'child_safety_acknowledge_alert') and p.prosrc like '%serialization_failure%'),0,
  'nenhuma RPC de mutacao de child_safety levanta serialization_failure (40001)');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname in ('child_safety_change_lifecycle',
    'child_safety_decide_authorization','child_safety_edit_pending_authorization',
    'child_safety_acknowledge_alert') and p.prosrc like $$%errcode='PT409'%$$),4,
  'as quatro RPCs sinalizam versao defasada com PT409');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure),
  'change_lifecycle preserva security definer e search_path vazio');
select ok(has_function_privilege('authenticated',
  'public.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)','execute')
  and has_function_privilege('authenticated',
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)','execute'),
  'grants de execute para authenticated preservados no wrapper e na funcao privada');

-- Catalogos sinteticos na forma canonica de producao.
insert into public.institution_types(id,code,name,status) values
('c5320000-0000-4000-8000-000000000001','p32-safety-type','P32 safety type','active');
insert into public.unit_types(id,code,name,status) values
('c5320000-0000-4000-8000-000000000002','p32-safety-unit','P32 safety unit','active');
insert into public.institutions(id,public_name,slug,institution_type_id) values
('c5321000-0000-4000-8000-000000000001','P32 synthetic A','p32-safety-a','c5320000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,unit_type_id,name,slug,handle) values
('c5322000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','c5320000-0000-4000-8000-000000000002','P32 unit A1','a1','p32unita1'),
('c5322000-0000-4000-8000-000000000002','c5321000-0000-4000-8000-000000000001','c5320000-0000-4000-8000-000000000002','P32 unit A2','a2','p32unita2');
-- A baseline de producao possui a pessoa tecnica Coelo. O trigger global de
-- follows usa esse id como follower/target e a fixture deve semeá-lo antes
-- de inserir qualquer pessoa ativa, sem desabilitar o trigger.
insert into public.people(id,person_type,first_name,last_name,display_name)
values ('c0e10000-0000-4000-8000-000000000001','adult','Coelo','Sistema','Coelo Sistema');
insert into public.people(id,person_type,first_name,last_name,display_name) values
('c5323000-0000-4000-8000-000000000001','child','P32','Synthetic','P32 synthetic child'),
('c5323000-0000-4000-8000-000000000002','adult','P32','Synthetic','P32 synthetic guardian'),
('c5323000-0000-4000-8000-000000000003','adult','P32','Synthetic','P32 synthetic authorized adult'),
('c5323000-0000-4000-8000-000000000004','adult','P32','Synthetic','P32 synthetic unit reviewer');
insert into public.child_contexts(id,child_person_id,institution_id) values
('c5324000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001');
insert into public.child_unit_links(child_context_id,unit_id,status,accepted_by,accepted_at) values
('c5324000-0000-4000-8000-000000000001','c5322000-0000-4000-8000-000000000001','active','c5323000-0000-4000-8000-000000000002',now());
insert into public.family_relationship_types(id,code,name) values
('c5325000-0000-4000-8000-000000000001','p32_uncle','P32 uncle');
insert into public.authorized_people(id,institution_id,display_name,person_id,owner_guardian_person_id) values
('c5326000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','P32 synthetic authorized adult',
 'c5323000-0000-4000-8000-000000000003','c5323000-0000-4000-8000-000000000002');
-- Tres pedidos pendentes: 1 plataforma decide + ciclo de vida; 2 versao obsoleta + revisor;
-- 3 plataforma sem child_safety.manage.
insert into public.authorized_person_authorizations(id,authorized_person_id,institution_id,child_context_id,unit_id,
  relationship_type_id,created_by_person_id,status,decision_status,request_reason)
select ('c5327000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'c5326000-0000-4000-8000-000000000001',
  'c5321000-0000-4000-8000-000000000001','c5324000-0000-4000-8000-000000000001','c5322000-0000-4000-8000-000000000001',
  'c5325000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000002','inactive','pending','P32 synthetic request'
from generate_series(1,3) n;
insert into public.authorized_person_authorization_capabilities(authorization_id,capability_code)
select ('c5327000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'pickup' from generate_series(1,3) n;

-- Ator de plataforma COM child_safety.manage (Owner), via ponte de ator interno.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
('c5328000-0000-4000-8000-000000000001','authenticated','authenticated','p32-owner@invalid.test',now(),now(),now(),'{}','{}'),
('c5328000-0000-4000-8000-000000000002','authenticated','authenticated','p32-reader@invalid.test',now(),now(),now(),'{}','{}'),
('c5328000-0000-4000-8000-000000000003','authenticated','authenticated','p32-reviewer@invalid.test',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_identities(id) values
('c5329000-0000-4000-8000-000000000001'),('c5329000-0000-4000-8000-000000000002');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
('c532a000-0000-4000-8000-000000000001','c5329000-0000-4000-8000-000000000001','c5328000-0000-4000-8000-000000000001'),
('c532a000-0000-4000-8000-000000000002','c5329000-0000-4000-8000-000000000002','c5328000-0000-4000-8000-000000000002');
-- Ator de plataforma SEM child_safety.manage: papel sintetico so com child_safety.read.
insert into public.platform_roles(id,code,name,max_scope_kind) values
('c532b000-0000-4000-8000-000000000001','p32_safety_reader','P32 synthetic reader','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect)
select 'c532b000-0000-4000-8000-000000000001',id,'allow' from public.platform_permissions where code='child_safety.read';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select 'c532c000-0000-4000-8000-000000000001','c5329000-0000-4000-8000-000000000001',id,'platform'
from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind) values
('c532c000-0000-4000-8000-000000000002','c5329000-0000-4000-8000-000000000002','c532b000-0000-4000-8000-000000000001','platform');


-- Revisor exato da unidade A1.
insert into public.person_auth_links(person_id,auth_user_id) values
('c5323000-0000-4000-8000-000000000004','c5328000-0000-4000-8000-000000000003');
insert into public.institution_memberships(id,person_id,institution_id,role_code) values
('c532d000-0000-4000-8000-000000000001','c5323000-0000-4000-8000-000000000004','c5321000-0000-4000-8000-000000000001','p32_reviewer');
insert into public.institution_roles(id,institution_id,code,name,max_scope_kind) values
('c532e000-0000-4000-8000-000000000001','c5321000-0000-4000-8000-000000000001','p32_unit_reviewer','P32 unit reviewer','unit');
insert into public.institution_role_permissions(role_id,permission_id)
select 'c532e000-0000-4000-8000-000000000001',id from public.institution_permissions where code='authorized_people.manage';
insert into public.institution_role_assignments(membership_id,role_id,scope_kind,scope_unit_id) values
('c532d000-0000-4000-8000-000000000001','c532e000-0000-4000-8000-000000000001','unit','c5322000-0000-4000-8000-000000000001');

-- Owner de plataforma aprova o pedido 1 (fica approved/active, versao 2).
select set_config('request.jwt.claims',jsonb_build_object('sub','c5328000-0000-4000-8000-000000000001',
  'session_id','c532f000-0000-4000-8000-000000000001','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.s8_approve',public.child_safety_decide_authorization(
  'c5330000-0000-4000-8000-000000000101','c5327000-0000-4000-8000-000000000001',1,'approved',
  'S8 aprovado pela plataforma')::text,true);

-- (a) change_lifecycle com versao defasada: PT409, sem mutacao.
select throws_ok(
  $$select public.child_safety_change_lifecycle(
    'c5330000-0000-4000-8000-000000000102','c5327000-0000-4000-8000-000000000001',99,'suspended',
    'S8 versao defasada')$$,
  'PT409','stale child safety version','change_lifecycle com versao defasada responde PT409');
-- (b) decide com versao defasada no pedido 2 (pendente): PT409.
select throws_ok(
  $$select public.child_safety_decide_authorization(
    'c5330000-0000-4000-8000-000000000103','c5327000-0000-4000-8000-000000000002',99,'approved',
    'S8 versao defasada')$$,
  'PT409','stale child safety version','decide_authorization com versao defasada responde PT409');
-- (c) edit_pending com versao defasada no pedido 3 (pendente): PT409.
select throws_ok(
  $$select public.child_safety_edit_pending_authorization(
    'c5330000-0000-4000-8000-000000000104','c5327000-0000-4000-8000-000000000003',99,
    '{"request_reason":"S8 edicao","relationship_code":"p32_uncle","capability_codes":["pickup"]}'::jsonb)$$,
  'PT409','stale child safety version','edit_pending_authorization com versao defasada responde PT409');
-- (d) versao correta: suspende e avanca a versao; replay idempotente.
select set_config('test.s8_suspend',public.child_safety_change_lifecycle(
  'c5330000-0000-4000-8000-000000000105','c5327000-0000-4000-8000-000000000001',2,'suspended',
  'S8 suspenso pela plataforma')::text,true);
select set_config('test.s8_replay',public.child_safety_change_lifecycle(
  'c5330000-0000-4000-8000-000000000105','c5327000-0000-4000-8000-000000000001',2,'suspended',
  'S8 suspenso pela plataforma')::text,true);
reset role;

select is(current_setting('test.s8_approve')::jsonb->>'version','2','pedido 1 aprovado na versao 2');
select is((select version from public.authorized_person_authorizations
  where id='c5327000-0000-4000-8000-000000000002'),1::bigint,
  'pedido 2 permanece na versao 1 apos a negativa PT409 (sem mutacao)');
select is((select version from public.authorized_person_authorizations
  where id='c5327000-0000-4000-8000-000000000003'),1::bigint,
  'pedido 3 permanece na versao 1 apos a negativa PT409 (sem mutacao)');
select is(current_setting('test.s8_suspend')::jsonb->>'lifecycle_status','suspended',
  'versao correta suspende a autorizacao');
select is(current_setting('test.s8_suspend')::jsonb->>'version','3','ciclo de vida avanca para a versao 3');
select is(current_setting('test.s8_replay'),current_setting('test.s8_suspend'),
  'mesmo request_id devolve o recibo idempotente');
select is((select status::text||'/'||version::text from public.authorized_person_authorizations
  where id='c5327000-0000-4000-8000-000000000001'),'suspended/3',
  'linha persistida: suspensa na versao 3');
select is((select count(*)::int from audit.audit_logs where object_id='c5327000-0000-4000-8000-000000000001'
  and action_code='child_safety.authorization.lifecycle' and outcome='success'),1,
  'auditoria do ciclo de vida registrada uma unica vez (replay nao duplica)');

select * from finish();
rollback;
