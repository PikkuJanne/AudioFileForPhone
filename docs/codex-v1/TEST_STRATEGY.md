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

Recorded T04 integration/evidence commands (historical labels; do not overwrite):
Use STATUS.md or evidence/T07.md for current passing commands with fresh labels.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps7.json
```

For a direct retained-suite run without writing an evidence report:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-AudioFileForPhone.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe
```

Recorded T04 TEMP-only resolver commands (both passed their recorded payload):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-OutputParent.ps1 -EvidencePath .\docs\codex-v1\evidence\T04-resolver-ps7.json
```

The focused `tests/Test-OutputParent.ps1` tests the actual resolver function
extracted from the functions-only runtime helper AST, injected redirected Music paths and literal
explicit output paths. Its normal mode uses TEMP only. The historical T03
`-DefaultSmoke` exercised the narrow configured-Music test in `evidence/T03.md`;
T06/T07 deferred that mode before setup; T08 ownership adaptation is below.
No registry or persistent PATH/policy change is
needed. Neither recorded mode is phone/manual playback evidence.

The wrapper writes only explicitly named `T03-<label>.json`, `T04-<label>.json`, `T05-<label>.json`, `T06-<label>.json` or `T07-<label>.json`
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

## T06 discovery checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps7-final2.json
```

The focused harness uses owned TEMP trees for Music-like overlap, explicit/new/legacy
output exclusions, malformed identities and similarly named user content. Real
junctions exercise loops and outside targets; a real file reparse fixture exercises
the file skip policy. Symlink creation capability is recorded separately without
changing machine settings. Owned ACL denial proves complete scan abort before
prompts/run/conversion; original ACLs, fixture hashes and exact cleanup are checked.
Repeated short real-FFmpeg runs retain default bitrate/layout/tags/full decode and
do not rescan the first generated run. Reports use CreateNew; retry with fresh labels.

Use T06 labels for ordinary retained baseline/preflight/resolver reports; preserve
all earlier reports. The retained suite now asserts empty scans create no run/log.
Historical T03 configured-Music smoke evidence remains valid for its original
payload. At T06/T07, `Test-OutputParent.ps1 -DefaultSmoke` stopped before any setup
because its pre-reserved run conflicted with production's no-reuse check. T08 uses
a successful controlled child returning its exclusive root instead. Ordinary
resolver mode remains TEMP-only.

