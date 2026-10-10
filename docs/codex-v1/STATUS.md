# Current project status

State: **T03 complete — OutputParent and isolated ordinary tests verified.**
Last completed task: T03. Exact next task: T04.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T04 in a new thread: extract small helpers and implement preflight.**
Use NEXT_SESSION.md. A07 and A08 passed on both required Windows shells.

## Environment and checkpoints

- Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`.
- Active branch: `codex/v1-t03-output-isolation`; origin fetch/push identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Owner merged T02 PR #2 at 20:32:54 UTC on 10 October 2026. Local main was
  fast-forwarded to independently advertised main
  `0818bf8206849370aa0ef2eaeccaed5b2fb1a890` before T03; no agent merge occurred.
- Tested working payload was based on that main commit. Reports retain the actual
  base and file fingerprints. Equivalent code checkpoint:
  `b5b3c8b7837dd8af17ae4e5b8405684ccdd7237e`; see `evidence/T03-tested-payload.json`
  for SHA-256 and Git-blob comparison, including CRLF/LF normalization.
- Code checkpoint was pushed and independently matched with fresh `ls-remote`.
  Final evidence/handoff follows it; final post-push HEAD is reported in the response.
- Draft PR #3: https://github.com/PikkuJanne/AudioFileForPhone/pull/3.
  T03 feature checkpoint synchronized; **T03 main integration pending owner review**.
- Installed native pair remains `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`, build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`; hashes are in reports.

## Verified behavior and evidence

`-OutputParent` selects a filesystem parent, including relative or missing paths.
Omission retains configured Windows Music. Run names, relative layout, default
64 kbps CBR, formats, names and metadata are preserved. Destination/log operations
are literal, so missing parents containing spaces/brackets work end to end.
The BAT is unchanged.

Ordinary suite and companion passed on both shells using byte-identical app copies
and fresh owned TEMP parents. Seven required baseline checks per shell passed;
source relative names/hashes and owned cleanup passed. Ten resolver cases per shell
passed, including injected redirected Music, bypass on override and non-filesystem
rejection. Separate instrumented configured-Music smokes passed on both shells:
exclusive reservation, create-new marker, no OutputParent override, exact synthetic
inventory, source preservation, 64 kbps MP3, full decode and exact owned cleanup.
No known-folder registry or persistent policy/PATH setting was changed.

**A07 and A08 passed.** See `evidence/T03.md` and linked JSON reports. The smoke
changes only the disposable copy's timestamp assignment; it is automated default
resolution evidence, not manual/phone playback evidence. Ordinary runs use TEMP only.

Existing impossible-date and corrupt/mixed batch exit-0 gaps remain observed.
BAT failure masking/extra-folder gaps remain historical T02 observations.
Production run reservation, broader preflight and transactional output are later
work. No CI, long-file/phone acceptance, release ZIP, tag or release was run.

## Canonical isolated commands

Both passed exit 0 and clean up only their owned disposable trees:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T03-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T03-baseline-ps7.json
```

Direct ordinary `tests/Test-AudioFileForPhone.ps1` now uses TEMP safely. Focused
resolver/smoke commands are in TEST_STRATEGY.md and `evidence/T03.md`.
T02 resolver-substitution helpers are historical against their frozen payload;
do not use those old commands as T03 canonical tests.

## Authority and completion boundary

Normal in-scope edits/tests/commits/feature pushes/draft PR updates are authorized.
Main integration and exact release/tag/publication retain their gates. T02 is
integrated; T03 is pending. No CI workflow or public v1.0.0 exists. Overall project
completion still requires public download verification and final-main closure.
