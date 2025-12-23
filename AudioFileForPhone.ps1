<#
AudioFileForPhone.ps1
Minimal Win11 audio converter + filename sanitizer for personal phone listening

Author: Janne Vuorela
Target OS: Windows 11
Dependencies: PowerShell 5.1+ or PowerShell 7+, ffmpeg.exe, ffprobe.exe

SYNOPSIS
    One-preset, no-frills audio converter intended for my own workflow:
    taking a folder of MP3 podcasts/audiobooks, re-encoding them to a
    phone-friendly bitrate, and outputting files with Android-safe,
    shortened filenames that still keep the date visible.

WHAT THIS IS (AND ISN’T)
    - Personal, purpose-built tool for my specific use case.
      It trades advanced audio features for predictability, robustness,
      and a simple console experience.
    - Used via a .bat wrapper (drag & drop a folder) or directly from PowerShell.
      No GUI, just verbose console + log output.
    - Focused on:
        - Making big podcast archives small enough for phone storage.
        - Fixing overly long, problematic filenames for Android / MTP.
        - Mirroring input folder structure into a clean output tree.
    - Not focused on:
        - Fancy DSP, noise reduction, or EQ.
        - Multi-format support (input is MP3, output is MP3).
        - Tag editing beyond a simple, safe title when needed.

FEATURES
    - Folder-based workflow:
        - Input:  a folder containing .mp3 files, recursively processed.
        - Output: a new root folder per run:
            <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS\
              <InputFolderName>\subfolders...
    - One-preset audio conversion:
        - Re-encodes all input .mp3 files using ffmpeg.
        - Default bitrate: 64 kbps CBR, configurable via -BitrateKbps.
        - Drops any video streams, audio-only output.
    - Filename sanitization + shortening for Android:
        - Tries to keep a leading date if present:
            "YYYY-MM-DD - Rest of name"
        - If no leading date is found, uses the file’s LastWriteTime.
        - Removes non-safe characters, keeps letters, digits, spaces, - and _.
        - Collapses whitespace and trims the result.
        - Truncates the base name to a configurable max length
          (default: 60 characters) to avoid long-path / phone issues.
        - Automatically adds " (2)", " (3)", etc. to avoid collisions.
    - Subfolder structure preserved:
        - Relative directory layout under the input folder is mirrored
          under the output base.
        - Only filenames are sanitized/shortened, not folder names.
    - Basic metadata handling:
        - Uses ffprobe to check for an existing title tag.
        - If no title is present, sets the title to the sanitized base name.
        - Copies all other metadata from source, forces ID3v2.3 for compatibility.
    - Per-run log file:
        - Stored in the run’s output root:
            AudioFileForPhone_log.txt
        - Logs:
            - Start time, input folder, output root, bitrate, max name length.
            - Each file processed, input and output paths.
            - Sanitized base name chosen for each file.
            - Conversion success/failure details and summary.

MY INTENDED USAGE
    - I drop a podcast/audiobook folder onto AudioFileForPhone.bat.
    - The script:
        - Walks the folder tree, finds all .mp3 files.
        - Converts them to 64 kbps CBR.
        - Writes them into a fresh AudioForPhone_* output tree.
        - Shortens and sanitizes filenames so Android accepts them.
    - After the run:
        - I copy the AudioForPhone_*\<InputFolderName>\ folder to my phone.
        - I keep the log file around if I suspect something failed mid-run.

SETUP
    1) Place these files together in a folder of your choice:
         - AudioFileForPhone.ps1
         - AudioFileForPhone.bat     (wrapper to allow drag & drop)
         - ffmpeg.exe
         - ffprobe.exe
    2) Optional:
         - Add the folder to PATH if you want to call the script from anywhere.
    3) Ensure the machine has:
         - Permission to read the input folder you drag onto the .bat.
         - Permission to create folders and files next to the script.
    4) ffmpeg/ffprobe resolution:
         - The script first looks for ffmpeg.exe / ffprobe.exe in the script folder.
         - If not found there, it searches PATH.
         - If still not found, it aborts with a fatal error.

