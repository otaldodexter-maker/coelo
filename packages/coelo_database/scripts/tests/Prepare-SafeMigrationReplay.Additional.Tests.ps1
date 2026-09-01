$scriptPath = Join-Path $PSScriptRoot '..\Prepare-SafeMigrationReplay.ps1'
$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$migrationRoot = Join-Path $packageRoot 'migrations'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
  'coelo_prepare_replay_tests_' + [guid]::NewGuid().ToString('N')
)

function Get-NormalizedTextSha256([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $bytes = [Text.UTF8Encoding]::new($false).GetBytes($content)
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return (($sha256.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally {
    $sha256.Dispose()
  }
}

function Get-AdditionalEntry([string]$Name) {
  $path = Join-Path $migrationRoot $Name
  return "$Name|$(Get-NormalizedTextSha256 $path)"
}

Describe 'Prepare-SafeMigrationReplay reviewed additional migrations' {
  BeforeEach {
    $destination = Join-Path $testRoot ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
  }

  AfterEach {
    if (Test-Path -LiteralPath $destination) {
      Remove-Item -LiteralPath $destination -Recurse -Force
    }
  }

  AfterAll {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }

  It 'appends an ordered hash-pinned canonical allowlist after the foundation manifest' {
    $names = @(
      '20260901170731_access_profile_models_crud_and_catalog.sql',
      '20260901193000_name_access_profile_model_rpc_arguments.sql',
      '20260901210000_superadmin_internal_users_directory.sql'
    )
    $entries = @($names | ForEach-Object { Get-AdditionalEntry $_ })

    $output = & $scriptPath -DestinationMigrationsRoot $destination `
      -FoundationOnly -AdditionalMigration $entries

    $generated = @(Get-ChildItem -LiteralPath $destination -File -Filter '*.sql')
    $generated.Count | Should Be 64
    foreach ($name in $names) {
      $source = Join-Path $migrationRoot $name
      $copied = Join-Path $destination $name
      (Test-Path -LiteralPath $copied -PathType Leaf) | Should Be $true
      (Get-NormalizedTextSha256 $copied) | Should Be (Get-NormalizedTextSha256 $source)
    }
    $output | Should Match 'additional=3'
  }

  It 'rejects additional migrations outside the FoundationOnly profile' {
    $entry = Get-AdditionalEntry '20260901210000_superadmin_internal_users_directory.sql'
    { & $scriptPath -DestinationMigrationsRoot $destination -AdditionalMigration $entry } |
      Should Throw 'additional migrations require FoundationOnly'
  }

  It 'rejects an unordered additional allowlist' {
    $entries = @(
      Get-AdditionalEntry '20260901210000_superadmin_internal_users_directory.sql'
      Get-AdditionalEntry '20260901193000_name_access_profile_model_rpc_arguments.sql'
    )
    { & $scriptPath -DestinationMigrationsRoot $destination `
        -FoundationOnly -AdditionalMigration $entries } |
      Should Throw 'additional migrations must be unique and strictly ordered'
  }

  It 'rejects path traversal instead of resolving an arbitrary migration file' {
    $entry = '..\20260901210000_superadmin_internal_users_directory.sql|' + ('0' * 64)
    { & $scriptPath -DestinationMigrationsRoot $destination `
        -FoundationOnly -AdditionalMigration $entry } |
      Should Throw "invalid additional migration entry: $entry"
  }

  It 'rejects a migration that is not newer than the foundation manifest boundary' {
    $entry = Get-AdditionalEntry '20260831192831_activities_v2_actor_attribution.sql'
    { & $scriptPath -DestinationMigrationsRoot $destination `
        -FoundationOnly -AdditionalMigration $entry } |
      Should Throw 'additional migrations must be newer than the foundation manifest boundary'
  }

  It 'rejects a canonical migration whose expected normalized hash is wrong' {
    $entry = '20260901210000_superadmin_internal_users_directory.sql|' + ('0' * 64)
    { & $scriptPath -DestinationMigrationsRoot $destination `
        -FoundationOnly -AdditionalMigration $entry } |
      Should Throw 'additional migration hash mismatch: 20260901210000_superadmin_internal_users_directory.sql'
  }

  It 'keeps an explicit reparse-point rejection for every additional canonical source' {
    $text = [IO.File]::ReadAllText($scriptPath)
    $text | Should Match 'additional migration cannot be a reparse point'
  }
}
