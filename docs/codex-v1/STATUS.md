# Current project status

State: **T21 owner reports successful phone checks; version/chapter details pending.**
Last completed task: T20, owner-integrated. Exactly next task: continue T21.
Required improvements 1-15; optional O01 deferred. Project/release incomplete.

## T21 phone report checkpoint

- Janne Vuorela reports **"All worked. Samsung A56, Android One UI 8.5, AIMP,
  usb cable"** in reply to the three-file procedure. This confirms the requested
  start/40:00/79:00 playback and seeking, expected approximate 1:19:35 duration,
  close/reopen resume, short titles/Artist/Album, blue cover and First/Second order.
  These are aggregate owner-reported outcomes, not instrumented measurements.
- Record the phone and OS exactly as supplied. AIMP's installed version remains
  unreported. Chapter availability/navigation is ambiguous because the last
  instruction said "if available". One brief record clarification is pending;
  no repeat phone test, screenshots, new app or new media is needed. Base Android
  release, USB protocol, sorting mode and phone-side hashes are not inferred.
- Exact intended assets remain the 79m35 unchanged T20 MP3 and two 20-second
  current-application outputs under TEMP `T21P-06b84fc67184/Phone`. Preparation,
  alias/source/report/runner bindings and original generation provenance remain
  frozen. The new observation and Windows-side asset check are separate evidence;
  local hashing or decoding is not a phone observation.
- T20 PR #20 is integrated at main `3e5b6fbec1f0c172b9d996b7473ae9f7d77e035d`.
  T21 preparation checkpoint `e2b9a222dd08651e449f708e6dac9cc7709be438` independently
  matches its live feature ref; draft PR #21 remains open and unmerged. Exact-head
  push38157910582 and PR38157946939 each pass both Windows jobs. T01-T20 are
  integrated; T21 main integration remains owner-controlled.
- A51/A52/T21 remain blocked only on the missing AIMP version and actual chapter
  detail. See `evidence/T21-phone-observations.json`, `evidence/T21.md` and the new
  independent phone-report review. No runtime/helper/BAT/test/CI/build/default
  change or release authorization. Exactly next continue T21, not T22.

## T20 completed recovery — historical feature checkpoint, now integrated

- Janne Vuorela reported the guide's cover mismatch after trying both PNGs and
  again requested simpler testing. Actual PS5.1 Desktop STA application had
  already completed all three synthetic inputs with exit0. The guide incorrectly
  required a prepared 64x64 PNG, rejecting the valid tracked 2816x1536 poster.
  Its failed aggregate stays unchanged; actual picker capture and outputs are
  independently verified rather than relabeled as a passing guide.
- Janne explicitly confirmed dragging the test folder onto the BAT and seeing
  **Completed with failures**. BAT selected shell/version, raw exit and output
  root remain unknown. Unknown Music output is retained without inspection/cleanup.
- A49's method is explicitly revised in task/strategy/acceptance tracking to these
  named interactions plus automated both-shell Windows checks. Existing support
  retains 182 passes; fresh unchanged cancellation tests add eighteen passes,
  with controlled console input, owned-process release, unrelated-process survival
  and interrupted-output safety. Current PS7 picker, physical Cancel, hardware
  Ctrl+C and physical fallback are not claimed. T21 phone/listening remains later.
- `Test-T20PickerRecovery.ps1` independently verifies the same actual PS5.1
  outputs from both verifier shells: metadata, date/layout, 64kbps, full audio/art
  decode and actual selected cover dimensions pass. Each records sixteen released
  bounded natives and 41 unchanged file bindings. PS7 verifier execution is not a
  PS7 application/picker run. No application or UI was rerun.
- The corrected guide accepts the actual valid JPG/PNG, checks its dimensions
  and preservation, and retains captures before validation. Both-shell runs of
  its actual verification functions pass against retained outputs and reject a
  false Cancel action, with thirteen released natives each. Exact source/adapter/
  invocation proof is in `T20-guided-correction-check.json`.
- See `evidence/T20.md`, recovery/cancellation binders, named observation record
  and `T20-recovery-review.json`. Prior reviews remain frozen. Runtime/helper/BAT,
  tests/CI/build/defaults remain unchanged. A50 retains its selected real long-file
  and controlled-Music passes. No further owner Windows tests are needed.
