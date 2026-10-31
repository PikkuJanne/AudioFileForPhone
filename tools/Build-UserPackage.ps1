<#
.SYNOPSIS
Builds the corrective v1.0.5 candidate in a small end-user layout.
.DESCRIPTION
Follow-up to Build-Package.ps1: binds every core member and the existing icon to
an explicit clean detached source commit. A reviewed subset stays under app/;
the root contains only the direct BAT, existing ICO and short README.txt.
BATs receive explicit CRLF and the root converter target moves under app/.
The owner-selected corrective identity is v1.0.5. This operation establishes no
acceptance, publication, tag creation or upload authority.
No download, audio conversion, repository change or existing output write.
The new output directory receives complete assets through one directory move.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourcePath,
    [Parameter(Mandatory = $true)][string]$SourceCommit,
    [Parameter(Mandatory = $true)][string]$RuntimeAssetDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$PackageTestEvidencePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$appVersion = '1.0.5'
$targetTag = 'v1.0.5'
$zipName = 'AudioFileForPhone-v1.0.5.zip'
$coreZipName = $zipName
$payloadNames = @(
    'AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1',
    'AudioFileForPhone.ManagedSetup.ps1', 'AudioFileForPhone.Launcher.ps1',
    'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Diagnostics.ps1',
    'AudioFileForPhone.Checks.ps1', 'Check-AudioFileForPhone.ps1',
    'Check-AudioFileForPhone.bat', 'tools/ffmpeg-download.json',
    'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat',
    'AudioFileForPhone.bat', 'README.md', 'SUPPORT.md', 'CHANGELOG.md',
    'SECURITY.md', 'LICENSE'
)
[Array]::Sort($payloadNames, [StringComparer]::Ordinal)
# This is the final distribution allowlist, not an enumeration of the checkout.
$appNames = @(
    'AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1',
    'AudioFileForPhone.ManagedSetup.ps1', 'AudioFileForPhone.Diagnostics.ps1',
    'AudioFileForPhone.Checks.ps1', 'Check-AudioFileForPhone.ps1',
    'tools/ffmpeg-download.json', 'Setup-AudioFileForPhone.ps1',
    'Setup-AudioFileForPhone.bat', 'README.md', 'SUPPORT.md', 'CHANGELOG.md',
    'SECURITY.md', 'LICENSE'
)
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$stage = $null
$ownedFiles = New-Object 'Collections.Generic.List[string]'

function Get-UserPackagePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '^[\\/]{2}[?.]' -or
        $Path -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+[\\/])' -or
        $Path -match '[\x00-\x1f<>"|?*]' -or $Path -match '^[A-Za-z]:.*:' -or
        $Path -match '(?:^|[\\/])[^\\/]*[. ](?:[\\/]|$)') {
        throw 'Use an absolute ordinary Windows path without devices, streams, wildcards or dot/space aliases.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Substring($root.Length).Contains(':') -or $full -eq $root) {
        throw 'A non-root ordinary filesystem path is required.'
    }
    return $full.TrimEnd('\', '/')
}

function Assert-UserPackageNoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Package paths and their ancestors cannot contain reparse points.'
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Test-UserPackageWithin {
    param([string]$Path, [string]$Root)
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)
}

