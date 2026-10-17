<#
.SYNOPSIS
Build the explicit AudioFileForPhone package from an exact clean detached commit.
.DESCRIPTION
Requires Windows PowerShell 5.1 or PowerShell 7 on Windows and Git. Runtime FFmpeg
stays external. The supplied tool record is checked against the installed tools;
test references are caller-supplied evidence, not a release authorization.

OutputDirectory must be new, outside SourcePath, with an existing safe parent.
The builder publishes the three complete local assets by one directory move.
It performs no download, Git write, tag, upload or release operation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$SourceCommit,
    [Parameter(Mandatory = $true)][string]$TargetTag,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$DependencyProvenancePath,
    [Parameter(Mandatory = $true)][string]$TestEvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PackageFullPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not [IO.Path]::IsPathRooted($Path) -or
        $Path -match '^[\\/]{2}[?.]' -or $Path -match '^[A-Za-z]+:.*:' -or
        $Path -match '[\x00-\x1f]' -or $Path -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+[\\/])') {
        throw 'Package paths must be absolute ordinary Windows filesystem paths without device namespaces or streams.'
    }
    # Framework GetFullPath can erase trailing dots; reject aliases in raw input.
    if ($Path -match '(?:^|[\\/])[^\\/]*[. ](?:[\\/]|$)') {
        throw 'Package paths cannot contain trailing dot/space aliases or dot traversal components.'
    }
    $fullPath = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.Substring($root.Length) -match ':|[<>"|?*]' -or
        @($fullPath.Substring($root.Length) -split '[\\/]' | Where-Object { $_ -match '[. ]$' }).Count -ne 0) {
        throw 'Package paths cannot contain streams, wildcard characters or trailing dot/space aliases.'
    }
    if ($fullPath -eq $root) { return $root }
    return $fullPath.TrimEnd('\', '/')
}

function Assert-PackageNoReparse {
    param([string]$Path)
    $cursor = Get-PackageFullPath $Path
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Package paths cannot contain symlinks or reparse ancestors.'
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Test-PackageWithin {
    param([string]$Path, [string]$Root)
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Invoke-PackageGit {
    param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rows = @(& git --no-optional-locks -C $script:PackageSource @Arguments 2>&1)
        $nativeCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($AllowedExitCodes -notcontains $nativeCode) { throw "Package Git read failed (exit $nativeCode)." }
    return [pscustomobject]@{ ExitCode = $nativeCode; Lines = @($rows | ForEach-Object { [string]$_ }) }
}

function Assert-PackageCleanSource {
    $head = Invoke-PackageGit @('rev-parse', '--verify', 'HEAD')
    if ($head.Lines.Count -ne 1 -or $head.Lines[0] -cne $SourceCommit) { throw 'SourceCommit must match checkout HEAD exactly.' }
    $branch = Invoke-PackageGit @('symbolic-ref', '--quiet', 'HEAD') @(0, 1)
    if ($branch.ExitCode -ne 1 -or $branch.Lines.Count -ne 0) { throw 'Package source must use detached HEAD.' }
    $status = Invoke-PackageGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')
    if ($status.Lines.Count -ne 0) { throw 'Package source must be clean; dirty, untracked and ignored files are refused.' }
}

function Assert-PackageMemberName {
    param([string]$Name)
    # Only the reviewed inert pin may be nested; all other files remain root-only.
    if ($Name -ceq 'tools/ffmpeg-download.json') { return }
    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Name -eq '.' -or $Name -eq '..' -or
        $Name.EndsWith('.') -or $Name -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
        throw 'Unsafe package member name; only literal ordinary root file names are allowed.'
    }
}

function Get-PackageHash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Read-PackageJson {
    param([string]$Path)
    Assert-PackageNoReparse $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -gt 1048576) { throw 'Package input JSON must be a regular file at most 1 MiB.' }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
}

function Write-PackageJson {
    param([string]$Path, [object]$Document)
    $json = ($Document | ConvertTo-Json -Depth 20) + "`n"
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function Assert-PackageHttpsUrl {
    param([string]$Value)
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -cne 'https' -or
        -not [string]::IsNullOrEmpty($uri.UserInfo) -or -not [string]::IsNullOrEmpty($uri.Query) -or
        -not [string]::IsNullOrEmpty($uri.Fragment)) {
        throw 'Dependency source_url must be an HTTPS provenance URL without credentials, query or fragment.'
    }
}

