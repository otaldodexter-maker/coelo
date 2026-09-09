param(
  [Parameter(Mandatory = $true)]
  [string]$RunnerPath
)

$sourceRunner = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $RunnerPath).Path)
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'child-directory-runner-test-' + [guid]::NewGuid().ToString('N')
)
$fixturePackage = Join-Path $fixtureRoot 'packages\coelo_database'
$fixtureScripts = Join-Path $fixturePackage 'scripts'
$fixtureRunner = Join-Path $fixtureScripts 'Invoke-SafeLocalMigrationReplay.ps1'
$fixtureTests = Join-Path $fixturePackage 'supabase\tests'
$canonicalTap = Join-Path $fixtureTests 'superadmin_child_context_directory_v2_test.sql'
$wrongTap = Join-Path $fixtureTests 'wrong_test.sql'
$secondTap = Join-Path $fixtureTests 'second_test.sql'
$expectedProfileError = 'CHILD concurrency requires exact ChildDirectoryEnvelope target without other profiles, additions or concurrency'
$expectedTapError = 'CHILD concurrency requires exactly the canonical child directory TAP'
$sentinelError = 'CHILD_RUNNER_TEST_SENTINEL_BEFORE_MUTEX'

New-Item -ItemType Directory -Path $fixtureScripts -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixturePackage 'migrations') -Force | Out-Null
New-Item -ItemType Directory -Path $fixtureTests -Force | Out-Null
$resolverRoot = Join-Path $fixturePackage 'replay\profiles\ChildDirectoryEnvelope'
New-Item -ItemType Directory -Path $resolverRoot -Force | Out-Null

[IO.File]::WriteAllText(
  (Join-Path $fixturePackage 'supabase\config.toml'),
  'project_id = "child-runner-fixture"',
  [Text.UTF8Encoding]::new($false)
)
foreach ($path in @($canonicalTap, $wrongTap, $secondTap)) {
  [IO.File]::WriteAllText($path, 'select 1;', [Text.UTF8Encoding]::new($false))
}
foreach ($version in @('20260908051500', '20260908051501')) {
  [IO.File]::WriteAllText(
    (Join-Path $fixturePackage "migrations\$($version)_stub.sql"),
    'select 1;',
    [Text.UTF8Encoding]::new($false)
  )
}
[IO.File]::WriteAllText(
  (Join-Path $resolverRoot 'Resolve-ChildDirectoryEnvelope.ps1'),
  "param([string]`$TargetVersion)`n",
  [Text.UTF8Encoding]::new($false)
)

$runnerText = [IO.File]::ReadAllText($sourceRunner)
$mutexLine = '$mutex = [Threading.Mutex]::new($false, ''Local\CoeloSafeSupabaseReplay'')'
if (($runnerText.Split(@($mutexLine), [StringSplitOptions]::None).Count - 1) -ne 1) {
  throw 'runner fixture could not locate exactly one mutex construction'
}
$runnerText = $runnerText.Replace(
  $mutexLine,
  "throw '$sentinelError'`n$mutexLine"
)
[IO.File]::WriteAllText($fixtureRunner, $runnerText, [Text.UTF8Encoding]::new($false))

function Get-RunnerFailure([hashtable]$Arguments) {
  try {
    & $fixtureRunner @Arguments
    return $null
  }
  catch {
    return $_.Exception.Message
  }
}

function New-ValidArguments {
  @{
    TargetVersion = '20260908051500'
    NominalProfile = 'ChildDirectoryEnvelope'
    TestPath = @($canonicalTap)
    RunChildDirectoryConcurrency = $true
  }
}

