$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourceName = '20260813155005_forms_definition_and_capabilities.sql'
$converterRelative = 'replay\profiles\FReadDirectoryContractRedDerived\Convert-FReadFormsDefinitionForLocalReplay.ps1'

function Get-FReadConversionTestHash([string]$Path) {
  $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($content)))).Replace('-', '').ToLowerInvariant()
  } finally { $sha.Dispose() }
}

Describe 'Nominal local Forms CASE materialization' {
  BeforeEach {
    $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $fixturePackageRoot = Join-Path $fixtureRoot 'repository\packages\coelo_database'
    $fixtureMigrationRoot = Join-Path $fixturePackageRoot 'migrations'
    $converterPath = Join-Path $fixturePackageRoot $converterRelative
    $sourcePath = Join-Path $fixtureMigrationRoot $sourceName
    $destination = Join-Path $fixtureRoot 'prepared'
    foreach ($path in @($fixtureMigrationRoot, (Split-Path -Parent $converterPath), $destination)) {
      New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path (Join-Path $sourcePackageRoot 'migrations') $sourceName) -Destination $sourcePath
    if (Test-Path -LiteralPath (Join-Path $sourcePackageRoot $converterRelative)) {
      Copy-Item -LiteralPath (Join-Path $sourcePackageRoot $converterRelative) -Destination $converterPath
    }
    $outputPath = Join-Path $destination $sourceName
  }

  It 'preserves all source bytes and inserts only four parentheses with <ending> line endings' -TestCases @(
    @{ ending = 'LF' }, @{ ending = 'CRLF' }
  ) {
    param($ending)
    $text = [IO.File]::ReadAllText($sourcePath).Replace("`r`n", "`n")
    if ($ending -eq 'CRLF') { $text = $text.Replace("`n", "`r`n") }
    [IO.File]::WriteAllText($sourcePath, $text, [Text.UTF8Encoding]::new($false))
    $before = [IO.File]::ReadAllBytes($sourcePath)
    $receipt = & $converterPath -DestinationMigrationsRoot $destination
    $after = [IO.File]::ReadAllBytes($outputPath)
    $after.Length | Should Be ($before.Length + 4)
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($sourcePath)) | Should Be ([Convert]::ToBase64String($before))
    $sourceOffset = 0
    $inserted = [Collections.Generic.List[byte]]::new()
    foreach ($targetByte in $after) {
      if ($sourceOffset -lt $before.Length -and $targetByte -eq $before[$sourceOffset]) {
        $sourceOffset++
      } else { $inserted.Add($targetByte) }
    }
    $sourceOffset | Should Be $before.Length
    [Text.Encoding]::ASCII.GetString($inserted.ToArray()) | Should Be '()()'
    (Get-FReadConversionTestHash $sourcePath) | Should Be '3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36'
    (Get-FReadConversionTestHash $outputPath) | Should Be '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe'
    $receipt.SourceSha256CrlfUtf8 | Should Be '3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36'
    $receipt.DerivedSha256CrlfUtf8 | Should Be '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe'
    $receipt.InsertedCharacterCount | Should Be 4
    @(Get-ChildItem -LiteralPath $destination -File).Count | Should Be 1
  }

  It 'rejects source drift outside the exact CASE fragments before writing' {
    [IO.File]::AppendAllText($sourcePath, "`n-- unreviewed drift`n")
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'source hash mismatch'
    Test-Path -LiteralPath $outputPath | Should Be $false
  }

  It 'rejects a missing exact <kind> CASE fragment' -TestCases @(
    @{ kind = 'decimal' }, @{ kind = 'photo' }
  ) {
    param($kind)
    $text = [IO.File]::ReadAllText($sourcePath).Replace("case when p_kind = '$kind'", "case when p_kind  = '$kind'")
    [IO.File]::WriteAllText($sourcePath, $text)
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'expected exactly one occurrence'
    Test-Path -LiteralPath $outputPath | Should Be $false
  }

  It 'rejects duplicate exact <kind> CASE fragments' -TestCases @(
    @{ kind = 'decimal' }, @{ kind = 'photo' }
  ) {
    param($kind)
    $lines = [IO.File]::ReadAllLines($sourcePath)
    $fragment = if ($kind -eq 'decimal') { $lines[104..106] -join "`n" } else { $lines[144..145] -join "`n" }
    [IO.File]::AppendAllText($sourcePath, "`n" + $fragment + "`n")
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'expected exactly one occurrence'
    Test-Path -LiteralPath $outputPath | Should Be $false
  }

  It 'rejects an incorrect derived hash pin before writing' {
    $text = [IO.File]::ReadAllText($converterPath).Replace(
      '06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe', ('0' * 64))
    [IO.File]::WriteAllText($converterPath, $text)
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'derived hash mismatch'
    Test-Path -LiteralPath $outputPath | Should Be $false
  }

  It 'never overwrites an existing destination file' {
    [IO.File]::WriteAllText($outputPath, 'preserve existing file')
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'destination already exists'
    [IO.File]::ReadAllText($outputPath) | Should Be 'preserve existing file'
  }

  It 'rejects a resolved destination inside the repository' {
    $inside = Join-Path $destination '..\repository\packages\coelo_database\migrations'
    { & $converterPath -DestinationMigrationsRoot $inside } | Should Throw 'outside the repository'
  }

  It 'rejects relative destinations' {
    { & $converterPath -DestinationMigrationsRoot '..\prepared' } | Should Throw 'absolute local path'
  }

  It 'rejects destinations outside the local temporary root' {
    $outside = Join-Path ([IO.Path]::GetPathRoot($TestDrive)) 'coelo-fread-outside-temp'
    { & $converterPath -DestinationMigrationsRoot $outside } | Should Throw 'below the local temporary root'
  }

  It 'rejects network destinations' {
    { & $converterPath -DestinationMigrationsRoot '\\unapproved-host\share\prepared' } | Should Throw 'absolute local path'
  }

  It 'rejects <surface> reparse metadata before reading or writing' -TestCases @(
    @{ surface = 'source' }, @{ surface = 'source ancestor' },
    @{ surface = 'destination' }, @{ surface = 'destination ancestor' }
  ) {
    param($surface)
    $isSource = $surface.StartsWith('source')
    $guardedPath = if ($isSource) { $sourcePath } else { $destination }
    $isAncestor = $surface.EndsWith('ancestor')
    $parentMetadata = [pscustomobject]@{
      FullName = (Split-Path -Parent $guardedPath); PSIsContainer = $true; Parent = $null
      Attributes = [IO.FileAttributes]::ReparsePoint
    }
    Mock Get-Item {
      [pscustomobject]@{
        FullName = $guardedPath; PSIsContainer = -not $isSource
        Parent = $parentMetadata; Directory = $parentMetadata
        Attributes = if ($isAncestor) { [IO.FileAttributes]::Normal } else { [IO.FileAttributes]::ReparsePoint }
      }
    } -ParameterFilter { $LiteralPath -eq $guardedPath }
    { & $converterPath -DestinationMigrationsRoot $destination } | Should Throw 'reparse point'
    Test-Path -LiteralPath $outputPath | Should Be $false
  }
}
