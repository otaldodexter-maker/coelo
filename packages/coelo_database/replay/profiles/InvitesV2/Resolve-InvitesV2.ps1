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
# plus exactly one repair: 20260812000000_chat_production_contract.sql.
#
# That repair is not a new dependency of invites. It is a gap in the manifest
# itself: the manifest carries 20260901101500_superadmin_internal_chat_v2.sql,
# whose preflight requires public.chat_attachment_metadata, and the only
# migration that creates that table was left out -- the manifest jumps from
# 20260811215451 straight to 20260812000847. Without the repair the manifest
# cannot reach anything newer than the chat migration, which is why Convites,
# Circulares, Avisos and Avaliacoes are all unreachable by the sanctioned path.
#
# The clean fix belongs to the manifest, not here, but changing the manifest
# rehashes every profile that pins it. Until that decision is taken, this
# profile repairs the order locally and verifies every input by hash.
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
if (@($entries | Where-Object { $_.version -ceq '20260812000000' }).Count -ne 0) {
  throw 'InvitesV2 repair is obsolete: the manifest already carries the chat contract'
}

$selected = @($entries | Where-Object { $_.version -le $TargetVersion })
if ($selected.Count -ne 65 -or $selected[-1].file -cne '20260901190432_superadmin_internal_invites_v2.sql') {
  throw 'InvitesV2 requires the 65-entry manifest prefix ending at the candidate'
}

$repairName = '20260812000000_chat_production_contract.sql'
$repair = Assert-InvitesFile (Join-Path (Join-Path $packageRoot 'migrations') $repairName)
if ((Get-InvitesHash $repair.FullName) -cne
    '75e18de4d9108a55719acae93af011221fdb81e8259772bb93c52df37508fe47') {
  throw "InvitesV2 input hash mismatch: $repairName"
}

$fromManifest = @($selected | ForEach-Object {
  $file = Assert-InvitesFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-InvitesHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "InvitesV2 input hash mismatch: $($_.file)"
  }
  $file
})
$canonical = @(@($fromManifest) + @($repair) | Sort-Object Name)

$preflight = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql' |
  Sort-Object Name | ForEach-Object { Assert-InvitesFile $_.FullName })
if ($preflight.Count -ne 2) {
  throw 'InvitesV2 requires exactly the two inherited preflights'
}

$allInputs = @($canonical) + @($preflight)
$versions = @($allInputs | ForEach-Object { $_.Name.Substring(0, 14) })
if ($canonical.Count -ne 66 -or $allInputs.Count -ne 68 -or
    @($versions | Sort-Object -Unique).Count -ne 68 -or
    ($versions | Sort-Object)[-1] -cne $TargetVersion) {
  throw 'InvitesV2 requires 66 unique canonical migrations and two inherited preflights'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object {
    $_.Name -ceq '20260901190432_superadmin_internal_invites_v2.sql' -or $_.Name -ceq $repairName
  })
  ManifestHash = (Get-InvitesHash $manifestFile.FullName)
}
