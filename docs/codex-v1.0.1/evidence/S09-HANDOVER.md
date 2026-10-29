# S09 handover - COMPLETED

## Outcome

S09 implements a shared output audio plan from actual selected-encoder sample-rate
capabilities and reproduced Windows MPEG/CBR limits. Every advertised bitrate is
retained. Ordinary compatible 64 kbps mono/stereo keeps its sample rate, channel
shape and decoded sound. Other compatible combinations explicitly resample to the
nearest supported rate, with ties toward the lower rate. Known standard
multichannel layouts explicitly downmix to stereo; unsupported or inconsistent
layouts receive a stable pre-encode incompatibility. Wrong clamped bitrate is
never accepted.

Production source is `57f90c4f73c385b0b0e562f487b8cf945a60de2a`. Current source
`1dcf1b398d610dd478922d5dba672992ca4d5d0f` contains only the cleanup-test API fix
after the earlier test/CI checkpoint; its runtime is unchanged from that production
source. Earlier reports retain their actual source
identities and are not relabeled as final-source reports.

S09-A1/A2/A3 pass on the available Windows client. All 26 accepted local suite
reports pass 666 groups, plus 1,980 planned matrix conversions and 128 actual
application conversions. Ninety-two compatible default cases have identical
legacy/planned decoded PCM hashes. Required static analysis passes zero
diagnostics in both shells. Native35 ran last and sequentially in both shells.
Exact-source push/PR CI passes all four jobs; downloaded reports each bind 857
required checks, three observations, every retained family and the new matrix.
The containing documentation checkpoint's fresh advertised equality and exact-head
CI are observed after push in the final response and refreshed next thread.

## Changes

`Get-AudioMediaInfo` now captures the selected first audio stream's codec, sample
rate, channel count and layout without altering format-specific metadata or
duration behavior. `Get-AudioEncoderSampleRates` performs one bounded query of
the selected libmp3lame after interactive input. `Get-AudioOutputPlan` intersects
the measured encoder capabilities with verified MPEG bitrate families. One shared
`New-AudioEncodeArguments` builder supplies both cover paths; explicit `-ar`/`-ac`
follow every input, with the existing selected-stream map and metadata precedence.

Validation retains exact audio-stream bitrate, fixed duration bounds, strict full
decode, staged owned partials and no-overwrite publication. It additionally checks
planned sample rate/channels. The manifest records `audio_plan` and
`observed_audio`. A missing or unusable capability response becomes an explicit
pre-encode failure. If capability-process release is unproved, the first file's
failure and diagnostics are recorded and the batch stops before another native
operation can replace the retained child identity.

`Test-EncodingCompatibility.ps1` exercises the production probe/plan/builder/
transaction/validator and actual application route. The retained S02 leads still
run independent old-argument encoder comparisons, while application assertions
now require planned exact-rate success. Historical evidence paths remain intact.
Diagnostics require exactly the five named native stages and include an explicit
returned-result release-refusal injection after actual child release. Metadata,
progress and diagnostics drivers use an explicit owned absent ConfigPath.

CI adds the S09 matrix under its own narrow current-run artifact path. Its gate
requires at least 495 exact planned/full-decoded conversions, the required
coverage groups and four valid actual application groups, with source, fixture,
ownership, release and cleanup proof. Existing historical families remain; native
resource checks run last and sequentially. README/CHANGELOG describe the planned
sample-rate and explicit channel behavior. No runtime dependency, setup pin,
artwork, default bitrate, tag or release is changed.

S08 startup/host override, policy refusal, literal arguments/CWD and one application
start remain. Shared resolver/save/setup APIs, explicit FfmpegDirectory/ConfigPath,
absolute PATH=CWD compatibility, Enter/M/Q, metadata precedence and input safeguards
remain. Conversion never downloads. Separate setup still requires consent and
preserves reviewed provenance, bounded owned staging/cleanup, guarded publication,
smoke checks and pending cancellation before Remember. Normal encode and full
decode remain unlimited. Sources and published v1.0.0 remain preserved.

## Verification

Actual client: Windows 11 Pro 26H2 x64, build 26300.9711; Windows PowerShell
5.1.26100.9711 and portable PowerShell 7.6.5. Store PowerShell 7.6.7 remains available
and is covered through the retained S08 route where the focused suite executes it.
There is no classic MSI PS7 installation. Tests use owned hidden UTF8 PS/CMD
drivers, CP65001 and explicit UTF8 native streams; each host prepends its own
PSHOME Modules. Reports/fixtures/config and raw logs remain private.

