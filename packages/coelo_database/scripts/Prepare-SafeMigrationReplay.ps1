[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DestinationMigrationsRoot,

  [switch]$FoundationOnly,

  [string[]]$AdditionalMigration = @()
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$canonicalRoot = Join-Path $packageRoot 'migrations'
$preflightRoot = Join-Path $packageRoot 'replay'
$foundationManifestPath = Join-Path $preflightRoot 'foundation-migrations.sha256'
$destinationRoot = [IO.Path]::GetFullPath($DestinationMigrationsRoot)

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
if ($AdditionalMigration.Count -gt 0 -and -not $FoundationOnly) {
  throw 'additional migrations require FoundationOnly'
}
if ($FoundationOnly) {
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
  $foundationBoundaryVersion = $manifestEntries[-1].Version
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
          $_.Version -le $foundationBoundaryVersion
        }).Count -ne 0) {
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
  $foundationManifestHash = (Get-FileHash -LiteralPath $foundationManifestPath -Algorithm SHA256).Hash
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
if ($labelBridgeIndex -lt 1 -or
    $combined[$labelBridgeIndex - 1].Name -ne '20260811215451_access_profile_management_v2.sql' -or
    $labelBridgeIndex + 1 -ge $combined.Count -or
    $combined[$labelBridgeIndex + 1].Name -ne '20260812000847_audit_production.sql') {
  throw 'label replay bridge must immediately follow access-profile management v2'
}

foreach ($source in @($canonical) + @($preflight)) {
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
  "$(($_.BaseName))=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
}) -join ','
$profile = if ($FoundationOnly) { 'foundation' } else { 'full' }
$manifestEvidence = if ($FoundationOnly) { "; manifest_sha256=$foundationManifestHash" } else { '' }
"Prepared $($generated.Count) safe replay migrations ($($canonical.Count) canonical + $($preflight.Count) preflight); profile=$profile; additional=$($additionalCanonical.Count)$manifestEvidence; preflight_sha256=$preflightHashes."
