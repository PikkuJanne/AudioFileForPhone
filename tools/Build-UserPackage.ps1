<#
.SYNOPSIS
Repackages the published v1.0.1 payload into a clean end-user folder layout.
.DESCRIPTION
Follow-up to Build-Package.ps1: verifies its exact original published assets,
retains all eighteen payload files byte-for-byte under app/, and adds the four
compatible entry points, a short guide and LICENSE at the archive root.
Build-Package.ps1 remains the exact-source core payload builder. Generated
entry points are identified separately from retained source blobs in the new
manifest. This operation establishes no acceptance, release or upload authority.
No download, native tool execution, repository change or existing output write.
The new output directory receives complete assets through one directory move.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeAssetDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$PackageTestEvidencePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$sourceCommit = 'd9d7129e9463de17e29c2a36752c82e326abf22e'
$zipName = 'AudioFileForPhone-v1.0.1.zip'
$originalHashes = [ordered]@{
    'AudioFileForPhone-v1.0.1.zip' = '78ae51a2d5bcddc56ae64c4703a4e35baa340204c2647123fefaeb175dae8a53'
    'release-manifest.json' = '45f6f6022dbb3bf065804106af0b4e444a5bd5fdb3565876133120569008bda3'
    'SHA256SUMS.txt' = '298cbd7374fee37a400b0016fc7c4065939761c32140107dfdd2c2f9d3293e6f'
}
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

function New-UserPackageForwarder {
    param([byte[]]$Bytes, [string]$FileName)
    $text = ConvertFrom-UserPackageUtf8 $Bytes
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0 -or $null -eq $ast.ParamBlock -or
        $null -ne $ast.BeginBlock -or $null -ne $ast.ProcessBlock) {
        throw 'Original entry point must have one unambiguous script parameter block.'
    }
    $prefix = $text.Substring(0, $ast.ParamBlock.Extent.EndOffset)
    $body = @'


# Compatibility entry point. The complete implementation stays together in app/.
$implementation = Join-Path $PSScriptRoot 'app\__FILE__'
if (-not [IO.File]::Exists($implementation)) {
    Write-Error 'Required app/__FILE__ is missing. Extract the complete application ZIP.' -ErrorAction Continue
    exit 1
}
& $implementation @PSBoundParameters
exit $LASTEXITCODE
'@
    $body = $body.Replace('__FILE__', $FileName).Replace("`r`n", "`n").Replace("`n", "`r`n")
    $wrapper = $prefix + $body + "`r`n"
    $wrapperAst = [Management.Automation.Language.Parser]::ParseInput($wrapper, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0 -or $wrapperAst.ParamBlock.Extent.Text -cne $ast.ParamBlock.Extent.Text) {
        throw 'Generated compatibility entry point did not preserve its parameter contract.'
    }
    # BOM lets Windows PowerShell 5.1 read any non-ASCII comment help correctly.
    return ,([byte[]](@(239, 187, 191) + $utf8.GetBytes($wrapper)))
}

function New-UserPackageBat {
    param([byte[]]$Bytes, [string]$Before, [string]$After)
    $text = ConvertFrom-UserPackageUtf8 $Bytes
    if ([regex]::Matches($text, [regex]::Escape($Before)).Count -ne 1) {
        throw 'Original BAT target assignment must occur exactly once.'
    }
    # Preserve the original argument transport, validation, policy and exit logic.
    return ,$utf8.GetBytes($text.Replace($Before, $After))
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

    $originalBytes = @{}
    foreach ($name in $originalHashes.Keys) {
        $limit = if ($name -ceq 'SHA256SUMS.txt') { 4096 } elseif ($name -ceq 'release-manifest.json') { 1048576 } else { 2097152 }
        $bytes = Read-UserPackageBytes (Join-Path $inputRoot $name) $limit
        if ((Get-UserPackageBytesHash $bytes) -cne $originalHashes[$name]) {
            throw ('Original published asset hash mismatch: ' + $name)
        }
        $originalBytes[$name] = $bytes
    }
    $originalManifest = (ConvertFrom-UserPackageUtf8 $originalBytes['release-manifest.json']) | ConvertFrom-Json
    $expectedChecksums = $originalHashes[$zipName] + '  ' + $zipName + "`n" +
        $originalHashes['release-manifest.json'] + "  release-manifest.json`n"
    if ((ConvertFrom-UserPackageUtf8 $originalBytes['SHA256SUMS.txt']).Replace("`r`n", "`n") -cne $expectedChecksums) {
        throw 'Original external checksum rows must bind exactly the original ZIP and manifest.'
    }
    if ($originalManifest.schema_version -ne 1 -or $originalManifest.repository -cne 'PikkuJanne/AudioFileForPhone' -or
        $originalManifest.app_version -cne '1.0.1' -or $originalManifest.tag -cne 'v1.0.1' -or
        $originalManifest.release_commit -cne $sourceCommit -or $originalManifest.zip.name -cne $zipName -or
        $originalManifest.zip.sha256 -cne $originalHashes[$zipName] -or
        $originalManifest.zip.bytes -ne $originalBytes[$zipName].Length -or
        @($originalManifest.files.PSObject.Properties).Count -ne 18 -or
        @($originalManifest.file_bytes.PSObject.Properties).Count -ne 18) {
        throw 'Original payload manifest does not identify the exact published v1.0.1 source and inventory.'
    }

    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $payload = @{}
    $memory = New-Object IO.MemoryStream(,$originalBytes[$zipName])
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
            $payload[$name] = $bytes
        }
        if ($seen.Count -ne $payloadNames.Count) { throw 'Original ZIP omitted a required payload file.' }
    }
    finally { $archive.Dispose(); $memory.Dispose() }

    $members = @{}
    $mappings = @()
    foreach ($name in $payloadNames) {
        $destination = 'app/' + $name
        $members[$destination] = $payload[$name]
        $mappings += [ordered]@{ source_path = $name; archive_path = $destination; sha256 = $originalManifest.files.$name }
    }
    $members['AudioFileForPhone.bat'] = New-UserPackageBat $payload['AudioFileForPhone.bat'] `
        'set "AFP_LAUNCHER=%~dp0AudioFileForPhone.Launcher.ps1"' 'set "AFP_LAUNCHER=%~dp0app\AudioFileForPhone.Launcher.ps1"'
    $members['Setup-AudioFileForPhone.bat'] = New-UserPackageBat $payload['Setup-AudioFileForPhone.bat'] `
        'set "SETUP_SCRIPT=%~dp0Setup-AudioFileForPhone.ps1"' 'set "SETUP_SCRIPT=%~dp0app\Setup-AudioFileForPhone.ps1"'
    foreach ($name in @('AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1')) {
        $members[$name] = New-UserPackageForwarder $payload[$name] $name
    }
    $readme = @'
