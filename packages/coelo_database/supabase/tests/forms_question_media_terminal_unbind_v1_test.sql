begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into public.institution_types(id,code,name,status) values
 ('9f090000-0000-4000-8000-000000000001','qa-r08-fmedia-unbind','QA R08 forms media unbind','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9f090000-0000-4000-8000-000000000010','QA R08 FM unbind','qa-r08-fm-unbind','active','9f090000-0000-4000-8000-000000000001');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9f090000-0000-4000-8000-000000000102','authenticated','authenticated','fm-unbind@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9f090000-0000-4000-8000-000000000202','9f090000-0000-4000-8000-000000000102',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9f090000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9f090000-0000-4000-8000-000000000402','9f090000-0000-4000-8000-000000000302','9f090000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id)
select '9f090000-0000-4000-8000-000000000502',
  '9f090000-0000-4000-8000-000000000302',r.id,
  'institution'::app_private.superadmin_internal_scope_kind,
  '9f090000-0000-4000-8000-000000000010'
from public.platform_roles r where r.code='owner';

insert into public.forms(id,institution_id,kind,identity_mode,response_unit,title,created_by_internal_identity_id,updated_by_internal_identity_id)
values ('9f090000-0000-4000-8000-000000000600','9f090000-0000-4000-8000-000000000010','form','identified','person','Form terminal',
  '9f090000-0000-4000-8000-000000000302','9f090000-0000-4000-8000-000000000302');
insert into public.form_versions(id,form_id,version_number,created_by_internal_identity_id)
values ('9f090000-0000-4000-8000-000000000601','9f090000-0000-4000-8000-000000000600',1,'9f090000-0000-4000-8000-000000000302');
update public.forms set working_version_id='9f090000-0000-4000-8000-000000000601'
where id='9f090000-0000-4000-8000-000000000600';
insert into public.form_sections(id,form_version_id,title,position)
values ('9f090000-0000-4000-8000-000000000602','9f090000-0000-4000-8000-000000000601','Secao',0);
insert into public.form_items(id,form_version_id,section_id,kind,label,position) values
 ('9f090000-0000-4000-8000-000000000603','9f090000-0000-4000-8000-000000000601','9f090000-0000-4000-8000-000000000602','photo','Mismatch',0),
 ('9f090000-0000-4000-8000-000000000604','9f090000-0000-4000-8000-000000000601','9f090000-0000-4000-8000-000000000602','photo','Expira',1);

select ok(exists(
  select 1 from pg_catalog.pg_trigger
  where tgrelid='public.media_assets'::regclass
    and tgname='form_media_unbind_deleted_question_v1' and not tgisinternal
),'trigger terminal de question-image existe');

create temporary table fm_terminal(label text primary key,body jsonb not null);
grant select,insert on fm_terminal to authenticated,service_role;
select set_config('request.jwt.claims',jsonb_build_object('sub','9f090000-0000-4000-8000-000000000102','session_id','9f090000-0000-4000-8000-000000000202','aal','aal1','role','authenticated')::text,true);
set local role authenticated;
insert into fm_terminal values
 ('prepare_mismatch',public.superadmin_form_media_prepare_v2(
   '9f090000-0000-4000-8000-000000000901','9f090000-0000-4000-8000-000000000600',
   '9f090000-0000-4000-8000-000000000601','9f090000-0000-4000-8000-000000000603',
   'image/png',1024,repeat('a',64))),
 ('prepare_expire',public.superadmin_form_media_prepare_v2(
   '9f090000-0000-4000-8000-000000000902','9f090000-0000-4000-8000-000000000600',
   '9f090000-0000-4000-8000-000000000601','9f090000-0000-4000-8000-000000000604',
   'image/webp',2048,repeat('b',64)));
reset role;
select ok((select bool_and(body->>'ok'='true') from fm_terminal where label like 'prepare_%'),
  'prepare cria os dois assets e bindings');
create temporary table fm_terminal_ids as
select label,(body#>>'{data,asset_id}')::uuid asset_id,(body#>>'{data,finalize_ticket}')::uuid ticket
from fm_terminal where label like 'prepare_%';
grant select on fm_terminal_ids to service_role;

select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm_terminal values('mismatch',public.form_media_finalize_question_r2_v1(
  (select asset_id from fm_terminal_ids where label='prepare_mismatch'),
  (select ticket from fm_terminal_ids where label='prepare_mismatch'),
  1024,repeat('f',64),640,480));
reset role;
select is((select body#>>'{error,code}' from fm_terminal where label='mismatch'),'FORM_MEDIA_MISMATCH',
  'mismatch encerra o asset');
select ok(not exists(
  select 1 from public.media_bindings
  where media_asset_id=(select asset_id from fm_terminal_ids where label='prepare_mismatch')
),'mismatch solta o binding invisivel');

update app_private.form_media_upload_tickets set expires_at=now()-interval '1 minute'
where asset_id=(select asset_id from fm_terminal_ids where label='prepare_expire');
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
set local role service_role;
insert into fm_terminal values('expire',public.form_media_expire_question_r2_v1(100));
reset role;
select is((select (body#>>'{data,expired}')::integer from fm_terminal where label='expire'),1,
  'sweep expira o asset pendente');
select ok(not exists(
  select 1 from public.media_bindings
  where media_asset_id=(select asset_id from fm_terminal_ids where label='prepare_expire')
),'expiracao solta o binding invisivel');

select lives_ok($$
  select app_private.form_replace_working_definition(
    '9f090000-0000-4000-8000-000000000601',
    '[{"id":"secao-final","title":"Secao","description":null,"position":0,"items":[{"id":"texto-final","kind":"short_text","label":"Texto","help_text":null,"position":0,"is_required":false,"config":{},"options":[],"conditions":[]}]}]'::jsonb
  )
$$,'perguntas encerradas por mismatch/expire podem ser removidas');

select * from finish();
rollback;
