[CmdletBinding()]
param(
  [switch]$DescribeOnly,
  [string]$ProjectRoot,
  [ValidatePattern('^coelo_safe_[a-f0-9]{29}$')][string]$ProjectId,
  [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedExecutorSha256
)
$ErrorActionPreference='Stop'
$executorPath=Join-Path $PSScriptRoot 'r02-d01-auth-proof-executor.mjs'
$executorHash=(Get-FileHash -LiteralPath $executorPath -Algorithm SHA256).Hash
$cases=@('provision-membership','provision-session','provision-jwt','cleanup-membership','cleanup-session','cleanup-jwt')
if ($DescribeOnly) {
  return [pscustomobject]@{Cases=$cases; ExecutorSha256=$executorHash; SqlExecuted=$false; Cleanup='owned replay volume via parent wrapper'}
}
if (-not $ProjectRoot -or -not $ProjectId -or -not $ExpectedExecutorSha256) { throw 'AUTH_PROOF_LOCAL_INPUT_REQUIRED' }
$projectFull=[IO.Path]::GetFullPath($ProjectRoot)
$marker=Join-Path $projectFull '.coelo-safe-replay'
if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or
    [IO.File]::ReadAllText($marker) -cne $ProjectId -or
    ((Get-Item -LiteralPath $projectFull).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    ((Get-Item -LiteralPath $marker).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'AUTH_PROOF_OWNED_REPLAY_REQUIRED' }
if ($executorHash -ne $ExpectedExecutorSha256) { throw 'AUTH_PROOF_EXECUTOR_HASH_MISMATCH' }
$dockerPath=(Get-Command docker -ErrorAction Stop).Source
$nodePath=(Get-Command node -ErrorAction Stop).Source
$containerName="supabase_db_$ProjectId"
$running=@(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') { throw 'AUTH_PROOF_LOCAL_CONTAINER_REQUIRED' }
$processes=[Collections.Generic.List[Diagnostics.Process]]::new()
$results=[Collections.Generic.List[object]]::new()
$actor='a9020000-0000-4000-8000-000000000101'
$session='a9020000-0000-4000-8000-000000000201'
$identity='a9020000-0000-4000-8000-000000000301'
$membership='a9020000-0000-4000-8000-000000000501'
$mailbox='r02-auth-proof@invalid.test'
# Imports the real executor without invoking its CLI; emits only local SQL/IDs.
$generator=@'
import {pathToFileURL} from 'node:url';
const {mutationSql,plan}=await import(pathToFileURL(process.argv[2]));
const [action,exp]=process.argv.slice(3);
const actor={sub:'a9020000-0000-4000-8000-000000000101',session_id:'a9020000-0000-4000-8000-000000000201',aal:'aal1',exp:Number(exp)};
console.log(JSON.stringify({plan,sql:mutationSql(action,'r02-auth-proof@invalid.test',actor)}));
'@
function New-ActualCommand([string]$Action,[double]$Expires) {
  if ((Get-FileHash -LiteralPath $executorPath -Algorithm SHA256).Hash -ne $executorHash) { throw 'AUTH_PROOF_EXECUTOR_CHANGED' }
  # argv[1] must differ from the imported module, whose entrypoint guard uses it.
  $output=@(& $nodePath --input-type=module -e $generator 'r02-auth-proof-generator' $executorPath $Action ($Expires.ToString('R',[Globalization.CultureInfo]::InvariantCulture)) 2>$null)
  if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { throw 'AUTH_PROOF_GENERATION_FAILED' }
  return $output[0] | ConvertFrom-Json
}
function Start-Psql([string]$Sql,[switch]$KeepOpen) {
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$dockerPath
  $info.Arguments="exec -i $containerName psql --no-psqlrc --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --tuples-only --no-align --username postgres --dbname postgres"
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new(); $p.StartInfo=$info
  if (-not $p.Start()) { throw 'AUTH_PROOF_PSQL_START_FAILED' }
  $processes.Add($p)
  $p.StandardInput.WriteLine($Sql); $p.StandardInput.Flush()
  if (-not $KeepOpen) { $p.StandardInput.Close() }
  return $p
}
function Get-SqlDiagnostic([string]$StandardError) {
  $first=@($StandardError -split "`r?`n" | Where-Object {$_ -match '(?:ERROR|FATAL):'} | Select-Object -First 1)
  $state='unknown'; $message='unclassified local database error'
  if ($first.Count -eq 1) {
    if ($first[0] -match '(?:ERROR|FATAL):\s+([0-9A-Z]{5}):') { $state=$Matches[1] }
    # Only allowlisted error text is emitted; never arbitrary DETAIL/CONTEXT/SQL.
    foreach ($known in @('revoked internal access is terminal','internal membership version mismatch','last active platform owner is protected','LOCAL_FIXTURE_COLLISION','AUTH_BASE_REQUIRED','AUTH_OWNER_ROLE_REQUIRED','AUTH_OPERATIONS_ROLE_REQUIRED','LIVE_OWNER_REQUIRED','SAI_MEMBERSHIP_REVOKED','SAI_SESSION_INVALID','lock timeout','statement timeout','deadlock detected')) {
      if ($first[0].Contains($known)) { $message=$known; break }
    }
  }
  return "sqlstate=$state error=$message"
}
function Finish-Psql([Diagnostics.Process]$Process,[switch]$ExpectDenial) {
  if (-not $Process.WaitForExit(12000)) { try {$Process.Kill()} catch {}; throw 'AUTH_PROOF_SQL_TIMEOUT' }
  $stdout=$Process.StandardOutput.ReadToEnd(); $stderr=$Process.StandardError.ReadToEnd()
  if ($ExpectDenial) {
    if ($Process.ExitCode -eq 0 -or $stderr -notmatch 'LIVE_OWNER_REQUIRED|SAI_MEMBERSHIP_REVOKED|SAI_SESSION_INVALID' -or
        $stderr -match 'lock timeout|deadlock|statement timeout') { throw "AUTH_PROOF_EXPECTED_DENIAL_NOT_OBSERVED phase=$proofPhase case=$proofCase $(Get-SqlDiagnostic $stderr)" }
  } elseif ($Process.ExitCode -ne 0) { throw "AUTH_PROOF_LOCAL_SQL_FAILED phase=$proofPhase case=$proofCase $(Get-SqlDiagnostic $stderr)" }
  return $stdout
}
function Read-Json([string]$Sql) {
  $output=Finish-Psql (Start-Psql $Sql)
  $lines=@($output -split "`r?`n" | Where-Object {$_.TrimStart().StartsWith('{')})
  if ($lines.Count -ne 1) { throw 'AUTH_PROOF_INVALID_RECEIPT' }
  return $lines[0] | ConvertFrom-Json
}
function Wait-Condition([string]$Sql) {
  $timer=[Diagnostics.Stopwatch]::StartNew()
  do {
    if ((Read-Json $Sql).ready -eq $true) { return }
    Start-Sleep -Milliseconds 50
  } while ($timer.ElapsedMilliseconds -lt 3500)
  throw 'AUTH_PROOF_WAIT_NOT_OBSERVED'
}
$plan=(New-ActualCommand 'provision' ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+3600)).plan
$authId=$plan.authUserId; $targetIdentity=$plan.identityId; $targetLink=$plan.authLinkId; $targetMembership=$plan.membershipId; $roleId=$plan.roleId
$fixtureReady=$false
$proofPhase='fixture'; $proofCase='none'
try {
  # This transaction changes only the disposable local database. A second Owner
  # keeps the last-owner protection enabled when the actor is revoked.
  $null=Finish-Psql (Start-Psql @"
begin;
do `$preflight`$
begin
 if current_user<>'postgres' or to_regprocedure('app_private.require_superadmin_internal_context(text)') is null then raise exception 'AUTH_BASE_REQUIRED'; end if;
 if exists(select 1 from auth.users where id in('$actor','$authId','a9020000-0000-4000-8000-000000000102'))
 or exists(select 1 from app_private.superadmin_internal_identities where id in('$identity','$targetIdentity','a9020000-0000-4000-8000-000000000302'))
 or exists(select 1 from app_private.superadmin_internal_memberships where id in('$membership','$targetMembership','a9020000-0000-4000-8000-000000000502','a9020000-0000-4000-8000-000000000503'))
 or exists(select 1 from public.platform_roles where id='$roleId' or code in('r02-saved-operations','r02-proof-operations'))
 then raise exception 'LOCAL_FIXTURE_COLLISION'; end if;
 if (select count(*) from public.platform_roles where code='owner' and status='active')<>1 then raise exception 'AUTH_OWNER_ROLE_REQUIRED'; end if;
 if (select count(*) from public.platform_roles where code='operations' and status='active')<>1 then raise exception 'AUTH_OPERATIONS_ROLE_REQUIRED'; end if;
end `$preflight`$;
update public.platform_roles set code='r02-saved-operations' where code='operations';
insert into public.platform_roles(id,code,name,status,max_scope_kind) values('$roleId','operations','R02 synthetic operations','active','platform');
insert into public.platform_role_permissions(role_id,permission_id,effect,status)
select '$roleId',id,'allow','active' from public.platform_permissions where code='platform.read';
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,banned_until) values
 ('$actor','authenticated','authenticated','r02-owner@invalid.test',now(),now(),now(),'{}','{}',null),
 ('a9020000-0000-4000-8000-000000000102','authenticated','authenticated','r02-spare@invalid.test',now(),now(),now(),'{}','{}',null),
 ('$authId','authenticated','authenticated','$mailbox',now(),now(),now(),jsonb_build_object('coelo_e2_package','$($plan.package)','coelo_e2_plan','$($plan.planId)','coelo_e2_persona','$($plan.persona)'),'{}',now()+interval '1 day');
insert into auth.sessions(id,user_id,aal,created_at,updated_at,not_after) values('$session','$actor','aal1',now(),now(),now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values('$identity'),('a9020000-0000-4000-8000-000000000302');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values
 ('a9020000-0000-4000-8000-000000000401','$identity','$actor'),
 ('a9020000-0000-4000-8000-000000000402','a9020000-0000-4000-8000-000000000302','a9020000-0000-4000-8000-000000000102');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select v.id::uuid,v.identity::uuid,r.id,'platform' from public.platform_roles r cross join (values
 ('$membership','$identity'),('a9020000-0000-4000-8000-000000000502','a9020000-0000-4000-8000-000000000302')) v(id,identity) where r.code='owner' and r.status='active';
commit;
"@)
  $fixtureReady=$true
  foreach ($action in @('provision','cleanup')) {
    if ($action -eq 'cleanup') {
      $proofPhase='cleanup-fixture'; $proofCase='none'
      # Revocation is terminal. Append a new active membership for this action.
      $membership='a9020000-0000-4000-8000-000000000503'
      $null=Finish-Psql (Start-Psql @"
begin;
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select '$membership','$identity',id,'platform' from public.platform_roles where code='owner' and status='active';
insert into app_private.superadmin_internal_identities(id,created_by_internal_identity_id) values('$targetIdentity','$identity');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values('$targetLink','$targetIdentity','$authId');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind) values('$targetMembership','$targetIdentity','$roleId','platform');
insert into auth.sessions(id,user_id,aal,created_at,updated_at) values('a9020000-0000-4000-8000-000000000202','$authId','aal1',now(),now());
commit;
"@)
    }
    foreach ($scenario in @('session','jwt','membership')) {
      $case="$action-$scenario"; $holderName="r02_auth_holder_$scenario"; $callerName="r02_auth_caller_$scenario"
      $proofCase=$case; $proofPhase='prepare-case'
      $null=Finish-Psql (Start-Psql "update auth.sessions set not_after=clock_timestamp()+interval '1 hour' where id='$session';")
      $proofPhase='acquire-holder'
      $holder=Start-Psql -KeepOpen -Sql "set application_name='$holderName'; begin; select id from auth.users where id='$authId' for update;"
      Wait-Condition "select jsonb_build_object('ready',exists(select 1 from pg_stat_activity where application_name='$holderName' and state='idle in transaction'))::text;"
      $expiry=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()/1000+3
      if ($scenario -eq 'session') { $null=Finish-Psql (Start-Psql "update auth.sessions set not_after=to_timestamp($($expiry.ToString('R',[Globalization.CultureInfo]::InvariantCulture))) where id='$session';") }
      $jwtExpiry=if ($scenario -eq 'jwt') {$expiry} else {$expiry+3600}
      $command=New-ActualCommand $action $jwtExpiry
      $proofPhase='observe-caller-lock'
      $caller=Start-Psql "set application_name='$callerName'; $($command.sql)"
      Wait-Condition "select jsonb_build_object('ready',exists(select 1 from pg_stat_activity c join pg_stat_activity h on h.pid=any(pg_blocking_pids(c.pid)) where c.application_name='$callerName' and h.application_name='$holderName' and c.wait_event_type='Lock'))::text;"
      if ($scenario -eq 'membership') {
        $proofPhase='revoke-actor'
        $null=Finish-Psql (Start-Psql "update app_private.superadmin_internal_memberships set status='revoked',revoked_at=clock_timestamp(),version=version+1 where id='$membership';")
      } else {
        $proofPhase='await-expiry'
        Wait-Condition "select jsonb_build_object('ready',extract(epoch from clock_timestamp()) >= $($expiry.ToString('R',[Globalization.CultureInfo]::InvariantCulture)))::text;"
      }
      $proofPhase='release-holder'
      $holder.StandardInput.WriteLine('rollback;'); $holder.StandardInput.Close(); $null=Finish-Psql $holder
      $proofPhase='verify-denial'
      $null=Finish-Psql $caller -ExpectDenial
      $proofPhase='verify-unchanged'
      $expectedCount=if ($action -eq 'cleanup') {1} else {0}
      $receipt=Read-Json @"
select jsonb_build_object('unchanged',
 (select count(*) from app_private.superadmin_internal_identities where id='$targetIdentity')=$expectedCount
 and (select count(*) from app_private.superadmin_internal_auth_links where id='$targetLink')=$expectedCount
 and (select count(*) from app_private.superadmin_internal_memberships where id='$targetMembership')=$expectedCount
 and not exists(select 1 from app_private.superadmin_internal_auth_links where id='$targetLink' and (status<>'active' or version<>1))
 and not exists(select 1 from app_private.superadmin_internal_memberships where id='$targetMembership' and (status<>'active' or version<>1))
 and (select count(*) from auth.sessions where user_id='$authId')=$expectedCount
 and not exists(select 1 from audit.audit_logs where action_code in('e2.r02.auth.provision','e2.r02.auth.cleanup') and outcome='success'),
 'clock',clock_timestamp())::text;
"@
      if ($receipt.unchanged -ne $true) { throw 'AUTH_PROOF_UNEXPECTED_EFFECT' }
      $sha=[Security.Cryptography.SHA256]::Create()
      try {$sqlHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($command.sql)))).Replace('-','')} finally {$sha.Dispose()}
      $results.Add([pscustomobject]@{Case=$case;Status='PASS';LockObserved=$true;Unchanged=$true;SqlSha256=$sqlHash;Clock=$receipt.clock})
      Write-Host "AUTH_PROOF_CASE_PASS case=$case sql_sha256=$sqlHash completed=$($results.Count)"
    }
  }
} catch {
  Write-Host "AUTH_PROOF_CASE_FAIL phase=$proofPhase case=$proofCase completed=$($results.Count)"
  throw
} finally {
  foreach ($p in $processes) { try {if (-not $p.HasExited) {$p.StandardInput.Close(); if (-not $p.WaitForExit(1000)) {$p.Kill()}}} catch {} }
  # Restore seeded role names even on failure. Synthetic rows remain only in the
  # owned disposable volume; the parent wrapper tears that volume down.
  if ($fixtureReady) {
    $proofPhase='restore-role-names'; $proofCase='none'
    $null=Finish-Psql (Start-Psql "begin; update public.platform_roles set code='r02-proof-operations' where id='$roleId' and code='operations'; update public.platform_roles set code='operations' where code='r02-saved-operations'; commit;")
  }
  foreach ($p in $processes) {$p.Dispose()}
}
[pscustomobject]@{P=$results.Count;F=0;B=0;S=0;U=6-$results.Count;ExecutorSha256=$executorHash;Cases=@($results.ToArray());Cleanup='psql closed; role names restored; synthetic rows owned by disposable replay teardown'}
