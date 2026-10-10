# Current project status

State: **T05 complete — native execution and media inspection verified.**
Last completed task: T05. Exact next task: T06.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T06 in a new thread: bound recursive scanning and exclude prior output.**
Use NEXT_SESSION.md. A12, A13 and A14 passed on both required Windows shells.

## Environment and checkpoints

- Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`.
- Active branch: `codex/v1-t05-native-process`; fetch/push origin identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Owner merged T04 PR #4 at 21:06:59 UTC on 10 October 2026 into main
  `124f3a96e1a416f6870b832d1ee1cc7543286ab9`. Local main was fast-forwarded
  to the independently advertised ref before T05. No agent merge occurred.
- Reports retain actual test base `124f3a96e1a416f6870b832d1ee1cc7543286ab9`
  and working source fingerprints. Equivalent tested code checkpoint:
  `215b57c2d1fd93ab62192e07c9ba30632bf2824e`. See `evidence/T05-tested-payload.json`
  for SHA-256/Git-blob equivalence, including only recorded CRLF/LF normalization.
- Code checkpoint was pushed and independently matched with fresh ls-remote.
  Final evidence/handoff follows it; final post-push HEAD is reported in the response.
- Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/5.
  **T05 feature synchronized; main integration pending owner review.**
  T01–T04 are integrated into main.
- Installed pair: `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`, build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`; hashes are in reports.

## Verified behavior and evidence

All runtime native calls now share `Invoke-AudioNativeProcess`: absolute executable
paths, CRT argv quoting on both shells, immediate exit status, timing and bounded
UTF-8 stdout/stderr captured by concurrent pool tasks. Default retention is
1,048,576 stdout/65,536 stderr characters; the remainder is drained and counted.
Ordinary stderr is not itself a failure. FFmpeg uses -nostdin, redirected stdin is
closed, and owned process/pipes/tasks are disposed. No conversion timeout is imposed.
Tool identity/libmp3lame checks run once before prompts; paths/versions enter the log.

`Get-AudioMediaInfo` selects a:0 and validates one audio stream/index. Startup,
nonzero exit, truncation, invalid JSON/schema and no audio have explicit results.
Failed inspection counts as a file failure; a valid missing title keeps the existing
filename fallback. Container tags for MP3/M4A and first-audio-stream comments for
Ogg preserve precedence. Conversion maps the validated first audio stream.
Defaults, Music/OutputParent resolution, names/layout, metadata options and BAT remain.

**A12–A14 pass.** Per shell: 35 focused native/probe/dependency cases, exact special/
quoted/Unicode argv, alternating/concurrent unterminated floods of 2,457,600 chars
per pipe, stable handles over 40 invocations (PS5.1 674→674; PS7 578→578), real quoted
Unicode metadata, cover/full audio decode and path/version logs. Final reports are
`T05-native-ps51-final.json` and `T05-native-ps7-final.json`; earlier failed attempts
remain separate. Retained FFmpeg suite/seven required companion checks, 35 preflight
negatives/eight helper checks and ten resolver cases pass per shell. Source/synthetic
hashes, exact ACL restoration and owned TEMP cleanup pass. See `evidence/T05.md`.

No ordinary Music run, registry/persistent policy change, downloads, external-reference
media/protocol audit, live-share acceptance, manual/phone/long-audio test, cancellation
test, CI, release ZIP, tag or release was performed. Diagnostic retention is a prefix;
truncation can omit a final error line. Later diagnostic work may refine this policy.
Impossible dates, aggregate failed-batch exit 0, recursive reparse/exclusion policy,
path budgets, production run reservation and transactional publication remain later tasks.

## Canonical isolated commands

Both shells passed these with the installed tools; ordinary tests use TEMP only.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-baseline-ps7.json
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-NativeProcess.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T05-native-ps7-final.json
```

Native reports are CreateNew; use a fresh T05 label to rerun. Preflight/resolver
commands are in TEST_STRATEGY.md/evidence/T05.md. Keep historical evidence intact.
Frozen T02 substitution helpers are historical, not canonical for current code.

## Authority and completion boundary

Normal in-scope edits/tests/commits/feature pushes/draft PR updates are authorized.
Main integration and exact release/tag/publication retain their gates. T05 awaits
owner integration. Overall project completion still requires the remaining tasks,
public download verification and final-main closure.
