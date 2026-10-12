<#
Prepare exactly three MP3 files in an owned TEMP Phone folder. The representative
long output is copied unchanged from the selected, retained T20 result. The two
short synthetic files exercise metadata, supplied artwork and chapter mapping.
Preparation is automated provenance, never evidence of real phone acceptance.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,
    [string]$EvidencePath = (Join-Path $PSScriptRoot '../evidence/T21-preparation-ps7-final1.json'),
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\', '/')
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$ownedRoot = Join-Path $tempParent ('T21P-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$ownerPath = Join-Path $ownedRoot '.t21-phone-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$phoneDirectory = Join-Path $ownedRoot 'Phone'
$longReportPath = Join-Path $projectRoot 'docs/codex-v1/evidence/T20-long-ps7-final1.json'
$longRoot = Join-Path $tempParent 'T20L-8a2614f96c2a'
$longRawPath = Join-Path $longRoot 'private-native-capture.json'
$longMarkerPath = Join-Path $longRoot '.t20-long-owner'
$longPath = $null
$rootCreated = $false
$stage = 'initial_validation'
$sources = @()
$inputs = @()
$privateRuns = New-Object 'System.Collections.Generic.List[object]'
$publicRuns = New-Object 'System.Collections.Generic.List[object]'
$report = [ordered]@{
    schema_version = 1; task = 'T21'; purpose = 'ready_to_copy_phone_payload_preparation_only'
    started_utc = [DateTime]::UtcNow.ToString('o'); finished_utc = $null
    status = 'fail'; phone_acceptance = 'not_run'; physical_phone_evidence = $false
    tested_commit = $null; expected_commit = $ExpectedCommit
    preparer_sha256 = $null; preparer_snapshot_sha256 = $null; preparer_after_sha256 = $null
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    shell_executable = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    windows_build = $null; elevated = $null; execution_policy = @()
    ownership = [ordered]@{ root_name = [IO.Path]::GetFileName($ownedRoot); marker_sha256 = $null; marker_unchanged = $false; exclusive_directory = $false; retained = $true; cleanup_attempted = $false }
    tools = [ordered]@{}; sources = @(); synthetic_inputs = @(); assets = @(); native_runs = @()
    long_origin = $null; application_manifest = $null; private_bindings = [ordered]@{}
    source_bytes_unchanged = $false; source_copy_unchanged = $false; input_bytes_unchanged = $false
    long_output_bytes_unchanged = $false; tool_bytes_unchanged = $false; preparer_bytes_unchanged = $false
    all_native_processes_released = $false; exactly_three_phone_mp3_files = $false
    original_personal_source_accessed = $false; ordinary_music_access = $false
    failure_stage = $null; error = $null
}

function Assert-Preparation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-NoReparse {
    param([string]$Path)
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            Assert-Preparation (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse paths are unsupported.'
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Get-Hash {
    param([string]$Path)
    Assert-NoReparse $Path
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    Assert-NoReparse $Path
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush() } finally { $stream.Dispose() }
}
function New-OwnedDirectory {
    param([string]$Path)
    Assert-NoReparse ([IO.Path]::GetDirectoryName($Path))
    Assert-Preparation ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) 'Exclusive directory reservation failed.'
    Assert-NoReparse $Path
}
function Get-OwnedTree {
    param([string]$Root)
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $files = New-Object 'System.Collections.Generic.List[object]'
    Assert-NoReparse $Root; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-NoReparse $item.FullName
            Assert-Preparation (Test-AudioPathWithin -Path $item.FullName -Parent $Root) 'Owned inventory escaped its root.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) } else { $files.Add($item) }
        }
    }
    return $files.ToArray()
}
function Invoke-BoundedNative {
    param([string]$Label, [string]$ExecutablePath, [string[]]$NativeArguments, [int]$TimeoutMilliseconds = 60000)
    $context = New-AudioCancellationContext
    $deadline = New-Object T21PhonePreparation.Deadline($context, $TimeoutMilliseconds)
    try {
        $result = Invoke-AudioNativeProcess -ExecutablePath $ExecutablePath -Arguments $NativeArguments -Cancellation $context -MaxStdoutChars 2097152 -MaxStderrChars 131072
        $privateRuns.Add([pscustomobject]@{ label = $Label; executable = $ExecutablePath; arguments = $NativeArguments; result = $result; timed_out = $deadline.TimedOut })
        $sanitizedArguments = @($NativeArguments | ForEach-Object { $_.Replace($ownedRoot, '<OWNED_TEMP>').Replace($longRoot, '<T20_OWNED_TEMP>').Replace($projectRoot, '<PROJECT>') })
        $publicRuns.Add([pscustomobject]@{ label = $Label; executable = $ExecutablePath; arguments = $sanitizedArguments; deadline_ms = $TimeoutMilliseconds; timed_out = $deadline.TimedOut; status = $result.Status; exit_code = $result.ExitCode; elapsed_ms = $result.DurationMilliseconds; process_released = $result.ProcessReleased; capture_truncated = ($result.StdoutTruncated -or $result.StderrTruncated) })
        Assert-Preparation (-not $deadline.TimedOut -and $result.Status -ceq 'Completed' -and $result.ExitCode -eq 0 -and $result.ProcessReleased -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) ('Bounded native command failed: ' + $Label)
        return $result
    }
    finally { $deadline.Dispose(); $context.Dispose() }
}
function Get-Probe {
    param([string]$Label, [string]$Path, [switch]$Tags)
    $entries = 'stream=index,codec_type,codec_name,sample_rate,channels,bit_rate,width,height:stream_disposition=attached_pic:format=duration,size:chapter=id,start_time,end_time'
    if ($Tags) { $entries += ':format_tags=title,artist,album,track,disc:chapter_tags=title' }
    $native = Invoke-BoundedNative $Label $FfprobePath @('-v', 'error', '-show_entries', $entries, '-of', 'json', '-i', $Path)
    return $native.Stdout | ConvertFrom-Json
}
function Get-AudioTechnical {
    param([object]$Probe)
    $audio = @($Probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-Preparation ($audio.Count -eq 1) 'Exactly one audio stream required.'
    return [pscustomobject]@{
        codec = $audio[0].codec_name; sample_rate = [int]$audio[0].sample_rate; channels = [int]$audio[0].channels
        audio_bitrate = [int]$audio[0].bit_rate
        duration_seconds = [double]::Parse([string]$Probe.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    }
}
function Copy-CompleteAsset {
    param([string]$Source, [string]$Destination, [string]$ExpectedHash)
    Assert-NoReparse $Source; Assert-NoReparse $Destination
    $working = $Destination + '.work'
    [IO.File]::Copy($Source, $working, $false)
    Assert-Preparation ((Get-Hash $working) -ceq $ExpectedHash) 'Asset copy differs from verified source.'
    [IO.File]::Move($working, $Destination)
}

try {
    foreach ($path in @($PSCommandPath, (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'), $tempParent, $evidenceFullPath, $longReportPath, $longRawPath, $longMarkerPath, $FfmpegPath, $FfprobePath)) { Assert-NoReparse $path }
    Assert-Preparation (-not (Test-Path -LiteralPath $evidenceFullPath)) 'Refusing to overwrite an existing public report; use a fresh attempt filename.'
    Assert-Preparation ([IO.Path]::GetDirectoryName($evidenceFullPath) -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence')) 'Public evidence must stay in its designated directory.'
    Assert-Preparation ([IO.Path]::GetFileName($evidenceFullPath) -cmatch '^T21-preparation-[a-z0-9-]+\.json$') 'Use a dedicated T21 preparation report filename.'
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Assert-Preparation (-not (Test-AudioPathWithin -Path $ownedRoot -Parent $projectRoot)) 'Private fixtures must remain outside Git.'
    foreach ($toolPath in @($FfmpegPath, $FfprobePath)) { Assert-Preparation ($toolPath -match '^[A-Za-z]:[\\/]' -and (Test-Path -LiteralPath $toolPath -PathType Leaf)) 'Absolute installed native tool required.' }
    Initialize-AudioDirectoryInterop
    if (-not ('T21PhonePreparation.Deadline' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Threading;
namespace T21PhonePreparation {
    public sealed class Deadline : IDisposable {
        private readonly Timer timer;
        private int timedOut;
        public bool TimedOut { get { return Interlocked.CompareExchange(ref timedOut, 0, 0) != 0; } }
        public Deadline(object context, int milliseconds) {
            timer = new Timer(delegate {
                Interlocked.Exchange(ref timedOut, 1);
                context.GetType().GetMethod("Request").Invoke(context, null);
            }, null, milliseconds, Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@ -ErrorAction Stop
    }
    New-OwnedDirectory $ownedRoot; $rootCreated = $true; $report.ownership.exclusive_directory = $true
    Write-NewText $ownerPath $ownerToken; $report.ownership.marker_sha256 = Get-Hash $ownerPath
    $report.preparer_sha256 = Get-Hash $PSCommandPath
    $snapshotPath = Join-Path $ownedRoot 'preparer-snapshot.ps1'
    [IO.File]::Copy($PSCommandPath, $snapshotPath, $false); $report.preparer_snapshot_sha256 = Get-Hash $snapshotPath
    Write-NewText (Join-Path $ownedRoot 'private-invocation.json') ([ordered]@{ command_line = [Environment]::CommandLine; parameters = $PSBoundParameters; project_root = $projectRoot; owned_root = $ownedRoot; evidence_path = $evidenceFullPath; environment = 'Preparation inherits parent environment; application wrapper changes only its own PATH and removes inherited PSModulePath.' } | ConvertTo-Json -Depth 6)
    $report.private_bindings.invocation_sha256 = Get-Hash (Join-Path $ownedRoot 'private-invocation.json')
    $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try { $report.elevated = (New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } finally { $identity.Dispose() }
    Assert-Preparation (-not $report.elevated) 'Preparation must run as an ordinary user.'
    $report.execution_policy = @(Get-ExecutionPolicy -List | ForEach-Object { [pscustomobject]@{ scope = $_.Scope.ToString(); policy = $_.ExecutionPolicy.ToString() } })
    $gitPath = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $report.tested_commit = (Invoke-BoundedNative 'source_commit' $gitPath @('-C', $projectRoot, 'rev-parse', 'HEAD')).Stdout.Trim()
    Assert-Preparation ($report.tested_commit -ceq $ExpectedCommit) 'Actual HEAD differs from the explicitly reviewed commit.'
    $appFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat')
    $status = Invoke-BoundedNative 'runtime_worktree_status' $gitPath (@('-C', $projectRoot, 'status', '--porcelain=v1', '--') + $appFiles)
    Assert-Preparation ([string]::IsNullOrWhiteSpace($status.Stdout)) 'Application files must have no worktree changes.'
    $longReport = [IO.File]::ReadAllText($longReportPath) | ConvertFrom-Json
    Assert-Preparation ((Get-Hash $longReportPath) -ceq '7830d118cd4b27bfa8d144ec1a72491368d27018c19f733af813910711e5bce0') 'Selected original T20 report differs from its reviewed bytes.'
    Assert-Preparation ($longReport.status -ceq 'pass' -and $longReport.ownership.root_name -ceq 'T20L-8a2614f96c2a') 'Selected T20 long result must pass at its exact retained root.'
    Assert-Preparation ((Get-Hash $longMarkerPath) -ceq $longReport.ownership.marker_sha256) 'Retained T20 owner marker differs.'
    Assert-Preparation ((Get-Hash $longRawPath) -ceq '902dd55ab95a7d8e83ce04a7ad43eca2c158113f73f274182df5053b34ec4b96') 'Selected private T20 native record differs.'
    $longRaw = [IO.File]::ReadAllText($longRawPath) | ConvertFrom-Json
    $pathRecord = @($longRaw | Where-Object { $_.label -ceq 'output_probe' })
    Assert-Preparation ($pathRecord.Count -eq 1 -and $pathRecord[0].arguments[-2] -ceq '-i') 'Exact long output path must come from the retained output-probe argv.'
    $longPath = [IO.Path]::GetFullPath($pathRecord[0].arguments[-1])
    Assert-Preparation (Test-AudioPathWithin -Path $longPath -Parent (Join-Path $longRoot 'output')) 'Long output must stay inside the exact owned T20 output scope.'
    Assert-NoReparse $longPath
    $longHash = Get-Hash $longPath
    Assert-Preparation ($longHash -ceq '2ca720b5a04515dfbf5537632a3962f6dcd1dd068fd4679bd0135adb5e09286e' -and (Get-Item -LiteralPath $longPath).Length -eq 38201262) 'Long output bytes differ from selected acceptance evidence.'
    $report.long_origin = [ordered]@{ private_id = 'T20-long-01'; original_tested_commit = $longReport.tested_commit; report = 'evidence/T20-long-ps7-final1.json'; report_sha256 = Get-Hash $longReportPath; retained_root_name = $longReport.ownership.root_name; marker_sha256 = Get-Hash $longMarkerPath; private_raw_sha256 = Get-Hash $longRawPath; output_sha256_before = $longHash; output_sha256_after = $null; output_length = 38201262; reconversion = $false; private_tags_omitted = $true; earlier_full_decode_and_64kbps_frame_scan = $true }
    foreach ($name in @('ffmpeg', 'ffprobe')) {
        $toolPath = if ($name -ceq 'ffmpeg') { $FfmpegPath } else { $FfprobePath }
        $hash = Get-Hash $toolPath
        Assert-Preparation ($hash -ceq $longReport.tools.$name.sha256) 'Actual tool differs from selected T20 tool bytes.'
        $version = Invoke-BoundedNative ($name + '_version') $toolPath @('-version')
        $report.tools[$name] = [ordered]@{ path = $toolPath; sha256_before = $hash; sha256_after = $null; version = ($version.Stdout -split '\r?\n')[0] }
    }
    $appDirectory = Join-Path $ownedRoot 'app'; $inputDirectory = Join-Path $ownedRoot 'Input'; $outputParent = Join-Path $ownedRoot 'output'
    foreach ($directory in @($appDirectory, $inputDirectory, $outputParent, $phoneDirectory)) { New-OwnedDirectory $directory }
    foreach ($name in $appFiles) {
        $sourcePath = Join-Path $projectRoot $name; $copyPath = Join-Path $appDirectory $name; $sourceHash = Get-Hash $sourcePath
        $previous = @($longReport.sources | Where-Object { $_.name -ceq $name })
        Assert-Preparation ($previous.Count -eq 1 -and $sourceHash -ceq $previous[0].source_sha256_after) 'Current runtime differs from the tested T20 runtime.'
        [IO.File]::Copy($sourcePath, $copyPath, $false)
        $sources += [pscustomobject]@{ name = $name; source_sha256_before = $sourceHash; copy_sha256_before = Get-Hash $copyPath; source_sha256_after = $null; copy_sha256_after = $null }
        Assert-Preparation ($sources[-1].copy_sha256_before -ceq $sourceHash) 'Application copy must be byte-identical.'
    }
    $stage = 'synthetic_generation'
    $chapterPath = Join-Path $ownedRoot 'first-track.ffmetadata'
    Write-NewText $chapterPath @'
;FFMETADATA1
title=First track
artist=T21 Phone Test
album=T21 Phone Test
track=1/2
disc=1/1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=10000
title=First half
[CHAPTER]
TIMEBASE=1/1000
START=10000
END=20000
title=Second half
'@
    $firstInput = Join-Path $inputDirectory 'Z-first.m4a'; $secondInput = Join-Path $inputDirectory 'A-second.ogg'; $coverPath = Join-Path $ownedRoot 'Blue-cover.jpg'
    Invoke-BoundedNative 'generate_first_m4a_with_chapters' $FfmpegPath @('-hide_banner', '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=20', '-f', 'ffmetadata', '-i', $chapterPath, '-map', '0:a:0', '-map_metadata', '1', '-map_chapters', '1', '-ac', '2', '-c:a', 'aac', '-f', 'mp4', ($firstInput + '.work')) | Out-Null
    [IO.File]::Move(($firstInput + '.work'), $firstInput)
    Invoke-BoundedNative 'generate_second_ogg' $FfmpegPath @('-hide_banner', '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i', 'sine=frequency=660:sample_rate=44100:duration=20', '-ac', '2', '-c:a', 'libvorbis', '-metadata', 'title=Second track', '-metadata', 'artist=T21 Phone Test', '-metadata', 'album=T21 Phone Test', '-metadata', 'track=2/2', '-metadata', 'disc=1/1', '-f', 'ogg', ($secondInput + '.work')) | Out-Null
    [IO.File]::Move(($secondInput + '.work'), $secondInput)
    Invoke-BoundedNative 'generate_blue_jpg_cover' $FfmpegPath @('-hide_banner', '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i', 'color=c=blue:s=64x64', '-frames:v', '1', '-c:v', 'mjpeg', '-f', 'image2', '-update', '1', ($coverPath + '.work')) | Out-Null
    [IO.File]::Move(($coverPath + '.work'), $coverPath)
    foreach ($inputPath in @($firstInput, $secondInput, $coverPath, $chapterPath)) {
        $inputs += [pscustomobject]@{ filename = [IO.Path]::GetFileName($inputPath); length = (Get-Item -LiteralPath $inputPath).Length; sha256_before = Get-Hash $inputPath; sha256_after = $null }
    }
    $firstProbe = Get-Probe 'first_input_probe' $firstInput -Tags
    $secondProbe = Get-Probe 'second_input_probe' $secondInput -Tags
    Assert-Preparation (@($firstProbe.chapters).Count -eq 2 -and @($secondProbe.chapters).Count -eq 0) 'Expected chapter setup is missing from the generated inputs.'
    $coverProbe = Get-Probe 'cover_probe' $coverPath
    Assert-Preparation ($coverProbe.streams[0].codec_name -ceq 'mjpeg' -and $coverProbe.streams[0].width -eq 64 -and $coverProbe.streams[0].height -eq 64) 'Expected small blue JPEG fixture is invalid.'
    Write-NewText (Join-Path $ownedRoot 'private-input-probes.json') (@{ first = $firstProbe; second = $secondProbe; cover = $coverProbe } | ConvertTo-Json -Depth 12)
    $stage = 'unchanged_application_conversion'
    $wrapperPath = Join-Path $ownedRoot 'convert-short.ps1'
    $toolDirectory = [IO.Path]::GetDirectoryName($FfmpegPath).Replace("'", "''") + ';' + [IO.Path]::GetDirectoryName($FfprobePath).Replace("'", "''")
    $wrapper = @'
$ErrorActionPreference = 'Stop'
$env:PATH = '__TOOL_DIRECTORY__;' + $env:PATH
Remove-Item -LiteralPath Env:PSModulePath -ErrorAction SilentlyContinue
& (Join-Path $PSScriptRoot 'app/AudioFileForPhone.ps1') -InputFolder (Join-Path $PSScriptRoot 'Input') -OutputParent (Join-Path $PSScriptRoot 'output') -CoverPath (Join-Path $PSScriptRoot 'Blue-cover.jpg') -Artist 'T21 Phone Test' -Album 'T21 Phone Test'
exit $LASTEXITCODE
'@
    Write-NewText $wrapperPath ($wrapper.Replace('__TOOL_DIRECTORY__', $toolDirectory))
    $report.private_bindings.application_wrapper_sha256 = Get-Hash $wrapperPath
    Invoke-BoundedNative 'unchanged_application_default64kbps_with_cover' $report.shell_executable @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', $wrapperPath) -TimeoutMilliseconds 120000 | Out-Null
    $runEntries = @(Get-ChildItem -LiteralPath $outputParent -Force)
    Assert-Preparation ($runEntries.Count -eq 1 -and $runEntries[0].PSIsContainer) 'Exactly one completed application output run is required.'
    $runRoot = $runEntries[0].FullName
    $runOwnerPath = Join-Path $runRoot '.AudioFileForPhone-output.json'
    $runOwner = [IO.File]::ReadAllText($runOwnerPath) | ConvertFrom-Json
    Assert-Preparation ($runOwner.output_root -ceq $runRoot -and $runOwner.cleanup_scope -ceq $runRoot -and $runOwner.ownership_token -cmatch '^[a-f0-9]{32}$') 'Application output ownership does not match the exact owned run.'
    $manifestPath = Join-Path $runRoot 'AudioFileForPhone_manifest.json'
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    Assert-Preparation ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 2 -and $manifest.totals.failed -eq 0 -and $manifest.totals.not_completed -eq 0 -and $manifest.policies.bitrate_kbps -eq 64) 'Application did not complete both files at the default bitrate.'
    Assert-Preparation ($manifest.build.entry_sha256 -ceq $sources[0].copy_sha256_before -and $manifest.build.helper_sha256 -ceq $sources[1].copy_sha256_before) 'Application manifest differs from the exact copied runtime.'
    Assert-Preparation ($manifest.tools.ffmpeg.path -ieq $FfmpegPath -and $manifest.tools.ffprobe.path -ieq $FfprobePath -and
        (Get-Hash $manifest.tools.ffmpeg.path) -ceq $report.tools.ffmpeg.sha256_before -and
        (Get-Hash $manifest.tools.ffprobe.path) -ceq $report.tools.ffprobe.sha256_before) 'Application did not resolve the verified external tools.'
    $report.application_manifest = [ordered]@{ sha256 = Get-Hash $manifestPath; status = $manifest.run.status; exit_code = $manifest.run.exit_code; converted = $manifest.totals.converted; bitrate_kbps = $manifest.policies.bitrate_kbps; entry_sha256 = $manifest.build.entry_sha256; helper_sha256 = $manifest.build.helper_sha256 }
    $stage = 'independent_output_validation'
    $outputFiles = @(Get-OwnedTree $runRoot | Where-Object { $_.Extension -ieq '.mp3' })
    Assert-Preparation ($outputFiles.Count -eq 2) 'Expected exactly two short MP3 output files.'
    foreach ($file in $outputFiles) {
        $isFirst = $file.Name.EndsWith('Z-first.mp3', [StringComparison]::OrdinalIgnoreCase)
        $isSecond = $file.Name.EndsWith('A-second.mp3', [StringComparison]::OrdinalIgnoreCase)
        Assert-Preparation ($isFirst -or $isSecond) 'Unexpected short output filename.'
        $title = if ($isFirst) { 'First track' } else { 'Second track' }
        $track = if ($isFirst) { '1/2' } else { '2/2' }
        $id = if ($isFirst) { 'T21-short-01' } else { 'T21-short-02' }
        $destination = Join-Path $phoneDirectory $(if ($isFirst) { 'Z-first.mp3' } else { 'A-second.mp3' })
        $hashBefore = Get-Hash $file.FullName
        $probe = Get-Probe ($id + '_output_probe') $file.FullName -Tags
        $technical = Get-AudioTechnical $probe
        Assert-Preparation ($technical.codec -ceq 'mp3' -and $technical.audio_bitrate -eq 64000 -and [Math]::Abs($technical.duration_seconds - 20) -le 0.35) 'Short MP3 technical output differs from expected default behavior.'
        $tags = $probe.format.tags
        Assert-Preparation ($tags.title -ceq $title -and $tags.artist -ceq 'T21 Phone Test' -and $tags.album -ceq 'T21 Phone Test' -and $tags.track -ceq $track -and $tags.disc -ceq '1/1') 'Friendly metadata or track/disc tags did not survive application conversion.'
        $pictures = @($probe.streams | Where-Object { $_.codec_type -ceq 'video' })
        Assert-Preparation ($pictures.Count -eq 1 -and $pictures[0].codec_name -ceq 'mjpeg' -and $pictures[0].width -eq 64 -and $pictures[0].height -eq 64 -and $pictures[0].disposition.attached_pic -eq 1) 'Supplied artwork was not embedded as expected.'
        $chapters = @($probe.chapters)
        Assert-Preparation (($isFirst -and $chapters.Count -eq 2) -or ($isSecond -and $chapters.Count -eq 0)) 'Actual MP3 chapter count differs from source mapping.'
        if ($isFirst) {
            Assert-Preparation ([double]$chapters[0].start_time -eq 0 -and [double]$chapters[0].end_time -eq 10 -and [double]$chapters[1].start_time -eq 10 -and [double]$chapters[1].end_time -eq 20 -and $chapters[0].tags.title -ceq 'First half' -and $chapters[1].tags.title -ceq 'Second half') 'Actual chapter timing/title mapping differs.'
        }
        Invoke-BoundedNative ($id + '_full_decode') $FfmpegPath @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $file.FullName, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
        Assert-Preparation ((Get-Hash $file.FullName) -ceq $hashBefore) 'Validated short MP3 bytes changed.'
        Copy-CompleteAsset $file.FullName $destination $hashBefore
        $report.assets += [pscustomobject]@{ private_id = $id; filename = [IO.Path]::GetFileName($destination); length = (Get-Item -LiteralPath $destination).Length; sha256 = Get-Hash $destination; source_sha256_before = $hashBefore; source_sha256_after = Get-Hash $file.FullName; technical = $technical; expected_tags = [ordered]@{ title = $title; artist = 'T21 Phone Test'; album = 'T21 Phone Test'; track = $track; disc = '1/1' }; observed_tags = $tags; artwork = [ordered]@{ description = 'solid blue square'; width = 64; height = 64; codec = 'mjpeg'; attached_pic = $true }; chapters = $chapters; independent_full_decode = $true }
    }
    $longProbe = Get-Probe 'unchanged_long_output_technical_probe' $longPath
    $longTechnical = Get-AudioTechnical $longProbe
    Assert-Preparation ($longTechnical.codec -ceq 'mp3' -and $longTechnical.audio_bitrate -eq 64000 -and [Math]::Abs($longTechnical.duration_seconds - $longReport.output.probe.duration_seconds) -le 0.001) 'Selected unchanged long output technical identity differs.'
    $longDestination = Join-Path $phoneDirectory 'Long-audio.mp3'
    Copy-CompleteAsset $longPath $longDestination $longHash
    $report.assets += [pscustomobject]@{ private_id = 'T20-long-01'; filename = 'Long-audio.mp3'; length = (Get-Item -LiteralPath $longDestination).Length; sha256 = Get-Hash $longDestination; source_sha256_before = $longHash; source_sha256_after = Get-Hash $longPath; technical = $longTechnical; tags_omitted = $true; artwork_stream_count = @($longProbe.streams | Where-Object { $_.codec_type -ceq 'video' }).Count; chapters_count = @($longProbe.chapters).Count; earlier_full_decode_and_64kbps_frame_scan = $true; reconversion = $false }
    $phoneFiles = @(Get-ChildItem -LiteralPath $phoneDirectory -Force)
    $report.exactly_three_phone_mp3_files = $phoneFiles.Count -eq 3 -and @($phoneFiles | Where-Object { $_.PSIsContainer -or $_.Extension -ine '.mp3' }).Count -eq 0
    Assert-Preparation $report.exactly_three_phone_mp3_files 'Phone folder must contain exactly three MP3s and nothing else.'
    Write-NewText (Join-Path $ownedRoot 'SHA256SUMS.txt') (($report.assets | Sort-Object filename | ForEach-Object { $_.sha256 + '  Phone/' + $_.filename }) -join [Environment]::NewLine)
    $report.status = 'prepared'
}
catch {
    $report.failure_stage = $stage
    $report.error = 'Preparation failed; exact exception retained privately.'
    if ($rootCreated) { Write-NewText (Join-Path $ownedRoot 'private-error.txt') ($_ | Out-String) }
}
finally {
    if ($rootCreated) {
        try {
            foreach ($source in $sources) {
                $source.source_sha256_after = Get-Hash (Join-Path $projectRoot $source.name)
                $source.copy_sha256_after = Get-Hash (Join-Path (Join-Path $ownedRoot 'app') $source.name)
            }
            foreach ($input in $inputs) {
                $path = if ($input.filename -ceq 'Blue-cover.jpg' -or $input.filename -ceq 'first-track.ffmetadata') { Join-Path $ownedRoot $input.filename } else { Join-Path (Join-Path $ownedRoot 'Input') $input.filename }
                $input.sha256_after = Get-Hash $path
            }
            foreach ($name in @('ffmpeg', 'ffprobe')) {
                if ($report.tools.Contains($name)) { $report.tools[$name].sha256_after = Get-Hash $report.tools[$name].path }
            }
            $report.sources = $sources; $report.synthetic_inputs = $inputs
            $report.source_bytes_unchanged = $sources.Count -eq 3 -and @($sources | Where-Object { $_.source_sha256_before -cne $_.source_sha256_after }).Count -eq 0
            $report.source_copy_unchanged = $sources.Count -eq 3 -and @($sources | Where-Object { $_.source_sha256_before -cne $_.copy_sha256_before -or $_.copy_sha256_before -cne $_.copy_sha256_after }).Count -eq 0
            $report.input_bytes_unchanged = $inputs.Count -eq 4 -and @($inputs | Where-Object { $_.sha256_before -cne $_.sha256_after }).Count -eq 0
            if ($null -ne $report.long_origin) { $report.long_origin.output_sha256_after = Get-Hash $longPath; $report.long_output_bytes_unchanged = $report.long_origin.output_sha256_before -ceq $report.long_origin.output_sha256_after -and (Get-Hash $longMarkerPath) -ceq $report.long_origin.marker_sha256 }
            $report.tool_bytes_unchanged = $report.tools.Count -eq 2 -and @($report.tools.Values | Where-Object { $_.sha256_before -cne $_.sha256_after }).Count -eq 0
            $report.preparer_after_sha256 = Get-Hash $PSCommandPath
            $report.preparer_bytes_unchanged = $report.preparer_sha256 -ceq $report.preparer_after_sha256 -and $report.preparer_sha256 -ceq $report.preparer_snapshot_sha256
            $report.ownership.marker_unchanged = [IO.File]::ReadAllText($ownerPath) -ceq $ownerToken -and (Get-Hash $ownerPath) -ceq $report.ownership.marker_sha256
            $report.all_native_processes_released = $publicRuns.Count -gt 0 -and @($publicRuns | Where-Object { -not $_.process_released -or $_.timed_out }).Count -eq 0
            if ($report.status -ceq 'prepared' -and -not ($report.source_bytes_unchanged -and $report.source_copy_unchanged -and $report.input_bytes_unchanged -and $report.long_output_bytes_unchanged -and $report.tool_bytes_unchanged -and $report.preparer_bytes_unchanged -and $report.ownership.marker_unchanged -and $report.all_native_processes_released)) { $report.status = 'fail'; $report.failure_stage = 'final_preservation' }
        }
        catch { $report.status = 'fail'; $report.failure_stage = 'final_preservation_inspection'; Write-NewText (Join-Path $ownedRoot 'private-final-error.txt') ($_ | Out-String) }
        $privateCapturePath = Join-Path $ownedRoot 'private-native-capture.json'
        Write-NewText $privateCapturePath ($privateRuns.ToArray() | ConvertTo-Json -Depth 16)
        $report.private_bindings.native_capture_sha256 = Get-Hash $privateCapturePath
        $privateInputProbePath = Join-Path $ownedRoot 'private-input-probes.json'
        if (Test-Path -LiteralPath $privateInputProbePath) { $report.private_bindings.input_probes_sha256 = Get-Hash $privateInputProbePath }
        $report.finished_utc = [DateTime]::UtcNow.ToString('o'); $report.native_runs = @($publicRuns.ToArray())
        Write-NewText (Join-Path $ownedRoot 'preparation.json') (($report | ConvertTo-Json -Depth 16) + [Environment]::NewLine)
        Write-NewText $evidenceFullPath (($report | ConvertTo-Json -Depth 16) + [Environment]::NewLine)
    }
}
if ($report.status -cne 'prepared') { throw ('T21 preparation failed at ' + $report.failure_stage + '; retained root ' + $report.ownership.root_name) }
[pscustomobject]@{ status = 'prepared'; phone_folder = $phoneDirectory; report = $evidenceFullPath; retained_root_name = $report.ownership.root_name; phone_acceptance = 'not_run' }
