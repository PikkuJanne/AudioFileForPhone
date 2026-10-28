# S12 handover — COMPLETED on available client/CI scope

## Outcome

S12 implements clean-environment CI and local evidence release gates. The local
campaign passes70 selected suite reports and2analysis reports:1856 required
groups and6historical observations. Two matrices perform990 direct conversions
and64 actual application matrix conversions; two complementary corpora add20
conversions. All66 compatible default64 PCM comparisons match. Clean-first-run
adds7 fresh production-process cases and3 independently validated conversions per
shell. Gate50 per shell tests contracts and actual refusals, not client acceptance.

Initial source570ed713129a9800dee2ff5032cdf754ad0e6207 failed all four Server CI
jobs at the newly wired filesystem fixture's exact ACL restoration assertion.
The application conversion and full decode had passed. Source76dab1faa0e883420bbc28b95c0ef2ae530d7f7e
limited fixture writes to the DACL and captured the next failure: Windows added
AI while the owner/group and inherited ACE text stayed identical. Source
375adcdfdbc9d70001b21d8d495efb1384b1201d constructs the owned inherited fixture
before saving its denial baseline, strictly preserving descriptor state except
the documented AI addition. Exact full-SDDL restoration remains unchanged.
Client focused reruns, analysis and all four exact-source Server jobs pass. S12-A1/A2/A3 pass in the recorded scope. Containing-checkpoint advertised equality/exact-head CI must be observed after push in the final response; an unverified/failed checkpoint requires S12 continuation. S13 has not started.

## Changes

- Test-CleanFirstRun runs empty/stale/malformed child PATH refusals, explicit
  external conversion, deliberate production setup saving, a fresh saved-selection
  conversion and app-local conversion. It preserves parent PATH, owned config,
  real manifests/exact64/metadata/full decode, source hashes and conservative
  descendant-release/cleanup guards. Existing first-run15 remains.
- CI adds gate, clean-first, S11 corpus/filesystem and actual online setup
  families. Historical T17/S08/S09/S10 contracts remain. Two narrow report regexes
  also accept runID_attempt. Jobs explicitly say supplementary Windows Server and
  record actual caption/ProductType/build/shell. Pins, read-only permission,
  exact event checkout and absence of release jobs remain. Upload paths stay
  narrow. Native checks remain last and sequential within each job.
- tools/ReleaseGates.ps1 and Test-ReleaseGates.ps1 check actual local candidate,
  report and asset identities. Frozen C/control/member checks use binary Git
  blobs, preserving exact package bytes despite checkout CRLF/LF. Mandatory client
  cells, status/types/check IDs, manifest/checksums and exact S17 public-asset
  authority refuse incomplete/stale records. A pass grants no authority.
- RELEASE_GATES.md defines the later runner contract; SYNC_AND_RELEASE references
  it. No S13 kit or S14 release artifact is built. Production runtime, audio
  policy, default64, supported inputs/layout/metadata, icons/posters and published
  v1.0.0 remain unchanged from runtimeb05b581dc6372cecd99471c53ee2cac72b8267ba.
- The owned ACL fixture is initialized before any denial and before its immutable
  baseline. DACL/captured-SACL binary bytes/order, owner/group, ResourceManagerControl
  and other control flags must stay identical; only AI0-to-1 is permitted.
  This is explicit fixture construction, not a restoration claim for old failed
  AI-off scopes. The later full original-SDDL assertion is never normalized.

## Verification

Actual client: Microsoft Windows11 Pro26H2 26300.9711 x64, PS5.1.26100.9711 and
portablePS7.6.5. StorePS7.6.7 is startup-route evidence only. Owned hidden UTF8/
CP65001 drivers use own-host Modules, short marked TEMP, isolated LOCALAPPDATA and
explicit ConfigPath. S12.json gives each exact redacted command, actual checkout,
hashes, start/end, expected/observed scope and private report digest.

