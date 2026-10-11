<#
Prepare retained, synthetic fixtures for the owner's T20 Windows acceptance.
This does not execute the application or establish any manual acceptance result.
The exclusive TEMP root and its local report remain available for the tester.
#>
[CmdletBinding()]
param(
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\', '/')
$helperPath = Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$rootName = 'AudioFileForPhone-T20-Manual-' + [guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path $tempParent $rootName
$markerPath = Join-Path $fixtureRoot '.t20-manual-owner'
$markerToken = [guid]::NewGuid().ToString('N')
$reportPath = Join-Path $fixtureRoot 'preparation.json'
$rootCreated = $false
$nativeCommands = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat')
$report = [ordered]@{
    schema_version = 1
    task = 'T20'
    purpose = 'synthetic_manual_fixture_preparation_only'
    started_utc = [DateTime]::UtcNow.ToString('o')
    finished_utc = $null
    status = 'failed'
    manual_acceptance = 'not_run'
    source_commit = $null
    preparer_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    runtime = [ordered]@{
        version = $PSVersionTable.PSVersion.ToString()
        edition = $PSVersionTable.PSEdition
        executable_path = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        windows_build = $null
    }
    ownership = [ordered]@{
        root = $fixtureRoot
        temp_parent = $tempParent
        marker_path = $markerPath
        marker_sha256 = $null
        exclusive_directory = $false
        reparse_ancestors_refused = $true
        retained_for_owner = $true
    }
    paths = [ordered]@{}
    tools = [ordered]@{}
    sources = @()
    inputs = @()
    native_commands = @()
    native_processes_released = $false
    source_bytes_unchanged = $false
    empty_output_parent = $false
    error = $null
}

function Write-NewPreparationFile {
    param([string]$Path, [byte[]]$Bytes)
    Assert-AudioNoReparseAncestor -Path ([IO.Path]::GetDirectoryName($Path))
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length); $stream.Flush() }
    finally { $stream.Dispose() }
}

