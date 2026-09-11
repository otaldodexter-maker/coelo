-- pgTAP do worker de materializacao de Avisos v2 (candidato 20260910200500).
-- Fixture de identidades internas derivada de superadmin_internal_notices_v2_baseline_test.sql.
-- Simula a Edge Function notice-publication-worker: claims role=service_role,
-- papel service_role, wrappers publicos *_for_worker com os mesmos parametros do index.ts.
begin;
create extension if not exists pgtap with schema extensions;
select plan(52);

-- Objetos e ACL
select has_table('app_private', 'notice_publication_jobs', 'publication job queue exists');
select has_function('app_private', 'claim_notice_publication_jobs', array['text','integer'], 'claim exists');
select has_function('app_private', 'materialize_notice_publication_job', array['uuid','integer'], 'materializer exists');
select has_function('app_private', 'run_notice_publication_job', array['uuid','integer'], 'guarded run exists');
select has_function('public', 'claim_notice_publication_jobs_for_worker', array['text','integer'], 'claim wrapper exists');
select has_function('public', 'run_notice_publication_job_for_worker', array['uuid','integer'], 'run wrapper exists');
select ok(has_function_privilege('service_role', 'public.claim_notice_publication_jobs_for_worker(text,integer)', 'execute'),
  'service_role may execute the claim wrapper');
select ok(has_function_privilege('service_role', 'public.run_notice_publication_job_for_worker(uuid,integer)', 'execute'),
  'service_role may execute the run wrapper');
select ok(not has_function_privilege('authenticated', 'public.claim_notice_publication_jobs_for_worker(text,integer)', 'execute'),
  'authenticated cannot execute the claim wrapper');
select ok(not has_function_privilege('authenticated', 'public.run_notice_publication_job_for_worker(uuid,integer)', 'execute'),
  'authenticated cannot execute the run wrapper');
select ok(not has_function_privilege('anon', 'public.claim_notice_publication_jobs_for_worker(text,integer)', 'execute'),
  'anon cannot execute the claim wrapper');
select ok(not has_function_privilege('anon', 'public.run_notice_publication_job_for_worker(uuid,integer)', 'execute'),
  'anon cannot execute the run wrapper');
select ok(not has_function_privilege('service_role', 'app_private.run_notice_publication_job(uuid,integer)', 'execute')
  and not has_function_privilege('service_role', 'app_private.materialize_notice_publication_job(uuid,integer)', 'execute')
  and not has_function_privilege('service_role', 'app_private.claim_notice_publication_jobs(text,integer)', 'execute'),
  'service_role reaches app_private only through the definer wrappers');
select ok(not has_table_privilege('authenticated', 'app_private.notice_publication_jobs', 'select')
  and not has_table_privilege('service_role', 'app_private.notice_publication_jobs', 'select'),
  'job queue has no direct client read');
select ok((select relrowsecurity and relforcerowsecurity from pg_class
  where oid = 'app_private.notice_publication_jobs'::regclass), 'job queue is RLS deny-by-default');
select ok(position('append_notice_audit' in pg_get_functiondef('app_private.materialize_notice_publication_job(uuid,integer)'::regprocedure)) = 0
  and position('append_notice_audit' in pg_get_functiondef('app_private.run_notice_publication_job(uuid,integer)'::regprocedure)) = 0,
  'worker does not call the legacy people-based audit');
select ok(position('update public.platform_notices' in pg_get_functiondef('app_private.materialize_notice_publication_job(uuid,integer)'::regprocedure)) = 0
  and position('update public.platform_notices' in pg_get_functiondef('app_private.run_notice_publication_job(uuid,integer)'::regprocedure)) = 0,
  'worker never changes the notice status');

-- Fixture: identidades internas (owner), instituicoes, unidade, pessoas, vinculos
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9b200000-0000-4000-8000-000000000101','authenticated','authenticated','worker-owner@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9b200000-0000-4000-8000-000000000201','9b200000-0000-4000-8000-000000000101',now(),now(),'aal1',now()+interval '1 hour');
insert into public.institution_types(id,code,name,status) values
 ('9b200000-0000-4000-8000-000000000001','worker-v2-test','Worker v2 test','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9b200000-0000-4000-8000-000000000010','Colégio Araucária','worker-v2-araucaria','active','9b200000-0000-4000-8000-000000000001'),
 ('9b200000-0000-4000-8000-000000000011','Colégio Vazio','worker-v2-vazio','active','9b200000-0000-4000-8000-000000000001');
insert into public.unit_types(id,code,name) values
 ('9b200000-0000-4000-8000-000000000002','worker-v2-unit','Worker v2 unit');
