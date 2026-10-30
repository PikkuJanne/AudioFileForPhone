<# Read-only CI checks and retained marker-owned synthetic integration. Dependency downloads are confined to Initialize-CiDependencies.ps1. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DependenciesPath,
    [Parameter(Mandatory = $true)][string]$RunLabel
)

$ErrorActionPreference = 'Stop'
# This job owns its console; child media drivers inherit UTF8 CP65001.
[Console]::InputEncoding = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')

function Assert-CiRunLabel {
    param([string]$Label)
    if ($Label -notmatch '^(attempt|final)[1-9][0-9]*$|^run[1-9][0-9]*_[1-9][0-9]*$') {
        throw 'Run label must be fresh attemptN/finalN or run<ID>_<attempt>, with positive integers and no filesystem metacharacters.'
    }
}
function Assert-CiNoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'CI paths cannot contain reparse ancestors.' }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Write-CiJson {
    param([string]$Path, [object]$Document)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ((Split-Path -Parent $fullPath) -ine $evidenceParent) { throw 'CI reports must stay directly in their approved parent.' }
    Assert-CiNoReparse $evidenceParent
    $stream = [IO.File]::Open($fullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = New-Object IO.StreamWriter($stream, [Text.Encoding]::UTF8)
        try { $writer.WriteLine(($Document | ConvertTo-Json -Depth 20)); $writer.Flush() } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}
function Get-CiSourceInventory {
    param([string[]]$Paths)
    return @($Paths | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Get-CiSetupFunction {
    param([string]$Name)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Initialize-CiDependencies.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw 'Dependency helper must parse before inert function extraction.' }
    $definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name }, $false))
    if ($definitions.Count -ne 1) { throw "Dependency helper must define exactly one $Name function." }
    return [scriptblock]::Create($definitions[0].Extent.Text)
}
function Assert-CiDependencyRecord {
    param([object]$Record, [object]$Lock)
    if ($Record.schema_version -ne 1 -or $Record.task -cne 'T17' -or $Record.status -cne 'pass' -or $Lock.schema_version -ne 1) {
        throw 'Dependency setup and lock require passing T17/schema1 contracts.'
    }
    foreach ($kind in @('ffmpeg', 'analyzer')) {
        foreach ($property in @('version', 'archive_url', 'archive_sha256')) {
            if ([string]$Record.$kind.$property -cne [string]$Lock.$kind.$property) { throw "Dependency $kind $property differs from checked-in lock." }
        }
        if ($Record.$kind.extraction.file_count -ne $Lock.$kind.archive_file_count -or
            $Record.$kind.extraction.inventory_sha256 -cne $Lock.$kind.inventory_sha256) { throw "Dependency $kind inventory differs from checked-in lock." }
    }
    if ($Record.ffmpeg.ffmpeg_sha256 -cne $Lock.ffmpeg.ffmpeg_sha256 -or $Record.ffmpeg.ffprobe_sha256 -cne $Lock.ffmpeg.ffprobe_sha256 -or
        $Record.analyzer.module_manifest_sha256 -cne $Lock.analyzer.module_manifest_sha256) { throw 'Dependency selected file hashes differ from checked-in lock.' }
}
function Assert-CiEncodingReport {
    param([object]$Record)
    if ($Record.schema_version -ne 1 -or $Record.task -cne 'S09' -or $Record.status -cne 'pass' -or
        $Record.mode -cne 'real_windows_encoding_compatibility') { throw 'Encoding matrix requires a passing actual S09/schema1 report.' }
    foreach ($flag in @('source_unchanged', 'synthetic_unchanged', 'descendant_release_proved', 'cleanup_verified',
        'copied_bytes_unchanged', 'parent_path_unchanged', 'temp_exclusively_reserved', 'marker_create_new')) {
        if ($Record.$flag -isnot [bool] -or -not $Record.$flag) { throw "Encoding matrix did not prove $flag." }
    }
    $matrix = @($Record.matrix); $apps = @($Record.app_runs)
    if ($matrix.Count -lt 495 -or $apps.Count -ne 4) { throw 'Encoding matrix requires at least495 planned conversions and exactly4 actual application groups.' }
    $rates = @(8,16,24,32,40,48,56,64,80,96,112,128,144,160,192,224,256,320)
    $sampleRates = @(8000,11025,12000,16000,22050,24000,32000,44100,48000)
    $identities = New-Object 'Collections.Generic.HashSet[string]'
    foreach ($row in $matrix) {
        if ([string]::IsNullOrWhiteSpace([string]$row.id) -or -not $identities.Add([string]$row.id) -or
            $row.status -cne 'pass' -or $row.full_decode -ne $true -or $rates -notcontains $row.requested_bitrate_kbps -or
            $sampleRates -notcontains $row.planned_sample_rate -or $row.planned_channels -notin @(1,2) -or
            $row.observed_bitrate_bps -ne ([long]$row.requested_bitrate_kbps * 1000) -or
            $row.observed_sample_rate -ne $row.planned_sample_rate -or $row.observed_channels -ne $row.planned_channels) {
            throw 'Every unique encoding matrix result must fully decode with the exact planned bitrate/sample-rate/channel shape.'
        }
    }
    if (@($matrix | Where-Object { $_.group -ceq 'required' }).Count -ne 252 -or
        @($matrix | Where-Object { $_.group -ceq 'extra' }).Count -ne 180 -or
        @($matrix | Where-Object { $_.group -ceq 'multichannel' }).Count -ne 36 -or
        @($matrix | Where-Object { $_.group -ceq 'codec' }).Count -ne 25 -or
        @($matrix | Where-Object { $_.group -ceq 'artwork' }).Count -ne 2) {
        throw 'Encoding matrix lost required, low/odd/high, multichannel, codec or artwork coverage.'
    }
    $appRates = @($apps | ForEach-Object { $_.rate } | Sort-Object)
    if (($appRates -join ',') -cne '8,64,144,192') { throw 'Encoding application groups must retain8/64/144/192 kbps coverage.' }
    foreach ($app in $apps) {
        if ($app.status -cne 'pass' -or $app.converted -lt 1 -or $app.manifest_audio_plans_verified -ne $true -or
            $app.observed_audio_verified -ne $true -or $app.full_decode -ne $true -or $app.PATH -cne 'empty' -or
            $app.config_created -ne $false) { throw 'Every actual encoding application group must prove conversion, manifest/audio-plan validation, full decode and isolated empty-PATH/config behavior.' }
    }
}
function Assert-CiSupportReport {
    param([object]$Record)
    if ($Record.schema_version -ne 1 -or $Record.task -cne 'S10' -or $Record.status -cne 'pass' -or
        $Record.mode -cne 'real_windows_environment_check_selftest_early_failure_and_support_export') { throw 'Support diagnostics requires a passing actual S10/schema1 report.' }
    foreach ($flag in @('source_unchanged', 'synthetic_unchanged', 'descendant_release_proved', 'cleanup_verified',
        'copied_bytes_unchanged', 'parent_path_unchanged', 'temp_exclusively_reserved', 'marker_create_new')) {
        if ($Record.$flag -isnot [bool] -or -not $Record.$flag) { throw "Support diagnostics did not prove $flag." }
    }
    foreach ($flag in @('ordinary_music_access', 'owner_media_access', 'user_config_read_or_written', 'persistent_environment_writes', 'automatic_uploads')) {
        if ($Record.$flag -isnot [bool] -or $Record.$flag) { throw "Support diagnostics violated $flag isolation." }
    }
    $cases = @($Record.cases)
    if ($cases.Count -lt 25 -or @($cases | Where-Object { $_.status -cne 'pass' }).Count -ne 0) { throw 'Support diagnostics requires every executed group to pass.' }
    foreach ($required in @('check-default-success-executes-selected-tools-without-writes',
        'explicit-synthetic-selftest-converts-validates-hashes-and-cleans',
        'both-startup-storage-locations-fail-with-original-cause-intact',
        'dryrun-invalid-input-and-missing-helper-fail-with-no-writes',
        'support-redaction-rejects-adversarial-free-text-and-unknown-properties',
        'private-startup-record-review-and-explicit-export-work-with-missing-converter-helper')) {
        if (@($cases | Where-Object { $_.name -ceq $required }).Count -ne 1) { throw 'Support diagnostics lost a required no-write, self-test, failure or privacy group.' }
    }
}

