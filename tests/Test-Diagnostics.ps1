<#
T14 persistent local diagnostics and JSON manifest evidence. Only synthetic media,
metadata, controlled faults and retained child handles use one exclusive token-
marked TEMP tree. Reports are create-new; ordinary Music is never accessed.
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
$testName = 'T14D-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t14-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false; $descendantReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Diagnostics.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T14|T15|T16|T18)-diagnostics-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw "EvidencePath '$evidenceFullPath' must name fresh T14/T15/T16/T18-diagnostics-ps51/ps7-attempt/finalN.json directly in '$evidenceParent'."
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'persistent_local_diagnostics_json_manifest_and_record_faults'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    owned_temp_root = $testRoot; owner_marker_sha256 = $null
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_entry_bytes_unchanged = $false
    ordinary_music_access = $false; physical_manual_evidence = $false
    native_runs = @(); entry_runs = @(); cases = @(); children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
}
$exitCode = 1
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse fixture/ancestor.'
        $item = $item.Parent
    }
}
function Get-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $items = New-Object 'System.Collections.Generic.List[object]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Refusing reparse inside exact owned tree.'
            $items.Add($item); if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $items.ToArray()
}
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$Utf8Bom)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { if($Utf8Bom){$preamble=[Text.Encoding]::UTF8.GetPreamble();$stream.Write($preamble,0,$preamble.Length)};$bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_)).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() } })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path); $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-OwnedNative {
    param([string]$Tool, [string[]]$NativeArguments, [object]$Parser = $null, [scriptblock]$Callback = $null,
          [object]$Duration = $null, [int]$StdoutLimit = 1048576, [int]$StderrLimit = 65536,
          [object]$Cancellation = $null, [string]$ExpectedStatus = 'Completed', [object]$ExpectedCode = 0)
    $prior = $script:descendantReleaseProved; $script:descendantReleaseProved = $false
    $ownsContext = $null -eq $Cancellation
    $context = if ($ownsContext) { New-AudioCancellationContext } else { $Cancellation }
    $deadline = New-Object T14Support.Deadline($context, 180000)
    try {
        $parameters = @{ ExecutablePath = $Tool; Arguments = $NativeArguments; Cancellation = $context; MaxStdoutChars = $StdoutLimit; MaxStderrChars = $StderrLimit }
        if ($null -ne $Parser) { $parameters.ProgressParser = $Parser }
        if ($null -ne $Callback) { $parameters.ProgressCallback = $Callback; $parameters.ProgressDurationSeconds = $Duration }
        $native = Invoke-AudioNativeProcess @parameters
        if ($native.ProcessReleased) { $script:descendantReleaseProved = $prior }
        $report.native_runs += [pscustomobject]@{ executable = $Tool; arguments = @($NativeArguments | ForEach-Object { $_.Replace($testRoot, '<OWNED_TEMP>') }); status = $native.Status; exit_code = $native.ExitCode; process_released = $native.ProcessReleased; deadline_requested = $deadline.TimedOut; duration_ms = $native.DurationMilliseconds }
        Assert-True (-not $deadline.TimedOut -and $native.Status -ceq $ExpectedStatus -and $native.ExitCode -eq $ExpectedCode -and $native.ProcessReleased) ('Native fixture/check failed: ' + $native.Status + '/' + $native.ExitCode + ' ' + $native.Error + ' ' + $native.Stderr)
        return $native
    } finally { $deadline.Dispose(); if ($ownsContext) { $context.Dispose() } }
}
function Get-OwnedMedia {
    param([string]$Path)
    $prior=$script:descendantReleaseProved;$script:descendantReleaseProved=$false
    $media=Get-AudioMediaInfo -Path $Path -FfprobePath $ffprobe -Cancellation $null
    if($null -ne $media.NativeResult -and $media.NativeResult.ProcessReleased){$script:descendantReleaseProved=$prior}
    Assert-True ($media.Status -ceq 'Success' -and $media.NativeResult.ProcessReleased) 'Owned source media probe must complete with positive release proof.'
    return $media
}
function Assert-Decoded {
    param([string]$Path,[double]$ExpectedDuration)
    $probe=(Invoke-OwnedNative $ffprobe @('-v','error','-show_entries','stream=codec_type,codec_name,bit_rate,duration:stream_tags=title,artist,album','-of','json',$Path)).Stdout|ConvertFrom-Json
    $audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'})
    Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Published output must independently probe as one 64 kbps MP3 audio stream.'
    $seconds=[double]::Parse([string]$audio[0].duration,[Globalization.CultureInfo]::InvariantCulture)
    Assert-True ([math]::Abs($seconds-$ExpectedDuration) -le 0.35) 'Independent output duration must match existing source tolerance.'
    Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-xerror','-i',$Path,'-map','0:a:0','-f','null','NUL')|Out-Null
    return [pscustomobject]@{duration_seconds=$seconds;byte_length=(Get-Item -LiteralPath $Path).Length;sha256=(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant();fully_decoded=$true}
}
function New-AppCopy {
    param([string]$Label)
    $app=Join-Path $testRoot ('A-'+$Label);[IO.Directory]::CreateDirectory($app)|Out-Null
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){$copy=Join-Path $app $name;[IO.File]::Copy((Join-Path $projectRoot $name),$copy,$false);Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'App/helper copies must start byte-identical.'}
    # All substitutions are confined to an append-only helper copy. The actual
    # entry bytes and native ownership/disposal behavior remain intact.
    $audit=@'
$script:T14OriginalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
$script:T14OriginalManifestWriter=(Get-Item -LiteralPath Function:Write-AudioRunManifest).ScriptBlock
$script:T14OriginalContext=(Get-Item -LiteralPath Function:New-AudioCancellationContext).ScriptBlock
function New-AudioCancellationContext {
    param([switch]$CaptureConsole)
    $context=& $script:T14OriginalContext @PSBoundParameters
    if($global:T14Mode -ceq 'startup-cancel'){$context.Request();$global:T14StartupCancelled=$true}
    return $context
}
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
          [object]$Cancellation=(Get-AudioCancellationContext),[object]$ProgressParser=$null,[scriptblock]$ProgressCallback=$null,[object]$ProgressDurationSeconds=$null,[object]$ProgressCallbackState=$null)
    $proof=[pscustomobject]@{process_released=$false;status='not returned';exit_code=$null;cancelled_encoder=$false;owned_partial_seen=$false};$global:T14NativeProofs.Add($proof)
    $nativeParameters=@{};foreach($key in $PSBoundParameters.Keys){$nativeParameters[$key]=$PSBoundParameters[$key]}
    $working=@($Arguments|Where-Object{$_.EndsWith('.partial',[StringComparison]::Ordinal)})
    if($global:T14Mode -ceq 'encoder-fail' -and $Arguments -contains '-y'){$nativeParameters.Arguments=@($Arguments[0..($Arguments.Length-2)])+@('-af','T14_NoSuchAudioFilter',$Arguments[-1])}
    if($global:T14Mode -ceq 'output-probe-fail' -and $working.Count -gt 0 -and $Arguments -contains '-show_entries'){$nativeParameters.Arguments=@('-T14_NoSuchProbeOption')+$Arguments}
    if($global:T14Mode -ceq 'output-decode-fail' -and $working.Count -gt 0 -and $Arguments -contains 'null'){$changed=[string[]]$Arguments.Clone();$filter=[array]::IndexOf($changed,'-af');if($filter -ge 0){$changed[$filter+1]='T14_NoSuchDecodeFilter'};$nativeParameters.Arguments=$changed}
    if($global:T14Mode -ceq 'large-probe-fail' -and $Arguments -contains '-select_streams'){$nativeParameters.ExecutablePath=$global:T14Child;$nativeParameters.Arguments=@('flood')}
    $timer=$null
    try {
        if($global:T14Mode -like 'cancel-*' -and $Arguments -contains '-y' -and @($Arguments|Where-Object{$_ -like '*Second*'}).Count -gt 0){
            $proof.cancelled_encoder=$true;$proof.owned_partial_seen=($working.Count -eq 1 -and [IO.File]::Exists($working[0]));$nativeParameters.Arguments=@('-re')+$Arguments
            $timer=New-Object T14Support.Deadline($Cancellation,500)
        }
        $result=& $script:T14OriginalNative @nativeParameters
        $proof.process_released=[bool]$result.ProcessReleased;$proof.status=$result.Status;$proof.exit_code=$result.ExitCode
        return $result
    }finally{if($null -ne $timer){$timer.Dispose()}}
}
function Write-AudioRunManifest {
    param([object]$Manifest,[string]$Checkpoint)
    $global:T14ManifestWrites.Add([pscustomobject]@{checkpoint=$Checkpoint;status=$Manifest.Data.run.status;converted=$Manifest.Data.totals.converted;failed=$Manifest.Data.totals.failed;cancelled=$Manifest.Data.totals.cancelled})
    if(($global:T14Mode -ceq 'manifest-initial' -and $Checkpoint -ceq 'Initial') -or
       ($global:T14Mode -ceq 'manifest-boundary' -and $Checkpoint -ceq 'FileBoundary') -or
       ($global:T14Mode -ceq 'manifest-final' -and $Checkpoint -ceq 'Final') -or
       ($global:T14Mode -ceq 'cancel-manifest' -and $Manifest.Data.run.status -ceq 'Cancelled')){throw ('controlled T14 '+$global:T14Mode+' persistence failure')}
    if($global:T14Mode -ceq 'manifest-existing' -and $Checkpoint -ceq 'Initial'){
        $stream=New-Object IO.FileStream($Manifest.Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$bytes=[Text.Encoding]::UTF8.GetBytes('Synthetic existing manifest sentinel');$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
    }
    $global:T14CurrentCheckpoint=$Checkpoint;$global:T14CurrentManifestStatus=$Manifest.Data.run.status
    try{& $script:T14OriginalManifestWriter -Manifest $Manifest -Checkpoint $Checkpoint}
    finally{$global:T14CurrentCheckpoint=$null;$global:T14CurrentManifestStatus=$null}
}
'@

    [IO.File]::AppendAllText((Join-Path $app 'AudioFileForPhone.Helpers.ps1'),"`r`n"+$audit,[Text.Encoding]::UTF8)
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){Add-Fixture (Join-Path $app $name)}
    return Join-Path $app 'AudioFileForPhone.ps1'
}
function Invoke-Entry {
    param([string]$Label,[string]$InputPath,[string]$OutputParent,[string]$Mode='normal',[string]$Artist='',[string]$Album='')
    $entry=New-AppCopy $Label;$driver=Join-Path $testRoot ($Label+'-driver.ps1')
    $prefix=@('$ErrorActionPreference=''Stop''','$ProgressPreference=''SilentlyContinue''','[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$env:PATH='+(Get-Literal (Split-Path -Parent $ffmpeg))+'+'';''+$env:PATH'),('$global:T14Mode='+(Get-Literal $Mode)),('$global:T14Child='+(Get-Literal $childExe)),
        '$global:T14NativeProofs=New-Object ''System.Collections.Generic.List[object]''','$global:T14ManifestWrites=New-Object ''System.Collections.Generic.List[object]''',
        '$global:T14GuardFaultInjected=$false;$global:T14StartupCancelled=$false',
        ('Add-Type -TypeDefinition '+(Get-Literal $supportSource)))
    $logFault=@'
