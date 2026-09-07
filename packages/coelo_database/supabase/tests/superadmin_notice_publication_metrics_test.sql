begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- Synthetic internal-only author: no person_auth_link or fabricated person.
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
  raw_app_meta_data,raw_user_meta_data) values
 ('9b300000-0000-4000-8000-000000000101','authenticated','authenticated',
  'notice-pipeline@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b300000-0000-4000-8000-000000000201','9b300000-0000-4000-8000-000000000101',
  now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9b300000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9b300000-0000-4000-8000-000000000401','9b300000-0000-4000-8000-000000000301',
  '9b300000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(
  id,internal_identity_id,platform_role_id,scope_kind)
select '9b300000-0000-4000-8000-000000000501',
  '9b300000-0000-4000-8000-000000000301',id,'platform'
from public.platform_roles where code='owner';

select is((select count(*)::integer from app_private.superadmin_internal_memberships
  where id='9b300000-0000-4000-8000-000000000501'),1,'synthetic Owner membership is present');

select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b300000-0000-4000-8000-000000000101',
 'session_id','9b300000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);

create temporary table pipeline_results(label text primary key,body jsonb not null);
-- Calls execute as the actual SQL client role. Fixtures/results remain private
-- to the test runner; no grants and no SECURITY DEFINER test helpers.
do $$
declare
  draft_result jsonb;
begin
  set local role authenticated;
  draft_result := public.superadmin_notice_save_draft_v2(
 '9b300000-0000-4000-8000-000000000701',null,null,
 jsonb_build_object('type','popup','title','Aviso sintético','body','Conteúdo de teste.',
  'priority','routine','audience',jsonb_build_object('rules',jsonb_build_array(
    jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb))),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all',
  'content_format','text_background','background_color','#D63C00','text_color','#FFFFFF',
  'button_color','#D63C00','popup_size','standard','has_outer_inset',true,
  'button_label','Entendi','recurrence','one_time','weekly_days','[]'::jsonb,
  'image_orientation','vertical','starts_at',now()-interval '1 minute',
  'ends_at',now()+interval '1 day'));
  reset role;
  insert into pipeline_results values ('draft',draft_result);
exception when others then
  reset role;
  raise;
end $$;

-- Direct owner fixtures below isolate metric generations; they do not simulate
-- a successful worker or prove delivery. Recipient people are not author links.
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9b300000-0000-4000-8000-000000000601','adult','Recipient','One','Recipient One','active'),
 ('9b300000-0000-4000-8000-000000000602','adult','Recipient','Two','Recipient Two','active'),
 ('9b300000-0000-4000-8000-000000000603','adult','Recipient','Three','Recipient Three','active');

