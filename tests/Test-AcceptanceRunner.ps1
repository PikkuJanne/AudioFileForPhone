<#
Real extracted-kit rehearsal integration. Inputs are existing local runtime assets;
this suite never freezes a release, downloads tools or accesses ordinary Music.
Private raw reports are deliberately retained in the marker-owned TEMP scope.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeAssetsDirectory,
    [Parameter(Mandatory = $true)][string]$FfmpegDirectory,
    [Parameter(Mandatory = $true)][string]$PowerShell7Path,
    [Parameter(Mandatory = $true)][string]$EvidencePath
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $project 'tools\acceptance\Acceptance.Common.ps1')
. (Join-Path $project 'AudioFileForPhone.Helpers.ps1')
$assets = Assert-AcceptanceLocalPath $RuntimeAssetsDirectory -MustExist
$tools = Assert-AcceptanceLocalPath $FfmpegDirectory -MustExist
$ps7 = Assert-AcceptanceLocalPath $PowerShell7Path -MustExist
$evidence = Assert-AcceptanceLocalPath $EvidencePath
if (Test-Path -LiteralPath $evidence) { throw 'Runner evidence already exists.' }
$null = Assert-AcceptanceLocalPath ([IO.Path]::GetDirectoryName($evidence)) -MustExist
$hostProcess = [Diagnostics.Process]::GetCurrentProcess()
try { $shell = $hostProcess.MainModule.FileName } finally { $hostProcess.Dispose() }
$scope = Join-Path ([IO.Path]::GetTempPath()) ('S13R-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$cases = New-Object 'Collections.Generic.List[object]'
$children = New-Object 'Collections.Generic.List[object]'
$rawReports = New-Object 'Collections.Generic.List[object]'
$failure = $null; $released = $true; $fixtureNative = @(); $kitHash = $null; $runtimeHash = $null
$started = [DateTime]::UtcNow.ToString('o')
$sourceBefore = @(); $sourceAfter = @(); $sourceUnchanged = $false
$utf8 = New-Object Text.UTF8Encoding($false)
$sourceHashes = @()

function Assert-Runner {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Write-RunnerJson {
    param([string]$Path, [object]$Object)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($Object | ConvertTo-Json -Depth 24) + "`n")
        $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true)
    } finally { $stream.Dispose() }
}
function Add-RunnerCase {
    param([string]$Id, [string]$Expected, [string]$Observed, [AllowNull()][object]$ExitCode = $null)
    $cases.Add([pscustomobject]@{ id = $Id; status = 'PASSED'; expected = $Expected; observed = $Observed; exit_code = $ExitCode })
}
function Invoke-RunnerHost {
    param([string]$Name, [string]$Target, [hashtable]$Parameters)
    $driverPath = Join-Path $scope ($Name + '-driver.ps1')
    $argumentsPath = Join-Path $scope ($Name + '-arguments.json')
    Write-RunnerJson $argumentsPath ([ordered]@{ parameters = $Parameters })
    [IO.File]::WriteAllText($driverPath, @'
$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$document = [IO.File]::ReadAllText($env:AFP_TEST_ARGUMENTS, [Text.Encoding]::UTF8) | ConvertFrom-Json
$forward = @{}
foreach ($property in $document.parameters.PSObject.Properties) { $forward[$property.Name] = $property.Value }
$global:LASTEXITCODE = 0
& $env:AFP_TEST_TARGET @forward
exit $LASTEXITCODE
'@, $utf8)
    $local = Join-Path $scope ($Name + '-child'); $null = [IO.Directory]::CreateDirectory($local)
    $environment = @{
        AFP_TEST_TARGET = $Target; AFP_TEST_ARGUMENTS = $argumentsPath
        PATH = ($env:SystemRoot + '\System32;' + $env:SystemRoot)
        LOCALAPPDATA = $local; TEMP = $local; TMP = $local
        PSModulePath = ((Join-Path ([IO.Path]::GetDirectoryName($shell)) 'Modules') + ';' +
            (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules') + ';' + $env:PSModulePath)
        AUDIOFILEFORPHONE_INPUT = ''; AUDIOFILEFORPHONE_HOST = ''
    }
    $script:released = $false
    $child = Invoke-AcceptanceChild -Executable $shell -Arguments @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','RemoteSigned','-File',$driverPath) -Environment $environment
    $script:released = $child.process_released -and $child.pipe_drain_completed
    $children.Add([pscustomobject]@{ id = $Name; result = $child })
    Assert-Runner ($script:released -and -not $child.stdout_truncated -and -not $child.stderr_truncated) ('Child release or bounded capture is unproved: ' + $Name)
    return $child
}
function New-RunnerExtraction {
    param([string]$Name)
    $directory = Join-Path $scope $Name
    if (Test-Path -LiteralPath $directory) { throw 'Extraction collision.' }
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $scope 'built\Acceptance-Kit.zip'), $directory)
    $null = Assert-AcceptanceLocalPath $directory -MustExist
    return $directory
}
function Invoke-ExtractedRunner {
    param([string]$Name, [string]$Extraction, [string]$Source, [string]$Archive,
          [string]$ToolDirectory = $tools, [switch]$WithoutRehearsal, [switch]$Overlap)
    $parent = if ($Overlap) { $Source } else { Join-Path $scope ($Name + '-sessions') }
    if (-not (Test-Path -LiteralPath $parent)) { $null = [IO.Directory]::CreateDirectory($parent) }
    $parameters = @{
        SourceDirectory = $Source; FfmpegDirectory = $ToolDirectory; PowerShell7Path = $ps7
        KitArchivePath = $Archive; SessionParent = $parent; AutomatedOnly = $true
    }
    if (-not $WithoutRehearsal) { $parameters.Rehearsal = $true }
    $child = Invoke-RunnerHost $Name (Join-Path $Extraction 'Run-Windows-Acceptance.ps1') $parameters
    $matchesFound = [regex]::Matches($child.stdout, '(?m)^Local acceptance session: ([^\r\n]+)\r?$')
    Assert-Runner ($matchesFound.Count -eq 1) ('Runner did not identify exactly one new session: ' + $Name)
    $session = Assert-AcceptanceLocalPath $matchesFound[0].Groups[1].Value -MustExist
    Assert-Runner (Test-AcceptanceWithin $session $parent) 'Runner session escaped its exclusive parent.'
    $reportPath = Join-Path $session 'REPORT.json'; $textPath = Join-Path $session 'REPORT.txt'
    $privatePath = Join-Path $session 'local-private.json'
    $report = Read-AcceptanceJson $reportPath -MaximumBytes 4194304
    $raw = Read-AcceptanceJson $privatePath -MaximumBytes 16777216
    $text = [IO.File]::ReadAllText($textPath, [Text.Encoding]::UTF8)
    $serialized = [IO.File]::ReadAllText($reportPath, [Text.Encoding]::UTF8) + $text
    Assert-Runner ($serialized -notmatch 'PRIVATE_MEDIA_MARKER|PRIVATE_SENTINEL_S13|[A-Za-z]:[\\/]|S13R-[a-f0-9]{8}') ('Report exported a private path/content: ' + $Name)
    foreach ($sourceHash in $sourceHashes) { Assert-Runner (-not $serialized.Contains($sourceHash)) 'Report exported a source-content hash.' }
    foreach ($field in @('physical_shortcut','phone_play','phone_seek')) {
        Assert-Runner ($report.human_observations.$field -ceq 'NOT_TESTED') 'Unperformed human observation was filled.'
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $session -File -Force | Where-Object { $_.Extension -ceq '.json' })) {
        $document = Read-AcceptanceJson $file.FullName -MaximumBytes 16777216
        if ($null -ne $document.PSObject.Properties['kind']) { Assert-Runner ($document.kind -cne 'candidate_acceptance') 'Rehearsal emitted final-candidate acceptance.' }
    }
    $rawReports.Add([pscustomobject]@{
        id = $Name; session_directory = $session; report_path = $reportPath; report_sha256 = Get-AcceptanceHash $reportPath
        text_path = $textPath; text_sha256 = Get-AcceptanceHash $textPath
        private_path = $privatePath; private_sha256 = Get-AcceptanceHash $privatePath
    })
    return [pscustomobject]@{ child = $child; session = $session; report = $report; private = $raw }
}
function Assert-RunnerRefusal {
    param([string]$Name, [object]$Result, [string]$Issue)
    Assert-Runner ($Result.child.exit_code -eq 1 -and $Result.report.status -ceq 'FAILED' -and $Result.report.issue_code -ceq $Issue) ('Wrong fault result for ' + $Name)
    Assert-Runner (@($Result.private.conversions).Count -eq 0) ('Early fault unexpectedly converted media: ' + $Name)
    Add-RunnerCase $Name ('raw1, FAILED, ' + $Issue + ', redacted report, no conversion') 'Expected early refusal; private evidence retained and humans untested.' $Result.child.exit_code
}

