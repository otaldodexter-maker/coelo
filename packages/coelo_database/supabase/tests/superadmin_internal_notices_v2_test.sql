begin;
create extension if not exists pgtap with schema extensions;
select plan(38);

select has_function('public', 'superadmin_notice_directory_v2',
  array['text[]','text','text[]','text[]','timestamp with time zone','uuid','integer'],
  'internal Notice directory v2 exists');
select has_function('public', 'superadmin_notice_detail_v2', array['uuid'],
  'internal Notice detail v2 exists');
select has_function('public', 'superadmin_notice_save_draft_v2',
  array['uuid','uuid','bigint','jsonb'], 'internal Notice save v2 exists');
select has_function('public', 'superadmin_notice_publish_v2',
  array['uuid','uuid','bigint'], 'internal Notice publish v2 exists');
select has_function('public', 'superadmin_notice_change_status_v2',
  array['uuid','uuid','bigint','text','text'], 'internal Notice lifecycle v2 exists');
select has_table('analytics', 'notice_events', 'Notice events use the analytics schema');

insert into auth.users(
  id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data
) values
 ('9b100000-0000-4000-8000-000000000101','authenticated','authenticated',
  'notices-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000102','authenticated','authenticated',
  'notices-content@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000103','authenticated','authenticated',
  'notices-scoped@invalid.test',now(),now(),now(),'{}','{}'),
 ('9b100000-0000-4000-8000-000000000104','authenticated','authenticated',
  'notices-people@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b100000-0000-4000-8000-000000000201','9b100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000202','9b100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000203','9b100000-0000-4000-8000-000000000103',now(),now(),'aal2',now()+interval '1 hour'),
 ('9b100000-0000-4000-8000-000000000204','9b100000-0000-4000-8000-000000000104',now(),now(),'aal2',now()+interval '1 hour');

insert into public.institution_types(id,code,name,status) values
 ('9b100000-0000-4000-8000-000000000001','notice-v2-test','Notice v2 test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9b100000-0000-4000-8000-000000000010','Colégio Ipê','notice-v2-ipe','active',
  '9b100000-0000-4000-8000-000000000001');

insert into app_private.superadmin_internal_identities(id) values
 ('9b100000-0000-4000-8000-000000000301'),
 ('9b100000-0000-4000-8000-000000000302'),
 ('9b100000-0000-4000-8000-000000000303');
insert into app_private.superadmin_internal_auth_links(
  id,internal_identity_id,auth_user_id
) values
 ('9b100000-0000-4000-8000-000000000401','9b100000-0000-4000-8000-000000000301','9b100000-0000-4000-8000-000000000101'),
 ('9b100000-0000-4000-8000-000000000402','9b100000-0000-4000-8000-000000000302','9b100000-0000-4000-8000-000000000102'),
 ('9b100000-0000-4000-8000-000000000403','9b100000-0000-4000-8000-000000000303','9b100000-0000-4000-8000-000000000103');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id
)
select fixture.id,fixture.identity_id,role_record.id,
  fixture.scope_kind::app_private.superadmin_internal_scope_kind,fixture.institution_id
from (values
 ('9b100000-0000-4000-8000-000000000501'::uuid,'9b100000-0000-4000-8000-000000000301'::uuid,'owner','platform',null::uuid),
 ('9b100000-0000-4000-8000-000000000502'::uuid,'9b100000-0000-4000-8000-000000000302'::uuid,'content','platform',null::uuid),
 ('9b100000-0000-4000-8000-000000000503'::uuid,'9b100000-0000-4000-8000-000000000303'::uuid,'operations','institution','9b100000-0000-4000-8000-000000000010'::uuid)
) fixture(id,identity_id,role_code,scope_kind,institution_id)
join public.platform_roles role_record on role_record.code=fixture.role_code;
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9b100000-0000-4000-8000-000000000601','adult','Pessoa','Global','Pessoa Global','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
 ('9b100000-0000-4000-8000-000000000601','9b100000-0000-4000-8000-000000000104','active');

create temporary table notice_results(label text primary key,body jsonb not null);

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000101',
 'session_id','9b100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

insert into notice_results values ('empty',public.superadmin_notice_directory_v2(
 null,null,null,null,null,null,24));
