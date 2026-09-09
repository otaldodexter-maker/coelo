$harnessPath = Join-Path $PSScriptRoot '..\Test-ChildDirectoryConcurrency.ps1'
$notePath = Join-Path $PSScriptRoot '..\..\..\..\docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-concurrency-plan.md'

function Parse-Script([string]$Path) {
  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$tokens,
    [ref]$errors
  )
  [pscustomobject]@{ Ast = $ast; Errors = @($errors); Text = [IO.File]::ReadAllText($Path) }
}

Describe 'CHILD directory concurrency harness contract' {
  It 'exists and parses without errors' {
    Test-Path -LiteralPath $harnessPath -PathType Leaf | Should Be $true
    $parsed = Parse-Script $harnessPath
    $parsed.Errors.Count | Should Be 0
  }

  It 'requires the owned disposable project and isolated identity' {
    $parsed = Parse-Script $harnessPath
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'ProjectRoot') | Should Be $true
    ($parameters -contains 'ProjectId') | Should Be $true
    $parsed.Text | Should Match '\.coelo-safe-replay'
    $parsed.Text | Should Match 'supabase_db_\$ProjectId'
    $parsed.Text | Should Match 'requires a clean one-shot disposable database'
    $parsed.Text | Should Match 'actor_internal_identity_id in'
  }

  It 'coordinates independent sessions through observed database locks' {
    $parsed = Parse-Script $harnessPath
    $starts = @($parsed.Ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Start-IsolatedPsql'
    }, $true))
    $starts.Count | Should BeGreaterThan 6
    $parsed.Text | Should Match 'pg_catalog\.pg_locks'
    $parsed.Text | Should Match 'wait_event_type'
    $parsed.Text | Should Match 'pg_catalog\.pg_blocking_pids'
    $parsed.Text | Should Match "Wait-ForBlockedSession 'child-membership-reader' 'child-membership-writer'"
    $parsed.Text | Should Match "Wait-ForBlockedSession 'child-rename-reader' 'child-rename-writer'"
    $parsed.Text | Should Match "Wait-ForBlockedSession 'child-expiry-reader' 'child-audit-gate'"
    $parsed.Text | Should Match 'pg_advisory_lock'
    $parsed.Text | Should Match 'Wait-ForDatabaseSignal'
    $parsed.Text | Should Not Match 'select pg_sleep'
  }

  It 'covers revocation after the first authorization read' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match "status='revoked',revoked_at=clock_timestamp\(\)"
    $parsed.Text | Should Match 'version=version\+1'
    $parsed.Text | Should Match 'child-concurrency-active@invalid\.test'
    $parsed.Text | Should Match 'SAI_MEMBERSHIP_REVOKED'
    $parsed.Text | Should Match "outcome='success'"
    $parsed.Text | Should Match "outcome='denied'"
    $parsed.Text | Should Match "institution_id is not null"
    $parsed.Text | Should Match "actor_internal_identity_id='9c100000-0000-4000-8000-000000000401'"
  }

  It 'renames the third limit-plus-one row and checks the returned order and cursor' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match "display_name='Aaron'"
    $parsed.Text | Should Match 'New-ReaderSql ''child-rename-reader'' \$activeClaims 2'
    $parsed.Text | Should Match "person_name -cne 'Aaron'"
    $parsed.Text | Should Match "person_name -cne 'Alfa'"
    $parsed.Text | Should Match "next_cursor.name -cne 'alfa'"
  }

  It 'forces wall-clock expiry during audit and verifies rollback' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'child_directory_concurrency_audit_gate'
    $parsed.Text | Should Match "not_after=clock_timestamp\(\)\+interval '30 seconds'"
    $parsed.Text | Should Match 'StatementTimeoutSeconds 60'
    $parsed.Text | Should Match 'LockTimeoutSeconds 50'
    $parsed.Text | Should Match "interval '20 seconds'"
    $parsed.Text | Should Match 'expiryDeadlineEpoch'
    $parsed.Text | Should Match "deadline' 40000"
    $parsed.Text | Should Match "actor_internal_identity_id='9c100000-0000-4000-8000-000000000402'"
    $parsed.Text | Should Match 'SAI_SESSION_INVALID'
    $parsed.Text | Should Match 'AllowFailure'
    $parsed.Text | Should Match 'success audit rolled back'
  }

  It 'bounds waits and cleans every process without reading credentials' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'WaitForExit'
    $parsed.Text | Should Match 'TimeoutMilliseconds = 30000'
    $parsed.Text | Should Match 'finally'
    $parsed.Text | Should Match '\.Kill\(\)'
    $parsed.Text | Should Match 'drop trigger if exists child_directory_concurrency_audit_gate'
    $parsed.Text | Should Match 'if \(\$auditGateOwned\)'
    $parsed.Text | Should Not Match 'session_replication_role'
    $parsed.Text | Should Not Match '(?i)(service_role|anon_key|password|secret)'
  }

  It 'keeps a durable plan that distinguishes runtime status from structure checks' {
    Test-Path -LiteralPath $notePath -PathType Leaf | Should Be $true
    $note = [IO.File]::ReadAllText($notePath)
    $note | Should Match 'status: "(prepared-not-executed|local-sql-green-in-integrated-base)"'
    $note | Should Match 'SQL concorrente n.o executado'
  }
}
