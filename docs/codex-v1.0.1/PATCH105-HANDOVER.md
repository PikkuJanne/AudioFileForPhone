# PATCH105 handover — COMPLETED — 2026-10-31

## Outcome

Published the normal [AudioFileForPhone v1.0.5 release](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.5), independently downloaded all three public assets without authentication, checked their hashes and all 17 ZIP members, and converted the available authorized private recording from those downloaded bytes in both PowerShell versions. Both outputs passed strict full decode and the expected duration, metadata, artwork and 64 kbps checks. Source bytes and creation/write timestamps stayed unchanged.

The earlier recovery covered M4A source probing. This patch also handles a narrowly classified, fully exited encoder, output-probe or validator crash with one fresh worker for that failed operation. Persistent crashes remain item failures and later good inputs continue.

The reported native crash was **not naturally reproduced**. Its underlying cause remains **UNPROVEN**. The full original 29-file batch was unavailable. Representative media and the available private fixture are identified separately; injected failures prove recovery behavior rather than native causation.

Owner action: **none**. No retest, upload, reinstall, PATH edit, sign-off or next chat is required. No automatic next step/version follows. Final documentation checkpoint hashes and exact-commit CI are observed after the containing commit and ordinary merge, avoiding self-referential evidence commits.

## Release identity and downloads

- Release ID: `430012191`; published `2026-10-31T15:28:19Z`; draft=false, prerelease=false.
- Frozen source/tag: `4cb6341ae5358faac28462643a9d67a5e3f9b424` / `v1.0.5`.
- Annotated tag object: `4a0ec0c2b2d5320688759d0bfec3c5e5bad31096`.

| Public asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [AudioFileForPhone-v1.0.5.zip](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.5/AudioFileForPhone-v1.0.5.zip) | 294085 | `17964b42e2cff1f8b95ebccf347ec05a2316caef6e439a2a841b39afb2d63d48` |
| [release-manifest.json](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.5/release-manifest.json) | 15194 | `fbc6451043e8809095830e5f994898fed9bfca179b79640179ec03593b609ea6` |
| [SHA256SUMS.txt](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.5/SHA256SUMS.txt) | 183 | `24c795e57b4941771ddc856252904cc1c4ae57832faec438604e6463dc388eef` |

The exact ZIP was validated before publication, downloaded from the authenticated draft and checked, then independently downloaded from its public URLs without authentication and checked again. The release tag and public assets remain frozen through documentation closure. All five previous releases, 15 asset identities/sizes/digests and 10 old annotated/peeled tag refs match the pre-work snapshot.

## Changes

`AudioFileForPhone.Helpers.ps1` recognizes a narrow set of Windows worker exception exits only when the native runner proves process exit, pipe drain and released handles. Stderr text alone never authorizes recovery.

An encoder retry removes only its identity-checked owned partial and reserves a fresh private temporary output. A validator retry keeps the same completed MP3 under a read guard and reruns only that validator on identical bytes; it does not re-encode. Read-only source/output probing uses the same one-shot classification where appropriate. The existing bounded M4A stream-copy source recovery remains intact. Logs and manifests retain both the original crash and final operation result.

Ordinary media errors, cancellation, timeout, access denial, disk-full errors and validation mismatches do not become retries. Duration, bitrate, metadata/artwork, full decode, source protection, honest counts and no-overwrite behavior remain. The app keeps the selected installation and never downloads/replaces tools during conversion. BAT/UI/layout, current artwork and 64 kbps CBR defaults are preserved.

Tests add a compiled test-only native seam and representative batch/direct-argv acceptance. No injection switch or test binary is shipped. Test-only PID-instance identity and explicit UTF-8 readers corrected verification flaws. CI retains all checks and security controls; its bounded job budget increased from 20 to 30 minutes for the added 24-case worker suite. Production timeouts did not change.

## Actual verification

Windows client: **Windows 11 Pro 26H2 x64, build 26300.9711**; Windows PowerShell **5.1.26100.9711** and PowerShell **7.6.5**. Isolated synthetic input, output, profiles and config were used. The ordinary Music folder and installed tools/settings were not changed.

