<#
T03 focused resolver checks. Ordinary mode uses only an owned TEMP directory.
-DefaultSmoke runs one synthetic source through unmodified runtime copies.
Only the successfully returned exclusive run is inspected and removed from Music.
No known-folder settings are changed and unrelated Music entries are never listed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [switch]$DefaultSmoke,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$application = Join-Path $projectRoot 'AudioFileForPhone.ps1'
$helpers = Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T03-resolver-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.t03-owner'
$originalPath = $env:PATH
$musicRoot = $null
$musicParent = $null
$musicOwnerFile = $null
$runtimeOwnerFile = $null
$runtimeOwnerToken = $null
$musicCleanupAuthorized = $false
$tempRootReserved = $false
$tempMarkerCreated = $false
$evidenceStream = $null
$sourceAudio = $null
$expectedMusicFiles = @()
$expectedMusicDirectories = @()
$exitCode = 1

$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T03|T04|T05|T06|T07|T08|T09|T11|T15|T16)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T03/T04/T05/T06/T07/T08/T09/T11/T15/T16-<label>.json directly in docs/codex-v1/evidence.'
}
$evidenceTask = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3)
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1
    task = $evidenceTask
    mode = $(if ($DefaultSmoke) { 'resolver_and_default_music_smoke' } else { 'resolver_only' })
    command = [Environment]::CommandLine
    started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString()
    shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString()
    windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    application_sha256_before = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash.ToLowerInvariant()
    application_sha256_after = $null
    application_unchanged = $false
    helpers_sha256_before = (Get-FileHash -LiteralPath $helpers -Algorithm SHA256).Hash.ToLowerInvariant()
    helpers_sha256_after = $null
    helpers_unchanged = $false
    resolver_cases = @()
    default_smoke = [ordered]@{
        status = 'not_run'; byte_identical_copies = $false; output_override_passed = $false
        root_exclusively_reserved = $false; marker_create_new = $false
        trusted_child_execution = $false; runtime_ownership_verified = $false
        configured_music_verified = $false; exact_inventory_verified = $false
        source_sha256_before = $null; source_sha256_after = $null; source_unchanged = $null
        cleanup_verified = $null
    }
    temp_cleanup_verified = $false
    temp_root = $testRoot
    status = 'fail'
    error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Refusing a reparse point in the test path or its ancestors.'
        }
        $parentPath = Split-Path -Parent $item.FullName
        if (-not $parentPath -or $parentPath -ceq $item.FullName) { break }
        $item = Get-Item -LiteralPath $parentPath -Force
    }
}

function Get-SafeTree {
    param([string]$Root)
    # Inspect each child before descending, including on Windows PowerShell 5.1.
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Refusing a reparse point inside the owned test tree.'
            }
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}

function New-ExclusiveDirectory {
    param([string]$Path)
    if (-not ('AudioFileForPhoneT03.NativeDirectory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhoneT03 {
    public static class NativeDirectory {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr securityAttributes);
    }
}
'@
    }
    if (-not [AudioFileForPhoneT03.NativeDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Exclusive test directory reservation failed (Win32 $code); existing directories are never claimed."
    }
}

function New-OwnerMarker {
    param([string]$Path)
    $bytes = [Text.Encoding]::UTF8.GetBytes($ownerToken)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Write-EvidenceCheckpoint {
    # This stream was reserved with CreateNew before tests started. Retain the
    # exact returned Music path immediately, including when later checks fail.
    $bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 12))
    $evidenceStream.Position = 0
    $evidenceStream.SetLength(0)
    $evidenceStream.Write($bytes, 0, $bytes.Length)
    $evidenceStream.Flush($true)
}

