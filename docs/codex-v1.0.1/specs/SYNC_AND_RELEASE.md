# Checkpoint, handover and release protocol

The v1.0.5 work order completed tested ordinary reviewed integration, normal
public publication and independent public-download smoke. Frozen source/tag:
`4cb6341ae5358faac28462643a9d67a5e3f9b424` / `v1.0.5`. See PATCH105-HANDOVER.md and
evidence/PATCH105.json. Owner testing/action: none. Its one-chat authority is
exhausted after documentation closure; no automatic next version follows.
Earlier records remain historical; preserve every released tag/asset/control.

## Completed v1.0.5 batch-repair authority — 2026-10-31

The current owner request incorporates the v1.0.5 batch-repair work order and
authorizes implementation, automated direct/package tests with the verified
observed build, ordinary reviewed PR/CI integration, a normal public corrective
release and independent public-byte verification in one chat. Historical stops
and separate approval requests do not apply to this bounded patch. Freeze and
validate the exact ZIP, verify draft bytes, publish, independently download/hash/
smoke and finish branch/main sync. Preserve controls and all old tags/assets.
No private recordings, raw logs or work-order contents in public Git or assets.

This patch is published and independently verified; see PATCH104-HANDOVER.md and
evidence/PATCH104.json in docs/codex-v1.0.1. Its one-chat authority is exhausted.
No automatic next version, owner test or new publication follows. Older records
remain historical.

## Completed v1.0.4 patch authority — 2026-10-31

The current owner request authorizes this bounded tested source-probe crash patch
through ordinary reviewed PR/CI merge, exact-package Windows verification, public
v1.0.4 publication and independent public-download smoke in one chat. It replaces
historical checkpoint stops and separate owner approval for this patch only.
Validate the exact ZIP, verify draft bytes, publish normal release, independently
download/hash/smoke, and close with main/live-ref sync. Owner testing: none.
Preserve old tags/assets and all controls. No private media/handoff/raw logs in Git.

## Active v1.0.3 patch authority — 2026-10-31

The owner's current request and incorporated v1.0.3 work order authorize this
tested patch through ordinary reviewed PR integration, required CI, public normal
release and independent public-download smoke in this chat. They supersede old
numbered stops and separate owner approval gates. Preserve existing access
controls, tags and assets. Freeze the exact integrated source, validate its ZIP,
verify a draft's exact assets, publish, independently download and convert from
those bytes, then complete final main/live sync. No new owner testing or sign-off.

## Active focused repair amendment — 2026-10-30

The owner-authorized REPAIR_BRIEF.md and active CHARTER amendment supersede
conflicting S01-S18 routing below. Apply the start/end checkpoint protocol to
R1/R2/R3, one step per chat. Owner testing required: none; all new checks belong
to Codex. No owner acceptance kit, phone check, retest or diagnostic request is an
active gate. Preserve old observations and waivers as historical evidence.
R1/R2 do not publish. Existing v1.0.0/v1.0.1 tags/assets remain unchanged;
historical S16/S17 authority is not authority for new corrective bytes. Reconcile
the release identity and exact tested assets before any R3 publication. Main
integration still requires ordinary review and the existing owner-approval
default. Feature branch push and fresh advertised-ref comparison remain required.
The numbered S14-S18 sections describe the old release and do not restart it.

## Start every thread

Read active state and previous handover; inspect repository identity, status,
current branch, relevant diffs and fresh live remote refs. Fetch ordinary refs
without rewriting local work. Inspect live tags/releases before any tag operation.
The expected origin is PikkuJanne/AudioFileForPhone (SSH or HTTPS spelling is fine).
Do not assume a source ZIP is a clone or that a prior thread's tracking ref is live.

Work one step only. If the step cannot be completed, preserve safe work and record
BLOCKED or IN_PROGRESS with exact remaining tasks; the next thread resumes it.
No automatic march through subsequent steps after a test finishes.

## End every numbered step

1. Run focused tests and required regressions; record the actual result, command,
   environment and tested runtime identity. Do not fabricate execution in an absent OS.
2. Review the actual intended diff, check whitespace, accidental private data,
   unrelated changes and runtime/default regressions. Do not use indiscriminate
   `git add .` when the worktree contains unrelated files.
3. Update STATE.json, STATUS.md, NEXT_SESSION.md and a step evidence file. List
   owner actions only when genuinely necessary; most steps have none.
4. Commit the intended files on the recorded branch, push that exact branch, then
   independently compare `git rev-parse HEAD` with the first SHA returned by
   `git ls-remote origin refs/heads/<branch>`. A tracking ref or 'push succeeded'
   message alone is not independent current sync evidence. Report missing network
   or permission as SYNC_BLOCKED; do not mark the whole step completed.
5. Check relevant GitHub CI for the exact pushed commit. Pending checks are pending;
   stop with a handover if they cannot be observed in the current session, and
   resume the same step later. Do not promise asynchronous monitoring.
6. Give the full HANDOVER.md structure and filled next-thread prompt. STOP.

During feature work, remote feature-branch sync is required each step. Main need
not contain incomplete work; report main integration separately. S14 integrates
verified work through the repository's ordinary merge/PR policy, then builds from
one clean main source commit. Never change protections or force updates to avoid
checks. Thereafter maintain the active branch/main state explicitly; preserve
other collaborators' commits and rebuild if they change packaged runtime content.

## Avoid self-referential commit evidence

A commit cannot contain its own final SHA. Store the tested prior code commit and
runtime-file hash set in versioned evidence. Record the final checkpoint HEAD/live
comparison in the final handover after push. NEXT_SESSION instructs the next thread
to refresh that comparison. Do not create endless documentation commits just to
embed a newer checkpoint SHA into itself. STATE must distinguish tested source,
active branch and frozen release source; they need not all be the same commit.

