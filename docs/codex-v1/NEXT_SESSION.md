# Next session — T16 after owner integration

T15 is complete: A38/A39/A40 and the full M3 local matrix pass on PS5.1 and PS7.
Exactly next implementation task: T16, complete the regression and fault-injection
matrix, after owner integration of T15. Project/release remain incomplete.

## Read first and reconcile

Read STATUS.md, this file, TASKS.json, AUTHORITY.md, SYNC_PROTOCOL.md and applicable
AGENTS guidance. Inspect dirty/untracked state, active branch, fetch/push URLs,
overrides, normal fetch, independently advertised refs and live GitHub.
Preserve all work; no reset/clean/force. T14 PR #14 was owner-merged at
10:53:03 UTC on 11 October 2026 into main
1ab43fcb4e00fae6268cd799b89d8b606b6a6bb2. T01-T14 are integrated.

T15 branch codex/v1-t15-metadata; reviewed/tested code
5044cd80a1380ba69022446eca1b62d295b4b819 was pushed/live-matched.
Draft PR https://github.com/PikkuJanne/AudioFileForPhone/pull/15.
Evidence/handoff follows in a docs-only checkpoint; inspect fresh final HEAD/ref.
Main integration remains owner-gated. Live Actions workflow count is zero;
local results are not CI acceptance.

## Preserve metadata and earlier contracts

Keep MP3/M4A container tags and Ogg a:0 stream comments, missing/empty-title
planned-name fallback, nonempty whitespace title and last nonblank Artist/Album
overrides. Preserve quoted Unicode, track/disc/comment and ID3v2.3 behavior.
Default source artwork stays dropped. Validate supplied JPEG/PNG once during
preflight, dispose image/picker resources, require native release proof and reuse
cached diagnostics. Each encoder reads the image to embed one JPEG at original
dimensions. Large-cover warnings stay advisory; no automatic resizing.

Chapter mapping remains FFmpeg's existing default. The short real M4A fixture
keeps two quoted/Unicode chapter titles, with 0.150023 becoming 0.150000 seconds
in MP3's millisecond time base. Probe success does not establish phone navigation
or resume. M4B and other unsupported scan extensions remain excluded.

Read evidence/T15.md and T15-tested-payload.json. Thirty-two final reports pass:
600 required groups/checks plus six baseline observations. Two Metadata finals
directly test code 5044cd80; 15 groups/18 decoded publications/81 direct natives/
14 retained hosts/118 entry release proofs per shell. The thirty regression
reports retain their actual base 1ab43fcb and matching tested bytes.
Twenty files/134 report-source relationships bind literally or strict UTF-8
CRLF-to-LF only. Older schema fields are not fabricated. Two preliminary metadata
passes remain provenance; no T15 failed attempt/recovery.

Full M3 covers all existing families, including quiet handles 674->674/578->578
with allowance 16, actual 3,605-second progress/full decode at 3605.047982 seconds,
and exact returned-root configured-Music smokes. Those smokes verify only owned
synthetic roots, tokens, inventory, manifest and cleanup; ordinary Music is not
enumerated.

Keep coverage limits explicit: padded overrides are pure-plan only; actual
quoted Unicode override tags are real probes. Empty-title assignment omits an
MP3 tag. Actual M4A differing stream handler_name and Ogg stream-only comments
are not physical conflicting title dictionaries; native stubs cover that branch.
The actual FFmpeg undecodable-cover branch uses controlled post-GDI corruption
of an owned synthetic image and restores bytes only after release. Other invalid
initial images are separate real negatives.

Preserve staged/no-overwrite publication and ownership, truthful counts/0/2/1,
scoped Ctrl+C/130/release/restoration, zero-operation preview, bounded progress
below 100 until publication, and T14 required local log/JSON behavior.
T07 possible unknown residue, T09 brief path interval, T11 forced-host limits and
T14 last-good snapshot/crash-durability limits remain. Physical T11 evidence is
historical; no new phone/manual/CI/release acceptance is inferred.

## Start the next coherent task

If PR #15 is owner-merged, independently verify the advertised main merge,
fast-forward clean local main and create a relevant T16 codex branch.
Read only tasks/T16.md and its relevant specs next. Keep real FFmpeg and all
existing source-safety/cleanup gates; tests run on the active Windows machine.
Use fresh T16 report labels and honest failure/provenance records.
Main/release authority is unchanged.

Copy-ready prompt: T16 next please
