<#
.SYNOPSIS
Run focused R3 single-file, 31-file and long-audio checks on an exact user ZIP.
.DESCRIPTION
Uses the existing packaged native-process runner and external FFmpeg/ffprobe.
Both real app hosts receive explicit owned output/config paths, empty PATH and
NoProfile. Synthetic media and extracted scripts never touch ordinary Music.
Deterministic Internet marks are ADS fixtures, not browser-extraction evidence.
Owned media/output are removed only after process release, integrity and marker
checks; bounded raw captures and the create-new report remain outside Git.
No download, persistent environment/policy change or publication is performed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeZipPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedZipSha256,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [Parameter(Mandatory = $true)][string]$FfmpegDirectory,
    [Parameter(Mandatory = $true)][string]$PowerShell7Path,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$ExpectedAppVersion = '1.0.2'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$zipPath = [IO.Path]::GetFullPath($RuntimeZipPath)
$evidence = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetDirectoryName($evidence)
$ffmpeg = Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffmpeg.exe'
$ffprobe = Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffprobe.exe'
$PowerShell7Path = [IO.Path]::GetFullPath($PowerShell7Path)
$runRoot = Join-Path $evidenceParent ('R3-audio-' + [guid]::NewGuid().ToString('N'))
$dataRoot = Join-Path $runRoot 'owned-data'
$rawRoot = Join-Path $runRoot 'raw'
$packageRoot = Join-Path $dataRoot ('relocated app ' + [char]0x00e4 + [char]0x4e2d)
$singleRoot = Join-Path $dataRoot ('single input ' + [char]0x00f6)
$batchRoot = Join-Path $dataRoot ('batch input ' + [char]0x00e4)
$marker = Join-Path $runRoot '.R3-audio-owner'
$token = [guid]::NewGuid().ToString('N')
$pathBefore = $env:PATH
$modulesBefore = $env:PSModulePath
$localBefore = $env:LOCALAPPDATA
$tempBefore = $env:TEMP
$locationBefore = Get-Location
$directoryBefore = [Environment]::CurrentDirectory
$policiesBefore = @(Get-ExecutionPolicy -List | ForEach-Object { [pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy} })
$created = $false
$releaseProved = $true
$nativeRuns = New-Object 'Collections.Generic.List[object]'
$fixtures = New-Object 'Collections.Generic.List[object]'
$appRuns = New-Object 'Collections.Generic.List[object]'
$members = New-Object 'Collections.Generic.List[object]'
$sourceBindings = New-Object 'Collections.Generic.List[object]'
$report = [ordered]@{
    schema_version=1; task='R3'; kind='exact_package_audio_acceptance'; status='FAILED'
    started_utc=[DateTime]::UtcNow.ToString('o'); expected_source_commit=$ExpectedSourceCommit
    runtime_zip_sha256=$ExpectedZipSha256; app_version=$ExpectedAppVersion
    test_script_sha256=$null; environment=$null; dependencies=$null; package_members=@(); source_bindings=@()
    synthetic_sources=@(); app_runs=@(); native_runs=@(); total_converted=0
    long_duration_seconds=1800; source_unchanged=$false; package_unchanged=$false
    dependencies_unchanged=$false; policies_unchanged=$false; parent_environment_unchanged=$false
    descendant_release_proved=$false; cleanup_verified=$false; ordinary_music_access=$false
    owner_media_access=$false; user_config_read_or_written=$false; downloads_performed=$false
    publication_performed=$false; owner_testing_required='none'; physical_observation=$false
    browser_extraction_observed=$false; internet_marks='Deterministic Zone.Identifier ADS on every extracted PS1.'
    raw_captures_retained=$true; raw_evidence_root=$rawRoot
}

