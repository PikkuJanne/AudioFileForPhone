<#
S10 real Windows support/check/startup tests. All mutable configuration, startup
records, exports, synthetic media and copied packages remain in one exclusively
reserved token-owned TEMP tree. Ordinary Music and owner configuration are never
opened. Pure failure substitutions are identified separately from native checks.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -ceq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
if ($evidenceParent -ine (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -or
    $leaf -cnotmatch "^S10-support-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$") {
    throw 'Use a fresh S10-support report for this host in the active evidence directory.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; choose a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S10-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s10-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'Collections.Generic.List[string]'
$nativeRuns = New-Object 'Collections.Generic.List[object]'
$runtimePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1',
    'AudioFileForPhone.Checks.ps1', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1',
    'AudioFileForPhone.bat', 'Check-AudioFileForPhone.ps1', 'Check-AudioFileForPhone.bat',
    'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ManagedSetup.ps1')
$sourcePaths = $runtimePaths + @('tests/Test-SupportDiagnostics.ps1')
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'S10'; mode = 'real_windows_environment_check_selftest_early_failure_and_support_export'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; persistent_environment_writes = $false; automatic_uploads = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; descendant_release_proved = $false; cleanup_verified = $false
    tools = @(); native_runs = @(); cases = @(); status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'Collections.Generic.Stack[string]'; $items = New-Object 'Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$NoBom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding(-not $NoBom.IsPresent); $preamble = $encoding.GetPreamble()
        $stream.Write($preamble, 0, $preamble.Length); $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Add-Fixture { param([string]$Path); $fixtures.Add($Path); $report.synthetic_before += Get-Inventory @($Path) $testRoot }
function Get-Literal { param([AllowEmptyString()][string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Get-TreeState {
    param([string[]]$Roots)
    $rows = @()
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { $rows += $root + '|ABSENT'; continue }
        $rows += $root + '|DIRECTORY'
        foreach ($item in @(Get-SafeTree $root | Sort-Object FullName)) {
            $rows += if ($item.PSIsContainer) { $item.FullName + '|DIRECTORY' } else { $item.FullName + '|' + (Get-FileHash -LiteralPath $item.FullName).Hash }
        }
    }
    return $rows | ConvertTo-Json -Compress
}
function New-AppCopy {
    param([string]$Name, [string]$Missing = '')
    $directory = New-Directory $Name
    foreach ($relative in $runtimePaths) {
        if ($relative -ceq $Missing) { continue }
        $copy = Join-Path $directory $relative
        [IO.File]::Copy((Join-Path $projectRoot $relative), $copy, $false)
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $relative)).Hash) 'Copied runtime must be byte-identical.'
        Add-Fixture $copy
    }
    return $directory
}
function Invoke-Child {
    param([string]$Label, [string]$Code, [hashtable]$EnvironmentValues = @{}, [int]$DeadlineMilliseconds = 120000)
    $driver = Join-Path $testRoot ($Label + '-driver.ps1')
    $loader = Join-Path $testRoot ($Label + '-environment-loader.ps1')
    # Do not change copied runtime bytes or depend on desktop saved settings in
    # missing-tool tests. Replace only the read-only environment seam at load.
    $loaderCode = @'
. $global:S10OriginalEnvironmentHelper
function Get-AudioEnvironmentSetting {
    param([string]$Name, [string]$Target = 'Process')
    if ($Name -ieq 'Path' -and $Target -eq 'Process') { return $env:PATH }
    return $null
}
'@
    Write-NewText $loader $loaderCode; Add-Fixture $loader
    $prefix = @('$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''',
        '[Console]::InputEncoding=New-Object Text.UTF8Encoding($false); [Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        '$env:PSModulePath=(Join-Path $PSHOME ''Modules'')+'';''+$env:PSModulePath',
        ('$global:S10EnvironmentLoader=' + (Get-Literal $loader)),
        @'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($ChildPath -ceq 'AudioFileForPhone.Helpers.ps1' -and [IO.File]::Exists($actual)) {
        $global:S10OriginalEnvironmentHelper=$actual
        return $global:S10EnvironmentLoader
    }
    return $actual
}
'@)
    Write-NewText $driver (($prefix + $Code) -join "`r`n"); Add-Fixture $driver
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $shellPath; $info.WorkingDirectory = $testRoot
    $info.Arguments = (@('-NoLogo', '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'RemoteSigned', '-File', $driver) | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false); $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    foreach ($name in @($info.EnvironmentVariables.Keys)) {
        if ([string]$name -like 'AUDIOFILEFORPHONE_*') { $info.EnvironmentVariables.Remove($name) }
    }
    $info.EnvironmentVariables['LOCALAPPDATA'] = $localData
    $info.EnvironmentVariables['TEMP'] = $childTemp; $info.EnvironmentVariables['TMP'] = $childTemp
    $info.EnvironmentVariables['PATH'] = $emptyPath
    foreach ($name in $EnvironmentValues.Keys) { $info.EnvironmentVariables[$name] = [string]$EnvironmentValues[$name] }
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info; $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        Assert-True $process.Start() 'Owned support child did not start.'
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($DeadlineMilliseconds)) {
            $script:releaseProved = $false; $process.Kill(); $process.WaitForExit(5000) | Out-Null
            throw 'Owned support child exceeded deadline; descendant release unproved, fixtures retained.'
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)) {
            $script:releaseProved = $false; throw 'Owned support child pipe remains held; retaining owned fixtures.'
        }
        $result = [pscustomobject]@{ exit_code = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result; elapsed_ms = $timer.ElapsedMilliseconds; process_released = $true; pipe_drain_completed = $true }
        $nativeRuns.Add([pscustomobject]@{ operation = $Label; status = 'Completed'; exit_code = $result.exit_code; elapsed_ms = $result.elapsed_ms; process_released = $true; pipe_drain_completed = $true })
        return $result
    } finally { $timer.Stop(); $process.Dispose() }
}
function Assert-ChildExit {
    param([object]$Result, [int]$Code)
    Assert-True ($Result.exit_code -eq $Code) ('Unexpected child exit ' + $Result.exit_code + ' expected ' + $Code + ': ' + $Result.stdout + ' ' + $Result.stderr)
}
function Read-CheckResult {
    param([object]$Result)
    $summaryMatches = [regex]::Matches($Result.stdout, '(?m)^\[CHECK_RESULT\] (.+)\r?$')
    Assert-True ($summaryMatches.Count -eq 1) ('Expected one stable check result marker: ' + $Result.stdout)
    return $summaryMatches[0].Groups[1].Value | ConvertFrom-Json
}
function Invoke-Check {
    param([string]$Label, [string]$Arguments = '', [string]$AppDirectory = $appRoot)
    return Invoke-Child $Label ('& ' + (Get-Literal (Join-Path $AppDirectory 'Check-AudioFileForPhone.ps1')) + ' -ConfigPath ' + (Get-Literal $configPath) + ' ' + $Arguments + "`r`nexit `$LASTEXITCODE")
}
function Read-StartupRecord {
    param([object]$Result, [string[]]$StorageRoots)
    $paths = @()
    foreach ($root in $StorageRoots) {
        if ([IO.Directory]::Exists($root)) { $paths += @(Get-SafeTree $root | Where-Object { -not $_.PSIsContainer -and $_.Name -cmatch '^failure-[a-f0-9]{32}\.json$' } | ForEach-Object { $_.FullName }) }
    }
    Assert-True ($paths.Count -eq 1) ('Expected one early failure record: ' + $Result.stdout + ' ' + $Result.stderr)
    $item = Get-Item -LiteralPath $paths[0]
    Assert-True ($item.Length -gt 0 -and $item.Length -le 65536) 'Early failure JSON must be bounded to 64 KiB.'
    $record = Get-Content -LiteralPath $paths[0] -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($record.kind -ceq 'AudioFileForPhone.Diagnostic' -and $record.schema_version -eq 1) 'Early failure requires the stable diagnostic schema.'
    Assert-True ($record.privacy -match 'PRIVATE' -and $Result.stdout -match 'PRIVATE local report') 'Local detailed reports must be visibly labelled private.'
    Assert-True ($record.host.version -ceq $PSVersionTable.PSVersion.ToString() -and $record.host.process_x64 -and $record.host.os_version) 'Early failure must retain actual host and OS identity.'
    Assert-True ($record.log_path -ceq $paths[0] -and $record.totals.exit_code -eq 1 -and $record.totals.converted -eq 0) 'Startup record must disclose its path and honest pre-conversion result.'
    return $record
}
try {
    Assert-NoReparse $tempParent; Assert-NoReparse $evidenceParent
    Assert-True ([Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) 'S10 client tests require x64.'
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Run the harness with an explicit UTF8 CP65001 outer driver.'
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    . (Join-Path $projectRoot 'AudioFileForPhone.Diagnostics.ps1')
    . (Join-Path $projectRoot 'AudioFileForPhone.Checks.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Exact TEMP root must be exclusively reserved.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new = $true
    $localData = New-Directory 'LocalData'; $childTemp = New-Directory 'Temp'; $emptyPath = New-Directory 'EmptyPath'
    $configRoot = New-Directory 'Config [literal]'; $configPath = Join-Path $configRoot 'absent.json'
    $outputRoot = Join-Path $testRoot 'OutputMustRemainAbsent'
    $appRoot = New-AppCopy 'App [literal]'
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    Assert-True ((Split-Path -Parent $ffmpeg) -ieq (Split-Path -Parent $ffprobe)) 'Harness requires one supplied existing FFmpeg pair directory.'
    $toolDirectory = Split-Path -Parent $ffmpeg
    foreach ($path in @($ffmpeg, $ffprobe)) { Assert-NoReparse $path; $report.tools += [pscustomobject]@{ name = Split-Path -Leaf $path; sha256 = (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() } }
    $explicit = '-FfmpegDirectory ' + (Get-Literal $toolDirectory)

    Invoke-Case 'check-default-success-executes-selected-tools-without-writes' 'S10-A2/S10-A3' {
        param($case)
        $roots = @($appRoot, $localData, $childTemp, $configRoot, $outputRoot)
        $before = Get-TreeState $roots
        $result = Invoke-Check 'check-good' $explicit; Assert-ChildExit $result 0
        $summary = Read-CheckResult $result
        Assert-True ($summary.exit_code -eq 0 -and $summary.code -ceq 'EnvironmentReady') 'Default check must report validated ready status.'
        Assert-True ($result.stdout -match 'execut|binar' -and $result.stdout -match 'ffmpeg|FFmpeg') 'Default check must disclose native execution and selected dependency checks.'
        Assert-True ((Get-TreeState $roots) -ceq $before) 'Default environment check must not write media, settings, diagnostics or output.'
        $case.result = $summary; $case.no_write_verified = $true; $case.real_native_checks = $true
    }
    Invoke-Case 'accessible-check-bat-forwards-exits-without-redirected-pause' 'S10-A1/S10-A2' {
        param($case)
        # The byte-identical BAT is exercised with an inert owned Check script.
        # Actual production checking/self-test is covered by the PS1 cases with
        # explicit owned ConfigPath. The BAT offers no ConfigPath override, so an
        # actual default call here could read the owner's SpecialFolder config.
        $copy = New-AppCopy 'BAT-stub' 'Check-AudioFileForPhone.ps1'
        $stub = Join-Path $copy 'Check-AudioFileForPhone.ps1'
        Write-NewText $stub "[Console]::OutputEncoding=New-Object Text.UTF8Encoding(`$false)`r`nWrite-Host '[BAT_STUB] inert check entered'`r`nexit ([int]`$env:AFP_S10_EXIT)"; Add-Fixture $stub
        $cmdDriver = Join-Path $testRoot 'check-bat-driver.cmd'
        Write-NewText $cmdDriver "@echo off`r`nsetlocal DisableDelayedExpansion`r`nchcp 65001 >nul`r`n`"%AFP_S10_BAT%`"`r`nexit /b %ERRORLEVEL%`r`n" -NoBom; Add-Fixture $cmdDriver
        foreach ($code in @(0, 1, 130)) {
            $scriptText = '& $env:ComSpec /d /v:off /c ' + (Get-Literal $cmdDriver) + "`r`nexit `$LASTEXITCODE"
            $result = Invoke-Child ('check-bat-' + $code) $scriptText @{ AFP_S10_EXIT = [string]$code; AFP_S10_BAT = Join-Path $copy 'Check-AudioFileForPhone.bat' }
            Assert-ChildExit $result $code
            Assert-True ($result.stdout -match '\[BAT_STUB\]' -and $result.stdout -notmatch 'Press any key') 'Accessible check BAT must enter once and never require redirected pause input.'
        }
        $case.inert_check_child = $true; $case.real_environment_check_evidence = $false; $case.exit_codes = @(0, 1, 130)
    }
    Invoke-Case 'check-missing-dependencies-is-console-only-and-actionable' 'S10-A1/S10-A2/S10-A3' {
        param($case)
        $roots = @($appRoot, $localData, $childTemp, $configRoot, $outputRoot); $before = Get-TreeState $roots
        $result = Invoke-Check 'check-missing'; Assert-ChildExit $result 1; $summary = Read-CheckResult $result
        Assert-True ($summary.code -ceq 'DependencyMissing') 'Missing production selection needs the stable DependencyMissing code.'
        Assert-True ($result.stdout -match 'Setup-AudioFileForPhone|FfmpegDirectory') 'Missing dependency check must name a concrete repair command.'
        Assert-True ((Get-TreeState $roots) -ceq $before) 'Failed default check must remain console-only.'
        $case.result = $summary; $case.no_write_verified = $true
    }
    Invoke-Case 'explicit-synthetic-selftest-converts-validates-hashes-and-cleans' 'S10-A2' {
        param($case)
        $before = Get-TreeState @($appRoot, $localData, $childTemp, $configRoot, $outputRoot)
        $result = Invoke-Check 'selftest-real' ($explicit + ' -SelfTest'); Assert-ChildExit $result 0
        $summary = Read-CheckResult $result
        Assert-True ($summary.self_test.source_unchanged -and $summary.self_test.cleanup_verified -and $summary.self_test.process_released) 'Real self-test must report unchanged source, validated native release and owned cleanup.'
        Assert-True ((Get-TreeState @($appRoot, $localData, $childTemp, $configRoot, $outputRoot)) -ceq $before) 'Explicit self-test must leave only its console result after owned cleanup.'
        Assert-True ($result.stdout -match '\[SELF_TEST\]') 'Explicit self-test has its own visible state.'
        $case.result = $summary; $case.real_conversion = $true; $case.cleanup_verified = $true
    }

    $inputRoot = New-Directory 'Input [literal]'
    $preflightSentinel = Join-Path $inputRoot '2026-10-28 - Preflight sentinel.mp3'
    # These preflight-only cases stop before media probing. This marker is not
    # presented as a valid converted audio fixture; the real self-test is above.
    Write-NewText $preflightSentinel 'S10 nonmedia preflight sentinel'; Add-Fixture $preflightSentinel
    foreach ($failure in @(
        @{ label = 'helper'; missing = 'AudioFileForPhone.Helpers.ps1'; code = 'HelperMissing'; cause = 'Required runtime file is missing'; console = 'Helpers.ps1' },
        @{ label = 'dependency'; missing = ''; code = 'DependencyMissing'; cause = 'Could not find ffmpeg'; console = 'ffmpeg.exe' },
        @{ label = 'config'; missing = ''; code = 'ConfigInvalid'; cause = 'Invalid tool configuration'; console = 'configuration' }
    )) {
        $failureSpec = $failure
        Invoke-Case ('converter-early-' + $failure.label + '-failure-persists-bounded-private-record') 'S10-A1' {
            param($case)
            $copy = New-AppCopy ('Failure-' + $failureSpec.label) $failureSpec.missing
            $local = New-Directory ('Local-' + $failureSpec.label); $temporary = New-Directory ('Temp-' + $failureSpec.label)
            $selectedConfig = $configPath
            if ($failureSpec.label -ceq 'config') {
                $selectedConfig = Join-Path $configRoot 'invalid.json'; Write-NewText $selectedConfig '{ this is invalid JSON'; Add-Fixture $selectedConfig
            }
            $code = '& ' + (Get-Literal (Join-Path $copy 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputRoot) +
                ' -OutputParent ' + (Get-Literal $outputRoot) + ' -ConfigPath ' + (Get-Literal $selectedConfig) + "`r`nexit `$LASTEXITCODE"
            $result = Invoke-Child ('early-' + $failureSpec.label) $code @{ LOCALAPPDATA = $local; TEMP = $temporary; TMP = $temporary }
            Assert-ChildExit $result 1
            $record = Read-StartupRecord $result @($local, $temporary)
            # PowerShell renders Write-Error differently between host editions,
            # wrapping sentences and inserting ANSI/gutter text. The private
            # record retains the exact cause; stderr must still show its fatal
            # classification and the specific failing component.
            $consoleTokens = [regex]::Replace(($result.stderr -replace '\x1b\[[0-?]*[ -/]*[@-~]', ''), '\s', '')
            Assert-True ($record.message.Contains($failureSpec.cause) -and $consoleTokens.Contains($failureSpec.console) -and $consoleTokens.Contains('FATAL')) ('Exact recorded cause and specific original console failure must remain visible. Record: ' + $record.message + '; stderr: ' + $result.stderr)
            Assert-True ($record.code -ceq $failureSpec.code -and $record.stage) 'Early failure must use the expected stable stage/code.'
            Assert-True ($record.repair -and -not (Test-Path -LiteralPath $outputRoot)) 'Startup failure must provide a repair and create no ordinary output root.'
            if ($failureSpec.label -cne 'helper') { Assert-True (@($record.discovery_attempts).Count -gt 0) 'Resolver failure must retain its bounded attempted-origin evidence.' }
            $case.code = $record.code; $case.stage = $record.stage; $case.bounded_bytes = $true; $case.no_output_root = $true
        }
    }
    Invoke-Case 'launcher-explicit-missing-host-preserves-refusal-and-report' 'S10-A1' {
        param($case)
        $local = New-Directory 'Local-host'; $temporary = New-Directory 'Temp-host'
        $missingHost = Join-Path $testRoot 'missing-host.exe'
        $code = '& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Launcher.ps1')) + ' -InputFolder ' + (Get-Literal $inputRoot) +
            ' -HostPath ' + (Get-Literal $missingHost) + "`r`nexit `$LASTEXITCODE"
        $result = Invoke-Child 'early-host' $code @{ LOCALAPPDATA = $local; TEMP = $temporary; TMP = $temporary }
        Assert-ChildExit $result 1
        $record = Read-StartupRecord $result @($local, $temporary)
        Assert-True ($record.code -ceq 'HostStartFailed' -and $record.stage -ceq 'HostSelection') 'Explicit missing host needs HostStartFailed at HostSelection.'
        Assert-True ($result.stdout -match 'No alternate host|No healthy supported|Host selection stopped') 'Host refusal must not start a fallback or hide its original cause.'
        Assert-True (-not (Test-Path -LiteralPath $outputRoot)) 'Failed host selection cannot create conversion output.'
        $case.code = $record.code; $case.stage = $record.stage
    }
    Invoke-Case 'startup-storage-local-failure-uses-unique-temp-fallback' 'S10-A1' {
        param($case)
        $blockedLocal = Join-Path $testRoot 'Local-is-file'; Write-NewText $blockedLocal 'storage blocker'; Add-Fixture $blockedLocal
        $temporary = New-Directory 'Temp-fallback'
        $code = '& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputRoot) +
            ' -OutputParent ' + (Get-Literal $outputRoot) + ' -ConfigPath ' + (Get-Literal $configPath) + "`r`nexit `$LASTEXITCODE"
        $result = Invoke-Child 'early-fallback' $code @{ LOCALAPPDATA = $blockedLocal; TEMP = $temporary; TMP = $temporary }
        Assert-ChildExit $result 1; $record = Read-StartupRecord $result @($temporary)
        Assert-True ($record.code -ceq 'DependencyMissing' -and [IO.Path]::GetDirectoryName($record.log_path).StartsWith($temporary + '\', [StringComparison]::OrdinalIgnoreCase)) 'Fallback report must stay in the supplied unique owned TEMP scope.'
        Assert-True ($result.stdout -match 'original console cause is unchanged' -or $result.stderr -match 'original console cause is unchanged') 'Storage fallback should disclose its independent storage failure.'
        $case.code = $record.code; $case.fallback_verified = $true
    }
    Invoke-Case 'both-startup-storage-locations-fail-with-original-cause-intact' 'S10-A1' {
        param($case)
        $blockedLocal = Join-Path $testRoot 'Both-local-is-file'; $blockedTemp = Join-Path $testRoot 'Both-temp-is-file'
        Write-NewText $blockedLocal 'local blocker'; Add-Fixture $blockedLocal
        Write-NewText $blockedTemp 'temp blocker'; Add-Fixture $blockedTemp
        $code = '& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputRoot) +
            ' -OutputParent ' + (Get-Literal $outputRoot) + ' -ConfigPath ' + (Get-Literal $configPath) + "`r`nexit `$LASTEXITCODE"
        $result = Invoke-Child 'early-no-storage' $code @{ LOCALAPPDATA = $blockedLocal; TEMP = $blockedTemp; TMP = $blockedTemp }
        Assert-ChildExit $result 1
        $text = $result.stdout + $result.stderr
        Assert-True ($text -match 'Could not find ffmpeg' -and $text -match 'DependencyMissing' -and $text -match 'original console cause is unchanged') 'Failed logging must preserve the useful original missing-dependency cause and stable code.'
        Assert-True ($text -notmatch 'PRIVATE local report' -and -not (Test-Path -LiteralPath $outputRoot)) 'Unavailable logging must not claim a saved report or create a run.'
        $case.original_cause_preserved = $true; $case.report_saved = $false
    }
    Invoke-Case 'dryrun-invalid-input-and-missing-helper-fail-with-no-writes' 'S10-A1/S10-A3' {
        param($case)
        $missingCopy = New-AppCopy 'Preview-missing-helper' 'AudioFileForPhone.Helpers.ps1'
        $before = Get-TreeState @($appRoot, $missingCopy, $localData, $childTemp, $configRoot, $outputRoot)
        foreach ($preview in @(
            @{ name = 'invalid'; app = $appRoot; input = (Join-Path $testRoot 'AbsentInput') },
            @{ name = 'helper'; app = $missingCopy; input = $inputRoot }
        )) {
            $code = '& ' + (Get-Literal (Join-Path $preview.app 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $preview.input) +
                ' -OutputParent ' + (Get-Literal $outputRoot) + ' -ConfigPath ' + (Get-Literal $configPath) + " -DryRun`r`nexit `$LASTEXITCODE"
            $result = Invoke-Child ('preview-failure-' + $preview.name) $code; Assert-ChildExit $result 1
            Assert-True (($result.stdout + $result.stderr) -match 'Preflight failed|Required runtime file') 'Preview failure must retain its original error.'
            Assert-True ($result.stdout -notmatch 'PRIVATE local report') 'DryRun errors cannot persist a private startup report.'
        }
        Assert-True ((Get-TreeState @($appRoot, $missingCopy, $localData, $childTemp, $configRoot, $outputRoot)) -ceq $before) 'Both DryRun failures must be application-read-only.'
        $case.no_write_verified = $true; $case.failure_count = 2
    }
    Invoke-Case 'check-missing-helper-bootstrap-does-not-load-converter-or-write' 'S10-A1/S10-A2' {
        param($case)
        $copy = New-AppCopy 'Check-missing-helper' 'AudioFileForPhone.Helpers.ps1'
        $before = Get-TreeState @($copy, $localData, $childTemp, $configRoot)
        $result = Invoke-Check 'check-no-helper' $explicit $copy; Assert-ChildExit $result 1
        $summary = Read-CheckResult $result
        Assert-True ($summary.code -ceq 'HelperMissing' -and ($result.stdout + $result.stderr) -match 'Helpers.ps1|complete application package') 'Check bootstrap must diagnose the absent production helper.'
        Assert-True ((Get-TreeState @($copy, $localData, $childTemp, $configRoot)) -ceq $before) 'Missing-helper check must remain console-only.'
        $case.result = $summary; $case.no_write_verified = $true
    }
    Invoke-Case 'check-corrupt-config-failure-preserves-config-and-writes-nothing' 'S10-A1/S10-A2/S10-A3' {
        param($case)
        $invalidConfig = Join-Path $configRoot 'invalid.json'
        $before = Get-TreeState @($appRoot, $localData, $childTemp, $configRoot, $outputRoot)
        $code = '& ' + (Get-Literal (Join-Path $appRoot 'Check-AudioFileForPhone.ps1')) + ' -ConfigPath ' + (Get-Literal $invalidConfig) + "`r`nexit `$LASTEXITCODE"
        $result = Invoke-Child 'check-config-invalid' $code; Assert-ChildExit $result 1; $summary = Read-CheckResult $result
        Assert-True ($summary.code -ceq 'ConfigInvalid') 'Default check must retain ConfigInvalid from production resolution.'
        Assert-True ((Get-TreeState @($appRoot, $localData, $childTemp, $configRoot, $outputRoot)) -ceq $before) 'Corrupt-config environment check must preserve all config and create no diagnostics.'
        $case.result = $summary; $case.no_write_verified = $true
    }
    Invoke-Case 'no-network-resolver-rejects-UNC-before-filesystem-or-native-access' 'S10-A2/S10-A3' {
        param($case)
        $savedConfig = Join-Path $configRoot 'unc-saved.json'
        Write-NewText $savedConfig (@{ schema_version = 1; ffmpeg_directory = '\\AFP-S10-not-contacted.invalid\share\tools' } | ConvertTo-Json); Add-Fixture $savedConfig
        $code = @(
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
            ('$localConfig=' + (Get-Literal $configPath)), ('$savedConfig=' + (Get-Literal $savedConfig)), ('$localApp=' + (Get-Literal $appRoot)),
            @'
$script:remoteAccess=0;$script:nativeCalls=0
function Get-AudioEnvironmentSetting {
    param([string]$Name, [string]$Target = 'Process')
    if($Name -ieq 'Path' -and $Target -eq 'Process'){return $env:PATH}
    return $null
}
$script:realSelectionPath=(Get-Command Get-AudioSelectionPath -CommandType Function).ScriptBlock
function Assert-S10LocalAccess {
    param([object[]]$Values)
    foreach($value in $Values){if([string]$value -like '\\*'){$script:remoteAccess++;throw 'S10 forbidden remote filesystem access'}}
}
function Get-AudioSelectionPath {param([string]$Path);Assert-S10LocalAccess @($Path);& $script:realSelectionPath @PSBoundParameters}
function Test-Path {
    [CmdletBinding()]param([Parameter(Position=0)][string[]]$Path,[string[]]$LiteralPath,[string]$PathType)
    Assert-S10LocalAccess @($Path+$LiteralPath);Microsoft.PowerShell.Management\Test-Path @PSBoundParameters
}
function Get-Item {
    [CmdletBinding()]param([Parameter(Position=0)][string[]]$Path,[string[]]$LiteralPath,[switch]$Force)
    Assert-S10LocalAccess @($Path+$LiteralPath);Microsoft.PowerShell.Management\Get-Item @PSBoundParameters
}
function Invoke-AudioNativeProcess {$script:nativeCalls++;throw 'S10 forbidden native access'}
$remote='\\AFP-S10-not-contacted.invalid\share\tools'
foreach($mode in @('config','explicit','saved','app-local','PATH')){
    $context=@{};$options=@{ScriptDirectory=$localApp;ConfigPath=$localConfig;LocalOnly=$true;DiagnosticContext=$context}
    $env:PATH=$remote
    switch($mode){
        'config'{$options.ConfigPath=$remote+'\config.json';$expected='ConfigInvalid'}
        'explicit'{$options.FfmpegDirectory=$remote;$expected='DependencyInvalid'}
        'saved'{$options.ConfigPath=$savedConfig;$expected='DependencyInvalid'}
        'app-local'{$options.ScriptDirectory=$remote;$expected='DependencyInvalid'}
        'PATH'{$expected='DependencyMissing'}
    }
    $cause=$null;try{Resolve-AudioToolSelection @options|Out-Null}catch{$cause=$_.Exception.Message}
    if($null -eq $cause -or $context.Code -cne $expected -or $script:remoteAccess -ne 0 -or $script:nativeCalls -ne 0){throw ('No-network guard failed for '+$mode+': '+$cause+' / '+$context.Code)}
}
Write-Host '[LOCAL_ONLY_RESULT] five UNC origins refused before filesystem/native access; guard instrumentation only'
'@
        ) -join "`r`n"
        $before = Get-TreeState @($childTemp, $localData, $configRoot)
        $result = Invoke-Child 'local-only-UNC-guards' $code; Assert-ChildExit $result 0
        Assert-True ($result.stdout -match '\[LOCAL_ONLY_RESULT\]' -and (Get-TreeState @($childTemp, $localData, $configRoot)) -ceq $before) 'UNC guard instrumentation must show zero remote/native access and no writes.'
        $case.instrumented_filesystem_guards = $true; $case.native_calls = 0; $case.remote_access_calls = 0; $case.origins = @('config', 'explicit', 'saved', 'app-local', 'PATH')
    }
    Invoke-Case 'no-network-private-report-import-and-selftest-temp-reject-UNC-before-access' 'S10-A2/S10-A3' {
        param($case)
        $code = @(
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Diagnostics.ps1'))),
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Checks.ps1'))),
            @'
$remote='\\AFP-S10-not-contacted.invalid\share\support'
$script:storageChecks=0;$script:ancestryChecks=0;$script:createChecks=0;$script:nativeCalls=0
function Assert-AudioDiagnosticStoragePath {$script:storageChecks++;throw 'S10 forbidden diagnostic filesystem access'}
function Invoke-AudioNativeProcess {$script:nativeCalls++;throw 'S10 forbidden native operation'}
# Import must refuse UNC without requiring any production converter helper.
if(Get-Command Get-AudioAppVersion -CommandType Function -ErrorAction SilentlyContinue){throw 'S10 import isolation unexpectedly loaded the converter helper'}
$cause=$null;try{Import-AudioDiagnosticRecord -Path ($remote+'\failure.json')|Out-Null}catch{$cause=$_.Exception.Message}
if($cause -notmatch 'local filesystem path' -or $script:storageChecks -ne 0 -or $script:nativeCalls -ne 0){throw ('UNC support import did not refuse before storage/native access: '+$cause)}
'@,
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
            @'
function Assert-AudioNoReparseAncestor {$script:ancestryChecks++;throw 'S10 forbidden TEMP filesystem access'}
function Initialize-AudioDirectoryInterop {$script:createChecks++;throw 'S10 forbidden TEMP creation'}
$savedTemp=$env:TEMP;$savedTmp=$env:TMP
try {
    $env:TEMP=$remote;$env:TMP=$remote
    # GetTempPath reads process configuration only; it does not open the share.
    if(-not [IO.Path]::GetTempPath().StartsWith($remote,[StringComparison]::OrdinalIgnoreCase)){throw 'S10 TEMP fixture did not select the intended UNC spelling'}
    $cause=$null;try{New-AudioSelfTestScope|Out-Null}catch{$cause=$_.Exception.Message}
    if($cause -notmatch 'local filesystem path' -or $script:ancestryChecks -ne 0 -or $script:createChecks -ne 0 -or $script:nativeCalls -ne 0){throw ('UNC self-test TEMP did not refuse before ancestry/create/native access: '+$cause)}
}finally{$env:TEMP=$savedTemp;$env:TMP=$savedTmp}
Write-Host '[LOCAL_SUPPORT_RESULT] UNC import and self-test TEMP refused before filesystem/create/native access; instrumentation only'
'@
        ) -join "`r`n"
        $before = Get-TreeState @($childTemp, $localData, $configRoot)
        $result = Invoke-Child 'local-only-support-and-temp' $code; Assert-ChildExit $result 0
        Assert-True ($result.stdout -match '\[LOCAL_SUPPORT_RESULT\]' -and (Get-TreeState @($childTemp, $localData, $configRoot)) -ceq $before) 'UNC import and TEMP instrumentation must prove refusal before access and leave no application files.'
        $case.instrumented_filesystem_guards = $true; $case.converter_helper_independent_import = $true
        $case.storage_checks = 0; $case.ancestry_checks = 0; $case.creation_checks = 0; $case.native_calls = 0; $case.actual_remote_access = $false
    }
    Invoke-Case 'interactive-prerequisite-release-refusal-stops-before-setup-or-new-native-work' 'S10-A1/S10-A2' {
        param($case)
        $loader = Join-Path $testRoot 'repair-refusal-loader.ps1'
        $loaderCode = @(
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
            @'
function Resolve-AudioToolSelection {
    param([string]$FfmpegDirectory,[string]$ConfigPath,[string]$ScriptDirectory,[object]$Cancellation,[hashtable]$DiagnosticContext,[switch]$LocalOnly)
    # Pure returned-result substitution: no child exists in this injection.
    $DiagnosticContext.Code='DependencyInvalid';$DiagnosticContext.Stage='ToolSelection'
    $DiagnosticContext.NativeResult=[pscustomobject]@{Status='Completed';ExitCode=0;ProcessReleased=$false;PipeDrainCompleted=$false;Operation='S10 injected prerequisite refusal';Error='S10 pure injection';Stderr=''}
    throw 'S10 pure prerequisite release refusal'
}
function Invoke-AudioToolSetup {$global:S10RepairCalls++;throw 'S10 setup must not follow unproved release'}
function Invoke-AudioNativeProcess {$global:S10UnexpectedNative++;throw 'S10 no native operation may follow unproved release'}
'@
        ) -join "`r`n"
        Write-NewText $loader $loaderCode; Add-Fixture $loader
        $code = @(
            ('$global:S10ExpectedApp=' + (Get-Literal $appRoot)), ('$global:S10RefusalLoader=' + (Get-Literal $loader)),
            '$global:S10RepairCalls=0;$global:S10UnexpectedNative=0',
            @'
function global:Join-Path {
    [CmdletBinding()]param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath)
    if($Path -ceq $global:S10ExpectedApp -and $ChildPath -ceq 'AudioFileForPhone.Helpers.ps1'){return $global:S10RefusalLoader}
    Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
}
'@,
            ('& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputRoot) + ' -OutputParent ' + (Get-Literal $outputRoot) + ' -ConfigPath ' + (Get-Literal $configPath) + ' -Interactive'),
            '$observedExit=$LASTEXITCODE;if($observedExit -ne 1 -or $global:S10RepairCalls -ne 0 -or $global:S10UnexpectedNative -ne 0){throw ''Release refusal did not stop before repair/native work''}',
            'Write-Host ''[REPAIR_REFUSAL_RESULT] injected result stopped before setup and native work'';exit 0'
        ) -join "`r`n"
        $local = New-Directory 'Local-repair-refusal'; $temporary = New-Directory 'Temp-repair-refusal'
        $result = Invoke-Child 'repair-release-refusal' $code @{ LOCALAPPDATA = $local; TEMP = $temporary; TMP = $temporary }; Assert-ChildExit $result 0
        Assert-True ($result.stdout -match '\[REPAIR_REFUSAL_RESULT\]' -and -not [IO.Directory]::Exists($outputRoot)) 'Injected unproved prerequisite result must not enter setup or start a run.'
        $record = Read-StartupRecord $result @($local, $temporary)
        Assert-True ($record.code -ceq 'DependencyInvalid' -and $record.native.process_released -eq $false -and $record.message -match 'release/pipe completion is unproved') 'Early failure must retain the first refusal identity and actionable stop cause.'
        $case.injected = $true; $case.real_unreleased_child = $false; $case.setup_calls = 0; $case.subsequent_native_calls = 0
    }
    Invoke-Case 'explicit-support-export-is-reviewable-whitelisted-and-does-not-overwrite' 'S10-A3' {
        param($case)
        $export = Join-Path $testRoot 'support-export.txt'
        $result = Invoke-Check 'check-export' ($explicit + ' -ExportPath ' + (Get-Literal $export)); Assert-ChildExit $result 0
        Assert-True ([IO.File]::Exists($export)) 'Explicit export must create the requested reviewable text.'
        $text = [IO.File]::ReadAllText($export); $support = $text | ConvertFrom-Json
        Assert-True ($support.kind -ceq 'AudioFileForPhone.Support' -and $text -match 'Review before sharing' -and $text -match 'No upload') 'Support export must be labelled for review with no-upload privacy guidance.'
        Assert-True (-not $text.Contains($testRoot) -and -not $text.Contains($toolDirectory) -and -not $text.Contains($env:USERNAME)) 'Shareable export must omit real private/tool/user roots.'
        $hash = (Get-FileHash -LiteralPath $export).Hash; Add-Fixture $export
        $again = Invoke-Check 'check-export-occupied' ($explicit + ' -ExportPath ' + (Get-Literal $export)); Assert-ChildExit $again 1
        Assert-True ((Get-FileHash -LiteralPath $export).Hash -ceq $hash) 'Export must refuse to overwrite an existing file.'
        $case.whitelist_kind = $support.kind; $case.no_overwrite = $true; $case.no_upload = $true
    }
    Invoke-Case 'support-redaction-rejects-adversarial-free-text-and-unknown-properties' 'S10-A3' {
        param($case)
        $secret = 'S10_PRIVATE_SENTINEL_7c91'
        $hostile = [pscustomobject]@{
            code = 'DependencyMissing'; stage = 'ToolSelection'; app_version = '1.0.0'; build = @{}
            host = @{ version = '7.6.5'; os_version = '10.0.26300.9711'; path = 'C:\Users\' + $secret + '\pwsh.exe'; edition = 'Core'; apartment = 'STA'; os_x64 = $true; process_x64 = $true }
            config = @{ path = 'C:\' + $secret + '\config.json' }; message = $secret + ' -i C:\secret.mp3'; repair = $secret
            discovery_attempts = @(@{ candidate = 'C:\' + $secret; reason = $secret }); raw_path = $secret
            tools = @{ origin = 'PATH'; ffmpeg = @{ path = 'C:\' + $secret + '\ffmpeg.exe'; version = 'ffmpeg version 9.0.2 ' + $secret; architecture = 'x64'; sha256 = ('a' * 64) }; ffprobe = $null }
            native = @{ status = 'Completed'; executable = 'C:\' + $secret; process_released = $true; pipe_drain_completed = $true; error = $secret; stderr = $secret + "`r`n" + [char]27 + '[31m'; arguments = @('-i', 'C:\' + $secret + '.mp3'); exit_code = 0; elapsed_ms = 12 }
            totals = @{ total = 0; converted = 0; failed = 0; exit_code = 1; status = $secret }
            source_root = 'C:\' + $secret; output_root = 'C:\' + $secret; credentials = $secret; metadata = @{ title = $secret; artist = $secret }
        }
        $text = ConvertTo-AudioSupportReport -Record $hostile
        Assert-True (-not $text.Contains($secret) -and $text -notmatch '(?i)[a-z]:[\\/]|\\\\') 'Whitelist must exclude arbitrary private text and every unredacted absolute path.'
        $support = $text | ConvertFrom-Json
        Assert-True (@($support.PSObject.Properties.Name | Where-Object { $_ -in @('credentials', 'metadata', 'raw_path', 'message', 'discovery_attempts') }).Count -eq 0 -and
            @($support.native.PSObject.Properties.Name | Where-Object { $_ -in @('stderr', 'error', 'arguments') }).Count -eq 0) 'Whitelist must omit unknown/private fields and native free-text/argument properties.'
        Assert-True ($support.source_root -ceq '[SOURCE]' -and $support.output_root -ceq '[OUTPUT]' -and $support.config -ceq '[CONFIG]' -and $support.user_root -ceq '[USER]') 'Support report must replace private roots with explicit tokens.'
        $hostile.code = $secret; $hostile.stage = $secret; $hostile.app_version = $secret
        $hostile.host.version = $secret; $hostile.host.edition = $secret; $hostile.tools.origin = $secret
        $hostile.tools.ffmpeg.architecture = $secret; $hostile.tools.ffmpeg.sha256 = $secret
        $again = ConvertTo-AudioSupportReport -Record $hostile
        Assert-True (-not $again.Contains($secret)) 'Every retained scalar needs type/allowlist filtering, including codes, build/version, origin and architecture.'
        $case.injected = $true; $case.real_conversion_evidence = $false; $case.arbitrary_fields_omitted = $true
    }
    Invoke-Case 'private-startup-record-review-and-explicit-export-work-with-missing-converter-helper' 'S10-A1/S10-A3' {
        param($case)
        $copy = New-AppCopy 'Support-review-no-helper' 'AudioFileForPhone.Helpers.ps1'
        $recordPaths = @(Get-SafeTree (Join-Path $testRoot 'Local-dependency') | Where-Object { -not $_.PSIsContainer -and $_.Name -like 'failure-*.json' })
        Assert-True ($recordPaths.Count -eq 1) 'Expected the earlier actual dependency startup record.'
        $privatePath = $recordPaths[0].FullName
        $before = Get-TreeState @($copy, $localData, $childTemp, $configRoot)
        $code = '& ' + (Get-Literal (Join-Path $copy 'Check-AudioFileForPhone.ps1')) + ' -DiagnosticPath ' + (Get-Literal $privatePath) + "`r`nexit `$LASTEXITCODE"
        $result = Invoke-Child 'support-review-real-record' $code; Assert-ChildExit $result 0; $summary = Read-CheckResult $result
        Assert-True ($summary.code -ceq 'SupportReviewReady' -and $result.stdout -match 'DependencyMissing') 'Support review must preserve the original stable diagnostic code without loading converter helpers.'
        Assert-True ((Get-TreeState @($copy, $localData, $childTemp, $configRoot)) -ceq $before) 'Reviewing a private record must not execute tools, read config or write a new report.'
        $export = Join-Path $testRoot 'startup-support-export.txt'
        $exportCode = '& ' + (Get-Literal (Join-Path $copy 'Check-AudioFileForPhone.ps1')) + ' -DiagnosticPath ' + (Get-Literal $privatePath) + ' -ExportPath ' + (Get-Literal $export) + "`r`nexit `$LASTEXITCODE"
        $saved = Invoke-Child 'support-export-real-record' $exportCode; Assert-ChildExit $saved 0
        $text = [IO.File]::ReadAllText($export); Add-Fixture $export
        Assert-True (-not $text.Contains($testRoot) -and ($text | ConvertFrom-Json).code -ceq 'DependencyMissing') 'Export of an actual startup record must preserve stable cause while removing private roots.'
        $case.original_record_real_startup = $true; $case.helper_independent = $true; $case.console_review_no_write = $true
    }
    Invoke-Case 'private-report-import-rejects-oversize-malformed-and-unsupported-schema-with-no-export' 'S10-A3' {
        param($case)
        foreach ($bad in @(
            @{ name = 'oversize'; text = (' ' * 65537) },
            @{ name = 'malformed'; text = '{ bad json' },
            @{ name = 'schema'; text = '{"schema_version":2,"kind":"AudioFileForPhone.Diagnostic","stage":"Bootstrap","code":"HelperMissing"}' }
        )) {
            $path = Join-Path $testRoot ('bad-report-' + $bad.name + '.json'); Write-NewText $path $bad.text; Add-Fixture $path
            $export = Join-Path $testRoot ('bad-export-' + $bad.name + '.txt')
            $code = '& ' + (Get-Literal (Join-Path $appRoot 'Check-AudioFileForPhone.ps1')) + ' -DiagnosticPath ' + (Get-Literal $path) + ' -ExportPath ' + (Get-Literal $export) + "`r`nexit `$LASTEXITCODE"
            $result = Invoke-Child ('support-import-invalid-' + $bad.name) $code; Assert-ChildExit $result 1
            $summary = Read-CheckResult $result
            Assert-True ($summary.code -ceq 'DiagnosticInvalid' -and -not [IO.File]::Exists($export)) 'Invalid/oversize private reports must fail with DiagnosticInvalid and no export.'
        }
        $case.rejected = @('oversize', 'malformed', 'unsupported-schema'); $case.exports_created = 0
    }
    Invoke-Case 'support-export-refuses-reparse-target-without-touching-target' 'S10-A3' {
        param($case)
        $target = New-Directory 'Export-junction-target'; $link = Join-Path $testRoot 'Export-junction'
        Assert-True ((Split-Path -Parent $link) -ceq $testRoot -and (Split-Path -Parent $target) -ceq $testRoot) 'Junction fixture must stay in the exact owned scope.'
        $null = New-Item -ItemType Junction -Path $link -Value $target
        try {
            $record = New-AudioDiagnosticRecord -ScriptDirectory $appRoot -Stage 'EnvironmentCheck' -Code 'Completed' -Message 'Synthetic export refusal' -ConfigPath $configPath
            $message = $null
            try { Export-AudioSupportReport -Record $record -Path (Join-Path $link 'must-not-write.txt') | Out-Null } catch { $message = $_.Exception.Message }
            Assert-True ($message -match 'reparse' -and @(Get-ChildItem -LiteralPath $target -Force).Count -eq 0) 'Export must reject a reparse destination without writing through it.'
        } finally { [IO.Directory]::Delete($link, $false) }
        $case.reparse_refused = $true; $case.target_unchanged = $true
    }
    Invoke-Case 'private-report-import-refuses-reparse-ancestor' 'S10-A3' {
        param($case)
        $target = New-Directory 'Import-junction-target'; $link = Join-Path $testRoot 'Import-junction'
        $private = Join-Path $target 'private.json'
        Write-NewText $private '{"schema_version":1,"kind":"AudioFileForPhone.Diagnostic","stage":"Bootstrap","code":"HelperMissing"}'; Add-Fixture $private
        Assert-True ((Split-Path -Parent $link) -ceq $testRoot -and (Split-Path -Parent $target) -ceq $testRoot) 'Import junction fixture must stay in the exact owned scope.'
        $null = New-Item -ItemType Junction -Path $link -Value $target
        try {
            $code = '& ' + (Get-Literal (Join-Path $appRoot 'Check-AudioFileForPhone.ps1')) + ' -DiagnosticPath ' + (Get-Literal (Join-Path $link 'private.json')) + "`r`nexit `$LASTEXITCODE"
            $result = Invoke-Child 'support-import-reparse' $code; Assert-ChildExit $result 1; $summary = Read-CheckResult $result
            Assert-True ($summary.code -ceq 'DiagnosticInvalid' -and $result.stdout -match 'reparse') 'Private report import must reject a reparse ancestor.'
        } finally { [IO.Directory]::Delete($link, $false) }
        $case.reparse_refused = $true
    }
    foreach ($injection in @('fixture-unavailable', 'fixture-release-refusal', 'prestart-cancel')) {
        $injectionMode = $injection
        Invoke-Case ('selftest-' + $injection + '-is-explicitly-labelled-injection') 'S10-A2/S10-A3' {
            param($case)
            $code = @(
                ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
                ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Checks.ps1'))),
                ('$mode=' + (Get-Literal $injectionMode)),
                ('$selection=[pscustomobject]@{Ffmpeg=[pscustomobject]@{Path=' + (Get-Literal $ffmpeg) + '};Ffprobe=[pscustomobject]@{Path=' + (Get-Literal $ffprobe) + '}}'),
                '$script:calls=0; $cancel=New-AudioCancellationContext',
                @'
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[object]$Cancellation,[string]$Operation,[int]$TimeoutMilliseconds)
    $script:calls++
    # No native child exists in this pure returned-result injection.
    return [pscustomobject]@{
        Status=$(if($mode -ceq 'prestart-cancel'){'Cancelled'}else{'Completed'});ExitCode=0
        ProcessReleased=($mode -cne 'fixture-release-refusal');PipeDrainCompleted=$true
        Stdout='fixture capability deliberately absent';Stderr='';Error='S10 pure injected condition'
        StdoutTruncated=$false;StderrTruncated=$false;Operation=$Operation;TimeoutMilliseconds=$TimeoutMilliseconds
    }
}
try {
    $result=Invoke-AudioSyntheticSelfTest -Selection $selection -SupportedSampleRates @(44100,48000) -Cancellation $cancel
    $expected=if($mode -ceq 'fixture-unavailable'){'SELF_TEST_UNAVAILABLE'}elseif($mode -ceq 'prestart-cancel'){'Cancelled'}else{'SelfTestFailed'}
    if($result.Code -cne $expected -or $script:calls -ne 1 -or $null -ne $result.RootPath){throw ('Unexpected injected outcome: '+($result|ConvertTo-Json -Depth 4))}
    if($mode -ceq 'fixture-release-refusal' -and $result.ProcessReleased){throw 'Unproved release was silently accepted.'}
    if($mode -ceq 'prestart-cancel' -and $result.ExitCode -ne 130){throw 'Cancellation exit130 was lost.'}
    Write-Host ('[INJECTION_RESULT] '+([ordered]@{mode=$mode;code=$result.Code;exit_code=$result.ExitCode;native_calls=$script:calls;root_created=($null -ne $result.RootPath);injected=$true}|ConvertTo-Json -Compress))
}finally{$cancel.Dispose()}
'@
            ) -join "`r`n"
            $before = Get-TreeState @($childTemp, $localData, $configRoot)
            $result = Invoke-Child ('injection-' + $injectionMode) $code; Assert-ChildExit $result 0
            Assert-True ($result.stdout -match '\[INJECTION_RESULT\]' -and (Get-TreeState @($childTemp, $localData, $configRoot)) -ceq $before) 'Pure unavailable/refusal/cancellation checks must stop before fixture creation and leave no state.'
            $case.injected = $true; $case.real_native_or_conversion_evidence = $false; $case.stopped_before_fixture_creation = $true
        }
    }
    Invoke-Case 'late-cancellation-after-real-selftest-cleanup-preserves-exit130' 'S10-A2' {
        param($case)
        $code = @(
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Diagnostics.ps1'))),
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Checks.ps1'))),
            ('$check=Invoke-AudioEnvironmentCheck -ScriptDirectory ' + (Get-Literal $appRoot) + ' -FfmpegDirectory ' + (Get-Literal $toolDirectory) + ' -ConfigPath ' + (Get-Literal $configPath)),
            @'
if($check.Status -cne 'Success'){throw ('Production environment check failed: '+$check.Message)}
$script:cancelAfterCleanup=New-AudioCancellationContext
$script:realCleanup=(Get-Command Remove-AudioSelfTestScope -CommandType Function).ScriptBlock
function Remove-AudioSelfTestScope {
    param([object]$Scope,[bool]$ProcessReleased,[bool]$PipeDrainCompleted)
    & $script:realCleanup @PSBoundParameters
    # Only the request timing is injected. Fixture, transaction, native release,
    # full-decode validation and guarded cleanup all execute production code.
    $script:cancelAfterCleanup.Request()
}
try {
    $result=Invoke-AudioSyntheticSelfTest -Selection $check.Selection -SupportedSampleRates $check.SampleRates -Cancellation $script:cancelAfterCleanup
    if($result.Status -cne 'Cancelled' -or $result.Code -cne 'Cancelled' -or $result.ExitCode -ne 130 -or
        -not $result.SourceUnchanged -or -not $result.CleanupVerified -or -not $result.ProcessReleased -or
        -not $result.PipeDrainCompleted -or $null -eq $result.Validation -or $result.Validation.Status -cne 'Success'){
        throw ('Late cancellation lost transaction/release/cleanup proof: '+($result|ConvertTo-Json -Depth 3))
    }
    if([IO.Directory]::Exists($result.RootPath)){throw 'Late cancellation did not clean its exact released scope.'}
    Write-Host ('[LATE_CANCEL_RESULT] '+([ordered]@{status=$result.Status;exit_code=$result.ExitCode;cleanup_verified=$result.CleanupVerified;source_unchanged=$result.SourceUnchanged;native_count=@($result.NativeResults).Count;real_conversion=$true;request_timing_injected=$true}|ConvertTo-Json -Compress))
}finally{$script:cancelAfterCleanup.Dispose()}
'@
        ) -join "`r`n"
        $before = Get-TreeState @($childTemp, $localData, $configRoot)
        $result = Invoke-Child 'late-selftest-cancellation' $code; Assert-ChildExit $result 0
        Assert-True ($result.stdout -match '\[LATE_CANCEL_RESULT\]' -and (Get-TreeState @($childTemp, $localData, $configRoot)) -ceq $before) 'Late cancellation must retain130 after actual validated conversion and complete owned cleanup.'
        $case.request_timing_injected = $true; $case.real_conversion = $true; $case.exit_code = 130; $case.cleanup_verified = $true
    }
    Invoke-Case 'selftest-cleanup-refuses-unproved-release-and-changed-marker' 'S10-A2' {
        param($case)
        $sentinel = Join-Path $testRoot 'Outside-selftest-scope-sentinel.mp3'
        Write-NewText $sentinel 'S10 owned outside-scope cleanup sentinel'; Add-Fixture $sentinel
        $code = @(
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
            ('. ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Checks.ps1'))),
            ('$outsideSentinel=' + (Get-Literal $sentinel)),
            @'
$scope=New-AudioSelfTestScope
try {
    $refused=$false
    try{Remove-AudioSelfTestScope -Scope $scope -ProcessReleased $false -PipeDrainCompleted $true}catch{$refused=$_.Exception.Message -match 'unproved'}
    if(-not $refused -or -not [IO.Directory]::Exists($scope.Root)){throw 'Cleanup did not retain an unproved-release scope.'}
    $token=$scope.Token;$scope.Token='0'*32;$refused=$false
    try{Remove-AudioSelfTestScope -Scope $scope -ProcessReleased $true -PipeDrainCompleted $true}catch{$refused=$true}
    if(-not $refused -or -not [IO.Directory]::Exists($scope.Root)){throw 'Cleanup accepted changed marker token.'}
    $scope.Token=$token
    $sentinelHash=(Get-FileHash -LiteralPath $outsideSentinel).Hash
    foreach($property in @('InputPath','OutputPath','FixturePath','ResultPath')){
        $originalPathValue=$scope.$property;$scope.$property=$outsideSentinel;$refused=$false
        try{Remove-AudioSelfTestScope -Scope $scope -ProcessReleased $true -PipeDrainCompleted $true}catch{$refused=$true}
        if(-not $refused -or -not [IO.Directory]::Exists($scope.Root) -or (Get-FileHash -LiteralPath $outsideSentinel).Hash -cne $sentinelHash){throw ('Cleanup accepted an out-of-scope '+$property)}
        $scope.$property=$originalPathValue
    }
    # This pure cleanup test never started a native process, so positive release
    # and pipe proof is true after restoring its unchanged ownership token.
    Remove-AudioSelfTestScope -Scope $scope -ProcessReleased $true -PipeDrainCompleted $true
    if([IO.Directory]::Exists($scope.Root)){throw 'Exact owned scope did not clean after valid proof.'}
    Write-Host '[INJECTION_RESULT] cleanup guards passed; no native process was started'
}finally{if($null -ne $scope.MarkerStream){$scope.MarkerStream.Dispose()}}
'@
        ) -join "`r`n"
        $before = Get-TreeState @($childTemp)
        $result = Invoke-Child 'injection-cleanup' $code; Assert-ChildExit $result 0
        Assert-True ((Get-TreeState @($childTemp)) -ceq $before) 'Cleanup guard test must clean only its known owned scope after valid proof.'
        $case.injected = $true; $case.real_native_or_conversion_evidence = $false; $case.marker_and_release_refusal = $true
    }
    $report.copied_bytes_unchanged = $true
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Depth 5 -Compress) -ceq ($report.source_after | ConvertTo-Json -Depth 5 -Compress))
        $report.parent_path_unchanged = $env:PATH -ceq $originalPath
        Assert-True ($report.source_unchanged -and $report.parent_path_unchanged) 'Source bytes or parent PATH changed during S10 tests.'
        if ($created) {
            $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
            $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Depth 5 -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Depth 5 -Compress))
            Assert-True $report.synthetic_unchanged 'Owned runtime/driver/source fixtures changed.'
            $report.descendant_release_proved = $releaseProved
            Assert-True $releaseProved 'Cleanup refused because exact descendant release is unproved.'
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup root/name/parent refused.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup owner marker changed.'
            Get-SafeTree $resolved | Out-Null
            [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['integrity_or_cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    $report.native_runs = $nativeRuns.ToArray(); $report.completed_utc = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent; Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
Write-Host ('S10 support: ' + $report.status + '; cases=' + $report.cases.Count + '; cleanup=' + $report.cleanup_verified + '; sources=' + $report.source_unchanged + '/' + $report.synthetic_unchanged)
exit $exitCode
