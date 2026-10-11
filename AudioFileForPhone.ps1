<#
AudioFileForPhone.ps1
Minimal Win11 audio converter + filename sanitizer for personal phone listening

Author: Janne Vuorela
Target OS: Windows 11
Dependencies: PowerShell 5.1+ or PowerShell 7+, ffmpeg.exe, ffprobe.exe

SYNOPSIS
    One-preset, no-frills audio converter intended for my own workflow:
    taking a folder of MP3, M4A, or OGG podcasts/audiobooks, re-encoding them to a
    phone-friendly bitrate, and outputting files with Android-safe,
    shortened filenames that still keep the date visible.

WHAT THIS IS (AND ISN’T)
    - Personal, purpose-built tool for my specific use case.
      It trades advanced audio features for predictability, robustness,
      and a simple console experience.
    - Used via a .bat wrapper (drag & drop a folder) or directly from PowerShell.
      Optional TUI prompts when launched in interactive mode.
    - Focused on:
        - Making big podcast archives small enough for phone storage.
        - Fixing overly long, problematic filenames for Android / MTP.
        - Mirroring input folder structure into a clean output tree.
        - Optional, batch-level metadata helpers (cover + artist/album).
    - Not focused on:
        - Fancy DSP, noise reduction, or EQ.
        - Additional output formats (output is always MP3).
        - Per-track tagging workflows or library management.

FEATURES
    - Folder-based workflow:
        - Input:  a folder containing .mp3, .m4a, and .ogg files, recursively processed.
        - Output: a new root folder per run:
            <MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS[_N]\
              <InputFolderName>\subfolders...
    - One-preset audio conversion:
        - Re-encodes all input .mp3, .m4a, and .ogg files using ffmpeg.
        - Supports Ogg Vorbis and Ogg Opus audio in .ogg files.
        - Default bitrate: 64 kbps CBR, configurable via -BitrateKbps.
        - Drops any video streams, audio-only output.
    - Filename sanitization + shortening for Android:
        - Tries to keep a leading date if present:
            "YYYY-MM-DD - Rest of name"
        - An absent or impossible leading date uses the file’s LastWriteTime.
          Impossible date prefixes remain part of the title input.
        - Removes non-safe characters, keeps letters, digits, spaces, - and _.
        - Collapses whitespace and trims the result.
        - Truncates the base name to a configurable max length
          (default: 60 UTF-16 units, including any collision suffix).
        - Normalizes titles to NFC; shortening keeps complete Unicode scalars.
        - Automatically adds " (2)", " (3)", etc. to avoid collisions.
    - Subfolder structure preserved:
        - Relative directory layout under the input folder is mirrored
          under the output base.
        - Only filenames are sanitized/shortened, not folder names.
    - Basic metadata handling:
        - Uses ffprobe to check for an existing title tag.
        - If no title is present, sets the title to the sanitized base name.
        - Copies source metadata (including Ogg audio-stream tags), forces ID3v2.3.
    - Optional batch metadata (interactive or parameter-driven):
        - Can embed an album cover image (.jpg/.png) into every output MP3.
        - Can set Artist and Album tags for all output files.
        - In interactive mode, cover is selected via file picker.
        - Warns (and logs) if the chosen cover is unusually large
          (size and/or dimensions), to avoid bloating every output file.
    - Per-run log file:
        - Stored in the run’s output root:
            AudioFileForPhone_log.txt
        - Logs:
            - Start time, input folder, output root, bitrate, max name length.
            - Selected metadata options (cover/artist/album) when used.
            - Each file processed, input and output paths.
            - Sanitized base name chosen for each file.
            - Conversion success/failure details and summary.

MY INTENDED USAGE
    - I drop a podcast/audiobook folder onto AudioFileForPhone.bat.
    - The script:
        - Walks the folder tree, finds all .mp3, .m4a, and .ogg files.
        - Converts them to 64 kbps CBR.
        - Writes them into a fresh AudioForPhone_* output tree in my Music folder.
        - Shortens and sanitizes filenames so Android accepts them.
        - Optionally embeds cover + sets artist/album tags for AIMP/players.
    - After the run:
        - I copy the AudioForPhone_*\<InputFolderName>\ folder to my phone.
        - I keep the log file around if I suspect something failed mid-run.

