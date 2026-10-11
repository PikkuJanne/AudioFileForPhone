# Next session — T14 after owner integration

T13 is complete: A33/A34 pass on Windows PowerShell 5.1 and PowerShell 7.
Exactly next implementation task: T14, persistent diagnostics and a usable run
manifest, after owner integration of T13. Project/release remain incomplete.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS guidance. Inspect dirty/untracked state, active branch, fetch/push URLs,
overrides, normal fetch, independently advertised refs and live GitHub. Preserve
all work; no reset/clean/force. T12 PR #12 was owner-merged at 09:05:48 UTC on
11 October 2026 into main ace0b7cfa6381ffcffb0e71f70f8346a31e04d6c. T01-T12 integrated.

T13 branch codex/v1-t13-progress, reviewed/tested code
8607569a7147aba836c2e7c4c36f4f0219369d58, pushed/live-matched.
Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/13.
Evidence/handoff follows in a docs-only checkpoint; inspect fresh final HEAD/ref.
Main integration remains owner-gated.

## Preserve progress and earlier contracts

Encoder progress uses bounded stdout records independently of stderr. Keep only
the latest complete record, 1,024-character lines, 8,192-character records and
sampling every 500 ms within a phase, immediate changes and drainage after observer
fault. Prefer out_time_us, legacy out_time_ms also microseconds, then arbitrary-hour
timestamp. Unknown timing/duration is indeterminate; no ETA. progress=end is only
an encoding boundary. File success at 100 percent follows validation/publication/
count; failure clear stays indeterminate. Batch uses ok+failed and visibly retains
failures at 100 percent.

Read evidence/T13.md and manifest: fourteen selected final passes; 17 focused
progress groups per shell at the reviewed commit, actual 3,605-second synthetic
conversions and independent full decode at 3605.047982 seconds, with live positive
machine samples before publication. Native 35, transaction 27/61 decoded, script
13, preview 8, cancellation 9 and retained baseline pass both shells.
Native handle counts stay 667->667 and 576->576;
source/synthetic/child/exact TEMP gates pass; ordinary Music unused. Manifest
independently matches 14 files to code, literally or only CRLF-to-LF.

Retain all 18 raw test reports, including two preliminary passes and two failed
harness variable-collision attempts. Separate recovery records plus historical
harness reconstruction prove later removal of two exact known owned roots;
original failed cleanup flags remain false. No blanket cleanup is authorized.

Preserve DryRun's no tools/writes/cover/prompts/cancellation/progress/parser and
Previewed/0 contract. Keep T09 publication/ownership, T10 truthful counts/0/2/1,
T11 Ctrl+C/130/release/context restoration and forced-close limits. T07 possible
unknown residue and T09 path interval remain. Physical T11 evidence remains
historical; no new phone/manual/CI/release acceptance is inferred.

## Start the next coherent task

If PR #13 is owner-merged, independently verify the advertised main merge,
fast-forward clean local main and create a relevant T14 codex branch. Read only
tasks/T14.md and relevant specs next. Add local persistent diagnostics/structured
run manifest without changing preview, progress, outcomes or source safety.
Main/release gates are unchanged; next full applicable suite is at a milestone.

Copy-ready prompt: T14 next please
