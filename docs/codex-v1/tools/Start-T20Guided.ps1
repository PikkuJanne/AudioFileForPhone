<#
One owner command for the remaining physical T20 observations. All generated
drivers, raw output and aggregate results remain in a uniquely owned TEMP tree.
-ValidateOnly checks prepared bytes and parser compatibility without opening UI,
running the application, or creating files. No personal media is used here.
#>
[CmdletBinding()]
param(
    [string]$PreparationPath,
    [string]$Tester = 'Janne Vuorela',
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..')).TrimEnd('\', '/')
if ([string]::IsNullOrWhiteSpace($PreparationPath)) {
    $PreparationPath = Join-Path $projectRoot 'docs/codex-v1/evidence/T20-preparation-ps7.json'
}

function Assert-Guided {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Get-GuidedPath {
    param([string]$Path)
    Assert-Guided (-not [string]::IsNullOrWhiteSpace($Path)) 'An explicit path is required.'
    Assert-Guided ($Path -match '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])' -and -not $Path.StartsWith('\\?\') -and -not $Path.StartsWith('\\.\')) 'Only ordinary absolute filesystem paths are supported.'
    return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}
function Assert-GuidedNoReparse {
    param([string]$Path)
    $next = Get-GuidedPath $Path
    while ($next) {
        $item = Get-Item -LiteralPath $next -Force -ErrorAction Stop
        Assert-Guided (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse paths are refused: $next"
        $next = [IO.Path]::GetDirectoryName($next)
    }
}
function Assert-GuidedWithin {
    param([string]$Path, [string]$Parent)
    $canonical = Get-GuidedPath $Path; $scope = Get-GuidedPath $Parent
    Assert-Guided ($canonical.StartsWith($scope + '\', [StringComparison]::OrdinalIgnoreCase)) 'Path is outside the exact owned scope.'
    return $canonical
}
function Get-GuidedHash {
    param([string]$Path)
    Assert-GuidedNoReparse $Path
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-GuidedNew {
    param([string]$Path, [string]$Text, [switch]$Bom)
    Assert-GuidedWithin $Path $script:guidedRoot | Out-Null
    Assert-GuidedNoReparse ([IO.Path]::GetDirectoryName($Path))
    if($script:ownerMarkerHash){Assert-Guided ((Get-GuidedHash $script:ownerMarker) -ceq $script:ownerMarkerHash) 'Guided ownership marker changed.'}
    $encoding = New-Object Text.UTF8Encoding([bool]$Bom)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $preamble = $encoding.GetPreamble(); $bytes = $encoding.GetBytes($Text)
        if ($preamble.Length) { $stream.Write($preamble, 0, $preamble.Length) }
        $stream.Write($bytes, 0, $bytes.Length); $stream.Flush()
    } finally { $stream.Dispose() }
}
function Write-GuidedJson {
    param([string]$Path, [object]$Value)
    Write-GuidedNew $Path (($Value | ConvertTo-Json -Depth 18) + [Environment]::NewLine)
}
function ConvertTo-GuidedArguments {
    param([string[]]$Values)
    $quoted = foreach ($value in $Values) {
        Assert-Guided ($null -ne $value -and $value.IndexOf([char]0) -lt 0) 'Invalid native argument.'
        '"' + ([regex]::Replace([regex]::Replace($value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
    }
    return $quoted -join ' '
}
function Confirm-GuidedPreparation {
    Assert-GuidedNoReparse $script:preparationPathFull
    $actualReport = Get-GuidedPath $script:preparation.paths.report
    Assert-Guided ($actualReport -ieq (Join-Path $script:preparedRoot 'preparation.json')) 'Preparation names an unexpected local report.'
    Assert-Guided ((Get-GuidedHash $actualReport) -ceq (Get-GuidedHash $script:preparationPathFull)) 'Retained preparation report differs from its original.'
    Assert-Guided ($script:preparation.status -ceq 'prepared' -and $script:preparation.native_processes_released -and $script:preparation.source_bytes_unchanged) 'Preparation did not finish safely.'
    Assert-Guided ($script:preparation.ownership.exclusive_directory -and $script:preparation.ownership.retained_for_owner) 'Preparation has no exclusive retained ownership.'
    Assert-Guided ($script:preparedRoot -ieq (Get-GuidedPath $script:preparation.paths.root) -and
        (Split-Path -Parent $script:preparedRoot) -ieq (Get-GuidedPath $script:preparation.ownership.temp_parent) -and
        (Split-Path -Leaf $script:preparedRoot) -cmatch '^AudioFileForPhone-T20-Manual-[a-f0-9]{32}$') 'Preparation root identity is invalid.'
    $marker = Join-Path $script:preparedRoot '.t20-manual-owner'
    Assert-Guided ($marker -ieq (Get-GuidedPath $script:preparation.ownership.marker_path) -and
        (Get-GuidedHash $marker) -ceq $script:preparation.ownership.marker_sha256) 'Preparation ownership marker changed.'
    foreach ($name in @('application_directory', 'special_input', 'mixed_input', 'covers', 'output_parent')) {
        Assert-GuidedWithin $script:preparation.paths.$name $script:preparedRoot | Out-Null
        Assert-GuidedNoReparse $script:preparation.paths.$name
    }
    $expected = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat')
    Assert-Guided (@($script:preparation.sources).Count -eq 3) 'Expected three unchanged application copies.'
    foreach ($source in $script:preparation.sources) {
        Assert-Guided ($expected -ccontains $source.name) 'Unexpected application source record.'
        $current = Join-Path $projectRoot $source.name
        $copy = Join-Path $script:preparation.paths.application_directory $source.name
        Assert-Guided ($copy -ieq (Get-GuidedPath $source.copy_path) -and
            (Get-GuidedHash $copy) -ceq $source.copy_sha256 -and
            (Get-GuidedHash $current) -ceq $source.source_sha256 -and
            $source.copy_sha256 -ceq $source.source_sha256) 'Candidate or application copy changed; prepare affected acceptance again.'
    }
    foreach ($input in $script:preparation.inputs) {
        Assert-GuidedWithin $input.path $script:preparedRoot | Out-Null
        Assert-Guided ((Get-GuidedHash $input.path) -ceq $input.sha256) 'A prepared fixture changed.'
    }
    foreach ($tool in @($script:preparation.tools.ffmpeg, $script:preparation.tools.ffprobe)) {
        Assert-Guided ((Get-GuidedHash $tool.path) -ceq $tool.sha256) 'A selected external executable changed.'
    }
}

# The application and its helper stay unchanged. Only this separate test driver
# supplies the cover yes/no answer and predetermined metadata; actual picker
# selection/cancellation remains the owner's action in the original STA dialog.
$pickerDriver = @'
param([Parameter(Mandatory=$true)][string]$ConfigurationPath)
$ErrorActionPreference='Stop'
$configuration=Get-Content -Raw -Encoding UTF8 -LiteralPath $ConfigurationPath | ConvertFrom-Json
$started=[DateTime]::UtcNow.ToString('o')
$record=[ordered]@{kind='T20.GuidedPicker';label=$configuration.label;started_utc=$started;finished_utc=$null;
    command=[Environment]::CommandLine;launched_executable=$configuration.shell_path;
    shell_version=$PSVersionTable.PSVersion.ToString();shell_edition=$PSVersionTable.PSEdition;
    apartment=[Threading.Thread]::CurrentThread.GetApartmentState().ToString();execution_policy=@(Get-ExecutionPolicy -List | Select-Object Scope,ExecutionPolicy);
    prompt_automation='Test driver supplies yes only for the cover question and supplies Artist/Album parameters.';
    human_action_requested=$configuration.action;human_confirmation='pending';entry_before=$null;helper_before=$null;
    entry_after=$null;helper_after=$null;exit_code=$null;output_root=$null;status='failed';error=$null}
$writer=$null
function global:Read-Host {
    param([string]$Prompt)
    if($Prompt.StartsWith('Add album cover to output MP3 metadata?', [StringComparison]::Ordinal)) {return 'y'}
    throw ('Unexpected interactive prompt: '+$Prompt)
}
try {
    $markerHash=(Get-FileHash -LiteralPath $configuration.owner_marker -Algorithm SHA256).Hash.ToLowerInvariant()
    if($markerHash -cne $configuration.owner_marker_sha256){throw 'Guided owner marker changed.'}
    $record.entry_before=(Get-FileHash -LiteralPath $configuration.entry -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.helper_before=(Get-FileHash -LiteralPath $configuration.helper -Algorithm SHA256).Hash.ToLowerInvariant()
    if($record.entry_before -cne $configuration.entry_sha256 -or $record.helper_before -cne $configuration.helper_sha256){throw 'Application copies changed.'}
    if($record.apartment -cne 'STA'){throw 'The picker child is not STA.'}
    Write-Host ('T20 '+$configuration.label+' -- '+$configuration.instructions) -ForegroundColor Cyan
    if($configuration.action -eq 'Select'){Write-Host ('Select this file: '+$configuration.cover_path)}
    Write-Host 'Other prompts and verification are automatic. This window closes when the case finishes.'
    $stream=[IO.File]::Open($configuration.raw_path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $writer=New-Object IO.StreamWriter($stream,(New-Object Text.UTF8Encoding($false)))
    $global:LASTEXITCODE=$null
    & $configuration.entry -InputFolder $configuration.input_path -OutputParent $configuration.output_parent -Interactive -Artist $configuration.artist -Album $configuration.album *>&1 | ForEach-Object {
        $line=[string]$_;$writer.WriteLine($line);$writer.Flush();Write-Host $line
        if($line -match '^\[INFO\] Output root\s+:\s+(.+)$'){
            if($null -ne $record.output_root){throw 'Multiple output roots were reported.'}
            $record.output_root=$Matches[1]
        }
    }
    $record.exit_code=$global:LASTEXITCODE
    if($record.exit_code -ne 0 -or [string]::IsNullOrWhiteSpace($record.output_root)){throw 'Application did not complete with one reported root and exit 0.'}
    $record.status='captured'
}catch{$record.error=$_.Exception.Message}
finally{
    if($null -ne $writer){$writer.Dispose()}
    $record.entry_after=(Get-FileHash -LiteralPath $configuration.entry -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.helper_after=(Get-FileHash -LiteralPath $configuration.helper -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.finished_utc=[DateTime]::UtcNow.ToString('o')
    $json=($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $output=[IO.File]::Open($configuration.result_path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$output.Write($bytes,0,$bytes.Length)}finally{$output.Dispose()}
}
if($record.status -ne 'captured'){exit 1}
exit 0
'@

$preparationPathFull = Get-GuidedPath $PreparationPath
Assert-GuidedNoReparse $preparationPathFull
$preparation = Get-Content -Raw -Encoding UTF8 -LiteralPath $preparationPathFull | ConvertFrom-Json
$preparedRoot = Get-GuidedPath $preparation.ownership.root
Confirm-GuidedPreparation
$shells = @{
    ps51 = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    ps7 = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
}
foreach ($shell in $shells.Values) { Assert-GuidedNoReparse $shell }
$parseTokens=$null;$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseInput($pickerDriver,[ref]$parseTokens,[ref]$parseErrors)
Assert-Guided (@($parseErrors).Count -eq 0) 'Generated picker driver has syntax errors.'
if ($ValidateOnly) {
    [pscustomobject]@{status='validated';ui_launched=$false;application_run=$false;files_created=$false;
        shell=$PSVersionTable.PSVersion.ToString();edition=$PSVersionTable.PSEdition;
        preparation_sha256=(Get-GuidedHash $preparationPathFull);prepared_root=$preparedRoot;
        source_commit=$preparation.source_commit;picker_driver_parse_errors=@($parseErrors).Count}
    return
}
Assert-Guided (-not [Console]::IsInputRedirected) 'Start this guide in a genuine local console.'
Assert-Guided (-not [string]::IsNullOrWhiteSpace($Tester)) 'A named tester is required.'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
Assert-Guided (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'Use an ordinary non-elevated console for acceptance.'
. (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
Initialize-AudioDirectoryInterop
$guidedRoot=Join-Path $preparation.ownership.temp_parent ('T20G-'+[guid]::NewGuid().ToString('N').Substring(0,8))
Assert-GuidedNoReparse ([IO.Path]::GetDirectoryName($guidedRoot))
Assert-Guided ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($guidedRoot,[IntPtr]::Zero)) 'Could not exclusively reserve guided TEMP root.'
$ownerMarker=Join-Path $guidedRoot '.t20-guided-owner'
Write-GuidedNew $ownerMarker ([guid]::NewGuid().ToString('N'))
$ownerMarkerHash=Get-GuidedHash $ownerMarker
$entry=Join-Path $preparation.paths.application_directory 'AudioFileForPhone.ps1'
$helper=Join-Path $preparation.paths.application_directory 'AudioFileForPhone.Helpers.ps1'
$entryHash=Get-GuidedHash $entry;$helperHash=Get-GuidedHash $helper
$aggregate=[ordered]@{schema_version=1;kind='T20.GuidedPhysicalSession';tester=$Tester;
    started_utc=[DateTime]::UtcNow.ToString('o');finished_utc=$null;status='running';
    preparation_path=$preparationPathFull;preparation_sha256=(Get-GuidedHash $preparationPathFull);
    prepared_source_commit=$preparation.source_commit;owner_marker_sha256=$ownerMarkerHash;
    results_root=$guidedRoot;adjacent_external_tool_setup=@();bat=$null;picker_cases=@();cancellation_cases=@();
    native_verification=@();human_confirmation='pending';source_and_fixture_preserved=$false;
    cleanup='All guided/raw/results trees retained. BAT Music output is unknown and retained; no Music scan or cleanup.';
    limitations=@('BAT drag/drop is a named owner attestation only; actual selected shell/version, exit code and output root are not captured.',
        'Picker cover yes/no and Artist/Album values are supplied by the separate test driver; actual picker actions are physical.',
        'Successful application native release relies on unchanged runtime enforcement; verification natives have independent release results.');error=$null}
Write-GuidedJson (Join-Path $guidedRoot 'session-start.json') $aggregate
Write-Host ('T20 results stay at: '+$guidedRoot) -ForegroundColor Cyan

function Start-GuidedConsole {
    param([string]$Executable,[string[]]$Arguments)
    $oldModulePath=$env:PSModulePath;$hostProcess=$null
    try {
        # Remove inherited Core module paths only for this owned child launch.
        $env:PSModulePath=$null
        $hostProcess=Start-Process -FilePath $Executable -ArgumentList (ConvertTo-GuidedArguments $Arguments) -WorkingDirectory $projectRoot -WindowStyle Normal -PassThru
    } finally { $env:PSModulePath=$oldModulePath }
    try {$hostProcess.WaitForExit();return $hostProcess.ExitCode}
    finally {$hostProcess.Dispose()}
}
if (-not ('T20Guided.Deadline' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Threading;
namespace T20Guided { public sealed class Deadline : IDisposable {
    private readonly Timer timer;
    public Deadline(object context) { timer=new Timer(delegate {
        context.GetType().GetMethod("Request").Invoke(context,null);
    },null,30000,Timeout.Infinite); }
    public void Dispose(){timer.Dispose();}
} }
'@
}
function Invoke-GuidedVerificationNative {
    param([string]$Executable,[string[]]$Arguments)
    $context=New-AudioCancellationContext;$deadline=New-Object T20Guided.Deadline($context)
    try {
        $result=Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Cancellation $context -MaxStdoutChars 1048576 -MaxStderrChars 65536
        $aggregate.native_verification+= [pscustomobject]@{executable=$Executable;arguments=$Arguments;status=$result.Status;
            exit_code=$result.ExitCode;process_released=$result.ProcessReleased;elapsed_ms=$result.DurationMilliseconds;
            stdout_truncated=$result.StdoutTruncated;stderr_truncated=$result.StderrTruncated;error=$result.Error}
        Assert-Guided ($result.Status -ceq 'Completed' -and $result.ExitCode -eq 0 -and $result.ProcessReleased -and
            -not $result.StdoutTruncated -and -not $result.StderrTruncated) 'Independent probe/decode did not complete within its bound with released native process.'
        return $result
    } finally {$deadline.Dispose();$context.Dispose()}
}
function Get-GuidedTreeFiles {
    param([string]$Root)
    Assert-GuidedNoReparse $Root
    $pending=New-Object 'System.Collections.Generic.Stack[string]';$files=New-Object 'System.Collections.Generic.List[string]'
    $pending.Push($Root)
    while($pending.Count){foreach($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)){
        Assert-Guided (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Unexpected reparse entry in exact output scope.'
        if($item.PSIsContainer){$pending.Push($item.FullName)}else{$files.Add($item.FullName)}
    }}
    return $files.ToArray()
}
function Test-GuidedPickerOutput {
    param([object]$Capture,[object]$Configuration)
    Assert-Guided ($Capture.status -ceq 'captured' -and $Capture.exit_code -eq 0 -and $Capture.apartment -ceq 'STA' -and
        $Capture.entry_before -ceq $entryHash -and $Capture.entry_after -ceq $entryHash -and
        $Capture.helper_before -ceq $helperHash -and $Capture.helper_after -ceq $helperHash) 'Picker child did not capture a successful unchanged STA application run.'
    $expectedEdition=if($Configuration.label.StartsWith('PS51',[StringComparison]::Ordinal)){'Desktop'}else{'Core'}
    Assert-Guided ($Capture.shell_edition -ceq $expectedEdition) 'Actual picker shell edition differs from the requested case.'
    $outputRoot=Assert-GuidedWithin $Capture.output_root $Configuration.output_parent
    Assert-Guided ((Split-Path -Parent $outputRoot) -ieq $Configuration.output_parent) 'Reported run root is not a direct controlled child.'
    Assert-GuidedNoReparse $outputRoot
    $markerPath=Join-Path $outputRoot '.AudioFileForPhone-output.json'
    Assert-GuidedNoReparse $markerPath
    $identity=Get-Content -Raw -Encoding UTF8 -LiteralPath $markerPath|ConvertFrom-Json
    Assert-Guided ($identity.kind -ceq 'AudioFileForPhone.Output' -and $identity.output_root -ieq $outputRoot -and
        $identity.cleanup_scope -ieq $outputRoot -and $identity.ownership_token -cmatch '^[a-f0-9]{32}$') 'Output ownership marker is invalid.'
    $manifestPath=Join-Path $outputRoot 'AudioFileForPhone_manifest.json'
    Assert-GuidedNoReparse $manifestPath
    $manifest=Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath|ConvertFrom-Json
    Assert-Guided ($manifest.kind -ceq 'AudioFileForPhone.RunManifest' -and $manifest.run.output_root -ieq $outputRoot -and
        $manifest.run.exit_code -eq 0 -and $manifest.build.entry_sha256 -ceq $entryHash -and
        $manifest.build.helper_sha256 -ceq $helperHash -and @($manifest.records).Count -eq 3 -and
        $manifest.checkpoint -ceq 'Final' -and $manifest.totals.converted -eq 3 -and $manifest.totals.failed -eq 0) 'Manifest does not match the actual successful candidate/run.'
    $expectedCover=if($Configuration.action -ceq 'Select'){$Configuration.cover_path}else{$null}
    Assert-Guided ([string]$manifest.policies.metadata.cover_path -ceq [string]$expectedCover) 'Actual picker result differs from the requested physical action.'
    $rawText=Get-Content -Raw -Encoding UTF8 -LiteralPath $Configuration.raw_path
    Assert-Guided (-not $rawText.Contains('Could not open file picker.') -and -not $rawText.Contains('Selected cover failed validation:')) 'The picker failed or was unavailable; that cannot establish physical Cancel.'
    $files=@(Get-GuidedTreeFiles $outputRoot)
    Assert-Guided (@($files|Where-Object{[IO.Path]::GetExtension($_) -ieq '.partial'}).Count -eq 0) 'A partial remains after the successful picker run.'
    Assert-Guided (@($files|Where-Object{[IO.Path]::GetExtension($_) -ieq '.mp3'}).Count -eq 3) 'Output MP3 count differs from three controlled inputs.'
    $verified=@()
    foreach($row in $manifest.records){
        Assert-Guided ($row.status -ceq 'Converted') 'A picker manifest row did not convert.'
        $inputPath=Assert-GuidedWithin (Join-Path $Configuration.input_path $row.source_relative_path) $Configuration.input_path
        $outputPath=Assert-GuidedWithin (Join-Path $outputRoot $row.output_relative_path) $outputRoot
        $relativeDirectory=[IO.Path]::GetDirectoryName([string]$row.source_relative_path)
        $expectedDirectory=Split-Path -Leaf $Configuration.input_path
        if($relativeDirectory){$expectedDirectory=Join-Path $expectedDirectory $relativeDirectory}
        Assert-Guided ([IO.Path]::GetDirectoryName([string]$row.output_relative_path) -ieq $expectedDirectory -and
            [IO.Path]::GetFileName($outputPath) -cmatch '^\d{4}-\d{2}-\d{2} - .+\.mp3$') 'Relative layout or date-first output name changed.'
        Assert-GuidedNoReparse $inputPath;Assert-GuidedNoReparse $outputPath
        $probe=(Invoke-GuidedVerificationNative $preparation.tools.ffprobe.path @('-v','error','-show_streams','-show_format','-of','json',$outputPath)).Stdout|ConvertFrom-Json
        $sourceProbe=(Invoke-GuidedVerificationNative $preparation.tools.ffprobe.path @('-v','error','-show_streams','-show_format','-of','json',$inputPath)).Stdout|ConvertFrom-Json
        $sourceTitle=[string]$sourceProbe.format.tags.title
        if([string]::IsNullOrWhiteSpace($sourceTitle)){$sourceTitle=[string](@($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'audio'})[0].tags.title)}
        $audio=@($probe.streams|Where-Object{$_.codec_type -ceq 'audio'});$art=@($probe.streams|Where-Object{$_.codec_type -ceq 'video' -and $_.disposition.attached_pic -eq 1})
        $coverCount=if($Configuration.action -ceq 'Select'){1}else{0}
        Assert-Guided ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int]$audio[0].bit_rate -eq 64000 -and
            $art.Count -eq $coverCount -and $probe.format.tags.artist -ceq $Configuration.artist -and
            $probe.format.tags.album -ceq $Configuration.album -and $probe.format.tags.title -ceq $sourceTitle) 'Independent tags, artwork or 64 kbps audio probe differs.'
        $sourceAudio=@($sourceProbe.streams|Where-Object{$_.codec_type -ceq 'audio'})[0]
        $sourceSeconds=if($sourceAudio.duration){[double]::Parse([string]$sourceAudio.duration,[Globalization.CultureInfo]::InvariantCulture)}else{[double]::Parse([string]$sourceProbe.format.duration,[Globalization.CultureInfo]::InvariantCulture)}
        $outputSeconds=[double]::Parse([string]$audio[0].duration,[Globalization.CultureInfo]::InvariantCulture)
        Assert-Guided ($sourceSeconds -gt 0 -and $outputSeconds -gt 0 -and [math]::Abs($sourceSeconds-$outputSeconds) -le 0.35) 'Independent selected audio duration differs beyond the existing allowance.'
        if($coverCount){Assert-Guided ($art[0].width -eq 64 -and $art[0].height -eq 64) 'Selected prepared artwork dimensions differ.'}
        Invoke-GuidedVerificationNative $preparation.tools.ffmpeg.path @('-nostdin','-v','error','-xerror','-i',$outputPath,'-map','0:a:0','-f','null','NUL')|Out-Null
        if($coverCount){Invoke-GuidedVerificationNative $preparation.tools.ffmpeg.path @('-nostdin','-v','error','-xerror','-i',$outputPath,'-map','0:v:0','-frames:v','1','-f','null','NUL')|Out-Null}
        $verified+= [pscustomobject]@{source_relative_path=$row.source_relative_path;output_relative_path=$row.output_relative_path;
            source_sha256=(Get-GuidedHash $inputPath);output_sha256=(Get-GuidedHash $outputPath);bytes=(Get-Item -LiteralPath $outputPath).Length;
            source_duration_seconds=$sourceSeconds;duration_seconds=$outputSeconds;artwork_count=$art.Count;title=$probe.format.tags.title;artist=$probe.format.tags.artist;album=$probe.format.tags.album;
            independent_full_decode=$true}
    }
    return [pscustomobject]@{output_root=$outputRoot;ownership_marker_sha256=(Get-GuidedHash $markerPath);
        manifest_sha256=(Get-GuidedHash $manifestPath);outputs=$verified;status='automatically_verified';physical_confirmation='pending'}
}

try {
    # Explorer may reuse an existing process with its original PATH. Copy the
    # already-installed trusted tools beside the unchanged private app, where
    # production discovery looks first. These binary copies never enter Git.
    foreach($toolName in @('ffmpeg','ffprobe')){
        $installed=$preparation.tools.$toolName
        $adjacent=Assert-GuidedWithin (Join-Path $preparation.paths.application_directory ($toolName+'.exe')) $preparedRoot
        Confirm-GuidedPreparation
        $setup=[pscustomobject]@{tool=$toolName;installed_path=$installed.path;installed_version=$installed.version;
            private_copy_path=$adjacent;working_path=$null;sha256=$installed.sha256;created_this_session=$false;status='pending';
            provenance='Copy of existing installed external executable; no download, global PATH change, production package change or Git binary.'}
        $aggregate.adjacent_external_tool_setup+= $setup
        if(Test-Path -LiteralPath $adjacent){
            Assert-Guided ((Get-GuidedHash $adjacent) -ceq $installed.sha256) 'Existing private adjacent tool differs; refusing overwrite.'
            $setup.status='existing_copy_hash_verified'
        }else{
            Assert-GuidedNoReparse $preparation.paths.application_directory
            $working=Assert-GuidedWithin ($adjacent+'.'+[guid]::NewGuid().ToString('N')+'.work') $preparedRoot
            $setup.working_path=$working;$setup.status='working_copy_pending'
            [IO.File]::Copy($installed.path,$working,$false)
            Assert-Guided ((Get-GuidedHash $working) -ceq $installed.sha256) 'Private working executable differs; retaining the recognizable work file.'
            Assert-GuidedNoReparse $preparation.paths.application_directory
            [IO.File]::Move($working,$adjacent)
            $setup.created_this_session=$true;$setup.status='published_verified_copy'
        }
        Assert-Guided ((Get-GuidedHash $adjacent) -ceq $installed.sha256) 'Private adjacent tool copy differs.'
    }
    Write-Host 'First: drag the mixed valid/corrupt synthetic folder onto AudioFileForPhone.bat in the other Explorer window.' -ForegroundColor Cyan
    Write-Host 'Press Enter for the three optional metadata questions. Expected final message: Completed with failures. The corrupt fixture is deliberate. Press a key to close that window.'
    Write-Host ('Folder to drag: '+$preparation.paths.mixed_input)
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList (ConvertTo-GuidedArguments @($preparation.paths.application_directory)) | Out-Null
    Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList (ConvertTo-GuidedArguments @((Split-Path -Parent $preparation.paths.mixed_input))) | Out-Null
    $batObservation=Read-Host 'Return here: type FAILURES if the BAT showed Completed with failures, or type its actual message/error'
    $aggregate.bat=[ordered]@{tester=$Tester;observed_utc=[DateTime]::UtcNow.ToString('o');owner_observation=$batObservation;
        status='owner_attestation_pending_final_confirmation';expected_visible_message='Completed with failures';
        selected_shell=$null;shell_version=$null;exit_code=$null;output_root=$null;music_output_retained=$true;
        capture_limit='No instrumentation or output capture. No Music inspection or cleanup.'}
    $driverPath=Join-Path $guidedRoot 'picker.ps1';Write-GuidedNew $driverPath $pickerDriver -Bom
    $cases=@(@{label='PS51Select';shell='ps51';action='Select'},@{label='PS51Cancel';shell='ps51';action='Cancel'},
        @{label='PS7Select';shell='ps7';action='Select'},@{label='PS7Cancel';shell='ps7';action='Cancel'})
    $caseIndex=0
    foreach($case in $cases){
        $caseIndex++;$outputParent=Join-Path $guidedRoot ('O'+$caseIndex)
        Assert-Guided ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($outputParent,[IntPtr]::Zero)) 'Could not exclusively create case output parent.'
        $configuration=[ordered]@{label=$case.label;action=$case.action;
            instructions= $(if($case.action -ceq 'Select'){'Use the dialog to select the printed PNG cover.'}else{'Click Cancel in the cover dialog.'});
            shell_path=$shells[$case.shell];entry=$entry;helper=$helper;entry_sha256=$entryHash;helper_sha256=$helperHash;
            owner_marker=$ownerMarker;owner_marker_sha256=$ownerMarkerHash;input_path=$preparation.paths.special_input;
            output_parent=$outputParent;cover_path=$preparation.paths.valid_png_cover;
            artist='T20 guided synthetic artist';album='T20 guided synthetic album';
            raw_path=(Join-Path $guidedRoot ($case.label+'.log'));result_path=(Join-Path $guidedRoot ($case.label+'.json'))}
        $configurationPath=Join-Path $guidedRoot ($case.label+'-config.json');Write-GuidedJson $configurationPath $configuration
        $launchArguments=@('-NoLogo','-NoProfile','-Sta','-ExecutionPolicy','RemoteSigned','-File',$driverPath,'-ConfigurationPath',$configurationPath)
        Write-Host ('Next window: '+$case.label+' -- '+$configuration.instructions) -ForegroundColor Cyan
        $childExit=Start-GuidedConsole $shells[$case.shell] $launchArguments
        Assert-Guided ($childExit -eq 0 -and [IO.File]::Exists($configuration.result_path)) 'Picker host failed or its capture is missing. Retain the known scope; no native cleanup is guessed.'
        $capture=Get-Content -Raw -Encoding UTF8 -LiteralPath $configuration.result_path|ConvertFrom-Json
        $verification=Test-GuidedPickerOutput $capture ([pscustomobject]$configuration)
        $aggregate.picker_cases+= [pscustomobject]@{label=$case.label;launch_executable=$shells[$case.shell];launch_arguments=$launchArguments;
            host_exit_code=$childExit;capture=$capture;capture_sha256=(Get-GuidedHash $configuration.result_path);
            raw_sha256=(Get-GuidedHash $configuration.raw_path);verification=$verification}
        Confirm-GuidedPreparation
    }
    $evidenceParent=Join-Path $projectRoot 'docs/codex-v1/evidence'
    Assert-GuidedNoReparse $evidenceParent
    foreach($edition in @('ps51','ps7')){
        $number=21
        do{$freshPath=Join-Path $evidenceParent ('T16-cancellation-'+$edition+'-manual'+$number+'.json');$number++}
        while([IO.File]::Exists($freshPath) -or [IO.Directory]::Exists($freshPath))
        $launchArguments=@('-NoLogo','-NoProfile','-ExecutionPolicy','RemoteSigned','-File',(Join-Path $projectRoot 'tests/Test-Cancellation.ps1'),
            '-Manual','-EvidencePath',$freshPath,'-FfmpegPath',$preparation.tools.ffmpeg.path,'-FfprobePath',$preparation.tools.ffprobe.path)
        Write-Host ('Next window: '+$edition+' Ctrl+C. Wait for READY, then physically press Ctrl+C once.') -ForegroundColor Cyan
        $childExit=Start-GuidedConsole $shells[$edition] $launchArguments
        Assert-Guided ([IO.File]::Exists($freshPath)) 'Cancellation report missing; retain all known scope and do not claim child cleanup.'
        $rawHash=Get-GuidedHash $freshPath;$raw=Get-Content -Raw -Encoding UTF8 -LiteralPath $freshPath|ConvertFrom-Json
        Assert-Guided ($raw.schema_version -eq 1 -and $raw.task -ceq 'T16' -and $raw.mode -ceq 'physical_manual_console_ctrl_c' -and
            $raw.manual_requested -and $raw.command.Contains((Split-Path -Leaf $freshPath))) 'Fresh cancellation report identity is unexpected; leave it in place.'
        $destination=Assert-GuidedWithin (Join-Path $guidedRoot (Split-Path -Leaf $freshPath)) $guidedRoot
        Assert-Guided ((Split-Path -Parent (Get-GuidedPath $freshPath)) -ieq (Get-GuidedPath $evidenceParent) -and
            -not (Test-Path -LiteralPath $destination) -and (Get-GuidedHash $freshPath) -ceq $rawHash) 'Exact new report relocation boundaries or bytes changed.'
        Move-Item -LiteralPath $freshPath -Destination $destination -ErrorAction Stop
        Assert-Guided ((Get-GuidedHash $destination) -ceq $rawHash -and -not [IO.File]::Exists($freshPath)) 'Relocated raw report bytes differ.'
        $aggregate.cancellation_cases+= [pscustomobject]@{edition=$edition;launch_executable=$shells[$edition];launch_arguments=$launchArguments;
            host_exit_code=$childExit;original_report_path=$freshPath;retained_report_path=$destination;sha256=$rawHash;
            original_task=$raw.task;original_acceptance='A29';original_tested_commit=$raw.tested_commit;
            status=$raw.status;physical_manual_ctrl_c=$raw.physical_manual_ctrl_c;source_unchanged=$raw.source_unchanged;
            synthetic_unchanged=$raw.synthetic_unchanged;children_disposed=$raw.children_disposed;cleanup_verified=$raw.cleanup_verified;
            physical_confirmation='pending'}
        Assert-Guided ($childExit -eq 0 -and $raw.status -ceq 'pass' -and $raw.physical_manual_ctrl_c -and
            $raw.source_unchanged -and $raw.synthetic_unchanged -and $raw.children_disposed -and $raw.cleanup_verified) 'Cancellation assertions failed; raw report preserved outside Git.'
    }
    Confirm-GuidedPreparation;$aggregate.source_and_fixture_preserved=$true
    Write-Host 'The automatic output and cancellation checks completed.' -ForegroundColor Green
    $confirmation=Read-Host 'If YOU performed the BAT drop, all four picker actions, and both READY Ctrl+C keypresses, type DONE; otherwise describe what remains'
    $aggregate.human_confirmation=$confirmation
    if($confirmation -ieq 'DONE' -and $batObservation -ieq 'FAILURES'){
        $aggregate.status='owner_confirmed_with_automatic_proof'
        $aggregate.bat.status='owner_attested';foreach($row in $aggregate.picker_cases){$row.verification.physical_confirmation='owner_confirmed'}
        foreach($row in $aggregate.cancellation_cases){$row.physical_confirmation='owner_confirmed'}
    }else{$aggregate.status='manual_confirmation_incomplete'}
}catch{$aggregate.status='failed';$aggregate.error=$_.Exception.Message;Write-Warning $aggregate.error}
finally{
    $aggregate.finished_utc=[DateTime]::UtcNow.ToString('o')
    $reportPath=Join-Path $guidedRoot 'guided-result.json';Write-GuidedJson $reportPath $aggregate
    Write-Host ('T20 guided result: '+$aggregate.status+'; report: '+$reportPath)
    Write-Host 'Keep all these files for verification. Unknown BAT Music output was not inspected or removed.'
}
if($aggregate.status -ne 'owner_confirmed_with_automatic_proof'){exit 1}
exit 0
