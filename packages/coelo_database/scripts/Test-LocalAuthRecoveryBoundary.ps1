[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^coelo_safe_[0-9a-f]{29}$')][string]$ProjectId,
  [switch]$AssertConfined
)

$ErrorActionPreference = 'Stop'
$cliPackage = 'supabase@2.116.0'
Add-Type -AssemblyName System.Net.Http
$expectedRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) $ProjectId))
if ([IO.Path]::GetFullPath($ProjectRoot) -ne $expectedRoot -or
    -not (Test-Path -LiteralPath (Join-Path $ProjectRoot '.coelo-safe-replay'))) {
  throw 'recovery boundary requires the marked disposable safe-replay project'
}

# Import only named function definitions from the trusted repository helper.
# The lifecycle body must never execute as part of this focal probe.
$helperPath = Join-Path $PSScriptRoot 'Test-LocalAuthLifecycle.ps1'
$parseErrors = $null
$helperAst = [Management.Automation.Language.Parser]::ParseFile(
  $helperPath, [ref]$null, [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) { throw 'Auth helper contains parsing errors' }
$helperNames = @('Get-LocalSupabaseEnvironment', 'Invoke-HttpAttempt',
  'Get-RecoveryMessage', 'Get-RecoverySessionFromLink', 'Invoke-JsonRequest',
  'Invoke-Bootstrap', 'Invoke-IsolatedSql', 'Invoke-Logout')
foreach ($helperName in $helperNames) {
  $definitions = @($helperAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
      $node.Name -eq $helperName
  }, $false))
  if ($definitions.Count -ne 1) { throw "ambiguous or absent helper $helperName" }
  . ([scriptblock]::Create($definitions[0].Extent.Text))
}

function Get-SanitizedMethods {
  param([Parameter(Mandatory = $true)][string]$AccessToken)
  $parts = $AccessToken.Split('.')
  if ($parts.Count -ne 3) { throw 'provider returned malformed JWT' }
  $payload = $parts[1].Replace('-', '+').Replace('_', '/')
  $payload = $payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '=')
  $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) |
    ConvertFrom-Json
  $methods = @($claims.amr | ForEach-Object {
    if ([string]$_.method -notmatch '^[a-z_]{1,40}$') {
      throw 'provider returned unexpected AMR method shape'
    }
    [string]$_.method
  } | Sort-Object -Unique)
  return $methods -join ','
}

function Write-BoundaryObservation {
  param([string]$Gate, [string]$AccessToken, $Bootstrap)
  $hasContext = $Bootstrap.ok -eq $true -and $null -ne $Bootstrap.data -and
    @($Bootstrap.data.permission_codes) -contains 'platform.read'
  $outcome = if ($hasContext) { 'RED' } elseif ($Bootstrap.ok -eq $false -and
      $null -eq $Bootstrap.data -and $Bootstrap.error.code -eq 'SAI_SESSION_INVALID') {
    'PASS'
  } else { 'INCONCLUSIVE' }
  $code = if ($Bootstrap.ok -eq $false -and
      [string]$Bootstrap.error.code -match '^SAI_[A-Z_]+$') {
    $Bootstrap.error.code
  } else { 'none' }
  "D01 recovery boundary gate=$Gate outcome=$outcome productive_context=$hasContext methods=$(Get-SanitizedMethods $AccessToken) error_code=$code"
}

function Assert-BootstrapConfined {
  param($Bootstrap)
  if ($Bootstrap.ok -ne $false -or $null -ne $Bootstrap.data -or
      $Bootstrap.error.code -ne 'SAI_SESSION_INVALID') {
    throw 'recovery confinement assertion failed: expected denied session and no productive context'
  }
}

