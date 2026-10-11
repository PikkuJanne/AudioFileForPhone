# Current project status

State: **T08 complete — exclusive run reservation and M1 regression verified.**
Last completed task: T08. Exact next task: T09.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T09: stage, validate and safely publish each output.** Use NEXT_SESSION.md.
A22/A23 pass under PS5.1 and PS7; per-file publication remains a separate gate.

## Environment and checkpoints

- Windows 11 Pro 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout `C:\projects\AudioFileForPhone-main`, branch `codex/v1-t08-exclusive-runs`.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T07 PR #7 at 01:04:14 UTC on 11 October 2026 into main
  `e1ea2a95a5a9b7461d69101b6a111f26b51abbf6`. Local main was fast-forwarded
  to that independently advertised ref before T08. No agent merge occurred.
- Actual test base is that main commit. Reviewed equivalent code checkpoint:
  `3b6c4164c6e4dd4b58f0be074c17f6fb854b41be`. Final reports retain actual base
  and working hashes; `evidence/T08-tested-payload.json` verifies 12 runtime/test
  fingerprints against committed blobs (only recorded Git CRLF/LF normalization).
  Code push matched fresh advertised ref. Evidence/handoff follows in a docs-only
  checkpoint; final HEAD/live comparison is in the response/PR, not a self-reference.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/8.
  **T08 feature synchronized; main integration pending owner review.** T01–T07
  are integrated. No GitHub CI checks are configured/claimed.
- Existing C:\ffmpeg\bin pair, build 2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev.
  Tool hashes/versions remain in reports; no downloads/settings change.

## Verified behavior and evidence

Readable invariant timestamp roots acquire numeric _2/_3/... suffixes on collision.
CreateDirectoryW establishes exclusive ownership; only Win32 occupied errors 80/183
retry, bounded to 1000 default attempts. Marker/log use CreateNew and the log header
appends after a UTF-8 BOM. The marker records fresh token and exact cleanup scope.
No preexisting root is reused and production never recursively reclaims setup
failures: their exact new scope/token stays visible in the diagnostic.

Provisional free selection is read-only and keeps occupied unmarked source audio
visible during discovery. Each exact suffix revalidates the complete pure batch
plan before creation. Raw output-parent checks precede provider normalization,
retain relative navigation/FileSystem PSDrive syntax and reject invalid components.
Existing T07 date/NFC/scalar/order/name/path budgets and conversion defaults remain.
T09 must use the fixed `.AudioFileForPhone-<32 hex>.partial` working name and an
explicit MP3 muxer. Output publication/validation is not yet transactional.

Sixteen current reports in evidence/T08.md and the manifest pass on both shells:
13 focused groups with four same-candidate barrier children obtaining counters 3/4/5/6,
two real-entry relative/PSDrive conversions and immutable collision sentinels;
retained FFmpeg/seven companions, preflight 35/eight helpers, discovery 8, naming 11
with 19 decoded outputs, native 35, resolver 10 and configured-Music default smoke.
Sources/fixtures, byte-identical runtime copies, owned ACL restoration, child disposal
and scoped cleanup pass. Final sequential native handles stayed 667->667 and 575->575
with threshold 16 unchanged. Independent review has no remaining blocking finding.

The Music smoke inspects only one exact direct root returned after a successful
controlled unmodified child. Runtime token/scope and a CreateNew test marker,
nonreparse ancestry and exact synthetic inventory gate cleanup of only that root.
It verifies 64 kbps/full decode/title/source and exact Music/TEMP cleanup. Ordinary
resolver/tests use owned TEMP; no ordinary Music enumeration or Music ACL change.

## Preserved limitations

Sixty T08 attempt reports are retained: 52 pass and 8 fail. Only the 16 current
reports establish final-payload equivalence. Initial harness failures, old native
fixture path 261, provisional guard/provider errors and one parallel PS7 handle-growth
observation are documented in evidence/T08.md. No path/handle threshold was waived;
failed diagnostic OS user/computer names alone were redacted. Every T08 attempt
verified its owned cleanup; intermediate passes do not substitute for final hashes.

T07's initial naming attempt still has unverified cleanup and an unknown possible
synthetic machine-TEMP residue. Its leaf was not recorded and parent enumeration
is denied. No broad recovery or ACL/settings change was attempted. Later exact
owned cleanup does not retroactively prove that attempt cleaned.

No phone/manual playback, long-audio, cancellation, source-replacement, CI or release
result is claimed. No universal Android/MTP path limit is claimed. T06 file-symlink
privilege limitation remains distinct from performed file-reparse coverage. Project
and release remain incomplete; transaction/cancellation/later acceptance gates stand.

## Commands and authority

Exact final commands and report labels: evidence/T08.md and TEST_STRATEGY.md.
Use fresh T08 or next-task labels; never overwrite historical reports. All tests
run on this active Windows machine using short synthetic owned fixtures.

Owner review remains required for main integration. Feature pushes are not merge,
visibility/protection/history or release authority. No tag/release was created.
Publication requires exact reviewed commit/assets under AUTHORITY.md and the
RELEASE_RUNBOOK.md, then independent public download and final main closure.
