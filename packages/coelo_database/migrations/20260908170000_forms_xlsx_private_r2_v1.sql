-- C02 / I005 LOCAL WIP. Requires the two historical export-download migrations
-- (20260820164500 / 20260820164600) and the reviewed I003 media catalog.
-- No production cutover. Preserve the existing job expiry default; final XLSX
-- limits/format/cleanup policy remain a pre-cutover decision in the Forms spec.
begin;
do $$begin
  if to_regclass('app_private.form_file_download_tokens') is null
    or to_regprocedure('app_private.form_actor_has_export_permission(uuid,text)') is null
    or to_regprocedure('app_private.private_media_catalog_key_v1(public.media_assets,text,text,text)') is null
    or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null then
    raise exception 'forms_xlsx_r2_dependencies_missing';
  end if;
end$$;

alter table public.form_file_jobs
  add column artifact_provider text not null default 'supabase_mvp',
  add column artifact_media_asset_id uuid references public.media_assets(id) on delete restrict,
  add column requested_by_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  add column requested_auth_link_id uuid references app_private.superadmin_internal_auth_links(id) on delete restrict,
  add column requested_membership_id uuid references app_private.superadmin_internal_memberships(id) on delete restrict,
  -- A session must be revocable/deletable while a transient job still exists.
  -- Its UUID is immutable provenance, revalidated against auth.sessions on use.
  add column requested_auth_session_id uuid,
  add column requested_scope_kind text,
  add column requested_scope_institution_id uuid references public.institutions(id) on delete restrict,
  add column requested_management_version bigint,
  add column request_payload_sha256 text,
  add column snapshot_format_version integer,
  add column snapshot_row_count bigint,
  add column snapshot_ready boolean not null default false,
  alter column requested_by_person_id drop not null,
  add constraint form_file_jobs_provider_shape_ck check ((
    (artifact_provider='supabase_mvp' and requested_by_person_id is not null
      and artifact_media_asset_id is null and requested_by_internal_identity_id is null
      and requested_auth_link_id is null and requested_membership_id is null
      and requested_auth_session_id is null and requested_scope_kind is null
      and requested_scope_institution_id is null and requested_management_version is null
      and request_payload_sha256 is null and snapshot_format_version is null
      and snapshot_row_count is null and not snapshot_ready)
    or (artifact_provider='r2' and requested_by_person_id is null
      and requested_by_internal_identity_id is not null and requested_auth_link_id is not null
      and requested_membership_id is not null and requested_auth_session_id is not null
      and requested_scope_kind in ('platform','institution')
      and ((requested_scope_kind='platform' and requested_scope_institution_id is null)
        or (requested_scope_kind='institution' and requested_scope_institution_id=institution_id))
      and export_kind='xlsx' and occurrence_id is null and artifact_path is null
      and requested_management_version is not null and requested_management_version>=0
      and request_payload_sha256 is not null and request_payload_sha256 ~ '^[0-9a-f]{64}$'
      and snapshot_format_version=1 and snapshot_row_count is not null and snapshot_row_count>=0
      and (state<>'succeeded' or (snapshot_ready and artifact_media_asset_id is not null
        and artifact_byte_length is not null and artifact_byte_length>0 and completed_at is not null)))
  ) is true);
create unique index form_file_jobs_internal_request_uidx
  on public.form_file_jobs(requested_by_internal_identity_id,request_id) where artifact_provider='r2';
create unique index form_file_jobs_media_asset_uidx
  on public.form_file_jobs(artifact_media_asset_id) where artifact_media_asset_id is not null;
create index form_file_jobs_internal_link_idx on public.form_file_jobs(requested_auth_link_id) where requested_auth_link_id is not null;
create index form_file_jobs_internal_membership_idx on public.form_file_jobs(requested_membership_id) where requested_membership_id is not null;
create index form_file_jobs_requested_scope_idx on public.form_file_jobs(requested_scope_institution_id) where requested_scope_institution_id is not null;

