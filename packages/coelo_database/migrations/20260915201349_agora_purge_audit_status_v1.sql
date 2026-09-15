-- R14 Bloco E / ADR 0040 / action_id agora.remove.
-- Fecha o recibo agregado do purge depois que o worker confirma cada job.
create or replace function public.record_now_media_purge_result(
  p_job_id bigint,p_success boolean,p_error text default null
)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  job app_private.now_media_purge_jobs%rowtype;
  safe_error text;
  aggregate_status text;
begin
  if auth.role() is distinct from 'service_role' or p_job_id is null then
    raise insufficient_privilege using message='not_authorized';
  end if;
  select * into job from app_private.now_media_purge_jobs where id=p_job_id for update;
  if not found then raise undefined_object using message='purge_job_not_found'; end if;
  safe_error:=nullif(left(btrim(coalesce(p_error,'')),160),'');
  if p_success then
    update app_private.now_media_purge_jobs
    set status='purged',completed_at=now(),locked_at=null,locked_by=null,last_error=null where id=job.id;
  else
    update app_private.now_media_purge_jobs
    set status='error',available_at=now()+interval '1 minute',locked_at=null,locked_by=null,last_error=safe_error
    where id=job.id;
  end if;
  select case
    when count(*) filter(where status<>'purged')=0 then 'purged'
    when count(*) filter(where status='error')>0 then 'retry'
    else 'queued' end
  into aggregate_status
  from app_private.now_media_purge_jobs
  where publication_id=job.publication_id;
  update app_private.now_publication_audit audit
  set detail=audit.detail || jsonb_build_object(
    'purge_status',aggregate_status,
    'purge_results',coalesce(audit.detail->'purge_results','{}'::jsonb) ||
      jsonb_build_object(job.id::text,jsonb_build_object(
        'status',case when p_success then 'purged' else 'error' end,
        'error',safe_error)))
  where audit.publication_id=job.publication_id and audit.event_code='publication_removed'
    and audit.request_id=job.request_id;
  return jsonb_build_object('job_id',job.id,'status',case when p_success then 'purged' else 'error' end);
end $$;

alter function public.record_now_media_purge_result(bigint,boolean,text) owner to postgres;
revoke all on function public.record_now_media_purge_result(bigint,boolean,text)
  from public,anon,authenticated,service_role;
grant execute on function public.record_now_media_purge_result(bigint,boolean,text)
  to service_role;
