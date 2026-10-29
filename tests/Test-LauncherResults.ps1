<#
T10 real cmd.exe tests of the byte-identical BAT and an inert capture/exit child.
Both installed PowerShell branches run with an explicit process-local host choice. No
application script, FFmpeg, Music resolver or personal media is executed/read.
Percent paths are supplied through one caller environment expansion; this tests
what BAT receives, not recovery of paths already expanded by an earlier caller.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$productionBat = Join-Path $projectRoot 'AudioFileForPhone.bat'
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
$activeEvidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1.0.1/evidence')).TrimEnd('\', '/')
$isActiveEvidence = (Split-Path -Parent $evidenceFullPath) -ieq $activeEvidenceParent -and
    (Split-Path -Leaf $evidenceFullPath) -match '^S08-launcherresults-(ps51|ps7)-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$'
if ($isActiveEvidence) { $evidenceParent = $activeEvidenceParent }
elseif ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T10|T11|T15|T16)-launcher-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw 'EvidencePath must name fresh historical T10/T11/T15/T16-launcher-ps51/ps7-attempt/finalN.json or active S08-launcherresults-ps51/ps7-attemptN/finalN/runID_attempt.json in the corresponding evidence parent.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'T10-launcher-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t10-launcher-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$childrenReleased = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$systemDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
$cmdPath = Join-Path $systemDirectory 'cmd.exe'
$windowsPsPath = Join-Path $systemDirectory 'WindowsPowerShell\v1.0\powershell.exe'
$pwshPath = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'bat_result_argument_contract'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    source_before = @(); source_after = @(); source_unchanged = $false
    fixtures_before = @(); fixtures_after = @(); fixtures_unchanged = $false
    copied_bats_byte_identical = $false; temp_exclusively_reserved = $false; marker_create_new = $false
    owned_temp_root_name = $testName; music_resolver_or_media_access = $false
    exercised_shells = @(); cases = @(); children_disposed = $false; cleanup_verified = $false
    caller_path_transport = 'cmd /d /v:off /s /c; percent-bearing arguments and launcher paths use one environment substitution, with a defined percent sentinel proving no recursive BAT expansion'
    limitations = @('Cannot recover a path expanded or altered by a previous caller. Direct literal percent-variable input is explicitly characterized as caller expansion.', 'No Explorer drag/drop, interactive keypress, phone, audio, forced termination or controlled application cancellation acceptance is claimed. Code 130 is an inert child exit forwarding test.')
    status = 'fail'; error = $null
}

