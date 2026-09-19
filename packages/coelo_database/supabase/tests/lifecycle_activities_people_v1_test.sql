-- Prova pgTAP da migration 20260920020000_lifecycle_activities_people_v1 (spec 066: atividades,
-- suspensão de pessoas, instituições arquivadas). Fixture com rollback total (prefixo 9c2).
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

select has_function('public','superadmin_activity_change_status_v1',array['uuid','uuid','bigint','text','text'],'activity change_status exists');
select has_function('public','superadmin_person_suspend_v1',array['uuid','uuid','timestamp with time zone','timestamp with time zone','text'],'person suspend exists');
select has_function('public','superadmin_person_reactivate_v1',array['uuid','uuid','text'],'person reactivate exists');
select has_column('public','people','suspended_from','people.suspended_from');
select ok(position('suspended_from' in pg_get_functiondef('app_private.current_person_id'::regproc))>0,'current_person_id ignores suspended accounts');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c200000-0000-4000-8000-000000000101','authenticated','authenticated','lp-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c200000-0000-4000-8000-000000000201','9c200000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into auth.users(id) values ('9c200000-0000-4000-8000-000000000102');
insert into public.institution_types(id,code,name,status) values ('9c200000-0000-4000-8000-000000000001','lp-test','LP test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id,management_version) values
 ('9c200000-0000-4000-8000-000000000010','LP Instituicao A','lp-a','active','9c200000-0000-4000-8000-000000000001',1),
 ('9c200000-0000-4000-8000-000000000011','LP Instituicao Arquivada','lp-arq','archived','9c200000-0000-4000-8000-000000000001',3);
update public.institutions set deleted_at = now() where id='9c200000-0000-4000-8000-000000000011';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c200000-0000-4000-8000-000000000401','adult','LP','Responsavel','LP Responsavel','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values ('9c200000-0000-4000-8000-000000000401','9c200000-0000-4000-8000-000000000102','active');
insert into app_private.superadmin_internal_identities(id) values ('9c200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c200000-0000-4000-8000-000000000501','9c200000-0000-4000-8000-000000000301','9c200000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9c200000-0000-4000-8000-000000000601','9c200000-0000-4000-8000-000000000301',r.id,'platform',null from public.platform_roles r where r.code='owner';
-- fixture direto na tabela: marca a sessão como escrita interna da família v2
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000101',
 'session_id','9c200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select app_private.activity_v2_set_marker((select c from app_private.require_superadmin_internal_context('activities.create') c),'activities.create','create',gen_random_uuid());
insert into public.activity_definitions(id,institution_id,name,status,management_version,origin_scope_kind,distribution_scope,governance_kind,handle_stem,canonical_handle,identity_mode)
 values ('9c200000-0000-4000-8000-000000000701','9c200000-0000-4000-8000-000000000010','LP Atividade','active',1,'institution','institution_standard','optional','lp-atividade','lp-atividade.lp-a','initials');

create temporary table r(label text primary key, body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000101',
 'session_id','9c200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

-- atividade
insert into r values ('inactive',public.superadmin_activity_change_status_v1('9c200000-0000-4000-8000-000000000801','9c200000-0000-4000-8000-000000000701',1,'inactive','Fim do semestre'));
select is((select body#>>'{data,status}' from r where label='inactive'),'inactive','activity inactivated');
insert into r values ('del',public.superadmin_activity_delete_v1('9c200000-0000-4000-8000-000000000802','9c200000-0000-4000-8000-000000000701',2,'Criada por engano'));
select ok((select body->>'ok' from r where label='del')='true','activity delete ok');
select ok((select (body#>>'{data,hard_deleted}')::boolean = not exists(select 1 from public.activity_definitions where id='9c200000-0000-4000-8000-000000000701') from r where label='del'),'hard delete iff row gone');
select ok(not exists(select 1 from public.activity_definitions where id='9c200000-0000-4000-8000-000000000701' and archived_at is null and status='archived'),'logical delete sets archived_at');

-- pessoa: suspensão bloqueia a conta no período
insert into r values ('suspend',public.superadmin_person_suspend_v1('9c200000-0000-4000-8000-000000000803','9c200000-0000-4000-8000-000000000401',now()-interval '1 hour',now()+interval '1 day','Investigacao interna'));
select is((select body#>>'{data,suspended_now}' from r where label='suspend'),'true','person suspended now');
insert into r values ('no_reason',public.superadmin_person_suspend_v1('9c200000-0000-4000-8000-000000000804','9c200000-0000-4000-8000-000000000401',now(),null,null));
select is((select body#>>'{error,code}' from r where label='no_reason'),'SAI_INVALID_ARGUMENT','suspend needs reason');
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000102','role','authenticated','aal','aal1')::text,true);
select set_config('request.jwt.claim.sub','9c200000-0000-4000-8000-000000000102',true);
select is(app_private.current_person_id(),null,'suspended account does not resolve to the person');
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000101',
 'session_id','9c200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('request.jwt.claim.sub','9c200000-0000-4000-8000-000000000101',true);
insert into r values ('reactivate',public.superadmin_person_reactivate_v1('9c200000-0000-4000-8000-000000000805','9c200000-0000-4000-8000-000000000401','Concluido'));
select is((select body#>>'{data,suspended_now}' from r where label='reactivate'),'false','person reactivated');
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000102','role','authenticated','aal','aal1')::text,true);
select set_config('request.jwt.claim.sub','9c200000-0000-4000-8000-000000000102',true);
select is(app_private.current_person_id(),'9c200000-0000-4000-8000-000000000401'::uuid,'account resolves again after reactivation');
select ok(exists(select 1 from audit.audit_logs where action_code='person.suspend' and object_id='9c200000-0000-4000-8000-000000000401'),'audit person.suspend');

-- instituições arquivadas: fora por padrão, dentro com o filtro
select set_config('request.jwt.claims',jsonb_build_object('sub','9c200000-0000-4000-8000-000000000101',
 'session_id','9c200000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('request.jwt.claim.sub','9c200000-0000-4000-8000-000000000101',true);
insert into r values ('dir_default',public.superadmin_institution_directory_v2(jsonb_build_object('search','LP Instituicao'),50,0,'public_name',true));
select is((select jsonb_array_length(body#>'{data,items}') from r where label='dir_default'),1,'default directory hides archived');
insert into r values ('dir_archived',public.superadmin_institution_directory_v2(jsonb_build_object('search','LP Instituicao','statuses',jsonb_build_array('archived')),50,0,'public_name',true));
select is((select body#>'{data,items}'->0->>'public_name' from r where label='dir_archived'),'LP Instituicao Arquivada','archived filter shows the archived one');

select * from finish();
rollback;
