#Requires -Version 7.0
# C01 I015: real Windows DPAPI tests, restricted to an owned synthetic TEMP root.
# No password is passed in arguments/environment or printed by an assertion.
$c01SecretHelper = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Invoke-E2R01PersonaSecretStore.ps1'))
$c01SecretPwsh = 'C:/Users/adrie/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
$c01SecretSid = [Security.Principal.WindowsIdentity]::GetCurrent().User

function New-C01SecretPassword {
  $bytes = [byte[]]::new(32)
  [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function Set-C01RestrictedDirectory([string]$Path) {
  $acl = [Security.AccessControl.DirectorySecurity]::new()
  $acl.SetOwner($c01SecretSid)
  $acl.SetAccessRuleProtection($true, $false)
  $rule = [Security.AccessControl.FileSystemAccessRule]::new(
    $c01SecretSid, [Security.AccessControl.FileSystemRights]::FullControl,
    [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',
    [Security.AccessControl.PropagationFlags]::None,
    [Security.AccessControl.AccessControlType]::Allow)
  $acl.AddAccessRule($rule)
  Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function New-C01SecretRequest([string]$Operation, [string]$Directory,
  [string]$PlanId, [string]$AuthUserId, [string]$Password) {
  $request = [ordered]@{
    version = 1; operation = $Operation; directory = $Directory
    planId = $PlanId; authUserId = $AuthUserId
  }
  if ($Operation -eq 'reserve') {
    $request.receipt = [ordered]@{
      planId = $PlanId; authUserId = $AuthUserId; password = $Password; state = 'reserved'
    }
  }
  $request
}

function Start-C01SecretProcess([object]$Request, [switch]$DiscardResponse) {
  $start = [Diagnostics.ProcessStartInfo]::new()
  $start.FileName = $c01SecretPwsh
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
  $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
  $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
  $start.WorkingDirectory = $script:c01SecretFixtureRoot
  foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $c01SecretHelper)) {
    $start.ArgumentList.Add($argument)
  }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $start
  if (-not $process.Start()) { throw 'C01_SECRET_TEST_PROCESS_START_FAILED' }
  $script:c01SecretProcesses.Add($process)
  $output = if (-not $DiscardResponse) { $process.StandardOutput.ReadToEndAsync() } else { $null }
  $errorOutput = $process.StandardError.ReadToEndAsync()
  try {
    $json = ConvertTo-Json -InputObject $Request -Depth 8 -Compress
    $process.StandardInput.Write($json)
    $process.StandardInput.Close()
  } catch {
    if (-not $process.HasExited) { $process.Kill($true) }
    throw 'C01_SECRET_TEST_STDIN_FAILED'
  }
  [pscustomobject]@{ Process = $process; Output = $output; ErrorOutput = $errorOutput }
}

function Complete-C01SecretProcess([object]$Pending) {
  if (-not $Pending.Process.WaitForExit(15000)) {
    $Pending.Process.Kill($true)
    throw 'C01_SECRET_TEST_PROCESS_TIMEOUT'
  }
  $output = $Pending.Output.GetAwaiter().GetResult()
  $errorOutput = $Pending.ErrorOutput.GetAwaiter().GetResult()
  $payload = $null
  try { $payload = ConvertFrom-Json -InputObject $output -AsHashtable -ErrorAction Stop }
  catch { throw 'C01_SECRET_TEST_INVALID_JSON_RESPONSE' }
  [pscustomobject]@{
    ExitCode = $Pending.Process.ExitCode; Payload = $payload
    Output = $output; ErrorOutput = $errorOutput
  }
}

function Invoke-C01SecretRequest([object]$Request) {
  Complete-C01SecretProcess (Start-C01SecretProcess $Request)
}

function Assert-C01SecretSuccess([object]$Result, [object]$Request) {
  $Result.ExitCode | Should Be 0
  ($Result.ErrorOutput.Length -eq 0) | Should Be $true
  ($Result.Payload -is [System.Collections.IDictionary]) | Should Be $true
  ($Result.Payload.ok -is [bool] -and $Result.Payload.ok) | Should Be $true
  ($Result.Payload.version -eq 1 -and ($Result.Payload.version -is [int] -or $Result.Payload.version -is [long])) | Should Be $true
  ($Result.Payload.operation -ceq $Request.operation) | Should Be $true
  ($Result.Payload.planId -ceq $Request.planId) | Should Be $true
  ($Result.Payload.authUserId -ceq $Request.authUserId) | Should Be $true
  $expectedKeys = @('version', 'ok', 'operation', 'planId', 'authUserId')
  if ($Request.operation -eq 'read') { $expectedKeys += 'receipt' }
  (@(Compare-Object ($expectedKeys | Sort-Object) @($Result.Payload.Keys | Sort-Object)).Count -eq 0) | Should Be $true
  if ($Request.operation -ne 'read') {
    (-not $Result.Output.Contains($script:c01SecretPassword)) | Should Be $true
  }
}

function Assert-C01SecretFailure([object]$Result, [string]$Code) {
  $Result.ExitCode | Should Be 1
  ($Result.ErrorOutput.Length -eq 0) | Should Be $true
  ($Result.Payload -is [System.Collections.IDictionary]) | Should Be $true
  ($Result.Payload.ok -is [bool] -and -not $Result.Payload.ok) | Should Be $true
  ($Result.Payload.version -eq 1 -and ($Result.Payload.version -is [int] -or $Result.Payload.version -is [long])) | Should Be $true
  (@(Compare-Object @('code', 'ok', 'version') @($Result.Payload.Keys | Sort-Object)).Count -eq 0) | Should Be $true
  ($Result.Payload.code -is [string] -and $Result.Payload.code -cmatch '^SECRET_STORE_[A-Z_]+$') | Should Be $true
  if ($Code) { ($Result.Payload.code -ceq $Code) | Should Be $true }
  (-not $Result.Payload.Contains('receipt')) | Should Be $true
  (-not $Result.Output.Contains($script:c01SecretPassword)) | Should Be $true
}

function Assert-C01SecretReceipt([object]$Result, [string]$Password, [string]$State) {
  $receipt = $Result.Payload.receipt
  ($receipt -is [System.Collections.IDictionary]) | Should Be $true
  (@(Compare-Object @('authUserId', 'password', 'planId', 'state') @($receipt.Keys | Sort-Object)).Count -eq 0) | Should Be $true
  ($receipt.planId -ceq $script:c01SecretPlanId) | Should Be $true
  ($receipt.authUserId -ceq $script:c01SecretAuthId) | Should Be $true
  # Compare only booleans: Pester must never include a password in diagnostics.
  ($receipt.password -is [string] -and $receipt.password -ceq $Password) | Should Be $true
  ($receipt.state -ceq $State) | Should Be $true
}

function Assert-C01OnlyCurrentSidAcl([string]$Path) {
  $acl = Get-Acl -LiteralPath $Path
  $acl.AreAccessRulesProtected | Should Be $true
  ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ceq $c01SecretSid.Value) | Should Be $true
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  ($rules.Count -gt 0) | Should Be $true
  foreach ($rule in $rules) {
    ($rule.IdentityReference.Value -ceq $c01SecretSid.Value) | Should Be $true
    ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow) | Should Be $true
    (-not $rule.IsInherited) | Should Be $true
  }
}

