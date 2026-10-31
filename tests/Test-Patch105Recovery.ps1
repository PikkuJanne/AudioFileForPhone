<#
Real-tool regression of bounded worker crash recovery. The test-only native shim
records exact argv and injects only the selected native operation. Media, shim
executables, raw output and reports stay in an exclusively owned external scope.
The production scripts are used unchanged, including when ApplicationRoot names
an extracted release ZIP. Injection proves recovery behavior, not a crash cause.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EvidencePath,
    [string]$FfmpegPath='C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath='C:\ffmpeg\bin\ffprobe.exe',
    [string]$ApplicationRoot=''
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\','/')
if([string]::IsNullOrWhiteSpace($ApplicationRoot)){$ApplicationRoot=$project}
$application=[IO.Path]::GetFullPath($ApplicationRoot).TrimEnd('\','/')
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$tempParent=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
$root=Join-Path $tempParent ('AFP-P105-'+[guid]::NewGuid().ToString('N'))
$marker=Join-Path $root '.patch105-owner';$token=[guid]::NewGuid().ToString('N')
$created=$false;$released=$true;$exitCode=1
$report=[ordered]@{
    schema_version=1;task='PATCH105';mode='real_tools_with_test_only_worker_fault_injection'
    status='fail';shell=$PSVersionTable.PSVersion.ToString();shell_edition=$PSVersionTable.PSEdition
    tested_commit=(& git -C $project rev-parse HEAD|Out-String).Trim()
    test_script_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    shim_source_sha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Patch105.NativeShim.cs') -Algorithm SHA256).Hash.ToLowerInvariant()
    started_utc=[DateTime]::UtcNow.ToString('o');environment=$null;cases=@()
    runtime_hashes=@();runtime_unchanged=$false;synthetic_unchanged=$false
    descendant_release_proved=$false;cleanup_verified=$false;owner_media_access=$false;ordinary_music_access=$false
    process_identity_checks=0;recycled_pid_observations=0;exited_pid_observations=0;process_identity_failure=$null
}
function Assert-P105([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash-P105([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-P105([string]$Path,[string]$Value){
    $s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$b=(New-Object Text.UTF8Encoding($false)).GetBytes($Value);$s.Write($b,0,$b.Length)}finally{$s.Dispose()}
}
function Inventory-P105([string[]]$Paths){@($Paths|ForEach-Object{[pscustomobject]@{path=$_;sha256=Hash-P105 $_}})}
function Safe-P105([string]$Path){
    $p=[IO.Path]::GetFullPath($Path)
    while($p){if(Test-Path -LiteralPath $p){Assert-P105 (((Get-Item -LiteralPath $p -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Reparse path refused.'};$p=[IO.Path]::GetDirectoryName($p)}
}
function Run-P105([string]$Exe,[string[]]$Arguments,[int[]]$Allowed=@(0),[hashtable]$Environment=@{}){
    $saved=@{};foreach($key in $Environment.Keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
    try{
        foreach($key in $Environment.Keys){[Environment]::SetEnvironmentVariable($key,[string]$Environment[$key],'Process')}
        $r=Invoke-AudioNativeProcess -ExecutablePath $Exe -Arguments $Arguments -Operation 'Patch105 test child' -TimeoutMilliseconds 180000
    }finally{foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key],'Process')}}
    if(-not$r.ProcessReleased-or-not$r.PipeDrainCompleted){$script:released=$false}
    Assert-P105 ($r.Status-eq'Completed'-and$r.ProcessReleased-and$r.PipeDrainCompleted-and$Allowed-contains$r.ExitCode) ('Native test child failed: '+$r.Status+' exit='+$r.ExitCode+' '+$r.Stderr+' '+$r.Error+' '+$r.Stdout)
    return $r
}
function Case-P105([string]$Name,[scriptblock]$Body){
    $case=[ordered]@{name=$Name;status='fail'}
    try{& $Body $case;$case.status='pass'}finally{$report.cases+=[pscustomobject]$case}
}
function Media-P105([string]$Path){(Run-P105 $FfprobePath @('-v','error','-show_streams','-show_format','-of','json','-i',$Path)).Stdout|ConvertFrom-Json}
function Events-P105([object]$Run,[string]$Stage,[bool]$Selected=$true){return ,@($Run.events|Where-Object{$_.stage-ceq$Stage-and$_.selected-eq$Selected})}
function Assert-ReleasedEvents-P105([object[]]$Events){
    foreach($event in $Events){
        $report.process_identity_checks++
        $process=Get-Process -Id $event.pid -ErrorAction SilentlyContinue
        if($null-eq$process){continue}
        try{
            if($process.HasExited){$report.exited_pid_observations++;continue}
            # PIDs can be reused by independent concurrent tests. Identify the
            # original worker instance before treating a live PID as a leak.
            $observedTicks=$process.StartTime.ToUniversalTime().Ticks
            if($observedTicks-eq[long]$event.started_utc_ticks){
                $process.Refresh()
                if($process.HasExited){$report.exited_pid_observations++;continue}
                $script:released=$false
                $report.process_identity_failure=[pscustomobject]@{pid=$event.pid;stage=$event.stage;recorded_start_utc_ticks=$event.started_utc_ticks;observed_start_utc_ticks=[string]$observedTicks;process_name=$process.ProcessName}
                throw 'The same test native shim instance still runs after application return.'
            }
            $report.recycled_pid_observations++
        }catch{$script:released=$false;throw}
        finally{$process.Dispose()}
    }
}
function App-P105 {
    param([string]$Name,[string]$Stage,[string]$Mode,[string]$Fixture,[int]$Expected=0,
        [bool]$FollowingGood=$false,[bool]$Unreadable=$false,[string]$ErrorText='',
        [long]$CrashExit=3221226505,[int]$ProbeTimeoutSeconds=60)
    $caseRoot=Join-Path $root $Name;$input=Join-Path $caseRoot 'input';$output=Join-Path $caseRoot 'output';$temp=Join-Path $caseRoot 'temp';$state=Join-Path $caseRoot 'shim-state'
    foreach($p in @($caseRoot,$input,$output,$temp,$state)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $sourcePath=Join-Path $input ('2024-01-01 - Selected'+[IO.Path]::GetExtension($Fixture))
    if($Unreadable){Write-P105 $sourcePath 'test-only unreadable audio'}else{[IO.File]::Copy($Fixture,$sourcePath)}
    if($FollowingGood){[IO.File]::Copy($fixtureM4a,(Join-Path $input '2024-01-02 - Subsequent good.m4a'))}
    $inputPaths=@(Get-ChildItem -LiteralPath $input -File|ForEach-Object{$_.FullName});$before=Inventory-P105 $inputPaths
    $log=Join-Path $caseRoot 'shim.jsonl'
    $environment=@{
        AFP_PATCH105_REAL_FFMPEG=$FfmpegPath;AFP_PATCH105_REAL_FFPROBE=$FfprobePath
        AFP_PATCH105_SOURCE=$sourcePath;AFP_PATCH105_STAGE=$Stage;AFP_PATCH105_MODE=$Mode
        AFP_PATCH105_LOG=$log;AFP_PATCH105_STATE=$state;AFP_PATCH105_ERROR=$ErrorText;AFP_PATCH105_EXIT=[string]$CrashExit
        TEMP=$temp;TMP=$temp;USERPROFILE=(Join-Path $caseRoot 'profile');LOCALAPPDATA=(Join-Path $caseRoot 'local');APPDATA=(Join-Path $caseRoot 'roaming');FFMPEG='';PATH=''
    }
    $a=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $application 'AudioFileForPhone.ps1'),'-InputFolder',$input,'-OutputParent',$output,'-FfmpegDirectory',$shimRoot,'-ConfigPath',(Join-Path $caseRoot 'missing.json'),'-Artist','Patch105 artist','-Album','Patch105 album','-CoverPath',$cover,'-ProbeTimeoutSeconds',[string]$ProbeTimeoutSeconds)
    $r=Run-P105 $shell $a @($Expected) $environment
    $text=$r.Stdout+"`n"+$r.Stderr;Write-P105 (Join-Path $caseRoot 'console.txt') $text
    $manifests=@(Get-ChildItem -LiteralPath $output -Recurse -File|Where-Object{$_.Name-ceq'AudioFileForPhone_manifest.json'})
    Assert-P105 ($manifests.Count-eq1) 'One run manifest required.'
    $manifest=Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8|ConvertFrom-Json
    $events=@(Get-Content -LiteralPath $log -Encoding UTF8|ForEach-Object{$_|ConvertFrom-Json})
    Assert-ReleasedEvents-P105 $events
    $files=@(Get-ChildItem -LiteralPath $output -Recurse -File|Where-Object{$_.Extension-ieq'.mp3'})
    $partials=@(Get-ChildItem -LiteralPath $output -Recurse -Force|Where-Object{$_.Extension-ieq'.partial'-or$_.Name-like'.AudioFileForPhone-recovery-*'})
    Assert-P105 ($partials.Count-eq0) 'No partial or recovery working files may remain after released children.'
    Assert-P105 (($before|ConvertTo-Json -Compress)-ceq((Inventory-P105 $inputPaths)|ConvertTo-Json -Compress)) 'Synthetic original bytes changed.'
    $nativeLog=Join-Path ([IO.Path]::GetDirectoryName($manifests[0].FullName)) 'AudioFileForPhone_log.txt'
    $diagnostics=Get-Content -LiteralPath $nativeLog -Raw -Encoding UTF8
    return [pscustomobject]@{native=$r;manifest=$manifest;text=$text;diagnostics=$diagnostics;files=$files;events=$events;source=$sourcePath;root=$caseRoot}
}
function Verify-P105([object]$Run,[int]$Count,[int]$Failed=0){
    Assert-P105 ($Run.files.Count-eq$Count-and$Run.manifest.totals.converted-eq$Count-and$Run.manifest.totals.failed-eq$Failed) 'Incorrect finished output/manifest counts.'
    foreach($file in $Run.files){
        $m=Media-P105 $file.FullName;$audio=@($m.streams|Where-Object{$_.codec_type-eq'audio'});$art=@($m.streams|Where-Object{$_.disposition.attached_pic-eq1})
        Assert-P105 ($audio.Count-eq1-and$audio[0].codec_name-eq'mp3'-and[long]$audio[0].bit_rate-eq64000-and[int]$audio[0].sample_rate-eq44100-and[int]$audio[0].channels-eq2-and$art.Count-eq1) 'Output audio shape/cover mismatch.'
        Assert-P105 ($m.format.tags.title-ceq'Patch105 source title'-and$m.format.tags.artist-ceq'Patch105 artist'-and$m.format.tags.album-ceq'Patch105 album') 'Source title or batch metadata lost.'
        $null=Run-P105 $FfmpegPath @('-nostdin','-v','error','-xerror','-err_detect','explode','-i',$file.FullName,'-map','0:a:0','-f','null','NUL')
        $guard=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);$guard.Dispose()
    }
}
function Assert-OneRetry-P105([object]$Run,[string]$Stage){
    $events=Events-P105 $Run $Stage
    Assert-P105 ($events.Count-eq2-and$events[0].action-ceq'once'-and$events[1].action-ceq'delegate'-and$events[0].pid-ne$events[1].pid) ($Stage+' did not execute exactly once after one exited injected crash.')
    $record=@($Run.manifest.records)[0]
    $diagnostic=$null;$logStage=''
    switch($Stage){
        'encode'{$diagnostic=$record.native_operations.encoder;$logStage='Encoder'}
        'output-probe'{$diagnostic=$record.native_operations.output_probe;$logStage='OutputProbe'}
        'validate'{$diagnostic=$record.native_operations.output_decode;$logStage='OutputDecode'}
        'source-probe'{$diagnostic=$record.source_probe;$logStage='SourceProbe'}
    }
    Assert-P105 ($null-ne$diagnostic-and$diagnostic.exit_code-eq0-and$diagnostic.process_released-and$null-ne$diagnostic.crash_recovery-and$diagnostic.crash_recovery.exit_code-ne0-and$diagnostic.crash_recovery.process_released) 'Manifest lost first crash or final successful process diagnostic.'
    Assert-P105 ($Run.diagnostics.Contains($logStage+'.FirstAttempt')-and$Run.diagnostics.Contains('*** stack smashing detected ***: terminated')) 'Local diagnostics lost the first failed worker.'
    return ,$events
}
try{
    Assert-P105 ([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT) 'Windows required.'
    Safe-P105 ([IO.Path]::GetDirectoryName($evidence));Safe-P105 $tempParent;Safe-P105 $application
    Assert-P105 ([IO.Directory]::Exists([IO.Path]::GetDirectoryName($evidence))-and-not(Test-Path -LiteralPath $evidence)-and-not$evidence.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Fresh report must remain outside Git.'
    . (Join-Path $application 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop;$created=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($root,[IntPtr]::Zero)
    Assert-P105 $created 'Exclusive TEMP reservation failed.';Write-P105 $marker $token
    $FfmpegPath=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$FfprobePath=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $shell=Join-Path $PSHOME 'powershell.exe';if(-not[IO.File]::Exists($shell)){$shell=Join-Path $PSHOME 'pwsh.exe'}
    $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.environment=[ordered]@{windows_build=$cv.CurrentBuildNumber+'.'+$cv.UBR;ffmpeg=(Run-P105 $FfmpegPath @('-version')).Stdout.Split([char]10)[0].Trim();ffprobe=(Run-P105 $FfprobePath @('-version')).Stdout.Split([char]10)[0].Trim();ffmpeg_sha256=Hash-P105 $FfmpegPath;ffprobe_sha256=Hash-P105 $FfprobePath;crash_coverage='test-only injected native exception exit; no natural-crash reproduction claim'}
    $runtime=@('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1','AudioFileForPhone.Diagnostics.ps1')|ForEach-Object{Join-Path $application $_}
    $sourceBefore=Inventory-P105 $runtime
    $report.runtime_hashes=@($sourceBefore|ForEach-Object{[pscustomobject]@{relative_path=[IO.Path]::GetFileName($_.path);sha256=$_.sha256}})
    $shimRoot=Join-Path $root 'shim';[IO.Directory]::CreateDirectory($shimRoot)|Out-Null
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $null=Run-P105 $csc @('/nologo','/target:exe',('/out:'+(Join-Path $shimRoot 'ffprobe.exe')),(Join-Path $PSScriptRoot 'Patch105.NativeShim.cs'))
    [IO.File]::Copy((Join-Path $shimRoot 'ffprobe.exe'),(Join-Path $shimRoot 'ffmpeg.exe'))
    $fixtureM4a=Join-Path $root 'fixture.m4a';$fixtureMp3=Join-Path $root 'fixture.mp3';$fixtureOgg=Join-Path $root 'fixture.ogg';$cover=Join-Path $root 'cover.jpg'
    $null=Run-P105 $FfmpegPath @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=44100:duration=1.5','-c:a','aac','-ac','2','-metadata','title=Patch105 source title',$fixtureM4a)
    $null=Run-P105 $FfmpegPath @('-nostdin','-v','error','-i',$fixtureM4a,'-c:a','libmp3lame',$fixtureMp3)
    $null=Run-P105 $FfmpegPath @('-nostdin','-v','error','-i',$fixtureM4a,'-c:a','libvorbis',$fixtureOgg)
    Add-Type -AssemblyName System.Drawing;$image=New-Object Drawing.Bitmap(225,225)
    try{$image.Save($cover,[Drawing.Imaging.ImageFormat]::Jpeg)}finally{$image.Dispose()}
    $fixtureBefore=Inventory-P105 @($fixtureM4a,$fixtureMp3,$fixtureOgg,$cover)

    Case-P105 'classification-requires-exception-completion-drained-pipes-and-released-process' {param($case)
        $rows=@(
            @{status='Completed';code=-1073740791;released=$true;drained=$true;expected=$true},
            @{status='Completed';code=-1073741819;released=$true;drained=$true;expected=$true},
            @{status='Completed';code=3221226505;released=$true;drained=$true;expected=$true},
            @{status='Completed';code=1;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=0;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=5;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=112;released=$true;drained=$true;expected=$false},
            @{status='Timeout';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='Cancelled';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='MissingExecutable';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='StartFailed';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=-1073740791;released=$false;drained=$true;expected=$false},
            @{status='Completed';code=-1073740791;released=$true;drained=$false;expected=$false}
        )
        foreach($row in $rows){$n=[pscustomobject]@{Status=$row.status;ExitCode=$row.code;ProcessReleased=$row.released;PipeDrainCompleted=$row.drained;Stderr='*** stack smashing detected ***: terminated'};Assert-P105 ((Test-AudioNativeWorkerCrash -NativeResult $n)-eq$row.expected) ('Crash classification mismatch: '+($row|ConvertTo-Json -Compress))}
        $case.rows=$rows.Count
    }
    Case-P105 'healthy-input-does-not-retry' {param($case)
        $r=App-P105 -Name normal -Stage encode -Mode normal -Fixture $fixtureM4a;Verify-P105 $r 1
        foreach($stage in @('source-probe','encode','output-probe','validate')){Assert-P105 ((Events-P105 $r $stage).Count-eq1) ('Healthy '+$stage+' retried.')}
        $case.exit_code=0;$case.converted=1;$case.retries=0
    }
    Case-P105 'encoder-once-crash-retries-in-new-owned-partial' {param($case)
        $r=App-P105 -Name encoder-once -Stage encode -Mode once -Fixture $fixtureM4a;Verify-P105 $r 1
        $events=Assert-OneRetry-P105 $r encode
        Assert-P105 ($events[0].path-cne$events[1].path-and-not[IO.File]::Exists($events[0].path)-and-not[IO.File]::Exists($events[1].path)) 'Encoder reused an owned partial or left its old partial.'
        Assert-P105 ((Events-P105 $r 'source-probe').Count-eq1-and(Events-P105 $r 'output-probe').Count-eq1-and(Events-P105 $r validate).Count-eq1) 'Encoder crash reran unrelated operations.'
        $case.exit_code=0;$case.encode_processes=2;$case.fresh_working_path=$true;$case.full_decode=$true
    }
    Case-P105 'validator-once-crash-reuses-identical-completed-bytes-without-reencode' {param($case)
        $r=App-P105 -Name validator-once -Stage validate -Mode once -Fixture $fixtureM4a;Verify-P105 $r 1
        $events=Assert-OneRetry-P105 $r validate
        Assert-P105 ($events[0].path-ceq$events[1].path-and$events[0].sha256-ceq$events[1].sha256-and$events[0].sha256-ceq(Hash-P105 $r.files[0].FullName)) 'Validator recovery did not retain exact completed MP3 bytes.'
        Assert-P105 (($events[0].argv|ConvertTo-Json -Compress)-ceq($events[1].argv|ConvertTo-Json -Compress)) 'Validator retry changed argv.'
        Assert-P105 ((Events-P105 $r encode).Count-eq1-and(Events-P105 $r 'source-probe').Count-eq1-and(Events-P105 $r 'output-probe').Count-eq1) 'Validator crash re-encoded or reran other operations.'
        $case.exit_code=0;$case.encode_processes=1;$case.validator_processes=2;$case.identical_completed_bytes=$true;$case.identical_argv=$true
    }
    Case-P105 'output-probe-once-crash-retries-only-same-read-operation' {param($case)
        $r=App-P105 -Name output-probe-once -Stage output-probe -Mode once -Fixture $fixtureM4a;Verify-P105 $r 1
        $events=Assert-OneRetry-P105 $r output-probe
        Assert-P105 ($events[0].path-ceq$events[1].path-and$events[0].sha256-ceq$events[1].sha256-and($events[0].argv|ConvertTo-Json -Compress)-ceq($events[1].argv|ConvertTo-Json -Compress)) 'Output probe retry changed bytes or argv.'
        Assert-P105 ((Events-P105 $r encode).Count-eq1-and(Events-P105 $r validate).Count-eq1) 'Output probe retry reran encode or validation.'
        $case.exit_code=0;$case.output_probe_processes=2;$case.encode_processes=1;$case.identical_completed_bytes=$true
    }
    foreach($fixture in @($fixtureMp3,$fixtureOgg)){
        $kind=[IO.Path]::GetExtension($fixture).TrimStart('.')
        Case-P105 ($kind+'-source-probe-once-crash-retries-without-remux') {param($case)
            $r=App-P105 -Name ($kind+'-probe-once') -Stage source-probe -Mode once -Fixture $fixture;Verify-P105 $r 1
            $events=Assert-OneRetry-P105 $r source-probe
            Assert-P105 (($events[0].argv|ConvertTo-Json -Compress)-ceq($events[1].argv|ConvertTo-Json -Compress)-and(Events-P105 $r 'recovery-remux').Count-eq0) 'Source retry changed argv or used a format-specific recovery.'
            $case.exit_code=0;$case.source_probe_processes=2;$case.remux_processes=0
        }
    }
    Case-P105 'm4a-source-probe-keeps-bounded-stream-copy-recovery' {param($case)
        $r=App-P105 -Name m4a-probe-once -Stage source-probe -Mode once -Fixture $fixtureM4a;Verify-P105 $r 1
        Assert-P105 ((Events-P105 $r 'source-probe').Count-eq1-and(Events-P105 $r 'recovery-remux').Count-eq1) 'Existing M4A source recovery did not remain bounded.'
        Assert-P105 (@($r.manifest.records)[0].recovery.status-ceq'Success') 'Existing source recovery receipt absent.'
        $case.exit_code=0;$case.original_source_probe_processes=1;$case.remux_processes=1
    }
    Case-P105 'access-violation-encoder-crash-uses-same-bounded-recovery' {param($case)
        $r=App-P105 -Name encoder-access-violation -Stage encode -Mode once -Fixture $fixtureMp3 -CrashExit 3221225477;Verify-P105 $r 1
        $events=Assert-OneRetry-P105 $r encode
        $case.exit_code=0;$case.encode_processes=2;$case.injected_ntstatus='0xC0000005'
    }
    foreach($stage in @('encode','output-probe','validate','source-probe')){
        Case-P105 ($stage+'-persistent-crash-fails-once-bounded-then-next-input-converts') {param($case)
            $fixture=if($stage-ceq'source-probe'){$fixtureMp3}else{$fixtureM4a}
            $r=App-P105 -Name ('persistent-'+$stage) -Stage $stage -Mode persistent -Fixture $fixture -Expected 2 -FollowingGood $true;Verify-P105 $r 1 1
            $events=Events-P105 $r $stage
            Assert-P105 ($events.Count-eq2-and@($events|Where-Object{$_.action-ceq'persistent'}).Count-eq2) 'Persistent native crash exceeded one retry or was misreported.'
            Assert-P105 ($r.files[0].Name.StartsWith('2024-01-02 - ',[StringComparison]::Ordinal)-and$r.text.Contains([IO.Path]::GetFileName($r.source))) 'Failed file published, failure unnamed, or subsequent good input did not convert.'
            $case.exit_code=2;$case.failed_operation_processes=2;$case.converted=1;$case.failed=1;$case.no_partial_output=$true
        }
    }
    foreach($stage in @('encode','validate','output-probe','source-probe')){
        Case-P105 ($stage+'-ordinary-error-is-not-retried') {param($case)
            $r=App-P105 -Name ('ordinary-'+$stage) -Stage $stage -Mode ordinary -Fixture $fixtureM4a -Expected 2 -FollowingGood $true -ErrorText 'test-only ordinary decode failure';Verify-P105 $r 1 1
            Assert-P105 ((Events-P105 $r $stage).Count-eq1) 'An ordinary native error was retried.'
            $case.exit_code=2;$case.failed_operation_processes=1;$case.converted=1;$case.failed=1
        }
    }
    foreach($message in @('Permission denied','No space left on device')){
        $kind=if($message-ceq'Permission denied'){'access-denied'}else{'disk-full'}
        Case-P105 ('encoder-'+$kind+'-ordinary-exit-is-not-retried') {param($case)
            $r=App-P105 -Name $kind -Stage encode -Mode ordinary -Fixture $fixtureM4a -Expected 2 -ErrorText $message;Verify-P105 $r 0 1
            Assert-P105 ((Events-P105 $r encode).Count-eq1) 'An injected ordinary storage error was retried.'
            $case.exit_code=2;$case.encode_processes=1;$case.injection='ordinary error exit and message; no volume or ACL modification'
        }
    }
    Case-P105 'real-unreadable-input-has-no-retry-and-next-good-input-converts' {param($case)
        $r=App-P105 -Name unreadable -Stage encode -Mode normal -Fixture $fixtureM4a -Expected 2 -Unreadable $true -FollowingGood $true;Verify-P105 $r 1 1
        Assert-P105 ((Events-P105 $r 'source-probe').Count-eq1-and(Events-P105 $r encode).Count-eq0-and(Events-P105 $r 'recovery-remux').Count-eq0) 'Unreadable media entered recovery.'
        $case.exit_code=2;$case.source_probe_processes=1;$case.converted=1;$case.failed=1;$case.no_partial_output=$true
    }
    Case-P105 'actual-duration-mismatch-is-rejected-without-reencode-or-validation-retry' {param($case)
        $r=App-P105 -Name mismatch -Stage encode -Mode duration-mismatch -Fixture $fixtureM4a -Expected 2;Verify-P105 $r 0 1
        Assert-P105 ((Events-P105 $r encode).Count-eq1-and(Events-P105 $r 'output-probe').Count-eq1-and(Events-P105 $r validate).Count-eq0) 'Duration mismatch was retried or decoded despite invalid header duration.'
        $case.exit_code=2;$case.encode_processes=1;$case.failed=1;$case.no_partial_output=$true
    }
    Case-P105 'source-probe-timeout-is-not-retried-and-next-good-input-converts' {param($case)
        $r=App-P105 -Name probe-timeout -Stage source-probe -Mode timeout -Fixture $fixtureM4a -Expected 2 -FollowingGood $true -ProbeTimeoutSeconds 1;Verify-P105 $r 1 1
        Assert-P105 ((Events-P105 $r 'source-probe').Count-eq1-and(Events-P105 $r 'recovery-remux').Count-eq0) 'Timed-out source probe was retried.'
        $case.exit_code=2;$case.source_probe_processes=1;$case.converted=1;$case.failed=1
    }
    Case-P105 'cancelled-transaction-does-not-start-worker-or-publish' {param($case)
        $run=Join-Path $root 'cancelled';[IO.Directory]::CreateDirectory($run)|Out-Null;$out=Join-Path $run 'cancelled.mp3'
        $cancel=New-AudioCancellationContext
        try{$cancel.Request();$r=Invoke-AudioOutputTransaction -OutputPath $out -OutputRoot $run -SourcePath $fixtureM4a -SourceDurationSeconds 1.5 -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -EncodeArguments @() -Cancellation $cancel}
        finally{$cancel.Dispose()}
        Assert-P105 ($r.Status-ceq'Cancelled'-and$null-eq$r.EncoderResult-and-not(Test-Path -LiteralPath $out)-and@(Get-ChildItem -LiteralPath $run -Force).Count-eq0) 'Cancellation started a worker or left output.'
        $case.status_code='Cancelled';$case.workers_started=0;$case.no_partial_output=$true
    }
    Case-P105 'preexisting-final-output-is-preserved-without-starting-worker' {param($case)
        $run=Join-Path $root 'occupied';[IO.Directory]::CreateDirectory($run)|Out-Null;$out=Join-Path $run 'occupied.mp3';Write-P105 $out 'unrelated existing bytes';$before=Hash-P105 $out
        $r=Invoke-AudioOutputTransaction -OutputPath $out -OutputRoot $run -SourcePath $fixtureM4a -SourceDurationSeconds 1.5 -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath -EncodeArguments @() -Cancellation $null
        Assert-P105 ($r.Status-cne'Success'-and$null-eq$r.EncoderResult-and(Hash-P105 $out)-ceq$before-and@(Get-ChildItem -LiteralPath $run -Force).Count-eq1) 'Occupied final output changed or a worker started.'
        $case.workers_started=0;$case.existing_bytes_unchanged=$true
    }
    $report.runtime_unchanged=(($sourceBefore|ConvertTo-Json -Compress)-ceq((Inventory-P105 $runtime)|ConvertTo-Json -Compress))
    $report.synthetic_unchanged=(($fixtureBefore|ConvertTo-Json -Compress)-ceq((Inventory-P105 @($fixtureM4a,$fixtureMp3,$fixtureOgg,$cover))|ConvertTo-Json -Compress))
    Assert-P105 ($report.runtime_unchanged-and$report.synthetic_unchanged) 'Source integrity check failed.'
    $report.status='pass';$exitCode=0
}catch{$report.error=$_.Exception.Message;Write-Warning $report.error}
finally{
    $report.descendant_release_proved=$released
    try{
        Assert-P105 $released 'Cleanup refused: child release not proved.'
        if($created){
            $full=[IO.Path]::GetFullPath($root)
            Assert-P105 ($full-ceq$root-and[IO.Path]::GetDirectoryName($full)-ieq$tempParent) 'Cleanup scope mismatch.'
            Safe-P105 $root;Assert-P105 ([IO.File]::ReadAllText($marker)-ceq$token) 'Owner marker mismatch.'
            foreach($item in @(Get-ChildItem -LiteralPath $root -Recurse -Force)){Assert-P105 (($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Cleanup refused a reparse child.'}
            Remove-Item -LiteralPath $root -Recurse -Force;$report.cleanup_verified=-not(Test-Path -LiteralPath $root)
        }
    }catch{$report.cleanup_error=$_.Exception.Message;$report.status='fail';$exitCode=1}
    $report.finished_utc=[DateTime]::UtcNow.ToString('o');Write-P105 $evidence ($report|ConvertTo-Json -Depth 16)
}
Write-Host ('PATCH105 recovery: '+$report.status+'; cases='+$report.cases.Count+'; cleanup='+$report.cleanup_verified)
exit $exitCode
