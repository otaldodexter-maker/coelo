[CmdletBinding()]
param(
  [ValidateSet('Prepare', 'Verify', 'Clean')]
  [string]$Mode = 'Prepare'
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
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
  $trackedMirrorFiles = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::OrdinalIgnoreCase
  )
  $trackedPaths = @(
    & git -C $repositoryRoot ls-files -- 'packages/coelo_database/supabase/migrations/*.sql'
  )
  if ($LASTEXITCODE -ne 0) { throw 'cannot inventory tracked migration mirrors' }
  foreach ($trackedPath in $trackedPaths) {
    [void]$trackedMirrorFiles.Add(
      [IO.Path]::GetFullPath((Join-Path $repositoryRoot $trackedPath))
    )
  }
  Get-ChildItem -LiteralPath $mirrorFull -File -Filter '*.sql' |
    ForEach-Object {
      $candidate = [System.IO.Path]::GetFullPath($_.FullName)
      if (-not $candidate.StartsWith($mirrorFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove file outside mirror: $candidate"
      }
      if (-not $trackedMirrorFiles.Contains($candidate)) {
        Remove-Item -LiteralPath $candidate -Force
      }
    }
  return
}

if ($Mode -eq 'Prepare') {
  & $PSCommandPath -Mode Clean
  foreach ($source in $canonical) {
    $target = Join-Path $mirrorFull $source.Name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
      $sourceHash = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
      $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
      if ($sourceHash -cne $targetHash) {
        throw "tracked migration mirror differs from canonical source: $($source.Name)"
      }
    }
    else {
      Copy-Item -LiteralPath $source.FullName -Destination $target
    }
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
