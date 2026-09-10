[CmdletBinding()]
param([string]$TargetVersion = '20260901200206')

$ErrorActionPreference = 'Stop'

function Assert-FReadDerivedFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "FReadDirectoryContractRedDerived input is missing: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "FReadDirectoryContractRedDerived input cannot contain a reparse point: $($cursor.FullName)"
    }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item
}

function Get-FReadDerivedHash([string]$Path) {
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
$descriptorFile = Assert-FReadDerivedFile (Join-Path $PSScriptRoot 'profile.json')
if ((Get-FReadDerivedHash $descriptorFile.FullName) -cne '449186e4598522945baabad162caf5700bcd6d01dde0e8de360d8f668ecab04a') {
  throw 'FReadDirectoryContractRedDerived descriptor hash mismatch'
}
$descriptor = [IO.File]::ReadAllText($descriptorFile.FullName) | ConvertFrom-Json
if ($TargetVersion -cne $descriptor.target_version) {
  throw "FReadDirectoryContractRedDerived requires target 20260901200206; received $TargetVersion"
}
$materialization = $descriptor.forms_definition_materialization
$converter = Assert-FReadDerivedFile (Join-Path $PSScriptRoot $materialization.converter)
if ((Get-FReadDerivedHash $converter.FullName) -cne $materialization.converter_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractRedDerived dependency hash mismatch: converter'
}
$parentRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'FReadDirectoryContractRed'
$parentDescriptor = Assert-FReadDerivedFile (Join-Path $parentRoot 'profile.json')
if ((Get-FReadDerivedHash $parentDescriptor.FullName) -cne $descriptor.parent.descriptor_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractRedDerived dependency hash mismatch: parent descriptor'
}
$parentResolver = Assert-FReadDerivedFile (Join-Path $parentRoot 'Resolve-FReadDirectoryContractRed.ps1')
if ((Get-FReadDerivedHash $parentResolver.FullName) -cne $descriptor.parent.resolver_sha256_crlf_utf8) {
  throw 'FReadDirectoryContractRedDerived dependency hash mismatch: parent resolver'
}

# The checked parent resolver validates the original Auth45+3+2 names/hashes.
# No converter runs here: Invoke uses this before staging or Docker inspection.
$parent = & $parentResolver.FullName -TargetVersion $TargetVersion
if ($parent.Canonical.Count -ne $descriptor.planned_counts.canonical -or
    $parent.Preflight.Count -ne $descriptor.planned_counts.preflight -or
    ($parent.Canonical.Count + $parent.Preflight.Count) -ne $descriptor.planned_counts.total -or
    @($parent.Canonical | Where-Object Name -eq $materialization.file).Count -ne 1) {
  throw 'FReadDirectoryContractRedDerived requires unchanged RED50 and one Forms definition source'
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
