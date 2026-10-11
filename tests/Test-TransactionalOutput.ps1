<#
T09 short real conversions and staged false-success/failure evidence.
All media, native diagnostics and independent sentinel children stay inside one
exclusively reserved TEMP tree. Evidence is create-new. Tests never visit Music.
Native-function substitution is confined to this test process; production has
no injection flags. Real probe, integrity decode and filesystem failures remain.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'T9-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t09-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$events = New-Object 'System.Collections.Generic.List[object]'
$savedAcls = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-TransactionalOutput.ps1')
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^T09-transaction-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw 'EvidencePath must name fresh T09-transaction-ps51/ps7-attempt/finalN.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'T09'; mode = 'transactional_output_real_and_faults'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    owned_temp_root_name = $testName; temp_parent_selection = 'shorter user/machine TEMP, read-only lookup'
    cases = @(); duration_matrix = @(); rejected_rate_matrix = @(); acls_restored = $false; children_disposed = $false
    cleanup_verified = $false; status = 'fail'; error = $null
}
$exitCode = 1
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point in a fixture path or ancestor.'
        $item = $item.Parent
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse points inside exact cleanup scope.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() } })
}
function Add-LateFixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function New-NativeResult {
    param([int]$Code = 0, [string]$Stdout = '', [string]$Stderr = '', [string]$Status = 'Completed', [bool]$Truncated = $false, [bool]$Released = $true)
    return [pscustomobject]@{ Status = $Status; ExitCode = $Code; Stdout = $Stdout; Stderr = $Stderr; Error = $Stderr; StdoutTruncated = $Truncated; StderrTruncated = $false; ElapsedMilliseconds = 0; ProcessReleased = $Released }
}
function Invoke-RealNative {
    param([string]$Tool, [string[]]$NativeArguments)
    return & $script:originalNative -ExecutablePath $Tool -Arguments $NativeArguments
}
function Invoke-RealSuccess {
    param([string]$Tool, [string[]]$NativeArguments)
    $native = Invoke-RealNative $Tool $NativeArguments
    Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 0) ('Real native fixture/check failed: ' + $native.Error + ' ' + $native.Stderr)
    return $native
}
function Get-RealProbe {
    param([string]$Path)
    $native = Invoke-RealSuccess $ffprobe @('-v', 'error', '-show_entries', 'stream=index,codec_type,codec_name,sample_rate,channels,bit_rate,duration:format=duration,bit_rate', '-of', 'json', '-i', $Path)
    return $native.Stdout | ConvertFrom-Json
}
function Assert-Decoded {
    param([string]$Path, [int]$Rate)
    $probe = Get-RealProbe $Path
    $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq ($Rate * 1000)) 'Published output must independently probe as one MP3 stream at selected audio bitrate.'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $Path, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
    return $probe
}
function New-Fixture {
    param([string]$Label, [string]$Extension, [double]$Duration, [int]$SampleRate, [string]$Codec)
    $path = Join-Path $inputRoot ($Label + '.' + $Extension)
    $durationText = $Duration.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
    $args = @('-nostdin', '-hide_banner', '-v', 'error', '-f', 'lavfi', '-i', ('sine=frequency=733:sample_rate=' + $SampleRate), '-t', $durationText, '-c:a', $Codec)
    if ($Codec -eq 'libmp3lame') { $args += @('-b:a', '64k', '-ar', [string]$SampleRate) }
    if ($Codec -eq 'aac') { $args += @('-b:a', '96k') }
    $args += @('-metadata', ('title=Transactional ' + $Label), $path)
    Invoke-RealSuccess $ffmpeg $args | Out-Null
    $fixtures.Add($path)
    return $path
}
function Invoke-Transaction {
    param([string]$Output, [string]$Source, [double]$Duration, [int]$Rate = 64, [bool]$Cover = $false)
    $args = @('-nostdin', '-hide_banner', '-v', 'error', '-i', $Source, '-map', '0:a:0', '-c:a', 'libmp3lame', '-b:a', ($Rate.ToString([Globalization.CultureInfo]::InvariantCulture) + 'k'), '-id3v2_version', '3')
    return Invoke-AudioOutputTransaction -SourcePath $Source -OutputRoot $outputRoot -OutputPath $Output -SourceDurationSeconds $Duration -BitrateKbps $Rate -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments $args -HasCover $Cover
}
function Assert-FailureCleanup {
    param([object]$Result, [string]$Output, [string]$StatusPattern = '.')
    Assert-True ($Result.Status -ne 'Success' -and $Result.Status -match $StatusPattern) ('Expected transaction failure; got ' + $Result.Status + ': ' + $Result.Error)
    Assert-True (-not (Test-Path -LiteralPath $Output)) 'Failure must not leave a final-looking MP3.'
    if (-not [string]::IsNullOrEmpty($Result.WorkingPath)) { Assert-True (-not (Test-Path -LiteralPath $Result.WorkingPath)) 'Failure must remove this exact owned working path.' }
    Assert-True ([string]::IsNullOrEmpty($Result.CleanupError)) 'Expected fault must not conceal a cleanup failure.'
}
function Reset-NativeMock {
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value $script:originalNative
    $script:faultMode = ''; $script:encodeCopy = ''; $script:probeJson = ''; $script:encoderCalls = 0; $script:capturedWorking = ''
}
function Set-NativeMock {
    param([string]$Mode, [string]$CopyPath = '', [string]$Json = '')
    $script:faultMode = $Mode; $script:encodeCopy = $CopyPath; $script:probeJson = $Json; $script:encoderCalls = 0; $script:capturedWorking = ''
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value {
        param([string]$ExecutablePath, [string[]]$Arguments)
        $encode = $ExecutablePath -ieq $ffmpeg -and @($Arguments | Where-Object { $_ -eq '-b:a' }).Count -gt 0
        if ($encode) {
            $script:encoderCalls++; $work = $Arguments[$Arguments.Count - 1]; $script:capturedWorking = $work
            Assert-True ([IO.Path]::GetFileName($work) -match '^\.AudioFileForPhone-[0-9a-f]{32}\.partial$') 'Encoder must receive a unique non-final working basename.'
            Assert-True (@($Arguments | Where-Object { $_ -eq '-y' }).Count -eq 1 -and $Arguments[$Arguments.Count - 3] -eq '-f' -and $Arguments[$Arguments.Count - 2] -eq 'mp3') 'Owned working overwrite and explicit MP3 muxer must be exact.'
            Assert-True (-not (Test-Path -LiteralPath $script:expectedFinal)) 'Final filename must remain absent during encoding.'
            Assert-True ((Get-Item -LiteralPath $work).Length -eq 0) 'Working path must be reserved empty before the encoder runs.'
            if ($script:encodeCopy) {
                $data = [IO.File]::ReadAllBytes($script:encodeCopy)
                $writer = New-Object IO.FileStream($work, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
                try { $writer.SetLength(0); $writer.Write($data, 0, $data.Length) } finally { $writer.Dispose() }
            }
            if ($script:faultMode -eq 'guard-delete') {
                $blocked = $false; try { [IO.File]::Delete($work) } catch { $blocked = $true }
                Assert-True $blocked 'Kept ownership handle must actually prevent another delete during encoding.'
                $script:guardDeleteBlocked = $true
            }
            if ($script:faultMode -eq 'encoder-nonzero') { return New-NativeResult 17 '' 'controlled encoder failure' }
            if ($script:faultMode -eq 'encoder-start') { return New-NativeResult 0 '' 'controlled startup failure' 'StartFailed' }
            if ($script:faultMode -eq 'encoder-unreleased') { return New-NativeResult 0 '' 'controlled exit ownership unknown' 'Completed' $false $false }
            return New-NativeResult
        }
        if ($ExecutablePath -ieq $ffprobe) {
            if ($script:faultMode -eq 'probe-nonzero') { return New-NativeResult 19 '' 'controlled probe failure' }
            if ($script:faultMode -eq 'probe-start') { return New-NativeResult 0 '' 'controlled probe startup failure' 'StartFailed' }
            if ($script:faultMode -eq 'probe-truncated') { return New-NativeResult 0 $script:probeJson '' 'Completed' $true }
            if ($script:faultMode -eq 'probe-json') { return New-NativeResult 0 $script:probeJson }
            if ($script:faultMode -eq 'probe-unreleased') { return New-NativeResult 0 '' 'controlled exit ownership unknown' 'Completed' $false $false }
        }
        if ($script:faultMode -eq 'decode-nonzero' -and $ExecutablePath -ieq $ffmpeg) { return New-NativeResult 23 '' 'controlled integrity decode failure' }
        if ($script:faultMode -eq 'decode-unreleased' -and $ExecutablePath -ieq $ffmpeg) { return New-NativeResult 0 '' 'controlled exit ownership unknown' 'Completed' $false $false }
        return Invoke-RealNative $ExecutablePath $Arguments
    }
}

try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-NoReparse $tempParent
    $ownedRootCreated = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $inputRoot = Join-Path $testRoot 'S'; $outputRoot = Join-Path $testRoot 'O'; $appRoot = Join-Path $testRoot 'A'
    foreach ($directory in @($inputRoot, $outputRoot, $appRoot)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $helpersCopy = Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'
    $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1') -Destination $helpersCopy
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Destination $scriptCopy
    Assert-True ((Get-FileHash -LiteralPath $helpersCopy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')).Hash) 'Copied runtime must be byte-identical.'
    Assert-True ((Get-FileHash -LiteralPath $scriptCopy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1')).Hash) 'Copied entry must be byte-identical.'
    . $helpersCopy
    $report.copied_bytes_unchanged = $true
    $script:originalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
    $script:originalPublish = (Get-Item -LiteralPath Function:Publish-AudioWorkingOutput).ScriptBlock
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools'] = @($ffmpeg, $ffprobe | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant(); version = (Invoke-RealSuccess $_ @('-version')).Stdout.Split([char]10)[0].Trim() } })
    $report.source_before = Get-SourceInventory
    $matrixInputs = @()
    foreach ($extension in @('mp3', 'm4a', 'ogg')) {
        $codec = switch ($extension) { 'mp3' { 'libmp3lame' }; 'm4a' { 'aac' }; 'ogg' { 'libvorbis' } }
        foreach ($duration in @(0.025, 0.2, 2.0)) {
            foreach ($sampleRate in @(8000, 11025, 16000, 22050, 44100, 48000)) {
                $label = ('m-' + $extension + '-' + $duration.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture) + '-' + $sampleRate)
                $path = New-Fixture $label $extension $duration $sampleRate $codec
                $matrixInputs += [pscustomobject]@{ path = $path; extension = $extension; generated_seconds = $duration; source_sample_rate = $sampleRate; bitrate = 64 }
            }
        }
        foreach ($rate in @(8, 320)) {
            $sampleRate = if ($rate -eq 8) { 8000 } else { 48000 }
            $path = New-Fixture ('edge-' + $extension + '-' + $rate) $extension 0.2 $sampleRate $codec
            $matrixInputs += [pscustomobject]@{ path = $path; extension = $extension; generated_seconds = 0.2; source_sample_rate = $sampleRate; bitrate = $rate }
        }
        $rejectedPath = New-Fixture ('unsupported-' + $extension + '-8') $extension 0.2 48000 $codec
        $matrixInputs += [pscustomobject]@{ path = $rejectedPath; extension = $extension; generated_seconds = 0.2; source_sample_rate = 48000; bitrate = 8; expected_rate_rejection = $true }
    }
    $opus = New-Fixture 'opus' 'ogg' 0.2 48000 'libopus'
    $matrixInputs += [pscustomobject]@{ path = $opus; extension = 'ogg-opus'; generated_seconds = 0.2; source_sample_rate = 48000; bitrate = 64 }
    $valid = New-Fixture 'valid' 'mp3' 2.0 44100 'libmp3lame'
    $wrongCodec = New-Fixture 'wrong-codec' 'm4a' 2.0 44100 'aac'
    $wrongRate = Join-Path $inputRoot 'wrong-rate.mp3'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-i', $valid, '-map', '0:a:0', '-c:a', 'libmp3lame', '-b:a', '32k', $wrongRate) | Out-Null; $fixtures.Add($wrongRate)
    $png = Join-Path $inputRoot 'picture.png'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'color=red:size=512x512', '-frames:v', '1', $png) | Out-Null; $fixtures.Add($png)
    $jpeg = Join-Path $inputRoot 'cover.jpg'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=1024x1024', '-frames:v', '1', '-c:v', 'mjpeg', '-q:v', '2', $jpeg) | Out-Null; $fixtures.Add($jpeg)
    $coverMismatch = Join-Path $inputRoot 'cover-rate.mp3'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-i', $wrongRate, '-i', $jpeg, '-map', '0:a:0', '-map', '1:v:0', '-c:a', 'copy', '-c:v', 'copy', '-disposition:v', 'attached_pic', $coverMismatch) | Out-Null; $fixtures.Add($coverMismatch)
    $good64 = Join-Path $inputRoot 'good64.mp3'
    Invoke-RealSuccess $ffmpeg @('-nostdin', '-v', 'error', '-i', $valid, '-map', '0:a:0', '-c:a', 'libmp3lame', '-b:a', '64k', $good64) | Out-Null; $fixtures.Add($good64)
    $corrupt = Join-Path $inputRoot 'corrupt.mp3'; Write-NewText $corrupt ('this is synthetic corrupt media' * 40); $fixtures.Add($corrupt)
    $truncated = Join-Path $inputRoot 'truncated.mp3'
    $bytes = [IO.File]::ReadAllBytes($good64); $short = New-Object byte[] ([int]($bytes.Length * 0.35)); [Array]::Copy($bytes, $short, $short.Length); [IO.File]::WriteAllBytes($truncated, $short); $fixtures.Add($truncated)
    $payloadCorrupt = Join-Path $inputRoot 'payload-corrupt.mp3'
    $damaged = [IO.File]::ReadAllBytes($good64)
    for ($offset = [int]($damaged.Length * 0.3); $offset -lt [int]($damaged.Length * 0.8); $offset++) { $damaged[$offset] = 0 }
    [IO.File]::WriteAllBytes($payloadCorrupt, $damaged); $fixtures.Add($payloadCorrupt)
    $unrelatedPartial = Join-Path $outputRoot ('.AudioFileForPhone-' + [guid]::NewGuid().ToString('N') + '.partial')
    Write-NewText $unrelatedPartial 'external synthetic working sentinel'; $fixtures.Add($unrelatedPartial)
    $preservedPartials = New-Object 'System.Collections.Generic.List[string]'; $preservedPartials.Add($unrelatedPartial)
    $report.synthetic_before = Get-FixtureInventory

    Invoke-Case 'empirical supported matrix fully decodes and unsupported selected rates fail safely' 'A24,A25' {
        param($case)
        foreach ($row in $matrixInputs) {
            $media = Get-AudioMediaInfo -Path $row.path -FfprobePath $ffprobe
            Assert-True ($media.Status -eq 'Success' -and $media.DurationSeconds -gt 0) 'Real supported source must have finite positive inspected duration.'
            $output = Join-Path $outputRoot ([IO.Path]::GetFileNameWithoutExtension($row.path) + '-r' + $row.bitrate + '.mp3')
            $result = Invoke-Transaction $output $row.path $media.DurationSeconds $row.bitrate
            if ($row.expected_rate_rejection) {
                Assert-FailureCleanup $result $output '^ValidationFailed$'
                Assert-True ($result.Error -match 'bitrate') 'Unsupported requested rate must fail specifically because the actual audio bitrate differs.'
                $probe = $result.ValidationResult.ProbeResult.Stdout | ConvertFrom-Json
                $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })[0]
                Assert-True ([int]$audio.bit_rate -ne ($row.bitrate * 1000)) 'Unsupported-rate case must actually observe encoder rounding.'
                $report.rejected_rate_matrix += [pscustomobject]@{ extension = $row.extension; source_sample_rate = $row.source_sample_rate; selected_bitrate_kbps = $row.bitrate; actual_audio_bitrate = [int]$audio.bit_rate; status = $result.Status; final_absent = $true; owned_partial_removed = $true }
                continue
            }
            Assert-True ($result.Status -eq 'Success') ('Real transaction failed: ' + $result.Status + ' ' + $result.Error)
            Assert-True (-not (Test-Path -LiteralPath $result.WorkingPath)) 'Successful promotion must consume the exact working file.'
            $probe = Assert-Decoded $output $row.bitrate
            $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })[0]
            $report.duration_matrix += [pscustomobject]@{
                extension = $row.extension; generated_seconds = $row.generated_seconds; source_sample_rate = $row.source_sample_rate; selected_bitrate_kbps = $row.bitrate
                source_duration_seconds = $media.DurationSeconds; output_duration_seconds = [double]::Parse([string]$audio.duration, [Globalization.CultureInfo]::InvariantCulture)
                absolute_probe_delta_seconds = [Math]::Abs($media.DurationSeconds - [double]::Parse([string]$audio.duration, [Globalization.CultureInfo]::InvariantCulture))
                decoded_duration_seconds = $result.ValidationResult.DecodedDurationSeconds
                source_decode_delta_seconds = [Math]::Abs($media.DurationSeconds - $result.ValidationResult.DecodedDurationSeconds)
                output_sample_rate = [int]$audio.sample_rate; full_decode = $true; status = $result.Status
            }
        }
        $case['successful_rows'] = $report.duration_matrix.Count; $case['unsupported_rate_rejections'] = $report.rejected_rate_matrix.Count; $case['generated_durations'] = @(0.025, 0.2, 2.0)
        $case['source_sample_rates'] = @(8000, 11025, 16000, 22050, 44100, 48000); $case['selected_bitrates'] = @(8, 64, 320)
        $case['mp3_m4a_vorbis_opus'] = $true; $case['all_final_outputs_fully_decoded'] = $true
        $case['maximum_probe_delta_seconds'] = ($report.duration_matrix | Measure-Object absolute_probe_delta_seconds -Maximum).Maximum
        $case['maximum_source_decode_delta_seconds'] = ($report.duration_matrix | Measure-Object source_decode_delta_seconds -Maximum).Maximum
    }
    foreach ($fault in @(
        @{ mode = 'empty'; source = ''; title = 'zero exit with empty owned output' },
        @{ mode = 'corrupt'; source = $corrupt; title = 'zero exit with corrupt output' },
        @{ mode = 'nonaudio'; source = $png; title = 'zero exit with non-audio image' },
        @{ mode = 'codec'; source = $wrongCodec; title = 'unexpected AAC codec disguised by partial extension' },
        @{ mode = 'rate'; source = $wrongRate; title = 'selected audio bitrate mismatch' },
        @{ mode = 'cover-rate'; source = $coverMismatch; title = 'audio bitrate mismatch despite artwork/container bitrate' },
        @{ mode = 'truncated'; source = $truncated; title = 'physically truncated MP3 retaining original Xing duration' },
        @{ mode = 'payload-corrupt'; source = $payloadCorrupt; title = 'corrupted payload after valid MP3 header' },
        @{ mode = 'too-long'; source = $good64; title = 'implausibly long output' },
        @{ mode = 'encoder-nonzero'; source = $good64; title = 'nonzero encoder after partial bytes' },
        @{ mode = 'encoder-start'; source = ''; title = 'encoder startup failure' },
        @{ mode = 'probe-nonzero'; source = $good64; title = 'nonzero validation probe' },
        @{ mode = 'probe-start'; source = $good64; title = 'validation probe startup failure' },
        @{ mode = 'decode-nonzero'; source = $good64; title = 'integrity decoder native failure' }
    )) {
        Invoke-Case $fault.title 'A25,A26' {
            param($case)
            $script:expectedFinal = Join-Path $outputRoot ('fault-' + $fault.mode + '.mp3')
            Set-NativeMock $fault.mode $fault.source
            try {
                $duration = if ($fault.mode -eq 'too-long') { 0.2 } else { (Get-RealProbe $good64).format.duration }
                $result = Invoke-Transaction $script:expectedFinal $valid ([double]::Parse([string]$duration, [Globalization.CultureInfo]::InvariantCulture)) 64 ($fault.mode -eq 'cover-rate')
                $expectedStatus = if ($fault.mode -match '^encoder-') { '^EncodeFailed$' } else { '^ValidationFailed$' }
                Assert-FailureCleanup $result $script:expectedFinal $expectedStatus
                Assert-True ($script:encoderCalls -eq 1) 'Each injected output must execute its encoder exactly once.'
                $case['transaction_status'] = $result.Status; $case['reason'] = $result.Error.Replace($testRoot, '<OWNED_TEMP>')
                $case['only_owned_working_removed'] = $true
                if ($fault.mode -eq 'cover-rate') {
                    $probe = Get-RealProbe $coverMismatch; $case['actual_audio_bitrate'] = [int]$probe.streams[0].bit_rate; $case['container_bitrate'] = [int]$probe.format.bit_rate
                    Assert-True ($probe.streams.Count -eq 2 -and [int]$probe.streams[0].bit_rate -eq 32000 -and [int]$probe.format.bit_rate -gt 64000 -and $result.Error -match 'bitrate') 'Valid JPEG artwork must inflate the container above64k while wrong32k audio is specifically rejected by bitrate.'
                }
            } finally { Reset-NativeMock }
        }
    }
    Invoke-Case 'malformed/missing/non-finite output duration and probe JSON rejected' 'A25,A26' {
        param($case)
        $template = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"mp3","bit_rate":"64000","sample_rate":"44100","channels":1,"duration":"2.037551"}],"format":{"format_name":"mp3","duration":"2.037551","bit_rate":"64000"}}'
        $payloads = @('', 'not-json', '[]', '{"streams":[]}', $template.Replace('"duration":"2.037551"', '"duration":"N/A"'), $template.Replace('"duration":"2.037551"', '"duration":"NaN"'), $template.Replace('"duration":"2.037551"', '"duration":"-1"'), $template.Replace(',"duration":"2.037551"', ''), $template.Replace('"codec_name":"mp3"', '"codec_name":"aac"'), $template.Replace('"bit_rate":"64000","sample_rate"', '"bit_rate":"32000","sample_rate"'))
        $statuses = @()
        for ($index = 0; $index -lt $payloads.Count; $index++) {
            $script:expectedFinal = Join-Path $outputRoot ('json-' + $index + '.mp3'); Set-NativeMock 'probe-json' $good64 $payloads[$index]
            try { $result = Invoke-Transaction $script:expectedFinal $valid 2.037551; Assert-FailureCleanup $result $script:expectedFinal '^ValidationFailed$'; $statuses += $result.Status }
            finally { Reset-NativeMock }
        }
        $script:expectedFinal = Join-Path $outputRoot 'json-limit.mp3'; Set-NativeMock 'probe-truncated' $good64 $template
        try { $result = Invoke-Transaction $script:expectedFinal $valid 2.037551; Assert-FailureCleanup $result $script:expectedFinal '^ValidationFailed$'; $statuses += $result.Status }
        finally { Reset-NativeMock }
        $case['payloads'] = $payloads.Count + 1; $case['statuses'] = $statuses
    }
    Invoke-Case 'missing/invalid source duration fails before encoding' 'A25,A26' {
        param($case)
        $statuses = @()
        foreach ($duration in @(0.0, -1.0, [double]::NaN, [double]::PositiveInfinity)) {
            $script:expectedFinal = Join-Path $outputRoot ('source-duration-' + $statuses.Count + '.mp3'); Set-NativeMock 'empty'
            try {
                $result = Invoke-Transaction $script:expectedFinal $valid $duration
                Assert-FailureCleanup $result $script:expectedFinal '^InvalidSourceDuration$'
                Assert-True ($script:encoderCalls -eq 0) 'Invalid source duration must be rejected before encoder invocation.'
                $statuses += $result.Status
            } finally { Reset-NativeMock }
        }
        $case['invalid_values'] = @('zero', 'negative', 'NaN', 'positive infinity'); $case['statuses'] = $statuses; $case['no_encoder_calls'] = $true
    }
    Invoke-Case 'source inspection distinguishes missing/invalid duration and declared format fallback' 'A25' {
        param($case)
        $rows = @(
            @{ json = '{"streams":[{"index":0,"codec_type":"audio"}],"format":{}}'; status = 'Missing'; origin = $null },
            @{ json = '{"streams":[{"index":0,"codec_type":"audio","duration":"-1"}],"format":{"duration":"2"}}'; status = 'Invalid'; origin = 'Stream' },
            @{ json = '{"streams":[{"index":0,"codec_type":"audio","duration":"NaN"}],"format":{"duration":"2"}}'; status = 'Invalid'; origin = 'Stream' },
            @{ json = '{"streams":[{"index":0,"codec_type":"audio","duration":"N/A"}],"format":{"duration":"2"}}'; status = 'Valid'; origin = 'Format' }
        )
        $observed = @()
        foreach ($row in $rows) {
            Set-NativeMock 'probe-json' '' $row.json
            try {
                $media = Get-AudioMediaInfo -Path $valid -FfprobePath $ffprobe
                Assert-True ($media.Status -eq 'Success' -and $media.DurationStatus -ceq $row.status -and $media.DurationOrigin -ceq $row.origin) 'Source duration policy must preserve explicit Missing/Invalid/Valid distinction and only documented fallback.'
                $observed += [pscustomobject]@{ status = $media.DurationStatus; origin = $media.DurationOrigin; seconds = $media.DurationSeconds }
            } finally { Reset-NativeMock }
        }
        $script:expectedFinal = Join-Path $outputRoot 'missing-source-null.mp3'; Set-NativeMock 'empty'
        try {
            $result = Invoke-AudioOutputTransaction -SourcePath $valid -OutputRoot $outputRoot -OutputPath $script:expectedFinal -SourceDurationSeconds $null -BitrateKbps 64 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments @()
            Assert-FailureCleanup $result $script:expectedFinal '^InvalidSourceDuration$'
            Assert-True ($script:encoderCalls -eq 0) 'An explicit null source duration must fail before encoding.'
        } finally { Reset-NativeMock }
        $case['source_duration_results'] = $observed; $case['explicit_null_transaction_status'] = $result.Status
    }
    Invoke-Case 'apparently valid probe cannot bless corrupt audio payload' 'A25,A26' {
        param($case)
        $json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"mp3","bit_rate":"64000","duration":"2.037551"}],"format":{"format_name":"mp3"}}'
        $script:expectedFinal = Join-Path $outputRoot 'forged-probe.mp3'; Set-NativeMock 'probe-json' $payloadCorrupt $json
        try {
            $result = Invoke-Transaction $script:expectedFinal $valid 2.037551
            Assert-FailureCleanup $result $script:expectedFinal '^ValidationFailed$'
            Assert-True ($result.ValidationResult.Status -eq 'DecodeFailed' -and $null -ne $result.ValidationResult.DecodeResult) 'A valid-looking probe over corrupt payload must reach and fail real integrity decode.'
            $case['validation_status'] = $result.ValidationResult.Status; $case['real_decode_exit'] = $result.ValidationResult.DecodeResult.ExitCode
        } finally { Reset-NativeMock }
    }
    Invoke-Case 'bounded duration policy rejects minute loss for multi-hour claimed source' 'A25' {
        param($case)
        $json = '{"streams":[{"index":0,"codec_type":"audio","codec_name":"mp3","bit_rate":"64000","sample_rate":"44100","channels":1,"duration":"7140"}],"format":{"format_name":"mp3","duration":"7140","bit_rate":"64000"}}'
        $script:expectedFinal = Join-Path $outputRoot 'long-duration-policy.mp3'; Set-NativeMock 'probe-json' $good64 $json
        try { $result = Invoke-Transaction $script:expectedFinal $valid 7200; Assert-FailureCleanup $result $script:expectedFinal '^ValidationFailed$'; $case['transaction_status'] = $result.Status; $case['source_claim_seconds'] = 7200; $case['output_claim_seconds'] = 7140 }
        finally { Reset-NativeMock }
    }
    Invoke-Case 'promotion exception and actual locked working file fail safely' 'A26' {
        param($case)
        $statuses = @(); $reasons = @()
        foreach ($mode in @('injected-rename', 'locked-working')) {
            $script:expectedFinal = Join-Path $outputRoot ($mode + '.mp3'); Set-NativeMock 'copy-valid' $good64
            $script:workingLock = $null
            if ($mode -eq 'injected-rename') {
                Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value { param([string]$WorkingPath, [string]$OutputPath); throw 'controlled rename/disk promotion failure' }
            } else {
                Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value {
                    param([string]$WorkingPath, [string]$OutputPath)
                    $stream = New-Object IO.FileStream($WorkingPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
                    try { & $script:originalPublish -WorkingPath $WorkingPath -OutputPath $OutputPath }
                    finally { $stream.Dispose() }
                }
            }
            try {
                $result = Invoke-Transaction $script:expectedFinal $valid 2.037551; Assert-FailureCleanup $result $script:expectedFinal '^PromotionFailed$'; $statuses += $result.Status
                $reasons += $result.Error.Replace($testRoot, '<OWNED_TEMP>')
                if ($mode -eq 'locked-working') { Assert-True ($result.Error -match 'used by another process|sharing violation|being used') 'Actual locked promotion must report the real sharing violation.' }
            }
            finally { Reset-NativeMock; Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value $script:originalPublish }
        }
        $case['statuses'] = $statuses; $case['reasons'] = $reasons; $case['real_FileShare_None_move_failure'] = $true; $case['owned_lock_disposed_before_cleanup'] = $true
    }
    Invoke-Case 'concurrent final sentinel created after encode survives no-overwrite promotion' 'A26' {
        param($case)
        $script:expectedFinal = Join-Path $outputRoot 'race-final.mp3'
        $eventPrefix = 'Local\AudioFileForPhone-T09-' + [guid]::NewGuid().ToString('N')
        $readyName = $eventPrefix + '-ready'; $releaseName = $eventPrefix + '-release'; $writtenName = $eventPrefix + '-written'
        foreach ($name in @($readyName, $releaseName, $writtenName)) {
            $created = $false; $handle = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $name, [ref]$created)
            Assert-True $created 'Sentinel events must be exclusive to this invocation.'; $events.Add($handle)
        }
        $ready = $events[$events.Count - 3]; $release = $events[$events.Count - 2]; $written = $events[$events.Count - 1]
        $literalOutput = "'" + $script:expectedFinal.Replace("'", "''") + "'"
        $childCode = @('$ErrorActionPreference=''Stop''',
            ('$r=[Threading.EventWaitHandle]::OpenExisting(''' + $readyName + ''')'),
            ('$g=[Threading.EventWaitHandle]::OpenExisting(''' + $releaseName + ''')'),
            ('$w=[Threading.EventWaitHandle]::OpenExisting(''' + $writtenName + ''')'),
            'try { $null=$r.Set(); if (-not $g.WaitOne(50000)) { throw ''Sentinel release timeout'' }',
            ('$s=New-Object IO.FileStream(' + $literalOutput + ',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)'),
            'try { $b=[Text.Encoding]::UTF8.GetBytes(''external concurrent final sentinel''); $s.Write($b,0,$b.Length) } finally { $s.Dispose() }',
            '$null=$w.Set(); exit 0 } catch { [Console]::Out.WriteLine($_.Exception.Message); exit 1 } finally { $r.Dispose(); $g.Dispose(); $w.Dispose() }') -join "`n"
        $shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
        $info = New-Object Diagnostics.ProcessStartInfo; $info.FileName = Join-Path $PSHOME $shellName
        $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -EncodedCommand ' + [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
        $info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
        $process = New-Object Diagnostics.Process; $process.StartInfo = $info; Assert-True ($process.Start()) 'Owned sentinel writer must start.'
        $child = [pscustomobject]@{ process = $process; stdout_task = $process.StandardOutput.ReadToEndAsync(); stderr_task = $process.StandardError.ReadToEndAsync() }; $children.Add($child)
        Assert-True ($ready.WaitOne(50000)) 'Independent sentinel child must signal ready.'
        Set-NativeMock 'copy-valid' $good64
        Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value {
            param([string]$WorkingPath, [string]$OutputPath)
            Assert-True (-not (Test-Path -LiteralPath $OutputPath)) 'Final must be absent until independent writer is released after validation.'
            $null = $release.Set(); Assert-True ($written.WaitOne(50000)) 'Independent writer must create final before promotion.'
            & $script:originalPublish -WorkingPath $WorkingPath -OutputPath $OutputPath
        }
        try {
            $result = Invoke-Transaction $script:expectedFinal $valid 2.037551
            Assert-True ($result.Status -eq 'PromotionFailed' -and -not (Test-Path -LiteralPath $result.WorkingPath)) 'Concurrent final must fail safely and remove only owned partial.'
            Assert-True ([IO.File]::ReadAllText($script:expectedFinal) -ceq 'external concurrent final sentinel') 'Concurrent final bytes must survive exactly.'
            Assert-True ($process.WaitForExit(50000) -and $process.ExitCode -eq 0) 'Sentinel writer must complete successfully.'
            $expectedBytes = [Text.Encoding]::UTF8.GetBytes('external concurrent final sentinel'); $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $expectedHash = ([BitConverter]::ToString($algorithm.ComputeHash($expectedBytes))).Replace('-', '').ToLowerInvariant() } finally { $algorithm.Dispose() }
            $actualHash = (Get-FileHash -LiteralPath $script:expectedFinal).Hash.ToLowerInvariant()
            Assert-True ($actualHash -ceq $expectedHash) 'Independent concurrent sentinel SHA256 must match original bytes.'
            $fixtures.Add($script:expectedFinal); $report.synthetic_before += [pscustomobject]@{ relative_path = $script:expectedFinal.Substring($testRoot.Length + 1); sha256 = $expectedHash }
            $case['sentinel_sha256'] = $actualHash; $case['transaction_status'] = $result.Status; $case['writer_process_exit'] = $process.ExitCode; $case['barrier_after_validation'] = $true
        } finally { Reset-NativeMock; Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value $script:originalPublish }
    }
    Invoke-Case 'ownership guard prevents actual working-path deletion during encoder' 'A24,A26' {
        param($case)
        $script:expectedFinal = Join-Path $outputRoot 'guard-success.mp3'; $script:guardDeleteBlocked = $false; Set-NativeMock 'guard-delete' $good64
        try {
            $result = Invoke-Transaction $script:expectedFinal $valid 2.037551
            Assert-True ($result.Status -eq 'Success' -and $script:guardDeleteBlocked -and -not (Test-Path -LiteralPath $result.WorkingPath)) 'Guard must prevent deletion while permitting valid encode/probe/decode and publication.'
            Assert-Decoded $script:expectedFinal 64 | Out-Null
            $case['real_delete_sharing_failure'] = $true; $case['transaction_status'] = $result.Status; $case['final_fully_decoded'] = $true
        } finally { Reset-NativeMock }
    }
    Invoke-Case 'changed working-file identity after guard release preserves replacement sentinel' 'A26' {
        param($case)
        $script:expectedFinal = Join-Path $outputRoot 'replaced-working.mp3'; Set-NativeMock 'copy-valid' $good64
        $script:displacedWorking = ''
        Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value {
            param([string]$WorkingPath, [string]$OutputPath)
            $script:displacedWorking = $WorkingPath + '.held'
            [IO.File]::Move($WorkingPath, $script:displacedWorking)
            Write-NewText $WorkingPath 'external replacement working sentinel'
            throw 'controlled writer replaced working path after guard release'
        }
        try {
            $result = Invoke-Transaction $script:expectedFinal $valid 2.037551
            Assert-True ($result.Status -eq 'PromotionFailed' -and $result.CleanupError -match 'ownership changed' -and -not (Test-Path -LiteralPath $script:expectedFinal)) 'Unproved current-path ownership must be explicitly reported without publishing.'
            Assert-True ([IO.File]::ReadAllText($result.WorkingPath) -ceq 'external replacement working sentinel') 'Replacement bytes must survive production cleanup.'
            $preservedPartials.Add($result.WorkingPath); Add-LateFixture $result.WorkingPath; Add-LateFixture $script:displacedWorking
            $case['replacement_sha256'] = (Get-FileHash -LiteralPath $result.WorkingPath).Hash.ToLowerInvariant(); $case['cleanup_error'] = $result.CleanupError
            $case['transaction_status'] = $result.Status; $case['replacement_preserved'] = $true
        } finally { Reset-NativeMock; Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value $script:originalPublish }
    }
    Invoke-Case 'unestablished native exit retains recognizable partial and explicit cleanup diagnostic' 'A26' {
        param($case)
        $observed = @()
        foreach ($mode in @('encoder-unreleased', 'probe-unreleased', 'decode-unreleased')) {
            $script:expectedFinal = Join-Path $outputRoot ($mode + '.mp3'); Set-NativeMock $mode $good64
            try {
                $result = Invoke-Transaction $script:expectedFinal $valid 2.037551
                $expectedStatus = if ($mode -eq 'encoder-unreleased') { 'EncodeFailed' } else { 'ValidationFailed' }
                Assert-True ($result.Status -eq $expectedStatus -and $result.CleanupError -match 'exit was not established' -and (Test-Path -LiteralPath $result.WorkingPath) -and -not (Test-Path -LiteralPath $script:expectedFinal)) 'Unknown native exit must preserve only incomplete working output and report why cleanup was skipped.'
                $preservedPartials.Add($result.WorkingPath); Add-LateFixture $result.WorkingPath
                $observed += [pscustomobject]@{ phase = $mode; transaction_status = $result.Status; partial_sha256 = (Get-FileHash -LiteralPath $result.WorkingPath).Hash.ToLowerInvariant(); cleanup_error = $result.CleanupError }
            } finally { Reset-NativeMock }
        }
        $case['stages'] = $observed; $case['process_result_fault_injection_only'] = $true; $case['no_live_native_child_created_by_stub'] = $true
    }
    Invoke-Case 'actual entry postpublication log failure reports published mapping and preserves valid output' 'A24,A26' {
        param($case)
        $entryInput = Join-Path $testRoot 'E'; $entryParent = Join-Path $testRoot 'P'
        foreach ($directory in @($entryInput, $entryParent)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
        $entrySource = Join-Path $entryInput '2024-01-02 Synthetic.mp3'; [IO.File]::Copy($valid, $entrySource, $false); Add-LateFixture $entrySource
        $literalScript = "'" + $scriptCopy.Replace("'", "''") + "'"; $literalInput = "'" + $entryInput.Replace("'", "''") + "'"; $literalParent = "'" + $entryParent.Replace("'", "''") + "'"
        $literalToolDirectory = "'" + (Split-Path -Parent $ffmpeg).Replace("'", "''") + "'"
        $driver = @('$ErrorActionPreference=''Stop''', '$ProgressPreference=''SilentlyContinue''',
            ('$env:PATH=' + $literalToolDirectory + '+'';''+$env:PATH'),
            'function global:Add-Content {',
            '  [CmdletBinding()] param([string]$LiteralPath,[Parameter(ValueFromPipeline=$true)][object]$Value)',
            '  process { if ([string]$Value -match ''\[OK\]'') { throw ''controlled postpublication log write failure'' }',
            '    Microsoft.PowerShell.Management\Add-Content -LiteralPath $LiteralPath -Value $Value -ErrorAction Stop }',
            '}',
            ('& ' + $literalScript + ' -InputFolder ' + $literalInput + ' -OutputParent ' + $literalParent),
            'exit $LASTEXITCODE') -join "`n"
        $shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
        $shellPath = Join-Path $PSHOME $shellName
        $driverPath = Join-Path $testRoot 'log-driver.ps1'; Write-NewText $driverPath $driver; Add-LateFixture $driverPath
        $native = Invoke-RealNative $shellPath @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', $driverPath)
        $case['child_exit'] = $native.ExitCode; $case['child_native_status'] = $native.Status; $case['child_process_released'] = $native.ProcessReleased
        Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 1 -and $native.ProcessReleased) 'Actual entry must exit1 and dispose its child after an injected postpublication log failure.'
        # Windows PowerShell may wrap a single error message at display width,
        # even across words/paths. Preserve its characters while joining wraps.
        $text = ($native.Stdout + "`n" + $native.Stderr).Replace("`r", '').Replace("`n", '')
        $case['diagnostic_published_phrase'] = ($text -match 'Validated output was published to')
        $case['diagnostic_log_failure_phrase'] = ($text -match 'controlled postpublication log write failure')
        if (-not $case.diagnostic_published_phrase -or -not $case.diagnostic_log_failure_phrase) {
            # Do not persist host CLIXML InformationRecord identity fields.
            $case['failed_child_diagnostic_excerpt'] = $text.Substring([Math]::Max(0, $text.Length - 1200)).Replace($testRoot, '<OWNED_TEMP>')
        }
        Assert-True ($text -match 'Validated output was published to' -and $text -match 'controlled postpublication log write failure') 'Actual entry must explicitly identify the successfully published mapping and subsequent diagnostic write failure.'
        $roots = @($native.Stdout -split '\r?\n' | ForEach-Object { if ($_ -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1].Trim() } })
        Assert-True ($roots.Count -eq 1 -and (Test-AudioPathWithin -Path $roots[0] -Parent $entryParent)) 'Real entry must report exactly one run inside the owned explicit parent.'
        $marker = [IO.File]::ReadAllText((Join-Path $roots[0] '.AudioFileForPhone-output.json')) | ConvertFrom-Json
        Assert-True ($marker.output_root -ceq $roots[0] -and $marker.cleanup_scope -ceq $roots[0] -and $marker.ownership_token -match '^[0-9a-f]{32}$') 'Actual entry reservation must self-match its exact owned path/token.'
        $published = @(Get-SafeTree $roots[0] | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
        Assert-True ($published.Count -eq 1 -and $text.Contains($published[0].FullName)) 'Failure diagnostic must identify the single output that actually remains published.'
        Assert-Decoded $published[0].FullName 64 | Out-Null
        Assert-True (@(Get-SafeTree $roots[0] | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.partial' }).Count -eq 0) 'Postpublication log failure must not leave an owned partial.'
        $case['child_exit'] = $native.ExitCode; $case['child_process_released'] = $native.ProcessReleased
        $case['published_output_fully_decoded'] = $true; $case['published_sha256'] = (Get-FileHash -LiteralPath $published[0].FullName).Hash.ToLowerInvariant()
        $case['published_mapping_reported'] = $true; $case['subsequent_log_failure_reported'] = $true
    }
    Invoke-Case 'unrelated existing partial preserved across every owned cleanup' 'A26' {
        param($case)
        Assert-True ([IO.File]::ReadAllText($unrelatedPartial) -ceq 'external synthetic working sentinel') 'Unrelated partial bytes must never be removed or rewritten.'
        $partialFiles = @(Get-ChildItem -LiteralPath $outputRoot -Force | Where-Object { $_.Name -like '*.partial' })
        Assert-True ($partialFiles.Count -eq $preservedPartials.Count -and @($partialFiles | Where-Object { -not $preservedPartials.Contains($_.FullName) }).Count -eq 0) 'Only exact deliberately preserved partials may remain; all ordinary failed transactions must clean their work.'
        $case['sentinel_sha256'] = (Get-FileHash -LiteralPath $unrelatedPartial).Hash.ToLowerInvariant(); $case['no_unexpected_partials'] = $true; $case['deliberately_preserved_partial_count'] = $preservedPartials.Count
    }
    $report.status = 'pass'; $exitCode = 0
}
catch { $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    if ($null -ne $script:originalNative) { Reset-NativeMock }
    if ($null -ne $script:originalPublish) { Set-Item -LiteralPath Function:script:Publish-AudioWorkingOutput -Value $script:originalPublish }
    $childrenStopped = $true
    foreach ($child in $children) {
        try {
            foreach ($handle in $events) { $null = $handle.Set() }
            Assert-True ($child.process.HasExited -or $child.process.WaitForExit(60000)) 'Owned child still active; preserve exact test tree.'
            $null = $child.stdout_task.GetAwaiter().GetResult(); $null = $child.stderr_task.GetAwaiter().GetResult(); $child.process.Dispose()
        } catch { $childrenStopped = $false; $report['child_cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    foreach ($handle in $events) { $handle.Dispose() }; $report.children_disposed = $childrenStopped
    $report.acls_restored = $true
    foreach ($inventory in @('source', 'synthetic')) {
        try {
            $after = if ($inventory -eq 'source') { Get-SourceInventory } else { Get-FixtureInventory }
            $report[$inventory + '_after'] = $after
            $same = (($report[$inventory + '_before'] | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress))
            $report[$inventory + '_unchanged'] = $same; Assert-True $same "$inventory SHA256 inventory must remain unchanged."
        } catch { $report.status = 'fail'; $exitCode = 1; $report[$inventory + '_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    try {
        if ($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must remain exactly inside the current exclusive TEMP root.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup needs the exact create-new owner token from this invocation.'
            Get-SafeTree $resolved | Out-Null; [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    if (-not $childrenStopped) { $report.status = 'fail'; $exitCode = 1 }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    $bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 16))
    $stream = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
Write-Host "T09 transaction: $($report.status); cases=$($report.cases.Count); matrix=$($report.duration_matrix.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
