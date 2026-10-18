# S03 handover - COMPLETED

## Outcome

S03-A1/A2/A3 pass. Bounded short native operations, explicit Timeout transport,
overridable media probes and safe pipe teardown are implemented and verified on
the available Windows 11 client under both shells. Source 9b30f96 is pushed and
live-equal with passing exact-head push and associated PR CI. The final docs-only
containing checkpoint is checked after push in the final response; refresh it at
the next thread's entry. S04 remains NOT_STARTED. Project release is not complete.

## Changes

Extended Invoke-AudioNativeProcess in the existing helper with operation names,
optional TimeoutMilliseconds (zero/unlimited by default), elapsed/status/release
transport, independent retained UTF8 stdout/stderr snapshots and bounded pipe
completion. Each pipe worker polls its own handle and reads available bytes;
decoder state preserves split Unicode. Cancellation is polled before deadlines.
Kill/wait applies only to the retained owned child. Teardown waits separately
for child/pipe release and closes owned handles. Missing EOF/uncertain release
withholds ProcessReleased, so the existing transaction retains the incomplete
file. No process-tree/name termination or automatic reclamation was added.

Version and encoder capability checks each default to 15 seconds. Source/output probes
default to 60 seconds; public ProbeTimeoutSeconds (1-2147483) propagates through the entry,
transaction and validation. Timeout remains distinct in per-file outcomes and
reports the executable, operation, elapsed time and release result with retry
guidance. Encoding and full decode have no short fixed runtime ceiling. Default
64 kbps CBR, Music destination, supported inputs, tree/names/metadata/artwork,
full-decode validation and external0/1/2/130 contract remain intact.

Added tests/Test-ShortOperations.ps1 with compiled independent hung children and
separately inherited stdout/stderr writers, exact retained sentinel/descendant
identity cleanup, marker/reparse/hash guards and create-new reports. Its15 cases
exercise bounded startup/probes, configurable deadlines, pipe-only deadlines,
two cancellation timings, output-probe timeout partial cleanup/retention, argv/
Unicode/caps and short paced real encode/decode. CI adds this family and retains
the native resource suite last. Retained wrappers accept/forward additive args;
the exact help-name list adds the one authorized parameter. README/help explain
the option. No new runtime dependency, privilege, config or network behavior.

## Verification

All commands run from C:\projects\AudioFileForPhone-main. Resolve shells with
(Get-Command powershell.exe).Source / (Get-Command pwsh.exe).Source. Owned test
children use -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned,
child-only PSModulePath removal and the inherited console CP65001. Public JSON
accepted_local_reports[].command_arguments records each exact invocation and
historical report path. Reports/logs/media stay in private owned TEMP; public
evidence binds digests and sanitized summaries. No ordinary Music/personal media.

