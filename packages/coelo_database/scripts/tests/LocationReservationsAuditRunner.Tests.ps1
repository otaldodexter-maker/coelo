$wrapperPath = Join-Path $PSScriptRoot '..\Invoke-SafeLocalMigrationReplay.ps1'

Describe 'Location reservations audit nominal TAP gate' {
  It 'requires precisely the reservation TAP before allocating resources' {
    $tokens=$null; $errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($wrapperPath,[ref]$tokens,[ref]$errors)
    @($errors).Count | Should Be 0
    $guards=@($ast.FindAll({param($node)
      $node -is [Management.Automation.Language.IfStatementAst] -and
      $node.Extent.Text.Contains("throw 'Location reservation audit proof requires exactly the nominal reservation TAP'")
    },$true))
    $guards.Count | Should Be 1
    $RunLocationReservationsAuditAuthorization=$true
    $expectedReservationTap='C:\nominal\superadmin_location_reservations_v2_test.sql'
    $condition=[scriptblock]::Create($guards[0].Clauses[0].Item1.Extent.Text)
    $resolvedTestPaths=@(); (& $condition) | Should Be $true
    $resolvedTestPaths=@('C:\nominal\other.sql'); (& $condition) | Should Be $true
    $resolvedTestPaths=@($expectedReservationTap,$expectedReservationTap); (& $condition) | Should Be $true
    $resolvedTestPaths=@($expectedReservationTap); (& $condition) | Should Be $false
    $resolvedTestPaths=@($expectedReservationTap.ToUpperInvariant()); (& $condition) | Should Be $false
    $RunLocationReservationsAuditAuthorization=$false
    $resolvedTestPaths=@(); (& $condition) | Should Be $false
    $guards[0].Extent.StartOffset | Should BeLessThan $ast.Extent.Text.IndexOf('$mutex = [Threading.Mutex]')
  }
}
