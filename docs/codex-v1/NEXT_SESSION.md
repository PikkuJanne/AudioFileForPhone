# Next session — T08

Suggested owner request: **T08 next please**.
One coherent task: reserve unique run roots and logs exclusively.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS instructions. Inspect actual git status/branch, all origin fetch/push URLs,
pushurl/overrides and live GitHub. Normal fetch and fresh advertised refs are
required; stored done flags or tracking refs are not synchronization proof.

T07 code checkpoint: `e99f81ca3eb2c24102882e5723c52c236105450c`, branch
`codex/v1-t07-naming-planner`, draft PR #7:
https://github.com/PikkuJanne/AudioFileForPhone/pull/7.
Evidence follows in a docs-only checkpoint; inspect current live HEAD. T06 was
owner-merged into main `8599dfd9706d99119d4a38fb511968529e914246`. T07 main
integration remains owner-gated. Preserve local/remote work; no reset/clean/force.
If PR #7 is owner-merged, fast-forward local main to its verified live ref and
start the T08 branch from that merge. Do not infer agent merge authority.

Read only tasks/T08.md and relevant specs/SAFETY.md next, then the current run/log
code and tests. Use specs/FILENAMES.md/evidence/T07.md for dependent name budgets.

## T08 bounded implementation

- Reserve roots through proven exclusive ownership, readable timestamp plus
  entropy/collision suffix. A GUID suggestion is not an exclusive reservation.
- Create logs and marker with CreateNew semantics. Never reuse an existing run.
  Record exact cleanup scope; preserve prior roots/logs/sentinels byte-for-byte.
- Use a synchronization barrier for concurrent launches, not sleeps as race proof.
  A22/A23 require distinct owned roots/logs and no preexisting overwrite.
- Adapt second-resolution root assumptions in tests and the paused configured-
  Music smoke. Keep that smoke narrow and owner-bounded; never enumerate ordinary
  Music or clean by naming convention. Normal resolver tests remain TEMP-only.
- Replan/validate the exact reserved root spelling using the T07 pure batch
  planner. Its complete file/directory/future working budgets remain enforced;
  added root entropy must fit. Preserve default 64 kbps, formats/layout/date-first
  naming/metadata and script/BAT entry points. No downloads/new framework.

## Tests and handoff

Tests run on this active Windows 11 machine under PS5.1/PS7 with the installed
C:\ffmpeg\bin pair, short synthetic fixtures and exclusively owned TEMP. Current
passing command families/labels are in evidence/T07.md and TEST_STRATEGY.md;
new harnesses/report guards need T08 labels while preserving all historical JSON.
Run targeted reservation/sentinel/concurrency tests and affected retained suites.
Final T07 reports use current hashes and verified cleanup; the initial failed
naming attempt's possible unknown machine-TEMP synthetic residue is documented.
Do not claim that attempt cleaned or attempt broad cleanup without exact ownership.

Update evidence/T08.md, A22/A23 links, TASKS, STATUS, this handoff and decisions.
Review intended diff/source safety, commit/push, independently compare local HEAD
to fresh advertised branch and report main integration/CI/approval separately.
Leave T09 as exactly the next coherent task. No release/tag/main merge authority
is granted by this handoff; project completion still requires final publication,
independent public download and main closure under the release runbook.
