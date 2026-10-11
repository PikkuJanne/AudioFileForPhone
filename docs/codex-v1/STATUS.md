# Current project status

State: **T15 complete; A38/A39/A40 passed; full M3 local matrix passed.**
Last completed task: T15. Exactly next implementation task: T16 after owner
integration of T15. Required improvements 1-15; optional O01 deferred.
Project/release remain incomplete.

## Checkpoint and environment

- Checkout C:\projects\AudioFileForPhone-main; branch codex/v1-t15-metadata.
  Origin fetch/push https://github.com/PikkuJanne/AudioFileForPhone.git.
- Owner merged T14 PR #14 at 10:53:03 UTC on 11 October 2026 into main
  1ab43fcb4e00fae6268cd799b89d8b606b6a6bb2; final T14 feature
  628d8247a07a1b0866f90452883b2b4ceeea1c38. Normal fetch and independently
  advertised refs matched; clean local main was fast-forwarded before branching.
  T01-T14 are integrated.
- Reviewed/tested code checkpoint 5044cd80a1380ba69022446eca1b62d295b4b819
  was normally pushed and independently matched its fresh advertised feature ref.
  Evidence/handoff follows in a docs-only checkpoint; final HEAD/live proof belongs
  in the PR/response, without a self-referential stored hash.
- Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/15.
  **Feature synchronized; T15 main integration owner-gated.**
  Live GitHub has zero Actions workflows; no CI pass is claimed.
- Windows 11 Pro 26300.9457; PS5.1.26100.9444/Desktop and bundled PS7.6.5/Core.
  Existing C:\ffmpeg\bin pair, build
  2026-10-08-git-ec420ba161-essentials_build-www.gyan.dev.
  No download or machine settings/policy change.

## Verified behavior and evidence

Metadata keeps MP3/M4A container tags or Ogg first-audio-stream comments.
Missing/empty title uses the complete sanitized planned basename; nonempty
whitespace title survives. Nonblank Artist/Album overrides apply last, literally.
Track/disc/comment and quoted Unicode tags pass real output probes on both shells.

Explicit JPEG/PNG receives one image inspection and one dedicated FFmpeg decode
check before conversion. Image/picker handles are disposed; native release proof
is required. Cached diagnostics serve prompts/logs. Each encoder then reads the
cover for embedding. Source artwork is dropped by default; an explicit cover
replaces it with one attached JPEG at unchanged dimensions. Large-cover warnings
remain advisory. Invalid supplied images fail preflight before prompts/reservation.

Chapter mapping remains FFmpeg's existing default. Actual short M4A chapters retain
both quoted/Unicode titles in MP3; a 0.150023-second boundary rounds to 0.150000
in its millisecond time base. This proves probed fields for the fixture/build.
Phone navigation and resume remain untested and are not guaranteed.

Thirty-two selected final reports pass: **600 required groups/checks and six
baseline observations** across both shells. Metadata directly tests code 5044cd80:
15 groups and 18 independently probed/full-decoded publications per shell,
81 direct native commands, 14 retained hosts and 118 entry native release proofs.
All source/synthetic, release/disposal and exact owned cleanup gates pass.
Two earlier metadata attempt1 passes remain as provenance; no T15 failures/recovery.

Full M3 also passes retained baseline, preflight, discovery, naming, reservation,
resolver, launcher, transaction, script outcomes, preview, diagnostics, progress,
automated cancellation and native execution. Quiet sequential native handles stay
674->674 / 578->578, allowance 16. Progress converts the actual 3,605-second
synthetic source and fully decodes at 3605.047982 seconds with live samples.
Two configured-Music smokes inspect/remove only each successful returned root,
with runtime scope/token, CreateNew test marker, exact synthetic inventory and
final manifest assertions. Ordinary Music is never enumerated.

The tested-payload manifest binds 20 source files/134 report-source relationships
to code 5044cd80: two literal and eighteen strict UTF-8 CRLF-to-LF matches.
Older baseline lacks command/edition/child-ledger fields; resolver/music records
one harness digest, with actual entry/helper before/after hashes. Missing fields
are not invented. Exact commands/results/limits: evidence/T15.md,
evidence/T15-tested-payload.json and TEST_STRATEGY.md.

## Preserved limitations and next action

Padded nonblank override exactness is a pure argument-plan check; actual quoted
Unicode override tags are separately probed. FFmpeg's empty MP3 title assignment
omits the tag. The real M4A stream fixture has a differing handler_name; Ogg has
stream comments and no format tags. Conflicting title dictionaries are additionally
covered by native probe stubs, rather than claimed as physical container conflicts.

The undecodable-cover branch corrupts only an owned synthetic image after GDI
validation/disposal, then restores exact bytes after positive native release.
Initial missing/corrupt/GIF/BMP fixtures are separate actual preflight negatives.
No permanent GDI-readable/FFmpeg-undecodable initial image is claimed.

Preserve local T14 diagnostics/manifest semantics, T09 publication/ownership,
T10 counts/exit codes, T11 cancellation/host limits and historical physical checks,
T12 preview zero operations, and T13 progress below 100 until publication.
T07 possible unknown TEMP residue, T09 brief post-guard path interval and T14
last-good snapshot/crash-durability limits remain. No new manual/phone acceptance.

Owner review/integration of draft PR #15 remains pending under AUTHORITY.md.
Exactly next implementation task: T16, complete the regression and fault-injection
matrix, after that merge is independently verified. No tag/release created;
exact commit/assets, ZIP, draft/public download and final main closure remain
governed by AUTHORITY.md and RELEASE_RUNBOOK.md.
