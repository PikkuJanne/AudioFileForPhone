# Current project status

State: **T01 local checks complete; feature push/live checkpoint pending.**
Current task: T01. Next coherent task after its verified checkpoint: T02.
Required improvements: 1–15. Optional O01: deferred. No application changes.

## Environment

- Windows 11 Pro 64-bit, build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main` (missing metadata restored only
  after owner approval and all nine original files matched live Git blobs).
- Active branch: `codex/v1-t01-checkpoint`. Fetch/push origin both identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Baseline/tested application SHA and last live main checkpoint:
  `2bf1ea1921ab33633b978bd384bbbf098648ceed`. Live main has no drift from the bundle.
- Local main equals live GitHub main at that baseline. T01 integration: pending.
- Bundle validation passed; supplied Python helpers 41 tests passed under each
  shell; supplemental Windows helpers 23 cases per shell passed (46 total).
  Evidence: `evidence/T01.md`, `T01-helper-results.json`, `T01-source-inventory.json`.
- Real active-branch sync: pending successful push and fresh live-ref comparison.

## Authority and limitations

Startup permits implementation/testing, focused commits, task-branch pushes and
draft PRs. Owner approved restoring Git metadata and requested no repeated
confirmation. No main-merge policy or exact release authorization is recorded.
See DECISIONS and AUTHORITY; one active task branch and small draft PR workflow.

FFmpeg/ffprobe were not found on PATH or in the checkout. No conversion tests,
Windows application acceptance, real-phone acceptance or CI were run. The legacy
integration suite touches ordinary Music and remains unrun pending proven
isolation. No CI workflow exists at baseline. GitHub CLI authentication failed;
Git push authentication is still to be tested. Connected GitHub reads worked.
No public v1.0.0 exists; website work is excluded.

## Completion boundary

T01 is complete only after a clean committed branch equals its fresh live ref.
The overall project remains incomplete until the public release, real-download
verification and final-main closure gates in RELEASE_RUNBOOK are satisfied.