- Last verified feature checkpoint before recovery is
  `1e9e5de182f9cbe710f84ff0e63526698ac086d1`; push/PR CI 38154161336/38154164444
  pass both Windows jobs each. Final recovery push/live-ref comparison and checks
  belong in PR #20/response. Main is da2a627, unmerged; no release authority.

## T20 previous checkpoint — historical simplified continuation

- Janne Vuorela supplied his tester identity and exactly one local podcast, asking
  for a much simpler or automated test. Only that selected file was inspected and
  copied; its private path/name/tags/media/raw logs stay outside Git. Private ID
  `T20-long-01`: mono MP3, 44.1 kHz, 4,775.055646 seconds (79m35s), 38,249,841 bytes.
  A50's quantitative method was explicitly revised at his request; expected
  duration/resource/default-path/policy outcomes remain intact. A49 actual human
  interactions and T21 phone/listening evidence are not substituted.
- `tools/Test-T20LongAudio.ps1` actually passes on ordinary-user PS5.1/PS7 at
  application candidate `f992a54c8e7a8ad9ce2b95bd26bf66be86f5bf4e` (runtime blobs
  identical to integrated main da2a627). Both outputs are 38,201,262 bytes and
  SHA256 `2ca720b5a04515dfbf5537632a3962f6dcd1dd068fd4679bd0135adb5e09286e`.
  Duration difference is zero; 182,798 audio frames all encode at 64 kbps.
  Independent full decode and 20-second near-end decode pass. Host elapsed times
  are 34.633/37.353 seconds; observed lifetime host working-set peaks are about
  144/215 MiB and encoder peaks about 20.5/20.3 MiB. These are measured processes,
  not total-system memory or universal performance limits.
- Original/copy/application/runner/marker hashes remain unchanged. Both runs
  record eight completed/released bounded verification natives, natural observed
  process exits and no controller kill. Exact runner snapshots/private invocation
  hashes and sanitized reports are bound in `evidence/T20-long-bindings.json`.
  Three exclusive TEMP trees stay retained outside Git. Preliminary PS5.1 attempt
  failed a harness flat-output assumption despite successful app conversion; its
  original report remains failed, without invented final verification or an old
  runner snapshot. Fresh final runs validate the intended recursive layout.
- A50 now **passes** through the real selected long-file measurements and the
  controlled both-shell default-Music smoke below. A49/T20 remain **blocked** until
  Janne performs and confirms the remaining physical actions. `T20_MANUAL_STEPS.md`
  now gives one `Start-T20Guided.ps1` command: one Explorer folder-on-unchanged-BAT
  drop, actual STA select/Cancel and physical READY Ctrl+C in each shell. Output
  verification and local evidence collection are automatic. No owner action has
  been run by Codex; no playback/phone/forced-close/fallback observation is claimed.
  The BAT selected shell, raw exit and unknown Music output stay explicit capture
  limits; unknown Music output is retained and never scanned or cleaned.
- Final guided working SHA256 is
  `ca886f2b08f615de0a0b81fae6bcb1b894d201838317fc04b727fa1929bbf57d`.
  Both actual shell/parser and `-ValidateOnly` runs pass; generated picker-driver
  fingerprints match across shells. `evidence/T20-guided-validation.json` binds
  exact invocations/captures and prepared-tree/source/tool before/after hashes.
  Validation opens no UI, runs no application and creates no tool copies.
- Draft PR #20 holds this coherent partial task. Feature synchronization and CI
  after this revision belong in the PR/response; T20 main integration remains
  owner-gated. Exactly next: continue T20, not T21. No freeze/release authority.

## T20 preserved preparation checkpoint

- Owner PikkuJanne merged T19 PR #19 at 15:19:08 UTC on 11 October 2026 into
  main `da2a6273ff9aceb86af75ad4aa2d2942ec745d66`; final T19 feature was
  `4aa3dd3bbeb02982ef788521e2751fdc5bcb05df`. Normal fetch, independently
  advertised refs and live GitHub matched. Clean local main was fast-forwarded;
  active branch is `codex/v1-t20-windows-acceptance`. T01-T19 are integrated.
  See `evidence/T20-start.json`. Main push CI run 38150774320 passes.
