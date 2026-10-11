# AudioFileForPhone — Audio converter + filename sanitizer for Win11 (PowerShell + FFmpeg)
Minimal, no-frills audio converter I use to shrink and clean up podcast/audiobook MP3, M4A, and OGG files for phone listening. It’s a personal, purpose-built tool, not a general audio manager. It trades features for a simple folder-based workflow, predictable output structure, and verbose logging so I can see exactly what happened during each run.

**Synopsis**  
- Accepts a single input folder path (typically via drag & drop on a .bat wrapper).  
- Recursively finds all .mp3, .m4a, and .ogg files under that folder and re-encodes them to MP3 at a phone-friendly bitrate:
  - Default: 64 kbps CBR (configurable via -BitrateKbps).
  - OGG input supports Vorbis and Opus audio; extensions are case-insensitive (including .OGG).
  - Output is always MP3. Other input extensions, such as .opus, .wav, and .flac, are not scanned.
- Creates a new output tree per run in the current user's Music folder:
  - `<MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\...`
- Sanitizes and shortens filenames for Android / MTP:
  - Keeps a YYYY-MM-DD prefix when available, or uses the file’s timestamp.  
  - Strips problematic characters, collapses whitespace, and truncates to a configurable max length.  
  - Avoids collisions by appending (2), (3), etc.  
- Optional batch metadata helpers:
  - Can embed an album cover image into every output MP3 (.jpg/.png).  
  - Can set Artist and Album tags for all output files.  
  - In interactive mode, cover selection uses a file picker.  
  - Warns (and logs) if the chosen cover is unusually large (size and/or dimensions).  
- Writes a per-run log file in the output root:
  - Each root is exclusively created. If a timestamp is occupied, a numeric suffix such as `_2` is added; existing runs are preserved.
  - AudioFileForPhone_log.txt with detailed per-file information.

**Requirements**  
- Windows 11  
- PowerShell (Windows PowerShell or PowerShell 7 is fine)  
- ffmpeg.exe and ffprobe.exe 
  - Either next to the script or available in PATH.  
- Optional: .bat wrapper for drag-and-drop usage

**Installation**  
- Place these files together in a folder of your choice:
  - AudioFileForPhone.ps1  
  - AudioFileForPhone.Helpers.ps1 (required beside the script)
  - AudioFileForPhone.bat (wrapper for drag & drop)  
  - ffmpeg.exe 
  - ffprobe.exe 
