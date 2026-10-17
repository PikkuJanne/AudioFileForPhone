# Dependency and package security

AudioFileForPhone runs locally with the permissions of the user who starts it.
It has no telemetry, account, automatic upload, production downloader or updater.
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
   replacing it, then test a short nonprivate sample yourself.
4. Select a trusted installation with `-FfmpegDirectory`, deliberately save a
   choice using the README helper, place a complete pair beside the application,
   or use a trusted installation already in your shell's `PATH`, in that order.
   For shared builds retain their required DLLs according to the publisher's
   instructions. Invalid explicit/saved choices and incomplete app-local pairs
   stop preflight. PATH searches absolute directories only, without implicit
   current-directory lookup. An absolute PATH entry still works when it is the
   working directory. Inspect both actual resolved paths and the printed origin.

After reviewing the app/helper and trusting the chosen vendor files, run these
commands from the application folder to inspect the exact selected files.
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

Conversion startup prints both resolved paths and version responses and verifies
`libmp3lame` before reserving a run. Its log/manifest retain tool paths and version
responses; their build hashes identify the app scripts, not the vendor binaries.
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
for read-only checks, the BAT's existing process-scoped Bypass and direct invocation.
Do not weaken an enforced organization policy to run the app.

## Package provenance

The developer builder uses the explicit repository allowlist. It packages only
the entry script, runtime helper, BAT, README, SUPPORT, SECURITY, CHANGELOG and MIT
license at the ZIP root. FFmpeg/ffprobe binaries, vendor DLLs, tests, generated
audio, logs, caches, posters, Git data and Codex handoff/evidence are excluded.

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

Repository CI downloads dependencies only into its isolated test environment,
using reviewed fixed archives and complete hashed inventories. It adds no app
downloader or machine-wide tool setup. See the repository's
[CI security boundary](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/CI_SECURITY.md)
for its read-only permissions, dependency pins and JSON-only uploads. CI is
supplementary to recorded local Windows acceptance.