function Assert-R3([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-R3Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Assert-R3NoReparse([string]$Path) {
    $cursor=[IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            Assert-R3 (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse ancestor refused.'
        }
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-R3Inventory([string]$Root) {
    @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{path=$_.FullName.Substring($Root.TrimEnd('\','/').Length+1).Replace('\','/');bytes=$_.Length;sha256=Get-R3Hash $_.FullName}
    })
}
function Write-R3NewText([string]$Path,[string]$Text) {
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}
function Invoke-R3Native([string]$Executable,[string[]]$Arguments,[string]$Label) {
    $savedModules=$env:PSModulePath
    try {
        if ([IO.Path]::GetFileName($Executable) -ieq 'powershell.exe') { $env:PSModulePath=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/Modules' }
        $result=Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Operation $Label -MaxStdoutChars 1048576 -MaxStderrChars 65536
    } catch { $script:releaseProved=$false; throw }
    finally { $env:PSModulePath=$savedModules }
    if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { $script:releaseProved=$false }
    $stem=('{0:D3}-{1}' -f ($nativeRuns.Count+1),$Label)
    $stdout=Join-Path $rawRoot ($stem+'.stdout.txt'); $stderr=Join-Path $rawRoot ($stem+'.stderr.txt')
    Write-R3NewText $stdout $result.Stdout; Write-R3NewText $stderr $result.Stderr
    $nativeRuns.Add([pscustomobject]@{label=$Label;status=$result.Status;exit_code=$result.ExitCode;elapsed_ms=$result.ElapsedMilliseconds;timeout_ms=$result.TimeoutMilliseconds;process_released=$result.ProcessReleased;pipe_drain_completed=$result.PipeDrainCompleted;stdout_truncated=$result.StdoutTruncated;stderr_truncated=$result.StderrTruncated;stdout_sha256=Get-R3Hash $stdout;stderr_sha256=Get-R3Hash $stderr})
    Assert-R3 ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 0 -and $result.ProcessReleased -and $result.PipeDrainCompleted -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) ('Native '+$Label+' failed; retained captures '+$stem+'. '+$result.Error)
    return $result
}
function New-R3Fixture([string]$Root,[string]$Relative,[int]$Duration,[int]$Frequency,[switch]$Long) {
    $path=Join-Path $Root $Relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path)) | Out-Null
    $title=if ($Long) {'R3 synthetic long audio'} else {'R3 synthetic '+[IO.Path]::GetFileNameWithoutExtension($Relative).Substring(11)}
    $rate=if ($Long) {'22050'} else {'44100'}
    $null=Invoke-R3Native $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i',('sine=frequency='+$Frequency+':sample_rate='+$rate+':duration='+$Duration),'-ac','1','-c:a','aac','-b:a','48k','-metadata',('title='+$title),'-metadata','artist=R3 Synthetic Artist','-metadata','album=R3 Synthetic Album',$path) ('fixture-'+($fixtures.Count+1))
    $probe=(Invoke-R3Native $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$path) ('source-probe-'+($fixtures.Count+1))).Stdout | ConvertFrom-Json
    $audio=@($probe.streams | Where-Object {$_.codec_type -ceq 'audio'})
    Assert-R3 ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'aac' -and [math]::Abs([double]::Parse([string]$probe.format.duration,[Globalization.CultureInfo]::InvariantCulture)-$Duration) -lt 0.15) 'Synthetic M4A source shape/duration mismatch.'
    $fixtures.Add([pscustomobject]@{root=$Root;relative=$Relative.Replace('\','/');duration_seconds=$Duration;long=[bool]$Long;title=$title;sha256=Get-R3Hash $path;bytes=(Get-Item -LiteralPath $path).Length})
}
function Test-R3Batch([string]$Shell,[string]$ShellLabel,[string]$InputRoot,[string]$Kind) {
    $label=$ShellLabel+'-'+$Kind
    $output=Join-Path $dataRoot ($label+'-outputs'); $config=Join-Path $dataRoot ($label+'-config.json')
    $expected=@($fixtures | Where-Object {$_.root -ceq $InputRoot})
    $version=(Invoke-R3Native $Shell @('-NoLogo','-NoProfile','-NonInteractive','-Command','$PSVersionTable.PSVersion.ToString()') ($label+'-host-version')).Stdout.Trim()
    $result=Invoke-R3Native $Shell @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/AudioFileForPhone.ps1'),'-InputFolder',$InputRoot,'-OutputParent',$output,'-ConfigPath',$config,'-FfmpegDirectory',$FfmpegDirectory) ($label+'-convert')
    Assert-R3 (-not (Test-Path -LiteralPath $config)) 'Conversion saved a tool configuration.'
    $runs=@(Get-ChildItem -LiteralPath $output -Directory)
    Assert-R3 ($runs.Count -eq 1) 'Exactly one owned output run is required.'
    $manifestPath=Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json'
    $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-R3 ($manifest.app_version -ceq $ExpectedAppVersion -and $manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.policies.bitrate_kbps -eq 64 -and $manifest.tools.selection_origin -ceq 'Explicit' -and $manifest.totals.converted -eq $expected.Count -and $manifest.totals.failed -eq 0 -and $manifest.records.Count -eq $expected.Count) 'Application count/default/status/selection mismatch.'
    Assert-R3 ([regex]::Matches($result.Stdout,('(?m)^\[ AUDIOFILEFORPHONE :: '+[regex]::Escape($ExpectedAppVersion)+' \] -- AUDIO CONSOLE\s*$')).Count -eq 1 -and [regex]::Matches($result.Stdout,'(?m)^\[RESULT\]').Count -eq 1) 'Console must contain one heading and final result.'
    Assert-R3 ($result.Stdout -notmatch '\[DEBUG\]|(?m)^[-=]{12,}|Script path\s*:|Raw input\s*:|ffmpeg encoding arguments|ffmpeg\.exe.+-') 'Successful console contains diagnostic/command/banner clutter.'
    Assert-R3 ($result.Stdout -match ('converted='+$expected.Count+'; failed=0') -and $result.Stdout -match 'Input:' -and $result.Stdout -match '\[INFO\] Output root' -and $result.Stdout -match 'Log file\s*:') 'Console result/input/destination/log context missing.'
    $logPath=Join-Path $runs[0].FullName 'AudioFileForPhone_log.txt'; $log=Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
    Assert-R3 ($log -match ('Summary: total='+$expected.Count+', converted='+$expected.Count+', failed=0') -and $log -match 'FFmpeg encoding arguments' -and $log -match 'Source:') 'Detailed successful local diagnostics missing.'
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $rawRoot ($label+'-manifest.json'))
    Copy-Item -LiteralPath $logPath -Destination (Join-Path $rawRoot ($label+'-local-log.txt'))
    $files=@(Get-ChildItem -LiteralPath $runs[0].FullName -File -Recurse -Force)
    Assert-R3 (@($files | Where-Object {$_.Extension -ceq '.mp3'}).Count -eq $expected.Count -and @($files | Where-Object {$_.Name -match '(?i)\.partial|\.working|\.tmp$'}).Count -eq 0) 'Output count or remaining partial-file mismatch.'
    $verified=New-Object 'Collections.Generic.List[object]'
    foreach ($record in $manifest.records) {
        $relative=$record.source_relative_path.Replace('\','/')
        $fixture=@($expected | Where-Object {$_.relative -ceq $relative})
        Assert-R3 ($record.status -ceq 'Converted' -and $fixture.Count -eq 1) 'Manifest contains an unknown/unconverted source.'
        $leaf=[IO.Path]::GetFileNameWithoutExtension($relative).Substring(11)
        $expectedRelative=[IO.Path]::GetFileName($InputRoot)+'/'+($relative -replace '[^/]+$','')+'2026-10-30 - '+$leaf+'.mp3'
        Assert-R3 ($record.output_relative_path.Replace('\','/') -ceq $expectedRelative) 'Relative layout/date-first output name changed.'
        $outputPath=Join-Path $runs[0].FullName $record.output_relative_path
        $media=(Invoke-R3Native $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$outputPath) ($label+'-output-probe-'+($verified.Count+1))).Stdout | ConvertFrom-Json
        $audio=@($media.streams | Where-Object {$_.codec_type -ceq 'audio'})
        $duration=[double]::Parse([string]$media.format.duration,[Globalization.CultureInfo]::InvariantCulture)
        Assert-R3 ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int64]$audio[0].bit_rate -eq 64000 -and [math]::Abs($duration-$fixture[0].duration_seconds) -lt 0.3) 'Independent MP3 stream/64kbps/duration mismatch.'
        Assert-R3 ($media.format.tags.title -ceq $fixture[0].title -and $media.format.tags.artist -ceq 'R3 Synthetic Artist' -and $media.format.tags.album -ceq 'R3 Synthetic Album') 'Source metadata preservation changed.'
        $null=Invoke-R3Native $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-i',$outputPath,'-map','0:a:0','-f','null','-') ($label+'-full-decode-'+($verified.Count+1))
        $seeks=@()
        if ($fixture[0].long) {
            foreach ($fraction in @(0.25,0.5,0.9)) {
                $offset=[int]($fixture[0].duration_seconds*$fraction)
                $seek=Invoke-R3Native $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-ss',[string]$offset,'-i',$outputPath,'-t','5','-map','0:a:0','-progress','pipe:1','-nostats','-f','null','-') ($label+'-seek-'+$offset)
                $times=@([regex]::Matches($seek.Stdout,'(?m)^out_time_us=(\d+)\s*$') | ForEach-Object {[int64]$_.Groups[1].Value})
                $decoded=if ($times.Count -gt 0) {($times | Measure-Object -Maximum).Maximum} else {0}
                Assert-R3 ($seek.Stdout -match '(?m)^progress=end\s*$' -and $decoded -ge 4900000 -and $decoded -le 5200000) 'Long-audio seek did not prove five seconds of decoded output.'
                $seeks += [pscustomobject]@{offset_seconds=$offset;decoded_microseconds=$decoded;exit_code=0;full_requested_segment_decoded=$true}
            }
        }
        $verified.Add([pscustomobject]@{source_relative_path=$relative;output_relative_path=$record.output_relative_path;codec='mp3';bitrate_bps=64000;duration_seconds=$duration;expected_duration_seconds=$fixture[0].duration_seconds;full_decode=$true;metadata_verified=$true;date_and_layout_verified=$true;sha256=Get-R3Hash $outputPath;bytes=(Get-Item -LiteralPath $outputPath).Length;seeks=$seeks})
    }
    $appRuns.Add([pscustomobject]@{label=$label;shell_version=$version;input_count=$expected.Count;converted=$expected.Count;failed=0;exit_code=0;PATH='empty';NoProfile=$true;config_created=$false;selection_origin='Explicit';manifest_sha256=Get-R3Hash $manifestPath;log_sha256=Get-R3Hash $logPath;captured_console_verified=$true;outputs=$verified.ToArray()})
}

$exitCode=1
try {
    Assert-R3 ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and [Environment]::Is64BitProcess) 'Run on x64 Windows.'
    foreach ($path in @($zipPath,$evidenceParent,$ffmpeg,$ffprobe,$PowerShell7Path)) { Assert-R3NoReparse $path; Assert-R3 (Test-Path -LiteralPath $path) 'A required exact input path is missing.' }
    Assert-R3 (-not (Test-Path -LiteralPath $evidence) -and -not $evidence.StartsWith($projectRoot+'\',[StringComparison]::OrdinalIgnoreCase)) 'Use a new report outside the repository.'
    Assert-R3 ((Get-R3Hash $zipPath) -ceq $ExpectedZipSha256) 'Exact candidate ZIP SHA256 mismatch.'
    $os=Get-CimInstance Win32_OperatingSystem; $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent(); $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    $admin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $adminGroup=@($identity.Groups | ForEach-Object {$_.Value}) -contains 'S-1-5-32-544'
    Assert-R3 (-not $admin -and -not $adminGroup) 'Acceptance requires a non-administrator account and token.'
    $report.environment=[ordered]@{caption=$os.Caption;product_type=$os.ProductType;display_version=$cv.DisplayVersion;build=$os.BuildNumber+'.'+$cv.UBR;architecture=$os.OSArchitecture;elevated_administrator_role=$admin;administrators_group_sid_present=$adminGroup;orchestrator_ps=[string]$PSVersionTable.PSVersion;process_policy=[string](Get-ExecutionPolicy)}
    Assert-R3 (-not (Test-Path -LiteralPath $runRoot)) 'Owned root collision.'
    [IO.Directory]::CreateDirectory($runRoot) | Out-Null; $created=$true
    Write-R3NewText $marker $token
    foreach ($path in @($dataRoot,$rawRoot,$packageRoot,$singleRoot,$batchRoot,(Join-Path $dataRoot 'local-data'),(Join-Path $dataRoot 'temp'))) { [IO.Directory]::CreateDirectory($path) | Out-Null }
    $report.test_script_sha256=Get-R3Hash $PSCommandPath
    $dependenciesBefore=@(Get-R3Hash $ffmpeg;Get-R3Hash $ffprobe)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $allowlist=@('AudioFileForPhone.bat','AudioFileForPhone.ico','README.txt','app/AudioFileForPhone.ps1','app/AudioFileForPhone.Helpers.ps1','app/AudioFileForPhone.ManagedSetup.ps1','app/AudioFileForPhone.Diagnostics.ps1','app/AudioFileForPhone.Checks.ps1','app/Check-AudioFileForPhone.ps1','app/tools/ffmpeg-download.json','app/Setup-AudioFileForPhone.ps1','app/Setup-AudioFileForPhone.bat','app/README.md','app/SUPPORT.md','app/CHANGELOG.md','app/SECURITY.md','app/LICENSE')
    $archive=[IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase); $total=0L
        Assert-R3 ($archive.Entries.Count -eq $allowlist.Count) 'Candidate must use the exact clean user-package allowlist.'
        foreach ($entry in $archive.Entries) {
            $total+=$entry.Length
            Assert-R3 ($entry.FullName -cin $allowlist -and $seen.Add($entry.FullName) -and $entry.Length -gt 0 -and $entry.Length -le 4194304 -and $total -le 16777216) 'Unexpected/duplicate/out-of-bounds package member.'
        }
    } finally { $archive.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$packageRoot)
    $packageBefore=Get-R3Inventory $packageRoot
    foreach ($entry in $packageBefore) { $members.Add($entry) }
    . (Join-Path $PSScriptRoot '../tools/ReleaseGates.ps1')
    foreach ($entry in @($packageBefore | Where-Object {$_.path.StartsWith('app/') -and $_.path -cne 'app/Setup-AudioFileForPhone.bat'})) {
        $sourcePath=$entry.path.Substring(4)
        $sourceHash=Get-ReleaseGitBlobHash -RepositoryRoot $projectRoot -SourceCommit $ExpectedSourceCommit -RelativePath $sourcePath
        Assert-R3 ($sourceHash -ceq $entry.sha256) ('Exact candidate source binding failed: '+$sourcePath)
        $sourceBindings.Add([pscustomobject]@{source_path=$sourcePath;archive_path=$entry.path;sha256=$sourceHash})
    }
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'app') -File -Recurse | Where-Object {$_.Extension -ceq '.ps1'})) {
        Set-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
        Assert-R3 ((Get-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Raw).Contains('ZoneId=3')) 'Deterministic Internet mark not retained.'
    }
    . (Join-Path $packageRoot 'app/AudioFileForPhone.Helpers.ps1')
    Assert-R3 ((Get-AudioAppVersion) -ceq $ExpectedAppVersion) 'Packaged app version differs from the explicit candidate contract.'
    $env:PATH=''; $env:LOCALAPPDATA=Join-Path $dataRoot 'local-data'; $env:TEMP=Join-Path $dataRoot 'temp'
    Set-Location -LiteralPath $dataRoot; [Environment]::CurrentDirectory=$dataRoot
    $report.dependencies=[ordered]@{
        ffmpeg=[ordered]@{sha256=$dependenciesBefore[0];version=((Invoke-R3Native $ffmpeg @('-version') 'ffmpeg-version').Stdout -split "`r?`n")[0]}
        ffprobe=[ordered]@{sha256=$dependenciesBefore[1];version=((Invoke-R3Native $ffprobe @('-version') 'ffprobe-version').Stdout -split "`r?`n")[0]}
    }
    New-R3Fixture $singleRoot '2026-10-30 Single.m4a' 2 440
    for ($index=1;$index -le 30;$index++) {
        $sub=if (($index % 2) -eq 0) {'Part A'} else {'Part B '+[char]0x00f6}
        New-R3Fixture $batchRoot ($sub+'/2026-10-30 Item '+$index.ToString('D2')+'.m4a') 2 (400+$index*11)
    }
    New-R3Fixture $batchRoot 'Long/2026-10-30 Long 30 min.m4a' 1800 220 -Long
    $sourcesBefore=@($fixtures | ForEach-Object {[pscustomobject]@{root=$_.root;relative=$_.relative;sha256=Get-R3Hash (Join-Path $_.root $_.relative)}})
    $shells=@(@{label='ps51';path=(Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe')},@{label='ps7';path=$PowerShell7Path})
    foreach ($shell in $shells) { Test-R3Batch $shell.path $shell.label $singleRoot 'single'; Test-R3Batch $shell.path $shell.label $batchRoot 'batch31-long' }
    $sourcesAfter=@($fixtures | ForEach-Object {[pscustomobject]@{root=$_.root;relative=$_.relative;sha256=Get-R3Hash (Join-Path $_.root $_.relative)}})
    Assert-R3 (($sourcesBefore | ConvertTo-Json -Compress) -ceq ($sourcesAfter | ConvertTo-Json -Compress)) 'Synthetic source bytes changed in place.'
    Assert-R3 (($packageBefore | ConvertTo-Json -Compress) -ceq ((Get-R3Inventory $packageRoot) | ConvertTo-Json -Compress)) 'Extracted app bytes changed.'
    Assert-R3 ((Get-R3Hash $ffmpeg) -ceq $dependenciesBefore[0] -and (Get-R3Hash $ffprobe) -ceq $dependenciesBefore[1] -and (Get-R3Hash $zipPath) -ceq $ExpectedZipSha256) 'External tool or exact ZIP bytes changed.'
    $report.source_unchanged=$true; $report.package_unchanged=$true; $report.dependencies_unchanged=$true
    $report.total_converted=($appRuns | Measure-Object -Property converted -Sum).Sum
    Assert-R3 ($appRuns.Count -eq 4 -and $report.total_converted -eq 64) 'Required real single/31-file host matrix incomplete.'
    $report.status='PASSED'; $exitCode=0
} catch {
    $report.error=$_.Exception.Message.Replace($runRoot,'<OWNED_ROOT>')
    $report.error_location=$_.ScriptStackTrace.Replace($runRoot,'<OWNED_ROOT>')
} finally {
    $env:PATH=$pathBefore; $env:PSModulePath=$modulesBefore; $env:LOCALAPPDATA=$localBefore; $env:TEMP=$tempBefore
    Set-Location -LiteralPath $locationBefore.ProviderPath; [Environment]::CurrentDirectory=$directoryBefore
    $report.parent_environment_unchanged=$env:PATH -ceq $pathBefore -and $env:PSModulePath -ceq $modulesBefore -and $env:LOCALAPPDATA -ceq $localBefore -and $env:TEMP -ceq $tempBefore
    $policiesAfter=@(Get-ExecutionPolicy -List | ForEach-Object {[pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy}})
    $report.policies_unchanged=($policiesBefore | ConvertTo-Json -Compress) -ceq ($policiesAfter | ConvertTo-Json -Compress)
    $report.descendant_release_proved=$releaseProved
    $report.package_members=$members.ToArray(); $report.source_bindings=$sourceBindings.ToArray(); $report.synthetic_sources=$fixtures.ToArray(); $report.app_runs=$appRuns.ToArray(); $report.native_runs=$nativeRuns.ToArray()
    try {
        Assert-R3 ($report.parent_environment_unchanged -and $report.policies_unchanged) 'Parent environment/policy restoration failed.'
        if ($created -and (Test-Path -LiteralPath $dataRoot)) {
            Assert-R3 $releaseProved 'Owned cleanup refused because native release/drain is unproved.'
            Assert-R3NoReparse $dataRoot
            $resolved=(Resolve-Path -LiteralPath $dataRoot).ProviderPath.TrimEnd('\','/')
            Assert-R3 ($resolved -ceq $dataRoot -and [IO.Path]::GetDirectoryName($resolved) -ceq $runRoot -and [IO.File]::ReadAllText($marker) -ceq $token) 'Cleanup boundary/owner marker mismatch.'
            foreach ($entry in @(Get-ChildItem -LiteralPath $resolved -Recurse -Force)) { Assert-R3 (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child blocks owned cleanup.' }
            [IO.Directory]::Delete($resolved,$true)
            $report.cleanup_verified=-not (Test-Path -LiteralPath $resolved)
            Assert-R3 $report.cleanup_verified 'Exact owned media/output cleanup failed.'
        }
    } catch { $report.status='FAILED'; $exitCode=1; $report.cleanup_error=$_.Exception.Message.Replace($runRoot,'<OWNED_ROOT>') }
    $report.ended_utc=[DateTime]::UtcNow.ToString('o')
    if (-not (Test-Path -LiteralPath $evidence) -and (Test-Path -LiteralPath $evidenceParent -PathType Container)) { Assert-R3NoReparse $evidenceParent; Write-R3NewText $evidence ($report | ConvertTo-Json -Depth 20) }
}
[pscustomobject]@{status=$report.status;evidence_path=$evidence;evidence_sha256=if (Test-Path -LiteralPath $evidence) {Get-R3Hash $evidence} else {$null};total_converted=$report.total_converted;cleanup_verified=$report.cleanup_verified;error=$report.error} | ConvertTo-Json
exit $exitCode