function Get-UserPackageBytesHash {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Read-UserPackageBytes {
    param([string]$Path, [long]$MaximumBytes)
    Assert-UserPackageNoReparse $Path
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        if ($stream.Length -lt 1 -or $stream.Length -gt $MaximumBytes) { throw 'Input file exceeds its package bound.' }
        $bytes = New-Object byte[] ([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { throw 'Input ended before its advertised length.' }
            $offset += $count
        }
        return ,$bytes
    }
    finally { $stream.Dispose() }
}

function ConvertFrom-UserPackageUtf8 {
    param([byte[]]$Bytes)
    $text = $utf8.GetString($Bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xfeff) { $text = $text.Substring(1) }
    return $text
}

function Invoke-UserPackageSourceGit {
    param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $rows = @(& $gitPath --no-optional-locks -C $sourceRoot @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $saved }
    if ($AllowedExitCodes -notcontains $code) { throw 'Exact source Git verification failed.' }
    return [pscustomobject]@{ code = $code; lines = @($rows | ForEach-Object { [string]$_ }) }
}

function Assert-UserPackageSource {
    $head = Invoke-UserPackageSourceGit @('rev-parse', '--verify', 'HEAD')
    $branch = Invoke-UserPackageSourceGit @('symbolic-ref', '--quiet', 'HEAD') @(0, 1)
    $status = Invoke-UserPackageSourceGit @('status', '--porcelain=v1', '--untracked-files=all', '--ignored=matching')
    if ($head.lines.Count -ne 1 -or $head.lines[0] -cne $SourceCommit -or
        $branch.code -ne 1 -or $branch.lines.Count -ne 0 -or $status.lines.Count -ne 0) {
        throw 'SourcePath must be a clean detached checkout of SourceCommit, without untracked or ignored files.'
    }
}

function Read-UserPackageSourceBlob {
    param([string]$Name)
    if ($Name -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|tools/(?:ffmpeg-download\.json|Build-UserPackage\.ps1))$') {
        throw 'Unexpected exact-source blob path.'
    }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $gitPath; $info.WorkingDirectory = $sourceRoot
    $info.Arguments = 'cat-file blob ' + $SourceCommit + ':' + $Name
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    $buffer = New-Object IO.MemoryStream
    try {
        if (-not $process.Start()) { throw 'Cannot read exact source blob.' }
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $process.WaitForExit(); $null = $errorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or $buffer.Length -lt 1 -or $buffer.Length -gt 10485760) {
            throw 'Missing or excessive exact source blob.'
        }
        return ,$buffer.ToArray()
    } finally { $buffer.Dispose(); $process.Dispose() }
}

function New-UserPackageBat {
    param([byte[]]$Bytes, [string]$Before, [string]$After)
    $text = ConvertFrom-UserPackageUtf8 $Bytes
    if ([regex]::Matches($text, [regex]::Escape($Before)).Count -ne 1) {
        throw 'Original BAT target assignment must occur exactly once.'
    }
    # Preserve the original argument transport, validation, policy and exit logic.
    return ,$utf8.GetBytes($text.Replace($Before, $After).Replace("`r`n", "`n").Replace("`n", "`r`n"))
}

