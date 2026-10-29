# S08 handover - COMPLETED

## Outcome

Source 64628f05a86957e2381e5bf1041ce5ecd49da4f3 contains the startup implementation
and a test-only healthy-host budget correction. Packaged runtime bytes are unchanged
from d5db9cb6a6e20373dbb599fc5d4e79164ef7e99c. S08 focused acceptance passes 76
groups in each client shell; retained launcher characterization passes 66 each.
All 22 accepted local suite reports pass, covering 694 groups. Seven identify
exact source 64628f0; fourteen retain d5db9cb and one first-run report retains entry
73bb303 with the actual matching final runtime hashes. Two additional analyzer
reports pass. Source identities are preserved, not relabeled. The containing
checkpoint's advertised equality and exact-head CI are observed after push in the
final response. S09 remains NOT_STARTED and requires a separate thread.

## Changes

The one-folder BAT keeps delayed expansion disabled and transports the received
folder through process-local environment. A fixed native Windows PowerShell
bootstrap invokes a small launcher using NoProfile/STA/File/RemoteSigned.
RemoteSigned replaces Bypass without changing saved policy. Direct application
calls and their existing parameter interface remain available.

Selection probes at most three absolute-PATH PS7 candidates, a conventional
installed PS7 path and native PS5.1. Implicit CWD/relative PATH do not grant host
authority; intentional absolute PATH=CWD remains compatible. HostPath, or
AUDIOFILEFORPHONE_HOST for BAT, requires one exact absolute local executable and
never falls back. The default15-second per-probe deadline is configurable1..60.
Existing native capture/drain/owned teardown are reused. Known missing hosts create
no child/pipes. Only safe absence, unsupported structured identity or a timeout
with proved release permit pre-entry fallback. Unknown refusal, managed signing/
language policy and uncertain release stop selection.

Healthy hosts report actual executable/version/edition, separate OS/process
architecture and STA. Store aliases resolve to their real executable and repeat
the probe with unchanged identity fields. The application-independent probe imports
its own built-in Security module and emits ASCII-escaped JSON without changing
console encoding. Module precedence changes only in the selected child process.
Caller CWD and literal arguments survive. There is one application start site,
unlimited normal application runtime and no retry after any application result.
Codes0/1/2/130 survive reporting and console handling. Redirected/unavailable input
never waits on a mandatory pause. A console retains the same outcome window;
missing bootstrap prints a direct route and missing runtime identifies its filename.

Enter/M/Q, metadata precedence/EOF safety, prompt-free normal calls, no batch
metadata persistence, shared resolver/save/setup APIs, FfmpegDirectory/ConfigPath,
64kbps CBR defaults, sources/artwork and transactional output remain. Helpers,
managed engine, setup entries and reviewed pin are unchanged from entry. Consent,
notices/provenance, bounded owned staging/cleanup, guarded retry, validation/smoke
before selection and pending cancellation before Remember remain. Conversion never
downloads. Case50 remains engine-result injection; S06 real vendor acceptance stays
separate on69bce4a. Normal encode/full decode remain unlimited. Parent waiting does
not poll the application's cancellation buffer.

The focused suite joins CI. Retained argument/exit coverage and historical report
paths remain. Both launcher files join package allowlists, required-member tests
and analyzer coverage. CI uploads only the exact current-run S08 report alongside
historical current-run reports. README/SUPPORT/CHANGELOG document behavior and the
override. No artwork, production dependency, persistent environment/policy, tag or
release changed.

## Verification

Actual Windows11 Pro26H2 build26300.9711 x64; PS5.1.26100.9711, portable Codex
PS7.6.5 and actual Store PS7.6.7 run x64/STA. There is no classic MSI PS7 install.
Existing conversion tools C:\ffmpeg\bin are Gyan2026-10-08 Git ec420ba161.
Package policy uses CI-pinned9.0.2 and analyzer1.25.0 separately provisioned in
owned development storage, not an application install.

S08.json contains exact commands, actual source/file identities, report contracts,
SHA256s, case summaries and nonpasses. Common flags: NoLogo/NoProfile/
NonInteractive/ExecutionPolicy RemoteSigned. Owned BOM UTF8 PS and hidden UTF8
CMD drivers retain CP65001 and own-host module precedence. Raw media/config/
reports/drivers remain private; historical create-new contracts are preserved.

