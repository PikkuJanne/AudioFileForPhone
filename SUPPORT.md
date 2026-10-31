# Support and troubleshooting

v1.0.5 makes one fresh-process recovery attempt after a recognized native media
worker crash and confirmed process/handle release. An encoder retry uses a new
owned temporary file; a validator retry reads the same completed output without
re-encoding it. A repeated crash is reported as an item failure. Ordinary media
errors and validation mismatches are not retried, and unvalidated files are never
published. The app keeps the selected FFmpeg installation and never downloads or
replaces tools during conversion. The native crash's underlying cause is unproven.

AudioFileForPhone targets Windows 10 22H2 x64 and Windows 11 x64 with Windows
PowerShell 5.1 and PowerShell 7. The published
[v1.0.5 application ZIP](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.5/AudioFileForPhone-v1.0.5.zip)
includes the batch-worker, direct-launch and clean-package repairs. Earlier release
tags and bytes are preserved. Windows 10 and genuine Explorer conversion remain
unverified owner-accepted release exceptions (`OWNER_WAIVED`, `NOT_RUN`), not test
passes. Actual coverage and gaps are in the
[active release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1.0.1/STATUS.md).
Owner testing required: none. Codex performs all new repair verification; no
owner diagnostic run, phone check or acceptance kit is required.
It is unsigned and needs separately supplied FFmpeg/ffprobe for conversion.
Read [README.md](README.md) for setup, options and output behavior.

## Tested boundaries

Recorded checks use short synthetic media and isolated destinations, including
MP3/M4A and OGG Vorbis/Opus, naming/path boundaries, metadata/covers, full decode,
failure results, cancellation components and local record persistence.

| Environment or workflow | Evidence boundary |
| --- | --- |
| Historical Windows 11 Pro 26300.9457 | Local synthetic regression runs on Windows PowerShell 5.1.26100.9444 and PowerShell 7.6.5. |
| v1.0.2 client, Windows 11 Pro 26H2 26300.9711 x64 | Automated isolated verification on Windows PowerShell 5.1.26100.9711 and PowerShell 7.6.5, including a 31-M4A batch and 30-minute audio/seek checks per host. Controlled native BAT success/partial failure uses an owned default Music folder. |
| v1.0.2 public-download smoke | The independently downloaded exact public ZIP passed 12 groups and 20 real outputs in total across PS5.1/PS7, with full decode/source integrity and five native BAT cases. This does not establish genuine Explorer conversion. |
| Windows 10 22H2 x64, PS5.1/PS7 | NOT_RUN and unverified. The owner accepted this release exception; Server CI does not supply a Windows 10 pass. |
| Genuine Explorer conversion through the current BAT/shortcut | NOT_RUN and unverified; owner-accepted release exception. An inert genuine shortcut drop proved literal argument/cwd delivery but failed environment isolation. Controlled native BAT conversion is separate evidence. |
| Historical v1.0.1 development, Windows 11 Pro 26H2 26300.9711 x64 | S03/S04 synthetic source tests on Windows PowerShell 5.1.26100.9711 and PowerShell 7.6.5. These source tests do not establish Windows 10 or later exact-package results; see the retained evidence. |
| Historical hosted Windows Server 2025, image `win25-vs2026` / `20260925.250.1` | Supplementary CI on Windows PowerShell 5.1.26100.33438 and PowerShell 7.6.6 with fixed FFmpeg/ffprobe 9.0.2 essentials. Server CI is separate from client acceptance. |
| Physical console Ctrl+C | Owner-confirmed historical checks on Windows PowerShell 5.1 and Store PowerShell 7.6.6; not a new manual claim for every later change. |
| Music-folder default | Configured-folder resolver and dedicated owned generated-input smoke checks; no real network-redirected Music acceptance. Ordinary personal Music was not used as disposable test data. |
| Samsung S24, One UI 8.5, AIMP v4.31.1747, USB cable | Named owner acceptance on the three T21 assets: long playback/seeking/duration, resume, tags, supplied blue cover and ordering work. Chapters unavailable; navigation not tested. [T21 evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T21.md). |
| Historical Explorer folder drop and PS5.1 STA picker | Named owner folder-on-BAT observation reached "Completed with failures"; selected BAT shell, raw exit and output path were not captured. Actual PS5.1 picker outputs were independently verified. Current PS7 picker, physical Cancel and fallback remain unobserved. [T20 evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T20.md). |
| Other phone/player or USB/MTP configurations and NAS/UNC | Claims remain limited to recorded evidence, without a universal compatibility guarantee. Automated launcher checks do not establish unobserved Explorer/phone behavior. |
| Exact v1.0.2 release ZIP | Public bytes match the frozen tested ZIP SHA256 `012b82fbb82565ed5aff0d8444f0640c3dfb049e0f4a355ea2464c484219abad`. Current package/public verification is in the [release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1.0.1/STATUS.md); source tests alone do not establish public-byte acceptance. |
| Recovery BAT, owner report of 2026-10-30 | The owner reports a successful launch and working audio. This is owner-reported recovery, not independent verification of every file, host, shortcut or repaired package. No repeat owner test is requested. |

