<#
.SYNOPSIS
Build a local acceptance kit around an existing, verified runtime package.
.DESCRIPTION
No Git, download, elevation or installation is used. Final mode requires the fixed
release target. Rehearsal explicitly permits the current runtime and never grants
release acceptance. The archive's digest is external to avoid a circular self-hash.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RuntimeAssetsDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$RunnerSourceDirectory,
    [switch]$Rehearsal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RunnerSourceDirectory)) { $RunnerSourceDirectory = Join-Path $PSScriptRoot 'acceptance' }

function Get-KitBuildPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -notmatch '^[A-Za-z]:[\\/]' -or
        $Path -match '[\x00-\x1f<>"|?*]' -or $Path.Substring(2) -match ':' -or
        $Path -match '(?:^|[\\/])(?:\.\.?|[^\\/]*[. ])(?:[\\/]|$)') {
        throw 'Kit paths must be absolute ordinary local filesystem paths without aliases, streams or wildcards.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -eq [IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd('\', '/')
}

function Assert-KitBuildNoReparse {
    param([string]$Path)
    $cursor = Get-KitBuildPath $Path
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Kit paths must not contain reparse points.' }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Test-KitBuildWithin {
    param([string]$Path, [string]$Root)
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Root.TrimEnd('\', '/') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Get-KitBuildHash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Read-KitBuildJson {
    param([string]$Path)
    Assert-KitBuildNoReparse $Path
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -lt 2 -or $item.Length -gt 4194304) { throw 'Kit JSON must be a regular file of at most 4 MiB.' }
    $text = [IO.File]::ReadAllText($Path, (New-Object Text.UTF8Encoding($false, $true)))
    if (-not $text.TrimStart([char]0xfeff).TrimStart().StartsWith('{')) { throw 'Kit JSON must contain one object.' }
    $document = $text | ConvertFrom-Json -ErrorAction Stop
    # Windows PowerShell can silently collapse repeated JSON keys. Detect them
    # per object, including escaped spellings, before trusting a hash inventory.
    $jsonTokens = [regex]::Matches($text, '"(?:[^"\\]|\\.)*"|[{}\[\]:,]|[^{}\[\]:,\s]+')
    $objects = New-Object 'System.Collections.Generic.Stack[object]'
    for ($index = 0; $index -lt $jsonTokens.Count; $index++) {
        $token = $jsonTokens[$index].Value
        if ($token -ceq '{') {
            $objects.Push([pscustomobject]@{ IsObject = $true; Names = (New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)) })
        } elseif ($token -ceq '[') { $objects.Push([pscustomobject]@{ IsObject = $false; Names = $null }) }
        elseif ($token -cin @('}', ']')) { $null = $objects.Pop() }
        elseif ($token.StartsWith('"') -and $index + 1 -lt $jsonTokens.Count -and $jsonTokens[$index + 1].Value -ceq ':') {
            $name = ('{"key":' + $token + '}' | ConvertFrom-Json -ErrorAction Stop).key
            if ($objects.Count -eq 0 -or -not $objects.Peek().IsObject -or -not $objects.Peek().Names.Add($name)) { throw 'Kit JSON contains a duplicate object member.' }
        }
    }
    return $document
}

function Get-KitBuildField {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object -or $null -eq $Object.PSObject.Properties[$Name]) { throw ('Required kit field is missing: ' + $Name) }
    return $Object.PSObject.Properties[$Name].Value
}

function Get-KitBuildStreamHash {
    param([IO.Stream]$Stream)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Assert-KitBuildArchive {
    param([string]$Path, [object[]]$Inventory, [hashtable]$Sizes, [string]$Version)
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        if ($archive.Entries.Count -ne $Inventory.Count) { throw 'Runtime archive member count differs from the manifest.' }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $helperText = $null
        foreach ($entry in $archive.Entries) {
            $member = @($Inventory | Where-Object { $_.path -ceq $entry.FullName })
            if ($member.Count -ne 1 -or -not $seen.Add($entry.FullName) -or $entry.ExternalAttributes -ne 0 -or
                $entry.Length -lt 0 -or $entry.Length -gt 10485760 -or $entry.Length -ne $Sizes[$entry.FullName]) {
                throw 'Runtime archive contains an unsafe, duplicate, unexpected or incorrectly sized member.'
            }
            $stream = $entry.Open()
            try { $hash = Get-KitBuildStreamHash $stream } finally { $stream.Dispose() }
            if ($hash -cne $member[0].sha256) { throw 'Runtime archive member hash differs from the external manifest.' }
            if ($entry.FullName -ceq 'AudioFileForPhone.Helpers.ps1') {
                $stream = $entry.Open(); $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false, $true)))
                try { $helperText = $reader.ReadToEnd() } finally { $reader.Dispose(); $stream.Dispose() }
            }
        }
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput($helperText, [ref]$tokens, [ref]$errors)
        if ($errors.Count -ne 0) { throw 'Packaged runtime helper does not parse.' }
        $functions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-AudioAppVersion' }, $true))
        if ($functions.Count -ne 1 -or $functions[0].Body.EndBlock.Statements.Count -ne 1 -or
            $functions[0].Body.EndBlock.Statements[0] -isnot [Management.Automation.Language.ReturnStatementAst]) { throw 'Packaged runtime version function is not the expected literal return.' }
        $value = $functions[0].Body.EndBlock.Statements[0].Pipeline.SafeGetValue()
        if ($value -isnot [string] -or $value -cne $Version) { throw 'Packaged helper version differs from its manifest.' }
    }
    finally { $archive.Dispose() }
}

