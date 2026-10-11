# Current project status

State: **T10 complete — script and BAT result contracts verified.**
Last completed task: T10. Exact next task: T11.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T11: handle cancellation and crash leftovers safely.** Use NEXT_SESSION.md.
A27–A28 pass on PS5.1/PS7. Controlled cancellation remains a separate gate.

## Environment and checkpoints

- Windows 11 Pro 26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout C:\projects\AudioFileForPhone-main, branch codex/v1-t10-results.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T09 PR #9 at 07:01:10 UTC on 11 October 2026 into main
  d31f2deb76f2d0aa88e13fb5ca2e123c4f3d1cc6. Normal fetch and independently
  advertised refs matched it and T09 feature 84270ac61ab39614a4346cf5ff429e49b77ca779.
  Clean local main was fast-forwarded before creating the T10 branch.
- Actual test base is that merge. Reviewed equivalent code checkpoint:
  478c0a0c6a2935eb7271c9d28771a63455307599. Raw reports retain base/working hashes;
  evidence/T10-tested-payload.json independently proves 11 runtime/test fingerprints
  against committed blobs with only documented Git CRLF/LF normalization.
  Code push matches the fresh advertised feature ref. Evidence/handoff follows
  in a docs-only checkpoint; final HEAD/live comparison is in the PR/response.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/10.
  **T10 feature synchronized; main integration pending owner review.**
  T01–T09 are integrated. GitHub lists zero Actions workflows; no CI pass claimed.
- Existing C:\ffmpeg\bin pair, build
  2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev.
  Tool hashes/versions are retained in reports; no download or settings change.

## Verified behavior and evidence

Script exits 0 / Completed when every supported snapshot file succeeds; 2 /
CompletedWithFailures for a completed batch with file failures; 1 /
FailedBeforeConversion or Failed for preflight, empty scan, setup or fatal errors.
Native probe/transaction exceptions fail one file and independent valid files
continue. Results count once after the file boundary, with success only after
T09 publication. Log failure is fatal and preserves the original file outcome,
completed output and count. Progress display failure warns and continues.

Final summary reports total, processed, converted, failed, not_processed,
scan_excluded, unsupported, elapsed seconds and available output/log locations.
Exclusions count skipped entries/subtrees; unsupported files count only visited
ordinary files. A setup exception can retain a marker-only scope before the
reservation object returns; error reports exact scope/token and final fallback
messages do not imply that nothing was created. Production does not remove it.

BAT rejects zero/empty/multiple arguments, including empty second with a third;
keeps STA and DisableDelayedExpansion; captures child errorlevel immediately;
prints code-specific results and returns the same code after pause. Codes
0/1/2/130/37 and legal quoted input/script locations containing spaces, !, %, &,
^ and apostrophes are verified. Literal percent tests use one caller environment
substitution; direct caller percent expansion is separately observed. Prior caller
expansion, extra CALL passes and Explorer/manual forms are not guaranteed.

Twelve final reports pass on the final payload: script 13 groups and 14 independent
64 kbps probe/full-decode publications per shell; launcher 52 cmd cases per driver,
each exercising both actual shell branches; retained FFmpeg/seven companions;
transaction 27 groups/61 decoded conversions/three requested-rate rejects;
preflight 35/eight helpers; discovery eight. Source/fixture/sentinel hashes,
byte-identical copies, child disposal, applicable ACL/link restoration and exact
owned TEMP cleanup pass. Independent final runtime/harness review has no blocker.
No ordinary Music access or new native-resource/configured-Music claim.

T09 transactional invariants remain: CreateNew-owned nonfinal sibling partial;
retained no-delete handle/file identity through native use; nonempty expected MP3
streams/selected audio bitrate; finite positive source/probe/full-decode durations
within fixed 0.35 seconds; no-overwrite publication and exact current-owned cleanup.
Unknown child exit or changed identity retains visible incomplete residue and
reason. Source and completed output preservation, default 64 kbps CBR, supported
MP3/M4A/OGG, script/BAT, Music destination, layout, dates and metadata remain.

## Preserved limitations

32 T10 raw reports are retained: 26 pass/six fail; only the 12 manifest reports
establish final equivalence. Empty-argument caller transport, automatic $Input,
filename separator, multiline mapping matcher and exact preflight-prefix harness
failures are documented in evidence/T10.md. All attempts verify source preservation
and exact cleanup. Earlier passing payloads preceded reviewed timeout safeguards
or the reserved-setup reporting refinement; final selected reruns prove the final
bytes. No failed evidence, limits or assertions were waived.

T09's 27 attempts/18 final reports and privacy-only attempt4 redaction remain.
T07's initial naming cleanup still leaves unknown possible synthetic machine-TEMP
residue: exact leaf unrecorded, parent enumeration denied. No broad recovery/ACL
change was attempted; later exact cleanup does not prove that old attempt cleaned.

No cancellation, forced-close, phone/manual, source-replacement, full-disk,
long-file/performance, CI or release acceptance is claimed. Host parameter-binding
and forced termination can use host-specific nonzero codes. Code 130 is reserved
and only inert BAT forwarding is tested. T09's brief post-guard path-check interval
and T06 file-symlink privilege limitation remain. Full M2 suites are the T11 boundary
work; project/release remain incomplete and the release runbook still applies.

## Commands and authority

Exact commands/report labels/results: evidence/T10.md and TEST_STRATEGY.md.
Use fresh labels and short synthetic fixtures in exclusively owned TEMP; preserve
all historical reports. Tests ran on this active Windows machine under both shells.

Owner review remains required for main. Feature push is not merge, visibility,
protection/history or release authority. No tag/release was created. Publication
requires exact reviewed commit/assets under AUTHORITY.md and RELEASE_RUNBOOK.md,
independent public download and final main closure.
