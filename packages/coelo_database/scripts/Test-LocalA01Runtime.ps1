[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern('^coelo_safe_[0-9a-f]{29}$')][string]$ProjectId,
  [Parameter(Mandatory = $true)][string]$ClientRoot
)

$ErrorActionPreference = 'Stop'
$a01PackageRoot = Split-Path -Parent $PSScriptRoot

function Assert-A01Path([string]$Path, [bool]$Directory) {
  if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\r\n"\x00]') { throw 'A01 path must be an absolute local path' }
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if ($item.PSIsContainer -ne $Directory) { throw 'A01 path kind mismatch' }
  $cursor = $item
  while ($null -ne $cursor) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'A01 path contains a reparse point' }
    $cursor = if ($cursor.PSIsContainer) { $cursor.Parent } else { $cursor.Directory }
  }
  return $item.FullName
}

function Get-A01Sha([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function Get-A01FileHash([string]$Path) {
  $null = Assert-A01Path $Path $false
  return Get-A01Sha ([IO.File]::ReadAllText($Path).Replace("`r`n","`n").Replace("`r","`n").Replace("`n","`r`n"))
}

function Assert-A01ProjectPath([string]$Root, [string]$Identity) {
  $expected = Join-Path ([IO.Path]::GetTempPath()) $Identity
  if ($Identity -cnotmatch '^coelo_safe_[0-9a-f]{29}$' -or
      [IO.Path]::GetFullPath($Root).TrimEnd('\') -cne [IO.Path]::GetFullPath($expected).TrimEnd('\')) {
    throw 'A01 project must be the exact own disposable TEMP identity'
  }
  $null = Assert-A01Path $Root $true
  $marker = Assert-A01Path (Join-Path $Root '.coelo-safe-replay') $false
  if ([IO.File]::ReadAllText($marker) -cne $Identity) { throw 'A01 project marker mismatch' }
  $config = [IO.File]::ReadAllText((Assert-A01Path (Join-Path $Root 'supabase\config.toml') $false))
  $matches = [regex]::Matches($config, '(?m)^\s*project_id\s*=\s*"([^"]+)"\s*$')
  if ($matches.Count -ne 1 -or $matches[0].Groups[1].Value -cne $Identity) { throw 'A01 project config mismatch' }
}

function Assert-A01Origin([string]$Value) {
  $uri = $null
  if ($Value -cnotmatch '^http://127\.0\.0\.1:[0-9]{4,5}/?$' -or
      -not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
      $uri.Port -lt 1024 -or $uri.Port -gt 65535) { throw 'A01 origin must be explicit HTTP loopback' }
  return $uri
}

function ConvertTo-A01Base64Url([byte[]]$Bytes) { return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_') }
function ConvertFrom-A01JwtPayload([string]$Token) {
  try {
    $parts = $Token.Split('.')
    if ($parts.Count -ne 3) { throw 'shape' }
    $part = $parts[1].Replace('-','+').Replace('_','/')
    $part += '=' * ((4 - $part.Length % 4) % 4)
    return ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json)
  } catch { throw 'A01 JWT payload is invalid' }
}
function Test-A01JwtSignature([string]$Token, [string]$Secret) {
  $parts = $Token.Split('.')
  if ($parts.Count -ne 3) { return $false }
  $hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Secret))
  try { return (ConvertTo-A01Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($parts[0]+'.'+$parts[1])))) -ceq $parts[2] }
  finally { $hmac.Dispose() }
}
function New-A01Jwt([string]$Secret, [ValidateSet('Reader','Revoked','Denied')][string]$Actor, [long]$Now) {
  if ($Secret.Length -lt 32) { throw 'A01 signer is missing or invalid' }
  $suffix = @{ Reader=102; Revoked=104; Denied=106 }[$Actor]
  $claims = [ordered]@{ sub=('8a200000-0000-4000-8000-{0:d12}' -f $suffix); session_id=('8a200000-0000-4000-8000-{0:d12}' -f ($suffix+100)); role='authenticated'; aal='aal2'; aud='authenticated'; iat=$Now; exp=($Now+600) }
  $header = ConvertTo-A01Base64Url ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
  $payload = ConvertTo-A01Base64Url ([Text.Encoding]::UTF8.GetBytes(($claims | ConvertTo-Json -Compress)))
  $hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Secret))
  try { return $header+'.'+$payload+'.'+(ConvertTo-A01Base64Url ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($header+'.'+$payload)))) }
  finally { $hmac.Dispose() }
}

function New-A01ClientEnvironment([string]$Origin, [string]$Anon, [hashtable]$Tokens) {
  $null = Assert-A01Origin $Origin
  $environment = @{}
  # Deliberate OS/toolchain allowlist: parent credentials and signer are not inherited.
  foreach ($key in @('SystemRoot','WINDIR','COMSPEC','PATH','PATHEXT','TEMP','TMP','USERPROFILE','APPDATA','LOCALAPPDATA','PROGRAMDATA','PUB_CACHE','FLUTTER_ROOT')) {
    $value = [Environment]::GetEnvironmentVariable($key)
    if ($null -ne $value) { $environment[$key] = $value }
  }
  $environment.COELO_A01_LOCAL_RUNTIME = '1'
  $environment.COELO_A01_LOCAL_URL = $Origin
  $environment.COELO_A01_LOCAL_ANON_KEY = $Anon
  $environment.COELO_A01_READER_JWT = $Tokens.Reader
  $environment.COELO_A01_REVOKED_JWT = $Tokens.Revoked
  $environment.COELO_A01_DENIED_JWT = $Tokens.Denied
  return $environment
}

