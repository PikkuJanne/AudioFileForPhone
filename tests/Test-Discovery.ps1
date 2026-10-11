<#
T06 focused discovery and boundary evidence on the active Windows shell.
All audio is synthetic. Application copies, links, ACL denials and child logs stay
inside an exclusively reserved TEMP tree; ordinary Music is never enumerated.
Registered links are removed without recursion before owned-tree cleanup.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T06-discovery-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t06-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$originalPath = $env:PATH
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$links = New-Object 'System.Collections.Generic.List[object]'
$savedAcls = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Discovery.ps1')
$exitCode = 1
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^T06-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T06-<label>.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a new label to preserve prior evidence.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'T06'; mode = 'bounded_discovery_and_boundary'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    cases = @(); acls_restored = $false; links_removed = $false; cleanup_verified = $false
    status = 'fail'; error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
}

function Assert-Throws {
    param([scriptblock]$Body, [string]$Pattern)
    $caught = $null
    try { & $Body | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-True ($null -ne $caught -and $caught -match $Pattern) "Expected rejection matching '$Pattern'; received '$caught'."
}

function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' }
    finally { $report.cases += [pscustomobject]$case }
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point in a test path or ancestor.'
        $item = $item.Parent
    }
}

function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing an unregistered reparse point inside the owned tree.'
            $items.Add($item)
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}

