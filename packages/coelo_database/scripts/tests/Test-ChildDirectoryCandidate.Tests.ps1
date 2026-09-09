[CmdletBinding()]
param([switch]$PrintDependencyPins)
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sources = @(
  @('20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql','require_superadmin_internal_context'),
  @('20260827235500_superadmin_internal_institution_list_filter.sql','superadmin_internal_error_envelope'),
  @('20260901124500_harden_superadmin_auth_context_denial_audit.sql','audit_superadmin_internal_denial_if_identified'),
  @('20260827233000_superadmin_internal_auth_context.sql','audit_append_superadmin_internal'),
  @('20260827233000_superadmin_internal_auth_context.sql','audit_append_auth_session_denial')
)
$pins = @($sources | ForEach-Object {
  $source = [IO.File]::ReadAllText((Join-Path $packageRoot ('migrations/' + $_[0]))).Replace("`r`n", "`n")
  $pattern = '(?is)create(?: or replace)? function app_private\.' + [regex]::Escape($_[1]) + '\(.*?\bas\s+\$\$(.*?)\$\$;'
  $matches = [regex]::Matches($source, $pattern)
  if ($matches.Count -ne 1) { throw "ambiguous dependency source: $($_[1])" }
  $digest = [Security.Cryptography.MD5]::Create()
  try { $hash = ([BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($matches[0].Groups[1].Value)))).Replace('-','').ToLowerInvariant() }
  finally { $digest.Dispose() }
  [pscustomobject]@{ Name = $_[1]; Source = $_[0]; Md5SourceLF = $hash }
})
if ($PrintDependencyPins) { $pins | Format-List; return }
$candidatePath = Join-Path $packageRoot 'migrations/20260908051500_superadmin_child_context_directory_v2.sql'
if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) { throw 'child candidate missing' }
$candidate = [IO.File]::ReadAllText($candidatePath).Replace("`r`n", "`n")
foreach ($pin in $pins) { if (-not $candidate.Contains($pin.Md5SourceLF)) { throw "dependency pin drift: $($pin.Name)" } }
$checks = [ordered]@{
  'one nominal public gateway' = '(?s)create function public\.superadmin_child_context_directory_v2\(\s*p_institution_id uuid default null,\s*p_after_name text default null,\s*p_after_context_id uuid default null,\s*p_limit integer default 20'
  'bounded request' = 'p_limit is null or p_limit < 1 or p_limit > 50'
  'paired cursor' = '\(p_after_name is null\) <> \(p_after_context_id is null\)'
  'UTF8 transport budget' = 'octet_length\(p_after_name\) > 8192'
  'server keyset collation' = 'lower\(p.display_name\) collate "C"'
  'authorized child context' = "cc.status = 'active' and p.person_type = 'child'"
  'soft deletion enforced' = 'p.deleted_at is null and i.deleted_at is null'
  'institution filter restricts' = 'effective_institution_id is null or cc.institution_id = effective_institution_id'
  'row locks' = 'for share of cc, p, i'
  'minimal item' = "(?s)'context_id', row_record.id, 'person_id', row_record.child_person_id,\s*'person_name', row_record.display_name, 'institution_id', row_record.institution_id,\s*'institution_name', row_record.public_name"
  'audit13 and no payload' = "(?s)perform app_private.audit_append_superadmin_internal\(.*?'child_context_catalog', null\);"
  'negative audit distrusts filter' = "'people.read', 'child_context.directory', error_code, correlation_id, null\);"
  'return after audit' = "(?s)'child_context_catalog', null\);.*?return jsonb_build_object"
  'wall clock session guard' = 's.not_after > clock_timestamp\(\)'
  'body fingerprint preflight' = "md5\(replace\(function_record.prosrc, E'\\r\\n', E'\\n'\)\)"
}
foreach ($check in $checks.GetEnumerator()) {
  if ($candidate -notmatch $check.Value) { throw "child static contract failed: $($check.Key)" }
}
if ([regex]::Matches($candidate, 'create function ').Count -ne 1) { throw 'unexpected helper surface' }
if ([regex]::Matches($candidate, "from app_private.require_superadmin_internal_context\('people.read'\)").Count -lt 3) {
  throw 'authorization must be revalidated after locks and before audit'
}
if ($candidate -match '(?i)insert into public.platform_|audit14|activity_v2|child_unit_links|child_group_links|total_count|local_identifier') {
  throw 'unexpected dependency or projection expansion'
}
Write-Output "PASS: $($checks.Count) child source contracts plus surface/revalidation guards; STATIC ONLY, SQL NOT EXECUTED."
