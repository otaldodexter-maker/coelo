-- Prova pgTAP da migration 20260920001000_institution_lifecycle_v1 (spec 066).
-- Fixture sintética com rollback total (prefixo 9e1): owner interno (aal2), operations com
-- escopo em outra instituição, instituição A (com unidade) e B (recém-criada, sem vínculos).
begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

select has_function('public','superadmin_institution_change_status_v1',array['uuid','uuid','bigint','text','text'],'change_status_v1 exists');
select has_function('public','superadmin_institution_delete_v1',array['uuid','uuid','bigint','text'],'delete_v1 exists');
select has_function('app_private','lifecycle_can_hard_delete_v1',array['text','uuid'],'hard delete predicate exists');
select ok(has_function_privilege('authenticated','public.superadmin_institution_change_status_v1(uuid,uuid,bigint,text,text)','execute')
  and not has_function_privilege('anon','public.superadmin_institution_change_status_v1(uuid,uuid,bigint,text,text)','execute'),'authenticated only');
select ok(not has_function_privilege('authenticated','app_private.lifecycle_can_hard_delete_v1(text,uuid)','execute'),'predicate is private');
select ok(position('40001' in pg_get_functiondef('app_private.superadmin_institution_lifecycle_apply_v1'::regproc))=0
  and position('PT409' in pg_get_functiondef('app_private.superadmin_institution_lifecycle_apply_v1'::regproc))>0,'stale = PT409, never 40001');
select has_column('public','institution_directory','management_version','directory exposes management_version');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9e100000-0000-4000-8000-000000000101','authenticated','authenticated','lc-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9e100000-0000-4000-8000-000000000102','authenticated','authenticated','lc-ops@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9e100000-0000-4000-8000-000000000201','9e100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9e100000-0000-4000-8000-000000000202','9e100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values ('9e100000-0000-4000-8000-000000000001','lc-test','LC test','active');
insert into public.unit_types(id,code,name,status) values ('9e100000-0000-4000-8000-000000000002','lc-unit','LC unit','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id,management_version) values
 ('9e100000-0000-4000-8000-000000000010','LC Instituição A','lc-a','active','9e100000-0000-4000-8000-000000000001',3),
 ('9e100000-0000-4000-8000-000000000011','LC Instituição B','lc-b','active','9e100000-0000-4000-8000-000000000001',1),
 ('9e100000-0000-4000-8000-000000000012','LC Instituição C','lc-c','active','9e100000-0000-4000-8000-000000000001',1);
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status) values
 ('9e100000-0000-4000-8000-000000000020','9e100000-0000-4000-8000-000000000010','LC Unidade A1','lc-unidade-a1','lcunidade.a1','9e100000-0000-4000-8000-000000000002','active');
