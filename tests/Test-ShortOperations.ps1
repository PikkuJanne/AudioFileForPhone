<#
S03 real Windows deadlines and pipe ownership. Compiled independent children,
synthetic audio, copied runtime and raw diagnostics stay in marked owned TEMP.
The report is create-new and keeps the historical T17 CI path contract.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S03-shortoperations-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-shortoperations-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S03-shortoperations active report or the historical T17-shortoperations CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S03-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s03-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$created = $false
$fixtureReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$identityFiles = New-Object 'System.Collections.Generic.List[string]'
$retainedProcesses = New-Object 'System.Collections.Generic.List[object]'
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$uncertainOperations = New-Object 'System.Collections.Generic.HashSet[string]'
$originalNative = $null
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat', 'tests/Test-ShortOperations.ps1', '.github/scripts/Invoke-CiChecks.ps1')
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S03' }); mode = 'real_windows_short_operations'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; physical_manual_evidence = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    cleanup_verified = $false; descendant_release_proved = $false; native_runs = @(); tools = @(); cases = @()
    status = 'fail'; error = $null
}
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Assert-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' }
    finally { $report.cases += [pscustomobject]$case }
}
function Save-NativeResult {
    param([object]$Result)
    $nativeRuns.Add([pscustomobject]@{
        operation = $Result.Operation; status = $Result.Status; exit_code = $Result.ExitCode
        elapsed_ms = $Result.ElapsedMilliseconds; timeout_ms = $Result.TimeoutMilliseconds
        process_released = $Result.ProcessReleased; pipe_drain_completed = $Result.PipeDrainCompleted
        stdout_retained = $Result.Stdout.Length; stderr_retained = $Result.Stderr.Length
    })
}
function Invoke-TrackedNative {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments,
        [int]$MaxStdoutChars = 1048576, [int]$MaxStderrChars = 65536,
        [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
        [AllowNull()][scriptblock]$ProgressCallback, [AllowNull()][object]$ProgressDurationSeconds,
        [AllowNull()][object]$ProgressParser, [AllowNull()][object]$ProgressCallbackState,
        [int]$TimeoutMilliseconds = 0, [string]$Operation = 'Native operation', [int]$PipeDrainTimeoutMilliseconds = 5000
    )
    try {
        $native = & $script:originalNative @PSBoundParameters
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) { $uncertainOperations.Add($Operation) | Out-Null }
        return $native
    } catch { $uncertainOperations.Add($Operation) | Out-Null; throw }
}
function Assert-Success {
    param([object]$Result)
    Save-NativeResult $Result
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ExitCode -eq 0 -and $Result.ProcessReleased -and $Result.PipeDrainCompleted) ('Expected complete success/release/EOF: ' + $Result.Status + ' ' + $Result.Error + ' ' + $Result.Stderr)
}
function Assert-Timeout {
    param([object]$Result, [int]$Timeout, [bool]$Released = $true, [int]$EarliestMilliseconds = $Timeout)
    Save-NativeResult $Result
    Assert-True ($Result.Status -ceq 'Timeout' -and $Result.TimeoutMilliseconds -eq $Timeout -and $Result.ProcessReleased -eq $Released) 'Timeout must preserve its deadline and conservative release result.'
    Assert-True ($Result.ElapsedMilliseconds -ge ($EarliestMilliseconds - 40) -and $Result.ElapsedMilliseconds -lt ($Timeout + 8000)) 'The earliest operation/drain deadline plus separately bounded teardown must finish within eight seconds of the configured operation deadline.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($Result.Operation) -and $Result.Error -match 'Timeout|timed out|deadline') 'Timeout must identify its operation and diagnostic.'
}
function Get-ExactFixtureProcess {
    param([string]$IdentityPath)
    Assert-NoReparse $IdentityPath
    $identity = Get-Content -LiteralPath $IdentityPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($identity.token -ceq $ownerToken -and [IO.Path]::GetFullPath($identity.executable).StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Process identity must belong to this exact fixture tree/token.'
    $process = [Diagnostics.Process]::GetProcessById([int]$identity.pid)
    try {
        # Opening the retained handle precedes identity checks and any Kill.
        $retainedHandle = $process.Handle
        Assert-True ($retainedHandle -ne [IntPtr]::Zero -and $process.StartTime.ToUniversalTime().Ticks -eq [long]$identity.started_ticks -and
            [IO.Path]::GetFullPath($process.MainModule.FileName) -ieq [IO.Path]::GetFullPath($identity.executable)) 'Exact retained PID/start-time/executable identity must match before fixture cleanup.'
        return $process
    } catch { $process.Dispose(); throw }
}
function Stop-ExactFixtureProcess {
    param([Diagnostics.Process]$Process)
    try {
        if (-not $Process.HasExited) { $Process.Kill() }
        Assert-True ($Process.WaitForExit(5000)) 'Exact retained fixture process must exit before cleanup.'
    } finally { $Process.Dispose() }
}
$exitCode = 1
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    Add-Type -TypeDefinition @'
using System;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
namespace AudioFileForPhoneS03 {
    public static class NativeDirectory {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        [return: MarshalAs(UnmanagedType.Bool)] public static extern bool CreateDirectoryW(string path, IntPtr attributes);
    }
    public sealed class RequestTimer : IDisposable {
        private Timer timer;
        public RequestTimer(object context, int milliseconds) {
            MethodInfo request = context.GetType().GetMethod("Request");
            timer = new Timer(delegate(object ignored) { request.Invoke(context, new object[0]); }, null, milliseconds, Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@
    Assert-True ([AudioFileForPhoneS03.NativeDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Exact TEMP directory must be reserved exclusively.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'App [literal]'
    [IO.Directory]::CreateDirectory($appRoot) | Out-Null
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
        $copy = Join-Path $appRoot $name
        Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Runtime copies must preserve source bytes.'
        $fixtures.Add($copy)
    }
    $report.copied_bytes_unchanged = $true
    . (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')
    $script:originalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
    $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($tool in @($ffmpeg, $ffprobe)) {
        Assert-NoReparse $tool
        $version = Invoke-AudioNativeProcess -ExecutablePath $tool -Arguments @('-version') -TimeoutMilliseconds 15000 -Operation 'fixture tool identity'
        Assert-Success $version
        $report.tools += [pscustomobject]@{ name = [IO.Path]::GetFileName($tool); sha256 = (Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant(); version = ($version.Stdout -split '\r?\n')[0] }
    }
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    Assert-True (Test-Path -LiteralPath $compiler -PathType Leaf) 'Installed Windows C# compiler is required.'
    $childSource = Join-Path $testRoot 'ShortChild.cs'
    $child = Join-Path $testRoot 'ShortChild.exe'
    Write-NewText $childSource @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
class ShortChild {
    [StructLayout(LayoutKind.Sequential)] struct SA { public int size; public IntPtr descriptor; [MarshalAs(UnmanagedType.Bool)] public bool inherit; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct SI { public int cb; public string reserved, desktop, title; public int x,y, xs,ys, xc,yc, fill, flags; public short show, reserved2; public IntPtr reservedPtr, input, output, error; }
    [StructLayout(LayoutKind.Sequential)] struct PI { public IntPtr process, thread; public int pid, tid; }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcessW(string app, StringBuilder command, IntPtr pa, IntPtr ta, bool inherit, int flags, IntPtr env, string cwd, ref SI start, out PI process);
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int kind);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetHandleInformation(IntPtr handle, out uint flags);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFileW(string path, uint access, uint share, ref SA attributes, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    static string Exe { get { return Process.GetCurrentProcess().MainModule.FileName; } }
    static void Record(string file, string token, Process process) {
        string text = new JavaScriptSerializer().Serialize(new { pid=process.Id, started_ticks=process.StartTime.ToUniversalTime().Ticks, executable=process.MainModule.FileName, token=token });
        using (FileStream stream = new FileStream(file, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
            byte[] bytes = new UTF8Encoding(false).GetBytes(text); stream.Write(bytes,0,bytes.Length);
        }
    }
    static void HoldPipe(string mode, string identity, string token) {
        SA sa = new SA(); sa.size=Marshal.SizeOf(typeof(SA)); sa.inherit=true;
        IntPtr nul=CreateFileW("NUL",0xC0000000,3,ref sa,3,0,IntPtr.Zero);
        if (nul.ToInt64()==-1) throw new Exception("Cannot create inherited NUL.");
        IntPtr excluded=GetStdHandle(mode=="hold-stdout" ? -12 : -11);
        uint excludedFlags;
        if(!GetHandleInformation(excluded,out excludedFlags) || !SetHandleInformation(excluded,1,0)) throw new Exception("Cannot isolate inherited pipe handles.");
        try {
            SI si=new SI(); si.cb=Marshal.SizeOf(typeof(SI)); si.flags=0x100; si.input=nul;
            si.output=mode=="hold-stdout" ? GetStdHandle(-11) : nul;
            si.error=mode=="hold-stderr" ? GetStdHandle(-12) : nul;
            PI pi;
            if(!CreateProcessW(null,new StringBuilder("\""+Exe+"\" hold"),IntPtr.Zero,IntPtr.Zero,true,0,IntPtr.Zero,Path.GetDirectoryName(Exe),ref si,out pi)) throw new Exception("CreateProcessW "+Marshal.GetLastWin32Error());
            try { using(Process process=Process.GetProcessById(pi.pid)) { Record(identity,token,process); } }
            finally { CloseHandle(pi.thread); CloseHandle(pi.process); }
        } finally { SetHandleInformation(excluded,1,excludedFlags & 1); CloseHandle(nul); }
    }
    static int Main(string[] args) {
        Console.OutputEncoding=new UTF8Encoding(false);
        string mode=args.Length>0 ? args[0] : "echo";
        if(mode=="hold") { Thread.Sleep(60000); return 0; }
        if(mode=="hang") { using(Process self=Process.GetCurrentProcess()) { Record(args[1],args[2],self); } Console.Out.Write("before hang"); Console.Error.Write("hang diagnostic"); Thread.Sleep(60000); return 0; }
        if(mode=="hold-stdout" || mode=="hold-stderr") { HoldPipe(mode,args[1],args[2]); Console.Out.Write("parent stdout"); Console.Error.Write("parent stderr"); return 0; }
        if(mode=="flood") { Console.Out.Write(new string('O',400000)); Console.Error.Write(new string('E',200000)); return 0; }
        string name=Path.GetFileNameWithoutExtension(Exe), dir=Path.GetDirectoryName(Exe);
        bool version=Array.IndexOf(args,"-version")>=0, encoders=Array.IndexOf(args,"-encoders")>=0;
        if ((version && dir.IndexOf("version-hang",StringComparison.Ordinal)>=0) || (encoders && dir.IndexOf("encoder-hang",StringComparison.Ordinal)>=0) || (!version && name=="ffprobe" && dir.IndexOf("probe-hang",StringComparison.Ordinal)>=0)) {
            Thread.Sleep(60000); return 0;
        }
        if(version) { Console.Out.Write(name+" version S03-independent-fixture\n"); return 0; }
        if(encoders) { Console.Out.Write(" A....D libmp3lame MP3\n"); return 0; }
        if(name=="ffprobe") {
            if(dir.IndexOf("probe-held",StringComparison.Ordinal)>=0) HoldPipe("hold-stdout",Path.Combine(dir,"probe-descendant.json"),File.ReadAllText(Path.Combine(dir,"fixture-token.txt")));
            if(dir.IndexOf("probe-delayed",StringComparison.Ordinal)>=0) Thread.Sleep(1500);
            Console.Out.Write("{\"streams\":[{\"index\":0,\"codec_type\":\"audio\",\"duration\":\"2.0\"}],\"format\":{\"tags\":{\"title\":\"Synthetic\"}}}"); return 0;
        }
        Console.Out.Write(new JavaScriptSerializer().Serialize(args)); return 0;
    }
}
'@
    $compiled = Invoke-AudioNativeProcess -ExecutablePath $compiler -Arguments @('/nologo', '/target:exe', '/reference:System.Web.Extensions.dll', ('/out:' + $child), $childSource) -TimeoutMilliseconds 20000 -Operation 'compile independent fixture'
    Assert-Success $compiled
    $fixtures.Add($childSource); $fixtures.Add($child)
    # A separate exact retained process must survive every application timeout.
    $sentinelInfo = New-Object Diagnostics.ProcessStartInfo
    $sentinelInfo.FileName = $child; $sentinelInfo.Arguments = 'hold'; $sentinelInfo.UseShellExecute = $false
    $sentinel = New-Object Diagnostics.Process; $sentinel.StartInfo = $sentinelInfo
    Assert-True $sentinel.Start() 'Independent sentinel must start.'
    $sentinelHandle = $sentinel.Handle; $retainedProcesses.Add($sentinel)
    Assert-True ($sentinelHandle -ne [IntPtr]::Zero) 'Sentinel requires retained process handle.'
    $toolPairs = @{}
    foreach ($mode in @('version-hang-ffmpeg', 'version-hang-ffprobe', 'encoder-hang', 'probe-hang', 'probe-delayed', 'probe-held', 'normal')) {
        $dir = Join-Path $testRoot $mode; [IO.Directory]::CreateDirectory($dir) | Out-Null
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            $copy = Join-Path $dir $name; Copy-Item -LiteralPath $child -Destination $copy; $fixtures.Add($copy)
        }
        $toolPairs[$mode] = $dir
    }
    $pipeToken = Join-Path $toolPairs['probe-held'] 'fixture-token.txt'; Write-NewText $pipeToken $ownerToken; $fixtures.Add($pipeToken)
    $audio = Join-Path $testRoot "2026-10-17 - Synthetic [literal] O'Brien.wav"
    $createdAudio = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=44100:duration=2','-c:a','pcm_s16le',$audio) -Operation 'synthetic source creation'
    Assert-Success $createdAudio; $fixtures.Add($audio)
    $report.synthetic_before = Get-Inventory $fixtures.ToArray() $testRoot
    Invoke-Case 'never-exiting-child-times-out-with-owned-release' {
        param($case)
        $identity = Join-Path $testRoot 'hung-child.json'; $identityFiles.Add($identity)
        # A new compiled fixture can take longer than 500ms to start on a cold
        # CI host. This operation budget permits startup without relaxing EOF,
        # diagnostic, owned-release or independently retained sentinel checks.
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('hang',$identity,$ownerToken) -TimeoutMilliseconds 2000 -Operation 'S03 never-exiting child'
        $case['fixture_ready_marker_created'] = Test-Path -LiteralPath $identity -PathType Leaf
        Assert-Timeout $result 2000
        Assert-True $case['fixture_ready_marker_created'] 'The independently compiled child must reach its hang readiness marker before the deadline.'
        Assert-True ($result.PipeDrainCompleted -and $result.Stdout -ceq 'before hang' -and $result.Stderr -ceq 'hang diagnostic') 'Timeout retains independently captured output and proves both EOFs after owned child kill.'
        Assert-True (-not $sentinel.HasExited) 'Unrelated sentinel must survive timeout.'
        $case['native_status'] = $result.Status; $case['elapsed_ms'] = $result.ElapsedMilliseconds; $case['unrelated_process_survived'] = $true
    }
    foreach ($stream in @('stdout','stderr')) {
        Invoke-Case ('exited-parent-with-held-' + $stream + '-reports-timeout') {
            param($case)
            $identity = Join-Path $testRoot ('held-' + $stream + '.json'); $identityFiles.Add($identity)
            $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @(('hold-' + $stream),$identity,$ownerToken) -TimeoutMilliseconds 2000 -PipeDrainTimeoutMilliseconds 300 -Operation ('S03 held ' + $stream)
            Assert-Timeout $result 2000 $false 300
            Assert-True ($result.ExitCode -eq 0 -and -not $result.PipeDrainCompleted -and $result.Stdout -ceq 'parent stdout' -and $result.Stderr -ceq 'parent stderr') 'Exited child with inherited writer must time out, preserve both streams and withhold complete release proof.'
            $descendant = Get-ExactFixtureProcess $identity
            Assert-True (-not $descendant.HasExited -and -not $sentinel.HasExited) 'Runtime must leave exact fixture descendant and unrelated sentinel alive.'
            Stop-ExactFixtureProcess $descendant
            $uncertainOperations.Remove('S03 held ' + $stream) | Out-Null
            $case['held_stream'] = $stream; $case['owned_parent_exit'] = 0; $case['conservative_process_release'] = $false
            $case['descendant_survived_runtime'] = $true; $case['descendant_exact_cleanup'] = $true; $case['elapsed_ms'] = $result.ElapsedMilliseconds
        }
    }
    Invoke-Case 'pipe-drain-has-separate-bound-without-operation-deadline' {
        param($case)
        $identity = Join-Path $testRoot 'held-drain-only.json'; $identityFiles.Add($identity)
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('hold-stdout',$identity,$ownerToken) -PipeDrainTimeoutMilliseconds 300 -Operation 'S03 pipe-only bound'
        Save-NativeResult $result
        Assert-True ($result.Status -ceq 'Timeout' -and $result.ExitCode -eq 0 -and $result.TimeoutMilliseconds -eq 0 -and -not $result.PipeDrainCompleted -and -not $result.ProcessReleased -and $result.ElapsedMilliseconds -lt 8300) 'An exited parent with a hung inherited pipe must have bounded drain even when its operation has no runtime ceiling.'
        $descendant = Get-ExactFixtureProcess $identity
        Assert-True (-not $descendant.HasExited) 'Pipe-only handling must not kill the independently owned descendant.'
        Stop-ExactFixtureProcess $descendant
        $uncertainOperations.Remove('S03 pipe-only bound') | Out-Null
        $case['native_status'] = $result.Status; $case['deadline_ms'] = 0; $case['drain_bound_ms'] = 300; $case['descendant_exact_cleanup'] = $true
    }
    foreach ($mode in @('version-hang-ffmpeg','version-hang-ffprobe','encoder-hang')) {
        Invoke-Case ('bounded-startup-' + $mode) {
            param($case)
            $dir = $toolPairs[$mode]
            $mockFfmpeg = if ($mode -ceq 'version-hang-ffprobe') { Join-Path $toolPairs['normal'] 'ffmpeg.exe' } else { Join-Path $dir 'ffmpeg.exe' }
            $mockFfprobe = if ($mode -ceq 'version-hang-ffmpeg') { Join-Path $toolPairs['normal'] 'ffprobe.exe' } else { Join-Path $dir 'ffprobe.exe' }
            $watch = [Diagnostics.Stopwatch]::StartNew(); $message = $null
            try { Assert-ToolPrerequisites -FfmpegPath $mockFfmpeg -FfprobePath $mockFfprobe -TimeoutMilliseconds 2000 | Out-Null }
            catch { $message = $_.Exception.Message }
            $watch.Stop()
            $case['diagnostic'] = if ($null -eq $message) { $null } else { $message.Replace($testRoot,'<OWNED_TEMP>') }
            $case['elapsed_ms'] = $watch.ElapsedMilliseconds; $case['configured_deadline_ms'] = 2000
            Assert-True ($null -ne $message -and $message -match 'Timeout|timed out' -and $message -match 'ffmpeg|ffprobe' -and $watch.ElapsedMilliseconds -lt 10000) 'Version/capability hang must report executable/Timeout within bounded startup time.'
            Assert-True (-not $sentinel.HasExited) 'Startup timeout must preserve unrelated sentinel.'
        }
    }
    Invoke-Case 'media-probe-timeout-is-distinct-and-actionable' {
        param($case)
        $info = Get-AudioMediaInfo -Path $audio -FfprobePath (Join-Path $toolPairs['probe-hang'] 'ffprobe.exe') -ProbeTimeoutSeconds 1
        Assert-Timeout $info.NativeResult 1000
        Assert-True ($info.Status -ceq 'Timeout' -and $info.TitleStatus -ceq 'Unknown' -and $info.Error -match 'ProbeTimeoutSeconds|increase|retry|deadline') 'Probe timeout must remain distinct from corruption and explain an actionable retry/override.'
        $case['probe_status'] = $info.Status; $case['diagnostic'] = $info.Error.Replace($testRoot,'<OWNED_TEMP>'); $case['deadline_ms'] = $info.NativeResult.TimeoutMilliseconds
    }
    Invoke-Case 'media-probe-deadline-override-allows-slow-valid-probe' {
        param($case)
        $probe = Join-Path $toolPairs['probe-delayed'] 'ffprobe.exe'
        $short = Get-AudioMediaInfo -Path $audio -FfprobePath $probe -ProbeTimeoutSeconds 1
        Assert-Timeout $short.NativeResult 1000
        $long = Get-AudioMediaInfo -Path $audio -FfprobePath $probe -ProbeTimeoutSeconds 3
        Assert-Success $long.NativeResult
        Assert-True ($long.Status -ceq 'Success' -and $long.Title -ceq 'Synthetic' -and $long.NativeResult.TimeoutMilliseconds -eq 3000 -and $long.NativeResult.ElapsedMilliseconds -ge 1500) 'Advanced probe deadline must allow the same slow valid operation to succeed.'
        $normal = Get-AudioMediaInfo -Path $audio -FfprobePath (Join-Path $toolPairs['normal'] 'ffprobe.exe')
        Assert-Success $normal.NativeResult
        Assert-True ($normal.NativeResult.TimeoutMilliseconds -eq 60000) 'Default media probe deadline remains 60 seconds.'
        $case['short_status'] = $short.Status; $case['overridden_status'] = $long.Status; $case['overridden_elapsed_ms'] = $long.NativeResult.ElapsedMilliseconds; $case['default_deadline_ms'] = 60000
    }
    foreach ($mode in @('probe-hang','probe-held')) {
        Invoke-Case ('output-probe-timeout-transaction-' + $mode) {
            param($case)
            $outputRoot = Join-Path $testRoot ('Output ' + $mode); [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
            $final = Join-Path $outputRoot '2026-10-17 - Synthetic.mp3'
            if ($mode -ceq 'probe-held') { $identity = Join-Path $toolPairs[$mode] 'probe-descendant.json'; $identityFiles.Add($identity) }
            $transaction = Invoke-AudioOutputTransaction -OutputPath $final -OutputRoot $outputRoot -SourcePath $audio -SourceDurationSeconds 2 `
                -FfmpegPath $ffmpeg -FfprobePath (Join-Path $toolPairs[$mode] 'ffprobe.exe') -ProbeTimeoutSeconds 1 `
                -EncodeArguments @('-nostdin','-v','error','-i',$audio,'-map','0:a:0','-c:a','libmp3lame','-b:a','64k')
            Assert-Success $transaction.EncoderResult
            Assert-True ($transaction.Status -ceq 'Timeout' -and $transaction.ValidationResult.Status -ceq 'Timeout' -and -not (Test-Path -LiteralPath $final)) 'Output probe timeout must propagate through validation/transaction and never publish a final-looking output.'
            $released = $mode -ceq 'probe-hang'
            Assert-Timeout $transaction.ValidationResult.ProbeResult 1000 $released
            Assert-True ([IO.Path]::GetFileName($transaction.WorkingPath) -cmatch '^\.AudioFileForPhone-[a-f0-9]{32}\.partial$') 'Only a uniquely staged partial path may exist before validated publication.'
            if ($released) {
                Assert-True (-not (Test-Path -LiteralPath $transaction.WorkingPath) -and [string]::IsNullOrEmpty($transaction.CleanupError)) 'Proved native release must permit exact partial cleanup after probe timeout.'
            } else {
                Assert-True ($transaction.ValidationResult.ProbeResult.ExitCode -eq 0) 'Observed parent exit zero is required before exact descendant cleanup can restore fixture release proof.'
                Assert-True ((Test-Path -LiteralPath $transaction.WorkingPath -PathType Leaf) -and -not [string]::IsNullOrEmpty($transaction.CleanupError)) 'Unproved native pipe release must retain its incomplete working path.'
                $descendant = Get-ExactFixtureProcess $identity
                Assert-True (-not $descendant.HasExited) 'Application must preserve independently owned pipe holder.'
                Stop-ExactFixtureProcess $descendant
                $uncertainOperations.Remove('Output media probe') | Out-Null
            }
            $case['transaction_status'] = $transaction.Status; $case['probe_timeout_ms'] = $transaction.ValidationResult.ProbeResult.TimeoutMilliseconds
            $case['no_final_publication'] = $true; $case['working_partial_retained'] = -not $released; $case['probe_process_released'] = $released
        }
    }
    Invoke-Case 'pre-requested-cancellation-precedes-tiny-deadline' {
        param($case)
        $context = New-AudioCancellationContext
        try {
            $context.Request()
            $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('hold') -TimeoutMilliseconds 1 -Cancellation $context -Operation 'S03 pre-cancelled deadline'
            Save-NativeResult $result
            Assert-True ($result.Status -ceq 'Cancelled' -and $result.ProcessReleased -and $context.ActiveProcessId -eq 0) 'Requested cancellation must stay Cancelled and launch no child even with an expired short deadline.'
            $case['native_status'] = $result.Status; $case['active_child_pid'] = $context.ActiveProcessId
        } finally { $context.Dispose() }
    }
    Invoke-Case 'active-cancellation-remains-distinct-before-deadline' {
        param($case)
        $context = New-AudioCancellationContext
        $timer = New-Object AudioFileForPhoneS03.RequestTimer($context, 250)
        try {
            $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('hold') -TimeoutMilliseconds 1500 -Cancellation $context -Operation 'S03 active cancellation'
            Save-NativeResult $result
            Assert-True ($result.Status -ceq 'Cancelled' -and $result.ProcessReleased -and $result.PipeDrainCompleted -and $context.ActiveProcessId -eq 0 -and $result.ElapsedMilliseconds -lt 1500) 'Active cancellation must release the child/streams, clear its PID and remain distinct from Timeout.'
            Assert-True (-not $sentinel.HasExited) 'Cancellation must preserve unrelated sentinel.'
            $case['native_status'] = $result.Status; $case['elapsed_ms'] = $result.ElapsedMilliseconds; $case['unrelated_process_survived'] = $true
        } finally { $timer.Dispose(); $context.Dispose() }
    }
    Invoke-Case 'normal-argv-output-size-and-legacy-unlimited-default' {
        param($case)
        $values = @('echo','','quoted "text"',"O'Brien [literal] &",'trailing\',([string][char]0x00E4 + [char]0x65E5))
        $normal = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments $values
        Assert-Success $normal
        $captured = $normal.Stdout | ConvertFrom-Json
        Assert-True (($captured | ConvertTo-Json -Compress) -ceq ($values | ConvertTo-Json -Compress)) 'Existing Windows quoting and Unicode/empty arguments must remain exact.'
        Assert-True ($normal.TimeoutMilliseconds -eq 0) 'Legacy direct native calls keep the unlimited operation default.'
        $flood = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('flood') -TimeoutMilliseconds 3000 -Operation 'S03 stream caps' -MaxStdoutChars 113 -MaxStderrChars 227
        Assert-Success $flood
        Assert-True ($flood.Stdout.Length -eq 113 -and $flood.Stderr.Length -eq 227 -and $flood.StdoutTruncated -and $flood.StderrTruncated -and $flood.StdoutTotalChars -eq 400000 -and $flood.StderrTotalChars -eq 200000) 'Deadline transport must retain independent stream caps while fully draining both pipes.'
        $case['argv_exact'] = $true; $case['legacy_deadline_ms'] = 0; $case['stdout_total'] = $flood.StdoutTotalChars; $case['stderr_total'] = $flood.StderrTotalChars
    }
    Invoke-Case 'real-progressing-encode-and-complete-decode-exceed-short-bound' {
        param($case)
        # A successful bounded startup followed by >1s real media work proves the
        # startup ceiling cannot leak into ordinary encode/full decode calls.
        $tools = Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe -TimeoutMilliseconds 1000
        Assert-True (-not [string]::IsNullOrWhiteSpace($tools.Ffmpeg.Version)) 'Real bounded prerequisites must succeed.'
        $outputRoot = Join-Path $testRoot 'Output [literal]'; [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
        $final = Join-Path $outputRoot '2026-10-17 - Synthetic.mp3'
        $script:encodeProgressCount = 0
        $transaction = Invoke-AudioOutputTransaction -OutputPath $final -OutputRoot $outputRoot -SourcePath $audio -SourceDurationSeconds 2 -FfmpegPath $ffmpeg -FfprobePath $ffprobe `
            -EncodeArguments @('-nostdin','-v','error','-re','-i',$audio,'-map','0:a:0','-c:a','libmp3lame','-b:a','64k') -ProgressCallback { param($progress) if ($progress.Phase -ceq 'Encoding') { $script:encodeProgressCount++ } }
        Assert-True ($transaction.Status -ceq 'Success' -and (Test-Path -LiteralPath $final -PathType Leaf)) ('Real transaction failed: ' + $transaction.Error)
        Assert-Success $transaction.EncoderResult; Assert-Success $transaction.ValidationResult.DecodeResult
        Assert-True ($transaction.EncoderResult.TimeoutMilliseconds -eq 0 -and $transaction.EncoderResult.ElapsedMilliseconds -gt 1000 -and $script:encodeProgressCount -gt 1 -and $transaction.ValidationResult.DecodeResult.TimeoutMilliseconds -eq 0) 'Progressing real encode must exceed startup deadline and full production decode must keep no short runtime ceiling.'
        $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-re','-i',$final,'-map','0:a:0','-progress','pipe:1','-f','null','-') -Operation 'S03 paced complete decode'
        Assert-Success $decode
        Assert-True ($decode.TimeoutMilliseconds -eq 0 -and $decode.ElapsedMilliseconds -gt 1000 -and $decode.Stdout -match 'progress=end') 'Real complete decode must also run longer than startup deadline and reach progress=end.'
        $case['startup_deadline_ms'] = 1000; $case['encode_elapsed_ms'] = $transaction.EncoderResult.ElapsedMilliseconds
        $case['encoding_progress_observations'] = $script:encodeProgressCount; $case['production_validation_status'] = $transaction.ValidationResult.Status
        $case['complete_decode_elapsed_ms'] = $decode.ElapsedMilliseconds; $case['complete_decode_deadline_ms'] = $decode.TimeoutMilliseconds
    }
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    # Direct retained handles are always exact owned processes. Marker-based
    # survivors require matching token, executable and creation time first.
    foreach ($process in $retainedProcesses) {
        try { Stop-ExactFixtureProcess $process }
        catch { $fixtureReleaseProved = $false; $report['retained_process_cleanup_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    }
    foreach ($identityPath in $identityFiles) {
        if (Test-Path -LiteralPath $identityPath -PathType Leaf) {
            try {
                $identity = Get-Content -LiteralPath $identityPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $existing = Get-Process -Id ([int]$identity.pid) -ErrorAction SilentlyContinue
                if ($null -ne $existing) {
                    $existing.Dispose()
                    $exact = Get-ExactFixtureProcess $identityPath
                    Stop-ExactFixtureProcess $exact
                }
            } catch { $fixtureReleaseProved = $false; $report['identity_cleanup_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
        }
    }
    if ($uncertainOperations.Count -gt 0) { $fixtureReleaseProved = $false }
    $report['unproved_native_operations'] = @($uncertainOperations)
    $report.native_runs = $nativeRuns.ToArray(); $report.descendant_release_proved = $fixtureReleaseProved
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository source bytes changed during focused tests.'
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True $report.synthetic_unchanged 'Owned synthetic source/runtime/fixture bytes changed.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['hash_verification_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        Assert-True $fixtureReleaseProved 'Cleanup refused because exact fixture process release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay in exact directly owned TEMP tree.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires unchanged create-new owner marker.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 18)
}
Write-Host "$($report.task) short operations: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