SETUP
    1) Place these files together in a folder of your choice:
         - AudioFileForPhone.ps1
         - AudioFileForPhone.Helpers.ps1
         - AudioFileForPhone.bat     (wrapper to allow drag & drop)
         - ffmpeg.exe
         - ffprobe.exe
    2) Optional:
         - Add the folder to PATH if you want to call the script from anywhere.
    3) Ensure the machine has:
         - Permission to read the input folder you drag onto the .bat.
         - Permission to create folders and files in the current user's Music folder.
    4) ffmpeg/ffprobe resolution:
         - The script first looks for ffmpeg.exe / ffprobe.exe in the script folder.
         - If not found there, it searches PATH.
         - If still not found, it aborts with a fatal error.

USAGE
    A) Drag & drop (primary usage)
        - Drag a folder containing .mp3, .m4a, or .ogg files onto:
            AudioFileForPhone.bat
        - The .bat calls:
            AudioFileForPhone.ps1 -InputFolder "<that folder>" -Interactive
        - Output:
            <MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS[_N]\
                <InputFolderName>\...
            plus:
                AudioFileForPhone_log.txt    (in the AudioForPhone_* root)
    B) Direct PowerShell (default options)
        - From a PowerShell prompt:
            .\AudioFileForPhone.ps1 -InputFolder "C:\MyPodcasts"
        - Uses:
            -BitrateKbps     64
            -MaxBaseLength   60
    C) Direct PowerShell (custom options)
        - Example: slightly higher bitrate, tighter filename length:
            .\AudioFileForPhone.ps1
                -InputFolder   "C:\MyPodcasts"
                -BitrateKbps   96
                -MaxBaseLength 50
    D) Direct PowerShell (with batch metadata)
        - Provide cover + artist/album without interactive prompts:
            .\AudioFileForPhone.ps1
                -InputFolder "C:\MyPodcasts"
                -CoverPath  "C:\Images\cover.jpg"
                -Artist     "PowerShell After Dark"
                -Album      "PSConfEU 2024"
    E) Preview source-to-output names without creating files
        - .\AudioFileForPhone.ps1 -InputFolder "C:\MyPodcasts" -DryRun
        - Uses the conversion discovery and naming planner. The output root is
          provisional; durations, writability, tools, media and cover validation
          are unverified. -Interactive is ignored during preview.

NOTES
    - Input:
        - Only .mp3, .m4a, and .ogg files are processed (case-insensitive).
        - Search is recursive under the specified input folder.
        - -DryRun previews mappings without creating output, logs or audio,
          running tools, validating a cover or showing interactive prompts.
    - Output:
        - Uses the current user's Windows Music folder, including moved locations.
        - Optional -OutputParent selects another filesystem directory; a missing
          directory is created. Relative paths use the current PowerShell location.
        - All outputs are MP3, even if input had different internal encoding.
        - Names follow the pattern:
            "YYYY-MM-DD - Sanitized title.mp3"
          truncated to MaxBaseLength characters for the base name.
    - Dates:
        - A real leading "YYYY-MM-DD" calendar date is kept.
        - Otherwise, the file’s LastWriteTime is used as the date for naming.
    - Metadata:
        - Existing title tags are preserved when present.
        - When missing, the title is set to the sanitized base name.
        - Artist/Album can be set for all outputs when provided.
        - Album cover can be embedded when a CoverPath is provided.
        - ID3v2.3 is enforced for broader compatibility.
    - Logging:
        - A single log file is created per run in the AudioForPhone_* root.
        - All important operations and failures are logged, including
          cover diagnostics warnings when a cover is used.
    - Results:
        - -DryRun exits 0 with Previewed when planning succeeds; no conversions
          are counted and the displayed output root is not reserved.
        - Exit 0: all supported snapshot files converted successfully.
        - Exit 2: batch completed with one or more per-file failures; other
          independent files continue. Exit 1: preflight, empty scan or fatal error.
        - Summary distinguishes processed, converted, failed, not processed,
          scan exclusions and unsupported files, with elapsed time and locations.
        - Parameter-binding failures and forced host termination can use host
          codes. Controlled cancellation (130) is deferred to T11.

