# User distribution

## Corrective v1.0.2 candidate (unpublished)

The owner selected v1.0.2 for the corrective release. The active identity is
recorded in `docs/codex-v1.0.1/CORRECTIVE_RELEASE_TARGET.json`; the historical
`RELEASE_TARGET.json` and published v1.0.0/v1.0.1 remain unchanged. A version
selection does not authorize publication of any unverified or changed bytes.

The application ZIP contains exactly these four visible root entries:

```text
AudioFileForPhone.bat
AudioFileForPhone.ico
README.txt
app/
```

The existing ICO, 17-file final allowlist, direct BAT-to-converter route, literal
folder transport, CMD pause/exit and process-only policy request are preserved.
Required helpers, setup, dependency pin, diagnostics, support and license stay
under `app/`. Both BATs have explicit CRLF. FFmpeg remains external; conversion
never downloads it, and separate setup requires consent for a download.

Build the exact-source core payload with `tools/Build-Package.ps1`, using the
authoritative helper version 1.0.2 and `-TargetTag v1.0.2`. Its intermediate assets
belong in a new directory separate from the final user assets. Then run:

```powershell
.\tools\Build-UserPackage.ps1 -SourcePath 'C:\build\source' -SourceCommit '<full commit SHA>' -RuntimeAssetDirectory 'C:\build\core-assets' -OutputDirectory 'C:\build\candidate-assets'
```

Both intermediate and final ZIPs are named `AudioFileForPhone-v1.0.2.zip`, but
have different contents and hashes. Distribute only the final small-root user
ZIP, together with its final `release-manifest.json` and `SHA256SUMS.txt`. The
builder checks all 18 core members against the clean detached source commit,
copies the existing icon from that commit, and records all 17 final member
hashes, generated-entrypoint provenance and the exact source. Unsafe paths,
reparse ancestors, changed inputs and existing output directories are refused.

The final manifest identifies app version 1.0.2, tag v1.0.2 and artifact kind
`corrective_release_candidate`. Layout revision 3 remains a layout identifier.
`publication_authorized` stays false: a build and a passing test report grant no
publication or main-integration authority. Exact tested-source/asset approval
and all required R3 automated acceptance remain separate publication gates.

Run `tests/Test-UserPackageBuild.ps1` under both supported shells and verify the
exact final ZIP with `tests/Test-UserPackage.ps1` using isolated synthetic media,
owned output/configuration and external trusted tools. The optional builder
`-PackageTestEvidencePath` accepts only a passing `user_package_verification`
report bound to app version 1.0.2, this corrective artifact kind, the exact source
commit and ZIP SHA256. Attaching evidence changes the external manifest and
checksums; the verified ZIP itself must remain identical. Test changed final
bytes again before publication. Owner testing required: none.

The short root guide names the v1.0.2 application ZIP and release page, explains
shortcut/icon use, dependency selection and visible errors, and points to the
license and detailed support under `app/`. It contains no internal repair-step
branding. Ordinary users should select the application asset on Releases.

## Historical focused-repair R2 candidate (unpublished)

The following preserves the R2 build contract and candidate evidence. Reproduce
it from its recorded R2 source; it is not the current builder's version contract.
The canonical R2 ZIP and its historical records remain unchanged.

The repaired application ZIP has exactly four visible root entries:

```text
AudioFileForPhone.bat
AudioFileForPhone.ico
README.txt
app/
```

The existing icon is copied from the exact source commit, without modification.
The root BAT directly invokes `app/AudioFileForPhone.ps1` in the built-in x64
Windows PowerShell 5.1 STA host. It retains R1's literal folder transport,
process-only Bypass request, CMD-owned pause and preserved exit result. Both
packaged BATs have explicitly generated CRLF bytes, including optional standalone
setup under `app/`. Direct PS7 use is `app/AudioFileForPhone.ps1`.

The final allowlist is in `tools/Build-UserPackage.ps1`: 14 app members plus the
three root files. Required helpers, diagnostics, setup, the dependency pin,
support documents and license remain together under `app/`. The old launcher,
host probe and redundant BATs remain in Git and the intermediate core payload;
they are excluded from the user ZIP. Developer material, tests, acceptance kits,
promotional PNGs, generated output and FFmpeg binaries are also excluded.

Build the intermediate core assets using `tools/Build-Package.ps1` from a clean,
detached exact source commit and actual dependency/test records. Then run:

