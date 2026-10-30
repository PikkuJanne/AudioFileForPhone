# Changelog

## 1.0.2 — published 2026-10-30

[Application ZIP](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.2/AudioFileForPhone-v1.0.2.zip)
and [release notes/checksums](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.2).
The tag and exact assets retain frozen source `83a5713cacfbc330f309f48d8377cb5be11ba3a6`.

- Launch the converter directly from the BAT in built-in x64 Windows PowerShell
  5.1 STA with a documented process-only policy request. CMD owns final status,
  pause and preserved exit, including failures before a script can enter.
- Preserve literal folder transport and optional existing-tool/consent-based
  setup. Store CRLF BAT bytes consistently in Git and application archives.
- Present a small package root: BAT, unchanged ICO, README.txt and app/ with all
  required helpers, setup, support and license files. Omit developer material.
- Keep normal console output concise while retaining warnings/errors, counts,
  output/log locations and detailed local diagnostics.
- Retain default64kbps CBR, supported inputs, metadata/layout and source safety.
- Verify the exact package on Windows 11 Pro 26300.9711 x64 with Windows
  PowerShell 5.1.26100.9711 and PowerShell 7.6.5, including the 31-M4A batch,
  30-minute synthetic audio/seek checks and controlled native BAT conversion.
  An independent public download passed 12 groups, 20 real outputs in total
  across both hosts and five native BAT cases.
- Publish with explicit owner-accepted coverage exceptions: Windows 10 22H2 x64
  and genuine Explorer BAT/shortcut conversion remain unverified (`OWNER_WAIVED`,
  `NOT_RUN`), not passed. No owner testing is required. Published v1.0.0/v1.0.1
  tags and bytes remain unchanged.

## Historical 1.0.1 preparation notes

These notes predate the preserved [v1.0.1 release](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.1).
Their candidate status and old launcher describe that historical preparation.

Unreleased v1.0.1 work: separate consent-based managed setup now pins the exact
Gyan 9.0.2 Windows x64 ZIP. It verifies transfer/integrity/extraction bounds, retains
vendor notices/provenance and validates a synthetic encode/probe/decode before
selection. Conversion never downloads tools. Existing-tool setup and deliberate
remembering remain available offline; no automatic update or global install.

## Historical 1.0.1 candidate notes

- Add a no-write environment-check PS1/BAT, explicit owned synthetic self-test,
  bounded early startup failure records with storage fallback, stable stage/error
  codes and actionable repairs. Offer local whitelist-based support review/export
  without uploads; converter DryRun remains no-write even on failures.
- Plan an exact CBR bitrate and compatible sample rate before encoding, preserving
  ordinary 64 kbps mono/stereo sound. Explicitly downmix supported standard
  multichannel layouts to stereo and reject unknown layouts before encoding.
  Share cover/no-cover audio arguments; record the plan and independently
  validated stream bitrate, sample rate and channels in the run manifest.
- Harden the one-folder BAT route with bounded, policy-respecting host checks,
  exact executable/version/architecture/STA reporting and an explicit host
  override. Prefer usable PowerShell 7, allow pre-entry fallback to Windows
  PowerShell 5.1, and never retry conversion after application entry. Preserve
  literal supplied folder spelling and application exit codes; redirected input
  returns without a mandatory pause. Use process-scoped RemoteSigned.
- Add an Enter/M/Q ready menu after successful preflight/setup: Enter starts with
  defaults, M customizes this batch and Q cancels. Preserve explicit metadata,
  stop safely on invalid/unavailable input or EOF, and label probing, encoding,
  validation and publication separately. Batch metadata is never saved.
- Add separate existing-tool setup PS1/BAT entries and interactive dependency
  repair that resumes the same conversion after validating a selected pair.
  Show tool identities/hashes, ask before remembering, retain typed-path and
  offline recovery, and give exact repair commands on noninteractive failures.
  Optional downloading is available in separate setup after affirmative consent.
- Add explicit `-FfmpegDirectory` and portable `-ConfigPath` tool selection with
  deterministic explicit/saved/app-local/PATH precedence and bounded validation.
- Add deliberate atomic user-selection persistence through
  `Save-AudioToolSelection`; ordinary conversion and preview never save settings.
- Preserve short-operation deadlines and unlimited normal encode/full-decode
  runtime. Set the single runtime version to 1.0.1 for candidate preparation;
  exact-package acceptance and public release remain separate pending gates.

## 1.0.0

Changes for app version 1.0.0. Publication and exact package verification are
recorded separately in the repository's
[release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md).

- Preserve recursive MP3/M4A/OGG conversion to 64 kbps CBR MP3 by default, the
  configured Music destination, relative folder layout and date-first filenames.
- Add an optional output parent, read-only preview, deterministic filename and
  collision planning, and exclusive per-run output folders.
- Validate tools, input/output paths and explicit covers before conversion;
  exclude reparse points and recognized generated runs during discovery.
- Encode to recognizable partials, validate and fully decode audio before final
  publication, and preserve completed outputs after independent file failures.
- Report meaningful batch exit codes, bounded progress, controlled cancellation,
  local diagnostic logs and structured per-file manifests.
- Preserve source metadata with documented title/Artist/Album precedence;
  replace artwork only with an explicit cover and document chapter/player limits.
- Retain isolated real-FFmpeg tests on Windows PowerShell 5.1 and PowerShell 7;
  add supplementary Windows CI with verified external test dependencies.
- Provide comment-based help, executable examples, one runtime version source
  and unsigned-script/support guidance.

FFmpeg remains external. Loudness normalization is deferred. Named phone
acceptance covers Samsung S24, One UI 8.5 and AIMP v4.31.1747 over USB cable;
chapters were unavailable and navigation was not tested. See
[SUPPORT.md](SUPPORT.md#tested-boundaries) for the recorded limits.
