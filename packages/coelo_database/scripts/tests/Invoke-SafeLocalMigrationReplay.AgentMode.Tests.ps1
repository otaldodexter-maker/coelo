$scriptPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'
$tokens = $null
$parseErrors = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
  $scriptPath,
  [ref]$tokens,
  [ref]$parseErrors
)

Describe 'Invoke-SafeLocalMigrationReplay Supabase CLI agent mode' {
  It 'parses without errors' {
    @($parseErrors).Count | Should Be 0
  }

  It 'disables CLI agent autodetection for every npx Supabase invocation' {
    $cliCalls = @(
      $scriptAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
          $node.CommandElements.Count -gt 0 -and
          $node.CommandElements[0].Extent.Text -eq 'npx.cmd'
      }, $true)
    )

    $cliCalls.Count | Should BeGreaterThan 0
    foreach ($call in $cliCalls) {
      $elements = @($call.CommandElements | ForEach-Object { $_.Extent.Text })
      $agentIndex = [Array]::IndexOf($elements, '--agent')

      $agentIndex | Should BeGreaterThan -1
      ($agentIndex + 1) | Should BeLessThan $elements.Count
      $elements[$agentIndex + 1] | Should Be 'no'
    }
  }

  It 'forwards the reviewed additional migration allowlist to replay preparation' {
    $prepareCall = @(
      $scriptAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
          $node.CommandElements.Count -gt 0 -and
          $node.CommandElements[0].Extent.Text -match 'Prepare-SafeMigrationReplay\.ps1'
      }, $true)
    )

    $prepareCall.Count | Should Be 1
    $elements = @($prepareCall[0].CommandElements | ForEach-Object { $_.Extent.Text })
    ($elements -contains '-AdditionalMigration') | Should Be $true
    ($elements -contains '$AdditionalMigration') | Should Be $true
  }

  It 'keeps generated replay ownership, reparse and residual-resource cleanup gates' {
    $text = [IO.File]::ReadAllText($scriptPath)
    $text | Should Match 'Assert-NoReparseTree \$projectRoot'
    $text | Should Match '\.coelo-safe-replay'
    $text | Should Match 'Get-DockerResources \$projectId'
    $text | Should Match 'project directory remains after cleanup'
  }

  It 'validates additions before start without exposing migrations to automatic startup replay' {
    $text = [IO.File]::ReadAllText($scriptPath)
    $text | Should Match '\$validatedMigrationRoot'
    $text | Should Match '-DestinationMigrationsRoot \$validatedMigrationRoot'
    $text | Should Match 'Copy-Item -LiteralPath \$validatedMigration\.FullName -Destination \$migrationRoot'
    $text.IndexOf('-DestinationMigrationsRoot $validatedMigrationRoot') |
      Should BeLessThan $text.IndexOf('$startAttempted = $true')
    $text.IndexOf('Copy-Item -LiteralPath $validatedMigration.FullName -Destination $migrationRoot') |
      Should BeGreaterThan $text.IndexOf('supabase start failed with exit code')
  }
}