alter table public.media_assets
  add column export_file_job_id uuid references public.form_file_jobs(id) on delete restrict,
  add column expires_at timestamptz,
  drop constraint media_assets_mime_type_check,
  add constraint media_assets_mime_type_check check ((
    (catalog_kind='form-xlsx' and mime_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    or (catalog_kind<>'form-xlsx' and mime_type in ('image/jpeg','image/png','image/webp','video/mp4'))
  ) is true),
  add constraint media_assets_export_binding_shape_ck check ((
    (catalog_kind='form-xlsx' and export_file_job_id is not null and expires_at is not null)
    or (catalog_kind<>'form-xlsx' and export_file_job_id is null and expires_at is null)
  ) is true);
create index media_assets_export_job_fk_idx on public.media_assets(export_file_job_id) where export_file_job_id is not null;
create unique index media_assets_xlsx_active_attempt_uidx on public.media_assets(export_file_job_id)
  where catalog_kind='form-xlsx' and status in ('pending','ready');

-- The image shape below is preserved byte-for-byte from I003, followed by the
-- new XLSX branch. No image limit, owner, nullable-state or legacy rule changes.
alter table public.media_assets drop constraint media_assets_catalog_shape_ck,
  add constraint media_assets_catalog_shape_ck check ((
    (catalog_kind = 'legacy-happens'
      and post_id is not null and owner_person_id is not null and byte_size is not null
      and form_id is null and source_form_asset_id is null
      and owner_internal_identity_id is null and media_purpose is null
      and pixel_width is null and pixel_height is null)
    or
    (catalog_kind = 'form-image'
      and post_id is null and form_id is not null
      and storage_provider = 'r2' and bucket_id = 'coelo-media-prod'
      and original_name = '' and media_purpose is not null
      and mime_type in ('image/jpeg','image/png','image/webp')
      and (byte_size is null or byte_size between 1 and 4194304)
      and (
        (media_purpose = 'question-image' and source_form_asset_id is null
          and num_nonnulls(owner_person_id,owner_internal_identity_id) = 1)
        or (media_purpose = 'answer-image' and source_form_asset_id is not null
          and owner_internal_identity_id is null)
      )
      and (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$')
      and num_nonnulls(pixel_width,pixel_height) in (0,2)
      and ((pixel_width is null and pixel_height is null)
        or (pixel_width between 1 and 2560 and pixel_height between 1 and 2560))
      and (status <> 'ready' or (checksum_sha256 is not null
        and pixel_width is not null and pixel_height is not null
        and byte_size is not null))
      and (status <> 'pending' or (byte_size is null and checksum_sha256 is null
        and pixel_width is null and pixel_height is null))
    )
    or (catalog_kind = 'form-xlsx' and post_id is null and form_id is not null
      and source_form_asset_id is null and owner_person_id is null and owner_internal_identity_id is not null
      and storage_provider = 'r2' and bucket_id = 'coelo-transient-prod' and original_name = ''
      and media_purpose = 'forms-responses-export'
      and mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      and pixel_width is null and pixel_height is null
      and (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$')
      and (status <> 'pending' or (byte_size is null and checksum_sha256 is null))
      and (status <> 'ready' or (byte_size is not null and checksum_sha256 is not null)))
  ) is true);

create or replace function app_private.private_media_catalog_key_v1(
  p_asset public.media_assets,p_rendition text,p_key text,p_mime text
) returns boolean language sql immutable security invoker set search_path='' as $$
  select case when p_asset.catalog_kind='form-xlsx' then
    p_rendition='original'
    and p_mime='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    and p_key='tenants/'||p_asset.institution_id::text||'/exports/forms/'
      ||p_asset.export_file_job_id::text||'/'||p_asset.id::text||'/responses.xlsx'
  else p_key ~ (
    '^tenants/' || p_asset.institution_id::text || '/forms/form/' || p_asset.form_id::text
    || '/' || p_asset.media_purpose || '/' || p_asset.id::text || '/' || p_rendition
    || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    || case p_mime when 'image/jpeg' then '[.]jpg$' when 'image/png' then '[.]png$'
      when 'image/webp' then '[.]webp$' else '$a' end
  ) end;
$$;

create table app_private.form_xlsx_snapshot_rows (
  file_job_id uuid not null references public.form_file_jobs(id) on delete cascade,
  sequence_number bigint not null check(sequence_number>0),
  response_id uuid not null,
  submission_jsonb jsonb not null check(jsonb_typeof(submission_jsonb)='object'),
  primary key(file_job_id,sequence_number),
  unique(file_job_id,response_id)
);
alter table app_private.form_xlsx_snapshot_rows enable row level security;
alter table app_private.form_xlsx_snapshot_rows force row level security;
revoke all on app_private.form_xlsx_snapshot_rows from public,anon,authenticated,service_role;

create function app_private.forms_xlsx_job_guard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and new.artifact_provider is distinct from old.artifact_provider then
    raise check_violation using message='forms_xlsx_job_origin_immutable';
  end if;
  if new.artifact_provider<>'r2' then return new; end if;
  if tg_op='UPDATE' and (
    row(new.id,new.form_id,new.institution_id,new.occurrence_id,new.export_kind,new.request_id,
      new.requested_by_internal_identity_id,new.requested_auth_link_id,new.requested_membership_id,
      new.requested_auth_session_id,new.requested_scope_kind,new.requested_scope_institution_id,
      new.requested_management_version,new.request_payload_sha256,new.snapshot_format_version,new.expires_at)
    is distinct from row(old.id,old.form_id,old.institution_id,old.occurrence_id,old.export_kind,old.request_id,
      old.requested_by_internal_identity_id,old.requested_auth_link_id,old.requested_membership_id,
      old.requested_auth_session_id,old.requested_scope_kind,old.requested_scope_institution_id,
      old.requested_management_version,old.request_payload_sha256,old.snapshot_format_version,old.expires_at)
    or (old.snapshot_ready and (not new.snapshot_ready or new.snapshot_row_count is distinct from old.snapshot_row_count))
    or (old.state='expired' and new.state<>'expired')
    or (old.state='succeeded' and (new.state not in ('succeeded','expired')
      or (new.state='succeeded' and row(new.artifact_media_asset_id,new.artifact_byte_length,new.manifest_jsonb)
        is distinct from row(old.artifact_media_asset_id,old.artifact_byte_length,old.manifest_jsonb))))
  ) then raise check_violation using message='forms_xlsx_job_identity_immutable'; end if;
  if not exists(select 1 from app_private.superadmin_internal_auth_links link
      where link.id=new.requested_auth_link_id and link.internal_identity_id=new.requested_by_internal_identity_id)
    or not exists(select 1 from app_private.superadmin_internal_memberships membership
      where membership.id=new.requested_membership_id and membership.internal_identity_id=new.requested_by_internal_identity_id)
  then raise check_violation using message='forms_xlsx_job_actor_mismatch'; end if;
  return new;
end;
$$;
create trigger forms_xlsx_job_guard_v1 before insert or update on public.form_file_jobs
  for each row execute function app_private.forms_xlsx_job_guard_v1();

create function app_private.forms_xlsx_asset_guard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare job public.form_file_jobs;
begin
  if new.catalog_kind<>'form-xlsx' then return new; end if;
  if tg_op='UPDATE' and old.status in ('quarantined','deleted') and new.status<>old.status
    and not (old.status='quarantined' and new.status='deleted') then
    raise check_violation using message='forms_xlsx_asset_revocation_final';
  end if;
  if tg_op='UPDATE' and row(new.export_file_job_id,new.expires_at,new.upload_request_id)
    is distinct from row(old.export_file_job_id,old.expires_at,old.upload_request_id) then
    raise check_violation using message='forms_xlsx_asset_binding_immutable';
  end if;
  select * into job from public.form_file_jobs where id=new.export_file_job_id for share;
  if job.id is null or job.artifact_provider<>'r2' or job.export_kind<>'xlsx'
    or row(job.form_id,job.institution_id,job.requested_by_internal_identity_id,job.expires_at)
      is distinct from row(new.form_id,new.institution_id,new.owner_internal_identity_id,new.expires_at)
  then raise check_violation using message='forms_xlsx_asset_scope_invalid'; end if;
  return new;
end;
$$;
create trigger forms_xlsx_asset_guard_v1 before insert or update on public.media_assets
  for each row execute function app_private.forms_xlsx_asset_guard_v1();

create function app_private.forms_xlsx_snapshot_guard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare job public.form_file_jobs;
begin
  if tg_op='UPDATE' then raise check_violation using message='forms_xlsx_snapshot_immutable'; end if;
  if tg_op='DELETE' then
    select * into job from public.form_file_jobs where id=old.file_job_id for share;
    if job.id is not null and job.state<>'expired' then
      raise check_violation using message='forms_xlsx_snapshot_immutable';
    end if;
    return old;
  end if;
  select * into job from public.form_file_jobs where id=new.file_job_id for share;
  if job.id is null or job.artifact_provider<>'r2' or job.snapshot_ready or job.state<>'pending'
    or new.submission_jsonb->>'responseId' is distinct from new.response_id::text
    or new.submission_jsonb#>>'{metadata,form_id}' is distinct from job.form_id::text
  then raise check_violation using message='forms_xlsx_snapshot_scope_invalid'; end if;
  return new;
end;
$$;
create trigger forms_xlsx_snapshot_guard_v1 before insert or update or delete on app_private.form_xlsx_snapshot_rows
  for each row execute function app_private.forms_xlsx_snapshot_guard_v1();

create function app_private.forms_xlsx_complete_guard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare job public.form_file_jobs; asset public.media_assets;
begin
  if tg_table_name='media_assets' then
    if new.catalog_kind<>'form-xlsx' then return null; end if;
    select * into asset from public.media_assets where id=new.id;
    select * into job from public.form_file_jobs where id=asset.export_file_job_id;
    if asset.status in ('pending','ready') and job.artifact_media_asset_id is distinct from asset.id then
      raise check_violation using message='forms_xlsx_attempt_not_current';
    end if;
  else select * into job from public.form_file_jobs where id=new.id; end if;
  if job.id is null or job.artifact_provider<>'r2' then return null; end if;
  if job.snapshot_ready and job.state<>'expired' and job.snapshot_row_count<>(
    select count(*) from app_private.form_xlsx_snapshot_rows where file_job_id=job.id
  ) then raise check_violation using message='forms_xlsx_snapshot_count_invalid'; end if;
  if job.artifact_media_asset_id is not null then
    select * into asset from public.media_assets where id=job.artifact_media_asset_id;
    if asset.id is null or asset.catalog_kind<>'form-xlsx'
      or row(asset.export_file_job_id,asset.form_id,asset.institution_id,asset.owner_internal_identity_id,asset.expires_at)
        is distinct from row(job.id,job.form_id,job.institution_id,job.requested_by_internal_identity_id,job.expires_at)
    then raise check_violation using message='forms_xlsx_job_asset_mismatch'; end if;
  end if;
  if job.state='succeeded' and (asset.id is null or asset.status<>'ready'
    or asset.byte_size is distinct from job.artifact_byte_length) then
    raise check_violation using message='forms_xlsx_original_required';
  end if;
  if asset.status='ready' and job.state<>'succeeded' then
    raise check_violation using message='forms_xlsx_job_completion_required';
  end if;
  return null;
end;
$$;
create constraint trigger forms_xlsx_complete_guard_v1 after insert or update on public.form_file_jobs
  deferrable initially deferred for each row execute function app_private.forms_xlsx_complete_guard_v1();
create constraint trigger forms_xlsx_complete_guard_v1 after insert or update on public.media_assets
  deferrable initially deferred for each row execute function app_private.forms_xlsx_complete_guard_v1();

revoke all on function app_private.forms_xlsx_job_guard_v1(),app_private.forms_xlsx_asset_guard_v1(),
  app_private.forms_xlsx_snapshot_guard_v1(),app_private.forms_xlsx_complete_guard_v1()
  from public,anon,authenticated,service_role;
-- Reuse the canonical internal capability checker for a previously authorized
-- server-owned job/token context. Never accept JWT metadata from a worker body.
-- Claims are built from auth.sessions + the immutable link and restored on
-- every exit; this helper has no direct grant, including to service_role.
create function app_private.forms_xlsx_context_from_session_v1(
  p_identity uuid,p_link uuid,p_membership uuid,p_session uuid,p_scope text,p_institution uuid
) returns app_private.superadmin_internal_context
language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; v_auth_user_id uuid; session_aal text;
  original_claims text:=current_setting('request.jwt.claims',true);
  original_sub text:=current_setting('request.jwt.claim.sub',true);
begin
  select session_record.user_id,session_record.aal::text into v_auth_user_id,session_aal
  from auth.sessions session_record
  join app_private.superadmin_internal_auth_links link on link.id=p_link
    and link.auth_user_id=session_record.user_id and link.internal_identity_id=p_identity
  where session_record.id=p_session and (session_record.not_after is null or session_record.not_after>clock_timestamp());
  if v_auth_user_id is null or session_aal is null or session_aal not in ('aal1','aal2') then
    raise insufficient_privilege using detail='SAI_SESSION_INVALID';
  end if;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_auth_user_id,'session_id',p_session,
    'aal',session_aal,'role','authenticated')::text,true);
  perform set_config('request.jwt.claim.sub',v_auth_user_id::text,true);
  select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
  if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
    ctx.scope_kind,ctx.scope_institution_id) is distinct from row(p_identity,p_link,p_membership,p_session,p_scope,p_institution)
    or ctx.scope_kind not in ('platform','institution')
    or (ctx.scope_kind='institution' and ctx.scope_institution_id is null)
    or not exists(select 1 from auth.sessions s where s.id=p_session and s.user_id=v_auth_user_id
      and (s.not_after is null or s.not_after>clock_timestamp())) then
    raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
  end if;
  perform set_config('request.jwt.claims',coalesce(original_claims,''),true);
  perform set_config('request.jwt.claim.sub',coalesce(original_sub,''),true);
  return ctx;
