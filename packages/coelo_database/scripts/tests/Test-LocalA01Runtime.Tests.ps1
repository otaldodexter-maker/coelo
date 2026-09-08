$helper = Join-Path (Split-Path -Parent $PSScriptRoot) 'Test-LocalA01Runtime.ps1'

Describe 'A01 local runtime closed gates' {
  BeforeEach {
    . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  }

  It 'accepts only the explicit loopback origin' {
    (Assert-A01Origin 'http://127.0.0.1:54321').Port | Should Be 54321
  }
  foreach ($badOrigin in @('https://127.0.0.1:54321','http://localhost:54321','http://127.0.0.1','http://127.0.0.1:54321/x','http://u@127.0.0.1:54321','http://127.0.0.1:54321/?x=1','http://127.0.0.1:54321/#x')) {
    It "rejects nonnominal origin $badOrigin" {
      { Assert-A01Origin $badOrigin } | Should Throw 'A01 origin'
    }
  }
  It 'signs only the synthetic actor and ten minute session' {
    $jwt = New-A01Jwt -Secret ('s' * 40) -Actor Reader -Now 1800000000
    $claims = ConvertFrom-A01JwtPayload $jwt
    $claims.sub | Should Be '8a200000-0000-4000-8000-000000000102'
    $claims.session_id | Should Be '8a200000-0000-4000-8000-000000000202'
    ($claims.exp - $claims.iat) | Should Be 600
    $claims.role | Should Be 'authenticated'
    $claims.aal | Should Be 'aal2'
    (Test-A01JwtSignature $jwt ('s' * 40)) | Should Be $true
    (Test-A01JwtSignature $jwt ('x' * 40)) | Should Be $false
  }
  It 'rejects an arbitrary actor' {
    { New-A01Jwt -Secret ('s' * 40) -Actor Owner -Now 1800000000 } | Should Throw
  }
  It 'passes only six nominal client variables and never the signer' {
    $priorSecret = $env:JWT_SECRET
    $env:JWT_SECRET = 'parent-secret-do-not-copy'
    try {
      $child = New-A01ClientEnvironment 'http://127.0.0.1:54321' 'fake-anon' @{ Reader='r';Revoked='v';Denied='d' }
      @($child.Keys | Where-Object { $_ -like 'COELO_A01_*' }).Count | Should Be 6
      $child.COELO_A01_LOCAL_RUNTIME | Should Be '1'
      $child.ContainsKey('JWT_SECRET') | Should Be $false
      ($child.Values -contains 'parent-secret-do-not-copy') | Should Be $false
    } finally { $env:JWT_SECRET = $priorSecret }
  }
  It 'rejects a skipped test even when Flutter exits zero' {
    { ConvertFrom-A01FlutterReport 'All tests skipped.' 0 } | Should Throw 'A01 Flutter'
  }
  It 'rejects a failed child without exposing its output' {
    { ConvertFrom-A01FlutterReport 'secret-output' 1 } | Should Throw 'A01 Flutter failed'
  }
  It 'rejects an empty correlation report' {
    { ConvertFrom-A01FlutterReport "A01_LOCAL_HTTP_CORRELATIONS []`nAll tests passed!" 0 } | Should Throw 'A01 correlation'
  }
  It 'rejects a foreign ledger with the correct count and final version' {
    $expected = 1..55 | ForEach-Object { [pscustomobject]@{ Name = ('20260907{0:d6}_nominal.sql' -f $_) } }
    $actual = @($expected | ForEach-Object { $_.Name.Substring(0,14) })
    $actual[0] = '20250907000001'
    { Assert-A01Ledger $actual $expected } | Should Throw 'A01 ledger'
  }
  It 'rejects a nonexistent or escaped project before native operations' {
    { Assert-A01ProjectPath $TestDrive ('coelo_safe_' + ('a' * 29)) } | Should Throw 'A01 project'
  }
  It 'rejects client output with another RPC even if correlations look valid' {
    $records = ConvertTo-Json -InputObject @([ordered]@{rpc='arbitrary_rpc';http_status=200;ok=$true;correlation_id='8a200000-0000-4000-8000-000000000001'}) -Compress
    { ConvertFrom-A01FlutterReport ("A01_LOCAL_HTTP_CORRELATIONS $records`nAll tests passed!") 0 } | Should Throw 'A01 correlation'
  }
}

