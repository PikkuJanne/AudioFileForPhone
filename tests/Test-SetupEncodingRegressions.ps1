<#
Retained S02 regression leads after the S09 output audio plan correction.
Real tools and unchanged app copies; all media/config/output is synthetic and owned.
Independent unplanned encoder calls retain the original clamping reproduction;
the application must publish exact-rate output using the explicit tested plan.
Historical setup observations retain their original context and report contract.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][string]$FfmpegPath,
    [Parameter(Mandatory = $true)][string]$FfprobePath
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$shellName = if ($edition -eq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$activeParent = Join-Path $projectRoot 'docs/codex-v1.0.1/evidence'
$legacyParent = Join-Path $projectRoot 'docs/codex-v1/evidence'
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq $activeParent -and $leaf -cmatch "^S02-regressions-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq $legacyParent -and $leaf -cmatch "^T17-setupencoding-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S02-regressions-<edition>-attemptN/finalN active report or T17-setupencoding CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).ProviderPath.TrimEnd('\', '/')
$testName = 'AFP-S02-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s02-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$created = $false
$script:allChildrenExited = $true
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat', 'tests/Test-SetupEncodingRegressions.ps1')
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S02' })
    mode = 'real_windows_s09_retained_encoding_regressions'; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; physical_manual_evidence = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    parent_path_unchanged = $false; persistent_environment_writes = $false
    copied_bytes_unchanged = $false; cleanup_verified = $false; tools = @(); cases = @(); pending_contracts = @()
    status = 'fail'; error = $null
}
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse ancestor refused.'
        $item = $item.Parent
    }
}
function Assert-NoReparseTree {
    param([string]$Path)
    Assert-NoReparse $Path
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
    })
}
function Get-Literal {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CRT quoting, including trailing backslashes and embedded quotes.
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Invoke-OwnedProcess {
    param([string]$Executable, [string[]]$Arguments, [AllowNull()][string]$ChildPath, [switch]$SetChildPath)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.WorkingDirectory = $testRoot
    $info.UseShellExecute = $false
    # Inherit the established console/UTF-8 page; never create a CP437 console.
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    foreach ($key in @($info.EnvironmentVariables.Keys)) {
        if ([string]$key -ieq 'PSModulePath') { $info.EnvironmentVariables.Remove($key) }
    }
    if ($SetChildPath) { $info.EnvironmentVariables['PATH'] = $ChildPath }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        Assert-True $process.Start() 'Owned process failed to start.'
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(90000)) {
            $script:allChildrenExited = $false
            # Only this retained process; descendant release is unknown, so retain TEMP.
            $process.Kill(); $process.WaitForExit(10000) | Out-Null
            throw 'Owned process timed out; fixture cleanup withheld because descendant release is unproved.'
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 10000)) {
            $script:allChildrenExited = $false
            throw 'Owned redirected pipes did not close; fixture cleanup withheld because descendant release is unproved.'
        }
        return [pscustomobject]@{ exit_code = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result }
    } finally { $process.Dispose() }
}
function Invoke-Tool {
    param([string]$Executable, [string[]]$Arguments)
    $result = Invoke-OwnedProcess $Executable $Arguments
    Assert-True ($result.exit_code -eq 0) ('Synthetic tool operation failed: ' + $result.stderr)
    return $result.stdout
}
function Read-Audio {
    param([string]$Path)
    $media = (Invoke-Tool $ffprobe @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $Path)) | ConvertFrom-Json
    $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
    Assert-True ($audio.Count -eq 1) 'Expected exactly one independently probed audio stream.'
    return $audio[0]
}
function Invoke-App {
    param([string]$Id, [string]$InputPath, [AllowEmptyString()][string]$PathValue, [int]$Rate = 64, [switch]$DefaultRate)
    $caseRoot = Join-Path $testRoot $Id
    New-Item -ItemType Directory -Path $caseRoot | Out-Null
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
        $copy = Join-Path $caseRoot $name
        Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Application copy bytes changed.'
    }
    $outputParent = Join-Path $caseRoot 'Outputs [literal]'
    $wrapper = Join-Path $caseRoot 'child.ps1'
    $loader = Join-Path $caseRoot 'environment-loader.ps1'
    # Preserve byte-identical production files while making missing-tool
    # scenarios independent of the desktop's saved/inherited FFMPEG hints.
    $loaderCode = @'
