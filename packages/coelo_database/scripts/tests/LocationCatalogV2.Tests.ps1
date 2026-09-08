$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-LocationTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Closed LocationCatalogV2 replay selector' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $fixturePackageRoot = Join-Path $fixtureRoot 'repository\packages\coelo_database'
    $fixtureMigrationRoot = Join-Path $fixturePackageRoot 'migrations'
    $fixtureReplayRoot = Join-Path $fixturePackageRoot 'replay'
    $fixtureScriptRoot = Join-Path $fixturePackageRoot 'scripts'
    $fixtureBootstrapRoot = Join-Path $fixturePackageRoot 'tests\fixtures'
    $destination = Join-Path $fixtureRoot 'prepared'
    foreach ($path in @($fixtureMigrationRoot, $fixtureReplayRoot, $fixtureScriptRoot, $fixtureBootstrapRoot, $destination)) {
      New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
      Copy-Item -Destination $fixtureMigrationRoot
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') |
      Copy-Item -Destination $fixtureReplayRoot -Recurse
    $sourceName = 'location_catalog_v2_capability_bootstrap.sql'
    $bootstrapName = '20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
    $candidateName = '20260908031000_superadmin_location_catalog_v2.sql'
    $institutionName = '20260827235500_superadmin_internal_institution_list_filter.sql'
    foreach ($name in @($sourceName, $bootstrapName)) {
      Copy-Item -LiteralPath (Join-Path (Join-Path $sourcePackageRoot 'tests\fixtures') $name) -Destination $fixtureBootstrapRoot
    }
    $sourcePath = Join-Path $fixtureBootstrapRoot $sourceName
    $bootstrapPath = Join-Path $fixtureBootstrapRoot $bootstrapName
    foreach ($name in @('Prepare-SafeMigrationReplay.ps1', 'Invoke-SafeLocalMigrationReplay.ps1')) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination $fixtureScriptRoot
    }
    $prepareScript = Join-Path $fixtureScriptRoot 'Prepare-SafeMigrationReplay.ps1'
    $invokeScript = Join-Path $fixtureScriptRoot 'Invoke-SafeLocalMigrationReplay.ps1'
    $resolverPath = Join-Path $fixtureReplayRoot 'profiles\LocationCatalogV2\Resolve-LocationCatalogV2.ps1'
    $descriptorPath = Join-Path $fixtureReplayRoot 'profiles\LocationCatalogV2\profile.json'
    $manifestPath = Join-Path $fixtureReplayRoot 'foundation-migrations.sha256'
    $invokeText = [IO.File]::ReadAllText($invokeScript)
    $sentinelAnchor = '$mutex = [Threading.Mutex]::new'
    $invokeText.Contains($sentinelAnchor) | Should Be $true
    [IO.File]::WriteAllText($invokeScript, $invokeText.Replace(
      $sentinelAnchor, "throw 'Location fixture stop before mutex or Docker'`n" + $sentinelAnchor))
    $configRoot = Join-Path $fixturePackageRoot 'supabase'
    New-Item -ItemType Directory -Path $configRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $configRoot 'config.toml'), 'project_id = "location_fixture"')
    $baselineNames = @(Get-Content -LiteralPath $manifestPath | Where-Object {
      $_.Trim() -and -not $_.TrimStart().StartsWith('#')
    } | Where-Object {
      $version = $_.Substring(0, 14)
      $version -le '20260812001975' -or $version -in @(
        '20260827214000', '20260827233000', '20260901124500', '20260901200206')
    } | ForEach-Object { $_.Split('|')[0] })
    $preflightNames = @(
      '20260811151253_assert_function_execute_preflight.sql',
      '20260811215452_access_profile_labels_replay_bridge.sql')
  }

  It 'resolves exactly Auth45 plus two canonical additions and separate bootstrap at position49' {
    $selection = & $resolverPath
    @($selection).Count | Should Be 1
    @($selection.Canonical).Count | Should Be 47
    @($selection.Preflight).Count | Should Be 2
    @($selection.Additional).Count | Should Be 2
    @($selection.LocationBootstrap).Count | Should Be 1
    $selection.LocationBootstrap.Name | Should Be $bootstrapName
    ($selection.LocationBootstrap -is [IO.FileInfo]) | Should Be $true
    $all = @(@($selection.Canonical) + @($selection.Preflight) + @($selection.LocationBootstrap) | Sort-Object Name)
    $all.Count | Should Be 50
    $all[48].Name | Should Be $bootstrapName
    $all[49].Name | Should Be $candidateName
    @($all.Name | ForEach-Object { $_.Substring(0,14) } | Sort-Object -Unique).Count | Should Be 50
    @($selection.Canonical)[43].Name | Should Be $institutionName
    @($selection.Canonical)[46].Name | Should Be $candidateName
    (Get-LocationTestHash (Join-Path $fixtureMigrationRoot $candidateName)) | Should Be 'f6c6c842114932d96af6b2478df43827241192044cfcae778e7ca3e4132960df'
    $pinnedCandidate = (Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json).canonical_additions[1]
    $pinnedCandidate.sha256_lf_utf8 | Should Be 'ec886dcbfbe88be54fb99f233e01395a8632388b2db94761f4a49b611e93ad2f'
    $pinnedCandidate.commit | Should Be '6b0cbb3009c7184896cfd2aebd6c7a7ca0fafe10'
    $pinnedCandidate.blob | Should Be '8d26581692ff78db923de98d7c788257857fbbdb'
    foreach ($items in @($selection.Canonical, $selection.Preflight, $selection.Additional)) {
      (@($items).Name -contains $bootstrapName) | Should Be $false
      (@($items).Name -contains $sourceName) | Should Be $false
    }
    (Get-LocationTestHash $sourcePath -Raw) | Should Be '3dd0bf5c11e52a68102e3e707e48835eb676513c235daab5defcdb1e7ad24bfb'
    (Get-LocationTestHash $bootstrapPath -Raw) | Should Be 'd46583bc936dfb284b5d05bdba8dea8f965d31a0f899164bfdd8a8c6bd6d2471'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a non-final target in the resolver' {
    { & $resolverPath -TargetVersion 20260901200206 } | Should Throw 'LocationCatalogV2 requires target 20260908031000'
  }

  It 'rejects descriptor drift in <field>' -TestCases @(
    @{field='bridge'}, @{field='name'}, @{field='hash'}, @{field='target'},
    @{field='basehash'}, @{field='baseprofile'}, @{field='count'}, @{field='duplicate'},
    @{field='pathescape'}, @{field='bootstrapname'}, @{field='sourcehash'},
    @{field='derivedhash'}, @{field='position'}, @{field='before'}, @{field='delta'}
  ) {
    param($field)
    $descriptor = Get-Content -LiteralPath $descriptorPath -Raw | ConvertFrom-Json
    switch ($field) {
      bridge { $descriptor.extra_bridges = @('unapproved.sql') }
      name { $descriptor.canonical_additions[0].file = '20260827235500_wrong.sql' }
      hash { $descriptor.canonical_additions[0].sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260901200206' }
      basehash { $descriptor.base.manifest_sha256_crlf_utf8 = '0' * 64 }
      baseprofile { $descriptor.base.profile = 'foundation' }
      count { $descriptor.planned_counts.bootstrap = 0 }
      duplicate { $descriptor.canonical_additions[1] = $descriptor.canonical_additions[0] }
      pathescape { $descriptor.location_bootstrap.source.file = '..\escape.sql' }
      bootstrapname { $descriptor.location_bootstrap.derived.file = '20260908030958_wrong.sql' }
      sourcehash { $descriptor.location_bootstrap.source.sha256_raw = '0' * 64 }
      derivedhash { $descriptor.location_bootstrap.derived.sha256_raw = '0' * 64 }
      position { $descriptor.location_bootstrap.combined_position = 48 }
      before { $descriptor.location_bootstrap.before = $institutionName }
      delta { $descriptor.location_bootstrap.insert_line = 'unapproved' }
    }
    [IO.File]::WriteAllText($descriptorPath, ($descriptor | ConvertTo-Json -Depth 10))
    { & $resolverPath } | Should Throw 'LocationCatalogV2 descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects changed manifest before selection' {
    [IO.File]::AppendAllText($manifestPath, "`n# drift`n")
    { & $resolverPath } | Should Throw 'LocationCatalogV2 base manifest hash mismatch'
  }

  It 'rejects changed input <kind>' -TestCases @(
    @{kind='baseline'}, @{kind='institution'}, @{kind='candidate'}, @{kind='preflight'},
    @{kind='source'}, @{kind='derived'}
  ) {
    param($kind)
    $inputPath = switch ($kind) {
      baseline { Join-Path $fixtureMigrationRoot $baselineNames[0] }
      institution { Join-Path $fixtureMigrationRoot $institutionName }
      candidate { Join-Path $fixtureMigrationRoot $candidateName }
      preflight { Join-Path $fixtureReplayRoot $preflightNames[0] }
      source { $sourcePath }
      derived { $bootstrapPath }
    }
    if ($kind -eq 'candidate') {
      $approvedCase = "is distinct from (case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end) then"
      $previousCase = "is distinct from case when expected.client_execute then array['authenticated:EXECUTE:false'] else '{}'::text[] end then"
      $candidateText = [IO.File]::ReadAllText($inputPath)
      ([regex]::Matches($candidateText, [regex]::Escape($approvedCase))).Count | Should Be 1
      [IO.File]::WriteAllText($inputPath, $candidateText.Replace($approvedCase, $previousCase), [Text.UTF8Encoding]::new($false))
      (Get-LocationTestHash $inputPath) | Should Be '02fb69cbff42834ffa9a9cdebb60bab7e15c6cd0cf150175020de8c8d0f823f6'
    } else {
      [IO.File]::AppendAllText($inputPath, "`n-- drift`n")
    }
    { & $resolverPath } | Should Throw 'LocationCatalogV2 input hash mismatch'
  }

  It 'rejects raw bootstrap drift despite equal normalized hash: <kind>' -TestCases @(
    @{kind='source'}, @{kind='derived'}
  ) {
    param($kind)
    $inputPath = if ($kind -eq 'source') { $sourcePath } else { $bootstrapPath }
    $beforeHash = Get-LocationTestHash $inputPath
    $content = [IO.File]::ReadAllText($inputPath).Replace("`r`n","`n").Replace("`n","`r`n")
    [IO.File]::WriteAllText($inputPath, $content, [Text.UTF8Encoding]::new($false))
    (Get-LocationTestHash $inputPath) | Should Be $beforeHash
    { & $resolverPath } | Should Throw 'LocationCatalogV2 input raw hash mismatch'
  }

  It 'rejects bootstrap transformation drift <kind>' -TestCases @(
    @{kind='beforebegin'}, @{kind='duplicate'}, @{kind='session'}, @{kind='grant'}
  ) {
    param($kind)
    $sourceText = [IO.File]::ReadAllText($sourcePath)
    $line = "set local coelo.local_replay = 'location-catalog-v2';`n"
    $changed = switch ($kind) {
      beforebegin { $line + $sourceText }
      duplicate { $sourceText.Replace("begin;`n","begin;`n" + $line + $line) }
      session { $sourceText.Replace("begin;`n","begin;`nset coelo.local_replay = 'location-catalog-v2';`n") }
      grant { $sourceText.Replace("begin;`n","begin;`ngrant select on public.people to authenticated;`n") }
    }
    [IO.File]::WriteAllText($bootstrapPath, $changed, [Text.UTF8Encoding]::new($false))
    { & $resolverPath } | Should Throw 'LocationCatalogV2 input hash mismatch'
  }

  It 'rejects missing nominal input <kind>' -TestCases @(
    @{kind='institution'}, @{kind='candidate'}, @{kind='source'}, @{kind='derived'}
  ) {
    param($kind)
    $inputPath = switch ($kind) {
      institution { Join-Path $fixtureMigrationRoot $institutionName }
      candidate { Join-Path $fixtureMigrationRoot $candidateName }
      source { $sourcePath }
      derived { $bootstrapPath }
    }
    Remove-Item -LiteralPath $inputPath
    { & $resolverPath } | Should Throw 'LocationCatalogV2 input is missing'
  }

  It 'rejects a third generic preflight without copying' {
    [IO.File]::WriteAllText((Join-Path $fixtureReplayRoot '20260908030958_unapproved.sql'), 'select 1;')
    { & $resolverPath } | Should Throw 'LocationCatalogV2 requires 47 canonical migrations, two inherited preflights and one separate bootstrap'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects reparse metadata on <inputKind> <kind>' -TestCases @(
    @{inputKind='source';kind='file'}, @{inputKind='source';kind='ancestor'},
    @{inputKind='derived';kind='file'}, @{inputKind='derived';kind='ancestor'},
    @{inputKind='descriptor';kind='file'}, @{inputKind='descriptor';kind='ancestor'},
    @{inputKind='candidate';kind='file'}, @{inputKind='candidate';kind='ancestor'}
  ) {
    param($inputKind,$kind)
    $inputPath = switch ($inputKind) {
      source { $sourcePath }
      derived { $bootstrapPath }
      descriptor { $descriptorPath }
      candidate { Join-Path $fixtureMigrationRoot $candidateName }
    }
    $parentPath = Split-Path -Parent $inputPath
    $directoryMetadata = [pscustomobject]@{
      FullName=$parentPath; PSIsContainer=$true; Parent=$null
      Attributes=if($kind -eq 'ancestor'){[IO.FileAttributes]::ReparsePoint}else{[IO.FileAttributes]::Directory}
    }
    Mock Get-Item {
      [pscustomobject]@{
        FullName=$inputPath; PSIsContainer=$false; Directory=$directoryMetadata
        Attributes=if($kind -eq 'file'){[IO.FileAttributes]::ReparsePoint}else{[IO.FileAttributes]::Normal}
      }
    } -ParameterFilter { $LiteralPath -eq $inputPath }
    { & $resolverPath } | Should Throw 'reparse point'
  }

  It 'integration prepares exactly50 files with the separate bootstrap bytes and no source copy' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile LocationCatalogV2
    $expectedNames = @($baselineNames) + @($institutionName,$candidateName) + @($preflightNames) + @($bootstrapName)
    $actual = @(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name)
    $actual.Count | Should Be 50
    @(Compare-Object ($expectedNames | Sort-Object) @($actual.Name)).Count | Should Be 0
    $actual[48].Name | Should Be $bootstrapName
    $actual[49].Name | Should Be $candidateName
    foreach ($file in $actual) {
      $sourceRoot = if ($file.Name -eq $bootstrapName) { $fixtureBootstrapRoot } elseif ($file.Name -in $preflightNames) { $fixtureReplayRoot } else { $fixtureMigrationRoot }
      (Get-LocationTestHash $file.FullName -Raw) | Should Be (Get-LocationTestHash (Join-Path $sourceRoot $file.Name) -Raw)
    }
    (Get-LocationTestHash $sourcePath -Raw) | Should Be '3dd0bf5c11e52a68102e3e707e48835eb676513c235daab5defcdb1e7ad24bfb'
    $output | Should Match 'profile=LocationCatalogV2; additional=2'
    $output | Should Match '47 canonical \+ 2 preflight \+ 1 location bootstrap'
  }

  It 'integration reaches only the pre-mutex sentinel at the nominal target' {
    { & $invokeScript -TargetVersion 20260908031000 -NominalProfile LocationCatalogV2 } |
      Should Throw 'Location fixture stop before mutex or Docker'
  }

  It 'integration rejects earlier target' {
    { & $invokeScript -TargetVersion 20260901200206 -NominalProfile LocationCatalogV2 } |
      Should Throw 'LocationCatalogV2 requires target 20260908031000'
  }

  It 'integration rejects profile mixing <mode>' -TestCases @(
    @{mode='AuthOnly'}, @{mode='FoundationOnly'}, @{mode='AdditionalMigration'}
  ) {
    param($mode)
    $parameters = @{NominalProfile='LocationCatalogV2'}
    $parameters[$mode] = if ($mode -eq 'AdditionalMigration') { 'historical.sql|' + ('0'*64) } else { $true }
    { & $prepareScript -DestinationMigrationsRoot $destination @parameters } | Should Throw 'nominal replay cannot be combined'
    { & $invokeScript -TargetVersion 20260908031000 @parameters } | Should Throw 'nominal replay cannot be combined'
  }

  It 'integration rejects incompatible runner mode <mode>' -TestCases @(
    @{mode='RunAuthLifecycle'}, @{mode='RunActivityV2Concurrency'}
  ) {
    param($mode)
    $parameters = @{NominalProfile='LocationCatalogV2'}
    $parameters[$mode] = $true
    { & $invokeScript -TargetVersion 20260908031000 @parameters } | Should Throw 'nominal replay cannot be combined'
  }

  It 'integration rejects changed bootstrap before staging or the sentinel' {
    [IO.File]::AppendAllText($bootstrapPath,"`n-- drift`n")
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile LocationCatalogV2 } | Should Throw 'LocationCatalogV2 input hash mismatch'
    { & $invokeScript -TargetVersion 20260908031000 -NominalProfile LocationCatalogV2 } | Should Throw 'LocationCatalogV2 input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a non-allowlisted profile without changing legacy selectors' {
    { & $prepareScript -DestinationMigrationsRoot $destination -NominalProfile UnapprovedLocation } | Should Throw 'ValidateSet'
    { & $invokeScript -TargetVersion 20260908031000 -NominalProfile UnapprovedLocation } | Should Throw 'ValidateSet'
  }
}

