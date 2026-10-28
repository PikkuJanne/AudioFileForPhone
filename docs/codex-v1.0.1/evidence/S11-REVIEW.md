# S11 campaign review

Reviewed on 2026-10-28 against entry checkpoint
`c6c63bf72b333afd530ff2facfce5c48ffde5347`. The two new harnesses received a
read-only peer review by an agent who did not author them. The reviewer authored
the narrow launcher-fixture correction below; that portion received an author
readback, not a claim of independent authorship or an external audit. Actual
executed outcomes, nonpasses, report digests and checkpoint CI belong in S11.json
and the full handover. Source inspection alone supplies no execution pass.

## Coverage and evidence boundaries

The corpus uses the production probe, capability query, audio planner, metadata
builder, staged transaction and full-decode validator directly. It supplements
the retained large matrix with tiny AAC-LC/ALAC/MP3/Vorbis/Opus sources, irregular
VBR, AAC edit-list variants and MP3 without a Xing header. Independent probes and
decodes compare observed durations, exact 64 kbps shape, metadata and ordinary
default decoded sound. It does not substitute direct-function tests for retained
whole-application or first-run evidence. The deliberately truncated MP3 retains a
plausible header and exercises the real output validator; transaction rejection
and no-publication behavior also remain covered by the retained transaction suite.

The retained Progress suite supplies actual 3,605-second CBR and VBR conversions.
The retained TransactionalOutput suite supplies unknown/missing/nonfinite duration
result injections and corrupt/truncated payload cases. HE-AAC fixture-generation
availability stays distinct from converter acceptance. No duration tolerance,
source-duration policy, bitrate expectation or full-decode requirement changed.

The filesystem harness creates only owned synthetic fixtures. It verifies an
actual write-denied application directory while converting elsewhere, a config
parent ACL denial, an exclusively held source and a controlled source move after
a real plan. The config fixture is parsed before denial, an independent CreateNew
operation must receive UnauthorizedAccessException, and saving must fail at the
expected config lock path. ACLs must restore to their exact original SDDL.

The disk-exhaustion case writes a small prefix into the production-owned partial
and injects a labeled encoder result. Its shared write handle is compatible with
the retained transaction guard. This proves response to the injected failure; it
is not an actual full-disk test. Expected faults require no final publication,
owned-partial cleanup and preserved unrelated bytes. Existing suites retain
actual destination ACL, path-boundary, reparse, concurrent-run, collision,
cancellation, native-release and cleanup coverage.

Both new harnesses use atomic native directory reservation, a create-new owner
marker, immutable fixture/source hashes, no-reparse checks and exact owned cleanup.
Native release/pipe uncertainty prevents a cleanup success claim. Raw reports,
child diagnostics, tools and media remain private and outside public Git.

## Review corrections

Review caught an Opus fixture rate assumption: the independently generated Opus
source now explicitly uses 48 kHz. The corpus reports direct production functions
rather than claiming copied application evidence, and its reservation uses the
retained production CreateDirectoryW interop.

The retained launcher campaign exposed an exact-string fixture mismatch: the
requested ancestor spelling was `C:\Windows\TEMP`, while both captured child
working directories used the physical `C:\Windows\Temp` spelling. Fresh diagnostic
reports retain the expected directory and complete child capture before the
assertion. Native GetFinalPathNameByHandleW now obtains the already-owned fixture
directory's spelling; it must differ from the requested path only by casing and
must remain a local drive path. The exact PowerShell/process CWD assertions remain
unchanged. Application launcher/runtime behavior was not modified.

## Preservation and limits

All 13 runtime/download-manifest checkout hashes were independently compared with
S10.json and matched, including the tested runtime from
`b05b581dc6372cecd99471c53ee2cac72b8267ba`. Runtime defaults, source safety,
metadata/artwork, no-write checks, private diagnostics, whitelist export, separate
consent-based setup, cancellation130 and prerequisite/capability release refusals
remain. Normal encoding/full decoding remain unlimited.

This review establishes no Windows 10, genuine cloud/redirected/UNC/mapped-share,
physical UI/Ctrl+C, phone or future exact release ZIP pass. Missing environments
stay explicit acceptance gaps; no blanket reparse bypass or universal storage
compatibility claim is justified. Main integration and publication remain later,
separately authorized steps; only S11 is in scope here.