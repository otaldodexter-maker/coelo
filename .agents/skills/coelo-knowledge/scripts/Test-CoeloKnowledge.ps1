[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$knowledgeRoot = Join-Path $Root 'docs\knowledge'
$requiredFields = @(
  'title',
  'knowledge_id',
  'source',
  'status',
  'generated_at',
  'audience',
  'surfaces',
  'visibility',
  'review_owner'
)
$audienceByFolder = @{
  team = 'team'
  admin = 'admin'
  users = 'user'
}
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
  param([string]$Path, [string]$Message)
  $errors.Add("$Path`: $Message")
}

function Convert-ToRelativePath {
  param([string]$BasePath, [string]$Path)

  $baseUri = [uri]($BasePath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar)
  $pathUri = [uri]$Path
  return [uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).
    Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Read-Frontmatter {
  param([string]$Path)

  $lines = Get-Content -LiteralPath $Path
  if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
    return $null
  }

  $closingIndex = -1
  for ($index = 1; $index -lt $lines.Count; $index++) {
    if ($lines[$index].Trim() -eq '---') {
      $closingIndex = $index
      break
    }
  }
  if ($closingIndex -lt 2) {
    return $null
  }

  $metadata = @{}
  foreach ($line in $lines[1..($closingIndex - 1)]) {
    if ($line -match '^\s*([a-z_]+)\s*:\s*(.*?)\s*$') {
      $value = $Matches[2].Trim()
      if (
        ($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))
      ) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $metadata[$Matches[1]] = $value
    }
  }
  return $metadata
}

if (-not (Test-Path -LiteralPath $knowledgeRoot -PathType Container)) {
  Add-ValidationError -Path 'docs/knowledge' -Message 'diretório ausente'
}
else {
  foreach ($folder in $audienceByFolder.Keys) {
    $audienceRoot = Join-Path $knowledgeRoot $folder
    if (-not (Test-Path -LiteralPath $audienceRoot -PathType Container)) {
      continue
    }

    foreach ($article in Get-ChildItem -LiteralPath $audienceRoot -Filter '*.md' -File -Recurse) {
      $relativePath = Convert-ToRelativePath -BasePath $Root -Path $article.FullName
      $metadata = Read-Frontmatter -Path $article.FullName
      if ($null -eq $metadata) {
        Add-ValidationError -Path $relativePath -Message 'frontmatter YAML ausente ou inválido'
        continue
      }

      foreach ($field in $requiredFields) {
        if (-not $metadata.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($metadata[$field])) {
          Add-ValidationError -Path $relativePath -Message "campo obrigatório ausente: $field"
        }
      }

      if ($metadata.status -and $metadata.status -notin @('draft', 'validated', 'deprecated')) {
        Add-ValidationError -Path $relativePath -Message "status inválido: $($metadata.status)"
      }
      if ($metadata.audience -and $metadata.audience -ne $audienceByFolder[$folder]) {
        Add-ValidationError -Path $relativePath -Message "audience '$($metadata.audience)' diverge da pasta '$folder'"
      }
      if ($metadata.generated_at -and $metadata.generated_at -notmatch '^\d{4}-\d{2}-\d{2}$') {
        Add-ValidationError -Path $relativePath -Message 'generated_at deve usar YYYY-MM-DD'
      }
      if ($metadata.knowledge_id -and $metadata.knowledge_id -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        Add-ValidationError -Path $relativePath -Message 'knowledge_id deve usar kebab-case'
      }

      if ($metadata.source) {
        if ([System.IO.Path]::IsPathRooted($metadata.source)) {
          Add-ValidationError -Path $relativePath -Message 'source deve ser caminho relativo ao repositório'
        }
        else {
          $sourcePath = Join-Path $Root $metadata.source
          if (-not (Test-Path -LiteralPath $sourcePath)) {
            Add-ValidationError -Path $relativePath -Message "source inexistente: $($metadata.source)"
          }
        }
      }

      $content = Get-Content -LiteralPath $article.FullName -Raw
      $sensitivePatterns = [ordered]@{
        'CPF' = '\b\d{3}\.\d{3}\.\d{3}-\d{2}\b'
        'service_role' = '(?i)\bservice_role\b'
        'chave secreta' = '(?i)\b(?:secret|token|api[_-]?key)\s*[:=]\s*\S+'
        'chave OpenAI' = '\bsk-(?:proj-)?[A-Za-z0-9_-]{12,}\b'
        'JWT' = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b'
        'conversa bruta' = '(?im)^\s*(?:usuário|usuario|assistente|user|assistant)\s*:'
      }
      foreach ($entry in $sensitivePatterns.GetEnumerator()) {
        if ($content -match $entry.Value) {
          Add-ValidationError -Path $relativePath -Message "conteúdo proibido detectado: $($entry.Key)"
        }
      }
    }
  }
}

if ($errors.Count -gt 0) {
  if (-not $Quiet) {
    $errors | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    Write-Output "FAIL: $($errors.Count) erro(s) na base de conhecimento."
  }
  exit 1
}

if (-not $Quiet) {
  Write-Output 'PASS: base de conhecimento válida.'
}
exit 0
