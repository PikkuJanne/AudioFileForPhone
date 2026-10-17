<#
S06 managed-download failure boundaries on Windows. Only the named transport
adapter is replaced for installer fixtures. Production manifest, archive preflight,
extraction, selection and cleanup code remain intact. Timed response-stream tests
exercise the real bounded stream copier separately. No personal media or user
configuration is touched; raw fixtures stay in an exclusively owned TEMP tree.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S06-managedsetup-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-managedsetup-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S06-managedsetup active report or historical T17-managedsetup CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S06-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s06-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $exitCode = 1; $releaseProved = $true
$originalPath = $env:PATH
$originalSentinel = [Environment]::GetEnvironmentVariable('AFP_S06_EXECUTION_SENTINEL', 'Process')
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$sourcePaths = @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1','AudioFileForPhone.ManagedSetup.ps1','Setup-AudioFileForPhone.ps1','tools/ffmpeg-download.json','tests/Test-ManagedSetup.ps1')
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S06' }); mode = 'managed_installer_failure_boundaries_and_production_stream_bounds'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; real_vendor_install_evidence = $false; live_network_access = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; persistent_environment_writes = $false
    cleanup_verified = $false; descendant_release_proved = $false; native_runs = @(); tools = @(); cases = @()
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition,[string]$Message); if (-not $Condition) { throw $Message } }
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
function Write-NewText {
    param([string]$Path,[string]$Text)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text); $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths,[string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{relative_path=$path.Substring($Root.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
    })
}
function Add-Fixture { param([string]$Path); $fixtures.Add($Path); $report.synthetic_before += Get-Inventory @($Path) $testRoot }
function Invoke-Case {
    param([string]$Name,[scriptblock]$Body)
    $case = [ordered]@{name=$Name;acceptance_case='S06-A2';status='fail'}
    try { & $Body $case; $case.status='pass' } finally { $report.cases += [pscustomobject]$case }
}
function Invoke-TrackedNative {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
        [object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,
        [object]$ProgressParser,[object]$ProgressCallbackState,[int]$TimeoutMilliseconds=0,
        [string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    try {
        $native = & $script:originalNative @PSBoundParameters
        if (-not $native.ProcessReleased) { $script:releaseProved=$false }
        $nativeRuns.Add([pscustomobject]@{operation=$native.Operation;status=$native.Status;exit_code=$native.ExitCode;elapsed_ms=$native.ElapsedMilliseconds;timeout_ms=$native.TimeoutMilliseconds;process_released=$native.ProcessReleased;pipe_drain_completed=$native.PipeDrainCompleted})
        return $native
    } catch { $script:releaseProved=$false; throw }
}
function Assert-NativeSuccess {
    param([object]$Result)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ExitCode -eq 0 -and $Result.ProcessReleased -and $Result.PipeDrainCompleted) ('Owned native operation failed: '+$Result.Error+' '+$Result.Stderr)
}
function New-FixtureArchive {
    param([string]$Name,[object[]]$Entries)
    $path = Join-Path $testRoot ($Name+'.zip')
    $file = [IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        $zip = New-Object IO.Compression.ZipArchive($file,[IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($item in $Entries) {
                $entry=$zip.CreateEntry([string]$item.Name,[IO.Compression.CompressionLevel]::Optimal)
                if ($item.PSObject.Properties.Name -contains 'Attributes') { $entry.ExternalAttributes=[int]$item.Attributes }
                $destination=$entry.Open()
                try {
                    if ($item.PSObject.Properties.Name -contains 'SourcePath') {
                        $source=[IO.File]::OpenRead([string]$item.SourcePath)
                        try { $source.CopyTo($destination) } finally { $source.Dispose() }
                    }
                    else {
                        $bytes=if ($item.PSObject.Properties.Name -contains 'Bytes') { [byte[]]$item.Bytes } else { (New-Object Text.UTF8Encoding($false)).GetBytes([string]$item.Text) }
                        $destination.Write($bytes,0,$bytes.Length)
                    }
                } finally { $destination.Dispose() }
            }
        } finally { $zip.Dispose() }
    } finally { $file.Dispose() }
    Add-Fixture $path
    return $path
}
function New-FixtureManifest {
    param([string]$ArchivePath)
    $manifest = $script:pinnedManifest | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $manifest.archive_root='fixture-build'; $manifest.bin_relative_path='bin'; $manifest.notices=@('LICENSE','README.txt')
    $manifest.build='S06-independent-security-fixture'
    $manifest.sha256=(Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest.archive_size_bytes=[long](Get-Item -LiteralPath $ArchivePath).Length
    $manifest.max_download_bytes=[long]1048576; $manifest.max_expanded_bytes=[long]1048576; $manifest.max_entries=100
    $manifest.connect_timeout_seconds=1; $manifest.download_timeout_seconds=1
    return $manifest
}
function Invoke-FixtureDownload {
    param([object]$Manifest,[string]$DestinationPath,[object]$CancellationState)
    $script:downloadCalls++
    if ($script:downloadMode -ceq 'offline') { throw (New-Object IO.IOException('S06 synthetic offline transport failure.')) }
    if ($script:downloadMode -ceq 'timeout') { throw (New-Object TimeoutException('S06 synthetic download timeout.')) }
    if ($script:downloadMode -ceq 'cancel') {
        $CancellationState.Request()
        throw (New-Object OperationCanceledException('S06 synthetic download cancellation.'))
    }
    [IO.File]::Copy($script:downloadFixture,$DestinationPath,$false)
    return [pscustomobject]@{BytesWritten=(Get-Item -LiteralPath $DestinationPath).Length;FinalUri=$Manifest.url}
}
function Assert-PreservedSelection {
    Assert-True ((Get-FileHash -LiteralPath $configPath).Hash -ceq $script:configHash) 'Failed setup must preserve the previous valid config byte-for-byte.'
    Assert-True ((Get-FileHash -LiteralPath $previousSentinel).Hash -ceq $script:previousHash) 'Failed setup must preserve an unrelated previous managed dependency sentinel.'
    Assert-True (-not (Test-Path -LiteralPath $executionSentinel)) 'No executable from an unaccepted archive may execute.'
    foreach ($tool in $report.tools) {
        Assert-True ((Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant() -ceq $tool.sha256) 'User-managed tools must retain their original bytes.'
    }
}
function Invoke-InstallFailure {
    param([object]$Manifest,[string]$Expected,[object]$Case,[object]$CancellationState,[switch]$NoConsent,[string]$Root=$managedRoot)
    $message=$null; $result=$null
    $arguments=@{Manifest=$Manifest;ConfigPath=$configPath;ManagedRoot=$Root}
    if (-not $NoConsent) { $arguments.Consent=$true }
    if ($null -ne $CancellationState) { $arguments.CancellationState=$CancellationState }
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try { $result=Invoke-AudioManagedToolInstall @arguments; if ($result.Error) { $message=[string]$result.Error } }
    catch { $message=$_.Exception.Message }
    $watch.Stop()
    Assert-True (-not [string]::IsNullOrWhiteSpace($message) -and $message -match $Expected) ('Expected specific managed-install refusal '+$Expected+'; observed '+$message)
    Assert-True ($null -eq $result -or $result.Status -notin @('Ready','Success','Installed')) 'Failure must never report successful installation.'
    Assert-PreservedSelection
    $Case['diagnostic']=$message.Replace($testRoot,'<OWNED_TEMP>'); $Case['elapsed_ms']=$watch.ElapsedMilliseconds
    $Case['config_preserved']=$true; $Case['previous_dependency_preserved']=$true; $Case['unaccepted_executables_not_run']=$true
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    $report.source_before=Get-Inventory $sourcePaths $projectRoot
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
namespace AudioFileForPhoneS06 {
    public static class NativeDirectory {
        [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true,ExactSpelling=true)]
        [return:MarshalAs(UnmanagedType.Bool)] public static extern bool CreateDirectoryW(string path,IntPtr attributes);
    }
    public sealed class DelayedStream : MemoryStream {
        private readonly int delay; private readonly bool never;
        public DelayedStream(byte[] bytes,int delayMilliseconds,bool neverCompletes):base(bytes) { delay=delayMilliseconds; never=neverCompletes; }
        public override Task<int> ReadAsync(byte[] buffer,int offset,int count,CancellationToken cancellationToken) {
            if(never) return new TaskCompletionSource<int>().Task;
            return Task.Factory.StartNew(delegate { Thread.Sleep(delay); cancellationToken.ThrowIfCancellationRequested(); return base.Read(buffer,offset,count); },cancellationToken);
        }
    }
    public sealed class RequestTimer : IDisposable {
        private Timer timer;
        public RequestTimer(object context,int milliseconds) {
            timer=new Timer(delegate(object ignored) { context.GetType().GetMethod("Request").Invoke(context,new object[0]); },null,milliseconds,Timeout.Infinite);
        }
        public void Dispose() { timer.Dispose(); }
    }
}
'@
    Assert-True ([AudioFileForPhoneS06.NativeDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)) 'Owned TEMP directory must be reserved exclusively.'
    $created=$true; $report.temp_exclusively_reserved=$true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new=$true
    $appRoot=Join-Path $testRoot 'App [literal]'; [IO.Directory]::CreateDirectory($appRoot) | Out-Null
    foreach ($name in @('AudioFileForPhone.Helpers.ps1','AudioFileForPhone.ManagedSetup.ps1','Setup-AudioFileForPhone.ps1')) {
        $copy=Join-Path $appRoot $name
        Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Runtime copies must retain source bytes.'
        Add-Fixture $copy
    }
    [IO.Directory]::CreateDirectory((Join-Path $appRoot 'tools')) | Out-Null
    $manifestCopy=Join-Path $appRoot 'tools/ffmpeg-download.json'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'tools/ffmpeg-download.json') -Destination $manifestCopy; Add-Fixture $manifestCopy
    $report.copied_bytes_unchanged=$true
    . (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')
    . (Join-Path $appRoot 'AudioFileForPhone.ManagedSetup.ps1')
    $script:originalNative=(Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $script:pinnedManifest=Get-AudioManagedDownloadManifest -ManifestPath $manifestCopy
    $script:productionDownload=(Get-Command Invoke-AudioManagedDownload -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioManagedDownload -Value ${function:Invoke-FixtureDownload}
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($tool in @($ffmpeg,$ffprobe)) {
        Assert-NoReparse $tool
        $report.tools += [pscustomobject]@{path=$tool;sha256=(Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant()}
    }
    $configPath=Join-Path $testRoot 'config [literal].json'
    Save-AudioToolSelection -FfmpegDirectory (Split-Path -Parent $ffmpeg) -ConfigPath $configPath | Out-Null
    $script:configHash=(Get-FileHash -LiteralPath $configPath).Hash
    $managedRoot=Join-Path $testRoot 'Managed [literal]'; [IO.Directory]::CreateDirectory($managedRoot) | Out-Null
    $previous=Join-Path $managedRoot 'previous-accepted-build'; [IO.Directory]::CreateDirectory($previous) | Out-Null
    $previousSentinel=Join-Path $previous 'keep.txt'; Write-NewText $previousSentinel 'Preserve an existing valid selection and unrelated dependency bytes.'
    $script:previousHash=(Get-FileHash -LiteralPath $previousSentinel).Hash
    $executionSentinel=Join-Path $testRoot 'UNACCEPTED-EXECUTION.txt'
    [Environment]::SetEnvironmentVariable('AFP_S06_EXECUTION_SENTINEL',$executionSentinel,'Process')
    $markerSource=Join-Path $testRoot 'ExecutionMarker.cs'; $markerExe=Join-Path $testRoot 'ExecutionMarker.exe'
    Write-NewText $markerSource @'
using System;
using System.IO;
class ExecutionMarker {
    static int Main() {
        File.WriteAllText(Environment.GetEnvironmentVariable("AFP_S06_EXECUTION_SENTINEL"),"An unaccepted fixture executable ran.");
        return 9;
    }
}
'@
    $compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $compiled=Invoke-AudioNativeProcess -ExecutablePath $compiler -Arguments @('/nologo','/target:exe',('/out:'+$markerExe),$markerSource) -TimeoutMilliseconds 20000 -Operation 'S06 compile independent execution marker'
    Assert-NativeSuccess $compiled; Add-Fixture $markerSource; Add-Fixture $markerExe
    # Prove the independent marker really executes before relying on its absence.
    $markerCheck=Invoke-AudioNativeProcess -ExecutablePath $markerExe -Arguments @() -TimeoutMilliseconds 5000 -Operation 'S06 execution-marker self-check'
    Assert-True ($markerCheck.Status -ceq 'Completed' -and $markerCheck.ExitCode -eq 9 -and $markerCheck.ProcessReleased -and (Test-Path -LiteralPath $executionSentinel)) 'Executable execution marker must be independently proved.'
    [IO.File]::Delete($executionSentinel)
    $markerBytes=[IO.File]::ReadAllBytes($markerExe)
    $baseEntries=@(
        [pscustomobject]@{Name='fixture-build/bin/ffmpeg.exe';Bytes=$markerBytes},
        [pscustomobject]@{Name='fixture-build/bin/ffprobe.exe';Bytes=$markerBytes},
        [pscustomobject]@{Name='fixture-build/LICENSE';Text='Synthetic license fixture'},
        [pscustomobject]@{Name='fixture-build/README.txt';Text='Synthetic notice fixture'}
    )
    $validArchive=New-FixtureArchive 'structurally-valid' $baseEntries
    $script:downloadFixture=$validArchive; $script:downloadMode='copy'; $script:downloadCalls=0
    $validManifest=New-FixtureManifest $validArchive
    Add-Fixture $configPath; Add-Fixture $previousSentinel
    Invoke-Case 'archive-preflight-accepts-complete-safe-fixture-without-executing' {
        param($case)
        $destination=Join-Path $testRoot 'accepted-archive-preflight'; [IO.Directory]::CreateDirectory($destination) | Out-Null
        Expand-AudioManagedArchive -ArchivePath $validArchive -DestinationPath $destination -Manifest $validManifest | Out-Null
        foreach ($name in @('bin/ffmpeg.exe','bin/ffprobe.exe','LICENSE','README.txt')) {
            Assert-True (Test-Path -LiteralPath (Join-Path $destination ('fixture-build/'+$name)) -PathType Leaf) 'Safe archive extraction must preserve both tools and notices.'
        }
        Assert-PreservedSelection
        $case['archive_only_validation']=$true; $case['executable_marker_absent']=$true
    }
    Invoke-Case 'explicit-install-without-consent-performs-no-transport-or-staging' {
        param($case)
        $case['acceptance_case']='S06-A1'
        $newRoot=Join-Path $testRoot 'must-not-create-without-consent'; $before=$script:downloadCalls
        Invoke-InstallFailure $validManifest 'consent|Consent' $case -NoConsent -Root $newRoot
        Assert-True ($script:downloadCalls -eq $before -and -not (Test-Path -LiteralPath $newRoot)) 'Declined explicit consent must precede transfer and storage creation.'
        $case['transport_calls']=0; $case['staging_created']=$false
    }
    Invoke-Case 'pre-requested-cancellation-performs-no-transport-or-staging' {
        param($case)
        $context=New-AudioCancellationContext
        try {
            $context.Request(); $before=$script:downloadCalls; $newRoot=Join-Path $testRoot 'must-not-create-when-cancelled'
            Invoke-InstallFailure $validManifest 'cancel|Cancel' $case -CancellationState $context -Root $newRoot
            Assert-True ($script:downloadCalls -eq $before -and -not (Test-Path -LiteralPath $newRoot)) 'Pre-requested cancellation must precede network and staging.'
            $case['transport_calls']=0; $case['staging_created']=$false
        } finally { $context.Dispose() }
    }
    Invoke-Case 'shared-setup-explicit-download-without-consent-refuses-early' {
        param($case)
        $case['acceptance_case']='S06-A1'
        $newRoot=Join-Path $testRoot 'shared-refusal-no-storage'; $before=$script:downloadCalls
        $result=Invoke-AudioToolSetup -ScriptDirectory $appRoot -ConfigPath $configPath -AllowManagedDownload -Download -NonInteractive -ManagedRoot $newRoot
        Assert-True ($result.Status -ceq 'NotConfigured' -and $result.Error -match 'Consent|consent' -and $script:downloadCalls -eq $before -and -not (Test-Path -LiteralPath $newRoot)) 'Shared unattended setup requires explicit consent before engine or storage.'
        Assert-PreservedSelection; $case['status_observed']=$result.Status; $case['transport_calls']=0
    }
    $originalInteractive=(Get-Command Test-AudioSetupInteractionAvailable -CommandType Function).ScriptBlock
    $originalResponse=(Get-Command Read-AudioSetupResponse -CommandType Function).ScriptBlock
    function Test-AudioSetupInteractionAvailable { return $true }
    function Read-AudioSetupResponse {
        param([string]$Prompt)
        $script:responsePrompts.Add($Prompt)
        Assert-True ($script:responses.Count -gt 0) 'Unexpected repeated production setup prompt.'
        return $script:responses.Dequeue()
    }
    try {
        Invoke-Case 'shared-interactive-D-decline-is-one-shot-without-installation' {
            param($case)
            $case['acceptance_case']='S06-A1'
            $script:responses=New-Object 'Collections.Generic.Queue[string]'; $script:responsePrompts=New-Object 'Collections.Generic.List[string]'
            $script:responses.Enqueue('D'); $script:responses.Enqueue('N')
            $newRoot=Join-Path $testRoot 'interactive-decline-no-storage'; $before=$script:downloadCalls
            $result=Invoke-AudioToolSetup -ScriptDirectory $appRoot -ConfigPath $configPath -AllowManagedDownload -ManagedRoot $newRoot
            Assert-True ($result.Status -ceq 'Cancelled' -and $script:responses.Count -eq 0 -and $script:responsePrompts.Count -eq 2 -and $script:downloadCalls -eq $before -and -not (Test-Path -LiteralPath $newRoot)) 'Interactive D must ask affirmative consent once; N leaves installation/config untouched.'
            Assert-PreservedSelection; $case['prompt_count']=2; $case['transport_calls']=0
        }
        Invoke-Case 'conversion-D-cannot-grant-download-authority' {
            param($case)
            $case['acceptance_case']='S06-A1'
            # This app view deliberately lacks the managed engine/manifest. The
            # conversion-facing shared flow must return separate-setup guidance
            # without loading either one, even if an affirmative answer is queued.
            $conversionRoot=Join-Path $testRoot 'conversion-view-without-managed-engine'; [IO.Directory]::CreateDirectory($conversionRoot) | Out-Null
            $script:responses=New-Object 'Collections.Generic.Queue[string]'; $script:responsePrompts=New-Object 'Collections.Generic.List[string]'
            $script:responses.Enqueue('D'); $script:responses.Enqueue('Y'); $before=$script:downloadCalls
            $result=Invoke-AudioToolSetup -ScriptDirectory $conversionRoot -ConfigPath $configPath
            Assert-True ($result.Status -ceq 'NotConfigured' -and $result.Error -match 'separate setup' -and $script:responses.Count -eq 1 -and $script:responsePrompts.Count -eq 1 -and $script:downloadCalls -eq $before) 'Conversion must not load a managed engine or consume affirmative download consent.'
            Assert-PreservedSelection; $case['prompt_count']=1; $case['queued_yes_not_consumed']=$true; $case['transport_calls']=0
        }
    } finally {
        Set-Item -LiteralPath Function:script:Test-AudioSetupInteractionAvailable -Value $originalInteractive
        Set-Item -LiteralPath Function:script:Read-AudioSetupResponse -Value $originalResponse
    }
    Invoke-Case 'standalone-download-without-consent-refuses-in-UTF8-child' {
        param($case)
        $case['acceptance_case']='S06-A1'
        $driver=Join-Path $testRoot 'standalone-no-consent-driver.ps1'
        $setupLiteral="'"+(Join-Path $appRoot 'Setup-AudioFileForPhone.ps1').Replace("'","''")+"'"
        $configLiteral="'"+$configPath.Replace("'","''")+"'"
        $newRoot=Join-Path $testRoot 'standalone-no-consent-no-storage'
        $rootLiteral="'"+$newRoot.Replace("'","''")+"'"
        Write-NewText $driver ("[Console]::OutputEncoding=New-Object Text.UTF8Encoding(`$false)`r`ntry { & "+$setupLiteral+' -Download -NonInteractive -ConfigPath '+$configLiteral+' -ManagedRoot '+$rootLiteral+" } finally { Write-Host ('[S06_CODEPAGE] ' + [Console]::OutputEncoding.CodePage) }`r`nexit `$LASTEXITCODE`r`n")
        Add-Fixture $driver
        $shellPath=Join-Path $PSHOME $(if ($edition -ceq 'ps51') {'powershell.exe'} else {'pwsh.exe'})
        $result=Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo','-NoProfile','-NonInteractive','-OutputFormat','Text','-ExecutionPolicy','RemoteSigned','-File',$driver) -TimeoutMilliseconds 30000 -Operation 'S06 standalone consent refusal'
        Assert-True ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 1 -and $result.ProcessReleased -and $result.PipeDrainCompleted -and ($result.Stdout+$result.Stderr) -match 'requires -Consent' -and -not (Test-Path -LiteralPath $newRoot)) 'Production standalone must refuse missing Consent before any managed storage.'
        Assert-True ($result.Stdout -match '(?m)^\[S06_CODEPAGE\] 65001\r?$') 'The actual redirected child must independently report UTF8 CP65001.'
        Assert-PreservedSelection; $case['child_exit_code']=1; $case['owned_child_output_codepage']=65001
    }
    foreach ($mode in @('offline','timeout','cancel')) {
        Invoke-Case ('installer-'+$mode+'-preserves-previous-selection') {
            param($case)
            $script:downloadMode=$mode; $context=New-AudioCancellationContext
            try {
                $before=$script:downloadCalls
                Invoke-InstallFailure $validManifest $mode $case -CancellationState $context
                Assert-True ($script:downloadCalls -eq $before+1) 'Expected one scoped transport attempt.'
                $case['transport_calls']=1; $case['scope']='transport failure propagation and installer cleanup, not live-network evidence'
            } finally { $context.Dispose(); $script:downloadMode='copy' }
        }
    }
    Invoke-Case 'pinned-hash-mismatch-is-refused-before-execution' {
        param($case)
        $manifest=New-FixtureManifest $validArchive; $manifest.sha256=('0'*64)
        Invoke-InstallFailure $manifest 'hash|SHA256|integrity' $case
    }
    Invoke-Case 'pinned-archive-byte-length-mismatch-is-refused-before-execution' {
        param($case)
        $manifest=New-FixtureManifest $validArchive; $manifest.archive_size_bytes++
        Invoke-InstallFailure $manifest 'size|bytes|length' $case
    }
    Invoke-Case 'invalid-manifest-download-bound-refused-before-transport' {
        param($case)
        $manifest=New-FixtureManifest $validArchive; $manifest.max_download_bytes=$manifest.archive_size_bytes-1; $before=$script:downloadCalls
        Invoke-InstallFailure $manifest 'size|bound|bytes|download' $case
        Assert-True ($script:downloadCalls -eq $before) 'Inconsistent pinned transfer bounds must be refused before transport.'
        $case['transport_calls']=0
    }
    Invoke-Case 'hash-valid-non-ZIP-is-refused' {
        param($case)
        $badZip=Join-Path $testRoot 'not-an-archive.zip'; Write-NewText $badZip 'This is not a ZIP, despite its correct fixture pin.'; Add-Fixture $badZip
        $script:downloadFixture=$badZip
        Invoke-InstallFailure (New-FixtureManifest $badZip) 'archive|ZIP|Central Directory|End of' $case
    }
    $unsafeEntries=@(
        [pscustomobject]@{Label='dot-dot-traversal';Name='fixture-build/../../escape.txt'},
        [pscustomobject]@{Label='backslash-traversal';Name='fixture-build\..\escape.txt'},
        [pscustomobject]@{Label='rooted-drive';Name='C:/escape.txt'},
        [pscustomobject]@{Label='drive-relative';Name='C:escape.txt'},
        [pscustomobject]@{Label='rooted-slash';Name='/escape.txt'},
        [pscustomobject]@{Label='UNC';Name='\\server\share\escape.txt'},
        [pscustomobject]@{Label='ADS';Name='fixture-build/notice.txt:payload'},
        [pscustomobject]@{Label='reserved-device';Name='fixture-build/NUL.txt'},
        [pscustomobject]@{Label='trailing-dot';Name='fixture-build/notice.'},
        [pscustomobject]@{Label='trailing-space';Name='fixture-build/notice '},
        [pscustomobject]@{Label='wildcard';Name='fixture-build/notice?.txt'},
        [pscustomobject]@{Label='root-prefix-collision';Name='fixture-build-other/outside.txt'},
        [pscustomobject]@{Label='exact-duplicate';Name='fixture-build/LICENSE'},
        [pscustomobject]@{Label='case-collision';Name='fixture-build/license'},
        [pscustomobject]@{Label='implicit-parent-case-collision';Name='fixture-build/BIN/extra.txt'},
        [pscustomobject]@{Label='file-as-parent';Name='fixture-build/LICENSE/payload.txt'},
        [pscustomobject]@{Label='unix-symlink';Name='fixture-build/link';Attributes=-1577123840},
        [pscustomobject]@{Label='windows-reparse';Name='fixture-build/reparse';Attributes=1024}
    )
    foreach ($unsafe in $unsafeEntries) {
        Invoke-Case ('unsafe-archive-'+$unsafe.Label+'-never-executes-tools') {
            param($case)
            $extra=[pscustomobject]@{Name=$unsafe.Name;Text='Security fixture payload.'}
            if ($unsafe.PSObject.Properties.Name -contains 'Attributes') { $extra | Add-Member -NotePropertyName Attributes -NotePropertyValue $unsafe.Attributes }
            $archive=New-FixtureArchive $unsafe.Label (@($baseEntries)+@($extra)); $script:downloadFixture=$archive
            Invoke-InstallFailure (New-FixtureManifest $archive) 'archive|entry|path|root|component|duplicate|unsafe|reparse|symlink|collision|directory|parent|separator' $case
            $case['archive_security_fixture']=$unsafe.Label
        }
    }
    Invoke-Case 'archive-entry-count-bound' {
        param($case)
        $script:downloadFixture=$validArchive; $manifest=New-FixtureManifest $validArchive; $manifest.max_entries=3
        Invoke-InstallFailure $manifest 'count|entries|limit|bound' $case
    }
    foreach ($mode in @('lying-entry-count','ZIP64-sentinel')) {
        Invoke-Case ('archive-directory-'+$mode+'-rejected-before-materialization') {
            param($case)
            $bytes=[IO.File]::ReadAllBytes($validArchive); $eocd=$bytes.Length-22
            Assert-True ([BitConverter]::ToUInt32($bytes,$eocd) -eq [uint32]0x06054b50) 'Fixture must have an unambiguous terminal EOCD with no comment.'
            $value=if ($mode -ceq 'ZIP64-sentinel') {[uint16]65535} else {[uint16]1}
            [Array]::Copy([BitConverter]::GetBytes($value),0,$bytes,$eocd+8,2)
            [Array]::Copy([BitConverter]::GetBytes($value),0,$bytes,$eocd+10,2)
            $path=Join-Path $testRoot ($mode+'.zip')
            $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            try {$stream.Write($bytes,0,$bytes.Length)} finally {$stream.Dispose()}
            Add-Fixture $path; $script:downloadFixture=$path; $manifest=New-FixtureManifest $path
            if ($mode -ceq 'lying-entry-count') {$manifest.max_entries=3}
            Invoke-InstallFailure $manifest 'count|entries|bound|ZIP64|directory|archive' $case
            $case['modified_EOCD']=$mode
        }
    }
    Invoke-Case 'archive-expanded-size-bound' {
        param($case)
        $archive=New-FixtureArchive 'expanded-bomb' (@($baseEntries)+@([pscustomobject]@{Name='fixture-build/large.txt';Bytes=(New-Object byte[] 65536)}))
        $script:downloadFixture=$archive; $manifest=New-FixtureManifest $archive; $manifest.max_expanded_bytes=16384
        Invoke-InstallFailure $manifest 'size|expanded|limit|bound|bytes' $case
    }
    foreach ($metadataMode in @('central-only','both-headers')) {
    Invoke-Case ('actual-expanded-entry-cannot-exceed-declared-metadata-'+$metadataMode) {
        param($case)
        $archive=New-FixtureArchive ('metadata-before-patch-'+$metadataMode) (@($baseEntries)+@([pscustomobject]@{Name='fixture-build/large.txt';Bytes=(New-Object byte[] 65536)}))
        $bytes=[IO.File]::ReadAllBytes($archive); $patched=0
        for ($index=0; $index -le $bytes.Length-46; $index++) {
            if ($bytes[$index] -eq 0x50 -and $bytes[$index+1] -eq 0x4b -and $bytes[$index+2] -eq 1 -and $bytes[$index+3] -eq 2) {
                $nameLength=[BitConverter]::ToUInt16($bytes,$index+28)
                if ($index+46+$nameLength -le $bytes.Length -and [Text.Encoding]::UTF8.GetString($bytes,$index+46,$nameLength) -ceq 'fixture-build/large.txt') {
                    # Keep the compressed data intact but make the ZIP central
                    # directory lie about its expanded size. The fixture pin is
                    # recomputed, so production extraction must enforce actual
                    # bytes rather than only trusting preflight metadata.
                    $replacement=[BitConverter]::GetBytes([uint32]1)
                    [Array]::Copy($replacement,0,$bytes,$index+24,4)
                    if ($metadataMode -ceq 'both-headers') {
                        $localOffset=[BitConverter]::ToUInt32($bytes,$index+42)
                        Assert-True ([BitConverter]::ToUInt32($bytes,[int]$localOffset) -eq [uint32]0x04034b50 -and [BitConverter]::ToUInt32($bytes,[int]$localOffset+22) -eq 65536) 'The intended local header must independently declare the real uncompressed length before mutation.'
                        [Array]::Copy($replacement,0,$bytes,[int]$localOffset+22,4)
                    }
                    $patched++
                }
            }
        }
        Assert-True ($patched -eq 1) 'Exactly the intended central-directory expanded length must be patched.'
        $mutated=Join-Path $testRoot ('metadata-lie-'+$metadataMode+'.zip')
        $output=[IO.File]::Open($mutated,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $output.Write($bytes,0,$bytes.Length) } finally { $output.Dispose() }
        Add-Fixture $mutated; $script:downloadFixture=$mutated
        Invoke-InstallFailure (New-FixtureManifest $mutated) 'expansion|expanded|metadata|length|archive|size' $case
        $case['declared_bytes']=1; $case['real_expanded_bytes']=65536; $case['patched_headers']=$metadataMode
    }
    }
    Invoke-Case 'directory-entry-cannot-hide-compressed-payload-behind-zero-expanded-size' {
        param($case)
        $directoryName='fixture-build/empty-directory/'
        $archive=New-FixtureArchive 'directory-payload-before-patch' (@($baseEntries)+@([pscustomobject]@{Name=$directoryName;Bytes=(New-Object byte[] 512)}))
        $bytes=[IO.File]::ReadAllBytes($archive); $patched=0
        for ($index=0; $index -le $bytes.Length-46; $index++) {
            if ($bytes[$index] -eq 0x50 -and $bytes[$index+1] -eq 0x4b -and $bytes[$index+2] -eq 1 -and $bytes[$index+3] -eq 2) {
                $nameLength=[BitConverter]::ToUInt16($bytes,$index+28)
                if ($index+46+$nameLength -le $bytes.Length -and [Text.Encoding]::UTF8.GetString($bytes,$index+46,$nameLength) -ceq $directoryName) {
                    $localOffset=[BitConverter]::ToUInt32($bytes,$index+42)
                    Assert-True ([BitConverter]::ToUInt32($bytes,[int]$localOffset) -eq [uint32]0x04034b50 -and [BitConverter]::ToUInt32($bytes,$index+20) -gt 0) 'Synthetic directory entry must contain a real compressed payload.'
                    $zero=[BitConverter]::GetBytes([uint32]0)
                    [Array]::Copy($zero,0,$bytes,$index+24,4); [Array]::Copy($zero,0,$bytes,[int]$localOffset+22,4); $patched++
                }
            }
        }
        Assert-True ($patched -eq 1) 'Exactly the intended directory entry must have both declared expanded sizes patched.'
        $mutated=Join-Path $testRoot 'directory-hidden-payload.zip'
        $stream=[IO.File]::Open($mutated,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try {$stream.Write($bytes,0,$bytes.Length)} finally {$stream.Dispose()}
        Add-Fixture $mutated; $script:downloadFixture=$mutated
        Invoke-InstallFailure (New-FixtureManifest $mutated) 'directory|payload|archive|size|compression|CRC' $case
        $case['declared_expanded_bytes']=0; $case['real_expanded_bytes']=512
    }
    Invoke-Case 'required-vendor-notice-is-checked-before-any-executable' {
        param($case)
        $archive=New-FixtureArchive 'missing-notice' @($baseEntries | Where-Object {$_.Name -cne 'fixture-build/LICENSE'})
        $script:downloadFixture=$archive
        Invoke-InstallFailure (New-FixtureManifest $archive) 'required|LICENSE|notice' $case
    }
    Invoke-Case 'existing-reparse-managed-root-is-refused-without-following' {
        param($case)
        $target=Join-Path $testRoot 'junction-target'; [IO.Directory]::CreateDirectory($target) | Out-Null
        $targetSentinel=Join-Path $target 'keep.txt'; Write-NewText $targetSentinel 'Never follow or delete this junction target.'; Add-Fixture $targetSentinel
        $junction=Join-Path $testRoot 'managed-junction'
        try {
            New-Item -ItemType Junction -Path $junction -Target $target | Out-Null
            Assert-True (((Get-Item -LiteralPath $junction -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Fixture must create a real Windows reparse point.'
            $before=$script:downloadCalls
            Invoke-InstallFailure $validManifest 'reparse|junction|symbolic|link' $case -Root $junction
            Assert-True ($script:downloadCalls -eq $before -and [IO.File]::ReadAllText($targetSentinel) -ceq 'Never follow or delete this junction target.') 'ManagedRoot reparse refusal must precede transfer and preserve its target.'
            $case['real_windows_junction_refused']=$true; $case['transport_calls']=0
        } finally {
            if ([IO.Directory]::Exists($junction)) {
                $link=Get-Item -LiteralPath $junction -Force
                Assert-True ($link.FullName -ceq $junction -and ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and @($link.Target).Count -eq 1 -and [IO.Path]::GetFullPath([string]$link.Target) -ieq $target) 'Exact junction identity must be checked before nonrecursive link deletion.'
                [IO.Directory]::Delete($junction,$false)
            }
        }
    }
    foreach ($mode in @('exact','short','pin-overflow','max-overflow','timeout','cancel')) {
        Invoke-Case ('production-download-stream-'+$mode) {
            param($case)
            $manifest=New-FixtureManifest $validArchive
            $manifest.archive_size_bytes=[long]16; $manifest.max_download_bytes=[long]16; $manifest.download_timeout_seconds=1
            $length=16
            if ($mode -ceq 'short') {$length=15}
            if ($mode -ceq 'pin-overflow') {$length=32; $manifest.max_download_bytes=[long]64}
            if ($mode -ceq 'max-overflow') {$length=32; $manifest.archive_size_bytes=[long]64}
            $never=$mode -in @('timeout','cancel')
            $input=New-Object AudioFileForPhoneS06.DelayedStream((New-Object byte[] $length),0,$never)
            $output=New-Object IO.MemoryStream
            $cancel=New-Object Threading.CancellationTokenSource; $context=New-AudioCancellationContext; $requestTimer=$null
            $watch=[Diagnostics.Stopwatch]::StartNew(); $message=$null; $count=$null
            if ($mode -ceq 'cancel') { $requestTimer=New-Object AudioFileForPhoneS06.RequestTimer($context,200) }
            try {
                try { $count=Copy-AudioManagedResponseStream -Stream $input -DestinationStream $output -Manifest $manifest -Timer $watch -CancellationState $context -CancellationSource $cancel }
                catch { $message=$_.Exception.Message }
                $watch.Stop()
                if ($mode -ceq 'exact') {
                    Assert-True ($null -eq $message -and $count -eq 16 -and $output.Length -eq 16) 'Production bounded copier must accept precisely pinned bytes.'
                }
                elseif ($mode -ceq 'short') {
                    Assert-True ($message -match 'size mismatch' -and $output.Length -eq 15) 'Short bodies must be refused after EOF without claiming a complete artifact.'
                }
                elseif ($mode -in @('pin-overflow','max-overflow')) {
                    Assert-True ($message -match 'bound' -and $output.Length -eq 0) 'Production copier must reject a read exceeding either bound before writing it.'
                }
                elseif ($mode -ceq 'timeout') {
                    Assert-True ($message -match 'deadline|timeout' -and $watch.ElapsedMilliseconds -ge 950 -and $watch.ElapsedMilliseconds -lt 3000 -and $cancel.IsCancellationRequested -and $output.Length -eq 0) 'A never-completing body read must time out and cancel its scoped request within the declared bound.'
                }
                else {
                    Assert-True ($message -match 'cancel' -and $watch.ElapsedMilliseconds -lt 1000 -and $cancel.IsCancellationRequested -and $output.Length -eq 0) 'Requested cancellation must beat the body deadline and cancel the scoped request.'
                }
                Assert-PreservedSelection
                $case['diagnostic']=$message; $case['elapsed_ms']=$watch.ElapsedMilliseconds; $case['bytes_written']=$output.Length
                $case['scope']='production bounded asynchronous response copier with independent synthetic stream; no live HTTP claim'
            } finally {
                if ($null -ne $requestTimer) { $requestTimer.Dispose() }
                $input.Dispose(); $output.Dispose(); $context.Dispose(); $cancel.Dispose()
            }
        }
    }
    Invoke-Case 'all-failed-installs-remove-only-their-owned-staging' {
        param($case)
        $entries=@(Get-ChildItem -LiteralPath $managedRoot -Force)
        Assert-True ($entries.Count -eq 1 -and $entries[0].FullName -ceq $previous) 'Every failed install must clean its own stage and preserve the prior managed dependency.'
        Assert-PreservedSelection; $case['leftover_staging_count']=0
    }
    Invoke-Case 'repeat-managed-install-uses-unique-complete-directories-and-preserves-earlier-install' {
        param($case)
        $realEntries=@(
            [pscustomobject]@{Name='fixture-build/bin/ffmpeg.exe';SourcePath=$ffmpeg},
            [pscustomobject]@{Name='fixture-build/bin/ffprobe.exe';SourcePath=$ffprobe},
            [pscustomobject]@{Name='fixture-build/LICENSE';Text='Synthetic test notice. This owned test archive is not a vendor provenance claim.'},
            [pscustomobject]@{Name='fixture-build/README.txt';Text='Synthetic repeat-install fixture using the explicitly supplied real x64 tool pair.'}
        )
        $archive=New-FixtureArchive 'real-tools-repeat-install' $realEntries
        $manifest=New-FixtureManifest $archive
        $manifest.max_download_bytes=[long]$manifest.archive_size_bytes+1048576
        $manifest.max_expanded_bytes=[long](Get-Item -LiteralPath $ffmpeg).Length+[long](Get-Item -LiteralPath $ffprobe).Length+1048576
        $script:downloadFixture=$archive; $before=$script:downloadCalls
        $first=Invoke-AudioManagedToolInstall -Manifest $manifest -ConfigPath $configPath -ManagedRoot $managedRoot -Consent
        Assert-True ($null -ne $first.ToolSelection -and $first.ToolSelection.Origin -ceq 'ManagedSetup' -and $first.PersistenceSucceeded -eq $false) 'A completed real fixture installation must return a validated current-run selection without implicit config persistence.'
        Assert-SafeTree $first.InstalledDirectory
        $firstPaths=@(Get-ChildItem -LiteralPath $first.InstalledDirectory -File -Recurse -Force | Select-Object -ExpandProperty FullName)
        $firstInventory=Get-Inventory $firstPaths $first.InstalledDirectory
        $second=Invoke-AudioManagedToolInstall -Manifest $manifest -ConfigPath $configPath -ManagedRoot $managedRoot -Consent
        Assert-True ($null -ne $second.ToolSelection -and $first.InstalledDirectory -cne $second.InstalledDirectory -and [IO.Path]::GetDirectoryName($first.InstalledDirectory) -ieq $managedRoot -and [IO.Path]::GetDirectoryName($second.InstalledDirectory) -ieq $managedRoot) 'Repeated setup must create distinct validated private versions without overwriting its predecessor.'
        Assert-True (($firstInventory | ConvertTo-Json -Compress) -ceq ((Get-Inventory $firstPaths $first.InstalledDirectory) | ConvertTo-Json -Compress)) 'The second installation must preserve every first-install tool, notice and provenance byte.'
        foreach ($installed in @($first,$second)) {
            Assert-True ((Test-Path -LiteralPath $installed.ProvenancePath -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $installed.InstalledDirectory 'LICENSE') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $installed.InstalledDirectory 'README.txt') -PathType Leaf)) 'Every published dependency must retain notices and provenance.'
            foreach ($tool in $report.tools) {
                Assert-True ((Get-FileHash -LiteralPath (Join-Path $installed.ToolSelection.Directory ([IO.Path]::GetFileName($tool.path)))).Hash.ToLowerInvariant() -ceq $tool.sha256) 'Installed tools must exactly match the accepted real fixture bytes.'
            }
        }
        Assert-True ($script:downloadCalls -eq $before+2 -and @((Get-ChildItem -LiteralPath $managedRoot -Force) | Where-Object {$_.Name -like '.AudioFileForPhone-staging-*'}).Count -eq 0) 'Two explicit installs require two transfers and must leave no incomplete stage.'
        Assert-PreservedSelection
        $case['scope']='real supplied x64 tool pair, full production capability checks and synthetic MP3 encode/probe/full-decode twice; download transport only is mocked; not primary-vendor provenance evidence'
        $case['completed_installs']=2; $case['unique_destinations']=$true; $case['previous_install_unchanged']=$true; $case['config_unchanged']=$true
        $case['first_publication_attempts']=[int]$first.PublicationAttempts
        $case['second_publication_attempts']=[int]$second.PublicationAttempts
    }
    $report.status='pass'; $exitCode=0
} catch { $report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    [Environment]::SetEnvironmentVariable('AFP_S06_EXECUTION_SENTINEL',$originalSentinel,'Process')
    $report.native_runs=$nativeRuns.ToArray(); $report.descendant_release_proved=$releaseProved
    $report.parent_path_unchanged=$env:PATH -ceq $originalPath
    try {
        Assert-True $report.parent_path_unchanged 'Setup tests must preserve parent PATH.'
        $report.source_after=Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged=($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress)
        Assert-True $report.source_unchanged 'Repository source bytes changed during tests.'
        $report.synthetic_after=Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged=($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress)
        Assert-True $report.synthetic_unchanged 'Owned source/runtime/archive/config fixture bytes changed.'
    } catch { $report.status='fail'; $exitCode=1; $report['hash_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        Assert-True $releaseProved 'Cleanup requires proved native release.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay in the exact directly owned TEMP tree.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires the unchanged create-new ownership token.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified=-not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status='fail'; $exitCode=1; $report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc']=[DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 18)
}
Write-Host "S06 managed setup: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
