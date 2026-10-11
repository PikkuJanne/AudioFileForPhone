# Next session - T20 after owner integration

T19 implementation is complete at reviewed source
70d1e2f3b47b84b595915c73a6ecb1b09d981d8e (C2). Selected local acceptance passes
1,196 required groups plus six separate baseline observations; hosted acceptance
passes 306 groups plus six observations. Both C2 exploratory builds and independent
source/security review pass. Exactly next task is T20, real Windows acceptance on both shells,
after owner integration of draft PR #19. Project/release remain incomplete;
optional loudness remains deferred.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS. Inspect actual dirty/untracked state, active branch, all fetch/push URLs,
overrides, normal fetch, independently advertised refs and live GitHub. Preserve
all work; no reset/clean/force. Owner PikkuJanne merged T18 PR #18 at 13:35:59 UTC
on 11 October 2026 into main 948d27c264a825e49e0ec3b6cc6b5c54542a70b0.
Final T18 feature was 0172cc3583dc2379ba04340a8c0c37217e53a9a3. T01-T18 are
integrated. See `evidence/T19-start.json`.

T19 branch is codex/v1-t19-package. Reviewed code is
70d1e2f3b47b84b595915c73a6ecb1b09d981d8e, committed/pushed with an independently
matched live feature ref; evidence/handoff follows in a docs-only
checkpoint. Independently inspect fresh HEAD/live refs, draft PR
https://github.com/PikkuJanne/AudioFileForPhone/pull/19 and latest actual checks.
Feature synchronization and main integration are separate. **T19 main integration
remains owner-gated.** No tag/release authorization or repository settings change
was granted.

C2 source push 38147793935 and PR run 38147797740 pass both supported Windows
jobs in each run. Actual tested PR integration
20f9a65b00fc884a96f46f918eec65584c6fe391 has main 948d27c and C2 as parents;
its complete tree 4cd70be37d41ee9debda25cfc53f6894dad6417d equals C2 and independent
advertised refs match. Selected hosted acceptance passes **306 required groups
plus six separate baseline observations**, with sixteen original PR raw reports,
45 sources and 332 relationships. Read `evidence/T19-ci-runs-final3.json` and
`evidence/T19-hosted-payload-final3.json`. Actual Server 2025 image win25-vs2026
20260925.250.1, PS5.1.26100.33438/Desktop, PS7.6.6/Core, external FFmpeg/ffprobe
9.0.2 and analyzer 1.25.0 remain recorded; original report names/bytes/BOM are retained.
Both hosted LF lists contain exactly README.md. All ten copied files match source
before the owned README removes 230 CR bytes only immediately before LF, changing
12,523 to 12,293 bytes. Production source is unchanged; BOM absence and zero lone CR
are preserved. Fixture/ZIP hashes, true/crlf configuration preservation/restoration
to false/lf, process release and owned fixture cleanup pass. Hosted-download
retention is a separate scope in the payload provenance.

Historical initial-source push 38145156830 and PR run 38145173494 pass all four Windows jobs.
The actual PR integration is 95073feb268c1d108b39621dbd7c6e0f505219e5; its complete
tree 8327caf1ab12fa8005de66c2d398ba73076c9865 equals initial reviewed
d69732aa91bde6ccf966cb584544251b463004e4. Read `evidence/T19-ci-runs.json` and
`evidence/T19-hosted-payload.json` for actual events/environments and report bindings.
That historical hosted evidence passes **304 required groups/six separate observations**,
with sixteen original PR reports, 45 sources and 332 source/report relationships.
Actual Windows Server 2025 image win25-vs2026 20260925.250.1,
PS5.1.26100.33438/Desktop, PS7.6.6/Core, external FFmpeg/ffprobe 9.0.2 and analyzer
1.25.0 are recorded. Original report filenames/bytes/BOM are preserved; source
comparison allows only proved strict UTF-8 LF/CRLF conversion preserving BOM.
Hosted checks supplement the active Windows 11 machine; never infer local
interactive, phone, frozen ZIP, main integration or release acceptance from them.

## Preserve the current package and dependency contract

