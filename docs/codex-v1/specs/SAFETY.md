# Filesystem safety contract

## Source and destination invariants

Input audio, folder names and existing destination files are never rewritten,
deleted, renamed or normalized in-place. Outputs live only in a uniquely owned
run tree under the configured Music folder or explicit OutputParent. Relative
source folder layout stays familiar. Filesystem operations on user paths must be
literal, with canonical, separator-aware, case-appropriate containment checks.
Do not substitute a string StartsWith check that confuses C:\Audio with C:\Audio2.

Reject non-filesystem inputs and roots under the initial v1 policy; provide the
actual reason. Preserve full root spelling during validation. Known-folder lookup
is distinct from concatenating USERPROFILE\Music. No Windows registry changes are
needed to test a redirected resolver. Preflight may verify writability with a
uniquely owned sentinel on a normal run, but never during preview.

Skip and report directory reparse points; do not follow junction/symlink loops or
unknown targets. Scan access failure stops before conversion under the selected
contract. Recognize generated output using ownership/structure, with a conservative
legacy-log fallback. Do not silently exclude arbitrary user folders just because
they share an AudioForPhone_ prefix. Snapshot discovery before conversion.

T06 implements a literal, explicit directory walk and ordinal case-insensitive
file ordering. Selected input/output paths with reparse ancestry are rejected;
descendant file/directory reparse points are skipped visibly. Planned output must
not equal or contain the selected input; an output run beneath the input is valid
and excluded. Selecting a recognized run root or any folder inside one is rejected.
Scan failure or an empty snapshot stops before prompts, destination write probing,
run-root/log creation and conversion. Read-only provisional selection picks a
nonexistent candidate so occupied unmarked audio folders remain in discovery.
This selection does not establish ownership; T08 reserves the final root atomically.

New runs write `.AudioFileForPhone-output.json` with CreateNew. Recognition requires
an integer schema 1, exact kind `AudioFileForPhone.Output`, and a self-matching
absolute canonical output path. Marker parsing retains at most 8192 characters.
Legacy fallback requires an exact valid timestamp/rate root name, matching initial
log header/input/output/rate/name-limit fields, and a nonreparse direct directory
matching the recorded input leaf. Only the first 65536 characters of a log are read;
a long batch log remains recognizable. Reparse identity files are not followed.
Malformed identity is insufficient; access/read errors abort discovery. Identity
is for exclusion only, never authority to delete or reclaim a run. Moved/copied
runs retaining an old absolute identity path are conservatively unrecognized.
The snapshot does not lock sources against subsequent external replacement.

## Exclusive ownership

A run-root timestamp is for readability, not uniqueness. Reserve a fresh root
using a tested exclusive primitive; Directory.CreateDirectory returning an existing
directory is not proof that this process created it. Marker/log files use create-new
semantics. An existing candidate root is never reused. Test races with synchronized
process launches, including log/sentinel checks, not sleeps that avoid the race.

Creation/cleanup decisions must preserve ownership evidence and be safe when a
second run or external writer appears. Do not reclaim directories based only on
names, timestamps or a parsed log supplied by another process.

T08 uses Win32 CreateDirectoryW, which fails for an occupied directory or file.
Only ERROR_FILE_EXISTS (80) and ERROR_ALREADY_EXISTS (183) advance the numeric
counter; other failures abort. Names use invariant yyyyMMdd_HHmmss and optional
_2, _3, ... suffixes. Parent ancestry and raw components are checked; the pure
batch plan validates every candidate's exact path budget before creation. The
successfully created root is checked again before CreateNew marker/log writes.
The marker records a fresh ownership_token and cleanup_scope equal to the exact
canonical root. These fields describe this invocation; parsed identity alone
still never confers cleanup authority. Production does not recursively remove a
run after setup failure; it reports that exact scope/token and leaves it visible.
The log is CreateNew with a UTF-8 BOM; headers and later records append.

## Transactional per-file output

Allocate output name -> create unique working path on the output filesystem ->
encode -> validate -> no-overwrite promotion -> record success. A working path
should end in a clearly non-final suffix; pass the MP3 output format explicitly
rather than relying on a .partial filename's extension. Final .mp3 is not written
until validation passes. FFmpeg may overwrite only its exclusively owned working
file if needed; never point -y at an existing user's final file.

Validation: process success, nonzero file size, expected MP3 audio stream/bitrate,
reasonable duration and allowed artwork/stream shape. Compare stream characteristics,
not total container bitrate inflated by artwork. Use a documented duration tolerance
justified by encoder padding and fixture results. Avoid percentage-only tolerances
that could allow minutes of truncation in a multi-hour audiobook. Missing/invalid
source duration needs a declared safe validation fallback or a clear failure, never
an invented duration. Full decode of every long file need not be the default; use
short full-decode regression tests and targeted long-file acceptance.

