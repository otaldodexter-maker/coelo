[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$DestinationMigrationsRoot
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$sourceName = '20260813155005_forms_definition_and_capabilities.sql'
$sourcePath = Join-Path (Join-Path $packageRoot 'migrations') $sourceName
$sourceHash = '3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36'
$derivedHash = '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe'

function Assert-FReadLocalPath([string]$Path, [bool]$IsDirectory) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -ne $IsDirectory) { throw "unexpected local path kind: $Path" }
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "local Forms materialization path contains a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
}

function Get-FReadMaterializedHash([string]$Text) {
  $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($normalized)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Get-FReadLiteralCount([string]$Text, [string]$Literal) {
  $count = 0
  $offset = 0
  while (($offset = $Text.IndexOf($Literal, $offset, [StringComparison]::Ordinal)) -ge 0) {
    $count++
    $offset += $Literal.Length
  }
  return $count
}

if ($DestinationMigrationsRoot -notmatch '^[A-Za-z]:[\\/]') {
  throw 'destination must be an absolute local path'
}
$destinationFull = [IO.Path]::GetFullPath($DestinationMigrationsRoot).TrimEnd('\')
$repositoryFull = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\')
$temporaryFull = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if ($destinationFull -eq $repositoryFull -or
    $destinationFull.StartsWith($repositoryFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'destination must be outside the repository'
}
if (-not $destinationFull.StartsWith($temporaryFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'destination must be below the local temporary root'
}
Assert-FReadLocalPath $destinationFull $true
Assert-FReadLocalPath $sourcePath $false
$outputPath = Join-Path $destinationFull $sourceName
if (Test-Path -LiteralPath $outputPath) { throw 'destination already exists' }

# Preserve source encoding/line endings. The normalized digests use the same
# CRLF UTF-8 contract as the nominal replay profiles, independent of checkout EOL.
$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
$hasBom = $sourceBytes.Length -ge 3 -and $sourceBytes[0] -eq 239 -and
  $sourceBytes[1] -eq 187 -and $sourceBytes[2] -eq 191
$byteOffset = if ($hasBom) { 3 } else { 0 }
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$sourceText = $utf8.GetString($sourceBytes, $byteOffset, $sourceBytes.Length - $byteOffset)
$sourceLf = $sourceText.Replace("`r`n", "`n").Replace("`r", "`n")
$lineEnding = if ($sourceText.Contains("`r`n")) { "`r`n" } else { "`n" }

# Two reviewed literals only. No SQL parsing bypass or general rewrite rules.
$numericBefore = @'
    if p_config - case when p_kind = 'decimal' then array['min_value','max_value','decimal_places']
                       when p_kind = 'money' then array['min_value','max_value','currency']
                       else array['min_value','max_value'] end <> '{}'::jsonb
'@
$numericAfter = @'
    if p_config - (case when p_kind = 'decimal' then array['min_value','max_value','decimal_places']
                       when p_kind = 'money' then array['min_value','max_value','currency']
                       else array['min_value','max_value'] end) <> '{}'::jsonb
'@
$imageBefore = @'
    if p_config - case when p_kind = 'photo' then array['allow_camera','min_images','max_images']
                       else array['allow_existing','min_images','max_images'] end <> '{}'::jsonb
'@
$imageAfter = @'
    if p_config - (case when p_kind = 'photo' then array['allow_camera','min_images','max_images']
                       else array['allow_existing','min_images','max_images'] end) <> '{}'::jsonb
'@
$pairs = @(
  @{ Name = 'numeric CASE'; Before = $numericBefore; After = $numericAfter },
  @{ Name = 'image CASE'; Before = $imageBefore; After = $imageAfter }
)
foreach ($pair in $pairs) {
  $pair.Before = $pair.Before.Replace("`r`n", "`n")
  $pair.After = $pair.After.Replace("`r`n", "`n")
  if ((Get-FReadLiteralCount $sourceLf $pair.Before) -ne 1) {
    throw "expected exactly one occurrence of $($pair.Name)"
  }
}
if ((Get-FReadMaterializedHash $sourceText) -cne $sourceHash) { throw 'source hash mismatch' }
$derivedText = $sourceText
foreach ($pair in $pairs) {
  $before = $pair.Before.Replace("`n", $lineEnding)
  $after = $pair.After.Replace("`n", $lineEnding)
  if ((Get-FReadLiteralCount $derivedText $before) -ne 1) {
    throw "expected exactly one occurrence with source line endings of $($pair.Name)"
  }
  $derivedText = $derivedText.Replace($before, $after)
}
if ($derivedText.Length - $sourceText.Length -ne 4) { throw 'expected exactly four inserted characters' }
if ((Get-FReadMaterializedHash $derivedText) -cne $derivedHash) { throw 'derived hash mismatch' }
$outputBytes = $utf8.GetBytes($derivedText)
if ($hasBom) { $outputBytes = [byte[]](@(239, 187, 191) + @($outputBytes)) }
if ($outputBytes.Length - $sourceBytes.Length -ne 4) { throw 'expected exactly four inserted bytes' }

# CreateNew also refuses a destination introduced after the existence check.
$stream = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($outputBytes, 0, $outputBytes.Length) } finally { $stream.Dispose() }
[pscustomobject]@{
  SourceMigration = $sourceName
  SourceSha256CrlfUtf8 = $sourceHash
  DerivedSha256CrlfUtf8 = $derivedHash
  InsertedCharacterCount = 4
  DestinationPath = $outputPath
}