USAGE
    A) Drag & drop (primary usage)
        - Drag a folder containing .mp3 files onto:
            AudioFileForPhone.bat
        - The .bat calls:
            AudioFileForPhone.ps1 -InputFolder "<that folder>"
        - Output:
            <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS\
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

NOTES
    - Input:
        - Only .mp3 files are processed.
        - Search is recursive under the specified input folder.
    - Output:
        - All outputs are MP3, even if input had different internal encoding.
        - Names follow the pattern:
            "YYYY-MM-DD - Sanitized title.mp3"
          truncated to MaxBaseLength characters for the base name.
    - Dates:
        - If the original filename starts with "YYYY-MM-DD", that date is kept.
        - Otherwise, the file’s LastWriteTime is used as the date for naming.
    - Metadata:
        - Existing title tags are preserved when present.
        - When missing, the title is set to the sanitized base name.
        - ID3v2.3 is enforced for broader compatibility.
    - Logging:
        - A single log file is created per run in the AudioForPhone_* root.
        - All important operations and failures are logged.

LIMITATIONS
    - Input format limited to MP3:
        - Other audio formats (FLAC, M4A, etc.) are not handled.
    - No loudness normalization or noise reduction:
        - The script only re-encodes bitrate and handles naming/metadata.
    - Single naming scheme:
        - Date-first, then sanitized title, truncated to MaxBaseLength.
        - No alternative patterns.
    - Long path edge cases:
        - Extremely deep input folder paths combined with long names
          may still hit Windows path length limits.
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
    - Long path / ItemNotFound errors:
        - Move or rename the input folder to a shorter path (e.g. C:\P)
          and run the tool again from there.
    - Files appear missing on the phone:
        - Check:
            - That all inputs were .mp3 and were actually converted.
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
    [int]$MaxBaseLength = 60
)

# --- Script path & dir ---
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath

Write-Host "==== AudioFileForPhone ===="
Write-Host "[INFO] Script path : $ScriptPath"
Write-Host "[INFO] Script dir  : $ScriptDir"
Write-Host "[INFO] Raw input   : '$InputFolder'"
Write-Host "[INFO] Bitrate     : ${BitrateKbps}kbps"
Write-Host "[INFO] Max name    : $MaxBaseLength chars"
Write-Host ""

# --- Basic sanity check on param ---
if ([string]::IsNullOrWhiteSpace($InputFolder)) {
    Write-Error "[FATAL] InputFolder parameter is null or empty. This usually means the .bat did not pass the path correctly."
    exit 1
}

# --- Helper: find ffmpeg / ffprobe either next to script or in PATH ---
function Get-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExeName
    )

    # Use the script directory 
    $localPath = Join-Path $ScriptDir $ExeName
    Write-Host "[DEBUG] Checking for $ExeName next to script: $localPath"
    if (Test-Path $localPath) {
        Write-Host "[INFO] Using $ExeName from script folder."
        return $localPath
    }

    Write-Host "[DEBUG] Searching for $ExeName in PATH..."
    foreach ($p in ($env:PATH -split ';' | Where-Object { $_ })) {
        $candidate = Join-Path $p $ExeName
        if (Test-Path $candidate) {
            Write-Host "[INFO] Found $ExeName in PATH: $candidate"
            return $candidate
        }
    }

    throw "[FATAL] Could not find $ExeName. Put it next to this script or add it to PATH."
}

# --- Locate ffmpeg / ffprobe ---
try {
    $ffmpeg  = Get-ToolPath -ExeName "ffmpeg.exe"
    $ffprobe = Get-ToolPath -ExeName "ffprobe.exe"
}
catch {
    Write-Error $_
    exit 1
}