insert into notice_results values ('saved',public.superadmin_notice_save_draft_v2(
 '9b100000-0000-4000-8000-000000000701',null,null,
 jsonb_build_object(
  'type','popup','title','Manutenção preventiva','body','A plataforma ficará indisponível por quinze minutos.',
  'priority','important','audience',jsonb_build_object('rules',jsonb_build_array(
    jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb))),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all',
  'content_format','text_background','background_color','#D63C00','text_color','#FFFFFF',
  'button_color','#D63C00','popup_size','standard','has_outer_inset',true,
  'button_label','Entendi','recurrence','one_time','weekly_days','[]'::jsonb,
  'image_orientation','vertical','starts_at',now()-interval '1 minute','ends_at',now()+interval '1 day')));

insert into notice_results values ('saved_replay',public.superadmin_notice_save_draft_v2(
 '9b100000-0000-4000-8000-000000000701',null,null,
 jsonb_build_object(
  'type','popup','title','Manutenção preventiva','body','A plataforma ficará indisponível por quinze minutos.',
  'priority','important','audience',jsonb_build_object('rules',jsonb_build_array(
    jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb))),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all',
  'content_format','text_background','background_color','#D63C00','text_color','#FFFFFF',
  'button_color','#D63C00','popup_size','standard','has_outer_inset',true,
  'button_label','Entendi','recurrence','one_time','weekly_days','[]'::jsonb,
  'image_orientation','vertical','starts_at',now()-interval '1 minute','ends_at',now()+interval '1 day')));

insert into notice_results values ('published',public.superadmin_notice_publish_v2(
 '9b100000-0000-4000-8000-000000000702',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),1));
insert into notice_results values ('detail',public.superadmin_notice_detail_v2(
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved')));
insert into notice_results values ('directory',public.superadmin_notice_directory_v2(
 null,'Manutenção',array['active'],array['important'],null,null,24));
insert into notice_results values ('paused',public.superadmin_notice_change_status_v2(
 '9b100000-0000-4000-8000-000000000703',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),2,'paused',null));
insert into notice_results values ('resumed',public.superadmin_notice_change_status_v2(
 '9b100000-0000-4000-8000-000000000704',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),3,'scheduled',null));
insert into notice_results values ('inactive',public.superadmin_notice_change_status_v2(
 '9b100000-0000-4000-8000-000000000705',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),4,'inactive','Janela cancelada'));
insert into notice_results values ('inactive_replay',public.superadmin_notice_change_status_v2(
 '9b100000-0000-4000-8000-000000000705',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),4,'inactive','Janela cancelada'));
insert into notice_results values ('terminal',public.superadmin_notice_change_status_v2(
 '9b100000-0000-4000-8000-000000000706',
 (select (body#>>'{data,id}')::uuid from notice_results where label='saved'),5,'scheduled',null));
insert into notice_results values ('media',public.superadmin_notice_save_draft_v2(
 '9b100000-0000-4000-8000-000000000707',null,null,
 jsonb_build_object('type','popup','title','Imagem','body','Bloqueada','priority','routine',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','platform','select_all',true))),
  'audience_label','Todos','behavior','dismissible','target_device','all','content_format','image',
  'popup_size','standard','recurrence','one_time','starts_at',now())));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000101',
 'session_id','9b100000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
insert into notice_results values ('owner_aal1',public.superadmin_notice_directory_v2(
 null,null,null,null,null,null,24));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000102',
 'session_id','9b100000-0000-4000-8000-000000000202',
 'aal','aal2','role','authenticated')::text,true);
insert into notice_results values ('content_read',public.superadmin_notice_directory_v2(
 null,null,null,null,null,null,24));
insert into notice_results values ('content_write',public.superadmin_notice_save_draft_v2(
 '9b100000-0000-4000-8000-000000000708',null,null,'{}'));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000103',
 'session_id','9b100000-0000-4000-8000-000000000203',
 'aal','aal2','role','authenticated')::text,true);
insert into notice_results values ('scoped',public.superadmin_notice_directory_v2(
 null,null,null,null,null,null,24));

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b100000-0000-4000-8000-000000000104',
 'session_id','9b100000-0000-4000-8000-000000000204',
 'aal','aal2','role','authenticated')::text,true);
insert into notice_results values ('people_only',public.superadmin_notice_directory_v2(
 null,null,null,null,null,null,24));