- Near-final tested source is that integrated main commit. Runtime/helper/BAT
  and all existing tests remain unchanged. Automated tester: Codex, ordinary
  non-elevated account, Windows 11 Pro 26300.9457/x64, PS5.1.26100.9444/Desktop
  and bundled PS7.6.5/Core. Existing owner-provided C:\ffmpeg\bin pair reports
  Gyan build 2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev; exact tool
  hashes/versions are in the original reports. No download or global setting
  change occurred. Read-only execution-policy observations are retained in
  `evidence/T20-environment.json`; both managed scopes are Undefined. Each
  actual test command requests process-scoped RemoteSigned.
- Eight selected targeted runs pass **182 supplemental checks**: per shell,
  metadata 15, application outcomes 13, launcher contracts 52, resolver/default
  Music 11. Original create-new `T16-*-final20.json` reports keep their original
  task/case IDs and actual tested commit. `evidence/T20-supplemental.json` binds
  their byte hashes, exact invocations, timestamps and 26 source relationships
  to T20. All recorded source/fixture preservation, child release and owned
  cleanup gates pass. Configured-Music runs inspect/remove only their returned
  exact owned run and leave unrelated Music entries unenumerated.
- At the first checkpoint A49/A50 remained **blocked pending named manual evidence**. No physical BAT
  drag/drop, STA picker, fresh physical Ctrl+C, representative long source,
  manual default-path or playback observation is claimed. Prior T11 physical
  evidence and T19 automated long/default checks remain historical, without
  substitution for this task. Native app UI control is unavailable in this
  session. The subsequent named input and requested automated method revision
  above supersede that checkpoint's missing-identity/long-input state.
- `T20_MANUAL_STEPS.md` gives the continuation procedure. Preparation/commands
  are not successful observations. T21 remains dependent on T20; no source
  freeze, exact release-ZIP acceptance, tag or publication is authorized.
- `tools/Prepare-T20Manual.ps1` parses in both shells; actual PS5.1/PS7
  preparations each produce eight short controlled fixtures with thirteen
  completed/released bounded native calls, unchanged source/copies and empty
  output parents. Both roots are retained for physical testing. The first PS7
  attempt failed before copies/fixtures because two discovered Git executable
  paths were combined; selecting the first resolves it. Original failure and
  marker/report-only retained scope remain unchanged. Exact original reports,
  copies and commands are bound by `evidence/T20-preparation-bindings.json`.

## Checkpoint and environment

The following T19 sections preserve the historical checkpoint/evidence scopes.
Its previously pending integration is superseded by the verified T20 start above.

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t19-package.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner PikkuJanne merged T18 PR #18 at 13:35:59 UTC on 11 October 2026 into
  main 948d27c264a825e49e0ec3b6cc6b5c54542a70b0; final T18 feature
  0172cc3583dc2379ba04340a8c0c37217e53a9a3. Normal fetch, independently
  advertised refs and live GitHub matched; clean local main was fast-forwarded
  before branching. T01-T18 are integrated. See evidence/T19-start.json.
- Selected corrected T19 source C2: 70d1e2f3b47b84b595915c73a6ecb1b09d981d8e,
  committed/pushed with independently matched live feature ref. Initial C0
  d69732aa91bde6ccf966cb584544251b463004e4 and intermediate C1
  1cb92a18ed162861b286a47cabb6ae365ee8b4e0 retain their actual historical reports.
  Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/19.
  Evidence/handoff follows in a docs-only checkpoint. Final feature push and
  independent HEAD/live-ref comparison belong in the PR/response without a
  self-referential containing SHA. **T19 main integration remains owner-gated.**
  No tag/release authorization or repository settings change was added.
- Active Windows 11 Pro 26300.9457; PS5.1.26100.9444/Desktop and bundled
  PS7.6.5/Core. External Gyan FFmpeg/ffprobe 9.0.2 essentials and official
  PSScriptAnalyzer 1.25.0 are verified through retained CI-only dependency records.
  No global installation, PATH/module-path setting or machine policy change.
