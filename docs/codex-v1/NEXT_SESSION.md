# Next session — T09

Suggested owner request: **T09 next please**.
One coherent task: stage, validate and safely publish each output.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS instructions. Inspect actual git status/branch, all origin fetch/push URLs,
pushurl/overrides and live GitHub. Normal fetch and fresh advertised refs are
required; stored done flags or tracking refs are not synchronization proof.

T08 code checkpoint: `3b6c4164c6e4dd4b58f0be074c17f6fb854b41be`, branch
`codex/v1-t08-exclusive-runs`, draft PR: https://github.com/PikkuJanne/AudioFileForPhone/pull/8.
Actual test base: `e1ea2a95a5a9b7461d69101b6a111f26b51abbf6`, the owner-performed
T07 PR #7 merge into main. Evidence/handoff follows the T08 code checkpoint;
inspect current live HEAD and STATUS.md for the recorded verification outcome.
T08 main integration remains owner-gated. Preserve local/remote work; no
reset/clean/force. If the T08 PR is owner-merged, fast-forward local main to its
verified live ref and start the T09 branch from that merge. Do not infer agent
merge authority or start T09 before its T08 dependency is verified complete.

Read only tasks/T09.md and relevant specs/SAFETY.md, specs/PROCESS_AUDIO.md and
specs/FILENAMES.md next, then the current conversion/probe/reservation code and
affected tests. Use evidence/T08.md for exact checkpoint and test limitations.

## T08 behavior to preserve

Run roots use invariant readable timestamps and numeric _2, _3, ... suffixes.
CreateDirectoryW proves exclusive creation; only occupied-candidate errors 80/183
retry. Marker/log creation uses CreateNew, the marker records an invocation token
and exact cleanup scope, and log records append. Existing files, roots, logs and
sentinels are preserved. Setup failure reports its newly owned scope/token and
leaves it visible; parsed markers alone never authorize deletion or reuse.

Read-only provisional selection avoids excluding an occupied unmarked audio
folder from the snapshot. Final reservation validates/replans the exact suffix
before conversion. Raw OutputParent components are checked before resolution
while relative paths, navigation, provider-qualified filesystem paths and
FileSystem PSDrives remain supported. Preserve literal path handling, reparse
checks and the complete T07 path budgets, including the future working filename.

## T09 bounded implementation

- Encode to a uniquely owned sibling working file on the same filesystem using
  `.AudioFileForPhone-<32 hex digits>.partial`. Honor its fixed length and validate
  its complete path below 260 UTF-16 units; directories remain below 248 and
  components at most 255. Prove ownership before allowing FFmpeg to overwrite
  that working file. Pass the MP3 muxer explicitly for the .partial extension.
- Require process success, nonzero length, expected MP3 audio/stream shape and
  selected audio bitrate. Container bitrate inflated by cover art is insufficient.
  Compare source/output duration with a documented, empirically tested tolerance;
  avoid percentage-only limits that permit substantial long-file truncation.
  Declare a safe missing/invalid-source-duration policy instead of inventing one.
- Promote only validated output to its planned final name with no-overwrite
  semantics. Preserve a concurrent destination and report a per-file failure.
  Test actual promotion/rename/disk errors and keep the recorded mapping truthful.
- Remove only current owned working paths after handles/process use has ended.
  Preserve sources, existing sentinels and completed outputs. Forced termination
  residue must remain visibly incomplete. Keep default 64 kbps CBR, formats,
  layout/date-first names, metadata and script/BAT entry points unchanged.

A24–A26 require real conversion plus staged fault/probe fixtures: zero-exit empty,
corrupt/non-audio/truncated/implausibly long output, codec/rate mismatch, missing
duration, encoder/probe/promotion failures and a concurrent final-file sentinel.
Do not claim success from encoder exit alone. Aggregate result/exit policy is T10;
controlled cancellation is T11 and preview is T12. No downloads/new framework.

## Tests and handoff

Tests run on this active Windows 11 machine under PS5.1/PS7 with the installed
C:\ffmpeg\bin pair, short synthetic fixtures and exclusively owned TEMP. Exact
current T08 final3/verified3 command families and report labels belong in
evidence/T08.md and TEST_STRATEGY.md; inspect the recorded outcomes before use.
Use fresh T09 labels and preserve every historical JSON. Retain the real-FFmpeg
suite and affected companions; never run a baseline against ordinary Music.
Configured-Music smoke may touch only its specifically proved owned run, with
the existing narrow token/inventory cleanup guards and no parent traversal.

The initial failed T07 PS5.1 naming report has cleanup=false. Native entries were
removed, but the unrecorded short machine-TEMP root and parent enumeration denial
leave possible unknown synthetic residue unverified. Do not claim that attempt
cleaned or attempt broad cleanup/ACL changes without exact ownership. Later
reports retain recoverable scope identity and verify checked .NET cleanup.

Create evidence/T09.md; update A24–A26 links, TASKS, STATUS, this handoff and
decisions using actual results and exact tested payload. Review intended diff and
source safety, commit/push, independently compare local HEAD to fresh advertised
branch and report main integration/CI/approval separately. Leave T10 as exactly
the next coherent task. This handoff grants no release/tag/main merge authority;
project completion still requires final publication, independent public download
and main closure under the release runbook.
