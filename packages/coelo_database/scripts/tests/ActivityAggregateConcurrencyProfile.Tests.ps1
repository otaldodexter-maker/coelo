$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$profileRoot = Join-Path $packageRoot 'replay\profiles\ActivityAggregateConcurrency'
$descriptorPath = Join-Path $profileRoot 'profile.json'
$resolverPath = Join-Path $profileRoot 'Resolve-ActivityAggregateConcurrency.ps1'
$descriptor = [IO.File]::ReadAllText($descriptorPath) | ConvertFrom-Json

function Get-NormalizedReplayHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed ActivityAggregateConcurrency replay selector' {
  It 'derives base55 and adds only the current aggregate migration' {
    $result = & $resolverPath -TargetVersion '20260908154257'

    @($result.Canonical).Count | Should Be 54
    @($result.Preflight).Count | Should Be 2
    (@($result.Canonical).Count + @($result.Preflight).Count) | Should Be 56
    @($result.Additional).Count | Should Be 1
    $result.Additional[0].Name | Should Be '20260908154257_superadmin_activity_save_v2.sql'
    $result.Canonical[-1].Name | Should Be '20260908154257_superadmin_activity_save_v2.sql'
    @($result.Canonical.Name | Sort-Object -Unique).Count | Should Be 54
    @($result.Preflight.Name | Sort-Object -Unique).Count | Should Be 2
  }

  It 'pins the aggregate and both parent artifacts by normalized hash' {
    $parentRoot = Join-Path $packageRoot 'replay\profiles\A01DirectoryAuditGreen'
    $aggregatePath = Join-Path $packageRoot 'migrations\20260908154257_superadmin_activity_save_v2.sql'

    (Get-NormalizedReplayHash $aggregatePath) |
      Should Be $descriptor.canonical_addition.sha256_crlf_utf8
    (Get-NormalizedReplayHash (Join-Path $parentRoot 'profile.json')) |
      Should Be $descriptor.parent.descriptor_sha256_crlf_utf8
    (Get-NormalizedReplayHash (Join-Path $parentRoot 'Resolve-A01DirectoryAuditGreen.ps1')) |
      Should Be $descriptor.parent.resolver_sha256_crlf_utf8
    @($descriptor.extra_bridges).Count | Should Be 0
  }

  It 'rejects every target except the aggregate migration' {
    { & $resolverPath -TargetVersion '20260907222911' } |
      Should Throw 'ActivityAggregateConcurrency requires target 20260908154257; received 20260907222911'
  }
}
