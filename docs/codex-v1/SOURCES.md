# Primary sources and review provenance

Checked while preparing the handoff on 8 October 2026. Specifications and task
choices are project recommendations; API/CLI behavior should be rechecked against
the installed versions during implementation. No dependency checksum is invented.

| ID | Primary reference | Use |
|---|---|---|
| S1 | https://github.com/PikkuJanne/AudioFileForPhone/commit/2bf1ea1921ab33633b978bd384bbbf098648ceed | Reviewed source snapshot; not a runtime test |
| S2 | https://developers.openai.com/codex/agent-configuration/agents-md | Small repository guidance and task-specific references |
| S3 | https://www.ffmpeg.org/ffmpeg.html | Native options including -nostdin and machine-readable -progress |
| S4 | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing?view=powershell-7.5 | Native argument parsing differences and executable examples |
| S5 | https://docs.github.com/en/actions/reference/security/secure-use | Action SHA pinning and least privilege |
| S6 | https://ffmpeg.org/ffmpeg-filters.html#loudnorm | Optional measured loudness mode and fallback/sample-rate behavior |
| S7 | https://cli.github.com/manual/gh_release_create | Existing-tag verification and draft release creation |
| S8 | https://cli.github.com/manual/gh_release_edit | Explicit draft/publication/prerelease flags |
| S9 | https://cli.github.com/manual/gh_release_download | Download actual uploaded assets |
| S10 | https://cli.github.com/manual/gh_release_view | Inspect release metadata |
| S11 | https://git-scm.com/docs/git-ls-remote | Compare with remote-advertised refs and peeled tags |

The full FFmpeg filter page initially timed out; its official indexed documentation
was subsequently retrieved for the loudnorm section. No non-primary technical
source is relied on. The current app and Windows/phone behavior still require the
real tests assigned in the plan.
