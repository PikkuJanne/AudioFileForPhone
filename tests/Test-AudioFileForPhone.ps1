<#
Integration checks using generated audio and real ffmpeg/ffprobe (no Pester).
Run from either Windows PowerShell 5.1 or PowerShell 7:
    .\tests\Test-AudioFileForPhone.ps1
Fixtures, unchanged script copies and output use a uniquely owned TEMP tree.
Each conversion receives a fresh OutputParent. The live Music folder is not used.
#>
[CmdletBinding()]
param([string]$FfmpegPath, [string]$FfprobePath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$productionScript = Join-Path $projectRoot 'AudioFileForPhone.ps1'
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$originalPath = $env:PATH
$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd('\', '/')
$testName = 'AudioFileForPhone-tests-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.integration-owner'
$ownedRootCreated = $false

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Find-Tool {
    param([string]$Name, [string]$ExplicitPath)
    if ($ExplicitPath) {
        $resolved = (Resolve-Path -LiteralPath $ExplicitPath -ErrorAction Stop).ProviderPath
        Assert-True ((Test-Path -LiteralPath $resolved -PathType Leaf) -and
            [IO.Path]::GetFileName($resolved) -ieq $Name) "Expected an executable named $Name."
        return $resolved
    }
    $localPath = Join-Path $projectRoot $Name
    if (Test-Path -LiteralPath $localPath -PathType Leaf) { return $localPath }
    return (Get-Command $Name -CommandType Application -ErrorAction Stop).Source
}

function Assert-NoReparseTree {
    param([string]$Path, [switch]$AncestorsOnly)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse ancestor refused: $($item.FullName)"
        $item = $item.Parent
    }
    if ($AncestorsOnly) { return }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($child in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse child refused: $($child.FullName)"
            if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
}

function Get-SourceInventory {
    param([string]$Path)
    Assert-NoReparseTree $Path
    return @(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
            length = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
}

function Invoke-Native {
    param([string]$Executable, [string[]]$Arguments, [int]$ExpectedExitCode = 0)
    # PowerShell 5.1 represents native stderr as ErrorRecords; capture diagnostics
    # without turning successful ffmpeg progress output into terminating errors.
    $ErrorActionPreference = 'Continue'
    $nativeOutput = @(& $Executable @Arguments 2>&1)
    $nativeExitCode = $LASTEXITCODE
    if ($nativeExitCode -ne $ExpectedExitCode) {
        throw "$Executable exited $nativeExitCode (expected $ExpectedExitCode).`n$($nativeOutput -join "`n")"
    }
    return $nativeOutput
}

function Read-Media {
    param([string]$Path)
    $json = Invoke-Native $ffprobe @('-v', 'error', '-show_format', '-show_streams', '-of', 'json', $Path)
    return ($json -join "`n" | ConvertFrom-Json)
}

function New-Audio {
    param([string]$Path, [string]$Codec, [string]$Title)
    $nativeArgs = @('-hide_banner', '-loglevel', 'error', '-y', '-f', 'lavfi',
        '-i', 'sine=frequency=440:sample_rate=48000:duration=0.4', '-c:a', $Codec)
    if ($Title) { $nativeArgs += @('-metadata', "TITLE=$Title") }
    $nativeArgs += @('-metadata', 'artist=Source artist', '-metadata', 'album=Source album',
        '-metadata', 'comment=Source comment', '-metadata', 'track=3', $Path)
    Invoke-Native $ffmpeg $nativeArgs | Out-Null
}

function Invoke-Conversion {
    param([string]$Name, [string]$InputPath, [string[]]$Options = @(), [int]$ExpectedExitCode = 0)
    $runDir = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $runDir | Out-Null
    $outputParent = Join-Path $runDir 'Outputs [literal]'
    Assert-True (-not (Test-Path -LiteralPath $outputParent)) "$Name must use a fresh output parent."
    $scriptCopy = Join-Path $runDir 'AudioFileForPhone.ps1'
    Copy-Item -LiteralPath $productionScript -Destination $scriptCopy
    Assert-True ((Get-FileHash -LiteralPath $scriptCopy).Hash -eq (Get-FileHash -LiteralPath $productionScript).Hash) 'Application copy must be byte-identical.'
    $sourceBefore = ConvertTo-Json -InputObject @(Get-SourceInventory $InputPath) -Compress
    $nativeArgs = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
        '-File', $scriptCopy, '-InputFolder', $InputPath, '-OutputParent', $outputParent) + $Options
    $ErrorActionPreference = 'Continue'
    $nativeOutput = @(& $shellPath @nativeArgs 2>&1)
    $nativeExitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $sourceAfter = ConvertTo-Json -InputObject @(Get-SourceInventory $InputPath) -Compress
    Assert-True ($sourceBefore -ceq $sourceAfter) "$Name must preserve all source names and SHA-256 hashes."
    $roots = @($nativeOutput | ForEach-Object {
        if ("$_" -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1] }
    })
    Assert-True ($roots.Count -eq 1) "$Name should report exactly one output root."
    $outputRoot = [IO.Path]::GetFullPath($roots[0]).TrimEnd('\', '/')
    Assert-True ((Split-Path -Parent $outputRoot) -ieq $outputParent) "$Name should write only under its explicit OutputParent."
    Assert-True ((Split-Path -Leaf $outputRoot) -match '^AudioForPhone_\d+kbps_\d{8}_\d{6}$') "$Name should use the timestamped output name."
    Assert-True (Test-Path -LiteralPath $outputParent -PathType Container) "$Name should create its missing OutputParent literally."
    Assert-True (@(Get-ChildItem -LiteralPath $outputParent -Directory).Count -eq 1) "$Name should create exactly one owned output run."
    Assert-True ($nativeExitCode -eq $ExpectedExitCode) "$Name exited $nativeExitCode (expected $ExpectedExitCode).`n$($nativeOutput -join "`n")"
    Assert-True (@(Get-ChildItem -LiteralPath $runDir -Directory -Filter 'AudioForPhone_*').Count -eq 0) "$Name should not create output beside the script."
    Assert-True (Test-Path -LiteralPath $outputRoot -PathType Container) "$Name should create its output root."
    return [pscustomobject]@{
        Base = Join-Path $outputRoot (Split-Path -Leaf $InputPath)
        Log = Get-Content -LiteralPath (Join-Path $outputRoot 'AudioFileForPhone_log.txt') -Raw
    }
}

function Assert-Mp3 {
    param([string]$Path, [int]$BitrateKbps, [bool]$HasCover = $false)
    $media = Read-Media $Path
    $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
    $video = @($media.streams | Where-Object { $_.codec_type -eq 'video' })
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3') "$Path should contain MP3 audio."
    Assert-True ([int]$audio[0].bit_rate -eq $BitrateKbps * 1000) "$Path should use ${BitrateKbps}kbps audio."
    if ($HasCover) {
        Assert-True ($video.Count -eq 1 -and $video[0].disposition.attached_pic -eq 1) "$Path should embed the supplied cover."
    }
    else {
        Assert-True ($video.Count -eq 0) "$Path should contain no video."
    }
    return $media
}

try {
    $ffmpeg = Find-Tool 'ffmpeg.exe' $FfmpegPath
    $ffprobe = Find-Tool 'ffprobe.exe' $FfprobePath
    # Script copies exercise production PATH discovery without copying binaries.
    $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
    foreach ($selection in @(@{ Name = 'ffmpeg.exe'; Path = $ffmpeg }, @{ Name = 'ffprobe.exe'; Path = $ffprobe })) {
        $firstCandidate = $null
        foreach ($directory in ($env:PATH -split ';' | Where-Object { $_ })) {
            $candidate = Join-Path $directory $selection.Name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $firstCandidate = [IO.Path]::GetFullPath($candidate)
                break
            }
        }
        Assert-True ($firstCandidate -ieq $selection.Path) 'Application PATH discovery must select the same executable used by the test.'
    }
    Assert-NoReparseTree $tempParent -AncestorsOnly
    Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'Unique test root must not already exist.'
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $ownedRootCreated = $true
    $marker = [IO.File]::Open($ownerFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.Encoding]::ASCII.GetBytes($ownerToken)
        $marker.Write($bytes, 0, $bytes.Length)
    }
    finally { $marker.Dispose() }
    $inputDir = Join-Path $testRoot 'Mixed input with spaces'
    $nestedDir = Join-Path $inputDir 'Nested folder\More audio'
    New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null

    $vorbisPath = Join-Path $inputDir '2024-01-01 - Vorbis.ogg'
    $opusPath = Join-Path $nestedDir '2024-01-02 - Opus.OGG'
    New-Audio $vorbisPath 'libvorbis' 'Original Vorbis title'
    New-Audio $opusPath 'libopus' 'Original Opus title'
    New-Audio (Join-Path $inputDir '2024-01-03 - No title! @.ogg') 'libvorbis' ''
    New-Audio (Join-Path $inputDir '2024-01-04 - Shared.mp3') 'libmp3lame' 'Original MP3 title'
    New-Audio (Join-Path $inputDir '2024-01-04 - Shared.m4a') 'aac' 'Original M4A title'
    New-Audio (Join-Path $inputDir '2024-01-04 - Shared.ogg') 'libvorbis' 'Collision Ogg title'
    Set-Content -LiteralPath (Join-Path $inputDir 'ignore.txt') -Value 'Not audio'

    foreach ($fixture in @(
        @{ Path = $vorbisPath; Codec = 'vorbis'; Title = 'Original Vorbis title' },
        @{ Path = $opusPath; Codec = 'opus'; Title = 'Original Opus title' }
    )) {
        $source = Read-Media $fixture.Path
        $sourceAudio = @($source.streams | Where-Object { $_.codec_type -eq 'audio' })[0]
        Assert-True ($sourceAudio.codec_name -eq $fixture.Codec) 'Fixture should use the intended Ogg codec.'
        Assert-True ($sourceAudio.tags.title -eq $fixture.Title) 'Ogg fixture should have stream-level title metadata.'
    }

    $mixed = Invoke-Conversion 'Mixed run' $inputDir
    $outputs = @(Get-ChildItem -LiteralPath $mixed.Base -Recurse -File)
    Assert-True ($outputs.Count -eq 6) 'Mixed input should produce six audio files, ignoring the text file.'
    Assert-True ($mixed.Log -match 'Summary: total=6, converted=6, failed=0') 'Mixed conversion should report all files successful.'
    $titles = @()
    foreach ($output in $outputs) {
        Assert-True ($output.Extension -eq '.mp3') 'Every output extension should be .mp3.'
        $media = Assert-Mp3 $output.FullName 64
        Assert-True ($media.format.tags.artist -eq 'Source artist') 'Source artist should be preserved.'
        Assert-True ($media.format.tags.album -eq 'Source album') 'Source album should be preserved.'
        Assert-True ($media.format.tags.comment -eq 'Source comment') 'Source comment should be preserved.'
        Assert-True ($media.format.tags.track -eq '3') 'Source track number should be preserved.'
        $titles += $media.format.tags.title
    }
    foreach ($title in @('Original Vorbis title', 'Original Opus title', 'Original MP3 title',
        'Original M4A title', 'Collision Ogg title', '2024-01-03 - No title')) {
        Assert-True ($titles -contains $title) "Output should retain or generate title '$title'."
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $mixed.Base 'Nested folder\More audio\2024-01-02 - Opus.mp3')) 'Uppercase OGG should preserve nested folders with spaces.'
    Assert-True (Test-Path -LiteralPath (Join-Path $mixed.Base '2024-01-03 - No title.mp3')) 'Missing-title Ogg should use the sanitized filename.'
    foreach ($name in @('2024-01-04 - Shared.mp3', '2024-01-04 - Shared (2).mp3', '2024-01-04 - Shared (3).mp3')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $mixed.Base $name)) 'Mixed extensions with the same basename should not overwrite each other.'
    }
    Write-Host 'PASS: Vorbis/Opus Ogg, uppercase extension, recursion, tags, fallback title, MP3/M4A, collisions and 64kbps MP3.'

    $coverInput = Join-Path $testRoot 'Cover input'
    New-Item -ItemType Directory -Path $coverInput | Out-Null
    Copy-Item -LiteralPath $vorbisPath -Destination $coverInput
    $coverPath = Join-Path $testRoot 'Small cover.jpg'
    Invoke-Native $ffmpeg @('-hide_banner', '-loglevel', 'error', '-y', '-f', 'lavfi',
        '-i', 'color=c=blue:s=32x32', '-frames:v', '1', '-update', '1', $coverPath) | Out-Null
    $cover = Invoke-Conversion 'Cover run' $coverInput @('-BitrateKbps', '96', '-CoverPath', $coverPath,
        '-Artist', 'Override artist', '-Album', 'Override album')
    Assert-True ($cover.Log -match 'Summary: total=1, converted=1, failed=0') 'Cover conversion should succeed.'
    $coverFiles = @(Get-ChildItem -LiteralPath $cover.Base -File -Filter '*.mp3')
    Assert-True ($coverFiles.Count -eq 1) 'Cover run should produce one MP3.'
    $covered = Assert-Mp3 $coverFiles[0].FullName 96 $true
    Assert-True ($covered.format.tags.title -eq 'Original Vorbis title') 'Ogg title should survive cover embedding.'
    Assert-True ($covered.format.tags.artist -eq 'Override artist') 'Artist override should take precedence.'
    Assert-True ($covered.format.tags.album -eq 'Override album') 'Album override should take precedence.'
    Write-Host 'PASS: Supplied cover, artist/album overrides, preserved Ogg title and custom 96kbps bitrate.'

    $emptyInput = Join-Path $testRoot 'Unsupported input'
    New-Item -ItemType Directory -Path $emptyInput | Out-Null
    Set-Content -LiteralPath (Join-Path $emptyInput 'ignore.txt') -Value 'Not audio'
    $empty = Invoke-Conversion 'Empty run' $emptyInput @() 1
    Assert-True ($empty.Log -match '(?im)No [^\r\n]*OGG[^\r\n]*files found') 'No-supported-files message should mention OGG.'
    Assert-True (@(Get-ChildItem -LiteralPath $empty.Base -Recurse -File).Count -eq 0) 'Unsupported files should create no audio output.'
    Write-Host 'PASS: No-supported-files behavior and OGG diagnostic.'
    Write-Host "All integration checks passed on PowerShell $($PSVersionTable.PSVersion)."
}
finally {
    $env:PATH = $originalPath
    if ($ownedRootCreated -and (Test-Path -LiteralPath $testRoot)) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path.TrimEnd('\', '/')
        if ((Split-Path -Parent $resolvedTestRoot) -ne $tempParent -or
            (Split-Path -Leaf $resolvedTestRoot) -ne $testName -or
            $resolvedTestRoot -cne $testRoot -or
            -not (Test-Path -LiteralPath $ownerFile -PathType Leaf) -or
            [IO.File]::ReadAllText($ownerFile) -cne $ownerToken) {
            throw "Refusing cleanup outside the expected unique TEMP directory: $resolvedTestRoot"
        }
        Assert-NoReparseTree $resolvedTestRoot
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
        Assert-True (-not (Test-Path -LiteralPath $resolvedTestRoot)) 'Owned TEMP cleanup should remove the test tree.'
        Write-Host 'PASS: Owned TEMP cleanup and source hashes.'
    }
}
