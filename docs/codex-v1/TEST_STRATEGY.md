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

The existing suite's entry point remains the starting point after isolation:

```powershell
powershell.exe -NoProfile -File .\tests\Test-AudioFileForPhone.ps1
pwsh -NoProfile -File .\tests\Test-AudioFileForPhone.ps1
```

These commands are not claimed to have been run here. Validate actual policy and
harness parameters in T02/T03; record canonical updated commands in STATUS. Never
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
