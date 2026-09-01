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
Add-Type -AssemblyName System.Net.Http

function Get-LocalSupabaseEnvironment {
  $statusLines = @(
    & npx.cmd --yes $cliPackage status --workdir $ProjectRoot --output env
  )
  if ($LASTEXITCODE -ne 0) {
    throw 'cannot read isolated Supabase status'
  }
  $environment = @{}
  foreach ($line in $statusLines) {
    if ($line -match '^([A-Z0-9_]+)="(.*)"$') {
      $environment[$Matches[1]] = $Matches[2]
    }
  }
  foreach ($requiredName in @('API_URL', 'ANON_KEY', 'INBUCKET_URL')) {
    if (-not $environment.ContainsKey($requiredName) -or
        [string]::IsNullOrWhiteSpace($environment[$requiredName])) {
      throw "isolated Supabase status omitted $requiredName"
    }
  }
  return $environment
}

function Invoke-HttpAttempt {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers = @{},
    [hashtable]$Body
  )
  $handler = [Net.Http.HttpClientHandler]::new()
  $handler.AllowAutoRedirect = $false
  $client = [Net.Http.HttpClient]::new($handler)
  try {
    $request = [Net.Http.HttpRequestMessage]::new(
      [Net.Http.HttpMethod]::new($Method),
      $Uri
    )
    foreach ($entry in $Headers.GetEnumerator()) {
      $null = $request.Headers.TryAddWithoutValidation($entry.Key, [string]$entry.Value)
    }
    if ($null -ne $Body) {
      $json = $Body | ConvertTo-Json -Compress
      $request.Content = [Net.Http.StringContent]::new(
        $json,
        [Text.Encoding]::UTF8,
        'application/json'
      )
    }
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Body = $content
      Location = if ($null -eq $response.Headers.Location) {
        $null
      }
      else {
        $response.Headers.Location.OriginalString
      }
    }
  }
  finally {
    $client.Dispose()
    $handler.Dispose()
  }
}

function Get-RecoveryMessage {
  param(
    [Parameter(Mandatory = $true)][string]$InboxUrl,
    [string]$PreviousId
  )
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $messages = Invoke-RestMethod -Method Get `
      -Uri "$($InboxUrl.TrimEnd('/'))/api/v1/messages"
    $message = @($messages.messages |
      Where-Object { $_.ID -ne $PreviousId } |
      Sort-Object Created -Descending |
      Select-Object -First 1)
    if ($message.Count -eq 1) {
      $detail = Invoke-RestMethod -Method Get `
        -Uri "$($InboxUrl.TrimEnd('/'))/api/v1/message/$($message[0].ID)"
      $content = [Net.WebUtility]::HtmlDecode(
        ([string]$detail.Text) + ' ' + ([string]$detail.HTML)
      )
      $match = [regex]::Match(
        $content,
        'https?://[^\s"''<>]+/auth/v1/verify\?[^\s"''<>]+'
      )
      if ($match.Success) {
        return [pscustomobject]@{
          Id = [string]$message[0].ID
          Link = $match.Value
        }
      }
    }
    Start-Sleep -Milliseconds 250
  }
  throw 'Mailpit did not expose a recovery link in time'
}

function Get-RecoverySessionFromLink {
  param([Parameter(Mandatory = $true)][string]$Link)
  $verification = Invoke-HttpAttempt -Method Get -Uri $Link
  if ($verification.StatusCode -notin @(301, 302, 303, 307, 308) -or
      [string]::IsNullOrWhiteSpace($verification.Location)) {
    throw 'valid recovery link did not redirect to the application'
  }
  $redirect = [uri]$verification.Location
  $fragment = @{}
  foreach ($pair in $redirect.Fragment.TrimStart('#').Split('&')) {
    if (-not $pair) { continue }
    $parts = $pair.Split('=', 2)
    if ($parts.Count -eq 2) {
      $fragment[[uri]::UnescapeDataString($parts[0])] =
        [uri]::UnescapeDataString($parts[1])
    }
  }
  if ($fragment['type'] -ne 'recovery' -or
      [string]::IsNullOrWhiteSpace($fragment['access_token']) -or
      [string]::IsNullOrWhiteSpace($fragment['refresh_token'])) {
    throw 'recovery callback did not establish a recovery session'
  }
  [pscustomobject]@{
    AccessToken = $fragment['access_token']
    RefreshToken = $fragment['refresh_token']
  }
}

