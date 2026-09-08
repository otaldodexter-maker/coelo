$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-AgendaReadTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed AgendaReadContractRed replay selector' -Tag 'AgendaReadEntrypoints' {
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
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\AgendaReadContractRed\profile.json'
    $resolverScript = Join-Path $fixtureReplayRoot 'profiles\AgendaReadContractRed\Resolve-AgendaReadContractRed.ps1'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'AgendaRead fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "agenda_read_fixture"')
    $nominalNames = @(
      '20260831195944_activities_v2_actor_provenance_semantics.sql',
      '20260831203645_activities_v2_permissions_receipts.sql',
      '20260831211945_activities_v2_internal_gateways.sql',
      '20260901183836_superadmin_agenda_production.sql',
      '20260901184240_agenda_fk_index_hardening.sql',
      '20260901193717_superadmin_agenda_contexts.sql'
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

  It 'selects Auth45 plus exactly six historical files and two preflights with identical bytes' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed
    $baselineNames.Count | Should Be 45
    $expectedNames = @($baselineNames) + @($nominalNames) + @($preflightNames)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 53
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    foreach ($file in $actual) {
      $root = if ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-AgendaReadTestHash $file.FullName -Raw) | Should Be (Get-AgendaReadTestHash (Join-Path $root $file.Name) -Raw)
      (Get-AgendaReadTestHash $file.FullName) | Should Be (Get-AgendaReadTestHash (Join-Path $root $file.Name))
    }
    # These six historical prerequisites must appear once at the approved canonical positions.
    ($baselineNames -contains $nominalNames[-1]) | Should Be $false
    @($actual | Where-Object Name -eq $nominalNames[-1]).Count | Should Be 1
    @($actual.Name | ForEach-Object { $_.Substring(0, 14) } | Sort-Object -Unique).Count | Should Be 53
    $actualCanonical = @($actual | Where-Object { $_.Name -notin $preflightNames })
    $actualCanonical.Count | Should Be 51
    for ($additionIndex = 0; $additionIndex -lt $nominalNames.Count; $additionIndex++) {
      ([Array]::IndexOf(@($actualCanonical.Name), $nominalNames[$additionIndex]) + 1) | Should Be (@(44, 45, 46, 48, 49, 50)[$additionIndex])
    }
    $actual[-1].Name.Substring(0, 14) | Should Be '20260901200206'
    $output | Should Match 'profile=AgendaReadContractRed; additional=6'
  }

  It 'accepts the sole nominal target and reaches only the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaRead fixture stop before mutex or Docker'
  }

  It 'rejects an earlier target before the fixture sentinel' {
    { & $invokeScript -TargetVersion 20260831195944 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed requires target 20260901200206'
  }

  It 'rejects a non-allowlisted profile' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile GreenAgendaRead } |
      Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile GreenAgendaRead } |
      Should Throw 'ValidateSet'
  }

  It 'rejects CLI profile mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'AgendaReadContractRed' }
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
    $parameters = @{ NominalProfile = 'AgendaReadContractRed' }
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
      name { $descriptor.canonical_additions[0].file = '20260831195944_wrong.sql' }
      hash { $descriptor.canonical_additions[0].sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260831195944' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      baseprofile { $descriptor.base.profile = 'foundation' }
      count { $descriptor.planned_counts.canonical = 52 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.canonical_additions[0].file = '..\escape.sql' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed descriptor hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a changed foundation manifest before either entry point can proceed' {
    [IO.File]::AppendAllText($manifestPath, "`n# unreviewed change`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed base manifest hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed base manifest hash mismatch'
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
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed input hash mismatch'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a missing canonical addition' {
    Remove-Item -LiteralPath (Join-Path $fixtureMigrationRoot $nominalNames[0])
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed input is missing'
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
      Should Throw 'AgendaReadContractRed input is missing'
  }

  It 'rejects a resolver <kind> reparse point in <entrypoint> before executing it' -TestCases @(
    @{ kind = 'file'; entrypoint = 'Prepare' }, @{ kind = 'ancestor'; entrypoint = 'Prepare' },
    @{ kind = 'file'; entrypoint = 'Invoke' }, @{ kind = 'ancestor'; entrypoint = 'Invoke' }
  ) {
    param($kind, $entrypoint)
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\AgendaReadContractRed\Resolve-AgendaReadContractRed.ps1'
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
      { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile AgendaReadContractRed } |
        Should Throw 'reparse point'
      @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
    } else {
      { & $invokeScript -TargetVersion 20260901200206 -NominalProfile AgendaReadContractRed } |
        Should Throw 'reparse point'
    }
  }
}

Describe 'Closed AgendaReadContractRed resolver' -Tag 'AgendaReadResolver' {
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
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\AgendaReadContractRed\profile.json'
    $resolverScript = Join-Path $fixtureReplayRoot 'profiles\AgendaReadContractRed\Resolve-AgendaReadContractRed.ps1'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    # Only this TestDrive copy can run. Stop before mutex, staging or any Docker
    # inspection even when valid arguments/config pass all preceding guards.
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'AgendaRead fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "agenda_read_fixture"')
    $nominalNames = @(
      '20260831195944_activities_v2_actor_provenance_semantics.sql',
      '20260831203645_activities_v2_permissions_receipts.sql',
      '20260831211945_activities_v2_internal_gateways.sql',
      '20260901183836_superadmin_agenda_production.sql',
      '20260901184240_agenda_fk_index_hardening.sql',
      '20260901193717_superadmin_agenda_contexts.sql'
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

  It 'returns Auth45 plus six pinned additions and both anchored preflights without copying or executing SQL' {
    $result = & $resolverScript
    $result.Canonical.Count | Should Be 51
    $result.Preflight.Count | Should Be 2
    $result.Additional.Count | Should Be 6
    $result.ManifestHash | Should Be '4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59'
    $expectedNames = @($baselineNames) + @($nominalNames)
    @(Compare-Object ($expectedNames | Sort-Object) @($result.Canonical.Name)).Count | Should Be 0
    ($result.Additional.Name -join '|') | Should Be ($nominalNames -join '|')
    for ($index = 0; $index -lt 6; $index++) {
      ([Array]::IndexOf(@($result.Canonical.Name), $nominalNames[$index]) + 1) |
        Should Be (@(44, 45, 46, 48, 49, 50)[$index])
    }
    $all = @(@($result.Canonical) + @($result.Preflight) | Sort-Object Name)
    $all.Count | Should Be 53
    @($all.Name | ForEach-Object { $_.Substring(0, 14) } | Sort-Object -Unique).Count | Should Be 53
    $all[-1].Name | Should Be '20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql'
    $all[28].Name | Should Be $preflightNames[0]
    $all[29].Name | Should Be '20260811151254_group_management_security.sql'
    $all[40].Name | Should Be '20260811215451_access_profile_management_v2.sql'
    $all[41].Name | Should Be $preflightNames[1]
    $all[42].Name | Should Be '20260812000847_audit_production.sql'
    $descriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
    @($descriptor.extra_bridges).Count | Should Be 0
    foreach ($entry in @($descriptor.canonical_additions) + @($descriptor.inherited_preflights)) {
      $root = if ($entry.file -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-AgendaReadTestHash (Join-Path $root $entry.file)) | Should Be $entry.sha256_crlf_utf8
    }
    foreach ($entry in $baselineEntries) {
      (Get-AgendaReadTestHash (Join-Path $fixtureMigrationRoot $entry.Split('|')[0])) | Should Be $entry.Split('|')[1]
    }
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a non-nominal target without reading application SQL' {
    { & $resolverScript -TargetVersion 20260831195944 } |
      Should Throw 'AgendaReadContractRed requires target 20260901200206'
  }

  It 'rejects descriptor drift in <field>' -TestCases @(
    @{ field = 'bridge' }, @{ field = 'name' }, @{ field = 'hash' }, @{ field = 'target' },
    @{ field = 'basehash' }, @{ field = 'count' }, @{ field = 'position' },
    @{ field = 'duplicate' }, @{ field = 'pathescape' }
  ) {
    param($field)
    $descriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
    switch ($field) {
      bridge { $descriptor.extra_bridges = @('unapproved.sql') }
      name { $descriptor.canonical_additions[0].file = '20260831195944_wrong.sql' }
      hash { $descriptor.canonical_additions[0].sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260831195944' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      count { $descriptor.planned_counts.canonical = 52 }
      position { $descriptor.canonical_additions[0].canonical_union_position = 45 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.canonical_additions[0].file = '..\escape.sql' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $resolverScript } | Should Throw 'AgendaReadContractRed descriptor hash mismatch'
  }

  It 'rejects a changed base manifest' {
    [IO.File]::AppendAllText($manifestPath, [Environment]::NewLine + '# changed fixture')
    { & $resolverScript } | Should Throw 'AgendaReadContractRed base manifest hash mismatch'
  }

  It 'rejects changed bytes of <inputKind>' -TestCases @(
    @{ inputKind = 'baseline' }, @{ inputKind = 'addition' }, @{ inputKind = 'preflight' }
  ) {
    param($inputKind)
    $path = switch ($inputKind) {
      baseline { Join-Path $fixtureMigrationRoot $baselineNames[0] }
      addition { Join-Path $fixtureMigrationRoot $nominalNames[0] }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
    }
    [IO.File]::AppendAllText($path, [Environment]::NewLine + '-- changed fixture')
    { & $resolverScript } | Should Throw 'AgendaReadContractRed input hash mismatch'
  }

  It 'rejects omission of approved addition <index>' -TestCases @(
    @{ index = 0 }, @{ index = 1 }, @{ index = 2 }, @{ index = 3 }, @{ index = 4 }, @{ index = 5 }
  ) {
    param($index)
    [IO.File]::Delete((Join-Path $fixtureMigrationRoot $nominalNames[$index]))
    { & $resolverScript } | Should Throw 'AgendaReadContractRed input is missing'
  }

  It 'rejects a <dependency> <kind> reparse point before reading the file' -TestCases @(
    @{ dependency = 'descriptor'; kind = 'file' }, @{ dependency = 'descriptor'; kind = 'ancestor' },
    @{ dependency = 'manifest'; kind = 'file' }, @{ dependency = 'manifest'; kind = 'ancestor' },
    @{ dependency = 'canonical'; kind = 'file' }, @{ dependency = 'canonical'; kind = 'ancestor' },
    @{ dependency = 'preflight'; kind = 'file' }, @{ dependency = 'preflight'; kind = 'ancestor' }
  ) {
    param($dependency, $kind)
    $guardedPath = switch ($dependency) {
      descriptor { $descriptorPath }
      manifest { $manifestPath }
      canonical { Join-Path $fixtureMigrationRoot $nominalNames[0] }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
    }
    $directoryMetadata = [pscustomobject]@{
      FullName = Split-Path -Parent $guardedPath
      PSIsContainer = $true
      Parent = $null
      Attributes = if ($kind -eq 'ancestor') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Directory }
    }
    Mock Get-Item {
      [pscustomobject]@{
        FullName = $guardedPath
        PSIsContainer = $false
        Directory = $directoryMetadata
        Attributes = if ($kind -eq 'file') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Normal }
      }
    } -ParameterFilter { $LiteralPath -eq $guardedPath }
    { & $resolverScript } | Should Throw 'reparse point'
  }

  It 'rejects an extra replay SQL instead of implicitly accepting a third preflight' {
    [IO.File]::WriteAllText((Join-Path $fixtureReplayRoot '20260812000001_unapproved.sql'), '-- fixture only')
    { & $resolverScript } |
      Should Throw 'AgendaReadContractRed requires 51 unique canonical migrations and exactly two inherited preflights'
  }
}
