[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DestinationMigrationsRoot
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$canonicalRoot = Join-Path $packageRoot 'migrations'
$preflightRoot = Join-Path $packageRoot 'replay'
$destinationRoot = [IO.Path]::GetFullPath($DestinationMigrationsRoot)

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
if ($canonical.Count -eq 0 -or
    $preflight.Count -ne 1 -or
    $preflight[0].Name -ne '20260811151253_assert_function_execute_preflight.sql') {
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

$preflightHash = (Get-FileHash -LiteralPath $preflight[0].FullName -Algorithm SHA256).Hash
"Prepared $($generated.Count) safe replay migrations ($($canonical.Count) canonical + $($preflight.Count) preflight); preflight_sha256=$preflightHash."
