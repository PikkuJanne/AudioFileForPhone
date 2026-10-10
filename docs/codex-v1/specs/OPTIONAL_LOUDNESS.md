# Optional O01 — not required for initial v1.0.0

This feature stays deferred unless the owner explicitly activates it before the
candidate freeze. Core improvements 1–15 and public release do not depend on it.
It is not permission to add a DSP toolbox, presets UI or change the default sound.

Use an opt-in switch, off by default. A measured two-pass loudnorm pipeline must
measure the same selected channel layout/preprocessing as the application pass.
Record target loudness/true peak, source measurements, chosen output sample rate,
normalization mode and deviations. Choose/document project targets from listening
and measurement tests rather than call them a universal podcast standard.

FFmpeg documents linear/dynamic modes and fallback constraints; dynamic processing
can upsample internally, so output rate must be explicit. Consult S6 at
implementation time. Silent/short inputs or invalid/non-finite measurements need
clear policy; never interpolate invalid numeric text into a filter command.

Validate the decoded final lossy MP3, with practical documented tolerances and
headroom—not only pre-encode filter statistics. Keep metadata, safe output staging,
exit outcomes and cancellation intact across both passes. Compare disabled-mode
arguments/results against the baseline. Any adoption changes the required test
matrix and invalidates already frozen candidate/asset authorization.
