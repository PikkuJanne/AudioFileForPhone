# Local Windows acceptance kit

S13 implements the builder and runner. A successful rehearsal is not a frozen
candidate or release acceptance. S14 builds the final kit around its exact ZIP;
S15 collects the necessary client and human observations. Never deliver the
development rehearsal as the owner acceptance candidate.

## Build and identity

`tools/Build-AcceptanceKit.ps1` accepts `-RuntimeAssetsDirectory` containing the
existing ZIP, release-manifest.json and SHA256SUMS.txt, and a new
`-OutputDirectory`. Its optional `-RunnerSourceDirectory` defaults to
`tools/acceptance`. Normal mode requires the fixed v1.0.1 target. Explicit
`-Rehearsal` permits preparation with the current runtime and labels the archive
`rehearsal_acceptance_kit`.

The builder verifies literal local paths, the complete runtime allowlist, ZIP
members, version, sizes, digests and external checksum rows before publishing a
new output directory. It packages the existing runtime ZIP unchanged. It never
downloads, freezes a source, invokes Git, merges, tags or publishes. Runtime
package hashes identify Git blob/archive bytes. Kit script hashes identify the
actual runner input bytes, which can differ from checkout EOL transformations.

Outputs are Acceptance-Kit.zip and its external Acceptance-Kit.sha256. The ZIP
contains the six fixed runner/guide files, kit-manifest.json and the three runtime
assets under runtime/. No FFmpeg, developer framework, SDK, personal media or raw
report is distributed. The archive hash is external because a ZIP cannot contain
its own hash. Keep the retained ZIP beside its extracted folder; the runner
verifies both ZIP members and extracted files before loading the runtime.

## Automated collection

The BAT starts an allowed x64 STA Windows PowerShell 5.1 with a process-scoped
RemoteSigned request. It never changes persisted policy or retries past a managed
refusal. The PS1 also supports explicit SourceDirectory, FfmpegDirectory,
PowerShell7Path, KitArchivePath and SessionParent for automated isolated testing.
`-AutomatedOnly -Rehearsal` are development controls, not owner observations.

The runner uses the production resolver/setup/native validation and packaged
host health probe. It records actual OS caption, client/Server type, build and
revision, display version, OS/process architecture and shell versions. Store
aliases must resolve to a healthy same-identity executable before conversion;
startup alone never fills a core client cell.

Every automated conversion explicitly supplies owned ConfigPath and OutputParent.
Child PATH lacks the selected FFmpeg directory. A separate production setup saves
the selected pair, followed by a fresh process conversion. Per installed host,
the runner parses the package, converts a hash-verified copy of one selected
supported source, and converts a 3,605-second synthetic fixture. It also converts
the complete selected collection through the unchanged packaged PS1. Counts,
record/source/output correlation, exact64 audio plan/duration, complete decode,
all source hashes (including unsupported files) and absence of partials must pass.

Windows PS5.1 can return no item and no ItemNotFound exception for an absent
identity member beneath a bracket/Unicode path. The kit's strict inventory scope
uses a local identity-reader adapter with an explicit null return, retaining the
same literal/error/reparse checks and shared production snapshot. It disappears
before production conversions; no packaged runtime bytes or safeguards change.

Hidden UTF8/CP65001 drivers transport named arguments through private JSON without
evaluation. Child capture is bounded and drained. Normal encode/decode is
unlimited. Any unproved native release refuses further native work. Sessions and
completed outputs remain local; there is no speculative recursive cleanup.

## Actual desktop and phone scope

The automated PS1 collection and the physical BAT collection are separate captures.
The BAT requires a real console and normal Windows Known Folder configuration;
redirecting input or changing LOCALAPPDATA cannot stand in for that route.
Human mode selects tools once through normal production setup, then reuses that
pair in the owned automated scopes. A remembered desktop selection remains an
explicit production setup decision. Automated S13 rehearsals never read that
default configuration or access ordinary Music.

The prepared shortcut targets the actual packaged BAT with the original selected
folder. The owner double-clicks once and presses Enter for defaults. A top-level
DirectoryName watcher observes only newly created run names during that action;
the kit never enumerates Music or chooses a newest directory. Exactly one source,
package, start interval and ownership-marker match must then pass full collection
verification. Watcher error/overflow, zero/ambiguous matches or invalid output
blocks the mechanical result. The raw Explorer/BAT process exit remains unknown.
The owner's answer and mechanical verification have separate report fields.

Direct Windows BAT shortcuts expand percent expressions. The kit therefore
refuses percent-containing physical source/runtime/session paths before Music or
Explorer access, with PHYSICAL_LITERAL_PATH_UNSUPPORTED. This is a documented
route limit; it is not a reason to rename owner data or claim literal success.
Cloud/UNC/reparse and unavailable storage remain outside the local-only claim.

The phone check names an output actually generated and validated by this kit.
Play and seek answers start NOT_TESTED and are collected explicitly. No historical
phone pass or automated gesture supplies these observations.

## Reports and release gates

One whitelist-only REPORT.txt is returned by the owner. REPORT.json is its local
machine-readable companion. Raw child captures, source paths/hashes, private
manifests and errors stay in local-private.json and the owned session. No upload
occurs. Reports are bounded, staged and published without overwriting an existing
report; no audio/source hashes or private log text are exported.

Only a normal final1.0.1 kit may emit candidate_acceptance records. Actual one-file
and exact-package records derive from captured and independently verified runs.
Full-collection acceptance additionally requires the separate actual BAT collection;
its controlled PS1 exit is never attached to the physical run. Physical/phone
records require actual observations. Rehearsals emit none of these records.

This kit does not manufacture the four full core client campaign reports or
online/offline setup acceptance. S14/S15 must supply matching actual captures for
those gates. S12's seven-case clean-first and real online suites remain retained;
their historical passes are not relabeled as exact-package acceptance. The strict
source/ZIP/kit/report/client/human/authority validator remains unchanged. A local
collection or prepared kit grants no publication authority.
