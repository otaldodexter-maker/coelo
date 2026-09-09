[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^coelo_safe_[0-9a-f]{29}$')]
  [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
$cliPackage = 'supabase@2.116.0'
$projectFull = [IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $projectFull '.coelo-safe-replay'
$containerName = "supabase_db_$ProjectId"
$dockerPath = (Get-Command docker -ErrorAction Stop).Source
$httpHandler = $null
$httpClient = $null

function Assert-NoReparseAncestors([string]$Path) {
  $cursor = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      throw 'CHILD HTTP local path contains a reparse point'
    }
    $cursor = $cursor.Parent
  }
}

function Get-LocalHttpEnvironment {
  $statusLines = @(
    & npx.cmd --yes $cliPackage --agent no status --workdir $projectFull --output env
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'CHILD HTTP local could not read isolated Supabase status'
  }
  $environment = @{}
  foreach ($line in $statusLines) {
    if ($line -match '^(API_URL|ANON_KEY)="(.*)"$') {
      $environment[$Matches[1]] = $Matches[2]
    }
  }
  foreach ($requiredName in @('API_URL', 'ANON_KEY')) {
    if (-not $environment.ContainsKey($requiredName) -or
        [string]::IsNullOrWhiteSpace($environment[$requiredName])) {
      throw "CHILD HTTP local status omitted $requiredName"
    }
  }
  $apiUri = [uri]$environment.API_URL
  if (-not $apiUri.IsAbsoluteUri -or $apiUri.Scheme -ne 'http' -or
      $apiUri.Host -ne '127.0.0.1' -or $apiUri.Port -le 0 -or
      $apiUri.AbsolutePath -ne '/' -or $apiUri.UserInfo -ne '' -or
      $apiUri.Query -ne '' -or $apiUri.Fragment -ne '') {
    throw 'CHILD HTTP local API URL must be an explicit loopback endpoint'
  }
  [pscustomobject]@{ ApiUrl = $apiUri.AbsoluteUri.TrimEnd('/'); AnonKey = $environment.ANON_KEY }
}

function Invoke-LocalJsonRequest(
  [string]$Method,
  [string]$Uri,
  [hashtable]$Headers,
  [hashtable]$Body
) {
  $requestUri = [uri]$Uri
  if ($requestUri.Scheme -ne 'http' -or $requestUri.Host -ne '127.0.0.1') {
    throw 'CHILD HTTP local refused a non-loopback request'
  }
  $request = [Net.Http.HttpRequestMessage]::new(
    [Net.Http.HttpMethod]::new($Method), $requestUri
  )
  try {
    foreach ($entry in $Headers.GetEnumerator()) {
      $null = $request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value)
    }
    $request.Content = [Net.Http.StringContent]::new(
      ($Body | ConvertTo-Json -Compress -Depth 8),
      [Text.Encoding]::UTF8,
      'application/json'
    )
    $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
    try {
      $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      if (-not $response.IsSuccessStatusCode) {
        throw "CHILD HTTP local request failed with HTTP $([int]$response.StatusCode)"
      }
      return $content | ConvertFrom-Json
    }
    finally {
      $response.Dispose()
    }
  }
  finally {
    $request.Dispose()
  }
}

function Invoke-OwnedContainerSql([string]$Sql, [string]$FailureMessage) {
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $dockerPath
  $startInfo.Arguments = "exec -i $containerName psql --no-psqlrc --set ON_ERROR_STOP=1 --tuples-only --no-align --username postgres --dbname postgres"
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw $FailureMessage }
    $process.StandardInput.WriteLine($Sql)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(20000)) {
      try { $process.Kill() } catch { }
      throw "$FailureMessage (timeout)"
    }
    $output = $process.StandardOutput.ReadToEnd()
    $null = $process.StandardError.ReadToEnd()
    if ($process.ExitCode -ne 0) { throw $FailureMessage }
    return $output
  }
  finally {
    $process.Dispose()
  }
}