function global:Add-Content {
    [CmdletBinding()]
    param([string]$LiteralPath,[Parameter(ValueFromPipeline=$true)][object]$Value,[string]$Encoding)
    process {
        $text=[string]$Value
        if(($global:T14Mode -ceq 'log-initial' -and $text.StartsWith('==== AudioFileForPhone Log ====')) -or
           ($global:T14Mode -ceq 'log-boundary' -and $text -match '^\[OK\] ') -or
           ($global:T14Mode -ceq 'log-final' -and $text -match '^\[INFO\] Summary:') -or
           ($global:T14Mode -ceq 'cancel-log' -and $text -match '^\[CANCELLED\] ')){throw ('controlled T14 '+$global:T14Mode+' persistence failure')}
        Microsoft.PowerShell.Management\Add-Content @PSBoundParameters
    }
}
function global:Read-Host {param($Prompt);throw 'T14 unexpected interactive prompt'}
function global:New-Object {
    [CmdletBinding()]
    param([Parameter(Position=0)][string]$TypeName,[Parameter(Position=1)][object[]]$ArgumentList,[hashtable]$Property)
    if($global:T14Mode -ceq 'manifest-guard-reopen' -and -not $global:T14GuardFaultInjected -and
       $global:T14CurrentCheckpoint -ceq 'Final' -and $global:T14CurrentManifestStatus -ceq 'Completed' -and
       $TypeName -ceq 'IO.FileStream' -and $ArgumentList.Count -ge 2 -and
       [IO.Path]::GetFileName([string]$ArgumentList[0]) -ceq 'AudioFileForPhone_manifest.json' -and $ArgumentList[1] -eq [IO.FileMode]::Open){
        $global:T14GuardFaultInjected=$true;throw 'controlled T14 published manifest guard reopen failure'
    }
    Microsoft.PowerShell.Utility\New-Object @PSBoundParameters
}
'@
    $command='& '+(Get-Literal $entry)+' -InputFolder '+(Get-Literal $InputPath)+' -OutputParent '+(Get-Literal $OutputParent)+' -BitrateKbps 64 -MaxBaseLength 40'
    if($Artist){$command+=' -Artist '+(Get-Literal $Artist)};if($Album){$command+=' -Album '+(Get-Literal $Album)}
    $text=(@($prefix)+@($logFault,'$global:LASTEXITCODE=$null',($command+' *>&1 | ForEach-Object {[Console]::Out.WriteLine([string]$_)}'),
        'foreach($proof in $global:T14NativeProofs){[Console]::Out.WriteLine(''[NATIVEPROOF] ''+($proof|ConvertTo-Json -Compress))}',
        'foreach($write in $global:T14ManifestWrites){[Console]::Out.WriteLine(''[MANIFESTWRITE] ''+($write|ConvertTo-Json -Compress))}',
        '[Console]::Out.WriteLine(''[ENTRYAUDIT] ''+(@{guard_fault_injected=$global:T14GuardFaultInjected;startup_cancelled=$global:T14StartupCancelled}|ConvertTo-Json -Compress))',
        'if($null -eq $global:LASTEXITCODE){throw ''Entry omitted exit code''};exit $global:LASTEXITCODE')) -join "`n"
    Write-NewText $driver $text -Utf8Bom;Add-Fixture $driver
    $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$shellPath;$info.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "'+$driver+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$info.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info
    $child=[pscustomobject]@{process=$process;stdout_task=$null;stderr_task=$null;started=$false;disposed=$false;timed_out=$false};$children.Add($child)
    $prior=$script:descendantReleaseProved;$script:descendantReleaseProved=$false
    Assert-True ($process.Start()) 'Owned diagnostic entry host must start.';$child.started=$true
    $child.stdout_task=$process.StandardOutput.ReadToEndAsync();$child.stderr_task=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(120000)){$child.timed_out=$true;throw 'Synthetic diagnostics host timed out; preserve scope because descendants are unproved.'}
    if(-not $child.stdout_task.Wait(5000) -or -not $child.stderr_task.Wait(5000)){$child.timed_out=$true;throw 'Owned host pipes did not join; preserve scope.'}
    $result=[pscustomobject]@{exit_code=$process.ExitCode;text=$child.stdout_task.GetAwaiter().GetResult()+"`n"+$child.stderr_task.GetAwaiter().GetResult();entry=$entry}
    $process.Dispose();$child.disposed=$true
    $proofs=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[NATIVEPROOF\] '}|ForEach-Object{$_.Substring(14)|ConvertFrom-Json})
    $writes=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[MANIFESTWRITE\] '}|ForEach-Object{$_.Substring(16)|ConvertFrom-Json})
    $result|Add-Member -NotePropertyName native_release_proofs -NotePropertyValue $proofs;$result|Add-Member -NotePropertyName manifest_write_attempts -NotePropertyValue $writes
    $entryAudit=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[ENTRYAUDIT\] '}|ForEach-Object{$_.Substring(13)|ConvertFrom-Json})
    $result|Add-Member -NotePropertyName entry_audit -NotePropertyValue $entryAudit
    $report.entry_runs += [pscustomobject]@{label=$Label;mode=$Mode;exit_code=$result.exit_code;console=$result.text.Replace($testRoot,'<OWNED_TEMP>');native_release_proofs=$proofs;manifest_write_attempts=$writes;entry_audit=$entryAudit;host_wait_exit_and_pipe_join_proved=$true;host_disposed=$child.disposed}
    if($result.exit_code -in @(0,1,2,130) -and $result.text -match '\[RESULT\] status=' -and $proofs.Count -gt 0 -and @($proofs|Where-Object{-not $_.process_released}).Count -eq 0){$script:descendantReleaseProved=$prior}
    return $result
}
function Get-RunArtifacts {
    param([string]$Parent,[switch]$AllowForeignManifest)
    $runs=@(Get-ChildItem -LiteralPath $Parent -Force|Where-Object{$_.PSIsContainer -and (Test-Path -LiteralPath (Join-Path $_.FullName '.AudioFileForPhone-output.json'))})
    Assert-True ($runs.Count -eq 1) 'Exactly one fresh recognized run must exist in owned destination.'
    $root=$runs[0].FullName;$tree=@(Get-SafeTree $root)
    Assert-True (@($tree|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.partial'}).Count -eq 0) 'Released native and manifest operations must leave no final-looking or sibling partial.'
    $manifestPath=Join-Path $root 'AudioFileForPhone_manifest.json';$data=$null
    if([IO.File]::Exists($manifestPath) -and -not $AllowForeignManifest){$data=[IO.File]::ReadAllText($manifestPath)|ConvertFrom-Json}
    $logPath=Join-Path $root 'AudioFileForPhone_log.txt';$log=if([IO.File]::Exists($logPath)){[IO.File]::ReadAllText($logPath)}else{''}
    return [pscustomobject]@{root=$root;manifest_path=$manifestPath;data=$data;log=$log;outputs=@($tree|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.mp3'})}
}
function Assert-ManifestTotals {
    param([object]$Artifacts,[string]$InputPath,[int]$Supported,[int]$Converted,[int]$Failed,[int]$Cancelled=0,[int]$NotProcessed=0,[int]$Excluded=0,[int]$Unsupported=0)
    $data=$Artifacts.data;Assert-True ($null -ne $data -and $data.schema_version -eq 1 -and $data.kind -ceq 'AudioFileForPhone.RunManifest' -and @($data.records).Count -eq $Supported) 'JSON must contain exactly one row per supported snapshot candidate.'
    $totals=$data.totals
    Assert-True ($totals.supported -eq $Supported -and $totals.converted -eq $Converted -and $totals.failed -eq $Failed -and $totals.cancelled -eq $Cancelled -and $totals.not_processed -eq $NotProcessed -and $totals.processed -eq ($Converted+$Failed) -and $totals.not_completed -eq ($Cancelled+$NotProcessed) -and $Supported -eq ($Converted+$Failed+$Cancelled+$NotProcessed)) 'Exclusive outcome totals and legacy not-completed count must reconcile.'
    Assert-True ($totals.scan_excluded -eq $Excluded -and $totals.unsupported -eq $Unsupported -and @($data.scan_exclusions).Count -eq $Excluded) 'Scan exclusions and unsupported entries must remain separate.'
    $inputBytes=[long]0;$outputBytes=[long]0;$inputDuration=[double]0;$outputDuration=[double]0;$unknown=0;$decoded=@()
    foreach($row in $data.records){$source=Join-Path $InputPath $row.source_relative_path;Assert-True ([IO.File]::Exists($source) -and [long]$row.input_bytes -eq (Get-Item -LiteralPath $source).Length) 'Every row must map exact source and observed byte length.';$inputBytes+=[long]$row.input_bytes
        if($null -ne $row.input_duration_seconds){$inputDuration+=[double]$row.input_duration_seconds}else{$unknown++}
        if($row.status -ceq 'Converted'){$target=Join-Path $Artifacts.root $row.output_relative_path;Assert-True ([IO.File]::Exists($target) -and [long]$row.output_bytes -eq (Get-Item -LiteralPath $target).Length -and $row.output_duration_seconds -gt 0 -and $row.input_duration_seconds -gt 0 -and $row.code -ceq 'Success') 'Converted mapping must be actual validated publication with measured duration/bytes.';$outputBytes+=[long]$row.output_bytes;$outputDuration+=[double]$row.output_duration_seconds;$independent=Assert-Decoded $target $row.input_duration_seconds;Assert-True ([math]::Abs($independent.duration_seconds-$row.output_duration_seconds) -lt 0.000001) 'Manifest output duration must match independently observed selected audio probe duration.';$decoded+=$independent
        }else{Assert-True ($row.output_bytes -eq 0 -and $null -eq $row.output_duration_seconds -and -not [IO.File]::Exists((Join-Path $Artifacts.root $row.output_relative_path))) 'Unpublished candidate must have no final and no invented output measurement.'}
        Assert-True ($row.elapsed_seconds -ge 0 -and $row.reason.Length -le 2048) 'Row timings/reasons must remain valid and bounded to2048 total characters including any truncation suffix.'
        if($row.status -ceq 'Converted'){Assert-True ($row.decoded_duration_seconds -gt 0 -and [math]::Abs($row.decoded_duration_seconds-$row.input_duration_seconds) -le 0.35) 'Converted row must record actual full-decode duration within the source tolerance.'}
    }
    Assert-True ($totals.input_bytes -eq $inputBytes -and $totals.output_bytes -eq $outputBytes -and [math]::Abs($totals.input_duration_seconds-$inputDuration) -lt 0.000001 -and [math]::Abs($totals.output_duration_seconds-$outputDuration) -lt 0.000001 -and $totals.input_duration_unknown_count -eq $unknown -and $data.run.elapsed_seconds -ge 0) 'Actual byte/duration totals and unknown measurements must reconcile.'
    Assert-True ($Artifacts.outputs.Count -eq $Converted) 'Manifest conversions must equal actual published output count.'
    return [pscustomobject]@{totals=$totals;decoded_outputs=$decoded;records=$data.records;run_status=$data.run.status;exit_code=$data.run.exit_code;elapsed_seconds=$data.run.elapsed_seconds}
}
function Save-CaseRun {
    param([object]$Case,[object]$Result,[object]$Artifacts)
    $Case['actual_exit_code']=$Result.exit_code;$Case['console_diagnostics']=$Result.text.Replace($testRoot,'<OWNED_TEMP>')
    $Case['native_release_proofs']=$Result.native_release_proofs;$Case['manifest_write_attempts']=$Result.manifest_write_attempts
    $Case['local_log_excerpt']=$Artifacts.log.Replace($testRoot,'<OWNED_TEMP>')
    if($null -ne $Artifacts.data){$Case['manifest']=$Artifacts.data|ConvertTo-Json -Depth 12 -Compress;$Case['manifest']=$Case['manifest'].Replace($testRoot.Replace('\','\\'),'<OWNED_TEMP>').Replace($testRoot,'<OWNED_TEMP>')}
}
$supportSource=@'
using System;
using System.Text;
using System.Threading;
namespace T14Support {
    public sealed class Deadline : IDisposable {
        private readonly Timer timer;private int timedOut;
        public bool TimedOut {get{return Interlocked.CompareExchange(ref timedOut,0,0)!=0;}}
        public Deadline(object context,int milliseconds){timer=new Timer(o=>{Interlocked.Exchange(ref timedOut,1);context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite);}
        public void Dispose(){timer.Dispose();}
    }
    public static class Child {
        public static int Main(string[] args){Console.OutputEncoding=new UTF8Encoding(false);Console.Out.Write("STDOUT_SHOULD_NOT_PERSIST\n"+new string('O',1100000));Console.Error.Write("T14 bounded probe root cause, quoted \"failure\", =SUM(1,2)\r\n"+new string('E',131072));return 7;}
    }
}
'@
function New-InputFixture {
    param([string]$Label,[string[]]$Extensions=@('mp3'),[switch]$CancellationSet)
    $folder=Join-Path $testRoot ('I-'+$Label);[IO.Directory]::CreateDirectory($folder)|Out-Null
    for($index=0;$index -lt $Extensions.Count;$index++){
        $extension=$Extensions[$index];$descriptor=if($CancellationSet){@('First','Second','Third')[$index]}else{'Item'+$index}
        $name='2024-01-'+($index+1).ToString('00')+' '+$descriptor+', '+[char]0x00e9+[char]0x4e2d+' =SUM(1,2).'+$extension
        $source=if($CancellationSet -and $index -eq 1){$slowSeed}else{$seeds[$extension]};$target=Join-Path $folder $name
        [IO.File]::Copy($source,$target,$false);Add-Fixture $target
    }
    return $folder
}
function New-OutputParent {
    param([string]$Label)
    $folder=Join-Path $testRoot ('O-'+$Label);[IO.Directory]::CreateDirectory($folder)|Out-Null
    $sentinel=Join-Path $folder 'Synthetic existing sibling.mp3';Write-NewText $sentinel 'Synthetic sibling sentinel';Add-Fixture $sentinel
    return $folder
}
function Get-NativeSummaries {
    param([string]$Log)
    return @($Log -split '\r?\n'|Where-Object{$_ -match '^\[DEBUG\] \[NATIVE\] '}|ForEach-Object{$_.Substring(17)|ConvertFrom-Json})
}
function Assert-ConsoleCounts {
    param([object]$Result,[int]$Total,[int]$Converted,[int]$Failed,[int]$NotCompleted)
    $expected='total='+$Total+'; processed='+($Converted+$Failed)+'; converted='+$Converted+'; failed='+$Failed+'; not_processed='+$NotCompleted+';'
    Assert-True ($Result.text.Contains($expected)) 'Console must preserve actual committed counts even if required persistence fails.'
}
try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop;Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
    $ownedRootCreated=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved=$true;Write-NewText $ownerFile $ownerToken;$report.marker_create_new=$true
    $report.owner_marker_sha256=(Get-FileHash -LiteralPath $ownerFile).Hash.ToLowerInvariant();$report.source_before=Get-SourceInventory
    Add-Type -TypeDefinition $supportSource
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools']=@($ffmpeg,$ffprobe|ForEach-Object{[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant();version=(Invoke-OwnedNative $_ @('-version')).Stdout.Split([char]10)[0].Trim()}})
    $toolInfo=[pscustomobject]@{Ffmpeg=$report.tools[0];Ffprobe=$report.tools[1]}
    $support=Join-Path $testRoot 'Child.cs';Write-NewText $support $supportSource;Add-Fixture $support
    $childExe=Join-Path $testRoot 'Child.exe';$compiler=Join-Path ([Environment]::GetFolderPath('Windows')) 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    $compilerDirectory=Split-Path -Parent $compiler;$references=@('mscorlib.dll','System.dll','System.Core.dll')|ForEach-Object{'/reference:'+(Join-Path $compilerDirectory $_)}
    Invoke-OwnedNative $compiler (@('/nologo','/noconfig','/nostdlib+','/target:exe','/main:T14Support.Child',('/out:'+$childExe))+$references+@($support))|Out-Null;Add-Fixture $childExe
    # Explicit code points keep Unicode expectations authoritative in both shells,
    # even when Windows PowerShell reads this ASCII-only test source without a BOM.
    $exactTitle='=SUM(1,2), "quoted" '+[char]0x00e9+[char]0x4e2d+"`r`nline two`nline three"
    $exactArtist='+artist, "quoted" '+[char]0x03a9+"`r`nartist line"
    $exactAlbum='@album, '+[char]0x65e5+[char]0x672c+"`nsecond line"
    $seeds=@{}
    foreach($extension in @('mp3','m4a','ogg')){
        $seed=Join-Path $testRoot ('seed.'+$extension);$codec=if($extension -ceq 'mp3'){'libmp3lame'}elseif($extension -ceq 'm4a'){'aac'}else{'libvorbis'}
        Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=22050','-t','0.25','-c:a',$codec,'-b:a','64k','-metadata',('title='+$exactTitle),$seed)|Out-Null
        Add-Fixture $seed;$seeds[$extension]=$seed
    }
    $slowSeed=Join-Path $testRoot 'slow.m4a';Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=22050','-t','5','-c:a','aac','-b:a','64k','-metadata',('title='+$exactTitle),$slowSeed)|Out-Null;Add-Fixture $slowSeed
    $media=Get-OwnedMedia $seeds.mp3;Assert-True ($media.TitleStatus -ceq 'Present' -and $media.Title -ceq $exactTitle) 'Actual source metadata must match explicit Unicode, quotes, commas and CR/LF code points.'
    Invoke-Case 'JSON exact structured strings survive initial boundary and final atomic snapshots' 'A36' {
        param($case);$inputPath=New-InputFixture 'roundtrip';$parent=New-OutputParent 'roundtrip'
        $snapshot=Get-AudioInputSnapshot $inputPath (Join-Path $parent 'planned')
        $run=New-AudioRunReservation -OutputParent $parent -InputFolder $inputPath -Files $snapshot.Files -BitrateKbps 64 -MaxBaseLength 40 -Timestamp '20240101_000000'
        $context=New-AudioRunManifest -Run $run -Snapshot $snapshot -InputFolder $inputPath -ScriptPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -ToolInfo $toolInfo -BitrateKbps 64 -MaxBaseLength 40 -Artist $exactArtist -Album $exactAlbum
        $reason='-failure, "quote" '+[char]0x00e9+"`r`n=SUM(1,2)`nlast line"
        try{Update-AudioRunManifest $context Running $null 0;Write-AudioRunManifest $context Initial
            $row=$context.Data.records[0];$source=Join-Path $inputPath $row.source_relative_path;$output=Join-Path $run.OutputRoot $row.output_relative_path
            Set-AudioManifestRecord -Record $row -Status Failed -Code SyntheticStructuredFailure -Reason $reason -SourcePath $source -OutputPath $output -Media $media -Transaction $null -ElapsedSeconds 1.234
            Update-AudioRunManifest $context Failed 1 1.234;Write-AudioRunManifest $context FileBoundary;Write-AudioRunManifest $context Final
            $read=[IO.File]::ReadAllText($context.Path)|ConvertFrom-Json
            Assert-True ($read.records[0].reason -ceq $reason -and $read.records[0].source_title -ceq $exactTitle -and $read.policies.metadata.artist -ceq $exactArtist -and $read.policies.metadata.album -ceq $exactAlbum) 'JSON must roundtrip exact structured Unicode/formula-like/quoted/multiline values.'
            Assert-True ($read.checkpoint -ceq 'Final' -and $read.revision -eq 3 -and $read.totals.failed -eq 1 -and $read.records[0].input_duration_seconds -eq $media.DurationSeconds) 'Snapshots must retain actual measured duration and exclusive failure row.'
            $case['newline_fixture_kind']='actual source metadata and synthetic structured reason; no newline Windows filename';$case['exact_unicode_codepoints']=@('U+00E9','U+4E2D','U+03A9','U+65E5','U+672C');$case['roundtrip_json']=$read
        }finally{Close-AudioRunManifest $context}
        Get-RunArtifacts $parent|Out-Null
    }
    Invoke-Case 'mixed real formats corrupt input excluded subtree and unsupported files reconcile' 'A35,A36,A37' {
        param($case);$inputPath=New-InputFixture 'mixed' @('mp3','m4a','ogg');$bad=Join-Path $inputPath '2024-01-04 Bad.mp3';Write-NewText $bad 'Synthetic invalid MP3';Add-Fixture $bad
        foreach($name in @('notes.txt','.AudioFileForPhone-orphan.partial')){$path=Join-Path $inputPath $name;Write-NewText $path 'Synthetic unsupported source sentinel';Add-Fixture $path}
        $prior=Join-Path $inputPath 'Prior';[IO.Directory]::CreateDirectory($prior)|Out-Null;Write-AudioOutputMarker -OutputRoot $prior;Add-Fixture (Join-Path $prior '.AudioFileForPhone-output.json');$excluded=Join-Path $prior 'excluded.mp3';[IO.File]::Copy($seeds.mp3,$excluded,$false);Add-Fixture $excluded
        $parent=New-OutputParent 'mixed';$result=Invoke-Entry 'mixed' $inputPath $parent -Artist $exactArtist -Album $exactAlbum;$artifacts=Get-RunArtifacts $parent;Save-CaseRun $case $result $artifacts
        Assert-True ($result.exit_code -eq 2 -and $artifacts.data.run.status -ceq 'CompletedWithFailures' -and $artifacts.data.run.exit_code -eq 2) 'Real mixed run must persist completed-with-failures and exit2.'
        Assert-ConsoleCounts $result 4 3 1 0;$case['reconciled']=Assert-ManifestTotals $artifacts $inputPath 4 3 1 -Excluded 1 -Unsupported 2
        Assert-True ($artifacts.data.app_version -ceq (Get-AudioAppVersion) -and $artifacts.data.build.entry_sha256 -ceq (Get-FileHash -LiteralPath $result.entry).Hash.ToLowerInvariant() -and $artifacts.data.build.helper_sha256 -ceq (Get-FileHash -LiteralPath (Join-Path (Split-Path -Parent $result.entry) 'AudioFileForPhone.Helpers.ps1')).Hash.ToLowerInvariant()) 'App version and build fingerprint must identify actual executed entry/helper bytes.'
        foreach($name in @('ffmpeg','ffprobe')){Assert-True ($artifacts.data.tools.$name.path -ceq (Get-Variable $name -ValueOnly) -and $artifacts.data.tools.$name.version -ceq $toolInfo.$name.Version) 'Actual tool path and full version line must persist.'}
        Assert-True ($artifacts.data.policies.metadata.artist -ceq $exactArtist -and $artifacts.data.policies.metadata.album -ceq $exactAlbum -and @($artifacts.data.records|Where-Object{$_.status -ceq 'Converted' -and $_.source_title -cne $exactTitle}).Count -eq 0) 'Actual metadata policy and source titles must retain exact JSON strings.'
        $summaries=Get-NativeSummaries $artifacts.log;Assert-True (@($summaries|Where-Object{$_.stage -ceq 'SourceProbe' -and $_.exit_code -ne 0}).Count -eq 1 -and @($summaries.stage|Select-Object -Unique).Count -eq 4) 'Local log must retain actual source failure and all probe/encoder/validation stages.';$case['native_stage_summaries']=$summaries
    }
    foreach($mode in @('encoder-fail','output-probe-fail','output-decode-fail','large-probe-fail')){
        Invoke-Case ('bounded persistent actual native failure '+$mode) 'A35,A37' {
            param($case);$inputPath=New-InputFixture $mode;$parent=New-OutputParent $mode;$result=Invoke-Entry $mode $inputPath $parent -Mode $mode;$artifacts=Get-RunArtifacts $parent;Save-CaseRun $case $result $artifacts
            Assert-True ($result.exit_code -eq 2 -and $artifacts.data.run.status -ceq 'CompletedWithFailures') 'Native file failure must persist truthful failed row and exit2.'
            $case['reconciled']=Assert-ManifestTotals $artifacts $inputPath 1 0 1;Assert-ConsoleCounts $result 1 0 1 0
            $stage=if($mode -ceq 'encoder-fail'){'Encoder'}elseif($mode -ceq 'output-probe-fail'){'OutputProbe'}elseif($mode -ceq 'output-decode-fail'){'OutputDecode'}else{'SourceProbe'}
            $summaries=Get-NativeSummaries $artifacts.log;$failure=@($summaries|Where-Object{$_.stage -ceq $stage -and $_.exit_code -ne 0})
            Assert-True ($failure.Count -eq 1 -and $failure[0].process_released -and $failure[0].elapsed_ms -ge 0 -and $failure[0].stderr_retained_chars -le 16384 -and $artifacts.log.Contains('[NATIVE_STDERR] '+$stage)) 'Failure must persist bounded stderr, exit, release and elapsed diagnostics for its actual stage.'
            if($mode -ceq 'large-probe-fail'){Assert-True ($failure[0].stderr_total_chars -gt 131072 -and $failure[0].stderr_truncated -and -not $artifacts.log.Contains('STDOUT_SHOULD_NOT_PERSIST') -and $artifacts.log.Length -lt 50000 -and $artifacts.data.records[0].reason.Contains('[truncated; see local native diagnostics]')) 'Flooded synthetic native child must be drained yet retain only bounded stderr/reason and no stdout dump.'}
            $case['native_stage_summaries']=$summaries;$case['diagnostic_native_kind']=if($mode -ceq 'large-probe-fail'){'controlled compiled child; original owned native runner'}else{'actual FFmpeg/FFprobe invalid option/filter'}
        }
    }
    foreach($mode in @('manifest-initial','manifest-boundary','manifest-final','log-initial','log-boundary','log-final')){
        Invoke-Case ('required recording failure '+$mode+' preserves committed outputs') 'A35,A37' {
            param($case);$inputPath=New-InputFixture $mode @('mp3','m4a');$parent=New-OutputParent $mode;$result=Invoke-Entry $mode $inputPath $parent -Mode $mode;$artifacts=Get-RunArtifacts $parent;Save-CaseRun $case $result $artifacts
            $converted=if($mode -match 'initial$'){0}elseif($mode -match 'boundary$'){1}else{2}
            Assert-True ($result.exit_code -eq 1 -and $result.text.Contains('controlled T14 '+$mode+' persistence failure') -and $artifacts.outputs.Count -eq $converted) 'Required persistence failure must explicitly exit1 and keep actual publications.'
            Assert-ConsoleCounts $result 2 $converted 0 (2-$converted)
            Assert-True ($null -ne $artifacts.data -and $artifacts.data.run.status -notmatch '^Completed' -and $artifacts.data.totals.converted -eq $converted) 'Last persisted snapshot must keep committed row counts without claiming completed success.'
            $case['reconciled']=Assert-ManifestTotals $artifacts $inputPath 2 $converted 0 -NotProcessed (2-$converted)
        }
    }
    Invoke-Case 'existing manifest path is preserved without overwriting or final-looking partial' 'A35' {
        param($case);$inputPath=New-InputFixture 'manifest-existing';$parent=New-OutputParent 'manifest-existing';$result=Invoke-Entry 'manifest-existing' $inputPath $parent -Mode manifest-existing;$artifacts=Get-RunArtifacts $parent -AllowForeignManifest;Save-CaseRun $case $result $artifacts
        Assert-True ($result.exit_code -eq 1 -and [IO.File]::ReadAllText($artifacts.manifest_path) -ceq 'Synthetic existing manifest sentinel' -and $artifacts.outputs.Count -eq 0) 'Required JSON creation must refuse occupied target and preserve exact unrelated bytes.';Assert-ConsoleCounts $result 1 0 0 1;$case['occupied_manifest_preserved']=$true
    }
    Invoke-Case 'manifest identity replacement is refused without touching foreign bytes' 'A35' {
        param($case);$inputPath=New-InputFixture 'identity';$parent=New-OutputParent 'identity';$snapshot=Get-AudioInputSnapshot $inputPath (Join-Path $parent 'planned');$run=New-AudioRunReservation -OutputParent $parent -InputFolder $inputPath -Files $snapshot.Files -BitrateKbps 64 -MaxBaseLength 40 -Timestamp '20240101_000000'
        $context=New-AudioRunManifest -Run $run -Snapshot $snapshot -InputFolder $inputPath -ScriptPath (Join-Path $projectRoot 'AudioFileForPhone.ps1') -ToolInfo $toolInfo -BitrateKbps 64 -MaxBaseLength 40
        try{Update-AudioRunManifest $context Running $null 0;Write-AudioRunManifest $context Initial;Close-AudioRunManifest $context
            [IO.File]::Delete($context.Path);Write-NewText $context.Path 'Synthetic foreign identity sentinel';$refused=$false
            try{Update-AudioRunManifest $context Failed 1 1;Write-AudioRunManifest $context Final}catch{$refused=$true;$case['refusal_reason']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
            Assert-True ($refused -and [IO.File]::ReadAllText($context.Path) -ceq 'Synthetic foreign identity sentinel') 'Writer cannot adopt a replacement path merely because it retains the same filename.'
        }finally{Close-AudioRunManifest $context};Get-RunArtifacts $parent -AllowForeignManifest|Out-Null;$case['foreign_manifest_preserved']=$true
    }
    Invoke-Case 'post-publication final guard reopen failure persists Failed while preserving outputs' 'A35,A37' {
        param($case);$inputPath=New-InputFixture 'guard-reopen' @('mp3','m4a');$parent=New-OutputParent 'guard-reopen';$result=Invoke-Entry 'guard-reopen' $inputPath $parent -Mode manifest-guard-reopen;$artifacts=Get-RunArtifacts $parent;Save-CaseRun $case $result $artifacts
        Assert-True ($result.exit_code -eq 1 -and @($result.entry_audit|Where-Object{$_.guard_fault_injected}).Count -eq 1 -and $artifacts.data.run.status -ceq 'Failed' -and $artifacts.data.run.exit_code -eq 1) 'A post-promotion guard failure must correct safely owned Completed JSON to Failed.'
        Assert-ConsoleCounts $result 2 2 0 0;$case['reconciled']=Assert-ManifestTotals $artifacts $inputPath 2 2 0
    }
    foreach($mode in @('cancel-normal','cancel-manifest','cancel-log')){
        Invoke-Case ('controlled owned encoder cancellation with '+$mode+' recording') 'A35,A36,A37' {
            param($case);$inputPath=New-InputFixture $mode @('mp3','m4a','ogg') -CancellationSet;$parent=New-OutputParent $mode;$result=Invoke-Entry $mode $inputPath $parent -Mode $mode;$artifacts=Get-RunArtifacts $parent;Save-CaseRun $case $result $artifacts
            Assert-True ($result.exit_code -eq 130 -and $artifacts.outputs.Count -eq 1 -and @($result.native_release_proofs|Where-Object{$_.cancelled_encoder -and $_.owned_partial_seen -and $_.status -ceq 'Cancelled' -and $_.process_released}).Count -eq 1) 'Controlled exact-context request must cancel active owned partial after first publication and retain exit130 with positive release proof.'
            Assert-ConsoleCounts $result 3 1 0 2
            if($mode -ceq 'cancel-manifest'){
                Assert-True ($result.text.Contains('Cancellation manifest could not be written') -and $artifacts.data.run.status -ceq 'Running' -and $artifacts.data.totals.converted -eq 1 -and $artifacts.data.totals.cancelled -eq 0 -and $artifacts.data.totals.not_processed -eq 2) 'Persistent cancellation JSON failure must remain visibly last-good Running, never false final completion.'
                $case['reconciled_last_good_snapshot']=Assert-ManifestTotals $artifacts $inputPath 3 1 0 -NotProcessed 2
            }else{
                Assert-True ($artifacts.data.run.status -ceq 'Cancelled' -and $artifacts.data.run.exit_code -eq 130) 'Cancelled final JSON must persist exclusive current and unstarted candidate outcomes.'
                $case['reconciled']=Assert-ManifestTotals $artifacts $inputPath 3 1 0 -Cancelled 1 -NotProcessed 1
                if($mode -ceq 'cancel-log'){Assert-True ($result.text.Contains('Cancellation diagnostic could not be logged')) 'Required cancellation log failure must be explicit without changing130.'}
            }
            $case['physical_manual_evidence']=$false;$case['signal_kind']='per-instance timer Request on owned cancellation context'
        }
    }
    Invoke-Case 'startup context cancellation exits130 before reservation or manifest setup' 'A35,A37' {
        param($case);$inputPath=New-InputFixture 'startup';$parent=New-OutputParent 'startup';$result=Invoke-Entry 'startup' $inputPath $parent -Mode startup-cancel
        $case['actual_exit_code']=$result.exit_code;$case['console_diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>');$case['native_release_proofs']=$result.native_release_proofs
        Assert-True ($result.exit_code -eq 130 -and @($result.entry_audit|Where-Object{$_.startup_cancelled}).Count -eq 1 -and $result.text -notmatch 'not recognized|undefined' -and @(Get-ChildItem -LiteralPath $parent -Directory).Count -eq 0 -and $result.manifest_write_attempts.Count -eq 0) 'Immediate startup cancellation must report130 without undefined functions, reservation or manifest.'
        Assert-ConsoleCounts $result 1 0 0 1;$case['no_conversion_child']=(@($result.native_release_proofs|Where-Object{$_.status -ceq 'Cancelled'}).Count -eq 0)
    }
    $report.copied_entry_bytes_unchanged=$true;$report.status='pass';$exitCode=0
}
catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
    $childrenStopped=$descendantReleaseProved
    foreach($child in $children){if($child.timed_out){$childrenStopped=$false};if($child.disposed){continue}
        try{if($child.started){if(-not $child.process.HasExited){$child.process.Kill()};Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Owned host exit unproved.'}
            foreach($task in @($child.stdout_task,$child.stderr_task)){if($null -ne $task){Assert-True ($task.Wait(5000)) 'Owned pipe unproved.';$null=$task.GetAwaiter().GetResult()}};$child.process.Dispose();$child.disposed=$true
        }catch{$childrenStopped=$false;$report['child_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    $report.children_disposed=$childrenStopped;$report['descendant_release_proved']=$descendantReleaseProved
    $report['owned_host_objects']=@($children|ForEach-Object{[pscustomobject]@{started=$_.started;disposed=$_.disposed;timed_out=$_.timed_out}})
    foreach($inventory in @('source','synthetic')){try{$after=if($inventory -ceq 'source'){Get-SourceInventory}else{Get-FixtureInventory};$report[$inventory+'_after']=$after
        $same=(($report[$inventory+'_before']|ConvertTo-Json -Compress) -ceq ($after|ConvertTo-Json -Compress));$report[$inventory+'_unchanged']=$same;Assert-True $same "$inventory SHA256 must remain unchanged."
    }catch{$report.status='fail';$exitCode=1;$report[$inventory+'_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}}
    try{if($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)){
        $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/');Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exact exclusively reserved TEMP root.'
        Assert-NoReparse $resolved;Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact CreateNew ownership token.';Get-SafeTree $resolved|Out-Null
        [IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved)
    };Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'}catch{$report.status='fail';$exitCode=1;$report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    if(-not $childrenStopped){$report.status='fail';$exitCode=1};$report['finished_utc']=[DateTime]::UtcNow.ToString('o');Assert-NoReparse $evidenceParent;Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 20)
}
Write-Host "T14 diagnostics: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
