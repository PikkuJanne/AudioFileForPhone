<#
T04 focused preflight evidence. All fixtures, application copies and raw child
diagnostics are confined to one exclusively reserved, marked TEMP directory.
ACL denials apply only to new fixture directories and are restored in finally.
No application conversion or interactive prompt should begin in negative cases.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$application = Join-Path $projectRoot 'AudioFileForPhone.ps1'
$helpers = Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T04-preflight-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t04-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false
$originalPath = $env:PATH
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shell = Join-Path $PSHOME $shellName
$savedAcls = New-Object 'System.Collections.Generic.List[object]'
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Preflight.ps1')
$exitCode = 1

$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T04|T05|T06|T07|T08)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T04/T05/T06/T07/T08-<label>.json directly in docs/codex-v1/evidence.'
}
$evidenceTask = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3)
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $evidenceTask; mode = 'preflight_negative_and_helper'
    command = [Environment]::CommandLine
    started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString()
    windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    copied_bytes_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false
    cases = @(); helper_cases = @(); permissions = @()
    acls_restored = $false; cleanup_verified = $false
    status = 'fail'; error = $null
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
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

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Refusing a reparse point in the test path or its ancestors.'
        }
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
    if (-not ('AudioFileForPhoneT04.NativeDirectory' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhoneT04 {
    public static class NativeDirectory {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr securityAttributes);
    }
}
'@
    }
    if (-not [AudioFileForPhoneT04.NativeDirectory]::CreateDirectoryW($Path, [IntPtr]::Zero)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "Exclusive test directory reservation failed (Win32 $code); existing directories are never claimed."
    }
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-ChildCode {
    param([string]$Code, [string]$Label, [string]$ChildPath = $ordinaryPath)
    # EncodedCommand preserves empty, whitespace and embedded-quote arguments
    # identically on PS5.1 and PS7; no shell evaluates user-controlled strings.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Code))
    $oldPath = $env:PATH
    $oldPreference = $ErrorActionPreference
    try {
        $env:PATH = $ChildPath
        $ErrorActionPreference = 'Continue'
        $output = @(& $shell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -EncodedCommand $encoded 2>&1 6>&1)
        $codeResult = $LASTEXITCODE
    }
    finally { $env:PATH = $oldPath; $ErrorActionPreference = $oldPreference }
    $text = ($output | ForEach-Object { "$_" }) -join "`n"
    [IO.File]::WriteAllText((Join-Path $testRoot ($Label + '.log')), $text)
    return [pscustomobject]@{ exit_code = $codeResult; text = $text; command_text = $Code.Replace($testRoot, '<OWNED_TEMP>') }
}

