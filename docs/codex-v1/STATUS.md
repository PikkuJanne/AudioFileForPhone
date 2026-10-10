# Current project status

State: **T02 blocked — test preparation pushed; real baseline execution awaits FFmpeg/ffprobe.**
Last completed task: T01, now integrated by the owner. Exact next task: finish T02.
Required improvements: 1–15. Optional O01: deferred. No application changes.

## Next suggested step

Provide locally installed `ffmpeg.exe` and `ffprobe.exe` (PATH or full executable
paths), then resume T02 and run the isolated baseline on both shells. A04–A06
must pass before T03. The T03 exception permits an isolation-only blocker;
missing native dependencies do not qualify.

## Environment and checkpoints

- Windows 11 Pro 64-bit, build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`.
- Active branch: `codex/v1-t02-baseline`; origin fetch/push identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- T01 PR #1 was merged by PikkuJanne at 19:45:49 UTC on 10 October 2026.
  Local main was fast-forwarded to independently advertised main
  `483af25f8e5fa9dee295f5b74130324663339e37`.
- Tested T02 harness/matrix commit and independently advertised feature checkpoint:
  `0b71b68ee044639d82bd1b7bc43e10d023258be4`.
  Final evidence documentation follows it; final post-push SHA is reported in
  the response. Refresh HEAD/live refs every session.
- Draft PR #2: https://github.com/PikkuJanne/AudioFileForPhone/pull/2.
  T02 integration into main is pending; the owner-performed T01 merge does not
  create blanket merge authority.
- Application baseline remains byte-identical to
  `2bf1ea1921ab33633b978bd384bbbf098648ceed`, including the original integration suite.

## Evidence and limitations

T02 adds a regression matrix, test-only copy adapter and focused synthetic
characterization companion. Each copied Music resolver is replaced exactly once;
application/original-test files are untouched. Adapter validation and companion
syntax passed on both shells; all four unsafe report-path rejection checks passed.
Owned TEMP cleanup and original source hashes passed in those harness checks.
Evidence: `evidence/T02.md` and the five linked T02 JSON reports.

Neither FFmpeg nor ffprobe was found on PATH, in the checkout, common installed
locations or bundled runtime. Real-mode attempts on both shells exited 1 before
fixture creation/conversion and recorded blocked. **A04, A05 and A06 are blocked.**
No audio/source-media hash comparison, default-Music smoke, Windows application
acceptance, phone acceptance or CI ran. Source-review deficiencies and proposed
bitrate/name/path choices remain unvalidated, not acceptance successes.

## Verified commands and pending real execution

Adapter-only checks passed (exit 0); these do not pass A04–A06:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-isolation-ps51.json -ValidateOnly
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-isolation-ps7.json -ValidateOnly
```

Real-mode attempts blocked (exit 1); rerun when tools are available:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps7.json
```

Optional `-FfmpegPath`/`-FfprobePath` identify existing canonical executables;
the adapter verifies production PATH discovery selects the same pair. No global
execution-policy or authentication change was made. Never run the original suite
directly against ordinary Music before T03 isolation.

## Authority and completion boundary

Normal in-scope implementation/testing/commits/feature pushes/draft PR updates are
authorized. Main integration and exact release/tag/publication retain their gates.
No CI workflow exists and no public v1.0.0 exists. Overall project completion still
requires public download verification and final-main closure in RELEASE_RUNBOOK.
