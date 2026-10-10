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