insert into app_private.superadmin_internal_identities(id) values
 ('9e100000-0000-4000-8000-000000000301'),('9e100000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9e100000-0000-4000-8000-000000000401','9e100000-0000-4000-8000-000000000301','9e100000-0000-4000-8000-000000000101'),
 ('9e100000-0000-4000-8000-000000000402','9e100000-0000-4000-8000-000000000302','9e100000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,f.scope_kind::app_private.superadmin_internal_scope_kind,f.inst
from (values
 ('9e100000-0000-4000-8000-000000000501'::uuid,'9e100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9e100000-0000-4000-8000-000000000502'::uuid,'9e100000-0000-4000-8000-000000000302'::uuid,'operations','institution','9e100000-0000-4000-8000-000000000012'::uuid)
) f(id,identity_id,role_code,scope_kind,inst) join public.platform_roles r on r.code=f.role_code;

create temporary table r(label text primary key, body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','9e100000-0000-4000-8000-000000000101',
 'session_id','9e100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

-- predicado
select is(app_private.lifecycle_can_hard_delete_v1('institution','9e100000-0000-4000-8000-000000000010'),false,'A has a unit: no hard delete');
select is(app_private.lifecycle_can_hard_delete_v1('institution','9e100000-0000-4000-8000-000000000011'),true,'B has nothing: hard delete allowed');
select is(app_private.lifecycle_can_hard_delete_v1('unit','9e100000-0000-4000-8000-000000000020'),true,'unit A1 has nothing: hard delete allowed');

-- inativar sem motivo → inválido
insert into r values ('no_reason',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000701',
  '9e100000-0000-4000-8000-000000000010',3,'inactive',null));
select is((select body#>>'{error,code}' from r where label='no_reason'),'SAI_INVALID_ARGUMENT','inactivate requires reason');

-- inativar
insert into r values ('inactive',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000702',
  '9e100000-0000-4000-8000-000000000010',3,'inactive','Encerramento do contrato'));
select is((select body#>>'{data,status}' from r where label='inactive'),'inactive','A inactivated');
select is((select body#>>'{data,management_version}' from r where label='inactive'),'4','version bumped');
select is((select status::text from public.units where id='9e100000-0000-4000-8000-000000000020'),'active','children keep physical status');
select ok(exists(select 1 from audit.audit_logs where action_code='institution.inactivate' and object_id='9e100000-0000-4000-8000-000000000010'
  and reason_code='LIFECYCLE_OPERATOR_REASON' and after_json->>'status'='inactive'),'audit institution.inactivate with reason code and after');
select is((select lifecycle_reason from public.institutions where id='9e100000-0000-4000-8000-000000000010'),'Encerramento do contrato','reason stored on the institution');

-- replay idempotente
insert into r values ('replay',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000702',
  '9e100000-0000-4000-8000-000000000010',3,'inactive','Encerramento do contrato'));
select is((select body#>>'{data,replayed}' from r where label='replay'),'true','same request replays');
select is((select management_version from public.institutions where id='9e100000-0000-4000-8000-000000000010'),4::bigint,'replay does not bump');

-- versão defasada
insert into r values ('stale',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000703',
  '9e100000-0000-4000-8000-000000000010',3,'active',null));
select is((select body#>>'{error,code}' from r where label='stale'),'SAI_CONCURRENT_CHANGE','stale version = SAI_CONCURRENT_CHANGE');

-- reativar
insert into r values ('active',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000704',
  '9e100000-0000-4000-8000-000000000010',4,'active',null));
select is((select body#>>'{data,status}' from r where label='active'),'active','A reactivated');

-- excluir A (tem vínculos) → lógica
insert into r values ('delete_a',public.superadmin_institution_delete_v1('9e100000-0000-4000-8000-000000000705',
  '9e100000-0000-4000-8000-000000000010',5,'Criada em duplicidade'));
select is((select body#>>'{data,hard_deleted}' from r where label='delete_a'),'false','A: logical delete');
select ok((select status='archived' and deleted_at is not null from public.institutions where id='9e100000-0000-4000-8000-000000000010'),'A archived with deleted_at');
select is((select count(*) from public.units where institution_id='9e100000-0000-4000-8000-000000000010'),1::bigint,'children preserved');
select is((select count(*) from public.institution_directory where id='9e100000-0000-4000-8000-000000000010'),0::bigint,'archived leaves the directory');

-- excluir B (sem vínculos) → real
insert into r values ('delete_b',public.superadmin_institution_delete_v1('9e100000-0000-4000-8000-000000000706',
  '9e100000-0000-4000-8000-000000000011',1,'Criada por engano'));
select is((select body#>>'{data,hard_deleted}' from r where label='delete_b'),'true','B: hard delete');
select is((select count(*) from public.institutions where id='9e100000-0000-4000-8000-000000000011'),0::bigint,'B row gone');

-- operations com escopo em C não mexe em C? (escopo próprio permitido) e não mexe em outra
select set_config('request.jwt.claims',jsonb_build_object('sub','9e100000-0000-4000-8000-000000000102',
 'session_id','9e100000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
insert into r values ('cross',public.superadmin_institution_change_status_v1('9e100000-0000-4000-8000-000000000707',
  '9e100000-0000-4000-8000-000000000010',6,'inactive','x'));
select is((select body->>'ok' from r where label='cross'),'false','scoped operations cannot touch another institution');

select * from finish();
rollback;
