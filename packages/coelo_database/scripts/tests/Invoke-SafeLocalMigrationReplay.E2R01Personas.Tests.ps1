# WIP I021 preserved at R01 closure: not executed; runner/harness implementation absent.
# Do not integrate this draft as completed coverage. See handoffs/C01.md revision 51.
# I021 offline contract tests. Never invoke the real replay runner or Docker.
# Only the parsed guard/service expressions and a nominal harness call against
# a TestDrive stub execute; cleanup assertions inspect the actual AST.
$runnerPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'
$tokens = $null
$parseErrors = $null
$runnerAst = [Management.Automation.Language.Parser]::ParseFile(
  $runnerPath, [ref]$tokens, [ref]$parseErrors
)

function Get-E2R01Guard {
  $matches = @($runnerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.IfStatementAst] -and
      $node.Clauses[0].Item1.Extent.Text -match '^\$RunE2R01Personas\s+-and'
  }, $true))
  if ($matches.Count -ne 1) { throw 'expected one explicit E2 R01 compatibility guard' }
  return $matches[0]
}

function Invoke-E2R01Guard([hashtable]$Flags) {
  $RunE2R01Personas = $true
  $AuthOnly = $true
  $FoundationOnly = $false
  $NominalProfile = ''
  $RunAuthLifecycle = $false
  $RunActivityV2Concurrency = $false
  foreach ($key in $Flags.Keys) { Set-Variable -Name $key -Value $Flags[$key] }
  & ([scriptblock]::Create((Get-E2R01Guard).Extent.Text))
}

function Get-E2R01HarnessCall {
  $calls = @($runnerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.CommandElements.Count -gt 0 -and
      $node.CommandElements[0].Extent.Text -match 'Test-E2R01PersonasLocal\.ps1'
  }, $true))
  if ($calls.Count -ne 1) { throw 'expected one nominal E2 R01 harness call' }
  return $calls[0]
}

function Get-E2R01Assignment([string]$Name) {
  $matches = @($runnerAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.AssignmentStatementAst] -and
      $node.Left.Extent.Text -eq ('$' + $Name)
  }, $true))
  if ($matches.Count -ne 1) { throw "expected one assignment for $Name" }
  return $matches[0]
}

Describe 'E2 R01 personas replay integration (offline)' {
  It 'parses and exposes an opt-in switch' {
    @($parseErrors).Count | Should Be 0
    $parameter = @($runnerAst.ParamBlock.Parameters | Where-Object {
      $_.Name.VariablePath.UserPath -eq 'RunE2R01Personas'
    })
    $parameter.Count | Should Be 1
    $parameter[0].StaticType | Should Be ([Management.Automation.SwitchParameter])
  }

  It 'rejects each incompatible mode before allocating the replay lease' {
    foreach ($flags in @(
      @{ AuthOnly = $false }, @{ FoundationOnly = $true },
      @{ NominalProfile = 'N01PrerequisitesRed' },
      @{ RunAuthLifecycle = $true }, @{ RunActivityV2Concurrency = $true }
    )) {
      { Invoke-E2R01Guard $flags } | Should Throw 'E2 R01 personas requires AuthOnly'
    }
    $guard = Get-E2R01Guard
    $mutex = @($runnerAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and
        $node.Extent.Text -match '\[Threading.Mutex\]::new'
    }, $true))
    $mutex.Count | Should Be 1
    $guard.Extent.StartOffset | Should BeLessThan $mutex[0].Extent.StartOffset
  }

  It 'permits only the requested AuthOnly combination and leaves legacy modes untouched' {
    { Invoke-E2R01Guard @{} } | Should Not Throw
    { Invoke-E2R01Guard @{ RunE2R01Personas = $false; AuthOnly = $false; FoundationOnly = $true } } | Should Not Throw
    { Invoke-E2R01Guard @{ RunE2R01Personas = $false; RunAuthLifecycle = $true } } | Should Not Throw
    { Invoke-E2R01Guard @{ RunE2R01Personas = $false; RunActivityV2Concurrency = $true } } | Should Not Throw
  }

  It 'selects the existing Auth service set for either Auth harness and keeps the database default' {
    $authLifecycleExcludes = & ([scriptblock]::Create((Get-E2R01Assignment 'authLifecycleExcludes').Right.Extent.Text))
    $databaseOnlyExcludes = & ([scriptblock]::Create((Get-E2R01Assignment 'databaseOnlyExcludes').Right.Extent.Text))
    $selection = [scriptblock]::Create((Get-E2R01Assignment 'excludedServices').Right.Extent.Text)
    foreach ($flags in @(@($false, $true), @($true, $false))) {
      $RunAuthLifecycle = $flags[0]
      $RunE2R01Personas = $flags[1]
      (& $selection) | Should Be $authLifecycleExcludes
    }
    $RunAuthLifecycle = $false
    $RunE2R01Personas = $false
    (& $selection) | Should Be $databaseOnlyExcludes
    foreach ($service in @('gotrue', 'kong', 'mailpit', 'postgrest')) {
      (($authLifecycleExcludes -split ',') -contains $service) | Should Be $false
      (($databaseOnlyExcludes -split ',') -contains $service) | Should Be $true
    }
  }

  It 'forwards only the owned project root and ID to the nominal harness' {
    $scriptRoot = Join-Path $TestDrive 'nominal-stub'
    New-Item -ItemType Directory -Path $scriptRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $scriptRoot 'Test-E2R01PersonasLocal.ps1'), @'
