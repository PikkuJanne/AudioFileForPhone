<#
Automated T20 representative audio smoke on the actual Windows host. The caller
must explicitly select one local input; no personal directories are searched.
Private audio, raw streams, tags and paths stay in a retained exclusive TEMP root.
Public evidence contains only a private ID, technical observations and hashes.
This establishes automated conversion/decode evidence, never manual playback.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [ValidatePattern('^T20-long-[0-9]{2}$')][string]$PrivateId = 'T20-long-01',
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\', '/')
$evidenceDirectory = Join-Path $projectRoot 'docs/codex-v1/evidence'
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ([IO.Path]::GetDirectoryName($evidenceFullPath) -ine $evidenceDirectory -or
    [IO.Path]::GetFileName($evidenceFullPath) -notmatch '^T20-long-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw 'EvidencePath must be a fresh T20-long-ps51/ps7-attempt/finalN.json in the evidence directory.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$ownedRoot = Join-Path ([IO.Path]::GetTempPath()) ('T20L-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$ownerPath = Join-Path $ownedRoot '.t20-long-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$rootCreated = $false
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat')
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$rawRuns = New-Object 'System.Collections.Generic.List[object]'
$stage = 'initial_validation'
$report = [ordered]@{
    schema_version = 1; task = 'T20'; mode = 'user_selected_representative_long_audio_automated'
    private_id = $PrivateId; tester = 'Codex automation'; input_selected_by = 'Janne Vuorela'
    started_utc = [DateTime]::UtcNow.ToString('o'); finished_utc = $null; status = 'fail'
    tested_commit = $null; runner_sha256 = $null; runner_snapshot_sha256 = $null; runner_after_sha256 = $null; runner_bytes_unchanged = $false; shell = $PSVersionTable.PSVersion.ToString()
    shell_edition = $PSVersionTable.PSEdition; shell_executable = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -eq 'Desktop') {'powershell.exe'} else {'pwsh.exe'})
    windows_build = $null; os_architecture = [Environment]::Is64BitOperatingSystem; elevated = $null; execution_policy = @()
    command = 'same-shell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File <PROJECT>\docs\codex-v1\tools\Test-T20LongAudio.ps1 -SourcePath <PRIVATE_SOURCE> -EvidencePath <PUBLIC_EVIDENCE>'
    private_invocation_sha256 = $null; original_source_path_redacted = $true
    ordinary_music_access = $false; manual_playback = 'not_run'; physical_manual_evidence = $false
    ownership = [ordered]@{ root_name = [IO.Path]::GetFileName($ownedRoot); exclusive_directory = $false; marker_sha256 = $null; marker_unchanged = $false; retained = $true; cleanup_attempted = $false }
    tools = [ordered]@{}; sources = @(); source = $null; output = $null; manifest = $null
    native_runs = @(); application_resources = $null; resources_method = 'nominal 50ms wait plus Toolhelp snapshot/sample work; actual first/last sample times and count per retained process; sampled working set and process-reported lifetime peak'
    source_bytes_unchanged = $false; source_copy_unchanged = $false; application_bytes_unchanged = $false
    all_observed_processes_exited_and_disposed = $false; failure_stage = $null; raw_capture_retained_privately = $true
}