insert into public.units(id,institution_id,name,slug,unit_type_id,handle) values
 ('9b200000-0000-4000-8000-000000000020','9b200000-0000-4000-8000-000000000010','Unidade Norte','norte',
  '9b200000-0000-4000-8000-000000000002','workerv2norte');
insert into app_private.superadmin_internal_identities(id) values ('9b200000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('9b200000-0000-4000-8000-000000000401','9b200000-0000-4000-8000-000000000301','9b200000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '9b200000-0000-4000-8000-000000000501','9b200000-0000-4000-8000-000000000301',role_record.id,'platform'
from public.platform_roles role_record where role_record.code='owner';
insert into public.people(id,person_type,first_name,last_name,display_name,status) values
 ('9b200000-0000-4000-8000-000000000601','adult','Ana','Ativa','Ana Ativa','active'),
 ('9b200000-0000-4000-8000-000000000602','adult','Rui','Revogado','Rui Revogado','active'),
 ('9b200000-0000-4000-8000-000000000603','adult','Uma','Unidade','Uma Unidade','active');
insert into public.institution_memberships(id,person_id,institution_id,role_code,status,scope_kind,scope_unit_id,revoked_at) values
 ('9b200000-0000-4000-8000-000000000801','9b200000-0000-4000-8000-000000000601','9b200000-0000-4000-8000-000000000010','staff','active','institution',null,null),
 ('9b200000-0000-4000-8000-000000000802','9b200000-0000-4000-8000-000000000602','9b200000-0000-4000-8000-000000000010','staff','inactive','institution',null,now()),
 ('9b200000-0000-4000-8000-000000000803','9b200000-0000-4000-8000-000000000603','9b200000-0000-4000-8000-000000000010','guardian','active','unit','9b200000-0000-4000-8000-000000000020',null);

create temporary table worker_results(label text primary key, body jsonb not null);
grant select, insert on worker_results to service_role;

create temporary table notice_ids(label text primary key, notice_id uuid not null);

-- Owner publica pelo v2
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b200000-0000-4000-8000-000000000101','session_id','9b200000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);

create temporary table v2_results(label text primary key, body jsonb not null);
insert into v2_results values ('saved_platform', public.superadmin_notice_save_draft_v2(
 '9b200000-0000-4000-8000-000000000701',null,null,
 jsonb_build_object('type','popup','title','Aviso plataforma','body','Para todos.','priority','routine',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','platform','select_all',true,'target_ids','[]'::jsonb)),
    'role_codes','[]'::jsonb,'plan_ids','[]'::jsonb),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all','content_format','text_background',
  'popup_size','standard','has_outer_inset',true,'recurrence','one_time','image_orientation','vertical',
  'starts_at',now()-interval '1 minute','ends_at',now()+interval '1 day')));
insert into v2_results values ('saved_institution', public.superadmin_notice_save_draft_v2(
 '9b200000-0000-4000-8000-000000000702',null,null,
 jsonb_build_object('type','popup','title','Aviso Araucária','body','Somente Araucária.','priority','important',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',false,
    'target_ids',jsonb_build_array('9b200000-0000-4000-8000-000000000010'),'excluded_ids','[]'::jsonb,'filters','{}'::jsonb)),
    'role_codes','[]'::jsonb,'plan_ids','[]'::jsonb),
  'audience_label','Colégio Araucária','behavior','dismissible','target_device','all','content_format','text_background',
  'popup_size','standard','has_outer_inset',true,'recurrence','one_time','image_orientation','vertical',
  'starts_at',now()-interval '1 minute','ends_at',now()+interval '1 day')));
insert into v2_results values ('saved_empty', public.superadmin_notice_save_draft_v2(
 '9b200000-0000-4000-8000-000000000703',null,null,
 jsonb_build_object('type','popup','title','Aviso vazio','body','Ninguém.','priority','routine',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','institution','select_all',false,
    'target_ids',jsonb_build_array('9b200000-0000-4000-8000-000000000011')))),
  'audience_label','Colégio Vazio','behavior','dismissible','target_device','all','content_format','text_background',
  'popup_size','standard','has_outer_inset',true,'recurrence','one_time','image_orientation','vertical',
  'starts_at',now()-interval '1 minute')));
insert into v2_results values ('saved_future', public.superadmin_notice_save_draft_v2(
 '9b200000-0000-4000-8000-000000000704',null,null,
 jsonb_build_object('type','popup','title','Aviso futuro','body','Amanhã.','priority','routine',
  'audience',jsonb_build_object('rules',jsonb_build_array(jsonb_build_object('dimension','platform','select_all',true))),
  'audience_label','Toda a plataforma','behavior','dismissible','target_device','all','content_format','text_background',
  'popup_size','standard','has_outer_inset',true,'recurrence','one_time','image_orientation','vertical',
  'starts_at',now()+interval '1 day')));
