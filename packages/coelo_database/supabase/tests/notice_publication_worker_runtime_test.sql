begin;
select plan(16);

select has_function('app_private','run_notice_publication_job',array['uuid','integer'],'guarded worker entrypoint exists');
select has_function('app_private','dispatch_notice_publication_worker',array[]::text[],'cron dispatcher exists');
select has_function('public','claim_notice_publication_jobs_for_worker',array['text','integer'],'PostgREST claim wrapper exists');
select has_function('public','run_notice_publication_job_for_worker',array['uuid','integer'],'PostgREST run wrapper exists');
select ok(not has_function_privilege('authenticated','app_private.run_notice_publication_job(uuid,int)','execute'),'frontend cannot run publication jobs');
select ok(has_function_privilege('service_role','app_private.run_notice_publication_job(uuid,int)','execute'),'service role can run publication jobs');
select ok(not has_function_privilege('authenticated','public.run_notice_publication_job_for_worker(uuid,int)','execute'),'frontend cannot use worker wrapper');
select ok(has_function_privilege('service_role','public.run_notice_publication_job_for_worker(uuid,int)','execute'),'service role can use worker wrapper');
select ok(position('lease_expired' in pg_get_functiondef('app_private.claim_notice_publication_jobs(text,int)'::regprocedure))>0,'stale leases are recoverable');
select ok(position('for update skip locked' in lower(pg_get_functiondef('app_private.claim_notice_publication_jobs(text,int)'::regprocedure)))>0,'claims remain concurrent-safe');
select ok(position('notice.management_version <> job.notice_version' in pg_get_functiondef('app_private.run_notice_publication_job(uuid,int)'::regprocedure))>0,'superseded jobs fail closed');
select ok(position("notice.status::text <> 'scheduled'" in pg_get_functiondef('app_private.run_notice_publication_job(uuid,int)'::regprocedure))>0,'paused or inactive notices cannot materialize');
select ok(position('materialize_notice_publication_job' in pg_get_functiondef('app_private.run_notice_publication_job(uuid,int)'::regprocedure))>0,'valid jobs use the bounded materializer');
select is((select count(*)::integer from cron.job where jobname='coelo-notice-publication-worker'),1,'worker cron is versioned exactly once');
select ok(position('notice_publication_worker_secret' in pg_get_functiondef('app_private.dispatch_notice_publication_worker()'::regprocedure))>0,'dispatcher reads an opaque Vault secret');
select ok(position('delivered_at' in pg_get_functiondef('app_private.run_notice_publication_job(uuid,int)'::regprocedure))=0,'materialization never fabricates delivery timestamps');

select * from finish();
rollback;