# --- Normalise and validate input folder ---
try {
    Write-Host "[DEBUG] Running Resolve-Path on: '$InputFolder'"
    $resolvedInput = Resolve-Path -LiteralPath $InputFolder -ErrorAction Stop
    $InputFolder   = $resolvedInput.Path
    Write-Host "[INFO] Resolved input folder: '$InputFolder'"
}
catch {
    Write-Error "[FATAL] Could not resolve input folder '$InputFolder': $_"
    exit 1
}

$InputFolder = $InputFolder.TrimEnd('\','/')

# --- Output root + log setup ---
$timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$outputRoot = Join-Path $ScriptDir ("AudioForPhone_{0}kbps_{1}" -f $BitrateKbps, $timestamp)

Write-Host "[INFO] Output root      : $outputRoot"

if (-not (Test-Path $outputRoot)) {
    Write-Host "[DEBUG] Creating output root folder..."
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
}

# --- Log file ---
$logPath = Join-Path $outputRoot "AudioFileForPhone_log.txt"
"==== AudioFileForPhone Log ====" | Out-File -FilePath $logPath -Encoding UTF8
"Start time    : $(Get-Date)"    | Add-Content -Path $logPath
"Input folder  : $InputFolder"   | Add-Content -Path $logPath
"Output root   : $outputRoot"    | Add-Content -Path $logPath
"Bitrate (kbps): $BitrateKbps"   | Add-Content -Path $logPath
"Max base len  : $MaxBaseLength" | Add-Content -Path $logPath
""                                  | Add-Content -Path $logPath

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "[{0}] {1}" -f $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

# --- Output base ---
$inputLeaf  = Split-Path $InputFolder -Leaf
$outputBase = Join-Path $outputRoot $inputLeaf

Write-Log ("Output base      : {0}" -f $outputBase)

New-Item -ItemType Directory -Path $outputBase -Force | Out-Null

Write-Host ""
Write-Log "Scanning for MP3 files under: $InputFolder"

# --- Scan for MP3s ---
try {
    $files = Get-ChildItem -Path $InputFolder -Filter *.mp3 -Recurse -File -ErrorAction Stop
}
catch {
    Write-Error "[FATAL] Error searching for MP3 files: $_"
    Write-Log ("FATAL: Error searching for MP3 files: {0}" -f $_) "FATAL"
    exit 1
}

if (-not $files) {
    Write-Warning "[WARN] No MP3 files found under: $InputFolder"
    Write-Log ("No MP3 files found under: {0}" -f $InputFolder) "WARN"
    exit 1
}

Write-Log ("Found {0} MP3 file(s)." -f $files.Count)
Write-Host ""

# --- Main conversion + sanitize loop ---
$index  = 0
$ok     = 0
$failed = 0
$total  = $files.Count

foreach ($file in $files) {
    $index++
    $percent = [int](($index / $total) * 100)
    $status  = "{0} / {1}: {2}" -f $index, $total, $file.Name

    Write-Host "------------------------------------------------------------"
    Write-Log ("Processing file {0}/{1}: {2}" -f $index, $total, $file.FullName)

    Write-Progress -Activity ("Converting audio to {0}kbps MP3" -f $BitrateKbps) `
                   -Status $status `
                   -PercentComplete $percent

    # Preserve subfolder structure, directories only
    $relativePath = $file.FullName.Substring($InputFolder.Length).TrimStart('\','/')
    $relativeDir  = Split-Path $relativePath -Parent

    if ([string]::IsNullOrEmpty($relativeDir)) {
        $outDir = $outputBase
    } else {
        $outDir = Join-Path $outputBase $relativeDir
    }

    if (-not (Test-Path $outDir)) {
        Write-Log ("Creating output folder: {0}" -f $outDir) "DEBUG"
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Build sanitized + shortened filename, keep date
    $originalBase = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

    if ($originalBase -match '^(?<date>\d{4}-\d{2}-\d{2})\s*-?\s*(?<rest>.*)$') {
        $datePart  = $matches['date']
        $titlePart = $matches['rest']
    }
    else {
        $datePart  = $file.LastWriteTime.ToString('yyyy-MM-dd')
        $titlePart = $originalBase
    }

    # Remove non-safe chars, keep letters, digits, spaces, - and _
    $safeTitle = $titlePart -replace '[^\p{L}\p{Nd}\s\-_]', ''
    # Collapse whitespace and trim
    $safeTitle = ($safeTitle -replace '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($safeTitle)) {
        $safeTitle = 'Episode'
    }

    $base = "$datePart - $safeTitle"

    # Enforce max length
    if ($base.Length -gt $MaxBaseLength) {
        $base = $base.Substring(0, $MaxBaseLength).Trim()
    }

    Write-Log ("Sanitized base: '{0}' (from '{1}')" -f $base, $originalBase) "DEBUG"

    # Handle collisions in this output directory
    $newBase  = $base
    $counter  = 1
    $extension = '.mp3'   # output is always mp3

    while ($true) {
        $candidateName = "$newBase$extension"
        $candidatePath = Join-Path $outDir $candidateName

        if (-not (Test-Path $candidatePath)) {
            break
        }

        $counter++
        $suffix = " ($counter)"
        $limit  = [Math]::Max(1, $MaxBaseLength - $suffix.Length)

        $trimmedBase = if ($base.Length -gt $limit) {
            $base.Substring(0, $limit).TrimEnd()
        }
        else {
            $base
        }

        $newBase = "$trimmedBase$suffix"
    }

    $outFileName = "$newBase$extension"
    $outPath     = Join-Path $outDir $outFileName

    Write-Host "       Source : $($file.FullName)"
    Write-Host "       Target : $outPath"
    Write-Log  ("Output file   : {0}" -f $outPath) "DEBUG"

    # Check metadata, title only
    $hasTitle = $false
    try {
        $ffprobeArgs   = @("-v","quiet","-print_format","json","-show_format",$file.FullName)
        Write-Host "       [DEBUG] Running ffprobe..."
        $ffprobeOutput = & $ffprobe @ffprobeArgs 2>$null

        if ($ffprobeOutput) {
            $meta = $ffprobeOutput | ConvertFrom-Json
            if ($meta.format -and $meta.format.tags -and $meta.format.tags.title) {
                $hasTitle = $true
                Write-Host "       [INFO] Existing title tag: $($meta.format.tags.title)"
            }
            else {
                Write-Host "       [INFO] No title tag found; will set from sanitized filename."
            }
        }
        else {
            Write-Host "       [WARN] ffprobe returned no output; assuming no title tag."
        }
    }
    catch {
        Write-Host "       [WARN] ffprobe failed: $_"
        Write-Log ("ffprobe failed for '{0}': {1}" -f $file.FullName, $_) "WARN"
    }

    # Copy all metadata, and force ID3v2.3 
    $metadataArgs = @("-map_metadata","0","-id3v2_version","3")

    if (-not $hasTitle) {
        # Use the sanitized base, including date as title
        $title = $newBase
        $metadataArgs += @("-metadata","title=$title")
        Write-Host "       [INFO] Setting title tag: $title"
    }

    # ffmpeg re-encode to MP3 64kbps CBR 
    $ffArgs = @(
        "-y",
        "-i", $file.FullName,
        "-vn",
        "-acodec", "libmp3lame",
        "-b:a", ("{0}k" -f $BitrateKbps)
    ) + $metadataArgs + @($outPath)

    Write-Host "       [DEBUG] ffmpeg command line:"
    Write-Host "              $ffmpeg " + ($ffArgs -join " ")

    try {
        & $ffmpeg @ffArgs
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outPath)) {
            $ok++
            Write-Host "       [OK]   Converted successfully."
            Write-Log  ("OK   : '{0}' -> '{1}'" -f $file.FullName, $outPath) "OK"
        }
        else {
            $failed++
            Write-Warning "       [FAIL] ffmpeg exit code: $LASTEXITCODE (or output file missing)"
            Write-Log   ("FAIL : '{0}' (ffmpeg exit code {1})" -f $file.FullName, $LASTEXITCODE) "FAIL"
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