Both tested FFmpeg pairs are recorded in S09-CODEC-RESEARCH.md: existing
`C:\ffmpeg\bin` Gyan Git ec420ba161 and the existing owned development provision
of reference Gyan 9.0.2. No conversion downloads or new persistent configuration
were needed. Server CI is supplementary, not Windows 10/11 client acceptance.

| Check | Exact command or artifact contract | Environment/runtime identity | Result | Evidence |
|---|---|---|---|---|
| Independent encoder reproduction | `ffmpeg -h encoder=libmp3lame`; nine rates x eighteen bitrates x mono/stereo, plus old-argument leads | Both recorded FFmpeg builds; native research at entry f7fe652 | PASS 648 native combinations: 432 exact, 216 clamped; twenty old-argument controls reproduce reported leads | S09-CODEC-RESEARCH.md |
| Explicit downmix supplement | Production probe/plan/builder/transaction with ten independently verified standard layouts | Production 57f90c4; both FFmpeg builds, portable PS7 | PASS twenty actual transactions, exact 64 kbps/48 kHz/stereo and full decode | S09-CODEC-RESEARCH.md |
| Final required encoding matrix | `Test-EncodingCompatibility.ps1`; `S09-encoding-gyan/reference-ps51/ps7-final3.json` | Exact source 1dcf1b3; two client shells and two builds | PASS all four: 495 planned conversions and 32 actual app conversions each; exact shape, compatible default PCM equality, metadata, fixture/runtime hashes and cleanup | S09.json final report inventory |
| Retained isolated baseline | `Invoke-IsolatedBaseline.ps1`; `T17-baseline-ps51/ps7-attempt91.json` | Source 57f90c4; final runtime | PASS both shells; retained real suite and characterization in owned isolation | Private historical-contract reports summarized in S09.json |
| Transaction/duration/truncation | `Test-TransactionalOutput.ps1`; `T16-transaction-ps51/ps7-attempt91.json` | Source 57f90c4; final runtime | PASS 27 groups each, retained wrong-rate and payload/duration protections | Private reports summarized in S09.json |
| Original reported leads | `Test-SetupEncodingRegressions.ps1`; `T17-setupencoding-ps51/ps7-attempt92.json` | Source 57f90c4; final runtime | PASS twelve groups each; application bitrate/shape/manifest exactness required | Private reports summarized in S09.json |
| Metadata/artwork | `Test-Metadata.ps1`; `T16-metadata-ps51/ps7-final93.json` | Source 5e513e43dd819bf37cdcc5daf531e0a0e6dd3e88; final runtime | PASS fifteen groups each with explicit owned ConfigPath | Private reports summarized in S09.json |
| Progress and long decode | `Test-Progress.ps1`; `T16-progress-ps51/ps7-final93.json` | Source 5e513e4; final runtime | PASS eighteen groups each, including 3605-second silent CBR and 3605-second VBR | Private reports summarized in S09.json |
| Diagnostics and release-refusal boundary | `Test-Diagnostics.ps1`; `T18-diagnostics-ps51/ps7-final93.json` | Source 5e513e4; final runtime | PASS twenty groups each; release-refusal is an explicitly injected returned result after actual child release, not a genuinely unreleased child | Private reports summarized in S09.json |
| Pure runtime/CI contracts | `tests/ci/Test-CiContracts.ps1`; `T17-unit-ps51/ps7-final93.json` | Source 5e513e4 | PASS 33 groups each, including strict matrix-report gating and narrow CI artifact policy | Private reports summarized in S09.json |
| Menu/input/default sound | `Test-MetadataInteraction.ps1`; `S07-metadatainteraction-ps51/ps7-final94.json` | Actual recorded source 5e513e4; final runtime | PASS 23 groups each; actual report identities retained | Private reports summarized in S09.json |
| Preserved S08/package | `Test-Launcher.ps1` and `Test-Package.ps1`; corrected fresh final95 drivers | Exact source 1dcf1b3; package uses reference pinned tools | PASS focused 76 and package 57 groups per shell | S09.json final report inventory |
| Static correctness/security | Required twelve-file scope; pinned PSScriptAnalyzer 1.25.0, configured rules plus default Errors; `analysis-ps51/ps7-final96.json` | Exact final source 1dcf1b3, both client shells | PASS zero diagnostics in each shell | Private analyzer reports summarized in S09.json |
| Native process/release | `Test-NativeProcess.ps1`, last and sequential; fresh final97 drivers | Exact source 1dcf1b3, both client shells | PASS 35 groups per shell; source/fixtures/release/cleanup proved | S09.json final report inventory |

