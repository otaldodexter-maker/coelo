create table app_private.form_file_download_tokens (
  id uuid primary key default gen_random_uuid(),
  file_job_id uuid not null references public.form_file_jobs(id) on delete cascade,
  actor_person_id uuid not null references public.people(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint form_file_download_tokens_hash_ck check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint form_file_download_tokens_expiry_ck check (expires_at > created_at)
);
create index form_file_download_tokens_cleanup_idx
  on app_private.form_file_download_tokens(expires_at, id)
  where consumed_at is null;
alter table app_private.form_file_download_tokens enable row level security;
alter table app_private.form_file_download_tokens force row level security;
revoke all on table app_private.form_file_download_tokens from public, anon, authenticated, service_role;

create or replace function app_private.form_list_file_jobs(p_query jsonb)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.responses.export');
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_created timestamptz := (p_query ->> 'cursor_created_at')::timestamptz;
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  perform app_private.form_assert_payload_keys(p_query,array['form_id','cursor_created_at','cursor_id','limit'],'form file jobs query');
  return (
    with page as (
      select job.* from public.form_file_jobs job
       where job.form_id=(p_query->>'form_id')::uuid and job.requested_by_person_id=actor
         and (cursor_created is null or (job.created_at,job.id)<(cursor_created,cursor_id))
       order by job.created_at desc,job.id desc limit page_limit+1
    ), visible as (select * from page limit page_limit)
    select jsonb_build_object(
      'items',coalesce(jsonb_agg(jsonb_build_object(
        'id',id,'status',state,'progress',progress,
        'download_available',state in ('succeeded','partial') and expires_at>now() and artifact_path is not null,
        'error_code',error_code,'expires_at',expires_at
      ) order by created_at desc,id desc),'[]'::jsonb),
      'has_more',(select count(*)>page_limit from page),
      'next_cursor',(select jsonb_build_object('created_at',created_at,'id',id) from visible order by created_at,id limit 1)
    ) from visible
  );
end;
$$;

create or replace function app_private.form_authorize_file_job_download(p_file_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare actor uuid := app_private.require_forms_actor('forms.responses.export');
declare job_row public.form_file_jobs;
declare raw_token uuid := gen_random_uuid();
declare token_expires_at timestamptz;
begin
  select job.* into job_row
    from public.form_file_jobs job
    join public.forms form_row on form_row.id=job.form_id and form_row.institution_id=job.institution_id
    join public.institutions institution_row on institution_row.id=job.institution_id
   where job.id=p_file_job_id and job.requested_by_person_id=actor
     and job.state in ('succeeded','partial') and job.expires_at>now()
     and job.artifact_path is not null;
  if job_row.id is null then return null; end if;
  token_expires_at:=least(job_row.expires_at,now()+interval '2 minutes');
  delete from app_private.form_file_download_tokens
   where expires_at<=now() or (file_job_id=job_row.id and actor_person_id=actor and consumed_at is null);
  insert into app_private.form_file_download_tokens(file_job_id,actor_person_id,token_hash,expires_at)
  values(job_row.id,actor,encode(digest(raw_token::text,'sha256'),'hex'),token_expires_at);
  return jsonb_build_object('download_token',raw_token,'expires_at',token_expires_at);
end;
$$;

create or replace function app_private.form_redeem_file_job_download(p_download_token uuid)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare result jsonb;
begin
  with consumed as (
    update app_private.form_file_download_tokens token_row
       set consumed_at=now()
     where token_row.token_hash=encode(digest(p_download_token::text,'sha256'),'hex')
       and token_row.consumed_at is null and token_row.expires_at>now()
     returning token_row.file_job_id
  )
  select jsonb_build_object('job_id',job.id,'storage_path',job.artifact_path,
    'export_kind',job.export_kind,'expires_at',job.expires_at)
    into result
    from consumed
    join public.form_file_jobs job on job.id=consumed.file_job_id
    join public.forms form_row on form_row.id=job.form_id and form_row.institution_id=job.institution_id
   where job.state in ('succeeded','partial') and job.expires_at>now() and job.artifact_path is not null;
  return result;
end;
$$;

create or replace function public.form_authorize_file_job_download(p_file_job_id uuid)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.form_authorize_file_job_download($1) $$;
create or replace function public.form_redeem_file_job_download(p_download_token uuid)
returns jsonb language sql volatile security definer set search_path = ''
as $$ select app_private.form_redeem_file_job_download($1) $$;

revoke all on function app_private.form_authorize_file_job_download(uuid) from public,anon,authenticated,service_role;
revoke all on function app_private.form_redeem_file_job_download(uuid) from public,anon,authenticated,service_role;
revoke all on function public.form_authorize_file_job_download(uuid) from public,anon,service_role;
revoke all on function public.form_redeem_file_job_download(uuid) from public,anon,authenticated;
grant execute on function public.form_authorize_file_job_download(uuid) to authenticated;
grant execute on function public.form_redeem_file_job_download(uuid) to service_role;
