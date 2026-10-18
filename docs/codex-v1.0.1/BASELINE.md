# Baseline and evidence ledger

Snapshot collected 17 October 2026; refresh live refs at S01.

## Repository state read from GitHub

- Repository: PikkuJanne/AudioFileForPhone; normal branch: main.
- Main observed: 28f53b10529495754273d55654c7b29e78848c83 (Icon and poster).
- Latest published release observed: v1.0.0, published 12 October 2026.
- Release source: 2092a405c1d06eca336e771a0ed5d1881acd015a.
- Published runtime ZIP SHA256:
  8fe8ac6752800f54dd58a7b454924ee5aa0b9b7153aa31457312ba3e1b2103cf.
- Release excludes FFmpeg/ffprobe and reports Windows 11 acceptance. Do not infer
  Windows 10 acceptance or silently migrate old evidence to the new package.

Fresh source identities observed in the owner's diagnostic:

| File | Git blob | SHA256 |
|---|---|---|
| AudioFileForPhone.ps1 | d6bcdbdb3a4a180e4e9ef142e601c28cb4e40d49 | c44462d0746cbacfc6f37ae7fe98780bbf196cc99d48f66e066de0508f4545ec |
| AudioFileForPhone.Helpers.ps1 | b59cbea5497f428b4b063929f06b924fc9e4424c | d5e9f03a69f084a148245a36567e7d6460363624c229301f8a807f07d9a5ff7c |
| AudioFileForPhone.bat | 8bec7664cca0b27a484023daeddd4fab46294805 | 03e7489dba12aae68f3c47e1364ad9ff15cc17dc8ed773d9e4cb2aeec264d7d0 |

## Owner-machine observations (supplied diagnostic, not fresh execution here)

Windows 10 Home 22H2, build 19045.7417, x64. Windows PowerShell 5.1.19041.7417 and
Microsoft Store PowerShell 7.6.7 are present. The app is in a source-archive-style
project directory. Diagnostic identities exactly matched the three tagged runtime
files; that did not independently verify the downloaded release ZIP.

Both ffmpeg.exe and ffprobe.exe exist under C:\ffmpeg\bin, outside application-local
and Process/User/Machine PATH. Both no-profile hosts reproduced NOT_FOUND. The
initial app scanned 30 M4A files, then stopped before conversion with exit 1,
converted=0, not_processed=30 and no persistent application log.

The diagnostic did not run the tools. A later owner-run check did run them:
both version commands and libmp3lame inspection passed. A temporary process PATH
allowed the unchanged application to reach optional metadata prompts for both a
one-file test folder and the 30-file folder. The reported build identity was:
2026-10-15-git-afead44165-essentials_build-www.gyan.dev.

**No final conversion summary or new phone-playback result has been supplied.**
Do not ask the owner to repeat the report, version commands or discovery tests.
Carry the unproved conversion forward to automated candidate acceptance.

## Previous review findings to verify against live code

- Get-ToolPath searches beside the script, then Get-Command.
- BAT requests interactive mode, prefers a found pwsh, and otherwise uses PS5.1.
- Read-YesNo treats Enter as No; the latest prompt is normal input, not an exception.
- The first tool version/capability calls share an unbounded native waiting helper.
- Output transactions protect partial files and fully decode MP3 before promotion.
- Exact bitrate validation follows encoding without an explicit sample-rate plan.
- A fixed 0.35-second duration bound and conservative reparse restrictions exist.
- Existing tests are substantial; retain and extend them, not another wholesale suite.

A previous assistant reported Linux FFmpeg 7.1.5 synthetic experiments showing
48 kHz/8 kbps -> 32 kbps, 48 kHz/144 kbps -> 128 kbps and 8 kHz/192 kbps -> 64 kbps.
Treat these as **reported reproduction leads**, not independently verified bundle
results or a proven failure on the owner's newer Windows FFmpeg build. S02/S09
must reproduce and record actual behavior on the Windows test builds.

## Privacy

This ledger deliberately omits the owner's username, private source names, complete
PATH inventory and raw diagnostics. Test paths should be generated. The real
collection is selected locally in S15, never checked into Git or uploaded.

## Source basis

The conversation diagnostic is AudioFileForPhone-diagnostics-20261017-140513-d1a1a11b.txt
(environment lines 9-16; identities 18-30; PATH inventory 83-154; tools 159-174;
PS7 189-196; limits 199-205). The later console update is owner-supplied.
Repository/API and external primary references are listed in SOURCES.md.
