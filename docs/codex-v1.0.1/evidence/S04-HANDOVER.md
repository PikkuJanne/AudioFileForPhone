# S04 handover - COMPLETED

## Outcome

S04-A1/A2/A3 pass on the available Windows 11 client under both shells.
Explicit and deliberately remembered selection is implemented and verified.
Source 68e14aded3c2e80493512af8cc10d5abe34c4c19 is pushed/live-equal;
exact-source push and associated PR CI pass. Final containing documentation
HEAD/live equality and exact-head CI are observed after push in the final
response and must be refreshed next entry. S05 is NOT_STARTED.
The public release is not complete.

## Changes

AudioFileForPhone.ps1 adds FfmpegDirectory and ConfigPath. Only actually supplied
explicit directory parameters are forwarded. Preview bypasses resolution/config;
conversion validates once before output or optional prompts and never saves.
Console/log/manifest disclose discovery origin.

The functions-only helper shares Get-AudioConfigPath, Read-AudioToolConfig,
Resolve-AudioToolSelection and deliberate Save-AudioToolSelection. Precedence:
explicit -> saved -> complete pair directly beside script -> PATH.
Invalid explicit/saved choices and incomplete local pairs stop with guidance;
no invisible fallback or mixed local/PATH pair. Exact regular EXEs under
absolute PATH entries are supported, including separate installed directories.
Implicit CWD lookup, relative/blank PATH entries and aliases/functions/wrappers
are excluded. Absolute PATH entries remain eligible when equal to either working
directory, preserving legacy launches from a configured bin. Differing build IDs warn. Bounded
version/libmp3lame validation is reused; PE headers disclose known architecture.

Config defaults to Windows LocalApplicationData/AudioFileForPhone/config.json.
ConfigPath is a documented portable/user override. Only deliberately invoked
Save-AudioToolSelection writes UTF8 schema1 with a 64 KiB bound. Strict parsing
rejects corrupt/unknown schemas, invalid types, ambiguous duplicate/case/escaped
keys, comments and trailing commas. Atomic create/replace uses an exclusive
temporary lock, guarded original bytes, identity/hash checks, flush and owned
temporary cleanup. Replacing only the root directory string token preserves
unrelated JSON dates, precision, escaping, nested fields, whitespace and BOM.
Read-only or locked storage fails without silently replacing the saved choice.

Public help/README/SUPPORT/SECURITY document selection and manual recovery.
No setup UI/entry point, downloads, privileges, new dependency or persistent
environment mutation. BAT/artwork, 64 kbps default, supported formats, Music
default, layout/date-first names/metadata, source-read-only behavior,
transactional full-decode publication and 0/1/2/130 outcomes remain.
S03 operation deadlines, cancellation/pipe release and unlimited normal
encode/decode runtime are retained.

Added 14-case focused test family and additive CI family, keeping native last.
Retained actual-entry launches use owned absent ConfigPath. Exact public help
example text is unchanged through its existing audited loader. No old
assertion or historical report-path contract was removed.

## Verification

Commands run from C:\projects\AudioFileForPhone-main. Resolve shells via
Get-Command powershell.exe / pwsh.exe. Owned children use -NoLogo -NoProfile
-NonInteractive -ExecutionPolicy RemoteSigned, inherited console CP65001 and
child-only PSModulePath removal. S04.json accepted_local_reports contains every
exact invocation, source/runtime identity and report digest. Create-new reports
use original active/historical paths, then literal moves into marked private
TEMP records. No ordinary Music, owner config or personal media.

| Check | Exact command / report | Environment and source | Observed result | Evidence |
|---|---|---|---|---|
| Selection | tests/Test-ToolSelection.ps1 with explicit C:/ffmpeg/bin tools; S04-toolselection-ps51/ps7-final2.json | Windows 11 Pro 26H2 26300.9711 x64; PS5.1 5.1.26100.9711 / PS7 7.6.5; 68e14ad | 14 each, including absolute PATH=CWD compatibility, blank/relative decoy rejection, real explicit/saved empty-PATH conversion and independent 64 kbps full decode | S04.json accepted_local_reports |
| Isolation | tests/Invoke-IsolatedBaseline.ps1 -ValidateOnly; T17-s04-isolation-ps51/ps7-final8.json | Same corrected source/client | PASS byte copies/owned cleanup | S04.json |
| Baseline | Same without ValidateOnly and explicit tools; T17-s04-baseline-ps51/ps7-final8.json | Same corrected source; local 2026-10-08-git-ec420ba161 essentials | PASS legacy 0; 7 required characterizations/3 observations each | S04.json |
| Pure contracts | tests/ci/Test-CiContracts.ps1; T17-unit-ps51/ps7-final8.json | Same corrected source/client | 31 each | S04.json |
| Help/examples | tests/Test-HelpVersion.ps1; T17-help-ps51/ps7-final8.json | Same corrected source; five exact examples/12 parameters | 7 each | S04.json |
| Source CI | gh run view/download 39051385250 and 39051387556 | Exact push 68e14ad; PR integration checkout recorded separately; supplementary hosted Windows Server | All 4 jobs; artifacts prove 14 new cases plus every retained family | S04.json |
| Review | Independent runtime/test/path audits; git -c core.whitespace=cr-at-eol diff --check fc31a86..HEAD | Actual intended scope, source safety and privacy | No remaining blocking finding | S04.json;D23-D28 |

