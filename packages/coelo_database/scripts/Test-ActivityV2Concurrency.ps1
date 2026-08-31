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
  throw 'Activity v2 concurrency requires the owned disposable replay project'
}

$running = @(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') {
  throw 'Activity v2 concurrency database container is unavailable'
}

function Start-IsolatedPsql([string]$Sql) {
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
    throw 'Activity v2 concurrency could not start an isolated SQL session'
  }
  $process.StandardInput.Write($Sql)
  $process.StandardInput.Close()
  $processes.Add($process)
  return $process
}

function Complete-IsolatedPsql(
  [Diagnostics.Process]$Process,
  [int]$TimeoutMilliseconds = 30000
) {
  if (-not $Process.WaitForExit($TimeoutMilliseconds)) {
    try { $Process.Kill() } catch { }
    throw 'Activity v2 concurrency SQL session timed out'
  }
  $standardOutput = $Process.StandardOutput.ReadToEnd()
  $standardError = $Process.StandardError.ReadToEnd()
  if ($Process.ExitCode -ne 0) {
    throw "Activity v2 concurrency SQL session failed: $($standardError.Trim())"
  }
  [pscustomobject]@{
    Output = $standardOutput
    Error = $standardError
  }
}

function Get-JsonResult([string]$Output) {
  $jsonLines = @($Output -split "`r?`n" | Where-Object { $_.TrimStart().StartsWith('{') })
  if ($jsonLines.Count -ne 1) {
    throw 'Activity v2 concurrency session returned an unexpected result shape'
  }
  return $jsonLines[0] | ConvertFrom-Json
}

$fixtureSql = @'
begin;
insert into public.institution_types(id,code,name,status) values
 ('8c100000-0000-4000-8000-000000000001','activities-v2-concurrency','Activities v2 concurrency','active');
insert into public.institutions(id,public_name,slug,status,institution_type_id) values
 ('8c100000-0000-4000-8000-000000000010','Concurrency Tenant','activities-v2-concurrency','active','8c100000-0000-4000-8000-000000000001');
insert into public.units(id,institution_id,institution_type_id,name,slug,status) values
 ('8c100000-0000-4000-8000-000000000011','8c100000-0000-4000-8000-000000000010','8c100000-0000-4000-8000-000000000001','Concurrency Unit','activities-v2-concurrency-unit','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('8c100000-0000-4000-8000-000000000101','authenticated','authenticated','concurrency@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('8c100000-0000-4000-8000-000000000201','8c100000-0000-4000-8000-000000000101',now(),now(),'aal2',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values
 ('8c100000-0000-4000-8000-000000000301');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('8c100000-0000-4000-8000-000000000401','8c100000-0000-4000-8000-000000000301','8c100000-0000-4000-8000-000000000101');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '8c100000-0000-4000-8000-000000000501','8c100000-0000-4000-8000-000000000301',id,'platform'
from public.platform_roles where code='owner';
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select role_record.id,permission_record.id,'allow','active'
from public.platform_roles role_record cross join public.platform_permissions permission_record
where role_record.code='owner' and permission_record.code in('activities.manage','activities.link_units')
on conflict(role_id,permission_id) do update set effect='allow',status='active',revoked_at=null;
select set_config('request.jwt.claims',jsonb_build_object(
 'sub','8c100000-0000-4000-8000-000000000101',
 'session_id','8c100000-0000-4000-8000-000000000201',
 'aal','aal2','role','authenticated')::text,true);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8c100000-0000-4000-8000-000000000301',
 'internal_auth_link_id','8c100000-0000-4000-8000-000000000401',
 'internal_membership_id','8c100000-0000-4000-8000-000000000501',
 'auth_user_id','8c100000-0000-4000-8000-000000000101',
 'session_id','8c100000-0000-4000-8000-000000000201',
 'permission_code','activities.manage','action_code','manage',
 'correlation_id',gen_random_uuid())::text,true);
insert into public.activity_definitions(
 id,institution_id,name,description,handle_stem,origin_scope_kind,
 created_by_person_id,status,management_version
) values(
 '8c100000-0000-4000-8000-000000000701',
 '8c100000-0000-4000-8000-000000000010',
 'Concurrency Original','Synthetic fixture','concurrency-original',
 'institution',null,'draft',1
);
select set_config('app_private.activity_v2_internal_marker',jsonb_build_object(
 'internal_identity_id','8c100000-0000-4000-8000-000000000301',
 'internal_auth_link_id','8c100000-0000-4000-8000-000000000401',
 'internal_membership_id','8c100000-0000-4000-8000-000000000501',
 'auth_user_id','8c100000-0000-4000-8000-000000000101',
 'session_id','8c100000-0000-4000-8000-000000000201',
 'permission_code','activities.link_units','action_code','link_units',
 'correlation_id',gen_random_uuid())::text,true);
