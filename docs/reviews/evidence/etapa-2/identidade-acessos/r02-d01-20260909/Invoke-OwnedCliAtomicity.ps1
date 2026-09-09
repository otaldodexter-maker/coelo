# source: Invoke-SafeLocalMigrationReplay.ps1; D01 atomicity qualifier; D00 delegation
# status: candidate; offline orchestration tested; SQL qualification pending
# generated_at: 2026-09-09
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$QualifierPath,
  [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedQualifierSha256,
  [switch]$ExecuteInAuthorizedLocalSlot
)
$ErrorActionPreference='Stop'
if (!$ExecuteInAuthorizedLocalSlot) { throw 'D00 exclusive local slot required' }
function Assert-NoReparseAncestors([string]$Path) {
  $cursor=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  while($null -ne $cursor){
    if($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse ancestor denied'}
    $cursor=if($cursor.PSIsContainer){$cursor.Parent}else{$cursor.Directory}
  }
}
function Assert-NoReparseTree([string]$Path) {
  Assert-NoReparseAncestors $Path
  foreach($entry in Get-ChildItem -LiteralPath $Path -Force -Recurse){
    if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse tree denied'}
  }
}
Assert-NoReparseAncestors $QualifierPath
if((Get-FileHash -LiteralPath $QualifierPath -Algorithm SHA256).Hash -ine $ExpectedQualifierSha256){throw 'Qualifier SHA256 mismatch'}
foreach($key in @('SUPABASE_SERVICES_HOSTNAME','SUPABASE_PROJECT_ID','SUPABASE_DB_PORT','SUPABASE_DB_SHADOW_PORT','SUPABASE_ENV','SUPABASE_WORKDIR','SUPABASE_PROFILE','SUPABASE_DB_PASSWORD','DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','PGHOST','PGPORT','PGSERVICE','PGSERVICEFILE','SUPABASE_DB_URL')){
  if(![string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key))){throw 'Connection environment override denied'}
}
$endpoint=(& docker context inspect --format '{{.Endpoints.docker.Host}}' 2>$null | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $endpoint -notmatch '^npipe:/{2,4}\./pipe/[a-zA-Z0-9_.-]+$'){throw 'Local Windows Docker context required'}
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
Assert-NoReparseAncestors $tempRoot
$projectId='coelo_safe_'+[guid]::NewGuid().ToString('N').Substring(0,29)
$projectRoot=Join-Path $tempRoot $projectId
$marker=Join-Path $projectRoot '.coelo-safe-replay'
$cliPackage='supabase@2.116.0'
$ports=[Collections.Generic.HashSet[int]]::new()
$ownedConfigHash=$null
function Assert-OwnedConfig {
  Assert-NoReparseTree $projectRoot
  if([IO.File]::ReadAllText($marker) -cne $projectId){throw 'Owned marker changed'}
  if($null -eq $ownedConfigHash -or (Get-FileHash -LiteralPath (Join-Path $projectRoot 'supabase/config.toml') -Algorithm SHA256).Hash -cne $ownedConfigHash){throw 'Owned config changed'}
}
function Get-FreeTcpPort {
  do {
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    try{$listener.Start();$port=([Net.IPEndPoint]$listener.LocalEndpoint).Port}finally{$listener.Stop()}
  } until($ports.Add($port))
  $port
}
function Get-OwnedResources {
  $containers=@(& docker ps -a --filter "name=$projectId" --format '{{.ID}}')
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect owned containers'}
  $volumes=@(& docker volume ls --filter "name=$projectId" --format '{{.Name}}')
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect owned volumes'}
  $networks=@(& docker network ls --filter "name=$projectId" --format '{{.ID}}')
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect owned networks'}
  @($containers)+@($volumes)+@($networks) | Where-Object {$_}
}
function Invoke-OwnedCli([string[]]$CommandArgs) {
  $priorPreference=$ErrorActionPreference
  try {
    # CLI startup/status output may contain generated local credentials.
    $ErrorActionPreference='Continue'
    & npx.cmd --offline $cliPackage --agent no @CommandArgs *> $null
    $exitCode=$LASTEXITCODE
  } finally {$ErrorActionPreference=$priorPreference}
  if($exitCode -ne 0){throw "Owned CLI command failed with exit code $exitCode"}
}
$mutex=[Threading.Mutex]::new($false,'Local\CoeloSafeSupabaseReplay')
$acquired=$false
try{$acquired=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$acquired=$true}
if(!$acquired){$mutex.Dispose();throw 'Another safe Supabase replay is already running'}
$created=$false;$startAttempted=$false;$primaryFailure=$null
$cleanupFailures=[Collections.Generic.List[string]]::new()
try {
  if(Test-Path -LiteralPath $projectRoot){throw 'Generated disposable path already exists'}
  if(@(Get-OwnedResources).Count){throw 'Generated disposable Docker identity already exists'}
  $null=New-Item -ItemType Directory -Path $projectRoot
  $created=$true
  [IO.File]::WriteAllText($marker,$projectId,[Text.UTF8Encoding]::new($false))
  Invoke-OwnedCli @('init','--workdir',$projectRoot)
  $configPath=Join-Path $projectRoot 'supabase/config.toml'
  Assert-NoReparseTree $projectRoot
  if(@(Get-ChildItem -LiteralPath $projectRoot -Force -Recurse -File | Where-Object {$_.Name -like '.env*'}).Count){throw 'Generated project environment file denied'}
  if(Test-Path -LiteralPath (Join-Path $projectRoot 'supabase/.temp/project-ref')){throw 'Generated linked project denied'}
  $config=[IO.File]::ReadAllText($configPath)
  $identityPattern=[regex]'(?m)^\s*project_id\s*=\s*"[^"]+"\s*$'
  $portPattern=[regex]'(?m)^(\s*(?:port|shadow_port|smtp_port|pop3_port)\s*=\s*)\d+'
  if($identityPattern.Matches($config).Count -ne 1){throw 'Generated config identity is ambiguous'}
  $config=$identityPattern.Replace($config,"project_id = `"$projectId`"")
  $config=$portPattern.Replace($config,{param($match) $match.Groups[1].Value+(Get-FreeTcpPort)})
  [IO.File]::WriteAllText($configPath,$config,[Text.UTF8Encoding]::new($false))
  $ownedConfigHash=(Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
  $migrations=Join-Path $projectRoot 'supabase/migrations'
  if(!(Test-Path -LiteralPath $migrations)){$null=New-Item -ItemType Directory -Path $migrations}
  if(@(Get-ChildItem -LiteralPath $migrations -Force).Count){throw 'Generated migration directory is not empty'}
  $excluded='gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
  Write-Output "OWNED_ATOMICITY_PROJECT $projectId"
  Assert-OwnedConfig
  $startAttempted=$true
  Invoke-OwnedCli @('start','--workdir',$projectRoot,'--exclude',$excluded)
  Assert-OwnedConfig
  Invoke-OwnedCli @('db','reset','--local','--no-seed','--workdir',$projectRoot,'--yes')
  Assert-OwnedConfig
  if((Get-FileHash -LiteralPath $QualifierPath -Algorithm SHA256).Hash -ine $ExpectedQualifierSha256){throw 'Qualifier changed before execution'}
  $results=@(& $QualifierPath -ProjectRoot $projectRoot -ProjectId $projectId -ExecuteInAuthorizedLocalSlot)
  if($results.Count -ne 2 -or $results[0] -cne 'CLI_LEDGER_FAILURE_ROLLBACK_PASS' -or $results[1] -cne 'CLI_LEDGER_SUCCESS_CONTROL_PASS'){
    throw 'Qualifier did not return both exact atomicity gates'
  }
  $results | Write-Output
} catch {$primaryFailure=$_.Exception}
finally {
  try {
    if($startAttempted){
      try {
        Assert-OwnedConfig
        Invoke-OwnedCli @('stop','--workdir',$projectRoot,'--no-backup','--yes')
      } catch {$cleanupFailures.Add('Owned stop failed: '+$_.Exception.Message)}
    }
    try {
      if(@(Get-OwnedResources).Count -ne 0){throw 'Owned Docker resources remain'}
    } catch {$cleanupFailures.Add($_.Exception.Message)}
    # Retain the project/config when stop failed, to permit exact owned recovery.
    if($created -and $cleanupFailures.Count -eq 0 -and (Test-Path -LiteralPath $projectRoot)){
      try {
        $resolved=[IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
        if($resolved -cne (Join-Path $tempRoot $projectId) -or [IO.File]::ReadAllText($marker) -cne $projectId){throw 'Owned cleanup containment/marker mismatch'}
        Assert-NoReparseTree $resolved
        Remove-Item -LiteralPath $resolved -Recurse -Force
        if(Test-Path -LiteralPath $resolved){throw 'Owned directory remains'}
      } catch {$cleanupFailures.Add($_.Exception.Message)}
    }
  } finally {
    if($acquired){$mutex.ReleaseMutex()}
    $mutex.Dispose()
  }
}
if($cleanupFailures.Count){throw ('Owned cleanup failed; retained path '+$projectRoot+': '+($cleanupFailures -join '; '))}
if($null -ne $primaryFailure){throw $primaryFailure}
Write-Output 'OWNED_ATOMICITY_2_PASS CLEANUP_ZERO'
