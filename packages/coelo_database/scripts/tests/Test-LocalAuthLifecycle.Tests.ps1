$harnessPath = Join-Path $PSScriptRoot '..\Test-LocalAuthLifecycle.ps1'
$wrapperPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'
$configPath = Join-Path $PSScriptRoot '..\..\supabase\config.toml'

function Read-CoeloScript([string]$Path) {
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

Describe 'Local Auth lifecycle recovery contract' {
  It 'parses the harness and wrapper without errors' {
    (Read-CoeloScript $harnessPath).Errors.Count | Should Be 0
    (Read-CoeloScript $wrapperPath).Errors.Count | Should Be 0
  }

  It 'keeps Mailpit in the disposable Auth stack' {
    $wrapper = Read-CoeloScript $wrapperPath
    $wrapper.Text | Should Not Match "authLifecycleExcludes\s*=\s*'[^']*mailpit"
  }

  It 'retries one transient local stack startup without widening cleanup ownership' {
    $wrapper = Read-CoeloScript $wrapperPath
    $wrapper.Text | Should Match 'for \(\$startAttempt = 1; \$startAttempt -le 2; \$startAttempt\+\+\)'
    $wrapper.Text | Should Match 'supabase start failed after 2 attempts'
  }

  It 'proves request callback update old-password refusal reuse and expiration' {
    $harness = Read-CoeloScript $harnessPath
    $harness.Text | Should Match '/auth/v1/recover'
    $harness.Text | Should Match '/api/v1/messages'
    $harness.Text | Should Match "fragment\['type'\].*'recovery'"
    $harness.Text | Should Match '/auth/v1/user'
    $harness.Text | Should Match 'old password was not rejected'
    $harness.Text | Should Match 'old rotated refresh token was not rejected after logout'
    $harness.Text | Should Match 'password recovery responses can enumerate account existence'
    $harness.Text | Should Match 'recovery link reuse was not rejected'
    $harness.Text | Should Match 'expired recovery link was not rejected'
  }

  It 'allows same-origin local reset callbacks without opening arbitrary hosts' {
    $config = [IO.File]::ReadAllText($configPath)
    $config | Should Match 'http://127\.0\.0\.1:\*/reset-password'
    $config | Should Match 'http://localhost:\*/reset-password'
    $config | Should Not Match 'additional_redirect_urls\s*=\s*\["\*"\]'
  }

  It 'builds an Auth-only replay without the canonically blocked import chain' {
    $destination = Join-Path $TestDrive 'auth-migrations'
    New-Item -ItemType Directory -Path $destination | Out-Null

    & (Join-Path $PSScriptRoot '..\Prepare-SafeMigrationReplay.ps1') `
      -DestinationMigrationsRoot $destination -AuthOnly | Out-Null

    $names = @(Get-ChildItem -LiteralPath $destination -File -Filter '*.sql' |
      Sort-Object Name | Select-Object -ExpandProperty Name)
    ($names -contains '20260812000847_audit_production.sql') |
      Should Be $true
    ($names -contains '20260827214000_harden_default_function_execute_privileges.sql') |
      Should Be $true
    ($names -contains '20260827233000_superadmin_internal_auth_context.sql') |
      Should Be $true
    ($names -contains '20260901124500_harden_superadmin_auth_context_denial_audit.sql') |
      Should Be $true
    ($names -contains '20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql') |
      Should Be $true
    ($names -contains '20260812002010_import_export_unit_source_retention.sql') |
      Should Be $false
    $names[-1] | Should Be '20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql'
  }
}
