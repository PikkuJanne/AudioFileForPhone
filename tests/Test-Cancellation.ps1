<#
T11 cancellation/crash evidence. All media, controller binaries, logs and app
copies live in one CreateDirectoryW/CreateNew-owned TEMP tree. The app entry is
byte-identical; an append-only helper copy slows one real encoder for the test.
Automated keyboard records are controlled input, never a physical manual test.
Run -Manual from a genuine local ConsoleHost and press Ctrl+C only after READY.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe',
    [switch]$Manual
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'T11C-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t11-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$descendantReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Cancellation.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T11|T13|T14|T15|T16)-cancellation-(ps51|ps7)-(attempt|final|manual)[0-9]+\.json$') {
    throw 'EvidencePath must name fresh T11/T13/T14/T15/T16-cancellation-ps51/ps7-attempt/final/manualN.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = $(if ($Manual) { 'physical_manual_console_ctrl_c' } else { 'controlled_native_console_input_and_forced_host' })
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_entry_bytes_unchanged = $false
    owned_temp_root_name = $testName; temp_parent_selection = 'shorter user/machine TEMP, read-only lookup'
    owned_temp_root = $testRoot; owner_marker_sha256 = $null
    cases = @(); children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
    manual_requested = [bool]$Manual; physical_manual_ctrl_c = $false
}
$exitCode = 1
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point in a fixture path or ancestor.'
        $item = $item.Parent
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside exact cleanup scope.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() } })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-RealSuccess {
    param([string]$Tool, [string[]]$NativeArguments)
    $native = Invoke-AudioNativeProcess -ExecutablePath $Tool -Arguments $NativeArguments -Cancellation $null
    Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 0 -and $native.ProcessReleased) ('Real fixture/check failed: status=' + $native.Status + ', exit=' + $native.ExitCode + ' ' + $native.Error + ' ' + $native.Stderr + ' ' + $native.Stdout)
    return $native
}
function Start-OwnedChild {
    param([string]$Executable, [string[]]$Arguments)
    $info = New-Object Diagnostics.ProcessStartInfo; $info.FileName = $Executable
    $info.Arguments = [T11Controller.Utility]::CommandLine($Arguments)
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    Assert-True ($process.Start()) 'Exact owned child must start.'
    $child = [pscustomobject]@{ process = $process; stdout_task = $process.StandardOutput.ReadToEndAsync(); stderr_task = $process.StandardError.ReadToEndAsync(); disposed = $false; timed_out = $false }
    $children.Add($child); return $child
}
function Complete-OwnedChild {
    param([object]$Child, [int]$TimeoutMilliseconds = 90000)
    if (-not $Child.process.WaitForExit($TimeoutMilliseconds)) { $Child.timed_out = $true; throw 'Owned controller/host timed out; preserve exact test tree because descendant release is unproved.' }
    if (-not $Child.stdout_task.Wait(5000) -or -not $Child.stderr_task.Wait(5000)) { $Child.timed_out = $true; throw 'Owned child pipes did not close in bounded teardown; preserve exact tree.' }
    $result = [pscustomobject]@{ exit_code = $Child.process.ExitCode; stdout = $Child.stdout_task.GetAwaiter().GetResult(); stderr = $Child.stderr_task.GetAwaiter().GetResult() }
    $Child.process.Dispose(); $Child.disposed = $true; return $result
}
function New-AppCopy {
    param([string]$Label, [string]$ReadyPath, [string]$PidPath, [string]$BeforePath, [string]$MonitorLibrary)
    $root = Join-Path $testRoot ('A-' + $Label); [IO.Directory]::CreateDirectory($root) | Out-Null
    $entry = Join-Path $root 'AudioFileForPhone.ps1'; $helper = Join-Path $root 'AudioFileForPhone.Helpers.ps1'
    [IO.File]::Copy((Join-Path $projectRoot 'AudioFileForPhone.ps1'), $entry, $false)
    [IO.File]::Copy((Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'), $helper, $false)
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) {
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'App copies must start byte-identical.'
    }
    $append = @'
Add-Type -TypeDefinition ([IO.File]::ReadAllText(__LIBRARY__))
$script:T11OriginalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath, [string[]]$Arguments, [int]$MaxStdoutChars=1048576, [int]$MaxStderrChars=65536,
          [object]$Cancellation = (Get-AudioCancellationContext), [scriptblock]$ProgressCallback, [object]$ProgressDurationSeconds,
          [object]$ProgressParser, [object]$ProgressCallbackState,
          [int]$TimeoutMilliseconds=0, [string]$Operation='Native operation', [int]$PipeDrainTimeoutMilliseconds=5000)
    $watcher = $null
    if ([IO.Path]::GetFileName($ExecutablePath) -ieq 'ffmpeg.exe' -and
        @($Arguments | Where-Object { $_ -match '2024-01-02 Second\.m4a$' }).Count -eq 1 -and
        [IO.Path]::GetExtension($Arguments[$Arguments.Length-1]) -ceq '.partial') {
        $completed = @([IO.Directory]::GetFiles([IO.Path]::GetDirectoryName($Arguments[$Arguments.Length-1])) |
            Where-Object { [IO.Path]::GetExtension($_) -ieq '.mp3' } |
            ForEach-Object { [pscustomobject]@{ path=$_; sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() } })
        [IO.File]::WriteAllText(__BEFORE__, ($completed | ConvertTo-Json -Depth 4))
        # Test-only real-time input pacing and packet flushing produce a safely
        # observable real encoder; production encoding arguments are unchanged.
        $Arguments = @('-re') + $Arguments[0..($Arguments.Length-2)] + @('-flush_packets', '1', $Arguments[$Arguments.Length-1])
        $watcher = New-Object T11Controller.Readiness($Cancellation, $Arguments[$Arguments.Length-1], __READY__, __PID__)
    }
    try {
        $nativeResult = & $script:T11OriginalNative -ExecutablePath $ExecutablePath -Arguments $Arguments -MaxStdoutChars $MaxStdoutChars -MaxStderrChars $MaxStderrChars -Cancellation $Cancellation -ProgressCallback $ProgressCallback -ProgressDurationSeconds $ProgressDurationSeconds -ProgressParser $ProgressParser -ProgressCallbackState $ProgressCallbackState -TimeoutMilliseconds $TimeoutMilliseconds -Operation $Operation -PipeDrainTimeoutMilliseconds $PipeDrainTimeoutMilliseconds
        if ($null -ne $watcher) { [IO.File]::WriteAllText(__READY__+'.released', ([ordered]@{status=$nativeResult.Status;process_released=$nativeResult.ProcessReleased} | ConvertTo-Json)) }
        return $nativeResult
    }
    finally { if ($null -ne $watcher) { $watcher.Dispose() } }
}
'@
    $append = $append.Replace('__LIBRARY__', (Get-Literal $MonitorLibrary)).Replace('__BEFORE__', (Get-Literal $BeforePath)).Replace('__READY__', (Get-Literal $ReadyPath)).Replace('__PID__', (Get-Literal $PidPath))
    [IO.File]::AppendAllText($helper, "`r`n" + $append, [Text.Encoding]::UTF8)
    Add-Fixture $entry; Add-Fixture $helper; return $entry
}
function New-EntryDriver {
    param([string]$Label, [string]$Entry, [string]$InputPath, [string]$OutputParent, [string]$RawPath, [string]$ExitPath, [string]$ModePath)
    $text = @('$ErrorActionPreference=''Stop''', '$ProgressPreference=''SilentlyContinue''',
        ('$env:PATH=' + (Get-Literal (Split-Path -Parent $ffmpeg)) + '+'';''+$env:PATH'),
        '$previousMode=[Console]::TreatControlCAsInput', '$global:LASTEXITCODE=$null',
        ('& ' + (Get-Literal $Entry) + ' -InputFolder ' + (Get-Literal $InputPath) + ' -OutputParent ' + (Get-Literal $OutputParent) + ' -ConfigPath ' + (Get-Literal (Join-Path $testRoot 'missing-config.json')) + ' -BitrateKbps 64 *>&1 | ForEach-Object {'),
        ('  [IO.File]::AppendAllText(' + (Get-Literal $RawPath) + ', [string]$_+[Environment]::NewLine)'), '}',
        ('[IO.File]::WriteAllText(' + (Get-Literal $ExitPath) + ', [string]$global:LASTEXITCODE)'),
        ('[IO.File]::WriteAllText(' + (Get-Literal $ModePath) + ', ([ordered]@{ before=$previousMode; after=[Console]::TreatControlCAsInput } | ConvertTo-Json))'),
        'exit $global:LASTEXITCODE') -join "`n"
    $driver = Join-Path $testRoot ($Label + '-driver.ps1'); Write-NewText $driver $text; Add-Fixture $driver; return $driver
}
function Assert-CancelledRun {
    param([string]$OutputParent, [string]$RawPath, [string]$ExitPath, [string]$ModePath, [string]$BeforePath, [object]$Case)
    $text = [IO.File]::ReadAllText($RawPath)
    Assert-True ([IO.File]::ReadAllText($ExitPath) -ceq '130') 'Controlled entry must return explicit exit130.'
    $summary = @($text -split '\r?\n' | Where-Object { $_ -match '^\[RESULT\] ' })[-1]
    Assert-True ($summary -match 'status=Cancelled; total=3; processed=1; converted=1; failed=0; not_processed=2;') ('Cancellation must preserve first success and leave cancelled/unstarted inputs unprocessed: ' + $summary)
    $mode = [IO.File]::ReadAllText($ModePath) | ConvertFrom-Json
    Assert-True ($mode.before -eq $mode.after) 'Console input mode must be restored after controlled cancellation.'
    $runs = @(Get-ChildItem -LiteralPath $OutputParent -Force | Where-Object { $_.PSIsContainer }); Assert-True ($runs.Count -eq 1) 'Cancelled batch must retain one exact run.'
    $tree = @(Get-SafeTree $runs[0].FullName)
    $outputs = @($tree | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
    Assert-True ($outputs.Count -eq 1 -and @($tree | Where-Object { $_.Extension -ieq '.partial' }).Count -eq 0) 'Completed output must remain and current partial must be removed.'
    $before = @([IO.File]::ReadAllText($BeforePath) | ConvertFrom-Json)
    Assert-True ($before.Count -eq 1 -and $before[0].path -ceq $outputs[0].FullName -and $before[0].sha256 -ceq (Get-FileHash -LiteralPath $outputs[0].FullName).Hash.ToLowerInvariant()) 'Completed output must remain byte-identical across cancellation.'
    $log = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_log.txt'))
    Assert-True ($log.Contains('[CANCELLED]') -and $log.Contains('status=Cancelled')) 'Persistent run log must record controlled cancellation.'
    $probe = (Invoke-RealSuccess $ffprobe @('-v', 'error', '-show_entries', 'stream=codec_name,bit_rate', '-of', 'json', $outputs[0].FullName)).Stdout | ConvertFrom-Json
    Assert-True ($probe.streams[0].codec_name -ceq 'mp3' -and [int]$probe.streams[0].bit_rate -eq 64000) 'Preserved publication must be the 64 kbps MP3.'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-xerror', '-i', $outputs[0].FullName, '-f', 'null', 'NUL') | Out-Null
    Assert-True (-not $unrelated.process.HasExited) 'Unrelated live real FFmpeg must survive cancellation.'
    $Case['exit_code'] = 130; $Case['summary'] = $summary; $Case['completed_output_sha256'] = $before[0].sha256
    $Case['completed_output_unchanged_and_decoded'] = $true; $Case['current_partial_removed'] = $true
    $Case['cancelled_log_record'] = $true; $Case['console_mode_restored'] = $true; $Case['unrelated_real_ffmpeg_survived'] = $true
}

# Framework-compatible fixture-only helpers. Controller isolates synthetic key
# input to one newly created console. Termination uses retained known handles.
$supportSource = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
namespace T11Controller {
 public static class Utility {
  public static string Quote(string value) { StringBuilder b=new StringBuilder("\""); int n=0; foreach(char c in value) { if(c=='\\') {n++;continue;} if(c=='"') b.Append('\\',n*2+1); else b.Append('\\',n); b.Append(c);n=0; } b.Append('\\',n*2);return b.Append('"').ToString(); }
  public static string CommandLine(string[] values) { StringBuilder b=new StringBuilder();foreach(string v in values) {if(b.Length>0)b.Append(' ');b.Append(Quote(v));}return b.ToString(); }
 }
 public sealed class RequestTimer : IDisposable {
  private Timer timer;
  public RequestTimer(object context, int milliseconds) { timer=new Timer(delegate {context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite); }
  public void Dispose() {timer.Dispose();}
 }
 public sealed class Readiness : IDisposable {
  private Timer timer; private int done;
  public Readiness(object context,string partial,string ready,string pidPath) {
   timer=new Timer(delegate {
    if(Interlocked.CompareExchange(ref done,0,0)!=0)return;
    try {
     int pid=(int)context.GetType().GetProperty("ActiveProcessId").GetValue(context,null);
     if(pid==0 || !File.Exists(partial) || new FileInfo(partial).Length==0)return;
     if(Interlocked.Exchange(ref done,1)!=0)return;
     File.WriteAllText(pidPath,pid.ToString());File.WriteAllText(ready,partial);
     Console.WriteLine("T11 READY: first output completed; second real encoder active. Press Ctrl+C once now.");
    } catch(Exception error) {if(Interlocked.Exchange(ref done,1)==0) File.WriteAllText(ready+".error",error.Message);}
   },null,50,50);
  }
  public void Dispose() { timer.Dispose(); }
 }
 public class Controller {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct STARTUPINFO {public int cb;public string reserved,desktop,title;public uint x,y,xSize,ySize,xChars,yChars,fill,flags;public short show,reserved2;public IntPtr reservedPointer,input,output,error;}
  [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION {public IntPtr process,thread;public uint pid,tid;}
  [StructLayout(LayoutKind.Sequential)] struct PROCESS_BASIC_INFORMATION {public IntPtr reserved,peb,reserved2,reserved3,pid,parent;}
  [StructLayout(LayoutKind.Sequential)] struct FILETIME {public uint low,high;public long Ticks {get {return ((long)high<<32)|low;}}}
  [StructLayout(LayoutKind.Explicit,Size=20)] struct INPUT_RECORD { [FieldOffset(0)]public short type;[FieldOffset(4)]public int down;[FieldOffset(8)]public short repeat;[FieldOffset(10)]public short key;[FieldOffset(12)]public short scan;[FieldOffset(14)]public char character;[FieldOffset(16)]public int state;}
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool CreateProcess(string app,StringBuilder args,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string directory,ref STARTUPINFO startup,out PROCESS_INFORMATION process);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool AttachConsole(uint pid);
  [DllImport("kernel32.dll")]static extern bool FreeConsole();
  [DllImport("kernel32.dll")]static extern IntPtr GetStdHandle(int kind);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr CreateFileW(string path,uint access,uint sharing,IntPtr attributes,uint creation,uint flags,IntPtr template);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool WriteConsoleInputW(IntPtr input,INPUT_RECORD[] records,uint count,out uint written);
  [DllImport("kernel32.dll")]static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
  [DllImport("kernel32.dll")]static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
  [DllImport("kernel32.dll")]static extern bool TerminateProcess(IntPtr handle,uint code);
  [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
  [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,uint pid);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool QueryFullProcessImageName(IntPtr process,uint flags,StringBuilder name,ref int size);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetProcessTimes(IntPtr process,out FILETIME created,out FILETIME exited,out FILETIME kernel,out FILETIME user);
  [DllImport("ntdll.dll")]static extern int NtQueryInformationProcess(IntPtr process,int kind,out PROCESS_BASIC_INFORMATION information,int bytes,out int returned);
  static void Require(bool ok,string message) {if(!ok)throw new IOException(message+" Win32="+Marshal.GetLastWin32Error());}
  static bool Exited(IntPtr handle) {return WaitForSingleObject(handle,0)==0;}
  static void StopExact(IntPtr handle) {if(handle==IntPtr.Zero)return;if(!Exited(handle))Require(TerminateProcess(handle,123),"Exact owned termination failed.");Require(WaitForSingleObject(handle,5000)==0,"Exact owned process exit unproved.");}
  public static int Main(string[] a) {
   PROCESS_INFORMATION pi=new PROCESS_INFORMATION();IntPtr native=IntPtr.Zero;bool attached=false,ready=false,injected=false,forced=false,survived=false,released=false;uint exit=999;string error="";int nativePid=0;
   try {
    STARTUPINFO si=new STARTUPINFO();si.cb=Marshal.SizeOf(si);si.flags=1;si.show=0;
    string[] argv={a[0],"-NoLogo","-NoProfile","-ExecutionPolicy","RemoteSigned","-File",a[1]};
    Require(CreateProcess(a[0],new StringBuilder(Utility.CommandLine(argv)),IntPtr.Zero,IntPtr.Zero,false,0x10,IntPtr.Zero,Path.GetDirectoryName(a[1]),ref si,out pi),"Fresh hidden console host launch failed.");
    CloseHandle(pi.thread);pi.thread=IntPtr.Zero;
    Stopwatch watch=Stopwatch.StartNew();while(!File.Exists(a[2]) && !Exited(pi.process) && watch.ElapsedMilliseconds<30000)Thread.Sleep(50);
    Require(File.Exists(a[2]),"Second encoder did not become ready.");ready=true;
    nativePid=int.Parse(File.ReadAllText(a[3]));IntPtr candidate=OpenProcess(0x00100000|0x0001|0x0400|0x1000,false,(uint)nativePid);Require(candidate!=IntPtr.Zero,"Cannot retain current encoder candidate handle.");
    try {
     // PID/image alone cannot prove ownership after PID reuse. All identity
     // checks use the retained candidate handle while the owned host is live.
     Require(!Exited(pi.process),"Owned host exited before encoder ownership proof.");
     PROCESS_BASIC_INFORMATION basic;int returned;Require(NtQueryInformationProcess(candidate,0,out basic,Marshal.SizeOf(typeof(PROCESS_BASIC_INFORMATION)),out returned)==0,"Cannot read candidate handle parent identity.");
     Require(basic.pid.ToInt64()==nativePid && basic.parent.ToInt64()==pi.pid,"Encoder candidate is not this newly owned host's child.");
     FILETIME hostCreated,hostExit,hostKernel,hostUser,childCreated,childExit,childKernel,childUser;
     Require(GetProcessTimes(pi.process,out hostCreated,out hostExit,out hostKernel,out hostUser),"Cannot read owned host creation identity.");
     Require(GetProcessTimes(candidate,out childCreated,out childExit,out childKernel,out childUser),"Cannot read encoder candidate creation identity.");
     Require(childCreated.Ticks>=hostCreated.Ticks,"Encoder predates this owned host; possible PID reuse.");
     StringBuilder image=new StringBuilder(32768);int count=image.Capacity;Require(QueryFullProcessImageName(candidate,0,image,ref count),"Cannot verify encoder image.");Require(String.Equals(image.ToString(),a[6],StringComparison.OrdinalIgnoreCase),"Recorded encoder image differs from exact ffmpeg.");Require(!Exited(candidate) && !Exited(pi.process),"Ready encoder/owned host already exited.");
     native=candidate;candidate=IntPtr.Zero;
    } finally {if(candidate!=IntPtr.Zero)CloseHandle(candidate);}
    if(a[4]=="key") {
     // Detach only this disposable controller if its launch inherited a console.
     FreeConsole();Require(AttachConsole(pi.pid),"Cannot attach to newly owned host console.");attached=true;
     INPUT_RECORD key=new INPUT_RECORD();key.type=1;key.down=1;key.repeat=1;key.key=0x43;key.character='\u0003';key.state=8;INPUT_RECORD up=key;up.down=0;
     IntPtr input=CreateFileW("CONIN$",0x80000000|0x40000000,3,IntPtr.Zero,3,0,IntPtr.Zero);Require(input!=new IntPtr(-1),"Cannot open newly owned console input.");
     try {uint written;Require(WriteConsoleInputW(input,new INPUT_RECORD[]{key,up},2,out written)&&written==2,"Controlled Ctrl+C key records failed.");injected=true;}finally{CloseHandle(input);}
     FreeConsole();attached=false;
     Require(WaitForSingleObject(pi.process,20000)==0,"Controlled console shutdown exceeded bound.");
     Require(WaitForSingleObject(native,5000)==0,"Cancelled encoder exit unproved.");
    } else {
     StopExact(pi.process);forced=true;Thread.Sleep(150);survived=!Exited(native);StopExact(native);
    }
    Require(GetExitCodeProcess(pi.process,out exit),"Cannot read exact host exit.");released=true;
   } catch(Exception e) {error=e.Message;}
   finally {
    if(attached)FreeConsole();
    try {StopExact(pi.process);StopExact(native);released=pi.process!=IntPtr.Zero && native!=IntPtr.Zero && Exited(pi.process) && Exited(native);} catch(Exception cleanup){error+=" Cleanup: "+cleanup.Message;released=false;}
    if(pi.thread!=IntPtr.Zero)CloseHandle(pi.thread);if(pi.process!=IntPtr.Zero)CloseHandle(pi.process);if(native!=IntPtr.Zero)CloseHandle(native);
    string escaped=error.Replace("\\","\\\\").Replace("\"","\\\"").Replace("\r"," ").Replace("\n"," ");
    File.WriteAllText(a[5],"{\"host_pid\":"+pi.pid+",\"native_pid\":"+nativePid+",\"ready\":"+ready.ToString().ToLowerInvariant()+",\"synthetic_ctrl_c_key_records\":"+injected.ToString().ToLowerInvariant()+",\"forced_host_termination\":"+forced.ToString().ToLowerInvariant()+",\"native_alive_after_host_kill\":"+survived.ToString().ToLowerInvariant()+",\"held_owned_handles_released\":"+released.ToString().ToLowerInvariant()+",\"host_exit_code\":"+exit+",\"error\":\""+escaped+"\"}");
   }
   return error.Length==0?0:1;
  }
 }
}
'@

try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop; Assert-NoReparse $tempParent; Assert-NoReparse $evidenceParent
    $ownedRootCreated = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved = $true; Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $report.owner_marker_sha256 = (Get-FileHash -LiteralPath $ownerFile).Hash.ToLowerInvariant()
    $report.source_before = Get-SourceInventory
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools'] = @($ffmpeg, $ffprobe | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant(); version = (Invoke-RealSuccess $_ @('-version')).Stdout.Split([char]10)[0].Trim() } })
    $support = Join-Path $testRoot 'Support.cs'; Write-NewText $support $supportSource; Add-Fixture $support
    $library = $support; $controller = Join-Path $testRoot 'Controller.exe'
    $compiler = Join-Path ([Environment]::GetFolderPath('Windows')) 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    # Framework csc's default response file uses bare assembly names. A Core
    # host's current directory can supply incompatible forwarding facades.
    # Bind this fixture executable to the installed compiler's exact libraries.
    $compilerDirectory = Split-Path -Parent $compiler
    $compilerReferences = @('mscorlib.dll', 'System.dll', 'System.Core.dll') |
        ForEach-Object { '/reference:' + (Join-Path $compilerDirectory $_) }
    Invoke-RealSuccess $compiler (@('/nologo', '/noconfig', '/nostdlib+', '/target:exe', '/main:T11Controller.Controller', ('/out:' + $controller)) + $compilerReferences + @($support)) | Out-Null
    Add-Fixture $controller; Add-Type -TypeDefinition $supportSource
    $unrelated = Start-OwnedChild $ffmpeg @('-nostdin', '-v', 'error', '-re', '-f', 'lavfi', '-i', 'sine=frequency=222:sample_rate=44100', '-t', '180', '-f', 'null', 'NUL')
    Assert-True (-not $unrelated.process.WaitForExit(200)) 'Unrelated real FFmpeg fixture must be live.'
    $inputRoot = Join-Path $testRoot 'I'; [IO.Directory]::CreateDirectory($inputRoot) | Out-Null
    foreach ($row in @(@{ name='2024-01-01 First.mp3'; codec='libmp3lame'; duration='0.25' },
        @{ name='2024-01-02 Second.m4a'; codec='aac'; duration='45' }, @{ name='2024-01-03 Third.ogg'; codec='libvorbis'; duration='0.25' })) {
        $path = Join-Path $inputRoot $row.name
        Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=733:sample_rate=44100', '-t', $row.duration, '-c:a', $row.codec, $path) | Out-Null
        Add-Fixture $path
    }
    $orphan = Join-Path $inputRoot ('.AudioFileForPhone-' + [guid]::NewGuid().ToString('N') + '.partial')
    Write-NewText $orphan 'synthetic orphan in ordinary input, never owned by conversion'; Add-Fixture $orphan
    if (-not $Manual) {
        Invoke-Case 'pre-requested context starts no native child' 'A29' {
            param($case); $context = New-AudioCancellationContext
            try { $context.Request(); $result = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-version') -Cancellation $context
                Assert-True ($result.Status -ceq 'Cancelled' -and $result.ProcessReleased -and $context.ActiveProcessId -eq 0) 'Pre-requested context must return Cancelled without an active child.'
                $case['native_status']='Cancelled'; $case['no_child_launched']=$true
            } finally { $context.Dispose() }
        }
        Invoke-Case 'programmatic native cancellation releases only owned real FFmpeg' 'A29' {
            param($case); $context=New-AudioCancellationContext; $timer=New-Object T11Controller.RequestTimer($context,500)
            try { $result=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-re','-f','lavfi','-i','sine=frequency=555:sample_rate=44100','-t','45','-f','null','NUL') -Cancellation $context
                Assert-True ($result.Status -ceq 'Cancelled' -and $result.ProcessReleased -and $context.ActiveProcessId -eq 0 -and $result.DurationMilliseconds -lt 10000) 'Cancellation must bound teardown, prove child exit and clear active PID.'
                Assert-True (-not $unrelated.process.HasExited) 'Unrelated real FFmpeg must survive native cancellation.'
                $case['native_status']='Cancelled';$case['process_released']=$true;$case['duration_milliseconds']=$result.DurationMilliseconds;$case['unrelated_real_ffmpeg_survived']=$true
            } finally { $timer.Dispose();$context.Dispose() }
        }
        Invoke-Case 'pre-requested source inspection reports cancellation before probe/staging' 'A29' {
            param($case);$context=New-AudioCancellationContext
            try {$context.Request();$info=Get-AudioMediaInfo -Path (Join-Path $inputRoot '2024-01-01 First.mp3') -FfprobePath $ffprobe -Cancellation $context
                Assert-True ($info.Status -ceq 'Cancelled' -and $null -eq $info.NativeResult -and $context.ActiveProcessId -eq 0) 'Cancelled source inspection must launch no probe and must not become an ordinary media failure.'
                $case['source_probe_cancelled_before_launch']=$true
            }finally{$context.Dispose()}
        }
        $script:T11TestOriginalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
        $script:T11TestOriginalPublish=(Get-Item -LiteralPath Function:Publish-AudioWorkingOutput).ScriptBlock
        $phaseNative={
            param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,[object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,[object]$ProgressParser,[object]$ProgressCallbackState,
                  [int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
            $working=@($Arguments|Where-Object{[IO.Path]::GetExtension($_) -ceq '.partial'})
            if($script:T11Phase -ceq 'unproved-release' -and $working.Count -gt 0 -and $Arguments -contains '-y') {
                $Cancellation.Request()
                return [pscustomobject]@{Status='Cancelled';ExitCode=$null;ProcessReleased=$false;Error='controlled unproved-release cancellation result; no child launched by this fault';Stdout='';Stderr='';StdoutTruncated=$false;StderrTruncated=$false}
            }
            $result=& $script:T11TestOriginalNative -ExecutablePath $ExecutablePath -Arguments $Arguments -MaxStdoutChars $MaxStdoutChars -MaxStderrChars $MaxStderrChars -Cancellation $Cancellation -ProgressCallback $ProgressCallback -ProgressDurationSeconds $ProgressDurationSeconds -ProgressParser $ProgressParser -ProgressCallbackState $ProgressCallbackState -TimeoutMilliseconds $TimeoutMilliseconds -Operation $Operation -PipeDrainTimeoutMilliseconds $PipeDrainTimeoutMilliseconds
            if($working.Count -gt 0 -and (($script:T11Phase -ceq 'validation-probe' -and $Arguments -contains '-show_entries') -or ($script:T11Phase -ceq 'full-decode' -and $Arguments -contains '-progress' -and $Arguments -contains 'null'))) {
                Assert-True ($result.Status -ceq 'Completed' -and $result.ProcessReleased) 'Phase cancellation requests follow a real successful native release.'
                $Cancellation.Request();$script:T11PhaseReached=$true
            }
            return $result
        }
        $phasePublish={
            param([string]$WorkingPath,[string]$OutputPath,[object]$Cancellation=(Get-AudioCancellationContext))
            if($script:T11Phase -ceq 'publication'){$Cancellation.Request();$script:T11PhaseReached=$true}
            & $script:T11TestOriginalPublish -WorkingPath $WorkingPath -OutputPath $OutputPath -Cancellation $Cancellation
        }
        foreach($phase in @('validation-probe','full-decode','publication','unproved-release')) {
            Invoke-Case ('transaction cancellation at '+$phase+' preserves publication/cleanup boundary') 'A29' {
                param($case);$script:T11Phase=$phase;$script:T11PhaseReached=$false;$context=New-AudioCancellationContext
                $phaseRoot=Join-Path $testRoot ('O-phase-'+$phase);[IO.Directory]::CreateDirectory($phaseRoot)|Out-Null
                $source=Join-Path $inputRoot '2024-01-01 First.mp3';$final=Join-Path $phaseRoot 'final.mp3'
                $sourceInfo=Get-AudioMediaInfo -Path $source -FfprobePath $ffprobe -Cancellation $null
                Set-Item -LiteralPath Function:Invoke-AudioNativeProcess -Value $phaseNative
                Set-Item -LiteralPath Function:Publish-AudioWorkingOutput -Value $phasePublish
                try {
                    $transaction=Invoke-AudioOutputTransaction -OutputPath $final -OutputRoot $phaseRoot -SourcePath $source -SourceDurationSeconds $sourceInfo.DurationSeconds -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments @('-nostdin','-v','error','-i',$source,'-map','0:a:0','-c:a','libmp3lame','-b:a','64k') -Cancellation $context
                    Assert-True ($transaction.Status -ceq 'Cancelled' -and -not(Test-Path -LiteralPath $final)) 'Each phase must return Cancelled and never publish a final-looking output.'
                    if($phase -ceq 'unproved-release') {
                        Assert-True ((Test-Path -LiteralPath $transaction.WorkingPath) -and $transaction.CleanupError.Contains('exit was not established')) 'Simulated unproved native release must retain the exact current partial and explicit cleanup reason.'
                        $case['injected_unknown_release_no_actual_child']=$true;$case['exact_partial_retained']=$true;$case['cleanup_reason']=$transaction.CleanupError
                    }else{
                        Assert-True ($script:T11PhaseReached -and -not(Test-Path -LiteralPath $transaction.WorkingPath) -and [string]::IsNullOrEmpty($transaction.CleanupError) -and $context.ActiveProcessId -eq 0) 'Proved released phase must remove exact current partial after closing the guard.'
                        $case['real_phase_reached']=$true;$case['current_partial_removed']=$true
                    }
                    $case['transaction_status']='Cancelled';$case['no_final_publication']=$true
                }finally{
                    Set-Item -LiteralPath Function:Invoke-AudioNativeProcess -Value $script:T11TestOriginalNative
                    Set-Item -LiteralPath Function:Publish-AudioWorkingOutput -Value $script:T11TestOriginalPublish
                    $context.Dispose()
                }
            }
        }
    }
    $label = if ($Manual) { 'manual' } else { 'console' }
    $parent = Join-Path $testRoot ('O-' + $label); [IO.Directory]::CreateDirectory($parent) | Out-Null
    $ready=Join-Path $testRoot ($label+'-ready.txt');$pidFile=Join-Path $testRoot ($label+'-native.txt');$before=Join-Path $testRoot ($label+'-completed.json')
    $raw=Join-Path $testRoot ($label+'-raw.log');$codeFile=Join-Path $testRoot ($label+'-exit.txt');$modeFile=Join-Path $testRoot ($label+'-mode.json')
    $entry=New-AppCopy $label $ready $pidFile $before $library; $report.copied_entry_bytes_unchanged=$true
    Invoke-Case $(if ($Manual) { 'physical ConsoleHost Ctrl+C preserves first output, removes current partial and returns130' } else { 'controlled isolated console Ctrl+C key records preserve first output, remove current partial and return130' }) 'A29' {
        param($case)
        if ($Manual) {
            Assert-True (-not [Console]::IsInputRedirected) '-Manual requires a genuine local console with unredirected input.'
            $previousMode=[Console]::TreatControlCAsInput
            Write-Host 'T11 manual fixture: wait for READY, then press Ctrl+C once during the second encoder.'
            $oldPath=$env:PATH; $env:PATH=(Split-Path -Parent $ffmpeg)+';'+$oldPath
            $script:descendantReleaseProved=$false
            try { & $entry -InputFolder $inputRoot -OutputParent $parent -ConfigPath (Join-Path $testRoot 'missing-config.json') -BitrateKbps 64 *>&1 | ForEach-Object { [IO.File]::AppendAllText($raw,[string]$_+[Environment]::NewLine) } }
            finally { $env:PATH=$oldPath }
            Write-NewText $codeFile ([string]$global:LASTEXITCODE); Write-NewText $modeFile (([ordered]@{before=$previousMode;after=[Console]::TreatControlCAsInput}) | ConvertTo-Json)
            Assert-True (Test-Path -LiteralPath $ready) 'Manual Ctrl+C must occur after READY during real conversion.'
            $release=[IO.File]::ReadAllText($ready+'.released')|ConvertFrom-Json
            if($release.process_released){$script:descendantReleaseProved=$true}
            Assert-True $release.process_released 'Manual conversion must retain native helper exit/disposal proof.'
        } else {
            $driver=New-EntryDriver $label $entry $inputRoot $parent $raw $codeFile $modeFile
            $controllerReport=Join-Path $testRoot ($label+'-controller.json')
            $script:descendantReleaseProved=$false
            $child=Start-OwnedChild $controller @($shellPath,$driver,$ready,$pidFile,'key',$controllerReport,$ffmpeg)
            $result=Complete-OwnedChild $child
            $observed=[IO.File]::ReadAllText($controllerReport)|ConvertFrom-Json
            if ($observed.held_owned_handles_released) { $script:descendantReleaseProved=$true }
            Assert-True ($result.exit_code -eq 0 -and $observed.synthetic_ctrl_c_key_records -and $observed.held_owned_handles_released -and $observed.host_exit_code -eq 130) ('Isolated console cancellation must finish exactly: '+$observed.error+' '+$result.stderr)
            $case['controller']=$observed;$case['physical_manual_keypress_claim']=$false
        }
        Assert-CancelledRun $parent $raw $codeFile $modeFile $before $case
        if($Manual){$report.physical_manual_ctrl_c=$true;$case['physical_manual_keypress_claim']=$true}
    }
    if (-not $Manual) {
        Invoke-Case 'forced owned host termination leaves recognizable partial and completed output; next run preserves both plus arbitrary orphan' 'A30' {
            param($case)
            $crashParent=Join-Path $inputRoot 'Crash-runs';[IO.Directory]::CreateDirectory($crashParent)|Out-Null
            $crashReady=Join-Path $testRoot 'crash-ready.txt';$crashPid=Join-Path $testRoot 'crash-native.txt';$crashBefore=Join-Path $testRoot 'crash-completed.json'
            $crashEntry=New-AppCopy 'crash' $crashReady $crashPid $crashBefore $library
            $crashRaw=Join-Path $testRoot 'crash-raw.log';$crashCode=Join-Path $testRoot 'crash-exit.txt';$crashMode=Join-Path $testRoot 'crash-mode.json'
            $crashDriver=New-EntryDriver 'crash' $crashEntry $inputRoot $crashParent $crashRaw $crashCode $crashMode
            $controllerReport=Join-Path $testRoot 'crash-controller.json'
            $script:descendantReleaseProved=$false
            $child=Start-OwnedChild $controller @($shellPath,$crashDriver,$crashReady,$crashPid,'crash',$controllerReport,$ffmpeg)
            $result=Complete-OwnedChild $child;$observed=[IO.File]::ReadAllText($controllerReport)|ConvertFrom-Json
            if ($observed.held_owned_handles_released) { $script:descendantReleaseProved=$true }
            Assert-True ($result.exit_code -eq 0 -and $observed.forced_host_termination -and $observed.held_owned_handles_released) ('Exact crash controller must prove held native handle cleanup: '+$observed.error)
            $priorRuns=@(Get-ChildItem -LiteralPath $crashParent -Force | Where-Object { $_.PSIsContainer });Assert-True ($priorRuns.Count -eq 1) 'Crash must retain one recognizable owned run.'
            $tree=@(Get-SafeTree $priorRuns[0].FullName);$partials=@($tree|Where-Object{$_.Extension -ieq '.partial'});$outputs=@($tree|Where-Object{$_.Extension -ieq '.mp3'})
            Assert-True ($partials.Count -eq 1 -and $partials[0].Name -match '^\.AudioFileForPhone-[0-9a-f]{32}\.partial$' -and $outputs.Count -eq 1) 'Forced host termination must leave one nonfinal partial and first completed MP3.'
            Assert-True (-not (Test-Path -LiteralPath $crashCode)) 'Forced kill must not be represented as controlled shutdown.'
            $preserved=@($tree|Where-Object{-not $_.PSIsContainer}|ForEach-Object{[pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
            $nextParent=Join-Path $testRoot 'O-next';[IO.Directory]::CreateDirectory($nextParent)|Out-Null
            $nextRaw=Join-Path $testRoot 'next-raw.log';$nextCode=Join-Path $testRoot 'next-exit.txt';$nextMode=Join-Path $testRoot 'next-mode.json'
            # Run byte-identical production helpers without test pacing. The old
            # run is nested beneath input; discovery must exclude its identity.
            $plainRoot=Join-Path $testRoot 'A-next';[IO.Directory]::CreateDirectory($plainRoot)|Out-Null
            foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')) { $copy=Join-Path $plainRoot $name;[IO.File]::Copy((Join-Path $projectRoot $name),$copy,$false);Add-Fixture $copy }
            $nextDriver=New-EntryDriver 'next' (Join-Path $plainRoot 'AudioFileForPhone.ps1') $inputRoot $nextParent $nextRaw $nextCode $nextMode
            # Console mode is unavailable to redirected hosts; capture this
            # normal driver using the same fresh console controller is unsuitable
            # because it expects an encoder barrier, so omit only mode lines.
            $normalText=[IO.File]::ReadAllText($nextDriver).Replace('$previousMode=[Console]::TreatControlCAsInput', '$previousMode=$null').Replace('after=[Console]::TreatControlCAsInput','after=$null')
            $normalDriver=Join-Path $testRoot 'next-normal.ps1';Write-NewText $normalDriver $normalText;Add-Fixture $normalDriver
            $script:descendantReleaseProved=$false
            $nextChild=Start-OwnedChild $shellPath @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$normalDriver)
            $nextResult=Complete-OwnedChild $nextChild 60000
            $nextText=[IO.File]::ReadAllText($nextRaw)
            Assert-True ($nextResult.exit_code -eq 0 -and $nextText -match '\[RESULT\] status=Completed; total=3; processed=3; converted=3; failed=0; not_processed=0; scan_excluded=1; unsupported=1;') 'Next run must process only original audio, exclude prior run and count ordinary orphan as unsupported.'
            $script:descendantReleaseProved=$true
            foreach($item in $preserved) {Assert-True ((Get-FileHash -LiteralPath $item.path).Hash -ceq $item.sha256) 'Next run must preserve every prior run file including exact crash partial.'}
            Assert-True (-not $unrelated.process.HasExited) 'Unrelated real FFmpeg must survive host crash and next run.'
            $case['controller']=$observed;$case['recognizable_partial_name']=$partials[0].Name;$case['prior_run_all_file_hashes_unchanged']=$true
            $case['no_forced_host_cancelled_claim']=$true;$case['next_run_supported_count']=3;$case['arbitrary_orphan_preserved']=$true;$case['unrelated_real_ffmpeg_survived']=$true
        }
    }
    $report.status='pass';$exitCode=0
}
catch { $report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error }
finally {
    $childrenStopped=$descendantReleaseProved
    foreach($child in $children) {
        if($child.timed_out){$childrenStopped=$false}
        if($child.disposed){continue}
        try {if(-not $child.process.HasExited){$child.process.Kill()}
            Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Exact owned child still active; preserve tree.'
            Assert-True ($child.stdout_task.Wait(5000) -and $child.stderr_task.Wait(5000)) 'Exact owned pipes remained open; preserve tree.'
            $null=$child.stdout_task.GetAwaiter().GetResult();$null=$child.stderr_task.GetAwaiter().GetResult();$child.process.Dispose();$child.disposed=$true
        }catch{$childrenStopped=$false;$report['child_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    $report.children_disposed=$childrenStopped
    foreach($inventory in @('source','synthetic')) {
        try {$after=if($inventory -eq 'source'){Get-SourceInventory}else{Get-FixtureInventory};$report[$inventory+'_after']=$after
            $same=(($report[$inventory+'_before']|ConvertTo-Json -Compress) -ceq ($after|ConvertTo-Json -Compress));$report[$inventory+'_unchanged']=$same;Assert-True $same "$inventory SHA256 inventory must remain unchanged."
        }catch{$report.status='fail';$exitCode=1;$report[$inventory+'_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    try {
        if($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)) {
            $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exactly to exclusive owned TEMP root.'
            Assert-NoReparse $resolved;Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact CreateNew owner token.'
            Get-SafeTree $resolved|Out-Null;[IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'
    }catch{$report.status='fail';$exitCode=1;$report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    if(-not $childrenStopped){$report.status='fail';$exitCode=1}
    $report['finished_utc']=[DateTime]::UtcNow.ToString('o');Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 18)
}
Write-Host "T11 cancellation: $($report.status); cases=$($report.cases.Count); physical_manual=$Manual; children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
