<# Synthetic regression for inaccurate source estimates and recoverable MP3 decoder errors.
   ApplicationPath can select an extracted package. No input from the user's folders. #>
[CmdletBinding()]
param(
    [string]$ApplicationPath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
if (-not $ApplicationPath) { $ApplicationPath = Join-Path $PSScriptRoot '../AudioFileForPhone.ps1' }
$ApplicationPath = (Resolve-Path -LiteralPath $ApplicationPath).ProviderPath
$FfmpegPath = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
$FfprobePath = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
$toolDirectory = [IO.Path]::GetDirectoryName($FfmpegPath)
$shell = (Get-Process -Id $PID).Path
. (Join-Path $PSScriptRoot '../AudioFileForPhone.Helpers.ps1')

function Assert-Measurement([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Invoke-MeasurementTool([string]$Executable, [string[]]$Arguments, [int]$ExpectedExit = 0) {
    $result = Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -TimeoutMilliseconds 120000
    Assert-Measurement ($result.Status -ceq 'Completed' -and $result.ExitCode -eq $ExpectedExit -and
        $result.ProcessReleased -and $result.PipeDrainCompleted -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) (
        "Expected exit $ExpectedExit from $Executable, got $($result.Status) / $($result.ExitCode). $($result.Error) $($result.Stderr) $($result.Stdout)")
    return $result
}
function Invoke-MeasurementFfmpeg([string[]]$Arguments) {
    Invoke-MeasurementTool $FfmpegPath (@('-nostdin', '-hide_banner', '-v', 'error') + $Arguments)
}
function Get-MeasurementProbe([string]$Path) {
    (Invoke-MeasurementTool $FfprobePath @('-v', 'warning', '-show_streams', '-show_format', '-of', 'json', '-i', $Path)).Stdout | ConvertFrom-Json
}
function Get-MeasurementPcm([string]$Path, [switch]$Strict) {
    # These short fixtures have constant shape. Counting raw PCM bytes on disk
    # gives a reference independent of production's FFmpeg progress time parser.
    $probe = Get-MeasurementProbe $Path
    $audio = @($probe.streams | Where-Object codec_type -ceq 'audio')[0]
    $decodeArguments = @()
    if ($Strict) { $decodeArguments += @('-xerror', '-err_detect', 'explode') }
    $decode = Invoke-MeasurementFfmpeg ($decodeArguments + @('-i', $Path, '-map', '0:a:0', '-c:a', 'pcm_s16le', '-f', 's16le', $pcmPath))
    $bytes = (Get-Item -LiteralPath $pcmPath).Length
    [IO.File]::Delete($pcmPath)
    $samples = $bytes / (2 * [int]$audio.channels)
    Assert-Measurement ($samples -gt 0 -and $samples -eq [math]::Floor($samples)) 'Expected nonempty, complete PCM samples.'
    return [pscustomobject]@{ Seconds = $samples / [int]$audio.sample_rate; Stderr = $decode.Stderr; Audio = $audio; Tags = $probe.format.tags }
}
function Get-MeasurementHashes([string]$Directory) {
    Get-ChildItem -LiteralPath $Directory -File | Sort-Object Name |
        ForEach-Object { Get-FileHash -LiteralPath $_.FullName } | ConvertTo-Json -Compress
}
function Invoke-MeasurementApp([string]$InputDirectory, [string]$Destination, [int]$ExpectedExit) {
    $before = Get-MeasurementHashes $InputDirectory
    $result = Invoke-MeasurementTool $shell @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
        '-File', $ApplicationPath, '-InputFolder', $InputDirectory, '-OutputParent', $Destination,
        '-FfmpegDirectory', $toolDirectory, '-ConfigPath', (Join-Path $root 'unused.json')) $ExpectedExit
    Assert-Measurement ($before -ceq (Get-MeasurementHashes $InputDirectory)) 'The application modified source files.'
    $files = @(Get-ChildItem -LiteralPath $Destination -Recurse -Force)
    $manifests = @($files | Where-Object Name -ceq 'AudioFileForPhone_manifest.json')
    Assert-Measurement ($manifests.Count -eq 1 -and @($files | Where-Object {
        $_.Extension -ceq '.partial' -or $_.Name -like '.AudioFileForPhone-recovery-*'
    }).Count -eq 0) 'Expected one manifest and no abandoned working files.'
    $data = Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Measurement (@($files | Where-Object Extension -ceq '.mp3').Count -eq $data.totals.converted) 'Published outputs differ from converted count.'
    return [pscustomobject]@{ Manifest = $data; Console = $result.Stdout + $result.Stderr }
}

$token = [guid]::NewGuid().ToString('N')
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$root = Join-Path $temp ('AFP-Duration-' + $token.Substring(0, 8))
$marker = Join-Path $root '.owner'
$pcmPath = Join-Path $root 'reference.s16le'
Assert-Measurement ($toolDirectory -ieq [IO.Path]::GetDirectoryName($FfprobePath)) 'Use ffmpeg and ffprobe from the same directory.'
Assert-AudioNoReparseAncestor -Path $temp
Initialize-AudioDirectoryInterop
Assert-Measurement ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($root, [IntPtr]::Zero)) 'Could not reserve a fresh TEMP directory.'
$owner = [IO.File]::Open($marker, [IO.FileMode]::CreateNew)
try {
    $bytes = [Text.Encoding]::ASCII.GetBytes($token)
    $owner.Write($bytes, 0, $bytes.Length)
} finally { $owner.Dispose() }

try {
    $source = [IO.Directory]::CreateDirectory((Join-Path $root 'source')).FullName
    $vbr = Join-Path $source '01 - Estimated VBR.mp3'
    $null = Invoke-MeasurementFfmpeg @('-f', 'lavfi', '-i', 'anullsrc=r=22050:cl=mono:d=2',
        '-f', 'lavfi', '-i', 'anoisesrc=r=22050:a=0.5:d=6:seed=12345', '-filter_complex', '[0:a][1:a]concat=n=2:v=0:a=1[a]',
        '-map', '[a]', '-c:a', 'libmp3lame', '-q:a', '2', '-write_xing', '0', '-metadata', 'title=Measured VBR', $vbr)
    $cbr = Join-Path $root 'cbr.mp3'
    $null = Invoke-MeasurementFfmpeg @('-f', 'lavfi', '-i', 'sine=frequency=733:sample_rate=44100:d=6',
        '-ac', '2', '-c:a', 'libmp3lame', '-b:a', '64k', '-write_xing', '0', '-id3v2_version', '0', $cbr)
    $cbrBytes = [IO.File]::ReadAllBytes($cbr)
    $withJunk = Join-Path $source '02 - CBR with leading junk.mp3'
    [IO.File]::WriteAllBytes($withJunk, [byte[]]((New-Object byte[] 24576) + $cbrBytes))
    $damaged = Join-Path $source '03 - Recoverable decoder warning.mp3'
    $packets = (Invoke-MeasurementTool $FfprobePath @('-v', 'error', '-select_streams', 'a:0',
        '-show_packets', '-show_entries', 'packet=pos,size', '-of', 'json', '-i', $cbr)).Stdout | ConvertFrom-Json
    $frameStart = [int]$packets.packets[50].pos
    $frameEnd = $frameStart + [int]$packets.packets[50].size
    for ($i = $frameStart + 4; $i -lt $frameEnd; $i++) { $cbrBytes[$i] = 255 }
    [IO.File]::WriteAllBytes($damaged, $cbrBytes)
    $next = Join-Path $source '04 - Ordinary AAC.m4b'
    $null = Invoke-MeasurementFfmpeg @('-f', 'lavfi', '-i', 'sine=frequency=521:sample_rate=44100:d=1.7', '-c:a', 'aac', '-f', 'ipod', $next)
    $references = @{}
    foreach ($file in Get-ChildItem -LiteralPath $source -File) {
        $references[$file.Name] = Get-MeasurementPcm $file.FullName
    }
    $expectedVbr = $references[[IO.Path]::GetFileName($vbr)]
    $estimated = [double]::Parse($expectedVbr.Audio.duration, [Globalization.CultureInfo]::InvariantCulture)
    Assert-Measurement ([math]::Abs($estimated - $expectedVbr.Seconds) -gt 0.35 -and -not $expectedVbr.Stderr) 'VBR fixture did not exercise a wrong estimate on otherwise readable audio.'
    Assert-Measurement ($references[[IO.Path]::GetFileName($damaged)].Stderr -match 'decod') 'Frame corruption failed to produce recoverable decoder diagnostics.'

    $run = Invoke-MeasurementApp $source (Join-Path $root 'converted') 0
    $data = $run.Manifest
    Assert-Measurement ($data.totals.converted -eq 4 -and $data.totals.failed -eq 0 -and
        $data.totals.converted_with_source_warnings -eq 1 -and $run.Console -match 'converted with source' -and
        $run.Console -match 'duration was estimated') (
        'Wrong successful batch counts or missing visible source warning. ' + ($data.totals | ConvertTo-Json -Compress))
    foreach ($row in $data.records) {
        $sourceName = [IO.Path]::GetFileName($row.source_relative_path)
        $expected = $references[$sourceName]
        $output = Get-MeasurementPcm (Join-Path $data.run.output_root $row.output_relative_path) -Strict
        Assert-Measurement ($row.status -ceq 'Converted' -and $row.source_measurement_method -and
            [math]::Abs($row.input_duration_seconds - $expected.Seconds) -lt 0.00001 -and
            [math]::Abs($row.decoded_duration_seconds - $output.Seconds) -lt 0.00001 -and
            [math]::Abs($row.duration_difference_seconds - [math]::Abs($row.input_duration_seconds - $row.decoded_duration_seconds)) -lt 0.00001 -and
            $row.duration_tolerance_seconds -eq 0.35 -and [math]::Abs($expected.Seconds - $output.Seconds) -le 0.35 -and
            -not $output.Stderr -and $output.Audio.codec_name -ceq 'mp3' -and [int]$output.Audio.bit_rate -eq 64000 -and
            $output.Audio.channels -eq $expected.Audio.channels -and $output.Audio.sample_rate -ceq $expected.Audio.sample_rate) (
            'Duration evidence or output audio shape mismatch for ' + $row.source_relative_path)
        Assert-Measurement ([bool]$row.source_warnings -eq ($sourceName -eq [IO.Path]::GetFileName($damaged))) 'Source damage must be identified separately from bitrate estimation.'
        if ($sourceName -eq [IO.Path]::GetFileName($vbr)) {
            Assert-Measurement ($row.source_duration_estimated -and [math]::Abs($row.source_reported_duration_seconds - $estimated) -lt 0.00001 -and
                $row.source_reported_duration_origin -ceq 'Stream' -and $output.Tags.title -ceq 'Measured VBR') 'Source estimate or preserved title missing.'
        }
    }

    $negative = [IO.Directory]::CreateDirectory((Join-Path $root 'negative')).FullName
    [IO.File]::WriteAllText((Join-Path $negative '01 - Unreadable.mp3'), 'No decodable audio.')
    [IO.File]::Copy($next, (Join-Path $negative '02 - Subsequent good.m4b'))
    $data = (Invoke-MeasurementApp $negative (Join-Path $root 'negative-out') 2).Manifest
    Assert-Measurement ($data.totals.failed -eq 1 -and $data.totals.converted -eq 1 -and
        $data.records[0].status -ceq 'Failed' -and $data.records[1].status -ceq 'Converted') 'Unreadable input must fail individually and the next file must convert.'
    Write-Host ([string]::Format([Globalization.CultureInfo]::InvariantCulture,
        'Measured duration regression passed. VBR reported {0:F6}s and decoded {1:F6}s. Four conversions, one warning, and one isolated failure in the negative batch.',
        $estimated, $expectedVbr.Seconds))
} finally {
    $resolved = (Resolve-Path -LiteralPath $root).ProviderPath
    Assert-Measurement ($resolved -ceq $root -and [IO.Path]::GetDirectoryName($resolved) -ceq $temp -and
        [IO.File]::ReadAllText($marker) -ceq $token) 'Refusing cleanup outside the marker-owned temporary directory.'
    Assert-AudioNoReparseAncestor -Path $resolved
    foreach ($item in Get-ChildItem -LiteralPath $resolved -Recurse -Force) {
        Assert-Measurement (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing to clean a reparse point.'
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