function Assert-ChildPage(
  $Response,
  [string[]]$ExpectedContextIds,
  [string[]]$ExpectedPersonIds
) {
  $expectedCount = $ExpectedContextIds.Count
  if ($ExpectedPersonIds.Count -ne $expectedCount) {
    throw 'CHILD HTTP local test expectation is inconsistent'
  }
  if ($Response.ok -ne $true -or $null -eq $Response.data -or
      $null -ne $Response.error -or @($Response.data.items).Count -ne $ExpectedCount) {
    throw 'CHILD HTTP local returned an invalid success envelope'
  }
  $expectedFields = 'context_id,institution_id,institution_name,person_id,person_name'
  $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $items = @($Response.data.items)
  for ($index = 0; $index -lt $items.Count; $index++) {
    $item = $items[$index]
    $fields = @($item.psobject.Properties.Name | Sort-Object) -join ','
    try {
      $contextId = [guid]::Parse([string]$item.context_id).ToString()
      $personId = [guid]::Parse([string]$item.person_id).ToString()
      $institutionId = [guid]::Parse([string]$item.institution_id).ToString()
    }
    catch {
      throw 'CHILD HTTP local returned a non-UUID DTO identifier'
    }
    if ($fields -cne $expectedFields -or -not $ids.Add($contextId) -or
        $contextId -cne $ExpectedContextIds[$index] -or
        $personId -cne $ExpectedPersonIds[$index] -or
        $institutionId -cne '9d100000-0000-4000-8000-000000000010' -or
        $item.institution_name -cne 'CHILD HTTP Institution A') {
      throw 'CHILD HTTP local returned a malformed or duplicate DTO item'
    }
  }
}

function Assert-ChildDenial($Response, [string]$ExpectedCode) {
  if ($Response.ok -ne $false -or $null -ne $Response.data -or
      $Response.error.code -cne $ExpectedCode) {
    throw 'CHILD HTTP local denial released data or returned the wrong code'
  }
}

Assert-NoReparseAncestors $projectFull
if (-not (Test-Path -LiteralPath $projectFull -PathType Container) -or
    -not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw 'CHILD HTTP local requires the owned disposable replay project'
}
Assert-NoReparseAncestors $markerPath
if ([IO.File]::ReadAllText($markerPath) -ne $ProjectId) {
  throw 'CHILD HTTP local requires the owned disposable replay project'
}
$running = @(& $dockerPath inspect --format '{{.State.Running}}' $containerName 2>$null)
if ($LASTEXITCODE -ne 0 -or $running.Count -ne 1 -or $running[0].Trim() -ne 'true') {
  throw 'CHILD HTTP local database container is unavailable'
}

$preflightOutput = Invoke-OwnedContainerSql -FailureMessage 'CHILD HTTP local preflight failed' -Sql @'
select (
 (select count(*) from public.institutions where id in('9d100000-0000-4000-8000-000000000010','9d100000-0000-4000-8000-000000000011'))+
 (select count(*) from public.people where id in('9d100000-0000-4000-8000-000000000101','9d100000-0000-4000-8000-000000000102','9d100000-0000-4000-8000-000000000103','9d100000-0000-4000-8000-000000000104'))+
 (select count(*) from public.child_contexts where id in('9d100000-0000-4000-8000-000000000701','9d100000-0000-4000-8000-000000000702','9d100000-0000-4000-8000-000000000703','9d100000-0000-4000-8000-000000000704'))+
 (select count(*) from auth.users where id='9d100000-0000-4000-8000-000000000202')+
 (select count(*) from app_private.superadmin_internal_identities where id in('9d100000-0000-4000-8000-000000000401','9d100000-0000-4000-8000-000000000402'))+
 (select count(*) from app_private.superadmin_internal_auth_links where id in('9d100000-0000-4000-8000-000000000501','9d100000-0000-4000-8000-000000000502'))+
 (select count(*) from app_private.superadmin_internal_memberships where id in('9d100000-0000-4000-8000-000000000601','9d100000-0000-4000-8000-000000000602'))+
 (select count(*) from audit.audit_logs where actor_internal_identity_id in('9d100000-0000-4000-8000-000000000401','9d100000-0000-4000-8000-000000000402'))
)::text;
'@
$preflightValues = @($preflightOutput -split "`r?`n" | ForEach-Object { $_.Trim() } |
  Where-Object { $_ -match '^\d+$' })
if ($preflightValues.Count -ne 1 -or $preflightValues[0] -ne '0') {
  throw 'CHILD HTTP local requires a clean one-shot disposable database'
}

