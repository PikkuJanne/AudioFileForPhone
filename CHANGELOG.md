# Changelog

## 1.0.0 - unreleased

App version established for the planned first release. No frozen ZIP, phone
acceptance or verified public release is claimed by this entry.

- Preserve recursive MP3/M4A/OGG conversion to 64 kbps CBR MP3 by default, the
  configured Music destination, relative folder layout and date-first filenames.
- Add an optional output parent, read-only preview, deterministic filename and
  collision planning, and exclusive per-run output folders.
- Validate tools, input/output paths and explicit covers before conversion;
  exclude reparse points and recognized generated runs during discovery.
- Encode to recognizable partials, validate and fully decode audio before final
  publication, and preserve completed outputs after independent file failures.
- Report meaningful batch exit codes, bounded progress, controlled cancellation,
  local diagnostic logs and structured per-file manifests.
- Preserve source metadata with documented title/Artist/Album precedence;
  replace artwork only with an explicit cover and document chapter/player limits.
- Retain isolated real-FFmpeg tests on Windows PowerShell 5.1 and PowerShell 7;
  add supplementary Windows CI with verified external test dependencies.
- Provide comment-based help, executable examples, one runtime version source
  and unsigned-script/support guidance.

FFmpeg remains external. Loudness normalization is deferred. Packaging and
device/manual acceptance continue before publication.