| Check | Result and boundary |
| --- | --- |
| Observed vendor identity | October 15 essentials ZIP SHA `ca1c1b5214fed88dfa31f66f36e8d4aacf0cbf6b0d0de4a40716be9bcf902591` verified before execution; isolated matching pair. FFmpeg SHA `8713cce775e98fc09ed7c3cc5c21f10a6a9170561ce4943aa9d40bcc968c4bf4`; ffprobe SHA `377375905347c87de3d8fce4232d2f84ba12efd4f2d21ab9edb7633ae3494ffe`. |
| Baseline and exact candidate batches | Each passed three independent uninstrumented PS5.1 runs, one uninstrumented PS7 run and one separate forwarding-instrumented run: **29/29 each**, exit 0. Generated batch: 14 fragmented M4As, 15 normal M4As, one 1800-second recording, 225×225 JPEG and identical metadata overrides. Every output independently checked for full decoded duration, tags/artwork and 64 kbps; counts and source/package/tool integrity verified. |
| Direct comparison | Baseline and candidate each passed three complete direct replays of **121 actual native argument vectors**, including transaction-added progress/overwrite/format/private-output options; **29 independently validated outputs per replay**. Independent direct launcher bypassed the production runner and forwarding shim. |
| Healthy-path preservation | First uninstrumented baseline/candidate batches produced **29/29 byte-identical MP3s**. Test/CI hardening after `bb144f4` rebuilt to the same final ZIP hash. |
| Available private fixture | Baseline: six forwarding-instrumented packaged conversions plus three direct replays. Candidate: two uninstrumented actual-tool-directory runs. Each passed 4255.010249-second strict decode, tags, 225×225 JPEG, 64 kbps, 44100 Hz stereo and unchanged source bytes/timestamps. This fixture is not the original 29-file batch. |
| Exact ZIP fault injection | **24/24 per shell**: fresh encoder partial, validator identical-byte/no-reencode recovery, output/source probe recovery, persistent-crash continuation, unreadable input, ordinary-error exclusions, validation mismatch, timeout, cancellation and no-overwrite. Process identity checked 219 times per shell; recycled PIDs observed 1 and 2, with no same-instance leak. Runtime/input integrity and cleanup passed. Injection establishes behavior, not cause. |
| Existing safety suites | Transactional suite **27 cases + 61 matrix entries + 3 rejected-rate entries per shell** passed. Current-source native-process suite **35 cases per shell** passed sequentially after audio suites ended. Release, cleanup, ACL restoration and source integrity verified. |
| Package/build acceptance | **12 groups / 20 real outputs** passed across both app shells; BAT transport/pause/exit and Unicode checks passed. Builder policy **11 cases per shell** passed. Package has 17 allowlisted members, unchanged icon/layout and no native tools/media/tests. |
| Stable comparison | Separately verified 9.0.2 essentials pair passed a 29-file direct workload with strict full decode, bitrate, metadata/art and unchanged sources. It was a comparison, not a replacement for selected tools or the observed-build test. |
| Available local source coverage | **19 passing families / 960 checks + 3 observations per shell**, assembled from preserved actual prefix, resumed families and separate current-source controls/native checks. Original aggregates remain nonpasses; the local network gap below remains failed/unrun coverage. |
| Source/PR/main CI | Push `41212789658`, PR `41212795286`, integrated main `41214139395`: both shell jobs passed **20 families / 963 checks + 3 observations**, plus PATCH104's 8 cases and PATCH105's 24 cases each. Observed Server 2025 builds 26100.33650 and 26100.33674; PS5.1.26100.33648 and PS7.6.7/7.6.9; supplementary server coverage. Checkout IDs, tree equality, child report hashes and release/integrity/cleanup flags independently checked. |
| Public download | All three assets anonymously downloaded; exact hashes, source/tag identity, normal release flags, checksums and 17 members verified. Downloaded ZIP passed two uninstrumented private-fixture smoke conversions, one per client shell, on the observed October 15 pair. |

Commands and public-safe receipt hashes are in [evidence/PATCH105.json](evidence/PATCH105.json). Raw media, owner logs, complete argv and private report paths/identities remain outside Git/assets. No owner test kit is required.

## Retained nonpasses and limits

Both local real managed-download tests reached the unchanged **300-second body deadline**, cleaned their owned scopes and preserved source/fixture state. Each executed one failed case and left two cases **NOT_RUN**. The hosted equivalents passed. No network transport, timeout, selection, PATH, registry, execution policy or security control was changed to obtain a pass.

The original local PS7 short-operation case took **10153 ms** against the unchanged **10000 ms** assertion (operation budget 2000 ms). It remains a nonpass with cause **UNPROVEN**. A finite comparison ran once on baseline v1.0.4 and once on frozen v1.0.5: both passed all 16 unchanged cases, with cleanup/release/integrity proved. Native-runner and startup-prerequisite function text is identical between those versions. The comparison did not reclassify the original failure or establish causation.

Test-harness development/nonpasses were retained privately: singleton-array handling and shim file-sharing corrections, the initial automated cover-picker attempt that never converted media, default-ANSI reading of UTF-8 names, a numeric-PID-only release assertion, and a cover-check assertion that incorrectly expected audio progress. Final assertions use explicit UTF-8 and PID plus process start identity; intended validation was preserved. Original PID collisions cannot be proven because those initial reports lacked instance identity.

Windows 10 client, genuine Explorer conversion and human/phone listening were **not run or claimed**. No new owner task is attached to any gap. Native crash cause remains unproven.

## Git state and closure

Repository: [PikkuJanne/AudioFileForPhone](https://github.com/PikkuJanne/AudioFileForPhone).
The feature ref `codex/v1.0.5-batch-recovery` was independently advertised at frozen source `4cb6341ae5358faac28462643a9d67a5e3f9b424` after push. [PR #40](https://github.com/PikkuJanne/AudioFileForPhone/pull/40) merged normally as `cb0a0bb017fb8d2bcef52f6530c83e98b1fb009d` after exact-head push/PR CI passed. Its tree `416e5b39f752f3264d2782220afb0d3e87ddd8e6` equals the tested source and PR integration tree. Integrated-main CI also passed.

`codex/v1.0.5-release-closure` contains documentation/evidence only. Its containing checkpoint, fresh advertised branch/main refs, ordinary reviewed integration and exact-commit CI are checked after commit; the final checkpoint SHA is provided in the completion message. This avoids rewriting a released tag or creating endless self-referential evidence commits. Main may contain later documentation commits while the release tag remains on tested source.

## Human action and next step

**None.** This work order is complete. No owner acceptance kit, diagnostic request, playback/phone exercise, permission request or next numbered step remains. Preserve the published tag and bytes. Future maintenance requires a new owner request.