try {
    Assert-Runner (-not (Test-Path -LiteralPath $scope)) 'Owned TEMP collision.'
    $null = [IO.Directory]::CreateDirectory($scope)
    Write-RunnerJson (Join-Path $scope '.owner') ([ordered]@{ kind = 'S13.AcceptanceRunnerTest'; token = [guid]::NewGuid().ToString('N') })
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $manifest = Read-AcceptanceJson (Join-Path $assets 'release-manifest.json') -MaximumBytes 1048576
    $runtimeZip = Join-Path $assets ([string]$manifest.zip.name)
    $runtimeHash = Get-AcceptanceHash $runtimeZip
    Assert-Runner ($runtimeHash -ceq $manifest.zip.sha256) 'Actual runtime input digest mismatch.'
    $assetBefore = @('release-manifest.json','SHA256SUMS.txt',[string]$manifest.zip.name) | ForEach-Object {
        [pscustomobject]@{ path = $_; sha256 = Get-AcceptanceHash (Join-Path $assets $_) }
    }
    $build = Invoke-RunnerHost 'build' (Join-Path $project 'tools\Build-AcceptanceKit.ps1') @{
        RuntimeAssetsDirectory = $assets; OutputDirectory = (Join-Path $scope 'built')
        RunnerSourceDirectory = (Join-Path $project 'tools\acceptance'); Rehearsal = $true
    }
    Assert-Runner ($build.exit_code -eq 0) ('Real runtime kit build failed: ' + $build.stdout + $build.stderr)
    $kitArchive = Join-Path $scope 'built\Acceptance-Kit.zip'; $kitHash = Get-AcceptanceHash $kitArchive
    $buildResult = $build.stdout | ConvertFrom-Json
    Assert-Runner ($buildResult.acceptance_kit_sha256 -ceq $kitHash) 'Builder result differs from actual archive digest.'
    Add-RunnerCase 'real_runtime_kit_build' 'raw0 and actual ZIP digest match' 'Fresh rehearsal kit built from existing actual runtime assets.' $build.exit_code
    $extraction = New-RunnerExtraction 'kit'
    $source = Join-Path $scope ("PRIVATE_MEDIA_MARKER [" + [char]0x00E4 + "] & ' ! %")
    $null = [IO.Directory]::CreateDirectory($source)
    $nested = Join-Path $source 'nested'; $null = [IO.Directory]::CreateDirectory($nested)
    $fixtures = @(
        @((Join-Path $source ("01 [" + [char]0x00F6 + "] & ' ! %.mp3")), @('-c:a','libmp3lame','-b:a','96k')),
        @((Join-Path $nested '02-aac.m4a'), @('-c:a','aac','-b:a','96k')),
        @((Join-Path $nested '03-vorbis.ogg'), @('-c:a','libvorbis','-q:a','3'))
    )
    foreach ($fixture in $fixtures) {
        $script:released = $false
        $native = Invoke-AudioNativeProcess -ExecutablePath (Join-Path $tools 'ffmpeg.exe') -Arguments (@('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=617:sample_rate=44100:duration=1.5','-metadata','artist=S13 synthetic artist') + $fixture[1] + @($fixture[0]))
        $fixtureNative += $native
        $script:released = $native.ProcessReleased -and $native.PipeDrainCompleted
        Assert-Runner ($script:released -and $native.Status -ceq 'Completed' -and $native.ExitCode -eq 0) 'Synthetic input creation failed or release is unproved.'
    }
    [IO.File]::WriteAllText((Join-Path $source 'unsupported.txt'), 'PRIVATE_SENTINEL_S13')
    $sourceBefore = @(Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported)
    Assert-Runner ($sourceBefore.Count -eq 4 -and @($sourceBefore | Where-Object { $_.supported }).Count -eq 3) 'Synthetic source inventory must contain three supported files plus sentinel.'
    $sourceHashes = @($sourceBefore | ForEach-Object { $_.sha256 })
    $success = Invoke-ExtractedRunner 'positive' $extraction $source $kitArchive
    Assert-Runner ($success.child.exit_code -eq 0 -and $success.report.kind -ceq 'rehearsal_collection' -and
        $success.report.status -ceq 'AUTOMATED_PASSED_ACCEPTANCE_INCOMPLETE') ('Extracted rehearsal did not complete honest automated scope: ' + $success.child.stdout + $success.child.stderr)
    Assert-Runner ($success.report.runtime_zip_sha256 -ceq $runtimeHash -and $success.report.acceptance_kit_sha256 -ceq $kitHash -and
        $success.report.source_commit -ceq $manifest.release_commit -and $success.report.runtime_version -ceq $manifest.app_version) 'Report package/source/archive binding mismatch.'
    Assert-Runner (@($success.report.hosts).Count -eq 2 -and $success.report.hosts[0].shell_version -match '^5\.1\.' -and
        $success.report.hosts[1].shell_version -match '^7\.' -and @($success.report.hosts | Where-Object { $_.status -cne 'PASSED' }).Count -eq 0) 'Both actual supported hosts were not verified.'
    $oneCases = @($success.report.cases | Where-Object { $_.id -match '^one_file_host[12]$' })
    $longCases = @($success.report.cases | Where-Object { $_.id -match '^long_file_host[12]$' })
    Assert-Runner ($oneCases.Count -eq 2 -and $longCases.Count -eq 2) 'Expected one-file and long-file conversion per actual host.'
    foreach ($row in @($oneCases) + @($longCases)) {
        Assert-Runner ($row.status -ceq 'PASSED' -and $row.exit_code -eq 0 -and $row.raw_exit_captured -and
            $row.input_count -eq 1 -and $row.converted_count -eq 1 -and $row.failed_count -eq 0 -and $row.unprocessed_count -eq 0 -and
            $row.source_unchanged -and $row.media_validated -and $row.full_decode -and $row.media[0].bitrate_bps -eq 64000 -and $row.media[0].full_decode) 'One/long-file execution or independent media evidence failed.'
    }
    foreach ($row in $longCases) {
        Assert-Runner ($row.media[0].input_duration_seconds -ge 3605 -and
            [math]::Abs($row.media[0].decoded_duration_seconds - $row.media[0].input_duration_seconds) -le 0.35) 'Long synthetic full-decode duration did not meet the fixed tolerance.'
    }
    $collection = @($success.report.cases | Where-Object { $_.id -ceq 'full_collection_controlled_packaged_ps1' })
    Assert-Runner ($collection.Count -eq 1 -and $collection[0].status -ceq 'PASSED' -and $collection[0].exit_code -eq 0 -and
        $collection[0].input_count -eq 3 -and $collection[0].converted_count -eq 3 -and $collection[0].failed_count -eq 0 -and
        $collection[0].unprocessed_count -eq 0 -and $collection[0].source_unchanged -and $collection[0].media_validated -and
        @($collection[0].media).Count -eq 3) 'Controlled real collection did not correlate all three inputs.'
    foreach ($conversion in @($success.private.conversions)) {
        Assert-Runner (Test-AcceptanceWithin $conversion.run_directory $success.session) 'A controlled conversion escaped its owned session.'
    }
    foreach ($childRecord in @($success.private.children | Where-Object { $null -ne $_.PSObject.Properties['script'] })) {
        if ([IO.Path]::GetFileName([string]$childRecord.script) -cin @('AudioFileForPhone.ps1','Setup-AudioFileForPhone.ps1')) {
            Assert-Runner (@($childRecord.arguments) -ccontains '-ConfigPath') 'Controlled production invocation omitted its explicit owned config.'
            if ([IO.Path]::GetFileName([string]$childRecord.script) -ceq 'AudioFileForPhone.ps1') {
                Assert-Runner (@($childRecord.arguments) -ccontains '-OutputParent') 'Controlled conversion omitted its explicit owned output.'
            }
        }
    }
    Add-RunnerCase 'extracted_real_rehearsal' 'raw0; actual2hosts; one+3605s each; collection3; strict IDs; humans untested' 'Seven real production conversions independently decoded; all outputs remain in owned scope.' $success.child.exit_code

    $tamperedRunner = New-RunnerExtraction 'bad-runner'
    [IO.File]::AppendAllText((Join-Path $tamperedRunner 'Run-Windows-Acceptance.ps1'), "`n# deliberate extracted runner mutation`n", $utf8)
    Assert-RunnerRefusal 'tampered_runner' (Invoke-ExtractedRunner 'tampered-runner' $tamperedRunner $source $kitArchive) 'PACKAGE_IDENTITY'
    $tamperedRuntime = New-RunnerExtraction 'bad-runtime'
    $runtimeRelative = 'runtime\' + [string]$manifest.zip.name
    $runtimeStream = [IO.File]::Open((Join-Path $tamperedRuntime $runtimeRelative), [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $runtimeStream.WriteByte(42) } finally { $runtimeStream.Dispose() }
    Assert-RunnerRefusal 'tampered_runtime' (Invoke-ExtractedRunner 'tampered-runtime' $tamperedRuntime $source $kitArchive) 'PACKAGE_IDENTITY'
    $badArchive = Join-Path $scope 'corrupt-kit.zip'
    $archiveBytes = [IO.File]::ReadAllBytes($kitArchive)
    $archiveStream = [IO.File]::Open($badArchive, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $archiveStream.Write($archiveBytes, 0, $archiveBytes.Length - 30) } finally { $archiveStream.Dispose() }
    Assert-RunnerRefusal 'tampered_archive' (Invoke-ExtractedRunner 'tampered-archive' $extraction $source $badArchive) 'PACKAGE_IDENTITY'
    Assert-RunnerRefusal 'missing_retained_archive' (Invoke-ExtractedRunner 'missing-archive' $extraction $source (Join-Path $scope 'missing.zip')) 'PACKAGE_IDENTITY'
    Assert-RunnerRefusal 'rehearsal_requires_opt_in' (Invoke-ExtractedRunner 'no-rehearsal' $extraction $source $kitArchive -WithoutRehearsal) 'PACKAGE_IDENTITY'
    $emptySource = Join-Path $scope 'empty-source'; $null = [IO.Directory]::CreateDirectory($emptySource)
    Assert-RunnerRefusal 'empty_source' (Invoke-ExtractedRunner 'empty-source' $extraction $emptySource $kitArchive) 'SOURCE_SELECTION'
    $overlap = Join-Path $scope 'overlap-source'; $null = [IO.Directory]::CreateDirectory($overlap)
    Assert-RunnerRefusal 'source_session_overlap' (Invoke-ExtractedRunner 'overlap' $extraction $overlap $kitArchive -Overlap) 'SOURCE_SELECTION'
    $emptyTools = Join-Path $scope 'empty-tools'; $null = [IO.Directory]::CreateDirectory($emptyTools)
    Assert-RunnerRefusal 'unavailable_explicit_tools' (Invoke-ExtractedRunner 'missing-tools' $extraction $source $kitArchive -ToolDirectory $emptyTools) 'DEPENDENCY_SELECTION'

    $sourceAfter = @(Get-AcceptanceSourceInventory -Root $source -IncludeUnsupported)
    $sourceUnchanged = Test-AcceptanceSourceInventory -Root $source -Before $sourceBefore -IncludeUnsupported
    Assert-Runner $sourceUnchanged 'Synthetic source or unsupported sentinel changed.'
    Assert-Runner ((Get-AcceptanceHash $kitArchive) -ceq $kitHash) 'Canonical kit archive changed during tests.'
    foreach ($row in $assetBefore) { Assert-Runner ((Get-AcceptanceHash (Join-Path $assets $row.path)) -ceq $row.sha256) 'Input runtime asset changed during tests.' }
    Add-RunnerCase 'source_and_input_assets_unchanged' 'All4source hashes and actual input assets unchanged' 'Full before/after inventory matched; mutations were isolated to deliberate test copies.'
} catch { $failure = $_.Exception.Message }
finally {
    $codeHashes = @()
    foreach ($name in @('tools\Build-AcceptanceKit.ps1','tools\acceptance\Run-Windows-Acceptance.ps1','tools\acceptance\Acceptance.Common.ps1',
        'tools\acceptance\Acceptance.Physical.ps1','tools\acceptance\Export-AcceptanceReport.ps1','tests\Test-AcceptanceRunner.ps1')) {
        $codeHashes += [pscustomobject]@{ path = $name.Replace('\','/'); sha256 = Get-AcceptanceHash (Join-Path $project $name) }
    }
    $document = [ordered]@{
        schema_version = 1; task = 'S13'; mode = 'real_extracted_kit_rehearsal'; status = $(if ($null -eq $failure) { 'pass' } else { 'fail' })
        started_utc = $started; ended_utc = [DateTime]::UtcNow.ToString('o'); shell_version = [string]$PSVersionTable.PSVersion
        shell_edition = [string]$PSVersionTable.PSEdition; code_hashes = $codeHashes
        runtime_zip_sha256 = $runtimeHash; acceptance_kit_sha256 = $kitHash; cases = $cases.ToArray(); error = $failure
        fixture_root = $scope; children = $children.ToArray(); fixture_native = $fixtureNative; raw_reports = $rawReports.ToArray()
        source_before = $sourceBefore; source_after = $sourceAfter; source_unchanged = $sourceUnchanged
        descendant_release_proved = $released; fixtures_retained = $true; cleanup_performed = $false
        ordinary_music_access = $false; owner_config_access = $false; physical_observation = 'NOT_TESTED'; phone_observation = 'NOT_TESTED'
        release_candidate_acceptance = $false
    }
    Write-RunnerJson $evidence $document
}
if ($null -ne $failure) { throw ('Acceptance runner integration failed: ' + $failure) }
[pscustomobject]@{ status = 'pass'; cases = $cases.Count; evidence = $evidence; fixture_root = $scope; acceptance_kit_sha256 = $kitHash } | ConvertTo-Json
