<#
T08 exclusive run ownership, CreateNew identity/logs, and process barriers.
All fixtures and diagnostics live in one exclusively owned short TEMP root.
Named ready/release events synchronize distinct child processes without sleeps.
Cleanup trusts the test root's create-new token and returned reservation tokens;
it never reclaims a run solely from its name or parsed public marker.
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
$testName = 'T8-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t08-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$originalPath = $env:PATH
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$events = New-Object 'System.Collections.Generic.List[object]'
$ownedRuns = New-Object 'System.Collections.Generic.List[object]'
$savedAcls = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-RunReservation.ps1')
$exitCode = 1
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T08|T09|T11|T15|T16)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T08/T09/T11/T15/T16-<label>.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label to preserve previous evidence.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$ownerHash = [Security.Cryptography.SHA256]::Create()
try { $ownerSha = ([BitConverter]::ToString($ownerHash.ComputeHash([Text.Encoding]::UTF8.GetBytes($ownerToken)))).Replace('-', '').ToLowerInvariant() }
finally { $ownerHash.Dispose() }
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'exclusive_reservation_and_barrier_processes'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    owned_temp_root_name = $testName; owner_marker_sha256 = $ownerSha
    temp_parent_selection = 'shorter existing user/machine TEMP, read-only environment lookup'
    cases = @(); acls_restored = $false; children_disposed = $false; cleanup_verified = $false
    status = 'fail'; error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Assert-Throws {
    param([scriptblock]$Body, [string]$Pattern)
    $caught = $null
    try { & $Body | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -match $Pattern) "Expected rejection matching '$Pattern'; received '$caught'."
}

function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' }
    finally { $report.cases += [pscustomobject]$case }
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point in a test path or ancestor.'
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
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside the exact owned test tree.'
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}

