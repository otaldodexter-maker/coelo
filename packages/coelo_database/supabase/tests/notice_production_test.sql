begin;
select plan(64);

select has_column('public','platform_notices','audience_json','structured audience is persisted');
select has_column('public','platform_notices','button_color','button color is persisted');
select has_column('public','platform_notices','popup_size','popup size is persisted');
select has_column('public','platform_notices','has_outer_inset','outer inset is persisted');
select has_column('public','platform_notices','management_version','optimistic version is persisted');
select has_table('app_private','notice_command_receipts','idempotency receipts exist');
select has_table('app_private','notice_publication_jobs','publication queue exists');
select has_table('app_private','notice_admin_audit','append-only audit exists');
select has_function('public','list_notices_for_superadmin',array['text','text[]','text[]','timestamp with time zone','uuid','integer'],'cursor list RPC exists');
select has_function('public','save_notice_draft_for_superadmin',array['uuid','jsonb','uuid','bigint'],'save command exists');
select has_function('public','publish_notice_for_superadmin',array['uuid','uuid','bigint'],'publish command exists');
select has_function('app_private','materialize_notice_publication_job',array['uuid','integer'],'recipient worker exists');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.platform_notices'::regclass),'notices force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.notice_receipts'::regclass),'receipts force RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='analytics.notice_events'::regclass),'notice events force RLS');
select ok(not has_table_privilege('authenticated','public.platform_notices','select'),'authenticated cannot select notices directly');
select ok(not has_table_privilege('authenticated','public.platform_notices','insert,update,delete'),'authenticated cannot mutate notices directly');
select ok(not has_table_privilege('authenticated','analytics.notice_events','select,insert,update,delete'),'frontend cannot access notice events directly');
select ok(has_function_privilege('authenticated','public.list_notices_for_superadmin(text,text[],text[],timestamptz,uuid,int)','execute'),'authenticated can call scoped list RPC');
select ok(not has_function_privilege('authenticated','app_private.materialize_notice_publication_job(uuid,int)','execute'),'frontend cannot execute worker');
select ok(not has_function_privilege('authenticated','app_private.validate_notice_audience(jsonb)','execute'),'frontend cannot invoke private audience validation');
select is((select confdeltype::text from pg_constraint where conname='notice_receipts_notice_id_fkey'),'r','receipt retention uses RESTRICT');
select ok(exists(select 1 from pg_trigger where tgrelid='app_private.notice_admin_audit'::regclass and tgname='notice_admin_audit_append_only' and not tgisinternal),'audit mutation trigger exists');
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"platform","select_all":true},{"dimension":"institution","select_all":true}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience','mixed audience dimensions fail closed'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"platform","select_all":false,"target_ids":["10000000-0000-4000-8000-000000000001"]}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_platform_audience','platform audience cannot disguise a global broadcast'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"institution","select_all":true,"filters":{"search":["a","b"]}}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience_search','select-all search must be one bounded value'
);
select ok(
  position('audience_label' in pg_get_constraintdef((select oid from pg_constraint where conname='platform_notices_production_values_ck'))) > 0,
  'audience label has a database length constraint'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"institution","select_all":true,"filters":{"institution_ids":{}}}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience_parent_filter','parent filters must be arrays'
);
select throws_ok(
  $$select app_private.validate_notice_audience(jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',true,'filters',jsonb_build_object('institution_ids',(select jsonb_agg(gen_random_uuid()) from generate_series(1,101))))),'role_codes','[]'::jsonb,'plan_ids','[]'::jsonb))$$,
  '22023','invalid_audience_parent_filter','parent filter arrays are bounded server-side'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"group","select_all":true,"filters":{"unit_ids":"not-an-array"}}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience_parent_filter','unit parent filters must also be bounded arrays'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"institution","select_all":true,"filters":{"institution_ids":["not-a-uuid"]}}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience_filter_id','parent filter values must be UUIDs'
);
select throws_ok(
  $$select app_private.validate_notice_audience('{"rules":[{"dimension":"institution","select_all":true,"filters":{"institution_ids":["82000000-0000-4000-8000-000000000099"]}}],"role_codes":[],"plan_ids":[]}'::jsonb)$$,
  '22023','invalid_audience_filter_target','parent filter UUIDs must identify live objects'
);
select ok(position('image_storage_decision_required' in pg_get_functiondef('public.publish_notice_for_superadmin(uuid,uuid,bigint)'::regprocedure))>0,'image publish is fail-closed');
select ok(
  position('aal2_required' in pg_get_functiondef('public.change_notice_status_for_superadmin(uuid,uuid,bigint,text,text)'::regprocedure))>0
  and position('notice.publish' in pg_get_functiondef('public.change_notice_status_for_superadmin(uuid,uuid,bigint,text,text)'::regprocedure))>0,
  'resume revalidates publish capability and AAL2 server-side'
);
select ok(
  position($needle$p_dimension='person'$needle$ in pg_get_functiondef('public.list_notice_audience_options_for_superadmin(text,text,uuid[],text,text,int)'::regprocedure))>0,
  'person audience options are resolved server-side'
);
select ok(
  position('p_limit + 1' in pg_get_functiondef('public.list_notices_for_superadmin(text[],text,text[],text[],timestamptz,uuid,int)'::regprocedure))>0,
  'directory cursor is returned only when another row exists'
);
select ok(
  position('for update skip locked' in lower(pg_get_functiondef('app_private.claim_notice_publication_jobs(text,int)'::regprocedure)))>0,
  'publication workers claim jobs concurrently without duplicate work'
);
select ok(
  position('request_hash' in pg_get_functiondef('public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)'::regprocedure))>0
  and position('management_version' in pg_get_functiondef('public.save_notice_draft_for_superadmin(uuid,jsonb,uuid,bigint)'::regprocedure))>0,
  'save enforces idempotency and optimistic concurrency'
);
select ok(
  position($needle$status::text in ('active','trial')$needle$ in pg_get_functiondef('app_private.materialize_notice_publication_job(uuid,int)'::regprocedure))>0,
  'recipient plan filter uses canonical subscription statuses'
);

