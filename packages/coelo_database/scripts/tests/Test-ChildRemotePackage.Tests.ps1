$harnessPath = Join-Path $PSScriptRoot '..\Test-ChildRemotePackage.ps1'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$manifestPath = Join-Path $repositoryRoot 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-package-auth-base.sha256'
$payloadPath = Join-Path $repositoryRoot 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-remote-apply-migration.sql'
$validProjectId = 'coelo_safe_1234567890abcdef1234567890abc'
$sentinel = 'CHILD_PACKAGE_TEST_DOCKER_SENTINEL'
$fixtureRoots = [Collections.Generic.List[string]]::new()

function New-HarnessFixture(
  [ValidateSet('None','MissingMigration','DriftedMigration','ExtraMigration','PayloadCrLf','PayloadBom','PayloadDrift')]
  [string]$Mutation = 'None',
  [ValidateSet('Valid','Missing','Wrong')]
  [string]$Marker = 'Valid'
) {
  $root = Join-Path ([IO.Path]::GetTempPath()) ('child-package-guard-' + [guid]::NewGuid().ToString('N'))
  $fixtureRoots.Add($root)
  $scripts = Join-Path $root 'packages\coelo_database\scripts'
  $notes = Join-Path $root 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes'
  $project = Join-Path $root $validProjectId
  $migrations = Join-Path $project 'supabase\migrations'
  New-Item -ItemType Directory -Path $scripts,$notes,$migrations -Force | Out-Null

  $text = [IO.File]::ReadAllText($harnessPath)
  $text = $text.Replace(
    '$dockerPath = (Get-Command docker -ErrorAction Stop).Source',
    '$dockerPath = ''docker-must-not-run'''
  )
  $inspectLine = '$running = @(& $dockerPath inspect --format ''{{.State.Running}}'' $containerName 2>$null)'
  if (($text.Split(@($inspectLine), [StringSplitOptions]::None).Count - 1) -ne 1) {
    throw 'test fixture could not identify the Docker inspection boundary'
  }
  $text = $text.Replace($inspectLine, "throw '$sentinel'`n$inspectLine")
  $fixtureHarness = Join-Path $scripts 'Test-ChildRemotePackage.ps1'
  [IO.File]::WriteAllText($fixtureHarness, $text, [Text.UTF8Encoding]::new($false))

  Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $notes 'child-package-auth-base.sha256')
  $payloadBytes = [IO.File]::ReadAllBytes($payloadPath)
  if ($Mutation -eq 'PayloadCrLf') {
    $payloadText = [Text.UTF8Encoding]::new($false, $true).GetString($payloadBytes)
    $payloadLf = $payloadText.Replace("`r`n", "`n").Replace("`r", "`n")
    $payloadBytes = [Text.UTF8Encoding]::new($false).GetBytes($payloadLf.Replace("`n", "`r`n"))
  }
  elseif ($Mutation -eq 'PayloadBom') {
    $payloadBytes = @([byte]0xef,[byte]0xbb,[byte]0xbf) + $payloadBytes
  }
  elseif ($Mutation -eq 'PayloadDrift') {
    $payloadBytes = $payloadBytes + [Text.Encoding]::UTF8.GetBytes("`n-- drift")
  }
  [IO.File]::WriteAllBytes((Join-Path $notes 'child-remote-apply-migration.sql'), $payloadBytes)

  $entries = @(Get-Content -LiteralPath $manifestPath | ForEach-Object {
    if ($_ -match '^[0-9a-f]{64}  (.+\.sql)$') { $Matches[1] }
  })
  foreach ($name in $entries) {
    $source = Join-Path $repositoryRoot "packages\coelo_database\migrations\$name"
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
      $source = Join-Path $repositoryRoot "packages\coelo_database\replay\$name"
    }
    Copy-Item -LiteralPath $source `
      -Destination (Join-Path $migrations $name)
  }
  if ($Mutation -eq 'MissingMigration') {
    Remove-Item -LiteralPath (Join-Path $migrations $entries[-1]) -Force
  }
  elseif ($Mutation -eq 'DriftedMigration') {
    [IO.File]::AppendAllText((Join-Path $migrations $entries[0]), "`n-- drift")
  }
  elseif ($Mutation -eq 'ExtraMigration') {
    [IO.File]::WriteAllText(
      (Join-Path $migrations '20260901200207_extra.sql'),
      'select 1;',
      [Text.UTF8Encoding]::new($false)
    )
  }

  if ($Marker -ne 'Missing') {
    $markerValue = if ($Marker -eq 'Valid') { $validProjectId } else { 'coelo_safe_wrong' }
    [IO.File]::WriteAllText(
      (Join-Path $project '.coelo-safe-replay'), $markerValue, [Text.UTF8Encoding]::new($false)
    )
  }
  [pscustomobject]@{ Harness = $fixtureHarness; Project = $project }
}

