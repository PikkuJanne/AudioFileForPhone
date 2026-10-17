# Roadmap — one numbered step per thread

18 steps. 54 required acceptance criteria. All statuses start NOT_STARTED.
Human work is concentrated at S15; S16 permits only necessary affected-path retests.

| Step | Deliverable |
|---|---|
| S01 | Reconcile baseline and activate the new plan |
| S02 | Capture regressions before fixing them |
| S03 | Add bounded short-operation execution |
| S04 | Implement explicit and remembered tool selection |
| S05 | Add first-run setup and manual recovery |
| S06 | Implement consent-based managed dependency setup |
| S07 | Simplify metadata interaction |
| S08 | Harden the BAT and PowerShell startup route |
| S09 | Plan valid bitrate and sample-rate combinations |
| S10 | Ship diagnostics, early failure reports and self-test |
| S11 | Run compatibility and failure regression campaign |
| S12 | Add clean-environment CI and release gates |
| S13 | Build the one-click acceptance kit |
| S14 | Integrate and freeze the exact release candidate |
| S15 | Collect the single owner acceptance session |
| S16 | Resolve acceptance and prepare exact release authorization |
| S17 | Publish and verify the new public release |
| S18 | Close with final main synchronization |

Accepted improvement mapping: dependency selection -> S04/S05; absent-dependency
setup -> S06; clear prompts -> S07; sample-rate/bitrate correctness -> S02/S09;
host startup -> S03/S08; diagnostics -> S10; bounded waiting -> S03; client/package
acceptance -> S11-S18. Duration and cloud-path investigation stays evidence-driven
in S11, not a blanket feature expansion.

A failure is repaired before closure. S16 can be explicitly entered to repair a
known S15 issue, but that never waives S15's final-candidate acceptance. The state
must show that recovery exception and clear it when the required rerun succeeds.
