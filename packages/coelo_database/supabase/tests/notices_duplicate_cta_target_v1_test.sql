-- Prova pgTAP da migration 20260919230000_notices_duplicate_cta_target_v1 (spec 069, H08 + H13).
-- Fixture sintética com rollback total (prefixo 9c1): owner interno (aal2), content interno
-- (notices.manage sem publish), instituições Ipê e Jacarandá, uma circular em cada.
begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

select has_column('public','platform_notices','cta_target_kind','cta_target_kind exists');
select has_column('public','platform_notices','cta_target_id','cta_target_id exists');
select has_function('public','superadmin_notice_duplicate_v2',array['uuid','uuid'],'duplicate v2 exists');
select ok(has_function_privilege('authenticated','public.superadmin_notice_duplicate_v2(uuid,uuid)','execute'),
  'authenticated can call duplicate');
select ok(not has_function_privilege('anon','public.superadmin_notice_duplicate_v2(uuid,uuid)','execute'),
  'anon cannot call duplicate');
select ok(not has_function_privilege('authenticated','app_private.superadmin_notice_cta_target(jsonb)','execute'),
  'cta helper is private');
select ok(position('superadmin_notice_command_receipts' in pg_get_functiondef('public.superadmin_notice_duplicate_v2(uuid,uuid)'::regprocedure))>0,
  'duplicate is idempotent');
select ok(position('superadmin_notice_cta_target' in pg_get_functiondef('public.superadmin_notice_save_draft_v2(uuid,uuid,bigint,jsonb)'::regprocedure))>0,
  'save validates cta target');

insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c100000-0000-4000-8000-000000000101','authenticated','authenticated','dup-owner@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000102','authenticated','authenticated','dup-content@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c100000-0000-4000-8000-000000000201','9c100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000202','9c100000-0000-4000-8000-000000000102',now(),now(),'aal2',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values
 ('9c100000-0000-4000-8000-000000000001','dup-test','Dup test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c100000-0000-4000-8000-000000000010','Colégio Ipê','dup-ipe','active','9c100000-0000-4000-8000-000000000001'),
 ('9c100000-0000-4000-8000-000000000011','Colégio Jacarandá','dup-jaca','active','9c100000-0000-4000-8000-000000000001');
insert into app_private.superadmin_internal_identities(id) values
 ('9c100000-0000-4000-8000-000000000301'),('9c100000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000101'),
 ('9c100000-0000-4000-8000-000000000402','9c100000-0000-4000-8000-000000000302','9c100000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select f.id,f.identity_id,r.id,f.scope_kind::app_private.superadmin_internal_scope_kind,null
from (values
 ('9c100000-0000-4000-8000-000000000501'::uuid,'9c100000-0000-4000-8000-000000000301'::uuid,'owner','platform'),
 ('9c100000-0000-4000-8000-000000000502'::uuid,'9c100000-0000-4000-8000-000000000302'::uuid,'content','platform')
) f(id,identity_id,role_code,scope_kind) join public.platform_roles r on r.code=f.role_code;
insert into public.circulars(id,institution_id,status,author_internal_identity_id,author_internal_membership_id) values
 ('9c100000-0000-4000-8000-000000000801','9c100000-0000-4000-8000-000000000010','draft','9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000501'),
 ('9c100000-0000-4000-8000-000000000802','9c100000-0000-4000-8000-000000000011','draft','9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000501');

create temporary table r(label text primary key, body jsonb not null);
create function pg_temp.payload(p_cta jsonb, p_audience jsonb default null) returns jsonb language sql immutable as $$
  select jsonb_build_object(
    'type','for_you','title','Volta às aulas','body','Confira a circular.',
    'priority','important','audience',coalesce(p_audience,jsonb_build_object('rules',jsonb_build_array(
      jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb)))),
    'audience_label','Toda a plataforma','behavior','dismissible','target_device','all',
    'content_format','text_background','background_color','#D63C00','text_color','#FFFFFF',
    'button_color','#D63C00','popup_size','standard','has_outer_inset',true,
    'button_label','Abrir','link_label','Ver circular','recurrence','one_time','weekly_days','[]'::jsonb,
    'image_orientation','vertical','starts_at',now()-interval '1 minute','ends_at',now()+interval '1 day',
    'cta_target',p_cta)
$$;

select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000101',
 'session_id','9c100000-0000-4000-8000-000000000201','aal','aal2','role','authenticated')::text,true);

-- H13 ---------------------------------------------------------------------------------------------
insert into r values ('saved',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000701',null,null,
  pg_temp.payload(jsonb_build_object('kind','circular','id','9c100000-0000-4000-8000-000000000801'))));
