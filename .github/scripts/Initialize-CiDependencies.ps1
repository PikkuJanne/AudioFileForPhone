[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DestinationPath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$ManifestPath
)

# CI-only downloads into one fresh TEMP child. Application entry points never load this file.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrEmpty($ManifestPath)) { $ManifestPath = Join-Path $PSScriptRoot '..\dependencies.json' }

function Assert-CiNoReparse {
    param([Parameter(Mandatory = $true)][string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse point refused: $cursor"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-CiSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-CiZipPlan {
    param([Parameter(Mandatory = $true)]$Archive, [Parameter(Mandatory = $true)][string]$Root)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $prefix = $rootFull + '\'
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $files = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $plan = New-Object 'Collections.Generic.List[object]'
    [long]$expandedBytes = 0
    if ($Archive.Entries.Count -gt 500) { throw 'ZIP member count exceeds CI dependency limit.' }
    foreach ($entry in $Archive.Entries) {
        $name = [string]$entry.FullName
        $directory = $name.EndsWith('/')
        $trimmed = $name.TrimEnd('/')
        if ([string]::IsNullOrEmpty($trimmed) -or $name.StartsWith('/') -or $name.Contains('\') -or $name.Contains(':')) {
            throw "Unsafe ZIP path: $name"
        }
        foreach ($part in $trimmed.Split('/')) {
            if ([string]::IsNullOrEmpty($part) -or $part -eq '.' -or $part -eq '..' -or
                $part -match '[\x00-\x1f<>"|?*]' -or $part.EndsWith('.') -or $part.EndsWith(' ') -or
                $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
                throw "Unsafe ZIP component: $name"
            }
        }
        if (-not $seen.Add($trimmed)) { throw "Duplicate or case-colliding ZIP member: $name" }
        $attributes = [long]$entry.ExternalAttributes
        $unixType = ($attributes -shr 16) -band 61440
        if (($attributes -band 1024) -ne 0 -or ($unixType -ne 0 -and $unixType -ne 32768 -and $unixType -ne 16384)) {
            throw "Linked or special ZIP member refused: $name"
        }
        if ($directory -and $entry.Length -ne 0) { throw "Nonempty ZIP directory: $name" }
        $target = [IO.Path]::GetFullPath((Join-Path $rootFull $trimmed.Replace('/', '\')))
        if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $target.Length -ge 260) {
            throw "ZIP target escapes or exceeds tested Windows path budget: $name"
        }
        $expandedBytes += $entry.Length
        if ($entry.Length -gt 134217728 -or $expandedBytes -gt 805306368) { throw 'ZIP expanded size exceeds CI dependency limit.' }
        if (-not $directory) { [void]$files.Add($trimmed) }
        $plan.Add([pscustomobject]@{ entry = $entry; name = $name; target = $target; directory = $directory })
    }
    foreach ($item in $plan) {
        $parentName = $item.name.TrimEnd('/')
        while ($parentName.Contains('/')) {
            $parentName = $parentName.Substring(0, $parentName.LastIndexOf('/'))
            if ($files.Contains($parentName)) { throw "ZIP file is another member's ancestor: $parentName" }
        }
    }
    return $plan.ToArray()
}

function Expand-CiVerifiedZip {
    param([string]$ArchivePath, [string]$Root, $Dependency)
    Assert-CiNoReparse -Path $ArchivePath
    Assert-CiNoReparse -Path $Root
    if (Test-Path -LiteralPath $Root) { throw 'Extraction destination already exists.' }
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $plan = @(Get-CiZipPlan -Archive $archive -Root $Root)
        [void](New-Item -Path $Root -ItemType Directory -ErrorAction Stop)
        foreach ($item in $plan) {
            Assert-CiNoReparse -Path $item.target
            if ($item.directory) { [void][IO.Directory]::CreateDirectory($item.target); continue }
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.target))
            Assert-CiNoReparse -Path $item.target
            $sourceStream = $item.entry.Open()
            try {
                $targetStream = [IO.File]::Open($item.target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $sourceStream.CopyTo($targetStream) } finally { $targetStream.Dispose() }
            } finally { $sourceStream.Dispose() }
            if ((Get-Item -LiteralPath $item.target -Force).Length -ne $item.entry.Length) { throw 'ZIP member extracted length mismatch.' }
        }
        $inventory = @(Get-CiDependencyInventory -Root $Root)
        $digest = Get-CiInventoryDigest -Inventory $inventory
        if ($inventory.Count -ne $Dependency.archive_file_count -or $digest -ne $Dependency.inventory_sha256) {
            throw 'Extracted dependency inventory does not match reviewed archive.'
        }
        return [pscustomobject]@{ file_count = $inventory.Count; inventory_sha256 = $digest; files = $inventory }
    } finally { $archive.Dispose() }
}

function Get-CiDependencyInventory {
    param([Parameter(Mandatory = $true)][string]$Root)
    Assert-CiNoReparse -Path $Root
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $inventory = New-Object 'Collections.Generic.List[object]'
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($rootFull)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Extracted dependency contains a reparse point.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            $relative = $item.FullName.Substring($rootFull.Length + 1).Replace('\', '/')
            $inventory.Add([pscustomobject]@{ name = $relative; bytes = $item.Length; sha256 = (Get-CiSha256 -Path $item.FullName) })
        }
    }
    return $inventory.ToArray()
}

function Get-CiInventoryDigest {
    param([Parameter(Mandatory = $true)][object[]]$Inventory)
    $lines = New-Object 'Collections.Generic.List[string]'
    foreach ($file in $Inventory) {
        $lines.Add($file.name + "`t" + ([long]$file.bytes).ToString([Globalization.CultureInfo]::InvariantCulture) + "`t" + $file.sha256 + "`n")
    }
    $sorted = $lines.ToArray()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]::Concat($sorted)))).Replace('-', '').ToLowerInvariant()
    } finally { $hasher.Dispose() }
}

