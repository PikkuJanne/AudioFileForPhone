<#
Read-only recovery of one exact retained owner picker run. The original failed
guide report stays unchanged; a successful application run is verified against
the actual selected tracked cover, never an assumed prepared fixture. This does
not open UI or establish BAT, PS7 picker, Cancel, Ctrl+C or final confirmation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SessionRoot,
    [Parameter(Mandatory=$true)][string]$EvidencePath
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\','/')
$evidenceParent=Join-Path $projectRoot 'docs/codex-v1/evidence'
$evidenceFull=[IO.Path]::GetFullPath($EvidencePath)
if([IO.Path]::GetDirectoryName($evidenceFull) -ine $evidenceParent -or
    [IO.Path]::GetFileName($evidenceFull) -cnotmatch '^T20-picker-recovery-(ps51|ps7)-(attempt|final)[0-9]+\.json$'){
    throw 'Evidence must be a fresh T20-picker-recovery-ps51/ps7-attempt/finalN.json in the evidence directory.'
}
if(Test-Path -LiteralPath $evidenceFull){throw 'Refusing to overwrite existing evidence.'}
$stage='identity'
$bindings=New-Object 'System.Collections.Generic.List[object]'
$nativeRuns=New-Object 'System.Collections.Generic.List[object]'
$rawRuns=New-Object 'System.Collections.Generic.List[object]'
$privateRoot=$null
$report=[ordered]@{schema_version=1;task='T20';mode='read_only_existing_physical_picker_recovery';status='fail';
    automated_operator='Codex';physical_tester='Janne Vuorela';
    human_observation_source='Direct user message: tried both PNGs and received the same guide error.';
    human_confirmation='Specific PNG selection reported; final DONE confirmation was not given.';
    started_utc=[DateTime]::UtcNow.ToString('o');finished_utc=$null;tested_commit=$null;
    verification_shell=$PSVersionTable.PSVersion.ToString();verification_edition=$PSVersionTable.PSEdition;
    observed_application_shell=$null;observed_application_edition=$null;observed_apartment=$null;
    application_started_utc=$null;application_finished_utc=$null;application_exit_code=$null;application_status=$null;
    application_launched_by_this_verifier=$false;ui_launched=$false;music_access=$false;personal_directory_enumeration=$false;
    old_guide_status='failed';old_guide_result_unchanged=$false;requested_cover_matches_actual=$false;
    actual_cover=$null;outputs=@();native_verification=@();bindings=@();all_bound_bytes_unchanged=$false;
    runner_snapshot_sha256=$null;private_proof_root_name=$null;private_invocation_sha256=$null;private_raw_verification_sha256=$null;
    retained_private_files=$true;cleanup_attempted=$false;failure_stage=$null;
    limitations=@('Only the retained PS5.1 STA Select run is recovered; running this verifier in PS7 does not establish a PS7 picker observation.',
        'Original guide failure and missing final owner confirmation remain unchanged.',
        'BAT observation was empty; selected BAT shell/exit/Music root were not captured and no Music was inspected.',
        'No physical Cancel, Ctrl+C, manual listening or phone observation is established.',
        'Actual selected cover is hashed before/after recovery, not retrospectively before its original selection.')}