select is((select body->>'ok' from r where label='saved'),'true','save with circular cta ok');
select is((select body#>>'{data,cta_target,kind}' from r where label='saved'),'circular','cta kind projected');
select is((select body#>>'{data,cta_target,id}' from r where label='saved'),'9c100000-0000-4000-8000-000000000801','cta id projected');

insert into r values ('missing',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000702',null,null,
  pg_temp.payload(jsonb_build_object('kind','circular','id','9c100000-0000-4000-8000-000000000899'))));
select is((select body#>>'{error,code}' from r where label='missing'),'NOTICE_INVALID_INPUT','missing cta target rejected');

insert into r values ('bad_kind',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000703',null,null,
  pg_temp.payload(jsonb_build_object('kind','external','id','9c100000-0000-4000-8000-000000000801'))));
select is((select body#>>'{error,code}' from r where label='bad_kind'),'NOTICE_INVALID_INPUT','external kind rejected');

insert into r values ('outside',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000704',null,null,
  pg_temp.payload(jsonb_build_object('kind','circular','id','9c100000-0000-4000-8000-000000000802'),
    jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',false,
      'target_ids',jsonb_build_array('9c100000-0000-4000-8000-000000000010')))))));
select is((select body#>>'{error,code}' from r where label='outside'),'NOTICE_INVALID_INPUT','cta outside audience rejected');

insert into r values ('inside',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000705',null,null,
  pg_temp.payload(jsonb_build_object('kind','circular','id','9c100000-0000-4000-8000-000000000801'),
    jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',false,
      'target_ids',jsonb_build_array('9c100000-0000-4000-8000-000000000010')))))));
select is((select body->>'ok' from r where label='inside'),'true','cta inside audience accepted');

insert into r values ('none',public.superadmin_notice_save_draft_v2('9c100000-0000-4000-8000-000000000706',null,null,
  pg_temp.payload(null)));
select is((select body#>>'{data,cta_target,kind}' from r where label='none'),'none','absent cta = none');

-- H08 ---------------------------------------------------------------------------------------------
insert into r values ('published',public.superadmin_notice_publish_v2('9c100000-0000-4000-8000-000000000707',
  (select (body#>>'{data,id}')::uuid from r where label='saved'),1));
select is((select body#>>'{data,status}' from r where label='published'),'active','source is active');
insert into r values ('inactive',public.superadmin_notice_change_status_v2('9c100000-0000-4000-8000-000000000708',
  (select (body#>>'{data,id}')::uuid from r where label='saved'),2,'inactive','Encerrado'));
select is((select body#>>'{data,status}' from r where label='inactive'),'inactive','source is terminal');
insert into public.notice_receipts(notice_id,person_id,delivered_at)
select (body#>>'{data,id}')::uuid, p.id, now() from r, public.people p where r.label='saved' limit 1;

insert into r values ('dup',public.superadmin_notice_duplicate_v2('9c100000-0000-4000-8000-000000000709',
  (select (body#>>'{data,id}')::uuid from r where label='saved')));
select is((select body->>'ok' from r where label='dup'),'true','duplicate of terminal notice ok');
select is((select body#>>'{data,status}' from r where label='dup'),'draft','copy is a draft');
select is((select body#>>'{data,title}' from r where label='dup'),'Cópia de Volta às aulas','copy title');
select is((select body#>>'{data,management_version}' from r where label='dup'),'1','copy version 1');
select is((select body#>>'{data,starts_at}' from r where label='dup'),null,'copy has no starts_at');
select is((select body#>>'{data,ends_at}' from r where label='dup'),null,'copy has no ends_at');
select is((select body#>>'{data,reach}' from r where label='dup'),'0','copy has no receipts');
select is((select body#>>'{data,cta_target,id}' from r where label='dup'),'9c100000-0000-4000-8000-000000000801','copy keeps cta');
select is((select body#>>'{data,link_label}' from r where label='dup'),'Ver circular','copy keeps link label');
select is((select body#>>'{data,audience_label}' from r where label='dup'),'Toda a plataforma','copy keeps audience');
select isnt((select body#>>'{data,id}' from r where label='dup'),(select body#>>'{data,id}' from r where label='saved'),'copy is a new row');

insert into r values ('dup_replay',public.superadmin_notice_duplicate_v2('9c100000-0000-4000-8000-000000000709',
  (select (body#>>'{data,id}')::uuid from r where label='saved')));
select is((select body#>>'{data,id}' from r where label='dup_replay'),(select body#>>'{data,id}' from r where label='dup'),
  'replay returns the same copy');
select is((select count(*) from public.platform_notices where title='Cópia de Volta às aulas'),1::bigint,'replay creates no second copy');

select ok(exists(select 1 from audit.audit_logs where action_code='notice.duplicate'
  and object_id=(select (body#>>'{data,id}')::uuid from r where label='dup')
  and after_json->>'id'=(select body#>>'{data,id}' from r where label='saved')),
  'audit notice.duplicate with source id');

insert into r values ('dup_missing',public.superadmin_notice_duplicate_v2('9c100000-0000-4000-8000-000000000710',
  '9c100000-0000-4000-8000-000000000999'));
select is((select body#>>'{error,code}' from r where label='dup_missing'),'NOTICE_NOT_FOUND','missing source');

-- content (sem notices.publish) não duplica
select set_config('request.jwt.claims',jsonb_build_object('sub','9c100000-0000-4000-8000-000000000102',
 'session_id','9c100000-0000-4000-8000-000000000202','aal','aal2','role','authenticated')::text,true);
insert into r values ('dup_denied',public.superadmin_notice_duplicate_v2('9c100000-0000-4000-8000-000000000711',
  (select (body#>>'{data,id}')::uuid from r where label='saved')));
select is((select body->>'ok' from r where label='dup_denied'),'false','content role cannot duplicate');

select * from finish();
rollback;
