# S01 handover - COMPLETED

## Outcome

The 43-file v1.0.1 plan is imported and root routing is active. S01-A1/A2/A3 pass.
The reviewed preparation checkpoint is pushed, independently synchronized and green
on both exact-head push/PR CI matrices. The final docs-only record is verified
after push in the session response; no containing-commit self-hash is stored.
S02 has not started. No application feature was changed; no local audio conversion
or owner test was run. Supplementary CI executed the retained automated suites.

## Changes

Imported only payload/docs/codex-v1.0.1 from the verified corrected bundle. Merged
AGENTS routing, Windows 10 target, separate consent-based setup scope, checkpoint
and fixed release rules. Updated STATE, STATUS, NEXT_SESSION and DECISIONS.
Historical docs/codex-v1, runtime, tests, CI, packaging, README and owner artwork
are unchanged from reconciled main. No runtime dependency or machine setting added.

## Verification

Commands use the repository as working directory. `$bundle` is the externally
extracted AudioFileForPhone_Codex_v1.0.1_Bundle; `$py` is the Codex bundled Python
under `$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`.
Both are optional planning tools, outside the repository/application package.

| Check | Exact command or artifact | Environment/runtime identity | Result | Evidence |
|---|---|---|---|---|
| Bundle structure/integrity | `& $py -B $bundle/tools/validate_bundle.py $bundle` | Corrected bundle ZIP SHA256 cd8421b3a2e4d0b7ba10d96323d00544b8fc97a5af140f56938e8d2b3b805028 | PASS: 52 files, 18 steps, 54 criteria | S01.json bundle/cases |
| Validator regression tests | `& $py -B $bundle/tools/test_validate_bundle.py` | Bundled standard-library tooling | PASS: all 22 tests, including deliberate invalid-input rejection | S01.json cases |
| Reconciliation | `git fetch --prune origin`; `git merge --ff-only origin/main`; `git switch -c codex/audiofileforphone-v1.0.1` | Clean initial main 74992b2; live main 28f53b10529495754273d55654c7b29e78848c83 | PASS: four owner artwork commits preserved | S01.json repository |
| Live release identity | `gh api repos/PikkuJanne/AudioFileForPhone/releases`; `git ls-remote --tags origin v1.0.0 'v1.0.0^{}' v1.0.1 'v1.0.1^{}'` | v1.0.0 release 410779813 / source 2092a405c1d06eca336e771a0ed5d1881acd015a | PASS: target unused; original tag and all three asset digests fixed | S01.json release |
| Host inventory | `Get-CimInstance Win32_OperatingSystem`; explicit PSVersionTable object under each `-NoProfile -NonInteractive` host | Windows 11 Pro 26H2 26300.9711 x64; PS5.1 5.1.26100.9711, PS7 7.6.5 | PASS: inventory only | S01.json environment/cases |
| Imported contracts and scope | External `check_s01.py`; `git diff --check`; Git source bytes and SHA256 comparison | Tested unchanged source 28f53b10529495754273d55654c7b29e78848c83 | PASS: 39 immutable payload files equal, four ledgers mutable; old evidence/runtime/artwork preserved | S01.json runtime_hashes/cases |
| Existing test entry points | Read tests/Invoke-IsolatedBaseline.ps1, .github/scripts/Invoke-CiChecks.ps1, T22-routine-commands.json | Retained real-FFmpeg suite | Inventory only; no local audio suite needed for docs-only S01 | S01.json test_entry_points |
| Feature checkpoint | `git push -u origin codex/audiofileforphone-v1.0.1`; `git rev-parse HEAD`; `git ls-remote --exit-code origin refs/heads/codex/audiofileforphone-v1.0.1` | 91635bbcd7ac74ea135be1fbdd95fb9c543ca88a | PASS: live equality and clean checkout | S01.json checkpoint_verification |
| Both-shell sync | `$ps51` / `$ps7 -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File docs/codex-v1/tools/Test-GitSync.ps1 -RepoPath C:\projects\AudioFileForPhone-main -AsJson` | Actual local PS5.1 / PS7 above | PASS at 15:12:27Z / 15:12:30Z | S01.json checkpoint_verification |
| Preparation CI | `gh run view 39043987462 --repo PikkuJanne/AudioFileForPhone --json headSha,status,conclusion,jobs`; same for 39044003403 | Push / PR for 91635bbcd7ac74ea135be1fbdd95fb9c543ca88a; Windows Server supplementary | PASS: both PS5.1 and PS7 jobs in both runs | S01.json ci |

No Windows 10, new candidate/package/kit or new phone pass is claimed. The owner's
baseline metadata prompt remains the last confirmed stage. Existing v1.0.0 live
server digests were read; independent redownload was not performed in S01.