| Check | Artifact/command contract | Actual identity | Result |
|---|---|---|---|
| Focused startup | Test-Launcher.ps1; S08-launcher-ps51/ps7-final83.json | Exact64628f0 | PASS76 each; actual three hosts/Store pin, literal paths/CWD, exits0/1/2/130, redirected stdin, missing files, owned .lnk, injected policy/release and real startup timeout/fallback |
| Retained launcher | Test-LauncherResults.ps1; S08-launcherresults-ps51/ps7-final82.json | d5db9cb, final runtime | PASS66 each; direct PS7/PS5.1 and old argument/exit cases |
| Metadata/output | Test-MetadataInteraction.ps1; S07-metadatainteraction-ps51/ps7-final82.json | d5db9cb | PASS23 each; real output/tags/art/sound/full decode, menu and input guards |
| First-run/setup | Test-FirstRunSetup.ps1; S05-firstrunsetup-ps51/ps7-attempt81.json | PS51 entry73bb303 with final hashes; PS7 d5db9cb | PASS15 each |
| Resolver/config | Test-ToolSelection.ps1; S04-toolselection-ps51/ps7-attempt81.json | d5db9cb | PASS14 each, including absolute PATH=CWD |
| Preview/help/contracts | Test-Preview/Test-HelpVersion/tests/ci/Test-CiContracts; T12/T17 attempt81 | d5db9cb | PASS8/7/31 each |
| Short operations | Test-ShortOperations.ps1; S03-shortoperations-ps7-attempt81 / ps51-final84 | d5db9cb / exact64628f0, matching runtime | PASS15 each; final PS51 run isolated and unchanged |
| Package policy | Test-Package.ps1; T17-package-ps51/ps7-final83.json | Exact64628f0, pinned tools | PASS57 each; both new required members and rejection guards |
| Native/release | Test-NativeProcess.ps1; T17-native-ps51/ps7-final84.json | Exact64628f0; last and sequential | PASS35 each; unchanged fixtures and owned release/cleanup |
| Static correctness/security | PSScriptAnalyzer1.25.0 configured rules plus default Errors | Exact64628f0, both shells,10 files | PASS zero diagnostics |

Direct real hung-start probes use1second and finish1062/1018ms with release/drain
proved. Real hanging-host then PS5.1 selection uses5seconds, total5531/5695ms.
The owned .lnk runs ShellExecute hidden in TEMP with redirected streams; physical
Desktop/Explorer input is unclaimed. Inert exit130 is forwarding evidence, not
physical Ctrl+C. Policy/unsupported architectures are injected; enterprise settings
are untouched. Unicode executable serialization is a lossless pure roundtrip;
actual Unicode script/input/CWD paths execute through CMD.

Early null-array/aggregation assertions were harness issues; source-changing runs
correctly failed integrity guards. One pre-case PS51 driver inherited Core modules;
private own-host lookup fixed it. Earlier focused fallback tests used an overly
short1second healthy-host budget and safely stopped at1079/1108ms. The separate
strict1second hung-start test remains. Package attempt81 rejected the existing Git
build because provenance requires the CI pin. A malformed private package CMD
generator was corrected before the suite, without changing safeguards.

S03 PS51 attempt81 failed inside its independent held-pipe fixture before identity
record/expected messages. The helper returned Timeout and withheld release proof;
original fixtures remain retained. The340-character stderr was not saved, so its
exact cause is unconfirmed. A new owned diagnostic with byte-identical fixture/
helper produced expected parent exit0, both messages and descendant identity, then
stopped only the exactly verified descendant. Original nonpass/root remain private.
The unchanged isolated final PS51 suite passes all 15 groups, source/fixture
integrity, release and cleanup. The original cause remains unconfirmed; a later
pass does not relabel it. No safeguard or assertion was disabled.

Windows10, classic MSI PS7, physical drag/drop/dialog/console Ctrl+C, future exact
v1.0.1 ZIP/kit and new phone observations are NOT_RUN. The retained harness requires
a direct PS7 candidate; focused tests separately verify Store aliases. No ordinary
Music, personal media, owner config or owner action was used.

## Git state (observe after checkpoint)

Origin https://github.com/PikkuJanne/AudioFileForPhone.git; branch
codex/audiofileforphone-v1.0.1; PR29 OPEN draft/unmerged at
https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Entry feature local/live
73bb303972da55e6f0c160467e7dd8c9b1ec0a4b matched. Exact push39080221388 and
PR39080224509 passed all4 jobs. Source64628f0 is local; its runtime equals d5db9cb.