- C2 source push 38147793935 and PR run 38147797740 pass both supported Windows
  jobs in each run. Actual tested PR integration is
  20f9a65b00fc884a96f46f918eec65584c6fe391, with parents main 948d27c and C2;
  its complete tree 4cd70be37d41ee9debda25cfc53f6894dad6417d equals C2. Independent
  advertised refs match. Selected hosted evidence passes **306 required groups
  plus six separate baseline observations**, binding sixteen original PR raw
  reports, 45 sources and 332 source/report relationships. Actual Server 2025
  image win25-vs2026 20260925.250.1, PS5.1.26100.33438/Desktop and PS7.6.6/Core,
  external FFmpeg/ffprobe 9.0.2 and analyzer 1.25.0 are recorded in
  `evidence/T19-ci-runs-final3.json` and `evidence/T19-hosted-payload-final3.json`.
  Original report filenames/bytes/BOM remain intact.
  Both hosted package regressions record exactly README.md in the LF member list:
  ten original copies are proved before the owned README removes 230 CR bytes
  from CRLF, changing 12,523 to 12,293 bytes. Production source stays unchanged;
  actual BOM absence and zero lone CR remain preserved. Exact fixture/ZIP hashes,
  unchanged true/crlf settings, restoration to false/lf, owned process release
  and fixture cleanup pass. Hosted-download retention remains a separate scope
  recorded in the payload provenance.
- Historical initial-source push 38145156830 and PR run 38145173494 pass all four Windows
  jobs. The actual PR integration is 95073feb268c1d108b39621dbd7c6e0f505219e5,
  whose complete tree 8327caf1ab12fa8005de66c2d398ba73076c9865 equals initial reviewed
  d69732a. That historical hosted evidence passes **304 required groups plus six separate
  observations** and binds sixteen original PR reports and 45 sources through
  332 relationships. Original filenames/bytes/BOM are retained; source comparison
  permits only proved strict UTF-8 LF/CRLF conversion preserving BOM. Actual
  Windows Server 2025 image win25-vs2026 20260925.250.1, PS5.1.26100.33438/Desktop,
  PS7.6.6/Core, external FFmpeg/ffprobe 9.0.2 and analyzer 1.25.0 are recorded.
  See `evidence/T19-ci-runs.json` and `evidence/T19-hosted-payload.json`. Hosted
  checks supplement active Windows 11 acceptance and do not establish manual
  Windows, phone, frozen ZIP, main integration or release acceptance.

## T19 behavior and selected evidence

The eight-file distributable allowlist includes the PS1, functions-only helper,
BAT, README, SUPPORT, CHANGELOG, SECURITY and MIT LICENSE. Application files remain
adjacent at ZIP root. Tests/CI/build rules belong to the source commit but are
excluded from the distributable, together with icons, unused poster, FFmpeg and
ffprobe binaries, media, logs, caches, .git and Codex handoff/evidence.

The builder requires a supplied full lowercase commit matching a clean detached
checkout, including refusal of dirty tracked, untracked and ignored files. It
reads the allowlist and packages exact Git blobs from that commit, checks regular
member modes and byte identity, and refuses archive attribute substitution or
omission, unsafe paths/reparse points, source-contained outputs and overwrite.
The corrected archive command applies process-local Git core.autocrlf=false and
core.eol=lf overrides so ambient checkout settings cannot change packaged blobs;
it does not write persistent Git configuration.
It stages outside the checkout and publishes complete local assets together.
Get-AudioAppVersion from the exact source helper supplies ZIP/app/tag version;
target tag mismatch and active helper statements are refused.

ZIP member order and timestamps are deterministic. Actual comparison establishes
repeat byte equality only for the recorded builds. The external manifest binds
ZIP digest, per-member hashes/sizes, source commit, builder/allowlist/input hashes,
shell/Git versions, actual signing state, external tool identity and supplied
passing test references. The manifest is outside the ZIP; SHA256SUMS hashes the
ZIP and manifest and never itself. Caller-supplied references are attestations;
the builder validates their schema/commit/digest/status without independently
establishing test acceptance or authorization. Actual scripts remain unsigned;
checksums identify bytes and do not authenticate the publisher.

