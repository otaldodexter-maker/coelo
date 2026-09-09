[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^coelo_safe_[a-f0-9]{29}$')]
  [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
$projectFull = [IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $projectFull '.coelo-safe-replay'
$containerName = "supabase_db_$ProjectId"
$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$packageRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $packageRoot)
$payloadPath = Join-Path $repositoryRoot 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-remote-apply-migration.sql'
$authManifestPath = Join-Path $repositoryRoot 'docs\reviews\etapa-2-operacao\next-round\R02-20260909\handoffs\notes\child-package-auth-base.sha256'
$projectMigrationsRoot = Join-Path $projectFull 'supabase\migrations'
$expectedPayloadSha256 = '740057756fb2a7dfa5e8f2ab2d9908df24968f2a3e78196a1faa0d3b422c6c2c'
$expectedAuthManifestSha256 = '1b31d0ad0d825d9420cc862808f582f08c6ce0171208018f588c0a998a0e9f46'
$probeRole = 'd03_child_package_acl_probe'
$fixtureCleanupSql = @"
begin;
do `$cleanup_guard`$
begin
  if current_user<>'postgres'
    or not exists(select 1 from pg_catalog.pg_roles
      where rolname='$probeRole' and not rolcanlogin
        and not rolsuper and not rolcreaterole and not rolcreatedb
        and not rolreplication and not rolbypassrls)
    or exists(select 1 from pg_catalog.pg_auth_members membership
      join pg_catalog.pg_roles role_record
       on role_record.oid in(membership.roleid,membership.member)
      where role_record.rolname='$probeRole') then
    raise object_not_in_prerequisite_state
      using message='CHILD package fixture ownership drift';
  end if;
end
`$cleanup_guard`$;
alter default privileges for role postgres in schema public
  revoke execute on functions from $probeRole;
drop role $probeRole;

commit;
"@
$processes = [Collections.Generic.List[Diagnostics.Process]]::new()
$fixtureAttempted = $false

function Assert-NoReparseAncestors([string]$Path) {
  $cursor = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'CHILD package local path contains a reparse point'
    }
    $cursor = $cursor.Parent
  }
}

function Assert-NoReparseTree([string]$Path) {
  Assert-NoReparseAncestors $Path
  foreach ($item in Get-ChildItem -LiteralPath $Path -Force -Recurse) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'CHILD package local migrations contain a reparse point'
    }
  }
}

function Get-Sha256Hex([byte[]]$Bytes) {
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    return -join @($algorithm.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') })
  }
  finally {
    $algorithm.Dispose()
  }
}

function Get-NormalizedLfSha256([string]$Path) {
  $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
  $text = $strictUtf8.GetString([IO.File]::ReadAllBytes($Path))
  $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
  return Get-Sha256Hex ([Text.UTF8Encoding]::new($false).GetBytes($normalized))
}

function Invoke-OwnedPsql(
  [string]$Sql,
  [int]$TimeoutMilliseconds = 60000,
  [switch]$AllowFailure
) {
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $dockerPath
  $startInfo.Arguments = "exec -i $containerName psql --no-psqlrc --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --tuples-only --no-align --username postgres --dbname postgres"
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
  $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) {
    $process.Dispose()
    throw 'CHILD package local could not start owned psql'
  }
  $processes.Add($process)
  $outputTask = $process.StandardOutput.ReadToEndAsync()
  $errorTask = $process.StandardError.ReadToEndAsync()
  $sqlBytes = [Text.UTF8Encoding]::new($false).GetBytes(
    "set statement_timeout = '30s'; set lock_timeout = '5s';`n" + $Sql + "`n")
  $process.StandardInput.BaseStream.Write($sqlBytes, 0, $sqlBytes.Length)
  $process.StandardInput.BaseStream.Close()
  if (-not $process.WaitForExit($TimeoutMilliseconds)) {
    try { $process.Kill() } catch { }
    throw 'CHILD package local psql timed out'
  }
  $output = $outputTask.GetAwaiter().GetResult()
  $errorOutput = $errorTask.GetAwaiter().GetResult()
  if (-not $AllowFailure -and $process.ExitCode -ne 0) {
    $sqlState = 'UNKNOWN'
    if ($errorOutput -match '(?m)^ERROR:\s+([0-9A-Z]{5}):' -and
        $Matches[1] -cin @('55000','42501','2BP01','42704','42P01','42710','P0001')) {
      $sqlState = $Matches[1]
    }
    $knownGuard = $errorOutput -match 'CHILD package fixture ownership drift'
    throw "CHILD package local psql failed; SQLSTATE=$sqlState; fixtureOwnershipGuard=$knownGuard; raw output withheld"
  }
  [pscustomobject]@{
    ExitCode = $process.ExitCode
    Output = $output
    Error = $errorOutput
  }
}

