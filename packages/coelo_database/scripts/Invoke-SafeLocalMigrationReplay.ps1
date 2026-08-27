[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d{14}$')]
  [string]$TargetVersion
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$packageRoot = Split-Path -Parent $scriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$repositoryFull = [IO.Path]::GetFullPath($repositoryRoot)
$canonicalConfig = Join-Path $packageRoot 'supabase\config.toml'
$targetMigration = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'migrations') -File -Filter "$TargetVersion`_*.sql")
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$projectId = 'coelo_safe_' + [guid]::NewGuid().ToString('N')
$projectRoot = Join-Path $tempRoot $projectId
$supabaseRoot = Join-Path $projectRoot 'supabase'
$migrationRoot = Join-Path $supabaseRoot 'migrations'
$configPath = Join-Path $supabaseRoot 'config.toml'
$databaseOnlyExcludes = 'gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
$allocatedPorts = [Collections.Generic.HashSet[int]]::new()
$cliPackage = 'supabase@2.116.0'
$mutex = $null
$mutexAcquired = $false

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
if ($projectRoot -eq $repositoryFull -or
    $projectRoot.StartsWith($repositoryFull.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'safe replay temp root cannot be inside the repository'
}
$mutex = [Threading.Mutex]::new($false, 'Local\CoeloSafeSupabaseReplay')
try {
  $mutexAcquired = $mutex.WaitOne(0)
}
catch [Threading.AbandonedMutexException] {
  $mutexAcquired = $true
}
catch {
  $mutex.Dispose()
  throw
}
if (-not $mutexAcquired) {
  $mutex.Dispose()
  throw 'another safe Supabase replay is already running'
}
$startAttempted = $false
$projectCreated = $false
$primaryFailure = $null
$cleanupFailures = [Collections.Generic.List[Exception]]::new()
try {
  if (Test-Path -LiteralPath $projectRoot) {
    throw 'generated safe replay project already exists'
  }
  if (@(Get-DockerResources $projectId).Count -ne 0) {
    throw 'generated safe replay Docker identity already exists'
  }
  New-Item -ItemType Directory -Path $projectRoot | Out-Null
  $projectCreated = $true
  [IO.File]::WriteAllText((Join-Path $projectRoot '.coelo-safe-replay'), $projectId, [Text.UTF8Encoding]::new($false))
  New-Item -ItemType Directory -Path $supabaseRoot | Out-Null
  New-Item -ItemType Directory -Path $migrationRoot | Out-Null
  Assert-NoReparseAncestors $migrationRoot

  $portPattern = [regex]'(?m)^(\s*(?:port|shadow_port|smtp_port|pop3_port)\s*=\s*)\d+'
  $projectPattern = [regex]'(?m)^\s*project_id\s*=\s*"[^"]+"\s*$'
  $config = [IO.File]::ReadAllText($canonicalConfig)
  if ($projectPattern.Matches($config).Count -ne 1) {
    throw 'canonical config must contain exactly one double-quoted project_id'
  }
  $config = $projectPattern.Replace($config, "project_id = `"$projectId`"")
  $config = $portPattern.Replace($config, { param($match) $match.Groups[1].Value + (Get-FreeTcpPort) })
  [IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
  $writtenConfig = [IO.File]::ReadAllText($configPath)
  $expectedProjectLine = "project_id = `"$projectId`""
  if ($projectPattern.Matches($writtenConfig).Count -ne 1 -or
      $projectPattern.Match($writtenConfig).Value.Trim() -ne $expectedProjectLine) {
    throw 'generated config did not preserve the isolated project_id'
  }

  $startAttempted = $true
  & npx.cmd --yes $cliPackage start --workdir $projectRoot --exclude $databaseOnlyExcludes *> $null
  if ($LASTEXITCODE -ne 0) { throw "supabase start failed with exit code $LASTEXITCODE" }

  & (Join-Path $scriptRoot 'Prepare-SafeMigrationReplay.ps1') -DestinationMigrationsRoot $migrationRoot
  & npx.cmd --yes $cliPackage db reset --local --no-seed --version $TargetVersion --workdir $projectRoot --yes
  if ($LASTEXITCODE -ne 0) { throw "safe local db reset failed with exit code $LASTEXITCODE" }
}
catch {
  $primaryFailure = $_.Exception
}
finally {
  try {
    if ($startAttempted) {
      & npx.cmd --yes $cliPackage stop --workdir $projectRoot --no-backup --yes *> $null
      if ($LASTEXITCODE -ne 0) {
        $cleanupFailures.Add([InvalidOperationException]::new('supabase stop failed'))
      }
    }
  }
  catch {
    $cleanupFailures.Add($_.Exception)
  }
  finally {
    if (Test-Path -LiteralPath $projectRoot) {
      try {
        $marker = Join-Path $projectRoot '.coelo-safe-replay'
        if (-not $projectCreated -or
            -not (Test-Path -LiteralPath $marker -PathType Leaf) -or
            [IO.File]::ReadAllText($marker) -ne $projectId) {
          throw 'safe replay ownership marker is missing or invalid'
        }
        Assert-NoReparseTree $projectRoot
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
      }
      catch {
        $cleanupFailures.Add([InvalidOperationException]::new(
          "safe replay directory cleanup failed: $($_.Exception.Message)",
          $_.Exception
        ))
      }
    }
  }

  try {
    $residualDocker = @(Get-DockerResources $projectId)
    if ($residualDocker.Count -ne 0) {
      $cleanupFailures.Add([InvalidOperationException]::new(
        "safe replay Docker resources remain: $($residualDocker -join ',')"
      ))
    }
  }
  catch {
    $cleanupFailures.Add($_.Exception)
  }
  if (Test-Path -LiteralPath $projectRoot) {
    $cleanupFailures.Add([InvalidOperationException]::new(
      'safe replay project directory remains after cleanup'
    ))
  }
  try {
    if ($mutexAcquired) {
      $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
  }
  catch {
    $cleanupFailures.Add($_.Exception)
  }
}

if ($primaryFailure -and $cleanupFailures.Count -gt 0) {
  $failures = [Collections.Generic.List[Exception]]::new()
  $failures.Add($primaryFailure)
  foreach ($failure in $cleanupFailures) { $failures.Add($failure) }
  throw [AggregateException]::new('safe replay failed and cleanup was incomplete', $failures)
}
if ($primaryFailure) { throw $primaryFailure }
if ($cleanupFailures.Count -gt 0) {
  throw [AggregateException]::new('safe replay cleanup was incomplete', $cleanupFailures)
}

"Safe local replay completed through $TargetVersion with isolated identity $projectId and zero residual resources."
