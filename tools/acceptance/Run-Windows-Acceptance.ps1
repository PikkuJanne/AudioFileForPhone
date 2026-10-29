<#
Local acceptance collection. No Git, test framework, SDK, network provisioning or
administrator rights are needed. Rehearsal kits can never produce accepted-candidate
records. Raw paths, source hashes and child diagnostics stay in the new local session.
#>
[CmdletBinding()]
param(
    [string]$SourceDirectory,
    [string]$FfmpegDirectory,
    [string]$PowerShell7Path,
    [string]$KitArchivePath,
    [string]$SessionParent,
    [switch]$AutomatedOnly,
    [switch]$Rehearsal
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Acceptance.Common.ps1')
. (Join-Path $PSScriptRoot 'Export-AcceptanceReport.ps1')
. (Join-Path $PSScriptRoot 'Acceptance.Physical.ps1')
$utf8 = New-Object Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$session = $null; $kit = $null; $selection = $null; $exitCode = 1
$private = [ordered]@{ children = @(); source_before = @(); conversions = @(); error = $null; package = $null }
$report = [ordered]@{
    schema_version = 1; kind = 'acceptance_collection'; status = 'FAILED'
    started_utc = [DateTime]::UtcNow.ToString('o'); ended_utc = $null
    source_commit = $null; runtime_version = $null; runtime_zip_sha256 = $null
    acceptance_kit_sha256 = $null; runtime_hashes = @(); environment = $null
    dependencies = @(); hosts = @(); cases = @(); issue_code = 'INITIALIZATION'
    human_observations = [ordered]@{ physical_shortcut = 'NOT_TESTED'; physical_run_verification = 'NOT_TESTED'; phone_play = 'NOT_TESTED'; phone_seek = 'NOT_TESTED' }
}

function Write-KitJson {
    param([string]$Path, [object]$Value)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write(($Value | ConvertTo-Json -Depth 24)); $writer.Flush() } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function Select-KitFolder {
    param([string]$Description)
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object Windows.Forms.FolderBrowserDialog
    try {
        $picker.Description = $Description; $picker.ShowNewFolderButton = $false
        if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw (New-Object OperationCanceledException('Selection cancelled.')) }
        return $picker.SelectedPath
    } finally { $picker.Dispose() }
}

function New-KitChildEnvironment {
    param([string]$LocalRoot)
    $null = [IO.Directory]::CreateDirectory($LocalRoot)
    return @{
        # Diagnostics honors this environment variable. Production configuration
        # does not; every automated conversion still receives explicit ConfigPath.
        LOCALAPPDATA = $LocalRoot; TEMP = $LocalRoot; TMP = $LocalRoot
        PATH = ($env:SystemRoot + '\System32;' + $env:SystemRoot)
        AUDIOFILEFORPHONE_HOST = ''; AUDIOFILEFORPHONE_INPUT = ''
        AFP_KIT_RUNTIME = $kit.runtime_directory
    }
}