function Get-SingleJson([string]$Output, [string]$Description) {
  $lines = @($Output -split "`r?`n" | ForEach-Object { $_.Trim() } |
    Where-Object { $_.StartsWith('{') })
  if ($lines.Count -ne 1) {
    throw "CHILD package local returned invalid $Description evidence"
  }
  return $lines[0] | ConvertFrom-Json
}

function Get-BaseState {
  Get-SingleJson (Invoke-OwnedPsql @"
select pg_catalog.jsonb_build_object(
 'is_postgres',current_user='postgres',
 'envelope_md5',(select pg_catalog.md5(pg_catalog.replace(p.prosrc,E'\r\n',E'\n'))
   from pg_catalog.pg_proc p where p.oid=pg_catalog.to_regprocedure(
    'app_private.superadmin_internal_error_envelope(text,uuid)')),
 'gateway_exists',pg_catalog.to_regprocedure(
   'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)') is not null,
 'probe_role_exists',exists(select 1 from pg_catalog.pg_roles where rolname='$probeRole'),
 'auth_target_present',exists(select 1 from supabase_migrations.schema_migrations
   where version='20260901200206'),
 'newer_migration_present',exists(select 1 from supabase_migrations.schema_migrations
   where version>'20260901200206')
)::text;
"@).Output 'base state'
}

function Assert-OriginalBase($State, [string]$Stage) {
  if ($State.auth_target_present -ne $true -or $State.newer_migration_present -ne $false) {
    throw "CHILD package local $Stage is not the exact AuthOnly target 20260901200206"
  }
  if ($State.is_postgres -ne $true -or
      $State.envelope_md5 -cne 'b89d2dc22f032a1c3f155a77f0eaaf08' -or
      $State.gateway_exists -ne $false -or $State.probe_role_exists -ne $false) {
    throw "CHILD package local $Stage does not match the pinned AuthOnly base"
  }
}

Assert-NoReparseAncestors $projectFull
if (-not (Test-Path -LiteralPath $projectFull -PathType Container) -or
    -not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw 'CHILD package local requires the owned disposable replay project'
}
Assert-NoReparseAncestors $markerPath
if ([IO.File]::ReadAllText($markerPath) -ne $ProjectId) {
  throw 'CHILD package local requires the owned disposable replay project'
}
if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
  throw 'CHILD package local payload is missing'
}
Assert-NoReparseAncestors $payloadPath
if (-not (Test-Path -LiteralPath $authManifestPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $projectMigrationsRoot -PathType Container)) {
  throw 'CHILD package local AuthOnly manifest or migration root is missing'
}
Assert-NoReparseAncestors $authManifestPath
Assert-NoReparseTree $projectMigrationsRoot
if ((Get-NormalizedLfSha256 $authManifestPath) -cne
    $expectedAuthManifestSha256) {
  throw 'CHILD package local AuthOnly manifest differs from the reviewed pin'
}
$manifestEntries = @(Get-Content -LiteralPath $authManifestPath | ForEach-Object {
  if ($_ -notmatch '^([0-9a-f]{64})  (\d{14}_[a-z0-9_]+\.sql)$') {
    throw 'CHILD package local AuthOnly manifest has an invalid entry'
  }
  [pscustomobject]@{ Hash = $Matches[1]; Name = $Matches[2] }
})
$migrationFiles = @(Get-ChildItem -LiteralPath $projectMigrationsRoot -File -Filter '*.sql' |
  Sort-Object Name)
