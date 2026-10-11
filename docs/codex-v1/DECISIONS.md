# Decisions and policy ledger

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
