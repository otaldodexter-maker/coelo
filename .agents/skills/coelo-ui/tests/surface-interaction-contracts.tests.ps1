$ErrorActionPreference = 'Stop'

$referencePath = Join-Path $PSScriptRoot '..\references\surface-interaction-contracts.md'
$skillPath = Join-Path $PSScriptRoot '..\SKILL.md'

function Assert-Contains {
  param(
    [string]$Content,
    [string]$Expected,
    [string]$Source,
    [string]$Label
  )

  if (-not $Content.Contains($Expected)) {
    throw "$Label must contain '$Expected' in $Source."
  }
}

if (-not (Test-Path -LiteralPath $referencePath)) {
  throw "Missing required surface interaction reference: $referencePath"
}

$reference = Get-Content -LiteralPath $referencePath -Raw
foreach ($expected in @(
  'colorScheme.surface',
  'colorScheme.primaryContainer',
  'CoeloRadius.md',
  'CoeloSpacing.spaceHalf',
  'colorScheme.errorContainer',
  'CoeloRadius.full',
  'CoeloAdminMultiSelectFilter'
)) {
  Assert-Contains -Content $reference -Expected $expected -Source $referencePath -Label 'Surface interaction reference'
}

$skill = Get-Content -LiteralPath $skillPath -Raw
Assert-Contains -Content $skill -Expected 'references/surface-interaction-contracts.md' -Source $skillPath -Label 'Coelo UI skill'
Assert-Contains -Content $skill -Expected 'obrigatoriamente o' -Source $skillPath -Label 'Coelo UI skill routing'
Assert-Contains -Content $skill -Expected 'popup' -Source $skillPath -Label 'Coelo UI skill routing'
Assert-Contains -Content $skill -Expected 'filtro' -Source $skillPath -Label 'Coelo UI skill routing'
Assert-Contains -Content $skill -Expected 'dismiss' -Source $skillPath -Label 'Coelo UI skill routing'

Write-Output 'surface-interaction-contracts.tests.ps1: PASS'