Add-Type -AssemblyName System.Net.Http
$httpHandler = [Net.Http.HttpClientHandler]::new()
$httpHandler.AllowAutoRedirect = $false
$httpHandler.UseProxy = $false
$httpClient = [Net.Http.HttpClient]::new($httpHandler, $false)
$httpClient.Timeout = [TimeSpan]::FromSeconds(20)
try {
  $environment = Get-LocalHttpEnvironment
  $publicHeaders = @{ apikey = $environment.AnonKey }
  $email = "child-http-$([guid]::NewGuid().ToString('N'))@example.invalid"
  $password = "Coelo-$([guid]::NewGuid().ToString('N'))-9!"
  $signup = Invoke-LocalJsonRequest -Method Post `
    -Uri "$($environment.ApiUrl)/auth/v1/signup" -Headers $publicHeaders `
    -Body @{ email = $email; password = $password }
  if ($null -eq $signup.user -or [string]::IsNullOrWhiteSpace($signup.access_token)) {
    throw 'CHILD HTTP local signup did not return the auto-confirmed local session'
  }
  $authUserId = [guid]::Parse([string]$signup.user.id).ToString()
  $accessToken = [string]$signup.access_token

  $null = Invoke-OwnedContainerSql -FailureMessage 'CHILD HTTP local fixture failed' -Sql @"
begin;
insert into public.institutions(id,public_name,slug,status) values
 ('9d100000-0000-4000-8000-000000000010','CHILD HTTP Institution A','child-http-a','active'),
 ('9d100000-0000-4000-8000-000000000011','CHILD HTTP Institution B','child-http-institution-b','active');
insert into public.people(id,person_type,first_name,last_name,display_name) values
 ('9d100000-0000-4000-8000-000000000101','child','Synthetic','Alfa','Alfa'),
 ('9d100000-0000-4000-8000-000000000102','child','Synthetic','Beta','Beta'),
 ('9d100000-0000-4000-8000-000000000103','child','Synthetic','Zulu','Zulu'),
 ('9d100000-0000-4000-8000-000000000104','child','Synthetic','Intrusa','Intrusa B');
insert into public.child_contexts(id,child_person_id,institution_id,status) values
 ('9d100000-0000-4000-8000-000000000701','9d100000-0000-4000-8000-000000000101','9d100000-0000-4000-8000-000000000010','active'),
 ('9d100000-0000-4000-8000-000000000702','9d100000-0000-4000-8000-000000000102','9d100000-0000-4000-8000-000000000010','active'),
 ('9d100000-0000-4000-8000-000000000703','9d100000-0000-4000-8000-000000000103','9d100000-0000-4000-8000-000000000010','active'),
 ('9d100000-0000-4000-8000-000000000704','9d100000-0000-4000-8000-000000000104','9d100000-0000-4000-8000-000000000011','active');
insert into app_private.superadmin_internal_identities(id) values
 ('9d100000-0000-4000-8000-000000000401'),
 ('9d100000-0000-4000-8000-000000000402');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status) values
 ('9d100000-0000-4000-8000-000000000501','9d100000-0000-4000-8000-000000000401','$authUserId','active');
insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data) values
 ('9d100000-0000-4000-8000-000000000202','authenticated','authenticated','child-http-backup@invalid.test',now(),now(),now(),'{}','{}');
insert into app_private.superadmin_internal_auth_links(id,internal_identity_id,auth_user_id,status) values
 ('9d100000-0000-4000-8000-000000000502','9d100000-0000-4000-8000-000000000402','9d100000-0000-4000-8000-000000000202','active');
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,scope_institution_id,status)
select '9d100000-0000-4000-8000-000000000601','9d100000-0000-4000-8000-000000000401',id,'institution','9d100000-0000-4000-8000-000000000010','active'
 from public.platform_roles where code='owner';
insert into app_private.superadmin_internal_memberships(id,internal_identity_id,platform_role_id,scope_kind,status)
select '9d100000-0000-4000-8000-000000000602','9d100000-0000-4000-8000-000000000402',id,'platform','active'
 from public.platform_roles where code='owner';
