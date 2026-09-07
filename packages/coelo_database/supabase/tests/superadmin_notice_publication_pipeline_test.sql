begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

-- Synthetic internal-only author: no person_auth_link or fabricated person.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
 ('9b200000-0000-4000-8000-000000000101','authenticated','authenticated',
  'notice-pipeline@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b200000-0000-4000-8000-000000000201','9b200000-0000-4000-8000-000000000101',
  now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9b200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9b200000-0000-4000-8000-000000000401','9b200000-0000-4000-8000-000000000301',
  '9b200000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select '9b200000-0000-4000-8000-000000000501',
  '9b200000-0000-4000-8000-000000000301',id,'platform'
from public.platform_roles where code='owner';

select is((select count(*)::integer from app_private.superadmin_internal_memberships
  where id='9b200000-0000-4000-8000-000000000501'),1,'synthetic Owner membership is present');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b200000-0000-4000-8000-000000000101',
 'session_id','9b200000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

create temporary table pipeline_results(label text primary key,body jsonb not null);
insert into pipeline_results values ('draft',public.superadmin_notice_save_draft_v2(
 '9b200000-0000-4000-8000-000000000701',null,null,
 jsonb_build_object('type','popup','title','Aviso sintético','body','Conteúdo de teste.',
  'priority','routine','audience',jsonb_build_object('rules',jsonb_build_array(
    jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb))),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all',
  'content_format','text_background','background_color','#D63C00','text_color','#FFFFFF',
  'button_color','#D63C00','popup_size','standard','has_outer_inset',true,
  'button_label','Entendi','recurrence','one_time','weekly_days','[]'::jsonb,
  'image_orientation','vertical','starts_at',now()-interval '1 minute',
  'ends_at',now()+interval '1 day')));
insert into pipeline_results values ('publish',public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000702',
 (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft'),1));
insert into pipeline_results values ('replay',public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000702',
 (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft'),1));
insert into pipeline_results values ('detail',public.superadmin_notice_detail_v2(
 (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')));
insert into pipeline_results values ('directory',public.superadmin_notice_directory_v2(
 null,'Aviso sintético',array['scheduled'],null,null,null,24));

-- The baseline foundation profile lacks the worker table. Return an empty
-- inventory rather than aborting the test before the behavioral RED assertions.
create function pg_temp.pipeline_jobs(p_notice_id uuid) returns jsonb
language plpgsql as $$
declare result jsonb;
begin
  if to_regclass('app_private.notice_publication_jobs') is null then return '[]'::jsonb; end if;
  execute 'select coalesce(jsonb_agg(to_jsonb(job)), ''[]''::jsonb)
    from app_private.notice_publication_jobs job where notice_id=$1'
    into result using p_notice_id;
  return result;
end $$;
insert into pipeline_results values ('jobs',pg_temp.pipeline_jobs(
 (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')));

select is((select body#>>'{ok}' from pipeline_results where label='draft'),'true',
  'internal-only Owner can save the synthetic text draft');
select is((select body#>>'{ok}' from pipeline_results where label='publish'),'true',
  'authorized publish accepts the command');
select is((select body#>>'{data,status}' from pipeline_results where label='publish'),'scheduled',
  'past start still queues publication instead of claiming active delivery');
select is((select body#>>'{data,status}' from pipeline_results where label='detail'),'scheduled',
  'detail lifecycle refresh cannot activate before audience materialization');
select is((select jsonb_array_length(body#>'{data,items}') from pipeline_results where label='directory'),1,
  'directory lifecycle refresh preserves the queued scheduled notice');
select is((select body#>>'{data,management_version}' from pipeline_results where label='publish'),'2',
  'publication freezes a new version');
select is((select body from pipeline_results where label='replay'),
  (select body from pipeline_results where label='publish'),'publish replay returns the original receipt');
select is((select jsonb_array_length(body) from pipeline_results where label='jobs'),1,
  'publication and replay create exactly one job');
select is((select body#>>'{0,state}' from pipeline_results where label='jobs'),'queued',
  'new publication job starts queued');
select is((select body#>>'{0,notice_version}' from pipeline_results where label='jobs'),'2',
  'job freezes the accepted notice version');
select is((select body#>'{0,audience_snapshot}' from pipeline_results where label='jobs'),
  (select body#>'{data,audience}' from pipeline_results where label='draft'),
  'job freezes the authorized audience');
select ok((select (body#>>'{0,available_at}')::timestamptz <= clock_timestamp()
  from pipeline_results where label='jobs'),'past-start job is immediately eligible');
select is((select to_jsonb(notice)->>'processing_state' from public.platform_notices notice
  where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')),'queued',
  'notice persists the queued processing state');
select ok((select published_at is null from public.platform_notices
  where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')),
  'publication timestamp is absent until materialization completes');
select is((select count(*)::integer from public.notice_receipts where notice_id=
  (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')),0,
  'enqueue does not fabricate recipient delivery');
select ok((select approved_by is null and published_by_internal_identity_id=
  '9b200000-0000-4000-8000-000000000301'::uuid from public.platform_notices
  where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')),
  'publication preserves internal identity without a people bridge');

select * from finish();
rollback;
