<#
.SYNOPSIS
Converts a folder of MP3, M4A and OGG audio to smaller MP3 files.

.DESCRIPTION
Recursively snapshots supported files, preserves relative folders and writes a
new AudioForPhone_<bitrate>kbps_<timestamp>[_N] run under the configured Windows
Music folder or OutputParent. Default output is 64 kbps CBR MP3. Sources are
preserved. Names keep a valid leading date or use LastWriteTime, then a sanitized
NFC title with a bounded, collision-safe suffix. Folder names are preserved.

Conversion changes bitrate, names and supported metadata. It performs no loudness
normalization, noise reduction or EQ. .opus, .wav, .flac and .m4b are not scanned.
OGG supports Vorbis and Opus in .ogg files. FFmpeg and ffprobe are external tools,
selected by FfmpegDirectory, saved config, a pair beside the script, then PATH.
Conversion requires libmp3lame. Interactive launches offer deliberate setup repair
when tool selection fails; other launches stop with an exact setup command.

Source title and supported tags are copied; a missing/empty title uses the planned
output basename. Nonblank Artist/Album override source tags. Source artwork is
dropped by default; an explicit JPEG/PNG replaces it with one attached JPEG cover.
FFmpeg chapter mapping is retained, without splitting tracks or guaranteeing
chapter navigation or resume on a phone. Each MP3 is validated and fully decoded
before publication. Local logs and a JSON manifest report actual outcomes.

.PARAMETER InputFolder
Exactly one existing filesystem folder below a drive/share root. Input and output
ancestors with reparse points are rejected. Descendant links and recognized prior
output runs are skipped; an inaccessible subtree aborts discovery.

.PARAMETER FromBatchLauncher
Internal BAT entry point. Reads the single folder from the process environment
without evaluating it and enables the existing interactive workflow.

.PARAMETER BitrateKbps
CBR MP3 bitrate in kbps; default 64. Accepted: 8, 16, 24, 32, 40, 48, 56, 64, 80,
96, 112, 128, 144, 160, 192, 224, 256, 320. Rates depend on source sample rate.

.PARAMETER MaxBaseLength
Maximum output basename length in UTF-16 units, including date and collision
suffix, excluding .mp3. Default 60; range 24-180. Truncation keeps Unicode scalars.
Full file/working paths must be below 260 units; created directories below 248.
These limits do not guarantee acceptance by every phone or MTP implementation.

.PARAMETER Interactive
Offers dependency repair when needed, then Enter to start, M to customize batch
metadata or Q to cancel after preflight. Metadata is never saved between batches.
Setup asks before remembering a selected tool pair.
Use an STA console for the picker. Without this switch there are no prompts.
DryRun explicitly ignores Interactive.

.PARAMETER CoverPath
Optional readable JPEG/PNG cover. Invalid explicit covers fail preflight.
Selected artwork replaces source artwork in every output as one attached JPEG.
Omit to drop source artwork. Large images produce warnings and can bloat outputs.

.PARAMETER Artist
Optional batch artist override. Omitted or whitespace-only values retain source tags.

.PARAMETER Album
Optional batch album override. Omitted or whitespace-only values retain source tags.

.PARAMETER OutputParent
Optional destination parent. Default: current user's configured Windows Music
folder, including a moved location. A missing explicit parent is created during
conversion; relative paths use the current PowerShell location. Preview does not
create a parent or test writability.

.PARAMETER DryRun
Plans source-to-output names without writing directories, audio, logs or manifests,
calling tools, checking cover/media or prompting. Root is provisional; durations,
writability and dependency availability remain unverified. Returns Previewed/0 on
success. Remove this switch to convert with the same naming/metadata options.

.PARAMETER ProbeTimeoutSeconds
Advanced media-probe deadline in seconds (default 60, range 1-2147483). Increase
for large files or slow storage after a probe Timeout. Applies to source and output
probes. Encoding and full audio decode have no short fixed runtime ceiling.

.PARAMETER FfmpegDirectory
Optional filesystem directory containing both ffmpeg.exe and ffprobe.exe. Overrides
saved/app-local/PATH selection for this run only; never saves or changes PATH.
Invalid explicit choices fail preflight without falling back to another build.

.PARAMETER ConfigPath
Optional JSON config file location for portable use or isolated environments.
Overrides the default Windows LocalApplicationData\AudioFileForPhone\config.json.
Relative paths use the current PowerShell location. Normal conversion only reads
config; preview does not read it. Interactive dependency repair can remember a
selection only after affirmative consent. Corrupt/new-schema config is preserved;
use an explicit FfmpegDirectory override or another writable ConfigPath.

.EXAMPLE
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts'

Convert recursively at the default 64 kbps to a new run in the Windows Music folder.

.EXAMPLE
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -BitrateKbps 96 -MaxBaseLength 50

Convert to an explicit destination at 96 kbps with shorter basenames.

.EXAMPLE
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -CoverPath '.\cover.png' -Artist 'Example narrator' -Album 'Example book'

Convert using an explicit cover and batch tags, with no interactive prompts.

.EXAMPLE
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -DryRun -Interactive

Preview names without writes, tool calls or prompts. Interactive is ignored.

.EXAMPLE
. .\AudioFileForPhone.Helpers.ps1; Get-AudioAppVersion

Read the authoritative app version used by the banner and local run manifest.
Dot-sourcing this functions-only helper does not start a conversion.

.OUTPUTS
Console diagnostics and progress; conversion creates MP3 files and local records.
No pipeline result object. Inspect the process exit code in a caller.

.NOTES
Windows 11; Windows PowerShell 5.1 and PowerShell 7. Scripts are unsigned.
Get-AudioAppVersion in AudioFileForPhone.Helpers.ps1 is the single version source;
package metadata must read it. See README.md, SUPPORT.md and CHANGELOG.md.

Exit codes: 0 Completed (or Previewed); 1 preflight/no supported files/fatal error;
2 CompletedWithFailures (independent files continue); 130 controlled Cancelled.
Parameter binding and forced termination may use host-defined codes.

