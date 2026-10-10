# Project control index

Read `STATUS.md`, `NEXT_SESSION.md` and `TASKS.json` at every session start. Read
`AUTHORITY.md` and `SYNC_PROTOCOL.md` before any remote write. Then load only the
next task brief and its relevant specs/cases; do not load this whole directory
into every Codex thread.

- `ROADMAP.md`: seven milestones and review-improvement mapping.
- `BASELINE.md`: inspected snapshot, preserved behavior, risks; not a test report.
- `DECISIONS.md`: default policies and owner-approved changes.
- `ACCEPTANCE.json`: case identifiers, required/optional status and actual evidence.
- `specs/`: bounded contracts for safety, filenames, process/audio behavior and UX.
- `TEST_STRATEGY.md`: efficient synthetic, failure-path, Windows and phone checks.
- `RELEASE_RUNBOOK.md`: exact candidate, draft, publication and closure sequence.
- `templates/`: empty evidence forms; never substitute them for results.
- `tools/Test-GitSync.ps1`: non-mutating live-branch check; validate on Windows T01.
- `tools/verify_release.py`: optional stdlib technical public-release verifier.

Original requirements: improve, not rewrite; remain a local tool; synchronize
local/GitHub continuously; only public v1.0.0 ends the project; website later.
