$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-FReadGreenDerivedTestHash([string]$Path, [switch]$Raw) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
      [Text.UTF8Encoding]::new($false).GetBytes(
        [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n"))
    }
    ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function New-FReadGreenDerivedFixture([string]$Root) {
  $package = Join-Path $Root 'repository\packages\coelo_database'
  $scripts = Join-Path $package 'scripts'
  $migrations = Join-Path $package 'migrations'
  $replay = Join-Path $package 'replay'
  $destination = Join-Path $Root 'prepared'
  foreach ($path in @($scripts, $migrations, $replay, $destination)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
  Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
    Copy-Item -Destination $migrations
  Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') |
    Copy-Item -Destination $replay -Recurse
  foreach ($name in @('Invoke-SafeLocalMigrationReplay.ps1', 'Prepare-SafeMigrationReplay.ps1')) {
    Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination $scripts
  }
  $invoke = Join-Path $scripts 'Invoke-SafeLocalMigrationReplay.ps1'
  $anchor = '$mutex = [Threading.Mutex]::new'
  $invokeText = [IO.File]::ReadAllText($invoke)
  if (-not $invokeText.Contains($anchor)) { throw 'fixture sentinel anchor missing' }
  # Only this TestDrive copy can execute; it stops before mutex/staging/Docker.
  [IO.File]::WriteAllText($invoke, $invokeText.Replace(
    $anchor, "throw 'FRead Green derived fixture stop before mutex or Docker'`n" + $anchor))
  $config = Join-Path $package 'supabase'
  New-Item -ItemType Directory -Path $config | Out-Null
  [IO.File]::WriteAllText((Join-Path $config 'config.toml'), 'project_id = "fread_derived_fixture"')
  $profile = Join-Path $replay 'profiles\FReadDirectoryContractGreenDerived'
  [pscustomobject]@{
    Package = $package; Migrations = $migrations; Replay = $replay; Destination = $destination
    Invoke = $invoke; Prepare = Join-Path $scripts 'Prepare-SafeMigrationReplay.ps1'
    Resolver = Join-Path $profile 'Resolve-FReadDirectoryContractGreenDerived.ps1'
    Descriptor = Join-Path $profile 'profile.json'
    Converter = Join-Path $replay 'profiles\FReadDirectoryContractRedDerived\Convert-FReadFormsDefinitionForLocalReplay.ps1'
    ParentResolver = Join-Path $replay 'profiles\FReadDirectoryContractGreen\Resolve-FReadDirectoryContractGreen.ps1'
    ParentDescriptor = Join-Path $replay 'profiles\FReadDirectoryContractGreen\profile.json'
    Source = Join-Path $migrations '20260813155005_forms_definition_and_capabilities.sql'
  }
}

Describe 'Closed FRead Green derived resolver' -Tag 'FReadGreenDerivedResolver' {
  BeforeEach { $fixture = New-FReadGreenDerivedFixture (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) }

  It 'returns the unchanged canonical Green51 inputs and one pinned materialization without writing or executing it' {
    $sourceBefore = Get-FReadGreenDerivedTestHash $fixture.Source -Raw
    $parent = & $fixture.ParentResolver
    $result = & $fixture.Resolver
    $result.Canonical.Count | Should Be 49
    $result.Preflight.Count | Should Be 2
    $result.Additional.Count | Should Be 4
    $actual = @(@($result.Canonical) + @($result.Preflight) | Sort-Object Name)
    $expected = @(@($parent.Canonical) + @($parent.Preflight) | Sort-Object Name)
    ($actual.FullName -join '|') | Should Be ($expected.FullName -join '|')
    $actual[-1].Name.Substring(0, 14) | Should Be '20260908000049'
    $result.ManifestHash | Should Be $parent.ManifestHash
    $metadata = $result.FormsDefinitionMaterialization
    $metadata.SourceMigration | Should Be '20260813155005_forms_definition_and_capabilities.sql'
    $metadata.SourceSha256CrlfUtf8 | Should Be '3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36'
    $metadata.DerivedSha256CrlfUtf8 | Should Be '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe'
    $metadata.ConverterPath | Should Be $fixture.Converter
    $metadata.ConverterSha256CrlfUtf8 | Should Be 'c3cc8e86a075c20f608d3d34ab31f1611e56f80aabfe29958832f5ab05982dc5'
    $metadata.InsertedCharacterCount | Should Be 4
    (Get-FReadGreenDerivedTestHash $fixture.Source -Raw) | Should Be $sourceBefore
    @(Get-ChildItem -LiteralPath $fixture.Destination -Force).Count | Should Be 0
  }

  It 'rejects the old Auth boundary instead of the reader target' {
    { & $fixture.Resolver -TargetVersion 20260901200206 } |
      Should Throw 'FReadDirectoryContractGreenDerived requires target 20260908000049'
  }

  It 'rejects descriptor drift in <field>' -TestCases @(
    @{ field = 'source' }, @{ field = 'derived' }, @{ field = 'converter' },
    @{ field = 'delta' }, @{ field = 'pathescape' }, @{ field = 'parent' },
    @{ field = 'target' }, @{ field = 'bridge' }, @{ field = 'count' }
  ) {
    param($field)
    $descriptor = Get-Content -LiteralPath $fixture.Descriptor -Raw | ConvertFrom-Json
    switch ($field) {
      source { $descriptor.forms_definition_materialization.source_sha256_crlf_utf8 = '0' * 64 }
      derived { $descriptor.forms_definition_materialization.derived_sha256_crlf_utf8 = '0' * 64 }
      converter { $descriptor.forms_definition_materialization.converter_sha256_crlf_utf8 = '0' * 64 }
      delta { $descriptor.forms_definition_materialization.inserted_character_count = 6 }
      pathescape { $descriptor.forms_definition_materialization.file = '..\escape.sql' }
      parent { $descriptor.parent.resolver_sha256_crlf_utf8 = '0' * 64 }
      target { $descriptor.target_version = '20260901200206' }
      bridge { $descriptor.extra_bridges = @('unapproved.sql') }
      count { $descriptor.planned_counts.total = 52 }
    }
    [IO.File]::WriteAllText($fixture.Descriptor, ($descriptor | ConvertTo-Json -Depth 10))
    { & $fixture.Resolver } | Should Throw 'FReadDirectoryContractGreenDerived descriptor hash mismatch'
  }

  It 'rejects changed <dependency> before calling inherited code' -TestCases @(
    @{ dependency = 'Converter' }, @{ dependency = 'ParentResolver' }, @{ dependency = 'ParentDescriptor' }
  ) {
    param($dependency)
    [IO.File]::AppendAllText($fixture.$dependency, "`n# changed fixture`n")
    { & $fixture.Resolver } | Should Throw 'FReadDirectoryContractGreenDerived dependency hash mismatch'
  }

  It 'retains the canonical input hash gate for <kind>' -TestCases @(
    @{ kind = 'source' }, @{ kind = 'baseline' }, @{ kind = 'preflight' }
  ) {
    param($kind)
    $path = switch ($kind) {
      source { $fixture.Source }
      baseline { (Get-ChildItem -LiteralPath $fixture.Migrations -File | Sort-Object Name | Select-Object -First 1).FullName }
      preflight { Join-Path $fixture.Replay '20260811151253_assert_function_execute_preflight.sql' }
    }
    [IO.File]::AppendAllText($path, "`n-- changed fixture`n")
    { & $fixture.Resolver } | Should Throw 'FReadDirectoryContractGreen input hash mismatch'
  }

  It 'rejects a <dependency> <kind> reparse point before reading or invoking it' -TestCases @(
    @{ dependency = 'ParentResolver'; kind = 'file' }, @{ dependency = 'ParentResolver'; kind = 'ancestor' },
    @{ dependency = 'Converter'; kind = 'file' }, @{ dependency = 'Converter'; kind = 'ancestor' }
  ) {
    param($dependency, $kind)
    $guardedPath = $fixture.$dependency
    $parentPath = Split-Path -Parent $guardedPath
    $directoryMetadata = [pscustomobject]@{
      FullName = $parentPath; PSIsContainer = $true; Parent = $null
      Attributes = if ($kind -eq 'ancestor') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Directory }
    }
    Mock Get-Item {
      [pscustomobject]@{
        FullName = $guardedPath; PSIsContainer = $false; Directory = $directoryMetadata
        Attributes = if ($kind -eq 'file') { [IO.FileAttributes]::ReparsePoint } else { [IO.FileAttributes]::Normal }
      }
    } -ParameterFilter { $LiteralPath -eq $guardedPath }
    { & $fixture.Resolver } | Should Throw 'reparse point'
  }

  It 'rejects a missing or changed reader: <defect>' -TestCases @(
    @{ defect = 'missing' }, @{ defect = 'hash' }
  ) {
    param($defect)
    $reader = Join-Path $fixture.Migrations '20260908000049_superadmin_forms_directory_internal_read.sql'
    if ($defect -eq 'missing') {
      [IO.File]::Delete($reader)
      { & $fixture.Resolver } | Should Throw 'FReadDirectoryContractGreen input is missing'
    } else {
      [IO.File]::AppendAllText($reader, '-- changed')
      { & $fixture.Resolver } | Should Throw 'FReadDirectoryContractGreen input hash mismatch'
    }
  }
}

Describe 'Closed FRead Green derived entrypoints' -Tag 'FReadGreenDerivedEntrypoints' {
  BeforeEach { $fixture = New-FReadGreenDerivedFixture (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) }

  It 'materializes the same 51 names with only four inserted bytes in the single approved file' {
    $parent = & $fixture.ParentResolver
    $sourceBefore = Get-FReadGreenDerivedTestHash $fixture.Source -Raw
    & $fixture.Prepare -DestinationMigrationsRoot $fixture.Destination -NominalProfile FReadDirectoryContractGreenDerived
    $expected = @(@($parent.Canonical) + @($parent.Preflight) | Sort-Object Name)
    $actual = @(Get-ChildItem -LiteralPath $fixture.Destination -File | Sort-Object Name)
    $actual.Count | Should Be 51
    ($actual.Name -join '|') | Should Be ($expected.Name -join '|')
    for ($index = 0; $index -lt $actual.Count; $index++) {
      if ($actual[$index].Name -eq '20260813155005_forms_definition_and_capabilities.sql') {
        (Get-FReadGreenDerivedTestHash $actual[$index].FullName) | Should Be '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe'
        ($actual[$index].Length - $expected[$index].Length) | Should Be 4
      } else {
        (Get-FReadGreenDerivedTestHash $actual[$index].FullName -Raw) | Should Be (Get-FReadGreenDerivedTestHash $expected[$index].FullName -Raw)
      }
    }
    (Get-FReadGreenDerivedTestHash $fixture.Source -Raw) | Should Be $sourceBefore
  }

  It 'accepts only the reviewed target and stops before any Docker or staging action' {
    { & $fixture.Invoke -TargetVersion 20260908000049 -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'FRead Green derived fixture stop before mutex or Docker'
    { & $fixture.Invoke -TargetVersion 20260827235500 -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'FReadDirectoryContractGreenDerived requires target 20260908000049'
  }

  It 'rejects nominal CLI mixing: <mode>' -TestCases @(
    @{ mode = 'AuthOnly' }, @{ mode = 'FoundationOnly' }, @{ mode = 'AdditionalMigration' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'FReadDirectoryContractGreenDerived' }
    $parameters[$mode] = if ($mode -eq 'AdditionalMigration') { 'historical.sql|' + ('0' * 64) } else { $true }
    { & $fixture.Prepare -DestinationMigrationsRoot $fixture.Destination @parameters } |
      Should Throw 'nominal replay cannot be combined'
    { & $fixture.Invoke -TargetVersion 20260908000049 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects incompatible runner mode <mode>' -TestCases @(
    @{ mode = 'RunAuthLifecycle' }, @{ mode = 'RunActivityV2Concurrency' }
  ) {
    param($mode)
    $parameters = @{ NominalProfile = 'FReadDirectoryContractGreenDerived' }
    $parameters[$mode] = $true
    { & $fixture.Invoke -TargetVersion 20260908000049 @parameters } |
      Should Throw 'nominal replay cannot be combined'
  }

  It 'rejects converter drift before either entrypoint can copy or reach the sentinel' {
    [IO.File]::AppendAllText($fixture.Converter, "`n# changed fixture`n")
    { & $fixture.Prepare -DestinationMigrationsRoot $fixture.Destination -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'FReadDirectoryContractGreenDerived dependency hash mismatch'
    { & $fixture.Invoke -TargetVersion 20260908000049 -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'FReadDirectoryContractGreenDerived dependency hash mismatch'
    @(Get-ChildItem -LiteralPath $fixture.Destination -Force).Count | Should Be 0
  }

  It 'rejects a relative destination before copying any input' {
    $relative = Resolve-Path -LiteralPath $fixture.Destination -Relative
    { & $fixture.Prepare -DestinationMigrationsRoot $relative -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'derived destination must be an absolute local path'
    @(Get-ChildItem -LiteralPath $fixture.Destination -Force).Count | Should Be 0
  }

  It 'rejects a destination ancestor reparse point before copying any input' {
    $unsafeParent = [pscustomobject]@{
      FullName = Split-Path -Parent $fixture.Destination
      PSIsContainer = $true; Parent = $null; Attributes = [IO.FileAttributes]::ReparsePoint
    }
    Mock Get-Item {
      [pscustomobject]@{
        FullName = $fixture.Destination; PSIsContainer = $true
        Parent = $unsafeParent; Attributes = [IO.FileAttributes]::Directory
      }
    } -ParameterFilter { $LiteralPath -eq $fixture.Destination }
    { & $fixture.Prepare -DestinationMigrationsRoot $fixture.Destination -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'reparse point'
    @(Get-ChildItem -LiteralPath $fixture.Destination -Force).Count | Should Be 0
  }

  It 'rejects a converter result with <defect> before copying the other 50 inputs' -TestCases @(
    @{ defect = 'source_receipt' }, @{ defect = 'derived_receipt' }, @{ defect = 'path_receipt' },
    @{ defect = 'delta_receipt' }, @{ defect = 'actual_hash' }, @{ defect = 'actual_missing' },
    @{ defect = 'original_changed' }, @{ defect = 'duplicate_receipt' }
  ) {
    param($defect)
    # Only the TestDrive converter and its two pins change here. This simulates
    # a faulty reviewed converter so Prepare's independent postconditions run.
    $converterText = [IO.File]::ReadAllText($fixture.Converter)
    switch ($defect) {
      source_receipt { $converterText = $converterText.Replace('SourceSha256CrlfUtf8 = $sourceHash', "SourceSha256CrlfUtf8 = ('0' * 64)") }
      derived_receipt { $converterText = $converterText.Replace('DerivedSha256CrlfUtf8 = $derivedHash', "DerivedSha256CrlfUtf8 = ('0' * 64)") }
      path_receipt { $converterText = $converterText.Replace('DestinationPath = $outputPath', "DestinationPath = (Join-Path `$DestinationMigrationsRoot 'wrong.sql')") }
      delta_receipt { $converterText = $converterText.Replace('InsertedCharacterCount = 4', 'InsertedCharacterCount = 6') }
      actual_hash { $converterText = $converterText.Replace('[pscustomobject]@{', "[IO.File]::AppendAllText(`$outputPath, '-- corrupt')`n[pscustomobject]@{") }
      actual_missing { $converterText = $converterText.Replace('[pscustomobject]@{', "[IO.File]::Delete(`$outputPath)`n[pscustomobject]@{") }
      original_changed { $converterText = $converterText.Replace('[pscustomobject]@{', "[IO.File]::AppendAllText(`$sourcePath, '-- changed')`n[pscustomobject]@{") }
      duplicate_receipt { $converterText += "`n[pscustomobject]@{ Duplicate = `$true }`n" }
    }
    [IO.File]::WriteAllText($fixture.Converter, $converterText)
    $descriptorHashBefore = Get-FReadGreenDerivedTestHash $fixture.Descriptor
    $descriptor = Get-Content -LiteralPath $fixture.Descriptor -Raw | ConvertFrom-Json
    $descriptor.forms_definition_materialization.converter_sha256_crlf_utf8 = Get-FReadGreenDerivedTestHash $fixture.Converter
    [IO.File]::WriteAllText($fixture.Descriptor, ($descriptor | ConvertTo-Json -Depth 10))
    $resolverText = [IO.File]::ReadAllText($fixture.Resolver)
    [IO.File]::WriteAllText($fixture.Resolver, $resolverText.Replace(
      $descriptorHashBefore, (Get-FReadGreenDerivedTestHash $fixture.Descriptor)))
    { & $fixture.Prepare -DestinationMigrationsRoot $fixture.Destination -NominalProfile FReadDirectoryContractGreenDerived } |
      Should Throw 'derived materialization'
    @(Get-ChildItem -LiteralPath $fixture.Destination -File | Where-Object {
      $_.Name -ne '20260813155005_forms_definition_and_capabilities.sql'
    }).Count | Should Be 0
  }
}
