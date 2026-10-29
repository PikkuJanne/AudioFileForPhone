[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $project 'tools\acceptance\Acceptance.Common.ps1')
. (Join-Path $project 'tools\acceptance\Export-AcceptanceReport.ps1')
. (Join-Path $project 'AudioFileForPhone.Helpers.ps1')
$evidence = Assert-AcceptanceLocalPath $EvidencePath
if (Test-Path -LiteralPath $evidence) { throw 'Evidence already exists.' }
$null = Assert-AcceptanceLocalPath ([IO.Path]::GetDirectoryName($evidence)) -MustExist
$scope = Join-Path ([IO.Path]::GetTempPath()) ('S13Common-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$cases = New-Object 'Collections.Generic.List[object]'
$released = $true; $failure = $null; $cleaned = $false
$started = [DateTime]::UtcNow.ToString('o')
function Assert-Common { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Add-CommonCase { param([string]$Id); $cases.Add([pscustomobject]@{ id = $Id; status = 'PASSED' }) }
function Assert-CommonRefused {
    param([scriptblock]$Action, [string]$Id)
    $refused = $false
    try { & $Action | Out-Null } catch { $refused = $true }
    Assert-Common $refused ('Expected refusal: ' + $Id); Add-CommonCase $Id
}
function New-CommonZip {
    param([string]$Path, [string[]]$Names, [string[]]$Texts)
    $zip = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        for ($index = 0; $index -lt $Names.Count; $index++) {
            $entry = $zip.CreateEntry($Names[$index]); $entry.ExternalAttributes = 0
            $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
            try { $writer.Write($Texts[$index]) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
}
try {
    $null = [IO.Directory]::CreateDirectory($scope)
    [IO.File]::WriteAllText((Join-Path $scope '.owner'), 'S13 focused common test')
    $source = Join-Path $scope ('source [' + [char]0x00E4 + ']'); $export = Join-Path $scope 'export'
    $null = [IO.Directory]::CreateDirectory($source); $null = [IO.Directory]::CreateDirectory($export)
    Assert-CommonRefused { Assert-AcceptanceLocalPath '\\server\share\file' } 'unc_refused'
    Assert-CommonRefused { Assert-AcceptanceLocalPath 'C:\folder\..\alias' } 'dot_alias_refused'
    Assert-CommonRefused { Assert-AcceptanceLocalPath 'C:\file:stream' } 'stream_refused'
    Assert-CommonRefused { Get-AcceptanceMemberPath $scope '../escape' } 'relative_escape_refused'
    [IO.File]::WriteAllText((Join-Path $source 'fixture.mp3'), 'inert source hashing fixture')
    $identityReaderBefore = (Get-Command Get-AudioIdentityFile -CommandType Function).ScriptBlock.ToString()
    $before = @(Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported)
    Assert-Common ($before.Count -eq 1 -and -not [IO.File]::Exists((Join-Path $source '.AudioFileForPhone-output.json'))) 'Missing-marker bracket/Unicode source was not inventoried.'
    Assert-Common ((Get-Command Get-AudioIdentityFile -CommandType Function).ScriptBlock.ToString() -ceq $identityReaderBefore) 'Inventory adapter escaped its local scope.'
    Add-CommonCase 'bracket_unicode_missing_marker'
    $generated = Join-Path $source 'marked-output'; $null = [IO.Directory]::CreateDirectory($generated)
    Write-AudioOutputMarker -OutputRoot $generated
    [IO.File]::WriteAllText((Join-Path $generated 'generated.mp3'), 'inert excluded output fixture')
    $excluded = @(Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported)
    Assert-Common ($excluded.Count -eq 1 -and $excluded[0].relative_path -ceq 'fixture.mp3') 'Actual production output marker was not excluded.'
    Add-CommonCase 'production_marker_exclusion_preserved'
    $markerLock = [IO.File]::Open((Join-Path $generated '.AudioFileForPhone-output.json'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try { Assert-CommonRefused { Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported } 'unreadable_marker_refused' }
    finally { $markerLock.Dispose() }
    $junctionTarget = Join-Path $scope 'junction-target'; $null = [IO.Directory]::CreateDirectory($junctionTarget)
    $junction = Join-Path $source 'reparse-source'
    $null = New-Item -ItemType Junction -Path $junction -Target $junctionTarget -ErrorAction Stop
    try { Assert-CommonRefused { Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported } 'source_reparse_refused' }
    finally {
        $junctionItem = Get-Item -LiteralPath $junction -Force -ErrorAction Stop
        if (($junctionItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -or
            -not (Test-AcceptanceWithin ([IO.Path]::GetFullPath($junction)) $scope)) { throw 'Owned junction identity changed; retained for inspection.' }
        [IO.Directory]::Delete($junction, $false)
    }
    Assert-Common (Test-AcceptanceSourceInventory -Root $source -Before $before) 'Unchanged source comparison failed.'
    Add-CommonCase 'source_unchanged'
    [IO.File]::WriteAllText((Join-Path $source 'extra.txt'), 'new file')
    Assert-Common (-not (Test-AcceptanceSourceInventory -Root $source -Before $before)) 'Added unsupported source escaped full-inventory detection.'
    Add-CommonCase 'source_added_file_detected'
    [IO.File]::Delete((Join-Path $source 'extra.txt'))
    [IO.File]::WriteAllText((Join-Path $source 'fixture.mp3'), 'changed source')
    Assert-Common (-not (Test-AcceptanceSourceInventory -Root $source -Before $before)) 'Changed source escaped hash detection.'
    Add-CommonCase 'source_mutation_detected'
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $entryFile = Join-Path $scope 'entry.txt'; [IO.File]::WriteAllText($entryFile, 'expected')
    $expected = @([pscustomobject]@{ path = 'entry.txt'; sha256 = Get-AcceptanceHash $entryFile })
    $validZip = Join-Path $scope 'valid.zip'; New-CommonZip $validZip @('entry.txt') @('expected')
    Test-AcceptanceZip -ZipPath $validZip -Expected $expected
    Add-CommonCase 'zip_exact_inventory'
    $badZip = Join-Path $scope 'unexpected.zip'; New-CommonZip $badZip @('entry.txt', 'extra.txt') @('expected', 'extra')
    Assert-CommonRefused { Test-AcceptanceZip -ZipPath $badZip -Expected $expected } 'zip_extra_refused'
    $duplicateZip = Join-Path $scope 'duplicate.zip'; New-CommonZip $duplicateZip @('entry.txt', 'entry.txt') @('expected', 'expected')
    Assert-CommonRefused { Test-AcceptanceZip -ZipPath $duplicateZip -Expected $expected } 'zip_duplicate_refused'
    $traversalZip = Join-Path $scope 'traversal.zip'; New-CommonZip $traversalZip @('../entry.txt') @('expected')
    Assert-CommonRefused { Test-AcceptanceZip -ZipPath $traversalZip -Expected $expected } 'zip_traversal_refused'
    $mismatchZip = Join-Path $scope 'mismatch.zip'; New-CommonZip $mismatchZip @('entry.txt') @('wrong')
    Assert-CommonRefused { Test-AcceptanceZip -ZipPath $mismatchZip -Expected $expected } 'zip_digest_refused'
    $report = [ordered]@{
        kind = 'rehearsal_acceptance'; status = 'AUTOMATED_PASSED_ACCEPTANCE_INCOMPLETE'; runtime_version = '1.0.0'
        environment = @{ os_caption = 'Windows test contract'; process_64bit = $true; private_path = 'C:\PRIVATE_MEDIA\secret.mp3' }
        hosts = @(@{ host_id = 'ps51'; shell_version = '5.1.0'; shell_edition = 'Desktop'; status = 'PASSED'; path = 'C:\PRIVATE_MEDIA\secret.mp3' })
        runtime_hashes = @(@{path = 'AudioFileForPhone.ps1'; sha256 = ('a' * 64)}, @{path = 'PRIVATE_MEDIA.mp3'; sha256 = ('b' * 64)})
        source_hashes = @(@{path = 'C:\PRIVATE_MEDIA\secret.mp3';sha256 = ('b' * 64)}); stdout = 'PRIVATE_LOG_MARKER'
        issue_code = 'C:\PRIVATE_MEDIA\secret.mp3'; human_observations = @{}
        cases = @(@{id = 'one_file';status = 'PASSED';result = @{captured_exit_code = 0;input_count = 1;converted_count = 1;failed_count = 0;unprocessed_count = 0;source_unchanged = $true;media_validated = $true;raw = 'PRIVATE_LOG_MARKER';media = @(@{sequence = 1;format = 'mp3';bitrate_bps = 64000;full_decode = $true})}})
    }
    $exported = Export-AcceptanceReport -Report $report -OutputDirectory $export
    $jsonText = [IO.File]::ReadAllText($exported.json_path); $text = [IO.File]::ReadAllText($exported.text_path)
    Assert-Common (($jsonText + $text) -notmatch 'PRIVATE_MEDIA|PRIVATE_LOG_MARKER|secret.mp3') 'Whitelisted export leaked private fields.'
    Assert-Common ($exported.report.human_observations.physical_shortcut -ceq 'NOT_TESTED' -and $exported.report.human_observations.phone_play -ceq 'NOT_TESTED' -and $exported.report.human_observations.phone_seek -ceq 'NOT_TESTED') 'Human defaults must remain untested.'
    Assert-Common ($exported.report.cases[0].exit_code -eq 0 -and $exported.report.cases[0].input_count -eq 1 -and $exported.report.cases[0].raw_exit_captured -and @($exported.report.runtime_hashes).Count -eq 1) 'Nested result fields were not exported correctly.'
    Add-CommonCase 'report_whitelist_and_nested_result'
    Assert-CommonRefused { Export-AcceptanceReport -Report $report -OutputDirectory $export } 'report_no_overwrite'
    $shell = Join-Path $PSHOME $(if ($PSVersionTable.PSEdition -ceq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' })
    $released = $false
    $child = Invoke-AcceptanceChild -Executable $shell -Arguments @('-NoLogo', '-NoProfile', '-Command', '[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); [Console]::Write([string]::new([char]120,1100000)); exit 7')
    $released = $child.process_released -and $child.pipe_drain_completed
    Assert-Common ($released -and $child.exit_code -eq 7 -and $child.stdout_truncated -and $child.stdout.Length -eq 1048576) 'Bounded child overflow/exit/release contract failed.'
    Add-CommonCase 'child_bounded_overflow_raw_exit_and_release'
} catch { $failure = $_.Exception.Message }
finally {
    if ($released -and (Test-Path -LiteralPath $scope)) {
        try {
            $null = Assert-AcceptanceLocalPath $scope -MustExist
            if ([IO.File]::ReadAllText((Join-Path $scope '.owner')) -cne 'S13 focused common test') { throw 'Owned cleanup marker mismatch.' }
            $pending = New-Object 'Collections.Generic.Stack[string]'; $pending.Push($scope)
            $directories = New-Object 'Collections.Generic.List[string]'
            while ($pending.Count -gt 0) {
                $directory = $pending.Pop(); $directories.Add($directory)
                foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
                    $null = Assert-AcceptanceLocalPath $item.FullName -MustExist
                    if ($item.PSIsContainer) { $pending.Push($item.FullName) } else { [IO.File]::Delete($item.FullName) }
                }
            }
            for ($index = $directories.Count - 1; $index -ge 0; $index--) { [IO.Directory]::Delete($directories[$index], $false) }
            $cleaned = -not (Test-Path -LiteralPath $scope)
        } catch { $failure = [string]$failure + ' Owned cleanup failed.' }
    }
    $document = [ordered]@{
        schema_version = 1; task = 'S13'; mode = 'acceptance_common_contracts'; status = $(if ($null -eq $failure -and $cleaned) { 'pass' } else { 'fail' })
        shell = [string]$PSVersionTable.PSVersion; shell_edition = [string]$PSVersionTable.PSEdition
        started_utc = $started; ended_utc = [DateTime]::UtcNow.ToString('o'); cases = $cases.ToArray()
        error = $failure; descendant_release_proved = $released; cleanup_verified = $cleaned
        ordinary_music_access = $false; release_acceptance = $false; human_observations = 'NOT_TESTED'
    }
    [IO.File]::WriteAllText($evidence, (($document | ConvertTo-Json -Depth 12) + "`n"), (New-Object Text.UTF8Encoding($false)))
}
if ($null -ne $failure -or -not $cleaned) { throw ('Acceptance common contract tests failed: ' + $failure) }
$document | ConvertTo-Json -Depth 4
