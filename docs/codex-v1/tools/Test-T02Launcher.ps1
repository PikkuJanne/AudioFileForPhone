<#
T02 characterization of the unchanged BAT using an inert capture/exit child.
No application conversion, Music-folder resolution or real Music access occurs.
The BAT chooses its installed shell normally; unexercised branches stay unrun.
#>
[CmdletBinding()]
param([string]$EvidencePath)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).ProviderPath
$productionBat = Join-Path $projectRoot 'AudioFileForPhone.bat'
$evidenceParent = Join-Path $projectRoot 'docs\codex-v1\evidence'
if ([string]::IsNullOrWhiteSpace($EvidencePath)) {
    $EvidencePath = Join-Path $evidenceParent 'T02-launcher.json'
}
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ($evidenceFullPath -ine (Join-Path $evidenceParent 'T02-launcher.json')) {
    throw 'EvidencePath must be docs/codex-v1/evidence/T02-launcher.json.'
}
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T02Launcher-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.t02-launcher-owner'
$cmdPath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'cmd.exe'
$evidenceApproved = $false
$cases = New-Object 'System.Collections.Generic.List[object]'
$report = [ordered]@{
    schema_version = 1
    task = 'T02'
    scope = 'B12 unchanged BAT plus inert PowerShell capture/exit stub; no audio conversion'
    started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    helper_shell = $PSVersionTable.PSVersion.ToString()
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    production_bat_sha256_before = (Get-FileHash -LiteralPath $productionBat -Algorithm SHA256).Hash.ToLowerInvariant()
    production_bat_sha256_after = $null
    copied_bat_byte_identical = $false
    cases = @()
    exercised_shells = @()
    fallback_ps51_branch = 'not_run'
    metacharacters_beyond_spaces = 'not_run; future T10'
    music_resolver_or_media_access = $false
    cleanup_verified = $false
    status = 'fail'
    error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse path refused: $($item.FullName)"
        $item = $item.Parent
    }
}