Describe 'CHILD concurrency safe replay runner contract' {
  It 'parses and exposes the new switch without removing existing runners' {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile(
      $sourceRunner, [ref]$tokens, [ref]$errors
    )
    @($errors).Count | Should Be 0
    $parameters = @($ast.ParamBlock.Parameters | ForEach-Object {
      $_.Name.VariablePath.UserPath
    })
    ($parameters -contains 'RunChildDirectoryConcurrency') | Should Be $true
    ($parameters -contains 'RunAuthLifecycle') | Should Be $true
    ($parameters -contains 'RunActivityV2Concurrency') | Should Be $true
    ($parameters -contains 'RunR02AuthProofConcurrency') | Should Be $true
    $text = [IO.File]::ReadAllText($sourceRunner)
    $text | Should Match 'Test-LocalAuthLifecycle\.ps1'
    $text | Should Match 'Test-ActivityV2Concurrency\.ps1'
    $text | Should Match 'Test-R02AuthProofConcurrency\.ps1'
  }

  It 'rejects a missing or different nominal profile before the mutex' {
    foreach ($profile in @($null, 'ActivityAggregateConcurrency')) {
      $arguments = New-ValidArguments
      if ($null -eq $profile) { $arguments.Remove('NominalProfile') }
      else { $arguments.NominalProfile = $profile }
      Get-RunnerFailure $arguments | Should Be $expectedProfileError
    }
  }

  It 'rejects every other target before the mutex' {
    $arguments = New-ValidArguments
    $arguments.TargetVersion = '20260908051501'
    Get-RunnerFailure $arguments | Should Be $expectedProfileError
  }

  It 'rejects incompatible profiles, additions and concurrency before the mutex' {
    $incompatible = @(
      @{ FoundationOnly = $true },
      @{ AuthOnly = $true },
      @{ AdditionalMigration = @('20260908051502_stub.sql|' + ('a' * 64)) },
      @{ RunAuthLifecycle = $true },
      @{ RunActivityV2Concurrency = $true },
      @{ RunR02AuthProofConcurrency = $true }
    )
    foreach ($modifier in $incompatible) {
      $arguments = New-ValidArguments
      foreach ($entry in $modifier.GetEnumerator()) {
        $arguments[$entry.Key] = $entry.Value
      }
      Get-RunnerFailure $arguments | Should Be $expectedProfileError
    }
  }

  It 'requires one canonical CHILD TAP after path resolution' {
    foreach ($case in @(
      @{ Paths = @() },
      @{ Paths = @($wrongTap) },
      @{ Paths = @($canonicalTap, $secondTap) }
    )) {
      $arguments = New-ValidArguments
      $arguments.TestPath = $case.Paths
      Get-RunnerFailure $arguments | Should Be $expectedTapError
    }
  }

  It 'accepts case-insensitive canonical profile spelling and reaches the sentinel' {
    $arguments = New-ValidArguments
    $arguments.NominalProfile = 'childdirectoryenvelope'
    Get-RunnerFailure $arguments | Should Be $sentinelError
  }

  It 'dispatches CHILD concurrency after pgTAP with the owned replay identity' {
    $text = [IO.File]::ReadAllText($sourceRunner)
    $tapIndex = $text.IndexOf('if ($resolvedTestPaths.Count -gt 0)')
    $childIndex = $text.IndexOf('if ($RunChildDirectoryConcurrency)', $tapIndex)
    $authIndex = $text.IndexOf('if ($RunAuthLifecycle)', $childIndex)
    $tapIndex | Should BeGreaterThan -1
    $childIndex | Should BeGreaterThan $tapIndex
    $authIndex | Should BeGreaterThan $childIndex
    $text.Substring($childIndex, $authIndex - $childIndex) |
      Should Match 'Test-ChildDirectoryConcurrency\.ps1'
    $text.Substring($childIndex, $authIndex - $childIndex) |
      Should Match '-ProjectRoot \$projectRoot'
    $text.Substring($childIndex, $authIndex - $childIndex) |
      Should Match '-ProjectId \$projectId'
  }

  It 'keeps CHILD guards ahead of mutex construction and resource inspection' {
    $text = [IO.File]::ReadAllText($sourceRunner)
    $profileGuard = $text.IndexOf($expectedProfileError)
    $tapGuard = $text.IndexOf($expectedTapError)
    $mutexIndex = $text.IndexOf('$mutex = [Threading.Mutex]::new')
    $profileGuard | Should BeGreaterThan -1
    $tapGuard | Should BeGreaterThan $profileGuard
    $mutexIndex | Should BeGreaterThan $tapGuard
  }

  AfterAll {
    $fixtureFull = [IO.Path]::GetFullPath($fixtureRoot)
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    if ((Split-Path -Parent $fixtureFull) -ine $expectedParent -or
        (Split-Path -Leaf $fixtureFull) -notmatch '^child-directory-runner-test-[a-f0-9]{32}$') {
      throw 'refusing cleanup outside the owned temporary runner fixture'
    }
    if (Test-Path -LiteralPath $fixtureFull) {
      Remove-Item -LiteralPath $fixtureFull -Recurse -Force
    }
  }
}
