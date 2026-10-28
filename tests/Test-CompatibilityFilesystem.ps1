<#
S11 owned Windows filesystem tests. All mutable configuration, startup
records, exports, synthetic media and copied packages remain in one exclusively
reserved token-owned TEMP tree. Ordinary Music and owner configuration are never
opened. Pure failure substitutions are identified separately from native checks.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -ceq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
if ($evidenceParent -ine (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -or
    $leaf -cnotmatch "^S11-filesystem-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$") {
    throw 'Use a fresh S11-filesystem report for this host in the active evidence directory.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; choose a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'S11F-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s11-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'Collections.Generic.List[string]'
$nativeRuns = New-Object 'Collections.Generic.List[object]'
$runtimePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1',
    'AudioFileForPhone.Checks.ps1', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1',
    'AudioFileForPhone.bat', 'Check-AudioFileForPhone.ps1', 'Check-AudioFileForPhone.bat',
    'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ManagedSetup.ps1')
$sourcePaths = $runtimePaths + @('tests/Test-CompatibilityFilesystem.ps1')
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'S11'; mode = 'real_windows_owned_filesystem_and_labelled_write_fault'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; persistent_environment_writes = $false; automatic_uploads = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; descendant_release_proved = $false; cleanup_verified = $false
    tools = @(); native_runs = @(); cases = @(); status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'Collections.Generic.Stack[string]'; $items = New-Object 'Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$NoBom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding(-not $NoBom.IsPresent); $preamble = $encoding.GetPreamble()
        $stream.Write($preamble, 0, $preamble.Length); $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
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
function Get-Literal { param([AllowEmptyString()][string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Get-TreeState {
    param([string[]]$Roots)
    $rows = @()
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { $rows += $root + '|ABSENT'; continue }
        $rows += $root + '|DIRECTORY'
        foreach ($item in @(Get-SafeTree $root | Sort-Object FullName)) {
            $rows += if ($item.PSIsContainer) { $item.FullName + '|DIRECTORY' } else { $item.FullName + '|' + (Get-FileHash -LiteralPath $item.FullName).Hash }
        }
    }
    return $rows | ConvertTo-Json -Compress
}
function New-AppCopy {
    param([string]$Name, [string]$Missing = '')
    $directory = New-Directory $Name
    foreach ($relative in $runtimePaths) {
        if ($relative -ceq $Missing) { continue }
        $copy = Join-Path $directory $relative
        [IO.File]::Copy((Join-Path $projectRoot $relative), $copy, $false)
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $relative)).Hash) 'Copied runtime must be byte-identical.'
        Add-Fixture $copy
    }
    return $directory
}
function Invoke-Child {
    param([string]$Label, [string]$Code, [hashtable]$EnvironmentValues = @{}, [int]$DeadlineMilliseconds = 120000)
    $driver = Join-Path $testRoot ($Label + '-driver.ps1')
    $prefix = @('$ErrorActionPreference=''Stop''; $ProgressPreference=''SilentlyContinue''',
        '[Console]::InputEncoding=New-Object Text.UTF8Encoding($false); [Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        '$env:PSModulePath=(Join-Path $PSHOME ''Modules'')+'';''+$env:PSModulePath')
    Write-NewText $driver (($prefix + $Code) -join "`r`n"); Add-Fixture $driver
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $shellPath; $info.WorkingDirectory = $testRoot
    $info.Arguments = (@('-NoLogo', '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'RemoteSigned', '-File', $driver) | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false); $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    foreach ($name in @($info.EnvironmentVariables.Keys)) {
        if ([string]$name -like 'AUDIOFILEFORPHONE_*') { $info.EnvironmentVariables.Remove($name) }
    }
    $info.EnvironmentVariables['LOCALAPPDATA'] = $localData
    $info.EnvironmentVariables['TEMP'] = $childTemp; $info.EnvironmentVariables['TMP'] = $childTemp
    $info.EnvironmentVariables['PATH'] = $emptyPath
    foreach ($name in $EnvironmentValues.Keys) { $info.EnvironmentVariables[$name] = [string]$EnvironmentValues[$name] }
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info; $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        Assert-True $process.Start() 'Owned filesystem child did not start.'
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($DeadlineMilliseconds)) {
            $script:releaseProved = $false; $process.Kill(); $process.WaitForExit(5000) | Out-Null
            throw 'Owned filesystem child exceeded deadline; descendant release unproved, fixtures retained.'
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)) {
            $script:releaseProved = $false; throw 'Owned filesystem child pipe remains held; retaining owned fixtures.'
        }
        $result = [pscustomobject]@{ exit_code = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result; elapsed_ms = $timer.ElapsedMilliseconds; process_released = $true; pipe_drain_completed = $true }
        $nativeRuns.Add([pscustomobject]@{ operation = $Label; status = 'Completed'; exit_code = $result.exit_code; elapsed_ms = $result.elapsed_ms; process_released = $true; pipe_drain_completed = $true })
        return $result
    } finally { $timer.Stop(); $process.Dispose() }
}
function Set-OwnedDirectoryAccess {
    param([string]$Path,[Security.AccessControl.DirectorySecurity]$Acl)
    Assert-NoReparse $Path
    Assert-True ($Path.StartsWith($testRoot+'\',[StringComparison]::OrdinalIgnoreCase)) 'ACL scope must be an owned descendant.'
    # Persist only the DACL we intentionally change. Set-Acl can also copy owner,
    # group and audit sections on privileged hosts. The full original SDDL still
    # has to match after restoration; no inheritance/control flag is ignored.
    $accessOnly=New-Object Security.AccessControl.DirectorySecurity
    $accessOnly.SetSecurityDescriptorBinaryForm($Acl.GetSecurityDescriptorBinaryForm(),[Security.AccessControl.AccessControlSections]::Access)
    $directory=New-Object IO.DirectoryInfo($Path)
    if($PSVersionTable.PSEdition -ceq 'Desktop'){$directory.SetAccessControl($accessOnly)}
    else{[IO.FileSystemAclExtensions]::SetAccessControl($directory,$accessOnly)}
}
function Set-OwnedDeny {
    param([string]$Path,[Security.AccessControl.FileSystemRights]$Rights)
    Assert-NoReparse $Path
    Assert-True ($Path.StartsWith($testRoot+'\',[StringComparison]::OrdinalIgnoreCase)) 'ACL scope must be an owned descendant.'
    $original=Get-Acl -LiteralPath $Path
    $record=[pscustomobject]@{path=$Path;acl=$original;sddl=$original.Sddl;restored=$false}
    $savedAcls.Add($record)
    $changed=Get-Acl -LiteralPath $Path
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule=New-Object Security.AccessControl.FileSystemAccessRule($identity,$Rights,[Security.AccessControl.InheritanceFlags]::None,[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Deny)
    $null=$changed.AddAccessRule($rule);Set-OwnedDirectoryAccess $Path $changed
    $record | Add-Member -NotePropertyName denied_sddl -NotePropertyValue (Get-Acl -LiteralPath $Path).Sddl
    return $record
}
function Restore-OwnedAcl {
    param([object]$Record)
    Set-OwnedDirectoryAccess $Record.path $Record.acl
    $observed=Get-Acl -LiteralPath $Record.path
    if(-not $report.Contains('acl_restoration_observations')){$report['acl_restoration_observations']=@()}
    $report.acl_restoration_observations += [pscustomobject]@{
        fixture=$Record.path.Substring($testRoot.Length+1)
        expected_sddl=$Record.sddl; denied_sddl=$Record.denied_sddl; observed_sddl=$observed.Sddl
        original_are_access_rules_protected=$Record.acl.AreAccessRulesProtected
        observed_are_access_rules_protected=$observed.AreAccessRulesProtected
    }
    Assert-True ($observed.Sddl -ceq $Record.sddl) 'Owned ACL restoration failed.'
    $Record.restored=$true
}
function Invoke-Real {
    param([string]$Tool,[string[]]$NativeArguments)
    $prior=$script:releaseProved;$script:releaseProved=$false
    $native=& $script:originalNative -ExecutablePath $Tool -Arguments $NativeArguments -TimeoutMilliseconds 120000
    if($native.ProcessReleased -and $native.PipeDrainCompleted){$script:releaseProved=$prior}
    $nativeRuns.Add([pscustomobject]@{operation='real native';status=$native.Status;exit_code=$native.ExitCode;process_released=$native.ProcessReleased;pipe_drain_completed=$native.PipeDrainCompleted;elapsed_ms=$native.ElapsedMilliseconds})
    Assert-True ($native.ProcessReleased -and $native.PipeDrainCompleted) 'Native release and pipe proof required.'
    return $native
}
function Invoke-Transaction {
    param([string]$Label)
    $output=Join-Path $outputRoot ($Label+'.mp3')
    $encode=New-AudioEncodeArguments -InputPath $source -Media $media -OutputPlan $plan -MetadataArguments @('-map_metadata','0','-id3v2_version','3')
    return Invoke-AudioOutputTransaction -SourcePath $source -OutputRoot $outputRoot -OutputPath $output -SourceDurationSeconds $media.DurationSeconds -BitrateKbps 64 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -EncodeArguments $encode -OutputPlan $plan
}
function Assert-Failed {
    param([object]$Result)
    Assert-True ($Result.Status -ne 'Success' -and -not (Test-Path -LiteralPath $Result.OutputPath)) 'Failure left final-looking output.'
    Assert-True ([string]::IsNullOrEmpty($Result.CleanupError)) 'Expected fault concealed cleanup failure.'
    if($Result.WorkingPath){Assert-True (-not (Test-Path -LiteralPath $Result.WorkingPath)) 'Failure left its owned partial.'}
}
$savedAcls=New-Object 'Collections.Generic.List[object]'
$report['acls_restored']=$false
$report['unavailable']=@('Genuine cloud/redirected/UNC/mapped-share conversion NOT_RUN: no authorized synthetic setup is available.','Physical disk exhaustion NOT_RUN: controlled ENOSPC encoder-result injection is used.')
try {
    Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
    Assert-True ([Environment]::Is64BitProcess -and [Console]::OutputEncoding.CodePage -eq 65001) 'Run x64 with explicit UTF8 CP65001 outer driver.'
    $report.source_before=Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    $created=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)
    Assert-True $created 'Exact TEMP root must be exclusively reserved.';$report.temp_exclusively_reserved=$true
    Write-NewText $ownerFile $ownerToken;Add-Fixture $ownerFile;$report.marker_create_new=$true
    $localData=New-Directory 'L';$childTemp=New-Directory 'T';$emptyPath=New-Directory 'E'
    $inputRoot=New-Directory 'I';$outputRoot=New-Directory 'O';$entryOutput=New-Directory 'P'
    $configRoot=New-Directory 'C';$configPath=Join-Path $configRoot 'absent.json'
    $appRoot=New-AppCopy 'A'
    $script:originalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
    $script:trackedNative={
        param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
            [object]$Cancellation=(Get-AudioCancellationContext),[scriptblock]$ProgressCallback,[object]$ProgressDurationSeconds,
            [object]$ProgressParser,[object]$ProgressCallbackState,[int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
        $prior=$script:releaseProved;$script:releaseProved=$false
        $native=& $script:originalNative @PSBoundParameters
        if($native.ProcessReleased -and $native.PipeDrainCompleted){$script:releaseProved=$prior}
        $nativeRuns.Add([pscustomobject]@{operation=$Operation;status=$native.Status;exit_code=$native.ExitCode;process_released=$native.ProcessReleased;pipe_drain_completed=$native.PipeDrainCompleted;elapsed_ms=$native.ElapsedMilliseconds})
        return $native
    }
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value $script:trackedNative
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    Assert-True ((Split-Path -Parent $ffmpeg) -ieq (Split-Path -Parent $ffprobe)) 'Supply existing matching pair directory.'
    $toolDirectory=Split-Path -Parent $ffmpeg
    foreach($path in @($ffmpeg,$ffprobe)){
        Assert-NoReparse $path;$version=Invoke-Real $path @('-version')
        Assert-True ($version.Status -ceq 'Completed' -and $version.ExitCode -eq 0) 'Version failed.'
        $report.tools += [pscustomobject]@{name=Split-Path -Leaf $path;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();version=$version.Stdout.Split([char]10)[0].Trim()}
    }
    $source=Join-Path $inputRoot '2024-01-02 Synthetic.mp3'
    $native=Invoke-Real $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=44100:duration=0.3','-c:a','libmp3lame','-b:a','64k',$source)
    Assert-True ($native.Status -ceq 'Completed' -and $native.ExitCode -eq 0) 'Synthetic fixture generation failed.';Add-Fixture $source
    $media=Get-AudioMediaInfo -Path $source -FfprobePath $ffprobe
    Assert-True ($media.Status -ceq 'Success' -and $media.NativeResult.ProcessReleased -and $media.NativeResult.PipeDrainCompleted) 'Real fixture probe failed.'
    $capabilities=Get-AudioEncoderSampleRates -FfmpegPath $ffmpeg
    Assert-True ($capabilities.Status -ceq 'Success' -and $capabilities.NativeResult.ProcessReleased -and $capabilities.NativeResult.PipeDrainCompleted) 'Real sample-rate query failed.'
    $plan=Get-AudioOutputPlan -Media $media -BitrateKbps 64 -SupportedSampleRates $capabilities.SampleRates
    Assert-True ($plan.Status -ceq 'Success') 'Fixture plan failed.'
    Invoke-Case 'real-read-only-app-directory-converts-to-explicit-owned-output' 'S11-A1/S11-A3' {
        param($case)
        $acl=Set-OwnedDeny $appRoot ([Security.AccessControl.FileSystemRights]::WriteData -bor [Security.AccessControl.FileSystemRights]::CreateDirectories)
        try {
            $probe=Join-Path $appRoot 'must-not-write.tmp';$denied=$false
            try{$handle=[IO.File]::Open($probe,[IO.FileMode]::CreateNew);$handle.Dispose()}catch [UnauthorizedAccessException]{$denied=$true}
            Assert-True ($denied -and -not (Test-Path -LiteralPath $probe)) 'Owned ACL must actually deny writes.'
            $code='& '+(Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1'))+' -InputFolder '+(Get-Literal $inputRoot)+' -OutputParent '+(Get-Literal $entryOutput)+' -ConfigPath '+(Get-Literal $configPath)+' -FfmpegDirectory '+(Get-Literal $toolDirectory)+"`r`nexit `$LASTEXITCODE"
            $result=Invoke-Child 'readonly-app' $code
            Assert-True ($result.exit_code -eq 0) ('Readonly app entry failed: '+$result.stdout+' '+$result.stderr)
            $published=@(Get-SafeTree $entryOutput|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.mp3'})
            Assert-True ($published.Count -eq 1) 'Require one actually published output.'
            $validation=Get-AudioOutputValidation -Path $published[0].FullName -SourceDurationSeconds $media.DurationSeconds -BitrateKbps 64 -FfmpegPath $ffmpeg -FfprobePath $ffprobe -OutputPlan $plan
            Assert-True ($validation.Status -ceq 'Success' -and $validation.ProcessReleased) 'Published output must pass production exact-shape/duration/full-decode validation.'
            Assert-True (-not (Test-Path -LiteralPath $configPath) -and @(Get-ChildItem -LiteralPath $appRoot -Force).Count -eq $runtimePaths.Count) 'Conversion wrote application/config state.'
            $case.actual_acl_write_denied=$true;$case.actual_entry_exit=0;$case.output_fully_decoded=$true
        }finally{Restore-OwnedAcl $acl}
    }
    Invoke-Case 'real-owned-config-parent-acl-refuses-save-with-existing-json-unchanged' 'S11-A1/S11-A3' {
        param($case)
        $lockedConfig=Join-Path $configRoot 'locked.json'
        Write-NewText $lockedConfig ('{"schema_version":1,"ffmpeg_directory":'+(ConvertTo-Json -InputObject $toolDirectory -Compress)+',"unrelated":"preserve"}');Add-Fixture $lockedConfig
        $readConfig=Read-AudioToolConfig -ConfigPath $lockedConfig
        Assert-True ($readConfig.schema_version -eq 1 -and $readConfig.ffmpeg_directory -ceq $toolDirectory) 'Owned config must parse before ACL denial.'
        $acl=Set-OwnedDeny $configRoot ([Security.AccessControl.FileSystemRights]::WriteData)
        try{
            $probe=Join-Path $configRoot 'must-not-save.tmp';$writeDenied=$false
            try{$handle=[IO.File]::Open($probe,[IO.FileMode]::CreateNew);$handle.Dispose()}catch [UnauthorizedAccessException]{$writeDenied=$true}
            Assert-True ($writeDenied -and -not (Test-Path -LiteralPath $probe)) 'Owned config parent ACL must actually deny new writes.'
            $denied=$false
            try{Save-AudioToolSelection -FfmpegDirectory $toolDirectory -ConfigPath $lockedConfig|Out-Null}catch{$denied=$true;$case.failure=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
            Assert-True ($denied -and $case.failure.Contains('locked.json.lock')) 'Deliberate save must fail at the exact denied config lock creation.'
            $selection=Resolve-AudioToolSelection -FfmpegDirectory $toolDirectory -ConfigPath $lockedConfig -ScriptDirectory $appRoot
            Assert-True ($selection.Origin -ceq 'Explicit' -and $selection.Ffmpeg.Path -ceq $ffmpeg) 'Failed remember must retain valid explicit current-run selection.'
            Assert-True (@(Get-ChildItem -LiteralPath $configRoot -Force).Count -eq 1) 'Failed save left lock/staging files.'
            $case.actual_acl_denial=$true;$case.explicit_selection_valid=$true
        }finally{Restore-OwnedAcl $acl}
    }
    Invoke-Case 'actual-busy-source-refuses-encode-and-cleans-owned-partial' 'S11-A1/S11-A3' {
        param($case)
        $held=[IO.File]::Open($source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
        try{
            $result=Invoke-Transaction 'busy';Assert-Failed $result
            Assert-True ($result.Status -ceq 'EncodeFailed' -and $result.EncoderResult.Status -ceq 'Completed' -and $result.EncoderResult.ExitCode -ne 0 -and $result.EncoderResult.ProcessReleased -and $result.EncoderResult.PipeDrainCompleted) 'Actual encoder must refuse exclusively held source and prove release.'
            $case.transaction_status=$result.Status;$case.native_exit=$result.EncoderResult.ExitCode;$case.actual_FileShare_None=$true
        }finally{$held.Dispose()}
    }
    Invoke-Case 'controlled-source-disappearance-after-real-plan-prevents-final-publication' 'S11-A1/S11-A3' {
        param($case)
        $heldPath=$source+'.held';[IO.File]::Move($source,$heldPath)
        try{
            $result=Invoke-Transaction 'disappeared';Assert-Failed $result
            Assert-True ($result.Status -ceq 'EncodeFailed' -and $result.EncoderResult.ExitCode -ne 0 -and $result.EncoderResult.ProcessReleased -and $result.EncoderResult.PipeDrainCompleted) 'Actual encoder must reject disappeared source and prove release.'
            $case.controlled_fixture_move_after_plan=$true;$case.real_native_failure=$true;$case.transaction_status=$result.Status
        }finally{[IO.File]::Move($heldPath,$source)}
    }
    Invoke-Case 'labelled-ENOSPC-result-injection-rejects-written-prefix-preserves-sibling' 'S11-A1/S11-A3' {
        param($case)
        $sentinel=Join-Path $outputRoot 'unrelated.mp3';Write-NewText $sentinel 'Owned unrelated synthetic final sentinel';Add-Fixture $sentinel
        $script:injectedCalls=0
        Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value {
            param([string]$ExecutablePath,[string[]]$Arguments,[object]$Cancellation)
            $script:injectedCalls++
            Assert-True ($ExecutablePath -ieq $ffmpeg -and $Arguments -contains '-b:a') 'Only encoder boundary is injected.'
            $working=$Arguments[$Arguments.Count-1]
            Assert-True ([IO.Path]::GetFileName($working) -cmatch '^\.AudioFileForPhone-[a-f0-9]{32}\.partial$') 'Injection needs production reserved working path.'
            $stream=[IO.File]::Open($working,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
            try{$bytes=[Text.Encoding]::ASCII.GetBytes('synthetic incomplete prefix');$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
            return [pscustomobject]@{Status='Completed';ExitCode=1;Stdout='';Stderr='controlled ENOSPC: No space left on device';Error='';StdoutTruncated=$false;StderrTruncated=$false;ProcessReleased=$true;PipeDrainCompleted=$true}
        }
        try{
            $result=Invoke-Transaction 'disk-full';Assert-Failed $result
            Assert-True ($result.Status -ceq 'EncodeFailed' -and $result.Error -match 'ENOSPC' -and $script:injectedCalls -eq 1) 'Write-error result must stop before validation/publication.'
            $case.injected_native_result=$true;$case.real_full_disk=$false;$case.incomplete_prefix_written=$true;$case.transaction_status=$result.Status
        }finally{Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value $script:trackedNative}
    }
    $report.copied_bytes_unchanged=$true;$report.status='pass';$exitCode=0
}catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
    if($null -ne $script:originalNative){Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value $script:originalNative}
    try{
        foreach($record in $savedAcls){if(-not $record.restored){Restore-OwnedAcl $record}}
        $report.acls_restored=@($savedAcls|Where-Object{-not $_.restored}).Count -eq 0
        $report.source_after=Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged=(($report.source_before|ConvertTo-Json -Depth 5 -Compress) -ceq ($report.source_after|ConvertTo-Json -Depth 5 -Compress))
        $report.parent_path_unchanged=$env:PATH -ceq $originalPath
        Assert-True ($report.source_unchanged -and $report.parent_path_unchanged) 'Source bytes or parent PATH changed.'
        if($created){
            $report.synthetic_after=Get-Inventory $fixtures.ToArray() $testRoot
            $report.synthetic_unchanged=(($report.synthetic_before|ConvertTo-Json -Depth 5 -Compress) -ceq ($report.synthetic_after|ConvertTo-Json -Depth 5 -Compress))
            Assert-True $report.synthetic_unchanged 'Owned runtime/driver/source/config/sentinel fixture bytes changed.'
            $report.descendant_release_proved=$releaseProved;Assert-True $releaseProved 'Cleanup refused because descendant release is unproved.'
            $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup root/name/parent refused.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup owner marker changed.'
            Get-SafeTree $resolved|Out-Null;[IO.Directory]::Delete($resolved,$true)
            $report.cleanup_verified=-not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    }catch{$report.status='fail';$exitCode=1;$report['integrity_or_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    $report.native_runs=$nativeRuns.ToArray();$report.completed_utc=[DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent;Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 20)
}
Write-Host ('S11 filesystem: '+$report.status+'; cases='+$report.cases.Count+'; cleanup='+$report.cleanup_verified+'; sources='+$report.source_unchanged+'/'+$report.synthetic_unchanged)
exit $exitCode
