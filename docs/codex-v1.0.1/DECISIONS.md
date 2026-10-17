# Decisions

D01 — Owner-mandated public release v1.0.1. The owner corrected the earlier
      target on 17 October 2026. Preserve the entire accepted scope; published
      v1.0.0 and its assets remain unchanged. No alternative version without a
      new explicit owner instruction. RELEASE_TARGET.json fixes all release names.
D02 — One numbered step per thread, including hard STOP on blocked evidence.
D03 — No application rewrite; preserve default audio and source/output protections.
D04 — FFmpeg selection is application-specific; no persistent PATH mutation.
D05 — Managed download is optional, explicit, pinned and separate from conversion.
D06 — Missing dependency versions are tested by capability; do not require one
      exact patch number just because CI uses it. Reject known unsafe builds only
      with current sourced reasoning and an actionable replacement route.
D07 — Owner work is consolidated in S15; developer/CI matrices stay with Codex.
D08 — Full Windows 10/11 and candidate-byte verification cannot be waived by Codex.
D09 — Reference build pinning is for repeatable testing, not a claim that a release
      build is inherently better than every Git-master build.
D10 — Support export is local and opt-in; raw paths/media/metadata stay private.
D11 — Context-specific updates to the old AGENTS routing/download/release scope are
      intentional and narrow; preserve historical evidence and unrelated rules.

Append dated decisions with: problem, evidence, options considered, decision,
affected tests/steps, and whether user authorization is actually needed.
Do not relitigate these defaults in every new thread.

D12 - 2026-10-17, S01 routing: local/live paths and branches contain only the
      completed historical v1.0.0 plan, with no earlier 18-step import/progress.
      Apply S01 rather than the correction checkpoint. Fast-forward clean local
      main from 74992b2 to live 28f53b10529495754273d55654c7b29e78848c83;
      preserve owner artwork and create codex/audiofileforphone-v1.0.1. Import
      only 43 explicitly inventoried payload docs. No new authorization needed:
      the current owner request covers S01 edits/tests/commit/feature push.
D13 - 2026-10-17, S01 evidence: inventory actual Windows hosts and retained test
      entry points without rerunning owner diagnostics or audio tests for a
      documentation-only import. Existing wrappers have historical T-prefixed
      output contracts; S02 must preserve old evidence and explicitly bind new
      scope. Retain inherited UTF-8 console handling in future media runs.
D14 - 2026-10-17, checkpoint identity: store unchanged tested baseline/runtime
      hashes and the prior verified checkpoint. Observe final containing HEAD,
      live equality and its CI in the post-push handover, avoiding self-hashes.
      Main integration remains separate/deferred to ordinary S14 PR policy.

D15 - 2026-10-17, S01 checkpoint: preparation 91635bbcd7ac74ea135be1fbdd95fb9c543ca88a
      is pushed/live-equal and both exact-head push/PR CI matrices pass. Record
      S01 complete and S02 eligible but NOT_STARTED. Draft PR #29 stays unmerged;
      preserve existing owner-approval default for main integration. Final
      containing record is freshly checked after push without a self-hash.

D16 - 2026-10-17, S02 reproduction: retain all existing suites and their fresh
      T-prefixed evidence contracts. Run them with inherited UTF8 CP65001 and
      child-only environment changes; keep raw retained reports outside Git and
      bind redacted summaries by digest. Add one focused real-tool family to the
      existing CI runner without changing workflow permissions/pins or order of
      its final native-process check. Owner's bounded step authority suffices.
D17 - 2026-10-17, S02 classification: Windows 11 26300.9711 with the local
      2026-10-08 Git FFmpeg pair reproduces all three bitrate-clamping leads for
      mono/stereo. Preserve exact bitrate rejection and zero published bad files;
      record these as known late failures, not fixed compatibility. Stale saved
      selection and external-selection success stay PENDING_API; an owned JSON
      fixture is not a production config pass. Windows 10/other build/full matrix
      evidence remains open for later acceptance. No owner diagnostics needed.
D18 - 2026-10-17, S02 checkpoint: preparation
      76339f97211868b3bd23bb1557cc91469d287270 is clean/live-equal in PS5.1 and
      PS7; push CI39045431885 and PR CI39045437165 pass. Downloaded reports prove
      new focused family execution as well as old retained suites. Record push
      exact feature checkout separately from PR integration
      ac3eed99df04d021a8d7ee60d7ab230c4e14b6cf. Mark S02 complete and S03 eligible
      but NOT_STARTED; final docs-only containing HEAD/CI is observed after push.
      Main integration and S16/S17 exact-byte publication authority are unchanged.

