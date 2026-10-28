# Local release evidence gates

Run `tools/Test-ReleaseGates.ps1` for a read-only local evidence decision. Exit0
means the required matching evidence passed; exit1/REFUSED lists missing or
inconsistent evidence. The tool performs no download, upload, Git mutation, merge,
tag or publication and grants no authority.

Default invocation reads actual STATE.json and RELEASE_TARGET.json and refuses
without a frozen candidate. Historical S11 COMPLETED is not exact-package
acceptance. Runtime1.0.0 refuses target1.0.1. S12 tests this current refusal; it
does not build S14 assets or invent S15 observations.

With `-CandidateRecordPath <local JSON>`, the schema1 record has kind
`release_candidate`, source_commit (STATE frozen_release_commit C), target_version,
target_tag, release_title, runtime_zip, runtime_zip_sha256, acceptance_kit_sha256,
runtime_hashes [{path,sha256}], assets [{name,sha256}], and reports
[{gate_id,path,sha256}]. Paths are literal local non-reparse files beside the
record; report paths are safe relative JSON paths. JSON is bounded to4MiB.
The CLI checks actual file digests before accepting report bindings.

Exactly four local assets are required: AudioFileForPhone-v1.0.1.zip,
release-manifest.json, SHA256SUMS.txt and Acceptance-Kit.zip. Only the first three
are public release assets. The kit stays local/private. All digests must match
the candidate and STATE accepted ZIP/kit.

Runtime inventory covers the complete tools/package-files.json allowlist. C must
exist in local Git history, every member must be tracked at C, and packaged paths
must have no Git diff against C. Publication additionally requires C in local main.
The CLI hashes exact binary C blobs through a bounded owned hidden Git reader,
preserving archive bytes across autocrlf checkout differences. It compares those
hashes with the candidate and external manifest members. Manifest version/tag/C/
ZIP name/size/hash and both external checksum rows must match actual assets.
Later documentation commits outside the package may follow C without rebuilding
or rebinding accepted bytes.

Exactly twelve digest-bound candidate_acceptance/schema1 reports are required:
core_windows10_ps51, core_windows10_ps7, core_windows11_ps51, core_windows11_ps7,
clean_first_run, online_setup, offline_setup_failure, exact_package, one_file,
full_collection, physical_shortcut and phone_play_seek.

Each report records gate_id, PASSED, source_commit, runtime_zip_sha256,
acceptance_kit_sha256, runtime_hashes, command, started_utc, ended_utc, environment
and required checks. Automated reports require a captured integral exit_code0.
Human observations do not invent a phone/player or raw physical Explorer exit.
NOT_RUN/FAILED/BLOCKED/SKIPPED/PENDING/NOT_TESTED never satisfy required evidence.

| Gate | Required unique passing check IDs |
|---|---|
| Each core cell | parser, focused, integration |
| clean_first_run | missing_tools, external_selection, saved_fresh_process |
| online_setup | consent, download_pin, installed_conversion |
| offline_setup_failure | no_publication, owned_cleanup |
| exact_package | member_hashes, extracted_conversion, full_decode |
| one_file / full_collection | counts, media, source_hashes |
| physical_shortcut | observed_shortcut, matched_run |
| phone_play_seek | play, seek |

Every required check includes nonblank expected and observed values. The core
environment requires actual Windows10/Windows11 Client, x64, boolean
process_64bit=true, build/revision, display_version and exact shell_version.
Windows10 requires22H2/build19045; Windows11 requires build22000 or later. PS5.1
and PS7 are separate cells. Server/Linux and startup-only PS7 cannot substitute.
Collection counts must be nonnegative integers, input_count positive, all inputs
converted, zero failed/unprocessed, and source_unchanged/media_validated actual
booleans true. Physical/phone reports require evidence_type human_observation,
an actual observer and observed PASSED on final candidate output.

These records are trusted captures from the acceptance runner and actual human
observations. A digest proves byte identity, not that a claimed experiment happened.
The runner must retain its underlying raw results locally and emit checks from
execution; never reclassify historical aggregates or synthetic fixtures. Owner
exports stay redacted under MINIMAL_HUMAN_ACCEPTANCE.md.

Publication phase also requires S16 COMPLETED and STATE publication_authorization
with step S17, C, exact ZIP, target_tag v1.0.1, boolean owner_started_s17=true,
and assets [{name,sha256}] for exactly the three accepted public assets. Only the
human's separately started exact-byte S17 request supplies that authority.
The gate never creates it. S17 still refreshes live refs/releases, verifies main,
preserves v1.0.0 and independently checks draft/public downloads and ZIP members
under SYNC_AND_RELEASE.md.

tests/ci/Test-ReleaseGates.ps1 supplies in-memory validator fixtures, actual
historical digest refusals and actual repository CLI refusal. Its positive
fixtures are contract tests, not Windows/owner/phone/package acceptance.
