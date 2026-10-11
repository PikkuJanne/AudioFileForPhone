# Next session — T10

Suggested owner request: **T10 next please**.
One coherent task: unify script and BAT result reporting.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS instructions. Inspect actual git status/branch, all origin fetch/push URLs,
pushurl/overrides and live GitHub. Normal fetch and fresh advertised refs are
required; stored done flags or tracking refs are not synchronization proof.

T09 code checkpoint: fcce28736081d799b29f4594b56bebafbad1a9f7, branch
codex/v1-t09-transactional-output, draft PR:
https://github.com/PikkuJanne/AudioFileForPhone/pull/9.
Actual test base: 347b8656068b5e26b45410b830025de51000659f, owner-performed T08
PR #8 merge at 05:17:22 UTC on 11 October 2026. Evidence/handoff follows code;
inspect actual live HEAD and STATUS.md for the final synchronization outcome.

T09 main integration remains owner-gated. Preserve local/remote work; no reset/
clean/force. If PR #9 is owner-merged, fast-forward local main to its independently
advertised merge and start T10 from there. Do not infer agent merge authority or
start before the T09 dependency is verified complete.

Read only tasks/T10.md and relevant specs/UX_RESULTS.md and specs/SAFETY.md next,
then current conversion/result/log handling, BAT launch behavior and affected tests.
Use evidence/T09.md for exact commands, payload equivalence and limitations.

## T09 behavior to preserve

Only CreateNew-owned sibling .AudioFileForPhone-<32 hex>.partial files receive
FFmpeg overwrite permission with explicit MP3 muxer. Keep fixed working-name/path
budget and retained no-delete ownership guard through all native process use.
Volume/file-index checks gate no-overwrite File.Move and exact partial cleanup.
Concurrent finals preserve bytes and fail the original planned mapping.
Changed/reparse paths or unproved child exit retain visible incomplete residue
plus cleanup diagnostics; never reclaim other runs.

Require nonempty MP3, one requested-rate MP3 audio stream, expected optional JPEG
and finite positive source/header/decoded durations within fixed 0.35 s. Container
duration is a fallback only for absent/N/A stream duration; missing/invalid data
fails before encoding. Full error-fatal output decode uses validation-only sample
time, adds a read/decode pass and changes no DSP. Encoder exit zero or artwork-
inflated container bitrate never establishes success. Rounded selected rates must
fail validation; do not force a new sample rate.

General batch/BAT exit policy is still T10. Count success only after promotion.
Postpublication diagnostic failure already reports actual published path or actual
file failure, stops with exit 1 and avoids double counting. Keep mapping truthful
when introducing consistent results. Preserve sources/completed outputs.
Controlled cancellation is T11; preview T12. No new UI, unrelated DSP or downloads.

T08 exclusive Win32 root/CreateNew marker/log reservation, bounded occupied-only
numeric suffix retries, ownership token/scope and exact replanning remain.
T07 date/NFC/scalar/order/name/path budgets and literal/reparse guards remain.

## Tests and handoff

Tests run on this active Windows 11 machine under PS5.1/PS7, existing C:\ffmpeg\bin,
short synthetic fixtures and exclusively owned TEMP. Final focused reports:
T09-transaction-ps51-attempt6.json and T09-transaction-ps7-final1.json.
Each passes 27 groups, 61 decoded conversions and three incompatible-rate rejects.
16 other final reports across eight families and exact commands are in evidence/T09.md.
Native resource checks ran quietly/sequentially; keep allowance 16. Use fresh T10
labels and extend only affected report-label guards; preserve historical attempts.

Retain real FFmpeg integration and affected companions. Never run a baseline
against ordinary Music. Configured-Music smoke may touch only its exact successful
returned token/inventory-proved synthetic run; preserve narrow cleanup guards,
no parent traversal, no settings/ACL change.

T09 retains 27 raw reports (21 pass/six fail), with 18 final equivalents.
Earlier baseline source mutations and diagnostic/driver harness failures remain
explicit. Attempt4 identity-only redaction is documented. No full-disk, long-file/
phone/manual, cancellation, source-replacement, CI or release acceptance is claimed.
The brief post-guard filesystem check interval remains; do not expand T10 into
a handle-based filesystem rewrite.

T07's initial failed naming cleanup leaves unknown possible synthetic machine-TEMP
residue. Exact leaf is unrecorded and parent enumeration denied. Do not claim it
cleaned or attempt broad cleanup/ACL changes without exact ownership.

Create evidence/T10.md; update A27–A28, TASKS, STATUS, this handoff and decisions
with actual results/exact payload. Review diff/source safety; commit/push intended
paths; independently compare HEAD to fresh advertised feature ref. Report main
integration, CI and approval separately. Leave T11 as exactly the next task.
No tag/release/main merge authority is granted here; final publication, independent
public download and main closure remain gated by the release runbook.