param([string]$ProjectRoot, [string]$ProjectId)
[pscustomobject]@{ Root = $ProjectRoot; Id = $ProjectId; Extra = $args.Count }
'@)
    $projectId = 'coelo_safe_' + ('a' * 29)
    $projectRoot = Join-Path $TestDrive $projectId
    $call = Get-E2R01HarnessCall
    $result = @(& ([scriptblock]::Create($call.Extent.Text)))
    $result.Count | Should Be 1
    $result[0].Root | Should Be $projectRoot
    $result[0].Id | Should Be $projectId
    $result[0].Extra | Should Be 0
    @($call.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] }).Count | Should Be 2
  }

  It 'invokes the harness only when enabled and propagates its failure' {
    $call = Get-E2R01HarnessCall
    $gate = $call.Parent
    while ($gate -and $gate -isnot [Management.Automation.Language.IfStatementAst]) { $gate = $gate.Parent }
    $gate.Clauses[0].Item1.Extent.Text | Should Be '$RunE2R01Personas'
    $scriptRoot = Join-Path $TestDrive 'failing-stub'
    New-Item -ItemType Directory -Path $scriptRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $scriptRoot 'Test-E2R01PersonasLocal.ps1'), "throw 'synthetic nominal failure'")
    $RunE2R01Personas = $false
    { & ([scriptblock]::Create($gate.Extent.Text)) } | Should Not Throw
    $RunE2R01Personas = $true
    { & ([scriptblock]::Create($gate.Extent.Text)) } | Should Throw 'synthetic nominal failure'
  }

  It 'keeps the harness after successful reset inside the existing cleanup try' {
    $call = Get-E2R01HarnessCall
    $owner = $call.Parent
    while ($owner -and $owner -isnot [Management.Automation.Language.TryStatementAst]) { $owner = $owner.Parent }
    ($null -ne $owner.Finally) | Should Be $true
    $body = $owner.Body.Extent.Text
    $reset = $body.IndexOf('db reset --local --no-seed')
    $resetFailure = $body.IndexOf('safe local db reset failed')
    $harness = $body.IndexOf('Test-E2R01PersonasLocal.ps1')
    $reset | Should BeGreaterThan -1
    $resetFailure | Should BeGreaterThan $reset
    $harness | Should BeGreaterThan $resetFailure
    $owner.CatchClauses.Extent.Text | Should Match '\$primaryFailure = \$_\.Exception'
    $cleanup = $owner.Finally.Extent.Text
    $cleanup | Should Match 'stop --workdir \$projectRoot --no-backup --yes'
    $cleanup | Should Match '\.coelo-safe-replay'
    $cleanup | Should Match 'Assert-NoReparseTree \$projectRoot'
    $cleanup | Should Match 'Remove-Item -LiteralPath \$projectRoot -Recurse -Force'
    $cleanup | Should Match 'Get-DockerResources \$projectId'
    $cleanup | Should Match '\$mutex.ReleaseMutex\(\)'
  }
}
