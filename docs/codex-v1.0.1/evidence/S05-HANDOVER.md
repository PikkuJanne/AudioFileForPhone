# S05 handover - COMPLETED

## Outcome

S05-A1/A2/A3 pass on Windows 11 Pro 26H2 26300.9711 x64 under Windows
PowerShell 5.1.26100.9711 and PowerShell 7.6.5. Fifteen focused groups per shell
exercise production setup and actual synthetic conversion. UI choices are
scripted at named adapters; no physical dialog or owner observation is claimed.
Actual MTA dialog unavailability and noninteractive Host.UI refusal execute the
production adapters. No owner action is needed. S06 remains NOT_STARTED.
The public v1.0.1 release remains pending.

## Changes

Setup-AudioFileForPhone.ps1 and its simple BAT select an existing exact bin
directory, validate through the S04 shared resolver, display paths/builds/
architecture/SHA256 and ask before remembering. Explicit FfmpegDirectory validates
without prompts; Remember is deliberate persistence, ConfigPath is retained and
NonInteractive refuses missing selection. BAT uses the full Windows PowerShell
path, STA and process RemoteSigned; it preserves the result and skips a redirected
pause. There is no post-entry fallback or persistent policy change.

Functions-only Helpers adds the shared bounded setup flow and UI adapters.
S/M/D/Q offers existing selection, manual/offline instructions, clearly unavailable
download or cancellation. Dialog failure permits one typed-path fallback; cancel,
EOF and invalid input stop without retry loops. Only the exact chosen pair runs.
Read guards cover validation/hash/consent/save. Shared S04 config parsing, atomic
save and resolver precedence remain intact, including absolute PATH=CWD support.

Interactive conversion repairs selection before metadata/output reservation and
continues the same launch. Declining remember creates no config. Failed saving
clearly says NOT remembered and allows that current conversion; standalone
requested-save failure returns1 with an explicit conversion route. Controlled
setup cancellation returns130. Ordinary noninteractive failures print an exact
quoted repair action; preview never invokes setup or reads config/tools.

Public docs describe existing-tool/offline recovery. The original first five
README/help examples remain in order and unchanged. Package allowlist, builder and
independent policy tests now include both setup entries. CI adds the new family
without replacing assertions, historical report contracts or native-last order.
No runtime download, global install, new dependency or S06 implementation exists.

Main conversion BAT, icons/posters, runtime 1.0.0, 64 kbps CBR default, input formats,
Music destination/OutputParent, layout/date-first names, metadata and source safety
remain. S03 deadlines, transactional publication/full decode, cancellation/resource
release and unlimited normal encode/decode runtime remain.

## Verification

Commands run from C:\projects\AudioFileForPhone-main. Resolve powershell.exe/pwsh.exe
with Get-Command; PS7 is this machine's bundled runtime. Common flags:
`-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned`. Outer children
inherit CP65001 and remove PSModulePath only from their own environment. Hidden
PowerShell fixture drivers explicitly emit UTF8, audited as 65001, matching retained
help/regression drivers. Owned BOM-less CMD fixtures establish 65001 before reading
their Unicode BAT path. No persistent console/environment setting is changed.

| Check | Exact command/artifact | Environment and source | Result | Evidence |
|---|---|---|---|---|
| Setup production flow | tests/Test-FirstRunSetup.ps1 -EvidencePath docs/codex-v1.0.1/evidence/S05-firstrunsetup-ps51/ps7-final3.json -FfmpegPath C:/ffmpeg/bin/ffmpeg.exe -FfprobePath C:/ffmpeg/bin/ffprobe.exe | Actual client/shells above; cea42175a309fc841445f2765fc19e1d6de4c35e |15 groups each; four real conversions each with independent 64 kbps MP3/artist/full decode, save/read/decline/failure, cancellation/EOF/invalid pair, exact repair, preview, standalone and BAT | S05.json accepted_local_reports |
| Retained baseline/isolation | tests/Invoke-IsolatedBaseline.ps1 with/without -ValidateOnly; T17-s05-isolation/baseline-ps51/ps7-final12.json | Actual client; report's tested_commit recorded | Legacy0,7 required characterizations and3 observations; exact copies/cleanup | S05.json |
| Pure/help/selection/preview | tests/ci/Test-CiContracts.ps1; tests/Test-HelpVersion.ps1; tests/Test-ToolSelection.ps1; tests/Test-Preview.ps1 | Actual client; unchanged final runtime |31/7/14/8 per shell | S05.json |
| Retained safety | tests/Test-TransactionalOutput.ps1; Test-Cancellation.ps1; Test-ShortOperations.ps1; Test-SetupEncodingRegressions.ps1; Test-CleanupSafety.ps1; Test-NativeProcess.ps1 | Actual client; actual source per report, runtime hashes unchanged since dcc9408 |27/9/15/12/181/35 per shell; native last/sequential | S05.json |
| Exact source CI | push 39058815762; PR 39058820107; gh run view/download into fresh private directories | cea4217 push checkout; PR integration checkout separately recorded; hosted Server supplementary | All four jobs pass; downloaded report digests verify 15 setup groups and all retained families, including pinned package policy | S05.json ci |
| Review | Independent runtime/test/docs audits; git -c core.whitespace=cr-at-eol diff --check 01f90de..HEAD | Intended scope and actual final diff | No remaining blocker; no private media/log/config/binary artifacts | S05.json review; D29-D32 |

