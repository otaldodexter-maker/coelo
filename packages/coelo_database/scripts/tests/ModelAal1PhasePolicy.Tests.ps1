param([string]$CandidateMigrationPath)

$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if (-not $CandidateMigrationPath) {
  $CandidateMigrationPath = Join-Path $sourcePackageRoot 'migrations/20260908182839_access_profile_models_aal1_phase_policy.sql'
}
if (-not (Test-Path -LiteralPath $CandidateMigrationPath -PathType Leaf)) {
  throw 'Provide CandidateMigrationPath for the reviewed, not yet integrated candidate; no SQL is fabricated by this test'
}

function Get-ModelGreenTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed ModelAal1PhasePolicy replay selector' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $fixturePackageRoot = Join-Path $fixtureRoot 'repository\packages\coelo_database'
    $fixtureMigrationRoot = Join-Path $fixturePackageRoot 'migrations'
    $fixtureReplayRoot = Join-Path $fixturePackageRoot 'replay'
    $fixtureScriptRoot = Join-Path $fixturePackageRoot 'scripts'
    $destination = Join-Path $fixtureRoot 'prepared'
    foreach ($path in @($fixtureMigrationRoot, $fixtureReplayRoot, $fixtureScriptRoot, $destination)) {
      New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
      Copy-Item -Destination $fixtureMigrationRoot
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') |
      Copy-Item -Destination $fixtureReplayRoot -Recurse
    foreach ($name in @('Prepare-SafeMigrationReplay.ps1', 'Invoke-SafeLocalMigrationReplay.ps1')) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination $fixtureScriptRoot
    }
    $candidateName = '20260908182839_access_profile_models_aal1_phase_policy.sql'
    Copy-Item -LiteralPath $CandidateMigrationPath -Destination (Join-Path $fixtureMigrationRoot $candidateName) -Force
    $prepareScript = Join-Path $fixtureScriptRoot 'Prepare-SafeMigrationReplay.ps1'
    $invokeScript = Join-Path $fixtureScriptRoot 'Invoke-SafeLocalMigrationReplay.ps1'
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\ModelReadAuthorizationGreen\profile.json'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'Model AAL1 fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "model_green_fixture"')
    $nominalNames = @(
      '20260901170731_access_profile_models_crud_and_catalog.sql',
      '20260901193000_name_access_profile_model_rpc_arguments.sql',
      '20260908021821_access_profile_models_read_prelookup_authorization.sql'
    )
    $baselineEntries = @(Get-Content -LiteralPath $manifestPath | Where-Object {
      $_.Trim() -and -not $_.TrimStart().StartsWith('#')
    } | Where-Object {
      $version = $_.Substring(0, 14)
      $version -le '20260812001975' -or $version -in @(
        '20260827214000', '20260827233000', '20260901124500', '20260901200206')
    })
    $baselineNames = @($baselineEntries | ForEach-Object { $_.Split('|')[0] })
    $preflightNames = @(
      '20260811151253_assert_function_execute_preflight.sql',
      '20260811215452_access_profile_labels_replay_bridge.sql')
  }

  It 'selects exactly the inherited 50 plus the nominal candidate with identical bytes' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelAal1PhasePolicy
    $expectedNames = @($baselineNames) + @($nominalNames) + @($preflightNames) + @($candidateName)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 51
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    foreach ($file in $actual) {
      $root = if ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-ModelGreenTestHash $file.FullName -Raw) | Should Be (Get-ModelGreenTestHash (Join-Path $root $file.Name) -Raw)
    }
    $actual[-1].Name | Should Be $candidateName
    $output | Should Match '51 safe replay migrations .*49 canonical .*2 preflight'
    $output | Should Match 'profile=ModelAal1PhasePolicy; additional=4'
  }

  It 'preserves the inherited profile at exactly 50 even with the AAL1 candidate present' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelReadAuthorizationGreen
    @(Get-ChildItem -LiteralPath $destination -File).Count | Should Be 50
    Test-Path -LiteralPath (Join-Path $destination $candidateName) | Should Be $false
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelReadAuthorizationGreen } |
      Should Throw 'ModelReadAuthorizationGreen requires target 20260908021821'
  }

  It 'accepts the sole target and reaches only the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'Model AAL1 fixture stop before mutex or Docker'
  }

  It 'rejects the earlier target before mutex or Docker' {
    { & $invokeScript -TargetVersion 20260908021821 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'ModelAal1PhasePolicy requires target 20260908182839'
  }

  It 'rejects changed SQL bytes for <inputKind> before copying or the Invoke sentinel' -TestCases @(
    @{ inputKind = 'baseline' }, @{ inputKind = 'addition' }, @{ inputKind = 'corrective' },
    @{ inputKind = 'preflight' }, @{ inputKind = 'aal1' }
  ) {
    param($inputKind)
    $path = switch ($inputKind) {
      baseline { Join-Path $fixtureMigrationRoot $baselineNames[0] }
      addition { Join-Path $fixtureMigrationRoot $nominalNames[0] }
      corrective { Join-Path $fixtureMigrationRoot $nominalNames[-1] }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
      aal1 { Join-Path $fixtureMigrationRoot $candidateName }
    }
    [IO.File]::AppendAllText($path, "`n-- changed fixture`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'input hash mismatch'
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects candidate omission before copying or the Invoke sentinel' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $candidateName)
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'ModelAal1PhasePolicy input is missing'
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'target version must identify exactly one canonical migration'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects duplicate target filenames before the Invoke sentinel' {
    Copy-Item -LiteralPath (Join-Path $fixtureMigrationRoot $candidateName) -Destination (Join-Path $fixtureMigrationRoot '20260908182839_duplicate.sql')
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'target version must identify exactly one canonical migration'
  }
  It 'rejects a non-allowlisted profile' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile UnapprovedModelGreen } |
      Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile UnapprovedModelGreen } |
      Should Throw 'ValidateSet'
  }

  It 'rejects CLI profile mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'ModelAal1PhasePolicy' }
    $parameters[$mode] = if ($mode -eq 'AdditionalMigration') { 'historical.sql|' + ('0' * 64) } else { $true }
    { & $prepareScript -DestinationMigrationsRoot $destination @parameters } |
      Should Throw 'nominal replay cannot be combined'
    { & $invokeScript -TargetVersion 20260908182839 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects incompatible runner mode: <mode>' -TestCases @(
    @{ mode = 'RunAuthLifecycle' }, @{ mode = 'RunActivityV2Concurrency' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'ModelAal1PhasePolicy' }
    $parameters[$mode] = $true
    { & $invokeScript -TargetVersion 20260908182839 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects a changed foundation manifest before either entry point can proceed' {
    [IO.File]::AppendAllText($manifestPath, "`n# unreviewed change`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'ModelReadAuthorizationGreen base manifest hash mismatch'
    { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
      Should Throw 'ModelReadAuthorizationGreen base manifest hash mismatch'
  }

  It 'rejects <inputPath> <kind> reparse point in <entrypoint> before executing it' -TestCases @(@('own', 'base', 'candidate') | ForEach-Object { $inputPath = $_; foreach ($kind in @('file', 'ancestor')) { foreach ($entrypoint in @('Prepare', 'Invoke')) { @{kind=$kind; entrypoint=$entrypoint; inputPath=$inputPath} } } }
  ) {
    param($kind, $entrypoint, $inputPath)
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\ModelAal1PhasePolicy\Resolve-ModelAal1PhasePolicy.ps1'
    if ($inputPath -eq 'base') { $resolverPath = Join-Path $fixtureReplayRoot 'profiles\ModelReadAuthorizationGreen\Resolve-ModelReadAuthorizationGreen.ps1' }
    if ($inputPath -eq 'candidate') { $resolverPath = Join-Path $fixtureMigrationRoot $candidateName }
    $resolverParent = Split-Path -Parent $resolverPath
    $directoryMetadata = [pscustomobject]@{
      FullName = $resolverParent
      PSIsContainer = $true
      Parent = $null
      Attributes = if ($kind -eq 'ancestor') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Directory }
    }
    Mock Get-Item {
      if ($LiteralPath -eq $resolverPath) {
        [pscustomobject]@{
          FullName = $resolverPath
          PSIsContainer = $false
          Directory = $directoryMetadata
          Attributes = if ($kind -eq 'file') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Normal }
        }
      } else { $directoryMetadata }
    } -ParameterFilter { $LiteralPath -eq $resolverPath -or $LiteralPath -eq $resolverParent }
    if ($entrypoint -eq 'Prepare') {
      { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ModelAal1PhasePolicy } |
        Should Throw 'reparse point'
      @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
    } else {
      { & $invokeScript -TargetVersion 20260908182839 -NominalProfile ModelAal1PhasePolicy } |
        Should Throw 'reparse point'
    }
  }
}