if ($manifestEntries.Count -ne 47 -or $migrationFiles.Count -ne 47) {
  throw 'CHILD package local AuthOnly migration count differs from the reviewed base'
}
for ($index = 0; $index -lt $manifestEntries.Count; $index++) {
  if ($migrationFiles[$index].Name -cne $manifestEntries[$index].Name -or
      (Get-NormalizedLfSha256 $migrationFiles[$index].FullName) -cne
        $manifestEntries[$index].Hash) {
    throw 'CHILD package local AuthOnly migration order or normalized hash drifted'
  }
}
$payloadBytes = [IO.File]::ReadAllBytes($payloadPath)
if ($payloadBytes.Length -ge 3 -and $payloadBytes[0] -eq 0xef -and
    $payloadBytes[1] -eq 0xbb -and $payloadBytes[2] -eq 0xbf) {
  throw 'CHILD package local payload must not contain a BOM'
}
$payload = [Text.UTF8Encoding]::new($false, $true).GetString($payloadBytes).
  Replace("`r`n", "`n").Replace("`r", "`n")
$normalizedPayloadBytes = [Text.UTF8Encoding]::new($false).GetBytes($payload)
if ((Get-Sha256Hex $normalizedPayloadBytes) -cne $expectedPayloadSha256 -or
    $normalizedPayloadBytes.Length -ne 22280) {
  throw 'CHILD package local payload differs from the reviewed LF candidate'
}
$running = @(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') {
  throw 'CHILD package local database container is unavailable'
}