function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Get-FixtureInventory {
    return @($fixtures | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Write-NewText {
    param([string]$Path, [string]$Text)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function New-BarrierEvent {
    param([string]$Name)
    $created = $false
    $handle = New-Object Threading.EventWaitHandle($false, [Threading.EventResetMode]::ManualReset, $Name, [ref]$created)
    Assert-True $created 'Test synchronization event must be newly created for this owned invocation.'
    $events.Add($handle)
    return $handle
}

function Start-BarrierChild {
    param([string]$Label, [string]$ReadyName, [string]$ReleaseName, [string]$Body)
    $resultPath = Join-Path $testRoot ($Label + '.json')
    $parts = @('$ErrorActionPreference = ''Stop''', '$ProgressPreference = ''SilentlyContinue''',
        ('. ' + (ConvertTo-PowerShellLiteral $helpersCopy)),
        ('$ready = [Threading.EventWaitHandle]::OpenExisting(' + (ConvertTo-PowerShellLiteral $ReadyName) + ')'),
        ('$release = [Threading.EventWaitHandle]::OpenExisting(' + (ConvertTo-PowerShellLiteral $ReleaseName) + ')'),
        'try {', '    $null = $ready.Set()',
        '    if (-not $release.WaitOne(60000)) { throw ''Parent did not release the process barrier.'' }',
        '    $payload = & {', $Body, '    }',
        '    $bytes = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 10))',
        ('    $stream = New-Object IO.FileStream(' + (ConvertTo-PowerShellLiteral $resultPath) + ', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)'),
        '    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }',
        '    exit 0', '} catch {', '    [Console]::Out.WriteLine($_.Exception.Message)', '    exit 1',
        '} finally { $ready.Dispose(); $release.Dispose() }')
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(($parts -join "`n")))
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $shell
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -EncodedCommand ' + $encoded
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    Assert-True ($process.Start()) 'Owned test child process must start.'
    $child = [pscustomobject]@{
        label = $Label; process = $process; stdout_task = $process.StandardOutput.ReadToEndAsync()
        stderr_task = $process.StandardError.ReadToEndAsync(); result_path = $resultPath; collected = $false
    }
    $children.Add($child)
    return $child
}

function Wait-BarrierReady {
    param([object[]]$Handles)
    # PS5.1 defaults to STA, where WaitAll over multiple handles is unsupported.
    # One deadline bounds these waits; no release occurs until every signal arrives.
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        foreach ($handle in $Handles) {
            $remaining = [int][Math]::Max(0, 50000 - $watch.ElapsedMilliseconds)
            Assert-True ($handle.WaitOne($remaining)) 'Every distinct child must signal ready before the shared process barrier is released.'
        }
    }
    finally { $watch.Stop() }
}

function Complete-BarrierChild {
    param($Child)
    Assert-True ($Child.process.WaitForExit(60000)) 'Owned short-fixture child must finish within the test deadline.'
    $text = $Child.stdout_task.GetAwaiter().GetResult() + "`n" + $Child.stderr_task.GetAwaiter().GetResult()
    Write-NewText (Join-Path $testRoot ($Child.label + '.log')) $text
    $Child.collected = $true
    Assert-True ($Child.process.ExitCode -eq 0) "Owned barrier child failed: $text"
    Assert-True (Test-Path -LiteralPath $Child.result_path -PathType Leaf) 'Successful child must publish one create-new result report.'
    return [IO.File]::ReadAllText($Child.result_path) | ConvertFrom-Json
}

function Assert-ReservationIdentity {
    param($Reservation, [string]$ExpectedParent, [switch]$Register)
    $root = Get-AudioPath $Reservation.OutputRoot
    Assert-True ((Split-Path -Parent $root) -ieq $ExpectedParent -and
        $root.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Reservation must stay in its exact selected owned TEMP parent.'
    Assert-NoReparse $root
    Assert-True ($Reservation.LogPath -ceq (Join-Path $root 'AudioFileForPhone_log.txt')) 'Reservation must return this root\log path.'
    $markerPath = Join-Path $root '.AudioFileForPhone-output.json'
    $marker = [IO.File]::ReadAllText($markerPath) | ConvertFrom-Json
    Assert-True ($marker.schema_version -eq 1 -and $marker.kind -ceq 'AudioFileForPhone.Output' -and
        $marker.output_root -ceq $root -and $marker.ownership_token -ceq $Reservation.OwnerToken -and
        $marker.cleanup_scope -ceq $root -and -not [string]::IsNullOrWhiteSpace($Reservation.OwnerToken)) 'Create-new marker must match the trusted returned token and exact cleanup scope.'
    Assert-True (Test-Path -LiteralPath $Reservation.LogPath -PathType Leaf) 'Exclusive reservation must create its own log.'
    if ($Register) { $ownedRuns.Add([pscustomobject]@{ OutputRoot = $root; LogPath = $Reservation.LogPath; OwnerToken = $Reservation.OwnerToken; parent = $ExpectedParent }) }
}

function Assert-Mp3Decoded {
    param([string]$Path)
    $probe = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $Path)
    Assert-True ($probe.Status -eq 'Completed' -and $probe.ExitCode -eq 0) 'Real output probe must succeed.'
    $media = $probe.Stdout | ConvertFrom-Json
    $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Concurrent entry output must preserve the default one-stream 64 kbps MP3 behavior.'
    Assert-True ($media.format.tags.title -ceq '2024-01-02 - Synthetic') 'Missing source title must become the allocated basename.'
    $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-i', $Path, '-f', 'null', '-')
    Assert-True ($decode.Status -eq 'Completed' -and $decode.ExitCode -eq 0) 'Concurrent short output must fully decode.'
}

try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    $report.source_before = Get-SourceInventory
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhoneT08 {
    public static class NativeFixture {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr security);
    }
}
'@
    Assert-True ([AudioFileForPhoneT08.NativeFixture]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Short TEMP root must be exclusively reserved and writable.'
    $ownedRootCreated = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'A'; $inputRoot = Join-Path $testRoot 'S'
    $helperParent = Join-Path $testRoot 'H'; $realParent = Join-Path $testRoot 'P'
    $nestedInput = Join-Path $testRoot 'N'; $createNewRoot = Join-Path $testRoot 'C'; $deniedParent = Join-Path $testRoot 'D'
    $counterParent = Join-Path $testRoot 'Q'; $setupDeniedParent = Join-Path $testRoot 'E'
    foreach ($directory in @($appRoot, $inputRoot, $helperParent, $realParent, $nestedInput, $createNewRoot, $deniedParent, $counterParent, $setupDeniedParent)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'; $helpersCopy = Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Destination $scriptCopy
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1') -Destination $helpersCopy
    foreach ($copy in @($scriptCopy, $helpersCopy)) {
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot (Split-Path -Leaf $copy))).Hash) 'Application/helper copies must preserve exact source bytes.'
    }
    $report.copied_bytes_unchanged = $true
    . $helpersCopy
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($selection in @(@{ name = 'ffmpeg'; path = $ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe })) {
        $version = Invoke-AudioNativeProcess -ExecutablePath $selection.path -Arguments @('-version')
        Assert-True ($version.Status -eq 'Completed' -and $version.ExitCode -eq 0) 'Selected native tool must report its version.'
        $report[$selection.name] = [ordered]@{ version = ($version.Stdout -split '\r?\n')[0]; sha256 = (Get-FileHash -LiteralPath $selection.path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
    $sourceAudio = Join-Path $inputRoot '2024-01-02 - Synthetic.mp3'
    $generated = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=0.2', '-c:a', 'libmp3lame', '-map_metadata', '-1', $sourceAudio)
    Assert-True ($generated.Status -eq 'Completed' -and $generated.ExitCode -eq 0) 'Short synthetic MP3 fixture must be generated.'
    $fixtures.Add($sourceAudio)
    $files = @(Get-Item -LiteralPath $sourceAudio)
    $fixedStamp = '20300102_030405'
    $occupiedDirectory = Join-Path $helperParent ('AudioForPhone_64kbps_' + $fixedStamp)
    [IO.Directory]::CreateDirectory($occupiedDirectory) | Out-Null
    foreach ($name in @('sentinel.txt', 'AudioFileForPhone_log.txt', '.AudioFileForPhone-output.json')) {
        $path = Join-Path $occupiedDirectory $name; Write-NewText $path ('Existing unowned fixture ' + $name); $fixtures.Add($path)
    }
    $occupiedFile = Join-Path $helperParent ('AudioForPhone_64kbps_' + $fixedStamp + '_2')
    Write-NewText $occupiedFile 'Existing file must never become a run directory.'; $fixtures.Add($occupiedFile)
    $lastCounterFile = Join-Path $counterParent ('AudioForPhone_64kbps_' + $fixedStamp + '_' + [int]::MaxValue)
    Write-NewText $lastCounterFile 'Maximum counter existing file.'; $fixtures.Add($lastCounterFile)
    $nestedStamp = '20300102_040506'
    $nestedOccupied = Join-Path $nestedInput ('AudioForPhone_64kbps_' + $nestedStamp)
    [IO.Directory]::CreateDirectory($nestedOccupied) | Out-Null
    $nestedAudio = Join-Path $nestedOccupied '2024-01-02 - Prior unmarked audio.mp3'
    Copy-Item -LiteralPath $sourceAudio -Destination $nestedAudio; $fixtures.Add($nestedAudio)
    $nestedOriginal = Join-Path $nestedInput '2024-01-02 - Original.mp3'
    Copy-Item -LiteralPath $sourceAudio -Destination $nestedOriginal; $fixtures.Add($nestedOriginal)
    $budgetParent = Join-Path $testRoot ('b' * (160 - $testRoot.Length - 1))
    [IO.Directory]::CreateDirectory($budgetParent) | Out-Null
    $budgetFirst = Join-Path $budgetParent ('AudioForPhone_64kbps_' + $fixedStamp)
    [IO.Directory]::CreateDirectory($budgetFirst) | Out-Null
    $budgetSentinel = Join-Path $budgetFirst 'sentinel.txt'; Write-NewText $budgetSentinel 'Occupied exact-budget first candidate.'; $fixtures.Add($budgetSentinel)
    $report.synthetic_before = Get-FixtureInventory

    Invoke-Case 'pure candidate spelling timestamps suffix bounds and no IO' 'A23' {
        param($case)
        foreach ($counter in @(1, 2, 10, 1000)) {
            $suffix = if ($counter -eq 1) { '' } else { '_' + $counter }
            $expected = Join-Path $helperParent ('AudioForPhone_64kbps_' + $fixedStamp + $suffix)
            Assert-True ((Get-AudioRunCandidate -OutputParent $helperParent -BitrateKbps 64 -Timestamp $fixedStamp -Counter $counter) -ceq $expected) 'Candidate spelling must preserve baseline root and bounded numeric suffix.'
        }
        foreach ($stamp in @('bad', '20300102_0304', '20230229_030405', '20301302_030405', '00000102_030405')) { Assert-Throws { Get-AudioRunCandidate -OutputParent $helperParent -BitrateKbps 64 -Timestamp $stamp } 'timestamp|date|format|invalid' }
        foreach ($counter in @(0, -1)) { Assert-Throws { Get-AudioRunCandidate -OutputParent $helperParent -BitrateKbps 64 -Timestamp $fixedStamp -Counter $counter } 'counter|positive|range' }
        Assert-Throws { Get-AudioRunCandidate -OutputParent $helperParent -BitrateKbps 63 -Timestamp $fixedStamp } 'bitrate|unsupported|rate'
        Assert-True (@(Get-ChildItem -LiteralPath $helperParent -Force).Count -eq 2) 'Pure candidates must not create run roots.'
        $case['counter_values'] = @(1, 2, 10, 1000); $case['invalid_timestamps'] = 5
    }
    Invoke-Case 'four synchronized fixed-timestamp helper reservations isolate ownership and logs' 'A22,A23' {
        param($case)
        $eventPrefix = 'Local\AudioFileForPhone-T08-' + [guid]::NewGuid().ToString('N')
        $releaseName = $eventPrefix + '-release'; $release = New-BarrierEvent $releaseName
        $readyHandles = @(); $batch = @()
        for ($index = 0; $index -lt 4; $index++) {
            $label = 'helper-' + $index; $readyName = $eventPrefix + '-ready-' + $index
            $readyHandles += New-BarrierEvent $readyName
            $body = @(
                ('$files = @(Get-Item -LiteralPath ' + (ConvertTo-PowerShellLiteral $sourceAudio) + ')'),
                ('$reservation = New-AudioRunReservation -OutputParent ' + (ConvertTo-PowerShellLiteral $helperParent) + ' -InputFolder ' + (ConvertTo-PowerShellLiteral $inputRoot) + ' -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp ' + (ConvertTo-PowerShellLiteral $fixedStamp)),
                'if ([IO.File]::ReadAllText($reservation.LogPath).Length -ne 0) { throw ''Reserved helper log must initially contain no text.'' }',
                ('[IO.File]::AppendAllText($reservation.LogPath, ' + (ConvertTo-PowerShellLiteral ('unique helper log ' + $label + "`n")) + ', (New-Object Text.UTF8Encoding($false)))'),
                '[pscustomobject]@{ OutputRoot = $reservation.OutputRoot; LogPath = $reservation.LogPath; OwnerToken = $reservation.OwnerToken; Counter = $reservation.Counter; plan_count = @($reservation.Plans).Count }'
            ) -join "`n"
            $batch += Start-BarrierChild $label $readyName $releaseName $body
        }
        Wait-BarrierReady $readyHandles
        $null = $release.Set()
        $results = @($batch | ForEach-Object { Complete-BarrierChild $_ })
        $uniqueRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $uniqueTokens = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        for ($index = 0; $index -lt $results.Count; $index++) {
            $reservation = $results[$index]; Assert-ReservationIdentity $reservation $helperParent -Register
            Assert-True ($uniqueRoots.Add($reservation.OutputRoot) -and $uniqueTokens.Add($reservation.OwnerToken)) 'Each simultaneous process must own a different run and token.'
            Assert-True ($reservation.plan_count -eq 1 -and [IO.File]::ReadAllText($reservation.LogPath) -ceq ('unique helper log helper-' + $index + "`n")) 'Each log must contain only the distinct record from its creating child.'
        }
        Assert-True ((@($results.Counter | Sort-Object) -join ',') -ceq '3,4,5,6') 'Existing directory/file must be skipped and four exact concurrent suffixes reserved.'
        $case['processes'] = 4; $case['same_fixed_timestamp'] = $fixedStamp; $case['all_ready_before_release'] = $true
        $case['counters'] = @($results.Counter | Sort-Object); $case['roots_and_logs_distinct'] = $true; $case['timing_sleeps'] = 0
    }
    Invoke-Case 'CreateNew marker and shared log writer refuse collision unchanged' 'A23' {
        param($case)
        $token = [guid]::NewGuid().ToString('N')
        Write-AudioOutputMarker -OutputRoot $createNewRoot -OwnerToken $token
        $logPath = New-AudioRunLog -OutputRoot $createNewRoot
        [IO.File]::AppendAllText($logPath, 'CreateNew log collision sentinel.')
        $marker = Join-Path $createNewRoot '.AudioFileForPhone-output.json'
        $markerBefore = (Get-FileHash -LiteralPath $marker).Hash; $logBefore = (Get-FileHash -LiteralPath $logPath).Hash
        Assert-Throws { Write-AudioOutputMarker -OutputRoot $createNewRoot -OwnerToken ([guid]::NewGuid().ToString('N')) } 'exist|CreateNew|create|marker'
        Assert-Throws { New-AudioRunLog -OutputRoot $createNewRoot } 'exist|CreateNew|create|log'
        Assert-True ((Get-FileHash -LiteralPath $marker).Hash -ceq $markerBefore -and (Get-FileHash -LiteralPath $logPath).Hash -ceq $logBefore) 'Failed CreateNew writers must preserve both existing file hashes.'
        $case['marker_and_log_sha256_preserved'] = $true
    }
    Invoke-Case 'attempt exhaustion never overwrites existing directories files or sentinels' 'A23' {
        Assert-Throws { New-AudioRunReservation -OutputParent $helperParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -MaximumAttempts 2 } 'attempt|reserve|collision|exhaust|existing'
        foreach ($attempts in @(0, -1)) { Assert-Throws { New-AudioRunReservation -OutputParent $helperParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -MaximumAttempts $attempts } 'attempt|positive|range' }
        Assert-True (Test-Path -LiteralPath $occupiedDirectory -PathType Container) 'Existing directory must remain a directory.'
        Assert-True (Test-Path -LiteralPath $occupiedFile -PathType Leaf) 'Existing file must remain an unchanged file.'
    }
    Invoke-Case 'raw trailing dot or space parent rejected before canonicalization and writes' 'A23' {
        param($case)
        foreach ($leaf in @('bad.', 'bad ')) {
            $rawParent = $testRoot + '\\' + $leaf + '\\out'
            Assert-Throws { Get-AudioRunCandidate -OutputParent $rawParent -BitrateKbps 64 -Timestamp $fixedStamp } 'component|trailing|dot|space|unsupported|invalid'
            Assert-Throws { Get-AudioAvailableRunCandidate -OutputParent $rawParent -InputFolder $inputRoot -BitrateKbps 64 -Timestamp $fixedStamp } 'component|trailing|dot|space|unsupported|invalid'
            Assert-Throws { New-AudioRunReservation -OutputParent $rawParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp } 'component|trailing|dot|space|unsupported|invalid'
        }
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot 'bad'))) 'Rejected raw components must not create a canonical alias directory.'
        $case['raw_invalid_parents'] = 2; $case['writes_absent'] = $true
    }
    Invoke-Case 'real entry rejects raw parent components before prompts or run writes' 'A23' {
        param($case)
        $treeBefore = @((Get-SafeTree $testRoot).FullName | Sort-Object) | ConvertTo-Json -Compress
        foreach ($form in @('absolute', 'relative')) {
          foreach ($leaf in @('bad.', 'bad ')) {
            $rawParent = if ($form -eq 'absolute') { $testRoot + '\\' + $leaf + '\\out' } else { '.\\' + $leaf + '\\out' }
            $code = @('$ErrorActionPreference = ''Stop''', '$global:LASTEXITCODE = 0',
                ('Set-Location -LiteralPath ' + (ConvertTo-PowerShellLiteral $testRoot)),
                'function global:Read-Host { [Console]::Out.WriteLine(''T08_UNEXPECTED_PROMPT''); throw ''T08_UNEXPECTED_PROMPT'' }',
                'try {',
                ('& ' + (ConvertTo-PowerShellLiteral $scriptCopy) + ' -InputFolder ' + (ConvertTo-PowerShellLiteral $inputRoot) + ' -OutputParent ' + (ConvertTo-PowerShellLiteral $rawParent) + ' -Interactive *>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { [Console]::Out.WriteLine($_.Exception.Message) } else { [Console]::Out.WriteLine([string]$_) } }'),
                'exit $LASTEXITCODE', '} catch { [Console]::Out.WriteLine($_.Exception.Message); exit 1 }') -join "`n"
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
            $result = Invoke-AudioNativeProcess -ExecutablePath $shell -Arguments @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-EncodedCommand', $encoded)
            $text = $result.Stdout + "`n" + $result.Stderr
            Assert-True ($result.Status -eq 'Completed' -and $result.ExitCode -ne 0 -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) 'Raw invalid parent must finish with a nonzero entry status and complete diagnostics.'
            Assert-True ($text -match 'Preflight failed' -and $text -match 'component|trailing|dot|space|unsupported|invalid') "Real entry must explain its raw component rejection: $text"
            Assert-True ($text -notmatch 'T08_UNEXPECTED_PROMPT|Optional metadata step|Processing file|\[INFO\] Output root\s+:|Log file saved to:') 'Raw parent rejection must precede interactive prompts, conversion and run/log creation.'
          }
        }
        $treeAfter = @((Get-SafeTree $testRoot).FullName | Sort-Object) | ConvertTo-Json -Compress
        Assert-True ($treeBefore -ceq $treeAfter -and -not (Test-Path -LiteralPath (Join-Path $testRoot 'bad'))) 'Rejected actual entries must leave the entire owned tree unchanged and no canonical alias output parent.'
        $case['real_entry_rejections'] = 4; $case['invalid_parent_forms'] = @('absolute', 'relative'); $case['interactive_prompt_trap_unused'] = $true
        $case['run_and_log_writes_absent'] = $true; $case['owned_tree_paths_unchanged'] = $true
    }
    Invoke-Case 'explicit start counter and integer exhaustion stay bounded' 'A23' {
        param($case)
        foreach ($start in @(0, -1)) {
            Assert-Throws { Get-AudioAvailableRunCandidate -OutputParent $counterParent -InputFolder $inputRoot -BitrateKbps 64 -Timestamp $fixedStamp -StartCounter $start } 'counter|range|positive'
            Assert-Throws { New-AudioRunReservation -OutputParent $counterParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -StartCounter $start } 'counter|range|positive'
        }
        Assert-Throws { Get-AudioAvailableRunCandidate -OutputParent $counterParent -InputFolder $inputRoot -BitrateKbps 64 -Timestamp $fixedStamp -StartCounter ([int]::MaxValue) -MaximumAttempts 2 } 'counter.*exhaust'
        Assert-Throws { New-AudioRunReservation -OutputParent $counterParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -StartCounter ([int]::MaxValue) -MaximumAttempts 2 } 'counter.*exhaust'
        $reservation = New-AudioRunReservation -OutputParent $counterParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -StartCounter 9 -MaximumAttempts 1
        Assert-ReservationIdentity $reservation $counterParent -Register
        Assert-True ($reservation.Counter -eq 9 -and $reservation.OutputRoot -ceq (Get-AudioRunCandidate -OutputParent $counterParent -BitrateKbps 64 -Timestamp $fixedStamp -Counter 9)) 'Explicit provisional counter must be reserved exactly when available.'
        Assert-True (@(Get-ChildItem -LiteralPath $counterParent -Force).Count -eq 2) 'Exhaustion must create no unexpected candidate.'
        $case['explicit_start_counter'] = 9; $case['integer_overflow_rejected'] = $true
    }
    Invoke-Case 'occupied root with ordinary nested audio remains in actual suffix plan' 'A22,A23' {
        param($case)
        $selected = Get-AudioAvailableRunCandidate -OutputParent $nestedInput -InputFolder $nestedInput -BitrateKbps 64 -Timestamp $nestedStamp
        Assert-True ($selected.Counter -eq 2 -and -not (Test-Path -LiteralPath $selected.OutputRoot)) 'Read-only discovery selection must skip the occupied candidate without claiming its suffix.'
        $snapshot = Get-AudioInputSnapshot -InputFolder $nestedInput -OutputRoot $selected.OutputRoot
        Assert-True (@($snapshot.Files | Where-Object { $_.FullName -ieq $nestedAudio }).Count -eq 1 -and @($snapshot.Files).Count -eq 2) 'Occupied unmarked candidate audio must remain in the complete snapshot.'
        $reservation = New-AudioRunReservation -OutputParent $nestedInput -InputFolder $nestedInput -Files $snapshot.Files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $nestedStamp
        Assert-ReservationIdentity $reservation $nestedInput -Register
        Assert-True ($reservation.Counter -eq 2 -and @($reservation.Plans | Where-Object { $_.SourcePath -ieq $nestedAudio }).Count -eq 1) 'Actual suffixed reservation must retain ordinary source audio from the occupied candidate.'
        $after = Get-AudioInputSnapshot -InputFolder $nestedInput -OutputRoot (Join-Path $nestedInput 'future output\run')
        Assert-True (@($after.Files).Count -eq 2 -and @($after.Skipped | Where-Object { $_.Path -ieq $reservation.OutputRoot -and $_.Reason -match 'generated|output' }).Count -eq 1) 'New marked suffix root must be excluded while occupied unmarked audio remains eligible.'
        $case['occupied_unmarked_audio_retained'] = $true; $case['actual_counter'] = $reservation.Counter
    }
    Invoke-Case 'suffix is replanned against exact future working budget before creation' 'A23' {
        param($case)
        $first = Get-AudioRunCandidate -OutputParent $budgetParent -BitrateKbps 64 -Timestamp $fixedStamp
        $plan = @(Get-AudioBatchNamePlan -Files $files -InputFolder $inputRoot -OutputRoot $first -MaxBaseLength 60)
        Assert-True ($plan[0].WorkingPathTemplate.Length -eq 259) 'Unsuffixed exact-root working path must fit at 259 units.'
        Assert-Throws { New-AudioRunReservation -OutputParent $budgetParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -MaximumAttempts 2 } '260|length|limit|working|path|budget'
        $second = Get-AudioRunCandidate -OutputParent $budgetParent -BitrateKbps 64 -Timestamp $fixedStamp -Counter 2
        Assert-True (-not (Test-Path -LiteralPath $second)) 'Over-budget suffix candidate must not be created.'
        Assert-True (@(Get-ChildItem -LiteralPath $budgetParent -Force).Count -eq 1) 'Failed exact-root planning must retain only the existing first candidate.'
        $case['first_working_length'] = 259; $case['suffixed_working_length'] = 261; $case['failed_candidate_absent'] = $true
    }
    Invoke-Case 'nonoccupancy access denial aborts without attempts creating residue' 'A23' {
        param($case)
        Assert-NoReparse $deniedParent
        $original = Get-Acl -LiteralPath $deniedParent
        $savedAcls.Add([pscustomobject]@{ path = $deniedParent; acl = $original; sddl = $original.Sddl; restored = $false })
        $changed = Get-Acl -LiteralPath $deniedParent
        $rule = New-Object Security.AccessControl.FileSystemAccessRule([Security.Principal.WindowsIdentity]::GetCurrent().User,
            [Security.AccessControl.FileSystemRights]::CreateDirectories, [Security.AccessControl.InheritanceFlags]::None,
            [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Deny)
        $changed.AddAccessRule($rule); Set-Acl -LiteralPath $deniedParent -AclObject $changed
        $probe = Join-Path $deniedParent 'owned deny probe'
        $created = [AudioFileForPhoneT08.NativeFixture]::CreateDirectoryW($probe, [IntPtr]::Zero)
        $nativeError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($created) { [IO.Directory]::Delete($probe, $false) }
        Assert-True (-not $created -and $nativeError -eq 5) 'Owned ACL must actually deny native directory creation with access-denied status.'
        Assert-Throws { New-AudioRunReservation -OutputParent $deniedParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -MaximumAttempts 3 } '5|access|denied|create|reserv'
        Assert-True (@(Get-ChildItem -LiteralPath $deniedParent -Force).Count -eq 0) 'Nonoccupancy failure must leave no root, marker or log.'
        $case['effective_native_win32_denial'] = $nativeError; $case['residue_absent'] = $true
    }
    Invoke-Case 'marker setup denial preserves the exact newly owned root for inspection' 'A23' {
        param($case)
        $original = Get-Acl -LiteralPath $setupDeniedParent
        $savedAcls.Add([pscustomobject]@{ path = $setupDeniedParent; acl = $original; sddl = $original.Sddl; restored = $false })
        $changed = Get-Acl -LiteralPath $setupDeniedParent
        $rule = New-Object Security.AccessControl.FileSystemAccessRule([Security.Principal.WindowsIdentity]::GetCurrent().User,
            [Security.AccessControl.FileSystemRights]::CreateFiles, [Security.AccessControl.InheritanceFlags]::ContainerInherit,
            [Security.AccessControl.PropagationFlags]::InheritOnly, [Security.AccessControl.AccessControlType]::Deny)
        $changed.AddAccessRule($rule); Set-Acl -LiteralPath $setupDeniedParent -AclObject $changed
        $expected = Get-AudioRunCandidate -OutputParent $setupDeniedParent -BitrateKbps 64 -Timestamp $fixedStamp
        Assert-True (-not (Test-Path -LiteralPath $expected)) 'Setup failure fixture must begin without the run root.'
        $failure = $null
        try { New-AudioRunReservation -OutputParent $setupDeniedParent -InputFolder $inputRoot -Files $files -BitrateKbps 64 -MaxBaseLength 60 -Timestamp $fixedStamp -MaximumAttempts 3 | Out-Null }
        catch { $failure = $_.Exception.Message }
        Assert-True ($failure -match 'Reserved run setup failed' -and $failure.Contains($expected) -and $failure -match "token '[0-9a-f]{32}'" -and $failure -match 'access|denied') 'Post-reservation failure must identify its exact owned scope/token and actual marker write denial.'
        Assert-True ((Test-Path -LiteralPath $expected -PathType Container) -and @(Get-ChildItem -LiteralPath $expected -Force).Count -eq 0) 'Production must preserve the new empty owned root when marker setup fails.'
        Assert-True (@(Get-ChildItem -LiteralPath $setupDeniedParent -Force).Count -eq 1) 'Marker setup errors must abort without retrying further candidates.'
        # Root cleanup remains authorized by this test invocation's exclusive TEMP
        # owner token, even though this production call returned no public marker.
        $case['exact_failed_scope_preserved'] = $true; $case['further_candidates_absent'] = $true
    }
    Invoke-Case 'two synchronized real entry processes produce distinct decoded run trees' 'A22,A23' {
        param($case)
        $eventPrefix = 'Local\AudioFileForPhone-T08-' + [guid]::NewGuid().ToString('N')
        $releaseName = $eventPrefix + '-release'; $release = New-BarrierEvent $releaseName
        $readyHandles = @(); $batch = @()
        for ($index = 0; $index -lt 2; $index++) {
            $label = 'entry-' + $index; $readyName = $eventPrefix + '-ready-' + $index
            $readyHandles += New-BarrierEvent $readyName
            $parentSpelling = if ($index -eq 0) { '.\P' } else { 'T08Out:\' }
            $destinationSetup = if ($index -eq 0) {
                'Set-Location -LiteralPath ' + (ConvertTo-PowerShellLiteral $testRoot)
            } else {
                'New-PSDrive -Name T08Out -PSProvider FileSystem -Root ' + (ConvertTo-PowerShellLiteral $realParent) + ' | Out-Null'
            }
            $body = @('$global:LASTEXITCODE = 0',
                $destinationSetup,
                ('$lines = @(& ' + (ConvertTo-PowerShellLiteral $scriptCopy) + ' -InputFolder ' + (ConvertTo-PowerShellLiteral $inputRoot) + ' -OutputParent ' + (ConvertTo-PowerShellLiteral $parentSpelling) + ' *>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { [string]$_ } })'),
                'if ($global:LASTEXITCODE -ne 0) { throw (''Entry failed: '' + ($lines -join "`n")) }',
                '$roots = @($lines | ForEach-Object { if ($_ -match ''^\[INFO\] Output root\s+: (.+)$'') { $Matches[1].Trim() } })',
                'if ($roots.Count -ne 1) { throw ''Entry must report exactly one owned root.'' }',
                '$marker = [IO.File]::ReadAllText((Join-Path $roots[0] ''.AudioFileForPhone-output.json'')) | ConvertFrom-Json',
                '[pscustomobject]@{ OutputRoot = $roots[0]; LogPath = (Join-Path $roots[0] ''AudioFileForPhone_log.txt''); OwnerToken = $marker.ownership_token; text = ($lines -join "`n") }'
            ) -join "`n"
            $batch += Start-BarrierChild $label $readyName $releaseName $body
        }
        Wait-BarrierReady $readyHandles
        $null = $release.Set()
        $results = @($batch | ForEach-Object { Complete-BarrierChild $_ })
        Assert-True ($results[0].OutputRoot -ine $results[1].OutputRoot -and $results[0].OwnerToken -cne $results[1].OwnerToken) 'Simultaneously released entry invocations must own distinct roots, logs and tokens.'
        foreach ($reservation in $results) {
            Assert-ReservationIdentity $reservation $realParent -Register
            $audio = @(Get-SafeTree $reservation.OutputRoot | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
            Assert-True ($audio.Count -eq 1 -and $audio[0].FullName -ceq (Join-Path $reservation.OutputRoot 'S\2024-01-02 - Synthetic.mp3')) 'Each entry must produce only its own expected relative output.'
            Assert-Mp3Decoded $audio[0].FullName
            $log = [IO.File]::ReadAllText($reservation.LogPath)
            Assert-True ($log.Contains('Output root   : ' + $reservation.OutputRoot) -and $log.Contains('Input folder  : ' + $inputRoot)) 'Each entry log must describe only its exact own root/input.'
            $other = @($results | Where-Object { $_.OutputRoot -ine $reservation.OutputRoot })[0]
            $otherRootPattern = [regex]::Escape($other.OutputRoot) + '(?=[\\/''"\r\n]|$)'
            Assert-True (-not [regex]::IsMatch($log, $otherRootPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) 'Concurrent logs must not contain a path belonging to the other run.'
        }
        $case['processes'] = 2; $case['all_ready_before_release'] = $true; $case['timing_sleeps'] = 0
        $case['distinct_roots_and_logs'] = $true; $case['real_outputs_fully_decoded'] = 2
        $case['successful_parent_forms'] = @('relative .\P at owned root', 'process-local FileSystem PSDrive T08Out:\')
        $case['wall_clock_timestamp_equality_required'] = $false
    }
    Invoke-Case 'all returned marked suffix runs recognized and excluded from later discovery' 'A22,A23' {
        param($case)
        $snapshot = Get-AudioInputSnapshot -InputFolder $testRoot -OutputRoot (Join-Path $testRoot 'future\run')
        foreach ($reservation in $ownedRuns) {
            Assert-True (@($snapshot.Skipped | Where-Object { $_.Path -ieq $reservation.OutputRoot -and $_.Reason -match 'generated|output' }).Count -eq 1) 'Every actual owned root, including numeric suffixes, must be excluded by its valid marker.'
        }
        Assert-True (@($snapshot.Files | Where-Object { $_.FullName -ieq $sourceAudio }).Count -eq 1 -and
            @($snapshot.Files | Where-Object { $_.FullName -ieq $nestedAudio }).Count -eq 1) 'Original and unmarked prior source audio must remain eligible.'
        $case['recognized_owned_runs'] = $ownedRuns.Count; $case['original_and_unmarked_audio_retained'] = $true
    }
    $report.status = 'pass'; $exitCode = 0
}
catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    $allChildrenStopped = $true
    foreach ($child in $children) {
        try {
            if (-not $child.process.HasExited) {
                # Release any still-waiting owned child; wait for its short work
                # instead of deleting a tree a conversion could still be writing.
                foreach ($handle in $events) { $null = $handle.Set() }
                Assert-True ($child.process.WaitForExit(60000)) 'Owned child still running; preserve the exact test root for inspection.'
            }
            $null = $child.stdout_task.GetAwaiter().GetResult(); $null = $child.stderr_task.GetAwaiter().GetResult()
            $child.process.Dispose()
        }
        catch { $allChildrenStopped = $false; $report['child_cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    foreach ($handle in $events) { $handle.Dispose() }
    $report.children_disposed = $allChildrenStopped
    $aclRestoreSuccess = $true
    foreach ($saved in $savedAcls) {
        try {
            Assert-NoReparse $saved.path; Set-Acl -LiteralPath $saved.path -AclObject $saved.acl
            $saved.restored = (Get-Acl -LiteralPath $saved.path).Sddl -ceq $saved.sddl
            Assert-True $saved.restored 'Owned fixture ACL must be restored exactly before cleanup.'
        }
        catch { $aclRestoreSuccess = $false; $report['acl_restore_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    $report.acls_restored = $aclRestoreSuccess
    if (-not $allChildrenStopped -or -not $aclRestoreSuccess) { $report.status = 'fail'; $exitCode = 1 }
    foreach ($inventory in @('source', 'synthetic')) {
        try {
            $after = if ($inventory -eq 'source') { Get-SourceInventory } else { Get-FixtureInventory }
            $report[$inventory + '_after'] = $after
            $same = (($report[$inventory + '_before'] | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress))
            $report[$inventory + '_unchanged'] = $same; Assert-True $same "$inventory SHA-256 inventory must remain unchanged."
        }
        catch { $report.status = 'fail'; $exitCode = 1; $report[$inventory + '_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    try {
        if ($ownedRootCreated -and $allChildrenStopped -and $aclRestoreSuccess -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay inside the exact exclusively reserved TEMP root.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact create-new owner token from this invocation.'
            foreach ($reservation in $ownedRuns) { Assert-ReservationIdentity $reservation $reservation.parent }
            Get-SafeTree $resolved | Out-Null
            [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'
    }
    catch {
        $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
        $report['cleanup_error_location'] = $_.ScriptStackTrace.Replace($testRoot, '<OWNED_TEMP>')
    }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    $bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 14))
    $stream = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
Write-Host "T08 reservation: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); ACL=$($report.acls_restored); cleanup=$($report.cleanup_verified); source/synthetic unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
