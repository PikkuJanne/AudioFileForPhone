# Current project status

State: **T14 complete; A35/A36/A37 passed; main integration pending.**
Last completed task: T14. Exactly next implementation task: T15 after owner
integration of T14. Required improvements 1-15; optional O01 deferred.
Project/release are incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t14-diagnostics.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T13 PR #13 at 10:20:45 UTC on 11 October 2026 into main
  1af19a7d4f0d898a1fadc0914c81b99490affd80; final T13 feature
  b9d1652258ba31c20d832de505b7fe8828db3410. Normal fetch and independently
  advertised refs matched; clean local main was fast-forwarded before this branch.
  T01-T13 are integrated; prior M2 local acceptance remains passed.
- Reviewed/tested T14 code checkpoint b272cfda70861e0058aceaa60066e06d3c0ffc17
  was pushed and matched its freshly advertised feature ref. Evidence/handoff
  follows in a docs-only checkpoint; final HEAD/live proof belongs in PR/response.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/14.
  **Feature synchronized; T14 main integration owner-gated.**
  No Actions workflow/check pass is claimed.
- Windows 11 Pro 26300.9457; Windows PowerShell 5.1.26100.9444 and bundled
  PowerShell 7.6.5. Existing C:\ffmpeg\bin pair, build
  2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev. No download/settings change.

## Verified behavior and evidence

Each reserved conversion run has AudioFileForPhone_log.txt and
AudioFileForPhone_manifest.json. Actual tool versions, policies and development
app identity with entry/helper hashes persist locally. Source probe, encoder,
output probe and full decode retain status/exit/release/timing plus at most
16,384 stderr characters per stage; no stdout/progress dump. Reasons/errors are
bounded to 2,048 characters and measurement errors to 512.

JSON rows map every supported snapshot input to its planned output, outcome,
available duration measurements and actual byte counts. Converted, Failed,
Cancelled and NotProcessed counts reconcile to supported. Manifest not_processed
is unstarted; not_completed adds cancelled, matching legacy console semantics.
Scan exclusions/unsupported counts remain separate. Unknown durations are null.
CreateNew staging and identity-checked replacement persist setup, file boundaries
and final state. Required-record failure stops with 1 and preserves actual outcomes;
cancellation retains 130. A last-good Running snapshot is visibly incomplete.
Preflight-before-reservation and DryRun create no records. Public issue guidance
asks for redacted excerpts; no automatic upload exists.

Sixteen selected final reports pass across both shells: 270 required groups/checks
plus six baseline observations. Diagnostics directly tests code b272cfda: 19 groups
per shell, real Unicode/multiline metadata and JSON roundtrip, mixed formats/corrupt
input/exclusions, actual native failures and bounded floods, six recording faults,
occupied/foreign manifest identity, post-promotion guard failure, three controlled
cancellation variants and immediate startup cancellation. Fourteen published
synthetic outputs per shell independently probe as 64 kbps MP3 with matching
duration and fully decode; filesystem lengths verify recorded bytes.
Source/synthetic, native release, retained-host disposal
and exact TEMP cleanup gates pass.

Affected native (35), transaction (27/61 decoded matrix outputs), script (13),
preview (8), cancellation (9 automated), progress (17) and retained baseline
(7 required checks) pass per shell. Quiet native handles stay 667->667 / 577->577,
allowance 16 unchanged. The actual 3,605-second progress fixture fully decodes at
3605.047982 seconds with live samples before publication. Preview preserves strict
refreshed whole-tree inventory and zero operations. Ordinary Music was unused.
Tested-payload manifest binds 15 files/78 source-report pairs to the reviewed
commit: two literal matches and thirteen proved CRLF-to-LF matches. Root and
independent review recomputed the proof separately; BAT bytes are preserved.

## Preserved limitations and next action

Nineteen raw test reports remain: sixteen selected final passes, two preliminary
passes and one failed new-harness attempt. Its path classification and driver BOM
were repaired only in the harness; production stayed frozen. Original false
children/cleanup flags remain. Separate historical-harness proof and two recovery
records establish later exact known-root deletion after independent review.
The first recovery refused before deletion due to timestamp serialization;
the successful one compared exact UTC ticks and all other fields without tolerance.
No blanket cleanup/process kill occurred. Details, exact commands and provenance:
evidence/T14.md, T14-tested-payload.json and TEST_STRATEGY.md.

Records may contain private paths/metadata; sharing requires redaction. Final
record failure/forced shutdown can leave the last durable snapshot; filesystem
replacement is not a crash-durability guarantee. Preserve T07 possible unknown
TEMP residue, T09 brief post-guard path interval and T11 host/forced-shutdown limits.
Physical T11 evidence is historical; no new phone/manual console/CI/release
acceptance is inferred. The next full applicable suite is at the M3 boundary.

Owner review/integration of draft PR #14 remains pending under AUTHORITY.md.
Exactly next implementation task is T15, metadata, explicit covers and chapter
documentation, after its merge is independently verified. No tag/release created;
exact commit/assets, ZIP, draft/public download and final main closure remain
governed by AUTHORITY.md and RELEASE_RUNBOOK.md.