The containing documentation checkpoint, clean worktree, push result, freshly
advertised feature/main identities and exact-head push/PR CI must be observed after
push in the final response. A commit cannot contain its own SHA; refresh those
observations next thread. No standalone CI claim for unpushed source commits.
Main remains separately NOT_INTEGRATED, entry local/live
28f53b10529495754273d55654c7b29e78848c83. S14 reviewed PR policy and existing
owner approval remain. No merge/protection/history/visibility/tag/release change.

## Decisions, risks and blockers

D41-D45 record bootstrap/override, bounded conservative fallback and identities/
policy/encoding/module handling. Independent runtime review found no remaining
implementation blocker. During supported cancellation the application owns the
shared console input buffer; parent polling could steal its keystroke. Physical
behavior remains unclaimed. See [Windows console input modes](https://learn.microsoft.com/en-us/windows/console/setconsolemode).
No local implementation blocker remains. Final checkpoint live equality/CI are
observed after push before the session ends; refresh them next thread.

## Human action

None for S08. Consolidated Windows/phone owner acceptance stays in S15's prepared
kit and short guide. No PATH editing, repeated diagnostics or media upload.

## Next step and fully filled prompt

S09 is next eligible and NOT_STARTED, only in a separate thread.
Refresh the containing checkpoint recorded in the previous final response. Use:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Tested source: 64628f05a86957e2381e5bf1041ce5ecd49da4f3; packaged runtime
    is unchanged from d5db9cb6a6e20373dbb599fc5d4e79164ef7e99c.
    Refresh the containing checkpoint from the previous final response,
    fresh local/live feature and main identities, and exact-head CI.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    RELEASE_TARGET.json, evidence/S08.json and evidence/S08-HANDOVER.md.
    Complete ONLY S09 - Plan valid bitrate and sample-rate combinations.
    S01-S08 are complete; do not restart them. Read tasks/S09.md,
    specs/ENCODING_COMPATIBILITY.md and specs/SYNC_AND_RELEASE.md.
    Available client: Windows 11 Pro 26H2 26300.9711 x64,
    PS5.1 5.1.26100.9711, portable PS7 7.6.5 and Store PS7 7.6.7;
    existing FFmpeg/ffprobe C:\ffmpeg\bin (Gyan Git ec420ba161).
    Use actual Windows reproduction/capabilities for a shared output audio
    plan. Each advertised bitrate must yield a valid planned result or an
    explicit pre-encode incompatibility. Never accept clamped wrong bitrate.
    Preserve ordinary 64 kbps sound, mono/stereo and metadata; handle
    multi-channel limits explicitly, extend manifest/validation and run the
    required bitrate/sample-rate/channel matrix in both supported shells.
    Retain the bounded pre-entry launcher/host override, exact x64/STA and
    literal arguments/CWD, policy refusal and no retry after application exit.
    Preserve Enter/M/Q, explicit metadata precedence, EOF/input safety,
    prompt-free normal calls and no batch metadata saving. Retain resolver/
    save/setup APIs, FfmpegDirectory/ConfigPath and absolute PATH=CWD.
    Conversion never downloads. Separate managed setup remains consent-based;
    preserve reviewed pin/notices/provenance, bounded owned staging/cleanup,
    guarded publication retry, validation/smoke before selection and pending
    cancellation before Remember. Case50 is engine-result injection; S06 real
    vendor acceptance remains separate. Keep CP65001 and explicit UTF8 owned
    hidden PS/CMD drivers, historical evidence contracts, isolated fixtures/
    config, S03 deadlines and cancellation/release guards. Normal encode/full
    decode have no short runtime ceiling. Keep all S08 nonpasses/evidence
    limitations; do not disable a safeguard to make a test pass.
    Do not repeat owner diagnostics or scan ordinary Music/personal media.
    Preserve defaults, sources, artwork and published v1.0.0. Keep main
    integration separate under S14 reviewed policy and existing owner approval.
    Update evidence/state/status/next-session/decisions and full handover.
    Test/review/commit/push; verify fresh advertised equality and exact-commit CI.
    Give the filled next-thread prompt, then STOP. Do not start S10.
    Fixed deliverable: public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread ends after the S08 checkpoint. No S09 implementation starts here.

## Fixed final deliverable

Public normal v1.0.1 remains PENDING_S17. Runtime remains1.0.0. No frozen release
source, accepted v1.0.1 ZIP or publication authority exists. Only separately started
S17 publishes S16's exact accepted source/assets as AudioFileForPhone v1.0.1,
tagv1.0.1 and AudioFileForPhone-v1.0.1.zip. Published v1.0.0 is preserved.