function Assert-CiCleanFirstReport {
    param([object]$Record)
    if ($Record.schema_version -ne 1 -or $Record.task -cne 'S12' -or $Record.status -cne 'pass' -or $Record.mode -cne 'real_windows_clean_first_run_fresh_process') { throw 'Clean first-run needs actual passing S12/schema1 report.' }
    foreach ($flag in @('source_unchanged','synthetic_unchanged','descendant_release_proved','cleanup_verified','copied_bytes_unchanged','parent_path_unchanged','temp_exclusively_reserved','marker_create_new','fixture_tools_used_by_absolute_path_only','child_environment_sanitized')) {
        if ($Record.$flag -isnot [bool] -or -not $Record.$flag) { throw "Clean first-run did not prove $flag." }
    }
    foreach ($flag in @('ordinary_music_access','owner_media_access','user_config_read_or_written','persistent_environment_writes','automatic_uploads')) {
        if ($Record.$flag -isnot [bool] -or $Record.$flag) { throw "Clean first-run violated $flag isolation." }
    }
    $cases = @($Record.cases)
    if ($cases.Count -ne 7 -or $Record.fresh_process_count -ne 7 -or @($cases | Where-Object { $_.status -cne 'pass' -or $_.fresh_process -ne $true }).Count -ne 0) { throw 'Clean first-run requires seven fresh passing production process cases.' }
    foreach ($label in @('empty','stale','malformed')) {
        $rows = @($cases | Where-Object { $_.name -ceq ('fresh-no-tools-'+$label+'-PATH-refuses-with-repair') })
        if ($rows.Count -ne 1 -or $rows[0].PATH -cne $label -or $rows[0].exit_code -ne 1 -or $rows[0].config_initially_absent -ne $true -or $rows[0].app_local_pair_absent -ne $true -or $rows[0].output_absent -ne $true) { throw 'Clean first-run lost no-tool PATH/config refusal evidence.' }
    }
    foreach ($origin in @('Explicit','Saved','AppLocal')) {
        $rows = @($cases | Where-Object { $_.conversion.selection_origin -ceq $origin })
        if ($rows.Count -ne 1 -or $rows[0].conversion.converted -ne 1 -or $rows[0].conversion.bitrate_kbps -ne 64 -or $rows[0].conversion.independently_probed -ne $true -or $rows[0].conversion.full_decode -ne $true) { throw 'Clean first-run lost independently verified production conversion.' }
        if ($origin -ceq 'Saved') {
            if ($rows[0].config_unchanged -ne $true -or $rows[0].PATH -cne 'empty') { throw 'Clean first-run saved process lost config integrity or empty PATH.' }
        } elseif ($rows[0].config_created -isnot [bool] -or $rows[0].config_created -or $rows[0].PATH -cne $(if ($origin -ceq 'AppLocal') { 'malformed' } else { 'empty' })) { throw 'Clean first-run explicit/app-local process changed config or PATH isolation.' }
    }
    if (@($cases | Where-Object { $_.production_saved_selection -eq $true -and $_.exit_code -eq 0 -and $_.PATH -ceq 'empty' }).Count -ne 1) { throw 'Clean first-run lost deliberately saved production setup.' }
}
function Assert-CiDirectLauncherReport {
    param([object]$Record)
    if ($Record.schema_version -ne 1 -or $Record.task -cne 'R1' -or $Record.status -cne 'pass' -or
        $Record.mode -cne 'native_console_direct_bat') { throw 'Direct launcher requires a passing actual R1/schema1 native-console report.' }
    foreach ($flag in @('source_unchanged', 'cleanup_verified', 'descendant_release_proved', 'parent_path_unchanged', 'parent_module_path_unchanged', 'policies_unchanged')) {
        if ($Record.$flag -isnot [bool] -or -not $Record.$flag) { throw "Direct launcher did not prove $flag." }
    }
    $before = @($Record.source_before); $after = @($Record.source_after)
    if (($before | ConvertTo-Json -Compress) -cne ($after | ConvertTo-Json -Compress)) { throw 'Direct launcher source inventories differ.' }
    foreach ($path in @('AudioFileForPhone.bat', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ps1',
        'Setup-AudioFileForPhone.ps1', 'tests/Test-DirectLauncher.ps1', 'tests/DirectLauncher.Console.cs')) {
        $identities = @($before | Where-Object { $_.path -ceq $path })
        if ($identities.Count -ne 1 -or [string]$identities[0].sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Direct launcher lost an exact source identity.' }
    }
    $cases = @($Record.cases)
    if ($cases.Count -lt 39 -or @($cases | Where-Object { $_.status -cne 'pass' }).Count -ne 0) { throw 'Direct launcher requires all actual native-console cases to pass.' }
    foreach ($case in $cases) {
        foreach ($flag in @('pause_seen', 'still_waiting_before_key', 'key_injected', 'owned_tree_released')) {
            if ($case.native.$flag -isnot [bool] -or -not $case.native.$flag) { throw "Direct launcher case lost $flag evidence." }
        }
        if ($null -eq $case.expected_exit -or $null -eq $case.native.exit_code -or $case.native.exit_code -ne $case.expected_exit) { throw 'Direct launcher case lost the expected native exit code.' }
        if ($case.parent_path_unchanged -isnot [bool] -or -not $case.parent_path_unchanged) { throw 'Direct launcher case changed the parent PATH.' }
        if ($case.parent_module_path_unchanged -isnot [bool] -or -not $case.parent_module_path_unchanged) { throw 'Direct launcher case changed the parent PSModulePath.' }
    }
    $required = @('exit-0', 'exit-1', 'exit-2', 'exit-130', 'exit-37', 'trailing-separator', 'application-location',
        'converter-missing-runtime', 'converter-missing-host', 'converter-parse-error', 'converter-real-missing-helper',
        'setup-missing-runtime', 'setup-missing-host', 'setup-parse-error', 'setup-real-missing-helper',
        'setup-exit-0', 'setup-exit-1', 'setup-exit-130', 'setup-extra', 'setup-empty', 'converter-policy-denial', 'setup-policy-denial',
        'converter-remotesigned-internet-denial', 'setup-remotesigned-internet-denial', 'contaminated-parent-modules')
    $required += @(0..7 | ForEach-Object { 'input-' + $_ })
    $required += @(0..5 | ForEach-Object { 'invalid-' + $_ })
    foreach ($name in $required) {
        if (@($cases | Where-Object { $_.name -ceq $name }).Count -ne 1) { throw 'Direct launcher lost required launch, argument, result or refusal coverage.' }
    }
}
function Invoke-CiHarness {
    param([string]$RelativePath, [string]$Family, [switch]$RealMedia)
    $path = Join-Path $projectRoot $RelativePath
    # Keep historical suites/report paths intact; R1 gates the current direct BAT.
    $activeFamilies = @{ directlauncher='R1'; launcher='S08'; 'encoding-ci'='S09'; support='S10'; managedreal='S06'; corpus='S11'; filesystem='S11'; cleanfirst='S12'; releasegates='S12' }
    $childTask = if ($activeFamilies.ContainsKey($Family)) { $activeFamilies[$Family] } else { 'T17' }
    $childParent = if ($activeFamilies.ContainsKey($Family)) { Join-Path $projectRoot 'docs/codex-v1.0.1/evidence' } else { $evidenceParent }
    $evidence = Join-Path $childParent ("$childTask-$Family-$edition-$RunLabel.json")
    if (Test-Path -LiteralPath $evidence) { throw "Existing $Family report cannot be replaced." }
    $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', $path, '-EvidencePath', $evidence)
    if ($Family -ceq 'directlauncher') { $arguments += @('-Task', $childTask, '-RunLabel', $RunLabel) }
    if ($RealMedia) { $arguments += @('-FfmpegPath', $dependencies.ffmpeg_path, '-FfprobePath', $dependencies.ffprobe_path) }
    & $shellPath @arguments
    $childExit = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $evidence -PathType Leaf)) { throw "$Family did not produce its exclusive report (exit $childExit)." }
    Assert-CiNoReparse $evidence
    $child = Get-Content -LiteralPath $evidence -Raw -Encoding UTF8 | ConvertFrom-Json
    $row = [ordered]@{
        family = $Family; harness = $RelativePath; command_arguments = $arguments
        report = Split-Path -Leaf $evidence; report_sha256 = (Get-FileHash -LiteralPath $evidence -Algorithm SHA256).Hash.ToLowerInvariant()
        exit_code = $childExit; status = $child.status; required_checks = $null; observations = $null
    }
    $resultRow = [pscustomobject]$row
    $report.tests += $resultRow
    if ($childExit -ne 0 -or $child.status -cne 'pass' -or $child.source_unchanged -ne $true -or
        $child.task -cne $childTask -or $child.tested_commit -cne $report.tested_commit -or $child.shell -cne $report.shell) {
        throw "$Family requires exit zero, pass status and unchanged source bytes."
    }
    if (($RealMedia -or $Family -in @('ci-dependencyguards', 'package', 'launcher', 'directlauncher', 'managedreal')) -and $child.cleanup_verified -ne $true) { throw "$Family did not prove exact owned fixture cleanup." }
    if ($Family -ceq 'baseline') {
        if ($child.mode -cne 'real_ffmpeg_baseline' -or $child.legacy.exit_code -ne 0 -or $child.legacy.status -cne 'pass' -or
            $child.characterization.status -cne 'pass' -or $child.isolation.verified -ne $true -or $child.isolation.copied_bytes_unchanged -ne $true) {
            throw 'Retained baseline must execute real media and both legacy and characterization suites in owned isolation.'
        }
        $resultRow.required_checks = @($child.characterization.checks | Where-Object { $_.required }).Count
        $resultRow.observations = @($child.characterization.checks | Where-Object { -not $_.required }).Count
        if (@($child.characterization.checks | Where-Object { $_.required -and $_.status -cne 'pass' }).Count -ne 0) { throw 'A required baseline check failed.' }
    } else {
        $resultRow.required_checks = @($child.cases).Count
        if ($resultRow.required_checks -lt 1 -or @($child.cases | Where-Object { $_.status -cne 'pass' }).Count -ne 0) { throw "$Family must contain passing actual cases." }
        if ($Family -in @('native', 'help', 'shortoperations', 'toolselection', 'firstrunsetup', 'metadatainteraction', 'support', 'managedreal', 'corpus', 'filesystem', 'cleanfirst') -and ($child.synthetic_unchanged -ne $true -or $child.descendant_release_proved -ne $true)) {
            throw 'Media suites must preserve fixture bytes and prove every descendant release before cleanup.'
        }
        if ($Family -ceq 'encoding-ci') {
            Assert-CiEncodingReport -Record $child
            $resultRow.required_checks += @($child.matrix).Count + @($child.app_runs).Count
        }
        if ($Family -ceq 'support') { Assert-CiSupportReport -Record $child }
        if ($Family -ceq 'cleanfirst') { Assert-CiCleanFirstReport -Record $child }
        if ($Family -ceq 'directlauncher') { Assert-CiDirectLauncherReport -Record $child }
        if ($Family -ceq 'corpus') {
            if ($child.mode -cne 'real_windows_complementary_short_irregular_codec_corpus' -or @($child.matrix).Count -ne 10 -or
                @($child.matrix | Where-Object { $_.status -cne 'pass' -or $_.full_decode -ne $true -or $_.observed_bitrate_bps -ne ([long]$_.requested_bitrate_kbps * 1000) -or $_.observed_sample_rate -ne $_.planned_sample_rate -or $_.observed_channels -ne $_.planned_channels }).Count -ne 0) { throw 'Complementary corpus lost exact planned real conversion/decode evidence.' }
            $resultRow.required_checks += @($child.matrix).Count
        }
        if ($Family -ceq 'filesystem' -and ($child.acls_restored -isnot [bool] -or -not $child.acls_restored)) { throw 'Filesystem campaign did not restore actual owned ACLs.' }
        if ($Family -ceq 'managedreal' -and ($child.mode -cne 'real_windows_pinned_vendor_network' -or $child.mocked_network -ne $false -or @($child.cases).Count -ne 3)) { throw 'Online installer requires three actual pinned vendor setup cases.' }
    }
}

