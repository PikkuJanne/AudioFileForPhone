# S10 preparation nonpasses

An additional supplementary Server CI nonpass occurred at exact source
`b05b581dc6372cecd99471c53ee2cac72b8267ba`: initial PR run40730776625,
PS7 job122966169262, failed the owned startup-host fixture compile assertion
before the new S10 suite. Its report proves unchanged source, native release and
cleanup, but does not retain the failing compiler status/exit fields; the primary
compiler cause is not established. Report SHA256:
`83431cbf8209c5c4bdf50926263867e915f89f833659aa8be01e6eaff1d7888e`.
The connector lacks Actions-write permission. The CLI also refused a specific
job retry while the other workflow job was still active. Preserve this nonpass;
later exact-checkpoint verification of unchanged runtime is separate evidence.

Recorded 2026-10-28 on Windows 11 Pro 26H2 x64, build 26300.9711,
PS5.1.26100.9711 and portable PS7.6.5. Every failed report below records checkout
`ec828036cda843f9fadff2bc932125d84d241218` while S10 working files were changing.
Its retained file inventories identify the actual bytes; these are not clean
exact-source passes. Private reports, logs and synthetic scopes remain outside Git.

- Support attempt1 failed its original-console-cause assertion: PS5.1 stopped in
  the missing-helper case; PS7 stopped in the missing-dependency case. Those
  reports retain only the generic assertion failure, not the original child cause,
  code or stage. Their exact causes cannot be reconstructed from the retained
  outer logs. Attempt2 in both shells explicitly records a planned partial path
  of 260 UTF-16 units, exceeding the unchanged 259-unit limit before the intended
  dependency failure. A shorter, uniquely owned TEMP parent corrected that driver
  layout. PS5.1 attempt3 then retains the correct missing-helper cause but splits
  the console token FATAL across lines. The assertion now normalizes ANSI/whitespace
  for component tokens while still requiring the exact recorded cause. All these
  attempts prove source/fixture integrity, descendant release and cleanup. PS7
  attempt3 separately passed 26 groups; it is not relabeled as final-source evidence.
- Package attempts101/103 passed all 61 cases in each shell but failed their final
  source-integrity gate. Attempt101 inventories differ in Checks, Launcher and
  Check entry; attempt103 differs in Checks. Fixture-after verification was never
  reached, so its false flag is not proof that fixtures changed. Cleanup remains
  unverified and those owned scopes were retained; native release is proved.
- Baseline attempt102 failed both legacy and characterization runs in each shell;
  no output root was obtained. Its nested driver layout contains a 266-unit source
  fixture path. The shorter owned TEMP rerun attempt103 passes both suites with
  unchanged source and verified cleanup. The failed reports remain failed; the
  available diagnostic tails do not independently preserve their complete primary
  application error.
- PS7 short-operations attempt103 failed the pipe-only bound assertion: the fixture
  exited unexpectedly with code -1073741819 after 5,331 ms, with process/pipe release
  unproved. The harness refused cleanup and retained that scope. The underlying
  fixture failure is not diagnosed as an environment fault. Quiet sequential
  final105 passes all 15 groups at `35cc0a74a2fa4ac59bb9e22d09da61ad5d7cef44`,
  including bounded pipe refusal and exact descendant cleanup; this does not prove
  release of the earlier uncertain scope.
- Analyzer attempt1 has one real automatic-variable finding (`$matches`, renamed
  `$summaryMatches`) plus null diagnostic rows emitted by the private wrapper.
  Both were corrected. PSScriptAnalyzer 1.25.0 final1/final2 each check 17 files
  with zero diagnostics in both shells, at their actual 35cc0a7/b05b581 identities.

Final106 support (27 groups) and package (61 groups) reports independently pass
in both shells at `b05b581dc6372cecd99471c53ee2cac72b8267ba`, with their own
source/fixture/release/cleanup proof. Their detailed identities are in S10.json.
No safeguard, assertion scope, timeout or release guard was disabled. A separate
report-filing selector error briefly moved four historical reports; the session
audit restored them byte-for-byte. It changes no historical test result.

The following SHA256 values bind the original private nonpass report bytes:

| Report | SHA256 |
|---|---|
| S10-support-ps51-attempt1.json | `87648fc52b06614850c5426b835be038b8ade259fae2c683b15cf5e6f1443127` |
| S10-support-ps7-attempt1.json | `93a98ec12c6460024f1970a718288128e868c4fac65fdf5e93c5e5c40ee973cc` |
| S10-support-ps51-attempt2.json | `13b41b4fcdcf6a5ff46be4aa0ea0dea1293b78704aa538f66d2fa1a6b124ffa1` |
| S10-support-ps7-attempt2.json | `5ff695f7d31a63f2b030a2073a177e7bfa648b63911fa70acd9855cb8b3f742f` |
| S10-support-ps51-attempt3.json | `3932bb10fb236d95147c7654f97c8a0007ec8e529bfaf5f235580a71a987877c` |
| T17-package-ps51-attempt101.json | `e6e302e1318a3ad5cb8fd39fff2d6a550d6da9b60e3f3b625cd27433a642a0f1` |
| T17-package-ps7-attempt101.json | `e32159ebee254fb8a5fce6679d79179611ed0e2e1a3a505b21940af85e1e4ddd` |
| T17-package-ps51-attempt103.json | `18655491df64921d7c9b1bcef445a885cf0b0c4086bc0ae2b497be0b0c0184e3` |
| T17-package-ps7-attempt103.json | `70283b584383ae139aac4510e7f4d3632cd01b14fb35361bf114e3d7ca3c3b7c` |
| T17-baseline-ps51-attempt102.json | `9a9b3ca16480b748df80a02aadd2445ff3c8e6dabad26240b7d9e25560ce741a` |
| T17-baseline-ps7-attempt102.json | `b1697a54cf6884f59d512d4cb8a2790c5a731adadfacf397d519562ff9642990` |
| T17-shortoperations-ps7-attempt103.json | `fdc4a22c07a5715de4ea2d8d444a0fb669a6eae0df57837d0d60594c15a0b5d7` |
| analysis-ps51-attempt1.json | `408a546f9be50ab5b8b650e5b37f62ad023390e44cb1623161ac82f161561337` |
| analysis-ps7-attempt1.json | `4eefea31b355f2f1b5ced0d5cf74c0222bf482599f3aba4e63ccf693f255e5b3` |
