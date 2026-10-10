# T02 baseline regression matrix and selected v1 contracts

Source reviewed on 10 October 2026 at application baseline
`2bf1ea1921ab33633b978bd384bbbf098648ceed`. T01 was integrated into live main
at `483af25f8e5fa9dee295f5b74130324663339e37`; the application and original
integration suite remain unchanged. This document defines fixtures and assertions
before implementation changes. It is not an execution result. Actual observations,
environment, commands and acceptance results belong in `evidence/T02.md`.

## Baseline preservation matrix

Run each applicable row under Windows PowerShell 5.1 and PowerShell 7 using real
FFmpeg/ffprobe and only generated, short media. The legacy suite is retained; its
Music destination and cleanup require proven isolation before execution.

| ID / cases | Generated input or operation | Expected baseline assertion / measurement | Source locations |
|---|---|---|---|
| B01 / A04 | MP3/libmp3lame, M4A/AAC, OGG/Vorbis, uppercase `.OGG`/Opus; 0.4–3 seconds | Each produces one MP3 audio stream at the selected bitrate. Record source/output codec, channel count and sample rate. Uppercase matching works. | PS1 530–533, 643–645, 701–723; legacy tests 137–164 |
| B02 / A04 | Nested folders with spaces plus `.txt`, `.wav`, `.flac`, `.opus`, `.m4b` | Only MP3/M4A/OGG extensions are scanned. Preserve relative directories and the input folder leaf beneath the run root. | PS1 519–533, 568–580; legacy tests 133–145, 175 |
| B03 / A05 | Default options; mono/stereo sources at 44100 and 48000 Hz | Default requested bitrate is 64 kbps, `MaxBaseLength` is 60. Probe audio bitrate; inspect MPEG audio frame headers to establish CBR rather than using total container bitrate. Record actual channel/sample-rate behavior; the script adds no `-ac`, `-ar` or DSP filter. | PS1 204–207, 701–723 |
| B04 / A05 | Every successful short output | First bytes are ID3 with major version 3; exactly one MP3 audio stream; no source artwork by default. Fully decode short output with FFmpeg and record duration differences against the input probe. | PS1 680, 719–723; legacy tests 108–120 |
| B05 / A05 | Existing title plus artist, album, comment, track and disc tags in each supported container | Preserve existing title and source tags. Ogg comments come from the first audio stream; MP3/M4A use format tags. Capture actual disc/Unicode/quote behavior rather than inventing support. | PS1 643–680; legacy tests 147–173 |
| B06 / A05 | Missing title; leading date and punctuation in basename | Missing title becomes the allocated sanitized basename, including its collision suffix. Name whitelist keeps letters/digits/whitespace/hyphen/underscore, collapses whitespace and falls back to `Episode` for empty sanitized titles. | PS1 595–605, 682–685; legacy tests 141, 171–176 |
| B07 / A05 | Real leap date, impossible date, no date; set fixed `LastWriteTime` | Characterize current regex-only leading date behavior: impossible dates currently remain in the name. No-date names use `LastWriteTime` formatted `yyyy-MM-dd`. Record exact base truncation at 60. | PS1 586–605 |
| B08 / A05 | Same basename across MP3/M4A/OGG; equivalent sanitized names; long bases | Names remain distinct with suffix spelling ` (2)`, ` (3)`. Record input-to-output allocation order without assuming it is stable. Measure final basename length including suffix. | PS1 610–637; legacy tests 177–179 |
| B09 / A05 | 32x32 supplied JPEG, custom 96 kbps, Artist/Album overrides | One attached cover; preserved title; overrides take precedence; audio stream bitrate is 96000 bits/s. Record artwork codec/shape independently of audio bitrate. | PS1 688–713; legacy tests 182–197 |
| B10 / A05 | Input with attached artwork; explicit missing, wrong-extension or undecodable cover | Default artwork is dropped. Characterize baseline invalid-cover behavior separately: missing/wrong-extension cover is warned and ignored; an image extension alone is accepted and decoding may later fail. These observations are known deficiencies, not future acceptance passes. | PS1 287–294, 496–516, 698–723 |
| B11 / A05 | Unsupported-only/empty directory; missing input/tool; one valid and one corrupt audio file | Record actual process exit and summary for each outcome. Empty/unsupported inputs exit 1 but create a root/log/base first. Missing tool/input exits 1. Completed per-file failures lack an explicit aggregate exit and need reproduction. | PS1 429–449, 468–525, 541–545, 729–764; legacy tests 199–205 |
| B12 / A05 | BAT with zero/one/multiple arguments and a failing child | Zero arguments explicitly exit 1; characterize current one-folder forwarding, ignored extra arguments, unconditional `Done` and result after `pause`. Use an isolated child/argv fixture without interactive image dialogs. | BAT 7–10, 17–30 |
| B13 / A06 | All generated input trees, including ignored files | Compare sorted relative directory names, relative file names, lengths and SHA-256 values before/after conversion. Inventory image fixtures too. No source byte/name changes; no conversion output beneath input unless the explicitly isolated test layout requests it. | Safety invariant; legacy suite currently has no source-inventory assertion |
| B14 / A05 | Script copy outside input and configured Music resolver redirected only in the isolated test copy | Output is under the configured Music resolver, never beside the script. Preserve input leaf/relative layout and log location. Record the precise copy-only substitution and prove no writes/cleanup reach ordinary Music. | PS1 454–475, 519–525; legacy tests 67–105 |

