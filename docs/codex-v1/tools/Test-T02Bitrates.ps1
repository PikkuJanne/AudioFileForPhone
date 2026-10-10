<#
T02 empirical libmp3lame bitrate characterization, using generated audio only.
Runs on Windows PowerShell 5.1 and PowerShell 7; no production dependency changes.
#>
[CmdletBinding()]
param(
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe',
    [string]$EvidencePath,
    [switch]$Append
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $PSScriptRoot '../evidence/T02-bitrate-matrix.json' }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$requiredEvidencePath = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence/T02-bitrate-matrix.json'))
if ($evidenceFullPath -ine $requiredEvidencePath) { throw 'EvidencePath must be docs/codex-v1/evidence/T02-bitrate-matrix.json.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T02-Bitrate-' + [guid]::NewGuid().ToString('N')
$testRoot = [IO.Path]::GetFullPath((Join-Path $tempParent $testName))
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.t02-bitrate-owner'
$evidenceWriteApproved = $false
$rates = @(8,16,24,32,40,48,56,64,80,96,112,128,144,160,192,224,256,320)
$invalidRates = @(0,-1,7,65,145,321)
$profiles = @(
    [pscustomobject]@{ name = 'mono48000'; channels = 1; sample_rate = 48000 },
    [pscustomobject]@{ name = 'stereo44100'; channels = 2; sample_rate = 44100 },
    [pscustomobject]@{ name = 'mono22050'; channels = 1; sample_rate = 22050 },
    [pscustomobject]@{ name = 'stereo22050'; channels = 2; sample_rate = 22050 }
)
$windows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1
    task = 'T02'
    purpose = 'empirical_requested_bitrate_profile_characterization'
    started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString()
    shell_edition = $PSVersionTable.PSEdition
    windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    application_sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
    helper_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    accepted_rate_candidates_kbps = $rates
    invalid_rate_probes_kbps = $invalidRates
    profiles = $profiles
    fixture_duration_seconds = 0.6
    commands = [ordered]@{
        generate = 'ffmpeg -v error -nostdin -f lavfi -i sine=frequency=440:sample_rate=<profile.sample_rate>:duration=0.6 -ac <profile.channels> -c:a pcm_s16le <owned-temp>/<profile.name>.wav'
        encode = 'ffmpeg -v error -nostdin -y -i <generated-input.wav> -map 0:a:0 -vn -acodec libmp3lame -b:a <requested-kbps>k -id3v2_version 3 <owned-temp>/<profile>-<requested>.mp3'
        probe = 'ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels,bit_rate,duration -of json <generated-output.mp3>'
    }
    ffmpeg = $null
    ffprobe = $null
    rows = @()
    source_before = @()
    source_after = @()
    source_unchanged = $false
    cleanup_verified = $false
    isolation = [ordered]@{ unique_owned_temp_root = $true; marker_checked = $false; reparse_points_refused = $true; ordinary_music_access = $false }
    status = 'fail'
    error = $null
}

function Assert-NoReparseAncestors {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse point in test path is unsupported.' }
        $item = $item.Parent
    }
}

function Invoke-Native {
    param([string]$Executable, [string[]]$Arguments)
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $nativeOutput = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_" })
        $nativeCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $savedPreference }
    return [pscustomobject]@{ code = $nativeCode; output = $nativeOutput }
}

