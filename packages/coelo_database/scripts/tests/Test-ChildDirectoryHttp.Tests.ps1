$harnessPath = Join-Path $PSScriptRoot '..\Test-ChildDirectoryHttp.ps1'

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

Describe 'CHILD directory local HTTP harness structure' {
  It 'exists and parses without errors' {
    Test-Path -LiteralPath $harnessPath -PathType Leaf | Should Be $true
    $parsed = Parse-Script $harnessPath
    $parsed.Errors.Count | Should Be 0
  }

  It 'accepts only the owned disposable replay project' {
    $parsed = Parse-Script $harnessPath
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'ProjectRoot') | Should Be $true
    ($parameters -contains 'ProjectId') | Should Be $true
    $parsed.Text | Should Match '\^coelo_safe_\[0-9a-f\]\{29\}\$'
    $parsed.Text | Should Match '\.coelo-safe-replay'
    $parsed.Text | Should Match 'supabase_db_\$ProjectId'
    $parsed.Text | Should Match 'Assert-NoReparseAncestors'
    $parsed.Text | Should Match 'requires a clean one-shot disposable database'
  }

  It 'derives a loopback HTTP environment without exposing credentials' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'Get-LocalHttpEnvironment'
    $parsed.Text | Should Match 'API_URL'
    $parsed.Text | Should Match 'ANON_KEY'
    $parsed.Text | Should Match '127\.0\.0\.1'
    $parsed.Text | Should Match 'HttpClientHandler'
    $parsed.Text | Should Match 'AllowAutoRedirect = \$false'
    $parsed.Text | Should Match 'UseProxy = \$false'
    foreach ($uriPart in @('AbsolutePath', 'UserInfo', 'Query', 'Fragment')) {
      $parsed.Text | Should Match $uriPart
    }
    $parsed.Text | Should Not Match '(?i)(service_role|person_auth_links)'
    $parsed.Text | Should Not Match '(?im)Write-(Host|Output|Verbose|Information|Debug).*?(ANON_KEY|JWT|access_token|refresh_token)'
  }

  It 'creates isolated owner fixtures without weakening lifecycle guards' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'Invoke-OwnedContainerSql'
    $parsed.Text | Should Match '--no-psqlrc'
    $parsed.Text | Should Match 'ON_ERROR_STOP'
    $parsed.Text | Should Match '9d100000-'
    $parsed.Text | Should Match 'child-http-.*@example\.invalid'
    $parsed.Text | Should Match "code='owner'"
    $parsed.Text | Should Match 'backup'
    $parsed.Text | Should Match 'institution-b'
    $parsed.Text | Should Not Match 'session_replication_role'
  }

  It 'checks two pages and reload using the five-field CHILD DTO' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'Invoke-LocalJsonRequest'
    $parsed.Text | Should Match 'superadmin_child_context_directory_v2'
    $parsed.Text | Should Match 'Assert-ChildPage'
    $parsed.Text | Should Match 'ExpectedContextIds'
    $parsed.Text | Should Match 'ExpectedPersonIds'
    $parsed.Text | Should Match '\[guid\]::Parse'
    $parsed.Text | Should Match '9d100000-0000-4000-8000-000000000010'
    $parsed.Text | Should Match 'CHILD HTTP Institution A'
    foreach ($field in @('context_id', 'person_id', 'person_name', 'institution_id', 'institution_name')) {
      $parsed.Text | Should Match $field
    }
    $parsed.Text | Should Match 'next_cursor'
    $parsed.Text | Should Match '(?i)reload'
  }

  It 'makes cross-tenant and unknown identifiers indistinguishable denials' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'Assert-ChildDenial'
    $parsed.Text | Should Match 'SAI_PERMISSION_DENIED'
    $parsed.Text | Should Match '(?i)tenant-b'
    $parsed.Text | Should Match '(?i)unknown'
    $parsed.Text | Should Match '\$null -ne \$Response\.data'
    foreach ($auditField in @('success_count', 'denied_count', 'payload_count', 'denied_institution_count')) {
      $parsed.Text | Should Match "'$auditField'"
    }
    $parsed.Text | Should Match "actor_internal_identity_id='9d100000-0000-4000-8000-000000000401'"
    $parsed.Text | Should Match 'success_count -ne 3'
    $parsed.Text | Should Match 'denied_count -ne 3'
  }

  It 'revokes the membership version and retries with the same token' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match 'version=membership\.version\+1'
    $parsed.Text | Should Match 'SAI_MEMBERSHIP_REVOKED'
    $parsed.Text | Should Match '(?i)same token'
  }

  It 'bounds local operations and owns cleanup' {
    $parsed = Parse-Script $harnessPath
    $parsed.Text | Should Match '(?i)timeout'
    $parsed.Text | Should Match 'finally'
    $parsed.Text | Should Match '\.Kill\(\)'
    $parsed.Text | Should Match '\.Dispose\(\)'
    $parsed.Text | Should Match 'CHILD HTTP local PASS'
  }
}