FFmpeg/ffprobe remain external. SECURITY, README and SUPPORT describe legitimate
manual setup and vendor license/provenance boundaries. The builder checks resolved
executable hashes, actual version queries and libmp3lame capability with bounded
native execution and positive process release. Runtime/default processing remains
unchanged: local execution, 64 kbps CBR MP3, supported MP3/M4A/OGG, recursive relative
layout, date-first names and existing metadata limits. No telemetry, account,
service, updater/downloader or production Python dependency was added. The BAT's
existing process-scoped Bypass remains disclosed; enforced machine policy is not
bypassed. CHANGELOG remains unreleased.

Selected local evidence for corrected 70d1e2f passes **1,196 required groups plus
six separate baseline observations**: 890 milestone groups and 306 routine groups.
The inspected payload contains 34 aggregate reports and 48 raw records, including
thirty T16-family final19 parents actually tested
at d69732a, two configured-Music final19 parents at 1cb92a1 and two T17 routine
CI final21 parents at 70d1e2f, twelve routine children and two retained dependency
records. The binder proves the earlier milestone and Music source files unchanged
at C2; original tested_commit values stay intact. It covers 45 source files through
644 source/report relationships: 628 actual before/after relationships and sixteen
single fingerprints without after fields, plus four exact resolver-function
relationships. Only proved strict UTF-8 LF/CRLF conversion preserving BOM is
accepted; absent after fields are not invented. See `evidence/T19-tested-payload.json`.
Both final21 routine runs pass 153 required groups/three observations per shell,
including 51 packaging policy cases; child groups are not counted again. All 34
selected PowerShell sources parse; the configured nine-file analyzer gate has zero
diagnostics. Selected source/synthetic preservation, bounded native/process release
and current owned-cleanup gates pass where recorded. The original real-FFmpeg
integration suite remains retained and isolated; full M4 checks are selected here.

The packaging harness verifies all ten exact copied application/build files before
preparing its private synthetic committed repository. Only the owned README copy
is normalized by removing CR immediately before LF; the original copied hashes,
normalized hashes/sizes/policy and unchanged production README are recorded. BOM,
existing LF and lone CR bytes are preserved. The CRLF regression requires README.md
in its bare-LF member list. Inert exclusion markers and real external tools remain.
It exercises eight required omissions, unsafe/expanded allowlists, source/version/
helper provenance, dirty/attached/mismatched sources, symlink/reparse/output guards,
archive attributes, tool/test provenance, signing, inventory, non-self-referential
checksums and repeated builds. Successful final harness cleanup applies only to
its own recorded marker-owned tree. Preliminary success at the earlier imported
HEAD is exploratory and is not substituted for selected code-commit reports.
The first archive-fix precommit focused runs pass 51 cases in both shells and preserve
their actual d69732a tested_commit with corrected working-byte fingerprints. The
new case records bare-LF fixture members, builds under actual true/crlf settings,
verifies exact blob bytes and unchanged configuration, then restores false/lf;
the second build yields identical ZIP, manifest and SHA256SUMS within each shell.
Source/fixture preservation and owned cleanup pass. See
`evidence/T19-package-fix-commands.json`; these precommit runs are not counted
again as committed-source routine acceptance.

The final2 focused runs of the owned-README repair also pass 51 cases in both shells,
with README.md present in the LF list and source/fixture/cleanup true. They actually
test C1 with corrected working-byte fingerprints; those original commit identities
remain intact and the runs are not counted again as committed-C2 routine acceptance.

Selected final21 dependency records copy byte-identical actual final4 bytes, retaining setup
invocation/tested_commit 15d8dc1 and the previously verified dependency roots; no
reprovision is claimed. Dependency retention is separate from media/guard cleanup.
Workflow/lock/initializer/BAT and retained legacy integration bytes remain
unchanged. Routine CI adds packaging while retaining full official action pins,
contents: read, no secrets/privileged triggers/persisted checkout credentials and
current-run JSON-only upload policy. Independent C2 source/security review passes
in `evidence/T19-source-review-final3.json`, with no unresolved finding. Its frozen
eighteen-file inventory matches C2 exactly or through proved strict UTF-8 LF/CRLF
conversion preserving BOM. The post-code TEST_STRATEGY documentation clarification
is separately declared outside frozen C2; runtime, builder and harness remain C2.
The prior hosted coverage finding is resolved by mandatory LF README proof in
both hosted shells.
`evidence/T19-source-review.json` remains bound to historical d69732a; final
report/source payload binding is separate. The C1 source review and hosted records
remain `evidence/T19-source-review-final2.json`, `evidence/T19-ci-runs-final2.json`
and `evidence/T19-hosted-payload-final2.json`.