function Invoke-NegativeCase {
    param([string]$Name, [hashtable]$Overrides, [string]$Expected,
        [string]$ChildPath = $ordinaryPath, [string]$RootSpelling)
    $entry = [ordered]@{ name = $Name; status = 'fail'; exit_code = $null }
    $arguments = @{ InputFolder = $inputRoot; OutputParent = $outputRoot; Interactive = $true }
    foreach ($key in $Overrides.Keys) {
        if ($null -eq $Overrides[$key]) { $arguments.Remove($key) }
        else { $arguments[$key] = $Overrides[$key] }
    }
    $parts = @('$ErrorActionPreference = ''Stop''', '$arguments = @{')
    foreach ($key in @($arguments.Keys | Sort-Object)) {
        $value = if ($arguments[$key] -is [bool]) { '$true' } else { ConvertTo-PowerShellLiteral ([string]$arguments[$key]) }
        $parts += "    $key = $value"
    }
    $parts += @('}', '$global:LASTEXITCODE = $null', 'try {',
        ('    & ' + (ConvertTo-PowerShellLiteral $scriptCopy) + ' @arguments *>&1 | ForEach-Object {'),
        '        if ($_ -is [Management.Automation.ErrorRecord]) { [Console]::Out.WriteLine($_.Exception.Message) }',
        '        else { [Console]::Out.WriteLine([string]$_) }',
        '    }',
        '    if ($null -eq $global:LASTEXITCODE) { throw ''Application did not return a native script exit status.'' }',
        '    exit $global:LASTEXITCODE',
        '} catch {',
        '    [Console]::Out.WriteLine($_.Exception.Message)',
        '    exit 1',
        '}')
    try {
        $result = Invoke-ChildCode ($parts -join "`n") $Name $ChildPath
        $entry.exit_code = $result.exit_code
        $entry['command_text'] = $result.command_text
        $entry['host_options'] = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-EncodedCommand')
        $entry['expected_diagnostic_pattern'] = $Expected
        Assert-True ($result.exit_code -ne 0) "$Name must return a nonzero child-process status."
        # The child emits ErrorRecord.Exception.Message directly so PS5.1's
        # console formatter cannot wrap inside a diagnostic word. The wrapper
        # preserves application exit status and explicitly exits 1 on binding
        # errors. Diagnostics use stdout to avoid mixing raw text with PS5.1
        # EncodedCommand's CLIXML stderr. Raw logs stay in the owned TEMP tree.
        $diagnostic = $result.text -replace '\s+', ' '
        $fatalIndex = $diagnostic.IndexOf('[FATAL]')
        $excerpt = if ($fatalIndex -ge 0) { $diagnostic.Substring($fatalIndex) } else { $diagnostic }
        $excerpt = $excerpt.Replace($testRoot, '<OWNED_TEMP>').Replace($projectRoot, '<PROJECT>')
        $entry['diagnostic_excerpt'] = $excerpt.Substring(0, [Math]::Min(1200, $excerpt.Length))
        Assert-True ($diagnostic -match $Expected) "$Name must report its expected diagnostic ($Expected)."
        # A path-budget rejection can quote the planned run path. Filesystem
        # emptiness below proves that this diagnostic did not create that run.
        Assert-True ($result.text -notmatch 'Optional metadata step|Processing file|\[INFO\] Output root') "$Name must stop before optional metadata prompts and run output."
        if ($RootSpelling) {
            $rootDiagnostic = @($diagnostic -split '\[FATAL\] Preflight failed: ', 2)
            Assert-True ($rootDiagnostic.Count -eq 2 -and
                $rootDiagnostic[1].Contains("'" + $RootSpelling + "'")) "$Name must preserve the full quoted root spelling in the rejection diagnostic."
            $entry['root_spelling_preserved'] = $true
        }
        $items = @(Get-SafeTree $outputRoot)
        Assert-True ($items.Count -eq 0) "$Name must not create any output root, log or probe residue."
        $entry['prompt_and_conversion_absent'] = $true
        $entry['output_parent_empty'] = $true
        $entry.status = 'pass'
    }
    finally { $report.cases += [pscustomobject]$entry }
}

