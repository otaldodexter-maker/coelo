[CmdletBinding()]
param(
  [switch]$DescribeOnly,
  [string]$ProjectRoot,
  [ValidatePattern('^coelo_safe_[a-f0-9]{29}$')][string]$ProjectId
)
$ErrorActionPreference='Stop'
$cases=@('create','update','delete','duplicate')
if ($DescribeOnly) { return [pscustomobject]@{Actions=$cases; Cases=12; SqlExecuted=$false; Cleanup='parent-owned disposable replay volume'} }
if (-not $ProjectRoot -or -not $ProjectId) { throw 'MODELS_LOCAL_INPUT_REQUIRED' }
$projectFull=[IO.Path]::GetFullPath($ProjectRoot)
$marker=Join-Path $projectFull '.coelo-safe-replay'
if (-not (Test-Path -LiteralPath $marker -PathType Leaf) -or
    [IO.File]::ReadAllText($marker) -cne $ProjectId -or
    ((Get-Item -LiteralPath $projectFull).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
    ((Get-Item -LiteralPath $marker).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'MODELS_OWNED_REPLAY_REQUIRED' }
$dockerPath=(Get-Command docker -ErrorAction Stop).Source
$containerName="supabase_db_$ProjectId"
$running=@(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') { throw 'MODELS_LOCAL_CONTAINER_REQUIRED' }
$processes=[Collections.Generic.List[Diagnostics.Process]]::new()
$results=[Collections.Generic.List[object]]::new()
function Start-Psql([string]$Sql,[switch]$KeepOpen) {
  $info=[Diagnostics.ProcessStartInfo]::new()
  $info.FileName=$dockerPath
  $info.Arguments="exec -i $containerName psql --no-psqlrc --set ON_ERROR_STOP=1 --set VERBOSITY=verbose --tuples-only --no-align --username postgres --dbname postgres"
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true
  $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new(); $p.StartInfo=$info
  if (-not $p.Start()) { throw 'MODELS_PSQL_START_FAILED' }
  $processes.Add($p)
  $p.StandardInput.WriteLine("set statement_timeout='12s'; $Sql"); $p.StandardInput.Flush()
  if (-not $KeepOpen) { $p.StandardInput.Close() }
  return $p
}
function Finish-Psql([Diagnostics.Process]$Process) {
  if (-not $Process.WaitForExit(15000)) { try {$Process.Kill()} catch {}; throw 'MODELS_SQL_TIMEOUT' }
  $stdout=$Process.StandardOutput.ReadToEnd(); $stderr=$Process.StandardError.ReadToEnd()
  if ($Process.ExitCode -ne 0) {
    $state='unknown'; if ($stderr -match '(?:ERROR|FATAL):\s+([0-9A-Z]{5}):') {$state=$Matches[1]}
    throw "MODELS_SQL_FAILED phase=$phase sqlstate=$state"
  }
  return $stdout
}
function Parse-Json([string]$Output) {
  $lines=@($Output -split "`r?`n" | Where-Object {$_.TrimStart().StartsWith('{')})
  if ($lines.Count -ne 1) { throw 'MODELS_INVALID_RESULT' }
  return $lines[0] | ConvertFrom-Json
}
function Read-Json([string]$Sql) { return Parse-Json (Finish-Psql (Start-Psql $Sql)) }
function Wait-Condition([string]$Sql) {
  $timer=[Diagnostics.Stopwatch]::StartNew()
  do { if ((Read-Json $Sql).ready -eq $true) {return}; Start-Sleep -Milliseconds 50 } while ($timer.ElapsedMilliseconds -lt 5000)
  throw "MODELS_LOCK_NOT_OBSERVED phase=$phase"
}
$actor=[guid]::NewGuid().ToString(); $session=[guid]::NewGuid().ToString(); $identity=[guid]::NewGuid().ToString()
function Invoke-Model([string]$Expression) {
  # Suppress the set_config row, leaving exactly the public RPC envelope.
  return Read-Json "do `$claims`$ begin perform set_config('request.jwt.claims',jsonb_build_object('sub','$actor','session_id','$session','aal','aal1','role','authenticated','exp',extract(epoch from now()+interval '1 hour'))::text,false); end `$claims`$; set role authenticated; select $Expression;"
}
$phase='fixture'; $permission=''; $savedStatus=''
try {
  $null=Finish-Psql (Start-Psql @"
begin;
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data)
values('$actor','authenticated','authenticated','models-concurrency-$actor@invalid.test',now(),now(),now(),'{}','{}');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('$session','$actor',now(),now(),'aal1',now()+interval '1 hour');
insert into app_private.superadmin_internal_identities(id) values('$identity');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id) values(gen_random_uuid(),'$identity','$actor');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind)
select gen_random_uuid(),'$identity',id,'platform' from public.platform_roles where code='owner' and status='active';
commit;
"@)
  foreach ($action in $cases) {
    $phase="$action-seed"
    $request=[guid]::NewGuid().ToString()
    $draft="jsonb_build_object('domain','platform','name','Synthetic Models $request','max_scope_kind','platform','capabilities','[]'::jsonb,'reason','Local concurrency proof')"
    if ($action -ne 'create') {
      $seed=Invoke-Model "public.superadmin_access_profile_model_create(gen_random_uuid(),$draft)"
      if ($seed.ok -ne $true) {throw "MODELS_SEED_FAILED code=$($seed.error.code)"}
      $modelId=$seed.data.model_id
    }
    $expression=switch ($action) {
      'create' {"public.superadmin_access_profile_model_create('$request',$draft)"}
      'update' {"public.superadmin_access_profile_model_update('$request',jsonb_build_object('id','$modelId','name','Synthetic updated $request','expected_version',1,'capabilities','[]'::jsonb,'reason','Local concurrency proof'))"}
      'delete' {"public.superadmin_access_profile_model_delete('$request','$modelId',1,'Local concurrency proof')"}
      'duplicate' {"public.superadmin_access_profile_model_duplicate('$request',jsonb_build_object('source_model_id','$modelId','name','Synthetic duplicate $request','reason','Local concurrency proof'))"}
    }
    $initial=Invoke-Model $expression
    if ($initial.ok -ne $true -or $initial.data.replayed -ne $false) {throw "MODELS_INITIAL_FAILED action=$action code=$($initial.error.code)"}
    $permission="platform.role_models.$(if ($action -eq 'duplicate') {'create'} else {$action})"
    $savedStatus=(Read-Json "select jsonb_build_object('status',status) from public.platform_permissions where code='$permission';").status
    if ($savedStatus -ne 'active') {throw 'MODELS_ACTIVE_PERMISSION_REQUIRED'}
    foreach ($scenario in @('allowed','session','capability')) {
      $phase="$action-$scenario"
      $before=Read-Json "select jsonb_build_object('model',to_jsonb(t),'receipt',to_jsonb(r),'audits',(select count(*) from audit.audit_logs where actor_internal_identity_id='$identity' and outcome='success')) from public.access_profile_templates t cross join app_private.access_profile_model_command_receipts r where t.id='$($initial.data.model_id)' and r.request_id='$request';"
      $holderName="models_holder_$request"; $callerName="models_caller_$request"
      $holder=Start-Psql -KeepOpen "set application_name='$holderName'; begin; select pg_advisory_xact_lock(hashtextextended('coelo.access-profile-model:$request',0));"
      Wait-Condition "select jsonb_build_object('ready',exists(select 1 from pg_stat_activity where application_name='$holderName' and state='idle in transaction'));"
      $caller=Start-Psql "set application_name='$callerName'; do `$claims`$ begin perform set_config('request.jwt.claims',jsonb_build_object('sub','$actor','session_id','$session','aal','aal1','role','authenticated','exp',extract(epoch from now()+interval '1 hour'))::text,false); end `$claims`$; set role authenticated; select $expression;"
      Wait-Condition "select jsonb_build_object('ready',exists(select 1 from pg_stat_activity c join pg_stat_activity h on h.pid=any(pg_blocking_pids(c.pid)) where c.application_name='$callerName' and h.application_name='$holderName' and c.wait_event_type='Lock'));"
      if ($scenario -eq 'session') {$null=Finish-Psql (Start-Psql "update auth.sessions set not_after=clock_timestamp()-interval '1 hour' where id='$session';")}
      if ($scenario -eq 'capability') {$null=Finish-Psql (Start-Psql "update public.platform_permissions set status='inactive' where code='$permission';")}
      $holder.StandardInput.WriteLine('rollback;'); $holder.StandardInput.Close(); $null=Finish-Psql $holder
      $actual=Parse-Json (Finish-Psql $caller)
      $after=Read-Json "select jsonb_build_object('model',to_jsonb(t),'receipt',to_jsonb(r),'audits',(select count(*) from audit.audit_logs where actor_internal_identity_id='$identity' and outcome='success')) from public.access_profile_templates t cross join app_private.access_profile_model_command_receipts r where t.id='$($initial.data.model_id)' and r.request_id='$request';"
      $unchanged=($before | ConvertTo-Json -Depth 30 -Compress) -ceq ($after | ConvertTo-Json -Depth 30 -Compress)
      $expected=if ($scenario -eq 'session') {'SAI_SESSION_INVALID'} elseif ($scenario -eq 'capability') {'SAI_PERMISSION_DENIED'} else {'replayed'}
      $passed=if ($scenario -eq 'allowed') {$actual.ok -eq $true -and $actual.data.replayed -eq $true -and $unchanged} else {$actual.ok -eq $false -and $actual.error.code -eq $expected -and $null -eq $actual.data -and $unchanged}
      $observed=if ($actual.ok) {'replayed'} else {$actual.error.code}
      $results.Add([pscustomobject]@{Case="$action-$scenario";Status=$(if ($passed) {'PASS'} else {'FAIL'});Expected=$expected;Observed=$observed;LockObserved=$true;Unchanged=$unchanged})
      Write-Host "MODELS_CASE action=$action scenario=$scenario pass=$passed observed=$observed unchanged=$unchanged"
      $null=Finish-Psql (Start-Psql "begin; update auth.sessions set not_after=clock_timestamp()+interval '1 hour' where id='$session'; update public.platform_permissions set status='$savedStatus' where code='$permission'; commit;")
    }
  }
} finally {
  foreach ($p in $processes) {try {if (-not $p.HasExited) {$p.StandardInput.Close(); if (-not $p.WaitForExit(1000)) {$p.Kill()}}} catch {}}
  if ($savedStatus -eq 'active' -and $permission) {$null=Finish-Psql (Start-Psql "update public.platform_permissions set status='active' where code='$permission';")}
  foreach ($p in $processes) {$p.Dispose()}
}
$failed=@($results | Where-Object Status -eq 'FAIL').Count
[pscustomobject]@{P=$results.Count-$failed;F=$failed;B=0;S=0;U=12-$results.Count;Cases=@($results.ToArray());Cleanup='owned psql closed; permission restored; synthetic rows require parent replay volume teardown'}
if ($failed) {throw 'MODELS_RECEIPT_REAUTH_REGRESSION'}