Source/exploratory package builds at this feature commit are not an integrated
frozen candidate, exact release ZIP acceptance, phone/manual evidence, tag or
publication. Actual C2 builds pass in both shells: each ZIP has exactly eight
members matching C2 Git blob bytes, object IDs, hashes and sizes. Both script
signatures are NotSigned; external tool, input and supplied report hashes are
verified. All 659 tracked source files remain byte-identical and detached source
is clean before/after. ZIP sizes are 53,272 bytes in PS5.1 and 53,289 in PS7;
decompressed member contents match while compressed member sizes differ.
Cross-shell ZIP, manifest and SHA256SUMS bytes all differ; no cross-runtime
repeatability is promised. Original manifest evidence copies match external bytes.
Same-shell repeat equality is established separately by the package regression.
See `evidence/T19-exploratory-builds.json`, the original
`evidence/T19-exploratory-manifest-ps51.json` / `-ps7.json` and expanded argv in
`evidence/T19-exploratory-command-bindings.json`, which binds five full actual
commands and their external argv/result/raw-stream records. Exploratory source/input/output
roots and full raw driver capture remain retained outside Git. T23 must freeze
integrated C and test that exact ZIP; T24-T27 require recorded exact release
approval and the full release runbook.

## Preliminary failures and retained scopes

C1 hosted package reports passed 51 groups but had an empty lf_fixture_members
list in both shells, so the line-ending regression did not exercise an LF member
there. Local C1 fixtures did contain LF members. This coverage finding remains in
the original C1 review/hosted records. C2 changes only the owned fixture README
setup and its required-LF assertion; production README and the builder are unchanged
from C1. Current local and hosted C2 acceptance pass with the required LF member.

Initial clean detached d69732a exploratory builds failed in both shells before
assets were created. Ambient system Git core.autocrlf=true converted eight LF
members to CRLF; independent binary comparisons showed that process-local
false/lf archive overrides match all ten source blobs. The original failed-build
record remains `evidence/T19-exploratory-builds-attempt1.json`. Its first inspector
driver exited before retained child stdout/stderr, so its precise cause is unknown;
the initial full working-byte inventory was not retained. Read-only HEAD/clean
observations, later source observations and successful direct signing inspection
remain bounded to their actual capture. No failed-build repeatability or complete
initial inventory is inferred.

The separate C2 external driver attempt2 failed in its PS5.1 signing/version
inspector before invoking the builder: retained raw stderr records
Microsoft.PowerShell.Security autoload failure under inherited module paths.
Full raw capture remains outside Git, with hashes/status in
`evidence/T19-exploratory-builds-attempt2.json`. The successful driver removes
inherited PSModulePath only from owned child environments so each shell initializes
its defaults; parent/global environment and source files are untouched. A similar
environment cause for the uncaptured C0 inspector failure remains an inference,
not established evidence. No retained exploratory-root cleanup is claimed.

Package PS7 attempt1 remains failed: Invoke-Case's case-insensitive $Name parameter
shadowed loop $name, so required-omission and dirty-name scenarios did not exercise
their intended exact names. Attempt2 passes 49 scenario groups but remains failed
because cleanup was false. Both original reports and their exact hash-matched
harness snapshots are preserved. Both retain Access denied cleanup outcomes; the
original records do not establish which precise cleanup statement failed.

Attempt1's exact synthetic root was independently audited without mutation;
original source/build and asset byte/hash inventories matched and ancestors/tree
had no reparse points. Its original ownership token digest was not recorded, so
no original-token equality or recovery is claimed. Attempt2 retained a marker
digest but redacted its root name without separately persisting it; its remaining
scope cannot be safely identified. Neither old root was recovered or relabeled
cleaned. The final harness uses process TEMP, persists root name/logical parent
and marker digest, records cleanup stage/stack and verifies owned cleanup.

