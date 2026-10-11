# Current project status

State: **T18 complete; A45/A46 pass locally and repaired push/PR Windows jobs are green.**
Last completed task: T18. Exactly next task: T19 after owner integration.
Required improvements 1-15; optional O01 deferred. Project/release remain incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t18-help-version.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner PikkuJanne merged T17 PR #17 at 12:46:33 UTC on 11 October 2026 into
  main efe928367fe6380afd754dbd2376766506dd6815; final T17 feature
  a4c008d0a982d5fbb9ecc71668dcceb170957d6b. Normal fetch, independently
  advertised refs and live GitHub matched; clean local main was fast-forwarded
  before branching. T01-T17 are integrated. See evidence/T18-start.json.
- Selected repaired T18 code: 3766e168a1cf983d38b3a079d14d0fb589c0e6ae.
  Reviewed code was pushed and independently matched the live feature ref.
  Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/18.
  Evidence/handoff follows in a docs-only checkpoint. The final feature push,
  independent HEAD/live-ref comparison and actual new hosted checks belong in
  the draft PR/response without a self-referential containing SHA.
  **T18 main integration remains owner-gated.** No release authorization was added.
- Active Windows 11 Pro 26300.9457; PS5.1.26100.9444/Desktop and bundled
  PS7.6.5/Core. Fixed external Gyan FFmpeg/ffprobe 9.0.2 essentials and official
  PSScriptAnalyzer 1.25.0 are verified through retained CI-only dependency records.
  No global installation, PATH/module-path setting or machine policy change.
- Historical T17 hosted checks used Windows Server 2025 image win25-vs2026
  20260925.250.1; PS5.1.26100.33438/Desktop and PS7.6.6/Core. Those results
  supplement Windows 11 and are distinct from T18 local acceptance.

## T18 behavior and evidence

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

## Verified local command expansion

These describe selected invocations, not commands to overwrite existing reports.
For a repeat, use fresh allowed EvidencePath labels and a fresh RunLabel. Current
routine checks use each shell's final4 provenance copy of the verified final3
dependency record. Retained PS5.1 diagnostics used PS5.1 final2; retained PS7
diagnostics used PS7 final3. PS7 raw reports expose the managed
pwsh.dll host behind the launched adjacent pwsh.exe.

```powershell
$shells = @{
  ps51 = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
  ps7 = 'C:\Users\jtvuo\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
}
$tools = Get-Content -LiteralPath 'docs/codex-v1/evidence/T17-dependencies-ps51-final2.json' -Raw | ConvertFrom-Json
foreach ($edition in @('ps51','ps7')) {
  $diagnosticTools = if ($edition -eq 'ps51') { $tools } else { Get-Content -LiteralPath 'docs/codex-v1/evidence/T17-dependencies-ps7-final3.json' -Raw | ConvertFrom-Json }
  & $shells[$edition] -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File 'tests/Test-Diagnostics.ps1' -EvidencePath ('docs/codex-v1/evidence/T18-diagnostics-' + $edition + '-final1.json') -FfmpegPath $diagnosticTools.ffmpeg_path -FfprobePath $diagnosticTools.ffprobe_path
  & $shells[$edition] -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File '.github/scripts/Invoke-CiChecks.ps1' -DependenciesPath (Join-Path $PWD ('docs/codex-v1/evidence/T17-dependencies-' + $edition + '-final4.json')) -RunLabel final4
}
```

## Preserved limits and next action

Retain historical T17 evidence/security policy, including the failed 260-unit
hosted characterization and its private-layout repair to 227, complete pinned
inventories and the separate research-root cleanup rejected before execution by
automatic approval review. Its retained-root/false-cleanup outcome is not changed
by T18 fixture cleanup; no equivalent deletion retry is authorized or claimed.

T01 importer and T11 owner-confirmed physical Ctrl+C remain historical. T16's
974 regression groups/six observations, source relationships and recovery scope
remain retained. No new phone/Explorer/NAS/UNC/network-redirected Music, physical
manual, frozen ZIP or publication acceptance is inferred. Preserve metadata/cover/
chapter scope, T07 possible residue, T09 post-guard interval, T11 forced-host and
T14 persistence limits. Loudness remains deferred.

Owner review/integration of the T18 draft PR is required. Independently reconcile
main before exactly T19: package build and dependency/security policy. No release yet.