function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse paths are refused.'
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    Assert-NoReparse ([IO.Path]::GetDirectoryName($Path))
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush() } finally { $stream.Dispose() }
}
function Get-Hash { param([string]$Path); Assert-NoReparse $Path; return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function New-OwnedDirectory {
    param([string]$Path)
    Assert-NoReparse ([IO.Path]::GetDirectoryName($Path))
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) 'Exclusive directory reservation failed.'
    Assert-NoReparse $Path
}
function Get-OwnedTree {
    param([string]$Root)
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $items = New-Object 'System.Collections.Generic.List[object]'
    Assert-NoReparse $Root; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-NoReparse $item.FullName
            Assert-True ($item.FullName.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) 'Inventory must stay inside exact owned output run.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Convert-PublicArguments {
    param([string[]]$NativeArguments)
    return @($NativeArguments | ForEach-Object { $_.Replace($ownedRoot, '<OWNED_TEMP>').Replace($projectRoot, '<PROJECT>').Replace($SourcePath, '<PRIVATE_SOURCE>') })
}
function Invoke-BoundedProcess {
    param([string]$Label, [string]$ExecutablePath, [string[]]$NativeArguments, [int]$TimeoutMilliseconds = 60000, [switch]$Application)
    $capture = [T20Long.Controller]::Run($ExecutablePath, $NativeArguments, $ownedRoot, $TimeoutMilliseconds,
        (Split-Path -Parent $FfmpegPath) + ';' + (Split-Path -Parent $FfprobePath) + ';' + $env:PATH,
        [bool]$Application, $FfmpegPath, $FfprobePath)
    $rawRuns.Add([pscustomobject]@{ label = $Label; executable = $ExecutablePath; arguments = $NativeArguments; capture = $capture })
    $nativeRuns.Add([pscustomobject]@{
        label = $Label; executable = $ExecutablePath; arguments = (Convert-PublicArguments $NativeArguments)
        deadline_ms = $TimeoutMilliseconds; timed_out = $capture.TimedOut; exit_code = $capture.ExitCode
        elapsed_ms = $capture.ElapsedMilliseconds; process_released = $capture.AllExitedAndDisposed
        capture_truncated = $capture.Truncated; observation_error = $capture.ObservationError; controller_forced_termination = $capture.ForcedTermination
    })
    if ($Application) { $report.application_resources = $capture.Resources }
    Assert-True (-not $capture.TimedOut -and $capture.ExitCode -eq 0 -and $capture.AllExitedAndDisposed -and -not $capture.Truncated -and -not $capture.ObservationError -and -not $capture.ForcedTermination) ('Bounded process failed: ' + $Label)
    return $capture
}
function Get-TechnicalProbe {
    param([string]$Label, [string]$Path)
    $capture = Invoke-BoundedProcess $Label $FfprobePath @('-v', 'error', '-show_entries', 'stream=index,codec_type,codec_name,sample_rate,channels,bit_rate,duration:format=duration,size', '-of', 'json', '-i', $Path)
    $data = $capture.Stdout | ConvertFrom-Json
    $audio = @($data.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($audio.Count -eq 1) 'Exactly one audio stream is required.'
    $duration = [double]::Parse([string]$data.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    Assert-True ($duration -gt 0 -and -not [double]::IsInfinity($duration) -and -not [double]::IsNaN($duration)) 'Finite positive duration is required.'
    return [pscustomobject]@{
        codec = [string]$audio[0].codec_name; sample_rate = [int]$audio[0].sample_rate; channels = [int]$audio[0].channels
        audio_bitrate = [long]$audio[0].bit_rate; duration_seconds = $duration
        non_audio_codecs = @($data.streams | Where-Object { $_.codec_type -cne 'audio' } | ForEach-Object { [string]$_.codec_name })
    }
}

$supportSource = @'
using System; using System.IO; using System.Diagnostics; using System.Text;
using System.Collections.Generic; using System.Threading; using System.Threading.Tasks;
using System.Runtime.InteropServices;
namespace T20Long {
 public sealed class Resource {
  public string Role; public int Pid; public string StartedUtc; public double ElapsedMilliseconds;
  public double CpuMilliseconds; public long SampledWorkingSetPeakBytes; public long ProcessLifetimeWorkingSetPeakBytes;
  public int Samples; public double FirstSampleMilliseconds; public double LastSampleMilliseconds;
  public bool Exited; public bool Disposed; public int ExitCode; public bool ControllerKillAttempted;
 }
 public sealed class Capture {
  public string Stdout=""; public string Stderr=""; public bool TimedOut; public bool Truncated;
  public int ExitCode=-1; public double ElapsedMilliseconds; public bool AllExitedAndDisposed;
  public bool ObservationError; public bool ForcedTermination; public Resource[] Resources;
 }
 sealed class Owned { public Process Process; public Resource Resource; public DateTime Started; }
 public static class Controller {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Entry {
   public uint Size,Usage,Pid; public IntPtr Heap; public uint Module,Threads,Parent; public int Priority; public uint Flags;
   [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string Exe;
  }
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr CreateToolhelp32Snapshot(uint flags,uint pid);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool Process32FirstW(IntPtr snapshot,ref Entry entry);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool Process32NextW(IntPtr snapshot,ref Entry entry);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  static string Quote(string value) {
   StringBuilder b=new StringBuilder("\""); int n=0;
   foreach(char c in value) { if(c=='\\'){n++;continue;} if(c=='"')b.Append('\\',n*2+1);else b.Append('\\',n);b.Append(c);n=0; }
   b.Append('\\',n*2);return b.Append('"').ToString();
  }
  static string CommandLine(string[] values) { StringBuilder b=new StringBuilder();foreach(string s in values){if(b.Length>0)b.Append(' ');b.Append(Quote(s));}return b.ToString(); }
  static string Drain(StreamReader stream, Capture capture) {
   StringBuilder text=new StringBuilder();char[] buffer=new char[4096];int read;
   while((read=stream.Read(buffer,0,buffer.Length))>0){int keep=Math.Min(read,1048576-text.Length);if(keep>0)text.Append(buffer,0,keep);if(keep<read)capture.Truncated=true;}
   return text.ToString();
  }
  static Owned Retain(Process process,string role) {
   IntPtr handle=process.Handle;DateTime started=process.StartTime.ToUniversalTime();
   return new Owned { Process=process,Started=started,Resource=new Resource {Role=role,Pid=process.Id,StartedUtc=started.ToString("o")} };
  }
  static void Sample(Owned owned,double elapsed) {
   Process p=owned.Process;Resource r=owned.Resource;
   if(p.HasExited){r.Exited=true;r.ExitCode=p.ExitCode;try{r.CpuMilliseconds=p.TotalProcessorTime.TotalMilliseconds;r.ElapsedMilliseconds=(p.ExitTime.ToUniversalTime()-owned.Started).TotalMilliseconds;}catch{}return;}
   try {
    p.Refresh();r.CpuMilliseconds=p.TotalProcessorTime.TotalMilliseconds;
    r.SampledWorkingSetPeakBytes=Math.Max(r.SampledWorkingSetPeakBytes,p.WorkingSet64);
    r.ProcessLifetimeWorkingSetPeakBytes=Math.Max(r.ProcessLifetimeWorkingSetPeakBytes,p.PeakWorkingSet64);
    if(r.Samples==0)r.FirstSampleMilliseconds=elapsed;r.LastSampleMilliseconds=elapsed;r.Samples++;
   }catch(InvalidOperationException){if(!p.HasExited)throw;Sample(owned,elapsed);}
  }
  static void Discover(List<Owned> owned,string ffmpeg,string ffprobe) {
   DateTime snapshotStarted=DateTime.UtcNow;
   IntPtr snapshot=CreateToolhelp32Snapshot(2,0);if(snapshot==new IntPtr(-1))throw new IOException("Process snapshot failed.");
   try { Entry e=new Entry();e.Size=(uint)Marshal.SizeOf(typeof(Entry));bool valid=Process32FirstW(snapshot,ref e);
    while(valid){
     Owned parent=owned.Find(o=>o.Resource.Pid==(int)e.Parent&&!o.Process.HasExited);
     if(parent!=null&&!owned.Exists(o=>o.Resource.Pid==(int)e.Pid&&!o.Resource.Exited)){
      Process child=null;
      try {
       child=Process.GetProcessById((int)e.Pid);IntPtr retainedHandle=child.Handle;
       DateTime started=child.StartTime.ToUniversalTime();
       if(!child.HasExited&&!parent.Process.HasExited&&started>=parent.Started&&started<=snapshotStarted){
        string image=child.MainModule.FileName;
        string role=String.Equals(image,ffmpeg,StringComparison.OrdinalIgnoreCase)?"ffmpeg":String.Equals(image,ffprobe,StringComparison.OrdinalIgnoreCase)?"ffprobe":"other_owned_child";
        owned.Add(Retain(child,role));child=null;
       }
      }catch(ArgumentException){}catch(InvalidOperationException){}catch(System.ComponentModel.Win32Exception){if(child!=null&&!child.HasExited)throw;}finally{if(child!=null)child.Dispose();}
     }
     valid=Process32NextW(snapshot,ref e);
    }
   }finally{CloseHandle(snapshot);}
  }
  public static Capture Run(string executable,string[] arguments,string directory,int deadline,string childPath,bool monitorChildren,string ffmpeg,string ffprobe) {
   Capture capture=new Capture();List<Owned> owned=new List<Owned>();Stopwatch clock=Stopwatch.StartNew();
   Process host=new Process();Task<string> stdout=null,stderr=null;
   try {
    ProcessStartInfo start=new ProcessStartInfo();start.FileName=executable;start.Arguments=CommandLine(arguments);
    start.WorkingDirectory=directory;start.UseShellExecute=false;start.CreateNoWindow=true;
    start.RedirectStandardOutput=true;start.RedirectStandardError=true;
    start.StandardOutputEncoding=new UTF8Encoding(false);start.StandardErrorEncoding=new UTF8Encoding(false);
    start.EnvironmentVariables["PATH"]=childPath;start.EnvironmentVariables.Remove("PSModulePath");
    host.StartInfo=start;if(!host.Start())throw new IOException("Owned process failed to start.");
    owned.Add(Retain(host,monitorChildren?"application_host":"native_check"));
    stdout=Task.Factory.StartNew(()=>Drain(host.StandardOutput,capture));stderr=Task.Factory.StartNew(()=>Drain(host.StandardError,capture));
    while(!host.HasExited){
     if(monitorChildren)Discover(owned,ffmpeg,ffprobe);
     foreach(Owned item in owned)Sample(item,clock.Elapsed.TotalMilliseconds);
     if(clock.ElapsedMilliseconds>deadline){capture.TimedOut=true;break;}
     host.WaitForExit(50);
    }
    if(!capture.TimedOut){host.WaitForExit();capture.ExitCode=host.ExitCode;}
   }catch{capture.ObservationError=true;}
   finally {
    for(int i=owned.Count-1;i>=0;i--){
     Owned item=owned[i];try{if(!item.Process.HasExited&&!item.Process.WaitForExit(1000)){item.Resource.ControllerKillAttempted=true;capture.ForcedTermination=true;item.Process.Kill();}if(item.Process.WaitForExit(5000))Sample(item,clock.Elapsed.TotalMilliseconds);}catch{capture.ObservationError=true;}
    }
    if(stdout!=null){try{if(!stdout.Wait(5000))capture.ObservationError=true;else capture.Stdout=stdout.Result;}catch{capture.ObservationError=true;}}
    if(stderr!=null){try{if(!stderr.Wait(5000))capture.ObservationError=true;else capture.Stderr=stderr.Result;}catch{capture.ObservationError=true;}}
    foreach(Owned item in owned){try{item.Resource.Exited=item.Process.HasExited;item.Process.Dispose();item.Resource.Disposed=true;}catch{capture.ObservationError=true;}}
    if(owned.Count==0)host.Dispose();
    capture.AllExitedAndDisposed=owned.Count>0&&owned.TrueForAll(o=>o.Resource.Exited&&o.Resource.Disposed);
    capture.ElapsedMilliseconds=clock.Elapsed.TotalMilliseconds;capture.Resources=owned.ConvertAll(o=>o.Resource).ToArray();
   }
   return capture;
  }
  public static object CbrFrames(string path) {
   long frames=0;HashSet<int> rates=new HashSet<int>();int[] mpeg1={0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0};
   int[] mpeg2={0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0};int[] sample={44100,48000,32000};
   using(FileStream f=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.Read)) {
    byte[] h=new byte[10];if(f.Read(h,0,10)!=10)throw new IOException("Short MP3.");
    if(h[0]==73&&h[1]==68&&h[2]==51){for(int i=6;i<10;i++)if(h[i]>=128)throw new IOException("Invalid ID3 size.");long size=((long)h[6]<<21)|((long)h[7]<<14)|((long)h[8]<<7)|h[9];f.Position=10+size+((h[5]&16)!=0?10:0);}else f.Position=0;
    while(f.Position<f.Length){
     long position=f.Position;int remaining=(int)Math.Min(4,f.Length-position);if(f.Read(h,0,remaining)!=4)throw new IOException("Trailing MP3 bytes.");
     if(f.Length-position==128&&h[0]==84&&h[1]==65&&h[2]==71){f.Position=f.Length;break;}
     if(h[0]!=255||(h[1]&224)!=224)throw new IOException("Invalid MP3 sync.");
     int version=(h[1]>>3)&3,layer=(h[1]>>1)&3,index=h[2]>>4,sampleIndex=(h[2]>>2)&3;
     if(version==1||layer!=1||index==0||index==15||sampleIndex==3)throw new IOException("Unsupported MP3 frame.");
     int bitrate=(version==3?mpeg1:mpeg2)[index],frequency=sample[sampleIndex]/(version==3?1:version==2?2:4);
     int length=(version==3?144000:72000)*bitrate/frequency+((h[2]>>1)&1);
     if(position+length>f.Length)throw new IOException("Truncated MP3 frame.");rates.Add(bitrate);frames++;f.Position=position+length;
    }
   }
   return new { frame_count=frames, unique_bitrates_kbps=new List<int>(rates).ToArray(), cbr_64kbps=frames>0&&rates.Count==1&&rates.Contains(64) };
  }
 }
}
'@

try {
    foreach ($path in @($PSCommandPath, $projectRoot, (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'), [IO.Path]::GetTempPath(), $SourcePath, $FfmpegPath, $FfprobePath, $evidenceDirectory)) { Assert-NoReparse $path }
    Assert-True ($SourcePath -match '^(?:[A-Za-z]:[\\/]|\\\\[^\\/.?]+[\\/][^\\/]+[\\/])') 'Selected source must have a full absolute drive or UNC path.'
    $SourcePath = (Get-Item -LiteralPath $SourcePath -Force).FullName
    $sourceItem = Get-Item -LiteralPath $SourcePath -Force
    Assert-True (-not $sourceItem.PSIsContainer -and $sourceItem.Extension -iin @('.mp3', '.m4a', '.ogg')) 'Selected source must be one regular supported audio file.'
    Assert-True (-not $SourcePath.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Selected personal source must stay outside the repository.'
    $sourceBefore = Get-Hash $SourcePath
    $report.source = [ordered]@{ private_id = $PrivateId; length = $sourceItem.Length; sha256_before = $sourceBefore; sha256_after = $null; copy_sha256_before = $null; copy_sha256_after = $null; attributes = $sourceItem.Attributes.ToString(); probe = $null }
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Add-Type -TypeDefinition $supportSource -ErrorAction Stop
    New-OwnedDirectory $ownedRoot; $rootCreated = $true; $report.ownership.exclusive_directory = $true
    Write-NewText $ownerPath $ownerToken; $report.ownership.marker_sha256 = Get-Hash $ownerPath
    $privateSourceRecord = [ordered]@{ source_path = $SourcePath; source_private_id = $PrivateId; selected_by = 'Janne Vuorela'; ordinary_user_run = $true }
    Write-NewText (Join-Path $ownedRoot 'private-selection.json') ($privateSourceRecord | ConvertTo-Json)
    $privateInvocationPath = Join-Path $ownedRoot 'private-invocation.json'
    Write-NewText $privateInvocationPath ([ordered]@{ command_line = [Environment]::CommandLine; source_path = $SourcePath; evidence_path = $evidenceFullPath; parameters = $PSBoundParameters } | ConvertTo-Json -Depth 6)
    $report.private_invocation_sha256 = Get-Hash $privateInvocationPath
    $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try { $principal = New-Object Security.Principal.WindowsPrincipal($identity); $report.elevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } finally { $identity.Dispose() }
    Assert-True (-not $report.elevated) 'Acceptance must run as an ordinary user.'
    $report.execution_policy = @(Get-ExecutionPolicy -List | ForEach-Object { [pscustomobject]@{ scope = $_.Scope.ToString(); policy = $_.ExecutionPolicy.ToString() } })
    $report.runner_sha256 = Get-Hash $PSCommandPath
    $runnerSnapshotPath = Join-Path $ownedRoot 'runner-snapshot.ps1'
    [IO.File]::Copy($PSCommandPath, $runnerSnapshotPath, $false)
    $report.runner_snapshot_sha256 = Get-Hash $runnerSnapshotPath
    Assert-True ($report.runner_snapshot_sha256 -ceq $report.runner_sha256) 'Runner snapshot must bind exact tested working bytes.'
    $gitPath = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $report.tested_commit = (Invoke-BoundedProcess 'source_commit' $gitPath @('-C', $projectRoot, 'rev-parse', 'HEAD')).Stdout.Trim()
    Assert-True ($report.tested_commit -cmatch '^[a-f0-9]{40}$') 'Full tested commit required.'
    foreach ($name in @('ffmpeg', 'ffprobe')) {
        $tool = if ($name -ceq 'ffmpeg') { $FfmpegPath } else { $FfprobePath }
        $version = Invoke-BoundedProcess ($name + '_version') $tool @('-version')
        $report.tools[$name] = [ordered]@{ path = $tool; sha256 = Get-Hash $tool; version = ($version.Stdout -split '\r?\n')[0] }
    }
    $stage = 'exclusive_copy'
    $appDirectory = Join-Path $ownedRoot 'app'; $inputDirectory = Join-Path $ownedRoot 'input'; $outputParent = Join-Path $ownedRoot 'output'
    foreach ($directory in @($appDirectory, $inputDirectory, $outputParent)) { New-OwnedDirectory $directory }
    foreach ($name in $sourceFiles) {
        $source = Join-Path $projectRoot $name; $copy = Join-Path $appDirectory $name; $sourceHash = Get-Hash $source
        [IO.File]::Copy($source, $copy, $false); $copyHash = Get-Hash $copy
        Assert-True ($sourceHash -ceq $copyHash) 'Application copy must be byte-identical.'
        $report.sources += [pscustomobject]@{ name = $name; source_sha256_before = $sourceHash; copy_sha256_before = $copyHash; source_sha256_after = $null; copy_sha256_after = $null }
    }
    $inputCopy = Join-Path $inputDirectory ($PrivateId + $sourceItem.Extension.ToLowerInvariant())
    [IO.File]::Copy($SourcePath, $inputCopy, $false)
    $report.source.copy_sha256_before = Get-Hash $inputCopy
    Assert-True ($report.source.copy_sha256_before -ceq $sourceBefore) 'Source copy must be byte-identical.'
    $stage = 'source_probe'
    $report.source.probe = Get-TechnicalProbe 'source_probe' $inputCopy
    Assert-True ($report.source.probe.duration_seconds -gt 3600) 'Representative source must exceed one hour.'
    $stage = 'application_conversion'
    $appArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', (Join-Path $appDirectory 'AudioFileForPhone.ps1'), '-InputFolder', $inputDirectory, '-OutputParent', $outputParent)
    $application = Invoke-BoundedProcess 'unchanged_application_default64kbps' $report.shell_executable $appArguments -TimeoutMilliseconds 180000 -Application
    $ffmpegResources = @($report.application_resources | Where-Object { $_.Role -ceq 'ffmpeg' })
    Assert-True ($ffmpegResources.Count -ge 2 -and @($ffmpegResources | Where-Object { $_.Samples -ge 10 }).Count -ge 1) 'Real FFmpeg resources must have useful samples during long conversion.'
    $stage = 'application_outcomes'
    $outputEntries = @(Get-ChildItem -LiteralPath $outputParent -Force)
    Assert-True ($outputEntries.Count -eq 1 -and $outputEntries[0].PSIsContainer) 'Exactly one owned output run required.'
    $runRoot = $outputEntries[0].FullName; Assert-NoReparse $runRoot
    $markerFile = Join-Path $runRoot '.AudioFileForPhone-output.json'
    $marker = [IO.File]::ReadAllText($markerFile) | ConvertFrom-Json
    Assert-True ($marker.output_root -ceq $runRoot -and $marker.cleanup_scope -ceq $runRoot -and $marker.ownership_token -cmatch '^[a-f0-9]{32}$') 'Output ownership identity must match exact root.'
    $manifestPath = Join-Path $runRoot 'AudioFileForPhone_manifest.json'; Assert-NoReparse $manifestPath
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.supported -eq 1 -and $manifest.totals.processed -eq 1 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.totals.not_completed -eq 0 -and $manifest.totals.unsupported -eq 0 -and $manifest.totals.scan_excluded -eq 0) 'Manifest must report exactly one completed conversion.'
    Assert-True (@($manifest.records).Count -eq 1 -and $manifest.records[0].status -ceq 'Converted' -and $manifest.policies.bitrate_kbps -eq 64) 'Converted record/default bitrate required.'
    $report.manifest = [ordered]@{ sha256 = Get-Hash $manifestPath; status = $manifest.run.status; exit_code = $manifest.run.exit_code; totals = $manifest.totals; input_duration_seconds = $manifest.records[0].input_duration_seconds; output_duration_seconds = $manifest.records[0].output_duration_seconds; decoded_duration_seconds = $manifest.records[0].decoded_duration_seconds; elapsed_seconds = $manifest.run.elapsed_seconds; entry_sha256 = $manifest.build.entry_sha256; helper_sha256 = $manifest.build.helper_sha256 }
    Assert-True ($manifest.build.entry_sha256 -ceq $report.sources[0].copy_sha256_before -and $manifest.build.helper_sha256 -ceq $report.sources[1].copy_sha256_before) 'Manifest must bind unchanged copied runtime bytes.'
    $tree = @(Get-OwnedTree $runRoot)
    $outputs = @($tree | Where-Object { $_.Extension -ieq '.mp3' })
    Assert-True ($outputs.Count -eq 1 -and @($tree | Where-Object { $_.Extension -ieq '.partial' }).Count -eq 0) 'Exactly one published MP3 and no partial files required.'
    $outputFile = $outputs[0].FullName
    $stage = 'independent_output_validation'
    $outputProbe = Get-TechnicalProbe 'output_probe' $outputFile
    $difference = [Math]::Abs($outputProbe.duration_seconds - $report.source.probe.duration_seconds)
    Assert-True ($outputProbe.codec -ceq 'mp3' -and $outputProbe.audio_bitrate -eq 64000 -and $difference -le 0.35) 'Independent output must be 64kbps MP3 within 0.35 seconds source duration.'
    $frames = [T20Long.Controller]::CbrFrames($outputFile)
    Assert-True ($frames.cbr_64kbps) 'Every independently scanned MP3 frame must declare 64kbps.'
    $outputHashBefore = Get-Hash $outputFile
    Invoke-BoundedProcess 'independent_full_decode' $FfmpegPath @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $outputFile, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
    $nearEndStart = $outputProbe.duration_seconds - 30
    Invoke-BoundedProcess 'independent_near_end_decode' $FfmpegPath @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-ss', $nearEndStart.ToString('F6', [Globalization.CultureInfo]::InvariantCulture), '-i', $outputFile, '-t', '20', '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
    $report.output = [ordered]@{ private_id = $PrivateId; length = (Get-Item -LiteralPath $outputFile).Length; sha256_before_decode = $outputHashBefore; sha256_after_decode = Get-Hash $outputFile; probe = $outputProbe; duration_difference_seconds = $difference; tolerance_seconds = 0.35; cbr_frame_scan = $frames; independent_full_decode = $true; near_end_decode_start_seconds = $nearEndStart; near_end_decode_length_seconds = 20; independent_near_end_decode = $true }
    Assert-True ($report.output.sha256_after_decode -ceq $outputHashBefore) 'Independent decoding must preserve output bytes.'
    $report.status = 'pass'
}
catch {
    $report.failure_stage = $stage
    if ($rootCreated) { Write-NewText (Join-Path $ownedRoot 'private-error.txt') ($_ | Out-String) }
}
finally {
    if ($rootCreated) {
        try {
            $report.source.sha256_after = Get-Hash $SourcePath
            $report.source_bytes_unchanged = $report.source.sha256_after -ceq $report.source.sha256_before
            if ($inputCopy -and [IO.File]::Exists($inputCopy)) {
                $report.source.copy_sha256_after = Get-Hash $inputCopy
                $report.source_copy_unchanged = $report.source.copy_sha256_after -ceq $report.source.copy_sha256_before
            }
            foreach ($source in $report.sources) {
                $source.source_sha256_after = Get-Hash (Join-Path $projectRoot $source.name)
                $source.copy_sha256_after = Get-Hash (Join-Path $appDirectory $source.name)
            }
            $report.application_bytes_unchanged = $report.sources.Count -eq 3 -and @($report.sources | Where-Object { $_.source_sha256_before -cne $_.source_sha256_after -or $_.copy_sha256_before -cne $_.copy_sha256_after -or $_.source_sha256_after -cne $_.copy_sha256_after }).Count -eq 0
            $report.ownership.marker_unchanged = [IO.File]::ReadAllText($ownerPath) -ceq $ownerToken -and (Get-Hash $ownerPath) -ceq $report.ownership.marker_sha256
            $report.runner_after_sha256 = Get-Hash $PSCommandPath
            $report.runner_bytes_unchanged = $report.runner_sha256 -ceq $report.runner_after_sha256 -and $report.runner_sha256 -ceq (Get-Hash $runnerSnapshotPath)
            $report.all_observed_processes_exited_and_disposed = $nativeRuns.Count -gt 0 -and @($nativeRuns | Where-Object { -not $_.process_released }).Count -eq 0
            if (-not ($report.source_bytes_unchanged -and $report.source_copy_unchanged -and $report.application_bytes_unchanged -and $report.runner_bytes_unchanged -and $report.ownership.marker_unchanged -and $report.all_observed_processes_exited_and_disposed)) { $report.status = 'fail'; $report.failure_stage = 'preservation_and_release' }
        } catch { $report.status = 'fail'; $report.failure_stage = 'final_preservation_inspection'; Write-NewText (Join-Path $ownedRoot 'private-final-error.txt') ($_ | Out-String) }
        Write-NewText (Join-Path $ownedRoot 'private-native-capture.json') ($rawRuns.ToArray() | ConvertTo-Json -Depth 12)
    }
    $report.native_runs = @($nativeRuns.ToArray()); $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    Write-NewText $evidenceFullPath (($report | ConvertTo-Json -Depth 16) + [Environment]::NewLine)
}
if ($report.status -cne 'pass') { throw ('T20 long-file automation failed at ' + $report.failure_stage + '; private capture retained in ' + $report.ownership.root_name) }
[pscustomobject]@{ status = $report.status; evidence = $evidenceFullPath; retained_root_name = $report.ownership.root_name; output_duration_seconds = $report.output.probe.duration_seconds; application_elapsed_ms = @($report.application_resources | Where-Object { $_.Role -ceq 'application_host' })[0].ElapsedMilliseconds }
