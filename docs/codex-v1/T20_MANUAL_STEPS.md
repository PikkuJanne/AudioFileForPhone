# T20 Windows manual continuation — NOT RUN

This procedure is not acceptance evidence. A49/A50 need named observations and
supporting measurements. Use an ordinary, non-elevated local Windows 11 console.
Record `Get-ExecutionPolicy -List`; an enforced restriction is a blocker. The
process-scoped `RemoteSigned` requests below do not override Group Policy.

## Prepare once, then use the returned paths

If a successfully prepared root has already been supplied, reuse it. Otherwise
run this command once; it retains a uniquely owned synthetic TEMP tree, marker
and local `preparation.json`, without running the application:

```powershell
$t20Pwsh = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
& $t20Pwsh -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File 'C:\projects\AudioFileForPhone-main\docs\codex-v1\tools\Prepare-T20Manual.ps1'
$LASTEXITCODE
```

Keep its concrete returned `root`/`report` paths privately; do not invent a root
or enumerate TEMP to find one. Load the completed report using that returned root:

```powershell
$t20SessionRoot = '<EXACT_ROOT_RETURNED_BY_PREPARATION>'
if ($t20SessionRoot.StartsWith('<')) { throw 'Use the exact successful returned root.' }
$t20Preparation = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $t20SessionRoot 'preparation.json') | ConvertFrom-Json
if ($t20Preparation.status -ne 'prepared' -or $t20Preparation.ownership.root -cne $t20SessionRoot) { throw 'Preparation is incomplete or names another root.' }
$t20Entry = Join-Path $t20Preparation.paths.application_directory 'AudioFileForPhone.ps1'
$t20Ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$t20Pwsh = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
```

The report supplies actual `special_input`, `mixed_input`, cover and
`output_parent` paths; the app copies match the candidate bytes. Preserve the
marker and report for later verification. Cleanup must verify exact ownership,
inventory and child release, rather than delete a guessed path.

## Physical Ctrl+C on both shells

Run each command from a genuine local console with unredirected input. Wait for
**READY** during the second encoder, physically press Ctrl+C once, and wait for
the final harness result. Record the actual keypress and result.

```powershell
& $t20Ps51 -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File 'C:\projects\AudioFileForPhone-main\tests\Test-Cancellation.ps1' -Manual -EvidencePath 'C:\projects\AudioFileForPhone-main\docs\codex-v1\evidence\T16-cancellation-ps51-manual20.json'
$LASTEXITCODE
& $t20Pwsh -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File 'C:\projects\AudioFileForPhone-main\tests\Test-Cancellation.ps1' -Manual -EvidencePath 'C:\projects\AudioFileForPhone-main\docs\codex-v1\evidence\T16-cancellation-ps7-manual20.json'
$LASTEXITCODE
```

These labels were unused at preparation. Preserve any existing report and choose
a fresh accepted `manualN` label for retries. Expected application cancellation is
130 with a preserved/decoded first output, removed current partial, unchanged
sources, restored console mode, surviving unrelated FFmpeg and verified cleanup.
The harness has its own final exit; its report contains the application exit.

Reports retain original `task: T16`, `acceptance_case: A29` and T11 messages. Do
not relabel them. T20 will bind actual commit/source/harness/report hashes,
timestamps and tester confirmation after inspection. A physical-mode flag alone
does not establish that the owner pressed the key.

## STA picker and metadata on both shells

Run the actual prepared special input with a controlled output parent. The PATH
change below affects only the current process and is restored after both runs:

```powershell
$t20PreviousPath = $env:PATH
try {
    $env:PATH = (Split-Path -Parent $t20Preparation.tools.ffmpeg.path) + ';' + (Split-Path -Parent $t20Preparation.tools.ffprobe.path) + ';' + $t20PreviousPath
    & $t20Ps51 -NoLogo -NoProfile -Sta -ExecutionPolicy RemoteSigned -File $t20Entry -InputFolder $t20Preparation.paths.special_input -OutputParent $t20Preparation.paths.output_parent -Interactive
    $LASTEXITCODE
    & $t20Pwsh -NoLogo -NoProfile -Sta -ExecutionPolicy RemoteSigned -File $t20Entry -InputFolder $t20Preparation.paths.special_input -OutputParent $t20Preparation.paths.output_parent -Interactive
    $LASTEXITCODE
} finally { $env:PATH = $t20PreviousPath }
```

In each shell choose Yes for cover, select `paths.valid_png_cover` or
`paths.valid_jpg_cover`, then enter agreed synthetic Artist/Album values. Record
picker opening, fixture ID, values and final result. Repeat the commands, choose
Yes for cover and **Cancel** the picker; record continuation without artwork.
Each application run reserves a separate root within the prepared output parent.
Independent checks must verify the actual returned output tags/art/layout/hashes.

## BAT, errors and default Music

Physically drag `paths.special_input` onto the unchanged BAT in
`paths.application_directory` in Explorer. Record prompts, picker interaction,
final message and actual shell/version. The BAT prefers resolved `pwsh`; an
Explorer drop selecting PS7 does not prove a PS5.1 BAT branch. A PS5.1 fallback
needs a separately documented process-local PATH excluding `pwsh` but retaining
Windows PowerShell/FFmpeg. Do not change global PATH or BAT bytes. Dragging a path
into a console command proves console argument entry, not folder-on-BAT Explorer
drop. Claim only physical branches actually observed.

BAT default output is Music. Prepare exact returned-root capture/ownership and
cleanup before that run. Inspect only its successful returned root, verify its
runtime token, CreateNew test marker and exact inventory, then remove only that
root after child release. Never browse ordinary Music. Existing automated
default-smoke checks remain separate from the named owner's observation.

Record actual results for zero/multiple BAT arguments, no-prompt direct CLI,
`paths.invalid_cover`, missing dependencies and `paths.mixed_input`. Link automated
exit/probe checks separately. Forced window close is distinct from Ctrl+C and
can leave FFmpeg/partials; attempt it only with a prepared containment controller
and retained owned handles. Never terminate processes by global name.

## Long source and owner report

Next owner action: provide a tester identity and one explicitly selected, legally
held local MP3/M4A/OGG podcast/audiobook over an hour, then run both Ctrl+C commands
and report their actual results. Supply the long file's exact local path privately;
do not send its source, raw filename, content or private logs to GitHub. No broad
personal-media scan is needed. Copy only that file unchanged into a fresh owned
input folder, verify original/copy hashes and use a controlled owned output parent.
Keep the original outside all output/cleanup scopes.

Run the unchanged candidate on that controlled long input with each shell and
record private ID, codec/channels/sample rate, source duration/hash, command/exit,
elapsed time, measured resource samples and output duration/hash/size. Independently
probe/decode the output and verify the source hash afterward. Synthetic hour-long
automated evidence is supplementary; phone playback/seek remains T21.

For each case report tester identity, actual UTC time, shell/version, fixture or
private ID, action performed, expected/observed result, visible message/error and
actual exit. Record Windows build/architecture, ordinary-user status, full candidate
commit and dependency version/origin/hash once. Link concrete output/report hashes
and source/cleanup proof after inspection. Unperformed cases remain `not_run` and
restrictions remain `blocked`; prepared commands never count as observations.
