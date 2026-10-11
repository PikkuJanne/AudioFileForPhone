# Authorization and external-change boundaries

The owner started implementation on 10 October 2026 and scoped this thread to T01.
The imported bundle does not itself grant GitHub write authority. The actual
startup authorization and checkout-recovery approval are recorded in DECISIONS.
Never infer a broader approval from tool credentials or a prior unrelated project.

On 10 October 2026 the owner requested "T02 next please" in the T02 thread.
That authorizes T02 within the normal task scope below. Startup reconciliation
found PR #1 merged by `PikkuJanne` at 19:45:49 UTC into main
`483af25f8e5fa9dee295f5b74130324663339e37`; local main was fast-forwarded to
that existing merge and a fresh `codex/v1-t02-baseline` branch was created.
The owner-performed merge is integration evidence, not a new blanket merge policy.

The owner then supplied "C:\ffmpeg please resume T02". This authorizes use of
that locally installed FFmpeg/ffprobe pair and completion of the same T02 scope;
it does not change merge, release or machine-setting authority.

## Normal task scope after startup

On 10 October 2026 the owner requested "T03 next please". This authorizes T03
within the normal scope below. Fresh GitHub inspection found PR #2 merged by
`PikkuJanne` at 20:32:54 UTC into main
`0818bf8206849370aa0ef2eaeccaed5b2fb1a890`. Local main was fast-forwarded to
that existing merge; T03 uses `codex/v1-t03-output-isolation` from it. This
owner merge does not change the main-integration or release gates.

