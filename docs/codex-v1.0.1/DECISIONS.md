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
