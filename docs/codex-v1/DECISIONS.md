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
| D17 | Bitrate whitelist/ranges, name-length minimum and duration tolerance must be finalized from tests in T02/T09. | Open engineering detail |
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

## T02 reconciliation and engineering proposals — 10 October 2026

- Owner requested T02 and a handoff that clearly states the next suggested step.
  PR #1 was already merged by the owner at 19:45:49 UTC. T01 is now integrated
  into main `483af25f8e5fa9dee295f5b74130324663339e37`; no agent merge was performed.
  T02 uses fresh branch `codex/v1-t02-baseline` rather than the merged PR's branch.
- `T02_REGRESSION_MATRIX.md` records formats/defaults/tags/names/exits/source
  safety before application changes. Proposed D17 limits are the documented
  LAME fixed-rate union, `MaxBaseLength` 24–180 UTF-16 units, default 60, with
  independent final/working path checks below legacy Windows limits. Empirical
  finalization remains blocked by unavailable FFmpeg/ffprobe; do not treat these
  limits as implemented or tested. Duration tolerance remains assigned to T09.
- Retain D13 root rejection, D14 descendant-directory reparse skips and D15
  abort-before-conversion on scan access errors. Proposed T06 refinement also
  rejects a selected reparse directory and skips file reparse points to avoid
  out-of-tree source/cleanup boundaries; it needs focused Windows tests.
- Adopt the already proposed future outcome contract 0/1/2/130 from UX_RESULTS
  for all-success/preflight-or-empty/per-file-failure/controlled-cancel. Baseline
  runtime results are still unrun; implementation and BAT propagation remain T10/T11.
- The test-only T02 adapter substitutes the Music resolver in disposable copies;
  no production environment-variable backdoor or known-folder registry change
  is introduced. A04–A06 still require real media execution on both shells.
  Because native dependencies are missing, the isolation-only T03 scheduling
  exception does not apply. Next suggested step: provide a local FFmpeg/ffprobe
  pair and resume T02; start T03 only after required baseline evidence passes.

## Change entry template

ID/date; reason; previous/new policy; owner authorization when required; affected
tasks/cases; regression checks; source commit; outcome. Do not replace this ledger
with a bare “approved” assertion without a traceable reference.
