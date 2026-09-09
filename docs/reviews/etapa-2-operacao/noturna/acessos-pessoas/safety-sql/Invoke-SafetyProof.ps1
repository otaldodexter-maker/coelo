# Local only. Run after the coordinator's serialized Models/Safety sequence.
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
while (-not (Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md'))) {
  $repo = Split-Path -Parent $repo
  if (-not $repo) { throw 'Safety proof repository root not found' }
}
Set-Location -LiteralPath $repo
$tests = @(
  'ap_safety_internal_preflight_test.sql',
  'd04_child_safety_internal_reads_test.sql',
  'child_safety_production_test.sql'
) | ForEach-Object { Join-Path 'packages/coelo_database/supabase/tests' $_ }
& ./packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260909193000 -NominalProfile SafetyInternalReads53 -TestPath $tests
