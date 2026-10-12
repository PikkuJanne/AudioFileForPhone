# Prepared exact-candidate request — not authorization

The text below is prepared for owner review in T24. No approval is recorded yet.
The artifacts and acceptance results are linked from RELEASE_CANDIDATE.json and
evidence/T23.md. Main remains C; release gates are pending.

```text
Repository: PikkuJanne/AudioFileForPhone
Tag: v1.0.0
RELEASE_COMMIT = "2092a405c1d06eca336e771a0ed5d1881acd015a"
ZIP_SHA256 = "8fe8ac6752800f54dd58a7b454924ee5aa0b9b7153aa31457312ba3e1b2103cf"
MANIFEST_SHA256 = "7f354b2065b472f126316a1ceeae818e6133f59539eeaa526cab2a2e75609146"

I have reviewed the completed required acceptance evidence and this exact
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
