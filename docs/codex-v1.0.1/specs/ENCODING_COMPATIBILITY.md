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

Include M4A AAC-LC, HE-AAC or ALAC where the chosen build can generate/decode a valid
fixture, MP3 CBR/VBR, Ogg Vorbis/Opus, missing/empty/Unicode title, and artwork.
A fixture-generation limitation is NOT evidence that the converter rejected valid
input. Use licensed public/synthetic fixtures with provenance only as necessary;
never acquire private media or encrypted material. Existing unsupported extensions
(.m4b/.wav/.flac/.opus) remain outside scanner scope for this release.

Use the reference Windows build and a second current capability-compatible build,
including the owner-observed Git-style build where available. Keep exact tested
builds in evidence, not an overly restrictive runtime dependency policy.

## Duration validation investigation

Test long VBR recordings, AAC edit lists/padding, short clips, inaccurate header
duration, unknown/N/A duration, silence, and deliberate payload truncation. Preserve
strong detection of truncated outputs. Do not simply widen 0.35 seconds to a percent
of a multi-hour book. When a legitimate mismatch is reproduced, improve the source
duration basis (for example selected-stream decoded duration on an explicit fallback)
and document bounded tolerances. Never trim/pad/stretch audio just to pass a check.
A fallback may be more expensive; trigger it only when warranted and show its phase.

No duration-policy change is mandatory without a demonstrated issue. Every policy
change must carry both a real-valid-media regression and a retained truncation test.
