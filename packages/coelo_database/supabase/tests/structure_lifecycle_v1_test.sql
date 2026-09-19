-- Prova pgTAP da migration 20260920013000_structure_lifecycle_v1 (spec 066 para unidades e turmas).
-- Fixture com rollback total (prefixo 9b2): owner interno, instituição A com unidade A1 (tem turmas)
-- e unidade A2 vazia; turma T2 vazia.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

select has_function('public','superadmin_unit_change_status_v1',array['uuid','uuid','bigint','text','text'],'unit change_status exists');
select has_function('public','superadmin_group_delete_v1',array['uuid','uuid','bigint','text'],'group delete exists');
select ok(has_function_privilege('authenticated','public.superadmin_unit_delete_v1(uuid,uuid,bigint,text)','execute')
  and not has_function_privilege('anon','public.superadmin_unit_delete_v1(uuid,uuid,bigint,text)','execute'),'authenticated only');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9b200000-0000-4000-8000-000000000101','authenticated','authenticated','sl-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b200000-0000-4000-8000-000000000201','9b200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values ('9b200000-0000-4000-8000-000000000001','sl-test','SL test','active');
insert into public.unit_types(id,code,name,status) values ('9b200000-0000-4000-8000-000000000002','sl-unit','SL unit','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9b200000-0000-4000-8000-000000000010','SL Instituicao A','sl-a','active','9b200000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,handle,unit_type_id,status,management_version) values
 ('9b200000-0000-4000-8000-000000000020','9b200000-0000-4000-8000-000000000010','SL Unidade A1','sl-unidade-a1','slunidade.a1','9b200000-0000-4000-8000-000000000002','active',2),
 ('9b200000-0000-4000-8000-000000000021','9b200000-0000-4000-8000-000000000010','SL Unidade A2','sl-unidade-a2','slunidade.a2','9b200000-0000-4000-8000-000000000002','active',1);
insert into public.groups(id,institution_id,unit_id,name,status,management_version) values
 ('9b200000-0000-4000-8000-000000000030','9b200000-0000-4000-8000-000000000010','9b200000-0000-4000-8000-000000000020','SL Turma T1','active',1),
 ('9b200000-0000-4000-8000-000000000031','9b200000-0000-4000-8000-000000000010','9b200000-0000-4000-8000-000000000020','SL Turma T2','active',1);
insert into app_private.superadmin_internal_identities(id) values ('9b200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9b200000-0000-4000-8000-000000000401','9b200000-0000-4000-8000-000000000301','9b200000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9b200000-0000-4000-8000-000000000501','9b200000-0000-4000-8000-000000000301',r.id,'platform',null from public.platform_roles r where r.code='owner';

create temporary table r(label text primary key, body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','9b200000-0000-4000-8000-000000000101',
 'session_id','9b200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

insert into r values ('inactive',public.superadmin_unit_change_status_v1('9b200000-0000-4000-8000-000000000701','9b200000-0000-4000-8000-000000000020',2,'inactive','Reforma'));
select is((select body#>>'{data,status}' from r where label='inactive'),'inactive','unit inactivated');
select is((select status::text from public.groups where id='9b200000-0000-4000-8000-000000000030'),'active','groups keep physical status');
select is((select lifecycle_reason from public.units where id='9b200000-0000-4000-8000-000000000020'),'Reforma','reason stored');
insert into r values ('no_reason',public.superadmin_unit_change_status_v1('9b200000-0000-4000-8000-000000000702','9b200000-0000-4000-8000-000000000021',1,'inactive',null));
select is((select body#>>'{error,code}' from r where label='no_reason'),'SAI_INVALID_ARGUMENT','inactivate needs reason');
insert into r values ('stale',public.superadmin_unit_change_status_v1('9b200000-0000-4000-8000-000000000703','9b200000-0000-4000-8000-000000000020',2,'active',null));
select is((select body#>>'{error,code}' from r where label='stale'),'SAI_CONCURRENT_CHANGE','stale = SAI_CONCURRENT_CHANGE');
insert into r values ('active',public.superadmin_unit_change_status_v1('9b200000-0000-4000-8000-000000000704','9b200000-0000-4000-8000-000000000020',3,'active',null));
select is((select body#>>'{data,status}' from r where label='active'),'active','unit reactivated');

-- excluir unidade A1 (tem turmas) -> logica; unidade A2 vazia -> real
insert into r values ('del_a1',public.superadmin_unit_delete_v1('9b200000-0000-4000-8000-000000000705','9b200000-0000-4000-8000-000000000020',4,'Duplicada'));
select is((select body#>>'{data,hard_deleted}' from r where label='del_a1'),'false','unit with groups: logical delete');
select is((select status::text from public.units where id='9b200000-0000-4000-8000-000000000020'),'archived','unit archived');
select is((select count(*) from public.groups where unit_id='9b200000-0000-4000-8000-000000000020'),2::bigint,'groups preserved');
insert into r values ('del_a2',public.superadmin_unit_delete_v1('9b200000-0000-4000-8000-000000000706','9b200000-0000-4000-8000-000000000021',1,'Criada por engano'));
select is((select body#>>'{data,hard_deleted}' from r where label='del_a2'),'true','empty unit: hard delete');
select is((select count(*) from public.units where id='9b200000-0000-4000-8000-000000000021'),0::bigint,'unit row gone');

-- turma vazia -> real
insert into r values ('del_t2',public.superadmin_group_delete_v1('9b200000-0000-4000-8000-000000000707','9b200000-0000-4000-8000-000000000031',1,'Criada por engano'));
select is((select body#>>'{data,hard_deleted}' from r where label='del_t2'),'true','empty group: hard delete');

select * from finish();
rollback;
