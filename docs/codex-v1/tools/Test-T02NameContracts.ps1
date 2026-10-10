<#
T02 short-root real-FFmpeg characterization of proposed name limits 24..180.
Production is copied with only its Music resolver changed. Policy arithmetic is
reported separately and does not claim the baseline enforces these boundaries.
#>
[CmdletBinding()]
param(
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe',
    [Parameter(Mandatory = $true)][string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..')).TrimEnd('\', '/')
$productionScript = Join-Path $projectRoot 'AudioFileForPhone.ps1'
$evidenceParent = Join-Path $projectRoot 'docs\codex-v1\evidence'
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^T02-name-contracts-ps(51|7)\.json$') {
    throw 'EvidencePath must name T02-name-contracts-ps51.json or T02-name-contracts-ps7.json in docs/codex-v1/evidence.'
}
$shortParent = 'C:\Temp'
$testName = 'T02N-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $shortParent $testName
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.t02n-owner'
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$originalPath = $env:PATH
$commands = New-Object 'System.Collections.Generic.List[object]'
$runs = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$rootCreated = $false
$ownerCreated = $false
$exitCode = 1
$report = [ordered]@{
    schema_version = 1
    task = 'T02'
    suite = 'Short-root name-limit characterization'
    started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $shellPath
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.VersionString
    windows_build = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber + '.' + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)
    execution_policy = @(Get-ExecutionPolicy -List | ForEach-Object {
        [pscustomobject]@{ scope = $_.Scope.ToString(); policy = $_.ExecutionPolicy.ToString() }
    })
    production_sha256_before = (Get-FileHash -LiteralPath $productionScript -Algorithm SHA256).Hash.ToLowerInvariant()
    production_sha256_after = $null
    helper_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    ffmpeg_version = $null
    ffprobe_version = $null
    isolated_application_sha256 = $null
    source_before = @()
    source_after = @()
    source_unchanged = $false
    cleanup_verified = $false
    status = 'fail'
    error = $null
    policy_scope = 'Pure proposed v1 contract arithmetic; production enforcement remains T04/T07 and path handling remains later tasks.'
    baseline_validation_gap = 'Source-reviewed only: baseline parameters are unconstrained [int]; no 23/181 conversions or root/UNC acceptance were run.'
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-NoReparse {
    param([string]$Path, [switch]$Tree)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse ancestor refused: $($item.FullName)"
        $item = $item.Parent
    }
    if ($Tree -and (Test-Path -LiteralPath $Path -PathType Container)) {
        $reparse = @(Get-ChildItem -LiteralPath $Path -Recurse -Force | Where-Object {
            ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        })
        Assert-True ($reparse.Count -eq 0) 'Owned test tree contains a reparse point.'
    }
}

