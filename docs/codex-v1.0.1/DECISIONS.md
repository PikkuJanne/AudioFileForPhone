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

D27 - 2026-10-17, S04 final compatibility audit: the initial exclusion of every
      absolute PATH entry equal to CWD breaks a valid legacy setup when launched
      from its explicitly configured tool bin. Supersede that part of D23: honor
      absolute PATH entries regardless of current directory. Enumerating only
      absolute entries already prevents implicit CWD, blank and relative '.'
      discovery. Remove only the equality filter and add real positive coverage
      for both current-directory forms plus blank/relative decoy rejection.
      Reopen S04 for refreshed source/runtime evidence and CI; retain prior
      f1a7b17/a6e70d4 validation as earlier evidence, not final corrected bytes.
      This restores the owner's legacy-compatibility requirement; no new approval
      or S05 work is needed. Other selection and release safeguards remain.

D28 - 2026-10-17, corrected S04 checkpoint: source
      68e14aded3c2e80493512af8cc10d5abe34c4c19 passes 10 targeted local reports:
      selection 14, pure contracts 31 and help 7 cases per shell, plus isolated
      real baseline/validation. Both current-directory forms and blank/relative
      decoys are covered. Preserve the earlier 24 full local reports separately
      under prior_validation at f1a7b17. Corrected-source push CI 39051385250 and
      PR CI 39051387556 pass all four jobs, 194 checks/3 observations/14 selection
      cases each; PR integration is 34c0f2d1cb919c9925e4c4860346dbf7fb8a6f0c.
      Mark S04 complete and S05 NOT_STARTED. Final containing docs HEAD/live/CI
      is observed after push without a self-hash. Main/release authority stays
      separate; no owner action is needed for this step.

D29 - 2026-10-17, S05 setup: add separate existing-tool PS1/BAT entries and one
      shared Invoke-AudioToolSetup over S04 resolver/save APIs. Accept only the
      explicitly selected exact bin directory, validate capabilities and display
      identity/hashes under read guards. Ask before remembering; explicit Remember
      is deliberate consent. Interactive conversion resumes the same launch before
      metadata/output reservation. Failed save clearly says NOT remembered and
      permits current-launch use; standalone requested-save failure returns 1.
      No download or S06 implementation; D is visibly unavailable. Normal bounded
      step authority suffices, with main/release authority unchanged.

D30 - 2026-10-17, S05 interaction: use one-shot S/M/D/Q and remember inputs, a
      Windows Forms picker with typed fallback only when unavailable, distinct
      cancellation/EOF and actionable errors. Host.UI.ReadLine respects actual
      NonInteractive host authority. Preview bypasses all setup/config/tool calls;
      normal noninteractive conversion only displays a quoted repair command.
      Print that command outside formatted error records to preserve copyability.
      Setup BAT uses full SystemRoot PS5.1, STA and process RemoteSigned; no
      post-entry fallback, argument forwarding, persistent policy or PATH change.

D31 - 2026-10-17, S05 evidence repairs: retained help correctly caught README's
      new setup fences preceding the original five examples. Move the walkthrough;
      keep the existing ordering/text assertion. Capture of a strict exact-repair
      failure showed hidden PS5.1 diagnostics decoding Unicode as replacement
      characters. Match retained UTF8 test drivers and audit child CP65001; establish
      UTF8 in the owned hidden CMD fixture before its Unicode literal path. Keep
      all strict assertions and record failed attempts privately by hash. A local
      package policy run rejected the supplied Git build because it requires the
      retained CI-pinned 9.0.2 tools. Preserve that precondition and use passing
      exact-source pinned CI for package-policy evidence, not release acceptance.

D32 - 2026-10-17, S05 checkpoint: source
      cea42175a309fc841445f2765fc19e1d6de4c35e is pushed/live-equal. All 26 accepted
      local reports pass; focused setup has 15 grouped cases per shell. Retained
      reports on dcc9408/6b09917 share all final runtime bytes; actual tested
      commits remain distinct. Push 39058815762 and PR 39058820107 pass all four
      jobs; downloaded reports prove 211 required checks, 3 observations and 15 setup
      groups each. PR integration checkout 00d1f0df363e0c8ea5e89757af2d67ff5aaa9c1c
      is separate from exact push source. Mark S05 complete and S06 eligible but
      NOT_STARTED. Final containing docs HEAD/live/exact-head CI is observed after
      push in the final response without a self-hash. Main remains unintegrated;
      no release/tag operation or owner action. Public v1.0.1 remains PENDING_S17.

