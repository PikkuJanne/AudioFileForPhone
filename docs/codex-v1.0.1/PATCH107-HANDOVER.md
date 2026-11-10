# Duration repair handover — v1.0.7

[AudioFileForPhone v1.0.7](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.7) was published and independently verified. Frozen source d279ca585ca28b3ff40ce00e99bd2cb499ab04c5. [Application ZIP](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.7/AudioFileForPhone-v1.0.7.zip) SHA-256 f0af636dc512ebeaa49ceb6df8002f0cb4dc2fe854ca3ca2bc362a731efcf9f5.

The anonymously downloaded ZIP passed 7/7 mixed inputs on each PowerShell edition, with one converted source warning per batch. The supplied MP3 passed with and without generated artwork. Both negative batches failed the unreadable input and converted the next valid file.

## Public assets

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [AudioFileForPhone-v1.0.7.zip](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.7/AudioFileForPhone-v1.0.7.zip) | 301230 | f0af636dc512ebeaa49ceb6df8002f0cb4dc2fe854ca3ca2bc362a731efcf9f5 |
| [release-manifest.json](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.7/release-manifest.json) | 10316 | 5098b3a64090c1bacb70656505fe2cc01f322bd0760e61113cb6ca862fc588dd |
| [SHA256SUMS.txt](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.7/SHA256SUMS.txt) | 183 | 5ab5cf491f44b8c0b9d0644fa1b623d87efe86109fa566f774e01df3f51712f5 |

[PR #44](https://github.com/PikkuJanne/AudioFileForPhone/pull/44) integrated the tested source as 9ffaf3ada873f5442cdfaf7c802728c0dcc1e43f. [Feature push CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42886805316), [PR CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42886816196), and [integrated main CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42889733983) passed both supplementary Windows Server 2025 shell jobs. The documentation closure follows the frozen source.

## Duration repair

The v1.0.6 public ZIP rejected the supplied MP3 on Windows after probing and
encoding succeeded. Its source header estimate was 2141.132750 seconds. The
selected original audio independently decoded to 47,434,752 samples at 22,050 Hz
(2151.235918 seconds). The corrected Windows outputs decoded to 47,435,281 samples
(2151.259909 seconds), a 0.023991-second difference within the unchanged
0.35-second codec tolerance. The original hash matched before and after.
A generated 609 × 1000 JPEG exercised artwork. The case passed with and without it.

The shortened-output control used an MP3 from the public ZIP's smoke test. It
kept a plausible 2151.259909-second header and exited zero on strict decode.
Its measured 2146.037551 seconds were
5.198367 seconds below the source, and validation rejected it. An unreadable output
also failed. A synthetic recoverable input warning retained a verified conversion
with all 180,864 available decoded samples at 44.1 kHz. A separate negative batch
failed its unreadable input and still converted the next valid file.

## Windows verification

- Client: Windows 11 Pro 26H2 x64 build 26300.9711. Windows PowerShell
  5.1.26100.9711 and PowerShell 7.6.9. Tests used the verified October 15 Gyan
  Essentials build from the original report, the October 8 reference pair and
  the repository-pinned 9.0.2 reference pair.
- The two representative 23-item source batches each published 23 verified MP3s,
  including one with a source warning. They exercised the original, synthetic
  no-Xing CBR/VBR, stale Xing, junk and damaged-frame cases, and ordinary MP3,
  M4A, M4B and OGG. Only one original chapter was supplied. The other 22 original
  chapters and the owner's artwork were unavailable.
- Exact ZIP: both shells published 7/7 mixed inputs with one source warning each,
  and independently verified the original with and without the generated cover.
  The relocated package suite passed 13 cases and 30 decoded outputs, including
  native BAT launch with isolated Music. The final commits updated test
  expectations and the release-target contract. Independent builds matched the
  tested application and core ZIP bytes exactly.
- Local immutable regressions covered transactional output, the compatibility
  corpus, metadata, diagnostics and cancellation. Earlier local full-CI attempts
  hit an immutable-checkout guard and vendor download timeouts. The exact hosted
  CI result is recorded separately.
- Windows 10, Explorer interaction and physical phone playback were untested.
  Owner testing required: none. The original, raw log, private work order and raw
  test reports are outside Git and release assets.

The local filesystem suite passed five cases per shell. The exact NativeProcess, Patch104 and Patch105 suites passed 35, 9 and 29 cases per shell. MeasuredDuration passed in both shells, and the progress suite passed 18 cases in each PowerShell edition. The earlier help-target and filesystem expectation failures are retained as nonpasses.

All seven earlier releases, 21 assets and 14 advertised tag refs matched the pre-work inventory after publication. No owner testing or automatic next version is pending. Future maintenance needs a new owner request. Preserve the released source tag and all published assets. [Verification evidence](evidence/PATCH107.json).
