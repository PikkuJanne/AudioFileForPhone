# Automated acceptance contract

## Test layers and environment honesty

Retain the existing integration tests, native-process, preflight, transaction,
cleanup, discovery, preview, metadata, naming, output-parent, help/version and
launcher suites. Reuse verified test commands; do not replace them with lighter
new tests or hardcode the developer's FFmpeg path into production.

Focused unit/failure tests run each step. Full regression runs at S11/S12 and on
the exact candidate at S14. Tests must independently assert intended outcomes;
changing an expected success into expected failure requires a documented contract
reason. New tests cannot infer success solely from a log word or a version banner.

Required client environments: Windows 10 22H2 x64 and Windows 11 x64; PS5.1 and a
recorded PowerShell 7 on each for core tests. Codex uses its available Windows host
or real Windows VMs. GitHub-hosted Server CI is supplementary, accurately named.
Linux static tests or FFmpeg experiments do not fill client OS cells. If a client
is unavailable, finish code/kit preparation, then mark its acceptance BLOCKED and
use the owner kit once; do not keep requesting manual commands or invent a VM.
Do not install/purchase OSs, change host security, or assume remote access authority.

## Reproduce the first-run failure without masking it

Create synthetic fixtures with a build path known to the test harness. Launch the
candidate separately with a sanitized CHILD environment/config scope that lacks
that tool directory. Do not alter persisted PATH. Missing tools must produce clear
failure/setup action. Tools in a selected external directory must then work through
the actual production selection/config route. The harness must not quietly add
FFmpeg to the app PATH before asserting first-run success.

After saving selection, launch a fresh process and verify resolution without the
harness environment tweak. Include empty/stale/malformed PATH and app-local cases.
The main regression suite may configure tools explicitly, but label it differently
from clean first-run evidence. Tests use production APIs, not a bypass resolver.

## Core cases

- Dependency/setup/config: all cases in DEPENDENCIES_AND_SETUP.md.
- Launcher/UI: all cases in LAUNCH_AND_INTERACTION.md, including no auto retry.
- Encoding: advertised bitrate/sample-rate matrix, real-format fixtures, long-file
  decode, source/output durations, exact stream bitrate, metadata and artwork.
- Filesystem: owned isolated temp output, app read-only directory, user config not
  writable, destination denied, deep/Unicode paths, busy file, disappearing input,
  disk-write failure injection, simultaneous runs and collision determinism.
- Safeguards: no source mutation, output never overwrites, interrupted/invalid file
  never final-looking, cleanup only exact owned files/processes, cancellation.
- Diagnostics: startup failure export, unavailable log directories, redaction,
  bounded JSON/output, stable stage codes, dry-run no writes/prompts/tools/network.
- Compatibility exploration: genuine cloud/redirected/UNC locations when available,
  otherwise local representative negative tests and explicit evidence gaps. Do not
  remove all reparse safeguards to expand claims. No universal NAS/cloud guarantee.

Use failure injection for disk-full/locked-folder/process cases rather than filling
real disks or altering owner ACLs broadly. Synthetic fixtures and test config/output
must stay in exclusively owned scopes. Full source hashes before/after for fixtures;
local owner collection hash verification in the acceptance kit. No audio uploads.

## CI controls

Extend existing Windows workflow. Pin reviewed Actions by full commit SHA and dev
modules/dependency archives by tested versions/hashes. Minimal permissions; no
secrets for untrusted code, unsafe pull_request_target checkout, secret logging,
or write-on-every-push release job [P5]. Network dependency setup is an explicit CI
provisioning phase with provenance, not evidence that user setup works unaided.
Exercise offline install failures and a narrow end-to-end online installer check
against the selected vendor artifact; static mock coverage alone is insufficient.

Record checks by runtime hash set and environment, with start/end, commands, exit,
expected/actual and raw-local/redacted-export evidence paths. No fabricated checks
counts. CI pending/failed is not PASSED. Skip/unavailable rows never satisfy required
release gates. Nonrequired environments remain clearly outside the claims.
