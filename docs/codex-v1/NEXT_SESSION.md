# Next session

Task: **T02 — Capture baseline behavior and test contracts.**
Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T02.md, BASELINE.md, TEST_STRATEGY.md and DECISIONS.md.

Checkout: `C:\projects\AudioFileForPhone-main`.
Active branch: `codex/v1-t01-checkpoint`.
Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/1.
Last independently verified task checkpoint:
`2ead61ed51a3a6aeb93d2bdb341041f6490dceaf` (tested imported helper/source commit).
The final T01 documentation commit follows it; inspect actual HEAD/live refs.
Local/live main: `2bf1ea1921ab33633b978bd384bbbf098648ceed`; T01 is not merged.

T01 restored missing Git metadata only after explicit owner approval and verifying
all nine original files against GitHub. It imported 62 planning files, validated
the bundle, ran 41 Python helper tests under each shell and 46 PowerShell helper
cases (23 each), then pushed and passed live checks on both shells. Evidence:
`evidence/T01.md`, `T01-helper-results.json`, `T01-source-inventory.json`.
No application files or default behavior changed; no conversion/phone tests ran.

Environment: Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
FFmpeg/ffprobe were not found on PATH/in the checkout. The legacy integration
suite writes to ordinary Music and must not be run without proven isolation.
T02 should record a characterization matrix/fixtures and truthful blockers if
safe execution is unavailable. T03's documented scheduling exception is for a
later thread and does not waive A04–A06.

Existing authority covers ordinary implementation/tests/commits/task pushes and
draft PRs. The owner requested no repeated approvals for those actions. CLI auth
works outside the sandbox; the connected app cannot create PRs. No main merge,
bounded merge policy or exact release/tag authorization has been recorded.
Loudness remains deferred; website work is excluded. Public v1.0.0 is absent.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
Complete T02 only: capture baseline behavior and test contracts. Read AGENTS.md
and docs/codex-v1/INDEX.md, STATUS.md, NEXT_SESSION.md, TASKS.json, AUTHORITY.md,
SYNC_PROTOCOL.md, tasks/T02.md and its relevant references. Inspect actual status,
all fetch/push destinations and live refs; fetch normally and preserve all work.
Continue the existing codex/v1-t01-checkpoint branch and draft PR #1 unless fresh
state requires reconciliation. T01 passed; its tested/live checkpoint is
2ead61ed51a3a6aeb93d2bdb341041f6490dceaf, followed by final handoff documentation.
Local/live main was 2bf1ea1921ab33633b978bd384bbbf098648ceed; T01 is not integrated.
Build the regression matrix before changing implementation. FFmpeg/ffprobe were
not found on PATH/in the checkout. Never run the legacy suite against normal
Music; execute only after proven disposable isolation, otherwise record T02's
plan/fixtures and exact execution blocker for the later T03 exception. Preserve
default audio behavior, keep loudness deferred and leave website work for later.
Ordinary tests, focused commits, feature pushes and draft PR updates are already
authorized; do not ask for those again. Main integration and release writes retain
their recorded explicit approval gates. Before ending, record evidence and the
precise next task, review/stage intended files, commit/push and compare local HEAD
to fresh git ls-remote for the active branch. Report main integration separately,
never claim unrun Windows/phone tests passed, and leave the next-thread prompt.
```
