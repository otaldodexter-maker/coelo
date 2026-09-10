[CmdletBinding()]
param([string]$TargetVersion = '20260908021644')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-InternalUsersFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "InternalUsersV2 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "InternalUsersV2 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-InternalUsersHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local extension for the internal users directory candidates.
#
# Base: the whole reviewed foundation manifest, minus the two entries that
# cannot apply anywhere as written and that this domain does not depend on --
# 20260901101500_superadmin_internal_chat_v2.sql (23502: inserts into
# platform_permissions without the module_label, screen_label and action_label
# that 20260831130726 made mandatory by dropping their defaults) and
# 20260901185008_superadmin_internal_notices_v2.sql (42P01: alters
# public.notice_events, a table the manifest's own second entry moves to the
# analytics schema, where production keeps it too). Both defects belong to other
# packages and are reported, not repaired here.
#
# Additions: the two internal users migrations, in order. Neither is in the
# manifest, and neither is in production -- the three RPCs the Superadmin client
# calls for internal users do not exist in the database.
#
# This is not a generic extension mechanism and not a remote authorization.
if ($TargetVersion -cne '20260908021644') {
  throw "InternalUsersV2 requires target 20260908021644; received $TargetVersion"
}

$manifestFile = Assert-InternalUsersFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
$entries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'InternalUsersV2 base manifest entry is invalid'
  }
  [pscustomobject]@{ file = $Matches[1]; version = $Matches[2]; sha256_crlf_utf8 = $Matches[3] }
})
if ($entries.Count -ne 67 -or $entries[-1].version -cne '20260901200206') {
  throw 'InternalUsersV2 requires the unchanged 67-entry foundation manifest'
}

$excludedNames = @(
  '20260901101500_superadmin_internal_chat_v2.sql',
  '20260901185008_superadmin_internal_notices_v2.sql'
)
$selected = @($entries | Where-Object { $_.file -cnotin $excludedNames })
if ($selected.Count -ne 65) {
  throw 'InternalUsersV2 requires both unreachable entries to be present in the manifest and excluded here'
}

$additionNames = @(
  @{ file = '20260901210000_superadmin_internal_users_directory.sql'
     sha  = 'b1f62d73704638c72f8230ae1457da7345842d5997cca075564a7ad67e999db7' },
  @{ file = '20260908021644_superadmin_internal_users_read_minimization.sql'
     sha  = '5c670e6ac0d4755507af1e306b9a1f91a207db6ea911c6bdc75603622df6a72a' }
)
$additions = @($additionNames | ForEach-Object {
  $file = Assert-InternalUsersFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-InternalUsersHash $file.FullName) -cne $_.sha) {
    throw "InternalUsersV2 input hash mismatch: $($_.file)"
  }
  $file
})

$fromManifest = @($selected | ForEach-Object {
  $file = Assert-InternalUsersFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-InternalUsersHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "InternalUsersV2 input hash mismatch: $($_.file)"
  }
  $file
})
$canonical = @(@($fromManifest) + @($additions) | Sort-Object Name)

$preflight = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql' |
  Sort-Object Name | ForEach-Object { Assert-InternalUsersFile $_.FullName })
if ($preflight.Count -ne 2) {
  throw 'InternalUsersV2 requires exactly the two inherited preflights'
}

$allInputs = @($canonical) + @($preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 67 -or $allInputs.Count -ne 69 -or
    @($versions | Sort-Object -Unique).Count -ne 69 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'InternalUsersV2 requires 67 unique canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($additions)
  ManifestHash = (Get-InternalUsersHash $manifestFile.FullName)
}