function Test-RecoveryLinkDenied {
  param([Parameter(Mandatory = $true)]$Attempt)
  if ($Attempt.StatusCode -in @(400, 401, 403, 410, 422)) {
    return $true
  }
  if ($Attempt.StatusCode -notin @(301, 302, 303, 307, 308) -or
      [string]::IsNullOrWhiteSpace($Attempt.Location)) {
    return $false
  }
  $location = [string]$Attempt.Location
  return $location -match '(?:[#&?])error(?:_code)?=' -and
    $location -notmatch '(?:[#&?])access_token='
}

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][hashtable]$Headers,
    [Parameter(Mandatory = $true)][hashtable]$Body
  )
  Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers `
    -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Compress)
}

function Invoke-Bootstrap {
  param(
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [Parameter(Mandatory = $true)][string]$AnonKey,
    [Parameter(Mandatory = $true)][string]$AccessToken
  )
  Invoke-JsonRequest -Method Post `
    -Uri "$ApiUrl/rest/v1/rpc/superadmin_auth_bootstrap_context" `
    -Headers @{ apikey = $AnonKey; Authorization = "Bearer $AccessToken" } `
    -Body @{}
}

function Invoke-ResolveInstitutionContext {
  param(
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [Parameter(Mandatory = $true)][string]$AnonKey,
    [Parameter(Mandatory = $true)][string]$AccessToken,
    [Parameter(Mandatory = $true)][guid]$InstitutionId
  )
  $attempt = Invoke-HttpAttempt -Method Post `
    -Uri "$ApiUrl/rest/v1/rpc/superadmin_auth_resolve_institution_context" `
    -Headers @{ apikey = $AnonKey; Authorization = "Bearer $AccessToken" } `
    -Body @{ p_institution_id = $InstitutionId.ToString() }
  if ($attempt.StatusCode -ne 200) {
    $errorPayload = try { $attempt.Body | ConvertFrom-Json } catch { $null }
    $databaseCode = if ($null -eq $errorPayload) { 'unknown' } else { $errorPayload.code }
    $constraintMatch = if ($null -eq $errorPayload) {
      $null
    }
    else {
      [regex]::Match([string]$errorPayload.message, 'constraint "([a-z0-9_]+)"')
    }
    $constraint = if ($null -ne $constraintMatch -and $constraintMatch.Success) {
      $constraintMatch.Groups[1].Value
    }
    else {
      'unknown'
    }
    throw "institution context RPC failed with HTTP $($attempt.StatusCode), database code $databaseCode and constraint $constraint"
  }
  return $attempt.Body | ConvertFrom-Json
}

function Invoke-IsolatedSql {
  param(
    [Parameter(Mandatory = $true)][string]$Sql,
    [Parameter(Mandatory = $true)][string]$FailureMessage
  )
  $sqlOutput = @(
    $Sql | & docker exec -i "supabase_db_$ProjectId" `
      psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 2>&1
  )
  if ($LASTEXITCODE -ne 0) {
    throw $FailureMessage
  }
}

function Invoke-Logout {
  param(
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [Parameter(Mandatory = $true)][string]$AnonKey,
    [Parameter(Mandatory = $true)][string]$AccessToken
  )
  Invoke-RestMethod -Method Post -Uri "$ApiUrl/auth/v1/logout" `
    -Headers @{ apikey = $AnonKey; Authorization = "Bearer $AccessToken" } `
    -ContentType 'application/json' -Body '{}'
}

$environment = Get-LocalSupabaseEnvironment
$apiUrl = $environment['API_URL'].TrimEnd('/')
$anonKey = $environment['ANON_KEY']
$inboxUrl = $environment['INBUCKET_URL'].TrimEnd('/')
$email = "codex-auth-$([guid]::NewGuid().ToString('N'))@example.invalid"
$password = "Coelo-$([guid]::NewGuid().ToString('N'))-9!"
$newPassword = "Coelo-$([guid]::NewGuid().ToString('N'))-8!"
$recoveryRedirect = 'http://127.0.0.1:8766/reset-password'
$publicHeaders = @{ apikey = $anonKey }

