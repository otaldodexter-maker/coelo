-- Somente replay LOCAL descartavel. Fixtures sinteticas com rollback. Nenhuma conta real.
-- Prova do candidato RETIDO 20260910171800_child_safety_platform_decision_v1.RETIDO-P32.sql
-- (P32, opcao b): ator de plataforma com child_safety.manage decide e muda ciclo de vida;
-- revisor exato da unidade continua decidindo; quem nao tem nenhuma das duas recebe P0002.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

-- Estrutura: as duas funcoes aceitam a alternativa de plataforma e preservam as
-- verificacoes que o teste de producao exige.
select ok(pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%child_safety_has_exact_unit_review%' and pg_get_functiondef(
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  like $$%has_platform_permission('child_safety.manage',a.institution_id)%$$,
  'decisao aceita revisor exato da unidade OU plataforma com child_safety.manage escopado');
select ok(pg_get_functiondef(
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure)
  like '%child_safety_can_administer%' and pg_get_functiondef(
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure)
  like $$%has_platform_permission('child_safety.manage',a.institution_id)%$$,
  'ciclo de vida aceita plataforma escopada OU administrador do contexto');
select ok((select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)'::regprocedure)
  and (select prosecdef and coalesce(array_to_string(proconfig,','),'')='search_path=""'
  from pg_proc where oid='app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)'::regprocedure),
  'security definer e search_path vazio preservados');

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

select ok(exists(select 1 from app_private.superadmin_internal_actor_people ap
  join public.platform_memberships pm on pm.id=ap.platform_membership_id and pm.status='active'
  where ap.internal_identity_id='c5329000-0000-4000-8000-000000000001'),
  'ponte de ator espelhou pessoa de servico e membership de plataforma do Owner');

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