Describe 'A01 runtime orchestration with all external boundaries mocked' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  BeforeEach {
    Mock Assert-A01ProjectPath {}
    Mock Assert-A01DockerContext {}
    Mock Assert-A01Client { return $TestDrive }
    Mock Get-A01Inputs { 1..55 | ForEach-Object { [pscustomobject]@{Name=('20260907{0:d6}_nominal.sql' -f $_)} } }
    Mock Assert-A01StagedInputs {}
    Mock Get-A01FileHash { '758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99' }
    Mock Get-A01RuntimeIdentity { @{API_URL='http://127.0.0.1:54321';ANON_KEY='fake';JWT_SECRET=('s'*40)} }
    Mock Invoke-A01Sql { throw 'mock SQL boundary reached' }
    Mock Test-A01Startup {}
    Mock Invoke-A01Flutter { throw 'mock Flutter must not run before all gates' }
    Mock Invoke-A01CapturedProcess { throw 'unmocked external process forbidden' }
  }
  It 'rejects invalid identity before any SQL or HTTP' {
    Mock Get-A01RuntimeIdentity { throw 'identity denied' }
    { Invoke-A01LocalRuntime } | Should Throw 'identity denied'
    Assert-MockCalled Invoke-A01Sql -Scope It -Times 0 -Exactly
    Assert-MockCalled Test-A01Startup -Scope It -Times 0 -Exactly
    Assert-MockCalled Invoke-A01Flutter -Scope It -Times 0 -Exactly
  }
  It 'rejects wrong client before Docker inspection' {
    Mock Assert-A01Client { throw 'client denied' }
    { Invoke-A01LocalRuntime } | Should Throw 'client denied'
    Assert-MockCalled Get-A01RuntimeIdentity -Scope It -Times 0 -Exactly
  }
  It 'rejects seed drift before Docker inspection' {
    Mock Get-A01FileHash { 'wrong' }
    { Invoke-A01LocalRuntime } | Should Throw 'A01 seed pin mismatch'
    Assert-MockCalled Get-A01RuntimeIdentity -Scope It -Times 0 -Exactly
  }
  It 'rejects ledger mismatch before startup and seed' {
    Mock Invoke-A01Sql { '20260907222911' }
    { Invoke-A01LocalRuntime } | Should Throw 'A01 ledger'
    Assert-MockCalled Test-A01Startup -Scope It -Times 0 -Exactly
    Assert-MockCalled Invoke-A01Sql -Scope It -Times 1 -Exactly
  }
  It 'does not seed after a startup failure' {
    Mock Assert-A01Ledger {}
    Mock Invoke-A01Sql { 'nominal mock ledger' }
    Mock Test-A01Startup { throw 'startup denied' }
    { Invoke-A01LocalRuntime } | Should Throw 'startup denied'
    Assert-MockCalled Invoke-A01Sql -Scope It -Times 1 -Exactly
    Assert-MockCalled Invoke-A01Flutter -Scope It -Times 0 -Exactly
  }
}

