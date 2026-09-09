param([Parameter(Mandatory=$true)][string]$WrapperPath)

# Execute the actual leading statements only. The first nominal resolver is
# the offline boundary: no port, mutex, Docker, npx or replay may be reached.
$source = [IO.File]::ReadAllText($WrapperPath)
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'wrapper parsing failed' }
$boundary=@($ast.EndBlock.Statements | Where-Object {
  $_ -is [Management.Automation.Language.IfStatementAst] -and
  $_.Clauses[0].Item1.Extent.Text -eq '$NominalProfile'
})[0]
if ($null -eq $boundary) { throw 'offline nominal boundary not found' }
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('coelo_wrapper_guards_'+[guid]::NewGuid().ToString('N'))
$fixtureScripts=Join-Path $fixtureRoot 'packages\coelo_database\scripts'
$fixtureMigrations=Join-Path $fixtureRoot 'packages\coelo_database\migrations'
$null=New-Item -ItemType Directory -Path $fixtureScripts,$fixtureMigrations
foreach($version in @('20260901200206','20260908051500','20260908235110')) {
  [IO.File]::WriteAllText((Join-Path $fixtureMigrations ($version+'_offline_placeholder.sql')),'-- Never executed; target identity for guard tests only.')
}
$guardWrapper=Join-Path $fixtureScripts 'Invoke-OfflineGuards.ps1'
[IO.File]::WriteAllText($guardWrapper, $source.Substring(0,$boundary.Extent.StartOffset)+"`nthrow 'OFFLINE_GUARDS_ACCEPTED'`n")
$boundaryError='Auth recovery boundary requires Auth-only and excludes lifecycle and concurrency profiles'
$assertError='Auth recovery confinement assertions require the focal recovery boundary runner'

Describe 'R02 joint replay wrapper offline guard behavior' {
  It '<name>' -TestCases @(
    @{name='rejects Boundary without AuthOnly'; flags=@{RunAuthRecoveryBoundary=$true}; expected=$boundaryError}
    @{name='rejects Boundary plus CHILD'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;RunChildDirectoryConcurrency=$true}; expected=$boundaryError}
    @{name='rejects Boundary plus Auth proof'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;RunR02AuthProofConcurrency=$true}; expected=$boundaryError}
    @{name='rejects Boundary plus lifecycle'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;RunAuthLifecycle=$true}; expected=$boundaryError}
    @{name='rejects Boundary plus Clock'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;RunActivityV2Concurrency=$true;NominalProfile='ActivityAggregateConcurrencyClock'}; expected=$boundaryError}
    @{name='rejects Boundary plus Foundation'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;FoundationOnly=$true}; expected=$boundaryError}
    @{name='rejects Boundary plus Location'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;NominalProfile='LocationCatalogV2'}; expected=$boundaryError}
    @{name='rejects Assert without Boundary'; flags=@{AssertAuthRecoveryConfined=$true}; expected=$assertError}
    @{name='rejects Assert with CHILD'; flags=@{AssertAuthRecoveryConfined=$true;RunChildDirectoryConcurrency=$true;NominalProfile='ChildDirectoryEnvelope'}; expected=$assertError}
    @{name='rejects Assert with Clock'; flags=@{AssertAuthRecoveryConfined=$true;RunActivityV2Concurrency=$true;NominalProfile='ActivityAggregateConcurrencyClock'}; expected=$assertError}
    @{name='rejects Assert with Auth proof'; flags=@{AssertAuthRecoveryConfined=$true;AuthOnly=$true;RunAuthLifecycle=$true;RunR02AuthProofConcurrency=$true}; expected=$assertError}
    @{name='accepts focal Boundary guards only'; flags=@{AuthOnly=$true;RunAuthRecoveryBoundary=$true;AssertAuthRecoveryConfined=$true}; expected='OFFLINE_GUARDS_ACCEPTED'}
    @{name='accepts existing Auth proof guards only'; flags=@{AuthOnly=$true;RunAuthLifecycle=$true;RunR02AuthProofConcurrency=$true}; expected='OFFLINE_GUARDS_ACCEPTED'}
    @{name='accepts existing CHILD guards only'; version='20260908051500';flags=@{RunChildDirectoryConcurrency=$true;NominalProfile='ChildDirectoryEnvelope'}; expected='OFFLINE_GUARDS_ACCEPTED'}
    @{name='accepts existing Clock guards only'; version='20260908235110';flags=@{RunActivityV2Concurrency=$true;NominalProfile='ActivityAggregateConcurrencyClock'}; expected='OFFLINE_GUARDS_ACCEPTED'}
  ) {
    param($name,$flags,$expected,$version)
    if (-not $version) { $version='20260901200206' }
    $actual=$null
    try { & $guardWrapper -TargetVersion $version @flags } catch { $actual=$_.Exception.Message }
    $actual | Should Be $expected
  }
}
# Retained exclusive TEMP fixture contains only this source prefix and comments.
Write-Output "Offline fixture retained: $fixtureRoot"
