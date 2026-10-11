<#
T07 pure naming/path plans and short real-FFmpeg acceptance on Windows PS5.1/PS7.
Fixtures and application copies stay inside one exclusively owned, short TEMP
root. Native extended paths create only owned boundary/trailing-dot fixtures;
the production policy still rejects unsupported Windows paths. No Music use.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempCandidates = @([IO.Path]::GetTempPath(), [Environment]::GetEnvironmentVariable('TEMP', 'Machine')) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($_)).TrimEnd('\', '/') }
$tempParent = @($tempCandidates | Sort-Object Length | Select-Object -Unique)[0]
$testName = 'T7-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t07-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$originalPath = $env:PATH
$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
$originalUiCulture = [Threading.Thread]::CurrentThread.CurrentUICulture
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$nativeFiles = New-Object 'System.Collections.Generic.List[string]'
$nativeDirectories = New-Object 'System.Collections.Generic.List[string]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-NamingPlan.ps1')
$exitCode = 1
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T07|T08)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T07/T08-<label>.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label to preserve prior evidence.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'pure_naming_path_and_real_conversion'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    temp_parent_selection = 'shorter existing user/machine TEMP, read-only environment lookup'
    owned_temp_root_name = $testName
    owner_marker_sha256 = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($ownerToken)))).Replace('-', '').ToLowerInvariant()
    cases = @(); native_fixture_cleanup = $false; cleanup_verified = $false
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
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing a reparse point inside the owned test tree.'
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
        [pscustomobject]@{
            relative_path = $_.Substring($testRoot.Length + 1)
            sha256 = [AudioFileForPhoneT07.NativeFixture]::HashFile($_)
        }
    })
}

