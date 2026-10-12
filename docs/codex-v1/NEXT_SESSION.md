# Next session — continue T24 after pending exact approval

T23 A55/A56 pass. T24 preflight and independent reviews pass, but A57 is blocked
pending exact owner approval and a narrow main-timing exception; A58 is not run.
Exactly next: continue T24. No tag, draft, upload or publication exists yet.
O01 remains deferred; release/project incomplete.

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS first, then tasks/T24.md, RELEASE_RUNBOOK.md, evidence/T24.md,
T24-preflight.json and RELEASE_AUTHORIZATION_REQUEST.md. Recheck actual Git,
live refs/checks/tags/releases. Preserve unrelated work; no reset/clean/force.

Frozen C stays 2092a405c1d06eca336e771a0ed5d1881acd015a. Owner PikkuJanne
merged T23 evidence PR #24 early at 15:36:02Z on 12 October 2026. Main is now
cf03cf7097640fcac287e24f6a90ff003e5fe0be, whose complete tree equals the T23
evidence head. C is an ancestor and all 100 changed paths are docs/codex-v1.
Runtime/shipped/test/build/CI bytes are unchanged. Normal local fast-forward
preserved the existing merge. Do not roll back main, advance C or rebuild assets.

The approval request expressly accepts that existing docs-only merge as a narrow
exception to main-at-C timing and would require main to remain at the reconciled
SHA until T27 closure. This exception is pending. The literal main-equals-C
condition remains false. The task request and PR merge do not authorize release writes.

The three exact assets remain at the local_staging_directory in RELEASE_CANDIDATE.json:

- ZIP 53,958 bytes: 8fe8ac6752800f54dd58a7b454924ee5aa0b9b7153aa31457312ba3e1b2103cf.
- Manifest 4,162 bytes: 7f354b2065b472f126316a1ceeae818e6133f59539eeaa526cab2a2e75609146.
- Checksums 183 bytes: 83e72d9eb69ab1189a45315ade9842dc7f7f450883f33ae3d58213c13ef29de8.

Fresh root and independent checks pass actual hashes/inventory/ZIP CRC/eight
binary C members/manifest snapshot/checksum text. Source C CI 38264447275,
T23 final feature CI 38270713277 and reconciled main CI 38271428429 pass.
Prior verified evidence head is fc108114978671de1948d5243e3a4bd835ff5640;
final preparation HEAD/live-ref/checks belong in the PR/response, avoiding self-SHA.

One trusted in-chat question asks approval of the exact filled request and its
main exception. Await the actual answer; never infer approval from elapsed time,
file existence or credentials. Record the real reply, request/notes hashes,
scope/reference and current UTC observation in evidence/T24-authorization.json.
Carry granted unchanged authority through T25–T27 without asking again.

The prepared external operator is release.py under the owned external
AFP-T24-2092a405 TEMP directory. It has not been run. Review before use: it requires
an approved exact record, revalidates C/main/CI/digests/conflicts before each write,
creates/pushes only the annotated v1.0.0 at C, independently checks the peeled
target, and creates a draft with --verify-tag --draft --target C and exact assets
plus RELEASE_NOTES.md. Record actual IDs/state; keep draft=true/prerelease=false.
Interrupted runs require fresh inspection/recovery; never force or clobber, and
preserve failed original reports. No release mutation before approval.

After actual A57/A58 pass, route to T25 in a new chat. T25 downloads/tests actual
draft assets; T26 publishes and independently downloads public assets; T27 performs
authorized reviewed docs-only closure and final main sync. Keep progress on the
evidence branch until closure. Tag/draft/ZIP are not project completion.

Human testing stays closed. Reuse unchanged T20/T21 assets/results and their
Samsung S24 / One UI 8.5 / AIMP v4.31.1747 / USB scope. Chapters unavailable,
navigation not run; prior physical limits persist. No new media/phone/Music check.
