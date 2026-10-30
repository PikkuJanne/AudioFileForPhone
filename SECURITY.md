# Dependency and package security

AudioFileForPhone runs locally with the permissions of the user who starts it.
It has no telemetry, account, automatic upload or updater. Only the separate
user-invoked setup helper offers a pinned download after affirmative consent.
FFmpeg and ffprobe run as external processes. Review the application source and
the origin of those executables before running them; media parsing is performed
by the supplied FFmpeg build. Logs and run manifests contain local paths,
filenames and metadata. Follow [SUPPORT.md](SUPPORT.md#reporting-a-problem) before
sharing diagnostics.

## Supplying FFmpeg and ffprobe

1. Start at the [FFmpeg download page](https://ffmpeg.org/download.html). FFmpeg
   publishes source code and links separate Windows binary publishers, including
   [Gyan](https://www.gyan.dev/ffmpeg/builds/) and
   [BtbN](https://github.com/BtbN/FFmpeg-Builds). A Windows binary from either
   publisher is that publisher's build, not an FFmpeg-project signed executable.
2. Obtain a specific build manually from the publisher you trust. Retain its
   release identity, download URL, archive checksum and included license/build
   notices. Compare the archive's SHA-256 with the publisher's reference before
   extracting or running it. FFmpeg source-release signatures described on its
   download page authenticate the corresponding source archive; they do not
   authenticate a separately compiled Windows executable.
3. Keep `ffmpeg.exe` and `ffprobe.exe` from the same reviewed build together. The
   recorded automated baseline uses Gyan release essentials 9.0.2; this is tested
   provenance, not a runtime version pin or a guarantee for every other build.
   Available decoders, encoders and image support vary with build configuration.
   The app requires `libmp3lame`; actual inputs and covers must also be supported
   by the chosen build. Review the publisher's update/security information when
   replacing it. New repair verification uses Codex-run synthetic media.
4. Select a trusted installation with `-FfmpegDirectory`, deliberately save a
   choice using the separate setup entry, place a complete pair beside the application,
   or use a trusted installation already in your shell's `PATH`, in that order.
   For shared builds retain their required DLLs according to the publisher's
   instructions. Invalid explicit/saved choices and incomplete app-local pairs
   stop preflight. PATH searches absolute directories only, without implicit
   current-directory lookup. An absolute PATH entry still works when it is the
   working directory. Inspect both actual resolved paths and the printed origin.

The separate `Setup-AudioFileForPhone.ps1` and BAT can select existing tools or
offer optional managed setup. Conversion never downloads tools. Its download choice points to separate
setup, where the reviewed provider/build, size, destination, hash and license/source
references are displayed before affirmative consent. Unattended setup requires
both `-Download` and `-Consent`; remembering is a separate deliberate choice.
The exact ZIP is pinned in `tools/ffmpeg-download.json`; HTTPS uses normal
certificate validation, scoped redirects and transfer deadlines/size limits.
Integrity is checked before archive inspection, extraction or execution. Owned
staging rejects unsafe/colliding paths, links and excessive entries/expanded sizes.
All vendor files/notices and provenance are retained. Startup/capability checks
and a synthetic encode/probe/decode must pass before selection. Failure preserves
the previous selection; setup never replaces a user-managed installation. Future
runs never update the pinned build automatically.
Selecting a directory validates and executes only that explicitly chosen pair,
then prints their SHA-256 hashes. Hashes identify bytes, and version/capability
responses show what those programs report; neither establishes vendor
authenticity. Review the build before selecting it. Selecting an untrusted audio
source folder never authorizes executing programs found there.

Saving requires affirmative interactive consent or explicit `-Remember` on the
setup command. Config holds only the deliberate tool location, uses the shared
bounded atomic writer, and preserves corrupt/newer settings on failure. It never
changes PATH, registry, profiles or persistent execution policy. The repaired
setup BAT uses one built-in x64 Windows PowerShell 5.1 STA process with `-NoProfile`
and a process-only `Bypass` request for this trusted unsigned personal app.
MachinePolicy, UserPolicy and application control remain authoritative. CMD
retains the real failure and exit code and pauses without another host retry. Ordinary
noninteractive conversion and preview never run setup or save settings.

After reviewing the app/helper and trusting the chosen vendor files, run these
commands from `app/` in the extracted release, or the repository root in a source
checkout, to inspect the exact selected files.
Resolution executes bounded version/capability queries; the final three commands
also execute the selected tools directly:

```powershell
. .\AudioFileForPhone.Helpers.ps1
$selection = Resolve-AudioToolSelection -ScriptDirectory $PWD.Path
$ffmpegPath = $selection.Ffmpeg.Path
$ffprobePath = $selection.Ffprobe.Path
$ffmpegPath
$ffprobePath
Get-FileHash -LiteralPath $ffmpegPath -Algorithm SHA256
Get-FileHash -LiteralPath $ffprobePath -Algorithm SHA256
Get-AuthenticodeSignature -LiteralPath $ffmpegPath
Get-AuthenticodeSignature -LiteralPath $ffprobePath
& $ffmpegPath -version
& $ffprobePath -version
& $ffmpegPath -hide_banner -encoders
```

Conversion startup reports the selection origin and verifies `libmp3lame` before
reserving a run. Setup displays selected paths/hashes; the log/manifest retain
tool paths and version responses. Their build hashes identify the app scripts,
not the vendor binaries.
Startup does not verify vendor checksums or signatures, enforce a minimum FFmpeg
version, or certify authenticity or absence of vulnerabilities. Preview performs
no tool queries. SHA-256 identifies bytes against a trusted reference; a matching
checksum alone does not establish who published them.

## Licenses and signing

The application is under the [MIT License](LICENSE). FFmpeg and its compiled-in
libraries have separate terms. FFmpeg's [license documentation](https://ffmpeg.org/legal.html)
describes LGPL licensing and optional GPL components; the effective license
depends on the build. Gyan describes its FFmpeg builds as GPLv3 on its
[build page](https://www.gyan.dev/ffmpeg/builds/). Keep and read
the notices for the exact build you obtain. The app's MIT license does not
relicense those binaries, and the distributable excludes them.

The app's PowerShell scripts currently have no Authenticode publisher signature.
Package generation records actual script signature status. Neither the ZIP,
external manifest nor checksums acquire a publisher signature from packaging.
See [unsigned scripts and execution policy](SUPPORT.md#unsigned-scripts-and-execution-policy)
for read-only checks, the repaired BATs' process-only Bypass request and direct
invocation. This request does not sign files, remove download marks or change
saved execution policy. Do not weaken enforced organization policy or application
control. The conversion BAT calls the converter directly in one built-in x64
Windows PowerShell 5.1 STA process with `-NoProfile`; direct PowerShell 7 calls
remain available. Final status and pause live in CMD, including pre-entry errors;
forced window closure can still discard visible output.

## Package provenance

The normal public [v1.0.2 release](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.2)
provides the [application ZIP](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.2/AudioFileForPhone-v1.0.2.zip),
external manifest and checksums. Its tag remains on tested source
`83a5713cacfbc330f309f48d8377cb5be11ba3a6`; ZIP SHA256 is
`012b82fbb82565ed5aff0d8444f0640c3dfb049e0f4a355ea2464c484219abad`.
The public assets remain the exact frozen bytes. Later repository documentation
does not rebuild them or move the tag. Existing v1.0.0/v1.0.1 tags/assets remain unchanged.

An independent public download passed 12 groups/20 synthetic outputs in total
across Windows PowerShell 5.1 and PowerShell 7 on Windows 11 Pro 26300.9711 x64,
including full decode/source integrity and five native BAT cases. Windows 10 and
genuine Explorer conversion remain unverified owner-accepted release exceptions,
not passes. Owner testing required: none.

The runtime builder uses an 18-file intermediate core allowlist. The final
user-package builder selects 17 members, exposing only `AudioFileForPhone.bat`,
the unchanged `AudioFileForPhone.ico`, `README.txt` and `app/`. Required helpers,
optional setup, detailed documentation and license remain under `app/`. See
[distribution layout and provenance](docs/DISTRIBUTION.md). FFmpeg/ffprobe
binaries, vendor DLLs, tests, generated audio, logs, caches, posters, Git data and
Codex handoff/evidence are excluded.

The ZIP is built from a supplied clean detached source commit. The external
`release-manifest.json` records that commit, the helper-derived app version,
target tag, ZIP bytes/hash, each member's bytes/hash, signing observations and
supplied dependency/test evidence identities. `SHA256SUMS.txt` hashes the ZIP and
external manifest only. The manifest is outside the ZIP and the checksum file
does not hash itself. These records describe a build; they do not grant release
approval or establish tests that were never run. The builder verifies the supplied
tool hashes and version responses; test references/statuses are caller-supplied
attestations and must describe retained real reports. Before supplying them, the
operator must inspect the original report bytes, passing status and tested commit
and verify the report SHA-256. The builder validates the supplied schema/commit
and carries those references; it does not open the referenced reports or execute
their tests. Approved exact asset bytes must be verified separately under the
release runbook.

The published manifest retains its build-time `corrective_release_candidate`
kind and `publication_authorized: false`. Those fields describe the frozen build;
the later exact-byte owner authorization and actual public release are recorded
separately in the release evidence. The manifest/checksum bytes were not rewritten
after publication to update their status.

The user-distribution manifest additionally identifies its package revision,
original runtime ZIP and source-to-archive mapping. Generated entry points and
guide have their own hashes and packaging-tool provenance; they are not claimed
to be original source blobs. New layout tests bind the actual distributed ZIP.

Repository CI downloads dependencies only into its isolated test environment,
using reviewed fixed archives and complete hashed inventories. This CI provisioning
is separate from consent-based user setup and makes no machine-wide install. See the repository's
[CI security boundary](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/CI_SECURITY.md)
for its read-only permissions, dependency pins and JSON-only uploads. CI is
supplementary to recorded local Windows acceptance.