. $global:S02OriginalEnvironmentHelper
function Get-AudioEnvironmentSetting {
    param([string]$Name, [string]$Target = 'Process')
    if($Name -ieq 'Path' -and $Target -eq 'Process'){return $env:PATH}
    return $null
}
'@
    Write-NewText $loader $loaderCode
    $lines = @(
        '[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)',
        '$ProgressPreference = ''SilentlyContinue''',
        ('$global:S02EnvironmentLoader=' + (Get-Literal $loader)),
        @'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($ChildPath -ceq 'AudioFileForPhone.Helpers.ps1' -and [IO.File]::Exists($actual)) {
        $global:S02OriginalEnvironmentHelper=$actual
        return $global:S02EnvironmentLoader
    }
    return $actual
}
'@,
        '$found = @(''ffmpeg.exe'', ''ffprobe.exe'' | ForEach-Object { [bool](Get-Command $_ -CommandType Application -ErrorAction SilentlyContinue) })',
        'Write-Host (''[S02_DISCOVERY] '' + ($found | ConvertTo-Json -Compress))',
        ('& ' + (Get-Literal (Join-Path $caseRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $InputPath) + ' -OutputParent ' + (Get-Literal $outputParent) + ' -ConfigPath ' + (Get-Literal (Join-Path $caseRoot 'missing-config.json')) + $(if ($DefaultRate) { '' } else { ' -BitrateKbps ' + $Rate })),
        'exit $LASTEXITCODE'
    )
    Write-NewText $wrapper ($lines -join [Environment]::NewLine)
    $result = Invoke-OwnedProcess $shell @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', $wrapper) -ChildPath $PathValue -SetChildPath
    Write-NewText (Join-Path $caseRoot 'stdout.log') $result.stdout
    Write-NewText (Join-Path $caseRoot 'stderr.log') $result.stderr
    $discovery = [regex]::Match($result.stdout, '(?m)^\[S02_DISCOVERY\] (.+)\r?$')
    Assert-True $discovery.Success 'No controlled child discovery evidence.'
    # PS5.1 emits a JSON root array as one pipeline object; assign before @().
    $discoveredCommands = $discovery.Groups[1].Value.Trim() | ConvertFrom-Json
    return [pscustomobject]@{
        exit_code = $result.exit_code; text = $result.stdout + $result.stderr; output_parent = $outputParent
        discovery = @($discoveredCommands)
    }
}
$exitCode = 1
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'Unique TEMP root already exists.'
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $created = $true
    Write-NewText $ownerFile $ownerToken
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
    $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    Assert-True ([IO.Path]::GetFileName($ffmpeg) -ieq 'ffmpeg.exe' -and [IO.Path]::GetFileName($ffprobe) -ieq 'ffprobe.exe') 'Select the actual FFmpeg/ffprobe executables.'
    foreach ($tool in @($ffmpeg, $ffprobe)) {
        Assert-NoReparse $tool
        $version = (Invoke-Tool $tool @('-version')).Split([char]10)[0].Trim()
        $report.tools += [pscustomobject]@{ name = [IO.Path]::GetFileName($tool); sha256 = (Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant(); version = $version }
    }
    $toolPath = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe)
    $inputs = @{}
    foreach ($rate in @(8000, 48000)) {
        foreach ($channels in @(1, 2)) {
            $key = "${rate}Hz-${channels}ch"
            $inputDir = Join-Path $testRoot $key
            New-Item -ItemType Directory -Path $inputDir | Out-Null
            $source = Join-Path $inputDir '2026-10-17 - Synthetic.m4a'
            Invoke-Tool $ffmpeg @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', "sine=frequency=440:sample_rate=${rate}:duration=0.75", '-ac', "$channels", '-c:a', 'alac', '-metadata', 'title=Synthetic', $source) | Out-Null
            $audio = Read-Audio $source
            Assert-True ([int]$audio.sample_rate -eq $rate -and [int]$audio.channels -eq $channels -and $audio.codec_name -ceq 'alac') 'Source generation did not preserve the intended rate/channels/codec.'
            $fixtures.Add($source); $inputs[$key] = $source
        }
    }
    # A ready-to-use proposed saved-state fixture, never placed in the user profile.
    $staleConfig = Join-Path $testRoot 'stale-config.json'
    $absentDirectory = Join-Path $testRoot 'removed-tools'
    Write-NewText $staleConfig (([ordered]@{ schema_version = 1; ffmpeg_directory = $absentDirectory }) | ConvertTo-Json)
    $fixtures.Add($staleConfig)
    $saved = Get-Content -LiteralPath $staleConfig -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($saved.schema_version -eq 1 -and -not (Test-Path -LiteralPath $saved.ffmpeg_directory)) 'Stale saved-state fixture must refer to an absent owned directory.'
    $report.pending_contracts += [pscustomobject]@{
        id = 'stale_saved_selection'; status = 'HISTORICAL_BASELINE_OBSERVATION'; fixture = 'stale-config.json'; fixture_validated = $true
        production_executed = $false; expected = 'Fresh noninteractive process rejects stale selection with repair guidance, without PATH fallback.'
        reason = 'The S02 baseline lacked saved config/config-location APIs. This retained fixture is historical context only; current resolver/setup acceptance is exercised by the dedicated S04/S05 suites.'
    }
    $report.pending_contracts += [pscustomobject]@{
        id = 'external_selected_directory'; status = 'HISTORICAL_BASELINE_OBSERVATION'; production_executed = $false
        expected = 'Actual explicit/saved production route uses external pair without PATH changes.'
        reason = 'The S02 baseline lacked FfmpegDirectory/saved-selection APIs. Current explicit/saved API acceptance remains in the dedicated S04/S05 suites; configured child PATH below retains its legacy baseline scope.'
    }
    $report.synthetic_before = Get-Inventory $fixtures.ToArray() $testRoot
    $emptySearch = Join-Path $testRoot 'Empty tool search'
    New-Item -ItemType Directory -Path $emptySearch | Out-Null
    foreach ($id in @('both_tools_missing', 'external_pair_outside_path')) {
        $searchPath = if ($id -eq 'both_tools_missing') { $emptySearch } else { '' }
        $child = Invoke-App $id (Split-Path -Parent $inputs['48000Hz-1ch']) $searchPath -DefaultRate
        Assert-True ($child.discovery.Count -eq 2 -and $child.discovery -notcontains $true) 'Sanitized no-profile child unexpectedly resolved a dependency.'
        Assert-True ($child.exit_code -eq 1 -and $child.text -match 'FFmpeg not found' -and $child.text -match 'converted=0' -and -not (Test-Path -LiteralPath $child.output_parent)) 'Expected missing-tool failure before output creation.'
        $report.cases += [pscustomobject]@{
            id = $id; status = 'pass'; classification = 'REPRODUCED_EXISTING_MISSING_TOOL_FAILURE'
            expected = 'Exit 1 before conversion, both commands unresolved, no output parent.'
            observed_exit = $child.exit_code; commands_found = $child.discovery; output_parent_created = $false
            external_pair_exists = $(if ($id -eq 'external_pair_outside_path') { (Test-Path -LiteralPath $ffmpeg -PathType Leaf) -and (Test-Path -LiteralPath $ffprobe -PathType Leaf) } else { $null })
            child_path = $(if ($id -eq 'both_tools_missing') { 'owned empty directory' } else { 'empty' }); profile_loaded = $false
        }
    }
    # Focused reported leads + default control at both source rates, mono/stereo.
    foreach ($rate in @(8000, 48000)) {
        $bitrates = if ($rate -eq 8000) { @(64, 192) } else { @(64, 8, 144) }
        foreach ($channels in @(1, 2)) {
            foreach ($bitrate in $bitrates) {
                $key = "${rate}Hz-${channels}ch"
                $source = $inputs[$key]
                $id = "${key}-${bitrate}kbps"
                $raw = Join-Path $testRoot ($id + '-encoder-comparison.mp3')
                Invoke-Tool $ffmpeg @('-nostdin', '-v', 'error', '-i', $source, '-map', '0:a:0', '-vn', '-c:a', 'libmp3lame', '-b:a', "${bitrate}k", $raw) | Out-Null
                $encoded = Read-Audio $raw
                Invoke-Tool $ffmpeg @('-nostdin', '-v', 'error', '-xerror', '-i', $raw, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
                $child = Invoke-App $id (Split-Path -Parent $source) $toolPath $bitrate -DefaultRate:($bitrate -eq 64)
                Assert-True ($child.discovery.Count -eq 2 -and $child.discovery -notcontains $false) 'Configured legacy child must resolve both tools.'
                $manifests = @(Get-ChildItem -LiteralPath $child.output_parent -Recurse -File | Where-Object { $_.Name -ceq 'AudioFileForPhone_manifest.json' })
                Assert-True ($manifests.Count -eq 1) 'Expected exactly one actual production manifest.'
                $manifest = Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $record = @($manifest.records)
                Assert-True ($record.Count -eq 1 -and [int]$manifest.totals.supported -eq 1 -and [int]$manifest.totals.processed -eq 1) 'Production must account for the single synthetic input.'
                Assert-True ([int]$manifest.run.exit_code -eq $child.exit_code) 'Manifest exit must agree with the actual process exit.'
                $outputs = @(Get-ChildItem -LiteralPath $child.output_parent -Recurse -File | Where-Object { $_.Extension -ieq '.mp3' })
                $partials = @(Get-ChildItem -LiteralPath $child.output_parent -Recurse -File | Where-Object { $_.Name -match '\.partial' })
                Assert-True ($partials.Count -eq 0) 'Production left incomplete working files.'
                $exact = [int]$encoded.bit_rate -eq $bitrate * 1000
                if ($bitrate -eq 64) { Assert-True $exact 'Normal default must encode at exactly 64 kbps.' }
                $expectedRate = if ($rate -eq 48000 -and $bitrate -in @(8, 144)) { 24000 }
                    elseif ($rate -eq 8000 -and $bitrate -eq 192) { 32000 }
                    else { $rate }
                Assert-True ($child.exit_code -eq 0 -and $outputs.Count -eq 1 -and $record[0].status -ceq 'Converted' -and [int]$manifest.totals.converted -eq 1 -and [int]$manifest.totals.failed -eq 0) 'Planned exact-rate conversion must succeed and publish one output; late bitrate rejection is no longer accepted.'
                $published = Read-Audio $outputs[0].FullName
                Assert-True ($published.codec_name -ceq 'mp3' -and [int]$published.bit_rate -eq $bitrate * 1000 -and [int]$published.channels -eq $channels -and [int]$published.sample_rate -eq $expectedRate) 'Published output bitrate/codec/channel/sample-rate must match the independently expected plan.'
                $audioPlan = $record[0].audio_plan
                Assert-True ($null -ne $audioPlan -and $audioPlan.status -ceq 'Success' -and $audioPlan.code -ceq 'Compatible' -and -not [string]::IsNullOrWhiteSpace([string]$audioPlan.reason)) 'Manifest must retain the actual compatible audio plan and explanation.'
                Assert-True ($audioPlan.source_codec -ceq 'alac' -and [int]$audioPlan.source_sample_rate -eq $rate -and [int]$audioPlan.source_channels -eq $channels -and [int]$audioPlan.bitrate_kbps -eq $bitrate -and [int]$audioPlan.output_sample_rate -eq $expectedRate -and [int]$audioPlan.output_channels -eq $channels -and $audioPlan.resample -eq ($expectedRate -ne $rate) -and $audioPlan.downmix -eq $false) 'Manifest source-to-output sample-rate/channel decision must match the independent expectation.'
                $expectedLayout = if ($channels -eq 1) { 'mono' } else { 'stereo' }
                Assert-True ($audioPlan.source_channel_layout -ceq $expectedLayout) 'Manifest must retain the independently known source channel layout.'
                $observedAudio = $record[0].observed_audio
                Assert-True ($null -ne $observedAudio -and [int]$observedAudio.bitrate_bps -eq $bitrate * 1000 -and [int]$observedAudio.sample_rate -eq $expectedRate -and [int]$observedAudio.channels -eq $channels) 'Manifest observed audio must match the independently probed published stream.'
                Invoke-Tool $ffmpeg @('-nostdin', '-v', 'error', '-xerror', '-i', $outputs[0].FullName, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
                $classification = if ($exact) { 'EXACT_RATE_SUCCESS' } else { 'REPRODUCED_RAW_CLAMP_FIXED_BY_PLAN' }
                $report.cases += [pscustomobject]@{
                    id = $id; status = 'pass'; classification = $classification
                    expected = 'Exact requested bitrate, preserved mono/stereo, explicit expected sample rate and full decode; no late rejection allowance.'
                    source_codec = 'alac'; source_rate_hz = $rate; source_channels = $channels; requested_kbps = $bitrate
                    default_parameter_omitted = ($bitrate -eq 64); encoder_comparison_bps = [int]$encoded.bit_rate
                    encoder_comparison_rate_hz = [int]$encoded.sample_rate; encoder_comparison_full_decode = $true
                    raw_encoder_clamped = (-not $exact); expected_output_rate_hz = $expectedRate
                    manifest_audio_plan = $audioPlan; manifest_observed_audio = $observedAudio
                    app_exit = $child.exit_code; app_code = $record[0].code; published_count = $outputs.Count
                    published_bps = $(if ($null -ne $published) { [int]$published.bit_rate } else { $null })
                    published_rate_hz = $(if ($null -ne $published) { [int]$published.sample_rate } else { $null })
                    published_full_decode = ($null -ne $published); partial_count = $partials.Count
                    dependency_route = 'legacy child-only PATH; not external-selection acceptance'
                }
            }
        }
    }
    $report.copied_bytes_unchanged = $true
    $report.status = 'pass'; $exitCode = 0
} catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>').Replace($env:USERPROFILE, '<USERPROFILE>')
} finally {
    $report.source_after = Get-Inventory $sourcePaths $projectRoot
    $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
    if ($fixtures.Count -gt 0) {
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
    }
    $report.parent_path_unchanged = $env:PATH -ceq $originalPath
    if (-not ($report.source_unchanged -and $report.synthetic_unchanged -and $report.parent_path_unchanged)) { $report.status = 'fail'; $exitCode = 1 }
    try {
        if ($created -and $script:allChildrenExited) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Exact owned TEMP cleanup boundary not proved.'
            Assert-NoReparseTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Owned cleanup not proved; retain fixture tree.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
Write-Host "Retained setup/encoding regressions: $($report.status); shell=$edition; cases=$($report.cases.Count); historical API observations=$($report.pending_contracts.Count); cleanup=$($report.cleanup_verified)"
if ($report.error) { Write-Host $report.error }
exit $exitCode
