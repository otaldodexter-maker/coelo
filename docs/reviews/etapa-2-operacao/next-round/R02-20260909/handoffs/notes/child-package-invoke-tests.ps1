[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RunnerPath
)

# Source snapshot: 61d3720c88c6b488ee5fdbefbb630b168035db0f
# Source SHA-256 bytes: 9E2A367DE74F0BDFF758B6029E58AF43669686F7A1BB3E9E16B9A23601364ED9
# Source SHA-256 normalized LF: CB2449D3F6F621B25CFE090D065A5CF9D1435180D7AA52781E51CF31ADCE0CC1

function Parse-Runner([string]$Path) {
  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$tokens,
    [ref]$errors
  )
  [pscustomobject]@{ Ast = $ast; Errors = @($errors); Text = [IO.File]::ReadAllText($Path) }
}

Describe 'CHILD remote package runner hook structure' {
  It 'requires an existing candidate that parses' {
    Test-Path -LiteralPath $RunnerPath -PathType Leaf | Should Be $true
    $parsed = Parse-Runner $RunnerPath
    $parsed.Errors.Count | Should Be 0
  }

  It 'adds the opt-in switch without removing existing modes' {
    $parsed = Parse-Runner $RunnerPath
    $parameters = @($parsed.Ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    foreach ($name in @(
        'RunChildRemotePackage', 'RunAuthLifecycle', 'RunAuthRecoveryBoundary',
        'RunR02AuthProofConcurrency', 'RunChildDirectoryConcurrency',
        'RunChildDirectoryHttp', 'RunActivityV2Concurrency',
        'RunLocationReservationsAuditAuthorization')) {
      ($parameters -contains $name) | Should Be $true
    }
  }

  It 'rejects every non-AuthOnly package combination before the mutex' {
    $parsed = Parse-Runner $RunnerPath
    $guardStart = $parsed.Text.IndexOf('if ($RunChildRemotePackage -and (')
    $guardEnd = $parsed.Text.IndexOf("throw 'CHILD package requires exact AuthOnly", $guardStart)
    $mutexStart = $parsed.Text.IndexOf('$mutex = [Threading.Mutex]::new')
    $guardStart | Should BeGreaterThan -1
    $guardEnd | Should BeGreaterThan $guardStart
    $mutexStart | Should BeGreaterThan $guardEnd
    $guard = $parsed.Text.Substring($guardStart, $guardEnd - $guardStart)
    foreach ($required in @(
        '-not $AuthOnly', "'20260901200206'", '$FoundationOnly', '$NominalProfile',
        '$AdditionalMigration.Count -gt 0', '$TestPath.Count -gt 0', '$RunLint',
        '$RunAuthLifecycle', '$RunAuthRecoveryBoundary', '$AssertAuthRecoveryConfined',
        '$RunR02AuthProofConcurrency', '$RunChildDirectoryConcurrency',
        '$RunChildDirectoryHttp', '$RunActivityV2Concurrency',
        '$RunLocationReservationsAuditAuthorization')) {
      $guard.Contains($required) | Should Be $true
    }
  }

  It 'selects the database-only service composition for the package' {
    $parsed = Parse-Runner $RunnerPath
    $parsed.Text | Should Match '(?s)elseif \(\$RunChildRemotePackage\) \{\s*\$databaseOnlyExcludes\s*\}'
    $databaseOnly = [regex]::Match(
      $parsed.Text,
      "(?m)^\`$databaseOnlyExcludes = '([^']+)'$"
    )
    $databaseOnly.Success | Should Be $true
    $excluded = @($databaseOnly.Groups[1].Value -split ',')
    foreach ($service in @('gotrue', 'kong', 'postgrest', 'mailpit', 'edge-runtime')) {
      ($excluded -contains $service) | Should Be $true
    }
  }

  It 'dispatches the reviewed harness only after replay and the pgTAP gate' {
    $parsed = Parse-Runner $RunnerPath
    $prepare = $parsed.Text.IndexOf("Join-Path `$scriptRoot 'Prepare-SafeMigrationReplay.ps1'")
    $reset = $parsed.Text.IndexOf('db reset --local')
    $tapFailure = $parsed.Text.IndexOf('safe local pgTAP failed with exit code')
    $dispatch = $parsed.Text.IndexOf("Join-Path `$scriptRoot 'Test-ChildRemotePackage.ps1'")
    $prepare | Should BeGreaterThan -1
    $reset | Should BeGreaterThan $prepare
    $tapFailure | Should BeGreaterThan $reset
    $dispatch | Should BeGreaterThan $tapFailure
    $parsed.Text | Should Match '(?s)Test-ChildRemotePackage\.ps1''\)\s*`\s*-ProjectRoot \$projectRoot\s*`\s*-ProjectId \$projectId'
  }

  It 'keeps the existing Auth, CHILD, Activity and location dispatches' {
    $parsed = Parse-Runner $RunnerPath
    foreach ($script in @(
        'Test-LocalAuthLifecycle.ps1', 'Test-LocalAuthRecoveryBoundary.ps1',
        'Test-LocationReservationsAuditAuthorization.ps1',
        'Test-ActivityV2Concurrency.ps1', 'Test-ChildDirectoryConcurrency.ps1',
        'Test-ChildDirectoryHttp.ps1', 'Test-R02AuthProofConcurrency.ps1')) {
      $parsed.Text | Should Match ([regex]::Escape($script))
    }
  }
}
