# Source and provenance notes

Prepared 2026-10-17. This is a plan, not completed implementation evidence.
Refresh volatile provider/CLI/runtime details when implementing. No vendored source
or third-party binaries are included. Primary documentation informed constraints;
project-specific design decisions are proposals, not claims made by those sources.

## User evidence

The attached diagnostic and later console output are summarized in BASELINE.md.
Do not publish the raw diagnostic. Its executable discovery is not a media test.
The last new console evidence reaches the optional metadata prompt only.

## Repository reads

G1 — Live main snapshot:
https://api.github.com/repos/PikkuJanne/AudioFileForPhone/branches/main
Observed 28f53b10529495754273d55654c7b29e78848c83.

G2 — Latest public release:
https://api.github.com/repos/PikkuJanne/AudioFileForPhone/releases/latest
Observed v1.0.0; published 2026-10-12; source 2092a405c1d06eca336e771a0ed5d1881acd015a.

G3 — Existing active agent instructions (must merge narrow new routing):
https://github.com/PikkuJanne/AudioFileForPhone/blob/28f53b10529495754273d55654c7b29e78848c83/AGENTS.md

G4 — Tagged runtime/helper/support code reviewed earlier in this conversation:
https://github.com/PikkuJanne/AudioFileForPhone/tree/v1.0.0
Refresh exact helper/preflight/launcher/encoding code during S01/S02. Current
statements from the earlier review are preserved as baseline leads, not new tests.

## External primary references

P1 — Microsoft PowerShell environment variables:
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-7.5
Child process inheritance and scope explain why a temporary PATH fix does not
persist for future desktop launches. The new design avoids persistent PATH edits.

P2 — FFmpeg command documentation:
https://ffmpeg.org/ffmpeg.html
Version/encoder inspection, stream mapping, output-scoped audio options and progress.
Exact encoder/sample-rate planning must be verified on the selected Windows build.

P3 — Gyan's own Windows-build documentation:
https://www.gyan.dev/ffmpeg/builds/
Observed release/Git-master offerings and the owner's reported Git-build identity.
Do not infer a stability hierarchy from release versus Git naming. Select and pin
an exact build at S06; this plan does not embed a made-up download hash.

P4 — FFmpeg licensing information:
https://ffmpeg.org/legal.html
Licensing depends on build configuration. Inspect vendor notices/source provision;
the application's license does not replace dependencies' terms. No automatic claim
that retaining notices alone resolves every distribution obligation. The chosen
setup route downloads directly from a publisher rather than redistributing binaries.

P5 — GitHub Actions secure use:
https://docs.github.com/en/actions/reference/security/secure-use
Full reviewed commit pins, minimal permissions and untrusted-input boundaries.

P6 — Owner release-target correction, this conversation, 17 October 2026:
"Ok, this will take us to v1.0.1, so please make sure the end product is Codex publishing v1.0.1"
This explicit project instruction determines the target. It supersedes the earlier
version suggestion without changing implementation scope, test gates or workflow.
No live repository state was rechecked solely for this bundle correction.

P7 — GitHub CLI release create:
https://cli.github.com/manual/gh_release_create
Draft preparation and --verify-tag; verify actual available CLI behavior in S17.

P8 — GitHub CLI release download:
https://cli.github.com/manual/gh_release_download
Asset retrieval; separate authenticated draft checks from public anonymous checks.

## S06 verified pin (2026-10-17)

P9 - Exact Gyan vendor ZIP and checksum (direct HTTPS, no runtime latest lookup):
https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip
https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip.sha256
Publisher release: https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2
Observed vendor current release 9.0.2 (2026-09-19), x64 static essentials GPLv3.
The independent downloaded ZIP is 114768076 bytes, SHA256
60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba.
Published checksum and publisher GitHub asset digest agree. Actual ZIP inventory:
49 entries (45 regular files), 329221735 expanded bytes. LICENSE and README.txt
are retained with every vendor file. The runtime manifest records reviewed safety
bounds, distinct from actual sizes. No vendor binaries are redistributed.

P10 - Exact source and dependency terms identified in the vendor README:
https://github.com/FFmpeg/FFmpeg/commit/946fcce07b6dcd0331c8cc609192aeff5e1924f8
https://www.gnu.org/licenses/gpl-3.0.html
Vendor source availability/license review is separate from capability validation.
The application's MIT license does not replace the downloaded build's GPLv3 terms.
