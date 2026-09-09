$harnessPath = Join-Path $PSScriptRoot '..\Test-R02AuthProofConcurrency.ps1'
Describe 'R02 Auth proof concurrency local harness' {
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
