begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

select has_function('public','superadmin_activity_directory_v2',array['jsonb','integer','integer','text','boolean'],'directory v2 exists');
select has_function('public','superadmin_activity_detail_v2',array['uuid','text[]'],'detail v2 exists');
select has_function('public','superadmin_activity_form_options_v2',array['uuid','text[]','text','integer'],'form options v2 exists');

-- Genuine spec-039 fixtures. Everything is synthetic and rolled back.
insert into public.institution_types(id,code,name,status) values
 ('8a100000-0000-4000-8000-000000000001','activities-v2-read','Activities v2 read','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8a100000-0000-4000-8000-000000000010','Tenant A','activities-v2-read-a','active','8a100000-0000-4000-8000-000000000001'),
 ('8a100000-0000-4000-8000-000000000020','Tenant B','activities-v2-read-b','active','8a100000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8a100000-0000-4000-8000-000000000011','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000001','A Norte','activities-v2-read-a-norte','active'),
 ('8a100000-0000-4000-8000-000000000012','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000001','A Sul','activities-v2-read-a-sul','active'),
 ('8a100000-0000-4000-8000-000000000021','8a100000-0000-4000-8000-000000000020','8a100000-0000-4000-8000-000000000001','B Única','activities-v2-read-b-unica','active');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('8a100000-0000-4000-8000-000000000013','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000011','Turma A1','active'),
 ('8a100000-0000-4000-8000-000000000014','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000012','Turma A2 irmã','active'),
 ('8a100000-0000-4000-8000-000000000022','8a100000-0000-4000-8000-000000000020','8a100000-0000-4000-8000-000000000021','Turma B','active');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8a100000-0000-4000-8000-000000000101','authenticated','authenticated','read-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a100000-0000-4000-8000-000000000102','authenticated','authenticated','read-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a100000-0000-4000-8000-000000000103','authenticated','authenticated','read-aal1@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a100000-0000-4000-8000-000000000104','authenticated','authenticated','read-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a100000-0000-4000-8000-000000000105','authenticated','authenticated','read-people-only@invalid.test',now(),now(),now(),'{}','{}'),
 ('8a100000-0000-4000-8000-000000000106','authenticated','authenticated','read-denied-cap@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8a100000-0000-4000-8000-000000000201','8a100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000202','8a100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000203','8a100000-0000-4000-8000-000000000103',now(),now(),'aal1',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000204','8a100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000205','8a100000-0000-4000-8000-000000000105',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000206','8a100000-0000-4000-8000-000000000106',now(),now(),'aal2',now()+interval '1 hour'),
 ('8a100000-0000-4000-8000-000000000209','8a100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()-interval '1 minute');
insert into app_private.superadmin_internal_identities(id) values
 ('8a100000-0000-4000-8000-000000000301'),('8a100000-0000-4000-8000-000000000302'),
 ('8a100000-0000-4000-8000-000000000303'),('8a100000-0000-4000-8000-000000000304'),
 ('8a100000-0000-4000-8000-000000000306');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8a100000-0000-4000-8000-000000000401','8a100000-0000-4000-8000-000000000301','8a100000-0000-4000-8000-000000000101'),
 ('8a100000-0000-4000-8000-000000000402','8a100000-0000-4000-8000-000000000302','8a100000-0000-4000-8000-000000000102'),
 ('8a100000-0000-4000-8000-000000000403','8a100000-0000-4000-8000-000000000303','8a100000-0000-4000-8000-000000000103'),
 ('8a100000-0000-4000-8000-000000000404','8a100000-0000-4000-8000-000000000304','8a100000-0000-4000-8000-000000000104'),
 ('8a100000-0000-4000-8000-000000000406','8a100000-0000-4000-8000-000000000306','8a100000-0000-4000-8000-000000000106');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('8a100000-0000-4000-8000-000000000501'::uuid,'8a100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('8a100000-0000-4000-8000-000000000502'::uuid,'8a100000-0000-4000-8000-000000000302'::uuid,'operations','institution','8a100000-0000-4000-8000-000000000010'::uuid),
 ('8a100000-0000-4000-8000-000000000503'::uuid,'8a100000-0000-4000-8000-000000000303'::uuid,'owner','platform',null::uuid),
 ('8a100000-0000-4000-8000-000000000504'::uuid,'8a100000-0000-4000-8000-000000000304'::uuid,'operations','institution','8a100000-0000-4000-8000-000000000010'::uuid),
 ('8a100000-0000-4000-8000-000000000506'::uuid,'8a100000-0000-4000-8000-000000000306'::uuid,'content','platform',null::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now(),version=2 where id='8a100000-0000-4000-8000-000000000504';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('8a100000-0000-4000-8000-000000000601','adult','People','Only','People Only','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('8a100000-0000-4000-8000-000000000601','8a100000-0000-4000-8000-000000000105','active');

-- Explicit grants/deny keep the test independent from profile seed drift.
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,
 case when role_record.code='content' and permission_record.code='activities.read' then 'deny'::public.permission_effect else 'allow'::public.permission_effect end,'active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code in('owner','operations','content') and permission_record.code in(
 'activities.read','activities.assign_people','activities.manage_permissions','activities.manage','activities.link_units','activities.link_groups')
 and not(role_record.code='operations' and permission_record.code in(
   'activities.assign_people','activities.manage_permissions'))
on conflict(role_id,permission_id) do update set effect=excluded.effect,status='active',revoked_at=null;
delete from public.platform_role_permissions role_permission
using public.platform_roles role_record,public.platform_permissions permission_record
where role_permission.role_id=role_record.id
  and role_permission.permission_id=permission_record.id
  and role_record.code='operations'
  and permission_record.code in('activities.assign_people','activities.manage_permissions');

-- Seed one activity in each tenant through a genuine validated internal marker.
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a100000-0000-4000-8000-000000000301','internal_auth_link_id','8a100000-0000-4000-8000-000000000401','internal_membership_id','8a100000-0000-4000-8000-000000000501',
 'auth_user_id','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000201','permission_code','activities.manage','action_code','manage')::text,true);
insert into public.activity_definitions(id,institution_id,name,description,handle_stem,origin_scope_kind,created_by_person_id,status,management_version) values
 ('8a100000-0000-4000-8000-000000000701','8a100000-0000-4000-8000-000000000010','Robótica A','Somente tenant A','robotica-a-v2','institution',null,'draft',1),
 ('8a100000-0000-4000-8000-000000000702','8a100000-0000-4000-8000-000000000020','Robótica B','Somente tenant B','robotica-b-v2','institution',null,'draft',1);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a100000-0000-4000-8000-000000000301','internal_auth_link_id','8a100000-0000-4000-8000-000000000401','internal_membership_id','8a100000-0000-4000-8000-000000000501','auth_user_id','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000201','permission_code','activities.link_units','action_code','link_units')::text,true);
insert into public.activity_unit_links(id,activity_id,institution_id,unit_id,linked_by_person_id) values
 ('8a100000-0000-4000-8000-000000000711','8a100000-0000-4000-8000-000000000701','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000011',null),
 ('8a100000-0000-4000-8000-000000000721','8a100000-0000-4000-8000-000000000702','8a100000-0000-4000-8000-000000000020','8a100000-0000-4000-8000-000000000021',null);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8a100000-0000-4000-8000-000000000301','internal_auth_link_id','8a100000-0000-4000-8000-000000000401','internal_membership_id','8a100000-0000-4000-8000-000000000501','auth_user_id','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000201','permission_code','activities.link_groups','action_code','link_groups')::text,true);
insert into public.activity_group_links(id,activity_id,institution_id,unit_id,group_id,linked_by_person_id,participation_mode) values
 ('8a100000-0000-4000-8000-000000000712','8a100000-0000-4000-8000-000000000701','8a100000-0000-4000-8000-000000000010','8a100000-0000-4000-8000-000000000011','8a100000-0000-4000-8000-000000000013',null,'all'),
 ('8a100000-0000-4000-8000-000000000722','8a100000-0000-4000-8000-000000000702','8a100000-0000-4000-8000-000000000020','8a100000-0000-4000-8000-000000000021','8a100000-0000-4000-8000-000000000022',null,'all');

create temporary table read_results(label text primary key,body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);
insert into read_results values
 ('owner_directory',public.superadmin_activity_directory_v2('{"institution_id":"8a100000-0000-4000-8000-000000000010"}',24,0,'name',true)),
 ('owner_detail',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-000000000701','{}')),
 ('owner_options',public.superadmin_activity_form_options_v2('8a100000-0000-4000-8000-000000000010',array['taxonomy','structure'],null,50)),
 ('sibling_unit',public.superadmin_activity_directory_v2('{"unit_id":"8a100000-0000-4000-8000-000000000012"}',24,0,'name',true)),
 ('sibling_group',public.superadmin_activity_directory_v2('{"group_id":"8a100000-0000-4000-8000-000000000014"}',24,0,'name',true)),
 ('random_detail',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-ffffffffffff','{}')),
 ('invalid_sections',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-000000000701',array['participants','participants']));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000102','session_id','8a100000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
insert into read_results values
 ('scoped_a',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-000000000701','{}')),
 ('scoped_b',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-000000000702','{}')),
 ('scoped_sensitive',public.superadmin_activity_detail_v2('8a100000-0000-4000-8000-000000000701',array['participants','permissions']));
select set_config('request.jwt.claims','{}',true);
insert into read_results values('anonymous',public.superadmin_activity_directory_v2('{}',24,0,'name',true));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000101','session_id','8a100000-0000-4000-8000-000000000209','aal','aal2','role','authenticated')::text,true);
insert into read_results values('expired',public.superadmin_activity_directory_v2('{}',24,0,'name',true));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000103','session_id','8a100000-0000-4000-8000-000000000203','aal','aal1','role','authenticated')::text,true);
insert into read_results values('aal1_owner',public.superadmin_activity_directory_v2('{}',24,0,'name',true));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000104','session_id','8a100000-0000-4000-8000-000000000204','aal','aal2','role','authenticated')::text,true);
insert into read_results values('revoked',public.superadmin_activity_directory_v2('{}',24,0,'name',true));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000105','session_id','8a100000-0000-4000-8000-000000000205','aal','aal2','role','authenticated')::text,true);
insert into read_results values('people_only',public.superadmin_activity_directory_v2('{}',24,0,'name',true));
select set_config('request.jwt.claims',jsonb_build_object('sub','8a100000-0000-4000-8000-000000000106','session_id','8a100000-0000-4000-8000-000000000206','aal','aal2','role','authenticated')::text,true);
insert into read_results values('cap_denied',public.superadmin_activity_directory_v2('{}',24,0,'name',true));

select ok((select body#>>'{ok}'='true' and (body#>>'{data,total}')::int=1 from read_results where label='owner_directory'),'authorized directory returns tenant A only');
select ok((select body#>>'{data,items,0,activity_id}'='8a100000-0000-4000-8000-000000000701' and position('8a100000-0000-4000-8000-000000000702' in body::text)=0 from read_results where label='owner_directory'),'directory does not leak tenant B');
select ok((select body#>>'{ok}'='true' and body#>>'{data,activity,activity_id}'='8a100000-0000-4000-8000-000000000701' from read_results where label='owner_detail'),'detail returns the authorized activity');
select ok((select (select array_agg(key order by key) from jsonb_object_keys(body->'data') key)=array['activity','counts','groups','units']::text[] from read_results where label='owner_detail'),'default detail exposes exact sections');
select ok((select position('created_by_person_id' in body::text)=0 and position('internal_identity' in body::text)=0 from read_results where label='owner_detail'),'detail never exposes actor identifiers');
select ok((select body#>>'{ok}'='true' and body#>'{data,taxonomy}' is not null and body#>'{data,structure}' is not null from read_results where label='owner_options'),'authorized minimized form options succeed');
select ok((select (body#>>'{data,total}')::int=0 from read_results where label='sibling_unit'),'sibling unit filter cannot widen access');
select ok((select (body#>>'{data,total}')::int=0 from read_results where label='sibling_group'),'sibling group filter cannot widen access');
select is((select body#>>'{error,code}' from read_results where label='random_detail'),'ACTIVITY_NOT_FOUND','random activity UUID is non-enumerating');
select is((select body#>>'{error,code}' from read_results where label='invalid_sections'),'ACTIVITY_INVALID_INPUT','duplicate sections are rejected');
select ok((select body#>>'{ok}'='true' from read_results where label='scoped_a'),'institution-scoped actor reads tenant A');
select ok((select (body->'error')-'correlation_id' from read_results where label='scoped_b')=(select (body->'error')-'correlation_id' from read_results where label='random_detail'),'tenant B and random UUID are indistinguishable');
select is((select body#>>'{error,code}' from read_results where label='scoped_sensitive'),'SAI_PERMISSION_DENIED','sensitive sections require independent capabilities');
select is((select body#>>'{error,code}' from read_results where label='anonymous'),'SAI_AUTH_REQUIRED','missing Auth fails closed');
select is((select body#>>'{error,code}' from read_results where label='expired'),'SAI_SESSION_INVALID','expired session fails closed');
select is((select body#>>'{error,code}' from read_results where label='aal1_owner'),'SAI_MFA_REQUIRED','Owner AAL1 fails closed');
select is((select body#>>'{error,code}' from read_results where label='revoked'),'SAI_MEMBERSHIP_REVOKED','revoked membership fails closed');
select is((select body#>>'{error,code}' from read_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED','people-only cross-app identity is denied');
select is((select body#>>'{error,code}' from read_results where label='cap_denied'),'SAI_PERMISSION_DENIED','explicit capability deny fails closed');
select ok(not exists(select 1 from read_results where (select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[]),'every read uses the stable envelope');
select ok(not exists(select 1 from read_results where body#>>'{ok}'='false' and (select array_agg(key order by key) from jsonb_object_keys(body->'error') key)<>array['code','correlation_id','http_status','message']::text[]),'every read error is allowlisted');
select ok((select body#>>'{error,http_status}'='404' from read_results where label='scoped_b') and (select body#>>'{error,http_status}'='403' from read_results where label='scoped_sensitive'),'tenant scope is non-enumerating while sensitive section denial is 403');
select ok((select jsonb_array_length(body#>'{data,items}')=1 from read_results where label='owner_directory'),'directory item count matches total');
select ok((select body#>>'{data,limit}'='24' and body#>>'{data,offset}'='0' from read_results where label='owner_directory'),'directory echoes bounded pagination');
select ok(not exists(select 1 from read_results where body::text like '%@invalid.test%'),'read envelopes contain no Auth email');

select * from finish();
rollback;
