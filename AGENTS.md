# AudioFileForPhone agent instructions

## Work boundaries

Improve the existing PowerShell/FFmpeg tool incrementally. Keep the script and
BAT entry points, 64 kbps CBR MP3 default, supported MP3/M4A/OGG inputs, Music-folder
destination, recursive relative layout, date-first names and metadata behavior.
Do not add a hosted service, website, new UI framework, telemetry, account system,
auto-downloader/updater, production Python dependency or unrelated refactor.
Loudness normalization is optional/deferred and never enabled by default.

## Session routing

Start with `docs/codex-v1/STATUS.md`, `NEXT_SESSION.md`, `TASKS.json`, `AUTHORITY.md`
and `SYNC_PROTOCOL.md`; inspect actual git state, existing agent overrides and
live GitHub. Read only the current task and relevant specs next. One coherent
task per thread. Existing user instructions take precedence over this template;
merge rather than overwrite pre-existing AGENTS content.

## Implementation and evidence

Maintain Windows PowerShell 5.1 and PowerShell 7 compatibility on Windows 11.
Retain the existing real-FFmpeg integration suite; isolate it before broad use.
No audio/source modification in-place. No final-looking partial files, wildcards
for untrusted filesystem paths, Invoke-Expression, or global process termination.
No binaries, personal media, credentials or private logs in Git.

Tests are run on the active Codex Windows machine, with GitHub CI supplementary.
Use short synthetic fixtures and targeted tests per task, full suites at milestone
boundaries and the exact release ZIP. Never invent manual/phone evidence. Do not
run the baseline test suite against the owner's ordinary Music folder blindly.
The verified test commands are established in T02 and updated in STATUS.md.

## GitHub checkpoints and authority

Follow the authority file; authorized feature pushes are not permission to change
visibility, protections or history. Review the intended diff, test, update handoff,
commit and push. Independently compare HEAD to the live advertised branch ref;
tracking refs alone are not proof. Report feature sync and main integration
separately. Preserve unrelated work and never use force-push/reset/clean shortcuts.

## Release

No intermediate public release. Tag and publish only with recorded authorization
for the exact reviewed commit and assets. Follow RELEASE_RUNBOOK.md: validated
ZIP -> verified draft -> public v1.0.0 -> independent public download -> final
main sync and closure. A prepared ZIP, tag or draft is not project completion.
Never move the released tag or replace public bytes to include closure evidence.