Six earlier local matrix attempts completed all 495 conversions and four actual
application groups, but cleanup failed, so their overall status remains FAILED.
They are retained as nonpasses, not promoted to accepted reports. The failure
was localized to PowerShell Remove-Item before any tree deletion. The parent
Windows TEMP directory refused enumeration while exact child paths and every
file remained accessible. Parent traversal is a narrow inference, not a traced
internal cause. An independent tiny two-file Directory.Delete experiment passed.
The harness now uses the same direct legacy .NET deletion API already retained
elsewhere, after the unchanged exact owned boundary, marker/token, no-reparse and
native-release checks. This supports a narrow parent-enumeration cause inference;
it does not prove an unrelated application or machine fault. All four final3 runs
independently prove complete cleanup.

Earlier mixed diagnostics runs reached correct conversion counts but failed the
stale four-stage assertion; the strengthened exact five-stage assertion and new
release-refusal case pass in final93. Initial menu runs passed their 23 groups but
failed source integrity while CI files changed; unchanged final94 reports pass.
Exploratory analyzer runs emitted eight old `$event` warnings outside the required
scope; the required twelve-file checks pass zero diagnostics on exact 1dcf1b3.
The private preserved-suite final94 driver also supplied FfmpegPath to the focused
launcher, which only accepts EvidencePath. Parameter binding rejected it before
cases and no focused report existed. Corrected fresh final95 drivers pass only
EvidencePath to the launcher and the separately pinned pair to package tests.
This preparation failure is not a product nonpass or a test pass. These nonpasses
remain distinct from final required checks; no assertion, integrity gate, release
guard or timeout was disabled.

Earlier retained metadata/progress/diagnostics drivers omitted an explicit
ConfigPath. Those runs do not establish owner-config isolation. The strengthened
final drivers explicitly use an owned absent config path; historical claims are
not rewritten. No ordinary Music or personal media was scanned. Windows 10 22H2
x64, physical UI/console actions, new phone observations and the exact future
v1.0.1 ZIP/kit remain later consolidated acceptance work, not fabricated passes.

## Git state (observe after checkpoint)

