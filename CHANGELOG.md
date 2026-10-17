# Changelog

## Unreleased v1.0.1 work

- Add explicit `-FfmpegDirectory` and portable `-ConfigPath` tool selection with
  deterministic explicit/saved/app-local/PATH precedence and bounded validation.
- Add deliberate atomic user-selection persistence through
  `Save-AudioToolSelection`; conversion and preview never save settings.
- Preserve short-operation deadlines and unlimited normal encode/full-decode
  runtime. Runtime version remains 1.0.0 until the planned package step.

## 1.0.0

Changes for app version 1.0.0. Publication and exact package verification are
recorded separately in the repository's
[release evidence](https://github.com/PikkuJanne/AudioFileForPhone/blob/main/docs/codex-v1/STATUS.md).

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

FFmpeg remains external. Loudness normalization is deferred. Named phone
acceptance covers Samsung S24, One UI 8.5 and AIMP v4.31.1747 over USB cable;
chapters were unavailable and navigation was not tested. See
[SUPPORT.md](SUPPORT.md#tested-boundaries) for the recorded limits.
