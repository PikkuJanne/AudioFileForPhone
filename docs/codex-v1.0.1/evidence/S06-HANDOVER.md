# S06 handover - COMPLETED

## Outcome

S06 implements consent-based managed dependency setup on the existing PowerShell
tool. S06-A1, S06-A2 and S06-A3 passed on the available Windows 11 client in both
shells. Ten final targeted local reports passed, including actual pinned vendor
installs and fresh-process conversions. Exact-source push and PR CI passed all
four jobs; downloaded reports each contain 263 checks and 3 observations. S06 is
complete. S07 remains NOT_STARTED; this thread performs no S07 work.

Tested source is 69bce4ac129b7acc0d95b4d9f443e782efdd8763. The managed engine and
download manifest remain byte-identical to
70bd7525ecd7894d447275850a4ea95bbee240a1. Helpers changed later to retain pending
owned cancellation across the engine-result handoff and to print the no-download
message outside a wrapping error record. aceaa4d03276c674c8e90f2e67832529f9f35c7c
contains the earlier exact nested-manifest package-test correction. Broader
core62 reports are prior validation with their actual commits/file hashes, not
universal tests of the final helper. No owner observation or physical UI pass is
inferred. Public v1.0.1 remains pending.

## Changes

Setup-AudioFileForPhone.ps1 adds Download, Consent and ManagedRoot. Its existing
BAT remains a simple interactive entry. Interactive D displays the provider,
exact build, transfer bytes, destination, hash, license and source before asking
for Y. Unattended setup requires Download plus Consent. Remember remains a
separate deliberate choice. Conversion cannot grant download authority: its D
route prints the separate setup command and stops without loading the downloader.
Manual and existing-tool recovery remain available.

AudioFileForPhone.ManagedSetup.ps1 is a functions-only engine loaded by separate
setup. tools/ffmpeg-download.json pins the direct Gyan 9.0.2 essentials Windows
x64 ZIP at a versioned HTTPS URL. The artifact is 114768076 bytes and SHA256
60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba. The pin was
checked against the vendor's published checksum and its GitHub asset digest.
The reviewed bounds are 125829120 download bytes, 402653184 expanded bytes,
100 entries, 20 seconds for connection/headers and 300 seconds for the complete
transfer. Redirects remain HTTPS and confined to www.gyan.dev. No runtime latest
lookup or automatic update is introduced.

Integrity is checked under one read guard before archive processing or execution.
Independent EOCD/central-directory inspection bounds metadata before ZipArchive
entry allocation. Local and central names, sizes, compression, flags and CRC must
agree. ZIP64, descriptors, encryption, overlap, unsafe/linked paths, reserved
components, traversal, duplicates and case collisions are refused. Bounded raw
stored/deflate streams enforce actual output size and CRC; directory entries must
be empty stored records. This avoids ZipArchive's demonstrated truncation of
deflate output when uncompressed sizes are forged in one or both headers.

Each install uses an exclusively reserved, token-owned stage below private
managed storage. The default is managed beside ConfigPath; ManagedRoot supports
deliberate portable/isolated storage. All vendor files survive, including LICENSE,
README.txt, documentation, presets and ffplay. Shared capability/architecture
validation and a synthetic 64 kbps MP3 encode/probe/full decode run before a unique
directory rename publishes the complete dependency. The retained provenance file
is AudioFileForPhone-provenance.json. Only the shared Save-AudioToolSelection API
can then deliberately remember the new bin directory. Failure preserves previous
valid settings and user-managed tools; cleanup is limited to proved-owned staging.

A narrowly filtered retry handles transient Windows access/sharing errors during
the same unique publication rename. It rechecks ownership, paths, absent
destination, binary identities and hashes, observes cancellation and stops after
five seconds. It never changes services, processes, permissions or security
controls. Console capture owns input only during managed work and is disposed
before the remember question, so polling cannot consume menu/consent answers.
The shared flow checks its active context immediately after the engine returns
and also preserves the owned context's pending cancellation after disposal. An
observed cancellation therefore prevents subsequent pair validation or Remember,
including the handoff where the previous context was null.

The runtime allowlist, package builder and independent package policy now include
the engine and only the exact nested tools/ffmpeg-download.json manifest. Focused
security tests join the retained CI runner; actual vendor network acceptance is
an explicit local suite, without a mandatory CI network dependency. README,
SUPPORT, SECURITY, CHANGELOG and source/provenance notes describe this behavior.

