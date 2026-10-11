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
run-root/log creation and conversion. Existing planned run roots are refused;
exclusive reservation against concurrent creation remains T08.

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