select is((select body#>>'{ok}' from notice_results where label='empty'),'true',
  'Owner AAL2 can read the empty directory');
select is((select body#>>'{data,status}' from notice_results where label='saved'),'draft',
  'save persists a canonical draft');
select is((select body#>>'{data,management_version}' from notice_results where label='saved'),'1',
  'new draft starts at version one');
select is((select body from notice_results where label='saved_replay'),
  (select body from notice_results where label='saved'), 'save is idempotent');
select is((select body#>>'{data,status}' from notice_results where label='published'),'active',
  'past start publishes directly as active');
select is((select body#>>'{data,management_version}' from notice_results where label='published'),'2',
  'publish increments optimistic version');
select is((select body#>>'{data,status}' from notice_results where label='detail'),'active',
  'detail reload sees persisted active state');
select is((select jsonb_array_length(body#>'{data,items}')::text from notice_results where label='directory'),'1',
  'directory reload sees the persisted filtered item');
select is((select body#>>'{data,status}' from notice_results where label='paused'),'paused',
  'active can pause');
select is((select body#>>'{data,status}' from notice_results where label='resumed'),'active',
  'paused item resumes immediately when its start is past');
select is((select body#>>'{data,status}' from notice_results where label='inactive'),'inactive',
  'active item can become terminal inactive');
select is((select body from notice_results where label='inactive_replay'),
  (select body from notice_results where label='inactive'), 'status command is idempotent');
select is((select body#>>'{error,code}' from notice_results where label='terminal'),'NOTICE_TERMINAL',
  'inactive is terminal');
select is((select body#>>'{error,code}' from notice_results where label='media'),'NOTICE_MEDIA_BLOCKED',
  'media fails closed until the R2 gateway exists');
select is((select body#>>'{error,code}' from notice_results where label='owner_aal1'),'SAI_MFA_REQUIRED',
  'Owner AAL1 fails closed even for read');
select is((select body#>>'{ok}' from notice_results where label='content_read'),'true',
  'Content can read the minimized directory');
select is((select body#>>'{error,code}' from notice_results where label='content_write'),'SAI_PERMISSION_DENIED',
  'Content cannot mutate Notices');
select is((select body#>>'{error,code}' from notice_results where label='scoped'),'SAI_PERMISSION_DENIED',
  'institution-scoped identity cannot widen into platform Notices');
select is((select body#>>'{error,code}' from notice_results where label='people_only'),'SAI_INTERNAL_CONTEXT_DENIED',
  'people-only cross-realm identity is denied');
select ok(not exists(select 1 from notice_results
  where (select array_agg(key order by key) from jsonb_object_keys(body) key)
    <> array['data','error','ok']::text[]), 'all RPCs use the stable envelope');
select ok(not exists(select 1 from notice_results where body::text like '%@invalid.test%'),
  'envelopes contain no Auth email');
select is((select status::text from public.platform_notices
  where id=(select (body#>>'{data,id}')::uuid from notice_results where label='saved')),
  'inactive','database persists the terminal state after reload');
select is((select count(*)::text from audit.audit_logs
  where object_type='platform_notice' and action_code like 'notice.%'),'5',
  'successful mutations are audited without message content');
select ok(not exists(select 1 from audit.audit_logs
  where object_type='platform_notice' and after_json::text like '%Manutenção%'),
  'audit does not store Notice content');
select ok(has_table_privilege('authenticated','public.platform_notices','SELECT') is false,
  'authenticated has no direct Notice table read');
select ok(has_table_privilege('authenticated','public.platform_notices','INSERT') is false,
  'authenticated has no direct Notice table write');
select ok(has_table_privilege('authenticated','analytics.notice_events','SELECT') is false,
  'analytics Notice events remain private');
select ok(has_function_privilege('authenticated',
  'public.superadmin_notice_directory_v2(text[],text,text[],text[],timestamptz,uuid,integer)','EXECUTE'),
  'authenticated may execute only the internal directory wrapper');
select ok(not has_function_privilege('anon',
  'public.superadmin_notice_directory_v2(text[],text,text[],text[],timestamptz,uuid,integer)','EXECUTE'),
  'anon cannot execute the internal directory wrapper');
select ok(not has_function_privilege('service_role',
  'public.superadmin_notice_directory_v2(text[],text,text[],text[],timestamptz,uuid,integer)','EXECUTE'),
  'service role is not a client bypass');
select ok(not exists(
  select 1 from public.platform_notices where status::text in ('published','archived')),
  'legacy statuses have no remaining rows');
select ok((select convalidated is false from pg_constraint
  where conname='platform_notices_internal_v2_values_ck'),
  'legacy rows do not block deploy while all new writes enforce the canonical check');

select * from finish();
rollback;
