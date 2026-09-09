[CmdletBinding()]
param([string]$TargetVersion = '20260908154257')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ActivityAggregateFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "ActivityAggregateConcurrency input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "ActivityAggregateConcurrency input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-ActivityAggregateHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

$descriptorFile = Assert-ActivityAggregateFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-ActivityAggregateHash $descriptorFile.FullName) -cne
    '4c836eb765c726c6cbcac342314230856df4b5611e82e085a2ff1f14e3690450') {
  throw 'ActivityAggregateConcurrency descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "ActivityAggregateConcurrency requires target $($descriptor.target_version); received $TargetVersion"
}
if (@($descriptor.extra_bridges).Count -ne 0) {
  throw 'ActivityAggregateConcurrency requires zero extra bridges'
}

$parentRoot = Join-Path (Split-Path -Parent $PSScriptRoot) $descriptor.parent.id
$parentDescriptor = Assert-ActivityAggregateFile (Join-Path $parentRoot 'profile.json')
if ((Get-ActivityAggregateHash $parentDescriptor.FullName) -cne
    $descriptor.parent.descriptor_sha256_crlf_utf8) {
  throw 'ActivityAggregateConcurrency parent descriptor hash mismatch'
}
$parentResolver = Assert-ActivityAggregateFile (
  Join-Path $parentRoot 'Resolve-A01DirectoryAuditGreen.ps1'
)
if ((Get-ActivityAggregateHash $parentResolver.FullName) -cne
    $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'ActivityAggregateConcurrency parent resolver hash mismatch'
}
$parent = & $parentResolver.FullName -TargetVersion '20260907222911'
if ($parent.Canonical.Count -ne 53 -or $parent.Preflight.Count -ne 2 -or
    ($parent.Canonical.Count + $parent.Preflight.Count) -ne 55) {
  throw 'ActivityAggregateConcurrency requires unchanged A01DirectoryAuditGreen base55'
}

$addition = $descriptor.canonical_addition
if ($addition.file -cnotmatch '^20260908154257_[a-z0-9_]+\.sql$' -or
    $addition.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
  throw 'ActivityAggregateConcurrency addition metadata is invalid'
}
$additionFile = Assert-ActivityAggregateFile (
  Join-Path (Join-Path $packageRoot 'migrations') $addition.file
)
if ((Get-ActivityAggregateHash $additionFile.FullName) -cne $addition.sha256_crlf_utf8) {
  throw "ActivityAggregateConcurrency input hash mismatch: $($addition.file)"
}

$canonical = @($parent.Canonical) + @($additionFile) | Sort-Object Name
$all = @($canonical) + @($parent.Preflight)
$versions = @($all | ForEach-Object {
  if ($_.Name -cnotmatch '^\d{14}_[a-z0-9_]+\.sql$') {
    throw "ActivityAggregateConcurrency input name is invalid: $($_.Name)"
  }
  $_.Name.Substring(0, 14)
})
$position = [Array]::IndexOf([object[]]@($canonical.Name), [object]$addition.file) + 1
if ($canonical.Count -ne $descriptor.planned_counts.canonical -or
    $parent.Preflight.Count -ne $descriptor.planned_counts.preflight -or
    $all.Count -ne $descriptor.planned_counts.total -or
    @($versions | Sort-Object -Unique).Count -ne $all.Count -or
    ($versions | Sort-Object)[-1] -cne $descriptor.target_version -or
    $position -ne $addition.canonical_union_position) {
  throw 'ActivityAggregateConcurrency requires 54 canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $parent.Preflight
  Additional = @($additionFile)
  ManifestHash = $parent.ManifestHash
}
