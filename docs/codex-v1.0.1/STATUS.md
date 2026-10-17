S04 reopened for a bounded compatibility correction: an absolute PATH entry must remain eligible when it equals CWD. Prior completed evidence below belongs to f1a7b17/a6e70d4; corrected runtime verification is IN_PROGRESS. Resume only S04 until its refreshed checkpoint passes. S05 remains NOT_STARTED.

# Status

Project IN_PROGRESS. S01/S02/S03/S04 are COMPLETED. S04-A1/A2/A3 pass on the
available Windows 11 client. Next eligible: S05 - Add first-run setup and manual
recovery, in a new thread. S05 and later remain NOT_STARTED.

FfmpegDirectory and ConfigPath are frozen public selection options. Resolution
uses explicit -> saved -> complete app-local pair -> absolute PATH directories.
Invalid explicit/saved choices and incomplete local pairs fail visibly.
Save-AudioToolSelection is the only deliberate persistence API: bounded schema1
UTF8 config, strict parsing, atomic write and verbatim preservation of unrelated
JSON. Conversion/preview never save; preview does not read config. No setup UI,
download, persistent PATH change or new runtime dependency was added.

Windows 11 Pro 26H2 build 26300.9711 x64, PS5.1 5.1.26100.9711 and PS7 7.6.5:
14 focused cases each pass on source f1a7b17e3f9a1074059cd4d2de424d90adad0a78.
Real explicit/saved fresh-process conversions succeed on empty PATH with
independently probed 64 kbps MP3, preserved metadata and full decode. Schema,
stale/corrupt/duplicate/strict JSON, read-only/locked persistence, exact unknown
lexemes and executable-discovery sentinels pass. Retained isolation/baseline,
pure contracts, transactions, cancellation, cleanup, preview, help, captured
regressions, deadlines and native-resource tests pass in both shells.
All final local runs inherit CP65001 and preserve source/owned fixture hashes.

Source push CI 39050312230 and associated PR CI 39050314938 pass all four jobs.
Downloaded artifacts prove 14 focused cases plus every retained CI family.
Preparation fixture failures and their replacements are recorded honestly in
evidence/S04.json and evidence/S04-HANDOVER.md. Raw reports remain outside Git.

Feature source f1a7b17 is pushed/live-equal. The final containing docs checkpoint
receives fresh live/exact-head CI verification in the final response, avoiding
a self-containing SHA. Main remains 28f53b10529495754273d55654c7b29e78848c83;
PR #29 stays draft/unmerged. Main integration is NOT_INTEGRATED under S14 reviewed
policy and existing owner-approval default. No owner action is needed for S04.

Runtime remains 1.0.0; fixed eventual public release is v1.0.1. No candidate/ZIP
is frozen; publication is PENDING_S17, only from separately authorized S16 exact
source/assets. Published v1.0.0 and artwork are preserved. Windows 10, another
local real tool build, exact package/kit and new phone evidence remain future
acceptance work. S03 deadlines, cancellation/release safeguards and unlimited
normal encode/decode runtime remain verified.

## Preserved S03 checkpoint

# S03 status at entry

Project IN_PROGRESS. S01/S02/S03 are COMPLETED. S03-A1/A2/A3 pass on the
available Windows 11 client. Next eligible step is S04 - Implement explicit and
remembered tool selection, in a new thread. S04 and later remain NOT_STARTED.

Short operations now carry deadlines and distinct Timeout/Cancelled results.
Version/capability defaults are 15 seconds; media probes 60 seconds, publicly overridable with
ProbeTimeoutSeconds for source/output probes. Pipe completion after exit has a
separate 5-second default; teardown is bounded. Encoding/full decode retain unlimited
normal runtime. Only the retained owned child is terminated. Missing EOF/release
proof retains the exact .partial; publication and source safeguards remain.

Windows 11 Pro 26H2 build 26300.9711 x64, PS5.1 5.1.26100.9711 and PS7 7.6.5:
focused final3 passes 15 cases each under inherited UTF8 CP65001. Real paced 2-second
encode/decode exceed the 1-second test startup bound. Retained suites pass per shell:
legacy baseline 0 plus 7 required characterizations/3 observations, 31 pure
contracts, 27 transaction, 9 controlled cancellation, 181 cleanup, 7 help and 35
native cases; S02 characterization remains 12 cases. Source/synthetic hashes,
owned cleanup and native resource release pass. Raw reports remain outside Git.