D19 - 2026-10-17, S03 deadlines: extend the existing native helper with opt-in
      operation deadlines, retaining zero/unlimited encode/full-decode runtime.
      Version/capability checks default to 15 seconds; source/output probes to
      60 seconds with public ProbeTimeoutSeconds override. Independent pipe
      polling avoids blocked reader disposal; retain bounded diagnostic snapshots
      and require owned child exit plus drained/disposed pipes for release proof.
      Held inherited writers withhold release and preserve transaction partials.
      No process tree/name termination, persistent settings or dependency download.
      Adapt retained proxies additively; preserve all old assertions/contracts.
      Normal bounded S03 authority suffices; main/release authority is unchanged.

D20 - 2026-10-17, S03 validation: preserve inherited console CP65001 in the
      outer test host; CreateNoWindow accidentally selected CP437 in initial
      local replay, producing Unicode characterization failures. Those attempts
      are invalid for final acceptance and retained privately, not hidden.
      Restore inherited console and rerun without changing product safeguards.
      Preparation CI reached the retained help suite and correctly rejected the
      stale nine-parameter expectation. Add only the authorized advanced probe
      parameter to that exact help contract; retain all descriptions/examples,
      ownership and source-safety assertions. Repeat exact-head CI on the fix.

D21 - 2026-10-17, S03 CI fixture startup: both PS7 hosted runs on 709370a
      correctly returned Timeout/released/EOF at 533-534 ms, but the cold .NET
      fixture had written zero characters. PS5.1 passed the complete family.
      Increase only deliberate fixture budgets from 500 ms to 2000 ms, retaining
      exact output/EOF/ownership assertions and adding explicit readiness proof.
      Held-pipe lower bounds use their configured 300 ms drain deadline. Save
      caught startup details before assertions. Production 15-second/60-second defaults,
      probe overrides and runtime bytes remain unchanged. Repeat focused local
      tests and exact-head CI; no owner approval or safeguard exception needed.

D22 - 2026-10-17, S03 checkpoint: runtime 0d2d8ff remains unchanged in source
      9b30f96f3f280e6c9e04b33285ee9f40ee3c0d8a. Final3 focused 15 cases per shell,
      corrected CP65001 baselines and retained suites pass. Push CI 39048368905 and
      PR CI 39048372292 pass; artifact reports prove every focused/retained CI family.
      Mark S03 complete and S04 eligible/NOT_STARTED. Final docs-only containing
      HEAD/live/CI is observed after push, without another self-referential record.
      Keep main integration and S16-to-S17 publication authority separate.

D23 - 2026-10-17, S04 selection: freeze FfmpegDirectory and ConfigPath as public
      conversion options. Explicit selection overrides config contents for this
      run; invalid explicit/saved selections stop without fallback. Retain only
      a complete pair directly beside the app, then absolute PATH entries; never
      mix a local executable with PATH or discover tools from the input/CWD.
      Preserve separately installed PATH pairs, warning on differing build IDs.
      Reuse bounded startup validation and disclose PE architecture where known.
      No UI/setup/download or automatic config mutation is introduced in S04.
      Normal bounded step authority suffices; main/release authority is unchanged.

D24 - 2026-10-17, S04 config: resolve the default with Windows LocalApplicationData
      APIs; ConfigPath is a legitimate portable/test override. Deliberate
      Save-AudioToolSelection uses 64 KiB UTF-8 schema1, an exclusive temporary
      lock, guarded reads, identity/hash checks and atomic publication. Reject
      corrupt/unknown schemas, ambiguous keys, JSON comments/trailing commas and
      read-only/locked storage; preserve the old selection on observed failure.
      Replace only the root directory string token in existing valid JSON so
      unrelated dates, decimals, escapes and nested fields survive verbatim.
      Guards close for Windows atomic replacement; this does not promise serial
      isolation against an arbitrary external editor racing the final check.

D25 - 2026-10-17, S04 evidence isolation: retained actual-entry launches now use
      owned absent ConfigPath values. Exact public help examples retain their
      text through the existing audited loader's owned config resolver. No old
      assertion or historical report-path contract is removed. An initial
      PS5.1 fixture read BOM-less UTF-8 driver text as ANSI; EncodedCommand then
      duplicated information as CLIXML, even with Text output requested. Use a
      BOM-marked UTF-8 -File test driver to preserve Unicode and retain all native
      output/release assertions. Failed preparation reports
      remain private and are classified separately from accepted final runs.

D26 - 2026-10-17, S04 checkpoint: source
      f1a7b17e3f9a1074059cd4d2de424d90adad0a78 is pushed/live-equal. All 24
      final local reports pass on the available Windows 11 client in both shells;
      focused selection has 14 cases each. Source push CI 39050312230 and PR CI
      39050314938 pass all four jobs; artifact reports prove 194 checks and 3
      observations per job, with PR integration 53736bdfe2c85d0effb44ee98b8e550046c6bd94
      recorded separately from the feature SHA. Mark S04 complete and S05
      eligible/NOT_STARTED. Observe the final containing docs HEAD/live/CI after
      push in the final response; no self-containing SHA or main merge authority.
