$scriptPath = Join-Path $PSScriptRoot '..\Prepare-SafeMigrationReplay.ps1'

Describe 'Prepare-SafeMigrationReplay canonical ordering' {
  It 'accepts canonical migrations between the labels bridge and audit production' {
    $destinationRoot = Join-Path ([IO.Path]::GetTempPath()) (
      'coelo-safe-replay-test-' + [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $destinationRoot | Out-Null

    try {
      { & $scriptPath -DestinationMigrationsRoot $destinationRoot } |
        Should Not Throw

      Test-Path -LiteralPath (
        Join-Path $destinationRoot '20260811215452_access_profile_labels_replay_bridge.sql'
      ) | Should Be $true
      Test-Path -LiteralPath (
        Join-Path $destinationRoot '20260812000847_audit_production.sql'
      ) | Should Be $true
    }
    finally {
      Remove-Item -LiteralPath $destinationRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
