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

if (-not (Test-Path -LiteralPath $projectFull -PathType Container) -or
    -not (Test-Path -LiteralPath $markerPath -PathType Leaf) -or
    [IO.File]::ReadAllText($markerPath) -ne $ProjectId) {
  throw 'Location reservation audit authorization requires the owned disposable replay project'
}
$running = @(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') {
  throw 'Location reservation audit authorization database container is unavailable'
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
    throw 'Location reservation audit authorization could not start an isolated SQL session'
  }
  $process.StandardInput.WriteLine($Sql)
  $process.StandardInput.Flush()
  if (-not $KeepInputOpen) { $process.StandardInput.Close() }
  $processes.Add($process)
  $process
}

function Complete-IsolatedPsql([Diagnostics.Process]$Process, [int]$TimeoutMilliseconds = 30000) {
  if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
    try { $Process.Kill() } catch { }
    throw 'Location reservation audit authorization SQL session timed out'
  }
  $output = $Process.StandardOutput.ReadToEnd()
  $errorOutput = $Process.StandardError.ReadToEnd()
  if ($Process.ExitCode -ne 0) {
    throw "Location reservation audit authorization SQL session failed: $($errorOutput.Trim())"
  }
  [pscustomobject]@{ Output = $output; Error = $errorOutput }
}

