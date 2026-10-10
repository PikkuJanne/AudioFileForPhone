# Roadmap and traceability

27 required, task-sized steps across seven milestones. O01 is optional/deferred.
Use one coherent task per thread. This plan implements outcomes, not a rewrite.

## M0 — Baseline and continuity

Confirm the real checkout, preserve existing behavior and establish handoff checkpoints.

- [T01: Reconcile checkout, import handoff, establish checkpoint](tasks/T01.md)
- [T02: Capture baseline behavior and test contracts](tasks/T02.md)

## M1 — Safe foundations

Isolate tests, validate inputs, control subprocesses and allocate paths safely.

- [T03: Add OutputParent and isolate ordinary tests](tasks/T03.md)
- [T04: Extract small helpers and implement preflight](tasks/T04.md)
- [T05: Centralize native execution and media inspection](tasks/T05.md)
- [T06: Bound recursive scanning and exclude prior output](tasks/T06.md)
- [T07: Make date and filename allocation deterministic](tasks/T07.md)
- [T08: Reserve unique run roots and logs exclusively](tasks/T08.md)

## M2 — Reliable conversion outcomes

Prevent final-looking partials; handle batch errors, launcher codes and cancellation.

- [T09: Stage, validate and safely publish each output](tasks/T09.md)
- [T10: Unify script and BAT result reporting](tasks/T10.md)
- [T11: Handle cancellation and crash leftovers safely](tasks/T11.md)

## M3 — Everyday usability

Preview, progress, persistent diagnostics and predictable metadata.

- [T12: Add side-effect-free preview using the real planner](tasks/T12.md)
- [T13: Show per-file and batch progress honestly](tasks/T13.md)
- [T14: Add persistent diagnostics and a usable run manifest](tasks/T14.md)
- [T15: Stabilize metadata, explicit covers and chapter documentation](tasks/T15.md)

## M4 — Tests, documentation and packaging

Complete regression coverage, secure CI, help/version and package build policy.

- [T16: Complete the regression and fault-injection matrix](tasks/T16.md)
- [T17: Add secure Windows CI and a release gate](tasks/T17.md)
- [T18: Finish help, docs, version and support boundaries](tasks/T18.md)
- [T19: Define package build and dependency/security policy](tasks/T19.md)

## M5 — Acceptance and frozen candidate

Obtain real Windows/phone evidence and test the exact clean-commit ZIP.

- [T20: Perform real Windows acceptance on both shells](tasks/T20.md)
- [T21: Record phone playback, seeking and metadata acceptance](tasks/T21.md)
- [T22: Audit all required outcomes and integrate reviewed work](tasks/T22.md)
- [T23: Freeze C, build clean ZIP and preserve candidate evidence](tasks/T23.md)

## M6 — Publication and closure

Verify draft, publish normal v1.0.0, verify public bytes and synchronize final main.

- [T24: Authorize exact tag and prepare the draft release](tasks/T24.md)
- [T25: Verify uploaded draft assets before publication](tasks/T25.md)
- [T26: Publish public v1.0.0 and verify real downloads](tasks/T26.md)
- [T27: Close with synchronized evidence and immutable release](tasks/T27.md)

## Accepted review mapping

| Review item | Required task coverage |
|---|---|
| 1 | T09, T11, T22 |
| 2 | T10, T22 |
| 3 | T08, T22 |
| 4 | T02, T04, T05, T22 |
| 5 | T06, T22 |
| 6 | T05, T11, T22 |
| 7 | T02, T07, T22 |
| 8 | T03, T12, T22 |
| 9 | T13, T14, T22 |
| 10 | T02, T15, T22 |
| 11 | T04, T22 |
| 12 | T02, T03, T16, T20, T21, T22 |
| 13 | T01, T17, T22 |
| 14 | T18, T22 |
| 15 | T01, T19, T20, T22, T23, T24, T25, T26, T27 |
| 16 (optional) | O01 |

All required acceptance cases start not_run. “Done” requires actual evidence and a verified push checkpoint; the release additionally requires external publication/download and final main synchronization.
