[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $packageRoot 'replay\foundation-migrations.sha256'
$canonicalRoot = Join-Path $packageRoot 'migrations'

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
$excludedMigrations = @(
  '20260811225000_activity_professional_search.sql',
  '20260811235900_activity_template_catalog_expansion.sql',
  '20260812000000_chat_production_contract.sql',
  '20260812001000_import_export_hub_security.sql',
  '20260812001950_import_export_hub_lifecycle_closure.sql',
  '20260812001975_import_export_hub_unit_lifecycle_bridge.sql',
  '20260827222000_unit_import_export_private_acl_closure.sql',
  '20260827222500_harden_platform_notice_table_access.sql'
)

$entries = @(
  Get-Content -LiteralPath $manifestPath |
    Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
    ForEach-Object {
      if ($_ -notmatch '^((\d{14})_[a-z0-9_]+\.sql)\|([0-9a-f]{64})$') {
        throw "invalid foundation replay manifest entry: $_"
      }
      [pscustomobject]@{ Name = $Matches[1]; Hash = $Matches[3] }
    }
)

if ($entries.Count -ne 54) {
  throw "foundation replay profile must contain exactly 54 canonical migrations; found $($entries.Count)"
}
if ($entries[0].Name -ne '20260623191021_superadmin_foundation_v1.sql' -or
    $entries[-1].Name -ne '20260831195118_activities_v2_actor_provenance_hardening.sql') {
  throw 'foundation replay profile boundaries changed without review'
}
if (@($entries.Name | Where-Object { $_ -in $excludedMigrations }).Count -ne 0) {
  throw 'foundation replay profile admitted an explicitly excluded product migration'
}

foreach ($entry in $entries) {
  $path = Join-Path $canonicalRoot $entry.Name
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "foundation replay migration is missing: $($entry.Name)"
  }
  $actualHash = Get-NormalizedTextSha256 $path
  if ($actualHash -cne $entry.Hash) {
    throw "foundation replay migration hash mismatch: $($entry.Name)"
  }
}

"Foundation replay profile PASS: 54 reviewed canonical migrations; eight product migrations denied; all SHA-256 values match."