Automatic approval review rejected the independent exact audited attempt1 cleanup
and a separate synthetic cleanup probe before CreateProcess, reporting only
"blocked by policy" with no detailed reason. The probe created no root/report;
no equivalent retry occurred. Preserve these separate scopes and original false
cleanup outcomes. See evidence/T19-preliminary-cleanup-limit.json.

A third separate action, cleanup of the known temporary hosted-report download
root for initial PR run 38145173494, was rejected by automatic approval review
before execution with only "blocked by policy" and no detailed reason. No mutation
or equivalent retry occurred. That retained root contains public hosted JSON,
source excerpts, an ownership marker and a temporary verifier; it contains no
copied product source files, vendor binaries or personal media. The sixteen copied
original reports remain byte-identical and previously verified. This adds no
cleanup success and changes neither old package scope. See
`evidence/T19-hosted-capture-limit.json`.

## Verified local command routing

Use the selected exact records, not historical labels that would overwrite reports:
`evidence/T19-milestone-commands.json`, `evidence/T19-default-music-commands.json`
and `evidence/T19-routine-commands.json`.
They retain actual executable paths, arguments, dependency record and report
labels. Repeat only with fresh supported EvidencePath labels and RunLabel.
PS7 records may expose pwsh.dll behind the launched adjacent pwsh.exe.

Ordinary baseline/media checks use owned isolation or explicit OutputParent.
Configured-Music smoke is the separate bounded Test-OutputParent -DefaultSmoke
route: it uses synthetic input, inspects only its successfully returned exclusive
run and does not enumerate unrelated Music entries or change known-folder settings.
Its selected C1 reports pass eleven required checks per shell, with both TEMP and
the exact owned Music-run cleanup true; the binder proves their tested source
bytes unchanged at C2. Their actual C1 tested_commit values remain intact. These
checks are included in the 890 milestone groups. Never run the original
baseline blindly against the owner's ordinary Music folder. Automated controlled
default smoke does not replace T20's named manual acceptance.

## Historical T18 behavior and evidence

One functions-only Get-AudioAppVersion helper is the authoritative runtime 1.0.0
literal. Banner and run manifest call it; the existing log takes the manifest's
version. Proper comment-based help documents all nine public parameters and five
exact executable examples, with README matching their commands. CHANGELOG marks
1.0.0 unreleased; SUPPORT maps claims to tests/evidence and records actual device,
host, signing and dependency boundaries. No website placeholder is introduced.

The BAT's existing process-scoped Bypass is unchanged and disclosed. Support
prefers read-only policy inspection/direct RemoteSigned invocation and limits any
personal-machine unblocking guidance to reviewed exact files. Enforced policy
is never bypassed. The actual scripts remain unsigned. Cover, chapter, input,
normalization, outcome, cancellation, partial and diagnostics limits are explicit.
Package templates keep unknown provenance null; T19 must read Get-AudioAppVersion
when building package metadata. No package/ZIP build result is claimed by T18.

Selected local final4 reports at code 3766e16 plus retained diagnostics final1
pass **242 required groups plus six separate baseline observations**: routine
CI 102 per shell plus diagnostics nineteen per shell. Diagnostics actually tested
15d8dc1; its four source files are unchanged at 3766e16. The initial 256-group/six-
observation matrix at 15d8dc1 remains historical. Initial focused help and CI child
groups are not counted again. Five sequential families retain unit 31, dependency guards 22,
baseline 7, help 7 and native 35; the original legacy real-media suite also passes.
All 32 selected PowerShell sources parse, and the explicit seven-file analyzer
gate has zero default Errors/ten-rule diagnostics. Legacy style warnings remain
outside this gate. See evidence/T18.md, T18-tested-payload-final2.json and
T18-source-review-final2.json. The selected final payload binds sixteen actual
reports and forty sources through 284 before/after relationships to reviewed Git
blobs, allowing only proved strict UTF-8 LF/CRLF conversion
while preserving BOM bytes. The original payload/review remain historical.

