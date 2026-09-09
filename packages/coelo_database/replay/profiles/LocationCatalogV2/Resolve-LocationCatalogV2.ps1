[CmdletBinding()]
param([string]$TargetVersion = '20260908190650')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-LocationFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "LocationCatalogV2 input is missing: $Path" }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "LocationCatalogV2 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  $item
}

function Get-LocationHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n").Replace("`n","`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

$descriptorFile = Assert-LocationFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-LocationHash $descriptorFile.FullName) -cne 'c46f836935e8f77125bca34f3ef643f4eeb477a9c4fb327479d43519e5da850b') { throw 'LocationCatalogV2 descriptor hash mismatch' }
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) { throw "LocationCatalogV2 requires target 20260908190650; received $TargetVersion" }
if (@($descriptor.extra_bridges).Count -ne 0) { throw 'LocationCatalogV2 does not permit extra bridges' }

$profilesRoot = Split-Path -Parent $PSScriptRoot
$parentRoot = Join-Path $profilesRoot $descriptor.parent.id
$parentDescriptor = Assert-LocationFile (Join-Path $parentRoot 'profile.json')
$parentResolver = Assert-LocationFile (Join-Path $parentRoot 'Resolve-FReadDirectoryContractGreenDerived.ps1')
if ((Get-LocationHash $parentDescriptor.FullName) -cne $descriptor.parent.descriptor_sha256_crlf_utf8 -or
    (Get-LocationHash $parentResolver.FullName) -cne $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'LocationCatalogV2 parent hash mismatch'
}
$parent = & $parentResolver.FullName
$additions = @($descriptor.canonical_additions | ForEach-Object {
  if ($_.file -cne [IO.Path]::GetFileName($_.file) -or $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'LocationCatalogV2 addition is invalid'
  }
  $file = Assert-LocationFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-LocationHash $file.FullName) -cne $_.sha256_crlf_utf8) { throw "LocationCatalogV2 input hash mismatch: $($_.file)" }
  $file
})
$bootstrapSpecs = @($descriptor.location_bootstraps)
$bootstraps = @($bootstrapSpecs | ForEach-Object {
  if ($_.file -cne [IO.Path]::GetFileName($_.file) -or
      $_.file -notmatch '^\d{14}_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'LocationCatalogV2 bootstrap descriptor is invalid'
  }
  $file = Assert-LocationFile (Join-Path (Join-Path $packageRoot 'tests\fixtures') $_.file)
  if ((Get-LocationHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "LocationCatalogV2 bootstrap hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$canonical = @($parent.Canonical) + $additions
if ($parent.Canonical.Count -ne 49 -or $parent.Preflight.Count -ne 2 -or
    $canonical.Count -ne $descriptor.planned_counts.canonical -or
    $parent.Preflight.Count -ne $descriptor.planned_counts.preflight -or
    $bootstraps.Count -ne $descriptor.planned_counts.bootstrap -or
    ($canonical.Count + $parent.Preflight.Count + $bootstraps.Count) -ne $descriptor.planned_counts.total -or
    $additions[-1].BaseName.Substring(0,14) -cne $TargetVersion -or
    $bootstrapSpecs.Count -ne 2 -or
    $bootstrapSpecs[0].before -cne $bootstrapSpecs[1].file -or
    $bootstrapSpecs[1].before -cne $additions[0].Name) {
  throw 'LocationCatalogV2 selection contract mismatch'
}
[pscustomobject]@{
  Canonical = $canonical
  Preflight = $parent.Preflight
  Additional = $additions
  ManifestHash = $parent.ManifestHash
  FormsDefinitionMaterialization = $parent.FormsDefinitionMaterialization
  LocationBootstrap = $bootstraps
}
