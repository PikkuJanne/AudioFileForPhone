# Current project status

State: **T06 complete — bounded discovery and output exclusion verified.**
Last completed task: T06. Exact next task: T07.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T07 in a new thread: make date and filename allocation deterministic.**
Use NEXT_SESSION.md. A15, A16 and A17 passed on both required Windows shells.

## Environment and checkpoints

- Windows 11 Pro build 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`; branch `codex/v1-t06-safe-discovery`.
  Fetch/push origin: `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Owner merged T05 PR #5 at 23:50:14 UTC on 10 October 2026 into main
  `f5fad94d3ef31ec53972ad642b71c0a8d9f76e6f`. Local main was fast-forwarded
  to that independently advertised ref before T06. No agent merge occurred.
- Actual test base: `f5fad94d3ef31ec53972ad642b71c0a8d9f76e6f`; equivalent tested
  code checkpoint: `65bca07ab85bec00dd3f578d9ab38880e36e43e8`. Reports retain
  working hashes; `evidence/T06-tested-payload.json` verifies committed equivalence
  including only recorded CRLF/LF normalization. Code push matched fresh ls-remote.
  Final evidence/handoff follows it; final HEAD is reported in the response.
- Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/6.
  **T06 feature synchronized; main integration pending owner review.**
  T01–T05 are integrated into main.
- Installed tools: `C:\ffmpeg\bin\ffmpeg.exe` and `ffprobe.exe`, build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`; hashes are in reports.

## Verified behavior and evidence

Discovery uses canonical separator-aware OrdinalIgnoreCase boundaries and a
literal explicit walk. Complete sorted inputs precede destination probing,
metadata prompts, run/log creation and conversion. Empty/access-failed scans
create no run/log. Selected input/output reparse ancestry is rejected; descendant
directory/file reparse points are skipped with console and successful-run log
reasons. Planned output may be beneath input but cannot equal/contain it.
Selecting any part of a recognized generated tree is rejected.

New runs write a bounded self-matching CreateNew JSON marker. Legacy recognition
requires exact valid timestamp/rate root names, matching initial log fields with
absolute paths, and a direct mirrored input-leaf directory. Long logs use a
bounded prefix; arbitrary prefix names and malformed/mismatched identity remain
eligible. Reparse identity files are not followed. Read/access errors abort;
identity grants exclusion only, never deletion/reclamation authority. Moved/copied
runs retaining old absolute identity remain unrecognized. Existing planned roots
are refused; exclusive concurrent reservation remains T08. Snapshots do not lock
source paths against later external replacement.

**A15–A17 pass.** Per shell: eight focused groups, deterministic 17-file/8-skip
snapshot, real loop/outside junctions and file reparse, selected reparse/generated
ancestry, legacy casing/malformed relative paths, owned ACL-denied subtree,
two repeated short real-FFmpeg runs with 64 kbps/title/layout/full decode.
File symlinks lack host privilege (Win32 1314); actual inert custom file reparse
coverage passed and is reported separately. Final reports are PS51 `-final` and
PS7 `-final2`. Retained FFmpeg suite/seven required companions, 35 preflight
negatives/eight helpers and ten resolvers pass per shell with `-verified` labels.
Final source/fixture hashes, exact ACL restoration and owned TEMP cleanup pass.
Failed/intermediate reports remain separate; see `evidence/T06.md`.

Functions-only helpers, shared bounded native/probe APIs, 64 kbps CBR default,
formats, Music/OutputParent resolution, names/layout, metadata and BAT remain.
Calendar/NFC/collision/path allocation remains T07; reservation, transactional
output and aggregate/BAT outcomes remain T08–T11. No ordinary Music traversal,
registry/policy/privilege changes, downloads, manual/phone/long-audio/cancellation,
CI, release ZIP, tag or release occurred.

## Canonical isolated commands

Both shells passed these with the installed tools; ordinary tests use TEMP only.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps51-final.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Test-Discovery.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-discovery-ps7-final2.json
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-baseline-ps51-verified.json
pwsh -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\Invoke-IsolatedBaseline.ps1 -FfmpegPath C:\ffmpeg\bin\ffmpeg.exe -FfprobePath C:\ffmpeg\bin\ffprobe.exe -EvidencePath .\docs\codex-v1\evidence\T06-baseline-ps7-verified.json
```

Use fresh T06 labels to rerun and preserve historical reports. Discovery uses
CreateNew. Final preflight/resolver commands are in `evidence/T06.md`.
Current optional `Test-OutputParent.ps1 -DefaultSmoke` stops before any setup:
its pre-reserved Music run conflicts with production's no-reuse check. T08 must
adapt that ownership scheme. Ordinary TEMP resolver mode is current; T03 smoke
and T05 native reports describe their historical payloads. Frozen T02 substitution
helpers are not canonical current harnesses.

## Authority and completion boundary

Normal in-scope edits/tests/commits/feature pushes/draft PR updates are authorized.
Main integration and exact release/tag/publication retain their gates. T06 awaits
owner integration. Project completion still requires remaining tasks, public
download verification and final-main closure.
