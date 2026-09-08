[CmdletBinding()]
param([string]$TargetVersion = '20260908021821')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-ModelGreenFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "ModelReadAuthorizationGreen input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "ModelReadAuthorizationGreen input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-ModelGreenHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# This exact diagnostic descriptor is not an extension mechanism or a lease.
# Changing any metadata, bridge, name, count or digest requires another review.
$descriptorFile = Assert-ModelGreenFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-ModelGreenHash $descriptorFile.FullName) -cne '0986be5b8b35c7498644d0eca4e55fca02b4657ec2a830d27186c3958d5581f8') {
  throw 'ModelReadAuthorizationGreen descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "ModelReadAuthorizationGreen requires target 20260908021821; received $TargetVersion"
}
$manifestFile = Assert-ModelGreenFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
if ((Get-ModelGreenHash $manifestFile.FullName) -cne $descriptor.base.manifest_sha256_crlf_utf8) {
  throw 'ModelReadAuthorizationGreen base manifest hash mismatch'
}
$baseEntries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'ModelReadAuthorizationGreen base manifest entry is invalid'
  }
  if ($Matches[2] -le '20260812001975' -or $Matches[2] -in @(
      '20260827214000', '20260827233000', '20260901124500', '20260901200206')) {
    [pscustomobject]@{ file = $Matches[1]; sha256_crlf_utf8 = $Matches[3] }
  }
})
if ($baseEntries.Count -ne $descriptor.base.selected_canonical_count -or
    @($descriptor.extra_bridges).Count -ne 0) {
  throw 'ModelReadAuthorizationGreen requires Auth45 and zero extra bridges'
}
$canonicalEntries = @($baseEntries) + @($descriptor.canonical_additions)
$preflightEntries = @($descriptor.inherited_preflights)
$allEntries = @($canonicalEntries) + @($preflightEntries)
$versions = @($allEntries | ForEach-Object {
  if ($_.file -notmatch '^(\d{14})_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'ModelReadAuthorizationGreen input name or hash is invalid'
  }
  $_.file.Substring(0, 14)
})
if ($canonicalEntries.Count -ne $descriptor.planned_counts.canonical -or
    $preflightEntries.Count -ne $descriptor.planned_counts.preflight -or
    $allEntries.Count -ne $descriptor.planned_counts.total -or
    @($versions | Sort-Object -Unique).Count -ne $allEntries.Count -or
    ($versions | Sort-Object)[-1] -cne $descriptor.target_version -or
    @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql').Count -ne 2) {
  throw 'ModelReadAuthorizationGreen requires 48 unique canonical migrations and exactly two inherited preflights'
}
$canonical = @($canonicalEntries | ForEach-Object {
  $file = Assert-ModelGreenFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-ModelGreenHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "ModelReadAuthorizationGreen input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$preflight = @($preflightEntries | ForEach-Object {
  $file = Assert-ModelGreenFile (Join-Path (Join-Path $packageRoot 'replay') $_.file)
  if ((Get-ModelGreenHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "ModelReadAuthorizationGreen input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object { $_.Name -in $descriptor.canonical_additions.file })
  ManifestHash = $descriptor.base.manifest_sha256_crlf_utf8
}