- `<MusicFolder>` is the current user's configured Windows Music folder, usually `C:\Users\<user>\Music`. Moved or redirected Music folders are supported.
- To choose a different destination, pass `-OutputParent "D:\Phone audio"` directly to the PowerShell script. A missing directory is created; relative paths use the current PowerShell location. The run folder and recursive layout are the same under that parent.
- Default output root is:
  - `<MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\`
- The script first looks for ffmpeg.exe / ffprobe.exe next to itself, then falls back to searching PATH.  
- Before optional metadata prompts, the script checks the input directory, destination access, tool versions, `libmp3lame` availability and any explicit cover. Drive and share roots are rejected; choose a folder below the root. An invalid explicit cover stops the run with an error.
- `-BitrateKbps` accepts `8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320`; the default remains 64. Some rates require a compatible source sample rate.
- `-MaxBaseLength` accepts 24–180, with default 60. Normal preflight creates a missing destination parent and briefly tests file/directory creation using uniquely owned probes, then removes them.
- Discovery finishes before metadata prompts or run creation. It takes a sorted input snapshot and excludes the planned run and prior runs identified by `.AudioFileForPhone-output.json`, or by a matching legacy log and mirrored input folder. A similar folder name alone is retained.
- Selected input/output paths containing junctions or symbolic links are rejected. Descendant file and directory reparse points are skipped with a warning and recorded in the run log. An inaccessible subtree aborts the scan before conversion; selecting a prior generated run or a folder inside it is rejected.

**Usage**
1. Drag & drop via .bat (my default)  
   - Drag a folder containing MP3, M4A, or OGG files onto AudioFileForPhone.bat.
   - The wrapper calls:
        AudioFileForPhone.ps1 -InputFolder "<that folder>" -Interactive
   - The script:
     - Recursively scans for .mp3, .m4a, and .ogg files under the input folder.
     - Re-encodes each file to the selected bitrate.  
     - Writes the output tree under:
       `<MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\...`
     - Sanitizes and shortens filenames while keeping a date prefix.  
     - Optionally prompts once for:
       - Album cover embed (file picker), and/or
       - Artist + Album tags for all outputs.  
   - A log file for the run is written into the AudioForPhone_* root.
2. Direct PowerShell (default options)  
   - Run the script directly with just an input folder:
        .\AudioFileForPhone.ps1 -InputFolder "C:\MyPodcasts"
   - This uses:
     - -BitrateKbps 64 
     - -MaxBaseLength 60 
3. Direct PowerShell (custom options)  
   - Use when you want to adjust bitrate or maximum filename length:
        #96 kbps, slightly shorter names 
        .\AudioFileForPhone.ps1
            -InputFolder   "C:\MyPodcasts"
            -BitrateKbps   96
            -MaxBaseLength 50
4. Direct PowerShell (with batch metadata)  
   - Use when you want cover + artist/album without prompts:
        .\AudioFileForPhone.ps1
            -InputFolder "C:\MyPodcasts"
            -CoverPath  "C:\Images\cover.jpg"
            -Artist     "Some Artist"
            -Album      "Some Album"

**Output layout**  
- Default root per run:
  - `<MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\`
- For each run:
  - A subfolder named after the input folder’s leaf name:
    - `<MusicFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\`
  - The original subfolder structure under the input is mirrored beneath <InputFolderName>.  
- Filenames:
  - A real leading YYYY-MM-DD calendar date is preserved:
    - YYYY-MM-DD - Sanitized title.mp3  
  - An absent or impossible date uses LastWriteTime. An impossible prefix remains part of the title input:
    - YYYY-MM-DD - Sanitized title.mp3
  - Titles use NFC, then retain letters, decimal digits, whitespace, hyphens and underscores. Other characters and remaining noncomposing combining marks are removed; whitespace becomes single spaces. An empty title becomes Episode.
  - MaxBaseLength accepts 24–180 UTF-16 units (default 60), including the complete date, separator and collision suffix, excluding .mp3. Truncation keeps whole Unicode scalars.
  - Case-insensitive Windows collisions get suffixes (2), (3), etc. Source paths are ordered with OrdinalIgnoreCase, then Ordinal for ties, so the source-to-output mapping is repeatable.
  - All names and preserved folders are planned before prompts or output creation. Complete file and future working paths must be below 260 UTF-16 units; created directories must be below 248 and components at most 255. Unsupported/deep folder paths fail with guidance to use a shallower input or shorter OutputParent. Folder names are preserved. These limits do not guarantee acceptance by every phone/MTP implementation.

**Logging**  
- Each run produces one log file in the AudioForPhone_* root:  
  - AudioFileForPhone_log.txt 
- Logged details include:
  - Absolute FFmpeg/ffprobe paths and versions checked at startup.
  - Start time, input folder, output root, bitrate, and max base length.  
  - Selected metadata options (cover/artist/album) when used.
  - Cover diagnostics warnings when a cover is used.
  - For each file:
    - Original full path.  
    - Relative path and target directory.  
    - Original base name and chosen sanitized base name.  
    - Final output path.  
    - ffmpeg success or failure, including exit codes and exceptions.  
  - End-of-run summary:
    - Total files processed.  
    - Converted count.  
    - Failed count.  

**Batch wrapper (included)**  
- AudioFileForPhone.bat (drag-and-drop launcher):
  - Drag a folder onto the .bat to start a run.  
  - The .bat passes the folder path as -InputFolder to AudioFileForPhone.ps1.  
  - The provided wrapper launches PowerShell in STA mode so the cover picker works reliably.
  - If you want to extend it later (e.g. to pass custom bitrate or other flags), you can edit the wrapper to add parameters.

**Technical details**  
- Tool discovery:
  - Checks the script directory for ffmpeg.exe and ffprobe.exe.  
  - If not found, iterates over PATH to locate them.  
  - If still not found, aborts with a clear fatal error.  
- File scanning:
  - Uses Get-ChildItem -LiteralPath -Recurse to find .mp3, .m4a, and .ogg files under the input folder.
- Filename sanitization:
  - Attempts to parse a leading date from the original base name:
    - Pattern: YYYY-MM-DD - ...  
  - If no date is present, uses the file’s LastWriteTime formatted as yyyy-MM-dd.  
  - Removes non-safe characters, keeping:
    - Letters, digits, spaces, - and _.  
  - Collapses multiple spaces into one and trims surrounding whitespace.  
  - Truncates the resulting base name to MaxBaseLength characters.  
  - Performs a collision check in the output directory and adds numeric suffixes when needed.  
- Re-encoding:
  - Uses ffmpeg to convert each input file to MP3:
    - Audio codec: libmp3lame.  
    - Bitrate: BitrateKbps (e.g. 64k).  
    - Video is explicitly discarded (-vn).  
  - Output is always .mp3, regardless of internal encoding details.  
- Metadata:
  - Uses ffprobe to inspect the input file’s format and audio-stream tags.
  - A failed probe, invalid JSON or missing audio stream is logged as a file failure. A successful probe without a title uses the filename fallback.
  - If a title tag already exists, it is preserved.  
  - If no title tag is found, the script sets the title to the sanitized base name.
  - Artist/Album tags can be set for all outputs when provided.
  - A cover image can be embedded into every output MP3 when CoverPath is provided.
  - Warns (and logs) when the selected cover is unusually large (size and/or dimensions).
  - Metadata is copied from the container for MP3/M4A and from the first audio stream for OGG, preserving Vorbis/Opus comments such as title, artist, and album. ID3v2.3 is enforced for compatibility.
- Native execution:
  - Uses a shared process helper on PowerShell 5.1 and 7, with literal executable paths and Windows argument quoting.
  - Drains stdout and stderr concurrently and retains bounded diagnostic text. FFmpeg uses `-nostdin`; ordinary stderr output does not itself indicate failure.

**Troubleshooting**  
- Script window closes immediately:
  - Run AudioFileForPhone.bat from an existing cmd window to see the error output.  
  - Check PowerShell’s ExecutionPolicy and any corporate restrictions on running scripts.  
- “Could not find ffmpeg.exe / ffprobe.exe”:
  - Make sure both binaries are either:
    - In the same folder as AudioFileForPhone.ps1, or  
    - Installed somewhere that is included in PATH.  
- “Could not resolve input folder”:
  - The folder path passed from the .bat may be invalid.  
  - Ensure you are dragging a real folder, not a shortcut or an individual file.  
- Cover picker does not open:
  - Ensure the .bat launches PowerShell with -Sta (the provided wrapper does).
  - If running manually, use:
        pwsh -Sta -File .\AudioFileForPhone.ps1 -InputFolder "C:\MyPodcasts" -Interactive
- Long path / ItemNotFound errors:
  - Extremely deep input paths combined with long filenames can hit Windows path length limits.  
  - Workaround: move or temporarily rename the input folder to a short path (e.g. C:\P) and rerun the tool.  
- Files appear missing on the phone:
  - Confirm that the number of converted files in AudioForPhone_* matches your expectations.  
  - Open AudioFileForPhone_log.txt and look for:
    - Per-file failures or ffmpeg exit codes.  
    - Any skipped files due to errors.  

**Verification**

Run the integration checks with FFmpeg and ffprobe installed as described above:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1
```

The checks generate short synthetic audio clips and pass a dedicated temporary `OutputParent` for every conversion. They verify output isolation, OGG Vorbis/Opus conversion, metadata, filename handling, cover embedding, and existing MP3/M4A support. Source hashes are compared before and after; only the marked temporary test tree is removed afterward. Optional `-FfmpegPath` and `-FfprobePath` select an installed executable pair.

**Intent & License**
This is a personal tool for a very specific workflow. Shrinking and cleaning up my podcast/audiobook MP3, M4A, and OGG files for phone listening, with predictable output and logs I can inspect later. It’s provided as-is, without warranty. Use at your own risk. If you want to reuse or adapt it, feel free, just keep in mind it intentionally avoids extra features to stay simple, and easy to reason about when something breaks in the middle of a batch.
