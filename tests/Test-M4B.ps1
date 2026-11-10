<# Real synthetic media checks. Quick is the short CI regression, and Smoke can
   exercise the direct entry point extracted from an independently downloaded ZIP. #>
[CmdletBinding()]
param(
    [ValidateSet('Full', 'Quick', 'Smoke')][string]$Mode = 'Full',
    [string]$ApplicationPath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe',
    [string]$ExpectedAppVersion = '1.0.7'
)

$ErrorActionPreference = 'Stop'
if (-not $ApplicationPath) { $ApplicationPath = Join-Path $PSScriptRoot '../AudioFileForPhone.ps1' }
$ApplicationPath = [IO.Path]::GetFullPath($ApplicationPath)
$FfmpegPath = [IO.Path]::GetFullPath($FfmpegPath)
$FfprobePath = [IO.Path]::GetFullPath($FfprobePath)
$toolDirectory = [IO.Path]::GetDirectoryName($FfmpegPath)
. (Join-Path $PSScriptRoot '../AudioFileForPhone.Helpers.ps1')

function Assert-M4B([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Invoke-M4BNative([string]$Exe, [string[]]$Argv, [int]$ExitCode = 0) {
    $result = Invoke-AudioNativeProcess -ExecutablePath $Exe -Arguments $Argv -TimeoutMilliseconds 600000
    Assert-M4B ($result.Status -ceq 'Completed' -and $result.ExitCode -eq $ExitCode -and $result.ProcessReleased -and $result.PipeDrainCompleted -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) (
        '{0}: expected exit {1}, observed {2}/{3}. {4} {5} {6}' -f $Exe, $ExitCode, $result.Status, $result.ExitCode, $result.Error, $result.Stderr, $result.Stdout)
    return $result
}
function Invoke-M4BFfmpeg([string[]]$Argv) {
    return Invoke-M4BNative $FfmpegPath (@('-nostdin', '-hide_banner', '-v', 'error') + $Argv)
}
function Get-M4BProbe([string]$Path) {
    return (Invoke-M4BNative $FfprobePath @('-v', 'error', '-show_format', '-show_streams', '-show_chapters', '-of', 'json', '-i', $Path)).Stdout | ConvertFrom-Json
}
function Get-M4BSeconds($Value) {
    return [double]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture)
}
function New-M4BAudio([string]$Path, [string]$Codec, [string]$Muxer, [int]$Channels) {
    $null = Invoke-M4BFfmpeg @('-f', 'lavfi', '-i', 'sine=frequency=521:sample_rate=44100:duration=3',
        '-c:a', $Codec, '-ac', [string]$Channels, '-f', $Muxer, $Path)
}
function Get-M4BInventory([string]$Directory) {
    return @(Get-ChildItem -LiteralPath $Directory -File -Force -Recurse | Sort-Object FullName |
        ForEach-Object { Get-FileHash -LiteralPath $_.FullName })
}
function Invoke-M4BApp([string]$InputRoot, [string]$Destination, [string[]]$Options = @(), [int]$ExitCode = 0, [switch]$Preview) {
    $before = Get-M4BInventory $InputRoot | ConvertTo-Json -Compress
    $appArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File')
    if ($Preview) {
        # Normalize redirected Windows PowerShell console encoding for JSON plan
        # comparisons. Conversion still invokes the app directly through -File.
        $driver = Join-Path $root 'preview.ps1'
        [IO.File]::WriteAllText($driver, @'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
& $args[0] -InputFolder $args[1] -OutputParent $args[2] -FfmpegDirectory $args[3] -ConfigPath $args[4] -DryRun -Interactive
exit $LASTEXITCODE
'@)
        $appArguments += @($driver, $ApplicationPath, $InputRoot, $Destination, $toolDirectory, $config)
    } else {
        $appArguments += @($ApplicationPath, '-InputFolder', $InputRoot, '-OutputParent', $Destination,
            '-FfmpegDirectory', $toolDirectory, '-ConfigPath', $config)
    }
    if ($Options) { $appArguments += $Options }
    $result = Invoke-M4BNative $shell $appArguments $ExitCode
    $after = Get-M4BInventory $InputRoot | ConvertTo-Json -Compress
    Assert-M4B ($before -ceq $after) 'An input file changed or an input file was added or removed.'
    Assert-M4B (-not (Test-Path -LiteralPath $config)) 'The isolated configuration was written.'
    return $result.Stdout
}
function Get-M4BManifest([string]$Destination, [int]$Converted, [int]$Failed = 0, [int]$Bitrate = 64, [int]$Unsupported = 0) {
    $files = @(Get-ChildItem -LiteralPath $Destination -File -Recurse)
    $manifestFiles = @($files | Where-Object Name -ceq 'AudioFileForPhone_manifest.json')
    Assert-M4B ($manifestFiles.Count -eq 1) "Expected one run manifest in '$Destination'."
    $data = Get-Content -LiteralPath $manifestFiles[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-M4B ($data.app_version -ceq $ExpectedAppVersion -and $data.totals.converted -eq $Converted -and
        $data.totals.failed -eq $Failed -and $data.totals.unsupported -eq $Unsupported -and $data.records.Count -eq ($Converted + $Failed) -and
        $data.policies.bitrate_kbps -eq $Bitrate -and $data.policies.full_output_decode_required -eq $true -and
        @($data.policies.supported_extensions | Sort-Object) -join ',' -ceq '.m4a,.m4b,.mp3,.ogg') (
        'Unexpected manifest version, count, bitrate or format policy. ' + ($data.totals | ConvertTo-Json -Compress))
    $published = @($files | Where-Object Extension -ieq '.mp3')
    $temporaries = @(Get-ChildItem -LiteralPath $Destination -Force -Recurse |
        Where-Object { $_.Name -like '*.partial' -or $_.Name -like '.AudioFileForPhone-recovery-*' })
    Assert-M4B ($published.Count -eq $Converted -and $temporaries.Count -eq 0) 'Unexpected published MP3 or private temporary path count.'
    return $data
}
function Confirm-M4BOutput([object]$Data, [object]$Record, [double]$Duration, [int]$Channels = 0, [bool]$Cover = $false) {
    $path = Join-Path $Data.run.output_root $Record.output_relative_path
    Assert-M4B ($Record.status -ceq 'Converted' -and (Test-Path -LiteralPath $path -PathType Leaf)) "Output missing for '$($Record.source_relative_path)'."
    $probe = Get-M4BProbe $path
    $audio = @($probe.streams | Where-Object codec_type -ceq 'audio')
    $art = @($probe.streams | Where-Object { $_.disposition.attached_pic -eq 1 })
    Assert-M4B ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq (1000 * $Data.policies.bitrate_kbps) -and
        ($Channels -eq 0 -or $audio[0].channels -eq $Channels) -and $probe.streams.Count -eq (1 + [int]$Cover) -and $art.Count -eq [int]$Cover) (
        "Wrong audio or artwork stream in '$($Record.source_relative_path)'.")
    if ($Cover) {
        Assert-M4B ($art[0].codec_name -ceq 'mjpeg' -and $art[0].width -eq 90 -and $art[0].height -eq 60) 'The supplied cover was not selected.'
    }
    Assert-M4B ([math]::Abs((Get-M4BSeconds $audio[0].duration) - $Duration) -le 0.35) "Wrong MP3 duration in '$path'."
    $decode = Invoke-M4BFfmpeg @('-xerror', '-err_detect', 'explode', '-i', $path, '-map', '0:a:0',
        '-af', 'asetpts=N/SR/TB', '-progress', 'pipe:1', '-stats_period', '86400', '-f', 'null', '-')
    $endpoint = [regex]::Matches($decode.Stdout, '(?m)^out_time_us=(\d+)\s*$')
    Assert-M4B ($decode.Stderr.Length -eq 0 -and $decode.Stdout -match '(?m)^progress=end\s*$' -and $endpoint.Count -gt 0 -and
        [math]::Abs(([double]$endpoint[$endpoint.Count - 1].Groups[1].Value / 1000000) - $Duration) -le 0.35) "Full decoded duration differs for '$path'."
    return $probe
}
function Confirm-M4BChapters([object]$Probe, [object[]]$Expected) {
    Assert-M4B ($Probe.chapters.Count -eq $Expected.Count) 'The chapter count changed.'
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        $actual = $Probe.chapters[$i]
        $chapter = $Expected[$i]
        # The MP3 muxer stores chapter offsets at millisecond precision.
        Assert-M4B ($actual.tags.title -ceq $chapter.tags.title -and
            [math]::Abs((Get-M4BSeconds $actual.start_time) - (Get-M4BSeconds $chapter.start_time)) -le 0.002 -and
            [math]::Abs((Get-M4BSeconds $actual.end_time) - (Get-M4BSeconds $chapter.end_time)) -le 0.002) (
            "Chapter $i title or time range changed.")
    }
}
function New-M4BSubdirectory([string]$Relative) {
    return [IO.Directory]::CreateDirectory((Join-Path $root $Relative)).FullName
}
function Remove-M4BTestDirectory {
    $resolved = (Resolve-Path -LiteralPath $root).ProviderPath
    Assert-M4B ($resolved -ceq $root -and [IO.Path]::GetDirectoryName($resolved) -ceq $temp -and
        [IO.File]::ReadAllText($marker) -ceq $token) 'Refusing cleanup outside the marker-owned temporary directory.'
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($resolved)
    while ($pending.Count -gt 0) {
        $item = Get-Item -LiteralPath $pending.Pop() -Force
        Assert-M4B (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing to clean a reparse point.'
        if ($item.PSIsContainer) {
            foreach ($child in Get-ChildItem -LiteralPath $item.FullName -Force) { $pending.Push($child.FullName) }
        }
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$shell = (Get-Process -Id $PID).Path
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$token = [guid]::NewGuid().ToString('N')
$root = Join-Path $temp ('AFP-M4B-' + $token.Substring(0, 8))
$marker = Join-Path $root '.owner'
$config = Join-Path $root 'unused-config.json'
$appBefore = Get-FileHash -LiteralPath $ApplicationPath, (Join-Path ([IO.Path]::GetDirectoryName($ApplicationPath)) 'AudioFileForPhone.Helpers.ps1')
Assert-M4B ($toolDirectory -ieq [IO.Path]::GetDirectoryName($FfprobePath) -and (Test-Path -LiteralPath $FfmpegPath -PathType Leaf) -and
    (Test-Path -LiteralPath $FfprobePath -PathType Leaf) -and -not (Test-Path -LiteralPath $root)) 'Expected a selected tool pair and a fresh temporary root.'
Assert-AudioNoReparseAncestor -Path $temp
$null = [IO.Directory]::CreateDirectory($root)
$stream = [IO.File]::Open($marker, [IO.FileMode]::CreateNew)
try { $bytes = [Text.Encoding]::ASCII.GetBytes($token); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }

try {
    $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ("M4B $Mode on $($os.Caption) $($os.BuildNumber).$($windows.UBR) $($os.OSArchitecture), PowerShell $($PSVersionTable.PSVersion)")
    Write-Host ((Invoke-M4BFfmpeg @('-version')).Stdout.Split([char]10)[0].Trim())
    $mixedRoot = New-M4BSubdirectory 'mixed'
    $mixedNested = New-M4BSubdirectory 'mixed/[nested]'
    New-M4BAudio (Join-Path $mixedRoot '2024-01-02 - Book.m4a') 'aac' 'ipod' 1
    New-M4BAudio (Join-Path $mixedRoot '2024-01-02 - Book.m4b') 'aac' 'ipod' 2
    New-M4BAudio (Join-Path $mixedRoot '2024-01-02 - Book.mp3') 'libmp3lame' 'mp3' 1
    New-M4BAudio (Join-Path $mixedNested "03 - L'été & [écoute].ogg") 'libvorbis' 'ogg' 1
    $templates = @(Get-ChildItem -LiteralPath $mixedRoot -File -Recurse)
    if ($Mode -eq 'Full') {
        foreach ($i in 5..29) {
            $template = $templates[$i % $templates.Count]
            $name = ("2024-02-{0:D2} - L'été & [Lecture {0}]{1}" -f $i, $template.Extension)
            [IO.File]::Copy($template.FullName, (Join-Path $mixedNested $name))
        }
    }
    $mixedCount = if ($Mode -ceq 'Full') { 29 } else { 4 }
    $mixedRuns = if ($Mode -ceq 'Full') { 2 } else { 1 }
    $priorNames = $null
    foreach ($i in 1..$mixedRuns) {
        $destination = Join-Path $root "mixed-out-$i"
        $null = Invoke-M4BApp $mixedRoot $destination
        $data = Get-M4BManifest $destination $mixedCount
        $names = @($data.records.output_relative_path)
        Assert-M4B (@($names | Sort-Object -Unique).Count -eq $mixedCount -and
            @($names | Where-Object { $_ -match '^mixed[\\/]2024-01-02 - Book' }).Count -eq 3 -and
            @($names | Where-Object { $_ -match '^mixed[\\/]\[nested\][\\/]' }).Count -eq ($mixedCount - 3)) 'The date, relative layout or collision names changed.'
        if ($priorNames) { Assert-M4B (($names -join '|') -ceq ($priorNames -join '|')) 'Name plans differ across fresh destinations.' }
        $priorNames = $names
        foreach ($record in $data.records) {
            $null = Confirm-M4BOutput $data $record 3
        }
        Write-Host "Mixed synthetic batch $i verified $mixedCount/$mixedCount outputs at 64 kbps, including independent full decoding."
    }

    if ($Mode -ne 'Smoke') {
        $books = New-M4BSubdirectory 'books'
        $nested = New-M4BSubdirectory 'books/[nested]'
        $null = New-M4BSubdirectory 'books/not-a-file.m4b'
        $rich = Join-Path $books "2024-01-02 - L'été & [écoute].m4b"
        $stereo = Join-Path $books '2024-01-03 - No title.m4B'
        $alac = Join-Path $nested '2024-01-04 - Sans chapitres.M4B'
        $chapterFile = Join-Path $root 'chapters.ffmetadata'
        $sourceCover = Join-Path $root 'source.png'
        $cover = Join-Path $root 'explicit.png'
        $title = 'Äänikirja – été'
        $artist = 'Alkuperäinen ääni'
        $album = 'Livres – ääni'
        $overrideArtist = 'Valittu ääni'
        $overrideAlbum = 'Édition spéciale'
        [IO.File]::WriteAllText($chapterFile, @'
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=1100
title=Début
[CHAPTER]
TIMEBASE=1/1000
START=1100
END=3000
title=Loppu – yö
'@, (New-Object Text.UTF8Encoding($false)))
        $null = Invoke-M4BFfmpeg @('-f', 'lavfi', '-i', 'color=cyan:s=64x64', '-frames:v', '1', '-threads', '1', '-update', '1', $sourceCover)
        $null = Invoke-M4BFfmpeg @('-f', 'lavfi', '-i', 'color=yellow:s=90x60', '-frames:v', '1', '-threads', '1', '-update', '1', $cover)
        $null = Invoke-M4BFfmpeg @('-f', 'lavfi', '-i', 'color=navy:s=48x48:r=1:d=3',
            '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=3',
            '-f', 'lavfi', '-i', 'sine=frequency=780:sample_rate=44100:duration=3',
            '-i', $sourceCover, '-f', 'ffmetadata', '-i', $chapterFile,
            '-map', '0:v:0', '-map', '1:a:0', '-map', '2:a:0', '-map', '3:v:0', '-map_chapters', '4',
            '-c:v:0', 'mpeg4', '-c:v:1', 'png', '-disposition:v:1', 'attached_pic', '-c:a', 'aac', '-ac:a:0', '1', '-ac:a:1', '2',
            '-metadata', "title=$title", '-metadata', "artist=$artist", '-metadata', "album=$album", '-metadata', 'track=3/8',
            '-metadata', 'disc=1/2', '-metadata', 'genre=Audiobook', '-metadata', 'comment=Tag roundtrip',
            '-movflags', 'disable_chpl', '-f', 'mp4', $rich)
        New-M4BAudio $stereo 'aac' 'ipod' 2
        New-M4BAudio $alac 'alac' 'ipod' 1
        foreach ($file in @($rich, $stereo, $alac)) {
            $media = Get-M4BProbe $file
            $firstAudio = @($media.streams | Where-Object codec_type -ceq 'audio')[0]
            $expectedCodec = if ($file -ceq $alac) { 'alac' } else { 'aac' }
            $expectedChannels = if ($file -ceq $stereo) { 2 } else { 1 }
            Assert-M4B ($media.format.format_name -match '(^|,)mp4(,|$)' -and $firstAudio.codec_name -ceq $expectedCodec -and
                $firstAudio.channels -eq $expectedChannels) 'Generated source did not have the intended MP4-family container, codec or audio channels.'
        }
        $richMedia = Get-M4BProbe $rich
        Assert-M4B ($richMedia.chapters.Count -eq 2 -and $richMedia.chapters[0].tags.title -ceq 'Début' -and
            $richMedia.chapters[1].tags.title -ceq 'Loppu – yö' -and
            @($richMedia.streams | Where-Object codec_type -ceq 'data').Count -eq 1 -and
            @($richMedia.streams | Where-Object { $_.disposition.attached_pic -eq 1 }).Count -eq 1 -and
            @($richMedia.streams | Where-Object codec_type -ceq 'audio').Count -eq 2 -and
            $richMedia.streams[0].codec_type -ceq 'video') 'Rich fixture lacks chapters, chapter data, source artwork, or a nonzero first audio index.'
        [IO.File]::Copy($stereo, (Join-Path $books 'ignore.m4b.tmp'))
        [IO.File]::Copy($stereo, (Join-Path $books 'ignore.mp4'))
        [IO.File]::Copy($stereo, (Join-Path $books ('ignore.m4b' + [char]0x200B)))
        $destination = Join-Path $root 'preview-absent'
        $preview = Invoke-M4BApp $books $destination -Preview
        $planned = @([regex]::Matches($preview, '(?m)^\[PLAN\] (\{.*\})\r?$') | ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
        Assert-M4B ($preview -match 'unsupported files: 3' -and $planned.Count -eq 3 -and -not (Test-Path -LiteralPath $destination) -and
            @($planned.source_relative_path | Where-Object { $_ -cmatch '\.m4b$|\.M4B$|\.m4B$' }).Count -eq 3) 'Read-only preview counts or exact case-insensitive extensions changed.'
        foreach ($withCover in @($false, $true)) {
            $rate = if ($withCover) { 96 } else { 64 }
            $destination = Join-Path $root "books-out-$rate"
            $options = if ($withCover) { @('-CoverPath', $cover, '-Artist', $overrideArtist, '-Album', $overrideAlbum, '-BitrateKbps', '96') } else { @() }
            $null = Invoke-M4BApp $books $destination $options
            $data = Get-M4BManifest $destination 3 0 $rate 3
            Assert-M4B (($data.records.output_relative_path -join '|') -ceq ($planned.output_relative_path -join '|')) 'Preview and conversion planned different paths.'
            foreach ($record in $data.records) {
                $leaf = [IO.Path]::GetFileName($record.source_relative_path)
                $channels = if ($leaf -ceq [IO.Path]::GetFileName($stereo)) { 2 } else { 1 }
                $probe = Confirm-M4BOutput $data $record 3 $channels $withCover
                $tags = $probe.format.tags
                if ($leaf -ceq [IO.Path]::GetFileName($rich)) {
                    Confirm-M4BChapters $probe $richMedia.chapters
                    Assert-M4B ($tags.title -ceq $title -and $tags.track -ceq '3/8' -and $tags.disc -ceq '1/2' -and
                        $tags.genre -ceq 'Audiobook' -and $tags.comment -ceq 'Tag roundtrip') 'Mapped container metadata changed.'
                    if (-not $withCover) { Assert-M4B ($tags.artist -ceq $artist -and $tags.album -ceq $album) 'Source Artist/Album did not roundtrip.' }
                } else {
                    Assert-M4B ($probe.chapters.Count -eq 0 -and $tags.title -ceq [IO.Path]::GetFileNameWithoutExtension($record.output_relative_path)) 'Missing-title fallback or chapterless output changed.'
                }
                if ($withCover) { Assert-M4B ($tags.artist -ceq $overrideArtist -and $tags.album -ceq $overrideAlbum) 'Explicit metadata did not override source tags.' }
            }
        }
        Write-Host 'M4B-only preview and conversion verified AAC mono/stereo, ALAC, Unicode container tags, chapter fields, selected first audio, and both cover policies.'

        $brokenRoot = New-M4BSubdirectory 'partial'
        $brokenName = '2024-01-01 - Unreadable.m4b'
        [IO.File]::WriteAllText((Join-Path $brokenRoot $brokenName), 'Synthetic damaged MP4-family input')
        [IO.File]::Copy($alac, (Join-Path $brokenRoot '2024-01-02 - Good.M4B'))
        $destination = Join-Path $root 'partial-out'
        $console = Invoke-M4BApp $brokenRoot $destination @() 2
        $data = Get-M4BManifest $destination 1 1
        $failed = $data.records[0]
        Assert-M4B ($data.run.exit_code -eq 2 -and $data.run.status -ceq 'CompletedWithFailures' -and
            $failed.source_relative_path -ceq $brokenName -and $failed.status -ceq 'Failed' -and $failed.code -ceq 'ProbeFailed' -and
            $console.Contains($brokenName) -and -not (Test-Path -LiteralPath (Join-Path $data.run.output_root $failed.output_relative_path))) (
            'Unreadable M4B was not reported by name with a safe partial failure.')
        $null = Confirm-M4BOutput $data $data.records[1] 3 1
        Write-Host 'Unreadable M4B reported by name, exit 2, no partial MP3, and the next M4B fully decoded.'
    }

    if ($Mode -ceq 'Full') {
        $longRoot = New-M4BSubdirectory 'long'
        $book = Join-Path $longRoot '2024-01-02 - Two hour book.m4b'
        $frequencies = @(311, 613, 997)
        $inputs = @(foreach ($frequency in $frequencies) { '-f'; 'lavfi'; '-i'; "sine=frequency=${frequency}:sample_rate=16000:duration=2401" })
        $null = Invoke-M4BFfmpeg ($inputs + @('-filter_complex', '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]', '-map', '[out]',
            '-c:a', 'aac', '-b:a', '24k', '-f', 'ipod', $book))
        $source = Get-M4BProbe $book
        Assert-M4B ($source.format.format_name -match '(^|,)mp4(,|$)' -and $source.streams[0].codec_name -ceq 'aac' -and
            [math]::Abs((Get-M4BSeconds $source.streams[0].duration) - 7203) -le 0.35) 'Long fixture is not the intended 7203-second AAC book.'
        $destination = Join-Path $root 'long-out'
        $null = Invoke-M4BApp $longRoot $destination
        $data = Get-M4BManifest $destination 1
        $record = $data.records[0]
        $probe = Confirm-M4BOutput $data $record 7203 1
        $output = Join-Path $data.run.output_root $record.output_relative_path
        # Start each seek half a second early so MP3 bit-reservoir warm-up
        # does not dilute the one-second frequency measurement.
        $offsets = @('0.5', '3599.5', '7198.5')
        $sampleFilter = 'atrim=start=0.5:duration=1,asetpts=PTS-STARTPTS,astats=measure_perchannel=Zero_crossings_rate:measure_overall=none'
        for ($i = 0; $i -lt $offsets.Count; $i++) {
            $segment = Invoke-M4BNative $FfmpegPath @('-nostdin', '-hide_banner', '-v', 'info', '-xerror', '-ss', $offsets[$i],
                '-i', $output, '-map', '0:a:0', '-t', '1', '-af', $sampleFilter, '-f', 'null', '-')
            $crossing = [regex]::Match($segment.Stderr, 'Zero crossings rate: ([\d.]+)')
            Assert-M4B $crossing.Success "No decoded frequency signature at $($offsets[$i]) seconds."
            $frequency = (Get-M4BSeconds $crossing.Groups[1].Value) * [int]$probe.streams[0].sample_rate / 2
            Assert-M4B ([math]::Abs($frequency - $frequencies[$i]) -lt 10) "Wrong decoded segment at $($offsets[$i]) seconds."
        }
        Write-Host 'Long M4B verified full 7203-second decode and matching beginning, middle and near-end audio signatures.'
    }
    $appAfter = Get-FileHash -LiteralPath $appBefore.Path
    Assert-M4B (($appBefore | ConvertTo-Json -Compress) -ceq ($appAfter | ConvertTo-Json -Compress)) 'The application or its helper changed.'
    Remove-M4BTestDirectory
    Write-Host "M4B $Mode passed. Sources and application bytes unchanged."
}
catch {
    Write-Host "M4B $Mode failed. Owned synthetic data retained at $root"
    throw
}
