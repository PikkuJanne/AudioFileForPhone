# Windows CI and release boundary

The Windows CI workflow runs on every branch push and normal pull request. It
checks syntax, selected correctness/security analyzer rules, actual pure runtime
contracts, the retained isolated real-FFmpeg baseline and native-process tests
under Windows PowerShell 5.1 and PowerShell 7. Tests create short synthetic audio
in exclusively owned TEMP trees; the owner's ordinary Music folder is not a test
destination. Local Windows 11 results and hosted Windows Server results are
recorded separately.

## Workflow authority

Only `contents: read` is granted. Checkout uses the event's `github.sha`, with
credentials persistence, cleanup, submodules, LFS and unsafe PR checkout disabled.
For a pull request this is the temporary merge integration commit; the feature
head is recorded separately. Branch-only push filters exclude tag pushes. There
is no privileged PR target/workflow-run event, secret reference, release job,
write permission, self-hosted runner or automatic public release.

The reviewed actions are pinned to full commits in their official repositories:

- [actions/checkout v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1):
  `3d3c42e5aac5ba805825da76410c181273ba90b1`.
- [actions/upload-artifact v7.0.2](https://github.com/actions/upload-artifact/releases/tag/v7.0.2):
  `cf430e030ddbb5b0abf93d22962f4752f3646cd9`.

Both use Node 24. Checkout requires runner 2.327.1 or newer. The
[`windows-2025` hosted image](https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-Readme.md)
is mutable, so each report records the actual image, OS and shell version. No
preinstalled FFmpeg or analyzer is trusted. These choices follow GitHub's
[secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use).

## CI-only dependencies

`.github/dependencies.json` locks fixed publisher release URLs, archive lengths,
SHA-256 digests, complete extracted file inventories and entry-point digests.
`Initialize-CiDependencies.ps1` downloads only into a fresh marked TEMP child.
It verifies archive bytes before extraction or execution, rejects unsafe ZIP
members and reparse paths, and verifies the extracted inventory. No PATH,
PSModulePath, machine-wide installation or production downloader is added.
Checks independently verify the locked dependency payload before module import.

- Gyan FFmpeg/ffprobe 9.0.2 essentials ZIP: archive SHA-256
  `60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba`.
  [FFmpeg's download page](https://ffmpeg.org/download.html) links the external
  Windows publisher. The fixed [Gyan checksum](https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip.sha256)
  agrees with the [GitHub release asset digest](https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2).
  Setup queries versions and `libmp3lame`, `aac`, `libvorbis`, `libopus` encoders
  plus the MP3 decoder; retained tests actually convert and decode media.
- [PowerShell/PSScriptAnalyzer 1.25.0](https://github.com/PowerShell/PSScriptAnalyzer/releases/tag/1.25.0):
  nupkg SHA-256 `14e634c828eb98efb9f40b2918ba90f139ed5eccdf663a2a747736d996995d60`.
  The official release's published asset digest matches the downloaded package.

Hashes pin reviewed publisher bytes; they do not independently authenticate the
publisher or prove absence of vulnerabilities. Dependency updates require a
reviewed lock change and fresh checks. Only current-run JSON evidence is uploaded,
with 14-day retention. Raw child logs, media and downloaded binaries stay outside
Git and artifacts. Failed checks remain failed even when evidence upload succeeds.

## Release gate

CI has no release-writing capability. The existing `RELEASE_RUNBOOK.md` requires
prepublication automated, Windows and phone acceptance, reviewed integrated commit
C, validated exact ZIP/manifest bytes and recorded owner approval before tag/draft.
Release-only cases remain explicitly pending until draft/public bytes exist; the
runbook gates verification before publication and closure. No tag is moved and no
public bytes are replaced to include later closure evidence. T17 does not grant
main integration, settings changes or release approval.

For local reproduction use the exact supported shell, call dependency setup with
a fresh `AFP-CI-<GUID>` direct TEMP child and a fresh
`docs/codex-v1/evidence/T17-dependencies-ps51/ps7-finalN.json`, then call
`Invoke-CiChecks.ps1 -DependenciesPath <that JSON> -RunLabel finalN`. Reports use
CreateNew and never overwrite previous attempts. The dependency root remains
available after checks; remove only that exact positively verified owned tree.
