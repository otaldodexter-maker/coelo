[CmdletBinding()]
param([string]$TargetVersion = '20260908045531')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-AgendaGreenFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "AgendaReadContractGreen input is missing: $Path" }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "AgendaReadContractGreen input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}
function Get-AgendaGreenHash([string]$Path) {
  $text = [IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n").Replace("`n","`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($text)))).Replace('-','').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed inheritance: original RED53, its pins and all SQL bytes remain unchanged.
$descriptorFile = Assert-AgendaGreenFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-AgendaGreenHash $descriptorFile.FullName) -cne 'ec71fcca12d79b8e89051bf4f9e2f63f99bca17c0517d5ca9a4a7c4cd30c9051') {
  throw 'AgendaReadContractGreen descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "AgendaReadContractGreen requires target 20260908045531; received $TargetVersion"
}
$parentFile = Assert-AgendaGreenFile (Join-Path $packageRoot 'replay\profiles\AgendaReadContractRed\Resolve-AgendaReadContractRed.ps1')
$parentDescriptor = Assert-AgendaGreenFile (Join-Path $packageRoot 'replay\profiles\AgendaReadContractRed\profile.json')
if ((Get-AgendaGreenHash $parentFile.FullName) -cne $descriptor.base.resolver_sha256_crlf_utf8 -or
    (Get-AgendaGreenHash $parentDescriptor.FullName) -cne $descriptor.base.descriptor_sha256_crlf_utf8) {
  throw 'AgendaReadContractGreen parent pin mismatch'
}
# Both parent files and their ancestor chains have been checked before invocation.
$parentOutput = @(& $parentFile.FullName -TargetVersion '20260901200206')
if ($parentOutput.Count -ne 1) { throw 'AgendaReadContractGreen parent selection cardinality mismatch' }
$parent = $parentOutput[0]
if (@($parent.Canonical).Count -ne 51 -or @($parent.Preflight).Count -ne 2 -or
    @($parent.Additional).Count -ne 6 -or
    $parent.ManifestHash -cne $descriptor.base.manifest_sha256_crlf_utf8 -or
    @($descriptor.extra_bridges).Count -ne 0) {
  throw 'AgendaReadContractGreen requires its exact RED53 parent and zero extra bridges'
}
$candidate = Assert-AgendaGreenFile (Join-Path $packageRoot 'migrations\20260908045531_superadmin_agenda_read_v2.sql')
if ($candidate.Name -cne $descriptor.canonical_addition.file -or
    (Get-AgendaGreenHash $candidate.FullName) -cne $descriptor.canonical_addition.sha256_crlf_utf8) {
  throw 'AgendaReadContractGreen candidate hash mismatch'
}
$canonical = @(@($parent.Canonical) + @($candidate) | Sort-Object Name)
$preflight = @($parent.Preflight)
$additional = @(@($parent.Additional) + @($candidate) | Sort-Object Name)
$combined = @(@($canonical) + @($preflight) | Sort-Object Name)
$versions = @($combined | ForEach-Object {
  if ($_ -isnot [IO.FileInfo] -or $_.Name -cnotmatch '^\d{14}_[a-z0-9_]+\.sql$') {
    throw 'AgendaReadContractGreen returned an invalid migration'
  }
  $_.Name.Substring(0,14)
})
if ($canonical.Count -ne 52 -or $preflight.Count -ne 2 -or $additional.Count -ne 7 -or
    $combined.Count -ne 54 -or @($versions | Sort-Object -Unique).Count -ne 54 -or
    $versions[-1] -cne $TargetVersion -or
    $canonical[$descriptor.canonical_addition.canonical_union_position - 1].FullName -cne $candidate.FullName -or
    $combined[$descriptor.canonical_addition.replay_union_position - 1].FullName -cne $candidate.FullName) {
  throw 'AgendaReadContractGreen requires 52 canonical, two preflight and seven additional inputs, total54'
}
[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = $additional
  ManifestHash = $parent.ManifestHash
}
