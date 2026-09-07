$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-AuthAdditionEntry([string]$Name) {
  $content = [IO.File]::ReadAllText((Join-Path $fixtureMigrationRoot $Name)).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = ([BitConverter]::ToString(
      $sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($content))
    )).Replace('-', '').ToLowerInvariant()
    return "$Name|$hash"
  }
  finally { $sha.Dispose() }
}

Describe 'Auth-only replay nominal additional migrations' {
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
    foreach ($name in @('Prepare-SafeMigrationReplay.ps1', 'Invoke-SafeLocalMigrationReplay.ps1')) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination $fixtureScriptRoot
    }
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
      Copy-Item -Destination $fixtureMigrationRoot
    Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') -File |
      Copy-Item -Destination $fixtureReplayRoot
    $prepareScript = Join-Path $fixtureScriptRoot 'Prepare-SafeMigrationReplay.ps1'
    $invokeScript = Join-Path $fixtureScriptRoot 'Invoke-SafeLocalMigrationReplay.ps1'
    $firstName = '20260907000001_harness_fixture_first.sql'
    $lastName = '20260907000002_harness_fixture_last.sql'
    foreach ($name in @($firstName, $lastName)) {
      [IO.File]::WriteAllText((Join-Path $fixtureMigrationRoot $name), "select 1;`n")
    }
    $firstEntry = Get-AuthAdditionEntry $firstName
    $lastEntry = Get-AuthAdditionEntry $lastName
    $baselineEntries = @(Get-Content -LiteralPath (Join-Path $fixtureReplayRoot 'foundation-migrations.sha256') |
      Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') } |
      Where-Object {
        $version = $_.Substring(0, 14)
        $version -le '20260812001975' -or $version -in @(
          '20260827214000', '20260827233000', '20260901124500', '20260901200206')
      })
    $baselineNames = @($baselineEntries | ForEach-Object { $_.Split('|')[0] }) + @(
      '20260811151253_assert_function_execute_preflight.sql',
      '20260811215452_access_profile_labels_replay_bridge.sql'
    )
    # No config is copied: accepted Invoke arguments must stop at its existing
    # config guard, before mutex acquisition, Docker inspection or CLI calls.
  }

  It 'preserves exactly the 45 canonical Auth migrations and two preflights without additions' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly
    $actualNames = @(Get-ChildItem -LiteralPath $destination -File | Select-Object -ExpandProperty Name)
    $baselineEntries.Count | Should Be 45
    $actualNames.Count | Should Be 47
    @(Compare-Object ($baselineNames | Sort-Object) ($actualNames | Sort-Object)).Count | Should Be 0
    $output | Should Match 'profile=auth; additional=0'
  }

  It 'appends only the ordered hash-pinned additions while preserving the Auth baseline' {
    $output = & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly `
      -AdditionalMigration @($firstEntry, $lastEntry)
    $actualNames = @(Get-ChildItem -LiteralPath $destination -File | Select-Object -ExpandProperty Name)
    $expectedNames = @($baselineNames) + @($firstName, $lastName)
    $actualNames.Count | Should Be 49
    @(Compare-Object ($expectedNames | Sort-Object) ($actualNames | Sort-Object)).Count | Should Be 0
    foreach ($name in @($firstName, $lastName)) {
      [IO.File]::ReadAllText((Join-Path $destination $name)) |
        Should Be ([IO.File]::ReadAllText((Join-Path $fixtureMigrationRoot $name)))
    }
    $output | Should Match 'profile=auth; additional=2'
  }

  It 'rejects an incorrect additional SQL hash before copying any migration' {
    $entry = $firstName + '|' + ('0' * 64)
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw "additional migration hash mismatch: $firstName"
    @(Get-ChildItem -LiteralPath $destination -Force).Count | Should Be 0
  }

  It 'rejects a missing canonical addition' {
    $entry = '20260907000003_missing_harness_fixture.sql|' + ('0' * 64)
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'additional canonical migration is missing'
  }

  It 'rejects duplicate addition versions in both preparation and invocation' {
    $entries = @($firstEntry, $firstEntry)
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entries } |
      Should Throw 'additional migrations must be unique and strictly ordered'
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -AdditionalMigration $entries } |
      Should Throw 'additional migrations must be unique and strictly ordered'
  }

  It 'rejects unordered additions in both preparation and invocation' {
    $entries = @($lastEntry, $firstEntry)
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entries } |
      Should Throw 'additional migrations must be unique and strictly ordered'
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -AdditionalMigration $entries } |
      Should Throw 'additional migrations must be unique and strictly ordered'
  }

  It 'rejects additions at the Auth boundary in both scripts' {
    $entry = Get-AuthAdditionEntry '20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql'
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'additional migrations must be newer than the Auth-only boundary'
    { & $invokeScript -TargetVersion 20260901200206 -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'additional migrations must be newer than the Auth-only boundary'
  }

  It 'rejects additions newer than the legacy Foundation boundary but older than the Auth boundary' {
    $entry = Get-AuthAdditionEntry '20260901193000_name_access_profile_model_rpc_arguments.sql'
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'additional migrations must be newer than the Auth-only boundary'
    { & $invokeScript -TargetVersion 20260901193000 -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'additional migrations must be newer than the Auth-only boundary'
  }

  It 'rejects path escape entries before resolving files in either script' {
    $entry = '..\' + $firstEntry
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'invalid additional migration entry'
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'invalid additional migration entry'
  }

  It 'rejects malformed hashes in either script' {
    $entry = $firstName + '|not-a-sha256'
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'invalid additional migration entry'
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -AdditionalMigration $entry } |
      Should Throw 'invalid additional migration entry'
  }

  It 'keeps FoundationOnly and AuthOnly mutually exclusive even with additions' {
    { & $prepareScript -DestinationMigrationsRoot $destination -AuthOnly -FoundationOnly -AdditionalMigration $firstEntry } |
      Should Throw 'foundation-only and Auth-only replay profiles are mutually exclusive'
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -FoundationOnly -AdditionalMigration $firstEntry } |
      Should Throw 'foundation-only and Auth-only replay profiles are mutually exclusive'
  }

  It 'rejects additions without a named constrained profile in either script' {
    { & $prepareScript -DestinationMigrationsRoot $destination -AdditionalMigration $firstEntry } |
      Should Throw 'additional migrations require FoundationOnly or AuthOnly'
    { & $invokeScript -TargetVersion 20260907000001 -AdditionalMigration $firstEntry } |
      Should Throw 'additional migrations require FoundationOnly or AuthOnly'
  }

  It 'keeps the original Auth target without additions and stops before Docker' {
    { & $invokeScript -TargetVersion 20260901200206 -AuthOnly } |
      Should Throw 'canonical Supabase config is missing'
  }

  It 'accepts the final nominal addition as the Auth target and stops before Docker' {
    { & $invokeScript -TargetVersion 20260907000002 -AuthOnly -AdditionalMigration @($firstEntry, $lastEntry) } |
      Should Throw 'canonical Supabase config is missing'
  }

  It 'rejects an earlier Auth target that would silently omit the last addition' {
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly -AdditionalMigration @($firstEntry, $lastEntry) } |
      Should Throw 'Auth-only replay requires final target 20260907000002; received 20260907000001'
  }

  It 'rejects the baseline Auth target when additions were requested' {
    { & $invokeScript -TargetVersion 20260901200206 -AuthOnly -AdditionalMigration $firstEntry } |
      Should Throw 'Auth-only replay requires final target 20260907000001; received 20260901200206'
  }

  It 'rejects a target beyond the last reviewed Auth addition' {
    { & $invokeScript -TargetVersion 20260907000002 -AuthOnly -AdditionalMigration $firstEntry } |
      Should Throw 'Auth-only replay requires final target 20260907000001; received 20260907000002'
  }

  It 'rejects a newer target without a nominal Auth addition' {
    { & $invokeScript -TargetVersion 20260907000001 -AuthOnly } |
      Should Throw 'Auth-only replay requires target 20260901200206'
  }
}