Shared resolver/save/setup APIs, FfmpegDirectory/ConfigPath, absolute PATH=CWD
compatibility, one-shot input/cancel behavior and failed-save guidance remain.
The main conversion script/BAT defaults, supported inputs, Music/OutputParent
destination, relative/date-first layout, metadata, source safety, artwork,
transactional output and full decode remain. S03 startup bounds, cancellation/
release safeguards and unlimited normal encode/decode runtime are retained.

## Verification

Available actual client: Windows 11 Pro 26H2 26300.9711 x64, Windows PowerShell
5.1.26100.9711 and PowerShell 7.6.5. Existing explicit tools are C:\ffmpeg\bin.
Common child flags are -NoLogo -NoProfile -NonInteractive -ExecutionPolicy
RemoteSigned. Evidence contracts remain create-new active or historical paths;
raw reports are moved literally into marked private TEMP storage and only
redacted summaries/digests belong in Git. Owned hidden drivers explicitly emit
UTF8 CP65001; owned outer bootstraps are BOM UTF8 and establish CP65001.
No ordinary Music, personal media, owner config or persistent environment is used.
Generated private TEMP prefixes in invocation arrays are redacted as
<PRIVATE_TEMP>. Exact invocations remain in the hash-bound private raw reports.

| Check | Exact command or artifact | Environment/runtime identity | Result | Evidence |
|---|---|---|---|---|
| Primary pin/provenance | tools/ffmpeg-download.json; verified vendor ZIP, published .sha256 and GitHub asset digest; private audit SHA256 27d04c9c54e0f0eb34d79a5c33ce0e4dfd61bbc73abe31b790fe90dd0eca0bf8 | Direct Gyan HTTPS; no redirects; FFmpeg source 946fcce07b6dcd0331c8cc609192aeff5e1924f8 | PASS: download hash/114768076 bytes; 49 entries, 45 vendor files, 329221735 expanded bytes; README identifies Windows x64 static/GPLv3 | S06.json vendor provenance; private vendor audit by digest |
| Archive, failed setup and cancellation handoff | tests/Test-ManagedSetup.ps1; final70 invocation arrays in S06.json | Actual Windows client; 69bce4a final helper and unchanged engine/pin | PASS: 50 groups per shell. Earlier attempt4 passes 49 groups on the prior helper. Case50 first reproduced cancellation loss and uses explicitly labeled engine-result injection | S06.json final targeted reports; prior_validation and preparation records |
| Real vendor install and conversion | tests/Test-ManagedSetupReal.ps1; final70 invocation arrays in S06.json | Actual Windows client; 69bce4a; production pinned HTTPS transport and shared setup API | PASS: 3 groups per shell; all 45 vendor files, notices/provenance, deliberate save, fresh saved-config conversion, independently probed 64 kbps/tag/full decode, source hashes and owned cleanup | S06.json final real reports; no mocked transport/physical-user claim |
| Final first-run flow | tests/Test-FirstRunSetup.ps1; final70 invocation arrays in S06.json | Both actual client shells; 69bce4a | PASS: 15 groups per shell | S06.json final targeted reports |
| Final package policy | tests/Test-Package.ps1 with fresh final70 historical T17 report and explicit pinned 9.0.2 tools | Both actual client shells; 69bce4a | PASS: 55 checks per shell; package-policy evidence, not the future accepted release ZIP | S06.json invocation arrays and hashes; private TEMP prefix redacted |
| Final native release/resource checks | tests/Test-NativeProcess.ps1 with fresh final70 historical T17 report | Both actual client shells; 69bce4a | PASS: 35 checks per shell; run last and sequentially with retained quiet allowance | S06.json final native reports |
| Prior retained matrix | core62: isolated baseline/validation, pure contracts, help, selection, preview, transactions, controlled cancellation, short operations, captured encoding regressions, cleanup and package policy | Actual client; preserve actual report commits and file hashes; final helper changed later | Completed passing reports remain prior_validation. In-flight reports whose source guard observed the late repair are non-passes, not final acceptance | S06.json prior_validation and preparation records |
| Final source CI | Push 39074124256; PR 39074127630; all four downloaded T17-ci reports | 69bce4ac129b7acc0d95b4d9f443e782efdd8763 exact feature source; PR integration checkout c02767e30aadc88268bd08333987c70e9da18bbb separately recorded; hosted Server supplementary | PASS: 263 checks and 3 observations per job, including Managed50; source unchanged and checkout matches GITHUB_SHA | S06.json CI records |
| Prior source CI | Push 39073471860; PR 39073474224 | aceaa4d prior helper, 49 managed groups | Aggregate FAILURE: PS5.1 strict D-route text assertion failed on ErrorRecord wrapping; PS7 full matrix passed. No final-source pass claim | S06.json prior CI/preparation records |
| Review | Independent runtime/security/test reviews; intended diff and whitespace/private-data inspection | Exact final runtime/source identified above | Both-header deflate, directory-payload and cancellation-handoff findings repaired; no remaining implementation findings | S06.json review; decisions |

