<#
Focused R3 corrective user-package build policy. Uses caller-supplied clean detached source
and its exact core assets. Only new marker-owned copies are modified. No audio,
Music lookup, downloads, Git mutations or publication. Run separately in PS5.1
and PS7; repeat-build equality is asserted within each actual host. Raw evidence
and retained synthetic tampering fixtures stay outside the repository.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$SourceCommit,
    [Parameter(Mandatory = $true)][string]$RuntimeAssetDirectory,
    [Parameter(Mandatory = $true)][string]$EvidencePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$SourcePath = [IO.Path]::GetFullPath($SourcePath).TrimEnd('\', '/')
$RuntimeAssetDirectory = [IO.Path]::GetFullPath($RuntimeAssetDirectory).TrimEnd('\', '/')
$EvidencePath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetDirectoryName($EvidencePath)
$builder = Join-Path $repository 'tools/Build-UserPackage.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-BuildTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-BuildTestHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Assert-BuildTestOrdinaryPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            Assert-BuildTest (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Test paths cannot have reparse ancestors.'
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Invoke-BuildTestGit([string[]]$Arguments) {
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rows = @(& git --no-optional-locks -C $SourcePath @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    Assert-BuildTest ($code -eq 0) 'Read-only source Git inspection failed.'
    (@($rows | ForEach-Object { [string]$_ }) -join "`n").TrimEnd("`r", "`n")
}
function Get-BuildTestAssets([string]$Root) {
    @($assetNames | Sort-Object | ForEach-Object {
        [pscustomobject]@{ name = $_; bytes = (Get-Item -LiteralPath (Join-Path $Root $_)).Length; sha256 = Get-BuildTestHash (Join-Path $Root $_) }
    })
}
function Get-BuildTestBytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-BuildTestZip([string]$Path) {
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    $members = [ordered]@{}
    try {
        foreach ($entry in $archive.Entries) {
            Assert-BuildTest (-not $members.Contains($entry.FullName)) 'ZIP contains a duplicate member.'
            Assert-BuildTest ($entry.FullName -cmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -and $entry.FullName -notmatch '(^|/)\.\.?(/|$)|//|/$') 'ZIP member is unsafe.'
            Assert-BuildTest ($entry.Length -gt 0 -and $entry.Length -le 10485760) 'ZIP member exceeds its test bound.'
            $stream = $entry.Open(); $memory = New-Object IO.MemoryStream
            try { $stream.CopyTo($memory); [byte[]]$bytes = $memory.ToArray() }
            finally { $memory.Dispose(); $stream.Dispose() }
            $members[$entry.FullName] = [pscustomobject]@{ bytes = $bytes; sha256 = Get-BuildTestBytesHash $bytes; length = $bytes.Length }
        }
    } finally { $archive.Dispose() }
    return ,$members
}
function Add-BuildTestCase([string]$Name, [scriptblock]$Body) {
    $case = [ordered]@{ name = $Name; status = 'FAILED'; observed = $null }
    try { $case.observed = & $Body; $case.status = 'PASSED' }
    finally { $report.cases += [pscustomobject]$case }
}
function Invoke-BuildTestBuilder {
    param([string]$Output, [string]$InputAssets = $RuntimeAssetDirectory,
        [string]$Commit = $SourceCommit, [string]$InputSource = $SourcePath,
        [string]$TestEvidence, [switch]$ExpectFailure)
    $options = @{ SourcePath = $InputSource; SourceCommit = $Commit; RuntimeAssetDirectory = $InputAssets; OutputDirectory = $Output }
    if ($TestEvidence) { $options.PackageTestEvidencePath = $TestEvidence }
    $failure = $null; $capture = $null
    try { $capture = (& $builder @options | Out-String).Trim() }
    catch { $failure = $_.Exception.Message }
    if ($ExpectFailure) {
        Assert-BuildTest (-not [string]::IsNullOrWhiteSpace($failure)) 'Invalid build unexpectedly succeeded.'
        Assert-BuildTest (-not (Test-Path -LiteralPath $Output)) 'Refused build left a completed-looking output directory.'
    } else {
        Assert-BuildTest ([string]::IsNullOrWhiteSpace($failure)) ('Valid build failed: ' + $failure)
        Assert-BuildTest (Test-Path -LiteralPath $Output -PathType Container) 'Valid build omitted output directory.'
    }
    Assert-BuildTest (@(Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object { $_.Name -like '.afp-user-package-*' }).Count -eq 0) 'Builder retained an owned staging directory.'
    [pscustomobject]@{ refusal = $failure; output = $capture }
}
function Copy-BuildTestAssets([string]$Name) {
    $destination = Join-Path $root $Name
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    foreach ($asset in $assetNames) { Copy-Item -LiteralPath (Join-Path $RuntimeAssetDirectory $asset) -Destination (Join-Path $destination $asset) }
    $destination
}
function Update-BuildTestOuterDigests([string]$Directory, [object]$Manifest) {
    $Manifest.zip.sha256 = Get-BuildTestHash (Join-Path $Directory $coreZipName)
    $Manifest.zip.bytes = (Get-Item -LiteralPath (Join-Path $Directory $coreZipName)).Length
    $manifestPath = Join-Path $Directory 'release-manifest.json'
    [IO.File]::WriteAllText($manifestPath, (($Manifest | ConvertTo-Json -Depth 30) + "`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $Directory 'SHA256SUMS.txt'), ($Manifest.zip.sha256 + '  ' + $coreZipName + "`n" + (Get-BuildTestHash $manifestPath) + "  release-manifest.json`n"), $utf8)
}
function Write-BuildTestZipMember([string]$Path, [string]$Name, [byte[]]$Bytes) {
    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $old = $archive.GetEntry($Name)
        if ($null -ne $old) { $old.Delete() }
        $entry = $archive.CreateEntry($Name)
        $stream = $entry.Open()
        try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
    } finally { $archive.Dispose() }
}

foreach ($path in @($SourcePath, $RuntimeAssetDirectory, $evidenceParent)) { Assert-BuildTestOrdinaryPath $path }
Assert-BuildTest ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT -and [Environment]::Is64BitProcess) 'Use an x64 Windows host.'
Assert-BuildTest (-not (Test-Path -LiteralPath $EvidencePath)) 'Use a fresh EvidencePath.'
Assert-BuildTest ([IO.Directory]::Exists($evidenceParent)) 'Evidence parent must already exist.'
Assert-BuildTest (-not $EvidencePath.StartsWith($repository + '\', [StringComparison]::OrdinalIgnoreCase)) 'Keep raw build-policy evidence outside the repository.'
$coreManifest = Get-Content -LiteralPath (Join-Path $RuntimeAssetDirectory 'release-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$coreZipName = [string]$coreManifest.zip.name
Assert-BuildTest ($coreZipName -cmatch '^AudioFileForPhone-v[0-9]+\.[0-9]+\.[0-9]+\.zip$') 'Expected one ordinary core runtime archive name.'
Assert-BuildTest ($coreZipName -ceq 'AudioFileForPhone-v1.0.4.zip' -and $coreManifest.app_version -ceq '1.0.4' -and $coreManifest.tag -ceq 'v1.0.4') 'Core source/assets must use the owner-selected corrective release identity.'
$assetNames = @($coreZipName, 'release-manifest.json', 'SHA256SUMS.txt')
$root = Join-Path $evidenceParent ('user-package-build-' + [guid]::NewGuid().ToString('N'))
Assert-BuildTest (-not (Test-Path -LiteralPath $root)) 'Owned test root collision.'
[IO.Directory]::CreateDirectory($root) | Out-Null
[IO.File]::WriteAllText((Join-Path $root '.r2-build-owner'), [guid]::NewGuid().ToString('N'), $utf8)
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; kind = 'r3_user_package_build_policy'; task = 'R3'; app_version = '1.0.4'; artifact_kind = 'corrective_release_candidate'; status = 'RUNNING'
    started_utc = [datetime]::UtcNow.ToString('o'); ended_utc = $null; error = $null
    source_commit = $SourceCommit; test_script_sha256 = Get-BuildTestHash $PSCommandPath
    builder_sha256 = Get-BuildTestHash $builder; shell = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition
    windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR; os = [Environment]::OSVersion.Version.ToString()
    cases = @(); core_before = Get-BuildTestAssets $RuntimeAssetDirectory; core_after = @()
    source_status_before = $null; source_status_after = $null; source_unchanged = $false; core_unchanged = $false
    runtime_zip_sha256 = $null; icon_sha256 = $null; ordinary_music_access = $false; media_conversion = $false
    publication_performed = $false; owner_testing_required = 'none'; retained_owned_fixture_root = $root
    stage_cleanup_verified = $false; reparse_cleanup_verified = $false
}
$junctions = New-Object 'Collections.Generic.List[string]'
try {
    Assert-BuildTest ((Invoke-BuildTestGit @('rev-parse', 'HEAD')) -ceq $SourceCommit) 'Supplied source commit must equal HEAD.'
    $report.source_status_before = Invoke-BuildTestGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')
    Assert-BuildTest ([string]::IsNullOrWhiteSpace($report.source_status_before)) 'Supplied detached source must be clean.'
    $first = Join-Path $root 'first'
    Add-BuildTestCase 'valid-build-and-exact-root-allowlist' {
        $null = Invoke-BuildTestBuilder $first
        $zip = Join-Path $first 'AudioFileForPhone-v1.0.4.zip'
        $members = Read-BuildTestZip $zip
        [string[]]$expected = @('AudioFileForPhone.bat', 'AudioFileForPhone.ico', 'README.txt',
            'app/AudioFileForPhone.ps1', 'app/AudioFileForPhone.Helpers.ps1', 'app/AudioFileForPhone.ManagedSetup.ps1',
            'app/AudioFileForPhone.Diagnostics.ps1', 'app/AudioFileForPhone.Checks.ps1', 'app/Check-AudioFileForPhone.ps1',
            'app/tools/ffmpeg-download.json', 'app/Setup-AudioFileForPhone.ps1', 'app/Setup-AudioFileForPhone.bat',
            'app/README.md', 'app/SUPPORT.md', 'app/CHANGELOG.md', 'app/SECURITY.md', 'app/LICENSE')
        [Array]::Sort($expected, [StringComparer]::Ordinal)
        Assert-BuildTest (($members.Keys -join '|') -ceq ($expected -join '|')) 'Final user archive must contain exactly the independently listed seventeen files in ordinal order.'
        $rootEntries = @($members.Keys | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
        Assert-BuildTest ($rootEntries.Count -eq 4 -and @($rootEntries | Where-Object { $_ -cnotin @('app', 'AudioFileForPhone.bat', 'AudioFileForPhone.ico', 'README.txt') }).Count -eq 0) 'Final root must have exactly the four intended visible entries.'
        $report.runtime_zip_sha256 = Get-BuildTestHash $zip
        $report.icon_sha256 = $members['AudioFileForPhone.ico'].sha256
        Assert-BuildTest ($report.icon_sha256 -ceq (Get-BuildTestHash (Join-Path $SourcePath 'AudioFileForPhone.ico'))) 'Existing icon bytes changed.'
        $manifest = Get-Content -LiteralPath (Join-Path $first 'release-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-BuildTest ($manifest.package_revision -eq 3 -and $manifest.zip.sha256 -ceq $report.runtime_zip_sha256) 'Candidate manifest revision/ZIP binding mismatch.'
        Assert-BuildTest ($manifest.release_commit -ceq $SourceCommit -and $manifest.app_version -ceq '1.0.4' -and $manifest.tag -ceq 'v1.0.4' -and $manifest.corrective_release_version -ceq '1.0.4' -and $manifest.publication_authorized -eq $false -and $manifest.artifact_kind -ceq 'corrective_release_candidate') 'Corrective candidate must bind its source and approved identity without claiming publication authority.'
        Assert-BuildTest (@($manifest.files.PSObject.Properties).Count -eq 17) 'Candidate manifest inventory count mismatch.'
        foreach ($name in $members.Keys) {
            Assert-BuildTest ($manifest.files.$name -ceq $members[$name].sha256 -and $manifest.file_bytes.$name -eq $members[$name].length) 'Candidate manifest must bind every output member.'
        }
        $original = Read-BuildTestZip (Join-Path $RuntimeAssetDirectory $coreZipName)
        foreach ($name in $expected | Where-Object { $_.StartsWith('app/') -and -not $_.EndsWith('.bat') }) {
            Assert-BuildTest ($members[$name].sha256 -ceq $original[$name.Substring(4)].sha256) 'Copied app member differs from the exact core source.'
        }
        foreach ($name in @('AudioFileForPhone.bat', 'app/Setup-AudioFileForPhone.bat')) {
            $text = $utf8.GetString($members[$name].bytes)
            Assert-BuildTest ($text.Contains("`r`n") -and -not [regex]::IsMatch($text, '(?<!\r)\n')) 'Packaged BAT line endings must be CRLF.'
        }
        $bat = $utf8.GetString($members['AudioFileForPhone.bat'].bytes)
        Assert-BuildTest ($bat.Contains('set "AFP_SCRIPT=%~dp0app\AudioFileForPhone.ps1"') -and $bat -notmatch '(?im)^\s*call\s+' -and $bat.Contains('-FromBatchLauncher') -and $bat.Contains('-ExecutionPolicy Bypass')) 'Root BAT must retain the direct converter route and process-only policy request.'
        $sums = @([IO.File]::ReadAllLines((Join-Path $first 'SHA256SUMS.txt')))
        Assert-BuildTest ($sums.Count -eq 2 -and $sums[0] -ceq ($report.runtime_zip_sha256 + '  AudioFileForPhone-v1.0.4.zip') -and $sums[1] -ceq ((Get-BuildTestHash (Join-Path $first 'release-manifest.json')) + '  release-manifest.json')) 'External checksum binding mismatch.'
        'All seventeen exact members, four visible entries, CRLF direct BATs and unchanged icon verified.'
    }
    Add-BuildTestCase 'same-host-deterministic-rebuild' {
        $repeat = Join-Path $root 'repeat'
        $null = Invoke-BuildTestBuilder $repeat
        foreach ($name in @('AudioFileForPhone-v1.0.4.zip', 'release-manifest.json', 'SHA256SUMS.txt')) {
            Assert-BuildTest ((Get-BuildTestHash (Join-Path $first $name)) -ceq (Get-BuildTestHash (Join-Path $repeat $name))) 'Repeated clean build changed artifact bytes.'
        }
        'ZIP, manifest and checksum bytes are identical on this actual shell.'
    }
    Add-BuildTestCase 'wrong-source-commit-refused' {
        (Invoke-BuildTestBuilder (Join-Path $root 'wrong-source-output') -Commit ('0' * 40) -ExpectFailure).refusal
    }
    Add-BuildTestCase 'corrupt-core-archive-refused' {
        $copy = Copy-BuildTestAssets 'corrupt-core'
        $stream = [IO.File]::Open((Join-Path $copy $coreZipName), [IO.FileMode]::Append, [IO.FileAccess]::Write)
        try { $stream.WriteByte(1) } finally { $stream.Dispose() }
        (Invoke-BuildTestBuilder (Join-Path $root 'corrupt-output') -InputAssets $copy -ExpectFailure).refusal
    }
    Add-BuildTestCase 'self-consistent-member-tamper-refused-by-source-binding' {
        $copy = Copy-BuildTestAssets 'tampered-member'
        $original = Read-BuildTestZip (Join-Path $copy $coreZipName)
        [byte[]]$modified = $original['AudioFileForPhone.ps1'].bytes + $utf8.GetBytes("`n# owned synthetic tamper`n")
        Write-BuildTestZipMember (Join-Path $copy $coreZipName) 'AudioFileForPhone.ps1' $modified
        $manifest = Get-Content -LiteralPath (Join-Path $copy 'release-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $manifest.files.'AudioFileForPhone.ps1' = Get-BuildTestBytesHash $modified
        $manifest.file_bytes.'AudioFileForPhone.ps1' = $modified.Length
        Update-BuildTestOuterDigests $copy $manifest
        (Invoke-BuildTestBuilder (Join-Path $root 'tampered-output') -InputAssets $copy -ExpectFailure).refusal
    }
    Add-BuildTestCase 'extra-core-member-refused' {
        $copy = Copy-BuildTestAssets 'extra-member'
        Write-BuildTestZipMember (Join-Path $copy $coreZipName) 'unexpected.txt' ($utf8.GetBytes('owned synthetic extra member'))
        $manifest = Get-Content -LiteralPath (Join-Path $copy 'release-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Update-BuildTestOuterDigests $copy $manifest
        (Invoke-BuildTestBuilder (Join-Path $root 'extra-output') -InputAssets $copy -ExpectFailure).refusal
    }
    Add-BuildTestCase 'unsafe-output-spelling-refused' {
        (Invoke-BuildTestBuilder (Join-Path $root 'wildcard*output') -ExpectFailure).refusal
    }
    Add-BuildTestCase 'existing-output-preserved' {
        $existing = Join-Path $root 'existing'
        [IO.Directory]::CreateDirectory($existing) | Out-Null
        $sentinel = Join-Path $existing 'sentinel.txt'
        [IO.File]::WriteAllText($sentinel, 'Existing output must remain untouched.', $utf8)
        $before = Get-BuildTestHash $sentinel; $failure = $null
        try { $null = & $builder -SourcePath $SourcePath -SourceCommit $SourceCommit -RuntimeAssetDirectory $RuntimeAssetDirectory -OutputDirectory $existing }
        catch { $failure = $_.Exception.Message }
        Assert-BuildTest ($failure -and (Get-BuildTestHash $sentinel) -ceq $before -and @(Get-ChildItem -LiteralPath $existing -Force).Count -eq 1) 'Existing output refusal changed pre-existing bytes.'
        $failure
    }
    Add-BuildTestCase 'mismatched-evidence-refused-and-owned-stage-cleaned' {
        $badEvidence = Join-Path $root 'mismatched-evidence.json'
        $badRecord = [ordered]@{ schema_version = 1; kind = 'user_package_verification'; source_commit = $SourceCommit; status = 'PASSED'; package_revision = 3; app_version = '1.0.4'; artifact_kind = 'corrective_release_candidate'; runtime_zip_sha256 = ('0' * 64) }
        [IO.File]::WriteAllText($badEvidence, ($badRecord | ConvertTo-Json), $utf8)
        (Invoke-BuildTestBuilder (Join-Path $root 'bad-evidence-output') -TestEvidence $badEvidence -ExpectFailure).refusal
    }
    Add-BuildTestCase 'reparse-input-refused' {
        $link = Join-Path $root 'asset-junction'
        $null = New-Item -Path $link -ItemType Junction -Target $RuntimeAssetDirectory
        $junctions.Add($link)
        Assert-BuildTest (((Get-Item -LiteralPath $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Actual junction was not created.'
        (Invoke-BuildTestBuilder (Join-Path $root 'reparse-input-output') -InputAssets $link -ExpectFailure).refusal
    }
    Add-BuildTestCase 'reparse-output-parent-refused' {
        $target = Join-Path $root 'junction-target'
        [IO.Directory]::CreateDirectory($target) | Out-Null
        $link = Join-Path $root 'output-junction'
        $null = New-Item -Path $link -ItemType Junction -Target $target
        $junctions.Add($link)
        (Invoke-BuildTestBuilder (Join-Path $link 'output') -ExpectFailure).refusal
    }
    $report.source_status_after = Invoke-BuildTestGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')
    $report.core_after = Get-BuildTestAssets $RuntimeAssetDirectory
    $report.source_unchanged = $report.source_status_before -ceq $report.source_status_after -and (Invoke-BuildTestGit @('rev-parse', 'HEAD')) -ceq $SourceCommit
    $report.core_unchanged = ($report.core_before | ConvertTo-Json -Compress) -ceq ($report.core_after | ConvertTo-Json -Compress)
    Assert-BuildTest ($report.source_unchanged -and $report.core_unchanged) 'Original source/core assets changed during build tests.'
    $report.stage_cleanup_verified = @(Get-ChildItem -LiteralPath $root -Directory -Force | Where-Object { $_.Name -like '.afp-user-package-*' }).Count -eq 0
    Assert-BuildTest $report.stage_cleanup_verified 'Owned builder staging cleanup incomplete.'
    $report.status = 'PASSED'
} catch { $report.status = 'FAILED'; $report.error = $_.Exception.Message }
finally {
    try {
        foreach ($link in $junctions) {
            Assert-BuildTest ($link.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) 'Junction cleanup boundary mismatch.'
            $item = Get-Item -LiteralPath $link -Force
            Assert-BuildTest (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Expected owned junction changed before cleanup.'
            [IO.Directory]::Delete($link, $false)
        }
        $report.reparse_cleanup_verified = @($junctions | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0
        Assert-BuildTest $report.reparse_cleanup_verified 'Owned junction cleanup incomplete.'
    } catch { $report.status = 'FAILED'; $report.error = [string]$report.error + '; Cleanup: ' + $_.Exception.Message }
    $report.ended_utc = [datetime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText($EvidencePath, ($report | ConvertTo-Json -Depth 20), $utf8)
}
Write-Host ('R2 package build policy: ' + $report.status + '; ' + $report.cases.Count + ' cases; evidence ' + $EvidencePath)
if ($report.status -cne 'PASSED') { Write-Error $report.error -ErrorAction Continue; exit 1 }
exit 0
