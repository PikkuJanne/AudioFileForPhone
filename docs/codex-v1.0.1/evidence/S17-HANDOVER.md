# S17 handover — public v1.0.1 verified

## Outcome

Published AudioFileForPhone v1.0.1 as a normal public release, ID429170892:
https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.1
All three authenticated draft downloads and independent anonymous public downloads
match the unchanged frozen assets. Annotated tag v1.0.1 resolves to tested source
 d9d7129e9463de17e29c2a36752c82e326abf22e. Runtime1.0.1 and all18 ZIP members match.

## Changes

Only release/tag operations and sanitized evidence/routing documents. Exact assets
and owner authority are in S16-RELEASE-RECORD.json. No package rebuild, dependency
change, public-byte replacement, tag move, visibility/protection change or owner
media access. The original v1.0.0 release/tag/assets are preserved.

## Verification

| Check | Exact command/artifact | Environment/result | Evidence |
|---|---|---|---|
| Annotated tag | git tag -a v1.0.1 d9d7129e9463de17e29c2a36752c82e326abf22e; git push origin refs/tags/v1.0.1; git ls-remote | Tag object and peeled source verified | S17.json annotated_remote_tag_refs |
| Draft | gh release create ... --verify-tag --draft; gh release download ... | 3 asset hashes/sizes,18 member hashes,version1.0.1 pass | Draft verification digest in S17.json |
| Public release | gh release edit v1.0.1 --draft=false --prerelease=false --latest --verify-tag | Published 2026-10-30T15:08:54Z; correct ID/tag/title/flags | Public API proof in S17.json |
| Anonymous downloads | Fresh HttpClient, no Authorization/default credentials; API plus all3 browser_download_url assets | All HTTP200; exact sizes/SHA256 | public-verification.json digest in S17.json |
| Actual public-byte smoke | Invoke-PublicZipSmoke.ps1 -ZipPath anonymous-download/AudioFileForPhone-v1.0.1.zip | Win11 Pro26H2 26300.9711 x64 Client, PS5.1.26100.9711/PS7.6.5; 4 outputs each,raw0 | Smoke SHA256343f5c4e7454ba617d130a6d0a71ef66ee5b739b8c4cb9da7a5900e30d37a7f7 |
| Media/source integrity | Actual probe/full-decode of8 outputs; source/package/dependency hashes | 64000bps MP3,metadata/date/layout/counts correct; unchanged inputs/package/tools/config | 26 natural child exits,52 raw capture hashes verified |
| Old release | Anonymous old API plus fresh remote tag refs | v1.0.0 release/tag/3asset IDs/names/sizes/digests equal S01 | postpublication-preservation digest/proof in S17.json |

## Nonpasses and limits

Draft-by-tag API returned404 after successful creation; authenticated release-list
API recovered the existing unique draft without creating a duplicate. The first
public-byte smoke failed before conversion because inherited PS7 module paths hid
native PS5.1 Get-FileHash. The private harness now supplies installed native module
directories only to that PS5.1 child. Runtime/public bytes and parent/user settings
are unchanged; original failed report and diagnosis are retained with exact hashes.
Fresh public-byte smoke passes. No old failure is relabeled.

Five original client/collection/physical/phone gates remain OWNER_WAIVED and
NOT_VERIFIED under the owner's explicit publish/finish instruction. The unmodified
original release gate still refuses missing reports. Automated Windows11 success
does not establish the waived observations. Release notes disclose these limits.
Raw captures/binaries remain private at C:/projects/AFP-S17-20261030.

## Git state and human action

Publication source is already in main history. Release-tag C is distinct from the
later docs-only checkpoint. Feature/main equality and exact-head CI for the final
containing closure commit are observed after ordinary reviewed integration.
No human action or further authorization is requested.

## Next step and stop-rule supersession

Finish S18 documentation integration and fresh main sync in this chat under the
owner's explicit project-completion instruction. Historical one-step stops are
superseded. Do not move the tag or replace public bytes for closure documentation.
