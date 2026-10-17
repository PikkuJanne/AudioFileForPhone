# Diagnostics, self-test and bounded startup operations

## Short operations

Extend the existing native helper with per-operation deadlines, not a blanket time
limit. Starting defaults to evaluate: version/encoder/host checks 15 seconds; media
probe 60 seconds with an advanced override; bounded teardown remains separate.
Treat these as tunable project defaults, not FFmpeg guarantees. Report operation,
executable, elapsed time, process-release outcome and Timeout distinctly from error.
Poll cancellation; drain stdout and stderr independently with existing size bounds.
Kill/wait only the owned child. A deadline includes blocked output-drain completion,
not only WaitForExit. Tests must cover a never-exiting child and a child whose pipe
remains held. Dispose handles and retain incomplete working files when ownership/
release is uncertain. Cancellation stays distinguishable from timeout.

Normal encoding and complete decode have no short fixed runtime ceiling. Show
phase/progress and retain cancellation. Do not kill a progressing audiobook because
it exceeds a startup timeout. Probe timeouts must be configurable for large/slow
media, and never masquerade as corruption or completed conversion.

## Built-in check entry point

Provide Check-AudioFileForPhone.ps1 (or equivalent parameter sets without requiring
InputFolder) and an accessible BAT. Reuse the production resolver. Default check
is no-network, no-media, no-settings-write: inspect application identity, OS/host,
resolved config source, dependency candidates and versions/capabilities of selected
trusted tools. Show that execution checks run binaries; a mere path listing does not.
An explicit export may write a support report. Do not require the converter to load
successfully just to diagnose a missing helper; bootstrap failures need clear output.

Self-test is explicit and creates only a uniquely owned temporary fixture tree.
It runs a short synthetic conversion with production functions, validates outputs,
source hashes and exit handling, and cleans only its own files. It must not modify
ordinary Music or the owner's input; ordinary default-Music behavior is a separate
narrow acceptance check. No hidden network or dependency install during self-test.
If required lavfi/fixture capability is unavailable, say SELF_TEST_UNAVAILABLE,
not CONVERSION_BROKEN when ordinary conversion may still work.

## Startup failure record

On real startup failure, create a bounded report under
%LOCALAPPDATA%\AudioFileForPhone\Diagnostics, then a unique TEMP fallback if needed.
If neither is writable, the console still shows the original failure; logging
failure must not replace its primary cause. DryRun remains application-read-only,
including errors: console-only diagnostics unless the user invokes a separate
explicit export operation. Do not create an ordinary output root for a failed setup.

Record app/helper hashes/version, actual host/build, discovery attempts and rejected
reasons, selected tools, stable error code/stage, final counts/status, and log path.
Suggested codes: DependencyMissing, DependencyInvalid, ConfigInvalid, HostStartFailed,
CapabilityMissing, StartupTimeout, IncompatibleAudioSettings, OutputUnwritable.
Keep external process exit 0/1/2/130 contract; richer codes live in report fields.

## Privacy and repair

Local detailed logs may contain private filenames: label them. Shareable export
must use a whitelist of fields, replace user/source/output roots with tokens, avoid
raw PATH dumps and raw native argument lines, and sanitize bounded native errors
before inclusion. Show a reviewable text report; no automatic upload. Do not claim
redaction removes all identifying content. The owner returns one report from the
acceptance kit; Codex does not commit raw private files.

A failure must offer a specific next action (select dependency folder, reselect
saved path, shorter destination, retry after storage repair), not a generic reinstall.
Do not collect credentials, environment values unrelated to this app, or audio.