function Get-PackageDependencies {
    param([object]$Record)
    if ($Record.schema_version -ne 1) { throw 'Dependency provenance requires schema_version 1.' }
    $paths = @{}
    foreach ($name in @('ffmpeg', 'ffprobe')) {
        $tool = $Record.$name
        $path = Get-PackageFullPath ([string]$tool.path)
        Assert-PackageNoReparse $path
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.PSIsContainer -or $item.Name -ine ($name + '.exe')) { throw "Dependency $name must be its resolved external executable." }
        if (Test-PackageWithin $path $script:PackageSource) { throw 'Runtime dependencies must remain external to the package source.' }
        if ([string]$tool.sha256 -cnotmatch '^[a-f0-9]{64}$' -or (Get-PackageHash $path) -cne [string]$tool.sha256) {
            throw "Dependency $name executable hash mismatch."
        }
        if ([string]$tool.version -notmatch ('^' + $name + ' version \S') -or
            [string]::IsNullOrWhiteSpace([string]$tool.license_notice) -or
            [string]$tool.license_notice -match '[\x00-\x1f]|[A-Za-z]:[\\/]|\\\\') { throw 'Dependency version and public license notice are required without private paths.' }
        Assert-PackageHttpsUrl ([string]$tool.source_url)
        $paths[$name] = $path
    }
    # Use the exact-C runtime helper's bounded native runner; prove each release.
    $actual = @{}
    foreach ($name in @('ffmpeg', 'ffprobe')) {
        $arguments = if ($name -eq 'ffmpeg') { @('-nostdin', '-version') } else { @('-version') }
        $native = Invoke-AudioNativeProcess -ExecutablePath $paths[$name] -Arguments $arguments
        if ($native.Status -cne 'Completed' -or $native.ExitCode -ne 0 -or $native.StdoutTruncated -or
            $native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) {
            throw "Dependency $name successful version query and native process release were not established."
        }
        $actual[$name] = ($native.Stdout -split '\r?\n')[0]
    }
    $encoders = Invoke-AudioNativeProcess -ExecutablePath $paths.ffmpeg -Arguments @('-nostdin', '-hide_banner', '-encoders')
    if ($encoders.Status -cne 'Completed' -or $encoders.ExitCode -ne 0 -or $encoders.StdoutTruncated -or
        $encoders.ProcessReleased -isnot [bool] -or -not $encoders.ProcessReleased -or
        ($encoders.Stdout + "`n" + $encoders.Stderr) -notmatch '(?m)^\s*A\S*\s+libmp3lame\s') {
        throw 'External FFmpeg libmp3lame capability and native process release were not established.'
    }
    $result = [ordered]@{ bundled = $false }
    foreach ($name in @('ffmpeg', 'ffprobe')) {
        $tool = $Record.$name
        if ($actual[$name] -cne [string]$tool.version -or (Get-PackageHash $paths[$name]) -cne [string]$tool.sha256) {
            throw "Dependency $name version or post-check executable hash mismatch."
        }
        $result[$name] = [ordered]@{
            executable_name = $name + '.exe'; version = [string]$actual[$name]
            sha256 = [string]$tool.sha256; source_url = [string]$tool.source_url
            license_notice = [string]$tool.license_notice
        }
    }
    return $result
}

function Get-PackageTests {
    param([object]$Record)
    if ($Record.schema_version -ne 1 -or @($Record.tests).Count -lt 1) { throw 'Test evidence requires schema_version 1 and at least one actual passing reference.' }
    $result = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($test in @($Record.tests)) {
        $reference = [string]$test.reference
        if ($reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $reference -match '(?:^|/)\.\.?(?:/|$)|//|/$' -or
            -not $seen.Add($reference) -or [string]$test.tested_commit -cne $SourceCommit -or
            [string]$test.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [string]$test.status -cne 'pass') {
            throw 'Each test reference must be unique, safe, passing and identify SourceCommit with a SHA-256 report digest.'
        }
        $result += [ordered]@{ reference = $reference; tested_commit = [string]$test.tested_commit; sha256 = [string]$test.sha256; status = 'pass' }
    }
    return $result
}

