create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create or replace function app_private.claim_notice_publication_jobs(
  p_worker text,
  p_limit integer default 20
) returns setof app_private.notice_publication_jobs
language plpgsql security definer set search_path = '' as $$
begin
  if auth.role() <> 'service_role'
     or p_limit not between 1 and 100
     or length(trim(p_worker)) not between 1 and 120 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;

  update app_private.notice_publication_jobs
     set state = 'failed',
         available_at = now(),
         locked_at = null,
         locked_by = null,
         last_error_code = 'lease_expired'
   where state = 'processing'
     and locked_at < now() - interval '5 minutes'
     and attempts < 20;

  return query
  with claimed as (
    select id
      from app_private.notice_publication_jobs
     where state in ('queued', 'failed')
       and available_at <= now()
       and attempts < 20
     order by available_at, created_at
     for update skip locked
     limit p_limit
  )
  update app_private.notice_publication_jobs job
     set state = 'processing',
         attempts = job.attempts + 1,
         locked_at = now(),
         locked_by = trim(p_worker),
         last_error_code = null
    from claimed
   where job.id = claimed.id
  returning job.*;
end;
$$;

create or replace function app_private.run_notice_publication_job(
  p_job_id uuid,
  p_limit integer default 1000
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  job app_private.notice_publication_jobs;
  notice public.platform_notices;
begin
  if auth.role() <> 'service_role' or p_limit not between 1 and 5000 then
    raise exception using errcode = '42501', message = 'not_authorized';
  end if;

  select * into job
    from app_private.notice_publication_jobs
   where id = p_job_id and state = 'processing'
   for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'publication_job_not_found';
  end if;

  select * into notice
    from public.platform_notices
   where id = job.notice_id
   for share;
  if not found
     or notice.management_version <> job.notice_version
     or notice.status::text <> 'scheduled' then
    update app_private.notice_publication_jobs
       set state = 'failed',
           completed_at = null,
           locked_at = null,
           locked_by = null,
           last_error_code = case
             when notice.id is null then 'notice_missing'
             when notice.management_version <> job.notice_version then 'notice_superseded'
             else 'notice_not_scheduled'
           end
     where id = job.id;
    return jsonb_build_object('state', 'failed', 'error_code', case
      when notice.id is null then 'notice_missing'
      when notice.management_version <> job.notice_version then 'notice_superseded'
      else 'notice_not_scheduled'
    end);
  end if;

  return app_private.materialize_notice_publication_job(p_job_id, p_limit);
end;
$$;

revoke all on function app_private.claim_notice_publication_jobs(text, integer) from public, anon, authenticated;
revoke all on function app_private.run_notice_publication_job(uuid, integer) from public, anon, authenticated;
grant execute on function app_private.claim_notice_publication_jobs(text, integer) to service_role;
grant execute on function app_private.run_notice_publication_job(uuid, integer) to service_role;

create or replace function public.claim_notice_publication_jobs_for_worker(
  p_worker text,
  p_limit integer default 20
) returns table(id uuid)
language sql security definer set search_path = '' as $$
  select claimed.id from app_private.claim_notice_publication_jobs(p_worker, p_limit) claimed;
$$;

create or replace function public.run_notice_publication_job_for_worker(
  p_job_id uuid,
  p_limit integer default 1000
) returns jsonb
language sql security definer set search_path = '' as $$
  select app_private.run_notice_publication_job(p_job_id, p_limit);
$$;

revoke all on function public.claim_notice_publication_jobs_for_worker(text, integer) from public, anon, authenticated;
revoke all on function public.run_notice_publication_job_for_worker(uuid, integer) from public, anon, authenticated;
grant execute on function public.claim_notice_publication_jobs_for_worker(text, integer) to service_role;
grant execute on function public.run_notice_publication_job_for_worker(uuid, integer) to service_role;

create or replace function app_private.dispatch_notice_publication_worker()
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  worker_url text;
  worker_secret text;
  request_id bigint;
begin
  select decrypted_secret into worker_url
    from vault.decrypted_secrets where name = 'notice_publication_worker_url' limit 1;
  select decrypted_secret into worker_secret
    from vault.decrypted_secrets where name = 'notice_publication_worker_secret' limit 1;
  if nullif(worker_url, '') is null or nullif(worker_secret, '') is null then
    return null;
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-coelo-worker-secret', worker_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  ) into request_id;
  return request_id;
end;
$$;

revoke all on function app_private.dispatch_notice_publication_worker() from public, anon, authenticated;

do $$
declare existing_job bigint;
begin
  for existing_job in select jobid from cron.job where jobname = 'coelo-notice-publication-worker' loop
    perform cron.unschedule(existing_job);
  end loop;
  perform cron.schedule(
    'coelo-notice-publication-worker',
    '* * * * *',
    $cron$select app_private.dispatch_notice_publication_worker();$cron$
  );
end;
$$;
