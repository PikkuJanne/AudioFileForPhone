<#
T10 real child-process result evidence. Fixtures, instrumented helper copies and
raw diagnostics stay inside an exclusively reserved, marked TEMP tree. Production
entry bytes remain unchanged. No Music access, ACL changes or global child kills.
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
$testName = 'T10R-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t10-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-ScriptResults.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T10|T11|T12|T13|T14|T15|T16)-script-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw 'EvidencePath must name fresh T10/T11/T12/T13/T14/T15/T16-script-ps51/ps7-attempt/finalN.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'script_child_result_contract_real_and_faults'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_entry_bytes_unchanged = $false
    owned_temp_root_name = $testName; temp_parent_selection = 'shorter user/machine TEMP, read-only lookup'
    cases = @(); children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
}
$exitCode = 1
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = 'A27'; status = 'fail' }
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
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside exact cleanup scope.'
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
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-RealSuccess {
    param([string]$Tool, [string[]]$NativeArguments)
    $native = Invoke-AudioNativeProcess -ExecutablePath $Tool -Arguments $NativeArguments
    Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 0 -and $native.ProcessReleased) ('Real fixture/check failed: ' + $native.Error + ' ' + $native.Stderr)
    return $native
}
function New-Input {
    param([string]$Label, [string[]]$Names)
    $root = Join-Path $testRoot $Label; [IO.Directory]::CreateDirectory($root) | Out-Null
    foreach ($name in $Names) {
        $path = Join-Path $root $name; [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
        $extension = [IO.Path]::GetExtension($path).TrimStart('.')
        if ($name -match 'bad') { Write-NewText $path 'synthetic corrupt audio source for result contract' }
        else { [IO.File]::Copy((Join-Path $seedRoot ('good.' + $extension)), $path, $false) }
        Add-Fixture $path
    }
    return $root
}
function New-AppCopy {
    param([string]$Label, [string]$AppendHelpers = '')
    $root = Join-Path $testRoot ('A-' + $Label); [IO.Directory]::CreateDirectory($root) | Out-Null
    $entry = Join-Path $root 'AudioFileForPhone.ps1'; $copyHelper = Join-Path $root 'AudioFileForPhone.Helpers.ps1'
    [IO.File]::Copy((Join-Path $projectRoot 'AudioFileForPhone.ps1'), $entry, $false)
    [IO.File]::Copy((Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'), $copyHelper, $false)
    Assert-True ((Get-FileHash -LiteralPath $entry).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1')).Hash) 'Every copied entry must retain production bytes.'
    Assert-True ((Get-FileHash -LiteralPath $copyHelper).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')).Hash) 'Helper copy must start byte-identical.'
    if ($AppendHelpers) { [IO.File]::AppendAllText($copyHelper, "`r`n" + $AppendHelpers, [Text.Encoding]::UTF8) }
    Add-Fixture $entry; Add-Fixture $copyHelper
    return $entry
}
function Invoke-Entry {
    param([string]$Label, [string]$InputPath, [string]$Entry = $ordinaryEntry, [string]$DriverPrefix = '', [int]$Rate = 64)
    $parent = Join-Path $testRoot ('O-' + $Label); [IO.Directory]::CreateDirectory($parent) | Out-Null
    $driver = @('$ErrorActionPreference=''Stop''', '$ProgressPreference=''SilentlyContinue''',
        ('$env:PATH=' + (Get-Literal (Split-Path -Parent $ffmpeg)) + '+'';''+$env:PATH'), $DriverPrefix,
        '$global:LASTEXITCODE=$null',
        ('& ' + (Get-Literal $Entry) + ' -InputFolder ' + (Get-Literal $InputPath) + ' -OutputParent ' + (Get-Literal $parent) + ' -BitrateKbps ' + $Rate + ' *>&1 | ForEach-Object {'),
        '  if ($_ -is [Management.Automation.ErrorRecord]) { [Console]::Out.WriteLine($_.Exception.Message) }',
        '  else { [Console]::Out.WriteLine([string]$_) }', '}',
        'if ($null -eq $global:LASTEXITCODE) { throw ''Entry omitted explicit script exit code.'' }', 'exit $global:LASTEXITCODE') -join "`n"
    $driverPath = Join-Path $testRoot ($Label + '-driver.ps1'); Write-NewText $driverPath $driver; Add-Fixture $driverPath
    $info = New-Object Diagnostics.ProcessStartInfo; $info.FileName = $shellPath
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' + $driverPath + '"'
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    Assert-True ($process.Start()) 'Owned child must start.'
    $child = [pscustomobject]@{ process = $process; stdout_task = $process.StandardOutput.ReadToEndAsync(); stderr_task = $process.StandardError.ReadToEndAsync(); disposed = $false; timed_out = $false }
    $children.Add($child)
    if (-not $process.WaitForExit(60000)) { $child.timed_out = $true; throw 'Short-fixture child timed out; preserve its exact tree because descendant release is unproved.' }
    if (-not $child.stdout_task.Wait(5000) -or -not $child.stderr_task.Wait(5000)) { $child.timed_out = $true; throw 'Owned child pipes did not close within the teardown bound; preserve its exact tree.' }
    $stdout = $child.stdout_task.GetAwaiter().GetResult(); $stderr = $child.stderr_task.GetAwaiter().GetResult()
    $code = $process.ExitCode; $process.Dispose(); $child.disposed = $true
    Write-NewText (Join-Path $testRoot ($Label + '-stdout.log')) $stdout
    Write-NewText (Join-Path $testRoot ($Label + '-stderr.log')) $stderr
    return [pscustomobject]@{ exit_code = $code; text = $stdout + "`n" + $stderr; output_parent = $parent }
}
function Assert-Outcome {
    param([object]$Result, [object]$Case, [string]$Status, [int]$Code, [int]$Total, [int]$Processed, [int]$Converted, [int]$Failed, [int]$NotProcessed, [int]$Excluded = 0, [int]$Unsupported = 0, [switch]$ReservedSetupFailure, [switch]$UnprovedNativeExit)
    Assert-True ($Result.exit_code -eq $Code) ('Expected child exit ' + $Code + ', got ' + $Result.exit_code + '. ' + $Result.text.Substring([Math]::Max(0, $Result.text.Length - 1600)))
    $summaryLines = @($Result.text -split '\r?\n' | Where-Object { $_ -match '^\[RESULT\] ' })
    Assert-True ($summaryLines.Count -ge 1) 'Every path must emit a final stable aggregate result.'
    $fields = @{}
    # Normal runs also echo the persisted RESULT log record; the final summary
    # follows diagnostic failures and is authoritative for the actual exit.
    foreach ($pair in ($summaryLines[$summaryLines.Count - 1].Substring(9) -split ';\s*')) {
        $parts = $pair -split '=', 2; if ($parts.Count -eq 2) { $fields[$parts[0].Trim()] = $parts[1].Trim() }
    }
    foreach ($expected in @(@{ key = 'status'; value = $Status }, @{ key = 'total'; value = [string]$Total },
        @{ key = 'processed'; value = [string]$Processed }, @{ key = 'converted'; value = [string]$Converted },
        @{ key = 'failed'; value = [string]$Failed }, @{ key = 'not_processed'; value = [string]$NotProcessed },
        @{ key = 'scan_excluded'; value = [string]$Excluded }, @{ key = 'unsupported'; value = [string]$Unsupported })) {
        Assert-True ($fields[$expected.key] -ceq $expected.value) ('Aggregate field ' + $expected.key + ' expected ' + $expected.value + ', observed ' + $fields[$expected.key])
    }
    $elapsed = 0.0
    Assert-True ([double]::TryParse($fields['elapsed_seconds'], [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$elapsed) -and $elapsed -ge 0 -and -not [double]::IsInfinity($elapsed)) 'Aggregate elapsed time must be finite nonnegative seconds.'
    $Case['exit_code'] = $Code; $Case['outcome'] = $fields; $Case['explicit_exit_verified'] = $true
    $roots = @(Get-ChildItem -LiteralPath $Result.output_parent -Force | Where-Object { $_.PSIsContainer })
    if ($Status -eq 'FailedBeforeConversion' -and -not $ReservedSetupFailure) {
        Assert-True ($roots.Count -eq 0 -and @(Get-SafeTree $Result.output_parent).Count -eq 0) 'Preflight must leave the explicit parent empty.'
        $Case['no_run_writes'] = $true; return
    }
    Assert-True ($roots.Count -eq 1) 'Started batch must have one exact run inside its owned parent.'
    $root = $roots[0].FullName
    Assert-True (Test-AudioPathWithin -Path $root -Parent $Result.output_parent) 'Actual run must stay inside exact owned output parent.'
    $marker = [IO.File]::ReadAllText((Join-Path $root '.AudioFileForPhone-output.json')) | ConvertFrom-Json
    Assert-True ($marker.output_root -ceq $root -and $marker.cleanup_scope -ceq $root -and $marker.ownership_token -match '^[0-9a-f]{32}$') 'Actual reservation must self-match its root/token/scope.'
    $tree = @(Get-SafeTree $root)
    if ($ReservedSetupFailure) {
        Assert-True ($tree.Count -eq 1 -and $tree[0].Name -ceq '.AudioFileForPhone-output.json') 'Injected setup failure must retain exactly the owned marker and no log/final/partial output.'
        $Case['owned_marker_residue_preserved'] = $true; $Case['no_conversion_or_partial_output'] = $true
        return [pscustomobject]@{ root = $root; marker = $marker }
    }
    $published = @($tree | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
    Assert-True ($published.Count -eq $Converted) 'Aggregate conversions must equal independently observed published outputs.'
    $partials = @($tree | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.partial' })
    if ($UnprovedNativeExit) {
        Assert-True ($partials.Count -eq 1 -and $partials[0].Name -cmatch '^\.AudioFileForPhone-[0-9a-f]{32}\.partial$') 'An abrupt native exception must retain exactly one recognizable incomplete working file.'
        $runLog = [IO.File]::ReadAllText((Join-Path $root 'AudioFileForPhone_log.txt'))
        Assert-True ($Result.text.Contains($partials[0].FullName) -and $runLog.Contains($partials[0].FullName) -and
            $runLog.Contains('Owned native process exit was not established')) 'The exact retained path and unproved-exit reason must appear on console and in the log.'
        $Case['retained_partial'] = $partials[0].FullName.Substring($root.Length + 1)
        $Case['unproved_native_exit_preserved'] = $true
    }
    else { Assert-True ($partials.Count -eq 0) 'Handled cases with proved native exit must leave no incomplete working file.' }
    $outputs = @()
    foreach ($file in $published) {
        $probe = (Invoke-RealSuccess $ffprobe @('-v', 'error', '-show_entries', 'stream=codec_type,codec_name,bit_rate', '-of', 'json', '-i', $file.FullName)).Stdout | ConvertFrom-Json
        $audio = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' })
        Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Published output must independently probe as requested 64 kbps MP3.'
        Invoke-RealSuccess $ffmpeg @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $file.FullName, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
        $outputs += [pscustomobject]@{ relative_path = $file.FullName.Substring($root.Length + 1); sha256 = (Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant(); fully_decoded = $true }
    }
    $log = Join-Path $root 'AudioFileForPhone_log.txt'
    Assert-True ($Result.text.Contains($root) -and $Result.text.Contains($log)) 'Final messages must report the actual output root and local log path.'
    $Case['published_outputs'] = $outputs; $Case['publication_count_verified'] = $true
    $Case['no_partials'] = -not $UnprovedNativeExit; $Case['output_and_log_reported'] = $true
    return [pscustomobject]@{ root = $root; log = $log; published = $published }
}
function Assert-LoggedMappings {
    param([object]$Observed, [string]$InputPath, [int]$ExpectedSuccesses, [int]$ExpectedFailures)
    $lines = [IO.File]::ReadAllText($Observed.log) -split '\r?\n'
    $oks = @($lines | Where-Object { $_ -match '^\[OK\] OK\s+: ' })
    $fails = @($lines | Where-Object { $_ -match '^\[FAIL\] FAIL : ' })
    Assert-True ($oks.Count -eq $ExpectedSuccesses -and $fails.Count -eq $ExpectedFailures) 'Per-file log outcomes must exactly match actual successes and failures.'
    foreach ($line in @($oks + $fails)) {
        # Native failure reasons can span physical log lines; mapping is the
        # exact quoted prefix, independent of the diagnostic that follows it.
        Assert-True ($line -match "^\[(OK|FAIL)\] (?:OK|FAIL)\s*:\s*'(.+)' -> '([^']+)'") 'Every file outcome must record a source and an exact target mapping.'
        $kind = $Matches[1]; $source = $Matches[2]; $target = $Matches[3]
        Assert-True ((Test-AudioPathWithin -Path $source -Parent $InputPath) -and (Test-Path -LiteralPath $source -PathType Leaf)) 'Logged source mapping must identify an unchanged synthetic input.'
        Assert-True (Test-AudioPathWithin -Path $target -Parent $Observed.root) 'Logged target must remain inside actual owned run.'
        if ($kind -eq 'OK') {
            Assert-True (@($Observed.published | Where-Object { $_.FullName -ceq $target }).Count -eq 1) 'Successful logged target must equal one independently observed published output.'
        }
        else { Assert-True (-not (Test-Path -LiteralPath $target)) 'Failed planned target must remain unpublished.' }
    }
}

try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop; Assert-NoReparse $tempParent
    $ownedRootCreated = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved = $true; Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools'] = @($ffmpeg, $ffprobe | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant(); version = (Invoke-RealSuccess $_ @('-version')).Stdout.Split([char]10)[0].Trim() } })
    $report.source_before = Get-SourceInventory
    $seedRoot = Join-Path $testRoot 'S'; [IO.Directory]::CreateDirectory($seedRoot) | Out-Null
    foreach ($extension in @('mp3', 'm4a', 'ogg')) {
        $codec = switch ($extension) { 'mp3' { 'libmp3lame' }; 'm4a' { 'aac' }; 'ogg' { 'libvorbis' } }
        $path = Join-Path $seedRoot ('good.' + $extension)
        Invoke-RealSuccess $ffmpeg @('-nostdin', '-hide_banner', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=733:sample_rate=44100', '-t', '0.2', '-c:a', $codec, '-metadata', 'title=Synthetic T10 result fixture', $path) | Out-Null
        Add-Fixture $path
    }
    $ordinaryEntry = New-AppCopy 'plain'; $report.copied_entry_bytes_unchanged = $true
    $successInput = New-Input 'I-success' @('2024-01-01 First.mp3', '2024-01-02 Second.m4a', 'Sub/2024-01-03 Third.ogg')
    $unsupported = Join-Path $successInput 'notes.txt'; Write-NewText $unsupported 'synthetic unsupported-extension sentinel'; Add-Fixture $unsupported
    $excluded = Join-Path $successInput 'Prior'; [IO.Directory]::CreateDirectory($excluded) | Out-Null
    $excludedMarker = Join-Path $excluded '.AudioFileForPhone-output.json'
    Write-NewText $excludedMarker (([ordered]@{ schema_version = 1; kind = 'AudioFileForPhone.Output'; output_root = $excluded } | ConvertTo-Json)); Add-Fixture $excludedMarker
    $excludedAudio = Join-Path $excluded 'excluded.mp3'; [IO.File]::Copy((Join-Path $seedRoot 'good.mp3'), $excludedAudio, $false); Add-Fixture $excludedAudio
    Invoke-Case 'real all-success with accurate unsupported/excluded counts and recursive mapping' {
        param($case)
        $result = Invoke-Entry 'success' $successInput
        $observed = Assert-Outcome $result $case 'Completed' 0 3 3 3 0 0 1 1
        Assert-True (@($observed.published | Where-Object { $_.FullName -match '\\Sub\\2024-01-03 - Third\.mp3$' }).Count -eq 1) 'Recursive planned relative mapping must reach the actual final filename.'
        $log = [IO.File]::ReadAllText($observed.log)
        foreach ($name in @('2024-01-01 First.mp3', '2024-01-02 Second.m4a', '2024-01-03 Third.ogg')) { Assert-True ($log.Contains($name)) 'Every source mapping must be logged.' }
        Assert-LoggedMappings $observed $successInput 3 0
        $case['recursive_mapping_verified'] = $true; $case['exact_per_file_log_mappings_verified'] = $true
    }
    $partialInput = New-Input 'I-partial' @('2024-01-01 First.mp3', '2024-01-02 bad.m4a', '2024-01-03 Last.ogg')
    Invoke-Case 'real good-bad-good continues both independent valid files and exits2' {
        param($case)
        $result = Invoke-Entry 'partial' $partialInput
        $observed = Assert-Outcome $result $case 'CompletedWithFailures' 2 3 3 2 1 0
        $log = [IO.File]::ReadAllText($observed.log)
        Assert-True ($log.Contains('2024-01-02 bad.m4a') -and $log -match 'FAIL') 'Bad source and failure must be logged.'
        Assert-True (@($observed.published | Where-Object { $_.Name -match 'First|Last' }).Count -eq 2) 'Good files before and after failed input must be published.'
        Assert-LoggedMappings $observed $partialInput 2 1
        $case['failure_mapping_verified'] = $true; $case['later_valid_file_completed'] = $true; $case['exact_per_file_log_mappings_verified'] = $true
    }
    $badInput = New-Input 'I-bad' @('2024-01-02 bad.mp3')
    Invoke-Case 'real failures-only completed batch exits2 with zero publication' { param($case); $result = Invoke-Entry 'bad' $badInput; Assert-Outcome $result $case 'CompletedWithFailures' 2 1 1 0 1 0 | Out-Null }
    Invoke-Case 'invalid requested rate fails before conversion with exit1' { param($case); $result = Invoke-Entry 'invalid-rate' $successInput -Rate 65; Assert-Outcome $result $case 'FailedBeforeConversion' 1 0 0 0 0 0 | Out-Null }
    Invoke-Case 'missing input fails before conversion with exit1' { param($case); $result = Invoke-Entry 'missing' (Join-Path $testRoot 'Missing'); Assert-Outcome $result $case 'FailedBeforeConversion' 1 0 0 0 0 0 | Out-Null }
    $emptyInput = Join-Path $testRoot 'I-empty'; [IO.Directory]::CreateDirectory($emptyInput) | Out-Null
    $emptyText = Join-Path $emptyInput 'unsupported.txt'; Write-NewText $emptyText 'synthetic unsupported only'; Add-Fixture $emptyText
    Invoke-Case 'no supported files fails before conversion and reports unsupported separately' { param($case); $result = Invoke-Entry 'empty' $emptyInput; Assert-Outcome $result $case 'FailedBeforeConversion' 1 0 0 0 0 0 0 1 | Out-Null }
    $throwHelper = @'
$script:T10OriginalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath, [string[]]$Arguments, [int]$MaxStdoutChars=1048576, [int]$MaxStderrChars=65536, [object]$Cancellation=(Get-AudioCancellationContext), [scriptblock]$ProgressCallback, [object]$ProgressDurationSeconds, [object]$ProgressParser, [object]$ProgressCallbackState)
    if (@($Arguments | Where-Object { $_ -match '2024-01-02 throw\.m4a$' }).Count -gt 0) { throw 'controlled source probe native boundary exception' }
    return & $script:T10OriginalNative @PSBoundParameters
}
'@
    $throwEntry = New-AppCopy 'throw' $throwHelper
    $throwInput = New-Input 'I-throw' @('2024-01-01 First.mp3', '2024-01-02 throw.m4a', '2024-01-03 Last.ogg')
    Invoke-Case 'thrown native source-probe exception belongs to its file and next valid file continues' {
        param($case); $result = Invoke-Entry 'native-throw' $throwInput $throwEntry
        Assert-Outcome $result $case 'CompletedWithFailures' 2 3 3 2 1 0 | Out-Null
        Assert-True ($result.text.Contains('controlled source probe native boundary exception')) 'File failure must preserve the thrown native root cause.'
        $case['test_helper_append_only'] = $true; $case['native_root_cause_preserved'] = $true
    }
    $encodeThrowHelper = @'
$script:T10OriginalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath, [string[]]$Arguments, [int]$MaxStdoutChars=1048576, [int]$MaxStderrChars=65536, [object]$Cancellation=(Get-AudioCancellationContext), [scriptblock]$ProgressCallback, [object]$ProgressDurationSeconds, [object]$ProgressParser, [object]$ProgressCallbackState)
    if ([IO.Path]::GetFileName($ExecutablePath) -ieq 'ffmpeg.exe' -and
        @($Arguments | Where-Object { $_ -match 'encode-throw\.mp3$' }).Count -gt 0) { throw 'controlled encoder native boundary exception' }
    return & $script:T10OriginalNative @PSBoundParameters
}
'@
    $encodeThrowEntry = New-AppCopy 'encode-throw' $encodeThrowHelper
    $encodeThrowInput = New-Input 'I-encode-throw' @('2024-01-01 encode-throw.mp3', '2024-01-02 Last.ogg')
    Invoke-Case 'thrown encoder exception preserves unproved partial and next valid file continues' {
        param($case); $result = Invoke-Entry 'encoder-throw' $encodeThrowInput $encodeThrowEntry
        Assert-Outcome $result $case 'CompletedWithFailures' 2 2 2 1 1 0 -UnprovedNativeExit | Out-Null
        Assert-True ($result.text.Contains('controlled encoder native boundary exception') -and $result.text.Contains('EncodeFailed')) 'Encoder throw must retain transactional root cause/status.'
        $case['test_helper_append_only'] = $true; $case['native_root_cause_preserved'] = $true
    }
    $logFaultPrefix = @'
function global:Add-Content {
    [CmdletBinding()] param([string]$LiteralPath,[Parameter(ValueFromPipeline=$true)][object]$Value)
    process { if ([string]$Value -match '\[OK\]') { throw 'controlled postpublication log write failure' }
        Microsoft.PowerShell.Management\Add-Content -LiteralPath $LiteralPath -Value $Value -ErrorAction Stop }
}
'@
    $twoInput = New-Input 'I-two' @('2024-01-01 First.mp3', '2024-01-03 Last.ogg')
    $setupFaultHelper = @'
function New-AudioRunLog {
    param([Parameter(Mandatory=$true)][string]$OutputRoot)
    throw 'controlled reserved run log setup exception'
}
'@
    $setupFaultEntry = New-AppCopy 'setup-fault' $setupFaultHelper
    Invoke-Case 'reserved setup failure reports exact retained scope and token before any conversion' {
        param($case); $result = Invoke-Entry 'setup-fault' $twoInput $setupFaultEntry
        $observed = Assert-Outcome $result $case 'FailedBeforeConversion' 1 2 0 0 0 2 -ReservedSetupFailure
        $scopeAndToken = "Exact owned scope '$($observed.root)', token '$($observed.marker.ownership_token)'"
        Assert-True ($result.text.Contains($scopeAndToken) -and $result.text.Contains('controlled reserved run log setup exception')) 'Fatal setup diagnostic must identify the actual retained scope/token and original setup cause.'
        Assert-True ($result.text.Contains('Output root  : (not available; see error for any reserved scope)') -and
            $result.text.Contains('Log file     : (not available)')) 'Final summary must direct the user to the reserved scope diagnostic without claiming that no root was reserved.'
        $case['exact_scope_and_token_reported'] = $true; $case['final_scope_availability_truthful'] = $true; $case['test_helper_append_only'] = $true
    }
    Invoke-Case 'postpublication log failure keeps one conversion and truthful not-processed count' {
        param($case); $result = Invoke-Entry 'published-log-fault' $twoInput -DriverPrefix $logFaultPrefix
        $observed = Assert-Outcome $result $case 'Failed' 1 2 1 1 0 1
        Assert-True ($result.text.Contains('controlled postpublication log write failure') -and $result.text.Contains($observed.published[0].FullName)) 'Fatal diagnostic must retain published mapping and subsequent log failure.'
        $case['published_mapping_reported'] = $true; $case['converted_not_reclassified'] = $true
    }
    $failLogPrefix = $logFaultPrefix.Replace('\[OK\]', '\[FAIL\]').Replace('controlled postpublication log write failure', 'controlled failure log write exception')
    Invoke-Case 'failure-log exception preserves source failure and never counts the same file twice' {
        param($case); $result = Invoke-Entry 'failed-log-fault' $throwInput $throwEntry $failLogPrefix
        Assert-Outcome $result $case 'Failed' 1 3 2 1 1 1 | Out-Null
        Assert-True ($result.text.Contains('controlled source probe native boundary exception') -and $result.text.Contains('controlled failure log write exception')) 'Fatal reporting failure must preserve the original native cause and secondary cause.'
        $case['original_and_diagnostic_causes_preserved'] = $true; $case['test_helper_append_only'] = $true
    }
    $summaryPrefix = $logFaultPrefix.Replace('\[OK\]', 'Summary:').Replace('controlled postpublication log write failure', 'controlled summary log write exception')
    Invoke-Case 'summary-log failure yields fatal status while retaining all published conversions' {
        param($case); $result = Invoke-Entry 'summary-log-fault' $twoInput -DriverPrefix $summaryPrefix
        Assert-Outcome $result $case 'Failed' 1 2 2 2 0 0 | Out-Null
        Assert-True ($result.text.Contains('controlled summary log write exception')) 'Final diagnostic must identify the summary log failure.'
    }
    $progressPrefix = @'
function global:Write-Progress {
    [CmdletBinding()] param([string]$Activity,[string]$Status,[int]$PercentComplete,[int]$Id,[int]$ParentId,[switch]$Completed)
    throw 'controlled progress display exception'
}
'@
    Invoke-Case 'progress display exception is diagnostic and preserves successful conversions' {
        param($case); $result = Invoke-Entry 'progress-fault' $twoInput -DriverPrefix $progressPrefix
        Assert-Outcome $result $case 'Completed' 0 2 2 2 0 0 | Out-Null
        Assert-True ($result.text.Contains('Progress display failed: controlled progress display exception')) 'Progress fault must be reported explicitly without masking outcome.'
        $case['progress_fault_reported'] = $true
    }
    $report.status = 'pass'; $exitCode = 0
}
catch { $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    $childrenStopped = $true
    foreach ($child in $children) {
        if ($child.timed_out) { $childrenStopped = $false }
        if ($child.disposed) { continue }
        try {
            if (-not $child.process.HasExited) { $child.process.Kill() }
            Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Owned child still active; preserve exact test tree.'
            Assert-True ($child.stdout_task.Wait(5000) -and $child.stderr_task.Wait(5000)) 'Owned child pipes remained open after bounded teardown; preserve exact test tree.'
            $null = $child.stdout_task.GetAwaiter().GetResult(); $null = $child.stderr_task.GetAwaiter().GetResult()
            $child.process.Dispose(); $child.disposed = $true
        } catch { $childrenStopped = $false; $report['child_cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    $report.children_disposed = $childrenStopped
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
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exactly to this exclusive TEMP root.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact create-new owner token.'
            Get-SafeTree $resolved | Out-Null; [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    if (-not $childrenStopped) { $report.status = 'fail'; $exitCode = 1 }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 16)
}
Write-Host "T10 script: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
