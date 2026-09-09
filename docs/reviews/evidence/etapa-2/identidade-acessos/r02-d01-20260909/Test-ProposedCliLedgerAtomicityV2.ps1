# source: Supabase CLI v2.116.0 legacy-migration-apply.ts; D00 r16
# status: proposed-only; not executed; requires D00 exclusive disposable SQL slot
# generated_at: 2026-09-09
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProjectRoot,
  [Parameter(Mandatory)][ValidatePattern('^coelo_safe_[a-f0-9]{29}$')][string]$ProjectId,
  [switch]$ExecuteInAuthorizedLocalSlot
)
$ErrorActionPreference = 'Stop'
function Invoke-CapturedPinnedCli([string[]]$CommandArgs) {
  $previousPreference = $ErrorActionPreference
  try {
    # Windows PowerShell turns redirected native stderr into ErrorRecords.
    # Keep expected CLI failure observable without aborting before its exit code.
    $ErrorActionPreference = 'Continue'
    $captured = @(& npx.cmd --offline supabase@2.116.0 @CommandArgs 2>&1)
    $nativeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  [pscustomobject]@{
    ExitCode = $nativeExitCode
    Output = ($captured | Out-String).Trim()
    StandardOutput = ($captured | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] } | Out-String).Trim()
  }
}
if (!$ExecuteInAuthorizedLocalSlot) { throw 'D00 local qualification slot required' }
$root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
$expected = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) $ProjectId)).TrimEnd('\')
if ($root -cne $expected) { throw 'Not the exact disposable TEMP project' }
$item = Get-Item -LiteralPath $root -Force
while ($null -ne $item) {
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse ancestor denied' }
  $item = $item.Parent
}
foreach ($item in Get-ChildItem -LiteralPath $root -Force -Recurse) {
  if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse tree denied' }
}
$marker = Join-Path $root '.coelo-safe-replay'
if ((Get-Content -LiteralPath $marker -Raw) -cne $ProjectId) { throw 'Project marker mismatch' }
$config = Get-Content -LiteralPath (Join-Path $root 'supabase/config.toml') -Raw
if ($config -notmatch ('(?m)^project_id\s*=\s*"' + [regex]::Escape($ProjectId) + '"\s*$')) { throw 'Config identity mismatch' }
if (Test-Path -LiteralPath (Join-Path $root 'supabase/.temp/project-ref')) { throw 'Linked project denied' }
$migrations = Join-Path $root 'supabase/migrations'
if (!(Test-Path -LiteralPath $migrations) -or @(Get-ChildItem -LiteralPath $migrations -Force).Count) {
  throw 'Requires dedicated empty migration directory; never use product replay stack'
}
foreach ($key in @('SUPABASE_EXPERIMENTAL','SUPABASE_SERVICES_HOSTNAME','SUPABASE_PROJECT_ID','SUPABASE_DB_PORT','SUPABASE_DB_SHADOW_PORT','SUPABASE_ENV','SUPABASE_WORKDIR','SUPABASE_PROFILE','SUPABASE_DB_PASSWORD','DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','PGHOST','PGPORT','PGSERVICE','PGSERVICEFILE','SUPABASE_DB_URL')) {
  if (![string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key))) { throw 'Connection environment override denied' }
}
if (@(Get-ChildItem -LiteralPath $root -Force -Recurse -File | Where-Object { $_.Name -like '.env*' }).Count) {
  throw 'Project environment files denied'
}
$dbSections = [regex]::Matches($config,'(?ms)^\[db\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
if ($dbSections.Count -ne 1) { throw 'Unambiguous db section required' }
$ports = [regex]::Matches($dbSections[0].Groups['body'].Value,'(?m)^port\s*=\s*(?<port>[0-9]+)\s*(?:#.*)?$')
if ($ports.Count -ne 1 -or [int]$ports[0].Groups['port'].Value -lt 1024 -or [int]$ports[0].Groups['port'].Value -gt 65535) {
  throw 'Unambiguous local db port required'
}
$dbPort = $ports[0].Groups['port'].Value
# CLI hostname also follows the active Docker context. Inspect local context metadata
# before any daemon contact; only a Windows local named-pipe daemon is accepted.
$daemonEndpoint = (& docker context inspect --format '{{.Endpoints.docker.Host}}' 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $daemonEndpoint -notmatch '^npipe:/{2,4}\./pipe/[a-zA-Z0-9_.-]+$') {
  throw 'Local Windows Docker context required'
}
$versionResult = Invoke-CapturedPinnedCli @('--version')
if ($versionResult.ExitCode -ne 0 -or $versionResult.StandardOutput -cne '2.116.0') { throw 'Pinned CLI unavailable' }
$container = 'supabase_db_' + $ProjectId
$actualName = (& docker inspect --format '{{.Name}}' $container 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actualName -cne ('/' + $container)) { throw 'Exact local container absent' }
$bindingJson = & docker inspect --format '{{json .NetworkSettings.Ports}}' $container 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect owned database binding' }
$bindings = @((($bindingJson | Out-String) | ConvertFrom-Json).'5432/tcp')
if ($bindings.Count -lt 1 -or $bindings.Count -gt 2 -or @($bindings | Where-Object { $_.HostPort -cne $dbPort -or $_.HostIp -notin @('127.0.0.1','0.0.0.0','::','::1') }).Count -gt 0 -or
    @($bindings | Where-Object { $_.HostIp -in @('127.0.0.1','0.0.0.0') -and $_.HostPort -ceq $dbPort }).Count -ne 1) {
  throw 'CLI loopback port is not the exact owned database binding'
}
function Invoke-FixtureSql([string]$Sql, [ValidateSet('ledger-presence','ledger-readiness','probe-collision','probe-setup','rollback-check','drop-injection','commit-check','cleanup')][string]$Phase = 'ledger-readiness') {
  $previousPreference = $ErrorActionPreference
  try {
    # DROP TRIGGER IF EXISTS legitimately emits a NOTICE on stderr at cleanup.
    $ErrorActionPreference = 'Continue'
    $output = $Sql | & docker exec -i $container psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -v VERBOSITY=verbose -At 2>&1
    $nativeExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }
  if ($nativeExitCode -ne 0) {
    $state = 'UNKNOWN'
    # Inspect only the native ERROR message; never emit SQL, DETAIL, context or tokens.
    foreach ($record in @($output)) {
      $message = if ($record -is [Management.Automation.ErrorRecord]) { $record.Exception.Message } else { [string]$record }
      if ($message -match '(?m)^\s*(?:psql:[^\r\n]*?:\s*)?ERROR:\s+([0-9A-Z]{5}):' -and
          $Matches[1] -cin @('42P01','3F000','42501','42710','23505','P0001','55P03','57014','08006','08001','57P01')) {
        $state = $Matches[1]; break
      }
    }
    throw "Local fixture SQL failed; phase=$Phase; SQLSTATE=$state; raw output withheld"
  }
  return ($output | Out-String).Trim()
}
$version = '20990909000100'
$fixture = Join-Path $migrations ($version + '_d01_atomicity_fixture.sql')
$created = $false
try {
  # Empty reset need not create history. Bootstrap through the pinned CLI itself:
  # its committed history initialization precedes the deliberately failing batch.
  $presence = Invoke-FixtureSql "select to_regclass('supabase_migrations.schema_migrations') is not null;" -Phase 'ledger-presence'
  if ($presence -notin @('t','f')) { throw 'Ledger presence probe failed' }
  if ($presence -ceq 'f') {
    $bootstrap = Join-Path $migrations '20990909000000_d01_ledger_bootstrap.sql'
    if (Test-Path -LiteralPath $bootstrap) { throw 'Bootstrap path collision' }
    [IO.File]::WriteAllText($bootstrap, "do `$bootstrap`$ begin raise exception 'D01_BOOTSTRAP_EXPECTED_FAILURE'; end `$bootstrap`$;", [Text.UTF8Encoding]::new($false))
    $bootstrapResult = Invoke-CapturedPinnedCli @('--agent','no','db','push','--local','--skip-vault','--workdir',$root,'--yes')
    if ($bootstrapResult.ExitCode -eq 0 -or $bootstrapResult.Output -notmatch 'D01_BOOTSTRAP_EXPECTED_FAILURE') {
      throw 'Expected CLI bootstrap failure not witnessed; no manual ledger repair allowed'
    }
    # Only the owned fixture is removed; no history row is deleted or repaired.
    if ((Get-Item -LiteralPath $bootstrap).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Bootstrap reparse denied' }
    Remove-Item -LiteralPath $bootstrap -Force
  }
  # Require the resulting CLI-initialized empty ledger, including no bootstrap row.
  $ready = Invoke-FixtureSql "select count(*)=0 from supabase_migrations.schema_migrations;" -Phase 'ledger-readiness'
  if ($ready -cne 't') { throw 'Dedicated empty ledger required' }
  $absent = Invoke-FixtureSql "select to_regnamespace('d01_transport_probe') is null;" -Phase 'probe-collision'
  if ($absent -cne 't') { throw 'Probe namespace collision' }
  $null = Invoke-FixtureSql -Phase 'probe-setup' -Sql @'
create schema d01_transport_probe;
create function d01_transport_probe.reject_ledger() returns trigger language plpgsql as $$
begin
  if new.version = '20990909000100' then
    raise exception 'D01_FORCED_LEDGER_FAILURE';
  end if;
  return new;
end $$;
create trigger d01_transport_probe_reject before insert on supabase_migrations.schema_migrations
for each row execute function d01_transport_probe.reject_ledger();
'@
  $created = $true
  [IO.File]::WriteAllText($fixture, @'
set local lock_timeout = '5s';
set local statement_timeout = '30s';
select pg_catalog.pg_advisory_xact_lock(20990909000100);
do $fixture$ begin
  create table d01_transport_probe.committed_together(id integer primary key);
end $fixture$;
'@, [Text.UTF8Encoding]::new($false))
  $failedResult = Invoke-CapturedPinnedCli @('--agent','no','db','push','--local','--skip-vault','--workdir',$root,'--yes')
  if ($failedResult.ExitCode -eq 0 -or $failedResult.Output -notmatch 'D01_FORCED_LEDGER_FAILURE') {
    throw 'Expected exact ledger injection failure was not witnessed'
  }
  $rolledBack = Invoke-FixtureSql "select to_regclass('d01_transport_probe.committed_together') is null and not exists(select 1 from supabase_migrations.schema_migrations where version='$version');" -Phase 'rollback-check'
  if ($rolledBack -cne 't') { throw 'DDL/ledger rollback atomicity FAIL' }
  Write-Output 'CLI_LEDGER_FAILURE_ROLLBACK_PASS'
  $null = Invoke-FixtureSql 'drop trigger d01_transport_probe_reject on supabase_migrations.schema_migrations;' -Phase 'drop-injection'
  $controlResult = Invoke-CapturedPinnedCli @('--agent','no','db','push','--local','--skip-vault','--workdir',$root,'--yes')
  if ($controlResult.ExitCode -ne 0) { throw 'CLI success control failed; raw output withheld' }
  $committed = Invoke-FixtureSql "select to_regclass('d01_transport_probe.committed_together') is not null and (select count(*)=1 from supabase_migrations.schema_migrations where version='$version' and name='d01_atomicity_fixture' and cardinality(statements)=4);" -Phase 'commit-check'
  if ($committed -cne 't') { throw 'DDL/nominal ledger success control FAIL' }
  Write-Output 'CLI_LEDGER_SUCCESS_CONTROL_PASS'
} finally {
  # The dedicated stack owner must stop and verify all resources in its own finally.
  # Keep the successful synthetic ledger/DDL together until that full stack disposal.
  if ($created) {
    $null = Invoke-FixtureSql 'drop trigger if exists d01_transport_probe_reject on supabase_migrations.schema_migrations; drop function if exists d01_transport_probe.reject_ledger();' -Phase 'cleanup'
  }
}
