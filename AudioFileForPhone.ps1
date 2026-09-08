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
            <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHMMSS\
              <InputFolderName>\subfolders...
    - One-preset audio conversion:
        - Re-encodes all input .mp3, .m4a, and .ogg files using ffmpeg.
        - Supports Ogg Vorbis and Ogg Opus audio in .ogg files.
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
        - Writes them into a fresh AudioForPhone_* output tree.
        - Shortens and sanitizes filenames so Android accepts them.
        - Optionally embeds cover + sets artist/album tags for AIMP/players.
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
        - Drag a folder containing .mp3, .m4a, or .ogg files onto:
            AudioFileForPhone.bat
        - The .bat calls:
            AudioFileForPhone.ps1 -InputFolder "<that folder>" -Interactive
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
    [string]$Album
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

# --- Basic sanity check on param ---
if ([string]::IsNullOrWhiteSpace($InputFolder)) {
    Write-Error "[FATAL] InputFolder parameter is null or empty. This usually means the .bat did not pass the path correctly."
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

function Validate-CoverPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return @('.jpg', '.jpeg', '.png') -contains $ext
}

function Get-CoverDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $diag = [ordered]@{
        Path      = $Path
        SizeBytes = $null
        SizeMB    = $null
        Width     = $null
        Height    = $null
        Warnings  = @()
    }

    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        $diag.SizeBytes = [int64]$fi.Length
        $diag.SizeMB    = [Math]::Round(($fi.Length / 1MB), 2)

        # Size heuristic: warn if > 2MB (can bloat every MP3)
        if ($diag.SizeMB -gt 2.0) {
            $diag.Warnings += ("Cover is {0} MB. Consider a smaller JPG to avoid bloating every output MP3." -f $diag.SizeMB)
        }

        # Dimension heuristic: best-effort only (System.Drawing)
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop | Out-Null
            $img = [System.Drawing.Image]::FromFile($Path)
            try {
                $diag.Width  = $img.Width
                $diag.Height = $img.Height

                if (($diag.Width -gt 1200) -or ($diag.Height -gt 1200)) {
                    $diag.Warnings += ("Cover dimensions are {0}x{1}. Consider ~800x800 to keep file sizes sane." -f $diag.Width, $diag.Height)
                }
            }
            finally {
                $img.Dispose()
            }
        }
        catch {
            # Ignore, dimensions are optional
        }
    }
    catch {
        $diag.Warnings += ("Could not read cover file info: {0}" -f $_)
    }

    return [pscustomobject]$diag
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
            if ($picked -and (Validate-CoverPath -Path $picked)) {
                $CoverPath = $picked
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

# --- Helper: find ffmpeg / ffprobe either next to script or in PATH ---
function Get-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExeName
    )

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
"Start time    : $(Get-Date)"     | Add-Content -Path $logPath
"Input folder  : $InputFolder"    | Add-Content -Path $logPath
"Output root   : $outputRoot"     | Add-Content -Path $logPath
"Bitrate (kbps): $BitrateKbps"    | Add-Content -Path $logPath
"Max base len  : $MaxBaseLength"  | Add-Content -Path $logPath
"CoverPath     : $CoverPath"      | Add-Content -Path $logPath
"Artist        : $Artist"         | Add-Content -Path $logPath
"Album         : $Album"          | Add-Content -Path $logPath
""                                   | Add-Content -Path $logPath

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "[{0}] {1}" -f $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

# --- Validate cover path, non-interactive parameter or interactive pick + log diagnostics ---
if (-not [string]::IsNullOrWhiteSpace($CoverPath)) {
    if (-not (Validate-CoverPath -Path $CoverPath)) {
        Write-Log ("Invalid CoverPath '{0}'. Continuing without cover." -f $CoverPath) "WARN"
        $CoverPath = $null
    }
    else {
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
}

# --- Output base, mirrors input folder name ---
$inputLeaf  = Split-Path $InputFolder -Leaf
$outputBase = Join-Path $outputRoot $inputLeaf

Write-Log ("Output base      : {0}" -f $outputBase)

New-Item -ItemType Directory -Path $outputBase -Force | Out-Null

Write-Host ""
Write-Log "Scanning for audio files (.mp3/.m4a/.ogg) under: $InputFolder"

# --- Scan for MP3 + M4A + OGG ---
try {
    $files = @(Get-ChildItem -LiteralPath $InputFolder -Recurse -File -ErrorAction Stop |
        Where-Object { @('.mp3', '.m4a', '.ogg') -contains $_.Extension.ToLowerInvariant() })
}
catch {
    Write-Error "[FATAL] Error searching for audio files: $_"
    Write-Log ("FATAL: Error searching for audio files: {0}" -f $_) "FATAL"
    exit 1
}

if (-not $files) {
    Write-Warning "[WARN] No MP3/M4A/OGG files found under: $InputFolder"
    Write-Log ("No MP3/M4A/OGG files found under: {0}" -f $InputFolder) "WARN"
    exit 1
}

Write-Log ("Found {0} audio file(s) (.mp3/.m4a/.ogg)." -f $files.Count)
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

    $safeTitle = $titlePart -replace '[^\p{L}\p{Nd}\s\-_]', ''
    $safeTitle = ($safeTitle -replace '\s+', ' ').Trim()

    if ([string]::IsNullOrWhiteSpace($safeTitle)) {
        $safeTitle = 'Episode'
    }

    $base = "$datePart - $safeTitle"

    if ($base.Length -gt $MaxBaseLength) {
        $base = $base.Substring(0, $MaxBaseLength).Trim()
    }

    Write-Log ("Sanitized base: '{0}' (from '{1}')" -f $base, $originalBase) "DEBUG"

    $newBase    = $base
    $counter    = 1
    $extension  = '.mp3'

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

    # Ogg Vorbis/Opus comments live on the audio stream, not the container.
    $isOgg = $file.Extension -ieq '.ogg'
    $metadataSource = if ($isOgg) { '0:s:a:0' } else { '0' }

    # Check the same metadata source that ffmpeg will copy to the output.
    $hasTitle = $false
    try {
        $ffprobeArgs   = @("-v","quiet","-print_format","json","-show_format",
                          "-select_streams","a:0","-show_streams",$file.FullName)
        Write-Host "       [DEBUG] Running ffprobe..."
        $ffprobeOutput = & $ffprobe @ffprobeArgs 2>$null

        if ($ffprobeOutput) {
            $meta = $ffprobeOutput | ConvertFrom-Json
            $sourceTags = if ($isOgg) {
                $meta.streams | Select-Object -First 1 -ExpandProperty tags -ErrorAction SilentlyContinue
            } else {
                $meta.format.tags
            }
            if ($sourceTags -and $sourceTags.title) {
                $hasTitle = $true
                Write-Host "       [INFO] Existing title tag: $($sourceTags.title)"
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
            "-y",
            "-i", $file.FullName,
            "-i", $CoverPath,
            "-map", "0:a:0",
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
            "-y",
            "-i", $file.FullName,
            "-map", "0:a:0",
            "-vn",
            "-acodec", "libmp3lame",
            "-b:a", ("{0}k" -f $BitrateKbps)
        ) + $metadataArgs + @($outPath)
    }

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