Ctrl+C capture begins after metadata prompts in a supported Windows console.
It stops this run's child, preserving sources and completed outputs. The interrupted
file is not a completed outcome. Redirected input, other hosts, preflight/prompts,
Ctrl+Break and forced window/process closure have host-specific limits; forced
termination can bypass cleanup and leave a child or clearly incomplete .partial.
Unproved child exit/working-file identity causes retention and an exact diagnostic.
Later runs do not reclaim abandoned files automatically.

Review trusted source and applicable execution policy before running unsigned
scripts. Do not bypass enforced organization policy. SUPPORT.md documents the
launcher's existing process policy request and permitted direct launch guidance.
Logs can contain private paths/metadata; redact before sharing. No automatic uploads.

.LINK
https://github.com/PikkuJanne/AudioFileForPhone
#>
[CmdletBinding(DefaultParameterSetName = 'Direct')]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Direct')]
    [string]$InputFolder,

    [Parameter(Mandatory = $true, ParameterSetName = 'BatchLauncher')]
    [switch]$FromBatchLauncher,

    [int]$BitrateKbps = 64,

    # Max length of the base filename, without extension
    [int]$MaxBaseLength = 60,

    # Enables simple TUI prompts + file picker, intended for .bat usage
    [switch]$Interactive,

    # Non-interactive overrides, optional
    [string]$CoverPath,
    [string]$Artist,
    [string]$Album,

    # Optional destination parent; defaults to the configured Windows Music folder
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$OutputParent,

    # Read-only preview using the same discovery and naming planner as conversion
    [switch]$DryRun,

    [ValidateRange(1, 2147483)]
    [int]$ProbeTimeoutSeconds = 60,

    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$FfmpegDirectory,

    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$ConfigPath
)

if ($FromBatchLauncher) {
    $InputFolder = [Environment]::GetEnvironmentVariable('AUDIOFILEFORPHONE_INPUT', 'Process')
    $Interactive = $true
}

# --- Script path & dir, computed ONCE here, not inside functions ---
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

$ErrorActionPreference = 'Stop'
$runStartedUtc = [datetime]::UtcNow.ToString('o')
$runWatch = [Diagnostics.Stopwatch]::StartNew()
$run = $null; $logPath = $null; $outputBase = $null
$total = 0; $ok = 0; $failed = 0; $scanExcluded = 0; $unsupported = 0
$batchExitCode = 1; $runStatus = 'FailedBeforeConversion'; $currentOutcome = $null
$cancelCleanupNote = $null
$consoleCaptureNotice = ''
$manifest = $null; $manifestPath = $null; $activeRecordIndex = -1; $fileWatch = $null
$media = $null; $transaction = $null; $diagnosticError = ''
$outputAudioPlan = $null; $encoderCapabilities = $null
$encoderReleaseUnproved = $false
$coverValidation = $null
$script:AudioCancellationContext = $null
$script:AudioProgressDisplayEnabled = $true
$diagnosticsReady = $false
$diagnosticStage = 'Bootstrap'; $diagnosticCode = 'HelperMissing'
$toolDiagnosticContext = @{}
$toolInfo = $null

function Write-AudioProgress {
    param([string]$Status, [int]$PercentComplete, [switch]$Completed,
          [int]$Id = 0, [int]$ParentId = -1, [string]$Activity = ("Converting audio to {0}kbps MP3" -f $BitrateKbps))
    if (-not $script:AudioProgressDisplayEnabled) { return }
    try {
        Write-Progress -Id $Id -ParentId $ParentId -Activity $Activity `
            -Status $Status -PercentComplete $PercentComplete -Completed:$Completed -ErrorAction Stop
    }
    catch {
        $script:AudioProgressDisplayEnabled = $false
        Write-Warning "Progress display failed: $($_.Exception.Message); display disabled." -ErrorAction Continue
    }
}

function Write-AudioBatchProgress {
    param([string]$Detail, [switch]$Completed)
    $processed = $ok + $failed
    $percent = if ($total -gt 0) { [int][math]::Floor(100.0 * $processed / $total) } else { 0 }
    $status = '{0} / {1} processed; {2} converted; {3} failed; {4}' -f $processed, $total, $ok, $failed, $Detail
    Write-AudioProgress -Status $status -PercentComplete $percent -Completed:$Completed
}

function Get-AudioResultSummary {
    $elapsed = $runWatch.Elapsed.TotalSeconds.ToString('F3', [Globalization.CultureInfo]::InvariantCulture)
    return ('status={0}; total={1}; processed={2}; converted={3}; failed={4}; not_processed={5}; scan_excluded={6}; unsupported={7}; elapsed_seconds={8}' -f `
        $runStatus, $total, ($ok + $failed), $ok, $failed, ($total - $ok - $failed), $scanExcluded, $unsupported, $elapsed)
}