function Write-NewText {
    param([string]$Path, [string]$Text)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

function Assert-ValidScalars {
    param([string]$Value)
    for ($index = 0; $index -lt $Value.Length; $index++) {
        if ([char]::IsHighSurrogate($Value[$index])) {
            Assert-True ($index + 1 -lt $Value.Length -and [char]::IsLowSurrogate($Value[$index + 1])) 'Output must never end with or contain an unpaired high surrogate.'
            $index++
        }
        else { Assert-True (-not [char]::IsLowSurrogate($Value[$index])) 'Output must never contain an unpaired low surrogate.' }
    }
}

function Assert-Name {
    param([string]$RelativePath, [string]$ExpectedBase, [int]$Limit = 60, [int]$Counter = 1)
    $plan = Get-AudioNamePlan -SourceRelativePath $RelativePath -LastWriteTime $fallback -MaxBaseLength $Limit -Counter $Counter
    Assert-True ($plan.BaseName -ceq $ExpectedBase) "Exact basename mismatch for '$RelativePath': '$($plan.BaseName)' versus '$ExpectedBase'."
    $parent = Split-Path -Parent $RelativePath
    $expectedRelative = if ($parent) { Join-Path $parent ($ExpectedBase + '.mp3') } else { $ExpectedBase + '.mp3' }
    Assert-True ($plan.OutputRelativePath -ceq $expectedRelative) 'Single-file plan must preserve relative directories and append .mp3.'
    Assert-True ($plan.BaseName.Length -le $Limit -and $plan.BaseName -match '^\d{4}-\d{2}-\d{2} - .+') 'Complete date/separator/title/suffix must fit the UTF-16 basename budget.'
    Assert-ValidScalars $plan.BaseName
    return $plan
}

function Get-PlanMapping {
    param([object[]]$Plan)
    return @($Plan | ForEach-Object { $_.SourcePath + ' -> ' + $_.OutputRelativePath }) -join "`n"
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-Application {
    param([string]$InputPath, [string]$OutputParent, [string]$Label, [int]$Limit = 60, [switch]$Interactive)
    $code = '$ErrorActionPreference = ''Stop''; try { & ' + (ConvertTo-PowerShellLiteral $scriptCopy) +
        ' -InputFolder ' + (ConvertTo-PowerShellLiteral $InputPath) + ' -OutputParent ' +
        (ConvertTo-PowerShellLiteral $OutputParent) + ' -MaxBaseLength ' + $Limit.ToString([Globalization.CultureInfo]::InvariantCulture)
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
    Assert-True ($Result.exit_code -ne 0 -and ($Result.text -replace '\s+', ' ') -match $Pattern) 'Unsupported tree must return a nonzero child status with an actionable path/component diagnostic.'
    Assert-True ($Result.text -notmatch 'Optional metadata step|Processing file|\[INFO\] Output root\s+:|Log file saved to:') 'Planning failure must precede metadata prompts, conversions and run/log creation.'
    Assert-True (@(Get-SafeTree $OutputParent).Count -eq 0) 'Rejected planning must leave the owned output parent empty.'
}

function New-NativeDirectory {
    param([string]$Path)
    Assert-True ($Path.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Native fixture creation must stay inside this exact owned TEMP root.'
    $result = [AudioFileForPhoneT07.NativeFixture]::CreateDirectoryW([AudioFileForPhoneT07.NativeFixture]::Extended($Path), [IntPtr]::Zero)
    Assert-True $result "Owned native directory fixture creation failed (Win32 $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
    $nativeDirectories.Add($Path)
}

function New-NativeFile {
    param([string]$Path, [byte[]]$Bytes)
    Assert-True ($Path.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Native file creation must stay inside this exact owned TEMP root.'
    [AudioFileForPhoneT07.NativeFixture]::WriteFileNew($Path, $Bytes)
    $nativeFiles.Add($Path); $fixtures.Add($Path)
}

function Assert-NativeExists {
    param([string]$Path, [bool]$Directory)
    $attributes = [AudioFileForPhoneT07.NativeFixture]::GetFileAttributesW([AudioFileForPhoneT07.NativeFixture]::Extended($Path))
    Assert-True ($attributes -ne [uint32]::MaxValue) 'Actual native boundary fixture must exist.'
    Assert-True (($attributes -band 0x400) -eq 0) 'Owned native fixture must not be a reparse point.'
    Assert-True ((($attributes -band 0x10) -ne 0) -eq $Directory) 'Actual native fixture must have the expected file/directory kind.'
}

function Verify-RealRun {
    param([string]$InputPath, [string]$Parent, [string]$Label, [int]$Limit)
    $inputFiles = @(Get-SafeTree $InputPath | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
    $result = Invoke-Application $InputPath $Parent $Label -Limit $Limit
    Assert-True ($result.exit_code -eq 0) "Real conversion must succeed: $($result.text)"
    $roots = @($result.text -split '\r?\n' | ForEach-Object { if ($_ -match '^\[INFO\] Output root\s+: (.+)$') { $Matches[1].Trim() } })
    Assert-True ($roots.Count -eq 1 -and (Split-Path -Parent $roots[0]) -ieq $Parent) 'Run must report one root inside the selected owned TEMP parent.'
    $plan = @(Get-AudioBatchNamePlan -Files $inputFiles -InputFolder $InputPath -OutputRoot $roots[0] -MaxBaseLength $Limit)
    $actual = @(Get-SafeTree $roots[0] | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.mp3' })
    Assert-True ($actual.Count -eq $plan.Count -and $plan.Count -eq $inputFiles.Count) 'Actual audio count must equal the complete pure batch plan.'
    foreach ($record in $plan) {
        Assert-True (Test-Path -LiteralPath $record.OutputPath -PathType Leaf) 'Actual output must use the exact planned literal path.'
        Assert-True ($record.BaseName.Length -le $Limit -and $record.OutputPath.Length -lt 260) 'Actual complete basename/file path must fit both budgets.'
        Assert-ValidScalars $record.BaseName
        $probe = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v', 'error', '-show_streams', '-show_format', '-of', 'json', $record.OutputPath)
        Assert-True ($probe.Status -eq 'Completed' -and $probe.ExitCode -eq 0) 'Real output probe must succeed.'
        $media = $probe.Stdout | ConvertFrom-Json
        $audio = @($media.streams | Where-Object { $_.codec_type -eq 'audio' })
        Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -eq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Actual default output must contain one 64 kbps MP3 audio stream.'
        $expectedTitle = if ($record.SourcePath -ieq $metadataSource) { $metadataTitle } else { $record.BaseName }
        Assert-True ($media.format.tags.title -ceq $expectedTitle) 'Existing title must persist; missing title must equal the allocated collision-adjusted basename.'
        $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-i', $record.OutputPath, '-f', 'null', '-')
        Assert-True ($decode.Status -eq 'Completed' -and $decode.ExitCode -eq 0) 'Every short real output must fully decode.'
    }
    return [pscustomobject]@{ root = $roots[0]; plan = $plan; count = $actual.Count; max_path_length = ($plan.OutputPath | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum }
}

try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    $report.source_before = Get-SourceInventory
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
namespace AudioFileForPhoneT07 {
    public static class NativeFixture {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr security);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        public static extern uint GetFileAttributesW(string path);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DeleteFileW(string path);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool RemoveDirectoryW(string path);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
        private static extern SafeFileHandle CreateFileW(string path, uint access, uint share, IntPtr security,
            uint creation, uint flags, IntPtr template);
        public static string Extended(string path) {
            if (path.StartsWith(@"\\?\")) return path;
            if (path.StartsWith(@"\\")) return @"\\?\UNC\" + path.Substring(2);
            return @"\\?\" + path;
        }
        public static void WriteFileNew(string path, byte[] bytes) {
            using (SafeFileHandle handle = CreateFileW(Extended(path), 0x40000000, 0, IntPtr.Zero, 1, 0x00200000, IntPtr.Zero)) {
                if (handle.IsInvalid) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
                using (FileStream stream = new FileStream(handle, FileAccess.Write)) stream.Write(bytes, 0, bytes.Length);
            }
        }
        public static string HashFile(string path) {
            using (SafeFileHandle handle = CreateFileW(Extended(path), 0x80000000, 7, IntPtr.Zero, 3, 0x00200000, IntPtr.Zero)) {
                if (handle.IsInvalid) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
                using (FileStream stream = new FileStream(handle, FileAccess.Read))
                using (SHA256 hash = SHA256.Create()) return BitConverter.ToString(hash.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
            }
        }
    }
}
'@
    Assert-True ([AudioFileForPhoneT07.NativeFixture]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Short TEMP root must be exclusively reserved and writable.'
    $ownedRootCreated = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'A'; $inputRoot = Join-Path $testRoot 'I'; $longNameInput = Join-Path $testRoot 'L'
    $outputParent = Join-Path $testRoot 'O'; $longNameOutput = Join-Path $testRoot 'P'; $abortOutput = Join-Path $testRoot 'X'
    $boundaryRoot = Join-Path $testRoot 'B'; $longInput = Join-Path $testRoot 'Long'; $badInput = Join-Path $testRoot 'Bad'
    foreach ($directory in @($appRoot, $inputRoot, $longNameInput, $outputParent, $longNameOutput, $abortOutput, $boundaryRoot, $longInput, $badInput)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'; $helpersCopy = Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -Destination $scriptCopy
    Copy-Item -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1') -Destination $helpersCopy
    foreach ($copy in @($scriptCopy, $helpersCopy)) {
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot (Split-Path -Leaf $copy))).Hash) 'Application/helper copies must preserve exact source bytes.'
    }
    $report.copied_bytes_unchanged = $true
    . $helpersCopy
    $fallback = [DateTime]::ParseExact('2031-03-04', 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $supplementaryLetter = [char]::ConvertFromUtf32(0x10400)
    $supplementaryDigit = [char]::ConvertFromUtf32(0x1D7CE)
    $emoji = [char]::ConvertFromUtf32(0x1F60A)
    $composed = 'Caf' + [char]0xE9; $decomposed = 'Cafe' + [char]0x301
    $hangulComposed = [string][char]0xAC00; $hangulSeparated = [string][char]0x1100 + '!' + [char]0x1161
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($selection in @(@{ name = 'ffmpeg'; path = $ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe })) {
        $version = Invoke-AudioNativeProcess -ExecutablePath $selection.path -Arguments @('-version')
        Assert-True ($version.Status -eq 'Completed' -and $version.ExitCode -eq 0) 'Selected native tool must report its version.'
        $report[$selection.name] = [ordered]@{ version = ($version.Stdout -split '\r?\n')[0]; sha256 = (Get-FileHash -LiteralPath $selection.path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
    $seed = Join-Path $testRoot 'seed.mp3'
    $generated = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=0.2', '-c:a', 'libmp3lame', '-map_metadata', '-1', $seed)
    Assert-True ($generated.Status -eq 'Completed' -and $generated.ExitCode -eq 0) 'Short synthetic no-title MP3 fixture must be generated.'
    $fixtures.Add($seed)
    foreach ($punctuation in @('!', '#', '$', '%', '&', "'", '(', ')', '+', '=', '[', ']')) {
        $path = Join-Path $inputRoot ('2024-01-02 - E' + $punctuation + 'pisode.mp3')
        Copy-Item -LiteralPath $seed -Destination $path; $fixtures.Add($path)
        [IO.File]::SetLastWriteTime($path, $fallback)
    }
    foreach ($name in @('2023-02-29 - Impossible.mp3', ('2024-01-02 - ' + $composed + '.mp3'), ('2024-01-02 - ' + $decomposed + '.mp3'))) {
        $path = Join-Path $inputRoot $name; Copy-Item -LiteralPath $seed -Destination $path; $fixtures.Add($path)
        [IO.File]::SetLastWriteTime($path, $fallback)
    }
    $literalDirectory = Join-Path $inputRoot "Prefix [literal] O'Brien"
    $neighborDirectory = Join-Path $inputRoot "Prefix [literal] O'Brien2"
    foreach ($directory in @($literalDirectory, $neighborDirectory)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $path = Join-Path $directory '2024-01-02 - Literal [x].mp3'
        Copy-Item -LiteralPath $seed -Destination $path; $fixtures.Add($path); [IO.File]::SetLastWriteTime($path, $fallback)
    }
    $metadataTitle = 'Original ' + [char]0xC4 + ' title'
    $metadataSource = Join-Path $inputRoot '2024-02-29 - Metadata.mp3'
    $tagged = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-hide_banner', '-loglevel', 'error', '-nostdin', '-i', $seed, '-c:a', 'copy', '-metadata', ('title=' + $metadataTitle), $metadataSource)
    Assert-True ($tagged.Status -eq 'Completed' -and $tagged.ExitCode -eq 0) 'Short tagged synthetic fixture must be generated.'
    $fixtures.Add($metadataSource); [IO.File]::SetLastWriteTime($metadataSource, $fallback)
    $longNameSource = Join-Path $longNameInput ('2024-01-02 - ' + ('x' * 167) + '.mp3')
    Copy-Item -LiteralPath $seed -Destination $longNameSource; $fixtures.Add($longNameSource); [IO.File]::SetLastWriteTime($longNameSource, $fallback)
    $boundaryDirectories = @()
    foreach ($length in @(247, 248)) {
        $path = Join-Path $boundaryRoot (('d' + $length + '-') + ('d' * ($length - $boundaryRoot.Length - 1 - 5)))
        Assert-True ($path.Length -eq $length) 'Boundary directory fixture must have the exact requested UTF-16 length.'
        New-NativeDirectory $path; $boundaryDirectories += $path
    }
    $boundaryFiles = @()
    foreach ($length in @(259, 260)) {
        $path = Join-Path $boundaryRoot (('f' + $length + '-') + ('f' * ($length - $boundaryRoot.Length - 1 - 5 - 4)) + '.mp3')
        Assert-True ($path.Length -eq $length) 'Boundary file fixture must have the exact requested UTF-16 length.'
        New-NativeFile $path ([Text.Encoding]::UTF8.GetBytes('Synthetic native path boundary.')); $boundaryFiles += $path
    }
    $deepDirectory = Join-Path $longInput ('d' * (230 - $longInput.Length - 1))
    New-NativeDirectory $deepDirectory
    New-NativeFile (Join-Path $deepDirectory '2024-01-02 - Deep.mp3') ([IO.File]::ReadAllBytes($seed))
    foreach ($name in @('bad.', 'bad ')) {
        $path = Join-Path $badInput $name; New-NativeDirectory $path
        New-NativeFile (Join-Path $path '2024-01-02 - Unsafe.mp3') ([IO.File]::ReadAllBytes($seed))
    }
    $report.synthetic_before = Get-FixtureInventory

    Invoke-Case 'real calendar dates fallback whole title and locale independence' 'A18' {
        param($case)
        $dates = @(@{ source = '2024-02-29 - Leap.mp3'; expected = '2024-02-29 - Leap' },
            @{ source = '2000-02-29 - Century.mp3'; expected = '2000-02-29 - Century' },
            @{ source = '1900-02-29 - False.mp3'; expected = '2031-03-04 - 1900-02-29 - False' },
            @{ source = '2023-02-29 - Impossible.mp3'; expected = '2031-03-04 - 2023-02-29 - Impossible' },
            @{ source = '2024-13-01 - Month.mp3'; expected = '2031-03-04 - 2024-13-01 - Month' },
            @{ source = '0000-01-01 - Year.mp3'; expected = '2031-03-04 - 0000-01-01 - Year' },
            @{ source = 'No date.mp3'; expected = '2031-03-04 - No date' })
        foreach ($culture in @('en-US', 'fi-FI', 'de-DE', 'ar-SA')) {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
            [Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
            foreach ($date in $dates) {
                $plan = Assert-Name $date.source $date.expected
                if ($date.source -match '^(1900|2023|2024-13|0000)') { Assert-True (@($plan.Warnings).Count -gt 0) 'Impossible date fallback must carry a warning.' }
            }
        }
        [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture; [Threading.Thread]::CurrentThread.CurrentUICulture = $originalUiCulture
        $case['calendar_rows'] = $dates.Count; $case['cultures'] = @('en-US', 'fi-FI', 'de-DE', 'ar-SA')
    }
    Invoke-Case 'NFC scalar whitelist whitespace punctuation and empty title' 'A19' {
        param($case)
        Assert-Name ('sub [literal]\2024-01-02 - ' + $composed + '.mp3') ('2024-01-02 - ' + $composed) | Out-Null
        $nfc = Assert-Name ('2024-01-02 - ' + $decomposed + '.mp3') ('2024-01-02 - ' + $composed)
        Assert-True (@($nfc.Warnings).Count -gt 0) 'NFC change must carry a warning.'
        $letters = [string][char]0xC4 + [char]0xE4 + ' ' + [char]0xD6 + [char]0xF6 + ' ' + [char]0xDC + [char]0xFC + ' ' + [char]0xDF + ' ' + [char]0xC5 + [char]0xE5
        Assert-Name ('2024-01-02 - ' + $letters + '.mp3') ('2024-01-02 - ' + $letters) | Out-Null
        $removed = Assert-Name '2024-01-02 - O''Brien & [x] "Q".mp3' '2024-01-02 - OBrien x Q'
        Assert-True (@($removed.Warnings).Count -gt 0) 'Removed punctuation must carry a warning.'
        Assert-Name ("2024-01-02 -  a`t b" + [char]0xA0 + 'c  .mp3') '2024-01-02 - a b c' | Out-Null
        Assert-Name ('2024-01-02 - ' + $supplementaryLetter + $supplementaryDigit + $emoji + '.mp3') ('2024-01-02 - ' + $supplementaryLetter + $supplementaryDigit) | Out-Null
        Assert-Name ('2024-01-02 - x' + [char]0x301 + '.mp3') '2024-01-02 - x' | Out-Null
        Assert-Name ('2024-01-02 - ' + $hangulSeparated + '.mp3') ('2024-01-02 - ' + $hangulComposed) | Out-Null
        Assert-Name ('2024-01-02 - !!!' + $emoji + '.mp3') '2024-01-02 - Episode' | Out-Null
        Assert-Throws { Get-AudioNamePlan -SourceRelativePath ('Bad' + [string][char]0xD800 + '.mp3') -LastWriteTime $fallback -MaxBaseLength 60 } 'Unicode|surrogate|invalid|normal'
        Assert-Throws { Get-AudioNamePlan -SourceRelativePath ('Bad' + [string][char]0xDC00 + '.mp3') -LastWriteTime $fallback -MaxBaseLength 60 } 'Unicode|surrogate|invalid|normal'
        $case['supplementary_letters_and_decimal_digits_preserved'] = $true; $case['remaining_noncomposing_marks_removed'] = $true
    }
    Invoke-Case 'complete UTF-16 budgets scalar-safe truncation and counter growth' 'A21' {
        param($case)
        foreach ($length in @(24, 60, 180)) {
            foreach ($counter in @(1, 2, 9, 10, 99, 100, 9999, 10000)) {
                $suffix = if ($counter -eq 1) { '' } else { ' (' + $counter + ')' }
                $expected = '2024-01-02 - ' + ('x' * ($length - 13 - $suffix.Length)) + $suffix
                $plan = Assert-Name ('2024-01-02 - ' + ('x' * 220) + '.mp3') $expected $length $counter
                Assert-True ($plan.BaseName.Length -eq $length -and @($plan.Warnings).Count -gt 0) 'Clipped basename must fill the exact requested UTF-16 budget and warn.'
            }
        }
        Assert-Name ('2024-01-02 - abcdefghij' + $supplementaryLetter + '.mp3') '2024-01-02 - abcdefghij' 24 | Out-Null
        Assert-Name ('2024-01-02 - abcdefghi' + $supplementaryLetter + '.mp3') ('2024-01-02 - abcdefghi' + $supplementaryLetter) 24 | Out-Null
        Assert-Throws { Get-AudioNamePlan -SourceRelativePath '2024-01-02 - title.mp3' -LastWriteTime $fallback -MaxBaseLength 23 } '24|length|limit'
        Assert-Throws { Get-AudioNamePlan -SourceRelativePath '2024-01-02 - title.mp3' -LastWriteTime $fallback -MaxBaseLength 181 } '180|length|limit'
        foreach ($counter in @(0, -1, 1000000000)) { Assert-Throws { Get-AudioNamePlan -SourceRelativePath '2024-01-02 - title.mp3' -LastWriteTime $fallback -MaxBaseLength 24 -Counter $counter } 'counter|suffix|title|budget|length' }
        Assert-Throws { Get-AudioNamePlan -SourceRelativePath ('2024-01-02 - ' + $supplementaryLetter + '.mp3') -LastWriteTime $fallback -MaxBaseLength 24 -Counter 1000000 } 'title|scalar|budget|length|suffix'
        $case['lengths'] = @(24, 60, 180); $case['counters'] = @(1, 2, 9, 10, 99, 100, 9999, 10000); $case['exhaustion_rejected'] = $true
    }
    Invoke-Case 'permuted case extension NFC collisions give identical pure mappings' 'A20' {
        param($case)
        $pureInput = Join-Path $testRoot 'Pure input'; $pureOutput = Join-Path $testRoot 'Pure output'
        $names = @('a\2024-01-02 - Episode.mp3', 'a\2024-01-02 - Episode.m4a', 'a\2024-01-02 - Episode.ogg',
            'a\2024-01-02 - EPISODE.MP3', 'a\2024-01-02 - episode.mp3',
            ('a\2024-01-02 - ' + $composed + '.mp3'), ('a\2024-01-02 - ' + $decomposed + '.m4a'),
            'a\2024-01-02 - A&B.mp3', 'a\2024-01-02 - AB.ogg', 'b\2024-01-02 - Episode.mp3',
            ('a\2024-01-02 - ' + $hangulComposed + '.mp3'), ('a\2024-01-02 - ' + $hangulSeparated + '.ogg'))
        $files = @($names | ForEach-Object { [pscustomobject]@{ FullName = Join-Path $pureInput $_; LastWriteTime = $fallback } })
        $first = @(Get-AudioBatchNamePlan -Files $files -InputFolder $pureInput -OutputRoot $pureOutput -MaxBaseLength 24)
        $reverse = [object[]]$files.Clone(); [Array]::Reverse($reverse)
        $rotated = @($files[4..($files.Count - 1)]) + @($files[0..3])
        foreach ($permutation in @(@{ value = $reverse }, @{ value = $rotated })) {
            $again = @(Get-AudioBatchNamePlan -Files $permutation.value -InputFolder $pureInput -OutputRoot $pureOutput -MaxBaseLength 24)
            Assert-True ((Get-PlanMapping $first) -ceq (Get-PlanMapping $again)) 'Inventory permutations must produce byte-identical source-to-output mapping.'
        }
        $ordered = [string[]]@($files.FullName); [Array]::Sort($ordered, [StringComparer]::Ordinal)
        # Verify pair ordering directly, including case-insensitive ties.
        for ($index = 1; $index -lt $first.Count; $index++) {
            $previous = $first[$index - 1].SourcePath; $current = $first[$index].SourcePath
            $comparison = [StringComparer]::OrdinalIgnoreCase.Compare($previous, $current)
            Assert-True ($comparison -lt 0 -or ($comparison -eq 0 -and [StringComparer]::Ordinal.Compare($previous, $current) -lt 0)) 'Batch records must use OrdinalIgnoreCase source order with Ordinal tie-break.'
        }
        $allocated = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($record in $first) {
            Assert-True ($allocated.Add($record.OutputRelativePath)) 'Allocated full relative Windows paths must be unique.'
            $working = Join-Path $record.OutputDirectory ('.AudioFileForPhone-' + ('0' * 32) + '.partial')
            Assert-True ($record.WorkingPathTemplate -ceq $working) 'Every record must budget the specified fixed future working-path template.'
            Assert-True ($record.OutputPath -ceq (Join-Path $pureOutput $record.OutputRelativePath)) 'Absolute planned path must equal root plus complete relative mapping.'
        }
        Assert-True (@($first | Where-Object { $_.BaseName -match 'Episode \(5\)$' }).Count -eq 1) 'Five case/extension collisions must grow through (5) deterministically.'
        Assert-True (@($first | Where-Object { $_.SourceRelativePath -like 'b\*' -and $_.BaseName -eq '2024-01-02 - Episode' }).Count -eq 1) 'Identical basenames in distinct directories must allocate independently.'
        Assert-True (@($first | Where-Object { $_.BaseName -ceq ('2024-01-02 - ' + $hangulComposed + ' (2)') }).Count -eq 1) 'Punctuation removal joining Hangul Jamo must compose before collision allocation.'
        Assert-True (-not (Test-Path -LiteralPath $pureInput) -and -not (Test-Path -LiteralPath $pureOutput)) 'Pure planning must not inspect or create nonexistent source/destination directories.'
        Assert-Throws { Get-AudioBatchNamePlan -Files @([pscustomobject]@{ FullName = $pureInput + '2\foreign.mp3'; LastWriteTime = $fallback }) -InputFolder $pureInput -OutputRoot $pureOutput -MaxBaseLength 60 } 'input|within|outside|contain|relative'
        $case['inventories'] = 3; $case['sources'] = $files.Count; $case['pure_no_io'] = $true
        $case['mapping'] = @($first | ForEach-Object { [pscustomobject]@{ source = $_.SourceRelativePath; output = $_.OutputRelativePath } })
    }
    Invoke-Case 'canonical duplicate sources reject and failed batches emit no partial plans' 'A20,A21' {
        param($case)
        $pureInput = Join-Path $testRoot 'Pure input'; $pureOutput = Join-Path $testRoot 'Pure output'
        $source = Join-Path $pureInput 'a\2024-01-02 - title.mp3'
        $valid = [pscustomobject]@{ FullName = $source; LastWriteTime = $fallback }
        foreach ($alias in @($source, $source.Replace('\', '/'))) {
            Assert-Throws { Get-AudioBatchNamePlan -Files @($valid, [pscustomobject]@{ FullName = $alias; LastWriteTime = $fallback }) -InputFolder $pureInput -OutputRoot $pureOutput -MaxBaseLength 60 } 'duplicate|canonical|same source'
        }
        $emitted = New-Object 'System.Collections.Generic.List[object]'
        $caught = $null
        try {
            Get-AudioBatchNamePlan -Files @($valid, [pscustomobject]@{ FullName = (Join-Path $pureInput (('z' * 205) + '\late.mp3')); LastWriteTime = $fallback }) -InputFolder $pureInput -OutputRoot $pureOutput -MaxBaseLength 60 |
                ForEach-Object { $emitted.Add($_) }
        }
        catch { $caught = $_.Exception.Message }
        Assert-True ($null -ne $caught -and $emitted.Count -eq 0) 'A failure after an earlier valid source must emit zero partial plan records.'
        $case['duplicate_aliases'] = 2; $case['partial_records_on_late_failure'] = $emitted.Count
    }
    Invoke-Case 'preserved components reject invalid controls endings and DOS devices' 'A21' {
        param($case)
        foreach ($component in @('bad.', 'bad ', 'bad:name', 'bad?name', 'bad*name', 'bad|name', 'bad<name', ('bad' + [char]1 + 'name'),
            'CON', 'PRN', 'AUX', 'NUL', 'con.txt', 'COM1', 'COM9', 'LPT1', 'LPT9',
            ('COM' + [char]0xB9), ('LPT' + [char]0xB2), ('LPT' + [char]0xB3))) {
            Assert-Throws { Assert-AudioPathBudget -Path ('C:\safe\' + $component + '\title.mp3') -Kind File } 'component|folder|directory|invalid|reserved|device|trailing|unsupported'
        }
        Assert-AudioPathBudget -Path ('C:\' + ('x' * 255)) -Kind File
        Assert-Throws { Assert-AudioPathBudget -Path ('C:\' + ('x' * 256)) -Kind File } 'component|255|length|limit'
        foreach ($component in @('bad.', 'bad ', 'CON', ('COM' + [char]0xB9))) {
            $file = [pscustomobject]@{ FullName = (Join-Path $inputRoot ($component + '\2024-01-02 - title.mp3')); LastWriteTime = $fallback }
            Assert-Throws { Get-AudioBatchNamePlan -Files @($file) -InputFolder $inputRoot -OutputRoot (Join-Path $testRoot 'Unused') -MaxBaseLength 60 } 'component|folder|directory|invalid|reserved|device|trailing|unsupported'
        }
        $case['component_rejections'] = 20; $case['raw_preserved_paths_checked_before_normalization'] = $true
    }
    Invoke-Case 'actual Windows directory247248 and file259260 budget boundaries' 'A21' {
        param($case)
        foreach ($path in $boundaryDirectories) { Assert-NativeExists $path $true }
        foreach ($path in $boundaryFiles) { Assert-NativeExists $path $false }
        Assert-AudioPathBudget -Path $boundaryDirectories[0] -Kind Directory
        Assert-Throws { Assert-AudioPathBudget -Path $boundaryDirectories[1] -Kind Directory } '248|247|length|limit|budget'
        Assert-AudioPathBudget -Path $boundaryFiles[0] -Kind File
        Assert-Throws { Assert-AudioPathBudget -Path $boundaryFiles[1] -Kind File } '260|259|length|limit|budget'
        $case['actual_directory_lengths'] = @(247, 248); $case['actual_file_lengths'] = @(259, 260)
        $case['accepted_directory_length'] = 247; $case['accepted_file_length'] = 259
        $case['owned_extended_creation_only'] = $true
    }
    Invoke-Case 'working placeholder budget rejects even when final filename fits' 'A21' {
        param($case)
        $pureInput = Join-Path $testRoot 'Q'
        $output = 'C:\' + ('o' * 188)
        $file = [pscustomobject]@{ FullName = Join-Path $pureInput 'x.mp3'; LastWriteTime = $fallback }
        $directory = Join-Path $output 'Q'
        $working = Join-Path $directory ('.AudioFileForPhone-' + ('0' * 32) + '.partial')
        $final = Join-Path $directory '2031-03-04 - x.mp3'
        # Choose a precise pure root length so the working placeholder reaches
        # 260 while the ordinary short final name remains within its budget.
        $output = 'C:\' + ('o' * (260 - 3 - 1 - 1 - 1 - ('.AudioFileForPhone-'.Length + 32 + '.partial'.Length)))
        $directory = Join-Path $output 'Q'; $working = Join-Path $directory ('.AudioFileForPhone-' + ('0' * 32) + '.partial')
        $final = Join-Path $directory '2031-03-04 - x.mp3'
        Assert-True ($working.Length -eq 260 -and $final.Length -lt 260 -and $directory.Length -lt 248) 'Working-path rejection fixture must isolate the temporary-name budget.'
        Assert-Throws { Get-AudioBatchNamePlan -Files @($file) -InputFolder $pureInput -OutputRoot $output -MaxBaseLength 60 } 'working|260|path|budget|length'
        $case['working_length'] = $working.Length; $case['final_length'] = $final.Length
    }
    Invoke-Case 'long or trailing-dot-space trees abort before prompts and output' 'A21' {
        param($case)
        foreach ($selection in @(@{ input = $longInput; label = 'long-tree' }, @{ input = $badInput; label = 'bad-components' })) {
            $result = Invoke-Application $selection.input $abortOutput $selection.label -Interactive
            Assert-AbortBeforeRun $result $abortOutput 'path|component|directory|folder|length|limit|read|enumerat'
        }
        foreach ($path in $nativeDirectories | Where-Object { $_.StartsWith($badInput + '\', [StringComparison]::OrdinalIgnoreCase) }) { Assert-NativeExists $path $true }
        $case['actual_trailing_dot_and_space_source_folders_retained'] = $true; $case['prompt_conversion_and_run_absent'] = $true
    }
    Invoke-Case 'real literal Unicode dates 12 collisions and allocated title metadata' 'A18,A19,A20' {
        param($case)
        $run = Verify-RealRun $inputRoot $outputParent 'real-collisions' 60
        Assert-True ($run.count -eq 18) 'Real fixture must convert all twelve collision files plus date/Unicode/metadata/literal-folder fixtures.'
        $collisionPlan = @($run.plan | Where-Object { $_.BaseName -match '^2024-01-02 - Episode( \(\d+\))?$' })
        Assert-True ($collisionPlan.Count -eq 12 -and @($collisionPlan | Where-Object { $_.BaseName -ceq '2024-01-02 - Episode (12)' }).Count -eq 1) 'Actual collision allocation must grow beyond (9) through (12).'
        Assert-True (@($run.plan | Where-Object { $_.BaseName -ceq '2031-03-04 - 2023-02-29 - Impossible' }).Count -eq 1) 'Actual impossible date must retain the original prefix as fallback title.'
        foreach ($directory in @((Split-Path -Leaf $literalDirectory), (Split-Path -Leaf $neighborDirectory))) {
            Assert-True (Test-Path -LiteralPath (Join-Path $run.root ('I\' + $directory + '\2024-01-02 - Literal x.mp3')) -PathType Leaf) 'Literal bracketed/apostrophe prefix-neighbor directories must stay distinct and preserved.'
        }
        $case['actual_files'] = $run.count; $case['actual_collision_counter'] = 12; $case['full_decode_metadata_and_default_bitrate'] = $true
    }
    Invoke-Case 'actual180 UTF-16 basename fits short owned TEMP destination' 'A21' {
        param($case)
        $run = Verify-RealRun $longNameInput $longNameOutput 'real-180' 180
        Assert-True ($run.count -eq 1 -and $run.plan[0].BaseName.Length -eq 180) 'Actual maximal basename must contain precisely 180 UTF-16 units, excluding .mp3.'
        $case['actual_basename_length'] = 180; $case['actual_output_path_length'] = $run.max_path_length; $case['full_decode_metadata_and_default_bitrate'] = $true
    }
    $report.status = 'pass'; $exitCode = 0
}
catch {
    $report.error = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>'); Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture; [Threading.Thread]::CurrentThread.CurrentUICulture = $originalUiCulture
    foreach ($inventory in @('source', 'synthetic')) {
        try {
            $after = if ($inventory -eq 'source') { Get-SourceInventory } else { Get-FixtureInventory }
            $report[$inventory + '_after'] = $after
            $same = (($report[$inventory + '_before'] | ConvertTo-Json -Compress) -ceq ($after | ConvertTo-Json -Compress))
            $report[$inventory + '_unchanged'] = $same; Assert-True $same "$inventory SHA-256 inventory must remain unchanged."
        }
        catch { $report.status = 'fail'; $exitCode = 1; $report[$inventory + '_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>') }
    }
    try {
        if ($ownedRootCreated -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay inside the exact exclusively reserved TEMP root.'
            Assert-NoReparse $resolved
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact create-new owner marker token.'
            foreach ($path in $nativeFiles) {
                Assert-True ($path.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Only registered native fixtures inside this owned root may be removed.'
                Assert-NativeExists $path $false
                Assert-True ([AudioFileForPhoneT07.NativeFixture]::DeleteFileW([AudioFileForPhoneT07.NativeFixture]::Extended($path))) 'Owned native file fixture removal must succeed.'
            }
            foreach ($path in @($nativeDirectories | Sort-Object Length -Descending)) {
                Assert-True ($path.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Only registered native directories inside this owned root may be removed.'
                Assert-NativeExists $path $true
                Assert-True ([AudioFileForPhoneT07.NativeFixture]::RemoveDirectoryW([AudioFileForPhoneT07.NativeFixture]::Extended($path))) 'Owned native directory removal must succeed without recursion.'
            }
            $report.native_fixture_cleanup = $true
            Get-SafeTree $resolved | Out-Null
            # PS5.1's provider Force cleanup can demand ACL operations denied
            # by machine TEMP although the owner has deletion rights. After
            # exact ownership/path/reparse checks, .NET deletes this owned tree.
            [IO.Directory]::Delete($resolved, $true)
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Complete owned TEMP cleanup must be verified.'
    }
    catch {
        $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
        $report['cleanup_error_location'] = $_.ScriptStackTrace.Replace($testRoot, '<OWNED_TEMP>')
    }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    $bytes = [Text.Encoding]::UTF8.GetBytes(($report | ConvertTo-Json -Depth 14))
    $stream = New-Object IO.FileStream($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
Write-Host "T07 naming: $($report.status); cases=$($report.cases.Count); native/owned cleanup=$($report.native_fixture_cleanup)/$($report.cleanup_verified); source/synthetic unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
