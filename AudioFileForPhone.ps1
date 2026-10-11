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
            <MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS\
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
            <MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS\
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

NOTES
    - Input:
        - Only .mp3, .m4a, and .ogg files are processed (case-insensitive).
        - Search is recursive under the specified input folder.
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
    [string]$OutputParent
)

# --- Script path & dir, computed ONCE here, not inside functions ---
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

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
    $outputParentPath = Get-OutputParent -OutputParent $OutputParent
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputRoot = Join-Path $outputParentPath ("AudioForPhone_{0}kbps_{1}" -f $BitrateKbps, $timestamp)
    Assert-AudioOutputBoundary -InputFolder $InputFolder -OutputRoot $outputRoot
    if (Test-Path -LiteralPath $outputRoot -ErrorAction Stop) {
        throw "The planned output run root already exists; try again with a fresh run: '$outputRoot'."
    }
    Write-Host "[INFO] Scanning for audio files (.mp3/.m4a/.ogg) under: $InputFolder"
    $snapshot = Get-AudioInputSnapshot -InputFolder $InputFolder -OutputRoot $outputRoot
    foreach ($skip in $snapshot.Skipped) { Write-Warning ("{0}: {1}" -f $skip.Reason, $skip.Path) }
    $files = @($snapshot.Files)
    if ($files.Count -eq 0) { throw "No MP3/M4A/OGG files found under: $InputFolder" }
    $plans = @(Get-AudioBatchNamePlan -Files $files -InputFolder $InputFolder -OutputRoot $outputRoot -MaxBaseLength $MaxBaseLength)
    $ffmpeg = Get-ToolPath -ExeName 'ffmpeg.exe' -ScriptDirectory $ScriptDir
    $ffprobe = Get-ToolPath -ExeName 'ffprobe.exe' -ScriptDirectory $ScriptDir
    $toolInfo = Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe
    if ($PSBoundParameters.ContainsKey('CoverPath')) {
        $CoverPath = Get-ValidatedCoverPath -Path $CoverPath -FfmpegPath $ffmpeg
    }
    Test-OutputWritable -Path $outputParentPath
}
catch {
    Write-Error "[FATAL] Preflight failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}

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
                    Write-Error "[FATAL] $($_.Exception.Message)" -ErrorAction Continue
                    exit 1
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

# --- Output root + log setup ---
Write-Host "[INFO] Output root      : $outputRoot"

try {
    # Recheck after prompts. Exclusive concurrent reservation is implemented in T08.
    Assert-AudioOutputBoundary -InputFolder $InputFolder -OutputRoot $outputRoot
    if (Test-Path -LiteralPath $outputRoot -ErrorAction Stop) {
        throw "The planned output run root now exists: '$outputRoot'."
    }
    Write-Host "[DEBUG] Creating output root folder..."
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    Write-AudioOutputMarker -OutputRoot $outputRoot

    # --- Log file ---
    $logPath = Join-Path $outputRoot "AudioFileForPhone_log.txt"
    "==== AudioFileForPhone Log ====" | Out-File -LiteralPath $logPath -Encoding UTF8 -ErrorAction Stop
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
    Write-Error "[FATAL] Could not create output root or log '$outputRoot': $($_.Exception.Message)" -ErrorAction Continue
    exit 1
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
    Write-Error "[FATAL] Could not create output base '$outputBase': $($_.Exception.Message)" -ErrorAction Continue
    exit 1
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
    $file = $plan.SourceFile
    $index++
    $percent = [int](($index / $total) * 100)
    $status  = "{0} / {1}: {2}" -f $index, $total, $file.Name

    Write-Host "------------------------------------------------------------"
    Write-Log ("Processing file {0}/{1}: {2}" -f $index, $total, $file.FullName)

    Write-Progress -Activity ("Converting audio to {0}kbps MP3" -f $BitrateKbps) `
                   -Status $status `
                   -PercentComplete $percent

    $outDir = $plan.OutputDirectory
    $outPath = $plan.OutputPath
    $newBase = $plan.BaseName
    foreach ($warning in $plan.Warnings) { Write-Log ("{0}: {1}" -f $file.FullName, $warning) 'WARN' }
    if (Test-Path -LiteralPath $outPath -ErrorAction Stop) {
        $failed++
        Write-Log ("FAIL : Planned output already exists; refusing to overwrite '$outPath'.") 'FAIL'
        continue
    }

    if (-not (Test-Path -LiteralPath $outDir)) {
        Write-Log ("Creating output folder: {0}" -f $outDir) "DEBUG"
        [IO.Directory]::CreateDirectory($outDir) | Out-Null
    }

    Write-Log ("Sanitized base: '{0}' (from '{1}')" -f $newBase, $plan.OriginalBase) "DEBUG"

    Write-Host "       Source : $($file.FullName)"
    Write-Host "       Target : $outPath"
    Write-Log  ("Output file   : {0}" -f $outPath) "DEBUG"

    # A failed probe is a file failure, distinct from a valid missing title.
    Write-Host "       [DEBUG] Running ffprobe..."
    $media = Get-AudioMediaInfo -Path $file.FullName -FfprobePath $ffprobe
    if ($media.Status -ne 'Success') {
        $failed++
        Write-Log ("FAIL : '{0}' (probe {1}: {2})" -f $file.FullName, $media.Status, $media.Error) "FAIL"
        continue
    }
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
            "-n",
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
        ) + $metadataArgs + @($outPath)
    }
    else {
        $ffArgs = @(
            "-nostdin",
            "-n",
            "-i", $file.FullName,
            "-map", ("0:{0}" -f $media.StreamIndex),
            "-vn",
            "-acodec", "libmp3lame",
            "-b:a", ("{0}k" -f $BitrateKbps)
        ) + $metadataArgs + @($outPath)
    }

    Write-Host "       [DEBUG] ffmpeg command line:"
    Write-Host "              $ffmpeg " + ($ffArgs -join " ")

    try {
        $conversion = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments $ffArgs
        if ($conversion.Stderr) { Write-Host $conversion.Stderr.TrimEnd() }
        if ($conversion.StderrTruncated) { Write-Log 'FFmpeg diagnostics exceeded the retained limit.' 'WARN' }
        if ($conversion.Status -eq 'Completed' -and $conversion.ExitCode -eq 0 -and (Test-Path -LiteralPath $outPath)) {
            $ok++
            Write-Host "       [OK]   Converted successfully."
            Write-Log  ("OK   : '{0}' -> '{1}'" -f $file.FullName, $outPath) "OK"
        }
        else {
            $failed++
            Write-Warning "       [FAIL] ffmpeg status: $($conversion.Status), exit code: $($conversion.ExitCode) (or output file missing)"
            Write-Log ("FAIL : '{0}' (ffmpeg {1}, exit {2}: {3}; {4})" -f $file.FullName, $conversion.Status, $conversion.ExitCode, $conversion.Error, $conversion.Stderr) "FAIL"
        }
    }
    catch {
        $failed++
        Write-Warning "       [FAIL] Error converting file: $_"
        Write-Log ("FAIL : '{0}' (exception: {1})" -f $file.FullName, $_) "FAIL"
    }

    Write-Host ""
}

Write-Progress -Activity "Converting MP3s" -Completed

Write-Host "============================================================"
Write-Host "==== Summary ===="
Write-Host "  Input folder : $InputFolder"
Write-Host "  Output base  : $outputBase"
Write-Host "  Total files  : $total"
Write-Host "  Converted    : $ok"
Write-Host "  Failed       : $failed"
Write-Host "  Log file     : $logPath"
Write-Host "============================================================"

Write-Log ("Summary: total={0}, converted={1}, failed={2}" -f $total, $ok, $failed)
Write-Log ("Log file saved to: {0}" -f $logPath)