function New-PreparationDirectory {
    param([string]$Path)
    Assert-AudioNoReparseAncestor -Path ([IO.Path]::GetDirectoryName($Path))
    if (-not [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Could not reserve exclusive fixture directory (Win32 $code): $Path"
    }
    Assert-AudioNoReparseAncestor -Path $Path
}

function Invoke-PreparationNative {
    param([string]$ExecutablePath, [string[]]$NativeArguments)
    $context = New-AudioCancellationContext
    $deadline = New-Object T20ManualPreparation.Deadline($context, 30000)
    try {
        $result = Invoke-AudioNativeProcess -ExecutablePath $ExecutablePath -Arguments $NativeArguments -Cancellation $context -MaxStdoutChars 1048576 -MaxStderrChars 65536
        $nativeCommands.Add([pscustomobject]@{
            executable_path = $ExecutablePath
            arguments = $NativeArguments
            timeout_ms = 30000
            timed_out = $deadline.TimedOut
            status = $result.Status
            exit_code = $result.ExitCode
            process_released = $result.ProcessReleased
            elapsed_ms = $result.DurationMilliseconds
            stdout = $result.Stdout
            stderr = $result.Stderr
            stdout_truncated = $result.StdoutTruncated
            stderr_truncated = $result.StderrTruncated
            error = $result.Error
        })
        if ($deadline.TimedOut -or $result.Status -ne 'Completed' -or $result.ExitCode -ne 0 -or
            -not $result.ProcessReleased -or $result.StdoutTruncated -or $result.StderrTruncated) {
            throw "Fixture native command did not complete within its bound with released process: $ExecutablePath ($($result.Status), $($result.ExitCode))."
        }
        return $result
    }
    finally { $deadline.Dispose(); $context.Dispose() }
}

function Get-PreparationFileRecord {
    param([string]$Path, [string]$Kind)
    Assert-AudioNoReparseAncestor -Path $Path
    $file = Get-Item -LiteralPath $Path -Force
    if ($file.PSIsContainer) { throw "Expected a regular fixture file: $Path" }
    return [pscustomobject]@{
        kind = $Kind
        path = $file.FullName
        relative_path = $file.FullName.Substring($fixtureRoot.Length + 1)
        length = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function New-PreparationAudio {
    param([string]$Path, [string]$Format, [string]$Codec, [string]$Title)
    $workingPath = $Path + '.work'
    $arguments = @('-hide_banner', '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i',
        'sine=frequency=440:sample_rate=44100:duration=1', '-ac', '2', '-c:a', $Codec)
    if ($Format -eq 'mp3') { $arguments += @('-b:a', '64k', '-id3v2_version', '3') }
    $arguments += @('-metadata', ('title=' + $Title), '-metadata', 'artist=T20 synthetic fixture', '-f', $Format, $workingPath)
    Invoke-PreparationNative -ExecutablePath $FfmpegPath -NativeArguments $arguments | Out-Null
    $probe = Invoke-PreparationNative -ExecutablePath $FfprobePath -NativeArguments @('-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=codec_name,sample_rate,channels:format=duration', '-of', 'json', $workingPath)
    $info = $probe.Stdout | ConvertFrom-Json
    if (@($info.streams).Count -ne 1 -or [double]::Parse([string]$info.format.duration, [Globalization.CultureInfo]::InvariantCulture) -lt 0.9 -or
        [double]::Parse([string]$info.format.duration, [Globalization.CultureInfo]::InvariantCulture) -gt 1.2) {
        throw 'Generated short audio did not probe as approximately one second.'
    }
    Assert-AudioNoReparseAncestor -Path $workingPath
    [IO.File]::Move($workingPath, $Path)
    $record = Get-PreparationFileRecord -Path $Path -Kind 'valid_synthetic_audio'
    $record | Add-Member -NotePropertyName probe -NotePropertyValue $info
    return $record
}

function New-PreparationCover {
    param([string]$Path, [string]$Codec)
    $workingPath = $Path + '.work'
    Invoke-PreparationNative -ExecutablePath $FfmpegPath -NativeArguments @('-hide_banner', '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i',
        'color=c=blue:s=64x64', '-frames:v', '1', '-c:v', $Codec, '-f', 'image2', '-update', '1', $workingPath) | Out-Null
    $probe = Invoke-PreparationNative -ExecutablePath $FfprobePath -NativeArguments @('-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name,width,height', '-of', 'json', $workingPath)
    $info = $probe.Stdout | ConvertFrom-Json
    if (@($info.streams).Count -ne 1 -or $info.streams[0].width -ne 64 -or $info.streams[0].height -ne 64) {
        throw 'Generated cover did not probe as one 64x64 picture.'
    }
    Assert-AudioNoReparseAncestor -Path $workingPath
    [IO.File]::Move($workingPath, $Path)
    $record = Get-PreparationFileRecord -Path $Path -Kind 'valid_synthetic_cover'
    $record | Add-Member -NotePropertyName probe -NotePropertyValue $info
    return $record
}

try {
    # Check existing ancestors before loading any source file as PowerShell code.
    foreach ($existingPath in @($helperPath, $PSCommandPath, $tempParent)) {
        $ancestor = [IO.Path]::GetFullPath($existingPath)
        while ($ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse ancestor is unsupported for fixture preparation: $ancestor"
            }
            $ancestor = [IO.Path]::GetDirectoryName($ancestor)
        }
    }
    # The production helper is functions-only; loading it does not run the app.
    . $helperPath
    Assert-AudioNoReparseAncestor -Path $projectRoot
    Assert-AudioNoReparseAncestor -Path $PSCommandPath
    Assert-AudioNoReparseAncestor -Path $tempParent
    if (Test-AudioPathWithin -Path $fixtureRoot -Parent $projectRoot) { throw 'Fixture root must be outside the source checkout.' }
    foreach ($toolPath in @($FfmpegPath, $FfprobePath)) {
        if ($toolPath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])') { throw 'Installed tool paths must be absolute.' }
        Assert-AudioNoReparseAncestor -Path $toolPath
        if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw "Installed tool is missing: $toolPath" }
    }
    $FfmpegPath = (Get-Item -LiteralPath $FfmpegPath).FullName
    $FfprobePath = (Get-Item -LiteralPath $FfprobePath).FullName
    Initialize-AudioDirectoryInterop
    if (-not ('T20ManualPreparation.Deadline' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Threading;
namespace T20ManualPreparation {
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
    New-PreparationDirectory -Path $fixtureRoot
    $rootCreated = $true
    $report.ownership.exclusive_directory = $true
    Write-NewPreparationFile -Path $markerPath -Bytes ([Text.Encoding]::UTF8.GetBytes($markerToken))
    $report.ownership.marker_sha256 = (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.runtime.windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    $gitPath = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $commit = Invoke-PreparationNative -ExecutablePath $gitPath -NativeArguments @('-C', $projectRoot, 'rev-parse', 'HEAD')
    $report.source_commit = $commit.Stdout.Trim()
    if ($report.source_commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Full source commit was not returned.' }
    foreach ($toolName in @('ffmpeg', 'ffprobe')) {
        $toolPath = if ($toolName -eq 'ffmpeg') { $FfmpegPath } else { $FfprobePath }
        $version = Invoke-PreparationNative -ExecutablePath $toolPath -NativeArguments @('-version')
        $report.tools[$toolName] = [ordered]@{
            path = $toolPath
            sha256 = (Get-FileHash -LiteralPath $toolPath -Algorithm SHA256).Hash.ToLowerInvariant()
            version = ($version.Stdout -split '\r?\n')[0]
        }
    }
    $report.paths = [ordered]@{
        root = $fixtureRoot
        application_directory = Join-Path $fixtureRoot 'app'
        special_input = Join-Path $fixtureRoot 'Input spaces ä Ω [brackets] & ampersand'
        mixed_input = Join-Path $fixtureRoot 'Mixed valid & corrupt [batch]'
        covers = Join-Path $fixtureRoot 'Covers [picker] & images'
        output_parent = Join-Path $fixtureRoot 'Output [owned] & empty'
        report = $reportPath
    }
    foreach ($name in @('application_directory', 'special_input', 'mixed_input', 'covers', 'output_parent')) {
        New-PreparationDirectory -Path $report.paths[$name]
    }
    $nestedInput = Join-Path $report.paths.special_input 'Nested Ω [album] & folder'
    New-PreparationDirectory -Path $nestedInput
    foreach ($name in $sourceFiles) {
        $sourcePath = Join-Path $projectRoot $name
        Assert-AudioNoReparseAncestor -Path $sourcePath
        $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $copyPath = Join-Path $report.paths.application_directory $name
        [IO.File]::Copy($sourcePath, $copyPath, $false)
        $copyHash = (Get-FileHash -LiteralPath $copyPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($copyHash -cne $sourceHash) { throw "Application copy is not byte-identical: $name" }
        $report.sources += [pscustomobject]@{ name = $name; source_path = $sourcePath; copy_path = $copyPath; source_sha256 = $sourceHash; copy_sha256 = $copyHash; source_after_sha256 = $null }
    }
    $mp3Path = Join-Path $report.paths.special_input 'Example ä [MP3] & title.mp3'
    $report.inputs += New-PreparationAudio -Path $mp3Path -Format 'mp3' -Codec 'libmp3lame' -Title 'T20 synthetic MP3 title'
    $report.inputs += New-PreparationAudio -Path (Join-Path $nestedInput 'Example Ω [M4A] & title.m4a') -Format 'mp4' -Codec 'aac' -Title 'T20 synthetic M4A title'
    $report.inputs += New-PreparationAudio -Path (Join-Path $nestedInput 'Example ä [OGG] & title.ogg') -Format 'ogg' -Codec 'libvorbis' -Title 'T20 synthetic OGG title'
    $mixedValid = Join-Path $report.paths.mixed_input 'Valid [MP3] & example.mp3'
    [IO.File]::Copy($mp3Path, $mixedValid, $false)
    $report.inputs += Get-PreparationFileRecord -Path $mixedValid -Kind 'valid_synthetic_audio_copy'
    if ($report.inputs[-1].sha256 -cne $report.inputs[0].sha256) { throw 'Mixed-batch valid copy differs from its synthetic source.' }
    $corruptPath = Join-Path $report.paths.mixed_input 'Corrupt [MP3] & example.mp3'
    Write-NewPreparationFile -Path $corruptPath -Bytes ([Text.Encoding]::UTF8.GetBytes('T20 deliberate corrupt synthetic MP3; not audio.'))
    $report.inputs += Get-PreparationFileRecord -Path $corruptPath -Kind 'deliberately_corrupt_synthetic_audio'
    $jpgPath = Join-Path $report.paths.covers 'Blue [valid] & cover.jpg'
    $pngPath = Join-Path $report.paths.covers 'Blue ä [valid] & cover.png'
    $invalidCoverPath = Join-Path $report.paths.covers 'Invalid [cover] & image.jpg'
    $report.inputs += New-PreparationCover -Path $jpgPath -Codec 'mjpeg'
    $report.inputs += New-PreparationCover -Path $pngPath -Codec 'png'
    Write-NewPreparationFile -Path $invalidCoverPath -Bytes ([Text.Encoding]::UTF8.GetBytes('T20 deliberate invalid synthetic cover; not an image.'))
    $report.inputs += Get-PreparationFileRecord -Path $invalidCoverPath -Kind 'deliberately_invalid_synthetic_cover'
    $report.paths['valid_jpg_cover'] = $jpgPath
    $report.paths['valid_png_cover'] = $pngPath
    $report.paths['invalid_cover'] = $invalidCoverPath
    foreach ($source in $report.sources) {
        $source.source_after_sha256 = (Get-FileHash -LiteralPath $source.source_path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($source.source_after_sha256 -cne $source.source_sha256) { throw 'Source bytes changed during preparation.' }
    }
    $report.source_bytes_unchanged = $true
    $report.empty_output_parent = @(Get-ChildItem -LiteralPath $report.paths.output_parent -Force).Count -eq 0
    if (-not $report.empty_output_parent) { throw 'Prepared output parent must remain empty.' }
    if ([IO.File]::ReadAllText($markerPath) -cne $markerToken) { throw 'Ownership marker changed during preparation.' }
    $report.native_processes_released = @($nativeCommands | Where-Object { -not $_.process_released }).Count -eq 0
    $report.status = 'prepared'
}
catch {
    $report.error = $_.Exception.Message
}
finally {
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    $report.native_commands = @($nativeCommands.ToArray())
    if ($rootCreated) {
        $json = $report | ConvertTo-Json -Depth 12
        Write-NewPreparationFile -Path $reportPath -Bytes ((New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine))
    }
}

if ($report.status -ne 'prepared') { throw "T20 fixture preparation failed. Retained report/root: $reportPath. $($report.error)" }
[pscustomobject]$report.paths