| Check | Executed harness / evidence | Result and boundary |
|---|---|---|
| Retained full regression |30 retained families per shell, including Invoke-IsolatedBaseline, original integration/characterization, naming/metadata/output/source/transaction/cancellation/diagnostics/menu/setup/launcher suites|60 passing selected reports; no ordinary Music or physical default-Music smoke|
| Exact encoding |Test-EncodingCompatibility; S09-encoding-gyan-*-attempt301|2x495 direct plus2x32 actual application matrix conversions; existing Gyan Git ec420ba161|
| Clean first-run |Test-CleanFirstRun; S12-cleanfirst-*-attempt301|7 actual fresh processes per shell;3 real exact64/artist conversions with independent full decode per shell; no provisioning inherited through child PATH|
| Evidence gates |tests/ci/Test-ReleaseGates; S12-releasegates-*-attempt304|50 groups per shell; synthetic positive/mutation fixtures, actual S11 digest/schema refusal, exact source guard and current actual CLI exit1/REFUSED|
| Complementary corpus |Test-CompatibilityCorpus; S11-corpus-*-attempt304|4 groups/10 direct production conversions per shell; fixed duration/truncation policy retained|
| Filesystem |Test-CompatibilityFilesystem; S11-filesystem-*-attempt308|5 actual/injected groups per shell; strict pre-baseline fixture construction, exact original SDDL, owned ACL/locked/moved source and labeled ENOSPC result injection remain distinct|
| Actual online setup |Test-ManagedSetupReal; S06-managedreal-*-attempt304|3 actual vendor install/saved conversion groups per shell, separate from CI/development provisioning|
| Quiet final resources |ShortOperations15 PS51 thenPS7, NativeProcess35 PS51 thenPS7, attempt308|Sequential final runs; operation/drain/outer assertions unchanged; original305 timing nonpass retained|
| Static analysis |analysis-ps51/ps7-attempt304|Analyzer1.25.0:24 files, zero diagnostics; both parsers62 files; complete45/53 dependency inventories rechecked|
| CI policy |Test-CiContracts39 and dependencyguards22 per shell|Real source functions, exact pins/minimal permissions, unsafe policy/report mutations refused; fixtures are not media/owner evidence|

The70 selected reports retain actual checkout IDs and source hashes. Earlier
reports are reused only with matching relevant bytes; nothing is relabeled as
execution on the later source. Raw failed/preparation/superseded reports remain
private with separate digests. S12-NONPASSES.md records locale/date parsing,
PS5.1 default-path, private collector preparations, the unchanged short-operation
timing failure and initial Server ACL failure. No guard was disabled.

## Git state (observe after checkpoint)

Origin https://github.com/PikkuJanne/AudioFileForPhone.git; active branch
codex/audiofileforphone-v1.0.1. Source375adcdfdbc9d70001b21d8d495efb1384b1201d
is pushed and freshly advertised-equal. Source push40759426470 and PR40759435259
pass all four jobs; four downloaded wrappers bind974 required checks/3 observations and20 child digests each. PR actual checkout3e0c53855399b06e2bb950653049a8a7819e78e2 stays distinct from feature head. Initial failed
source push40755505772 and PR40755511831, and ACL diagnostic retry
push40757551304/PR40757562159, remain separate failed evidence.

Containing documentation HEAD, working tree, fresh live equality and exact-head
push/PR CI are observed after commit in the final response and refreshed next
entry. This commit cannot contain its own SHA. Pending/failed CI is never PASSED;
if that checkpoint gate is unproved, resume S12 instead of advancing.

Main is separately NOT_INTEGRATED at local/live28f53b10529495754273d55654c7b29e78848c83.
PR29 stays OPEN draft/unmerged under S14 reviewed policy and existing owner
approval. No main, tag, release, visibility, protection or history mutation.
Frozen release source/ZIP/kit/publication authority remain null.

## Decisions, risks and blockers

S12-REVIEW.md records official pin verification, independent source review and
corrections. D57-D59 record evidence/checkpoint decisions. Exact source CI passes; containing-checkpoint CI is observed after push in the final response. Windows10 required client cells stay
BLOCKED_UNAVAILABLE_CLIENT for the later consolidated kit. Server CI supplies
supplementary evidence only. Genuine cloud/redirected/UNC/mapped-share, physical
full disk, physical owner interaction, phone and future exact ZIP remain unproved.
No universal storage/phone compatibility or inferred conversion from a prompt.