The source pin's installed ffmpeg hash is
3256173f3f8bffd7df12227c68adf68025edb1832273a9530688a7bb1ed8edec; ffprobe is
f0d36ecbbdd3bcfac3efa078c96c7271c2e68b3810595552ac3b7f17e9a65c52. Vendor
LICENSE hash is 8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903
and README.txt is 0342de6bb39dd421cbec2c00d89ad274b640d75ad3f2cab09ffd647ce2d8f949.
These were independently streamed from the verified download and confirmed by
both final real-install reports for selected executables and retained notices.

Preparation non-passes remain evidence. Security attempts2/3 are preserved as
preparation non-passes, with their exact diagnostics/digests in S06.json; attempt4,
prior core62 validation and final70 must remain separately identified. Independent
development experiments
also exposed forged-size truncation and drove stronger tests and the raw bounded
extractor, without relaxing safeguards. Early real61 installs
encountered Windows directory-move failures. An exact-file read-only
RestartManager query identified an external Windows service; the identical
unique rename succeeded after a short wait. This led to the bounded guarded retry.
Those failed runs are not real-install acceptance passes.

Initial final61 local outer-driver encoding failed the retained FirstRun CP65001
guard and baseline Unicode expectations. Correcting only the owned BOM UTF8
bootstrap produced final62 reruns; no product safeguard or strict Unicode
assertion was weakened. Initial source 70bd752 push CI 39073369752 and PR CI
39073372561 failed the independent package ZIP root-only assertion. aceaa4d
changes that assertion to permit only the exact nested download pin and preserves
all other package gates. Its push 39073471860 and PR 39073474224 nevertheless
aggregate-failed because the PS5.1 D-route no-download sentence wrapped inside an
ErrorRecord; PS7's full prior-source matrix passed. The strict text assertion is
retained, and the product now prints the sentence plainly through Write-Host.

A late case50 RED reproduced an actual shared-setup bug: cancellation requested
on the setup-owned context at the engine return was discarded when that context
was disposed and the previous null context restored, allowing Remember to follow.
The helper now checks active cancellation before disposal and the owned pending
flag afterwards. Case50 injects only the engine result after loading the exact
production module; it proves shared-flow cancellation and preservation, not a
vendor installation or archive smoke. It passed on both final70 shells. Final
targeted acceptance comprises ten reports: FirstRun15, Package55, Managed50,
Real3 for each shell, then one final native report per shell run sequentially.
The broader core62 runs remain prior validation with actual source/hash evidence;
source-guard failures caused by the late repair are recorded as non-passes.

Windows 10 22H2, the exact future v1.0.1 release ZIP/acceptance kit, physical
interaction and new phone observations are NOT_RUN here and remain later gates.
An exact reviewed vendor build is a repeatable managed-download reference, not a
restriction on working user-managed builds or a claim that Git builds are unsafe.
Retaining vendor notices/source links is not presented as general legal advice or
a replacement for the dependency's license.

## Git state (observe after checkpoint)

Repository origin is https://github.com/PikkuJanne/AudioFileForPhone.git. Active
branch is codex/audiofileforphone-v1.0.1 and the relevant OPEN draft PR is
https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Entry checkpoint was
c348e2f24e85e76b6e342677e2042ae4c99b428e; prior tested source was
cea42175a309fc841445f2765fc19e1d6de4c35e. Current tested source is
69bce4ac129b7acc0d95b4d9f443e782efdd8763. The engine and manifest retain their
70bd7525ecd7894d447275850a4ea95bbee240a1 bytes; the final helper contains the
later cancellation-handoff and plain diagnostic repairs. Earlier reports retain
their actual source commits rather than inheriting this new identity.

The final containing documentation checkpoint, fresh advertised feature ref,
comparison timestamp, clean worktree/push result and exact-checkpoint CI are
observed after this document is committed and pushed. A commit cannot contain
its own final SHA; the session response records that final comparison and CI.
Refresh them on the next thread. Tracking refs alone are not equality evidence.

