Continue the existing PikkuJanne/AudioFileForPhone v1.0.0 project.

Read applicable AGENTS.md, then docs/codex-v1/STATUS.md, NEXT_SESSION.md,
TASKS.json, DECISIONS.md and SYNC_PROTOCOL.md. Reconcile actual local status,
fetch/push URLs, live active branch and main against the recorded handoff.
Preserve unrelated local work; never reset/clean/force-push to hide divergence.

Validate the previous checkpoint first. Select exactly the next dependency-ready
required task named in NEXT_SESSION.md. Read only that task and the relevant specs
and acceptance cases, then complete it. Do not repeat the whole repository audit
unless new evidence requires it. A milestone is not a single context window.

Preserve the existing local PowerShell/FFmpeg workflow and defaults. Improvements
1–15 are required; optional O01 loudness work stays deferred unless an owner decision
activates it. No website work and no intermediate public releases.

Keep test results/evidence truthful. Follow the established commit -> push -> live
branch comparison checkpoint. Update TASKS.json, STATUS.md and NEXT_SESSION.md,
including blockers, exact commands/results, integration state and next prompt.
Use the authority file for merges/publication; do not infer missing approvals.
If this is a release task, obey RELEASE_RUNBOOK.md and the frozen candidate.
Finish with the verified branch/commit, test summary and next task. Never call
this project complete merely because code, a ZIP, a tag or a draft is ready.
