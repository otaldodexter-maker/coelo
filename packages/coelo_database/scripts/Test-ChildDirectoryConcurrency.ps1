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
$processes = [Collections.Generic.List[Diagnostics.Process]]::new()
$auditGateOwned = $false

if (-not (Test-Path -LiteralPath $projectFull -PathType Container) -or
    -not (Test-Path -LiteralPath $markerPath -PathType Leaf) -or
    [IO.File]::ReadAllText($markerPath) -ne $ProjectId) {
  throw 'CHILD concurrency requires the owned disposable replay project'
}

$running = @(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') {
  throw 'CHILD concurrency database container is unavailable'
}

function Start-IsolatedPsql([string]$Sql, [switch]$KeepInputOpen) {
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $dockerPath
  $startInfo.Arguments = "exec -i $containerName psql --no-psqlrc --set ON_ERROR_STOP=1 --tuples-only --no-align --username postgres --dbname postgres"
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
    throw 'CHILD concurrency could not start an isolated SQL session'
  }
  $process.StandardInput.WriteLine($Sql)
  $process.StandardInput.Flush()
  if (-not $KeepInputOpen) { $process.StandardInput.Close() }
  $processes.Add($process)
  return $process
}

function Complete-IsolatedPsql(
  [Diagnostics.Process]$Process,
  [int]$TimeoutMilliseconds = 30000,
  [switch]$AllowFailure
) {
  if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
    try { $Process.Kill() } catch { }
    throw 'CHILD concurrency SQL session timed out'
  }
  $standardOutput = $Process.StandardOutput.ReadToEnd()
  $standardError = $Process.StandardError.ReadToEnd()
  if (-not $AllowFailure -and $Process.ExitCode -ne 0) {
    throw "CHILD concurrency SQL session failed: $($standardError.Trim())"
  }
  [pscustomobject]@{
    ExitCode = $Process.ExitCode
    Output = $standardOutput
    Error = $standardError
  }
}

function Invoke-IsolatedPsql([string]$Sql) {
  Complete-IsolatedPsql (Start-IsolatedPsql $Sql)
}

function Get-JsonResult([string]$Output) {
  $jsonLines = @($Output -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') })
  if ($jsonLines.Count -ne 1) {
    throw 'CHILD concurrency session returned an unexpected JSON result shape'
  }
  return $jsonLines[0] | ConvertFrom-Json
}

function Wait-ForDatabaseSignal(
  [string]$Sql,
  [string]$Description,
  [int]$TimeoutMilliseconds = 10000
) {
  $deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
  do {
    $result = Invoke-IsolatedPsql $Sql
    $values = @($result.Output -split "`r?`n" | ForEach-Object { $_.Trim() } |
      Where-Object { $_ -match '^\d+$' })
    if ($values.Count -eq 1 -and $values[0] -eq '1') { return }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)
  throw "CHILD concurrency timed out waiting for $Description"
}

function Get-SingleInteger([string]$Output, [string]$Description) {
  $values = @($Output -split "`r?`n" | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -match '^\d+$' })
  if ($values.Count -ne 1) {
    throw "CHILD concurrency received an unexpected $Description result"
  }
  return [int64]$values[0]
}

function Start-DatabaseGate([string]$ApplicationName, [int64]$LockKey) {
  $process = Start-IsolatedPsql -KeepInputOpen @"
set application_name='$ApplicationName';
set statement_timeout='25s';
select pg_catalog.pg_advisory_lock($LockKey);
"@
  Wait-ForDatabaseSignal @"
select count(*) from pg_catalog.pg_locks lock_record
join pg_catalog.pg_stat_activity activity on activity.pid=lock_record.pid
where activity.application_name='$ApplicationName'
 and lock_record.locktype='advisory' and lock_record.granted;
"@ "$ApplicationName to acquire its advisory gate"
  return $process
}