insert into app_private.notice_publication_jobs(id,notice_id,notice_version,audience_snapshot,state,completed_at)
select fixture.job_id,(body#>>'{data,id}')::uuid,fixture.version,body#>'{data,audience}','completed',now()
from pipeline_results cross join (values
 ('9b300000-0000-4000-8000-000000000801'::uuid,2),
 ('9b300000-0000-4000-8000-000000000802'::uuid,3)
) fixture(job_id,version) where label='draft';

update public.platform_notices set status='active',management_version=3,published_at=now(),
  current_publication_job_id=null
where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft');

insert into public.notice_receipts(notice_id,person_id,publication_job_id,notice_version,
  delivered_at,opened_at,acted_at,delivery_state)
select (body#>>'{data,id}')::uuid,fixture.person_id,fixture.job_id,fixture.version,
  case when fixture.level>=1 then now() end,
  case when fixture.level>=2 then now() end,
  case when fixture.level>=3 then now() end,
  case fixture.level when 3 then 'acted' when 2 then 'opened' when 1 then 'delivered' else 'pending' end
from pipeline_results cross join (values
 ('9b300000-0000-4000-8000-000000000601'::uuid,'9b300000-0000-4000-8000-000000000801'::uuid,2,3),
 ('9b300000-0000-4000-8000-000000000601'::uuid,'9b300000-0000-4000-8000-000000000802'::uuid,3,3),
 ('9b300000-0000-4000-8000-000000000602'::uuid,'9b300000-0000-4000-8000-000000000802'::uuid,3,1),
 ('9b300000-0000-4000-8000-000000000603'::uuid,'9b300000-0000-4000-8000-000000000802'::uuid,3,0),
 ('9b300000-0000-4000-8000-000000000603'::uuid,null::uuid,null::integer,3)
) fixture(person_id,job_id,version,level) where label='draft';

create temporary table original_receipts as select * from public.notice_receipts
where notice_id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft');
create function pg_temp.metric_tuple(p_value jsonb) returns jsonb language sql as $$
 select jsonb_build_array(p_value->'reach',p_value->'delivered_count',
   p_value->'viewed_count',p_value->'accepted_count')
$$;
do $$
declare
  notice_id uuid;
  detail_result jsonb;
  directory_result jsonb;
begin
  select (body#>>'{data,id}')::uuid into notice_id
    from pipeline_results where label='draft';
  set local role authenticated;
  detail_result := public.superadmin_notice_detail_v2(notice_id);
  directory_result := public.superadmin_notice_directory_v2(
    null,'Aviso sintético',null,null,null,null,24);
  reset role;
  insert into pipeline_results values
    ('no_job_detail',detail_result),('no_job_directory',directory_result);
exception when others then
  reset role;
  raise;
end $$;

select is((select body->>'ok' from pipeline_results where label='draft'),'true',
  'internal author saves the fixture without a people bridge');
select is((select count(*)::integer from original_receipts),5,
  'fixtures include current, previous and unversioned receipts');
select is((select pg_temp.metric_tuple(body->'data') from pipeline_results where label='no_job_detail'),
 '[0,0,0,0]'::jsonb,'detail shows zero metrics with no current generation');
select is((select pg_temp.metric_tuple(body#>'{data,items,0}') from pipeline_results where label='no_job_directory'),
 '[0,0,0,0]'::jsonb,'directory shows zero metrics with no current generation');

update public.platform_notices
set current_publication_job_id='9b300000-0000-4000-8000-000000000802'
where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft');
do $$
declare
  notice_id uuid;
  detail_result jsonb;
  directory_result jsonb;
begin
  select (body#>>'{data,id}')::uuid into notice_id
    from pipeline_results where label='draft';
  set local role authenticated;
  detail_result := public.superadmin_notice_detail_v2(notice_id);
  directory_result := public.superadmin_notice_directory_v2(
    null,'Aviso sintético',null,null,null,null,24);
  reset role;
  insert into pipeline_results values
    ('current_detail',detail_result),('current_directory',directory_result);
exception when others then
  reset role;
  raise;
end $$;
select is((select pg_temp.metric_tuple(body->'data') from pipeline_results where label='current_detail'),
 '[3,2,1,1]'::jsonb,'detail counts only the selected publication generation');
select is((select pg_temp.metric_tuple(body#>'{data,items,0}') from pipeline_results where label='current_directory'),
 '[3,2,1,1]'::jsonb,'directory counts only the selected publication generation');

update public.platform_notices set status='paused',management_version=4
where id=(select (body#>>'{data,id}')::uuid from pipeline_results where label='draft');
do $$
declare
  notice_id uuid;
  detail_result jsonb;
begin
  select (body#>>'{data,id}')::uuid into notice_id
    from pipeline_results where label='draft';
  set local role authenticated;
  detail_result := public.superadmin_notice_detail_v2(notice_id);
  reset role;
  insert into pipeline_results values ('paused_detail',detail_result);
exception when others then
  reset role;
  raise;
end $$;
select is((select pg_temp.metric_tuple(body->'data') from pipeline_results where label='paused_detail'),
 '[3,2,1,1]'::jsonb,'pausing increments management version without erasing publication metrics');
select ok(not exists(
 (select * from original_receipts except select * from public.notice_receipts)
 union all
 (select * from public.notice_receipts where notice_id=
   (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')
  except select * from original_receipts)
),'reading metrics preserves all historical receipts and delivery timestamps');
select is((select count(*)::integer from app_private.notice_publication_jobs where notice_id=
 (select (body#>>'{data,id}')::uuid from pipeline_results where label='draft')),2,
 'metric reads do not create or discard publication jobs');

select * from finish();
rollback;
