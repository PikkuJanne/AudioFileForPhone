# S07 handover - COMPLETED

## Outcome

S07-A1, S07-A2 and S07-A3 pass on the available Windows 11 client in both
supported shells. Tested source is c08d97571bd70d140acc89c1de86e2fc0f4c6583.
Thirty accepted local reports pass. Six final focused/first-run/native reports
identify that exact clean source; twenty-four retained reports identify entry
889db48 plus their actual S07 runtime hashes, which match the final runtime.
Earlier report/README wording and preparation attempts are not relabeled.

The containing documentation checkpoint, fresh live equality and exact-checkpoint
push/PR CI are observed after push in the session's final response. A commit
cannot contain its own final SHA. Refresh those observations on the next thread.
There is no standalone CI claim for the locally tested source commit: only its
containing checkpoint is pushed. S08 remains NOT_STARTED.

## Changes

Interactive conversion now shows the supported-file count and selected bitrate,
then Enter = start with defaults, M = customize metadata, Q = cancel. The waiting
message states that conversion has not started. Successful preflight/dependency
repair precedes the menu; no-files/dependency failures cannot show Ready.

Enter immediately retains the normal metadata/artwork policy and supplied
parameters. M exposes the existing cover/Artist/Album choices and explains that
conversion starts after the last choice, without an extra confirmation. Explicit
parameters remain authoritative, including blank Artist/Album retain-source
values. Entered custom tags are trimmed as before. Cover picker cancellation
retains the existing continue-without-cover policy. No batch metadata is saved.

Every text stage reads once through a small named helper adapter. Null/EOF and Q
at choices cancel with 130; invalid/pasted input stops with 1; unavailable or
redirected input stops with 1. Pasted code is inert. Normal conversion without
Interactive and all preview calls remain prompt-free. Existing output-writability
preflight can create an empty OutputParent; stopped menu cases create no batch,
MP3, log, manifest or partial and perform no media probe/encode/decode.

Durable console/log phase labels distinguish preflight, waiting, source probing,
encoding, validation/full decode and publication. Encoding at 100% still needs
validation. Existing final status and processed/converted/failed counts remain.

The functions-only helper gains availability/read/cover UI adapters. Shared
resolver/save/setup APIs, FfmpegDirectory/ConfigPath, absolute PATH=CWD compatibility
and all existing defaults remain. Managed engine, reviewed vendor pin, separate
setup entries and conversion BAT are unchanged from entry. Consent, retained
notices/provenance, bounded owned staging/cleanup, guarded publication retry and
validation/smoke before selection remain. Pending cancellation across engine
return before Remember is retained. Conversion performs no download.

README, SUPPORT and CHANGELOG describe the menu and cancellation. The focused
suite joins CI; retained first-run injection now selects Enter, and negative
preflight/setup assertions also reject Ready/wait text. Existing suites remain.

## Verification

Actual client: Windows 11 Pro 26H2 26300.9711 x64; Windows PowerShell
5.1.26100.9711 and PowerShell 7.6.5. Existing tools: C:\ffmpeg\bin, Gyan
2026-10-08 Git build ec420ba161. Complete tool/runtime/report hashes, actual
commands, source identities and focused case results are in S07.json.

Common flags are -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned.
Owned outer PS drivers use BOM UTF8 and CP65001; hidden PS/CMD drivers retain
explicit UTF8/65001. Native PS5.1 module lookup was repaired only in private
processes. Historical create-new report paths remain; raw reports/media/config
are outside Git in owned private storage, bound by digests. No ordinary Music,
personal media or owner config was accessed.