try {
    $diagnosticsPath = Join-Path $ScriptDir 'AudioFileForPhone.Diagnostics.ps1'
    if (-not (Test-Path -LiteralPath $diagnosticsPath -PathType Leaf)) { throw 'Required runtime file is missing: AudioFileForPhone.Diagnostics.ps1. Restore the complete application package.' }
    . $diagnosticsPath
    $diagnosticsReady = $true
Write-Host "[INFO] Script path : $ScriptPath"
Write-Host "[INFO] Script dir  : $ScriptDir"
Write-Host "[INFO] Raw input   : '$InputFolder'"
Write-Host "[INFO] Bitrate     : ${BitrateKbps}kbps"
Write-Host "[INFO] Max name    : $MaxBaseLength chars"
Write-Host "[INFO] Interactive : $Interactive"
Write-Host ""

# --- Preflight: reject prerequisites before optional prompts or run creation ---
Write-Host '[STATE] Preflight: checking input, destination and prerequisites.'
try {
    $helperPath = Join-Path $ScriptDir 'AudioFileForPhone.Helpers.ps1'
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) { throw ('Required runtime file is missing: AudioFileForPhone.Helpers.ps1. Restore the complete application package.') }
    . $helperPath
    Write-Host ("==== AudioFileForPhone v{0} ====" -f (Get-AudioAppVersion))
    $diagnosticStage = 'Parameters'; $diagnosticCode = 'StartupFailed'
    Assert-AudioParameters -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength
    $diagnosticStage = 'InputDiscovery'; $diagnosticCode = 'InputInvalid'
    $InputFolder = Get-InputDirectory -InputFolder $InputFolder
    $diagnosticStage = 'OutputPreflight'; $diagnosticCode = 'OutputUnwritable'
    if (-not [string]::IsNullOrWhiteSpace($OutputParent)) { Assert-AudioOutputParentSpelling -Path $OutputParent }
    $outputParentPath = Get-OutputParent -OutputParent $OutputParent
    $timestamp = [datetime]::Now.ToString('yyyyMMdd_HHmmss', [Globalization.CultureInfo]::InvariantCulture)
    $provisionalRun = Get-AudioAvailableRunCandidate -OutputParent $outputParentPath -InputFolder $InputFolder -BitrateKbps $BitrateKbps -Timestamp $timestamp
    $outputRoot = $provisionalRun.OutputRoot
    $diagnosticStage = 'InputDiscovery'; $diagnosticCode = 'InputInvalid'
    Write-Host "[INFO] Scanning for audio files (.mp3/.m4a/.ogg) under: $InputFolder"
    $snapshot = Get-AudioInputSnapshot -InputFolder $InputFolder -OutputRoot $outputRoot
    foreach ($skip in $snapshot.Skipped) { Write-Warning ("{0}: {1}" -f $skip.Reason, $skip.Path) }
    $files = @($snapshot.Files)
    $total = $files.Count
    $scanExcluded = @($snapshot.Skipped).Count
    $unsupported = $snapshot.UnsupportedCount
    if ($files.Count -eq 0) { throw "No MP3/M4A/OGG files found under: $InputFolder" }
    $plans = @(Get-AudioBatchNamePlan -Files $files -InputFolder $InputFolder -OutputRoot $outputRoot -MaxBaseLength $MaxBaseLength)
    if (-not $DryRun) {
        $diagnosticStage = 'ToolSelection'; $diagnosticCode = 'DependencyInvalid'
        $selectionOptions = @{ ConfigPath = $ConfigPath; ScriptDirectory = $ScriptDir; DiagnosticContext = $toolDiagnosticContext }
        if ($PSBoundParameters.ContainsKey('FfmpegDirectory')) { $selectionOptions.FfmpegDirectory = $FfmpegDirectory }
        try { $toolInfo = Resolve-AudioToolSelection @selectionOptions }
        catch [OperationCanceledException] { throw }
        catch {
            $selectionError = $_.Exception.Message
            if ($null -ne $toolDiagnosticContext.NativeResult -and
                (-not $toolDiagnosticContext.NativeResult.ProcessReleased -or -not $toolDiagnosticContext.NativeResult.PipeDrainCompleted)) {
                throw "$selectionError Native prerequisite release/pipe completion is unproved. No setup or further native operation was started; review the retained local diagnostic."
            }
            $repairCommand = Get-AudioSetupRepairCommand -ScriptDirectory $ScriptDir -ConfigPath $ConfigPath
            # Keep the copyable action outside formatted error records, which can
            # wrap long commands in Windows PowerShell 5.1.
            Write-Host ('[SETUP] Existing-tool repair: ' + $repairCommand)
            if (-not $Interactive) { throw "$selectionError Existing-tool repair: $repairCommand" }
            $setup = Invoke-AudioToolSetup -ScriptDirectory $ScriptDir -ConfigPath $ConfigPath -Reason $selectionError
            if ($setup.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Dependency setup cancelled before conversion.')) }
            if ($setup.Status -ne 'Ready' -or $null -eq $setup.Selection) { throw "$($setup.Error) Existing-tool repair: $repairCommand" }
            $toolInfo = $setup.Selection
            Write-Host '[SETUP] Continuing this launch with the validated selected tools.'
        }
        $ffmpeg = $toolInfo.Ffmpeg.Path
        $ffprobe = $toolInfo.Ffprobe.Path
        $diagnosticStage = 'CoverValidation'; $diagnosticCode = 'CoverInvalid'
        if ($PSBoundParameters.ContainsKey('CoverPath')) {
            $coverValidation = Get-ValidatedCoverPath -Path $CoverPath -FfmpegPath $ffmpeg -PassThru
            $CoverPath = $coverValidation.Path
        }
        $diagnosticStage = 'OutputPreflight'; $diagnosticCode = 'OutputUnwritable'
        Test-OutputWritable -Path $outputParentPath
    }
}
catch [OperationCanceledException] { throw }
catch {
    throw "Preflight failed: $($_.Exception.Message)"
}

if ($DryRun) {
    $outputBase = Join-Path $outputRoot (Split-Path $InputFolder -Leaf)
    Write-Host "[PREVIEW] Provisional output root: $outputRoot"
    Write-Host '[PREVIEW] Timestamp and reservation are provisional; an actual run can use a different root.'
    Write-Host '[PREVIEW] Durations: unknown (media has not been probed).'
    Write-Host '[PREVIEW] Destination writability: unverified (no write probe).'
    Write-Host '[PREVIEW] Tools, media and cover validation: unverified.'
    if ($Interactive) { Write-Host '[PREVIEW] -Interactive is ignored; no metadata prompts are shown.' }
    Write-Host ('[PREVIEW] Scan exclusions: {0}; unsupported files: {1} (all extensions except .mp3, .m4a and .ogg).' -f $scanExcluded, $unsupported)
    Write-Host '[PREVIEW] Naming, date prefixes and collision suffixes use the same planner as conversion.'
    foreach ($plan in $plans) {
        Write-Host ('[PREVIEW] {0} -> {1}' -f $plan.SourceRelativePath, $plan.OutputRelativePath)
        foreach ($warning in $plan.Warnings) {
            Write-Warning ('{0}: {1}' -f $plan.SourceRelativePath, $warning)
        }
        $previewPlan = [ordered]@{
            source_relative_path = [string]$plan.SourceRelativePath
            output_relative_path = [string]$plan.OutputRelativePath
            provisional_output_path = [string]$plan.OutputPath
            duration = 'unknown'
        } | ConvertTo-Json -Compress
        Write-Host ('[PLAN] ' + $previewPlan)
    }
    $runStatus = 'Previewed'
    $batchExitCode = 0
}
else {
$diagnosticStage = 'Conversion'; $diagnosticCode = 'StartupFailed'

function Read-MetadataResponse {
    param([string]$Prompt)
    $answer = Read-AudioMetadataResponse -Prompt $Prompt
    if ($null -eq $answer) {
        throw (New-Object OperationCanceledException('Metadata input ended; no conversion has started.'))
    }
    return $answer.Trim()
}

function Read-MetadataYesNo {
    param([string]$Prompt)
    switch ((Read-MetadataResponse -Prompt ($Prompt + ' (y/N; Q = cancel)')).ToUpperInvariant()) {
        'Y' { return $true }
        'YES' { return $true }
        '' { return $false }
        'N' { return $false }
        'NO' { return $false }
        'Q' { throw (New-Object OperationCanceledException('Metadata customization cancelled before conversion.')) }
        default { throw 'Invalid metadata choice. Use Y, N or Q; no conversion has started.' }
    }
}

# --- Optional: interactive metadata step, only if requested ---
if ($Interactive) {
    Write-Host ('Ready: {0} supported files -> {1} kbps CBR MP3' -f $total, $BitrateKbps)
    Write-Host 'Enter = start with defaults | M = customize metadata | Q = cancel'
    Write-Host 'Waiting for your selection (no conversion has started).'
    $customizeMetadata = $false
    switch ((Read-MetadataResponse -Prompt 'Selection').ToUpperInvariant()) {
        '' { }
        'M' { $customizeMetadata = $true }
        'Q' { throw (New-Object OperationCanceledException('Conversion cancelled at the ready menu.')) }
        default { throw 'Invalid selection. Use Enter, M or Q; no conversion has started.' }
    }
    if ($customizeMetadata) {
        Write-Host 'Customize this batch: source tags remain unless overridden; source artwork is dropped unless a cover is supplied.'
        Write-Host 'Explicit parameters are retained. Enter skips an optional value; conversion starts after these choices. Nothing is saved for the next batch.'

        # Cover
        if ([string]::IsNullOrWhiteSpace($CoverPath)) {
            $doCover = Read-MetadataYesNo -Prompt 'Add album cover to output MP3 metadata?'
            if ($doCover) {
                $picked = Select-AudioMetadataCover
                if ($picked) {
                    try {
                        $coverValidation = Get-ValidatedCoverPath -Path $picked -FfmpegPath $ffmpeg -PassThru
                        $CoverPath = $coverValidation.Path
                    }
                    catch {
                        throw "Selected cover failed validation: $($_.Exception.Message)"
                    }
                    Write-Host "[INFO] Cover selected: $CoverPath"

                    $coverDiag = $coverValidation.Diagnostics
                    if ($coverDiag.SizeMB -ne $null) {
                        Write-Host ("[INFO] Cover size: {0} MB" -f $coverDiag.SizeMB)
                    }
                    if (($coverDiag.Width -ne $null) -and ($coverDiag.Height -ne $null)) {
                        Write-Host ("[INFO] Cover dimensions: {0}x{1}" -f $coverDiag.Width, $coverDiag.Height)
                    }
                    foreach ($w in $coverDiag.Warnings) {
                        Write-Warning "[WARN] $w"
                    }
                }
                else {
                    Write-Host "[WARN] No valid cover selected. Continuing without embedded cover."
                    $CoverPath = $null
                }
            }
        }

        # Artist
        if (-not $PSBoundParameters.ContainsKey('Artist')) {
            $doArtist = Read-MetadataYesNo -Prompt 'Set Artist tag manually for all output files?'
            if ($doArtist) {
                $Artist = Read-MetadataResponse -Prompt 'Artist (Enter = retain source tag)'
                if ([string]::IsNullOrWhiteSpace($Artist)) { $Artist = $null }
            }
        }

        # Album
        if (-not $PSBoundParameters.ContainsKey('Album')) {
            $doAlbum = Read-MetadataYesNo -Prompt 'Set Album tag manually for all output files?'
            if ($doAlbum) {
                $Album = Read-MetadataResponse -Prompt 'Album (Enter = retain source tag)'
                if ([string]::IsNullOrWhiteSpace($Album)) { $Album = $null }
            }
        }

    }
    Write-Host '[STATE] Starting conversion with this batch metadata.'
}

# Console input belongs to this invocation only after interactive prompts finish.
# Native calls share this context; redirected/unsupported hosts retain their own
# interruption behavior and cannot promise a controlled exit code.
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '[{0}] {1}' -f $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $logPath -ErrorAction Stop -Value $line
}

function Save-AudioManifest {
    param([string]$Checkpoint, [string]$Status = 'Running', [AllowNull()][object]$ExitCode)
    Update-AudioRunManifest -Manifest $manifest -Status $Status -ExitCode $ExitCode `
        -ElapsedSeconds $runWatch.Elapsed.TotalSeconds -DiagnosticError $diagnosticError
    if ($manifest.Data.totals.converted -ne $ok -or $manifest.Data.totals.failed -ne $failed) {
        throw 'Run manifest outcomes do not match the committed conversion counts.'
    }
    Write-AudioRunManifest -Manifest $manifest -Checkpoint $Checkpoint
}

function Write-FileNativeDiagnostics {
    foreach ($entry in @(
        @{ Stage = 'SourceProbe'; Result = if ($media) { $media.NativeResult } else { $null } },
        @{ Stage = 'EncoderCapabilities'; Result = if ($encoderCapabilities) { $encoderCapabilities.NativeResult } else { $null } },
        @{ Stage = 'Encoder'; Result = if ($transaction) { $transaction.EncoderResult } else { $null } },
        @{ Stage = 'OutputProbe'; Result = if ($transaction -and $transaction.ValidationResult) { $transaction.ValidationResult.ProbeResult } else { $null } },
        @{ Stage = 'OutputDecode'; Result = if ($transaction -and $transaction.ValidationResult) { $transaction.ValidationResult.DecodeResult } else { $null } }
    )) {
        foreach ($line in @(Get-AudioNativeDiagnosticLines -Stage $entry.Stage -NativeResult $entry.Result)) { Write-Log $line 'DEBUG' }
    }
}

function Set-ActiveAudioRecordCancelled {
    if ($null -eq $manifest -or $activeRecordIndex -lt 0) { return }
    $record = $manifest.Data.records[$activeRecordIndex]
    if ($record.status -ne 'NotProcessed') { return }
    if ($fileWatch) { $fileWatch.Stop() }
    $elapsed = if ($fileWatch) { $fileWatch.Elapsed.TotalSeconds } else { 0 }
    Set-AudioManifestRecord -Record $record -Status Cancelled -Code Cancelled -Reason 'User requested cancellation.' `
        -SourcePath $file.FullName -OutputPath $outPath -Media $media -Transaction $transaction -ElapsedSeconds $elapsed -OutputPlan $outputAudioPlan
}

$script:AudioCancellationContext = New-AudioCancellationContext -CaptureConsole
$consoleCaptureNotice = $script:AudioCancellationContext.ConsoleCaptureError
Assert-AudioNotCancelled

# --- Output root + log setup ---
$diagnosticStage = 'OutputInitialization'; $diagnosticCode = 'OutputUnwritable'
try {
    $run = New-AudioRunReservation -OutputParent $outputParentPath -InputFolder $InputFolder -Files $files -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength -Timestamp $timestamp -StartCounter $provisionalRun.Counter
    $outputRoot = $run.OutputRoot
    $plans = @($run.Plans)
    $logPath = $run.LogPath
    $manifest = New-AudioRunManifest -Run $run -Snapshot $snapshot -InputFolder $InputFolder -ScriptPath $ScriptPath `
        -ToolInfo $toolInfo -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength -CoverPath $CoverPath -Artist $Artist -Album $Album
    $manifestPath = $manifest.Path
    $manifest.Data.run.started_utc = $runStartedUtc
    Save-AudioManifest -Checkpoint Initial
    Write-Host "[INFO] Output root      : $outputRoot"

    # --- Log file ---
    "==== AudioFileForPhone Log ====" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Start time    : $runStartedUtc" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Input folder  : $InputFolder"    | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Output root   : $outputRoot"     | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Bitrate (kbps): $BitrateKbps"    | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Max base len  : $MaxBaseLength"  | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "CoverPath     : $CoverPath"      | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Artist        : $Artist"         | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Album         : $Album"          | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "FFmpeg path   : $($toolInfo.Ffmpeg.Path)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "FFmpeg version: $($toolInfo.Ffmpeg.Version)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "FFprobe path  : $($toolInfo.Ffprobe.Path)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "FFprobe version: $($toolInfo.Ffprobe.Version)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Tool selection: $($toolInfo.Origin)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "App version   : $($manifest.Data.app_version)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Entry SHA256  : $($manifest.Data.build.entry_sha256)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Helper SHA256 : $($manifest.Data.build.helper_sha256)" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Manifest      : $manifestPath" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    ('Policies      : ' + ($manifest.Data.policies | ConvertTo-Json -Depth 4 -Compress)) | Add-Content -LiteralPath $logPath -ErrorAction Stop
    ""                              | Add-Content -LiteralPath $logPath -ErrorAction Stop
}
catch {
    throw "Could not initialize output root, log or manifest '$outputRoot': $($_.Exception.Message)"
}
$diagnosticStage = 'Conversion'; $diagnosticCode = 'StartupFailed'

if ($script:AudioCancellationContext.ConsoleCaptureEnabled) {
    Write-Log 'Press Ctrl+C during conversion to cancel this run safely.'
}
else {
    Write-Log ("Controlled console Ctrl+C is unavailable in this host: {0}" -f $script:AudioCancellationContext.ConsoleCaptureError) 'WARN'
}

foreach ($skip in $snapshot.Skipped) { Write-Log ("{0}: {1}" -f $skip.Reason, $skip.Path) 'WARN' }

# --- Log diagnostics for the cover already validated before run creation ---
if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
    $coverDiag = $coverValidation.Diagnostics
    foreach ($line in @(Get-AudioNativeDiagnosticLines -Stage 'CoverDecode' -NativeResult $coverValidation.NativeResult)) { Write-Log $line 'DEBUG' }

    if ($coverDiag.SizeMB -ne $null) {
        Write-Log ("Cover size: {0} MB" -f $coverDiag.SizeMB) "INFO"
    }
    if (($coverDiag.Width -ne $null) -and ($coverDiag.Height -ne $null)) {
        Write-Log ("Cover dimensions: {0}x{1}" -f $coverDiag.Width, $coverDiag.Height) "INFO"
    }
    foreach ($w in $coverDiag.Warnings) {
        Write-Log $w "WARN"
    }

    Write-Log ("Cover enabled: {0}" -f $CoverPath) "INFO"
}

# --- Output base, mirrors input folder name ---
$inputLeaf  = Split-Path $InputFolder -Leaf
$outputBase = Join-Path $outputRoot $inputLeaf

Write-Log ("Output base      : {0}" -f $outputBase)

try { [IO.Directory]::CreateDirectory($outputBase) | Out-Null }
catch {
    throw "Could not create output base '$outputBase': $($_.Exception.Message)"
}

Write-Host ""
Write-Log "Using completed input snapshot from: $InputFolder"
Write-Log ("Found {0} audio file(s) (.mp3/.m4a/.ogg)." -f $files.Count)
Write-Host ""

# --- Main conversion + sanitize loop ---
$index  = 0
$ok     = 0
$failed = 0
$total  = $files.Count

foreach ($plan in $plans) {
    Assert-AudioNotCancelled
    $currentOutcome = $null
    $file = $plan.SourceFile
    $index++
    $activeRecordIndex = $index - 1
    $fileWatch = [Diagnostics.Stopwatch]::StartNew()
    $media = $null; $transaction = $null; $outputAudioPlan = $null
    $outPath = $plan.OutputPath

    Write-Host "------------------------------------------------------------"
    Write-Log ("Processing file {0}/{1}: {2}" -f $index, $total, $file.FullName)

    Write-Log '[STATE] Probing source; duration unknown.'
    Write-AudioBatchProgress -Detail ("Probing file {0} / {1}: {2}" -f $index, $total, $file.Name)
    Write-AudioProgress -Id 1 -ParentId 0 -Activity $file.Name -Status 'Probing source; duration unknown' -PercentComplete -1
    $script:AudioLastDisplayedPhase = ''
    $fileProgressCallback = {
        param($progress)
        if ($script:AudioLastDisplayedPhase -cne $progress.Phase) {
            $phaseDetail = switch ($progress.Phase) {
                'Encoding' { 'Encoding audio; output is not yet validated.' }
                'Validating' { 'Validating output and fully decoding audio; output is not yet published.' }
                'Promoting' { 'Publishing validated output.' }
                default { $progress.Phase }
            }
            Write-Log ('[STATE] ' + $phaseDetail)
            $script:AudioLastDisplayedPhase = $progress.Phase
        }
        $detail = if ($progress.Phase -eq 'Encoding') {
            if ($progress.PercentComplete -ge 0) { 'Encoding ({0}%)' -f $progress.PercentComplete }
            else { 'Encoding (indeterminate)' }
        } else { $progress.Phase }
        Write-AudioProgress -Id 1 -ParentId 0 -Activity $file.Name -Status $detail -PercentComplete $progress.PercentComplete
    }

    $outDir = $plan.OutputDirectory
    $outPath = $plan.OutputPath
    $newBase = $plan.BaseName
    foreach ($warning in $plan.Warnings) { Write-Log ("{0}: {1}" -f $file.FullName, $warning) 'WARN' }
    Write-Log ("Sanitized base: '{0}' (from '{1}')" -f $newBase, $plan.OriginalBase) "DEBUG"

    Write-Host "       Source : $($file.FullName)"
    Write-Host "       Target : $outPath"
    Write-Log  ("Output file   : {0}" -f $outPath) "DEBUG"

    # A failed probe is a file failure, distinct from a valid missing title.
    $transaction = $null
    $fileStatus = 'ProbeFailed'; $fileReason = ''
    try {
    Write-Host "       [DEBUG] Running ffprobe..."
    $media = Get-AudioMediaInfo -Path $file.FullName -FfprobePath $ffprobe -ProbeTimeoutSeconds $ProbeTimeoutSeconds
    if ($media.Status -eq 'Cancelled') { Assert-AudioNotCancelled }
    if ($media.Status -eq 'Timeout') { $fileStatus = 'Timeout' }
    if ($media.Status -ne 'Success') {
        throw "Source probe failed ($($media.Status)): $($media.Error)"
    }
    $fileStatus = 'InvalidSourceDuration'
    if ($media.DurationStatus -ne 'Valid') {
        throw "Source duration $($media.DurationStatus); a finite positive source duration is required before conversion."
    }
    $fileStatus = 'IncompatibleAudioPlan'
    # Query the selected encoder once per started batch, after interactive input.
    # No trial encoding of user sources and no change to the startup/setup route.
    if ($null -eq $encoderCapabilities) { $encoderCapabilities = Get-AudioEncoderSampleRates -FfmpegPath $ffmpeg }
    if ($encoderCapabilities.Status -eq 'Cancelled') { Assert-AudioNotCancelled }
    $outputAudioPlan = Get-AudioOutputPlan -Media $media -BitrateKbps $BitrateKbps -SupportedSampleRates $encoderCapabilities.SampleRates
    if ($encoderCapabilities.Status -ne 'Success') {
        $outputAudioPlan.Status = 'Incompatible'; $outputAudioPlan.Code = 'EncoderCapabilitiesUnavailable'
        $outputAudioPlan.Reason = 'Cannot plan this selected encoder before encoding: ' + $encoderCapabilities.Error
        $encoderReleaseUnproved = $null -eq $encoderCapabilities.NativeResult -or -not $encoderCapabilities.NativeResult.ProcessReleased
    }
    if ($outputAudioPlan.Status -ne 'Success') { throw ($outputAudioPlan.Code + ': ' + $outputAudioPlan.Reason) }
    Write-Log ('Audio plan: ' + $outputAudioPlan.Reason)
    $fileStatus = 'Exception'
    $metadataPlan = Get-AudioMetadataPlan -Media $media -FallbackTitle $newBase -Artist $Artist -Album $Album
    $hasTitle = $metadataPlan.HasSourceTitle
    if ($hasTitle) {
        Write-Host "       [INFO] Existing title tag: $($media.Title)"
    }
    else {
        Write-Host "       [INFO] No title tag found; will set from sanitized filename."
    }

    # The shared plan preserves the source map and puts explicit overrides last.
    $metadataArgs = $metadataPlan.Arguments

    if (-not $hasTitle) {
        $title = $metadataPlan.Title
        Write-Host "       [INFO] Setting title tag: $title"
    }

    if (-not [string]::IsNullOrWhiteSpace($Artist)) {
        Write-Host "       [INFO] Setting artist tag: $Artist"
    }
    if (-not [string]::IsNullOrWhiteSpace($Album)) {
        Write-Host "       [INFO] Setting album tag: $Album"
    }

    # One output-scoped audio argument builder supplies both cover paths.
    if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
        Write-Host "       [INFO] Embedding cover: $CoverPath"
    }
    $ffArgs = @(New-AudioEncodeArguments -InputPath $file.FullName -Media $media -OutputPlan $outputAudioPlan -MetadataArguments $metadataArgs -CoverPath $CoverPath)

    Write-Host "       [DEBUG] ffmpeg encoding arguments (working path added by transaction):"
    Write-Host "              $ffmpeg " + ($ffArgs -join " ")

        $transaction = Invoke-AudioOutputTransaction -OutputPath $outPath -OutputRoot $outputRoot -SourcePath $file.FullName `
            -SourceDurationSeconds $media.DurationSeconds -BitrateKbps $BitrateKbps `
            -HasCover (-not [string]::IsNullOrWhiteSpace($CoverPath)) -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments $ffArgs `
            -ProgressCallback $fileProgressCallback -ProbeTimeoutSeconds $ProbeTimeoutSeconds -OutputPlan $outputAudioPlan
        $fileStatus = $transaction.Status
        $fileReason = $transaction.Error
        if ($fileStatus -eq 'Cancelled') {
            if ($transaction.CleanupError) {
                $cancelCleanupNote = "Working path retained: $($transaction.WorkingPath); $($transaction.CleanupError)"
                Write-Warning $cancelCleanupNote -ErrorAction Continue
            }
            Assert-AudioNotCancelled
        }
    }
    catch [OperationCanceledException] { throw }
    catch { $fileReason = $_.Exception.Message }

    # Commit the actual file outcome before optional diagnostics. A published
    # file stays successful even if its log write fails; the run then exits 1.
    if ($fileStatus -eq 'Success') { $ok++ } else { $failed++ }
    $currentOutcome = if ($fileStatus -eq 'Success') {
        "Validated output was published to '$outPath'"
    } else { "File '$($file.FullName)' failed ($fileStatus`: $fileReason)" }
    $fileWatch.Stop()
    $recordStatus = if ($fileStatus -eq 'Success') { 'Converted' } else { 'Failed' }
    Set-AudioManifestRecord -Record $manifest.Data.records[$activeRecordIndex] -Status $recordStatus -Code $fileStatus -Reason $fileReason `
        -SourcePath $file.FullName -OutputPath $outPath -Media $media -Transaction $transaction -ElapsedSeconds $fileWatch.Elapsed.TotalSeconds -OutputPlan $outputAudioPlan
    $activeRecordIndex = -1
    Save-AudioManifest -Checkpoint FileBoundary
    $displayOutcome = if ($fileStatus -eq 'Success') { 'Converted; validated output published' } else { "Failed: $fileStatus" }
    $filePercent = if ($fileStatus -eq 'Success') { 100 } else { -1 }
    Write-AudioProgress -Id 1 -ParentId 0 -Activity $file.Name -Status $displayOutcome -PercentComplete $filePercent -Completed
    Write-AudioBatchProgress -Detail $displayOutcome
    Write-FileNativeDiagnostics
    if ($encoderReleaseUnproved) {
        throw 'Encoder capability process release was not proved. Stopping this batch before any further native operation.'
    }
    if ($null -ne $transaction) {
        $conversion = $transaction.EncoderResult
        if ($null -ne $conversion -and $conversion.Stderr) { Write-Host $conversion.Stderr.TrimEnd() }
        if ($null -ne $conversion -and $conversion.StderrTruncated) { Write-Log 'FFmpeg diagnostics exceeded the retained limit.' 'WARN' }
    }
    if ($fileStatus -eq 'Success') {
        Write-Host "       [OK]   Converted successfully."
        Write-Log ("OK   : '{0}' -> '{1}'" -f $file.FullName, $outPath) 'OK'
    }
    else {
        Write-Warning "       [FAIL] $fileStatus`: $fileReason"
        Write-Log ("FAIL : '{0}' -> '{1}' ({2}: {3})" -f $file.FullName, $outPath, $fileStatus, (Get-AudioBoundedText -Value $fileReason)) 'FAIL'
    }
    if ($null -ne $transaction -and $transaction.CleanupError) {
        Write-Warning "       [WARN] Working path retained: $($transaction.WorkingPath); $($transaction.CleanupError)"
        Write-Log ("Working path retained: '{0}'; {1}" -f $transaction.WorkingPath, $transaction.CleanupError) 'WARN'
    }

    Write-Host ""
}

