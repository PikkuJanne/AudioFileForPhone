# S09 independent production review

Reviewed on 2026-10-27 (Europe/Berlin), against entry checkpoint
`f7fe6529c50fe9bd2bbf8acd440d804160bc3564` and the working production diff.
Review snapshot SHA256s after restoration of existing checkout line endings:

| File | SHA256 |
|---|---|
| AudioFileForPhone.ps1 | f7e4639b500fa442204494aba961639b5d4abed3d3433e641a6edac13f9190b9 |
| AudioFileForPhone.Helpers.ps1 | 6d8909240e163e5f856e6d9a36609dc00d9d627ac940ba76df0b398872e136fe |

The review covered selected-stream probing, capability parsing and release proof,
MPEG bitrate/sample-rate intersection, mono/stereo preservation, explicit standard
layout downmix, shared cover/no-cover output-option scope, metadata precedence,
planned-versus-observed manifest data and output validation. The existing fixed
duration bound, full decode, owned partial file, no-overwrite publication and
unlimited ordinary encode/decode paths remain intact. The new capability query is
bounded and runs once after interactive input; it has no download or fallback.

One review finding was corrected: an unproved capability-process release could
previously allow the next source probe to overwrite the cancellation context's
retained native process identity. The application now records the first source's
incompatibility and diagnostics, then stops the batch before any further native
operation. It makes no additional termination or cleanup attempt. A released but
unusable capability response remains an explicit pre-encode incompatibility.

Five additional pure checks ran under portable PowerShell 7.6.5 with an injected
native-result function and the helper hash above. A valid list produced the nine
expected sorted sample rates; duplicate lists, a missing list and an unreleased
result all failed; a requested cancellation returned Cancelled. These checks
launched no native child, generated no media and are not Windows conversion or
real timeout/release evidence. Actual matrix, application and retained regression
results belong to S09.json and retain their independently recorded identities.

The retained setup/encoding harness now keeps its independent unplanned encoder
comparison but requires correctly planned, exact-rate application output and the
matching manifest. Historical report contracts remain. The progress suite's
validation wrapper forwards the optional OutputPlan without bypassing validation.
Both edited harness files parsed under portable PowerShell 7.6.5; their scoped
whitespace check passed.

No outstanding production correctness finding remained in this review snapshot.
Final exact-source execution, CI, feature synchronization and main integration
are separate checkpoint gates; this review grants no release or merge authority.