'Auth lifecycle stage: signup and internal fixture'
$signup = Invoke-JsonRequest -Method Post -Uri "$apiUrl/auth/v1/signup" `
  -Headers $publicHeaders -Body @{ email = $email; password = $password }
if ($null -eq $signup.user -or $null -eq $signup.access_token -or
    $null -eq $signup.refresh_token) {
  throw 'Supabase Auth signup did not return a synthetic session'
}
$authUserId = [guid]::Parse($signup.user.id).ToString()

$fixtureSql = @"
do `$fixture`$
declare
  identity_id uuid;
  owner_identity_id uuid;
  operations_role_id uuid;
begin
  select id into strict operations_role_id
  from public.platform_roles
  where code='operations' and status='active';

  insert into app_private.superadmin_internal_identities default values
  returning id into identity_id;

  insert into app_private.superadmin_internal_auth_links(
    internal_identity_id,auth_user_id,status
  ) values(identity_id,'$authUserId'::uuid,'active');

  insert into app_private.superadmin_internal_memberships(
    internal_identity_id,platform_role_id,scope_kind,status
  ) values(identity_id,operations_role_id,'platform','active');

  insert into public.institutions(id,public_name,slug,status)
  values
    ('60000000-0000-4000-8000-000000000001','Synthetic Tenant A','synthetic-auth-tenant-a','active'),
    ('60000000-0000-4000-8000-000000000002','Synthetic Tenant B','synthetic-auth-tenant-b','active');

  insert into public.platform_roles(code,name,description,is_system,max_scope_kind)
  values('auth_no_capability','Auth no capability','Synthetic Auth negative role',false,'platform');

  insert into auth.users(id,aud,role,email,email_confirmed_at,created_at,updated_at,
    raw_app_meta_data,raw_user_meta_data)
  values('61000000-0000-4000-8000-000000000001','authenticated','authenticated',
    'synthetic-owner-anchor@invalid.test',now(),now(),now(),'{}','{}');
  insert into app_private.superadmin_internal_identities default values
  returning id into owner_identity_id;
  insert into app_private.superadmin_internal_auth_links(
    internal_identity_id,auth_user_id,status
  ) values(owner_identity_id,'61000000-0000-4000-8000-000000000001','active');
  insert into app_private.superadmin_internal_memberships(
    internal_identity_id,platform_role_id,scope_kind,status
  ) select owner_identity_id,id,'platform','active'
    from public.platform_roles where code='owner';

  insert into public.people(
    id,person_type,first_name,last_name,display_name,status
  ) values(
    '62000000-0000-4000-8000-000000000001','adult',
    'Synthetic','Realm Probe','Synthetic Realm Probe','active'
  );
  begin
    insert into public.person_auth_links(person_id,auth_user_id,status)
    values('62000000-0000-4000-8000-000000000001','$authUserId'::uuid,'active');
    raise exception 'cross-realm auth link was accepted';
  exception when unique_violation then
    null;
  end;
end
`$fixture`$;
"@
$fixtureOutput = @(
  $fixtureSql | & docker exec -i "supabase_db_$ProjectId" `
    psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 2>&1
)
if ($LASTEXITCODE -ne 0) {
  throw "cannot provision isolated internal Auth fixture: $($fixtureOutput -join ' ')"
}

$signupBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signup.access_token
if ($signupBootstrap.ok -ne $true -or
    $signupBootstrap.data.platform_role_code -ne 'operations' -or
    @($signupBootstrap.data.permission_codes) -notcontains 'platform.read') {
  throw 'signup session could not bootstrap internal Owner context'
}

Invoke-Logout -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signup.access_token | Out-Null
$revokedSignupBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signup.access_token
if ($revokedSignupBootstrap.ok -ne $false -or
    $revokedSignupBootstrap.error.code -ne 'SAI_SESSION_INVALID') {
  throw 'logged-out signup token retained internal access'
}

'Auth lifecycle stage: password login and authorization negatives'
$signin = Invoke-JsonRequest -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" `
  -Headers $publicHeaders -Body @{ email = $email; password = $password }