function Get-FixtureInventory {
    return @($profiles | ForEach-Object {
        $fixture = Get-Item -LiteralPath (Join-Path $testRoot ($_.name + '.wav'))
        [pscustomobject]@{
            relative_path = $fixture.Name
            length = $fixture.Length
            sha256 = (Get-FileHash -LiteralPath $fixture.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

function Remove-OwnedTestRoot {
    if ([IO.Path]::GetFullPath($testRoot) -ine (Join-Path $tempParent $testName) -or
        (Split-Path -Parent $testRoot) -ine $tempParent -or
        $testName -notmatch '^AudioFileForPhone-T02-Bitrate-[a-f0-9]{32}$') { throw 'Owned cleanup path does not match the unique TEMP child.' }
    if (-not (Test-Path -LiteralPath $testRoot -PathType Container)) { return }
    Assert-NoReparseAncestors $testRoot
    if (-not (Test-Path -LiteralPath $ownerFile -PathType Leaf) -or [IO.File]::ReadAllText($ownerFile) -cne $ownerToken) { throw 'Cleanup ownership marker is missing or changed.' }
    $report.isolation.marker_checked = $true
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($testRoot)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($child in Get-ChildItem -LiteralPath $directory -Force) {
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing cleanup containing a reparse point.' }
            if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
    $report.cleanup_verified = -not (Test-Path -LiteralPath $testRoot)
}

try {
    Assert-NoReparseAncestors $tempParent
    Assert-NoReparseAncestors (Split-Path -Parent $evidenceFullPath)
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparseAncestors $evidenceFullPath }
    $evidenceWriteApproved = $true
    foreach ($toolPath in @($FfmpegPath, $FfprobePath)) {
        if (-not [IO.Path]::IsPathRooted($toolPath) -or -not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw 'An absolute installed native tool path is required.' }
    }
    foreach ($toolName in @('ffmpeg','ffprobe')) {
        $toolPath = if ($toolName -eq 'ffmpeg') { $FfmpegPath } else { $FfprobePath }
        $versionResult = Invoke-Native $toolPath @('-version')
        if ($versionResult.code -ne 0) { throw 'Native tool version failed.' }
        $report[$toolName] = [ordered]@{
            path = [IO.Path]::GetFullPath($toolPath)
            sha256 = (Get-FileHash -LiteralPath $toolPath -Algorithm SHA256).Hash.ToLowerInvariant()
            version = $versionResult.output[0]
        }
    }
    if (Test-Path -LiteralPath $testRoot) { throw 'Unique TEMP path unexpectedly exists.' }
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    [IO.File]::WriteAllText($ownerFile, $ownerToken)
    foreach ($profile in $profiles) {
        $inputPath = Join-Path $testRoot ($profile.name + '.wav')
        $generated = Invoke-Native $FfmpegPath @('-v','error','-nostdin','-f','lavfi','-i',('sine=frequency=440:sample_rate={0}:duration=0.6' -f $profile.sample_rate),'-ac',"$($profile.channels)",'-c:a','pcm_s16le',$inputPath)
        if ($generated.code -ne 0) { throw ('Generated fixture failed for ' + $profile.name) }
    }
    $report.source_before = Get-FixtureInventory
    foreach ($profile in $profiles) {
        foreach ($requested in @($rates + $invalidRates)) {
            $inputPath = Join-Path $testRoot ($profile.name + '.wav')
            $outputPath = Join-Path $testRoot ('{0}-{1}.mp3' -f $profile.name, $requested)
            $encoded = Invoke-Native $FfmpegPath @('-v','error','-nostdin','-y','-i',$inputPath,'-map','0:a:0','-vn','-acodec','libmp3lame','-b:a',('{0}k' -f $requested),'-id3v2_version','3',$outputPath)
            $row = [ordered]@{
                profile = $profile.name
                requested_kbps = $requested
                candidate_whitelist_member = $rates -contains $requested
                native_exit_code = $encoded.code
                output_exists = Test-Path -LiteralPath $outputPath -PathType Leaf
                actual_audio_kbps = $null
                output_sample_rate = $null
                output_channels = $null
                output_codec = $null
                requested_equals_actual = $false
                encoder_changed_sample_rate = $null
                observation = 'native_failure'
                error = $null
            }
            if ($encoded.code -eq 0 -and $row.output_exists) {
                $probe = Invoke-Native $FfprobePath @('-v','error','-select_streams','a:0','-show_entries','stream=codec_name,sample_rate,channels,bit_rate,duration','-of','json',$outputPath)
                if ($probe.code -ne 0) { throw 'Successful encode could not be probed.' }
                $stream = @(($probe.output -join "`n" | ConvertFrom-Json).streams)[0]
                $row.actual_audio_kbps = [double]$stream.bit_rate / 1000
                $row.output_sample_rate = [int]$stream.sample_rate
                $row.output_channels = [int]$stream.channels
                $row.output_codec = $stream.codec_name
                $row.requested_equals_actual = $row.actual_audio_kbps -eq $requested
                $row.encoder_changed_sample_rate = $row.output_sample_rate -ne $profile.sample_rate
                $row.observation = if ($row.requested_equals_actual) { 'exact_requested_rate' } else { 'requested_rate_changed' }
            }
            else {
                $row.error = (($encoded.output -join "`n").Replace($testRoot, '<owned-temp>'))
            }
            $report.rows += [pscustomobject]$row
        }
    }
    $report.source_after = Get-FixtureInventory
    $report.source_unchanged = ($report.source_before | ConvertTo-Json -Depth 5 -Compress) -ceq ($report.source_after | ConvertTo-Json -Depth 5 -Compress)
    if (-not $report.source_unchanged) { throw 'Generated input fixtures changed during encoding.' }
    $report.status = 'pass'
}
catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<owned-temp>')
    $report.status = 'fail'
}
finally {
    try { Remove-OwnedTestRoot }
    catch { $report.error = 'Cleanup refused: ' + $_.Exception.Message; $report.status = 'fail' }
    if (-not $report.cleanup_verified) { $report.status = 'fail' }
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    if ($evidenceWriteApproved) {
        Assert-NoReparseAncestors (Split-Path -Parent $evidenceFullPath)
        if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparseAncestors $evidenceFullPath }
        $runs = @()
        if ($Append -and (Test-Path -LiteralPath $evidenceFullPath -PathType Leaf)) {
            $previousEvidence = [IO.File]::ReadAllText($evidenceFullPath) | ConvertFrom-Json
            if ($previousEvidence.task -ne 'T02' -or $previousEvidence.purpose -ne $report.purpose) { throw 'Append requires previous T02 bitrate evidence.' }
            $runs = @($previousEvidence.runs)
        }
        $evidence = [ordered]@{ schema_version = 1; task = 'T02'; purpose = $report.purpose; runs = @($runs + @($report)) }
        [IO.File]::WriteAllText($evidenceFullPath, ($evidence | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    }
}
Write-Output ('Bitrate characterization: {0}; rows={1}; source unchanged={2}; cleanup verified={3}' -f $report.status,$report.rows.Count,$report.source_unchanged,$report.cleanup_verified)
if ($report.status -ne 'pass') { throw $report.error }
