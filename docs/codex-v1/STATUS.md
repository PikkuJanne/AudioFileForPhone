# Current project status

State: **T09 complete — staged validation and no-overwrite publication verified.**
Last completed task: T09. Exact next task: T10.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T10: unify script and BAT result reporting.** Use NEXT_SESSION.md.
A24–A26 pass on PS5.1/PS7; aggregate result/exit policy remains a separate gate.

## Environment and checkpoints

- Windows 11 Pro 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout C:\projects\AudioFileForPhone-main, branch codex/v1-t09-transactional-output.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T08 PR #8 at 05:17:22 UTC on 11 October 2026 into main
  347b8656068b5e26b45410b830025de51000659f. Normal fetch and independently
  advertised refs verified it; clean local main fast-forwarded before T09.
- Actual test base is that merge. Reviewed equivalent code checkpoint:
  fcce28736081d799b29f4594b56bebafbad1a9f7. Raw reports retain base/working
  hashes; evidence/T09-tested-payload.json proves 13 runtime/test fingerprints
  against committed blobs with only independently proven Git CRLF/LF normalization.
  Code push matches the fresh advertised feature ref. Evidence/handoff follows
  in a docs-only checkpoint; final HEAD/live comparison is in the PR/response.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/9.
  **T09 feature synchronized; main integration pending owner review.**
  T01–T08 are integrated. No GitHub CI checks are configured/claimed.
- Existing C:\ffmpeg\bin pair, build
  2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev.
  Tool hashes/versions remain in reports; no downloads/settings change.

## Verified behavior and evidence

Each file encodes only to a CreateNew sibling .AudioFileForPhone-<32 hex>.partial
with explicit MP3 muxer. A retained no-delete handle and volume/file-index identity
guard current ownership. Validation requires nonzero MP3, one selected-rate MP3
audio stream, expected optional JPEG and finite positive source/header/decoded
durations within fixed 0.35 s. Missing/invalid source duration fails before staging.
Full output audio decode uses sample-count timestamps in the null muxer, catches
physical corruption/truncation despite plausible headers and changes no output DSP.
It adds a read/decode pass per file; long-file performance is unmeasured.

Only validated output reaches no-overwrite File.Move. Concurrent final destinations
preserve bytes and fail that file. Cleanup targets only its current matching partial
after process use; unproved ownership/child exit retains visible incomplete residue
and a diagnostic. Postpublication log error explicitly reports the actual mapping,
stops with exit 1 and preserves the completed output without double counting.

Eighteen final reports pass under both shells: 27 focused groups each, 61 decoded
real conversions plus three incompatible requested-rate rejections, max source/
header/decode delta 0.066125 s; retained FFmpeg/seven companions, preflight 35/eight
helpers, discovery eight, naming 11/19 decoded outputs, reservation 13, native 35,
resolver ten and configured-Music synthetic smoke. Source/fixture/sentinel hashes,
byte-identical runtime copies, owned child disposal, applicable original ACL
restoration and exact owned cleanup pass. Sequential native handles stay
668 to 668 and 576 to 576 with allowance 16 unchanged. Independent runtime/harness
review has no remaining blocker.

Default 64 kbps CBR, supported MP3/M4A/OGG inputs, script/BAT entry points, Music
destination, recursive layout, date-first names and metadata remain. Incompatible
8 kbps / 48 kHz combinations observed at 32 kbps fail selected-rate validation;
no forced sample rate is added. T08 exclusive roots/logs and T07 budgets remain.

Music smoke inspects only the exact direct root returned by a successful controlled
unmodified child. Runtime token/scope and CreateNew test marker, nonreparse ancestry
and exact synthetic inventory gate cleanup of only that run. 64 kbps/full decode/
title/source and exact Music/TEMP cleanup pass. Ordinary tests use owned TEMP;
no ordinary Music enumeration or Music ACL change.

## Preserved limitations

27 T09 raw attempts are retained: 21 pass/six fail; only the 18 manifest reports
establish final-payload equivalence. Initial baseline source changes, incompatible
rate fixtures and PS5.1 diagnostic wrapping/driver exit forwarding are recorded
in evidence/T09.md. Every attempt cleaned its exact owned scope. The two first
baseline reports retain source_unchanged=false after a concurrent refinement.
Attempt4 OS-generated diagnostic identity values alone are redacted with a note.
No test threshold/failure gate was waived.

T07's initial naming attempt still has unverified cleanup and unknown possible
synthetic machine-TEMP residue. Its exact leaf was unrecorded and parent enumeration
denied. No broad recovery/ACL/settings change was attempted; later exact cleanup
does not retroactively prove that attempt cleaned.

The brief identity-check-to-move/delete interval after guard release does not claim
hostile continuously replacing writer isolation. No full-disk experiment, long-audio/
phone/manual, source-replacement, cancellation, CI or release acceptance is claimed.
T06 file-symlink privilege limitation remains distinct from file-reparse coverage.
Project/release remain incomplete; later gates and release runbook remain required.

## Commands and authority

Exact commands/report labels/results: evidence/T09.md and TEST_STRATEGY.md.
Use fresh labels; never overwrite historical JSON. Tests run on this active Windows
machine with short synthetic owned fixtures. Owner review remains required for main.
Feature pushes are not merge, visibility/protection/history or release authority.
No tag/release was created. Publication requires exact reviewed commit/assets under
AUTHORITY.md and RELEASE_RUNBOOK.md, independent public download and final main closure.
