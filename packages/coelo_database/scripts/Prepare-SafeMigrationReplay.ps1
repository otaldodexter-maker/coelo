[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DestinationMigrationsRoot,

  [switch]$FoundationOnly,

  [switch]$AuthOnly,

  [ValidateSet('N01PrerequisitesRed', 'A01DirectoryContractRed', 'FReadDirectoryContractRed', 'FReadDirectoryContractGreen', 'ModelReadAuthorizationRed', 'A01DirectoryAuditRed', 'FReadDirectoryContractRedDerived', 'ModelReadAuthorizationGreen', 'A01DirectoryAuditGreen', 'FReadDirectoryContractGreenDerived')]
  [string]$NominalProfile,

  [string[]]$AdditionalMigration = @()
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$canonicalRoot = Join-Path $packageRoot 'migrations'
$preflightRoot = Join-Path $packageRoot 'replay'
$foundationManifestPath = Join-Path $preflightRoot 'foundation-migrations.sha256'
$destinationRoot = [IO.Path]::GetFullPath($DestinationMigrationsRoot)

if ($NominalProfile -and ($FoundationOnly -or $AuthOnly -or $AdditionalMigration.Count -gt 0)) {
  throw 'nominal replay cannot be combined with FoundationOnly, AuthOnly or AdditionalMigration'
}
if ($FoundationOnly -and $AuthOnly) {
  throw 'foundation-only and Auth-only replay profiles are mutually exclusive'
}

function Get-NormalizedTextSha256([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($content)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally {
    $sha256.Dispose()
  }
}

function Get-FileSha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString('X2') }) -join '')
  }
  finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

function Assert-NormalDirectory([string]$Path, [string]$Label) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if (-not $item.PSIsContainer) { throw "$Label is not a directory: $Path" }
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "$Label cannot be a reparse point: $Path"
  }
  return [IO.Path]::GetFullPath($item.FullName)
}

$canonicalFull = Assert-NormalDirectory $canonicalRoot 'canonical root'
$preflightFull = Assert-NormalDirectory $preflightRoot 'preflight root'
$destinationFull = Assert-NormalDirectory $destinationRoot 'destination root'
$repositoryFull = Assert-NormalDirectory $repositoryRoot 'repository root'