## T07 naming checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NamingPlan.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T07-naming-ps51-final2.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NamingPlan.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T07-naming-ps7-final2.json
```

Current regression commands and all ten passing report labels are in
`evidence/T07.md`. Baseline/preflight/resolver accept T07 filenames; discovery
accepts T06/T07. Preserve earlier reports and use fresh labels for reruns.
Owned fixture-root/output names were shortened to fit the newly enforced path
policy; the companion checks the same shortened ownership prefix. Application
copies retain exact bytes. No production path limit or source-safety check is waived.

Focused checks cover invariant real dates and whole-basename fallback, locales,
NFC before/after filtering, permitted supplementary scalars, noncomposing marks,
malformed surrogates, complete UTF-16 suffix budgets, shuffled case/extension/NFC
collisions, canonical duplicates and zero partial plan rows. Native owned fixtures
prove actual file 259/260 and directory 247/248 boundaries, including preserved
trailing-dot/space and overlong folder aborts before prompts/output. Short real
FFmpeg conversion checks 19 outputs per shell, suffix 12, exact planned layout,
allocated/preserved title tags, 64 kbps, full decode and an actual 180-unit basename.
The future fixed-length working path is budgeted but not written until T09.

The focused harness selects the shorter existing machine/user TEMP without
settings changes, creates an exclusive root and owner marker, records recoverable
root identity, individually removes registered native fixtures nonrecursively,
then checks exact path/token/nonreparse boundaries before .NET owned-tree deletion.
Final hashes/cleanup pass. Initial failed PS5.1 report has unverified cleanup and
an unknown possible synthetic residue because its leaf was not recorded and
machine TEMP parent enumeration is denied; evidence/T07.md preserves that limit.
No broad cleanup or ACL change was attempted. Configured-Music smoke was deferred
at T07 and adapted in T08; ordinary resolver mode stays TEMP-only. No phone/manual/
release evidence.

## T08 reservation and M1 regression checks

Use fresh T08 report labels. Both shells run Test-RunReservation.ps1, the isolated
retained baseline/seven companions, Test-Preflight.ps1, Test-Discovery.ps1,
Test-NamingPlan.ps1, Test-NativeProcess.ps1 and normal Test-OutputParent.ps1.
The current exact commands/reports are in evidence/T08.md. Historical reports
remain tied to their recorded hashes, including intermediate passes and failures.
Run process-resource handle checks with reduced test load; keep their threshold
and every failed observation. They do not establish reservation race correctness.

Reservation correctness uses named ready/release events in separate processes,
forcing four helper children to contend on the same fixed timestamp/candidates.
All must signal ready before release; no sleeps avoid the race. A separate two-
child real-entry barrier verifies decoded outputs, distinct roots/logs, relative
OutputParent and a process-local FileSystem PSDrive. That production launch does
not require both wall-clock timestamps to match; the fixed-candidate helper test
is the collision proof. Existing directories/files/logs/markers/sentinels retain
SHA256, CreateNew collisions refuse writes, suffix path overflow rejects before
creation, and owned ACL failures exercise Win32/setup diagnostics and exact scope.

The configured-Music smoke runs unmodified runtime copies with one synthetic
TEMP source and no OutputParent override. Inspect only the single direct Music
root returned after successful controlled exclusive reservation. Validate the
runtime token/scope, add a CreateNew test marker, require exact allowed inventory
and nonreparse ancestry, then remove only that run. Never enumerate ordinary
Music, change its settings/ACLs, pre-reserve candidates or modify timestamps.
If child/ownership/cleanup proof fails, preserve the recorded exact candidate
instead of guessing ownership. Final source hashes and scoped cleanup are required.

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

## T09 staged output checks

Use tests/Test-TransactionalOutput.ps1 under PS5.1 and PS7 with existing
C:\ffmpeg\bin tools and fresh create-new evidence labels. Current exact commands,
18 final report names, observed failures and runtime equivalence are in
evidence/T09.md and evidence/T09-tested-payload.json. Final focused reports are
T09-transaction-ps51-attempt6.json and T09-transaction-ps7-final1.json.

Each focused run verifies 27 groups: 61 real short decoded conversions and three
separate unsupported selected-rate rejections; false successes, physical stale-Xing
truncation/corruption, actual locked rename, independent final sentinel, retained
ownership/changed identity, unproved native exit and actual entry postpublication
log failure. The matrix spans tiny/normal durations, MP3/AAC/Vorbis/Opus and
8000 through 48000 Hz; max measured source/header/decoded difference 0.066125 s
supports the conservative fixed 0.35 s allowance. The simulated two-hour duration
mismatch is a policy test, not long-file evidence. Do not fill an ordinary volume
to test disk exhaustion or equate mocked failures with a real disk-full experiment.

Function substitutions exist only in the test process; production has no injection
switches. Runtime copies preserve bytes. All native children, sentinel events,
fixtures/raw diagnostics and temporary driver files remain in exclusively owned
TEMP; sources/sentinels and exact cleanup are checked. Named-event readiness and
release establish final-destination race timing, not sleeps. Diagnostic -File
drivers must forward nested LASTEXITCODE and handle PS5.1 display wrapping without
waiving published-path/exit/output assertions. Never persist unredacted OS host
identity from CLIXML; attempt4's explicit privacy-only redaction remains recorded.

Retain the baseline suite and affected preflight/discovery/naming/reservation/
native/resolver companions. The 16 existing final reports pass; native handle
checks run quietly/sequentially, preserve allowance 16 and every failed attempt.
Configured-Music smoke keeps its exact returned-root/token/inventory cleanup gates.
Ordinary tests never enumerate Music. Use fresh next-task labels and extend only
affected guard patterns; intermediate passes do not replace final payload hashes.

## T10 outcome and launcher checks

Current exact commands are in evidence/T10.md. Final script reports are
T10-script-ps51-final3.json and T10-script-ps7-final2.json: 13 real child groups,
14 independently probed/full-decoded publications per shell. Assert explicit
0/2/1, good-bad-good continuation, failures-only, preflight/empty scan, thrown
native boundaries, exact logged source/target mappings, diagnostic/summary faults,
warning-only progress faults and actual marker-only reserved setup residue.
Summary counts must match independently observed outputs, including fatal stops.

Final launcher reports are T10-launcher-ps51-final2.json and
T10-launcher-ps7-final2.json. Each runs 52 real cmd cases across both installed
PowerShell branches with an inert capture/exit child and byte-identical production
BAT. Validate exact argument count, including quoted empty extra arguments; STA;
code-specific messages; preserved 0/1/2/130/37 after actual pause; input and script
locations with spaces/!/percent/&/^/apostrophes. Percent-bearing strings use one
caller substitution; direct caller percent expansion is explicitly characterized.
No physical keypress/Explorer or real application cancellation is claimed.

Eight final1 regression reports across baseline/transaction/preflight/discovery
retain real FFmpeg/seven companions, 27 transactional groups/61 decoded successes/
three requested-rate rejects, preflight 35/eight helpers and discovery eight.
Source/fixture hashes, child disposal, applicable ACL/link restoration and exact
owned TEMP cleanup pass. The 12-report manifest independently matches 11 source
fingerprints to committed blobs with CRLF/LF-only normalization. Preserve all 32
raw attempts, including six failed harness match/fixture cases and earlier passes.

Harness driver/pipe waits are bounded and cleanup is refused whenever descendant
release is unproved. Production entry copies retain bytes; fault substitutions are
only appended helpers or driver cmdlet overrides inside exact owned TEMP. No
Music enumeration, new native-resource measurement or configured-Music smoke is
claimed for T10. T11 closes M2 and must run the full applicable suite at that gate.

## T11 cancellation and M2 matrix

Exact commands and results are in evidence/T11.md. Test-Cancellation.ps1 runs nine
automated groups on each shell: pre-request/native/source cancellation, actual
real-native cancel with unrelated FFmpeg alive, cancellation at successful
validation probe/decode return boundaries and before publication, unknown-release retention, isolated console Ctrl+C
input records, actual forced host kill and next-run/orphan preservation. Controller
ownership uses retained parent/creation/PID/image proof before termination. Separate
descendant release guards block fixture cleanup on uncertainty. Helpers are only
append-instrumented inside owned TEMP; entry/next-run bytes retain originals.

Physical -Manual mode is separate: real local ConsoleHost/Windows Terminal, wait
READY after first publication and during second encoder, then actual Ctrl+C. Verify
130/Cancelled/counts, preserved first output hash/full decode, unrelated FFmpeg,
console mode, sources and exact cleanup. Owner-confirmed PS5.1 manual1 passes;
Store PS7 manual1 failed test-helper compilation before cases, with cleanup/hashes
pass and physical=false. Explicit Framework compiler references repair only the
harness. Store PS7 manual2 passes at actual test base 18fd7a6 with owner
confirmation. It proves all physical gates with current runtime/repaired harness
bytes. The original PS5.1 manual1 harness variant stays preserved. Synthetic
console input never establishes physical acceptance. Fresh manualN labels are
CreateNew; existing reports are never overwritten.

Full applicable M2 suites pass both shells in 26 selected reports: script and
cancellation final2, other matrix families final1, plus Store PS7 cancellation
final3 and final4 after compiler repair (repository and Store-directory starts). Quiet sequential native handles 673->673 and
580->580 retain allowance16. Configured-Music smoke uses only exact successful
returned root/token/CreateNew test marker/nonreparse synthetic inventory; ordinary
Music never enumerated. Manifest proves 16 runtime/test files against code with
only CRLF/LF normalization. Preserve 33 raw automated reports/four failures; DLL
recovery limitation and old optimistic cleanup expectation are in evidence/T11.md.
A29/A30 and T11 pass; required physical Ctrl+C and full M2 local acceptance are
complete. This acceptance closure changes only docs/evidence; no runtime/test
change justifies repeating the existing passing suites. Main integration remains
owner-gated.

## T12 preview checks

Exact selected commands/results are in evidence/T12.md. Run Test-Preview.ps1 on
PS5.1 and PS7 with fresh T12-preview-<edition>-attempt/finalN.json labels. Final1
reports directly test b0c20f66; eight groups and eleven independently probed
64 kbps MP3/full-decoded publications per shell pass. Compare each preview source
and relative destination with its exact real success log mapping, including
collisions; matching only the published filename set is insufficient.

Reserve one exclusive marked TEMP tree. Assert whole-tree equality around every
preview: directories, file paths/lengths/SHA256, modification times and attributes.
Call FileSystemInfo.Refresh before reading both inventories to avoid cached
enumeration metadata; retain strict timestamp equality. Exclude access times only.
App copies preserve entry bytes; append forbidden native/write/cover/prompt/context
guards only in TEMP. Cover Interactive/invalid explicit cover, missing parent and
ancestor, owned default-Music resolver, corrupt supported media, empty/invalid and
late path-budget errors, marked exclusions/unmarked prefixes/unsupported files.
Occupy a provisional candidate and prove its preservation while real reservation
selects another root. Keep root timestamp/suffix promises out of assertions.

Suspend native child-release proof before each invocation; restore only explicit
release while preserving prior uncertainty. Bound owned child/pipe waits and refuse
recursive cleanup on unknown descendants. Verify exact root/token/nonreparse scope,
source/synthetic hashes, child disposal and final absence. Ordinary Music is unused.

Retain all eleven raw records: six selected final passes, attempt5 intermediate
pass and attempts1-4 failed harness metadata/transport/warning/path assertions.
Four selected baseline/script regression reports also pass on the same production
bytes (script 13 groups/14 decoded publications per shell). Manifest independently
matches eight tested files to committed blobs, three literal/five CRLF-to-LF only.
This is targeted T12 acceptance; the prior M2 suite and physical evidence remain
valid, with the next full applicable suite at a milestone boundary.

## T13 progress and affected regressions

Exact selected commands and raw results are in evidence/T13.md. Test-Progress.ps1
uses fresh T13-progress-ps51/ps7-attempt/finalN.json reports. Final1 tests reviewed
code 8607569 directly on both shells: 17 groups cover record chunks/bounds/time
fallback/unknown duration, caller-thread throttling, sparse live callbacks,
stderr separation/floods, worker/callback faults, requested cancellation, nonzero
end records, validation rejection, promotion collision and truthful batch outcomes.
The actual 3,605-second synthetic source runs without real-time pacing, has
multiple positive machine samples before publication, and independently probes/
fully decodes at 3605.047982 seconds as 64 kbps MP3. It is automated synthetic
evidence, not phone/manual playback or console appearance evidence.

Reserve one exclusive CreateDirectoryW/CreateNew token-marked TEMP tree. Retain
owned hosts before Start, suspend descendant-release proof before each native
call and preserve prior uncertainty. An append-only helper audit inside TEMP
records native return/release and caller-thread machine samples; entry bytes stay
identical. Preserve callbacks, duration, capture limits, parser and shared callback
state in wrappers. Keep release evidence separate from successful host status.
Unknown descendants block recursive deletion. Exact canonical root, marker/token,
nonreparse inventory, source/synthetic hashes, child disposal and absence are gates.

Twelve affected regression finals pass: native 35, transaction 27 groups/61 decoded
outputs, script 13, preview 8, automated cancellation 9 and retained baseline per
shell. Native quiet sequential handles 667->667/576->576 keep allowance 16.
Cancellation's full-decode fault selector requires null output, so encoder
-progress cannot masquerade as a decode boundary. Preview guards reject parser
compilation/display, retaining strict refreshed whole-tree inventory equality.
Manifest matches 14 tested files to the reviewed commit literally or CRLF-to-LF.

Retain 18 raw tests, including two failed new-harness variable-collision attempts
and two preliminary passes. Failed cleanup/children flags remain false; separate
known-root recovery records and in-memory historical-harness reconstruction prove
later exact removal. No recovery record counts toward A33/A34. These are targeted
affected checks; prior physical T11 evidence remains historical, with the next
full applicable suite at a milestone boundary.

## T14 diagnostics and affected regressions

Exact selected commands/results are in evidence/T14.md. Run Test-Diagnostics.ps1
with fresh T14-diagnostics-ps51/ps7-attempt/finalN.json labels. Final1 directly tests
code b272cfda on both shells: 19 groups, 14 independent 64 kbps MP3 probes and full
decodes per shell, source/output byte and probe-duration equality, real metadata
and JSON Unicode/quotes/commas/CR/LF/formula-like strings. Construct Unicode from
explicit code points and put UTF-8 BOMs on generated PS5.1 drivers. Newline fixtures
are metadata/structured values, not invalid Windows filenames.

Actual corrupt source, encoder filter, output probe option and decode filter
failures retain local native stage/status/exit/release/timing/stderr. A compiled
disposable child floods both pipes through the actual native runner; persisted
stderr is at most 16,384 characters per stage, reason/error 2,048 and measurement
error 512. No stdout dump/upload. Mixed supported/failed/excluded/unsupported
counts reconcile; manifest cancelled/unstarted states are exclusive and legacy
console not_processed includes both. Unknown measurements remain null.

Inject initial/boundary/final log and manifest failures, occupied/foreign identity,
post-promotion guard-open failure, three timer cancellation variants and immediate
startup cancellation. Preserve actual 0/1/2 publications/counts through recording
failure; fatal exit1 and cancellation130 remain explicit. Persistent write failures
leave honest last-good Running JSON. Source/helper copies identify actual bytes;
entry remains byte-identical, audit/fault wrappers append only in owned TEMP.

Reserve Win32/CreateNew token-marked exact TEMP scope, retain hosts before Start,
suspend release proof before every call and restore only positive proof preserving
prior uncertainty. Drain/join owned hosts and refuse recursive deletion when any
descendant is unproved. Check canonical root, token/digest, nonreparse inventory,
source/synthetic hashes, release/disposal and final absence. Ordinary Music unused.

Fourteen affected finals also pass: native 35, transaction 27/61 decoded outputs,
script 13, preview 8, automated cancellation 9, progress 17 and baseline 7 required
checks per shell. Quiet native handles 667->667/577->577 retain allowance 16;
progress actually converts 3,605 seconds and fully decodes 3605.047982 seconds with
live samples.
The manifest compares all selected source fingerprints and independently hashes
committed blobs, allowing only literal bytes or strict UTF-8 CRLF-to-LF equivalence.

Retain 19 raw tests, including 2 preliminary passes and 1 failed new-harness path/BOM
attempt. Original false children/cleanup flags stay unchanged. Three separate
proof/recovery records reconstruct exact historical harness 258aec1c and native/
host boundaries. First recovery refused before deletion on ISO text formatting;
second compares exact UTC ticks and all other fields without tolerance, then removes
only the independently reviewed known scope. These records are provenance only.
No repeat physical/phone/CI/release claim; next full applicable suite at M3 boundary.

## T15 metadata and full M3 matrix

Exact commands and selected results are in evidence/T15.md. Test-Metadata.ps1
uses fresh T15-metadata-ps51/ps7-attempt/finalN.json reports. Final1 directly tests
code 5044cd80 on both shells: 15 groups, 18 independently probed/full-decoded
publications, 81 direct natives, 14 retained hosts and 118 entry release proofs
per shell. Quoted Unicode title/artist/album/comment and track/disc survive actual
MP3/M4A/Ogg conversion; blank overrides retain source tags and existing/fallback
titles use the established precedence. Mixed video/art/two-audio input independently
decodes as the first 440 Hz audio rather than the second 880 Hz stream.

Default artwork is absent. JPEG/PNG explicit replacements have exactly one JPEG
attached picture with independently decoded blue/green pixels and original
dimensions, including 1232x1304. One image inspection and one dedicated preflight
decode serve each batch; encoders still read the cover for embedding. Exclusive
image reopening and explicit native release establish disposal. Cached diagnostics
retain advisory warnings without resizing. Missing/corrupt/GIF/BMP renamed images
fail before prompts/reservation. Controlled post-GDI corruption exercises real
FFmpeg decode rejection, restoring only owned synthetic bytes after positive
release. A no-child Completed/exit0/unreleased stub rejects false release proof.

Real M4A chapters keep two quoted/Unicode titles in MP3, with the 0.150023-second
source boundary rounded to 0.150000 seconds in MP3's millisecond time base.
This is short-fixture/probe evidence, not phone chapter navigation or resume.
Padded nonblank override exactness is pure-plan-only; actual empty MP3 title
assignment omits its tag. Physical M4A stream handler_name/Ogg stream-only comments
are distinct from native probe-stub conflicting-title dictionaries.

Full M3 passes 32 selected finals: 600 required groups/checks plus six baseline
observations. All retained families run both shells, including 52 launcher cases,
61 transactional decoded outputs, 3,605-second progress/full decode at 3605.047982,
and two strictly returned-root configured-Music smokes with the required final
manifest/exact synthetic inventory. Ordinary Music is never enumerated.
Quiet sequential native handles stay 674->674/578->578, allowance 16 unchanged.

All available source/synthetic/release/disposal/owned cleanup gates pass. The
manifest independently proves 20 files/134 actual report-source bindings to code
5044cd80, two literal/eighteen strict UTF-8 CRLF-to-LF only. Older baseline lacks
command/edition/child-ledger fields; resolver/music has actual entry/helper
before-after fields but only one recorded harness digest. Missing fields are not
invented. Preserve two preliminary metadata passes; no T15 failed attempt/recovery.
Prior physical T11 evidence stays historical. No new manual/phone/CI/release claim.