$stage = $null
$stageFiles = New-Object 'System.Collections.Generic.List[string]'
$stageDirectories = New-Object 'System.Collections.Generic.List[string]'
$buildFailure = $null
$buildResult = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Package building is supported on Windows only.' }
    if ($SourceCommit -cnotmatch '^[a-f0-9]{40}$') { throw 'SourceCommit requires the full lowercase 40-character commit identifier.' }
    $null = Get-Command git -CommandType Application -ErrorAction Stop
    $script:PackageSource = Get-PackageFullPath $SourcePath
    Assert-PackageNoReparse $script:PackageSource
    if (-not (Get-Item -LiteralPath $script:PackageSource -Force).PSIsContainer) { throw 'SourcePath must be the checkout root directory.' }
    $top = Invoke-PackageGit @('rev-parse', '--show-toplevel')
    if ($top.Lines.Count -ne 1 -or -not (Get-PackageFullPath $top.Lines[0]).Equals($script:PackageSource, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'SourcePath must be the checkout root directory.'
    }
    Assert-PackageCleanSource
    $output = Get-PackageFullPath $OutputDirectory
    $outputParent = [IO.Path]::GetDirectoryName($output)
    if (Test-PackageWithin $output $script:PackageSource) { throw 'OutputDirectory must be outside the source checkout.' }
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory already exists; select a new directory.' }
    Assert-PackageNoReparse $outputParent
    if (-not (Get-Item -LiteralPath $outputParent -Force).PSIsContainer) { throw 'OutputDirectory requires an existing parent directory.' }
    $dependencyPath = Get-PackageFullPath $DependencyProvenancePath
    $testsPath = Get-PackageFullPath $TestEvidencePath
    if ((Test-PackageWithin $dependencyPath $script:PackageSource) -or (Test-PackageWithin $testsPath $script:PackageSource)) {
        throw 'Package dependency provenance and test evidence JSON must be external to the source checkout.'
    }
    $dependencyRecord = Read-PackageJson $dependencyPath
    $testsRecord = Read-PackageJson $testsPath
    $inputHashes = [ordered]@{ dependency_provenance_sha256 = Get-PackageHash $dependencyPath; test_evidence_sha256 = Get-PackageHash $testsPath }

    $buildPaths = @('tools/Build-Package.ps1', 'tools/package-files.json')
    foreach ($relative in $buildPaths) {
        $path = Join-Path $script:PackageSource $relative
        Assert-PackageNoReparse $path
        $tree = Invoke-PackageGit @('ls-tree', $SourceCommit, '--', $relative)
        if ($tree.Lines.Count -ne 1 -or $tree.Lines[0] -notmatch '^100(?:644|755) blob [a-f0-9]{40}\t') {
            throw 'Exact source commit must contain regular builder and allowlist files.'
        }
    }
    if (-not (Get-PackageFullPath $PSCommandPath).Equals((Join-Path $script:PackageSource 'tools/Build-Package.ps1'), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Invoke the builder contained in the supplied source checkout.'
    }
    # Git show returns JSON text from C, independent of checkout line endings.
    $allowlistText = Invoke-PackageGit @('show', ($SourceCommit + ':tools/package-files.json'))
    $allowlist = ($allowlistText.Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop
    if ($allowlist.schema_version -ne 1) { throw 'Package allowlist requires schema_version 1.' }
    $members = @($allowlist.files)
    $required = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.ManagedSetup.ps1', 'tools/ffmpeg-download.json', 'AudioFileForPhone.bat', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'README.md', 'SUPPORT.md', 'CHANGELOG.md', 'SECURITY.md', 'LICENSE')
    $unique = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($member in $members) {
        if ($member -isnot [string]) { throw 'Package allowlist files must be strings.' }
        Assert-PackageMemberName $member
        if (-not $unique.Add($member)) { throw 'Duplicate package allowlist member.' }
        if ($required -cnotcontains $member) { throw 'Unexpected package allowlist member; update reviewed package policy before adding files.' }
        Assert-PackageNoReparse (Join-Path $script:PackageSource $member)
    }
    if ($members.Count -ne $required.Count -or @($required | Where-Object { $members -cnotcontains $_ }).Count -ne 0) { throw 'Package allowlist omits a required distributable file.' }
    [string[]]$members = $members
    [Array]::Sort($members, [StringComparer]::Ordinal)
    foreach ($member in $members) {
        $tree = Invoke-PackageGit @('ls-tree', $SourceCommit, '--', $member)
        if ($tree.Lines.Count -ne 1 -or $tree.Lines[0] -notmatch '^100(?:644|755) blob [a-f0-9]{40}\t') { throw 'Required package file omitted or not a regular Git blob.' }
    }

    # One unique sibling staging directory is the only writable build workspace.
    $stage = Join-Path $outputParent ('.afp-package-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $stage) { throw 'Unexpected staging collision.' }
    $null = [IO.Directory]::CreateDirectory($stage)
    $stagedSource = Join-Path $stage 'source'
    $null = [IO.Directory]::CreateDirectory($stagedSource)
    $stageDirectories.Add($stagedSource)
    $stagedTools = Join-Path $stagedSource 'tools'
    $null = [IO.Directory]::CreateDirectory($stagedTools)
    $stageDirectories.Add($stagedTools)
    $gitZip = Join-Path $stage 'git-source.zip'
    $stageFiles.Add($gitZip)
    # Archive must preserve blob bytes regardless of ambient checkout EOL policy.
    # Overrides apply only to this Git invocation; attributes remain verified below.
    $null = Invoke-PackageGit (@('-c', 'core.autocrlf=false', '-c', 'core.eol=lf', 'archive', '--format=zip', ('--output=' + $gitZip), $SourceCommit, '--') + $members + $buildPaths)
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $sourceArchive = [IO.Compression.ZipFile]::OpenRead($gitZip)
    try {
        $expected = @($members) + $buildPaths
        $found = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($entry in $sourceArchive.Entries) {
            if ($entry.FullName -ceq 'tools/' -and $entry.Length -eq 0) { continue }
            if ($expected -cnotcontains $entry.FullName -or -not $found.Add($entry.FullName) -or $entry.Length -gt 10485760) { throw 'Unexpected, duplicate, excessive or unsafe source archive entry.' }
            $path = Join-Path $stagedSource $entry.FullName
            $stageFiles.Add($path)
            $inputStream = $entry.Open()
            $outputStream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
            $blob = Invoke-PackageGit @('rev-parse', ($SourceCommit + ':' + $entry.FullName))
            $actualBlob = Invoke-PackageGit @('hash-object', '--no-filters', '--', $path)
            if ($blob.Lines.Count -ne 1 -or $actualBlob.Lines.Count -ne 1 -or $blob.Lines[0] -cne $actualBlob.Lines[0]) {
                throw 'Staged source bytes differ from exact commit blob (archive attributes are unsupported).'
            }
        }
        if ($found.Count -ne $expected.Count) { throw 'Source archive omitted a required file.' }
    } finally { $sourceArchive.Dispose() }

    $helperPath = Join-Path $stagedSource 'AudioFileForPhone.Helpers.ps1'
    $tokens = $null; $parseErrors = $null
    $helperAst = [Management.Automation.Language.Parser]::ParseFile($helperPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0 -or $null -ne $helperAst.BeginBlock -or $null -ne $helperAst.ProcessBlock -or
        @($helperAst.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count -ne 0) {
        throw 'Exact commit helper must be an inert functions-only file.'
    }
    . $helperPath
    $appVersion = Get-AudioAppVersion
    if ($appVersion -isnot [string] -or $appVersion -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -or $TargetTag -cne ('v' + $appVersion)) {
        throw 'TargetTag must match the exact source helper application version.'
    }
    $dependencies = Get-PackageDependencies $dependencyRecord
    $tests = @(Get-PackageTests $testsRecord)
    $zipName = 'AudioFileForPhone-' + $TargetTag + '.zip'
    $zipPath = Join-Path $stage $zipName
    $stageFiles.Add($zipPath)
    $fileHashes = [ordered]@{}
    $fileBytes = [ordered]@{}
    $signatures = [ordered]@{}
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($member in $members) {
            $path = Join-Path $stagedSource $member
            $fileHashes[$member] = Get-PackageHash $path
            $fileBytes[$member] = (Get-Item -LiteralPath $path -Force).Length
            if ($member.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
                $signature = Get-AuthenticodeSignature -LiteralPath $path -ErrorAction Stop
                $signatures[$member] = [ordered]@{
                    status = [string]$signature.Status
                    signer_thumbprint = $(if ($null -eq $signature.SignerCertificate) { $null } else { $signature.SignerCertificate.Thumbprint })
                }
            }
            $entry = $zip.CreateEntry($member, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $entry.ExternalAttributes = 0
            $inputStream = [IO.File]::OpenRead($path)
            $outputStream = $entry.Open()
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    } finally { $zip.Dispose() }
    $verifiedZip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($verifiedZip.Entries.Count -ne $members.Count) { throw 'Built ZIP inventory count mismatch.' }
        for ($index = 0; $index -lt $members.Count; $index++) {
            $entry = $verifiedZip.Entries[$index]
            $member = $members[$index]
            if ($entry.FullName -cne $member -or $entry.Length -ne $fileBytes[$member] -or $entry.ExternalAttributes -ne 0) { throw 'Built ZIP inventory, size or attributes mismatch.' }
            $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
            try { $digest = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
            if ($digest -cne $fileHashes[$member]) { throw 'Built ZIP member hash mismatch.' }
        }
    } finally { $verifiedZip.Dispose() }
    $zipHash = Get-PackageHash $zipPath
    $signatureStates = @($signatures.Values | ForEach-Object { $_.status })
    $signingStatus = if (@($signatureStates | Where-Object { $_ -cne 'NotSigned' }).Count -eq 0) { 'unsigned' }
        elseif (@($signatureStates | Where-Object { $_ -cne 'Valid' }).Count -eq 0) { 'signed_valid_on_build_host' } else { 'mixed_or_invalid' }
    $manifest = [ordered]@{
        schema_version = 1; repository = 'PikkuJanne/AudioFileForPhone'; app_version = $appVersion
        tag = $TargetTag; release_commit = $SourceCommit
        zip = [ordered]@{ name = $zipName; bytes = (Get-Item -LiteralPath $zipPath -Force).Length; sha256 = $zipHash }
        signing_status = $signingStatus; signatures = $signatures; dependencies = $dependencies
        files = $fileHashes; file_bytes = $fileBytes; test_evidence = $tests
        build = [ordered]@{
            source_mode = 'clean_detached_exact_git_blobs'; archive_order = 'Ordinal'; zip_timestamp_utc = '1980-01-01T00:00:00Z'
            powershell_version = $PSVersionTable.PSVersion.ToString(); powershell_edition = $PSVersionTable.PSEdition
            git_version = (Invoke-PackageGit @('--version')).Lines[0]
            builder_sha256 = Get-PackageHash (Join-Path $stagedTools 'Build-Package.ps1')
            allowlist_sha256 = Get-PackageHash (Join-Path $stagedTools 'package-files.json')
            inputs = $inputHashes
            evidence_scope = 'Supplied passing report references; this build does not establish release acceptance or authorization.'
        }
    }
    $manifestPath = Join-Path $stage 'release-manifest.json'
    $stageFiles.Add($manifestPath)
    Write-PackageJson $manifestPath $manifest
    $manifestHash = Get-PackageHash $manifestPath
    $checksumsPath = Join-Path $stage 'SHA256SUMS.txt'
    $stageFiles.Add($checksumsPath)
    [IO.File]::WriteAllText($checksumsPath, ($zipHash + '  ' + $zipName + "`n" + $manifestHash + "  release-manifest.json`n"), (New-Object Text.UTF8Encoding($false)))
    Assert-PackageCleanSource
    if ((Get-PackageHash $dependencyPath) -cne $inputHashes.dependency_provenance_sha256 -or
        (Get-PackageHash $testsPath) -cne $inputHashes.test_evidence_sha256) { throw 'Package provenance input changed during the build.' }
    # Remove only explicit owned staging files; never recursively delete source or output.
    foreach ($path in @($stageFiles.ToArray())) {
        if ((Test-PackageWithin $path $stagedSource) -or $path -ceq $gitZip) {
            Assert-PackageNoReparse $path; [IO.File]::Delete($path); $null = $stageFiles.Remove($path)
        }
    }
    for ($index = $stageDirectories.Count - 1; $index -ge 0; $index--) {
        Assert-PackageNoReparse $stageDirectories[$index]; [IO.Directory]::Delete($stageDirectories[$index], $false)
    }
    $stageDirectories.Clear()
    Assert-PackageNoReparse $stage
    Assert-PackageNoReparse $outputParent
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory appeared during the build; it was not replaced.' }
    [IO.Directory]::Move($stage, $output)
    $stage = $null
    $buildResult = [ordered]@{ status = 'pass'; source_commit = $SourceCommit; app_version = $appVersion; output_directory = $output; zip_name = $zipName; zip_sha256 = $zipHash; manifest_sha256 = $manifestHash }
} catch { $buildFailure = $_.Exception.Message }
finally {
    if ($null -ne $stage -and (Test-Path -LiteralPath $stage)) {
        try {
            Assert-PackageNoReparse $stage
            foreach ($path in $stageFiles) {
                if (-not (Test-PackageWithin $path $stage)) { throw 'Staging cleanup ownership mismatch.' }
                if (Test-Path -LiteralPath $path) { Assert-PackageNoReparse $path; [IO.File]::Delete($path) }
            }
            for ($index = $stageDirectories.Count - 1; $index -ge 0; $index--) {
                if (Test-Path -LiteralPath $stageDirectories[$index]) {
                    Assert-PackageNoReparse $stageDirectories[$index]; [IO.Directory]::Delete($stageDirectories[$index], $false)
                }
            }
            [IO.Directory]::Delete($stage, $false)
        } catch { $buildFailure = [string]$buildFailure + ' Owned staging cleanup failed; retained for inspection: ' + $_.Exception.Message }
    }
}
if ($null -ne $buildFailure) { throw $buildFailure }
$buildResult | ConvertTo-Json -Depth 4