| Check | Command / artifact | Actual environment and runtime | Result | Evidence |
|---|---|---|---|---|
| Focused deadlines | tests/Test-ShortOperations.ps1 with explicit C:/ffmpeg/bin tools; S03-shortoperations-ps51/ps7-final3.json | Windows 11 Pro 26H2 26300.9711 x64; PS5.1 5.1.26100.9711 / PS7 7.6.5; runtime 0d2d8ff unchanged in 9b30f96 | PASS 15 each; CP65001; no unresolved fixture process | S03.json accepted_local_reports |
| Isolation | tests/Invoke-IsolatedBaseline.ps1 -ValidateOnly; T17-s03-isolation-ps51/ps7-attempt6.json | Same client/shells | PASS exact copies/owned cleanup | Same |
| Real baseline | Same wrapper without ValidateOnly, explicit FFmpeg/ffprobe; T17-s03-baseline-ps51/ps7-attempt5.json | Git build 2026-10-08-git-ec420ba161 essentials; binary digests in focused report | PASS legacy 0;7 required characterizations/3 observations each | Same |
| Pure contracts | tests/ci/Test-CiContracts.ps1; T17-unit-ps51/ps7-attempt6.json | Same client/shells; no media | PASS 31 each | Same |
| Transactions | tests/Test-TransactionalOutput.ps1; T16-transaction-ps51/ps7-attempt5.json | Same; existing real+fault cases | PASS 27 each | Same |
| Cancellation | tests/Test-Cancellation.ps1; T16-cancellation-ps51/ps7-attempt5.json; no Manual | Same; automated controlled input/forced host | PASS 9 each; not physical Ctrl+C evidence | Same |
| Cleanup ownership | tests/Test-CleanupSafety.ps1; T16-cleanup-ps51/ps7-attempt5.json | Same; AST-derived retained safety guards | PASS 181 each | Same |
| Help / exact examples | tests/Test-HelpVersion.ps1; T17-help-ps51/ps7-attempt5.json | Same; authorized parameter name added | PASS 7 each | Same |
| Captured regressions | tests/Test-SetupEncodingRegressions.ps1, explicit tools; S02-regressions-ps51/ps7-final6.json | Same client/tools | PASS 12 each; known bitrate clamping still safely rejected | Same |
| Native calls/handles | tests/Test-NativeProcess.ps1; T17-s03-native-ps51/ps7-attempt6.json, run last | Same client/tools | PASS 35 each including the 40-call resource test, argv/Unicode/caps and real conversion/full decode | Same |
| Review | Independent read-only code/fixture audit, intended diff/privacy review; git -c core.whitespace=cr-at-eol diff --check 6f1ef9f..HEAD | Actual scoped diff | No remaining blocker; safeguards/assertions retained | S03.json review |
| Exact source CI | gh run view/download 39048368905 and 39048372292, repository PikkuJanne/AudioFileForPhone | Push checks 9b30f96f3f280e6c9e04b33285ee9f40ee3c0d8a; PR integration b60cce519c514eedc06cd68418cd05247cb5e32d | PASS all 4 jobs; artifact reports prove 15 focused cases plus retained families each | S03.json ci |

Observed focused final3 maximum recorded timeout was 2066 ms (PS5.1) / 2071 ms (PS7),
including teardown of held-pipe/output probe cases. Real paced encodes took 1721 ms /
1649 ms and independent paced full decodes 1562 ms / 1560 ms, beyond the 1-second startup
test bound. These are actual observations, not universal FFmpeg timing promises.
Both direct and production full decode retain native TimeoutMilliseconds 0.
The test uses synthetic 2-second media; no owner listening/phone claim is made.

Initial outer-host CreateNoWindow accidentally selected CP437. Baseline Unicode
characterization failed despite legacy 0. These attempts (including supplementary
retained progress passes and one incomplete PS5.1 startup assertion) are invalid
for final acceptance, preserved by digest and replaced by CP65001 runs. The
PS5.1 assertion failed before retaining its caught message, so its cause is not
claimed. Two initial wrapper invocation errors were refused before their suites
(nonmatching report leaf / omitted mandatory tool paths); corrected invocations
pass. Nothing was changed to weaken application validation. Preparation CI
39047699943/39047703714 failed the stale help parameter list; 709370a adds exactly
the new parameter. Its PS7 CI runs 39047952851/39047955727 safely timed out the
cold compiled fixture at 533-534 ms before it wrote diagnostics (release/EOF true,
zero retained characters). Their PS5.1 jobs passed the complete suite. 9b30f96
raises only deliberate fixture budgets to 2000 ms, adds readiness-marker proof
and preserves all diagnostic/release assertions; both replacement runs pass.
All failed reports remain recorded. Production defaults and bytes are unchanged.

Windows 10 22H2 client, another local FFmpeg build, exact candidate ZIP/kit and
new phone observations are NOT_RUN here and remain future acceptance work.
Hosted Windows Server CI is supplementary. Saved tool-selection APIs and bitrate
compatibility repairs retain their earlier pending scope for later steps.

## Git state (observe after checkpoint)

