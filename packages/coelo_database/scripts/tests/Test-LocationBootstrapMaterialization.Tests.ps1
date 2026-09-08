$ErrorActionPreference = 'Stop'
$fixtures = Join-Path $PSScriptRoot '../../tests/fixtures'
$sourcePath = Join-Path $fixtures 'location_catalog_v2_capability_bootstrap.sql'
$derivedPath = Join-Path $fixtures '20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
$expectedSourceHash = '3DD0BF5C11E52A68102E3E707E48835EB676513C235DAAB5DEFCDB1E7AD24BFB'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash -ne $expectedSourceHash) {
  throw 'Source bootstrap hash drift; obtain a newly reviewed nominal source.'
}
if (-not (Test-Path -LiteralPath $derivedPath)) { throw 'RED: local materialization is missing.' }
$source = (Get-Content -Raw -LiteralPath $sourcePath).Replace("`r`n", "`n")
$derived = (Get-Content -Raw -LiteralPath $derivedPath).Replace("`r`n", "`n")
$insertion = "begin;`nset local coelo.local_replay = 'location-catalog-v2';"
$expected = $source.Replace("begin;`n", "$insertion`n")
if ($derived -cne $expected) { throw 'RED: only the reviewed SET LOCAL after BEGIN may differ.' }
Write-Output 'PASS: source SHA256 preserved; derivative differs only by transaction-local opt-in. SQL NOT executed.'
