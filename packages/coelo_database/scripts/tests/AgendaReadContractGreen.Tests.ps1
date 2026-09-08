$sourcePackageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$candidateName = '20260908045531_superadmin_agenda_read_v2.sql'

function Get-AgendaGreenTestHash([string]$Path, [switch]$Raw) {
  $bytes = if ($Raw) { [IO.File]::ReadAllBytes($Path) } else {
    [Text.UTF8Encoding]::new($false).GetBytes([IO.File]::ReadAllText($Path).
      Replace("`r`n","`n").Replace("`r","`n").Replace("`n","`r`n"))
  }
  $sha=[Security.Cryptography.SHA256]::Create()
  try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function New-AgendaGreenTestFixture([string]$Root) {
  $dir=Join-Path $Root ([guid]::NewGuid().ToString('N'))
  $package=Join-Path $dir 'repository\packages\coelo_database'
  foreach($folder in @('migrations','replay','scripts','supabase')) {
    $null=New-Item -ItemType Directory -Path (Join-Path $package $folder) -Force
  }
  Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'migrations') -File -Filter '*.sql' |
    Copy-Item -Destination (Join-Path $package 'migrations')
  Get-ChildItem -LiteralPath (Join-Path $sourcePackageRoot 'replay') |
    Copy-Item -Destination (Join-Path $package 'replay') -Recurse
  foreach($name in @('Invoke-SafeLocalMigrationReplay.ps1','Prepare-SafeMigrationReplay.ps1')) {
    Copy-Item -LiteralPath (Join-Path $sourcePackageRoot "scripts\$name") -Destination (Join-Path $package 'scripts')
  }
  $invoke=Join-Path $package 'scripts\Invoke-SafeLocalMigrationReplay.ps1'
  $text=[IO.File]::ReadAllText($invoke)
  $anchor='$mutex = [Threading.Mutex]::new'
  if(-not $text.Contains($anchor)){throw 'Agenda Green fixture requires the pre-Docker mutex anchor'}
  [IO.File]::WriteAllText($invoke,$text.Replace($anchor,"throw 'Agenda Green fixture before mutex and Docker'`n"+$anchor))
  [IO.File]::WriteAllText((Join-Path $package 'supabase\config.toml'),'project_id = "agenda_green_fixture"')
  $destination=Join-Path $dir 'prepared'
  $null=New-Item -ItemType Directory -Path $destination
  [pscustomobject]@{
    Package=$package;Migrations=(Join-Path $package 'migrations');Replay=(Join-Path $package 'replay')
    Resolver=(Join-Path $package 'replay\profiles\AgendaReadContractGreen\Resolve-AgendaReadContractGreen.ps1')
    Descriptor=(Join-Path $package 'replay\profiles\AgendaReadContractGreen\profile.json')
    ParentResolver=(Join-Path $package 'replay\profiles\AgendaReadContractRed\Resolve-AgendaReadContractRed.ps1')
    ParentDescriptor=(Join-Path $package 'replay\profiles\AgendaReadContractRed\profile.json')
    Manifest=(Join-Path $package 'replay\foundation-migrations.sha256')
    Prepare=(Join-Path $package 'scripts\Prepare-SafeMigrationReplay.ps1');Invoke=$invoke;Destination=$destination
  }
}

