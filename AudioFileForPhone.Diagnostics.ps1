# Functions only. This bootstrap deliberately does not require the converter helper.
# Detailed records are local/private; the support formatter copies a strict whitelist.

function Get-AudioDiagnosticText {
    param([AllowNull()][object]$Value, [int]$MaximumChars = 2048)
    $text = ([string]$Value) -replace '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '?'
    if ($text.Length -gt $MaximumChars) { return $text.Substring(0, $MaximumChars) + ' [truncated]' }
    return $text
}

function Get-AudioDiagnosticRepair {
    param([string]$Code)
    switch ($Code) {
        'HelperMissing' { return 'Restore the complete application package, including its helper/check files.' }
        'HostStartFailed' { return 'Select an allowed x64 PowerShell 7 or Windows PowerShell 5.1 host. Respect managed signing/application controls.' }
        'ConfigInvalid' { return 'Preserve the config. Use an explicit FfmpegDirectory for this run, or deliberately select another ConfigPath in setup.' }
        'DependencyMissing' { return 'Run Setup-AudioFileForPhone.ps1 and select the directory containing both ffmpeg.exe and ffprobe.exe.' }
        'DependencyInvalid' { return 'Reselect a trusted working FFmpeg/ffprobe pair with Setup-AudioFileForPhone.ps1. No fallback or download occurs during conversion.' }
        'CapabilityMissing' { return 'Select a trusted FFmpeg build providing libmp3lame and its supported sample rates.' }
        'StartupTimeout' { return 'Retry with responsive trusted tools/host. Increase ProbeTimeoutSeconds only for slow media probes; normal encode/decode remain unlimited.' }
        'IncompatibleAudioSettings' { return 'Review the requested bitrate and source channel layout, or select a compatible trusted FFmpeg build.' }
        'OutputUnwritable' { return 'Repair destination storage/permissions or select a shorter writable OutputParent, then retry.' }
        'InputInvalid' { return 'Select one readable input folder containing supported MP3, M4A or OGG files.' }
        'CoverInvalid' { return 'Select a readable valid JPEG/PNG cover, or omit CoverPath for no cover.' }
        'SELF_TEST_UNAVAILABLE' { return 'The selected tools cannot create the synthetic fixture. Ordinary conversion may still work; select a build with lavfi sine/libmp3lame fixture support to rerun self-test.' }
        'SelfTestFailed' { return 'Review the self-test stage and local failure. Reselect working trusted tools or repair temporary storage before retrying.' }
        'SelfTestCleanupRetained' { return 'Self-test retained its uniquely owned temporary tree because safe cleanup could not be proved. Review the local retained path; do not remove unrelated files.' }
        'EnvironmentReady' { return 'Environment checks passed. This did not scan or convert user media.' }
        'SelfTestPassed' { return 'Synthetic self-test passed. This is not a phone or ordinary Music-folder acceptance result.' }
        'Cancelled' { return 'Cancellation was preserved. Review retained working paths before a deliberate retry.' }
        'Completed' { return 'No repair is indicated by this check.' }
        default { return 'Review the original console cause and the named stage. Use Check-AudioFileForPhone.ps1 to inspect this installation.' }
    }
}

