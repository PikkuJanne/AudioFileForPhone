<#
T18 help/examples/version smoke. Get-Help Code is parsed and saved verbatim in
child drivers; no string evaluation. Byte-identical application copies, synthetic
media and a test-only helper-load guard live in one exclusive token-marked TEMP
tree. The Music resolver is intercepted before its platform default can run.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T18|T17)-help-(ps51|ps7)-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$') {
    throw 'EvidencePath must name fresh T18/T17-help-ps51/ps7-attempt/finalN or CI runN_N JSON directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'T18H-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t18-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false; $descendantReleaseProved = $true; $exitCode = 1
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat',
    'tests/Test-HelpVersion.ps1', 'README.md', 'SUPPORT.md', 'CHANGELOG.md',
    'docs/codex-v1.0.1/RELEASE_TARGET.json', 'docs/codex-v1.0.1/CORRECTIVE_RELEASE_TARGET.json')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'comment_help_exact_examples_and_single_version'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = [string]$PSVersionTable.PSVersion; shell_edition = $PSVersionTable.PSEdition
    os = [string][Environment]::OSVersion.Version; windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    owned_temp_root = $testRoot; temp_exclusively_reserved = $false; marker_create_new = $false
    copied_application_bytes_unchanged = $false; ordinary_music_access = $false; physical_manual_evidence = $false
    guard_kind = 'test-only exact first helper-load Join-Path interception; shipped entry/helper bytes unchanged'
    inventory_fields = @('relative_path', 'kind', 'length', 'sha256', 'last_write_utc', 'attributes')
    access_time_excluded = $true; native_runs = @(); cases = @(); descendant_release_proved = $false
    children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
}
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
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse fixture/ancestor.'
        $item = $item.Parent
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse inside exact owned tree.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Get-TreeInventory {
    param([string]$Root)
    $inventoryRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $descendantPrefix = $inventoryRoot + '\'
    $items = @((Get-Item -LiteralPath $inventoryRoot -Force)) + @(Get-SafeTree $inventoryRoot)
    return @($items | ForEach-Object {
        $_.Refresh()
        # Windows can report the same literal root with different casing. Only
        # root identity and containment use its case-insensitive path semantics;
        # every relative name and inventory field stays exact for before/after.
        $relativePath = '.'
        if (-not [StringComparer]::OrdinalIgnoreCase.Equals($_.FullName, $inventoryRoot)) {
            Assert-True ($_.FullName.StartsWith($descendantPrefix, [StringComparison]::OrdinalIgnoreCase)) 'Inventory entry must be a strict descendant of the exact owned root.'
            $relativePath = $_.FullName.Substring($descendantPrefix.Length)
        }
        [pscustomobject][ordered]@{
            relative_path = $relativePath
            kind = $(if ($_.PSIsContainer) { 'directory' } else { 'file' })
            length = $(if ($_.PSIsContainer) { $null } else { $_.Length })
            sha256 = $(if ($_.PSIsContainer) { $null } else { (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() })
            last_write_utc = $_.LastWriteTimeUtc.ToString('o'); attributes = [int]$_.Attributes
        }
    } | Sort-Object relative_path)
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_)).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() } })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
$deadlineSource = @'
using System;
using System.Threading;
namespace T18Support {
    public sealed class Deadline : IDisposable {
        private readonly Timer timer; private int timedOut;
        public bool TimedOut { get { return Interlocked.CompareExchange(ref timedOut,0,0)!=0; } }
        public Deadline(object context,int milliseconds) {
            timer=new Timer(o=>{Interlocked.Exchange(ref timedOut,1);context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@
function Invoke-OwnedNative {
    param([string]$Tool, [string[]]$NativeArguments, [switch]$EntryHost)
    $previous = $script:descendantReleaseProved; $script:descendantReleaseProved = $false
    $context = New-AudioCancellationContext
    $deadline = New-Object T18Support.Deadline($context, 180000)
    try {
        $native = Invoke-AudioNativeProcess -ExecutablePath $Tool -Arguments $NativeArguments -Cancellation $context -MaxStdoutChars 2097152 -MaxStderrChars 65536
        if ($native.ProcessReleased -and -not $EntryHost) { $script:descendantReleaseProved = $previous }
        $report.native_runs += [pscustomobject]@{
            executable = $Tool; arguments = @($NativeArguments | ForEach-Object { $_.Replace($testRoot, '<OWNED_TEMP>') })
            status = $native.Status; exit_code = $native.ExitCode; process_released = $native.ProcessReleased
            deadline_requested = $deadline.TimedOut; duration_ms = $native.DurationMilliseconds
        }
        Assert-True (-not $deadline.TimedOut -and $native.Status -ceq 'Completed' -and $native.ProcessReleased -and -not $native.StdoutTruncated -and -not $native.StderrTruncated) ('Native completion/drain/release unproved: ' + $native.Status + ' ' + $native.Error)
        if (-not $EntryHost) { Assert-True ($native.ExitCode -eq 0) ('Synthetic native check failed: ' + $native.Stderr) }
        return $native
    } finally { $deadline.Dispose(); $context.Dispose() }
}
$guardLoader = @'
. $global:T18ExpectedHelper
$script:T18OriginalOutputParent=(Get-Item -LiteralPath Function:Get-OutputParent).ScriptBlock
$script:T18OriginalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Get-AudioConfigPath { param([string]$ConfigPath); return Microsoft.PowerShell.Management\Join-Path $global:T18OwnedRoot 'missing-config.json' }
function Get-OutputParent {
    param([string]$OutputParent,[scriptblock]$MusicResolver)
    $parameters=@{OutputParent=$OutputParent}
    if([string]::IsNullOrWhiteSpace($OutputParent)) {
        $global:T18MusicCalls++
        $parameters.MusicResolver={ $global:T18OwnedMusic }
    } elseif($null -ne $MusicResolver) { $parameters.MusicResolver=$MusicResolver }
    $resolved=& $script:T18OriginalOutputParent @parameters
    if(-not $resolved.StartsWith($global:T18OwnedRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'T18 resolver refused non-owned output.' }
    return $resolved
}
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
          [object]$Cancellation=(Get-AudioCancellationContext),[object]$ProgressParser=$null,[scriptblock]$ProgressCallback=$null,
          [object]$ProgressDurationSeconds=$null,[object]$ProgressCallbackState=$null,
          [int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    if($global:T18Preview) { $global:T18Forbidden.Add('native'); throw 'T18 preview attempted a native call.' }
    $proof=[pscustomobject]@{status='not returned';exit_code=$null;process_released=$false}
    $global:T18NativeProofs.Add($proof)
    $native=& $script:T18OriginalNative @PSBoundParameters
    $proof.status=$native.Status; $proof.exit_code=$native.ExitCode; $proof.process_released=[bool]$native.ProcessReleased
    return $native
}
if($global:T18Preview) {
    function Get-ToolPath { param($ExeName,$ScriptDirectory); $global:T18Forbidden.Add('tool lookup'); throw 'T18 preview tool lookup.' }
    function Resolve-AudioToolSelection { param($FfmpegDirectory,$ConfigPath,$ScriptDirectory); $global:T18Forbidden.Add('tool selection/config read'); throw 'T18 preview tool selection/config read.' }
    function Assert-ToolPrerequisites { param($FfmpegPath,$FfprobePath); $global:T18Forbidden.Add('tool preflight'); throw 'T18 preview tool preflight.' }
    function Get-ValidatedCoverPath { param($Path,$FfmpegPath); $global:T18Forbidden.Add('cover'); throw 'T18 preview cover validation.' }
    function Test-OutputWritable { param($Path,[switch]$SkipWriteProbe); $global:T18Forbidden.Add('writability'); throw 'T18 preview write probe.' }
    function New-AudioRunReservation { param($OutputParent,$InputFolder,$Files,$BitrateKbps,$MaxBaseLength,$Timestamp,$StartCounter,$MaximumAttempts); $global:T18Forbidden.Add('reservation'); throw 'T18 preview reservation.' }
    function Write-AudioRunManifest { param($Manifest,$Checkpoint); $global:T18Forbidden.Add('manifest'); throw 'T18 preview manifest.' }
    function Write-AudioOutputMarker { param($OutputRoot,$InputFolder,$BitrateKbps,$OwnershipToken); $global:T18Forbidden.Add('marker'); throw 'T18 preview marker.' }
    function New-AudioCancellationContext { param([switch]$CaptureConsole); $global:T18Forbidden.Add('console capture'); throw 'T18 preview console capture.' }
}
'@
function New-ExampleFixture {
    param([int]$Number, [string]$Code)
    $app = Join-Path $testRoot ('E' + $Number); [IO.Directory]::CreateDirectory($app) | Out-Null
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
        $target = Join-Path $app $name; [IO.File]::Copy((Join-Path $projectRoot $name), $target, $false)
        Assert-True ((Get-FileHash -LiteralPath $target).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'App/helper copies must be byte-identical.'
        Add-Fixture $target
    }
    $inputPath = Join-Path $app 'Podcasts'; $nested = Join-Path $inputPath 'Episodes'
    [IO.Directory]::CreateDirectory($nested) | Out-Null
    foreach ($seed in $seeds) {
        $parent = if ($seed.nested) { $nested } else { $inputPath }
        $target = Join-Path $parent $seed.name; [IO.File]::Copy($seed.path, $target, $false); Add-Fixture $target
    }
    foreach ($name in @('notes.txt', 'unsupported.wav')) { $target = Join-Path $inputPath $name; Write-NewText $target 'Synthetic unsupported-extension sentinel'; Add-Fixture $target }
    $cover = Join-Path $app 'cover.png'; [IO.File]::Copy($seedCover, $cover, $false); Add-Fixture $cover
    $loader = Join-Path $app 'T18-guard-loader.ps1'; Write-NewText $loader $guardLoader; Add-Fixture $loader
    $driver = Join-Path $app 'T18-driver.ps1'
    $prefix = @(
        '$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''; $global:LASTEXITCODE=0',
        '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('Set-Location -LiteralPath ' + (Get-Literal $app)),
        ('$env:PATH=' + (Get-Literal ((Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe))) + '+'';''+$env:PATH'),
        ('$global:T18ExpectedHelper=' + (Get-Literal (Join-Path $app 'AudioFileForPhone.Helpers.ps1'))),
        ('$global:T18LoaderPath=' + (Get-Literal $loader)),
        ('$global:T18OwnedRoot=' + (Get-Literal $testRoot)),
        ('$global:T18OwnedMusic=' + (Get-Literal (Join-Path $app 'Owned Music'))),
        ('$global:T18Preview=$' + $(if ($Number -eq 4) { 'true' } else { 'false' })),
        '$global:T18Loads=0; $global:T18MusicCalls=0; $global:T18NativeProofs=New-Object ''System.Collections.Generic.List[object]''; $global:T18Forbidden=New-Object ''System.Collections.Generic.List[string]'''
    )
    $driverGuard = @'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($global:T18Loads -eq 0 -and $actual -ieq $global:T18ExpectedHelper) { $global:T18Loads++; return $global:T18LoaderPath }
    return $actual
}
function global:Read-Host { param($Prompt); $global:T18Forbidden.Add('prompt'); throw 'T18 unexpected interactive prompt.' }
'@
    $suffix = @'
} finally {
    Write-Host ('[T18_AUDIT] '+([pscustomobject]@{helper_loads=$global:T18Loads;music_resolver_calls=$global:T18MusicCalls;native_proofs=@($global:T18NativeProofs.ToArray());forbidden_calls=@($global:T18Forbidden.ToArray())}|ConvertTo-Json -Depth 5 -Compress))
}
exit $LASTEXITCODE
'@
    # The published Code text remains exact between the braces, and only runs
    # by the normal -File script invocation after a successful AST parse.
    Write-NewText $driver (($prefix -join "`r`n") + "`r`n" + $driverGuard + "`r`ntry {`r`n" + $Code + "`r`n" + $suffix)
    Add-Fixture $driver
    return [pscustomobject]@{ app = $app; driver = $driver; input = $inputPath; parent = (Join-Path $app $(if ($Number -eq 1) { 'Owned Music' } else { 'Phone audio' })) }
}
function Invoke-Example {
    param([object]$Fixture, [int]$Number)
    $previous = $script:descendantReleaseProved
    $result = Invoke-OwnedNative $shellPath @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $Fixture.driver) -EntryHost
    $text = $result.Stdout + "`n" + $result.Stderr
    $audits = @($text -split '\r?\n' | Where-Object { $_.StartsWith('[T18_AUDIT] ', [StringComparison]::Ordinal) })
    Assert-True ($audits.Count -eq 1) 'Exact child driver must emit one finally audit.'
    $audit = $audits[0].Substring(12) | ConvertFrom-Json
    Assert-True (@($audit.native_proofs | Where-Object { -not $_.process_released }).Count -eq 0) 'All child native invocations require positive release proof.'
    $script:descendantReleaseProved = $previous
    Assert-True ($audit.helper_loads -eq $(if ($Number -eq 5) { 0 } else { 1 }) -and @($audit.forbidden_calls).Count -eq 0) 'Guard must intercept the first exact entry helper load and refuse native/interactive preview operations.'
    Assert-True ($audit.music_resolver_calls -eq $(if ($Number -eq 1) { 1 } else { 0 })) 'Only default example must use the owned synthetic Music resolver.'
    Assert-True ($result.ExitCode -eq 0) ('Help example failed: ' + $text.Replace($testRoot, '<OWNED_TEMP>'))
    return [pscustomobject]@{ text = $text; audit = $audit; exit_code = $result.ExitCode }
}
function Assert-ExampleOutputs {
    param([object]$Fixture, [object]$Result, [int]$Number)
    $roots = @(Get-ChildItem -LiteralPath $Fixture.parent -Directory)
    Assert-True ($roots.Count -eq 1) 'Example must reserve exactly one fresh output run.'
    $runRoot = $roots[0].FullName
    $manifestPath = Join-Path $runRoot 'AudioFileForPhone_manifest.json'; $data = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    $log = [IO.File]::ReadAllText((Join-Path $runRoot 'AudioFileForPhone_log.txt'))
    $bitrate = if ($Number -eq 2) { 96 } else { 64 }; $limit = if ($Number -eq 2) { 50 } else { 60 }
    Assert-True ($data.app_version -ceq $appVersion -and $Result.text.Contains('AudioFileForPhone v' + $appVersion) -and $log.Contains('App version   : ' + $appVersion)) 'One authoritative version must drive actual banner, log and manifest.'
    Assert-True ($data.build.entry_sha256 -ceq (Get-FileHash -LiteralPath (Join-Path $Fixture.app 'AudioFileForPhone.ps1')).Hash.ToLowerInvariant() -and $data.build.helper_sha256 -ceq (Get-FileHash -LiteralPath (Join-Path $Fixture.app 'AudioFileForPhone.Helpers.ps1')).Hash.ToLowerInvariant()) 'Manifest fingerprints must bind actual byte-identical shipped copies.'
    Assert-True ($data.run.status -ceq 'Completed' -and $data.run.exit_code -eq 0 -and $data.totals.converted -eq 4 -and $data.totals.failed -eq 0 -and $data.totals.unsupported -eq 2 -and @($data.records).Count -eq 4) 'All four supported formats must convert and reconcile; unsupported extensions remain separate.'
    Assert-True ($data.policies.bitrate_kbps -eq $bitrate -and $data.policies.max_base_length -eq $limit) 'Executed default/custom example options must match manifest.'
    Assert-True ($data.tools.ffmpeg.path -ceq $ffmpeg -and $data.tools.ffprobe.path -ceq $ffprobe -and $data.tools.ffmpeg.version -ceq $report.ffmpeg_version -and $data.tools.ffprobe.version -ceq $report.ffprobe_version) 'Manifest must identify the actual externally selected tool paths and versions.'
    $decoded = @()
    foreach ($row in $data.records) {
        Assert-True ($row.status -ceq 'Converted' -and $row.output_relative_path.StartsWith('Podcasts\', [StringComparison]::Ordinal)) 'Output must preserve input basename as first relative directory.'
        $output = Join-Path $runRoot $row.output_relative_path
        Assert-True ([IO.Path]::GetDirectoryName($row.output_relative_path) -ceq ('Podcasts\' + [IO.Path]::GetDirectoryName($row.source_relative_path)).TrimEnd('\')) 'Nested relative directory layout must be retained.'
        $base = [IO.Path]::GetFileNameWithoutExtension($output)
        Assert-True ($base.Length -le $limit -and $base -match '^2024-01-0[1-4] - ') 'Date-first names and basename limit must remain accurate.'
        $probe = (Invoke-OwnedNative $ffprobe @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $output)).Stdout | ConvertFrom-Json
        $audio = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' }); $pictures = @($probe.streams | Where-Object { $_.codec_type -ceq 'video' })
        Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq ($bitrate * 1000)) 'Independent probe must confirm selected MP3 bitrate.'
        $duration = [double]::Parse([string]$audio[0].duration, [Globalization.CultureInfo]::InvariantCulture)
        Assert-True ($duration -gt 0 -and [math]::Abs($duration - $row.input_duration_seconds) -le 0.35 -and $row.decoded_duration_seconds -gt 0) 'Independent output duration must stay within the recorded source/full-decode tolerance.'
        if ($Number -eq 3) {
            Assert-True ($pictures.Count -eq 1 -and $pictures[0].codec_name -ceq 'mjpeg' -and $pictures[0].disposition.attached_pic -eq 1 -and $probe.format.tags.artist -ceq 'Example narrator' -and $probe.format.tags.album -ceq 'Example book') 'Explicit cover must produce one attached JPEG and the exact batch overrides.'
        } else { Assert-True ($pictures.Count -eq 0 -and $probe.format.tags.artist -ceq 'Synthetic source artist' -and $probe.format.tags.album -ceq 'Synthetic source album') 'No explicit cover must retain source tags and have no artwork.' }
        $expectedTitle = if ($row.source_relative_path -match 'Opus') { $base } else { 'Synthetic source title' }
        Assert-True ($probe.format.tags.title -ceq $expectedTitle) 'Existing titles must survive; absent Opus title must use planned basename.'
        Invoke-OwnedNative $ffmpeg @('-nostdin', '-v', 'error', '-xerror', '-i', $output, '-map', '0:a:0', '-f', 'null', 'NUL') | Out-Null
        $decoded += [pscustomobject]@{ relative_path = $row.output_relative_path; bitrate_kbps = $bitrate; bytes = (Get-Item -LiteralPath $output).Length; sha256 = (Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant(); fully_decoded = $true }
    }
    Assert-True (@(Get-SafeTree $runRoot | Where-Object { -not $_.PSIsContainer -and $_.Name.EndsWith('.partial', [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) 'Successful example must retain no working partial.'
    return [pscustomobject]@{ app_version = $data.app_version; totals = $data.totals; decoded_outputs = $decoded; manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() }
}
try {
    $report.source_before = Get-SourceInventory
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Add-Type -TypeDefinition $deadlineSource
    Assert-NoReparse $tempParent; Initialize-AudioDirectoryInterop
    $ownedRootCreated = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be exclusively reserved, never adopt an existing path.'
    $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true; Add-Fixture $ownerFile
    $ffmpeg = (Get-Item -LiteralPath $FfmpegPath).FullName; $ffprobe = (Get-Item -LiteralPath $FfprobePath).FullName
    $report['ffmpeg_version'] = ((Invoke-OwnedNative $ffmpeg @('-nostdin', '-version')).Stdout -split '\r?\n')[0]
    $report['ffprobe_version'] = ((Invoke-OwnedNative $ffprobe @('-version')).Stdout -split '\r?\n')[0]
    $appVersion = Get-AudioAppVersion
    $help = $null; $examples = @()
    Invoke-Case 'Get-Help recognizes all documented parameters and exact executable examples without entry execution' 'A45,A46' {
        param($case)
        $before = Get-TreeInventory $testRoot
        $alternateRoot = $testRoot.ToUpperInvariant()
        Assert-True ($alternateRoot -cne $testRoot) 'Regression requires a differently cased spelling of the same owned Windows root.'
        $alternateInventory = Get-TreeInventory $alternateRoot
        Assert-True (($before | ConvertTo-Json -Compress -Depth 8) -ceq ($alternateInventory | ConvertTo-Json -Compress -Depth 8)) 'Owned inventory must retain exact relative names and node fields across differently cased spellings of its Windows root.'
        $case['alternate_root_spelling_inventory_equal'] = $true
        $script:help = Get-Help -Name (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Full
        $script:examples = @($help.examples.example)
        $expected = @('InputFolder', 'FromBatchLauncher', 'BitrateKbps', 'MaxBaseLength', 'Interactive', 'CoverPath', 'Artist', 'Album', 'OutputParent', 'DryRun', 'ProbeTimeoutSeconds', 'FfmpegDirectory', 'ConfigPath')
        $actual = @($help.parameters.parameter.name)
        Assert-True ($help.Synopsis -match 'MP3.*M4A.*OGG' -and $examples.Count -eq 5) 'Proper comment help must contain synopsis and five examples.'
        foreach ($name in $expected) {
            $parameter = @($help.parameters.parameter | Where-Object { $_.name -ceq $name })
            Assert-True ($parameter.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace(($parameter[0].description.Text | Out-String))) ('Missing help parameter description: ' + $name)
        }
        Assert-True (@($actual | Where-Object { $_ -notin $expected }).Count -eq 0) 'Help must match the bounded documented parameter set.'
        $command = Get-Command -Name (Join-Path $projectRoot 'AudioFileForPhone.ps1') -CommandType ExternalScript
        $direct = @($command.ParameterSets | Where-Object { $_.Name -ceq 'Direct' })
        $batch = @($command.ParameterSets | Where-Object { $_.Name -ceq 'BatchLauncher' })
        Assert-True ($command.ParameterSets.Count -eq 2 -and $direct.Count -eq 1 -and $batch.Count -eq 1) 'Direct and BAT launch syntax must remain separate.'
        $directInput = @($direct[0].Parameters | Where-Object { $_.Name -ceq 'InputFolder' })
        Assert-True ($direct[0].IsDefault -and $directInput.Count -eq 1 -and $directInput[0].IsMandatory -and $directInput[0].Position -eq 0) 'Direct calls must still require the positional input folder.'
        Assert-True (@($direct[0].Parameters | Where-Object { $_.Name -ceq 'FromBatchLauncher' }).Count -eq 0) 'The internal BAT switch must not change direct-call binding.'
        $batchRequired = @($batch[0].Parameters | Where-Object { $_.IsMandatory })
        Assert-True ($batchRequired.Count -eq 1 -and $batchRequired[0].Name -ceq 'FromBatchLauncher' -and $batchRequired[0].ParameterType -eq [Management.Automation.SwitchParameter]) 'The BAT route must bind its switch without prompting for an input parameter.'
        Assert-True (@($batch[0].Parameters | Where-Object { $_.Name -ceq 'InputFolder' }).Count -eq 0) 'The BAT route must take its folder through its data transport, not command-line rebinding.'
        $case['parameter_sets'] = @($command.ParameterSets | ForEach-Object {
            [pscustomobject]@{ name = $_.Name; default = $_.IsDefault; required = @($_.Parameters | Where-Object { $_.IsMandatory } | ForEach-Object { $_.Name }) }
        })
        $case['examples'] = @($examples | ForEach-Object {
            $tokens = $null; $errors = $null; $ast = [Management.Automation.Language.Parser]::ParseInput([string]$_.code, [ref]$tokens, [ref]$errors)
            Assert-True (@($errors).Count -eq 0 -and $ast.EndBlock.Statements.Count -gt 0) ('Example AST parse failed: ' + $_.title)
            [pscustomobject]@{ title = $_.title; code = $_.code; parse_errors = @($errors); statements = $ast.EndBlock.Statements.Count }
        })
        $docBlocks = @()
        foreach ($file in @('README.md', 'SUPPORT.md', 'CHANGELOG.md')) {
            $document = [IO.File]::ReadAllText((Join-Path $projectRoot $file))
            $blocks = @([regex]::Matches($document, '(?ms)^```powershell\r?\n(.*?)^```[ \t]*\r?$'))
            for ($blockIndex = 0; $blockIndex -lt $blocks.Count; $blockIndex++) {
                $code = $blocks[$blockIndex].Groups[1].Value.Trim(); $tokens = $null; $errors = $null
                [Management.Automation.Language.Parser]::ParseInput($code, [ref]$tokens, [ref]$errors) | Out-Null
                Assert-True (@($errors).Count -eq 0) ('Public documentation PowerShell block must parse: ' + $file + ' block ' + ($blockIndex + 1))
                if ($file -ceq 'README.md' -and $blockIndex -lt 5) {
                    Assert-True ($code.Replace("`r`n", "`n") -ceq ([string]$examples[$blockIndex].code).Trim().Replace("`r`n", "`n")) 'First five README commands must be the same exact executable help examples.'
                }
                $docBlocks += [pscustomobject]@{ source = $file; block = $blockIndex + 1; code = $code; parse_errors = @($errors); execution = $(if ($file -ceq 'README.md' -and $blockIndex -lt 5) { 'same exact help Code executed below in isolated child' } else { 'syntax only; policy/setup/interactive commands not executed' }) }
            }
            if ($file -ceq 'README.md') { Assert-True ($blocks.Count -ge 5) 'README must contain the five executable help examples.' }
        }
        $case['public_document_code_blocks'] = $docBlocks
        $after = Get-TreeInventory $testRoot
        Assert-True (($before | ConvertTo-Json -Compress -Depth 8) -ceq ($after | ConvertTo-Json -Compress -Depth 8)) 'Get-Help must not execute the entry or change owned fixtures.'
        $case['parameters'] = $actual; $case['owned_tree_unchanged'] = $true
    }
    Invoke-Case 'one runtime version literal and real helper output are consistent' 'A46' {
        param($case)
        Assert-True ($appVersion -cmatch '^1\.0\.2$') 'Authoritative semantic app version must be the owner-selected 1.0.2.'
        $literals = @()
        foreach ($file in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
            $tokens = $null; $errors = $null; $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot $file), [ref]$tokens, [ref]$errors)
            Assert-True (@($errors).Count -eq 0) 'Runtime sources must parse.'
            $literals += @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst] -and $node.Value -ceq '1.0.2' }, $true) | ForEach-Object { [pscustomobject]@{ source = $file; line = $_.Extent.StartLineNumber; text = $_.Extent.Text } })
        }
        Assert-True ($literals.Count -eq 1 -and $literals[0].source -ceq 'AudioFileForPhone.Helpers.ps1') 'Only the version helper may define the runtime 1.0.2 literal.'
        $releaseTarget = [IO.File]::ReadAllText((Join-Path $projectRoot 'docs/codex-v1.0.1/CORRECTIVE_RELEASE_TARGET.json')) | ConvertFrom-Json
        $expectedTag = 'v' + $appVersion; $expectedZip = 'AudioFileForPhone-' + $expectedTag + '.zip'
        Assert-True ($releaseTarget.target_version -ceq $appVersion -and $releaseTarget.target_tag -ceq $expectedTag -and $releaseTarget.runtime_zip -ceq $expectedZip -and $releaseTarget.release_title -ceq ('AudioFileForPhone ' + $expectedTag)) 'Corrective release target must agree with the runtime version, tag, title and ZIP name.'
        $historicalTargetPath = Join-Path $projectRoot 'docs/codex-v1.0.1/RELEASE_TARGET.json'
        $historicalTarget = [IO.File]::ReadAllText($historicalTargetPath) | ConvertFrom-Json
        Assert-True ($historicalTarget.target_version -ceq '1.0.1' -and $historicalTarget.target_tag -ceq 'v1.0.1' -and
            $historicalTarget.runtime_zip -ceq 'AudioFileForPhone-v1.0.1.zip' -and $historicalTarget.release_title -ceq 'AudioFileForPhone v1.0.1') 'Historical v1.0.1 release identity must remain separate from the corrective target.'
        $case['app_version'] = $appVersion; $case['runtime_version_literals'] = $literals
        $case['release_target_contract'] = 'docs/codex-v1.0.1/CORRECTIVE_RELEASE_TARGET.json'
        $case['release_target_tag'] = $expectedTag; $case['release_target_zip_name'] = $expectedZip
        $case['historical_release_target_version'] = $historicalTarget.target_version
        $case['historical_release_target_sha256'] = (Get-FileHash -LiteralPath $historicalTargetPath).Hash.ToLowerInvariant()
        $case['package_limit'] = 'Actual package builder and exact release ZIP are later tasks; no package-build result claimed.'
    }
    $seedDir = Join-Path $testRoot 'S'; [IO.Directory]::CreateDirectory($seedDir) | Out-Null
    $seeds = @()
    $formats = @(
        @{ extension = 'mp3'; codec = 'libmp3lame'; label = 'MP3'; nested = $false },
        @{ extension = 'm4a'; codec = 'aac'; label = 'M4A'; nested = $true },
        @{ extension = 'ogg'; codec = 'libvorbis'; label = 'Vorbis'; nested = $true },
        @{ extension = 'ogg'; codec = 'libopus'; label = 'Opus'; nested = $false }
    )
    for ($index = 0; $index -lt $formats.Count; $index++) {
        $format = $formats[$index]; $name = '2024-01-0' + ($index + 1) + ' ' + $format.label + ' synthetic episode.' + $format.extension
        $path = Join-Path $seedDir $name
        $arguments = @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.25', '-c:a', $format.codec, '-metadata', 'artist=Synthetic source artist', '-metadata', 'album=Synthetic source album')
        if ($format.label -cne 'Opus') { $arguments += @('-metadata', 'title=Synthetic source title') }
        Invoke-OwnedNative $ffmpeg ($arguments + @($path)) | Out-Null; Add-Fixture $path
        $seeds += [pscustomobject]@{ name = $name; path = $path; nested = $format.nested }
    }
    $seedCover = Join-Path $seedDir 'cover.png'
    Invoke-OwnedNative $ffmpeg @('-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=blue:s=32x32', '-frames:v', '1', '-threads', '1', $seedCover) | Out-Null
    Add-Fixture $seedCover
    for ($number = 1; $number -le $examples.Count; $number++) {
        $fixture = New-ExampleFixture $number ([string]$examples[$number - 1].code)
        Invoke-Case ('execute exact Get-Help example ' + $number) 'A45,A46' {
            param($case)
            $before = Get-TreeInventory $testRoot; $result = Invoke-Example $fixture $number
            $case['code'] = $examples[$number - 1].code; $case['exit_code'] = $result.exit_code
            $case['console_diagnostics'] = $result.text.Replace($testRoot, '<OWNED_TEMP>'); $case['guard_audit'] = $result.audit
            if ($number -le 3) { $case['outputs'] = Assert-ExampleOutputs $fixture $result $number }
            else {
                $after = Get-TreeInventory $testRoot
                Assert-True (($before | ConvertTo-Json -Compress -Depth 8) -ceq ($after | ConvertTo-Json -Compress -Depth 8)) 'Preview/helper-version example must preserve exact complete owned tree.'
                Assert-True (@($result.audit.native_proofs).Count -eq 0) 'Preview/helper-version example must have no native descendant.'
                $case['inventory_before'] = $before; $case['inventory_after'] = $after; $case['inventory_unchanged'] = $true
                if ($number -eq 4) {
                    $plans = @($result.text -split '\r?\n' | Where-Object { $_.StartsWith('[PLAN] ', [StringComparison]::Ordinal) } | ForEach-Object { $_.Substring(7) | ConvertFrom-Json })
                    Assert-True ($plans.Count -eq 4 -and @($plans | Where-Object { $_.duration -cne 'unknown' }).Count -eq 0 -and $result.text.Contains('status=Previewed; total=4; processed=0; converted=0; failed=0; not_processed=4; scan_excluded=0; unsupported=2;')) 'Preview must retain exact four unknown-duration plans and honest counts.'
                    Assert-True (-not (Test-Path -LiteralPath $fixture.parent)) 'Preview must not create a missing output parent.'
                    $case['plans'] = $plans
                } else { Assert-True (@($result.text -split '\r?\n' | Where-Object { $_ -ceq $appVersion }).Count -eq 1) 'Exact functions-only helper example must output the authoritative version once.' }
            }
        }
    }
    $report.copied_application_bytes_unchanged = $true; $report.status = 'pass'; $exitCode = 0
} catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error
} finally {
    $report.descendant_release_proved = $descendantReleaseProved; $report.children_disposed = $descendantReleaseProved
    foreach ($inventory in @('source', 'synthetic')) {
        try {
            $after = if ($inventory -ceq 'source') { Get-SourceInventory } else { Get-FixtureInventory }
            $report[$inventory + '_after'] = $after
            $same = (($report[$inventory + '_before'] | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress))
            $report[$inventory + '_unchanged'] = $same; Assert-True $same "$inventory SHA256 must remain unchanged."
        } catch { $report.status = 'fail'; $exitCode = 1; $report[$inventory + '_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    try {
        if ($ownedRootCreated -and $descendantReleaseProved -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exact exclusively reserved TEMP root.'
            Assert-NoReparse $resolved; Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact CreateNew ownership token.'
            Get-SafeTree $resolved | Out-Null; [IO.Directory]::Delete($resolved, $true); $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    if (-not $descendantReleaseProved) { $report.status = 'fail'; $exitCode = 1 }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
Write-Host "T18 help: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