if ($destinationFull -eq $repositoryFull -or
    $destinationFull.StartsWith($repositoryFull.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'destination must be an isolated local directory outside the repository'
}
if (@(Get-ChildItem -LiteralPath $destinationFull -Force).Count -ne 0) {
  throw 'destination migration directory must be empty'
}

$canonical = @(Get-ChildItem -LiteralPath $canonicalFull -File -Filter '*.sql' | Sort-Object Name)
$preflight = @(Get-ChildItem -LiteralPath $preflightFull -File -Filter '*.sql' | Sort-Object Name)
$foundationManifestHash = $null
$additionalCanonical = @()
$foundationBoundaryVersion = $null
if ($NominalProfile) {
  $nominalResolverRelative = switch ($NominalProfile) {
    'N01PrerequisitesRed' { 'profiles\N01PrerequisitesRed\Resolve-N01PrerequisitesRed.ps1' }
    'A01DirectoryContractRed' { 'profiles\A01DirectoryContractRed\Resolve-A01DirectoryContractRed.ps1' }
    'FReadDirectoryContractRed' { 'profiles\FReadDirectoryContractRed\Resolve-FReadDirectoryContractRed.ps1' }
    'FReadDirectoryContractGreen' { 'profiles\FReadDirectoryContractGreen\Resolve-FReadDirectoryContractGreen.ps1' }
    'ModelReadAuthorizationRed' { 'profiles\ModelReadAuthorizationRed\Resolve-ModelReadAuthorizationRed.ps1' }
    'ModelReadAuthorizationGreen' { 'profiles\ModelReadAuthorizationGreen\Resolve-ModelReadAuthorizationGreen.ps1' }
    'A01DirectoryAuditRed' { 'profiles\A01DirectoryAuditRed\Resolve-A01DirectoryAuditRed.ps1' }
    'A01DirectoryAuditGreen' { 'profiles\A01DirectoryAuditGreen\Resolve-A01DirectoryAuditGreen.ps1' }
    'FReadDirectoryContractRedDerived' { 'profiles\FReadDirectoryContractRedDerived\Resolve-FReadDirectoryContractRedDerived.ps1' }
    'FReadDirectoryContractGreenDerived' { 'profiles\FReadDirectoryContractGreenDerived\Resolve-FReadDirectoryContractGreenDerived.ps1' }
  }
  $nominalResolver = Join-Path $preflightRoot $nominalResolverRelative
  $nominalCursor = Get-Item -LiteralPath $nominalResolver -Force -ErrorAction Stop
  if ($nominalCursor.PSIsContainer) { throw 'nominal replay resolver must be a file' }
  while ($null -ne $nominalCursor) {
    if (($nominalCursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "nominal replay resolver contains a reparse point: $($nominalCursor.FullName)"
    }
    $nominalCursor = if ($nominalCursor.PSIsContainer) { $nominalCursor.Parent } else { $nominalCursor.Directory }
  }
  $nominal = & $nominalResolver
  $canonical = @($nominal.Canonical)
  $preflight = @($nominal.Preflight)
  $additionalCanonical = @($nominal.Additional)
  $foundationManifestHash = $nominal.ManifestHash
}
if ($AdditionalMigration.Count -gt 0 -and -not ($FoundationOnly -or $AuthOnly)) {
  throw 'additional migrations require FoundationOnly or AuthOnly'
}
if ($FoundationOnly -or $AuthOnly) {
  if (-not (Test-Path -LiteralPath $foundationManifestPath -PathType Leaf)) {
    throw 'foundation replay manifest is missing'
  }
  $manifestItem = Get-Item -LiteralPath $foundationManifestPath -Force
  if (($manifestItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw 'foundation replay manifest cannot be a reparse point'
  }
  $manifestEntries = @(
    Get-Content -LiteralPath $foundationManifestPath |
      Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
      ForEach-Object {
        if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
          throw "invalid foundation replay manifest entry: $_"
        }
        [pscustomobject]@{ Name = $Matches[1]; Version = $Matches[2]; Hash = $Matches[3] }
      }
  )
  if ($manifestEntries.Count -eq 0 -or
      @($manifestEntries.Name | Sort-Object -Unique).Count -ne $manifestEntries.Count -or
      @($manifestEntries.Version | Sort-Object -Unique).Count -ne $manifestEntries.Count -or
      @(Compare-Object @($manifestEntries.Name) @($manifestEntries.Name | Sort-Object) -SyncWindow 0).Count -ne 0) {
    throw 'foundation replay manifest must be non-empty, unique, and strictly ordered'
  }
  $foundationBoundaryEntries = @(
    $manifestEntries | Where-Object { $_.Version -eq '20260901124500' }
  )
  if ($foundationBoundaryEntries.Count -ne 1) {
    throw 'foundation replay manifest must contain the reviewed extension boundary'
  }
  $foundationBoundaryVersion = $foundationBoundaryEntries[0].Version
  $canonicalByName = @{}
  foreach ($migration in $canonical) { $canonicalByName[$migration.Name] = $migration }
  $canonical = @($manifestEntries | ForEach-Object {
    if (-not $canonicalByName.ContainsKey($_.Name)) {
      throw "foundation replay migration is missing: $($_.Name)"
    }
    $migration = $canonicalByName[$_.Name]
    $actualHash = Get-NormalizedTextSha256 $migration.FullName
    if ($actualHash -cne $_.Hash) {
      throw "foundation replay migration hash mismatch: $($_.Name)"
    }
    $migration
  })
  if ($canonical.Count -ne $manifestEntries.Count) {
    throw 'foundation replay manifest count mismatch'
  }
  if ($AuthOnly) {
    $canonical = @($canonical | Where-Object {
      $version = $_.Name.Substring(0, 14)
      $version -le '20260812001975' -or
        $version -in @(
          '20260827214000',
          '20260827233000',
          '20260901124500',
          '20260901200206'
        )
    })
  }
  $additionalBoundaryVersion = if ($AuthOnly) { '20260901200206' } else { $foundationBoundaryVersion }
  if ($AdditionalMigration.Count -gt 0) {
    $additionalEntries = @($AdditionalMigration | ForEach-Object {
      if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
        throw "invalid additional migration entry: $_"
      }
      [pscustomobject]@{ Name = $Matches[1]; Version = $Matches[2]; Hash = $Matches[3] }
    })
    if ($additionalEntries.Count -gt 0) {
      if (@($additionalEntries.Name | Sort-Object -Unique).Count -ne $additionalEntries.Count -or
          @($additionalEntries.Version | Sort-Object -Unique).Count -ne $additionalEntries.Count -or
          @(Compare-Object @($additionalEntries.Name) @($additionalEntries.Name | Sort-Object) -SyncWindow 0).Count -ne 0) {
        throw 'additional migrations must be unique and strictly ordered'
      }
      if (@($additionalEntries | Where-Object {
            $_.Version -le $additionalBoundaryVersion
          }).Count -ne 0) {
        if ($AuthOnly) {
          throw 'additional migrations must be newer than the Auth-only boundary'
        }
        throw 'additional migrations must be newer than the foundation manifest boundary'
      }
      $additionalCanonical = @($additionalEntries | ForEach-Object {
        if (-not $canonicalByName.ContainsKey($_.Name)) {
          throw "additional canonical migration is missing: $($_.Name)"
        }
        $migration = $canonicalByName[$_.Name]
        if (($migration.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
          throw "additional migration cannot be a reparse point: $($migration.FullName)"
        }
        $actualHash = Get-NormalizedTextSha256 $migration.FullName
        if ($actualHash -cne $_.Hash) {
          throw "additional migration hash mismatch: $($_.Name)"
        }
        $migration
      })
      $canonical = @($canonical) + @($additionalCanonical)
    }
  }
  $foundationManifestHash = Get-FileSha256 $foundationManifestPath
}
if ($canonical.Count -eq 0 -or
    $preflight.Count -ne 2 -or
    $preflight[0].Name -ne '20260811151253_assert_function_execute_preflight.sql' -or
    $preflight[1].Name -ne '20260811215452_access_profile_labels_replay_bridge.sql') {
  throw "unexpected replay inputs: canonical=$($canonical.Count) preflight=$($preflight.Count)"
}

$combined = @($canonical) + @($preflight) | Sort-Object Name
$versions = @($combined | ForEach-Object {
  if ($_.Name -notmatch '^(\d{14})_[a-z0-9_]+\.sql$') {
    throw "invalid migration filename: $($_.Name)"
  }
  $Matches[1]
})
if (@($versions | Sort-Object -Unique).Count -ne $versions.Count) {
  throw 'safe replay contains duplicate migration versions'
}
$preflightIndex = [Array]::IndexOf(@($combined.Name), $preflight[0].Name)
if ($preflightIndex -lt 0 -or
    $preflightIndex + 1 -ge $combined.Count -or
    $combined[$preflightIndex + 1].Name -ne '20260811151254_group_management_security.sql') {
  throw 'safe replay preflight must be immediately before the historical Groups migration'
}
$labelBridgeIndex = [Array]::IndexOf(@($combined.Name), $preflight[1].Name)
$auditProductionIndex = [Array]::IndexOf(
  @($combined.Name),
  '20260812000847_audit_production.sql'
)
if ($labelBridgeIndex -lt 1 -or
    $combined[$labelBridgeIndex - 1].Name -ne '20260811215451_access_profile_management_v2.sql' -or
    $auditProductionIndex -le $labelBridgeIndex) {
  throw 'label replay bridge must immediately follow access-profile management v2 and precede audit production'
}

if ($NominalProfile -in @('FReadDirectoryContractRedDerived', 'FReadDirectoryContractGreenDerived')) {
  # This reviewed local derivation runs before the remaining input copies.
  $derivedMetadata = $nominal.FormsDefinitionMaterialization
  $derivedName = '20260813155005_forms_definition_and_capabilities.sql'
  $derivedSources = @($canonical | Where-Object Name -ceq $derivedName)
  if ($derivedSources.Count -ne 1 -or $derivedMetadata.SourceMigration -cne $derivedName -or
      $derivedMetadata.InsertedCharacterCount -ne 4) {
    throw 'derived materialization requires exactly the reviewed Forms definition and four characters'
  }
  if ($DestinationMigrationsRoot -notmatch '^[A-Za-z]:[\\/]') {
    throw 'derived destination must be an absolute local path'
  }
  $derivedTemporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
  if (-not $destinationFull.StartsWith($derivedTemporaryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'derived destination must be below the local temporary root'
  }
  function Assert-FReadDerivedMaterializationPath([string]$Path, [bool]$IsDirectory) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "derived materialization path is missing: $Path" }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -ne $IsDirectory) { throw "derived materialization path kind is invalid: $Path" }
    $cursor = $item
    while ($null -ne $cursor) {
      if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "derived materialization path contains a reparse point: $($cursor.FullName)"
      }
      $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
    }
    return $item
  }
  $null = Assert-FReadDerivedMaterializationPath $destinationFull $true
  $derivedSource = Assert-FReadDerivedMaterializationPath $derivedSources[0].FullName $false
  $derivedConverter = Assert-FReadDerivedMaterializationPath $derivedMetadata.ConverterPath $false
  if ((Get-NormalizedTextSha256 $derivedSource.FullName) -cne $derivedMetadata.SourceSha256CrlfUtf8 -or
      (Get-NormalizedTextSha256 $derivedConverter.FullName) -cne $derivedMetadata.ConverterSha256CrlfUtf8) {
    throw 'derived materialization input hash mismatch'
  }
  $derivedOriginalRawHash = Get-FileSha256 $derivedSource.FullName
  $derivedOriginalLength = $derivedSource.Length
  $derivedTarget = Join-Path $destinationFull $derivedName
  $derivedReceipts = @(& $derivedConverter.FullName -DestinationMigrationsRoot $destinationFull)
  if ($derivedReceipts.Count -ne 1) { throw 'derived materialization must return exactly one receipt' }
  $derivedReceipt = $derivedReceipts[0]
  if ($derivedReceipt.SourceMigration -cne $derivedName -or
      $derivedReceipt.SourceSha256CrlfUtf8 -cne $derivedMetadata.SourceSha256CrlfUtf8 -or
      $derivedReceipt.DerivedSha256CrlfUtf8 -cne $derivedMetadata.DerivedSha256CrlfUtf8 -or
      $derivedReceipt.InsertedCharacterCount -ne 4 -or
      $derivedReceipt.DestinationPath -cne $derivedTarget) {
    throw 'derived materialization receipt mismatch'
  }
  $derivedFile = Assert-FReadDerivedMaterializationPath $derivedTarget $false
  $null = Assert-FReadDerivedMaterializationPath $derivedSource.FullName $false
  if ((Get-FileSha256 $derivedSource.FullName) -cne $derivedOriginalRawHash -or
      (Get-NormalizedTextSha256 $derivedFile.FullName) -cne $derivedMetadata.DerivedSha256CrlfUtf8 -or
      ($derivedFile.Length - $derivedOriginalLength) -ne 4) {
    throw 'derived materialization file or original source mismatch'
  }
}