## S14 — freeze candidate

S12 supplies the read-only local gate described in RELEASE_GATES.md. At acceptance
use tools/Test-ReleaseGates.ps1 with the actual candidate record; before publication
use its Publication phase. A refusal is a missing/failed/stale evidence result,
never permission to waive client, package or human gates. A pass grants no release
authority and does not replace the live/draft/public checks below.

Recheck target v1.0.1 is unused; preserve the original v1.0.0 tag and asset digests.
Integrate code normally, require a clean commit, run full tests, then freeze source C.
Build by an explicit runtime-file allowlist from C, never `zip the working tree`.
Include all required helper/setup/check entry points, tiny pinned-download manifest,
README/SUPPORT/LICENSE/CHANGELOG and needed runtime assets. Exclude developer tests,
state/handover files, raw reports/media/config, caches, tokens, and FFmpeg binaries.

Use version 1.0.1 in runtime/package metadata but no public prerelease/tag yet.
The runtime artifact must be named AudioFileForPhone-v1.0.1.zip. Create a package member
manifest, hashes, tested dependencies and release-source record. ZIP and manifest
must not contain a circular self-hash: external SHA256SUMS hashes ZIP + external
release-manifest; that manifest can record ZIP hash and per-member hashes, not its
own hash. Keep packaging deterministic where practical and test actual bytes.

Run the extracted package from a clean path and owned input/output/config scopes.
Build the acceptance kit around this exact ZIP, not a rebuilt variant. Record a
SHA256 for both ZIPs. No candidate binary/media/raw report is committed to Git.
Deliver the kit as a local artifact or a permitted nonpublic workflow artifact.
A public source repository is not a private place to store owner reports.

## S15/S16 — acceptance and exact publication authorization

Gather the consolidated owner/OS report and automatic package evidence. Required
fields are not blank/PENDING/NOT_RUN. Successful setup is not a conversion pass.
Record failures honestly and fix them within S16's bounded repair scope; freeze a
new candidate if package/runtime/dependency content changed, then run impacted
checks and any necessary tiny owner retest. Do not auto-advance S16 while blocked.

Preserve accepted candidate bytes when only evidence/handover docs change outside
the package. Do not retag a later documentation commit or unnecessarily rebuild.
S16 records source C, package SHA/member hashes, test evidence, target tag, exact
asset filenames and digests, and proposed release notes. Its final next-thread
prompt explicitly states:

    Publish AudioFileForPhone v1.0.1 from source <C> using only the assets/digests
    recorded in <release-record path>, including runtime ZIP SHA256 <H>. Complete
    S17 only, verify the public downloads, give the handover, and stop.

Replace all placeholders with real verified values. This is the owner's simple
publication authorization when pasted in the next thread. If source/assets drift,
authorization does not follow the new bytes automatically.

## S17 — publish and independently verify

Refresh refs, permissions and release state. Verify the authorization matches the
record, accepted source and files. Verify C is present in main history. Check all
required gates and actual assets again. No credential copies in shell history/logs.
Create an annotated tag v1.0.1 at C only if unused, push without force and verify
the remote peeled tag resolves to C. Do not let a CLI default tag current HEAD.
Use a draft release for asset preparation. GitHub CLI --verify-tag avoids silently
creating a tag; confirm current command behavior from official docs [P7].

Attach the exact ZIP, release-manifest.json and SHA256SUMS.txt; download draft assets
through authenticated APIs into a fresh directory and verify all hashes/members.
Publish as a normal non-prerelease only after these checks. Never claim a draft is
public. Do not trigger website deployment or other repositories.

Then obtain the public release API record without authenticated owner access and
independently download the public asset URLs into another fresh directory. Verify
public availability, tag/peeled C, draft=false, prerelease=false, filenames/sizes/
SHA256s, ZIP members and packaged runtime versions. Execute the smoke test from
publicly downloaded bytes on an available required Windows host; byte identity plus
recorded acceptance ties the other required environment to the same content.
If public verification fails, report RELEASE_VERIFICATION_FAILED; do not claim done,
move tags or overwrite public binaries to hide it. Diagnose and give a handover.

Original v1.0.0 tag/release/assets must be unchanged. A previously published v1.0.1
requires reconciliation rather than an overwrite, including on resumed S17.

## S18 — closure

Commit redacted final evidence/docs (not media or private reports), synchronize
main using fresh live comparison, verify normal public release once more, and
record closure. The release tag stays on C. A later docs-only main SHA is expected.
Any runtime/package change after acceptance reopens the relevant steps rather than
being smuggled into a closure commit. Mark completed only when public release,
accepted assets, OS evidence and final main synchronization are verified.

## Fixed release identity — mandatory at freeze, publication and closure

Read RELEASE_TARGET.json before S14, S16, S17 and S18. Required identities are:

- Runtime/package version: `1.0.1`.
- Annotated Git tag and GitHub release tag: `v1.0.1`.
- Release title: `AudioFileForPhone v1.0.1`.
- Runtime ZIP: `AudioFileForPhone-v1.0.1.zip`.
- Public endpoint: `https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.1`.

Check all these values against the actual package and live GitHub response. Any
mismatch blocks publication/closure even when source hashes and other tests pass.
The plan must end with Codex publishing and verifying this public normal release,
not merely preparing artifacts for the owner to publish manually. Preserve the
S16-to-S17 exact-byte authorization and the mandatory stop after each step. If the
target already exists, reconcile it against evidence; never force, replace or
quietly bump it. The v1.0.0 tag and published assets remain unchanged.
