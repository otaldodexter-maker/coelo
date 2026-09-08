$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$wrapperPath = Join-Path $sourcePackageRoot 'scripts\Invoke-SafeLocalMigrationReplay.ps1'
$helperPath = Join-Path $sourcePackageRoot 'scripts\Test-LocalA01Runtime.ps1'
$wrapperText = [IO.File]::ReadAllText($wrapperPath)
$wrapperTokens = $null
$wrapperErrors = $null
$wrapperAst = [Management.Automation.Language.Parser]::ParseFile($wrapperPath, [ref]$wrapperTokens, [ref]$wrapperErrors)
$mutexAnchor = '$mutex = [Threading.Mutex]::new'
$mutexOffset = $wrapperText.IndexOf($mutexAnchor, [StringComparison]::Ordinal)
if ($mutexOffset -lt 0 -or $wrapperText.LastIndexOf($mutexAnchor, [StringComparison]::Ordinal) -ne $mutexOffset) {
  throw 'A01 integration fixture requires exactly one mutex boundary'
}
$prefixText = $wrapperText.Substring(0, $mutexOffset)
$boundaryMessage = 'A01 fixture stopped before mutex staging or Docker'

function Get-A01IntegrationHash([string]$Path) {
  $lf = [string][char]10
  $crlf = [string][char]13 + [char]10
  $text = [IO.File]::ReadAllText($Path).Replace($crlf, $lf).Replace([string][char]13, $lf).Replace($lf, $crlf)
  $sha = [Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($text)))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Get-A01IntegrationDotCall {
  @($wrapperAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Dot -and
      $node.Extent.StartOffset -lt $mutexOffset
  }, $true))
}

function Get-A01IntegrationRuntimeCall {
  $dotCalls = @(Get-A01IntegrationDotCall)
  $helperExpression = if ($dotCalls.Count -eq 1) { $dotCalls[0].CommandElements[0].Extent.Text } else { '' }
  @($wrapperAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
      $node.InvocationOperator -eq [Management.Automation.Language.TokenKind]::Ampersand -and
      $node.Extent.StartOffset -gt $mutexOffset -and
      ($node.CommandElements[0].Extent.Text -eq $helperExpression -or
       $node.CommandElements[0].Extent.Text -match 'Test-LocalA01Runtime\.ps1')
  }, $true))
}

function Assert-A01IntegrationArguments($Call) {
  $elements = @($Call.CommandElements | ForEach-Object { $_.Extent.Text })
  foreach ($pair in @(
    @{Parameter='-ProjectRoot'; Value='$projectRoot'},
    @{Parameter='-ProjectId'; Value='$projectId'},
    @{Parameter='-ClientRoot'; Value='$A01ClientRoot'}
  )) {
    $index = [Array]::IndexOf($elements, $pair.Parameter)
    $index | Should BeGreaterThan -1
    ($index + 1) | Should BeLessThan $elements.Count
    $elements[$index + 1] | Should Be $pair.Value
  }
}

