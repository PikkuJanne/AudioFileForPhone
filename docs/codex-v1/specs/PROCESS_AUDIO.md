# Native process, audio and metadata contract

## Small shared process helper

Keep one helper for native invocation and a focused media-probe wrapper. Capture
exact tool path, exit code, stdout/stderr and timing while keeping memory bounded.
Drain redirected streams concurrently so a verbose child cannot block behind a
full pipe. Capture native exit status immediately. Missing executable, failed
probe, invalid JSON, missing audio and missing title are different results.

No Invoke-Expression, shell-evaluated command line, arbitrary cmd /c around FFmpeg,
or user-controlled executable text. Resolve ffmpeg.exe and ffprobe.exe to real
application paths (local beside script, then PATH per baseline), verify identity/
capability and log versions. Never auto-download dependencies or elevate.

PowerShell 5.1 native quoting differs from newer PowerShell; do not assume an
argument array alone proves exact delivery, or require PS7-only .NET APIs. Use an
argv-capture child and actual metadata fixtures on both shells. This contract is
supported by Microsoft about_Parsing, source S4. Preserve command execution behavior
without downgrading machine-wide security policies.

Use -nostdin for FFmpeg. Machine-readable -progress records are separate from stderr
diagnostics; parse them defensively (source S3). Keep process handle ownership for
cancellation. No broad process-name termination or forced arbitrary short timeout
that breaks normal audiobook conversion.

T05 implementation uses an absolute application path and one Windows CRT quoting
algorithm on both shells. A lazily compiled .NET helper reads fixed-size UTF-8
chunks on concurrent tasks; it retains at most 1,048,576 stdout characters and
65,536 stderr characters by default, while draining/counting the remainder.
Results carry native status, immediate exit code, text, truncation flags and
elapsed time without depending on or changing PowerShell LASTEXITCODE. No timeout
is imposed on ordinary conversion. Process handles and redirected streams belong
to that invocation and are disposed when it returns.

The focused probe selects `a:0`, validates exactly one audio stream and its
absolute stream index, and inspects only stream/container tags plus stream
identity. Conversion maps that validated stream. Failed startup, nonzero probe,
truncated output, invalid JSON/schema and no audio are file failures; successful
inspection reports title presence separately. MP3/M4A container tags and Ogg
first-audio-stream comments keep their existing precedence. Version/encoder
checks run once before prompts, and the accepted paths/versions enter the run log.

References for the implementation: [Microsoft CRT argument parsing](https://learn.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments)
and [Microsoft redirected process I/O guidance](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.standardoutput).

## Preserve audio behavior

Supported scanned extensions remain MP3/M4A/OGG, including Ogg Vorbis and Opus.
Output stays MP3/libmp3lame, 64 kbps CBR default, configurable validated bitrate.
Characterize channels/sample rate before change; do not add forced mono, a new
sample rate, normalization, silence trimming, EQ or noise reduction by default.
Select the intended source audio stream explicitly and avoid accidentally copying
video, extra audio streams or source attached pictures.

Treat media as local files, not user-provided URLs. Audit external-reference media
behavior and test any proposed FFmpeg protocol restriction against intended local
formats before adopting it. No processing telemetry or runtime download requests.
The process wrapper is not a sandbox for malicious decoder vulnerabilities; use
maintained trusted FFmpeg builds and do not claim otherwise.

## Tags and artwork

Keep ID3v2.3, existing titles or sanitized-title fallback, Ogg audio-stream tags and
Artist/Album batch overrides. Decide precedence explicitly when container and stream
tags conflict. Test track/disc, comment, Unicode and quotation marks. Avoid a
single generic metadata-map change that loses Ogg title/artist fields.

Default source artwork remains dropped. Explicit CoverPath supplies one batch
cover; validate readable/decodeable JPEG/PNG once before conversion. An explicit
invalid cover fails clearly instead of being ignored. No resizing is required for
v1; retain large-cover diagnostics. Optional resizing must preserve aspect ratio,
be opt-in, use an owned cache once per run and clean up its handles/files.

Chapter information and player navigation are separate from ordinary title/track
tags. Test actual chapter output and document limitations, especially M4A-to-MP3.
Do not promise source chapter navigation in phone players simply because metadata
copying is enabled. M4B, .opus, .wav and .flac scanning stay outside current scope.
