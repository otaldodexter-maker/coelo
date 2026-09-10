[CmdletBinding()]
param([string]$TargetVersion = '20260901190432')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

function Assert-InvitesFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "InvitesV2 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "InvitesV2 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-InvitesHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# Closed local extension for the invites v2 candidate.
#
# It is the reviewed foundation manifest prefix that ends at the candidate,
# minus exactly one entry: 20260901101500_superadmin_internal_chat_v2.sql.
#
# That entry is not a dependency of invites, and it cannot apply anywhere as
# written. It inserts into public.platform_permissions without module_label,
# screen_label and action_label, which 20260831130726 made NOT NULL by removing
# their defaults earlier in the same chain. The reset dies with 23502. The
# defect belongs to the chat package and was reported to the coordinator; it is
# not repaired here, because repairing another group's migration inside a proof
# profile would hide it.
#
# 20260901185008_superadmin_internal_notices_v2.sql is excluded for a reason of
# the same shape: line 99 does `alter table public.notice_events enable row level
# security`, but 20260623203230 -- the manifest's own second entry -- moved that
# table to the analytics schema, where production also keeps it. The migration
# addresses a schema that stopped existing in the second step of the chain.
# Notices is not a dependency of invites. That defect belongs to the notices
# package and was reported to the coordinator, not repaired here.
#
# The manifest also omits 20260812000000_chat_production_contract.sql, which the
# chat migration needs. Excluding both entries makes that omission moot for this
# profile.
#
# This is not a generic extension mechanism and not a remote authorization.
if ($TargetVersion -cne '20260901190432') {
  throw "InvitesV2 requires target 20260901190432; received $TargetVersion"
}

$manifestFile = Assert-InvitesFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
$entries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'InvitesV2 base manifest entry is invalid'
  }
  [pscustomobject]@{ file = $Matches[1]; version = $Matches[2]; sha256_crlf_utf8 = $Matches[3] }
})
if ($entries.Count -ne 67 -or $entries[-1].version -cne '20260901200206') {
  throw 'InvitesV2 requires the unchanged 67-entry foundation manifest'
}

$excludedNames = @(
  '20260901101500_superadmin_internal_chat_v2.sql',
  '20260901185008_superadmin_internal_notices_v2.sql'
)
$prefix = @($entries | Where-Object { $_.version -le $TargetVersion })
if ($prefix.Count -ne 65 -or $prefix[-1].file -cne '20260901190432_superadmin_internal_invites_v2.sql') {
  throw 'InvitesV2 requires the 65-entry manifest prefix ending at the candidate'
}
$selected = @($prefix | Where-Object { $_.file -cnotin $excludedNames })
if ($selected.Count -ne 63) {
  throw 'InvitesV2 requires both unreachable entries to be present in the manifest and excluded here'
}

$canonical = @($selected | ForEach-Object {
  $file = Assert-InvitesFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-InvitesHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "InvitesV2 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)

$preflight = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql' |
  Sort-Object Name | ForEach-Object { Assert-InvitesFile $_.FullName })
if ($preflight.Count -ne 2) {
  throw 'InvitesV2 requires exactly the two inherited preflights'
}

$allInputs = @($canonical) + @($preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 63 -or $allInputs.Count -ne 65 -or
    @($versions | Sort-Object -Unique).Count -ne 65 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'InvitesV2 requires 63 unique canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object {
    $_.Name -ceq '20260901190432_superadmin_internal_invites_v2.sql'
  })
  ManifestHash = (Get-InvitesHash $manifestFile.FullName)
}
