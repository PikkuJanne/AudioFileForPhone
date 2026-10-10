# Current project status

State: **T04 complete — helpers and preflight verified.**
Last completed task: T04. Exact next task: T05.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T05 in a new thread: centralize native execution and media inspection.**
Use NEXT_SESSION.md. A09, A10 and A11 passed on both required Windows shells.

## Environment and checkpoints

- Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`.
- Active branch: `codex/v1-t04-preflight`; fetch/push origin identify
  `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Owner merged T03 PR #3 at 20:43:41 UTC on 10 October 2026 into main
  `bf425829d2e019911f179eb8250bfe6800f7ac81`. Local main was fast-forwarded
  to the independently advertised ref before T04. No agent merge occurred.
- Reports retain actual test base `bf425829d2e019911f179eb8250bfe6800f7ac81`
  and working source fingerprints. Equivalent tested code checkpoint:
  `512a824ae856b4425a4012e0116f363babcc4d4e`. See `evidence/T04-tested-payload.json` for
  SHA-256/Git-blob comparison, with only recorded CRLF/LF normalization.
- Code checkpoint was pushed and independently matched with fresh ls-remote.
  Final evidence/handoff follows it; final post-push HEAD is reported in the response.
- Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/4.
  **T04 feature synchronized; main integration pending owner review.**
  T01–T03 are integrated into main.
- Installed pair: `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`, build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`; hashes are in reports.

## Verified behavior and evidence

The functions-only `AudioFileForPhone.Helpers.ps1` is now required beside the
entry PS1. Current copy harnesses carry it byte-for-byte. The script validates
selected input directory/provider/root/readability, numeric ranges, output
resolution/access, tool identity/libmp3lame and explicit JPEG/PNG cover decoding
before optional metadata prompts or run creation. Input roots retain their full
spelling in errors; synthetic UNC root rejection happens before network access.
Extended/device paths are refused. Default 64 kbps, configured Music resolution,
formats, existing names, relative layout and metadata conversion are preserved.
The BAT is unchanged.

**A09–A11 pass.** Per shell: 35 child-process negatives, eight helper checks,
effective owned-TEMP input/output ACL denials and exact ACL restoration, ten
resolver cases, retained real-FFmpeg suite and seven required baseline companion
checks. All recorded source/synthetic hashes and owned cleanup checks pass.
Positive real JPEG/PNG validation and caller-local native exit-state checks pass.
Internal SkipWriteProbe creates nothing; public preview is still T12.

Normal preflight creates a missing requested parent and removes only its
exclusively reserved directory/CreateNew file probes. No ordinary Music test,
registry/persistent policy change, disk-exhaustion fixture, live UNC acceptance,
manual/phone evidence, CI, long-file test, release ZIP, tag or release was run.
T03's configured-Music smoke remains historical automated evidence.

Impossible-date and corrupt/mixed batch exit-0 gaps remain observed. Recursive
reparse/access policy, planned path budgets, production run reservation,
transactional publication and BAT/aggregate outcomes remain later tasks.
See `evidence/T04.md` for exact commands, review, limitations and linked reports.

## Canonical isolated commands

Both shells passed these with the installed tools; ordinary tests use TEMP only.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-baseline-ps7.json
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps51.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Preflight.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T04-preflight-ps7.json
```

Resolver commands are in TEST_STRATEGY.md/evidence/T04.md. Frozen T02
resolver-substitution helpers are historical, not canonical for current code.

## Authority and completion boundary

Normal in-scope edits/tests/commits/feature pushes/draft PR updates are authorized.
Main integration and exact release/tag/publication retain their gates. T04 awaits
owner integration. Overall project completion still requires the remaining tasks,
public download verification and final-main closure.
