# Status

Project IN_PROGRESS. S01 remains COMPLETED. S02 local acceptance A1/A2/A3 passes;
checkpoint/live verification and exact-head CI are pending before S02 completion.
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
See evidence/S02.json and evidence/S02-HANDOVER.md; refresh live state next time.
