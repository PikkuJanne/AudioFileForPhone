<#
T02 focused baseline characterization using real FFmpeg and generated fixtures.
Invoke only through Invoke-IsolatedBaseline.ps1. The wrapper owns isolation and
cleanup; this helper never resolves the real Music folder or deletes media.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ApplicationScript,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$OutputParent,
    [Parameter(Mandatory = $true)][string]$FfmpegPath,
    [Parameter(Mandatory = $true)][string]$FfprobePath,
    [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$startedUtc = [DateTime]::UtcNow.ToString('o')
$originalPath = $env:PATH
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$commands = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$runs = New-Object 'System.Collections.Generic.List[object]'
$inventoryBefore = @()
$inventoryAfter = @()
$directoriesBefore = @()
$directoriesAfter = @()
$fixtureDefinitions = @()
$fatalError = $null
$resultPathApproved = $false
$environmentRecord = [ordered]@{
    os = [Environment]::OSVersion.VersionString
    shell = $shellPath
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = $PSVersionTable.PSEdition
    execution_policy = @(Get-ExecutionPolicy -List | ForEach-Object {
        [pscustomobject]@{ scope = $_.Scope.ToString(); policy = $_.ExecutionPolicy.ToString() }
    })
    ffmpeg_version = $null
    ffprobe_version = $null
    application_sha256 = $null
    characterization_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-AbsolutePath {
    param([string]$Path)
    Assert-True ([IO.Path]::IsPathRooted($Path)) "Expected an absolute path: $Path"
    return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-WithinPath {
    param([string]$Path, [string]$Parent)
    return $Path.StartsWith($Parent.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparseTree {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse ancestor refused: $($item.FullName)"
        $item = $item.Parent
    }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($child in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse child refused: $($child.FullName)"
            if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
}

function New-FixtureDirectory {
    param([string]$Path)
    Assert-True (Test-WithinPath (Get-AbsolutePath $Path) $WorkRoot) 'Fixture directory must stay inside WorkRoot.'
    [IO.Directory]::CreateDirectory($Path) | Out-Null
}

function Invoke-CapturedNative {
    param([string]$Purpose, [string]$Executable, [string[]]$Arguments, [switch]$AllowFailure)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    # PS5.1 turns stderr into ErrorRecords. Capture it without promoting normal
    # FFmpeg diagnostics to terminating errors; exit status remains authoritative.
    $ErrorActionPreference = 'Continue'
    $output = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $watch.Stop()
    $commandRecord = [ordered]@{
        purpose = $Purpose
        executable = $Executable
        arguments = @($Arguments)
        exit_code = $code
        elapsed_ms = $watch.ElapsedMilliseconds
        diagnostic_tail = @()
    }
    if ($code -ne 0) { $commandRecord.diagnostic_tail = @($output | Select-Object -Last 12) }
    $commands.Add([pscustomobject]$commandRecord)
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "$Purpose exited $code. $($commandRecord.diagnostic_tail -join ' ')"
    }
    return [pscustomobject]@{ ExitCode = $code; Output = $output }
}

function Read-Media {
    param([string]$Path)
    $result = Invoke-CapturedNative 'ffprobe media inspection' $FfprobePath @(
        '-v', 'error', '-show_format', '-show_streams', '-of', 'json', $Path)
    return ($result.Output -join "`n" | ConvertFrom-Json)
}

function Get-SourceInventory {
    return @(Get-ChildItem -LiteralPath $WorkRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            relative_path = $_.FullName.Substring($WorkRoot.Length).TrimStart('\', '/')
            length = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
}

function Get-DirectoryInventory {
    return @(Get-ChildItem -LiteralPath $WorkRoot -Recurse -Directory | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($WorkRoot.Length).TrimStart('\', '/')
    })
}

function Read-Duration {
    param($Media)
    $duration = [double]::Parse([string]$Media.format.duration, [Globalization.CultureInfo]::InvariantCulture)
    Assert-True ($duration -gt 0 -and -not [double]::IsNaN($duration) -and -not [double]::IsInfinity($duration)) 'Probe must report a finite positive duration.'
    return $duration
}

function Add-Check {
    param([string]$Id, [string]$Acceptance, [string]$Expected, [scriptblock]$Action)
    try {
        $observed = & $Action
        $checks.Add([pscustomobject]@{
            id = $Id; acceptance = $Acceptance; required = $true
            status = 'pass'; expected = $Expected; observed = $observed
        })
        Write-Host "PASS: $Id"
    }
    catch {
        $checks.Add([pscustomobject]@{
            id = $Id; acceptance = $Acceptance; required = $true
            status = 'fail'; expected = $Expected; observed = $_.Exception.Message
        })
        Write-Host "FAIL: $Id - $($_.Exception.Message)"
    }
}

function New-AudioFixture {
    param([string]$Path, [string]$Codec, [int]$Rate, [int]$Channels,
        [string]$Title, [string]$Artist, [string]$Album, [string]$Cover = '')
    $nativeArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-f', 'lavfi',
        '-i', "sine=frequency=440:sample_rate=${Rate}:duration=0.75")
    if ($Cover) {
        $nativeArgs += @('-i', $Cover, '-map', '0:a:0', '-map', '1:v:0',
            '-c:v', 'copy', '-disposition:v', 'attached_pic')
    }
    $nativeArgs += @('-c:a', $Codec, '-ac', "$Channels")
    if ($Title) { $nativeArgs += @('-metadata', "title=$Title") }
    $nativeArgs += @('-metadata', "artist=$Artist", '-metadata', "album=$Album",
        '-metadata', 'comment=Synthetic source comment', '-metadata', 'track=4', $Path)
    Invoke-CapturedNative 'generate synthetic audio fixture' $FfmpegPath $nativeArgs | Out-Null
}

function Invoke-Conversion {
    param([string]$Name, [string]$InputPath, [string[]]$Options = @())
    $runParent = Join-Path $OutputParent ('Run-' + [guid]::NewGuid().ToString('N'))
    Assert-True (-not (Test-Path -LiteralPath $runParent)) 'Each conversion requires a fresh output parent.'
    New-Item -ItemType Directory -Path $runParent | Out-Null
    $nativeArgs = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
        '-File', $ApplicationScript, '-InputFolder', $InputPath, '-OutputParent', $runParent) + $Options
    $native = Invoke-CapturedNative "application: $Name" $shellPath $nativeArgs -AllowFailure
    $reportedRoots = @($native.Output | ForEach-Object {
        if ($_ -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1] }
    })
    Assert-True ($reportedRoots.Count -eq 1) "$Name must report one isolated output root."
    $outputRoot = Get-AbsolutePath $reportedRoots[0]
    Assert-True ((Split-Path -Parent $outputRoot) -ieq $runParent) "$Name escaped its explicit OutputParent."
    Assert-True ((Split-Path -Leaf $outputRoot) -match '^AudioForPhone_64kbps_\d{8}_\d{6}$') "$Name root differs from the baseline naming contract."
    Assert-True (@(Get-ChildItem -LiteralPath $runParent -Directory).Count -eq 1) "$Name must create exactly one output run."
    Assert-True (Test-Path -LiteralPath $outputRoot -PathType Container) "$Name output root was not created."
    $base = Join-Path $outputRoot (Split-Path -Leaf $InputPath)
    $log = Get-Content -LiteralPath (Join-Path $outputRoot 'AudioFileForPhone_log.txt') -Raw
    $summary = $null
    if ($log -match 'Summary: total=(\d+), converted=(\d+), failed=(\d+)') {
        $summary = [pscustomobject]@{
            total = [int]$Matches[1]; converted = [int]$Matches[2]; failed = [int]$Matches[3]
        }
    }
    $files = @(Get-ChildItem -LiteralPath $base -Recurse -File | Sort-Object FullName)
    $runRecord = [pscustomobject]@{
        name = $Name; input = $InputPath; options = @($Options); output_parent = $runParent; output_root = $outputRoot
        exit_code = $native.ExitCode; summary = $summary
        output_files = @($files | ForEach-Object { $_.FullName.Substring($base.Length).TrimStart('\', '/') })
    }
    $runs.Add($runRecord)
    return [pscustomobject]@{
        Base = $base; Files = $files; ExitCode = $native.ExitCode; Summary = $summary; Record = $runRecord
    }
}

function Read-Mp3Frames {
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    Assert-True ($bytes.Length -gt 10) 'MP3 should contain an ID3 header and audio.'
    Assert-True ([Text.Encoding]::ASCII.GetString($bytes, 0, 3) -eq 'ID3') 'Expected a raw ID3 header.'
    Assert-True ($bytes[3] -eq 3) "Raw ID3 major version was $($bytes[3]), expected 3."
    $tagSize = 0
    for ($index = 6; $index -lt 10; $index++) {
        Assert-True (($bytes[$index] -band 128) -eq 0) 'Invalid synchsafe ID3 length.'
        $tagSize = ($tagSize -shl 7) -bor $bytes[$index]
    }
    $offset = 10 + $tagSize
    $bitrates = New-Object 'System.Collections.Generic.List[int]'
    while ($offset + 4 -le $bytes.Length) {
        if ($bytes[$offset] -ne 255 -or ($bytes[$offset + 1] -band 224) -ne 224) { break }
        $version = ($bytes[$offset + 1] -shr 3) -band 3
        $layer = ($bytes[$offset + 1] -shr 1) -band 3
        $rateIndex = ($bytes[$offset + 2] -shr 2) -band 3
        $bitrateIndex = ($bytes[$offset + 2] -shr 4) -band 15
        Assert-True ($version -ne 1 -and $layer -eq 1 -and $rateIndex -ne 3) 'Expected a valid MPEG layer III frame.'
        $table = if ($version -eq 3) {
            @(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320)
        } else { @(0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160) }
        Assert-True ($bitrateIndex -ge 1 -and $bitrateIndex -le 14) 'Unexpected free/invalid frame bitrate.'
        $rate = @(44100, 48000, 32000)[$rateIndex]
        if ($version -eq 2) { $rate /= 2 }
        elseif ($version -eq 0) { $rate /= 4 }
        $kbps = $table[$bitrateIndex]
        $coefficient = if ($version -eq 3) { 144 } else { 72 }
        $frameLength = [int][Math]::Floor($coefficient * $kbps * 1000 / $rate) + (($bytes[$offset + 2] -shr 1) -band 1)
        Assert-True ($offset + $frameLength -le $bytes.Length) 'Truncated MPEG frame.'
        $bitrates.Add($kbps)
        $offset += $frameLength
    }
    Assert-True ($bitrates.Count -ge 10) 'Expected at least ten complete MP3 frames in the short fixture.'
    Assert-True (@($bitrates | Where-Object { $_ -ne 64 }).Count -eq 0) 'Every MP3 audio frame must signal 64 kbps CBR.'
    # FFmpeg may emit a trailing ID3v1 tag, but there should be no other tail.
    $tail = $bytes.Length - $offset
    Assert-True ($tail -eq 0 -or ($tail -eq 128 -and [Text.Encoding]::ASCII.GetString($bytes, $offset, 3) -eq 'TAG')) 'Unparsed bytes remain after MP3 frames.'
    return [pscustomobject]@{ id3_major = [int]$bytes[3]; frames = $bitrates.Count; unique_frame_kbps = @($bitrates | Sort-Object -Unique) }
}

try {
    $ApplicationScript = Get-AbsolutePath $ApplicationScript
    $WorkRoot = Get-AbsolutePath $WorkRoot
    $OutputParent = Get-AbsolutePath $OutputParent
    $FfmpegPath = Get-AbsolutePath $FfmpegPath
    $FfprobePath = Get-AbsolutePath $FfprobePath
    $ResultPath = Get-AbsolutePath $ResultPath
    $ownedParent = Get-AbsolutePath (Split-Path -Parent $OutputParent)
    $ownerFile = Join-Path $ownedParent '.t03-owner'
    Assert-True ((Split-Path -Leaf $ownedParent) -match '^AudioFileForPhone-T03-[a-f0-9]{32}$') 'Companion requires the unique wrapper-owned parent.'
    Assert-True (Test-Path -LiteralPath $ownerFile -PathType Leaf) 'Wrapper ownership marker is required.'
    Assert-True ([IO.File]::ReadAllText($ownerFile) -match '^[a-f0-9]{32}$') 'Wrapper ownership marker must contain an exclusive token.'
    Assert-True ((Split-Path -Parent $WorkRoot) -eq $ownedParent -and (Test-WithinPath $ApplicationScript $ownedParent)) 'ApplicationScript, WorkRoot and OutputParent must share the wrapper-owned parent.'
    Assert-True ((Split-Path -Parent $ResultPath) -eq $ownedParent -and [IO.Path]::GetExtension($ResultPath) -ieq '.json' -and
        $ResultPath -ine $ApplicationScript -and -not (Test-WithinPath $ResultPath $WorkRoot) -and
        -not (Test-WithinPath $ResultPath $OutputParent)) 'ResultPath must be a JSON sibling under the owned parent, separate from all inputs and outputs.'
    Assert-True (-not (Test-Path -LiteralPath $ResultPath)) 'ResultPath must be fresh; refusing to overwrite an existing file.'
    Assert-NoReparseTree $ownedParent
    $resultPathApproved = $true
    Assert-True ($WorkRoot -ne $OutputParent -and -not (Test-WithinPath $WorkRoot $OutputParent) -and
        -not (Test-WithinPath $OutputParent $WorkRoot)) 'Source and output parents must be separate.'
    foreach ($filePath in @($ApplicationScript, $FfmpegPath, $FfprobePath, $shellPath)) {
        Assert-True (Test-Path -LiteralPath $filePath -PathType Leaf) "Required file missing: $filePath"
    }
    Assert-True (Test-Path -LiteralPath $OutputParent -PathType Container) 'Wrapper must create the isolated output parent.'
    if (Test-Path -LiteralPath $WorkRoot) {
        Assert-True (@(Get-ChildItem -LiteralPath $WorkRoot -Force).Count -eq 0) 'WorkRoot must be a fresh empty fixture directory.'
    } else { [IO.Directory]::CreateDirectory($WorkRoot) | Out-Null }
    $applicationTokens = $null; $applicationErrors = $null
    $applicationAst = [Management.Automation.Language.Parser]::ParseFile($ApplicationScript, [ref]$applicationTokens, [ref]$applicationErrors)
    Assert-True ($applicationErrors.Count -eq 0 -and
        @($applicationAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'OutputParent' }).Count -eq 1) 'Unchanged application copy must expose OutputParent.'
    $environmentRecord.application_sha256 = (Get-FileHash -LiteralPath $ApplicationScript -Algorithm SHA256).Hash
    $environmentRecord.ffmpeg_version = (Invoke-CapturedNative 'FFmpeg version' $FfmpegPath @('-version')).Output[0]
    $environmentRecord.ffprobe_version = (Invoke-CapturedNative 'ffprobe version' $FfprobePath @('-version')).Output[0]
    $env:PATH = (Split-Path -Parent $FfmpegPath) + ';' + (Split-Path -Parent $FfprobePath) + ';' + $originalPath

    # Construct Unicode at runtime so this test remains readable under PS5.1's
    # handling of an ASCII/UTF-8-without-BOM source file.
    $unicodeTitle = 'Original ' + [char]0x00c4 + [char]0x00e4 + ' ' + [char]0x6771 + [char]0x4eac
    $unicodeArtist = 'Artist ' + [char]0x00e9 + ' ' + [char]0x03a9
    $unicodeAlbum = 'Album ' + [char]0x00f6 + ' ' + [char]0x6771
    $input = Join-Path $WorkRoot 'Characterization input'
    $nested = Join-Path $input 'Nested folder\More audio'
    $assets = Join-Path $WorkRoot 'Fixture assets'
    $overrideInput = Join-Path $WorkRoot 'Override input'
    $invalidDateInput = Join-Path $WorkRoot 'Impossible date input'
    $corruptInput = Join-Path $WorkRoot 'Corrupt only input'
    $mixedInput = Join-Path $WorkRoot 'Mixed corrupt input'
    foreach ($directory in @($input, $nested, $assets, $overrideInput, $invalidDateInput, $corruptInput, $mixedInput)) {
        New-FixtureDirectory $directory
    }
    $coverPath = Join-Path $assets 'Synthetic cover.jpg'
    Invoke-CapturedNative 'generate synthetic source artwork' $FfmpegPath @('-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'lavfi', '-i', 'color=c=blue:s=32x32:d=0.4', '-frames:v', '1', '-update', '1', $coverPath) | Out-Null
    $longName = '2024-04-05 - ' + ('Long title ' * 7) + 'end'
    $monoPath = Join-Path $input ($longName + '.MP3')
    $stereoPath = Join-Path $nested 'Stereo fallback!.M4A'
    $vorbisPath = Join-Path $input '2024-04-06 - Vorbis.OGG'
    $opusPath = Join-Path $nested '2024-04-07 - Opus.ogg'
    New-AudioFixture $monoPath 'libmp3lame' 48000 1 $unicodeTitle $unicodeArtist $unicodeAlbum $coverPath
    New-AudioFixture $stereoPath 'aac' 44100 2 '' 'Source artist' 'Source album'
    (Get-Item -LiteralPath $stereoPath).LastWriteTime = [DateTime]::ParseExact('2023-02-03 12:00:00', 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    New-AudioFixture $vorbisPath 'libvorbis' 48000 1 'Original Vorbis title' 'Source artist' 'Source album'
    New-AudioFixture $opusPath 'libopus' 48000 2 $unicodeTitle $unicodeArtist $unicodeAlbum
    New-AudioFixture (Join-Path $input 'Ignored.wav') 'pcm_s16le' 48000 1 '' '' ''
    New-AudioFixture (Join-Path $input 'Ignored.FLAC') 'flac' 48000 1 '' '' ''
    Copy-Item -LiteralPath $opusPath -Destination (Join-Path $input 'Ignored.OPUS')
    Copy-Item -LiteralPath $stereoPath -Destination (Join-Path $input 'Ignored.m4b')
    Copy-Item -LiteralPath $vorbisPath -Destination (Join-Path $overrideInput '2024-04-06 - Vorbis.OGG')
    Copy-Item -LiteralPath $vorbisPath -Destination (Join-Path $invalidDateInput '2024-02-30 - Impossible.ogg')
    $corruptBytes = [Text.Encoding]::ASCII.GetBytes('Synthetic corrupt fixture; deliberately not an MP3 stream.')
    [IO.File]::WriteAllBytes((Join-Path $corruptInput '2024-04-08 - Corrupt.mp3'), $corruptBytes)
    [IO.File]::WriteAllBytes((Join-Path $mixedInput '2024-04-08 - Corrupt.mp3'), $corruptBytes)
    Copy-Item -LiteralPath $vorbisPath -Destination (Join-Path $mixedInput '2024-04-09 - Valid.ogg')

    $longOutput = ($longName.Substring(0, 60).TrimEnd()) + '.mp3'
    $fixtureDefinitions = @(
        [pscustomobject]@{ path = $monoPath; codec = 'mp3'; rate = 48000; channels = 1; title = $unicodeTitle; output = $longOutput; source_artwork = $true; source_duration_seconds = $null },
        [pscustomobject]@{ path = $stereoPath; codec = 'aac'; rate = 44100; channels = 2; title = '2023-02-03 - Stereo fallback'; output = 'Nested folder\More audio\2023-02-03 - Stereo fallback.mp3'; source_artwork = $false; source_duration_seconds = $null },
        [pscustomobject]@{ path = $vorbisPath; codec = 'vorbis'; rate = 48000; channels = 1; title = 'Original Vorbis title'; output = '2024-04-06 - Vorbis.mp3'; source_artwork = $false; source_duration_seconds = $null },
        [pscustomobject]@{ path = $opusPath; codec = 'opus'; rate = 48000; channels = 2; title = $unicodeTitle; output = 'Nested folder\More audio\2024-04-07 - Opus.mp3'; source_artwork = $false; source_duration_seconds = $null }
    )
    Assert-NoReparseTree $ownedParent
    $inventoryBefore = Get-SourceInventory
    $directoriesBefore = Get-DirectoryInventory
    Add-Check 'fixture_codecs_and_source_artwork' 'A04' 'Four intended source codecs, channel/rate matrix and MP3 attached picture exist.' {
        $observed = @()
        foreach ($fixture in $fixtureDefinitions) {
            $media = Read-Media $fixture.path
            $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
            $video = @($media.streams | Where-Object { $_.codec_type -eq 'video' })
            Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq $fixture.codec) 'Generated codec differs from fixture definition.'
            Assert-True ([int]$audio[0].sample_rate -eq $fixture.rate -and [int]$audio[0].channels -eq $fixture.channels) 'Generated source rate/channels differ from fixture definition.'
            $fixture.source_duration_seconds = Read-Duration $media
            if ($fixture.source_artwork) { Assert-True ($video.Count -eq 1 -and $video[0].disposition.attached_pic -eq 1) 'Synthetic MP3 source cover missing.' }
            $observed += [pscustomobject]@{ codec = $audio[0].codec_name; sample_rate = $audio[0].sample_rate; channels = $audio[0].channels; video_streams = $video.Count; duration_seconds = $fixture.source_duration_seconds }
        }
        return $observed
    }
    $defaultRun = Invoke-Conversion 'Default format, naming and exclusion matrix' $input
    Add-Check 'supported_and_unsupported_extensions' 'A04' 'Uppercase MP3/M4A/OGG and Ogg Opus produce four MP3s; WAV/FLAC/OPUS/M4B are ignored.' {
        Assert-True ($defaultRun.ExitCode -eq 0) 'Default conversion should exit 0.'
        Assert-True ($defaultRun.Files.Count -eq 4) "Expected four outputs; observed $($defaultRun.Files.Count)."
        Assert-True ($defaultRun.Summary.total -eq 4 -and $defaultRun.Summary.converted -eq 4 -and $defaultRun.Summary.failed -eq 0) 'Default log should report total=4, converted=4, failed=0.'
        Assert-True (@($defaultRun.Files | Where-Object { $_.Extension -ine '.mp3' }).Count -eq 0) 'All output extensions should be MP3.'
        return $defaultRun.Record
    }
    Add-Check 'default_audio_cbr_id3_and_full_decode' 'A05' '64 kbps MP3, raw ID3v2.3, constant frame bitrate, unchanged channels/rate, no video, complete decode.' {
        $observed = @()
        foreach ($fixture in $fixtureDefinitions) {
            $path = Join-Path $defaultRun.Base $fixture.output
            Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Expected output missing: $($fixture.output)"
            $media = Read-Media $path
            $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
            $video = @($media.streams | Where-Object { $_.codec_type -eq 'video' })
            Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Expected one 64 kbps MP3 stream.'
            Assert-True ([int]$audio[0].sample_rate -eq $fixture.rate -and [int]$audio[0].channels -eq $fixture.channels) 'Output should preserve source rate/channels.'
            Assert-True ($video.Count -eq 0) 'Source artwork must be absent by default.'
            $outputDuration = Read-Duration $media
            $frames = Read-Mp3Frames $path
            Invoke-CapturedNative 'full output decode' $FfmpegPath @('-hide_banner', '-loglevel', 'error', '-xerror', '-i', $path, '-map', '0:a:0', '-f', 'null', '-') | Out-Null
            $observed += [pscustomobject]@{
                output = $fixture.output; bit_rate = $audio[0].bit_rate; sample_rate = $audio[0].sample_rate
                channels = $audio[0].channels; frames = $frames; decode_exit = 0; video_streams = $video.Count
                source_duration_seconds = $fixture.source_duration_seconds; output_duration_seconds = $outputDuration
                duration_delta_seconds = $outputDuration - $fixture.source_duration_seconds
                duration_tolerance_acceptance = 'not asserted in T02; measured baseline for T09'
            }
        }
        return $observed
    }
    Add-Check 'default_naming_recursion_and_metadata' 'A05' 'Default base maximum 60, date-first naming, LastWriteTime fallback, nested folders and Unicode/plain titles/tags.' {
        $observed = @()
        foreach ($fixture in $fixtureDefinitions) {
            $path = Join-Path $defaultRun.Base $fixture.output
            Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Expected recursive/named output missing: $($fixture.output)"
            $file = Get-Item -LiteralPath $path
            Assert-True ($file.BaseName.Length -le 60 -and $file.BaseName -match '^\d{4}-\d{2}-\d{2} - ') 'Output should retain a date-first basename at most 60 characters.'
            $tags = (Read-Media $path).format.tags
            Assert-True ($tags.title -eq $fixture.title) "Output title differs: $($tags.title)"
            $expectedArtist = if ($fixture.title -eq $unicodeTitle) { $unicodeArtist } else { 'Source artist' }
            $expectedAlbum = if ($fixture.title -eq $unicodeTitle) { $unicodeAlbum } else { 'Source album' }
            Assert-True ($tags.artist -eq $expectedArtist -and $tags.album -eq $expectedAlbum) 'Source artist/album should be retained.'
            Assert-True ($tags.comment -eq 'Synthetic source comment' -and $tags.track -eq '4') 'Source comment/track should be retained.'
            $observed += [pscustomobject]@{ output = $fixture.output; basename_length = $file.BaseName.Length; tags = $tags }
        }
        Assert-True ([IO.Path]::GetFileNameWithoutExtension($longOutput).Length -eq 60) 'Long-name fixture should exercise the exact default maximum.'
        return $observed
    }

    foreach ($override in @(
        [pscustomobject]@{ name = 'Plain metadata overrides'; artist = 'Override artist'; album = 'Override album' },
        [pscustomobject]@{ name = 'Unicode metadata overrides'; artist = $unicodeArtist; album = $unicodeAlbum }
    )) {
        $overrideRun = Invoke-Conversion $override.name $overrideInput @('-Artist', $override.artist, '-Album', $override.album)
        Add-Check $override.name 'A05' 'Artist/Album overrides win while source Ogg title/comment/track survive.' {
            Assert-True ($overrideRun.ExitCode -eq 0 -and $overrideRun.Files.Count -eq 1) 'Override run should produce one successful output.'
            $tags = (Read-Media $overrideRun.Files[0].FullName).format.tags
            Assert-True ($tags.artist -eq $override.artist -and $tags.album -eq $override.album) 'Artist/Album override mismatch.'
            Assert-True ($tags.title -eq 'Original Vorbis title' -and $tags.comment -eq 'Synthetic source comment' -and $tags.track -eq '4') 'Override should preserve other Ogg stream tags.'
            return $tags
        }
    }

    $invalidDateRun = Invoke-Conversion 'Impossible leading date observation' $invalidDateInput
    $impossiblePreserved = $invalidDateRun.Record.output_files -contains '2024-02-30 - Impossible.mp3'
    $checks.Add([pscustomobject]@{
        id = 'impossible_leading_date'; acceptance = 'future A18'; required = $false
        status = $(if ($impossiblePreserved) { 'observed_gap' } else { 'observed_behavior' })
        expected = 'Record baseline behavior; v1 date validation is a later task.'
        observed = [pscustomobject]@{ invalid_date_preserved = $impossiblePreserved; run = $invalidDateRun.Record }
    })
    foreach ($faultCase in @(
        [pscustomobject]@{ name = 'Corrupt only exit observation'; input = $corruptInput },
        [pscustomobject]@{ name = 'Mixed valid and corrupt exit observation'; input = $mixedInput }
    )) {
        $faultRun = Invoke-Conversion $faultCase.name $faultCase.input
        $failedReported = $null -ne $faultRun.Summary -and $faultRun.Summary.failed -gt 0
        $checks.Add([pscustomobject]@{
            id = $faultCase.name; acceptance = 'future A27'; required = $false
            status = $(if ($failedReported -and $faultRun.ExitCode -eq 0) { 'observed_gap' } else { 'observed_behavior' })
            expected = 'Record actual batch exit versus reported failures; no claim that failure aggregation is fixed.'
            observed = [pscustomobject]@{ failed_files_reported = $failedReported; run = $faultRun.Record }
        })
    }
}
catch {
    $fatalError = $_.Exception.Message
    $checks.Add([pscustomobject]@{
        id = 'characterization_execution'; acceptance = 'A04-A06'; required = $true
        status = 'fail'; expected = 'Complete the focused isolated baseline matrix.'; observed = $fatalError
    })
    Write-Host "FAIL: characterization_execution - $fatalError"
}
finally {
    $env:PATH = $originalPath
    if ($inventoryBefore.Count -gt 0) {
        try {
            Assert-NoReparseTree $ownedParent
            $inventoryAfter = Get-SourceInventory
            $directoriesAfter = Get-DirectoryInventory
            Add-Check 'source_bytes_and_relative_names_unchanged' 'A06' 'All generated source/fixture relative names, lengths and SHA-256 hashes are unchanged.' {
                $beforeJson = ConvertTo-Json -InputObject @($inventoryBefore) -Depth 5 -Compress
                $afterJson = ConvertTo-Json -InputObject @($inventoryAfter) -Depth 5 -Compress
                Assert-True ($beforeJson -ceq $afterJson) 'Source inventory changed during baseline conversions.'
                $directoriesBeforeJson = ConvertTo-Json -InputObject @($directoriesBefore) -Compress
                $directoriesAfterJson = ConvertTo-Json -InputObject @($directoriesAfter) -Compress
                Assert-True ($directoriesBeforeJson -ceq $directoriesAfterJson) 'Source relative directory names changed during baseline conversions.'
                return [pscustomobject]@{ files_compared = $inventoryBefore.Count; directories_compared = $directoriesBefore.Count; identical = $true }
            }
        }
        catch {
            $checks.Add([pscustomobject]@{
                id = 'source_inventory_read'; acceptance = 'A06'; required = $true
                status = 'fail'; expected = 'Read the final source inventory.'; observed = $_.Exception.Message
            })
        }
    }
    $failedChecks = @($checks | Where-Object { $_.required -and $_.status -ne 'pass' })
    $result = [ordered]@{
        schema_version = 1
        suite = 'T03 isolated replay of T02 baseline characterization'
        started_utc = $startedUtc
        completed_utc = [DateTime]::UtcNow.ToString('o')
        status = $(if ($failedChecks.Count -eq 0) { 'pass' } else { 'fail' })
        fatal_error = $fatalError
        environment = [pscustomobject]$environmentRecord
        isolation = [pscustomobject]@{ application_copy = $ApplicationScript; fixture_root = $WorkRoot; output_parent = $OutputParent; cleanup_owner = 'Invoke-IsolatedBaseline.ps1' }
        fixtures = @($fixtureDefinitions)
        checks = $checks.ToArray()
        runs = $runs.ToArray()
        commands = $commands.ToArray()
        source_inventory_before = @($inventoryBefore)
        source_inventory_after = @($inventoryAfter)
        source_directories_before = @($directoriesBefore)
        source_directories_after = @($directoriesAfter)
    }
    if ($resultPathApproved) {
        Assert-NoReparseTree $ownedParent
        $json = ConvertTo-Json -InputObject $result -Depth 15
        # Exclusive creation prevents a concurrent file from being overwritten.
        $resultStream = [IO.File]::Open($ResultPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $resultWriter = New-Object IO.StreamWriter($resultStream, (New-Object Text.UTF8Encoding($false)))
            try { $resultWriter.Write($json) }
            finally { $resultWriter.Dispose() }
        }
        finally { $resultStream.Dispose() }
    }
    else { Write-Host 'No result file written because the supplied ownership/path boundary was not validated.' }
}

if ($failedChecks.Count -gt 0) { exit 1 }
Write-Host "Focused characterization passed on PowerShell $($PSVersionTable.PSVersion); known gaps remain explicit observations."
exit 0