function New-A01IntegrationFixture {
  $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
  $package = Join-Path $root 'repository\packages\coelo_database'
  $scripts = Join-Path $package 'scripts'
  $client = Join-Path $root 'client'
  foreach ($directory in @($scripts, $client, (Join-Path $package 'migrations'), (Join-Path $package 'supabase'), (Join-Path $package 'tests\fixtures'))) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [IO.File]::WriteAllText((Join-Path $package 'supabase\config.toml'), 'project_id = "a01_wrapper_fixture"')
  foreach ($version in @('20260907222911', '20260901200206')) {
    [IO.File]::WriteAllText((Join-Path $package ('migrations\' + $version + '_fixture.sql')), '-- Never executed.')
  }
  foreach ($profile in @('A01DirectoryAuditGreen', 'A01DirectoryAuditRed')) {
    $profileRoot = Join-Path $package ('replay\profiles\' + $profile)
    New-Item -ItemType Directory -Path $profileRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $profileRoot ('Resolve-' + $profile + '.ps1')),
      'param([string]$TargetVersion); if ($TargetVersion -ne "20260907222911") { throw "A01 fixture wrong target" }')
  }
  $seed = Join-Path $package 'tests\fixtures\a01_local_http_seed.sql'
  Copy-Item -LiteralPath (Join-Path $sourcePackageRoot 'tests\fixtures\a01_local_http_seed.sql') -Destination $seed
  $stub = @'
[CmdletBinding()]
param([string]$ProjectRoot,[string]$ProjectId,[string]$ClientRoot)
if ($MyInvocation.InvocationName -ne '.') { throw 'A01 fixture forbids runtime before the mutex' }
$global:A01WrapperTestTrace.Add('dot')
$global:A01WrapperTestLoad = @{ProjectRoot=$ProjectRoot;ProjectId=$ProjectId;ClientRoot=$ClientRoot}
function Assert-A01Client([string]$Root) {
  $global:A01WrapperTestTrace.Add('client')
  if ($global:A01WrapperTestFailClient -or $Root -cne $global:A01WrapperTestClient) { throw 'A01 fixture client rejected' }
  return Join-Path $Root 'apps\superadmin'
}
function Get-A01Inputs([string]$PackageRoot) {
  $global:A01WrapperTestTrace.Add('inputs')
  if ($global:A01WrapperTestFailInputs -or $PackageRoot -cne $global:A01WrapperTestPackage) { throw 'A01 fixture inputs rejected' }
  1..55 | ForEach-Object { [pscustomobject]@{Name=('fixture_{0}.sql' -f $_)} }
}
function Get-A01FileHash([string]$Path) {
  $lf=[string][char]10
  $crlf=[string][char]13+[char]10
  $text=[IO.File]::ReadAllText($Path).Replace($crlf,$lf).Replace([string][char]13,$lf).Replace($lf,$crlf)
  $sha=[Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($text)))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
'@
  $stubPath = Join-Path $scripts 'Test-LocalA01Runtime.ps1'
  [IO.File]::WriteAllText($stubPath, $stub, [Text.UTF8Encoding]::new($false))
  $copyPrefix = $prefixText
  $currentHelperHash = Get-A01IntegrationHash $helperPath
  $pinOccurrences = [regex]::Matches($copyPrefix, [regex]::Escape($currentHelperHash)).Count
  # Only TestDrive replaces the production pin with the observable inert helper's hash.
  # The separate source assertion requires the actual closed helper pin exactly once.
  if ($pinOccurrences -eq 1) {
    $copyPrefix = $copyPrefix.Replace($currentHelperHash, (Get-A01IntegrationHash $stubPath))
  }
  $copyPath = Join-Path $scripts 'Invoke-SafeLocalMigrationReplay.ps1'
  [IO.File]::WriteAllText($copyPath, $copyPrefix + "throw '$boundaryMessage'" + [Environment]::NewLine)
  $global:A01WrapperTestTrace = [Collections.Generic.List[string]]::new()
  $global:A01WrapperTestLoad = $null
  $global:A01WrapperTestClient = $client
  $global:A01WrapperTestPackage = $package
  $global:A01WrapperTestFailClient = $false
  $global:A01WrapperTestFailInputs = $false
  [pscustomobject]@{Root=$root; Package=$package; Client=$client; Wrapper=$copyPath; Helper=$stubPath; Seed=$seed}
}

function Invoke-A01IntegrationPrefix([hashtable]$Parameters) {
  try { & $fixture.Wrapper @Parameters | Out-Null; return $null }
  catch { return $_ }
}

function Assert-A01IntegrationRejection($Failure, [string]$Pattern = '^(A01 |A01DirectoryAuditGreen |nominal replay cannot be combined)') {
  $Failure | Should Not BeNullOrEmpty
  ($Failure.Exception -is [Management.Automation.ParameterBindingException]) | Should Be $false
  $Failure.FullyQualifiedErrorId | Should Not Match 'NamedParameterNotFound|ParameterBinding'
  $Failure.Exception.Message | Should Not Be $boundaryMessage
  $Failure.Exception.Message | Should Match $Pattern
  if ($null -ne $global:A01WrapperTestLoad) {
    (Test-Path -LiteralPath $global:A01WrapperTestLoad.ProjectRoot) | Should Be $false
  }
}

Describe 'A01 local runtime wrapper source contract' {
  It 'adds typed opt-in and client-root parameters without a keepalive switch' {
    @($wrapperErrors).Count | Should Be 0
    $run = @($wrapperAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -ceq 'RunA01LocalRuntime' })
    $client = @($wrapperAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -ceq 'A01ClientRoot' })
    $run.Count | Should Be 1
    $client.Count | Should Be 1
    $run[0].StaticType.FullName | Should Be 'System.Management.Automation.SwitchParameter'
    $client[0].StaticType.FullName | Should Be 'System.String'
    @($wrapperAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -match 'KeepAlive|NoCleanup|LeaveStack' }).Count | Should Be 0
  }

  It 'pins the actual helper and seed literally before the mutex boundary' {
    ($prefixText -match 'Test-LocalA01Runtime\.ps1') | Should Be $true
    ([regex]::Matches($prefixText, [regex]::Escape((Get-A01IntegrationHash $helperPath)))).Count | Should Be 1
    ([regex]::Matches($prefixText, '758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99')).Count | Should Be 1
    (Get-A01IntegrationHash (Join-Path $sourcePackageRoot 'tests\fixtures\a01_local_http_seed.sql')) |
      Should Be '758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99'
  }

  It 'dot-sources the helper with future project arguments before client and input checks' {
    $dot = @(Get-A01IntegrationDotCall)
    $dot.Count | Should Be 1
    Assert-A01IntegrationArguments $dot[0]
    foreach ($name in @('Assert-A01Client', 'Get-A01Inputs')) {
      $calls = @($wrapperAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq $name -and
          $node.Extent.StartOffset -lt $mutexOffset
      }, $true))
      $calls.Count | Should Be 1
      $calls[0].Extent.StartOffset | Should BeGreaterThan $dot[0].Extent.EndOffset
      $calls[0].Extent.StartOffset | Should BeLessThan $mutexOffset
    }
  }

  It 'selects the reviewed service group for auth=<auth> a01=<a01>' -TestCases @(
    @{auth=$false; a01=$false; expected='db-only'},
    @{auth=$true; a01=$false; expected='auth-services'},
    @{auth=$false; a01=$true; expected='auth-services'},
    @{auth=$true; a01=$true; expected='auth-services'}
  ) {
    param($auth,$a01,$expected)
    $assignments = @($wrapperAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$excludedServices'
    }, $true))
    $assignments.Count | Should Be 1
    $right = $assignments[0].Right
    @($right.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst]}, $true)).Count | Should Be 0
    @($right.FindAll({param($node) $node -is [Management.Automation.Language.InvokeMemberExpressionAst]}, $true)).Count | Should Be 0
    $variables = @($right.FindAll({param($node) $node -is [Management.Automation.Language.VariableExpressionAst]}, $true))
    @($variables | Where-Object { $_.VariablePath.UserPath -notin @('RunAuthLifecycle','RunA01LocalRuntime','authLifecycleExcludes','databaseOnlyExcludes') }).Count | Should Be 0
    $expression = [scriptblock]::Create('param($RunAuthLifecycle,$RunA01LocalRuntime); $authLifecycleExcludes="auth-services"; $databaseOnlyExcludes="db-only"; ' + $right.Extent.Text)
    (& $expression $auth $a01) | Should Be $expected
  }

  It 'calls the nominal helper only under the A01 flag with the three fixed arguments' {
    $calls = @(Get-A01IntegrationRuntimeCall)
    $calls.Count | Should Be 1
    Assert-A01IntegrationArguments $calls[0]
    $parent = $calls[0].Parent
    while ($null -ne $parent -and $parent -isnot [Management.Automation.Language.IfStatementAst]) { $parent = $parent.Parent }
    $parent | Should Not BeNullOrEmpty
    $parent.Clauses.Count | Should Be 1
    $parent.Clauses[0].Item1.Extent.Text.Trim() | Should Be '$RunA01LocalRuntime'
  }

  It 'calls after the successful reset guard inside the try whose finally cleans resources' {
    $calls = @(Get-A01IntegrationRuntimeCall)
    $calls.Count | Should Be 1
    $resetGuards = @($wrapperAst.FindAll({
      param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
        $node.Extent.Text -match 'safe local db reset failed' -and
        $node.Clauses[0].Item1.Extent.Text -match '\$LASTEXITCODE'
    }, $true))
    $resetGuards.Count | Should Be 1
    $calls[0].Extent.StartOffset | Should BeGreaterThan $resetGuards[0].Extent.EndOffset
    $parent = $calls[0].Parent
    while ($null -ne $parent -and $parent -isnot [Management.Automation.Language.TryStatementAst]) { $parent = $parent.Parent }
    $parent | Should Not BeNullOrEmpty
    $parent.Finally | Should Not BeNullOrEmpty
    $parent.Body.Extent.Text | Should Match 'db reset --local --no-seed --version \$TargetVersion'
    $parent.Finally.Extent.Text | Should Match 'stop --workdir \$projectRoot --no-backup'
    $parent.Finally.Extent.Text | Should Match 'Assert-NoReparseTree \$projectRoot'
    $parent.Finally.Extent.Text | Should Match 'Remove-Item -LiteralPath \$projectRoot'
    $parent.Finally.Extent.StartOffset | Should BeGreaterThan $calls[0].Extent.EndOffset
  }
}