Describe 'E2 R01 nominal secret store with real Windows DPAPI' {
  BeforeEach {
    $script:c01SecretProcesses = [Collections.Generic.List[Diagnostics.Process]]::new()
    $script:c01SecretFixtureRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('coelo-c01-secret-store-tests-' + [guid]::NewGuid().ToString('N'))))
    [IO.Directory]::CreateDirectory($script:c01SecretFixtureRoot) | Out-Null
    Set-C01RestrictedDirectory $script:c01SecretFixtureRoot
    $script:c01SecretDirectory = Join-Path $script:c01SecretFixtureRoot 'store'
    $script:c01SecretPlanId = [guid]::NewGuid().ToString()
    $script:c01SecretAuthId = [guid]::NewGuid().ToString()
    $script:c01SecretPassword = New-C01SecretPassword
    $script:c01SecretJunctions = [Collections.Generic.List[string]]::new()
  }

  AfterEach {
    foreach ($process in $script:c01SecretProcesses) {
      try { if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(5000) | Out-Null } }
      finally { $process.Dispose() }
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath($script:c01SecretFixtureRoot)
    if (-not $target.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      -not [IO.Path]::GetFileName($target).StartsWith('coelo-c01-secret-store-tests-', [StringComparison]::Ordinal)) {
      throw 'C01_SECRET_TEST_UNSAFE_CLEANUP_TARGET'
    }
    # Remove owned junctions without recursion before recursively removing the
    # validated owned TEMP root. Never enumerate paths for deletion in cmd.exe.
    foreach ($junction in $script:c01SecretJunctions) {
      $resolvedJunction = [IO.Path]::GetFullPath($junction)
      if (-not $resolvedJunction.StartsWith($target + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'C01_SECRET_TEST_UNSAFE_JUNCTION_TARGET'
      }
      if (Test-Path -LiteralPath $resolvedJunction) { Remove-Item -LiteralPath $resolvedJunction -Force }
    }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  }

  It 'returns null for an unreserved account through an exact read envelope' {
    $request = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    $result = Invoke-C01SecretRequest $request
    Assert-C01SecretSuccess $result $request
    ($null -eq $result.Payload.receipt) | Should Be $true
    (Test-Path -LiteralPath $script:c01SecretDirectory) | Should Be $false
  }

  It 'reserves once and reopens the original password in a separate process with encrypted bytes and restricted ACLs' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    $result = Invoke-C01SecretRequest $read
    Assert-C01SecretSuccess $result $read
    Assert-C01SecretReceipt $result $script:c01SecretPassword 'reserved'
    $receiptPath = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $cipher = [IO.File]::ReadAllBytes($receiptPath)
    ($cipher.Length -gt 0) | Should Be $true
    (-not [Text.Encoding]::UTF8.GetString($cipher).Contains($script:c01SecretPassword)) | Should Be $true
    Assert-C01OnlyCurrentSidAcl $script:c01SecretDirectory
    Assert-C01OnlyCurrentSidAcl $receiptPath
  }

  It 'allows exactly one concurrent reservation and keeps the winning password' {
    $otherPassword = New-C01SecretPassword
    $first = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    $second = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $otherPassword
    $pendingFirst = Start-C01SecretProcess $first
    $pendingSecond = Start-C01SecretProcess $second
    $resultFirst = Complete-C01SecretProcess $pendingFirst
    $resultSecond = Complete-C01SecretProcess $pendingSecond
    ((@($resultFirst, $resultSecond) | Where-Object { $_.Payload.ok -eq $true }).Count -eq 1) | Should Be $true
    if ($resultFirst.Payload.ok -eq $true) {
      Assert-C01SecretSuccess $resultFirst $first
      Assert-C01SecretFailure $resultSecond 'SECRET_STORE_COLLISION'
      $winnerPassword = $script:c01SecretPassword
    } else {
      Assert-C01SecretFailure $resultFirst 'SECRET_STORE_COLLISION'
      Assert-C01SecretSuccess $resultSecond $second
      $winnerPassword = $otherPassword
    }
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    $result = Invoke-C01SecretRequest $read
    Assert-C01SecretSuccess $result $read
    Assert-C01SecretReceipt $result $winnerPassword 'reserved'
  }

  It 'refuses a second reservation without rotating the encrypted receipt or password' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $path = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $beforeHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $reserve.receipt.password = New-C01SecretPassword
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_COLLISION'
    ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ceq $beforeHash) | Should Be $true
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretReceipt (Invoke-C01SecretRequest $read) $script:c01SecretPassword 'reserved'
  }

  It 'rejects another plan for the same account without revealing or changing the original receipt' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $otherPlan = [guid]::NewGuid().ToString()
    foreach ($operation in @('read', 'reserve', 'mark-created')) {
      $request = New-C01SecretRequest $operation $script:c01SecretDirectory $otherPlan $script:c01SecretAuthId (New-C01SecretPassword)
      Assert-C01SecretFailure (Invoke-C01SecretRequest $request)
    }
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretReceipt (Invoke-C01SecretRequest $read) $script:c01SecretPassword 'reserved'
  }

  It 'marks created idempotently without rewriting the original ciphertext' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $receiptPath = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $originalHash = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash
    $mark = New-C01SecretRequest 'mark-created' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $mark) $mark
    $markerPath = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.created.dpapi')
    $markerHash = (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $mark) $mark
    ((Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash -ceq $originalHash) | Should Be $true
    ((Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash -ceq $markerHash) | Should Be $true
    Assert-C01OnlyCurrentSidAcl $markerPath
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretReceipt (Invoke-C01SecretRequest $read) $script:c01SecretPassword 'created'
  }

  It 'rejects marking an account that has no durable reservation' {
    $request = New-C01SecretRequest 'mark-created' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretFailure (Invoke-C01SecretRequest $request)
    (Test-Path -LiteralPath (Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi'))) | Should Be $false
  }

  It 'fails closed on corrupted encrypted reservation bytes' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $path = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $bytes = [IO.File]::ReadAllBytes($path)
    $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 1
    [IO.File]::WriteAllBytes($path, $bytes)
    foreach ($operation in @('read', 'mark-created')) {
      $request = New-C01SecretRequest $operation $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
      Assert-C01SecretFailure (Invoke-C01SecretRequest $request) 'SECRET_STORE_CORRUPT'
    }
  }

  It 'rejects a created marker whose encrypted bytes are corrupt' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $mark = New-C01SecretRequest 'mark-created' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $mark) $mark
    $path = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.created.dpapi')
    $bytes = [IO.File]::ReadAllBytes($path)
    $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 1
    [IO.File]::WriteAllBytes($path, $bytes)
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretFailure (Invoke-C01SecretRequest $read) 'SECRET_STORE_CORRUPT'
  }

  It 'binds a valid created marker to the exact original encrypted receipt' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
    $mark = New-C01SecretRequest 'mark-created' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretSuccess (Invoke-C01SecretRequest $mark) $mark
    $path = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $reserve.receipt.password = New-C01SecretPassword
    $encoding = [Text.UTF8Encoding]::new($false)
    $plain = $encoding.GetBytes((ConvertTo-Json -InputObject $reserve.receipt -Compress))
    $entropy = $encoding.GetBytes(('C01-AUTH-PERSONAS-v1|' + $script:c01SecretPlanId + '|' + $script:c01SecretAuthId + '|reserve'))
    try {
      # Deliberately replace with valid DPAPI ciphertext for the same identity:
      # only the marker's receipt hash detects this substitution.
      $replacement = [Security.Cryptography.ProtectedData]::Protect(
        $plain, $entropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
      [IO.File]::WriteAllBytes($path, $replacement)
    } finally { [Array]::Clear($plain, 0, $plain.Length) }
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    Assert-C01SecretFailure (Invoke-C01SecretRequest $read) 'SECRET_STORE_CORRUPT'
  }

  It 'preserves the original reservation after an unconsumed or interrupted response' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    $pending = Start-C01SecretProcess $reserve -DiscardResponse
    $receiptPath = Join-Path $script:c01SecretDirectory ($script:c01SecretAuthId + '.reserve.dpapi')
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not [IO.File]::Exists($receiptPath) -and $clock.ElapsedMilliseconds -lt 15000 -and -not $pending.Process.HasExited) {
      Start-Sleep -Milliseconds 5
    }
    ([IO.File]::Exists($receiptPath)) | Should Be $true
    # The response is deliberately never interpreted. Kill if still running;
    # a fast completed process still models a response lost by its caller.
    $pending.Process.StandardOutput.Close()
    if (-not $pending.Process.HasExited) { $pending.Process.Kill($true) }
    $pending.Process.WaitForExit(5000) | Out-Null
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    $result = Invoke-C01SecretRequest $read
    Assert-C01SecretSuccess $result $read
    Assert-C01SecretReceipt $result $script:c01SecretPassword 'reserved'
    $reserve.receipt.password = New-C01SecretPassword
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_COLLISION'
  }

  It 'rejects an insecure pre-existing root without silently repairing its ACL' {
    # Create this synthetic insecure root directly with its DACL. Set-Acl on
    # an existing protected directory can require unavailable SACL privileges.
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($c01SecretSid)
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
      $c01SecretSid, [Security.AccessControl.FileSystemRights]::FullControl,
      [Security.AccessControl.AccessControlType]::Allow))
    $everyone = [Security.Principal.SecurityIdentifier]::new('S-1-1-0')
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
      $everyone, [Security.AccessControl.FileSystemRights]::ReadAndExecute,
      [Security.AccessControl.AccessControlType]::Allow))
    [IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($script:c01SecretDirectory), $acl)
    $before = (Get-Acl -LiteralPath $script:c01SecretDirectory).Sddl
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INSECURE_DIRECTORY'
    ((Get-Acl -LiteralPath $script:c01SecretDirectory).Sddl -ceq $before) | Should Be $true
    (@(Get-ChildItem -LiteralPath $script:c01SecretDirectory -Force).Count -eq 0) | Should Be $true
  }

  It 'rejects a junction root without writing through it' {
    $target = Join-Path $script:c01SecretFixtureRoot 'junction-target'
    [IO.Directory]::CreateDirectory($target) | Out-Null
    Set-C01RestrictedDirectory $target
    New-Item -ItemType Junction -Path $script:c01SecretDirectory -Target $target -ErrorAction Stop | Out-Null
    $script:c01SecretJunctions.Add($script:c01SecretDirectory)
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INSECURE_DIRECTORY'
    (@(Get-ChildItem -LiteralPath $target -Force).Count -eq 0) | Should Be $true
  }

  It 'rejects a root under a Git ancestor and does not create a store' {
    [IO.Directory]::CreateDirectory((Join-Path $script:c01SecretFixtureRoot '.git')) | Out-Null
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INSECURE_DIRECTORY'
    (Test-Path -LiteralPath $script:c01SecretDirectory) | Should Be $false
  }

  It 'rejects unexpected receipt fields and invalid password lengths without creating a store' {
    foreach ($length in @(31, 257)) {
      $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId ('x' * $length)
      Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INVALID_REQUEST'
    }
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
    $reserve.receipt.extra = $true
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INVALID_REQUEST'
    (Test-Path -LiteralPath $script:c01SecretDirectory) | Should Be $false
  }

  It 'rejects control characters and a receipt attached to a read request' {
    $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId ($script:c01SecretPassword + [char]0x7f)
    Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INVALID_REQUEST'
    $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
    $read.receipt = $reserve.receipt
    Assert-C01SecretFailure (Invoke-C01SecretRequest $read) 'SECRET_STORE_INVALID_REQUEST'
  }

  It 'rejects vector-valued receipt identity and state instead of coercing them to strings' {
    foreach ($field in @('planId', 'authUserId', 'state')) {
      $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $script:c01SecretPassword
      $reserve.receipt[$field] = @($reserve.receipt[$field])
      Assert-C01SecretFailure (Invoke-C01SecretRequest $reserve) 'SECRET_STORE_INVALID_REQUEST'
    }
    (Test-Path -LiteralPath $script:c01SecretDirectory) | Should Be $false
  }

  It 'accepts both password-length boundaries in independent account reservations' {
    foreach ($length in @(32, 256)) {
      $script:c01SecretAuthId = [guid]::NewGuid().ToString()
      $boundaryPassword = ((New-C01SecretPassword) * 4).Substring(0, $length)
      $reserve = New-C01SecretRequest 'reserve' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId $boundaryPassword
      Assert-C01SecretSuccess (Invoke-C01SecretRequest $reserve) $reserve
      $read = New-C01SecretRequest 'read' $script:c01SecretDirectory $script:c01SecretPlanId $script:c01SecretAuthId
      $result = Invoke-C01SecretRequest $read
      Assert-C01SecretSuccess $result $read
      Assert-C01SecretReceipt $result $boundaryPassword 'reserved'
    }
  }
}
