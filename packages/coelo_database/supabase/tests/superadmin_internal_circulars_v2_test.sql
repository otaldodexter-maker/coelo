begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

select has_function('public','superadmin_circular_directory_v2',
 array['uuid','text','text[]','timestamp with time zone','uuid','integer'],'directory RPC exists');
select has_function('public','superadmin_circular_detail_v2',array['uuid'],'detail RPC exists');
select has_function('public','superadmin_circular_save_draft_v2',
 array['uuid','uuid','uuid','uuid','uuid','jsonb'],'save RPC exists');
select has_function('public','superadmin_circular_publish_v2',
 array['uuid','uuid','bigint','timestamp with time zone'],'publish RPC exists');
select has_function('public','superadmin_circular_close_v2',
 array['uuid','uuid','bigint'],'close RPC exists');
select has_function('public','superadmin_circular_response_summary_v2',array['uuid'],
 'authorized response summary RPC exists');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
 raw_app_meta_data,raw_user_meta_data) values
 ('9c100000-0000-4000-8000-000000000101','authenticated','authenticated','circular-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000102','authenticated','authenticated','circular-content@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000103','authenticated','authenticated','circular-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000104','authenticated','authenticated','circular-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c100000-0000-4000-8000-000000000201','9c100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000202','9c100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000203','9c100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000204','9c100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour');

insert into public.institution_types(id,code,name,status) values
 ('9c100000-0000-4000-8000-000000000001','circular-v2-test','Circular v2 test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c100000-0000-4000-8000-000000000010','Colégio Horizonte','circular-v2-horizonte','active','9c100000-0000-4000-8000-000000000001'),
 ('9c100000-0000-4000-8000-000000000011','Colégio Ipê','circular-v2-ipe','active','9c100000-0000-4000-8000-000000000001');

insert into app_private.superadmin_internal_identities(id) values
 ('9c100000-0000-4000-8000-000000000301'),
 ('9c100000-0000-4000-8000-000000000302'),
 ('9c100000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000101'),
 ('9c100000-0000-4000-8000-000000000402','9c100000-0000-4000-8000-000000000302','9c100000-0000-4000-8000-000000000102'),
 ('9c100000-0000-4000-8000-000000000403','9c100000-0000-4000-8000-000000000303','9c100000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select fixture.id,fixture.identity_id,role_record.id,
 fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('9c100000-0000-4000-8000-000000000501'::uuid,'9c100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9c100000-0000-4000-8000-000000000502'::uuid,'9c100000-0000-4000-8000-000000000302'::uuid,'content','platform',null::uuid),
 ('9c100000-0000-4000-8000-000000000503'::uuid,'9c100000-0000-4000-8000-000000000303'::uuid,'operations','institution','9c100000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9c100000-0000-4000-8000-000000000601','adult','Pessoa','Global','Pessoa Global','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('9c100000-0000-4000-8000-000000000601','9c100000-0000-4000-8000-000000000104','active');

create temporary table circular_results(label text primary key,body jsonb not null);
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c100000-0000-4000-8000-000000000101','session_id','9c100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

insert into circular_results values('saved',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Renovação de matrícula','version',0,'status','draft',
  'response_policy','per_person','audiences',jsonb_build_array('guardians_only'),
  'blocks',jsonb_build_array(jsonb_build_object('id','9c100000-0000-4000-8000-000000000801',
   'kind','text','text','Confirme a renovação até 30 de setembro.')))));
insert into circular_results values('saved_replay',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Renovação de matrícula','version',0,'status','draft',
  'response_policy','per_person','audiences',jsonb_build_array('guardians_only'),
  'blocks',jsonb_build_array(jsonb_build_object('id','9c100000-0000-4000-8000-000000000801',
   'kind','text','text','Confirme a renovação até 30 de setembro.')))));
insert into circular_results values('load',public.superadmin_circular_load_draft_v2(
 '9c100000-0000-4000-8000-000000000010',null,null,null));