function Invoke-CiVerifiedDownload {
    param([Parameter(Mandatory = $true)]$Dependency, [Parameter(Mandatory = $true)][string]$Path)
    $url = [uri]$Dependency.archive_url
    if ($url.Scheme -ne 'https' -or $url.Host -ne 'github.com' -or
        $url.AbsolutePath -notmatch '^/(?:GyanD/codexffmpeg|PowerShell/PSScriptAnalyzer)/releases/download/[^/]+/[^/]+$' -or
        -not [string]::IsNullOrEmpty($url.Query) -or -not [string]::IsNullOrEmpty($url.Fragment)) {
        throw 'CI dependency URL is outside the reviewed fixed release sources.'
    }
    if ($Dependency.archive_sha256 -notmatch '^[a-f0-9]{64}$' -or $Dependency.archive_bytes -lt 1 -or $Dependency.archive_bytes -gt 134217728) {
        throw 'Invalid pinned CI dependency digest or size.'
    }
    Assert-CiNoReparse -Path $Path
    $client = New-Object Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromMinutes(5)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('AudioFileForPhone-CI/1')
    $elapsed = [Diagnostics.Stopwatch]::StartNew()
    $deadline = New-Object Threading.CancellationTokenSource
    $deadline.CancelAfter([TimeSpan]::FromMinutes(5))
    try {
        $response = $client.GetAsync($url, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $deadline.Token).GetAwaiter().GetResult()
        try {
            [void]$response.EnsureSuccessStatusCode()
            if ($response.RequestMessage.RequestUri.Scheme -ne 'https') { throw 'Insecure dependency redirect refused.' }
            $responseLength = $response.Content.Headers.ContentLength
            if ($null -ne $responseLength -and $responseLength -ne $Dependency.archive_bytes) { throw 'Dependency HTTP length differs from pin.' }
            $sourceStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            try {
                $targetStream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try {
                    $buffer = New-Object byte[] 65536
                    [long]$received = 0
                    while ($true) {
                        if ($elapsed.Elapsed.TotalMinutes -ge 5) { throw 'Dependency download exceeded its five-minute bound.' }
                        $readTask = $sourceStream.ReadAsync($buffer, 0, $buffer.Length, $deadline.Token)
                        if (-not $readTask.Wait(30000)) { $deadline.Cancel(); throw 'Dependency download stalled for thirty seconds.' }
                        $read = $readTask.GetAwaiter().GetResult()
                        if ($read -eq 0) { break }
                        $received += $read
                        if ($received -gt $Dependency.archive_bytes) { throw 'Dependency download exceeds pinned size.' }
                        $targetStream.Write($buffer, 0, $read)
                    }
                    if ($received -ne $Dependency.archive_bytes) { throw 'Dependency download is incomplete.' }
                } finally { $targetStream.Dispose() }
            } finally { $sourceStream.Dispose() }
        } finally { $response.Dispose() }
    } finally { $deadline.Cancel(); $client.Dispose(); $deadline.Dispose() }
    if ((Get-CiSha256 -Path $Path) -ne $Dependency.archive_sha256) { throw 'Dependency SHA256 differs from reviewed pin; extraction and execution refused.' }
}

