[CmdletBinding()]
param([string]$TargetVersion = '20260828005000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-PersonDetailFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "PersonDetailV2 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "PersonDetailV2 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-PersonDetailHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local extension for the person detail v2 candidate.
#
# It adds nothing to the reviewed foundation manifest: it selects the manifest
# prefix that ends exactly at the candidate and verifies every hash unchanged.
# The truncation exists because the manifest tail does not replay -- the
# FoundationOnly run of 2026-09-10 applied every entry up to and including this
# candidate and then failed on 20260901101500_superadmin_internal_chat_v2.sql,
# whose chat and audit dependencies are outside the manifest. That failure is
# later than this candidate and unrelated to it.
#
# This is not a generic extension mechanism and not a remote authorization.
if ($TargetVersion -cne '20260828005000') {
  throw "PersonDetailV2 requires target 20260828005000; received $TargetVersion"
}

$manifestFile = Assert-PersonDetailFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
$entries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'PersonDetailV2 base manifest entry is invalid'
  }
  [pscustomobject]@{ file = $Matches[1]; version = $Matches[2]; sha256_crlf_utf8 = $Matches[3] }
})
if ($entries.Count -ne 67 -or $entries[-1].version -cne '20260901200206') {
  throw 'PersonDetailV2 requires the unchanged 67-entry foundation manifest'
}

$selected = @($entries | Where-Object { $_.version -le $TargetVersion })
if ($selected.Count -ne 51 -or $selected[-1].file -cne '20260828005000_superadmin_internal_person_detail.sql') {
  throw 'PersonDetailV2 requires the 51-entry manifest prefix ending at the candidate'
}

$canonical = @($selected | ForEach-Object {
  $file = Assert-PersonDetailFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-PersonDetailHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "PersonDetailV2 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)

$preflight = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql' |
  Sort-Object Name | ForEach-Object { Assert-PersonDetailFile $_.FullName })
if ($preflight.Count -ne 2) {
  throw 'PersonDetailV2 requires exactly the two inherited preflights'
}

$allInputs = @($canonical) + @($preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 51 -or $allInputs.Count -ne 53 -or
    @($versions | Sort-Object -Unique).Count -ne 53 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'PersonDetailV2 requires 51 unique canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object {
    $_.Name -ceq '20260828005000_superadmin_internal_person_detail.sql'
  })
  ManifestHash = (Get-PersonDetailHash $manifestFile.FullName)
}