function New-AudioDiagnosticRecord {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory,
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string]$Code,
        [AllowNull()][string]$Message, [string]$ConfigPath,
        [AllowNull()][object]$Selection, [AllowNull()][object]$Counts,
        [AllowNull()][hashtable]$Context, [AllowNull()][object]$NativeResult)
    $build = [ordered]@{}
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1',
        'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Checks.ps1', 'AudioFileForPhone.ManagedSetup.ps1', 'Check-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1')) {
        try {
            $path = [IO.Path]::Combine($ScriptDirectory, $name)
            if ([IO.File]::Exists($path)) { $build[$name] = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() }
            else { $build[$name] = 'MISSING' }
        }
        catch { $build[$name] = 'UNREADABLE' }
    }
    $version = 'unavailable'
    try { if (Get-Command Get-AudioAppVersion -CommandType Function -ErrorAction SilentlyContinue) { $version = Get-AudioAppVersion } } catch { }
    $resolvedConfig = $ConfigPath
    try {
        # Identity capture must not retry the resolver's failed filesystem access
        # (especially a refused remote config during a no-network check).
        if ([string]::IsNullOrWhiteSpace($resolvedConfig)) {
            $resolvedConfig = [IO.Path]::Combine([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,
                [Environment+SpecialFolderOption]::DoNotVerify), 'AudioFileForPhone', 'config.json')
        }
        else { $resolvedConfig = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($resolvedConfig) }
    } catch { }
    $hostPath = ''
    $currentHost = $null
    try { $currentHost = [Diagnostics.Process]::GetCurrentProcess(); $hostPath = $currentHost.MainModule.FileName } catch { }
    finally { if ($null -ne $currentHost) { $currentHost.Dispose() } }
    $os = [Environment]::OSVersion.Version.ToString()
    $osDescription = ''
    try { $osDescription = [Runtime.InteropServices.RuntimeInformation]::OSDescription } catch { }
    $clientBuild = ''; $clientEdition = ''; $clientDisplay = ''
    try {
        $windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $clientBuild = [string]$windows.CurrentBuildNumber + '.' + [string]$windows.UBR
        $clientEdition = [string]$windows.EditionID; $clientDisplay = [string]$windows.DisplayVersion
    } catch { }
    $attempts = @()
    if ($null -ne $Context) {
        $retainedAttempts = @($Context.Attempts)
        if ($retainedAttempts.Count -gt 8) { $retainedAttempts = @($retainedAttempts | Select-Object -First 4) + @($retainedAttempts | Select-Object -Last 4) }
        foreach ($attempt in $retainedAttempts) {
            if ($null -eq $attempt) { continue }
            $attempts += [ordered]@{ origin = (Get-AudioDiagnosticText $attempt.Origin 32); candidate = (Get-AudioDiagnosticText $attempt.Candidate 512)
                status = (Get-AudioDiagnosticText $attempt.Status 64); reason = (Get-AudioDiagnosticText $attempt.Reason 256) }
        }
        if ($null -eq $NativeResult) { $NativeResult = $Context.NativeResult }
        if ($null -eq $Selection) { $Selection = $Context.Selection }
    }
    $tools = [ordered]@{ origin = 'Unresolved'; ffmpeg = $null; ffprobe = $null }
    if ($null -ne $Selection) {
        $tools.origin = Get-AudioDiagnosticText $Selection.Origin 32
        foreach ($key in @('Ffmpeg', 'Ffprobe')) {
            $tool = $Selection.$key
            if ($null -eq $tool) { continue }
            $hash = 'UNREADABLE'
            try { $hash = (Get-FileHash -LiteralPath $tool.Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() } catch { }
            $tools[$key.ToLowerInvariant()] = [ordered]@{ path = (Get-AudioDiagnosticText $tool.Path 1024)
                version = (Get-AudioDiagnosticText $tool.Version 256); architecture = (Get-AudioDiagnosticText $tool.Architecture 16); sha256 = $hash }
        }
    }
    $native = $null
    if ($null -ne $NativeResult) {
        $native = [ordered]@{ operation = (Get-AudioDiagnosticText $NativeResult.Operation 128)
            executable = (Get-AudioDiagnosticText $NativeResult.ExecutablePath 1024); status = (Get-AudioDiagnosticText $NativeResult.Status 64)
            exit_code = $NativeResult.ExitCode; elapsed_ms = $NativeResult.DurationMilliseconds
            process_released = [bool]$NativeResult.ProcessReleased; pipe_drain_completed = [bool]$NativeResult.PipeDrainCompleted
            error = (Get-AudioDiagnosticText $NativeResult.Error 1024); stderr = (Get-AudioDiagnosticText $NativeResult.Stderr 2048) }
    }
    $totals = [ordered]@{ total = 0; converted = 0; failed = 0; exit_code = 1; status = 'FailedBeforeConversion' }
    if ($null -ne $Counts) {
        foreach ($key in @('total', 'converted', 'failed', 'exit_code')) { if ($null -ne $Counts.$key) { $totals[$key] = [long]$Counts.$key } }
        if ($null -ne $Counts.status) { $totals.status = Get-AudioDiagnosticText $Counts.status 64 }
    }
    return [pscustomobject][ordered]@{
        schema_version = 1; kind = 'AudioFileForPhone.Diagnostic'; privacy = 'PRIVATE: may contain local paths and native errors. Review a separate redacted support export before sharing.'
        created_utc = [datetime]::UtcNow.ToString('o'); app_version = (Get-AudioDiagnosticText $version 32); build = $build
        host = [ordered]@{ path = $hostPath; version = $PSVersionTable.PSVersion.ToString(); edition = [string]$PSVersionTable.PSEdition
            os_version = $os; os_description = $osDescription; os_x64 = [Environment]::Is64BitOperatingSystem; process_x64 = [Environment]::Is64BitProcess
            apartment = [Threading.Thread]::CurrentThread.GetApartmentState().ToString(); language_mode = [string]$ExecutionContext.SessionState.LanguageMode }
        stage = (Get-AudioDiagnosticText $Stage 64); code = (Get-AudioDiagnosticText $Code 64); message = (Get-AudioDiagnosticText $Message 2048)
        repair = (Get-AudioDiagnosticRepair $Code); config = [ordered]@{ path = (Get-AudioDiagnosticText $resolvedConfig 1024); source = $(if ([string]::IsNullOrWhiteSpace($ConfigPath)) { 'Default' } else { 'Explicit' }) }
        client = [ordered]@{ build = $clientBuild; edition = $clientEdition; display_version = $clientDisplay }
        discovery_attempts = $attempts; tools = $tools; native = $native; totals = $totals; log_path = $null
    }
}

function Assert-AudioDiagnosticStoragePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])' -or $Path.StartsWith('\\?\') -or $Path.StartsWith('\\.\')) { throw 'Diagnostics require an absolute ordinary filesystem path.' }
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        $item = $null
        try { $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] { $item = $null }
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Diagnostics do not follow reparse-point storage paths.' }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Assert-AudioLocalDiagnosticPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    # Bootstrap/support can diagnose a missing main helper, so this local-only
    # spelling check deliberately has no converter-helper dependency.
    $provider = $null; $drive = $null
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem' -or $full -notmatch '^[A-Za-z]:[\\/]' -or $full.StartsWith('\\?\') -or $full.StartsWith('\\.\')) {
        throw 'Diagnostics/support require a local filesystem path; UNC and non-filesystem paths are refused before access.'
    }
    $volume = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($full))
    if ($volume.DriveType -eq [IO.DriveType]::Network) { throw 'Diagnostics/support refuse mapped network drives before access.' }
    return $full
}

function Write-AudioDiagnosticFile {
    param([string]$Path, [string]$Text)
    $null = Assert-AudioLocalDiagnosticPath -Path $Path
    Assert-AudioDiagnosticStoragePath -Path $Path
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    if ($bytes.Length -gt 65536) { throw 'Diagnostic report exceeds the 64 KiB byte limit.' }
    $stream = $null
    try {
        $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
    }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}

function Write-AudioStartupFailure {
    param([Parameter(Mandatory = $true)][object]$Record, [switch]$DryRun)
    Write-Host ('[DIAGNOSTIC] stage=' + $Record.stage + '; code=' + $Record.code + '; ' + $Record.repair)
    if ($DryRun) { Write-Host '[DIAGNOSTIC] DryRun: console only; no diagnostic file was created.'; return $null }
    $locations = @()
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { $locations += [IO.Path]::Combine($env:LOCALAPPDATA, 'AudioFileForPhone', 'Diagnostics') }
    if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) { $locations += [IO.Path]::Combine($env:TEMP, 'AudioFileForPhone-Diagnostics-' + [guid]::NewGuid().ToString('N')) }
    foreach ($directory in $locations) {
        try {
            $null = Assert-AudioLocalDiagnosticPath -Path $directory
            Assert-AudioDiagnosticStoragePath -Path $directory
            [IO.Directory]::CreateDirectory($directory) | Out-Null
            Assert-AudioDiagnosticStoragePath -Path $directory
            $path = [IO.Path]::Combine($directory, 'failure-' + [guid]::NewGuid().ToString('N') + '.json')
            $Record.log_path = $path
            $text = $Record | ConvertTo-Json -Depth 8
            if ([Text.Encoding]::UTF8.GetByteCount($text) -gt 65536) {
                # A bounded number of Unicode/control-rich diagnostics can still
                # expand in JSON. Preserve identity/stage/cause while dropping the
                # optional discovery/native text before giving up storage.
                $Record.discovery_attempts = @()
                $Record.message = Get-AudioDiagnosticText $Record.message 512
                if ($null -ne $Record.native) { $Record.native.stderr = '[omitted for byte bound]'; $Record.native.error = Get-AudioDiagnosticText $Record.native.error 256 }
                $text = $Record | ConvertTo-Json -Depth 8
            }
            Write-AudioDiagnosticFile -Path $path -Text $text
            Write-Host ('[DIAGNOSTIC] PRIVATE local report (review/redact before sharing): ' + $path)
            return $path
        }
        catch { Write-Warning ('Diagnostic storage unavailable; original console cause is unchanged. ' + (Get-AudioDiagnosticText $_.Exception.Message 512)) -ErrorAction Continue }
    }
    return $null
}

