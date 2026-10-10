# Next session

## Next suggested step

**T04 in a new thread: extract small helpers and implement preflight.**
T03 is complete on `codex/v1-t03-output-isolation`; A07/A08 passed on PS5.1 and
PS7. Draft PR #3 awaits owner integration. T02 PR #2 was owner-merged at
20:32:54 UTC on 10 October 2026 into main
`0818bf8206849370aa0ef2eaeccaed5b2fb1a890`; local main was fast-forwarded to it.
No blanket agent merge authority has been recorded.

Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T04.md and its relevant specs. Refresh actual Git/GitHub state and overrides.
Reconcile a newer owner merge if present; otherwise continue from the T03 head
on a separate T04 branch/PR and state the dependency. Preserve unrelated work.

T03 code checkpoint: `b5b3c8b7837dd8af17ae4e5b8405684ccdd7237e`.
Final evidence/handoff follows it; inspect fresh HEAD/live refs. Reports contain
actual test base `0818bf8206849370aa0ef2eaeccaed5b2fb1a890` plus file fingerprints;
`evidence/T03-tested-payload.json` verifies equivalent committed source, with only
Git CRLF/LF normalization where recorded. Draft PR:
https://github.com/PikkuJanne/AudioFileForPhone/pull/3.

The script accepts optional OutputParent; configured Windows Music remains the
default. Ordinary retained-suite/companion runs now use fresh owned TEMP parents
and byte-identical application copies. Missing parents with spaces/brackets are
covered end to end. Ten resolver cases and separate narrowly owned instrumented
Music smokes passed on each shell. Synthetic source hashes and all cleanup checks
passed. The smoke is opt-in and changes only a copy's timestamp assignment; no
registry changes or manual/phone evidence occurred. Use the canonical isolated
commands in STATUS.md/TEST_STRATEGY.md. T02 substitution helpers are historical.

Environment: Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
Use the installed `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`; never download.
Baseline audio/tags/names/layout remained unchanged. Impossible dates and corrupt
batch exit 0 remain observed gaps for later tasks; BAT remains byte-identical.
No CI, phone, long-file, release ZIP or publication was performed.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
T04 only: extract small helpers and implement preflight. Read AGENTS.md and
docs/codex-v1/INDEX.md, STATUS.md, NEXT_SESSION.md, TASKS.json, AUTHORITY.md,
SYNC_PROTOCOL.md, tasks/T04.md and relevant specs. Inspect actual status/overrides,
all fetch/push URLs and fresh advertised feature/main refs; fetch normally and
preserve work. T02 is owner-merged into main 0818bf8206849370aa0ef2eaeccaed5b2fb1a890.
T03 A07/A08 passed on both shells; code checkpoint b5b3c8b7837dd8af17ae4e5b8405684ccdd7237e
and draft PR #3 await owner integration. Reconcile any newer owner merge; otherwise
base focused T04 work on T03's latest head and state the dependency. Preserve
OutputParent/configured Music default and real-FFmpeg coverage; ordinary tests
now use owned TEMP output and include missing bracketed parents. Copy any newly
required runtime helpers with the app in every applicable test harness. Use the
installed C:\ffmpeg\bin pair and canonical commands in STATUS/TEST_STRATEGY.
No DSP/default bitrate/format/layout changes or policy/registry changes. Record
actual source hashes, commands, versions/results; don't invent manual/phone evidence.
Normal tests, commits, feature pushes and draft PR updates are authorized; retain
main merge/release gates. Review/stage intended files, update evidence/tracking and
handoff, commit/push, compare HEAD with fresh ls-remote, and report feature sync and
main integration separately. After T04, suggest T05 as the next coherent new thread.
```
