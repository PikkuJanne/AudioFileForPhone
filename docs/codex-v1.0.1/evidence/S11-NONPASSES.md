# S11 preparation nonpasses and unproved scopes

Recorded on the available Windows 11 Pro 26H2 x64 client, build 26300.9711,
Windows PowerShell 5.1.26100.9711 and portable PowerShell 7.6.5. Original private
reports and raw driver diagnostics remain outside public Git. Later successful
runs retain their own source/report identities and do not relabel these attempts.

## Launcher fixture reproduction

S08-launcher-ps51/ps7-attempt201 each failed the first exact CWD assertion at
checkout `c6c63bf72b333afd530ff2facfce5c48ffde5347`. Both reports prove unchanged
source/fixtures, native release and cleanup. Their case capture was assigned
only after the assertion, so neither report preserves the exact expected/observed
CWD. Their primary generic assertion is retained; it cannot itself establish the
particular directory-spelling mismatch.

The narrow diagnostic-only change retained the child capture before the CWD
assertion. Fresh PS5.1 attempt202, at the same checkout with the recorded changed
harness bytes, independently reproduced requested `C:\Windows\TEMP` versus both
captured `C:\Windows\Temp` ancestors. The rest of the CWD was identical. Its source,
fixture, release and cleanup checks passed. Directory enumeration separately
confirmed the physical ancestor spelling. No completed PS7 attempt202 report is
claimed.

The fixture now obtains the already-owned directory's native final spelling and
requires that canonicalization change casing only. It rejects remote final paths.
The exact captured PowerShell/process CWD assertion remains unchanged, as do all
production launcher bytes. Fresh attempt203 results are separate evidence.

## Initial complementary corpus

S11-corpus-ps51-attempt1 failed independent source-shape verification when a tiny
Opus fixture requested the default 44.1 kHz but libopus produced 48 kHz. Earlier
AAC/ALAC/MP3/Vorbis rows had run; this incomplete group is not counted as a passed
corpus. The test-only fixture now explicitly generates Opus at 48 kHz.

The same attempt records source_unchanged=false because harness fields were
edited while the run was active. It stopped at that integrity assertion, before
fixture-after verification, so synthetic_unchanged=false is not proof of source
media mutation. The returned native release and exact cleanup checks are true.
This failed report is not a clean exact-source pass. Fresh attempt2 in each shell
at `81450069bfd695817ce5fdbcd2365010cc91c42a` independently passes all four groups
and ten direct production conversions, with source/fixture/release/cleanup proof.

## Analyzer preparation

The first private analyzer wrapper in both shells extracted dependency inventory
functions without their required Assert-CiNoReparse function. It failed before
analysis and produced no analyzer acceptance report. The raw error is preserved;
this is wrapper preparation failure, not a zero-diagnostic analysis result.

The corrected wrapper then refused the old development dependency extraction.
Its FFmpeg tree contained only two files against the pinned 45-file inventory;
the analyzer tree was independently observed as 12 files against the pinned 53.
Selected binaries/module files alone cannot establish the complete extraction
contract. Both attempt2 wrappers stopped at the FFmpeg inventory gate and emitted
no completed analyzer acceptance report. Fresh pinned provisioning and subsequent
analysis must supply separate evidence. No inventory check was disabled.

## Interrupted campaign scopes

The user interruption terminated the active campaign commands. The initial
PS5.1 tool-selection and PS7 first-run scopes have no completed attempt201 report
and no retained descendant-release/cleanup proof. Their scopes are retained;
absence of a report is not a pass, an ordinary expected failure or proof that all
children were released. New attempt203 runs have separate identities and cannot
establish cleanup of the interrupted scopes. No global termination or broad
cleanup is authorized by a later pass.

## Original private evidence digests

These hashes were read before private filing. They bind the original bytes;
private stderr files are diagnostic artifacts, not completed suite reports.

| Artifact | SHA256 |
|---|---|
| S08-launcher-ps51-attempt201.json | `5c3a496e2d3b185b8358fb2d5904de6978c114a6ef8dba292cc89f61af46d3ef` |
| S08-launcher-ps7-attempt201.json | `332de035c6f2f4542d9b57b6a5c07fc42bb793988eba0df7ba9235b48ff3a783` |
| S08-launcher-ps51-attempt202.json | `4248c26187dda18f7991d9ce544250f6fa215fa4677180c9959d9547756f78db` |
| S11-corpus-ps51-attempt1.json | `bc9ec37b470d94d629c4c55b87942c8628ff7924a24f6724701ab1a2b1d52b3e` |
| analysis-ps51-attempt1.stderr.txt | `79eaa07f348ed359956c58d9805ba59c13cef24609a17d1e13d31ec70244c460` |
| analysis-ps7-attempt1.stderr.txt | `94e9e2ca8d9f2ddc3bc5de4aa1b8e2148fccd6b11c41e07a0f53b0d71072b2d4` |
| analysis-ps51-attempt2.stderr.txt | `684507db264d12a9d2660fbf34c415d09b4bf1e3b15bcfee9b93f14d75953795` |
| analysis-ps7-attempt2.stderr.txt | `5273b78f17d1bfdf4484ecdc0260d39bbf6a4d71407c171fe09162a9eed14312` |

Runtime remains unchanged from tested source
`b05b581dc6372cecd99471c53ee2cac72b8267ba`. No safeguard was weakened. Windows 10,
genuine cloud/UNC/mapped-share conversion, physical input/phone and the future
accepted ZIP remain outside these preparation claims.