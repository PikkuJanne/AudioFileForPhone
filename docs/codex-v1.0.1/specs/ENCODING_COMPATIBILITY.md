# Encoding compatibility without weaker validation

## Goal

Every supported advertised bitrate either produces the promised MP3 at the chosen
rate or gets an actionable incompatibility error BEFORE encoding that source.
No unnoticed bitrate clamping followed by an expensive late rejection. Do not
remove accepted parameter values merely to make the test matrix green.

## Investigation and plan

Extend media probing to capture selected audio codec, sample rate, channels and
channel layout. Use the existing first-audio-stream selection and metadata policy.
Record the source-to-output sample-rate/channel decision in the plan/manifest.
Keep ordinary 64 kbps cases unchanged where the current output is already correct.
Preserve mono and stereo; multichannel needs an explicit documented downmix decision,
not an undocumented version-dependent FFmpeg choice. Do not silently make all files
mono, add loudness filters, or alter content duration to fit validators.

Reproduce the previous reported bitrate cases on recorded Windows builds first.
Consult the selected libmp3lame encoder's supported sample rates and source/official
codec references as needed. Derive a tested mapping for supported sample rates and
MPEG bitrate constraints. Do not use an unverified table from assistant memory.
Choose a compatible output sample rate where resampling is justified; report the
choice, and validate its actual output. Reject a combination that cannot satisfy
the documented contract. Preserve configurable bitrate values that can be supported
by an explicit compatible resampling plan. Internal representative fixtures are
acceptable; do not encode every user source twice merely to probe the bitrate.

Add explicit `-ar` / `-ac` only according to the tested plan; placement follows
FFmpeg input/output option scoping [P2]. One shared argument builder supplies cover
and no-cover conversion. Metadata and attached-cover streams must not accidentally
change the selected audio stream. Keep CBR behavior, duration checks, staged output
and full decoding. Compare stream bitrate rather than total container bitrate that
includes artwork. Validate sample rate/channel shape too when the plan promises it.

## Automated matrix

Test all currently advertised bitrates against representative 8/16/22.05/24/32/44.1/
48 kHz mono/stereo fixtures; add low/odd rates and multichannel where the decoder
supports them. Generate source fixtures independently of the requested output plan.
The expected result is either correctly planned/validated output or a deliberate
pre-encode rejection with a stable reason, not arbitrary allowed failure.

Include M4A and unencrypted M4B AAC-LC, HE-AAC or ALAC where the chosen build can
generate/decode a valid fixture, MP3 CBR/VBR, Ogg Vorbis/Opus, missing/empty/Unicode
title, and artwork.
A fixture-generation limitation is NOT evidence that the converter rejected valid
input. Use licensed public/synthetic fixtures with provenance only as necessary;
never acquire private media or encrypted material. Existing unsupported extensions
(.wav/.flac/.opus) remain outside scanner scope.

Use the reference Windows build and a second current capability-compatible build,
including the owner-observed Git-style build where available. Keep exact tested
builds in evidence, not an overly restrictive runtime dependency policy.

## Duration validation

Treat source probe durations as progress and diagnostic hints. A missing or
invalid header duration may still accompany a usable source. Independently read
the selected original audio stream through the end and measure its duration from
decoded samples, accounting for the effective sample rate and skip/discard data.
Use bounded diagnostics and retain no PCM. The source pass may use the same
tolerant decoding policy as conversion. A normal, complete read yielding usable
audio may carry source warnings. A fatal error or incomplete read fails the item.

Check the staged output's header and independently measure its duration with a
strict full decode. Use the measured source reference and the existing fixed
0.35-second tolerance for codec padding and resampling. A staged output may be
published only after all format, bitrate, shape, metadata and validation checks
pass. Reuse the per-file source measurement through retries of the same source.
Log reported and measured durations with their origins, the difference and the
tolerance. Count outputs with source warnings as converted and report them
separately. Preserve the original source and the no-overwrite transaction.

Test long VBR recordings, AAC edit lists/padding, short clips, demonstrably
inaccurate or unavailable reported durations, recoverable source errors, and
unreadable sources. Retain a control where the output loses audio despite a
plausible header and successful strict decode. A successful conversion must
retain the measured recoverable source duration within the fixed tolerance.
