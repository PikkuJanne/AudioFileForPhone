# Next session — T17 after owner integration

T16 is complete: A41/A42 and the full local regression/failure matrix pass on
PS5.1 and PS7. Exactly next implementation task: T17, secure Windows CI and a
release gate, after owner integration of T16. Project/release remain incomplete.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS guidance. Inspect actual dirty/untracked state, active branch, fetch/push
URLs, overrides, normal fetch, independently advertised refs and live GitHub.
Preserve all work; no reset/clean/force. Owner merged T15 PR #15 at 11:30:53 UTC
on 11 October 2026 into main 42d80236521fbcbaf77d511abaca6d55456879c5.
T01-T15 are integrated. Prior T15 feature 8a55492ed7efb0590877eaa8f0160eee83410ce0.

T16 branch codex/v1-t16-regression; reviewed/tested code
3f3c21d2ca65025202ea4a364a157f671031a2a8 was pushed/live-matched.
Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/16.
Evidence/handoff follows in a docs-only checkpoint; independently inspect its
fresh final HEAD/ref. T16 main integration remains owner-gated. Live workflow
count is zero; local tests are not CI acceptance. No tags/releases exist.

## Preserve the tested matrix and safety contracts

Read evidence/T16.md and T16-tested-payload.json. Thirty-six selected finals pass:
974 required checks/groups plus six baseline observations. Thirty retained
reports keep actual base 42d80236 and matching frozen bytes; six focused finals
directly test code 3f3c21d2. No production PS/BAT changes were needed.
The manifest binds 22 files/184 relationships to committed blobs, four literally
and eighteen by strict UTF-8 CRLF-to-LF only; legacy missing fields stay absent.

Cleanup has 181 cases per shell: 16 actual retained TEMP guards and two exclusive
writers, with 163 preservation negatives and 18 positive operations. Scope is
actual extracted cleanup IfStatements plus inert dependencies and one observer;
parent finalizer coverage is not fabricated. Ten existing descendant conditions
and three ACL conditions are
negatively probed; six legacy bodies have no descendant condition. The new ledger
hardens Test-NativeProcess.ps1 specifically. Keep CreateNew evidence and positive
native-release gating. Unknown descendants or reparse/scope uncertainty retain
fixtures. Never broaden cleanup to ordinary Music or all TEMP.

Edges has six groups and ten independent output probes/full decodes per shell.
Real source/encoder paths 259 and combined special/Unicode parents pass. Source 260
success is limited to the actual machine/build; destination working 260 refuses
before native calls/reservation with explicit audited no-call proof. Live encoder
validation failure leaves the concurrently completed sibling byte-identical.
Native has 35 groups, 98 positive release records and quiet handles 665->665/576->576
with allowance 16. Full suites retain actual 3,605-second progress and scoped returned-root
Music smokes. Production source/synthetic preservation and owned cleanup pass.

Preserve all nine preliminary reports (five failed/four passing), four historical
snapshots and four separate proof/recovery records. Original failed flags remain
false. Cleanup attempt1's original marker digest was absent; current recovery
observation never fills it in. No recovered failed run counts as acceptance.

T01 external importer and T11 physical Ctrl+C evidence stay historical; no fresh
manual/phone/CI/release claim. Metadata/cover/chapter fixture limitations, T07
possible unknown residue, T09 path interval, T11 forced-host and T14 persistence
limits remain. Keep existing conversion, naming, publication, exit, preview,
progress, metadata and local diagnostics contracts. Loudness remains deferred.

## Start the next coherent task

If PR #16 is owner-merged, verify its advertised main merge, fast-forward clean
local main and create a relevant T17 codex branch. Read tasks/T17.md and only its
relevant specs next: TEST_STRATEGY.md, specs/RELEASE_PACKAGE.md and SOURCES.md.
Add secure Windows checks on both supported shells with reviewed full action
SHAs, minimum permissions and pinned/verified CI-only FFmpeg dependencies.
Do not grant untrusted PR code release-write credentials or add a production
downloader. Obtain real green workflow evidence on the exact reviewed head.
Main/release authority is unchanged; no intermediate public release.

Copy-ready prompt: T17 next please
