# Next session

## Next suggested step

**T03 in a new thread: add OutputParent and isolate ordinary tests.** T02 is
complete on its feature branch; A04–A06 passed on both Windows shells. Main
integration of T02 remains pending owner review of draft PR #2.

Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T03.md, specs/SAFETY.md and TEST_STRATEGY.md. Consult T02 evidence and
regression matrix for preservation expectations; read only relevant later specs.
Inspect fresh Git/GitHub state and agent overrides before editing.

Checkout: `C:\projects\AudioFileForPhone-main`.
Active branch: `codex/v1-t02-baseline`.
Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/2.
Tested payload/code checkpoint: `84bd98656e9e56c9d244aa8b9a216d0204dd23d8`; reports retain test base
`9fceee091fc4bfd43bdab64d5bb943a3b620bc79` plus verified helper fingerprints.
Final handoff documentation follows that checkpoint; inspect actual HEAD/live ref.

T01 PR #1 was merged by the owner at 19:45:49 UTC on 10 October 2026.
Local/live main was `483af25f8e5fa9dee295f5b74130324663339e37`.
T02 is not integrated. No broader agent merge policy was approved. Reconcile an
owner merge if present. If still pending, continue from the T02 head without
losing its evidence; keep T03 a separate task/branch/PR and state its dependency.

Environment: Windows 11 Pro build 26300.9457, PS5.1 5.1.26100.9444 and PS7 7.6.5.
Owner-provided native pair: `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`, build
`2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`. No agent installation,
ordinary Music test, phone test or persistent machine change occurred.

The unchanged legacy integration suite and focused synthetic companion passed
through the copy-only Music adapter on both shells. Seven required companion
checks passed per shell; impossible-date and failed-batch results are three
observed gaps per shell. Native bitrate and actual 24/180 filename/collision
characterization also passed. Source inventories and owned cleanup passed.
The PS5.1 report reader needed explicit UTF-8; both baseline suites were rerun
successfully after that test-only correction. Production PS1/BAT and original
suite remain unchanged. Review the finalized engineering choices in the matrix;
future acceptance cases remain unrun.

T03 adds optional OutputParent while retaining the configured Music default.
Update the existing suite to use an owned temporary parent; preserve real FFmpeg
coverage and the baseline behavior. A07 requires isolated output integration.
A08 requires resolver tests plus a narrowly owned default-path smoke; do not
change the owner's registry or blindly run the old suite against Music. Plan the
smoke so only its exclusively owned run can be removed. Update canonical test
commands in STATUS.md and TEST_STRATEGY.md. Baseline media need not be repeated
solely for documentation; rerun affected coverage for T03's application changes.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
T03 only: add optional OutputParent while preserving configured Music as default,
and isolate ordinary automated tests. Read AGENTS.md and docs/codex-v1/INDEX.md,
STATUS.md, NEXT_SESSION.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md, tasks/T03.md,
specs/SAFETY.md and TEST_STRATEGY.md. Inspect actual status/overrides, all fetch/push
URLs, and fresh advertised feature/main refs; fetch normally and preserve work.
T02 A04–A06 passed on both shells; its tested payload/code checkpoint is
84bd98656e9e56c9d244aa8b9a216d0204dd23d8 and draft PR #2 is pending integration. T01 was owner-merged
into main 483af25f8e5fa9dee295f5b74130324663339e37. Reconcile any newer owner merge;
otherwise base a focused T03 branch/PR on T02's current head and state the dependency.
Use installed C:\ffmpeg\bin\ffmpeg.exe and ffprobe.exe, never auto-download.
Preserve the real-FFmpeg suite; the old suite still writes ordinary Music when
invoked directly. T02's copy adapter is safe, with exact helper/source fingerprints
in evidence/T02-tested-payload.json. Implement A07 and A08 with an owned test
parent, resolver coverage and a narrowly safe default-path smoke. Do not change
known-folder registry settings or invent manual/phone evidence. No DSP/default
rate/formats/layout changes. Record source hashes, commands, shell/OS/tool versions
and actual results. Ordinary tests, focused commits, feature pushes and draft PR
updates are authorized; retain merge/release gates. Update tracking and handoff,
review/stage intended files, commit/push, compare HEAD with fresh ls-remote and
report feature sync and main integration separately. Clearly state the next
suggested step; after T03 completes, suggest T04 as the next coherent new thread.
```