Help executes the exact Get-Help Code of all five examples in owned children;
12 actual outputs per shell independently probe/full-decode. All ten public
PowerShell fences parse; policy/unblock/setup/interactive fences are syntax-only.
Preview and helper examples preserve exact owned directory/file/hash/time/attribute
inventories without ordinary Music access. Selected source/synthetic hashes,
positive descendant release, child disposal and exact owned fixture cleanup pass.
Dependencies are retained outside Git for checks, separate from media/guard cleanup.

Raw CI final4 records retain the T17 artifact namespace and actually test 3766e16.
Dependency final4 records are byte-identical provenance copies of final3, retaining
the actual setup invocation/tested_commit 15d8dc1 and verified roots; no new
provisioning is claimed. Historical final2/final3 records are unchanged. The
workflow, lock, dependency initializer, BAT and original retained
integration bytes remain unchanged; adding help to routine checks changes no CI
rights or downloader policy. Review has no implementation/security blocker.

The preliminary PS5.1 help attempt1 at 5eb1374 failed because imported helper
functions made Get-Help classify the multiline fifth example's second line as
remarks. Source/fixture/release/cleanup stayed true. The production help and README
now use the same single-line fifth command; both attempt2 reports pass. This
failure remains preserved. Hosted push/PR runs 38141841561/38141855067 at 15d8dc1
and 38141923121/38141927318 at docs checkpoint 634cc59 all failed in the PS7
help inventory while PS5.1 passed. The root-case diagnosis is an inference from
the failed line/old comparison, supported by the repaired alternate-root-spelling
regression; failed reports do not record Get-Item's exact returned root casing.
Original first-push PS7 raw reports remain in
T17-*-ps7-run38141841561_1.json; T18-ci-runs.json records actual run metadata.
The narrow test-only repair canonicalizes the owned root and compares its root/
prefix with OrdinalIgnoreCase while retaining a strict descendant boundary and
exact remaining relative paths, types, bytes, hashes, times and attributes.
An alternate-root-spelling regression runs inside the existing first group.
Production remains unchanged from 15d8dc1. Repaired hosted push 38142296899 and
PR integration 38142299941 pass both Windows jobs. Fresh API/refs verify actual
merge c721ed64d188fbdc9c761e19bb7f16d64ff70873 and complete tree
95a284e2dc656fe41300aedf2ead11c2f062dde9 equal to reviewed 3766e16. Fourteen exact
selected PR raw reports retain their run38142299941_1 names and actual integration
tested_commit; parent CI fields confirm GitHub SHA/run/event. No absent child
fields are invented. Hosted payload binds those actual bytes/source relationships.
Hosted acceptance is **204 required groups/six observations**, supplementary to
the separate local 242/six. Actual Server 2025 image 20260925.250.1, PS5.1.26100.33438/
PS7.6.6, FFmpeg 9.0.2 and analyzer 1.25.0 remain recorded. See T18-hosted-payload.json
and T18-ci-runs.json for two green and four failed historical runs.
An earlier direct dependency invocation failed the
host check before its body; it created no root/report, and no success is inferred.


## Preserved limits and next action

Retain T17's failed 260-unit hosted characterization and private-layout repair to
227, complete pinned inventories and the separate research-root cleanup rejected
before execution by automatic approval review. Its retained-root/false-cleanup
outcome is unchanged by later fixture cleanup; no equivalent deletion retry is
authorized or claimed. T18's failed help attempt and four failed historical hosted
runs, repaired root-case regression and two green hosted runs remain preserved
above and in their exact original reports.

T01 importer and T11 owner-confirmed physical Ctrl+C remain historical. T16's
974 regression groups/six observations, source relationships and recovery scope
remain retained. No new named phone/Explorer, STA dialog, drag/drop, representative
long-file, NAS/UNC/network-redirected Music or physical/manual evidence is inferred
from T19 automated/default smoke or builds. Preserve metadata/cover/chapter scope,
T07 possible residue, T09 post-guard interval, T11 forced-host and T14 persistence
limits. Loudness remains deferred.

Owner review/integration of draft PR #19 is required. Independently reconcile main
before exactly T20: real Windows acceptance on both shells. Tag, frozen candidate,
public release and project closure remain later gated work.
