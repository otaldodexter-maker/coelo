[CmdletBinding()]
param([string]$TargetVersion = '20260908000049')

$ErrorActionPreference = 'Stop'

function Assert-FReadGreenDerivedFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "FReadDirectoryContractGreenDerived input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "FReadDirectoryContractGreenDerived input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-FReadGreenDerivedHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash(
      [Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

# This descriptor permits one local four-character materialization only.
# It neither changes the canonical parent selection nor authorizes execution.
$descriptorFile = Assert-FReadGreenDerivedFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-FReadGreenDerivedHash $descriptorFile.FullName) -cne 'ec6435a0869c6356cf305cb01148a4cbf9e1f1d08e5277d35f42c9dbe3b3db67') {
  throw 'FReadDirectoryContractGreenDerived descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "FReadDirectoryContractGreenDerived requires target 20260908000049; received $TargetVersion"
}
$materialization = $descriptor.forms_definition_materialization
$converterRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'FReadDirectoryContractRedDerived'
$converter = Assert-FReadGreenDerivedFile (Join-Path $converterRoot $materialization.converter)
if ((Get-FReadGreenDerivedHash $converter.FullName) -cne $materialization.converter_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractGreenDerived dependency hash mismatch: converter'
}
$parentRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'FReadDirectoryContractGreen'
$parentDescriptor = Assert-FReadGreenDerivedFile (Join-Path $parentRoot 'profile.json')
if ((Get-FReadGreenDerivedHash $parentDescriptor.FullName) -cne $descriptor.parent.descriptor_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractGreenDerived dependency hash mismatch: parent descriptor'
}
$parentResolver = Assert-FReadGreenDerivedFile (Join-Path $parentRoot 'Resolve-FReadDirectoryContractGreen.ps1')
if ((Get-FReadGreenDerivedHash $parentResolver.FullName) -cne $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractGreenDerived dependency hash mismatch: parent resolver'
}

# The checked parent resolver validates the original Auth45+4+2 names/hashes.
# No converter runs here: Invoke uses this before staging or Docker inspection.
$parent = & $parentResolver.FullName -TargetVersion $TargetVersion
if ($parent.Canonical.Count -ne $descriptor.planned_counts.canonical -or
    $parent.Preflight.Count -ne $descriptor.planned_counts.preflight -or
    ($parent.Canonical.Count + $parent.Preflight.Count) -ne $descriptor.planned_counts.total -or
    @($parent.Canonical | Where-Object Name -eq $materialization.file).Count -ne 1) {
  throw 'FReadDirectoryContractGreenDerived requires unchanged canonical Green51 and one Forms definition source'
}
[pscustomobject]@{
  Canonical = $parent.Canonical
  Preflight = $parent.Preflight
  Additional = $parent.Additional
  ManifestHash = $parent.ManifestHash
  FormsDefinitionMaterialization = [pscustomobject]@{
    SourceMigration = $materialization.file
    SourceSha256CrlfUtf8 = $materialization.source_sha256_crlf_utf8
    DerivedSha256CrlfUtf8 = $materialization.derived_sha256_crlf_utf8
    ConverterPath = $converter.FullName
    ConverterSha256CrlfUtf8 = $materialization.converter_sha256_crlf_utf8
    InsertedCharacterCount = $materialization.inserted_character_count
  }
}
