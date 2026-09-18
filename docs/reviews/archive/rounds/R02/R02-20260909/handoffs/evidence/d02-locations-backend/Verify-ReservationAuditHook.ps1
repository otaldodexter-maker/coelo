param([Parameter(Mandatory = $true)][string]$CandidatePath)
$ErrorActionPreference = 'Stop'
$candidate = (Resolve-Path -LiteralPath $CandidatePath).Path
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($candidate, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -ne 0) { throw ($parseErrors | Out-String) }
$guard = @($ast.FindAll({ param($node)
  $node -is [Management.Automation.Language.IfStatementAst] -and
  $node.Extent.Text.StartsWith('if ($RunLocationReservationsAuditAuthorization -and (')
}, $true))
if ($guard.Count -ne 1) { throw 'Expected exactly one nominal audit proof guard' }
# Evaluate the actual reviewed parameter block and guard only. No wrapper setup,
# Docker, CLI, mutex, temporary database or SQL is reachable in this probe.
$probe = [scriptblock]::Create($ast.ParamBlock.Extent.Text + "`n" + $guard[0].Extent.Text + "`n'accepted'")
$valid = @{
  TargetVersion = '20260909165000'
  NominalProfile = 'LocationReservationsV1'
  RunLocationReservationsAuditAuthorization = $true
}
if ((& $probe @valid) -cne 'accepted') { throw 'Exact nominal pair was rejected' }
$cases = @(
  @{ NominalProfile = 'LocationCatalogV2' },
  @{ TargetVersion = '20260908190650' },
  @{ NominalProfile = $null },
  @{ FoundationOnly = $true },
  @{ AuthOnly = $true },
  @{ AdditionalMigration = @('20260909165000_superadmin_location_reservations_v2.sql') },
  @{ RunAuthLifecycle = $true },
  @{ RunAuthRecoveryBoundary = $true },
  @{ AssertAuthRecoveryConfined = $true },
  @{ RunR02AuthProofConcurrency = $true },
  @{ RunChildDirectoryConcurrency = $true },
  @{ RunChildDirectoryHttp = $true },
  @{ RunActivityV2Concurrency = $true },
  @{ RunLint = $true }
)
foreach ($case in $cases) {
  $arguments = $valid.Clone()
  foreach ($key in $case.Keys) {
    if ($null -eq $case[$key]) { $arguments.Remove($key) }
    else { $arguments[$key] = $case[$key] }
  }
  $rejected = $false
  try { $null = & $probe @arguments }
  catch {
    if ($_.Exception.Message -notlike 'Location reservation audit proof requires exact*') { throw }
    $rejected = $true
  }
  if (-not $rejected) { throw ('Unsafe combination accepted: ' + ($case.Keys -join ',')) }
}
"PASS: exact pair accepted, $($cases.Count) incompatible combinations denied; full candidate parses; no SQL/resources executed."
