$wrapperPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'

Describe 'Safe replay CHILD concurrency opt-in' {
  It 'rejects <label> before allocating resources' -TestCases @(
    @{ label='missing profile'; options=@{}; target='20260908051500' },
    @{ label='foreign profile'; options=@{NominalProfile='A01DirectoryAuditGreen'}; target='20260908051500' },
    @{ label='foreign target'; options=@{NominalProfile='ChildDirectoryEnvelope'}; target='20260901200206' },
    @{ label='foundation'; options=@{NominalProfile='ChildDirectoryEnvelope';FoundationOnly=$true}; target='20260908051500' },
    @{ label='Auth only'; options=@{NominalProfile='ChildDirectoryEnvelope';AuthOnly=$true}; target='20260908051500' },
    @{ label='additions'; options=@{NominalProfile='ChildDirectoryEnvelope';AdditionalMigration=@('invalid')}; target='20260908051500' },
    @{ label='Auth lifecycle'; options=@{NominalProfile='ChildDirectoryEnvelope';RunAuthLifecycle=$true}; target='20260908051500' },
    @{ label='Activity concurrency'; options=@{NominalProfile='ChildDirectoryEnvelope';RunActivityV2Concurrency=$true}; target='20260908051500' },
    @{ label='R02 Auth concurrency'; options=@{NominalProfile='ChildDirectoryEnvelope';RunR02AuthProofConcurrency=$true}; target='20260908051500' }
  ) {
    param($label,$options,$target)
    { & $wrapperPath -TargetVersion $target -RunChildDirectoryConcurrency @options } |
      Should Throw 'CHILD concurrency requires exact ChildDirectoryEnvelope target without other modes or additions'
  }

  It 'allows the exact CHILD opt-in through its guard without starting services' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($wrapperPath,[ref]$tokens,[ref]$errors)
    @($errors).Count | Should Be 0
    $guards=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
      $node.Extent.Text.Contains("throw 'CHILD concurrency requires exact ChildDirectoryEnvelope")
    },$true))
    $guards.Count | Should Be 1
    $RunChildDirectoryConcurrency=$true
    $NominalProfile='ChildDirectoryEnvelope'; $TargetVersion='20260908051500'
    $FoundationOnly=$false; $AuthOnly=$false; $AdditionalMigration=@()
    $RunAuthLifecycle=$false; $RunActivityV2Concurrency=$false; $RunR02AuthProofConcurrency=$false
    (& ([scriptblock]::Create($guards[0].Clauses[0].Item1.Extent.Text))) | Should Be $false
  }

  It 'dispatches only the owned CHILD harness after lint and retains the Auth dispatch' {
    $source=[IO.File]::ReadAllText($wrapperPath)
    $source | Should Match 'if \(\$RunChildDirectoryConcurrency\) \{\s*& \(Join-Path \$scriptRoot ''Test-ChildDirectoryConcurrency.ps1''\) `\s*-ProjectRoot \$projectRoot `\s*-ProjectId \$projectId'
    $source.IndexOf("if (`$RunChildDirectoryConcurrency) {") | Should BeGreaterThan $source.IndexOf('if ($RunLint)')
    $source | Should Match 'Test-R02AuthProofConcurrency.ps1'
    $source | Should Match '8A5ABFBAECB1DC4134542F3F016837CC51521C3CCF1C6F61BD9DE84F45BC2E86'
  }
}

Describe 'CHILD concurrency requires its nominal TAP gate' {
  It 'rejects an omitted, unrelated or additional TAP path before resources' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($wrapperPath,[ref]$tokens,[ref]$errors)
    $guards=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
      $node.Extent.Text.Contains("throw 'CHILD concurrency or HTTP requires exactly the nominal CHILD TAP'")
    },$true))
    $guards.Count | Should Be 1
    $canonicalTestsRoot='C:\nominal\supabase\tests'
    $expectedChildTap=Join-Path $canonicalTestsRoot 'superadmin_child_context_directory_v2_test.sql'
    $condition=[scriptblock]::Create($guards[0].Clauses[0].Item1.Extent.Text)
    foreach ($http in @($false,$true)) {
      $RunChildDirectoryConcurrency=-not $http
      $RunChildDirectoryHttp=$http
      $resolvedTestPaths=@(); (& $condition) | Should Be $true
      $resolvedTestPaths=@('C:\nominal\supabase\tests\other.sql'); (& $condition) | Should Be $true
      $resolvedTestPaths=@($expectedChildTap,$expectedChildTap); (& $condition) | Should Be $true
      $resolvedTestPaths=@($expectedChildTap); (& $condition) | Should Be $false
    }
    $RunChildDirectoryConcurrency=$false; $RunChildDirectoryHttp=$false
    $resolvedTestPaths=@(); (& $condition) | Should Be $false
    $ast.Extent.Text.IndexOf("throw 'CHILD concurrency or HTTP requires exactly the nominal CHILD TAP'") |
      Should BeLessThan $ast.Extent.Text.IndexOf('$mutex = [Threading.Mutex]')
  }
}