exception when others then
  perform set_config('request.jwt.claims',coalesce(original_claims,''),true);
  perform set_config('request.jwt.claim.sub',coalesce(original_sub,''),true);
  raise;
end;
$$;

alter table app_private.form_file_download_tokens
  alter column actor_person_id drop not null,
  add column actor_internal_identity_id uuid references app_private.superadmin_internal_identities(id) on delete restrict,
  add column actor_auth_link_id uuid references app_private.superadmin_internal_auth_links(id) on delete restrict,
  add column actor_membership_id uuid references app_private.superadmin_internal_memberships(id) on delete restrict,
  add column actor_auth_session_id uuid,
  add column actor_scope_kind text,
  add column actor_scope_institution_id uuid references public.institutions(id) on delete restrict,
  add column actor_aal text,
  add column media_asset_id uuid references public.media_assets(id) on delete restrict,
  add constraint form_file_download_tokens_actor_realm_ck check ((
    (actor_person_id is not null and actor_internal_identity_id is null and actor_auth_link_id is null
      and actor_membership_id is null and actor_auth_session_id is null and actor_scope_kind is null
      and actor_scope_institution_id is null and actor_aal is null and media_asset_id is null)
    or (actor_person_id is null and actor_internal_identity_id is not null and actor_auth_link_id is not null
      and actor_membership_id is not null and actor_auth_session_id is not null and media_asset_id is not null
      and actor_aal in ('aal1','aal2') and actor_scope_kind in ('platform','institution')
      and ((actor_scope_kind='platform' and actor_scope_institution_id is null)
        or (actor_scope_kind='institution' and actor_scope_institution_id is not null)))
  ) is true);
create unique index form_file_download_tokens_internal_active_uidx
  on app_private.form_file_download_tokens(file_job_id,actor_internal_identity_id)
  where consumed_at is null and actor_internal_identity_id is not null;
create index form_file_download_tokens_internal_actor_idx on app_private.form_file_download_tokens(actor_internal_identity_id) where actor_internal_identity_id is not null;
create index form_file_download_tokens_auth_link_idx on app_private.form_file_download_tokens(actor_auth_link_id) where actor_auth_link_id is not null;
create index form_file_download_tokens_membership_idx on app_private.form_file_download_tokens(actor_membership_id) where actor_membership_id is not null;
create index form_file_download_tokens_scope_idx on app_private.form_file_download_tokens(actor_scope_institution_id) where actor_scope_institution_id is not null;
create index form_file_download_tokens_asset_idx on app_private.form_file_download_tokens(media_asset_id) where media_asset_id is not null;

create function app_private.forms_xlsx_token_guard_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare job public.form_file_jobs;
begin
  if tg_op='UPDATE' and (old.actor_internal_identity_id is not null or new.actor_internal_identity_id is not null) then
    if row(new.id,new.file_job_id,new.actor_person_id,new.actor_internal_identity_id,new.actor_auth_link_id,
      new.actor_membership_id,new.actor_auth_session_id,new.actor_scope_kind,new.actor_scope_institution_id,
      new.actor_aal,new.media_asset_id,new.token_hash,new.expires_at,new.created_at)
      is distinct from row(old.id,old.file_job_id,old.actor_person_id,old.actor_internal_identity_id,old.actor_auth_link_id,
      old.actor_membership_id,old.actor_auth_session_id,old.actor_scope_kind,old.actor_scope_institution_id,
      old.actor_aal,old.media_asset_id,old.token_hash,old.expires_at,old.created_at)
      or (old.consumed_at is not null and new.consumed_at is distinct from old.consumed_at) then
      raise check_violation using message='forms_xlsx_token_immutable';
    end if;
    return new;
  end if;
  if new.actor_internal_identity_id is null then return new; end if;
  select * into job from public.form_file_jobs where id=new.file_job_id for share;
  if job.id is null or job.artifact_provider<>'r2' or job.state<>'succeeded'
    or job.artifact_media_asset_id is distinct from new.media_asset_id
    or job.requested_by_internal_identity_id is distinct from new.actor_internal_identity_id
    or new.expires_at>job.expires_at
    or (new.actor_scope_kind='institution' and new.actor_scope_institution_id is distinct from job.institution_id)
    or not exists(select 1 from app_private.superadmin_internal_auth_links link
      where link.id=new.actor_auth_link_id and link.internal_identity_id=new.actor_internal_identity_id)
    or not exists(select 1 from app_private.superadmin_internal_memberships membership
      where membership.id=new.actor_membership_id and membership.internal_identity_id=new.actor_internal_identity_id)
  then raise check_violation using message='forms_xlsx_token_scope_invalid'; end if;
  return new;
