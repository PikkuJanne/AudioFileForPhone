# Current project status

State: **T11 complete; M2 local acceptance passed; main integration pending.**
Last completed task: T11. Exactly next implementation task: T12 after owner
integration of T11. Required improvements 1-15; optional O01 deferred.
Project/release are incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t11-cancellation.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T10 PR #10 at 07:18:35 UTC on 11 October 2026 into main
  82f0fd3c9da765f169c2724edc73f779cdce6525. Normal fetch and independently
  advertised refs matched. Clean local main was fast-forwarded before this branch.
- Original full-matrix test base 82f0fd3; reviewed runtime checkpoint
  71eee22c87b57cea60079419f063149703c7df5a pushed/live-matched.
  Compiler-only test followup ac9cdedbb926d8ecfd6e21f1d26a713d27c09fd5 and
  evidence checkpoint 18fd7a6cef6208db415c7fea17de07d7d4b50628 also
  pushed/live-matched. PS7 physical manual2 actually tested 18fd7a6.
  Manual acceptance closure follows in a docs-only checkpoint; final HEAD/live
  comparison belongs in the PR/response.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/11.
  **Feature synchronized; A29/A30 pass; main integration pending.**
  T01-T10 integrated. GitHub lists zero workflows/checks; no CI pass claimed.
- Windows 11 Pro 26300.9457; PS5.1 5.1.26100.9444; bundled PS7 7.6.5 plus
  Store PS7 7.6.6 focused and physical checks. Existing C:\ffmpeg\bin pair,
  build 2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev. No download
  or persistent settings change.

## Verified behavior and evidence

Scoped supported-console Ctrl+C begins after prompts, restores prior console mode
and propagates Cancelled/130 through native/probe/validation/transaction boundaries.
Native wait/drain polls every 100 ms without ordinary runtime timeout. Existing
5000 ms exit/1000 ms drain teardown remains. Stop only the held owned child; suspend
cleanup before native/validation until explicit returned exit proof. Matching
identity/nonreparse exact current partial cleanup follows released handles. Request
and publication have one ordering point; completed outputs retain success.
Cancelled current file stays not_processed; processed=converted+failed. Persist
counts/cancellation where logging permits without masking130. Preserve exact
retained-path/unproved-child/late console diagnostics and T10 normal 0/2/1 outcomes.

A29 and A30 pass. Owner-confirmed physical Ctrl+C reports pass on PS5.1 manual1
and Store PS7 7.6.6 manual2. Both prove 130/Cancelled, total=3/processed=1/
converted=1/failed=0/not_processed=2, preserved first output hash/full decode,
removed current partial, cancellation log, restored console mode, unrelated
FFmpeg survival, unchanged source/fixture hashes and exact owned cleanup.
PS7 manual2 tested 18fd7a6 with current runtime/repaired harness fingerprints;
PS5.1 manual1 retains the original 71eee22 harness provenance. Automated input
records remain distinct. Full M2 local acceptance is complete.

26 selected final automated reports pass: full matrix on both shells plus focused
nine-group runs on PS5.1, bundled PS7 and Store PS7 from repository/Store directories.
Groups cover native cancellation/unrelated FFmpeg, cancellation at successful
validation return boundaries and before publication, unknown-exit residue,
preserved first output/mode restoration and actual forced host kill. Its encoder
remained alive on both shells; the harness stopped/waited an independently
parent/creation/image-verified retained handle before cleanup. Next unmodified run
preserves every prior-run/orphan hash.

Full M2 matrix: retained FFmpeg/seven companions; transaction 27 groups/61 decoded
conversions/3 rate rejects; script 13 groups/14 decoded publications; launcher 52
cases each/both shells; preflight 35/eight helpers; discovery 8; naming 11;
reservation 13; resolver 10; exact returned-root/token/inventory configured-Music
smokes; native 35. Quiet sequential native handles 673->673 (PS5.1), 580->580
(PS7), allowance16. Selected source/synthetic/child/ACL/link/TEMP/Music gates pass.
Ordinary Music never enumerated. Manifest proves 16 current files: 3 literal/
13 only CRLF-to-LF, with distinct historical manual harness provenance.

## Preserved limitations

36 raw reports retained: 33 automated (29 pass/four fail) and three physical-mode
reports (two actual passes/one compiler setup failure with no physical claim).
Old optimistic native-throw cleanup assertion, inherited-console/DLL-lock and
CS0165 failures remain. Attempt1 original cleanup=false survives later exact sole
DLL hash/nonreparse/child-exit recovery; marker/token had already gone, so later
root absence does not retroactively prove the original cleanup contract.
Store manual1 failed compiler setup; explicit Framework references repair only
the harness. A separate immediate evidence-path guard rejection created no
fixtures/report; its cause remains unobserved. Store-directory automatic final4
and subsequent direct physical manual2 pass. No failed evidence was relabelled.

T07 possible unknown synthetic machine-TEMP residue remains unverified; no known
leaf or broad recovery authority. T09 brief post-guard path interval remains.
Forced host/window close/power loss, redirected/unsupported hosts, preflight/
prompts and Ctrl+Break can bypass controlled cleanup/code130 and leave a running
child/recognizable partial. Next runs never auto-reclaim leftovers. No phone/
manual-window-close, source-replacement, full-disk, long-file/performance, CI or
release acceptance is claimed.

## Commands and next action

Exact commands/labels/results: evidence/T11.md and TEST_STRATEGY.md. T11 has no
remaining local acceptance action. Owner review/integration of draft PR #11 is
pending under AUTHORITY.md. Exactly next implementation task is T12 after that
integration is independently verified.

Normal feature edits/tests/commits/push/draft PR remain authorized. Main requires
owner review. No tag/release created. Exact reviewed commit/assets, validated ZIP,
verified draft/public download and final main closure remain gated by AUTHORITY.md
and RELEASE_RUNBOOK.md.
