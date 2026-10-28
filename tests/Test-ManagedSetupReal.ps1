<#
S06 opt-in real-network Windows acceptance. Downloads the reviewed runtime pin
through the production setup API into one marker-owned TEMP scope, retains every
vendor file, then converts a tiny synthetic input in a fresh process using only
the remembered owned config. CI invokes this separately named explicit online
acceptance; dependency provisioning never supplies its setup result.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
if ($evidenceParent -ine (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -or
    $leaf -cnotmatch "^S06-managedreal-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$") {
    throw 'Use a fresh S06-managedreal-ps51/ps7-attempt/final report in the active evidence directory.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'S06R-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s06-real-owner'
$ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.ManagedSetup.ps1',
    'Setup-AudioFileForPhone.ps1', 'tools/ffmpeg-download.json', 'tests/Test-ManagedSetupReal.ps1')
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$report = [ordered]@{
    schema_version = 1; task = 'S06'; mode = 'real_windows_pinned_vendor_network'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; mocked_network = $false; network_installations_requested = 1
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; persistent_environment_writes = $false
    cleanup_verified = $false; descendant_release_proved = $false; native_runs = @(); tools = @(); cases = @()
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Assert-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function New-Directory {
    param([string]$Name)
    $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding($true)
        $preamble = $encoding.GetPreamble(); $stream.Write($preamble, 0, $preamble.Length)
        $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Add-Fixture { param([string]$Path); $fixtures.Add($Path); $report.synthetic_before += Get-Inventory @($Path) $testRoot }
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Invoke-TrackedNative {
    param([string]$ExecutablePath, [string[]]$Arguments, [int]$MaxStdoutChars = 1048576, [int]$MaxStderrChars = 65536,
        [object]$Cancellation = (Get-AudioCancellationContext), [scriptblock]$ProgressCallback, [object]$ProgressDurationSeconds,
        [object]$ProgressParser, [object]$ProgressCallbackState, [int]$TimeoutMilliseconds = 0,
        [string]$Operation = 'Native operation', [int]$PipeDrainTimeoutMilliseconds = 5000)
    try {
        $native = & $script:originalNative @PSBoundParameters
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) { $script:releaseProved = $false }
        $nativeRuns.Add([pscustomobject]@{ operation = $native.Operation; status = $native.Status; exit_code = $native.ExitCode; elapsed_ms = $native.ElapsedMilliseconds; timeout_ms = $native.TimeoutMilliseconds; process_released = $native.ProcessReleased; pipe_drain_completed = $native.PipeDrainCompleted })
        return $native
    } catch { $script:releaseProved = $false; throw }
}
function Assert-NativeComplete {
    param([object]$Result, [switch]$Success)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ProcessReleased -and $Result.PipeDrainCompleted -and -not $Result.StdoutTruncated -and -not $Result.StderrTruncated) ('Expected completed, drained, released native process: ' + $Result.Status + ' ' + $Result.Error)
    if ($Success) { Assert-True ($Result.ExitCode -eq 0) ('Native operation failed: ' + $Result.Stderr) }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
$guardLoader = @'
. $global:S06ExpectedHelper
$script:S06OriginalNative = (Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
        [object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,
        [object]$ProgressParser,[object]$ProgressCallbackState,[int]$TimeoutMilliseconds=0,
        [string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    $proof = [pscustomobject]@{operation=$Operation;status='not returned';process_released=$false;pipe_drain_completed=$false}
    $global:S06NativeProofs.Add($proof)
    $native = & $script:S06OriginalNative @PSBoundParameters
    $proof.status=$native.Status; $proof.process_released=[bool]$native.ProcessReleased; $proof.pipe_drain_completed=[bool]$native.PipeDrainCompleted
    return $native
}
function Invoke-AudioToolSetup { $global:S06Forbidden.Add('setup'); throw 'Fresh noninteractive conversion must never invoke setup.' }
function Save-AudioToolSelection { $global:S06Forbidden.Add('save'); throw 'Fresh conversion must not save settings.' }
function Invoke-AudioManagedToolInstall { $global:S06Forbidden.Add('managed install'); throw 'Fresh conversion must not install tools.' }
function Invoke-AudioManagedDownload { $global:S06Forbidden.Add('download'); throw 'Fresh conversion must not download tools.' }
'@
function Invoke-FreshConversion {
    param([string]$Config, [string]$InputDirectory, [string]$OutputParent)
    $loader = Join-Path $testRoot 'fresh-loader.ps1'; Write-NewText $loader $guardLoader; Add-Fixture $loader
    $driver = Join-Path $testRoot 'fresh-driver.ps1'
    $code = @(
        '$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''; $global:LASTEXITCODE=0',
        '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$global:S06ExpectedHelper=' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1'))),
        ('$global:S06Loader=' + (Get-Literal $loader)),
        '$global:S06Loads=0; $global:S06NativeProofs=New-Object ''System.Collections.Generic.List[object]''; $global:S06Forbidden=New-Object ''System.Collections.Generic.List[string]'''
    )
    $code += @'
function global:Join-Path {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($global:S06Loads -eq 0 -and $actual -ieq $global:S06ExpectedHelper) { $global:S06Loads++; return $global:S06Loader }
    return $actual
}
function global:Read-Host { $global:S06Forbidden.Add('prompt'); throw 'Fresh noninteractive conversion must never prompt.' }
function global:Invoke-WebRequest { $global:S06Forbidden.Add('web request'); throw 'Fresh conversion must never use network.' }
function global:Invoke-RestMethod { $global:S06Forbidden.Add('REST request'); throw 'Fresh conversion must never use network.' }
function global:Start-BitsTransfer { $global:S06Forbidden.Add('BITS'); throw 'Fresh conversion must never transfer files.' }
try {
'@
    $code += '& ' + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $InputDirectory) + ' -OutputParent ' + (Get-Literal $OutputParent) + ' -ConfigPath ' + (Get-Literal $Config)
    $code += @'
} finally {
    Write-Host ('[S06_REAL_AUDIT] ' + ([pscustomobject]@{output_encoding_codepage=[Console]::OutputEncoding.CodePage;helper_loads=$global:S06Loads;native_proofs=@($global:S06NativeProofs.ToArray());forbidden_calls=@($global:S06Forbidden.ToArray())} | ConvertTo-Json -Depth 6 -Compress))
}
exit $LASTEXITCODE
'@
    Write-NewText $driver ($code -join "`r`n"); Add-Fixture $driver
    $previousRelease = $script:releaseProved; $script:releaseProved = $false
    $savedPath = $env:PATH
    try {
        $env:PATH = ''
        $native = Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo','-NoProfile','-NonInteractive','-OutputFormat','Text','-ExecutionPolicy','RemoteSigned','-File',$driver) -TimeoutMilliseconds 90000 -Operation 'S06 real managed fresh saved-config conversion'
    } finally { $env:PATH = $savedPath }
    Assert-NativeComplete $native
    $text = $native.Stdout + "`n" + $native.Stderr
    $audits = @($text -split '\r?\n' | Where-Object { $_.StartsWith('[S06_REAL_AUDIT] ', [StringComparison]::Ordinal) })
    Assert-True ($audits.Count -eq 1) 'Fresh conversion must emit one finally audit before owned cleanup.'
    $audit = $audits[0].Substring(17) | ConvertFrom-Json
    Assert-True ($audit.output_encoding_codepage -eq 65001 -and $audit.helper_loads -eq 1 -and @($audit.forbidden_calls).Count -eq 0) 'Fresh child must retain UTF8, load the exact helper and forbid setup/network/settings/prompts.'
    Assert-True (@($audit.native_proofs).Count -gt 0 -and @($audit.native_proofs | Where-Object { -not $_.process_released -or -not $_.pipe_drain_completed }).Count -eq 0) 'Every fresh conversion native descendant must prove release and completed pipes.'
    $script:releaseProved = $previousRelease
    Assert-True ($native.ExitCode -eq 0) ('Fresh conversion failed: ' + $text.Replace($testRoot, '<OWNED_TEMP>'))
    return [pscustomobject]@{ ExitCode = $native.ExitCode; Audit = $audit }
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    Assert-True ([Console]::OutputEncoding.CodePage -eq 65001) 'Run this suite from the inherited UTF8 CP65001 console.'
    Assert-True ([Environment]::Is64BitProcess) 'Real managed x64 installation requires an x64 Windows process.'
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Exact TEMP directory must be exclusively reserved.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new = $true
    $appRoot = New-Directory ("App [literal] O'Brien " + [char]0xE4)
    [IO.Directory]::CreateDirectory((Join-Path $appRoot 'tools')) | Out-Null
    foreach ($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1','AudioFileForPhone.ManagedSetup.ps1','Setup-AudioFileForPhone.ps1','tools/ffmpeg-download.json')) {
        $copy = Join-Path $appRoot $name; Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Production app/manifest copies must preserve exact repository bytes.'
        Add-Fixture $copy
    }
    $report.copied_bytes_unchanged = $true
    $script:originalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $configRoot = New-Directory 'Owned config [x]'; $config = Join-Path $configRoot 'Remembered.json'
    $managedRoot = Join-Path $testRoot ('M [x] ' + [char]0xE4)
    $pin = [IO.File]::ReadAllText((Join-Path $appRoot 'tools/ffmpeg-download.json')) | ConvertFrom-Json
    $report['runtime_pin'] = $pin
    Invoke-Case 'explicit production setup installs exact HTTPS vendor pin with retained files and deliberately saves only after smoke' 'S06-A1,S06-A3' {
        param($case)
        $setup = Invoke-AudioToolSetup -ScriptDirectory $appRoot -AllowManagedDownload -Download -Consent -Remember -NonInteractive -ManagedRoot $managedRoot -ConfigPath $config
        Assert-True ($setup.Status -ceq 'Ready' -and $setup.Remembered -and -not $setup.SaveError) ('Real production managed setup must complete and remember: ' + $setup.Error + ' ' + $setup.SaveError)
        $script:ffmpeg = $setup.Selection.Ffmpeg.Path; $script:ffprobe = $setup.Selection.Ffprobe.Path
        $script:installedRoot = Split-Path -Parent $setup.Selection.Directory
        Assert-True ($installedRoot.StartsWith($managedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Managed setup must remain below the owned root with a separator boundary.'
        Assert-True ((Read-AudioToolConfig -ConfigPath $config).ffmpeg_directory -ceq $setup.Selection.Directory) 'Remembered config must select the completed private managed pair.'
        $provenancePath = Join-Path $installedRoot 'AudioFileForPhone-provenance.json'
        $provenance = [IO.File]::ReadAllText($provenancePath) | ConvertFrom-Json
        Assert-True ($provenance.schema_version -eq 1 -and $provenance.archive_sha256 -ieq $pin.sha256 -and
            $provenance.manifest.url -ceq $pin.url -and $provenance.manifest.build -ceq $pin.build -and
            $provenance.archive_entries -eq 49 -and $provenance.expanded_bytes -eq 329221735 -and
            $provenance.smoke -ceq '64 kbps MP3 encode, probe and full decode passed') 'Recorded provenance must bind the exact verified vendor archive and passed smoke.'
        $vendorFiles = @(Get-ChildItem -LiteralPath $installedRoot -Recurse -File | Where-Object { $_.FullName -cne $provenancePath })
        Assert-True ($vendorFiles.Count -eq 45 -and ($vendorFiles | Measure-Object -Property Length -Sum).Sum -eq 329221735) 'All 45 pinned vendor files and all expanded vendor bytes must be retained.'
        Assert-True (@(Get-ChildItem -LiteralPath $managedRoot -Force | Where-Object { $_.Name.StartsWith('.AudioFileForPhone-staging-', [StringComparison]::Ordinal) }).Count -eq 0) 'Successful installation must leave no incomplete staging directory.'
        foreach ($tool in @($setup.Selection.Ffmpeg,$setup.Selection.Ffprobe)) {
            $hash = (Get-FileHash -LiteralPath $tool.Path -Algorithm SHA256).Hash.ToLowerInvariant()
            Assert-True ($hash -ieq $provenance.tool_sha256.([IO.Path]::GetFileName($tool.Path)) -and $tool.Architecture -ceq 'x64') 'Installed x64 tools must match their bound provenance hashes.'
            $identity = Invoke-AudioNativeProcess -ExecutablePath $tool.Path -Arguments @('-version') -TimeoutMilliseconds 15000 -Operation 'S06 installed vendor identity'; Assert-NativeComplete $identity -Success
            Assert-True (($identity.Stdout -split '\r?\n')[0].Contains($pin.build)) 'Executed build identity must match the reviewed manifest.'
            $report.tools += [pscustomobject]@{ name = [IO.Path]::GetFileName($tool.Path); sha256 = $hash; version = ($identity.Stdout -split '\r?\n')[0]; architecture = $tool.Architecture }
        }
        $notices = @()
        foreach ($notice in @($pin.notices)) {
            $noticePath = Join-Path $installedRoot $notice
            Assert-True ((Get-Item -LiteralPath $noticePath).Length -gt 0) 'Vendor notices must remain nonempty.'
            $notices += [pscustomobject]@{ path = $notice; sha256 = (Get-FileHash -LiteralPath $noticePath -Algorithm SHA256).Hash.ToLowerInvariant(); bytes = (Get-Item -LiteralPath $noticePath).Length }
        }
        $readme = [IO.File]::ReadAllText((Join-Path $installedRoot 'README.txt'))
        Assert-True ($readme.Contains($pin.build) -and $readme.Contains('License: GPL v3') -and $readme.Contains('https://github.com/FFmpeg/FFmpeg/commit/946fcce07b')) 'Retained README must preserve exact vendor build, license and source references.'
        foreach ($file in @(Get-ChildItem -LiteralPath $installedRoot -Recurse -File)) { Add-Fixture $file.FullName }
        Add-Fixture $config
        $case['provenance'] = $provenance; $case['notices'] = $notices; $case['vendor_file_count'] = $vendorFiles.Count
        $case['vendor_expanded_bytes'] = 329221735; $case['network'] = 'Production bounded HTTPS downloader; no test transport or cached archive supplied'
        $case['remembered_after_smoke'] = $true; $case['staging_removed'] = $true
    }
    Invoke-Case 'fresh saved-config process converts tiny synthetic audio at default64 with independent metadata probe and full decode' 'S06-A3' {
        param($case)
        $inputDir = New-Directory 'Synthetic input [x]'; $audio = Join-Path $inputDir '2024-02-03 - Tiny.mp3'
        $generated = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.25','-c:a','libmp3lame','-metadata','artist=S06 synthetic artist',$audio) -TimeoutMilliseconds 15000 -Operation 'S06 generate owned synthetic input'; Assert-NativeComplete $generated -Success; Add-Fixture $audio
        $configHash = (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
        $parent = Join-Path $testRoot 'Fresh saved output [x]'
        $child = Invoke-FreshConversion -Config $config -InputDirectory $inputDir -OutputParent $parent
        $runs = @(Get-ChildItem -LiteralPath $parent -Directory)
        Assert-True ($runs.Count -eq 1) 'Fresh conversion must create exactly one run below explicit owned OutputParent.'
        $manifest = [IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json')) | ConvertFrom-Json
        Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.policies.bitrate_kbps -eq 64 -and $manifest.tools.ffmpeg.path -ceq $ffmpeg -and $manifest.tools.ffprobe.path -ceq $ffprobe -and $manifest.tools.selection_origin -ceq 'Saved') 'Fresh conversion must validate/use the remembered exact managed pair at default64.'
        $output = Join-Path $runs[0].FullName $manifest.records[0].output_relative_path
        $probed = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v','error','-show_streams','-show_format','-of','json',$output) -TimeoutMilliseconds 15000 -Operation 'S06 independent converted output probe'; Assert-NativeComplete $probed -Success
        $probe = $probed.Stdout | ConvertFrom-Json; $streams = @($probe.streams | Where-Object { $_.codec_type -ceq 'audio' })
        Assert-True ($streams.Count -eq 1 -and $streams[0].codec_name -ceq 'mp3' -and [int]$streams[0].bit_rate -eq 64000 -and $probe.format.tags.artist -ceq 'S06 synthetic artist') 'Independent probe must verify one 64 kbps MP3 stream and preserved artist.'
        $decoded = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL') -Operation 'S06 independent complete output decode'; Assert-NativeComplete $decoded -Success
        Assert-True ($decoded.TimeoutMilliseconds -eq 0) 'Normal full decode must retain unlimited runtime.'
        Assert-True ((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash -ceq $configHash) 'Fresh conversion must preserve remembered config bytes.'
        Assert-True (@(Get-ChildItem -LiteralPath $runs[0].FullName -Recurse -File | Where-Object { $_.Name -match '\.partial' }).Count -eq 0) 'Completed conversion must leave no partial audio.'
        $case['conversion'] = [pscustomobject]@{ exit_code = $child.ExitCode; converted = 1; bitrate_kbps = 64; selection_origin = 'Saved'; artist = $probe.format.tags.artist; full_decode = $true; output_sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant() }
        $case['child_audit'] = $child.Audit; $case['PATH'] = 'empty'; $case['config_unchanged'] = $true
    }
    Invoke-Case 'subsequent setup without renewed consent preserves valid selected config and installed bytes' 'S06-A1,S06-A2' {
        param($case)
        $configHash = (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
        $beforeDirectories = @(Get-ChildItem -LiteralPath $managedRoot -Directory | ForEach-Object Name)
        $setup = Invoke-AudioToolSetup -ScriptDirectory $appRoot -AllowManagedDownload -Download -Remember -NonInteractive -ManagedRoot $managedRoot -ConfigPath $config
        Assert-True ($setup.Status -ceq 'NotConfigured' -and $setup.Error -match 'requires -Consent') 'A repeat unattended install must refuse absent affirmative consent.'
        Assert-True ((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash -ceq $configHash -and
            ((@(Get-ChildItem -LiteralPath $managedRoot -Directory | ForEach-Object Name) | ConvertTo-Json -Compress) -ceq ($beforeDirectories | ConvertTo-Json -Compress))) 'Refused repeated install must preserve the valid config and complete installation directories.'
        $case['result'] = $setup.Status; $case['no_second_network_install'] = $true; $case['previous_selection_unchanged'] = $true
    }
    $report.status = 'pass'; $exitCode = 0
} catch {
    $report.error = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')
    $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>')
    Write-Warning $report.error
} finally {
    $env:PATH = $originalPath; $report.parent_path_unchanged = $env:PATH -ceq $originalPath
    $report.native_runs = $nativeRuns.ToArray(); $report.descendant_release_proved = $releaseProved
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository source bytes changed during real acceptance.'
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True ($report.synthetic_unchanged -and $report.parent_path_unchanged) 'Owned immutable app/vendor/fixture bytes or parent PATH changed.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['hash_verification_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        Assert-True $releaseProved 'Cleanup refused because exact native descendant release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the exact directly owned TEMP tree and unchanged create-new owner marker.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
Write-Host "S06 real managed setup: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
