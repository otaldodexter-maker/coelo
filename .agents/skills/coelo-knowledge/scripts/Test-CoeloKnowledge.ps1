[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
  [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
$arguments = @('-X', 'utf8', (Join-Path $PSScriptRoot 'coelo_knowledge.py'), 'validate', '--root', $Root)
if ($Quiet) { $arguments += '--quiet' }
& python @arguments
exit $LASTEXITCODE