function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
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
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside the exact launcher cleanup scope.'
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @('AudioFileForPhone.bat', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'tests/Test-LauncherResults.ps1' | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

$stub = @'
[CmdletBinding()]
param([string]$InputFolder, [switch]$Interactive)
$ErrorActionPreference = 'Stop'
$capture = [IO.Path]::GetFullPath($env:AUDIOPHONE_T10_CAPTURE)
$ownedRoot = [IO.Path]::GetFullPath($env:AUDIOPHONE_T10_ROOT).TrimEnd('\', '/')
if ((Split-Path -Parent $capture) -ine $ownedRoot -or
    (Split-Path -Leaf $capture) -notmatch '^capture-[a-z0-9-]+\.json$' -or
    [IO.File]::ReadAllText((Join-Path $ownedRoot '.t10-launcher-owner')) -cne $env:AUDIOPHONE_T10_TOKEN) {
    throw 'Capture destination must belong to the launcher fixture.'
}
$record = [ordered]@{
    input_folder = $InputFolder; interactive = [bool]$Interactive
    extra_arguments = @($args | Where-Object { $null -ne $_ })
    shell_version = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    host_path = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    host_is_64_bit = [Environment]::Is64BitProcess; os_is_64_bit = [Environment]::Is64BitOperatingSystem
    apartment_state = [Threading.Thread]::CurrentThread.ApartmentState.ToString()
    requested_exit = [int]$env:AUDIOPHONE_T10_EXIT
}
$stream = New-Object IO.FileStream($capture, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $bytes = [Text.Encoding]::UTF8.GetBytes(($record | ConvertTo-Json -Depth 5)); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
exit ([int]$env:AUDIOPHONE_T10_EXIT)
'@

function Invoke-LauncherCase {
    param([string]$Name, [hashtable]$Shell, [string]$Bat, [string[]]$Folders,
        [int]$ChildExit = 0, [bool]$Invalid = $false, [string]$Transport = 'environment', [string]$ExpectedInput)
    $case = [ordered]@{
        name = $Shell.name + '-' + $Name; acceptance_case = 'A28'; status = 'fail'
        shell_branch = $Shell.name; supplied_argument_count = $Folders.Count; requested_child_exit = $ChildExit
        transport = $Transport; bat_relative_path = $Bat.Substring($testRoot.Length + 1)
        expected_input_relative_path = $null; bat_exit = $null; capture = $null; stdout = $null; stderr = $null
        pause_seen = $false; process_disposed = $false
    }
    $process = $null
    try {
        $capturePath = Join-Path $testRoot ('capture-' + $case.name + '.json')
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $cmdPath
        $commandText = '"%AUDIOPHONE_T10_BAT%"'
        for ($i = 0; $i -lt $Folders.Count; $i++) {
            if ($Folders[$i].Length -eq 0) { $commandText += ' ""' }
            elseif ($Transport -eq 'direct-literal-caller-expansion') { $commandText += ' "' + $Folders[$i] + '"' }
            else { $commandText += ' "%AUDIOPHONE_T10_ARG' + $i + '%"' }
            $startInfo.EnvironmentVariables['AUDIOPHONE_T10_ARG' + $i] = $Folders[$i]
        }
        $startInfo.Arguments = '/d /v:off /s /c "' + $commandText + '"'
        $startInfo.WorkingDirectory = $testRoot
        $startInfo.UseShellExecute = $false; $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true; $startInfo.RedirectStandardOutput = $true; $startInfo.RedirectStandardError = $true
        $startInfo.EnvironmentVariables['PATH'] = $Shell.path
        $startInfo.EnvironmentVariables['AUDIOFILEFORPHONE_HOST'] = $Shell.host_path
        $startInfo.EnvironmentVariables['PATHEXT'] = '.COM;.EXE;.BAT;.CMD'
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_BAT'] = $Bat
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_CAPTURE'] = $capturePath
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_ROOT'] = $testRoot
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_TOKEN'] = $ownerToken
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_EXIT'] = [string]$ChildExit
        $startInfo.EnvironmentVariables['AUDIOPHONE_T10_PERCENT_SENTINEL'] = 'CALLER_EXPANDED'
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $startInfo
        Assert-True ($process.Start()) 'Owned cmd launcher did not start.'
        $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.WriteLine(''); $process.StandardInput.Close()
        if (-not $process.WaitForExit(30000)) {
            $script:childrenReleased = $false
            $process.Kill()
            $cmdStopped = $process.WaitForExit(5000)
            throw ('Inert launcher exceeded 30 seconds; stopped only this owned cmd process, exit proved=' + $cmdStopped + '. Child exit unproved; cleanup refused.')
        }
        if (-not ($stdoutTask.Wait(10000) -and $stderrTask.Wait(10000))) {
            $script:childrenReleased = $false
            throw 'Owned process pipes did not close after cmd exit. Child release unproved; cleanup refused.'
        }
        $case.bat_exit = $process.ExitCode
        $case.stdout = $stdoutTask.GetAwaiter().GetResult().Trim(); $case.stderr = $stderrTask.GetAwaiter().GetResult().Trim()
        $case.pause_seen = $case.stdout.Contains('Press any key')
        Assert-True (-not $case.pause_seen) 'Redirected input must return without an endless mandatory pause.'
        Assert-True ([string]::IsNullOrWhiteSpace($case.stderr)) ('Unexpected launcher stderr: ' + $case.stderr)
        if (Test-Path -LiteralPath $capturePath) { $case.capture = Get-Content -LiteralPath $capturePath -Raw -Encoding UTF8 | ConvertFrom-Json }
        if ($Invalid) {
            Assert-True ($case.bat_exit -eq 1 -and $null -eq $case.capture -and $case.stdout.Contains('Drag exactly one folder')) 'Invalid arguments must clearly reject before application entry and exit 1.'
        }
        else {
            if ([string]::IsNullOrEmpty($ExpectedInput)) { $ExpectedInput = $Folders[0] }
            $case.expected_input_relative_path = $ExpectedInput.Substring($testRoot.Length + 1)
            Assert-True ($null -ne $case.capture) 'Inert capture child did not run.'
            Assert-True ($case.bat_exit -eq $ChildExit) 'Child exit must survive BAT reporting exactly.'
            Assert-True ($case.capture.input_folder -ceq $ExpectedInput -and $case.capture.interactive -and @($case.capture.extra_arguments).Count -eq 0) 'BAT must forward exactly the received folder plus Interactive without changing spelling.'
            Assert-True ($case.capture.apartment_state -ceq 'STA' -and $case.capture.shell_edition -ceq $Shell.edition -and $case.capture.requested_exit -eq $ChildExit -and
                $case.capture.host_path -ieq $Shell.host_path -and $case.capture.host_is_64_bit -and $case.capture.os_is_64_bit) 'The intended exact x64 PowerShell host must run STA and return the requested code.'
            $message = switch ($ChildExit) {
                0 { 'Completed. Check the output and log paths printed above.' }
                1 { 'Failed. Review the error and any output or log paths printed above.' }
                2 { 'Completed with failures. Review the output and log paths printed above.' }
                130 { 'Cancelled. Completed outputs are preserved; review the paths printed above.' }
                default { 'Failed with exit code ' + $ChildExit + '. Review the error printed above.' }
            }
            Assert-True ($case.stdout.Contains($message) -and -not $case.stdout.Contains('Done.')) 'BAT must print the truthful code-specific outcome.'
            if ($ChildExit -ne 0) { Assert-True (-not $case.stdout.Contains('Completed. Check')) 'A failed child must never display the all-success result.' }
        }
        $case.status = 'pass'
    }
    finally {
        if ($null -ne $process) { $process.Dispose(); $case.process_disposed = $true }
        $report.cases += [pscustomobject]$case
    }
}

try {
    Assert-NoReparse $tempParent; Assert-NoReparse $evidenceParent
    Assert-True ([IO.File]::Exists($pwshPath) -and [IO.File]::Exists($windowsPsPath) -and [IO.File]::Exists($cmdPath)) 'Both installed real PowerShell executables and cmd.exe are required.'
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhoneT10Launcher {
    public static class NativeFixture {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr security);
    }
}
'@
    Assert-True ([AudioFileForPhoneT10Launcher.NativeFixture]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Launcher TEMP root must be exclusively created.'
    $ownedRootCreated = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $report.source_before = Get-SourceInventory
    $locationNames = @('normal', 'space location', 'bang! location', 'percent %AUDIOPHONE_T10_PERCENT_SENTINEL% location', 'ampersand & location', 'caret ^ location', "apostrophe's location", "all ! %AUDIOPHONE_T10_PERCENT_SENTINEL% & ^ apostrophe's space", 'brackets [literal] (parentheses)', ('Suomi ' + [char]0xE4 + ' Deutsch ' + [char]0xFC), ('decomposed e' + [char]0x301))
    $batCopies = @()
    foreach ($location in $locationNames) {
        $directory = Join-Path $testRoot $location
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $bat = Join-Path $directory 'AudioFileForPhone.bat'
        Copy-Item -LiteralPath $productionBat -Destination $bat
        $child = Join-Path $directory 'AudioFileForPhone.ps1'
        Write-NewText $child $stub
        $fixtures.Add($bat); $fixtures.Add($child); $batCopies += $bat
        foreach ($runtimeName in @('AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
            $runtimeCopy = Join-Path $directory $runtimeName
            Copy-Item -LiteralPath (Join-Path $projectRoot $runtimeName) -Destination $runtimeCopy
            $fixtures.Add($runtimeCopy)
        }
        Assert-True ((Get-FileHash -LiteralPath $bat).Hash -ceq (Get-FileHash -LiteralPath $productionBat).Hash) 'Every exercised BAT must be byte-identical to production.'
    }
    $report.copied_bats_byte_identical = $true
    $inputNames = @('folder with spaces', 'bang! folder', 'percent %AUDIOPHONE_T10_PERCENT_SENTINEL% folder', 'ampersand & folder', 'caret ^ folder', "apostrophe's folder", "all ! %AUDIOPHONE_T10_PERCENT_SENTINEL% & ^ apostrophe's space", 'brackets [literal] (parentheses)', ('Suomi ' + [char]0xE4 + ' Deutsch ' + [char]0xFC), ('decomposed e' + [char]0x301))
    $inputFolders = @($inputNames | ForEach-Object { $directory = Join-Path $testRoot $_; [IO.Directory]::CreateDirectory($directory) | Out-Null; $directory })
    $report.fixtures_before = Get-FixtureInventory
    $shells = @(
        @{ name = 'pwsh'; edition = 'Core'; host_path = $pwshPath; path = (Split-Path -Parent $pwshPath) + ';' + $systemDirectory + ';' + (Split-Path -Parent $windowsPsPath) },
        @{ name = 'ps51-explicit'; edition = 'Desktop'; host_path = $windowsPsPath; path = $systemDirectory + ';' + (Split-Path -Parent $windowsPsPath) }
    )
    foreach ($shell in $shells) {
        Invoke-LauncherCase 'no-argument' $shell $batCopies[0] @() -Invalid $true
        Invoke-LauncherCase 'empty-only' $shell $batCopies[0] @('') -Invalid $true
        Invoke-LauncherCase 'multiple-folders' $shell $batCopies[0] @($inputFolders[0], $inputFolders[1]) -Invalid $true
        Invoke-LauncherCase 'empty-first-extra' $shell $batCopies[0] @('', $inputFolders[0]) -Invalid $true
        Invoke-LauncherCase 'empty-second-extra' $shell $batCopies[0] @($inputFolders[0], '') -Invalid $true
        Invoke-LauncherCase 'empty-second-third-extra' $shell $batCopies[0] @($inputFolders[0], '', $inputFolders[1]) -Invalid $true
        foreach ($code in @(0, 1, 2, 130, 37)) { Invoke-LauncherCase ('exit-' + $code) $shell $batCopies[0] @($inputFolders[0]) -ChildExit $code }
        for ($i = 0; $i -lt $inputFolders.Count; $i++) { Invoke-LauncherCase ('input-form-' + $i) $shell $batCopies[0] @($inputFolders[$i]) }
        Invoke-LauncherCase 'input-trailing-separator' $shell $batCopies[0] @($inputFolders[0] + '\')
        for ($i = 1; $i -lt $batCopies.Count; $i++) { Invoke-LauncherCase ('script-location-form-' + $i) $shell $batCopies[$i] @($inputFolders[6]) }
        $expandedInput = $inputFolders[2].Replace('%AUDIOPHONE_T10_PERCENT_SENTINEL%', 'CALLER_EXPANDED')
        Invoke-LauncherCase 'caller-percent-expansion-characterized' $shell $batCopies[0] @($inputFolders[2]) -Transport 'direct-literal-caller-expansion' -ExpectedInput $expandedInput
    }
    $report.exercised_shells = @($report.cases | Where-Object { $null -ne $_.capture } | ForEach-Object { $_.capture.shell_edition + ' ' + $_.capture.shell_version } | Sort-Object -Unique)
    $report.status = 'pass'
}
catch { $report.error = $_.Exception.Message; Write-Warning $report.error }
finally {
    $report.source_after = Get-SourceInventory
    $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
    if (-not $report.source_unchanged) { $report.status = 'fail'; $report.error = 'BAT or launcher harness bytes changed during execution.' }
    if ($ownedRootCreated) {
        $report.fixtures_after = Get-FixtureInventory
        $report.fixtures_unchanged = (($report.fixtures_before | ConvertTo-Json -Compress) -ceq ($report.fixtures_after | ConvertTo-Json -Compress))
        if (-not $report.fixtures_unchanged) { $report.status = 'fail'; $report.error = 'Inert launcher fixtures changed during execution.' }
        if ($childrenReleased) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and
                (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Refusing cleanup outside this exact token-owned launcher root.'
            Get-SafeTree $resolved | Out-Null
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
    }
    $report.children_disposed = $childrenReleased -and @($report.cases | Where-Object { -not $_.process_disposed }).Count -eq 0
    if (-not $report.children_disposed -or -not $report.cleanup_verified) { $report.status = 'fail' }
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 18)
}
if ($report.status -eq 'pass') { Write-Host ('Launcher results: ' + $report.cases.Count + ' cmd cases passed across explicitly selected real PS7 and PS5.1.'); exit 0 }
exit 1
