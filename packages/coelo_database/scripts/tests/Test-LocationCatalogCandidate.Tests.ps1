param([string]$Revision = '')
$ErrorActionPreference = 'Stop'
if ($Revision -and $Revision -notmatch '^[0-9a-f]{40}$') { throw 'Revision must be an exact commit hash.' }
function Read-NominalCandidateFile([string]$RelativePath) {
  if ($Revision) {
    $content = & git show "$($Revision):packages/coelo_database/$RelativePath"
    if ($LASTEXITCODE -ne 0) { throw "Missing nominal file at revision: $RelativePath" }
    return $content -join "`n"
  }
  return Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "../../$RelativePath")
}
$candidatePath = Join-Path $PSScriptRoot '../../migrations/20260908031000_superadmin_location_catalog_v2.sql'
if (-not (Test-Path -LiteralPath $candidatePath)) {
  throw 'RED LOC-CATALOG01: nominal local SQL candidate is missing; no database was contacted.'
}
$candidateSql = Read-NominalCandidateFile 'migrations/20260908031000_superadmin_location_catalog_v2.sql'
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
$observedPg17Acl = "array['authenticated:SELECT:false','service_role:DELETE:false','service_role:INSERT:false','service_role:MAINTAIN:false','service_role:REFERENCES:false','service_role:SELECT:false','service_role:TRIGGER:false','service_role:TRUNCATE:false','service_role:UPDATE:false']"
if (($candidateSql -replace '\s','').IndexOf($observedPg17Acl, [StringComparison]::Ordinal) -lt 0) {
  throw 'RED LOC-ACL01: exact Auth47 observed PG17 ACL must include MAINTAIN and no invented grants.'
}
if ($candidateSql -match '(?im)^\s*(delete from|truncate)\s+public\.activity_locations') {
  throw 'RED LOC-CATALOG01: candidate must not clean existing catalog data.'
}
if ($candidateSql -match '(?im)^\s*insert into public\.platform_(permissions|role_permissions)') {
  throw 'RED LOC-CATALOG01: capability provisioning belongs to nominal fixtures, not this candidate.'
}
foreach ($testFile in @('superadmin_location_catalog_v2_test.sql','superadmin_location_catalog_v2_authorization_test.sql','superadmin_location_catalog_v2_isolation_test.sql')) {
  $testSql = Read-NominalCandidateFile "supabase/tests/$testFile"
  $actorBlocks = [regex]::Matches($testSql, '(?is)set local role authenticated;(.*?)reset role;')
  foreach ($actorBlock in $actorBlocks) {
    if ($actorBlock.Groups[1].Value -match '(?is)\bselect\s+(is|ok|throws_ok|lives_ok|no_plan|finish)\s*\(') {
      throw "RED LOC-TAP01: TAP assertion executes as authenticated in $testFile"
    }
  }
}
$bootstrapSql = Read-NominalCandidateFile 'tests/fixtures/location_catalog_v2_capability_bootstrap.sql'
if ($bootstrapSql -notmatch 'module_label' -or $bootstrapSql -notmatch 'screen_label' -or $bootstrapSql -notmatch 'action_label') {
  throw 'RED LOC-TAP01: bootstrap must explicitly supply required permission labels.'
}
if ($candidateSql -notmatch "is distinct from \(case when expected\.client_execute then array\['authenticated:EXECUTE:false'\] else '\{\}'::text\[\] end\) then") {
  throw 'RED LOC-PARSE02: legacy helper ACL CASE must be parenthesized exactly; no ACL semantic change.'
}
if ($candidateSql -match "length\(text_value\)>case") {
  throw 'RED LOC-LOCK01: CASE expression in PLpgSQL condition must be parenthesized.'
}
if ($candidateSql -notmatch "(?s)pg_advisory_xact_lock\([^;]+;\s+select \* into strict ctx from app_private.require_superadmin_internal_context\('locations.create'\)") {
  throw 'RED LOC-LOCK01: context must be revalidated immediately after advisory lock acquisition.'
}
if ([regex]::Matches($candidateSql,"current_setting\('transaction_isolation'\)<>'read committed'").Count -ne 3) {
  throw 'RED LOC-LOCK01: all three gateways must enforce READ COMMITTED.'
}
if ([regex]::Matches($candidateSql,'session_record.not_after>clock_timestamp\(\)').Count -ne 3) {
  throw 'RED LOC-LOCK01: all three gateways must check original session wall-clock expiry after waits.'
}
Write-Output "PASS: $($requirements.Count) static candidate gates plus TAP-role/label/post-lock/isolation guards; SQL runtime/replay NOT executed."