Local regression history also uses an existing Gyan FFmpeg build dated
2026-10-08. These tested builds do not establish compatibility with every FFmpeg
build or source codec. Startup verifies executable versions and `libmp3lame`;
actual media/cover support is determined during probing, encoding and validation.
Tests do not certify arbitrary corrupt media or every filesystem/host environment.

The support claims below are bounded by repository tests and recorded evidence;
they do not extend the recorded device scope or establish exact package acceptance.

| Behavior | Tests and evidence |
| --- | --- |
| Preview and matching relative plans without writes/prompts | [Test-Preview.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-Preview.ps1), [T12](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T12.md). |
| Metadata, explicit covers and chapter-field limits | [Test-Metadata.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-Metadata.ps1), [T15](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T15.md). Chapter fields are inspected; phone behavior is limited to the S24/AIMP acceptance above, where chapter navigation was unavailable and untested. |
| Discovery/reparse exclusions and naming/path budgets | [Test-Discovery.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-Discovery.ps1), [Test-NamingPlan.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-NamingPlan.ps1), [T06](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T06.md), [T07](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T07.md). |
| Validation/publication, results and launcher exit transport | [Test-TransactionalOutput.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-TransactionalOutput.ps1), [Test-ScriptResults.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-ScriptResults.ps1), [Test-LauncherResults.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-LauncherResults.ps1), [T09](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T09.md), [T10](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T10.md). |
| Controlled cancellation and forced-host cleanup limits | [Test-Cancellation.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-Cancellation.ps1), [T11](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T11.md); physical Ctrl+C evidence remains historical as stated above. |
| Local diagnostics, manifest counts and persistence failure | [Test-Diagnostics.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-Diagnostics.ps1), [T14](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T14.md). |
| Comment-based help, executable examples and runtime version propagation | [Test-HelpVersion.ps1](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/tests/Test-HelpVersion.ps1); the T18 checkpoint records its actual results. |
| Local regression and supplementary hosted checks | [T16](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T16.md), [T17](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T17.md), with the exact environment boundaries above. |

## Unsigned scripts and execution policy

In the extracted release, run the PS1 commands below from `app/`; source-checkout
commands run from the repository root. The root BAT remains the normal folder-drop entry.

The scripts have no Authenticode publisher signature. Review the source and
origin of the app and FFmpeg pair. A checksum identifies bytes against a trusted
reference; it does not authenticate the publisher. Optional read-only checks are:

```powershell
Get-ExecutionPolicy
Get-ExecutionPolicy -List
Get-AuthenticodeSignature -LiteralPath '.\AudioFileForPhone.ps1'
Get-AuthenticodeSignature -LiteralPath '.\AudioFileForPhone.Helpers.ps1'
Get-AuthenticodeSignature -LiteralPath '.\Setup-AudioFileForPhone.ps1'
```

