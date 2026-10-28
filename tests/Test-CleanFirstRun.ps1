<#
S12 fresh-process clean-first-run tests. All mutable configuration, startup
records, exports, synthetic media and copied packages remain in one exclusively
reserved token-owned TEMP tree. Ordinary Music and owner configuration are never
opened. Unmodified production entry points run with separately sanitized CHILD environments.
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
    $leaf -cnotmatch "^S12-cleanfirst-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$") {
    throw 'Use a fresh S12-cleanfirst report for this host in the active evidence directory.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; choose a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'S12C-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s12-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'Collections.Generic.List[string]'
$nativeRuns = New-Object 'Collections.Generic.List[object]'
$runtimePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1',
    'AudioFileForPhone.Checks.ps1', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1',
    'AudioFileForPhone.bat', 'Check-AudioFileForPhone.ps1', 'Check-AudioFileForPhone.bat',
    'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ManagedSetup.ps1')
$sourcePaths = $runtimePaths + @('tests/Test-CleanFirstRun.ps1')
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = 'S12'; mode = 'real_windows_clean_first_run_fresh_process'
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
    param([string]$Label, [string]$Code, [AllowEmptyString()][string]$ChildPath = '', [int]$DeadlineMilliseconds = 120000)
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
    $info.EnvironmentVariables['PATH'] = $ChildPath
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info; $timer = [Diagnostics.Stopwatch]::StartNew()
    $priorRelease = $script:releaseProved; $script:releaseProved = $false
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
        $script:releaseProved = $priorRelease
        return $result
    } finally { $timer.Stop(); $process.Dispose() }
}
function Invoke-Real {
 param([string]$Tool,[string[]]$NativeArguments)
 $prior=$script:releaseProved;$script:releaseProved=$false
 $native=Invoke-AudioNativeProcess -ExecutablePath $Tool -Arguments $NativeArguments -TimeoutMilliseconds 120000
 if($native.ProcessReleased -and $native.PipeDrainCompleted){$script:releaseProved=$prior}
 $nativeRuns.Add([pscustomobject]@{operation='independent fixture/probe';status=$native.Status;exit_code=$native.ExitCode;process_released=$native.ProcessReleased;pipe_drain_completed=$native.PipeDrainCompleted})
 Assert-True ($native.Status -ceq 'Completed' -and $native.ExitCode -eq 0 -and $native.ProcessReleased -and $native.PipeDrainCompleted) 'Independent native check must complete drain and release.'
 return $native
}
function Get-AppCommand {
 param([string]$App,[string]$Config,[string]$Parent,[string]$Extra='')
 return '& '+(Get-Literal (Join-Path $App 'AudioFileForPhone.ps1'))+' -InputFolder '+(Get-Literal $inputRoot)+' -OutputParent '+(Get-Literal $Parent)+' -ConfigPath '+(Get-Literal $Config)+$Extra+"`r`nexit `$LASTEXITCODE"
}
function Assert-Conversion {
 param([object]$Child,[string]$Parent,[string]$Origin,[string]$ToolRoot)
 Assert-True ($Child.exit_code -eq 0) ('Fresh production conversion failed: '+$Child.stdout+$Child.stderr)
 $runs=@(Get-ChildItem -LiteralPath $Parent -Directory);Assert-True ($runs.Count -eq 1) 'Expected exactly one actual run.'
 $manifest=[IO.File]::ReadAllText((Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json'))|ConvertFrom-Json
 Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.policies.bitrate_kbps -eq 64) 'Actual manifest must prove one default64 conversion.'
 Assert-True ($manifest.tools.selection_origin -ceq $Origin -and $manifest.tools.ffmpeg.path -ceq (Join-Path $ToolRoot 'ffmpeg.exe') -and $manifest.tools.ffprobe.path -ceq (Join-Path $ToolRoot 'ffprobe.exe')) 'Production resolver must select exact expected origin and pair.'
 $output=Join-Path $runs[0].FullName $manifest.records[0].output_relative_path
 $probe=(Invoke-Real $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$output)).Stdout|ConvertFrom-Json
 $audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'})
 Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000 -and $probe.format.tags.artist -ceq 'S12 Synthetic Artist') 'Independent probe must prove exact64 MP3 and source artist.'
 $prior=$script:releaseProved;$script:releaseProved=$false
 $decode=Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL')
 if($decode.ProcessReleased -and $decode.PipeDrainCompleted){$script:releaseProved=$prior}
 Assert-True ($decode.Status -ceq 'Completed' -and $decode.ExitCode -eq 0 -and $decode.ProcessReleased -and $decode.PipeDrainCompleted -and $decode.TimeoutMilliseconds -eq 0) 'Independent complete decode remains unlimited and must release.'
 Assert-True (@(Get-SafeTree $Parent|Where-Object{-not $_.PSIsContainer -and $_.Name -match '\.partial$'}).Count -eq 0) 'Successful conversion cannot leave a partial.'
 return [pscustomobject]@{converted=1;bitrate_kbps=64;selection_origin=$Origin;independently_probed=$true;full_decode=$true;output_sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()}
}
try {
 Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
 Assert-True ([Environment]::Is64BitProcess -and [Console]::OutputEncoding.CodePage -eq 65001) 'Use x64 and inherited explicit UTF8 CP65001.'
 $report.source_before=Get-Inventory $sourcePaths $projectRoot
 . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
 Initialize-AudioDirectoryInterop
 $created=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)
 Assert-True $created 'Exact TEMP root must be exclusively reserved.';$report.temp_exclusively_reserved=$true
 Write-NewText $ownerFile $ownerToken;Add-Fixture $ownerFile;$report.marker_create_new=$true
 $localData=New-Directory 'L';$childTemp=New-Directory 'T';$inputRoot=New-Directory 'I';$configRoot=New-Directory 'C'
 $appRoot=New-AppCopy 'A'
 $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
 Assert-True ((Split-Path -Parent $ffmpeg) -ieq (Split-Path -Parent $ffprobe)) 'Supply explicit external fixture pair.'
 $toolDirectory=Split-Path -Parent $ffmpeg
 foreach($path in @($ffmpeg,$ffprobe)){
  Assert-NoReparse $path;$identity=Invoke-Real $path @('-version')
  $report.tools += [pscustomobject]@{name=Split-Path -Leaf $path;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();version=$identity.Stdout.Split([char]10)[0].Trim()}
 }
 $source=Join-Path $inputRoot '2024-01-02 Synthetic.mp3'
 $null=Invoke-Real $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=44100:duration=0.3','-c:a','libmp3lame','-metadata','artist=S12 Synthetic Artist',$source)
 Add-Fixture $source
 $report['fixture_tools_used_by_absolute_path_only']=$true;$report['child_environment_sanitized']=$true;$report['fresh_process_count']=0
 $paths=@(@{label='empty';value=''},@{label='stale';value=(Join-Path $testRoot 'Missing tools')},@{label='malformed';value=('"relative tools";;'+(Join-Path $testRoot 'Missing tools')+';.')})
 foreach($row in $paths){
  Invoke-Case ('fresh-no-tools-'+$row.label+'-PATH-refuses-with-repair') 'S12-A2' {
   param($case)
   $config=Join-Path $configRoot ($row.label+'-absent.json');$parent=Join-Path $testRoot ($row.label+'-output')
   Assert-True (-not (Test-Path -LiteralPath $config) -and -not (Test-Path -LiteralPath (Join-Path $appRoot 'ffmpeg.exe')) -and -not (Test-Path -LiteralPath (Join-Path $appRoot 'ffprobe.exe'))) 'Fresh missing-tool/config preconditions must hold independently.'
   $child=Invoke-Child ('Missing-'+$row.label) (Get-AppCommand $appRoot $config $parent) -ChildPath $row.value;$report.fresh_process_count++
   Assert-True ($child.exit_code -eq 1 -and -not (Test-Path -LiteralPath $parent) -and -not (Test-Path -LiteralPath $config)) 'Missing tools must fail before output/config creation.'
   Assert-True (($child.stdout+$child.stderr) -match 'Setup-AudioFileForPhone.ps1' -and ($child.stdout+$child.stderr) -match 'FfmpegDirectory') 'Missing tools must name real setup/selection repair.'
   $case.PATH=$row.label;$case.exit_code=$child.exit_code;$case.config_initially_absent=$true;$case.app_local_pair_absent=$true;$case.output_absent=$true;$case.fresh_process=$true
  }
 }
 $rememberedConfig=Join-Path $configRoot 'remembered.json'
 Invoke-Case 'explicit-external-selection-converts-on-empty-child-PATH-without-saving' 'S12-A2' {
  param($case)
  $parent=Join-Path $testRoot 'explicit-output';$config=Join-Path $configRoot 'explicit-absent.json'
  $child=Invoke-Child 'Explicit' (Get-AppCommand $appRoot $config $parent (' -FfmpegDirectory '+(Get-Literal $toolDirectory)))
  $report.fresh_process_count++;$case.conversion=Assert-Conversion $child $parent 'Explicit' $toolDirectory
  Assert-True (-not (Test-Path -LiteralPath $config)) 'Explicit selection cannot silently save settings.'
  $case.PATH='empty';$case.config_created=$false;$case.fresh_process=$true
 }
 Invoke-Case 'production-separate-setup-remembers-only-the-explicit-external-selection' 'S12-A2' {
  param($case)
  $command='& '+(Get-Literal (Join-Path $appRoot 'Setup-AudioFileForPhone.ps1'))+' -FfmpegDirectory '+(Get-Literal $toolDirectory)+' -ConfigPath '+(Get-Literal $rememberedConfig)+" -Remember -NonInteractive`r`nexit `$LASTEXITCODE"
  $child=Invoke-Child 'Remember' $command;$report.fresh_process_count++
  Assert-True ($child.exit_code -eq 0 -and (Read-AudioToolConfig -ConfigPath $rememberedConfig).ffmpeg_directory -ceq $toolDirectory) 'Actual setup must validate and deliberately save exact selection.'
  Add-Fixture $rememberedConfig;$case.PATH='empty';$case.production_saved_selection=$true;$case.fresh_process=$true;$case.exit_code=$child.exit_code
 }
 Invoke-Case 'fresh-saved-selection-converts-without-provisioned-PATH-or-config-mutation' 'S12-A2' {
  param($case)
  $before=(Get-FileHash -LiteralPath $rememberedConfig).Hash;$parent=Join-Path $testRoot 'saved-output'
  $child=Invoke-Child 'Saved' (Get-AppCommand $appRoot $rememberedConfig $parent);$report.fresh_process_count++
  $case.conversion=Assert-Conversion $child $parent 'Saved' $toolDirectory
  Assert-True ((Get-FileHash -LiteralPath $rememberedConfig).Hash -ceq $before) 'Fresh saved selection must not mutate config.'
  $case.PATH='empty';$case.config_unchanged=$true;$case.fresh_process=$true
 }
 Invoke-Case 'fresh-app-local-pair-converts-on-malformed-child-PATH-with-no-config' 'S12-A2' {
  param($case)
  foreach($path in @($ffmpeg,$ffprobe)){$copy=Join-Path $appRoot (Split-Path -Leaf $path);[IO.File]::Copy($path,$copy,$false);Add-Fixture $copy}
  $config=Join-Path $configRoot 'local-absent.json';$parent=Join-Path $testRoot 'local-output'
  $child=Invoke-Child 'AppLocal' (Get-AppCommand $appRoot $config $parent) -ChildPath $paths[2].value;$report.fresh_process_count++
  $case.conversion=Assert-Conversion $child $parent 'AppLocal' $appRoot
  Assert-True (-not (Test-Path -LiteralPath $config)) 'App-local selection must not save config.'
  $case.PATH='malformed';$case.config_created=$false;$case.fresh_process=$true
 }
 $report.copied_bytes_unchanged=$true;$report.status='pass';$exitCode=0
}catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
 try{
  $report.source_after=Get-Inventory $sourcePaths $projectRoot
  $report.source_unchanged=(($report.source_before|ConvertTo-Json -Depth 5 -Compress) -ceq ($report.source_after|ConvertTo-Json -Depth 5 -Compress))
  $report.parent_path_unchanged=$env:PATH -ceq $originalPath
  Assert-True ($report.source_unchanged -and $report.parent_path_unchanged) 'Source bytes or parent PATH changed.'
  if($created){
   $report.synthetic_after=Get-Inventory $fixtures.ToArray() $testRoot
   $report.synthetic_unchanged=(($report.synthetic_before|ConvertTo-Json -Depth 5 -Compress) -ceq ($report.synthetic_after|ConvertTo-Json -Depth 5 -Compress))
   Assert-True $report.synthetic_unchanged 'Owned runtime/driver/source/config bytes changed.'
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
Write-Host ('S12 clean-first-run: '+$report.status+'; cases='+$report.cases.Count+'; fresh_processes='+$report.fresh_process_count+'; cleanup='+$report.cleanup_verified+'; sources='+$report.source_unchanged+'/'+$report.synthetic_unchanged)
exit $exitCode
