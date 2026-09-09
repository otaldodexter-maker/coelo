[CmdletBinding()]
param([string]$TargetVersion = '20260908235110')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ActivityAggregateFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "ActivityAggregateConcurrencyClock input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "ActivityAggregateConcurrencyClock input cannot contain a reparse point: $($cursor.FullName)"
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
    'a1b92a382fcc9f47bbd5c7dc4f3c05a7db679b5ae663ba6b964ca90e745af15c') {
  throw 'ActivityAggregateConcurrencyClock descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "ActivityAggregateConcurrencyClock requires target $($descriptor.target_version); received $TargetVersion"
}
if (@($descriptor.extra_bridges).Count -ne 0) {
  throw 'ActivityAggregateConcurrencyClock requires zero extra bridges'
}

$parentRoot = Join-Path (Split-Path -Parent $PSScriptRoot) $descriptor.parent.id
$parentDescriptor = Assert-ActivityAggregateFile (Join-Path $parentRoot 'profile.json')
if ((Get-ActivityAggregateHash $parentDescriptor.FullName) -cne
    $descriptor.parent.descriptor_sha256_crlf_utf8) {
  throw 'ActivityAggregateConcurrencyClock parent descriptor hash mismatch'
}
$parentResolver = Assert-ActivityAggregateFile (
  Join-Path $parentRoot 'Resolve-ActivityAggregateConcurrency.ps1'
)
if ((Get-ActivityAggregateHash $parentResolver.FullName) -cne
    $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'ActivityAggregateConcurrencyClock parent resolver hash mismatch'
}
$parent = & $parentResolver.FullName -TargetVersion '20260908154257'
if ($parent.Canonical.Count -ne 54 -or $parent.Preflight.Count -ne 2 -or
    ($parent.Canonical.Count + $parent.Preflight.Count) -ne 56) {
  throw 'ActivityAggregateConcurrencyClock requires unchanged ActivityAggregateConcurrency base56'
}

$addition = $descriptor.canonical_addition
if ($addition.file -cnotmatch '^20260908235110_[a-z0-9_]+\.sql$' -or
    $addition.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
  throw 'ActivityAggregateConcurrencyClock addition metadata is invalid'
}
$additionFile = Assert-ActivityAggregateFile (
  Join-Path (Join-Path $packageRoot 'migrations') $addition.file
)
if ((Get-ActivityAggregateHash $additionFile.FullName) -cne $addition.sha256_crlf_utf8) {
  throw "ActivityAggregateConcurrencyClock input hash mismatch: $($addition.file)"
}

$canonical = @($parent.Canonical) + @($additionFile) | Sort-Object Name
$all = @($canonical) + @($parent.Preflight)
$versions = @($all | ForEach-Object {
  if ($_.Name -cnotmatch '^\d{14}_[a-z0-9_]+\.sql$') {
    throw "ActivityAggregateConcurrencyClock input name is invalid: $($_.Name)"
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
  throw 'ActivityAggregateConcurrencyClock requires 55 canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $parent.Preflight
  Additional = @($additionFile)
  ManifestHash = $parent.ManifestHash
}