| Check | Command / report contract | Actual identity | Result | Evidence |
|---|---|---|---|---|
| Menu and real output | tests/Test-MetadataInteraction.ps1; S07-metadatainteraction-ps51/ps7-final74.json | Exact c08d975, both client shells | PASS 23 groups each: Enter/M/Q, invalid/pasted input, EOF at every read, actual unavailable/NonInteractive refusal, overrides/defaults, 64/96kbps, tags/art pixels, 440Hz sound and full decode | S07.json accepted reports and focused_cases |
| Setup before menu | tests/Test-FirstRunSetup.ps1; S05-firstrunsetup-ps51/ps7-final74.json | Exact c08d975 | PASS 15 groups each; successful same-launch conversion and failures/cancellation before Ready | S07.json |
| Final native resource/release | tests/Test-NativeProcess.ps1; T17-native-ps51/ps7-final71.json | Exact c08d975; last and sequential | PASS 35 groups each, owned release/cleanup and unchanged fixtures | S07.json |
| Default isolated baseline | tests/Invoke-IsolatedBaseline.ps1; T17-baseline-ps51/ps7-final71.json | Entry889db48 with final runtime hashes | PASS retained legacy and 7 required characterization checks, 3 observations; isolation/cleanup proved | S07.json |
| Metadata/artwork | tests/Test-Metadata.ps1; T15-metadata PS5.1 final72 / PS7 final71 | Entry889db48 with final runtime hashes | PASS 15 each, real formats/tags/art/chapter observations and source preservation | S07.json |
| Progress / long audio | tests/Test-Progress.ps1; T13-progress PS5.1 final72 / PS7 final71 | Same runtime | PASS 17 each, including 3605-second synthetic audio and full decode | S07.json |
| Transactions | tests/Test-TransactionalOutput.ps1; T09-transaction PS5.1 final72 / PS7 final71 | Same runtime | PASS 27 each; ownership/no-overwrite/fault safety, restored fixture ACLs | S07.json |
| No Ready on preflight failure | tests/Test-Preflight.ps1; T04-preflight-ps51/ps7-final73.json | Same runtime, strengthened test guard | PASS 35 negative plus 8 helper groups each, restored ACLs/cleanup | S07.json |
| Pure contracts | tests/ci/Test-CiContracts.ps1; T17-unit-ps51/ps7-final73.json | Same runtime and final CI runner | PASS 31 each; no fixture tree or media/test processes | S07.json |
| Managed safeguards | tests/Test-ManagedSetup.ps1; S06-managedsetup-ps51/ps7-final71.json | Same runtime; unchanged engine/pin | PASS 50 each; case50 explicitly injects engine result, not vendor installation | S07.json |
| Cancellation | tests/Test-Cancellation.ps1; T11-cancellation-ps51/ps7-final71.json | Same runtime | PASS 9 each, controlled synthetic/owned-child evidence | S07.json |
| Preview | tests/Test-Preview.ps1; T12-preview-ps51/ps7-final71.json | Same runtime | PASS 8 each, no-write/prompt-free checks | S07.json |
| Short operations | tests/Test-ShortOperations.ps1; S03-shortoperations-ps51/ps7-final71.json | Same runtime | PASS 15 each; S03 bounds retained | S07.json |
| Selection | tests/Test-ToolSelection.ps1; S04-toolselection-ps51/ps7-final71.json | Same runtime | PASS 14 each; shared precedence/config/absolute PATH compatibility | S07.json |
| Help/version | tests/Test-HelpVersion.ps1; T17-help-ps51/ps7-final71.json | Same runtime; before final exit-table clarification | PASS 7 each; runtime 1.0.0 preserved; final docs are checked by containing CI | S07.json |

Null schema fields are left unavailable, not invented as true. Retained
children-disposed/isolation/cleanup guards are recorded separately; pure contracts
have no fixture cleanup requirement.

The final focused tests inject named UI responses into byte-identical production
copies and execute real FFmpeg. Physical console EOF/dialog/owner interaction is
NOT_RUN. Null injection is not a real-console EOF observation; actual redirected
availability refusal and the unchanged production reader's NonInteractive refusal
execute. No owner diagnostic is requested.

Preparation remains honest: initial private root drivers failed before suites on
literal newline/module lookup issues; T17-preview was rejected by its historical
contract and reran as T12-preview. Three retained-suite PS5.1 attempts failed before
cases on inherited Core modules; corrected private module lookup produced passes.
Focused PS7 attempt1 failed a tiny-tone end-crossing measurement; the stable middle
half now excludes MP3 edge noise with a tighter 10Hz tolerance. PS7 attempt2 passed
the earlier test revision. PS5.1 attempt1 safely stopped but failed a strict
diagnostic assertion when formatted output split NonInteractive across lines.
Whitespace normalization retains the observed token, real reader and no-batch
assertions. Both final exact-source runs pass. All prior digests and actual
identities remain separate. No assertion or runtime safeguard was disabled.

S07 does not repeat a vendor installation. S06's real unmocked primary-vendor
installation acceptance remains separately recorded on 69bce4a with unchanged
managed engine/pin. Case50 remains engine-result injection. Windows 10 22H2,
the future exact v1.0.1 ZIP/kit and new phone evidence are NOT_RUN here.

## Git state (observe after checkpoint)

Origin: https://github.com/PikkuJanne/AudioFileForPhone.git.
Branch: codex/audiofileforphone-v1.0.1.
PR #29: https://github.com/PikkuJanne/AudioFileForPhone/pull/29, OPEN draft/unmerged.
Entry/local/live feature was 889db48f9b856129a41c5c16727a2569ded4910e.
Its push39075046972 and PR39075049920 CI passed all four jobs on fresh inspection.
Tested source is c08d97571bd70d140acc89c1de86e2fc0f4c6583.

