[CmdletBinding()]
param()

# No replay target, SQL path, extension installer or keep-alive mode.
# Dot-sourcing defines test boundaries without running native commands.
$script:formsPreflightRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))

function Get-FormsPreflightTempRoot { [IO.Path]::GetTempPath() }
function New-FormsPreflightIdentity { 'coelo_fauthor_' + [guid]::NewGuid().ToString('N').Substring(0, 26) }
function New-FormsPreflightMutex { [Threading.Mutex]::new($false, 'Local\CoeloSafeSupabaseReplay') }
function Get-FormsPreflightEnvironmentNames {
  @(Get-ChildItem Env: | Where-Object {
    $_.Name -match '^(SUPABASE_|PGDELTA_)' -or $_.Name -in @('DOCKER_HOST','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH')
  } | Select-Object -ExpandProperty Name)
}
function Get-FormsPreflightPort {
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  try { $listener.Start(); ([Net.IPEndPoint]$listener.LocalEndpoint).Port }
  finally { $listener.Stop() }
}
function Assert-FormsPreflightAncestors([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  while ($null -ne $item) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'F-AUTHOR path contains a reparse point' }
    $item = if ($item.PSIsContainer) { $item.Parent } else { $item.Directory }
  }
}
function Get-FormsPreflightTree([string]$Path) {
  Assert-FormsPreflightAncestors $Path
  $queue = New-Object Collections.Queue
  $queue.Enqueue($Path)
  while ($queue.Count -gt 0) {
    foreach ($item in @(Get-ChildItem -LiteralPath $queue.Dequeue() -Force -ErrorAction Stop)) {
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'F-AUTHOR tree contains a reparse point' }
      $item
      if ($item.PSIsContainer) { $queue.Enqueue($item.FullName) }
    }
  }
}
function New-FormsPreflightContext {
  $temp = [IO.Path]::GetFullPath((Get-FormsPreflightTempRoot)).TrimEnd('\','/')
  Assert-FormsPreflightAncestors $temp
  $id = New-FormsPreflightIdentity
  if ($id -cnotmatch '^coelo_fauthor_[a-f0-9]{26}$') { throw 'invalid F-AUTHOR identity' }
  $root = [IO.Path]::GetFullPath((Join-Path $temp $id))
  if ([IO.Path]::GetDirectoryName($root) -ine $temp -or
      $root.StartsWith($script:formsPreflightRepository.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'F-AUTHOR project must be an immediate TEMP child outside the repository'
  }
  $port = Get-FormsPreflightPort
  do { $shadowPort = Get-FormsPreflightPort } while ($port -eq $shadowPort)
  $config = @"
project_id = "$id"
[api]
enabled = false
[db]
port = $port
shadow_port = $shadowPort
major_version = 17
health_timeout = "2m"
[db.migrations]
enabled = false
schema_paths = []
[db.seed]
enabled = false
sql_paths = []
[db.pooler]
enabled = false
[auth]
enabled = true
[storage]
enabled = true
[realtime]
enabled = false
"@
  $supabase = Join-Path $root 'supabase'
  [pscustomobject]@{
    Identity=$id; Temp=$temp; Root=$root; Supabase=$supabase; DbPort=$port
    Migrations=(Join-Path $supabase 'migrations'); ConfigPath=(Join-Path $supabase 'config.toml')
    ConfigText=$config; Marker=(Join-Path $root '.forms-authoring-owner')
    MarkerText=($id + '|' + $root + '|' + [guid]::NewGuid().ToString('N'))
    Created=$false; StartAttempted=$false; DockerContext=$null; LastEvidence=$null
  }
}
function New-FormsPreflightProject($Context) {
  if (Test-Path -LiteralPath $Context.Root) { throw 'F-AUTHOR project already exists' }
  Assert-FormsPreflightAncestors $Context.Temp
  $null = New-Item -ItemType Directory -Path $Context.Root -ErrorAction Stop
  $Context.Created = $true
  [IO.File]::WriteAllText($Context.Marker, $Context.MarkerText, [Text.UTF8Encoding]::new($false))
  $null = New-Item -ItemType Directory -Path $Context.Supabase -ErrorAction Stop
  $null = New-Item -ItemType Directory -Path $Context.Migrations -ErrorAction Stop
  [IO.File]::WriteAllText($Context.ConfigPath, $Context.ConfigText, [Text.UTF8Encoding]::new($false))
}
function Assert-FormsPreflightProject($Context, [switch]$BeforeStart) {
  if (-not $Context.Created -or $Context.Identity -cnotmatch '^coelo_fauthor_[a-f0-9]{26}$' -or
      [IO.Path]::GetFullPath($Context.Root) -ine (Join-Path $Context.Temp $Context.Identity) -or
      [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Context.Root)) -ine $Context.Temp) {
    throw 'F-AUTHOR project ownership is not established'
  }
  $tree = @(Get-FormsPreflightTree $Context.Root)
  if (-not (Test-Path -LiteralPath $Context.Marker -PathType Leaf) -or
      [IO.File]::ReadAllText($Context.Marker) -cne $Context.MarkerText) { throw 'F-AUTHOR owner marker mismatch' }
  if (-not (Test-Path -LiteralPath $Context.ConfigPath -PathType Leaf) -or
      [IO.File]::ReadAllText($Context.ConfigPath) -cne $Context.ConfigText) { throw 'F-AUTHOR startup config mismatch' }
  if (-not (Test-Path -LiteralPath $Context.Migrations -PathType Container) -or
      @(Get-ChildItem -LiteralPath $Context.Migrations -Force).Count -ne 0) { throw 'F-AUTHOR migrations must remain empty' }
  if ($BeforeStart) {
    $allowed = @($Context.Marker, $Context.Supabase, $Context.ConfigPath, $Context.Migrations)
    if (@($tree | Where-Object { $_.FullName -notin $allowed }).Count -ne 0) { throw 'unexpected startup path in F-AUTHOR project' }
  }
}
function Initialize-FormsPreflightProcessWindowType {
  if ('Coelo.FormsPreflight.ProcessWindow' -as [type]) { return }
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
namespace Coelo.FormsPreflight {
  public sealed class ProcessResult {
    public int ExitCode; public string Output; public string Error;
  }
  public sealed class ProcessWindow : IDisposable {
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
    static void Check(bool ok) { if (!ok) throw new InvalidOperationException("F-AUTHOR process ownership operation failed"); }
    static void Close(ref IntPtr handle) { if(handle!=IntPtr.Zero) { CloseHandle(handle);handle=IntPtr.Zero; } }
    static FileStream Stream(ref IntPtr handle,FileAccess access) {
      var stream=new FileStream(new SafeFileHandle(handle,true),access,4096,false);handle=IntPtr.Zero;return stream;
    }

    public ProcessWindow(string file,string arguments,string cwd,string text,string environment) {
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
        if(!String.IsNullOrEmpty(environment)) env=Marshal.StringToHGlobalUni(environment);
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
    public ProcessResult GetResult() {
      if(!inputTask.IsCompleted || !outputTask.IsCompleted || !errorTask.IsCompleted || !exitTask.IsCompleted)
        throw new InvalidOperationException("F-AUTHOR process result is incomplete");
      uint code;Check(GetExitCodeProcess(process,out code));
      return new ProcessResult { ExitCode=(int)code,Output=outputTask.GetAwaiter().GetResult(),Error=errorTask.GetAwaiter().GetResult() };
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
      if(!zero) throw new InvalidOperationException("F-AUTHOR owned process cleanup could not prove zero");
    }
  }
}
"@
  Add-Type -TypeDefinition $definition -Language CSharp -ErrorAction Stop
}
function New-FormsPreflightProcessWindow([string]$File, [string]$Arguments, [string]$WorkingDirectory) {
  Initialize-FormsPreflightProcessWindowType
  [Coelo.FormsPreflight.ProcessWindow]::new($File, $Arguments, $WorkingDirectory, $null, $null)
}
function Complete-FormsPreflightProcessWindow($Window, [ValidateSet(30,60,240)][int]$TimeoutSeconds) {
  $result=$null; $primary=$null
  try {
    if (-not $Window.Wait($TimeoutSeconds * 1000)) { throw [TimeoutException]::new('F-AUTHOR native deadline elapsed') }
    $result=$Window.GetResult()
  } catch { $primary=$_.Exception }
  finally {
    try { $Window.Dispose() }
    catch { throw [InvalidOperationException]::new('F-AUTHOR native cleanup unproven') }
  }
  if ($primary) { throw $primary }
  return $result
}
function Convert-FormsPreflightDockerArguments([string[]]$Arguments) {
  # Serialize Win32 argv once, including embedded quotes and trailing backslashes.
  # CreateProcessW is called directly; PowerShell Legacy escaping must not precede this.
  foreach ($argument in $Arguments) {
    $escaped=[regex]::Replace([string]$argument, '(\\*)"', '$1$1\"')
    $escaped=[regex]::Replace($escaped, '(\\+)$', '$1$1')
    '"' + $escaped + '"'
  }
}
function Invoke-FormsPreflightNative(
  [ValidateSet('docker','cli')]$Tool, [string[]]$Arguments, [string]$WorkingDirectory,
  [Parameter(Mandatory=$true)][ValidateSet(30,60,240)][int]$TimeoutSeconds
) {
  # Capture both pipes without streaming native setup output or raw failure details.
  $window=$null; $constructionAttempted=$false
  try {
    if (-not $WorkingDirectory) { $WorkingDirectory=$script:formsPreflightRepository }
    if ($Tool -eq 'cli') {
      $npx=(Get-Command -Name npx.cmd -CommandType Application -ErrorAction Stop).Source
      $file=$env:COMSPEC
      $tokens=@(Convert-FormsPreflightDockerArguments (@('--yes','supabase@2.116.0','--agent','no') + $Arguments))
      $command='"' + $npx + '" ' + ($tokens -join ' ')
      $nativeArguments='/d /s /c "' + $command + '"'
    } else {
      $file=(Get-Command -Name docker.exe -CommandType Application -ErrorAction Stop).Source
      $nativeArguments=@(Convert-FormsPreflightDockerArguments $Arguments) -join ' '
    }
    $constructionAttempted=$true
    $window=New-FormsPreflightProcessWindow $file $nativeArguments $WorkingDirectory
    $result=Complete-FormsPreflightProcessWindow $window $TimeoutSeconds
    [pscustomobject]@{ ExitCode=$result.ExitCode; Output=[string]$result.Output; Failure=$null }
  } catch {
    $reason='process-failed'
    if ($_.Exception.Message -match 'native cleanup unproven' -or ($constructionAttempted -and $null -eq $window)) {
      $script:formsPreflightNativeCleanupUnproven=$true
      $reason='cleanup-unproven'
    } elseif ($_.Exception.Message -match 'native deadline elapsed') { $reason='timeout' }
    [pscustomobject]@{ ExitCode=-1; Output=''; Failure=$reason }
  }
}
function Invoke-FormsPreflightDocker($Context, [string[]]$Arguments) {
  $prefix = if ($Context.DockerContext) { @('--context', $Context.DockerContext) } else { @() }
  Invoke-FormsPreflightNative -Tool docker -Arguments ($prefix + $Arguments) -TimeoutSeconds 30
}
function Assert-FormsPreflightEnvironment($Context) {
  if (@(Get-FormsPreflightEnvironmentNames).Count -gt 0) { throw 'F-AUTHOR refuses inherited environment overrides (values suppressed)' }
  $contextResult = Invoke-FormsPreflightNative -Tool docker -Arguments @('context','show') -TimeoutSeconds 30
  if ($contextResult.ExitCode -ne 0 -or $contextResult.Output.Trim() -cnotmatch '^[a-zA-Z0-9_.-]+$') { throw 'cannot determine the local Docker context' }
  $name = $contextResult.Output.Trim()
  if ($Context.DockerContext -and $Context.DockerContext -cne $name) { throw 'Docker context changed during F-AUTHOR preflight' }
  $endpoint = Invoke-FormsPreflightNative -Tool docker -Arguments @('context','inspect',$name,'--format','{{.Endpoints.docker.Host}}') -TimeoutSeconds 30
  if ($endpoint.ExitCode -ne 0 -or $endpoint.Output.Trim() -notmatch '^npipe:/+\./pipe/[a-zA-Z0-9_.-]+$') {
    throw 'F-AUTHOR requires a local Windows Docker named-pipe endpoint'
  }
  $Context.DockerContext = $name
}
function Get-FormsPreflightResources($Context) {
  $result = @{}
  foreach ($kind in @('Containers','Volumes','Networks')) {
    $prefix = switch ($kind) { 'Containers' { @('ps','-a','--no-trunc') }; 'Volumes' { @('volume','ls') }; 'Networks' { @('network','ls','--no-trunc') } }
    $format = if ($kind -eq 'Volumes') { '{{.Name}}' } else { '{{.ID}}' }
    $found = @()
    foreach ($filter in @("name=$($Context.Identity)", "label=com.supabase.cli.project=$($Context.Identity)")) {
      $r = Invoke-FormsPreflightDocker $Context ($prefix + @('--filter',$filter,'--format',$format))
      if ($r.ExitCode -ne 0) { throw "cannot inspect F-AUTHOR $kind" }
      $found += @($r.Output -split '\r?\n' | Where-Object { $_.Trim() })
    }
    $result[$kind] = @($found | Sort-Object -Unique)
  }
  [pscustomobject]$result
}
function Assert-FormsPreflightNoResources($Resources) {
  if (@($Resources.Containers).Count + @($Resources.Volumes).Count + @($Resources.Networks).Count -ne 0) {
    throw 'F-AUTHOR Docker identity is not empty'
  }
}
function Get-FormsPreflightInstance($Context) {
  $format = '{"Id":{{json .Id}},"Name":{{json .Name}},"Image":{{json .Image}},"ImageRef":{{json .Config.Image}},"Project":{{json (index .Config.Labels "com.supabase.cli.project")}},"Workdir":{{json (index .Config.Labels "com.supabase.cli.workdir")}},"Running":{{json .State.Running}},"StartedAt":{{json .State.StartedAt}},"Bindings":{{json (index .NetworkSettings.Ports "5432/tcp")}},"Mounts":[{{range $i,$m := .Mounts}}{{if $i}},{{end}}{"Type":{{json $m.Type}},"Name":{{json $m.Name}},"Destination":{{json $m.Destination}}}{{end}}],"Networks":[{{ $first := true }}{{range $i,$n := .NetworkSettings.Networks}}{{if not $first}},{{end}}{{ $first = false }}{"Name":{{json $i}},"Id":{{json $n.NetworkID}}}{{end}}]}'
  $r = Invoke-FormsPreflightDocker $Context @('inspect','--format',$format,("supabase_db_" + $Context.Identity))
  if ($r.ExitCode -ne 0) { throw 'cannot inspect the F-AUTHOR database container' }
  try { $m = $r.Output | ConvertFrom-Json -ErrorAction Stop } catch { throw 'invalid allowlisted Docker metadata' }
  if ($m.Id -cnotmatch '^[a-f0-9]{64}$' -or $m.Image -cnotmatch '^sha256:[a-f0-9]{64}$' -or
      $m.Name -cne ("/supabase_db_" + $Context.Identity) -or $m.Project -cne $Context.Identity -or
      [IO.Path]::GetFullPath([string]$m.Workdir) -ine $Context.Root -or $m.Running -ne $true -or
      $m.ImageRef -cnotmatch '^(public\.ecr\.aws/supabase/postgres|(?:docker\.io/)?supabase/postgres):17\.[a-zA-Z0-9_.-]+$') {
    throw 'F-AUTHOR container identity or official PostgreSQL image mismatch'
  }
  if (@($m.Mounts).Count -ne 1 -or $m.Mounts[0].Type -cne 'volume' -or
      $m.Mounts[0].Name -cne ("supabase_db_" + $Context.Identity) -or
      $m.Mounts[0].Destination -cne '/var/lib/postgresql/data') { throw 'F-AUTHOR database volume mismatch' }
  if (@($m.Networks).Count -ne 1 -or $m.Networks[0].Name -cne ("supabase_network_" + $Context.Identity) -or
      $m.Networks[0].Id -cnotmatch '^[a-f0-9]{64}$') { throw 'F-AUTHOR database network mismatch' }
  # Named-pipe transport proves a local daemon, not exclusive or loopback DB bindings.
  $bindings=@($m.Bindings)
  if ($null -eq $m.Bindings -or $bindings.Count -eq 0) { throw 'F-AUTHOR database bindings are missing' }
  foreach ($binding in $bindings) {
    $address=$null
    if (-not [Net.IPAddress]::TryParse([string]$binding.HostIp, [ref]$address) -or
        [string]$binding.HostPort -cnotmatch '^[0-9]{1,5}$' -or [int]$binding.HostPort -ne $Context.DbPort) {
      throw 'F-AUTHOR database binding metadata mismatch'
    }
  }
  $r = Invoke-FormsPreflightDocker $Context @('image','inspect','--format','{"Id":{{json .Id}},"RepoDigests":{{json .RepoDigests}}}',$m.Image)
  if ($r.ExitCode -ne 0) { throw 'cannot inspect the F-AUTHOR image digest' }
  try { $im = $r.Output | ConvertFrom-Json -ErrorAction Stop } catch { throw 'invalid allowlisted image metadata' }
  $digests = @($im.RepoDigests | Sort-Object -Unique)
  if ($im.Id -cne $m.Image -or $digests.Count -eq 0 -or
      @($digests | Where-Object { $_ -cnotmatch '^(public\.ecr\.aws/supabase/postgres|(?:docker\.io/)?supabase/postgres)@sha256:[a-f0-9]{64}$' }).Count -ne 0) {
    throw 'F-AUTHOR image digest is missing or inconsistent'
  }
  $resources = Get-FormsPreflightResources $Context
  if (@($resources.Containers).Count -ne 1 -or @($resources.Volumes).Count -ne 1 -or @($resources.Networks).Count -ne 1) {
    throw 'F-AUTHOR DB-only resource cardinality mismatch'
  }
  [pscustomobject]@{
    Id=[string]$m.Id; Name=[string]$m.Name; Image=[string]$m.Image; ImageRef=[string]$m.ImageRef
    Digests=$digests; Volume=[string]$m.Mounts[0].Name; Network=[string]$m.Networks[0].Id
    StartedAt=[DateTimeOffset]::Parse($m.StartedAt).ToUniversalTime().ToString('o')
    Bindings=@($bindings | ForEach-Object { [pscustomobject]@{ HostIp=[string]$_.HostIp; HostPort=[string]$_.HostPort } })
  }
}
function Get-FormsPreflightSql([ValidateSet('Catalog','Ledger','Jobs','Runs','Requests','Responses','DisableCron')]$Phase) {
  switch ($Phase) {
    'DisableCron' { return "ALTER SYSTEM SET cron.launch_active_jobs = 'off';" }
    'Ledger' { return '/* FA_LEDGER */ select count(*) from supabase_migrations.schema_migrations;' }
    'Jobs' { return '/* FA_JOBS */ select count(*) from cron.job;' }
    'Runs' { return '/* FA_RUNS */ select count(*) from cron.job_run_details;' }
    'Requests' { return '/* FA_REQUESTS */ select count(*) from net.http_request_queue;' }
    'Responses' { return '/* FA_RESPONSES */ select count(*) from net._http_response;' }
    'Catalog' { return @'
/* FA_CATALOG: metadata only; never read Vault values, job commands or HTTP payloads. */
select json_build_object(
  'actor', current_user, 'database', current_database(),
  'server_version_num', current_setting('server_version_num')::integer,
  'postmaster', pg_postmaster_start_time(),
  'preload', current_setting('shared_preload_libraries'),
  'cron_database', current_setting('cron.database_name', true),
  'cron', (select row_to_json(s) from
    (select setting, reset_val, source, pending_restart, context
       from pg_settings where name = 'cron.launch_active_jobs') s),
  'file_errors', (select count(*) from pg_file_settings where error is not null),
  'cron_file_settings', coalesce((select json_agg(json_build_object(
    'sourcefile', sourcefile, 'setting', setting, 'applied', applied) order by seqno)
    from pg_file_settings where name = 'cron.launch_active_jobs'), '[]'::json),
  'auth', json_build_object(
    'users', exists(select 1 from pg_class where oid=to_regclass('auth.users') and relkind='r'),
    'sessions', exists(select 1 from pg_class where oid=to_regclass('auth.sessions') and relkind='r'),
    'jwt', to_regprocedure('auth.jwt()') is not null,
    'aal_type', exists(select 1 from pg_type where oid=to_regtype('auth.aal_level') and typtype='e'),
    'aal_labels', coalesce((select json_agg(enumlabel order by enumsortorder)
      from pg_enum where enumtypid=to_regtype('auth.aal_level')), '[]'::json)),
  'storage', json_build_object(
    'buckets', exists(select 1 from pg_class where oid=to_regclass('storage.buckets') and relkind='r'),
    'columns', coalesce((select json_agg(attname order by attname) from pg_attribute
      where attrelid=to_regclass('storage.buckets') and attnum>0 and not attisdropped), '[]'::json)),
  'app_tables', (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','app_private') and c.relkind in ('r','p')),
  'ledger_exists', to_regclass('supabase_migrations.schema_migrations') is not null,
  'extensions', (select json_agg(json_build_object(
    'name', x.name, 'available', a.default_version, 'installed', e.extversion,
    'schema', to_regnamespace(x.schema_name) is not null,
    'structures', json_build_array(to_regclass(x.table_one) is not null,
      to_regclass(x.table_two) is not null, exists(
        select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
        where n.nspname=x.schema_name and p.proname=x.function_name)))
    order by x.name)
    from (values
      ('pg_cron','cron','cron.job','cron.job_run_details','schedule'),
      ('pg_net','net','net.http_request_queue','net._http_response','http_post'),
      ('supabase_vault','vault','vault.secrets','vault.decrypted_secrets','create_secret')
    ) x(name,schema_name,table_one,table_two,function_name)
    left join pg_available_extensions a on a.name=x.name
    left join pg_extension e on e.extname=x.name)
);
'@ }
  }
}
function Invoke-FormsPreflightSql($Context, [string]$ContainerId,
  [ValidateSet('Catalog','Ledger','Jobs','Runs','Requests','Responses','DisableCron')]$Phase) {
  if ($ContainerId -cnotmatch '^[a-f0-9]{64}$') { throw 'invalid F-AUTHOR SQL container identity' }
  $r = Invoke-FormsPreflightDocker $Context @('exec',$ContainerId,'psql','-X','-q','-w','-A','-t','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres','-c',(Get-FormsPreflightSql $Phase))
  if ($r.ExitCode -ne 0) { throw "F-AUTHOR $Phase SQL failed (native output suppressed)" }
  if ($Phase -eq 'Catalog') {
    try { return ($r.Output | ConvertFrom-Json -ErrorAction Stop) } catch { throw 'invalid F-AUTHOR catalog metadata' }
  }
  if ($Phase -eq 'DisableCron') { return }
  if ($r.Output.Trim() -cnotmatch '^\d+$') { throw "invalid F-AUTHOR $Phase count" }
  [long]$r.Output.Trim()
}
function Get-FormsPreflightExtensionState($Extension) {
  if ($null -eq $Extension -or [string]::IsNullOrWhiteSpace([string]$Extension.available)) { throw "unavailable extension: $($Extension.name)" }
  if ([string]$Extension.available -cnotmatch '^[0-9][a-zA-Z0-9_.-]*$' -or
      ($Extension.installed -and [string]$Extension.installed -cnotmatch '^[0-9][a-zA-Z0-9_.-]*$')) { throw 'invalid extension version metadata' }
  if ($Extension.schema -isnot [bool] -or
      @($Extension.structures | Where-Object { $_ -isnot [bool] }).Count -gt 0) { throw "inconsistent extension: $($Extension.name)" }
  $present = @($Extension.structures | Where-Object { $_ -eq $true }).Count
  if (@($Extension.structures).Count -ne 3) { throw "inconsistent extension: $($Extension.name)" }
  if ([string]::IsNullOrWhiteSpace([string]$Extension.installed)) {
    if ($Extension.schema -ne $false -or $present -ne 0) { throw "inconsistent extension: $($Extension.name)" }
    return 'not_installed'
  }
  if ($Extension.schema -ne $true -or $present -ne 3) { throw "inconsistent extension: $($Extension.name)" }
  'installed'
}
function Get-FormsPreflightSnapshot($Context, $Instance, [switch]$AfterRestart) {
  $c = Invoke-FormsPreflightSql $Context $Instance.Id Catalog
  # Project expected catalog metadata; native output and unexpected fields stay private.
  $evidence = [pscustomobject]@{
    ServerVersion=[int]$c.server_version_num; Postmaster=[string]$c.postmaster
    Preload=[string]$c.preload; CronDatabase=[string]$c.cron_database
    Extensions=@($c.extensions | Where-Object { $_.name -in @('pg_cron','pg_net','supabase_vault') } | ForEach-Object {
      [pscustomobject]@{Name=[string]$_.name;Available=[string]$_.available;Installed=[string]$_.installed;Schema=$_.schema;Structures=@($_.structures)}
    })
    NativeBootstrap=[pscustomobject]@{
      AuthUsers=$c.auth.users;AuthSessions=$c.auth.sessions;AuthJwt=$c.auth.jwt
      AuthAalEnum=$c.auth.aal_type;AuthAal1=(@($c.auth.aal_labels) -contains 'aal1')
      AuthAal2=(@($c.auth.aal_labels) -contains 'aal2');StorageBuckets=$c.storage.buckets
      StorageRequiredColumns=@(@('id','name','public','file_size_limit','allowed_mime_types') | Where-Object { $_ -in $c.storage.columns })
    }
    ApplicationTables=[long]$c.app_tables
    Cron=$null; Net=$null; Vault=$null; Ledger=$null
  }
  $Context.LastEvidence = $evidence
  if ($null -eq $c.app_tables -or [string]$c.app_tables -cnotmatch '^\d+$' -or
      $null -eq $c.file_errors -or [string]$c.file_errors -cnotmatch '^\d+$' -or
      $c.ledger_exists -isnot [bool]) { throw 'incomplete F-AUTHOR catalog metadata' }
  if ($c.actor -cne 'postgres' -or $c.database -cne 'postgres' -or
      [int]$c.server_version_num -lt 170000 -or [int]$c.server_version_num -gt 179999) { throw 'F-AUTHOR requires postgres on PostgreSQL 17' }
  $nativeChecks = [ordered]@{
    'auth.users'=$evidence.NativeBootstrap.AuthUsers
    'auth.sessions'=$evidence.NativeBootstrap.AuthSessions
    'auth.jwt()'=$evidence.NativeBootstrap.AuthJwt
    'auth.aal_level(enum)'=$evidence.NativeBootstrap.AuthAalEnum
    'auth.aal_level:aal1'=$evidence.NativeBootstrap.AuthAal1
    'auth.aal_level:aal2'=$evidence.NativeBootstrap.AuthAal2
    'storage.buckets'=$evidence.NativeBootstrap.StorageBuckets
    'storage.buckets(required columns)'=($evidence.NativeBootstrap.StorageRequiredColumns.Count -eq 5)
  }
  foreach ($required in $nativeChecks.Keys) {
    if ($nativeChecks[$required] -ne $true) { throw "F-AUTHOR native bootstrap missing structure: $required" }
  }
  if ([long]$c.app_tables -ne 0) { throw 'F-AUTHOR application catalog is not empty' }
  if (($c.preload -split ',' | ForEach-Object { $_.Trim().Trim('"') }) -notcontains 'pg_cron' -or
      $null -eq $c.cron -or $c.cron.context -cne 'sighup' -or $c.cron_database -cne 'postgres') {
    throw 'F-AUTHOR requires preloaded pg_cron and its real cluster cron settings'
  }
  $states = @{}
  foreach ($name in @('pg_cron','pg_net','supabase_vault')) {
    $matches = @($c.extensions | Where-Object { $_.name -ceq $name })
    if ($matches.Count -ne 1) { throw 'inconsistent extension catalog cardinality' }
    $states[$name] = Get-FormsPreflightExtensionState $matches[0]
  }
  $ledger = if ($c.ledger_exists -eq $true) { Invoke-FormsPreflightSql $Context $Instance.Id Ledger } else { $null }
  if ($null -ne $ledger -and $ledger -ne 0) { throw 'nonzero application migration ledger' }
  $evidence.Ledger = [pscustomobject]@{State=$(if ($c.ledger_exists) {'present'} else {'absent'});Rows=$ledger}
  $counts = @{}
  foreach ($phase in @('Jobs','Runs','Requests','Responses')) {
    $extension = if ($phase -in @('Jobs','Runs')) { 'pg_cron' } else { 'pg_net' }
    $counts[$phase] = $null
    if ($states[$extension] -eq 'installed') {
      $counts[$phase] = Invoke-FormsPreflightSql $Context $Instance.Id $phase
      if ($counts[$phase] -ne 0) { throw "nonzero F-AUTHOR $phase" }
    }
  }
  $evidence.Cron = [pscustomobject]@{
    State=$states.pg_cron;Jobs=$counts.Jobs;Runs=$counts.Runs
    Setting=[string]$c.cron.setting;ResetVal=[string]$c.cron.reset_val;Source=[string]$c.cron.source
    PendingRestart=$c.cron.pending_restart;FileErrors=[long]$c.file_errors
    AppliedAutoConfOff=@($c.cron_file_settings | Where-Object {
      $_.applied -eq $true -and $_.setting -ceq 'off' -and $_.sourcefile -match '(^|/)postgresql\.auto\.conf$'
    }).Count
  }
  $evidence.Net = [pscustomobject]@{State=$states.pg_net;Requests=$counts.Requests;Responses=$counts.Responses}
  $evidence.Vault = [pscustomobject]@{State=$states.supabase_vault}
  if ($AfterRestart -and ($c.cron.setting -cne 'off' -or $c.cron.reset_val -cne 'off' -or
      $c.cron.source -cne 'configuration file' -or $c.cron.pending_restart -ne $false -or
      [long]$c.file_errors -ne 0 -or $evidence.Cron.AppliedAutoConfOff -ne 1)) {
    throw 'F-AUTHOR cluster cron off is not effective from error-free configuration'
  }
  $evidence
}
function Invoke-FormsAuthoringRuntimePreflight {
  $ErrorActionPreference = 'Stop'
  $script:formsPreflightNativeCleanupUnproven=$false
  $ctx=$null; $mutex=$null; $acquired=$false; $failure=$null
  $before=$null; $after=$null; $instanceBefore=$null; $instanceAfter=$null
  $cleanup = New-Object Collections.Generic.List[string]
  try {
    if (@(Get-FormsPreflightEnvironmentNames).Count -gt 0) { throw 'F-AUTHOR refuses inherited environment overrides (values suppressed)' }
    $ctx = New-FormsPreflightContext
    $mutex = New-FormsPreflightMutex
    try { $acquired=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired=$true }
    if (-not $acquired) { throw 'another safe replay holds the global mutex' }
    Assert-FormsPreflightEnvironment $ctx
    if (Test-Path -LiteralPath $ctx.Root) { throw 'F-AUTHOR project already exists' }
    Assert-FormsPreflightNoResources (Get-FormsPreflightResources $ctx)
    New-FormsPreflightProject $ctx
    Assert-FormsPreflightProject $ctx -BeforeStart
    $version = Invoke-FormsPreflightNative -Tool cli -Arguments @('--version') -WorkingDirectory $ctx.Root -TimeoutSeconds 30
    if ($version.ExitCode -ne 0 -or $version.Output.Trim() -cne '2.116.0') { throw 'F-AUTHOR requires Supabase CLI 2.116.0' }
    Assert-FormsPreflightEnvironment $ctx
    Assert-FormsPreflightProject $ctx -BeforeStart
    $ctx.StartAttempted=$true
    $excludes='gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor'
    $start=Invoke-FormsPreflightNative -Tool cli -Arguments @('start','--workdir',$ctx.Root,'--exclude',$excludes) -WorkingDirectory $ctx.Root -TimeoutSeconds 240
    if ($start.ExitCode -ne 0) { throw 'F-AUTHOR start failed (native output suppressed)' }
    Assert-FormsPreflightProject $ctx
    $instanceBefore=Get-FormsPreflightInstance $ctx
    $before=Get-FormsPreflightSnapshot $ctx $instanceBefore
    Assert-FormsPreflightEnvironment $ctx
    Invoke-FormsPreflightSql $ctx $instanceBefore.Id DisableCron
    $restart=Invoke-FormsPreflightDocker $ctx @('restart','--time','10',$instanceBefore.Id)
    if ($restart.ExitCode -ne 0) { throw 'F-AUTHOR same-container restart failed' }
    $ready=$false
    for ($attempt=0; $attempt -lt 60; $attempt++) {
      $r=Invoke-FormsPreflightDocker $ctx @('exec',$instanceBefore.Id,'pg_isready','-U','postgres','-d','postgres','-t','1')
      if ($r.ExitCode -eq 0) { $ready=$true; break }
      if ($r.ExitCode -lt 0) { throw 'F-AUTHOR native readiness command failed' }
      Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'F-AUTHOR readiness did not recover after restart' }
    $instanceAfter=Get-FormsPreflightInstance $ctx
    foreach ($key in @('Id','Name','Image','ImageRef','Volume','Network')) {
      if ($instanceAfter.$key -cne $instanceBefore.$key) { throw "F-AUTHOR same-instance $key changed" }
    }
    if (($instanceAfter.Digests -join '|') -cne ($instanceBefore.Digests -join '|') -or
        [DateTimeOffset]::Parse($instanceAfter.StartedAt) -le [DateTimeOffset]::Parse($instanceBefore.StartedAt)) { throw 'F-AUTHOR image digest or restart identity mismatch' }
    $after=Get-FormsPreflightSnapshot $ctx $instanceAfter -AfterRestart
    if ([DateTimeOffset]::Parse($after.Postmaster) -le [DateTimeOffset]::Parse($before.Postmaster)) { throw 'F-AUTHOR postmaster did not change after restart' }
    Assert-FormsPreflightProject $ctx
  } catch { $failure=$_.Exception.Message }
  finally {
    if ($ctx -and $ctx.Created) {
      $safe=$false; $stopped=(-not $ctx.StartAttempted); $empty=$false
      try { Assert-FormsPreflightProject $ctx; $safe=$true } catch { $cleanup.Add('owned TEMP guard failed; directory preserved') }
      if ($safe -and $ctx.StartAttempted) {
        try {
          Assert-FormsPreflightEnvironment $ctx
          $stop=Invoke-FormsPreflightNative -Tool cli -Arguments @('stop','--workdir',$ctx.Root,'--no-backup','--yes') -WorkingDirectory $ctx.Root -TimeoutSeconds 60
          if ($stop.ExitCode -ne 0) { throw 'stop failed' }
          $stopped=$true
        } catch { $cleanup.Add('nominal stop failed; directory preserved') }
      }
      if ($ctx.StartAttempted) {
        try { Assert-FormsPreflightNoResources (Get-FormsPreflightResources $ctx); $empty=$true }
        catch { $cleanup.Add('Docker residual inspection did not prove zero') }
      } else { $empty=$true }
      if ($safe -and $stopped -and $empty -and -not $script:formsPreflightNativeCleanupUnproven) {
        try {
          Assert-FormsPreflightProject $ctx
          # Resolved absolute immediate TEMP child and every descendant were checked above.
          Remove-Item -LiteralPath $ctx.Root -Recurse -Force -ErrorAction Stop
          if (Test-Path -LiteralPath $ctx.Root) { throw 'TEMP residual' }
        } catch { $cleanup.Add('owned TEMP removal did not prove zero') }
      }
    }
    if ($script:formsPreflightNativeCleanupUnproven) { $cleanup.Add('native owned process cleanup unproven; directory preserved') }
    if ($acquired) { try { $mutex.ReleaseMutex() } catch { $cleanup.Add('mutex release failed') } }
    if ($mutex) { try { $mutex.Dispose() } catch { $cleanup.Add('mutex dispose failed') } }
  }
  if ($failure -or $cleanup.Count -gt 0) {
    if ($ctx) {
      Write-Output ([pscustomobject]@{
        Status='FAIL';Scope='empty-runtime-only';Identity=$ctx.Identity;TemporaryProject=$ctx.Root
        StartAttempted=$ctx.StartAttempted;InstanceBefore=$instanceBefore;InstanceAfter=$instanceAfter
        Before=$before;After=$after;Observed=$ctx.LastEvidence
        Cleanup=$(if ($cleanup.Count) {'unproven'} elseif (-not $ctx.Created) {'not_owned'} else {'zero'})
      })
    }
    $reason=@($failure; @($cleanup)) | Where-Object { $_ }
    throw ('F-AUTHOR preflight failed: ' + ($reason -join '; '))
  }
  [pscustomobject]@{
    Status='PASS';Scope='empty-runtime-only';Identity=$ctx.Identity;CliVersion='2.116.0'
    InstanceBefore=$instanceBefore;InstanceAfter=$instanceAfter;Before=$before;After=$after
    ApplicationMigrations=0;Cleanup='zero'
  }
}
if ($MyInvocation.InvocationName -ne '.') { Invoke-FormsAuthoringRuntimePreflight }
