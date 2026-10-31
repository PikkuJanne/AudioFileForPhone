<#
Synthetic Windows regression for the native source-probe crash path. A compiled
test-only shim emits the recorded NTSTATUS only for one selected source probe;
all media reads, stream-copy recovery, MP3 encoding and full decode use real tools.
Runtime sources are unchanged. Reports/media stay in an owned external scope.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EvidencePath,
    [string]$FfmpegPath='C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath='C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$evidence=[IO.Path]::GetFullPath($EvidencePath)
$parent=[IO.Path]::GetDirectoryName($evidence)
$root=Join-Path ([IO.Path]::GetTempPath()) ('AFP-P104-'+[guid]::NewGuid().ToString('N'))
$marker=Join-Path $root '.patch104-owner';$token=[guid]::NewGuid().ToString('N')
$created=$false;$released=$true;$exitCode=1
$report=[ordered]@{schema_version=1;task='PATCH104';mode='synthetic_native_source_probe_recovery';status='fail';shell=$PSVersionTable.PSVersion.ToString();tested_commit=(& git -C $project rev-parse HEAD|Out-String).Trim();started_utc=[DateTime]::UtcNow.ToString('o');environment=$null;cases=@();source_unchanged=$false;synthetic_unchanged=$false;descendant_release_proved=$false;cleanup_verified=$false;owner_media_access=$false;ordinary_music_access=$false}
function Assert-P104([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash-P104([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-P104([string]$Path,[string]$Value){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=(New-Object Text.UTF8Encoding($false)).GetBytes($Value);$s.Write($b,0,$b.Length)}finally{$s.Dispose()}}
function Inventory-P104([string[]]$Paths){@($Paths|ForEach-Object{[pscustomobject]@{path=$_;sha256=Hash-P104 $_}})}
function Safe-P104([string]$Path){$p=[IO.Path]::GetFullPath($Path);while($p){if(Test-Path -LiteralPath $p){Assert-P104 (((Get-Item -LiteralPath $p -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Reparse path refused.'};$p=[IO.Path]::GetDirectoryName($p)}}
function Run-P104([string]$Exe,[string[]]$Arguments,[int[]]$Allowed=@(0),[hashtable]$Environment=@{}){
    $saved=@{};foreach($key in $Environment.Keys){$saved[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
    try{
        foreach($key in $Environment.Keys){[Environment]::SetEnvironmentVariable($key,[string]$Environment[$key],'Process')}
        $r=Invoke-AudioNativeProcess -ExecutablePath $Exe -Arguments $Arguments -Operation 'Patch104 test child' -TimeoutMilliseconds 120000
    }finally{foreach($key in $saved.Keys){[Environment]::SetEnvironmentVariable($key,$saved[$key],'Process')}}
    if(-not$r.ProcessReleased-or-not$r.PipeDrainCompleted){$script:released=$false}
    Assert-P104 ($r.Status-eq'Completed'-and$r.ProcessReleased-and$r.PipeDrainCompleted-and$Allowed-contains$r.ExitCode) ('Native test child failed: '+$r.Status+' exit='+$r.ExitCode+' '+$r.Stderr+' '+$r.Error+' '+$r.Stdout)
    return $r
}
function Case-P104([string]$Name,[scriptblock]$Body){$case=[ordered]@{name=$Name;status='fail'};try{& $Body $case;$case.status='pass'}finally{$report.cases+=[pscustomobject]$case}}
function Media-P104([string]$Path){(Run-P104 $FfprobePath @('-v','error','-show_streams','-show_format','-of','json','-i',$Path)).Stdout|ConvertFrom-Json}
function App-P104([string]$Name,[string]$Mode,[string]$Source,[string]$Fixture,[int]$Expected,[bool]$Mixed=$false){
    $caseRoot=Join-Path $root $Name;$input=Join-Path $caseRoot 'input';$output=Join-Path $caseRoot 'output';$temp=Join-Path $caseRoot 'temp'
    foreach($p in @($caseRoot,$input,$output,$temp)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $sourcePath=Join-Path $input $Source;[IO.File]::Copy($Fixture,$sourcePath)
    if($Mixed){[IO.File]::WriteAllText((Join-Path $input '2024-01-01 - Unreadable.m4a'),'synthetic invalid m4a')}
    $before=Inventory-P104 @(Get-ChildItem -LiteralPath $input -File|ForEach-Object{$_.FullName})
    $log=Join-Path $caseRoot 'shim.tsv'
    $environment=@{AFP_PATCH104_REAL_FFMPEG=$FfmpegPath;AFP_PATCH104_REAL_FFPROBE=$FfprobePath;AFP_PATCH104_CRASH_SOURCE=$sourcePath;AFP_PATCH104_MODE=$Mode;AFP_PATCH104_SHIM_LOG=$log;TEMP=$temp;TMP=$temp;USERPROFILE=(Join-Path $caseRoot 'profile');LOCALAPPDATA=(Join-Path $caseRoot 'local');APPDATA=(Join-Path $caseRoot 'roaming');FFMPEG='';PATH=''}
    $a=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $project 'AudioFileForPhone.ps1'),'-InputFolder',$input,'-OutputParent',$output,'-FfmpegDirectory',$shimRoot,'-ConfigPath',(Join-Path $caseRoot 'missing.json'),'-Artist','Patch104 artist','-Album','Patch104 album','-CoverPath',$cover)
    $r=Run-P104 $shell $a @($Expected) $environment
    $text=$r.Stdout+"`n"+$r.Stderr;Write-P104 (Join-Path $caseRoot 'console.txt') $text
    $manifests=@(Get-ChildItem -LiteralPath $output -Recurse -File|Where-Object{$_.Name-ceq'AudioFileForPhone_manifest.json'})
    Assert-P104 ($manifests.Count-eq1) 'One run manifest required.'
    $manifest=Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8|ConvertFrom-Json
    $lines=@([IO.File]::ReadAllLines($log));$crashes=@($lines|Where-Object{$_-match'\tprobe-crash\t'});$remuxes=@($lines|Where-Object{$_-match'\trecovery-remux\t'})
    $files=@(Get-ChildItem -LiteralPath $output -Recurse -File|Where-Object{$_.Extension-ieq'.mp3'})
    $partials=@(Get-ChildItem -LiteralPath $output -Recurse -Force|Where-Object{$_.Extension-ieq'.partial'-or$_.Name-like'.AudioFileForPhone-recovery-*'})
    Assert-P104 ($partials.Count-eq0) 'No partial or recovery working files may remain after released children.'
    Assert-P104 (($before|ConvertTo-Json -Compress)-ceq((Inventory-P104 @(Get-ChildItem -LiteralPath $input -File|ForEach-Object{$_.FullName}))|ConvertTo-Json -Compress)) 'Synthetic original bytes changed.'
    return [pscustomobject]@{native=$r;manifest=$manifest;text=$text;crashes=$crashes.Count;remuxes=$remuxes.Count;files=$files;lines=$lines;source=$sourcePath}
}
function Verify-P104([object]$Run,[int]$Count){
    Assert-P104 ($Run.files.Count-eq$Count) 'Incorrect finished output count.'
    foreach($file in $Run.files){
        $m=Media-P104 $file.FullName;$audio=@($m.streams|Where-Object{$_.codec_type-eq'audio'});$art=@($m.streams|Where-Object{$_.disposition.attached_pic-eq1})
        Assert-P104 ($audio.Count-eq1-and$audio[0].codec_name-eq'mp3'-and[long]$audio[0].bit_rate-eq64000-and[int]$audio[0].sample_rate-eq44100-and[int]$audio[0].channels-eq2-and$art.Count-eq1) 'Recovered output audio shape/cover mismatch.'
        Assert-P104 ($m.format.tags.title-ceq'Patch104 source title'-and$m.format.tags.artist-ceq'Patch104 artist'-and$m.format.tags.album-ceq'Patch104 album') 'Original title or batch metadata lost.'
        $null=Run-P104 $FfmpegPath @('-nostdin','-v','error','-xerror','-err_detect','explode','-i',$file.FullName,'-map','0:a:0','-f','null','NUL')
        Assert-P104 ($file.Name.StartsWith('2024-01-02 - ',[StringComparison]::Ordinal)) 'Original date/name did not survive recovery.'
    }
}
try{
    Assert-P104 ([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT) 'Windows required.'
    Safe-P104 $parent;Safe-P104 ([IO.Path]::GetTempPath())
    Assert-P104 ([IO.Directory]::Exists($parent)-and-not(Test-Path -LiteralPath $evidence)-and-not$evidence.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Fresh report must remain outside Git.'
    . (Join-Path $project 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop;$created=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($root,[IntPtr]::Zero);Assert-P104 $created 'Exclusive TEMP reservation failed.';Write-P104 $marker $token
    $FfmpegPath=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$FfprobePath=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $shell=Join-Path $PSHOME 'powershell.exe';if(-not[IO.File]::Exists($shell)){$shell=Join-Path $PSHOME 'pwsh.exe'}
    $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.environment=[ordered]@{windows_build=$cv.CurrentBuildNumber+'.'+$cv.UBR;ffmpeg=(Run-P104 $FfmpegPath @('-version')).Stdout.Split([char]10)[0].Trim();ffprobe=(Run-P104 $FfprobePath @('-version')).Stdout.Split([char]10)[0].Trim();crash_coverage='forced native 0xC0000409 only; no historical-build reproduction claim'}
    $runtime=@('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1','AudioFileForPhone.Diagnostics.ps1')|ForEach-Object{Join-Path $project $_}
    $sourceBefore=Inventory-P104 $runtime
    $shimRoot=Join-Path $root 'shim';[IO.Directory]::CreateDirectory($shimRoot)|Out-Null
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $null=Run-P104 $csc @('/nologo','/target:exe',('/out:'+(Join-Path $shimRoot 'ffprobe.exe')),(Join-Path $PSScriptRoot 'Patch104.NativeShim.cs'))
    [IO.File]::Copy((Join-Path $shimRoot 'ffprobe.exe'),(Join-Path $shimRoot 'ffmpeg.exe'))
    $fixture=Join-Path $root 'fixture.m4a';$mp3=Join-Path $root 'fixture.mp3';$cover=Join-Path $root 'cover.jpg'
    # Audio is stream index1 in the original; recovered M4A audio becomes index0.
    $null=Run-P104 $FfmpegPath @('-nostdin','-v','error','-f','lavfi','-i','color=c=black:s=16x16:r=5:d=1.5','-f','lavfi','-i','sine=frequency=733:sample_rate=44100:duration=1.5','-map','0:v:0','-map','1:a:0','-c:v','mpeg4','-c:a','aac','-ac','2','-metadata','title=Patch104 source title','-metadata','creation_time=2024-01-02T03:04:05.000000Z',$fixture)
    $null=Run-P104 $FfmpegPath @('-nostdin','-v','error','-i',$fixture,'-map','0:a:0','-c:a','libmp3lame',$mp3)
    Add-Type -AssemblyName System.Drawing;$image=New-Object Drawing.Bitmap(24,24);try{$image.Save($cover,[Drawing.Imaging.ImageFormat]::Jpeg)}finally{$image.Dispose()}
    $fixtureBefore=Inventory-P104 @($fixture,$mp3,$cover)
    Case-P104 'native-crash-classification-excludes-ordinary-failure-and-unproved-termination' {
        param($case)
        $rows=@(
            @{status='Completed';code=-1073740791;released=$true;drained=$true;expected=$true},
            @{status='Completed';code=1;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=0;released=$true;drained=$true;expected=$false},
            @{status='Timeout';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='Cancelled';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='MissingExecutable';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='StartFailed';code=-1073740791;released=$true;drained=$true;expected=$false},
            @{status='Completed';code=-1073740791;released=$false;drained=$true;expected=$false},
            @{status='Completed';code=-1073740791;released=$true;drained=$false;expected=$false}
        )
        foreach($row in $rows){$n=[pscustomobject]@{Status=$row.status;ExitCode=$row.code;ProcessReleased=$row.released;PipeDrainCompleted=$row.drained;Stderr='*** stack smashing detected ***: terminated'};Assert-P104 ((Test-AudioSourceProbeCrash -NativeResult $n)-eq$row.expected) ('Crash classification mismatch: '+($row|ConvertTo-Json -Compress))};$case.rows=$rows.Count
    }
    Case-P104 'iso-date-tags-and-iso-looking-title-stay-readable' {param($case)
        $m=Get-AudioMediaInfo -Path $fixture -FfprobePath $FfprobePath
        Assert-P104 ($m.Status-eq'Success'-and$m.Title-ceq'Patch104 source title') 'Creation-time tag must not invalidate a healthy source probe.'
        $dateTitle=Join-Path $root 'iso-title.m4a';$iso='2024-01-02T03:04:05Z'
        $null=Run-P104 $FfmpegPath @('-nostdin','-v','error','-i',$fixture,'-map','0:a:0','-c:a','copy','-metadata',('title='+$iso),$dateTitle)
        $m=Get-AudioMediaInfo -Path $dateTitle -FfprobePath $FfprobePath
        Assert-P104 ($m.Status-eq'Success'-and$m.Title-is[string]-and$m.Title-ceq$iso) 'ISO-looking title must stay an exact string on every supported shell.'
        $case.creation_time_probe='Success';$case.title=$m.Title
    }
    Case-P104 'healthy-m4a-keeps-normal-conversion-without-recovery' {param($case)
        $r=App-P104 'normal' 'normal' '2024-01-02 - Original.m4a' $fixture 0;Verify-P104 $r 1
        Assert-P104 ($r.crashes-eq0-and$r.remuxes-eq0-and$r.manifest.totals.converted-eq1-and$r.manifest.totals.failed-eq0) 'Healthy source entered recovery.'
        $case.exit_code=$r.native.ExitCode;$case.recovery_attempts=$r.remuxes;$case.full_decode=$true
    }
    Case-P104 'native-crash-recovers-real-audio-and-uses-remux-stream-index' {param($case)
        $r=App-P104 'recover' 'crash' '2024-01-02 - Original.m4a' $fixture 0;Verify-P104 $r 1
        Assert-P104 ($r.crashes-eq1-and$r.remuxes-eq1-and$r.manifest.totals.converted-eq1-and$r.manifest.totals.failed-eq0) 'Forced source crash did not recover exactly once.'
        $record=@($r.manifest.records)[0];Assert-P104 ($record.recovery.attempted-and$record.recovery.status-eq'Success') 'Recovery receipt absent from manifest.'
        Assert-P104 ([math]::Abs([double]$record.input_duration_seconds-[double]$record.decoded_duration_seconds)-le0.35) 'Independent source/output duration tolerance exceeded.'
        $case.exit_code=$r.native.ExitCode;$case.recovery_attempts=$r.remuxes;$case.native_crashes=$r.crashes;$case.source_duration=$record.input_duration_seconds;$case.output_duration=$record.decoded_duration_seconds;$case.full_decode=$true
    }
    Case-P104 'unreadable-m4a-fails-by-name-then-good-converts-normally' {param($case)
        $r=App-P104 'mixed' 'normal' '2024-01-02 - Good.m4a' $fixture 2 $true;Verify-P104 $r 1
        Assert-P104 ($r.remuxes-eq0-and$r.manifest.totals.converted-eq1-and$r.manifest.totals.failed-eq1-and$r.text.Contains('2024-01-01 - Unreadable.m4a')) 'Mixed batch lacks named once-only failure or normal continuation.'
        $case.exit_code=$r.native.ExitCode;$case.converted=1;$case.failed=1;$case.recovery_attempts=0;$case.named_failure=$true;$case.no_partial_output=$true
    }
    Case-P104 'failed-recovery-attempts-once-and-publishes-no-mp3' {param($case)
        $r=App-P104 'fail-remux' 'remux-fail' '2024-01-02 - Original.m4a' $fixture 2
        Assert-P104 ($r.files.Count-eq0-and$r.crashes-eq1-and$r.remuxes-eq1-and$r.manifest.totals.failed-eq1-and$r.text.Contains('2024-01-02 - Original.m4a')) 'Failed recovery looped, lost name or published an output.'
        $case.exit_code=$r.native.ExitCode;$case.recovery_attempts=1;$case.failed=1;$case.no_partial_output=$true
    }
    Case-P104 'shortened-remux-cannot-validate-itself' {param($case)
        $r=App-P104 'short-remux' 'short-remux' '2024-01-02 - Original.m4a' $fixture 2
        Assert-P104 ($r.files.Count-eq0-and$r.crashes-eq1-and$r.remuxes-eq1-and$r.manifest.totals.failed-eq1) 'Shortened remux incorrectly passed independent source-duration validation.'
        Assert-P104 (@($r.manifest.records)[0].recovery.status-eq'RecoveryDurationMismatch') 'Shortened remux must have a named independent-duration failure.'
        $case.exit_code=$r.native.ExitCode;$case.recovery_attempts=1;$case.no_partial_output=$true
    }
    Case-P104 'native-crash-in-mp3-does-not-enter-m4a-recovery' {param($case)
        $r=App-P104 'mp3-crash' 'crash' '2024-01-02 - Original.mp3' $mp3 2
        Assert-P104 ($r.files.Count-eq0-and$r.crashes-eq2-and$r.remuxes-eq0-and$r.manifest.totals.failed-eq1) 'Persistent non-M4A source crash must get one fresh probe, no M4A recovery and no output.'
        $case.exit_code=$r.native.ExitCode;$case.recovery_attempts=0
    }
    $report.source_unchanged=(($sourceBefore|ConvertTo-Json -Compress)-ceq((Inventory-P104 $runtime)|ConvertTo-Json -Compress))
    $report.synthetic_unchanged=(($fixtureBefore|ConvertTo-Json -Compress)-ceq((Inventory-P104 @($fixture,$mp3,$cover))|ConvertTo-Json -Compress))
    Assert-P104 ($report.source_unchanged-and$report.synthetic_unchanged) 'Source integrity check failed.'
    $report.status='pass';$exitCode=0
}catch{$report.error=$_.Exception.Message;Write-Warning $report.error}
finally{
    $report.descendant_release_proved=$released
    try{
        Assert-P104 $released 'Cleanup refused: child release not proved.'
        if($created){$full=[IO.Path]::GetFullPath($root);Assert-P104 ($full-ceq$root-and[IO.Path]::GetDirectoryName($full).TrimEnd('\','/')-ieq[IO.Path]::GetTempPath().TrimEnd('\','/')) 'Cleanup scope mismatch.';Safe-P104 $root;Assert-P104 ([IO.File]::ReadAllText($marker)-ceq$token) 'Owner marker mismatch.';foreach($item in @(Get-ChildItem -LiteralPath $root -Recurse -Force)){Assert-P104 (($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Cleanup refused a reparse child.'};Remove-Item -LiteralPath $root -Recurse -Force;$report.cleanup_verified=-not(Test-Path -LiteralPath $root)}
    }catch{$report.cleanup_error=$_.Exception.Message;$report.status='fail';$exitCode=1}
    $report.finished_utc=[DateTime]::UtcNow.ToString('o');Write-P104 $evidence ($report|ConvertTo-Json -Depth 14)
}
Write-Host ('PATCH104 recovery: '+$report.status+'; cases='+$report.cases.Count+'; cleanup='+$report.cleanup_verified)
exit $exitCode