D33 - 2026-10-18, S06 consent and pin: keep network installation exclusively in
      separate setup. Conversion's D choice prints that separate route and stops.
      Interactive setup displays provider/build/bytes/destination/hash/license/
      source before Y; unattended setup requires Download plus Consent. Remember
      remains independent. Pin exact direct Gyan 9.0.2 essentials Windows x64 ZIP,
      114768076 bytes / SHA256 60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba,
      verified against published vendor SHA and publisher asset digest. Scoped
      HTTPS redirects, normal certificate validation, transfer deadlines/size and
      reviewed expanded/count bounds are mandatory. No runtime latest lookup,
      update, global install or user-managed tool replacement. Default private
      storage is managed beside ConfigPath, with explicit ManagedRoot portability.

D34 - 2026-10-18, S06 extraction: malicious fixtures established that ZipArchive
      can truncate real deflate output to forged central sizes, including matching
      lies in both headers. Do not weaken those tests. Independently bound EOCD
      and central parsing before entry allocation, compare local/central metadata,
      refuse unsupported ZIP64/descriptors/encryption, reject unsafe/colliding/
      linked paths and overlap, then decode bounded raw payloads with actual byte
      counts and CRC32. Directory entries must be empty stored entries. All vendor
      files/notices survive; shared capability checks and synthetic encode/probe/
      full decode precede unique directory publication and optional atomic save.
      These restrictions apply to the reviewed managed ZIP, not existing-tool
      version/capability compatibility. Keep normal conversion runtime unlimited.

D35 - 2026-10-18, S06 Windows publication/input: repeated successful-install tests
      and real vendor setup exposed a deterministic transient rename denial. A
      read-only RestartManager query of exact owned files identified an external
      Windows service; identical unique rename succeeded after one second. Retry
      only access/sharing errors 5/32/33 for at most five seconds, checking owned
      marker, no reparse path, absent destination and binary identities/hashes on
      every attempt. No service/process/security setting is changed. Capture Ctrl+C
      only during managed work, dispose before remember input; menu/consent typing
      must not be consumed by polling. Retain UTF8 CP65001 in owned hidden drivers.
      Initial local outer-driver encoding failures and the retained root-only ZIP
      test failure remain honest preparation evidence. Permit only the exact nested
      tools/ffmpeg-download.json in package policy; retain all other path defenses.

D36 - 2026-10-18, S06 final cancellation/diagnostic repair: case50 first reproduced
      that disposing the setup-owned context after install could lose a pending
      request before Remember. Assert while active, then inspect its request flag
      after disposal; preserve completed install but stop config selection/save.
      The labeled engine-result injection proves no later validation/save. Earlier
      aceaa4d CI passed PS7 and failed PS5.1 when ErrorRecord wrapped D's no-download
      sentence. Print that short sentence separately; retain the strict assertion.
      These five helper lines do not change normal conversion/runtime defaults.

D37 - 2026-10-18, S06 checkpoint: tested source
      69bce4ac129b7acc0d95b4d9f443e782efdd8763 includes final helper repair; engine
      and pin remain byte-identical to 70bd752. All 10 final targeted local reports
      pass in both client shells, with 50 setup/security and 3 real primary-install/
      saved-conversion groups per shell. Broader retained prior validation records
      its actual source/runtime hashes; no relabeling as final bytes.
      Exact-source push 39074124256 and PR 39074127630 pass all 4 jobs; downloaded
      artifacts bind actual tested checkouts and every retained/managed family.
      Keep failed preparation evidence separate. Mark S06 complete and S07
      eligible/NOT_STARTED. The containing docs HEAD/live/exact-head CI observation
      belongs in the final response after push, without a self-containing SHA.
      Main integration remains separate under S14/owner approval. No tag/release
      operation or owner action; public v1.0.1 remains PENDING_S17.

D38 - 2026-10-18, S07 interaction: show Ready with actual count/bitrate after
      successful preflight/setup. Enter starts immediately; M exposes the existing
      metadata controls and explains automatic continuation; Q/EOF cancel130.
      Invalid/pasted input fails1 and is never evaluated. Read each stage once
      through named metadata UI adapters; actual unavailable/NonInteractive input
      cannot start a batch. Explicit Artist/Album values, including blank retain-
      source values, skip M controls. No batch metadata is persisted. Durable
      phase labels distinguish probing/encoding/validation/publication; accurate
      final counts remain. Existing setup APIs and managed safeguards are intact.

