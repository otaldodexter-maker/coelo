begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

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

-- H21: 4.000 e o total somando os blocos de texto.
insert into circular_results values('ok4000',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000711','9c100000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Limite','version',0,'status','draft','response_policy','per_person',
  'audiences',jsonb_build_array('guardians_only'),
  'blocks',jsonb_build_array(jsonb_build_object('id','9c100000-0000-4000-8000-000000000811','kind','text','text',repeat('a',2000)),
   jsonb_build_object('id','9c100000-0000-4000-8000-000000000812','kind','text','text',repeat('b',2000))))));
select is((select body->>'ok' from circular_results where label='ok4000'),'true','dois blocos somando 4.000 sao aceitos');
insert into circular_results values('over4000',public.superadmin_circular_save_draft_v2(
 '9c100000-0000-4000-8000-000000000712','9c100000-0000-4000-8000-000000000010',null,null,null,
 jsonb_build_object('id','','title','Limite','version',0,'status','draft','response_policy','per_person',
  'audiences',jsonb_build_array('guardians_only'),
  'blocks',jsonb_build_array(jsonb_build_object('id','9c100000-0000-4000-8000-000000000813','kind','text','text',repeat('a',2000)),
   jsonb_build_object('id','9c100000-0000-4000-8000-000000000814','kind','text','text',repeat('b',2001))))));
select is((select body#>>'{error,code}' from circular_results where label='over4000'),'CIRCULAR_INVALID_INPUT','dois blocos somando 4.001 sao recusados');
select is((select count(*) from public.circular_revisions where title='Limite'),1::bigint,'somente a revisao dentro do limite foi gravada');
select ok((select pg_get_constraintdef(oid) from pg_constraint where conrelid='public.circular_revisions'::regclass and conname='circular_revisions_body_length_check') like '%4000%','constraint da tabela acompanha 4.000');
select * from finish(); rollback;