Describe 'Closed Agenda GREEN54 resolver' -Tag 'AgendaGreenResolver' {
  BeforeEach {
    $fx=New-AgendaGreenTestFixture $TestDrive
    $aggGuardedPath=$null
  }
  It 'inherits the exact RED53 selection and appends only the approved canonical migration' {
    $parent=& $fx.ParentResolver
    $green=& $fx.Resolver
    @($green).Count | Should Be 1
    $green.Canonical.Count | Should Be 52
    $green.Preflight.Count | Should Be 2
    $green.Additional.Count | Should Be 7
    $green.ManifestHash | Should Be $parent.ManifestHash
    ($green.Canonical[0..50].FullName -join '|') | Should Be ($parent.Canonical.FullName -join '|')
    ($green.Preflight.FullName -join '|') | Should Be ($parent.Preflight.FullName -join '|')
    ($green.Additional[0..5].FullName -join '|') | Should Be ($parent.Additional.FullName -join '|')
    $all=@(@($green.Canonical)+@($green.Preflight)|Sort-Object Name)
    $all.Count | Should Be 54
    @($all.Name | ForEach-Object {$_.Substring(0,14)} | Sort-Object -Unique).Count | Should Be 54
    $all[-1].Name | Should Be $candidateName
    $green.Canonical[-1].Name | Should Be $candidateName
    $green.Additional[-1].Name | Should Be $candidateName
    (Get-AgendaGreenTestHash $all[-1].FullName) | Should Be '15a490013e556d4a271dc2e026dc564737f0bf078c25a9916e5276c3db57f4a9'
    foreach($file in $all){($file -is [IO.FileInfo]) | Should Be $true}
    $all[28].Name | Should Be '20260811151253_assert_function_execute_preflight.sql'
    $all[41].Name | Should Be '20260811215452_access_profile_labels_replay_bridge.sql'
    @(Get-ChildItem -LiteralPath $fx.Destination -Force).Count | Should Be 0
  }
  It 'rejects a non-nominal target before calling its parent' {
    { & $fx.Resolver -TargetVersion 20260901200206 } | Should Throw 'AgendaReadContractGreen requires target 20260908045531'
  }
  It 'rejects closed descriptor drift in <field>' -TestCases @(
    @{field='target'},@{field='name'},@{field='hash'},@{field='parent'},@{field='count'},@{field='bridge'},@{field='path'}
  ) {
    param($field)
    $d=Get-Content -LiteralPath $fx.Descriptor -Raw -ErrorAction Stop | ConvertFrom-Json
    switch($field){
      target {$d.target_version='20260901200206'}
      name {$d.canonical_addition.file='20260908045531_wrong.sql'}
      hash {$d.canonical_addition.sha256_crlf_utf8='0'*64}
      parent {$d.base.resolver_sha256_crlf_utf8='0'*64}
      count {$d.planned_counts.canonical=53}
      bridge {$d.extra_bridges=@('unapproved.sql')}
      path {$d.canonical_addition.file='..\escape.sql'}
    }
    [IO.File]::WriteAllText($fx.Descriptor,($d|ConvertTo-Json -Depth 8))
    { & $fx.Resolver } | Should Throw 'AgendaReadContractGreen descriptor hash mismatch'
  }
  It 'rejects parent resolver or descriptor drift before invoking it' -TestCases @(@{kind='resolver'},@{kind='descriptor'}) {
    param($kind)
    $path=if($kind -eq 'resolver'){$fx.ParentResolver}else{$fx.ParentDescriptor}
    [IO.File]::AppendAllText($path,[Environment]::NewLine+'# parent drift')
    { & $fx.Resolver } | Should Throw 'AgendaReadContractGreen parent pin mismatch'
  }
  It 'preserves parent rejection of changed baseline, preflight, prerequisite and manifest' -TestCases @(
    @{kind='baseline'},@{kind='preflight'},@{kind='prerequisite'},@{kind='manifest'}
  ) {
    param($kind)
    $parent=& $fx.ParentResolver
    $path=switch($kind){
      baseline {$parent.Canonical[0].FullName}
      preflight {$parent.Preflight[0].FullName}
      prerequisite {$parent.Additional[0].FullName}
      manifest {$fx.Manifest}
    }
    [IO.File]::AppendAllText($path,[Environment]::NewLine+'-- drift')
    { & $fx.Resolver } | Should Throw 'hash mismatch'
  }
  It 'rejects missing, renamed or changed candidate bytes' -TestCases @(@{kind='missing'},@{kind='renamed'},@{kind='changed'}) {
    param($kind)
    $path=Join-Path $fx.Migrations $candidateName
    if($kind -eq 'changed'){[IO.File]::AppendAllText($path,[Environment]::NewLine+'-- drift')}
    elseif($kind -eq 'renamed'){Move-Item -LiteralPath $path -Destination (Join-Path $fx.Migrations '20260908045531_wrong.sql')}
    else{[IO.File]::Delete($path)}
    $expected=if($kind -eq 'changed'){'AgendaReadContractGreen candidate hash mismatch'}else{'AgendaReadContractGreen input is missing'}
    { & $fx.Resolver } | Should Throw $expected
  }
  It 'rejects a <dependency> <kind> reparse before reading or invoking it' -TestCases @(
    @{dependency='descriptor';kind='file'},@{dependency='descriptor';kind='ancestor'},
    @{dependency='parent';kind='file'},@{dependency='parent';kind='ancestor'},
    @{dependency='candidate';kind='file'},@{dependency='candidate';kind='ancestor'}
  ) {
    param($dependency,$kind)
    $aggGuardedPath=switch($dependency){descriptor{$fx.Descriptor};parent{$fx.ParentResolver};candidate{Join-Path $fx.Migrations $candidateName}}
    $aggFakeParent=[pscustomobject]@{
      FullName=(Split-Path -Parent $aggGuardedPath);PSIsContainer=$true;Parent=$null
      Attributes=$(if($kind -eq 'ancestor'){[IO.FileAttributes]::ReparsePoint}else{[IO.FileAttributes]::Directory})
    }
    $aggFakeFile=[pscustomobject]@{
      FullName=$aggGuardedPath;PSIsContainer=$false;Directory=$aggFakeParent
      Attributes=$(if($kind -eq 'file'){[IO.FileAttributes]::ReparsePoint}else{[IO.FileAttributes]::Normal})
    }
    Mock Get-Item {$aggFakeFile} -ParameterFilter {$LiteralPath -eq $aggGuardedPath}
    { & $fx.Resolver } | Should Throw 'reparse point'
  }
  It 'continues to reject an unapproved third replay SQL through its parent' {
    [IO.File]::WriteAllText((Join-Path $fx.Replay '20260908040000_unapproved.sql'),'-- fixture only')
    { & $fx.Resolver } | Should Throw 'exactly two inherited preflights'
  }
}