Describe 'Location selector casing preserves its reviewed bootstrap' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $package = Join-Path $fixtureRoot 'repository\packages\coelo_database'
    $destination = Join-Path $fixtureRoot 'prepared'
    foreach ($directory in @($package, $destination)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    foreach ($directory in @('migrations', 'replay', 'scripts', 'tests')) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot $directory) -Destination $package -Recurse
    }
    $prepare = Join-Path $package 'scripts\Prepare-SafeMigrationReplay.ps1'
  }
  It 'prepares all 50 inputs for accepted selector <selector>' -TestCases @(
    @{selector='LocationCatalogV2'}, @{selector='locationcatalogv2'}, @{selector='LOCATIONCATALOGV2'}
  ) {
    param($selector)
    $output = & $prepare -DestinationMigrationsRoot $destination -NominalProfile $selector
    $actual = @(Get-ChildItem -LiteralPath $destination -File -Filter '*.sql' | Sort-Object Name)
    $actual.Count | Should Be 50
    $actual[48].Name | Should Be '20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
    $actual[49].Name | Should Be '20260908031000_superadmin_location_catalog_v2.sql'
    (Get-LocationTestHash $actual[48].FullName -Raw) | Should Be 'd46583bc936dfb284b5d05bdba8dea8f965d31a0f899164bfdd8a8c6bd6d2471'
    $output | Should Match '47 canonical \+ 2 preflight \+ 1 location bootstrap'
  }

  It 'rejects altered bootstrap before copying with accepted selector <selector>' -TestCases @(
    @{selector='locationcatalogv2'}, @{selector='LOCATIONCATALOGV2'}
  ) {
    param($selector)
    $bootstrap = Join-Path $package 'tests\fixtures\20260908030959_location_catalog_v2_capability_bootstrap_local.sql'
    [IO.File]::AppendAllText($bootstrap, '-- unreviewed input')
    { & $prepare -DestinationMigrationsRoot $destination -NominalProfile $selector } |
      Should Throw 'LocationCatalogV2 input hash mismatch'
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }
}
