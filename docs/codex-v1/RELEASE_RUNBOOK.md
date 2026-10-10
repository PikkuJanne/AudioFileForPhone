# Release runbook — complete only after public v1.0.0 and final sync

This is a gated operator runbook, not a script to paste blindly. Check every native
exit code immediately. All placeholders must be replaced from reviewed evidence.
No command should infer source from an advancing default branch. Official command
references S7–S10 are retained in SOURCES.md; recheck installed CLI help at release.

## Gate 0 — Preconditions (T22)

Improvements 1–15 have real evidence. All required automated/Windows/phone cases
before publication pass; remaining release-only cases are explicitly pending. No
blocking defect, dirty tree, unresolved merge or undocumented compatibility claim.
O01 is deferred or, when explicitly activated, fully tested. Final version/help/
README/license/build/CI are integrated under approved merge policy.

Record live repo identity, default branch and actual checks on the integrated
commit. Confirm no earlier public release, prerelease or conflicting v1.0.0 tag was
introduced. Existing remote releases/tags are not deletion targets; stop/reconcile.

## Gate 1 — Freeze source C and package bytes (T23)

1. On synchronized main, record full commit C. All source/tests/CI/build and shipped
   docs are now frozen. No evidence has to contain its own containing commit SHA.
2. Build exact C in a clean detached test worktree on the same active machine.
   Stage outside the repo; do not package an arbitrary working directory.
3. Run required automated checks on C. Extract and test the exact ZIP under both
   Windows shells, with launcher/dependency smoke. Rerun affected manual tests.
4. Produce three assets per specs/RELEASE_PACKAGE.md. Verify safe member inventory,
   per-member hashes, ZIP/manifest hashes, license/docs and no third-party binaries.
5. Create a release-evidence branch `codex/v1-release-evidence` based on C. Store
   candidate/evidence/handoff only under docs/codex-v1/. Push and verify its live
   head. Keep main at C until closure. This preserves cross-thread/machine continuity
   without changing the candidate or requiring impossible self-hashes.

Track candidate fields using templates/RELEASE_CANDIDATE.example.json. No null,
placeholder or stale SHA can pass the release gate. Keep private raw logs/media out.

## Gate 2 — Exact owner authorization (T24)

Use the supplied RELEASE prompt filled with C, ZIP SHA-256 and manifest SHA-256.
Record the approval reference/date and allowed operations. It applies across
T24–T27 until bytes/scope change; do not ask for the same approval every thread.
A missing approval is a blocker, not project completion.

Recheck live main still C, evidence branch differs only by allowed progress files,
CI/tested source still matches, and local staged bytes match approval. Rebuild or
source change invalidates asset authorization. Respect existing protections.

## Gate 3 — Annotated tag and draft (T24)

Representative commands, AFTER validating the variables and absence of conflicts:

```powershell
$repo = 'PikkuJanne/AudioFileForPhone'
$tag = 'v1.0.0'
# $C, $zip, $manifest, $checksums and $notes are reviewed absolute values.
git tag -a $tag $C -m 'AudioFileForPhone v1.0.0'
if ($LASTEXITCODE -ne 0) { throw 'Tag creation failed.' }
git push origin refs/tags/v1.0.0
if ($LASTEXITCODE -ne 0) { throw 'Tag push failed.' }
# Independently compare the peeled target below to C before draft creation.
git ls-remote origin 'refs/tags/v1.0.0' 'refs/tags/v1.0.0^{}'
if ($LASTEXITCODE -ne 0) { throw 'Live tag read failed.' }
# STOP here until the returned peeled commit is verified equal to C.
gh release create $tag $zip $manifest $checksums --repo $repo --verify-tag --draft --title 'AudioFileForPhone v1.0.0' --notes-file $notes
if ($LASTEXITCODE -ne 0) { throw 'Draft creation/upload failed.' }
```

Never force an existing tag or use release upload --clobber. For an annotated tag,
the tag-object SHA and peeled commit SHA are different concepts; compare the
peeled `^{}` entry to C, not merely the tag object. --verify-tag avoids implicit
creation at the current default branch. Keep release draft=true, prerelease=false.
A tag or draft is not completion. Record exact asset names/IDs and sizes.

For interrupted retries: inspect existing state first. Reuse an already verified
correct draft/tag only under the same recorded authorization. Wrong public bytes,
wrong target or conflicting tag requires explicit remediation; no silent replacement.

## Gate 4 — Verify actual uploaded draft assets (T25)

Use a new empty download directory and authenticated draft read:

```powershell
gh release download v1.0.0 --repo PikkuJanne/AudioFileForPhone --dir $FreshDraftDownloadDirectory
if ($LASTEXITCODE -ne 0) { throw 'Draft download failed.' }
# Check exact file set, hashes, inventory, then extract safely and smoke.
```

Compare every downloaded asset to reviewed local expectations. Test the downloaded
ZIP, not a leftover build tree. Record source C, downloaded hash, shell/FFmpeg
versions, real command/results. Upload failure or mismatch blocks publication.
No public release needed just to learn whether the package is complete.

## Gate 5 — Publish once (T26)

Recheck authorization, draft asset bytes, tag C, checks and release state. Then:

```powershell
gh release edit v1.0.0 --repo PikkuJanne/AudioFileForPhone --draft=false --prerelease=false --latest
if ($LASTEXITCODE -ne 0) { throw 'Publication command failed; inspect actual state.' }
# Independently read real public state.
```

Publishing may make release assets immutable under repository policy. Do not
change settings to work around that. The normal public release must contain all
assets before this step. No v0.x releases or public release candidates.

## Gate 6 — Independent public downloads (T26)

Use unauthenticated API/HTTP reads to verify public repository and published
v1.0.0 (draft=false, prerelease=false, published_at present), expected asset names,
nonzero sizes and tag target C. Download ZIP, manifest and checksums into a fresh
location without credentials. Verify approved SHA-256 values and all ZIP members,
then run the public-downloaded ZIP smoke on Windows. Authenticated download alone
does not prove public access. Local staging hashes alone do not prove uploaded bytes.

Optional stdlib helper after actual publication/closure:

```powershell
py -3 .\docs\codex-v1\tools\verify_release.py --repo-path . --candidate .\docs\codex-v1\RELEASE_CANDIDATE.json
```

It checks technical public state/bytes plus clean main synchronization, not manual
listening or the truth of self-reported evidence. Before final closure its main
check is expected to fail if the active checkout is still on the evidence branch;
perform the gate's individual reads then rerun the combined helper after T27.
Network/auth/API limits are verification failures, never offline passes.

## Gate 7 — Closure main D (T27)

Create closure evidence recording public URL/time/tag/C/artifact digests, tests,
limitations and actual pending-free core scope. Integrate only docs/codex-v1 progress/
evidence from the evidence branch under recorded closure authority. Main becomes D.
Prove C is an ancestor of D, and the ENTIRE C..D diff contains no changes outside
docs/codex-v1/. Do not retag C to include the closure record.

Fetch/reconcile local main normally, require clean worktree, and compare local HEAD
to fresh live GitHub main. Re-run public technical verification. Report final SHA
and live comparison in the final session response/PR comment rather than create
an endless “latest SHA” commit chain. Archive evidence references, not private media.

## Definition of done

Required improvements/tests are evidenced; public normal v1.0.0 exists; actual
public assets match the approved candidate; released ZIP smoke passes; immutable
tag points to C; final local main equals live GitHub main D; only allowed evidence
changes separate C/D; no outstanding publication or sync blocker. Publish URL,
C, ZIP/manifest hashes, final D, test scope and honest limits in the closure response.
