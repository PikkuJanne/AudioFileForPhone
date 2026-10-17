# AudioFileForPhone agent instructions

## Work boundaries

Improve the existing PowerShell/FFmpeg tool incrementally. Keep the script and
BAT entry points, 64 kbps CBR MP3 default, supported MP3/M4A/OGG inputs, Music-folder
destination, recursive relative layout, date-first names and metadata behavior.
Do not add a hosted service, website, new UI framework, telemetry, account system,
silent or automatic downloader/updater, production Python dependency or unrelated refactor.
Loudness normalization is optional/deferred and never enabled by default.
A separate user-invoked, consent-based dependency setup helper is allowed by the
active charter. Conversion must never download tools silently. No persistent PATH,
registry or execution-policy changes, elevated setup or managed-control bypass.
Preserve current icons and posters.

## Session routing

The active plan is `docs/codex-v1.0.1/`. Start with its `CHARTER.md`, `STATE.json`,
`STATUS.md`, `NEXT_SESSION.md` and `RELEASE_TARGET.json`; inspect actual git state,
applicable agent overrides and fresh live GitHub. Read only the current task and
relevant specs next, including `specs/SYNC_AND_RELEASE.md` for checkpoint authority.
`docs/codex-v1/` is preserved historical v1.0.0 evidence, not active task routing.
Exactly one numbered step per thread. At success, failure, capacity boundary or
missing evidence, checkpoint safe work, give the full handover and STOP. Begin no
next numbered step until the owner starts another thread. A broken environment
is a named BLOCKED result; resolve safe local failures within the current step
and record missing evidence without disabling safeguards. Existing user
instructions take precedence; merge rather than overwrite pre-existing content.

## Implementation and evidence

Maintain Windows PowerShell 5.1 and PowerShell 7 compatibility on Windows 10 22H2
x64 and Windows 11 x64. Record actual client OS builds; Server CI is supplementary.
Retain the existing real-FFmpeg integration suite; isolate it before broad use.
No audio/source modification in-place. No final-looking partial files, wildcards
for untrusted filesystem paths, Invoke-Expression, or global process termination.
No binaries, personal media, credentials or private logs in Git.

Automate tests on the active Codex Windows machine, with GitHub CI supplementary.
Use short synthetic fixtures and targeted tests per task, full suites at milestone
boundaries and the exact release ZIP. Never invent manual/phone evidence. Do not
run the baseline test suite against the owner's ordinary Music folder blindly.
Historical verified commands remain in `docs/codex-v1/STATUS.md`; inventory and
adapt them within the active step without overwriting old evidence. Consolidate
necessary human actions into S15's ready-to-run acceptance kit and short guide;
do not repeat owner diagnostics, request PATH edits or infer conversion success
from a metadata prompt. Keep private media and raw reports out of public Git.

## GitHub checkpoints and authority

Follow the active charter and `specs/SYNC_AND_RELEASE.md`; historical v1.0.0
approvals are not new release or general main-merge authority. Normal bounded
step edits, isolated tests, intended commits, feature pushes and a relevant draft
PR are authorized. Integrate main through ordinary reviewed PR policy at S14;
retain the existing owner-approval default for main integration unless explicit
authority for the reviewed head or a bounded merge policy is recorded. Never
change visibility, protections or history. Review the intended diff, test,
update STATE/STATUS/NEXT_SESSION/evidence/decisions and the full handover, commit
and push. Independently compare HEAD to the fresh live advertised branch ref;
tracking refs alone are not proof. Report feature sync and main integration
separately, including exact-commit CI and pending checks. Preserve unrelated work
and never use force-push/reset/clean shortcuts.

## Release

The owner-fixed deliverable is public v1.0.1. `RELEASE_TARGET.json` requires runtime
1.0.1, tag v1.0.1, title AudioFileForPhone v1.0.1 and AudioFileForPhone-v1.0.1.zip.
Preserve published v1.0.0, its tag and assets. No intermediate public release or
silent version substitution; reconcile an occupied target without overwriting.
Follow the active release spec: validated exact ZIP -> verified draft -> public
v1.0.1 -> independent public download -> final local/live main sync and closure.
S16 must supply the exact accepted source/assets in its publication prompt; only
the separately started S17 performs authorized publication. S18 verifies closure.
A prepared ZIP, tag, draft or release-ready handover is not project completion.
Never move a released tag or replace public bytes to include closure evidence.
