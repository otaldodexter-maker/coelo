param()
$ErrorActionPreference = 'Stop'
$candidatePath = Join-Path $PSScriptRoot '../../migrations/20260908031000_superadmin_location_catalog_v2.sql'
if (-not (Test-Path -LiteralPath $candidatePath)) {
  throw 'RED LOC-CATALOG01: nominal local SQL candidate is missing; no database was contacted.'
}
$candidateSql = Get-Content -Raw -LiteralPath $candidatePath
$requirements = [ordered]@{
  'transaction' = '(?is)\bbegin;.*\bcommit;'
  'locked empty preflight' = '(?is)lock table public\.activity_locations in access exclusive mode.*if exists\(select 1 from public\.activity_locations\)'
  'internal author foreign key' = '(?is)created_by_internal_identity_id uuid.*references app_private\.superadmin_internal_identities\(id\)'
  'exclusive authorship' = 'num_nonnulls\(created_by_person_id,created_by_internal_identity_id\)=1'
  'scope discriminator' = "scope_kind in\('institution','unit'\)"
  'explicit kind' = "kind in\('internal','external'\)"
  'audience is not public' = "visibility in\('team','guardians','students','all'\)"
  'direct access revoked' = '(?is)revoke all on public\.activity_locations from public,anon,authenticated'
  'internal permission read' = "require_superadmin_internal_context\('locations.read'\)"
  'internal permission create' = "require_superadmin_internal_context\('locations.create'\)"
  'receipt row protection' = 'alter table app_private\.superadmin_location_create_receipts enable row level security'
  'receipt actor serialization' = 'pg_advisory_xact_lock'
  'stable pagination' = 'collate "C"'
  'safe envelopes' = 'superadmin_internal_error_envelope'
  'internal audit' = 'audit_append_superadmin_internal'
  'legacy name closure' = 'location_names'
  'legacy helper fingerprint' = 'f1809b1c0b268ed571eaaa958a061015'
}
foreach ($entry in $requirements.GetEnumerator()) {
  if ($candidateSql -notmatch $entry.Value) { throw "RED LOC-CATALOG01: $($entry.Key)" }
}
if ($candidateSql -match '(?im)^\s*(delete from|truncate)\s+public\.activity_locations') {
  throw 'RED LOC-CATALOG01: candidate must not clean existing catalog data.'
}
if ($candidateSql -match '(?im)^\s*insert into public\.platform_(permissions|role_permissions)') {
  throw 'RED LOC-CATALOG01: capability provisioning belongs to nominal fixtures, not this candidate.'
}
Write-Output "PASS: $($requirements.Count) static candidate gates; SQL runtime/replay NOT executed."
