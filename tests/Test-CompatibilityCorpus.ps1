<#
S11 complementary short/irregular codec corpus. Sources are generated independently
as lossless ALAC plus representative supported codecs; no ordinary Music folder,
user config or personal media is read. Every encode uses the shared production
plan, builder, staged transaction and full-decode validator. Raw diagnostics stay
inside one exclusively reserved token-owned TEMP tree; reports are create-new.
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
$localReport = $leaf -cmatch "^S11-corpus-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if ($evidenceParent -ine (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -or -not $localReport) {
    throw 'Use a fresh active S11-corpus-ps51/ps7-attempt/finalN.json report.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; select a fresh label.' }
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'AFP11C-' + [guid]::NewGuid().ToString('N').Substring(0, 10)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s11-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1; $originalNative = $null
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$matrix = New-Object 'System.Collections.Generic.List[object]'
$appRuns = New-Object 'System.Collections.Generic.List[object]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat', 'tests/Test-CompatibilityCorpus.ps1')



$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'S11'; mode = 'real_windows_complementary_short_irregular_codec_corpus'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false; physical_manual_evidence = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; runtime_mode = 'direct_production_functions'
    owned_temp_root = $testRoot; cleanup_phase = 'NotStarted'
    cleanup_verified = $false; descendant_release_proved = $false; parent_path_unchanged = $false
    requested_bitrate_kbps = 64; duration_policy_changed = $false; duration_tolerance_seconds = 0.35
    native_runs = @(); tools = @(); encoder_sample_rates = @(); cases = @(); matrix = @(); app_runs = @(); fixture_limitations = @()
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
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
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$Utf8Bom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding($Utf8Bom.IsPresent)
        $preamble = $encoding.GetPreamble(); $stream.Write($preamble, 0, $preamble.Length)
        $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Add-Fixture { param([string]$Path); $fixtures.Add($Path); $report.synthetic_before += Get-Inventory @($Path) $testRoot }
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
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
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased -or -not $native.PipeDrainCompleted) { $script:releaseProved = $false }
        $nativeRuns.Add([pscustomobject]@{
            operation = $native.Operation; status = $native.Status; exit_code = $native.ExitCode
            elapsed_ms = $native.ElapsedMilliseconds; timeout_ms = $native.TimeoutMilliseconds
            process_released = $native.ProcessReleased; pipe_drain_completed = $native.PipeDrainCompleted
        })
        return $native
    } catch { $script:releaseProved = $false; throw }
}
function Assert-NativeSuccess {
    param([object]$Result)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ExitCode -eq 0 -and $Result.ProcessReleased -and $Result.PipeDrainCompleted -and -not $Result.StdoutTruncated -and -not $Result.StderrTruncated) ('Native operation failed: ' + $Result.Status + ' ' + $Result.Error + ' ' + $Result.Stderr)
}
function Invoke-Tool {
    param([string]$Executable, [string[]]$Arguments, [string]$Operation = 'S11 synthetic fixture/check')
    $native = Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Operation $Operation
    Assert-NativeSuccess $native
    return $native
}
function Read-Probe {
    param([string]$Path)
    $native = Invoke-Tool $ffprobe @('-v','error','-show_streams','-show_format','-of','json','-i',$Path) 'S11 independent probe'
    return $native.Stdout | ConvertFrom-Json
}
function Read-Audio {
    param([string]$Path)
    $probe = Read-Probe $Path
    $audio = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($audio.Count -eq 1) 'Expected one independently probed audio stream.'
    return $audio[0]
}

function Get-ExpectedSampleRate {
    param([int]$SourceRate, [int]$Bitrate)
    # Independently asserted MPEG layer III families; these are tested by every
    # actual encoded matrix result, never inferred from requested output options.
    $eligible = @($supportedRates | Where-Object {
        ($Bitrate -le 64 -and $_ -lt 16000) -or
        ($Bitrate -le 160 -and $_ -ge 16000 -and $_ -le 24000) -or
        ($Bitrate -ge 32 -and $Bitrate -ne 144 -and $_ -ge 32000)
    })
    if ($eligible.Count -eq 0) { return $null }
    return @($eligible | Sort-Object @{Expression={[math]::Abs([long]$_ - $SourceRate)}}, @{Expression={[int]$_}})[0]
}

