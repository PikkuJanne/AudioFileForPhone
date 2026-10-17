<#
T19 packaging-policy tests. All builds use a marker-owned, synthetic local Git
repository containing exact application/build bytes plus deliberate exclusions.
External FFmpeg identity/capability is checked; no conversion or Music lookup runs.
This is packaging-policy evidence, not frozen-candidate or release acceptance.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$evidenceParent = Join-Path $projectRoot 'docs\codex-v1\evidence'
$evidence = [IO.Path]::GetFullPath($EvidencePath)
$shellLabel = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
if (-not [IO.Path]::GetDirectoryName($evidence).Equals($evidenceParent, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($evidence) -notmatch ('^(T19|T17)-package-' + $shellLabel + '-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$')) {
    throw 'Package evidence must use a fresh T19/T17-package-<actual shell>-attemptN/finalN/runN_N JSON directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidence) { throw 'Package evidence already exists; choose a fresh label.' }
$required = @('AudioFileForPhone.bat', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat',
    'CHANGELOG.md', 'LICENSE', 'README.md', 'SECURITY.md', 'SUPPORT.md')
[Array]::Sort($required, [StringComparer]::Ordinal)
$buildFiles = @('tools/Build-Package.ps1', 'tools/package-files.json')
$sourceFiles = $required + $buildFiles + @('tests/Test-Package.ps1', '.github/dependencies.json')
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$rootName = 'T19P-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$root = Join-Path $tempParent $rootName
$marker = Join-Path $root '.owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$fixtureRoot = Join-Path $root 'source'
$buildParent = Join-Path $root 'builds'
$dependencyInput = Join-Path $root 'dependencies.json'
$testInput = Join-Path $root 'tests.json'
$rootCreated = $false
$childrenReleased = $true
$junctions = New-Object 'Collections.Generic.List[string]'
$shellPath = Join-Path $PSHOME $(if ($shellLabel -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$gitPath = (Get-Command git.exe -ErrorAction Stop).Source
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = [IO.Path]::GetFileName($evidence).Substring(0, 3)
    mode = 'synthetic_clean_commit_packaging_policy'; status = 'fail'; error = $null
    started_utc = [DateTime]::UtcNow.ToString('o'); ended_utc = $null
    shell = [string]$PSVersionTable.PSVersion; shell_edition = [string]$PSVersionTable.PSEdition
    os = [string][Environment]::OSVersion.Version; windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = $null; synthetic_source_commit = $null
    command = $null; owned_temp_root = '<OWNED_TEMP>'; temp_exclusively_reserved = $false
    owned_temp_name = $rootName; temp_parent_kind = 'process_temporary_directory'
    marker_create_new = $false; ownership_marker_sha256 = $null
    source_before = @(); source_after = @(); source_unchanged = $false
    fixture_before = @(); fixture_after = @(); synthetic_unchanged = $false
    dependencies = @(); native_runs = @(); cases = @(); artifacts = @()
    ordinary_music_access = $false; media_conversion = $false; physical_manual_evidence = $false
    release_candidate_acceptance = $false; descendant_release_proved = $false; cleanup_verified = $false
}

function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Protect-Text {
    param([string]$Text)
    foreach ($replacement in @(@($root, '<OWNED_TEMP>'), @($projectRoot, '<REPOSITORY>'),
        @($PSHOME, '<SHELL_ROOT>'), @([Environment]::GetFolderPath('UserProfile'), '<USER_PROFILE>'))) {
        if (-not [string]::IsNullOrEmpty($replacement[0])) {
            $Text = $Text.Replace($replacement[0].Replace('\', '\\'), $replacement[1])
            $Text = $Text.Replace($replacement[0].Replace('\', '/'), $replacement[1])
            $Text = $Text.Replace($replacement[0], $replacement[1])
        }
    }
    return $Text
}
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            Assert-True (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse point found in an owned test path or ancestor.'
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-SafeTree {
    param([string]$Path)
    Assert-NoReparse $Path
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $items = New-Object 'Collections.Generic.List[object]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse point found inside owned cleanup tree.'
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Get-Hash { param([string]$Path); return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string]$Base, [string[]]$Names)
    return @($Names | ForEach-Object { [pscustomobject][ordered]@{ relative_path = $_; sha256 = (Get-Hash (Join-Path $Base $_)); bytes = (Get-Item -LiteralPath (Join-Path $Base $_)).Length } })
}
function Invoke-Case {
    param([string]$CaseName, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $CaseName; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
$deadlineSource = @'
using System;
using System.Threading;
namespace T19Support {
    public sealed class Deadline : IDisposable {
        private readonly Timer timer; private int timedOut;
        public bool TimedOut { get { return Interlocked.CompareExchange(ref timedOut,0,0)!=0; } }
        public Deadline(object context,int milliseconds) {
            timer=new Timer(o=>{Interlocked.Exchange(ref timedOut,1);context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@
function Invoke-OwnedNative {
    param([string]$Executable, [string[]]$NativeArguments, [switch]$AllowFailure)
    $context = New-AudioCancellationContext
    $deadline = New-Object T19Support.Deadline($context, 180000)
    try {
        $native = Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $NativeArguments -Cancellation $context -MaxStdoutChars 1048576 -MaxStderrChars 1048576
        $script:childrenReleased = $script:childrenReleased -and $native.ProcessReleased
        $report.native_runs += [pscustomobject][ordered]@{
            executable = [IO.Path]::GetFileName($Executable)
            arguments = @($NativeArguments | ForEach-Object { Protect-Text $_ })
            status = $native.Status; exit_code = $native.ExitCode; process_released = $native.ProcessReleased
            deadline_requested = $deadline.TimedOut; duration_ms = $native.DurationMilliseconds
            stdout = (Protect-Text $native.Stdout); stderr = (Protect-Text $native.Stderr)
        }
        Assert-True (-not $deadline.TimedOut -and $native.Status -ceq 'Completed' -and $native.ProcessReleased -and -not $native.StdoutTruncated -and -not $native.StderrTruncated) 'Owned native completion/drain/release failed.'
        if (-not $AllowFailure) { Assert-True ($native.ExitCode -eq 0) ('Owned native command failed: ' + (Protect-Text $native.Stderr)) }
        return $native
    } finally { $deadline.Dispose(); $context.Dispose() }
}
function Invoke-FixtureGit { param([string[]]$GitArguments); return (Invoke-OwnedNative $gitPath (@('-C', $fixtureRoot) + $GitArguments)).Stdout.Trim() }
function Get-FixtureGitConfig {
    return [pscustomobject][ordered]@{
        core_autocrlf = (Invoke-FixtureGit @('config', '--local', '--get', 'core.autocrlf'))
        core_eol = (Invoke-FixtureGit @('config', '--local', '--get', 'core.eol'))
    }
}
function Commit-Fixture {
    param([string]$Message)
    Invoke-FixtureGit @('add', '--all') | Out-Null
    Invoke-FixtureGit @('-c', 'user.name=T19 synthetic fixture', '-c', 'user.email=t19@example.invalid', 'commit', '-m', $Message) | Out-Null
    $commit = Invoke-FixtureGit @('rev-parse', 'HEAD')
    Invoke-FixtureGit @('checkout', '--detach', $commit) | Out-Null
    return $commit
}
function Restore-Fixture { Invoke-FixtureGit @('checkout', '--detach', $report.synthetic_source_commit) | Out-Null }
function Get-OutputInventory {
    param([string]$Directory)
    return @(Get-SafeTree $Directory | Where-Object { -not $_.PSIsContainer } | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.FullName.Substring($Directory.Length + 1); sha256 = (Get-Hash $_.FullName); bytes = $_.Length }
    })
}
function Get-OutputTree {
    param([string]$Directory)
    return @(Get-SafeTree $Directory | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.FullName.Substring($Directory.Length + 1)
            kind = $(if ($_.PSIsContainer) { 'directory' } else { 'file' })
            sha256 = $(if ($_.PSIsContainer) { $null } else { Get-Hash $_.FullName })
            bytes = $(if ($_.PSIsContainer) { $null } else { $_.Length }) }
    })
}
function Set-TestInput {
    param([string]$Commit)
    $fixtureEvidencePath = Join-Path $root 'fixture-copy-policy.json'
    $fixtureEvidence = [ordered]@{ schema_version = 1; status = 'pass'; tested_commit = $Commit; scope = 'Synthetic byte-copy identity only; no release, runtime, device or publication acceptance.' }
    [IO.File]::WriteAllText($fixtureEvidencePath, ($fixtureEvidence | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    $inputRecord = [ordered]@{ schema_version = 1; tests = @([ordered]@{ reference = 'synthetic/fixture-copy-policy.json'; tested_commit = $Commit; sha256 = (Get-Hash $fixtureEvidencePath); status = 'pass' }) }
    [IO.File]::WriteAllText($testInput, ($inputRecord | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
}
function Invoke-Build {
    param([string]$Destination, [string]$Commit = $report.synthetic_source_commit,
        [string]$Source = $fixtureRoot, [string]$Tag = ('v' + (Get-AudioAppVersion)),
        [string]$Dependencies = $dependencyInput, [string]$Tests = $testInput)
    return Invoke-OwnedNative $shellPath @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
        '-File', (Join-Path $fixtureRoot 'tools\Build-Package.ps1'), '-SourcePath', $Source, '-SourceCommit', $Commit,
        '-TargetTag', $Tag, '-OutputDirectory', $Destination, '-DependencyProvenancePath', $Dependencies, '-TestEvidencePath', $Tests) -AllowFailure
}
function Assert-RejectedBuild {
    param([string]$Name, [string]$Commit = $report.synthetic_source_commit,
        [string]$Source = $fixtureRoot, [string]$Tag = ('v' + (Get-AudioAppVersion)),
        [string]$Dependencies = $dependencyInput, [string]$Tests = $testInput, [string]$Destination = '')
    if ([string]::IsNullOrEmpty($Destination)) { $Destination = Join-Path $buildParent $Name }
    $before = Get-OutputTree $buildParent
    $native = Invoke-Build -Destination $Destination -Commit $Commit -Source $Source -Tag $Tag -Dependencies $Dependencies -Tests $Tests
    Assert-True ($native.ExitCode -ne 0) ('Unsafe package build accepted: ' + $Name)
    $after = Get-OutputTree $buildParent
    Assert-True (($before | ConvertTo-Json -Depth 8 -Compress) -ceq ($after | ConvertTo-Json -Depth 8 -Compress)) ('Rejected build changed existing output bytes: ' + $Name)
    Assert-True (-not (Test-Path -LiteralPath $Destination)) ('Rejected build left a final output directory: ' + $Name)
    return $native
}
function Read-ZipInventory {
    param([string]$Path)
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        return @($archive.Entries | ForEach-Object {
            Assert-True ($_.FullName -cmatch '^[A-Za-z0-9._-]+$' -and -not $_.FullName.EndsWith('/') -and $_.FullName -cne '.' -and $_.FullName -cne '..') 'ZIP entry must be a safe root filename.'
            Assert-True (($_.ExternalAttributes -band 1024) -eq 0 -and ($_.ExternalAttributes -band -268435456) -ne -1610612736) 'ZIP entry cannot be a reparse point or symlink.'
            Assert-True ($_.LastWriteTime.Year -eq 1980 -and $_.LastWriteTime.Month -eq 1 -and $_.LastWriteTime.Day -eq 1 -and $_.LastWriteTime.Hour -eq 0 -and $_.LastWriteTime.Minute -eq 0 -and $_.LastWriteTime.Second -eq 0) 'ZIP timestamps must use the deterministic epoch.'
            $stream = $_.Open(); $hasher = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() } finally { $hasher.Dispose(); $stream.Dispose() }
            [pscustomobject][ordered]@{ relative_path = $_.FullName; sha256 = $hash; bytes = $_.Length }
        })
    } finally { $archive.Dispose() }
}

$oldAuthorDate = [Environment]::GetEnvironmentVariable('GIT_AUTHOR_DATE', 'Process')
$oldCommitterDate = [Environment]::GetEnvironmentVariable('GIT_COMMITTER_DATE', 'Process')
try {
    Assert-NoReparse $evidenceParent
    Assert-NoReparse $tempParent
    Assert-True (-not (Test-Path -LiteralPath $root)) 'Owned temporary root must be fresh.'
    [void](New-Item -Path $root -ItemType Directory)
    $rootCreated = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $marker $ownerToken
    $report.marker_create_new = $true; $report.ownership_marker_sha256 = Get-Hash $marker
    [void](New-Item -Path $fixtureRoot -ItemType Directory)
    [void](New-Item -Path $buildParent -ItemType Directory)
    [void](New-Item -Path (Join-Path $fixtureRoot 'tools') -ItemType Directory)
    $report.command = Protect-Text ([Environment]::CommandLine)
    $report.source_before = Get-Inventory $projectRoot $sourceFiles
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Add-Type -TypeDefinition $deadlineSource
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $report.tested_commit = (Invoke-OwnedNative $gitPath @('-C', $projectRoot, 'rev-parse', 'HEAD')).Stdout.Trim()
    Assert-True ($report.tested_commit -cmatch '^[a-f0-9]{40}$') 'Actual test checkout commit must be a full SHA.'
    foreach ($name in $required + $buildFiles) { [IO.File]::Copy((Join-Path $projectRoot $name), (Join-Path $fixtureRoot $name), $false) }
    $report.fixture_before = Get-Inventory $fixtureRoot ($required + $buildFiles)
    Invoke-Case 'fixture preserves exact copied source bytes before owned README LF setup' 'A47,A48' {
        param($case)
        foreach ($entry in $report.fixture_before) {
            $source = @($report.source_before | Where-Object { $_.relative_path -ceq $entry.relative_path })
            Assert-True ($source.Count -eq 1 -and $source[0].sha256 -ceq $entry.sha256 -and $source[0].bytes -eq $entry.bytes) 'Fixture copy must preserve exact source bytes.'
        }
        $case['copied_files'] = $report.fixture_before
        $ownedReadmePath = Join-Path $fixtureRoot 'README.md'
        $sourceReadmePath = Join-Path $projectRoot 'README.md'
        $readmeBefore = @(Get-Inventory $fixtureRoot @('README.md'))[0]
        $readmeBytes = [IO.File]::ReadAllBytes($ownedReadmePath)
        $lfReadmeBytes = New-Object 'Collections.Generic.List[byte]'
        $removedCrCount = 0; $loneCrBefore = 0
        for ($readmeByteIndex = 0; $readmeByteIndex -lt $readmeBytes.Length; $readmeByteIndex++) {
            if ($readmeBytes[$readmeByteIndex] -eq 13) {
                if ($readmeByteIndex + 1 -lt $readmeBytes.Length -and $readmeBytes[$readmeByteIndex + 1] -eq 10) {
                    $removedCrCount++
                    continue
                }
                $loneCrBefore++
            }
            $lfReadmeBytes.Add($readmeBytes[$readmeByteIndex])
        }
        [IO.File]::WriteAllBytes($ownedReadmePath, $lfReadmeBytes.ToArray())
        $readmeAfter = @(Get-Inventory $fixtureRoot @('README.md'))[0]
        $writtenReadmeBytes = [IO.File]::ReadAllBytes($ownedReadmePath)
        $bomBefore = $readmeBytes.Length -ge 3 -and $readmeBytes[0] -eq 239 -and $readmeBytes[1] -eq 187 -and $readmeBytes[2] -eq 191
        $bomAfter = $writtenReadmeBytes.Length -ge 3 -and $writtenReadmeBytes[0] -eq 239 -and $writtenReadmeBytes[1] -eq 187 -and $writtenReadmeBytes[2] -eq 191
        $loneCrAfter = 0
        for ($readmeByteIndex = 0; $readmeByteIndex -lt $writtenReadmeBytes.Length; $readmeByteIndex++) {
            if ($writtenReadmeBytes[$readmeByteIndex] -eq 13 -and ($readmeByteIndex + 1 -ge $writtenReadmeBytes.Length -or $writtenReadmeBytes[$readmeByteIndex + 1] -ne 10)) { $loneCrAfter++ }
        }
        $case['readme_normalization'] = [ordered]@{
            relative_path = 'README.md'
            policy = 'Owned README fixture only: remove CR byte only immediately before LF; preserve all other bytes, including UTF-8 BOM, existing LF and lone CR.'
            before = $readmeBefore; after = $readmeAfter; crlf_pairs_removed = $removedCrCount
            utf8_bom_before = $bomBefore; utf8_bom_after = $bomAfter; bom_preserved = ($bomBefore -eq $bomAfter)
            lone_cr_before = $loneCrBefore; lone_cr_after = $loneCrAfter; lone_cr_preserved = ($loneCrBefore -eq $loneCrAfter)
            source_readme_sha256 = Get-Hash $sourceReadmePath
            source_readme_unchanged = ((Get-Hash $sourceReadmePath) -ceq $readmeBefore.sha256)
        }
        Assert-True ($readmeAfter.bytes -eq $readmeBefore.bytes - $removedCrCount -and [BitConverter]::ToString($writtenReadmeBytes) -ceq [BitConverter]::ToString($lfReadmeBytes.ToArray())) 'Owned README setup must write only the specified byte transformation.'
        Assert-True ($case.readme_normalization.bom_preserved -and $case.readme_normalization.lone_cr_preserved) 'Owned README setup must preserve BOM and lone CR bytes.'
        Assert-True $case.readme_normalization.source_readme_unchanged 'Owned README setup must leave production README bytes unchanged.'
        $report.fixture_before = Get-Inventory $fixtureRoot ($required + $buildFiles)
    }
    [Environment]::SetEnvironmentVariable('GIT_AUTHOR_DATE', '2000-01-01T00:00:00Z', 'Process')
    [Environment]::SetEnvironmentVariable('GIT_COMMITTER_DATE', '2000-01-01T00:00:00Z', 'Process')
    Invoke-FixtureGit @('init', '--quiet') | Out-Null
    Invoke-FixtureGit @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-FixtureGit @('config', 'core.eol', 'lf') | Out-Null
    Invoke-FixtureGit @('config', 'core.symlinks', 'false') | Out-Null
    $excluded = @('ffmpeg.exe', 'ffprobe.exe', 'private.mp3', 'private.m4a', 'private.ogg', 'private.log',
        'AudioFileForPhone_poster.png', 'cache/temp.txt', 'tests/fixture.txt', 'docs/codex-v1/private-evidence.json')
    foreach ($name in $excluded) {
        $path = Join-Path $fixtureRoot $name; $parent = [IO.Path]::GetDirectoryName($path)
        if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -Path $parent -ItemType Directory -Force) }
        Write-NewText $path 'SYNTHETIC EXCLUSION MARKER; no personal content or executable binary.'
    }
    Write-NewText (Join-Path $fixtureRoot '.gitignore') "ignored-fixture.log`n"
    $report.synthetic_source_commit = Commit-Fixture 'T19 deterministic synthetic package fixture'
    Set-TestInput $report.synthetic_source_commit
    $lock = Get-Content -LiteralPath (Join-Path $projectRoot '.github\dependencies.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $dependencies = [ordered]@{ schema_version = 1 }
    foreach ($kind in @('ffmpeg', 'ffprobe')) {
        $toolPath = [IO.Path]::GetFullPath($(if ($kind -ceq 'ffmpeg') { $FfmpegPath } else { $FfprobePath }))
        Assert-NoReparse $toolPath
        $hash = Get-Hash $toolPath
        $pin = if ($kind -ceq 'ffmpeg') { $lock.ffmpeg.ffmpeg_sha256 } else { $lock.ffmpeg.ffprobe_sha256 }
        Assert-True ($hash -ceq $pin) 'Packaging tests require the retained CI-pinned external FFmpeg/ffprobe build for accurate vendor provenance.'
        $versionResult = Invoke-OwnedNative $toolPath @('-version')
        $versionLine = @($versionResult.Stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[0]
        $dependencies[$kind] = [ordered]@{ path = $toolPath; version = $versionLine; sha256 = $hash
            source_url = $lock.ffmpeg.archive_url
            license_notice = 'External Gyan essentials build; its own GPLv3 license/provenance applies. These binaries are not redistributed in this package.' }
        $report.dependencies += [pscustomobject]@{ tool = $kind; version = $versionLine; sha256 = $hash; source_url = $lock.ffmpeg.archive_url; bundled = $false }
    }
    Write-NewText $dependencyInput ($dependencies | ConvertTo-Json -Depth 8)
    $first = Join-Path $buildParent 'first'
    Invoke-Case 'Git CRLF archive policy preserves exact blob package bytes' 'A47,A48' {
        param($case)
        $case['original_config'] = Get-FixtureGitConfig
        Assert-True ($case.original_config.core_autocrlf -ceq 'false' -and $case.original_config.core_eol -ceq 'lf') 'Original fixture Git configuration must be explicit false/lf.'
        $case['lf_fixture_members'] = @(foreach ($lfCandidate in $required + $buildFiles) {
            $fixtureBytes = [IO.File]::ReadAllBytes((Join-Path $fixtureRoot $lfCandidate))
            for ($lfByteIndex = 0; $lfByteIndex -lt $fixtureBytes.Length; $lfByteIndex++) {
                if ($fixtureBytes[$lfByteIndex] -eq 10 -and ($lfByteIndex -eq 0 -or $fixtureBytes[$lfByteIndex - 1] -ne 13)) {
                    $lfCandidate
                    break
                }
            }
        })
        Assert-True ($case.lf_fixture_members -ccontains 'README.md') 'CRLF archive regression must contain the deliberately prepared LF README fixture.'
        try {
            Invoke-FixtureGit @('config', 'core.autocrlf', 'true') | Out-Null
            Invoke-FixtureGit @('config', 'core.eol', 'crlf') | Out-Null
            $case['build_config'] = Get-FixtureGitConfig
            Assert-True ($case.build_config.core_autocrlf -ceq 'true' -and $case.build_config.core_eol -ceq 'crlf') 'Regression must actually build under true/crlf.'
            $case['clean_source'] = (Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')).Length -eq 0
            Assert-True $case.clean_source 'CRLF configuration must retain clean fixture source.'
            $native = Invoke-Build $first
            Assert-True ($native.ExitCode -eq 0) ('CRLF-configured package build failed: ' + (Protect-Text $native.Stderr))
            $zipName = 'AudioFileForPhone-v' + (Get-AudioAppVersion) + '.zip'
            $inventory = Read-ZipInventory (Join-Path $first $zipName)
            Assert-True (($inventory.relative_path -join '|') -ceq ($required -join '|')) 'CRLF build requires the exact independent root inventory.'
            foreach ($entry in $inventory) {
                $blob = @($report.fixture_before | Where-Object { $_.relative_path -ceq $entry.relative_path })[0]
                Assert-True ($entry.sha256 -ceq $blob.sha256 -and $entry.bytes -eq $blob.bytes) 'CRLF Git policy must not transform committed member bytes.'
            }
            $case['config_after_build'] = Get-FixtureGitConfig
            $case['configuration_unchanged'] = (($case.config_after_build | ConvertTo-Json -Compress) -ceq ($case.build_config | ConvertTo-Json -Compress))
            Assert-True $case.configuration_unchanged 'Builder overrides must not mutate fixture configuration.'
            $case['fixture_unchanged'] = (((Get-Inventory $fixtureRoot ($required + $buildFiles)) | ConvertTo-Json -Depth 8 -Compress) -ceq ($report.fixture_before | ConvertTo-Json -Depth 8 -Compress))
            Assert-True $case.fixture_unchanged 'CRLF build must preserve actual source checkout bytes.'
            $case['source_commit'] = $report.synthetic_source_commit
            $case['zip_inventory'] = $inventory
        } finally {
            Invoke-FixtureGit @('config', 'core.autocrlf', 'false') | Out-Null
            Invoke-FixtureGit @('config', 'core.eol', 'lf') | Out-Null
            $case['restored_config'] = Get-FixtureGitConfig
            $case['configuration_restored'] = (($case.restored_config | ConvertTo-Json -Compress) -ceq ($case.original_config | ConvertTo-Json -Compress))
            Assert-True $case.configuration_restored 'Owned fixture configuration must be restored.'
        }
    }
    Invoke-Case 'explicit distributable allowlist excludes committed binary/media/log/cache/poster/evidence fixtures' 'A47,A48' {
        param($case)
        $zipName = 'AudioFileForPhone-v' + (Get-AudioAppVersion) + '.zip'
        $inventory = Read-ZipInventory (Join-Path $first $zipName)
        Assert-True (($inventory.relative_path -join '|') -ceq ($required -join '|')) 'ZIP must have exactly the independent required inventory in ordinal order.'
        foreach ($entry in $inventory) {
            $source = @($report.fixture_before | Where-Object { $_.relative_path -ceq $entry.relative_path })[0]
            Assert-True ($entry.sha256 -ceq $source.sha256 -and $entry.bytes -eq $source.bytes) 'ZIP member bytes must exactly match source Git payload.'
        }
        $report.artifacts = Get-OutputInventory $first
        Assert-True (($report.artifacts.relative_path -join '|') -ceq (($zipName, 'release-manifest.json', 'SHA256SUMS.txt' | Sort-Object) -join '|')) 'Only the three external package assets may be published.'
        $case['source_commit'] = $report.synthetic_source_commit; $case['inventory'] = $inventory; $case['excluded_fixtures'] = $excluded
    }
    Invoke-Case 'external manifest binds actual version commit per-member hashes signing and tool provenance without checksum self-reference' 'A47,A48' {
        param($case)
        $manifestPath = Join-Path $first 'release-manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True ($manifest.schema_version -eq 1 -and $manifest.repository -ceq 'PikkuJanne/AudioFileForPhone' -and $manifest.app_version -ceq (Get-AudioAppVersion) -and $manifest.tag -ceq ('v' + (Get-AudioAppVersion)) -and $manifest.release_commit -ceq $report.synthetic_source_commit) 'Manifest must bind exact source C and the runtime helper version.'
        Assert-True ($manifest.zip.sha256 -ceq (Get-Hash (Join-Path $first $manifest.zip.name))) 'Manifest ZIP digest must match actual bytes.'
        Assert-True (($manifest.files.PSObject.Properties.Name -join '|') -ceq ($required -join '|')) 'Manifest member inventory must exactly equal the ZIP allowlist.'
        foreach ($entry in $report.fixture_before | Where-Object { $required -ccontains $_.relative_path }) {
            Assert-True ($manifest.files.($entry.relative_path) -ceq $entry.sha256) 'Manifest member SHA-256 must match actual source and ZIP bytes.'
            Assert-True ($manifest.file_bytes.($entry.relative_path) -eq $entry.bytes) 'Manifest member size must match actual source and ZIP bytes.'
        }
        Assert-True ($manifest.signing_status -ceq 'unsigned') 'This actual unsigned source must be reported as unsigned.'
        foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) {
            $signature = Get-AuthenticodeSignature -LiteralPath (Join-Path $fixtureRoot $name)
            Assert-True ($manifest.signatures.$name.status -ceq [string]$signature.Status -and $null -eq $manifest.signatures.$name.signer_thumbprint) 'Manifest must reflect actual unsigned script signature state.'
        }
        Assert-True ($manifest.dependencies.bundled -eq $false) 'Dependency provenance must state tools remain external.'
        foreach ($dependency in $report.dependencies) {
            $actual = $manifest.dependencies.($dependency.tool)
            Assert-True ($actual.sha256 -ceq $dependency.sha256 -and $actual.version -ceq $dependency.version -and $actual.source_url -ceq $dependency.source_url -and $actual.executable_name -ceq ($dependency.tool + '.exe')) 'Manifest dependency identity must match actually queried external executables.'
        }
        Assert-True ($manifest.build.source_mode -ceq 'clean_detached_exact_git_blobs' -and
            $manifest.build.builder_sha256 -ceq (Get-Hash (Join-Path $fixtureRoot 'tools\Build-Package.ps1')) -and
            $manifest.build.allowlist_sha256 -ceq (Get-Hash (Join-Path $fixtureRoot 'tools\package-files.json')) -and
            $manifest.build.powershell_version -ceq [string]$PSVersionTable.PSVersion -and
            $manifest.build.powershell_edition -ceq [string]$PSVersionTable.PSEdition -and
            $manifest.build.inputs.dependency_provenance_sha256 -ceq (Get-Hash $dependencyInput) -and
            $manifest.build.inputs.test_evidence_sha256 -ceq (Get-Hash $testInput)) 'Manifest must bind exact builder allowlist shell and supplied provenance bytes.'
        $expectedTests = Get-Content -LiteralPath $testInput -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-True (($manifest.test_evidence | ConvertTo-Json -Depth 8 -Compress) -ceq ($expectedTests.tests | ConvertTo-Json -Depth 8 -Compress)) 'Manifest must preserve the actual supplied synthetic-only test reference.'
        Assert-True (-not (($manifest | ConvertTo-Json -Depth 20) -match '(?i)[A-Z]:\\|<USER_PROFILE>|private\.mp3|owner_token')) 'Public manifest cannot disclose local absolute paths or ownership tokens.'
        $lines = @([IO.File]::ReadAllLines((Join-Path $first 'SHA256SUMS.txt')) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-True ($lines.Count -eq 2) 'SHA256SUMS must hash only ZIP and external manifest.'
        foreach ($name in @($manifest.zip.name, 'release-manifest.json')) {
            Assert-True ($lines -ccontains ((Get-Hash (Join-Path $first $name)) + '  ' + $name)) 'Published checksum must bind an actual asset without self-reference.'
        }
        $case['manifest'] = $manifest; $case['checksum_lines'] = $lines
    }
    Invoke-Case 'same-shell repeated clean build compares ZIP manifest and checksum bytes' 'A47' {
        param($case)
        $case['build_config'] = Get-FixtureGitConfig
        Assert-True ($case.build_config.core_autocrlf -ceq 'false' -and $case.build_config.core_eol -ceq 'lf') 'Comparison build must actually use restored false/lf.'
        $second = Join-Path $buildParent 'second'
        Assert-True ((Invoke-Build $second).ExitCode -eq 0) 'Second clean build must succeed.'
        $repeat = Get-OutputInventory $second
        Assert-True (($repeat | ConvertTo-Json -Depth 8 -Compress) -ceq ($report.artifacts | ConvertTo-Json -Depth 8 -Compress)) 'Repeated package artifacts must compare byte-for-byte in this shell.'
        $case['first'] = $report.artifacts; $case['second'] = $repeat; $case['byte_identical'] = $true
    }
    Invoke-Case 'existing artifact directory is preserved without overwrite' 'A47,A48' {
        param($case)
        $before = Get-OutputInventory $first
        Assert-True ((Invoke-Build $first).ExitCode -ne 0) 'Builder must reject an existing output directory.'
        Assert-True (($before | ConvertTo-Json -Depth 8 -Compress) -ceq ((Get-OutputInventory $first) | ConvertTo-Json -Depth 8 -Compress)) 'Existing approved artifact bytes must be unchanged.'
        $existingFile = Join-Path $buildParent 'existing-file'; Write-NewText $existingFile 'SYNTHETIC OUTPUT SENTINEL'
        $sentinelHash = Get-Hash $existingFile
        Assert-True ((Invoke-Build $existingFile).ExitCode -ne 0 -and (Get-Hash $existingFile) -ceq $sentinelHash) 'An existing output file must also be preserved byte-for-byte.'
        $case['preserved'] = $true
    }
    foreach ($sample in @(@{ name = 'abbreviated source commit'; commit = $report.synthetic_source_commit.Substring(0, 12) },
        @{ name = 'wrong full source commit'; commit = ('0' * 40) }, @{ name = 'uppercase source commit'; commit = $report.synthetic_source_commit.ToUpperInvariant() })) {
        Invoke-Case $sample.name 'A47,A48' { Assert-RejectedBuild -Name 'bad-commit' -Commit $sample.commit | Out-Null }
    }
    Invoke-Case 'wrong target tag cannot override the authoritative helper version' 'A47,A48' { Assert-RejectedBuild -Name 'bad-tag' -Tag 'v9.9.9' | Out-Null }
    Invoke-Case 'output inside source is refused before any directory creation' 'A47,A48' {
        $inside = Join-Path $fixtureRoot 'not-a-package'
        Assert-RejectedBuild -Name 'inside-source' -Destination $inside | Out-Null
    }
    Invoke-Case 'attached branch checkout is refused' 'A47,A48' {
        Invoke-FixtureGit @('switch', '-c', 'synthetic-attached') | Out-Null
        try { Assert-RejectedBuild -Name 'attached' | Out-Null } finally { Restore-Fixture }
    }
    Invoke-Case 'dirty tracked source is refused and restored byte-for-byte' 'A47,A48' {
        $path = Join-Path $fixtureRoot 'README.md'; $bytes = [IO.File]::ReadAllBytes($path)
        try { [IO.File]::AppendAllText($path, "`nSYNTHETIC DIRTY MARKER`n"); Assert-RejectedBuild -Name 'tracked-dirty' | Out-Null } finally { [IO.File]::WriteAllBytes($path, $bytes) }
    }
    foreach ($name in @('untracked-fixture.log', 'ignored-fixture.log')) {
        Invoke-Case ('dirty ' + $name + ' is refused') 'A47,A48' {
            $path = Join-Path $fixtureRoot $name; Write-NewText $path 'SYNTHETIC UNTRACKED MARKER'
            Assert-True ([IO.Path]::GetFileName($path) -ceq $name) 'Dirty fixture must use the exact intended filename.'
            $dirtyStatus = Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')
            $expectedPrefix = if ($name -ceq 'ignored-fixture.log') { '!! ' } else { '?? ' }
            Assert-True ($dirtyStatus -ceq ($expectedPrefix + $name)) 'Dirty fixture must be actually classified as the intended ignored/untracked file.'
            try { Assert-RejectedBuild -Name 'untracked' | Out-Null } finally { [IO.File]::Delete($path) }
        }
    }
    foreach ($name in $required) {
        Invoke-Case ('required omission: ' + $name) 'A47' {
            [IO.File]::Delete((Join-Path $fixtureRoot $name))
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot $name))) 'Required omission must delete the exact named required member.'
            $commit = Commit-Fixture ('Synthetic required omission ' + $name); Set-TestInput $commit
            try { Assert-RejectedBuild -Name 'omission' -Commit $commit | Out-Null } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
        }
    }
    $allowlistPath = Join-Path $fixtureRoot 'tools\package-files.json'
    foreach ($sample in @(@{ name = 'traversal'; value = '../outside.txt' }, @{ name = 'absolute'; value = 'C:/outside.txt' },
        @{ name = 'wildcard'; value = 'wild*.txt' }, @{ name = 'reserved device'; value = 'NUL.txt' },
        @{ name = 'case duplicate'; value = 'README.MD' }, @{ name = 'third party binary'; value = 'ffmpeg.exe' })) {
        Invoke-Case ('unsafe expanded allowlist: ' + $sample.name) 'A47,A48' {
            $list = Get-Content -LiteralPath $allowlistPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $list.files += $sample.value
            [IO.File]::WriteAllText($allowlistPath, ($list | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
            $commit = Commit-Fixture ('Synthetic unsafe allowlist ' + $sample.name); Set-TestInput $commit
            try { Assert-RejectedBuild -Name 'unsafe-allowlist' -Commit $commit | Out-Null } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
        }
    }
    Invoke-Case 'version is read from source helper rather than the invoked checkout or filename' 'A47,A48' {
        $path = Join-Path $fixtureRoot 'AudioFileForPhone.Helpers.ps1'
        $text = [IO.File]::ReadAllText($path); $oldVersion = Get-AudioAppVersion
        Assert-True ($text.Contains("return '$oldVersion'")) 'Synthetic version fixture requires the exact single runtime helper return.'
        [IO.File]::WriteAllText($path, $text.Replace("return '$oldVersion'", "return '9.9.9'"), (New-Object Text.UTF8Encoding($false)))
        $commit = Commit-Fixture 'Synthetic source helper version mismatch'; Set-TestInput $commit
        $script:differentFixtureCommit = $commit
        try { Assert-RejectedBuild -Name 'source-version' -Commit $commit | Out-Null } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
    }
    Invoke-Case 'valid existing full commit different from checkout HEAD is refused' 'A47,A48' {
        Assert-True ($script:differentFixtureCommit -cne $report.synthetic_source_commit -and $script:differentFixtureCommit -cmatch '^[a-f0-9]{40}$') 'Wrong-HEAD fixture must use a real different full source commit.'
        Assert-RejectedBuild -Name 'wrong-existing-head' -Commit $script:differentFixtureCommit | Out-Null
    }
    Invoke-Case 'exact source helper must be functions-only before loading' 'A47,A48' {
        [IO.File]::AppendAllText((Join-Path $fixtureRoot 'AudioFileForPhone.Helpers.ps1'), "`nWrite-Output 'SYNTHETIC_ACTIVE_HELPER_SENTINEL'`n")
        $activeCommit = Commit-Fixture 'Synthetic active helper statement'; Set-TestInput $activeCommit
        try {
            $rejected = Assert-RejectedBuild -Name 'active-helper' -Commit $activeCommit
            Assert-True (-not $rejected.Stdout.Contains('SYNTHETIC_ACTIVE_HELPER_SENTINEL')) 'Functions-only helper guard must run before executing any top-level statement.'
        } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
    }
    foreach ($attributeKind in @('export-ignore', 'export-subst')) {
        Invoke-Case ('archive attribute cannot omit or substitute exact Git blobs: ' + $attributeKind) 'A47,A48' {
            if ($attributeKind -ceq 'export-subst') {
                [IO.File]::WriteAllText((Join-Path $fixtureRoot 'README.md'), 'Synthetic substitution token: $Format:%H$', (New-Object Text.UTF8Encoding($false)))
            }
            Write-NewText (Join-Path $fixtureRoot '.gitattributes') ('README.md ' + $attributeKind + "`n")
            $attributeCommit = Commit-Fixture ('Synthetic archive attribute ' + $attributeKind); Set-TestInput $attributeCommit
            try {
                Assert-True ((Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all')).Length -eq 0) 'Archive-attribute fixture must have clean source.'
                Assert-RejectedBuild -Name 'archive-attribute' -Commit $attributeCommit | Out-Null
            } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
        }
    }
    Invoke-Case 'dependency input inside otherwise clean source is refused' 'A48' {
        $insideDependency = Join-Path $fixtureRoot 'local-provenance.json'
        [IO.File]::Copy($dependencyInput, $insideDependency, $false)
        $insideCommit = Commit-Fixture 'Synthetic source-contained dependency input'; Set-TestInput $insideCommit
        try {
            $rejected = Assert-RejectedBuild -Name 'inside-dependency' -Commit $insideCommit -Dependencies $insideDependency
            Assert-True (($rejected.Stdout + $rejected.Stderr) -match 'outside.*source|external.*source') 'Dependency input rejection must identify the external-source boundary.'
        } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
    }
    Invoke-Case 'test input inside otherwise clean source is refused' 'A48' {
        $rejected = Assert-RejectedBuild -Name 'inside-tests' -Tests (Join-Path $fixtureRoot 'docs\codex-v1\private-evidence.json')
        Assert-True (($rejected.Stdout + $rejected.Stderr) -match 'outside.*source|external.*source') 'Test input rejection must identify the external-source boundary.'
    }
    foreach ($unsafeOutput in @('relative-package', ('C:relative-package'), (Join-Path $buildParent 'wild*.zip'),
        (Join-Path $buildParent 'package:stream'), (Join-Path $buildParent 'trailing.'), (Join-Path $buildParent '..\escaped'))) {
        Invoke-Case 'unsafe output path syntax is refused before mutation' 'A47,A48' {
            Assert-RejectedBuild -Name 'unsafe-output' -Destination $unsafeOutput | Out-Null
        }
    }
    Invoke-Case 'tracked Git symlink mode is refused even with Windows regular-file checkout' 'A47,A48' {
        $path = Join-Path $fixtureRoot 'README.md'; [IO.File]::WriteAllText($path, 'SUPPORT.md', (New-Object Text.UTF8Encoding($false)))
        $blob = Invoke-FixtureGit @('hash-object', '-w', '--', 'README.md')
        Invoke-FixtureGit @('update-index', '--cacheinfo', ('120000,' + $blob + ',README.md')) | Out-Null
        Invoke-FixtureGit @('-c', 'user.name=T19 synthetic fixture', '-c', 'user.email=t19@example.invalid', 'commit', '-m', 'Synthetic tracked symlink mode') | Out-Null
        $commit = Invoke-FixtureGit @('rev-parse', 'HEAD'); Set-TestInput $commit
        Assert-True ((Invoke-FixtureGit @('status', '--porcelain=v1', '--untracked-files=all')).Length -eq 0) 'Git symlink-mode fixture must be clean so rejection exercises the member mode guard.'
        try { Assert-RejectedBuild -Name 'git-symlink' -Commit $commit | Out-Null } finally { Restore-Fixture; Set-TestInput $report.synthetic_source_commit }
    }
    foreach ($kind in @('source', 'output-parent')) {
        Invoke-Case ('reparse ' + $kind + ' ancestor is refused without following it') 'A47,A48' {
            $link = Join-Path $root ('junction-' + $kind)
            $target = if ($kind -ceq 'source') { $fixtureRoot } else { $buildParent }
            [void](New-Item -Path $link -ItemType Junction -Value $target); $junctions.Add($link)
            try {
                if ($kind -ceq 'source') { Assert-RejectedBuild -Name 'source-reparse' -Source $link | Out-Null }
                else { Assert-RejectedBuild -Name 'output-reparse' -Destination (Join-Path $link 'not-created') | Out-Null }
            } finally { [IO.Directory]::Delete($link, $false); [void]$junctions.Remove($link) }
        }
    }
    foreach ($kind in @('hash', 'version', 'missing-tool')) {
        Invoke-Case ('dependency provenance mismatch: ' + $kind) 'A48' {
            $changed = Get-Content -LiteralPath $dependencyInput -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($kind -ceq 'hash') { $changed.ffmpeg.sha256 = '0' * 64 }
            elseif ($kind -ceq 'version') { $changed.ffprobe.version = 'synthetic incorrect tool version' }
            else { $changed.ffmpeg.path = Join-Path $root 'does-not-exist.exe' }
            $path = Join-Path $root ('dependency-' + $kind + '.json'); Write-NewText $path ($changed | ConvertTo-Json -Depth 8)
            Assert-RejectedBuild -Name 'dependency-mismatch' -Dependencies $path | Out-Null
        }
    }
    foreach ($kind in @('commit', 'status', 'unsafe-reference')) {
        Invoke-Case ('test provenance mismatch: ' + $kind) 'A48' {
            $changed = Get-Content -LiteralPath $testInput -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($kind -ceq 'commit') { $changed.tests[0].tested_commit = '0' * 40 }
            elseif ($kind -ceq 'status') { $changed.tests[0].status = 'fail' }
            else { $changed.tests[0].reference = '../private-path.json' }
            $path = Join-Path $root ('tests-' + $kind + '.json'); Write-NewText $path ($changed | ConvertTo-Json -Depth 8)
            Assert-RejectedBuild -Name 'test-provenance' -Tests $path | Out-Null
        }
    }
    $report.status = 'pass'
} catch {
    $report.error = Protect-Text $_.Exception.Message
    $report['error_location'] = Protect-Text $_.ScriptStackTrace
    Write-Warning $report.error
} finally {
    [Environment]::SetEnvironmentVariable('GIT_AUTHOR_DATE', $oldAuthorDate, 'Process')
    [Environment]::SetEnvironmentVariable('GIT_COMMITTER_DATE', $oldCommitterDate, 'Process')
    $report.descendant_release_proved = $childrenReleased
    try {
        $report.source_after = Get-Inventory $projectRoot $sourceFiles
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Depth 8 -Compress) -ceq ($report.source_after | ConvertTo-Json -Depth 8 -Compress))
        Assert-True $report.source_unchanged 'Application/build/test/lock source changed during package tests.'
        if (Test-Path -LiteralPath $fixtureRoot) {
            $report.fixture_after = Get-Inventory $fixtureRoot ($required + $buildFiles)
            $report.synthetic_unchanged = (($report.fixture_before | ConvertTo-Json -Depth 8 -Compress) -ceq ($report.fixture_after | ConvertTo-Json -Depth 8 -Compress))
            Assert-True $report.synthetic_unchanged 'Synthetic application/build payload was not restored exactly.'
        }
        Assert-True $childrenReleased 'Owned children must be positively released before cleanup.'
        if ($rootCreated) {
            $report['cleanup_stage'] = 'owned_junctions'
            foreach ($link in @($junctions.ToArray())) {
                Assert-True ([IO.Path]::GetDirectoryName($link).Equals($root, [StringComparison]::OrdinalIgnoreCase)) 'Owned junction cleanup escaped exact temporary root.'
                Assert-True (((Get-Item -LiteralPath $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Owned junction changed before nonrecursive removal.'
                [IO.Directory]::Delete($link, $false)
            }
            $resolved = (Resolve-Path -LiteralPath $root).ProviderPath.TrimEnd('\', '/')
            $report.cleanup_stage = 'exact_root_ownership_and_reparse'
            Assert-True ($resolved.Equals($root, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetDirectoryName($resolved).Equals($tempParent, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -ceq $rootName) 'Cleanup must resolve the exact exclusively owned TEMP directory.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($marker) -ceq $ownerToken) 'Cleanup ownership token differs.'
            $report.cleanup_stage = 'safe_owned_tree_inventory'
            $cleanupTree = @(Get-SafeTree $resolved)
            $report.cleanup_stage = 'owned_git_readonly_attributes'
            $ownedGitPrefix = (Join-Path $fixtureRoot '.git') + '\'
            foreach ($item in $cleanupTree) {
                if (-not $item.PSIsContainer -and ($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
                    Assert-True ($item.FullName.StartsWith($ownedGitPrefix, [StringComparison]::OrdinalIgnoreCase)) 'Only owned synthetic Git metadata may require ReadOnly removal for cleanup.'
                    $item.Attributes = $item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)
                }
            }
            $report.cleanup_stage = 'remove_exact_owned_tree'
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned package fixture cleanup failed.'
    } catch {
        $report.status = 'fail'; $report['verification_error'] = Protect-Text $_.Exception.Message
        $report['verification_error_location'] = Protect-Text $_.ScriptStackTrace
    }
    $report.ended_utc = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    Write-NewText $evidence ($report | ConvertTo-Json -Depth 30)
}
Write-Host ('T19 package policy: ' + $report.status + '; cases=' + $report.cases.Count + '; source=' + $report.source_unchanged + '; cleanup=' + $report.cleanup_verified)
if ($report.status -cne 'pass') { exit 1 }
