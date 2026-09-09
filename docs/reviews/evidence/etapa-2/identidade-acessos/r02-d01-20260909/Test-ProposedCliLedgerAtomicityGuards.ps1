# source: Test-ProposedCliLedgerAtomicity.ps1 pre-resource guards; parent bounded task
# status: local filesystem guard harness; never invokes CLI/Docker
# generated_at: 2026-09-09
$ErrorActionPreference = 'Stop'
$subject = Join-Path $PSScriptRoot 'Test-ProposedCliLedgerAtomicity.ps1'
$script:externalCalls = 0
function npx.cmd { $script:externalCalls++; throw 'EXTERNAL_COMMAND_REACHED' }
function docker { $script:externalCalls++; throw 'EXTERNAL_COMMAND_REACHED' }
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$id = 'coelo_safe_' + [guid]::NewGuid().ToString('N').Substring(0,29)
$root = Join-Path $temp $id
$target = Join-Path $temp ($id + '_guard_target')
$marker = Join-Path $root '.coelo-safe-replay'
$owned = @($root,$target)
$overrideKeys = @('SUPABASE_SERVICES_HOSTNAME','SUPABASE_PROJECT_ID','SUPABASE_DB_PORT','SUPABASE_DB_SHADOW_PORT','SUPABASE_ENV','SUPABASE_WORKDIR','SUPABASE_PROFILE','SUPABASE_DB_PASSWORD','DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','PGHOST','PGPORT','PGSERVICE','PGSERVICEFILE','SUPABASE_DB_URL')
$savedEnvironment = @{}
foreach ($key in $overrideKeys) { $savedEnvironment[$key] = [Environment]::GetEnvironmentVariable($key) }
foreach ($path in $owned) {
  if ([IO.Path]::GetFullPath((Split-Path -Parent $path)).TrimEnd('\') -cne $temp -or (Test-Path -LiteralPath $path)) {
    throw 'Fixture containment or collision failure'
  }
}
function Expect-Denial([string]$Case,[string]$Expected,[hashtable]$Parameters) {
  $observed = $null
  try { & $subject @Parameters | Out-Null } catch { $observed = $_.Exception.Message }
  if ($observed -cne $Expected -or $script:externalCalls -ne 0) {
    throw "Guard case failed: $Case; unexpected denial or external boundary reached"
  }
  Write-Output "$Case PASS expected=$Expected external_calls=0"
}
try {
  $base = @{ProjectRoot=$root;ProjectId=$id;ExecuteInAuthorizedLocalSlot=$true}
  Expect-Denial 'NO_SLOT_SWITCH' 'D00 local qualification slot required' @{ProjectRoot=$root;ProjectId=$id}
  Expect-Denial 'WRONG_TEMP_IDENTITY' 'Not the exact disposable TEMP project' @{ProjectRoot=$target;ProjectId=$id;ExecuteInAuthorizedLocalSlot=$true}
  [void][IO.Directory]::CreateDirectory($root)
  [IO.File]::WriteAllText($marker,'different-project')
  Expect-Denial 'MARKER_MISMATCH' 'Project marker mismatch' $base
  [IO.File]::Delete($marker)
  [IO.Directory]::Delete($root)
  [void][IO.Directory]::CreateDirectory($target)
  [void](New-Item -ItemType Junction -Path $root -Target $target)
  Expect-Denial 'ROOT_PHYSICAL_JUNCTION' 'Reparse ancestor denied' $base
  [IO.Directory]::Delete($root) # delete only the link; never traverse the target
  [void][IO.Directory]::CreateDirectory($root)
  [void](New-Item -ItemType Junction -Path $marker -Target $target)
  Expect-Denial 'MARKER_PHYSICAL_JUNCTION' 'Reparse tree denied' $base
  [IO.Directory]::Delete($marker) # marker is a directory junction, not a file symlink
  [IO.File]::WriteAllText($marker,$id)
  [void][IO.Directory]::CreateDirectory((Join-Path $root 'supabase'))
  [IO.File]::WriteAllText((Join-Path $root 'supabase/config.toml'),('project_id = "' + $id + '"'))
  Expect-Denial 'MIGRATION_DIRECTORY_ABSENT' 'Requires dedicated empty migration directory; never use product replay stack' $base
  [void][IO.Directory]::CreateDirectory((Join-Path $root 'supabase/migrations'))
  [IO.File]::WriteAllText((Join-Path $root 'supabase/migrations/owned-fixture.sql'),'-- guard fixture only')
  Expect-Denial 'MIGRATION_DIRECTORY_NONEMPTY' 'Requires dedicated empty migration directory; never use product replay stack' $base
  [IO.File]::Delete((Join-Path $root 'supabase/migrations/owned-fixture.sql'))
  foreach ($key in $overrideKeys) { [Environment]::SetEnvironmentVariable($key,$null) }
  foreach ($key in $overrideKeys) {
    [Environment]::SetEnvironmentVariable($key,'guard-synthetic-override')
    Expect-Denial ('OVERRIDE_' + $key) 'Connection environment override denied' $base
    [Environment]::SetEnvironmentVariable($key,$null)
  }
  [IO.File]::WriteAllText((Join-Path $root '.env.local'),'# synthetic fixture')
  Expect-Denial 'ENV_FILE' 'Project environment files denied' $base
  [IO.File]::Delete((Join-Path $root '.env.local'))
  Expect-Denial 'DB_SECTION_ABSENT' 'Unambiguous db section required' $base
  [IO.File]::AppendAllText((Join-Path $root 'supabase/config.toml'),"`n[db]`nport = 1`n")
  Expect-Denial 'DB_PORT_OUTSIDE_RANGE' 'Unambiguous local db port required' $base
} finally {
  foreach ($key in $overrideKeys) { [Environment]::SetEnvironmentVariable($key,$savedEnvironment[$key]) }
  foreach ($link in @($marker,$root)) {
    if ((Test-Path -LiteralPath $link) -and ((Get-Item -LiteralPath $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      [IO.Directory]::Delete($link)
    }
  }
  foreach ($path in $owned) {
    if ([IO.Path]::GetFullPath((Split-Path -Parent $path)).TrimEnd('\') -cne $temp) { throw 'Cleanup containment failed' }
    if (Test-Path -LiteralPath $path) {
      $items = @((Get-Item -LiteralPath $path -Force)) + @(Get-ChildItem -LiteralPath $path -Force -Recurse)
      if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Cleanup unexpected reparse point' }
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
  if (@($owned | Where-Object { Test-Path -LiteralPath $_ }).Count) { throw 'Residual owned fixture' }
  Write-Output 'OWNED_TEMP_CLEANUP PASS residual_paths=0'
}
Write-Output ('SUBJECT_SHA256 ' + (Get-FileHash -Algorithm SHA256 -LiteralPath $subject).Hash)
Write-Output 'GUARDS_TOTAL 26 PASS; CLI_DOCKER_CALLS 0; SQL_RUNS 0'
