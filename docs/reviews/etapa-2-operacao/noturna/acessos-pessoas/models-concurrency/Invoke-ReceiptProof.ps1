[CmdletBinding()]
param([ValidateSet('red','green')][string]$Phase='red')
$ErrorActionPreference='Stop'
$repo=(& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) {throw 'RECEIPT_PROOF_REPOSITORY_REQUIRED'}
$log=Join-Path $PSScriptRoot "$Phase-replay.txt"
Start-Transcript -LiteralPath $log -Force | Out-Null
try {
  & (Join-Path $repo 'packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1') `
    -AuthOnly -TargetVersion '20260901200206' `
    -TestPath (Join-Path $repo 'packages/coelo_database/supabase/tests/ap_models_nominal_package_test.sql') `
    -RunModelReceiptConcurrency
} finally {Stop-Transcript | Out-Null}