function Assert-RuntimeOwnership {
    Assert-True $musicCleanupAuthorized 'Music inspection requires the controlled successful child and verified runtime ownership.'
    Assert-NoReparse $musicRoot
    $markerItem = Get-Item -LiteralPath $runtimeOwnerFile -Force
    Assert-True (-not $markerItem.PSIsContainer -and $markerItem.Length -le 8192) 'Runtime marker must be a small regular file.'
    Assert-NoReparse $runtimeOwnerFile
    $identity = [IO.File]::ReadAllText($runtimeOwnerFile) | ConvertFrom-Json
    Assert-True (($identity.schema_version -is [int] -or $identity.schema_version -is [long]) -and $identity.schema_version -eq 1 -and
        $identity.kind -ceq 'AudioFileForPhone.Output') 'Runtime marker must retain the exact production identity.'
    Assert-True ($identity.output_root -is [string] -and $identity.output_root -ceq $musicRoot -and
        $identity.cleanup_scope -is [string] -and $identity.cleanup_scope -ceq $musicRoot -and
        $identity.ownership_token -is [string] -and $identity.ownership_token -ceq $runtimeOwnerToken -and
        $identity.ownership_token -cmatch '^[0-9a-f]{32}$') 'Runtime marker token and cleanup scope must still match the controlled child run.'
}

function Invoke-ResolverCase {
    param([string]$Name, [hashtable]$Arguments, [string]$Expected, [string]$ExpectedError)
    $entry = [ordered]@{ name = $Name; status = 'fail' }
    try {
        $result = & $resolverCommand $Arguments
        if ($ExpectedError) { throw 'Expected resolver rejection but it returned a path.' }
        Assert-True ($result -ceq $Expected) "$Name should return its exact canonical filesystem path."
        $entry.status = 'pass'
    }
    catch {
        if ($ExpectedError -and $_.Exception.Message -match $ExpectedError) {
            $entry.status = 'pass'
            $entry['rejection_verified'] = $true
        }
        else { throw }
    }
    finally { $report.resolver_cases += [pscustomobject]$entry }
}

function Invoke-Native {
    param([string]$Executable, [string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $output = @(& $Executable @Arguments 2>&1)
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Synthetic test child exited $code.`n$($output -join "`n")" }
    return $output
}

function Get-ExactMusicInventory {
    Assert-RuntimeOwnership
    $items = @(Get-SafeTree $musicRoot)
    $files = @($items | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
        $_.FullName.Substring($musicRoot.Length + 1)
    } | Sort-Object)
    $directories = @($items | Where-Object { $_.PSIsContainer } | ForEach-Object {
        $_.FullName.Substring($musicRoot.Length + 1)
    } | Sort-Object)
    foreach ($path in $files) {
        Assert-True ($expectedMusicFiles -ccontains $path) 'Owned Music run must contain no unexpected file before cleanup.'
    }
    foreach ($path in $directories) {
        Assert-True ($expectedMusicDirectories -ccontains $path) 'Owned Music run must contain no unexpected directory before cleanup.'
    }
    Assert-True (($files -join "`n") -ceq ($expectedMusicFiles -join "`n")) 'Owned Music run must retain the complete expected file inventory.'
    Assert-True (($directories -join "`n") -ceq ($expectedMusicDirectories -join "`n")) 'Owned Music run must retain the complete expected directory inventory.'
    return [pscustomobject]@{ files = $files; directories = $directories }
}