function Get-HarnessFailure($Fixture, [string]$ProjectId = $validProjectId) {
  try {
    & $Fixture.Harness -ProjectRoot $Fixture.Project -ProjectId $ProjectId
    return $null
  }
  catch {
    return $_.Exception.Message
  }
}

Describe 'CHILD remote package offline guards' {
  It 'package.guard.parse parses and keeps cleanup command boundaries separate' {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path $harnessPath), [ref]$tokens, [ref]$errors
    )
    @($errors).Count | Should Be 0
    $cleanupCalls = @($ast.FindAll({
      param($node)
      $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Invoke-OwnedPsql' -and
        $node.Extent.Text -match 'fixtureCleanupSql'
    }, $true))
    $cleanupCalls.Count | Should Be 2
    foreach ($call in $cleanupCalls) { $call.CommandElements.Count | Should Be 3 }
  }

  It 'package.guard.project-id rejects an invalid generated identity before Docker' {
    $fixture = New-HarnessFixture
    $failure = Get-HarnessFailure $fixture 'unsafe-project'
    $failure | Should Not Be $null
    $failure | Should Match 'ProjectId'
    $failure | Should Not Match $sentinel
  }

  It 'package.guard.marker rejects missing and incorrect ownership before Docker' {
    foreach ($marker in @('Missing','Wrong')) {
      $fixture = New-HarnessFixture -Marker $marker
      Get-HarnessFailure $fixture | Should Be 'CHILD package local requires the owned disposable replay project'
    }
  }

  It 'package.guard.auth-base rejects missing, drifted and extra migrations before Docker' {
    foreach ($case in @(
      @{ Mutation='MissingMigration'; Error='CHILD package local AuthOnly migration count differs from the reviewed base' },
      @{ Mutation='DriftedMigration'; Error='CHILD package local AuthOnly migration order or normalized hash drifted' },
      @{ Mutation='ExtraMigration'; Error='CHILD package local AuthOnly migration count differs from the reviewed base' }
    )) {
      $fixture = New-HarnessFixture -Mutation $case.Mutation
      Get-HarnessFailure $fixture | Should Be $case.Error
    }
  }

  It 'package.guard.payload-crlf normalizes CRLF and reaches the Docker sentinel' {
    $fixture = New-HarnessFixture -Mutation PayloadCrLf
    Get-HarnessFailure $fixture | Should Be $sentinel
  }

  It 'package.guard.payload-bom rejects BOM before Docker' {
    $fixture = New-HarnessFixture -Mutation PayloadBom
    Get-HarnessFailure $fixture | Should Be 'CHILD package local payload must not contain a BOM'
  }

  It 'package.guard.payload-drift rejects changed normalized bytes before Docker' {
    $fixture = New-HarnessFixture -Mutation PayloadDrift
    Get-HarnessFailure $fixture | Should Be 'CHILD package local payload differs from the reviewed LF candidate'
  }

  It 'package.guard.external-boundary keeps all tested failures before process creation' {
    $text = [IO.File]::ReadAllText($harnessPath)
    $payloadGuard = $text.IndexOf('payload differs from the reviewed LF candidate')
    $inspect = $text.IndexOf('$running = @(& $dockerPath inspect')
    $psqlStart = $text.IndexOf('$process.Start()')
    $payloadGuard | Should BeGreaterThan -1
    $inspect | Should BeGreaterThan $payloadGuard
    $psqlStart | Should BeGreaterThan -1
  }

  AfterAll {
    foreach ($root in $fixtureRoots) {
      $resolved = [IO.Path]::GetFullPath($root)
      $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
        [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar
      ) + [IO.Path]::DirectorySeparatorChar
      $leaf = Split-Path -Leaf $resolved
      if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
          $leaf -cnotmatch '^child-package-guard-[a-f0-9]{32}$') {
        throw 'test fixture cleanup path escaped its owned TEMP boundary'
      }
      $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'test fixture cleanup root is a reparse point'
      }
      Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
  }
}