insert into public.activity_unit_links(
 activity_id,institution_id,unit_id,linked_by_person_id,status
) values(
 '8c100000-0000-4000-8000-000000000701',
 '8c100000-0000-4000-8000-000000000010',
 '8c100000-0000-4000-8000-000000000011',null,'active'
);
commit;
'@

$claims = '{"sub":"8c100000-0000-4000-8000-000000000101","session_id":"8c100000-0000-4000-8000-000000000201","aal":"aal2","role":"authenticated"}'
function New-CommandSql([string]$RequestId,[string]$Name) {
  return @"
set role authenticated;
set statement_timeout='20s';
set lock_timeout='15s';
select pg_sleep(1);
with configured as materialized (
 select set_config('request.jwt.claims','$claims',false)
)
select public.superadmin_activity_update_v2(
 '$RequestId',
 '8c100000-0000-4000-8000-000000000701',
 1,
 jsonb_build_object('name','$Name')
)::text
from configured;
"@
}

function New-VerificationSql(
  [guid]$ConflictCorrelationId
) {
  return @"
select jsonb_build_object(
 'management_version',(select management_version from public.activity_definitions where id='8c100000-0000-4000-8000-000000000701'),
 'receipt_count',(select count(*) from app_private.superadmin_internal_activity_command_receipts where request_id in(
   '8c100000-0000-4000-8000-000000000801','8c100000-0000-4000-8000-000000000802')),
 'audit_count',(select count(*) from audit.audit_logs log_record
   join app_private.superadmin_internal_activity_command_receipts receipt
     on receipt.correlation_id=log_record.correlation_id
    where receipt.request_id in(
      '8c100000-0000-4000-8000-000000000801','8c100000-0000-4000-8000-000000000802')
      and log_record.outcome='success'),
 'denial_audit_count',(select count(*) from audit.audit_logs log_record
   where log_record.correlation_id='$ConflictCorrelationId'
     and log_record.outcome='denied'
     and log_record.reason_code='SAI_CONCURRENT_CHANGE'
     and log_record.action_code='activity.update')
)::text;
"@
}

try {
  $setupProcess = Start-IsolatedPsql $fixtureSql
  $setupResult = Complete-IsolatedPsql $setupProcess
  if ($setupResult.Error -match '(?i)deadlock') {
    throw 'Activity v2 fixture encountered a deadlock'
  }

  $sessionA = Start-IsolatedPsql (New-CommandSql '8c100000-0000-4000-8000-000000000801' 'Concurrent A')
  $sessionB = Start-IsolatedPsql (New-CommandSql '8c100000-0000-4000-8000-000000000802' 'Concurrent B')
  $resultA = Complete-IsolatedPsql $sessionA
  $resultB = Complete-IsolatedPsql $sessionB

  $combinedOutput = $resultA.Output + $resultA.Error + $resultB.Output + $resultB.Error
  if ($combinedOutput -match '(?i)deadlock') {
    throw 'Activity v2 concurrent commands encountered a deadlock'
  }
  $responses = @(
    (Get-JsonResult $resultA.Output),
    (Get-JsonResult $resultB.Output)
  )
  $successes = @($responses | Where-Object { $_.ok -eq $true })
  $conflicts = @($responses | Where-Object {
    $_.ok -eq $false -and $_.error.code -eq 'SAI_CONCURRENT_CHANGE'
  })
  if ($successes.Count -ne 1 -or $conflicts.Count -ne 1 -or
      [int64]$successes[0].data.management_version -ne 2) {
    throw 'Activity v2 concurrency did not produce one winner and one version conflict'
  }
  $conflictCorrelationId = [guid]$conflicts[0].error.correlation_id

  $verifyProcess = Start-IsolatedPsql (New-VerificationSql $conflictCorrelationId)
  $verification = Get-JsonResult (Complete-IsolatedPsql $verifyProcess).Output
  if ([int64]$verification.management_version -ne 2 -or
      [int64]$verification.receipt_count -ne 1 -or
      [int64]$verification.audit_count -ne 1 -or
      [int64]$verification.denial_audit_count -ne 1) {
    throw 'Activity v2 concurrency durable invariants failed'
  }
}
finally {
  foreach ($process in $processes) {
    if (-not $process.HasExited) {
      try { $process.Kill() } catch { }
    }
    $process.Dispose()
  }
}

'Activity v2 concurrency passed: one winner, one version conflict, one receipt, one success audit and one denied audit.'
