# AudioFileForPhone — Audio converter + filename sanitizer for Win11 (PowerShell + FFmpeg)
Minimal, no-frills audio converter I use to shrink and clean up podcast/audiobook MP3, M4A, and OGG files for phone listening. It’s a personal, purpose-built tool, not a general audio manager. It trades features for a simple folder-based workflow, predictable output structure, and verbose logging so I can see exactly what happened during each run.

**Synopsis**  
- Accepts a single input folder path (typically via drag & drop on a .bat wrapper).  
- Recursively finds all .mp3, .m4a, and .ogg files under that folder and re-encodes them to MP3 at a phone-friendly bitrate:
  - Default: 64 kbps CBR (configurable via -BitrateKbps).
  - OGG input supports Vorbis and Opus audio; extensions are case-insensitive (including .OGG).
  - Output is always MP3. Other input extensions, such as .opus, .wav, and .flac, are not scanned.
- Creates a new output tree per run:
  - <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\... 
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
  - AudioFileForPhone.bat (wrapper for drag & drop)  
  - ffmpeg.exe 
  - ffprobe.exe 
- Default output root is:
  - <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\ 
- The script first looks for ffmpeg.exe / ffprobe.exe next to itself, then falls back to searching PATH.  

**Usage**
1. Drag & drop via .bat (my default)  
   - Drag a folder containing MP3, M4A, or OGG files onto AudioFileForPhone.bat.
   - The wrapper calls:
        AudioFileForPhone.ps1 -InputFolder "<that folder>" -Interactive
   - The script:
     - Recursively scans for .mp3, .m4a, and .ogg files under the input folder.
     - Re-encodes each file to the selected bitrate.  
     - Writes the output tree under:
       <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\...  
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
  - <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\ 
- For each run:
  - A subfolder named after the input folder’s leaf name:
    - <ScriptFolder>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\<InputFolderName>\ 
  - The original subfolder structure under the input is mirrored beneath <InputFolderName>.  
- Filenames:
  - If the original base name starts with YYYY-MM-DD, that date is preserved:
    - YYYY-MM-DD - Sanitized title.mp3  
  - If no leading date is found, the file’s LastWriteTime is used:
    - YYYY-MM-DD - Sanitized title.mp3
  - The base name (without .mp3) is truncated to MaxBaseLength characters.  
  - If a filename collision occurs in the same folder, suffixes (2), (3), etc. are added.  

**Logging**  
- Each run produces one log file in the AudioForPhone_* root:  
  - AudioFileForPhone_log.txt 
- Logged details include:
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
  - If a title tag already exists, it is preserved.  
  - If no title tag is found, the script sets the title to the sanitized base name.
  - Artist/Album tags can be set for all outputs when provided.
  - A cover image can be embedded into every output MP3 when CoverPath is provided.
  - Warns (and logs) when the selected cover is unusually large (size and/or dimensions).
  - Metadata is copied from the container for MP3/M4A and from the first audio stream for OGG, preserving Vorbis/Opus comments such as title, artist, and album. ID3v2.3 is enforced for compatibility.

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
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AudioFileForPhone.ps1
pwsh -NoProfile -File .\tests\Test-AudioFileForPhone.ps1
```

The checks generate short synthetic audio clips in a temporary folder and verify OGG Vorbis/Opus conversion, metadata, filename handling, cover embedding, and existing MP3/M4A support. Temporary inputs and outputs are removed afterward.

**Intent & License**
This is a personal tool for a very specific workflow. Shrinking and cleaning up my podcast/audiobook MP3, M4A, and OGG files for phone listening, with predictable output and logs I can inspect later. It’s provided as-is, without warranty. Use at your own risk. If you want to reuse or adapt it, feel free, just keep in mind it intentionally avoids extra features to stay simple, and easy to reason about when something breaks in the middle of a batch.