end;
$$;
create trigger forms_xlsx_token_guard_v1 before insert or update on app_private.form_file_download_tokens
  for each row execute function app_private.forms_xlsx_token_guard_v1();

create function app_private.superadmin_form_authorize_xlsx_download_v2(p_file_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
  job public.form_file_jobs; asset public.media_assets; raw_token uuid:=gen_random_uuid();
  token_expiry timestamptz; error_code text; correlation uuid:=gen_random_uuid();
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    initial_ctx:=ctx;
    if current_setting('transaction_isolation')<>'read committed' or p_file_job_id is null then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if ctx.aal is null or ctx.aal not in ('aal1','aal2')
      or ctx.scope_kind not in ('platform','institution') or ctx.scope_kind is null
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    select j.* into job from public.form_file_jobs j join public.forms f on f.id=j.form_id and f.institution_id=j.institution_id
      join public.institutions i on i.id=j.institution_id and i.deleted_at is null
      where j.id=p_file_job_id and j.artifact_provider='r2' and j.export_kind='xlsx'
        and j.requested_by_internal_identity_id=ctx.internal_identity_id
        and (ctx.scope_kind='platform' or j.institution_id=ctx.scope_institution_id)
        and j.state='succeeded' and j.expires_at>clock_timestamp() for update of j;
    if job.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    select * into asset from public.media_assets where id=job.artifact_media_asset_id
      and catalog_kind='form-xlsx' and status='ready' and export_file_job_id=job.id
      and institution_id=job.institution_id and expires_at=job.expires_at for share;
    if asset.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id)
      is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
        initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or not exists(select 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id
        and (s.not_after is null or s.not_after>clock_timestamp())) or job.expires_at<=clock_timestamp() then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    token_expiry:=least(job.expires_at,clock_timestamp()+interval '2 minutes');
    update app_private.form_file_download_tokens set consumed_at=clock_timestamp()
      where file_job_id=job.id and actor_internal_identity_id=ctx.internal_identity_id and consumed_at is null;
    insert into app_private.form_file_download_tokens(file_job_id,actor_internal_identity_id,actor_auth_link_id,
      actor_membership_id,actor_auth_session_id,actor_scope_kind,actor_scope_institution_id,actor_aal,media_asset_id,token_hash,expires_at)
    values(job.id,ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,
      ctx.scope_kind,ctx.scope_institution_id,ctx.aal,asset.id,
      encode(extensions.digest(convert_to(raw_token::text,'UTF8'),'sha256'),'hex'),token_expiry);
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.session_id,'forms.responses.export',ctx.aal,'superadmin.forms.export.download.authorize','success',null,
      correlation,job.institution_id,'form_file_job',job.id);
  exception when others then
    get stacked diagnostics error_code=pg_exception_detail;
    error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.responses.export',
      'superadmin.forms.export.download.authorize',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  return jsonb_build_object('ok',true,'error',null,'data',jsonb_build_object('job_id',job.id,'download_token',raw_token,'expires_at',token_expiry));
end;
$$;

