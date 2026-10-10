# Next session

## Next suggested step

**T05 in a new thread: centralize native execution and media inspection.**
T04 is complete on `codex/v1-t04-preflight`; A09–A11 passed on PS5.1/PS7.
Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/4 awaits owner integration. T03 PR #3 was owner-merged
at 20:43:41 UTC on 10 October 2026 into main
`bf425829d2e019911f179eb8250bfe6800f7ac81`. No agent merge occurred and no
blanket main merge or release authority has been recorded.

Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T05.md and specs/PROCESS_AUDIO.md. Refresh actual Git/GitHub and overrides.
Reconcile a newer owner merge if present; otherwise branch separately from the
latest T04 head and state its dependency. Preserve unrelated work.

T04 tested equivalent code checkpoint: `512a824ae856b4425a4012e0116f363babcc4d4e`.
Final evidence/handoff follows it; inspect fresh HEAD/live refs. Reports retain
the actual test base and working fingerprints; `evidence/T04-tested-payload.json`
establishes checkpoint equivalence including documented Git line-ending behavior.

The entry script now dot-sources the required functions-only
`AudioFileForPhone.Helpers.ps1`. All current copy harnesses include it unchanged.
Existing parameter order/defaults and BAT are retained. Preflight rejects input
kind/root/readability, range, destination, tool and explicit-cover failures before
optional prompts/run creation. It checks real ffmpeg/ffprobe version identity and
libmp3lame. Cover checks decode and exercise mjpeg once to null output. A missing
OutputParent is created intentionally; exclusive empty-directory/CreateNew-file
probes are removed literally. Internal SkipWriteProbe has no writes; public preview
remains T12. T05 should bring these narrow startup native calls under its shared
wrapper while keeping distinct prerequisite diagnostics.

Thirty-five negatives and eight helper checks passed per shell, including
effective owned TEMP ACL denials/exact restoration, JPEG/PNG and caller-local
native status. Ten resolver cases per shell and retained short-media suites passed.
Sources and exact owned cleanup passed. No ordinary Music, registry/policy,
disk-fill, live-share, manual/phone, long-file, CI or release evidence was created.

Environment: Windows 11 build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
Use installed `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`; never download.
Use STATUS/TEST_STRATEGY canonical TEMP commands. Frozen T02 substitution tools
are historical. Impossible dates, corrupt/mixed batch exit 0, reparse/scan policy,
full path budgeting, production run-root reservation and transactional output
remain later tasks. Do not broaden T05 to implement those tasks.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
T05 only: centralize native execution and media inspection. Read AGENTS.md and
docs/codex-v1/INDEX.md, STATUS.md, NEXT_SESSION.md, TASKS.json, AUTHORITY.md,
SYNC_PROTOCOL.md, tasks/T05.md and specs/PROCESS_AUDIO.md. Inspect actual status,
overrides, all fetch/push URLs, fresh advertised branch/main refs and live GitHub.
Fetch normally and preserve work. T03 is owner-merged into main
bf425829d2e019911f179eb8250bfe6800f7ac81. T04 code checkpoint 512a824ae856b4425a4012e0116f363babcc4d4e
has A09–A11 passing on both Windows shells; final handoff follows it and draft
PR https://github.com/PikkuJanne/AudioFileForPhone/pull/4 awaits owner integration. Reconcile any newer owner merge;
otherwise base focused T05 work on latest T04 head and state dependency.
Build one bounded native helper with concurrent stdout/stderr draining, exact
argv/status, -nostdin, resource ownership and distinct probe/dependency results.
Test quoted/special/Unicode argv on PS5.1/PS7 and noisy/error children, keeping
real-FFmpeg coverage. Bring startup tool/cover checks under that wrapper.
Preserve OutputParent/configured Music, defaults, audio/metadata behavior and
functions-only helper loading. Copy runtime helpers in every applicable harness.
Use C:\ffmpeg\bin pair and owned TEMP canonical tests. No DSP, downloads,
registry/policy change, unrelated refactor or invented manual/phone evidence.
Normal tests, commits, feature pushes and draft PR updates are authorized;
main merge/release gates remain. Review/stage intended diff, record exact tested
source hashes and results, update evidence/tracking/handoff, commit/push and compare
HEAD with fresh ls-remote. Report feature sync and main integration separately.
After T05, suggest T06 as the next coherent new thread.
```
