$runtimePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-FormsAuthoringRuntimePreflight.ps1'

if (-not (Test-Path -LiteralPath $runtimePath)) { throw 'F-AUTHOR runtime preflight is not implemented' }
. $runtimePath
# A second fence prevents a failed mock from reaching a real executable.
function docker { throw 'real Docker is forbidden in this suite' }
function npx.cmd { throw 'real Supabase CLI is forbidden in this suite' }

Describe 'Isolated Forms authoring runtime preflight (native boundary mocked)' {
  BeforeEach {
    $script:faId = 'coelo_fauthor_' + [guid]::NewGuid().ToString('N').Substring(0,26)
    $script:faTemp = Join-Path $TestDrive 'isolated-temp'
    New-Item -ItemType Directory -Path $script:faTemp -Force | Out-Null
    $script:faRoot = Join-Path $script:faTemp $script:faId
    $script:faCalls = New-Object Collections.ArrayList
    $script:faLive = $false
    $script:faRestarted = $false
    $script:faFailure = ''
    $script:faReparsePath = $null
    $script:faFakeFilePath = $null
    $script:faReleased = $false
    $script:faDisposed = $false
    $script:faAcquire = $true
    $script:faPort = 56000
    $script:faCatalog = @{
      actor = 'postgres'; database = 'postgres'; server_version_num = 170006
      postmaster = '2026-09-08T04:00:00Z'
      preload = 'pg_stat_statements,pg_cron,pg_net'; cron_database = 'postgres'
      cron = @{ setting = 'on'; reset_val = 'on'; source = 'default'; pending_restart = $false; context = 'sighup' }
      file_errors = 0; cron_file_settings = @()
      auth = @{ users = $true; sessions = $true; jwt = $true; aal_type = $true; aal_labels = @('aal1','aal2','aal3') }
      storage = @{ buckets = $true; columns = @('id','name','public','file_size_limit','allowed_mime_types') }
      app_tables = 0; ledger_exists = $true
      extensions = @(
        @{ name = 'pg_cron'; available = '1.6.4'; installed = '1.6'; schema = $true; structures = @($true,$true,$true) },
        @{ name = 'pg_net'; available = '0.19.5'; installed = '0.19.5'; schema = $true; structures = @($true,$true,$true) },
        @{ name = 'supabase_vault'; available = '0.3.1'; installed = '0.3.1'; schema = $true; structures = @($true,$true,$true) }
      )
    }
    Mock Get-FormsPreflightTempRoot { $script:faTemp }
    Mock New-FormsPreflightIdentity { $script:faId }
    Mock Get-FormsPreflightEnvironmentNames { @() }
    Mock Get-FormsPreflightPort { $script:faPort++; $script:faPort }
    Mock Start-Sleep { }
    Mock New-FormsPreflightMutex {
      $m = New-Object PSObject
      $m | Add-Member ScriptMethod WaitOne { param($milliseconds) $script:faAcquire }
      $m | Add-Member ScriptMethod ReleaseMutex { $script:faReleased = $true }
      $m | Add-Member ScriptMethod Dispose { $script:faDisposed = $true }
      $m
    }
    Mock Invoke-FormsPreflightNative {
      param($Tool, $Arguments, $WorkingDirectory)
      [void]$script:faCalls.Add(@{ Tool=$Tool; Arguments=@($Arguments); WorkingDirectory=$WorkingDirectory })
      $a = @($Arguments)
      if ($Tool -eq 'cli') {
        if ($a -contains '--version') { return @{ ExitCode=0; Output='2.116.0' } }
        if ($a -contains 'start') {
          $script:faLive = $true
          if ($script:faFailure -eq 'start') { return @{ ExitCode=1; Output='SECRET_START_OUTPUT' } }
          if ($script:faFailure -eq 'marker') { [IO.File]::WriteAllText((Join-Path $script:faRoot '.forms-authoring-owner'), 'alien') }
          return @{ ExitCode=0; Output='SECRET_START_OUTPUT' }
        }
        if ($a -contains 'stop') {
          if ($script:faFailure -eq 'stop') { return @{ ExitCode=1; Output='SECRET_STOP_OUTPUT' } }
          if ($script:faFailure -ne 'residual') { $script:faLive = $false }
          return @{ ExitCode=0; Output='SECRET_STOP_OUTPUT' }
        }
      }
      if ($a -contains 'context') {
        if ($a -contains 'show') { return @{ ExitCode=0; Output='desktop-linux' } }
        $endpoint = if ($script:faFailure -eq 'remote') { 'tcp://remote.example:2376' } else { 'npipe:////./pipe/dockerDesktopLinuxEngine' }
        return @{ ExitCode=0; Output=$endpoint }
      }
      if (($a -contains 'ps') -or ($a -contains 'ls')) {
        $value = ''
        if ($script:faLive -or $script:faFailure -eq 'collision') { $value = 'owned-resource' }
        return @{ ExitCode=0; Output=$value }
      }
      if ($a -contains 'restart') {
        $script:faRestarted = $true
        if ($script:faFailure -eq 'restart') { return @{ ExitCode=1; Output='SECRET_RESTART_OUTPUT' } }
        return @{ ExitCode=0; Output=('b' * 64) }
      }
      if ($a -contains 'pg_isready') {
        return @{ ExitCode=$(if ($script:faFailure -eq 'readiness') { 1 } else { 0 }); Output='' }
      }
      if ($a -contains 'inspect') {
        if ($a -contains 'image') {
          $digest = 'sha256:' + ('c' * 64)
          if ($script:faRestarted -and $script:faFailure -eq 'digest') { $digest = 'sha256:' + ('d' * 64) }
          return @{ ExitCode=0; Output=(@{ Id=('sha256:' + ('e' * 64)); RepoDigests=@("public.ecr.aws/supabase/postgres@$digest") } | ConvertTo-Json -Compress) }
        }
        $m = @{
          Id=('b' * 64); Name=('/supabase_db_' + $script:faId)
          Image=('sha256:' + ('e' * 64)); ImageRef='public.ecr.aws/supabase/postgres:17.6.1.075'
          Project=$script:faId; Workdir=$script:faRoot; Running=$true
          StartedAt=$(if ($script:faRestarted) { '2026-09-08T04:01:00Z' } else { '2026-09-08T04:00:00Z' })
          Mounts=@(@{ Type='volume'; Name=('supabase_db_' + $script:faId); Destination='/var/lib/postgresql/data' })
          Networks=@(@{ Name=('supabase_network_' + $script:faId); Id=('f' * 64) })
        }
        if ($script:faRestarted) {
          switch ($script:faFailure) {
            'identity' { $m.Id = 'd' * 64 }
            'image' { $m.Image = 'sha256:' + ('d' * 64) }
            'volume' { $m.Mounts[0].Name = 'alien-volume' }
            'network' { $m.Networks[0].Id = 'd' * 64 }
          }
        }
        return @{ ExitCode=0; Output=($m | ConvertTo-Json -Depth 8 -Compress) }
      }
      if ($a -contains 'psql') {
        $sql = $a[-1]
        if ($sql -eq "ALTER SYSTEM SET cron.launch_active_jobs = 'off';") { return @{ ExitCode=0; Output='ALTER SYSTEM' } }
        if ($sql -match 'FA_CATALOG') {
          $c = $script:faCatalog | ConvertTo-Json -Depth 12 | ConvertFrom-Json
          if ($script:faRestarted) {
            $c.postmaster = '2026-09-08T04:01:00Z'
            $c.cron.setting='off'; $c.cron.reset_val='off'; $c.cron.source='configuration file'
            $c.cron_file_settings=@(@{ sourcefile='/var/lib/postgresql/data/postgresql.auto.conf'; setting='off'; applied=$true })
            switch ($script:faFailure) {
              'postmaster' { $c.postmaster = $script:faCatalog.postmaster }
              'setting' { $c.cron.setting = 'on' }
              'reset_val' { $c.cron.reset_val = 'on' }
              'source' { $c.cron.source = 'session' }
              'pending' { $c.cron.pending_restart = $true }
              'file_errors' { $c.file_errors = 1 }
              'file_unapplied' { $c.cron_file_settings[0].applied = $false }
            }
          }
          return @{ ExitCode=0; Output=($c | ConvertTo-Json -Depth 12 -Compress) }
        }
        $count = if ($script:faFailure -and $sql -match ('FA_' + $script:faFailure.ToUpperInvariant())) { 1 } else { 0 }
        return @{ ExitCode=0; Output=[string]$count }
      }
      throw 'unexpected native command in mock'
    }
  }

  It 'runs a fresh empty project, alters cron once and restarts the exact container before cleanup' {
    $result = Invoke-FormsAuthoringRuntimePreflight
    $result.Status | Should Be 'PASS'
    $result.Cleanup | Should Be 'zero'
    $result.Before.Cron.State | Should Be 'installed'
    $result.After.Cron.Jobs | Should Be 0
    $result.After.Ledger.Rows | Should Be 0
    $script:faRestarted | Should Be $true
    $script:faReleased | Should Be $true
    $script:faDisposed | Should Be $true
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
    $calls = @($script:faCalls)
    @($calls | Where-Object { $_.Arguments -contains 'start' }).Count | Should Be 1
    @($calls | Where-Object { $_.Arguments -contains 'stop' }).Count | Should Be 1
    $restart = @($calls | Where-Object { $_.Arguments -contains 'restart' })[0]
    $restart.Arguments[-1] | Should Be ('b' * 64)
    $alter = @($calls | Where-Object { $_.Arguments[-1] -eq "ALTER SYSTEM SET cron.launch_active_jobs = 'off';" })
    $alter.Count | Should Be 1
    $startCall=@($calls | Where-Object { $_.Arguments -contains 'start' })[0]
    $stopCall=@($calls | Where-Object { $_.Arguments -contains 'stop' })[0]
    $startCall.WorkingDirectory | Should Be $script:faRoot
    ($stopCall.Arguments -join '|') | Should Be ('stop|--workdir|' + $script:faRoot + '|--no-backup|--yes')
    $script:faCalls.IndexOf($startCall) | Should BeLessThan $script:faCalls.IndexOf($alter[0])
    $script:faCalls.IndexOf($alter[0]) | Should BeLessThan $script:faCalls.IndexOf($restart)
    $script:faCalls.IndexOf($restart) | Should BeLessThan $script:faCalls.IndexOf($stopCall)
    @($calls | Where-Object { $_.Arguments -contains 'reset' -or $_.Arguments -contains 'push' }).Count | Should Be 0
    ($result | ConvertTo-Json -Depth 15) | Should Not Match 'SECRET_'
  }

  It 'records available but uninstalled extensions as not_installed with null counts' {
    foreach ($e in $script:faCatalog.extensions) { $e.installed=$null; $e.schema=$false; $e.structures=@($false,$false,$false) }
    $result = Invoke-FormsAuthoringRuntimePreflight
    $result.Status | Should Be 'PASS'
    $result.After.Cron.State | Should Be 'not_installed'
    ($null -eq $result.After.Cron.Jobs) | Should Be $true
    ($null -eq $result.After.Net.Requests) | Should Be $true
    $result.After.Vault.State | Should Be 'not_installed'
    @($script:faCalls | Where-Object { $_.Arguments[-1] -match 'FA_(JOBS|RUNS|REQUESTS|RESPONSES)' }).Count | Should Be 0
  }

  It 'rejects an unavailable required extension before ALTER SYSTEM' {
    $script:faCatalog.extensions[1].available=$null
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'unavailable extension: pg_net'
    $script:faRestarted | Should Be $false
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
  }

  It 'rejects partially present extensions instead of calling their absent tables' -TestCases @(
    @{Index=0;Installed=$true},@{Index=1;Installed=$true},@{Index=2;Installed=$true},
    @{Index=0;Installed=$false},@{Index=1;Installed=$false},@{Index=2;Installed=$false}
  ) {
    param($Index,$Installed)
    if ($Installed) { $script:faCatalog.extensions[$Index].structures[0]=$false }
    else { $script:faCatalog.extensions[$Index].installed=$null }
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'inconsistent extension'
    $script:faRestarted | Should Be $false
  }

  It 'rejects missing real bootstrap structures' -TestCases @(
    @{Section='auth';Field='users'},@{Section='auth';Field='sessions'},@{Section='auth';Field='jwt'},
    @{Section='auth';Field='aal_type'},@{Section='storage';Field='buckets'}
  ) {
    param($Section,$Field)
    $script:faCatalog[$Section][$Field]=$false
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'native bootstrap'
    $script:faRestarted | Should Be $false
  }

  It 'rejects missing cron preload and missing real registered GUC' -TestCases @(@{Case='preload'},@{Case='guc'}) {
    param($Case)
    if ($Case -eq 'preload') { $script:faCatalog.preload='pg_net' } else { $script:faCatalog.cron=$null }
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'cron'
    $script:faRestarted | Should Be $false
  }

  It 'rejects nonzero ledger, jobs, runs and network queues before any ALTER' -TestCases @(
    @{Case='ledger'},@{Case='jobs'},@{Case='runs'},@{Case='requests'},@{Case='responses'}
  ) {
    param($Case)
    $script:faFailure=$Case
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'nonzero'
    $script:faRestarted | Should Be $false
  }

  It 'rejects effective-setting and same-instance failures after restart and cleans up' -TestCases @(
    @{Case='identity'},@{Case='image'},@{Case='digest'},@{Case='volume'},@{Case='network'},
    @{Case='postmaster'},@{Case='setting'},@{Case='reset_val'},@{Case='source'},
    @{Case='pending'},@{Case='file_errors'},@{Case='file_unapplied'},@{Case='restart'},@{Case='readiness'}
  ) {
    param($Case)
    $script:faFailure=$Case
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw
    $script:faRestarted | Should Be $true
    $script:faReleased | Should Be $true
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
  }

  It 'suppresses secret startup output and still stops after a partial start' {
    $script:faFailure='start'
    $message=''
    try { Invoke-FormsAuthoringRuntimePreflight } catch { $message=$_.Exception.Message }
    $message | Should Match 'start failed'
    $message | Should Not Match 'SECRET_'
    @($script:faCalls | Where-Object { $_.Arguments -contains 'stop' }).Count | Should Be 1
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
  }

  It 'refuses remote endpoints and prior identity collisions before start' -TestCases @(@{Case='remote'},@{Case='collision'}) {
    param($Case)
    $script:faFailure=$Case
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw
    @($script:faCalls | Where-Object { $_.Arguments -contains 'start' }).Count | Should Be 0
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
  }

  It 'never deletes a preexisting project directory' {
    New-Item -ItemType Directory -Path $script:faRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:faRoot 'alien'), 'preserve')
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'already exists'
    [IO.File]::ReadAllText((Join-Path $script:faRoot 'alien')) | Should Be 'preserve'
    @($script:faCalls | Where-Object { $_.Arguments -contains 'start' }).Count | Should Be 0
  }

  It 'refuses unsafe cleanup and preserves evidence when marker, stop or residual checks fail' -TestCases @(
    @{Case='marker'},@{Case='stop'},@{Case='residual'}
  ) {
    param($Case)
    $script:faFailure=$Case
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw
    (Test-Path -LiteralPath $script:faRoot) | Should Be $true
    $script:faReleased | Should Be $true
    if ($Case -eq 'marker') { @($script:faCalls | Where-Object { $_.Arguments -contains 'stop' }).Count | Should Be 0 }
  }

  It 'refuses environment overrides without printing their values' {
    Mock Get-FormsPreflightEnvironmentNames { @('SUPABASE_PROJECT_ID') }
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'environment override'
    $script:faCalls.Count | Should Be 0
  }

  It 'does not acquire a second global replay lease' {
    $script:faAcquire=$false
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'another safe replay'
    $script:faDisposed | Should Be $true
    $script:faReleased | Should Be $false
    @($script:faCalls | Where-Object { $_.Arguments -contains 'start' }).Count | Should Be 0
  }

  It 'uses only the fixed startup config and leaves migrations empty before start' {
    $ctx = New-FormsPreflightContext
    New-FormsPreflightProject $ctx
    Assert-FormsPreflightProject $ctx -BeforeStart
    @((Get-ChildItem -LiteralPath $ctx.Migrations -Force)).Count | Should Be 0
    $config=[IO.File]::ReadAllText($ctx.ConfigPath)
    $config | Should Match 'major_version = 17'
    $config | Should Match '(?s)\[db.migrations\]\s+enabled = false'
    $config | Should Match '(?s)\[db.seed\]\s+enabled = false'
    $config | Should Not Match 'db.settings|vault|env\(|schema_paths = \["|sql_paths = \["'
    [IO.File]::WriteAllText((Join-Path $ctx.Supabase '.env'), 'SECRET=fixture')
    { Assert-FormsPreflightProject $ctx -BeforeStart } | Should Throw 'unexpected startup path'
  }

  It 'checks file and directory ancestor reparse metadata without traversing a link' {
    $ctx=New-FormsPreflightContext
    New-FormsPreflightProject $ctx
    $script:faReparsePath=$script:faRoot
    Mock Get-Item {
      [pscustomobject]@{FullName=$script:faRoot;Attributes=[IO.FileAttributes]::ReparsePoint;PSIsContainer=$true;Parent=$null}
    } -ParameterFilter { $LiteralPath -eq $script:faReparsePath }
    { Assert-FormsPreflightProject $ctx -BeforeStart } | Should Throw 'reparse'
  }

  It 'keeps mixed installed and not_installed states separate' {
    $script:faCatalog.extensions[1].installed=$null
    $script:faCatalog.extensions[1].schema=$false
    $script:faCatalog.extensions[1].structures=@($false,$false,$false)
    $result=Invoke-FormsAuthoringRuntimePreflight
    $result.After.Cron.State | Should Be 'installed'
    $result.After.Cron.Jobs | Should Be 0
    $result.After.Net.State | Should Be 'not_installed'
    ($null -eq $result.After.Net.Requests) | Should Be $true
    $result.After.Vault.State | Should Be 'installed'
  }

  It 'reports absent application ledger explicitly without issuing a count query' {
    $script:faCatalog.ledger_exists=$false
    $result=Invoke-FormsAuthoringRuntimePreflight
    $result.After.Ledger.State | Should Be 'absent'
    ($null -eq $result.After.Ledger.Rows) | Should Be $true
    @($script:faCalls | Where-Object { $_.Arguments[-1] -match 'FA_LEDGER' }).Count | Should Be 0
  }

  It 'fails closed on missing catalog fields instead of casting absence to zero' -TestCases @(
    @{Field='app_tables'},@{Field='file_errors'},@{Field='ledger_exists'}
  ) {
    param($Field)
    $script:faCatalog[$Field]=$null
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw 'incomplete'
    $script:faRestarted | Should Be $false
  }

  It 'requires postgres on PostgreSQL 17 and an empty application catalog' -TestCases @(
    @{Field='actor';Value='authenticated'},@{Field='server_version_num';Value=160010},
    @{Field='server_version_num';Value=180000},@{Field='app_tables';Value=1}
  ) {
    param($Field,$Value)
    $script:faCatalog[$Field]=$Value
    { Invoke-FormsAuthoringRuntimePreflight } | Should Throw
    $script:faRestarted | Should Be $false
  }

  It 'never returns partial native SQL failure output' {
    $script:faFailure='sqlfailure'
    Mock Invoke-FormsPreflightNative { @{ExitCode=1;Output='SECRET_SQL_FAILURE'} } -ParameterFilter {
      $script:faFailure -eq 'sqlfailure' -and $Tool -eq 'docker' -and $Arguments[-1] -match 'FA_CATALOG'
    }
    $message=''
    try { Invoke-FormsAuthoringRuntimePreflight } catch { $message=$_.Exception.Message }
    $message | Should Match 'Catalog SQL failed'
    $message | Should Not Match 'SECRET_'
    (Test-Path -LiteralPath $script:faRoot) | Should Be $false
  }

  It 'rejects modified config before stop can select a different identity' {
    $ctx=New-FormsPreflightContext
    New-FormsPreflightProject $ctx
    [IO.File]::WriteAllText($ctx.ConfigPath, 'project_id = "alien"')
    { Assert-FormsPreflightProject $ctx } | Should Throw 'config mismatch'
  }

  It 'checks a file ancestor through Directory as well as directory Parent' {
    $ctx=New-FormsPreflightContext
    New-FormsPreflightProject $ctx
    $reparse=[pscustomobject]@{FullName=$ctx.Supabase;Attributes=[IO.FileAttributes]::ReparsePoint;PSIsContainer=$true;Parent=$null}
    $script:faFakeFile=[pscustomobject]@{FullName=$ctx.ConfigPath;Attributes=[IO.FileAttributes]::Normal;PSIsContainer=$false;Directory=$reparse}
    $script:faFakeFilePath=$ctx.ConfigPath
    Mock Get-Item { $script:faFakeFile } -ParameterFilter { $LiteralPath -eq $script:faFakeFilePath }
    { Assert-FormsPreflightAncestors $ctx.ConfigPath } | Should Throw 'reparse'
  }

  It 'exposes no free parameters and keeps its only SQL mutation standalone' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($runtimePath,[ref]$tokens,[ref]$errors)
    $errors.Count | Should Be 0
    $ast.ParamBlock.Parameters.Count | Should Be 0
    (Get-FormsPreflightSql DisableCron) | Should Be "ALTER SYSTEM SET cron.launch_active_jobs = 'off';"
    $catalog=Get-FormsPreflightSql Catalog
    $catalog | Should Not Match '(?i)\b(create|insert|update|delete|grant|revoke)\b'
    $catalog | Should Not Match '(?i)select.+decrypted_secret'
  }


  It 'preserves embedded Docker template quotes in Windows legacy argument passing' {
    $a=@(Convert-FormsPreflightDockerArguments @('inspect','--format','{"Id":{{json .Id}}}'))
    $a.Count | Should Be 3
    $a[2] | Should Be '{\"Id\":{{json .Id}}}'
  }

  It 'reports not_owned when preflight preserves an identity collision before creating resources' -TestCases @(
    @{Case='collision'},@{Case='directory'}
  ) {
    param($Case)
    if ($Case -eq 'collision') { $script:faFailure='collision' }
    else {
      New-Item -ItemType Directory -Path $script:faRoot | Out-Null
      [IO.File]::WriteAllText((Join-Path $script:faRoot 'alien'), 'preserve')
    }
    $reports=New-Object Collections.ArrayList
    $failed=$false
    try {
      Invoke-FormsAuthoringRuntimePreflight | ForEach-Object { [void]$reports.Add($_) }
    } catch { $failed=$true }
    $failed | Should Be $true
    $reports.Count | Should Be 1
    $reports[0].Status | Should Be 'FAIL'
    $reports[0].StartAttempted | Should Be $false
    $reports[0].Cleanup | Should Be 'not_owned'
    @($script:faCalls | Where-Object { $_.Arguments -contains 'stop' }).Count | Should Be 0
    if ($Case -eq 'directory') {
      [IO.File]::ReadAllText((Join-Path $script:faRoot 'alien')) | Should Be 'preserve'
    }
  }
}