If final promotion collides, do not overwrite; reserve a new safe suffix or fail
that file, and record the actual mapping. A failed record/log write is explicit.
All failures preserve sources and completed outputs. Source SHA-256 comparison is
required in tests; do not upload real private source inventories.

## Cancellation and cleanup

Track only this invocation's child/process handle and files. On controlled cancel,
stop/wait the owned child, close handles, remove this file's working output and
record cancelled, preserving completed files. Never kill all ffmpeg processes.
Forced host termination/power loss may bypass finally; left-behind files must remain
recognizably incomplete. Do not silently auto-delete other run trees at next start.

Test cleanup must use its own unique TEMP root with verified ownership and no
reparse escape. A legacy test's Music cleanup needs a narrow owned-run exception;
ordinary automated tests must use OutputParent. Cleanup failure should be reported,
not hidden with blanket SilentlyContinue or broad Remove-Item globs.

No resume database, global lock service, background daemon, parallel processing
system or automatic disk reclamation is needed for v1.0.0.

## T09 selected publication policy

Each conversion creates a sibling `.AudioFileForPhone-<32 lowercase hex>.partial`
with FileMode.CreateNew after rechecking canonical boundaries, reparse ancestry
and the complete T07 budgets. A retained ReadWrite handle without Delete sharing
prevents replacement during encoding, probing and decoding. FFmpeg receives `-y`
only for this created working file and `-f mp3` explicitly. The process helper
returns after owned process/pipe disposal; abnormal teardown waits up to five
seconds for its owned child and reports ProcessReleased=false if exit is unproved.
This teardown bound does not limit ordinary conversion runtime.

Require a finite positive selected source-audio duration, using container duration
only when the selected stream duration is absent/N/A; invalid stream duration fails.
Missing/invalid source duration is a per-file failure before staging/encoding.
Output must be nonempty MP3, exactly one MP3 audio stream at the requested bitrate,
and exactly one attached JPEG stream only when an explicit cover was requested.
Container bitrate is never a substitute for the selected audio stream bitrate.

Probe duration, source duration and decoded duration must agree within a fixed
0.35 seconds. This absolute allowance covers short low-sample-rate encoder padding;
it never grows with the length of an audiobook. Every staged output fully decodes
with error-fatal FFmpeg settings into the null muxer. Validation-only asetpts derives
media time from PCM sample count, so plausible Xing headers/timestamps cannot stand
in for emitted audio. Completed progress and finite positive decoded duration are
required. This adds a read/decode pass per file; long-file performance is unmeasured.
It does not change the MP3 audio or introduce loudness normalization.

Release the ownership guard only after validation/process use has ended. Recheck
nonreparse ancestry and the recorded volume/file-index identity, then use the
non-overwriting two-argument File.Move operation to the planned sibling final name.
An occupied destination or filesystem error fails that file without choosing a
new mapping. Record success only after promotion. Any subsequent diagnostic/log
write failure explicitly reports the actual published path or file failure and
stops with a fatal logging error; it cannot reclassify a published output as an
encoder failure or increment the same file twice.

T14 also requires a local JSON manifest. Initial creation uses a CreateNew owned
partial and a non-overwriting move; updates replace only the retained owned
manifest identity after ancestry/identity checks. Staging failures remove only
the exact proved owned partial. An occupied or replaced manifest is preserved and
reported as a fatal record failure. The brief path-check-to-replace interval after
releasing the guard has the same hostile concurrent-writer limitation as audio
publication. No marker or manifest authorizes next-run reclamation. Required
record failure preserves published outputs/counts; cancellation keeps code 130.

On failure, remove only the exact current working file after matching its identity.
A changed/reparse path, cleanup error or unproved child exit leaves a visible
.partial and diagnostic. Existing partials, destinations and completed outputs
remain untouched. The brief path-check-to-move/delete interval after guard release
is not a handle-based transaction against a hostile continuously replacing writer;
source replacement remains later work. T11 adds scoped controlled console Ctrl+C
and per-instance cancellation without changing these identity/publication gates.
Cleanup authority is suspended before each native call and validation, and returns
only with explicit native-exit proof. Abrupt helper/host unwind conservatively
retains the exact partial; controlled cancellation returns the release proof and
removes the current partial when its identity matches. No automatic cleanup of
abandoned run trees is added.
