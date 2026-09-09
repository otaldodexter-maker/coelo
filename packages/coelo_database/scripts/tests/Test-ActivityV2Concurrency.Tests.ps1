$harnessPath = Join-Path $PSScriptRoot '..\Test-ActivityV2Concurrency.ps1'
$wrapperPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'

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

Describe 'Activity v2 concurrency harness contract' {
  It 'seeds a separate active Owner chain so actor revocation preserves the last-owner guard' {
    $parsed = Parse-Script $harnessPath
    $fixture = @($parsed.Ast.FindAll({param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left.Extent.Text -eq '$fixtureSql'
    },$true))[0].Right.Extent.Text
    ($fixture -match "'8c100000-0000-4000-8000-000000000102','authenticated','authenticated','concurrency-spare@invalid.test'") | Should Be $true
    ($fixture -match "\('8c100000-0000-4000-8000-000000000302'\)") | Should Be $true
    ($fixture -match "'8c100000-0000-4000-8000-000000000402','8c100000-0000-4000-8000-000000000302','8c100000-0000-4000-8000-000000000102'") | Should Be $true
    ($fixture -match "select '8c100000-0000-4000-8000-000000000502','8c100000-0000-4000-8000-000000000302',id,'platform'\s+from public.platform_roles where code='owner' and status='active'") | Should Be $true
    ($parsed.Text -match 'session_replication_role|disable trigger') | Should Be $false
  }

  It 'advances only the actor membership version on terminal revocation' {
    $parsed = Parse-Script $harnessPath
    ($parsed.Text -match "set status='revoked',revoked_at=clock_timestamp\(\),version=version\+1\s+where id='8c100000-0000-4000-8000-000000000501'") | Should Be $true
  }

  It 'rejects reused fixture identities before the atomic one-shot seed' {
    $parsed = Parse-Script $harnessPath
    ($parsed.Text -match 'ACTIVITY_CONCURRENCY_FIXTURE_COLLISION') | Should Be $true
    ($parsed.Text -match "auth.users where id in\('8c100000-0000-4000-8000-000000000101','8c100000-0000-4000-8000-000000000102'\)") | Should Be $true
    ($parsed.Text -match "superadmin_internal_memberships where id in\('8c100000-0000-4000-8000-000000000501','8c100000-0000-4000-8000-000000000502'\)") | Should Be $true
    $parsed.Text.IndexOf('ACTIVITY_CONCURRENCY_FIXTURE_COLLISION') | Should BeLessThan $parsed.Text.IndexOf('insert into public.institution_types')
  }

  It 'exists and parses without errors' {
    Test-Path -LiteralPath $harnessPath -PathType Leaf | Should Be $true
    $parsed = Parse-Script $harnessPath
    $parsed.Errors.Count | Should Be 0
  }

  It 'requires the disposable project root and isolated project identity' {
    $parsed = Parse-Script $harnessPath
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'ProjectRoot') | Should Be $true
    ($parameters -contains 'ProjectId') | Should Be $true
    $parsed.Text | Should Match '\.coelo-safe-replay'
    $parsed.Text | Should Match 'supabase_db_\$ProjectId'
  }

  It 'starts two independent psql processes and waits for both results' {
    $parsed = Parse-Script $harnessPath
    $starts = @($parsed.Ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Start-IsolatedPsql'
    }, $true))
    $starts.Count | Should BeGreaterThan 3
    $parsed.Text | Should Match 'WaitForExit'
    $parsed.Text | Should Match 'pg_sleep\(1\)'
    $parsed.Text | Should Match 'set role authenticated'
  }

  It 'asserts one winner, one concurrent-change loser, and durable invariants' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'SAI_CONCURRENT_CHANGE'
    $parsed.Text | Should Match 'management_version'
    $parsed.Text | Should Match 'activity_command_receipts'
    $parsed.Text | Should Match 'audit_logs'
    $parsed.Text | Should Match 'denial_audit_count'
    $parsed.Text | Should Match "reason_code='SAI_CONCURRENT_CHANGE'"
    $parsed.Text | Should Match "action_code='activity.update'"
    $parsed.Text | Should Match 'deadlock'
  }

  It 'uses the exact audited eight-field internal marker fixture' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match "'correlation_id',gen_random_uuid\(\)"
  }

  It 'seeds the aggregate with an active unit link under the nominal marker' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'insert into public\.units'
    $parsed.Text | Should Match 'insert into public\.activity_unit_links'
    $parsed.Text | Should Match "'permission_code','activities\.link_units','action_code','link_units'"
    $parsed.Text | Should Not Match 'session_replication_role'
  }

  It 'never obtains or prints local API or database credentials' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Not Match 'supabase\s+status'
    $parsed.Text | Should Not Match '(?i)(password|service_role|anon_key|secret)'
  }
}

Describe 'Safe replay Activity v2 concurrency integration' {
  It 'parses and exposes the explicit switch' {
    $parsed = Parse-Script $wrapperPath
    $parsed.Errors.Count | Should Be 0
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'RunActivityV2Concurrency') | Should Be $true
  }

  It 'invokes the harness with only the isolated root and identity' {
    $parsed = Parse-Script $wrapperPath
    $parsed.Text | Should Match "Test-ActivityV2Concurrency\.ps1"
    $parsed.Text | Should Match '-ProjectRoot\s+\$projectRoot'
    $parsed.Text | Should Match '-ProjectId\s+\$projectId'
  }
}