## Git state (observe after checkpoint)

Repository: PikkuJanne/AudioFileForPhone, public, HTTPS origin, default main.
Active branch: codex/audiofileforphone-v1.0.1. Tested source and local/live main:
28f53b10529495754273d55654c7b29e78848c83. Prior verified checkpoint local/live HEAD is
91635bbcd7ac74ea135be1fbdd95fb9c543ca88a, independently observed clean/equal on
2026-10-17 at 15:12:27Z (PS5.1) and 15:12:30Z (PS7). Its push and PR CI both pass.
Draft PR #29: https://github.com/PikkuJanne/AudioFileForPhone/pull/29. Final
docs-only containing HEAD/live equality and exact CI are in the post-push session
response; the next thread must refresh them. S01 is not integrated into
main; integration is deferred to S14. No frozen v1.0.1 source or ZIP hash exists.
The final containing commit cannot record its own SHA; final observation belongs
in the post-push response and the next thread must refresh it.

## Decisions, risks and blockers

No earlier 18-step import exists, so S01 applies rather than version correction.
The historical v1.0.0 plan remains archival. No target conflict or local-work
conflict was found. The available FFmpeg pair under C:\ffmpeg\bin was inventoried
without execution. Runtime version remains 1.0.0, intentionally unchanged in S01.

Helpers has LF Git bytes and clean CRLF checkout bytes; both hashes are recorded.
The initial PS5.1 file invocation omitted the established process-only RemoteSigned
flag and was blocked; the established invocation passes without persistent policy
changes. The initial external audit used an unsuitable hash-object normalization assertion
for other tracked CRLF files; the corrected comparison checks exact Git bytes or
the exact clean CRLF representation. No application file changed. An initial
PS5.1 hashtable inventory projection emitted nulls; explicit property capture
verified the actual host version. These tooling corrections are not app failures.

Future S02 must respect existing T-prefixed evidence destination contracts, use
owned synthetic fixtures and retain inherited UTF-8 CP65001 behavior. Windows 10
and candidate-byte acceptance remain future evidence requirements. Preparation
push/live comparison and exact-commit CI passed; no S01 blocker remains.
The final docs-only record receives its own post-push live/CI confirmation.
Existing owner approval for reviewed main integration remains required unless
explicit authority or a bounded merge policy is recorded. No automatic merge.

## Human action

None for this step. Consolidated owner kit belongs to S15. No PATH edits, tool
commands, repeated diagnostic, personal-audio upload or manual matrix requested.

## Next step and fully filled prompt

Next eligible step is S02, NOT_STARTED. Start a new thread with:

    Continue AudioFileForPhone in C:\projects\AudioFileForPhone-main using
    docs/codex-v1.0.1 on branch codex/audiofileforphone-v1.0.1 (draft PR #29:
    https://github.com/PikkuJanne/AudioFileForPhone/pull/29). Read CHARTER.md,
    STATE.json, STATUS.md, NEXT_SESSION.md and evidence/S01-HANDOVER.md; verify
    fresh local/live branch and main refs plus CI for the exact current head.
    Complete ONLY S02 - Capture regressions before fixing them in this thread.
    S01 is complete; do not reimport/reset the plan or restart S01. Read tasks/S02.md
    and only its referenced specs. Tested baseline is
    28f53b10529495754273d55654c7b29e78848c83; actual Windows 11 Pro 26H2
    26300.9711 x64 has PS5.1 5.1.26100.9711 and PS7 7.6.5, with FFmpeg/ffprobe
    files under C:\ffmpeg\bin (S01 inventoried but did not execute them).
    Automate isolated no-profile missing-tool and bitrate/sample-rate regressions
    with short owned synthetic fixtures. Retain existing suites; respect their
    historical T-prefixed evidence-path contracts and inherited UTF-8 CP65001.
    Use the established per-process RemoteSigned invocation for local PS1 checks;
    do not alter persistent policy or PATH. Do not rerun owner diagnostics, scan
    ordinary Music/personal media, infer conversion from prompts, or start S03.
    Preserve defaults, source safety, current artwork and published v1.0.0.
    Main integration remains separate, with its existing owner-approval default.
    Update evidence/state/status/next-session/decisions and the full handover;
    test/review/commit/push intended changes and verify fresh live equality and
    exact-commit CI. Give the filled next-thread prompt, then STOP.
    The fixed final deliverable is public v1.0.1; only separately started S17
    publishes the exact accepted source/assets identified in the S16 handover.

## Stop

This thread performs S01 only. No next numbered step without a new owner thread.

## Fixed final deliverable

Public v1.0.1 publication is PENDING S17. No new tag, release, package or draft
was created. A prepared plan does not satisfy the final public deliverable.
