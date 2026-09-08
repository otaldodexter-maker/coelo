[CmdletBinding()]
param([string]$TargetVersion = '20260908031000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-LocationFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "LocationCatalogV2 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "LocationCatalogV2 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-LocationHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local preparation contract; it grants no authority to run SQL.
# The bootstrap is a separate committed input, never a canonical migration or extra preflight.
$descriptorFile = Assert-LocationFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-LocationHash $descriptorFile.FullName) -cne '3edf1fc7608b50615f85994ce48c2e9875484eec6ea7e704516d84ee7c2a82f6') {
  throw 'LocationCatalogV2 descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "LocationCatalogV2 requires target 20260908031000; received $TargetVersion"
}
$manifestFile = Assert-LocationFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
if ((Get-LocationHash $manifestFile.FullName) -cne $descriptor.base.manifest_sha256_crlf_utf8) {
  throw 'LocationCatalogV2 base manifest hash mismatch'
}
$baseEntries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'LocationCatalogV2 base manifest entry is invalid'
  }
  if ($Matches[2] -le '20260812001975' -or $Matches[2] -in @(
      '20260827214000', '20260827233000', '20260901124500', '20260901200206')) {
    [pscustomobject]@{ file = $Matches[1]; sha256_crlf_utf8 = $Matches[3] }
  }
})
if ($baseEntries.Count -ne $descriptor.base.selected_canonical_count -or
    @($descriptor.extra_bridges).Count -ne 0) {
  throw 'LocationCatalogV2 requires Auth45 and zero extra bridges'
}
$canonicalEntries = @($baseEntries) + @($descriptor.canonical_additions)
$preflightEntries = @($descriptor.inherited_preflights)
$bootstrap = $descriptor.location_bootstrap
$allEntries = @($canonicalEntries) + @($preflightEntries) + @($bootstrap.derived)
$versions = @($allEntries | ForEach-Object {
  if ($_.file -notmatch '^(\d{14})_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'LocationCatalogV2 input name or hash is invalid'
  }
  $_.file.Substring(0, 14)
})
if ($canonicalEntries.Count -ne $descriptor.planned_counts.canonical -or
    $preflightEntries.Count -ne $descriptor.planned_counts.preflight -or
    @($bootstrap.derived).Count -ne $descriptor.planned_counts.bootstrap -or
    $allEntries.Count -ne $descriptor.planned_counts.total -or
    @($versions | Sort-Object -Unique).Count -ne $allEntries.Count -or
    ($versions | Sort-Object)[-1] -cne $descriptor.target_version -or
    @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql').Count -ne 2) {
  throw 'LocationCatalogV2 requires 47 canonical migrations, two inherited preflights and one separate bootstrap'
}
$ordered = @($allEntries | Sort-Object file)
$bootstrapIndex = [Array]::IndexOf(@($ordered.file), $bootstrap.derived.file)
if ($bootstrapIndex + 1 -ne $bootstrap.combined_position -or
    $bootstrapIndex + 1 -ge $ordered.Count -or
    $ordered[$bootstrapIndex + 1].file -cne $bootstrap.before) {
  throw 'LocationCatalogV2 bootstrap must be position49 immediately before target31000'
}
$orderedCanonical = @($canonicalEntries | Sort-Object file)
foreach ($addition in $descriptor.canonical_additions) {
  if ([Array]::IndexOf(@($orderedCanonical.file), $addition.file) + 1 -ne $addition.canonical_union_position) {
    throw 'LocationCatalogV2 canonical addition order mismatch'
  }
}
$canonical = @($canonicalEntries | ForEach-Object {
  $file = Assert-LocationFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-LocationHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "LocationCatalogV2 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$preflight = @($preflightEntries | ForEach-Object {
  $file = Assert-LocationFile (Join-Path (Join-Path $packageRoot 'replay') $_.file)
  if ((Get-LocationHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "LocationCatalogV2 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$bootstrapFiles = @($bootstrap.source, $bootstrap.derived | ForEach-Object {
  if ($_.file -cne [IO.Path]::GetFileName($_.file) -or
      $_.sha256_raw -cnotmatch '^[0-9a-f]{64}$') {
    throw 'LocationCatalogV2 bootstrap name or raw hash is invalid'
  }
  $file = Assert-LocationFile (Join-Path (Join-Path $packageRoot 'tests\fixtures') $_.file)
  if ((Get-LocationHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "LocationCatalogV2 input hash mismatch: $($_.file)"
  }
  if ((Get-LocationHash $file.FullName -Raw) -cne $_.sha256_raw -or $file.Length -ne $_.bytes) {
    throw "LocationCatalogV2 input raw hash mismatch: $($_.file)"
  }
  $file
})
# Verify the sole byte insertion without writing or transforming either input.
$sourceBytes = [IO.File]::ReadAllBytes($bootstrapFiles[0].FullName)
$derivedBytes = [IO.File]::ReadAllBytes($bootstrapFiles[1].FullName)
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$sourceText = $utf8.GetString($sourceBytes)
$anchorIndex = $sourceText.IndexOf($bootstrap.insert_after, [StringComparison]::Ordinal)
if ($anchorIndex -lt 0 -or
    $sourceText.LastIndexOf($bootstrap.insert_after, [StringComparison]::Ordinal) -ne $anchorIndex) {
  throw 'LocationCatalogV2 bootstrap requires exactly one BEGIN insertion anchor'
}
$insertAt = $utf8.GetByteCount($sourceText.Substring(0, $anchorIndex + $bootstrap.insert_after.Length))
$insertBytes = $utf8.GetBytes($bootstrap.insert_line)
$expectedBytes = [byte[]]::new($sourceBytes.Length + $insertBytes.Length)
[Array]::Copy($sourceBytes, 0, $expectedBytes, 0, $insertAt)
[Array]::Copy($insertBytes, 0, $expectedBytes, $insertAt, $insertBytes.Length)
[Array]::Copy($sourceBytes, $insertAt, $expectedBytes, $insertAt + $insertBytes.Length, $sourceBytes.Length - $insertAt)
if ($insertBytes.Length -ne 54 -or
    [Convert]::ToBase64String($derivedBytes) -cne [Convert]::ToBase64String($expectedBytes)) {
  throw 'LocationCatalogV2 bootstrap must differ only by the exact SET LOCAL line after BEGIN'
}
[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object { $_.Name -in $descriptor.canonical_additions.file })
  LocationBootstrap = $bootstrapFiles[1]
  ManifestHash = $descriptor.base.manifest_sha256_crlf_utf8
}
