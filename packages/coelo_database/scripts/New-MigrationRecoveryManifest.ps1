[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$RecoveryRoot,

  [Parameter()]
  [ValidatePattern('^recovery://[A-Za-z0-9][A-Za-z0-9.-]*/[A-Za-z0-9][A-Za-z0-9.-]*$')]
  [string]$RecoveryLogicalId,

  [Parameter()]
  [ValidateRange(1, 10000)]
  [int]$ExpectedCanonicalCount = 100
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$canonicalRoot = Join-Path $packageRoot 'migrations'
$evidenceRoot = Join-Path $repositoryRoot 'docs\reviews\evidence'
$remoteVersionsPath = Join-Path $evidenceRoot '2026-08-27-remote-migration-versions.txt'
$manifestOutputName = '2026-08-27-migration-recovery-manifest.csv'
$metadataOutputName = '2026-08-27-migration-recovery-manifest.meta.json'

function Assert-NotReparsePoint([string]$Path, [string]$Label) {
  $item = Get-Item -LiteralPath $Path -Force
  if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "$Label cannot be a reparse point: $Path"
  }
  return $item
}

function Resolve-ExistingDirectory([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "$Label directory is missing: $Path" }
  $item = Assert-NotReparsePoint $Path $Label
  if (-not $item.PSIsContainer) { throw "$Label is not a directory: $Path" }
  return [System.IO.Path]::GetFullPath($item.FullName)
}

function Resolve-ExistingFile([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label file is missing: $Path" }
  $item = Assert-NotReparsePoint $Path $Label
  if ($item.PSIsContainer) { throw "$Label is not a file: $Path" }
  return [System.IO.Path]::GetFullPath($item.FullName)
}

function Assert-Under([string]$Path, [string]$Root, [string]$Label) {
  if (-not $Path.StartsWith($Root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label escaped its approved root: $Path"
  }
}

function Get-Sha256Hex([byte[]]$Bytes) {
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
  }
  finally {
    $algorithm.Dispose()
  }
}

function Get-FileDigests([string]$Path) {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
  $text = $utf8.GetString($bytes)
  if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) {
    $text = $text.Substring(1)
  }
  $lfNormalized = $text -replace "`r`n|`r", "`n"
  [pscustomobject]@{
    sha256_raw = Get-Sha256Hex $bytes
    sha256_lf_normalized = Get-Sha256Hex ($utf8.GetBytes($lfNormalized))
  }
}

function Get-MigrationFiles([string]$Root, [string]$Origin, [string]$DisplayRoot) {
  $files = @(Get-ChildItem -LiteralPath $Root -File -Filter '*.sql' | Sort-Object Name)
  if ($files.Count -eq 0) { throw "no $Origin migrations found" }
  $entries = foreach ($file in $files) {
    $fileFull = Resolve-ExistingFile $file.FullName "$Origin migration"
    Assert-Under $fileFull $Root "$Origin migration"
    $fileItem = Get-Item -LiteralPath $fileFull -Force
    if ($fileItem.Name -notmatch '^(?<version>\d{14})_(?<name>[a-z0-9]+(?:_[a-z0-9]+)*)\.sql$') {
      throw "invalid migration name in ${Origin}: $($fileItem.Name)"
    }
    $digests = Get-FileDigests $fileFull
    [pscustomobject]@{
      version = $Matches.version
      name = $Matches.name
      path = "$DisplayRoot/$($fileItem.Name)"
      size = $fileItem.Length
      sha256_raw = $digests.sha256_raw
      sha256_lf_normalized = $digests.sha256_lf_normalized
      origin = $Origin
    }
  }
  $duplicates = @($entries | Group-Object version | Where-Object Count -gt 1)
  if ($duplicates.Count -gt 0) { throw "duplicate $Origin version: $($duplicates[0].Name)" }
  return @($entries)
}

function Get-SourceSetSha256([object[]]$Entries) {
  $lines = @(
    $Entries |
      Sort-Object version, name, size, sha256_raw, sha256_lf_normalized |
      ForEach-Object { "$($_.version)|$($_.name)|$($_.size)|$($_.sha256_raw)|$($_.sha256_lf_normalized)" }
  )
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  return Get-Sha256Hex ($utf8NoBom.GetBytes(($lines -join "`n") + "`n"))
}

