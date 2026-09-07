begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

-- Prepared for the isolated N01 replay profile; no publication or real data.
select ok(not has_function_privilege('anon',
  'public.claim_notice_publication_jobs_for_worker(text,integer)','execute'),
  'anonymous cannot claim publication jobs');
select ok(not has_function_privilege('authenticated',
  'public.claim_notice_publication_jobs_for_worker(text,integer)','execute'),
  'authenticated clients cannot claim publication jobs');
select ok(not has_function_privilege('anon',
  'public.run_notice_publication_job_for_worker(uuid,integer)','execute'),
  'anonymous cannot run publication jobs');
select ok(not has_function_privilege('authenticated',
  'public.run_notice_publication_job_for_worker(uuid,integer)','execute'),
  'authenticated clients cannot run publication jobs');
select ok(not has_function_privilege('authenticated',
  'app_private.materialize_notice_publication_job(uuid,integer)','execute'),
  'authenticated clients cannot bypass the worker wrapper');
select ok(has_function_privilege('service_role',
  'public.run_notice_publication_job_for_worker(uuid,integer)','execute'),
  'worker retains its public run entry point');

set local role anon;
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker('synthetic-worker',1)$sql$,
  '42501',null,'anonymous execution cannot reach the claim worker');
select throws_ok($sql$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-000000000901',1)$sql$,
  '42501',null,'anonymous execution cannot reach the run worker');
reset role;
set local role authenticated;
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker('synthetic-worker',1)$sql$,
  '42501',null,'authenticated execution cannot reach the claim worker');
select throws_ok($sql$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-000000000901',1)$sql$,
  '42501',null,'authenticated execution cannot reach the run worker');
reset role;

select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is((select count(*)::integer from public.claim_notice_publication_jobs_for_worker('synthetic-worker',1)),
  0,'service role reaches the claim entry point in the isolated empty profile');
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker('synthetic-worker',null)$sql$,
  '42501','not_authorized','claim rejects NULL page limit before touching jobs');
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker(null,1)$sql$,
  '42501','not_authorized','claim rejects NULL worker name');
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker('synthetic-worker',101)$sql$,
  '42501','not_authorized','claim rejects oversized page limit');
select throws_ok($sql$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-000000000901',null)$sql$,
  '42501','not_authorized','run rejects NULL limit before looking up a job');
select throws_ok($sql$select public.run_notice_publication_job_for_worker('9b200000-0000-4000-8000-000000000901',0)$sql$,
  '42501','not_authorized','run rejects zero limit');
reset role;
-- Administrative direct-call guard probe, not a claim of client ACL access.
select throws_ok($sql$select app_private.materialize_notice_publication_job('9b200000-0000-4000-8000-000000000901',null)$sql$,
  '42501','not_authorized','direct materializer also rejects NULL limit');

select set_config('request.jwt.claim.role','',true);
select set_config('request.jwt.claims','{}',true);
set local role service_role;
select throws_ok($sql$select * from public.claim_notice_publication_jobs_for_worker('synthetic-worker',1)$sql$,
  '42501','not_authorized','claim denies an absent JWT role instead of NULL bypass');
reset role;
-- Administrative direct-call guard probe with no JWT role.
select throws_ok($sql$select app_private.materialize_notice_publication_job('9b200000-0000-4000-8000-000000000901',1)$sql$,
  '42501','not_authorized','materializer denies an absent JWT role');

select * from finish();
rollback;
