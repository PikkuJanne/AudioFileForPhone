# AudioFileForPhone: focused repair — no human testing

Revision: owner follow-up, 30 October 2026. This file replaces the previous `AudioFileForPhone_Focused_Repair_for_Codex.md`; it does not restart completed work.

## Latest owner requirements — take precedence

The owner reports that `AudioFileForPhone-Recovery.bat` got the existing tool running and producing working audio files. Record this as an owner-reported successful recovery, not as an independently measured pass of every file, shell, shortcut, or final package. Do not ask for another run, screenshots, a recording, logs, a report, or a playback confirmation to substantiate it.

**There will be NO human testing in this repair.** All new verification is Codex's responsibility, using its available machines, VMs, runners and automation. Remove earlier owner-acceptance tasks from the active instructions and handovers, including the final ordinary-use test and phone check. Do not relabel a test as a quick confirmation, normal use, or a release prerequisite to assign it back to the owner. Starting the next Codex thread is not a request to test software.

The recovery launcher is a functional reference, not the final appearance or universal dependency configuration. Preserve the direct launch behavior that worked; do not preserve its temporary recovery branding or hardcode the owner's FFmpeg directory into the public tool. Finish with the existing icon, a clean small download and a restrained console. No new GUI, artwork, installer framework or feature programme.

Keep the three steps below, one per thread, with a handover and STOP. If repairs have already started, merge this change into the active instructions, preserve completed implementation and valid evidence, and resume the current unfinished step. Do not regenerate the old 18-step plan.

## Instruction to Codex

Repair the existing tool. Do not start another improvement programme or rewrite the converter. The normal user experience must be: extract the application ZIP, make a shortcut to the clearly visible BAT using the clearly visible ICO, drop one audio folder onto the shortcut, and obtain validated MP3 files. Startup failures must remain readable.

Work in PikkuJanne/AudioFileForPhone. Read the existing AGENTS instructions and inspect the current checkout/live GitHub before editing. These owner-directed corrective requirements supersede earlier plans that require a complex default host-selection layer or ship developer material to users. Preserve unrelated work, tests and historical evidence. Do not force-push, change repository protections, or publish over existing release bytes.

Do ONE repair step per thread, provide the short handover below, then STOP. There are three repair steps, not another 18-step project. Keep each completed checkpoint committed and pushed to the current work branch; compare HEAD with the live advertised remote ref. Report main integration separately. No automatic release in steps R1 or R2.

## Evidence, not assumptions

- Owner: Windows 10 Home 22H2 x64; existing ffmpeg.exe and ffprobe.exe at C:\ffmpeg\bin. Earlier version checks and libmp3lame check passed. The later owner report confirms that the recovery BAT started the tool and produced working audio files. Exact final-package hashes, total converted count and universal compatibility are not established by that report.
- Owner's previously reported setup error: Setup-AudioFileForPhone.ps1 cannot be loaded because it is not digitally signed. Converter shortcut exits before its error can be read.
- v1.0.1 AudioFileForPhone.bat invokes AudioFileForPhone.Launcher.ps1 with RemoteSigned, then immediately exits. Its normal route has no BAT-level pause. The pause inside the PowerShell launcher cannot run when that launcher is rejected before entry.
- Setup-AudioFileForPhone.bat also uses RemoteSigned. The PowerShell launcher additionally uses RemoteSigned for its probe and application children. Changing just the outer process can therefore be insufficient if the old chain remains.
- RemoteSigned rejects unsigned Internet-marked scripts. The owner's exact Zone.Identifier and policy scopes have not been collected, so do not claim to have proved them. Reproduce this case on a disposable NTFS test directory, and separately handle managed policy refusal honestly.
- Live release metadata inspected 2026-10-30 describes v1.0.1 package revision 2, with a clean app/ layout and unchanged converter. That is not proof of the archive the owner downloaded, its icon contents, or working launch behavior. Re-fetch live state.
- Existing v1.0.1 source supports -FfmpegDirectory. An explicit directory can use the owner's existing binaries without setup, saved config changes, downloads or PATH edits.

## R1 — Restore a simple, visible launch path

Prefer one BAT -> one built-in x64 Windows PowerShell 5.1 STA process -> existing AudioFileForPhone.ps1. Keep direct PS7 use available; do not make a multi-engine health-probe chain mandatory for ordinary folder-drop use. Keep the existing audio engine, validation and safety mechanisms intact.