Read `evidence/T19.md`, `evidence/T19-tested-payload.json`,
`evidence/T19-source-review-final3.json` and `evidence/T19-preliminary-cleanup-limit.json`.
Independent final3 source/security review passes at C2 with no unresolved finding;
its frozen eighteen-file inventory is exact or proved strict UTF-8 LF/CRLF
conversion preserving BOM. The post-code TEST_STRATEGY documentation clarification
is declared separately outside frozen C2; runtime, builder and harness remain C2.
Mandatory LF README proof in both hosted shells resolves the prior coverage finding.
The initial `evidence/T19-source-review.json` remains historical at d69732a.
The intermediate C1 1cb92a18ed162861b286a47cabb6ae365ee8b4e0 retains
`evidence/T19-source-review-final2.json`, `evidence/T19-ci-runs-final2.json` and
`evidence/T19-hosted-payload-final2.json`. The selected corrected source is C2 70d1e2f.
Its inspected local payload passes **1,196 required groups plus six separate
baseline observations**: 890 milestone and 306 routine groups. It contains 34
aggregate reports and 48 raw records, including thirty T16-family final19 parents actually
tested at d69732a, two configured-Music final19 parents at 1cb92a1 and two T17
routine CI final21 parents at 70d1e2f, twelve routine children and two dependency
provenance records. Earlier milestone and Music source files are independently
proved unchanged at C2; preserve every original tested_commit. The binder covers
45 source files through 644 relationships: 628 actual before/after and sixteen
single fingerprints without after fields, plus four exact resolver-function
relationships. Only proved strict UTF-8 LF/CRLF conversion preserving BOM is
allowed; no absent after field is invented. Routine CI passes 153 required
groups/three observations per shell, including 51 packaging cases; children are
not counted again. All 34 selected PowerShell sources parse and the explicit
nine-file analyzer gate has zero diagnostics.

Actual active environment is Windows 11 Pro 26300.9457, PS5.1.26100.9444/Desktop,
PS7.6.5/Core, external Gyan FFmpeg/ffprobe 9.0.2 essentials and official
PSScriptAnalyzer 1.25.0. Selected final21 dependency provenance copies are
byte-identical to final4; actual setup invocation/tested_commit remains 15d8dc1
with verified external roots and no new provisioning. These roots are retained
separately from media/guard cleanup. Preserve the original real-FFmpeg suite,
short synthetic fixtures, source/fixture preservation, bounded native/process
release and exact owned cleanup checks. Selected source/synthetic preservation,
process release and current owned cleanup pass where recorded. Retained historical
false-cleanup scopes remain unchanged.

`tools/Build-Package.ps1` reads `tools/package-files.json` and exact Git blobs from
a supplied full lowercase commit matching clean detached HEAD. It refuses tracked,
untracked or ignored dirt, required omissions, unexpected/unsafe allowlist names,
Git symlink modes and reparse ancestors, source-contained outputs/provenance,
existing output, active helper statements and archive attribute changes. The
corrected Git archive invocation supplies process-local core.autocrlf=false and
core.eol=lf overrides; it makes no persistent Git configuration change. The
eight ZIP-root files are entry PS1, functions-only helper, BAT, README, SUPPORT,
CHANGELOG, SECURITY and MIT LICENSE; helper/BAT adjacency is preserved. No icons,
poster, tests/CI/build files, .git/evidence, FFmpeg binaries, logs, media or caches
are shipped.

Get-AudioAppVersion remains the sole runtime 1.0.0 source; exact-source helper
supplies app/ZIP/tag version and tag mismatch is rejected. ZIP members have ordinal
order and fixed timestamps; only actual byte comparisons establish repeatability.
The external manifest records commit, inventory hashes/sizes, ZIP digest, build/
input/shell provenance, actual signing and external dependency identity.
SHA256SUMS hashes ZIP and manifest only. Supplied passing test references are
caller attestations; the builder validates their schema/commit/digest/status
without proving acceptance or authorization. Runtime remains local and unsigned;
checksums do not authenticate the publisher. FFmpeg setup remains manual/external
with vendor source/license notices. No runtime downloader/updater, telemetry,
account, service or production Python dependency exists.

Both initial archive-fix precommit focused package runs pass 51 cases with source/fixture
preservation and owned cleanup true. Their actual tested_commit remains d69732a;
corrected working bytes are separately fingerprinted in
`evidence/T19-package-fix-commands.json`. The new case records bare-LF fixture
members and actual true/crlf Git settings, proves exact packaged blob bytes and
unchanged settings, restores false/lf and compares all three second-build assets
byte-for-byte within each shell. Do not count these precommit runs again as
committed-source routine acceptance.