For this trusted unsigned personal app, the repaired conversion and setup BATs
request `-ExecutionPolicy Bypass` for their one child process. This permits
reviewed unsigned Internet-marked app files without removing their download
marks. `RemoteSigned` can reject such files before any PS1 error handler runs.
The request does not change saved execution policy, PATH, profiles or registry.
MachinePolicy, UserPolicy and application control remain authoritative. A refusal
stays visible in CMD, with no alternate-engine retry or script-text evaluation.
See [Microsoft's execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).

On a personal machine where this request is permitted, a direct parameter-based
launch in the installed shell can use the same process-only policy:

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio'
pwsh -NoProfile -Sta -ExecutionPolicy Bypass -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio'
```

If managed policy refuses these unsigned scripts, an administrator-approved route
is required. Do not weaken policy or endpoint protection, switch engines to
escape a denial, or remove download marks as a workaround. The repaired BATs use
one built-in x64 Windows PowerShell 5.1 STA process with `-NoProfile`. CMD owns
their final status and pause even when the host, runtime or parsing fails.

The standalone setup BAT accepts no arguments and uses the same launch policy.
For explicit setup options, direct calls remain available:

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\Setup-AudioFileForPhone.ps1
pwsh -NoProfile -Sta -ExecutionPolicy Bypass -File .\Setup-AudioFileForPhone.ps1
```

`Check-AudioFileForPhone.bat` remains a separate source-checkout helper requesting
`RemoteSigned`. The application ZIP supplies the check PS1 under `app/`.

## Existing-tool and offline recovery

If the trusted FFmpeg build is already extracted, no internet connection or PATH
edit is needed. Run setup and choose **S**, then select the exact folder containing
both `ffmpeg.exe` and `ffprobe.exe`. If the picker is unavailable, type that folder
without surrounding quotes. Cancel exits 130; an invalid pair exits 1 without
replacing a saved selection. **M** prints manual instructions. In separate setup,
**D** presents the pinned vendor/build, bytes, destination, SHA-256 and source/license
references, then requires **Y** before downloading. In conversion, **D** only prints
the separate setup route; conversion itself never downloads tools.

For a command that never prompts, replace the example directory with your reviewed
installation and run from the application folder:

```powershell
.\Setup-AudioFileForPhone.ps1 -FfmpegDirectory 'D:\Trusted tools\bin' -Remember -NonInteractive
```

Use `-ConfigPath '.\portable-config.json'` on both setup and conversion when using
a portable config. Omit `-Remember` to inspect/validate a pair without saving; then
pass the same explicit directory to conversion:

```powershell
.\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -FfmpegDirectory 'D:\Trusted tools\bin'
```

Setup validates and prints both paths, build responses, detected architectures
and SHA-256 hashes. It does not authenticate the publisher. Keep a shared build's
required DLLs and vendor notices with it. Never select tools merely because an
audio download folder happens to contain executables.

An invalid saved selection stops ordinary discovery. An explicit
`-FfmpegDirectory` bypasses its contents for one run. Corrupt, unsupported-schema,
read-only or locked config is preserved, and a failed save says **not remembered**.
Use a different writable `-ConfigPath`, or review and move only that config file
aside before deliberately saving again. Standalone requested-save failure exits
1 and prints the current-run conversion route; an interactive conversion can
continue with the validated pair without saving. No administrator access or
persistent environment changes are required.

Interactive setup requires a readable console. Redirected input and PowerShell's
`-NonInteractive` host mode cause a bounded error with a direct setup command;
they never assume consent. Ordinary conversion without `-Interactive` returns
the repair action instead of opening setup. `-DryRun` skips setup and dependency
checks entirely.

After successful conversion preflight, the interactive ready menu waits for
Enter (start), M (this batch's metadata) or Q (cancel). Invalid input stops; EOF
cancels, and unavailable/redirected input cannot start a batch. M preserves
explicit parameters and starts conversion after the last choice without another
confirmation. No batch metadata is saved. Use ordinary parameter-based conversion
without `-Interactive` when a console is unavailable. Probing, encoding and
validating are separate states: a 100% encode is still awaiting validation and
publication. Read the final converted/failed counts and exit status.

Optional managed setup uses the exact reviewed Gyan 9.0.2 essentials Windows x64
ZIP in [tools/ffmpeg-download.json](tools/ffmpeg-download.json). Review that manifest
before using `Setup-AudioFileForPhone.ps1 -Download -Consent -Remember -NonInteractive`.
Both switches are required for unattended download; `-Remember` separately permits
saving. `-ManagedRoot` overrides private storage, otherwise `managed` sits beside
the selected config. No global install, user-managed tool replacement or automatic
update occurs. Keep the installed vendor files, GPLv3 notices and AudioFileForPhone-provenance.json
together. The publisher's license/source terms apply independently of this app's MIT
license. Hash mismatch, invalid ZIP, offline/timeout and cancellation stop without
changing the previous config. Retry separate setup or use **S** with an existing
trusted offline build; do not disable verification to accept changed bytes.

## Common problems

| Symptom | What to check |
| --- | --- |
| Script cannot run or window closes | The repaired BAT keeps its own status and pause in CMD, including script-load errors. Read the error above the pause and follow the policy guidance above. Keep required helpers beside the converter. Forced window closure cannot retain the display. |
| FFmpeg/ffprobe missing or capability check fails | Run `Setup-AudioFileForPhone.ps1` and select a trusted pair, or use the explicit existing-tool command above. Selection order remains explicit, saved config, complete app-local pair, then PATH. Check the printed origin, versions/paths and `libmp3lame` error. |
| Saved tool folder is stale, config is corrupt/newer, or saving fails | Follow existing-tool/offline recovery above. `-FfmpegDirectory` works for the current run without changing config. The app preserves a bad/unsupported file and never silently falls back; failed persistence means not remembered. |
| Invalid/unreadable input or no supported files | Select an existing folder below the drive/share root, not a file, shortcut or generated output. Only MP3/M4A/OGG extensions are scanned. |
| Permission, junction or scan error | Choose accessible ordinary filesystem paths. Selected paths with reparse-point ancestors are rejected; descendant reparse points are excluded. An inaccessible subtree stops the scan. Preview does not test destination writability. |
| Long/incompatible preserved path | Use a shallower input selection or shorter OutputParent. Folder names are kept; MaxBaseLength cannot shorten folders. File/working paths must be under 260 UTF-16 units and created directories under 248. |
| Cover rejected or outputs grow unexpectedly | Use a readable JPEG/PNG. Invalid explicit covers stop preflight. Cover dimensions are preserved and artwork is embedded in every output; prepare a smaller image yourself if needed. Source artwork is otherwise dropped. |
| Cover picker unavailable | Use the BAT's STA launch only where its policy request is acceptable, or start the installed shell with `-Sta` and `-Interactive`. Passing `-CoverPath` avoids the picker. |
| Some files fail | Inspect each Failed manifest row and bounded native error in the log. Unsupported source media, nonpositive/unknown duration or a rate incompatible with the source can fail. Other valid files continue; exit 2 reports batch failures. |
| Progress reaches 100 percent but files failed | Batch progress means processed, including failed files. Encoding progress precedes validation/publication. Use the final counts and exit code. |
| Required log/manifest write fails | The run stops with exit 1 while preserving actual published outputs/counts; cancellation stays 130. The last durable manifest may be incomplete. Keep the console result and reported root cause. |
| Files, tags, cover or chapters behave differently on a phone | Recorded phone acceptance is limited to the historical S24/AIMP configuration above. Chapter navigation/resume and every source-specific tag are not guaranteed; M4B is unsupported. No new phone test is required for this repair. |

For a direct interactive launch of the trusted app, choose the installed shell:

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy Bypass -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -Interactive
pwsh -NoProfile -Sta -ExecutionPolicy Bypass -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -Interactive
```

The BAT accepts exactly one folder and preserves the application exit code,
including 0 success, 1 failure, 2 partial failure and 130 cancellation. CMD prints
the result and runs `pause`; redirected EOF can release the pause without a key.
Forced window/process termination cannot guarantee visibility or a final code.
When calling it from a shell, quote the path and account for the caller's
expansion rules. The wrapper cannot restore `%NAME%`, `!NAME!` or other characters
already changed by the caller or an extra `CALL` expansion pass.

The repaired BAT directly calls the converter in the built-in x64 Windows
PowerShell 5.1 STA host. There is no health-probe chain, host override or automatic
retry. Direct PowerShell 7 calls keep the existing parameters, including explicit
`-FfmpegDirectory` and `-ConfigPath`; no PATH edit is needed. Keep
`AudioFileForPhone.Helpers.ps1` and `AudioFileForPhone.Diagnostics.ps1` beside the
converter. Launcher/HostProbe source is retained for historical compatibility and
is unused by this route. Normal encoding and full decode have no short deadline.

## Environment check and support export

In an allowed PowerShell host, run `app/Check-AudioFileForPhone.ps1` for the
download's default environment check. From a source checkout,
`Check-AudioFileForPhone.bat` is also available and accepts no arguments.
With PowerShell open in `app/` (or the repository root for a checkout), the PS1
offers explicit options:

```powershell
.\Check-AudioFileForPhone.ps1 -FfmpegDirectory 'C:\ffmpeg\bin' -ConfigPath '.\portable-config.json'
.\Check-AudioFileForPhone.ps1 -FfmpegDirectory 'C:\ffmpeg\bin' -SelfTest
.\Check-AudioFileForPhone.ps1 -DiagnosticPath 'C:\Reports\failure.json'
.\Check-AudioFileForPhone.ps1 -DiagnosticPath 'C:\Reports\failure.json' -ExportPath 'C:\Reports\support.txt'
```

| Operation | Reads and execution | Writes |
| --- | --- | --- |
| Default check | App/OS/host/config identity; production resolver executes selected trusted binaries for bounded version and encoder queries | None, including failures |
| `-SelfTest` | Production resolver, synthetic MP3 planning/encoding, complete decode and source-hash verification | Only its uniquely owned TEMP fixture tree; cleans after ownership/release proof |
| `-DiagnosticPath` | One bounded existing private record; no tool execution, config lookup or audio access | None |
| `-ExportPath` | Whitelisted support text displayed for review | One new explicit file in an existing directory; no overwrite |
| Converter `-DryRun` | Existing naming/discovery preview; no tool execution or config read | None, including failures |

The check requires local config/tool paths and skips remote PATH entries.
PowerShell/.NET can use transient compiler TEMP files while loading native
interop; the no-write contract covers persistent application data and settings.

No check, self-test or support export downloads or uploads anything. A self-test
fixture limitation is `SELF_TEST_UNAVAILABLE`; it does not establish a broken
ordinary conversion. A timeout stays distinct. Encoding and complete decode
retain their unlimited normal runtime. If release or ownership is uncertain,
the self-test reports the exact retained scope; do not remove unrelated files.
Check/self-test exits are 0 (passed), 1 (failed/unavailable), or 130 (cancelled).
Unobserved physical-console/phone behavior and Windows 10 coverage remain
explicit evidence limits, not owner-testing assignments.

Once converter/setup script entry succeeds, startup failures attempt a PRIVATE JSON report
before an ordinary run exists. The first location is
`%LOCALAPPDATA%\AudioFileForPhone\Diagnostics`; a unique TEMP location is the
fallback. Records are capped at 64 KiB and disclose exact local paths/native
errors. Logging failure never replaces the original console cause. Missing
bootstrap files/hosts can leave console-only evidence when no safe logger can
run. DryRun and the default check never create these records.

| Stable code | Next action |
| --- | --- |
| `HelperMissing` | Restore the complete application package and keep its helpers together. |
| `DependencyMissing` / `DependencyInvalid` | Select a trusted directory containing both tools with the separate setup command. |
| `ConfigInvalid` | Preserve the file; use an explicit `-FfmpegDirectory` or deliberately select another `-ConfigPath` in setup. |
| `HostStartFailed` | Select an allowed x64 PowerShell 7 or Windows PowerShell 5.1 host; respect managed policy. |
| `StartupTimeout` | Retry responsive trusted tools/host; adjust the advanced probe deadline only for slow media probes. |
| `CapabilityMissing` / `IncompatibleAudioSettings` | Review the selected build, requested bitrate and supported channel layout. |
| `OutputUnwritable` | Repair storage/permissions or choose a shorter writable destination. |

The report records a stable stage separately from its code. Export copies a
strict whitelist, replaces paths with tokens and omits raw errors, command
arguments, PATH, source names and metadata. It can review startup records even
when the main converter helper is missing. Review the displayed text before
sharing; redaction reduces identifying content and cannot guarantee anonymity.
Private records are never uploaded or committed automatically.

## Cancellation and incomplete outputs

Controlled Ctrl+C begins after optional metadata prompts in a supported Windows
console. It stops only the current owned child and waits before removing the
exact owned partial, if release/file identity are proved. Completed outputs
remain. The interrupted file stays outside the processed count.

Redirected input, other hosts, preflight/prompts and Ctrl+Break can use
host-defined shutdown behavior. Window closure, forced process termination or
power loss may skip cleanup and leave a native child or a recognizable
`.AudioFileForPhone-<token>.partial` file. A retained-path diagnostic means cleanup
could not be proved. Such files are incomplete, and later runs do not reclaim
them automatically. Before removing an abandoned run yourself, confirm that its
original conversion and child have stopped and that the exact paths are yours.
Do not terminate every FFmpeg process or delete source media to recover a run.

## Reporting a problem

This optional reporting guidance is not a repair acceptance or diagnostic task
for the owner; no new owner testing or log collection is required.

Open a [GitHub issue](https://github.com/PikkuJanne/AudioFileForPhone/issues).
Prefer a short synthetic or nonprivate reproduction. Include:

- App version from dot-sourcing the helper and calling `Get-AudioAppVersion`;
  commit/source or release asset identity if known.
- Windows version/build, `$PSVersionTable.PSVersion`, shell/console type, actual
  FFmpeg/ffprobe paths and versions printed by the app.
- The exact command/options with private paths/tags replaced, supported input
  extension/codec, expected behavior and actual behavior.
- Final result/exit code and counts, the relevant per-file manifest row and a
  short native-error/log excerpt. State if records were unavailable/incomplete.
- For a device issue: phone/OS/player versions, transfer method and what failed
  during playback/seek/chapter/resume. Do not treat an untried step as passing.

Logs and manifests contain exact local paths, filenames and metadata. Redact
names, private content and identifying values before posting; do not upload your
whole log, audio library, credentials or personal media. The app has no automatic
upload or telemetry.