For this trusted unsigned personal application, use an explicitly documented process-only -ExecutionPolicy Bypass request on the selected launch route, rather than claiming RemoteSigned will accept an unsigned downloaded file. No persistent Set-ExecutionPolicy, registry edits, blanket Unblock-File, disabled antivirus, administrative rights, policy evasion, or alternate-engine retries after a policy block. MachinePolicy/UserPolicy and application control remain authoritative. A managed-policy denial must remain visible; never re-evaluate a script's text to escape an enforced denial.

Alternatively, an actual trusted signing solution is acceptable only if genuinely available; do not invent certificates or introduce a signing infrastructure project. Do not silently remove download marks from the application or unrelated files.

Place the final error/status reporting and pause in CMD/BAT, not solely inside a PS1. Capture ERRORLEVEL immediately and retain it after pause. Cover unavailable host, missing runtime, policy refusal, parsing failure, invalid argument, cancellation and ordinary conversion result. Do not guarantee visibility after forced window termination.

Keep delayed expansion off, use absolute app paths relative to the BAT, and safely pass spaces, parentheses, ampersands, percent signs, exclamation marks, apostrophes and Unicode. Do not use CALL to forward untrusted arguments or construct executable PowerShell text from paths. Do not retry a batch automatically. Zero/multiple-folder invocations must display useful instructions and stay visible.

Fix the existing standalone setup BAT similarly. Audit any nested setup/process invocations that remain for policy inconsistency; do not globally replace unrelated policy documentation/test literals. Keep downloads optional and consent-based. Do not hardcode C:\ffmpeg\bin in the public launcher. Preserve explicit/saved/app-local/PATH resolution and existing selection UI. The separate recovery BAT supplied with this brief IS owner-specific and is not the final universal launcher.

Add focused automated Windows regression tests now. Tests must reproduce unsigned Internet-marked PS1 files, not only run a Git checkout without Zone.Identifier. A negative policy case must test that the BAT remains usable and reports the real error, rather than checking only internal functions. Use disposable fixtures/VMs for policy scenarios; never change the owner's workstation policies. Exercise the real launcher, with automation supplying console input and observing the wait/exit behavior rather than removing the production pause to make tests pass.

Stop with a handover after the targeted patch and tests. Do not delete the previous launcher or probe source until all references have been examined; unused development material may stay in Git but must not complicate the normal packaged launch path.

## R2 — Build a clean user package

The extracted application root must be intentionally small:

    AudioFileForPhone.bat
    AudioFileForPhone.ico
    README.txt
    app/

Use the existing AudioFileForPhone.ico from the repository. No new artwork. Put required PS1/configuration/support files, optional standalone setup and existing licenses/notices under app/. Preserve relative runtime dependencies; do not delete required helpers merely to reduce file count. The entry BAT must call the real converter under app/ directly, not CALL another BAT that reparses the dropped path.

Use an explicit release allowlist and test its output. Exclude AGENTS.md, docs/codex-*, plans, handovers, acceptance kits, test frameworks, test fixtures, build tools, CI files, private reports, large promotional PNGs, and generated output from the user archive. Those belong in Git, not the download. Keep the license and required notices in app/; the short root README must point to them.

README: three ordinary-use instructions, dependency selection where needed, and what to do when an error remains visible. Explain the process-local policy request accurately. Make the README's recommended download the application release asset, not GitHub's autogenerated source archive. The owner should not need to know the distinction to find the correct primary download.

### Final console presentation

Keep the original console workflow. Normal output should show a short application/version heading, the selected input and destination, the existing ready/customize choice where applicable, concise progress, and one clear final summary with converted/failed counts and output location. Avoid repeated banners, large separators, raw FFmpeg command lines, debug dumps, or recovery/test labels in the normal successful path. Retain detailed diagnostics in the existing local logs or an explicit verbose route; always surface actionable errors and the relevant log path. Never hide warnings, partial failure or cancellation for cosmetic reasons. Keep error visibility and exit-code behavior intact. Verify the text with automated captured-output assertions; use automated screen capture where available without making the owner review screenshots.

Use a new empty extraction destination for testing; do not delete or clean the owner's old installation. Test the BAT and ICO after relocation to a directory different from the build checkout. Preserve the exact icon and package hashes in build evidence. No bundled FFmpeg redistribution in this repair unless already explicitly approved and correctly licensed.

Stop with a handover and the candidate artifact identity. No public release yet.

## R3 — Automated package acceptance and release

Codex performs all new tests without human involvement. Use available Windows machines, disposable VMs or runners and the existing test harness; do not build a new general testing framework. Use the exact candidate archive, Internet-marked scripts, a non-administrator account, no developer-added FFmpeg PATH and no PowerShell profile assistance. Record whether Internet marks came from actual browser extraction or were applied to disposable fixtures for a deterministic regression; do not conflate the two. Exercise Windows 10 22H2 x64 and Windows 11 x64 where the support claim is made. Linux inspection is not Windows execution, and Server CI is not client-Windows evidence.

