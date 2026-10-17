<#
T12 no-write preview evidence and plan-versus-real conversion on PS5.1/PS7.
All fixtures, app copies and drivers use one exclusively reserved, marked TEMP
tree. Preview inventories include directories, SHA256, LastWriteTimeUtc and
attributes; access times are deliberately excluded. No ordinary Music access.
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
$testName = 'T12P-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.t12-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$ownedRootCreated = $false; $descendantReleaseProved = $true
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$children = New-Object 'System.Collections.Generic.List[object]'
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-Preview.ps1')
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
$shellPath = Join-Path $PSHOME $shellName
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T12|T13|T14|T15|T16)-preview-(ps51|ps7)-(attempt|final)[0-9]+\.json$') {
    throw "EvidencePath '$evidenceFullPath' must name fresh T12/T13/T14/T15/T16-preview-ps51/ps7-attempt/finalN.json directly in '$evidenceParent'."
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'EvidencePath already exists; use a fresh label.' }
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3); mode = 'preview_inventory_equality_and_real_plan_equivalence'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_entry_bytes_unchanged = $false
    owned_temp_root = $testRoot; owner_marker_sha256 = $null
    inventory_fields = @('relative_path', 'kind', 'length', 'sha256', 'last_write_utc', 'attributes')
    access_time_excluded = $true; ordinary_music_access = $false
    cases = @(); children_disposed = $false; cleanup_verified = $false; status = 'fail'; error = $null
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
function Get-TreeInventory {
    param([string]$Root)
    $items = @((Get-Item -LiteralPath $Root -Force)) + @(Get-SafeTree $Root)
    return @($items | ForEach-Object {
        # Enumeration can retain directory metadata from fixture setup; read
        # authoritative properties afresh on both sides of the equality check.
        $_.Refresh()
        [pscustomobject][ordered]@{
            relative_path = $(if ($_.FullName -ceq $Root) { '.' } else { $_.FullName.Substring($Root.Length + 1) })
            kind = $(if ($_.PSIsContainer) { 'directory' } else { 'file' })
            length = $(if ($_.PSIsContainer) { $null } else { $_.Length })
            sha256 = $(if ($_.PSIsContainer) { $null } else { (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant() })
            last_write_utc = $_.LastWriteTimeUtc.ToString('o'); attributes = [int]$_.Attributes
        }
    } | Sort-Object relative_path)
}
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_)).Hash.ToLowerInvariant() } })
}
function Get-FixtureInventory {
    return @($fixtures | ForEach-Object { [pscustomobject]@{ relative_path = $_.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant() } })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += [pscustomobject]@{ relative_path = $Path.Substring($testRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-RealSuccess {
    param([string]$Tool, [string[]]$NativeArguments)
    $previousReleaseProof = $script:descendantReleaseProved
    $script:descendantReleaseProved = $false
    $native = Invoke-AudioNativeProcess -ExecutablePath $Tool -Arguments $NativeArguments -Cancellation $null
    if ($native.ProcessReleased) { $script:descendantReleaseProved = $previousReleaseProof }
    Assert-True ($native.Status -ceq 'Completed' -and $native.ExitCode -eq 0 -and $native.ProcessReleased) ('Native fixture/check failed: ' + $native.Status + '/' + $native.ExitCode + ' ' + $native.Error + ' ' + $native.Stderr)
    return $native
}
function New-AppCopy {
    param([string]$Label, [switch]$Guards)
    $root = Join-Path $testRoot ('A-' + $Label); [IO.Directory]::CreateDirectory($root) | Out-Null
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) {
        [IO.File]::Copy((Join-Path $projectRoot $name), (Join-Path $root $name), $false)
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $root $name)).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Every app copy must start byte-identical.'
    }
    if ($Guards) {
        $append = @'
function Invoke-AudioNativeProcess { param($ExecutablePath,$Arguments,$MaxStdoutChars,$MaxStderrChars,$Cancellation,[int]$TimeoutMilliseconds=0,[string]$Operation='Native operation',[int]$PipeDrainTimeoutMilliseconds=5000); Stop-T12Forbidden 'native' }
function Get-ToolPath { param($ExeName,$ScriptDirectory); Stop-T12Forbidden 'tool lookup' }
function Assert-ToolPrerequisites { param($FfmpegPath,$FfprobePath); Stop-T12Forbidden 'tool prerequisites' }
function Get-ValidatedCoverPath { param($Path,$FfmpegPath); Stop-T12Forbidden 'cover validation/cache' }
function Test-OutputWritable { param($Path,[switch]$SkipWriteProbe); Stop-T12Forbidden 'destination write probe' }
function New-AudioRunReservation { param($OutputParent,$InputFolder,$Files,$BitrateKbps,$MaxBaseLength,$Timestamp,$StartCounter,$MaximumAttempts); Stop-T12Forbidden 'run reservation' }
function New-AudioRunLog { param($OutputRoot); Stop-T12Forbidden 'log creation' }
function Write-AudioRunManifest { param($Manifest,$Checkpoint); Stop-T12Forbidden 'manifest write' }
function Write-AudioOutputMarker { param($OutputRoot,$InputFolder,$BitrateKbps,$OwnershipToken); Stop-T12Forbidden 'marker creation' }
function New-AudioCancellationContext { param([switch]$CaptureConsole); Stop-T12Forbidden 'console cancellation scope' }
function New-AudioProgressParser { Stop-T12Forbidden 'progress parser compilation' }
function Initialize-AudioDirectoryInterop { Stop-T12Forbidden 'write interop compilation' }
$script:T12OriginalOutputParent=(Get-Item -LiteralPath Function:Get-OutputParent).ScriptBlock
function Get-OutputParent {
    param([string]$OutputParent,[scriptblock]$MusicResolver)
    if ([string]::IsNullOrWhiteSpace($OutputParent)) { $MusicResolver={ $global:T12OwnedMusicPath } }
    return & $script:T12OriginalOutputParent -OutputParent $OutputParent -MusicResolver $MusicResolver
}
'@
        [IO.File]::AppendAllText((Join-Path $root 'AudioFileForPhone.Helpers.ps1'), "`r`n" + $append, [Text.Encoding]::UTF8)
    }
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) { Add-Fixture (Join-Path $root $name) }
    return Join-Path $root 'AudioFileForPhone.ps1'
}
function New-Driver {
    param([string]$Label, [string]$Entry, [string]$InputPath, [string]$OutputParent, [switch]$Preview,
          [switch]$Interactive, [string]$Cover = '', [int]$Limit = 40, [switch]$OmitOutputParent)
    $command = '& ' + (Get-Literal $Entry) + ' -InputFolder ' + (Get-Literal $InputPath) + ' -BitrateKbps 64 -MaxBaseLength ' + $Limit +
        ' -Artist ' + (Get-Literal "Synthetic O'Brien & !% ^ artist") + ' -Album ' + (Get-Literal 'Synthetic preview album')
    if (-not $OmitOutputParent) { $command += ' -OutputParent ' + (Get-Literal $OutputParent) }
    if ($Preview) { $command += ' -DryRun' }; if ($Interactive) { $command += ' -Interactive' }; if ($Cover) { $command += ' -CoverPath ' + (Get-Literal $Cover) }
    $prefix = @('$ErrorActionPreference=''Stop''', '$ProgressPreference=''SilentlyContinue''', '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false)',
        ('$env:PATH=' + (Get-Literal (Split-Path -Parent $ffmpeg)) + '+'';''+$env:PATH'),
        '$global:T12ForbiddenCalls=New-Object ''System.Collections.Generic.List[string]''',
        ('$global:T12OwnedMusicPath=' + (Get-Literal $OutputParent)),
        'function global:Stop-T12Forbidden { param([string]$Name); $global:T12ForbiddenCalls.Add($Name); throw (''T12 forbidden preview operation: ''+$Name) }',
        'function global:Read-Host { param($Prompt,[switch]$AsSecureString,[switch]$MaskInput); Stop-T12Forbidden ''interactive prompt'' }')
    if ($Preview) {
        $prefix += 'function global:Write-Progress { [CmdletBinding()] param($Activity,$Status,$PercentComplete,$Id,$ParentId,[switch]$Completed); Stop-T12Forbidden ''progress display'' }'
        $prefix += 'function global:Add-Content { param($LiteralPath,$Path,$Value,$Encoding); Stop-T12Forbidden ''content/log append'' }'
        $prefix += 'function global:New-Item { param($Path,$ItemType,$Name,$Value); Stop-T12Forbidden ''directory/file creation'' }'
    }
    $text = (@($prefix) + @('$global:LASTEXITCODE=$null', ($command + ' *>&1 | ForEach-Object { [Console]::Out.WriteLine([string]$_) }'),
        '[Console]::Out.WriteLine(''[GUARD] ''+([ordered]@{calls=@($global:T12ForbiddenCalls.ToArray())}|ConvertTo-Json -Compress))',
        'if($null -eq $global:LASTEXITCODE){throw ''Entry omitted explicit exit code.''};exit $global:LASTEXITCODE')) -join "`n"
    $path = Join-Path $testRoot ($Label + '-driver.ps1'); Write-NewText $path $text; Add-Fixture $path; return $path
}
function Invoke-Driver {
    param([string]$Path, [switch]$Preview)
    $info = New-Object Diagnostics.ProcessStartInfo; $info.FileName = $shellPath
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' + $Path + '"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$info.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info
    if(-not $Preview){$script:descendantReleaseProved=$false}
    Assert-True ($process.Start()) 'Owned entry child must start.'
    $child=[pscustomobject]@{process=$process;stdout_task=$process.StandardOutput.ReadToEndAsync();stderr_task=$process.StandardError.ReadToEndAsync();disposed=$false;timed_out=$false}
    $children.Add($child)
    if(-not $process.WaitForExit(60000)){$child.timed_out=$true;throw 'Short synthetic entry child timed out; retain exact tree because descendants are unproved.'}
    if(-not $child.stdout_task.Wait(5000) -or -not $child.stderr_task.Wait(5000)){$child.timed_out=$true;throw 'Child pipes failed bounded join; retain exact tree.'}
    $result=[pscustomobject]@{exit_code=$process.ExitCode;text=$child.stdout_task.GetAwaiter().GetResult()+"`n"+$child.stderr_task.GetAwaiter().GetResult()}
    $process.Dispose();$child.disposed=$true
    if(-not $Preview -and $result.exit_code -eq 0 -and $result.text -match '\[RESULT\] status=Completed;'){$script:descendantReleaseProved=$true}
    return $result
}
function Get-PlanRows { param([string]$Text); return @($Text -split '\r?\n' | Where-Object {$_ -match '^\[PLAN\] '} | ForEach-Object {$_.Substring(7)|ConvertFrom-Json}) }
function Assert-NoWritePreview {
    param([string]$Driver,[object]$Case,[int]$Code=0,[int]$Total=11,[int]$Excluded=1,[int]$Unsupported=2)
    $before=@(Get-TreeInventory $testRoot);$result=Invoke-Driver $Driver -Preview;$after=@(Get-TreeInventory $testRoot)
    $Case['inventory_before']=$before;$Case['inventory_after']=$after
    $Case['preview_diagnostics']=$result.text.Replace($testRoot,'<OWNED_TEMP>')
    $changes=@();foreach($entry in $before){$match=@($after|Where-Object{$_.relative_path -ceq $entry.relative_path})
        if($match.Count -ne 1 -or ($entry|ConvertTo-Json -Compress) -cne ($match[0]|ConvertTo-Json -Compress)){$changes+=[pscustomobject]@{relative_path=$entry.relative_path;before=$entry;after=$match}}
    };foreach($entry in $after){if(@($before|Where-Object{$_.relative_path -ceq $entry.relative_path}).Count -eq 0){$changes+=[pscustomobject]@{relative_path=$entry.relative_path;before=$null;after=$entry}}}
    $Case['inventory_changes']=$changes
    Assert-True (($before|ConvertTo-Json -Compress -Depth 8) -ceq ($after|ConvertTo-Json -Compress -Depth 8)) 'Preview must preserve complete owned-tree inventory including directories, hashes, modification times and attributes.'
    Assert-True ($result.exit_code -eq $Code) ('Unexpected preview exit: '+$result.exit_code+' '+$result.text.Replace($testRoot,'<OWNED_TEMP>'))
    $guard=@($result.text -split '\r?\n'|Where-Object{$_ -match '^\[GUARD\] '})
    Assert-True ($guard.Count -eq 1 -and @((($guard[0].Substring(8)|ConvertFrom-Json).calls)).Count -eq 0) 'Preview must invoke no guarded native/write/cover/prompt operations.'
    $plans=@(Get-PlanRows $result.text)
    if($Code -eq 0){
        Assert-True ($result.text -match ('\[RESULT\] status=Previewed; total='+$Total+'; processed=0; converted=0; failed=0; not_processed='+$Total+'; scan_excluded='+$Excluded+'; unsupported='+$Unsupported+';')) 'Successful preview must be distinct from conversion and retain honest counts.'
        Assert-True ($plans.Count -eq $Total) 'Preview must emit one JSON mapping per supported snapshot source.'
        foreach($row in $plans){Assert-True ($row.duration -ceq 'unknown' -and [IO.Path]::IsPathRooted($row.provisional_output_path) -and -not [IO.Path]::IsPathRooted($row.source_relative_path) -and -not [IO.Path]::IsPathRooted($row.output_relative_path)) 'Plan fields must distinguish relative mappings, provisional absolute paths and unknown duration.'}
        foreach($pattern in @('provisional','timestamp.*reservation.*(different|change)','[Dd]uration.*unknown','[Ww]ritability.*unverified','[Tt]ools.*media.*cover.*unverified','not reserved','not created during preview')){Assert-True ($result.text -match $pattern) ('Preview must label limitation '+$pattern)}
    }else{
        Assert-True ($result.text -match '\[RESULT\] status=FailedBeforeConversion;' -and $plans.Count -eq 0) 'Invalid/empty preview must fail before conversion and emit no partial plan.'
        Assert-True ($result.text -match 'not planned; preview made no reservation' -and $result.text -match 'not created during preview') 'Failed preview must explicitly report that no run/log was created.'
    }
    $Case['exit_code']=$result.exit_code;$Case['complete_inventory_equal']=$true
    $Case['guarded_operations_called']=0;$Case['plans_emitted']=$plans.Count
    $Case['plans']=@($plans|ForEach-Object{[pscustomobject]@{source_relative_path=$_.source_relative_path;output_relative_path=$_.output_relative_path;provisional_output_path=$_.provisional_output_path.Replace($testRoot,'<OWNED_TEMP>');duration=$_.duration}})
    return [pscustomobject]@{result=$result;plans=$plans}
}