$destination = [IO.Path]::GetFullPath($DestinationPath).TrimEnd('\')
$destinationParent = [IO.Path]::GetDirectoryName($destination)
$permittedParents = @([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\'))
if (-not [string]::IsNullOrEmpty($env:RUNNER_TEMP)) { $permittedParents += [IO.Path]::GetFullPath($env:RUNNER_TEMP).TrimEnd('\') }
if ($permittedParents -notcontains $destinationParent -or [IO.Path]::GetFileName($destination) -notmatch '^AFP-CI-[a-f0-9]{32}$') {
    throw 'CI dependency destination must be a fresh AFP-CI-GUID direct TEMP or RUNNER_TEMP child.'
}
Assert-CiNoReparse -Path $destination
if (Test-Path -LiteralPath $destination) { throw 'CI dependency destination already exists.' }
$evidence = [IO.Path]::GetFullPath($EvidencePath)
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$evidenceParent = Join-Path $repositoryRoot 'docs\codex-v1\evidence'
$shellLabel = if ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion -ge [version]'5.1') { 'ps51' } elseif ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7) { 'ps7' } else { throw 'Unsupported CI shell.' }
if (-not [IO.Path]::GetDirectoryName($evidence).Equals($evidenceParent, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($evidence) -notmatch ('^T17-dependencies-' + $shellLabel + '-(?:attempt[1-9][0-9]*|final[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$')) {
    throw 'CI dependency evidence must use a fresh T17-dependencies shell and run label JSON name.'
}
Assert-CiNoReparse -Path $evidence
if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($evidence)) -PathType Container)) { throw 'Evidence parent must exist.' }
$evidenceStream = [IO.File]::Open($evidence, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$ownerToken = [guid]::NewGuid().ToString('N')
$record = [ordered]@{
    schema_version = 1; task = 'T17'; status = 'fail'; started_utc = [DateTime]::UtcNow.ToString('o'); ended_utc = $null
    shell = [string]$PSVersionTable.PSVersion; edition = [string]$PSVersionTable.PSEdition
    root = $destination; owner_token = $ownerToken; ownership_marker_sha256 = $null
    manifest_path = [IO.Path]::GetFullPath($ManifestPath); manifest_sha256 = $null
    setup_path = $PSCommandPath; setup_sha256 = (Get-CiSha256 -Path $PSCommandPath)
    tested_commit = $null; source_unchanged = $false
    invocation = [ordered]@{ script = $PSCommandPath; destination_path = $destination; evidence_path = $evidence; manifest_path = [IO.Path]::GetFullPath($ManifestPath) }
    ffmpeg_path = $null; ffprobe_path = $null; analyzer_module_path = $null
    ffmpeg = $null; analyzer = $null; error = $null
    cleanup = 'Not requested; this exact owned dependency root remains available for checks. No global installation or environment changes.'
}
try {
    $identity = @(& git -C $repositoryRoot rev-parse HEAD)
    if ($LASTEXITCODE -ne 0 -or $identity.Count -ne 1 -or $identity[0] -notmatch '^[a-f0-9]{40}$') { throw 'CI checkout identity unavailable.' }
    $record.tested_commit = [string]$identity[0]
    Assert-CiNoReparse -Path $ManifestPath
    $record.manifest_sha256 = Get-CiSha256 -Path $ManifestPath
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.schema_version -ne 1) { throw 'Unsupported CI dependency manifest.' }
    [void](New-Item -Path $destination -ItemType Directory -ErrorAction Stop)
    $marker = Join-Path $destination '.afp-ci-owner'
    $markerStream = [IO.File]::Open($marker, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $markerBytes = [Text.Encoding]::UTF8.GetBytes($ownerToken); $markerStream.Write($markerBytes, 0, $markerBytes.Length) } finally { $markerStream.Dispose() }
    $record.ownership_marker_sha256 = Get-CiSha256 -Path $marker
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.Net.Http
    $ffmpegArchive = Join-Path $destination 'ffmpeg.zip'
    $analyzerArchive = Join-Path $destination 'analyzer.nupkg'
    Invoke-CiVerifiedDownload -Dependency $manifest.ffmpeg -Path $ffmpegArchive
    Invoke-CiVerifiedDownload -Dependency $manifest.analyzer -Path $analyzerArchive
    $ffmpegRoot = Join-Path $destination 'ffmpeg'
    $analyzerRoot = Join-Path $destination 'PSScriptAnalyzer'
    $ffmpegInventory = Expand-CiVerifiedZip -ArchivePath $ffmpegArchive -Root $ffmpegRoot -Dependency $manifest.ffmpeg
    $analyzerInventory = Expand-CiVerifiedZip -ArchivePath $analyzerArchive -Root $analyzerRoot -Dependency $manifest.analyzer
    $record.ffmpeg_path = Join-Path $ffmpegRoot $manifest.ffmpeg.ffmpeg_member.Replace('/', '\')
    $record.ffprobe_path = Join-Path $ffmpegRoot $manifest.ffmpeg.ffprobe_member.Replace('/', '\')
    $record.analyzer_module_path = Join-Path $analyzerRoot $manifest.analyzer.module_member
    if ((Get-CiSha256 -Path $record.ffmpeg_path) -ne $manifest.ffmpeg.ffmpeg_sha256 -or
        (Get-CiSha256 -Path $record.ffprobe_path) -ne $manifest.ffmpeg.ffprobe_sha256 -or
        (Get-CiSha256 -Path $record.analyzer_module_path) -ne $manifest.analyzer.module_manifest_sha256) { throw 'Dependency entry point digest mismatch.' }
    $ffmpegVersion = @(& $record.ffmpeg_path -version)
    if ($LASTEXITCODE -ne 0 -or $ffmpegVersion[0] -notmatch ('^ffmpeg version ' + [regex]::Escape($manifest.ffmpeg.version) + '(?:\s|$)')) { throw 'Pinned FFmpeg version unavailable.' }
    $ffprobeVersion = @(& $record.ffprobe_path -version)
    if ($LASTEXITCODE -ne 0 -or $ffprobeVersion[0] -notmatch ('^ffprobe version ' + [regex]::Escape($manifest.ffmpeg.version) + '(?:\s|$)')) { throw 'Pinned ffprobe version unavailable.' }
    $encoders = @(& $record.ffmpeg_path -hide_banner -encoders)
    if ($LASTEXITCODE -ne 0) { throw 'FFmpeg encoder capability query failed.' }
    foreach ($encoder in $manifest.ffmpeg.required_encoders) {
        if (-not ($encoders -match ('^\s*A[.A-Z]{5}\s+' + [regex]::Escape($encoder) + '\s'))) { throw "Required encoder missing: $encoder" }
    }
    $decoders = @(& $record.ffmpeg_path -hide_banner -decoders)
    if ($LASTEXITCODE -ne 0 -or -not ($decoders -match ('^\s*A[.A-Z]{5}\s+' + [regex]::Escape($manifest.ffmpeg.required_decoder) + '\s'))) { throw 'Required MP3 decoder missing.' }
    $moduleData = Import-PowerShellDataFile -LiteralPath $record.analyzer_module_path
    if ([string]$moduleData.ModuleVersion -ne $manifest.analyzer.version) { throw 'Pinned analyzer manifest version mismatch.' }
    $record.ffmpeg = [ordered]@{
        version = $manifest.ffmpeg.version; archive_url = $manifest.ffmpeg.archive_url; archive_sha256 = (Get-CiSha256 -Path $ffmpegArchive)
        ffmpeg_sha256 = (Get-CiSha256 -Path $record.ffmpeg_path); ffprobe_sha256 = (Get-CiSha256 -Path $record.ffprobe_path)
        ffmpeg_version_line = [string]$ffmpegVersion[0]; ffprobe_version_line = [string]$ffprobeVersion[0]
        encoders = @($manifest.ffmpeg.required_encoders); decoder = $manifest.ffmpeg.required_decoder; extraction = $ffmpegInventory
    }
    $record.analyzer = [ordered]@{
        version = $manifest.analyzer.version; archive_url = $manifest.analyzer.archive_url; archive_sha256 = (Get-CiSha256 -Path $analyzerArchive)
        module_manifest_sha256 = (Get-CiSha256 -Path $record.analyzer_module_path); extraction = $analyzerInventory
    }
    $record.status = 'pass'
} catch {
    $record.error = $_.Exception.Message
    throw
} finally {
    try {
        $record.source_unchanged = ((Get-CiSha256 -Path $PSCommandPath) -eq $record.setup_sha256 -and
            $null -ne $record.manifest_sha256 -and (Get-CiSha256 -Path $ManifestPath) -eq $record.manifest_sha256)
        if (-not $record.source_unchanged) { $record.status = 'fail'; if ($null -eq $record.error) { $record.error = 'CI dependency sources changed during setup.' } }
    } catch { $record.status = 'fail'; $record.source_unchanged = $false; if ($null -eq $record.error) { $record.error = $_.Exception.Message } }
    $record.ended_utc = [DateTime]::UtcNow.ToString('o')
    $writer = New-Object IO.StreamWriter($evidenceStream, (New-Object Text.UTF8Encoding($false)))
    try { $writer.Write(($record | ConvertTo-Json -Depth 10)); $writer.Flush() } finally { $writer.Dispose(); $evidenceStream.Dispose() }
}
if ($record.status -ne 'pass') { throw $record.error }
[pscustomobject]@{ Root = $destination; FfmpegPath = $record.ffmpeg_path; FfprobePath = $record.ffprobe_path; AnalyzerManifestPath = $record.analyzer_module_path; EvidencePath = $evidence }