## Selected v1 engineering choices, validation and implementation pending

These proposed choices refine D13–D17 within existing scope. Missing FFmpeg/ffprobe
prevents T02's empirical finalization; they must be validated, implemented and
tested in their owning tasks; source review or a failing baseline does not pass
their later acceptance gates. Defaults, automatic audio behavior and formats stay
unchanged. Duration tolerance remains a T09 decision informed by the B04 results;
T02 must not turn an unmeasured tolerance into a validated-output claim.

| Boundary | Selected contract | Required future checks / owning task |
|---|---|---|
| Requested bitrate | Accept only integer kbps values `8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320`; default 64. No free-format, ABR or VBR option. | Every accepted rate is tested with a compatible sample-rate fixture; reject 0, negative, 7, 65, 145 and 321 before prompts/writes. T04/A09 and T09/A24–A25. |
| Rate/profile compatibility | The whitelist is the union of documented LAME fixed rates, not a promise that every source sample rate can produce every requested rate. Keep baseline automatic encoder choices. A produced audio stream whose measured bitrate differs from the request fails validation; do not label rounding as success or add a forced sample rate to conceal it. | Low-rate MPEG-2/2.5 fixtures and MPEG-1 320 kbps fixture; incompatible/rounded case is a visible per-file failure. T05/T09. |
| Basename length | Integer `MaxBaseLength` 24–180 inclusive, default 60; unit is UTF-16 code units, excluding `.mp3` and including date, separator and suffix. Normalize NFC first and truncate only at a scalar boundary. This is a project limit, not a universal Android/MTP limit. | 23/24/60/180/181 boundaries; composed/decomposed accents, Finnish/German, permitted supplementary letters, emoji removal and empty sanitized titles. T04/A09, T07/A19–A21. |
| Date and suffix budget | Preserve the complete ten-character date plus ` - ` and at least one permitted title character, reducing title length for suffixes. At length 24, ` (9999)` still leaves four title units. If a counter or required suffix cannot fit, fail visibly without overwrite; do not reuse a number. | Date prefix survives minimum length; suffix transitions 9→10, 99→100 and 9999→10000; stable case-insensitive collision allocation. T07/A18–A21. |
| Impossible leading date | Use invariant real calendar parsing. On failure, use `LastWriteTime` and retain the entire original basename as the title input before sanitization. This avoids silently dropping an unrecognized original prefix. | Valid/impossible leap dates and non-default locale produce declared mappings. T07/A18. |
| Input kind and roots | Accept local filesystem directories on Windows 11; reject files, non-filesystem providers and drive roots with a specific preflight message. Keep canonical root spelling during rejection. UNC roots, live shares and removable/network storage are outside the tested support claim. | Local drive root and provider inputs fail before conversion/writes/prompts; bracket/space paths use literal semantics; separate prefix-neighbor containment checks. T04/A09–A11, T06. |
| Reparse and scanning | Reject a selected reparse-point input directory; skip and report descendant directory reparse points rather than following targets. Proposed T06 refinement: file reparse points also receive a recorded skip until a supported local-target contract is tested, to avoid source/cleanup boundary escapes. Any ordinary scan access failure aborts before conversions. | Owned junction/symlink loops and outside-target sentinels untouched; access-denied subtree causes zero conversions. T06/A15–A17. |
| Complete path | Conservatively reject any planned canonical file path of 260 or more UTF-16 units, including temporary working names; validate preserved directory components independently. Directory-creation paths must satisfy the applicable shorter legacy directory limit too. No extended-length-prefix/long-path support claim. | Below/at/over boundary for final and working paths; deep trees rejected with actionable diagnostic; no source-folder renaming or silent omission. T04/T07/T09. |
| Process results | Target codes: 0 all requested conversions succeed; 1 preflight/no supported files/fatal; 2 completed batch with per-file failures; 130 controlled cancellation where captured. Host-defined parameter-binding/forced-close codes remain honest limitations. BAT saves and returns child result across `pause`; exactly one folder. | Valid/empty/mixed/all-failed batches, BAT child exits and zero/multiple paths. T10/A27–A28, T11/A29–A30. |

