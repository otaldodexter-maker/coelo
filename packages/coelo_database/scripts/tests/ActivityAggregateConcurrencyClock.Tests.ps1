$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$resolver = Join-Path $packageRoot 'replay\profiles\ActivityAggregateConcurrencyClock\Resolve-ActivityAggregateConcurrencyClock.ps1'

Describe 'ActivityAggregateConcurrencyClock closed successor' {
  It 'adds only the already integrated clock to the unchanged historical56' {
    $result = & $resolver
    $parent = & (Join-Path $packageRoot 'replay\profiles\ActivityAggregateConcurrency\Resolve-ActivityAggregateConcurrency.ps1')
    @($result.Canonical).Count | Should Be 55
    @($result.Preflight).Count | Should Be 2
    @($result.Additional).Count | Should Be 1
    $result.Canonical[-1].Name | Should Be '20260908235110_superadmin_activity_link_end_clock_v1.sql'
    $result.Canonical[-2].Name | Should Be '20260908154257_superadmin_activity_save_v2.sql'
    @(Compare-Object @($parent.Canonical.Name) @($result.Canonical[0..53].Name)).Count | Should Be 0
    @(Compare-Object @($parent.Preflight.Name) @($result.Preflight.Name)).Count | Should Be 0
    @($result.Canonical.Name | Sort-Object -Unique).Count | Should Be 55
  }

  It 'rejects the historical target instead of silently broadening it' {
    { & $resolver -TargetVersion '20260908154257' } |
      Should Throw 'ActivityAggregateConcurrencyClock requires target 20260908235110'
  }

  It 'pins the exact existing clock bytes with declared CRLF UTF8 normalization' {
    $source = Join-Path $packageRoot 'migrations\20260908235110_superadmin_activity_link_end_clock_v1.sql'
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
      [IO.File]::ReadAllText($source).Replace("`r`n","`n").Replace("`r","`n").Replace("`n","`r`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
    $hash | Should Be 'be66e47436dfaf61bc3655fa5c1bedbeb88725077912e5c8fb28155bbcb7b069'
  }
}