foreach ($source in @($canonical) + @($preflight)) {
  if ($NominalProfile -in @('FReadDirectoryContractRedDerived', 'FReadDirectoryContractGreenDerived') -and $source.Name -ceq '20260813155005_forms_definition_and_capabilities.sql') { continue }
  $sourceFull = [IO.Path]::GetFullPath($source.FullName)
  if (($source.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "replay input cannot be a reparse point: $sourceFull"
  }
  $target = Join-Path $destinationFull $source.Name
  if (Test-Path -LiteralPath $target) { throw "duplicate replay migration: $($source.Name)" }
  Copy-Item -LiteralPath $sourceFull -Destination $target
}

$generated = @(Get-ChildItem -LiteralPath $destinationFull -File -Filter '*.sql' | Sort-Object Name)
if ($generated.Count -ne ($canonical.Count + $preflight.Count)) {
  throw 'generated safe replay migration count mismatch'
}

$preflightHashes = @($preflight | ForEach-Object {
  "$(($_.BaseName))=$(Get-FileSha256 $_.FullName)"
}) -join ','
$profile = if ($NominalProfile) {
  $NominalProfile
}
elseif ($FoundationOnly) {
  'foundation'
}
elseif ($AuthOnly) {
  'auth'
}
else {
  'full'
}
$manifestEvidence = if ($FoundationOnly -or $AuthOnly -or $NominalProfile) {
  "; manifest_sha256=$foundationManifestHash"
}
else {
  ''
}
"Prepared $($generated.Count) safe replay migrations ($($canonical.Count) canonical + $($preflight.Count) preflight); profile=$profile; additional=$($additionalCanonical.Count)$manifestEvidence; preflight_sha256=$preflightHashes."