if ($null -eq $signin.access_token -or $null -eq $signin.refresh_token) {
  throw 'Supabase Auth password sign-in did not return a session'
}
$signinBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signin.access_token
if ($signinBootstrap.ok -ne $true) {
  throw 'password sign-in session could not bootstrap internal context'
}

Invoke-IsolatedSql -FailureMessage 'cannot assign synthetic Owner role' -Sql @"
update app_private.superadmin_internal_memberships membership
set platform_role_id=(select id from public.platform_roles where code='owner'),
  version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@
'Auth authorization stage: Owner AAL1 bootstrap during MVP deferral'
$ownerAal1Bootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signin.access_token
if ($ownerAal1Bootstrap.ok -ne $true -or
    $ownerAal1Bootstrap.data.platform_role_code -ne 'owner' -or
    $ownerAal1Bootstrap.data.aal -ne 'aal1' -or
    @($ownerAal1Bootstrap.data.permission_codes) -notcontains 'platform.read') {
  throw 'Owner AAL1 could not bootstrap during the approved MVP MFA deferral'
}

Invoke-IsolatedSql -FailureMessage 'cannot assign synthetic capability-less role' -Sql @"
update app_private.superadmin_internal_memberships membership
set platform_role_id=(select id from public.platform_roles where code='auth_no_capability'),
  version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@
'Auth authorization stage: capability denial'
$capabilityDenied = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signin.access_token
if ($capabilityDenied.ok -ne $false -or
    $capabilityDenied.error.code -ne 'SAI_PERMISSION_DENIED') {
  throw 'missing capability was not denied'
}

Invoke-IsolatedSql -FailureMessage 'cannot assign institution-scoped membership' -Sql @"
update app_private.superadmin_internal_memberships membership
set platform_role_id=(select id from public.platform_roles where code='operations'),
  scope_kind='institution',
  scope_institution_id='60000000-0000-4000-8000-000000000001'::uuid,
  version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@
'Auth authorization stage: tenant allow and cross-tenant denial'
$tenantAContext = Invoke-ResolveInstitutionContext -ApiUrl $apiUrl `
  -AnonKey $anonKey -AccessToken $signin.access_token `
  -InstitutionId '60000000-0000-4000-8000-000000000001'
if ($tenantAContext.ok -ne $true -or
    $tenantAContext.data.resolved_institution_id -ne
      '60000000-0000-4000-8000-000000000001') {
  throw 'institution-scoped membership could not resolve its own tenant'
}
$tenantBDenied = Invoke-ResolveInstitutionContext -ApiUrl $apiUrl `
  -AnonKey $anonKey -AccessToken $signin.access_token `
  -InstitutionId '60000000-0000-4000-8000-000000000002'
if ($tenantBDenied.ok -ne $false -or
    $tenantBDenied.error.code -ne 'SAI_PERMISSION_DENIED') {
  throw 'cross-tenant institution context was not denied'
}
$tamperedTenantDenied = Invoke-ResolveInstitutionContext -ApiUrl $apiUrl `
  -AnonKey $anonKey -AccessToken $signin.access_token `
  -InstitutionId '60000000-0000-4000-8000-000000000099'
if ($tamperedTenantDenied.ok -ne $false -or
    $tamperedTenantDenied.error.code -ne 'SAI_PERMISSION_DENIED') {
  throw 'tampered institution id was not denied'
}

Invoke-IsolatedSql -FailureMessage 'cannot suspend synthetic membership' -Sql @"
update app_private.superadmin_internal_memberships membership
set status='suspended',suspended_at=now(),version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@
'Auth authorization stage: suspended membership denial'
$suspendedDenied = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signin.access_token
if ($suspendedDenied.ok -ne $false -or
    $suspendedDenied.error.code -ne 'SAI_MEMBERSHIP_SUSPENDED') {
  throw 'suspended membership was not denied'
}
Invoke-IsolatedSql -FailureMessage 'cannot reactivate synthetic membership' -Sql @"
update app_private.superadmin_internal_memberships membership
set status='active',suspended_at=null,version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@