function Get-RecoveryLogicalId([string]$RecoveryFull, [string]$RequestedLogicalId) {
  if ($RequestedLogicalId) {
    return $RequestedLogicalId
  }

  $recoveryLeaf = [System.IO.Path]::GetFileName($RecoveryFull.TrimEnd('\\'))
  $recoveryParentLeaf = [System.IO.Path]::GetFileName((Split-Path -Parent $RecoveryFull).TrimEnd('\\'))
  if ($recoveryParentLeaf -notmatch '^Coelo-recovery-\d{8}-\d{6}(?:-[a-z0-9]+)+$') {
    throw "recovery snapshot parent name is not approved: $recoveryParentLeaf"
  }
  if ($recoveryLeaf -ne 'mirror-before-reconcile') {
    throw "recovery snapshot leaf name is not approved: $recoveryLeaf"
  }
  return "recovery://$recoveryParentLeaf/$recoveryLeaf"
}

function Write-TextAtomically([string]$OutputFull, [string]$Text, [string]$Label, [string]$ApprovedRoot) {
  Assert-Under $OutputFull $ApprovedRoot $Label
  $parentFull = Resolve-ExistingDirectory (Split-Path -Parent $OutputFull) "$Label parent"
  if ($parentFull -ne $ApprovedRoot) { throw "$Label parent does not match the approved evidence root: $parentFull" }
  if (Test-Path -LiteralPath $OutputFull) {
    $outputItem = Assert-NotReparsePoint $OutputFull $Label
    if ($outputItem.PSIsContainer) { throw "$Label is not a file: $OutputFull" }
  }
  $fileName = [System.IO.Path]::GetFileName($OutputFull)
  $tempFull = Join-Path $ApprovedRoot ".${fileName}.$PID.$([guid]::NewGuid().ToString('N')).tmp"
  $backupFull = Join-Path $ApprovedRoot ".${fileName}.$PID.$([guid]::NewGuid().ToString('N')).bak"
  Assert-Under $tempFull $ApprovedRoot "temporary $Label"
  Assert-Under $backupFull $ApprovedRoot "$Label backup"
  $tempCreated = $false
  try {
    $stream = [System.IO.File]::Open($tempFull, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
      $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false))
      try { $writer.Write($Text) }
      finally { $writer.Dispose() }
    }
    finally { $stream.Dispose() }
    $tempCreated = $true
    Assert-NotReparsePoint $tempFull "temporary $Label" | Out-Null
    if ([System.IO.File]::Exists($OutputFull)) {
      Assert-NotReparsePoint $OutputFull $Label | Out-Null
      [System.IO.File]::Replace($tempFull, $OutputFull, $backupFull)
      $backupItem = Assert-NotReparsePoint $backupFull "$Label backup"
      if (-not $backupItem.PSIsContainer) { [System.IO.File]::Delete($backupFull) }
    }
    else {
      [System.IO.File]::Move($tempFull, $OutputFull)
    }
    $tempCreated = $false
  }
  finally {
    if ($tempCreated -and (Test-Path -LiteralPath $tempFull -PathType Leaf)) {
      $tempItem = Assert-NotReparsePoint $tempFull "temporary $Label"
      if (-not $tempItem.PSIsContainer) { [System.IO.File]::Delete($tempFull) }
    }
    if (Test-Path -LiteralPath $backupFull -PathType Leaf) {
      $backupItem = Assert-NotReparsePoint $backupFull "$Label backup"
      if (-not $backupItem.PSIsContainer) { [System.IO.File]::Delete($backupFull) }
    }
  }
}

$canonicalFull = Resolve-ExistingDirectory $canonicalRoot 'canonical migration'
$recoveryFull = Resolve-ExistingDirectory $RecoveryRoot 'recovery snapshot'
$recoveryLogical = Get-RecoveryLogicalId $recoveryFull $RecoveryLogicalId
$repositoryFull = Resolve-ExistingDirectory $repositoryRoot 'repository'
$evidenceFull = Resolve-ExistingDirectory $evidenceRoot 'evidence'
$remoteVersionsFull = Resolve-ExistingFile $remoteVersionsPath 'remote migration baseline'
$scriptFull = Resolve-ExistingFile $PSCommandPath 'manifest generator script'
$outputFull = Join-Path $evidenceFull $manifestOutputName
$metadataFull = Join-Path $evidenceFull $metadataOutputName
if (Test-Path -LiteralPath $outputFull) {
  $outputItem = Assert-NotReparsePoint $outputFull 'manifest output'
  if ($outputItem.PSIsContainer) { throw "manifest output is not a file: $outputFull" }
}
Assert-Under $canonicalFull $packageRoot 'canonical migration directory'
Assert-Under $evidenceFull $repositoryFull 'evidence directory'
Assert-Under $remoteVersionsFull $evidenceFull 'remote migration baseline'
Assert-Under $scriptFull $repositoryFull 'manifest generator script'
Assert-Under $outputFull $evidenceFull 'manifest output'
Assert-Under $metadataFull $evidenceFull 'manifest metadata output'