The C2 fixture setup first proves all ten copied files match actual source bytes,
then normalizes only the owned README copy by removing CR immediately before LF.
It records copied and normalized hashes/sizes/policy, preserves BOM, existing LF
and lone CR, and verifies production README stays unchanged. The CRLF regression
must contain README.md in its bare-LF member list before the first build. The
focused final2 repair reports pass 51 groups per shell with that member present
and source/fixture/cleanup true; their actual tested_commit is C1 with corrected
working-byte fingerprints. They are not counted again as committed-C2 routine
acceptance. Group count and two positive builds remain unchanged.

Read exact selected invocation routing in `evidence/T19-milestone-commands.json`,
`evidence/T19-default-music-commands.json` and `evidence/T19-routine-commands.json`.
Use fresh allowed evidence names/RunLabel for repeats. Default-Music smoke is the
bounded `Test-OutputParent.ps1 -DefaultSmoke` route with synthetic input and only
the returned exclusive owned run inspected/cleaned; unrelated Music entries are
not enumerated and known-folder settings are unchanged. Never run the original
baseline blindly against ordinary Music. Selected C1 Music reports pass eleven
required checks per shell, with TEMP and exact owned Music-run cleanup true; their
actual C1 tested_commit is preserved and source bytes are proved unchanged at C2.
These checks are included in the 890 milestone groups. That automated smoke is
separate from T20 named manual evidence.

`evidence/T19-exploratory-builds.json` and
`evidence/T19-exploratory-manifest-ps51.json` / `-ps7.json` record builds from this
corrected C2 source. Both builds pass with exactly eight ZIP members matching C2
Git blob bytes/object IDs/hashes/sizes. Both script signatures are NotSigned;
external tools and input/report hashes are verified. All 659 tracked source files
are byte-unchanged and detached source is clean before/after. ZIP sizes are 53,272
bytes in PS5.1 and 53,289 in PS7; decompressed contents match but compressed member
sizes differ. Cross-shell ZIP, manifest and SHA256SUMS bytes all differ; no
cross-runtime repeatability is promised. Same-shell repeat equality belongs to
the separately recorded package regression. Read
`evidence/T19-exploratory-command-bindings.json` for five full actual expanded argv
commands and external argv/result/raw-stream bindings. Original manifest evidence
copies match external bytes.
Exploratory roots and full raw driver capture remain retained outside Git.
These are source/exploratory builds, not an integrated frozen release candidate or exact release-ZIP acceptance.
T23 freezes integrated C and tests that exact ZIP. No tag/draft/public release or
release authorization is inferred from a local package build.

## Preserve failures and existing limits

C1 hosted package reports passed 51 groups but recorded empty LF member lists in
both shells; the LF transformation regression was therefore inactive there.
Local C1 fixtures had LF members. Preserve that finding and the unchanged original
C1 review/hosted reports. C2 repairs only the owned README setup and required-LF
assertion; production README and builder bytes are unchanged from C1. Final C2
local and hosted acceptance pass with the required LF member.

Initial detached d69732a exploratory package builds failed in both shells before
assets: ambient system core.autocrlf=true changed eight LF members to CRLF.
Independent binary checks confirmed the narrow process-local false/lf override
matches all ten Git blobs. Preserve `evidence/T19-exploratory-builds-attempt1.json`.
The initial inspector driver exited without retained child stdout/stderr; its
precise cause is unknown and the initial full working-byte inventory was not
retained. Preserve only the captured read-only clean/source observations and
later successful direct signing inspection; infer no failed-build repeatability.

Preserve C2 external driver attempt2 in
`evidence/T19-exploratory-builds-attempt2.json`: its PS5.1 signing/version inspector
failed before builder invocation, with Microsoft.PowerShell.Security autoload
failure captured in full raw stderr outside Git. The successful driver removes
inherited PSModulePath only in each owned child so shell defaults initialize;
parent/global environment and source files are unchanged. A shared environment
cause for the uncaptured C0 inspector failure is only an inference. No retained
exploratory-root cleanup is claimed.