'Auth lifecycle stage: refresh rotation and logout revocation'
$refresh = Invoke-JsonRequest -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" `
  -Headers $publicHeaders -Body @{ refresh_token = $signin.refresh_token }
if ($null -eq $refresh.access_token -or $null -eq $refresh.refresh_token) {
  throw 'Supabase Auth refresh did not rotate the session tokens'
}
$refreshBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $refresh.access_token
if ($refreshBootstrap.ok -ne $true) {
  throw 'refreshed session could not bootstrap internal context'
}

Invoke-Logout -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $refresh.access_token | Out-Null
$revokedRefreshBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $refresh.access_token
if ($revokedRefreshBootstrap.ok -ne $false -or
    $revokedRefreshBootstrap.error.code -ne 'SAI_SESSION_INVALID') {
  throw 'logged-out refreshed token retained internal access'
}

$refreshDenied = $false
try {
  Invoke-JsonRequest -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" `
    -Headers $publicHeaders -Body @{ refresh_token = $refresh.refresh_token } |
    Out-Null
}
catch {
  if ($_.Exception.Response.StatusCode.value__ -in @(400, 401)) {
    $refreshDenied = $true
  }
}
if (-not $refreshDenied) {
  throw 'logged-out refresh token was not rejected'
}
$rotatedRefreshDenied = $false
try {
  Invoke-JsonRequest -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" `
    -Headers $publicHeaders -Body @{ refresh_token = $signin.refresh_token } |
    Out-Null
}
catch {
  if ($_.Exception.Response.StatusCode.value__ -in @(400, 401)) {
    $rotatedRefreshDenied = $true
  }
}
if (-not $rotatedRefreshDenied) {
  throw 'old rotated refresh token was not rejected after logout'
}

$wrongPasswordAttempt = Invoke-HttpAttempt -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $publicHeaders `
  -Body @{ email = $email; password = 'definitely-wrong-password' }
$unknownAccountAttempt = Invoke-HttpAttempt -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $publicHeaders `
  -Body @{ email = "unknown-$([guid]::NewGuid().ToString('N'))@example.invalid"; password = 'definitely-wrong-password' }
if ($wrongPasswordAttempt.StatusCode -ne 400 -or
    $unknownAccountAttempt.StatusCode -ne 400 -or
    $wrongPasswordAttempt.Body -ne $unknownAccountAttempt.Body) {
  throw 'invalid login responses can enumerate account existence'
}

'Auth lifecycle stage: recovery callback and password reset'
$existingRecoveryAttempt = Invoke-HttpAttempt -Method Post `
  -Uri "$apiUrl/auth/v1/recover" -Headers $publicHeaders `
  -Body @{ email = $email; redirect_to = $recoveryRedirect }
$unknownRecoveryAttempt = Invoke-HttpAttempt -Method Post `
  -Uri "$apiUrl/auth/v1/recover" -Headers $publicHeaders `
  -Body @{
    email = "unknown-$([guid]::NewGuid().ToString('N'))@example.invalid"
    redirect_to = $recoveryRedirect
  }
if ($existingRecoveryAttempt.StatusCode -ne 200 -or
    $unknownRecoveryAttempt.StatusCode -ne 200 -or
    $existingRecoveryAttempt.Body -ne $unknownRecoveryAttempt.Body) {
  throw 'password recovery responses can enumerate account existence'
}
$recoveryMessage = Get-RecoveryMessage -InboxUrl $inboxUrl
$recoverySession = Get-RecoverySessionFromLink -Link $recoveryMessage.Link

$updatedUser = Invoke-JsonRequest -Method Put -Uri "$apiUrl/auth/v1/user" `
  -Headers @{
    apikey = $anonKey
    Authorization = "Bearer $($recoverySession.AccessToken)"
  } -Body @{ password = $newPassword }
if ($updatedUser.id -ne $authUserId) {
  throw 'password recovery updated an unexpected Auth identity'
}
Invoke-Logout -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $recoverySession.AccessToken | Out-Null

$oldPasswordAttempt = Invoke-HttpAttempt -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $publicHeaders `
  -Body @{ email = $email; password = $password }
