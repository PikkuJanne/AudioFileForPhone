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

The original test suite writes into Music and times runs to avoid collisions.
T02 captures characterization first; run only in a genuinely isolated test account
or safe owned harness. T03 adds OutputParent and moves ordinary tests to unique
TEMP roots. It may proceed while T02 execution is specifically blocked by unsafe
legacy output isolation, but it must finish baseline execution before T04.
Do not introduce a production-only environment-variable backdoor simply to fake
Music-folder isolation.

## Commands

T02 adds a test-only adapter which retains and runs the original real-FFmpeg
suite from disposable copies. It replaces exactly one Music resolver in each
copy, verifies the substitution and parses the companion on the invoking shell.
The application and original suite are untouched. Cleanup uses a unique owned
TEMP root with an exact marker/path check and refuses reparse points. The
adapter does not test the live configured Music destination; A08 remains T03.

Adapter-only checks, verified on the active machine in T02:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-isolation-ps51.json -ValidateOnly
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-isolation-ps7.json -ValidateOnly
```

Real baseline commands, passed on both shells in T02 using the owner's installed pair:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps7.json
```

The adapter finds canonical `ffmpeg.exe`/`ffprobe.exe` locally or on PATH. Optional
`-FfmpegPath` and `-FfprobePath` accept absolute executable paths and verify that
the unchanged application will discover the same pair. Reports must be named
`T02-<label>.json` directly under `docs/codex-v1/evidence`; raw generated-run logs
are disposable. It never installs tools or changes persistent execution policy.
`-ValidateOnly` does not generate/convert audio and cannot pass A04–A06. The
companion's executed fixtures/known-gap observations map to
`T02_REGRESSION_MATRIX.md`. Reports contain source hashes, measured media
properties, required passes and separate observed defects. The PS5.1 report
reader explicitly uses UTF-8; both suites were rerun after that harness fix.

Focused T02 contract commands (helpers default to `C:\ffmpeg\bin`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\docs\codex-v1\tools\Test-T02Bitrates.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\docs\codex-v1\tools\Test-T02Bitrates.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -Append
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File .\docs\codex-v1\tools\Test-T02NameContracts.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-name-contracts-ps51.json
pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File .\docs\codex-v1\tools\Test-T02NameContracts.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-name-contracts-ps7.json
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\docs\codex-v1\tools\Test-T02Launcher.ps1
```

Bitrates: four generated WAV profiles (encoder characterization, not added input
support), 18 candidate and six invalid rates, 96 rows per shell. Silent rounding
is recorded, not accepted as correct output. Names: real app copies at 24/180
with three colliding supported inputs plus pure suffix/path budget checks; no
filesystem boundary or future preflight implementation claim. Launcher: unchanged
BAT next to an inert argv/exit stub under owned TEMP; stored PS5.1-host evidence
exercises the selected PS7/STA child, not its PS5.1 fallback. No Music resolution
or conversion occurs in that helper. Future T10 must cover fallback/metacharacters.

Helpers verify exact owned cleanup and reject redirected evidence paths. T02
adds parent/existing-file reparse checks to the bitrate report writer; the optional
isolated junction rejection fixture was blocked before execution by automatic
approval review ("rejected: blocked by policy"), so that runtime guard check is
unrun. No fixture or repository evidence-directory change occurred. T02
test payload fingerprints are preserved in `evidence/T02-tested-payload.json`;
reports name the actual test base plus working helper hashes, not a fabricated
post-test commit. T03 must update canonical commands after ordinary suite isolation.

The original suite's direct commands remain available after T03 isolation:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AudioFileForPhone.ps1
pwsh -NoProfile -File .\tests\Test-AudioFileForPhone.ps1
```

Do not run those direct commands against ordinary Music before T03. Validate
actual policy and record canonical updated commands in STATUS. Never
change execution policy globally or disable endpoint controls for a test. Add a
small repository test runner only if it reduces repeated commands, not a framework.

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