Package PS7 attempts1/2 remain failed with original cleanup_verified false and
unchanged raw bytes; exact original harness snapshots are retained. Attempt1's
Invoke-Case $Name shadowed loop $name, invalidating its intended exact omission/
dirty-name coverage; attempt2 passes 49 scenarios but cleanup failed with Access
denied. The original errors do not prove the exact cleanup statement that failed.
The final harness uses process TEMP, records root name/logical parent/marker hash
and cleanup stage/stack, and proves only its own scope cleanup.

Attempt1's known exact synthetic root was independently audited read-only with
matching source/build/asset hashes and no reparse points. Its original token digest
was absent, so original-token equality/recovery is not claimed. Attempt2 recorded
a marker hash but not its redacted root name; that remaining scope cannot safely
be identified. Both old roots remain retained; current successful cleanup does
not alter either historical false outcome.

Automatic approval review rejected independent exact attempt1 cleanup and a
separate synthetic cleanup probe before CreateProcess, stating only "blocked by
policy" with no detailed reason. No probe root/report was created, and no equivalent
retry occurred. Preserve the separate scopes in T19-preliminary-cleanup-limit.json.

A third distinct cleanup, of the known temporary hosted-download root for initial
PR run 38145173494, was rejected before execution by automatic approval review
with only "blocked by policy" and no detailed reason. No mutation or equivalent
retry occurred. Its retained public hosted JSON/source excerpts, marker and
temporary verifier are recorded in `evidence/T19-hosted-capture-limit.json`;
no product source files, vendor binaries or personal media were copied there.
The sixteen preserved original reports were verified byte-identical before the
rejection. Claim no cleanup success and do not combine this with either older
package root.

Retain T18's selected local 242 required groups/six observations, actual source
bindings, original failed help attempt, four failed historical hosted runs and
repaired root-case regression with two green runs. Historical hosted 204 groups/
six observations supplement those local results; no later acceptance is inferred.
Retain T17's failed 260-unit characterization, private-layout repair to 227,
complete dependency pinning and separate blocked-cleanup research root with its
original retained-root/false-cleanup outcome and no equivalent retry.

T01 importer and T11 owner-confirmed physical Ctrl+C remain historical. T16's
974 regression groups/six observations, source relationships and recovery scope
remain retained. Preserve T07 residue, T09 post-guard interval, T11 forced-host,
T14 persistence and metadata/cover/chapter/player limits. No new phone, Explorer/
STA picker/drag-drop interaction, representative long-file, physical/manual,
NAS/UNC/network-redirected Music or public-release evidence is inferred from
T19 automated checks/default smoke/builds. Optional loudness stays deferred.

README/SUPPORT/SECURITY disclose unsigned scripts and the existing BAT process
Bypass. Preserve read-only policy inspection, personal unblocking only of reviewed
exact files and no bypass of enforced policy. Runtime/BAT/retained legacy suite/
workflow/lock/initializer bytes remain unchanged. Routine CI adds packaging while
preserving official action pins, contents: read, no secrets/privileged triggers/
persisted checkout credentials and current-run JSON-only uploads.

## Start exactly T20 after owner integration

If draft PR #19 is owner-merged, independently verify advertised main, safely
fast-forward clean local main and create a relevant T20 codex branch. Read
`tasks/T20.md`, `TEST_STRATEGY.md` and `templates/MANUAL_WINDOWS.md` next.
Use the near-final reviewed integrated source on the same Windows 11 machine,
with Windows PowerShell 5.1 and PowerShell 7, and record a named ordinary-user
tester, actual versions, UTC time, exact source and real commands/observations.

T20 must cover real BAT drag/drop and STA cover selection, no-prompt CLI, spaces/
special paths, failure/cancellation, controlled default output and a representative
long audio file. Record private input IDs/characteristics and output hashes rather
than raw personal media. Do not invent manual/phone evidence or mark a template
run. Preserve machine execution policy/endpoint settings; an actual restriction
is a documented blocker or limitation, not authority to bypass it. Any source
change afterward triggers affected acceptance reruns.

T21 phone acceptance, T22 pre-freeze reconciliation, T23 exact integrated frozen
ZIP and T24-T27 release/public-download/closure remain subsequent gated work.
Main/release authority stays governed by AUTHORITY.md and RELEASE_RUNBOOK.md.

Copy-ready prompt: T20 next please