Assert-CiRunLabel $RunLabel
$reportPath = Join-Path $evidenceParent ("T17-ci-$edition-$RunLabel.json")
if (Test-Path -LiteralPath $reportPath) { throw 'CI report already exists; select a fresh label.' }
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$ciOperatingSystem = Get-CimInstance Win32_OperatingSystem
$ciWindowsRegistry = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'T17'; mode = 'syntax_analysis_unit_real_ffmpeg'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString()
    windows_caption = $ciOperatingSystem.Caption; windows_product_type = [int]$ciOperatingSystem.ProductType
    windows_build = $ciWindowsRegistry.CurrentBuildNumber + '.' + $ciWindowsRegistry.UBR
    windows_display_version = $ciWindowsRegistry.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    acceptance_class = $(if ($env:GITHUB_ACTIONS -ceq 'true') { 'supplementary_windows_server_ci' } elseif ($ciOperatingSystem.ProductType -eq 1) { 'windows_client_local' } else { 'supplementary_windows_server_local' })
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    github_sha = $env:GITHUB_SHA; github_event = $env:GITHUB_EVENT_NAME; github_run_id = $env:GITHUB_RUN_ID; github_run_attempt = $env:GITHUB_RUN_ATTEMPT
    github_ref = $env:GITHUB_REF; github_head_ref = $env:GITHUB_HEAD_REF; github_base_ref = $env:GITHUB_BASE_REF
    runner_os = $env:RUNNER_OS; runner_arch = $env:RUNNER_ARCH; runner_image = $env:ImageOS; runner_image_version = $env:ImageVersion
    execution_environment = $(if ($env:GITHUB_ACTIONS -ceq 'true') { 'github_hosted_windows' } else { 'local_windows' })
    dependency_report = $null; dependency_report_sha256 = $null
    dependencies_rechecked_against_lock = $false; checkout_matches_github_sha = $null
    source_before = @(); source_after = @(); source_unchanged = $false
    syntax = @(); analysis = [ordered]@{ status = 'not_run'; rules = @(); files = @(); diagnostics = @(); all_default_errors_gated = $true; analyzer_version = $null }
    tests = @(); required_checks = $null; observations = $null; status = 'fail'; error = $null
}
$exitCode = 1
$sourcePaths = @()
try {
    Assert-CiNoReparse $projectRoot
    if ($env:GITHUB_ACTIONS -ceq 'true') {
        $report.checkout_matches_github_sha = ($report.tested_commit -cmatch '^[a-f0-9]{40}$' -and $report.tested_commit -ceq $env:GITHUB_SHA)
        if (-not $report.checkout_matches_github_sha) { throw 'Actual checked-out HEAD must equal the exact GitHub event SHA.' }
    }
    $dependencyFullPath = [IO.Path]::GetFullPath($DependenciesPath)
    if ((Split-Path -Parent $dependencyFullPath) -ine $evidenceParent -or
        (Split-Path -Leaf $dependencyFullPath) -cne "T17-dependencies-$edition-$RunLabel.json") { throw 'DependenciesPath must name this shell and fresh label in the approved evidence parent.' }
    Assert-CiNoReparse $dependencyFullPath
    $dependencies = Get-Content -LiteralPath $dependencyFullPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $report.dependency_report = Split-Path -Leaf $dependencyFullPath
    $report.dependency_report_sha256 = (Get-FileHash -LiteralPath $dependencyFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $lock = Get-Content -LiteralPath (Join-Path $projectRoot '.github/dependencies.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-CiDependencyRecord -Record $dependencies -Lock $lock
    $dependencyRoot = [IO.Path]::GetFullPath([string]$dependencies.root).TrimEnd('\', '/')
    $permittedParents = @([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/'))
    if (-not [string]::IsNullOrEmpty($env:RUNNER_TEMP)) { $permittedParents += [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\', '/') }
    if ($permittedParents -notcontains [IO.Path]::GetDirectoryName($dependencyRoot) -or
        [IO.Path]::GetFileName($dependencyRoot) -cnotmatch '^AFP-CI-[a-f0-9]{32}$' -or $dependencies.owner_token -cnotmatch '^[a-f0-9]{32}$') {
        throw 'Dependencies require the exact marked direct TEMP/RUNNER_TEMP scope.'
    }
    Assert-CiNoReparse $dependencyRoot
    $markerPath = Join-Path $dependencyRoot '.afp-ci-owner'
    Assert-CiNoReparse $markerPath
    if ([IO.File]::ReadAllText($markerPath) -cne $dependencies.owner_token -or
        (Get-FileHash -LiteralPath $markerPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $dependencies.ownership_marker_sha256) { throw 'Dependency owner marker/token changed.' }
    if ([IO.Path]::GetFullPath($dependencies.manifest_path) -ine [IO.Path]::GetFullPath((Join-Path $projectRoot '.github/dependencies.json')) -or
        (Get-FileHash -LiteralPath $dependencies.manifest_path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $dependencies.manifest_sha256 -or
        [IO.Path]::GetFullPath($dependencies.setup_path) -ine [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Initialize-CiDependencies.ps1')) -or
        (Get-FileHash -LiteralPath $dependencies.setup_path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $dependencies.setup_sha256) {
        throw 'Provisioning lock/helper bytes changed since their recorded setup.'
    }
    foreach ($property in @('ffmpeg_path', 'ffprobe_path', 'analyzer_module_path')) {
        $toolPath = [string]$dependencies.$property
        if (-not [IO.Path]::IsPathRooted($toolPath) -or -not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw "Missing explicit verified dependency: $property." }
        Assert-CiNoReparse $toolPath
    }
    if ((Get-FileHash -LiteralPath $dependencies.ffmpeg_path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $lock.ffmpeg.ffmpeg_sha256 -or
        (Get-FileHash -LiteralPath $dependencies.ffprobe_path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $lock.ffmpeg.ffprobe_sha256 -or
        (Get-FileHash -LiteralPath $dependencies.analyzer_module_path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $lock.analyzer.module_manifest_sha256) {
        throw 'Provisioned dependency fingerprints changed before checks.'
    }
    . (Get-CiSetupFunction 'Get-CiSha256')
    . (Get-CiSetupFunction 'Get-CiDependencyInventory')
    . (Get-CiSetupFunction 'Get-CiInventoryDigest')
    foreach ($kind in @('ffmpeg', 'analyzer')) {
        $extractionName = if ($kind -ceq 'analyzer') { 'PSScriptAnalyzer' } else { 'ffmpeg' }
        $extractionRoot = Join-Path $dependencyRoot $extractionName
        Assert-CiNoReparse $extractionRoot
        $inventory = @(Get-CiDependencyInventory -Root $extractionRoot)
        if ($inventory.Count -ne $lock.$kind.archive_file_count -or (Get-CiInventoryDigest -Inventory $inventory) -cne $lock.$kind.inventory_sha256) {
            throw "Actual extracted $kind bytes or file set changed before execution/import."
        }
    }
    if ([IO.Path]::GetFullPath($dependencies.ffmpeg_path) -ine [IO.Path]::GetFullPath((Join-Path (Join-Path $dependencies.root 'ffmpeg') $lock.ffmpeg.ffmpeg_member)) -or
        [IO.Path]::GetFullPath($dependencies.ffprobe_path) -ine [IO.Path]::GetFullPath((Join-Path (Join-Path $dependencies.root 'ffmpeg') $lock.ffmpeg.ffprobe_member)) -or
        [IO.Path]::GetFullPath($dependencies.analyzer_module_path) -ine [IO.Path]::GetFullPath((Join-Path (Join-Path $dependencyRoot 'PSScriptAnalyzer') $lock.analyzer.module_member))) {
        throw 'Selected executables/module must be the pinned extracted members.'
    }
    $report.dependencies_rechecked_against_lock = $true
    $allPaths = @(& git -C $projectRoot ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate reviewed repository sources.' }
    $sourcePaths = @($allPaths | Where-Object { $_ -match '\.(ps1|psd1)$' -and ($_ -notmatch '/' -or $_ -match '^(tests/|tools/|\.github/scripts/|docs/codex-v1/tools/)') } | Sort-Object -Unique)
    $sourcePaths += @('.github/workflows/windows-ci.yml', '.github/dependencies.json', 'tools/package-files.json', 'tools/ffmpeg-download.json')
    $sourcePaths = @($sourcePaths | Sort-Object -Unique)
    $report.source_before = Get-CiSourceInventory $sourcePaths
    foreach ($relative in @($sourcePaths | Where-Object { $_ -match '\.(ps1|psd1)$' })) {
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot $relative), [ref]$tokens, [ref]$errors) | Out-Null
        $report.syntax += [pscustomobject]@{ path = $relative; errors = @($errors | ForEach-Object { [pscustomobject]@{ line = $_.Extent.StartLineNumber; message = $_.Message } }) }
        if ($errors.Count -ne 0) { throw "Syntax errors in $relative under this supported shell." }
    }
    Import-Module -Name $dependencies.analyzer_module_path -Force -ErrorAction Stop
    $analyzer = @(Get-Module -Name PSScriptAnalyzer)
    if ($analyzer.Count -ne 1 -or $analyzer[0].Version.ToString() -cne $lock.analyzer.version -or
        [IO.Path]::GetFullPath($analyzer[0].ModuleBase) -ine [IO.Path]::GetFullPath((Split-Path -Parent $dependencies.analyzer_module_path))) {
        throw 'Exact pinned analyzer module/version must be loaded from the verified extraction.'
    }
    $report.analysis.analyzer_version = $analyzer[0].Version.ToString()
    $analysisFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.ManagedSetup.ps1', 'Setup-AudioFileForPhone.ps1') + @($sourcePaths | Where-Object { $_ -match '^\.github/scripts/.*\.ps1$|^tests/ci/.*\.ps1$|^tools/.*\.ps1$|^tests/Test-Package\.ps1$' })
    $analysisFiles += @('AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1')
    $analysisFiles += @('AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.Checks.ps1', 'Check-AudioFileForPhone.ps1', 'tests/Test-SupportDiagnostics.ps1')
    $analysisFiles += @('tests/Test-CleanFirstRun.ps1', 'tests/Test-CompatibilityCorpus.ps1', 'tests/Test-CompatibilityFilesystem.ps1', 'tests/Test-ManagedSetupReal.ps1')
    $settingsPath = Join-Path $projectRoot '.github/scripts/PSScriptAnalyzerSettings.psd1'
    $settings = Import-PowerShellDataFile -LiteralPath $settingsPath
    $report.analysis.rules = @($settings.IncludeRules); $report.analysis.files = $analysisFiles
    $availableRules = @(Get-ScriptAnalyzerRule | Select-Object -ExpandProperty RuleName)
    foreach ($rule in $settings.IncludeRules) { if ($availableRules -notcontains $rule) { throw "Pinned analyzer does not provide configured rule $rule." } }
    foreach ($relative in $analysisFiles) {
        # Gate every default Error as well as all diagnostics from the explicit correctness/security rules.
        $messages = @(Invoke-ScriptAnalyzer -Path (Join-Path $projectRoot $relative) -Severity Error -ErrorAction Stop) +
            @(Invoke-ScriptAnalyzer -Path (Join-Path $projectRoot $relative) -Settings $settingsPath -ErrorAction Stop)
        $report.analysis.diagnostics += @($messages | ForEach-Object {
            [pscustomobject]@{ path = $relative; line = $_.Line; rule = $_.RuleName; severity = [string]$_.Severity; message = $_.Message }
        })
    }
    if (@($report.analysis.diagnostics).Count -ne 0) { throw 'Configured correctness/security analysis reported a diagnostic.' }
    $report.analysis.status = 'pass'
    Invoke-CiHarness -RelativePath 'tests/ci/Test-CiContracts.ps1' -Family 'unit'
    Invoke-CiHarness -RelativePath 'tests/ci/Test-CiDependencies.ps1' -Family 'ci-dependencyguards'
    Invoke-CiHarness -RelativePath 'tests/ci/Test-ReleaseGates.ps1' -Family 'releasegates'
    Invoke-CiHarness -RelativePath 'tests/Test-CleanFirstRun.ps1' -Family 'cleanfirst' -RealMedia
    # Legacy host-selection suites remain optional development evidence in Git.
    Invoke-CiHarness -RelativePath 'tests/Test-DirectLauncher.ps1' -Family 'directlauncher'
    # Package tests inspect the verified external tool identity; they do not convert media.
    Invoke-CiHarness -RelativePath 'tests/Test-Package.ps1' -Family 'package' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Invoke-IsolatedBaseline.ps1' -Family 'baseline' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-HelpVersion.ps1' -Family 'help' -RealMedia
    # Retained original leads now require corrected exact-rate output.
    Invoke-CiHarness -RelativePath 'tests/Test-SetupEncodingRegressions.ps1' -Family 'setupencoding' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-EncodingCompatibility.ps1' -Family 'encoding-ci' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-ShortOperations.ps1' -Family 'shortoperations' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-ToolSelection.ps1' -Family 'toolselection' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-FirstRunSetup.ps1' -Family 'firstrunsetup' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-MetadataInteraction.ps1' -Family 'metadatainteraction' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-ManagedSetup.ps1' -Family 'managedsetup' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-SupportDiagnostics.ps1' -Family 'support' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-CompatibilityCorpus.ps1' -Family 'corpus' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-CompatibilityFilesystem.ps1' -Family 'filesystem' -RealMedia
    Invoke-CiHarness -RelativePath 'tests/Test-ManagedSetupReal.ps1' -Family 'managedreal'
    # Last and sequential: the retained resource-handle check has an unchanged quiet allowance.
    Invoke-CiHarness -RelativePath 'tests/Test-NativeProcess.ps1' -Family 'native' -RealMedia
    $report.required_checks = [int](($report.tests | Measure-Object -Property required_checks -Sum).Sum)
    $report.observations = [int](($report.tests | Measure-Object -Property observations -Sum).Sum)
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message }
finally {
    if ($sourcePaths.Count -gt 0 -and $report.source_before.Count -gt 0) {
        $report.source_after = Get-CiSourceInventory $sourcePaths
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        if (-not $report.source_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    }
    $report.completed_utc = [DateTime]::UtcNow.ToString('o')
    Write-CiJson $reportPath $report
}
Write-Host "T17 CI checks: $($report.status); shell=$edition; tests=$($report.tests.Count); source bytes unchanged=$($report.source_unchanged)"
if ($report.error) { Write-Host $report.error }
exit $exitCode