D39 - 2026-10-18, S07 verification: preserve preflight writability semantics,
      which may leave an empty OutputParent, while requiring zero batch/config
      entries and only the three exact bounded tool-selection native operations
      on stopped choices. Real output tests independently probe tags/bitrate/
      artwork pixels, full decode and440Hz sound. A first tiny-tone assertion
      counted MP3 boundary noise; stable middle-half measurement now excludes it
      with a tighter10Hz tolerance. PS5.1 formatted diagnostic wordwrap is handled
      by whitespace normalization of the observed NonInteractive token; the real
      reader and no-batch checks remain unchanged. Private module/newline/contract
      preparation failures and earlier reports remain honest non-passes/prior
      validation. Null EOF injection is not physical-console observation.

D40 - 2026-10-18, S07 checkpoint: sourcec08d97571bd70d140acc89c1de86e2fc0f4c6583
      has six exact-source final focused/first-run/native reports; all30 accepted
      local reports pass. Twenty-four retained reports keep entry889db48 and
      actual matching final runtime hashes. Native35 runs last and sequentially
      in both shells. Mark S07 complete and S08 eligible/NOT_STARTED. Commit source
      locally, then push one containing evidence/documentation checkpoint and
      observe fresh advertised equality/exact-head push and PR CI in the final
      response, without a self-containing SHA or invented standalone source CI.
      Main integration stays separate under S14/owner approval. Managed50 case50
      remains engine-result injection; S06 real vendor installs remain separate.
      No owner action, tag/release operation or changed frozen/public bytes.
      Public v1.0.1 remains PENDING_S17.

D41 - 2026-10-18, S08 startup: keep the one-folder BAT thin and delayed expansion
      disabled. Transport the received input through process-local environment,
      anchor the bootstrap to native x64 Windows PowerShell, and invoke a small
      launcher with -NoProfile/-STA/-File/RemoteSigned. HostPath (or process-only
      AUDIOFILEFORPHONE_HOST for BAT) is an exact absolute local .exe choice with
      no fallback. Preserve the direct application parameter route and existing
      FfmpegDirectory/ConfigPath APIs. No persistent environment/policy change.

D42 - 2026-10-18, S08 selection: probe at most three absolute-PATH PS7 candidates,
      a conventional installed PS7 path and native PS5.1. Implicit CWD/relative
      PATH entries confer no selection authority; explicit absolute PATH=CWD is
      preserved. Use the existing bounded native helper with a default15-second
      per-probe deadline (advanced1..60), bounded capture/drain/owned teardown.
      A known missing executable creates no pipes; record that safe absence
      separately from the raw native no-pipe field. Only unavailable identities
      or safely released timeouts allow pre-entry fallback. Unknown startup
      refusal, managed language/signing policy and unproved release stop it.
      Store aliases resolve to a full actual executable and repeat the probe;
      require unchanged path/version/edition/architectures/STA/language/policy.
      After one application start there is no retry, including nonzero exits.
      Normal conversion and full-decode runtime remain unlimited.

D43 - 2026-10-18, S08 identity/privacy: keep the host probe application-independent
      and side-effect-free. Import only its own built-in Security module before
      reading policies, avoiding inherited cross-host module autoload. ASCII-
      escape JSON without changing console encoding so Unicode executable paths
      survive PS5.1 capture. Prepend the selected host's Modules only in the child
      environment. Retain an interactive console outcome with guarded ReadKey;
      redirected/unavailable input never waits. Missing launcher has a fixed
      console-only diagnostic wait; absent bootstrap prints the direct route.
      Required helper checks precede stack traces. No network, settings, Music
      lookup or media work occurs during host selection.
D44 - 2026-10-18, S08 verification: separate actual host runs from injected
      policy/architecture/release decisions and physical UI observations. Real
      portable PS7 7.6.5, Store PS7 7.6.7 and PS5.1 pass x64/STA; classic MSI
      is not installed. An owned hidden .lnk route passes without Desktop writes.
      Retained characterization uses explicit direct hosts, while focused Store
      tests independently resolve the expected actual path. Keep raw reports and
      every nonpass private, bound by redacted summaries/digests. Healthy fallback
      tests use 15s for a missing candidate and 5s for a hanging candidate plus
      actual PS5.1; the separate strict 1s hanging-child deadline remains unchanged.
      Package provenance checks require the CI-pinned9.0.2 tools, provisioned only
      through the existing explicit development helper. Conversion keeps the
      existing local Git build and performs no download. Preserve original S03
      PS51 held-pipe fixture failure with unknown stderr and retained scope;
      unchanged isolated final15 and narrow identical-fixture diagnostic pass.
      No timeout/release/cleanup safeguard or assertion is suppressed.