insert into auth.users(id,aud,role,email,created_at,updated_at) values
  ('82000000-0000-4000-8000-000000000001','authenticated','authenticated','notice-owner@test.invalid',now(),now()),
  ('82000000-0000-4000-8000-000000000002','authenticated','authenticated','notice-denied@test.invalid',now(),now());
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
  ('82100000-0000-4000-8000-000000000001','adult','Notice','Owner','Notice Owner','active'),
  ('82100000-0000-4000-8000-000000000002','adult','Notice','Denied','Notice Denied','active');
insert into public.person_auth_links(person_id,auth_user_id,status) values
  ('82100000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001','active'),
  ('82100000-0000-4000-8000-000000000002','82000000-0000-4000-8000-000000000002','active');
insert into public.platform_memberships(person_id,role_id,status,scope_kind,mfa_required)
select '82100000-0000-4000-8000-000000000001',id,'active','platform',false
from public.platform_roles where code='owner';

create temporary table notice_test_inputs(
  payload jsonb not null,
  notice_id uuid,
  publication_job_id uuid
);
grant select,update on notice_test_inputs to authenticated,service_role;
insert into notice_test_inputs(payload) values(jsonb_build_object(
  'title','Runtime Notice','body','Runtime body','priority','important',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object(
    'dimension','platform','select_all',true,'target_ids','[]'::jsonb,
    'excluded_ids','[]'::jsonb,'filters','{}'::jsonb)),
    'role_codes','[]'::jsonb,'plan_ids','[]'::jsonb),
  'audience_label','Todos','behavior','dismissible','target_device','all',
  'content_format','text_background','background_color','#FFFFFF',
  'text_color','#3F4549','button_color','#D63C00','popup_size','standard',
  'has_outer_inset',true,'button_label','Entendi','link_label','',
  'recurrence','one_time','weekly_days','[]'::jsonb,
  'image_orientation','vertical'
));

set local role anon;
select throws_ok(
  $$select public.list_notices_for_superadmin()$$,
  '42501',null,'anonymous direct RPC call cannot enumerate notices'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000002","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select public.list_notices_for_superadmin()$$,
  '42501','not_authorized','authenticated actor without capability cannot list notices'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);
select lives_ok(
  $$select public.list_notices_for_superadmin()$$,
  'authorized reader can call list directly without relying on Flutter'
);
select throws_ok(
  $$select public.save_notice_draft_for_superadmin('82200000-0000-4000-8000-000000000001',(select payload from notice_test_inputs),null,null)$$,
  '42501','aal2_required','notice management fails closed below AAL2'
);
select throws_ok(
  $$select public.publish_notice_for_superadmin('82200000-0000-4000-8000-000000000002','82200000-0000-4000-8000-000000000099',1)$$,
  '42501','aal2_required','notice publication fails closed below AAL2 before object lookup'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select * from public.platform_notices$$,
  '42501',null,'authenticated frontend cannot bypass RPCs with direct table reads'
);
select throws_ok(
  $$select public.save_notice_draft_for_superadmin('82200000-0000-4000-8000-000000000003',jsonb_set((select payload from notice_test_inputs),'{audience_label}',to_jsonb(repeat('x',201))),null,null)$$,
  '22023','invalid_notice_payload','oversized audience label is rejected server-side'
);
select lives_ok(
  $$with saved as (
      select public.save_notice_draft_for_superadmin(
        '82200000-0000-4000-8000-000000000004',
        (select payload from notice_test_inputs),null,null
      ) result
    )
    update notice_test_inputs
       set notice_id=(saved.result->>'id')::uuid
      from saved$$,
  'authorized AAL2 manager can create a valid notice through the RPC'
);
select is(
  (public.get_notice_for_superadmin((select notice_id from notice_test_inputs))->>'title'),
  'Runtime Notice','authorized reader can retrieve the notice created through the command RPC'
);
select throws_ok(
  $$select public.get_notice_for_superadmin('82200000-0000-4000-8000-000000000099')$$,
  'P0002','notice_not_found','arbitrary UUID cannot disclose another object'
);
select is(
  (public.publish_notice_for_superadmin(
    '82200000-0000-4000-8000-000000000005',
    (select notice_id from notice_test_inputs),1
  )->>'status'),
  'scheduled','authorized AAL2 publisher can queue a valid notice'
);
reset role;