Assert-NoReparse $evidenceParent
$evidenceStream = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read)
try {
    Write-EvidenceCheckpoint
    Assert-NoReparse $tempParent
    New-ExclusiveDirectory $testRoot
    $tempRootReserved = $true
    New-OwnerMarker $ownerFile
    $tempMarkerCreated = $true
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($application, [ref]$tokens, [ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) 'Production application must parse before resolver extraction.'
    $helperTokens = $null; $helperErrors = $null
    $helperAst = [Management.Automation.Language.Parser]::ParseFile($helpers, [ref]$helperTokens, [ref]$helperErrors)
    Assert-True ($helperErrors.Count -eq 0) 'Production helpers must parse before resolver extraction.'
    $functions = @($helperAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-OutputParent'
    }, $true))
    Assert-True ($functions.Count -eq 1) 'Exactly one production Get-OutputParent function must exist.'
    # Execute only the actual resolver function AST; never run entry-point code.
    $resolverCommand = [scriptblock]::Create("param([hashtable]`$ResolverArguments)`n" +
        $functions[0].Extent.Text + "`nGet-OutputParent @ResolverArguments")
    $report['resolver_sha256'] = ([Security.Cryptography.SHA256]::Create().ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($functions[0].Extent.Text)) | ForEach-Object { $_.ToString('x2') }) -join ''

    $redirected = Join-Path $testRoot 'Configured redirected Music [synthetic]'
    $probe = [pscustomobject]@{ Calls = 0 }
    $injectedResolver = { $probe.Calls++; $redirected }.GetNewClosure()
    Invoke-ResolverCase 'injected configured Music, independent of user profile' @{
        MusicResolver = $injectedResolver
    } ([IO.Path]::GetFullPath($redirected))
    Assert-True ($probe.Calls -eq 1) 'Default resolution should invoke the injected resolver exactly once.'
    Assert-True (-not (Test-Path -LiteralPath $redirected)) 'Resolver lookup must not create the injected Music directory.'
    Invoke-ResolverCase 'empty configured Music is rejected' @{ MusicResolver = { '' } } '' 'Music folder'
    $bypassResolver = { throw 'Explicit override unexpectedly invoked the Music resolver.' }
    $absolute = Join-Path $testRoot 'Absolute output with spaces [brackets]\new child'
    Invoke-ResolverCase 'absolute missing parent and literal brackets, override bypasses resolver' @{
        OutputParent = $absolute; MusicResolver = $bypassResolver
    } ([IO.Path]::GetFullPath($absolute))
    Invoke-ResolverCase 'filesystem provider-qualified override' @{
        OutputParent = 'FileSystem::' + $absolute; MusicResolver = $bypassResolver
    } ([IO.Path]::GetFullPath($absolute))
    Invoke-ResolverCase 'existing filesystem parent, override bypasses resolver' @{
        OutputParent = $testRoot; MusicResolver = $bypassResolver
    } ([IO.Path]::GetFullPath($testRoot))
    Push-Location -LiteralPath $testRoot
    try {
        Invoke-ResolverCase 'relative missing parent uses PowerShell location' @{
            OutputParent = '.\Relative output [brackets]\new parent'; MusicResolver = $bypassResolver
        } ([IO.Path]::GetFullPath((Join-Path $testRoot 'Relative output [brackets]\new parent')))
    }
    finally { Pop-Location }
    foreach ($providerPath in @('Env:\TEMP', 'Registry::HKEY_CURRENT_USER\Software', 'Variable:\PSVersionTable')) {
        Invoke-ResolverCase ('reject non-filesystem ' + ($providerPath -split ':')[0]) @{
            OutputParent = $providerPath; MusicResolver = $bypassResolver
        } '' 'filesystem directory'
    }
    $existingFile = Join-Path $testRoot 'Existing file [literal].txt'
    [IO.File]::WriteAllText($existingFile, 'Generated resolver fixture.')
    Invoke-ResolverCase 'existing file is rejected as output parent' @{
        OutputParent = $existingFile; MusicResolver = $bypassResolver
    } '' 'existing file'
    Assert-True (-not (Test-Path -LiteralPath $absolute)) 'Override resolution must not create the missing parent.'

    if ($DefaultSmoke) {
        $report.default_smoke.status = 'fail'
        $musicParent = & $resolverCommand @{}
        Assert-True ([IO.Path]::IsPathRooted($musicParent)) 'Configured Music path must be absolute.'
        $musicParent = [IO.Path]::GetFullPath($musicParent)
        Assert-True ($musicParent -ine [IO.Path]::GetPathRoot($musicParent)) 'Smoke requires a configured Music directory below a filesystem root.'
        $musicParent = $musicParent.TrimEnd('\', '/')
        Assert-True (Test-Path -LiteralPath $musicParent -PathType Container) 'Smoke requires an existing configured Music directory.'
        Assert-NoReparse $musicParent
        $configured = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic, [Environment+SpecialFolderOption]::DoNotVerify)
        Assert-True ($musicParent -ieq [IO.Path]::GetFullPath($configured).TrimEnd('\', '/')) 'Default resolver must equal Windows configured Music.'
        $report.default_smoke.configured_music_verified = $true

        $sourceAudio = Join-Path $testRoot 'T08 generated default smoke\2024-01-02 - Default smoke.mp3'
        [IO.Directory]::CreateDirectory((Split-Path -Parent $sourceAudio)) | Out-Null
        $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
        $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
        foreach ($selection in @(@{ name = 'ffmpeg'; path = $ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe })) {
            Assert-True ([IO.Path]::GetFileName($selection.path) -ieq ($selection.name + '.exe')) 'Smoke tools must be the explicitly selected native executable pair.'
            $report.default_smoke[$selection.name] = [ordered]@{
                version = (Invoke-Native $selection.path @('-version'))[0].ToString()
                sha256 = (Get-FileHash -LiteralPath $selection.path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
        foreach ($selection in @(@{ name = 'ffmpeg.exe'; path = $ffmpeg }, @{ name = 'ffprobe.exe'; path = $ffprobe })) {
            $firstCandidate = $null
            foreach ($directory in ($env:PATH -split ';' | Where-Object { $_ })) {
                $candidate = Join-Path $directory $selection.name
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $firstCandidate = [IO.Path]::GetFullPath($candidate)
                    break
                }
            }
            Assert-True ($firstCandidate -ieq $selection.path) 'Production PATH discovery must select the reported native tool.'
        }
        Invoke-Native $ffmpeg @('-hide_banner', '-loglevel', 'error', '-nostdin', '-f', 'lavfi', '-i',
            'sine=frequency=440:sample_rate=44100:duration=0.4', '-c:a', 'libmp3lame', '-metadata',
            'title=T08 synthetic default smoke', $sourceAudio) | Out-Null
        $report.default_smoke.source_sha256_before = (Get-FileHash -LiteralPath $sourceAudio -Algorithm SHA256).Hash.ToLowerInvariant()

        $scriptCopy = Join-Path $testRoot 'Default smoke application.ps1'
        Copy-Item -LiteralPath $application -Destination $scriptCopy
        $helpersCopy = Join-Path $testRoot 'AudioFileForPhone.Helpers.ps1'
        Copy-Item -LiteralPath $helpers -Destination $helpersCopy
        Assert-True ((Get-FileHash -LiteralPath $scriptCopy).Hash -ceq (Get-FileHash -LiteralPath $application).Hash) 'Smoke application copy must preserve all source bytes.'
        Assert-True ((Get-FileHash -LiteralPath $helpersCopy).Hash -ceq (Get-FileHash -LiteralPath $helpers).Hash) 'Smoke runtime helper copy must preserve all source bytes.'
        $report.default_smoke.byte_identical_copies = $true
        $report.default_smoke['copy_sha256'] = (Get-FileHash -LiteralPath $scriptCopy -Algorithm SHA256).Hash.ToLowerInvariant()
        $report.default_smoke['helpers_copy_sha256'] = (Get-FileHash -LiteralPath $helpersCopy -Algorithm SHA256).Hash.ToLowerInvariant()
        $shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
        $shell = Join-Path $PSHOME $shellName
        $childArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned',
            '-File', $scriptCopy, '-InputFolder', (Split-Path -Parent $sourceAudio))
        $report.default_smoke.output_override_passed = $childArguments -contains '-OutputParent'
        Assert-True (-not $report.default_smoke.output_override_passed) 'Default smoke child must omit OutputParent.'
        $savedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $nativeOutput = @(& $shell @childArguments 2>&1)
            $childExitCode = $LASTEXITCODE
        }
        finally { $ErrorActionPreference = $savedPreference }
        $report.default_smoke['child_exit_code'] = $childExitCode
        $roots = @($nativeOutput | ForEach-Object {
            if ("$_" -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1] }
        })
        $report.default_smoke['reported_roots'] = @($roots)
        if ($roots.Count -eq 1) {
            $report.default_smoke['recoverable_reported_root'] = $roots[0]
        }
        Write-EvidenceCheckpoint
        $nativeOutput | ForEach-Object { "$_" } | Set-Content -LiteralPath (Join-Path $testRoot 'default-smoke-child.log') -Encoding UTF8
        Assert-True ($roots.Count -eq 1) 'Default smoke must report one exact run root; uncertain roots cannot be inspected or cleaned.'
        Assert-True ($childExitCode -eq 0) 'Default smoke requires a successful controlled child; its reported candidate remains recorded if unsuccessful.'
        $canonicalRoot = [IO.Path]::GetFullPath($roots[0]).TrimEnd('\', '/')
        Assert-True ($canonicalRoot -ceq $roots[0] -and (Split-Path -Parent $canonicalRoot) -ieq $musicParent -and
            (Split-Path -Leaf $canonicalRoot) -cmatch '^AudioForPhone_64kbps_\d{8}_\d{6}(?:_(?:[2-9]|[1-9]\d+))?$') 'Default smoke returned root must be canonical and directly inside configured Music.'
        Assert-True ($report.default_smoke.byte_identical_copies -and $report.application_sha256_before -ceq
            (Get-FileHash -LiteralPath $scriptCopy -Algorithm SHA256).Hash.ToLowerInvariant() -and $report.helpers_sha256_before -ceq
            (Get-FileHash -LiteralPath $helpersCopy -Algorithm SHA256).Hash.ToLowerInvariant()) 'Successful child cleanup authority requires the exact reviewed application/helper bytes.'
        $musicRoot = $canonicalRoot
        $report.default_smoke.trusted_child_execution = $true
        Assert-NoReparse $musicRoot
        $runtimeOwnerFile = Join-Path $musicRoot '.AudioFileForPhone-output.json'
        $markerItem = Get-Item -LiteralPath $runtimeOwnerFile -Force
        Assert-True (-not $markerItem.PSIsContainer -and $markerItem.Length -le 8192) 'Returned run requires a small production ownership marker.'
        Assert-NoReparse $runtimeOwnerFile
        $identity = [IO.File]::ReadAllText($runtimeOwnerFile) | ConvertFrom-Json
        Assert-True (($identity.schema_version -is [int] -or $identity.schema_version -is [long]) -and $identity.schema_version -eq 1 -and
            $identity.kind -ceq 'AudioFileForPhone.Output' -and $identity.output_root -is [string] -and $identity.output_root -ceq $musicRoot -and
            $identity.cleanup_scope -is [string] -and $identity.cleanup_scope -ceq $musicRoot -and $identity.ownership_token -is [string] -and
            $identity.ownership_token -cmatch '^[0-9a-f]{32}$') 'Returned marker must match the controlled successful child, exact cleanup scope and production ownership identity.'
        $runtimeOwnerToken = $identity.ownership_token
        $report.default_smoke['runtime_owner_token'] = $runtimeOwnerToken
        $report.default_smoke['cleanup_scope'] = $musicRoot
        $report.default_smoke['run_root_name'] = Split-Path -Leaf $musicRoot
        $report.default_smoke.root_exclusively_reserved = $true
        $report.default_smoke.runtime_ownership_verified = $true
        $musicCleanupAuthorized = $true
        $musicOwnerFile = Join-Path $musicRoot '.t08-owner'
        New-OwnerMarker $musicOwnerFile
        $report.default_smoke.marker_create_new = $true
        $expectedMusicDirectories = @('T08 generated default smoke')
        $expectedMusicFiles = @('.t08-owner', '.AudioFileForPhone-output.json', 'AudioFileForPhone_log.txt', 'AudioFileForPhone_manifest.json',
            'T08 generated default smoke\2024-01-02 - Default smoke.mp3') | Sort-Object
        Write-EvidenceCheckpoint
        $inventory = Get-ExactMusicInventory
        Assert-True (($inventory.files -join "`n") -ceq ($expectedMusicFiles -join "`n")) 'Default smoke must produce only the owner markers, log, manifest and one synthetic MP3.'
        Assert-True (($inventory.directories -join "`n") -ceq ($expectedMusicDirectories -join "`n")) 'Default smoke must preserve the exact synthetic input folder.'
        $report.default_smoke['inventory'] = $inventory
        $report.default_smoke.exact_inventory_verified = $true
        $outputAudio = Join-Path $musicRoot 'T08 generated default smoke\2024-01-02 - Default smoke.mp3'
        $manifestPath = Join-Path $musicRoot 'AudioFileForPhone_manifest.json'
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        $records = @($manifest.records)
        Assert-True ($manifest.schema_version -eq 1 -and $manifest.kind -ceq 'AudioFileForPhone.RunManifest' -and
            $manifest.checkpoint -ceq 'Final' -and $manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and
            $manifest.run.input_root -ceq (Split-Path -Parent $sourceAudio) -and $manifest.run.output_root -ceq $musicRoot) 'Manifest must describe this exact successful controlled run and final result.'
        Assert-True ($records.Count -eq 1 -and $records[0].status -ceq 'Converted' -and $records[0].code -ceq 'Success' -and
            $records[0].source_relative_path -ceq (Split-Path -Leaf $sourceAudio) -and
            $records[0].output_relative_path -ceq 'T08 generated default smoke\2024-01-02 - Default smoke.mp3' -and
            $records[0].input_bytes -eq (Get-Item -LiteralPath $sourceAudio -Force).Length -and
            $records[0].output_bytes -eq (Get-Item -LiteralPath $outputAudio -Force).Length) 'Manifest must map the single source to the exact published output and actual byte lengths.'
        Assert-True ($manifest.totals.supported -eq 1 -and $manifest.totals.processed -eq 1 -and $manifest.totals.converted -eq 1 -and
            $manifest.totals.failed -eq 0 -and $manifest.totals.cancelled -eq 0 -and $manifest.totals.not_processed -eq 0 -and
            $manifest.totals.not_completed -eq 0 -and $manifest.totals.input_bytes -eq $records[0].input_bytes -and
            $manifest.totals.output_bytes -eq $records[0].output_bytes -and
            $manifest.build.entry_sha256 -ceq $report.application_sha256_before -and
            $manifest.build.helper_sha256 -ceq $report.helpers_sha256_before) 'Manifest counts, byte totals and actual executed build hashes must reconcile.'
        $report.default_smoke['manifest_verified'] = $true
        $report.default_smoke['manifest_sha256'] = $manifestHash
        $report.default_smoke['manifest_record'] = $records[0]
        $media = (Invoke-Native $ffprobe @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $outputAudio)) -join "`n" | ConvertFrom-Json
        $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
        Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Default smoke output must contain 64 kbps MP3 audio.'
        Assert-True ($media.format.tags.title -eq 'T08 synthetic default smoke') 'Default smoke must preserve source title metadata.'
        Invoke-Native $ffmpeg @('-hide_banner', '-loglevel', 'error', '-nostdin', '-i', $outputAudio, '-f', 'null', '-') | Out-Null
        $report.default_smoke['output_sha256'] = (Get-FileHash -LiteralPath $outputAudio -Algorithm SHA256).Hash.ToLowerInvariant()
        $report.default_smoke['audio_bitrate'] = [int]$audio[0].bit_rate
        $report.default_smoke['full_decode_passed'] = $true
        Assert-True ((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $manifestHash) 'Independent probe/decode must preserve the final manifest bytes.'
        $report.default_smoke.status = 'pass'
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
    $report.application_sha256_after = (Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash.ToLowerInvariant()
    $report.application_unchanged = $report.application_sha256_before -ceq $report.application_sha256_after
    if (-not $report.application_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    $report.helpers_sha256_after = (Get-FileHash -LiteralPath $helpers -Algorithm SHA256).Hash.ToLowerInvariant()
    $report.helpers_unchanged = $report.helpers_sha256_before -ceq $report.helpers_sha256_after
    if (-not $report.helpers_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    if ($report.default_smoke.source_sha256_before) {
        $report.default_smoke.source_unchanged = $false
        if (Test-Path -LiteralPath $sourceAudio -PathType Leaf) {
            $report.default_smoke.source_sha256_after = (Get-FileHash -LiteralPath $sourceAudio -Algorithm SHA256).Hash.ToLowerInvariant()
            $report.default_smoke.source_unchanged = $report.default_smoke.source_sha256_before -ceq $report.default_smoke.source_sha256_after
        }
        if (-not $report.default_smoke.source_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    }
    try {
        if ($musicRoot -and (Test-Path -LiteralPath $musicRoot)) {
            $resolved = (Resolve-Path -LiteralPath $musicRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $musicRoot -and (Split-Path -Parent $resolved) -ieq $musicParent) 'Music cleanup must stay inside the exact configured parent and reserved run.'
            Assert-True ($report.default_smoke.root_exclusively_reserved -and $report.default_smoke.trusted_child_execution -and
                $report.default_smoke.runtime_ownership_verified -and $report.default_smoke.marker_create_new) 'Music cleanup requires successful controlled exclusive reservation and both owner markers.'
            Assert-RuntimeOwnership
            Assert-NoReparse $musicOwnerFile
            Assert-True ([IO.File]::ReadAllText($musicOwnerFile) -ceq $ownerToken) 'Music cleanup requires the exact create-new marker token.'
            Get-ExactMusicInventory | Out-Null
            [IO.Directory]::Delete($resolved, $true)
            $report.default_smoke.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
    }
    catch {
        $report.status = 'fail'; $exitCode = 1
        $report['music_cleanup_error'] = $_.Exception.Message
        Write-Warning $report.music_cleanup_error
    }
    try {
        if ($tempRootReserved -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and
                (Split-Path -Leaf $resolved) -ceq $testName) 'TEMP cleanup must stay inside its exact owned root.'
            Assert-True ($tempRootReserved -and $tempMarkerCreated) 'TEMP cleanup requires successful exclusive reservation and create-new owner marker.'
            Assert-NoReparse $ownerFile
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'TEMP cleanup requires the exact marker token.'
            Get-SafeTree $resolved | Out-Null
            [IO.Directory]::Delete($resolved, $true)
            $report.temp_cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
    }
    catch {
        $report.status = 'fail'; $exitCode = 1
        $report['temp_cleanup_error'] = $_.Exception.Message
        Write-Warning $report.temp_cleanup_error
    }
    if ($DefaultSmoke -and $report.default_smoke.cleanup_verified -ne $true) { $report.status = 'fail'; $exitCode = 1 }
    if (-not $report.temp_cleanup_verified) { $report.status = 'fail'; $exitCode = 1 }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    try { Write-EvidenceCheckpoint }
    finally { $evidenceStream.Dispose() }
}
Write-Host "$evidenceTask $($report.mode): $($report.status); TEMP cleanup=$($report.temp_cleanup_verified); Music cleanup=$($report.default_smoke.cleanup_verified)"
exit $exitCode
