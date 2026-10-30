# AudioFileForPhone

A small Windows PowerShell/FFmpeg tool for converting a folder of podcasts or
audiobooks to MP3 and producing shorter, date-first filenames. It scans
recursively, preserves the relative folder layout and writes a new run under the
current user's configured Music folder. Input files are preserved.

The default is **64 kbps CBR MP3**. Re-encoding can reduce audio quality; it does
**not normalize loudness**. Loudness normalization is deferred and has no current
option. Filename Unicode normalization is a separate naming operation.

The app reports version 1.0.1. Candidate package, acceptance and publication status
are recorded in the repository's [active release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1.0.1/STATUS.md).
See [CHANGELOG.md](CHANGELOG.md) and the
[tested boundaries in SUPPORT.md](SUPPORT.md#tested-boundaries).

## Setup

**Development repair:** the direct BAT launch described below is an R1 source
patch. Published v1.0.1 ZIP bytes are unchanged. The revised user package (R2)
and exact-package acceptance/release (R3) are separate work. Owner testing required:
none; all new repair verification is automated by Codex.

For the existing GitHub download, extract the complete ZIP into a new, empty folder and keep the `app` folder beside
the launch files. The top level contains only the converter/setup BAT and PS1
entry points, a short README and the license. Drag an audio folder onto
`AudioFileForPhone.bat`; use `Setup-AudioFileForPhone.bat` to select FFmpeg.
The supporting scripts and full documentation live in `app/`.

Explicit and saved FFmpeg selections and PATH discovery work as before. If you
keep an application-local pair instead, put both executables in `app/`, beside
the implementation scripts. FFmpeg is not included in the download.

The target systems are Windows 10 22H2 x64 and Windows 11 x64 with Windows
PowerShell 5.1 or PowerShell 7. See the recorded acceptance limits in SUPPORT.md.
In a source checkout (or inside the download's `app/` folder), keep these files together:

- `AudioFileForPhone.ps1`
- `AudioFileForPhone.Helpers.ps1` (required)
- `AudioFileForPhone.Diagnostics.ps1` (startup evidence and local support export)
- `Check-AudioFileForPhone.ps1`, `Check-AudioFileForPhone.bat` and `AudioFileForPhone.Checks.ps1` (environment check and explicit synthetic self-test)
- `AudioFileForPhone.bat` (optional drag-and-drop launcher)
- `AudioFileForPhone.Launcher.ps1` and `AudioFileForPhone.HostProbe.ps1` (retained legacy source; unused by the repaired BAT)
- `Setup-AudioFileForPhone.ps1` and `Setup-AudioFileForPhone.bat` (dependency setup)
- `AudioFileForPhone.ManagedSetup.ps1` and `tools/ffmpeg-download.json` (optional pinned download)

For conversion, provide trusted `ffmpeg.exe` and `ffprobe.exe`. Selection order is
`-FfmpegDirectory`, a deliberately saved user selection, a complete pair beside
the scripts, then `PATH`. Explicit, saved and app-local choices require both
regular executables in that directory. An incomplete local pair or an invalid
explicit/saved choice stops preflight with repair guidance. Startup checks that
both run and that FFmpeg provides `libmp3lame`, and prints the origin and paths.
FFmpeg stays external. Existing-tool setup needs no network access. Separate setup
also offers an optional pinned vendor download after affirmative consent. Conversion
never downloads tools.
Vendor binaries have their own licenses and provenance. Preview needs neither
executable.

For the setup walkthrough and offline recovery, see
[Existing-tool setup and recovery](#existing-tool-setup-and-recovery).

For manual download sources, tested build identities, license differences and
checks of the exact resolved executables, read
[dependency and package security](SECURITY.md). Obtain both tools from the same
trusted build and retain the publisher's notices. Startup capability/version
responses do not authenticate a vendor binary.

The scripts are **unsigned**. Review the [execution-policy guidance](SUPPORT.md#unsigned-scripts-and-execution-policy)
before running downloaded files. The repaired conversion and setup BATs request
process-only `-ExecutionPolicy Bypass` for this trusted unsigned personal app.
This leaves saved policy unchanged; MachinePolicy, UserPolicy and application
control remain authoritative. A denial stays visible without retrying another host.

## Usage

Open PowerShell in the application folder. The example input `'.\Podcasts'` must
already contain supported audio; paths resolve from the current PowerShell
location. Without `-Interactive`, there are no metadata prompts.

With `-Interactive` (including drag and drop), dependency repair finishes before
the ready menu shows the supported-file count and selected bitrate:

```text
Ready: 3 supported files -> 64 kbps CBR MP3
Enter = start with defaults | M = customize metadata | Q = cancel
Waiting for your selection (no conversion has started).
```

Press Enter to convert using the normal source-tag/artwork policy and any supplied
parameters. M offers cover, Artist and Album choices for this batch; supplied
parameters remain in effect, including blank Artist/Album values that retain
source tags. Conversion starts after the last metadata choice. Q cancels before
batch output. Metadata choices are never saved for later batches. Invalid input
stops with guidance; EOF cancels. Redirected or unavailable console input stops
without starting a batch. For automation, omit `-Interactive` and pass parameters.
The console distinguishes preflight, waiting, probing, encoding, validation and
publication; encoding at 100% still needs validation before the file is complete.

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
The repaired BAT starts one built-in x64 Windows PowerShell 5.1 STA process with
`-NoProfile`, calling the converter directly and enabling its existing interactive
workflow. It performs no host selection or automatic retry. CMD prints the result,
pauses and returns the original exit code: 0 success, 1 failure, 2 partial failure,
or 130 cancellation. Startup and parsing errors remain above the pause. Forced
window termination cannot preserve visibility or guarantee an exit result.

PowerShell 7 remains available through the direct parameter-based converter route.
After reviewing and trusting the unsigned app, an explicit process-only launch can
use an existing FFmpeg pair outside PATH:

```powershell
pwsh -NoProfile -Sta -ExecutionPolicy Bypass -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -FfmpegDirectory 'D:\Trusted tools\bin'
```

Direct calls keep all conversion/preview options, including `-ConfigPath` and
`-Interactive`. No PATH edit is required. The old Launcher/HostProbe scripts remain
in source for historical compatibility; the repaired BAT does not depend on them
or honor their host override. When calling a BAT from a shell, account for the
caller's expansion rules; it cannot recover text already expanded by CMD.

## Existing-tool setup and recovery

After reviewing a trusted existing build, run setup from the application folder:

```powershell
.\Setup-AudioFileForPhone.ps1
```

Choose **S** to select the directory containing both executables. A Windows folder
picker is used when available; otherwise type the exact directory path without
surrounding quotes. Only that directory is checked. Setup shows both paths,
versions, detected architecture and SHA-256 hashes, then asks whether to remember
the choice. **N** keeps it for this launch only; **Q** cancels. **M** gives manual
instructions. In the separate setup entry, **D** displays the pinned provider,
build, transfer size, destination, SHA-256, source and license before asking **Y**
to download. Any other answer cancels. An invalid pair stops setup without
replacing a saved choice.

The repaired `Setup-AudioFileForPhone.bat` opens the same setup using one built-in
x64 Windows PowerShell 5.1 STA process, `-NoProfile` and process-only `Bypass`.
Managed policy and application control still apply. CMD retains errors, pauses
and returns the original result. It accepts no arguments; use the PS1 entry for
explicit options. A console with readable input
is needed for interactive setup. To select and remember a reviewed pair directly,
without prompts or a PATH edit:

```powershell
.\Setup-AudioFileForPhone.ps1 -FfmpegDirectory 'D:\Trusted tools\bin' -Remember -NonInteractive
```

Omit `-Remember` to validate and display the pair without saving. Setup returns 0
when the selected pair is ready, 1 when configuration or an explicitly requested
save fails, and 130 on cancel. A failed settings write clearly says the choice
was **not remembered** and gives an explicit `-FfmpegDirectory` conversion command.
The valid pair can still be used for the current interactive conversion.

When an `-Interactive` conversion cannot resolve its tools, it offers the same
existing-tool setup before metadata prompts and resumes that launch with the validated pair.
Its **D** choice gives the separate setup command and stops without downloading.
Ordinary conversion never prompts, downloads or saves settings; it reports the
exact setup repair command. Preview never starts setup, reads config or calls
tools, including when `-Interactive` is supplied.

For optional managed setup, review [the pinned manifest](tools/ffmpeg-download.json)
and its vendor/license references. It selects the exact Gyan Windows x64 static
9.0.2 essentials ZIP, downloaded directly from the publisher. All extracted vendor
files, GPLv3 notices and provenance are retained in a new private versioned
directory. Tools are checked and a tiny synthetic MP3 is encoded, probed and fully
decoded before the install is offered for selection. Existing installations stay
in place; future launches never update them automatically.

To consent explicitly without prompts:

```powershell
.\Setup-AudioFileForPhone.ps1 -Download -Consent -Remember -NonInteractive
```

`-Download` without `-Consent` refuses. Omit `-Remember` to install/validate and
display a current-run command without changing config. Default managed storage is
`managed` beside the selected config file; `-ManagedRoot` chooses a private portable
storage directory. `-ConfigPath` still selects the same config for setup/conversion.
HTTPS certificate checks, pinned SHA-256, transfer/time limits and safe extraction
bounds must pass. Ctrl+C cancels owned work; offline/errors preserve the previous
selection and leave manual setup available. No admin access or persistent PATH,
registry or policy change is needed. The repository/package contains no FFmpeg
binaries. A newer pin requires a reviewed application change.

## Inputs and options

| Option | Behavior |
| --- | --- |
| `-InputFolder` | Required existing filesystem directory below a drive/share root; scanning is recursive. |
| `-OutputParent` | Optional destination parent; defaults to configured Music. Conversion creates a missing parent. |
| `-BitrateKbps` | Default 64; accepted rates are 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320. The audio plan chooses a compatible sample rate before encoding. |
| `-MaxBaseLength` | Default 60, range 24-180 UTF-16 units; includes date/separator/collision suffix, excludes `.mp3`. |
| `-CoverPath` | Optional readable `.jpg`, `.jpeg` or `.png`; replaces source artwork with one attached JPEG cover. |
| `-Artist`, `-Album` | Nonblank values override source tags for the whole batch; omitted/whitespace-only values keep source tags. |
| `-Interactive` | Offers tool repair when needed, then Enter to start, M for batch metadata, Q to cancel; pickers use STA. Ignored during preview. |
| `-DryRun` | Read-only scan and filename plan; no output folders, audio, markers, cover cache, logs or manifest. |
| `-ProbeTimeoutSeconds` | Advanced source/output probe deadline, default 60 seconds (1-2147483). Increase for large files or slow storage after a probe Timeout. |
| `-FfmpegDirectory` | Directory containing both trusted executables; overrides saved/app-local/PATH selection for this run without saving or changing PATH. |
| `-ConfigPath` | Optional config file location; overrides the Windows user-local default. Relative paths use the current PowerShell location. Only deliberate interactive setup can save it; preview does not read config. |

Before each source is encoded, the log and run manifest record its audio plan.
Mono/stereo and a compatible source sample rate are preserved. Other rates use
the nearest compatible rate supported by the selected libmp3lame (ties lower):
8/16/24 kbps require at most 24 kHz; 144 kbps requires 16/22.05/24 kHz;
80/96/112/128/160 kbps require at least 16 kHz; 192/224/256/320 kbps require
32/44.1/48 kHz. Ordinary 64 kbps at an MP3-supported rate keeps its audio shape.
The exact promised stream bitrate, sample rate and channels are checked before
publication, along with duration and full decoding.

MP3 has at most two channels. Standard 2.1, 3.0, quad, 4.0, 5.0, 5.0(side),
5.1, 5.1(side), 6.1 and 7.1 layouts explicitly use FFmpeg's stereo downmix.
Other multichannel layouts, missing audio shape, or a build without a compatible
sample rate get an actionable error before encoding that source. These choices
do not add loudness normalization or change the source file.

To use an existing external installation, add `-FfmpegDirectory 'D:\Trusted tools\bin'`
to the conversion command. No PATH edit is required. The default config file is
`%LOCALAPPDATA%\AudioFileForPhone\config.json`, resolved using the Windows user-folder
API. `-ConfigPath '.\portable-config.json'` selects a different file. A missing file
allows app-local/PATH discovery; stale, corrupt or unsupported config stops it.
An explicit directory can override that file for the current run without changing
it. Setup also accepts `-ConfigPath '.\portable-config.json'`; use that same option
for conversion to read a portable selection. Corrupt or newer config is preserved.
Use another writable ConfigPath or move only the reviewed problematic file aside
before deliberately saving again.

Remember a trusted existing pair only when you deliberately run this helper:

```powershell
. .\AudioFileForPhone.Helpers.ps1
Save-AudioToolSelection -FfmpegDirectory 'D:\Trusted tools\bin'
```

The helper accepts the same `-ConfigPath` override, validates the pair before an
atomic UTF-8 JSON write, and stores `schema_version: 1` and `ffmpeg_directory`.
It preserves other schema-1 settings and refuses corrupt/newer config or read-only
storage. A failed save means the choice was not remembered; use the explicit
directory for the current conversion. Normal conversion, preview and helper load
never save settings; interactive setup saves only after affirmative consent.
Setup is the simpler user-facing route to the same shared resolver and save API.

Only the app directory itself is an app-local layout; `tools\ffmpeg\bin` is not
searched. PATH discovery uses the first regular `.exe` under absolute PATH
directories, excluding implicit current-directory lookup and blank/relative entries.
An absolute PATH entry remains valid when it is also the working directory. It never
executes aliases, functions or shell wrappers. Separate PATH directories remain
supported; differing tool build IDs produce a warning. No source folders or whole
drives are searched for tools.

Version and encoder capability checks each have a 15-second deadline. A timeout
reports the operation, executable, elapsed time and whether process release was
proved. Media probes use the deadline above; encoding and full audio decode have
no short fixed runtime ceiling. Pipe completion after child exit is bounded
separately at five seconds, with bounded teardown. An unproved release retains
the clearly incomplete working file and reports why.

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
| `130` | `Cancelled`: Q or EOF during interactive choices, or controlled Ctrl+C after metadata prompts in a supported Windows console. |

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
the console's final result too. Preview has no records, including on failure.
Before a conversion run exists, startup failures attempt a bounded PRIVATE JSON
record under `%LOCALAPPDATA%\AudioFileForPhone\Diagnostics`, then a unique TEMP
fallback. If storage fails, the original console cause remains visible.

Double-click `Check-AudioFileForPhone.bat` for an environment check, or use an
allowed PowerShell host in the application folder:

```powershell
.\Check-AudioFileForPhone.ps1 -FfmpegDirectory 'C:\ffmpeg\bin'
.\Check-AudioFileForPhone.ps1 -FfmpegDirectory 'C:\ffmpeg\bin' -SelfTest
.\Check-AudioFileForPhone.ps1 -DiagnosticPath 'C:\Reports\failure.json' -ExportPath 'C:\Reports\support.txt'
```

The default check reads app/config identity and executes the selected trusted
tools for bounded version/capability checks. It reads no audio, creates no
persistent application files even on failure, and uses no network. Remote
config/tool paths are refused; remote PATH entries are skipped. PowerShell/.NET
may use transient compiler files. `-ConfigPath` selects a portable config.
`-SelfTest` explicitly creates a short synthetic fixture in a uniquely owned TEMP
tree, then uses production planning, conversion and validation. It verifies the
source hash and cleans only that tree after ownership and process-release proof.
`SELF_TEST_UNAVAILABLE` means fixture support is unavailable; ordinary conversion
may still work. Uncertain release or cleanup retains the exact named tiny tree.

`-DiagnosticPath` reviews an existing bounded private startup record without
executing tools. The displayed support report uses a field whitelist and path
tokens; native free text, source names/tags, arguments and PATH are omitted.
`-ExportPath` explicitly saves that reviewable text to a new file in an existing
directory. It never overwrites or uploads. Review it before sharing: redaction
does not guarantee anonymity. See [diagnostic stages and repair guidance](SUPPORT.md#environment-check-and-support-export).

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
package is not release acceptance: exact extraction, automated Windows/launcher
checks and exact-byte publication authority remain required by the active
[repair charter](docs/codex-v1.0.1/CHARTER.md). No owner or phone test is required
for this repair. The clean repaired user-package build belongs to R2.