insert into public.notice_receipts(
  notice_id,person_id,institution_id,materialized_at
) values (
  (select notice_id from notice_test_inputs),
  '82100000-0000-4000-8000-000000000001',
  null,
  now()-interval '1 day'
);
update notice_test_inputs input
set publication_job_id=job.id
from app_private.notice_publication_jobs job
where job.notice_id=input.notice_id;

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok(
  $$select * from public.claim_notice_publication_jobs_for_worker('notice-test-worker',20)$$,
  'worker can claim the first due publication'
);
select is(
  (public.run_notice_publication_job_for_worker(
    (select publication_job_id from notice_test_inputs),
    1000
  )->>'state'),
  'completed','first publication materializes completely'
);
reset role;
select ok(
  (select current_publication_job_id is not null from public.platform_notices where id=(select notice_id from notice_test_inputs)),
  'completed publication becomes the current publication'
);
select ok(
  (select publication_job_id is not null and notice_version is not null and delivered_at is null
     from public.notice_receipts
     where notice_id=(select notice_id from notice_test_inputs)
       and publication_job_id=(select publication_job_id from notice_test_inputs)),
  'materialized receipt is versioned without fabricating delivery'
);
select is(
  (select count(*)::integer from public.notice_receipts
   where notice_id=(select notice_id from notice_test_inputs)
     and publication_job_id is null),
  1,'legacy unversioned receipts remain historical and are not adopted'
);

update public.notice_receipts
set delivered_at=now(),delivery_state='delivered'
where publication_job_id=(select publication_job_id from notice_test_inputs);
update public.platform_notices
set status='scheduled',processing_state='queued',published_at=null,
    management_version=management_version+1,ends_at=null
where id=(select notice_id from notice_test_inputs);
insert into app_private.notice_publication_jobs(notice_id,notice_version,audience_snapshot,available_at)
select id,management_version,audience_json,now() from public.platform_notices
where id=(select notice_id from notice_test_inputs);
update notice_test_inputs input
set publication_job_id=job.id
from app_private.notice_publication_jobs job
where job.notice_id=input.notice_id
  and job.notice_version=(select management_version from public.platform_notices where id=input.notice_id);

set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok(
  $$select * from public.claim_notice_publication_jobs_for_worker('notice-test-worker-2',20)$$,
  'worker can claim a republished notice'
);
select is(
  (public.run_notice_publication_job_for_worker(
    (select publication_job_id from notice_test_inputs),
    1000
  )->>'state'),
  'completed','republished notice materializes independently'
);
reset role;
select is(
  (select count(*)::integer from public.notice_receipts where notice_id=(select notice_id from notice_test_inputs)),
  3,'republication preserves legacy and separate receipt generations'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
select is(
  (public.get_notice_for_superadmin((select notice_id from notice_test_inputs))->>'reach')::integer,
  1,'detail reach counts only the current publication'
);
select is(
  (public.get_notice_for_superadmin((select notice_id from notice_test_inputs))->>'delivered_count')::integer,
  0,'delivery metrics do not leak from the previous publication'
);
reset role;

update public.platform_notices
set status='scheduled',processing_state='queued',management_version=management_version+1,
    ends_at=now()-interval '1 minute'
where id=(select notice_id from notice_test_inputs);
insert into app_private.notice_publication_jobs(notice_id,notice_version,audience_snapshot,available_at)
select id,management_version,audience_json,now() from public.platform_notices
where id=(select notice_id from notice_test_inputs);
update notice_test_inputs input
set publication_job_id=job.id
from app_private.notice_publication_jobs job
where job.notice_id=input.notice_id
  and job.notice_version=(select management_version from public.platform_notices where id=input.notice_id);
set local role service_role;
select set_config('request.jwt.claim.role','service_role',true);
select lives_ok(
  $$select * from public.claim_notice_publication_jobs_for_worker('notice-test-worker-expired',20)$$,
  'worker can claim an expired queued publication for terminal handling'
);
select is(
  (public.run_notice_publication_job_for_worker(
    (select publication_job_id from notice_test_inputs),
    1000
  )->>'error_code'),
  'notice_expired','expired notice fails closed without activation'
);
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000002","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select public.get_notice_for_superadmin((select notice_id from notice_test_inputs))$$,
  '42501','not_authorized','actor without capability cannot use a known notice UUID'
);
reset role;

update public.platform_memberships set status='revoked',revoked_at=now()
where person_id='82100000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','82000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"82000000-0000-4000-8000-000000000001","aal":"aal2","role":"authenticated"}',true);
select throws_ok(
  $$select public.get_notice_for_superadmin((select notice_id from notice_test_inputs))$$,
  '42501','not_authorized','membership revocation is revalidated on the next direct request'
);
reset role;

select * from finish();
rollback;