function Invoke-Native {
    param([string]$Purpose, [string]$Executable, [string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $output = @(& $Executable @Arguments 2>&1 | ForEach-Object { "$_" })
    $code = $LASTEXITCODE
    $commands.Add([pscustomobject]@{
        purpose = $Purpose; executable = $Executable; arguments = @($Arguments); exit_code = $code
        diagnostic_tail = $(if ($code -ne 0) { @($output | Select-Object -Last 12) } else { @() })
    })
    if ($code -ne 0) { throw "$Purpose exited $code. $($output | Select-Object -Last 12 | Out-String)" }
    return $output
}

function Get-FixtureInventory {
    param([string]$InputRoot)
    return @(Get-ChildItem -LiteralPath $InputRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            relative_path = $_.FullName.Substring($InputRoot.Length).TrimStart('\', '/')
            length = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

function Add-PolicyCheck {
    param([string]$Id, [bool]$Condition, $Observed)
    Assert-True $Condition "Proposed policy arithmetic failed: $Id"
    $checks.Add([pscustomobject]@{ id = $Id; scope = 'pure proposed policy'; status = 'pass'; observed = $Observed })
}

try {
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    foreach ($tool in @(@{ Path = $FfmpegPath; Name = 'ffmpeg.exe' }, @{ Path = $FfprobePath; Name = 'ffprobe.exe' })) {
        Assert-True ([IO.Path]::IsPathRooted($tool.Path) -and (Test-Path -LiteralPath $tool.Path -PathType Leaf)) "Required local tool missing: $($tool.Path)"
        Assert-True ([IO.Path]::GetFileName($tool.Path) -ieq $tool.Name) "Tool must be named $($tool.Name)."
    }
    $FfmpegPath = [IO.Path]::GetFullPath($FfmpegPath)
    $FfprobePath = [IO.Path]::GetFullPath($FfprobePath)
    $report.ffmpeg_version = @(Invoke-Native 'FFmpeg version' $FfmpegPath @('-version'))[0]
    $report.ffprobe_version = @(Invoke-Native 'ffprobe version' $FfprobePath @('-version'))[0]
    if (-not (Test-Path -LiteralPath $shortParent)) {
        Assert-NoReparse (Split-Path -Parent $shortParent)
        New-Item -ItemType Directory -Path $shortParent | Out-Null
    }
    Assert-NoReparse $shortParent
    Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'Unique short test root already exists; refusing reuse.'
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $rootCreated = $true
    $markerStream = [IO.File]::Open($ownerFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $markerBytes = [Text.Encoding]::ASCII.GetBytes($ownerToken)
        $markerStream.Write($markerBytes, 0, $markerBytes.Length)
    }
    finally { $markerStream.Dispose() }
    $ownerCreated = $true
    $inputRoot = Join-Path $testRoot 'i'
    $musicParent = Join-Path $testRoot 'm'
    New-Item -ItemType Directory -Path $inputRoot | Out-Null
    New-Item -ItemType Directory -Path $musicParent | Out-Null
    $scriptCopy = Join-Path $testRoot 'app.ps1'
    $musicExpression = @'
$musicFolder = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::MyMusic,
    [Environment+SpecialFolderOption]::DoNotVerify
)
'@.Replace("`r`n", "`n")
    $sourceText = [IO.File]::ReadAllText($productionScript).Replace("`r`n", "`n")
    Assert-True ([regex]::Matches($sourceText, [regex]::Escape($musicExpression)).Count -eq 1) 'Expected exactly one original Music resolver.'
    $replacement = '$musicFolder = ' + "'" + $musicParent.Replace("'", "''") + "'"
    $copyText = $sourceText.Replace($musicExpression, $replacement)
    Assert-True ($copyText.Replace($replacement, $musicExpression) -ceq $sourceText -and
        $copyText -notmatch '\[Environment\]::GetFolderPath\s*\(') 'Application copy must change only the Music resolver.'
    [IO.File]::WriteAllText($scriptCopy, $copyText, (New-Object Text.UTF8Encoding($true)))
    $report.isolated_application_sha256 = (Get-FileHash -LiteralPath $scriptCopy -Algorithm SHA256).Hash.ToLowerInvariant()
    $env:PATH = (Split-Path -Parent $FfmpegPath) + ';' + (Split-Path -Parent $FfprobePath) + ';' + $originalPath
    $datePrefix = '2024-02-03 - '
    $longStem = $datePrefix + ('A' * 200)
    foreach ($format in @(
        @{ Extension = '.mp3'; Codec = 'libmp3lame' },
        @{ Extension = '.m4a'; Codec = 'aac' },
        @{ Extension = '.ogg'; Codec = 'libvorbis' }
    )) {
        $fixturePath = Join-Path $inputRoot ($longStem + $format.Extension)
        Assert-True ($fixturePath.Length -le 259 -and [IO.Path]::GetFileName($fixturePath).Length -le 255) 'Synthetic fixture must fit legacy Windows path/component bounds.'
        Invoke-Native 'generate 0.4-second colliding fixture' $FfmpegPath @('-hide_banner', '-loglevel', 'error', '-y',
            '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000:duration=0.4', '-c:a', $format.Codec, $fixturePath) | Out-Null
    }
    Assert-NoReparse $testRoot -Tree
    $report.source_before = Get-FixtureInventory $inputRoot
    foreach ($limit in @(24, 180)) {
        $preexistingRoots = @(Get-ChildItem -LiteralPath $musicParent -Directory | Select-Object -ExpandProperty FullName)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (Test-Path -LiteralPath (Join-Path $musicParent ('AudioForPhone_64kbps_' + (Get-Date -Format 'yyyyMMdd_HHmmss')))) {
            Assert-True ($watch.Elapsed.TotalSeconds -lt 5) 'Timed out avoiding timestamp reuse in owned Music.'
            Start-Sleep -Milliseconds 100
        }
        $output = @(Invoke-Native "baseline MaxBaseLength $limit" $shellPath @('-NoLogo', '-NoProfile', '-NonInteractive',
            '-ExecutionPolicy', 'RemoteSigned', '-File', $scriptCopy, '-InputFolder', $inputRoot, '-MaxBaseLength', "$limit"))
        $reportedRoots = @($output | ForEach-Object { if ($_ -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1] } })
        Assert-True ($reportedRoots.Count -eq 1) 'Baseline should report one output root.'
        $outputRoot = [IO.Path]::GetFullPath($reportedRoots[0]).TrimEnd('\', '/')
        Assert-True ((Split-Path -Parent $outputRoot) -ieq $musicParent -and
            (Split-Path -Leaf $outputRoot) -match '^AudioForPhone_64kbps_\d{8}_\d{6}$' -and
            $preexistingRoots -notcontains $outputRoot) 'Reported output must be a fresh timestamp root directly under owned Music.'
        Assert-NoReparse $testRoot -Tree
        $base = Join-Path $outputRoot 'i'
        $files = @(Get-ChildItem -LiteralPath $base -File | Sort-Object Name)
        Assert-True ($files.Count -eq 3) 'Three colliding source formats must create three outputs.'
        $log = Get-Content -LiteralPath (Join-Path $outputRoot 'AudioFileForPhone_log.txt') -Raw
        Assert-True ($log -match 'Summary: total=3, converted=3, failed=0') 'Collision run must report all three conversions successful.'
        $expectedNames = @(
            ($datePrefix + ('A' * ($limit - $datePrefix.Length)) + '.mp3'),
            ($datePrefix + ('A' * ($limit - $datePrefix.Length - 4)) + ' (2).mp3'),
            ($datePrefix + ('A' * ($limit - $datePrefix.Length - 4)) + ' (3).mp3')
        )
        $observations = @()
        foreach ($file in $files) {
            Assert-True ($expectedNames -ccontains $file.Name) 'Collision output name differs from the expected date/title/suffix contract.'
            Assert-True ($file.BaseName.Length -eq $limit -and $file.Name.StartsWith($datePrefix, [StringComparison]::Ordinal)) 'Every collision basename must preserve the date and requested maximum.'
            Assert-True ($file.FullName.Length -le 259 -and $file.Name.Length -le 255) 'Actual output must fit legacy path/component limits.'
            $json = @(Invoke-Native 'probe collision output' $FfprobePath @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $file.FullName)) -join "`n"
            $media = $json | ConvertFrom-Json
            $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
            Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Name-limit conversion must retain the default 64 kbps MP3 audio.'
            $observations += [pscustomobject]@{
                relative_name = $file.Name; basename_length = $file.BaseName.Length; filename_length = $file.Name.Length
                complete_path_length = $file.FullName.Length; parent_directory_length = $file.DirectoryName.Length
                audio_codec = $audio[0].codec_name; audio_bit_rate = [int]$audio[0].bit_rate
            }
        }
        $runs.Add([pscustomobject]@{ max_base_length = $limit; status = 'pass'; exit_code = 0; summary = 'total=3, converted=3, failed=0'; outputs = $observations })
    }
    foreach ($lengthCase in @(
        @{ Length = 23; Accepted = $false }, @{ Length = 24; Accepted = $true },
        @{ Length = 180; Accepted = $true }, @{ Length = 181; Accepted = $false }
    )) {
        $accepted = $lengthCase.Length -ge 24 -and $lengthCase.Length -le 180
        Add-PolicyCheck "name_length_$($lengthCase.Length)" ($accepted -eq $lengthCase.Accepted) ([pscustomobject]@{ length = $lengthCase.Length; accepted = $accepted })
    }
    foreach ($counter in @(9, 10, 9999, 10000)) {
        $suffix = " ($counter)"
        $titleCapacity = 24 - $datePrefix.Length - $suffix.Length
        $allocatedBase = $datePrefix + ('A' * $titleCapacity) + $suffix
        Add-PolicyCheck "suffix_counter_$counter" ($datePrefix.Length -eq 13 -and $titleCapacity -ge 1 -and $allocatedBase.Length -eq 24) ([pscustomobject]@{
            counter = $counter; suffix = $suffix; suffix_length = $suffix.Length
            date_prefix_length = $datePrefix.Length; available_title_characters = $titleCapacity; allocated_basename_length = $allocatedBase.Length
        })
    }
    foreach ($pathCase in @(
        @{ Length = 259; Maximum = 259; Accepted = $true; Kind = 'complete_file_path' },
        @{ Length = 260; Maximum = 259; Accepted = $false; Kind = 'complete_file_path' },
        @{ Length = 247; Maximum = 247; Accepted = $true; Kind = 'directory_path' },
        @{ Length = 248; Maximum = 247; Accepted = $false; Kind = 'directory_path' }
    )) {
        $syntheticString = 'C:\' + ('x' * ($pathCase.Length - 3))
        $accepted = $syntheticString.Length -le $pathCase.Maximum
        Add-PolicyCheck "$($pathCase.Kind)_$($pathCase.Length)" ($syntheticString.Length -eq $pathCase.Length -and $accepted -eq $pathCase.Accepted) ([pscustomobject]@{
            kind = $pathCase.Kind; dotnet_string_length = $syntheticString.Length; maximum = $pathCase.Maximum; accepted = $accepted
            filesystem_operation = 'none; arithmetic only'
        })
    }
    $report.status = 'pass'
    $exitCode = 0
}
catch {
    $report.error = $_.Exception.Message
    Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    try {
        if ($report.source_before.Count -gt 0) {
            $report.source_after = Get-FixtureInventory $inputRoot
            $report.source_unchanged = ((ConvertTo-Json -InputObject @($report.source_before) -Compress) -ceq
                (ConvertTo-Json -InputObject @($report.source_after) -Compress))
            Assert-True $report.source_unchanged 'Generated source relative names/bytes changed.'
        }
        $report.production_sha256_after = (Get-FileHash -LiteralPath $productionScript -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-True ($report.production_sha256_before -ceq $report.production_sha256_after) 'Production script changed during characterization.'
        if ($rootCreated) {
            Assert-True $ownerCreated 'Exclusive ownership marker was not established; preserving the test root.'
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $shortParent -and
                (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Refusing cleanup without the exact short owned boundary and token.'
            Assert-NoReparse $resolved -Tree
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
            Assert-True $report.cleanup_verified 'Owned test root cleanup failed.'
        }
    }
    catch {
        $report.status = 'fail'
        $exitCode = 1
        $report.error = ($report.error + ' ' + $_.Exception.Message).Trim()
        Write-Warning $_.Exception.Message
    }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o')
    $report['runs'] = $runs.ToArray()
    $report['policy_checks'] = $checks.ToArray()
    $report['commands'] = $commands.ToArray()
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    [IO.File]::WriteAllText($evidenceFullPath, (ConvertTo-Json -InputObject $report -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
Write-Host "T02 name contracts: $($report.status); source unchanged=$($report.source_unchanged); cleanup=$($report.cleanup_verified)"
exit $exitCode
