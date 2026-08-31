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
}
