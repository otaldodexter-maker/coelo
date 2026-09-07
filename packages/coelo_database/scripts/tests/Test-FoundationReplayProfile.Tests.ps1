$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$validatorPath = Join-Path $PSScriptRoot '..\Test-FoundationReplayProfile.ps1'
$manifestPath = Join-Path $packageRoot 'replay\foundation-migrations.sha256'
$migrationRoot = Join-Path $packageRoot 'migrations'

function Get-FixtureMigrationEntry([string]$Name) {
  $source = Join-Path $migrationRoot $Name
  Copy-Item -LiteralPath $source -Destination (Join-Path $fixtureRoot 'migrations')
  $text = [IO.File]::ReadAllText($source).
    Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = ([BitConverter]::ToString(
      $sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($text))
    )).Replace('-', '').ToLowerInvariant()
    return "$Name|$hash"
  }
  finally {
    $sha.Dispose()
  }
}

Describe 'Foundation replay closed profile' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    foreach ($directory in @('scripts', 'replay', 'migrations')) {
      New-Item -ItemType Directory -Path (Join-Path $fixtureRoot $directory) | Out-Null
    }
    $fixtureValidator = Join-Path $fixtureRoot 'scripts\Test-FoundationReplayProfile.ps1'
    $fixtureManifest = Join-Path $fixtureRoot 'replay\foundation-migrations.sha256'
    Copy-Item -LiteralPath $validatorPath -Destination $fixtureValidator
    Copy-Item -LiteralPath $manifestPath -Destination $fixtureManifest
    $entries = @([IO.File]::ReadAllLines($manifestPath) |
      Where-Object { $_.Trim() -and -not $_.TrimStart().StartsWith('#') })
    foreach ($entry in $entries) {
      Copy-Item -LiteralPath (Join-Path $migrationRoot $entry.Split('|')[0]) `
        -Destination (Join-Path $fixtureRoot 'migrations')
    }
  }

  It 'accepts the reviewed 67 migrations through the internal MFA deferral' {
    $result = & $fixtureValidator
    $result | Should Match 'PASS: 67 reviewed canonical migrations'
  }

  It 'rejects an extra canonical migration even with a valid name and hash' {
    $additional = Get-FixtureMigrationEntry '20260901210000_superadmin_internal_users_directory.sql'
    [IO.File]::AppendAllText($fixtureManifest, "`r`n$additional`r`n")

    { & $fixtureValidator } | Should Throw 'must contain exactly 67 canonical migrations; found 68'
  }

  It 'rejects a changed SQL payload when its reviewed hash is unchanged' {
    $migration = Join-Path $fixtureRoot ('migrations\' + $entries[0].Split('|')[0])
    [IO.File]::AppendAllText($migration, "`r`nselect 1;`r`n")

    { & $fixtureValidator } | Should Throw 'foundation replay migration hash mismatch'
  }

  It 'rejects a different final migration even when count and hashes are valid' {
    $entries[-1] = Get-FixtureMigrationEntry '20260901210000_superadmin_internal_users_directory.sql'
    [IO.File]::WriteAllLines($fixtureManifest, $entries)

    { & $fixtureValidator } | Should Throw 'foundation replay profile boundaries changed without review'
  }
}
