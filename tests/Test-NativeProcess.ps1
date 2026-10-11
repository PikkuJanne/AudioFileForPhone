<#
T05 native execution and explicit probe evidence on the active Windows shell.
Only short synthetic media and a compiled, disposable test child are used.
Every fixture, copied application and diagnostic stays in an exclusively owned
TEMP tree. The selected evidence file is create-new; historical reports survive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-N-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t05-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$originalPath = $env:PATH
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat',
    'tests/Test-NativeProcess.ps1', 'tests/Test-Preflight.ps1', 'tests/Test-AudioFileForPhone.ps1',
    'tests/Test-BaselineCharacterization.ps1', 'tests/Invoke-IsolatedBaseline.ps1', 'tests/Test-OutputParent.ps1')
$exitCode = 1
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T05|T08|T09|T11)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T05/T08/T09/T11-<label>.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a new label to preserve prior evidence.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'native_process_and_probe'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    cases = @(); cleanup_verified = $false; status = 'fail'; error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Get-FixtureInventory {
    return @($fixtures | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point in a test path or ancestor.'
        $item = $item.Parent
    }
}

function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside the owned tree.'
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}

function New-ExclusiveDirectory {
    param([string]$Path)
    if (-not ('AudioFileForPhoneT05.NativeDirectory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhoneT05 {
    public static class NativeDirectory {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr securityAttributes);
    }
}
'@
    }
    if (-not [AudioFileForPhoneT05.NativeDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) {
        throw "Exclusive test root reservation failed (Win32 $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
    }
}

function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' }
    finally { $report.cases += [pscustomobject]$case }
}

function Assert-NativeSuccess {
    param($Result, [string]$Operation)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ExitCode -eq 0) "$Operation must complete successfully: $($Result.Status)/$($Result.ExitCode) $($Result.Stderr)"
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Get-ProbeJson {
    param([string]$Path)
    $native = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v', 'error', '-print_format', 'json', '-show_format', '-show_streams', $Path)
    Assert-NativeSuccess $native 'Real ffprobe'
    return $native.Stdout | ConvertFrom-Json
}

