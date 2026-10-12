# Next session — T25 actual uploaded draft verification

T24 A57/A58 pass. Exactly next: T25 in a new chat. A59–A65 remain pending;
O01 deferred. Draft exists and is unpublished; release/project incomplete.

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS first, then tasks/T25.md, RELEASE_RUNBOOK.md, RELEASE_CANDIDATE.json,
evidence/T24.md, evidence/T24-authorization.json, evidence/T24-tag-draft.json
and evidence/T24-independent-draft-review.json. Inspect
actual Git/remote/dirty/PR/check/tag/release state; preserve unrelated work.

The owner explicitly answered "Approve exact v1.0.0 request" to the trusted
question containing C, all three asset hashes, T24–T27 operations and the existing
early docs-only main merge. Actual question/reply/request/notes hashes and scope
are in evidence/T24-authorization.json. Carry unchanged authority without asking
again: exact tag/draft/upload, conditional normal public publication after actual
draft/download gates, and reviewed docs-only T27 closure. Changed C, bytes, hashes,
scope or a newly failed required gate invalidates approval; state the precise blocker.

Frozen C remains 2092a405c1d06eca336e771a0ed5d1881acd015a. Approved live main
remains cf03cf7097640fcac287e24f6a90ff003e5fe0be, the owner's existing PR #24
merge. C is an ancestor; all 100 C-to-main paths are docs/codex-v1. The actual
approval accepts only this early evidence-only timing exception. Keep main there
until T27 and later progress on codex/v1-release-evidence; do not merge PR #25 early.
No source/shipped/test/CI/build file may change; never retag C or rebuild silently.

Annotated v1.0.0 tag object: 279945f7d5a4b887b7bd44eae5244b03060f76cc.
Fresh independent advertised peeled tag and remote tag-object API both resolve
to C. Draft ID410779813 has tag_name v1.0.0, target_commitish=C, draft=true,
prerelease=false and published_at=null. GitHub's authenticated draft URL uses
untagged-cd686fe416ddfbca6302; that representation does not change the verified tag.
Use gh release view/download v1.0.0 with the exact repository, or authenticated
asset APIs if necessary. Reinspect actual state before using any stored metadata.

Expected actual assets:

- AudioFileForPhone-v1.0.0.zip, ID634242834, 53,958 bytes,
  SHA256 8fe8ac6752800f54dd58a7b454924ee5aa0b9b7153aa31457312ba3e1b2103cf.
- release-manifest.json, ID634242836, 4,162 bytes,
  SHA256 7f354b2065b472f126316a1ceeae818e6133f59539eeaa526cab2a2e75609146.
- SHA256SUMS.txt, ID634242837, 183 bytes,
  SHA256 83e72d9eb69ab1189a45315ade9842dc7f7f450883f33ae3d58213c13ef29de8.

Local originals remain at local_staging_directory in RELEASE_CANDIDATE.json.
T24 independently verifies actual uploaded names/IDs/sizes/server digests and
approved notes. Server metadata/local originals are not actual downloaded-byte
evidence. A59 requires a new empty owned TEMP download directory, authenticated
download of all three real draft assets, exact hashes/inventory/member equality,
safe fresh extraction and both-shell/launcher/dependency smoke of downloaded ZIP.
Do not publish in T25. Preserve failures and never clobber/replace/delete state.

Reuse docs/codex-v1/tools/test_t23_zip.py only after inspecting its interface,
actual source hash and the recorded T23 invocation. Bind fresh downloaded-byte
hashes, driver hash, shell/tool versions, commands/results and preservation gates.
Keep ordinary Music/personal media outside the test. Use fresh report/run labels;
inherit the existing CP65001 console and documented child-only module-key handling.
Do not change frozen application/tests/build sources or weaken strict comparisons.

Source C CI38264447275, approved-main CI38271428429 and preparation push/PR
CI38272786200/38272911927 pass. Prior verified feature checkpoint is
c7c6c91dfb064464c35b611bd92fe90f349e5a26. Final T24 HEAD/live-ref/new CI are in
PR #25/response; inspect live state again and avoid self-containing commit hashes.

Human testing remains closed. Reuse unchanged T20/T21 named scope and assets:
Samsung S24 / One UI 8.5 / AIMP v4.31.1747 / USB; chapters unavailable and navigation
not run; prior physical limits persist. No human retest/long regeneration/media scan.

After A59 passes, hand off to T26 for conditional publication and independent
unauthenticated public downloads/smoke. T27 then integrates reviewed docs-only
closure, verifies final clean local/live main D and frozen tag C. Never declare
project completion from a prepared ZIP, tag or draft alone.

Copy-ready prompt: **T25 next please**.
