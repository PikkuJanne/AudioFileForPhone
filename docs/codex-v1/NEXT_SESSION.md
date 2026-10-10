# Next session

## Next suggested step

**T06 in a new thread: bound recursive scanning and exclude prior output.**
T05 is complete on `codex/v1-t05-native-process`; A12–A14 passed on PS5.1/PS7.
Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/5 awaits owner integration.
T04 PR #4 was owner-merged at 21:06:59 UTC on 10 October 2026 into main
`124f3a96e1a416f6870b832d1ee1cc7543286ab9`. No agent merge occurred and no
blanket main merge or release authority has been recorded.

Read AGENTS.md, INDEX.md, STATUS.md, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md,
tasks/T06.md and specs/SAFETY.md. Refresh actual Git/GitHub and overrides.
Reconcile a newer owner merge if present; otherwise branch separately from the
latest T05 head and state its dependency. Preserve unrelated work.

T05 tested equivalent code checkpoint: `215b57c2d1fd93ab62192e07c9ba30632bf2824e`.
Final evidence/handoff follows it; inspect fresh HEAD/live refs. Reports retain
the actual test base and working fingerprints; `evidence/T05-tested-payload.json`
establishes checkpoint equivalence including only Git line-ending normalization.

The required functions-only `AudioFileForPhone.Helpers.ps1` stays beside the entry
PS1 and is copied byte-for-byte by current harnesses. Its lazy .NET runner handles
Windows CRT quoting, bounded concurrent stream drains, explicit native status/exit,
closed stdin and owned cleanup on PS5.1/PS7. FFmpeg calls use -nostdin. Media probes
validate first-audio stream/index and distinguish native/probe/JSON/audio failures
from successful absent title. Ogg stream versus MP3/M4A container metadata precedence
and all existing defaults/names/layout are preserved. Tool paths/versions are logged.

Per shell: 35 native cases, full 2.45M-character dual-pipe drains, 40-invocation zero
handle growth, exact quoted/Unicode argv plus real metadata/cover/full decode;
retained FFmpeg suite/seven required companion checks; 35 preflight negatives/eight
helper checks and ten resolver cases pass. All final source/fixture hashes, owned
TEMP cleanup and ACL restoration pass. Initial native failures are retained and
explained in evidence/T05.md, with final passing reports explicitly named.

Environment: Windows 11 build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
Use installed `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`; never download.
Use STATUS/TEST_STRATEGY TEMP-only commands. Native reports are CreateNew; choose a
fresh T05 label to repeat them. No ordinary Music, registry/policy, live-share,
manual/phone/long-audio, cancellation, CI or release evidence was created in T05.
External-reference media remains unaudited; no protocol whitelist was adopted.

T06 must snapshot/exclude inputs before creating the production run root. Current
production discovery still recurses with Get-ChildItem and run output exists before
scan; these are the next task's gaps. Adopt recorded reparse/access policies from
DECISIONS: reject selected reparse directory; skip directory and file reparse points
with visible reasons; abort inaccessible scans before conversions. Recognize actual
generated output conservatively; retain arbitrary similarly prefixed user content.
Keep date/Unicode/full path budgeting T07, production run reservation T08,
transactional output T09 and aggregate/BAT outcomes T10/T11 out of this thread.

## Copy-ready next-thread prompt

```text
Work in C:\projects\AudioFileForPhone-main for PikkuJanne/AudioFileForPhone.
T06 only: bound recursive scanning and exclude prior output. Read AGENTS.md and
docs/codex-v1/INDEX.md, STATUS.md, NEXT_SESSION.md, TASKS.json, AUTHORITY.md,
SYNC_PROTOCOL.md, tasks/T06.md and specs/SAFETY.md. Inspect actual status,
overrides, fetch/push URLs, fresh advertised branch/main refs and live GitHub.
Fetch normally and preserve work. T04 is owner-merged into main
124f3a96e1a416f6870b832d1ee1cc7543286ab9. T05 tested code checkpoint
215b57c2d1fd93ab62192e07c9ba30632bf2824e has A12–A14 passing on both Windows shells;
final handoff follows it and draft PR #5 awaits owner integration. Reconcile any
newer owner merge; otherwise base focused T06 work on latest T05 head and state dependency.
Use separator-aware canonical relationships and deterministic discovered-input
snapshot; exclude planned/current/generated and conservatively recognized legacy
outputs before creating a run. Test overlap, Music-like nested ancestry, prefix
neighbors, arbitrary similarly named user folders, junction loops/file reparse
points and owned ACL denials. Reject selected reparse directories; skip descendant
reparse files/directories visibly; abort inaccessible scans before conversions.
Keep functions-only helper loading and shared bounded native/probe APIs. Preserve
OutputParent/configured Music, defaults, formats, names/layout, metadata and BAT.
Use C:\ffmpeg\bin pair and owned TEMP tests; no ordinary Music traversal, source
mutation, downloads, registry/policy changes, unrelated refactor or invented manual evidence.
Normal tests, commits, feature pushes and draft PR updates are authorized;
main merge/release gates remain. Review/stage intended diff, record exact tested
source hashes/results, update evidence/tracking/handoff, commit/push and compare
HEAD with fresh ls-remote. Report feature sync and main integration separately.
After T06, suggest T07 as the next coherent new thread.
```
