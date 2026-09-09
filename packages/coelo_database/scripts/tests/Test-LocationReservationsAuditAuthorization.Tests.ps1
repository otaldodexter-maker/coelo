$harnessPath = Join-Path $PSScriptRoot '..\Test-LocationReservationsAuditAuthorization.ps1'

function Parse-Script([string]$Path) {
  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$tokens,
    [ref]$errors
  )
  [pscustomobject]@{
    Ast = $ast
    Errors = @($errors)
    Text = [IO.File]::ReadAllText($Path)
  }
}

Describe 'Location reservation audit authorization harness contract' {
  It 'generates exact valid JWT claim JSON for both causal actors without running SQL' {
    $parsed = Parse-Script $harnessPath
    $functions = @($parsed.Ast.FindAll({param($node)
      $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -ceq 'Get-Claims'
    }, $true))
    $functions.Count | Should Be 1
    # Evaluate only the actual pure function, never the harness entry point.
    . ([scriptblock]::Create($functions[0].Extent.Text))
    foreach ($actor in @(1,2)) {
      $raw = Get-Claims $actor
      $claims = $raw | ConvertFrom-Json
      @($claims.psobject.Properties.Name | Sort-Object) | Should Be @('aal','role','session_id','sub')
      $suffix = $actor.ToString().PadLeft(12,'0')
      $claims.sub | Should Be ('d1400000-0000-4000-8000-' + $suffix)
      $claims.session_id | Should Be ('d1500000-0000-4000-8000-' + $suffix)
      ([guid]$claims.sub).ToString() | Should Be $claims.sub
      ([guid]$claims.session_id).ToString() | Should Be $claims.session_id
      $claims.aal | Should Be 'aal1'
      $claims.role | Should Be 'authenticated'
    }
  }

  It 'exists and parses without errors' {
    Test-Path -LiteralPath $harnessPath -PathType Leaf | Should Be $true
    $parsed = Parse-Script $harnessPath
    $parsed.Errors.Count | Should Be 0
  }

  It 'requires the owned disposable project and exact container identity' {
    $parsed = Parse-Script $harnessPath
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'ProjectRoot') | Should Be $true
    ($parameters -contains 'ProjectId') | Should Be $true
    $parsed.Text | Should Match '\.coelo-safe-replay'
    $parsed.Text | Should Match 'supabase_db_\$ProjectId'
  }

  It 'proves the caller reached the held audit relation lock before mutation' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'lock table audit\.audit_logs in share mode'
    $parsed.Text | Should Match 'pg_blocking_pids\(caller\.pid\)'
    $parsed.Text | Should Match "caller\.wait_event_type='Lock'"
    $parsed.Text | Should Match 'location_audit_holder_\$Scenario'
    $parsed.Text | Should Match 'location_audit_caller_\$Scenario'
  }

  It 'keeps caller authentication transaction local and uses independent updater sessions' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'set local role authenticated'
    $parsed.Text | Should Match 'set_config\(''request\.jwt\.claims'',''\$claims'',true\)'
    $parsed.Text | Should Match '\$updater = Start-IsolatedPsql \$updateSql'
    $parsed.Text | Should Match 'pg_catalog\.now\(\) remains earlier'
    $parsed.Text | Should Match 'not_after=clock_timestamp\(\)'
  }

  It 'uses separate actors and a spare Owner for terminal versioned revocation' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match "Test-AuditAuthorizationAfterWait 'expiry' 1"
    $parsed.Text | Should Match "Test-AuditAuthorizationAfterWait 'revocation' 2"
    $parsed.Text | Should Match "changed_by_internal_identity_id='d1600000-0000-4000-8000-000000000003'"
    $parsed.Text | Should Match 'version=version\+1'
    $parsed.Text | Should Not Match "update app_private\.superadmin_internal_memberships[\s\S]*set status='active'"
  }

  It 'requires the expected denial and zero rolled-back success effects' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'SAI_SESSION_INVALID'
    $parsed.Text | Should Match 'SAI_MEMBERSHIP_REVOKED'
    $parsed.Text | Should Match "action_code='location\.reservation\.create'"
    $parsed.Text | Should Match "institution_id='d1100000-0000-4000-8000-000000000001'"
    foreach ($effect in @('bindings','reservations','occurrences','receipts','successes')) {
      $parsed.Text | Should Match ('\$proof\.{0} -ne 0' -f $effect)
    }
    $parsed.Text | Should Match '\$proof\.denials -ne 1'
  }

  It 'does not obtain credentials or bypass database guards' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Not Match 'supabase\s+status'
    $parsed.Text | Should Not Match 'session_replication_role'
    $parsed.Text | Should Not Match '(?i)(password|service_role|anon_key|secret)'
  }
}
