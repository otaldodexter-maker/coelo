[CmdletBinding()]
param(
  [ValidateSet('Prepare', 'Verify', 'Clean')]
  [string]$Mode = 'Prepare'
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$canonicalRoot = Join-Path $packageRoot 'migrations'
$mirrorRoot = Join-Path $packageRoot 'supabase\migrations'

$packageFull = [System.IO.Path]::GetFullPath($packageRoot)
$canonicalFull = [System.IO.Path]::GetFullPath($canonicalRoot)
$mirrorFull = [System.IO.Path]::GetFullPath($mirrorRoot)

if (-not $canonicalFull.StartsWith($packageFull, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'canonical migration directory escaped package root'
}
if (-not $mirrorFull.StartsWith($packageFull, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'CLI mirror directory escaped package root'
}

New-Item -ItemType Directory -Path $mirrorFull -Force | Out-Null

$canonical = @(
  Get-ChildItem -LiteralPath $canonicalFull -File -Filter '*.sql' |
    Sort-Object Name
)

if ($canonical.Count -eq 0) {
  throw 'no canonical migrations found'
}

if ($Mode -eq 'Clean') {
  Get-ChildItem -LiteralPath $mirrorFull -File -Filter '*.sql' |
    ForEach-Object {
      $candidate = [System.IO.Path]::GetFullPath($_.FullName)
      if (-not $candidate.StartsWith($mirrorFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove file outside mirror: $candidate"
      }
      Remove-Item -LiteralPath $candidate -Force
    }
  return
}

if ($Mode -eq 'Prepare') {
  & $PSCommandPath -Mode Clean
  foreach ($source in $canonical) {
    Copy-Item -LiteralPath $source.FullName -Destination (Join-Path $mirrorFull $source.Name)
  }
}

$mirror = @(
  Get-ChildItem -LiteralPath $mirrorFull -File -Filter '*.sql' |
    Sort-Object Name
)

if ($canonical.Count -ne $mirror.Count) {
  throw "migration count mismatch: canonical=$($canonical.Count) mirror=$($mirror.Count)"
}

for ($index = 0; $index -lt $canonical.Count; $index++) {
  if ($canonical[$index].Name -ne $mirror[$index].Name) {
    throw "migration name mismatch at index $index"
  }
  $sourceHash = (Get-FileHash -LiteralPath $canonical[$index].FullName -Algorithm SHA256).Hash
  $mirrorHash = (Get-FileHash -LiteralPath $mirror[$index].FullName -Algorithm SHA256).Hash
  if ($sourceHash -ne $mirrorHash) {
    throw "migration content mismatch: $($canonical[$index].Name)"
  }
}

Write-Output "Verified $($canonical.Count) canonical migrations."