# AudioFileForPhone

Convert a folder of podcasts or audiobooks to 64 kbps MP3. Original audio stays unchanged.

1. Extract the entire ZIP into a new, empty folder you want to keep.
2. First time: open Setup-AudioFileForPhone.bat to select an existing FFmpeg folder,
   or choose its optional download after reviewing and accepting the prompt.
3. Drag one audio folder onto AudioFileForPhone.bat. Press Enter to use defaults.

Completed files go into a new run folder under your Music folder, keeping the
relative subfolders and date-first filenames. MP3, M4A and OGG input is supported.
Conversion never downloads tools. FFmpeg and ffprobe are not bundled.

Keep the app folder: it contains the program components and detailed instructions.
You do not need to open or edit those files for ordinary use. Advanced help and
support are in app/README.md and app/SUPPORT.md.

PowerShell users can run AudioFileForPhone.ps1 or Setup-AudioFileForPhone.ps1 here
with the existing command-line options. If using app-local FFmpeg discovery,
place both ffmpeg.exe and ffprobe.exe in app/, beside the actual implementation.
An explicit or saved selection can point to a separate trusted tools folder.

Version 1.0.1, package revision 2. This layout keeps the original program payload
unchanged and presents the launchers separately from its internal files.
'@
    $members['README.md'] = $utf8.GetBytes($readme.Replace("`r`n", "`n") + "`n")
    $members['LICENSE'] = $payload['LICENSE']
    [string[]]$names = @($members.Keys)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    if ($names.Count -ne 24) { throw 'Clean package must contain exactly twenty-four reviewed members.' }

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
        if ($testRecord.schema_version -ne 1 -or $testRecord.status -cnotin @('PASSED', 'pass') -or
            $testRecord.runtime_zip_sha256 -cne $zipHash -or $testRecord.package_revision -ne 2) {
            throw 'Package evidence must be an actual passing revision2 report bound to this exact clean ZIP.'
        }
        $tests = [ordered]@{ sha256 = Get-UserPackageBytesHash $testBytes; runtime_zip_sha256 = $zipHash; status = [string]$testRecord.status; scope = 'Caller-supplied new-layout report; no client or human results are inferred.' }
    }
    $builderHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $generated = @()
    foreach ($name in @('AudioFileForPhone.bat', 'AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'Setup-AudioFileForPhone.ps1')) {
        $generated += [ordered]@{ path = $name; source_path = $name; source_sha256 = $originalManifest.files.$name; sha256 = $hashes[$name]; generator_sha256 = $builderHash; method = $(if ($name.EndsWith('.ps1')) { 'Original help/attributes/parameter prefix plus PSBoundParameters forwarding and exit propagation.' } else { 'Original BAT with only the one implementation-target assignment changed to app/.' }) }
    }
    $manifest = [ordered]@{
        schema_version = 1; repository = 'PikkuJanne/AudioFileForPhone'; app_version = '1.0.1'
        tag = 'v1.0.1'; release_commit = $sourceCommit; package_revision = 2; layout = 'app/'
        original_runtime_zip_sha256 = $originalHashes[$zipName]
        original_release_manifest_sha256 = $originalHashes['release-manifest.json']
        zip = [ordered]@{ name = $zipName; bytes = (Get-Item -LiteralPath $zipPath).Length; sha256 = $zipHash }
        files = $hashes; file_bytes = $lengths; source_to_archive = $mappings
        generated_entrypoints = $generated
        generated_readme = [ordered]@{ path = 'README.md'; generator_sha256 = $builderHash; sha256 = $hashes['README.md'] }
        copied_license = [ordered]@{ source_path = 'LICENSE'; sha256 = $hashes['LICENSE'] }
        dependencies = $originalManifest.dependencies
        package_test_evidence = $tests
        build = [ordered]@{ builder = 'tools/Build-UserPackage.ps1'; builder_sha256 = $builderHash; source_mode = 'Pinned original published payload plus separately identified generated entrypoints'; archive_order = 'Ordinal'; zip_timestamp_utc = '1980-01-01T00:00:00Z'; evidence_scope = 'Original payload bytes are unchanged. Original acceptance does not establish the new generated entrypoints or layout; test this exact package separately. This build grants no publication authority.' }
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
    Assert-UserPackageNoReparse $stage
    Assert-UserPackageNoReparse $outputParent
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory appeared and will not be replaced.' }
    [IO.Directory]::Move($stage, $output)
    $stage = $null
    [ordered]@{ status = 'pass'; package_revision = 2; source_commit = $sourceCommit; runtime_zip_sha256 = $zipHash; manifest_sha256 = $manifestHash; output_directory = $output; members = 24; original_payload_files_unchanged = 18 } | ConvertTo-Json
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
