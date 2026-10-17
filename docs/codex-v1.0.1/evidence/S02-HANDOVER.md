# S02 handover - COMPLETED

## Outcome

S02-A1/A2/A3 pass. Reviewed preparation 76339f97211868b3bd23bb1557cc91469d287270
is pushed, clean/live-equal under both local shells, and green in exact-head push
and associated PR CI. Downloaded structured reports verify the new family actually
executed. Final docs-only record receives its own post-push live/CI observation in
the session response. S01 remains complete; S03 has not started. Captured failures
remain unfixed by design in this step.

## Changes

Added tests/Test-SetupEncodingRegressions.ps1, a bounded, marker-owned, real-tool
characterization harness using byte-identical application copies, supported M4A
ALAC fixtures and public OutputParent. It tests sanitized no-profile missing-tool
search scopes, default 64 kbps controls and the reported mono/stereo bitrate leads.
Saved-selection fixture/API expectations are pending explicitly. CI adds this one
real-media family before its existing final native-process suite. No old suite,
evidence contract, runtime entry point/default, artwork or historical evidence was
changed. Structured S02 records are public; raw reports/logs stay outside Git.

## Verification

All commands run from C:\projects\AudioFileForPhone-main. Resolve absolute shells
with (Get-Command powershell.exe).Source and (Get-Command pwsh.exe).Source. Each
owned child uses -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned;
inherited PSModulePath is removed only from its environment. Console output page
65001 is inherited; no new console, persistent PATH or machine policy changes.

| Check | Exact command or artifact | Environment/runtime identity | Result | Evidence |
|---|---|---|---|---|
| Isolation validation | tests/Invoke-IsolatedBaseline.ps1 -ValidateOnly -EvidencePath docs/codex-v1/evidence/T17-s02-isolation-ps51-attempt1.json (and ps7) | Windows 11 Pro 26H2 26300.9711 x64, PS5.1 5.1.26100.9711 / PS7 7.6.5 | PASS both; unchanged copies, exact owned cleanup | S02.json retained_suites |
| Retained baseline | Same wrapper without ValidateOnly, -FfmpegPath C:/ffmpeg/bin/ffmpeg.exe -FfprobePath C:/ffmpeg/bin/ffprobe.exe -EvidencePath docs/codex-v1/evidence/T17-s02-baseline-ps51-attempt1.json (and ps7) | Local Git build 2026-10-08-git-ec420ba161 essentials; exact binary hashes in reports | PASS both legacy suites; 7 required characterization checks + 3 separate observations per shell | S02.json retained_suites |
| Focused regressions | tests/Test-SetupEncodingRegressions.ps1 -FfmpegPath C:/ffmpeg/bin/ffmpeg.exe -FfprobePath C:/ffmpeg/bin/ffprobe.exe -EvidencePath docs/codex-v1.0.1/evidence/S02-regressions-ps51-final1.json (and ps7) | Same client/tools; runtime unchanged at tested prior source 888b4f12da31af417b4f03c050147440fe0cf27c; harness hashes bound | PASS 12 characterized cases per shell; 2 API cases pending separately | S02-regressions-ps51-final1.json, S02-regressions-ps7-final1.json |
| CI pure contracts | tests/ci/Test-CiContracts.ps1 -EvidencePath docs/codex-v1/evidence/T17-unit-ps51-attempt20261017.json (and ps7) | Both actual local shells; no media | PASS 31 cases each | S02.json retained_suites |
| Evidence overwrite refusal | Repeat the PS5.1 regression command with existing final1 destination | Same client | Expected exit 1 before conversion; evidence SHA256 unchanged | S02.json evidence_overwrite_guard |
| Independent review | Read-only subagent audit plus root intended-diff/privacy/scope/whitespace checks | Actual new harness and two-line CI change | No material blockers; bounded pipe review fix included | S02.json review |
| Feature sync | Each shell with common flags above, -File docs/codex-v1/tools/Test-GitSync.ps1 -RepoPath C:/projects/AudioFileForPhone-main -AsJson | Preparation 76339f97211868b3bd23bb1557cc91469d287270 | PASS clean/live-equal at 15:32:02.7656208Z / 15:32:05.3191008Z | S02.json checkpoint_verification |
| Exact-head CI and PR checks | gh run view 39045431885 / 39045437165 --repo PikkuJanne/AudioFileForPhone --json headSha,status,conclusion,jobs; gh run download each into private local evidence | Push checks feature 76339f97211868b3bd23bb1557cc91469d287270; PR integration checkout ac3eed99df04d021a8d7ee60d7ab230c4e14b6cf | PASS all four jobs; source unchanged, exact event checkout, 12 focused cases + all retained families verified from artifacts | S02.json ci |

Each focused shell run records two missing-tool failures (exit 1, converted 0,
neither command resolvable, output parent absent), four normal default controls
(64 kbps, omitted bitrate parameter, full decode and exact rate/channel/sample
shape), and these independently measured outcomes for both mono and stereo:

