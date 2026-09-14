[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Query,
  [ValidateSet('all', 'team', 'admin', 'user', 'users')][string]$Audience = 'all',
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
  [ValidateSet('validated', 'draft', 'deprecated', 'all')][string]$Status = 'validated',
  [ValidateSet('current', 'future', 'historical', 'superseded', 'all')][string]$Lifecycle = 'current',
  [switch]$Detailed
)
$ErrorActionPreference = 'Stop'
$arguments = @('-X', 'utf8', (Join-Path $PSScriptRoot 'coelo_knowledge.py'), 'search', '--root', $Root,
  '--query', $Query, '--audience', $Audience, '--status', $Status, '--lifecycle', $Lifecycle)
if ($Detailed) { $arguments += '--detailed' }
& python @arguments
exit $LASTEXITCODE