function Assert-Recovery{param([bool]$Condition,[string]$Message);if(-not $Condition){throw $Message}}
function Full-RecoveryPath{param([string]$Path)
    Assert-Recovery (-not [string]::IsNullOrWhiteSpace($Path) -and $Path -match '^[A-Za-z]:[\\/]' -and -not $Path.StartsWith('\\')) 'An ordinary absolute drive path is required.'
    return [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}
function Assert-RecoveryNoReparse{param([string]$Path)
    $next=Full-RecoveryPath $Path
    while($next){$item=Get-Item -LiteralPath $next -Force;Assert-Recovery (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.';$next=[IO.Path]::GetDirectoryName($next)}
}
function Within-Recovery{param([string]$Path,[string]$Parent)
    $full=Full-RecoveryPath $Path;$scope=Full-RecoveryPath $Parent
    Assert-Recovery ($full.StartsWith($scope+'\',[StringComparison]::OrdinalIgnoreCase)) 'Exact owned boundary violation.'
    return $full
}
function Hash-Recovery{param([string]$Path)
    Assert-RecoveryNoReparse $Path
    Assert-Recovery (-not (Get-Item -LiteralPath $Path -Force).PSIsContainer) 'A regular file is required.'
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Bind-Recovery{param([string]$Label,[string]$Path,[string]$Expected)
    $hash=Hash-Recovery $Path;if($Expected){Assert-Recovery ($hash -ceq $Expected) ('Bound bytes differ: '+$Label)}
    $bindings.Add([pscustomobject]@{label=$Label;path=$Path;before_sha256=$hash;after_sha256=$null;unchanged=$false})
    return $hash
}
function Write-RecoveryNew{param([string]$Path,[string]$Text)
    Assert-RecoveryNoReparse ([IO.Path]::GetDirectoryName($Path))
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush()}finally{$stream.Dispose()}
}
function Invoke-RecoveryNative{param([string]$Label,[string]$Executable,[string[]]$Arguments)
    $context=New-AudioCancellationContext;$deadline=New-Object T20PickerRecovery.Deadline($context)
    try{
        $result=Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Cancellation $context -MaxStdoutChars 1048576 -MaxStderrChars 65536
        $rawRuns.Add([pscustomobject]@{label=$Label;executable=$Executable;arguments=$Arguments;result=$result})
        $nativeRuns.Add([pscustomobject]@{label=$Label;deadline_ms=30000;status=$result.Status;exit_code=$result.ExitCode;
            process_released=$result.ProcessReleased;elapsed_ms=$result.DurationMilliseconds;stdout_truncated=$result.StdoutTruncated;stderr_truncated=$result.StderrTruncated})
        Assert-Recovery ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 0 -and $result.ProcessReleased -and
            -not $result.StdoutTruncated -and -not $result.StderrTruncated) ('Independent bounded verification failed: '+$Label)
        return $result
    }finally{$deadline.Dispose();$context.Dispose()}
}
function Probe-Recovery{param([string]$Label,[string]$Path)
    return ((Invoke-RecoveryNative $Label $preparation.tools.ffprobe.path @('-v','error','-show_streams','-show_format','-of','json','-i',$Path)).Stdout|ConvertFrom-Json)
}
function Seconds-Recovery{param([object]$Value)
    $number=[double]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)
    Assert-Recovery ($number -gt 0 -and -not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) 'Finite positive duration is required.'
    return $number
}
try{
    $session=Full-RecoveryPath $SessionRoot
    Assert-Recovery ($session -ieq (Join-Path ([IO.Path]::GetTempPath()) 'T20G-6190484c')) 'Only the exact user-provided retained session is supported.'
    Assert-RecoveryNoReparse $session
    $originalPath=Join-Path $session 'guided-result.json';$originalHash=Bind-Recovery 'original_failed_guide' $originalPath
    $original=Get-Content -Raw -Encoding UTF8 -LiteralPath $originalPath|ConvertFrom-Json
    Assert-Recovery ($original.kind -ceq 'T20.GuidedPhysicalSession' -and $original.status -ceq 'failed' -and
        $original.tester -ceq 'Janne Vuorela' -and $original.results_root -ieq $session -and
        $original.error -ceq 'Actual picker result differs from the requested physical action.' -and
        [string]::IsNullOrWhiteSpace($original.bat.owner_observation) -and $original.human_confirmation -ceq 'pending' -and
        @($original.picker_cases).Count -eq 0 -and @($original.cancellation_cases).Count -eq 0) 'Original failed report identity differs.'
    Bind-Recovery 'session_owner_marker' (Join-Path $session '.t20-guided-owner') $original.owner_marker_sha256|Out-Null
    Bind-Recovery 'original_session_start' (Join-Path $session 'session-start.json')|Out-Null
    $preparationPath=Full-RecoveryPath $original.preparation_path
    Assert-Recovery ($preparationPath -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence/T20-preparation-ps7.json')) 'Unexpected preparation record.'
    Bind-Recovery 'preparation_report' $preparationPath $original.preparation_sha256|Out-Null
    $preparation=Get-Content -Raw -Encoding UTF8 -LiteralPath $preparationPath|ConvertFrom-Json
    $prepared=Full-RecoveryPath $preparation.ownership.root
    Assert-Recovery ($preparation.status -ceq 'prepared' -and $preparation.ownership.exclusive_directory -and
        (Split-Path -Parent $prepared) -ieq ([IO.Path]::GetTempPath().TrimEnd('\')) -and
        (Split-Path -Leaf $prepared) -cmatch '^AudioFileForPhone-T20-Manual-[a-f0-9]{32}$') 'Preparation scope lacks recorded ownership.'
    Bind-Recovery 'preparation_owner_marker' (Join-Path $prepared '.t20-manual-owner') $preparation.ownership.marker_sha256|Out-Null
    Bind-Recovery 'original_preparation_copy' (Join-Path $prepared 'preparation.json') $original.preparation_sha256|Out-Null
    $configurationPath=Join-Path $session 'PS51Select-config.json';Bind-Recovery 'picker_configuration' $configurationPath|Out-Null
    $configuration=Get-Content -Raw -Encoding UTF8 -LiteralPath $configurationPath|ConvertFrom-Json
    $capturePath=Join-Path $session 'PS51Select.json';Bind-Recovery 'original_picker_capture' $capturePath|Out-Null
    $capture=Get-Content -Raw -Encoding UTF8 -LiteralPath $capturePath|ConvertFrom-Json
    $driverPath=Join-Path $session 'picker.ps1';Bind-Recovery 'original_picker_driver' $driverPath|Out-Null
    $rawPath=Join-Path $session 'PS51Select.log';Bind-Recovery 'original_picker_raw_log' $rawPath|Out-Null
    Assert-Recovery ($configuration.label -ceq 'PS51Select' -and $configuration.action -ceq 'Select' -and
        $configuration.owner_marker -ieq (Join-Path $session '.t20-guided-owner') -and
        $configuration.owner_marker_sha256 -ceq $original.owner_marker_sha256 -and
        $configuration.input_path -ieq $preparation.paths.special_input -and $configuration.output_parent -ieq (Join-Path $session 'O1') -and
        $configuration.entry -ieq (Join-Path $preparation.paths.application_directory 'AudioFileForPhone.ps1') -and
        $configuration.helper -ieq (Join-Path $preparation.paths.application_directory 'AudioFileForPhone.Helpers.ps1')) 'Unexpected picker configuration.'
    Assert-Recovery ($capture.kind -ceq 'T20.GuidedPicker' -and $capture.label -ceq 'PS51Select' -and
        $capture.status -ceq 'captured' -and $capture.exit_code -eq 0 -and $capture.apartment -ceq 'STA' -and
        $capture.shell_edition -ceq 'Desktop' -and $capture.shell_version -ceq '5.1.26100.9444' -and
        $capture.launched_executable -ieq (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -and
        $capture.human_action_requested -ceq 'Select' -and $capture.human_confirmation -ceq 'pending') 'Actual retained shell/action capture differs.'
    foreach($source in $preparation.sources){
        Assert-Recovery (@('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1','AudioFileForPhone.bat') -ccontains $source.name) 'Unexpected application file.'
        Bind-Recovery ('source_'+$source.name) (Join-Path $projectRoot $source.name) $source.source_sha256|Out-Null
        Bind-Recovery ('copy_'+$source.name) (Within-Recovery $source.copy_path $prepared) $source.source_sha256|Out-Null
    }
    Assert-Recovery ($capture.entry_before -ceq $configuration.entry_sha256 -and $capture.entry_after -ceq $configuration.entry_sha256 -and
        $capture.helper_before -ceq $configuration.helper_sha256 -and $capture.helper_after -ceq $configuration.helper_sha256) 'Captured application byte preservation failed.'
    foreach($input in $preparation.inputs){Bind-Recovery ('prepared_'+$input.kind+'_'+[array]::IndexOf(@($preparation.inputs),$input)) (Within-Recovery $input.path $prepared) $input.sha256|Out-Null}
    foreach($name in @('ffmpeg','ffprobe')){
        Bind-Recovery ('installed_'+$name) $preparation.tools.$name.path $preparation.tools.$name.sha256|Out-Null
        Bind-Recovery ('adjacent_'+$name) (Join-Path $preparation.paths.application_directory ($name+'.exe')) $preparation.tools.$name.sha256|Out-Null
    }
    $outputRoot=Within-Recovery $capture.output_root $configuration.output_parent
    Assert-Recovery ((Split-Path -Parent $outputRoot) -ieq $configuration.output_parent) 'Output is not a direct owned child.'
    $outputMarkerPath=Join-Path $outputRoot '.AudioFileForPhone-output.json';Bind-Recovery 'output_owner_marker' $outputMarkerPath|Out-Null
    $outputMarker=Get-Content -Raw -Encoding UTF8 -LiteralPath $outputMarkerPath|ConvertFrom-Json
    Assert-Recovery ($outputMarker.kind -ceq 'AudioFileForPhone.Output' -and $outputMarker.output_root -ieq $outputRoot -and
        $outputMarker.cleanup_scope -ieq $outputRoot -and $outputMarker.ownership_token -cmatch '^[a-f0-9]{32}$') 'Output ownership identity differs.'
    $manifestPath=Join-Path $outputRoot 'AudioFileForPhone_manifest.json';Bind-Recovery 'original_application_manifest' $manifestPath|Out-Null
    $manifest=Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath|ConvertFrom-Json
    Assert-Recovery ($manifest.kind -ceq 'AudioFileForPhone.RunManifest' -and $manifest.checkpoint -ceq 'Final' -and
        $manifest.run.output_root -ieq $outputRoot -and $manifest.run.input_root -ieq $configuration.input_path -and
        $manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and
        $manifest.build.entry_sha256 -ceq $capture.entry_before -and $manifest.build.helper_sha256 -ceq $capture.helper_before -and
        $manifest.totals.supported -eq 3 -and $manifest.totals.converted -eq 3 -and $manifest.totals.failed -eq 0 -and @($manifest.records).Count -eq 3) 'Actual manifest was not a completed three-input unchanged application run.'
    $coverPath=Full-RecoveryPath $manifest.policies.metadata.cover_path
    Assert-Recovery ($coverPath -ieq (Join-Path $projectRoot 'AudioFileForPhone_poster.png')) 'Recovery is limited to the actual selected tracked repository poster.'
    $coverHash=Bind-Recovery 'actual_selected_repository_cover' $coverPath
    Assert-Recovery ($coverPath -ine $configuration.cover_path) 'Expected recovery condition did not occur.'
    $rawText=Get-Content -Raw -Encoding UTF8 -LiteralPath $rawPath
    Assert-Recovery (-not $rawText.Contains('Could not open file picker.') -and -not $rawText.Contains('Selected cover failed validation:')) 'Actual picker was unavailable or invalid.'
    $report.observed_application_shell=$capture.shell_version;$report.observed_application_edition=$capture.shell_edition;$report.observed_apartment=$capture.apartment
    $report.application_started_utc=$capture.started_utc;$report.application_finished_utc=$capture.finished_utc;$report.application_exit_code=$capture.exit_code;$report.application_status=$manifest.run.status
    $stage='independent_verification'
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    if(-not ('T20PickerRecovery.Deadline' -as [type])){Add-Type -TypeDefinition @'
using System; using System.Threading;
namespace T20PickerRecovery { public sealed class Deadline : IDisposable {
 private readonly Timer timer;
 public Deadline(object context) { timer=new Timer(delegate { context.GetType().GetMethod("Request").Invoke(context,null); },null,30000,Timeout.Infinite); }
 public void Dispose(){timer.Dispose();}
} }
'@}
    $privateRoot=Join-Path ([IO.Path]::GetTempPath()) ('T20R-'+[guid]::NewGuid().ToString('N').Substring(0,12))
    Assert-RecoveryNoReparse ([IO.Path]::GetDirectoryName($privateRoot))
    Assert-Recovery ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($privateRoot,[IntPtr]::Zero)) 'Could not reserve exclusive proof directory.'
    Write-RecoveryNew (Join-Path $privateRoot '.t20-recovery-owner') ([guid]::NewGuid().ToString('N'))
    Bind-Recovery 'recovery_owner_marker' (Join-Path $privateRoot '.t20-recovery-owner')|Out-Null
    $runnerHash=Bind-Recovery 'working_recovery_runner' $PSCommandPath
    $snapshot=Join-Path $privateRoot 'runner.ps1';[IO.File]::Copy($PSCommandPath,$snapshot,$false)
    $report.runner_snapshot_sha256=Bind-Recovery 'exact_runner_snapshot' $snapshot $runnerHash
    $invocationPath=Join-Path $privateRoot 'invocation.json'
    Write-RecoveryNew $invocationPath (([ordered]@{command_line=[Environment]::CommandLine;session_root=$session;evidence_path=$evidenceFull;verification_shell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
    $report.private_invocation_sha256=Bind-Recovery 'private_actual_invocation' $invocationPath
    $report.private_proof_root_name=Split-Path -Leaf $privateRoot
    $git=(Get-Command git.exe -CommandType Application|Select-Object -First 1).Source
    $report.tested_commit=(Invoke-RecoveryNative 'current_application_repository_head' $git @('-C',$projectRoot,'rev-parse','HEAD')).Stdout.Trim()
    Assert-Recovery ($report.tested_commit -cmatch '^[a-f0-9]{40}$') 'Repository head unavailable.'
    $tracked=(Invoke-RecoveryNative 'actual_cover_is_tracked' $git @('-C',$projectRoot,'ls-files','--error-unmatch','--','AudioFileForPhone_poster.png')).Stdout.Trim()
    Assert-Recovery ($tracked -ceq 'AudioFileForPhone_poster.png') 'Actual selected cover is not the intended tracked file.'
    $cover=Probe-Recovery 'actual_cover_probe' $coverPath;$coverVideo=@($cover.streams|Where-Object{$_.codec_type -ceq 'video'})
    Assert-Recovery ($coverVideo.Count -eq 1 -and $coverVideo[0].codec_name -ceq 'png' -and $coverVideo[0].width -eq 2816 -and $coverVideo[0].height -eq 1536) 'Actual cover technical identity differs.'
    Invoke-RecoveryNative 'actual_cover_full_decode' $preparation.tools.ffmpeg.path @('-nostdin','-v','error','-xerror','-i',$coverPath,'-map','0:v:0','-frames:v','1','-f','null','NUL')|Out-Null
    $report.actual_cover=[pscustomobject]@{public_tracked_name='AudioFileForPhone_poster.png';sha256=$coverHash;bytes=(Get-Item -LiteralPath $coverPath).Length;codec='png';width=2816;height=1536;independent_full_decode=$true;requested_fixture_width=64;requested_fixture_height=64;original_picker_cover_path_matches_requested=$false}
    $stack=New-Object 'System.Collections.Generic.Stack[string]';$stack.Push($outputRoot);$mp3Count=0
    while($stack.Count){foreach($item in @(Get-ChildItem -LiteralPath $stack.Pop() -Force)){
        Assert-RecoveryNoReparse $item.FullName
        if($item.PSIsContainer){$stack.Push($item.FullName)}else{
            Assert-Recovery ($item.Extension -ine '.partial') 'A partial output remains.'
            if($item.Extension -ieq '.mp3'){$mp3Count++}
        }
    }}
    Assert-Recovery ($mp3Count -eq 3) 'Exact owned output has a different MP3 count.'
    $number=0
    foreach($row in $manifest.records){
        $number++;$label='output_'+$number
        Assert-Recovery ($row.status -ceq 'Converted') 'A manifest row did not convert.'
        $inputPath=Within-Recovery (Join-Path $configuration.input_path $row.source_relative_path) $configuration.input_path
        $outputPath=Within-Recovery (Join-Path $outputRoot $row.output_relative_path) $outputRoot
        $expectedDirectory=Split-Path -Leaf $configuration.input_path;$relativeDirectory=[IO.Path]::GetDirectoryName([string]$row.source_relative_path)
        if($relativeDirectory){$expectedDirectory=Join-Path $expectedDirectory $relativeDirectory}
        Assert-Recovery ([IO.Path]::GetDirectoryName([string]$row.output_relative_path) -ieq $expectedDirectory -and
            [IO.Path]::GetFileName($outputPath) -cmatch '^2026-10-11 - .+\.mp3$') 'Recursive layout/date-first name differs.'
        $inputHash=Bind-Recovery ($label+'_source') $inputPath
        $outputHash=Bind-Recovery $label $outputPath
        $sourceProbe=Probe-Recovery ($label+'_source_probe') $inputPath;$probe=Probe-Recovery ($label+'_probe') $outputPath
        $audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'});$art=@($probe.streams|Where-Object{$_.codec_type -ceq 'video' -and $_.disposition.attached_pic -eq 1})
        $sourceAudio=@($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'audio'})
        $title=[string]$sourceProbe.format.tags.title;if([string]::IsNullOrWhiteSpace($title)){$title=[string]$sourceAudio[0].tags.title}
        Assert-Recovery (-not [string]::IsNullOrWhiteSpace($title) -and $sourceAudio.Count -eq 1 -and $audio.Count -eq 1 -and
            $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000 -and
            $probe.format.tags.title -ceq $title -and $probe.format.tags.artist -ceq $configuration.artist -and
            $probe.format.tags.album -ceq $configuration.album -and $art.Count -eq 1 -and
            $art[0].width -eq $coverVideo[0].width -and $art[0].height -eq $coverVideo[0].height) 'Independent tags/audio/artwork differs from actual selected cover.'
        $sourceSeconds=Seconds-Recovery $(if($sourceAudio[0].duration){$sourceAudio[0].duration}else{$sourceProbe.format.duration})
        $outputSeconds=Seconds-Recovery $audio[0].duration
        Assert-Recovery ([math]::Abs($sourceSeconds-$outputSeconds) -le 0.35) 'Independent audio duration mismatch.'
        Invoke-RecoveryNative ($label+'_full_audio_decode') $preparation.tools.ffmpeg.path @('-nostdin','-v','error','-xerror','-i',$outputPath,'-map','0:a:0','-f','null','NUL')|Out-Null
        Invoke-RecoveryNative ($label+'_full_art_decode') $preparation.tools.ffmpeg.path @('-nostdin','-v','error','-xerror','-i',$outputPath,'-map','0:v:0','-frames:v','1','-f','null','NUL')|Out-Null
        $report.outputs+=[pscustomobject]@{id=$label;source_extension=[IO.Path]::GetExtension($inputPath).ToLowerInvariant();source_sha256=$inputHash;output_sha256=$outputHash;bytes=(Get-Item -LiteralPath $outputPath).Length;
            codec='mp3';bitrate_bps=64000;sample_rate=[int]$audio[0].sample_rate;channels=[int]$audio[0].channels;source_duration_seconds=$sourceSeconds;output_duration_seconds=$outputSeconds;
            original_title_preserved=$true;artist_matches_configured=$true;album_matches_configured=$true;recursive_layout_preserved=$true;date_first_name=$true;
            attached_art_count=1;attached_art_codec=$art[0].codec_name;attached_art_width=$art[0].width;attached_art_height=$art[0].height;full_audio_decode=$true;full_art_decode=$true}
    }
    $stage='preservation'
    foreach($binding in $bindings){$binding.after_sha256=Hash-Recovery $binding.path;$binding.unchanged=$binding.before_sha256 -ceq $binding.after_sha256;Assert-Recovery $binding.unchanged ('Bound bytes changed: '+$binding.label)}
    $report.old_guide_result_unchanged=(Hash-Recovery $originalPath) -ceq $originalHash
    $report.all_bound_bytes_unchanged=$true;$report.status='pass'
}catch{
    $report.failure_stage=$stage
    Write-Warning ('Picker recovery failed at stage '+$stage+'. The original report remains unchanged; private diagnostics stay outside Git.')
    if($privateRoot){Write-RecoveryNew (Join-Path $privateRoot 'failure.txt') ($_.Exception.ToString()+[Environment]::NewLine)}
}finally{
    if($privateRoot){
        $privateRaw=Join-Path $privateRoot 'verification-raw.json'
        Write-RecoveryNew $privateRaw (([ordered]@{native_runs=$rawRuns.ToArray();private_bindings=$bindings.ToArray()}|ConvertTo-Json -Depth 15)+[Environment]::NewLine)
        $report.private_raw_verification_sha256=Hash-Recovery $privateRaw
    }
    $report.native_verification=$nativeRuns.ToArray()
    $report.bindings=@($bindings|ForEach-Object{[pscustomobject]@{label=$_.label;before_sha256=$_.before_sha256;after_sha256=$_.after_sha256;unchanged=$_.unchanged}})
    $report.finished_utc=[DateTime]::UtcNow.ToString('o')
    Write-RecoveryNew $evidenceFull (($report|ConvertTo-Json -Depth 14)+[Environment]::NewLine)
}
Write-Host ('T20 actual PS5.1 picker recovery: '+$report.status+'; public report: '+[IO.Path]::GetFileName($evidenceFull))
if($report.status -ne 'pass'){exit 1}
exit 0