LIMITATIONS
    - Input extensions limited to .mp3, .m4a, and .ogg:
        - Other extensions (e.g. .flac, .wav, .opus) are not scanned.
    - No loudness normalization or noise reduction:
        - The script only re-encodes bitrate and handles naming/metadata.
    - Single naming scheme:
        - Date-first, then sanitized title, truncated to MaxBaseLength.
        - No alternative patterns.
    - Long path edge cases:
        - Complete destination/working paths must be below 260 UTF-16 units;
          created directories must be below 248. Unsupported preserved folder
          names or paths fail preflight with guidance; folders are not renamed.
        - In practice, keeping the input folder path short (e.g. C:\P)
          avoids most issues.

TROUBLESHOOTING
    - Script window closes immediately when using the .bat:
        - Run the .bat from an existing cmd window to see error output.
        - Check PowerShell ExecutionPolicy or corporate restrictions.
    - "Could not find ffmpeg.exe / ffprobe.exe":
        - Place ffmpeg.exe and ffprobe.exe next to AudioFileForPhone.ps1, or
          install ffmpeg and add it to PATH.
    - "Could not resolve input folder":
        - The path passed from the .bat may contain quotes or be invalid.
        - Ensure you are dragging a real folder, not a shortcut.
    - Cover picker does not open:
        - Ensure the .bat launches PowerShell with -Sta (the provided wrapper does).
        - If running manually, use:
            pwsh -Sta -File .\AudioFileForPhone.ps1 -InputFolder "C:\MyPodcasts" -Interactive
    - Long path / ItemNotFound errors:
        - Move or rename the input folder to a shorter path (e.g. C:\P)
          and run the tool again from there.
    - Files appear missing on the phone:
        - Check:
            - That all inputs were .mp3, .m4a, or .ogg and were actually converted.
            - The log file for per-file errors.
            - The output tree under AudioForPhone_* for expected counts.

LICENSE / WARRANTY
    - Personal tool, provided as-is, without warranty. Use at your own risk.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFolder,

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
    [switch]$DryRun
)

# --- Script path & dir, computed ONCE here, not inside functions ---
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

$ErrorActionPreference = 'Stop'
$runWatch = [Diagnostics.Stopwatch]::StartNew()
$run = $null; $logPath = $null; $outputBase = $null
$total = 0; $ok = 0; $failed = 0; $scanExcluded = 0; $unsupported = 0
$batchExitCode = 1; $runStatus = 'FailedBeforeConversion'; $currentOutcome = $null
$cancelCleanupNote = $null
$consoleCaptureNotice = ''
$script:AudioCancellationContext = $null
$script:AudioProgressDisplayEnabled = $true

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
Write-Host "==== AudioFileForPhone ===="
Write-Host "[INFO] Script path : $ScriptPath"
Write-Host "[INFO] Script dir  : $ScriptDir"
Write-Host "[INFO] Raw input   : '$InputFolder'"
Write-Host "[INFO] Bitrate     : ${BitrateKbps}kbps"
Write-Host "[INFO] Max name    : $MaxBaseLength chars"
Write-Host "[INFO] Interactive : $Interactive"
Write-Host ""

# --- Preflight: reject prerequisites before optional prompts or run creation ---
try {
    . (Join-Path $ScriptDir 'AudioFileForPhone.Helpers.ps1')
    Assert-AudioParameters -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength
    $InputFolder = Get-InputDirectory -InputFolder $InputFolder
    if (-not [string]::IsNullOrWhiteSpace($OutputParent)) { Assert-AudioOutputParentSpelling -Path $OutputParent }
    $outputParentPath = Get-OutputParent -OutputParent $OutputParent
    $timestamp = [datetime]::Now.ToString('yyyyMMdd_HHmmss', [Globalization.CultureInfo]::InvariantCulture)
    $provisionalRun = Get-AudioAvailableRunCandidate -OutputParent $outputParentPath -InputFolder $InputFolder -BitrateKbps $BitrateKbps -Timestamp $timestamp
    $outputRoot = $provisionalRun.OutputRoot
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
        $ffmpeg = Get-ToolPath -ExeName 'ffmpeg.exe' -ScriptDirectory $ScriptDir
        $ffprobe = Get-ToolPath -ExeName 'ffprobe.exe' -ScriptDirectory $ScriptDir
        $toolInfo = Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe
        if ($PSBoundParameters.ContainsKey('CoverPath')) {
            $CoverPath = Get-ValidatedCoverPath -Path $CoverPath -FfmpegPath $ffmpeg
        }
        Test-OutputWritable -Path $outputParentPath
    }
}
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

