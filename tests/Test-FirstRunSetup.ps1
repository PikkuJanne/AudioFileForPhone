<#
S05 production first-run/setup flows with real Windows FFmpeg and owned synthetic
audio. Only the UI adapters are scripted; no physical dialog or owner observation
is claimed. Application/helper/setup copies remain byte-identical. The exact first
helper-load Join-Path interception is test-only and never shipped. Everything
mutable stays in one exclusively reserved, token-owned TEMP tree. Reports retain
the historical T17 CI contract and add the active S05 report contract.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S05-firstrunsetup-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-firstrunsetup-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S05-firstrunsetup active report or historical T17-firstrunsetup CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S05-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s05-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'tests/Test-FirstRunSetup.ps1', '.github/scripts/Invoke-CiChecks.ps1')
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S05' }); mode = 'real_windows_first_run_with_scripted_UI_adapters'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; physical_dialog_evidence = 'NOT_RUN'; UI_interaction = 'scripted setup availability/read/directory adapters plus metadata ready defaults adapter; no physical dialog or owner interaction'
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; persistent_environment_writes = $false
    cleanup_verified = $false; descendant_release_proved = $false; native_runs = @(); tools = @(); cases = @()
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Assert-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$NoBom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding(-not $NoBom.IsPresent)
        $preamble = $encoding.GetPreamble(); $stream.Write($preamble, 0, $preamble.Length)
        $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
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
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Invoke-WithPath {
    param([string]$PathValue, [scriptblock]$Body)
    $saved = $env:PATH; try { $env:PATH = $PathValue; & $Body } finally { $env:PATH = $saved }
}
function Invoke-TrackedNative {
    param([string]$ExecutablePath, [string[]]$Arguments, [int]$MaxStdoutChars = 1048576, [int]$MaxStderrChars = 65536,
        [object]$Cancellation = (Get-AudioCancellationContext), [scriptblock]$ProgressCallback, [object]$ProgressDurationSeconds,
        [object]$ProgressParser, [object]$ProgressCallbackState, [int]$TimeoutMilliseconds = 0,
        [string]$Operation = 'Native operation', [int]$PipeDrainTimeoutMilliseconds = 5000)
    try {
        $native = & $script:originalNative @PSBoundParameters
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) { $script:releaseProved = $false }
        $nativeRuns.Add([pscustomobject]@{ operation = $native.Operation; status = $native.Status; exit_code = $native.ExitCode; elapsed_ms = $native.ElapsedMilliseconds; timeout_ms = $native.TimeoutMilliseconds; process_released = $native.ProcessReleased; pipe_drain_completed = $native.PipeDrainCompleted })
        return $native
    } catch { $script:releaseProved = $false; throw }
}
function Assert-NativeComplete {
    param([object]$Result, [switch]$Success)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ProcessReleased -and $Result.PipeDrainCompleted -and -not $Result.StdoutTruncated -and -not $Result.StderrTruncated) ('Expected completed, drained, released native process: ' + $Result.Status + ' ' + $Result.Error)
    if ($Success) { Assert-True ($Result.ExitCode -eq 0) ('Native operation failed: ' + $Result.Stderr) }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
