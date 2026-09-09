[CmdletBinding()]
param([string]$TargetVersion = '20260909165000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ReservationFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "LocationReservationsV1 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "LocationReservationsV1 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  $item
}

function Get-ReservationHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

$descriptorFile = Assert-ReservationFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-ReservationHash $descriptorFile.FullName) -cne '611fde347e1324b90c9d8af438ef062f2ec19aa25e74e330d0e11caec1401f85') {
  throw 'LocationReservationsV1 descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "LocationReservationsV1 requires target 20260909165000; received $TargetVersion"
}
if (@($descriptor.extra_bridges).Count -ne 0) {
  throw 'LocationReservationsV1 does not permit extra bridges'
}

$profilesRoot = Split-Path -Parent $PSScriptRoot
$parentRoot = Join-Path $profilesRoot $descriptor.parent.id
$parentDescriptor = Assert-ReservationFile (Join-Path $parentRoot 'profile.json')
$parentResolver = Assert-ReservationFile (Join-Path $parentRoot 'Resolve-LocationCatalogV2.ps1')
if ((Get-ReservationHash $parentDescriptor.FullName) -cne $descriptor.parent.descriptor_sha256_crlf_utf8 -or
    (Get-ReservationHash $parentResolver.FullName) -cne $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'LocationReservationsV1 parent hash mismatch'
}
$parent = & $parentResolver.FullName

$additions = @($descriptor.canonical_additions | ForEach-Object {
  if ($_.file -cne [IO.Path]::GetFileName($_.file) -or
      $_.file -notmatch '^\d{14}_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'LocationReservationsV1 addition is invalid'
  }
  $file = Assert-ReservationFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-ReservationHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "LocationReservationsV1 input hash mismatch: $($_.file)"
  }
  $file
})
$bootstrapSpec = $descriptor.reservation_bootstrap
if ($bootstrapSpec.file -cne [IO.Path]::GetFileName($bootstrapSpec.file) -or
    $bootstrapSpec.file -notmatch '^\d{14}_[a-z0-9_]+\.sql$' -or
    $bootstrapSpec.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
  throw 'LocationReservationsV1 bootstrap descriptor is invalid'
}
$reservationBootstrap = Assert-ReservationFile (
  Join-Path (Join-Path $packageRoot 'tests\fixtures') $bootstrapSpec.file)
if ((Get-ReservationHash $reservationBootstrap.FullName) -cne $bootstrapSpec.sha256_crlf_utf8) {
  throw 'LocationReservationsV1 bootstrap hash mismatch'
}

$canonical = @(@($parent.Canonical) + $additions | Sort-Object Name -Unique)
$bootstraps = @(@($parent.LocationBootstrap) + $reservationBootstrap | Sort-Object Name)
if (@($parent.Canonical).Count -ne 53 -or @($parent.Preflight).Count -ne 2 -or
    @($parent.LocationBootstrap).Count -ne 2 -or $additions.Count -ne 6 -or
    $canonical.Count -ne $descriptor.planned_counts.canonical -or
    @($parent.Preflight).Count -ne $descriptor.planned_counts.preflight -or
    $bootstraps.Count -ne $descriptor.planned_counts.bootstrap -or
    ($canonical.Count + @($parent.Preflight).Count + $bootstraps.Count) -ne $descriptor.planned_counts.total -or
    $canonical[-1].BaseName.Substring(0,14) -cne $TargetVersion -or
    $bootstrapSpec.before -cne $additions[-1].Name) {
  throw 'LocationReservationsV1 selection contract mismatch'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $parent.Preflight
  Additional = $additions
  ManifestHash = $parent.ManifestHash
  FormsDefinitionMaterialization = $parent.FormsDefinitionMaterialization
  LocationBootstrap = $bootstraps
  ReservationBootstrap = $reservationBootstrap
}