$primaryFailure = $null
try {
  Assert-OriginalBase (Get-BaseState) 'prestate'
  'package.prestate'

  $null = Invoke-OwnedPsql @"
begin;
do `$fixture`$
begin
  if current_user<>'postgres' then
    raise insufficient_privilege using message='CHILD package fixture requires postgres';
  end if;
  create role $probeRole nologin;
end
`$fixture`$;
alter default privileges for role postgres in schema public
  grant execute on functions to $probeRole;
commit;
"@
  $fixtureAttempted = $true

  $fixtureState = Get-SingleJson (Invoke-OwnedPsql @"
select pg_catalog.jsonb_build_object(
 'nologin',exists(select 1 from pg_catalog.pg_roles where rolname='$probeRole' and not rolcanlogin),
 'default_execute',exists(
   select 1 from pg_catalog.pg_default_acl d
   join pg_catalog.pg_roles owner_role on owner_role.oid=d.defaclrole and owner_role.rolname='postgres'
   join pg_catalog.pg_namespace n on n.oid=d.defaclnamespace and n.nspname='public'
   cross join lateral pg_catalog.aclexplode(d.defaclacl) a
   join pg_catalog.pg_roles grantee on grantee.oid=a.grantee and grantee.rolname='$probeRole'
   where d.defaclobjtype='f' and a.privilege_type='EXECUTE' and not a.is_grantable)
)::text;
"@).Output 'negative fixture state'
  if ($fixtureState.nologin -ne $true -or $fixtureState.default_execute -ne $true) {
    throw 'CHILD package local negative fixture was not established'
  }

  $negative = Invoke-OwnedPsql -AllowFailure -Sql ("begin;`n" + $payload + "`ncommit;`n")
  if ($negative.ExitCode -eq 0 -or
      ($negative.Output + $negative.Error) -notmatch '55000:.*child directory package result drift') {
    throw 'CHILD package local negative run did not fail at the final postflight'
  }
  'package.default-acl-denied'
  $negativeRollback = Get-BaseState
  if ($negativeRollback.envelope_md5 -cne 'b89d2dc22f032a1c3f155a77f0eaaf08' -or
      $negativeRollback.gateway_exists -ne $false -or
      $negativeRollback.probe_role_exists -ne $true) {
    throw 'CHILD package local negative transaction did not roll back atomically'
  }
  'package.negative-rollback'

  $cleanupProbe = Get-SingleJson (Invoke-OwnedPsql @"
select pg_catalog.jsonb_build_object(
 'nologin', exists(select 1 from pg_catalog.pg_roles where rolname='$probeRole' and not rolcanlogin),
 'elevated', exists(select 1 from pg_catalog.pg_roles where rolname='$probeRole' and (rolsuper or rolcreaterole or rolcreatedb or rolreplication or rolbypassrls)),
 'memberships', (select count(*) from pg_catalog.pg_auth_members m
   join pg_catalog.pg_roles r on r.oid in(m.roleid,m.member) where r.rolname='$probeRole')
)::text;
"@).Output 'cleanup probe'
  "CHILD_CLEANUP_PROBE nologin=$($cleanupProbe.nologin) elevated=$($cleanupProbe.elevated) memberships=$($cleanupProbe.memberships)"
  $null = Invoke-OwnedPsql -Sql $fixtureCleanupSql
  $fixtureAttempted = $false
  Assert-OriginalBase (Get-BaseState) 'post-fixture cleanup'
  'package.fixture-cleanup'

  $positiveVerification = @'
do $local_positive$
declare p record;
begin
  if (select md5(replace(prosrc,E'\r\n',E'\n')) from pg_catalog.pg_proc
      where oid=pg_catalog.to_regprocedure(
       'app_private.superadmin_internal_error_envelope(text,uuid)'))
       is distinct from 'bfce7b85b8d5d43e93e5d3fba3a66dc8' then
    raise object_not_in_prerequisite_state using message='local envelope result drift';
  end if;
  select proc.* into p from pg_catalog.pg_proc proc where proc.oid=pg_catalog.to_regprocedure(
    'public.superadmin_child_context_directory_v2(uuid,text,uuid,integer)');
  if p.oid is null
    or md5(replace(p.prosrc,E'\r\n',E'\n'))<>'302916710017ece5fa029d9ea388e3f9'
    or p.prokind<>'f' or p.provolatile<>'v' or not p.prosecdef or p.proretset
    or p.prorettype<>'jsonb'::regtype
    or (select lanname from pg_catalog.pg_language where oid=p.prolang)<>'plpgsql'
    or pg_catalog.pg_get_userbyid(p.proowner)<>'postgres'
    or coalesce(p.proconfig,'{}'::text[])<>array['search_path=""']::text[]
    or not pg_catalog.has_function_privilege('authenticated',p.oid,'EXECUTE')
    or pg_catalog.has_function_privilege('anon',p.oid,'EXECUTE')
    or pg_catalog.has_function_privilege('service_role',p.oid,'EXECUTE')
    or exists(select 1 from pg_catalog.aclexplode(coalesce(p.proacl,
      pg_catalog.acldefault('f',p.proowner))) a where a.grantee not in(
       p.proowner,(select oid from pg_catalog.pg_roles where rolname='authenticated'))
       or a.privilege_type<>'EXECUTE' or (a.grantee<>p.proowner and a.is_grantable)) then
    raise object_not_in_prerequisite_state using message='local CHILD result drift';
  end if;
end
$local_positive$;
'@
  $null = Invoke-OwnedPsql -Sql ("begin;`n" + $payload + "`ncommit;`n")
  'package.positive-metadata'
  $null = Invoke-OwnedPsql -Sql $positiveVerification
  'package.persisted-after-commit'
}
catch {
  $primaryFailure = $_.Exception
}
finally {
  foreach ($process in $processes) {
    try { if (-not $process.HasExited) { $process.Kill() } } catch { }
  }
  if ($fixtureAttempted) {
    try {
      $null = Invoke-OwnedPsql -Sql $fixtureCleanupSql
    }
    catch {
      if ($null -eq $primaryFailure) { $primaryFailure = $_.Exception }
    }
  }
  foreach ($process in $processes) { $process.Dispose() }
}
if ($null -ne $primaryFailure) { throw $primaryFailure }

'CHILD package local PASS: extra default ACL failed closed and rolled back; clean payload committed and persisted the reviewed catalog state.'
