<#
T15 real metadata, explicit artwork and chapter observations. Only synthetic media,
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
$testName = 'T15M-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t15-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false; $descendantReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Metadata.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T15|T16)-metadata-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw "EvidencePath '$evidenceFullPath' must name fresh T15/T16-metadata-ps51/ps7-attempt/finalN.json directly in '$evidenceParent'."
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'real_metadata_artwork_and_chapter_observation'
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
    $deadline = New-Object T15Support.Deadline($context, 180000)
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
function Probe-Media {
    param([string]$Path)
    return (Invoke-OwnedNative $ffprobe @('-v','error','-show_streams','-show_format','-show_chapters','-of','json',$Path)).Stdout|ConvertFrom-Json
}
function Get-Tag {
    param([object]$Tags,[string]$Name)
    if($null -eq $Tags){return $null};$property=$Tags.PSObject.Properties|Where-Object{$_.Name -ieq $Name}|Select-Object -First 1
    if($null -ne $property){return [string]$property.Value};return $null
}
function New-AppCopy {
    param([string]$Label)
    $app=Join-Path $testRoot ('A-'+$Label);[IO.Directory]::CreateDirectory($app)|Out-Null
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){$copy=Join-Path $app $name;[IO.File]::Copy((Join-Path $projectRoot $name),$copy,$false);Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'App/helper copies must start byte-identical.'}
    $audit=@'
