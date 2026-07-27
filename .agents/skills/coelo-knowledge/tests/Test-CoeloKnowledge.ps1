[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $skillRoot 'scripts\Test-CoeloKnowledge.ps1'
$searcher = Join-Path $skillRoot 'scripts\Search-CoeloKnowledge.ps1'

if (-not (Test-Path -LiteralPath $validator)) {
  throw "RED: validator ausente em $validator"
}
if (-not (Test-Path -LiteralPath $searcher)) {
  throw "RED: consulta ausente em $searcher"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "coelo-knowledge-tests-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path (Join-Path $testRoot 'docs\knowledge\team') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'docs\knowledge\admin') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'docs\knowledge\users') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $testRoot 'AGENTS.md') -Value '# Source'

function Write-Article {
  param(
    [Parameter(Mandatory)][string]$RelativePath,
    [Parameter(Mandatory)][string]$Audience,
    [string]$ExtraBody = ''
  )

  $content = @"
---
title: "Artigo de teste"
knowledge_id: "test-capability"
source: "AGENTS.md"
status: "draft"
generated_at: "2026-07-27"
audience: "$Audience"
surfaces: ["superadmin"]
visibility: "internal"
review_owner: "Produto e Engenharia"
---

# Artigo de teste

Conteudo reutilizavel e sem dados pessoais.
$ExtraBody
"@
  Set-Content -LiteralPath (Join-Path $testRoot $RelativePath) -Value $content
}

try {
  Write-Article -RelativePath 'docs\knowledge\team\valid.md' -Audience 'team'
  & $validator -Root $testRoot | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Artigo válido foi rejeitado.' }

  Write-Article -RelativePath 'docs\knowledge\admin\wrong-audience.md' -Audience 'user'
  & $validator -Root $testRoot -Quiet
  if ($LASTEXITCODE -eq 0) { throw 'Audiência divergente da pasta foi aceita.' }
  Remove-Item -LiteralPath (Join-Path $testRoot 'docs\knowledge\admin\wrong-audience.md')

  Write-Article -RelativePath 'docs\knowledge\users\sensitive.md' -Audience 'user' -ExtraBody 'CPF 123.456.789-09 e service_role=segredo'
  & $validator -Root $testRoot -Quiet
  if ($LASTEXITCODE -eq 0) { throw 'Conteúdo sensível foi aceito.' }
  Remove-Item -LiteralPath (Join-Path $testRoot 'docs\knowledge\users\sensitive.md')

  Write-Article -RelativePath 'docs\knowledge\team\missing-source.md' -Audience 'team'
  (Get-Content -LiteralPath (Join-Path $testRoot 'docs\knowledge\team\missing-source.md') -Raw).
    Replace('source: "AGENTS.md"', 'source: "docs/nao-existe.md"') |
    Set-Content -LiteralPath (Join-Path $testRoot 'docs\knowledge\team\missing-source.md')
  & $validator -Root $testRoot -Quiet
  if ($LASTEXITCODE -eq 0) { throw 'Fonte inexistente foi aceita.' }
  Remove-Item -LiteralPath (Join-Path $testRoot 'docs\knowledge\team\missing-source.md')

  Write-Article -RelativePath 'docs\knowledge\admin\admin.md' -Audience 'admin'
  $teamResults = @(& $searcher -Root $testRoot -Audience team -Query 'reutilizavel')
  if ($teamResults.Count -ne 1 -or $teamResults[0] -notmatch 'team[\\/]valid.md') {
    throw "Consulta não filtrou corretamente a audiência team: $($teamResults -join ', ')"
  }

  $scenarios = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'skill-scenarios.json') -Raw | ConvertFrom-Json
  $expectedOutcomes = @(
    'update-canonical-or-separated-projection',
    'no-op',
    'separate-articles-with-shared-knowledge-id',
    'reject-sensitive-content',
    'record-open-question'
  )
  foreach ($outcome in $expectedOutcomes) {
    if ($outcome -notin $scenarios.expected) {
      throw "Cenário obrigatório ausente: $outcome"
    }
  }

  Write-Output 'PASS: validação, consulta e cenários da memória Coelo.'
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
