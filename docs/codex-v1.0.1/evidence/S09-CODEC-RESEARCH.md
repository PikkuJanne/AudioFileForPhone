# S09 codec capability reproduction

Recorded 2026-10-27 on the active Windows 11 Pro 26H2 x64 client,
build 26300.9711. This is independent native encoder research, not a claim
that the application matrix or either shell's application regressions passed.
Both owned research drivers ran with portable PowerShell 7.6.5 and
`-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned`. UTF8 input,
output and native redirected streams use CP65001. Native children use
`UseShellExecute=false`, `CreateNoWindow=true`, and are individually waited and
disposed. No personal media, Music folder, owner configuration, conversion
download, persistent configuration or process-wide termination was used.

The checkout identity recorded by both research drivers was
`f7fe6529c50fe9bd2bbf8acd440d804160bc3564`. The native research does not load
application code. Its input WAVs are synthetic 330 Hz, 1.1-second PCM generated
at 8/48 kHz and mono/stereo. All four WAV hashes remained unchanged.

## Exact binaries

| Build | Tool | SHA256 |
| --- | --- | --- |
| Gyan 2026-10-08 Git ec420ba161 | ffmpeg.exe | `54474e51fd3612a9e6654fed5a0b746cfe51984cc055ea0075195c1cc786ad2b` |
| Gyan 2026-10-08 Git ec420ba161 | ffprobe.exe | `ff735e9bf07ec6ccd6aeb2005a727f49f36a96ee9664a8d9d7deca7628544f20` |
| Gyan 9.0.2 essentials | ffmpeg.exe | `3256173f3f8bffd7df12227c68adf68025edb1832273a9530688a7bb1ed8edec` |
| Gyan 9.0.2 essentials | ffprobe.exe | `f0d36ecbbdd3bcfac3efa078c96c7271c2e68b3810595552ac3b7f17e9a65c52` |

Git tools are the existing `C:\ffmpeg\bin` selection. Reference tools are the
unchanged existing S08 development provision in private TEMP; no new provision
or download was required. Both `ffmpeg -hide_banner -h encoder=libmp3lame`
responses advertise sample rates 44100, 48000, 32000, 22050, 24000, 16000,
11025, 12000 and 8000 Hz, sample formats s32p/fltp/s16p, and mono/stereo layouts.

## Reproduction and result

For each build the independent driver generated all 324 combinations of nine
output sample rates, all eighteen advertised bitrates, and mono/stereo, using
the independent 48 kHz PCM source. It ran the following argument shapes with
literal owned paths (angle-bracket names below are redactions):

```text
ffmpeg -hide_banner -v error -nostdin -f lavfi -i sine=frequency=330:sample_rate=<source-rate>:duration=1.1 -ac <channels> -c:a pcm_s16le -y <source.wav>
ffmpeg -hide_banner -v error -nostdin -i <source.wav> -map 0:a:0 -c:a libmp3lame -b:a <requested>k -ar <sample-rate> -ac <channels> -y <result.mp3>
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels,bit_rate,duration -of json <result.mp3>
ffmpeg -hide_banner -v error -xerror -nostdin -i <result.mp3> -map 0:a:0 -f null -
```

Both builds produced identical capability results: all 324 encode/probe/full
decode operations succeeded; 216 combinations matched requested bitrate, rate
and channels exactly; 108 were silently clamped to another bitrate. Decode
success alone therefore cannot establish a valid requested bitrate.

The exact-result combinations were:

| Planned sample rates (Hz) | Exact CBR bitrates (kbps), mono and stereo |
| --- | --- |
| 8000, 11025, 12000 | 8, 16, 24, 32, 40, 48, 56, 64 |
| 16000, 22050, 24000 | 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160 |
| 32000, 44100, 48000 | 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 |

A separate twenty-output driver omitted `-ar` and `-ac`, matching the old
audio argument shape. These five shapes, each mono/stereo and each build,
confirmed all reported leads and the default controls:

| Source rate | Requested bitrate | Observed stream bitrate | Observed rate |
| --- | --- | --- | --- |
| 48000 Hz | 8 kbps | 32 kbps | 48000 Hz |
| 48000 Hz | 144 kbps | 128 kbps | 48000 Hz |
| 8000 Hz | 192 kbps | 64 kbps | 8000 Hz |
| 48000 Hz | 64 kbps | 64 kbps | 48000 Hz |
| 8000 Hz | 64 kbps | 64 kbps | 8000 Hz |

The raw report and synthetic files remain in the new owned private codec
research scope. Public evidence is limited to these factual summaries/hashes:

- Full 648-combination report SHA256:
  `131b132cc489496ffb81da762210938976af5f4fbfaf76fc3db72ebfceb342e7`.
- Full-matrix driver SHA256:
  `ccfd5d2655784f5092b1b908dd8f15509b1264292a7f560a44342dcf2358048a`.
- Twenty-output old-argument report SHA256:
  `64e1666742f54fdb32790b4aeb5e7c37941baabdf3ce14bdc5e65a16d4319a06`.
- Old-argument driver SHA256:
  `e45def6e3b4df350467ed1b12a04be1e5a73319032ea12b448c58bded6a1aab1`.

## Primary-source interpretation

LAME's [bitrate/sample-rate tables](https://raw.githubusercontent.com/lameproject/lame/master/libmp3lame/tables.c)
identify the three rows as MPEG-2, MPEG-1 and MPEG-2.5; their contents agree
with every exact native result above. Its
[FindNearestBitrate and BitrateIndex implementation](https://raw.githubusercontent.com/lameproject/lame/master/libmp3lame/util.c)
selects the separate MPEG-2.5 row below 16000 Hz. Thus the low-sample-rate
encoder limit is 64 kbps, even though MPEG-2 allows rates through 160 kbps.
The tested 8 kbps setting works in both channel shapes throughout the first
two rows; 144 kbps is available only in the middle row.

The FFmpeg libmp3lame wrapper for the
[reference source commit](https://raw.githubusercontent.com/FFmpeg/FFmpeg/946fcce07b6dcd0331c8cc609192aeff5e1924f8/libavcodec/libmp3lame.c)
and [observed Git source](https://raw.githubusercontent.com/FFmpeg/FFmpeg/ec420ba161/libavcodec/libmp3lame.c)
sets both LAME input/output sample rates from the selected codec rate, and
uses `lame_set_brate` for CBR. That explains why relying on an unsupported
bitrate at a retained sample rate clamps without an encode failure.

Planning implication: preserve a mono/stereo source's rate whenever its row
admits the requested bitrate. Otherwise explicitly select a compatible
supported rate and validate it. Preserve 64 kbps shape/rate where already
correct. The encoder supports no multichannel output; select and document a
stereo downmix explicitly, or reject that source before encode with an
actionable incompatibility. Neither behavior should rely on FFmpeg's implicit
automatic channel choice. Application integration, source odd/low-rate and
multichannel coverage, manifests, metadata, and both-shell verification are
recorded separately by the S09 application harness.

## Production known-layout downmix supplement

Actual Windows production-helper reproduction completed at source
`57f90c4f73c385b0b0e562f487b8cf945a60de2a` on the same client and portable
PowerShell 7.6.5. The helper SHA256 before and after every supplement invocation
was `6d8909240e163e5f856e6d9a36609dc00d9d627ac940ba76df0b398872e136fe`.
No production code was modified by this research. The owned UTF8 drivers
dot-sourced that exact helper and used its hidden native process runner.

Each source was generated independently from an `aevalsrc` graph with one
distinct 220 + 110*n Hz tone per channel, amplitude 0.04, 48000 Hz and duration
0.75 seconds. An independent ffprobe had to report the exact requested layout,
count and rate; a strict source decode then had to succeed. Only such a fixture
could enter the production `Get-AudioMediaInfo`, `Get-AudioOutputPlan`,
`Get-AudioMetadataPlan`, `New-AudioEncodeArguments` and
`Invoke-AudioOutputTransaction -OutputPlan` path.

Twenty production transactions succeeded: all ten supported layouts on each
recorded FFmpeg build. Every plan retained 48000 Hz, explicitly selected two
output channels and `Downmix=true`, and reported `Resample=false`. Every
transaction validated 64000-bit/s MP3, 48000 Hz and two channels, completed its
strict full decode with release proof, published its final output and left no
owned partial. An additional independent output probe confirmed those values.
Encode and full-decode timeouts remained zero. All selected source hashes were
unchanged after conversion. Both builds used these actual fixture choices:

| Exact observed source layout | Channels | Selected source codec/container |
| --- | --- | --- |
| 2.1 | 3 | AAC-LC / M4A |
| 3.0 | 3 | ALAC / M4A |
| quad | 4 | AAC-LC / M4A |
| 4.0 | 4 | ALAC / M4A |
| 5.0 | 5 | ALAC / M4A |
| 5.0(side) | 5 | FLAC / Ogg (`.ogg`) |
| 5.1 | 6 | ALAC / M4A |
| 5.1(side) | 6 | FLAC / Ogg (`.ogg`) |
| 6.1 | 7 | Vorbis / Ogg |
| 7.1 | 8 | AAC-LC / M4A |

Fixture limitations were checked rather than relabeled as passes: ALAC
canonicalized 2.1/quad/7.1 to its supported layouts; ALAC and AAC canonicalized
6.1 to 6.1(back), while Vorbis preserved 6.1. ALAC, ordinary AAC and Vorbis
canonicalized the two side layouts to 5.0/5.1; libopus refused those requested
side layouts. Forced AAC PCE, including explicit output channel-layout options,
also yielded 5.0/5.1. Those mismatched fixtures were never sent through a
claimed side-layout transaction. Explicit-layout Ogg FLAC preserved both side
labels, passed independent source probe/full decode, and supplied the four
successful production side-layout cases. This uses the existing supported
`.ogg` extension; scanner extensions were not changed and `.flac` remains
outside scope.

Representative fixture-generation argument shapes:

```text
ffmpeg -nostdin -hide_banner -v error -f lavfi -i aevalsrc=exprs=<one-distinct-tone-per-channel>:s=48000:d=0.75:c=<layout> -c:a <alac-or-aac-or-libvorbis> <fixture.m4a-or-fixture.ogg>
ffmpeg -nostdin -hide_banner -v error -f lavfi -i aevalsrc=exprs=<one-distinct-tone-per-channel>:s=48000:d=0.75:c=<side-layout> -channel_layout <side-layout> -c:a flac <fixture.ogg>
```

All raw reports/drivers/synthetic files remain in a new owned private layout
research scope. Report and driver identities are:

| Report | Actual outcome | Report SHA256 | Driver SHA256 |
| --- | --- | --- | --- |
| Initial layout attempts | 16 production successes, four side-fixture limitations | `c8dd8616b1766bb9963a2d554e769b032c60db44b8dd9005abe3180ba0689f53` | `4fe5ff637b987474dd68366a1ba697a464ac7f10de2461ae66ec5fcd5b69d898` |
| Forced AAC PCE | Four side-fixture limitations, no claimed production cases | `7e9f9a726f621cc75c23dce636213093a2e999a1d09786c7fe53c400006514f0` | `2cd60705c90906d41f07d5d6146cdf0708ecf4b895dfd3e695135c8cedf3e002` |
| Explicit layout plus PCE | Four side-fixture limitations, no claimed production cases | `b017812265104e03691c18168a60dd4c0810a7c31f984d501eeacdbed5da97d8` | `a8f9d246f6dac9cb8483745bdd17eedd71c6d59266383e4580242a604a0fd3ff` |
| Exact side-layout Ogg FLAC | Four production successes | `5e59db58f5a63bd94986634175e5725ae7c939fe28fb7a77dd44fd4cac7b3650` | `74b8e5d472c40430edad27af9030b27c2c0f08fac7db238962d90544a1c7ab25` |

All 180 directly tracked fixture-generation/independent-check native calls
across those reports returned release and pipe-drain proof without truncated
capture. Nonzero exits are retained for deliberately unsupported fixture
generation; they are not production failures. The successful transactions
additionally exercised production probe, capability, encode, validation and
decode release guards; every successful case records the output decode's
release proof and both unlimited-runtime assertions.
