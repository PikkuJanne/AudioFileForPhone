<#
T13 machine-record progress, transactional phase ordering and real hour-plus
audio evidence. Only synthetic sources and disposable children use one exclusive,
token-marked TEMP tree. Evidence is create-new; ordinary Music is never accessed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'T13P-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t13-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false; $descendantReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Progress.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T13|T14|T15|T16)-progress-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw "EvidencePath '$evidenceFullPath' must name fresh T13/T14/T15/T16-progress-ps51/ps7-attempt/finalN.json directly in '$evidenceParent'."
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'bounded_machine_progress_and_hour_plus_real_smoke'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    owned_temp_root = $testRoot; owner_marker_sha256 = $null
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_entry_bytes_unchanged = $false
    ordinary_music_access = $false; physical_manual_evidence = $false
    native_runs = @(); cases = @(); children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
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
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse fixture/ancestor.'
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
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse inside exact owned tree.'
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
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_)).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() } })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path); $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-OwnedNative {
    param([string]$Tool, [string[]]$NativeArguments, [object]$Parser = $null, [scriptblock]$Callback = $null,
          [object]$Duration = $null, [int]$StdoutLimit = 1048576, [int]$StderrLimit = 65536,
          [object]$Cancellation = $null, [string]$ExpectedStatus = 'Completed', [object]$ExpectedCode = 0)
    $prior = $script:descendantReleaseProved; $script:descendantReleaseProved = $false
    $ownsContext = $null -eq $Cancellation
    $context = if ($ownsContext) { New-AudioCancellationContext } else { $Cancellation }
    $deadline = New-Object T13Support.Deadline($context, 180000)
    try {
        $parameters = @{ ExecutablePath = $Tool; Arguments = $NativeArguments; Cancellation = $context; MaxStdoutChars = $StdoutLimit; MaxStderrChars = $StderrLimit }
        if ($null -ne $Parser) { $parameters.ProgressParser = $Parser }
        if ($null -ne $Callback) { $parameters.ProgressCallback = $Callback; $parameters.ProgressDurationSeconds = $Duration }
        $native = Invoke-AudioNativeProcess @parameters
        if ($native.ProcessReleased) { $script:descendantReleaseProved = $prior }
        $report.native_runs += [pscustomobject]@{ executable = $Tool; arguments = @($NativeArguments | ForEach-Object { $_.Replace($testRoot, '<OWNED_TEMP>') }); status = $native.Status; exit_code = $native.ExitCode; process_released = $native.ProcessReleased; deadline_requested = $deadline.TimedOut; duration_ms = $native.DurationMilliseconds }
        Assert-True (-not $deadline.TimedOut -and $native.Status -ceq $ExpectedStatus -and $native.ExitCode -eq $ExpectedCode -and $native.ProcessReleased) ('Native fixture/check failed: ' + $native.Status + '/' + $native.ExitCode + ' ' + $native.Error + ' ' + $native.Stderr)
        return $native
    } finally { $deadline.Dispose(); if ($ownsContext) { $context.Dispose() } }
}
function Parse-Record {
    param([string]$Text)
    $parser = New-AudioProgressParser; $parser.Add($Text); $parser.Complete(); return $parser.Snapshot
}
function Get-DisplayRows { param([string]$Text); return @($Text -split '\r?\n' | Where-Object { $_ -match '^\[DISPLAY\] ' } | ForEach-Object { $_.Substring(10) | ConvertFrom-Json }) }
function Invoke-Entry {
    param([string]$Label, [string]$InputPath, [string]$Output, [switch]$UiFailure)
    $driver = Join-Path $testRoot ($Label + '-driver.ps1')
    $prefix = @('$ErrorActionPreference=''Stop''', '$ProgressPreference=''Continue''', '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$env:PATH=' + (Get-Literal (Split-Path -Parent $ffmpeg)) + '+'';''+$env:PATH'),
        ('$global:T13Output=' + (Get-Literal $Output)), ('$global:T13UiFailure=$' + [bool]$UiFailure),
        '$global:T13Rows=New-Object ''System.Collections.Generic.List[object]''',
        '$global:T13NativeProofs=New-Object ''System.Collections.Generic.List[object]''')
    $capture = @'