function Invoke-MatrixConversion {
    param([object]$Source, [int]$Bitrate, [string]$Group, [string]$Cover = '')
    $id = $Source.id + '-' + $Bitrate + 'k-' + $Group
    $output = Join-Path $outputRoot ($id + '.mp3')
    $plan = Get-AudioOutputPlan -Media $Source.media -BitrateKbps $Bitrate -SupportedSampleRates $supportedRates
    $expectedSampleRate = Get-ExpectedSampleRate $Source.rate $Bitrate
    Assert-True ($plan.Status -ceq 'Success' -and $plan.OutputSampleRate -eq $expectedSampleRate -and $plan.BitrateKbps -eq $Bitrate -and $plan.SourceCodec -ceq $Source.codec -and $plan.SourceSampleRate -eq $Source.rate -and $plan.SourceChannels -eq $Source.channels) ('Incorrect plan: ' + $id + ' ' + $plan.Reason)
    $expectedChannels = [math]::Min($Source.channels, 2)
    Assert-True ($plan.OutputChannels -eq $expectedChannels -and $plan.Resample -eq ($Source.rate -ne $expectedSampleRate) -and $plan.Downmix -eq ($Source.channels -gt 2)) ('Incorrect resample/downmix decision: ' + $id)
    if ($Bitrate -eq 64 -and $supportedRates -contains $Source.rate -and $Source.channels -le 2) { Assert-True (-not $plan.Resample -and -not $plan.Downmix) 'Normal default64 source shape changed.' }
    $metadata = Get-AudioMetadataPlan -Media $Source.media -FallbackTitle ('S11 fallback ' + $Source.id)
    $arguments = New-AudioEncodeArguments -InputPath $Source.path -Media $Source.media -MetadataArguments $metadata.Arguments -OutputPlan $plan -CoverPath $Cover
    $arIndex = [Array]::IndexOf($arguments, '-ar'); $acIndex = [Array]::IndexOf($arguments, '-ac')
    $lastInputIndex = [Array]::LastIndexOf($arguments, '-i')
    Assert-True (@($arguments | Where-Object { $_ -ceq '-ar' }).Count -eq 1 -and @($arguments | Where-Object { $_ -ceq '-ac' }).Count -eq 1 -and $arIndex -gt $lastInputIndex + 1 -and $acIndex -gt $lastInputIndex + 1 -and [int]$arguments[$arIndex+1] -eq $expectedSampleRate -and [int]$arguments[$acIndex+1] -eq $expectedChannels) ('Builder output options differ from the plan or occur before an input: ' + $id)
    $transaction = Invoke-AudioOutputTransaction -SourcePath $Source.path -OutputRoot $outputRoot -OutputPath $output -SourceDurationSeconds $Source.media.DurationSeconds -BitrateKbps $Bitrate -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments $arguments -HasCover ([bool]$Cover) -OutputPlan $plan
    Assert-True ($transaction.Status -ceq 'Success' -and [string]::IsNullOrEmpty($transaction.CleanupError)) ('Transaction failed: ' + $id + ' ' + $transaction.Status + ' ' + $transaction.Error)
    Assert-True ($transaction.EncoderResult.TimeoutMilliseconds -eq 0 -and $transaction.ValidationResult.DecodeResult.TimeoutMilliseconds -eq 0) 'Normal encoding/full decode gained a runtime limit.'
    $validation = $transaction.ValidationResult
    Assert-True ($validation.Status -ceq 'Success' -and $validation.SampleRate -eq $expectedSampleRate -and $validation.Channels -eq $expectedChannels -and $validation.Bitrate -eq $Bitrate * 1000) ('Validator did not return exact planned audio shape: ' + $id)
    $probe = Read-Probe $output
    $audio = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].sample_rate -eq $expectedSampleRate -and [int]$audio[0].channels -eq $expectedChannels -and [int]$audio[0].bit_rate -eq $Bitrate * 1000) ('Independent output differs from plan: ' + $id)
    $videos = @($probe.streams | Where-Object { $_.codec_type -ceq 'video' })
    Assert-True ($videos.Count -eq [int][bool]$Cover -and $probe.format.tags.title -ceq $metadata.Title -and $probe.format.tags.artist -ceq 'S11 source artist' -and $probe.format.tags.album -ceq 'S11 source album') ('Metadata/cover regression: ' + $id)
    Assert-True (-not (Test-Path -LiteralPath $transaction.WorkingPath)) 'Validated publication left owned partial.'
    $soundUnchanged = $null
    if ($Bitrate -eq 64 -and -not $plan.Resample -and -not $plan.Downmix -and -not $Cover) {
        $baseline = Join-Path $outputRoot ($id + '-legacy-default.mp3')
        $baselineArguments = @()
        for ($index=0; $index -lt $arguments.Count; $index++) {
            if ($arguments[$index] -in @('-ar','-ac')) { $index++; continue }
            $baselineArguments += $arguments[$index]
        }
        Invoke-Tool $ffmpeg ($baselineArguments + @($baseline)) 'S11 ordinary default64 legacy sound control' | Out-Null
        $baselineHash = Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$baseline,'-map','0:a:0','-f','hash','-hash','sha256','-') 'S11 default64 legacy decoded PCM hash'
        $plannedHash = Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$output,'-map','0:a:0','-f','hash','-hash','sha256','-') 'S11 default64 planned decoded PCM hash'
        Assert-True ($baselineHash.Stdout.Trim() -ceq $plannedHash.Stdout.Trim()) ('Ordinary default64 decoded sound changed: ' + $id)
        $soundUnchanged = $true
    }
    $matrix.Add([pscustomobject]@{
        id=$id; group=$Group; status='pass'; source_codec=$Source.codec; source_sample_rate=$Source.rate; source_channels=$Source.channels; source_channel_layout=$Source.layout
        requested_bitrate_kbps=$Bitrate; planned_sample_rate=$plan.OutputSampleRate; planned_channels=$plan.OutputChannels; resample=$plan.Resample; downmix=$plan.Downmix
        observed_bitrate_bps=[int]$audio[0].bit_rate; observed_sample_rate=[int]$audio[0].sample_rate; observed_channels=[int]$audio[0].channels
        output_duration_seconds=$validation.DurationSeconds; decoded_duration_seconds=$validation.DecodedDurationSeconds; source_duration_seconds=$Source.media.DurationSeconds
        full_decode=$true; default_shape_unchanged=($Bitrate -eq 64 -and -not $plan.Resample -and -not $plan.Downmix); default_decoded_sound_unchanged=$soundUnchanged; cover=[bool]$Cover
    })
    return [pscustomobject]@{ output=$output; plan=$plan; source=$Source }
}
function New-CorpusSource {
    param([string]$Id,[double]$Duration,[string]$Codec,[string]$Extension,[string[]]$ExtraArguments=@(),[int]$Rate=44100)
    $path=Join-Path $inputRoot ($Id+'.'+$Extension)
    $seconds=$Duration.ToString('0.000000',[Globalization.CultureInfo]::InvariantCulture)
    $arguments=@('-nostdin','-v','error','-f','lavfi','-i',("sine=frequency=733:sample_rate={0}:duration={1}" -f $Rate,$seconds),'-ac','1','-c:a',$Codec)+$ExtraArguments
    $arguments+=@('-metadata',('title=S11 '+$Id),'-metadata','artist=S11 source artist','-metadata','album=S11 source album',$path)
    Invoke-Tool $ffmpeg $arguments 'S11 generate independent synthetic source'|Out-Null
    Add-Fixture $path
    $audio=Read-Audio $path
    Assert-True ([int]$audio.sample_rate -eq $Rate -and [int]$audio.channels -eq 1) 'Independent source shape differs.'
    $media=Get-AudioMediaInfo -Path $path -FfprobePath $ffprobe
    Assert-True ($media.Status -ceq 'Success' -and $media.DurationStatus -ceq 'Valid') ('Source probe failed: '+$Id+' '+$media.Error)
    return [pscustomobject]@{id=$Id;path=$path;media=$media;rate=$Rate;channels=1;codec=$audio.codec_name;layout=[string]$audio.channel_layout;generated_seconds=$Duration}
}
function Read-DecodedSeconds {
    param([string]$Path)
    $native=Invoke-Tool $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-err_detect','explode','-i',$Path,'-map','0:a:0','-vn','-sn','-dn','-af','asetpts=N/SR/TB','-progress','pipe:1','-stats_period','86400','-f','null','-') 'S11 independent strict full decode'
    Assert-True ([string]::IsNullOrWhiteSpace($native.Stderr)) 'Independent strict full decode emitted an error.'
    $time=$null;$end=$null
    foreach($line in ($native.Stdout -split '\r?\n')){
        if($line -cmatch '^out_time_us=(\d+)$'){$time=[long]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)}
        elseif($line -ceq 'progress=end'){$end=$time}
    }
    Assert-True ($null -ne $end -and $end -gt 0) 'Independent full decode omitted positive completed duration.'
    return [double]$end/1000000
}
function Invoke-CorpusConversion {
    param([object]$Source)
    $sourceDecoded=Read-DecodedSeconds $Source.path
    $converted=Invoke-MatrixConversion $Source 64 'complementary-corpus'
    $outputDecoded=Read-DecodedSeconds $converted.output
    Assert-True ([math]::Abs($outputDecoded-$sourceDecoded) -le 0.35) ('Independent decoded duration differs: '+$Source.id)
    $report.corpus_observations += [pscustomobject]@{id=$Source.id;generated_seconds=$Source.generated_seconds;source_decoded_seconds=$sourceDecoded;output_decoded_seconds=$outputDecoded;duration_tolerance_seconds=0.35;policy_changed=$false}
    return $converted
}
try {
    Assert-NoReparse $projectRoot;Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Use an owned UTF8 CP65001 driver.'
    $report.source_before=Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)) 'TEMP root must be reserved exclusively.'
    $created=$true;$report.temp_exclusively_reserved=$true
    Write-NewText $ownerFile $ownerToken;Add-Fixture $ownerFile;$report.marker_create_new=$true
    $inputRoot=New-Directory 'In';$outputRoot=New-Directory 'Out'
    $originalNative=${function:Invoke-AudioNativeProcess}
    Set-Item -Path function:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $ffmpeg=[IO.Path]::GetFullPath($FfmpegPath);$ffprobe=[IO.Path]::GetFullPath($FfprobePath)
    foreach($tool in @($ffmpeg,$ffprobe)){
        Assert-NoReparse $tool
        $identity=Invoke-Tool $tool @('-version') 'S11 selected build identity'
        $report.tools += [pscustomobject]@{name=[IO.Path]::GetFileName($tool);sha256=(Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant();version=($identity.Stdout -split '\r?\n')[0]}
    }
    $capability=Get-AudioEncoderSampleRates -FfmpegPath $ffmpeg
    Assert-True ($capability.Status -ceq 'Success') 'Encoder sample-rate capability query failed.'
    Assert-NativeSuccess $capability.NativeResult;$supportedRates=@($capability.SampleRates)
    $report.encoder_sample_rates=$supportedRates
    $report['corpus_observations']=@()
    $report['retained_complementary_coverage']=@('Test-Progress actual3605second CBR and VBR','Test-TransactionalOutput unknown/N/A/invalid duration result injection','Test-EncodingCompatibility HE-AAC valid-fixture availability characterization')
    Invoke-Case 'real sub-frame sources retain strict64 output metadata and decoded duration' {
        param($case)
        foreach($row in @(
            @{id='tiny-aac';duration=0.001;codec='aac';ext='m4a';extra=@('-profile:a','aac_low','-b:a','96k')},
            @{id='tiny-alac';duration=0.001;codec='alac';ext='m4a';extra=@()},
            @{id='tiny-mp3';duration=0.001;codec='libmp3lame';ext='mp3';extra=@('-b:a','96k')},
            @{id='tiny-vorbis';duration=0.001;codec='libvorbis';ext='ogg';extra=@('-q:a','3')},
            @{id='tiny-opus';duration=0.001;codec='libopus';ext='ogg';rate=48000;extra=@('-b:a','64k')},
            @{id='vbr-irregular';duration=1.137;codec='libmp3lame';ext='mp3';extra=@('-q:a','4')}
        )){
            $sourceRate=if($row.ContainsKey('rate')){[int]$row.rate}else{44100}
            $source=New-CorpusSource $row.id $row.duration $row.codec $row.ext $row.extra $sourceRate
            Invoke-CorpusConversion $source|Out-Null
        }
        $case['real_conversions']=6;$case['duration_policy_changed']=$false
    }
    Invoke-Case 'AAC edit-list and packet skip-sample variants retain bounded decoded duration' {
        param($case)
        $case['variants']=@()
        foreach($edit in @(0,1)){
            $source=New-CorpusSource ('aac-editlist-'+$edit) 1.137 'aac' 'm4a' @('-profile:a','aac_low','-b:a','96k','-use_editlist',[string]$edit)
            $packets=Invoke-Tool $ffprobe @('-v','error','-select_streams','a:0','-read_intervals','%+#1','-show_packets','-of','json','-i',$source.path) 'S11 AAC first packet padding evidence'
            $packet=@((ConvertFrom-Json $packets.Stdout).packets)[0]
            Invoke-CorpusConversion $source|Out-Null
            $case.variants += [pscustomobject]@{use_editlist=$edit;source_duration_seconds=$source.media.DurationSeconds;first_packet_pts_time=$packet.pts_time;first_packet_duration_time=$packet.duration_time;side_data=@($packet.side_data_list)}
        }
    }
    Invoke-Case 'MP3 without Xing header retains observed estimated duration and full decode' {
        param($case)
        $source=New-CorpusSource 'no-xing-cbr' 1.137 'libmp3lame' 'mp3' @('-b:a','96k','-write_xing','0')
        $bytes=[IO.File]::ReadAllBytes($source.path);$text=[Text.Encoding]::ASCII.GetString($bytes)
        Assert-True ($text.IndexOf('Xing',[StringComparison]::Ordinal) -lt 0 -and $text.IndexOf('Info',[StringComparison]::Ordinal) -lt 0) 'No-Xing fixture unexpectedly contains Xing/Info signature.'
        Invoke-CorpusConversion $source|Out-Null
        $case['source_duration_seconds']=$source.media.DurationSeconds;$case['no_xing_or_info_signature']=$true
    }
    Invoke-Case 'intact payload passes while retained-header truncation fails full-decode validation' {
        param($case)
        $source=New-CorpusSource 'truncation-control' 3.137 'alac' 'm4a'
        $control=Invoke-CorpusConversion $source
        $truncated=Join-Path $inputRoot 'retained-header-truncated.mp3'
        $bytes=[IO.File]::ReadAllBytes($control.output);$length=[int]($bytes.Length*0.35)
        $stream=[IO.File]::Open($truncated,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write($bytes,0,$length)}finally{$stream.Dispose()}
        Add-Fixture $truncated
        $probe=Read-Probe $truncated;$audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'})[0]
        $headerSeconds=[double]::Parse([string]$audio.duration,[Globalization.CultureInfo]::InvariantCulture)
        Assert-True ([math]::Abs($headerSeconds-$source.media.DurationSeconds) -le 0.35) 'Truncation control did not preserve plausible header duration.'
        $validation=Get-AudioOutputValidation -Path $truncated -SourceDurationSeconds $source.media.DurationSeconds -BitrateKbps 64 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -OutputPlan $control.plan
        Assert-True ($validation.Status -cne 'Success' -and $validation.ProcessReleased -and $null -ne $validation.DecodeResult -and $validation.Error -match 'decode|Decoded') 'Retained-header truncation escaped full-decode validation.'
        $case['intact_validation']='Success';$case['truncated_validation']=$validation.Status;$case['header_duration_seconds']=$headerSeconds
        $case['expected_seconds']=$source.media.DurationSeconds;$case['decode_exit_code']=$validation.DecodeResult.ExitCode;$case['decoded_duration_seconds']=$validation.DecodedDurationSeconds
        $case['truncated_file_never_published']=$true;$case['duration_tolerance_seconds']=0.35
    }

    $report.status='pass';$exitCode=0
} catch {
    $report.error = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')
    $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>')
    Write-Warning $report.error
} finally {
    $env:PATH = $originalPath
    $report.native_runs = $nativeRuns.ToArray(); $report.matrix = $matrix.ToArray(); $report.app_runs = $appRuns.ToArray()
    $report.descendant_release_proved = $releaseProved; $report.parent_path_unchanged = $env:PATH -ceq $originalPath
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository source bytes changed during focused matrix.'
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True $report.synthetic_unchanged 'Owned immutable source/runtime/fixture bytes changed.'
        Assert-True $report.parent_path_unchanged 'Process PATH changed.'
    } catch { $report.status='fail'; $exitCode=1; $report['hash_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        $report.cleanup_phase = 'NativeReleaseCheck'
        Assert-True $releaseProved 'Cleanup refused because exact native process/pipe release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $report.cleanup_phase = 'ResolveOwnedRoot'
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            $report.cleanup_phase = 'VerifyExactBoundary'
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay in exact directly owned TEMP tree.'
            $report.cleanup_phase = 'VerifyOwnerMarker'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires unchanged create-new owner marker.'
            $report.cleanup_phase = 'VerifyNoReparseTree'
            Assert-SafeTree $resolved
            $report.cleanup_phase = 'RemoveExactOwnedTree'
            # Use the same exact-path cleanup API as the retained transaction,
            # metadata, progress and diagnostics suites. All guards above still
            # apply; do not enumerate or delete through the TEMP parent.
            [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_phase = 'VerifyRemoved'
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup not verified.'
        $report.cleanup_phase = 'Completed'
    } catch {
        $report.status='fail'; $exitCode=1
        $report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')
        $report['cleanup_error_type']=$_.Exception.GetType().FullName
        $report['cleanup_error_target']=([string]$_.TargetObject).Replace($testRoot,'<OWNED_TEMP>')
        $report['cleanup_error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>')
        $report['cleanup_error_position']=$_.InvocationInfo.PositionMessage.Replace($testRoot,'<OWNED_TEMP>')
    }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 22)
}
Write-Host "S11 complementary corpus: $($report.status); matrix=$($matrix.Count); app groups=$($appRuns.Count); cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