| Source rate | Requested | Direct encoder stream | Actual app result |
|---|---|---|---|
| 48 kHz | 8 kbps | 32 kbps at 48 kHz | Exit 2, ValidationFailed, no promoted MP3 or partial residue |
| 48 kHz | 144 kbps | 128 kbps at 48 kHz | Same safe late rejection |
| 8 kHz | 192 kbps | 64 kbps at 8 kHz | Same safe late rejection |

Synthetic sources are 0.75 seconds; all source/config SHA256 inventories match
before/after and exact marker/reparse-checked cleanup passes. Direct comparison
MP3s fully decode. Published controls are independently probed and decoded. Legacy
configured child PATH success is not clean first-run or external-selection success.

Two preparation attempts are invalid, preserved locally and bound by digest:
PS5.1 root-array wrapping needed a harness correction; the next run's source hash
guard detected the pipe-safety edit applied during execution. Final1 reran frozen
harness bytes successfully under both shells. Neither failure is an app result.

Windows 10, another locally tested FFmpeg build, the owner's 2026-10-15 build,
full advertised bitrate matrix, exact candidate ZIP/kit and new phone evidence are
not established here. Hosted CI is supplementary Windows Server evidence.

## Git state (observe after checkpoint)

Expected origin: https://github.com/PikkuJanne/AudioFileForPhone.git. Active branch
codex/audiofileforphone-v1.0.1, open draft PR #29:
https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Entry local/live HEAD is
888b4f12da31af417b4f03c050147440fe0cf27c, clean; exact-head push 39044347056 and
PR 39044349551 pass both jobs. Local/live main remain
28f53b10529495754273d55654c7b29e78848c83. Fetch and independent ls-remote confirmed
these entry identities. Preparation 76339f97211868b3bd23bb1557cc91469d287270 was
pushed and independently verified clean/equal at 15:32:02Z (PS5.1) and 15:32:05Z
(PS7). Push CI39045431885 and PR CI39045437165 pass both jobs; downloaded artifact
reports confirm the exact feature/integration checkout distinction above. Main
integration remains NOT_INTEGRATED, deferred to S14 ordinary reviewed policy and
existing owner-approval default. No frozen release SHA or ZIP exists. The final
containing commit cannot store its own SHA; final response reports its fresh
live equality and exact-commit CI, and the next thread must refresh them.

## Decisions, risks and blockers

Capture existing behavior without weakening exact bitrate or full-decode checks.
Stale config and external selection are PENDING_API until actual public APIs exist;
no mock claim or hidden resolver. Missing-tool failure is reproduced; the three
Linux leads are now reproduced on the available Windows build. Their correction
belongs to later planned work. There is no owner action blocker for S02.

## Human action

None for this step. Consolidated client/package/phone evidence remains S15 work.
No repeated diagnostics, manual commands, PATH edits or personal media requested.

## Next step and fully filled prompt

Next eligible step is S03 - Add bounded short-operation execution, NOT_STARTED.
Start a new thread with this prompt:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1, draft PR #29:
    https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Read AGENTS.md,
    CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md, evidence/S02.json and
    evidence/S02-HANDOVER.md; inspect actual diff and refresh local/live feature
    and main identities plus exact-head CI. Complete ONLY S03 - Add bounded
    short-operation execution. Read tasks/S03.md and its referenced specs, plus
    specs/SYNC_AND_RELEASE.md. S01/S02 are complete; do not reset/reimport them.
    Last independently verified preparation checkpoint is
    76339f97211868b3bd23bb1557cc91469d287270. Actual local Windows 11 Pro 26H2
    26300.9711 x64 has PS5.1 5.1.26100.9711 and PS7 7.6.5. Local FFmpeg/ffprobe
    C:\ffmpeg\bin report 2026-10-08-git-ec420ba161 essentials. S02 final1 passes
    12 cases per shell; both retained baseline suites and 31 CI contracts per
    shell pass. Known late bitrate failures remain captured, not fixed; saved
    selection APIs remain pending. Runtime remains unchanged from
    28f53b10529495754273d55654c7b29e78848c83. Keep real FFmpeg suites, historical
    T-prefixed evidence contracts and inherited UTF8 CP65001; use isolated owned
    fixtures, public OutputParent and per-process RemoteSigned. Do not repeat
    owner diagnostics or scan ordinary Music/personal media. Preserve defaults,
    source safety, artwork and published v1.0.0. Main integration remains separate
    under the existing owner-approval default. Update evidence/state/status/
    next-session/decisions and full handover; test/review/commit/push intended work,
    verify fresh live equality and exact-commit CI. Give filled next-thread prompt,
    then STOP. Do not start S04. Fixed final deliverable is public v1.0.1; only
    separately started S17 publishes S16's exact accepted source/assets.

## Stop

This thread performs only S02. Stop at the completed or incomplete checkpoint.

## Fixed final deliverable

Public v1.0.1 remains PENDING S17. Only a separately started S17 using S16's exact
accepted source/assets prompt publishes. Runtime remains unchanged at 1.0.0;
existing published v1.0.0, tag/assets and current owner artwork are preserved.