function Release-DatabaseGate(
  [Diagnostics.Process]$Process,
  [int64]$LockKey
) {
  $Process.StandardInput.WriteLine("select pg_catalog.pg_advisory_unlock($LockKey);")
  $Process.StandardInput.WriteLine('\q')
  $Process.StandardInput.Close()
  $result = Complete-IsolatedPsql $Process
  if ($result.Error -match '(?i)deadlock') {
    throw 'CHILD concurrency gate encountered a deadlock'
  }
}

$fixtureSql = @'
begin;
insert into public.institution_types(id,code,name,status) values
 ('9c100000-0000-4000-8000-000000000001','child-directory-concurrency','CHILD concurrency','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('9c100000-0000-4000-8000-000000000010','Concurrency Institution','child-directory-concurrency','active','9c100000-0000-4000-8000-000000000001');
insert into public.people(id,person_type,first_name,last_name,display_name) values
 ('9c100000-0000-4000-8000-000000000101','child','Synthetic','Alpha','Alfa'),
 ('9c100000-0000-4000-8000-000000000102','child','Synthetic','Beta','Beta'),
 ('9c100000-0000-4000-8000-000000000103','child','Synthetic','Zulu','Zulu');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000101','9c100000-0000-4000-8000-000000000010','active'),
 ('9c100000-0000-4000-8000-000000000702','9c100000-0000-4000-8000-000000000102','9c100000-0000-4000-8000-000000000010','active'),
 ('9c100000-0000-4000-8000-000000000703','9c100000-0000-4000-8000-000000000103','9c100000-0000-4000-8000-000000000010','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9c100000-0000-4000-8000-000000000201','authenticated','authenticated','child-concurrency-revoked@invalid.test',now(),now(),now(),'{}','{}'),
 ('9c100000-0000-4000-8000-000000000202','authenticated','authenticated','child-concurrency-active@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000201',now(),now(),'aal1',clock_timestamp()+interval '1 hour'),
 ('9c100000-0000-4000-8000-000000000302','9c100000-0000-4000-8000-000000000202',now(),now(),'aal1',clock_timestamp()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('9c100000-0000-4000-8000-000000000401'),
 ('9c100000-0000-4000-8000-000000000402');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status) values
 ('9c100000-0000-4000-8000-000000000501','9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000201','active'),
 ('9c100000-0000-4000-8000-000000000502','9c100000-0000-4000-8000-000000000402','9c100000-0000-4000-8000-000000000202','active');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,status)
select fixture.id,fixture.internal_identity_id,role_record.id,'platform','active'
from public.platform_roles role_record
cross join (values
 ('9c100000-0000-4000-8000-000000000601'::uuid,'9c100000-0000-4000-8000-000000000401'::uuid),
 ('9c100000-0000-4000-8000-000000000602'::uuid,'9c100000-0000-4000-8000-000000000402'::uuid)
) as fixture(id,internal_identity_id)
where role_record.code='owner';
commit;
'@

$revocationClaims = '{"sub":"9c100000-0000-4000-8000-000000000201","session_id":"9c100000-0000-4000-8000-000000000301","aal":"aal1","role":"authenticated"}'
$activeClaims = '{"sub":"9c100000-0000-4000-8000-000000000202","session_id":"9c100000-0000-4000-8000-000000000302","aal":"aal1","role":"authenticated"}'
function New-ReaderSql(
  [string]$ApplicationName,
  [string]$Claims,
  [int]$Limit = 20,
  [int]$StatementTimeoutSeconds = 20,
  [int]$LockTimeoutSeconds = 15
) {
  return @"
set application_name='$ApplicationName';
set statement_timeout='$($StatementTimeoutSeconds)s';
set lock_timeout='$($LockTimeoutSeconds)s';
set role authenticated;
with configured as materialized (
 select set_config('request.jwt.claims','$Claims',false)
)
select public.superadmin_child_context_directory_v2(null,null,null,$Limit)::text
from configured;
"@
}