S05.json records all 26 exact invocation arrays, actual
tested_commit, final source/runtime hashes, report digests and observed results. Reports are
create-new at their original contracts, then moved literally into marked private
TEMP records. Raw reports, logs, fixture audio/config and CI artifacts stay outside
Git. Some retained reports ran on dcc9408/6b09917; all five final runtime files are
unchanged across those commits to cea4217. This distinction is explicit, not a
claim that each report used one later commit. Final-source focus and complete CI
provide the final test/diagnostic-driver verification.

Preparation failures are preserved honestly: initial README fence ordering failed
the retained help suite; corrected docs keep every old assertion. Redirected
PS5.1 and hidden CMD fixture encoding required UTF8 handling; strict Unicode
command checks were not weakened. The product also prints the copyable action
outside wrapping error records. A local package-policy check correctly rejected
the supplied Git build because that suite requires its retained CI-pinned 9.0.2
tools. No pin or safeguard was disabled; exact-source CI supplies package-policy
coverage. This is not acceptance of the eventual exact v1.0.1 ZIP.

Physical dialogs, Windows 10 22H2, another local vendor build, exact release ZIP/
acceptance kit and new phone evidence are NOT_RUN here and remain future gates.
No diagnostics were requested from the owner and no ordinary Music/media/config
was scanned. Server CI is supplementary to actual Windows 11 client execution.

## Git state (observe after checkpoint)

Origin https://github.com/PikkuJanne/AudioFileForPhone.git; branch
codex/audiofileforphone-v1.0.1; OPEN draft PR #29:
https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
Entry 01f90defb27bb8af8736e5206a8e68999410f57d was clean/live-equal; exact entry
push 39051866628 and PR 39051870270 pass. Local/live main remains
28f53b10529495754273d55654c7b29e78848c83.

Tested source cea42175a309fc841445f2765fc19e1d6de4c35e is normally pushed and
independently advertised by fresh ls-remote; exact-source push/PR CI pass. The final
containing documentation HEAD cannot contain itself: its fresh clean/live equality,
comparison time and exact-head CI are observed after push in the final response.
Refresh those next entry. No force/reset/clean, merge, history/protection/visibility,
tag or release operation occurred.

Main integration is NOT_INTEGRATED under S14 ordinary reviewed PR policy and the
existing owner-approval default. No frozen source/ZIP exists. Runtime 1.0.0 and
published v1.0.0 are preserved; eventual fixed public target remains v1.0.1.

## Decisions, risks and blockers

D29-D32 record shared existing-tool setup, bounded consent/input, exact repair,
honest fixture/pin preparation failures and checkpoint authority. No S05 blocker
remains. Physical UI evidence is not inferred from adapter automation. Existing
S04 atomic save and arbitrary external-editor race limits remain unchanged.

## Human action

None for S05. Consolidated human/phone/OS acceptance remains S15's prepared kit.

## Next step and fully filled prompt

S06 - Implement consent-based managed dependency setup is eligible, NOT_STARTED.
Start a separate thread using:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    RELEASE_TARGET.json, evidence/S05.json and evidence/S05-HANDOVER.md.
    Refresh local/live feature and main identities and exact-head CI.
    Tested source: cea42175a309fc841445f2765fc19e1d6de4c35e; refresh the later
    containing checkpoint recorded in the previous final response.
    Complete ONLY S06 - Implement consent-based managed dependency setup.
    S01-S05 are complete; do not restart them. Read tasks/S06.md, its referenced
    specs and SOURCES.md, and specs/SYNC_AND_RELEASE.md.
    Available host: Windows 11 Pro 26H2 26300.9711 x64, PS5.1 5.1.26100.9711,
    PS7 7.6.5; existing FFmpeg/ffprobe C:\ffmpeg\bin.
    Retain FfmpegDirectory/ConfigPath, shared resolver/save/setup APIs, absolute
    PATH=CWD compatibility, one-shot setup/cancel/EOF and clear save-failure
    behavior. D is intentionally unavailable until this S06 implementation.
    Keep conversion free of downloads; setup requires affirmative consent,
    reviewed exact vendor ZIP provenance/hash/bounds, safe owned staging and
    validation/smoke before selecting. Preserve user-managed tools/notices.
    Retain inherited outer CP65001, explicit UTF8 owned hidden PS/CMD drivers,
    historical evidence paths, isolated owned synthetic fixtures/config,
    S03 deadlines/cancellation/release safeguards and unlimited encode/decode.
    Do not repeat owner diagnostics or scan ordinary Music/personal media.
    Preserve defaults, sources, artwork and published v1.0.0. Keep main
    integration separate under existing owner-approval authority.
    Update evidence/state/status/next-session/decisions and full handover.
    Test/review/commit/push; verify fresh live equality and exact-commit CI.
    Give the filled next-thread prompt, then STOP. Do not start S07.
    Fixed deliverable: public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread ends after S05. No S06 work starts here.

## Fixed final deliverable

Public v1.0.1 is PENDING_S17. Only separately started S17 publishes S16's exact
accepted source/assets. No candidate or publication authorization is created by
S05. Published v1.0.0 tag/assets and current artwork remain.
