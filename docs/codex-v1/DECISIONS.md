# Decisions and policy ledger

## T22 review and final-version documentation — 12 October 2026

- Reconcile owner-merged PR #21 by normal fetch and fast-forward only. Main
  `25856cf144b0b84cbedd378a58a8e537ae91c52b` contains T01–T21; its T21 tree
  matches final feature `7629aeb8c183fbd4d5f16eb74e8a70969b91d9a7` and both
  merge-push Windows CI jobs pass. No main or repository settings write occurs.
- Independently audit improvements 1–15, historical report provenance and the
  current security/usability/package contracts. Improvement 15's implementation
  readiness is distinct from required future exact-ZIP/publication/closure gates
  A55–A65. O01 stays deferred and no loudness default is introduced.
- Candidate `64772f1e5cbc4ea4fb5d0a5f0aefda8eab145723` corrects only the shipped
  README/SUPPORT/CHANGELOG's stale progress text. Stable version/feature notes
  link to mutable repository evidence without inventing a release date, frozen
  package acceptance or public release. Narrow named T20/T21 observations and
  unavailable/untested limits stay explicit. Runtime/tests/CI/build are unchanged.
- Run the retained full milestone routing and routine CI sequentially on this
  active Windows machine with fresh `final220` milestone and `final221` selected
  routine reports. Dependency copies retain
  actual historical provisioning bytes/commit; no download/global setting change
  is implied. Ordinary media checks are isolated; only the established bounded
  default-Music smoke touches its returned exact owned run.
- Initial create-new driver preflight refused an occupied historical `final22`
  cancellation filename before any suite launch or dependency copy. Preserve
  `T22-driver-preflight.json`; use fresh labels without overwriting old reports.
- Preserve the initial `final220` PS5.1 routine/baseline failure. The external
  driver's CREATE_NO_WINDOW launch gave the retained characterization harness
  code page 437, decoding FFprobe UTF-8 as mojibake. A controlled synthetic probe
  proves correct raw UTF-8 tags, exact failure under 437, and exact success with
  the inherited console's 65001 (also with a scoped restored UTF-8 setting).
  Correct only the temporary driver to inherit the existing console and retry
  the two routine jobs with fresh `final221` reports. Application/test sources
  and strict comparisons remain unchanged; the failed record is never relabeled.
- Preserve the owner's completed human-testing instruction and actual Samsung
  S24/AIMP result. No personal media scan, long-file regeneration, new phone
  observation or physical interaction is authorized or needed in this audit.
- Main integration of the exact reviewed final-document PR remains owner-gated.
  T23 can freeze only after those changes are integrated and freshly synchronized;
  this task request adds no tag/release authority.

These scope choices implement the accepted review. Verify contracts in T02 and
record any owner-approved changes with rationale and impacted tests.

| ID | Decision | Status |
|---|---|---|
| D01 | Improve current PS1/BAT; no rewrite or new runtime dependency. | Fixed scope |
| D02 | Improvements 1–15 required; O01 loudness optional and off by default. | Fixed scope |
| D03 | Only normal public v1.0.0; website and intermediate releases excluded. | Fixed scope |
| D04 | Preserve default 64 kbps CBR, Music output, formats and date-first names. | Fixed scope |
| D05 | FFmpeg/ffprobe remain external, user-installed; no silent download. | Release policy |
| D06 | Source artwork absent by default; explicit cover replaces batch artwork. | Preserve baseline |
| D07 | One task per thread; one active developer machine; evidence in GitHub. | Workflow |
| D08 | No source mutation; no final-looking output before validation. | Safety invariant |
| D09 | Windows 11 plus PS 5.1 and PS 7 are required test environments. | Required |
| D10 | Real phone long-file/seek/tag/artwork/order acceptance is required. | Required |
| D11 | Windows 10, live UNC and removable/network storage are not promised without evidence; document untested limits. | Support boundary |
| D12 | No automatic resizing/preservation of source artwork required for v1; correct explicit-cover behavior and diagnostics are required. | Scope control |
| D13 | Root directories are rejected with a clear message in v1 unless T02 deliberately adopts and tests correct root handling. | Safe initial contract |
| D14 | Skip directory reparse points/junctions with a recorded warning; do not follow unknown targets. | Safe initial contract |
| D15 | Scan access failures abort before conversions, rather than silently miss subtrees. | Safe initial contract |
| D16 | Empty/no-supported inputs return a documented nonzero outcome with no finished output. | Preserve intent |
| D17 | Fixed-rate whitelist and name limit 24–180 finalized in T02; requested ranges enforced in T04. Produced-rate/duration/full-decode validation implemented in T09. | Ranges and T09 validation implemented |
| D18 | Main-merge authority and exact release approval are not recorded yet. | Owner gate |
| D19 | Any post-freeze commit may change only docs/codex-v1 progress/evidence, never shipped or tested payload. | Freeze policy |

## Approval ledger

The original bundle supplied no approvals. The following entries record the
owner's messages in the T01 thread on 10 October 2026 (Europe/Berlin).

