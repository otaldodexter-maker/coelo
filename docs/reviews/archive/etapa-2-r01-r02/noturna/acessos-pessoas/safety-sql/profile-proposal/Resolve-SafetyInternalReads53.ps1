[CmdletBinding()]
param([string]$TargetVersion = '20260909190000')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)

function Assert-SafetyReadsFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "SafetyInternalReads53 input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "SafetyInternalReads53 input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-SafetyReadsHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-SafetyReadsBodyMd5([string]$Path) {
  $source = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
  $pattern = '(?is)create\s+or\s+replace\s+function\s+app_private\.superadmin_internal_error_envelope\s*\(.*?\)\s*returns\s+jsonb.*?\bas\s+\$\$(.*?)\$\$;'
  $matches = [regex]::Matches($source, $pattern)
  if ($matches.Count -ne 1) {
    throw "SafetyInternalReads53 helper source is ambiguous: $Path"
  }
  $md5 = [Security.Cryptography.MD5]::Create()
  try {
    return ([BitConverter]::ToString($md5.ComputeHash(
      [Text.Encoding]::UTF8.GetBytes($matches[0].Groups[1].Value)))).Replace('-', '').ToLowerInvariant()
  } finally { $md5.Dispose() }
}

$descriptorFile = Assert-SafetyReadsFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-SafetyReadsHash $descriptorFile.FullName) -cne '15eeec5f353243bf7c509181a89ba0b7f886748d7b85c978551e7a35a757d6c1') {
  throw 'SafetyInternalReads53 descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($descriptor.id -cne 'SafetyInternalReads53' -or $TargetVersion -cne $descriptor.target_version) {
  throw "SafetyInternalReads53 requires target 20260909190000; received $TargetVersion"
}

$manifestFile = Assert-SafetyReadsFile (Join-Path $packageRoot 'replay\foundation-migrations.sha256')
if ((Get-SafetyReadsHash $manifestFile.FullName) -cne $descriptor.base.manifest_sha256_crlf_utf8) {
  throw 'SafetyInternalReads53 base manifest hash mismatch'
}
$baseEntries = @(Get-Content -LiteralPath $manifestFile.FullName | Where-Object {
  $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object {
  if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
    throw 'SafetyInternalReads53 base manifest entry is invalid'
  }
  if ($Matches[2] -le '20260812001975' -or $Matches[2] -in @(
      '20260827214000', '20260827233000', '20260901124500', '20260901200206')) {
    [pscustomobject]@{ file = $Matches[1]; sha256_crlf_utf8 = $Matches[3] }
  }
})
if ($descriptor.base.profile -cne 'auth' -or
    $descriptor.base.boundary -cne '20260901200206' -or
    $baseEntries.Count -ne 45 -or
    $baseEntries.Count -ne $descriptor.base.selected_canonical_count -or
    @($descriptor.canonical_additions).Count -ne 5 -or
    @($descriptor.local_bridges).Count -ne 1 -or
    @($descriptor.inherited_preflights).Count -ne 2) {
  throw 'SafetyInternalReads53 requires unchanged Auth45, Safety5, bridge1 and preflight2'
}

$canonicalEntries = @($baseEntries) + @($descriptor.canonical_additions)
$bridgeEntries = @($descriptor.local_bridges)
$preflightEntries = @($descriptor.inherited_preflights)
$allEntries = @($canonicalEntries) + @($bridgeEntries) + @($preflightEntries)
$versions = @($allEntries | ForEach-Object {
  if ($_.file -notmatch '^(\d{14})_[a-z0-9_]+\.sql$' -or
      $_.sha256_crlf_utf8 -cnotmatch '^[0-9a-f]{64}$') {
    throw 'SafetyInternalReads53 input name or hash is invalid'
  }
  $_.file.Substring(0, 14)
})
$bridgeVersion = $bridgeEntries[0].file.Substring(0, 14)
if ($canonicalEntries.Count -ne $descriptor.planned_counts.canonical -or
    $bridgeEntries.Count -ne $descriptor.planned_counts.local_bridges -or
    $preflightEntries.Count -ne $descriptor.planned_counts.preflight -or
    $allEntries.Count -ne $descriptor.planned_counts.total -or
    @($versions | Sort-Object -Unique).Count -ne $allEntries.Count -or
    ($versions | Sort-Object)[-1] -cne $descriptor.target_version -or
    $bridgeVersion -le $descriptor.base.boundary -or
    $bridgeVersion -ge $descriptor.target_version -or
    $bridgeEntries[0].after -cne '20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql' -or
    $bridgeEntries[0].before -cne '20260909190000_d04_child_safety_internal_reads.sql' -or
    @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'replay') -File -Filter '*.sql').Count -ne 2) {
  throw 'SafetyInternalReads53 requires 50 canonical migrations, one ordered bridge and two inherited preflights'
}
if (@(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'migrations') -File -Filter "$bridgeVersion`_*.sql").Count -ne 0) {
  throw 'SafetyInternalReads53 local bridge version conflicts with a canonical migration'
}

$canonical = @($canonicalEntries | ForEach-Object {
  $file = Assert-SafetyReadsFile (Join-Path (Join-Path $packageRoot 'migrations') $_.file)
  if ((Get-SafetyReadsHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "SafetyInternalReads53 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$preflight = @($preflightEntries | ForEach-Object {
  $file = Assert-SafetyReadsFile (Join-Path (Join-Path $packageRoot 'replay') $_.file)
  if ((Get-SafetyReadsHash $file.FullName) -cne $_.sha256_crlf_utf8) {
    throw "SafetyInternalReads53 input hash mismatch: $($_.file)"
  }
  $file
} | Sort-Object Name)
$bridge = Assert-SafetyReadsFile (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'ChildDirectoryEnvelope') $bridgeEntries[0].file)
if ((Get-SafetyReadsHash $bridge.FullName) -cne $bridgeEntries[0].sha256_crlf_utf8) {
  throw "SafetyInternalReads53 input hash mismatch: $($bridge.Name)"
}

$sourceNote = Assert-SafetyReadsFile (Join-Path $repositoryRoot $bridgeEntries[0].source_note)
$approvedSource = Assert-SafetyReadsFile (Join-Path $repositoryRoot $bridgeEntries[0].approved_helper_source)
if ((Get-SafetyReadsHash $sourceNote.FullName) -cne $bridgeEntries[0].source_note_sha256_crlf_utf8 -or
    (Get-SafetyReadsHash $approvedSource.FullName) -cne $bridgeEntries[0].approved_helper_source_sha256_crlf_utf8 -or
    (Get-SafetyReadsHash $bridge.FullName) -cne (Get-SafetyReadsHash $sourceNote.FullName) -or
    (Get-SafetyReadsBodyMd5 $approvedSource.FullName) -cne $bridgeEntries[0].expected_after_body_md5 -or
    (Get-SafetyReadsBodyMd5 $bridge.FullName) -cne $bridgeEntries[0].expected_after_body_md5 -or
    $bridgeEntries[0].expected_before_body_md5 -cne 'b89d2dc22f032a1c3f155a77f0eaaf08') {
  throw 'SafetyInternalReads53 bridge provenance mismatch'
}

[pscustomobject]@{
  Canonical = $canonical
  Preflight = $preflight
  Additional = @($canonical | Where-Object { $_.Name -cin @($descriptor.canonical_additions.file) })
  LocalBridges = @($bridge)
  ManifestHash = $descriptor.base.manifest_sha256_crlf_utf8
}
