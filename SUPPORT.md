# Support and troubleshooting

AudioFileForPhone targets Windows 11 with Windows PowerShell 5.1 and PowerShell 7.
It is unsigned and needs separately supplied FFmpeg/ffprobe for conversion.
Read [README.md](README.md) for setup, options and output behavior.

## Tested boundaries

Recorded checks use short synthetic media and isolated destinations, including
MP3/M4A and OGG Vorbis/Opus, naming/path boundaries, metadata/covers, full decode,
failure results, cancellation components and local record persistence.

| Environment or workflow | Evidence boundary |
| --- | --- |
| Active Windows 11 Pro 26300.9457 | Local synthetic regression runs on Windows PowerShell 5.1.26100.9444 and PowerShell 7.6.5. |
| Hosted Windows Server 2025, image `win25-vs2026` / `20260925.250.1` | Supplementary CI on Windows PowerShell 5.1.26100.33438 and PowerShell 7.6.6 with fixed FFmpeg/ffprobe 9.0.2 essentials. This is separate from Windows 11 acceptance. |
| Physical console Ctrl+C | Owner-confirmed historical checks on Windows PowerShell 5.1 and Store PowerShell 7.6.6; not a new manual claim for every later change. |
| Music-folder default | Configured-folder resolver and dedicated owned generated-input smoke checks; no real network-redirected Music acceptance. Ordinary personal Music was not used as disposable test data. |
| Samsung S24, One UI 8.5, AIMP v4.31.1747, USB cable | Named owner acceptance on the three T21 assets: long playback/seeking/duration, resume, tags, supplied blue cover and ordering work. Chapters unavailable; navigation not tested. [T21 evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T21.md). |
| Explorer folder drop and PS5.1 STA picker | Named owner folder-on-BAT observation reached "Completed with failures"; selected BAT shell, raw exit and output path were not captured. Actual PS5.1 picker outputs were independently verified. Current PS7 picker, physical Cancel and fallback remain unobserved. [T20 evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/evidence/T20.md). |
| Other phone/player or USB/MTP configurations and NAS/UNC | Claims remain limited to recorded evidence, without a universal compatibility guarantee. Automated launcher checks do not establish unobserved Explorer/phone behavior. |
| Exact release ZIP | Package verification is recorded separately in the repository's [release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md); source tests alone do not establish acceptance of downloaded bytes. |

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

Inspect policy in the shell you intend to use; these commands only read it:

```powershell
Get-ExecutionPolicy
Get-ExecutionPolicy -List
Get-AuthenticodeSignature -LiteralPath '.\AudioFileForPhone.ps1'
Get-AuthenticodeSignature -LiteralPath '.\AudioFileForPhone.Helpers.ps1'
```

The scripts have no Authenticode publisher signature. A SHA-256 comparison checks
bytes against a trusted reference; a checksum alone does not authenticate the
publisher. Review the source and the origin of both app and vendor binaries.

On a personal machine where you are permitted to run reviewed unsigned scripts,
direct invocation can request `RemoteSigned` for that child process:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio'
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -OutputParent '.\Phone audio'
```

Use the command for the installed shell. The request does not persistently change
machine/user policy and does not override Group Policy. If your effective policy
requires signatures or your organization blocks unsigned scripts, ask its
administrator for an approved route. Do not weaken that policy or endpoint
protection. See [Microsoft's execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).

If `RemoteSigned` blocks reviewed files solely because they carry an Internet
download mark, and your personal-machine policy permits unblocking, unblock only
the exact files you have inspected:

```powershell
Unblock-File -LiteralPath '.\AudioFileForPhone.ps1'
Unblock-File -LiteralPath '.\AudioFileForPhone.Helpers.ps1'
```

This removes each file's download mark; it does not sign the file or change
execution policy. Do not recursively unblock a download directory. See
[Microsoft's Unblock-File documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file).

The existing BAT launcher explicitly supplies process-scoped
`-ExecutionPolicy Bypass`, suppressing ordinary policy blocking/warnings in that
child session. It does not override Group Policy. Choose the direct invocation
above when you want policy checks; the BAT is not an approved way around an
enforced policy.

## Common problems

| Symptom | What to check |
| --- | --- |
| Script cannot run or window closes | Run from an existing PowerShell window to keep diagnostics visible; inspect execution policy as above. Keep the helper beside the entry script. |
| FFmpeg/ffprobe missing or capability check fails | Add `-FfmpegDirectory 'D:\Trusted tools\bin'` with both trusted executables to the conversion command. Selection order is explicit, saved config, complete app-local pair, then PATH. Check the printed origin, versions/paths and `libmp3lame` error. |
| Saved tool folder is stale, config is corrupt/newer, or saving fails | Use `-FfmpegDirectory` for the current run without changing config. See README for `-ConfigPath` and the deliberate save helper. Move a reviewed bad config aside to restore ordinary discovery; the app will not silently overwrite it or fall back. Read-only storage leaves the previous file intact and means the choice was not remembered. |
| Invalid/unreadable input or no supported files | Select an existing folder below the drive/share root, not a file, shortcut or generated output. Only MP3/M4A/OGG extensions are scanned. |
| Permission, junction or scan error | Choose accessible ordinary filesystem paths. Selected paths with reparse-point ancestors are rejected; descendant reparse points are excluded. An inaccessible subtree stops the scan. Preview does not test destination writability. |
| Long/incompatible preserved path | Use a shallower input selection or shorter OutputParent. Folder names are kept; MaxBaseLength cannot shorten folders. File/working paths must be under 260 UTF-16 units and created directories under 248. |
| Cover rejected or outputs grow unexpectedly | Use a readable JPEG/PNG. Invalid explicit covers stop preflight. Cover dimensions are preserved and artwork is embedded in every output; prepare a smaller image yourself if needed. Source artwork is otherwise dropped. |
| Cover picker unavailable | Use the BAT's STA launch only where its policy request is acceptable, or start the installed shell with `-Sta` and `-Interactive`. Passing `-CoverPath` avoids the picker. |
| Some files fail | Inspect each Failed manifest row and bounded native error in the log. Unsupported source media, nonpositive/unknown duration or a rate incompatible with the source can fail. Other valid files continue; exit 2 reports batch failures. |
| Progress reaches 100 percent but files failed | Batch progress means processed, including failed files. Encoding progress precedes validation/publication. Use the final counts and exit code. |
| Required log/manifest write fails | The run stops with exit 1 while preserving actual published outputs/counts; cancellation stays 130. The last durable manifest may be incomplete. Keep the console result and reported root cause. |
| Files, tags, cover or chapters behave differently on a phone | Compare the converted count and output files locally first, then test transfer/playback in your player. Recorded phone acceptance is limited to the S24/AIMP configuration above. Chapter navigation/resume and every source-specific tag are not guaranteed; M4B is unsupported. |

For a direct interactive launch with policy checks, choose the installed shell:

```powershell
powershell.exe -NoProfile -Sta -ExecutionPolicy RemoteSigned -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -Interactive
pwsh -NoProfile -Sta -ExecutionPolicy RemoteSigned -File .\AudioFileForPhone.ps1 -InputFolder '.\Podcasts' -Interactive
```

The BAT accepts exactly one folder, forwards the child code and pauses. When
calling it from a shell, quote the path and account for the caller's expansion
rules. The wrapper cannot restore `%NAME%`, `!NAME!` or other characters already
changed by the caller or an extra `CALL` expansion pass.

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
