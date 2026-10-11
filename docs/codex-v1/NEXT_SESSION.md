# Next session — T11

Suggested owner request: **T11 next please**.
One coherent task: handle cancellation and crash leftovers safely.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS guidance. Inspect git status/branch, all fetch/push URLs, pushurl/overrides
and live GitHub. Normal fetch and independently advertised main/feature refs are
required; stored done flags or tracking refs alone are not sync proof.

T10 code checkpoint: 478c0a0c6a2935eb7271c9d28771a63455307599, branch
codex/v1-t10-results, draft PR:
https://github.com/PikkuJanne/AudioFileForPhone/pull/10.
Actual test base: d31f2deb76f2d0aa88e13fb5ca2e123c4f3d1cc6, owner-performed T09
PR #9 merge at 07:01:10 UTC on 11 October 2026. Evidence/handoff follows code;
inspect live HEAD and STATUS.md for the final feature synchronization outcome.

T10 main integration remains owner-gated. Preserve all local/remote work; no reset,
clean or force. If PR #10 is owner-merged, fast-forward clean local main to its
independently advertised merge and start T11 there. Do not infer merge authority
or start before the T10 dependency is verified complete.

Read only tasks/T11.md and relevant specs/SAFETY.md and specs/PROCESS_AUDIO.md next,
then current native runner, transaction cleanup and result handling plus affected
tests. Use evidence/T10.md for exact current commands/equivalence and limitations.

## Behavior to preserve

T10 explicit outcomes: Completed=0, CompletedWithFailures=2,
FailedBeforeConversion/Failed=1. Independent files continue after ordinary probe
or conversion failure. Processed=converted+failed; not_processed=total-processed.
Commit each actual outcome before diagnostic writes; published outputs remain
successful even if fatal log error stops the run with 1. Preserve the original
file cause plus secondary diagnostic reason. Progress display faults warn/continue.

Final summary includes counts, scan exclusions/unsupported files, elapsed seconds,
available output/log paths and explicit exit. Exclusions count entries/subtrees;
unsupported counts cover visited ordinary files only. Reserved setup can leave
marker-only residue before returning a run object; primary error names exact scope
and token while availability fallback does not falsely imply nothing exists.
Structured persistent manifests and detailed native progress remain later tasks.

BAT validates exactly one nonempty argument, keeps STA and DisableDelayedExpansion,
captures child code immediately outside launch blocks, reports truthful outcomes
and returns it after pause. 130 is reserved and inert forwarding verified only;
T11 must establish real controlled cancellation. Prior caller expansion or extra
CALL passes cannot be undone; literal percent tests use single caller substitution.

T09 encodes only to CreateNew-owned .AudioFileForPhone-<32 hex>.partial siblings,
with explicit MP3 muxer and retained no-delete guard/volume-file-index identity.
Require finite positive source duration, nonempty MP3 with selected audio bitrate
and exact optional JPEG, and source/header/full-decode duration within fixed 0.35 s.
Only validated output reaches no-overwrite File.Move. Cleanup requires exact current
identity and proved native exit; changed/reparse paths or unknown exit retain
visible incomplete residue with a reason. No global process termination/reclamation.
Keep original source/completed outputs and default DSP/rate/sample/layout behavior.

T08 exclusive root/CreateNew marker/log, exact token/scope, occupied-only suffix
retries and complete replanning remain. T07 literal boundaries, reparse exclusions,
NFC/scalar/ordinal/date/name/path budgets remain. Do not broaden T11 into a handle-
based filesystem rewrite or alter the fixed native teardown/resource thresholds
without actual evidence. Controlled cancellation and forced host close are distinct.

## Tests and handoff

Active Windows 11 machine; PS5.1/PS7; installed C:\ffmpeg\bin; short synthetic owned
TEMP. Final focused reports: T10-script-ps51-final3.json and
T10-script-ps7-final2.json (13 groups/14 independent decoded publications each),
T10-launcher-ps51-final2.json and T10-launcher-ps7-final2.json (52 cmd cases each,
both real shell branches). Eight final regression reports across baseline,
transaction/preflight/discovery are in evidence/T10.md; all 12 final payloads pass.

T10-tested-payload.json verifies 11 runtime/test fingerprints against code with
only proven CRLF/LF normalization. 32 raw reports remain (26 pass/six fail), all
source preservation/exact cleanup verified. Earlier passing harnesses/runtime
preceded timeout guards, mapping refinements or reserved-setup reporting; only
manifest-selected reports establish final equivalence. Use fresh T11 labels and
extend only affected label guards. Preserve every failure and exact thresholds.

T11 closes M2; run its focused checks and the full applicable suite at that boundary.
Native resource checks run quietly/sequentially with existing allowance 16. T09's
prior handle results were 668->668 and 576->576; T10 claims no new measurement.
Ordinary tests never touch ordinary Music. Configured-Music smoke must keep its
single successful returned root/token/CreateNew test marker/nonreparse exact
synthetic-inventory cleanup proof; no parent traversal/settings/ACL changes.

No real cancellation, forced-close, phone/manual, source-replacement, full-disk,
long-file/performance, CI or release acceptance is claimed. T09's brief post-guard
path interval remains. T07 possible unknown TEMP residue remains unverified; no
exact leaf is known and no broad cleanup/recovery is authorized.

Create evidence/T11.md; update A29–A30, TASKS, STATUS, this handoff and decisions
with actual tested payload/results. Review diff/source safety, commit intended
paths, push feature and independently compare HEAD to a fresh advertised ref.
Report main integration, CI and approval separately. Leave exactly T12 next.
No tag/release/main merge authority is granted here; final publication/public
download/main closure remain gated by the release runbook.
