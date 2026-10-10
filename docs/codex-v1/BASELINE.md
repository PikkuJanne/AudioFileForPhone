# Inspected baseline — 8 October 2026

Repository: PikkuJanne/AudioFileForPhone. Reviewed branch: `main`.
Full commit: `2bf1ea1921ab33633b978bd384bbbf098648ceed`. Commit timestamp: 2026-10-01 15:16:23 UTC.
Commit subject: “Save converted audio in the user's Music folder”.
The GitHub release listing was empty when rechecked for this bundle.

This is a source inspection, not proof of runtime behavior. T01 must fetch and
reconcile the actual repository; never rewind it to this commit. No repository
files, settings, branches, tags or releases were modified while building the bundle.

## Existing files

`AudioFileForPhone.ps1`, `AudioFileForPhone.bat`, `README.md`, `LICENSE`, `.gitignore`,
three image/icon assets and `tests/Test-AudioFileForPhone.ps1`. No checked-in CI
workflow appeared in the recursive tree at the inspected commit. Git blob IDs,
not SHA-256 digests, are recorded in `baseline.json`.

## Preserve and characterize

Input: .mp3, .m4a and .ogg (Vorbis/Opus), extension matching case-insensitive.
Output: MP3, libmp3lame, configurable bitrate default 64 kbps CBR; do not force mono
or change channel/sample-rate handling without measured baseline evidence.
`MaxBaseLength` default 60; date-first naming with LastWriteTime fallback. Mirror
relative folder layout. Output under the Windows configured Music folder, not
beside the script. Preserve title when present, Ogg stream tags, ID3v2.3 and
Artist/Album overrides; source artwork is not copied by default. Separate supplied
cover is optional. No actual loudness normalization currently exists.

## Source-review risks to reproduce

Final filenames are direct FFmpeg destinations with overwrite enabled, and success
uses exit status plus path existence rather than probing output. Run-root timestamp
resolution is one second. Batch failure results and BAT exit propagation need
explicit contracts. Scanning can include previous output when a parent is chosen.
ffprobe errors are not sufficiently distinguished from missing title metadata.
Preflight, literal paths, deterministic collision ordering and cancellation require
strengthening. Current tests generate synthetic fixtures but write outputs into
real Music; they include timestamp waiting to avoid reused run roots.

Do not mark any of these as fixed from this document. Reproduce, implement and
record evidence under the linked tasks. Tests may reveal different or additional
root causes; preserve the requested outcome without mechanically following an
outdated implementation suggestion.

## Primary references

- https://github.com/PikkuJanne/AudioFileForPhone/commit/2bf1ea1921ab33633b978bd384bbbf098648ceed
- https://github.com/PikkuJanne/AudioFileForPhone/blob/2bf1ea1921ab33633b978bd384bbbf098648ceed/AudioFileForPhone.ps1
- https://github.com/PikkuJanne/AudioFileForPhone/blob/2bf1ea1921ab33633b978bd384bbbf098648ceed/tests/Test-AudioFileForPhone.ps1
- https://api.github.com/repos/PikkuJanne/AudioFileForPhone/releases
