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
| D17 | Fixed-rate whitelist and name limit 24–180 finalized in T02; requested ranges enforced in T04. Produced-rate validation and duration tolerance remain T09. | Ranges implemented; later validation pending |
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

## Change entry template

ID/date; reason; previous/new policy; owner authorization when required; affected
tasks/cases; regression checks; source commit; outcome. Do not replace this ledger
with a bare “approved” assertion without a traceable reference.