function Set-FixtureDeny {
    param([string]$Path, [Security.AccessControl.FileSystemRights]$Rights)
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    Assert-True ($resolved.StartsWith($testRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'ACL fixture must stay below this owned TEMP root.'
    Assert-NoReparse $resolved
    $original = Get-Acl -LiteralPath $resolved
    $savedAcls.Add([pscustomobject]@{ path = $resolved; acl = $original; sddl = $original.Sddl; restored = $false })
    $changed = Get-Acl -LiteralPath $resolved
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity, $Rights,
        [Security.AccessControl.InheritanceFlags]::None,
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Deny)
    $changed.AddAccessRule($rule)
    Set-Acl -LiteralPath $resolved -AclObject $changed
}

try {
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    Assert-NoReparse $tempParent
    $report.source_before = Get-SourceInventory
    New-ExclusiveDirectory $testRoot
    $ownedRootCreated = $true
    $report.temp_exclusively_reserved = $true
    $bytes = [Text.Encoding]::UTF8.GetBytes($ownerToken)
    $marker = New-Object IO.FileStream($ownerFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $marker.Write($bytes, 0, $bytes.Length) } finally { $marker.Dispose() }
    $report.marker_create_new = $true
    $appRoot = Join-Path $testRoot 'App'
    $inputRoot = Join-Path $testRoot 'Input [literal]'
    $outputRoot = Join-Path $testRoot 'Output [literal]'
    $emptyTools = Join-Path $testRoot 'No tools'
    $onlyFfmpeg = Join-Path $testRoot 'Only ffmpeg'
    foreach ($directory in @($appRoot, $inputRoot, $outputRoot, $emptyTools, $onlyFfmpeg)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $scriptCopy = Join-Path $appRoot 'AudioFileForPhone.ps1'
    $helpersCopy = Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'
    foreach ($pair in @(@{ source = $application; copy = $scriptCopy }, @{ source = $helpers; copy = $helpersCopy })) {
        Copy-Item -LiteralPath $pair.source -Destination $pair.copy
        Assert-True ((Get-FileHash -LiteralPath $pair.source).Hash -ceq (Get-FileHash -LiteralPath $pair.copy).Hash) 'Every application/helper copy must preserve source bytes.'
        $tokens = $null; $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseFile($pair.copy, [ref]$tokens, [ref]$parseErrors) | Out-Null
        Assert-True ($parseErrors.Count -eq 0) 'Application/helper copies must parse before children run.'
    }
    $report.copied_bytes_unchanged = $true
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath
    $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($selection in @(@{ name = 'ffmpeg'; path = $ffmpeg }, @{ name = 'ffprobe'; path = $ffprobe })) {
        Assert-True ([IO.Path]::GetFileName($selection.path) -ieq ($selection.name + '.exe')) 'Selected dependencies must be local named native executables.'
        $version = @(& $selection.path -version)
        Assert-True ($LASTEXITCODE -eq 0) 'Installed tool version command must succeed.'
        $report[$selection.name] = [ordered]@{ path = $selection.path; version = "$($version[0])"; sha256 = (Get-FileHash -LiteralPath $selection.path -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $ordinaryPath = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
    $audio = Join-Path $inputRoot '2024-01-02 - Synthetic.mp3'
    & $ffmpeg -hide_banner -loglevel error -nostdin -f lavfi -i 'sine=frequency=440:sample_rate=44100:duration=0.2' -c:a libmp3lame $audio
    Assert-True ($LASTEXITCODE -eq 0) 'Short synthetic audio creation must succeed.'
    $fixtures.Add($audio)
    $regularFile = Join-Path $testRoot 'Existing file [literal].txt'
    $wrongCover = Join-Path $testRoot 'Wrong cover.txt'
    $corruptCover = Join-Path $testRoot 'Corrupt cover.jpg'
    foreach ($file in @($regularFile, $wrongCover, $corruptCover)) {
        [IO.File]::WriteAllText($file, 'T04 synthetic non-media fixture.')
        $fixtures.Add($file)
    }
    $validJpeg = Join-Path $testRoot 'Valid cover.jpg'
    $validPng = Join-Path $testRoot 'Valid cover.png'
    Add-Type -AssemblyName System.Drawing
    $bitmap = New-Object Drawing.Bitmap(32, 32)
    try {
        $bitmap.Save($validJpeg, [Drawing.Imaging.ImageFormat]::Jpeg)
        $bitmap.Save($validPng, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    $fixtures.Add($validJpeg)
    $fixtures.Add($validPng)
    $report.synthetic_before = Get-FixtureInventory

    Invoke-NegativeCase 'input-missing' @{ InputFolder = (Join-Path $testRoot 'Missing input') } 'input.*(directory|folder)|resolve input'
    Invoke-NegativeCase 'input-file' @{ InputFolder = $regularFile } 'input.*(directory|folder)'
    foreach ($providerPath in @('Env:\TEMP', 'Registry::HKEY_CURRENT_USER\Software', 'Variable:\PSVersionTable')) {
        Invoke-NegativeCase ('input-provider-' + ($providerPath -split ':')[0]) @{ InputFolder = $providerPath } 'filesystem.*directory|directory.*filesystem'
    }
    Invoke-NegativeCase 'input-embedded-quote' @{ InputFolder = ($inputRoot + '\Bad"path') } 'invalid|malformed|input.*(directory|folder)|resolve input'
    Invoke-NegativeCase 'input-whitespace' @{ InputFolder = '   ' } 'input.*(directory|folder)|empty|whitespace'
    Invoke-NegativeCase 'input-omitted-binding' @{ InputFolder = $null } 'InputFolder|mandatory|NonInteractive'
    Invoke-NegativeCase 'input-drive-root' @{ InputFolder = 'C:\' } 'root' $ordinaryPath 'C:\'
    Invoke-NegativeCase 'input-unc-root-slash' @{ InputFolder = '\\synthetic.invalid\share\' } 'root' $ordinaryPath '\\synthetic.invalid\share\'
    Invoke-NegativeCase 'input-unc-root-no-slash' @{ InputFolder = '\\synthetic.invalid\share' } 'root' $ordinaryPath '\\synthetic.invalid\share'
    foreach ($bitrate in @(0, -1, 7, 65, 145, 321)) {
        Invoke-NegativeCase ('bitrate-' + $bitrate) @{ BitrateKbps = $bitrate } 'BitrateKbps|bitrate'
    }
    foreach ($length in @(23, 181)) {
        Invoke-NegativeCase ('max-base-' + $length) @{ MaxBaseLength = $length } 'MaxBaseLength|base.*length'
    }
    Invoke-NegativeCase 'bitrate-binding' @{ BitrateKbps = 'not-an-integer' } 'BitrateKbps|Int32|convert'
    Invoke-NegativeCase 'max-base-binding' @{ MaxBaseLength = 'not-an-integer' } 'MaxBaseLength|Int32|convert'
    Invoke-NegativeCase 'output-existing-file' @{ OutputParent = $regularFile } 'existing file|output.*directory|output.*parent'
    Invoke-NegativeCase 'output-provider' @{ OutputParent = 'Env:\TEMP' } 'filesystem.*directory|directory.*filesystem'
    Invoke-NegativeCase 'output-invalid' @{ OutputParent = ($outputRoot + '\Bad"path') } 'invalid|malformed|Illegal characters in path|output.*(directory|parent)'
    Invoke-NegativeCase 'output-file-ancestor' @{ OutputParent = ($regularFile + '\nested child') } 'file|output.*(directory|parent)'
    Invoke-NegativeCase 'cover-missing' @{ CoverPath = (Join-Path $testRoot 'Missing cover.jpg') } 'cover'
    Invoke-NegativeCase 'cover-directory' @{ CoverPath = $inputRoot } 'cover'
    Invoke-NegativeCase 'cover-wrong-extension' @{ CoverPath = $wrongCover } 'cover|JPEG|PNG'
    Invoke-NegativeCase 'cover-corrupt-jpeg' @{ CoverPath = $corruptCover } 'cover|JPEG|decode|image'
    Invoke-NegativeCase 'tool-missing-ffmpeg' @{} 'ffmpeg' $emptyTools
    Copy-Item -LiteralPath $ffmpeg -Destination (Join-Path $onlyFfmpeg 'ffmpeg.exe')
    Invoke-NegativeCase 'tool-missing-ffprobe' @{} 'ffprobe' $onlyFfmpeg
    $invalidTool = Join-Path $appRoot 'ffmpeg.exe'
    [IO.File]::WriteAllText($invalidTool, 'T04 invalid native executable.')
    try { Invoke-NegativeCase 'tool-invalid-local-executable' @{} 'ffmpeg|executable|version' }
    finally { Remove-Item -LiteralPath $invalidTool -Force }
    $versionFailureTool = Join-Path $env:WINDIR 'System32\whoami.exe'
    Copy-Item -LiteralPath $versionFailureTool -Destination $invalidTool
    try {
        $report['tool_version_failure_fixture'] = [ordered]@{
            source = '%WINDIR%\System32\whoami.exe'
            sha256 = (Get-FileHash -LiteralPath $invalidTool -Algorithm SHA256).Hash.ToLowerInvariant()
            purpose = 'Trusted local native executable with a failing ffmpeg -version response'
        }
        Invoke-NegativeCase 'tool-version-failure' @{} 'Invalid ffmpeg executable|version'
    }
    finally { Remove-Item -LiteralPath $invalidTool -Force }

    $helperBefore = @((Get-SafeTree $appRoot).FullName | Sort-Object)
    $helperTokens = $null; $helperErrors = $null
    $helperAst = [Management.Automation.Language.Parser]::ParseFile($helpersCopy, [ref]$helperTokens, [ref]$helperErrors)
    Assert-True ($helperErrors.Count -eq 0 -and $null -eq $helperAst.BeginBlock -and
        $null -eq $helperAst.ProcessBlock -and $null -eq $helperAst.ParamBlock) 'Helper import must have no script parameter binding or executable begin/process blocks.'
    foreach ($statement in $helperAst.EndBlock.Statements) {
        Assert-True ($statement -is [Management.Automation.Language.FunctionDefinitionAst]) 'Helper import may contain only function definitions.'
    }
    $helperCode = '$ErrorActionPreference = ''Stop''; . ' + (ConvertTo-PowerShellLiteral $helpersCopy) + '; Write-Output ''T04_HELPERS_IMPORTED'''
    $helperResult = Invoke-ChildCode $helperCode 'helpers-inert'
    Assert-True ($helperResult.exit_code -eq 0 -and $helperResult.text.Trim() -ceq 'T04_HELPERS_IMPORTED') 'Dot-sourcing the helper must only define functions, with no prompt or conversion output.'
    Assert-True (($helperBefore -join "`n") -ceq (@((Get-SafeTree $appRoot).FullName | Sort-Object) -join "`n")) 'Dot-sourcing must not create files beside the helper.'
    Assert-True (@(Get-SafeTree $outputRoot).Count -eq 0) 'Dot-sourcing must not create output.'
    $report.helper_cases += [pscustomobject]@{ name = 'dot-source-inert'; status = 'pass'; exit_code = $helperResult.exit_code; command_text = $helperResult.command_text }

    . $helpersCopy
    & {
        $LASTEXITCODE = 17
        Assert-ToolPrerequisites -FfmpegPath $ffmpeg -FfprobePath $ffprobe
    }
    $report.helper_cases += [pscustomobject]@{ name = 'tool-prerequisites-ignore-local-exit-shadow'; status = 'pass'; caller_local_exit = 17 }
    foreach ($cover in @($validJpeg, $validPng)) {
        $validated = & {
            param([string]$FixtureCover)
            $LASTEXITCODE = 17
            Get-ValidatedCoverPath -Path $FixtureCover -FfmpegPath $ffmpeg
        } $cover
        Assert-True ($validated -ceq $cover) 'Readable synthetic JPEG/PNG must validate even when the caller shadows native exit state.'
        $report.helper_cases += [pscustomobject]@{
            name = ('cover-validate-' + [IO.Path]::GetExtension($cover).TrimStart('.'))
            status = 'pass'; caller_local_exit = 17
        }
    }
    foreach ($boundaries in @(@{ bitrate = 8; length = 24 }, @{ bitrate = 64; length = 60 }, @{ bitrate = 320; length = 180 })) {
        Assert-AudioParameters -BitrateKbps $boundaries.bitrate -MaxBaseLength $boundaries.length
        $report.helper_cases += [pscustomobject]@{ name = ('numeric-boundaries-' + $boundaries.bitrate + '-' + $boundaries.length); status = 'pass' }
    }
    $missingPreviewParent = Join-Path $testRoot 'Preview nonexistent output\child'
    Test-OutputWritable -Path $missingPreviewParent -SkipWriteProbe | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Split-Path -Parent $missingPreviewParent))) 'SkipWriteProbe must defer all directory and sentinel writes.'
    $report.helper_cases += [pscustomobject]@{ name = 'skip-write-probe-no-creation'; status = 'pass'; public_preview = 'deferred to T12' }

    $unreadableInput = Join-Path $testRoot 'ACL unreadable input'
    $unwritableOutput = Join-Path $testRoot 'ACL unwritable output'
    foreach ($directory in @($unreadableInput, $unwritableOutput)) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    Copy-Item -LiteralPath $audio -Destination (Join-Path $unreadableInput 'Synthetic.mp3')
    $fixtures.Add((Join-Path $unreadableInput 'Synthetic.mp3'))
    # Add the new fixture before its directory becomes unreadable.
    $report.synthetic_before = Get-FixtureInventory
    Set-FixtureDeny $unreadableInput ([Security.AccessControl.FileSystemRights]::ListDirectory)
    $listDenied = $false
    try { Get-ChildItem -LiteralPath $unreadableInput -Force -ErrorAction Stop | Out-Null }
    catch [UnauthorizedAccessException] { $listDenied = $true }
    Assert-True $listDenied 'Input ACL denial must actually prevent directory enumeration on this host.'
    $report.permissions += [pscustomobject]@{ name = 'owned-input-list-denied'; status = 'pass'; effective_operation_denial = $true; rights = 'ListDirectory/ReadData'; scope = 'new owned TEMP fixture only' }
    Invoke-NegativeCase 'input-unreadable-acl' @{ InputFolder = $unreadableInput } 'read|access|enumerat|input.*(directory|folder)'
    Set-FixtureDeny $unwritableOutput ([Security.AccessControl.FileSystemRights]::WriteData)
    $writeDenied = $false
    $deniedProbe = Join-Path $unwritableOutput 'Denied create-new operation.tmp'
    try {
        $probe = New-Object IO.FileStream($deniedProbe, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $probe.Dispose()
    }
    catch [UnauthorizedAccessException] { $writeDenied = $true }
    Assert-True $writeDenied 'Output ACL denial must actually prevent file creation on this host.'
    Assert-True (-not (Test-Path -LiteralPath $deniedProbe)) 'Denied write operation must leave no file.'
    $report.permissions += [pscustomobject]@{ name = 'owned-output-create-denied'; status = 'pass'; effective_operation_denial = $true; rights = 'WriteData/CreateFiles'; scope = 'new owned TEMP fixture only' }
    Invoke-NegativeCase 'output-unwritable-acl' @{ OutputParent = $unwritableOutput } 'writ|access|output.*(directory|parent)'
    Assert-True (@(Get-ChildItem -LiteralPath $unwritableOutput -Force).Count -eq 0) 'Unwritable destination must contain no run root, log or probe residue.'
    $report.status = 'pass'
    $exitCode = 0
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
            Assert-True $saved.restored 'Original fixture ACL must be restored exactly before cleanup.'
        }
        catch {
            $aclRestoreSuccess = $false
            $report['acl_restore_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
        }
    }
    $report.acls_restored = $aclRestoreSuccess
    if (-not $aclRestoreSuccess) { $report.status = 'fail'; $exitCode = 1 }
    try {
        $report.source_after = Get-SourceInventory
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository application/helper/BAT/harness source bytes must remain unchanged.'
    }
    catch {
        $report.status = 'fail'; $exitCode = 1
        $report['source_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
    }
    try {
        $report.synthetic_after = Get-FixtureInventory
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True $report.synthetic_unchanged 'All synthetic source/cover fixtures must remain unchanged.'
    }
    catch {
        $report.status = 'fail'; $exitCode = 1
        $report['synthetic_verification_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
    }
    try {
        if ($ownedRootCreated -and $aclRestoreSuccess -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and
                (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay inside the exact exclusively owned TEMP root.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact create-new owner marker token.'
            Get-SafeTree $resolved | Out-Null
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Owned TEMP cleanup must be verified.'
    }
    catch {
        $report.status = 'fail'; $exitCode = 1
        $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot, '<OWNED_TEMP>')
    }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    $report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $evidenceFullPath -Encoding UTF8
}
Write-Host "$evidenceTask preflight: $($report.status); cases=$($report.cases.Count); ACL restored=$($report.acls_restored); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
