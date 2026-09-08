$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-A01TestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed A01DirectoryContractRed replay selector' {
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
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\A01DirectoryContractRed\profile.json'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'A01 fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "a01_fixture"')
    $nominalNames = @(
      '20260831192831_activities_v2_actor_attribution.sql',
      '20260831195118_activities_v2_actor_provenance_hardening.sql',
      '20260831195944_activities_v2_actor_provenance_semantics.sql',
      '20260831203645_activities_v2_permissions_receipts.sql',
      '20260831211945_activities_v2_internal_gateways.sql',
      '20260831231645_activities_v2_rls_grants.sql',
      '20260831234307_activities_v2_final_review_hardening.sql'
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

  It 'selects Auth45 plus exactly seven historical files and two preflights with identical bytes' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed
    $baselineNames.Count | Should Be 45
    $expectedNames = @($baselineNames) + @($nominalNames) + @($preflightNames)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 54
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    foreach ($file in $actual) {
      $root = if ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-A01TestHash $file.FullName -Raw) | Should Be (Get-A01TestHash (Join-Path $root $file.Name) -Raw)
      (Get-A01TestHash $file.FullName) | Should Be (Get-A01TestHash (Join-Path $root $file.Name))
    }
    # Activities additions must appear once, after Auth context and before the final Auth hardening.
    ($baselineNames -contains $nominalNames[-1]) | Should Be $false
    @($actual | Where-Object Name -eq $nominalNames[-1]).Count | Should Be 1
    @($actual.Name | ForEach-Object { $_.Substring(0, 14) } | Sort-Object -Unique).Count | Should Be 54
    $actualCanonical = @($actual | Where-Object { $_.Name -notin $preflightNames })
    $actualCanonical.Count | Should Be 52
    for ($additionIndex = 0; $additionIndex -lt $nominalNames.Count; $additionIndex++) {
      ([Array]::IndexOf(@($actualCanonical.Name), $nominalNames[$additionIndex]) + 1) | Should Be (44 + $additionIndex)
    }
    ($actual.Name -contains '20260907222911_superadmin_activity_directory_v2_client_contract.sql') | Should Be $false
    $actual[-1].Name.Substring(0, 14) | Should Be '20260901200206'
    $output | Should Match 'profile=A01DirectoryContractRed; additional=7'
  }

  It 'accepts the sole nominal target and reaches only the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01 fixture stop before mutex or Docker'
  }

  It 'rejects an earlier target before the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260831234307 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed requires target 20260901200206'
  }

  It 'rejects a non-allowlisted profile' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile GreenA01 } |
      Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile GreenA01 } |
      Should Throw 'ValidateSet'
  }

  It 'rejects CLI profile mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'A01DirectoryContractRed' }
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
    $parameters = @{ NominalProfile = 'A01DirectoryContractRed' }
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
      name { $descriptor.canonical_additions[0].file = '20260831192831_wrong.sql' }
      hash { $descriptor.canonical_additions[0].sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260831234307' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      baseprofile { $descriptor.base.profile = 'foundation' }
      count { $descriptor.planned_counts.canonical = 51 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.canonical_additions[0].file = '..\escape.sql' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed descriptor hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a changed foundation manifest before either entry point can proceed' {
    [IO.File]::AppendAllText($manifestPath, "`n# unreviewed change`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed base manifest hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed base manifest hash mismatch'
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
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed input hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a missing canonical addition' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $nominalNames[0])
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed input is missing'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
      Should Throw 'A01DirectoryContractRed input is missing'
  }

  It 'rejects a resolver <kind> reparse point in <entrypoint> before executing it' -TestCases @(
    @{ kind = 'file'; entrypoint = 'Prepare' }, @{ kind = 'ancestor'; entrypoint = 'Prepare' },
    @{ kind = 'file'; entrypoint = 'Invoke' }, @{ kind = 'ancestor'; entrypoint = 'Invoke' }
  ) {
    param($kind, $entrypoint)
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\A01DirectoryContractRed\Resolve-A01DirectoryContractRed.ps1'
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
      { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryContractRed } |
        Should Throw 'reparse point'
      @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
    } else {
      { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryContractRed } |
        Should Throw 'reparse point'
    }
  }
}
