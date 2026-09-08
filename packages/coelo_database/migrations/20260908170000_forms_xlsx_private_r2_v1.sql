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
  if tg_op='UPDATE' and row(new.export_file_job_id,new.expires_at)
    is distinct from row(old.export_file_job_id,old.expires_at) then
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
-- WIP: request/capture, worker leases/finalization/reconciliation, token issue/
-- redeem and cleanup RPCs follow in this same reserved candidate before review.
commit;
