# User experience, outcomes and reporting

## Public interface

Keep InputFolder, BitrateKbps=64, MaxBaseLength=60, Interactive, CoverPath, Artist and
Album. Add optional OutputParent with the configured Music folder still default.
Add one clearly documented no-write preview interface; use shared planning logic.
Do not add a GUI, command hierarchy or mandatory interactive wizard.

Outside Interactive, no Read-Host/file picker should run. Preflight errors should
be returned before optional metadata prompts. Exactly one dropped folder is the
BAT contract; reject zero/multiple arguments clearly, not silent first-only use.
The wrapper remains STA-capable and preserves its child exit result across pause.

## Outcome contract to finalize in T02/T10

Suggested bounded codes: 0=all requested conversions succeeded; 1=preflight/no
supported files/fatal problem; 2=completed batch with one or more per-file failures;
130=controlled user cancellation where the host permits capture. These are a proposed
project contract, not claims about current behavior. Record any alternative and
update tests/help/BAT consistently. PowerShell parameter-binding failures and
forced OS termination may have host-defined codes; the minimum invariant is no
failure being presented as success. Report forced-close limitations honestly.

Continue independent files after ordinary conversion failure. Fatal preflight or
inaccessible scan prevents conversions. Scan exclusions, unsupported extensions,
conversion failures and cancellation are separate outcomes in the summary.

## Preview

Plan source-to-output mapping, collisions, exclusions and warnings without writes.
No output root, log, marker, manifest, image preparation, encoder or interactive
prompt. Read-only probing is allowed only if needed and clearly described. Do not
write a test sentinel to prove permissions in preview; say not checked. An actual
run reserves its root, so a preview root is provisional, not a promised timestamp.

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
