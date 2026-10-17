# Merge these active rules into root AGENTS.md

- The active project is the incremental v1.0.1 setup/compatibility plan under
  docs/codex-v1.0.1. Read CHARTER, STATE, STATUS and NEXT_SESSION, then only the current
  task/specs. Preserve historical docs/codex-v1 rather than using its completed
  state to skip this work.
- Exactly one numbered step per thread. At success, failure, capacity boundary or
  missing evidence: checkpoint what is safe, give a full handover and STOP. Never
  begin the next numbered step until the owner starts it in another thread.
- Preserve existing runtime/defaults/safety. No rewrite, website, production Python,
  silent downloads, persistent PATH changes, elevated setup or telemetry. A separate
  consent-based dependency setup helper is expressly allowed by the new charter.
- Target Windows 10 22H2 x64 and Windows 11 x64 with PS5.1 and PS7. Automate all test
  matrices and source/media checks; consolidate human actions into S15's simple kit.
- Update STATE, STATUS, NEXT_SESSION, evidence and decisions each step. Review, test,
  commit/push allowed changes and compare local HEAD with fresh live remote HEAD.
  Distinguish feature-branch sync, main integration and pending CI.
- Preserve unrelated work, repository policy, current artwork, tags and release
  assets. Do not overwrite v1.0.0. S17 publication requires the S16 exact-identity
  authorization prompt. Do not invent a pass to satisfy a release gate.
- A broken environment is a named BLOCKED result, not success and not permission to
  disable protections. Resolve safe local failures within the current step and
  record missing evidence. Provide the exact next-thread prompt in every handover.

- The owner has fixed the end product as public v1.0.1. Read RELEASE_TARGET.json;
  runtime 1.0.1, tag v1.0.1, title AudioFileForPhone v1.0.1 and
  AudioFileForPhone-v1.0.1.zip must agree. S17 must publish; S18 must verify closure.
  A draft, prepared ZIP or release-ready handover is not completion.