Main integration is independently NOT_INTEGRATED. The retained main identity is
28f53b10529495754273d55654c7b29e78848c83; refresh actual local/live main at final
checkpoint. Integration remains S14 ordinary reviewed PR policy with the existing
owner-approval default. No main merge, force/reset/clean, history/protection/
visibility change, tag or release operation is part of S06. Runtime is 1.0.0;
no frozen release source or accepted release ZIP hash exists.

## Decisions, risks and blockers

D33 records separate consent, the exact primary pin and bounded private storage.
D34 records malicious-archive evidence and independent bounded extraction rather
than trusting declared ZIP sizes. D35 records the guarded Windows publication
retry, scoped console capture, preserved encoding guards and exact nested package
manifest exception. The late cancellation-handoff reproduction and repair are
documented in D36. D37 records final source acceptance and the containing
checkpoint observation protocol. Existing shared selection/config guarantees
remain. No S06 implementation blocker remains. The ten final reports and all
four exact-source CI reports passed. Later OS/phone/release acceptance remains
explicitly outside S06; no evidence is invented for those gates.

## Human action

None for S06. Consolidated human/phone/OS acceptance remains S15's ready-to-run kit
and short guide. No repeated owner diagnostics, PATH edits or personal media scan.

## Next step and fully filled prompt

S07 - Simplify metadata interaction is the next eligible step and remains
NOT_STARTED here. Start it only in a separately opened thread using this prompt:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1.
    Draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/29.
    Read AGENTS.md, CHARTER.md, STATE.json, STATUS.md, NEXT_SESSION.md,
    RELEASE_TARGET.json, evidence/S06.json and evidence/S06-HANDOVER.md.
    Refresh local/live feature and main identities and exact-head CI.
    Tested source: 69bce4ac129b7acc0d95b4d9f443e782efdd8763; refresh the later
    containing checkpoint recorded in the previous final response.
    Complete ONLY S07 - Simplify metadata interaction.
    S01-S06 are complete; do not restart them. Read tasks/S07.md and
    specs/LAUNCH_AND_INTERACTION.md, plus specs/SYNC_AND_RELEASE.md.
    Available host: Windows 11 Pro 26H2 26300.9711 x64, PS5.1 5.1.26100.9711,
    PS7 7.6.5; existing FFmpeg/ffprobe C:\ffmpeg\bin.
    Implement the clear Enter/M/Q menu after successful setup. Preserve metadata
    overrides, parameter precedence and normal defaults. Distinguish waiting,
    probing, encoding and validation. Inject Enter, M, Q, invalid-input and EOF
    tests; unavailable input must not hang or start a batch. Normal
    noninteractive calls remain prompt-free. Do not save batch metadata.
    Retain shared resolver/save/setup APIs, FfmpegDirectory/ConfigPath,
    absolute PATH=CWD compatibility and consent-based separate managed setup.
    Conversion remains free of downloads. Preserve the reviewed exact vendor
    pin, retained notices/provenance, bounded owned staging/cleanup, guarded
    publication retry and validation/smoke before selection. Preserve pending
    cancellation through the engine-result handoff before Remember. Treat
    case50 as engine-result injection and real vendor acceptance separately.
    Retain inherited UTF8 CP65001 and explicit UTF8 owned hidden PS/CMD drivers,
    historical evidence paths, isolated synthetic fixtures/config, S03 deadlines
    and cancellation/release safeguards, and unlimited normal encode/decode.
    Do not repeat owner diagnostics or scan ordinary Music/personal media.
    Preserve defaults, sources, artwork and published v1.0.0. Keep main
    integration separate under existing owner-approval authority.
    Update evidence/state/status/next-session/decisions and the full handover.
    Test/review/commit/push; verify fresh live equality and exact-commit CI.
    Give the filled next-thread prompt, then STOP. Do not start S08.
    Fixed deliverable: public v1.0.1. Only separately started S17 publishes
    S16's exact accepted source/assets.

## Stop

This thread ends after S06's final checkpoint. No S07 work starts here.

## Fixed final deliverable

Public v1.0.1 is PENDING_S17. Only separately started S17 publishes S16's exact
accepted source/assets. This step creates neither a frozen candidate nor
publication authority. Runtime 1.0.0, published v1.0.0 tag/assets and existing
icons/posters remain preserved. The fixed future release identity remains tag
v1.0.1, title AudioFileForPhone v1.0.1 and AudioFileForPhone-v1.0.1.zip.
