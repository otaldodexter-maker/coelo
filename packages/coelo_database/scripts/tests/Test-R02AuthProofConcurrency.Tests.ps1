$harnessPath = Join-Path $PSScriptRoot '..\Test-R02AuthProofConcurrency.ps1'
Describe 'R02 Auth proof concurrency local harness' {
  It 'preserves terminal membership history and uses a fresh active membership for cleanup' {
    $source=[IO.File]::ReadAllText($harnessPath)
    ($source.Contains('foreach ($scenario in @(''session'',''jwt'',''membership''))')) | Should Be $true
    ($source.Contains("set status='active',revoked_at=null")) | Should Be $false
    ($source.Contains("a9020000-0000-4000-8000-000000000503")) | Should Be $true
    ($source -match "set status='revoked',revoked_at=clock_timestamp\(\),version=version\+1") | Should Be $true
  }

  It 'reports bounded SQLSTATE and known error text without SQL or token details' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($harnessPath,[ref]$tokens,[ref]$errors)
    $definition=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-SqlDiagnostic'
    },$true))
    $definition.Count | Should Be 1
    . ([scriptblock]::Create($definition[0].Extent.Text))
    $diagnostic=Get-SqlDiagnostic "ERROR:  55000: revoked internal access is terminal`nCONTEXT: SQL statement secret-token-and-whole-sql"
    $diagnostic | Should Be 'sqlstate=55000 error=revoked internal access is terminal'
    (Get-SqlDiagnostic 'ERROR: 23505: private-token-unknown-message') | Should Be 'sqlstate=23505 error=unclassified local database error'
    ($diagnostic -match 'secret|CONTEXT|SQL statement') | Should Be $false
  }

  It 'emits each completed case before the next and annotates local failures' {
    $source=[IO.File]::ReadAllText($harnessPath)
    ($source.Contains('AUTH_PROOF_CASE_PASS case=$case')) | Should Be $true
    ($source.Contains('AUTH_PROOF_CASE_FAIL phase=$proofPhase case=$proofCase completed=$($results.Count)')) | Should Be $true
    ($source.Contains('Get-SqlDiagnostic $stderr')) | Should Be $true
    ($source.Contains('--set VERBOSITY=verbose')) | Should Be $true
  }

  It 'generates real <action> SQL offline without invoking the executor CLI' -TestCases @(
    @{action='provision'}, @{action='cleanup'}
  ) {
    param($action)
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($harnessPath,[ref]$tokens,[ref]$errors)
    $generatorAssignment=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left.Extent.Text -eq '$generator'
    },$true))
    $generatorAssignment.Count | Should Be 1
    . ([scriptblock]::Create($generatorAssignment[0].Extent.Text))
    $definition=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -eq 'New-ActualCommand'
    },$true))
    $definition.Count | Should Be 1
    . ([scriptblock]::Create($definition[0].Extent.Text))
    $executorPath=Join-Path $PSScriptRoot '..\r02-d01-auth-proof-executor.mjs'
    $executorHash=(Get-FileHash -LiteralPath $executorPath -Algorithm SHA256).Hash
    $executorHash | Should Be '8A5ABFBAECB1DC4134542F3F016837CC51521C3CCF1C6F61BD9DE84F45BC2E86'
    $nodePath=(Get-Command node -ErrorAction Stop).Source
    $command=New-ActualCommand $action ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+3600)
    $LASTEXITCODE | Should Be 0
    @($command).Count | Should Be 1
    $command.plan.authUserId | Should Match '^[0-9a-f-]{36}$'
    $command.sql | Should Match '^begin;'
    $command.sql | Should Match 'require_superadmin_internal_context'
    $command.sql | Should Match "e2.r02.auth.$action"
    if ($action -eq 'provision') {
      $command.sql | Should Match 'insert into app_private.superadmin_internal_identities'
    } else {
      $command.sql | Should Match 'delete from auth.sessions'
    }
  }

  It 'parses without errors' {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($harnessPath,[ref]$tokens,[ref]$errors)
    @($errors).Count | Should Be 0
  }
  It 'describes exactly six distinct cases without resources' {
    $plan = & $harnessPath -DescribeOnly
    @($plan.Cases).Count | Should Be 6
    @($plan.Cases | Select-Object -Unique).Count | Should Be 6
    $plan.SqlExecuted | Should Be $false
    $plan.ExecutorSha256 | Should Match '^[A-F0-9]{64}$'
  }
  It 'rejects a foreign project before Docker discovery' {
    { & $harnessPath -ProjectRoot $TestDrive -ProjectId 'production' -ExpectedExecutorSha256 ('0'*64) } | Should Throw
  }
  It 'rejects missing ownership marker before Docker discovery' {
    { & $harnessPath -ProjectRoot $TestDrive -ProjectId ('coelo_safe_'+('a'*29)) -ExpectedExecutorSha256 ('0'*64) } | Should Throw 'AUTH_PROOF_OWNED_REPLAY_REQUIRED'
  }
  It 'rejects a stale executor hash before Docker discovery' {
    $id='coelo_safe_'+('a'*29)
    [IO.File]::WriteAllText((Join-Path $TestDrive '.coelo-safe-replay'),$id)
    { & $harnessPath -ProjectRoot $TestDrive -ProjectId $id -ExpectedExecutorSha256 ('0'*64) } | Should Throw 'AUTH_PROOF_EXECUTOR_HASH_MISMATCH'
  }
  It 'uses real generated SQL, observed blocking and strict negative receipts' {
    $source=[IO.File]::ReadAllText($harnessPath)
    $source | Should Match 'mutationSql\(action'
    $source | Should Match 'pg_blocking_pids'
    $source | Should Match 'wait_event_type'
    $source | Should Match 'AUTH_PROOF_UNEXPECTED_EFFECT'
    $source | Should Match 'SAI_MEMBERSHIP_REVOKED'
    $source | Should Match 'clock_timestamp'
    $source | Should Not Match 'session_replication_role'
    $source | Should Not Match 'Invoke-RestMethod|Invoke-WebRequest|docker run|docker start'
  }
}

Describe 'R02 Auth proof wrapper integration' {
  $wrapperPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'
  It 'exposes a separate explicit proof switch' {
    (Get-Command $wrapperPath).Parameters.ContainsKey('RunR02AuthProofConcurrency') | Should Be $true
  }
  It 'rejects incompatible combinations before starting resources' {
    $invalid = @(
      @{ TargetVersion='20260901200206' },
      @{ TargetVersion='20260901200206'; AuthOnly=$true },
      @{ TargetVersion='20260901200206'; RunAuthLifecycle=$true },
      @{ TargetVersion='20260908051500'; AuthOnly=$true; RunAuthLifecycle=$true },
      @{ TargetVersion='20260901200206'; AuthOnly=$true; RunAuthLifecycle=$true; FoundationOnly=$true },
      @{ TargetVersion='20260901200206'; AuthOnly=$true; RunAuthLifecycle=$true; AdditionalMigration=@('not-allowed.sql') },
      @{ TargetVersion='20260901200206'; AuthOnly=$true; RunAuthLifecycle=$true; NominalProfile='ChildDirectoryEnvelope' },
      @{ TargetVersion='20260901200206'; AuthOnly=$true; RunAuthLifecycle=$true; RunActivityV2Concurrency=$true }
    )
    foreach ($arguments in $invalid) {
      { & $wrapperPath @arguments -RunR02AuthProofConcurrency } |
        Should Throw 'R02 Auth proof concurrency requires exact AuthOnly lifecycle base without additions'
    }
  }
}
