[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$LocalProjectRoot,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{14}$')]
  [string]$TargetVersion
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$packageRoot = Split-Path -Parent $scriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$projectRoot = [IO.Path]::GetFullPath($LocalProjectRoot)
$repositoryFull = [IO.Path]::GetFullPath($repositoryRoot)
$supabaseRoot = Join-Path $projectRoot 'supabase'
$configPath = Join-Path $supabaseRoot 'config.toml'
$migrationRoot = Join-Path $supabaseRoot 'migrations'
$projectRefPath = Join-Path $supabaseRoot '.temp\project-ref'
$targetMigration = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'migrations') -File -Filter "$TargetVersion`_*.sql")

if ($projectRoot -eq $repositoryFull -or
    $projectRoot.StartsWith($repositoryFull.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'local replay project must be outside the repository'
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  throw 'local replay project is missing supabase/config.toml'
}
if (Test-Path -LiteralPath $projectRefPath -PathType Leaf) {
  throw 'linked Supabase projects are forbidden for safe local replay'
}
if ($targetMigration.Count -ne 1) {
  throw "target version must identify exactly one canonical migration: $TargetVersion"
}
if (-not (Test-Path -LiteralPath $migrationRoot -PathType Container)) {
  New-Item -ItemType Directory -Path $migrationRoot | Out-Null
}
if (@(Get-ChildItem -LiteralPath $migrationRoot -Force).Count -ne 0) {
  throw 'local replay migration directory must be empty'
}

$started = $false
$generated = @()
$databaseOnlyExcludes = 'gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
try {
  & npx.cmd supabase start --workdir $projectRoot --exclude $databaseOnlyExcludes *> $null
  if ($LASTEXITCODE -ne 0) { throw "supabase start failed with exit code $LASTEXITCODE" }
  $started = $true

  & (Join-Path $scriptRoot 'Prepare-SafeMigrationReplay.ps1') -DestinationMigrationsRoot $migrationRoot
  $generated = @(Get-ChildItem -LiteralPath $migrationRoot -File -Filter '*.sql')

  & npx.cmd supabase db reset --local --no-seed --version $TargetVersion --workdir $projectRoot --yes
  if ($LASTEXITCODE -ne 0) { throw "safe local db reset failed with exit code $LASTEXITCODE" }
}
finally {
  foreach ($file in $generated) {
    Remove-Item -LiteralPath $file.FullName -Force
  }
  if ($started) {
    & npx.cmd supabase stop --workdir $projectRoot --no-backup --yes *> $null
  }
}
