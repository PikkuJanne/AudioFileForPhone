# Authorization and external-change boundaries

The owner started implementation on 10 October 2026 and scoped this thread to T01.
The imported bundle does not itself grant GitHub write authority. The actual
startup authorization and checkout-recovery approval are recorded in DECISIONS.
Never infer a broader approval from tool credentials or a prior unrelated project.

## Normal task scope after startup

Allowed: inspect/fetch, preserve work, create a relevant codex/* branch, make
incremental code/docs/test edits, run isolated tests, commit intended changes,
push that branch and open/update a relevant draft PR. Do not needlessly ask the
owner to approve each ordinary task commit or repeat an approval already recorded.

## Main integration

Default: owner approval for a reviewed PR or milestone integration. Optional
bounded policy the owner may approve once: integrate in-scope reviewed PRs only
when required local tests and GitHub checks pass, no conflicts or unrelated changes
exist, and a fresh comparison confirms the reviewed PR head. Preserve branch
protection; do not use admin override. Record which policy is actually approved.
Until then, feature-branch synchronization is valid but main integration is pending.

## Release gate

The supplied release prompt authorizes annotated v1.0.0 tagging, draft creation,
asset upload, normal public publication and docs-only closure integration for the
specified full commit and exact ZIP/manifest hashes. It may be carried across T24–T27.
A changed commit, payload, hash or newly failed acceptance invalidates that approval.
No intermediate public releases or prereleases. A draft is allowed after this gate.

## Never authorized implicitly

History rewriting, force push, deletion/reset of unrelated work, existing tags or
releases, replacing public assets, repository visibility/protection changes,
secret creation/disclosure, spending money, machine-wide execution-policy changes,
disabling endpoint protection, changing default audio processing, hosting or website
work. Do not bypass corporate policy when an unsigned script is blocked.

## Blocker handling

Missing test environment, phone evidence, authentication, checks or approval means
blocked—not complete. Continue independent authorized work where possible, then
leave one precise owner action with evidence. Do not silently waive required tests.
