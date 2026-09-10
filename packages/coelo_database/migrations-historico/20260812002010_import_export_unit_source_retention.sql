begin;

-- The attestation is written before the established preview routine records
-- import_files, so a single trigger persists its checksum and 24h retention.
create or replace function app_private.attest_unit_import_file_retention()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  attestation app_private.unit_import_source_attestations%rowtype;
begin
  if new.import_job_id is not null then
    select * into attestation
    from app_private.unit_import_source_attestations
    where import_job_id = new.import_job_id;
    if attestation.import_job_id is not null then
      new.checksum_sha256 := attestation.checksum_sha256;
      new.retention_expires_at := coalesce(
        new.retention_expires_at,
        new.uploaded_at + interval '24 hours'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists import_files_attest_unit_source on public.import_files;
create trigger import_files_attest_unit_source
before insert or update of import_job_id, uploaded_at, retention_expires_at
on public.import_files
for each row execute function app_private.attest_unit_import_file_retention();

revoke all on function app_private.attest_unit_import_file_retention()
from public, anon, authenticated, service_role;

commit;
