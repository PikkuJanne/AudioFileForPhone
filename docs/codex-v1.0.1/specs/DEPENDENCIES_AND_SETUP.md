# Dependency resolution and setup contract

## Public interface (selection spelling frozen at S04)

Add `-FfmpegDirectory <directory>` to the existing script. It selects a pair of
executables and does not save anything unless explicitly requested by setup.
Keep existing invocations valid. Add a separate Setup-AudioFileForPhone.ps1 plus
simple BAT entry point. Keep a single resolver and validator shared by setup,
conversion, environment check and self-test; do not build parallel incompatible
implementations. Names may be adjusted once with documentation and test updates.

S04 freezes `-FfmpegDirectory` and `-ConfigPath <JSON file>` on conversion.
ConfigPath overrides the Windows LocalApplicationData API default; relative
explicit paths use the current PowerShell location. The shared functions-only
helper exposes Get-AudioConfigPath, Read-AudioToolConfig,
Resolve-AudioToolSelection and deliberate Save-AudioToolSelection. S04 adds no
setup entry point or prompts; those remain S05. Conversion never saves choices.
Config input/output is limited to 64 KiB and schema 1; other schema-1 fields are
preserved on a deliberate save, while corrupt/unknown schemas are refused.
An explicit directory bypasses config contents for that run, allowing recovery
without rewriting the bad file. A failed save throws with not-remembered guidance.

The retained app-local convention is a complete pair directly beside the script;
an incomplete pair fails rather than mixing local and PATH tools. The nested
tools/ffmpeg/bin layout is deliberately unsupported. PATH uses absolute entries
only and excludes implicit current-directory candidates, blank/relative entries,
aliases, functions and wrappers. An explicitly absolute PATH directory remains
eligible when it equals the working directory; separate installed PATH directories
remain supported.

## Deterministic resolution

Precedence: explicit FfmpegDirectory -> saved user selection -> application-local
pair -> PATH. Document any existing app-local fallback conventions retained.

Explicit/saved selections must resolve to a filesystem directory with both regular
files. Use literal paths and validate the chosen pair before use. Do not search
whole drives, execute a found file automatically, select the newest by filename,
or hardcode C:\ffmpeg. App-local includes a documented `tools\ffmpeg\bin` layout
only if deliberately supported and tested. Relative app-local paths are based on
the script directory, never the shell/shortcut working directory.

An invalid explicit directory is an error, never silently ignored. A stale saved
selection produces repair guidance; interactive mode can offer reselection, while
noninteractive mode returns a stable error. No invisible fallback to another build.
Never construct mixed explicit/local pairs from unrelated directories. Existing
PATH discovery may find a separately installed pair: preserve valid legacy setups
where capabilities pass, disclose both paths and warn about differing build IDs
rather than requiring identical version text. Do not execute aliases/functions or
shell wrappers as ffmpeg.exe. Preserve working user-managed builds.

Validate startup with bounded version and libmp3lame checks. Record path, build,
architecture where detectable, and discovery origin. Numeric or Git-style version
strings are evidence, not a hardcoded whitelist. Hash selected binaries in setup,
diagnostics/acceptance and changed-identity checks; do not rehash 200 MB per audio
file. Capabilities/versions are not proof of publisher authenticity.

## Minimal persisted state

Default `%LOCALAPPDATA%\AudioFileForPhone\config.json`, UTF-8 JSON with schema_version
and ffmpeg_directory. Store only a deliberate tool location (and explanatory build
identity if useful), not the owner's source folder, metadata tags, passwords or
entire PATH. No registry/PATH/profile mutation. Resolve the user folder via Windows
APIs. Offer an explicit config-location option for owned test environments and
portable use, with a documented precedence. This must be a legitimate user option,
not a hidden production test bypass. Without it, use the user-local default.

Writes are atomic, bounded in size, validate schema/path/value types, and fail with
actionable errors. Unknown schema/newer format is not silently replaced. Do not
execute config content or deserialize arbitrary objects. A stale/corrupt/read-only
config is repairable without editing PowerShell. Choosing a path may continue only
for the current run when persistence fails, but clearly say it was not remembered.
No settings writes during preview, environment checks or default script load.

## First-run existing/manual setup (required)

Missing tools in interactive mode: explain what is missing, then offer select an
existing folder, manual instructions, optional setup download, or cancel. Selection
accepts the pair's bin directory; optionally recognize exactly one documented bin
child within an explicitly selected installation root. No unbounded recursion.
Clearly show which directory is accepted and ask whether to remember it. Use
Windows dialogs already available where appropriate, with plain typed-path fallback
when dialogs fail. No new GUI framework. User cancel is not an infinite retry loop.

Noninteractive conversion never prompts/downloads. It returns a stable error with
the exact existing-tool setup command. No FFmpeg is executed merely because an
untrusted source audio folder happens to contain an exe.

## Separate optional managed setup download (required implementation, optional use)

Implement in setup, not the conversion code path. Present provider/build, transfer
size, destination and trust/license notes before affirmative consent. A command-line
unattended setup requires an explicit download/consent parameter; absence is refusal,
not assumed approval. Network errors, no internet and declined consent leave manual
setup available and leave a previous valid selection unchanged.

At S06 select one exact vendor ZIP build for Windows x64 from a primary source and
record its URL, SHA256, archive size bound, extraction size/count bounds, source/
license reference and build identity in a reviewed manifest. Prefer a versioned
URL: never resolve `latest` at user runtime. Do not invent a SHA or silently refresh
a pin after mismatch. CI test pins are not permanent runtime version restrictions.
Reference release builds provide repeatability; Gyan also recommends Git-master
builds, so do not claim all nightly builds are untrustworthy or unstable [P3].

Use HTTPS with normal certificate validation, bounded connect/download time and
size, explicit cancellation, and scoped allowed redirect hosts. Prefer ZIP to avoid
installing 7-Zip as a second prerequisite. Validate integrity BEFORE extraction or
execution. Reject traversal (`..`, rooted/UNC paths), alternate data streams,
symlinks/reparse entries, unsafe components, duplicate/case-colliding entries,
excessive counts or expanded sizes. Safe canonical-path containment checks must
include a path separator boundary. Test archive failures rather than assume a
standard ExtractToDirectory call meets this policy by itself.

Stage under a uniquely owned directory within user-local application storage. Keep
vendor notices and provenance intact. Do not redistribute vendor executables in this
repository or app release; retrieve directly from the pinned publisher location.
Check exact selected build notices and source availability; an application's MIT
license is not the vendor's license [P4]. Do not strip vendor files to dodge notices.
Validate both tools and a synthetic smoke conversion before atomically selecting
the install. Do not replace arbitrary C:\ffmpeg or another app's binaries. On failure
remove only proved-owned incomplete staging. A valid previous selection survives.
Use versioned private dependency directories; no silent updating on future runs.

## Required tests

No tools; one tool missing; outside PATH; app-local; explicit override; valid saved
config; stale/corrupt/new-schema config; unwritable config; fresh process reads saved
selection; directory spaces/brackets/Unicode; duplicate PATH copies; startup failure;
missing DLL/wrong executable architecture evidence; mismatched pair warning; no
execution from input-folder/extraneous current-directory candidates; offline setup;
decline; hash mismatch; bad ZIP; extraction limits; cancelled install; repeat setup;
no persistent environment changes; no successful-selection mutation on failed setup.