function Invoke-KitHost {
    param([string]$HostPath, [string]$ScriptPath, [string[]]$ExtraArguments = @(), [hashtable]$ChildEnvironment, [string]$InputText = '')
    $driverId = [guid]::NewGuid().ToString('N').Substring(0, 10)
    $driver = Join-Path $session ('invoke-' + $driverId + '.ps1')
    $driverArguments = Join-Path $session ('arguments-' + $driverId + '.json')
    $parameters = [ordered]@{}
    for ($argumentIndex = 0; $argumentIndex -lt $ExtraArguments.Count; $argumentIndex++) {
        $name = [string]$ExtraArguments[$argumentIndex]
        if ($name -cnotmatch '^-(InputFolder|OutputParent|ConfigPath|FfmpegDirectory|Remember|NonInteractive)$') { throw 'Unexpected internal production parameter.' }
        $name = $name.Substring(1)
        if ($parameters.Contains($name)) { throw 'Duplicate internal production parameter.' }
        if ($name -cin @('Remember','NonInteractive')) { $parameters[$name] = $true }
        else { $argumentIndex++; if ($argumentIndex -ge $ExtraArguments.Count) { throw 'Missing internal production parameter value.' }; $parameters[$name] = $ExtraArguments[$argumentIndex] }
    }
    Write-KitJson $driverArguments ([ordered]@{ parameters = $parameters })
    [IO.File]::WriteAllText($driver, @'
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$document = [IO.File]::ReadAllText($env:AFP_KIT_ARGUMENTS, [Text.Encoding]::UTF8) | ConvertFrom-Json
$forward = @{}
foreach ($property in $document.parameters.PSObject.Properties) { $forward[$property.Name] = $property.Value }
$global:LASTEXITCODE = 0
& $env:AFP_KIT_TARGET @forward
exit $LASTEXITCODE
'@, (New-Object Text.UTF8Encoding($false)))
    $ChildEnvironment['AFP_KIT_TARGET'] = $ScriptPath; $ChildEnvironment['AFP_KIT_ARGUMENTS'] = $driverArguments
    $arguments = @('-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'RemoteSigned', '-File', $driver)
    $ChildEnvironment['PSModulePath'] = (Join-Path (Split-Path -Parent $HostPath) 'Modules') + ';' + (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules') + ';' + $env:PSModulePath
    $result = Invoke-AcceptanceChild -Executable $HostPath -Arguments $arguments -Environment $ChildEnvironment -StandardInput $InputText
    $private.children += [pscustomobject]@{ executable = $HostPath; script = $ScriptPath; arguments = $ExtraArguments; result = $result }
    if (-not $result.process_released -or -not $result.pipe_drain_completed -or $result.stdout_truncated -or $result.stderr_truncated) { throw 'Child release, pipe drain or bounded capture is unproved; the entire local session is retained.' }
    return $result
}

function Get-KitRun {
    param([string]$Parent)
    # This parent is new and exclusively owned. Never enumerate the Music folder.
    $roots = @(Get-ChildItem -LiteralPath $Parent -Directory -Force)
    if ($roots.Count -ne 1) { throw 'Expected one run in the exclusively owned output parent.' }
    return $roots[0].FullName
}

function Resolve-KitHost {
    param([string]$RequestedPath)
    # Reuse the packaged startup policy/architecture checks, including Store
    # execution aliases. The resolved executable must pass a second same-identity
    # check before any core application run. This is startup evidence only.
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $kit.runtime_directory 'AudioFileForPhone.Launcher.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw 'Packaged launcher does not parse.' }
    $definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Invoke-AudioHostProbe' }, $false))
    if ($definitions.Count -ne 1) { throw 'Packaged startup probe identity is ambiguous.' }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
    $probePath = Join-Path $kit.runtime_directory 'AudioFileForPhone.HostProbe.ps1'
    $probe = Invoke-AudioHostProbe -HostPath $RequestedPath -ProbePath $probePath
    $private.children += [pscustomobject]@{ route = 'packaged_startup_probe'; result = $probe }
    if ($probe.Status -cne 'Ready' -or -not $probe.ProcessReleased -or -not $probe.PipeDrainCompleted) { throw 'Requested host is blocked, unhealthy or unreleased; no alternate host or application is started.' }
    $resolved = Assert-AcceptanceLocalPath $probe.Identity.Path -MustExist
    if ($resolved -ine $RequestedPath) {
        $again = Invoke-AudioHostProbe -HostPath $resolved -ProbePath $probePath
        $private.children += [pscustomobject]@{ route = 'packaged_resolved_startup_probe'; result = $again }
        if ($again.Status -cne 'Ready' -or -not $again.ProcessReleased -or -not $again.PipeDrainCompleted) { throw 'Resolved host could not establish startup health and release.' }
        foreach ($field in @('Path','Version','Edition','ProcessArchitecture','OSArchitecture','ApartmentState','LanguageMode','MachinePolicy','UserPolicy')) {
            if ($again.Identity.$field -cne $probe.Identity.$field) { throw 'Execution-alias identity changed; no application is started.' }
        }
    }
    return $resolved
}

function Add-KitCase {
    param([string]$Id, [string]$Status, [object]$Result, [object]$EnvironmentRecord = $null)
    $row = [pscustomobject]@{ id = $Id; status = $Status; result = $Result; environment = $EnvironmentRecord }
    $report.cases += $row
    return $row
}

function Read-KitObservation {
    param([string]$Prompt)
    while ($true) {
        $answer = Read-Host ($Prompt + ' [yes / no / not tested]')
        if ($null -eq $answer) { return 'NOT_TESTED' }
        switch ($answer.Trim().ToLowerInvariant()) {
            'yes' { return 'PASSED' }
            'no' { return 'FAILED' }
            'not tested' { return 'NOT_TESTED' }
            '' { return 'NOT_TESTED' }
        }
    }
}

function Write-KitGate {
    param([string]$GateId, [object[]]$Checks, [object]$Case, [object]$EnvironmentRecord, [switch]$Human)
    if ($report.kind -cne 'candidate_collection' -or $Case.status -cne 'PASSED') { return }
    $gate = [ordered]@{
        schema_version = 1; kind = 'candidate_acceptance'; gate_id = $GateId; status = 'PASSED'
        source_commit = $kit.source_commit; runtime_zip_sha256 = $kit.runtime_zip_sha256
        acceptance_kit_sha256 = $kit.acceptance_kit_sha256; runtime_hashes = $kit.runtime_hashes
        command = $(if ($AutomatedOnly) { 'Run-Windows-Acceptance.ps1 -AutomatedOnly (exact archived runner; private arguments omitted)' } else { 'Run-Windows-Acceptance.ps1 (interactive; exact archived runner; private arguments omitted)' })
        started_utc = $report.started_utc; ended_utc = [DateTime]::UtcNow.ToString('o')
        environment = $EnvironmentRecord; checks = $Checks
    }
    if ($Human) {
        $gate.evidence_type = 'human_observation'; $gate.observer = 'local console user (self-reported)'; $gate.observed = 'PASSED'
    } else {
        # Exit0 here is the captured controlled child result, never an Explorer inference.
        $gate.exit_code = 0
    }
    if ($GateId -in @('one_file', 'full_collection')) {
        foreach ($field in @('input_count','converted_count','failed_count','unprocessed_count','source_unchanged','media_validated')) {
            $gate[$field] = $Case.result.$field
        }
    }
    Write-KitJson (Join-Path $session ($GateId + '.json')) $gate
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or -not [Environment]::Is64BitProcess -or
        $ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') { throw 'An allowed Windows x64 FullLanguage host is required; policy is never bypassed.' }
    if ([string]::IsNullOrWhiteSpace($SessionParent)) { $SessionParent = [IO.Path]::GetTempPath() }
    $SessionParent = Assert-AcceptanceLocalPath -Path $SessionParent -MustExist
    $session = Join-Path $SessionParent ('AFPA-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    if (Test-Path -LiteralPath $session) { throw 'Session collision.' }
    $null = [IO.Directory]::CreateDirectory($session)
    Write-KitJson (Join-Path $session '.owner.json') ([ordered]@{ kind = 'AudioFileForPhone.Acceptance'; token = [guid]::NewGuid().ToString('N') })
    Write-Host ('Local acceptance session: ' + $session)
    if ([string]::IsNullOrWhiteSpace($KitArchivePath)) {
        $KitArchivePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Acceptance-Kit.zip'
    }
    $report.issue_code = 'PACKAGE_IDENTITY'
    $kit = Read-AcceptanceKit -KitRoot $PSScriptRoot -KitArchivePath $KitArchivePath -ExtractDirectory (Join-Path $session 'runtime')
    $private.package = $kit
    if ($kit.manifest.kind -ceq 'rehearsal_acceptance_kit') {
        if (-not $Rehearsal) { throw 'This is a development rehearsal kit. It is not an owner release candidate.' }
        $report.kind = 'rehearsal_collection'
    } elseif ($kit.runtime_version -ceq '1.0.1' -and -not $Rehearsal) { $report.kind = 'candidate_collection' }
    else { throw 'Candidate version or rehearsal invocation mismatch.' }
    foreach ($field in @('source_commit','runtime_version','runtime_zip_sha256','acceptance_kit_sha256','runtime_hashes')) { $report[$field] = $kit.$field }
    . (Join-Path $kit.runtime_directory 'AudioFileForPhone.Helpers.ps1')
    . (Join-Path $kit.runtime_directory 'AudioFileForPhone.Diagnostics.ps1')
    $null = Add-KitCase 'package_members' 'PASSED' ([pscustomobject]@{ count = @($kit.runtime_hashes).Count; member_hashes_verified = $true })

    $report.issue_code = 'SOURCE_SELECTION'
    if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
        if ($AutomatedOnly) { throw 'Automated collection requires an explicit owned source folder.' }
        $SourceDirectory = Select-KitFolder 'Choose the source audio folder. Files remain unchanged.'
    }
    $SourceDirectory = Assert-AcceptanceLocalPath -Path $SourceDirectory -MustExist
    if ((Test-AcceptanceWithin $session $SourceDirectory) -or (Test-AcceptanceWithin $SourceDirectory $session) -or
        (Test-AcceptanceWithin $SourceDirectory $PSScriptRoot)) { throw 'Source and the kit/session workspace must be separate trees.' }
    $sourceBefore = @(Get-AcceptanceSourceInventory -Root $SourceDirectory -IncludeUnsupported)
    $supportedBefore = @($sourceBefore | Where-Object { $_.supported })
    if ($supportedBefore.Count -eq 0) { throw 'The selected folder contains no supported MP3, M4A or OGG input.' }
    $private.source_before = $sourceBefore
    $report.issue_code = 'DEPENDENCY_SELECTION'
    $config = Join-Path $session 'selection.json'
    $selectionContext = @{ NativeResult = $null; Attempts = @(); Stage = 'ToolSelection'; Code = 'DependencyInvalid'; Selection = $null }
    $options = @{ ScriptDirectory = $kit.runtime_directory; LocalOnly = $true; DiagnosticContext = $selectionContext }
    if ($AutomatedOnly) { $options.ConfigPath = $config }
    if (-not [string]::IsNullOrWhiteSpace($FfmpegDirectory)) { $options.FfmpegDirectory = $FfmpegDirectory }
    try { $selection = Resolve-AudioToolSelection @options } catch [OperationCanceledException] { throw } catch {
        if ($AutomatedOnly) { throw }
        if ($null -ne $selectionContext.NativeResult -and (-not $selectionContext.NativeResult.ProcessReleased -or -not $selectionContext.NativeResult.PipeDrainCompleted)) { throw 'Prerequisite release is unproved. No setup or further native operation is allowed.' }
        # One normal separate setup in human mode, reused by the real desktop
        # route. Its production UI owns explicit download and remember consent.
        $setup = Invoke-AudioToolSetup -ScriptDirectory $kit.runtime_directory -AllowManagedDownload
        if ($setup.Status -cne 'Ready') { throw 'Separate setup did not configure tools. Preserve this report for the kit maintainer.' }
        $selection = $setup.Selection
    }
    $toolDirectory = $selection.Directory
    if ([string]::IsNullOrWhiteSpace($toolDirectory)) { throw 'The selected FFmpeg pair must share one existing directory for the owned setup check.' }
    $report.dependencies = @('Ffmpeg','Ffprobe') | ForEach-Object { [pscustomobject]@{ name = $_.ToLowerInvariant(); origin = $selection.Origin; version = $selection.$_.Version; sha256 = (Get-FileHash -LiteralPath $selection.$_.Path).Hash.ToLowerInvariant() } }

    $report.issue_code = 'HOST_DISCOVERY'
    $hostPaths = @((Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'))
    if ([string]::IsNullOrWhiteSpace($PowerShell7Path)) {
        $pwsh = @(Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue)
        if ($pwsh.Count -gt 0) { $PowerShell7Path = $pwsh[0].Source }
        elseif (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe')) { $PowerShell7Path = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
    }
    if (-not [string]::IsNullOrWhiteSpace($PowerShell7Path)) { $hostPaths += $PowerShell7Path }
    else { $null = Add-KitCase 'ps7_unavailable' 'BLOCKED' ([pscustomobject]@{ reason = 'No installed PS7 discovered; required client cell remains missing.' }) }

    # Fixed driver text; private paths cross only the process environment.
    $identityDriver = Join-Path $session 'host-check.ps1'
    [IO.File]::WriteAllText($identityDriver, @'
$ErrorActionPreference = 'Stop'
$reg = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$os = Get-CimInstance Win32_OperatingSystem
$files = @(Get-ChildItem -LiteralPath $env:AFP_KIT_RUNTIME -File | Where-Object { $_.Extension -ceq '.ps1' })
foreach ($file in $files) {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw 'Packaged runtime parser failure.' }
}
$osArchitecture = [string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture
$processArchitecture = [string][Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
if ($osArchitecture -cne 'X64' -or $processArchitecture -cne 'X64') { throw 'Acceptance requires actual AMD64 Windows and process architecture.' }
. (Join-Path $env:AFP_KIT_RUNTIME 'AudioFileForPhone.Helpers.ps1')
[ordered]@{ os = $(if ([int]$os.ProductType -eq 1 -and [int]$reg.CurrentBuildNumber -ge 22000) { 'Windows11' } elseif ([int]$os.ProductType -eq 1) { 'Windows10' } else { 'WindowsServer' }); caption = $os.Caption; product_type = [int]$os.ProductType; architecture = 'x64'; process_64bit = [Environment]::Is64BitProcess; build = ([string]$reg.CurrentBuildNumber + '.' + [string]$reg.UBR); revision = [int]$reg.UBR; display_version = [string]$reg.DisplayVersion; shell_version = [string]$PSVersionTable.PSVersion; shell_edition = [string]$PSVersionTable.PSEdition; parser_files = $files.Count; runtime_version = Get-AudioAppVersion; apartment = [string][Threading.Thread]::CurrentThread.ApartmentState } | ConvertTo-Json -Compress
'@, $utf8)
    $oneRoot = Join-Path $session 'one-file'; $null = [IO.Directory]::CreateDirectory($oneRoot)
    $copyPath = Join-Path $oneRoot ('selected' + [IO.Path]::GetExtension($supportedBefore[0].path))
    [IO.File]::Copy($supportedBefore[0].path, $copyPath, $false)
    if ((Get-FileHash -LiteralPath $copyPath).Hash.ToLowerInvariant() -cne $supportedBefore[0].sha256) { throw 'The owned one-file copy differs from its source.' }
    $oneBefore = @(Get-AcceptanceSourceInventory -Root $oneRoot)
    $longRoot = Join-Path $session 'long-input'; $null = [IO.Directory]::CreateDirectory($longRoot)
    $longPath = Join-Path $longRoot 'synthetic-long.mp3'
    $longCreate = Invoke-AudioNativeProcess -ExecutablePath $selection.Ffmpeg.Path -Arguments @('-nostdin','-v','error','-f','lavfi','-i','anullsrc=r=22050:cl=mono','-t','3605','-c:a','libmp3lame','-b:a','64k',$longPath)
    if ($longCreate.Status -cne 'Completed' -or $longCreate.ExitCode -ne 0 -or -not $longCreate.ProcessReleased -or -not $longCreate.PipeDrainCompleted) { throw 'Long synthetic fixture creation failed or release is unproved.' }
    $longBefore = @(Get-AcceptanceSourceInventory -Root $longRoot)
    $hostRows = @(); $oneCases = @(); $longCases = @(); $firstEnvironment = $null; $batchEnvironment = $null
    $resolvedHostPaths = @()
    foreach ($requestedHostPath in $hostPaths) {
        $hostPath = Resolve-KitHost $requestedHostPath
        $resolvedHostPaths += $hostPath
        $index = $hostRows.Count + 1
        $environment = New-KitChildEnvironment (Join-Path $session ('child-' + $index))
        $identityResult = Invoke-KitHost $hostPath $identityDriver @() $environment
        if ($identityResult.exit_code -ne 0) { throw 'Installed host could not execute package/parser/client checks.' }
        $identity = $identityResult.stdout | ConvertFrom-Json
        if (-not $identity.process_64bit -or $identity.apartment -cne 'STA' -or
            ($index -eq 1 -and $identity.shell_version -notmatch '^5\.1\.') -or ($index -eq 2 -and $identity.shell_version -notmatch '^7\.')) { throw 'Host architecture, apartment or version does not match the required cell.' }
        $hostRows += $identity
        $identity | Add-Member -NotePropertyName host_id -NotePropertyValue ('host' + $index)
        $identity | Add-Member -NotePropertyName status -NotePropertyValue 'PASSED'
        if ($null -eq $firstEnvironment) { $firstEnvironment = $identity; $batchEnvironment = $environment }
        $report.environment = $firstEnvironment; $report.hosts = $hostRows
        if ($identity.runtime_version -cne $kit.runtime_version) { throw 'Packaged authoritative runtime version differs from kit identity.' }
        $null = Add-KitCase ('parser_version_host' + $index) 'PASSED' ([pscustomobject]@{ parser_files = $identity.parser_files; captured_exit_code = 0 }) $identity
        $emptyParent = Join-Path $session ('missing-' + $index); $null = [IO.Directory]::CreateDirectory($emptyParent)
        $hostConfig = Join-Path $environment.TEMP 'config.json'
        $missing = Invoke-KitHost $hostPath (Join-Path $kit.runtime_directory 'AudioFileForPhone.ps1') @('-InputFolder',$oneRoot,'-OutputParent',$emptyParent,'-ConfigPath',$hostConfig) $environment
        if ($missing.exit_code -ne 1 -or @(Get-ChildItem -LiteralPath $emptyParent -Force).Count -ne 0) { throw 'Clean child missing-tool refusal or no-write boundary failed.' }
        $saved = Invoke-KitHost $hostPath (Join-Path $kit.runtime_directory 'Setup-AudioFileForPhone.ps1') @('-FfmpegDirectory',$toolDirectory,'-ConfigPath',$hostConfig,'-Remember','-NonInteractive') $environment
        if ($saved.exit_code -ne 0) { throw 'Production existing-tool setup did not save in the owned child scope.' }
        foreach ($pair in @(@('one_file',$oneRoot,$oneBefore), @('long_file',$longRoot,$longBefore))) {
            $parent = Join-Path $session ($pair[0] + '-' + $index); $null = [IO.Directory]::CreateDirectory($parent)
            $converted = Invoke-KitHost $hostPath (Join-Path $kit.runtime_directory 'AudioFileForPhone.ps1') @('-InputFolder',$pair[1],'-OutputParent',$parent,'-ConfigPath',$hostConfig) $environment
            $runRoot = Get-KitRun $parent
            $validated = Test-AcceptanceConversion -RunDirectory $runRoot -SourceRoot $pair[1] -SourceBefore $pair[2] -RuntimeDirectory $kit.runtime_directory -FfmpegPath $selection.Ffmpeg.Path -FfprobePath $selection.Ffprobe.Path -CapturedExitCode $converted.exit_code
            $private.conversions += [pscustomobject]@{ run_directory = $runRoot; result = $validated }
            $case = Add-KitCase ($pair[0] + '_host' + $index) 'PASSED' $validated $identity
            if ($pair[0] -ceq 'one_file') { $oneCases += $case } else { $longCases += $case }
        }
        $null = Add-KitCase ('clean_saved_host' + $index) 'PASSED' ([pscustomobject]@{ missing_exit_code = $missing.exit_code; setup_exit_code = $saved.exit_code; saved_fresh_process_conversion = $true }) $identity
        $null = Add-KitCase ('missing_tools_host' + $index) 'PASSED' ([pscustomobject]@{ captured_exit_code = [int]$missing.exit_code; no_output_writes = $true }) $identity
        $null = Add-KitCase ('setup_saved_host' + $index) 'PASSED' ([pscustomobject]@{ captured_exit_code = [int]$saved.exit_code; saved_fresh_process_conversion = $true }) $identity
    }

    $report.issue_code = 'BATCH_CONVERSION'
    # The controlled collection uses the unmodified packaged PS1 with explicit
    # owned config/output. The BAT's mandatory real console and normal user
    # configuration belong to the separate physical collection below. Changing
    # LOCALAPPDATA does not redirect Windows' Known Folder configuration lookup.
    $batchParent = Join-Path $session 'collection-output'; $null = [IO.Directory]::CreateDirectory($batchParent)
    $batchConfig = Join-Path $batchEnvironment.TEMP 'config.json'
    $batch = Invoke-KitHost $resolvedHostPaths[0] (Join-Path $kit.runtime_directory 'AudioFileForPhone.ps1') @('-InputFolder',$SourceDirectory,'-OutputParent',$batchParent,'-ConfigPath',$batchConfig) $batchEnvironment
    if ($batch.exit_code -ne 0) { throw 'Production PS1 collection failed. Its private output is retained for the kit maintainer.' }
    $batchRoot = Get-KitRun $batchParent
    $batchVerified = Test-AcceptanceConversion -RunDirectory $batchRoot -SourceRoot $SourceDirectory -SourceBefore $sourceBefore -RuntimeDirectory $kit.runtime_directory -FfmpegPath $selection.Ffmpeg.Path -FfprobePath $selection.Ffprobe.Path -CapturedExitCode $batch.exit_code
    $private.conversions += [pscustomobject]@{ run_directory = $batchRoot; result = $batchVerified }
    $batchCase = Add-KitCase 'full_collection_controlled_packaged_ps1' 'PASSED' $batchVerified $firstEnvironment
    Write-Host ('Completed collection retained at: ' + $batchRoot)

    if (-not $AutomatedOnly) {
        $report.issue_code = 'PHYSICAL_SHORTCUT'
        # Explorer uses normal production configuration, not our isolated child.
        # Invoke the separate normal setup only if its actual resolver needs it.
        $desktopContext = @{ NativeResult = $null; Attempts = @(); Stage = 'ToolSelection'; Code = 'DependencyInvalid'; Selection = $null }
        $desktopSelection = $null
        try { $desktopSelection = Resolve-AudioToolSelection -ScriptDirectory $kit.runtime_directory -LocalOnly -DiagnosticContext $desktopContext }
        catch [OperationCanceledException] { throw }
        catch {
            if ($null -ne $desktopContext.NativeResult -and (-not $desktopContext.NativeResult.ProcessReleased -or -not $desktopContext.NativeResult.PipeDrainCompleted)) { throw 'Desktop prerequisite release is unproved. No setup or further native operation is allowed.' }
            if ((Read-KitObservation 'Remember the already selected FFmpeg folder for the normal desktop route') -cne 'PASSED') { throw 'Normal desktop setup was not remembered; no physical pass is inferred.' }
            $normalSetup = Invoke-AudioToolSetup -ScriptDirectory $kit.runtime_directory -FfmpegDirectory $toolDirectory -Remember -NonInteractive
            if ($normalSetup.Status -cne 'Ready' -or -not $normalSetup.Remembered) { throw 'Normal desktop setup did not save the deliberate selection.' }
            $desktopSelection = $normalSetup.Selection
        }
        if ((Get-AcceptanceHash $desktopSelection.Ffmpeg.Path) -cne $report.dependencies[0].sha256 -or
            (Get-AcceptanceHash $desktopSelection.Ffprobe.Path) -cne $report.dependencies[1].sha256) { throw 'Desktop dependency bytes differ from this collection; an affected-path retest is required.' }
        $physical = Initialize-AcceptancePhysical -RuntimeDirectory $kit.runtime_directory -SourceDirectory $SourceDirectory -SessionDirectory $session
        try { $physicalResult = Complete-AcceptancePhysical -Context $physical -SourceBefore $sourceBefore -FfmpegPath $selection.Ffmpeg.Path -FfprobePath $selection.Ffprobe.Path }
        finally { Close-AcceptancePhysical -Context $physical }
        $private.physical = $physicalResult
        $report.human_observations.physical_shortcut = $physicalResult.observation
        $report.human_observations.physical_run_verification = $physicalResult.status
        $null = Add-KitCase 'physical_shortcut' $physicalResult.status $physicalResult.conversion $firstEnvironment
        # The phone file comes from the already validated exact candidate batch.
        $manifest = Get-Content -LiteralPath (Join-Path $batchRoot 'AudioFileForPhone_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $phoneOutput = Join-Path $batchRoot $manifest.records[0].output_relative_path
        Write-Host ('Copy this candidate output to the phone: ' + $phoneOutput)
        $report.issue_code = 'PHONE_OBSERVATION'
        $report.human_observations.phone_play = Read-KitObservation 'On the phone, did a short section play correctly'
        $report.human_observations.phone_seek = Read-KitObservation 'On the phone, did seeking near the end work correctly'
    }
    if (-not (Test-AcceptanceSourceInventory -Root $SourceDirectory -Before $sourceBefore -IncludeUnsupported)) { throw 'Selected source files changed. The batch cannot pass.' }
    $report.issue_code = $null
    $report.status = if ($AutomatedOnly -or @($report.human_observations.Values | Where-Object { $_ -cne 'PASSED' }).Count -gt 0 -or $hostRows.Count -ne 2 -or $physicalResult.status -cne 'PASSED') { 'AUTOMATED_PASSED_ACCEPTANCE_INCOMPLETE' } else { 'PASSED' }

    # Only real executed paths emit matching final-candidate gate captures. Missing
    # online/offline setup and absent OS rows are never manufactured by this kit.
    $checks = @([pscustomobject]@{ id = 'counts'; status = 'PASSED'; expected = 'all supported inputs converted with no failures'; observed = 'exact manifest and independently checked output count' },
        [pscustomobject]@{ id = 'media'; status = 'PASSED'; expected = 'exact64 MP3, plan/duration, complete decode'; observed = 'all outputs independently probed and fully decoded' },
        [pscustomobject]@{ id = 'source_hashes'; status = 'PASSED'; expected = 'source inventory and hashes unchanged'; observed = 'local before/after matched; private hashes retained locally' })
    Write-KitGate 'one_file' $checks $oneCases[0] $firstEnvironment
    # Final full_collection also requires the actual BAT/shortcut collection.
    # The controlled PS1 exit0 remains distinct from the uncaptured Explorer exit.
    if (-not $AutomatedOnly -and $physicalResult.status -ceq 'PASSED') {
        $physicalBatchCheck = [pscustomobject]@{ id = 'actual_packaged_bat_collection'; status = 'PASSED'; expected = 'actual selected-folder BAT collection plus independently validated completed output'; observed = 'owner gesture and unique watched run matched; physical raw process exit not captured' }
        Write-KitGate 'full_collection' ($checks + $physicalBatchCheck) $batchCase $firstEnvironment
    }
    $exactChecks = @('member_hashes','extracted_conversion','full_decode') | ForEach-Object { [pscustomobject]@{ id = $_; status = 'PASSED'; expected = 'exact archived candidate and real validated conversion'; observed = 'verified package inventory plus captured completed and fully decoded production output' } }
    Write-KitGate 'exact_package' $exactChecks $oneCases[0] $firstEnvironment
    if (-not $AutomatedOnly -and $physicalResult.status -ceq 'PASSED') {
        $physicalChecks = @('observed_shortcut','matched_run') | ForEach-Object { [pscustomobject]@{ id = $_; status = 'PASSED'; expected = 'one real owner gesture and exact resulting manifest'; observed = 'owner report plus unique watched production run identity and independently validated media' } }
        Write-KitGate 'physical_shortcut' $physicalChecks ([pscustomobject]@{ status = 'PASSED' }) $firstEnvironment -Human
    }
    if ($report.human_observations.phone_play -ceq 'PASSED' -and $report.human_observations.phone_seek -ceq 'PASSED') {
        $phoneChecks = @('play','seek') | ForEach-Object { [pscustomobject]@{ id = $_; status = 'PASSED'; expected = 'successful phone observation on this kit candidate output'; observed = 'local console user reported yes after playing and seeking' } }
        Write-KitGate 'phone_play_seek' $phoneChecks ([pscustomobject]@{ status = 'PASSED' }) $firstEnvironment -Human
    }
    $exitCode = 0
} catch [OperationCanceledException] {
    $report.status = 'CANCELLED'; $report.issue_code = 'CANCELLED'; $private.error = $_.Exception.Message; $exitCode = 130
} catch {
    $private.error = $_.Exception.Message
    Write-Host ('Acceptance stopped at ' + $report.issue_code + '. Return REPORT.txt; no diagnostic commands or source upload are needed.')
} finally {
    $report.ended_utc = [DateTime]::UtcNow.ToString('o')
    if ($session) {
        try {
            Write-KitJson (Join-Path $session 'local-private.json') $private
            Export-AcceptanceReport -Report $report -OutputDirectory $session
            Write-Host ('Return only: ' + (Join-Path $session 'REPORT.txt'))
            if (-not $AutomatedOnly) { Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList ('"' + $session + '"') }
        } catch { Write-Host 'Report creation failed. The owned session is retained; the kit maintainer must repair this fault.'; $exitCode = 1 }
    }
}
exit $exitCode
