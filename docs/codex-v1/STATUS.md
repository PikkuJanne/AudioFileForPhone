# Current project status

State: **T02 complete — isolated baseline and contract characterization passed.**
Last completed task: T02. Exact next task: T03.
Required improvements: 1–15. Optional O01: deferred. No application changes.

## Next suggested step

**Start T03 in a new thread: add OutputParent and isolate ordinary tests.**
A04–A06 passed on both required shells. Use the copy-ready prompt in
NEXT_SESSION.md and the installed pair under `C:\ffmpeg\bin`.

## Environment and checkpoints

- Windows 11 Pro 64-bit, build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`.
- Active branch: `codex/v1-t02-baseline`; origin fetch/push identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- T01 PR #1 was merged by PikkuJanne at 19:45:49 UTC on 10 October 2026.
  Local main equals independently advertised main
  `483af25f8e5fa9dee295f5b74130324663339e37` at this checkpoint.
- T02 reports record test base `9fceee091fc4bfd43bdab64d5bb943a3b620bc79`
  plus exact working helper hashes. The tested payload is preserved at code
  checkpoint `84bd98656e9e56c9d244aa8b9a216d0204dd23d8`; see `evidence/T02-tested-payload.json`.
  Final evidence documentation follows it; final post-push HEAD is reported in
  the response. Refresh actual HEAD/live refs every session.
- Draft PR #2: https://github.com/PikkuJanne/AudioFileForPhone/pull/2.
  Feature checkpoint is synchronized; T02 integration into main is pending.
  The owner-performed T01 merge does not create blanket merge authority.
- Application/BAT/original integration suite remain byte-identical to
  `2bf1ea1921ab33633b978bd384bbbf098648ceed`.
- Owner supplied `C:\ffmpeg` when resuming T02. Installed executables are
  `C:\ffmpeg\bin\ffmpeg.exe` and `C:\ffmpeg\bin\ffprobe.exe`, both build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`. Exact hashes are in evidence.

## Evidence and limitations

The retained legacy suite and focused companion passed on both shells. Generated
MP3/AAC M4A/Vorbis/Opus OGG, uppercase extensions, exclusions, 64 kbps frame CBR,
ID3v2.3, mono/stereo and unchanged 44.1/48 kHz, full decode, metadata/Unicode/
overrides, date-first/default-60 names, recursive layout and source inventories
were checked. **A04, A05 and A06 passed.** Owned cleanup passed in every stored run.

The 96-case native bitrate matrix per shell establishes the fixed-rate whitelist
and profile rounding; actual baseline name-limit runs establish 24/180 including
collisions. Arithmetic suffix/path policy checks select conservative limits.
Root/reparse rejection, Unicode scalar truncation, path-limit enforcement and
produced-rate validation still belong to later tasks. Policies are not implemented
by T02. Measured short-clip duration deltas do not finalize T09's tolerance.

Observed baseline gaps: impossible `2024-02-30` retained; corrupt-only/mixed batches
exit 0 despite failures; BAT hides child 1/2 behind exit 0 and Done, and ignores
extra folders. Evidence labels these gaps separately from required passes.
Some matrix details remain unrun, listed in T02_REGRESSION_MATRIX.md.
No ordinary Music smoke, phone acceptance, release ZIP or CI was run.

## Verified baseline commands

Both commands passed (exit 0) using only owned disposable media/output:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T02-baseline-ps7.json
```

Focused contract/launcher commands and historical adapter guard results are in
TEST_STRATEGY.md and `evidence/T02.md`. The adapter redirects exactly one Music
resolver in each disposable application/test copy and verifies production PATH
discovery selects the explicit pair. No persistent policy or machine setting was
changed. Never invoke the original suite directly against ordinary Music before
T03 isolation. T03 must update these canonical commands for its final harness.

## Authority and completion boundary

Normal in-scope implementation/testing/commits/feature pushes/draft PR updates are
authorized. Main integration and exact release/tag/publication retain their gates.
No CI workflow exists and no public v1.0.0 exists. Overall project completion still
requires public download verification and final-main closure in RELEASE_RUNBOOK.