Keep S08 startup/override/policy/literal arguments and shared resolver/save/setup
APIs, S09 exact audio plan/default64/full-decode/metadata/artwork, and S10 no-write
checks/DryRun, private bounded diagnostics, whitelist export, owned self-test,
local-only guards, cancellation130 and release-refusal boundaries. Separate setup
requires consent. Conversion/check never download. Normal encode/decode stay
unlimited; duration bound stays0.35seconds.

## Human action

None for S12. Do not repeat owner diagnostics, request PATH edits or private audio.
Necessary Windows/physical/phone observations stay consolidated in S15's kit.

## Next step and fully filled prompt

S13 — Build the one-click acceptance kit is eligible only after S12's source and
checkpoint gates pass, in a separate owner thread. Otherwise resume S12.

```text
Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
Tested test/CI source: 375adcdfdbc9d70001b21d8d495efb1384b1201d.
Production runtime remains b05b581dc6372cecd99471c53ee2cac72b8267ba.
Refresh the containing checkpoint from the previous final response,
fresh advertised feature/main refs and exact-head push/PR CI.
Read AGENTS.md and active CHARTER.md, STATE.json, STATUS.md,
NEXT_SESSION.md, RELEASE_TARGET.json, evidence/S12.json,
S12-HANDOVER.md, S12-REVIEW.md and S12-NONPASSES.md.
Complete ONLY S13 — Build the one-click acceptance kit.
S01-S12 are complete only if the S12 checkpoint gates are verified;
if unverified/failed, resume S12 instead. Do not restart earlier steps.
Read tasks/S13.md, specs/MINIMAL_HUMAN_ACCEPTANCE.md,
specs/RELEASE_GATES.md, specs/AUTOMATED_ACCEPTANCE.md and
specs/SYNC_AND_RELEASE.md. Do not start S14 in S13.
Available client: Windows11 Pro26H2 26300.9711 x64,
PS5.1.26100.9711 and portablePS7.6.5. Store7.6.7 is startup-only.
C:\ffmpeg\bin is Gyan Git ec420ba161; pinned9.0.2 remains separate.
Windows10 is unavailable; Server CI cannot substitute client acceptance.
Retain S12 seven-case clean child PATH/config tests, exact pins/minimal
permissions, narrow artifacts, actual OS labels, real separate online setup,
and strict source/runtime/ZIP/kit/report/client/human/authority gates.
Keep exact Git blob package hashes distinct from checkout EOL hashes.
Preserve S11 corpus/filesystem, exact original-SDDL ACL restoration,
canonical owned CWD/exact assertions, historical reports and all nonpasses.
Keep UTF8 CP65001 owned hidden drivers and isolated fixtures/config.
Do not invent cloud/UNC/full-disk/physical/phone/exact-ZIP evidence.
Preserve S10 no-write/privacy/self-test/local-only/cancellation130 and
prerequisite/capability release refusals; S09 exact audio/default64,
metadata/artwork/downmix/rejection, fixed duration and unlimited encode/decode;
S08 startup/override/policy/literal arguments and shared resolver/save/setup.
Separate setup requires consent; conversion/check never download.
Do not scan ordinary Music/personal media or repeat owner diagnostics.
Preserve defaults, sources, icons/posters and published v1.0.0.
Main integration remains separate under S14 reviewed policy and owner approval.
Update evidence/state/status/decisions/full handover; test/review/commit/push,
verify fresh advertised equality and exact-head CI, give the filled prompt,
then STOP. Do not start S14.
Fixed deliverable: publicv1.0.1. Only separately started S17 publishes
S16's exact accepted source/assets; S18 verifies closure.
```

## Stop

Stop after the S12 checkpoint and full handover. No S13 work starts in this thread.

## Fixed final deliverable

Public normalv1.0.1 remains PENDING_S17. Runtime is1.0.0; no frozen release source,
accepted ZIP/kit or publication authority exists. Only separately started S17
publishes S16's exact accepted source/assets as AudioFileForPhone v1.0.1,
tagv1.0.1 and AudioFileForPhone-v1.0.1.zip. S18 verifies public download/main-sync
closure. Published v1.0.0 and its tag/assets remain preserved.
