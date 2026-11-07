# M4B release handover — v1.0.6

[AudioFileForPhone v1.0.6](https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.6) is a normal public release. The three assets were checked in the draft, then downloaded anonymously from GitHub and checked again. The public ZIP passed 13 package groups and independently validated 30 MP3s, including a real BAT run and both direct PowerShell routes. The 17 allowlisted members and the existing icon were verified.

Unencrypted M4B that the selected tools can decode produces one complete MP3 at the default 64 kbps CBR. The converter selects the first audio stream and copies supported container tags and chapter fields. Player support determines chapter navigation and resume. Existing formats, BAT and shortcut behavior, terminal presentation, source safeguards and strict output validation remain in use.

## Download and source

| Public asset | Bytes | SHA-256 |
| --- | ---: | --- |
| [AudioFileForPhone-v1.0.6.zip](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.6/AudioFileForPhone-v1.0.6.zip) | 297202 | `afae97d280f3fc410e220be2eb84c8cd1d49a71feb107d4fd46ee229f71b1e68` |
| [release-manifest.json](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.6/release-manifest.json) | 10316 | `cb9864ac6973ab912c9e4a8719ec6344cdb6ab83d75a6cb65deb81587d888cc3` |
| [SHA256SUMS.txt](https://github.com/PikkuJanne/AudioFileForPhone/releases/download/v1.0.6/SHA256SUMS.txt) | 183 | `d5db0e2309e55f64c01f060f9543a8be95c8213cc73974407a413f65187c2f3d` |

Tested source `6e2b3cbb87ba29c8140b80e722f2c443044f6def`. Annotated tag `v1.0.6` points to that source. [PR #42](https://github.com/PikkuJanne/AudioFileForPhone/pull/42) integrated the same tree as `c5dbd45670ad768d60e676bb86a5407c290edef7`. The [feature push CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42369259101), [PR CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42369263258), and [integrated main CI](https://github.com/PikkuJanne/AudioFileForPhone/actions/runs/42370479972) passed on both Windows Server 2025 shell jobs. The later documentation checkpoint keeps the tag and runtime bytes frozen.

## Automated verification

Windows 11 Pro 26H2 x64 build 26300.9711, Windows PowerShell 5.1.26100.9711 and PowerShell 7.6.9. Each shell passed two fresh synthetic 29-file mixed batches. The tests verified exact extension matching and read-only preview, AAC mono/stereo and ALAC, distinct shared-basename outputs, Unicode tags and chapter names/times, selected cover art, unreadable-book continuation, and a 7,203-second audiobook with a complete independent decode and correct beginning, middle and near-end seek samples.

The fragmented M4B recovered after an injected source-probe crash. Existing encoder and validator fault suites passed, including validation of identical completed bytes without another encode. Existing M4A regression passed five packaged 29-file runs and three direct replays. Local baseline, discovery, naming, preview, metadata and transactional output checks also passed. [Evidence](evidence/M4B.json)

The first long-book runs fully decoded but failed seek measurements sampled at decoder startup. Measuring after half a second of decoder warm-up passed on the retained outputs and in fresh runs. Earlier mutable-checkout integrity failures and a vendor HTTP 503 on the superseded PR run are recorded in the evidence. New platform coverage was Windows 11 client and supplementary Windows Server 2025. The BAT verification used an automated Windows console and an isolated Music folder.

The six earlier releases, 18 assets and 12 tag refs matched the pre-work inventory. No owner action is required. Future maintenance needs a new owner request.