The rate table comes from [LAME's upstream usage guide](https://github.com/lameproject/lame/blob/master/USAGE)
and the CBR option mapping from [FFmpeg's libmp3lame documentation](https://www.ffmpeg.org/ffmpeg-codecs.html#libmp3lame).
Exact media behavior still requires the installed Windows build. The conservative
path policy accounts for [Microsoft's documented legacy path limits](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation),
including the distinction between file and directory-creation paths; it does not
claim that an OS long-path setting makes both PowerShell families and FFmpeg safe.

## Known deficiencies to characterize, not preserve as successes

- PS1 586–588 accepts impossible dates; 595 removes decomposed combining marks and
  performs no NFC normalization; 604–605 can truncate the date at very small lengths.
  `BitrateKbps`/`MaxBaseLength` currently have only integer typing (204–207).
- PS1 451 trims a root separator; 442 checks resolution without directory/provider
  validation; 532 has no explicit reparse exclusion or prior-output recognition.
- PS1 468–475 reuses a second-resolution run root and truncates its log; conversion
  writes directly to a final `.mp3` with `-y` (702/717). Success uses only native
  exit status and path existence (731), with no size/probe/duration validation.
- PS1 653–676 discards probe stderr and ignores its exit status, conflating failed
  inspection with missing title. Logs and file existence/collision operations use
  wildcard-capable path parameters in several places (475–493, 578, 618, 731).
- PS1 763–764 does not aggregate failures into an explicit exit. BAT 29–30 always
  prints `Done` and pauses without saving or explicitly returning the child result.
- Legacy tests 76–98 wait around timestamp reuse, then infer ownership from a
  snapshot/name rather than exclusive creation. Cleanup at 210–218 is under ordinary
  Music; a concurrent creator is not proven excluded. Do not run it blindly.

Each runtime reproduction is a separate observed result in T02 evidence. Unrun
rows remain unrun; blocked media execution keeps A04–A06 blocked until isolated
execution is completed. The T03 scheduling exception applies only when isolation
is the sole blocker; it does not waive a missing native dependency.