Use automated desktop/console interaction for genuine shell/shortcut cases where an interactive Windows session is available. A command-line invocation reproducing an argument is useful coverage but is not itself proof of an Explorer drag/drop event. Preserve this distinction in evidence. Do not ask the owner to supply a desktop session, perform a drop, or press keys for a test.

Test:

1. Extracted root contains exactly the intended visible entries, including the existing ICO.
2. Direct drop onto the BAT and drop onto a real .lnk targeting that BAT work from an unrelated working directory; application/source paths include spaces and non-ASCII text.
3. A complete FFmpeg pair outside PATH can be selected or explicitly configured and used; no reinstall/global PATH edit is needed.
4. Unsigned Internet-marked runtime files work through the chosen trusted personal-app launch policy. Enforced-policy refusal remains visible and is not evaded.
5. Missing host/helper/tool, corrupt media and invalid invocation have visible errors, correct exit codes and no in-place source changes.
6. One generated M4A and a generated multi-file batch of at least 30 M4A inputs actually finish with correct counts, MP3 audio streams, expected bitrate/duration, full decode validation and unchanged source hashes. Include a meaningful long-duration case and seek/decode checks using existing test facilities. A prompt or -DryRun is not a conversion pass. Use synthetic media; do not request, upload or automatically access the owner's private audio collection.
7. The setup entry point also works from the Internet-marked package, not only from a developer checkout.
8. Normal console output is concise, the icon is the existing asset, and the package root contains no developer/test clutter. Detailed diagnostics remain available when a failure is deliberately injected.

**Owner testing required: none.** Do not produce or send an acceptance kit for the owner, request a final smoke test, or make release dependent on a new owner playback observation. The existing successful recovery report remains historical owner evidence; new results must come from Codex's own automated executions. Machine-validated audio is not a claim that a human listened to it or that an untested phone/player worked. Keep private media and paths out of Git.

If a Windows environment or UI-automation capability is unavailable, first use other already available authorized execution environments. Record the exact remaining coverage gap; never report an unrun case as passed, silently convert a failed test into a pass, or claim a broader platform scope than the evidence supports. An essential unresolved launch/conversion/package failure remains a technical blocker for Codex to fix, not an owner-testing assignment. Never end with "awaiting user testing." Do not spend money, create external accounts or weaken security controls to obtain a test environment without authorization.

Only after the exact package has passed the required automated checks should the corrective release be published. Preserve v1.0.0 and v1.0.1, including their existing public bytes. The prior repair brief proposed v1.0.2 if unused: inspect live state and existing release authorization rather than silently choosing or overwriting a version. This no-testing amendment does not expand publishing authority. Keep the exact tested commit and artifact hashes in the release record. If an essential technical gate or required publication authority is missing, report that specific blocker without asking for human testing.

Verify the uploaded downloadable artifact against the tested SHA-256, not merely the tag/banner; download again and automatically smoke-test the actual package. Update final branch/main synchronization and report the real public release identity. No 'all done' claim for a ZIP, tag or draft alone. Include the actual automated coverage and any clearly bounded unverified behavior; do not invent a new manual acceptance gate.

## Handover after each step

State: what changed; exact automated Windows tests run and results; what has NOT been tested; files changed; local commit/live branch SHA; main integration status; any technical or authorization blocker; and the exact next prompt. State "Owner testing required: none." Then STOP. Keep this handover brief and factual. No requests for a test, screenshot, log collection or playback confirmation. No new roadmap, tracking framework or production dependency is required.

## Prior source references retained for Codex

- https://github.com/PikkuJanne/AudioFileForPhone/blob/v1.0.1/AudioFileForPhone.bat
- https://github.com/PikkuJanne/AudioFileForPhone/blob/main/Setup-AudioFileForPhone.bat
- https://github.com/PikkuJanne/AudioFileForPhone/blob/main/AudioFileForPhone.Launcher.ps1
- https://github.com/PikkuJanne/AudioFileForPhone/blob/v1.0.1/AudioFileForPhone.ps1
- https://api.github.com/repos/PikkuJanne/AudioFileForPhone/releases/latest
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies

This revision updates the earlier repair instructions from the owner's latest message; it is not a fresh repository review or a new runtime test. The owner has now reported working audio through the recovery BAT. Preserve that report accurately, but do not relabel it as independent verification of a later package. These instructions create no new application, Windows or Explorer pass claims.
