param([Parameter(Mandatory=$true)][string]$RunnerPath)
$ErrorActionPreference = 'Stop'
$canonicalScriptRoot = Split-Path -Parent $PSScriptRoot
$packageRoot = Split-Path -Parent $canonicalScriptRoot
$tap = Join-Path $packageRoot 'supabase\tests\superadmin_child_context_directory_v2_test.sql'
$runnerText = [IO.File]::ReadAllText($RunnerPath)

Describe 'CHILD HTTP runner closed offline gate' {
  BeforeEach {
    # Exercise the real pre-resource guards, replacing only script location.
    # Stop before mutex acquisition, port allocation, Docker or filesystem writes.
    $sentinel = '$mutex = [Threading.Mutex]::new'
    $cut = $runnerText.IndexOf($sentinel, [StringComparison]::Ordinal)
    if ($cut -lt 0) { throw 'Runner has no pre-resource boundary' }
    $prefix = $runnerText.Substring(0, $cut).Replace(
      '$scriptRoot = $PSScriptRoot',
      ('$scriptRoot = ''' + $canonicalScriptRoot.Replace("'", "''") + ''''))
    $probe = [scriptblock]::Create($prefix + "throw 'HTTP_OFFLINE_BOUNDARY'")
    $valid = @{ TargetVersion='20260908051500'; NominalProfile='ChildDirectoryEnvelope';
      RunChildDirectoryHttp=$true; TestPath=@($tap) }
  }

  It 'parses and accepts only the nominal HTTP invocation before resources' {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseInput($runnerText,[ref]$tokens,[ref]$errors)
    @($errors).Count | Should Be 0
    { & $probe @valid } | Should Throw 'HTTP_OFFLINE_BOUNDARY'
    $valid.TestPath=@($tap.ToUpperInvariant())
    { & $probe @valid } | Should Throw 'HTTP_OFFLINE_BOUNDARY'
  }

  It 'rejects all incompatible modes and wrong profile or target before resources' {
    foreach ($mode in @('FoundationOnly','AuthOnly','RunAuthLifecycle','RunAuthRecoveryBoundary',
      'RunR02AuthProofConcurrency','RunActivityV2Concurrency','RunChildDirectoryConcurrency')) {
      $attempt=$valid.Clone(); $attempt[$mode]=$true
      $caught=$null
      try { & $probe @attempt } catch { $caught=$_.Exception.Message }
      $caught | Should Not BeNullOrEmpty
      $caught | Should Not Match 'HTTP_OFFLINE_BOUNDARY'
    }
    foreach ($delta in @(@{NominalProfile='LocationCatalogV2'},
      @{TargetVersion='20260901200206'}, @{AdditionalMigration=@('unexpected')})) {
      $attempt=$valid.Clone(); foreach($key in $delta.Keys) { $attempt[$key]=$delta[$key] }
      { & $probe @attempt } | Should Throw 'CHILD HTTP requires exact'
    }
  }

  It 'rejects absent duplicate or alternative TAP before resources' {
    $alternative = @(Get-ChildItem (Join-Path $packageRoot 'supabase\tests') -Filter '*.sql' |
      Where-Object FullName -ne $tap)[0].FullName
    foreach ($paths in @(@(), @($tap,$tap), @($alternative))) {
      $attempt=$valid.Clone(); $attempt.TestPath=$paths
      { & $probe @attempt } | Should Throw 'requires exactly the nominal CHILD TAP'
    }
  }

  It 'keeps HTTP services without invoking Auth lifecycle and dispatches after TAP' {
    $selector=[regex]::Match($runnerText,'(?s)\$excludedServices = if \(.*?\n  }\s+else \{.*?\n  }')
    $selector.Success | Should Be $true
    foreach ($enabled in @($false,$true)) {
      $RunAuthLifecycle=$false; $RunAuthRecoveryBoundary=$false; $RunChildDirectoryHttp=$enabled
      $authLifecycleExcludes='auth'; $databaseOnlyExcludes='db'
      Invoke-Expression $selector.Value
      $excludedServices | Should Be $(if($enabled){'auth'}else{'db'})
      $RunAuthLifecycle | Should Be $false
    }
    $dispatch=$runnerText.IndexOf("'Test-ChildDirectoryHttp.ps1'")
    $dispatch | Should BeGreaterThan ($runnerText.IndexOf('test db --local'))
    $runnerText | Should Match 'if \(\$RunChildDirectoryHttp\) \{\s+& \(Join-Path'
    $runnerText | Should Not Match '\$RunAuthLifecycle\s*=\s*\$true'
  }
}
