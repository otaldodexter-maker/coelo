[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{14}$')]
  [string]$TargetVersion
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$packageRoot = Split-Path -Parent $scriptRoot
$canonicalConfig = Join-Path $packageRoot 'supabase\config.toml'
$targetMigration = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'migrations') -File -Filter "$TargetVersion`_*.sql")
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$projectId = 'coelo_safe_' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$projectRoot = Join-Path $tempRoot $projectId
$supabaseRoot = Join-Path $projectRoot 'supabase'
$migrationRoot = Join-Path $supabaseRoot 'migrations'
$configPath = Join-Path $supabaseRoot 'config.toml'
$databaseOnlyExcludes = 'gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
$allocatedPorts = [Collections.Generic.HashSet[int]]::new()

function Assert-NoReparseAncestors([string]$Path) {
  $cursor = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "safe replay path contains a reparse point: $($cursor.FullName)"
    }
    $cursor = $cursor.Parent
  }
}

function Assert-NoReparseTree([string]$Path) {
  Assert-NoReparseAncestors $Path
  foreach ($item in Get-ChildItem -LiteralPath $Path -Force -Recurse) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw "safe replay cleanup found a reparse point: $($item.FullName)"
    }
  }
}

function Get-FreeTcpPort {
  do {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
      $listener.Start()
      $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    }
    finally {
      $listener.Stop()
    }
  } until ($allocatedPorts.Add($port))
  return $port
}

function Get-DockerResources([string]$Identity) {
  $containers = @(& docker ps -a --filter "name=$Identity" --format '{{.ID}}')
  if ($LASTEXITCODE -ne 0) { throw 'cannot inspect Docker containers' }
  $volumes = @(& docker volume ls --filter "name=$Identity" --format '{{.Name}}')
  if ($LASTEXITCODE -ne 0) { throw 'cannot inspect Docker volumes' }
  $networks = @(& docker network ls --filter "name=$Identity" --format '{{.ID}}')
  if ($LASTEXITCODE -ne 0) { throw 'cannot inspect Docker networks' }
  return @($containers) + @($volumes) + @($networks) | Where-Object { $_ }
}

if ($targetMigration.Count -ne 1) {
  throw "target version must identify exactly one canonical migration: $TargetVersion"
}
if (-not (Test-Path -LiteralPath $canonicalConfig -PathType Leaf)) {
  throw 'canonical Supabase config is missing'
}
Assert-NoReparseAncestors $tempRoot
if (Test-Path -LiteralPath $projectRoot) {
  throw 'generated safe replay project already exists'
}
if (@(Get-DockerResources $projectId).Count -ne 0) {
  throw 'generated safe replay Docker identity already exists'
}

$startAttempted = $false
$cleanupFailure = $null
try {
  New-Item -ItemType Directory -Path $migrationRoot -Force | Out-Null
  Assert-NoReparseAncestors $migrationRoot

  $portPattern = [regex]'(?m)^(\s*(?:port|shadow_port|smtp_port|pop3_port)\s*=\s*)\d+'
  $config = [IO.File]::ReadAllText($canonicalConfig)
  $config = [regex]::Replace($config, '(?m)^project_id\s*=\s*"[^"]+"', "project_id = `"$projectId`"")
  $config = $portPattern.Replace($config, { param($match) $match.Groups[1].Value + (Get-FreeTcpPort) })
  [IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))

  $startAttempted = $true
  & npx.cmd supabase start --workdir $projectRoot --exclude $databaseOnlyExcludes *> $null
  if ($LASTEXITCODE -ne 0) { throw "supabase start failed with exit code $LASTEXITCODE" }

  & (Join-Path $scriptRoot 'Prepare-SafeMigrationReplay.ps1') -DestinationMigrationsRoot $migrationRoot
  & npx.cmd supabase db reset --local --no-seed --version $TargetVersion --workdir $projectRoot --yes
  if ($LASTEXITCODE -ne 0) { throw "safe local db reset failed with exit code $LASTEXITCODE" }
}
finally {
  try {
    if ($startAttempted) {
      & npx.cmd supabase stop --workdir $projectRoot --no-backup --yes *> $null
      if ($LASTEXITCODE -ne 0) { $cleanupFailure = 'supabase stop failed' }
    }
  }
  finally {
    if (Test-Path -LiteralPath $projectRoot) {
      try {
        Assert-NoReparseTree $projectRoot
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
      }
      catch {
        $cleanupFailure = "safe replay directory cleanup failed: $($_.Exception.Message)"
      }
    }
  }

  $residualDocker = @(Get-DockerResources $projectId)
  if (Test-Path -LiteralPath $projectRoot) {
    $cleanupFailure = 'safe replay project directory remains after cleanup'
  }
  if ($residualDocker.Count -ne 0) {
    $cleanupFailure = "safe replay Docker resources remain: $($residualDocker -join ',')"
  }
  if ($cleanupFailure) { throw $cleanupFailure }
}

"Safe local replay completed through $TargetVersion with isolated identity $projectId and zero residual resources."