The containing documentation HEAD, freshly advertised branch ref/equality,
comparison time, clean worktree and exact-head push/PR CI are recorded after push
in the final response. They must be observed before this session is considered
finished. Tracking refs alone are not proof. No standalone source-commit CI is
claimed; containing-checkpoint CI tests its identical runtime and final docs.

Main remains independently NOT_INTEGRATED. Entry local/live main is
28f53b10529495754273d55654c7b29e78848c83; refresh at the final checkpoint. S14
integration retains ordinary reviewed PR policy and the owner-approval default.
No main merge, force/reset/clean, protection/visibility/history or tag/release
operation is authorized by this step.

## Decisions, risks and blockers

D38 records one-shot Enter/M/Q and explicit parameter precedence. D39 records
no-batch/preflight semantics, test-measurement/formatting repairs and evidence
boundaries. D40 records exact-source versus earlier local identities and the
containing-checkpoint observation protocol. Independent runtime and test reviews
have no outstanding implementation findings. No S07 local implementation blocker
remains; final containing-checkpoint CI must be observed after push.

## Human action

None for S07. Consolidated owner/phone/OS work remains S15's ready-to-run kit and
short guide. No PATH edits, repeated owner diagnostics or personal-media scan.

## Next step and fully filled prompt

S08 - Harden the BAT and PowerShell startup route is next eligible and NOT_STARTED.
Open a separate thread; refresh the containing checkpoint from the previous final
response. Use:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Tested source: c08d97571bd70d140acc89c1de86e2fc0f4c6583.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    RELEASE_TARGET.json, evidence/S07.json and evidence/S07-HANDOVER.md.
    Refresh local/live feature/main identities, the containing checkpoint from
    the previous final response, and exact-head CI.
    Complete ONLY S08 - Harden the BAT and PowerShell startup route.
    S01-S07 are complete; do not restart them. Read tasks/S08.md,
    specs/LAUNCH_AND_INTERACTION.md, specs/DIAGNOSTICS_AND_TIMEOUTS.md and
    specs/SYNC_AND_RELEASE.md.
    Available host: Windows 11 Pro 26H2 26300.9711 x64,
    PS5.1 5.1.26100.9711, PS7 7.6.5; FFmpeg/ffprobe C:\ffmpeg\bin.
    Implement minimal bounded host selection/health checking and explicit host
    override, preserve exact host/architecture/STA identity and literal arguments.
    Fallback is allowed only before application entry, never after an app exit
    and never around enforced enterprise policy. Test startup deadlines, working
    directories, argument edge cases, exit0/1/2/130, redirected input/no endless
    pause, missing helpers and no second conversion after application failure.
    Retain Enter/M/Q, explicit metadata precedence, EOF/unavailable-input safety,
    prompt-free normal calls and no batch metadata saving. Retain shared
    resolver/save/setup APIs, FfmpegDirectory/ConfigPath, absolute PATH=CWD
    compatibility and separate consent-based managed setup. Conversion never
    downloads. Preserve reviewed pin/notices/provenance, owned bounded staging/
    cleanup, guarded publication retry, validation/smoke before selection and
    pending cancellation across engine return before Remember. Case50 is engine-
    result injection; S06 real vendor installation acceptance remains separate.
    Retain UTF8 CP65001 and explicit UTF8 owned hidden PS/CMD drivers, historical
    evidence paths, isolated synthetic fixtures/config, S03 deadlines and
    cancellation/release safeguards, and unlimited normal encode/decode runtime.
    Do not repeat owner diagnostics or scan ordinary Music/personal media.
    Preserve defaults, sources, artwork and published v1.0.0. Keep main
    integration separate under existing owner-approval authority.
    Update evidence/state/status/next-session/decisions and full handover.
    Test/review/commit/push; verify fresh live equality and exact-commit CI.
    Give the filled next-thread prompt, then STOP. Do not start S09.
    Fixed deliverable: public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread ends after the S07 checkpoint. No S08 implementation starts here.

## Fixed final deliverable

Public v1.0.1 is PENDING_S17. Runtime remains 1.0.0; no frozen release source,
accepted ZIP digest or publication authority exists. Only separately started S17
publishes S16's exact accepted source/assets. The fixed title/tag/runtime ZIP are
AudioFileForPhone v1.0.1, v1.0.1 and AudioFileForPhone-v1.0.1.zip.
Published v1.0.0, existing artwork and source media are preserved.