$stub = @'
[CmdletBinding()]
param([string]$InputFolder, [switch]$Interactive)
$ErrorActionPreference = 'Stop'
$capture = [IO.Path]::GetFullPath($env:AUDIOPHONE_T02_CAPTURE)
$ownedRoot = [IO.Path]::GetFullPath($env:AUDIOPHONE_T02_ROOT).TrimEnd('\', '/')
if ((Split-Path -Parent $capture) -ine $ownedRoot -or
    (Split-Path -Leaf $capture) -notmatch '^capture-[a-z0-9-]+\.json$' -or
    [IO.File]::ReadAllText((Join-Path $ownedRoot '.t02-launcher-owner')) -cne $env:AUDIOPHONE_T02_TOKEN) {
    throw 'Capture destination must belong to the launcher fixture.'
}
$record = [ordered]@{
    input_folder = $InputFolder
    interactive = [bool]$Interactive
    extra_arguments = @($args | Where-Object { $null -ne $_ })
    shell_version = $PSVersionTable.PSVersion.ToString()
    shell_edition = $PSVersionTable.PSEdition
    apartment_state = [Threading.Thread]::CurrentThread.ApartmentState.ToString()
    requested_exit = [int]$env:AUDIOPHONE_T02_EXIT
}
$bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($record | ConvertTo-Json -Depth 5))
$stream = [IO.File]::Open($capture, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
exit ([int]$env:AUDIOPHONE_T02_EXIT)
'@

try {
    Assert-NoReparse $tempParent
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    $evidenceApproved = $true
    Assert-True ($testRoot -notmatch '[%!"&|<>^]') 'This fixture excludes cmd metacharacters beyond spaces.'
    Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'Unique launcher root already exists; refusing reuse.'
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    [IO.File]::WriteAllText($ownerFile, $ownerToken)
    $batCopy = Join-Path $testRoot 'AudioFileForPhone.bat'
    Copy-Item -LiteralPath $productionBat -Destination $batCopy
    $report.copied_bat_byte_identical = ((Get-FileHash -LiteralPath $batCopy -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $report.production_bat_sha256_before)
    Assert-True $report.copied_bat_byte_identical 'Launcher copy must be byte-identical to production.'
    [IO.File]::WriteAllText((Join-Path $testRoot 'AudioFileForPhone.ps1'), $stub, (New-Object Text.UTF8Encoding($true)))
    $firstFolder = Join-Path $testRoot 'First folder with spaces'
    $secondFolder = Join-Path $testRoot 'Second folder with spaces'
    [IO.Directory]::CreateDirectory($firstFolder) | Out-Null
    [IO.Directory]::CreateDirectory($secondFolder) | Out-Null
    $caseDefinitions = @(
        @{ name = 'no-argument'; child_exit = 0; folders = @() },
        @{ name = 'one-folder-exit-0'; child_exit = 0; folders = @($firstFolder) },
        @{ name = 'one-folder-exit-1'; child_exit = 1; folders = @($firstFolder) },
        @{ name = 'one-folder-exit-2'; child_exit = 2; folders = @($firstFolder) },
        @{ name = 'multiple-folders'; child_exit = 0; folders = @($firstFolder, $secondFolder) }
    )
    foreach ($case in $caseDefinitions) {
        $capturePath = Join-Path $testRoot ('capture-' + $case.name + '.json')
        $commandText = '"' + $batCopy + '"'
        foreach ($folder in $case.folders) { $commandText += ' "' + $folder + '"' }
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $cmdPath
        $startInfo.Arguments = '/d /c "' + $commandText + '"'
        $startInfo.WorkingDirectory = $testRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.EnvironmentVariables['AUDIOPHONE_T02_CAPTURE'] = $capturePath
        $startInfo.EnvironmentVariables['AUDIOPHONE_T02_ROOT'] = $testRoot
        $startInfo.EnvironmentVariables['AUDIOPHONE_T02_TOKEN'] = $ownerToken
        $startInfo.EnvironmentVariables['AUDIOPHONE_T02_EXIT'] = [string]$case.child_exit
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $startInfo
        try {
            Assert-True ($process.Start()) 'cmd fixture did not start.'
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $process.StandardInput.WriteLine('')
            $process.StandardInput.Close()
            if (-not $process.WaitForExit(30000)) {
                $process.Kill()
                $process.WaitForExit()
                throw 'Inert launcher child exceeded 30 seconds; stopped this owned cmd process.'
            }
            $exitCode = $process.ExitCode
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
        }
        finally { $process.Dispose() }
        $capture = $null
        if (Test-Path -LiteralPath $capturePath) {
            $capture = Get-Content -LiteralPath $capturePath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        $doneMessage = $stdout.Contains('Done. Check the new')
        if ($case.folders.Count -eq 0) {
            Assert-True ($exitCode -eq 1 -and $null -eq $capture) 'Zero arguments must exit 1 without launching PowerShell.'
        }
        else {
            Assert-True ($null -ne $capture) "Capture child did not run for $($case.name): $stderr"
            Assert-True ($capture.input_folder -ceq $firstFolder -and $capture.interactive -and @($capture.extra_arguments).Count -eq 0) ("BAT forwarding differs: " + ($capture | ConvertTo-Json -Depth 5 -Compress))
            Assert-True ($capture.requested_exit -eq $case.child_exit -and $capture.apartment_state -eq 'STA') 'Capture stub must use the requested child exit and STA.'
        }
        $gap = ($case.folders.Count -gt 1) -or
            ($case.folders.Count -gt 0 -and $case.child_exit -ne 0 -and ($doneMessage -or $exitCode -ne $case.child_exit))
        $cases.Add([pscustomobject]@{
            name = $case.name
            supplied_folder_count = $case.folders.Count
            requested_child_exit = $case.child_exit
            bat_exit = $exitCode
            unconditional_done_displayed = $doneMessage
            status = $(if ($gap) { 'observed_gap' } else { 'observed_behavior' })
            capture = $capture
            stdout = $stdout.Trim()
            stderr = $stderr.Trim()
            cmd_arguments = $startInfo.Arguments
        })
    }
    $report.cases = $cases.ToArray()
    $report.exercised_shells = @($cases | Where-Object { $null -ne $_.capture } | ForEach-Object {
        $_.capture.shell_edition + ' ' + $_.capture.shell_version
    } | Sort-Object -Unique)
    if (@($cases | Where-Object { $null -ne $_.capture -and $_.capture.shell_edition -eq 'Desktop' }).Count -gt 0) {
        $report.fallback_ps51_branch = 'observed'
    }
    $report.status = 'pass'
    $report['interpretation'] = 'characterization completed; observed gaps remain unfixed'
}
catch {
    $report.error = $_.Exception.Message
    Write-Warning $report.error
}
finally {
    $report.production_bat_sha256_after = (Get-FileHash -LiteralPath $productionBat -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($report.production_bat_sha256_after -cne $report.production_bat_sha256_before) {
        $report.status = 'fail'
        $report.error = 'Production BAT bytes changed.'
    }
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
        Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and
            (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Refusing cleanup outside the exact owned launcher root.'
        Assert-NoReparse $resolved
        $reparse = @(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object {
            ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        })
        Assert-True ($reparse.Count -eq 0) 'Refusing cleanup of a launcher tree containing reparse points.'
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
    }
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    if ($evidenceApproved) {
        Assert-NoReparse $evidenceParent
        if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
        $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $evidenceFullPath -Encoding UTF8
    }
}
if ($report.status -like 'pass*') {
    Write-Host 'T02 launcher characterization completed; known gaps were observed, not fixed.'
    exit 0
}
exit 1