try {
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop;Assert-NoReparse $tempParent;Assert-NoReparse $evidenceParent
    $ownedRootCreated=[AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot,[IntPtr]::Zero)
    Assert-True $ownedRootCreated 'TEMP root must be reserved exclusively.'
    $report.temp_exclusively_reserved=$true;Write-NewText $ownerFile $ownerToken;$report.marker_create_new=$true
    $report.owner_marker_sha256=(Get-FileHash -LiteralPath $ownerFile).Hash.ToLowerInvariant();$report.source_before=Get-SourceInventory
    $ffmpeg=(Resolve-Path -LiteralPath $FfmpegPath).ProviderPath;$ffprobe=(Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    $report['tools']=@($ffmpeg,$ffprobe|ForEach-Object{[pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant();version=(Invoke-RealSuccess $_ @('-version')).Stdout.Split([char]10)[0].Trim()}})
    $seedRoot=Join-Path $testRoot 'Seed';[IO.Directory]::CreateDirectory($seedRoot)|Out-Null
    foreach($extension in @('mp3','m4a','ogg')){
        $codec=switch($extension){'mp3'{'libmp3lame'};'m4a'{'aac'};'ogg'{'libvorbis'}};$path=Join-Path $seedRoot ('good.'+$extension)
        Invoke-RealSuccess $ffmpeg @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=733:sample_rate=44100','-t','0.25','-c:a',$codec,'-metadata','title=Synthetic preview fixture',$path)|Out-Null;Add-Fixture $path
    }
    $inputRoot=Join-Path $testRoot "Input [x] O'Brien & !%^";[IO.Directory]::CreateDirectory($inputRoot)|Out-Null
    $composed='caf'+[char]0xE9;$decomposed='cafe'+[char]0x301
    $names=@('2024-02-29 - Episode.mp3','2024-02-29 - Episode.m4a','2024-02-29 - Episode.ogg','2024-01-02 - A&B.mp3','2024-01-02 - AB.ogg',
        ('2024-01-02 - '+$composed+'.mp3'),('2024-01-02 - '+$decomposed+'.m4a'),'2023-02-29 - Impossible.ogg',"No date !% ^ O'Brien & [brackets].mp3",
        ("Sub [x] !% ^ O'Brien &\2024-03-01 - "+[char]0xDC+'nicode '+[char]0x6F22+[char]0x5B57+'.ogg'),
        'AudioForPhone_64kbps_20240101_000000\2024-03-02 - Prefix is ordinary.m4a')
    foreach($name in $names){$path=Join-Path $inputRoot $name;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null;[IO.File]::Copy((Join-Path $seedRoot ('good'+[IO.Path]::GetExtension($name))),$path,$false);[IO.File]::SetLastWriteTime($path,[datetime]::new(2023,6,7,12,34,56));Add-Fixture $path}
    foreach($name in @('notes.txt',('.AudioFileForPhone-'+('a'*32)+'.partial'))){$path=Join-Path $inputRoot $name;Write-NewText $path 'Synthetic unsupported sentinel';Add-Fixture $path}
    $prior=Join-Path $inputRoot 'Prior';[IO.Directory]::CreateDirectory($prior)|Out-Null
    $marker=Join-Path $prior '.AudioFileForPhone-output.json';Write-NewText $marker (([ordered]@{schema_version=1;kind='AudioFileForPhone.Output';output_root=$prior})|ConvertTo-Json);Add-Fixture $marker
    $excluded=Join-Path $prior 'excluded.mp3';[IO.File]::Copy((Join-Path $seedRoot 'good.mp3'),$excluded,$false);Add-Fixture $excluded
    $existingParent=Join-Path $testRoot 'Existing';[IO.Directory]::CreateDirectory($existingParent)|Out-Null
    $sentinel=Join-Path $existingParent 'existing.mp3';[IO.File]::Copy((Join-Path $seedRoot 'good.mp3'),$sentinel,$false);Add-Fixture $sentinel
    $guardedEntry=New-AppCopy 'guarded' -Guards;$plainEntry=New-AppCopy 'plain';$report.copied_entry_bytes_unchanged=$true
    Invoke-Case 'guarded preview ignores Interactive/invalid cover and preserves every directory/file property' 'A31' {
        param($case);$driver=New-Driver 'guarded' $guardedEntry $inputRoot $existingParent -Preview -Interactive -Cover (Join-Path $testRoot 'missing-cover.png')
        $observed=Assert-NoWritePreview $driver $case
        Assert-True ($observed.result.text -match '[Ii]nteractive.*ignored') 'Explicit Interactive must be labelled ignored without asking questions.'
        Assert-True (@($observed.plans|Where-Object{$_.source_relative_path -match '^Prior\\'}).Count -eq 0 -and @($observed.plans|Where-Object{$_.source_relative_path -match '^AudioForPhone_'}).Count -eq 1) 'Marked prior run must be excluded; ordinary prefix-sharing folder remains input.'
        Assert-True ($observed.result.text -match 'Invalid leading date; using LastWriteTime' -and
            $observed.result.text -match 'Title normalized to NFC' -and
            $observed.result.text -match 'whitelist removed') 'Preview must expose the actual date, normalization and sanitization warnings.'
        $case['interactive_ignored']=$true;$case['invalid_cover_explicitly_unverified']=$true;$case['marked_run_excluded_and_unmarked_prefix_included']=$true
    }
    Invoke-Case 'missing explicit destination and missing ancestor stay absent' 'A31' {
        param($case);$parent=Join-Path $testRoot 'Absent\Phone';$driver=New-Driver 'missing-parent' $guardedEntry $inputRoot $parent -Preview
        Assert-NoWritePreview $driver $case|Out-Null;Assert-True (-not(Test-Path -LiteralPath (Join-Path $testRoot 'Absent'))) 'Preview must not create destination ancestor.';$case['missing_parent_unchanged']=$true
    }
    Invoke-Case 'omitted destination uses only owned substituted Music resolver without creation' 'A31' {
        param($case);$parent=Join-Path $testRoot 'Owned Music';$driver=New-Driver 'default-resolver' $guardedEntry $inputRoot $parent -Preview -OmitOutputParent
        $observed=Assert-NoWritePreview $driver $case
        Assert-True (-not(Test-Path -LiteralPath $parent) -and @($observed.plans|Where-Object{-not(Test-AudioPathWithin -Path $_.provisional_output_path -Parent $parent)}).Count -eq 0) 'Default destination branch must use substituted exact synthetic resolver only.';$case['owned_resolver_substitution']=$true
    }
    Invoke-Case 'supported corrupt media is planned with unknown duration and no probe' 'A31,A32' {
        param($case);$corruptRoot=Join-Path $testRoot 'Corrupt';[IO.Directory]::CreateDirectory($corruptRoot)|Out-Null
        $corrupt=Join-Path $corruptRoot '2024-01-01 corrupt.mp3';Write-NewText $corrupt 'Synthetic non-audio MP3';Add-Fixture $corrupt
        $driver=New-Driver 'corrupt' $guardedEntry $corruptRoot (Join-Path $testRoot 'CorruptOut') -Preview
        Assert-NoWritePreview $driver $case -Total 1 -Excluded 0 -Unsupported 0|Out-Null;$case['media_validation_unverified_not_guessed']=$true
    }
    Invoke-Case 'empty unsupported-only preview fails without writes/native calls/partial plans' 'A31' {
        param($case);$empty=Join-Path $testRoot 'Empty';[IO.Directory]::CreateDirectory($empty)|Out-Null;$note=Join-Path $empty 'notes.txt';Write-NewText $note 'Synthetic empty scan';Add-Fixture $note
        $driver=New-Driver 'empty' $guardedEntry $empty (Join-Path $testRoot 'EmptyOut') -Preview
        $observed=Assert-NoWritePreview $driver $case -Code 1;Assert-True ($observed.result.text -match 'No MP3/M4A/OGG') 'Empty preview must retain actionable source error.'
    }
    Invoke-Case 'invalid output-parent file and invalid parameters fail without writes' 'A31' {
        param($case);$driver=New-Driver 'parent-file' $guardedEntry $inputRoot $sentinel -Preview
        $observed=Assert-NoWritePreview $driver $case -Code 1;Assert-True ($observed.result.text -match 'existing file') 'Existing output-parent file must reject clearly.'
        $second=[ordered]@{};$driver=New-Driver 'bad-limit' $guardedEntry $inputRoot (Join-Path $testRoot 'BadLimitOut') -Preview -Limit 23
        Assert-NoWritePreview $driver $second -Code 1|Out-Null;$case['invalid_limit_inventory_equal']=$second.complete_inventory_equal
    }
    Invoke-Case 'late complete-path budget failure emits no partial preview plans and writes nothing' 'A31,A32' {
        param($case);$deep=Join-Path $testRoot 'Deep';$directory=Join-Path $deep ('z'*140);[IO.Directory]::CreateDirectory($directory)|Out-Null
        foreach($path in @((Join-Path $deep '2024-01-01 First.mp3'),(Join-Path $directory '2024-01-02 Last.mp3'))){[IO.File]::Copy((Join-Path $seedRoot 'good.mp3'),$path,$false);Add-Fixture $path}
        $driver=New-Driver 'deep' $guardedEntry $deep (Join-Path $testRoot 'DeepOut') -Preview
        $observed=Assert-NoWritePreview $driver $case -Code 1;Assert-True ($observed.result.text -match 'File path is \d+ UTF-16 units; the supported limit is 259') 'Unsupported complete working path must reject visibly with the measured limit.'
    }
    Invoke-Case 'unchanged-input real MP3/M4A/OGG run matches preview relative allocations despite occupied provisional root' 'A32' {
        param($case);$driver=New-Driver 'real-plan' $plainEntry $inputRoot $existingParent -Preview
        $observed=Assert-NoWritePreview $driver $case
        $root=[IO.Path]::GetDirectoryName($observed.plans[0].provisional_output_path)
        $relative=$observed.plans[0].output_relative_path;$root=$observed.plans[0].provisional_output_path.Substring(0,$observed.plans[0].provisional_output_path.Length-$relative.Length).TrimEnd('\')
        Assert-True (Test-AudioPathWithin -Path $root -Parent $existingParent) 'Provisional root must stay inside owned destination.'
        [IO.Directory]::CreateDirectory($root)|Out-Null;$occupied=Join-Path $root 'occupied.txt';Write-NewText $occupied 'Synthetic writer occupying preview candidate';Add-Fixture $occupied
        $sourceBefore=@(Get-TreeInventory $inputRoot)
        $realDriver=New-Driver 'real' $plainEntry $inputRoot $existingParent
        $result=Invoke-Driver $realDriver
        Assert-True ($result.exit_code -eq 0 -and $result.text -match '\[RESULT\] status=Completed; total=11; processed=11; converted=11; failed=0; not_processed=0; scan_excluded=1; unsupported=2;') 'Subsequent real conversion must complete every planned valid source.'
        $sourceAfter=@(Get-TreeInventory $inputRoot);Assert-True (($sourceBefore|ConvertTo-Json -Compress -Depth 8) -ceq ($sourceAfter|ConvertTo-Json -Compress -Depth 8)) 'Real conversion must preserve source directories/file hashes/timestamps/attributes.'
        $runRoots=@(Get-ChildItem -LiteralPath $existingParent -Force|Where-Object{$_.PSIsContainer -and (Test-Path -LiteralPath (Join-Path $_.FullName '.AudioFileForPhone-output.json'))})
        Assert-True ($runRoots.Count -eq 1 -and $runRoots[0].FullName -cne $root -and [IO.File]::ReadAllText($occupied) -ceq 'Synthetic writer occupying preview candidate') 'Actual run must reserve another root and leave occupied provisional candidate unchanged.'
        $actualRoot=$runRoots[0].FullName;$tree=@(Get-SafeTree $actualRoot);$outputs=@($tree|Where-Object{-not $_.PSIsContainer -and $_.Extension -ieq '.mp3'})
        Assert-True ($outputs.Count -eq 11 -and @($tree|Where-Object{$_.Extension -ieq '.partial'}).Count -eq 0) 'Real run must publish exactly planned MP3s and no partials.'
        $log=[IO.File]::ReadAllText((Join-Path $actualRoot 'AudioFileForPhone_log.txt'))
        $actualMappings=@($log -split '\r?\n'|Where-Object{$_ -match '^\[OK\] OK\s*:'}|ForEach-Object{
            $match=[regex]::Match($_,"^\[OK\] OK\s*:\s*'(.+)' -> '(.+)'$")
            Assert-True $match.Success 'Every success log record must contain one exact quoted source/target mapping.'
            [pscustomobject]@{source=$match.Groups[1].Value;target=$match.Groups[2].Value}
        })
        Assert-True ($actualMappings.Count -eq 11) 'Actual run must record exactly eleven successful source/target mappings.'
        $mappings=@();foreach($row in $observed.plans){$target=Join-Path $actualRoot $row.output_relative_path;Assert-True (Test-Path -LiteralPath $target -PathType Leaf) 'Every preview relative mapping must equal a real published target.'
            $expectedSource=Join-Path $inputRoot $row.source_relative_path
            Assert-True (@($actualMappings|Where-Object{$_.source -ceq $expectedSource -and $_.target -ceq $target}).Count -eq 1) 'Each exact preview source must map to its actual logged target, including collision allocation.'
            $probe=(Invoke-RealSuccess $ffprobe @('-v','error','-show_entries','stream=codec_type,codec_name,bit_rate','-of','json',$target)).Stdout|ConvertFrom-Json
            $audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'});Assert-True ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000) 'Each published mapping must independently probe as 64 kbps MP3.'
            Invoke-RealSuccess $ffmpeg @('-nostdin','-v','error','-xerror','-i',$target,'-map','0:a:0','-f','null','NUL')|Out-Null
            $mappings+=[pscustomobject]@{source_relative_path=$row.source_relative_path;output_relative_path=$row.output_relative_path;sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant();fully_decoded=$true}
        }
        $case['actual_relative_mappings']=$mappings;$case['all_plans_published_and_decoded']=$true;$case['source_inventory_equal_after_real_run']=$true
        $case['exact_actual_logged_source_target_mappings_verified']=$true
        $case['provisional_root_occupied_and_preserved']=$true;$case['actual_root_differs_without_timestamp_guarantee']=$true
    }
    $report.status='pass';$exitCode=0
}
catch{$report.error=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>');$report['error_location']=$_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>');Write-Warning $report.error}
finally{
    $childrenStopped=$descendantReleaseProved
    foreach($child in $children){if($child.timed_out){$childrenStopped=$false};if($child.disposed){continue}
        try{if(-not $child.process.HasExited){$child.process.Kill()};Assert-True ($child.process.HasExited -or $child.process.WaitForExit(5000)) 'Owned child exit unproved.'
            Assert-True ($child.stdout_task.Wait(5000) -and $child.stderr_task.Wait(5000)) 'Owned pipe disposal unproved.'
            $null=$child.stdout_task.GetAwaiter().GetResult();$null=$child.stderr_task.GetAwaiter().GetResult();$child.process.Dispose();$child.disposed=$true
        }catch{$childrenStopped=$false;$report['child_cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    }
    $report.children_disposed=$childrenStopped
    foreach($inventory in @('source','synthetic')){try{$after=if($inventory -ceq 'source'){Get-SourceInventory}else{Get-FixtureInventory};$report[$inventory+'_after']=$after
        $same=(($report[$inventory+'_before']|ConvertTo-Json -Compress) -ceq ($after|ConvertTo-Json -Compress));$report[$inventory+'_unchanged']=$same;Assert-True $same "$inventory SHA256 must remain unchanged."
    }catch{$report.status='fail';$exitCode=1;$report[$inventory+'_verification_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}}
    try{if($ownedRootCreated -and $childrenStopped -and (Test-Path -LiteralPath $testRoot)){
        $resolved=(Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/');Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must resolve exactly to exclusive TEMP root.'
        Assert-NoReparse $resolved;Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires exact CreateNew token.';Get-SafeTree $resolved|Out-Null
        [IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved)
    };Assert-True $report.cleanup_verified 'Exact owned TEMP cleanup must be verified.'}catch{$report.status='fail';$exitCode=1;$report['cleanup_error']=$_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>')}
    if(-not $childrenStopped){$report.status='fail';$exitCode=1};$report['finished_utc']=[DateTime]::UtcNow.ToString('o');Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report|ConvertTo-Json -Depth 20)
}
Write-Host "T12 preview: $($report.status); cases=$($report.cases.Count); children=$($report.children_disposed); cleanup=$($report.cleanup_verified); source/synthetic=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