Describe 'A01 local runtime wrapper rejects before any resource boundary' {
  BeforeEach {
    $fixture = New-A01IntegrationFixture
    $parameters = @{
      TargetVersion='20260907222911'; NominalProfile='A01DirectoryAuditGreen'
      RunA01LocalRuntime=$true; A01ClientRoot=$fixture.Client
    }
  }
  AfterEach {
    foreach ($name in @('A01WrapperTestTrace','A01WrapperTestLoad','A01WrapperTestClient','A01WrapperTestPackage','A01WrapperTestFailClient','A01WrapperTestFailInputs')) {
      Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
    }
  }

  It 'reaches only the pre-mutex sentinel for the accepted profile spelling <profile>' -TestCases @(
    @{profile='A01DirectoryAuditGreen'}, @{profile='a01directoryauditgreen'}, @{profile='A01DIRECTORYAUDITGREEN'}
  ) {
    param($profile)
    $parameters.NominalProfile = $profile
    $failure = Invoke-A01IntegrationPrefix $parameters
    $failure.Exception.Message | Should Be $boundaryMessage
    @($global:A01WrapperTestTrace | Where-Object { $_ -eq 'dot' }).Count | Should Be 1
    @($global:A01WrapperTestTrace | Where-Object { $_ -eq 'client' }).Count | Should Be 1
    @($global:A01WrapperTestTrace | Where-Object { $_ -eq 'inputs' }).Count | Should Be 1
    $global:A01WrapperTestLoad.ClientRoot | Should Be $fixture.Client
    $global:A01WrapperTestLoad.ProjectId | Should Match '^coelo_safe_[0-9a-f]{29}$'
    $global:A01WrapperTestLoad.ProjectRoot | Should Be (Join-Path ([IO.Path]::GetTempPath()) $global:A01WrapperTestLoad.ProjectId)
    (Test-Path -LiteralPath $global:A01WrapperTestLoad.ProjectRoot) | Should Be $false
  }

  It 'rejects incompatible option <mode> before importing the helper' -TestCases @(
    @{mode='FoundationOnly'}, @{mode='AuthOnly'}, @{mode='AdditionalMigration'},
    @{mode='RunAuthLifecycle'}, @{mode='RunActivityV2Concurrency'}, @{mode='TestPath'}, @{mode='RunLint'}
  ) {
    param($mode)
    $parameters[$mode] = switch ($mode) {
      AdditionalMigration { @('20260908031000_unapproved.sql|' + ('0' * 64)) }
      TestPath { @('unapproved.sql') }
      default { $true }
    }
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure
    $global:A01WrapperTestTrace.Count | Should Be 0
  }

  It 'rejects an unapproved selection <kind> before importing the helper' -TestCases @(
    @{kind='missing-profile'}, @{kind='red-profile'}, @{kind='earlier-target'}
  ) {
    param($kind)
    switch ($kind) {
      missing-profile { $parameters.Remove('NominalProfile') }
      red-profile { $parameters.NominalProfile = 'A01DirectoryAuditRed' }
      earlier-target { $parameters.TargetVersion = '20260901200206' }
    }
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure
    $global:A01WrapperTestTrace.Count | Should Be 0
  }

  It 'rejects a client root supplied without the runtime opt-in' {
    $parameters.Remove('RunA01LocalRuntime')
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure
    $global:A01WrapperTestTrace.Count | Should Be 0
  }

  It 'rejects an empty client root <value>' -TestCases @(@{value=''}, @{value='   '}) {
    param($value)
    $parameters.A01ClientRoot = $value
    Assert-A01IntegrationRejection (Invoke-A01IntegrationPrefix $parameters)
  }

  It 'rejects helper <change> before importing any helper function' -TestCases @(@{change='missing'}, @{change='changed'}) {
    param($change)
    if ($change -eq 'missing') { Remove-Item -LiteralPath $fixture.Helper }
    else { [IO.File]::AppendAllText($fixture.Helper, '# unapproved helper drift') }
    Assert-A01IntegrationRejection (Invoke-A01IntegrationPrefix $parameters)
    $global:A01WrapperTestTrace.Count | Should Be 0
  }

  It 'rejects seed <change> before the resource boundary' -TestCases @(@{change='missing'}, @{change='changed'}) {
    param($change)
    if ($change -eq 'missing') { Remove-Item -LiteralPath $fixture.Seed }
    else { [IO.File]::AppendAllText($fixture.Seed, '-- unapproved seed drift') }
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure '(?i)A01|a01_local_http_seed'
  }

  It 'propagates the client validation failure before the resource boundary' {
    $global:A01WrapperTestFailClient = $true
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure '^A01 fixture client rejected$'
    @($global:A01WrapperTestTrace | Where-Object { $_ -eq 'client' }).Count | Should Be 1
  }

  It 'propagates the closed Green55 input validation failure before the resource boundary' {
    $global:A01WrapperTestFailInputs = $true
    $failure = Invoke-A01IntegrationPrefix $parameters
    Assert-A01IntegrationRejection $failure '^A01 fixture inputs rejected$'
    @($global:A01WrapperTestTrace | Where-Object { $_ -eq 'inputs' }).Count | Should Be 1
  }
}