function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Get-FixtureInventory {
    return @($fixtures | ForEach-Object {
        [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Write-NewText {
    param([string]$Path, [string]$Text)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function New-SnapshotAudio {
    param([string]$RelativePath)
    $path = Join-Path $scanRoot $RelativePath
    Write-NewText $path ('Synthetic discovery bytes for ' + $RelativePath)
    $fixtures.Add($path)
    return $path
}

function New-OutputMarker {
    param([string]$Root, [string]$SelfPath = $Root, [int]$Schema = 1, [string]$Kind = 'AudioFileForPhone.Output')
    [IO.Directory]::CreateDirectory($Root) | Out-Null
    Write-NewText (Join-Path $Root '.AudioFileForPhone-output.json') (@{
        schema_version = $Schema; kind = $Kind; output_root = $SelfPath
    } | ConvertTo-Json -Compress)
}

function New-LegacyRoot {
    param([string]$Root, [string]$InputPath, [string]$SelfPath = $Root, [int]$Bitrate = 64, [switch]$LongLog, [switch]$OmitChild)
    [IO.Directory]::CreateDirectory($Root) | Out-Null
    if (-not $OmitChild) { [IO.Directory]::CreateDirectory((Join-Path $Root (Split-Path -Leaf $InputPath))) | Out-Null }
    $text = "==== AudioFileForPhone Log ====`r`nStart time    : synthetic`r`nInput folder  : $InputPath`r`nOutput root   : $SelfPath`r`nBitrate (kbps): $Bitrate`r`nMax base len  : 60`r`n"
    if ($LongLog) { $text += 'x' * 70000 }
    Write-NewText (Join-Path $Root 'AudioFileForPhone_log.txt') $text
}

function Assert-Snapshot {
    param($Snapshot, [string[]]$Expected)
    $actual = @($Snapshot.Files | ForEach-Object { $_.FullName })
    $sorted = [string[]]$Expected.Clone()
    [Array]::Sort($sorted, [StringComparer]::OrdinalIgnoreCase)
    Assert-True (($actual -join "`n") -ceq ($sorted -join "`n")) 'Snapshot must contain exactly the expected files in ordinal case-insensitive full-path order.'
    Assert-True (@($Snapshot.Files | Where-Object { $_ -isnot [IO.FileInfo] }).Count -eq 0) 'Snapshot files must be FileInfo values.'
    foreach ($skip in @($Snapshot.Skipped)) {
        Assert-True (-not [string]::IsNullOrWhiteSpace($skip.Path) -and -not [string]::IsNullOrWhiteSpace($skip.Reason)) 'Every skipped item must carry a path and visible reason.'
    }
}

function Assert-Skipped {
    param($Snapshot, [string]$Path, [string]$ReasonPattern)
    $matches = @($Snapshot.Skipped | Where-Object { $_.Path -ieq $Path })
    Assert-True ($matches.Count -eq 1 -and $matches[0].Reason -match $ReasonPattern) "Expected one skip for '$Path' with reason '$ReasonPattern'."
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-Application {
    param([string]$InputPath, [string]$OutputParent, [string]$Label, [switch]$Interactive)
    $code = '$ErrorActionPreference = ''Stop''; try { & ' + (ConvertTo-PowerShellLiteral $scriptCopy) +
        ' -InputFolder ' + (ConvertTo-PowerShellLiteral $InputPath) + ' -OutputParent ' +
        (ConvertTo-PowerShellLiteral $OutputParent)
    if ($Interactive) { $code += ' -Interactive' }
    $code += ' *>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { [Console]::Out.WriteLine($_.Exception.Message) } else { [Console]::Out.WriteLine([string]$_) } }; exit $LASTEXITCODE } catch { [Console]::Out.WriteLine($_.Exception.Message); exit 1 }'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
    $result = Invoke-AudioNativeProcess -ExecutablePath $shell -Arguments @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-EncodedCommand', $encoded)
    Assert-True ($result.Status -eq 'Completed' -and -not $result.StdoutTruncated -and -not $result.StderrTruncated) 'Application child must complete with untruncated diagnostics.'
    Write-NewText (Join-Path $testRoot ($Label + '.log')) ($result.Stdout + "`n" + $result.Stderr)
    return [pscustomobject]@{ exit_code = $result.ExitCode; text = $result.Stdout + "`n" + $result.Stderr }
}

function Assert-AbortBeforeRun {
    param($Result, [string]$OutputParent, [string]$Pattern)
    Assert-True ($Result.exit_code -ne 0 -and ($Result.text -replace '\s+', ' ') -match $Pattern) 'Unsafe discovery must return a nonzero child status with its diagnostic.'
    Assert-True ($Result.text -notmatch 'Optional metadata step|Processing file|\[INFO\] Output root\s+:|Log file saved to:') 'Discovery failure must precede metadata prompts, conversions and run/log creation.'
    Assert-True (@(Get-SafeTree $OutputParent).Count -eq 0) 'Rejected discovery must leave the owned output parent empty.'
}

try {
    Assert-NoReparse $evidenceParent
    Assert-NoReparse $tempParent
    $report.source_before = Get-SourceInventory
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace AudioFileForPhoneT06 {
    public static class NativeFixture {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr securityAttributes);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.I1)]
        public static extern bool CreateSymbolicLinkW(string path, string target, int flags);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share, IntPtr security,
            uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DeviceIoControl(SafeFileHandle handle, uint code, byte[] input, uint inputLength,
            IntPtr output, uint outputLength, out uint returned, IntPtr overlapped);
        public static int CreateCustomFileReparse(string path) {
            // Disposable test only: non-Microsoft name-surrogate tag + private
            // GUID. No driver/target exists, and no settings or privileges change.
            // REPARSE_GUID_DATA_BUFFER: ULONG tag, USHORT length/reserved, GUID.
            using (SafeFileHandle handle = CreateFileW(path, 0x40000000, 7, IntPtr.Zero, 1, 0x00200000, IntPtr.Zero)) {
                if (handle.IsInvalid) return Marshal.GetLastWin32Error();
                byte[] buffer = new byte[24];
                Buffer.BlockCopy(BitConverter.GetBytes((uint)0x2000A06E), 0, buffer, 0, 4);
                Buffer.BlockCopy(new Guid("05b0e647-6fd6-484e-9dc8-f08f78bca6ab").ToByteArray(), 0, buffer, 8, 16);
                uint returned;
                // CTL_CODE(FILE_DEVICE_FILE_SYSTEM, 41, METHOD_BUFFERED, FILE_SPECIAL_ACCESS)
                if (!DeviceIoControl(handle, 0x000900A4, buffer, (uint)buffer.Length, IntPtr.Zero, 0, out returned, IntPtr.Zero))
                    return Marshal.GetLastWin32Error();
                return 0;
            }
        }
    }
}
'@
    Assert-True ([AudioFileForPhoneT06.NativeFixture]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'TEMP root must be exclusively reserved.'
    $ownedRootCreated = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken
    $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'App [literal]'
    $scanRoot = Join-Path $testRoot 'Music [discovery fixture]'
    $outsideRoot = Join-Path $testRoot 'Outside source selection'
    $abortOutput = Join-Path $testRoot 'Abort output [literal]'
    $realMusic = Join-Path $testRoot 'Music [real fixture]'
    foreach ($directory in @($appRoot, $scanRoot, $outsideRoot, $abortOutput, $realMusic)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'
    $helpersCopy = Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Destination $scriptCopy
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1') -Destination $helpersCopy
    foreach ($copy in @($scriptCopy, $helpersCopy)) {
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot (Split-Path -Leaf $copy))).Hash) 'Application/helper copies must preserve exact source bytes.'
    }
    $report.copied_bytes_unchanged = $true
    . $helpersCopy
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
    $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($selection in @(@{ name = 'ffmpeg'; path = $ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe })) {
        $native = Invoke-AudioNativeProcess -ExecutablePath $selection.path -Arguments @('-version')
        Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 0) 'Selected native tool must report its version.'
        $report[$selection.name] = [ordered]@{ version = ($native.Stdout -split '\r?\n')[0]; sha256 = (Get-FileHash -LiteralPath $selection.path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath

    $expectedFiles = @()
    foreach ($relative in @('z last.OGG', 'Pod [literal]\a first.MP3', 'Pod [literal]\nested\middle.m4a',
        'AudioForPhone_user\keep.mp3', 'AudioForPhone_64kbps_20260101_010101-neighbor\keep.mp3',
        'AudioForPhone_64kbps_20261301_010101\keep.mp3', 'AudioForPhone_63kbps_20260101_010101\keep.mp3')) {
        $expectedFiles += New-SnapshotAudio $relative
    }
    Write-NewText (Join-Path $scanRoot 'ignored.wav') 'Unsupported discovery fixture.'
    $plannedRoot = Join-Path $scanRoot 'Destination\AudioForPhone_64kbps_20261011_120000'
    $explicitFile = New-SnapshotAudio 'Destination\AudioForPhone_64kbps_20261011_120000\skip.mp3'
    $markedRoot = Join-Path $scanRoot 'Marked prior output'
    New-OutputMarker $markedRoot
    $markedFile = New-SnapshotAudio 'Marked prior output\skip.mp3'
    $legacyRoot = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010101'
    New-LegacyRoot $legacyRoot (Join-Path $testRoot 'Historical input') -LongLog
    $legacyFile = New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010101\Historical input\skip.mp3'
    $emptyLegacy = Join-Path $scanRoot 'AudioForPhone_80kbps_20260101_010102'
    New-LegacyRoot $emptyLegacy (Join-Path $testRoot 'Historical empty input') -Bitrate 80
    $malformedMarkerRoot = Join-Path $scanRoot 'Malformed marker'
    Write-NewText (Join-Path $malformedMarkerRoot '.AudioFileForPhone-output.json') '{ bad json'
    $expectedFiles += New-SnapshotAudio 'Malformed marker\keep.mp3'
    foreach ($invalid in @(@{ name = 'Marker wrong self'; self = $markedRoot; schema = 1; kind = 'AudioFileForPhone.Output' },
        @{ name = 'Marker wrong schema'; self = $null; schema = 2; kind = 'AudioFileForPhone.Output' },
        @{ name = 'Marker wrong kind'; self = $null; schema = 1; kind = 'User.Output' })) {
        $invalidRoot = Join-Path $scanRoot $invalid.name
        $self = if ($invalid.self) { $invalid.self } else { $invalidRoot }
        New-OutputMarker $invalidRoot -SelfPath $self -Schema $invalid.schema -Kind $invalid.kind
        $expectedFiles += New-SnapshotAudio ($invalid.name + '\keep.mp3')
    }
    $wrongLegacy = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010103'
    New-LegacyRoot $wrongLegacy (Join-Path $testRoot 'Historical input') -SelfPath $legacyRoot
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010103\Historical input\keep.mp3'
    $missingChild = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010104'
    New-LegacyRoot $missingChild (Join-Path $testRoot 'Absent input leaf') -OmitChild
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010104\keep.mp3'
    $wrongRate = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010105'
    New-LegacyRoot $wrongRate (Join-Path $testRoot 'Historical input') -Bitrate 80
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010105\Historical input\keep.mp3'
    $driveRelativeInput = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010106'
    New-LegacyRoot $driveRelativeInput 'C:Historical input'
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010106\Historical input\keep.mp3'
    $driveRelativeOutput = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010107'
    New-LegacyRoot $driveRelativeOutput (Join-Path $testRoot 'Historical input') -SelfPath ('C:' + (Split-Path -Leaf $driveRelativeOutput))
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010107\Historical input\keep.mp3'
    $relativeLegacyInput = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010108'
    New-LegacyRoot $relativeLegacyInput 'Historical input'
    $expectedFiles += New-SnapshotAudio 'AudioForPhone_64kbps_20260101_010108\Historical input\keep.mp3'
    $caseLegacy = Join-Path $scanRoot 'AudioForPhone_64kbps_20260101_010109'
    New-LegacyRoot $caseLegacy (Join-Path $testRoot 'Historical casing input').ToUpperInvariant() -SelfPath $caseLegacy.ToUpperInvariant()
    $outsideAudio = Join-Path $outsideRoot 'never traverse.mp3'
    Write-NewText $outsideAudio 'Synthetic out-of-selection audio.'
    $fixtures.Add($outsideAudio)

    $loopPath = Join-Path $scanRoot 'JunctionLoop'
    $outLink = Join-Path $scanRoot 'JunctionOutside'
    $parentLink = Join-Path $testRoot 'JunctionInputAncestor'
    foreach ($link in @(@{ path = $loopPath; target = $scanRoot }, @{ path = $outLink; target = $outsideRoot }, @{ path = $parentLink; target = $scanRoot })) {
        # PS5.1 resolves a junction's Value as a wildcard path. Escape our known
        # owned target so brackets refer to exactly the literal fixture; PS7
        # accepts Value literally and must receive the original spelling.
        $junctionTarget = if ($PSVersionTable.PSEdition -eq 'Desktop') { [Management.Automation.WildcardPattern]::Escape($link.target) } else { $link.target }
        New-Item -ItemType Junction -Path $link.path -Value $junctionTarget | Out-Null
        $links.Add([pscustomobject]@{ path = $link.path; directory = $true })
        Assert-True (((Get-Item -LiteralPath $link.path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Owned junction fixture must actually be a reparse point.'
    }
    $fileLink = Join-Path $scanRoot 'LinkedAudio.mp3'
    $symlinkCreated = [AudioFileForPhoneT06.NativeFixture]::CreateSymbolicLinkW($fileLink, $outsideAudio, 2)
    $unprivilegedSymlinkError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    $ordinarySymlinkError = 0
    if (-not $symlinkCreated) {
        $symlinkCreated = [AudioFileForPhoneT06.NativeFixture]::CreateSymbolicLinkW($fileLink, $outsideAudio, 0)
        $ordinarySymlinkError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    }
    $report['file_symlink_capability'] = [ordered]@{
        available = $symlinkCreated; unprivileged_win32_error = $unprivilegedSymlinkError; ordinary_win32_error = $ordinarySymlinkError
        machine_settings_changed = $false
    }
    $fileReparseKind = 'file symbolic link'
    if (-not $symlinkCreated) {
        # Microsoft's documented GUID buffer and tag bits permit an actual,
        # inert file reparse fixture without pretending symlink creation passed.
        # https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_guid_data_buffer
        # https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-point-tags
        # https://learn.microsoft.com/en-us/windows/win32/api/winioctl/ni-winioctl-fsctl_set_reparse_point
        $customError = [AudioFileForPhoneT06.NativeFixture]::CreateCustomFileReparse($fileLink)
        Assert-True ($customError -eq 0) "Owned custom file-reparse fixture must be created (Win32 $customError); file-symlink capability unavailable (Win32 $ordinarySymlinkError)."
        $fileReparseKind = 'inert custom non-Microsoft name-surrogate reparse tag 0x2000A06E'
    }
    $links.Add([pscustomobject]@{ path = $fileLink; directory = $false })
    Assert-True (((Get-Item -LiteralPath $fileLink -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Owned file fixture must actually be a reparse point.'
    $report['file_reparse_fixture'] = [ordered]@{ kind = $fileReparseKind; actual_reparse_attribute = $true }
    if (-not $symlinkCreated) {
        $ordinaryReadFailed = $false
        try { [IO.File]::ReadAllBytes($fileLink) | Out-Null } catch [IO.IOException] { $ordinaryReadFailed = $true }
        Assert-True $ordinaryReadFailed 'Custom file reparse fixture must reject ordinary content reads on this host.'
        $report.file_reparse_fixture['ordinary_content_read_failed'] = $true
    }
    $aclInput = Join-Path $testRoot 'ACL input'
    $aclDenied = Join-Path $aclInput 'denied subtree'
    Write-NewText (Join-Path $aclInput 'early.mp3') 'Synthetic audio before inaccessible subtree.'
    Write-NewText (Join-Path $aclDenied 'hidden.mp3') 'Synthetic inaccessible source.'
    $fixtures.Add((Join-Path $aclInput 'early.mp3')); $fixtures.Add((Join-Path $aclDenied 'hidden.mp3'))
    $realSource = Join-Path $realMusic 'Pod [literal]\2024-01-02 - Synthetic.mp3'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $realSource)) | Out-Null
    $native = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=0.3', '-c:a', 'libmp3lame', '-metadata', 'title=T06 synthetic title', $realSource)
    Assert-True ($native.Status -eq 'Completed' -and $native.ExitCode -eq 0) 'Short real audio fixture must be generated.'
    $fixtures.Add($realSource)
    $realNeighbor = Join-Path $realMusic 'AudioForPhone_user\2024-01-03 - User prefix.mp3'
    [IO.Directory]::CreateDirectory((Split-Path -Parent $realNeighbor)) | Out-Null
    Copy-Item -LiteralPath $realSource -Destination $realNeighbor
    $fixtures.Add($realNeighbor)
    $report.synthetic_before = Get-FixtureInventory

    Invoke-Case 'canonical filesystem paths and separator-aware ordinal containment' 'A17' {
        param($case)
        $child = Join-Path $scanRoot 'Pod [literal]'
        Assert-True ((Get-AudioPath ($child + '\..\Pod [literal]\.\')) -ceq $child) 'Canonicalization must collapse dot segments and trailing separators.'
        Assert-True ((Get-AudioPath ('FileSystem::' + $child)) -ceq $child) 'Filesystem-qualified paths must retain literal bracket spelling.'
        Push-Location -LiteralPath $scanRoot
        try { Assert-True ((Get-AudioPath '.\Pod [literal]') -ceq $child) 'Relative canonicalization must use current PowerShell location.' } finally { Pop-Location }
        foreach ($providerPath in @('Env:\TEMP', 'Registry::HKEY_CURRENT_USER\Software')) { Assert-Throws { Get-AudioPath $providerPath } 'filesystem' }
        Assert-True (Test-AudioPathWithin -Path $child.ToUpperInvariant() -Parent ($scanRoot + '\')) 'Containment must be case insensitive and ignore trailing parent separators.'
        Assert-True (Test-AudioPathWithin -Path $scanRoot -Parent $scanRoot.ToUpperInvariant()) 'Containment includes equality.'
        Assert-True (-not (Test-AudioPathWithin -Path ($scanRoot + '2\child') -Parent $scanRoot)) 'Similarly prefixed neighbors must not be descendants.'
        Assert-True (-not (Test-AudioPathWithin -Path $scanRoot -Parent $child)) 'A parent must not be inside its child.'
        $case['comparison_checks'] = 9
    }
    Invoke-Case 'output equal or ancestor rejected; nested output and prefix neighbors allowed' 'A17' {
        Assert-Throws { Assert-AudioOutputBoundary -InputFolder $scanRoot -OutputRoot $scanRoot } 'output|boundary|ancestor|contain|equal'
        Assert-Throws { Assert-AudioOutputBoundary -InputFolder $scanRoot -OutputRoot $testRoot } 'output|boundary|ancestor|contain'
        Assert-AudioOutputBoundary -InputFolder $scanRoot -OutputRoot (Join-Path $scanRoot 'new output\run')
        Assert-AudioOutputBoundary -InputFolder $scanRoot -OutputRoot ($scanRoot + '2\run')
    }
    Invoke-Case 'deterministic snapshot excludes explicit marked and structured legacy output' 'A15' {
        param($case)
        # The malformed drive-relative log root would resolve to its actual
        # directory here. A current drive location must never confer ownership.
        Push-Location -LiteralPath $scanRoot
        try {
            $snapshot = Get-AudioInputSnapshot -InputFolder $scanRoot -OutputRoot $plannedRoot
        }
        finally { Pop-Location }
        Assert-Snapshot $snapshot $expectedFiles
        foreach ($root in @($markedRoot, $legacyRoot, $emptyLegacy, $caseLegacy)) { Assert-Skipped $snapshot $root 'generated|legacy|output' }
        Assert-Skipped $snapshot $plannedRoot 'output|destination'
        $again = Get-AudioInputSnapshot -InputFolder $scanRoot -OutputRoot $plannedRoot
        Assert-Snapshot $again $expectedFiles
        Assert-True (($snapshot.Files.FullName -join "`n") -ceq ($again.Files.FullName -join "`n")) 'Repeated discovery must be stable.'
        $case['input_count'] = @($snapshot.Files).Count; $case['skip_count'] = @($snapshot.Skipped).Count
        $case['long_legacy_log_prefix_recognized'] = (Get-Item -LiteralPath (Join-Path $legacyRoot 'AudioFileForPhone_log.txt')).Length -gt 65536
        $case['arbitrary_prefix_and_malformed_identity_retained'] = $true
        $case['drive_relative_legacy_identity_retained'] = $true
    }
    Invoke-Case 'junction loop outside target and actual file reparse skipped visibly' 'A16' {
        param($case)
        $snapshot = Get-AudioInputSnapshot -InputFolder $scanRoot -OutputRoot $plannedRoot
        Assert-Snapshot $snapshot $expectedFiles
        foreach ($link in @($loopPath, $outLink, $fileLink)) { Assert-Skipped $snapshot $link 'reparse|junction|symbolic' }
        Assert-True (@($snapshot.Files | Where-Object { $_.FullName -ieq $outsideAudio }).Count -eq 0) 'Out-of-selection target must never be traversed.'
        $case['actual_junctions'] = 2; $case['actual_file_reparse_points'] = 1
        $case['file_reparse_kind'] = $fileReparseKind; $case['file_symbolic_link_available'] = $symlinkCreated
    }
    Invoke-Case 'selected generated root rejected before run and prompts' 'A15' {
        Assert-Throws { Get-AudioInputSnapshot -InputFolder $legacyRoot.ToUpperInvariant() -OutputRoot (Join-Path $abortOutput 'run') } 'generated|output'
        Assert-Throws { Get-AudioInputSnapshot -InputFolder (Join-Path $legacyRoot 'Historical input') -OutputRoot (Join-Path $abortOutput 'run') } 'generated|output'
        $result = Invoke-Application $markedRoot $abortOutput 'selected-generated' -Interactive
        Assert-AbortBeforeRun $result $abortOutput 'generated|output'
    }
    Invoke-Case 'selected reparse directory and reparse ancestry rejected' 'A16' {
        Assert-Throws { Get-AudioInputSnapshot -InputFolder $loopPath -OutputRoot (Join-Path $abortOutput 'run') } 'reparse|junction|symbolic'
        Assert-Throws { Assert-AudioOutputBoundary -InputFolder (Join-Path $parentLink 'Pod [literal]') -OutputRoot (Join-Path $abortOutput 'run') } 'reparse|junction|symbolic'
        Assert-Throws { Assert-AudioOutputBoundary -InputFolder $aclInput -OutputRoot (Join-Path $parentLink 'new output\run') } 'reparse|junction|symbolic'
        $result = Invoke-Application $loopPath $abortOutput 'selected-reparse' -Interactive
        Assert-AbortBeforeRun $result $abortOutput 'reparse|junction|symbolic'
    }
    Invoke-Case 'ACL-denied descendant aborts snapshot and application before prompts and run' 'A16' {
        param($case)
        Assert-NoReparse $aclDenied
        Assert-True ($aclDenied.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'ACL fixture must stay in this exact owned TEMP tree.'
        $original = Get-Acl -LiteralPath $aclDenied
        $savedAcls.Add([pscustomobject]@{ path = $aclDenied; acl = $original; sddl = $original.Sddl; restored = $false })
        $changed = Get-Acl -LiteralPath $aclDenied
        $rule = New-Object Security.AccessControl.FileSystemAccessRule([Security.Principal.WindowsIdentity]::GetCurrent().User,
            [Security.AccessControl.FileSystemRights]::ListDirectory, [Security.AccessControl.InheritanceFlags]::None,
            [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Deny)
        $changed.AddAccessRule($rule); Set-Acl -LiteralPath $aclDenied -AclObject $changed
        $effectiveDenial = $false
        try { Get-ChildItem -LiteralPath $aclDenied -Force -ErrorAction Stop | Out-Null } catch [UnauthorizedAccessException] { $effectiveDenial = $true }
        Assert-True $effectiveDenial 'Fixture ACL must actually deny enumeration on this Windows host.'
        Assert-Throws { Get-AudioInputSnapshot -InputFolder $aclInput -OutputRoot (Join-Path $abortOutput 'run') } 'access|read|enumerat|scan'
        $result = Invoke-Application $aclInput $abortOutput 'denied-subtree' -Interactive
        Assert-AbortBeforeRun $result $abortOutput 'access|read|enumerat|scan'
        $case['effective_operation_denial'] = $true; $case['prompt_conversion_and_run_absent'] = $true
    }
    Invoke-Case 'real Music-like input repeated runs preserve source layout and exclude prior output' 'A15' {
        param($case)
        $outputs = @()
        foreach ($label in @('first', 'second')) {
            $parent = Join-Path $realMusic ('Destination ' + $label)
            [IO.Directory]::CreateDirectory($parent) | Out-Null
            $result = Invoke-Application $realMusic $parent ('real-' + $label)
            Assert-True ($result.exit_code -eq 0) "Real $label conversion must succeed: $($result.text)"
            $roots = @($result.text -split '\r?\n' | ForEach-Object { if ($_ -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1].Trim() } })
            Assert-True ($roots.Count -eq 1 -and (Split-Path -Parent $roots[0]) -ieq $parent) 'Run must report one root in the selected nested TEMP destination.'
            $root = $roots[0]
            Assert-True (Test-Path -LiteralPath (Join-Path $root '.AudioFileForPhone-output.json') -PathType Leaf) 'Current run must write its recognition marker.'
            $audio = @(Get-SafeTree $root | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
            Assert-True ($audio.Count -eq 2) 'Each repeated run must convert only the two original files.'
            foreach ($relative in @('Pod [literal]\2024-01-02 - Synthetic.mp3', 'AudioForPhone_user\2024-01-03 - User prefix.mp3')) {
                $destination = Join-Path $root ((Split-Path -Leaf $realMusic) + '\' + $relative)
                Assert-True (Test-Path -LiteralPath $destination -PathType Leaf) 'Real conversion must preserve recursive relative layout and date-first names.'
                $probe = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $destination)
                Assert-True ($probe.ExitCode -eq 0 -and $probe.Status -eq 'Completed') 'Output probe must succeed.'
                $media = $probe.Stdout | ConvertFrom-Json
                $streams = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
                Assert-True ($streams.Count -eq 1 -and $streams[0].codec_name -eq 'mp3' -and [int]$streams[0].bit_rate -eq 64000) 'Default output must have one 64 kbps MP3 audio stream.'
                Assert-True ($media.format.tags.title -eq 'T06 synthetic title') 'Real conversion must preserve original title metadata.'
                $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-i', $destination, '-f', 'null', '-')
                Assert-True ($decode.ExitCode -eq 0 -and $decode.Status -eq 'Completed') 'Every short output must fully decode.'
            }
            $outputs += $root
            $snapshot = Get-AudioInputSnapshot -InputFolder $realMusic -OutputRoot (Join-Path $realMusic 'Future destination\new run')
            Assert-Snapshot $snapshot @($realSource, $realNeighbor)
            foreach ($prior in $outputs) { Assert-Skipped $snapshot $prior 'generated|output' }
        }
        $case['runs'] = 2; $case['original_files_per_run'] = 2; $case['default_audio_bitrate'] = 64000
        $case['full_decode_and_metadata'] = $true; $case['music_destination'] = 'owned TEMP synthetic Music only'
    }
    $report.status = 'pass'; $exitCode = 0
}
catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
    Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    $aclRestoreSuccess = $true
    foreach ($saved in $savedAcls) {
        try {
            Assert-NoReparse $saved.path
            Set-Acl -LiteralPath $saved.path -AclObject $saved.acl
            $saved.restored = (Get-Acl -LiteralPath $saved.path).Sddl -ceq $saved.sddl
            Assert-True $saved.restored 'Original fixture ACL must be restored exactly.'
        }
        catch { $aclRestoreSuccess = $false; $report['acl_restore_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    $report.acls_restored = $aclRestoreSuccess
    if (-not $aclRestoreSuccess) { $report.status = 'fail'; $exitCode = 1 }
    foreach ($inventory in @('source', 'synthetic')) {
        try {
            $after = if ($inventory -eq 'source') { Get-SourceInventory } else { Get-FixtureInventory }
            $report[$inventory + '_after'] = $after
            $same = (($report[$inventory + '_before'] | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress))
            $report[$inventory + '_unchanged'] = $same
            Assert-True $same "$inventory SHA-256 inventory must remain unchanged."
        }
        catch { $report.status = 'fail'; $exitCode = 1; $report[$inventory + '_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    try {
        if ($ownedRootCreated -and $aclRestoreSuccess -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay inside the exact exclusively reserved TEMP root.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact create-new owner token.'
            foreach ($link in $links) {
                Assert-True ($link.path.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Only registered links inside this owned root may be removed.'
                Assert-NoReparse (Split-Path -Parent $link.path)
                $item = Get-Item -LiteralPath $link.path -Force -ErrorAction Stop
                Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Link cleanup requires the registered entry to remain a reparse point.'
                if ($link.directory) { [IO.Directory]::Delete($link.path, $false) } else { [IO.File]::Delete($link.path) }
                Assert-True (-not (Test-Path -LiteralPath $link.path)) 'Registered fixture link must be removed without traversing its target.'
            }
            $report.links_removed = $true
            Get-SafeTree $resolved | Out-Null
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Owned TEMP cleanup must be verified.'
    }
    catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    $bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 14))
    $evidence = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $evidence.Write($bytes, 0, $bytes.Length) } finally { $evidence.Dispose() }
}
Write-Host "T06 discovery: $($report.status); cases=$($report.cases.Count); ACL restored=$($report.acls_restored); links removed=$($report.links_removed); cleanup=$($report.cleanup_verified); source/synthetic unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