D45 - 2026-10-18, S08 checkpoint: tested source
      64628f05a86957e2381e5bf1041ce5ecd49da4f3 changes only fallback-test budgets
      after production source d5db9cb6a6e20373dbb599fc5d4e79164ef7e99c. All22
      accepted local suite reports pass694 groups; seven identify64628f0,
      fourteen d5db9cb and one first-run entry73bb303 with matching final runtime
      hashes. Native35 runs last/sequentially. Static analyzer1.25 passes10 files
      with zero diagnostics in both shells. Commit one containing evidence/docs
      checkpoint, push, then observe fresh advertised equality and exact-head
      push/PR CI in the final response without a self-containing SHA. S08 complete;
      S09 eligible/NOT_STARTED in a separate thread only. Main stays unmerged under
      S14/owner approval. No owner action, tag/release operation or changed frozen
      bytes. Fixed public v1.0.1 remains PENDING_S17.

D46 - 2026-10-27, S09 measured MPEG planning: both selected Windows FFmpeg builds
      report nine libmp3lame sample rates. Independent 648-case encode/probe/full
      decode research proves MPEG 2.5 below 16 kHz stops at 64 kbps; MPEG 2 up to 24 kHz
      permits 8..160 including 144; MPEG 1 at 32/44.1/48 kHz excludes8/16/24/144.
      Intersect these tested tables with actual selected capabilities. Preserve a
      compatible source rate, otherwise choose nearest Hz, ties lower. Keep all 18
      advertised values and validate exact stream bitrate; decode alone accepted
      all 216 clamped research outputs and cannot replace that check.

D47 - 2026-10-27, S09 shape and stream selection: extend first-audio probing with
      codec/rate/channels/layout while keeping metadata and duration inspection
      independent. Preserve mono/stereo. Explicitly use standard FFmpeg stereo
      rematrix for ten known layouts with matching counts, reject others before
      encoding. All ten have actual source-shape and production full-decode
      evidence on both builds, including valid Ogg-coded side-layout fixtures.
      Share one builder for both cover paths with output-scoped-ar/-ac and existing
      audio/metadata maps. Manifest adds plan and observed shape; validator retains
      exact bitrate, fixed 0.35-second duration, strict full decode and transaction
      guards. No normalization, trimming, padding or runtime ceiling is introduced.

D48 - 2026-10-27, S09 capability release: query selected encoder help once after
      interactive input, never trial-encode user sources. If capability release
      is unproved, record the first incompatibility and stop before another native
      operation can overwrite its retained identity. Independent review caught
      this continuation risk; a real-app test substitutes refusal only after the
      real capability child completed/released/drained, retaining actual cleanup
      authority. Injection is not a genuinely unproved child acceptance claim.

D49 - 2026-10-27, S09 test repairs: initial matrices passed 495 + 4 media groups but
      failed Remove-Item cleanup before deleting owned trees. Enhanced diagnostics,
      exact ACL/marker/no-reparse and exclusive-read checks found intact trees;
      parent enumeration was denied. Reuse the exact Directory.Delete API already
      used by retained suites, with every original release/boundary/token/reparse
      guard; separately owned two-file and final full-matrix cleanup pass. Do not
      change ACLs/processes/policy or add a broad retry. Preserve failed reports.
      Strengthen stale diagnostics to the exact five-stage set, give legacy
      regression drivers an owned absent ConfigPath, retain integrity rejection
      of concurrent CI edits and correct private argument binding without changing
      runtime APIs. Required analyzer rules remain intact; exploratory old test
      variable warnings are not silently suppressed or called a pass.

D50 - 2026-10-27, S09 checkpoint: tested source 1dcf1b398d610dd478922d5dba672992ca4d5d0f
      changes tests/CI after production/runtime 57f90c4f73c385b0b0e562f487b8cf945a60de2a.
      All 26 accepted local reports pass 666 groups, 1,980 matrix + 128 actual app
      conversions and 92 default PCM equalities; preserve actual 6/10/10 report
      checkout counts at 57f90c4/5e513e4/1dcf1b3 and matching runtime hashes. Native 35
      runs last/sequentially. Exact-source push 40525113343 and PR 40525121428 pass
      all 4 jobs; downloaded wrappers each bind 857 checks, 3 observations and all
      families; PR integration 0303ea678cc90399cf939eff6147b98c8b4d8322 stays distinct.
      Commit containing evidence/docs, push and observe fresh equality/exact-head
      CI in the final response, without a self-containing SHA. S09 complete; S10
      eligible/NOT_STARTED in a separate thread only. Main remains unmerged under
      S14/owner approval. No human action, tag/release operation or changed frozen
      bytes. Fixed public v1.0.1 remains PENDING_S17; runtime remains 1.0.0.