Expected origin https://github.com/PikkuJanne/AudioFileForPhone.git. Active branch
codex/audiofileforphone-v1.0.1; open draft PR #29:
https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Entry local/live feature
6f1ef9fa098e680ef611f373feab0533d4976b1d is clean; exact entry push CI 39045862937
and PR CI 39045866602 pass. Local/live main is
28f53b10529495754273d55654c7b29e78848c83 at entry and preparation verification.

Runtime implementation 0d2d8ff6d9636f313d775b7b0d90aa513d8e7831 is followed by
test-only help contract correction 709370abfea1f28309032d64863ee92d776155b5
and fixture timing/readiness correction 9b30f96f3f280e6c9e04b33285ee9f40ee3c0d8a.
Ordinary pushes and independent fresh ls-remote confirm equality. 9b30f96 has
passing exact-head push CI 39048368905 and associated PR CI 39048372292, separately
recording feature vs integration checkout. Final docs-only HEAD cannot contain
its own SHA; its fresh clean/live comparison and exact-head CI are in the final
response, and the next thread must refresh them. No force/reset/clean/merge.

Main integration: NOT_INTEGRATED, separate S14 ordinary reviewed PR policy and
existing owner-approval default. No frozen source or release ZIP is recorded;
S03 performed no tag or release write. Runtime remains 1.0.0 until planned
version/package work.

## Decisions, risks and blockers

D19-D21 record operation-specific bounds, conservative pipe release, retained
proxy compatibility, corrected inherited console, help and fixture adjustments.
Bounds are tunable application defaults, not vendor guarantees. Polling checks
each pipe on its dedicated worker, with sequential native calls per handle.
Normal local child release, held writers and resource stability are verified;
unknown release keeps incomplete files. No S03 blocker remains. Unavailable
Windows 10/kit/phone evidence is explicitly deferred to the planned acceptance.

## Human action

None for S03. No repeated diagnostic commands, PATH edits, ordinary Music scan,
audio upload or manual developer matrix. Consolidated owner work remains S15.

## Next step and fully filled prompt

S04 - Implement explicit and remembered tool selection is eligible, NOT_STARTED.
Start a new thread with this prompt:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    evidence/S03.json and evidence/S03-HANDOVER.md. Refresh actual local/live
    feature and main identities and verify exact-head CI. The independently
    verified tested source is 9b30f96f3f280e6c9e04b33285ee9f40ee3c0d8a;
    the later containing docs checkpoint/CI is in the prior thread's final response
    and must be refreshed. Complete ONLY S04 - Implement explicit and remembered
    tool selection. S01/S02/S03 are complete; do not reset/reimport or restart them.
    Read tasks/S04.md and its referenced specs, plus specs/SYNC_AND_RELEASE.md.
    Available host: Windows 11 Pro 26H2 26300.9711 x64, PS5.1 5.1.26100.9711
    and PS7 7.6.5; FFmpeg/ffprobe in C:\ffmpeg\bin. S03 focused final3 passes
    15 cases per shell with inherited UTF8 CP65001, bounded short operations and
    source/output ProbeTimeoutSeconds (default 60). Encode/full decode keep no short
    runtime ceiling. Retained suites and exact-source CI pass; keep original
    T-prefixed evidence-path contracts and additive proxy support. Use isolated owned
    synthetic fixtures and per-process RemoteSigned. Do not repeat owner diagnostics
    or scan ordinary Music/personal media. Preserve defaults, source safety,
    artwork and published v1.0.0. Main integration remains separate under existing
    owner-approval authority. Update evidence/state/status/next-session/decisions and
    full handover; test/review/commit/push intended changes; verify fresh live equality
    and exact-commit CI. Give the filled next-thread prompt, then STOP. Do not start
    S05. The fixed deliverable is public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread performs only S03 and ends here. Do not start S04 in this thread.

## Fixed final deliverable

Public v1.0.1 publication is PENDING_S17. Only separately started S17 publishes
S16's exact accepted source/assets. No frozen candidate or publication authority
is created by this checkpoint. Published v1.0.0 tag/assets and artwork remain.
