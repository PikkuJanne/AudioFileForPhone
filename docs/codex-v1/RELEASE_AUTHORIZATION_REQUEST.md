# Prepared exact-candidate request — not authorization

The text below is prepared for owner review in T24. No approval is recorded yet.
The artifacts and acceptance results are linked from RELEASE_CANDIDATE.json and
evidence/T23.md. Release gates are pending. T24 freshly rechecks all three local
asset hashes and the eight ZIP members against C before requesting approval.

## T24 main reconciliation included in this request

The owner merged T23 evidence PR #24 at 15:36:02Z on 12 October 2026. Live main is
`cf03cf7097640fcac287e24f6a90ff003e5fe0be`, instead of C. C is an ancestor;
all 100 changed paths are under docs/codex-v1 and main's complete tree equals
the reviewed T23 evidence head. Runtime, shipped files, tests, CI and build rules
are unchanged. No reset, rollback, rebuild or change to the candidate is proposed.

Approval of this request also accepts that existing early evidence-only merge
as a narrow exception to the main-at-C timing rule in RELEASE_RUNBOOK Gate 2 and
SYNC_PROTOCOL. Retain C and the exact approved assets. Require live main to equal
the reconciled SHA above until authorized T27 closure; any further change needs
fresh review. Keep subsequent T24–T26 progress on the evidence branch and merge
the reviewed docs-only closure only in T27. This exception does not authorize a
new source commit, different package bytes or general main integration.

Proposed draft/public release notes: [RELEASE_NOTES.md](RELEASE_NOTES.md).
The same reviewed notes and assets will be used for the draft; T25 downloaded
draft verification must pass before T26 publication.

```text
Repository: PikkuJanne/AudioFileForPhone
Tag: v1.0.0
RELEASE_COMMIT = "2092a405c1d06eca336e771a0ed5d1881acd015a"
ZIP_SHA256 = "8fe8ac6752800f54dd58a7b454924ee5aa0b9b7153aa31457312ba3e1b2103cf"
MANIFEST_SHA256 = "7f354b2065b472f126316a1ceeae818e6133f59539eeaa526cab2a2e75609146"
CHECKSUMS_SHA256 = "83e72d9eb69ab1189a45315ade9842dc7f7f450883f33ae3d58213c13ef29de8"

I accept the existing docs-only PR #24 merge at main
cf03cf7097640fcac287e24f6a90ff003e5fe0be as the narrow timing exception described
above, retaining RELEASE_COMMIT and all exact asset bytes.

I have reviewed the completed pre-release candidate acceptance evidence and this exact
candidate. I authorize creating and pushing the annotated v1.0.0 tag at
RELEASE_COMMIT, creating a draft release, uploading the reviewed ZIP,
release-manifest.json and SHA256SUMS.txt, and publishing it as the normal public,
non-prerelease v1.0.0 after all draft/download checks pass. I also authorize the
reviewed docs-only closure PR integration after publication. No different source
commit or changed asset bytes are authorized by this prompt.

Follow docs/codex-v1/RELEASE_RUNBOOK.md through T24–T27 in task-sized sessions.
Record this authorization and carry it across threads; do not ask for the same
approval again unless the commit, payload, scope or hashes change.

Recheck live repository, main, CI, tag/release conflicts and the candidate hashes
before each external write. Never move an existing tag, overwrite public assets,
use upload --clobber, delete existing releases, weaken protections, or publish a
prerelease. Stop on a mismatch and state the exact blocker.

After publication independently download the real public assets without auth,
verify hashes/ZIP contents, and run the released ZIP smoke check on Windows.
Close the project only after the final local main equals live GitHub main and
the tag still resolves to the tested release commit. The frozen release commit
may precede final main only by allowed progress/evidence changes. Do not retag
just to include a later closure record. Report release URL, commit, hashes,
actual test evidence, final sync and any documented limitations.
```
