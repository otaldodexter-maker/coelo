[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RepositoryRoot)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$proposal=Join-Path $repo 'packages/coelo_database/replay/profiles/SafetyInternalReads53'
$manifest=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest-after.json') -Raw | ConvertFrom-Json
$descriptor=Get-Content -LiteralPath (Join-Path $proposal 'profile.json') -Raw | ConvertFrom-Json
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$sandbox=Join-Path $tempBase ('coelo_safety_profile_'+[guid]::NewGuid().ToString('N'))
$isolated=Join-Path $sandbox 'repository'
$destination=Join-Path $sandbox 'materialized'
$resolverRelative='packages/coelo_database/replay/profiles/SafetyInternalReads53/Resolve-SafetyInternalReads53.ps1'
$prepareRelative='packages/coelo_database/scripts/Prepare-SafeMigrationReplay.ps1'
$invokeRelative='packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1'
$beforeHashes=@($prepareRelative,$invokeRelative | ForEach-Object {(Get-FileHash -LiteralPath (Join-Path $repo $_)).Hash})
$checks=[Collections.Generic.List[string]]::new()
function Copy-Input([string]$Relative) {
  $source=Join-Path $repo $Relative; $target=Join-Path $isolated $Relative
  $null=New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target)
  Copy-Item -LiteralPath $source -Destination $target
}
function Assert-Rejected([scriptblock]$Action,[string]$Expected) {
  $rejected=$false
  try {$null=& $Action} catch {if ($_.Exception.Message -notlike "*$Expected*") {throw}; $rejected=$true}
  if (-not $rejected) {throw "EXPECTED_REJECTION_MISSING: $Expected"}
  $checks.Add($Expected)
}
try {
  $null=New-Item -ItemType Directory -Path $isolated,$destination
  foreach ($entry in $manifest.ordered_sources) {Copy-Input $entry.path}
  Copy-Input $descriptor.base.manifest
  Copy-Input $descriptor.local_bridges[0].source_note
  Copy-Input $descriptor.local_bridges[0].approved_helper_source
  Copy-Input $prepareRelative; Copy-Input $invokeRelative
  $profileTarget=Split-Path -Parent (Join-Path $isolated $resolverRelative)
  $null=New-Item -ItemType Directory -Force -Path $profileTarget
  Copy-Item -LiteralPath (Join-Path $proposal 'profile.json') -Destination $profileTarget
  Copy-Item -LiteralPath (Join-Path $proposal 'Resolve-SafetyInternalReads53.ps1') -Destination $profileTarget
  foreach ($relative in @($resolverRelative,$prepareRelative,$invokeRelative)) {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $isolated $relative),[ref]$tokens,[ref]$errors)
    if ($errors.Count) {throw "POWERSHELL_PARSE_FAILED $relative"}
  }
  $checks.Add('three live PowerShell files parse')
  $resolver=Join-Path $isolated $resolverRelative
  $selection=& $resolver
  if (@($selection.Canonical).Count -ne 50 -or @($selection.Preflight).Count -ne 2 -or @($selection.LocalBridges).Count -ne 1 -or @($selection.Additional).Count -ne 5) {throw 'SELECTION_COUNTS_MISMATCH'}
  $checks.Add('50 canonical plus 2 preflight plus 1 inherited bridge')
  Assert-Rejected {& $resolver -TargetVersion '20260908051500'} 'requires target 20260909193000'
  $profilePath=Join-Path $profileTarget 'profile.json'
  $profileBytes=[IO.File]::ReadAllBytes($profilePath)
  try {
    [IO.File]::AppendAllText($profilePath,' ')
    Assert-Rejected {& $resolver} 'descriptor hash mismatch'
  } finally {[IO.File]::WriteAllBytes($profilePath,$profileBytes)}
  $guardPath=Join-Path $isolated 'packages/coelo_database/migrations/20260909193000_d04_child_safety_internal_reads.sql'
  $guardBytes=[IO.File]::ReadAllBytes($guardPath)
  try {
    [IO.File]::AppendAllText($guardPath,' ')
    Assert-Rejected {& $resolver} 'input hash mismatch'
  } finally {[IO.File]::WriteAllBytes($guardPath,$guardBytes)}
  $null=& (Join-Path $isolated $prepareRelative) -NominalProfile SafetyInternalReads53 -DestinationMigrationsRoot $destination
  $actual=@(Get-ChildItem -LiteralPath $destination -File -Filter '*.sql' | Sort-Object Name)
  $expected=@($manifest.ordered_sources | ForEach-Object {[IO.Path]::GetFileName($_.path)} | Sort-Object)
  if ($actual.Count -ne 53 -or @(Compare-Object $expected @($actual.Name)).Count) {throw 'EXACT_53_SELECTION_MISMATCH'}
  foreach ($entry in $manifest.ordered_sources) {
    $actualFile=Join-Path $destination ([IO.Path]::GetFileName($entry.path))
    if ((Get-FileHash -LiteralPath $actualFile).Hash.ToLowerInvariant() -cne $entry.sha256_bytes) {throw "BYTE_COPY_MISMATCH $($entry.path)"}
  }
  $checks.Add('all 53 output files exactly match manifest-after names and bytes')
  $afterHashes=@($prepareRelative,$invokeRelative | ForEach-Object {(Get-FileHash -LiteralPath (Join-Path $repo $_)).Hash})
  if (@(Compare-Object $beforeHashes $afterHashes).Count) {throw 'RESERVED_WRAPPER_CHANGED'}
  $checks.Add('reserved wrappers unchanged')
} finally {
  $resolvedSandbox=[IO.Path]::GetFullPath($sandbox)
  if (-not $resolvedSandbox.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path -Leaf $resolvedSandbox) -notmatch '^coelo_safety_profile_[a-f0-9]{32}$') {throw 'UNSAFE_SANDBOX_CLEANUP_PATH'}
  if (Test-Path -LiteralPath $resolvedSandbox) {Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force}
}
$result=[pscustomobject]@{Status='PASS';P=$checks.Count;F=0;SqlExecuted=$false;DockerExecuted=$false;Canonical=50;Preflight=2;Bridge=1;Total=53;Checks=@($checks.ToArray());SandboxRemoved=(-not (Test-Path -LiteralPath $sandbox))}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'serialized-profile-proof.json'),($result | ConvertTo-Json -Depth 5)+"`n",[Text.UTF8Encoding]::new($false))
$result
