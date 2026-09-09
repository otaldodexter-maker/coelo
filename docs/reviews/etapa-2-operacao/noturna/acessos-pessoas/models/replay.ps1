# Local only; requires the coordinator's SQL slot. Existing runner owns cleanup.
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
while (-not (Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md'))) {
  $repo = Split-Path -Parent $repo
  if (-not $repo) { throw 'repository root not found' }
}
Set-Location -LiteralPath $repo
$tests = @(
  'ap_models_nominal_package_test.sql',
  'access_profile_models_aal1_phase_policy_test.sql',
  'access_profile_models_read_authorization_test.sql',
  'access_profile_models_read_helper_acl_test.sql',
  'access_profile_models_read_prelookup_regression_test.sql',
  'd04_access_models_scope_filter_test.sql'
) | ForEach-Object { Join-Path 'packages/coelo_database/supabase/tests' $_ }
& ./packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -TargetVersion 20260901200206 -AuthOnly -TestPath $tests
