[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Query,
  [ValidateSet('all', 'team', 'admin', 'user')][string]$Audience = 'all',
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$knowledgeRoot = Join-Path $Root 'docs\knowledge'
$folders = switch ($Audience) {
  'team' { @('team') }
  'admin' { @('admin') }
  'user' { @('users') }
  default { @('team', 'admin', 'users') }
}

function Convert-ToRelativePath {
  param([string]$BasePath, [string]$Path)

  $baseUri = [uri]($BasePath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar)
  $pathUri = [uri]$Path
  return [uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).
    Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

foreach ($folder in $folders) {
  $audienceRoot = Join-Path $knowledgeRoot $folder
  if (-not (Test-Path -LiteralPath $audienceRoot -PathType Container)) {
    continue
  }

  Get-ChildItem -LiteralPath $audienceRoot -Filter '*.md' -File -Recurse |
    Select-String -Pattern ([regex]::Escape($Query)) -List |
    ForEach-Object {
      Convert-ToRelativePath -BasePath $Root -Path $_.Path
    }
}