Describe 'A01 process boundary' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  It 'uses only the fixed Flutter command and 180 second child window' {
    Mock Get-Command { [pscustomobject]@{Source='C:\nominal\flutter.bat'} }
    Mock Assert-A01Path { 'C:\nominal\flutter.bat' }
    Mock Invoke-A01CapturedProcess { [pscustomobject]@{ExitCode=0;Output='withheld';Error=''} }
    $null = Invoke-A01Flutter $TestDrive @{COELO_A01_LOCAL_RUNTIME='1'}
    Assert-MockCalled Invoke-A01CapturedProcess -Scope It -Times 1 -Exactly -ParameterFilter {
      $TimeoutSeconds -eq 180 -and $Arguments -ceq '/d /s /c ""C:\nominal\flutter.bat" test --no-pub test/features/activities/a01_local_runtime_test.dart"' -and
      $Environment.COELO_A01_LOCAL_RUNTIME -ceq '1'
    }
  }
  It 'compiles the Windows job owner without starting any native process' {
    Initialize-A01ProcessWindowType
    ('Coelo.A01ProcessWindow' -as [type]) | Should Not BeNullOrEmpty
  }
}
Describe 'A01 positive report and independent audit verification' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  BeforeEach {
    $records = @()
    1..3 | ForEach-Object { $records += [pscustomobject]@{rpc='superadmin_auth_bootstrap_context';http_status=200;ok=$true;correlation_id=$null} }
    $rows = @()
    foreach ($number in 1..5) {
      $options = $number -in @(2,5)
      $success = $number -le 3
      $correlation = '8a200000-0000-4000-8000-{0:d12}' -f $number
      $rpc = if ($options) { 'superadmin_activity_filter_options_v2' } else { 'superadmin_activity_directory_v2' }
      $records += [pscustomobject]@{rpc=$rpc;http_status=200;ok=$success;correlation_id=$correlation}
      $actor = if ($success) {302} elseif ($number -eq 4) {304} else {306}
      $id = '8a200000-0000-4000-8000-{0:d12}'
      $rows += [pscustomobject]@{
        correlation_id=$correlation;action_code=$(if($options){'activity.filter_options'}else{'activity.directory'})
        permission_code='activities.read';outcome=$(if($success){'success'}else{'denied'});actor_kind='superadmin_internal'
        actor_internal_identity_id=($id -f $actor);actor_internal_auth_link_id=($id -f ($actor+100));actor_internal_membership_id=($id -f ($actor+200))
        session_id_hash=(Get-A01Sha ($id -f ($actor-100)));mfa_aal='aal2';actor_person_id=$null;before_json=$null;object_id=$null;integrity=$true
        institution_id=$(if($success){$id -f 10}else{$null});context_id=$(if($success){$id -f 10}else{$null})
        context_kind=$(if($success){'institution'}else{'global'})
        reason_code=$(if($success){$null}elseif($actor -eq 304){'SAI_MEMBERSHIP_REVOKED'}else{'SAI_PERMISSION_DENIED'})
        after_json=$(if($success){[pscustomobject]@{row_count=$(if($options){8}elseif($number -eq 3){0}else{2})}}else{$null})
      }
    }
    $output = 'A01_LOCAL_HTTP_CORRELATIONS '+(ConvertTo-Json -InputObject $records -Compress)+[Environment]::NewLine+'All tests passed!'
  }
  It 'accepts a completed report and all three independently audited actors' {
    $activities = @(ConvertFrom-A01FlutterReport $output 0)
    $activities.Count | Should Be 5
    { Assert-A01Audit $activities $rows } | Should Not Throw
  }
  It 'rejects missing audit even though Flutter passed' {
    $activities = @(ConvertFrom-A01FlutterReport $output 0)
    { Assert-A01Audit $activities $rows[0..3] } | Should Throw 'A01 audit correlation count'
  }
  It 'rejects an actor mismatch on a correlated success' {
    $rows[0].actor_internal_identity_id = '8a200000-0000-4000-8000-000000000301'
    { Assert-A01Audit @(ConvertFrom-A01FlutterReport $output 0) $rows } | Should Throw 'A01 audit actor'
  }
  It 'rejects a different session hash' {
    $rows[0].session_id_hash = '0'*64
    { Assert-A01Audit @(ConvertFrom-A01FlutterReport $output 0) $rows } | Should Throw 'A01 audit actor'
  }
  It 'rejects an audit payload that includes domain data' {
    $rows[0].after_json | Add-Member NoteProperty name 'Robotics synthetic'
    { Assert-A01Audit @(ConvertFrom-A01FlutterReport $output 0) $rows } | Should Throw 'A01 audit success'
  }
  It 'rejects another institution on an audited read' {
    $rows[0].institution_id = '8a200000-0000-4000-8000-000000000020'
    { Assert-A01Audit @(ConvertFrom-A01FlutterReport $output 0) $rows } | Should Throw 'A01 audit success'
  }
  It 'rejects duplicate correlations' {
    $records[4].correlation_id = $records[3].correlation_id
    $output = 'A01_LOCAL_HTTP_CORRELATIONS '+(ConvertTo-Json -InputObject $records -Compress)+[Environment]::NewLine+'All tests passed!'
    { ConvertFrom-A01FlutterReport $output 0 } | Should Throw 'A01 correlation report'
  }
}
Describe 'A01 Kong routing identity' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  BeforeEach {
    $routing = @('services:','  - name: auth-v1','    url: http://own-auth:9999/','    routes:','      - name: auth-v1-all','        paths:','          - /auth/v1/','  - name: rest-v1','    url: http://own-rest:3000/','    routes:','      - name: rest-v1-all','        paths:','          - /rest/v1/') -join [Environment]::NewLine
  }
  It 'accepts the two nominal paths only when they target own aliases' {
    { Assert-A01KongRouting $routing @('own-rest') @('own-auth') } | Should Not Throw
  }
  It 'rejects a foreign upstream despite an unrelated correct URL elsewhere' {
    $routing = $routing.Replace('url: http://own-rest:3000/','url: http://foreign:3000/')+[Environment]::NewLine+'    unrelated: http://own-rest:3000/'
    { Assert-A01KongRouting $routing @('own-rest') @('own-auth') } | Should Throw 'A01 Kong'
  }
  It 'rejects two services capturing the same REST path' {
    $routing += [Environment]::NewLine+$routing.Substring($routing.IndexOf('  - name: rest-v1'))
    { Assert-A01KongRouting $routing @('own-rest') @('own-auth') } | Should Throw 'A01 Kong'
  }
}
Describe 'A01 local daemon gate' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  BeforeEach {
    $script:a01DockerContext = $null
    $script:a01DockerEndpoint = $null
    $script:a01MockRemote = $false; $script:a01MockChanged = $false; $script:a01MockPipeChanged = $false
    Mock Get-Command { [pscustomobject]@{Source='C:\nominal\docker.exe'} }
    Mock Get-A01DockerOverrideNames { @() }
    Mock Invoke-A01CapturedProcess {
      if ($Arguments -ceq 'context show') { [pscustomobject]@{ExitCode=0;Output='desktop-linux'} }
      else { [pscustomobject]@{ExitCode=0;Output='npipe:////./pipe/dockerDesktopLinuxEngine'} }
    }
  }
  It 'refuses overrides before querying a daemon' {
    Mock Get-A01DockerOverrideNames { @('DOCKER_HOST') }
    { Assert-A01DockerContext } | Should Throw 'A01 Docker overrides'
    Assert-MockCalled Invoke-A01CapturedProcess -Scope It -Times 0 -Exactly
  }
  It 'refuses a remote context endpoint before inspection or SQL' {
    $script:a01MockRemote = $true
    Mock Invoke-A01CapturedProcess { [pscustomobject]@{ExitCode=0;Output='tcp://remote.example:2376'} } -ParameterFilter { $script:a01MockRemote -and $Arguments -ne 'context show' }
    { Assert-A01DockerContext } | Should Throw 'A01 Docker requires local'
  }
  It 'pins the checked local context in subsequent Docker calls' {
    Assert-A01DockerContext
    $null = Invoke-A01Docker 'inspect nominal'
    Assert-MockCalled Invoke-A01CapturedProcess -Scope It -Times 1 -Exactly -ParameterFilter { $Arguments -ceq '--host npipe:////./pipe/dockerDesktopLinuxEngine inspect nominal' }
  }
  It 'rejects an endpoint change under the same context name' {
    Assert-A01DockerContext
    $script:a01MockPipeChanged = $true
    Mock Invoke-A01CapturedProcess { [pscustomobject]@{ExitCode=0;Output='npipe:////./pipe/otherEngine'} } -ParameterFilter { $script:a01MockPipeChanged -and $Arguments -ne 'context show' }
    { Assert-A01DockerContext } | Should Throw 'A01 Docker endpoint changed'
  }
  It 'rejects a context change before CLI status' {
    Assert-A01DockerContext
    $script:a01MockChanged = $true
    Mock Invoke-A01CapturedProcess { [pscustomobject]@{ExitCode=0;Output='other-context'} } -ParameterFilter { $script:a01MockChanged -and $Arguments -ceq 'context show' }
    { Assert-A01DockerContext } | Should Throw 'A01 Docker context changed'
  }
}
Describe 'A01 complete process deadline and descendant ownership' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  It 'closes the job when the parent exited but a descendant still holds a pipe' {
    $window=[pscustomobject]@{Disposed=$false;ParentExited=$true;Waited=0}
    $window | Add-Member ScriptMethod Wait { param($ms) $this.Waited=$ms;return $false }
    $window | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    { Complete-A01ProcessWindow $window 180 } | Should Throw 'A01 local process timed out'
    $window.Disposed | Should Be $true
    $window.Waited | Should Be 180000
  }
  It 'closes the job on a blocked asynchronous input write' {
    $window=[pscustomobject]@{Disposed=$false}
    $window | Add-Member ScriptMethod Wait { param($ms) return $false }
    $window | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    { Complete-A01ProcessWindow $window 30 } | Should Throw 'A01 local process timed out'
    $window.Disposed | Should Be $true
  }
  It 'returns results only after every pipe and parent have completed, then closes the job' {
    $window=[pscustomobject]@{Disposed=$false}
    $window | Add-Member ScriptMethod Wait { param($ms) return $true }
    $window | Add-Member ScriptMethod GetResult { return [pscustomobject]@{ExitCode=0;Output='safe synthetic output';Error=''} }
    $window | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    (Complete-A01ProcessWindow $window 180).ExitCode | Should Be 0
    $window.Disposed | Should Be $true
  }
}
Describe 'A01 constructor environment and CLI endpoint regression' {
  . $helper -ProjectRoot $TestDrive -ProjectId ('coelo_safe_' + ('a' * 29)) -ClientRoot $TestDrive
  It 'treats PowerShell null and empty strings as inherited native environment' {
    Initialize-A01ProcessWindowType
    [Coelo.A01ProcessWindow]::UsesInheritedEnvironment($null) | Should Be $true
    [Coelo.A01ProcessWindow]::UsesInheritedEnvironment('') | Should Be $true
    [Coelo.A01ProcessWindow]::UsesInheritedEnvironment(('A01_FAKE=x'+[char]0+[char]0)) | Should Be $false
  }
  It 'passes only the pinned host to the status child and leaves parent environment untouched' {
    $script:a01DockerEndpoint = 'npipe:////./pipe/dockerDesktopLinuxEngine'
    $priorContext=$env:DOCKER_CONTEXT; $priorHost=$env:DOCKER_HOST
    $env:DOCKER_CONTEXT='parent-do-not-pass'; $env:DOCKER_HOST='parent-do-not-pass'
    try {
      Mock Assert-A01DockerContext {}
      Mock Invoke-A01CapturedProcess { [pscustomobject]@{ExitCode=0;Output='API_URL="http://127.0.0.1:54321"'} }
      $null = Get-A01LocalStatus
      Assert-MockCalled Invoke-A01CapturedProcess -Scope It -Times 1 -Exactly -ParameterFilter {
        $Environment.DOCKER_HOST -ceq 'npipe:////./pipe/dockerDesktopLinuxEngine' -and
        -not $Environment.ContainsKey('DOCKER_CONTEXT') -and -not $Environment.ContainsKey('DOCKER_TLS') -and -not $Environment.ContainsKey('DOCKER_TLS_VERIFY') -and
        -not $Environment.ContainsKey('DOCKER_CERT_PATH') -and -not $Environment.ContainsKey('DOCKER_CONFIG')
      }
      $env:DOCKER_CONTEXT | Should Be 'parent-do-not-pass'
      $env:DOCKER_HOST | Should Be 'parent-do-not-pass'
    } finally { $env:DOCKER_CONTEXT=$priorContext; $env:DOCKER_HOST=$priorHost }
  }
}