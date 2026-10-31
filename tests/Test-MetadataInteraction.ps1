<#
S07 production metadata-menu flows with real Windows FFmpeg and owned synthetic
audio. Only the UI adapters are scripted; no physical dialog or owner observation
is claimed. Application/helper copies remain byte-identical. The exact first
helper-load Join-Path interception is test-only and never shipped. Everything
mutable stays in one exclusively reserved, token-owned TEMP tree. Reports retain
the historical T17 CI contract and add the active S07 report contract.
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
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S07-metadatainteraction-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-metadatainteraction-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S07-metadatainteraction active report or historical T17-metadatainteraction CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S07-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s07-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ManagedSetup.ps1', 'tools/ffmpeg-download.json', 'tests/Test-MetadataInteraction.ps1', '.github/scripts/Invoke-CiChecks.ps1')
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S07' }); mode = 'real_windows_metadata_interaction_with_scripted_UI_adapters'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; physical_dialog_evidence = 'NOT_RUN'; UI_interaction = 'scripted named metadata availability/read/cover adapters; actual application and real FFmpeg'
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
. $global:S07ExpectedHelper
$script:S07OriginalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
        [object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,
        [object]$ProgressParser,[object]$ProgressCallbackState,[int]$TimeoutMilliseconds=0,
        [string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    if ($global:S07ForbidNative) { $global:S07Forbidden.Add('native'); throw 'Preview must never execute native tools.' }
    $proof=[pscustomobject]@{operation=$Operation;status='not returned';process_released=$false;pipe_drain_completed=$false;timeout_ms=$TimeoutMilliseconds}
    $global:S07NativeProofs.Add($proof)
    $native=& $script:S07OriginalNative @PSBoundParameters
    $proof.status=$native.Status; $proof.process_released=[bool]$native.ProcessReleased; $proof.pipe_drain_completed=[bool]$native.PipeDrainCompleted
    return $native
}
function Save-AudioToolSelection { $global:S07Forbidden.Add('settings write'); throw 'Metadata must never save settings.' }
function Invoke-AudioToolSetup { $global:S07Forbidden.Add('setup'); throw 'Explicit selected pair must not require setup.' }
function Read-AudioSetupResponse { $global:S07Forbidden.Add('setup prompt'); throw 'Metadata must not call setup reader.' }
function Select-AudioSetupDirectory { $global:S07Forbidden.Add('setup dialog'); throw 'Metadata must not call setup picker.' }
if ($global:S07ScriptedUI) {
    function Test-AudioMetadataInteractionAvailable { return $true }
    function Read-AudioMetadataResponse {
        param([string]$Prompt)
        $global:S07MetadataPrompts.Add($Prompt)
        if ($global:S07Responses.Count -eq 0) { $global:S07Forbidden.Add('extra metadata prompt'); throw 'Unexpected extra metadata input.' }
        return $global:S07Responses.Dequeue()
    }
    function Select-AudioMetadataCover { $global:S07DialogCalls++; return $global:S07DialogPath }
}
if ($global:S07ForceHostRead) {
    # Only availability is overridden: production Host.UI.ReadLine must refuse.
    function Test-AudioMetadataInteractionAvailable { return $true }
}
if ($global:S07ForbidNative) {
    function Read-AudioToolConfig { $global:S07Forbidden.Add('config read'); throw 'Preview config read.' }
    function Resolve-AudioToolSelection { $global:S07Forbidden.Add('tool resolution'); throw 'Preview tool resolution.' }
}
'@
function Invoke-ProductionChild {
    param([string]$Label,[string]$Command,[object[]]$Responses=@(),[string]$DialogPath='',
        [switch]$ScriptedUI,[switch]$Preview,[switch]$ForceHostRead)
    $loader=Join-Path $testRoot ($Label+'-loader.ps1'); Write-NewText $loader $guardLoader; Add-Fixture $loader
    $driver=Join-Path $testRoot ($Label+'-driver.ps1')
    $code=@(
        '$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''; $global:LASTEXITCODE=0',
        '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$global:S07ExpectedHelper='+(Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
        ('$global:S07Loader='+(Get-Literal $loader)),
        ('$global:S07ScriptedUI=$'+$ScriptedUI.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S07ForceHostRead=$'+$ForceHostRead.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S07ForbidNative=$'+$Preview.IsPresent.ToString().ToLowerInvariant()),
        ('$global:S07DialogPath='+(Get-Literal $DialogPath)),
        '$global:S07Loads=0; $global:S07DialogCalls=0; $global:S07Responses=New-Object ''System.Collections.Generic.Queue[object]''',
        '$global:S07Forbidden=New-Object ''System.Collections.Generic.List[string]''; $global:S07MetadataPrompts=New-Object ''System.Collections.Generic.List[string]''; $global:S07NativeProofs=New-Object ''System.Collections.Generic.List[object]'''
    )
    foreach ($response in $Responses) { $code+='$global:S07Responses.Enqueue('+$(if ($null -eq $response) {'$null'} else {Get-Literal ([string]$response)})+')' }
    $code+=@'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($global:S07Loads -eq 0 -and $actual -ieq $global:S07ExpectedHelper) { $global:S07Loads++; return $global:S07Loader }
    return $actual
}
function global:Read-Host { param([string]$Prompt); $global:S07Forbidden.Add('Read-Host'); throw 'Unexpected legacy Read-Host.' }
function global:Invoke-WebRequest { $global:S07Forbidden.Add('download'); throw 'Unexpected download.' }
function global:Invoke-RestMethod { $global:S07Forbidden.Add('network'); throw 'Unexpected network.' }
function global:Start-BitsTransfer { $global:S07Forbidden.Add('BITS'); throw 'Unexpected transfer.' }
try {
'@
    $code+=$Command
    $code+=@'
} finally {
    Write-Host ('[S07_AUDIT] ' + ([pscustomobject]@{output_encoding_codepage=[Console]::OutputEncoding.CodePage;helper_loads=$global:S07Loads;dialog_calls=$global:S07DialogCalls;metadata_prompts=@($global:S07MetadataPrompts.ToArray());remaining_responses=$global:S07Responses.Count;native_proofs=@($global:S07NativeProofs.ToArray());forbidden_calls=@($global:S07Forbidden.ToArray())} | ConvertTo-Json -Depth 6 -Compress))
}
exit $LASTEXITCODE
'@
    Write-NewText $driver ($code -join [Environment]::NewLine); Add-Fixture $driver
    $previousRelease=$script:releaseProved; $script:releaseProved=$false
    $native=Invoke-WithPath '' {Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo','-NoProfile','-NonInteractive','-OutputFormat','Text','-ExecutionPolicy','RemoteSigned','-File',$driver) -TimeoutMilliseconds 120000 -Operation ('S07 production child '+$Label) -MaxStdoutChars 1048576 -MaxStderrChars 65536}
    Assert-NativeComplete $native
    $text=$native.Stdout+[Environment]::NewLine+$native.Stderr
    Write-NewText (Join-Path $testRoot ($Label+'.log')) $text
    $audits=@($text -split '\r?\n' | Where-Object {$_.StartsWith('[S07_AUDIT] ',[StringComparison]::Ordinal)})
    Assert-True ($audits.Count -eq 1) 'Production child must emit one finally audit.'
    $audit=$audits[0].Substring(12) | ConvertFrom-Json
    Assert-True ($audit.output_encoding_codepage -eq 65001) 'Owned redirected child must emit UTF8 CP65001.'
    Assert-True (@($audit.native_proofs | Where-Object {-not $_.process_released -or -not $_.pipe_drain_completed}).Count -eq 0) 'Every native descendant must prove release and pipe completion.'
    $script:releaseProved=$previousRelease
    Assert-True ($audit.helper_loads -eq 1 -and @($audit.forbidden_calls).Count -eq 0) ('Production guards failed: '+$text.Replace($testRoot,'<OWNED_TEMP>'))
    Assert-True ($audit.remaining_responses -eq 0) 'Exactly the supplied injected responses must be consumed.'
    Assert-True (-not $text.Contains([string][char]27)) 'Redirected presentation must remain plain and contain no raw escape sequences.'
    return [pscustomobject]@{ExitCode=$native.ExitCode;Text=$text;Audit=$audit;ElapsedMilliseconds=$native.ElapsedMilliseconds}
}
function Get-AppCommand {
    param([string]$Parent,[switch]$Interactive,[switch]$Preview,[hashtable]$Overrides=@{},[int]$Bitrate=64)
    $command='& '+(Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1'))+' -InputFolder '+(Get-Literal $inputDir)+' -OutputParent '+(Get-Literal $Parent)+' -ConfigPath '+(Get-Literal $config)+' -FfmpegDirectory '+(Get-Literal $toolDirectory)+' -BitrateKbps '+$Bitrate
    if ($Interactive) {$command+=' -Interactive'}; if ($Preview) {$command+=' -DryRun'}
    foreach ($key in @('CoverPath','Artist','Album')) {if ($Overrides.ContainsKey($key)) {$command+=' -'+$key+' '+(Get-Literal $Overrides[$key])}}
    return $command
}
function Assert-Conversion {
    param([string]$Parent,[object]$Child,[string]$ExpectedArtist=$sourceArtist,[string]$ExpectedAlbum=$sourceAlbum,[bool]$HasCover=$false,[int]$Bitrate=64)
    Assert-True ($Child.ExitCode -eq 0) ('Expected conversion success: '+$Child.Text.Replace($testRoot,'<OWNED_TEMP>'))
    $runs=@(Get-ChildItem -LiteralPath $Parent -Directory); Assert-True ($runs.Count -eq 1) 'Expected one output run.'
    $manifest=[IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json')) | ConvertFrom-Json
    Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.policies.bitrate_kbps -eq $Bitrate -and $manifest.tools.ffmpeg.path -ceq $ffmpeg -and $manifest.tools.ffprobe.path -ceq $ffprobe) 'Manifest must prove one completed conversion at selected bitrate using exact external pair.'
    $output=Join-Path $runs[0].FullName $manifest.records[0].output_relative_path
    Assert-True ([IO.Path]::GetFileName($output).StartsWith('2024-02-03',[StringComparison]::Ordinal)) 'Date-first output names must survive metadata interaction.'
    $probed=Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v','error','-show_streams','-show_format','-of','json',$output) -TimeoutMilliseconds 15000 -Operation 'S07 independent output probe'; Assert-NativeComplete $probed -Success
    $probe=$probed.Stdout | ConvertFrom-Json; $streams=@($probe.streams | Where-Object {$_.codec_type -ceq 'audio'}); $pictures=@($probe.streams | Where-Object {$_.codec_type -ceq 'video'})
    Assert-True ($streams.Count -eq 1 -and $streams[0].codec_name -ceq 'mp3' -and [int]$streams[0].bit_rate -eq 1000*$Bitrate) 'Actual output must be one audio stream at selected CBR MP3 bitrate.'
    Assert-True ($probe.format.tags.artist -ceq $ExpectedArtist -and $probe.format.tags.album -ceq $ExpectedAlbum -and $probe.format.tags.title -ceq $sourceTitle -and $probe.format.tags.comment -ceq $sourceComment -and $probe.format.tags.track -ceq '3/9') 'Output metadata must preserve ordinary tags and exact explicit/custom overrides.'
    if ($HasCover) {
        Assert-True ($pictures.Count -eq 1 -and $pictures[0].disposition.attached_pic -eq 1 -and $pictures[0].width -eq 40 -and $pictures[0].height -eq 24) 'Requested cover must be one attached picture preserving dimensions.'
        $raw=Join-Path $testRoot ('cover-'+[guid]::NewGuid().ToString('N')+'.rgb')
        $image=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-i',$output,'-map','0:v:0','-frames:v','1','-pix_fmt','rgb24','-f','rawvideo',$raw) -Operation 'S07 independent cover pixels'; Assert-NativeComplete $image -Success
        $pixels=[IO.File]::ReadAllBytes($raw); $center=3*(12*40+20)
        Assert-True ($pixels.Length -eq 3*40*24 -and $pixels[$center+2] -gt 180 -and $pixels[$center] -lt 50) 'Decoded replacement pixels must be blue and differ from red source artwork.'
    } else {Assert-True ($pictures.Count -eq 0) 'Default output must drop source artwork.'}
    $decoded=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL') -Operation 'S07 independent full decode'; Assert-NativeComplete $decoded -Success
    Assert-True ($decoded.TimeoutMilliseconds -eq 0) 'Full decode must keep unlimited normal runtime.'
    $raw=Join-Path $testRoot ('sound-'+[guid]::NewGuid().ToString('N')+'.f32')
    $signal=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-i',$output,'-map','0:a:0','-ac','1','-ar','22050','-f','f32le',$raw) -Operation 'S07 independent sound regression'; Assert-NativeComplete $signal -Success
    $samples=[IO.File]::ReadAllBytes($raw); $crossings=0; $previous=[double]0
    # Measure the stable middle half of the short tone. MP3 priming/tail noise
    # can add crossings at the ends and must not distort the frequency check.
    Assert-True ($samples.Length -ge 22050*4*0.25) 'Decoded synthetic sound must retain a meaningful duration.'
    $first=4*[int][math]::Floor($samples.Length/16); $last=4*[int][math]::Floor(3*$samples.Length/16)
    for ($offset=$first;$offset -le $last;$offset+=4) {$value=[BitConverter]::ToSingle($samples,$offset); if ($previous -lt 0 -and $value -ge 0) {$crossings++}; $previous=$value}
    $frequency=$crossings/((($last-$first)/4)/22050.0); Assert-True ([math]::Abs($frequency-440) -lt 10) 'Decoded sound must retain the440Hz source signal.'
    Assert-True (@(Get-ChildItem -LiteralPath $runs[0].FullName -Recurse -File | Where-Object {$_.Name -match '\.partial'}).Count -eq 0) 'Completed conversion must leave no partial files.'
    Assert-True (-not (Test-Path -LiteralPath $config)) 'Metadata must never create configuration.'
    return [pscustomobject]@{exit_code=$Child.ExitCode;converted=1;bitrate_kbps=$Bitrate;full_decode=$true;decoded_frequency_hz=$frequency;artist=$probe.format.tags.artist;album=$probe.format.tags.album;attached_pictures=$pictures.Count;output_sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()}
}
function Assert-NoBatch {
    param([string]$Parent,[object]$Child,[int]$ExitCode)
    $parentExists=Test-Path -LiteralPath $Parent
    $entries=if ($parentExists) {@(Get-ChildItem -LiteralPath $Parent -Force)} else {@()}
    Assert-True ($Child.ExitCode -eq $ExitCode -and $entries.Count -eq 0 -and -not (Test-Path -LiteralPath $config)) ('Expected bounded exit'+$ExitCode+' without batch/config output: '+$Child.Text.Replace($testRoot,'<OWNED_TEMP>'))
    $allowedOperations=@('ffmpeg version check','ffprobe version check','ffmpeg encoder capability check')
    Assert-True (@($Child.Audit.native_proofs | Where-Object {$_.operation -notin $allowedOperations}).Count -eq 0) 'Waiting/cancelled/invalid input allows only the three bounded tool-selection preflight checks.'
    return [pscustomobject]@{output_parent_exists=$parentExists;output_parent_entries=$entries.Count;batch_output_created=$false;config_created=$false;media_processing_started=$false}
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Run from inherited UTF8 CP65001 console.'
    $report.source_before=Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)) 'Exact TEMP directory must be exclusively reserved.'
    $created=$true; $report.temp_exclusively_reserved=$true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new=$true
    $appRoot=New-Directory ("App [literal] O'Brien "+[char]0xE4)
    foreach ($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
        $copy=Join-Path $appRoot $name; Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Runtime copies must preserve repository bytes.'
        Add-Fixture $copy
    }
    $report.copied_bytes_unchanged=$true
    $script:originalNative=(Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value (Get-Command Invoke-TrackedNative -CommandType Function).ScriptBlock
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath; $toolDirectory=Split-Path -Parent $ffmpeg
    Assert-True ((Split-Path -Parent $ffprobe) -ieq $toolDirectory) 'Fixture binaries must share selected external pair directory.'
    foreach ($tool in @($ffmpeg,$ffprobe)) {
        Assert-NoReparse $tool
        $identity=Invoke-AudioNativeProcess -ExecutablePath $tool -Arguments @('-version') -TimeoutMilliseconds 15000 -Operation 'S07 fixture identity'; Assert-NativeComplete $identity -Success
        $report.tools+=[pscustomobject]@{name=[IO.Path]::GetFileName($tool);sha256=(Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant();version=($identity.Stdout -split '\r?\n')[0]}
    }
    Add-Type -AssemblyName System.Drawing
    $red=Join-Path $testRoot 'source-red.jpg'; $blue=Join-Path $testRoot 'override-blue.jpg'
    foreach ($row in @(@{path=$red;color=[Drawing.Color]::Red},@{path=$blue;color=[Drawing.Color]::Blue})) {
        $bitmap=New-Object Drawing.Bitmap(40,24); $graphics=$null
        try {$graphics=[Drawing.Graphics]::FromImage($bitmap); $graphics.Clear($row.color); $bitmap.Save($row.path,[Drawing.Imaging.ImageFormat]::Jpeg)} finally {if ($null -ne $graphics) {$graphics.Dispose()}; $bitmap.Dispose()}
        Add-Fixture $row.path
    }
    $sourceArtist='S07 source artist '+[char]0xE4; $sourceAlbum='S07 source album '+[char]0xE9; $sourceTitle='S07 source title'; $sourceComment='S07 source comment'
    $inputDir=New-Directory 'Synthetic input [x]'; $audio=Join-Path $inputDir '2024-02-03 - Tiny.mp3'
    $generated=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.4:sample_rate=22050','-i',$red,'-map','0:a:0','-map','1:v:0','-c:a','libmp3lame','-b:a','64k','-c:v','mjpeg','-disposition:v','attached_pic','-metadata',('artist='+$sourceArtist),'-metadata',('album='+$sourceAlbum),'-metadata',('title='+$sourceTitle),'-metadata',('comment='+$sourceComment),'-metadata','track=3/9',$audio) -TimeoutMilliseconds 15000 -Operation 'S07 generate tagged synthetic source with red artwork'; Assert-NativeComplete $generated -Success; Add-Fixture $audio
    $sourceProbe=Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v','error','-show_streams','-of','json',$audio) -TimeoutMilliseconds 15000 -Operation 'S07 source artwork proof'; Assert-NativeComplete $sourceProbe -Success
    Assert-True (@(($sourceProbe.Stdout | ConvertFrom-Json).streams | Where-Object {$_.disposition.attached_pic -eq 1}).Count -eq 1) 'Source fixture must actually have an attached picture.'
    $configRoot=New-Directory 'Owned config [x]'; $config=Join-Path $configRoot 'Absent.json'

    Invoke-Case 'Enter begins defaults with distinct waiting probing encoding and validation states' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Enter output'; $child=Invoke-ProductionChild 'Enter' (Get-AppCommand $parent -Interactive) -Responses @('') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child
        Assert-True ($child.Text.Contains('[READY] 1 files -> 64 kbps CBR MP3') -and $child.Text.Contains('Enter: convert    M: metadata    Q: quit') -and $child.Text.Contains('Waiting for your selection (no conversion has started).')) 'Ready menu must describe all actions and waiting explicitly.'
        Assert-True ($child.Audit.metadata_prompts.Count -eq 1 -and $child.Audit.dialog_calls -eq 0) 'Enter advances immediately without customization.'
        $positions=@(); foreach ($pattern in @('Waiting for your selection','\[STATE\] Probing source','\[STATE\] Encoding audio','\[STATE\] Validating output')) {$match=[regex]::Match($child.Text,$pattern); Assert-True $match.Success ('Missing state: '+$pattern); $positions+=$match.Index}
        Assert-True ($positions[0] -lt $positions[1] -and $positions[1] -lt $positions[2] -and $positions[2] -lt $positions[3]) 'Waiting must precede probing, encoding, then validation.'
        $case['ordered_state_markers']=@('waiting','probing','encoding','validating')
    }
    Invoke-Case 'M customizes real Artist Album and replacement cover without extra confirmation' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Customize output'; $artist='Custom artist '+[char]0xE4; $album='Custom album '+[char]0xE9
        $child=Invoke-ProductionChild 'Customize' (Get-AppCommand $parent -Interactive) -Responses @('M','Y',$artist,$album) -DialogPath $blue -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $artist -ExpectedAlbum $album -HasCover $true
        Assert-True ($child.Audit.metadata_prompts.Count -eq 4 -and $child.Audit.dialog_calls -eq 1 -and $child.Text -match '(?i)customiz|metadata' -and $child.Text -match '(?i)start|continu|return') 'Customization asks one cover choice and each free-text field without opt-in questions.'
    }
    Invoke-Case 'Enter preserves explicit tags cover and selected bitrate' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Explicit Enter output'; $artist='  Explicit artist  '; $album='Explicit album'
        $child=Invoke-ProductionChild 'ExplicitEnter' (Get-AppCommand $parent -Interactive -Bitrate 96 -Overrides @{CoverPath=$blue;Artist=$artist;Album=$album}) -Responses @('') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $artist -ExpectedAlbum $album -HasCover $true -Bitrate 96
        Assert-True ($child.Text.Contains('[READY] 1 files -> 96 kbps CBR MP3') -and $child.Audit.metadata_prompts.Count -eq 1 -and $child.Audit.dialog_calls -eq 0) 'Supplied values and selected rate must survive Enter.'
    }
    Invoke-Case 'M respects explicit parameters and skips their controls' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Explicit M output'; $artist='Explicit M artist'; $album='Explicit M album'
        $child=Invoke-ProductionChild 'ExplicitM' (Get-AppCommand $parent -Interactive -Overrides @{CoverPath=$blue;Artist=$artist;Album=$album}) -Responses @('M') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $artist -ExpectedAlbum $album -HasCover $true
        Assert-True ($child.Audit.metadata_prompts.Count -eq 1 -and $child.Audit.dialog_calls -eq 0) 'Explicit parameters must not be replaced or asked again.'
    }
    Invoke-Case 'M customizes only missing controls and retains exact nonblank text' 'S07-A1' {
        param($case)
        $parent=Join-Path $testRoot 'Partial M output'; $artist='Partial explicit artist'
        $child=Invoke-ProductionChild 'PartialM' (Get-AppCommand $parent -Interactive -Overrides @{Artist=$artist}) -Responses @('M','N','  Selected album  ') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $artist -ExpectedAlbum '  Selected album  '
        Assert-True ($child.Audit.metadata_prompts.Count -eq 3 -and $child.Audit.dialog_calls -eq 0) 'Missing cover/album controls must not override explicit artist.'
    }
    Invoke-Case 'M blank custom values preserve defaults and cancelled cover picker continues without cover' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Blank M output'
        $child=Invoke-ProductionChild 'BlankM' (Get-AppCommand $parent -Interactive) -Responses @('M','Y','   ','') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child
        Assert-True ($child.Audit.dialog_calls -eq 1 -and $child.Audit.metadata_prompts.Count -eq 4) 'Cancelled picker and entered blank tags retain defaults.'
    }
    Invoke-Case 'M explicit blank tag parameters suppress controls while preserving source tags' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Explicit blank M output'
        $child=Invoke-ProductionChild 'ExplicitBlankM' (Get-AppCommand $parent -Interactive -Overrides @{Artist='   ';Album=''}) -Responses @('M','N') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child
        Assert-True ($child.Audit.metadata_prompts.Count -eq 2 -and $child.Audit.dialog_calls -eq 0) 'Explicit blank tags retain source semantics and are not re-prompted.'
    }
    Invoke-Case 'fresh Enter launch never inherits previous batch metadata' 'S07-A1,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Fresh defaults output'; $child=Invoke-ProductionChild 'FreshDefaults' (Get-AppCommand $parent -Interactive) -Responses @('') -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child
        Assert-True (@(Get-ChildItem -LiteralPath $configRoot -Force).Count -eq 0) 'Metadata/configuration must not be saved between launches.'
        $case['settings_files_created']=0
    }
    $pastedSentinel=Join-Path $testRoot 'Pasted code must never execute.txt'
    foreach ($row in @(@{label='Q';response='Q';code=130},@{label='LowerQ';response=' q ';code=130},@{label='EOF';response=$null;code=130})) {
        Invoke-Case ('menu '+$row.label+' stops once without media processing or output') 'S07-A1,S07-A2' {
            param($case)
            $parent=Join-Path $testRoot ($row.label+' output'); $child=Invoke-ProductionChild $row.label (Get-AppCommand $parent -Interactive) -Responses @($row.response) -ScriptedUI
            $case['no_batch']=Assert-NoBatch $parent $child $row.code
            Assert-True (-not (Test-Path -LiteralPath $pastedSentinel)) 'Pasted source code must remain inert input.'
            Assert-True ($child.Audit.metadata_prompts.Count -eq 1 -and $child.Audit.dialog_calls -eq 0) 'Cancellation/invalid input must not retry or open a dialog.'
            $case['exit_code']=$child.ExitCode; $case['prompts']=1; $case['elapsed_ms']=$child.ElapsedMilliseconds
        }
    }
    foreach ($row in @(@{label='ReadyRetryEof';responses=@('typo',$null)},@{label='CoverRetryEof';responses=@('M','typo',$null)},@{label='CoverEof';responses=@('M',$null)},@{label='ArtistValueEof';responses=@('M','N',$null)},@{label='AlbumValueEof';responses=@('M','N','Artist',$null)})) {
        Invoke-Case ('metadata '+$row.label+' never converts unavailable input into defaults') 'S07-A2' {
            param($case)
            $parent=Join-Path $testRoot ($row.label+' output'); $child=Invoke-ProductionChild $row.label (Get-AppCommand $parent -Interactive) -Responses $row.responses -ScriptedUI
            $case['no_batch']=Assert-NoBatch $parent $child 130
            $case['exit_code']=$child.ExitCode; $case['prompts']=$child.Audit.metadata_prompts.Count
        }
    }
    Invoke-Case 'invalid ready and cover choices repeat only their prompt then convert actual tags and selected cover' 'v1.0.3' {
        param($case)
        $parent=Join-Path $testRoot 'Recovered metadata output'; $artist="O'Brien & " + [char]0x00E4 + [char]0x4E2D
        $child=Invoke-ProductionChild 'RecoveredMetadata' (Get-AppCommand $parent -Interactive) -Responses @('typo','M','maybe','Y',$artist,'2027 Term 1 Week 8') -DialogPath $blue -ScriptedUI
        $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $artist -ExpectedAlbum '2027 Term 1 Week 8' -HasCover $true
        Assert-True ($child.Audit.metadata_prompts.Count -eq 6 -and $child.Audit.dialog_calls -eq 1 -and [regex]::Matches($child.Text,'Use Enter, M or Q\.').Count -eq 1 -and [regex]::Matches($child.Text,'Use Y, N or Q\.').Count -eq 1) 'Each invalid choice emits exactly one short hint and repeats only the relevant prompt.'
        Assert-True ($child.Audit.metadata_prompts[0] -ceq $child.Audit.metadata_prompts[1] -and $child.Audit.metadata_prompts[2] -ceq $child.Audit.metadata_prompts[3]) 'Retries must not restart earlier prompts.'
    }
    foreach ($textTag in @('Y','N','Q')) {
        Invoke-Case ('free-text tag '+$textTag+' remains data') 'v1.0.3' {
            param($case)
            $parent=Join-Path $testRoot ('Literal '+$textTag+' output')
            $child=Invoke-ProductionChild ('LiteralTag'+$textTag) (Get-AppCommand $parent -Interactive) -Responses @('M','N',$textTag,$textTag) -ScriptedUI
            $case['conversion']=Assert-Conversion $parent $child -ExpectedArtist $textTag -ExpectedAlbum $textTag
        }
    }
    Invoke-Case 'invalid inert menu text repeats and Q cancels without conversion' 'v1.0.3' {
        param($case)
        $parent=Join-Path $testRoot 'Inert retry output'
        $child=Invoke-ProductionChild 'InertRetry' (Get-AppCommand $parent -Interactive) -Responses @(('Set-Content -LiteralPath '+(Get-Literal $pastedSentinel)+' -Value executed'),'Q') -ScriptedUI
        $case['no_batch']=Assert-NoBatch $parent $child 130
        Assert-True (-not (Test-Path -LiteralPath $pastedSentinel) -and $child.Audit.metadata_prompts.Count -eq 2) 'Text is never executed and an invalid menu entry must prompt again.'
    }
    Invoke-Case 'actual redirected noninteractive host rejects ready interaction before a batch' 'S07-A2' {
        param($case)
        $parent=Join-Path $testRoot 'Unavailable host output'; $child=Invoke-ProductionChild 'UnavailableHost' (Get-AppCommand $parent -Interactive)
        $case['no_batch']=Assert-NoBatch $parent $child 1
        Assert-True ($child.Text -match '(?i)console|redirect|noninteractive|non-interactive' -and $child.Audit.metadata_prompts.Count -eq 0) 'Unavailable console must fail explicitly without scripted input.'
        $case['host']='actual -NonInteractive child; redirected stdout/stderr'; $case['exit_code']=1
    }
    Invoke-Case 'production response reader preserves actual NonInteractive host authority' 'S07-A2' {
        param($case)
        $parent=Join-Path $testRoot 'Host authority output'; $child=Invoke-ProductionChild 'HostReadRefused' (Get-AppCommand $parent -Interactive) -ForceHostRead
        $case['no_batch']=Assert-NoBatch $parent $child 1
        # Windows PowerShell formats nested method errors to console width and
        # can wrap within NonInteractive. Compare the observed message after
        # whitespace normalization; keep the actual reader and no-batch checks.
        $hostRefusal=[regex]::Match(($child.Text -replace '\s+',''),'(?i)noninteractive|non-interactive')
        Assert-True ($hostRefusal.Success -and $child.Audit.dialog_calls -eq 0) 'Availability override must not permit production Host.UI.ReadLine under NonInteractive.'
        $case['observed_host_refusal_token']=$hostRefusal.Value
        $case['adapter_override']='availability only; production reader unchanged'; $case['exit_code']=1
    }
    Invoke-Case 'normal noninteractive calls remain prompt-free and preserve defaults' 'S07-A2,S07-A3' {
        param($case)
        $parent=Join-Path $testRoot 'Noninteractive output'; $child=Invoke-ProductionChild 'Noninteractive' (Get-AppCommand $parent)
        $case['conversion']=Assert-Conversion $parent $child
        Assert-True ($child.Audit.metadata_prompts.Count -eq 0 -and $child.Audit.dialog_calls -eq 0 -and -not $child.Text.Contains('Waiting for your selection')) 'Ordinary conversion must not show/read ready menu.'
    }
    Invoke-Case 'dry-run with Interactive remains prompt-free tool-free and write-free' 'S07-A2' {
        param($case)
        $parent=Join-Path $testRoot 'Preview output'; $child=Invoke-ProductionChild 'Preview' (Get-AppCommand $parent -Interactive -Preview) -Preview
        Assert-True ($child.ExitCode -eq 0 -and $child.Text -match '\[PREVIEW\]' -and $child.Text -match 'Interactive.*ignored' -and $child.Audit.native_proofs.Count -eq 0 -and $child.Audit.metadata_prompts.Count -eq 0 -and $child.Audit.dialog_calls -eq 0 -and -not (Test-Path -LiteralPath $parent) -and -not (Test-Path -LiteralPath $config)) 'Preview ignores Interactive without tools, prompts or settings.'
        $case['exit_code']=0; $case['native_calls']=0; $case['prompts']=0
    }
    $report.status='pass'; $exitCode=0


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
Write-Host "$($report.task) metadata interaction: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
