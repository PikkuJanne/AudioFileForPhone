# S13 review

The implementation is confined to kit/build/test files; all13 production runtime
checkout hashes and packaged behavior remain unchanged from b05b581dc6372cecd99471c53ee2cac72b8267ba.
S13.json records exact code, runtime-package and kit identities separately.

A peer reviewer read the S13 task/specs before reviewing the runner, builder,
common verifier, exporter and physical helper. Review found and corrected the
proposed redirected BAT/default-config assumption, nested export fields, unknown
status serialization, actual architecture reporting, prerequisite release guards,
hidden UTF8 driver setup, repeated dependency selection and physical-result scope.
The actual owner's answer and mechanical verification now have separate fields;
only the mechanical passing result can unlock a physical gate.

The builder checks exact18-member runtime inventory, sizes, hashes, helper version
and checksum rows. It refuses unsafe/duplicate/omitted members, escaped duplicate
JSON properties, additional binaries, occupied output and changed inputs. The kit
hash is external; all bundled runtime bytes are unchanged. Checkout EOL hashes are
not substituted for package Git blob hashes. Explicit rehearsal mode cannot emit
candidate acceptance. No intermediate tag or public release is created.

The common verifier checks retained ZIP and extracted content, bounded archive
expansion, literal local paths, package-bound production manifests, exact source/
record/output correlation, counts, audio plan and fixed-duration/full-decode
validation. Bounded child captures must prove exit/drain/release before proceeding.
Normal conversion and complete decode remain unlimited. Source hashes stay private.

The exporter uses a field whitelist rather than log-string scrubbing. It excludes
private paths, source/output hashes, raw errors and unknown nested fields. Complete
bounded reports are staged and moved without overwrite. There is no upload.
Expected-negative exits are labeled per case; a completed manifest never becomes
a captured physical BAT exit.

The physical route targets the real packaged BAT with the original collection.
It watches only newly created top-level run events, checks exact source/build/
start/ownership identity and refuses zero/ambiguous/error observations. It never
scans Music, selects a newest directory or deletes completed outputs. Actual stub
shortcut testing exposed percent expansion, now a named refusal before launch.
Synthetic watcher tests do not assert physical owner evidence.

The PS5.1 null adapter had separate read-only peer review. It adds only an explicit
null return inside one kit inventory call. Literal path handling, narrow exception
handling, marker identity/exclusion, read/permission errors and reparse refusal
remain. New tests prove real marker exclusion, lock/junction refusal and no global
function replacement. Production runtime is unchanged and failed final1 evidence
is retained separately.

Pinned PSScriptAnalyzer1.25.0 and both supported parsers check actual source; the
full dependency inventories are verified by the parent analysis. No review or
synthetic positive fixture supplies client10, core campaign, online setup, physical,
phone, exact final ZIP or publication evidence. The existing S12 validators, CI
pins/permissions/narrow artifacts and all retained S08-S12 tests remain unchanged.

The remaining S13 blocker is actual picker selection/cancellation on an allowed
interactive desktop. The UI experiment and policy refusal are accurately labeled
BLOCKED_INTERACTIVE_DESKTOP. S13 is not complete, no owner diagnostic is requested,
and S14 remains unstarted.

## Continuation review from96da3cc

An independent read-only reviewer confirmed the remaining criterion is actual
Select-KitFolder selection returning the identical literal owned path and actual
cancellation throwing OperationCanceledException('Selection cancelled.'). The
full runner must not be dot-sourced for this narrow test. The continuation binds
the AST-extracted function and private driver to the current unchanged runner.

The host refused the driver before execution; no pass is inferred from process
exit, missing report or absent window. No policy argument/change, control bypass
or owner debugging followed. All24 source/runtime hashes and20 old report digests
match. Documentation-only changes preserve tested source9e2c933/runtimeb05b581,
all prior nonpasses, NOT_TESTED physical/phone fields and null final-asset fields.
Current entry source/live equality and four passing exact-head Server jobs are
separate from the final containing-checkpoint sync/CI observation after push.

Independent review of all eight final documentation diffs passed scope/privacy/
state/identity checks and reverified the private refusal digest and24/20 comparison
counts. One printed Get-Process parameter spacing error was corrected before
commit. Active JSON/state/target/null-asset assertions, exact function extraction,
source hashes and git diff --check passed on portablePS7.6.5.