function Initialize-A01ProcessWindowType {
  if ('Coelo.A01ProcessWindow' -as [type]) { return }
  # Windows-only, private job. Child starts suspended so it cannot fork before assignment.
  # No breakaway flags; closing the job also terminates descendants after the parent exits.
  $definition = @"
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace Coelo {
  public sealed class A01ProcessResult {
    public int ExitCode; public string Output; public string Error;
  }
  public sealed class A01ProcessWindow : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct SA { public int Length; public IntPtr Descriptor; public int Inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct SI {
      public int Size; public string Reserved, Desktop, Title;
      public int X,Y,XSize,YSize,XChars,YChars,Fill,Flags; public short Show,ReservedBytes;
      public IntPtr ReservedPtr,Input,Output,Error;
    }
    [StructLayout(LayoutKind.Sequential)] struct PI { public IntPtr Process,Thread; public uint Id,ThreadId; }
    [StructLayout(LayoutKind.Sequential)] struct Limits {
      public long ProcessTime,JobTime; public uint Flags; public UIntPtr Min,Max; public uint Active;
      public UIntPtr Affinity; public uint Priority,Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IO { public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes; }
    [StructLayout(LayoutKind.Sequential)] struct Extended {
      public Limits Basic; public IO Io; public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)] struct Accounting {
      public long User,Kernel,PeriodUser,PeriodKernel; public uint Faults,Total,Active,Terminated;
    }
    [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int kind,ref Extended info,int length);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job,int kind,out Accounting info,int length,IntPtr returned);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(IntPtr job,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool CreatePipe(out IntPtr read,out IntPtr write,ref SA attributes,int size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetHandleInformation(IntPtr handle,uint mask,uint flags);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string app,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,ref SI startup,out PI process);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    IntPtr job,process,thread; bool assigned,disposed;
    StreamWriter input; StreamReader output,error;
    Task inputTask,exitTask; Task<string> outputTask,errorTask;
    readonly Stopwatch elapsed=Stopwatch.StartNew();
    static void Check(bool ok) { if (!ok) throw new InvalidOperationException("A01 process ownership operation failed"); }
    static void Close(ref IntPtr handle) { if(handle!=IntPtr.Zero) { CloseHandle(handle);handle=IntPtr.Zero; } }
    static FileStream Stream(ref IntPtr handle,FileAccess access) {
      var stream=new FileStream(new SafeFileHandle(handle,true),access,4096,false);handle=IntPtr.Zero;return stream;
    }
    public static bool UsesInheritedEnvironment(string environment) { return String.IsNullOrEmpty(environment); }
    public A01ProcessWindow(string file,string arguments,string cwd,string text,string environment) {
      IntPtr inRead=IntPtr.Zero,inWrite=IntPtr.Zero,outRead=IntPtr.Zero,outWrite=IntPtr.Zero,errRead=IntPtr.Zero,errWrite=IntPtr.Zero,env=IntPtr.Zero;
      try {
        job=CreateJobObject(IntPtr.Zero,null);Check(job!=IntPtr.Zero);
        var limits=new Extended();limits.Basic.Flags=0x2000;
        Check(SetInformationJobObject(job,9,ref limits,Marshal.SizeOf(typeof(Extended))));
        var sa=new SA { Length=Marshal.SizeOf(typeof(SA)),Inherit=1 };
        Check(CreatePipe(out inRead,out inWrite,ref sa,0));
        Check(CreatePipe(out outRead,out outWrite,ref sa,0));
        Check(CreatePipe(out errRead,out errWrite,ref sa,0));
        Check(SetHandleInformation(inWrite,1,0));Check(SetHandleInformation(outRead,1,0));Check(SetHandleInformation(errRead,1,0));
        var si=new SI { Size=Marshal.SizeOf(typeof(SI)),Flags=0x100,Input=inRead,Output=outWrite,Error=errWrite };
        PI pi;
        if(!UsesInheritedEnvironment(environment)) env=Marshal.StringToHGlobalUni(environment);
        // CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT | CREATE_NO_WINDOW.
        Check(CreateProcessW(file,new StringBuilder("\""+file+"\" "+arguments),IntPtr.Zero,IntPtr.Zero,true,0x08000404,env,cwd,ref si,out pi));
        process=pi.Process;thread=pi.Thread;
        Check(AssignProcessToJobObject(job,process));assigned=true;
        Close(ref inRead);Close(ref outWrite);Close(ref errWrite);
        input=new StreamWriter(Stream(ref inWrite,FileAccess.Write),new UTF8Encoding(false));
        output=new StreamReader(Stream(ref outRead,FileAccess.Read),new UTF8Encoding(false));
        error=new StreamReader(Stream(ref errRead,FileAccess.Read),new UTF8Encoding(false));
        Check(ResumeThread(thread)!=0xffffffff);Close(ref thread);
        outputTask=output.ReadToEndAsync();errorTask=error.ReadToEndAsync();
        inputTask=Task.Factory.StartNew(delegate {
          try { input.WriteAsync(text ?? "").GetAwaiter().GetResult();input.FlushAsync().GetAwaiter().GetResult(); }
          finally { input.Dispose(); }
        });
        exitTask=Task.Factory.StartNew(delegate { Check(WaitForSingleObject(process,0xffffffff)==0); });
      } catch { Dispose();throw; }
      finally {
        Close(ref inRead);Close(ref inWrite);Close(ref outRead);Close(ref outWrite);Close(ref errRead);Close(ref errWrite);
        if(env!=IntPtr.Zero) Marshal.FreeHGlobal(env);
      }
    }
    public bool Wait(int milliseconds) {
      int remaining=(int)Math.Max(0,(long)milliseconds-elapsed.ElapsedMilliseconds);
      return Task.WaitAll(new Task[] {inputTask,outputTask,errorTask,exitTask},remaining);
    }
    public A01ProcessResult GetResult() {
      if(!inputTask.IsCompleted || !outputTask.IsCompleted || !errorTask.IsCompleted || !exitTask.IsCompleted)
        throw new InvalidOperationException("A01 process result is incomplete");
      uint code;Check(GetExitCodeProcess(process,out code));
      return new A01ProcessResult { ExitCode=(int)code,Output=outputTask.GetAwaiter().GetResult(),Error=errorTask.GetAwaiter().GetResult() };
    }
    public void Dispose() {
      if(disposed) return;disposed=true;
      bool zero=true;
      try {
        if(job!=IntPtr.Zero && assigned) {
          Check(TerminateJobObject(job,1));
          var grace=Stopwatch.StartNew();Accounting state;
          do {
            Check(QueryInformationJobObject(job,1,out state,Marshal.SizeOf(typeof(Accounting)),IntPtr.Zero));
            if(state.Active==0) break;
            Thread.Sleep(10);
          } while(grace.ElapsedMilliseconds<5000);
          zero=state.Active==0;
        } else if(process!=IntPtr.Zero) {
          Check(TerminateProcess(process,1));zero=WaitForSingleObject(process,5000)==0;
        }
      } finally {
        // Closing the non-inherited job handle enforces KILL_ON_JOB_CLOSE even on errors.
        Close(ref job);Close(ref thread);Close(ref process);
        if(input!=null) { try { input.BaseStream.Dispose(); } catch {} }
        if(output!=null) output.Dispose();if(error!=null) error.Dispose();
      }
      if(!zero) throw new InvalidOperationException("A01 owned process cleanup could not prove zero");
    }
  }
}
"@
  Add-Type -TypeDefinition $definition -Language CSharp -ErrorAction Stop
}
function Complete-A01ProcessWindow($Window, [int]$TimeoutSeconds) {
  try {
    if (-not $Window.Wait($TimeoutSeconds * 1000)) { throw 'A01 local process timed out; owned job will be closed' }
    return $Window.GetResult()
  } finally { $Window.Dispose() }
}
function Invoke-A01CapturedProcess([string]$File, [string]$Arguments, [string]$WorkingDirectory, [string]$InputText, [int]$TimeoutSeconds = 30, [hashtable]$Environment) {
  Initialize-A01ProcessWindowType
  $block = $null
  if ($null -ne $Environment) {
    $block = ((@($Environment.Keys | Sort-Object | ForEach-Object { $_+'='+$Environment[$_] })) -join [string][char]0) + [char]0 + [char]0
  }
  $window = $null
  try {
    $window = [Coelo.A01ProcessWindow]::new($File,$Arguments,$WorkingDirectory,$InputText,$block)
    return Complete-A01ProcessWindow $window $TimeoutSeconds
  } catch {
    if ($_.Exception.Message -match 'timed out') { throw 'A01 local process timed out; owned job closed' }
    throw 'A01 local process failed; native output withheld'
  } finally { if ($null -ne $window) { $window.Dispose() } }
}
function Invoke-A01Git([string]$Root, [string]$Arguments) {
  $result = Invoke-A01CapturedProcess (Get-Command git.exe -ErrorAction Stop).Source $Arguments $Root
  if ($result.ExitCode -ne 0) { throw 'A01 client Git verification failed' }
  return $result.Output.Trim()
}
function Assert-A01Client([string]$Root) {
  $null = Assert-A01Path $Root $true
  if ((Invoke-A01Git $Root 'rev-parse HEAD') -cne 'f0be734ac3210c84523a61700f73feaba5150368' -or
      (Invoke-A01Git $Root 'status --porcelain --untracked-files=all') -ne '') { throw 'A01 client requires exact f0be734a and a clean checkout' }
  if ((Invoke-A01Git $Root 'rev-parse HEAD:apps/superadmin') -cne '8fc63de9f4862b05ceea4b3d233c6e1977443cde' -or
      (Invoke-A01Git $Root 'rev-parse HEAD:packages') -cne 'cb6baa89f821a4a775bdc8bb1055668d053ec35e') { throw 'A01 client dependency tree pin mismatch' }
  $tracked = (Invoke-A01Git $Root 'ls-files -v -- apps/superadmin packages') -split '\r?\n'
  foreach ($line in $tracked) {
    if ($line -cnotmatch '^H (.+)$') { throw 'A01 client hidden index flags are forbidden' }
    $null = Assert-A01Path (Join-Path $Root $Matches[1]) $false
  }
  $packageConfig = Assert-A01Path (Join-Path $Root 'apps\superadmin\.dart_tool\package_config.json') $false
  $packages = @(([IO.File]::ReadAllText($packageConfig) | ConvertFrom-Json).packages)
  $expected = @('coelo_api','coelo_auth','coelo_domain','coelo_tokens','coelo_ui_admin','coelo_ui_core','coelo_superadmin')
  if (@($packages | Where-Object { $_.name -like 'coelo_*' }).Count -ne $expected.Count) { throw 'A01 client local dependency set mismatch' }
  foreach ($name in $expected) {
    $entry = @($packages | Where-Object name -ceq $name)
    $target = if ($name -ceq 'coelo_superadmin') { Join-Path $Root 'apps\superadmin' } else { Join-Path $Root ('packages\'+$name) }
    if ($entry.Count -ne 1) { throw 'A01 client local dependency is missing' }
    $uri = [Uri]::new([Uri]::new($packageConfig), [string]$entry[0].rootUri)
    if (-not $uri.IsFile -or $uri.LocalPath.TrimEnd('\','/') -ine $target.TrimEnd('\','/')) { throw 'A01 client dependency path escape' }
    $null = Assert-A01Path $uri.LocalPath $true
  }
  return Join-Path $Root 'apps\superadmin'
}

function Get-A01Inputs([string]$PackageRoot) {
  $resolver = Join-Path $PackageRoot 'replay\profiles\A01DirectoryAuditGreen\Resolve-A01DirectoryAuditGreen.ps1'
  if ((Get-A01FileHash $resolver) -cne '6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2') { throw 'A01 resolver pin mismatch' }
  $profile = & $resolver -TargetVersion '20260907222911'
  $inputs = @(@($profile.Canonical) + @($profile.Preflight) | Sort-Object Name)
  if ($inputs.Count -ne 55 -or $inputs[-1].Name -cne '20260907222911_superadmin_activity_directory_v2_client_contract.sql') { throw 'A01 inputs require Green55' }
  return $inputs
}
function Assert-A01StagedInputs([string]$Root, [object[]]$Inputs) {
  foreach ($relative in @('validated-migrations','supabase\migrations')) {
    $directory = Assert-A01Path (Join-Path $Root $relative) $true
    $files = @(Get-ChildItem -LiteralPath $directory -Force)
    if ($files.Count -ne 55) { throw 'A01 staged input count mismatch' }
    foreach ($input in $Inputs) {
      if ((Get-A01FileHash (Join-Path $directory $input.Name)) -cne (Get-A01FileHash $input.FullName)) { throw 'A01 staged input pin mismatch' }
    }
  }
}
function Assert-A01Ledger([string[]]$Versions, [object[]]$Inputs) {
  $expected = @($Inputs | ForEach-Object { $_.Name.Substring(0,14) } | Sort-Object)
  if ($Versions.Count -ne 55 -or $expected.Count -ne 55 -or
      @($Versions | Sort-Object -Unique).Count -ne 55 -or
      @(Compare-Object $expected @($Versions | Sort-Object) -SyncWindow 0).Count -ne 0) { throw 'A01 ledger must match exactly the 55 reviewed versions' }
}

function Get-A01DockerOverrideNames {
  return @(Get-ChildItem Env: | Where-Object { $_.Name -match '^SUPABASE_' -or $_.Name -in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH') } | Select-Object -ExpandProperty Name)
}
function Assert-A01DockerContext {
  if (@(Get-A01DockerOverrideNames).Count -gt 0) { throw 'A01 Docker overrides are forbidden (values withheld)' }
  $docker = (Get-Command docker.exe -ErrorAction Stop).Source
  $context = Invoke-A01CapturedProcess $docker 'context show' $ProjectRoot
  if ($context.ExitCode -ne 0 -or $context.Output.Trim() -cnotmatch '^[a-zA-Z0-9_.-]+$') { throw 'A01 Docker context is invalid' }
  $name = $context.Output.Trim()
  if ($script:a01DockerContext -and $script:a01DockerContext -cne $name) { throw 'A01 Docker context changed' }
  $endpoint = Invoke-A01CapturedProcess $docker ('context inspect '+$name+' --format "{{.Endpoints.docker.Host}}"') $ProjectRoot
  if ($endpoint.ExitCode -ne 0 -or $endpoint.Output.Trim() -cnotmatch '^npipe:/+\./pipe/[a-zA-Z0-9_.-]+$') { throw 'A01 Docker requires local Windows named pipe' }
  $pipe = $endpoint.Output.Trim()
  if ($script:a01DockerEndpoint -and $script:a01DockerEndpoint -cne $pipe) { throw 'A01 Docker endpoint changed' }
  $script:a01DockerContext = $name
  $script:a01DockerEndpoint = $pipe
}
function Invoke-A01Docker([string]$Arguments, [string]$InputText) {
  if (-not $script:a01DockerEndpoint -or @(Get-A01DockerOverrideNames).Count -gt 0) { throw 'A01 Docker endpoint was not established or overrides changed' }
  $result = Invoke-A01CapturedProcess (Get-Command docker.exe -ErrorAction Stop).Source ('--host '+$script:a01DockerEndpoint+' '+$Arguments) $ProjectRoot $InputText
  if ($result.ExitCode -ne 0) { throw 'A01 own Docker verification failed' }
  return $result.Output.Trim()
}
function Invoke-A01Sql([string]$Sql) {
  return Invoke-A01Docker ('exec -i supabase_db_'+$ProjectId+' psql -X -q -A -t --username postgres --dbname postgres --set ON_ERROR_STOP=1') $Sql
}

function ConvertFrom-A01Environment([object[]]$Lines) {
  $result = @{}
  foreach ($line in $Lines) {
    if ($line -cmatch '^([A-Z][A-Z0-9_]*)=(.*)$') {
      if ($result.ContainsKey($Matches[1])) { throw 'A01 environment has duplicate fields' }
      $result[$Matches[1]] = $Matches[2].Trim('"')
    }
  }
  return $result
}

function Assert-A01KongRouting([string]$Routing, [string[]]$RestAliases, [string[]]$AuthAliases) {
  # Closed parser for the CLI's literal service blocks, not a general YAML interpreter.
  $blocks = @([regex]::Matches($Routing,'(?ms)^  - name: [^\r\n]+\r?\n.*?(?=^  - name: |\z)') | ForEach-Object Value)
  foreach ($route in @(@('/rest/v1',3000,$RestAliases),@('/auth/v1',9999,$AuthAliases))) {
    $pathPattern = '(?m)^\s+- ["'']?'+[regex]::Escape($route[0])+'/?["'']?\s*$'
    $selected = @($blocks | Where-Object { $_ -match $pathPattern })
    if ($selected.Count -ne 1) { throw 'A01 Kong requires exactly one service for each nominal route' }
    $urls = [regex]::Matches($selected[0], '(?m)^    url:\s*["'']?(http://[^\s"'']+)["'']?\s*$')
    $uri = $null
    if ($urls.Count -ne 1 -or -not [Uri]::TryCreate($urls[0].Groups[1].Value,[UriKind]::Absolute,[ref]$uri) -or
        $uri.Scheme -cne 'http' -or $uri.Port -ne $route[1] -or $uri.Host -cnotin $route[2] -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -cne '/') { throw 'A01 Kong nominal route does not target the own service' }
  }
}
function Get-A01LocalStatus {
  Assert-A01DockerContext
  $childEnvironment = @{}
  foreach ($key in @('SystemRoot','WINDIR','COMSPEC','PATH','PATHEXT','TEMP','TMP','USERPROFILE','APPDATA','LOCALAPPDATA','PROGRAMDATA')) {
    $value = [Environment]::GetEnvironmentVariable($key)
    if ($null -ne $value) { $childEnvironment[$key] = $value }
  }
  $childEnvironment.DOCKER_HOST = $script:a01DockerEndpoint
  $status = Invoke-A01CapturedProcess -File $env:COMSPEC -Arguments ('/d /s /c "npx.cmd --yes supabase@2.116.0 --agent no status --workdir ""'+$ProjectRoot+'"" --output env"') -WorkingDirectory $ProjectRoot -Environment $childEnvironment
  if ($status.ExitCode -ne 0) { throw 'A01 local status failed' }
  return ConvertFrom-A01Environment ($status.Output -split '\r?\n')
}
function Get-A01RuntimeIdentity {
  $names = @('supabase_db_','supabase_auth_','supabase_rest_','supabase_kong_') | ForEach-Object { $_+$ProjectId }
  $decodedContainers = Invoke-A01Docker ('inspect --type container '+($names -join ' ')) | ConvertFrom-Json
  $containers = @($decodedContainers)
  if ($containers.Count -ne 4) { throw 'A01 requires DB, Auth, REST and Kong running' }
  foreach ($container in $containers) {
    if ($container.Name.TrimStart('/') -cnotin $names -or -not $container.State.Running -or
        $container.Config.Labels.'com.supabase.cli.project' -cne $ProjectId) { throw 'A01 container identity mismatch' }
    if ($container.State.Health -and $container.State.Health.Status -cne 'healthy') { throw 'A01 container is not healthy' }
  }
  $db = @($containers | Where-Object Name -ceq ('/supabase_db_'+$ProjectId))[0]
  $rest = @($containers | Where-Object Name -ceq ('/supabase_rest_'+$ProjectId))[0]
  $auth = @($containers | Where-Object Name -ceq ('/supabase_auth_'+$ProjectId))[0]
  $kong = @($containers | Where-Object Name -ceq ('/supabase_kong_'+$ProjectId))[0]
  $networks = @($db.NetworkSettings.Networks.PSObject.Properties)
  if ($networks.Count -ne 1 -or $networks[0].Name -cne ('supabase_network_'+$ProjectId)) { throw 'A01 own network mismatch' }
  $networkName = $networks[0].Name; $networkId = $networks[0].Value.NetworkID
  foreach ($container in $containers) {
    $network = $container.NetworkSettings.Networks.$networkName
    if ($null -eq $network -or $network.NetworkID -cne $networkId -or @($container.NetworkSettings.Networks.PSObject.Properties).Count -ne 1) { throw 'A01 container network escape' }
  }
  $mounts = @($db.Mounts | Where-Object Destination -ceq '/var/lib/postgresql/data')
  if ($mounts.Count -ne 1 -or $mounts[0].Type -cne 'volume' -or $mounts[0].Name -cne ('supabase_db_'+$ProjectId)) { throw 'A01 DB volume identity mismatch' }
  $restEnv = ConvertFrom-A01Environment $rest.Config.Env
  $authEnv = ConvertFrom-A01Environment $auth.Config.Env
  foreach ($connection in @($restEnv.PGRST_DB_URI, $authEnv.GOTRUE_DB_DATABASE_URL)) {
    $uri = $null
    if (-not [Uri]::TryCreate($connection,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('postgres','postgresql') -or
        $uri.AbsolutePath -cne '/postgres' -or $uri.Port -ne 5432 -or $uri.Host -cnotin @($networks[0].Value.Aliases)) { throw 'A01 service does not target the own DB' }
  }
  $environment = Get-A01LocalStatus
  $origin = Assert-A01Origin $environment.API_URL
  $ports = @($kong.NetworkSettings.Ports.'8000/tcp')
  if ($ports.Count -lt 1 -or @($ports | Where-Object { [int]$_.HostPort -eq $origin.Port -and $_.HostIp -in @('127.0.0.1','0.0.0.0') }).Count -ne 1) { throw 'A01 Kong endpoint port mismatch' }
  if ($environment.JWT_SECRET.Length -lt 32 -or $restEnv.PGRST_JWT_SECRET -cne $environment.JWT_SECRET -or
      $authEnv.GOTRUE_JWT_SECRET -cne $environment.JWT_SECRET -or
      (ConvertFrom-A01JwtPayload $environment.ANON_KEY).role -cne 'anon' -or
      -not (Test-A01JwtSignature $environment.ANON_KEY $environment.JWT_SECRET)) { throw 'A01 local signing configuration mismatch' }
  $kongEnv = ConvertFrom-A01Environment $kong.Config.Env
  if ($kongEnv.KONG_DECLARATIVE_CONFIG -cne '/home/kong/kong.yml') { throw 'A01 Kong declarative path mismatch' }
  $routing = Invoke-A01Docker ('exec supabase_kong_'+$ProjectId+' cat /home/kong/kong.yml')
  Assert-A01KongRouting $routing @($rest.NetworkSettings.Networks.$networkName.Aliases) @($auth.NetworkSettings.Networks.$networkName.Aliases)

  return $environment
}

function Test-A01Startup([hashtable]$Environment) {
  Add-Type -AssemblyName System.Net.Http
  $handler = [Net.Http.HttpClientHandler]::new(); $handler.AllowAutoRedirect = $false; $handler.UseProxy = $false
  $http = [Net.Http.HttpClient]::new($handler); $http.Timeout = [TimeSpan]::FromSeconds(10)
  try {
    foreach ($path in @('/auth/v1/health','/rest/v1/')) {
      $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, $Environment.API_URL.TrimEnd('/')+$path)
      $request.Headers.Add('apikey',$Environment.ANON_KEY)
      try {
        $response = $http.SendAsync($request).GetAwaiter().GetResult()
        try { if ([int]$response.StatusCode -ne 200) { throw 'A01 local service startup failed' } }
        finally { $response.Dispose() }
      } finally { $request.Dispose() }
    }
  } catch { throw 'A01 local service startup failed' }
  finally { $http.Dispose(); $handler.Dispose() }
}

function Get-A01DomainSnapshot {
  # Equality is scoped to these local domain/authorization tables for the tested HTTP commands.
  $tables = @('public.activity_definitions','public.activity_unit_links','public.activity_group_links','public.activity_admin_capability_actions','public.activity_assignment_capability_actions','public.activity_taxonomies','public.activity_taxonomy_requests','public.activity_handle_aliases','public.activity_locations','public.activity_templates','public.institutions','public.units','public.groups','public.platform_roles','public.platform_permissions','public.platform_role_permissions','public.people','public.person_auth_links','app_private.superadmin_internal_identities','app_private.superadmin_internal_auth_links','app_private.superadmin_internal_memberships','app_private.activity_management_command_receipts','app_private.superadmin_internal_activity_command_receipts')
  $parts = @($tables | ForEach-Object { "select '$_' as relation, md5(coalesce((select jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text)::text from $_ t),'[]')) as digest" })
  return Invoke-A01Sql ('select coalesce(jsonb_agg(row_to_json(s) order by relation),''[]''::jsonb)::text from ('+($parts -join ' union all ')+') s;')
}

function ConvertFrom-A01FlutterReport([string]$Output, [int]$ExitCode) {
  if ($ExitCode -ne 0) { throw 'A01 Flutter failed; child output withheld' }
  if ($Output.Length -gt 1048576 -or $Output -notmatch 'All tests passed!') { throw 'A01 Flutter did not finish the nominal test' }
  $matches = [regex]::Matches($Output,'(?m)A01_LOCAL_HTTP_CORRELATIONS (\[[^\r\n]*\])')
  if ($matches.Count -ne 1) { throw 'A01 Flutter must emit exactly one completed correlation report' }
  try { $decodedRecords = $matches[0].Groups[1].Value | ConvertFrom-Json; $records = @($decodedRecords) } catch { throw 'A01 correlation report is invalid' }
  $rpcNames = @('superadmin_auth_bootstrap_context','superadmin_activity_directory_v2','superadmin_activity_filter_options_v2')
  if ($records.Count -lt 7 -or $records.Count -gt 100) { throw 'A01 correlation report count is invalid' }
  foreach ($record in $records) {
    if (@($record.PSObject.Properties).Count -ne 4 -or $record.rpc -cnotin $rpcNames -or
        $record.http_status -ne 200 -or $record.ok -isnot [bool]) { throw 'A01 correlation report contains a nonnominal request' }
    if ($record.rpc -cne $rpcNames[0] -and $record.correlation_id -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') { throw 'A01 correlation identifier is invalid' }
  }
  $activities = @($records | Where-Object rpc -cne $rpcNames[0])
  if (@($activities.correlation_id | Sort-Object -Unique).Count -ne $activities.Count -or
      @($records | Where-Object rpc -ceq $rpcNames[0]).Count -lt 3) { throw 'A01 correlation report is incomplete or duplicated' }
  foreach ($rpc in $rpcNames[1..2]) {
    if (@($activities | Where-Object { $_.rpc -ceq $rpc -and $_.ok }).Count -lt 1 -or
        @($activities | Where-Object { $_.rpc -ceq $rpc -and -not $_.ok }).Count -lt 1) { throw 'A01 correlation positive/negative coverage is missing' }
  }
  return $activities
}

function Assert-A01Audit([object[]]$Records, [object[]]$Rows) {
  if ($Rows.Count -ne $Records.Count) { throw 'A01 audit correlation count mismatch' }
  $seenActors = @{}
  foreach ($record in $Records) {
    $matches = @($Rows | Where-Object correlation_id -ceq $record.correlation_id)
    if ($matches.Count -ne 1) { throw 'A01 audit correlation missing or duplicated' }
    $row = $matches[0]
    $action = if ($record.rpc -ceq 'superadmin_activity_directory_v2') { 'activity.directory' } else { 'activity.filter_options' }
    $suffix = if ($record.ok) { 302 } elseif ($row.actor_internal_identity_id -ceq '8a200000-0000-4000-8000-000000000304') { 304 } else { 306 }
    $id = '8a200000-0000-4000-8000-{0:d12}'
    $expectedOutcome = if ($record.ok) { 'success' } else { 'denied' }
    $sessionHash = Get-A01Sha ($id -f ($suffix-100))
    if ($row.action_code -cne $action -or $row.permission_code -cne 'activities.read' -or $row.outcome -cne $expectedOutcome -or
        $row.actor_kind -cne 'superadmin_internal' -or $row.actor_internal_identity_id -cne ($id -f $suffix) -or
        $row.actor_internal_auth_link_id -cne ($id -f ($suffix+100)) -or $row.actor_internal_membership_id -cne ($id -f ($suffix+200)) -or
        $row.session_id_hash -cne $sessionHash -or $row.mfa_aal -cne 'aal2' -or $row.actor_person_id -or $row.before_json -or
        $row.object_id -or -not $row.integrity) { throw 'A01 audit actor, action or integrity mismatch' }
    if ($record.ok) {
      if ($row.institution_id -cne ($id -f 10) -or $row.context_kind -cne 'institution' -or $row.context_id -cne ($id -f 10) -or
          $row.reason_code -or @($row.after_json.PSObject.Properties).Count -ne 1 -or
          $row.after_json.row_count -isnot [ValueType] -or
          ($action -ceq 'activity.directory' -and $row.after_json.row_count -notin @(0,2)) -or
          ($action -ceq 'activity.filter_options' -and $row.after_json.row_count -ne 8)) { throw 'A01 audit success scope or minimized counts mismatch' }
    } else {
      $reason = if ($suffix -eq 304) { 'SAI_MEMBERSHIP_REVOKED' } else { 'SAI_PERMISSION_DENIED' }
      if ($row.reason_code -cne $reason -or $row.institution_id -or $row.context_id -or $row.context_kind -cne 'global' -or $row.after_json) { throw 'A01 audit denied scope or reason mismatch' }
    }
    $seenActors[$suffix] = $true
  }
  if ($seenActors.Count -ne 3) { throw 'A01 audit must cover reader, revoked and denied actors' }
}

function Invoke-A01Flutter([string]$ApplicationRoot, [hashtable]$Environment) {
  $flutter = (Get-Command flutter.bat -ErrorAction Stop).Source
  $null = Assert-A01Path $flutter $false
  $arguments = '/d /s /c ""'+$flutter+'" test --no-pub test/features/activities/a01_local_runtime_test.dart"'
  return Invoke-A01CapturedProcess $env:COMSPEC $arguments $ApplicationRoot '' 180 $Environment
}

function Invoke-A01LocalRuntime {
  Assert-A01ProjectPath $ProjectRoot $ProjectId
  $applicationRoot = Assert-A01Client $ClientRoot
  $inputs = @(Get-A01Inputs $a01PackageRoot)
  Assert-A01StagedInputs $ProjectRoot $inputs
  $seed = Join-Path $a01PackageRoot 'tests\fixtures\a01_local_http_seed.sql'
  if ((Get-A01FileHash $seed) -cne '758e6b4b3c8ad237ec709acd17c0fe59c9d554f6c789c76bbb81ab13a67adf99') { throw 'A01 seed pin mismatch' }
  $script:a01DockerContext = $null
  $script:a01DockerEndpoint = $null
  Assert-A01DockerContext
  $environment = Get-A01RuntimeIdentity
  try {
    $ledger = @(Invoke-A01Sql 'select version from supabase_migrations.schema_migrations order by version;' ) -split '\r?\n'
    Assert-A01Ledger $ledger $inputs
    Test-A01Startup $environment
    # The opt-in and exact seed share the same psql session. No free seed path or SQL argument is exposed.
    $null = Invoke-A01Sql ("set coelo.local_replay = 'a01-http-green55';`n"+[IO.File]::ReadAllText($seed))
    $before = Get-A01DomainSnapshot
    if (-not $before -or $before -eq '[]') { throw 'A01 domain snapshot is empty' }
    $tokens = @{}; $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    foreach ($actor in @('Reader','Revoked','Denied')) { $tokens[$actor] = New-A01Jwt $environment.JWT_SECRET $actor $now }
    $childEnvironment = New-A01ClientEnvironment $environment.API_URL $environment.ANON_KEY $tokens
    $result = Invoke-A01Flutter $applicationRoot $childEnvironment
    $records = @(ConvertFrom-A01FlutterReport $result.Output $result.ExitCode)
    $ids = @($records | ForEach-Object { "'$($_.correlation_id)'::uuid" }) -join ','
    $auditSql = 'select coalesce(jsonb_agg(jsonb_build_object('+
      '''correlation_id'',a.correlation_id,''action_code'',a.action_code,''permission_code'',a.permission_code,''outcome'',a.outcome,'+
      '''actor_kind'',a.actor_kind,''actor_internal_identity_id'',a.actor_internal_identity_id,''actor_internal_auth_link_id'',a.actor_internal_auth_link_id,'+
      '''actor_internal_membership_id'',a.actor_internal_membership_id,''session_id_hash'',encode(a.session_id_hash,''hex''),''mfa_aal'',a.mfa_aal,'+
      '''actor_person_id'',a.actor_person_id,''institution_id'',a.institution_id,''context_kind'',a.context_kind,''context_id'',a.context_id,'+
      '''before_json'',a.before_json,''after_json'',a.after_json,''object_id'',a.object_id,''reason_code'',a.reason_code,'+
      '''integrity'',app_private.audit_entry_matches_digest(a))),''[]''::jsonb)::text from audit.audit_logs a where correlation_id in ('+$ids+');'
    $decodedRows = Invoke-A01Sql $auditSql | ConvertFrom-Json
    $rows = @($decodedRows)
    Assert-A01Audit $records $rows
    if ((Get-A01DomainSnapshot) -cne $before) { throw 'A01 tested HTTP commands changed the domain snapshot' }
    $null = Assert-A01Client $ClientRoot
    [pscustomobject]@{ Profile='A01DirectoryAuditGreen'; Target='20260907222911'; LedgerCount=55; HttpActivityResponses=$records.Count; AuditRows=$rows.Count; DomainUnchanged=$true; ClientCommit='f0be734ac3210c84523a61700f73feaba5150368'; Scope='Three nominal HTTP RPCs and tested UI commands only; inherited taxonomy.manage retained' }
  } finally {
    # No credentials or raw child/status/audit output are emitted. The caller owns stack teardown in its existing finally.
    $environment = $null; $tokens = $null; $childEnvironment = $null; $result = $null; $rows = $null
  }
}

# Dot-source imports only the named functions for Pester mocks; normal invocation always runs the closed path.
if ($MyInvocation.InvocationName -ne '.') { Invoke-A01LocalRuntime }