Assert-AudioNotCancelled
$currentOutcome = $null
$runStatus = if ($failed -gt 0) { 'CompletedWithFailures' } else { 'Completed' }
Write-Log ("Summary: total={0}, converted={1}, failed={2}" -f $total, $ok, $failed)
Write-Log ("Log file saved to: {0}" -f $logPath)
Write-Log ("Manifest saved to: {0}" -f $manifestPath)
Write-Log (Get-AudioResultSummary) 'RESULT'
$batchExitCode = if ($failed -gt 0) { 2 } else { 0 }
}
}
catch [OperationCanceledException] {
    $runStatus = 'Cancelled'; $batchExitCode = 130
    if ($manifest) { Set-ActiveAudioRecordCancelled }
    Write-Host '[CANCELLED] This run stopped. Completed outputs are preserved.'
    $cancelProcessNote = $null
    if ($null -ne $script:AudioCancellationContext -and $script:AudioCancellationContext.ActiveProcessId -ne 0) {
        $cancelProcessNote = "Owned native child exit was not established (process id $($script:AudioCancellationContext.ActiveProcessId)); no further termination or cleanup was attempted."
        Write-Warning $cancelProcessNote -ErrorAction Continue
    }
    if ($logPath) {
        try {
            if ($manifest) { Save-AudioManifest -Checkpoint Cancelled -Status Cancelled -ExitCode 130 }
        }
        catch {
            $diagnosticError = $_.Exception.Message
            Write-Warning "Cancellation manifest could not be written: $diagnosticError" -ErrorAction Continue
        }
        try {
            Write-FileNativeDiagnostics
            Write-Log 'Controlled cancellation requested; completed outputs preserved.' 'CANCELLED'
            if ($cancelCleanupNote) { Write-Log $cancelCleanupNote 'WARN' }
            if ($cancelProcessNote) { Write-Log $cancelProcessNote 'WARN' }
            Write-Log (Get-AudioResultSummary) 'RESULT'
        }
        catch {
            $diagnosticError = $_.Exception.Message
            Write-Warning "Cancellation diagnostic could not be logged: $diagnosticError" -ErrorAction Continue
        }
    }
}
catch {
    $rootCause = $_.Exception.Message
    $diagnosticError = $rootCause
    if ($null -ne $script:AudioCancellationContext -and (Test-AudioCancellation)) {
        $runStatus = 'Cancelled'; $batchExitCode = 130
        Set-ActiveAudioRecordCancelled
    }
    else {
        $runStatus = if (($ok + $failed) -eq 0) { 'FailedBeforeConversion' } else { 'Failed' }
        $batchExitCode = 1
    }
    $fatal = if ($currentOutcome) {
        "$currentOutcome, but its diagnostics could not be recorded in '$logPath'. The run stopped: $rootCause"
    } else { "The run stopped: $rootCause" }
    Write-Error "[FATAL] $fatal" -ErrorAction Continue
    # Keep the primary error on the console even when the same log is unavailable.
    if (-not $run) {
        if ($diagnosticsReady) {
            try {
                $failureCode = $diagnosticCode
                if ($diagnosticStage -eq 'ToolSelection' -and $toolDiagnosticContext.Code) { $failureCode = $toolDiagnosticContext.Code }
                $record = New-AudioDiagnosticRecord -ScriptDirectory $ScriptDir -Stage $diagnosticStage -Code $failureCode -Message $rootCause `
                    -ConfigPath $ConfigPath -Selection $toolInfo -Context $toolDiagnosticContext `
                    -Counts @{ total = $total; converted = $ok; failed = $failed; exit_code = $batchExitCode; status = $runStatus }
                $null = Write-AudioStartupFailure -Record $record -DryRun:$DryRun
            }
            catch { Write-Warning ('Startup diagnostics unavailable; original failure above is unchanged. ' + $_.Exception.Message) -ErrorAction Continue }
        }
        else { Write-Host '[DIAGNOSTIC] stage=Bootstrap; code=HelperMissing; restore the complete application package. Original failure is shown above.' }
    }
    if ($logPath) {
        try {
            Write-FileNativeDiagnostics
            if ($runStatus -eq 'Cancelled') { Write-Log 'Controlled cancellation requested; diagnostic failure did not change exit 130.' 'CANCELLED' }
            Write-Log (Get-AudioBoundedText -Value $fatal) 'FATAL'
            Write-Log (Get-AudioResultSummary) 'RESULT'
        }
        catch { Write-Warning "Fatal diagnostic could not be logged: $($_.Exception.Message)" -ErrorAction Continue }
    }
}
finally {
    if ($null -ne $script:AudioCancellationContext) {
        if (Test-AudioCancellation) {
            $lateCancellation = $runStatus -ne 'Cancelled'
            $runStatus = 'Cancelled'; $batchExitCode = 130
            Set-ActiveAudioRecordCancelled
            if ($lateCancellation -and $logPath) {
                try { Write-Log 'Controlled cancellation requested at the final run boundary; completed outputs preserved.' 'CANCELLED' }
                catch { $diagnosticError = $_.Exception.Message; Write-Warning "Cancellation diagnostic could not be logged: $diagnosticError" -ErrorAction Continue }
            }
        }
        $script:AudioCancellationContext.Dispose()
        $consoleError = $script:AudioCancellationContext.ConsoleCaptureError
        if ($consoleError -and $consoleError -cne $consoleCaptureNotice) {
            Write-Warning $consoleError -ErrorAction Continue
            if ($logPath) {
                try { Write-Log $consoleError 'WARN' }
                catch {
                    $diagnosticError = $_.Exception.Message
                    if ($runStatus -ne 'Cancelled') {
                        $runStatus = if (($ok + $failed) -eq 0) { 'FailedBeforeConversion' } else { 'Failed' }
                        $batchExitCode = 1
                    }
                    Write-Warning "Console diagnostic could not be logged: $diagnosticError" -ErrorAction Continue
                }
            }
        }
        $script:AudioCancellationContext = $null
    }
    if ($manifest) {
        try {
            # Required final human records precede a Completed JSON snapshot.
            # A final log failure therefore cannot leave a false full success.
            Write-Log (Get-AudioResultSummary) 'RESULT'
            Save-AudioManifest -Checkpoint Final -Status $runStatus -ExitCode $batchExitCode
        }
        catch {
            $diagnosticError = $_.Exception.Message
            if ($runStatus -ne 'Cancelled') {
                $runStatus = if (($ok + $failed) -eq 0) { 'FailedBeforeConversion' } else { 'Failed' }
                $batchExitCode = 1
            }
            Write-Error "[FATAL] $diagnosticError" -ErrorAction Continue
            if ($logPath) {
                try { Write-Log (Get-AudioBoundedText -Value $diagnosticError) 'FATAL'; Write-Log (Get-AudioResultSummary) 'RESULT' }
                catch { Write-Warning "Final diagnostic could not be logged: $($_.Exception.Message)" -ErrorAction Continue }
            }
            # One best-effort correction can persist the failed/cancelled outcome
            # after a transient final write error. A last good Running snapshot
            # remains visibly incomplete if required recording is unavailable.
            try { Save-AudioManifest -Checkpoint Final -Status $runStatus -ExitCode $batchExitCode }
            catch { Write-Warning "Final manifest correction could not be written: $($_.Exception.Message)" -ErrorAction Continue }
        }
        finally { Close-AudioRunManifest -Manifest $manifest }
    }
    if (-not $DryRun) {
        Write-AudioProgress -Id 1 -ParentId 0 -Activity 'Current file' -Status $runStatus -PercentComplete -1 -Completed
        Write-AudioBatchProgress -Detail $runStatus -Completed
    }
    $runWatch.Stop()
    Write-Host "============================================================"
    Write-Host "==== Summary ===="
    Write-Host ("[RESULT] " + (Get-AudioResultSummary))
    Write-Host "  Input folder : $InputFolder"
    # A setup failure can leave the exact reserved scope named in its error
    # before the reservation object returns. Do not imply that nothing exists.
    $actualOutput = if ($run) { $run.OutputRoot }
        elseif ($runStatus -eq 'Previewed') { "$outputRoot (provisional; not reserved)" }
        elseif ($DryRun) { '(not planned; preview made no reservation)' }
        else { '(not available; see error for any reserved scope)' }
    $actualLog = if ($logPath) { $logPath }
        elseif ($DryRun) { '(not created during preview)' }
        else { '(not available)' }
    Write-Host "  Output root  : $actualOutput"
    Write-Host "  Output base  : $outputBase"
    Write-Host "  Total files  : $total"
    Write-Host "  Converted    : $ok"
    Write-Host "  Failed       : $failed"
    Write-Host "  Log file     : $actualLog"
    $actualManifest = if ($manifestPath) { $manifestPath } elseif ($DryRun) { '(not created during preview)' } else { '(not available)' }
    Write-Host "  Manifest     : $actualManifest"
    Write-Host "  Exit code    : $batchExitCode"
    Write-Host "============================================================"
}
exit $batchExitCode
