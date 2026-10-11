# Current project status

State: **T17 complete; A43/A44 pass; local and real GitHub checks are green.**
Last completed task: T17. Exactly next task: T18 after owner integration.
Required improvements 1-15; optional O01 deferred. Project/release remain incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t17-windows-ci.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner PikkuJanne merged T16 PR #16 at 12:08:33 UTC on 11 October 2026 into
  main dc88a1da04929e9c985469a2833f23407d0b0e15; final T16 feature
  d17743b39b6e30b32d567a5f5f1628b59c303959. Normal fetch and independent live
  refs matched; clean local main was fast-forwarded before branching.
  T01-T16 are integrated.
- Reviewed final code 8cb3c07c40bf60bd3fa543f29431496029362d74 was pushed and
  independently live-ref matched. Initial code 57c3c2f remains historical.
  Evidence/handoff follows in a docs-only checkpoint; final HEAD/ref and new CI
  checks belong in the PR/response without a self-referential containing SHA.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/17.
  **Feature synchronized; T17 main integration owner-gated.**
- Green code push 38139564959 and PR integration run 38139568879. PR source head
  8cb3c07 differs from tested merge f8f9d71eff213af172eba14a33123845f4fcf139;
  fresh PR API/ref and uploaded reports agree, and complete Git trees match.
- Active Windows 11 Pro 26300.9457; PS5.1.26100.9444/Desktop and bundled
  PS7.6.5/Core. Actual hosted Windows Server 2025 image win25-vs2026
  20260925.250.1; PS5.1.26100.33438/Desktop and PS7.6.6/Core.
  Fixed Gyan FFmpeg/ffprobe 9.0.2 essentials and official analyzer 1.25.0.
  No global installation, PATH/module-path setting or machine policy change.

## T17 behavior and evidence

One Windows workflow checks all branch pushes and ordinary PR integration commits
under both shells. It uses full reviewed official action SHAs, only contents: read,
no secret-bearing trigger/release job/tag trigger, no persisted checkout token
and bounded current-run JSON uploads. CI-only dependency setup verifies fixed
publisher archive SHA-256/size before safe extraction, then whole inventories and
entry-point fingerprints are rechecked before import or tests. See CI_SECURITY.md
and evidence/T17.md. The exact-commit/exact-assets operator release gate remains.

Selected local final2 and uploaded PR reports pass **95 required groups plus three
baseline observations per shell**, 380 required groups plus twelve observations
across four executions. Syntax passes all selected PowerShell sources; every default
analyzer Error plus ten selected rules reports zero diagnostics. Four suites run
sequentially: 31 pure contracts, 22 ZIP/download guards, seven required retained
baseline checks and 35 native groups. Original legacy real-media tests, unchanged
source/fixture bytes, positive descendant release and exact media/guard cleanup pass.
Ordinary Music is unused. The complete T16 milestone suites remain retained.

The static audit retains 98 default diagnostics with zero Errors/selected-rule
diagnostics. Legacy style/console/null-comparison/BOM warnings are outside this
explicit gate. Production PS/helper/BAT and original retained integration bytes
remain unchanged. The selected payload binds actual report/source bytes to reviewed
Git blobs, permitting only strict UTF-8 LF/CRLF conversion and preserving BOM bytes.

First hosted push/PR jobs failed at 57c3c2f: runneradmin TEMP made a characterization
nested working path exactly 260 units, correctly rejected before reservation.
Only test-private sequential run parents under the exclusive wrapper GUID were
shortened; actual planner replay now reaches 227. All fresh-parent, source, boundary,
cleanup and production limits remain intact. Failed JSONs, earlier local finals,
preliminary harness failures/snapshots and audit records remain separate and unchanged.

## Preserved limits and next action

CI dependency roots remain outside Git for checks. A separate research TEMP folder
contains only two pinned archives and an ownership marker. Automatic approval review
rejected cleanup before execution with "blocked by policy"; proof/outcome preserve
its retained-root/false-cleanup state. No equivalent retries or fabricated success.
This is separate from passing media/guard fixture cleanup.

T01 importer and T11 owner-confirmed physical Ctrl+C evidence remain historical.
Hosted Windows Server checks supplement active Windows 11; no phone/Explorer/NAS/UNC,
frozen ZIP or publication acceptance is inferred. T16.md/tested-payload retain 974
regression groups/six observations, source relationships, preliminaries/recoveries
and their limits. Preserve metadata/cover/chapter scope, T07 possible residue,
T09 post-guard interval, T11 forced-host and T14 persistence limits. Loudness deferred.

Owner review/integration of draft PR #17 remains required. Independently reconcile
main before exactly T18: help, docs, version and support boundaries. No release yet.
