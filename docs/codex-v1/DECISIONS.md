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

## Change entry template

ID/date; reason; previous/new policy; owner authorization when required; affected
tasks/cases; regression checks; source commit; outcome. Do not replace this ledger
with a bare “approved” assertion without a traceable reference.