try {
    Assert-NoReparse $evidenceParent
    Assert-NoReparse $tempParent
    $report.source_before = Get-SourceInventory
    New-ExclusiveDirectory $testRoot
    $ownedRootCreated = $true
    $report.temp_exclusively_reserved = $true
    $marker = New-Object IO.FileStream($ownerFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($ownerToken); $marker.Write($bytes, 0, $bytes.Length) }
    finally { $marker.Dispose() }
    $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'App [literal]'
    $inputRoot = Join-Path $testRoot "Input [literal] O'Brien & Unicode"
    $outputRoot = Join-Path $testRoot "Output [literal] O'Brien & Unicode"
    foreach ($dir in @($appRoot, $inputRoot, $outputRoot)) { [IO.Directory]::CreateDirectory($dir) | Out-Null }
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) {
        $source = Join-Path $projectRoot $name
        $copy = Join-Path $appRoot $name
        Copy-Item -LiteralPath $source -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $source).Hash -ceq (Get-FileHash -LiteralPath $copy).Hash) 'Application/helper copies must preserve source bytes.'
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($copy, [ref]$tokens, [ref]$errors) | Out-Null
        Assert-True ($errors.Count -eq 0) 'Copied application/helper must parse.'
    }
    $report.copied_bytes_unchanged = $true
    . (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
    $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $tools = Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe
    foreach ($tool in @(@{ name = 'ffmpeg'; path = $ffmpeg; detail = $tools.Ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe; detail = $tools.Ffprobe })) {
        Assert-True ($tool.detail.Path -ceq $tool.path -and -not [string]::IsNullOrWhiteSpace($tool.detail.Version)) 'Prerequisite result must return exact absolute path/version.'
        $report[$tool.name] = [ordered]@{ path = $tool.detail.Path; version = $tool.detail.Version; sha256 = (Get-FileHash -LiteralPath $tool.path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }

    # csc.exe is the installed Windows .NET Framework compiler. No generated
    # binary or raw child diagnostics leave the exclusively owned TEMP tree.
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    Assert-True (Test-Path -LiteralPath $compiler -PathType Leaf) 'Installed Windows .NET Framework C# compiler is required.'
    $childSource = Join-Path $testRoot 'NativeChild.cs'
    $child = Join-Path $testRoot 'NativeChild.exe'
    [IO.File]::WriteAllText($childSource, @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
class NativeChild {
    static int Main(string[] args) {
        Console.OutputEncoding = new UTF8Encoding(false);
        string name = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        string directory = Path.GetDirectoryName(Environment.GetCommandLineArgs()[0]);
        if (Array.IndexOf(args, "-version") >= 0) {
            if (directory.IndexOf("version-failure", StringComparison.Ordinal) >= 0) { Console.Error.Write("VERSION_FAILURE"); return 13; }
            Console.Write((directory.IndexOf("unsupported", StringComparison.Ordinal) >= 0 ? "unsupported" : name) + " version T05-native-child-1\n");
            return 0;
        }
        if (Array.IndexOf(args, "-encoders") >= 0) {
            Console.Write(directory.IndexOf("no-lame", StringComparison.Ordinal) >= 0 ? " A..... aac AAC\n" : " A....D libmp3lame MP3\n"); return 0;
        }
        string mode = args.Length > 0 ? args[0] : "capture";
        if (name == "ffprobe") {
            string path = args[args.Length - 1];
            if (path.IndexOf("nonzero", StringComparison.Ordinal) >= 0) { Console.Error.Write("PROBE_FAILURE"); return 9; }
            if (path.IndexOf("invalid-json", StringComparison.Ordinal) >= 0) { Console.Write("{ invalid json"); return 0; }
            if (path.IndexOf("empty-output", StringComparison.Ordinal) >= 0) { return 0; }
            if (path.IndexOf("whitespace-output", StringComparison.Ordinal) >= 0) { Console.Write(" \t\r\n "); return 0; }
            if (path.IndexOf("truncated", StringComparison.Ordinal) >= 0) { Console.Write(new string('x', 1100000)); return 0; }
            if (path.IndexOf("wrong-shape", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":\"invalid\",\"format\":{}}"); return 0; }
            if (path.IndexOf("singleton-array", StringComparison.Ordinal) >= 0) { Console.Write("[{\"streams\":[{\"index\":0,\"codec_type\":\"audio\"}],\"format\":{}}]"); return 0; }
            if (path.IndexOf("bad-tags", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[{\"index\":0,\"codec_type\":\"audio\"}],\"format\":{\"tags\":{\"title\":123}}}"); return 0; }
            if (path.IndexOf("no-audio", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[],\"format\":{}}"); return 0; }
            if (path.IndexOf("multi", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[{\"index\":1,\"codec_type\":\"audio\"},{\"index\":2,\"codec_type\":\"audio\"}],\"format\":{}}"); return 0; }
            if (path.IndexOf("video", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[{\"index\":0,\"codec_type\":\"video\"}],\"format\":{}}"); return 0; }
            if (path.IndexOf("bad-index", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[{\"index\":-1,\"codec_type\":\"audio\"}],\"format\":{}}"); return 0; }
            if (path.IndexOf("no-title", StringComparison.Ordinal) >= 0) { Console.Write("{\"streams\":[{\"index\":4,\"codec_type\":\"audio\",\"tags\":{}}],\"format\":{\"tags\":{}}}"); return 0; }
            Console.Write("{\"streams\":[{\"index\":4,\"codec_type\":\"audio\",\"tags\":{\"title\":\"stream title\"}}],\"format\":{\"tags\":{\"title\":\"container title\"}}}");
            return 0;
        }
        if (mode == "exit7") { Console.Out.Write("OUT-seven"); Console.Error.Write("ERR-seven"); return 7; }
        if (mode == "normal-stderr") { Console.Error.Write("ordinary native diagnostic"); return 0; }
        if (mode == "alternating" || mode == "concurrent") {
            string outBlock = new string('O', 8192), errBlock = new string('E', 8192);
            if (mode == "concurrent") {
                Thread worker = new Thread(delegate() { for (int i = 0; i < 300; i++) Console.Error.Write(errBlock); });
                worker.Start(); for (int i = 0; i < 300; i++) Console.Out.Write(outBlock); worker.Join();
            } else { for (int i = 0; i < 300; i++) { Console.Out.Write(outBlock); Console.Error.Write(errBlock); } }
            return 7;
        }
        Console.Out.Write(new JavaScriptSerializer().Serialize(args)); return 0;
    }
}
'@, (New-Object Text.UTF8Encoding($false)))
    $compile = Invoke-AudioNativeProcess -ExecutablePath $compiler -Arguments @('/nologo', '/target:exe', '/reference:System.Web.Extensions.dll', ('/out:' + $child), $childSource)
    Assert-NativeSuccess $compile 'Disposable native child compilation'
    Assert-True (Test-Path -LiteralPath $child -PathType Leaf) 'Compilation must create the owned native child.'
    $report['child_compiler'] = [ordered]@{ path = $compiler; sha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash.ToLowerInvariant(); generated_binary_committed = $false }

    $unicode = ([string][char]0x00e4) + ([string][char]0x00f6) + ([string][char]0x96ea) + ([string][char]0x03a9)
    $exactArgs = [string[]]@('capture', '', ' ', 'two words', '[literal]', "O'Brien", 'x & y', 'say "quoted"', $unicode,
        'C:\space path\', 'C:\ends\\', '\"', '\\"', 'a\\\"b', '$(should not execute)', '; not evaluated', "tab`tbetween", "line`nbreak")
    Invoke-Case 'exact-argv-special-empty-backslash-unicode' {
        param($case)
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments $exactArgs
        Assert-NativeSuccess $result 'Exact argv capture'
        $captured = ConvertFrom-Json -InputObject $result.Stdout
        Assert-True ($captured.Count -eq $exactArgs.Count) 'Every argv element, including empty strings, must arrive.'
        for ($i = 0; $i -lt $exactArgs.Count; $i++) { Assert-True ($captured[$i] -ceq $exactArgs[$i]) "Argument $i must arrive exactly." }
        Assert-True ($result.ExecutablePath -ceq $child -and ($result.Arguments | ConvertTo-Json -Compress) -ceq ($exactArgs | ConvertTo-Json -Compress)) 'Result must retain exact executable/arguments.'
        $case['captured_argv'] = $captured; $case['duration_ms'] = $result.DurationMilliseconds
    }
    Invoke-Case 'ffmpeg-nostdin-argv' {
        param($case)
        $dir = Join-Path $testRoot 'ffmpeg-capture'; [IO.Directory]::CreateDirectory($dir) | Out-Null
        $captureFfmpeg = Join-Path $dir 'ffmpeg.exe'; Copy-Item -LiteralPath $child -Destination $captureFfmpeg
        $result = Invoke-AudioNativeProcess -ExecutablePath $captureFfmpeg -Arguments @('-nostdin', 'capture', ('artist=quote " and & ' + $unicode))
        Assert-NativeSuccess $result 'FFmpeg argv capture'
        $argv = ConvertFrom-Json -InputObject $result.Stdout
        Assert-True ($argv[0] -ceq '-nostdin' -and $argv[2] -ceq ('artist=quote " and & ' + $unicode)) 'FFmpeg receives explicit -nostdin and intact metadata.'
        $case['captured_argv'] = $argv
    }
    Invoke-Case 'immediate-exit-status-and-both-streams' {
        param($case)
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('exit7')
        Assert-True ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 7 -and $result.Stdout -ceq 'OUT-seven' -and $result.Stderr -ceq 'ERR-seven') 'Native nonzero exit status and stdout/stderr must remain distinct.'
        $case['exit_code'] = $result.ExitCode
    }
    Invoke-Case 'ordinary-stderr-is-success-and-caller-exit-unchanged' {
        param($case)
        $state = & {
            $LASTEXITCODE = 29
            $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('normal-stderr')
            [pscustomobject]@{ result = $result; caller_exit = $LASTEXITCODE }
        }
        Assert-NativeSuccess $state.result 'Native ordinary stderr'
        Assert-True ($state.result.Stderr -ceq 'ordinary native diagnostic' -and $state.caller_exit -eq 29) 'Ordinary stderr must not fail; caller native exit state must remain unchanged.'
        $case['caller_exit'] = $state.caller_exit; $case['stderr'] = $state.result.Stderr
    }
    foreach ($mode in @('alternating', 'concurrent')) {
        Invoke-Case ('bounded-dual-stream-flood-' + $mode) {
            param($case)
            $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @($mode)
            Assert-True ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 7) 'Dual-stream flood must finish and preserve exit 7.'
            Assert-True ($result.Stdout.Length -eq 1048576 -and $result.Stderr.Length -eq 65536 -and $result.StdoutTruncated -and $result.StderrTruncated) 'Both retained streams must stop exactly at their default caps.'
            Assert-True ($result.Stdout -cmatch '^O+$' -and $result.Stderr -cmatch '^E+$') 'Captured streams must preserve their own flood data.'
            Assert-True ($result.StdoutTotalChars -eq 2457600 -and $result.StderrTotalChars -eq 2457600) 'Both pipes must be fully drained after truncation.'
            $case['exit_code'] = $result.ExitCode; $case['stdout_retained'] = $result.Stdout.Length; $case['stderr_retained'] = $result.Stderr.Length
            $case['stdout_total'] = $result.StdoutTotalChars; $case['stderr_total'] = $result.StderrTotalChars; $case['duration_ms'] = $result.DurationMilliseconds
        }
    }
    Invoke-Case 'custom-zero-and-small-retention-caps' {
        param($case)
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('exit7') -MaxStdoutChars 0 -MaxStderrChars 4
        Assert-True ($result.Stdout -ceq '' -and $result.Stderr -ceq 'ERR-' -and $result.StdoutTruncated -and $result.StderrTruncated -and $result.ExitCode -eq 7) 'Configured zero/small diagnostic limits must be honored.'
        $case['stdout_retained'] = 0; $case['stderr_retained'] = $result.Stderr.Length
    }
    Invoke-Case 'embedded-nul-argument-is-rejected' {
        param($case)
        $result = Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('capture', ('before' + [char]0 + 'after'))
        Assert-True ($result.Status -ceq 'StartFailed' -and $null -eq $result.ExitCode -and $result.Error -match 'NUL|null|zero') 'Unrepresentable embedded NUL argv must be rejected before native execution.'
        $case['actual_status'] = $result.Status
    }
    Invoke-Case 'process-resource-handles-released' {
        param($case)
        for ($i = 0; $i -lt 8; $i++) { Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('exit7') | Out-Null }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        $self = [Diagnostics.Process]::GetCurrentProcess()
        try {
            $self.Refresh(); $before = $self.HandleCount
            for ($i = 0; $i -lt 40; $i++) { Invoke-AudioNativeProcess -ExecutablePath $child -Arguments @('exit7') | Out-Null }
            $self.Refresh(); $immediate = $self.HandleCount
            # NativeCapture has already joined both readers. Allow completed
            # worker threads to retire without invoking finalizers.
            Start-Sleep -Milliseconds 500
            $self.Refresh(); $after = $self.HandleCount
            $case['calls_after_warmup'] = 40; $case['handle_count_before'] = $before; $case['handle_count_immediate'] = $immediate
            $case['handle_count_after'] = $after; $case['worker_settle_ms'] = 500; $case['allowed_handle_growth'] = 16
            Assert-True (($after - $before) -le 16) 'Repeated child calls must release owned process/pipe handles without awaiting garbage collection.'
        } finally { $self.Dispose() }
        $renamed = $child + '.released'; Move-Item -LiteralPath $child -Destination $renamed; Move-Item -LiteralPath $renamed -Destination $child
        $case['child_executable_rename_after_exit'] = $true
    }
    $fakeExe = Join-Path $testRoot 'Non-executable.exe'; [IO.File]::WriteAllText($fakeExe, 'T05 synthetic invalid executable.')
    foreach ($sample in @(
        @{ name = 'missing-executable'; path = (Join-Path $testRoot 'Missing.exe'); status = 'MissingExecutable' },
        @{ name = 'directory-executable'; path = $inputRoot; status = 'InvalidExecutablePath' },
        @{ name = 'relative-executable'; path = 'NativeChild.exe'; status = 'InvalidExecutablePath' },
        @{ name = 'non-executable-file'; path = $fakeExe; status = 'StartFailed' })) {
        Invoke-Case $sample.name {
            param($case)
            $result = Invoke-AudioNativeProcess -ExecutablePath $sample.path -Arguments @()
            Assert-True ($result.Status -ceq $sample.status -and $null -eq $result.ExitCode -and -not [string]::IsNullOrWhiteSpace($result.Error)) 'Missing/invalid/failed-start results must have distinct status, no native exit and a diagnostic.'
            $case['expected_status'] = $sample.status; $case['actual_status'] = $result.Status
        }
    }
    $mockDir = Join-Path $testRoot 'mock-tools'; [IO.Directory]::CreateDirectory($mockDir) | Out-Null
    $mockFfprobe = Join-Path $mockDir 'ffprobe.exe'; Copy-Item -LiteralPath $child -Destination $mockFfprobe
    foreach ($sample in @(
        @{ name = 'nonzero'; status = 'ProbeFailed' }, @{ name = 'invalid-json'; status = 'InvalidJson' },
        @{ name = 'empty-output'; status = 'InvalidJson' }, @{ name = 'whitespace-output'; status = 'InvalidJson' },
        @{ name = 'truncated'; status = 'OutputTruncated' }, @{ name = 'wrong-shape'; status = 'InvalidProbeData' },
        @{ name = 'singleton-array'; status = 'InvalidProbeData' }, @{ name = 'bad-tags'; status = 'InvalidProbeData' },
        @{ name = 'no-audio'; status = 'NoAudio' }, @{ name = 'multi'; status = 'InvalidProbeData' },
        @{ name = 'video'; status = 'InvalidProbeData' }, @{ name = 'bad-index'; status = 'InvalidProbeData' })) {
        Invoke-Case ('probe-' + $sample.name) {
            param($case)
            $result = Get-AudioMediaInfo -Path (Join-Path $inputRoot ($sample.name + '.m4a')) -FfprobePath $mockFfprobe
            Assert-True ($result.Status -ceq $sample.status) "Probe $($sample.name) must return $($sample.status), received $($result.Status)."
            Assert-True ($result.NativeResult.Arguments -contains '-select_streams' -and $result.NativeResult.Arguments -contains 'a:0') 'Probe must explicitly request only first audio stream.'
            $case['expected_status'] = $sample.status; $case['actual_status'] = $result.Status
            $case['native_exit'] = $result.NativeResult.ExitCode
        }
    }
    foreach ($sample in @(@{ name = 'no-title'; ext = '.m4a'; title = $null; title_status = 'Absent'; source = '0' },
        @{ name = 'present-container'; ext = '.m4a'; title = 'container title'; title_status = 'Present'; source = '0' },
        @{ name = 'present-stream'; ext = '.ogg'; title = 'stream title'; title_status = 'Present'; source = '0:s:a:0' })) {
        Invoke-Case ('probe-title-' + $sample.name) {
            param($case)
            $result = Get-AudioMediaInfo -Path (Join-Path $inputRoot ($sample.name + $sample.ext)) -FfprobePath $mockFfprobe
            Assert-True ($result.Status -ceq 'Success' -and $result.TitleStatus -ceq $sample.title_status -and $result.Title -ceq $sample.title -and $result.StreamIndex -eq 4 -and $result.MetadataSource -ceq $sample.source) 'Valid probe must distinguish absent/present title and preserve container/Ogg stream precedence.'
            $case['title_status'] = $result.TitleStatus; $case['title'] = $result.Title; $case['stream_index'] = $result.StreamIndex; $case['metadata_source'] = $result.MetadataSource
        }
    }
    Invoke-Case 'probe-native-startup-failure-distinct' {
        param($case)
        $missing = Get-AudioMediaInfo -Path (Join-Path $inputRoot 'absent.m4a') -FfprobePath (Join-Path $testRoot 'AbsentProbe.exe')
        $invalid = Get-AudioMediaInfo -Path (Join-Path $inputRoot 'invalid.m4a') -FfprobePath $fakeExe
        Assert-True ($missing.Status -ceq 'MissingExecutable' -and $invalid.Status -ceq 'StartFailed') 'Probe must preserve missing/failed-start native statuses.'
        $case['missing_status'] = $missing.Status; $case['invalid_status'] = $invalid.Status
    }
    foreach ($mode in @('unsupported', 'version-failure', 'no-lame')) {
        Invoke-Case ('dependency-' + $mode) {
            param($case)
            $dir = Join-Path $testRoot $mode; [IO.Directory]::CreateDirectory($dir) | Out-Null
            $badFfmpeg = Join-Path $dir 'ffmpeg.exe'; Copy-Item -LiteralPath $child -Destination $badFfmpeg
            $message = $null
            try { Assert-ToolPrerequisites -FfmpegPath $badFfmpeg -FfprobePath $mockFfprobe | Out-Null }
            catch { $message = $_.Exception.Message }
            $expected = if ($mode -eq 'no-lame') { 'libmp3lame' } else { 'ffmpeg.*version|Invalid ffmpeg|unsupported|identity' }
            Assert-True ($null -ne $message -and $message -match $expected) 'Unsupported identity/version failure/missing encoder must reject with an explicit diagnostic.'
            $case['diagnostic'] = $message.Replace($testRoot, '<OWNED_TEMP>')
        }
    }

    # Real metadata proves the argv capture findings apply to installed FFmpeg.
    $title = 'Title "quoted" [brackets] O''Brien & ' + $unicode
    $artist = 'Artist "quoted" [brackets] O''Brien & ' + $unicode
    $album = 'Album "quoted" [brackets] O''Brien & ' + $unicode
    $audio = Join-Path $inputRoot ('2024-01-02 - Synthetic [literal] O''Brien & ' + $unicode + '.mp3')
    $created = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin', '-hide_banner', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=0.2',
        '-c:a', 'libmp3lame', '-metadata', ('title=' + $title), '-metadata', ('artist=' + $artist), '-metadata', ('album=' + $album), $audio)
    Assert-NativeSuccess $created 'Quoted Unicode synthetic MP3 creation'
    $fixtures.Add($audio)
    $multiAudio = Join-Path $testRoot 'Real multiple audio streams.m4a'
    $created = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin', '-hide_banner', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=black:s=16x16:r=5:d=0.2',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.2', '-f', 'lavfi', '-i', 'sine=frequency=880:duration=0.2', '-map', '0:v:0', '-map', '1:a:0', '-map', '2:a:0',
        '-c:v', 'mpeg4', '-c:a', 'aac', '-metadata', 'title=first audio selection', '-f', 'mp4', $multiAudio)
    Assert-NativeSuccess $created 'Synthetic video/two-audio container creation'
    $fixtures.Add($multiAudio)
    $cover = Join-Path $testRoot ('Cover [literal] O''Brien & ' + $unicode + '.png')
    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object Drawing.Bitmap(32, 32)
    try { $bitmap.Save($cover, [Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
    $fixtures.Add($cover)
    $report.synthetic_before = @(Get-FixtureInventory)
    Invoke-Case 'real-metadata-probe-and-selected-audio' {
        param($case)
        $info = Get-AudioMediaInfo -Path $audio -FfprobePath $ffprobe
        Assert-True ($info.Status -ceq 'Success' -and $info.Title -ceq $title -and $info.TitleStatus -ceq 'Present') 'Real ffprobe must preserve the quoted Unicode title.'
        $json = Get-ProbeJson $audio
        Assert-True ($json.format.tags.artist -ceq $artist -and $json.format.tags.album -ceq $album) 'Real FFmpeg must preserve exact quoted Unicode artist and album.'
        $multi = Get-AudioMediaInfo -Path $multiAudio -FfprobePath $ffprobe
        Assert-True ($multi.Status -ceq 'Success' -and $multi.StreamIndex -eq 1) 'Real ffprobe must select first audio stream by a:0 even after video and before extra audio.'
        $case['title'] = $info.Title; $case['artist'] = $json.format.tags.artist; $case['album'] = $json.format.tags.album; $case['selected_stream_index_after_video'] = $multi.StreamIndex
    }
    Invoke-Case 'real-cover-and-caller-state' {
        param($case)
        $state = & {
            $LASTEXITCODE = 31
            $validated = Get-ValidatedCoverPath -Path $cover -FfmpegPath $ffmpeg
            $validTools = Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe
            [pscustomobject]@{ path = $validated; caller_exit = $LASTEXITCODE; tools = $validTools }
        }
        Assert-True ($state.path -ceq $cover -and $state.caller_exit -eq 31) 'Native cover/tool checks must preserve caller native exit state and exact special path.'
        $case['caller_exit'] = $state.caller_exit; $case['cover_decoded'] = $true
    }
    Invoke-Case 'real-entry-quoted-unicode-metadata-full-decode-tool-log' {
        param($case)
        $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'
        $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
        $code = '$ErrorActionPreference = ''Stop''; & ' + (ConvertTo-PowerShellLiteral $scriptCopy) + ' -InputFolder ' + (ConvertTo-PowerShellLiteral $inputRoot) +
            ' -OutputParent ' + (ConvertTo-PowerShellLiteral $outputRoot) + ' -Artist ' + (ConvertTo-PowerShellLiteral $artist) + ' -Album ' + (ConvertTo-PowerShellLiteral $album) +
            ' -CoverPath ' + (ConvertTo-PowerShellLiteral $cover)
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $run = Invoke-AudioNativeProcess -ExecutablePath $shell -Arguments @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-EncodedCommand', $encoded)
        [IO.File]::WriteAllText((Join-Path $testRoot 'application.log'), $run.Stdout + "`n" + $run.Stderr)
        Assert-NativeSuccess $run 'Entry conversion'
        $outputs = @(Get-SafeTree $outputRoot | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
        Assert-True ($outputs.Count -eq 1) 'One source must produce one MP3 inside the owned output parent.'
        $json = Get-ProbeJson $outputs[0].FullName
        Assert-True ($json.format.tags.title -ceq $title -and $json.format.tags.artist -ceq $artist -and $json.format.tags.album -ceq $album) 'Entry preserves existing quoted Unicode title and exact Artist/Album overrides.'
        Assert-True (@($json.streams | Where-Object { $_.codec_type -ceq 'audio' }).Count -eq 1 -and @($json.streams | Where-Object { $_.disposition.attached_pic -eq 1 }).Count -eq 1) 'Output contains selected audio and explicit cover.'
        $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $outputs[0].FullName, '-map', '0:a:0', '-f', 'null', '-')
        Assert-NativeSuccess $decode 'Full output audio decode'
        $logs = @(Get-SafeTree $outputRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -ceq 'AudioFileForPhone_log.txt' })
        Assert-True ($logs.Count -eq 1) 'Run has exactly one log.'
        $logText = [IO.File]::ReadAllText($logs[0].FullName)
        Assert-True ($logText.Contains($ffmpeg) -and $logText.Contains($ffprobe) -and $logText.Contains($report.ffmpeg.version) -and $logText.Contains($report.ffprobe.version)) 'Run log records both absolute executable paths and verified versions.'
        $case['native_exit'] = $run.ExitCode; $case['output_sha256'] = (Get-FileHash -LiteralPath $outputs[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $case['full_audio_decode'] = $true; $case['tool_paths_versions_logged'] = $true; $case['title'] = $json.format.tags.title; $case['artist'] = $json.format.tags.artist; $case['album'] = $json.format.tags.album
    }
    $report.status = 'pass'; $exitCode = 0
}
catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
    Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    try {
        $report.source_after = Get-SourceInventory
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository application/helper/BAT/test source bytes must remain unchanged.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['source_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    try {
        $report.synthetic_after = @(Get-FixtureInventory)
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True $report.synthetic_unchanged 'Synthetic audio and cover sources must remain unchanged.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['synthetic_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    try {
        if ($ownedRootCreated -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup stays inside the exact exclusively owned TEMP root.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact create-new owner marker token.'
            Get-SafeTree $resolved | Out-Null
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Owned TEMP cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    $json = $report | ConvertTo-Json -Depth 14
    $evidence = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($json); $evidence.Write($bytes, 0, $bytes.Length) }
    finally { $evidence.Dispose() }
}
Write-Host "$($report.task) native: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
