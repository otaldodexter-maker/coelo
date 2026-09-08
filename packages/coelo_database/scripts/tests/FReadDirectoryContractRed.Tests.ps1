$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-FReadTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed FReadDirectoryContractRed replay selector' {
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
    $prepareScript = Join-Path $fixtureScriptRoot 'Prepare-SafeMigrationReplay.ps1'
    $invokeScript = Join-Path $fixtureScriptRoot 'Invoke-SafeLocalMigrationReplay.ps1'
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\FReadDirectoryContractRed\profile.json'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'FRead fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "fread_fixture"')
    $nominalNames = @(
      '20260813155005_forms_definition_and_capabilities.sql',
      '20260813155116_forms_distribution_and_occurrences.sql',
      '20260827235500_superadmin_internal_institution_list_filter.sql'
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

  It 'selects Auth45 plus exactly three historical files and two preflights with identical bytes' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed
    $baselineNames.Count | Should Be 45
    $expectedNames = @($baselineNames) + @($nominalNames) + @($preflightNames)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 50
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    foreach ($file in $actual) {
      $root = if ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-FReadTestHash $file.FullName -Raw) | Should Be (Get-FReadTestHash (Join-Path $root $file.Name) -Raw)
      (Get-FReadTestHash $file.FullName) | Should Be (Get-FReadTestHash (Join-Path $root $file.Name))
    }
    # These three historical prerequisites must appear once at the approved canonical positions.
    ($baselineNames -contains $nominalNames[-1]) | Should Be $false
    @($actual | Where-Object Name -eq $nominalNames[-1]).Count | Should Be 1
    @($actual.Name | ForEach-Object { $_.Substring(0, 14) } | Sort-Object -Unique).Count | Should Be 50
    $actualCanonical = @($actual | Where-Object { $_.Name -notin $preflightNames })
    $actualCanonical.Count | Should Be 48
    for ($additionIndex = 0; $additionIndex -lt $nominalNames.Count; $additionIndex++) {
      ([Array]::IndexOf(@($actualCanonical.Name), $nominalNames[$additionIndex]) + 1) | Should Be (@(42, 43, 46)[$additionIndex])
    }
    $actual[-1].Name.Substring(0, 14) | Should Be '20260901200206'
    $output | Should Match 'profile=FReadDirectoryContractRed; additional=3'
  }

  It 'accepts the sole nominal target and reaches only the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FRead fixture stop before mutex or Docker'
  }

  It 'rejects an earlier target before the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260827235500 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed requires target 20260901200206'
  }

  It 'rejects a non-allowlisted profile' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile GreenFRead } |
      Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile GreenFRead } |
      Should Throw 'ValidateSet'
  }

  It 'rejects CLI profile mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'FReadDirectoryContractRed' }
    $parameters[$mode] = if ($mode -eq 'AdditionalMigration') { 'historical.sql|' + ('0' * 64) } else { $true }
    { & $prepareScript -DestinationMigrationsRoot $destination @parameters } |
      Should Throw 'nominal replay cannot be combined'
    { & $invokeScript -TargetVersion 20260901200206 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects incompatible runner mode: <mode>' -TestCases @(
    @{ mode = 'RunAuthLifecycle' }, @{ mode = 'RunActivityV2Concurrency' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'FReadDirectoryContractRed' }
    $parameters[$mode] = $true
    { & $invokeScript -TargetVersion 20260901200206 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects descriptor mutation <field> before copying or the Invoke sentinel' -TestCases @(
    @{ field = 'bridge' }, @{ field = 'name' }, @{ field = 'hash' }, @{ field = 'target' },
    @{ field = 'basehash' }, @{ field = 'baseprofile' }, @{ field = 'count' },
    @{ field = 'duplicate' }, @{ field = 'pathescape' }
  ) {
    param($field)
    $descriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
    switch ($field) {
      bridge { $descriptor.extra_bridges = @('unapproved.sql') }
      name { $descriptor.canonical_additions[0].file = '20260813155005_wrong.sql' }
      hash { $descriptor.canonical_additions[0].sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260827235500' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      baseprofile { $descriptor.base.profile = 'foundation' }
      count { $descriptor.planned_counts.canonical = 49 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.canonical_additions[0].file = '..\escape.sql' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed descriptor hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a changed foundation manifest before either entry point can proceed' {
    [IO.File]::AppendAllText($manifestPath, "`n# unreviewed change`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed base manifest hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed base manifest hash mismatch'
  }

  It 'rejects changed SQL bytes for <inputKind> before copying or the Invoke sentinel' -TestCases @(
    @{ inputKind = 'baseline' }, @{ inputKind = 'addition' }, @{ inputKind = 'preflight' }
  ) {
    param($inputKind)
    $path = switch ($inputKind) {
      baseline { Join-Path $fixtureMigrationRoot $baselineNames[0] }
      addition { Join-Path $fixtureMigrationRoot $nominalNames[0] }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
    }
    [IO.File]::AppendAllText($path, "`n-- changed fixture`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed input hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a missing canonical addition' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $nominalNames[0])
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed input is missing'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
      Should Throw 'FReadDirectoryContractRed input is missing'
  }

  It 'rejects a resolver <kind> reparse point in <entrypoint> before executing it' -TestCases @(
    @{ kind = 'file'; entrypoint = 'Prepare' }, @{ kind = 'ancestor'; entrypoint = 'Prepare' },
    @{ kind = 'file'; entrypoint = 'Invoke' }, @{ kind = 'ancestor'; entrypoint = 'Invoke' }
  ) {
    param($kind, $entrypoint)
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\FReadDirectoryContractRed\Resolve-FReadDirectoryContractRed.ps1'
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
      { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile FReadDirectoryContractRed } |
        Should Throw 'reparse point'
      @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
    } else {
      { & $invokeScript -TargetVersion 20260901200206 -NominalProfile FReadDirectoryContractRed } |
        Should Throw 'reparse point'
    }
  }
}