$canonical = Get-MigrationFiles $canonicalFull 'canonical' 'packages/coelo_database/migrations'
$recovery = Get-MigrationFiles $recoveryFull 'recovery' $recoveryLogical
if ($canonical.Count -ne $ExpectedCanonicalCount) {
  throw "canonical migration count mismatch: expected=$ExpectedCanonicalCount actual=$($canonical.Count)"
}
if ($recovery.Count -ne 175) { throw "recovery migration count mismatch: expected=175 actual=$($recovery.Count)" }

$remoteStatementEvidence = @{}
$remote = foreach ($line in Get-Content -LiteralPath $remoteVersionsFull) {
  $value = $line.Trim()
  if (-not $value -or $value.StartsWith('#')) {
    if ($value -match '^# remote_statement_sha256\|(?<version>\d{14})\|(?<statements>\d+)\|(?<size>\d+)\|(?<sha256>[a-f0-9]{64})\|(?<status>[a-z0-9-]+)$') {
      $remoteStatementEvidence[$Matches.version] = "$($Matches.status); statements=$($Matches.statements); bytes=$($Matches.size); sha256=$($Matches.sha256)"
    }
    continue
  }
  if ($value -notmatch '^(?<version>\d{14})\|(?<name>[a-z0-9]+(?:_[a-z0-9]+)*)$') {
    throw "invalid remote migration baseline entry: $value"
  }
  [pscustomobject]@{
    version = $Matches.version
    name = $Matches.name
    path = "remote://supabase_migrations/schema_migrations/$($Matches.version)"
    size = $null
    sha256_raw = $null
    sha256_lf_normalized = $null
    origin = 'remote-ledger'
  }
}
$remote = @($remote)
$remoteDuplicates = @($remote | Group-Object version | Where-Object Count -gt 1)
if ($remoteDuplicates.Count -gt 0) { throw "duplicate remote version: $($remoteDuplicates[0].Name)" }
if ($remote.Count -ne 103) { throw "remote migration count mismatch: expected=103 actual=$($remote.Count)" }
if (($remote | Sort-Object version | Select-Object -Last 1).version -ne '20260821200000') { throw 'remote migration maximum version mismatch' }

$gitHead = @(& git -C $repositoryFull rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or $gitHead.Count -ne 1 -or $gitHead[0] -notmatch '^[a-f0-9]{40}$') {
  throw 'unable to resolve a valid Git HEAD for the manifest identity'
}

$byVersion = @{}
foreach ($entry in @($canonical + $recovery + $remote)) {
  if (-not $byVersion.ContainsKey($entry.version)) { $byVersion[$entry.version] = @() }
  $byVersion[$entry.version] += $entry
}

$manifest = foreach ($version in ($byVersion.Keys | Sort-Object)) {
  $entries = @($byVersion[$version])
  $head = @($entries | Where-Object origin -eq 'canonical')
  $snapshot = @($entries | Where-Object origin -eq 'recovery')
  $ledger = @($entries | Where-Object origin -eq 'remote-ledger')
  $localRelation = if ($head.Count -eq 1 -and $snapshot.Count -eq 1) {
    if ($head[0].name -ne $snapshot[0].name -or $head[0].sha256_lf_normalized -ne $snapshot[0].sha256_lf_normalized) {
      'text-divergent'
    }
    elseif ($head[0].sha256_raw -eq $snapshot[0].sha256_raw) {
      'raw-identical'
    }
    else {
      'eol-equivalent'
    }
  }
  else {
    $null
  }
  $remoteNameConflict = $ledger.Count -eq 1 -and (
    ($head.Count -eq 1 -and $head[0].name -ne $ledger[0].name) -or
    ($snapshot.Count -eq 1 -and $snapshot[0].name -ne $ledger[0].name)
  )
  $classification = if ($remoteNameConflict) {
    'name-conflict'
  }
  elseif ($localRelation -eq 'text-divergent') {
    'text-conflict'
  }
  elseif ($ledger.Count -eq 1 -and $head.Count -eq 1) {
    'remote-version+head-present'
  }
  elseif ($ledger.Count -eq 1 -and $snapshot.Count -eq 1) {
    'remote-recovery-candidate'
  }
  elseif ($head.Count -eq 1) {
    'local-only-head'
  }
  elseif ($snapshot.Count -eq 1) {
    'local-only-recovery'
  }
  else {
    throw "unclassifiable migration version: $version"
  }
  foreach ($entry in $entries) {
    [pscustomobject][ordered]@{
      version = $entry.version
      name = $entry.name
      path = $entry.path
      size = $entry.size
      sha256_raw = $entry.sha256_raw
      sha256_lf_normalized = $entry.sha256_lf_normalized
      origin = $entry.origin
      local_relation = $localRelation
      classification = $classification
      remote_statement_evidence = if ($remoteStatementEvidence.ContainsKey($version)) { $remoteStatementEvidence[$version] } else { $null }
    }
  }
}

