[CmdletBinding()]
param([string]$Revision = '')
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixture = [IO.File]::ReadAllText((Join-Path $packageRoot 'tests/fixtures/location_form_options_remote_snapshot_local.sql'))
$snapshotMatch = [regex]::Match($fixture,'(?s)\$snapshot\$(.*?)\$snapshot\$')
if (-not $snapshotMatch.Success) { throw 'snapshot literal missing' }
$snapshot = $snapshotMatch.Groups[1].Value | ConvertFrom-Json
function Get-Md5([string]$Value) {
  $digest = [Security.Cryptography.MD5]::Create()
  try { return ([BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant() }
  finally { $digest.Dispose() }
}
if ((Get-Md5 $snapshot.definition) -ne '65fe6408f0f2c6b0c1c9d71a809f2d80' -or
    (Get-Md5 $snapshot.definition.Replace("`r`n","`n")) -ne '516a06602a96073317e495dbb9d5b040') {
  throw 'remote snapshot bytes not identical to catalog evidence'
}
if ($Revision) {
  if ($Revision -notmatch '^[0-9a-f]{40}$') { throw 'exact revision required' }
  $candidate = (& git show "$($Revision):packages/coelo_database/migrations/20260908031000_superadmin_location_catalog_v2.sql") -join "`n"
  if ($LASTEXITCODE -ne 0) { throw 'candidate revision missing' }
} else {
  $candidate = [IO.File]::ReadAllText((Join-Path $packageRoot 'migrations/20260908031000_superadmin_location_catalog_v2.sql'))
}
$match = [regex]::Match($candidate, '(?s)\(''app_private\.superadmin_get_activity_form_options\(uuid\)'',\s+\$pattern\$(.*?)\$pattern\$,\s+\$replacement\$(.*?)\$replacement\$')
if (-not $match.Success) { throw 'nominal options closure pattern missing' }
$pattern = $match.Groups[1].Value.Replace('[[:space:]]','\s')
$regex = [regex]::new($pattern,[Text.RegularExpressions.RegexOptions]::Singleline)
$remoteMatches = $regex.Matches($snapshot.definition)
if ($remoteMatches.Count -ne 1) { throw "RED: exact remote options block must match once; observed $($remoteMatches.Count)" }
$canonical = [IO.File]::ReadAllText((Join-Path $packageRoot 'migrations/20260811200614_activity_read_model_contract_hardening.sql'))
if ($regex.Matches($canonical).Count -ne 0) { throw 'canonical alternate with students must not be accepted' }
if ($match.Groups[1].Value.Contains('.*?')) { throw 'options closure must not use a broad wildcard' }
$replacement = $match.Groups[2].Value
if ($replacement -cne "'locations','[]'::jsonb") { throw 'replacement expands beyond empty locations' }
$changed = $regex.Replace($snapshot.definition,$replacement)
if ((Get-Md5 $changed) -ne '2486e539f723d3f61cd9f29984efcbb2' -or
    -not $candidate.Contains("<>'2486e539f723d3f61cd9f29984efcbb2'")) {
  throw 'RED: exact options output hash must be pinned in candidate'
}
if (-not $candidate.Contains("message='location legacy options metadata drift'")) {
  throw 'RED: options metadata must be checked explicitly'
}
if ($changed -cne $snapshot.definition.Replace($remoteMatches[0].Value,$replacement)) { throw 'non-location bytes changed' }
foreach ($fragment in @('public.units unit where (p_institution_id is null',
  'where (p_institution_id is null or group_record.institution_id=p_institution_id)',
  'where (p_institution_id is null or membership.institution_id=p_institution_id)')) {
  if (-not $changed.Contains($fragment)) { throw 'remote non-location semantics changed' }
}
if ($changed.Contains("'students'") -or $changed.Contains('public.activity_locations')) { throw 'legacy projection/discovery not closed' }
if ($candidate -notmatch '3167d90039df952c9ae561f28486223c') { throw 'writer EOL proof not pinned' }
$writerSource = [IO.File]::ReadAllText((Join-Path $packageRoot 'migrations/20260811194840_activity_files_identity_commands.sql'))
$writerBody = [regex]::Match($writerSource,'(?is)create or replace function app_private\.superadmin_create_activity_locations\(.*?\bas\s+\$\$(.*?)\$\$;').Groups[1].Value
if ((Get-Md5 $writerBody.Replace("`r`n","`n")) -ne 'ccfc509321ae6d21eafb4082c4e53e58') {
  throw 'canonical writer body no longer equals remotely observed prosrc LF'
}
if ((Get-Md5 ($writerBody.Replace("`r`n","`n") + ' ')) -eq 'ccfc509321ae6d21eafb4082c4e53e58') {
  throw 'non-EOL drift must remain rejected'
}
$cutoverTest = [IO.File]::ReadAllText((Join-Path $packageRoot 'supabase/tests/superadmin_location_remote_options_cutover_test.sql'))
$testSnapshot = ([regex]::Match($cutoverTest,'(?s)\$snapshot\$(.*?)\$snapshot\$').Groups[1].Value | ConvertFrom-Json)
if ($testSnapshot.definition -cne $snapshot.definition) { throw 'TAP snapshot differs from local fixture' }
if ([regex]::Match($cutoverTest,'(?s)\$pattern\$(.*?)\$pattern\$').Groups[1].Value -cne $match.Groups[1].Value) {
  throw 'TAP pattern differs from candidate'
}
if ($candidate -notmatch "(?s)if expected.signature='app_private.superadmin_create_activity_locations\(uuid,uuid\[\],text,uuid\)' then.*?md5\(replace\(actual_definition,E'\\r\\n',E'\\n'\)\).*?elsif md5\(actual_definition\)<>expected.hash then") {
  throw 'EOL normalization must remain scoped to the exact writer'
}
Write-Output 'PASS: exact snapshot bytes, remote1/canonical0, narrow closure, unchanged non-location bytes and writer LF pin; STATIC ONLY, not PostgreSQL regex execution.'
Write-Output ('Post-cutover definition MD5 raw=' + (Get-Md5 $changed) + '; LF=' + (Get-Md5 $changed.Replace("`r`n","`n")))