function Get-JsonResult([string]$Output) {
  $jsonLines = @($Output -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') })
  if ($jsonLines.Count -ne 1) {
    throw 'Location reservation audit authorization returned an unexpected result shape'
  }
  $jsonLines[0] | ConvertFrom-Json
}

function Read-IsolatedJson([string]$Sql) {
  Get-JsonResult (Complete-IsolatedPsql (Start-IsolatedPsql $Sql)).Output
}

function Wait-IsolatedCondition([string]$Sql, [string]$Failure) {
  $timer = [Diagnostics.Stopwatch]::StartNew()
  do {
    if ((Read-IsolatedJson $Sql).ready -eq $true) { return }
    Start-Sleep -Milliseconds 100
  } while ($timer.ElapsedMilliseconds -lt 10000)
  throw $Failure
}

$fixtureSql = @'
begin;
insert into public.institution_types(id,code,name,status) values
 ('d1000000-0000-4000-8000-000000000001','reservation-audit-auth','Reservation audit authorization','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('d1100000-0000-4000-8000-000000000001','Reservation Audit Tenant','reservation-audit-auth','active','d1000000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,name,slug,status,institution_type_id) values
 ('d1200000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','Reservation Audit Unit','reservation-audit-unit','active','d1000000-0000-4000-8000-000000000001');
insert into public.groups(id,institution_id,unit_id,name,status) values
 ('d1300000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001','d1200000-0000-4000-8000-000000000001','Expiry Group','active'),
 ('d1300000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000001','d1200000-0000-4000-8000-000000000001','Revocation Group','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
select ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'authenticated','authenticated',
 'reservation-audit-'||i||'@invalid.test',now(),now(),now(),'{}','{}' from generate_series(1,3)i;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
select ('d1500000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now(),now(),'aal1',now()+interval '1 hour'
from generate_series(1,3)i;
insert into app_private.superadmin_internal_identities(id)
select ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid from generate_series(1,3)i;
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status)
select ('d1700000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'active' from generate_series(1,3)i;
insert into app_private.superadmin_internal_memberships(
 id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
select ('d1800000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('d1600000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,role_record.id,
 case when i<3 then 'institution'::app_private.superadmin_internal_scope_kind
      else 'platform'::app_private.superadmin_internal_scope_kind end,
 case when i<3 then 'd1100000-0000-4000-8000-000000000001'::uuid end,'active'
from generate_series(1,3)i cross join lateral(
 select id from public.platform_roles where code='owner' and status='active'
)role_record;
insert into public.activity_locations(id,institution_id,unit_id,name,status,scope_kind,kind,visibility,
 created_by_internal_identity_id) values
 ('d1900000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001',null,'Expiry Room','active','institution','internal','team','d1600000-0000-4000-8000-000000000003'),
 ('d1900000-0000-4000-8000-000000000002','d1100000-0000-4000-8000-000000000001',null,'Revocation Room','active','institution','internal','team','d1600000-0000-4000-8000-000000000003');
insert into public.location_scheduling_policies(
 scope_kind,owner_id,institution_id,unit_id,policy,updated_by_internal_identity_id)
values('institution','d1100000-0000-4000-8000-000000000001','d1100000-0000-4000-8000-000000000001',null,'block','d1600000-0000-4000-8000-000000000003');
commit;
'@

function Get-Claims([int]$Actor) {
  '{{"sub":"d1400000-0000-4000-8000-{0}","session_id":"d1500000-0000-4000-8000-{0}","aal":"aal1","role":"authenticated"}}' -f $Actor.ToString().PadLeft(12,'0')
}

function Test-AuditAuthorizationAfterWait(
  [ValidateSet('expiry','revocation')][string]$Scenario,
  [int]$Actor,
  [string]$LocationId,
  [string]$GroupId,
  [string]$RequestId,
  [string]$ExpectedCode
) {
  $holderName = "location_audit_holder_$Scenario"
  $callerName = "location_audit_caller_$Scenario"
  $claims = Get-Claims $Actor
  $holder = Start-IsolatedPsql -KeepInputOpen -Sql @"
begin;
set application_name='$holderName';
lock table audit.audit_logs in share mode;
select jsonb_build_object('holder',true)::text;
"@
  Wait-IsolatedCondition @"
select jsonb_build_object('ready',exists(
 select 1 from pg_locks lock_record join pg_stat_activity activity on activity.pid=lock_record.pid
 where activity.application_name='$holderName' and lock_record.relation='audit.audit_logs'::regclass
   and lock_record.mode='ShareLock' and lock_record.granted
))::text;
"@ 'Audit holder did not acquire the relation lock'

  $caller = Start-IsolatedPsql @"
begin;
set application_name='$callerName';
set local role authenticated;
set local statement_timeout='25s';
set local lock_timeout='20s';
select set_config('request.jwt.claims','$claims',true) is not null;
select public.superadmin_location_reservation_create_v2(jsonb_build_object(
 'location_id','$LocationId','consumer',jsonb_build_object('kind','group','id','$GroupId'),
 'first_occurrence',jsonb_build_object('starts_at','2026-09-15T12:00:00Z','ends_at','2026-09-15T13:00:00Z'),
 'recurrence',jsonb_build_object('kind','once'),'conflict_justification',null
 ),'$RequestId')::text;
commit;
"@
  Wait-IsolatedCondition @"
select jsonb_build_object('ready',exists(
 select 1 from pg_stat_activity caller join pg_stat_activity holder
   on holder.pid=any(pg_blocking_pids(caller.pid))
 where caller.application_name='$callerName' and holder.application_name='$holderName'
   and caller.wait_event_type='Lock'
))::text;
"@ 'Reservation caller did not reach the blocked success audit'

  $updateSql = if ($Scenario -eq 'expiry') {
@"
-- The caller transaction's pg_catalog.now() remains earlier than this value,
-- so the denial helper can identify the actor; final reauthorization uses the
-- wall clock and must reject the session after the blocked audit completes.
update auth.sessions set not_after=clock_timestamp()
where id='d1500000-0000-4000-8000-$($Actor.ToString().PadLeft(12,'0'))';
"@
  } else {
@"
update app_private.superadmin_internal_memberships
set status='revoked',revoked_at=clock_timestamp(),suspended_at=null,
 changed_by_internal_identity_id='d1600000-0000-4000-8000-000000000003',version=version+1
where id='d1800000-0000-4000-8000-$($Actor.ToString().PadLeft(12,'0'))';
"@
  }
  $updater = Start-IsolatedPsql $updateSql
  $null = Complete-IsolatedPsql $updater
  $holder.StandardInput.WriteLine('commit;')
  $holder.StandardInput.Close()
  $null = Complete-IsolatedPsql $holder
  $response = Get-JsonResult (Complete-IsolatedPsql $caller).Output
  if ($response.ok -ne $false -or $response.error.code -ne $ExpectedCode) {
    throw "Reservation $Scenario after confirmed audit wait did not return $ExpectedCode"
  }
  $correlation = [guid]$response.error.correlation_id
  $proof = Read-IsolatedJson @"
select jsonb_build_object(
 'bindings',(select count(*) from public.location_bindings where location_id='$LocationId'),
 'reservations',(select count(*) from public.location_reservations where location_id='$LocationId'),
 'occurrences',(select count(*) from public.location_reservation_occurrences occurrence
   join public.location_reservations reservation on reservation.id=occurrence.reservation_id
   where reservation.location_id='$LocationId'),
 'receipts',(select count(*) from app_private.location_reservation_receipts where request_id='$RequestId'),
 'successes',(select count(*) from audit.audit_logs where correlation_id='$correlation' and outcome='success'),
 'denials',(select count(*) from audit.audit_logs where correlation_id='$correlation' and outcome='denied'
   and reason_code='$ExpectedCode' and action_code='location.reservation.create'
   and institution_id='d1100000-0000-4000-8000-000000000001')
)::text;
"@
  if ($proof.bindings -ne 0 -or $proof.reservations -ne 0 -or $proof.occurrences -ne 0 -or
      $proof.receipts -ne 0 -or $proof.successes -ne 0 -or $proof.denials -ne 1) {
    throw "Reservation $Scenario denial violated rollback or audit invariants"
  }
  "Location reservation $Scenario passed after a confirmed audit wait: $ExpectedCode and zero durable effects."
}

try {
  $null = Complete-IsolatedPsql (Start-IsolatedPsql $fixtureSql)
  Test-AuditAuthorizationAfterWait 'expiry' 1 `
    'd1900000-0000-4000-8000-000000000001' `
    'd1300000-0000-4000-8000-000000000001' `
    'da000000-0000-4000-8000-000000000001' 'SAI_SESSION_INVALID'
  Test-AuditAuthorizationAfterWait 'revocation' 2 `
    'd1900000-0000-4000-8000-000000000002' `
    'd1300000-0000-4000-8000-000000000002' `
    'da000000-0000-4000-8000-000000000002' 'SAI_MEMBERSHIP_REVOKED'
}
finally {
  foreach ($process in $processes) {
    if (-not $process.HasExited) {
      try { $process.StandardInput.Close() } catch { }
      try { $process.Kill() } catch { }
    }
    $process.Dispose()
  }
}

'Location reservation audit authorization passed: expiry and terminal revocation rolled back every success effect.'