$guardLoader = @'
. $global:S05ExpectedHelper
$script:S05OriginalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
        [object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,
        [object]$ProgressParser,[object]$ProgressCallbackState,[int]$TimeoutMilliseconds=0,
        [string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    if ($global:S05ForbidNative) { $global:S05Forbidden.Add('native'); throw 'Preview must never execute a native process.' }
    $proof = [pscustomobject]@{operation=$Operation;status='not returned';process_released=$false;pipe_drain_completed=$false}
    $global:S05NativeProofs.Add($proof)
    $native = & $script:S05OriginalNative @PSBoundParameters
    $proof.status=$native.Status; $proof.process_released=[bool]$native.ProcessReleased; $proof.pipe_drain_completed=[bool]$native.PipeDrainCompleted
    return $native
}
if ($global:S05ScriptedUI) {
    function Test-AudioMetadataInteractionAvailable { return $true }
    function Read-AudioMetadataResponse {
        param([string]$Prompt)
        # S07 adds an explicit ready menu after setup. Keep the retained S05
        # setup-response queue and assertions unchanged by choosing defaults.
        return ''
    }
    function Test-AudioSetupInteractionAvailable { return $true }
    function Read-AudioSetupResponse {
        param([string]$Prompt)
        $global:S05SetupPrompts.Add($Prompt)
        if ($global:S05Responses.Count -eq 0) { throw 'Unexpected extra production setup prompt.' }
        return $global:S05Responses.Dequeue()
    }
    function Select-AudioSetupDirectory {
        $global:S05DialogCalls++
        return [pscustomobject]@{Status=$global:S05DialogStatus;Directory=$global:S05DialogDirectory;Error='Simulated dialog condition for automated coverage'}
    }
}
if ($global:S05ForceHostRead) {
    # Exercise the production Host.UI.ReadLine authority in -NonInteractive,
    # even when the preliminary console-availability check would refuse first.
    function Test-AudioSetupInteractionAvailable { return $true }
}
if ($global:S05ForbidSetup) {
    function Invoke-AudioToolSetup { $global:S05Forbidden.Add('setup'); throw 'Noninteractive/preview setup call.' }
    function Save-AudioToolSelection { $global:S05Forbidden.Add('settings write'); throw 'Noninteractive/preview settings write.' }
    function Read-AudioSetupResponse { $global:S05Forbidden.Add('setup prompt'); throw 'Noninteractive/preview setup prompt.' }
    function Select-AudioSetupDirectory { $global:S05Forbidden.Add('dialog'); throw 'Noninteractive/preview dialog.' }
}
if ($global:S05ForbidNative) {
    function Read-AudioToolConfig { $global:S05Forbidden.Add('config read'); throw 'Preview config read.' }
    function Resolve-AudioToolSelection { $global:S05Forbidden.Add('tool resolution'); throw 'Preview tool resolution.' }
}
'@
function Invoke-ProductionChild {
    param([string]$Label, [string]$Command, [object[]]$Responses = @(), [string]$DialogStatus = 'Unavailable', [string]$DialogDirectory = '',
        [switch]$ScriptedUI, [switch]$ForbidSetup, [switch]$Preview, [switch]$ForceHostRead)
    $loader = Join-Path $testRoot ($Label + '-loader.ps1'); Write-NewText $loader $guardLoader; Add-Fixture $loader
    $driver = Join-Path $testRoot ($Label + '-driver.ps1')
    $code = @(
        '$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''; $global:LASTEXITCODE=0',
        # Match the retained help/regression drivers: the native host redirects
        # UTF-8 streams, so its owned PS5.1 child must emit UTF-8 as well.
        '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$global:S05ExpectedHelper=' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
        ('$global:S05Loader=' + (Get-Literal $loader)),
        ('$global:S05ScriptedUI=$' + $ScriptedUI.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S05ForceHostRead=$' + $ForceHostRead.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S05ForbidSetup=$' + $ForbidSetup.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S05ForbidNative=$' + $Preview.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S05DialogStatus=' + (Get-Literal $DialogStatus)),
        ('$global:S05DialogDirectory=' + (Get-Literal $DialogDirectory)),
        '$global:S05Loads=0; $global:S05DialogCalls=0; $global:S05Responses=New-Object ''System.Collections.Generic.Queue[object]''',
        '$global:S05Forbidden=New-Object ''System.Collections.Generic.List[string]''; $global:S05SetupPrompts=New-Object ''System.Collections.Generic.List[string]''; $global:S05NativeProofs=New-Object ''System.Collections.Generic.List[object]'''
    )
    foreach ($response in $Responses) { $code += '$global:S05Responses.Enqueue(' + $(if ($null -eq $response) { '$null' } else { Get-Literal ([string]$response) }) + ')' }
    $code += @'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($global:S05Loads -eq 0 -and $actual -ieq $global:S05ExpectedHelper) { $global:S05Loads++; return $global:S05Loader }
    return $actual
}
function global:Read-Host {
    param([string]$Prompt)
    if (-not $global:S05ScriptedUI) { $global:S05Forbidden.Add('Read-Host'); throw 'Unexpected Read-Host.' }
    # Existing metadata flow is preserved. Only its three opt-in questions get N.
    if ($Prompt -match 'Add album cover|Set Artist|Set Album') { return 'N' }
    $global:S05Forbidden.Add('unrecognized Read-Host'); throw ('Unexpected metadata prompt: ' + $Prompt)
}
function global:Invoke-WebRequest { $global:S05Forbidden.Add('download'); throw 'Unexpected download.' }
function global:Invoke-RestMethod { $global:S05Forbidden.Add('network'); throw 'Unexpected network.' }
function global:Start-BitsTransfer { $global:S05Forbidden.Add('BITS'); throw 'Unexpected transfer.' }
try {
'@
    $code += $Command
    $code += @'
} finally {
    Write-Host ('[S05_AUDIT] ' + ([pscustomobject]@{output_encoding_codepage=[Console]::OutputEncoding.CodePage;helper_loads=$global:S05Loads;dialog_calls=$global:S05DialogCalls;setup_prompts=@($global:S05SetupPrompts.ToArray());remaining_responses=$global:S05Responses.Count;native_proofs=@($global:S05NativeProofs.ToArray());forbidden_calls=@($global:S05Forbidden.ToArray())} | ConvertTo-Json -Depth 6 -Compress))
}
exit $LASTEXITCODE
'@
    Write-NewText $driver ($code -join "`r`n"); Add-Fixture $driver
    $previousRelease = $script:releaseProved; $script:releaseProved = $false
    $native = Invoke-WithPath '' { Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo','-NoProfile','-NonInteractive','-OutputFormat','Text','-ExecutionPolicy','RemoteSigned','-File',$driver) -TimeoutMilliseconds 120000 -Operation ('S05 production child ' + $Label) -MaxStdoutChars 1048576 -MaxStderrChars 65536 }
    Assert-NativeComplete $native
    $text = $native.Stdout + "`n" + $native.Stderr
    Write-NewText (Join-Path $testRoot ($Label + '.log')) $text
    $audits = @($text -split '\r?\n' | Where-Object { $_.StartsWith('[S05_AUDIT] ', [StringComparison]::Ordinal) })
    Assert-True ($audits.Count -eq 1) 'Production child must emit one finally audit before cleanup.'
    $audit = $audits[0].Substring(12) | ConvertFrom-Json
    Assert-True ($audit.output_encoding_codepage -eq 65001) 'Owned redirected PowerShell children must emit UTF-8 without losing Unicode repair paths.'
    Assert-True (@($audit.native_proofs | Where-Object { -not $_.process_released -or -not $_.pipe_drain_completed }).Count -eq 0) 'Every production native invocation must prove release and pipe completion.'
    $script:releaseProved = $previousRelease
    Assert-True ($audit.helper_loads -eq 1 -and @($audit.forbidden_calls).Count -eq 0) ('Production helper load or forbidden-call guard failed: ' + $text.Replace($testRoot,'<OWNED_TEMP>'))
    if ($native.ExitCode -ne 0) {
        Assert-True ($text -notmatch 'Ready:|Waiting for your selection') 'Setup failure or cancellation must stop before the S07 ready menu.'
    }
    return [pscustomobject]@{ ExitCode=$native.ExitCode; Text=$text; Audit=$audit }
}
function Get-AppCommand {
    param([string]$Config, [string]$Parent, [switch]$Interactive, [switch]$Preview)
    $command = '& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputDir) + ' -OutputParent ' + (Get-Literal $Parent) + ' -ConfigPath ' + (Get-Literal $Config)
    if ($Interactive) { $command += ' -Interactive' }; if ($Preview) { $command += ' -DryRun' }
    return $command
}
function Assert-Conversion {
    param([string]$Parent, [object]$Child)
    Assert-True ($Child.ExitCode -eq 0) ('Expected production conversion success: ' + $Child.Text.Replace($testRoot,'<OWNED_TEMP>'))
    $runs = @(Get-ChildItem -LiteralPath $Parent -Directory)
    Assert-True ($runs.Count -eq 1) 'Expected exactly one production output run.'
    $manifest = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json')) | ConvertFrom-Json
    Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.policies.bitrate_kbps -eq 64 -and $manifest.tools.ffmpeg.path -ceq $ffmpeg -and $manifest.tools.ffprobe.path -ceq $ffprobe) 'Actual conversion must complete one synthetic input at default64 using the exact external pair.'
    $output = Join-Path $runs[0].FullName $manifest.records[0].output_relative_path
    $probed = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v','error','-show_streams','-show_format','-of','json',$output) -TimeoutMilliseconds 15000 -Operation 'S05 independent converted output probe'; Assert-NativeComplete $probed -Success
    $probe = $probed.Stdout | ConvertFrom-Json; $streams = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
    Assert-True ($streams.Count -eq 1 -and $streams[0].codec_name -ceq 'mp3' -and [int]$streams[0].bit_rate -eq 64000 -and $probe.format.tags.artist -ceq 'S05 synthetic artist') 'Independent output probe must verify 64 kbps MP3 and preserved artist.'
    $decoded = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL') -Operation 'S05 independent complete output decode'; Assert-NativeComplete $decoded -Success
    Assert-True ($decoded.TimeoutMilliseconds -eq 0) 'Full decode must keep unlimited normal runtime.'
    Assert-True (@(Get-ChildItem -LiteralPath $runs[0].FullName -Recurse -File | Where-Object { $_.Name -match '\.partial' }).Count -eq 0) 'Completed setup conversion must leave no partial files.'
    return [pscustomobject]@{ exit_code=$Child.ExitCode; converted=$manifest.totals.converted; bitrate_kbps=64; selection_origin=$manifest.tools.selection_origin; full_decode=$true; output_sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant() }
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Run this suite from the inherited UTF8 CP65001 console.'
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Exact TEMP directory must be exclusively reserved.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new = $true
    $appRoot = New-Directory ("App [literal] O'Brien " + [char]0xE4)
    foreach ($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1','Setup-AudioFileForPhone.ps1','Setup-AudioFileForPhone.bat')) {
        $copy = Join-Path $appRoot $name; Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Production copies must preserve exact repository bytes.'
        Add-Fixture $copy
    }
    $report.copied_bytes_unchanged = $true
    $script:originalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $toolDirectory = Split-Path -Parent $ffmpeg
    Assert-True ((Split-Path -Parent $ffprobe) -ieq $toolDirectory) 'Real fixture binaries must share one selected external bin directory.'
    foreach ($tool in @($ffmpeg,$ffprobe)) {
        Assert-NoReparse $tool
        $identity = Invoke-AudioNativeProcess -ExecutablePath $tool -Arguments @('-version') -TimeoutMilliseconds 15000 -Operation 'S05 external fixture identity'; Assert-NativeComplete $identity -Success
        $report.tools += [pscustomobject]@{ name=[IO.Path]::GetFileName($tool); sha256=(Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant(); version=($identity.Stdout -split '\r?\n')[0] }
    }
    $inputDir = New-Directory 'Synthetic input [x]'; $audio = Join-Path $inputDir '2024-02-03 - Tiny.mp3'
    $generated = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.25','-c:a','libmp3lame','-metadata','artist=S05 synthetic artist',$audio) -TimeoutMilliseconds 15000 -Operation 'S05 generate owned synthetic input'; Assert-NativeComplete $generated -Success; Add-Fixture $audio
    $configRoot = New-Directory 'Owned config [x]'; $rememberedConfig = Join-Path $configRoot 'Remembered.json'

    Invoke-Case 'production first launch repairs missing tools by typed fallback remembers and converts in the same launch' 'S05-A1,S05-A2' {
        param($case)
        $parent = Join-Path $testRoot 'Remembered output [x]'
        $child = Invoke-ProductionChild 'InteractiveRemember' (Get-AppCommand $rememberedConfig $parent -Interactive) -Responses @('S',$toolDirectory,'Y') -ScriptedUI
        $case['conversion'] = Assert-Conversion $parent $child
        Assert-True ($child.Audit.dialog_calls -eq 1 -and $child.Audit.setup_prompts.Count -eq 3 -and $child.Audit.remaining_responses -eq 0) 'Typed fallback must have exactly menu/path/remember prompts and one unavailable dialog.'
        Assert-True ((Read-AudioToolConfig -ConfigPath $rememberedConfig).ffmpeg_directory -ceq $toolDirectory) 'Deliberate first-run remember must use S04 config save API.'
        $case['PATH'] = 'empty'; $case['interaction'] = 'scripted production UI adapters; actual conversion'; $case['dialog_unavailable_typed_fallback'] = $true
    }
    Invoke-Case 'fresh independent noninteractive launch uses saved choice without setup or settings mutation' 'S05-A1,S05-A3' {
        param($case)
        $before = (Get-FileHash -LiteralPath $rememberedConfig).Hash
        $parent = Join-Path $testRoot 'Fresh saved output'
        $child = Invoke-ProductionChild 'FreshSaved' (Get-AppCommand $rememberedConfig $parent) -ForbidSetup
        $case['conversion'] = Assert-Conversion $parent $child
        Assert-True ($case.conversion.selection_origin -ceq 'Saved' -and $child.Audit.setup_prompts.Count -eq 0 -and (Get-FileHash -LiteralPath $rememberedConfig).Hash -ceq $before) 'Fresh process must read saved location without prompting or writing.'
        $case['config_unchanged'] = $true; $case['PATH'] = 'empty'
    }
    Invoke-Case 'declining remember continues actual conversion for current launch only' 'S05-A1,S05-A2' {
        param($case)
        $config = Join-Path $configRoot 'DoNotRemember.json'; $parent = Join-Path $testRoot 'Not remembered output'
        $child = Invoke-ProductionChild 'NoRemember' (Get-AppCommand $config $parent -Interactive) -Responses @('S','N') -DialogStatus 'Selected' -DialogDirectory $toolDirectory -ScriptedUI
        $case['conversion'] = Assert-Conversion $parent $child
        Assert-True (-not (Test-Path -LiteralPath $config) -and $child.Audit.remaining_responses -eq 0) 'Declining remember must never create settings.'
        $case['settings_created'] = $false
    }
    Invoke-Case 'read-only stale config save failure is explicit preserves bytes and allows current launch conversion' 'S05-A2' {
        param($case)
        $config = Join-Path $configRoot 'ReadOnlyStale.json'
        Write-NewText $config ([ordered]@{schema_version=1;ffmpeg_directory=(Join-Path $testRoot 'Removed tools');unrelated='preserve'} | ConvertTo-Json)
        Add-Fixture $config; $before = (Get-FileHash -LiteralPath $config).Hash
        [IO.File]::SetAttributes($config, [IO.FileAttributes]::ReadOnly)
        try {
            $parent = Join-Path $testRoot 'Failed save current output'
            $child = Invoke-ProductionChild 'FailedSave' (Get-AppCommand $config $parent -Interactive) -Responses @('S','Y') -DialogStatus 'Selected' -DialogDirectory $toolDirectory -ScriptedUI
            $case['conversion'] = Assert-Conversion $parent $child
            Assert-True ($child.Text -match '(?i)not remembered|not saved|could not.*remember' -and (Get-FileHash -LiteralPath $config).Hash -ceq $before) 'Failed save must disclose not remembered and preserve previous bytes.'
        } finally { [IO.File]::SetAttributes($config, [IO.FileAttributes]::Normal) }
        $case['previous_config_unchanged'] = $true; $case['current_launch_completed'] = $true
    }
    Invoke-Case 'menu dialog remember and EOF cancellations are bounded before output or settings creation' 'S05-A2' {
        param($case)
        $rows = @(
            @{label='MenuCancel';responses=@('Q');status='Unavailable';directory=''},
            @{label='DialogCancel';responses=@('S');status='Cancelled';directory=''},
            @{label='RememberCancel';responses=@('S','Q');status='Selected';directory=$toolDirectory},
            @{label='RememberEof';responses=@('S',$null);status='Selected';directory=$toolDirectory},
            @{label='MenuEof';responses=@($null);status='Unavailable';directory=''},
            @{label='TypedEof';responses=@('S',$null);status='Unavailable';directory=''}
        )
        $observations = @()
        foreach ($row in $rows) {
            $config = Join-Path $configRoot ($row.label + '.json'); $parent = Join-Path $testRoot ($row.label + ' output')
            $child = Invoke-ProductionChild $row.label (Get-AppCommand $config $parent -Interactive) -Responses $row.responses -DialogStatus $row.status -DialogDirectory $row.directory -ScriptedUI
            Assert-True ($child.ExitCode -eq 130 -and -not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath $parent) -and $child.Audit.remaining_responses -eq 0) ('Cancellation must exit130 without writes: ' + $row.label + ' ' + $child.Text.Replace($testRoot,'<OWNED_TEMP>'))
            $observations += [pscustomobject]@{condition=$row.label;exit_code=$child.ExitCode;setup_prompts=$child.Audit.setup_prompts.Count;output_created=$false;config_created=$false}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'manual and separate download choices return bounded guidance without pretending setup succeeded' 'S05-A2,S06-A1' {
        param($case)
        $observations = @()
        foreach ($mode in @('M','D')) {
            $config = Join-Path $configRoot ($mode + '-NotConfigured.json'); $parent = Join-Path $testRoot ($mode + ' output')
            $child = Invoke-ProductionChild ('Guidance' + $mode) (Get-AppCommand $config $parent -Interactive) -Responses @($mode) -ScriptedUI
            Assert-True ($child.ExitCode -eq 1 -and -not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath $parent) -and $child.Audit.setup_prompts.Count -eq 1) 'Guidance-only choice must stop without tools, settings or output.'
            if ($mode -ceq 'M') { Assert-True ($child.Text -match '(?i)ffmpeg.exe' -and $child.Text -match '(?i)ffprobe.exe' -and $child.Text -match 'Setup-AudioFileForPhone.ps1') 'Manual/offline instructions must identify both binaries and exact setup entry.' }
            else { Assert-True ($child.Text -match 'Conversion never downloads tools' -and $child.Text -match 'Setup-AudioFileForPhone.ps1' -and $child.Text -match 'No files were downloaded') 'Conversion must direct optional download to separate setup without network or configuration changes.' }
            $observations += [pscustomobject]@{choice=$mode;exit_code=$child.ExitCode;native_calls=$child.Audit.native_proofs.Count;settings_created=$false}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'invalid pair selection reports missing companion and never remembers or retries invisibly' 'S05-A2' {
        param($case)
        $invalidPair = New-Directory 'Invalid pair [one missing]'
        $copy = Join-Path $invalidPair 'ffmpeg.exe'; Copy-Item -LiteralPath $ffmpeg -Destination $copy; Add-Fixture $copy
        $config = Join-Path $configRoot 'InvalidPair.json'; $parent = Join-Path $testRoot 'Invalid pair output'
        $child = Invoke-ProductionChild 'InvalidPair' (Get-AppCommand $config $parent -Interactive) -Responses @('S') -DialogStatus 'Selected' -DialogDirectory $invalidPair -ScriptedUI
        Assert-True ($child.ExitCode -eq 1 -and $child.Text -match 'ffprobe.exe' -and $child.Audit.setup_prompts.Count -eq 1 -and -not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath $parent)) 'Invalid selected pair must stop before remember or output.'
        $case['exit_code'] = $child.ExitCode; $case['settings_created'] = $false; $case['retry_count'] = 0
    }
    Invoke-Case 'redirected noninteractive host cannot open first-run interaction and returns exact repair action' 'S05-A2,S05-A3' {
        param($case)
        $config = Join-Path $configRoot 'UnavailableHost.json'; $parent = Join-Path $testRoot 'Unavailable host output'
        $child = Invoke-ProductionChild 'UnavailableHost' (Get-AppCommand $config $parent -Interactive)
        Assert-True ($child.ExitCode -eq 1 -and $child.Text -match 'Setup-AudioFileForPhone.ps1' -and $child.Text -match '(?i)interactive|redirect|console' -and -not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath $parent)) 'Unavailable interaction must fail boundedly with repair command, no Read-Host or dialog.'
        $case['host'] = 'real -NonInteractive child, redirected stdout/stderr'; $case['exit_code'] = $child.ExitCode
    }
    Invoke-Case 'production response reader respects actual NonInteractive host authority when console precheck passes' 'S05-A2,S05-A3' {
        param($case)
        $config = Join-Path $configRoot 'HostReadRefused.json'; $parent = Join-Path $testRoot 'Host read refused output'
        $child = Invoke-ProductionChild 'HostReadRefused' (Get-AppCommand $config $parent -Interactive) -ForceHostRead
        Assert-True ($child.ExitCode -eq 1 -and $child.Text -match '(?i)noninteractive|non-interactive' -and $child.Audit.dialog_calls -eq 0 -and -not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath $parent)) 'The real host must refuse Host.UI.ReadLine with no retry, dialog, output or config write.'
        $case['adapter_override'] = 'availability only; production response reader unchanged'; $case['exit_code'] = 1
    }
    Invoke-Case 'noninteractive missing stale and corrupt config paths never prompt save download or create outputs' 'S05-A3' {
        param($case)
        $stale = Join-Path $configRoot 'NoninteractiveStale.json'; Write-NewText $stale ([ordered]@{schema_version=1;ffmpeg_directory=(Join-Path $testRoot 'Removed again')} | ConvertTo-Json); Add-Fixture $stale
        $corrupt = Join-Path $configRoot 'NoninteractiveCorrupt.json'; Write-NewText $corrupt '{"broken"'; Add-Fixture $corrupt
        $observations = @()
        foreach ($config in @((Join-Path $configRoot 'NoninteractiveMissing.json'),$stale,$corrupt)) {
            $label = [IO.Path]::GetFileNameWithoutExtension($config); $parent = Join-Path $testRoot ($label + ' output')
            $before = if (Test-Path -LiteralPath $config) { (Get-FileHash -LiteralPath $config).Hash } else { $null }
            $child = Invoke-ProductionChild $label (Get-AppCommand $config $parent) -ForbidSetup
            $repair = Get-AudioSetupRepairCommand -ScriptDirectory $appRoot -ConfigPath $config
            if (-not $child.Text.Contains($repair)) {
                $case['expected_repair'] = $repair.Replace($testRoot,'<OWNED_TEMP>')
                $case['observed_diagnostic'] = $child.Text.Replace($testRoot,'<OWNED_TEMP>')
            }
            Assert-True ($child.ExitCode -eq 1 -and $child.Text.Contains($repair) -and $child.Audit.setup_prompts.Count -eq 0 -and -not (Test-Path -LiteralPath $parent)) 'Noninteractive dependency failure must contain exact repair command and no setup/output.'
            if ($null -eq $before) { Assert-True (-not (Test-Path -LiteralPath $config)) 'Missing config must not be created.' } else { Assert-True ((Get-FileHash -LiteralPath $config).Hash -ceq $before) 'Failed noninteractive path must preserve config bytes.' }
            $observations += [pscustomobject]@{condition=$label;exit_code=$child.ExitCode;exact_repair_command=$true;config_unchanged=$true;prompt_count=0}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'preview with Interactive and corrupt config never reads setup state prompts downloads persists or invokes tools' 'S05-A3' {
        param($case)
        $config = Join-Path $configRoot 'PreviewCorrupt.json'; Write-NewText $config '{"corrupt"'; Add-Fixture $config
        $before = (Get-FileHash -LiteralPath $config).Hash; $parent = Join-Path $testRoot 'Preview output'
        $child = Invoke-ProductionChild 'Preview' (Get-AppCommand $config $parent -Interactive -Preview) -ForbidSetup -Preview
        Assert-True ($child.ExitCode -eq 0 -and $child.Text -match '\[PREVIEW\]' -and $child.Audit.native_proofs.Count -eq 0 -and $child.Audit.setup_prompts.Count -eq 0 -and -not (Test-Path -LiteralPath $parent) -and (Get-FileHash -LiteralPath $config).Hash -ceq $before) 'Preview must remain side-effect free regardless of Interactive or malformed config.'
        $case['exit_code'] = 0; $case['native_calls'] = 0; $case['config_bytes_unchanged'] = $true
    }
    Invoke-Case 'separate explicit setup entry validates real external pair and only deliberately remembers' 'S05-A1,S05-A3' {
        param($case)
        $config = Join-Path $configRoot 'SeparateSetup.json'
        $command = '& ' + (Get-Literal (Join-Path $appRoot 'Setup-AudioFileForPhone.ps1')) + ' -FfmpegDirectory ' + (Get-Literal $toolDirectory) + ' -ConfigPath ' + (Get-Literal $config) + ' -Remember -NonInteractive'
        $child = Invoke-ProductionChild 'SeparateSetup' $command
        Assert-True ($child.ExitCode -eq 0 -and (Read-AudioToolConfig -ConfigPath $config).ffmpeg_directory -ceq $toolDirectory -and $child.Audit.setup_prompts.Count -eq 0 -and $child.Audit.dialog_calls -eq 0) 'Separate explicit setup must validate/remember without prompts under explicit switches.'
        $case['exit_code'] = 0; $case['setup_only'] = $true; $case['actual_pair_validated'] = $true; $case['PATH'] = 'empty'
    }
    Invoke-Case 'separate setup distinguishes no-save requested-save failure and absent noninteractive directory' 'S05-A2,S05-A3' {
        param($case)
        $entry = '& ' + (Get-Literal (Join-Path $appRoot 'Setup-AudioFileForPhone.ps1'))
        $config = Join-Path $configRoot 'SeparateNoSave.json'
        $child = Invoke-ProductionChild 'SeparateNoSave' ($entry + ' -FfmpegDirectory ' + (Get-Literal $toolDirectory) + ' -ConfigPath ' + (Get-Literal $config) + ' -NonInteractive')
        Assert-True ($child.ExitCode -eq 0 -and $child.Text -match 'SHA256' -and $child.Text -match 'NOT remembered' -and $child.Text.Contains((Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1'))) -and -not (Test-Path -LiteralPath $config)) 'Standalone no-save must validate/hash without persistence and show quoted conversion route.'
        $failed = Join-Path $configRoot 'SeparateFailedSave.json'; Write-NewText $failed '{"schema_version":99,"keep":"unchanged"}'; Add-Fixture $failed
        $before = (Get-FileHash -LiteralPath $failed).Hash
        $saveChild = Invoke-ProductionChild 'SeparateFailedSave' ($entry + ' -FfmpegDirectory ' + (Get-Literal $toolDirectory) + ' -ConfigPath ' + (Get-Literal $failed) + ' -Remember -NonInteractive')
        Assert-True ($saveChild.ExitCode -eq 1 -and $saveChild.Text -match 'NOT remembered' -and (Get-FileHash -LiteralPath $failed).Hash -ceq $before) 'Standalone requested-save failure must return1 and preserve unknown schema bytes.'
        $missing = Join-Path $configRoot 'SeparateMissingDirectory.json'
        $missingChild = Invoke-ProductionChild 'SeparateMissingDirectory' ($entry + ' -ConfigPath ' + (Get-Literal $missing) + ' -NonInteractive')
        Assert-True ($missingChild.ExitCode -eq 1 -and $missingChild.Text -match 'FfmpegDirectory' -and $missingChild.Audit.setup_prompts.Count -eq 0 -and -not (Test-Path -LiteralPath $missing)) 'Standalone noninteractive setup without explicit directory must refuse without prompts or config writes.'
        $case['no_save_exit'] = 0; $case['failed_requested_save_exit'] = 1; $case['no_directory_noninteractive_exit'] = 1; $case['previous_config_unchanged'] = $true
    }
    Invoke-Case 'real MTA Windows runspace returns unavailable dialog without opening Windows Forms' 'S05-A2' {
        param($case)
        $runspace = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $pipeline = $null
        try {
            $runspace.ApartmentState = [Threading.ApartmentState]::MTA
            $runspace.ThreadOptions = [Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
            $runspace.Open(); $pipeline = [PowerShell]::Create(); $pipeline.Runspace = $runspace
            [void]$pipeline.AddScript('param($helper); . $helper; Select-AudioSetupDirectory').AddArgument((Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))
            $results = @($pipeline.Invoke())
            Assert-True ($pipeline.Streams.Error.Count -eq 0 -and $results.Count -eq 1 -and $results[0].Status -ceq 'Unavailable' -and $results[0].Error -match 'STA') 'Actual MTA adapter must decline before any desktop dialog.'
            $case['actual_apartment'] = 'MTA'; $case['dialog_result'] = $results[0].Status; $case['physical_dialog'] = 'NOT_RUN'
        } finally { if ($null -ne $pipeline) { $pipeline.Dispose() }; $runspace.Dispose() }
    }
    Invoke-Case 'setup BAT rejects extra and quoted-empty arguments and never pauses redirected launches' 'S05-A2,S05-A3' {
        param($case)
        $observations = @()
        foreach ($mode in @('NoArguments','Extra','QuotedEmpty','QuotedEmptyExtra')) {
            $driver = Join-Path $testRoot ('BAT-' + $mode + '.cmd')
            $arguments = switch ($mode) { 'NoArguments' { '' }; 'Extra' { ' extra' }; 'QuotedEmpty' { ' ""' }; 'QuotedEmptyExtra' { ' "" extra' } }
            # The hidden native CMD starts its own console; establish UTF-8 in
            # this owned driver before it reads the literal Unicode BAT path.
            $driverText = '@echo off' + "`r`n" + '"' + (Join-Path $env:SystemRoot 'System32\chcp.com') + '" 65001 >NUL' + "`r`ncall " + '"' + (Join-Path $appRoot 'Setup-AudioFileForPhone.bat') + '"' + $arguments + ' <NUL' + "`r`nexit /b %ERRORLEVEL%`r`n"
            Write-NewText $driver $driverText -NoBom; Add-Fixture $driver
            $native = Invoke-WithPath '' { Invoke-AudioNativeProcess -ExecutablePath (Join-Path $env:SystemRoot 'System32\cmd.exe') -Arguments @('/d','/c',$driver) -TimeoutMilliseconds 30000 -Operation ('S05 setup BAT ' + $mode) }; Assert-NativeComplete $native
            Assert-True ($native.ExitCode -eq 1 -and $native.Stdout -notmatch 'Press any key') ('BAT must preserve bounded exit1 with redirected input: ' + $mode + ' ' + $native.Stdout + $native.Stderr)
            if ($mode -cne 'NoArguments') { Assert-True ($native.Stdout -match 'accepts no arguments') 'Every supplied argument must be rejected before setup begins.' }
            else {
                if ($native.Stdout -notmatch 'explicit existing-tool directory|console input is unavailable') {
                    $case['observed_diagnostic'] = ($native.Stdout + $native.Stderr).Replace($testRoot,'<OWNED_TEMP>')
                }
                Assert-True ($native.Stdout -match 'explicit existing-tool directory|console input is unavailable') 'Double-click entry under redirected input must show direct recovery route.'
            }
            $observations += [pscustomobject]@{mode=$mode;exit_code=1;pause_shown=$false}
        }
        $case['observations'] = $observations
    }
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>'); $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    $env:PATH = $originalPath; $report.parent_path_unchanged = $env:PATH -ceq $originalPath
    $report.native_runs = $nativeRuns.ToArray(); $report.descendant_release_proved = $releaseProved
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository source bytes changed during focused tests.'
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True ($report.synthetic_unchanged -and $report.parent_path_unchanged) 'Owned immutable source/fixture bytes or parent PATH changed.'
    } catch { $report.status='fail'; $exitCode=1; $report['hash_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        Assert-True $releaseProved 'Cleanup refused because exact native descendant release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact directly owned TEMP tree and unchanged create-new owner marker.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status='fail'; $exitCode=1; $report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc']=[DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
Write-Host "$($report.task) first-run setup: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