D51 - 2026-10-28, S10 diagnostics contracts: use an independent functions-only
      bootstrap before the converter helper, with explicit stage/code boundaries
      and optional production resolver traces. Keep private bounded local reports
      separate from whitelist-only support review/export. Startup logging first
      tries LOCALAPPDATA then unique TEMP and never replaces the console cause.
      Default Check and converter DryRun failures remain console-only. Support
      imports are bounded UTF8/schema checked and need no converter helper.
      No upload, downloader or settings persistence is added to conversion/check.

D52 - 2026-10-28, S10 self-test/release review: reuse production resolution/audio
      planning/transaction/full-decode functions, with one uniquely reserved TEMP
      scope, held marker identity, fixed deletion inventory and release proof.
      Missing fixture support is SELF_TEST_UNAVAILABLE, timeouts stay distinct,
      and final cancellation preserves130. Default checks reject remote config/
      tools before access and skip remote PATH entries without changing normal
      conversion selection. Review found/fixed interactive setup continuation
      after unproved prerequisite release; it now stops before another native
      operation. Returned-result refusal tests are explicitly labelled injection.
      Full S10 evidence and checkpoint gates remain in S10.json; no main/release
      authority or new human diagnostic work is inferred.
D53 - 2026-10-28, S10 verification checkpoint: exact source/runtime b05b581 has
      final support27, package61 and native35 per shell plus17-file zero-diagnostic
      analysis. All24 accepted local reports pass644groups and6observations; keep
      actual9ec82803/7at35cc0a7 report identities with matching runtime hashes.
      Native runs last/sequentially. Preserve preparation nonpasses and uncertain
      scopes, including a fixture crash rather than diagnosing it as an OS fault.
      Initial source PR/PS7 CI failed an owned startup-fixture compilation assertion
      before S10; its cause is not established. Source push/PS7 passes891checks,
      and containing checkpoint CI must pass on its exact pushed head. No pending
      checks are passes and no assertion/deadline/release safeguard was disabled.
      Checkpoint docs only, observe advertised equality and exact-head CI after
      push without self-hashing. If that gate fails or remains unobserved, resume
      S10. S11 stays unstarted in this thread; main integration/owner acceptance/
      fixed v1.0.1 publication remain separate later gates.
D54 - 2026-10-28, S11 duration/audio campaign: retain production runtime b05b581
      and fixed0.35second validation; no genuine valid-media mismatch justified
      changing policy. Four495-case matrices and four10-conversion complementary
      corpora pass both shells/builds, alongside actual3605second CBR/VBR media.
      Plausible3.137007second truncated header decodes1.072086seconds and rejects
      despite decoder exit0. Preserve unknown-duration/refusal injections as such.

D55 - 2026-10-28, S11 fixture and filesystem evidence: native opened-directory
      spelling repairs TEMP/Temp test-fixture casing while exact CWD assertions
      remain. Opus fixture explicitly48000; atomic owned reservation and source/
      fixture/native-release/cleanup gates remain. Actual ACL/readonly/locked/
      moved-source cases are distinct from labeled ENOSPC prefix/result injection.
      Keep original nonpasses and interrupted cleanup uncertainty; no broad cleanup
      or reparse bypass and no invented physical/full-disk/cloud/UNC acceptance.

D56 - 2026-10-28, S11 checkpoint: test source8145006 changes only three test files;
      runtime13 hashes still b05b581.70 suite reports+2analysis pass1752groups and
      6observations,2020 direct planned/validated conversions and128 application
      matrix conversions;132 default PCM equalities. Keep actual53c6c63bf/17at
      8145006 suite identities and2analysis at8145006 with runtime hash ties.
      Fresh pinned development dependencies replace a refused pruned cache, not
      an application download. Native runs last/sequentially. Observe containing
      checkpoint advertised equality/exact-head CI after push without self-hashing;
      pending/failure requires S11 continuation. Windows10 stays blocked for S15;
      S12 remains unstarted until a new owner thread. Main/S14 approval and fixed
      publicv1.0.1 S16/S17 exact-byte publication authority remain unchanged.