-- (1) Ator de plataforma com child_safety.manage aprova o pedido 1.
select set_config('request.jwt.claims',jsonb_build_object('sub','c5328000-0000-4000-8000-000000000001',
  'session_id','c532f000-0000-4000-8000-000000000001','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.p32_platform_approve',public.child_safety_decide_authorization(
  'c5330000-0000-4000-8000-000000000001','c5327000-0000-4000-8000-000000000001',1,'approved',
  'P32 aprovado pela plataforma')::text,true);
select set_config('test.p32_platform_replay',public.child_safety_decide_authorization(
  'c5330000-0000-4000-8000-000000000001','c5327000-0000-4000-8000-000000000001',1,'approved',
  'P32 aprovado pela plataforma')::text,true);
-- (4) Versao obsoleta no pedido 2.
select throws_ok(
  $$select public.child_safety_decide_authorization(
    'c5330000-0000-4000-8000-000000000002','c5327000-0000-4000-8000-000000000002',99,'approved',
    'P32 versao obsoleta')$$,
  '40001','stale child safety version','versao obsoleta da serialization_failure ao ator de plataforma');
-- Pedido ja decidido nao pode ser decidido de novo, mesmo pela plataforma.
select throws_ok(
  $$select public.child_safety_decide_authorization(
    'c5330000-0000-4000-8000-000000000003','c5327000-0000-4000-8000-000000000001',2,'rejected',
    'P32 segunda decisao')$$,
  'P0002','child safety record unavailable','pedido ja aprovado nao volta a ser decidido');
-- (5) Ciclo de vida (suspended) pelo ator de plataforma sobre o pedido 1 aprovado.
select set_config('test.p32_platform_suspend',public.child_safety_change_lifecycle(
  'c5330000-0000-4000-8000-000000000004','c5327000-0000-4000-8000-000000000001',2,'suspended',
  'P32 suspenso pela plataforma')::text,true);
reset role;

select is(current_setting('test.p32_platform_approve')::jsonb->>'decision_status','approved',
  'plataforma com child_safety.manage aprova pedido pendente');
select is(current_setting('test.p32_platform_approve')::jsonb->>'lifecycle_status','active',
  'aprovacao pela plataforma ativa a autorizacao');
select is(current_setting('test.p32_platform_approve')::jsonb->>'version','2',
  'versao avanca para 2 apos a decisao');
select is(current_setting('test.p32_platform_replay')::jsonb,current_setting('test.p32_platform_approve')::jsonb,
  'mesmo request_id devolve o recibo idempotente');
select ok(exists(select 1 from public.authorized_person_authorizations a
  join app_private.superadmin_internal_actor_people ap on ap.person_id=a.decided_by_person_id
  where a.id='c5327000-0000-4000-8000-000000000001' and a.decision_status='approved'
    and a.status='suspended' and a.version=3 and a.decided_at is not null
    and ap.internal_identity_id='c5329000-0000-4000-8000-000000000001'
    and a.suspended_by_person_id=ap.person_id and a.suspension_reason='P32 suspenso pela plataforma'),
  'linha persistida: approved, suspensa, versao 3, decidida e suspensa pela pessoa de servico do Owner');
select is(current_setting('test.p32_platform_suspend')::jsonb->>'lifecycle_status','suspended',
  'change_lifecycle suspended pela plataforma responde suspended');
select is(current_setting('test.p32_platform_suspend')::jsonb->>'version','3',
  'ciclo de vida avanca a versao para 3');
select ok(exists(select 1 from audit.audit_logs l
  join app_private.superadmin_internal_actor_people ap on ap.person_id=l.actor_person_id
  where ap.internal_identity_id='c5329000-0000-4000-8000-000000000001'
    and l.action_code='child_safety.authorization.decide' and l.outcome='success'
    and l.object_id='c5327000-0000-4000-8000-000000000001'
    and l.actor_role_code='owner' and l.mfa_aal='aal2'),
  'auditoria da decisao registra pessoa de servico do Owner, papel owner e AAL');
select ok(exists(select 1 from audit.audit_logs l
  join app_private.superadmin_internal_actor_people ap on ap.person_id=l.actor_person_id
  where ap.internal_identity_id='c5329000-0000-4000-8000-000000000001'
    and l.action_code='child_safety.authorization.lifecycle' and l.outcome='success'
    and l.object_id='c5327000-0000-4000-8000-000000000001'
    and l.actor_role_code='owner'),
  'auditoria do ciclo de vida registra pessoa de servico do Owner e papel owner');
select ok(exists(select 1 from public.context_notification_events e
  join public.context_notification_recipients r on r.event_id=e.id
  where e.event_code='child_safety.authorization_decided'
    and e.object_id='c5327000-0000-4000-8000-000000000001'
    and r.person_id in ('c5323000-0000-4000-8000-000000000002','c5323000-0000-4000-8000-000000000004')
  group by e.id having count(distinct r.person_id)=2),
  'notificacao de decisao alcanca solicitante e revisor da unidade');

-- (2) Ator de plataforma SEM child_safety.manage recebe negativa sem distinguir existencia.
select set_config('request.jwt.claims',jsonb_build_object('sub','c5328000-0000-4000-8000-000000000002',
  'session_id','c532f000-0000-4000-8000-000000000002','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select throws_ok(
  $$select public.child_safety_decide_authorization(
    'c5330000-0000-4000-8000-000000000005','c5327000-0000-4000-8000-000000000003',1,'approved',
    'P32 sem permissao')$$,
  'P0002','child safety record unavailable','plataforma sem child_safety.manage nao decide');
select throws_ok(
  $$select public.child_safety_change_lifecycle(
    'c5330000-0000-4000-8000-000000000006','c5327000-0000-4000-8000-000000000001',3,'archived',
    'P32 sem permissao')$$,
  'P0002','child safety record unavailable','plataforma sem child_safety.manage nao muda ciclo de vida');
reset role;
select ok(exists(select 1 from public.authorized_person_authorizations
  where id='c5327000-0000-4000-8000-000000000003' and decision_status='pending' and version=1),
  'pedido 3 permanece pendente e sem versao alterada apos a negativa');

-- (3) Revisor exato da unidade continua decidindo (pedido 2).
select set_config('request.jwt.claims',jsonb_build_object('sub','c5328000-0000-4000-8000-000000000003',
  'session_id','c532f000-0000-4000-8000-000000000003','aal','aal2','role','authenticated')::text,true);
set local role authenticated;
select set_config('test.p32_reviewer_approve',public.child_safety_decide_authorization(
  'c5330000-0000-4000-8000-000000000007','c5327000-0000-4000-8000-000000000002',1,'approved',
  'P32 aprovado pelo revisor da unidade')::text,true);
reset role;
select is(current_setting('test.p32_reviewer_approve')::jsonb->>'decision_status','approved',
  'revisor exato da unidade continua aprovando');
select ok(exists(select 1 from public.authorized_person_authorizations
  where id='c5327000-0000-4000-8000-000000000002' and decision_status='approved' and status='active'
    and version=2 and decided_by_person_id='c5323000-0000-4000-8000-000000000004'),
  'decisao do revisor persiste com decided_by do revisor');
select ok(exists(select 1 from audit.audit_logs
  where actor_person_id='c5323000-0000-4000-8000-000000000004'
    and action_code='child_safety.authorization.decide'
    and object_id='c5327000-0000-4000-8000-000000000002'
    and actor_role_code='p32_reviewer'),
  'auditoria do revisor registra o papel institucional do revisor');

-- (6) anon sem execute nas publicas.
select ok(not has_function_privilege('anon',
  'public.child_safety_decide_authorization(uuid,uuid,bigint,text,text)','EXECUTE')
  and not has_function_privilege('anon',
  'public.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)','EXECUTE')
  and not has_function_privilege('anon',
  'app_private.child_safety_decide_authorization(uuid,uuid,bigint,text,text)','EXECUTE')
  and not has_function_privilege('anon',
  'app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)','EXECUTE'),
  'anon nao tem execute nas funcoes publicas nem nas privadas');
set local role anon;
select throws_ok(
  $$select public.child_safety_decide_authorization(
    'c5330000-0000-4000-8000-000000000008','c5327000-0000-4000-8000-000000000003',1,'approved','P32 anon')$$,
  '42501','permission denied for function child_safety_decide_authorization',
  'anon nao chama a decisao');
select throws_ok(
  $$select public.child_safety_change_lifecycle(
    'c5330000-0000-4000-8000-000000000009','c5327000-0000-4000-8000-000000000001',3,'archived','P32 anon')$$,
  '42501','permission denied for function child_safety_change_lifecycle',
  'anon nao muda ciclo de vida');
reset role;

select * from finish();
rollback;