$environment = Get-LocalSupabaseEnvironment
$apiUrl = $environment['API_URL'].TrimEnd('/')
$anonKey = $environment['ANON_KEY']
$inboxUrl = $environment['INBUCKET_URL'].TrimEnd('/')
foreach ($localUrl in @($apiUrl, $inboxUrl)) {
  if (-not ([uri]$localUrl).IsLoopback) { throw 'probe refuses non-loopback endpoint' }
}
$authImage = & docker inspect "supabase_auth_$ProjectId" --format '{{.Config.Image}}'
if ($LASTEXITCODE -ne 0) { throw 'cannot identify isolated Auth runtime' }
"D01 recovery boundary runtime=$authImage project=$ProjectId"
$email = "codex-recovery-boundary-$([guid]::NewGuid().ToString('N'))@example.invalid"
$password = "Coelo-$([guid]::NewGuid().ToString('N'))-9!"
$headers = @{ apikey = $anonKey }
$signup = Invoke-JsonRequest -Method Post -Uri "$apiUrl/auth/v1/signup" `
  -Headers $headers -Body @{ email = $email; password = $password }
$authUserId = [guid]::Parse($signup.user.id).ToString()
Invoke-IsolatedSql -FailureMessage 'cannot create focal synthetic operations fixture' -Sql @"
do `$fixture`$
declare identity_id uuid;
begin
  insert into app_private.superadmin_internal_identities default values
    returning id into identity_id;
  insert into app_private.superadmin_internal_auth_links(
    internal_identity_id,auth_user_id,status)
    values(identity_id,'$authUserId'::uuid,'active');
  insert into app_private.superadmin_internal_memberships(
    internal_identity_id,platform_role_id,scope_kind,status)
    select identity_id,id,'platform','active' from public.platform_roles
    where code='operations' and status='active';
end
`$fixture`$;
"@
$signin = Invoke-JsonRequest -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $headers `
  -Body @{ email = $email; password = $password }
$control = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $signin.access_token
if ($control.ok -ne $true -or
    @($control.data.permission_codes) -notcontains 'platform.read') {
  throw 'password control could not obtain productive context; boundary inconclusive'
}
"D01 recovery boundary gate=password-control outcome=PASS productive_context=True methods=$(Get-SanitizedMethods $signin.access_token)"
if ($AssertConfined) {
  $passwordRefresh = Invoke-JsonRequest -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" -Headers $headers `
    -Body @{ refresh_token = $signin.refresh_token }
  $passwordRefreshBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $passwordRefresh.access_token
  if ($passwordRefreshBootstrap.ok -ne $true -or
      @($passwordRefreshBootstrap.data.permission_codes) -notcontains 'platform.read') {
    throw 'refreshed password control lost productive context'
  }
  "D01 recovery boundary gate=refreshed-password-control outcome=PASS productive_context=True methods=$(Get-SanitizedMethods $passwordRefresh.access_token)"
}
Invoke-JsonRequest -Method Post -Uri "$apiUrl/auth/v1/recover" -Headers $headers `
  -Body @{ email = $email; redirect_to = 'http://127.0.0.1:8766/reset-password' } |
  Out-Null
$message = Get-RecoveryMessage -InboxUrl $inboxUrl
$recovery = Get-RecoverySessionFromLink -Link $message.Link
$recoveryBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $recovery.AccessToken
Write-BoundaryObservation -Gate 'recovery-before-reset' `
  -AccessToken $recovery.AccessToken -Bootstrap $recoveryBootstrap
$refresh = Invoke-JsonRequest -Method Post `
  -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" -Headers $headers `
  -Body @{ refresh_token = $recovery.RefreshToken }
$refreshBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
  -AccessToken $refresh.access_token
