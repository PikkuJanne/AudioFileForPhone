# Current project status

State: **T18 complete; A45/A46 pass on both local supported shells.**
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
- Selected local T18 code: 15d8dc1f43199c08bdd12f3bc49cb093db7d2e9d.
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

Selected reports at code 15d8dc1 pass **256 required groups plus six separate
baseline observations**: help attempt2 seven and diagnostics final1 nineteen per
shell, plus expanded routine CI final3 102 per shell. CI child reports are not
counted twice. Its five sequential families retain unit31, dependencyguards22,
baseline7, help7 and native35; the original legacy real-media suite also passes.
All 32 selected PowerShell sources parse, and the explicit seven-file analyzer
gate has zero default Errors/ten-rule diagnostics. Legacy style warnings remain
outside this gate. See evidence/T18.md, T18-tested-payload.json and
T18-source-review.json. The selected payload binds 18 reports and 40 source files
through 320 actual relationships to reviewed Git blobs, allowing only proved
strict UTF-8 LF/CRLF conversion while preserving BOM bytes.

Help executes the exact Get-Help Code of all five examples in owned children;
12 actual outputs per shell independently probe/full-decode. All ten public
PowerShell fences parse; policy/unblock/setup/interactive fences are syntax-only.
Preview and helper examples preserve exact owned directory/file/hash/time/attribute
inventories without ordinary Music access. Selected source/synthetic hashes,
positive descendant release, child disposal and exact owned fixture cleanup pass.
Dependencies are retained outside Git for checks, separate from media/guard cleanup.

Raw setup/CI final3 records retain the existing T17 artifact namespace while their
actual tested_commit names T18 code 15d8dc1. Historical T17 final2 reports are
unchanged. The workflow, lock, dependency initializer, BAT and original retained
integration bytes remain unchanged; adding help to routine checks changes no CI
rights or downloader policy. Review has no implementation/security blocker.

The preliminary PS5.1 help attempt1 at 5eb1374 failed because imported helper
functions made Get-Help classify the multiline fifth example's second line as
remarks. Source/fixture/release/cleanup stayed true. The production help and README
now use the same single-line fifth command; both attempt2 reports pass. This
failure remains preserved. An earlier direct dependency invocation failed the
host check before its body; it created no root/report, and no success is inferred.

## Verified local command expansion

These describe selected invocations, not commands to overwrite existing reports.
For a repeat, use fresh allowed EvidencePath labels and a fresh RunLabel. Tool
paths below are read from the actual setup records. Both help invocations and
PS5.1 diagnostics used the retained verified PS5.1 final2 record; PS7 diagnostics
used its new PS7 final3 record. Routine checks used each shell's new final3
setup record. PS7 raw reports expose the managed
pwsh.dll host behind the launched adjacent pwsh.exe.

```powershell
$shells = @{
  ps51 = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
  ps7 = 'C:\Users\jtvuo\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
}
$tools = Get-Content -LiteralPath 'docs/codex-v1/evidence/T17-dependencies-ps51-final2.json' -Raw | ConvertFrom-Json
foreach ($edition in @('ps51','ps7')) {
  & $shells[$edition] -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File 'tests/Test-HelpVersion.ps1' -EvidencePath ('docs/codex-v1/evidence/T18-help-' + $edition + '-attempt2.json') -FfmpegPath $tools.ffmpeg_path -FfprobePath $tools.ffprobe_path
  $diagnosticTools = if ($edition -eq 'ps51') { $tools } else { Get-Content -LiteralPath 'docs/codex-v1/evidence/T17-dependencies-ps7-final3.json' -Raw | ConvertFrom-Json }
  & $shells[$edition] -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File 'tests/Test-Diagnostics.ps1' -EvidencePath ('docs/codex-v1/evidence/T18-diagnostics-' + $edition + '-final1.json') -FfmpegPath $diagnosticTools.ffmpeg_path -FfprobePath $diagnosticTools.ffprobe_path
  & $shells[$edition] -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File '.github/scripts/Invoke-CiChecks.ps1' -DependenciesPath (Join-Path $PWD ('docs/codex-v1/evidence/T17-dependencies-' + $edition + '-final3.json')) -RunLabel final3
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