commit;
"@

  $authorizedHeaders = @{
    apikey = $environment.AnonKey
    Authorization = "Bearer $accessToken"
  }
  $rpcUri = "$($environment.ApiUrl)/rest/v1/rpc/superadmin_child_context_directory_v2"
  $firstPage = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{ p_limit = 2 }
  Assert-ChildPage $firstPage `
    @('9d100000-0000-4000-8000-000000000701','9d100000-0000-4000-8000-000000000702') `
    @('9d100000-0000-4000-8000-000000000101','9d100000-0000-4000-8000-000000000102')
  if ($firstPage.data.items[0].person_name -cne 'Alfa' -or
      $firstPage.data.items[1].person_name -cne 'Beta' -or
      $firstPage.data.next_cursor.name -cne 'beta' -or
      $firstPage.data.next_cursor.context_id -cne $firstPage.data.items[1].context_id) {
    throw 'CHILD HTTP local first page or cursor is invalid'
  }
  $secondPage = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{
      p_after_name = [string]$firstPage.data.next_cursor.name
      p_after_context_id = [string]$firstPage.data.next_cursor.context_id
      p_limit = 2
    }
  Assert-ChildPage $secondPage `
    @('9d100000-0000-4000-8000-000000000703') `
    @('9d100000-0000-4000-8000-000000000103')
  if ($secondPage.data.items[0].person_name -cne 'Zulu' -or
      $null -ne $secondPage.data.next_cursor) {
    throw 'CHILD HTTP local second page is invalid'
  }
  $reload = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{ p_limit = 2 }
  Assert-ChildPage $reload `
    @('9d100000-0000-4000-8000-000000000701','9d100000-0000-4000-8000-000000000702') `
    @('9d100000-0000-4000-8000-000000000101','9d100000-0000-4000-8000-000000000102')
  if (($reload | ConvertTo-Json -Compress -Depth 8) -cne
      ($firstPage | ConvertTo-Json -Compress -Depth 8)) {
    throw 'CHILD HTTP local reload did not restart the authoritative first page'
  }

  # tenant-b and unknown must expose the same public denial fields.
  $tenantBDenial = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{
      p_institution_id = '9d100000-0000-4000-8000-000000000011'; p_limit = 2
    }
  $unknownDenial = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{
      p_institution_id = '9d100000-0000-4000-8000-000000000099'; p_limit = 2
    }
  Assert-ChildDenial $tenantBDenial 'SAI_PERMISSION_DENIED'
  Assert-ChildDenial $unknownDenial 'SAI_PERMISSION_DENIED'
  if ($tenantBDenial.error.code -cne $unknownDenial.error.code -or
      $tenantBDenial.error.message -cne $unknownDenial.error.message -or
      $tenantBDenial.error.http_status -ne $unknownDenial.error.http_status) {
    throw 'CHILD HTTP local foreign and unknown institutions were distinguishable'
  }

  $null = Invoke-OwnedContainerSql -FailureMessage 'CHILD HTTP local revocation failed' -Sql @'
update app_private.superadmin_internal_memberships membership
set status='revoked',revoked_at=clock_timestamp(),version=membership.version+1
where membership.id='9d100000-0000-4000-8000-000000000601';
'@
  # The same token must be denied after the versioned terminal revocation.
  $revoked = Invoke-LocalJsonRequest -Method Post -Uri $rpcUri `
    -Headers $authorizedHeaders -Body @{ p_limit = 2 }
  Assert-ChildDenial $revoked 'SAI_MEMBERSHIP_REVOKED'

  $auditOutput = Invoke-OwnedContainerSql -FailureMessage 'CHILD HTTP local audit verification failed' -Sql @'
select jsonb_build_object(
 'success_count',(select count(*) from audit.audit_logs where actor_internal_identity_id='9d100000-0000-4000-8000-000000000401' and action_code='child_context.directory' and outcome='success'),
 'denied_count',(select count(*) from audit.audit_logs where actor_internal_identity_id='9d100000-0000-4000-8000-000000000401' and action_code='child_context.directory' and outcome='denied'),
 'payload_count',(select count(*) from audit.audit_logs where actor_internal_identity_id='9d100000-0000-4000-8000-000000000401' and action_code='child_context.directory' and (before_json is not null or after_json is not null)),
 'denied_institution_count',(select count(*) from audit.audit_logs where actor_internal_identity_id='9d100000-0000-4000-8000-000000000401' and action_code='child_context.directory' and outcome='denied' and institution_id is not null)
)::text;
'@
  $auditLines = @($auditOutput -split "`r?`n" | ForEach-Object { $_.Trim() } |
    Where-Object { $_.StartsWith('{') })
  if ($auditLines.Count -ne 1) {
    throw 'CHILD HTTP local audit verification returned an invalid shape'
  }
  $audit = $auditLines[0] | ConvertFrom-Json
  if ([int64]$audit.success_count -ne 3 -or [int64]$audit.denied_count -ne 3 -or
      [int64]$audit.payload_count -ne 0 -or
      [int64]$audit.denied_institution_count -ne 0) {
    throw 'CHILD HTTP local audit counts or minimization are invalid'
  }
}
finally {
  if ($null -ne $httpClient) { $httpClient.Dispose() }
  if ($null -ne $httpHandler) { $httpHandler.Dispose() }
}

'CHILD HTTP local PASS: canonical pagination and reload succeeded; foreign, unknown and revoked reads returned no data.'