Describe 'Closed Agenda GREEN54 entrypoints' -Tag 'AgendaGreenEntrypoints' {
  BeforeEach {
    $fx=New-AgendaGreenTestFixture $TestDrive
    $aggGuardedPath=$null
  }
  It 'prepares exactly54 byte-identical SQL inputs with honest counts' {
    $selected=& $fx.Resolver
    $output=& $fx.Prepare -DestinationMigrationsRoot $fx.Destination -NominalProfile AgendaReadContractGreen
    $files=@(Get-ChildItem -LiteralPath $fx.Destination -File | Sort-Object Name)
    $files.Count | Should Be 54
    $files[-1].Name | Should Be $candidateName
    $output | Should Match '52 canonical \+ 2 preflight'
    $output | Should Match 'profile=AgendaReadContractGreen; additional=7'
    $expected=@(@($selected.Canonical)+@($selected.Preflight)|Sort-Object Name)
    for($i=0;$i -lt 54;$i++){
      $files[$i].Name | Should Be $expected[$i].Name
      (Get-AgendaGreenTestHash $files[$i].FullName -Raw) | Should Be (Get-AgendaGreenTestHash $expected[$i].FullName -Raw)
    }
  }
  It 'accepts only the nominal target and stops at the pre-Docker fixture sentinel' {
    { & $fx.Invoke -TargetVersion 20260908045531 -NominalProfile AgendaReadContractGreen } |
      Should Throw 'Agenda Green fixture before mutex and Docker'
  }
  It 'rejects the old target before the fixture sentinel' {
    { & $fx.Invoke -TargetVersion 20260901200206 -NominalProfile AgendaReadContractGreen } |
      Should Throw 'AgendaReadContractGreen requires target 20260908045531'
  }
  It 'rejects mixing <mode> before staging or Docker' -TestCases @(
    @{mode='AuthOnly'},@{mode='FoundationOnly'},@{mode='AdditionalMigration'}
  ) {
    param($mode)
    $parameters=@{NominalProfile='AgendaReadContractGreen'}
    $parameters[$mode]=if($mode -eq 'AdditionalMigration'){'historical.sql|'+('0'*64)}else{$true}
    { & $fx.Prepare -DestinationMigrationsRoot $fx.Destination @parameters } | Should Throw 'nominal replay cannot be combined'
    { & $fx.Invoke -TargetVersion 20260908045531 @parameters } | Should Throw 'nominal replay cannot be combined'
    @(Get-ChildItem -LiteralPath $fx.Destination -Force).Count | Should Be 0
  }
  It 'rejects incompatible runner mode <mode>' -TestCases @(@{mode='RunAuthLifecycle'},@{mode='RunActivityV2Concurrency'}) {
    param($mode)
    $parameters=@{NominalProfile='AgendaReadContractGreen'}
    $parameters[$mode]=$true
    { & $fx.Invoke -TargetVersion 20260908045531 @parameters } | Should Throw 'nominal replay cannot be combined'
  }
  It 'keeps descriptor drift ahead of copying and the Invoke sentinel' {
    [IO.File]::AppendAllText($fx.Descriptor,[Environment]::NewLine+' ')
    { & $fx.Prepare -DestinationMigrationsRoot $fx.Destination -NominalProfile AgendaReadContractGreen } |
      Should Throw 'AgendaReadContractGreen descriptor hash mismatch'
    { & $fx.Invoke -TargetVersion 20260908045531 -NominalProfile AgendaReadContractGreen } |
      Should Throw 'AgendaReadContractGreen descriptor hash mismatch'
    @(Get-ChildItem -LiteralPath $fx.Destination -Force).Count | Should Be 0
  }
}