function Read-YesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [bool]$DefaultYes = $false
    )

    $defaultHint = if ($DefaultYes) { "Y/n" } else { "y/N" }

    while ($true) {
        $ans = Read-Host "$Prompt ($defaultHint)"
        if ([string]::IsNullOrWhiteSpace($ans)) { return $DefaultYes }

        switch ($ans.Trim().ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default { Write-Host "[WARN] Please answer y or n." }
        }
    }
}

function Select-CoverFileDialog {
    param(
        [string]$Title = "Select album cover image",
        [string]$Filter = "Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png|All Files (*.*)|*.*"
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Title = $Title
        $ofd.Filter = $Filter
        $ofd.Multiselect = $false

        $result = $ofd.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return $ofd.FileName
        }
        return $null
    }
    catch {
        Write-Warning "[WARN] Could not open file picker. (Tip: wrapper should launch PowerShell in STA mode.)"
        Write-Warning "[WARN] Error: $_"
        return $null
    }
}

# --- Optional: interactive metadata step, only if requested ---
if ($Interactive) {
    Write-Host "==== Optional metadata step ===="
    Write-Host "This run can optionally embed an album cover and set Artist/Album tags for all output files."
    Write-Host ""

    # Cover
    if ([string]::IsNullOrWhiteSpace($CoverPath)) {
        $doCover = Read-YesNo -Prompt "Add album cover to output MP3 metadata?" -DefaultYes:$false
        if ($doCover) {
            $picked = Select-CoverFileDialog
            if ($picked) {
                try { $CoverPath = Get-ValidatedCoverPath -Path $picked -FfmpegPath $ffmpeg }
                catch {
                    throw "Selected cover failed validation: $($_.Exception.Message)"
                }
                Write-Host "[INFO] Cover selected: $CoverPath"

                $coverDiag = Get-CoverDiagnostics -Path $CoverPath
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
    if ([string]::IsNullOrWhiteSpace($Artist)) {
        $doArtist = Read-YesNo -Prompt "Set Artist tag manually for all output files?" -DefaultYes:$false
        if ($doArtist) {
            $Artist = (Read-Host "Artist").Trim()
            if ([string]::IsNullOrWhiteSpace($Artist)) { $Artist = $null }
        }
    }

    # Album
    if ([string]::IsNullOrWhiteSpace($Album)) {
        $doAlbum = Read-YesNo -Prompt "Set Album tag manually for all output files?" -DefaultYes:$false
        if ($doAlbum) {
            $Album = (Read-Host "Album").Trim()
            if ([string]::IsNullOrWhiteSpace($Album)) { $Album = $null }
        }
    }

    Write-Host ""
}

# Console input belongs to this invocation only after interactive prompts finish.
# Native calls share this context; redirected/unsupported hosts retain their own
# interruption behavior and cannot promise a controlled exit code.
$script:AudioCancellationContext = New-AudioCancellationContext -CaptureConsole
$consoleCaptureNotice = $script:AudioCancellationContext.ConsoleCaptureError
Assert-AudioNotCancelled

# --- Output root + log setup ---
try {
    $run = New-AudioRunReservation -OutputParent $outputParentPath -InputFolder $InputFolder -Files $files -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength -Timestamp $timestamp -StartCounter $provisionalRun.Counter
    $outputRoot = $run.OutputRoot
    $plans = @($run.Plans)
    $logPath = $run.LogPath
    Write-Host "[INFO] Output root      : $outputRoot"

    # --- Log file ---
    "==== AudioFileForPhone Log ====" | Add-Content -LiteralPath $logPath -ErrorAction Stop
    "Start time    : $(Get-Date)"     | Add-Content -LiteralPath $logPath -ErrorAction Stop
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
    ""                              | Add-Content -LiteralPath $logPath -ErrorAction Stop
}
catch {
    throw "Could not create output root or log '$outputRoot': $($_.Exception.Message)"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "[{0}] {1}" -f $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $logPath -ErrorAction Stop -Value $line
}

if ($script:AudioCancellationContext.ConsoleCaptureEnabled) {
    Write-Log 'Press Ctrl+C during conversion to cancel this run safely.'
}
else {
    Write-Log ("Controlled console Ctrl+C is unavailable in this host: {0}" -f $script:AudioCancellationContext.ConsoleCaptureError) 'WARN'
}

foreach ($skip in $snapshot.Skipped) { Write-Log ("{0}: {1}" -f $skip.Reason, $skip.Path) 'WARN' }

# --- Log diagnostics for the cover already validated before run creation ---
if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
    $coverDiag = Get-CoverDiagnostics -Path $CoverPath

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

    Write-Host "------------------------------------------------------------"
    Write-Log ("Processing file {0}/{1}: {2}" -f $index, $total, $file.FullName)

    Write-AudioBatchProgress -Detail ("Inspecting file {0} / {1}: {2}" -f $index, $total, $file.Name)
    Write-AudioProgress -Id 1 -ParentId 0 -Activity $file.Name -Status 'Inspecting source; duration unknown' -PercentComplete -1
    $fileProgressCallback = {
        param($progress)
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
    $media = Get-AudioMediaInfo -Path $file.FullName -FfprobePath $ffprobe
    if ($media.Status -eq 'Cancelled') { Assert-AudioNotCancelled }
    if ($media.Status -ne 'Success') {
        throw "Source probe failed ($($media.Status)): $($media.Error)"
    }
    $fileStatus = 'InvalidSourceDuration'
    if ($media.DurationStatus -ne 'Valid') {
        throw "Source duration $($media.DurationStatus); a finite positive source duration is required before conversion."
    }
    $fileStatus = 'Exception'
    $hasTitle = $media.TitleStatus -eq 'Present'
    $metadataSource = $media.MetadataSource
    if ($hasTitle) {
        Write-Host "       [INFO] Existing title tag: $($media.Title)"
    }
    else {
        Write-Host "       [INFO] No title tag found; will set from sanitized filename."
    }

    # Build metadata args
    $metadataArgs = @("-map_metadata",$metadataSource,"-id3v2_version","3")

    if (-not $hasTitle) {
        $title = $newBase
        $metadataArgs += @("-metadata","title=$title")
        Write-Host "       [INFO] Setting title tag: $title"
    }

    if (-not [string]::IsNullOrWhiteSpace($Artist)) {
        $metadataArgs += @("-metadata","artist=$Artist")
        Write-Host "       [INFO] Setting artist tag: $Artist"
    }
    if (-not [string]::IsNullOrWhiteSpace($Album)) {
        $metadataArgs += @("-metadata","album=$Album")
        Write-Host "       [INFO] Setting album tag: $Album"
    }

    # ffmpeg re-encode
    if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
        Write-Host "       [INFO] Embedding cover: $CoverPath"

        $ffArgs = @(
            "-nostdin",
            "-i", $file.FullName,
            "-i", $CoverPath,
            "-map", ("0:{0}" -f $media.StreamIndex),
            "-c:a", "libmp3lame",
            "-b:a", ("{0}k" -f $BitrateKbps),
            "-map", "1:0",
            "-c:v", "mjpeg",
            "-disposition:v", "attached_pic",
            "-metadata:s:v", "title=Album cover",
            "-metadata:s:v", "comment=Cover (front)"
        ) + $metadataArgs
    }
    else {
        $ffArgs = @(
            "-nostdin",
            "-i", $file.FullName,
            "-map", ("0:{0}" -f $media.StreamIndex),
            "-vn",
            "-acodec", "libmp3lame",
            "-b:a", ("{0}k" -f $BitrateKbps)
        ) + $metadataArgs
    }

    Write-Host "       [DEBUG] ffmpeg encoding arguments (working path added by transaction):"
    Write-Host "              $ffmpeg " + ($ffArgs -join " ")

        $transaction = Invoke-AudioOutputTransaction -OutputPath $outPath -OutputRoot $outputRoot -SourcePath $file.FullName `
            -SourceDurationSeconds $media.DurationSeconds -BitrateKbps $BitrateKbps `
            -HasCover (-not [string]::IsNullOrWhiteSpace($CoverPath)) -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments $ffArgs `
            -ProgressCallback $fileProgressCallback
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
    $displayOutcome = if ($fileStatus -eq 'Success') { 'Converted; validated output published' } else { "Failed: $fileStatus" }
    $filePercent = if ($fileStatus -eq 'Success') { 100 } else { -1 }
    Write-AudioProgress -Id 1 -ParentId 0 -Activity $file.Name -Status $displayOutcome -PercentComplete $filePercent -Completed
    Write-AudioBatchProgress -Detail $displayOutcome
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
        Write-Log ("FAIL : '{0}' -> '{1}' ({2}: {3})" -f $file.FullName, $outPath, $fileStatus, $fileReason) 'FAIL'
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
Write-Log (Get-AudioResultSummary) 'RESULT'
$batchExitCode = if ($failed -gt 0) { 2 } else { 0 }
}
}
catch [OperationCanceledException] {
    $runStatus = 'Cancelled'; $batchExitCode = 130
    Write-Host '[CANCELLED] This run stopped. Completed outputs are preserved.'
    $cancelProcessNote = $null
    if ($null -ne $script:AudioCancellationContext -and $script:AudioCancellationContext.ActiveProcessId -ne 0) {
        $cancelProcessNote = "Owned native child exit was not established (process id $($script:AudioCancellationContext.ActiveProcessId)); no further termination or cleanup was attempted."
        Write-Warning $cancelProcessNote -ErrorAction Continue
    }
    if ($logPath) {
        try {
            Write-Log 'Controlled cancellation requested; completed outputs preserved.' 'CANCELLED'
            if ($cancelCleanupNote) { Write-Log $cancelCleanupNote 'WARN' }
            if ($cancelProcessNote) { Write-Log $cancelProcessNote 'WARN' }
            Write-Log (Get-AudioResultSummary) 'RESULT'
        }
        catch { Write-Warning "Cancellation diagnostic could not be logged: $($_.Exception.Message)" -ErrorAction Continue }
    }
}
catch {
    $rootCause = $_.Exception.Message
    $runStatus = if (($ok + $failed) -eq 0) { 'FailedBeforeConversion' } else { 'Failed' }
    $batchExitCode = 1
    $fatal = if ($currentOutcome) {
        "$currentOutcome, but its diagnostics could not be recorded in '$logPath'. The run stopped: $rootCause"
    } else { "The run stopped: $rootCause" }
    Write-Error "[FATAL] $fatal" -ErrorAction Continue
    # Keep the primary error on the console even when the same log is unavailable.
    if ($logPath) {
        try { Write-Log $fatal 'FATAL' }
        catch { Write-Warning "Fatal diagnostic could not be logged: $($_.Exception.Message)" -ErrorAction Continue }
    }
}
finally {
    if ($null -ne $script:AudioCancellationContext) {
        $script:AudioCancellationContext.Dispose()
        $consoleError = $script:AudioCancellationContext.ConsoleCaptureError
        if ($consoleError -and $consoleError -cne $consoleCaptureNotice) {
            Write-Warning $consoleError -ErrorAction Continue
            if ($logPath) {
                try { Write-Log $consoleError 'WARN' }
                catch { Write-Warning "Console diagnostic could not be logged: $($_.Exception.Message)" -ErrorAction Continue }
            }
        }
        $script:AudioCancellationContext = $null
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
    Write-Host "  Exit code    : $batchExitCode"
    Write-Host "============================================================"
}
exit $batchExitCode