create function app_private.form_redeem_xlsx_download_r2_v1(p_download_token uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare token_row app_private.form_file_download_tokens; job public.form_file_jobs; asset public.media_assets;
  ctx app_private.superadmin_internal_context; target_job uuid; token_digest text;
  error_code text; correlation uuid:=gen_random_uuid();
begin
  if current_setting('transaction_isolation')<>'read committed' then
    raise invalid_parameter_value using message='forms_xlsx_isolation_invalid';
  end if;
  token_digest:=encode(extensions.digest(convert_to(p_download_token::text,'UTF8'),'sha256'),'hex');
  select file_job_id into target_job from app_private.form_file_download_tokens
    where token_hash=token_digest and actor_internal_identity_id is not null and consumed_at is null;
  if target_job is null then return null; end if;
  -- Same lock order as issue: job before token. A consumed/denied ticket is
  -- committed as consumed even if the actor lost permission after issue.
  select * into job from public.form_file_jobs where id=target_job for update;
  update app_private.form_file_download_tokens set consumed_at=clock_timestamp()
    where token_hash=token_digest and file_job_id=job.id and consumed_at is null
      and actor_internal_identity_id is not null and expires_at>clock_timestamp()
    returning * into token_row;
  if token_row.id is null then return null; end if;
  begin
    ctx:=app_private.forms_xlsx_context_from_session_v1(token_row.actor_internal_identity_id,token_row.actor_auth_link_id,
      token_row.actor_membership_id,token_row.actor_auth_session_id,token_row.actor_scope_kind,token_row.actor_scope_institution_id);
    select * into asset from public.media_assets where id=token_row.media_asset_id for share;
    if job.artifact_provider<>'r2' or job.export_kind<>'xlsx' or job.state<>'succeeded'
      or job.expires_at<=clock_timestamp() or token_row.expires_at<=clock_timestamp()
      or job.requested_by_internal_identity_id is distinct from ctx.internal_identity_id
      or (ctx.scope_kind='institution' and job.institution_id is distinct from ctx.scope_institution_id)
      or job.artifact_media_asset_id is distinct from asset.id or asset.status is distinct from 'ready'
      or asset.catalog_kind is distinct from 'form-xlsx'
      or row(asset.export_file_job_id,asset.form_id,asset.institution_id,asset.expires_at)
        is distinct from row(job.id,job.form_id,job.institution_id,job.expires_at)
      or not exists(select 1 from public.forms f join public.institutions i on i.id=f.institution_id
        where f.id=job.form_id and f.institution_id=job.institution_id and i.deleted_at is null)
    then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    -- Locks above may wait; refresh the actor again before emitting metadata.
    ctx:=app_private.forms_xlsx_context_from_session_v1(token_row.actor_internal_identity_id,token_row.actor_auth_link_id,
      token_row.actor_membership_id,token_row.actor_auth_session_id,token_row.actor_scope_kind,token_row.actor_scope_institution_id);
    if job.expires_at<=clock_timestamp() or token_row.expires_at<=clock_timestamp() then
      raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
    end if;
  exception when insufficient_privilege then
    get stacked diagnostics error_code=pg_exception_detail;
    error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  perform app_private.audit_append_superadmin_internal(token_row.actor_internal_identity_id,token_row.actor_auth_link_id,
    token_row.actor_membership_id,token_row.actor_auth_session_id,'forms.responses.export',token_row.actor_aal,
    'superadmin.forms.export.download.redeem',case when error_code is null then 'success'::public.audit_outcome else 'denied'::public.audit_outcome end,
    error_code,correlation,job.institution_id,'form_file_job',job.id);
  if error_code is not null then return null; end if;
  return jsonb_build_object('job_id',job.id,'institution_id',job.institution_id,'asset_id',asset.id,
    'provider','r2','bucket',asset.bucket_id,'export_kind','xlsx','purpose',asset.media_purpose,
    'state',asset.status,'object_key',asset.object_key,'expires_at',least(job.expires_at,token_row.expires_at));
end;
$$;
create function public.superadmin_form_authorize_xlsx_download_v2(p_file_job_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_form_authorize_xlsx_download_v2($1);
$$;
create function public.form_redeem_xlsx_download_r2_v1(p_download_token uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_redeem_xlsx_download_r2_v1($1);
$$;
revoke all on function app_private.forms_xlsx_context_from_session_v1(uuid,uuid,uuid,uuid,text,uuid),
  app_private.forms_xlsx_token_guard_v1(),app_private.superadmin_form_authorize_xlsx_download_v2(uuid),
  app_private.form_redeem_xlsx_download_r2_v1(uuid) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_form_authorize_xlsx_download_v2(uuid) from public,anon,service_role;
revoke all on function public.form_redeem_xlsx_download_r2_v1(uuid) from public,anon,authenticated;
grant execute on function public.superadmin_form_authorize_xlsx_download_v2(uuid) to authenticated;
grant execute on function public.form_redeem_xlsx_download_r2_v1(uuid) to service_role;

-- A distinct queue kind prevents a legacy Storage worker from claiming R2 work.
alter table app_private.form_worker_jobs drop constraint form_worker_jobs_kind_ck;
alter table app_private.form_worker_jobs add constraint form_worker_jobs_kind_ck check (job_kind in (
  'generate_occurrences','reconcile_audience','materialize_metrics','enqueue_reminders',
  'export_csv','export_xlsx','export_zip','export_anonymous_participation',
  'finalize_asset','cleanup_uploads','cleanup_artifacts','export_xlsx_r2_v1'
));
create function app_private.superadmin_form_request_xlsx_v2(
  p_request_id uuid,p_expected_version bigint,p_payload jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare ctx app_private.superadmin_internal_context; initial_ctx app_private.superadmin_internal_context;
  form_row public.forms; job public.form_file_jobs; target_form uuid; payload_hash text;
  captured_count bigint; error_code text; correlation uuid:=gen_random_uuid();
begin
  begin
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    initial_ctx:=ctx;
    if current_setting('transaction_isolation')<>'read committed' or p_request_id is null
      or p_expected_version is null or p_expected_version<0
      or jsonb_typeof(p_payload) is distinct from 'object' then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if jsonb_typeof(p_payload->'form_id') is distinct from 'string'
      or not (p_payload->>'form_id' ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      or exists(select 1 from jsonb_object_keys(p_payload) k where k<>'form_id') then
      raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
    end if;
    if ctx.aal is null or ctx.aal not in ('aal1','aal2') or ctx.scope_kind is null
      or ctx.scope_kind not in ('platform','institution')
      or (ctx.scope_kind='institution' and ctx.scope_institution_id is null) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    target_form:=(p_payload->>'form_id')::uuid;
    payload_hash:=encode(extensions.digest(convert_to(jsonb_build_object('form_id',target_form,
      'expected_version',p_expected_version)::text,'UTF8'),'sha256'),'hex');
    perform pg_advisory_xact_lock(hashtextextended(ctx.internal_identity_id::text||':'||p_request_id::text,0));
    select f.* into form_row from public.forms f join public.institutions i on i.id=f.institution_id
      where f.id=target_form and i.deleted_at is null
        and (ctx.scope_kind='platform' or f.institution_id=ctx.scope_institution_id) for share of f,i;
    if form_row.id is null then raise insufficient_privilege using detail='SAI_PERMISSION_DENIED'; end if;
    select * into job from public.form_file_jobs where requested_by_internal_identity_id=ctx.internal_identity_id
      and request_id=p_request_id for update;
    if job.id is not null then
      if job.request_payload_sha256 is distinct from payload_hash or job.form_id is distinct from form_row.id
        or job.institution_id is distinct from form_row.institution_id then
        raise invalid_parameter_value using detail='SAI_INVALID_ARGUMENT';
      end if;
    else
      if form_row.management_version<>p_expected_version then
        raise serialization_failure using detail='SAI_CONCURRENT_CHANGE';
      end if;
      insert into public.form_file_jobs(form_id,institution_id,request_id,export_kind,artifact_provider,
        requested_by_internal_identity_id,requested_auth_link_id,requested_membership_id,requested_auth_session_id,
        requested_scope_kind,requested_scope_institution_id,requested_management_version,request_payload_sha256,
        snapshot_format_version,snapshot_row_count,snapshot_ready)
      values(form_row.id,form_row.institution_id,p_request_id,'xlsx','r2',ctx.internal_identity_id,
        ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id,
        p_expected_version,payload_hash,1,0,false) returning * into job;
      -- One statement snapshot for response, answer, option labels and identity.
      -- Version 1 preserves the existing writer projection; no binaries or
      -- storage credentials/paths are captured, including anonymous responses.
      insert into app_private.form_xlsx_snapshot_rows(file_job_id,sequence_number,response_id,submission_jsonb)
      select job.id,row_number() over(order by response.id),response.id,
             jsonb_build_object(
               'responseId', response.id,
               'occurrenceId', response.occurrence_id,
               'versionId', response.form_version_id,
               'metadata', jsonb_build_object(
                 'form_id', response.form_id,
                 'identity_mode', response.identity_mode,
                 'respondent', case when response.identity_mode = 'identified'
                   then person_row.display_name else '' end,
                 'submitted_at', case when response.identity_mode = 'identified'
                   then response.submitted_at::text else '' end
               ),
               'answers', coalesce((
                 select jsonb_agg(jsonb_build_object(
                   'itemId', item.id,
                   'question', item.label,
                   'multiValued', item.kind in ('multiple_choice', 'photo', 'gallery'),
                   'values', case
                     when item.kind in ('single_choice', 'multiple_choice') then coalesce((
                       select jsonb_agg(option_row.label order by answer_option.position, option_row.position)
                         from public.form_answer_options answer_option
                         join public.form_question_options option_row on option_row.id = answer_option.option_id
                        where answer_option.answer_id = answer.id and option_row.item_id = item.id
                     ), '[]'::jsonb)
                     when item.kind in ('photo', 'gallery') then coalesce((
                       select jsonb_agg('/forms/media/' || asset.id::text order by answer_asset.position)
                         from public.form_answer_assets answer_asset
                         join public.form_assets asset on asset.id = answer_asset.asset_id
                        where answer_asset.answer_id = answer.id and asset.state = 'finalized'
                          and asset.institution_id = response.institution_id
                          and asset.occurrence_id = response.occurrence_id and asset.item_id = item.id
                     ), '[]'::jsonb)
                     else jsonb_build_array(case answer.answer_kind
                       when 'short_text' then answer.text_value
                       when 'integer' then answer.integer_value::text
                       when 'decimal' then answer.decimal_value::text
                       when 'money' then answer.money_minor_units::text
                       when 'date' then answer.date_value::text
                       when 'yes_no' then case when answer.yes_no_value then 'Sim' else 'Não' end
                       when 'scale' then answer.scale_value::text
                       else '' end)
                   end
                 ) order by section.position, item.position, item.id)
                   from public.form_answers answer
                   join public.form_items item on item.id = answer.item_id
                   join public.form_sections section on section.id = item.section_id
                  where answer.response_id = response.id and answer.form_version_id = response.form_version_id
                    and item.form_version_id = response.form_version_id and section.form_version_id = response.form_version_id
               ), '[]'::jsonb)
             )
      from public.form_responses response
      join public.form_occurrences occurrence on occurrence.id=response.occurrence_id
        and occurrence.form_id=response.form_id and occurrence.institution_id=response.institution_id
        and occurrence.form_version_id=response.form_version_id
      join public.form_versions version on version.id=response.form_version_id and version.form_id=response.form_id
      left join public.people person_row on person_row.id=response.respondent_person_id
      where response.form_id=form_row.id and response.institution_id=form_row.institution_id and response.status='submitted';
      get diagnostics captured_count=row_count;
      update public.form_file_jobs set snapshot_ready=true,snapshot_row_count=captured_count
        where id=job.id returning * into job;
      insert into app_private.form_worker_jobs(job_kind,aggregate_id,payload_jsonb)
        values('export_xlsx_r2_v1',job.id,jsonb_build_object('file_job_id',job.id));
    end if;
    -- Any wait or capture may span a revocation. Refresh before committing work.
    select * into strict ctx from app_private.require_superadmin_internal_context('forms.responses.export');
    if row(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,ctx.session_id,ctx.scope_kind,ctx.scope_institution_id)
      is distinct from row(initial_ctx.internal_identity_id,initial_ctx.internal_auth_link_id,initial_ctx.internal_membership_id,
        initial_ctx.session_id,initial_ctx.scope_kind,initial_ctx.scope_institution_id)
      or not exists(select 1 from auth.sessions s where s.id=ctx.session_id and s.user_id=ctx.auth_user_id
        and (s.not_after is null or s.not_after>clock_timestamp())) then
      raise insufficient_privilege using detail='SAI_INTERNAL_CONTEXT_DENIED';
    end if;
    perform app_private.audit_append_superadmin_internal(ctx.internal_identity_id,ctx.internal_auth_link_id,ctx.internal_membership_id,
      ctx.session_id,'forms.responses.export',ctx.aal,'superadmin.forms.export.request','success',null,
      correlation,job.institution_id,'form_file_job',job.id);
  exception when others then
    get stacked diagnostics error_code=pg_exception_detail;
    error_code:=app_private.superadmin_internal_error_envelope(error_code,correlation)#>>'{error,code}';
  end;
  if error_code is not null then
    perform app_private.audit_superadmin_internal_denial_if_identified('forms.responses.export',
      'superadmin.forms.export.request',error_code,correlation);
    return app_private.superadmin_internal_error_envelope(error_code,correlation);
  end if;
  return jsonb_build_object('ok',true,'error',null,'data',jsonb_build_object('id',job.id,'status',job.state,
    'progress',job.progress,'download_path',null,'error_code',job.error_code,'expires_at',job.expires_at,
    'download_available',job.state='succeeded' and job.expires_at>clock_timestamp()));
end;
$$;
create function public.superadmin_form_request_xlsx_v2(p_request_id uuid,p_expected_version bigint,p_payload jsonb)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.superadmin_form_request_xlsx_v2($1,$2,$3);
$$;
revoke all on function app_private.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb) from public,anon,service_role;
grant execute on function public.superadmin_form_request_xlsx_v2(uuid,bigint,jsonb) to authenticated;

-- Service-only operations reuse the existing queue, lease and attempt count.
create function app_private.forms_xlsx_worker_job_v1(
  p_job_id uuid,p_worker_id text,p_file_job_id uuid,p_asset_id uuid default null
) returns public.form_file_jobs language plpgsql volatile security definer set search_path='' as $$
declare v_worker app_private.form_worker_jobs; v_job public.form_file_jobs;
  v_ctx app_private.superadmin_internal_context;
begin
  if current_setting('transaction_isolation')<>'read committed' or p_job_id is null or p_file_job_id is null
    or p_worker_id is null or length(p_worker_id) not between 1 and 240 then
    raise invalid_parameter_value using message='forms_xlsx_worker_input_invalid';
  end if;
  select * into v_worker from app_private.form_worker_jobs where id=p_job_id
    and aggregate_id=p_file_job_id and job_kind='export_xlsx_r2_v1'
    and state='processing' and lease_owner=p_worker_id and lease_expires_at>clock_timestamp() for update;
  if v_worker.id is null then raise serialization_failure using message='forms_xlsx_lease_unavailable'; end if;
  select j.* into v_job from public.form_file_jobs j join public.forms f on f.id=j.form_id and f.institution_id=j.institution_id
    join public.institutions i on i.id=j.institution_id and i.deleted_at is null
    where j.id=p_file_job_id and j.artifact_provider='r2' and j.export_kind='xlsx' and j.snapshot_ready
      and j.state in ('pending','processing','failed') and j.expires_at>clock_timestamp() for update of j;
  if v_job.id is null then raise no_data_found using message='forms_xlsx_job_unavailable'; end if;
  v_ctx:=app_private.forms_xlsx_context_from_session_v1(v_job.requested_by_internal_identity_id,v_job.requested_auth_link_id,
    v_job.requested_membership_id,v_job.requested_auth_session_id,v_job.requested_scope_kind,v_job.requested_scope_institution_id);
  if v_ctx.scope_kind='institution' and v_ctx.scope_institution_id is distinct from v_job.institution_id then
    raise insufficient_privilege using detail='SAI_PERMISSION_DENIED';
  end if;
  if p_asset_id is not null and (v_job.artifact_media_asset_id is distinct from p_asset_id
    or not exists(select 1 from public.media_assets a where a.id=p_asset_id and a.export_file_job_id=v_job.id
      and a.status='pending' and a.catalog_kind='form-xlsx'
      and a.upload_request_id='xlsx:'||v_worker.id::text||':'||v_worker.attempts::text)) then
    raise serialization_failure using message='forms_xlsx_attempt_unavailable';
  end if;
  if v_worker.lease_expires_at<=clock_timestamp() or v_job.expires_at<=clock_timestamp() then
    raise serialization_failure using message='forms_xlsx_lease_unavailable';
  end if;
  return v_job;
end;
$$;
create function app_private.form_worker_begin_xlsx_r2_v1(p_job_id uuid,p_worker_id text,p_file_job_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_worker app_private.form_worker_jobs; v_asset public.media_assets;
  v_attempt_key text; v_new_asset uuid:=gen_random_uuid(); v_ctx app_private.superadmin_internal_context;
begin
  v_job:=app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id);
  select * into strict v_worker from app_private.form_worker_jobs where id=p_job_id;
  v_attempt_key:='xlsx:'||v_worker.id::text||':'||v_worker.attempts::text;
  select * into v_asset from public.media_assets where id=v_job.artifact_media_asset_id for update;
  if v_asset.id is null or v_asset.status<>'pending' or v_asset.upload_request_id<>v_attempt_key then
    -- A stale worker may still finish network I/O. Preserve its unique locator
    -- for reconciliation/cleanup, and never reuse that key for the next lease.
    if v_asset.id is not null and v_asset.status='pending' then
      update public.media_assets set status='quarantined' where id=v_asset.id;
    end if;
    insert into public.media_assets(id,institution_id,form_id,owner_internal_identity_id,upload_request_id,
      catalog_kind,media_purpose,export_file_job_id,storage_provider,bucket_id,original_name,mime_type,expires_at,object_key)
    values(v_new_asset,v_job.institution_id,v_job.form_id,v_job.requested_by_internal_identity_id,v_attempt_key,
      'form-xlsx','forms-responses-export',v_job.id,'r2','coelo-transient-prod','',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',v_job.expires_at,
      'tenants/'||v_job.institution_id::text||'/exports/forms/'||v_job.id::text||'/'||v_new_asset::text||'/responses.xlsx')
    returning * into v_asset;
    update public.form_file_jobs set artifact_media_asset_id=v_asset.id,state='processing',
      started_at=coalesce(started_at,clock_timestamp()),progress=greatest(progress,0.05),error_code=null
      where id=v_job.id;
  end if;
  v_job:=app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,v_asset.id);
  v_ctx:=app_private.forms_xlsx_context_from_session_v1(v_job.requested_by_internal_identity_id,v_job.requested_auth_link_id,
    v_job.requested_membership_id,v_job.requested_auth_session_id,v_job.requested_scope_kind,v_job.requested_scope_institution_id);
  perform app_private.audit_append_superadmin_internal(v_ctx.internal_identity_id,v_ctx.internal_auth_link_id,
    v_ctx.internal_membership_id,v_ctx.session_id,'forms.responses.export',v_ctx.aal,
    'superadmin.forms.export.begin','success',null,gen_random_uuid(),v_job.institution_id,'form_file_job',v_job.id);
  perform app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,v_asset.id);
  return jsonb_build_object('job_id',v_job.id,'worker_job_id',v_worker.id,'attempt',v_worker.attempts,
    'asset_id',v_asset.id,'institution_id',v_job.institution_id,'provider','r2','bucket',v_asset.bucket_id,
    'object_key',v_asset.object_key,'mime_type',v_asset.mime_type,'expires_at',v_job.expires_at,
    'snapshot_format_version',v_job.snapshot_format_version,'snapshot_row_count',v_job.snapshot_row_count);
end;
$$;
create function app_private.form_worker_xlsx_snapshot_r2_v1(
  p_job_id uuid,p_worker_id text,p_file_job_id uuid,p_asset_id uuid,
  p_after_sequence bigint default 0,p_limit integer default 250
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_result jsonb;
begin
  if p_asset_id is null or p_after_sequence is null or p_after_sequence<0 or p_limit is null or p_limit not between 1 and 500 then
    raise invalid_parameter_value using message='forms_xlsx_page_invalid';
  end if;
  v_job:=app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  if p_after_sequence>v_job.snapshot_row_count then raise invalid_parameter_value using message='forms_xlsx_cursor_invalid'; end if;
  select jsonb_build_object('kind','xlsx','snapshot_format_version',v_job.snapshot_format_version,
    'submissions',coalesce(jsonb_agg(s.submission_jsonb order by s.sequence_number),'[]'::jsonb),
    'has_more',coalesce(max(s.sequence_number),p_after_sequence)<v_job.snapshot_row_count,
    'next_cursor',case when max(s.sequence_number) is not null then max(s.sequence_number)::text else null end)
    into v_result from (select sequence_number,submission_jsonb from app_private.form_xlsx_snapshot_rows
      where file_job_id=v_job.id and sequence_number>p_after_sequence order by sequence_number limit p_limit) s;
  perform app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  return v_result;
end;
$$;
create function public.form_worker_begin_xlsx_r2_v1(p_job_id uuid,p_worker_id text,p_file_job_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_worker_begin_xlsx_r2_v1($1,$2,$3);
$$;
create function public.form_worker_xlsx_snapshot_r2_v1(p_job_id uuid,p_worker_id text,p_file_job_id uuid,p_asset_id uuid,
  p_after_sequence bigint default 0,p_limit integer default 250)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_worker_xlsx_snapshot_r2_v1($1,$2,$3,$4,$5,$6);
$$;
revoke all on function app_private.forms_xlsx_worker_job_v1(uuid,text,uuid,uuid),
  app_private.form_worker_begin_xlsx_r2_v1(uuid,text,uuid),
  app_private.form_worker_xlsx_snapshot_r2_v1(uuid,text,uuid,uuid,bigint,integer) from public,anon,authenticated,service_role;
revoke all on function public.form_worker_begin_xlsx_r2_v1(uuid,text,uuid),
  public.form_worker_xlsx_snapshot_r2_v1(uuid,text,uuid,uuid,bigint,integer) from public,anon,authenticated;
grant execute on function public.form_worker_begin_xlsx_r2_v1(uuid,text,uuid),
  public.form_worker_xlsx_snapshot_r2_v1(uuid,text,uuid,uuid,bigint,integer) to service_role;
create function app_private.form_worker_complete_xlsx_r2_v1(
  p_job_id uuid,p_worker_id text,p_file_job_id uuid,p_asset_id uuid,
  p_actual_byte_length bigint,p_actual_checksum_sha256 text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_worker app_private.form_worker_jobs;
  v_ctx app_private.superadmin_internal_context;
begin
  if p_asset_id is null or p_actual_byte_length is null or p_actual_byte_length<1
    or p_actual_checksum_sha256 is null or p_actual_checksum_sha256!~'^[0-9a-f]{64}$' then
    raise invalid_parameter_value using message='forms_xlsx_measurement_invalid';
  end if;
  v_job:=app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  select * into strict v_worker from app_private.form_worker_jobs where id=p_job_id;
  perform 1 from public.media_assets where id=p_asset_id for update;
  perform app_private.forms_xlsx_worker_job_v1(p_job_id,p_worker_id,p_file_job_id,p_asset_id);
  -- Measurements come only from the service generating and writing the XLSX.
  -- No client grant and no caller-supplied path, MIME, tenant or manifest.
  update public.media_assets set status='ready',byte_size=p_actual_byte_length,
    checksum_sha256=p_actual_checksum_sha256,finalized_at=clock_timestamp() where id=p_asset_id;
  update public.form_file_jobs set state='succeeded',progress=1,artifact_byte_length=p_actual_byte_length,
    completed_at=clock_timestamp(),error_code=null,
    manifest_jsonb=jsonb_build_object('format_version',snapshot_format_version,'response_count',snapshot_row_count)
    where id=v_job.id;
  update app_private.form_worker_jobs set state='succeeded',completed_at=clock_timestamp(),
    lease_owner=null,lease_expires_at=null,progress_jsonb=jsonb_build_object('completed',true)
    where id=p_job_id;
  v_ctx:=app_private.forms_xlsx_context_from_session_v1(v_job.requested_by_internal_identity_id,v_job.requested_auth_link_id,
    v_job.requested_membership_id,v_job.requested_auth_session_id,v_job.requested_scope_kind,v_job.requested_scope_institution_id);
  perform app_private.audit_append_superadmin_internal(v_ctx.internal_identity_id,v_ctx.internal_auth_link_id,
    v_ctx.internal_membership_id,v_ctx.session_id,'forms.responses.export',v_ctx.aal,
    'superadmin.forms.export.complete','success',null,gen_random_uuid(),v_job.institution_id,'form_file_job',v_job.id);
  if v_worker.lease_expires_at<=clock_timestamp() or v_job.expires_at<=clock_timestamp() then
    raise serialization_failure using message='forms_xlsx_lease_unavailable';
  end if;
  return jsonb_build_object('job_id',v_job.id,'asset_id',p_asset_id,'state','succeeded',
    'byte_length',p_actual_byte_length,'checksum_sha256',p_actual_checksum_sha256,'expires_at',v_job.expires_at);
end;
$$;
-- Reconciliation reports persisted outcome to the service even if the requester
-- has since logged out. It grants neither a read ticket nor permission to delete.
create function app_private.form_worker_reconcile_xlsx_r2_v1(p_job_id uuid,p_file_job_id uuid,p_asset_id uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_asset public.media_assets; v_state text:='unavailable';
begin
  if current_setting('transaction_isolation')<>'read committed' or p_job_id is null or p_file_job_id is null or p_asset_id is null then
    raise invalid_parameter_value using message='forms_xlsx_worker_input_invalid';
  end if;
  if not exists(select 1 from app_private.form_worker_jobs where id=p_job_id
    and aggregate_id=p_file_job_id and job_kind='export_xlsx_r2_v1') then
    return jsonb_build_object('state','unavailable');
  end if;
  select * into v_job from public.form_file_jobs where id=p_file_job_id and artifact_provider='r2' for update;
  select * into v_asset from public.media_assets where id=p_asset_id and export_file_job_id=p_file_job_id
    and catalog_kind='form-xlsx' for share;
  if v_job.id is not null and v_asset.id is not null then
    if v_job.state='succeeded' and v_job.artifact_media_asset_id=v_asset.id and v_asset.status='ready' then
      v_state:='committed';
    elsif v_asset.status in ('quarantined','deleted') or v_job.state='expired' then
      v_state:='abandoned';
    elsif v_job.artifact_media_asset_id=v_asset.id and v_asset.status='pending' then
      v_state:='pending';
    end if;
  end if;
  return jsonb_build_object('state',v_state,'job_id',p_file_job_id,'asset_id',p_asset_id,
    'byte_length',case when v_state='committed' then v_asset.byte_size else null end,
    'checksum_sha256',case when v_state='committed' then v_asset.checksum_sha256 else null end);
end;
$$;
create function public.form_worker_complete_xlsx_r2_v1(p_job_id uuid,p_worker_id text,p_file_job_id uuid,p_asset_id uuid,
  p_actual_byte_length bigint,p_actual_checksum_sha256 text)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_worker_complete_xlsx_r2_v1($1,$2,$3,$4,$5,$6);
$$;
create function public.form_worker_reconcile_xlsx_r2_v1(p_job_id uuid,p_file_job_id uuid,p_asset_id uuid)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_worker_reconcile_xlsx_r2_v1($1,$2,$3);
$$;
revoke all on function app_private.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text),
  app_private.form_worker_reconcile_xlsx_r2_v1(uuid,uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text),
  public.form_worker_reconcile_xlsx_r2_v1(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.form_worker_complete_xlsx_r2_v1(uuid,text,uuid,uuid,bigint,text),
  public.form_worker_reconcile_xlsx_r2_v1(uuid,uuid,uuid) to service_role;
-- Keep historical Storage cleanup realm-specific. R2 lifecycle is handled
-- by its own nominal operations against the same authoritative catalog.
create or replace function app_private.form_worker_cleanup_snapshot(
  p_job_id uuid,
  p_worker_id text,
  p_limit integer default 100
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare page_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
declare result jsonb;
begin
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object('id', id, 'storage_path', storage_path)), '[]'::jsonb)
    ) into result
      from (
        select id, storage_path from public.form_assets
         where (state in ('prepared', 'uploaded') and expires_at <= now())
            or (state = 'discarded' and discarded_at is not null)
         order by expires_at, id limit page_limit
      ) candidate;
  else
    select jsonb_build_object(
      'kind', worker_job.job_kind,
      'items', coalesce(jsonb_agg(jsonb_build_object(
        'id', id,
        'storage_path', storage_path,
        'multipart_bucket', multipart_bucket,
        'multipart_path', multipart_path,
        'multipart_upload_id', multipart_upload_id
      )), '[]'::jsonb)
    ) into result
      from (
        select file_job.id, file_job.artifact_path as storage_path,
               multipart.bucket_id as multipart_bucket,
               multipart.object_path as multipart_path,
               multipart.upload_id as multipart_upload_id
          from public.form_file_jobs file_job
          left join app_private.form_multipart_uploads multipart
            on multipart.file_job_id = file_job.id
           and multipart.state in ('initiated', 'uploading')
         where file_job.artifact_provider = 'supabase_mvp'
           and file_job.state in ('pending', 'succeeded', 'partial', 'failed')
           and file_job.expires_at <= now()
         order by file_job.expires_at, file_job.id limit page_limit
      ) candidate;
  end if;
  return result;
end;
$$;

create or replace function app_private.form_worker_complete_cleanup(
  p_job_id uuid,
  p_worker_id text,
  p_item_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare worker_job app_private.form_worker_jobs;
declare completed_count integer;
declare requested_count integer := coalesce(cardinality(p_item_ids), 0);
begin
  if p_item_ids is null or requested_count > 200
     or requested_count <> (
       select count(distinct item_id) from unnest(p_item_ids) as items(item_id)
     ) then
    raise invalid_parameter_value using message = 'invalid cleanup items';
  end if;
  select * into worker_job from app_private.form_worker_jobs
   where id = p_job_id and job_kind in ('cleanup_uploads', 'cleanup_artifacts')
     and state = 'processing' and lease_owner = p_worker_id and lease_expires_at >= now()
   for update;
  if worker_job.id is null then
    raise serialization_failure using message = 'worker lease unavailable';
  end if;
  if worker_job.job_kind = 'cleanup_uploads' then
    update public.form_assets
       set state = 'expired'
     where id = any(p_item_ids) and (
       (state in ('prepared', 'uploaded') and expires_at <= now())
       or (state = 'discarded' and discarded_at is not null)
     );
  else
    update app_private.form_multipart_uploads multipart
       set state = 'aborted', aborted_at = now(), updated_at = now()
      where multipart.file_job_id = any(p_item_ids)
        and multipart.state in ('initiated', 'uploading')
        and exists (
          select 1 from public.form_file_jobs file_job
           where file_job.id = multipart.file_job_id
             and file_job.artifact_provider = 'supabase_mvp'
             and file_job.expires_at <= now()
        );
    update public.form_file_jobs
       set state = 'expired', artifact_path = null, artifact_byte_length = null
     where id = any(p_item_ids) and artifact_provider = 'supabase_mvp'
       and state in ('pending', 'succeeded', 'partial', 'failed') and expires_at <= now();
  end if;
  get diagnostics completed_count = row_count;
  if completed_count <> requested_count then
    raise serialization_failure using message = 'cleanup items unavailable';
  end if;
  update app_private.form_worker_jobs
     set state = 'succeeded', progress_jsonb = jsonb_build_object('completed', true, 'items', completed_count),
         completed_at = now(), lease_owner = null, lease_expires_at = null
   where id = worker_job.id;
end;
$$;


revoke all on function app_private.form_worker_cleanup_snapshot(uuid,text,integer),
  app_private.form_worker_complete_cleanup(uuid,text,uuid[]) from public,anon,authenticated,service_role;
-- WIP: worker failure, physical cleanup and R2 writer integration
-- follow in this reserved candidate before a complete packet is proposed.
commit;
