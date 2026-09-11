-- P32 regra alvo: politicas macro da unidade + notificacoes no sino para unidade,
-- hierarquia da crianca e demais responsaveis.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

insert into public.institution_types(id,code,name,status) values
 ('9f080000-0000-4000-8000-000000000001','p32-test','P32','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f080000-0000-4000-8000-000000000010','P32 A','p32-a','active','9f080000-0000-4000-8000-000000000001'),
 ('9f080000-0000-4000-8000-000000000020','P32 B','p32-b','active','9f080000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name,status) values ('9f080000-0000-4000-8000-000000000002','p32-unit','Unidade P32','active');
insert into public.units(id,institution_id,unit_type_id,name,slug,status,handle) values
 ('9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000002','Unidade A1','p32-a1','active','u.p32a1'),
 ('9f080000-0000-4000-8000-000000000012','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000002','Unidade A2','p32-a2','active','u.p32a2');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('9f080000-0000-4000-8000-000000000013','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000011','Turma A1-1','active');
-- pessoas: 2 responsaveis, crianca, coordenadora (unidade A1), professora (turma), secretaria (instituicao), profissional atribuido, professora de outra unidade
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9f080000-0000-4000-8000-000000000061','adult','Resp','Um','Resp Um','active'),
 ('9f080000-0000-4000-8000-000000000062','adult','Resp','Dois','Resp Dois','active'),
 ('9f080000-0000-4000-8000-000000000063','child','Crianca','P32','Crianca P32','active'),
 ('9f080000-0000-4000-8000-000000000064','adult','Coord','A1','Coord A1','active'),
 ('9f080000-0000-4000-8000-000000000065','adult','Prof','Turma','Prof Turma','active'),
 ('9f080000-0000-4000-8000-000000000066','adult','Secretaria','Inst','Secretaria Inst','active'),
 ('9f080000-0000-4000-8000-000000000067','adult','Prof','Atribuido','Prof Atribuido','active'),
 ('9f080000-0000-4000-8000-000000000068','adult','Prof','OutraUnidade','Prof OutraUnidade','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,scope_group_id) values
 ('9f080000-0000-4000-8000-000000000074','9f080000-0000-4000-8000-000000000064','9f080000-0000-4000-8000-000000000010','coordinator','active','unit','9f080000-0000-4000-8000-000000000011',null),
 ('9f080000-0000-4000-8000-000000000075','9f080000-0000-4000-8000-000000000065','9f080000-0000-4000-8000-000000000010','teacher','active','group','9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000013'),
 ('9f080000-0000-4000-8000-000000000076','9f080000-0000-4000-8000-000000000066','9f080000-0000-4000-8000-000000000010','secretary','active','institution',null,null),
 ('9f080000-0000-4000-8000-000000000077','9f080000-0000-4000-8000-000000000067','9f080000-0000-4000-8000-000000000010','teacher','active','unit','9f080000-0000-4000-8000-000000000012',null),
 ('9f080000-0000-4000-8000-000000000078','9f080000-0000-4000-8000-000000000068','9f080000-0000-4000-8000-000000000010','teacher','active','unit','9f080000-0000-4000-8000-000000000012',null);
insert into public.family_relationship_types(id,code,name) values ('9f080000-0000-4000-8000-000000000090','p32_resp','Responsavel P32');
insert into public.guardian_links(id,guardian_person_id,child_person_id,relation_type,relationship_type_id) values
 ('9f080000-0000-4000-8000-000000000081','9f080000-0000-4000-8000-000000000061','9f080000-0000-4000-8000-000000000063','responsavel','9f080000-0000-4000-8000-000000000090'),
 ('9f080000-0000-4000-8000-000000000082','9f080000-0000-4000-8000-000000000062','9f080000-0000-4000-8000-000000000063','responsavel','9f080000-0000-4000-8000-000000000090');
insert into public.child_contexts(id,child_person_id,institution_id) values
 ('9f080000-0000-4000-8000-000000000091','9f080000-0000-4000-8000-000000000063','9f080000-0000-4000-8000-000000000010');
insert into public.child_unit_links(id,child_context_id,unit_id,status,accepted_by,accepted_at) values
 ('9f080000-0000-4000-8000-000000000092','9f080000-0000-4000-8000-000000000091','9f080000-0000-4000-8000-000000000011','active','9f080000-0000-4000-8000-000000000064',now());
insert into public.child_group_links(id,child_unit_link_id,group_id,status) values
 ('9f080000-0000-4000-8000-000000000093','9f080000-0000-4000-8000-000000000092','9f080000-0000-4000-8000-000000000013','active');
insert into public.professional_child_assignments(id,membership_id,child_context_id,assigned_by_person_id,status) values
 ('9f080000-0000-4000-8000-000000000094','9f080000-0000-4000-8000-000000000077','9f080000-0000-4000-8000-000000000091','9f080000-0000-4000-8000-000000000064','active');

-- 1. destinatarios com a politica padrao (tudo ligado), ator = Resp Um
create temporary table rec as select r as person_id from app_private.child_care_notification_recipients_v1(
  '9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000091','9f080000-0000-4000-8000-000000000061') r;
select is((select count(*) from rec),5::bigint,'padrao: coordenadora da unidade, professora da turma, secretaria da instituicao, profissional atribuido e o outro responsavel');
select ok(not exists (select 1 from rec where person_id in ('9f080000-0000-4000-8000-000000000061','9f080000-0000-4000-8000-000000000068')),
  'o ator e a professora de outra unidade nao recebem');
select ok(exists (select 1 from rec where person_id='9f080000-0000-4000-8000-000000000062')
  and exists (select 1 from rec where person_id='9f080000-0000-4000-8000-000000000065')
  and exists (select 1 from rec where person_id='9f080000-0000-4000-8000-000000000067'),'demais responsaveis, professora da turma e profissional atribuido incluidos');

-- 2. gatilho de Seguranca infantil: pedido criado -> evento + destinatarios; decisao -> segundo evento
insert into public.authorized_people(id,institution_id,display_name) values
 ('9f080000-0000-4000-8000-000000000095','9f080000-0000-4000-8000-000000000010','Tia Autorizada');
insert into public.authorized_person_authorizations(id,authorized_person_id,institution_id,child_context_id,unit_id,relationship_type_id,created_by_guardian_link_id,created_by_person_id,valid_from)
values ('9f080000-0000-4000-8000-000000000096','9f080000-0000-4000-8000-000000000095','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000091',
  '9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000090','9f080000-0000-4000-8000-000000000081','9f080000-0000-4000-8000-000000000061',current_date);
select is((select count(*) from public.context_notification_events where object_id='9f080000-0000-4000-8000-000000000096' and event_code='child_safety.authorization.requested'),1::bigint,
  'pedido de autorizacao gera evento no sino');
select is((select count(*) from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.object_id='9f080000-0000-4000-8000-000000000096'),5::bigint,'evento do pedido chega aos 5 destinatarios');
update public.authorized_person_authorizations set decision_status='approved', decided_by_person_id='9f080000-0000-4000-8000-000000000066', decided_at=now(), decision_reason='ok'
where id='9f080000-0000-4000-8000-000000000096';
select is((select count(*) from public.context_notification_events where object_id='9f080000-0000-4000-8000-000000000096' and event_code='child_safety.authorization.approved'),1::bigint,
  'decisao gera evento proprio');
select ok(not exists (select 1 from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.event_code='child_safety.authorization.approved' and e.object_id='9f080000-0000-4000-8000-000000000096' and r.person_id='9f080000-0000-4000-8000-000000000066')
  and exists (select 1 from public.context_notification_recipients r join public.context_notification_events e on e.id=r.event_id
  where e.event_code='child_safety.authorization.approved' and e.object_id='9f080000-0000-4000-8000-000000000096' and r.person_id='9f080000-0000-4000-8000-000000000061'),
  'quem decidiu nao recebe; os dois responsaveis recebem a decisao');

-- 3. restricao e medicacao
insert into public.child_safety_restrictions(id,institution_id,unit_id,child_context_id,restriction_code,title,description,severity,reason,valid_from,created_by_person_id,updated_by_person_id)
values ('9f080000-0000-4000-8000-000000000097','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000091',
  'no_pickup_x','Restricao teste','Nao pode buscar','high','decisao judicial',now(),'9f080000-0000-4000-8000-000000000066','9f080000-0000-4000-8000-000000000066');
select is((select count(*) from public.context_notification_events where object_id='9f080000-0000-4000-8000-000000000097' and event_code='child_safety.restriction.created'),1::bigint,
  'restricao criada gera evento');
insert into public.medication_plans(id,institution_id,child_context_id,scope_kind,unit_id,status,created_by_person_id)
values ('9f080000-0000-4000-8000-000000000098','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000091','unit','9f080000-0000-4000-8000-000000000011','draft','9f080000-0000-4000-8000-000000000064');
select is((select count(*) from public.context_notification_events where object_id='9f080000-0000-4000-8000-000000000098' and event_code='medication.plan.created'),1::bigint,
  'plano de medicacao gera evento (unidade acompanha por padrao)');

-- 4. politica da unidade pelo realm interno
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f080000-0000-4000-8000-000000000101','authenticated','authenticated','p32-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9f080000-0000-4000-8000-000000000102','authenticated','authenticated','p32-ops-b@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f080000-0000-4000-8000-000000000201','9f080000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour'),
 ('9f080000-0000-4000-8000-000000000202','9f080000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values ('9f080000-0000-4000-8000-000000000301'),('9f080000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f080000-0000-4000-8000-000000000401','9f080000-0000-4000-8000-000000000301','9f080000-0000-4000-8000-000000000101'),
 ('9f080000-0000-4000-8000-000000000402','9f080000-0000-4000-8000-000000000302','9f080000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9f080000-0000-4000-8000-000000000501','9f080000-0000-4000-8000-000000000301',r.id,'platform' from public.platform_roles r where r.code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9f080000-0000-4000-8000-000000000502','9f080000-0000-4000-8000-000000000302',r.id,'institution','9f080000-0000-4000-8000-000000000020' from public.platform_roles r where r.code='operations';
create temporary table pol(label text primary key, body jsonb not null);
grant select,insert on pol to authenticated;

select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000101','session_id','9f080000-0000-4000-8000-000000000201','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into pol values('get0',public.superadmin_unit_care_policy_get_v1('9f080000-0000-4000-8000-000000000011'));
insert into pol values('set1',public.superadmin_unit_care_policy_set_v1('9f080000-0000-4000-8000-000000000901','9f080000-0000-4000-8000-000000000011',
  '{"medication_mode":"not_tracked","notify_other_guardians":false}'));
insert into pol values('set1r',public.superadmin_unit_care_policy_set_v1('9f080000-0000-4000-8000-000000000901','9f080000-0000-4000-8000-000000000011',
  '{"medication_mode":"not_tracked","notify_other_guardians":false}'));
insert into pol values('setbad',public.superadmin_unit_care_policy_set_v1(gen_random_uuid(),'9f080000-0000-4000-8000-000000000011','{"child_safety_mode":"whatever"}'));
insert into pol values('get1',public.superadmin_unit_care_policy_get_v1('9f080000-0000-4000-8000-000000000011'));
reset role;
select ok((select body->>'ok'='true' and (body#>>'{data,is_default}')::boolean and body#>>'{data,child_safety_mode}'='accept_to_release' from pol where label='get0'),
  'unidade sem politica devolve os padroes (is_default)');
select ok((select body->>'ok'='true' and body#>>'{data,medication_mode}'='not_tracked' and (body#>>'{data,management_version}')::int=2 from pol where label='set1'),
  'set grava a politica e avanca a versao');
select ok((select (body#>>'{data,replayed}')::boolean from pol where label='set1r'),'mesmo request_id e replay');
select is((select body#>>'{error,code}' from pol where label='setbad'),'SAI_INVALID_ARGUMENT','modo invalido e recusado');
select ok((select body#>>'{data,notify_other_guardians}'='false' and (body#>>'{data,is_default}')::boolean=false from pol where label='get1'),'get reflete a politica gravada');

-- 5. politica aplicada: medicacao nao acompanhada nao notifica; demais responsaveis fora
insert into public.medication_plans(id,institution_id,child_context_id,scope_kind,unit_id,status,created_by_person_id)
values ('9f080000-0000-4000-8000-000000000099','9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000091','unit','9f080000-0000-4000-8000-000000000011','draft','9f080000-0000-4000-8000-000000000064');
select is((select count(*) from public.context_notification_events where object_id='9f080000-0000-4000-8000-000000000099'),0::bigint,
  'com medication_mode not_tracked o plano nao gera evento');
select is((select count(*) from app_private.child_care_notification_recipients_v1(
  '9f080000-0000-4000-8000-000000000010','9f080000-0000-4000-8000-000000000011','9f080000-0000-4000-8000-000000000091','9f080000-0000-4000-8000-000000000061')),4::bigint,
  'com notify_other_guardians=false o outro responsavel sai da lista (e as pessoas de servico das identidades internas nunca entram)');

-- 6. cross-tenant e RLS
select set_config('request.jwt.claims',jsonb_build_object('sub','9f080000-0000-4000-8000-000000000102','session_id','9f080000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into pol values('xt_get',public.superadmin_unit_care_policy_get_v1('9f080000-0000-4000-8000-000000000011'));
insert into pol values('xt_set',public.superadmin_unit_care_policy_set_v1(gen_random_uuid(),'9f080000-0000-4000-8000-000000000011','{"child_safety_mode":"inclusion_only"}'));
reset role;
select set_config('request.jwt.claims',jsonb_build_object('sub',gen_random_uuid(),'role','authenticated')::text,true);
set local role authenticated;
select is((select count(*) from public.unit_care_policies),0::bigint,'sessao autenticada sem platform.read nao le a tabela de politicas (RLS)');
reset role;
select ok((select bool_and(body#>>'{error,code}'='SAI_PERMISSION_DENIED') from pol where label in ('xt_get','xt_set')),'operations escopado a B nao le nem grava a politica de A');
select is((select child_safety_mode from public.unit_care_policies where unit_id='9f080000-0000-4000-8000-000000000011'),'accept_to_release','politica de A intacta');
select ok(exists (select 1 from audit.audit_logs where action_code='unit.care_policy.set' and outcome='success')
  and exists (select 1 from audit.audit_logs where action_code='unit.care_policy.set' and outcome='denied'),'set e negativa auditados');

select * from finish();
rollback;
