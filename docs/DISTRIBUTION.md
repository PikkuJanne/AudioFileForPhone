# User distribution

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

## Building

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

## v1.0.1 packaging correction

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