```powershell
.\tools\Build-UserPackage.ps1 -SourcePath 'C:\build\source' -SourceCommit '<full commit SHA>' -RuntimeAssetDirectory 'C:\build\core-assets' -OutputDirectory 'C:\build\candidate-assets'
```

The final builder verifies every core member against that source's Git blobs,
reads the icon from the same commit and refuses dirty source, modified inputs,
unsafe paths and existing output. It creates `AudioFileForPhone-R2-candidate.zip`,
`release-manifest.json` and `SHA256SUMS.txt`. The manifest records generated BAT
and README provenance, exact member/icon digests and no publication authority.
Package revision 3 identifies the layout; it is not a release version. Runtime
version 1.0.1 is retained pending R3 release-identity reconciliation. No tag is
selected and no existing release is changed.

Run `tests/Test-UserPackageBuild.ps1` in both supported shells for build/refusal
policy, and `tests/Test-UserPackage.ps1` against the exact final ZIP for relocated
layout/icon, real isolated conversions, concise console, setup and native BAT
pause/exit checks. All media and destinations are synthetic and owned. Native
console argument tests do not establish an Explorer drop or successful BAT
encoding to the ordinary Music folder. R3 acceptance remains a separate step.
Owner testing required: none. R2 does not publish.

## Historical published v1.0.1 package revision 2

The following records the preserved public package, not the repaired candidate.

The downloadable package presents six files and one folder at the top level:

```text
AudioFileForPhone.bat
AudioFileForPhone.ps1
Setup-AudioFileForPhone.bat
Setup-AudioFileForPhone.ps1
README.md
LICENSE
app/
```

The original runtime files, optional check utility, dependency pin and detailed
documentation stay together under `app/`. They are application dependencies;
removing the diagnostic/helper modules breaks conversion or setup. Tests, raw
logs, acceptance reports, development plans, personal media and FFmpeg binaries
are excluded from both runtime and user ZIPs.

The top-level PS1 entry points retain the original parameter declarations and
forward bound parameters and exit codes to the implementation. BAT entry points
retain literal environment-based folder transport. They do not reparse `%*`.
Explicit/saved/PATH tool discovery is unchanged. Application-local FFmpeg means
both binaries beside the actual scripts in `app/`; this location is stated in
the short README. No tools are copied or installed by conversion.

### Historical revision 2 building

The current user-package builder is deliberately limited to the three original
published v1.0.1 assets, pinned by digest. It does not accept arbitrary new runtime
builds or another version; review and extend that contract before future releases.

`tools/Build-Package.ps1` remains the exact-source runtime payload builder used by
the existing integration/acceptance tooling. Its flat payload ZIP is an input to
the final user-distribution step, rather than the file to upload directly.

```powershell
.\tools\Build-UserPackage.ps1 -RuntimeAssetDirectory 'C:\build\runtime-assets' -OutputDirectory 'C:\build\user-assets'
```

The input directory contains the original v1.0.1 runtime ZIP, external release manifest and
SHA256SUMS. The user-package builder verifies those inputs, maps the original
runtime members under `app/`, generates the small top-level entry points and
guide, and produces the final ZIP plus matching manifest/checksums. Output must
be a fresh directory. No download, Git change or publication happens in a build.

Run `tests/Test-UserPackage.ps1` against the extracted final distribution using
owned synthetic inputs/output/configuration and existing external tools. It
checks actual ZIP bytes, PS1 parameter forwarding and real PS5.1/PS7 conversion,
setup persistence, optional checks and instrumented BAT argument transport.
Instrumented BAT coverage is not a physical Explorer observation.

### Historical v1.0.1 packaging correction

The owner rejected the original flat presentation and explicitly requested a
clean distribution after publication. Packaging revision 2 keeps runtime version
1.0.1, the original release tag and the original core payload bytes. Generated
entry points, their source mapping and packaging-tool identity are recorded
separately in the revised external manifest; they are not called unchanged Git
blobs. The revised ZIP has its own digest and package-test evidence.

Original assets are backed up privately before publication changes. Revised
assets are uploaded and downloaded for verification under temporary names before
canonical-name cutover. After anonymous public verification, temporary originals
are removed from the release while their digests and private backups are retained.
The release notes identify the correction. Asset renames are not an atomic
three-file update. The release tag and v1.0.0 assets are never moved or replaced.

Historical S14-S18 records describe revision 1. Their original ZIP/kit hashes and
missing observations remain historical evidence; they are not relabeled as
acceptance of revision 2. The packaging-correction record identifies current
distribution hashes and actual new-layout tests.
