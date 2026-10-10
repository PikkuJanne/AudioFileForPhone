# Evidence and efficient testing strategy

## Required environments

Windows 11 with Windows PowerShell 5.1 and PowerShell 7 on the active Codex machine.
Record exact builds/versions. GitHub Windows CI covers both shell families as a
supplement, not a substitute for local interactive tests or real phone playback.
No universal Windows 10, all-Android, UNC/NAS or long-path support claim without
corresponding evidence. Lack of a supported environment is a visible blocker.

## Test layers

Pure tests: date/naming/collisions, path boundaries, argument builder, progress
parser, outcome aggregation, version and package inventory. Native fault-injection
stubs: missing tool, argv capture, stderr flood, zero-exit fake output, truncated
files, invalid probe JSON, destination/promotion error. These test contracts but
cannot by themselves establish FFmpeg media correctness.

Real FFmpeg integration: keep the existing `tests/Test-AudioFileForPhone.ps1` and
its synthetic clips/cover fixture. Expand it or call focused sibling helpers. Do
not replace it with mocks. Ensure script-copy tests include any runtime helpers.
Use 0.4–3-second clips for routine matrices; cover MP3/AAC M4A/Vorbis/Opus OGG,
mono/stereo baseline, metadata and full-decode checks on short outputs.

Windows process/filesystem checks: cmd/BAT exits and metacharacters, STA picker,
read-only/unwritable paths, junctions, concurrency, actual cancellation and source
hash safety. Use controlled fixtures, not permissions changes to user directories.

Manual long-file/phone checks: a representative long podcast or audiobook (for
example over an hour) tests duration and near-end seeking; use legally held local
media without uploading it. Record output hash and private descriptive ID rather
than raw filename/content in GitHub. Check phone/player versions and actual tags,
cover, order, seeking/resume. Do not create fake screenshots or fill a template as
though tests were performed.

## Safe baseline and isolation ordering

At the T02 checkpoint, the original suite wrote into Music and timed runs to avoid collisions.
T02 captures characterization first; run only in a genuinely isolated test account
or safe owned harness. T03 adds OutputParent and moves ordinary tests to unique
TEMP roots. It may proceed while T02 execution is specifically blocked by unsafe
legacy output isolation, but it must finish baseline execution before T04.
Do not introduce a production-only environment-variable backdoor simply to fake
Music-folder isolation.

## Commands

T03 replaces the copy-only Music adapter with the public `OutputParent`
parameter. Ordinary integration checks, fixtures and output all live under
marker-owned TEMP trees. Every conversion receives a fresh output parent;
application copies preserve source bytes. The retained real-FFmpeg suite and
focused companion still check the baseline formats, tags, names, full decoding
and source inventories. Production PATH discovery is checked against the
selected installed pair. Cleanup verifies exact canonical ownership and rejects
reparse points before recursively removing only its own tree.

Canonical integration/evidence commands on the active Windows machine:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps7.json
```

For a direct retained-suite run without writing an evidence report:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
```

Canonical TEMP-only resolver commands (both passed):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps7.json
```

The focused `tests/Test-OutputParent.ps1` tests the actual resolver function
extracted from the functions-only runtime helper AST, injected redirected Music paths and literal
explicit output paths. Its normal mode uses TEMP only. `-DefaultSmoke` opts into
the separate narrow configured-Music test described in `evidence/T03.md`; this
is excluded from ordinary runs. No registry or persistent PATH/policy change is
needed. Neither mode is phone/manual playback evidence.

The wrapper writes only explicitly named `T03-<label>.json`, `T04-<label>.json` or `T05-<label>.json`
reports directly in `docs/codex-v1/evidence`, preserving historical reports. `-ValidateOnly`
checks copies, syntax and owned cleanup without generating media and cannot
establish codec behavior. No helper downloads tools.

T02 commands/results in `evidence/T02.md` describe the frozen T02 payload.
Its resolver-substitution helpers, including `Test-T02NameContracts.ps1`, are
historical and are not canonical commands for the changed T04 script. The
bitrate matrix, launcher observations and 24/180 name evidence remain the
selected contracts; repeat affected checks when those features change.

## T04 focused preflight checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps7.json
```

The focused harness uses the installed C:\ffmpeg\bin pair by default, short
synthetic media, byte-identical app/helper copies and exclusively marked TEMP.
Every negative child uses -Interactive under a -NonInteractive host to prove
rejection before prompts/conversion/run creation. It includes true Windows ACL
denials only on newly owned fixture directories, restores their original ACLs,
then verifies source hashes and exact cleanup. Inert helper loading, numeric
boundaries, caller-local native exit state, real JPEG/PNG validation and internal
SkipWriteProbe/no-creation are checked separately. Raw child diagnostics remain
only in disposable TEMP; evidence contains assertions, bounded diagnostic
excerpts and controlled commands.
No ordinary Music test, disk filling, registry/policy change or manual evidence.

## T05 native execution checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps7-final.json
```

The focused harness compiles a controlled C# child with the local .NET Framework
compiler inside owned TEMP. Its argv capture and native fault modes exercise both
shells independently; no test executable is shipped or committed. Real FFmpeg
tests accompany stubs. Retained baseline, preflight and resolver harnesses accept
T05 evidence filenames so their historical T03/T04 reports remain unchanged.
Native evidence uses CreateNew; repeat with a fresh T05 label instead of replacing
an existing report. The commands above record the original final runs.

## Cadence and status vocabulary

Targeted tests after each change; regression suite after M1/M2/M3 and before
integration; full suites on final C and exact ZIP. Long audio is not repeated for
every name-parser edit. If a payload change touches audio/process/path output,
rerun affected manual/phone evidence before freezing. Unchanged media-processing
payload may reuse prior manual results only with an explicit equivalence record.

Case status values: not_run, pass, fail, blocked, or not_applicable. Required cases
cannot silently become not_applicable; changing a gate requires owner-approved
scope change and honest release notes. Optional O01 cases remain not_run/deferred
and do not block the core. Every pass links concrete evidence with tested commit,
environment, commands, expected/observed result and real tester for manual cases.

Task status: todo, in_progress, blocked, verified, done, deferred. “verified” means
implementation evidence exists; “done” adds reviewed/pushed checkpoint. Record
prior verified code/evidence commit, not a self-referential current-commit hash.
A final live check is always required independently of stored status.
