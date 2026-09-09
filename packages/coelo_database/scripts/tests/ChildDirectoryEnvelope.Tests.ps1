param()

$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Describe 'Closed ChildDirectoryEnvelope replay selector' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $fixturePackageRoot = Join-Path $fixtureRoot 'repository\packages\coelo_database'
    $fixtureMigrationRoot = Join-Path $fixturePackageRoot 'migrations'
    $fixtureReplayRoot = Join-Path $fixturePackageRoot 'replay'
    $fixtureScriptRoot = Join-Path $fixturePackageRoot 'scripts'
    $fixtureNotesRoot = Join-Path $fixtureRoot 'repository\docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes'
    $destination = Join-Path $fixtureRoot 'prepared'
    foreach ($path in @($fixtureMigrationRoot, $fixtureReplayRoot, $fixtureScriptRoot, $fixtureNotesRoot, $destination)) {
      New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
      Copy-Item -Destination $fixtureMigrationRoot
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') |
      Copy-Item -Destination $fixtureReplayRoot -Recurse
    foreach ($name in @('Prepare-SafeMigrationReplay.ps1', 'Invoke-SafeLocalMigrationReplay.ps1')) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination $fixtureScriptRoot
    }
    Copy-Item -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $sourcePackageRoot)) 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-envelope-prerequisite.sql') -Destination $fixtureNotesRoot

    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\ChildDirectoryEnvelope\Resolve-ChildDirectoryEnvelope.ps1'
    $prepareScript = Join-Path $fixtureScriptRoot 'Prepare-SafeMigrationReplay.ps1'
    $invokeScript = Join-Path $fixtureScriptRoot 'Invoke-SafeLocalMigrationReplay.ps1'
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\ChildDirectoryEnvelope\profile.json'
    $bridgeName = '20260908051499_child_directory_error_envelope_bridge.sql'
    $bridgePath = Join-Path $fixtureReplayRoot "profiles\ChildDirectoryEnvelope\$bridgeName"
    $childName = '20260908051500_superadmin_child_context_directory_v2.sql'
    $childPath = Join-Path $fixtureMigrationRoot $childName
    $sourcePath = Join-Path $fixtureMigrationRoot '20260827235500_superadmin_internal_institution_list_filter.sql'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "child_envelope_fixture"')
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor,
      "throw 'Child envelope fixture stop before mutex or Docker'`n" + $sentinelAnchor
    ))
  }

  It 'selects Auth45, CHILD1, one local bridge and two inherited preflights' {
    $profile = & $resolverPath -TargetVersion '20260908051500'
    @($profile.Canonical).Count | Should Be 46
    @($profile.Preflight).Count | Should Be 2
    @($profile.Additional).Count | Should Be 1
    @($profile.LocalBridges).Count | Should Be 1
    @($profile.Canonical | Where-Object Name -ceq $childName).Count | Should Be 1
    $profile.LocalBridges[0].Name | Should Be $bridgeName
    $combined = @($profile.Canonical) + @($profile.LocalBridges) + @($profile.Preflight)
    $combined.Count | Should Be 49
    @($combined.Name | Sort-Object -Unique).Count | Should Be 49
    @($combined.Name | Sort-Object)[-1] | Should Be $childName
    [Array]::IndexOf(@($combined.Name | Sort-Object), $bridgeName) |
      Should BeLessThan ([Array]::IndexOf(@($combined.Name | Sort-Object), $childName))

    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile ChildDirectoryEnvelope
    $prepared = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $prepared.Count | Should Be 49
    @($prepared | Where-Object Name -ceq $bridgeName).Count | Should Be 1
    [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $destination $bridgeName))) |
      Should Be ([Convert]::ToBase64String([IO.File]::ReadAllBytes($bridgePath)))
    $output | Should Match '49 safe replay migrations .*46 canonical .*2 preflight'
    $output | Should Match 'profile=ChildDirectoryEnvelope; additional=1'
    { & $invokeScript -TargetVersion '20260908051500' -NominalProfile ChildDirectoryEnvelope } |
      Should Throw 'Child envelope fixture stop before mutex or Docker'
  }

  It 'rejects an earlier target' {
    { & $resolverPath -TargetVersion '20260901200206' } |
      Should Throw 'ChildDirectoryEnvelope requires target 20260908051500'
  }

  It 'rejects changed bytes for <inputKind>' -TestCases @(
    @{ inputKind = 'descriptor' }, @{ inputKind = 'manifest' }, @{ inputKind = 'child' },
    @{ inputKind = 'bridge' }, @{ inputKind = 'approvedSource' }, @{ inputKind = 'sourceNote' }
  ) {
    param($inputKind)
    $path = switch ($inputKind) {
      descriptor { $descriptorPath }
      manifest { $manifestPath }
      child { $childPath }
      bridge { $bridgePath }
      approvedSource { $sourcePath }
      sourceNote { Join-Path $fixtureNotesRoot 'child-envelope-prerequisite.sql' }
    }
    [IO.File]::AppendAllText($path, "`n-- changed fixture`n")
    { & $resolverPath -TargetVersion '20260908051500' } | Should Throw 'mismatch'
  }

  It 'rejects a canonical migration with the local bridge version' {
    [IO.File]::WriteAllText(
      (Join-Path $fixtureMigrationRoot '20260908051499_conflict.sql'),
      '-- conflicting canonical migration'
    )
    { & $resolverPath -TargetVersion '20260908051500' } |
      Should Throw 'local bridge version conflicts with a canonical migration'
  }

  It 'rejects a reparse point in the profile path' {
    $profileRoot = Split-Path -Parent $resolverPath
    $realProfileRoot = Join-Path $fixtureReplayRoot 'child-envelope-profile-target'
    Move-Item -LiteralPath $profileRoot -Destination $realProfileRoot
    New-Item -ItemType Junction -Path $profileRoot -Target $realProfileRoot | Out-Null
    { & $resolverPath -TargetVersion '20260908051500' } | Should Throw 'reparse point'
  }
}