Preparation 0d2d8ff CI correctly failed its stale help parameter expectation.
709370a adds the authorized parameter to that test; 9b30f96 adjusts only cold
fixture timing and adds readiness proof. Runtime bytes are unchanged. Push CI
39048368905 and associated PR
CI 39048372292 pass both shells; downloaded reports prove all 15 new cases and
every retained CI family executed. Initial CP437 outer-host attempts are invalid
for acceptance, preserved and replaced by CP65001 runs. See evidence/S03.json
and evidence/S03-HANDOVER.md for commands, digests, caveats and full handover.

Feature source 9b30f96 is pushed/live-equal, main remains
28f53b10529495754273d55654c7b29e78848c83, and draft PR #29 is unmerged.
The final containing docs checkpoint gets fresh live/exact-head CI observation
in the session response, avoiding a self-containing SHA. Main integration stays
NOT_INTEGRATED under S14 reviewed policy and existing owner-approval default.

Runtime remains 1.0.0; the fixed eventual public release is v1.0.1. No candidate
is frozen and publication is PENDING_S17, solely from separately authorized
S16 exact source/assets. Published v1.0.0 and artwork are preserved. Windows 10,
another local FFmpeg build, exact package/kit and new phone observations remain
future acceptance evidence. No owner action is needed for S03.

## Preserved S02 checkpoint

The prior status is preserved below as historical context; active routing is above.

### S02 status at entry

Project IN_PROGRESS. S01 and S02 are COMPLETED. All S02 acceptance criteria pass.
Next eligible step: S03 - Add bounded short-operation execution, in a new thread.
S03 and later steps remain NOT_STARTED. No runtime behavior changed in S02.

Actual Windows 11 Pro 26H2 build 26300.9711 x64, PS5.1 5.1.26100.9711 and PS7
7.6.5, local FFmpeg/ffprobe 2026-10-08-git-ec420ba161 essentials. Each shell's
focused characterization passes 12 cases: two missing-tool failures, four exact
64 kbps controls, six late bitrate rejection reproductions. Mono/stereo outcomes:
48 kHz/8 kbps -> 32 kbps; 48 kHz/144 kbps -> 128 kbps; 8 kHz/192 kbps -> 64 kbps.
The application rejects these six clamped results with exit 2, no final MP3 and
no partial residue. These are captured regressions, not compatibility fixes.

Both retained real-FFmpeg baseline suites pass under both shells (legacy exit 0;
seven required characterization checks and three separate observations each).
Both isolation validations and all 31 pure CI contracts per shell pass. Source/
config hashes, byte-identical application copies and exact owned TEMP cleanup
pass. Inherited UTF-8 CP65001 and historical T-prefixed report contracts remain.
Raw retained reports are outside Git; S02.json binds their digests and summaries.
The existing CI runner adds the focused family without replacing old suites.

Stale saved-selection fixture and explicit external selection remain PENDING_API,
not application failures or production passes. Windows 10, another local FFmpeg
build, full advertised matrix, exact candidate/kit and new phone evidence remain
future requirements. No owner diagnostic, ordinary Music or personal media scan.

Runtime remains 1.0.0, unchanged from main 28f53b10529495754273d55654c7b29e78848c83;
the fixed eventual public release is v1.0.1. S16 exact-byte handover authorizes only
separately started S17 publication. No candidate is frozen and no release/tag write.

Feature branch codex/audiofileforphone-v1.0.1 and draft PR #29 remain separate from
main integration, deferred to S14 ordinary reviewed policy with owner approval by
default. At entry, local/live feature 888b4f12da31af417b4f03c050147440fe0cf27c and
main 28f53b10529495754273d55654c7b29e78848c83 match; exact checkpoint CI passes.
Preparation 76339f97211868b3bd23bb1557cc91469d287270 is pushed, clean/live-equal
under both shells; exact-head push CI39045431885 and associated PR CI39045437165
pass all four jobs. Downloaded CI reports verify all retained families plus 12
focused cases per job; PR checkout is integration ac3eed99df04d021a8d7ee60d7ab230c4e14b6cf,
separate from the exact feature SHA used by push CI. The final docs-only record's
live equality and CI are observed after push in the session response, avoiding a
self-containing SHA. See evidence/S02.json and evidence/S02-HANDOVER.md.