$identityMetadata = [ordered]@{
  schema_version = 2
  git_head = $gitHead[0]
  roots = [ordered]@{
    repository = '.'
    canonical = 'packages/coelo_database/migrations'
    recovery = $recoveryLogical
    evidence = 'docs/reviews/evidence'
  }
  sources = [ordered]@{
    canonical = [ordered]@{ count = $canonical.Count; set_sha256 = Get-SourceSetSha256 $canonical }
    recovery = [ordered]@{ count = $recovery.Count; set_sha256 = Get-SourceSetSha256 $recovery }
    remote_baseline = [ordered]@{ count = $remote.Count; sha256_raw = (Get-FileDigests $remoteVersionsFull).sha256_raw }
  }
  generator = [ordered]@{ path = 'packages/coelo_database/scripts/New-MigrationRecoveryManifest.ps1'; sha256_raw = (Get-FileDigests $scriptFull).sha256_raw }
  counts = [ordered]@{ canonical = $canonical.Count; recovery = $recovery.Count; remote = $remote.Count; versions = $byVersion.Count; rows = $manifest.Count }
}
$metadataJson = $identityMetadata | ConvertTo-Json -Depth 8 -Compress
$manifestId = Get-Sha256Hex ([System.Text.UTF8Encoding]::new($false).GetBytes($metadataJson))
$manifest = foreach ($entry in $manifest) {
  [pscustomobject][ordered]@{
    manifest_id = $manifestId
    version = $entry.version
    name = $entry.name
    path = $entry.path
    size = $entry.size
    sha256_raw = $entry.sha256_raw
    sha256_lf_normalized = $entry.sha256_lf_normalized
    origin = $entry.origin
    local_relation = $entry.local_relation
    classification = $entry.classification
    remote_statement_evidence = $entry.remote_statement_evidence
  }
}
$csv = @($manifest | Sort-Object version, origin | ConvertTo-Csv -NoTypeInformation)
$csvText = ($csv -join "`n") + "`n"
$csvBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($csvText)
$metadata = [ordered]@{
  manifest_id = $manifestId
  identity = $identityMetadata
  payload = [ordered]@{
    filename = $manifestOutputName
    sha256 = Get-Sha256Hex $csvBytes
    bytes = $csvBytes.Length
    rows = $manifest.Count
  }
}
$metadataText = ($metadata | ConvertTo-Json -Depth 9 -Compress) + "`n"
Write-TextAtomically $outputFull $csvText 'manifest output' $evidenceFull
Write-TextAtomically $metadataFull $metadataText 'manifest metadata output' $evidenceFull

$classes = $manifest |
  Group-Object version |
  ForEach-Object { $_.Group[0] } |
  Group-Object classification |
  Sort-Object Name |
  ForEach-Object { "$($_.Name)=$($_.Count)" }
$relations = $manifest |
  Where-Object { $_.local_relation } |
  Group-Object version |
  ForEach-Object { $_.Group[0] } |
  Group-Object local_relation |
  Sort-Object Name |
  ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output "Manifest id=$manifestId; rows=$($manifest.Count); versions=$($byVersion.Count); canonical=$($canonical.Count); recovery=$($recovery.Count); remote=$($remote.Count); $($classes -join '; '); local-relations: $($relations -join '; ')"