if ($oldPasswordAttempt.StatusCode -ne 400) {
  throw 'old password was not rejected'
}
$newPasswordSignin = Invoke-JsonRequest -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $publicHeaders `
  -Body @{ email = $email; password = $newPassword }
if ($null -eq $newPasswordSignin.access_token) {
  throw 'new password did not establish a session'
}
'Auth lifecycle stage: revoked membership and minimized audit'
Invoke-IsolatedSql -FailureMessage 'cannot revoke synthetic membership' -Sql @"
update app_private.superadmin_internal_memberships membership
set status='revoked',revoked_at=now(),version=membership.version+1
from app_private.superadmin_internal_auth_links auth_link
where auth_link.internal_identity_id=membership.internal_identity_id
  and auth_link.auth_user_id='$authUserId'::uuid;
"@
$revokedMembershipDenied = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $newPasswordSignin.access_token
if ($revokedMembershipDenied.ok -ne $false -or
    $revokedMembershipDenied.error.code -ne 'SAI_MEMBERSHIP_REVOKED') {
  throw 'revoked membership was not denied'
}
Invoke-Logout -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $newPasswordSignin.access_token | Out-Null

$reuseAttempt = Invoke-HttpAttempt -Method Get -Uri $recoveryMessage.Link
if (-not (Test-RecoveryLinkDenied $reuseAttempt)) {
  throw 'recovery link reuse was not rejected'
}

Start-Sleep -Milliseconds 1100
Invoke-JsonRequest -Method Post -Uri "$apiUrl/auth/v1/recover" `
  -Headers $publicHeaders `
  -Body @{ email = $email; redirect_to = $recoveryRedirect } | Out-Null
$expiredMessage = Get-RecoveryMessage -InboxUrl $inboxUrl `
  -PreviousId $recoveryMessage.Id
$expireSql = "update auth.users set recovery_sent_at = now() - interval '2 hours' where id='$authUserId'::uuid;"
$expireOutput = @(
  $expireSql | & docker exec -i "supabase_db_$ProjectId" `
    psql --username postgres --dbname postgres --set ON_ERROR_STOP=1 2>&1
)
if ($LASTEXITCODE -ne 0) {
  throw "cannot expire synthetic recovery link: $($expireOutput -join ' ')"
}
$expiredAttempt = Invoke-HttpAttempt -Method Get -Uri $expiredMessage.Link
if (-not (Test-RecoveryLinkDenied $expiredAttempt)) {
  throw 'expired recovery link was not rejected'
}

Invoke-IsolatedSql -FailureMessage 'Auth audit evidence was incomplete' -Sql @"
do `$audit_check`$
begin
  if not exists(select 1 from audit.audit_logs
      where action_code='superadmin.auth.bootstrap' and outcome='success')
    or not exists(select 1 from audit.audit_logs
      where action_code='superadmin.auth.resolve_institution' and outcome='success'
        and institution_id='60000000-0000-4000-8000-000000000001'::uuid)
    or not exists(select 1 from audit.audit_logs
      where outcome='denied' and reason_code='SAI_PERMISSION_DENIED')
    or not exists(select 1 from audit.audit_logs
      where outcome='denied' and reason_code='SAI_MEMBERSHIP_SUSPENDED')
    or not exists(select 1 from audit.audit_logs
      where outcome='denied' and reason_code='SAI_MEMBERSHIP_REVOKED') then
    raise exception 'missing minimized Auth audit evidence';
  end if;
  if exists(select 1 from audit.audit_logs
      where reason_code='SAI_MFA_REQUIRED') then
    raise exception 'internal MVP Auth emitted a deferred MFA denial';
  end if;
  if exists(select 1 from audit.audit_logs log_record
    where to_jsonb(log_record)::text ~* '(access_token|refresh_token|password|@invalid\\.test)') then
    raise exception 'Auth audit contains prohibited credential or identity material';
  end if;
end
`$audit_check`$;
"@

'Local Supabase Auth lifecycle PASS: login/recovery without enumeration, refresh rotation and old-token refusal, logout/session revocation, callback/reset/one-use/expiration, internal realm separation, Owner AAL1 MVP bootstrap, active/suspended/revoked membership, capability denial, tenant isolation, tampered id refusal and minimized audit; synthetic fixture is confined to the disposable replay volume.'