Origin is `https://github.com/PikkuJanne/AudioFileForPhone.git`; active branch is
`codex/audiofileforphone-v1.0.1`. Draft PR29 remains OPEN draft and unmerged:
[PR29](https://github.com/PikkuJanne/AudioFileForPhone/pull/29).

Tested source `1dcf1b398d610dd478922d5dba672992ca4d5d0f` was pushed
and independently compared equal with the fresh advertised feature ref. Push CI
40525113343 and PR CI 40525121428 pass all four jobs. Downloaded CI wrappers and
matrix reports each verify 857 required checks, three observations and 495 planned
conversions plus four actual application groups. Push checkout is exact 1dcf1b3;
PR integration checkout is `0303ea678cc90399cf939eff6147b98c8b4d8322`, distinct
from its advertised feature head. The final containing evidence/checkpoint commit, worktree status,
push result, fresh feature/main identities and exact-head push/PR check outcomes
must be observed after finalization. A commit cannot include its own SHA; the
final response records that comparison and the next thread refreshes it.

Main remains separately NOT_INTEGRATED: local and fresh live main are
`28f53b10529495754273d55654c7b29e78848c83`. S14 reviewed PR policy and existing
owner-approval default still apply. No main merge, protection, history, visibility,
tag or release mutation occurred. There is no frozen v1.0.1 source or accepted ZIP.

## Decisions, risks and blockers

The measured three MPEG families and the selected encoder's advertised rates
jointly determine one explicit output plan; no user source is encoded twice to
probe compatibility. Compatible 64 kbps shape and decoded sound remain unchanged.
The multichannel allowlist is bounded to layouts independently reproduced through
the production helper on both builds. Unknown layouts reject before encoding.
Metadata selection remains independent of source duration/shape availability.

Independent review found and corrected the unreleased-capability continuation
risk. The actual-app diagnostics regression proves the stop boundary using a
clearly labeled substituted refusal after real child release. Its actual release
proof remains the cleanup authority. Pure injected parser checks are separately
identified in S09-REVIEW.md and are not real conversion evidence.

No local implementation or evidence blocker remains. The containing documentation
checkpoint must still receive its own fresh advertised comparison and successful
exact-head CI after push; those observations belong in the final response, without
a self-containing SHA. If that final gate cannot be verified, resume S09 instead
of treating pending CI as a pass. Windows10/physical/phone/package acceptance and
main integration remain separate later gates.

## Human action

None for S09. Do not repeat owner diagnostics, request PATH edits or ask for
private media. Necessary Windows/phone observations remain consolidated in S15's
prepared acceptance kit and short guide.

## Next step and fully filled prompt

S10 - Ship diagnostics, early failure reports and self-test is next eligible and
NOT_STARTED, only in a separately started owner thread. Refresh the containing
checkpoint recorded in the previous final response.

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Read AGENTS.md and the active CHARTER.md, STATE.json, STATUS.md,
    NEXT_SESSION.md, RELEASE_TARGET.json, evidence/S09.json,
    evidence/S09-HANDOVER.md, evidence/S09-CODEC-RESEARCH.md and
    evidence/S09-REVIEW.md. Refresh the containing checkpoint from the previous
    final response, fresh local/live feature/main identities and exact-head CI.
    Tested source: 1dcf1b398d610dd478922d5dba672992ca4d5d0f; production runtime
    is unchanged from 57f90c4f73c385b0b0e562f487b8cf945a60de2a.
    Complete ONLY S10 - Ship diagnostics, early failure reports and self-test.
    S01-S09 are complete; do not restart earlier steps. Read tasks/S10.md,
    specs/DIAGNOSTICS_AND_TIMEOUTS.md and specs/SYNC_AND_RELEASE.md.
    Available client: Windows 11 Pro 26H2 26300.9711 x64,
    PS5.1 5.1.26100.9711, portable PS7 7.6.5 and Store PS7 7.6.7.
    Existing C:\ffmpeg\bin is Gyan Git ec420ba161; the reference Gyan 9.0.2
    development tools remain separate from managed end-user setup acceptance.
    Preserve S09 shared output planning, exact bitrate/sample-rate/channels,
    compatible 64 kbps decoded sound, explicit downmix/rejection, selected metadata
    and artwork behavior, manifest plan/observed fields and capability-release
    refusal boundary. Retain fixed duration/truncation/full-decode validation,
    transactional owned partials, no-overwrite publication, cancellation/release
    guards and unlimited normal encode/full-decode runtime.
    Preserve S08 host selection/override, policy refusal, exact host/x64/STA,
    literal arguments/CWD and no retry after application exit. Retain Enter/M/Q,
    metadata precedence, EOF/input safety, prompt-free ordinary calls and no
    batch metadata persistence. Preserve shared resolver/save/setup APIs,
    FfmpegDirectory/ConfigPath, absolute PATH=CWD and separate consent-based
    setup with reviewed pin/provenance, bounded owned staging/cleanup, guarded
    publication, smoke checks and pending cancellation before Remember.
    Conversion never downloads. Keep CP65001 and explicit UTF8 owned hidden
    PS/CMD drivers, own-host module precedence, historical evidence contracts,
    isolated synthetic fixtures and explicit owned absent ConfigPath. Preserve
    recorded nonpasses and evidence limits; do not disable safeguards.
    Do not scan ordinary Music or personal media. Preserve defaults, sources,
    icons/artwork and published v1.0.0. Keep main integration separate under
    S14 reviewed policy and existing owner approval.
    Update evidence/state/status/next-session/decisions and full handover.
    Test/review/commit/push; verify fresh advertised equality and exact-head CI.
    Give the filled next-thread prompt, then STOP. Do not begin another step.
    Fixed deliverable: public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread ends after the S09 checkpoint and full handover. No S10 implementation
or other numbered-step work begins here.

## Fixed final deliverable

Public normal **v1.0.1** remains PENDING_S17; runtime remains 1.0.0. No frozen source,
accepted ZIP or publication authorization exists. Only separately started S17
publishes S16's exact accepted source/assets as AudioFileForPhone v1.0.1,
tag v1.0.1 and AudioFileForPhone-v1.0.1.zip. S18 verifies public/download/main-sync
closure. Published v1.0.0 and its tag/assets remain preserved.