$stage = $null
$stageFiles = New-Object 'System.Collections.Generic.List[string]'
$stageDirectories = New-Object 'System.Collections.Generic.List[string]'
$buildFailure = $null
$buildResult = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Acceptance kit building requires Windows.' }
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $assets = Get-KitBuildPath $RuntimeAssetsDirectory
    $runner = Get-KitBuildPath $RunnerSourceDirectory
    $output = Get-KitBuildPath $OutputDirectory
    Assert-KitBuildNoReparse $assets; Assert-KitBuildNoReparse $runner
    if (-not (Get-Item -LiteralPath $assets -Force).PSIsContainer -or -not (Get-Item -LiteralPath $runner -Force).PSIsContainer) { throw 'Runtime assets and runner source must be directories.' }
    $parent = [IO.Path]::GetDirectoryName($output)
    Assert-KitBuildNoReparse $parent
    if (-not (Get-Item -LiteralPath $parent -Force).PSIsContainer -or (Test-Path -LiteralPath $output)) { throw 'OutputDirectory must be new with an existing parent.' }
    if ((Test-KitBuildWithin $output $assets) -or (Test-KitBuildWithin $output $runner)) { throw 'OutputDirectory must be outside runtime assets and runner sources.' }
    $manifestPath = Join-Path $assets 'release-manifest.json'
    $manifest = Read-KitBuildJson $manifestPath
    $target = Read-KitBuildJson (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/codex-v1.0.1/RELEASE_TARGET.json')
    if ((Get-KitBuildField $manifest 'schema_version') -ne 1 -or (Get-KitBuildField $manifest 'repository') -cne 'PikkuJanne/AudioFileForPhone') { throw 'Unsupported runtime manifest identity.' }
    $version = [string](Get-KitBuildField $manifest 'app_version')
    $source = [string](Get-KitBuildField $manifest 'release_commit')
    if ($version -cnotmatch '^\d+\.\d+\.\d+$' -or $source -cnotmatch '^[a-f0-9]{40}$' -or
        (Get-KitBuildField $manifest 'tag') -cne ('v' + $version)) { throw 'Runtime manifest version, source or tag is invalid.' }
    if (-not $Rehearsal -and ($version -cne [string](Get-KitBuildField $target 'target_version') -or
        (Get-KitBuildField $manifest 'tag') -cne [string](Get-KitBuildField $target 'target_tag'))) { throw 'Final kit requires the fixed release target; use Rehearsal for preparation only.' }
    $zipRecord = Get-KitBuildField $manifest 'zip'
    $zipName = [string](Get-KitBuildField $zipRecord 'name')
    if ($zipName -cne ('AudioFileForPhone-v' + $version + '.zip') -or
        (-not $Rehearsal -and $zipName -cne [string](Get-KitBuildField $target 'runtime_zip'))) { throw 'Runtime ZIP filename differs from the target identity.' }
    $zipPath = Join-Path $assets $zipName
    Assert-KitBuildNoReparse $zipPath
    $zipItem = Get-Item -LiteralPath $zipPath -Force
    $zipBytes = Get-KitBuildField $zipRecord 'bytes'
    if ($zipItem.PSIsContainer -or $zipItem.Length -lt 1 -or $zipItem.Length -gt 67108864 -or
        ($zipBytes -isnot [int] -and $zipBytes -isnot [long]) -or $zipItem.Length -ne $zipBytes) { throw 'Runtime ZIP size differs from the bounded manifest.' }
    $zipHash = Get-KitBuildHash $zipPath
    if ([string](Get-KitBuildField $zipRecord 'sha256') -cnotmatch '^[a-f0-9]{64}$' -or
        (Get-KitBuildField $zipRecord 'sha256') -cne $zipHash) { throw 'Runtime ZIP digest differs from its manifest.' }
    $manifestHash = Get-KitBuildHash $manifestPath
    $checksumsPath = Join-Path $assets 'SHA256SUMS.txt'
    Assert-KitBuildNoReparse $checksumsPath
    $checksumItem = Get-Item -LiteralPath $checksumsPath -Force
    if ($checksumItem.PSIsContainer -or $checksumItem.Length -gt 1024) { throw 'Runtime checksums must be a bounded regular file.' }
    $checksums = [IO.File]::ReadAllText($checksumsPath, (New-Object Text.UTF8Encoding($false, $true))).Replace("`r`n", "`n")
    if ($checksums -cne ($zipHash + '  ' + $zipName + "`n" + $manifestHash + "  release-manifest.json`n")) { throw 'Runtime checksums must bind exactly the ZIP and external manifest.' }
    $allowlist = Read-KitBuildJson (Join-Path $PSScriptRoot 'package-files.json')
    $required = @(Get-KitBuildField $allowlist 'files')
    $files = Get-KitBuildField $manifest 'files'
    $fileBytes = Get-KitBuildField $manifest 'file_bytes'
    $properties = @($files.PSObject.Properties)
    if ($properties.Count -ne $required.Count -or @($fileBytes.PSObject.Properties).Count -ne $required.Count) { throw 'Runtime manifest inventory differs from the package allowlist.' }
    $inventory = @(); $sizes = @{}
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($property in $properties) {
        $name = $property.Name; $hash = [string]$property.Value
        if (($name -cne 'tools/ffmpeg-download.json' -and $name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') -or
            $required -cnotcontains $name -or -not $seen.Add($name) -or $hash -cnotmatch '^[a-f0-9]{64}$') { throw 'Runtime manifest has unsafe, duplicate or unexpected members/hashes.' }
        $bytes = Get-KitBuildField $fileBytes $name
        if (($bytes -isnot [int] -and $bytes -isnot [long]) -or $bytes -lt 0 -or $bytes -gt 10485760) { throw 'Runtime manifest has invalid member size.' }
        $sizes[$name] = [long]$bytes
        $inventory += [pscustomobject]@{ path = $name; sha256 = $hash }
    }
    $inventory = @($inventory | Sort-Object path)
    Assert-KitBuildArchive $zipPath $inventory $sizes $version
    $runnerFiles = @('Run-Windows-Acceptance.bat', 'Run-Windows-Acceptance.ps1', 'Acceptance.Common.ps1', 'Acceptance.Physical.ps1', 'Export-AcceptanceReport.ps1', 'INSTRUCTIONS.txt')
    $sources = [ordered]@{}
    foreach ($name in $runnerFiles) {
        $path = Join-Path $runner $name
        Assert-KitBuildNoReparse $path
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer -or $item.Length -lt 1 -or $item.Length -gt 1048576) { throw 'Runner files must be nonempty, bounded regular text files.' }
        $sources[$name] = $path
    }
    foreach ($name in @($zipName, 'release-manifest.json', 'SHA256SUMS.txt')) { $sources['runtime/' + $name] = Join-Path $assets $name }
    $sourceHashes = @{}
    foreach ($name in $sources.Keys) { $sourceHashes[$name] = Get-KitBuildHash $sources[$name] }
    if ($sourceHashes['runtime/' + $zipName] -cne $zipHash -or $sourceHashes['runtime/release-manifest.json'] -cne $manifestHash) { throw 'Runtime inputs changed during validation.' }
    $stage = Join-Path $parent ('.afp-kit-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $stage) { throw 'Unexpected staging collision.' }
    if (-not ('AudioFileForPhone.AcceptanceKitDirectory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhone {
    public static class AcceptanceKitDirectory {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr attributes);
    }
}
'@ -ErrorAction Stop
    }
    if (-not [AudioFileForPhone.AcceptanceKitDirectory]::CreateDirectoryW($stage, [IntPtr]::Zero)) {
        $stage = $null
        throw 'Could not exclusively reserve kit staging; no existing directory was changed.'
    }
    $content = Join-Path $stage 'content'; $stageDirectories.Add($content)
    $null = [IO.Directory]::CreateDirectory($content)
    $runtimeDirectory = Join-Path $content 'runtime'; $stageDirectories.Add($runtimeDirectory)
    $null = [IO.Directory]::CreateDirectory($runtimeDirectory)
    $kitInventory = @()
    foreach ($name in $sources.Keys) {
        $destination = Join-Path $content $name; $stageFiles.Add($destination)
        [IO.File]::Copy($sources[$name], $destination, $false)
        $hash = Get-KitBuildHash $destination
        if ($hash -cne $sourceHashes[$name]) { throw 'Kit input changed while being copied.' }
        $kitInventory += [pscustomobject]@{ path = $name; sha256 = $hash }
    }
    $kitManifest = [ordered]@{
        schema_version = 1; kind = $(if ($Rehearsal) { 'rehearsal_acceptance_kit' } else { 'acceptance_kit' })
        source_commit = $source; runtime_version = $version; runtime_zip = 'runtime/' + $zipName
        runtime_zip_sha256 = $zipHash; runtime_hashes = $inventory; kit_files = $kitInventory
        scope = $(if ($Rehearsal) { 'S13 rehearsal only; no frozen candidate or release acceptance.' } else { 'Exact package preparation; no acceptance or publication authority is granted by building a kit.' })
    }
    $kitManifestPath = Join-Path $content 'kit-manifest.json'; $stageFiles.Add($kitManifestPath)
    [IO.File]::WriteAllText($kitManifestPath, (($kitManifest | ConvertTo-Json -Depth 10) + "`n"), (New-Object Text.UTF8Encoding($false)))
    $kitZipPath = Join-Path $stage 'Acceptance-Kit.zip'; $stageFiles.Add($kitZipPath)
    $archive = [IO.Compression.ZipFile]::Open($kitZipPath, [IO.Compression.ZipArchiveMode]::Create)
    $kitNames = [string[]]@(@($sources.Keys) + 'kit-manifest.json')
    [Array]::Sort($kitNames, [StringComparer]::Ordinal)
    try {
        foreach ($name in $kitNames) {
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero); $entry.ExternalAttributes = 0
            $inputStream = [IO.File]::OpenRead((Join-Path $content $name)); $outputStream = $entry.Open()
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }
    $archive = [IO.Compression.ZipFile]::OpenRead($kitZipPath)
    try {
        if ($archive.Entries.Count -ne $kitNames.Count) { throw 'Built kit archive omitted a member.' }
        for ($index = 0; $index -lt $kitNames.Count; $index++) {
            $entry = $archive.Entries[$index]; $name = $kitNames[$index]
            if ($entry.FullName -cne $name -or $entry.ExternalAttributes -ne 0) { throw 'Built kit archive inventory differs.' }
            $stream = $entry.Open()
            try { $hash = Get-KitBuildStreamHash $stream } finally { $stream.Dispose() }
            if ($hash -cne (Get-KitBuildHash (Join-Path $content $name))) { throw 'Built kit archive member digest differs.' }
        }
    } finally { $archive.Dispose() }
    $kitHash = Get-KitBuildHash $kitZipPath
    $kitChecksumPath = Join-Path $stage 'Acceptance-Kit.sha256'; $stageFiles.Add($kitChecksumPath)
    [IO.File]::WriteAllText($kitChecksumPath, ($kitHash + "  Acceptance-Kit.zip`n"), (New-Object Text.UTF8Encoding($false)))
    foreach ($name in $sources.Keys) { if ((Get-KitBuildHash $sources[$name]) -cne $sourceHashes[$name]) { throw 'Kit source changed during the build.' } }
    foreach ($path in @($stageFiles.ToArray())) {
        if (Test-KitBuildWithin $path $content) { Assert-KitBuildNoReparse $path; [IO.File]::Delete($path); $null = $stageFiles.Remove($path) }
    }
    for ($index = $stageDirectories.Count - 1; $index -ge 0; $index--) { Assert-KitBuildNoReparse $stageDirectories[$index]; [IO.Directory]::Delete($stageDirectories[$index], $false) }
    $stageDirectories.Clear()
    Assert-KitBuildNoReparse $stage; Assert-KitBuildNoReparse $parent
    if (Test-Path -LiteralPath $output) { throw 'OutputDirectory appeared during the build; it was not replaced.' }
    [IO.Directory]::Move($stage, $output); $stage = $null
    $buildResult = [ordered]@{ status = 'PASSED'; kind = $kitManifest.kind; source_commit = $source; runtime_zip_sha256 = $zipHash; acceptance_kit_sha256 = $kitHash; output_directory = $output }
} catch { $buildFailure = $_.Exception.Message }
finally {
    if ($null -ne $stage -and (Test-Path -LiteralPath $stage)) {
        try {
            Assert-KitBuildNoReparse $stage
            foreach ($path in $stageFiles) {
                if (-not (Test-KitBuildWithin $path $stage)) { throw 'Kit cleanup ownership mismatch.' }
                if (Test-Path -LiteralPath $path) { Assert-KitBuildNoReparse $path; [IO.File]::Delete($path) }
            }
            for ($index = $stageDirectories.Count - 1; $index -ge 0; $index--) {
                if (Test-Path -LiteralPath $stageDirectories[$index]) { Assert-KitBuildNoReparse $stageDirectories[$index]; [IO.Directory]::Delete($stageDirectories[$index], $false) }
            }
            [IO.Directory]::Delete($stage, $false)
        } catch { $buildFailure = [string]$buildFailure + ' Owned kit staging retained: ' + $_.Exception.Message }
    }
}
if ($null -ne $buildFailure) { throw $buildFailure }
$buildResult | ConvertTo-Json -Depth 4
