# <step> handover — <COMPLETED / IN_PROGRESS / BLOCKED>

## Outcome

What was accomplished in this step; whether acceptance passed; what is still
unproved. Do not say "ready/done" when an obligatory gate remains blocked.

## Changes

Files/functions changed and why. User-visible behavior preserved/changed. Any
new dependency/configuration/permission assumption. Refer to the actual diff.

## Verification

| Check | Exact command or artifact | Environment/runtime identity | Result | Evidence |
|---|---|---|---|---|
| <case> | <command> | <OS/host/build/hash> | <actual result> | <path> |

Separate executed from not run, mocked from real, negative expected failures from
normal positive success, and automation from owner observation. Record each missing
Windows or package check. Link new regressions for every fixed issue.

## Git state (observe after checkpoint)

Repository/remote identity; active branch; local checkpoint HEAD; fresh live branch
HEAD and comparison time; working-tree state; push result; exact-commit CI status.
State main integration independently. Frozen release source and ZIP hash, if any,
are separate from this checkpoint HEAD. Do not commit this HEAD into itself.

## Decisions, risks and blockers

New evidence-backed decisions; actual blockers and exact remediation. No broad
reinstall advice or repeated requests for already supplied environment information.

## Human action

Normally "None for this step." At S15 provide the kit + one short instruction page.
No manual developer matrix, PATH editing, FFmpeg command typing or audio upload.

## Next step and fully filled prompt

Name only the next eligible numbered step, or resume this one. Fill all referenced
paths/IDs. At S16 use the exact publication authorization format in the release spec.

    Continue AudioFileForPhone using docs/codex-v1.0.1. Read active state and verify
    fresh local/live GitHub state. Complete ONLY <Sxx title> in this thread.
    <Concrete remaining inputs/known evidence or blockers.>
    Preserve defaults, source safety and published v1.0.0. Automate tests.
    Update evidence/state/handover; test/review/commit/push and verify live sync.
    Give the full handover and next-thread prompt, then STOP.

## Stop

This thread ends here. No work on another numbered step until the owner starts it.

## Fixed final deliverable

Release target: **v1.0.1**. State whether publication is pending, blocked, published
but not yet verified, or publicly verified. Include the verified public release
URL at S17/S18. A different version cannot satisfy this plan.
