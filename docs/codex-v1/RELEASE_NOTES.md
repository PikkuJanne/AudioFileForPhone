# AudioFileForPhone v1.0.0

Convert MP3, M4A and OGG audio to 64 kbps CBR MP3 for phone listening with the
existing PowerShell script and BAT launcher. Output goes to an exclusive run
folder under the configured Music destination, preserving relative folders,
date-first filenames and the documented metadata behavior.

- Preview the planned conversion without encoding, or select an output parent.
- Validate paths, FFmpeg/ffprobe capabilities and optional cover artwork before
  conversion; skip reparse points and recognized generated output folders.
- Encode to partial files, validate and fully decode audio before publishing
  each completed MP3; retain completed files when other inputs fail or cancel.
- Use bounded progress, useful exit codes and local diagnostic/run records.

Extract the ZIP with its files together. FFmpeg and ffprobe are required external
tools and are not included. Read the included README and SUPPORT for installation,
PowerShell execution-policy guidance, metadata precedence and troubleshooting.
The scripts are unsigned; SHA-256 checks describe integrity, not publisher
authentication. Loudness normalization remains deferred.

Automated source and exact-package checks ran on Windows 11 with Windows
PowerShell 5.1 and PowerShell 7, including the retained real-FFmpeg integration
suites. Named phone acceptance covers Samsung S24, One UI 8.5, AIMP v4.31.1747 and
USB transfer. Chapters were unavailable and chapter navigation was not tested.
See the repository's [acceptance evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md)
for the recorded scope and limits.

Release source: `2092a405c1d06eca336e771a0ed5d1881acd015a`.

The three release assets are `AudioFileForPhone-v1.0.0.zip`,
`release-manifest.json` and `SHA256SUMS.txt`. The manifest records the frozen source,
package members, dependency provenance and signing observations. SHA256SUMS.txt
lists the ZIP and external manifest digests.