insert into notice_ids select label, (body#>>'{data,id}')::uuid from v2_results;

insert into v2_results values ('published_platform', public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000711',(select notice_id from notice_ids where label='saved_platform'),1));
insert into v2_results values ('published_institution', public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000712',(select notice_id from notice_ids where label='saved_institution'),1));
insert into v2_results values ('published_empty', public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000713',(select notice_id from notice_ids where label='saved_empty'),1));
insert into v2_results values ('published_future', public.superadmin_notice_publish_v2(
 '9b200000-0000-4000-8000-000000000714',(select notice_id from notice_ids where label='saved_future'),1));

select is((select body#>>'{data,status}' from v2_results where label='published_platform'),'active',
  'v2 publish with past start is active');
select is((select body#>>'{data,status}' from v2_results where label='published_future'),'scheduled',
  'v2 publish with future start is scheduled');
select is((select count(*)::text from app_private.notice_publication_jobs job
  join notice_ids on notice_ids.notice_id=job.notice_id where job.state='queued'),'4',
  'publish enqueues one queued job per notice');
select is((select job.notice_version::text from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_platform')),'2',
  'job freezes the published management_version');
select ok((select job.available_at > now() from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_future')),
  'future scheduled job is not available before starts_at');
select is((select count(*)::text from public.notice_receipts receipt
  join notice_ids on notice_ids.notice_id=receipt.notice_id),'0',
  'publish alone creates no receipts');

-- Worker: claims service_role + papel service_role, wrappers publicos como index.ts
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into worker_results
select 'claim_1', coalesce(jsonb_agg(jsonb_build_object('id', claimed.id)), '[]'::jsonb)
from public.claim_notice_publication_jobs_for_worker('worker-test-1', 20) claimed;
insert into worker_results
select 'run_'||(job_row.value->>'id'), public.run_notice_publication_job_for_worker((job_row.value->>'id')::uuid, 1000)
from worker_results, jsonb_array_elements(worker_results.body) job_row where worker_results.label='claim_1';
insert into worker_results
select 'claim_2', coalesce(jsonb_agg(jsonb_build_object('id', claimed.id)), '[]'::jsonb)
from public.claim_notice_publication_jobs_for_worker('worker-test-1', 20) claimed;
reset role;

select is((select jsonb_array_length(body)::text from worker_results where label='claim_1'),'3',
  'claim returns exactly the available jobs (future job excluded)');
select is((select jsonb_array_length(body)::text from worker_results where label='claim_2'),'0',
  'second claim finds nothing left');
select is((select body->>'state' from worker_results where label='run_'||(select job.id::text
  from app_private.notice_publication_jobs job where job.notice_id=(select notice_id from notice_ids where label='saved_institution'))),
  'completed', 'institution-targeted job completes');
select is((select body->>'state' from worker_results where label='run_'||(select job.id::text
  from app_private.notice_publication_jobs job where job.notice_id=(select notice_id from notice_ids where label='saved_platform'))),
  'completed', 'platform job completes');
select is((select body->>'error_code' from worker_results where label='run_'||(select job.id::text
  from app_private.notice_publication_jobs job where job.notice_id=(select notice_id from notice_ids where label='saved_empty'))),
  'empty_audience', 'empty audience fails the job with empty_audience');
select is((select job.state||'/'||coalesce(job.last_error_code,'')||'/'||job.attempts::text from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_empty')),'failed/empty_audience/20',
  'empty job is failed and not retried');
select is((select status::text from public.platform_notices
  where id=(select notice_id from notice_ids where label='saved_empty')),'active',
  'empty audience does not change the notice status');
select is((select job.state||'/'||job.resolved_count::text||'/'||coalesce(job.locked_by,'released') from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_institution')),'completed/2/released',
  'institution job resolved two active members and released its lease');
select ok((select job.completed_at is not null from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_institution')),
  'completed job records completed_at');
select is((select string_agg(receipt.person_id::text, ',' order by receipt.person_id) from public.notice_receipts receipt
  where receipt.notice_id=(select notice_id from notice_ids where label='saved_institution')),
  '9b200000-0000-4000-8000-000000000601,9b200000-0000-4000-8000-000000000603',
  'receipts exist for active memberships only (revoked excluded)');
select ok((select bool_and(receipt.institution_id='9b200000-0000-4000-8000-000000000010' and receipt.delivered_at is null)
  from public.notice_receipts receipt where receipt.notice_id=(select notice_id from notice_ids where label='saved_institution')),
  'receipts carry the institution scope and are not delivered');
select ok(exists(select 1 from public.notice_receipts receipt
  where receipt.notice_id=(select notice_id from notice_ids where label='saved_platform')
    and receipt.person_id='9b200000-0000-4000-8000-000000000601'
    and receipt.institution_id='9b200000-0000-4000-8000-000000000010'),
  'platform audience reaches institution members');
select ok(not exists(select 1 from public.notice_receipts receipt
  where receipt.notice_id=(select notice_id from notice_ids where label='saved_platform')
    and receipt.person_id='9b200000-0000-4000-8000-000000000602'),
  'platform audience skips revoked memberships');
select is((select count(*)::text from analytics.notice_events event
  where event.notice_id=(select notice_id from notice_ids where label='saved_institution')
    and event.event_name='audience_materialized' and (event.properties_json->>'recipient_count')='2'),'1',
  'materialization leaves one analytics event');
select is((select count(*)::text from analytics.notice_events event
  where event.notice_id=(select notice_id from notice_ids where label='saved_empty') and event.event_name='audience_empty'),'1',
  'empty audience leaves one analytics event');

-- Reload pelo caminho do app: detail v2 mostra o alcance
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','9b200000-0000-4000-8000-000000000101','session_id','9b200000-0000-4000-8000-000000000201',
 'aal','aal1','role','authenticated')::text,true);
insert into v2_results values ('detail_institution', public.superadmin_notice_detail_v2(
 (select notice_id from notice_ids where label='saved_institution')));
select is((select body#>>'{data,reach}' from v2_results where label='detail_institution'),'2',
  'detail reload reports the materialized reach');
select is((select body#>>'{data,status}' from v2_results where label='detail_institution'),'active',
  'detail reload keeps the notice active');

-- Pausar e reagendar enfileira novo job; re-materializar nao duplica recibos
insert into v2_results values ('paused', public.superadmin_notice_change_status_v2(
 '9b200000-0000-4000-8000-000000000721',(select notice_id from notice_ids where label='saved_institution'),2,'paused',null));
insert into v2_results values ('resumed', public.superadmin_notice_change_status_v2(
 '9b200000-0000-4000-8000-000000000722',(select notice_id from notice_ids where label='saved_institution'),3,'scheduled',null));
select is((select body#>>'{data,status}' from v2_results where label='resumed'),'active',
  'resume with past start is active again');
select is((select string_agg(job.notice_version::text||':'||job.state, ',' order by job.notice_version)
  from app_private.notice_publication_jobs job
  where job.notice_id=(select notice_id from notice_ids where label='saved_institution')),'2:completed,4:queued',
  'resume enqueues a second job for the new version');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
insert into worker_results
select 'claim_3', coalesce(jsonb_agg(jsonb_build_object('id', claimed.id)), '[]'::jsonb)
from public.claim_notice_publication_jobs_for_worker('worker-test-2', 20) claimed;
insert into worker_results
select 'rerun', public.run_notice_publication_job_for_worker((body->0->>'id')::uuid, 1000)
from worker_results where label='claim_3';
reset role;

select is((select jsonb_array_length(body)::text from worker_results where label='claim_3'),'1',
  'only the new job is claimable');
select is((select body->>'state' from worker_results where label='rerun'),'completed',
  're-materialization completes');
select is((select count(*)::text from public.notice_receipts receipt
  where receipt.notice_id=(select notice_id from notice_ids where label='saved_institution')),'2',
  're-materialization does not duplicate receipts');

-- Negativas
select set_config('request.jwt.claims','{"role":"authenticated"}',true);
select throws_ok($$select * from public.claim_notice_publication_jobs_for_worker('worker-x', 20)$$,
  '42501','not_authorized','authenticated claims cannot claim jobs even through the wrapper');
select throws_ok($$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-0000000009ff', 1000)$$,
  '42501','not_authorized','authenticated claims cannot run jobs even through the wrapper');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select throws_ok($$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-0000000009ff', 1000)$$,
  'P0002','publication_job_not_found','unknown or already finished job is refused');
select throws_ok($$select * from public.claim_notice_publication_jobs_for_worker('worker-x', 500)$$,
  '42501','not_authorized','claim limit above 100 is refused');

set local role authenticated;
select throws_ok($$select * from public.claim_notice_publication_jobs_for_worker('worker-x', 20)$$,
  '42501', null, 'authenticated role has no execute on the claim wrapper');
select throws_ok($$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-0000000009ff', 1000)$$,
  '42501', null, 'authenticated role has no execute on the run wrapper');
reset role;
set local role anon;
select throws_ok($$select * from public.claim_notice_publication_jobs_for_worker('worker-x', 20)$$,
  '42501', null, 'anon role has no execute on the claim wrapper');
reset role;

select * from finish();
rollback;
