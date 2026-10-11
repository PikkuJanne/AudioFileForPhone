# Current project status

State: **T07 complete — deterministic date, Unicode and path allocation verified.**
Last completed task: T07. Exact next task: T08.
Required improvements: 1–15. Optional O01: deferred.

## Next suggested step

**Start T08 in a new thread: reserve unique run roots and logs exclusively.**
Use NEXT_SESSION.md. A18–A21 pass on both required Windows shells.

## Environment and checkpoints

- Windows 11 Pro26300.9457; PS5.1 5.1.26100.9444; PS7 7.6.5.
- Checkout: `C:\projects\AudioFileForPhone-main`; branch `codex/v1-t07-naming-planner`.
  Origin fetch/push: `https://github.com/PikkuJanne/AudioFileForPhone.git`.
- Owner merged T06 PR #6 at 00:25:18 UTC on 11 October 2026 into main
  `8599dfd9706d99119d4a38fb511968529e914246`. Local main was fast-forwarded
  to that independently advertised ref before T07. No agent merge occurred.
- Actual test base: `8599dfd9706d99119d4a38fb511968529e914246`; equivalent
  reviewed code checkpoint: `e99f81ca3eb2c24102882e5723c52c236105450c`.
  Reports retain actual base/working hashes. `evidence/T07-tested-payload.json`
  verifies committed equivalence (only recorded Git CRLF/LF normalization).
  Code push matched fresh ls-remote. Final evidence/handoff follows it; final
  HEAD/live ref is reported in the response/PR without a self-referential commit.
- Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/7.
  **T07 feature synchronized; main integration pending owner review.**
  T01–T06 are integrated into main. No GitHub CI checks are configured/claimed.
- Installed `C:\ffmpeg\bin\ffmpeg.exe`/`ffprobe.exe`, build
  `2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev`; report hashes retained.

## Verified behavior and evidence

Conversion consumes an all-or-nothing pure batch naming plan before tools, write
probes, prompts or run creation. Leading dates use real invariant Gregorian parsing;
invalid dates use LastWriteTime and retain the entire original basename as title
input. Titles normalize to NFC before/after whitelist filtering. Unicode L/Nd
scalars, whitespace, hyphen/underscore remain; noncomposing marks are removed.
Truncation protects whole scalars, not arbitrary grapheme clusters. Empty title
becomes Episode. MaxBaseLength 24–180 includes complete date/separator/title/suffix,
excludes .mp3, and measures UTF-16 units. Every suffix recomputes from full title.

Source order is OrdinalIgnoreCase then Ordinal. Destinations collide under
OrdinalIgnoreCase; canonical duplicate sources reject, case-only files are retained.
Preserved folders are validated before canonicalization and never renamed.
Complete destination/future working files must be <260 units, created directories
<248, components <=255. Marker/log paths are budgeted too. T09 must honor the
fixed `.AudioFileForPhone-<32 hex>.partial` working name. T07 creates no working
file. Existing unexpected planned targets fail; FFmpeg `-n` also refuses overwrite.

Current passing evidence: [T07.md](evidence/T07.md) and ten reports listed there/
in `T07-tested-payload.json`. Per shell: 11 focused groups with 28 date/culture
combinations, scalar/NFC/Hangul/counter cases, shuffled 12-source mappings, zero
partial-plan emission, actual native dir 247/248/file 259/260, long/problematic
folder rejection and 19 fully decoded real MP3 outputs (12 collisions and actual
180-unit basename/path 253). Retained FFmpeg/seven required companions, discovery 8,
preflight 35/eight helpers and resolver 10 pass. Final source/fixture hashes, exact
ACL restoration and owned cleanup pass. Fixture paths were shortened to fit the
production budgets; no limit was waived. Independent runtime/harness review has
no remaining blocking finding.

## Preserved limitations

The initial failed PS5.1 naming report has cleanup=false. Native entries were
removed, but provider recursive cleanup failed; its short machine-TEMP root leaf
was not recorded and the parent denies enumeration. An unknown possible synthetic
residue remains unverified. No broad cleanup or ACL/settings change was attempted.
Later reports record recoverable ownership identity and verify checked .NET cleanup.
All earlier failed/intermediate reports are preserved and are not current passes.

No ordinary Music traversal, personal media, downloads/settings change, manual/
phone/long-audio/cancellation or release evidence. No universal Android/MTP limit
is claimed. T06 file-symlink privilege limitation remains distinct from performed
file-reparse coverage. Configured-Music smoke remains deferred before setup until
T08 adapts its historical pre-reserved-run ownership scheme; normal resolver mode
is TEMP-only and current. Concurrency reservation is T08; transaction/cancellation/
source-replacement policies remain later task gates. Project/release is incomplete.

## Verified commands

Exact current commands are in `evidence/T07.md` and TEST_STRATEGY.md. Rerun with
fresh T07 labels; never overwrite historical reports. Tests run on the active
Codex Windows machine, with existing installed tools and synthetic owned TEMP.
Do not run the historical T02 resolver-substitution helpers against the new runtime.

## Integration and release gates

Owner review is required for main integration. Feature pushes are not merge,
visibility/protection/history or release authority. No tag/release was created.
Release publication still requires the exact reviewed commit and assets under
AUTHORITY.md/RELEASE_RUNBOOK.md. Refresh live refs before the next task.
