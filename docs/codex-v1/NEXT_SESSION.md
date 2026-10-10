# Next session

## Next suggested step

**Provide a local FFmpeg/ffprobe pair and finish T02 baseline execution on both
Windows shells.** T02 is blocked, not complete. After A04–A06 and engineering
choice characterization pass, T03 is the next new task/thread. The T03
isolation-only exception does not cover unavailable native tools.

Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T02.md, T02_REGRESSION_MATRIX.md, TEST_STRATEGY.md, DECISIONS.md and
evidence/T02.md. Inspect fresh Git/GitHub state before editing.

Checkout: `C:\projects\AudioFileForPhone-main`.
Active branch: `codex/v1-t02-baseline`.
Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/2.
Tested preparation/live code checkpoint:
`0b71b68ee044639d82bd1b7bc43e10d023258be4`.
Final handoff documentation follows that checkpoint; inspect actual HEAD/live ref.

T01 PR #1 was merged by the owner at 19:45:49 UTC on 10 October 2026.
Local/live main was `483af25f8e5fa9dee295f5b74130324663339e37`.
T02 is not integrated. No broader agent merge policy was approved.

Environment: Windows 11 Pro build 26300.9457, PS5.1 5.1.26100.9444 and PS7 7.6.5.
No FFmpeg/ffprobe was found despite local installed-tool/cache searches. No tools
were downloaded/installed, media opened or persistent machine settings changed.

T02 prepared a source-reviewed regression matrix and executable synthetic
fixtures/assertions. The copy-only adapter redirects exactly one Music resolver
in each disposable application/test copy. Both shell isolation/parser checks and
four unsafe report-path rejection checks passed; source files and owned cleanup
were verified. Both real-mode attempts stopped at dependency discovery (exit 1),
before fixture creation. A04–A06 remain blocked; the companion's media assertions
are unrun hypotheses. Source-review risks are not reproduced runtime evidence.
The original application, BAT and real-FFmpeg integration suite remain unchanged.

Use the canonical commands in STATUS.md. Optional full tool-path parameters are
supported. Do not run the legacy suite directly against the owner's Music.
Record actual rates/channels, raw ID3/frame CBR, durations, tags/names/exit outcomes
and fixture hashes; finalize proposed bitrate/name/path choices from real results.
If an assertion differs from baseline, record the observation and diagnosis;
do not alter production behavior merely to make characterization pass.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
Resume T02 only: real baseline execution and test-contract finalization. Read
AGENTS.md and docs/codex-v1/INDEX.md, STATUS.md, NEXT_SESSION.md, TASKS.json,
AUTHORITY.md, SYNC_PROTOCOL.md, tasks/T02.md, T02_REGRESSION_MATRIX.md,
TEST_STRATEGY.md, DECISIONS.md and evidence/T02.md. Inspect actual status, all
fetch/push destinations and fresh advertised feature/main refs; fetch normally
and preserve all work. Continue codex/v1-t02-baseline and draft PR #2 unless
fresh state requires reconciliation. T01 was merged by the owner into main
483af25f8e5fa9dee295f5b74130324663339e37. T02 test preparation was tested/pushed
at 0b71b68ee044639d82bd1b7bc43e10d023258be4; final docs follow it.
FFmpeg/ffprobe were absent. Use the owner's installed pair via PATH or explicit
-FfmpegPath/-FfprobePath; never auto-download. Run tests/Invoke-IsolatedBaseline.ps1
on PS5.1 and PS7 using the exact commands in STATUS. The copy adapter is proven
isolated; the original suite itself still writes Music if invoked directly.
Complete A04–A06 with real fixture/probe/decode/duration/source-hash evidence and
finalize engineering choices honestly. Do not treat known baseline defects as
passes or change production defaults to satisfy a hypothesis. T03's exception
does not cover missing native dependencies. Ordinary tests, focused commits,
feature pushes and draft PR updates are authorized; retain merge/release gates.
Update tracking/evidence/handoff, review/stage intended files, commit/push, compare
HEAD to fresh ls-remote and report feature synchronization/main integration
separately. Clearly state the next suggested step. Once T02 passes, suggest T03
as the next coherent new thread.
```