- The startup request authorizes "local implementation/testing, focused commits,
  pushes to relevant codex/* task branches, and draft PR creation within this
  scope" and requires T01 only in this thread. This applies to improvements 1–15;
  loudness remains deferred and the website is a later project.
- After inspection found no `.git`, the owner selected "Restore Git metadata here
  after verification". All nine existing files matched the live baseline before
  metadata was initialized, fetched and indexed without rewriting working files.
- The owner then instructed "Stop asking for approvals, you have Full access".
  Continue ordinary authorized T01 actions without repeated confirmation.
- Main integration still has no recorded reviewed-PR approval or bounded merge
  policy. The startup request explicitly reserves that gate, release tags,
  publication, settings/history changes and default audio changes.

T01 workflow: one active branch `codex/v1-t01-checkpoint`, a small draft PR against
`main`, and independent post-push live-ref verification. The next task may continue
on this branch while main integration remains pending; preserve any later work.
Do not infer merge authority from an unprotected branch or authenticated tools.

## T02 reconciliation and engineering decisions — 10 October 2026

- Owner requested T02 and a handoff that clearly states the next suggested step.
  PR #1 was already merged by the owner at 19:45:49 UTC. T01 is now integrated
  into main `483af25f8e5fa9dee295f5b74130324663339e37`; no agent merge was performed.
  T02 uses fresh branch `codex/v1-t02-baseline` rather than the merged PR's branch.
- `T02_REGRESSION_MATRIX.md` records formats/defaults/tags/names/exits/source
  safety before application changes. Selected D17 limits are the documented
  LAME fixed-rate union, `MaxBaseLength` 24–180 UTF-16 units, default 60, with
  independent final/working file paths below 260 and directory-creation paths
  below 248 UTF-16 units. Real tests on both shells establish exact rate/profile
  behavior and baseline 24/180 names with collisions. Pure budget tests support
  suffix/path policies; rejection and Unicode scalar/NFC behavior are not yet
  implemented. Duration tolerance remains assigned to T09; short baseline deltas
  range from 0 to -0.0065 seconds, insufficient to validate long-file tolerance.
- Retain D13 root rejection, D14 descendant-directory reparse skips and D15
  abort-before-conversion on scan access errors. Selected T06 refinement also
  rejects a selected reparse directory and skips file reparse points to avoid
  out-of-tree source/cleanup boundaries; enforcement needs focused Windows tests.
- Adopt the already proposed future outcome contract 0/1/2/130 from UX_RESULTS
  for all-success/preflight-or-empty/per-file-failure/controlled-cancel. Baseline
  all-failed/mixed batches and BAT child failures returned 0; these are observed
  gaps, not passes of the future result contract. Implementation remains T10/T11.
- The test-only T02 adapter substitutes the Music resolver in disposable copies;
  no production environment-variable backdoor or known-folder registry change
  is introduced. Initially missing native tools blocked execution. The owner then
  supplied "C:\ffmpeg please resume T02"; the installed bin pair resolved that
  blocker without a download or machine change. A04–A06 passed the unchanged
  legacy suite and synthetic companion on both shells. Exact working payload
  fingerprints are linked in evidence; observed defects and unrun details remain
  explicit. Next suggested step: T03, add OutputParent and isolate ordinary tests.

- Native matrix: every selected rate was exact on a compatible profile. At
  44.1/48 kHz, 8/16/24 became 32 and 144 became 128; at 22.05 kHz, 192–320
  became 160. Keep automatic channels/sample rate; reject invalid requests in
  T04 and fail a produced-rate mismatch in T09 rather than silently round.
- No agent merge, CI run, default-Music smoke, phone test or release occurred.
  Feature synchronization and pending main integration are reported separately.

## T03 reconciliation and isolation — 10 October 2026

- Owner requested "T03 next please". PR #2 was already owner-merged at
  20:32:54 UTC into main `0818bf8206849370aa0ef2eaeccaed5b2fb1a890`.
  Local main was fast-forwarded and T03 branched from it; no agent merge or
  broader merge/release authority was inferred.
- Optional OutputParent uses literal filesystem resolution, supports missing
  and relative parents, and retains Windows configured Music when omitted.
  It is appended after existing parameters to preserve positional binding.
  Destination/log operations are literal to support bracketed parent names.
  No DSP, default-rate, supported-format, naming/layout or metadata change.
- Ordinary real-FFmpeg tests now pass fresh owned TEMP parents and copy the
  application byte-for-byte. Retained suite plus seven required companion
  checks passed per shell; sources and owned cleanup passed. Ten resolver
  cases passed per shell. An opt-in automated default-path smoke reserves
  exactly one marked synthetic Music run with CreateDirectoryW and changes
  only the disposable copy's timestamp assignment. Its exact inventory,
  source hash, 64 kbps MP3/full decode and cleanup passed on both shells.
  No registry changes or manual/phone evidence are claimed.
- Independent review corrected unrelated TEMP traversal and missing-source
  preservation checks. Final harness children use RemoteSigned; no persistent
  policy change or unblocking operation occurred. T02 substitution commands
  remain historical, not canonical for the changed T03 script.
- Reports record actual test base plus payload hashes. Source equivalence to
  code checkpoint `b5b3c8b7837dd8af17ae4e5b8405684ccdd7237e` is verified,
  including only Git CRLF/LF normalization. Fresh advertised feature ref
  matched the pushed code checkpoint. Draft PR #3 awaits owner integration.
  A07/A08 pass; T04 is the next coherent task. No CI, release or phone test.

## T04 reconciliation and preflight — 10 October 2026

- Owner requested "T04 next please". PR #3 was already owner-merged at
  20:43:41 UTC into main `bf425829d2e019911f179eb8250bfe6800f7ac81`.
  Local main was fast-forwarded to its independently advertised ref; T04 uses
  `codex/v1-t04-preflight`. No agent merge or broader authority was inferred.
- Functions-only `AudioFileForPhone.Helpers.ps1` extracts validation, tool lookup,
  output resolution, cover diagnostics, existing naming and discovery. Existing
  PS1/BAT entry points and parameter order/defaults remain. Every current copy
  harness includes the helper byte-for-byte; package work must include it too.
- Validate selected input directory/provider/root/readability, requested bitrate
  and name limits, output resolution, native tool identities/libmp3lame and an
  explicit JPEG/PNG cover before optional metadata prompts or run-root/log creation.
  Cover validation also tests one-frame FFmpeg decode/mjpeg encoding, to null output.
  Invalid explicit or picked covers now stop clearly. Cancellation of the picker
  still allows proceeding without cover. Syntactic UNC roots are rejected before
  share access; live UNC support is not established. Extended/device paths are refused.
- Normal output preflight creates a requested missing parent, then exclusively
  reserves an empty probe directory and a CreateNew sibling file, writes/flushes
  one byte and removes only those probes. Missing parents are retained deliberately;
  they are user-requested destinations, not owned disposable run trees. The internal
  SkipWriteProbe switch defers all probe/directory writes for future preview callers;
  no public preview parameter is introduced. No disk-exhaustion test is claimed.
- T04 keeps recursive/reparse policy for T06, calendar/Unicode/path allocation for
  T07, production run-root reservation for T08, transactional MP3 publication for
  T09 and aggregate exits/BAT behavior for T10/T11. Naming/DSP/metadata conversion
  behavior is preserved; this preflight is not a complete filesystem/process audit.
- A09–A11 pass on both shells: 35 negatives/eight helper checks, actual owned-TEMP
  ACL denials/exact restoration, ten resolver cases and retained real-FFmpeg suites.
  Final source/synthetic hashes and owned cleanup passed. Review corrected native
  exit-variable scope and PS5.1 test-only diagnostic capture; no manual evidence
  is claimed. Tested equivalent code checkpoint is
  `512a824ae856b4425a4012e0116f363babcc4d4e`; draft PR #4 awaits owner integration.
  Next suggested step: T05 in a new thread.

## T05 reconciliation and native execution — 10 October 2026

- Owner requested "T05 next please". PR #4 was already owner-merged at
  21:06:59 UTC into main `124f3a96e1a416f6870b832d1ee1cc7543286ab9`.
  Local main was fast-forwarded to its independently advertised ref; T05 uses
  `codex/v1-t05-native-process`. No agent merge or broader authority was inferred.
- One shared lazy .NET runner handles exact Windows CRT argv quoting, bounded
  concurrent UTF-8 drains, immediate native exit code, timing and owned cleanup.
  It closes redirected stdin and FFmpeg uses -nostdin. Default retained prefixes
  are 1,048,576 stdout/65,536 stderr chars; overflow is fully drained/countable.
  No conversion timeout, shell evaluation, broad termination or LASTEXITCODE
  dependency/mutation. Tool/encoder checks run once, paths/versions enter the log.
- Probe selects a:0 and validates one audio stream/index, which conversion maps
  explicitly. Native startup, probe nonzero, truncated output, invalid JSON/schema
  and missing audio are distinct file failures. A valid absent title still uses
  the collision-adjusted filename fallback. Preserve MP3/M4A container tags and
  Ogg first-audio-stream comments; Artist/Album and cover behavior remain.
- Final 35 focused cases per shell pass, including exact quoted/Unicode argv,
  full dual-pipe floods and stable handles across 40 invocations, real metadata,
  cover/full decode and tool logs. Initial tests found a PS5.1 root-array test
  parsing difference and retained worker handles from LongRunning tasks. The
  harness was corrected and pool workers now avoid per-file thread allocation.
  Failed attempts are preserved separately; final reports and regression source
  hashes match code checkpoint `215b57c2d1fd93ab62192e07c9ba30632bf2824e`.
- Retained real-FFmpeg suites/seven required companion checks, preflight
  35 negatives/eight helpers and ten resolver cases pass per shell. Source/fixture
  hashes, ACL restoration and owned cleanup pass. No ordinary Music, downloads,
  machine setting changes, external-reference/protocol audit, manual/phone/long
  audio, cancellation, CI or release evidence. Diagnostic prefix retention may
  omit a final error line; truncation is explicit. Later task gates remain.
- Draft PR #5 awaits owner integration; feature synchronization was independently
  verified. T01–T04 are integrated. Next coherent task: T06 in a new thread.

## T06 reconciliation and discovery — 11 October 2026

- Owner requested "T06 next please". PR #5 was already owner-merged at
  23:50:14 UTC on 10 October 2026 into main
  `f5fad94d3ef31ec53972ad642b71c0a8d9f76e6f`. Local main was fast-forwarded
  to its independently advertised ref; T06 uses `codex/v1-t06-safe-discovery`.
  No agent merge or broader main/release authority was inferred.
- Separator-aware canonical comparisons use OrdinalIgnoreCase. Selected
  input/output reparse ancestry is rejected; explicit literal recursion skips
  descendant directory/file reparse points with console/log reasons. Enumeration
  and generated-identity access errors abort a complete scan before prompts,
  run/log creation or conversion. Empty input now also creates no run/log.
  Inputs are returned in ordinal case-insensitive full-path order before any run
  is created. Nested output parents/Music-as-input are valid; planned output must
  not equal or contain the input. Selecting recognized generated ancestry fails.
- New roots carry a bounded self-identifying CreateNew JSON marker. Legacy roots
  require exact valid timestamp/rate names, matching initial log fields with
  absolute paths, and a mirrored direct input-leaf directory. Long logs use a
  bounded prefix. Prefix-only, malformed, drive-relative and mismatched identity
  folders remain eligible. Markers/logs confer exclusion only, never cleanup
  ownership; moved/copied roots retaining old absolute identity are unrecognized.
- Existing planned roots are refused both before prompts and at creation. This
  closes sequential reuse without claiming exclusive concurrent reservation,
  which remains T08. The historical optional configured-Music smoke pre-reserves
  a root and conflicts with that refusal; its current mode stops before any setup
  until T08 adapts its ownership scheme. Ordinary resolver mode remains current.
- A15–A17 pass on PS5.1/PS7: eight grouped focused cases per shell, deterministic
  17-file/8-skip snapshots, real loop/outside junctions, selected reparse ancestry,
  exact ACL-denied descendant abort/restoration, and repeated short real-FFmpeg
  runs with layout/title/64 kbps/full-decode/source-hash checks. File symlink
  creation is unavailable on this host (Win32 1314); an actual inert custom
  file reparse point exercises the same attribute skip without changing settings.
  Reports distinguish the unavailable symlink capability from the performed test.
- Initial harness failures (shell-specific bracketed junction targets/symlink
  capability) and baseline empty-input expectation failures remain preserved.
  Final reports explicitly identify the corrected harness and tested source.
  Sources, fixtures, ACLs and owned cleanup pass. No ordinary Music traversal,
  machine-setting change, downloads, manual/phone/long-audio/cancellation, CI or
  release evidence. Source replacement after discovery remains outside this
  snapshot's guarantees; date/Unicode/path allocation is the next task, T07.

## T07 reconciliation and naming — 11 October 2026

- Owner requested "T07 next please". PR #6 was owner-merged at 00:25:18 UTC
  into main `8599dfd9706d99119d4a38fb511968529e914246`. Local main was
  fast-forwarded to the independently advertised ref; T07 uses
  `codex/v1-t07-naming-planner`. No agent merge/release authority was inferred.
- A complete pure plan now precedes tools, write probes, prompts and run creation.
  Real invariant Gregorian dates are retained; impossible dates use LastWriteTime
  and keep the whole original basename as title input. NFC applies before and
  after filtering, including punctuation-joined Hangul. L/Nd scalar categories,
  whitespace, hyphen and underscore remain permitted. Noncomposing marks are
  removed; scalar-safe truncation does not claim full grapheme preservation.
- MaxBaseLength 24–180 measures UTF-16 units excluding .mp3, including date,
  separator, whole title scalar and complete suffix. Every collision recomputes
  from the untruncated title. Source order is OrdinalIgnoreCase then Ordinal;
  collisions use an OrdinalIgnoreCase destination set. Canonical duplicate inputs
  reject; case-only sources are retained. All rows validate before any plan emits.
- Preserved folder components are validated before normalization and never
  mutated. Complete destination file/working paths <260, directory paths <248
  and components <=255 remain the T02 compatibility policy. T09 must honor the
  fixed `.AudioFileForPhone-<32 hex>.partial` working-name length. Marker/log
  paths are included. Unexpected planned targets fail and FFmpeg uses `-n`.
- A18–A21 pass on both shells: 11 focused groups, shuffled 12-source mappings,
  date/locale/Unicode/counter boundaries, actual native file 259/260 and dir 247/248,
  real problematic-folder rejection, 19 fully decoded real MP3s per shell,
  12 collision suffixes and actual 180 basename/path 253. Retained FFmpeg/seven
  required companion checks, discovery eight groups, preflight 35/eight helpers
  and resolver ten cases pass. Final sources/fixtures, ACL restoration and cleanup
  pass. Test root names were shortened to fit enforced budgets; no limit was waived.
- Intermediate reports preserve actual failures and working hashes. Initial
  naming PS5.1 cleanup is unverified: native entries were removed but provider
  recursive cleanup failed; its short root leaf was not recorded and the machine
  TEMP parent disallows enumeration, leaving an unknown possible synthetic
  residue. No broad cleanup or ACL change was attempted. Later runs record owned
  identity and verify checked .NET cleanup. Final passing reports are explicitly
  identified; their hashes equal reviewed code checkpoint
  `e99f81ca3eb2c24102882e5723c52c236105450c` (only recorded CRLF/LF differences).
- Draft PR #7 is feature-synchronized; main awaits owner review. No ordinary
  Music traversal, settings/downloads, manual/phone, long-audio, cancellation, CI
  or release evidence. T08 is next: exclusive run/log reservation, synchronized
  races/sentinel preservation and adaptation of the deferred configured-Music
  smoke ownership scheme. This task does not complete the project/release.

## Change entry template

ID/date; reason; previous/new policy; owner authorization when required; affected
tasks/cases; regression checks; source commit; outcome. Do not replace this ledger
with a bare “approved” assertion without a traceable reference.

## T08 — exclusive roots/logs and M1 verification (11 October 2026)

- Owner requested "T08 next please". Fresh GitHub showed owner-merged T07 PR #7
  at 01:04:14 UTC into main e1ea2a95a5a9b7461d69101b6a111f26b51abbf6; local
  main fast-forwarded to the advertised ref before codex/v1-t08-exclusive-runs.
  Normal task writes, feature push and draft PR apply; no agent merge authority.
- Retained readable invariant timestamps and chose short numeric _N collision
  suffixes to preserve complete T07 path budgets. CreateDirectoryW, not a name
  suggestion or existence check, establishes ownership. Retry only occupied
  errors 80/183, bounded to 1000 default attempts; validate every actual suffix plan
  before creation and recheck new-root ancestry before marker/log writes.
- Provisional selection is read-only and picks a nonexistent candidate before
  snapshotting, so occupied unmarked audio beneath input remains discoverable.
  Root marker/log use CreateNew; ownership_token and exact cleanup_scope record
  the invocation. BOM and append preserve UTF-8 logs. Failed setup reports exact
  new scope/token and leaves it visible; no production recursive reclaim.
- Raw component validation now precedes output-provider normalization, preserving
  relative navigation and FileSystem PSDrive/provider resolution. Review caught
  the provisional absolute-only guard's compatibility/diagnostic regression;
  real malformed-parent and successful relative/PSDrive entry tests verify the fix.
- A22/A23 pass under both shells: 13 focused groups, four same-timestamp barrier
  processes obtaining counters 3/4/5/6 and separate real-entry relative/PSDrive
  conversions. Existing directory/file/log/marker/sentinel hashes are unchanged.
  Attempts/counter exhaustion, suffix overflow, CreateNew collisions and owned
  ACL/setup failures verify exact failure scope without reusing another root.
- Configured-Music smoke now executes unmodified runtime copies with synthetic
  TEMP input and no OutputParent or timestamp rewrite. Only a successful trusted
  child's exact returned direct Music root, matching runtime token/scope, fresh
  test token, nonreparse ancestry and complete expected inventory authorize its
  cleanup. No ordinary Music enumeration, settings/ACL change or broad cleanup.
- Full M1 matrix: 16 final current reports, retained FFmpeg/seven companions,
  preflight 35/eight helpers, discovery 8, naming 11/19 decoded outputs, native 35,
  resolver 10 and default Music. Source/fixture hashes, ACL restore, child disposal
  and exact cleanup pass. Native handle check finally ran sequentially with
  unchanged threshold 16: PS5.1 667->667 and PS7 575->575. One parallel handle
  growth observation remains failed; no root cause or threshold relaxation claimed.
- Preserve all 60 attempts (52 pass, 8 fail) with recorded payloads. Initial STA,
  child exit-code and prefix-check harness errors, old native fixture path 261 and
  provisional provider-guard failures are documented. Shortened only the owned
  native TEMP prefix; no path limit waiver. Failed OS user/computer diagnostic
  fields alone were redacted. Every T08 attempt verifies owned cleanup; T07's
  unknown possible TEMP residue remains unverified and must not be inferred clean.
- Independent review has no remaining blocking issue. Code checkpoint
  3b6c4164c6e4dd4b58f0be074c17f6fb854b41be was pushed and matched fresh advertised
  feature ref; evidence manifest verifies 12 runtime/test fingerprints, allowing
  only recorded Git CRLF/LF normalization. Draft PR #8 follows normal authority.
  Final docs-only checkpoint requires its own fresh ref check in response/PR.
  Main integration remains owner-gated; no CI/manual/phone/tag/release claimed.
  Exactly next task is T09 staged validation and no-overwrite output promotion.

## T09 — staged validation and publication (11 October 2026)

- Owner requested "T09 next please". PR #8 was owner-merged at 05:17:22 UTC into
  main 347b8656068b5e26b45410b830025de51000659f. Fetch, URLs/overrides, clean state
  and fresh advertised refs were reconciled before branching
  codex/v1-t09-transactional-output. Ordinary commits, feature push and draft PR
  remain authorized; no main merge/release authority was inferred.
- Encode only CreateNew-owned fixed sibling partials with explicit MP3 muxer;
  retain no-delete file sharing through encoder/probe/full decode. Recheck
  volume/file-index identity before no-overwrite File.Move or current partial
  cleanup. Concurrent finals and changed working identity preserve their bytes.
  Unproved child exit retains visible incomplete residue; ordinary conversion
  remains unlimited, abnormal owned-child teardown waits at most five seconds.
- Require finite positive source audio duration (container fallback only for absent/
  N/A selected stream). Fail missing/invalid duration before staging. Validate
  nonempty MP3, one selected-rate audio stream and exact optional JPEG cover.
  Container bitrate is insufficient. Default CBR/metadata/input/layout/naming and
  sample-rate processing remain; no forced resampling or loudness change.
- Fixed 0.35-second source/header/decoded tolerance is deliberately absolute.
  Mandatory error-fatal output decode measures emitted PCM sample time using
  validation-only asetpts. This catches stale-header physical truncation and
  corruption; it adds a read/decode pass and long-file performance is unmeasured.
  61 tiny/normal format/sample/rate fixtures per shell max at 0.066125-second delta.
  Three requested 8 kbps/48 kHz combinations produce 32 kbps and are separately
  rejected rather than changing processing or waiving the requested audio rate.
- Result is counted once after transaction. Any subsequent log/diagnostic error
  explicitly reports actual published mapping or file failure and stops with
  exit 1. Actual entry fault child verifies preserved decoded output/mapping.
  General script/BAT batch exit/result policy remains T10.
- A24–A26 pass on both shells: 27 focused groups each, 61 decoded successes plus
  three rate rejects; 18 final reports also retain real FFmpeg/seven companions
  and affected preflight/discovery/naming/reservation/native/resolver/Music checks.
  Source/fixture/sentinel SHA256, byte-identical runtime copies, owned child
  disposal, applicable ACL restoration and exact owned cleanup pass. Sequential
  native handles 668 to 668 and 576 to 576 keep allowance 16.
- 27 raw attempts remain (21 pass/six fail). Initial baseline source-change
  failures, incompatible positive-rate fixture and diagnostic-wrapping/driver
  forwarding failures are documented. Attempt4's 60 OS-generated CLIXML identity
  values alone are redacted with metadata. No test outcome or fingerprint changed.
  T07 possible unknown synthetic TEMP residue remains unverified; no broad cleanup.
- Independent runtime/harness review has no blocker. Reviewed code checkpoint
  fcce28736081d799b29f4594b56bebafbad1a9f7 matches advertised feature ref.
  T09-tested-payload.json independently matches 13 runtime/test fingerprints to
  committed blobs with exact CRLF/LF-only normalization. Draft PR #9:
  https://github.com/PikkuJanne/AudioFileForPhone/pull/9.
  Evidence/handoff checkpoint follows; its final HEAD/live comparison is external.
  T09 main integration remains owner-gated; no CI/phone/manual/long-file/
  cancellation/source-replacement/release acceptance. Exactly next is T10.

## T10 — script and BAT results (11 October 2026)

- Owner requested "T10 next please". Fresh fetch/advertised refs and live GitHub
  verify owner-performed T09 PR #9 merge at 07:01:10 UTC into main
  d31f2deb76f2d0aa88e13fb5ca2e123c4f3d1cc6, with feature 84270ac6. Clean local main
  was fast-forwarded and codex/v1-t10-results created. Existing normal task scope
  grants feature edits/tests/commits/push/draft PR, not main merge or release.
- Select explicit 0 / Completed, 2 / CompletedWithFailures and 1 /
  FailedBeforeConversion or Failed. Reserve 130 for later controlled cancellation;
  BAT forwards inert 130 only in T10. Host binding/forced termination can differ.
  Independent files continue after source probe/native/transaction failure.
- Count the actual file outcome before diagnostics, success only after T09
  publication. Log errors are fatal and preserve original reason, mapping/output
  and counts; progress display errors warn/continue. Summary separates processed,
  converted, failed, unprocessed, excluded and unsupported, elapsed time and
  available paths. Keep legacy Summary totals and add normal RESULT record.
- A failed reserved setup can retain marker-only residue before returning its
  object. Primary helper error records exact scope/token; final availability text
  must not imply nothing was created. Actual child regression verifies it; no
  production cleanup/reclamation or filesystem transaction rewrite is added.
- BAT rejects zero/empty/multiple arguments including quoted-empty extras; keeps
  STA/DisableDelayedExpansion; captures child code immediately and preserves it
  through result printing/pause. Quoted input/script !/%/&/^/apostrophe/space forms
  pass. Percent transport is one caller substitution; previous caller expansion
  or extra CALL passes cannot be undone and Explorer/manual forms remain unrun.
- A27/A28 pass on both shells: 13 focused script groups, 14 independently decoded
  publications each; 52 cmd cases per driver, both actual branches each. Twelve
  final reports also retain FFmpeg/seven companions, transaction 27/61+three rate
  rejects, preflight 35/eight helpers and discovery eight. Source/fixture/sentinel hashes,
  byte-identical copies, child disposal, applicable ACL/link restore and exact
  owned TEMP cleanup pass. No ordinary Music enumeration or new resource claim.
- Preserve 32 raw attempts (26 pass/six fail). Empty-argument transport, automatic
  $Input, missing expected filename separator, multiline mapping and old fatal
  prefix matcher failures were harness errors, documented without waiving gates.
  Final payload reruns follow reviewed timeout guards and reserved-setup reporting
  refinement. All attempts retain source preservation/exact cleanup.
- Independent runtime/harness review has no remaining blocker. Code checkpoint
  478c0a0c6a2935eb7271c9d28771a63455307599 was pushed and matched fresh advertised
  feature ref. T10-tested-payload.json matches 11 runtime/test fingerprints from
  12 final reports to committed blobs, permitting only proven CRLF/LF conversion.
  Draft PR #10: https://github.com/PikkuJanne/AudioFileForPhone/pull/10.
  Evidence/handoff follows code; final HEAD/live comparison is external.
- GitHub lists zero Actions workflows; no CI execution claimed. Main integration
  is owner-gated. No cancellation, forced-close, phone/manual, full-disk, long-file,
  source-replacement or release acceptance. T07 unknown possible TEMP residue and
  T09 brief post-guard path interval remain. Exactly next task is T11, closing M2.

## T11 — cancellation and crash leftovers (11 October 2026)

- Owner requested "T11 next please". Fresh fetch/advertised refs/live GitHub verify
  owner T10 PR #10 merge at 07:18:35 UTC into main 82f0fd3, feature eeb15703.
  Clean main fast-forwarded before codex/v1-t11-cancellation. Normal feature scope
  remains authorized; main/release gates remain unchanged.
- Choose scoped supported-console Ctrl+C input after prompts; restore prior mode.
  Internal context flows through native/probe/validation/transaction; wait/drain
  polls 100 ms without ordinary runtime limit. Retain 5000 ms/1000 ms teardown.
  Request and non-overwrite publication have one per-instance ordering point.
  Completed output remains success; cancelled current file stays not_processed.
  Record Cancelled/130; diagnostics cannot mask cancellation.
- Suspend cleanup before native/validation until explicit exit proof returns.
  Exact identity/nonreparse working cleanup follows released native/guard handles.
  Abrupt unknown-exit throw retains recognizable partial and exact logged reason.
  No runtime process-name/PID termination or next-run reclamation is introduced.
- A30 pass; A29 controlled component and owner-confirmed PS5.1 physical manual1
  pass. Store PS7 manual1 failed in test-helper compiler setup before cases; its
  cleanup/hashes pass and physical=false. Explicit Framework references repair
  only the harness. Store PS7 7.6.6 manual2 now passes at actual test base
  18fd7a6cef6208db415c7fea17de07d7d4b50628; the owner confirmed "Done PASSED".
  Report exit130/counts, preserved decoded output, partial removal, log/mode,
  unrelated FFmpeg, source/fixture hashes and exact cleanup all pass. A29/A30 and
  T11 complete; M2 local acceptance passed. Three physical-mode reports retain
  two passes/one setup failure. Automated key records stay labelled automated;
  no phone result is invented.
- All 26 selected automated invocations pass: focused nine groups on PS5.1,
  bundled PS7 and Store PS7;
  full M2 retained/transaction/script/launcher/preflight/discovery/naming/reservation/
  resolver/default-Music/native matrix. Quiet native handles 673->673/580->580,
  unchanged allowance16. Selected hashes, child/ACL/link/TEMP/Music gates pass.
  Ordinary Music never enumerated. Manifest proves 16 runtime/test files against
  runtime code 71eee22c87b57cea60079419f063149703c7df5a and test-only compiler
  followup ac9cdedbb926d8ecfd6e21f1d26a713d27c09fd5, only CRLF/LF normalization.
  Distinct original/repaired harness bytes and actual report test bases remain.
- Preserve 33 raw automated reports (29 pass/four fail). Old optimistic partial
  assertion, inherited-console/DLL-lock fixture fault and CS0165 compiler failures
  remain. Attempt1 original cleanup=false survives later exact known sole-DLL
  hash/nonreparse/child-proof recovery; its marker/token had already gone, so later
  root absence does not retroactively satisfy original cleanup contract.
- Independent runtime/entry/harness review has no implementation blocker. Fixed
  controller candidate ownership (held parent/creation/image identity) and separate
  descendant-release cleanup guards before final tests. Actual killed hosts left
  live native children on both shells; known retained owned handles stopped them
  before fixture cleanup. No physical window-close/power-loss claim.
- Code checkpoint committed/pushed and freshly advertised-ref matched; draft PR
  https://github.com/PikkuJanne/AudioFileForPhone/pull/11. Evidence/handoff follows
  code. Zero GitHub workflows/checks; no CI/main merge/tag/release claim. Prior T07
  residue and T09 path interval remain. Evidence checkpoint 18fd7a6 was also
  pushed/live-matched. This manual acceptance closure changes only docs/evidence,
  so existing automated results remain valid. Exactly next implementation T12
  requires owner integration of T11 first.

## T12 — no-write preview (11 October 2026)

- Owner requested "T12 next please". Normal fetch, independently advertised refs
  and live GitHub verify owner T11 PR #11 merge at 08:06:36 UTC into main
  cb4ffc44d5ad78b575656ba44461db8b64ae7580, final feature f6633103. Clean local
  main was fast-forwarded before codex/v1-t12-preview. Normal feature scope
  continues; main and release gates are unchanged.
- Choose one documented DryRun switch. Existing discovery and complete batch
  naming allocation stay shared; branch before tools, write probes, cover work,
  prompts, cancellation registration and reservation. Previewed/0 counts no
  conversions and reaches the common explicit exit. Provisional timestamp/root,
  unknown durations and unverified permissions/tools/media/cover are visible.
- Six selected final reports pass on both shells: preview eight groups/eleven
  exact logged source-target mappings, independent 64 kbps MP3 probes/full decode;
  retained baseline/characterization; script 13 groups/14 decoded publications.
  Strict directories/files/hashes/modification-time/attribute inventories, zero
  guarded calls, source/fixture preservation, child disposal and exact cleanup pass.
  Default preview branch uses only an owned synthetic Music resolver.
- Preserve four failed harness attempts and one intermediate pass. Refresh stale
  enumeration metadata before inventory reads, fix driver array composition,
  assert actual warning meanings and the unchanged 259-unit file-path limit.
  Runtime was unchanged through those repairs; strict timestamp equality remains.
- Independent runtime/harness/raw evidence review passes. Code checkpoint
  b0c20f66e0d2c6af4f99232dc633c4eb201c6a57 was committed, pushed and matched its
  fresh advertised feature ref. Manifest proves eight tested files: three literal,
  five CRLF-to-LF only. Evidence/handoff follows in a docs-only checkpoint.
  Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/12.
  T12 main integration remains owner-gated; zero workflows/checks, no CI or release
  claim. Existing T07/T09/T11 limitations remain. Exactly next task is T13 after
  independently verified owner integration of T12.

## T13 — honest progress (11 October 2026)

- Owner requested "T13 next please". Fresh fetch/advertised refs and GitHub verify
  owner T12 PR #12 merge at 09:05:48 UTC into main
  ace0b7cfa6381ffcffb0e71f70f8346a31e04d6c, final feature fac5f09c. Clean local
  main was fast-forwarded before codex/v1-t13-progress. Existing feature scope
  continues; main and release gates are unchanged.
- Consume bounded latest-complete machine records from encoder stdout; retain
  separate stderr diagnostics. Caller-thread callbacks every 500 ms within a
  phase, immediate validation/promotion, no ETA. Unknown timing is indeterminate;
  encoding stays below 100 percent. Count actual published success/file failure
  before progress; batch uses converted plus failed and visibly retains failures.
  Disable optional observer/display after error while continuing pipe drainage.
- Fourteen selected final reports pass on PS5.1/7. Focused 17 groups per shell
  directly test code 8607569a7147aba836c2e7c4c36f4f0219369d58. Actual 3,605-second
  synthetic sources produce multiple positive live machine samples before
  publication and independently probe/full decode at 3605.047982 seconds,
  64 kbps MP3. Native 35, transaction 27/61 decoded, script 13, preview 8,
  cancellation 9 automated and retained baseline pass each shell. Quiet native
  handles stay 667->667 and 576->576; source/fixture/child/exact TEMP gates pass.
  Ordinary Music unused; preview rejects progress display/parser compilation.
- Preserve all 18 raw tests: 14 selected finals, two preliminary passes and two
  failures caused by new harness PowerShell variable collisions. Original false
  cleanup flags remain; separate exact-root recovery/historical code proofs bind
  later cleanup. Independent review confirms both known roots absent. No unknown
  T07 residue cleanup or retrospective successful original cleanup is inferred.
- Code checkpoint committed, pushed and freshly advertised-ref matched. Manifest
  proves 14 tested files literally or CRLF-to-LF only. Runtime/harness/recovery
  independent review has no blocker. Draft PR #13:
  https://github.com/PikkuJanne/AudioFileForPhone/pull/13. Evidence/handoff follows
  code in a docs-only checkpoint. Main owner-gated; zero workflows/no CI pass,
  no phone/manual/release claim. Existing T07/T09/T11 limitations remain.
  Exactly next task T14 after independently verified owner integration of T13.

## T18 — help, docs, version and support boundaries (11 October 2026)

- Owner requested "T18 next please". Normal fetch, independently advertised refs
  and live GitHub verify owner T17 PR #17 merge at 12:46:33 UTC into main
  efe928367fe6380afd754dbd2376766506dd6815, final feature
  a4c008d0a982d5fbb9ecc71668dcceb170957d6b. Clean main was fast-forwarded before
  codex/v1-t18-help-version. Normal feature edits/tests/commits/push/draft PR
  remain authorized; main integration and exact release gates are unchanged.
- Choose functions-only Get-AudioAppVersion as the sole authoritative runtime
  1.0.0 literal. Banner and manifest call it; log uses the manifest's value.
  Version example executes the real helper. T19 package builder must consume it;
  unknown app/provenance template fields stay null until real build evidence.
  No package, frozen ZIP or publication result is inferred from version setup.
- Replace the header with proper comment-help for all nine public parameters and
  five exact executable examples shared with README. Keep PS/BAT entry points,
  64 kbps CBR, Music default, MP3/M4A/OGG, layout, names and metadata. CHANGELOG
  marks 1.0.0 unreleased; SUPPORT maps claims to actual suite/evidence boundaries.
  No website placeholder, production downloader, telemetry or default loudness.
- Preserve the BAT's existing process Bypass and disclose it. Recommend read-only
  policy inspection/direct RemoteSigned, with optional personal-machine unblocking
  restricted to reviewed exact files when permitted. Never bypass enforced policy
  or disable endpoint protection; actual signing status remains unsigned. Public
  docs specify unsupported extensions, default artwork dropping/explicit replacement,
  chapter/player limits, exits, cancellation/partials and private local records.
- At code 15d8dc1f43199c08bdd12f3bc49cb093db7d2e9d, help attempt2 passes seven
  groups per shell and diagnostics final1 nineteen. Exact Get-Help Code examples
  produce twelve independently probed/full-decoded outputs per shell. Ten public
  PowerShell fences parse; policy/unblock/setup/interactive blocks are syntax-only.
  Preview/helper strict tree/hash/time/attribute inventories remain unchanged.
  Source/synthetic/positive release/child/exact owned cleanup gates pass; ordinary
  Music remains unused and no physical/manual result is claimed.
- Expanded routine CI final3 passes 102 required groups/three observations per
  shell: unit 31, dependency guards 22, retained baseline 7, help 7 and native 35;
  original legacy real-media passes. Local total is 256 groups/six observations,
  without double-counting CI child reports. Syntax covers 32 sources; explicit
  seven-file analyzer default Error/ten-rule gate is clean. Dependency records
  verify FFmpeg/ffprobe 9.0.2 and analyzer 1.25.0, retained outside Git. Raw final3
  keeps T17 namespaces but records actual T18 code; T17 final2 remains untouched.
- Adding help to routine CI preserves workflow/lock/initializer bytes, action
  pins, contents: read/no secrets/privileged triggers/persisted checkout token and
  current-run JSON-only uploads. BAT and original retained integration bytes are
  unchanged. Local Windows 11 PS5.1.26100.9444/PS7.6.5 acceptance is separate from
  historical hosted Server 2025 PS5.1.26100.33438/PS7.6.6 and future actual checks.
- Preserve failed PS5.1 help attempt1 at 5eb1374: helper import made the fifth
  multiline example's second line remarks, not executable Code. Hash/release/
  cleanup gates were true. Production help and README now share one line and
  both attempt2 reports pass. Earlier direct dependency host-check failure made
  no root/report. No failed attempt is retroactively relabelled successful.
- Review has no implementation/security blocker. Evidence/payload/source review
  bind actual reports to reviewed code; final push/live-ref and real hosted
  outcomes are recorded in the draft PR/response, not as a self-hash here.
  Main remains owner-gated. Historical T01/T11 manual, T16 regression, T07 residue,
  T09 path interval, T11 forced-host and T14 persistence limits remain. No fresh
  phone/MTP/player/Explorer/NAS/UNC/network Music/frozen ZIP/public acceptance.
  Exactly next task is T19 after independently verified owner integration of T18.

- Reviewed T18 code 15d8dc1 was pushed and independently matched its live advertised feature ref; draft PR #18 is attached. Evidence checkpoint and actual new hosted checks follow without a self-referential containing SHA. Main integration remains owner-gated.

### T18 hosted inventory repair and final local selection

- Original push/PR runs 38141841561/38141855067 at 15d8dc1 and
  38141923121/38141927318 at docs checkpoint 634cc59 failed the PS7 help suite;
  PS5.1 passed. The failed line/old case-sensitive comparison supports an inferred
  owned-root casing diagnosis, corroborated by the repaired differently-cased
  regression. Failed raw reports do not contain the exact Get-Item root casing.
  First-push PS7 raw reports
  and all actual run metadata remain preserved without rewriting failed statuses.
- Repair only tests/Test-HelpVersion.ps1: canonical owned root/prefix comparison
  uses OrdinalIgnoreCase, strict descendant containment remains mandatory, and all
  remaining relative names/type/bytes/hash/time/attributes stay exact. An alternate
  root-spelling regression runs inside the existing first group. Production,
  source safety, owner/reparse checks, cleanup and all CI rights/pins remain intact.
- Repaired reviewed code 3766e168a1cf983d38b3a079d14d0fb589c0e6ae was pushed
  and independently matched the live feature ref. Both local final4 CI executions
  pass 102 groups/three observations. Retain diagnostics final1 at actual 15d8dc1
  because all four sources match 3766e16. Final local aggregate is 242 groups/six
  observations, counting CI and diagnostics once; initial 256/six remains historical.
- Final4 dependency records are byte-identical provenance copies of final3,
  preserving actual setup invocation/tested_commit 15d8dc1 and reused verified
  roots. No new provisioning is inferred. Final2 payload/review select sixteen
  actual reports; current CI actually tests 3766e16. Original payload/review/raw
  reports remain unchanged. Repaired push 38142296899 and PR 38142299941 pass
  both Windows jobs. Fresh API/refs prove actual integration
  c721ed64d188fbdc9c761e19bb7f16d64ff70873 and complete tree equal to 3766e16.
  Fourteen exact selected PR raw reports record the actual integration commit;
  parent CI GitHub fields confirm SHA/run/event while absent child fields stay
  absent. T18-hosted-payload.json binds raw/source bytes. Hosted 204/six supplement
  local 242/six, with actual Server 2025 image 20260925.250.1/PS5.1.26100.33438/
  PS7.6.6/FFmpeg 9.0.2/analyzer 1.25.0. T18-ci-runs.json preserves four failed and
  two green runs; no failed report is rewritten as passing.
  PR #18 remains draft, main owner-gated; exactly next T19 after
  integration. Project/release and existing manual/device/security limits remain.

## T19 — exact-commit packages and external dependencies (11 October 2026)

- Owner requested "T19 next please". Fresh fetch, independently advertised refs
  and live GitHub verified owner T18 PR #18 merge at 13:35:59 UTC into main
  948d27c264a825e49e0ec3b6cc6b5c54542a70b0. Clean main was fast-forwarded before
  codex/v1-t19-package. Normal feature edits/tests/commits/push/draft PR remain
  authorized; main integration, repository settings and release gates are unchanged.
- Choose an explicit eight-root-file allowlist: entry PS1, functions-only helper,
  BAT, README, SUPPORT, CHANGELOG, SECURITY and MIT LICENSE. Keep FFmpeg/ffprobe,
  tests/CI/build rules, media/logs/caches, poster and handoff evidence outside ZIP.
  A supplied clean detached full lowercase commit must equal HEAD. The builder
  verifies exact Git blob bytes, member modes, path/reparse boundaries, source/
  input preservation and required omissions. Get-AudioAppVersion supplies the
  version/tag; no independent build version constant or runtime behavior change.
- Publish three complete local assets in one move after verification: ZIP,
  external manifest and SHA256SUMS covering ZIP/manifest only. Record actual
  member hashes/sizes, signatures, tool/version/capability identities and build/
  input digests. Supplied test references are caller attestations; the builder
  checks schema/commit/status/hash, while the operator independently audits real
  reports. Unsigned scripts and external vendor licenses/trust limits remain
  explicit. No downloader, telemetry, account, global setting or production Python.
- Preserve initial C0 d69732aa91bde6ccf966cb584544251b463004e4 and all its raw
  evidence. Actual clean-source builds failed because ambient Git autocrlf=true
  changed eight LF blobs to CRLF. C1 1cb92a18ed162861b286a47cabb6ae365ee8b4e0
  applies archive-command-only autocrlf=false/eol=lf, retaining byte/attribute
  checks and making no persistent config change. C1 hosted 51-case reports had
  empty LF member lists, despite local LF coverage. C2 verifies ten copied files
  before normalizing only owned fixture README CRLF bytes; source/BOM/lone CR stay
  unchanged and README must be in the regression's LF list. Both actual C2 hosted
  shells prove that member and exact same-shell repeated asset bytes.
- Reviewed C2 70d1e2f3b47b84b595915c73a6ecb1b09d981d8e was normally committed,
  pushed and independently matched to its live feature ref. Active Windows 11
  PS5.1.26100.9444/PS7.6.5 selection passes 1,196 required executions plus six
  observations, 34 aggregate/48 raw reports, 45 sources and 644 relationships.
  Thirty actual C0 milestone and two actual C1 guarded Music reports are retained
  only with independently proved source equivalence at C2. Final21 routine CI
  actually tests C2: 153 groups/three observations each, 34 parsed sources and
  nine-file pinned analyzer 1.25.0 Error/ten-rule gate with zero diagnostics.
  Children/focused runs are not counted twice. Dependency copies retain actual
  setup 15d8dc1 and byte-identical final4 provenance; no fresh provisioning.
- Two actual clean detached C2 builds pass independent eight-member Git blob,
  manifest/checksum/tool/report/signing audits; all 659 tracked files stay unchanged.
  Cross-shell ZIP, manifest and checksum bytes differ, although decompressed
  members match. These are exploratory source builds; integrated freeze and exact
  ZIP runtime/device acceptance remain later gates. Original manifest copies and
  concrete expanded argv/raw-stream bindings remain evidence, with ZIPs outside Git.
- C2 push 38147793935 and PR 38147797740 pass all four hosted Windows jobs.
  Actual test merge 20f9a65b00fc884a96f46f918eec65584c6fe391 has complete tree
  4cd70be37d41ee9debda25cfc53f6894dad6417d equal to C2. Sixteen original PR
  reports bind 45 sources/332 relationships and pass 306 groups/six observations.
  Actual Server 2025/PS5.1.26100.33438/PS7.6.6 remains separate from local evidence.
- Preserve all preliminary false cleanup/archive failures, unsupported analyzer
  wrapper parameter and captured C2 inspector module-autoload failure. Child-only
  removal of inherited PSModulePath resolves the latter without global/source
  changes; earlier C0 inspector cause remains unproved. Three automatic cleanup
  reviews rejected actions before execution, citing only "blocked by policy";
  retained scopes and raw flags stay documented, with no equivalent retry.
- A47/A48 pass; independent review has no unresolved source/security finding.
  Final docs-only evidence checkpoint, latest checks and fresh advertised-ref match
  belong in draft PR #19 and the response without a self-referential containing SHA.
  Main remains owner-gated; exactly next T20 after owner integration. Project/release
  and existing manual/device/security limits remain incomplete; loudness deferred.

## T20 start and manual acceptance checkpoint — 11 October 2026

- Owner requested "T20 next please". Live PR #19 is owner-merged at 15:19:08Z,
  feature 4aa3dd3 and main da2a627 independently advertised/API-matched. Clean main
  was safely fast-forwarded and codex/v1-t20-windows-acceptance created. Normal
  T20 edits/tests/feature push/draft PR are authorized; main/release gates stay.
- Ordinary-user Windows 11 26300.9457 PS5.1.26100.9444/PS7.6.5 focused support
  passes 182 checks in eight executions, with original T16 raw fields/bytes,
  eight report hashes, 26 source relationships and exact owned cleanup retained.
  Runtime, existing tests, CI/build/defaults remain unchanged; no broad personal
  media/Music access or global settings change. Main CI 38150774320 passes.
- Added only a guided manual procedure and retained owned synthetic preparer.
  Actual both-shell parse/preparation passes; each success has 13 completed/released
  bounded native calls, eight short fixtures, exact app copies and empty output.
  First PS7 duplicate-Git path failure remains preserved with its own retained
  marker/report-only scope; no cleanup/current-source success is retroactively
  assigned. Successful fixture trees remain intentionally retained for the owner.
- A49/A50/T20 stay blocked: named physical Windows actions and an explicitly chosen
  representative legally held over-hour input/time/resource/playback observations
  have not arrived. Native app UI is unavailable in this session; old physical or
  automated input/long/default evidence cannot invent current named observations.
  Asked owner for tester identity/local selected path and availability; no personal
  media search. Exactly next continue T20, not T21; project/release incomplete.

## T20 simpler owner check and automated representative file — 11 October 2026

- Janne Vuorela supplied his identity and exactly one local legally held podcast,
  requesting: "The test needs to be much simpler for me, or automated, please
  revise". This steers the same T20 task. The file is 79m35.055646s mono MP3;
  only that selected regular file was read/copied, without personal-folder search.
  Its public identity is T20-long-01; paths/names/tags/media/raw logs stay private.
- Revise A50's quantitative method explicitly in task/strategy/acceptance tracking
  to automated owner-selected real-media checks plus controlled default-Music
  smoke, preserving duration/resources/default-path/policy expected outcomes.
  A49 physical actions and T21 actual player/phone listening/seeking remain.
  No automated decoder result is a named playback observation.
- Fresh PS5.1/PS7 final1 runs actually test f992a54, whose runtime blobs equal
  integrated main da2a627. App host elapsed34.633/37.353s; actual host/FFmpeg
  CPU/memory/sample scopes are recorded. Both Completed/exit0 outputs are
  38,201,262bytes with identical hashes, zero duration delta, 182,798frames all
  64kbps, independent full+near-end decode and preservation gates passed.
  Observed retained processes exit/dispose naturally without controller kill;
  eight bounded native verifications per shell finish/release. These are two
  real acceptance runs, not added to the earlier 182 supplemental-case count.
- Preserve failed PS5.1 attempt1: runner assumed flat output rather than the
  unchanged app's recursive wrapper. It does not have completed independent
  verification or an original runner snapshot; no pass is inferred. Fresh finals
  use owned literal recursion, PID-reuse acquisition guard, forced-kill fail gate
  and exact runner before/snapshot/after hashes. Three owned roots remain retained
  outside Git; no cleanup attempted and no old retained-scope record changed.
- Replace the 129-line manual procedure with one guided command. Owner only does
  one mixed-corrupt folder-on-unchanged-BAT drop, actual STA select/Cancel in both
  shells and physical READY Ctrl+C in both; windows, preset synthetic metadata,
  verification and local capture are automated. Hash-bound copies of installed
  FFmpeg may be placed beside the private app for existing Explorer discovery;
  no download/global setting/runtime/Git/package binary change. BAT shell/exit/
  output are explicit uncaptured limits, and unknown Music output remains untouched.
  Original newly created cancellation reports keep their task/A29/commit IDs and
  bytes when relocated from exact fresh paths to local owned guided-results root.
- A50 passes; A49/T20 remain blocked until Janne's actual actions/confirmation and
  captured evidence are reviewed. Old T20-review.json stays frozen; new revision
  review/feature sync/CI accompany this checkpoint. Main integration remains
  owner-gated, exactly next continue T20, with project/release/phone unfinished.

## T20 recovered selection and simpler completed method — 11 October 2026

- Janne reported the cover mismatch after trying both PNGs and requested simpler
  testing again. Actual PS5.1 Desktop STA capture already records exit0, Completed,
  converted3/failed0. The guide wrongly demanded a 64x64 fixture, rejecting the
  valid selected tracked 2816x1536 poster. Preserve the failed aggregate and reuse
  independently verified capture/outputs.
- Correct only the guide verifier: accept actual valid regular JPG/PNG, bind
  source hash/dimensions, compare embedded artwork and retain captures before
  verification. Both-shell actual-function checks pass and reject false Cancel;
  thirteen bounded natives release each. No new UI/application execution.
- Both recovery verifier shells inspect the actual PS5.1 outputs; each records
  sixteen released natives, 41 unchanged bindings and metadata/layout/date/64kbps/
  duration/full audio-art decode success. PS7 verifier is not PS7 UI. Fresh unchanged
  both-shell cancellation tests add eighteen automated passes, with controlled
  input, owned process release, interrupted-output safety and unrelated-process
  survival; no hardware/manual action claim.
- Explicitly revise A49 at his repeated request to named interactions plus real
  automated both-shell Windows tests. Janne confirmed actual test-folder BAT drop
  showed Completed with failures. BAT shell/raw exit/output root remain unknown
  and its Music output untouched. Current PS7 picker, physical Cancel, hardware
  Ctrl+C and physical fallback remain disclosed coverage limits.
- A49/A50 pass; T20 done on feature, no further owner Windows test required. Preserve
  old reviews/failed reports/private scopes; create a focused recovery review.
  Runtime/helper/BAT/tests/CI/build/defaults remain unchanged. Last verified feature
  checkpoint 1e9e5de has both push/PR CI jobs green. Final recovery sync/checks
  belong in PR/response. Main integration owner-gated; exactly next T21 after
  integration. Project/release/phone acceptance incomplete.

## T21 minimal phone acceptance start — 11 October 2026

- Owner requested T21 next. Fresh fetch, advertised refs and live GitHub establish
  his PR #20 merge at16:44:42Z into main3e5b6fb, final feature67dee7e and identical
  complete trees. T20 final push/PR jobs all green; main push38156733341 initially
  running. Clean local main fast-forwarded; codex/v1-t21-phone-acceptance created.
- Keep simpler-testing preference: reuse the exact verified 79m35 long output,
  preserving original f992 generation identity and equivalent current runtime;
  prepare two short friendly-tag/blue-cover/order/chapter fixtures through current
  unchanged app. All media/logs/probes outside Git, no personal/Music search.
- A51/A52 still require actual named phone results; readiness/decode is not phone
  evidence. Asked for device/OS/player versions and transfer method while local
  preparation proceeds. One brief session covers start/middle/near-end listen/seek,
  duration/resume, tags/art/order and actual chapter availability. No new app,
  screenshots, command editing or full-length listening required.
- T21 remains blocked pending actual observations. Exactly next continue T21,
  not T22; main integration/release gates and deferred loudness unchanged.

- Actual preparation completes first run at main3e5b6fb in ordinary PS7/Windows11;
  both-shell parse passes, 16 direct native calls completed/released, all source/
  copy/input/tool/runner/marker/long preservation passes. Ready local scope
  T21P-06b84fc67184/Phone holds exactly three verified MP3s. Short tags/blue64x64
  attachedJPEG/track-disc/two chapter fields and audio decode pass; generic aliases
  are byte-identical copies of actual date-first app outputs. Long remains exact
  originalf992 generation bytes; runtime blobs equalmain3e5. Private records bound
  by hashes, original source unaccessed, no cleanup or phone-success claim.
- Review scopes release to16 direct helpers; independent nested descendants and
  timeout containment are not observed. Preserve completed source/report snapshots,
  document limit in binder; no rewrite/rerun is necessary for this successful
  no-timeout execution. Main CI38156733341 later passes. Phone question now gives
  the exact folder and one short session; device/player/transfer/results pending.

## T21 actual owner phone report — 11 October 2026

- Janne reports "All worked. Samsung A56, Android One UI 8.5, AIMP, usb cable"
  in response to the three-file phone procedure. Preserve that exact quote and
  derive only the unconditional prompted results: playback/seeks/duration/resume,
  tags/blue cover/order. These are named owner observations, not Codex measurements.
- Keep OS wording exactly supplied. AIMP's version remains missing; conditional
  "chapters if available" does not establish chapter availability/navigation.
  Ask one brief record clarification without another test. Scope every claim to
  this phone/player/assets; infer no base Android release, USB/MTP mode or phone hash.
- Recheck only exact known Windows assets and frozen runtime/report identities.
  Keep historical preparation-only and T20 evidence unchanged. No app/test/CI/build
  changes, personal source/Music scan, media in Git or repeated conversion.
- Existing e2b9a22 feature sync and both push/PR Windows matrices pass. PR21 remains
  draft/unmerged, main3e unchanged. A51/A52/T21 remain blocked only pending version
  and chapter detail; next continue T21. Main/release authority stays unchanged.

## T21 final phone acceptance and owner human-test closure — 12 October 2026

- Janne's final response supplies Samsung S24, One UI 8.5, AIMP v4.31.1747 and
  USB cable, confirming long audio works, resumes and other checks work. Use
  this corrected device; preserve earlier A56 report/review bytes as historical,
  without claiming a second accepted phone or additional observed test run.
- A51/A52 pass for the same exact three prompted assets. Chapter controls are
  unavailable and navigation not run. This satisfies A52's documented limitation
  comparison, without inventing navigation support or changing its method.
- Honor the explicit owner declaration that human testing is completed. No further
  human test or clarification is requested. Preserve actual scope and untested
  limits; automated milestone/ZIP checks and main/release authority remain.
- New final observation/review artifacts supersede missing details without editing
  old reports. Update README/SUPPORT only for this narrow accepted phone scope.
  Runtime/helper/BAT/tests/CI/build/defaults unchanged; no new media work/phone access.
- Previous35f275a live ref and both CI matrices pass; PR21 draft/unmerged, main3e
  unchanged. Complete T21 on reviewed/pushed feature, then exactly T22 after owner
  integration. Final sync/checks in PR/response; no project/release completion.