Allowed: inspect/fetch, preserve work, create a relevant codex/* branch, make
incremental code/docs/test edits, run isolated tests, commit intended changes,
push that branch and open/update a relevant draft PR. Do not needlessly ask the
owner to approve each ordinary task commit or repeat an approval already recorded.

On 10 October 2026 the owner requested "T04 next please". This authorizes T04
within that normal scope. Fresh GitHub inspection found PR #3 merged by
`PikkuJanne` at 20:43:41 UTC into main
`bf425829d2e019911f179eb8250bfe6800f7ac81`. Local main was fast-forwarded to
that advertised commit and `codex/v1-t04-preflight` created from it. This owner
merge does not change the main-integration or release gates.

## Main integration

On 10 October 2026 the owner requested "T05 next please". This authorizes T05
within the normal scope above. Fresh GitHub inspection found PR #4 merged by
`PikkuJanne` at 21:06:59 UTC into main
`124f3a96e1a416f6870b832d1ee1cc7543286ab9`. Local main was fast-forwarded to
that independently advertised commit; T05 uses `codex/v1-t05-native-process`.
This owner merge does not change the main-integration or release gates.

On 11 October 2026 the owner requested "T06 next please". This authorizes T06
within the normal scope above. Fresh GitHub inspection found PR #5 merged by
`PikkuJanne` at 23:50:14 UTC on 10 October 2026 into main
`f5fad94d3ef31ec53972ad642b71c0a8d9f76e6f`. Local main was fast-forwarded to
that independently advertised commit; T06 uses `codex/v1-t06-safe-discovery`.
This owner merge does not change the main-integration or release gates.

On 11 October 2026 the owner requested "T07 next please". This authorizes T07
within the normal scope above. Fresh GitHub inspection found PR #6 merged by
`PikkuJanne` at 00:25:18 UTC into main
`8599dfd9706d99119d4a38fb511968529e914246`. Local main was fast-forwarded to
that independently advertised commit; T07 uses `codex/v1-t07-naming-planner`.
This owner merge does not change the main-integration or release gates.

T08 authorization: on 11 October 2026 the owner requested "T08 next please".
Fresh GitHub inspection found PR #7 merged by PikkuJanne at 01:04:14 UTC into
main `e1ea2a95a5a9b7461d69101b6a111f26b51abbf6`. Local main was fast-forwarded
to that independently advertised ref; T08 uses `codex/v1-t08-exclusive-runs`.
Normal task commits, feature push and draft PR are authorized. This owner merge
does not change the main-integration or release gates.

T09 authorization: on 11 October 2026 the owner requested "T09 next please".
Fresh GitHub inspection found T08 PR #8 merged by PikkuJanne at 05:17:22 UTC
into main `347b8656068b5e26b45410b830025de51000659f`. Normal fetch and independently
advertised main/feature refs matched the owner merge and T08 final checkpoint.
The clean local main was fast-forwarded; T09 uses
`codex/v1-t09-transactional-output` from that verified merge. Normal task
commits, feature push and draft PR are authorized under the existing scope.
This owner merge does not change main integration or release authority.

Default: owner approval for a reviewed PR or milestone integration. Optional
bounded policy the owner may approve once: integrate in-scope reviewed PRs only
when required local tests and GitHub checks pass, no conflicts or unrelated changes
exist, and a fresh comparison confirms the reviewed PR head. Preserve branch
protection; do not use admin override. Record which policy is actually approved.
Until then, feature-branch synchronization is valid but main integration is pending.

T10 authorization: on 11 October 2026 the owner requested "T10 next please".
Fresh GitHub inspection found T09 PR #9 merged by PikkuJanne at 07:01:10 UTC
into main `d31f2deb76f2d0aa88e13fb5ca2e123c4f3d1cc6`. Normal fetch and independently
advertised main/feature refs matched that merge and T09 final checkpoint
`84270ac61ab39614a4346cf5ff429e49b77ca779`. Clean local main was fast-forwarded;
T10 uses `codex/v1-t10-results` from that verified merge. Normal task edits,
isolated tests, commits, feature push and relevant draft PR remain authorized.
This owner merge does not change main integration or release authority.

T12 authorization: on 11 October 2026 the owner requested "T12 next please".
Fresh fetch/advertised refs and live GitHub verify the owner's T11 PR #11 merge
at 08:06:36 UTC into main `cb4ffc44d5ad78b575656ba44461db8b64ae7580`, with
final feature `f66331032d4debc96c07b2c0b1cb8fe5d474cf6c`. Clean local main was
fast-forwarded; T12 uses `codex/v1-t12-preview` from that verified merge. Normal
task edits, isolated tests, commits, feature push and a relevant draft PR remain
authorized. Main integration and release authority are unchanged.

T13 authorization: on 11 October 2026 the owner requested "T13 next please".
Fresh fetch, independently advertised refs and live GitHub verify the owner's
T12 PR #12 merge at 09:05:48 UTC into main
`ace0b7cfa6381ffcffb0e71f70f8346a31e04d6c`, with final feature
`fac5f09c0b13fb5f114542d41452daa880442fa1`. Clean local main was fast-forwarded;
T13 uses `codex/v1-t13-progress` from that verified merge. Normal task edits,
isolated tests, commits, feature push and a relevant draft PR remain authorized.
Main integration and release authority are unchanged.

T14 authorization: on 11 October 2026 the owner requested "T14 next please".
Fresh fetch, independently advertised refs and live GitHub verify the owner's
T13 PR #13 merge at 10:20:45 UTC into main
`1af19a7d4f0d898a1fadc0914c81b99490affd80`, with final feature
`b9d1652258ba31c20d832de505b7fe8828db3410`. Clean local main was fast-forwarded;
T14 uses `codex/v1-t14-diagnostics` from that verified merge. Normal task edits,
isolated tests, commits, feature push and a relevant draft PR remain authorized.
Main integration and release authority are unchanged.

T15 authorization: on 11 October 2026 the owner requested "T15 next please".
Fresh fetch, independently advertised refs and live GitHub verify the owner's
T14 PR #14 merge at 10:53:03 UTC into main
`1ab43fcb4e00fae6268cd799b89d8b606b6a6bb2`, with final feature
`628d8247a07a1b0866f90452883b2b4ceeea1c38`. Clean local main was fast-forwarded;
T15 uses `codex/v1-t15-metadata` from that verified merge. Normal task edits,
isolated tests, commits, feature push and a relevant draft PR remain authorized.
Main integration and release authority are unchanged.

T16 authorization: on 11 October 2026 the owner requested "T16 next please".
Fresh fetch, independently advertised refs and live GitHub verify the owner's
T15 PR #15 merge at 11:30:53 UTC into main
`42d80236521fbcbaf77d511abaca6d55456879c5`, with final feature
`8a55492ed7efb0590877eaa8f0160eee83410ce0`. Clean local main was fast-forwarded;
T16 uses `codex/v1-t16-regression` from that verified merge. Normal task edits,
isolated tests, commits, feature push and a relevant draft PR remain authorized.
Main integration and release authority are unchanged.

## Release gate

T11 authorization: on 11 October 2026 the owner requested "T11 next please".
Fresh GitHub inspection found T10 PR #10 merged by PikkuJanne at 07:18:35 UTC
into main `82f0fd3c9da765f169c2724edc73f779cdce6525`. Normal fetch and independently
advertised main/feature refs matched that merge and T10 final checkpoint
`eeb15703cac8d93d9c3147ddf2bf70e47ccda27e`. Clean local main was fast-forwarded;
T11 uses `codex/v1-t11-cancellation` from that verified merge. Normal task edits,
isolated tests, commits, feature push and a relevant draft PR remain authorized.
This owner merge does not change main integration or release authority.

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