The earlier full local run on f1a7b17 is preserved separately under
S04.json prior_validation: 24 reports, including 27 transaction, 9 controlled
cancellation, 181 cleanup, 8 preview, 12 characterization, 15 deadline and 35
native/resource cases per shell, plus baseline/unit/help/selection. These are
prior-source results, not a claim that every local suite reran on 68e14ad.
Corrected-source local verification targets the five-line PATH delta; full
exact-source CI reruns every retained CI family. D27 records why this final audit
reopened S04 before stopping. No S05 work was started.

Preparation attempt1 interpreted a BOM-less UTF8 driver as ANSI under PS5.1;
overlapping final harness edits also invalidated source stability. Attempts2/3
reached successful explicit conversion but EncodedCommand duplicated information
as CLIXML and overflowed the retained stderr cap, even with Text output requested.
The final BOM-marked UTF8 -File driver preserves Unicode and every cap/release
assertion. Failed reports remain private with public hashes/reasons. Uncommitted
attempt4 and committed final1 pass both shells; final2 repeats on corrected source. No safeguard
was disabled and failed harness attempts are not product passes.

Windows 10 22H2, another local real FFmpeg build, exact ZIP/kit and new phone
observations are NOT_RUN here and remain future gates. Mismatched PATH responders
are independently compiled synthetic fixtures, not another vendor-build pass.
Invalid EXE bytes exercise real Windows startup failure without claiming actual
missing-DLL/incompatible-hardware coverage. Server CI is supplementary.

## Git state (observe after checkpoint)

Origin https://github.com/PikkuJanne/AudioFileForPhone.git; active branch
codex/audiofileforphone-v1.0.1; OPEN draft PR #29:
https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
Entry local/live fc31a863809ebce595658472c35bdf3ab6d77052 was clean; entry
push 39048718023 and PR 39048721360 pass both shells.
Main local/live stays 28f53b10529495754273d55654c7b29e78848c83.

Source 68e14aded3c2e80493512af8cc10d5abe34c4c19 was normally pushed and
independently advertised by fresh ls-remote. Exact-source push 39051385250 and
PR 39051387556 pass. Final docs-only containing HEAD cannot contain its own SHA;
fresh clean/live equality, comparison time and exact-head CI are reported after
push in the final response. Refresh them next entry. No force/reset/clean, merge,
history/protection/visibility change, tag or release write.

Main integration: NOT_INTEGRATED under S14 ordinary reviewed policy and existing
owner-approval default. No frozen release source or ZIP exists. Runtime remains
1.0.0 until planned package work.

## Decisions, risks and blockers

D23-D28 record interfaces, deterministic pairs, bounded strict/lexically preserved
config and isolated evidence. Review found and corrected omitted-param binding
and read-before-guard issues before final verification. No S04 blocker remains.
Atomic replacement serializes cooperating saves and detects observed identity/
content changes; it does not promise serial isolation against an arbitrary
external editor racing the final check.

## Human action

None for S04. No repeated diagnostics, PATH edits, ordinary media scans, uploads
or manual developer matrix. Consolidated owner work remains S15.

## Next step and fully filled prompt

S05 - Add first-run setup and manual recovery is eligible, NOT_STARTED.
Start a separate thread using:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    RELEASE_TARGET.json, evidence/S04.json and evidence/S04-HANDOVER.md.
    Refresh actual local/live feature and main identities and exact-head CI.
    Verified source: 68e14aded3c2e80493512af8cc10d5abe34c4c19; refresh the later
    containing checkpoint recorded in the prior final response.
    Complete ONLY S05 - Add first-run setup and manual recovery.
    S01/S02/S03/S04 are complete; do not reset/reimport or restart them.
    Read tasks/S05.md and its referenced specs, plus specs/SYNC_AND_RELEASE.md.
    Available host: Windows 11 Pro 26H2 26300.9711 x64, PS5.1 5.1.26100.9711
    and PS7 7.6.5; FFmpeg/ffprobe C:\ffmpeg\bin.
    S04 freezes FfmpegDirectory/ConfigPath and shared resolver/save APIs.
    Retain inherited UTF8 CP65001, historical T-prefixed report contracts,
    owned ConfigPath isolation, S03 deadlines/cancellation/release safeguards
    and unlimited normal encode/decode runtime. Use isolated synthetic fixtures.
    Do not repeat owner diagnostics or scan ordinary Music/personal media.
    Preserve defaults, source safety, artwork and published v1.0.0.
    Keep main integration separate under existing owner-approval authority.
    Update evidence/state/status/next-session/decisions and full handover.
    Test/review/commit/push intended changes; verify fresh live equality and
    exact-commit CI. Give the filled next-thread prompt, then STOP.
    Do not start S06. Fixed deliverable: public v1.0.1. Only separately started
    S17 publishes S16's exact accepted source/assets.

## Stop

This thread ends after S04. Do not start S05 here.

## Fixed final deliverable

Public v1.0.1 is PENDING_S17. Only separately started S17 publishes S16 exact
accepted source/assets. No frozen candidate or publication authority is created
by S04. Published v1.0.0 tag/assets and artwork remain.
