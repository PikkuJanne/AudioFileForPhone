# R1 handover — direct visible launch restored

## Result and scope

R1 only is complete. Owner testing required: none. No package, tag, release or
main integration was performed. R2/R3 remain separate chats. The historical
owner recovery report is retained as reported success, not independent acceptance.

The converter BAT now starts the existing converter directly in one built-in x64
Windows PowerShell5.1 STA NoProfile process. An explicit internal switch reads
the folder as process data; ordinary PS5.1/PS7 parameter calls remain available.
Both BATs request process-only Bypass and keep final status/pause/exit in CMD,
including failures before any PS1 can enter. Managed policy remains authoritative;
there is no retry or script-text evaluation. Both launchers isolate built-in host
modules within setlocal and use CRLF; neither changes the caller persistently.
Audio engine, dependency selection/optional consent-based setup and artwork remain.
Legacy launcher/probe references were audited and sources retained. The old pinned
user-package builder remains for deliberate R2 replacement; it is not a repaired ZIP.

## Automated verification

Windows11 Pro26H2 x64 build26300.9711, non-elevated account. Per shell:

| Suite | WinPS5.1.26100.9711 | PS7.6.5 |
| --- | ---: | ---: |
| Real-console direct BAT | 39 passed | 39 passed |
| First-run setup | 15 passed | 15 passed |
| Help/examples | 7 passed | 7 passed |
| CI contracts and policy guards | 41 passed | 41 passed |
| Existing isolated real-FFmpeg baseline | passed | passed |

Every native case observed the production pause, proved a wait before an injected
key and preserved the expected exit, with owned processes released. Paths cover
spaces, parentheses, ampersands, percent, exclamation, apostrophe, Unicode and
trailing separators; invalid arity, missing files/host/helper and parsing refusal
remain visible. Disposable NTFS scripts carry deterministic Internet marks.
Host adapters produce genuine AllSigned/RemoteSigned File-entry refusals; these
are not actual managed-policy deployments. Parent policies/PATH/PSModulePath,
source bytes and cleanup invariants pass. Setup includes four actual one-file
64kbps conversions per shell with full decode. Raw report hashes, commands,
source identities and honest preparation nonpasses are in R1.json; raw reports
and synthetic media remain private.

## Limits and blockers

No unresolved R1 launch failure. Windows10 client execution, real managed-policy/
application-control deployment, actual Explorer BAT/shortcut drops, physical
dialogs and repaired exact-package/browser-extraction acceptance are unverified.
No new phone or human-listening evidence is claimed. These gaps are Codex work;
no owner test or diagnostic task is assigned. Corrective release identity and
exact tested-byte publication authority still require reconciliation before R3.

## Files and Git

Changed: two entry BATs and converter parameter binding; .gitattributes; the new
native-console tests; affected setup/help tests and CI gates/workflow; README,
SUPPORT, SECURITY; AGENTS and active charter/sync instructions; adopted brief;
STATE/STATUS/NEXT_SESSION/DECISIONS and this redacted evidence/handover. No icon,
poster, audio helper, setup engine or public asset changed.

Branch: codex/audiofileforphone-r1-launch-repair.
Implementation:6e22c5c8394c6453e0d3428bc9fc143040126b96.
Local reports retain the actual precommit base b571fd17fb1123ae9b78d44ee246b4701e021194
plus hashes; matching final native runtime/harness bytes were independently bound
to implementation source. The containing evidence checkpoint cannot contain its
own SHA. Observe final HEAD/fresh advertised branch and exact-head CI after push,
and report them in the final response. Main remains separate and unintegrated;
ordinary reviewed policy and existing owner-approval default apply.

## Exact next prompt and stop

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main on branch
    codex/audiofileforphone-r1-launch-repair. Follow AGENTS.md and the active
    docs/codex-v1.0.1/CHARTER.md amendment, STATE.json, STATUS.md, NEXT_SESSION.md,
    REPAIR_BRIEF.md, RELEASE_TARGET.json and specs/SYNC_AND_RELEASE.md.
    Read evidence/R1.json and evidence/R1-HANDOVER.md. Refresh actual checkout,
    containing checkpoint/live refs, draft PR and exact-commit CI; R1 source is
    6e22c5c8394c6453e0d3428bc9fc143040126b96. Complete ONLY R2 of the focused repair:
    small allowlisted root BAT/unchanged ICO/README.txt/app, direct BAT-to-app
    converter with no CALL forwarding, concise console and relocated exact-package
    tests. Keep CMD pause/exit, CRLF BAT files, process-only Bypass, own-host module
    selection, literal folder transport, existing engine/metadata/defaults and
    optional consent-based dependency setup. Build-UserPackage currently pins old
    published bytes and targets the old launcher; deliberately update that contract
    and relevant tests rather than shipping the old path. Retain all required
    helpers/licenses/notices under app and preserve unrelated historical evidence.
    Owner testing required: none. No acceptance kit, logs, playback or phone request.
    Do not publish or replace v1.0.0/v1.0.1 assets/tags. Do not silently choose a
    corrective version or infer new publication/main authority from historical
    approvals. Main integration retains ordinary review and owner-approval default.
    Validate the candidate, record exact artifact/icon hashes and actual evidence
    gaps, review/commit/push and compare HEAD with fresh advertised branch, report
    exact-head CI and main separately. Give the full handover, then STOP before R3.
Owner testing required: none. STOP after R1; do not start R2 in this chat.