function Wait-ForBlockedSession(
  [string]$ApplicationName,
  [string]$ExpectedBlockerApplicationName
) {
  Wait-ForDatabaseSignal @"
select count(*)
from pg_catalog.pg_stat_activity reader
join pg_catalog.pg_stat_activity blocker
 on blocker.pid=any(pg_catalog.pg_blocking_pids(reader.pid))
where reader.application_name='$ApplicationName'
 and reader.wait_event_type='Lock'
 and blocker.application_name='$ExpectedBlockerApplicationName';
"@ "$ApplicationName to block on $ExpectedBlockerApplicationName"
}

try {
  $preflight = Invoke-IsolatedPsql @"
select (
 (select count(*) from public.institution_types where id='9c100000-0000-4000-8000-000000000001')+
 (select count(*) from public.institutions where id='9c100000-0000-4000-8000-000000000010')+
 (select count(*) from public.people where id in('9c100000-0000-4000-8000-000000000101','9c100000-0000-4000-8000-000000000102','9c100000-0000-4000-8000-000000000103'))+
 (select count(*) from public.child_contexts where id in('9c100000-0000-4000-8000-000000000701','9c100000-0000-4000-8000-000000000702','9c100000-0000-4000-8000-000000000703'))+
 (select count(*) from auth.users where id in('9c100000-0000-4000-8000-000000000201','9c100000-0000-4000-8000-000000000202'))+
 (select count(*) from auth.sessions where id in('9c100000-0000-4000-8000-000000000301','9c100000-0000-4000-8000-000000000302'))+
 (select count(*) from app_private.superadmin_internal_identities where id in('9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000402'))+
 (select count(*) from app_private.superadmin_internal_auth_links where id in('9c100000-0000-4000-8000-000000000501','9c100000-0000-4000-8000-000000000502'))+
 (select count(*) from app_private.superadmin_internal_memberships where id in('9c100000-0000-4000-8000-000000000601','9c100000-0000-4000-8000-000000000602'))+
 (select count(*) from audit.audit_logs where actor_internal_identity_id in('9c100000-0000-4000-8000-000000000401','9c100000-0000-4000-8000-000000000402'))+
 (select count(*) from pg_catalog.pg_trigger where tgname='child_directory_concurrency_audit_gate')+
 (select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='app_private' and p.proname='child_directory_concurrency_audit_gate')
)::text;
"@
  if ((Get-SingleInteger $preflight.Output 'one-shot preflight') -ne 0) {
    throw 'CHILD concurrency requires a clean one-shot disposable database'
  }
  $null = Invoke-IsolatedPsql $fixtureSql

  # The writer changes authorization after the reader's first context lookup,
  # then the gateway must revalidate after its FOR SHARE wait.
  $membershipGateKey = 930001
  $membershipGate = Start-DatabaseGate 'child-membership-gate' $membershipGateKey
  $membershipWriter = Start-IsolatedPsql @"
begin;
set application_name='child-membership-writer';
set statement_timeout='20s';
set lock_timeout='15s';
update app_private.superadmin_internal_memberships
 set status='revoked',revoked_at=clock_timestamp(),version=version+1
 where id='9c100000-0000-4000-8000-000000000601';
select pg_catalog.pg_advisory_xact_lock($membershipGateKey);
commit;
"@
  Wait-ForDatabaseSignal @"
select count(*) from pg_catalog.pg_locks lock_record
join pg_catalog.pg_stat_activity activity on activity.pid=lock_record.pid
where activity.application_name='child-membership-writer'
 and lock_record.locktype='advisory' and not lock_record.granted;
"@ 'the membership writer to hold the uncommitted revocation'
  $membershipReader = Start-IsolatedPsql (New-ReaderSql 'child-membership-reader' $revocationClaims)
  Wait-ForBlockedSession 'child-membership-reader' 'child-membership-writer'
  Release-DatabaseGate $membershipGate $membershipGateKey
  $null = Complete-IsolatedPsql $membershipWriter
  $membershipResponse = Get-JsonResult (Complete-IsolatedPsql $membershipReader).Output
  if ($membershipResponse.ok -ne $false -or
      $membershipResponse.data -ne $null -or
      $membershipResponse.error.code -cne 'SAI_MEMBERSHIP_REVOKED') {
    throw 'CHILD concurrency revocation returned data or the wrong denial'
  }
  $membershipAudit = Get-JsonResult (Invoke-IsolatedPsql @"
select jsonb_build_object(
 'success_count',(select count(*) from audit.audit_logs where action_code='child_context.directory' and outcome='success' and actor_internal_identity_id='9c100000-0000-4000-8000-000000000401'),
 'denied_count',(select count(*) from audit.audit_logs where action_code='child_context.directory' and outcome='denied' and reason_code='SAI_MEMBERSHIP_REVOKED' and actor_internal_identity_id='9c100000-0000-4000-8000-000000000401'),
 'trusted_input_count',(select count(*) from audit.audit_logs where action_code='child_context.directory' and outcome='denied' and institution_id is not null and actor_internal_identity_id='9c100000-0000-4000-8000-000000000401')
)::text;
"@).Output
  if ([int64]$membershipAudit.success_count -ne 0 -or
      [int64]$membershipAudit.denied_count -ne 1 -or
      [int64]$membershipAudit.trusted_input_count -ne 0) {
    throw 'CHILD concurrency revocation audit invariants failed'
  }
  # Zulu is the third limit+1 candidate. Its concurrent rename must be sorted
  # again after the row-lock wait before the first two items/cursor are emitted.
  $renameGateKey = 930002
  $renameGate = Start-DatabaseGate 'child-rename-gate' $renameGateKey
  $renameWriter = Start-IsolatedPsql @"
begin;
set application_name='child-rename-writer';
set statement_timeout='20s';
set lock_timeout='15s';
update public.people set display_name='Aaron'
 where id='9c100000-0000-4000-8000-000000000103';
select pg_catalog.pg_advisory_xact_lock($renameGateKey);
commit;
"@
  Wait-ForDatabaseSignal @"
select count(*) from pg_catalog.pg_locks lock_record
join pg_catalog.pg_stat_activity activity on activity.pid=lock_record.pid
where activity.application_name='child-rename-writer'
 and lock_record.locktype='advisory' and not lock_record.granted;
"@ 'the rename writer to hold the limit-plus-one row'
  $renameReader = Start-IsolatedPsql (New-ReaderSql 'child-rename-reader' $activeClaims 2)
  Wait-ForBlockedSession 'child-rename-reader' 'child-rename-writer'
  Release-DatabaseGate $renameGate $renameGateKey
  $null = Complete-IsolatedPsql $renameWriter
  $renameResponse = Get-JsonResult (Complete-IsolatedPsql $renameReader).Output
  if ($renameResponse.ok -ne $true -or
      @($renameResponse.data.items).Count -ne 2 -or
      $renameResponse.data.items[0].person_name -cne 'Aaron' -or
      $renameResponse.data.items[1].person_name -cne 'Alfa' -or
      $renameResponse.data.next_cursor.name -cne 'alfa' -or
      $renameResponse.data.next_cursor.context_id -cne '9c100000-0000-4000-8000-000000000701') {
    throw 'CHILD concurrency rename did not re-sort the returned page and cursor'
  }

  # Hold the success audit after all read locks. Wall-clock expiry while it
  # waits must abort the response and roll the just-appended audit row back.
  $auditGateKey = 930003
  # Preflight proved these names absent. Cleanup now owns partial creation too.
  $auditGateOwned = $true
  $null = Invoke-IsolatedPsql @"
create function app_private.child_directory_concurrency_audit_gate()
returns trigger language plpgsql security definer set search_path='' as `$`$
begin
 if new.action_code='child_context.directory' then
  perform pg_catalog.pg_advisory_xact_lock($auditGateKey);
 end if;
 return new;
end
`$`$;
create trigger child_directory_concurrency_audit_gate
 before insert on audit.audit_logs for each row
 execute function app_private.child_directory_concurrency_audit_gate();
"@
  $auditGate = Start-DatabaseGate 'child-audit-gate' $auditGateKey
  $expiryDeadlineResult = Invoke-IsolatedPsql @"
with updated as (
 update auth.sessions set not_after=clock_timestamp()+interval '30 seconds'
 where id='9c100000-0000-4000-8000-000000000302'
 returning not_after
)
select extract(epoch from not_after)::text from updated;
"@
  $expiryDeadlineValues = @($expiryDeadlineResult.Output -split "`r?`n" |
    ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\d+(\.\d+)?$' })
  if ($expiryDeadlineValues.Count -ne 1) {
    throw 'CHILD concurrency did not capture exactly one expiry deadline'
  }
  $expiryDeadlineEpoch = $expiryDeadlineValues[0]
  $expiryReaderSql = New-ReaderSql -ApplicationName 'child-expiry-reader' `
    -Claims $activeClaims -StatementTimeoutSeconds 60 -LockTimeoutSeconds 50
  $expiryReader = Start-IsolatedPsql $expiryReaderSql
  Wait-ForBlockedSession 'child-expiry-reader' 'child-audit-gate'
  $expiryMargin = Invoke-IsolatedPsql @"
select count(*) from auth.sessions
where id='9c100000-0000-4000-8000-000000000302'
 and not_after=pg_catalog.to_timestamp($expiryDeadlineEpoch)
 and not_after-clock_timestamp()>=interval '20 seconds';
"@
  if ((Get-SingleInteger $expiryMargin.Output 'pre-expiry margin') -ne 1) {
    throw 'CHILD concurrency reader did not block with the required expiry margin'
  }
  Wait-ForDatabaseSignal @"
select count(*) from auth.sessions
where id='9c100000-0000-4000-8000-000000000302'
 and not_after=pg_catalog.to_timestamp($expiryDeadlineEpoch)
 and clock_timestamp()>=pg_catalog.to_timestamp($expiryDeadlineEpoch);
"@ 'the reader session to reach its captured wall-clock deadline' 40000
  Release-DatabaseGate $auditGate $auditGateKey
  $expiryResult = Complete-IsolatedPsql $expiryReader -AllowFailure
  if ($expiryResult.ExitCode -eq 0 -or
      ($expiryResult.Output + $expiryResult.Error) -notmatch 'SAI_SESSION_INVALID' -or
      ($expiryResult.Output + $expiryResult.Error) -match '\{"ok":true') {
    throw 'CHILD concurrency wall-clock expiry released child data'
  }
  $expiryAudit = Get-JsonResult (Invoke-IsolatedPsql @"
select jsonb_build_object(
 'success_count',(select count(*) from audit.audit_logs where action_code='child_context.directory' and outcome='success' and actor_internal_identity_id='9c100000-0000-4000-8000-000000000402'),
 'gate_count',(select count(*) from pg_catalog.pg_trigger where tgname='child_directory_concurrency_audit_gate')
)::text;
"@).Output
  if ([int64]$expiryAudit.success_count -ne 1 -or [int64]$expiryAudit.gate_count -ne 1) {
    throw 'CHILD concurrency success audit rolled back invariant failed'
  }
  $null = Invoke-IsolatedPsql @"
drop trigger child_directory_concurrency_audit_gate on audit.audit_logs;
drop function app_private.child_directory_concurrency_audit_gate();
update auth.sessions set not_after=clock_timestamp()+interval '1 hour'
 where id='9c100000-0000-4000-8000-000000000302';
"@
}
finally {
  foreach ($process in $processes) {
    try {
      if (-not $process.HasExited) { $process.Kill() }
    } catch { }
  }
  if ($auditGateOwned) {
    try {
      $null = Invoke-IsolatedPsql @"
drop trigger if exists child_directory_concurrency_audit_gate on audit.audit_logs;
drop function if exists app_private.child_directory_concurrency_audit_gate();
"@
    } catch { }
  }
  foreach ($process in $processes) {
    $process.Dispose()
  }
}

'CHILD concurrency passed: revocation denied after a lock wait, limit+1 rename re-sorted, and wall-clock expiry returned no data with its success audit rolled back.'