$script:T15OriginalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock
$script:T15OriginalCover=(Get-Item -LiteralPath Function:Get-ValidatedCoverPath).ScriptBlock
function Get-ValidatedCoverPath {
    param([string]$Path,[string]$FfmpegPath,[switch]$PassThru)
    $global:T15CoverCalls++;return & $script:T15OriginalCover @PSBoundParameters
}
function Get-CoverDiagnostics {param([string]$Path);throw 'T15 cached cover diagnostics must be reused without reopening image'}
function Invoke-AudioNativeProcess {
    param([string]$ExecutablePath,[string[]]$Arguments,[int]$MaxStdoutChars=1048576,[int]$MaxStderrChars=65536,
          [object]$Cancellation=(Get-AudioCancellationContext),[object]$ProgressParser=$null,[scriptblock]$ProgressCallback=$null,[object]$ProgressDurationSeconds=$null,[object]$ProgressCallbackState=$null,
          [int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000)
    $proof=[pscustomobject]@{process_released=$false;status='not returned';exit_code=$null;cover_decode=$false;image_exclusively_reopened=$false;cover_temporarily_corrupted=$false;cover_bytes_restored=$false};$global:T15NativeProofs.Add($proof)
    $nativeParameters=@{};foreach($key in $PSBoundParameters.Keys){$nativeParameters[$key]=$PSBoundParameters[$key]}
    $saved=$null;$result=$null
    try{
        if($global:T15CoverPath -and $Arguments -contains $global:T15CoverPath -and $Arguments -contains '-frames:v' -and $Arguments -contains 'null'){
            $proof.cover_decode=$true
            $stream=New-Object IO.FileStream($global:T15CoverPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            try{$proof.image_exclusively_reopened=$true}finally{$stream.Dispose()}
            if($global:T15Mode -ceq 'cover-undecodable'){
                $saved=[IO.File]::ReadAllBytes($global:T15CoverPath);[IO.File]::WriteAllBytes($global:T15CoverPath,[Text.Encoding]::UTF8.GetBytes('Synthetic controlled corrupt cover after disposed GDI validation'));$proof.cover_temporarily_corrupted=$true
            }
        }
        $result=& $script:T15OriginalNative @nativeParameters
        $proof.process_released=[bool]$result.ProcessReleased;$proof.status=$result.Status;$proof.exit_code=$result.ExitCode
        return $result
    }finally{
        if($null -ne $saved -and $null -ne $result -and $result.ProcessReleased){[IO.File]::WriteAllBytes($global:T15CoverPath,$saved);$proof.cover_bytes_restored=$true}
    }
}
'@
    [IO.File]::AppendAllText((Join-Path $app 'AudioFileForPhone.Helpers.ps1'),"`r`n"+$audit,[Text.Encoding]::UTF8)
    foreach($name in @('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1')){Add-Fixture (Join-Path $app $name)}
    return Join-Path $app 'AudioFileForPhone.ps1'
}
function Invoke-Entry {
    param([string]$Label,[string]$InputPath,[string]$OutputParent,[string]$CoverPath,[string]$Artist,[string]$Album,[string]$Mode='normal',[switch]$Interactive)
    $entry=New-AppCopy $Label;$driver=Join-Path $testRoot ($Label+'-driver.ps1')
    $prefix=@('$ErrorActionPreference=''Stop''','$ProgressPreference=''SilentlyContinue''','[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$env:PATH='+(Get-Literal (Split-Path -Parent $ffmpeg))+'+'';''+$env:PATH'),('$global:T15Mode='+(Get-Literal $Mode)),('$global:T15CoverPath='+(Get-Literal $CoverPath)),
        '$global:T15NativeProofs=New-Object ''System.Collections.Generic.List[object]''','$global:T15CoverCalls=0;$global:T15Prompts=0',
        'function global:Read-Host {param($Prompt);$global:T15Prompts++;throw ''T15 unexpected metadata prompt''}')
    $command='& '+(Get-Literal $entry)+' -InputFolder '+(Get-Literal $InputPath)+' -OutputParent '+(Get-Literal $OutputParent)+' -BitrateKbps 64 -MaxBaseLength 40'
    foreach($parameter in @('CoverPath','Artist','Album')){if($PSBoundParameters.ContainsKey($parameter)){$command+=' -'+$parameter+' '+(Get-Literal (Get-Variable $parameter -ValueOnly))}}
    if($Interactive){$command+=' -Interactive'}
    $text=(@($prefix)+@('$global:LASTEXITCODE=$null',($command+' *>&1 | ForEach-Object {[Console]::Out.WriteLine([string]$_)}'),
        'foreach($proof in $global:T15NativeProofs){[Console]::Out.WriteLine(''[NATIVEPROOF] ''+($proof|ConvertTo-Json -Compress))}',
        '[Console]::Out.WriteLine(''[ENTRYAUDIT] ''+(@{cover_validation_calls=$global:T15CoverCalls;prompts=$global:T15Prompts}|ConvertTo-Json -Compress))',
        'if($null -eq $global:LASTEXITCODE){throw ''Entry omitted exit code''};exit $global:LASTEXITCODE')) -join "`n"
    Write-NewText $driver $text -Utf8Bom;Add-Fixture $driver
    $info=New-Object Diagnostics.ProcessStartInfo;$info.FileName=$shellPath;$info.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "'+$driver+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$info.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info
    $child=[pscustomobject]@{process=$process;stdout_task=$null;stderr_task=$null;started=$false;disposed=$false;timed_out=$false};$children.Add($child)
    $prior=$script:descendantReleaseProved;$script:descendantReleaseProved=$false
    Assert-True ($process.Start()) 'Owned metadata entry host must start.';$child.started=$true
    $child.stdout_task=$process.StandardOutput.ReadToEndAsync();$child.stderr_task=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(120000)){$child.timed_out=$true;throw 'Synthetic metadata host timed out; preserve scope because descendants are unproved.'}
    if(-not $child.stdout_task.Wait(5000) -or -not $child.stderr_task.Wait(5000)){$child.timed_out=$true;throw 'Owned host pipes did not join; preserve scope.'}
    $result=[pscustomobject]@{exit_code=$process.ExitCode;text=$child.stdout_task.GetAwaiter().GetResult()+"`n"+$child.stderr_task.GetAwaiter().GetResult();entry=$entry}
    $process.Dispose();$child.disposed=$true
    $proofs=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[NATIVEPROOF\] '}|ForEach-Object{$_.Substring(14)|ConvertFrom-Json})
    $audit=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[ENTRYAUDIT\] '}|ForEach-Object{$_.Substring(13)|ConvertFrom-Json})
    $result|Add-Member -NotePropertyName native_release_proofs -NotePropertyValue $proofs;$result|Add-Member -NotePropertyName audit -NotePropertyValue $audit
    $report.entry_runs += [pscustomobject]@{label=$Label;mode=$Mode;exit_code=$result.exit_code;console=$result.text.Replace($testRoot,'<OWNED_TEMP>');native_release_proofs=$proofs;audit=$audit;host_wait_exit_and_pipe_join_proved=$true;host_disposed=$true}
    if($result.exit_code -in @(0,1,2,130) -and $result.text -match '\[RESULT\] status=' -and $proofs.Count -gt 0 -and @($proofs|Where-Object{-not $_.process_released}).Count -eq 0){$script:descendantReleaseProved=$prior}
    return $result
}
function New-Input {
    param([string]$Label,[object[]]$Entries)
    $folder=Join-Path $testRoot ('I-'+$Label);[IO.Directory]::CreateDirectory($folder)|Out-Null
    foreach($entry in $Entries){$target=Join-Path $folder $entry.Name;[IO.File]::Copy($entry.Path,$target,$false);Add-Fixture $target}
    return $folder
}
function New-Destination {
    param([string]$Label)
    $parent=Join-Path $testRoot ('O-'+$Label);[IO.Directory]::CreateDirectory($parent)|Out-Null
    $sentinel=Join-Path $parent 'Synthetic sibling sentinel.mp3';Write-NewText $sentinel 'Unrelated synthetic sibling must survive';Add-Fixture $sentinel;return $parent
}
function Get-Artifacts {
    param([string]$Parent)
    $roots=@(Get-ChildItem -LiteralPath $Parent -Directory -Force|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName '.AudioFileForPhone-output.json')})
    Assert-True ($roots.Count -eq 1) 'One recognized fresh run must exist.'
    $root=$roots[0].FullName;$tree=@(Get-SafeTree $root);Assert-True (@($tree|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.partial'}).Count -eq 0) 'Released children must leave no owned partial.'
    $manifest=[IO.File]::ReadAllText((Join-Path $root 'AudioFileForPhone_manifest.json'))|ConvertFrom-Json
    return [pscustomobject]@{root=$root;manifest=$manifest;log=[IO.File]::ReadAllText((Join-Path $root 'AudioFileForPhone_log.txt'));outputs=@($tree|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.mp3'})}
}
function Assert-Success {
    param([object]$Case,[object]$Result,[object]$Artifacts,[string]$InputPath,[int]$Count)
    $Case['diagnostics']=$Result.text.Replace($testRoot,'<OWNED_TEMP>');$Case['native_release_proofs']=$Result.native_release_proofs;$Case['cover_audit']=$Result.audit
    Assert-True ($Result.exit_code -eq 0 -and $Artifacts.manifest.run.status -ceq 'Completed' -and $Artifacts.manifest.totals.converted -eq $Count -and $Artifacts.manifest.totals.failed -eq 0 -and $Artifacts.outputs.Count -eq $Count) 'Actual successful manifest and publications must reconcile.'
    $Case['outputs']=@()
    foreach($row in $Artifacts.manifest.records){$source=Join-Path $InputPath $row.source_relative_path;$output=Join-Path $Artifacts.root $row.output_relative_path
        Assert-True ($Artifacts.log.Contains(("[OK] OK   : '{0}' -> '{1}'" -f $source,$output)) -and $row.status -ceq 'Converted') 'Each manifest row must match the independently persisted source-to-output success record.'
        $decoded=Assert-Decoded $output $row.input_duration_seconds;Assert-True ([math]::Abs($decoded.duration_seconds-$row.output_duration_seconds) -lt 0.000001) 'Actual independently probed output duration must equal manifest measurement.'
        $Case.outputs += [pscustomobject]@{source_relative_path=$row.source_relative_path;output_relative_path=$row.output_relative_path;decoded=$decoded;probe=Probe-Media $output}
    }
}
function Assert-FileUnlocked {
    param([string]$Path)
    $stream=New-Object IO.FileStream($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{Assert-True $stream.CanRead 'Disposed image/native handles must permit exclusive reopening.'}finally{$stream.Dispose()}
}
function Measure-CoverPixel {
    param([string]$Path,[int]$Width,[int]$Height,[string]$Label)
    $raw=Join-Path $testRoot ($Label+'-cover.rgb');Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-i',$Path,'-map','0:v:0','-frames:v','1','-pix_fmt','rgb24','-f','rawvideo',$raw)|Out-Null
    $bytes=[IO.File]::ReadAllBytes($raw);Assert-True ($bytes.Length -eq 3*$Width*$Height) 'Cover decode must have exact expected dimensions without resizing.'
    $offset=3*([int][math]::Floor($Height/2)*$Width+[int][math]::Floor($Width/2));return [pscustomobject]@{red=[int]$bytes[$offset];green=[int]$bytes[$offset+1];blue=[int]$bytes[$offset+2]}
}
function Measure-AudioFrequency {
    param([string]$Path,[string]$Label)
    $raw=Join-Path $testRoot ($Label+'-audio.f32');Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-i',$Path,'-map','0:a:0','-ac','1','-ar','22050','-f','f32le',$raw)|Out-Null
    $bytes=[IO.File]::ReadAllBytes($raw);$crossings=0;$previous=[double]0;$first=-1;$last=-1
    for($offset=0;$offset+4 -le $bytes.Length;$offset+=4){if([math]::Abs([BitConverter]::ToSingle($bytes,$offset)) -gt 0.002){if($first -lt 0){$first=$offset};$last=$offset}}
    Assert-True ($first -ge 0 -and $last -gt $first) 'Actual decoded audio must contain the synthetic sine signal.'
    for($offset=$first;$offset -le $last;$offset+=4){$value=[BitConverter]::ToSingle($bytes,$offset);if($previous -lt 0 -and $value -ge 0){$crossings++};$previous=$value}
    return $crossings/((($last-$first)/4)/22050.0)
}
$supportSource=@'
using System;using System.Threading;
namespace T15Support{public sealed class Deadline:IDisposable{private readonly Timer timer;private int timedOut;public bool TimedOut{get{return Interlocked.CompareExchange(ref timedOut,0,0)!=0;}}public Deadline(object context,int milliseconds){timer=new Timer(o=>{Interlocked.Exchange(ref timedOut,1);context.GetType().GetMethod("Request").Invoke(context,null);},null,milliseconds,Timeout.Infinite);}public void Dispose(){timer.Dispose();}}}
'@
function New-ImageFixture {
    param([string]$Name,[int]$Width,[int]$Height,[Drawing.Color]$Color,[Drawing.Imaging.ImageFormat]$Format)
    $path=Join-Path $testRoot $Name;$bitmap=New-Object Drawing.Bitmap($Width,$Height);$graphics=$null
    try{$graphics=[Drawing.Graphics]::FromImage($bitmap);$graphics.Clear($Color);$bitmap.Save($path,$Format)}finally{if($null -ne $graphics){$graphics.Dispose()};$bitmap.Dispose()}
    Assert-FileUnlocked $path;Add-Fixture $path;return $path
}
function New-TaggedAudio {
    param([string]$Name,[string]$Codec,[string]$Title,[string[]]$Extra=@())
    $path=Join-Path $testRoot $Name
    Invoke-OwnedNative $ffmpeg (@('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=22050','-t','0.4','-c:a',$Codec,'-b:a','64k','-metadata',('title='+$Title),'-metadata',('artist='+$sourceArtist),'-metadata',('album='+$sourceAlbum),'-metadata',('comment='+$sourceComment),'-metadata','track=3/9','-metadata','disc=2/4')+$Extra+@($path))|Out-Null
    Add-Fixture $path;return $path
}
function Assert-OrdinaryTags {
    param([object]$Probe,[string]$Title,[string]$Artist=$sourceArtist,[string]$Album=$sourceAlbum)
    foreach($entry in @(@('title',$Title),@('artist',$Artist),@('album',$Album),@('comment',$sourceComment),@('track','3/9'),@('disc','2/4'))){Assert-True ((Get-Tag $Probe.format.tags $entry[0]) -ceq $entry[1]) ('Actual output '+$entry[0]+' tag must preserve deterministic exact value.')}
}
try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop;Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
    $ownedRootCreated=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero);Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved=$true;Write-NewText $ownerFile $ownerToken;$report.marker_create_new=$true;$report.owner_marker_sha256=(Get-FileHash -LiteralPath $ownerFile).Hash.ToLowerInvariant();$report.source_before=Get-SourceInventory
    Add-Type -TypeDefinition $supportSource;Add-Type -AssemblyName System.Drawing
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools']=@($ffmpeg,$ffprobe|ForEach-Object{[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant();version=(Invoke-OwnedNative $_ @('-version')).Stdout.Split([char]10)[0].Trim()}})
    $sourceTitle='Source "quoted", '+[char]0x00e9+[char]0x4e2d;$sourceArtist='Artist "quoted", '+[char]0x03a9;$sourceAlbum='Album "quoted", '+[char]0x65e5+[char]0x672c;$sourceComment='Comment "quoted", =SUM(1,2) '+[char]0x00e9
    $overrideArtist='Override "quoted", '+[char]0x00e9+[char]0x4e2d;$overrideAlbum='Override album "quoted", '+[char]0x03a9
    $baseMp3=New-TaggedAudio 'tagged.mp3' libmp3lame $sourceTitle;$baseM4a=New-TaggedAudio 'tagged.m4a' aac $sourceTitle @('-metadata:s:a:0','title=Audio stream ignored title','-metadata:s:a:0','handler_name=Audio stream ignored title')
    $oggTitle='Ogg selected stream "quoted", '+[char]0x00e9
    $baseOgg=New-TaggedAudio 'tagged.ogg' libvorbis 'Container request overridden in Ogg audio comments' @('-metadata:s:a:0',('title='+$oggTitle))
    $emptyMp3=New-TaggedAudio 'empty-title.mp3' libmp3lame '';$spaceMp3=New-TaggedAudio 'space-title.mp3' libmp3lame '   '
    $redPng=New-ImageFixture 'source-red.png' 40 24 ([Drawing.Color]::Red) ([Drawing.Imaging.ImageFormat]::Png)
    $blueJpg=New-ImageFixture 'cover-blue.jpg' 40 24 ([Drawing.Color]::Blue) ([Drawing.Imaging.ImageFormat]::Jpeg)
    $greenPng=New-ImageFixture 'cover-green.png' 40 24 ([Drawing.Color]::Lime) ([Drawing.Imaging.ImageFormat]::Png)
    $largeJpg=New-ImageFixture 'cover-large.jpg' 1232 1304 ([Drawing.Color]::Blue) ([Drawing.Imaging.ImageFormat]::Jpeg)
    $sourceArt=Join-Path $testRoot 'source-art.mp3';Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-i',$baseMp3,'-i',$redPng,'-map','0:a:0','-map','1:v:0','-c:a','copy','-c:v','png','-disposition:v','attached_pic','-id3v2_version','3',$sourceArt)|Out-Null;Add-Fixture $sourceArt
    Invoke-Case 'real format and Ogg stream metadata existing empty and whitespace title precedence' 'A38' {
        param($case);$entries=@([pscustomobject]@{Name='2024-01-01 Existing.mp3';Path=$baseMp3},[pscustomobject]@{Name='2024-01-02 Format.m4a';Path=$baseM4a},[pscustomobject]@{Name='2024-01-03 Ogg.ogg';Path=$baseOgg},[pscustomobject]@{Name='2024-01-04 Empty fallback.mp3';Path=$emptyMp3},[pscustomobject]@{Name='2024-01-05 Whitespace title.mp3';Path=$spaceMp3})
        $inputPath=New-Input 'titles' $entries;$parent=New-Destination 'titles';$result=Invoke-Entry 'titles' $inputPath $parent;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 5
        foreach($output in $case.outputs){$row=@($artifacts.manifest.records|Where-Object{$_.source_relative_path -ceq $output.source_relative_path})[0];$source=Join-Path $inputPath $output.source_relative_path;$sourceProbe=Probe-Media $source;$inspected=Get-OwnedMedia $source
            $expected=if($output.source_relative_path -like '*Ogg*'){$oggTitle}elseif($output.source_relative_path -like '*Empty*'){[IO.Path]::GetFileNameWithoutExtension($row.output_relative_path)}elseif($output.source_relative_path -like '*Whitespace*'){'   '}else{$sourceTitle}
            Assert-OrdinaryTags $output.probe $expected
            if($output.source_relative_path -like '*Ogg*'){Assert-True ($inspected.MetadataSource -ceq '0:s:a:0' -and $inspected.Title -ceq (Get-Tag $sourceProbe.streams[0].tags title) -and $inspected.Title -ceq $oggTitle) 'Actual Ogg uses selected audio comments.'}
            elseif($output.source_relative_path -notlike '*Empty*'){Assert-True ($inspected.MetadataSource -ceq '0' -and $inspected.Title -ceq (Get-Tag $sourceProbe.format.tags title)) 'Actual MP3/M4A title comes from format metadata.'}
            else{Assert-True ($inspected.TitleStatus -ceq 'Absent') 'An actual empty title assignment must trigger sanitized planned-name fallback.'}
        }
        $case['m4a_source_probe']=Probe-Media $baseM4a;$case['ogg_source_probe']=Probe-Media $baseOgg;$case['empty_vs_whitespace_policy']='empty/missing falls back; nonempty whitespace preserved';$case['unicode_expectation_codepoints']=@('U+00E9','U+4E2D','U+03A9','U+65E5','U+672C')
    }
    Invoke-Case 'explicit quoted Unicode artist and album overrides win while ordinary tags remain' 'A38' {
        param($case);$inputPath=New-Input 'overrides' @([pscustomobject]@{Name='2024-01-01 Tagged.mp3';Path=$baseMp3},[pscustomobject]@{Name='2024-01-02 Tagged.m4a';Path=$baseM4a},[pscustomobject]@{Name='2024-01-03 Tagged.ogg';Path=$baseOgg});$parent=New-Destination 'overrides';$result=Invoke-Entry 'overrides' $inputPath $parent -Artist $overrideArtist -Album $overrideAlbum;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 3
        foreach($output in $case.outputs){$expected=if($output.source_relative_path.EndsWith('.ogg')){$oggTitle}else{$sourceTitle};Assert-OrdinaryTags $output.probe $expected $overrideArtist $overrideAlbum}
        Assert-True ($artifacts.manifest.policies.metadata.artist -ceq $overrideArtist -and $artifacts.manifest.policies.metadata.album -ceq $overrideAlbum) 'Actual override policy must persist exact strings.'
    }
    Invoke-Case 'blank overrides are ignored and padded nonblank override values remain exact' 'A38' {
        param($case);$inputPath=New-Input 'blank' @([pscustomobject]@{Name='2024-01-01 Tagged.mp3';Path=$baseMp3});$parent=New-Destination 'blank';$result=Invoke-Entry 'blank' $inputPath $parent -Artist '   ' -Album '';$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 1;Assert-OrdinaryTags $case.outputs[0].probe $sourceTitle
        $paddedArtist='  '+$overrideArtist+'  ';$plan=Get-AudioMetadataPlan -Media (Get-OwnedMedia $baseMp3) -FallbackTitle ignored -Artist $paddedArtist -Album ' '
        Assert-True ($plan.ArtistOverride -ceq $paddedArtist -and $null -eq $plan.AlbumOverride -and $plan.Arguments[-1] -ceq ('artist='+$paddedArtist)) 'Pure plan must retain exact nonblank override without trimming and ignore whitespace.';$case['padded_override_plan']=$plan
    }
    Invoke-Case 'mixed normal video second audio and source art select only first audio' 'A38,A39' {
        param($case);$mixed=Join-Path $testRoot 'mixed.m4a';Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','color=c=red:s=32x24:r=4','-f','lavfi','-i','sine=frequency=440:sample_rate=22050','-f','lavfi','-i','sine=frequency=880:sample_rate=22050','-i',$blueJpg,'-t','1','-map','0:v:0','-map','1:a:0','-map','2:a:0','-map','3:v:0','-c:v:0','mpeg4','-c:v:1','mjpeg','-disposition:v:1','attached_pic','-c:a','aac','-b:a','64k','-metadata',('title='+$sourceTitle),'-f','mp4',$mixed)|Out-Null;Add-Fixture $mixed
        $sourceProbe=Probe-Media $mixed;$inspected=Get-OwnedMedia $mixed;Assert-True (@($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'audio'}).Count -eq 2 -and @($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'video'}).Count -eq 2 -and $inspected.StreamIndex -eq @($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'audio'})[0].index) 'Actual source must have normal video plus source art and two audio streams; selected absolute first-audio index must be correct.'
        $inputPath=New-Input 'mixed' @([pscustomobject]@{Name='2024-01-01 Mixed.m4a';Path=$mixed});$parent=New-Destination 'mixed';$result=Invoke-Entry 'mixed' $inputPath $parent;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 1
        Assert-True (@($case.outputs[0].probe.streams).Count -eq 1 -and $case.outputs[0].probe.streams[0].codec_type -ceq 'audio') 'Default output must contain only selected audio, no normal video/second audio/source picture.'
        $frequency=Measure-AudioFrequency (Join-Path $artifacts.root $case.outputs[0].output_relative_path) 'mixed';Assert-True ([math]::Abs($frequency-440) -lt 15) 'Independently decoded sine frequency must identify first440Hz audio rather than second880Hz.';$case['decoded_frequency_hz']=$frequency;$case['source_stream_shape']=$sourceProbe.streams
    }
    Invoke-Case 'source artwork is dropped by default while metadata survives' 'A39' {
        param($case);$sourceProbe=Probe-Media $sourceArt;Assert-True (@($sourceProbe.streams|Where-Object{$_.disposition.attached_pic -eq 1}).Count -eq 1) 'Actual source artwork fixture must contain one attached picture.'
        $inputPath=New-Input 'drop-art' @([pscustomobject]@{Name='2024-01-01 Source art.mp3';Path=$sourceArt});$parent=New-Destination 'drop-art';$result=Invoke-Entry 'drop-art' $inputPath $parent;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 1
        Assert-True (@($case.outputs[0].probe.streams|Where-Object{$_.codec_type -ceq 'video'}).Count -eq 0 -and $result.audit[0].cover_validation_calls -eq 0) 'Default artwork policy must drop source art without cover work.';Assert-OrdinaryTags $case.outputs[0].probe $sourceTitle
    }
    foreach($coverCase in @([pscustomobject]@{label='jpeg';path=$blueJpg;width=40;height=24;color='blue'},[pscustomobject]@{label='png';path=$greenPng;width=40;height=24;color='green'},[pscustomobject]@{label='large';path=$largeJpg;width=1232;height=1304;color='blue'})){
        Invoke-Case ('explicit '+$coverCase.label+' replaces source art once per batch without resizing') 'A39,A40' {
            param($case);$inputPath=New-Input $coverCase.label @([pscustomobject]@{Name='2024-01-01 Source art.mp3';Path=$sourceArt},[pscustomobject]@{Name='2024-01-02 Tagged.m4a';Path=$baseM4a});$parent=New-Destination $coverCase.label;$result=Invoke-Entry $coverCase.label $inputPath $parent -CoverPath $coverCase.path;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 2
            $coverProofs=@($result.native_release_proofs|Where-Object{$_.cover_decode});Assert-True ($result.audit[0].cover_validation_calls -eq 1 -and $coverProofs.Count -eq 1 -and $coverProofs[0].image_exclusively_reopened -and $coverProofs[0].process_released) 'One disposed image validation and one real cover decode must serve the whole batch.'
            Assert-True (@($artifacts.log -split '\r?\n'|Where-Object{$_ -match '^\[DEBUG\] \[NATIVE\] .*"stage":"CoverDecode"'}).Count -eq 1) 'Actual cover native result must be recorded once in local log.'
            $case['actual_pixels']=@();foreach($output in $case.outputs){$covers=@($output.probe.streams|Where-Object{$_.codec_type -ceq 'video'});Assert-True ($covers.Count -eq 1 -and $covers[0].disposition.attached_pic -eq 1 -and $covers[0].codec_name -ceq 'mjpeg' -and $covers[0].width -eq $coverCase.width -and $covers[0].height -eq $coverCase.height) 'Exactly one requested JPEG cover with unchanged dimensions must replace source picture.'
                $pixel=Measure-CoverPixel (Join-Path $artifacts.root $output.output_relative_path) $coverCase.width $coverCase.height ($coverCase.label+'-'+$case.actual_pixels.Count)
                if($coverCase.color -ceq 'blue'){Assert-True ($pixel.blue -gt 180 -and $pixel.red -lt 50 -and $pixel.green -lt 50) 'Actual blue replacement must differ from original red picture despite same dimensions.'}else{Assert-True ($pixel.green -gt 180 -and $pixel.red -lt 50 -and $pixel.blue -lt 50) 'Actual green PNG replacement must differ from original red source art.'};$case.actual_pixels+=$pixel
            };Assert-FileUnlocked $coverCase.path
            if($coverCase.label -ceq 'large'){Assert-True ($result.text.Contains('1232x1304') -and $result.text.Contains('Consider ~800x800')) 'Large image diagnostics must remain advisory while dimensions are preserved.'};$case['cover_sha256_unchanged']=$true;$case['no_resizing']=$true
        }
    }
    $corrupt=Join-Path $testRoot 'corrupt.png';Write-NewText $corrupt 'Synthetic invalid PNG';Add-Fixture $corrupt
    $gif=New-ImageFixture 'wrong-gif.png' 40 24 ([Drawing.Color]::Red) ([Drawing.Imaging.ImageFormat]::Gif);$bmp=New-ImageFixture 'wrong-bmp.jpg' 40 24 ([Drawing.Color]::Blue) ([Drawing.Imaging.ImageFormat]::Bmp)
    foreach($negative in @([pscustomobject]@{label='missing';path=(Join-Path $testRoot 'missing.png');mode='normal'},[pscustomobject]@{label='corrupt';path=$corrupt;mode='normal'},[pscustomobject]@{label='gif-renamed';path=$gif;mode='normal'},[pscustomobject]@{label='bmp-renamed';path=$bmp;mode='normal'},[pscustomobject]@{label='ffmpeg-undecodable';path=$greenPng;mode='cover-undecodable'})){
        Invoke-Case ('invalid explicit '+$negative.label+' cover fails before reservation logs or prompts') 'A39,A40' {
            param($case);$inputPath=New-Input $negative.label @([pscustomobject]@{Name='2024-01-01 Tagged.mp3';Path=$baseMp3});$parent=New-Destination $negative.label;$result=Invoke-Entry $negative.label $inputPath $parent -CoverPath $negative.path -Mode $negative.mode -Interactive
            $case['diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>');$case['native_release_proofs']=$result.native_release_proofs;$case['cover_audit']=$result.audit
            Assert-True ($result.exit_code -eq 1 -and $result.text.Contains('Invalid CoverPath') -and $result.audit[0].prompts -eq 0 -and $result.audit[0].cover_validation_calls -eq 1 -and @(Get-ChildItem -LiteralPath $parent -Directory -Force).Count -eq 0) 'Invalid supplied cover must be fatal preflight before interactive prompts or any reserved root/log.'
            if($negative.mode -ceq 'cover-undecodable'){$proof=@($result.native_release_proofs|Where-Object{$_.cover_decode})[0];Assert-True ($proof.image_exclusively_reopened -and $proof.cover_temporarily_corrupted -and $proof.status -ceq 'Completed' -and $proof.exit_code -ne 0 -and $proof.process_released -and $proof.cover_bytes_restored) 'Controlled after-GDI corruption must trigger actual ffmpeg failure; restore fixture only after positive native release.';$case['fault_kind']='isolated cover corrupted only after GDI validation/disposal before actual FFmpeg decode; exact original bytes restored after release'}
            if([IO.File]::Exists($negative.path)){Assert-FileUnlocked $negative.path}
        }
    }
    Invoke-Case 'Completed exit0 without release proof is rejected even after disposed image validation' 'A39,A40' {
        param($case);$originalNative=(Get-Item -LiteralPath Function:Invoke-AudioNativeProcess).ScriptBlock;$calls=0
        $stub={param($ExecutablePath,$Arguments,$MaxStdoutChars,$MaxStderrChars,$Cancellation,$ProgressParser,$ProgressCallback,$ProgressDurationSeconds,$ProgressCallbackState,[int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000);$script:T15NoChildCalls++;return [pscustomobject]@{Status='Completed';ExitCode=0;ProcessReleased=$false;Stdout='';Stderr='';Error='';DurationMilliseconds=0}};$script:T15NoChildCalls=0;$refused=$false
        try{Set-Item -LiteralPath Function:Invoke-AudioNativeProcess -Value $stub;try{Get-ValidatedCoverPath -Path $blueJpg -FfmpegPath $ffmpeg -PassThru|Out-Null}catch{$refused=$true;$case['reason']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}}finally{Set-Item -LiteralPath Function:Invoke-AudioNativeProcess -Value $originalNative}
        Assert-True ($refused -and $script:T15NoChildCalls -eq 1) 'Cover preflight must not treat Completed/exit0 as release proof.';Assert-FileUnlocked $blueJpg;$case['native_fixture_kind']='explicit no-process stub; no unknown child launched';$case['image_handle_disposed']=$true
    }
    Invoke-Case 'real M4A chapters preserve observed MP3 chapter times and exact tags without player claim' 'A40' {
        param($case);$metadata=Join-Path $testRoot 'chapters.ffmetadata';$firstTitle='Chapter "one", '+[char]0x00e9;$secondTitle='Chapter two '+[char]0x4e2d
        Write-NewText $metadata (";FFMETADATA1`n[CHAPTER]`nTIMEBASE=1/1000`nSTART=0`nEND=150`ntitle="+$firstTitle+"`n[CHAPTER]`nTIMEBASE=1/1000`nSTART=150`nEND=400`ntitle="+$secondTitle+"`n");Add-Fixture $metadata
        $chapterSource=Join-Path $testRoot 'chapters.m4a';Invoke-OwnedNative $ffmpeg @('-nostdin','-v','error','-i',$baseM4a,'-f','ffmetadata','-i',$metadata,'-map','0:a:0','-c:a','copy','-map_metadata','0','-map_chapters','1',$chapterSource)|Out-Null;Add-Fixture $chapterSource
        $sourceProbe=Probe-Media $chapterSource;Assert-True (@($sourceProbe.chapters).Count -eq 2 -and (Get-Tag $sourceProbe.chapters[0].tags title) -ceq $firstTitle -and (Get-Tag $sourceProbe.chapters[1].tags title) -ceq $secondTitle) 'Actual source must contain both chapter tags.'
        $inputPath=New-Input 'chapters' @([pscustomobject]@{Name='2024-01-01 Chapters.m4a';Path=$chapterSource});$parent=New-Destination 'chapters';$result=Invoke-Entry 'chapters' $inputPath $parent;$artifacts=Get-Artifacts $parent;Assert-Success $case $result $artifacts $inputPath 1
        $actual=@($case.outputs[0].probe.chapters);Assert-True ($actual.Count -eq 2) 'This FFmpeg build must preserve both observed source chapters into MP3.'
        for($index=0;$index -lt 2;$index++){Assert-True ((Get-Tag $actual[$index].tags title) -ceq (Get-Tag $sourceProbe.chapters[$index].tags title) -and [math]::Abs([double]$actual[$index].start_time-[double]$sourceProbe.chapters[$index].start_time) -le 0.001 -and [math]::Abs([double]$actual[$index].end_time-[double]$sourceProbe.chapters[$index].end_time) -le 0.001) 'Observed MP3 chapter tags/times must match actual M4A chapters within1ms.'}
        $case['source_chapters']=$sourceProbe.chapters;$case['actual_output_chapters']=$actual;$case['limitation']='Observed FFprobe chapter tags/times for these synthetic files and installed FFmpeg build only; phone/player chapter navigation not tested or guaranteed.';$case['physical_manual_evidence']=$false
    }
    $report.copied_entry_bytes_unchanged=$true;$report.status='pass';$exitCode=0
}
catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
    $childrenStopped=$descendantReleaseProved
    foreach($child in $children){if($child.timed_out){$childrenStopped=$false};if($child.disposed){continue}
        try{if($child.started){if(-not $child.process.HasExited){$child.process.Kill()};Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Owned host exit unproved.'};foreach($task in @($child.stdout_task,$child.stderr_task)){if($null -ne $task){Assert-True ($task.Wait(5000)) 'Owned pipe unproved.';$null=$task.GetAwaiter().GetResult()}};$child.process.Dispose();$child.disposed=$true}
        catch{$childrenStopped=$false;$report['child_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    $report.children_disposed=$childrenStopped;$report['descendant_release_proved']=$descendantReleaseProved;$report['owned_host_objects']=@($children|ForEach-Object{[pscustomobject]@{started=$_.started;disposed=$_.disposed;timed_out=$_.timed_out}})
    foreach($inventory in @('source','synthetic')){try{$after=if($inventory -ceq 'source'){Get-SourceInventory}else{Get-FixtureInventory};$report[$inventory+'_after']=$after;$same=(($report[$inventory+'_before']|ConvertTo-Json -Compress) -ceq ($after|ConvertTo-Json -Compress));$report[$inventory+'_unchanged']=$same;Assert-True $same "$inventory SHA256 must remain unchanged."}catch{$report.status='fail';$exitCode=1;$report[$inventory+'_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}}
    try{if($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)){$resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/');Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exact exclusive TEMP root.';Assert-NoReparse $resolved;Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Exact CreateNew token required.';Get-SafeTree $resolved|Out-Null;[IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved)};Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'}catch{$report.status='fail';$exitCode=1;$report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    if(-not $childrenStopped){$report.status='fail';$exitCode=1};$report['finished_utc']=[DateTime]::UtcNow.ToString('o');Assert-NoReparse $evidenceParent;Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 20)
}
Write-Host "T15 metadata: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