insert into circular_results values('published',public.superadmin_circular_publish_v2(
 '9c100000-0000-4000-8000-000000000702',
 (select (body#>>'{data,id}')::uuid from circular_results where label='saved'),1,null));
insert into circular_results values('detail',public.superadmin_circular_detail_v2(
 (select (body#>>'{data,id}')::uuid from circular_results where label='saved')));
insert into circular_results values('directory',public.superadmin_circular_directory_v2(
 '9c100000-0000-4000-8000-000000000010','Renovação',array['published'],null,null,8));
insert into circular_results values('summary',public.superadmin_circular_response_summary_v2(
 (select (body#>>'{data,id}')::uuid from circular_results where label='saved')));
insert into circular_results values('closed',public.superadmin_circular_close_v2(
 '9c100000-0000-4000-8000-000000000703',
 (select (body#>>'{data,id}')::uuid from circular_results where label='saved'),2));
insert into circular_results values('media',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000704','9c100000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Circular com mídia','version',0,'response_policy','per_person',
  'audiences',jsonb_build_array('families'),'blocks',jsonb_build_array(jsonb_build_object(
   'id','9c100000-0000-4000-8000-000000000802','kind','media','asset_ids','[]'::jsonb)))));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c100000-0000-4000-8000-000000000101','session_id','9c100000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
insert into circular_results values('owner_aal1',public.superadmin_circular_directory_v2(null,null,null,null,null,8));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c100000-0000-4000-8000-000000000102','session_id','9c100000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
insert into circular_results values('content_read',public.superadmin_circular_directory_v2(null,null,null,null,null,8));
insert into circular_results values('content_write',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000705','9c100000-0000-4000-8000-000000000010',null,null,null,'{}'));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c100000-0000-4000-8000-000000000103','session_id','9c100000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
insert into circular_results values('scoped_read',public.superadmin_circular_directory_v2(null,null,null,null,null,8));
insert into circular_results values('cross_tenant',public.superadmin_circular_directory_v2(
 '9c100000-0000-4000-8000-000000000011',null,null,null,null,8));
update app_private.superadmin_internal_memberships set status='revoked',revoked_at=now()
 where id='9c100000-0000-4000-8000-000000000503';
insert into circular_results values('revoked',public.superadmin_circular_directory_v2(null,null,null,null,null,8));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9c100000-0000-4000-8000-000000000104','session_id','9c100000-0000-4000-8000-000000000204',
 'aal','aal2','role','authenticated')::text,true);
insert into circular_results values('people_only',public.superadmin_circular_directory_v2(null,null,null,null,null,8));

select is((select body#>>'{data,status}' from circular_results where label='saved'),'draft','Owner saves draft');
select is((select body from circular_results where label='saved_replay'),
 (select body from circular_results where label='saved'),'save is idempotent');
select is((select body#>>'{data,title}' from circular_results where label='load'),'Renovação de matrícula','draft reload persists');
select is((select body#>>'{data,status}' from circular_results where label='published'),'published','publish persists canonical status');
select is((select body#>>'{data,draft,status}' from circular_results where label='detail'),'published','detail reload sees publication');
select is((select jsonb_array_length(body#>'{data,items}')::text from circular_results where label='directory'),'1','directory filters persisted data');
select is((select body#>>'{data,response_count}' from circular_results where label='summary'),'0','response summary is minimized aggregate');
select is((select body#>>'{data,status}' from circular_results where label='closed'),'closed','close is persisted');
select is((select body#>>'{error,code}' from circular_results where label='media'),'CIRCULAR_MEDIA_BLOCKED','media fails closed');
select is((select body#>>'{error,code}' from circular_results where label='owner_aal1'),'SAI_MFA_REQUIRED','Owner requires AAL2');
select is((select body#>>'{ok}' from circular_results where label='content_read'),'true','Content can read');
select is((select body#>>'{error,code}' from circular_results where label='content_write'),'SAI_PERMISSION_DENIED','Content cannot mutate');
select is((select jsonb_array_length(body#>'{data,items}')::text from circular_results where label='scoped_read'),'1','institution scope resolves automatically');
select is((select body#>>'{error,code}' from circular_results where label='cross_tenant'),'SAI_PERMISSION_DENIED','cross-tenant scope is denied');
select is((select body#>>'{error,code}' from circular_results where label='revoked'),'SAI_MEMBERSHIP_REVOKED','revoked internal membership fails closed');
select is((select body#>>'{error,code}' from circular_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED','people-only realm is denied');
select ok(not exists(select 1 from circular_results where
 (select array_agg(key order by key) from jsonb_object_keys(body) key)<>array['data','error','ok']::text[]),
 'all RPCs use stable envelopes');
select ok(not exists(select 1 from circular_results where body::text like '%@invalid.test%'),
 'envelopes do not leak Auth email');
select is((select author_person_id::text from public.circulars where id=(select (body#>>'{data,id}')::uuid from circular_results where label='saved')),null,
 'internal Circular has no synthetic person author');
select is((select author_internal_identity_id::text from public.circulars where id=(select (body#>>'{data,id}')::uuid from circular_results where label='saved')),
 '9c100000-0000-4000-8000-000000000301','internal authorship is durable');
select ok(not has_table_privilege('authenticated','public.circulars','SELECT'),'authenticated has no direct table read');
select ok(not has_table_privilege('authenticated','public.circulars','INSERT'),'authenticated has no direct table write');
select ok(has_function_privilege('authenticated','public.superadmin_circular_directory_v2(uuid,text,text[],timestamptz,uuid,integer)','EXECUTE'),
 'authenticated can execute nominal directory wrapper');
select ok(not has_function_privilege('anon','public.superadmin_circular_directory_v2(uuid,text,text[],timestamptz,uuid,integer)','EXECUTE'),
 'anon cannot execute wrapper');
select ok(not has_function_privilege('service_role','public.superadmin_circular_directory_v2(uuid,text,text[],timestamptz,uuid,integer)','EXECUTE'),
 'service role is not a client bypass');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.circulars'::regclass),
 'Circulars retain RLS and FORCE RLS');

select * from finish();
rollback;