function global:Write-Progress {
    [CmdletBinding()]
    param([string]$Activity,[string]$Status,[string]$CurrentOperation,[int]$Id=0,[int]$ParentId=-1,
          [int]$PercentComplete=-1,[int]$SecondsRemaining=-1,[switch]$Completed,[int]$SourceId=0)
    $published=0
    if([IO.Directory]::Exists($global:T13Output)){$published=@([IO.Directory]::EnumerateFiles($global:T13Output,'*.mp3',[IO.SearchOption]::AllDirectories)).Count}
    $global:T13Rows.Add([pscustomobject]@{id=$Id;parent_id=$ParentId;activity=$Activity;status=$Status;operation=$CurrentOperation;percent=$PercentComplete;seconds_remaining=$SecondsRemaining;completed=[bool]$Completed;published_outputs=$published;machine_sequence=$(if($null -eq $global:T13Machine){0}else{$global:T13Machine.RecordSequence});machine_seconds=$(if($null -eq $global:T13Machine){$null}else{$global:T13Machine.MediaSeconds})})
    if($global:T13UiFailure){throw 'controlled T13 display failure'}
}
function global:Read-Host { param($Prompt); throw 'T13 unexpected interactive prompt' }
'@
    $command = '& ' + (Get-Literal $entry) + ' -InputFolder ' + (Get-Literal $InputPath) + ' -OutputParent ' + (Get-Literal $Output) + ' -BitrateKbps 64 -MaxBaseLength 40'
    $text = (@($prefix) + @($capture, '$global:LASTEXITCODE=$null', ($command + ' *>&1 | ForEach-Object { [Console]::Out.WriteLine([string]$_) }'),
        'foreach($row in $global:T13Rows){[Console]::Out.WriteLine(''[DISPLAY] ''+($row|ConvertTo-Json -Compress))}',
        'foreach($proof in $global:T13NativeProofs){[Console]::Out.WriteLine(''[NATIVEPROOF] ''+($proof|ConvertTo-Json -Compress))}',
        'if($null -eq $global:LASTEXITCODE){throw ''Entry omitted exit code''};exit $global:LASTEXITCODE')) -join "`n"
    Write-NewText $driver $text; Add-Fixture $driver
    $info = New-Object Diagnostics.ProcessStartInfo; $info.FileName = $shellPath
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' + $driver + '"'
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false); $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    $child = [pscustomobject]@{process=$process;stdout_task=$null;stderr_task=$null;started=$false;disposed=$false;timed_out=$false}
    $children.Add($child)
    $priorReleaseProof=$script:descendantReleaseProved
    $script:descendantReleaseProved = $false
    Assert-True ($process.Start()) 'Owned entry child must start.'
    $child.started=$true;$child.stdout_task=$process.StandardOutput.ReadToEndAsync();$child.stderr_task=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(240000)){$child.timed_out=$true;throw 'Synthetic entry timed out; native descendants unproved, preserve owned tree.'}
    if(-not $child.stdout_task.Wait(5000) -or -not $child.stderr_task.Wait(5000)){$child.timed_out=$true;throw 'Entry pipe join failed; preserve owned tree.'}
    $result = [pscustomobject]@{exit_code=$process.ExitCode;text=$child.stdout_task.GetAwaiter().GetResult()+"`n"+$child.stderr_task.GetAwaiter().GetResult()}
    $process.Dispose();$child.disposed=$true
    $proofs=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[NATIVEPROOF\] '}|ForEach-Object{$_.Substring(14)|ConvertFrom-Json})
    $result | Add-Member -NotePropertyName native_release_proofs -NotePropertyValue $proofs
    if($result.exit_code -in @(0,2) -and $result.text -match '\[RESULT\] status=Completed(?:WithFailures)?;' -and
        $proofs.Count -gt 0 -and @($proofs|Where-Object{-not $_.process_released}).Count -eq 0){$script:descendantReleaseProved=$priorReleaseProof}
    return $result
}
function Get-Published {
    param([string]$Parent)
    return @(Get-SafeTree $Parent | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
}
function Assert-Decoded {
    param([string]$Path, [double]$ExpectedDuration)
    $probe = (Invoke-OwnedNative $ffprobe @('-v','error','-show_entries','stream=codec_type,codec_name,bit_rate,duration','-of','json',$Path)).Stdout | ConvertFrom-Json
    $audio = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Independent output probe must show one 64 kbps MP3 audio stream.'
    $seconds = [double]::Parse([string]$audio[0].duration, [Globalization.CultureInfo]::InvariantCulture)
    Assert-True ([math]::Abs($seconds-$ExpectedDuration) -le 0.35) 'Independent published duration must match within existing tolerance.'
    $parser = New-AudioProgressParser
    Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-xerror','-i',$Path,'-map','0:a:0','-progress','pipe:1','-stats_period','86400','-f','null','NUL') -Parser $parser | Out-Null
    Assert-True ($parser.Snapshot.ProgressState -ceq 'end' -and [math]::Abs($parser.Snapshot.MediaSeconds-$ExpectedDuration) -le 0.35) 'Independent complete decode must end at the expected media duration.'
    return [pscustomobject]@{duration_seconds=$seconds;decoded_seconds=$parser.Snapshot.MediaSeconds;sha256=(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant();fully_decoded=$true}
}
$supportSource = @'
using System;
using System.Text;
using System.Threading;
namespace T13Support {
    public static class ConsumerFault {
        public static int Calls;
        public static readonly Action<char[],int> Callback=(buffer,count)=>{Interlocked.Increment(ref Calls);throw new Exception("controlled T13 stream consumer failure");};
    }
    public sealed class Deadline : IDisposable {
        private readonly Timer timer;
        private int timedOut;
        public bool TimedOut { get { return Interlocked.CompareExchange(ref timedOut,0,0)!=0; } }
        public Deadline(object context,int milliseconds) {
            timer=new Timer(o=>{Interlocked.Exchange(ref timedOut,1);context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite);
        }
        public void Dispose(){timer.Dispose();}
    }
    public static class Child {
        public static int Main(string[] args) {
            Console.OutputEncoding=new UTF8Encoding(false);
            if(args[0]=="chunked") {
                if(args.Length>1){using(var marker=new System.IO.FileStream(args[1],System.IO.FileMode.CreateNew,System.IO.FileAccess.Write,System.IO.FileShare.Read)){byte[] bytes=Encoding.UTF8.GetBytes("running");marker.Write(bytes,0,bytes.Length);}}
                Console.Error.Write("STDERR_ONLY out_time_us=999999999999\nprogress=end\n");
                string[] chunks={"out_", "time_us=1000000\r", "\nprogress=continue\r\n", "out_time_ms=2000000\nprogress=continue\n", "out_time=02:00:05.125\r\nprogress=", "end\r\n"};
                foreach(string chunk in chunks){Console.Out.Write(chunk);Console.Out.Flush();Thread.Sleep(chunk==chunks[2]?1200:160);}
                if(args.Length>1){System.IO.File.WriteAllText(args[1],"complete");}
                return 0;
            }
            if(args[0]=="end-fail"){Console.Out.Write("out_time_us=90001500000\nprogress=end\n");Console.Error.Write("controlled encoder exit seven");return 7;}
            if(args[0]=="hold"){Thread.Sleep(30000);return 0;}
            if(args[0]=="huge") {
                Console.Out.Write(new string('X',2097152));Console.Out.Write("\nprogress=continue\n");
                Console.Error.Write(new string('E',131072));Console.Error.Write("\nout_time_us=999999999999\nprogress=end\n");
                Console.Out.Write("out_time_us=2500000\nprogress=end\n");return 0;
            }
            return 7;
        }
    }
}
'@
try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop; Assert-NoReparse $tempParent; Assert-NoReparse $evidenceParent
    $ownedRootCreated=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved=$true; Write-NewText $ownerFile $ownerToken; $report.marker_create_new=$true
    $report.owner_marker_sha256=(Get-FileHash -LiteralPath $ownerFile).Hash.ToLowerInvariant(); $report.source_before=Get-SourceInventory
    Add-Type -TypeDefinition $supportSource
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools']=@($ffmpeg,$ffprobe | ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant();version=(Invoke-OwnedNative $_ @('-version')).Stdout.Split([char]10)[0].Trim()}})
    $support=Join-Path $testRoot 'Child.cs'; Write-NewText $support $supportSource; Add-Fixture $support
    $childExe=Join-Path $testRoot 'Child.exe'; $compiler=Join-Path ([Environment]::GetFolderPath('Windows')) 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $compilerDirectory=Split-Path -Parent $compiler
    $references=@('mscorlib.dll','System.dll','System.Core.dll') | ForEach-Object {'/reference:'+(Join-Path $compilerDirectory $_)}
    Invoke-OwnedNative $compiler (@('/nologo','/noconfig','/nostdlib+','/target:exe','/main:T13Support.Child',('/out:'+$childExe))+$references+@($support)) | Out-Null; Add-Fixture $childExe
    Invoke-Case 'chunk boundaries and LF/CRLF produce only complete latest records' 'A33,A34' {
        param($case);$parser=New-AudioProgressParser
        foreach($chunk in @('out_','time_us=1250000',"`r","`nprogress=cont",'inue',"`r","`n")){$parser.Add($chunk)}
        Assert-True ($parser.Snapshot.Sequence -eq 1 -and $parser.Snapshot.MediaSeconds -eq 1.25 -and $parser.Snapshot.ProgressState -ceq 'continue') 'Split CRLF record must publish exactly once after its delimiter.'
        $parser.Add("out_time=02:15:45.125`nprogress=end");$parser.Complete()
        Assert-True ($parser.Snapshot.Sequence -eq 2 -and $parser.Snapshot.MediaSeconds -eq 8145.125 -and $parser.Snapshot.ProgressState -ceq 'end') 'Final unterminated line and hour-plus timestamp must parse.'
        $case['sequence']=2;$case['hour_plus_seconds']=$parser.Snapshot.MediaSeconds;$case['bounded_buffer_chars']=$parser.MaximumBufferedChars
    }
    Invoke-Case 'preferred microseconds, legacy microseconds and unbounded hour digits' 'A34' {
        param($case);$matrix=@(@{text="out_time_us=1000000`nout_time_ms=3000000`nout_time=02:00:00.0`nprogress=continue`n";seconds=1.0},
            @{text="out_time_ms=3605000000`nprogress=end`n";seconds=3605.0},@{text="out_time=1800:02:03.5`nprogress=end`n";seconds=6480123.5})
        $matrix+=@(@{text="out_time_us=-1`nout_time_ms=1000000`nout_time=25:00:01.5`nprogress=end`n";seconds=1.0},@{text="out_time_us=Infinity`nout_time_ms=invalid`nout_time=25:00:01.5`nprogress=end`n";seconds=90001.5})
        $case['records']=@();foreach($row in $matrix){$record=Parse-Record $row.text;Assert-True ($record.MediaSeconds -eq $row.seconds) 'Valid microseconds take precedence; invalid preferred values fall back within the same complete record.';$case.records+=[pscustomobject]@{expected_seconds=$row.seconds;actual_seconds=$record.MediaSeconds}}
    }
    Invoke-Case 'malformed overflow records remain bounded and recover at a later record' 'A33,A34' {
        param($case);$parser=New-AudioProgressParser;$parser.Add(('X'*2097152)+"`nprogress=continue`n")
        $parser.Add(("unknown="+('y'*200)+"`n")*100);$parser.Add("progress=end`n")
        Assert-True ($parser.MaximumBufferedChars -le 8192 -and $parser.BufferedChars -le 8192 -and $parser.DroppedRecords -gt 0) 'Huge line/record must be discarded with bounded storage.'
        $parser.Add("out_time_us=2500000`nprogress=end`n");$parser.Complete()
        Assert-True ($parser.Snapshot.MediaSeconds -eq 2.5 -and $parser.Snapshot.ProgressState -ceq 'end') 'Valid record following overflow must recover without carrying corrupt time.'
        foreach($bad in @('-1','NaN','Infinity','1.5','9223372036854775808')){$record=Parse-Record ("out_time_us=$bad`nprogress=end`n");Assert-True ($null -eq $record.MediaSeconds) 'Malformed machine numbers must not invent media time.'}
        foreach($bad in @('02:60:01.0','02:00:60.0','invalid','-01:00:00.0')){$record=Parse-Record ("out_time=$bad`nprogress=end`n");Assert-True ($null -eq $record.MediaSeconds) 'Malformed clock components must not invent media time.'}
        $case['maximum_buffer_chars']=$parser.MaximumBufferedChars;$case['dropped_records']=$parser.DroppedRecords;$case['recovered_seconds']=$parser.Snapshot.MediaSeconds
    }
    Invoke-Case 'unknown or invalid duration is indeterminate and encoding end never final success' 'A33,A34' {
        param($case);$record=Parse-Record "out_time_us=3605000000`nprogress=end`n";$case['duration_matrix']=@()
        foreach($duration in @($null,'N/A',0,-1,[double]::NaN,[double]::PositiveInfinity,'1e309')){$state=Get-AudioProgressState -Record $record -DurationSeconds $duration -Phase Encoding;Assert-True ($state.PercentComplete -eq -1) 'Unknown/nonpositive/nonfinite duration must show indeterminate progress.';$case.duration_matrix+=[pscustomobject]@{duration_label=[string]$duration;percent=$state.PercentComplete}}
        $state=Get-AudioProgressState -Record $record -DurationSeconds 7210 -Phase Encoding;Assert-True ($state.PercentComplete -eq 50) 'Trustworthy duration must compute media progress rather than wall clock.'
        foreach($duration in @(3605,100,0.01)){$state=Get-AudioProgressState -Record $record -DurationSeconds $duration -Phase Encoding;Assert-True ($state.PercentComplete -eq 99) 'End/overrun remains below 100 until validation and publication.'}
        $case['encoding_end_clamped_to']=99;$case['no_eta_invented']=$true
    }
    Invoke-Case 'same-phase UI samples throttle while mandatory phase transitions remain visible' 'A33' {
        param($case);$state=New-AudioProgressCallbackState;$events=New-Object 'System.Collections.Generic.List[object]';$callback={param($event);$events.Add($event)}
        $initial=Get-AudioProgressState -Record $null -DurationSeconds 10 -Phase Encoding
        $timed=Get-AudioProgressState -Record (Parse-Record "out_time_us=5000000`nprogress=continue`n") -DurationSeconds 10 -Phase Encoding
        Assert-True (Invoke-AudioProgressCallback -Callback $callback -State $state -Progress $initial) 'Initial phase must be visible.'
        Assert-True (-not (Invoke-AudioProgressCallback -Callback $callback -State $state -Progress $timed)) 'Immediate same-phase sample must remain throttled.'
        foreach($phase in @('Validating','Promoting')){Assert-True (Invoke-AudioProgressCallback -Callback $callback -State $state -Progress (Get-AudioProgressState -Record $null -DurationSeconds 10 -Phase $phase)) 'Mandatory changed phase must be visible even inside throttle interval.'}
        Assert-True ($events.Count -eq 3) 'Throttle exception permits only the initial and two changed-phase events here.'
        $case['phases']=@($events.Phase);$case['same_phase_update_suppressed']=$true;$case['phase_change_throttle_exceptions']=2
    }
    Invoke-Case 'native stdout machine stream is distinct from stderr and callbacks bounded' 'A33,A34' {
        param($case);$parser=New-AudioProgressParser;$events=New-Object 'System.Collections.Generic.List[object]'
        $liveMarker=Join-Path $testRoot 'live-progress.txt'
        $native=Invoke-OwnedNative $childExe @('chunked',$liveMarker) -Parser $parser -Duration 8000 -Callback {param($event);$events.Add([pscustomobject]@{Phase=$event.Phase;PercentComplete=$event.PercentComplete;MediaSeconds=$event.MediaSeconds;ProgressState=$event.ProgressState;marker_running=([IO.File]::Exists($liveMarker) -and [IO.File]::ReadAllText($liveMarker) -ceq 'running')})}
        Add-Fixture $liveMarker
        Assert-True ($native.Stderr.Contains('STDERR_ONLY') -and -not $native.Stdout.Contains('STDERR_ONLY') -and $parser.Snapshot.MediaSeconds -eq 7205.125) 'Only stdout records may determine progress; stderr remains diagnostic.'
        Assert-True ($events.Count -gt 0 -and $events.Count -le ([math]::Ceiling($native.DurationMilliseconds/500)+2)) 'UI callbacks must be throttled and still report progress.'
        Assert-True (@($events|Where-Object{$_.ProgressState -ceq 'continue' -and $_.marker_running}).Count -gt 0) 'A complete machine record must reach UI while the exact owned child is still running.'
        Assert-True (@($events | Where-Object {$_.PercentComplete -ge 100}).Count -eq 0) 'Native progress=end must never claim published success.'
        $case['callbacks']=$events.ToArray();$case['native_ms']=$native.DurationMilliseconds;$case['stderr_separate']=$true;$case['final_media_seconds']=$parser.Snapshot.MediaSeconds
    }
    Invoke-Case 'huge concurrent diagnostics drain with small retained stdout/stderr and parser recovery' 'A33,A34' {
        param($case);$parser=New-AudioProgressParser;$native=Invoke-OwnedNative $childExe @('huge') -Parser $parser -StdoutLimit 64 -StderrLimit 128
        Assert-True ($native.Stdout.Length -eq 64 -and $native.Stderr.Length -eq 128 -and $native.StdoutTruncated -and $native.StderrTruncated -and $native.StdoutTotalChars -gt 2097152 -and $native.StderrTotalChars -gt 131072) 'Drain must stay live while retained diagnostics remain bounded.'
        Assert-True ($parser.Snapshot.MediaSeconds -eq 2.5 -and $parser.MaximumBufferedChars -le 8192 -and $parser.DroppedRecords -gt 0) 'Parser must consume drained data beyond retained prefix and recover independently of stderr.'
        $case['retained_stdout_chars']=$native.Stdout.Length;$case['retained_stderr_chars']=$native.Stderr.Length;$case['parser_maximum_buffer_chars']=$parser.MaximumBufferedChars;$case['recovered_seconds']=$parser.Snapshot.MediaSeconds
    }
    Invoke-Case 'native progress callback exception is isolated from process outcome' 'A33' {
        param($case);$calls=New-Object 'System.Collections.Generic.List[object]'
        $native=Invoke-OwnedNative $childExe @('chunked') -Duration 8000 -Callback {param($event);$calls.Add($event);throw 'controlled T13 callback failure'}
        Assert-True ($calls.Count -eq 1 -and $native.ExitCode -eq 0 -and $native.ProcessReleased) 'Failing optional UI callback must be disabled once without changing completed native result.'
        $case['callback_calls_before_disabled']=$calls.Count;$case['native_outcome_unchanged']=$true
    }
    Invoke-Case 'throwing worker consumer is disabled and both flood pipes continue draining' 'A33' {
        param($case);$capture=$null;$prior=$script:descendantReleaseProved;$script:descendantReleaseProved=$false;[T13Support.ConsumerFault]::Calls=0
        try{$capture=New-Object AudioFileForPhone.NativeCapture($childExe,[string[]]@('huge'),64,128,[T13Support.ConsumerFault]::Callback)
            Assert-True ($capture.WaitForExit(10000)) 'Consumer fault must not stop stdout draining or block its owned child.'
            $code=$capture.CaptureExitCode();Assert-True ($capture.Complete(5000)) 'Flood drain must join after child exit.'
            Assert-True ($code -eq 0 -and [T13Support.ConsumerFault]::Calls -eq 1 -and $capture.ProgressConsumerError.Contains('controlled T13 stream consumer failure') -and $capture.ProgressConsumerError.Length -le 1024) 'Consumer exception must be retained once, bounded and disabled.'
            Assert-True ($capture.Stdout.Length -eq 64 -and $capture.Stderr.Length -eq 128 -and $capture.StdoutTotalChars -gt 2097152 -and $capture.StderrTotalChars -gt 131072) 'Faulted consumer cannot prevent either diagnostic stream from draining.'
            $case['consumer_calls']=1;$case['stdout_total_chars']=$capture.StdoutTotalChars;$case['stderr_total_chars']=$capture.StderrTotalChars;$case['consumer_error']=$capture.ProgressConsumerError
        }finally{if($null -ne $capture){$capture.Dispose();if($capture.Released){$script:descendantReleaseProved=$prior};$case['owned_capture_released']=$capture.Released}}
    }
    Invoke-Case 'progress end cannot turn a nonzero encoder exit into success' 'A33,A34' {
        param($case);$parser=New-AudioProgressParser;$events=New-Object 'System.Collections.Generic.List[object]'
        $native=Invoke-OwnedNative $childExe @('end-fail') -Parser $parser -Duration 90001.5 -Callback {param($event);$events.Add($event)} -ExpectedCode 7
        Assert-True ($native.ExitCode -eq 7 -and $parser.Snapshot.ProgressState -ceq 'end' -and @($events|Where-Object{$_.PercentComplete -ge 100}).Count -eq 0) 'Machine end is independent of actual encoder success and publication.'
        $case['actual_exit_code']=$native.ExitCode;$case['end_did_not_claim_success']=$true
    }
    Invoke-Case 'live progress-requested cancellation releases only its native child' 'A33' {
        param($case);$info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$childExe;$info.Arguments='hold';$info.UseShellExecute=$false;$info.CreateNoWindow=$true
        $held=New-Object Diagnostics.Process;$held.StartInfo=$info
        $owned=[pscustomobject]@{process=$held;stdout_task=$null;stderr_task=$null;started=$false;disposed=$false;timed_out=$false};$children.Add($owned)
        Assert-True ($held.Start()) 'Independent owned sentinel must start.';$owned.started=$true
        $context=New-AudioCancellationContext;$calls=New-Object 'System.Collections.Generic.List[object]'
        try{$native=Invoke-OwnedNative $childExe @('chunked') -Duration 8000 -Cancellation $context -ExpectedStatus 'Cancelled' -ExpectedCode $null -Callback {param($event);if($event.ProgressState -ceq 'continue'){$calls.Add($event);$context.Request();throw 'controlled display exception after cancellation request'}}
            Assert-True ($calls.Count -eq 1 -and $native.Status -ceq 'Cancelled' -and $native.ProcessReleased -and -not $held.HasExited) 'Callback catch must retain requested cancellation and unrelated owned child must survive.'
            $case['cancelled_process_released']=$true;$case['independent_live_child_survived']=$true
        }finally{$context.Dispose();if(-not $held.HasExited){$held.Kill()};Assert-True ($held.HasExited -or $held.WaitForExit(5000)) 'Independent held process release must be proved.';$held.Dispose();$owned.disposed=$true}
    }
    $short=Join-Path $testRoot 'short.mp3';Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=22050','-t','0.25','-c:a','libmp3lame','-b:a','64k',$short)|Out-Null;Add-Fixture $short
    Invoke-Case 'real transaction validates and promotes before any published-success display' 'A33' {
        param($case);$outRoot=Join-Path $testRoot 'Transaction';[IO.Directory]::CreateDirectory($outRoot)|Out-Null;$target=Join-Path $outRoot 'result.mp3'
        $sourceProbe=(Invoke-OwnedNative $ffprobe @('-v','error','-show_entries','stream=duration','-of','json',$short)).Stdout|ConvertFrom-Json;$seconds=[double]::Parse([string]$sourceProbe.streams[0].duration,[Globalization.CultureInfo]::InvariantCulture)
        $events=New-Object 'System.Collections.Generic.List[object]';$script:descendantReleaseProved=$false
        $transaction=Invoke-AudioOutputTransaction -OutputPath $target -OutputRoot $outRoot -SourcePath $short -SourceDurationSeconds $seconds -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments @('-nostdin','-v','error','-i',$short,'-vn','-c:a','libmp3lame','-b:a','64k') -Cancellation $null -ProgressCallback {param($event);$events.Add([pscustomobject]@{phase=$event.Phase;percent=$event.PercentComplete;final_exists=[IO.File]::Exists($target)})}
        if($transaction.EncoderResult.ProcessReleased -and $transaction.ValidationResult.ProcessReleased){$script:descendantReleaseProved=$true}
        $case['phase_events']=$events.ToArray();Assert-True ($transaction.Status -ceq 'Success' -and [IO.File]::Exists($target)) 'Real transaction must publish only validated output.'
        $phases=@($events|ForEach-Object{$_.phase});Assert-True ($phases -contains 'Validating' -and $phases -contains 'Promoting' -and [array]::IndexOf($phases,'Validating') -lt [array]::IndexOf($phases,'Promoting')) 'Validation and publication must be distinct ordered phases.'
        Assert-True (@($events|Where-Object{$_.final_exists -or $_.percent -ge 100 -or $_.phase -ceq 'Success'}).Count -eq 0) 'Transaction progress must not claim success before the caller commits outcome.'
        $case['decoded_output']=Assert-Decoded $target $seconds;$case['publication_after_validation_and_promotion']=$true
    }
    Invoke-Case 'encoder end followed by validation rejection never displays success or leaves a final' 'A33' {
        param($case);$outRoot=Join-Path $testRoot 'Reject';[IO.Directory]::CreateDirectory($outRoot)|Out-Null;$target=Join-Path $outRoot 'result.mp3'
        $originalValidation=(Get-Item -LiteralPath Function:Get-AudioOutputValidation).ScriptBlock;$events=New-Object 'System.Collections.Generic.List[object]'
        $wrapper={param($Path,$SourceDurationSeconds,$BitrateKbps,$HasCover,$FfprobePath,$FfmpegPath,$Cancellation,[int]$ProbeTimeoutSeconds=60)
            $result=& $originalValidation @PSBoundParameters;$result.Status='ControlledRejectedAfterRealValidation';$result.Error='controlled T13 validation rejection';return $result}.GetNewClosure()
        try{Set-Item -LiteralPath Function:Get-AudioOutputValidation -Value $wrapper;$script:descendantReleaseProved=$false
            $transaction=Invoke-AudioOutputTransaction -OutputPath $target -OutputRoot $outRoot -SourcePath $short -SourceDurationSeconds 0.25 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments @('-nostdin','-v','error','-i',$short,'-vn','-c:a','libmp3lame','-b:a','64k') -Cancellation $null -ProgressCallback {param($event);$events.Add($event)}
            if($transaction.EncoderResult.ProcessReleased -and $transaction.ValidationResult.ProcessReleased){$script:descendantReleaseProved=$true}
            Assert-True ($transaction.Status -ceq 'ValidationFailed' -and $transaction.EncoderResult.Stdout -match 'progress=end' -and -not [IO.File]::Exists($target) -and -not [IO.File]::Exists($transaction.WorkingPath)) 'Actual encoder end followed by rejected validation must not publish and exact partial must be cleaned after release.'
            Assert-True (@($events|Where-Object{$_.PercentComplete -ge 100 -or $_.Phase -ceq 'Success' -or $_.Phase -ceq 'Promoting'}).Count -eq 0) 'Rejected validation must never advance to promotion/success display.'
            $case['phases']=@($events.Phase);$case['actual_status']=$transaction.Status;$case['no_false_success_or_final']=$true
        }finally{Set-Item -LiteralPath Function:Get-AudioOutputValidation -Value $originalValidation}
    }
    Invoke-Case 'encoder end and successful validation followed by promotion collision never display success' 'A33' {
        param($case);$outRoot=Join-Path $testRoot 'Collision';[IO.Directory]::CreateDirectory($outRoot)|Out-Null;$target=Join-Path $outRoot 'result.mp3';$events=New-Object 'System.Collections.Generic.List[object]';$script:descendantReleaseProved=$false
        $transaction=Invoke-AudioOutputTransaction -OutputPath $target -OutputRoot $outRoot -SourcePath $short -SourceDurationSeconds 0.25 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments @('-nostdin','-v','error','-i',$short,'-vn','-c:a','libmp3lame','-b:a','64k') -Cancellation $null -ProgressCallback {param($event);$events.Add($event);if($event.Phase -ceq 'Promoting'){Write-NewText $target 'Synthetic publication collision sentinel'}}
        if($transaction.EncoderResult.ProcessReleased -and $transaction.ValidationResult.ProcessReleased){$script:descendantReleaseProved=$true}
        Assert-True ($transaction.Status -ceq 'PromotionFailed' -and $transaction.EncoderResult.Stdout -match 'progress=end' -and $transaction.ValidationResult.Status -ceq 'Success' -and [IO.File]::ReadAllText($target) -ceq 'Synthetic publication collision sentinel') 'Actual encoder end and validation success cannot override a final publication collision.'
        Assert-True (-not [IO.File]::Exists($transaction.WorkingPath) -and @($events|Where-Object{$_.PercentComplete -ge 100 -or $_.Phase -ceq 'Success'}).Count -eq 0) 'Promotion collision must leave occupied final intact, remove exact released partial and report no success.'
        Add-Fixture $target;$case['phases']=@($events.Phase);$case['actual_status']=$transaction.Status;$case['existing_final_preserved']=$true
    }
    $app=Join-Path $testRoot 'App';[IO.Directory]::CreateDirectory($app)|Out-Null
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){$copy=Join-Path $app $name;[IO.File]::Copy((Join-Path $projectRoot $name),$copy,$false);Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Application copies must start byte-identical.'}
    # Test-only audit after byte-identical copy: every native result has a
    # positive exit proof before the host can authorize recursive fixture cleanup.
    $nativeAudit=@'
$script:T13OriginalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
          [object]$Cancellation=(Get-AudioCancellationContext),[object]$ProgressParser=$null,[scriptblock]$ProgressCallback=$null,[object]$ProgressDurationSeconds=$null,[object]$ProgressCallbackState=$null,
          [int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    $proof=[pscustomobject]@{process_released=$false;status='not returned'};$global:T13NativeProofs.Add($proof)
    $nativeParameters=@{};foreach($key in $PSBoundParameters.Keys){$nativeParameters[$key]=$PSBoundParameters[$key]}
    if($null -ne $ProgressCallback){$originalCallback=$ProgressCallback;$nativeParameters.ProgressCallback={param($progress);$global:T13Machine=$progress;try{& $originalCallback $progress}finally{$global:T13Machine=$null}}.GetNewClosure()}
    $result=& $script:T13OriginalNative @nativeParameters
    $proof.process_released=[bool]$result.ProcessReleased;$proof.status=$result.Status
    return $result
}
'@
    [IO.File]::AppendAllText((Join-Path $app 'AudioFileForPhone.Helpers.ps1'),"`r`n"+$nativeAudit,[Text.Encoding]::UTF8)
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){Add-Fixture (Join-Path $app $name)}
    $entry=Join-Path $app 'AudioFileForPhone.ps1';$report.copied_entry_bytes_unchanged=$true
    Invoke-Case '100 percent processed retains file failure and never precedes final-file completion' 'A33' {
        param($case);$fixtureInput=Join-Path $testRoot 'Mixed';[IO.Directory]::CreateDirectory($fixtureInput)|Out-Null;$good=Join-Path $fixtureInput '2024-01-01 Good.mp3';[IO.File]::Copy($short,$good,$false);Add-Fixture $good
        $bad=Join-Path $fixtureInput '2024-01-02 Bad.ogg';Write-NewText $bad 'Synthetic invalid OGG';Add-Fixture $bad
        $out=Join-Path $testRoot 'MixedOut';$result=Invoke-Entry 'mixed' $fixtureInput $out;$case['diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>');$rows=Get-DisplayRows $result.text;$case['display_rows']=$rows
        Assert-True ($result.exit_code -eq 2 -and $result.text -match '\[RESULT\] status=CompletedWithFailures; total=2; processed=2; converted=1; failed=1; not_processed=0;') 'Completed-with-failures counts must remain separate from percent processed.'
        $hundred=@($rows|Where-Object{$_.id -eq 0 -and $_.percent -eq 100 -and -not $_.completed})
        Assert-True ($hundred.Count -gt 0 -and @($hundred|Where-Object{$_.status -notmatch '[Ff]ailed[^0-9]*1|1[^0-9]*[Ff]ailed'}).Count -eq 0) 'Batch at 100% processed must visibly retain one failure.'
        Assert-True (@($rows|Where-Object{$_.id -eq 0 -and $_.percent -eq 100 -and $_.published_outputs -lt 1}).Count -eq 0) 'Batch must not reach 100% when last file merely starts.'
        Assert-True (@($rows|Where-Object{$_.seconds_remaining -ne -1}).Count -eq 0) 'Display must not invent an ETA.'
        $published=Get-Published $out;Assert-True ($published.Count -eq 1) 'Only valid source may publish output.';$case['decoded_output']=Assert-Decoded $published[0].FullName 0.25;$case['failure_visible_at_processed_100']=$true
    }
    Invoke-Case 'display exceptions cannot change already committed successful file and batch outcomes' 'A33' {
        param($case);$fixtureInput=Join-Path $testRoot 'UiFault';[IO.Directory]::CreateDirectory($fixtureInput)|Out-Null;$good=Join-Path $fixtureInput '2024-01-01 Good.mp3';[IO.File]::Copy($short,$good,$false);Add-Fixture $good
        $out=Join-Path $testRoot 'UiFaultOut';$result=Invoke-Entry 'ui-fault' $fixtureInput $out -UiFailure;$case['diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>');$case['display_rows']=Get-DisplayRows $result.text
        Assert-True ($result.exit_code -eq 0 -and $result.text -match '\[RESULT\] status=Completed; total=1; processed=1; converted=1; failed=0;' -and $result.text.Contains('controlled T13 display failure')) 'Optional progress display failure must warn and preserve publication/count/exit0.'
        $published=Get-Published $out;Assert-True ($published.Count -eq 1) 'UI exception must not remove or reclassify published output.';$case['decoded_output']=Assert-Decoded $published[0].FullName 0.25;$case['committed_outcome_preserved']=$true
    }
    Invoke-Case 'actual 3605-second synthetic media progresses beyond an hour and fully decodes' 'A33,A34' {
        param($case);$fixtureInput=Join-Path $testRoot 'Long';[IO.Directory]::CreateDirectory($fixtureInput)|Out-Null;$long=Join-Path $fixtureInput '2024-01-01 Synthetic 3605 seconds.mp3'
        Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','anullsrc=r=22050:cl=mono','-t','3605','-c:a','libmp3lame','-b:a','64k',$long)|Out-Null;Add-Fixture $long
        $before=(Get-FileHash -LiteralPath $long).Hash;$out=Join-Path $testRoot 'LongOut';$result=Invoke-Entry 'long' $fixtureInput $out
        $case['diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>');$rows=Get-DisplayRows $result.text;$case['display_rows']=$rows
        Assert-True ($result.exit_code -eq 0 -and $result.text -match '\[RESULT\] status=Completed; total=1; processed=1; converted=1; failed=0;') 'Actual hour-plus source must succeed through unchanged application path.'
        $encoding=@($rows|Where-Object{$_.id -eq 1 -and $_.status -match 'Encoding' -and $_.machine_sequence -gt 0 -and $_.machine_seconds -gt 0 -and $_.percent -gt 0 -and $_.percent -lt 100 -and $_.published_outputs -eq 0 -and -not $_.completed})
        Assert-True (@($encoding.percent|Select-Object -Unique).Count -gt 1) 'Long real encoder must deliver multiple live determinate machine updates before publication.'
        Assert-True (@($rows|Where-Object{$_.id -ne 0 -and $_.percent -eq 100 -and $_.published_outputs -ne 1}).Count -eq 0) 'Per-file 100% success requires published output.'
        Assert-True (@($rows|Where-Object{$_.status -match 'Validating|Promoting' -and $_.published_outputs -ne 0}).Count -eq 0) 'Validation/promotion display must precede publication.'
        $published=Get-Published $out;Assert-True ($published.Count -eq 1) 'Hour-plus run must publish exactly one output.';$case['decoded_output']=Assert-Decoded $published[0].FullName 3605
        Assert-True ((Get-FileHash -LiteralPath $long).Hash -ceq $before) 'Actual long synthetic source must remain byte-identical.'
        $case['synthetic_source_duration_seconds']=3605;$case['realtime_throttling_used']=$false;$case['source_sha256_unchanged']=$true;$case['live_encoding_distinct_percentages']=@($encoding.percent|Select-Object -Unique)
    }
    $report.status='pass';$exitCode=0
}
catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
    $childrenStopped=$descendantReleaseProved
    foreach($child in $children){if($child.timed_out){$childrenStopped=$false};if($child.disposed){continue}
        try{if($child.started){if(-not $child.process.HasExited){$child.process.Kill()};Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Owned child exit unproved.'}
            foreach($task in @($child.stdout_task,$child.stderr_task)){if($null -ne $task){Assert-True ($task.Wait(5000)) 'Owned pipe unproved.';$null=$task.GetAwaiter().GetResult()}};$child.process.Dispose();$child.disposed=$true
        }catch{$childrenStopped=$false;$report['child_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    $report.children_disposed=$childrenStopped
    $report['descendant_release_proved']=$descendantReleaseProved
    $report['owned_host_objects']=@($children|ForEach-Object{[pscustomobject]@{started=$_.started;disposed=$_.disposed;timed_out=$_.timed_out}})
    foreach($inventory in @('source','synthetic')){try{$after=if($inventory -ceq 'source'){Get-SourceInventory}else{Get-FixtureInventory};$report[$inventory+'_after']=$after
        $same=(($report[$inventory+'_before']|ConvertTo-Json -Compress) -ceq ($after|ConvertTo-Json -Compress));$report[$inventory+'_unchanged']=$same;Assert-True $same "$inventory SHA256 must remain unchanged."
    }catch{$report.status='fail';$exitCode=1;$report[$inventory+'_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}}
    try{if($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)){
        $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/');Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exact exclusive TEMP root.'
        Assert-NoReparse $resolved;Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact CreateNew token.';Get-SafeTree $resolved|Out-Null
        [IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved)
    };Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'}catch{$report.status='fail';$exitCode=1;$report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    if(-not $childrenStopped){$report.status='fail';$exitCode=1};$report['finished_utc']=[DateTime]::UtcNow.ToString('o');Assert-NoReparse $evidenceParent;Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 20)
}
Write-Host "T13 progress: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
