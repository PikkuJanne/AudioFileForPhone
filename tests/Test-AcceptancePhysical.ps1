<# S13 synthetic correlation contracts. No Music, Explorer, phone or media execution.
The watcher observes only owned temporary directories; answers and media checks
are injected locally. A synthetic PASSED result is never client/human acceptance. #>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
. (Join-Path $project 'tools/acceptance/Acceptance.Common.ps1')
. (Join-Path $project 'tools/acceptance/Acceptance.Physical.ps1')
$evidence = Assert-AcceptanceLocalPath $EvidencePath
$null = Assert-AcceptanceLocalPath ([IO.Path]::GetDirectoryName($evidence)) -MustExist
if (Test-Path -LiteralPath $evidence) { throw 'Evidence already exists.' }
$temporaryParent = Assert-AcceptanceLocalPath ([IO.Path]::GetTempPath()).TrimEnd('\', '/') -MustExist
$root = Join-Path $temporaryParent ('S13Phys-' + [guid]::NewGuid().ToString('N'))
$token = [guid]::NewGuid().ToString('N')
$markerPath = Join-Path $root '.owner'
$directories = New-Object 'Collections.Generic.List[string]'
$files = New-Object 'Collections.Generic.List[string]'
$contexts = New-Object 'Collections.Generic.List[object]'
$cases = New-Object 'Collections.Generic.List[object]'
$script:contractAnswer = ''; $script:contractValidationFailure = $false; $script:contractValidationCalls = 0
$created = $false; $failure = $null
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$operatingSystem = Get-CimInstance Win32_OperatingSystem
$report = [ordered]@{
    schema_version = 1; task = 'S13'; mode = 'synthetic_physical_correlation_contracts'; status = 'FAILED'
    started_utc = [DateTimeOffset]::UtcNow.ToString('o'); ended_utc = $null
    shell_version = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    command = [Environment]::CommandLine; tested_commit = (& git -C $project rev-parse HEAD | Out-String).Trim()
    os_caption = $operatingSystem.Caption; product_type = [int]$operatingSystem.ProductType
    build = [string]$windows.CurrentBuildNumber + '.' + [string]$windows.UBR; display_version = [string]$windows.DisplayVersion
    architecture = [string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture; process_64bit = [Environment]::Is64BitProcess
    ordinary_music_access = $false; explorer_opened = $false; actual_human_observation = $false
    media_verification = 'injected contract stub'; release_acceptance = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    temp_exclusively_reserved = $false; watcher_cleanup_verified = $false; cleanup_verified = $false
    cases = @(); error = $null
}

function Assert-Contract { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function New-ContractDirectory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { throw 'Contract directory collision.' }
    $null = [IO.Directory]::CreateDirectory($Path); $directories.Add($Path); return $Path
}
function Write-ContractJson {
    param([string]$Path, [object]$Value)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($Value | ConvertTo-Json -Depth 10)); $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
    $files.Add($Path)
}
function New-ContractContext {
    $observed = New-ContractDirectory (Join-Path $root ([guid]::NewGuid().ToString('N')))
    $eventToken = [guid]::NewGuid().ToString('N')
    $watcher = New-Object IO.FileSystemWatcher
    $watcher.Path = $observed; $watcher.Filter = 'AudioForPhone_64kbps_*'
    $watcher.NotifyFilter = [IO.NotifyFilters]::DirectoryName; $watcher.IncludeSubdirectories = $false
    $context = [pscustomobject]@{
        runtime_directory = $root; source_directory = $root; music_directory = $observed
        entry_sha256 = ('a' * 64); helper_sha256 = ('b' * 64)
        started_utc = [DateTimeOffset]::UtcNow; ended_utc = $null
        created_event_id = 'AFP.S13.Test.Created.' + $eventToken; error_event_id = 'AFP.S13.Test.Error.' + $eventToken
        watcher = $watcher; closed = $false; captured_paths = @(); candidate_errors = @()
    }
    $null = Register-ObjectEvent $watcher Created -SourceIdentifier $context.created_event_id
    $null = Register-ObjectEvent $watcher Error -SourceIdentifier $context.error_event_id
    $watcher.EnableRaisingEvents = $true; $contexts.Add($context); return $context
}
function New-ContractRun {
    param([object]$Context, [int]$Counter = 1, [string]$Mutation = '')
    $leaf = 'AudioForPhone_64kbps_20261029_010101' + $(if ($Counter -gt 1) { '_' + $Counter } else { '' })
    $run = New-ContractDirectory (Join-Path $Context.music_directory $leaf)
    $start = [DateTimeOffset]::UtcNow
    if ($Mutation -ceq 'old-time') { $start = $Context.started_utc.AddSeconds(-1) }
    $manifest = [ordered]@{
        schema_version = 1; kind = 'AudioFileForPhone.RunManifest'
        run = @{ input_root = $Context.source_directory; output_root = $run; started_utc = $start.ToString('o') }
        build = @{ entry_sha256 = $Context.entry_sha256; helper_sha256 = $Context.helper_sha256 }
    }
    if ($Mutation -ceq 'wrong-source') { $manifest.run.input_root = $Context.music_directory }
    if ($Mutation -ceq 'wrong-build') { $manifest.build.helper_sha256 = ('c' * 64) }
    Write-ContractJson (Join-Path $run 'AudioFileForPhone_manifest.json') $manifest
    $marker = [ordered]@{
        schema_version = 1; kind = 'AudioFileForPhone.Output'; output_root = $run
        cleanup_scope = $run; ownership_token = ('d' * 32)
    }
    if ($Mutation -ceq 'bad-marker') { $marker.ownership_token = 'invalid' }
    Write-ContractJson (Join-Path $run '.AudioFileForPhone-output.json') $marker
    $null = Wait-Event -SourceIdentifier $Context.created_event_id -Timeout 5
    Assert-Contract (@(Get-Event -SourceIdentifier $Context.created_event_id -ErrorAction SilentlyContinue).Count -gt 0) 'Owned real watcher did not deliver the synthetic directory event.'
    return $run
}
function Invoke-ContractCompletion {
    param([object]$Context, [string]$Answer)
    $script:contractAnswer = $Answer
    return Complete-AcceptancePhysical -Context $Context -SourceBefore @([pscustomobject]@{ relative_path = 'contract.mp3' }) -FfmpegPath 'unused-contract-ffmpeg' -FfprobePath 'unused-contract-ffprobe'
}
# These shadows live only in this isolated test script scope, never global scope.
function Read-Host { param([string]$Prompt); return $script:contractAnswer }
function Test-AcceptanceConversion {
    param([string]$RunDirectory, [string]$SourceRoot, [object[]]$SourceBefore,
          [string]$RuntimeDirectory, [string]$FfmpegPath, [string]$FfprobePath,
          [AllowNull()][Nullable[int]]$CapturedExitCode)
    $script:contractValidationCalls++
    Assert-Contract (-not $PSBoundParameters.ContainsKey('CapturedExitCode')) 'Physical media validation must not invent a captured raw exit.'
    if ($script:contractValidationFailure) { throw 'Injected media verification refusal.' }
    return [pscustomobject]@{ injected_contract_result = $true; captured_exit_code = $null; run_id = Get-AcceptanceHash (Join-Path $RunDirectory 'AudioFileForPhone_manifest.json') }
}

try {
    foreach ($path in @('tools/acceptance/Acceptance.Common.ps1', 'tools/acceptance/Acceptance.Physical.ps1', 'tests/Test-AcceptancePhysical.ps1')) {
        $report.source_before += [pscustomobject]@{ path = $path; sha256 = Get-AcceptanceHash (Join-Path $project $path) }
    }
    if (-not ('AudioFileForPhone.S13PhysicalDirectory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhone { public static class S13PhysicalDirectory {
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
 [return: MarshalAs(UnmanagedType.Bool)] public static extern bool CreateDirectoryW(string path, IntPtr attributes);
} }
'@
    }
    Assert-Contract ([AudioFileForPhone.S13PhysicalDirectory]::CreateDirectoryW($root, [IntPtr]::Zero)) 'Owned contract root could not be exclusively reserved.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-ContractJson $markerPath @{ token = $token }
    $refusedPercentPath = $false
    try { Assert-AcceptancePhysicalSpelling (Join-Path $root 'literal %TEMP% folder') } catch { $refusedPercentPath = $_.Exception.Message.StartsWith('PHYSICAL_LITERAL_PATH_UNSUPPORTED:') }
    Assert-Contract $refusedPercentPath 'Direct BAT shortcuts must refuse percent expansion before opening Music or Explorer.'
    $cases.Add([pscustomobject]@{ id = 'literal-percent-shortcut-refusal'; expected = 'refused before physical initialization'; observed = 'PHYSICAL_LITERAL_PATH_UNSUPPORTED'; status = 'PASSED' })
    foreach ($answer in @('', 'no', 'maybe')) {
        $context = New-ContractContext; $result = Invoke-ContractCompletion $context $answer
        $expected = if ($answer -ceq '') { 'NOT_TESTED' } elseif ($answer -ceq 'no') { 'FAILED' } else { 'BLOCKED' }
        Assert-Contract ($result.status -ceq $expected -and $context.closed -and $null -eq $result.captured_exit_code -and -not $result.raw_exit_captured -and -not [string]::IsNullOrWhiteSpace($result.ended_utc)) 'Unperformed/refused/invalid answer contract failed.'
        $cases.Add([pscustomobject]@{ id = 'answer-' + $(if ($answer) { $answer } else { 'blank' }); expected = $expected; observed = $result.status; status = 'PASSED' })
    }
    $context = New-ContractContext; $result = Invoke-ContractCompletion $context 'yes'
    Assert-Contract ($result.status -ceq 'BLOCKED' -and $result.observation -ceq 'PASSED' -and -not $result.matched_run) 'An affirmative answer without an exact run must remain blocked.'
    $cases.Add([pscustomobject]@{ id = 'yes-without-run'; expected = 'BLOCKED'; observed = $result.status; status = 'PASSED' })
    foreach ($mutation in @('', 'wrong-source', 'wrong-build', 'old-time', 'bad-marker')) {
        $context = New-ContractContext; $null = New-ContractRun $context -Mutation $mutation
        $result = Invoke-ContractCompletion $context 'yes'
        $expected = if ($mutation -ceq '') { 'PASSED' } else { 'BLOCKED' }
        Assert-Contract ($result.status -ceq $expected -and $context.closed -and -not $result.raw_exit_captured -and $null -eq $result.captured_exit_code) 'Source/build/time/marker correlation contract failed.'
        if ($expected -ceq 'PASSED') { Assert-Contract ($result.matched_run -and $result.conversion.injected_contract_result) 'Synthetic matching route failed to invoke the injected media validator.' }
        $cases.Add([pscustomobject]@{ id = 'correlation-' + $(if ($mutation) { $mutation } else { 'matching' }); expected = $expected; observed = $result.status; status = 'PASSED' })
    }
    $context = New-ContractContext; $null = New-ContractRun $context; $null = New-ContractRun $context -Counter 2
    $result = Invoke-ContractCompletion $context 'yes'
    Assert-Contract ($result.status -ceq 'BLOCKED' -and -not $result.matched_run) 'Two exact matching runs must refuse correlation.'
    $cases.Add([pscustomobject]@{ id = 'ambiguous-runs'; expected = 'BLOCKED'; observed = $result.status; status = 'PASSED' })
    $context = New-ContractContext
    $null = New-Event -SourceIdentifier $context.error_event_id -MessageData 'Injected watcher error contract'
    $result = Invoke-ContractCompletion $context 'yes'
    Assert-Contract ($result.status -ceq 'BLOCKED') 'Watcher errors must refuse correlation.'
    $cases.Add([pscustomobject]@{ id = 'watcher-error'; expected = 'BLOCKED'; observed = $result.status; status = 'PASSED' })
    $context = New-ContractContext
    for ($index = 0; $index -lt 1001; $index++) { $null = New-Event -SourceIdentifier $context.created_event_id -MessageData 'Injected bounded-event contract' }
    $result = Invoke-ContractCompletion $context 'yes'
    Assert-Contract ($result.status -ceq 'BLOCKED') 'Excessive events must refuse correlation.'
    $cases.Add([pscustomobject]@{ id = 'event-bound'; expected = 'BLOCKED'; observed = $result.status; status = 'PASSED' })
    $context = New-ContractContext; $null = New-ContractRun $context
    $script:contractValidationFailure = $true; $result = Invoke-ContractCompletion $context 'yes'; $script:contractValidationFailure = $false
    Assert-Contract ($result.status -ceq 'BLOCKED' -and -not $result.matched_run -and $null -eq $result.conversion) 'Media verification refusal cannot produce a physical gate pass.'
    $cases.Add([pscustomobject]@{ id = 'media-refusal'; expected = 'BLOCKED'; observed = $result.status; status = 'PASSED' })
    $report.status = 'PASSED'
}
catch { $failure = $_; $report.error = $_.Exception.Message }
finally {
    foreach ($context in $contexts) { Close-AcceptancePhysical $context }
    $report.watcher_cleanup_verified = @($contexts | Where-Object { -not $_.closed -or $null -ne $_.watcher }).Count -eq 0
    foreach ($row in $report.source_before) { $report.source_after += [pscustomobject]@{ path = $row.path; sha256 = Get-AcceptanceHash (Join-Path $project $row.path) } }
    $report.source_unchanged = ($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress)
    if ($created -and $report.watcher_cleanup_verified) {
        $ownership = Read-AcceptanceJson $markerPath
        if ($ownership.token -cne $token -or -not (Test-AcceptanceWithin $root $temporaryParent)) { throw 'Owned test cleanup identity was not proved.' }
        foreach ($path in $files) { $null = Assert-AcceptanceLocalPath $path -MustExist; if (-not (Test-AcceptanceWithin $path $root)) { throw 'Cleanup escaped the test root.' }; [IO.File]::Delete($path) }
        for ($index = $directories.Count - 1; $index -ge 0; $index--) { $null = Assert-AcceptanceLocalPath $directories[$index] -MustExist; [IO.Directory]::Delete($directories[$index], $false) }
        $null = Assert-AcceptanceLocalPath $root -MustExist; [IO.Directory]::Delete($root, $false)
        $report.cleanup_verified = -not (Test-Path -LiteralPath $root)
    }
    $report.cases = $cases.ToArray(); $report.ended_utc = [DateTimeOffset]::UtcNow.ToString('o')
    $stream = [IO.File]::Open($evidence, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($report | ConvertTo-Json -Depth 12)); $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
    Remove-Item -LiteralPath Function:\Read-Host -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath Function:\Test-AcceptanceConversion -ErrorAction SilentlyContinue
}
if ($null -ne $failure) { throw $failure }
if (-not $report.source_unchanged -or -not $report.watcher_cleanup_verified -or -not $report.cleanup_verified) { throw 'Physical contract source or cleanup verification failed.' }
Write-Output ('Physical correlation contracts PASSED: ' + $cases.Count + ' groups; no human/client acceptance claimed.')
