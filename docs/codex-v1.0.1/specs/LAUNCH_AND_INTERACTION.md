# Launcher and interaction

## Normal folder workflow

Preserve `AudioFileForPhone.bat` accepting exactly one folder. The default script
without -Interactive remains noninteractive and its existing parameters remain
usable. Dependency repair precedes metadata choices. After successful setup show:

    Ready: <N> supported files -> 64 kbps CBR MP3
    Enter = start with defaults | M = customize metadata | Q = cancel
    Waiting for your selection (no conversion has started).

Use the selected bitrate in the display. Enter advances immediately, retaining
existing source metadata behavior and dropping source artwork by the existing
policy. M exposes the cover/Artist/Album controls; explicit parameter values remain
respected. Q exits as cancellation without producing output. Explain return from
metadata customization; avoid new redundant confirmations. Do not auto-store batch
metadata across unrelated folders. Keep invalid entry feedback concise and never
treat pasted source code as a command. Handle EOF/noninteractive host/redirected
input explicitly rather than looping forever or silently starting a conversion.

Preflight, waiting, probing, encoding, validating and completed/failed/cancelled
states should be visibly distinct. A displayed 100% file encode is not final
publication; preserve accurate overall counts. Any no-files/dependency failure
must not display an ordinary ready prompt.

## Host selection

Preserve preference for a usable PowerShell 7 and fallback to Windows PowerShell 5.1
only BEFORE the application has started. Resolve and display full host path/version,
architecture and STA state. Do not hardcode a Store package version or require an
unnecessarily exact PowerShell patch. Include an explicit host choice via a small
supported launcher setting/alternate documented entry route. Do not redesign the
entire BAT as a fragile nested command-string evaluator.

A capability/health probe must be side-effect free, -NoProfile and bounded. Test
classic installer and Store execution aliases. Distinguish OS architecture from
host-process architecture; support x64 targets with appropriate host selection and
actionable failure for unsupported combinations. Do not invent working ARM/x86
claims. Startup health can probe available managed features but must not loosen
application-control policy. If a preferred host is blocked by explicit enterprise
policy, do not bypass that policy by selecting another host.

Never fallback after application entry, regardless of its nonzero exit: outputs
may already exist. Capture child exit immediately and preserve it across console
messages/pause. No unbounded mandatory pause with redirected input. Retain one
window for interactive errors and make ordinary double-click without an argument
provide useful instructions rather than vanish.

## Invocation safety

Use absolute script paths based on the launcher directory, full known host paths
and -File with arguments. Keep delayed expansion disabled in BAT where needed.
No Invoke-Expression or user-supplied evaluated command strings. Take account of
CMD metacharacters and caller expansion; do not promise recovery of text already
expanded before the launcher receives it. Test actual supplied argument spelling.
The existing process-scoped execution-policy request is not authorization to alter
user/machine policy or bypass AppLocker/WDAC/Group Policy. Keep a direct route which
respects policy checks. Missing helper/config/asset diagnostics should identify the
missing file before a confusing stack trace where possible.

## Regression cases

Zero/multiple arguments; folder with spaces, brackets, ampersand, apostrophe,
parentheses, exclamation and percent; Finnish/German and decomposed Unicode; trailing
separator; unrelated working directory; real desktop .lnk route; Store pwsh;
PS7 absent/broken/unlaunchable; forced host choice; startup timeout; all exit codes;
application exit 2 must not launch the other shell; Enter/M/Q; dialog cancel;
no console; redirected stdin; explicit metadata values; no prompts in dry-run or
noninteractive conversion. Assert source preservation and no unexpected processes.
