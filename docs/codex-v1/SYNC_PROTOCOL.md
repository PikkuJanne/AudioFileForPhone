# Local / GitHub synchronization protocol

## At session start

Inspect root and all applicable agent guidance before importing/editing. Use
`git status --porcelain=v1 --untracked-files=all`, active branch, `git remote -v`,
all fetch/push URLs and `git config --get-all remote.origin.pushurl`. Confirm
origin belongs to PikkuJanne/AudioFileForPhone. Support normal SSH/HTTPS URL forms;
do not log embedded credentials. A changed repo identity is a blocker.

Run a normal `git fetch --prune origin` and inspect live advertised branch/main
refs. A bundle baseline is a reference, not a reset target. Classify local-only,
remote-only, diverged and dirty states. Preserve work and reconcile explicitly;
never use reset --hard, clean -fd, stash-and-forget, destructive checkout or force
push to manufacture a clean state. Resolve missing upstream deliberately.

At T01 inspect live default branch and existing PRs/tags/releases. If an existing
v1.0.0 release or tag is found, do not delete or retarget it; reconcile with owner.

## Task checkpoint

1. Run relevant tests; record exact commands, shell/OS/FFmpeg versions and outcomes.
2. Review diff, prohibited artifacts and source-safety evidence. Update TASKS,
   STATUS, NEXT_SESSION, decisions and task evidence using truthful results.
3. Stage explicit intended paths. Review `git diff --cached`. Do not blindly add
   everything from a working directory that may contain the owner's files.
4. Commit focused changes, then push the named feature branch. A rejected push is
   a blocker. Review remote changes; do not force-push.
5. Query live GitHub with `git ls-remote --exit-code origin refs/heads/<branch>`.
   Independently compare the full returned SHA to local HEAD. A stale origin/*
   tracking ref or a success-looking push message is insufficient evidence.
6. Verify clean intended worktree and report separately: active branch sync,
   main integration, CI status and approval state. Refresh before any merge.

`tools/Test-GitSync.ps1` performs a non-mutating check; it does not fetch, pull,
push, stage or commit. It validates fetch/push identity and untracked/dirty state.
A required origin/default ref unavailable over the network means verification
failed, never offline success. T01 validates the helper under both Windows shells.

## Feature branches versus main

A pushed feature branch does not mean main contains its changes. Use milestone
PRs or small task PRs as recorded at T01. Merge only under AUTHORITY.md. Recheck
reviewed head and CI, respect protections, then fetch/reconcile local main and
run a fresh check. Keep one active implementation branch rather than many stale
parallel branches on a single working tree. No second-machine work is needed.

## Durable evidence without self-referential commits

Evidence records name the code commit they tested and the previous verified GitHub
checkpoint. Do not try to put a commit's own SHA inside that same commit. Report
the final post-push HEAD/live-ref comparison in the session response or PR comment.
If a later docs-only status commit is needed, push/verify that too; do not endlessly
create commits solely to update “latest verified SHA”. Revalidate live state on the
next session regardless of a stored “done” flag.

## Release freeze and closure

The actual T24 exact approval in evidence/T24-authorization.json accepts the
owner's existing early docs-only PR #24 merge at
`cf03cf7097640fcac287e24f6a90ff003e5fe0be`. Keep that live main until T27 as
the narrow main-at-C timing exception; preserve frozen C
`2092a405c1d06eca336e771a0ed5d1881acd015a` and all exact package bytes.
Require C ancestry and the complete docs/codex-v1-only diff. This is no broader
integration permission; subsequent progress stays on the evidence branch.

C = immutable tested release source commit. Tag v1.0.0 must always resolve to C.
E = release-evidence branch based on C; it may receive progress/evidence-only commits.
D = final main after docs-only closure integration. D may differ from C, but only
under docs/codex-v1/. Runtime, tests, CI, build rules and all shipped files must
remain byte-identical. Do not move the tag to D. Final local main must equal the
live GitHub main D. Check C is an ancestor of D and inspect the complete diff.

Temporary detached worktrees for exact-C/ZIP tests on the same active machine
are allowed. Do not confuse a detached test worktree with the main developer
checkout, or delete a worktree containing uncommitted work.