function Write-UserPackageNewText {
    param([string]$Path, [string]$Text)
    $bytes = $utf8.GetBytes($Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Build the Windows distribution on Windows.' }
    $inputRoot = Get-UserPackagePath $RuntimeAssetDirectory
    $output = Get-UserPackagePath $OutputDirectory
    $repository = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\', '/')
    Assert-UserPackageNoReparse $inputRoot
    if (-not (Get-Item -LiteralPath $inputRoot -Force).PSIsContainer) { throw 'RuntimeAssetDirectory must be a directory.' }
    if (Test-UserPackageWithin $output $repository) { throw 'OutputDirectory must be outside the repository.' }
    if (Test-UserPackageWithin $output $inputRoot) { throw 'OutputDirectory must be outside the original asset directory.' }
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory already exists and will not be replaced.' }
    $outputParent = [IO.Path]::GetDirectoryName($output)
    Assert-UserPackageNoReparse $outputParent
    if (-not (Get-Item -LiteralPath $outputParent -Force).PSIsContainer) { throw 'OutputDirectory needs an existing parent.' }

    if ($SourceCommit -cnotmatch '^[a-f0-9]{40}$') { throw 'SourceCommit must be a full lowercase commit SHA.' }
    $sourceRoot = Get-UserPackagePath $SourcePath
    Assert-UserPackageNoReparse $sourceRoot
    $gitPath = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    Assert-UserPackageSource
    $builderBytes = Read-UserPackageSourceBlob 'tools/Build-UserPackage.ps1'
    $builderHash = Get-UserPackageBytesHash $builderBytes
    $runningBuilder = Read-UserPackageBytes $PSCommandPath 1048576
    if ((ConvertFrom-UserPackageUtf8 $builderBytes).Replace("`r`n", "`n") -cne
        (ConvertFrom-UserPackageUtf8 $runningBuilder).Replace("`r`n", "`n")) {
        throw 'Run the builder bytes recorded in SourceCommit.'
    }
    if (Test-UserPackageWithin $output $sourceRoot) { throw 'OutputDirectory must be outside SourcePath.' }
    $originalBytes = @{}; $originalHashes = [ordered]@{}
    foreach ($name in @($coreZipName, 'release-manifest.json', 'SHA256SUMS.txt')) {
        $limit = if ($name -ceq 'SHA256SUMS.txt') { 4096 } elseif ($name -ceq 'release-manifest.json') { 1048576 } else { 2097152 }
        $bytes = Read-UserPackageBytes (Join-Path $inputRoot $name) $limit
        $originalBytes[$name] = $bytes; $originalHashes[$name] = Get-UserPackageBytesHash $bytes
    }
    $originalManifest = (ConvertFrom-UserPackageUtf8 $originalBytes['release-manifest.json']) | ConvertFrom-Json
    $expectedChecksums = $originalHashes[$coreZipName] + '  ' + $coreZipName + "`n" +
        $originalHashes['release-manifest.json'] + "  release-manifest.json`n"
    if ((ConvertFrom-UserPackageUtf8 $originalBytes['SHA256SUMS.txt']).Replace("`r`n", "`n") -cne $expectedChecksums) {
        throw 'Core external checksum rows must bind exactly the core ZIP and manifest.'
    }
    if ($originalManifest.schema_version -ne 1 -or $originalManifest.repository -cne 'PikkuJanne/AudioFileForPhone' -or
        $originalManifest.app_version -cne $appVersion -or $originalManifest.tag -cne $targetTag -or
        $originalManifest.release_commit -cne $SourceCommit -or $originalManifest.zip.name -cne $coreZipName -or
        $originalManifest.zip.sha256 -cne $originalHashes[$coreZipName] -or
        $originalManifest.zip.bytes -ne $originalBytes[$coreZipName].Length -or
        @($originalManifest.files.PSObject.Properties).Count -ne 18 -or
        @($originalManifest.file_bytes.PSObject.Properties).Count -ne 18) {
        throw 'Core manifest must identify the explicit current source and expected input inventory.'
    }

    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $payload = @{}
    $memory = New-Object IO.MemoryStream(,$originalBytes[$coreZipName])
    $archive = New-Object IO.Compression.ZipArchive($memory, [IO.Compression.ZipArchiveMode]::Read, $false)
    try {
        if ($archive.Entries.Count -ne 18) { throw 'Original ZIP must contain exactly eighteen files.' }
        $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $expanded = 0L
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if ($payloadNames -cnotcontains $name -or -not $seen.Add($name) -or
                $entry.Length -lt 1 -or $entry.Length -gt 10485760 -or
                $entry.Length -ne $originalManifest.file_bytes.$name) {
                throw 'Original ZIP has an unexpected, duplicate, unsafe or out-of-bounds member.'
            }
            $expanded += $entry.Length
            if ($expanded -gt 16777216) { throw 'Original payload exceeds its total expansion bound.' }
            $stream = $entry.Open(); $buffer = New-Object IO.MemoryStream
            try { $stream.CopyTo($buffer); $bytes = $buffer.ToArray() }
            finally { $buffer.Dispose(); $stream.Dispose() }
            if ($bytes.Length -ne $entry.Length -or
                (Get-UserPackageBytesHash $bytes) -cne $originalManifest.files.$name) {
                throw 'Original ZIP member bytes do not match the original manifest.'
            }
            if ((Get-UserPackageBytesHash $bytes) -cne (Get-UserPackageBytesHash (Read-UserPackageSourceBlob $name))) {
                throw 'Core ZIP member does not match the explicit source commit.'
            }
            $payload[$name] = $bytes
        }
        if ($seen.Count -ne $payloadNames.Count) { throw 'Original ZIP omitted a required payload file.' }
    }
    finally { $archive.Dispose(); $memory.Dispose() }

    $members = @{}
    $mappings = @()
    foreach ($name in $appNames) {
        $destination = 'app/' + $name
        $members[$destination] = $payload[$name]
        $mappings += [ordered]@{ source_path = $name; archive_path = $destination; source_sha256 = $originalManifest.files.$name; method = $(if ($name -ceq 'Setup-AudioFileForPhone.bat') { 'Explicit CRLF' } else { 'Exact Git blob' }) }
    }
    $members['AudioFileForPhone.bat'] = New-UserPackageBat $payload['AudioFileForPhone.bat'] `
        'set "AFP_SCRIPT=%~dp0AudioFileForPhone.ps1"' 'set "AFP_SCRIPT=%~dp0app\AudioFileForPhone.ps1"'
    # Git stores LF; distribute explicit CRLF so CMD labels remain reliable.
    $setupText = (ConvertFrom-UserPackageUtf8 $payload['Setup-AudioFileForPhone.bat']).Replace("`r`n", "`n").Replace("`n", "`r`n")
    $members['app/Setup-AudioFileForPhone.bat'] = $utf8.GetBytes($setupText)
    $members['AudioFileForPhone.ico'] = Read-UserPackageSourceBlob 'AudioFileForPhone.ico'
    $mappings += [ordered]@{ source_path = 'AudioFileForPhone.ico'; archive_path = 'AudioFileForPhone.ico'; source_sha256 = Get-UserPackageBytesHash $members['AudioFileForPhone.ico']; method = 'Exact Git blob' }
    $readme = @'
AudioFileForPhone v1.0.5

Convert MP3, M4A and OGG folders to validated 64 kbps CBR MP3. Sources stay unchanged.

1. Extract the complete application ZIP into a new empty folder you want to keep.
2. Make a shortcut to AudioFileForPhone.bat. In shortcut Properties, Change Icon,
   choose the AudioFileForPhone.ico beside it. Keep the BAT, ICO and app/ together.
3. Drop one audio folder onto the shortcut (or BAT). Press Enter for defaults,
   M to customize metadata, or Q to cancel. Completed files go to a new run folder
   under Music, preserving relative folders and date-first filenames.

If tools are needed, select the folder containing both ffmpeg.exe and ffprobe.exe
when prompted, or open app/Setup-AudioFileForPhone.bat first. The separate setup
can remember that choice or offer an optional download with your consent.
Conversion never downloads tools. No FFmpeg binaries are bundled. Existing tools
can stay in a separate folder; no PATH edit or reinstall is required. App-local
tools, if wanted, belong beside the scripts in app/.
Existing PATH pairs and the FFMPEG environment setting are discovered automatically;
FFMPEG may name the pair's folder, its installation root, or ffmpeg.exe itself.

If an error stays visible, read it and the reported local log path. Restore the
complete package if a component is missing; consult app/SUPPORT.md. The final
key press closes the console and preserves its exit result.

Both BATs request ExecutionPolicy Bypass only for their child Windows PowerShell
process to run this trusted unsigned app, including downloaded scripts. No policy
or PATH change is saved. Managed policies and application control still apply;
if they refuse execution, the error stays visible and no other host is retried.

Download this version's application asset, AudioFileForPhone-v1.0.5.zip, from:
https://github.com/PikkuJanne/AudioFileForPhone/releases/tag/v1.0.5
Choose that application ZIP, rather than the autogenerated Source code archives.
Later application updates appear on the project's Releases page.

Detailed options: app/README.md. License: app/LICENSE. Security: app/SECURITY.md.
Optional setup notices and vendor provenance: app/tools/ffmpeg-download.json.
PowerShell users can run app/AudioFileForPhone.ps1 and app/Setup-AudioFileForPhone.ps1
with their existing options, including an explicit output directory.
'@
    $members['README.txt'] = $utf8.GetBytes($readme.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n")
    [string[]]$names = @($members.Keys)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    if ($names.Count -ne 17) { throw 'Clean package must contain exactly seventeen reviewed members.' }

    $stage = Join-Path $outputParent ('.afp-user-package-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $stage) { throw 'Unexpected owned staging collision.' }
    $null = [IO.Directory]::CreateDirectory($stage)
    $zipPath = Join-Path $stage $zipName; $ownedFiles.Add($zipPath)
    $hashes = [ordered]@{}; $lengths = [ordered]@{}
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $names) {
            [byte[]]$bytes = $members[$name]
            $hashes[$name] = Get-UserPackageBytesHash $bytes
            $lengths[$name] = $bytes.Length
            $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $entry.ExternalAttributes = 0
            $stream = $entry.Open()
            try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        }
    }
    finally { $zip.Dispose() }
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $verified = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($verified.Entries.Count -ne $names.Count) { throw 'Generated ZIP inventory mismatch.' }
        for ($index = 0; $index -lt $names.Count; $index++) {
            $entry = $verified.Entries[$index]; $name = $names[$index]
            if ($entry.FullName -cne $name -or $entry.Length -ne $lengths[$name] -or $entry.ExternalAttributes -ne 0) {
                throw 'Generated ZIP member order, size or attributes mismatch.'
            }
            $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
            if ($hash -cne $hashes[$name]) { throw 'Generated ZIP member digest mismatch.' }
        }
    }
    finally { $verified.Dispose() }

    $tests = $null
    if (-not [string]::IsNullOrWhiteSpace($PackageTestEvidencePath)) {
        $testPath = Get-UserPackagePath $PackageTestEvidencePath
        $testBytes = Read-UserPackageBytes $testPath 4194304
        $testRecord = (ConvertFrom-UserPackageUtf8 $testBytes) | ConvertFrom-Json
        if ($testRecord.schema_version -ne 1 -or $testRecord.kind -cne 'user_package_verification' -or
            $testRecord.status -cnotin @('PASSED', 'pass') -or
            $testRecord.app_version -cne $appVersion -or $testRecord.artifact_kind -cne 'corrective_release_candidate' -or
            $testRecord.source_commit -cne $SourceCommit -or
            $testRecord.runtime_zip_sha256 -cne $zipHash -or $testRecord.package_revision -ne 3) {
            throw 'Package evidence must be an actual passing v1.0.5 verification report bound to this exact source and ZIP.'
        }
        $tests = [ordered]@{ sha256 = Get-UserPackageBytesHash $testBytes; runtime_zip_sha256 = $zipHash; app_version = $appVersion; artifact_kind = 'corrective_release_candidate'; source_commit = $SourceCommit; status = [string]$testRecord.status; scope = 'Caller-supplied exact-package verification; no unrun client or human results or publication authority are inferred.' }
    }
    $generated = @()
    foreach ($name in @('AudioFileForPhone.bat', 'app/Setup-AudioFileForPhone.bat')) {
        $sourceName = $name -replace '^app/', ''
        $generated += [ordered]@{ path = $name; source_path = $sourceName; source_sha256 = $originalManifest.files.$sourceName; sha256 = $hashes[$name]; generator_sha256 = $builderHash; method = $(if ($name.StartsWith('app/')) { 'Explicit CRLF only' } else { 'Direct converter target under app/ and explicit CRLF; original literal transport/pause/exit preserved' }) }
    }
    $manifest = [ordered]@{
        schema_version = 1; repository = 'PikkuJanne/AudioFileForPhone'; app_version = $appVersion
        tag = $targetTag; release_commit = $SourceCommit; package_revision = 3; layout = 'app/'
        artifact_kind = 'corrective_release_candidate'; publication_authorized = $false
        corrective_release_version = $appVersion
        original_runtime_zip_sha256 = $originalHashes[$coreZipName]
        original_release_manifest_sha256 = $originalHashes['release-manifest.json']
        zip = [ordered]@{ name = $zipName; bytes = (Get-Item -LiteralPath $zipPath).Length; sha256 = $zipHash }
        files = $hashes; file_bytes = $lengths; source_to_archive = $mappings
        generated_entrypoints = $generated
        generated_readme = [ordered]@{ path = 'README.txt'; generator_sha256 = $builderHash; sha256 = $hashes['README.txt'] }
        icon = [ordered]@{ source_path = 'AudioFileForPhone.ico'; sha256 = $hashes['AudioFileForPhone.ico']; byte_identical = $true }
        dependencies = $originalManifest.dependencies
        package_test_evidence = $tests
        build = [ordered]@{ builder = 'tools/Build-UserPackage.ps1'; builder_sha256 = $builderHash; source_mode = 'Explicit clean detached Git source; every core blob verified; allowlisted app subset plus direct CRLF BAT and unchanged icon'; archive_order = 'Ordinal'; zip_timestamp_utc = '1980-01-01T00:00:00Z'; evidence_scope = 'Corrective v1.0.5 candidate only. The selected version and passing verification do not grant exact-byte publication authority. Preserve existing v1.0.0/v1.0.1/v1.0.2 tags and public assets.' }
    }
    $manifestPath = Join-Path $stage 'release-manifest.json'; $ownedFiles.Add($manifestPath)
    Write-UserPackageNewText $manifestPath (($manifest | ConvertTo-Json -Depth 20) + "`n")
    $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumsPath = Join-Path $stage 'SHA256SUMS.txt'; $ownedFiles.Add($sumsPath)
    Write-UserPackageNewText $sumsPath ($zipHash + '  ' + $zipName + "`n" + $manifestHash + "  release-manifest.json`n")
    foreach ($name in $originalHashes.Keys) {
        Assert-UserPackageNoReparse (Join-Path $inputRoot $name)
        if ((Get-FileHash -LiteralPath (Join-Path $inputRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $originalHashes[$name]) {
            throw 'Original asset changed during repackaging; completed output is not published.'
        }
    }
    Assert-UserPackageSource
    Assert-UserPackageNoReparse $stage
    Assert-UserPackageNoReparse $outputParent
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory appeared and will not be replaced.' }
    [IO.Directory]::Move($stage, $output)
    $stage = $null
    [ordered]@{ status = 'pass'; app_version = $appVersion; tag = $targetTag; artifact_kind = 'corrective_release_candidate'; package_revision = 3; source_commit = $SourceCommit; runtime_zip_sha256 = $zipHash; manifest_sha256 = $manifestHash; output_directory = $output; members = 17; original_payload_files_unchanged = 13; publication_authorized = $false } | ConvertTo-Json
}
finally {
    if ($null -ne $stage -and (Test-Path -LiteralPath $stage)) {
        # Only the three explicitly owned files and then the empty stage are removed.
        # No recursive removal or source/output cleanup is permitted.
        Assert-UserPackageNoReparse $stage
        foreach ($path in $ownedFiles) {
            if (-not (Test-UserPackageWithin $path $stage)) { throw 'Owned staging cleanup boundary mismatch.' }
            if (Test-Path -LiteralPath $path) { Assert-UserPackageNoReparse $path; [IO.File]::Delete($path) }
        }
        [IO.Directory]::Delete($stage, $false)
    }
}