function ConvertTo-AudioSupportReport {
    param([Parameter(Mandatory = $true)][object]$Record)
    # Never copy message, discovery paths/reasons, native stderr/arguments, PATH,
    # source names, tags or arbitrary nested properties into the shareable report.
    $codes = @('HelperMissing', 'HostStartFailed', 'ConfigInvalid', 'DependencyMissing', 'DependencyInvalid', 'CapabilityMissing', 'StartupTimeout',
        'IncompatibleAudioSettings', 'OutputUnwritable', 'InputInvalid', 'CoverInvalid', 'SELF_TEST_UNAVAILABLE', 'SelfTestFailed', 'SelfTestCleanupRetained',
        'EnvironmentReady', 'SelfTestPassed', 'Cancelled', 'Completed', 'StartupFailed')
    $stages = @('Bootstrap', 'Parameters', 'InputDiscovery', 'ToolSelection', 'CoverValidation', 'OutputPreflight', 'OutputInitialization',
        'HostSelection', 'ApplicationStart', 'Conversion', 'Setup', 'EnvironmentCheck', 'SelfTest', 'FixtureGeneration', 'Export',
        'CheckBootstrap', 'DependencyResolution', 'EncoderCapabilities', 'SyntheticSelfTest')
    $code = if ($Record.code -cin $codes) { [string]$Record.code } else { 'StartupFailed' }
    $stage = if ($Record.stage -cin $stages) { [string]$Record.stage } else { 'Bootstrap' }
    $safe = [ordered]@{ schema_version = 1; kind = 'AudioFileForPhone.Support'; privacy = 'Review before sharing. Redaction reduces identifying content; it does not guarantee anonymity. No upload is performed.'
        stage = $stage; code = $code; repair = (Get-AudioDiagnosticRepair $code); app_version = 'unavailable'; build = [ordered]@{}
        host = [ordered]@{}; config = '[CONFIG]'; user_root = '[USER]'; source_root = '[SOURCE]'; output_root = '[OUTPUT]'; tools = [ordered]@{}; native = $null; totals = [ordered]@{} }
    if ([string]$Record.app_version -match '^\d+\.\d+\.\d+(?:\.\d+)?$') { $safe.app_version = [string]$Record.app_version }
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Checks.ps1', 'AudioFileForPhone.ManagedSetup.ps1', 'Check-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1')) {
        $hash = [string]$Record.build.$name
        $safe.build[$name] = if ($hash -match '^[0-9a-fA-F]{64}$') { $hash.ToLowerInvariant() } elseif ($hash -cin @('MISSING', 'UNREADABLE')) { $hash } else { 'unavailable' }
    }
    foreach ($name in @('version', 'os_version')) {
        $value = [string]$Record.host.$name
        $safe.host[$name] = if ($value -match '^\d+(?:\.\d+){1,3}$') { $value } else { 'unavailable' }
    }
    $safe.host.client_build = if ([string]$Record.client.build -match '^\d+\.\d+$') { [string]$Record.client.build } else { 'unavailable' }
    foreach ($name in @('os_x64', 'process_x64')) { $safe.host[$name] = $Record.host.$name -is [bool] -and $Record.host.$name }
    $safe.host.edition = if ($Record.host.edition -cin @('Core', 'Desktop')) { [string]$Record.host.edition } else { 'unavailable' }
    $safe.host.apartment = if ($Record.host.apartment -cin @('STA', 'MTA', 'Unknown')) { [string]$Record.host.apartment } else { 'Unknown' }
    $safe.host.path = '[HOST]'
    $safe.tools.origin = if ($Record.tools.origin -cin @('Explicit', 'Saved', 'AppLocal', 'PATH', 'Unresolved')) { [string]$Record.tools.origin } else { 'Unresolved' }
    foreach ($key in @('ffmpeg', 'ffprobe')) {
        $tool = $Record.tools.$key
        if ($null -eq $tool) { $safe.tools[$key] = $null; continue }
        $hash = [string]$tool.sha256
        $architecture = if ($tool.architecture -cin @('x64', 'x86', 'ARM64', 'Unknown')) { [string]$tool.architecture } else { 'Unknown' }
        # Vendor version banners are free text. Export only a narrow release/build token.
        $version = [regex]::Match([string]$tool.version, '^(?:ffmpeg|ffprobe) version ((?:[0-9]{4}-[0-9]{2}-[0-9]{2}-git-[0-9a-f]{7,40}|[0-9]+\.[0-9]+(?:\.[0-9]+)?))(?=[\s\-]|$)').Groups[1].Value
        $safe.tools[$key] = [ordered]@{ path = '[TOOL]'; version = $(if ($version) { $version } else { 'omitted' }); architecture = $architecture
            sha256 = $(if ($hash -match '^[0-9a-fA-F]{64}$') { $hash.ToLowerInvariant() } else { 'unavailable' }) }
    }
    if ($null -ne $Record.native) {
        $status = if ($Record.native.status -cin @('Completed', 'Timeout', 'Cancelled', 'StartFailed', 'MissingExecutable', 'InvalidExecutablePath')) { [string]$Record.native.status } else { 'omitted' }
        $safe.native = [ordered]@{ status = $status; executable = '[TOOL]'; process_released = ($Record.native.process_released -is [bool] -and $Record.native.process_released)
            pipe_drain_completed = ($Record.native.pipe_drain_completed -is [bool] -and $Record.native.pipe_drain_completed); detail = 'Native free-text errors/arguments omitted; consult the PRIVATE local record.' }
        foreach ($name in @('exit_code', 'elapsed_ms')) { if ($Record.native.$name -is [ValueType] -and [string]$Record.native.$name -match '^-?\d{1,12}$') { $safe.native[$name] = [long]$Record.native.$name } }
    }
    foreach ($name in @('total', 'converted', 'failed', 'exit_code')) { if ([string]$Record.totals.$name -match '^-?\d{1,12}$') { $safe.totals[$name] = [long]$Record.totals.$name } }
    if ($null -ne $Record.PSObject.Properties['check'] -and $null -ne $Record.check) {
        $check = $Record.check
        $safe.check = [ordered]@{ status = $(if ($check.status -cin @('Success', 'Failed', 'Cancelled')) { [string]$check.status } else { 'Failed' })
            sample_rates_hz = @($check.sample_rates_hz | Where-Object { $_ -is [int] -and $_ -in @(8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000) } | Select-Object -First 9)
            self_test = $null }
        if ($null -ne $check.self_test) {
            $selfTest = $check.self_test
            $safe.check.self_test = [ordered]@{
                status = $(if ($selfTest.status -cin @('Success', 'Failed', 'Unavailable', 'Cancelled')) { [string]$selfTest.status } else { 'Failed' })
                code = $(if ($selfTest.code -cin @('SelfTestPassed', 'SelfTestFailed', 'SELF_TEST_UNAVAILABLE', 'SelfTestCleanupRetained', 'Cancelled')) { [string]$selfTest.code } else { 'SelfTestFailed' }) }
            foreach ($name in @('exit_code', 'bitrate', 'sample_rate', 'channels')) {
                if ([string]$selfTest.$name -match '^\d{1,9}$') { $safe.check.self_test[$name] = [long]$selfTest.$name }
            }
            foreach ($name in @('source_unchanged', 'cleanup_verified', 'process_released', 'pipe_drain_completed')) { $safe.check.self_test[$name] = $selfTest.$name -is [bool] -and $selfTest.$name }
        }
    }
    return ($safe | ConvertTo-Json -Depth 8)
}

function Export-AudioSupportReport {
    param([Parameter(Mandatory = $true)][object]$Record, [Parameter(Mandatory = $true)][string]$Path)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $text = ConvertTo-AudioSupportReport -Record $Record
    Write-AudioDiagnosticFile -Path $full -Text $text
    Write-Host ('[SUPPORT] Review this redacted text before sharing; no upload occurred: ' + $full)
    return $full
}