Write-BoundaryObservation -Gate 'refreshed-recovery-before-reset' `
  -AccessToken $refresh.access_token -Bootstrap $refreshBootstrap
if ($AssertConfined) {
  foreach ($denial in @($recoveryBootstrap, $refreshBootstrap)) {
    Assert-BootstrapConfined $denial
  }
  # This is an actual provider update of user-editable metadata, not a forged JWT.
  $metadataUpdate = Invoke-JsonRequest -Method Put -Uri "$apiUrl/auth/v1/user" `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $($refresh.access_token)" } `
    -Body @{ data = @{ authentication_method = 'password'; password_authenticated = $true } }
  if ($metadataUpdate.id -ne $authUserId -or
      $metadataUpdate.user_metadata.authentication_method -ne 'password' -or
      $metadataUpdate.user_metadata.password_authenticated -ne $true) {
    throw 'provider did not persist the synthetic mutable metadata probe'
  }
  $metadataRefresh = Invoke-JsonRequest -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" -Headers $headers `
    -Body @{ refresh_token = $refresh.refresh_token }
  $metadataBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $metadataRefresh.access_token
  Write-BoundaryObservation -Gate 'mutable-metadata-recovery-before-reset' `
    -AccessToken $metadataRefresh.access_token -Bootstrap $metadataBootstrap
  Assert-BootstrapConfined $metadataBootstrap

  $newPassword = "Coelo-$([guid]::NewGuid().ToString('N'))-8!"
  $updatedUser = Invoke-JsonRequest -Method Put -Uri "$apiUrl/auth/v1/user" `
    -Headers @{ apikey = $anonKey; Authorization = "Bearer $($metadataRefresh.access_token)" } `
    -Body @{ password = $newPassword }
  if ($updatedUser.id -ne $authUserId) {
    throw 'confined recovery could not update the intended synthetic Auth identity'
  }
  'D01 recovery boundary gate=confined-recovery-password-update outcome=PASS'
  $afterPasswordUpdate = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $metadataRefresh.access_token
  Write-BoundaryObservation -Gate 'recovery-after-reset-before-logout' `
    -AccessToken $metadataRefresh.access_token -Bootstrap $afterPasswordUpdate
  Assert-BootstrapConfined $afterPasswordUpdate
  Invoke-Logout -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $metadataRefresh.access_token | Out-Null
  $afterLogout = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $metadataRefresh.access_token
  Assert-BootstrapConfined $afterLogout
  $revokedRefreshAttempt = Invoke-HttpAttempt -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=refresh_token" -Headers $headers `
    -Body @{ refresh_token = $metadataRefresh.refresh_token }
  $revocationPayload = try { $revokedRefreshAttempt.Body | ConvertFrom-Json } catch { $null }
  # GoTrue v2.196.0 tokens/service.go returns these HTTP 400 codes when the
  # refresh token or its provider session no longer exists. Malformed requests
  # return validation_failed/invalid_request and must never count as revocation.
  if ($revokedRefreshAttempt.StatusCode -ne 400 -or
      $revocationPayload.error_code -notin @('refresh_token_not_found', 'session_not_found')) {
    throw 'logged-out recovery refresh token was not revoked by the provider'
  }
  "D01 recovery boundary gate=post-reset-recovery-logout outcome=PASS productive_context=False provider_error_code=$($revocationPayload.error_code)"

  $newSignin = Invoke-JsonRequest -Method Post `
    -Uri "$apiUrl/auth/v1/token?grant_type=password" -Headers $headers `
    -Body @{ email = $email; password = $newPassword }
  $newBootstrap = Invoke-Bootstrap -ApiUrl $apiUrl -AnonKey $anonKey `
    -AccessToken $newSignin.access_token
  if ($newBootstrap.ok -ne $true -or
      @($newBootstrap.data.permission_codes) -notcontains 'platform.read') {
    throw 'new password login could not obtain productive context after recovery logout'
  }
  "D01 recovery boundary gate=new-password-login outcome=PASS productive_context=True methods=$(Get-SanitizedMethods $newSignin.access_token)"
  'D01 recovery confinement assertions PASS; provider password update/logout/new login remain usable; cleanup belongs to disposable wrapper volume.'
}
else {
  'D01 focal observation completed; no password PUT; synthetic fixture cleanup belongs to disposable wrapper volume.'
}
