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
  foreach ($requiredName in @('API_URL', 'ANON_KEY')) {
    if (-not $environment.ContainsKey($requiredName) -or
        [string]::IsNullOrWhiteSpace($environment[$requiredName])) {
      throw "isolated Supabase status omitted $requiredName"
    }
  }
  return $environment
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
$email = "codex-auth-$([guid]::NewGuid().ToString('N'))@example.invalid"
$password = "Coelo-$([guid]::NewGuid().ToString('N'))-9!"
$publicHeaders = @{ apikey = $anonKey }

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

'Local Supabase Auth lifecycle PASS: signup, password sign-in, bootstrap, refresh, logout and session revocation; synthetic fixture is confined to the disposable replay volume.'
