# S10 production and privacy review

Reviewed on 2026-10-28 (Europe/Berlin), against entry checkpoint
`ec828036cda843f9fadff2bc932125d84d241218` and committed source
`35cc0a74a2fa4ac59bb9e22d09da61ad5d7cef44`, followed by the two-line repair in
`b05b581dc6372cecd99471c53ee2cac72b8267ba`. This is a code review and a
read-only preservation comparison. Final client-suite results, exact-source CI,
feature synchronization and the containing documentation checkpoint are separate
gates recorded in S10.json and the full handover.

The bootstrap implementation author reviewed the separate environment-check and
self-test implementation. The check/self-test implementation author independently
reviewed the bootstrap/resolver boundary. The bootstrap sections also received an
author readback; that is not a claim of independent authorship or an external
security audit. Neither peer review substitutes for the root agent's executed
Windows tests.

## Reviewed behavior and repairs

The independent diagnostics helper loads without the main converter helper. Real
startup failure records have bounded identity, config-source, actual resolver
attempts/rejections, selected tool hashes, stable code/stage, counts and native
elapsed/release fields. Application identity includes runtime/helper hashes and
the registry client build with its UBR revision; an OSVersion value alone would
not establish the complete Windows client build.

The original console cause is printed before best-effort logging. Diagnostics
first try process LOCALAPPDATA/AudioFileForPhone/Diagnostics, then a unique
process-TEMP fallback. Literal-path ancestry checks refuse reparse storage paths;
create-new writes refuse occupied filenames and cap reports at 64 KiB. Optional
discovery/native text is reduced if JSON expansion exceeds that byte bound. A
storage failure remains secondary to the original cause. A failed setup does not
reserve a conversion run merely to obtain a log. DryRun returns from the
diagnostic writer before any directory/file creation, including preview errors.
If the diagnostics helper or bootstrap host cannot run, the original console
failure remains available.

The review identified an important continuation boundary: a failed native
prerequisite must not enter interactive setup when process release or pipe
completion is unproved. The converter now checks the captured production result
before invoking setup or another native operation. Existing S09 capability
release refusal remains unchanged. The support harness's substituted refusal is
an explicitly labeled returned-result injection. It proves the stop decision;
it does not create or prove handling of a genuinely orphaned/unreleased process.

Default environment checking reuses production resolution and capability queries,
executes the selected trusted binaries, and does not scan audio, save settings,
download dependencies or automatically create a diagnostic report. Its optional
LocalOnly resolver policy rejects UNC and mapped network config/tool paths before
candidate access and skips remote PATH directories with a recorded rejection.
Local app/PATH candidate ancestry is checked before a path-existence query can
follow a reparse candidate. Ordinary conversion does not enable this additional
local-only selection restriction. Diagnostic identity collection resolves the
config spelling without retrying a failed filesystem lookup, avoiding a second
access to a config already refused by the check.

Explicit synthetic self-test uses production source probing, S09 audio planning,
metadata arguments, transactional encoding, validation and complete decode. It
requires the returned native release/pipe proofs before continuing. The tiny tree
is reserved exclusively, carries a held create-new token/identity marker, and
cleanup checks its exact parent/name/path inventory, source hash and absence of
unexpected/reparse descendants. Deletion is confined to that fixed inventory and
empty owned directories. Uncertain ownership, native release or cleanup retains
the scope and prevents a success claim. Missing fixture-only capability reports
SELF_TEST_UNAVAILABLE without asserting ordinary conversion is broken.

Peer review corrected trailing-slash handling for a drive-root TEMP location and
late cancellation after real conversion/cleanup. The self-test rechecks
cancellation at its result boundary, and the check entry point preserves a
request before disposing the cancellation context. A completed synthetic file or
successful cleanup cannot override exit 130. The late-cancellation regression
uses real synthetic conversion/cleanup followed by a deliberately injected
cancellation request; it is not physical Ctrl+C evidence.

## Support privacy

Detailed records are labeled PRIVATE because paths and bounded native errors may
identify user files. The separate shareable formatter creates a new whitelist
object. It retains only normalized codes/stages, narrow version/build tokens,
known runtime digest names, architecture values and bounded numeric/boolean
outcomes. It replaces host/tool/config/user/source/output roots with tokens and
omits raw PATH, native argument arrays, stderr/error free text, discovery reasons,
metadata, arbitrary properties and the original private message. Omitting native
free text avoids presenting a broad path-substitution regex as a privacy proof.

Support review reads one bounded strict-UTF8 schema-1 report, validates its
kind/schema, and does not require the converter helper. Export is a separate
explicit create-new operation, displays reviewable text and uploads nothing.
The notice correctly requires review and does not promise anonymity. A report
with valid structure remains untrusted input; whitelist/type filtering is applied
again during export. Reparse import/export destinations are refused.

## Read-only source preservation check

Under portable PowerShell 7.6.5, the reviewer read the entry helper with
`git show ec828036cda843f9fadff2bc932125d84d241218:AudioFileForPhone.Helpers.ps1`,
parsed entry/current contents with `Parser.ParseInput`, normalized CRLF to LF,
then compared the single matching function AST Extent.Text for each name below.
All eleven function texts were exactly equal:

- Invoke-AudioNativeProcess; Get-AudioMediaInfo; Get-AudioEncoderSampleRates.
- Get-AudioOutputPlan; New-AudioEncodeArguments; Get-AudioMetadataPlan.
- Get-AudioOutputValidation; Invoke-AudioOutputTransaction;
  Publish-AudioWorkingOutput.
- Save-AudioToolSelection; Invoke-AudioToolSetup.

This is pure code-preservation evidence, not a real conversion or Windows matrix
pass. It supports review of the unchanged S09 exact bitrate/rate/channels,
compatible 64 kbps mono/stereo sound policy, explicit downmix/rejection,
metadata/artwork mapping, fixed duration bound, full decode, owned partials,
no-overwrite publication and unlimited normal encode/full-decode runtime.
The unchanged save/setup bodies retain the separate consent-based downloader and
do not add any download to conversion. Native timeout/cancellation/release
mechanics remain in the retained production runner.

The intended diff keeps script/BAT entry points, supported input extensions,
default Music destination, recursive layout, date-first naming, default bitrate,
icons and posters. Runtime remains 1.0.0 at this stage; public v1.0.1 is the fixed
later deliverable. This review supplies no main-merge or publication authority.

## Runtime byte snapshot

These SHA256 values were read from the runtime checkout at the review boundary.
All rows except Checks.ps1 match the reviewed source 35cc0a7. The Checks.ps1 row
includes the subsequently inspected two-line local-path repair described below.
They identify the actual checked-out bytes, including checkout line endings; they
are not an assertion that every Git blob uses the same line endings. S10.json
records the final tested source that contains this complete byte set.

| Runtime file | SHA256 |
|---|---|
| AudioFileForPhone.ps1 | 2bfbe066420c76f00391f2c38963c2d97510b2bd7863181812a645e5b732d28c |
| AudioFileForPhone.Helpers.ps1 | a0aff73af92f73817b1b4341be6ec81d3326caca5ea37a6a71cc70fe38239b36 |
| AudioFileForPhone.Diagnostics.ps1 | 078196abc845bd8651ac047f0d5c6ddf283e0a8965d121223123e851c6b9915e |
| AudioFileForPhone.Checks.ps1 | 72f1ca6593ae861eda0bf137378e9e4305e74176048b19a3ccfc47cec5e62c46 |
| Check-AudioFileForPhone.ps1 | ebd667882c3144b181caa7b1d8aff770f994e1c71b49b38bcc48d544deb6d1f4 |
| Check-AudioFileForPhone.bat | b67202151d87e585cef1517917f9cb25dcd8cf2e327c1d4ec46f67e5cd521580 |
| AudioFileForPhone.Launcher.ps1 | 47ff967cdef0392f6d937a73a09763fa5f0952b68ddf47de237974062fbc1732 |
| AudioFileForPhone.HostProbe.ps1 | 043ccfe7199f1cbdcbc98e27339e7fd7c6a1ec57307a6352dab24f8ad2829996 |
| AudioFileForPhone.bat | 85123393a4a903e628f748004de9f51cf7a6f15159a29576abb9f5214121b338 |
| Setup-AudioFileForPhone.ps1 | 881f23c652eed61ddb074174403a2f225aca8aa8d84c0574ab6dba121f5eb630 |
| Setup-AudioFileForPhone.bat | 3d877f10816e65ec062c3a3c2788207cc4504e7829bdd6f994c03dd4525c3553 |
| AudioFileForPhone.ManagedSetup.ps1 | facc047465e1a2c7b094d5f871d21d8399124d57985577ebe2ed1bddd1c06538 |

## Follow-up and limits

Read-only review of source 35cc0a7 found two local-only policy gaps:
Import-AudioDiagnosticRecord did not call the independent local-path guard before
ancestry/file access, and New-AudioSelfTestScope did not apply the local tool-path
guard to TEMP before ancestry access. The root agent was notified. The separately
made repair was then inspected read-only: import now assigns
`$full = Assert-AudioLocalDiagnosticPath -Path $full` before its storage ancestry
check, and self-test reservation calls
`$null = Assert-AudioLocalToolPath -Path $parent` before TEMP ancestry access.
The earlier Checks.ps1 hash was
`87fd9af31d56671637e10911ce24388f30e33b73ca79b148e0118ad0a1261036`;
the corrected byte snapshot is in the table above. These are exactly the two
intended guard additions. Their formal focused rejection and both-shell results
remain in S10.json rather than being inferred from source inspection.

No further actionable production finding remained in this review scope. No
production file was edited during this review assignment. The source identity
and final test gates must still be observed independently; this review does not
promote pending checks to passes.

This review did not run the final both-shell suites, exact-head CI, a mapped
network share, real unreleased child, physical UI/console interaction, Windows 10,
phone playback or the final release ZIP. Local-only guards prevent application
selection of remote paths; executing a user-selected trusted binary is not a
claim of OS network sandboxing. PowerShell/.NET may use transient runtime/compiler
files for Add-Type; the check's application contract concerns no persistent
settings/media/automatic diagnostic files. Real tests and clearly labeled pure
injections belong to S10.json with their actual source/runtime identities.
