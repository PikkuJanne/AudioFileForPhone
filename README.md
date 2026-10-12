# AudioFileForPhone

A small Windows PowerShell/FFmpeg tool for converting a folder of podcasts or
audiobooks to MP3 and producing shorter, date-first filenames. It scans
recursively, preserves the relative folder layout and writes a new run under the
current user's configured Music folder. Input files are preserved.

The default is **64 kbps CBR MP3**. Re-encoding can reduce audio quality; it does
**not normalize loudness**. Loudness normalization is deferred and has no current
option. Filename Unicode normalization is a separate naming operation.

The app reports version 1.0.0. Exact package and publication verification are
recorded in the repository's [release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md).
See [CHANGELOG.md](CHANGELOG.md) and the
[tested boundaries in SUPPORT.md](SUPPORT.md#tested-boundaries).

## Setup

Use Windows 11 with Windows PowerShell 5.1 or PowerShell 7. Keep these files
together:

- `AudioFileForPhone.ps1`
- `AudioFileForPhone.Helpers.ps1` (required)
- `AudioFileForPhone.bat` (optional drag-and-drop launcher)

For conversion, provide trusted `ffmpeg.exe` and `ffprobe.exe` either beside the
scripts or in `PATH`. Each executable is found beside the script first, then in
`PATH`. Startup checks that both run and that FFmpeg provides `libmp3lame`.
FFmpeg stays external: the app does not download, install or update tools.
Vendor binaries have their own licenses and provenance. Preview needs neither
executable.

For manual download sources, tested build identities, license differences and
checks of the exact resolved executables, read
[dependency and package security](SECURITY.md). Obtain both tools from the same
trusted build and retain the publisher's notices. Startup capability/version
responses do not authenticate a vendor binary.

The scripts are **unsigned**. Review the [execution-policy guidance](SUPPORT.md#unsigned-scripts-and-execution-policy)
before running downloaded files. The included BAT requests process-scoped
`-ExecutionPolicy Bypass`; use direct PowerShell invocation when you need to keep
policy checks. Never work around an enforced organization policy.

## Usage

Open PowerShell in the application folder. The example input `'.\Podcasts'` must
already contain supported audio; paths resolve from the current PowerShell
location. Without `-Interactive`, there are no metadata prompts.

Convert with the defaults, using Music as the destination:

```powershell
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts'
```

Choose a destination, bitrate and shorter names:

```powershell
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -BitrateKbps 96 -MaxBaseLength 50
```

Apply an existing JPEG/PNG cover and Artist/Album tags to every output:

```powershell
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -CoverPath '.\cover.png' -Artist 'Example narrator' -Album 'Example book'
```

Preview the mapping without writes, tool calls or prompts, even with
`-Interactive`:

```powershell
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio' -DryRun -Interactive
```

Read the authoritative runtime version without starting conversion:

```powershell
. .\AudioFileForPhone.Helpers.ps1; Get-AudioAppVersion
```

Full parameter help and runnable examples are available locally:

```powershell
Get-Help .\AudioFileForPhone.ps1 -Full
Get-Help .\AudioFileForPhone.ps1 -Examples
```

For drag and drop, drop **exactly one folder** onto `AudioFileForPhone.bat`.
It uses `pwsh` when available, otherwise Windows PowerShell, starts in STA mode
for the optional cover picker and supplies `-Interactive`. The wrapper pauses
before returning the child exit code. See the security note above before using it.

## Inputs and options

| Option | Behavior |
| --- | --- |
| `-InputFolder` | Required existing filesystem directory below a drive/share root; scanning is recursive. |
| `-OutputParent` | Optional destination parent; defaults to configured Music. Conversion creates a missing parent. |
| `-BitrateKbps` | Default 64; accepted rates are 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320. Some rates require a compatible source sample rate. |
| `-MaxBaseLength` | Default 60, range 24-180 UTF-16 units; includes date/separator/collision suffix, excludes `.mp3`. |
| `-CoverPath` | Optional readable `.jpg`, `.jpeg` or `.png`; replaces source artwork with one attached JPEG cover. |
| `-Artist`, `-Album` | Nonblank values override source tags for the whole batch; omitted/whitespace-only values keep source tags. |
| `-Interactive` | Optional cover and tag prompts before conversion; cover picker needs STA. Ignored during preview. |
| `-DryRun` | Read-only scan and filename plan; no output folders, audio, markers, cover cache, logs or manifest. |

Inputs are `.mp3`, `.m4a` and `.ogg`, case-insensitively. OGG supports Vorbis and
Opus audio. **`.opus`, `.wav`, `.flac` and `.m4b` are not scanned.** An unsupported
extension is reported separately from a conversion failure.

Preview prints a `[PLAN]` JSON line per supported source, exclusions and naming
warnings. The run timestamp/reservation is provisional; durations, destination
writability, tools, media and covers are unverified. Unchanged names, timestamps
and options keep the same relative mapping, subject to the actual root's path
budget. Remove `-DryRun` when ready to convert.

## Output, names and metadata

Each conversion reserves a fresh run root; an occupied timestamp gets `_2`, `_3`,
and so on. The layout is:

```text
<OutputParent>\AudioForPhone_<Bitrate>kbps_YYYYMMDD_HHmmss\
    <InputFolderName>\<original subfolders>\YYYY-MM-DD - Title.mp3
    AudioFileForPhone_log.txt
    AudioFileForPhone_manifest.json
```

A valid leading `YYYY-MM-DD` is retained; otherwise the file's LastWriteTime
supplies the date. Names retain letters, decimal digits, whitespace, hyphens and
underscores after NFC normalization; whitespace becomes single spaces and empty
titles become `Episode`. Truncation keeps whole Unicode scalars. Windows
case-insensitive collisions receive `(2)`, `(3)`, etc. Folder names are preserved.

Complete output/working file paths must stay below 260 UTF-16 units, created
directories below 248 and components at most 255. Deep or incompatible preserved
folders fail before conversion; select a shallower input or shorter destination.
These limits do not guarantee every phone or MTP implementation accepts the paths.

Selected input/output paths containing junctions or symbolic links are rejected.
Descendant reparse points and recognized generated runs are excluded with reasons;
an unreadable subtree aborts scanning. An input inside a recognized generated run
is rejected. Excluded subtrees are not enumerated or counted as conversions.

The selected first audio stream is encoded with `libmp3lame` and ID3v2.3.
MP3/M4A container tags and OGG first-audio-stream comments supply metadata. An
existing nonempty title is retained; a missing/empty title falls back to the
complete planned basename, including date and collision suffix. Source-specific
tags may have no MP3 equivalent.

**Source artwork is dropped by default.** An explicit JPEG/PNG replaces it for
every output. Invalid explicit covers stop preflight; large covers warn, retain
their dimensions and increase every output's size. Chapters follow FFmpeg's
default mapping from the first input containing chapters. Conversion does not
split files, and copied chapter fields do not establish phone navigation or
resume behavior. Test your own player.

Recorded phone acceptance is limited to Samsung S24, One UI 8.5, AIMP
v4.31.1747 and USB transfer of the three T21 test files. The owner reports long
playback/seeking, resume, tags, supplied cover and ordering work. Chapters were
unavailable in that configuration; chapter navigation was not tested. See the
[tested boundaries](SUPPORT.md#tested-boundaries) for this scope.

## Results and interruption

Final MP3s appear only after encoding, audio/bitrate/duration validation and a
full audio decode. Validation adds a read/decode pass. Independent files continue
after ordinary failures; completed outputs and sources remain available.

| Exit | Result |
| --- | --- |
| `0` | `Completed`: all supported inputs converted, or `Previewed`: planning succeeded with no conversion. |
| `1` | `FailedBeforeConversion` or `Failed`: invalid setup, no supported files, scan/fatal error, or a required record-write failure. |
| `2` | `CompletedWithFailures`: batch finished with at least one per-file failure. |
| `130` | `Cancelled`: controlled Ctrl+C cancellation after metadata prompts in a supported Windows console. |

The summary reports actual counts and output/log/manifest paths. Processed means
converted plus failed; 100 percent processed can include failures. Unsupported
files and scan exclusions are separate counts. PowerShell parameter-binding
errors and forced termination can have host-defined exit behavior.

Controlled Ctrl+C stops the current owned child, waits for exit and removes the
exact owned partial when release and file identity are proved. Completed MP3s
remain; the interrupted file is not processed. Closing/killing the host or losing
power can leave a running child or `.AudioFileForPhone-<token>.partial` file.
Unproved cleanup retains the incomplete path and reports why. Later runs do not
automatically reclaim abandoned runs or partials. See [SUPPORT.md](SUPPORT.md)
for host limits and recovery guidance.

## Local diagnostics and support

Conversion writes a human-readable log and JSON manifest under its run root.
They contain exact paths, metadata, app/tool versions, script hashes, per-file
outcomes, timings, available durations/bytes and bounded native errors. The app
does not upload them. Redact private paths, filenames and metadata before sharing.
Records may be incomplete after a persistence failure or forced shutdown; use
the console's final result too. Preflight-before-reservation and preview have no
run records.

See [SUPPORT.md](SUPPORT.md) for troubleshooting, tested limits and a bug-report
template. Maintainers should use the recorded isolated commands in the
[project status](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md)
and task evidence; do not run retained suites blindly against ordinary Music.

Licensed under the [MIT License](LICENSE). FFmpeg is a separate dependency.

## Building a package (developers)

The repository command `tools/Build-Package.ps1` packages a supplied clean
detached Git worktree at a full source commit. `tools/package-files.json` is the
explicit distributable allowlist; the ZIP keeps the entry script, helper and BAT
adjacent at its root. It includes the selected public docs/license and excludes
FFmpeg/ffprobe, media, logs, caches, tests and repository evidence.

Use a reviewed source commit containing the final package files and builder.
Supply external JSON dependency provenance and test-evidence inputs for that
commit, following the caller schemas in the repository's
[package contract](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/specs/RELEASE_PACKAGE.md).
Before supplying test references, verify the original retained reports' bytes,
SHA-256, tested commit and passing status. The builder carries caller-supplied
report attestations; it does not open those references or run the acceptance tests.
The output directory must be a new absolute path outside the source
checkout, with an existing ordinary parent. Replace the placeholders below with
reviewed identities and exact paths; this example does not select a release
commit or authorize publication:

```powershell
& 'C:\reviewed-source\tools\Build-Package.ps1' -SourcePath 'C:\reviewed-source' -SourceCommit '<full reviewed commit SHA>' -TargetTag '<matching version tag>' -OutputDirectory 'C:\package-output\new-build' -DependencyProvenancePath 'C:\package-evidence\dependencies.json' -TestEvidencePath 'C:\package-evidence\tests.json'
```

The command emits the helper-versioned ZIP, external `release-manifest.json` and
`SHA256SUMS.txt`. The manifest records member hashes, source/provenance and actual
signing observations; checksums establish bytes against a trusted reference, not
publisher authenticity. Required-file omissions, dirty/mismatched source and
unsafe paths fail instead of producing a complete-looking package. A generated
package is not release acceptance: exact extraction, Windows/launcher/phone
checks and recorded approval remain gated by the repository's
[release runbook](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/RELEASE_RUNBOOK.md).
