$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-A01AuditGreenTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed A01DirectoryAuditGreen replay selector' {
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
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\A01DirectoryAuditGreen\profile.json'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'A01 Audit Green fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "a01_audit_fixture"')
    $nominalNames = @(
      '20260831192831_activities_v2_actor_attribution.sql',
      '20260831195118_activities_v2_actor_provenance_hardening.sql',
      '20260831195944_activities_v2_actor_provenance_semantics.sql',
      '20260831203645_activities_v2_permissions_receipts.sql',
      '20260831211945_activities_v2_internal_gateways.sql',
      '20260831231645_activities_v2_rls_grants.sql',
      '20260831234307_activities_v2_final_review_hardening.sql',
      '20260907222911_superadmin_activity_directory_v2_client_contract.sql'
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

  It 'selects the A01 base54 plus only the nominal v2 corrective with identical bytes' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen
    $baselineNames.Count | Should Be 45
    $expectedNames = @($baselineNames) + @($nominalNames) + @($preflightNames)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 55
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    foreach ($file in $actual) {
      $root = if ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-A01AuditGreenTestHash $file.FullName -Raw) | Should Be (Get-A01AuditGreenTestHash (Join-Path $root $file.Name) -Raw)
      (Get-A01AuditGreenTestHash $file.FullName) | Should Be (Get-A01AuditGreenTestHash (Join-Path $root $file.Name))
    }
    # Preserve the seven Activities positions and append only v2 after the final Auth MVP migration.
    ($baselineNames -contains $nominalNames[-1]) | Should Be $false
    @($actual | Where-Object Name -eq $nominalNames[-1]).Count | Should Be 1
    @($actual.Name | ForEach-Object { $_.Substring(0, 14) } | Sort-Object -Unique).Count | Should Be 55
    $actualCanonical = @($actual | Where-Object { $_.Name -notin $preflightNames })
    $actualCanonical.Count | Should Be 53
    for ($additionIndex = 0; $additionIndex -lt $nominalNames.Count; $additionIndex++) {
      ([Array]::IndexOf(@($actualCanonical.Name), $nominalNames[$additionIndex]) + 1) | Should Be (@(44, 45, 46, 47, 48, 49, 50, 53)[$additionIndex])
    }
    ($actual.Name -contains '20260907222911_superadmin_activity_directory_v2_client_contract.sql') | Should Be $true
    (Get-A01AuditGreenTestHash (Join-Path $destination $nominalNames[-1])) |
      Should Be 'e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f'
    $actualCanonical[51].Name.Substring(0, 14) | Should Be '20260901200206'
    $actual[-1].Name.Substring(0, 14) | Should Be '20260907222911'
    $output | Should Match 'profile=A01DirectoryAuditGreen; additional=8'
  }

  It 'accepts the sole nominal target and reaches only the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01 Audit Green fixture stop before mutex or Docker'
  }

  It 'rejects an earlier target before the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen requires target 20260907222911'
  }

  It 'rejects a non-allowlisted profile' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile GreenA01AuditGreen } |
      Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile GreenA01AuditGreen } |
      Should Throw 'ValidateSet'
  }

  It 'rejects CLI profile mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'A01DirectoryAuditGreen' }
    $parameters[$mode] = if ($mode -eq 'AdditionalMigration') { 'historical.sql|' + ('0' * 64) } else { $true }
    { & $prepareScript -DestinationMigrationsRoot $destination @parameters } |
      Should Throw 'nominal replay cannot be combined'
    { & $invokeScript -TargetVersion 20260907222911 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects incompatible runner mode: <mode>' -TestCases @(
    @{ mode = 'RunAuthLifecycle' }, @{ mode = 'RunActivityV2Concurrency' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'A01DirectoryAuditGreen' }
    $parameters[$mode] = $true
    { & $invokeScript -TargetVersion 20260907222911 @parameters } |
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
      target { $descriptor.target_version = '20260901200206' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      baseprofile { $descriptor.base.profile = 'foundation' }
      count { $descriptor.planned_counts.canonical = 52 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.canonical_additions[0].file = '..\escape.sql' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen descriptor hash mismatch'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a changed foundation manifest before either entry point can proceed' {
    [IO.File]::AppendAllText($manifestPath, "`n# unreviewed change`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen base manifest hash mismatch'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen base manifest hash mismatch'
  }

  It 'rejects changed SQL bytes for <inputKind> before copying or the Invoke sentinel' -TestCases @(
    @{ inputKind = 'baseline' }, @{ inputKind = 'addition' }, @{ inputKind = 'corrective' }, @{ inputKind = 'preflight' }
  ) {
    param($inputKind)
    $path = switch ($inputKind) {
      baseline { Join-Path $fixtureMigrationRoot $baselineNames[0] }
      addition { Join-Path $fixtureMigrationRoot $nominalNames[0] }
      corrective { Join-Path $fixtureMigrationRoot $nominalNames[-1] }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
    }
    [IO.File]::AppendAllText($path, "`n-- changed fixture`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input hash mismatch'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a missing canonical addition' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $nominalNames[0])
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input is missing'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input is missing'
  }

  It 'rejects omission of the sole v2 corrective before copying or the Invoke sentinel' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $nominalNames[-1])
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input is missing'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'target version must identify exactly one canonical migration'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a resolver <kind> reparse point in <entrypoint> before executing it' -TestCases @(
    @{ kind = 'file'; entrypoint = 'Prepare' }, @{ kind = 'ancestor'; entrypoint = 'Prepare' },
    @{ kind = 'file'; entrypoint = 'Invoke' }, @{ kind = 'ancestor'; entrypoint = 'Invoke' }
  ) {
    param($kind, $entrypoint)
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\A01DirectoryAuditGreen\Resolve-A01DirectoryAuditGreen.ps1'
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
      { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
        Should Throw 'reparse point'
      @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
    } else {
      { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
        Should Throw 'reparse point'
    }
  }
  It 'rejects the preserved v1 input before copying or the Invoke sentinel' {
    $historicalV1 = Join-Path $sourcePackageRoot 'scripts\tests\fixtures\A01DirectoryAuditRedV1\20260907222911_superadmin_activity_directory_v2_client_contract.sql'
    (Get-A01AuditGreenTestHash $historicalV1) |
      Should Be '77b248f6d60661ebf1fff941107b8fd148d9e2a19e9c27d1b4f45be01571847f'
    Copy-Item -LiteralPath $historicalV1 -Destination (Join-Path $fixtureMigrationRoot $nominalNames[-1]) -Force
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input hash mismatch'
    { & $invokeScript -TargetVersion 20260907222911 -NominalProfile A01DirectoryAuditGreen } |
      Should Throw 'A01DirectoryAuditGreen input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

}
