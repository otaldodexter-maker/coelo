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
