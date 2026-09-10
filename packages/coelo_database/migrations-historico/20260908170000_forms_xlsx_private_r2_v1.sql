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
  add column snapshot_schema jsonb,
  add column snapshot_schema_sha256 text,
  add column snapshot_ready boolean not null default false,
  alter column requested_by_person_id drop not null,
  add constraint form_file_jobs_provider_shape_ck check ((
    (artifact_provider='supabase_mvp' and requested_by_person_id is not null
      and artifact_media_asset_id is null and requested_by_internal_identity_id is null
      and requested_auth_link_id is null and requested_membership_id is null
      and requested_auth_session_id is null and requested_scope_kind is null
      and requested_scope_institution_id is null and requested_management_version is null
      and request_payload_sha256 is null and snapshot_format_version is null
      and snapshot_row_count is null and snapshot_schema is null and snapshot_schema_sha256 is null and not snapshot_ready)
    or (artifact_provider='r2' and requested_by_person_id is null
      and requested_by_internal_identity_id is not null and requested_auth_link_id is not null
      and requested_membership_id is not null and requested_auth_session_id is not null
      and requested_scope_kind in ('platform','institution')
      and ((requested_scope_kind='platform' and requested_scope_institution_id is null)
        or (requested_scope_kind='institution' and requested_scope_institution_id=institution_id))
      and export_kind='xlsx' and occurrence_id is null and artifact_path is null
      and requested_management_version is not null and requested_management_version>=0
      and request_payload_sha256 is not null and request_payload_sha256 ~ '^[0-9a-f]{64}$'
      and snapshot_format_version in (1,2) and snapshot_row_count is not null and snapshot_row_count>=0
      and (snapshot_format_version=1 or not snapshot_ready or (
        jsonb_typeof(snapshot_schema)='object' and snapshot_schema->>'formId'=form_id::text
        and jsonb_typeof(snapshot_schema->'versions')='array'
        and snapshot_schema_sha256=encode(extensions.digest(convert_to(snapshot_schema::text,'UTF8'),'sha256'),'hex'))
        or (state='expired' and snapshot_schema is null and snapshot_schema_sha256 ~ '^[0-9a-f]{64}$'))
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
create unique index form_xlsx_snapshot_export_id_uidx
  on app_private.form_xlsx_snapshot_rows(file_job_id,(submission_jsonb->>'responseId'));

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
    or (old.snapshot_ready and (not new.snapshot_ready or new.snapshot_row_count is distinct from old.snapshot_row_count
      or (new.snapshot_schema is distinct from old.snapshot_schema and not (
        old.snapshot_format_version=2 and old.state='expired' and new.state='expired'
        and old.snapshot_schema is not null and new.snapshot_schema is null
        and not exists(select 1 from app_private.form_xlsx_snapshot_rows s where s.file_job_id=old.id)))
      or new.snapshot_schema_sha256 is distinct from old.snapshot_schema_sha256))
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
    or (job.snapshot_format_version=1 and new.submission_jsonb->>'responseId' is distinct from new.response_id::text)
    or (job.snapshot_format_version=2 and (
      new.submission_jsonb->>'responseId' is null
      or new.submission_jsonb->>'responseId' !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or not exists(select 1 from public.form_responses r where r.id=new.response_id
        and r.form_id=job.form_id and r.institution_id=job.institution_id
        and r.occurrence_id::text=new.submission_jsonb->>'occurrenceId'
        and r.form_version_id::text=new.submission_jsonb->>'versionId'
        and r.identity_mode=new.submission_jsonb#>>'{metadata,identity_mode}'
        and case when r.identity_mode='identified' then new.submission_jsonb->>'responseId'=r.id::text
          else new.submission_jsonb->>'responseId'<>r.id::text
            and ((new.submission_jsonb->'metadata') - array['form_id','identity_mode'])='{}'::jsonb end)))
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
  captured_count bigint; captured_schema jsonb; invalid_capture boolean;
  error_code text; correlation uuid:=gen_random_uuid();
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
        p_expected_version,payload_hash,2,0,false) returning * into job;
      -- All source rows, the complete version graph and typed values share one
      -- MVCC statement snapshot. Invalid incoming/outgoing links reject the
      -- entire request; inner joins must never silently omit damaged history.
      with captured as materialized (
        select r.*,case when r.identity_mode='anonymous' then gen_random_uuid() else r.id end export_id
        from public.form_responses r where r.form_id=form_row.id and r.status='submitted'
      ), versions as materialized (
        select v.* from public.form_versions v where v.id in(select form_version_id from captured)
      ), sections as materialized (
        select s.* from public.form_sections s where s.form_version_id in(select id from versions)
      ), items as materialized (
        select i.* from public.form_items i where i.form_version_id in(select id from versions)
      ), options as materialized (
        select o.* from public.form_question_options o where o.form_version_id in(select id from versions)
      ), conditions as materialized (
        select c.* from public.form_question_conditions c where c.form_version_id in(select id from versions)
      ), graph as (
        select jsonb_build_object('formId',form_row.id,'formTitle',form_row.title,'versions',
          coalesce((select jsonb_agg(jsonb_build_object(
            'versionId',v.id,'versionNumber',v.version_number,'state',v.state,
            'sections',coalesce((select jsonb_agg(jsonb_build_object(
              'sectionId',s.id,'title',s.title,'description',s.description,'position',s.position,
              'items',coalesce((select jsonb_agg(jsonb_build_object(
                'itemId',i.id,'kind',i.kind,'label',i.label,'helpText',i.help_text,
                'position',i.position,'required',i.is_required,'config',i.config_jsonb,
                'options',coalesce((select jsonb_agg(jsonb_build_object(
                  'optionId',o.id,'label',o.label,'position',o.position) order by o.position,o.id)
                  from options o where o.item_id=i.id),'[]'::jsonb)) order by i.position,i.id)
                from items i where i.section_id=s.id),'[]'::jsonb)) order by s.position,s.id)
              from sections s where s.form_version_id=v.id),'[]'::jsonb),
            'conditions',coalesce((select jsonb_agg(jsonb_build_object(
              'sourceItemId',c.source_item_id,'targetItemId',c.target_item_id,'kind',c.condition_kind,
              'expectedYesNo',c.expected_yes_no,'sourceOptionId',c.source_option_id)
              order by c.target_item_id,c.source_item_id,c.id)
              from conditions c where c.form_version_id=v.id),'[]'::jsonb))
            order by v.version_number,v.id) from versions v),'[]'::jsonb)) body
      ), invalid as (
        select exists(select 1 from captured r
          left join public.form_occurrences o on o.id=r.occurrence_id and o.form_id=r.form_id
            and o.institution_id=r.institution_id and o.form_version_id=r.form_version_id
          left join public.form_applications app on app.id=o.application_id
            and app.form_id=r.form_id and app.institution_id=r.institution_id
          left join versions v on v.id=r.form_version_id and v.form_id=r.form_id
          where r.institution_id<>form_row.institution_id or r.identity_mode<>form_row.identity_mode
            or o.id is null or app.id is null or v.id is null)
        or exists(select 1 from public.form_items i join public.form_sections s on s.id=i.section_id
          where (i.form_version_id in(select id from versions) or s.form_version_id in(select id from versions))
            and i.form_version_id<>s.form_version_id)
        or exists(select 1 from public.form_question_options o join public.form_items i on i.id=o.item_id
          where (o.form_version_id in(select id from versions) or i.form_version_id in(select id from versions))
            and (o.form_version_id<>i.form_version_id or i.kind not in ('single_choice','multiple_choice')))
        or exists(select 1 from public.form_question_conditions c
          join public.form_items target on target.id=c.target_item_id
          join public.form_items source on source.id=c.source_item_id
          left join public.form_question_options o on o.id=c.source_option_id
          where (c.form_version_id in(select id from versions) or target.form_version_id in(select id from versions)
            or source.form_version_id in(select id from versions))
            and (c.form_version_id<>target.form_version_id or c.form_version_id<>source.form_version_id
              or (c.condition_kind='yes_no' and source.kind<>'yes_no')
              or (c.condition_kind='choice' and (source.kind not in ('single_choice','multiple_choice')
                or o.id is null or o.form_version_id<>c.form_version_id or o.item_id<>source.id))))
        or exists(select 1 from public.form_answers a join captured r on r.id=a.response_id
          left join items i on i.id=a.item_id and i.form_version_id=r.form_version_id
          left join sections s on s.id=i.section_id and s.form_version_id=r.form_version_id
          where a.form_version_id<>r.form_version_id or i.id is null or s.id is null or a.answer_kind<>i.kind
            or case a.answer_kind
              when 'short_text' then a.text_value is null
              when 'integer' then a.integer_value is null
              when 'decimal' then a.decimal_value is null
              when 'money' then a.money_minor_units is null or jsonb_typeof(i.config_jsonb->'currency') is distinct from 'string'
              when 'date' then a.date_value is null
              when 'yes_no' then a.yes_no_value is null
              when 'scale' then a.scale_value is null else false end)
        or exists(select 1 from public.form_answer_options ao
          join public.form_answers a on a.id=ao.answer_id join captured r on r.id=a.response_id
          left join options o on o.id=ao.option_id and o.item_id=a.item_id and o.form_version_id=r.form_version_id
          where o.id is null or a.answer_kind not in ('single_choice','multiple_choice'))
        or exists(select 1 from public.form_answer_assets aa
          join public.form_answers a on a.id=aa.answer_id join captured r on r.id=a.response_id
          left join public.form_assets asset on asset.id=aa.asset_id and asset.item_id=a.item_id
            and asset.occurrence_id=r.occurrence_id and asset.institution_id=r.institution_id
          where asset.id is null or asset.state<>'finalized' or a.answer_kind not in ('photo','gallery')
            or (r.identity_mode='identified' and asset.prepared_by_person_id is distinct from r.respondent_person_id)
            or (r.identity_mode='anonymous' and asset.prepared_by_person_id is not null)) bad
      ), inserted as (
        insert into app_private.form_xlsx_snapshot_rows(file_job_id,sequence_number,response_id,submission_jsonb)
        select job.id,row_number() over(order by r.export_id),r.id,jsonb_build_object(
          'responseId',r.export_id,'occurrenceId',r.occurrence_id,'versionId',r.form_version_id,
          'metadata',jsonb_build_object('form_id',r.form_id,'identity_mode',r.identity_mode)
            ||case when r.identity_mode='identified' then jsonb_build_object(
              'respondent',(select display_name from public.people where id=r.respondent_person_id),
              'submitted_at',r.submitted_at) else '{}'::jsonb end,
          'answers',coalesce((select jsonb_agg(jsonb_build_object('itemId',i.id,'values',case
            when a.answer_kind in ('single_choice','multiple_choice') then coalesce((
              select jsonb_agg(jsonb_build_object('kind','choice','optionId',ao.option_id) order by ao.position,ao.option_id)
              from public.form_answer_options ao where ao.answer_id=a.id),'[]'::jsonb)
            when a.answer_kind in ('photo','gallery') then coalesce((
              select jsonb_agg(jsonb_build_object('kind','media','assetId',aa.asset_id) order by aa.position,aa.asset_id)
              from public.form_answer_assets aa where aa.answer_id=a.id),'[]'::jsonb)
            else jsonb_build_array(case a.answer_kind
              when 'short_text' then jsonb_build_object('kind','text','value',a.text_value)
              when 'integer' then jsonb_build_object('kind','integer','value',a.integer_value::text)
              when 'decimal' then jsonb_build_object('kind','decimal','value',a.decimal_value::text)
              when 'money' then jsonb_build_object('kind','money','minorUnits',a.money_minor_units::text,'currency',i.config_jsonb->>'currency')
              when 'date' then jsonb_build_object('kind','date','value',a.date_value::text)
              when 'yes_no' then jsonb_build_object('kind','boolean','value',a.yes_no_value)
              when 'scale' then jsonb_build_object('kind','integer','value',a.scale_value::text) end) end)
            order by s.position,i.position,i.id)
            from public.form_answers a join items i on i.id=a.item_id
            join sections s on s.id=i.section_id where a.response_id=r.id),'[]'::jsonb))
          from captured r where not (select bad from invalid)
          returning 1
      ) select graph.body,invalid.bad,(select count(*) from inserted)
        into captured_schema,invalid_capture,captured_count from graph cross join invalid;
      if invalid_capture then raise check_violation using detail='SAI_UNAVAILABLE'; end if;
      update public.form_file_jobs set snapshot_ready=true,snapshot_row_count=captured_count,
        snapshot_schema=captured_schema,
        snapshot_schema_sha256=encode(extensions.digest(convert_to(captured_schema::text,'UTF8'),'sha256'),'hex')
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
    'form_id',v_job.form_id,
    'asset_id',v_asset.id,'institution_id',v_job.institution_id,'provider','r2','bucket',v_asset.bucket_id,
    'object_key',v_asset.object_key,'mime_type',v_asset.mime_type,'expires_at',v_job.expires_at,
    'snapshot_format_version',v_job.snapshot_format_version,'snapshot_row_count',v_job.snapshot_row_count,
    'snapshot_schema',v_job.snapshot_schema,'snapshot_schema_sha256',v_job.snapshot_schema_sha256);
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
    'snapshot_schema_sha256',v_job.snapshot_schema_sha256,
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
  if exists(select 1 from app_private.form_multipart_uploads m where m.media_asset_id=p_asset_id
    and m.artifact_provider='r2' and (m.state is distinct from 'completed'
      or m.uploaded_bytes is distinct from p_actual_byte_length
      or m.checksum_sha256 is distinct from p_actual_checksum_sha256)) then
    raise check_violation using message='forms_xlsx_multipart_finalization_mismatch';
  end if;
  -- Measurements come only from the service generating and writing the XLSX.
  -- No client grant and no caller-supplied path, MIME, tenant or manifest.
  update public.media_assets set status='ready',byte_size=p_actual_byte_length,
    checksum_sha256=p_actual_checksum_sha256,finalized_at=clock_timestamp() where id=p_asset_id;
  update public.form_file_jobs set state='succeeded',progress=1,artifact_byte_length=p_actual_byte_length,
    completed_at=clock_timestamp(),error_code=null,
    manifest_jsonb=jsonb_build_object('format_version',snapshot_format_version,'response_count',snapshot_row_count,
      'schema_sha256',snapshot_schema_sha256)
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
-- Preserve the legacy single upload while retaining every R2 asset attempt.
alter table app_private.form_multipart_uploads
  add column artifact_provider text not null default 'supabase_mvp',
  add column media_asset_id uuid references public.media_assets(id) on delete restrict,
  add column worker_attempt integer,
  add column attempt_owner text,
  add column snapshot_format_version integer,
  add column snapshot_row_count bigint,
  add column checksum_sha256 text,
  drop constraint form_multipart_uploads_file_job_id_key,
  drop constraint form_multipart_uploads_bucket_ck,
  drop constraint form_multipart_uploads_path_ck,
  add constraint form_multipart_uploads_provider_ck check (
    (artifact_provider='supabase_mvp' and bucket_id='coelo-forms-private'
      and object_path ~ '^[0-9a-f]{2}/[0-9a-f-]{36}$' and media_asset_id is null
      and worker_attempt is null and attempt_owner is null and snapshot_format_version is null
      and snapshot_row_count is null and checksum_sha256 is null)
    or (artifact_provider='r2' and bucket_id='coelo-transient-prod'
      and media_asset_id is not null and worker_attempt is not null and worker_attempt between 1 and 20
      and attempt_owner is not null and length(attempt_owner) between 1 and 240
      and snapshot_format_version is not null and snapshot_format_version in (1,2)
      and snapshot_row_count is not null and snapshot_row_count>=0
      and object_path ~ '^tenants/[0-9a-f-]{36}/exports/forms/[0-9a-f-]{36}/[0-9a-f-]{36}/responses[.]xlsx$'
      and ((state='completed' and checksum_sha256 is not null and checksum_sha256 ~ '^[0-9a-f]{64}$')
        or (state<>'completed' and checksum_sha256 is null)))
  );
create unique index form_multipart_uploads_legacy_job_uidx
  on app_private.form_multipart_uploads(file_job_id) where artifact_provider='supabase_mvp';
create unique index form_multipart_uploads_r2_asset_uidx
  on app_private.form_multipart_uploads(media_asset_id) where artifact_provider='r2';
create unique index form_multipart_uploads_r2_attempt_uidx
  on app_private.form_multipart_uploads(worker_job_id,worker_attempt) where artifact_provider='r2';
alter table app_private.form_multipart_uploads enable row level security;
alter table app_private.form_multipart_uploads force row level security;
alter table app_private.form_multipart_parts enable row level security;
alter table app_private.form_multipart_parts force row level security;
revoke all on app_private.form_multipart_uploads,app_private.form_multipart_parts from public,anon,authenticated,service_role;

create function app_private.forms_xlsx_multipart_binding_v1() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_asset public.media_assets; v_worker app_private.form_worker_jobs;
begin
  if tg_op='UPDATE' and (new.artifact_provider,new.file_job_id,new.worker_job_id,new.bucket_id,new.object_path,
    new.upload_id,new.media_asset_id,new.worker_attempt,new.attempt_owner,new.snapshot_format_version,new.snapshot_row_count)
    is distinct from (old.artifact_provider,old.file_job_id,old.worker_job_id,old.bucket_id,old.object_path,
    old.upload_id,old.media_asset_id,old.worker_attempt,old.attempt_owner,old.snapshot_format_version,old.snapshot_row_count) then
    raise check_violation using message='forms_xlsx_multipart_origin_immutable';
  end if;
  select * into v_job from public.form_file_jobs where id=new.file_job_id;
  if v_job.artifact_provider is distinct from new.artifact_provider then
    raise check_violation using message='forms_xlsx_multipart_provider_mismatch';
  end if;
  if new.artifact_provider='r2' then
    select * into v_asset from public.media_assets where id=new.media_asset_id;
    select * into v_worker from app_private.form_worker_jobs where id=new.worker_job_id;
    if v_asset.id is null or v_asset.catalog_kind<>'form-xlsx' or v_asset.export_file_job_id<>v_job.id
      or v_asset.form_id<>v_job.form_id or v_asset.institution_id<>v_job.institution_id
      or v_asset.owner_internal_identity_id<>v_job.requested_by_internal_identity_id
      or v_asset.bucket_id<>new.bucket_id or v_asset.object_key<>new.object_path
      or v_asset.upload_request_id<>'xlsx:'||new.worker_job_id::text||':'||new.worker_attempt::text
      or v_worker.id is null or v_worker.job_kind<>'export_xlsx_r2_v1' or v_worker.aggregate_id<>v_job.id
      or new.snapshot_format_version<>v_job.snapshot_format_version or new.snapshot_row_count<>v_job.snapshot_row_count then
      raise check_violation using message='forms_xlsx_multipart_binding_mismatch';
    end if;
    if tg_op='INSERT' and (v_asset.status is distinct from 'pending' or v_job.artifact_media_asset_id is distinct from v_asset.id
      or v_worker.attempts is distinct from new.worker_attempt or v_worker.lease_owner is distinct from new.attempt_owner
      or v_worker.state is distinct from 'processing' or v_worker.lease_expires_at is null
      or v_worker.lease_expires_at<=clock_timestamp()) then
      raise check_violation using message='forms_xlsx_multipart_attempt_unavailable';
    end if;
    if tg_op='UPDATE' and old.state in ('completed','aborted') and
      (new.state,new.uploaded_bytes,new.next_part_number,new.checksum_sha256,new.completed_at,new.aborted_at)
      is distinct from (old.state,old.uploaded_bytes,old.next_part_number,old.checksum_sha256,old.completed_at,old.aborted_at) then
      raise check_violation using message='forms_xlsx_multipart_terminal_immutable';
    end if;
  end if;
  return new;
end;
$$;
create trigger forms_xlsx_multipart_binding_v1 before insert or update on app_private.form_multipart_uploads
  for each row execute function app_private.forms_xlsx_multipart_binding_v1();
revoke all on function app_private.forms_xlsx_multipart_binding_v1() from public,anon,authenticated,service_role;

create function app_private.forms_xlsx_multipart_projection_v1(p_upload_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('bucket_id',m.bucket_id,'object_path',m.object_path,'upload_id',m.upload_id,
    'state',m.state,'next_part_number',m.next_part_number,'uploaded_bytes',m.uploaded_bytes,
    'checksum_sha256',m.checksum_sha256,
    'scope',jsonb_build_object('worker_job_id',m.worker_job_id,'worker_id',m.attempt_owner,
      'file_job_id',m.file_job_id,'attempt',m.worker_attempt,'asset_id',m.media_asset_id,
      'bucket',m.bucket_id,'object_key',m.object_path,'snapshot_format_version',m.snapshot_format_version,
      'snapshot_row_count',m.snapshot_row_count),
    'parts',coalesce((select jsonb_agg(jsonb_build_object('part_number',p.part_number,'etag',p.etag,
      'byte_length',p.byte_length,'checksum_sha256',p.checksum_sha256) order by p.part_number)
      from app_private.form_multipart_parts p where p.multipart_upload_id=m.id),'[]'::jsonb))
  from app_private.form_multipart_uploads m where m.id=p_upload_id and m.artifact_provider='r2';
$$;
revoke all on function app_private.forms_xlsx_multipart_projection_v1(uuid) from public,anon,authenticated,service_role;

-- An explicit scope binds every network operation to the same authorized
-- lease, sealed snapshot and opaque asset. Reconciliation grants no delivery.
create function app_private.form_worker_multipart_xlsx_r2_v1(
  p_scope jsonb,p_operation text,p_payload jsonb default '{}'::jsonb
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_job public.form_file_jobs; v_asset public.media_assets; v_worker app_private.form_worker_jobs;
  v_upload app_private.form_multipart_uploads; v_part app_private.form_multipart_parts;
  v_job_id uuid; v_file_job_id uuid; v_asset_id uuid; v_owner text; v_expected jsonb;
  v_upload_id text; v_number integer; v_bytes bigint; v_etag text; v_checksum text; v_allowed text[];
begin
  if current_setting('transaction_isolation')<>'read committed' or p_scope is null or jsonb_typeof(p_scope)<>'object'
    or pg_column_size(p_scope)>4096 or p_payload is null or jsonb_typeof(p_payload)<>'object'
    or pg_column_size(p_payload)>4096 or p_operation is null
    or p_operation not in ('authorize','snapshot','begin','record_part','complete','reconcile') then
    raise invalid_parameter_value using message='forms_xlsx_multipart_input_invalid';
  end if;
  v_job_id:=(p_scope->>'worker_job_id')::uuid; v_file_job_id:=(p_scope->>'file_job_id')::uuid;
  v_asset_id:=(p_scope->>'asset_id')::uuid; v_owner:=p_scope->>'worker_id';
  if v_job_id is null or v_file_job_id is null or v_asset_id is null or v_owner is null then
    raise invalid_parameter_value using message='forms_xlsx_multipart_input_invalid';
  end if;
  if p_operation='reconcile' then
    select * into v_worker from app_private.form_worker_jobs where id=v_job_id
      and aggregate_id=v_file_job_id and job_kind='export_xlsx_r2_v1' for share;
    if v_worker.id is null then return null; end if;
    select * into v_upload from app_private.form_multipart_uploads where worker_job_id=v_job_id
      and file_job_id=v_file_job_id and media_asset_id=v_asset_id and artifact_provider='r2' for share;
    if v_upload.id is null then return null; end if;
    v_expected:=app_private.forms_xlsx_multipart_projection_v1(v_upload.id)->'scope';
    if p_scope is distinct from v_expected then raise serialization_failure using message='forms_xlsx_multipart_scope_mismatch'; end if;
  else
    v_job:=app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
    select * into strict v_worker from app_private.form_worker_jobs where id=v_job_id;
    select * into strict v_asset from public.media_assets where id=v_asset_id for update;
    v_expected:=jsonb_build_object('worker_job_id',v_job_id,'worker_id',v_owner,'file_job_id',v_file_job_id,
      'attempt',v_worker.attempts,'asset_id',v_asset_id,'bucket',v_asset.bucket_id,'object_key',v_asset.object_key,
      'snapshot_format_version',v_job.snapshot_format_version,'snapshot_row_count',v_job.snapshot_row_count);
    if p_scope is distinct from v_expected then raise serialization_failure using message='forms_xlsx_multipart_scope_mismatch'; end if;
    select * into v_upload from app_private.form_multipart_uploads
      where media_asset_id=v_asset_id and artifact_provider='r2' for update;
  end if;
  v_allowed:=case p_operation
    when 'begin' then array['upload_id']
    when 'record_part' then array['upload_id','part_number','etag','byte_length','checksum_sha256']
    when 'complete' then array['upload_id','byte_length','checksum_sha256']
    when 'reconcile' then array['upload_id','byte_length','checksum_sha256']
    else array[]::text[] end;
  if exists(select 1 from jsonb_object_keys(p_payload) k where not(k=any(v_allowed)))
    or exists(select 1 from unnest(v_allowed) k where not(p_payload?k)) then
    raise invalid_parameter_value using message='forms_xlsx_multipart_payload_invalid';
  end if;
  if p_operation in ('authorize','snapshot') then
    perform app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
    if p_operation='authorize' then return jsonb_build_object('authorized',true,'scope',v_expected); end if;
    return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
  end if;
  v_upload_id:=p_payload->>'upload_id';
  if jsonb_typeof(p_payload->'upload_id')<>'string' or v_upload_id is null
    or length(v_upload_id) not between 1 and 1024 or v_upload_id ~ '[[:space:][:cntrl:]]' then
    raise invalid_parameter_value using message='forms_xlsx_multipart_upload_id_invalid';
  end if;
  if p_operation='begin' then
    if v_upload.id is null then
      insert into app_private.form_multipart_uploads(file_job_id,worker_job_id,bucket_id,object_path,upload_id,
        artifact_provider,media_asset_id,worker_attempt,attempt_owner,snapshot_format_version,snapshot_row_count)
      values(v_file_job_id,v_job_id,v_asset.bucket_id,v_asset.object_key,v_upload_id,'r2',v_asset_id,
        v_worker.attempts,v_owner,v_job.snapshot_format_version,v_job.snapshot_row_count) returning * into v_upload;
    elsif v_upload.upload_id<>v_upload_id or v_upload.state='aborted' then
      raise serialization_failure using message='forms_xlsx_multipart_begin_mismatch';
    end if;
  else
    if v_upload.id is null or v_upload.upload_id<>v_upload_id or v_upload.state='aborted' then
      raise serialization_failure using message='forms_xlsx_multipart_upload_unavailable';
    end if;
    v_bytes:=(p_payload->>'byte_length')::bigint; v_checksum:=p_payload->>'checksum_sha256';
    if jsonb_typeof(p_payload->'byte_length')<>'number' or v_bytes is null or v_bytes<1
      or p_payload->'byte_length'<>to_jsonb(v_bytes) or jsonb_typeof(p_payload->'checksum_sha256')<>'string'
      or v_checksum is null or v_checksum!~'^[0-9a-f]{64}$' then
      raise invalid_parameter_value using message='forms_xlsx_measurement_invalid';
    end if;
    if p_operation='record_part' then
      v_number:=(p_payload->>'part_number')::integer; v_etag:=p_payload->>'etag';
      if jsonb_typeof(p_payload->'part_number')<>'number' or v_number is null or v_number not between 1 and 10000
        or p_payload->'part_number'<>to_jsonb(v_number) or jsonb_typeof(p_payload->'etag')<>'string'
        or v_etag is null or length(v_etag) not between 3 and 1024 or v_etag!~'^"[^"[:cntrl:]]+"$'
        or v_bytes>67108864 then raise invalid_parameter_value using message='forms_xlsx_multipart_part_invalid'; end if;
      select * into v_part from app_private.form_multipart_parts where multipart_upload_id=v_upload.id and part_number=v_number;
      if v_part.multipart_upload_id is not null then
        if (v_part.etag,v_part.byte_length,v_part.checksum_sha256) is distinct from (v_etag,v_bytes,v_checksum) then
          raise serialization_failure using message='forms_xlsx_multipart_part_replay_mismatch';
        end if;
      else
        if v_upload.state='completed' or v_number<>v_upload.next_part_number then
          raise serialization_failure using message='forms_xlsx_multipart_part_out_of_sequence';
        end if;
        -- Before another part, the preceding part must satisfy the provider's
        -- minimum and uniform non-final size. The final part may be smaller.
        if v_number>1 and (v_bytes>(select first.byte_length from app_private.form_multipart_parts first
          where first.multipart_upload_id=v_upload.id and first.part_number=1)
          or exists(select 1 from app_private.form_multipart_parts p
          where p.multipart_upload_id=v_upload.id and (p.byte_length<5242880 or p.byte_length<>
            (select first.byte_length from app_private.form_multipart_parts first
             where first.multipart_upload_id=v_upload.id and first.part_number=1)))) then
          raise check_violation using message='forms_xlsx_multipart_nonfinal_size_invalid';
        end if;
        insert into app_private.form_multipart_parts(multipart_upload_id,part_number,etag,byte_length,checksum_sha256)
          values(v_upload.id,v_number,v_etag,v_bytes,v_checksum);
        update app_private.form_multipart_uploads set state='uploading',next_part_number=next_part_number+1,
          uploaded_bytes=uploaded_bytes+v_bytes,updated_at=clock_timestamp() where id=v_upload.id returning * into v_upload;
      end if;
    elsif p_operation='complete' then
      if v_upload.uploaded_bytes<>v_bytes or v_upload.next_part_number<=1 then
        raise check_violation using message='forms_xlsx_multipart_measurement_mismatch';
      end if;
      if v_upload.state='completed' then
        if v_upload.checksum_sha256<>v_checksum then raise serialization_failure using message='forms_xlsx_multipart_complete_mismatch'; end if;
      else
        update app_private.form_multipart_uploads set state='completed',checksum_sha256=v_checksum,
          completed_at=clock_timestamp(),updated_at=clock_timestamp() where id=v_upload.id returning * into v_upload;
      end if;
    elsif p_operation='reconcile' then
      if v_upload.state<>'completed' then return null; end if;
      if v_upload.uploaded_bytes<>v_bytes or v_upload.checksum_sha256<>v_checksum then
        raise serialization_failure using message='forms_xlsx_multipart_complete_mismatch';
      end if;
      return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
    end if;
  end if;
  perform app_private.forms_xlsx_worker_job_v1(v_job_id,v_owner,v_file_job_id,v_asset_id);
  return app_private.forms_xlsx_multipart_projection_v1(v_upload.id);
end;
$$;
create function public.form_worker_multipart_xlsx_r2_v1(p_scope jsonb,p_operation text,p_payload jsonb default '{}'::jsonb)
returns jsonb language sql volatile security definer set search_path='' as $$
  select app_private.form_worker_multipart_xlsx_r2_v1($1,$2,$3);
$$;
revoke all on function app_private.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb) from public,anon,authenticated;
grant execute on function public.form_worker_multipart_xlsx_r2_v1(jsonb,text,jsonb) to service_role;

-- C00 I016: preserve the shared queue contract and the existing attempts CHECK.
-- Exhausted jobs retain their state, lease and artifacts for reconciliation.
create or replace function app_private.form_claim_worker_job(
  p_worker_id text,
  p_lease_seconds integer default 60,
  p_job_kinds text[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare job_row app_private.form_worker_jobs;
begin
  if nullif(btrim(p_worker_id), '') is null or p_lease_seconds not between 10 and 600 then
    raise invalid_parameter_value using message = 'valid worker id and lease required';
  end if;
  update app_private.form_worker_jobs job
     set state = 'processing',
         attempts = attempts + 1,
         lease_owner = p_worker_id,
         lease_expires_at = now() + make_interval(secs => p_lease_seconds)
   where job.id = (
     select candidate.id
       from app_private.form_worker_jobs candidate
      where (
        (candidate.state in ('pending', 'failed') and candidate.available_at <= now())
        or (candidate.state = 'processing' and candidate.lease_expires_at < now())
      )
        and candidate.attempts < 20
        and (p_job_kinds is null or candidate.job_kind = any(p_job_kinds))
      order by candidate.available_at, candidate.created_at, candidate.id
      limit 1
      for update skip locked
   )
  returning * into job_row;
  if job_row.id is null then return null; end if;
  return jsonb_build_object(
    'id', job_row.id,
    'job_kind', job_row.job_kind,
    'aggregate_id', job_row.aggregate_id,
    'payload', job_row.payload_jsonb,
    'progress', job_row.progress_jsonb,
    'attempts', job_row.attempts,
    'created_at', job_row.created_at,
    'lease_expires_at', job_row.lease_expires_at
  );
end;
$$;

-- WIP: worker failure, physical cleanup and R2 writer integration
-- follow in this reserved candidate before a complete packet is proposed.
commit;
