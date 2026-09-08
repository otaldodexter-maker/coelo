create or replace function app_private.form_actor_has_export_permission(
  p_actor uuid,
  p_export_kind text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with target_permission as (
    select permission_row.id
      from public.platform_permissions permission_row
     where permission_row.code = case
       when p_export_kind = 'anonymous_participation'
         then 'forms.anonymous_participation.export'
       else 'forms.responses.export'
     end
       and permission_row.status = 'active'
  ), memberships as (
    select membership.id, membership.role_id, role_row.code as role_code
      from public.platform_memberships membership
      join public.platform_roles role_row on role_row.id = membership.role_id
     where membership.person_id = p_actor
       and membership.status = 'active'
       and membership.revoked_at is null
       and membership.scope_kind = 'platform'
       and membership.scope_institution_id is null
       and role_row.status = 'active'
  ), effects as (
    select grant_row.effect
      from memberships
      join public.platform_role_permissions grant_row
        on grant_row.role_id = memberships.role_id
       and grant_row.status = 'active'
       and grant_row.revoked_at is null
      join target_permission on target_permission.id = grant_row.permission_id
    union all
    select override_row.effect
      from memberships
      join public.platform_member_permission_overrides override_row
        on override_row.membership_id = memberships.id
       and override_row.status = 'active'
       and (override_row.starts_at is null or override_row.starts_at <= now())
       and (override_row.expires_at is null or override_row.expires_at > now())
      join target_permission on target_permission.id = override_row.permission_id
  )
  select exists(select 1 from effects where effect = 'allow')
     and not exists(select 1 from effects where effect = 'deny')
     and (
       p_export_kind <> 'anonymous_participation'
       or exists(select 1 from memberships where role_code = 'owner')
     );
$$;

with ranked as (
  select token_row.id,
         row_number() over (
           partition by token_row.file_job_id, token_row.actor_person_id
           order by token_row.created_at desc, token_row.id desc
         ) as position
    from app_private.form_file_download_tokens token_row
   where token_row.consumed_at is null
)
update app_private.form_file_download_tokens token_row
   set consumed_at = now()
  from ranked
 where ranked.id = token_row.id
   and ranked.position > 1;

create unique index form_file_download_tokens_one_active_idx
  on app_private.form_file_download_tokens(file_job_id, actor_person_id)
  where consumed_at is null;

create or replace function app_private.form_list_file_jobs(p_query jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := app_private.current_person_id();
declare page_limit integer := least(greatest(coalesce((p_query ->> 'limit')::integer, 25), 1), 100);
declare cursor_created timestamptz := (p_query ->> 'cursor_created_at')::timestamptz;
declare cursor_id uuid := (p_query ->> 'cursor_id')::uuid;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  perform app_private.form_assert_payload_keys(
    p_query, array['form_id','cursor_created_at','cursor_id','limit'], 'form file jobs query'
  );
  return (
    with page as (
      select job.*
        from public.form_file_jobs job
       where job.form_id = (p_query ->> 'form_id')::uuid
         and job.requested_by_person_id = actor
         and app_private.form_actor_has_export_permission(actor, job.export_kind)
         and (cursor_created is null or (job.created_at, job.id) < (cursor_created, cursor_id))
       order by job.created_at desc, job.id desc
       limit page_limit + 1
    ), visible as (
      select * from page limit page_limit
    )
    select jsonb_build_object(
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'status', state, 'progress', progress,
        'download_available', state in ('succeeded','partial')
          and expires_at > now() and artifact_path is not null,
        'error_code', error_code, 'expires_at', expires_at
      ) order by created_at desc, id desc), '[]'::jsonb),
      'has_more', (select count(*) > page_limit from page),
      'next_cursor', (
        select jsonb_build_object('created_at', created_at, 'id', id)
          from visible order by created_at, id limit 1
      )
    ) from visible
  );
end;
$$;

create or replace function app_private.form_authorize_file_job_download(p_file_job_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor uuid := app_private.current_person_id();
declare job_row public.form_file_jobs;
declare raw_token uuid := gen_random_uuid();
declare token_expires_at timestamptz;
begin
  if actor is null then
    raise insufficient_privilege using message = 'authentication required';
  end if;
  select job.* into job_row
    from public.form_file_jobs job
    join public.forms form_row
      on form_row.id = job.form_id
     and form_row.institution_id = job.institution_id
    join public.institutions institution_row on institution_row.id = job.institution_id
   where job.id = p_file_job_id
     and job.requested_by_person_id = actor
     and job.state in ('succeeded','partial')
     and job.expires_at > now()
     and job.artifact_path is not null
   for update of job;
  if job_row.id is null then return null; end if;
  if not app_private.form_actor_has_export_permission(actor, job_row.export_kind) then
    if job_row.export_kind = 'anonymous_participation' then
      raise insufficient_privilege using
        message = 'Owner role and forms.anonymous_participation.export required';
    end if;
    raise insufficient_privilege using message = 'forms.responses.export required';
  end if;

  token_expires_at := least(job_row.expires_at, now() + interval '2 minutes');
  delete from app_private.form_file_download_tokens token_row
   where token_row.file_job_id = job_row.id
     and token_row.actor_person_id = actor
     and token_row.consumed_at is null;
  insert into app_private.form_file_download_tokens(
    file_job_id, actor_person_id, token_hash, expires_at
  ) values (
    job_row.id, actor, encode(digest(raw_token::text,'sha256'),'hex'), token_expires_at
  );
  return jsonb_build_object('download_token', raw_token, 'expires_at', token_expires_at);
end;
$$;

create or replace function app_private.form_redeem_file_job_download(p_download_token uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  with consumed as (
    update app_private.form_file_download_tokens token_row
       set consumed_at = now()
     where token_row.token_hash = encode(digest(p_download_token::text,'sha256'),'hex')
       and token_row.consumed_at is null
       and token_row.expires_at > now()
     returning token_row.file_job_id, token_row.actor_person_id
  )
  select jsonb_build_object(
    'job_id', job.id,
    'storage_path', job.artifact_path,
    'export_kind', job.export_kind,
    'expires_at', job.expires_at
  )
    into result
    from consumed
    join public.form_file_jobs job
      on job.id = consumed.file_job_id
     and job.requested_by_person_id = consumed.actor_person_id
    join public.forms form_row
      on form_row.id = job.form_id
     and form_row.institution_id = job.institution_id
   where job.state in ('succeeded','partial')
     and job.expires_at > now()
     and job.artifact_path is not null
     and app_private.form_actor_has_export_permission(
       consumed.actor_person_id, job.export_kind
     );
  return result;
end;
$$;

revoke all on function app_private.form_actor_has_export_permission(uuid, text)
  from public, anon, authenticated, service_role;
