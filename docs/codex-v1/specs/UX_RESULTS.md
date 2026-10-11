# User experience, outcomes and reporting

## Public interface

Keep InputFolder, BitrateKbps=64, MaxBaseLength=60, Interactive, CoverPath, Artist and
Album. Add optional OutputParent with the configured Music folder still default.
The T12 no-write preview interface is the single DryRun switch, using shared
discovery and planning logic. It does not enable SupportsShouldProcess/WhatIf.
Do not add a GUI, command hierarchy or mandatory interactive wizard.

Outside Interactive, no Read-Host/file picker should run. Preflight errors should
be returned before optional metadata prompts. Exactly one dropped folder is the
BAT contract; reject zero/multiple arguments clearly, not silent first-only use.
The wrapper remains STA-capable and preserves its child exit result across pause.

## Outcome contract selected in T10

For conversion, selected bounded codes: 0=all supported snapshot files succeeded; 1=preflight/no
supported files/fatal problem; 2=completed batch with one or more per-file failures.
130 / Cancelled is selected for controlled user cancellation in T11 and handled
by the BAT. PowerShell parameter-binding failures and
forced OS termination may have host-defined codes; the minimum invariant is no
failure being presented as success. Report forced-close limitations honestly.

Continue independent files after ordinary conversion failure. Fatal preflight or
inaccessible scan prevents conversions. Scan exclusions, unsupported extensions,
conversion failures and cancellation are separate outcomes in the summary.

T10 result names: Completed (0), CompletedWithFailures (2),
FailedBeforeConversion (1, no file outcome recorded) and Failed (1, at least one
file outcome recorded). Processed equals converted plus failed; not_processed
equals supported snapshot total minus processed. Count only after the file's
probe/transaction boundary finishes; success requires T09 publication. Commit
the count before diagnostics so a log failure cannot reclassify or double-count
the file. A diagnostic write failure stops the run with code 1 and console root
cause/mapping. Progress display failure warns and continues.

T11 captures Ctrl+C as console input only after interactive prompts, restoring
the previous console mode in finally. Poll native wait/drain and file/publication
boundaries; cancellation and publication have a per-context ordering point.
The interrupted file is not a completed success/failure and remains not_processed.
Persist CANCELLED and RESULT records when the log is writable; diagnostic failure
does not mask cancellation code 130. Preserve exact retained-path/unproved-child
and console polling/restoration diagnostics. Redirected input/unsupported hosts,
preflight/prompts, Ctrl+Break and forced host/window shutdown have host-specific
limits; forced termination may bypass finally and leave a running child/partial.
No next-run reclamation is authorized by a parsed marker or recognizable filename.

Scan exclusions count skipped entries, including excluded directory subtrees;
unsupported files count only ordinary files in visited directories. These counts
are separate from supported files and conversion failures. The final console
summary includes elapsed seconds, counts, actual reserved output/log locations
and exit code even after a caught fatal error. Normal logs retain the legacy
Summary totals plus the explicit RESULT status/counts line. Structured persistent
manifests and persistent native diagnostics remain T14 work; richer progress is T13.

BAT disables delayed expansion, accepts exactly one nonempty argument, keeps STA,
captures child errorlevel on the immediately following line outside a parenthesized
launch block, and returns it after pause. Messages distinguish completion, file
failures, fatal error, reserved cancellation and unknown nonzero results. Caller
expansion (for example raw %NAME%, delayed !NAME!, or an extra CALL pass) cannot
be undone by the wrapper; tests must identify how literal paths reach cmd.exe.

## Preview

Plan source-to-output mapping, collisions, exclusions and warnings without writes.
No output root, log, marker, manifest, image preparation, encoder or interactive
prompt. Read-only probing is allowed only if needed and clearly described. Do not
write a test sentinel to prove permissions in preview; say not checked. An actual
run reserves its root, so a preview root is provisional, not a promised timestamp.

DryRun performs no native probing: duration is unknown, and destination
writability, tools, media and cover validation remain unverified. Interactive is
ignored explicitly. Report naming warnings and skipped paths/reasons, plus the
unsupported count for visited directories and the supported extension policy.
Each console [PLAN] line contains compact JSON with source_relative_path,
output_relative_path, provisional_output_path and duration="unknown". No
persistent manifest is created. Previewed returns 0, with processed/converted/
failed zero and not_processed equal to the supported snapshot total. Caught
preflight, input, scan and naming failures retain FailedBeforeConversion/1 and no
writes. Parameter binding remains outside the script's result handler, as above.
The final summary labels the root provisional and states that no log was created.
Unchanged source names/timestamps and naming options produce the same relative
mapping; a real reservation race may choose another root and path-budget outcome.

## Progress and logs

Show processed/total and per-file encoding progress, then validation/promotion.
Unknown duration is indeterminate. 100 percent processed does not imply every file
succeeded. Native diagnostics should persist locally while console verbosity can
remain modest. Keep enough stderr for the real failure without storing unbounded
progress noise or personal metadata in public GitHub artifacts.

Manifest fields: source relative path (optionally full local path), output relative
path, status, error code/reason, input/output duration, byte lengths and elapsed
time. Format can be CSV or JSON; use one schema and roundtrip tests. CSV needs proper
escaping/UTF-8 and a defined spreadsheet formula-safety approach; JSON avoids that
specific spreadsheet behavior. Do not change original metadata just to sanitize a
log. A separate display-safe field can coexist with exact structured values.

Final messages: completed, completed with failures, cancelled or failed before
conversion. Include actual totals, elapsed time, output location and local log/
manifest location. No automatic upload, browsing, website launch or update check.
