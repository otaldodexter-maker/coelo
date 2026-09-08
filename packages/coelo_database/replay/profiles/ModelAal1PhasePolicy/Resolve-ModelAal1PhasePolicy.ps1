[CmdletBinding()]
param([string]$TargetVersion = '20260908182839')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ModelAal1File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "ModelAal1PhasePolicy input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "ModelAal1PhasePolicy input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-ModelAal1Hash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local extension: reuse the reviewed Auth45 + Models3 + preflights2
# selector unchanged, adding only this exact phase-policy candidate. This is
# neither a generic extension mechanism nor a runtime/remote authorization.
if ($TargetVersion -cne '20260908182839') {
  throw "ModelAal1PhasePolicy requires target 20260908182839; received $TargetVersion"
}
$baseResolver = Assert-ModelAal1File (Join-Path $packageRoot 'replay\profiles\ModelReadAuthorizationGreen\Resolve-ModelReadAuthorizationGreen.ps1')
$baseProfile = & $baseResolver.FullName -TargetVersion '20260908021821'
if (@($baseProfile.Canonical).Count -ne 48 -or
    @($baseProfile.Preflight).Count -ne 2 -or
    @($baseProfile.Additional).Count -ne 3) {
  throw 'ModelAal1PhasePolicy requires the unchanged Model READ profile with 50 inputs'
}
$candidateName = '20260908182839_access_profile_models_aal1_phase_policy.sql'
$candidate = Assert-ModelAal1File (Join-Path (Join-Path $packageRoot 'migrations') $candidateName)
if ((Get-ModelAal1Hash $candidate.FullName) -cne 'b88a0f82ba07f21eba60171c681852910a55327ff5adf147742f402032143833') {
  throw "ModelAal1PhasePolicy input hash mismatch: $candidateName"
}
$canonical = @(@($baseProfile.Canonical) + @($candidate) | Sort-Object Name)
$allInputs = @($canonical) + @($baseProfile.Preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 49 -or $allInputs.Count -ne 51 -or
    @($versions | Sort-Object -Unique).Count -ne 51 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'ModelAal1PhasePolicy requires 49 unique canonical migrations and two inherited preflights'
}
[pscustomobject]@{
  Canonical = $canonical
  Preflight = @($baseProfile.Preflight)
  Additional = @($baseProfile.Additional) + @($candidate)
  ManifestHash = $baseProfile.ManifestHash
}
