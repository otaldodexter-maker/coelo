[CmdletBinding()]
param([string]$TargetVersion = '20260909210000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ConsumerFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "StructureLocationConsumersV1 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "StructureLocationConsumersV1 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  $item
}

function Get-ConsumerHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

$descriptorFile = Assert-ConsumerFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-ConsumerHash $descriptorFile.FullName) -cne '567d00d3fb2e509f3868d6870de227b59e6fd28671c7994435338abc49450cdb') {
  throw 'StructureLocationConsumersV1 descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "StructureLocationConsumersV1 requires target 20260909210000; received $TargetVersion"
}
if (@($descriptor.extra_bridges).Count -ne 0) {
  throw 'StructureLocationConsumersV1 does not permit extra bridges'
}

$profilesRoot = Split-Path -Parent $PSScriptRoot
$parentRoot = Join-Path $profilesRoot $descriptor.parent.id
$parentDescriptor = Assert-ConsumerFile (Join-Path $parentRoot 'profile.json')
$parentResolver = Assert-ConsumerFile (Join-Path $parentRoot 'Resolve-LocationReservationsV1.ps1')
if ((Get-ConsumerHash $parentDescriptor.FullName) -cne $descriptor.parent.descriptor_sha256_crlf_utf8 -or
    (Get-ConsumerHash $parentResolver.FullName) -cne $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'StructureLocationConsumersV1 parent hash mismatch'
}
$parent = & $parentResolver.FullName

$companionRoot = Join-Path $profilesRoot $descriptor.companion.id
$companionDescriptor = Assert-ConsumerFile (Join-Path $companionRoot 'profile.json')
$companionResolver = Assert-ConsumerFile (
  Join-Path $companionRoot 'Resolve-ActivityAggregateConcurrencyClock.ps1')
if ((Get-ConsumerHash $companionDescriptor.FullName) -cne $descriptor.companion.descriptor_sha256_crlf_utf8 -or
    (Get-ConsumerHash $companionResolver.FullName) -cne $descriptor.companion.resolver_sha256_crlf_utf8) {
  throw 'StructureLocationConsumersV1 companion hash mismatch'
}
$companion = & $companionResolver.FullName
if (@($companion.Preflight).Count -ne @($parent.Preflight).Count) {
  throw 'StructureLocationConsumersV1 requires both selections to share the reviewed preflights'
}
foreach ($index in 0..(@($parent.Preflight).Count - 1)) {
  if ($companion.Preflight[$index].Name -cne $parent.Preflight[$index].Name) {
    throw 'StructureLocationConsumersV1 preflight selections diverge'
  }
}
$union = @(@($parent.Canonical) + @($companion.Canonical) | Sort-Object Name -Unique)
if (@($companion.Canonical).Count -ne $descriptor.planned_counts.companion_canonical -or
    $union.Count -ne $descriptor.planned_counts.union_canonical) {
  throw 'StructureLocationConsumersV1 canonical union contract mismatch'
}

$additions = @($descriptor.canonical_additions | ForEach-Object {
  if ($_.file -cne [IO.Path]::GetFileName($_.file) -or
      $_.file -notmatch '^\d{14}_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'StructureLocationConsumersV1 addition is invalid'
  }
  $file = Assert-ConsumerFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-ConsumerHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "StructureLocationConsumersV1 input hash mismatch: $($_.file)"
  }
  $file
})

$canonical = @(@($union) + $additions | Sort-Object Name -Unique)
if (@($parent.Canonical).Count -ne $descriptor.planned_counts.parent_canonical -or
    @($parent.Preflight).Count -ne 2 -or
    @($parent.LocationBootstrap).Count -ne 3 -or $additions.Count -ne 3 -or
    $canonical.Count -ne $descriptor.planned_counts.canonical -or
    @($parent.Preflight).Count -ne $descriptor.planned_counts.preflight -or
    @($parent.LocationBootstrap).Count -ne $descriptor.planned_counts.bootstrap -or
    ($canonical.Count + @($parent.Preflight).Count + @($parent.LocationBootstrap).Count) -ne $descriptor.planned_counts.total -or
    $canonical[-1].BaseName.Substring(0,14) -cne $TargetVersion) {
  throw 'StructureLocationConsumersV1 selection contract mismatch'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $parent.Preflight
  Additional = $additions
  ManifestHash = $parent.ManifestHash
  FormsDefinitionMaterialization = $parent.FormsDefinitionMaterialization
  LocationBootstrap = $parent.LocationBootstrap
  ReservationBootstrap = $parent.ReservationBootstrap
}
