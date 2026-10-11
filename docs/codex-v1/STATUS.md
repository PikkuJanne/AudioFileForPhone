# Current project status

State: **T11 implemented; automated M2 matrix verified; physical Ctrl+C gate pending.**
Last fully completed task: T10. Current task: T11. Next implementation task: T12
after T11 acceptance and owner integration. Required improvements 1-15; optional
O01 deferred. Project/release are incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t11-cancellation.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T10 PR #10 at 07:18:35 UTC on 11 October 2026 into main
  82f0fd3c9da765f169c2724edc73f779cdce6525. Normal fetch and independent advertised
  main/T10 feature eeb15703cac8d93d9c3147ddf2bf70e47ccda27e matched. Clean local
  main was fast-forwarded before this branch.
- Original full-matrix test base 82f0fd3; equivalent reviewed runtime checkpoint
  71eee22c87b57cea60079419f063149703c7df5a was committed/pushed and independently
  advertised-ref matched. Test-only compiler followup
  ac9cdedbb926d8ecfd6e21f1d26a713d27c09fd5 also pushed/live-matched; runtime
  unchanged. Evidence/handoff follows in a docs-only checkpoint; final HEAD/live
  comparison belongs in the PR/response.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/11.
  **Feature synchronized; physical A29 acceptance and main integration pending.**
  T01-T10 integrated. GitHub lists zero workflows/checks; no CI pass claimed.
- Windows 11 Pro 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5 plus Store 7.6.6 focused checks. Existing C:\ffmpeg\bin
  pair, build 2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev. No download
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

A30 passes. A29 controlled component and owner-confirmed PS5.1 physical manual
test pass. Store PS7 7.6.6 manual1 failed in test-helper compilation before any
conversion; its exact cleanup and unchanged hashes pass, with no physical claim.
Compiler references have been made explicit; PS7 manual2 is requested and remains
the required acceptance gate. Automated input records are labelled accurately.

26 selected final automated reports pass: the full matrix on both shells and
focused nine-group reruns on PS5.1, bundled PS7 and Store PS7. Focused groups
cover actual native cancel/unrelated FFmpeg survival, validation/publication
boundaries, unknown-exit residue, first output hash/full decode/mode restore, and
actual forced host kill. Its owned encoder remained alive on both shells; harness
stopped/waited an independently parent/creation/image-verified retained handle
before cleanup. Next unmodified run preserves every prior-run/orphan hash.

Full M2 matrix: retained FFmpeg/seven companions; transaction 27 groups/61 decoded
conversions/3 rate rejects; script 13 groups/14 decoded publications; launcher 52
cases each/both shells; preflight 35/eight helpers; discovery 8; naming 11; reservation 13;
resolver 10; exact returned-root/token/inventory configured-Music smokes; native 35.
Quiet sequential native handles 673->673 (PS5.1),580->580 (PS7), allowance 16.
Selected source/synthetic/child/ACL/link/TEMP/Music gates pass. Ordinary Music never
enumerated. T11-tested-payload.json proves 16 files against code: 3 literal/13 only
CRLF-to-LF.

## Preserved limitations

33 raw automated reports retained: 29 pass/four fail. Script PS5.1 final1 expected
optimistic cleanup after native throw without exit proof; final2 verifies exact
retained partial/reason and next-file continuation. Cancellation attempt1 failed
AttachConsole and DLL-lock cleanup; original cleanup_verified=false remains.
Later sole-DLL exact known hash/nonreparse/child-exit recovery removed DLL and empty
root; original marker/token had already gone, so original cleanup is not
retroactively proved. Attempts2/3 retain CS0165 compiler failures and full cleanup.
Attempt4 and initial final reports prove the original harness. Compiler-only
repaired focused final2/final3 reports prove the current harness. PS5.1 manual1
passes against the original harness; Store PS7 manual1 compiler failure remains.
Details and distinct fingerprints are in evidence/T11.md and the manifest.

T07 possible unknown synthetic machine-TEMP residue remains unverified; no known
leaf or broad recovery authority. T09 brief post-guard path interval remains.
Forced host/window close/power loss, redirected/unsupported hosts, preflight/
prompts and Ctrl+Break can bypass controlled cleanup/code 130 and leave a running
child/recognizable partial. Next runs never auto-reclaim leftovers. No PS7 physical
Ctrl+C, phone/manual-window-close, source-replacement, full-disk, long-file/
performance, CI or release acceptance is claimed.

## Commands and next action

Exact commands/labels/results: evidence/T11.md and TEST_STRATEGY.md. Owner action:
retry PS7 manual2 from an open Windows Terminal prompt, press Ctrl+C after READY
and report the result. PS5.1 manual1 is already confirmed passed.
Reconcile fresh reports/payload before completing A29/T11/M2. Exactly next
implementation task is T12 after this gate and owner integration.

Normal feature edits/tests/commits/push/draft PR remain authorized. Main requires
owner review. No tag/release created. Exact reviewed commit/assets, validated ZIP,
verified draft/public download and final main closure remain gated by AUTHORITY.md
and RELEASE_RUNBOOK.md.
