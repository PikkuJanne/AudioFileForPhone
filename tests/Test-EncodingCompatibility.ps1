<#
S09 real Windows encoding compatibility matrix. Sources are generated independently
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
if ($evidenceParent -ine (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -or
    $leaf -cnotmatch "^S09-encoding-[a-z0-9]+-$edition-(attempt|final)[1-9][0-9]*\.json$") {
    throw 'Use a fresh active S09-encoding-BUILD-ps51/ps7-attempt/finalN.json report.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; select a fresh label.' }
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'AFP-S09-' + [guid]::NewGuid().ToString('N').Substring(0, 10)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s09-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1; $originalNative = $null
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$matrix = New-Object 'System.Collections.Generic.List[object]'
$appRuns = New-Object 'System.Collections.Generic.List[object]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-EncodingCompatibility.ps1')
$bitrates = @(8,16,24,32,40,48,56,64,80,96,112,128,144,160,192,224,256,320)
$matrixRates = @(8000,16000,22050,24000,32000,44100,48000)
$extraRates = @(4000,11025,12000,12345,96000)
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'S09'; mode = 'real_windows_encoding_compatibility'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false; physical_manual_evidence = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    cleanup_verified = $false; descendant_release_proved = $false; parent_path_unchanged = $false
    advertised_bitrates_kbps = $bitrates; required_sample_rates_hz = $matrixRates; extra_sample_rates_hz = $extraRates
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
    param([string]$Executable, [string[]]$Arguments, [string]$Operation = 'S09 synthetic fixture/check')
    $native = Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Operation $Operation
    Assert-NativeSuccess $native
    return $native
}
function Read-Probe {
    param([string]$Path)
    $native = Invoke-Tool $ffprobe @('-v','error','-show_streams','-show_format','-of','json','-i',$Path) 'S09 independent probe'
    return $native.Stdout | ConvertFrom-Json
}
function Read-Audio {
    param([string]$Path)
    $probe = Read-Probe $Path
    $audio = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($audio.Count -eq 1) 'Expected one independently probed audio stream.'
    return $audio[0]
}
function New-Source {
    param([string]$Id, [int]$SampleRate, [int]$Channels, [string]$Codec = 'alac', [string]$Extension = 'm4a', [string]$Title = 'S09 synthetic', [string[]]$ExtraArguments = @())
    $path = Join-Path $inputRoot ($Id + '.' + $Extension)
    $arguments = @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i',("sine=frequency=440:sample_rate={0}:duration=0.75" -f $SampleRate),'-ac',[string]$Channels,'-c:a',$Codec)
    $arguments += $ExtraArguments
    $arguments += @('-metadata',('title=' + $Title),'-metadata','artist=S09 source artist','-metadata','album=S09 source album',$path)
    Invoke-Tool $ffmpeg $arguments 'S09 independently generate source' | Out-Null
    Add-Fixture $path
    $audio = Read-Audio $path
    Assert-True ([int]$audio.sample_rate -eq $SampleRate -and [int]$audio.channels -eq $Channels) ('Independent source shape differed: ' + $Id)
    $media = Get-AudioMediaInfo -Path $path -FfprobePath $ffprobe
    Assert-True ($media.Status -ceq 'Success' -and $media.DurationStatus -ceq 'Valid' -and $media.CodecName -ceq $audio.codec_name -and $media.SampleRate -eq $SampleRate -and $media.Channels -eq $Channels) ('Production probe lost source audio shape: ' + $Id + ' ' + $media.Error)
    return [pscustomobject]@{ id=$Id; path=$path; media=$media; rate=$SampleRate; channels=$Channels; codec=$audio.codec_name; layout=[string]$audio.channel_layout }
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
    $metadata = Get-AudioMetadataPlan -Media $Source.media -FallbackTitle ('S09 fallback ' + $Source.id)
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
    Assert-True ($videos.Count -eq [int][bool]$Cover -and $probe.format.tags.title -ceq $metadata.Title -and $probe.format.tags.artist -ceq 'S09 source artist' -and $probe.format.tags.album -ceq 'S09 source album') ('Metadata/cover regression: ' + $id)
    Assert-True (-not (Test-Path -LiteralPath $transaction.WorkingPath)) 'Validated publication left owned partial.'
    $soundUnchanged = $null
    if ($Bitrate -eq 64 -and -not $plan.Resample -and -not $plan.Downmix -and -not $Cover) {
        $baseline = Join-Path $outputRoot ($id + '-legacy-default.mp3')
        $baselineArguments = @()
        for ($index=0; $index -lt $arguments.Count; $index++) {
            if ($arguments[$index] -in @('-ar','-ac')) { $index++; continue }
            $baselineArguments += $arguments[$index]
        }
        Invoke-Tool $ffmpeg ($baselineArguments + @($baseline)) 'S09 ordinary default64 legacy sound control' | Out-Null
        $baselineHash = Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$baseline,'-map','0:a:0','-f','hash','-hash','sha256','-') 'S09 default64 legacy decoded PCM hash'
        $plannedHash = Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$output,'-map','0:a:0','-f','hash','-hash','sha256','-') 'S09 default64 planned decoded PCM hash'
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
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-AppGroup {
    param([int]$Bitrate, [switch]$DefaultRate, [string]$Cover = '')
    $id = 'App-' + $Bitrate + $(if ($Cover) { '-cover' } else { '' })
    $parent = New-Directory ($id + '-output')
    $config = Join-Path $testRoot ($id + '-absent-config.json')
    $driver = Join-Path $testRoot ($id + '.ps1')
    $code = '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)' + "`n" + '$ProgressPreference="SilentlyContinue"' + "`n& " + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $appInput) + ' -OutputParent ' + (Get-Literal $parent) + ' -ConfigPath ' + (Get-Literal $config) + ' -FfmpegDirectory ' + (Get-Literal (Split-Path -Parent $ffmpeg))
    if (-not $DefaultRate) { $code += ' -BitrateKbps ' + $Bitrate }
    if ($Cover) { $code += ' -CoverPath ' + (Get-Literal $Cover) }
    $code += "`nexit `$LASTEXITCODE"
    Write-NewText $driver $code -Utf8Bom; Add-Fixture $driver
    $savedPath = $env:PATH
    try { $env:PATH = ''; $native = Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo','-NoProfile','-NonInteractive','-OutputFormat','Text','-ExecutionPolicy','RemoteSigned','-File',$driver) -Operation ('S09 actual application ' + $id) }
    finally { $env:PATH = $savedPath }
    Assert-NativeSuccess $native
    Write-NewText (Join-Path $testRoot ($id + '.log')) ($native.Stdout + "`n" + $native.Stderr)
    $runs = @(Get-ChildItem -LiteralPath $parent -Directory)
    Assert-True ($runs.Count -eq 1) 'App must create exactly one reserved output run.'
    $manifest = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json')) | ConvertFrom-Json
    Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.failed -eq 0 -and $manifest.totals.converted -eq $appSources.Count -and $manifest.policies.bitrate_kbps -eq $Bitrate) 'Actual app matrix counts/default policy failed.'
    foreach ($record in @($manifest.records)) {
        $source = $appSources | Where-Object { [IO.Path]::GetFileName($_.path) -ceq $record.source_relative_path }
        Assert-True ($null -ne $source -and $record.status -ceq 'Converted') 'Actual app source record missing.'
        $plan = Get-AudioOutputPlan -Media $source.media -BitrateKbps $Bitrate -SupportedSampleRates $supportedRates
        $audio = Read-Audio (Join-Path $runs[0].FullName $record.output_relative_path)
        Assert-True ($record.audio_plan.status -ceq 'Success' -and $record.audio_plan.source_codec -ceq $source.codec -and $record.audio_plan.source_sample_rate -eq $source.rate -and $record.audio_plan.source_channels -eq $source.channels -and $record.audio_plan.output_sample_rate -eq $plan.OutputSampleRate -and $record.audio_plan.output_channels -eq $plan.OutputChannels -and $record.audio_plan.bitrate_kbps -eq $Bitrate -and $record.audio_plan.resample -eq $plan.Resample -and $record.audio_plan.downmix -eq $plan.Downmix) 'Actual app manifest plan differs from selected source/shared planner.'
        Assert-True ([int]$audio.bit_rate -eq $Bitrate * 1000 -and [int]$audio.sample_rate -eq $plan.OutputSampleRate -and [int]$audio.channels -eq $plan.OutputChannels -and $record.observed_audio.bitrate_bps -eq [int]$audio.bit_rate -and $record.observed_audio.sample_rate -eq [int]$audio.sample_rate -and $record.observed_audio.channels -eq [int]$audio.channels) 'Actual app validation/manifest shape mismatch.'
        Assert-True ($record.decoded_duration_seconds -gt 0 -and $record.output_duration_seconds -gt 0) 'Actual app lost decode/duration evidence.'
    }
    Assert-True (@(Get-ChildItem -LiteralPath $runs[0].FullName -Recurse -File | Where-Object { $_.Name -match '\.partial$' }).Count -eq 0 -and -not (Test-Path -LiteralPath $config)) 'App leaked partial or created config.'
    $appRuns.Add([pscustomobject]@{ id=$id; status='pass'; rate=$Bitrate; default_parameter_omitted=$DefaultRate.IsPresent; converted=$manifest.totals.converted; manifest_audio_plans_verified=$true; observed_audio_verified=$true; full_decode=$true; cover=[bool]$Cover; PATH='empty'; config_created=$false })
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Run this Windows harness through the established UTF-8 CP65001 driver.'
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'TEMP root must be reserved exclusively.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new = $true
    $appRoot = New-Directory 'App'; $inputRoot = New-Directory 'Sources'; $outputRoot = New-Directory 'Outputs'; $appInput = New-Directory 'AppSources'
    foreach ($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')) {
        $copy = Join-Path $appRoot $name; Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Runtime copies changed bytes.'
        Add-Fixture $copy
    }
    $report.copied_bytes_unchanged = $true
    . (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')
    $script:originalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    Assert-True ((Split-Path -Parent $ffmpeg) -ieq (Split-Path -Parent $ffprobe)) 'App fixture requires a supplied real pair in one external directory.'
    foreach ($tool in @($ffmpeg,$ffprobe)) {
        Assert-NoReparse $tool
        $identity = Invoke-Tool $tool @('-version') 'S09 selected build identity'
        $report.tools += [pscustomobject]@{ name=[IO.Path]::GetFileName($tool); sha256=(Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant(); version=($identity.Stdout -split '\r?\n')[0] }
    }
    $capability = Get-AudioEncoderSampleRates -FfmpegPath $ffmpeg
    Assert-True ($capability.Status -ceq 'Success' -and @($capability.SampleRates).Count -gt 0) 'Selected encoder sample-rate capability query failed.'
    Assert-NativeSuccess $capability.NativeResult
    $supportedRates = @($capability.SampleRates)
    $report.encoder_sample_rates = $supportedRates
    Assert-True (($supportedRates | Sort-Object) -join ',' -ceq '8000,11025,12000,16000,22050,24000,32000,44100,48000') 'Required libmp3lame sample-rate capability shape changed; investigate this build explicitly.'
    $sources = @()
    foreach ($rate in @($matrixRates + $extraRates)) {
        foreach ($channels in @(1,2)) { $sources += New-Source ('alac-' + $rate + '-' + $channels) $rate $channels }
    }
    Invoke-Case 'reported bitrate leads reproduced independently before shared planning' {
        param($case)
        $leads = @()
        foreach ($rate in @(8000,48000)) {
            foreach ($channels in @(1,2)) {
                foreach ($bitrate in $(if ($rate -eq 8000) { @(64,192) } else { @(64,8,144) })) {
                    $source = $sources | Where-Object { $_.rate -eq $rate -and $_.channels -eq $channels }
                    $comparison = Join-Path $outputRoot ("raw-${rate}-${channels}-${bitrate}.mp3")
                    Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$source.path,'-map','0:a:0','-vn','-c:a','libmp3lame','-b:a',("${bitrate}k"),$comparison) 'S09 raw lead reproduction' | Out-Null
                    $audio = Read-Audio $comparison
                    if ($bitrate -eq 64) { Assert-True ([int]$audio.bit_rate -eq 64000) 'Unplanned default64 baseline changed.' }
                    $leads += [pscustomobject]@{ source_sample_rate=$rate; channels=$channels; requested_kbps=$bitrate; raw_bitrate_bps=[int]$audio.bit_rate; raw_sample_rate=[int]$audio.sample_rate; clamped=([int]$audio.bit_rate -ne $bitrate * 1000) }
                }
            }
        }
        $case['observations'] = $leads
    }
    foreach ($source in $sources) {
        $group = if ($matrixRates -contains $source.rate) { 'required' } else { 'extra' }
        foreach ($bitrate in $bitrates) { Invoke-MatrixConversion $source $bitrate $group | Out-Null }
    }
    Assert-True (@($matrix | Where-Object { $_.group -ceq 'required' }).Count -eq 252 -and @($matrix | Where-Object { $_.group -ceq 'extra' }).Count -eq 180) 'Full 18 x representative and low/odd/high mono/stereo matrix incomplete.'
    $multiSources = @()
    foreach ($channels in @(6,8)) { $multiSources += New-Source ('aac-48000-' + $channels) 48000 $channels 'aac' 'm4a' 'S09 multichannel' @('-b:a','384k') }
    foreach ($source in $multiSources) { foreach ($bitrate in $bitrates) { Invoke-MatrixConversion $source $bitrate 'multichannel' | Out-Null } }
    $unicodeTitle = 'S09 ' + [char]0xE4 + [char]0x65E5 + ' title'
    $variantSources = @(
        (New-Source 'aac-lc' 44100 2 'aac' 'm4a' $unicodeTitle @('-profile:a','aac_low','-b:a','96k')),
        (New-Source 'mp3-cbr' 44100 2 'libmp3lame' 'mp3' '' @('-b:a','96k')),
        (New-Source 'mp3-vbr' 44100 1 'libmp3lame' 'mp3' 'S09 VBR' @('-q:a','4')),
        (New-Source 'ogg-vorbis' 44100 2 'libvorbis' 'ogg' $unicodeTitle @('-q:a','3')),
        (New-Source 'ogg-opus' 48000 1 'libopus' 'ogg' '' @('-b:a','64k'))
    )
    $jpeg = Join-Path $inputRoot 'synthetic-cover.jpg'
    Invoke-Tool $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','color=red:size=64x64','-frames:v','1','-c:v','mjpeg',$jpeg) 'S09 synthetic artwork' | Out-Null; Add-Fixture $jpeg
    foreach ($source in $variantSources) { foreach ($bitrate in @(8,64,144,192,320)) { Invoke-MatrixConversion $source $bitrate 'codec' | Out-Null } }
    foreach ($source in @($variantSources[0],$variantSources[3])) { Invoke-MatrixConversion $source 8 'artwork' $jpeg | Out-Null }
    Invoke-Case 'HE-AAC encoder availability is explicit fixture-generation evidence' {
        param($case)
        $hePath = Join-Path $inputRoot 'he-aac-attempt.m4a'
        $he = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=44100:duration=0.75','-c:a','aac','-profile:a','aac_he','-b:a','48k',$hePath) -Operation 'S09 HE-AAC fixture capability'
        if (Test-Path -LiteralPath $hePath -PathType Leaf) { Add-Fixture $hePath }
        $probe = if ($he.Status -ceq 'Completed' -and $he.ExitCode -eq 0) { Get-AudioMediaInfo -Path $hePath -FfprobePath $ffprobe } else { $null }
        if ($null -ne $probe -and $probe.Status -ceq 'Success' -and $probe.DurationStatus -ceq 'Valid') {
            $source = [pscustomobject]@{id='he-aac';path=$hePath;media=$probe;rate=$probe.SampleRate;channels=$probe.Channels;codec=$probe.CodecName;layout=$probe.ChannelLayout}
            Invoke-MatrixConversion $source 64 'he-aac' | Out-Null
            $case['fixture_status'] = 'valid_generated_and_converted'
        } else {
            $case['fixture_status'] = 'generation_or_decode_unavailable'
            $case['converter_rejection_claimed'] = $false
            $case['generation_exit'] = $he.ExitCode
            $case['probe_status'] = $(if ($null -ne $probe) { $probe.Status } else { $null })
            $report.fixture_limitations += [pscustomobject]@{codec='HE-AAC';status='generation_or_decode_unavailable';converter_rejection_claimed=$false;reason='This build did not produce a valid decodable HE-AAC synthetic fixture; AAC-LC and ALAC cover M4A.'}
        }
    }
    Invoke-Case 'incompatible plans reject unknown shape or absent matching encoder family before native encoding' {
        param($case)
        $source = $sources | Where-Object { $_.rate -eq 48000 -and $_.channels -eq 2 }
        $observations = @()
        foreach ($row in @(
            @{name='absent-low-family';media=$source.media;rate=8;rates=@(32000,44100,48000);code='NoCompatibleSampleRate'},
            @{name='absent-high-family';media=$source.media;rate=320;rates=@(8000,16000,24000);code='NoCompatibleSampleRate'},
            @{name='empty-capabilities';media=$source.media;rate=64;rates=@();code='NoCompatibleSampleRate'},
            @{name='unknown-multichannel-layout';media=[pscustomobject]@{Status='Success';CodecName='aac';SampleRate=48000;Channels=6;ChannelLayout='unknown'};rate=64;rates=$supportedRates;code='UnsupportedChannelLayout'},
            @{name='arbitrary-layout';media=[pscustomobject]@{Status='Success';CodecName='aac';SampleRate=48000;Channels=6;ChannelLayout='6 channels (FL+FR+FC+LFE+BL+BR)'};rate=64;rates=$supportedRates;code='UnsupportedChannelLayout'},
            @{name='inconsistent-layout';media=[pscustomobject]@{Status='Success';CodecName='aac';SampleRate=48000;Channels=3;ChannelLayout='5.1'};rate=64;rates=$supportedRates;code='UnsupportedChannelLayout'},
            @{name='missing-sample-rate';media=[pscustomobject]@{Status='Success';CodecName='alac';SampleRate=$null;Channels=2;ChannelLayout='stereo'};rate=64;rates=$supportedRates;code='InvalidSourceAudioShape'},
            @{name='zero-channels';media=[pscustomobject]@{Status='Success';CodecName='alac';SampleRate=48000;Channels=0;ChannelLayout='stereo'};rate=64;rates=$supportedRates;code='InvalidSourceAudioShape'},
            @{name='missing-codec';media=[pscustomobject]@{Status='Success';CodecName=$null;SampleRate=48000;Channels=2;ChannelLayout='stereo'};rate=64;rates=$supportedRates;code='InvalidSourceAudioShape'}
        )) {
            $before = $nativeRuns.Count
            $plan = Get-AudioOutputPlan -Media $row.media -BitrateKbps $row.rate -SupportedSampleRates $row.rates
            $repeat = Get-AudioOutputPlan -Media $row.media -BitrateKbps $row.rate -SupportedSampleRates $row.rates
            Assert-True ($plan.Status -ceq 'Incompatible' -and $plan.Code -ceq $row.code -and -not [string]::IsNullOrWhiteSpace($plan.Reason) -and $repeat.Code -ceq $plan.Code -and $repeat.Reason -ceq $plan.Reason -and $nativeRuns.Count -eq $before) ('Expected stable actionable no-native incompatibility: ' + $row.name)
            $observations += [pscustomobject]@{id=$row.name;status=$plan.Status;code=$plan.Code;reason=$plan.Reason;native_calls=0}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'restricted capabilities choose only their compatible actual intersection' {
        param($case)
        $source = $sources | Where-Object { $_.rate -eq 48000 -and $_.channels -eq 2 }
        $before = $nativeRuns.Count
        $plan = Get-AudioOutputPlan -Media $source.media -BitrateKbps 144 -SupportedSampleRates @(12345,16000,48000)
        Assert-True ($plan.Status -ceq 'Success' -and $plan.OutputSampleRate -eq 16000 -and $nativeRuns.Count -eq $before) 'Planner did not intersect codec compatibility with selected encoder capabilities.'
        $case['requested_bitrate_kbps']=144; $case['capabilities']=@(12345,16000,48000); $case['planned_sample_rate']=16000; $case['native_calls']=0
    }
    Invoke-Case 'real wrong sample rate and channel shape fail existing validator before decode' {
        param($case)
        $source = $sources | Where-Object { $_.rate -eq 48000 -and $_.channels -eq 2 }
        $plan = Get-AudioOutputPlan -Media $source.media -BitrateKbps 64 -SupportedSampleRates $supportedRates
        $observations = @()
        foreach ($row in @(@{name='wrong-sample-rate';rate=44100;channels=2;pattern='sample.?rate'},@{name='wrong-channel-count';rate=48000;channels=1;pattern='channel'})) {
            $path = Join-Path $outputRoot ($row.name + '.mp3')
            Invoke-Tool $ffmpeg @('-nostdin','-v','error','-i',$source.path,'-map','0:a:0','-c:a','libmp3lame','-b:a','64k','-ar',[string]$row.rate,'-ac',[string]$row.channels,$path) 'S09 controlled real wrong-shape output' | Out-Null
            $validation = Get-AudioOutputValidation -Path $path -SourceDurationSeconds $source.media.DurationSeconds -BitrateKbps 64 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -OutputPlan $plan
            Assert-True ($validation.Status -cne 'Success' -and $validation.Error -match $row.pattern -and $null -eq $validation.DecodeResult -and $validation.ProcessReleased) ('Wrong-shape output accepted or decode started: ' + $row.name + ' ' + $validation.Error)
            $observations += [pscustomobject]@{id=$row.name;status=$validation.Status;reason=$validation.Error;decode_started=$false}
        }
        $case['observations'] = $observations
    }
    $appSources = @($sources | Where-Object { ($_.rate -eq 8000 -and $_.channels -eq 1) -or ($_.rate -eq 48000 -and $_.channels -eq 2) }) + @($multiSources[0]) + @($variantSources)
    foreach ($source in $appSources) { $copy = Join-Path $appInput ([IO.Path]::GetFileName($source.path)); Copy-Item -LiteralPath $source.path -Destination $copy; Add-Fixture $copy }
    Invoke-AppGroup 8
    Invoke-AppGroup 64 -DefaultRate
    Invoke-AppGroup 144
    Invoke-AppGroup 192 -Cover $jpeg
    Assert-True ($appRuns.Count -eq 4) 'Actual application route groups incomplete.'
    $report.status = 'pass'; $exitCode = 0
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
        Assert-True $releaseProved 'Cleanup refused because exact native process/pipe release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay in exact directly owned TEMP tree.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires unchanged create-new owner marker.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup not verified.'
    } catch { $report.status='fail'; $exitCode=1; $report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 22)
}
Write-Host "S09 encoding compatibility: $($report.status); matrix=$($matrix.Count); app groups=$($appRuns.Count); cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
