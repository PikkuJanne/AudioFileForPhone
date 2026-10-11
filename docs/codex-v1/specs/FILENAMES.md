# Naming and path contract

Preserve the date-first scheme, the existing safe-character intent, MaxBaseLength
60 by default and suffix spelling such as “ (2)”. This is an output naming change,
not source-folder cleanup or a replacement library organizer.

One pure planner should be used by preview and actual conversion. Its inputs are
source relative path, source filename/timestamp, configured length and an explicitly
ordered inventory; its outputs include destination relative path and warnings.

Parse leading YYYY-MM-DD with a real invariant-culture calendar operation. An
impossible date uses the recorded LastWriteTime fallback and a tested title rule.
Do not silently reinterpret a failed date under a different locale. Normalize text
to NFC before applying the baseline whitelist and whitespace rules; preserve
Finnish/German and other permitted letters. Do not split a surrogate pair during
truncation. A full grapheme-aware implementation is desirable only if kept small;
record how combining sequences are handled after normalization.

Use an explicit stable ordinal ordering and Windows-style case-insensitive collision
set with a deterministic tie-break. Characterization might show current ordering
was incidental; repeatability is the intended fix. Same basename across .mp3/.m4a/
.ogg must allocate repeatable suffixes. Budget suffix growth, date prefix, separators
and extension; a collision suffix must not silently exceed MaxBaseLength.

Document the length unit being enforced; do not claim a universal Android/MTP limit
from a single character count. Validate the complete Windows destination path and
all preserved directory components. Keep existing folders intact; reject an
unsupported deep/problematic tree with actionable diagnostics rather than rewrite
source paths or silently omit files. Extra naming patterns and folder sanitization
modes are not required in this release.

Fixtures: real and impossible leap dates; no-date names; composed/decomposed accents;
spaces/brackets/apostrophes/ampersands; equivalent sanitized titles; case collisions;
emoji/surrogates; empty sanitized title; suffix transition from 9 to 10; very small
and excessive requested length; deeply nested folders; distinct parent names sharing
a prefix. For BAT paths also test percent/exclamation/caret behavior in cmd.exe.

## T07 selected implementation

`Get-AudioNamePlan` accepts a relative source file path, LastWriteTime,
MaxBaseLength and counter. `Get-AudioBatchNamePlan` accepts a complete inventory,
InputFolder and OutputRoot and returns all validated plans together. Both are
pure: no enumeration, prompts, probes or writes. Conversion consumes these plans;
T12 preview must use the same batch planner.

Dates use invariant Gregorian TryParseExact. Invalid leading dates use invariant
LastWriteTime and retain the **entire original basename** as title input. Titles
normalize to NFC before filtering and again after removal, which can join
composable letters. The whitelist permits Unicode L/Nd scalars, whitespace, `-`
and `_`; whitespace collapses to one space. Remaining noncomposing marks are
removed. Truncation protects scalar boundaries, without claiming full grapheme
preservation. Malformed surrogate strings reject clearly. An empty safe title is
Episode. Category lookup uses the string/index overload of
[CharUnicodeInfo](https://learn.microsoft.com/en-us/dotnet/api/system.globalization.charunicodeinfo.getunicodecategory?view=netframework-4.8.1).

MaxBaseLength is 24–180 **UTF-16 units excluding .mp3**, including the complete
ten-unit date, three-unit separator, at least one complete title scalar and the
entire suffix. Every counter replans from the untruncated title. Insufficient
space rejects visibly. Sources sort by full path with OrdinalIgnoreCase and then
Ordinal; the destination relative-path set uses OrdinalIgnoreCase. Canonical
duplicate sources reject, while case-only sources remain distinct on a Windows
directory configured to allow them. Preserved directories are never normalized
or renamed.

Legacy-compatible destination file paths are <260 units, created directory paths
<248 and individual components <=255. Validate original component spellings
before canonicalization: reject trailing dots/spaces, reserved Windows device
names (including COM/LPT superscript digits), controls and invalid path characters.
See Microsoft’s [naming rules](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file)
and [path limits](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation).
This is a deliberate compatibility policy, not a universal Windows/Android/MTP
capability claim. T07 also validates marker/log paths and a future sibling working
name `.AudioFileForPhone-<32 hex digits>.partial`. T09 must honor that fixed length
and explicit output format; T07 creates no working file. Deep paths may therefore
reject even when the final short MP3 name alone would fit.

An unexpected existing planned target fails instead of being renamed. FFmpeg `-n`
also refuses overwrite after the literal guard. Concurrent run reservation and
transactional publication remain T08/T09. BAT metacharacter tests remain T14.
