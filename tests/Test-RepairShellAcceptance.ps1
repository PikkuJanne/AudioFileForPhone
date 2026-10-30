<#
.SYNOPSIS
Verify an exact repair ZIP through its unchanged BATs in controlled native consoles.
.DESCRIPTION
Uses DirectLauncher.Console.cs, owned child profiles and synthetic two-second audio.
The real converter receives no output/config override: an initial guarded identity
check and unmodified DryRun must first prove its default Music destination is owned.
Real setup selects an existing external pair and remembers only the owned default
config. Enter starts the converter; SetupCancel exercises the real setup menu/Q.
This is controlled native-console proof, not genuine Explorer conversion or folder
picker proof. All PS1 Internet marks are deterministic ADS, not browser extraction.
No download, registry/persistent environment/policy change or publication occurs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RuntimeZipPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedZipSha256,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory=$true)][string]$EvidencePath,
    [Parameter(Mandatory=$true)][string]$FfmpegDirectory,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$ExpectedAppVersion='1.0.2'
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$zipPath=[IO.Path]::GetFullPath($RuntimeZipPath);$evidence=[IO.Path]::GetFullPath($EvidencePath)
$evidenceParent=[IO.Path]::GetDirectoryName($evidence)
$runRoot=Join-Path $evidenceParent ('R3-shell-'+[guid]::NewGuid().ToString('N'))
$dataRoot=Join-Path $runRoot 'owned-data';$rawRoot=Join-Path $runRoot 'raw'
$packageRoot=Join-Path $dataRoot ('relocated app '+[char]0x00e4)
$working=Join-Path $dataRoot ('unrelated cwd '+[char]0x00f6)
$ownedProfile=Join-Path $dataRoot 'owned-profile';$music=Join-Path $ownedProfile 'Music'
$marker=Join-Path $runRoot '.R3-shell-owner';$token=[guid]::NewGuid().ToString('N')
$realSystemRoot=$env:SystemRoot;$winps=Join-Path $realSystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$cmd=Join-Path $realSystemRoot 'System32/cmd.exe';$csc=Join-Path $realSystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$controllerSource=Join-Path $PSScriptRoot 'DirectLauncher.Console.cs';$controller=Join-Path $dataRoot 'console-controller.exe'
$ffmpeg=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffmpeg.exe'
$ffprobe=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffprobe.exe'
$FfmpegDirectory=[IO.Path]::GetDirectoryName($ffmpeg)
$created=$false;$releaseProved=$true;$exitCode=1;$packageBefore=@();$sourceBefore=@();$toolHashes=@()
$parentBefore=@{};foreach($name in @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','TMP','PATH','PSModulePath','SystemRoot')){$parentBefore[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$policiesBefore=@(Get-ExecutionPolicy -List|ForEach-Object{[pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy}})
$report=[ordered]@{schema_version=1;task='R3';kind='exact_package_controlled_native_shell_acceptance';status='FAILED';started_utc=[DateTime]::UtcNow.ToString('o');command=[Environment]::CommandLine;expected_source_commit=$ExpectedSourceCommit;runtime_zip_sha256=$ExpectedZipSha256;app_version=$ExpectedAppVersion;environment=$null;cases=@();processes=@();native_cases=@();app_runs=@();package_members=@();source_bindings=@();child_identity=$null;internet_marks='Deterministic Zone.Identifier ADS on all extracted PS1 files; not browser extraction.';genuine_explorer_conversion='NOT_TESTED';physical_folder_browser_selection='NOT_TESTED';ordinary_music_access=$false;owner_media_access=$false;user_config_read_or_written=$false;owned_default_config_written=$false;downloads_performed=$false;publication_performed=$false;owner_testing_required='none';source_unchanged=$false;package_unchanged=$false;dependencies_unchanged=$false;harness_unchanged=$false;policies_unchanged=$false;parent_environment_unchanged=$false;descendant_release_proved=$false;cleanup_verified=$false;raw_evidence_root=$rawRoot}
function Assert-Shell([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash-Shell([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Assert-ShellNoReparse([string]$Path){$cursor=[IO.Path]::GetFullPath($Path);while($cursor){if(Test-Path -LiteralPath $cursor){Assert-Shell (((Get-Item -LiteralPath $cursor -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)-eq 0) 'Reparse path refused.'};$cursor=[IO.Path]::GetDirectoryName($cursor)}}
function Inventory-Shell([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{Assert-Shell (($_.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq 0) 'Reparse member refused.';[pscustomobject]@{path=$_.FullName.Substring($Root.TrimEnd('\','/').Length+1).Replace('\','/');bytes=$_.Length;sha256=Hash-Shell $_.FullName}})}
function Write-ShellNew([string]$Path,[string]$Text){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=(New-Object Text.UTF8Encoding($false)).GetBytes($Text);$s.Write($b,0,$b.Length)}finally{$s.Dispose()}}
function Quote-Shell([AllowEmptyString()][string]$Value){
    Assert-Shell ($Value.IndexOf([char]0)-lt 0) 'NUL argument refused.'
    $q='"';$slashes=0;foreach($c in $Value.ToCharArray()){if($c-eq'\'){$slashes++;continue};if($c-eq'"'){$q+=('\'*($slashes*2+1))+'"'}else{$q+=('\'*$slashes)+$c};$slashes=0};$q+('\'*($slashes*2))+'"'
}
function New-ShellEnvironment([string]$ChildProfile){
    $environment=@{USERPROFILE=$ChildProfile;LOCALAPPDATA=(Join-Path $ChildProfile 'AppData/Local');APPDATA=(Join-Path $ChildProfile 'AppData/Roaming');TEMP=(Join-Path $ChildProfile 'AppData/Local/Temp');TMP=(Join-Path $ChildProfile 'AppData/Local/Temp');PATH='';PSModulePath=(Join-Path $realSystemRoot 'System32/WindowsPowerShell/v1.0/Modules')}
    foreach($p in @($ChildProfile,(Join-Path $ChildProfile 'Music'),$environment.LOCALAPPDATA,$environment.APPDATA,$environment.TEMP)){[IO.Directory]::CreateDirectory($p)|Out-Null};return $environment
}
function Invoke-ShellProcess([string]$Executable,[string[]]$Arguments,[string]$Label,[hashtable]$Environment=@{},[int[]]$AllowedCodes=@(0),[int]$DeadlineMilliseconds=90000){
    $si=New-Object Diagnostics.ProcessStartInfo;$si.FileName=$Executable;$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.WorkingDirectory=$working
    $si.Arguments=(@($Arguments|ForEach-Object{Quote-Shell $_})-join' ');$si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
    $si.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$si.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    foreach($key in $Environment.Keys){$si.EnvironmentVariables[$key]=[string]$Environment[$key]}
    $p=New-Object Diagnostics.Process;$p.StartInfo=$si;$started=$false
    try{
        Assert-Shell ($p.Start()) 'Owned process did not start.';$started=$true;$p.StandardInput.Close();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit($DeadlineMilliseconds)){$script:releaseProved=$false;$p.Kill();$null=$p.WaitForExit(5000);throw ('Owned short-fixture deadline: '+$Label+'; retain data because descendant release is unproved.')}
        if(-not $out.Wait(5000)-or -not $err.Wait(5000)){$script:releaseProved=$false;throw ('Owned process pipes did not close: '+$Label)}
        $stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult();$code=$p.ExitCode
        $stem=('{0:D3}-{1}'-f($report.processes.Count+1),$Label);$op=Join-Path $rawRoot ($stem+'.stdout.txt');$ep=Join-Path $rawRoot ($stem+'.stderr.txt')
        Write-ShellNew $op $stdout;Write-ShellNew $ep $stderr
        $report.processes+=[pscustomobject]@{label=$Label;executable=$Executable;arguments=$Arguments;exit_code=$code;natural_exit=$true;pipes_drained=$true;stdout_sha256=Hash-Shell $op;stderr_sha256=Hash-Shell $ep}
        Assert-Shell ($AllowedCodes-contains$code) ('Unexpected '+$Label+' exit '+$code+'; see retained capture '+$stem)
        return [pscustomobject]@{stdout=$stdout;stderr=$stderr;exit_code=$code}
    }catch{if($started){try{if(-not$p.HasExited){$script:releaseProved=$false}}catch{$script:releaseProved=$false}};throw}finally{$p.Dispose()}
}
function Add-ShellCase([string]$Id,[string]$Observed){$report.cases+=[pscustomobject]@{id=$Id;status='PASSED';observed=$Observed}}
$identityCommand=@'
$i=[Security.Principal.WindowsIdentity]::GetCurrent();$p=New-Object Security.Principal.WindowsPrincipal($i)
[ordered]@{music=[Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic,[Environment+SpecialFolderOption]::DoNotVerify);local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,[Environment+SpecialFolderOption]::DoNotVerify);profile=$env:USERPROFILE;path=$env:PATH;cwd=(Get-Location).ProviderPath;process64=[Environment]::Is64BitProcess;shell_version=$PSVersionTable.PSVersion.ToString();is_admin=$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}|ConvertTo-Json -Compress
'@
function Test-ShellIdentity([hashtable]$Environment,[string]$Label){
    $r=Invoke-ShellProcess $winps @('-NoLogo','-NoProfile','-NonInteractive','-STA','-ExecutionPolicy','Bypass','-Command',$identityCommand) $Label $Environment
    $i=$r.stdout|ConvertFrom-Json
    Assert-Shell ($i.profile-ceq$Environment.USERPROFILE-and$i.music-ceq(Join-Path $Environment.USERPROFILE 'Music')-and$i.local-ceq$Environment.LOCALAPPDATA-and$i.path-ceq''-and$i.cwd-ceq$working-and$i.process64-and-not$i.is_admin) 'Owned child identity/default folders were not proved; refuse application execution.'
    return $i
}
function New-ShellPackage([string]$Destination){
    Assert-Shell (-not(Test-Path -LiteralPath $Destination)) 'Fresh package extraction required.'
    [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$Destination)
    foreach($file in @(Get-ChildItem -LiteralPath $Destination -File -Recurse|Where-Object{$_.Extension-ceq'.ps1'})){
        Set-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
        Assert-Shell (([string](Get-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Raw)).Contains('ZoneId=3')) 'Internet mark missing.'
    };return $Destination
}
function Invoke-ShellBat([string]$Label,[string]$Bat,[string[]]$Folders,[int]$ExpectedExit,[string]$Mode='',[hashtable]$ExtraEnvironment=@{},[string]$ExpectedText=''){
    $environment=@{};foreach($key in $childEnvironment.Keys){$environment[$key]=$childEnvironment[$key]};$environment.AFP_R3_BAT=$Bat
    $command='"%AFP_R3_BAT%"'
    for($n=0;$n-lt$Folders.Count;$n++){$environment['AFP_R3_ARG'+$n]=$Folders[$n];$command+=' "%AFP_R3_ARG'+$n+'%"'}
    foreach($key in $ExtraEnvironment.Keys){$environment[$key]=$ExtraEnvironment[$key]}
    $nativePath=Join-Path $rawRoot ($Label+'-console.json')
    $arguments=@($cmd,('/d /v:off /s /c "'+$command+'"'),$working,$nativePath,'180000');if($Mode){$arguments+=$Mode}
    $null=Invoke-ShellProcess $controller $arguments $Label $environment @(0) 205000
    Assert-Shell ([IO.File]::Exists($nativePath)) 'Native console report missing.'
    $native=Get-Content -LiteralPath $nativePath -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not$native.owned_tree_released){$script:releaseProved=$false}
    Assert-Shell ([string]::IsNullOrEmpty($native.error)-and$native.pause_seen-and$native.still_waiting_before_key-and$native.key_injected-and$native.owned_tree_released-and$native.exit_code-eq$ExpectedExit) ('Native pause/wait/key/exit/release contract failed: '+$Label)
    if($Mode){Assert-Shell ($native.initial_menu_key_sent-and$native.initial_menu_mode-ceq$Mode) 'Initial menu key/mode not proved.'}
    if($ExpectedText){Assert-Shell ($native.text-match$ExpectedText) ('Actionable native diagnostic missing: '+$Label)}
    $report.native_cases+=[pscustomobject]@{label=$Label;expected_exit=$ExpectedExit;mode=$Mode;report_filename=[IO.Path]::GetFileName($nativePath);report_sha256=Hash-Shell $nativePath;pause_seen=$native.pause_seen;still_waiting_before_key=$native.still_waiting_before_key;key_injected=$native.key_injected;initial_menu_key_sent=$(if($Mode){[bool]$native.initial_menu_key_sent}else{$false});owned_tree_released=$native.owned_tree_released;exit_code=$native.exit_code}
    return $native
}
function Verify-ShellRun([string]$Label,[string[]]$BeforeRuns,[int]$Total,[int]$Converted,[int]$Failed,[object]$Native){
    $new=@(Get-ChildItem -LiteralPath $music -Directory|Where-Object{$BeforeRuns-cnotcontains$_.FullName})
    Assert-Shell ($new.Count-eq 1) 'Exactly one new owned default-Music run required.';$root=$new[0].FullName
    $manifestPath=Join-Path $root 'AudioFileForPhone_manifest.json';$logPath=Join-Path $root 'AudioFileForPhone_log.txt'
    $m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    $expectedStatus=if($Failed){'CompletedWithFailures'}else{'Completed'};$expectedExit=if($Failed){2}else{0}
    Assert-Shell ($m.app_version-ceq$ExpectedAppVersion-and$m.run.status-ceq$expectedStatus-and$m.run.exit_code-eq$expectedExit-and$m.policies.bitrate_kbps-eq 64-and$m.tools.selection_origin-ceq'Saved'-and$m.totals.converted-eq$Converted-and$m.totals.failed-eq$Failed-and$m.records.Count-eq$Total) 'Actual BAT conversion manifest/count/default/version mismatch.'
    Assert-Shell (@($m.records|Where-Object{$_.status-ceq'Converted'}).Count-eq$Converted-and@($m.records|Where-Object{$_.status-ceq'Failed'}).Count-eq$Failed) 'Per-file outcomes differ from totals.'
    $compact=$Native.text-replace'\s+','';Assert-Shell ($compact.Contains('AudioFileForPhonev'+$ExpectedAppVersion)-and$compact.Contains('converted='+$Converted+';failed='+$Failed)) 'Native console lacks truthful version/count summary.'
    $files=@(Get-ChildItem -LiteralPath $root -File -Recurse -Force);$outputs=@($files|Where-Object{$_.Extension-ceq'.mp3'})
    Assert-Shell ($outputs.Count-eq$Converted-and@($files|Where-Object{$_.Name-match'(?i)\.partial|\.working|\.tmp$'}).Count-eq 0) 'Published output/partial count mismatch.'
    $audioChecks=@();foreach($file in $outputs){
        $probe=(Invoke-ShellProcess $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$file.FullName) ($Label+'-probe')).stdout|ConvertFrom-Json
        $audio=@($probe.streams|Where-Object{$_.codec_type-ceq'audio'})
        Assert-Shell ($audio.Count-eq 1-and$audio[0].codec_name-ceq'mp3'-and[long]$audio[0].bit_rate-eq 64000-and[math]::Abs([double]::Parse([string]$probe.format.duration,[Globalization.CultureInfo]::InvariantCulture)-2)-lt 0.35) 'Independent MP3/rate/duration verification failed.'
        $null=Invoke-ShellProcess $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-err_detect','explode','-i',$file.FullName,'-map','0:a:0','-f','null','NUL') ($Label+'-full-decode')
        $audioChecks+=[pscustomobject]@{relative=$file.FullName.Substring($root.Length+1).Replace('\','/');sha256=Hash-Shell $file.FullName;codec='mp3';bitrate_bps=64000;fully_decoded=$true}
    }
    Assert-Shell ((Get-Content -LiteralPath $logPath -Raw -Encoding UTF8)-match('Summary: total='+$Total+', converted='+$Converted+', failed='+$Failed)) 'Detailed local log counts missing.'
    [IO.File]::Copy($manifestPath,(Join-Path $rawRoot ($Label+'-manifest.json')),$false);[IO.File]::Copy($logPath,(Join-Path $rawRoot ($Label+'-local-log.txt')),$false)
    $report.app_runs+=[pscustomobject]@{label=$Label;default_music_owned=$true;total=$Total;converted=$Converted;failed=$Failed;exit_code=$expectedExit;selection_origin='Saved';app_version=$m.app_version;manifest_sha256=Hash-Shell $manifestPath;audio=$audioChecks}
}
try{
    Assert-Shell ([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT) 'Windows execution required.'
    Assert-Shell ([IO.Directory]::Exists($evidenceParent)-and-not[IO.File]::Exists($evidence)-and-not$evidence.StartsWith($projectRoot+'\',[StringComparison]::OrdinalIgnoreCase)) 'Create-new raw evidence must be outside Git.'
    foreach($p in @($zipPath,$evidenceParent,$ffmpeg,$ffprobe,$controllerSource)){Assert-ShellNoReparse $p}
    Assert-Shell ([IO.File]::Exists($winps)-and[IO.File]::Exists($csc)-and[IO.File]::Exists($ffmpeg)-and[IO.File]::Exists($ffprobe)) 'Required existing host/compiler/tool pair unavailable.'
    Assert-Shell ((Hash-Shell $zipPath)-ceq$ExpectedZipSha256) 'Exact ZIP SHA256 mismatch.'
    $os=Get-CimInstance Win32_OperatingSystem;$cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=New-Object Security.Principal.WindowsPrincipal($identity)
    $admin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator);$adminGroup=@($identity.Groups|ForEach-Object{$_.Value})-contains'S-1-5-32-544'
    Assert-Shell (-not$admin-and-not$adminGroup-and$os.ProductType-eq 1) 'Acceptance requires an actual non-administrator Windows client account.'
    $report.environment=[ordered]@{caption=$os.Caption;product_type=$os.ProductType;display_version=$cv.DisplayVersion;build=$os.BuildNumber+'.'+$cv.UBR;architecture=$os.OSArchitecture;is_admin=$admin;administrators_group_sid_present=$adminGroup;orchestrator_shell=$PSVersionTable.PSVersion.ToString()}
    Assert-Shell (-not(Test-Path -LiteralPath $runRoot)) 'Owned root collision.';[IO.Directory]::CreateDirectory($runRoot)|Out-Null;$created=$true;Write-ShellNew $marker $token
    foreach($p in @($dataRoot,$rawRoot,$working)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $harnessBefore=@(Hash-Shell $PSCommandPath;Hash-Shell $controllerSource);$toolHashes=@(Hash-Shell $ffmpeg;Hash-Shell $ffprobe)
    $report.test_script_sha256=$harnessBefore[0];$report.controller_source_sha256=$harnessBefore[1];$report.dependencies=[ordered]@{ffmpeg_sha256=$toolHashes[0];ffprobe_sha256=$toolHashes[1];outside_child_path=$true}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $allow=@('AudioFileForPhone.bat','AudioFileForPhone.ico','README.txt','app/AudioFileForPhone.ps1','app/AudioFileForPhone.Helpers.ps1','app/AudioFileForPhone.ManagedSetup.ps1','app/AudioFileForPhone.Diagnostics.ps1','app/AudioFileForPhone.Checks.ps1','app/Check-AudioFileForPhone.ps1','app/tools/ffmpeg-download.json','app/Setup-AudioFileForPhone.ps1','app/Setup-AudioFileForPhone.bat','app/README.md','app/SUPPORT.md','app/CHANGELOG.md','app/SECURITY.md','app/LICENSE')
    $archive=[IO.Compression.ZipFile]::OpenRead($zipPath);try{$seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase);$expanded=0L;Assert-Shell ($archive.Entries.Count-eq 17) 'Expected seventeen-member clean package.';foreach($entry in $archive.Entries){$expanded+=$entry.Length;Assert-Shell ($entry.FullName-cin$allow-and$seen.Add($entry.FullName)-and$entry.Length-gt 0-and$entry.Length-le 4194304-and$expanded-le 16777216) 'Unexpected/duplicate/out-of-bounds package member.'}}finally{$archive.Dispose()}
    $null=New-ShellPackage $packageRoot;$packageBefore=Inventory-Shell $packageRoot;$report.package_members=$packageBefore
    . (Join-Path $PSScriptRoot '../tools/ReleaseGates.ps1')
    foreach($member in @($packageBefore|Where-Object{$_.path.StartsWith('app/')-and$_.path-cne'app/Setup-AudioFileForPhone.bat'})){$sourcePath=$member.path.Substring(4);$hash=Get-ReleaseGitBlobHash -RepositoryRoot $projectRoot -SourceCommit $ExpectedSourceCommit -RelativePath $sourcePath;Assert-Shell ($hash-ceq$member.sha256) ('Exact source binding mismatch: '+$sourcePath);$report.source_bindings+=[pscustomobject]@{source_path=$sourcePath;archive_path=$member.path;sha256=$hash}}
    Assert-Shell ((Hash-Shell (Join-Path $packageRoot 'AudioFileForPhone.ico'))-ceq(Get-ReleaseGitBlobHash -RepositoryRoot $projectRoot -SourceCommit $ExpectedSourceCommit -RelativePath 'AudioFileForPhone.ico')) 'Existing icon source binding mismatch.'
    $batText=[IO.File]::ReadAllText((Join-Path $packageRoot 'AudioFileForPhone.bat'))
    Assert-Shell ($batText.Contains('set "AFP_SCRIPT=%~dp0app\AudioFileForPhone.ps1"')-and$batText.Contains('-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File')-and$batText-notmatch'(?mi)^\s*call\b') 'Direct built-in NoProfile/STA BAT contract missing.'
    Add-ShellCase 'exact-package-source-and-marked-runtime' 'ZIP hash, seventeen allowlisted members, source bindings, existing icon and deterministic PS1 marks verified.'
    & $csc /nologo /target:exe ('/out:'+$controller) $controllerSource;Assert-Shell ($LASTEXITCODE-eq 0-and[IO.File]::Exists($controller)) 'Existing native controller did not compile.'
    $childEnvironment=New-ShellEnvironment $ownedProfile;$config=Join-Path $childEnvironment.LOCALAPPDATA 'AudioFileForPhone/config.json'
    $report.child_identity=Test-ShellIdentity $childEnvironment 'owned-child-identity'
    $single=Join-Path $dataRoot ('single input '+[char]0x00e4);$mixed=Join-Path $dataRoot ('mixed input '+[char]0x00f6)
    foreach($p in @($single,$mixed,(Join-Path $mixed 'nested'))){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $good=Join-Path $single '2024-01-02 Good.m4a';$null=Invoke-ShellProcess $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=44100:duration=2','-c:a','aac','-metadata','title=R3 shell synthetic',$good) 'synthetic-source'
    [IO.File]::Copy($good,(Join-Path $mixed 'nested/2024-01-02 Good.m4a'),$false);Write-ShellNew (Join-Path $mixed '2024-01-03 Bad.m4a') 'Synthetic corrupt M4A for controlled partial failure.'
    $sourceBefore=@([pscustomobject]@{root='single';files=Inventory-Shell $single};[pscustomobject]@{root='mixed';files=Inventory-Shell $mixed})
    $preview=Invoke-ShellProcess $winps @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/AudioFileForPhone.ps1'),'-InputFolder',$single,'-DryRun') 'unmodified-default-music-dryrun' $childEnvironment
    Assert-Shell ($preview.stdout.Contains($music)-and$preview.stdout-match'status=Previewed;'-and@(Get-ChildItem -LiteralPath $music -Force).Count-eq 0-and-not(Test-Path -LiteralPath $config)) 'Unmodified preview did not prove owned default Music without app writes.'
    Add-ShellCase 'guarded-owned-default-music-preview' 'Normal NoProfile host and unmodified app DryRun resolve owned Music; no output/config; host caches may exist only in owned profile.'
    $null=Invoke-ShellProcess $winps @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/Setup-AudioFileForPhone.ps1'),'-FfmpegDirectory',$FfmpegDirectory,'-Remember','-NonInteractive') 'real-setup-existing-pair-remember' $childEnvironment
    Assert-Shell ([IO.File]::Exists($config)) 'Real setup did not write the owned default config.';$saved=Get-Content -LiteralPath $config -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-Shell ($saved.ffmpeg_directory-ieq$FfmpegDirectory) 'Saved exact external tools directory mismatch.';$configHash=Hash-Shell $config;$report.owned_default_config_written=$true
    Add-ShellCase 'real-setup-ps1-existing-selection-ready0' 'Marked real Setup PS1 validated external tools and deliberately remembered only owned default config; no download.'
    $beforeRuns=@(Get-ChildItem -LiteralPath $music -Directory|ForEach-Object{$_.FullName});$n=Invoke-ShellBat 'happy-single-bat' (Join-Path $packageRoot 'AudioFileForPhone.bat') @($single) 0 'Enter';Verify-ShellRun 'happy-single-bat' $beforeRuns 1 1 0 $n
    Add-ShellCase 'native-bat-single-default64' 'Real unchanged root BAT, menu Enter, validated default64 MP3 in owned default Music; pause/wait/key/exit0/release.'
    $beforeRuns=@(Get-ChildItem -LiteralPath $music -Directory|ForEach-Object{$_.FullName});$n=Invoke-ShellBat 'partial-batch-bat' (Join-Path $packageRoot 'AudioFileForPhone.bat') @($mixed) 2 'Enter';Verify-ShellRun 'partial-batch-bat' $beforeRuns 2 1 1 $n
    Add-ShellCase 'native-bat-good-and-corrupt-exit2' 'Independent good output validates; corrupt source fails without publication; totals2/converted1/failed1 and exit2 preserved.'
    $null=Invoke-ShellBat 'setup-bat-menu-q-cancel' (Join-Path $packageRoot 'app/Setup-AudioFileForPhone.bat') @() 130 'SetupCancel' @{} 'S = select existing folder'
    Assert-Shell ((Hash-Shell $config)-ceq$configHash) 'Setup cancellation modified saved config.'
    Add-ShellCase 'marked-setup-bat-real-menu-cancel130' 'Real marked setup loads, exposes S/M/D/Q, receives Q+Return, preserves config, pauses and returns130; no picker acceptance claimed.'
    $null=Invoke-ShellBat 'invalid-no-folder' (Join-Path $packageRoot 'AudioFileForPhone.bat') @() 1 '' @{} 'exactly one audio folder'
    $null=Invoke-ShellBat 'invalid-multiple-folders' (Join-Path $packageRoot 'AudioFileForPhone.bat') @($single,$mixed) 1 '' @{} 'exactly one audio folder'
    Add-ShellCase 'invalid-arity-visible-exit1' 'Zero/multiple folders stay visible, preserve1 and prove final pause/key/release.'
    foreach($kind in @('host','runtime','helper')){
        $negative=Join-Path $dataRoot ('negative-missing-'+$kind);$null=New-ShellPackage $negative;$extra=@{};$message=''
        if($kind-ceq'host'){$fake=Join-Path $dataRoot 'missing-windows-host';[IO.Directory]::CreateDirectory($fake)|Out-Null;$extra.SystemRoot=$fake;$message='Windows PowerShell could not be found'}
        elseif($kind-ceq'runtime'){Remove-Item -LiteralPath (Join-Path $negative 'app/AudioFileForPhone.ps1');$message='AudioFileForPhone.ps1 is missing'}
        else{Remove-Item -LiteralPath (Join-Path $negative 'app/AudioFileForPhone.Helpers.ps1');$message='AudioFileForPhone.Helpers.ps1'}
        $null=Invoke-ShellBat ('missing-'+$kind) (Join-Path $negative 'AudioFileForPhone.bat') @($single) 1 '' $extra $message
        Add-ShellCase ('owned-negative-missing-'+$kind) 'Only named owned negative copy/environment changed; visible exit1 and native pause/key/job release verified.'
    }
    $emptyEnvironment=New-ShellEnvironment (Join-Path $dataRoot 'owned-empty-profile');$null=Test-ShellIdentity $emptyEnvironment 'empty-profile-identity'
    $missing=Invoke-ShellProcess $winps @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/AudioFileForPhone.ps1'),'-InputFolder',$single,'-ConfigPath',(Join-Path $emptyEnvironment.LOCALAPPDATA 'absent-config.json')) 'missing-tools-noninteractive' $emptyEnvironment @(1)
    Assert-Shell (($missing.stdout+$missing.stderr)-match'Could not find ffmpeg|DependencyMissing|DependencyInvalid'-and@(Get-ChildItem -LiteralPath (Join-Path $emptyEnvironment.USERPROFILE 'Music') -Force).Count-eq 0) 'Missing tools must fail usefully before conversion/output.'
    Add-ShellCase 'missing-tools-empty-path-config-visible1' 'Unmodified NoProfile/NonInteractive app with owned missing config and empty PATH returns1 without output or download.'
    $sourceAfter=@([pscustomobject]@{root='single';files=Inventory-Shell $single};[pscustomobject]@{root='mixed';files=Inventory-Shell $mixed})
    $report.source_unchanged=($sourceBefore|ConvertTo-Json -Depth 6 -Compress)-ceq($sourceAfter|ConvertTo-Json -Depth 6 -Compress)
    $report.package_unchanged=($packageBefore|ConvertTo-Json -Compress)-ceq((Inventory-Shell $packageRoot)|ConvertTo-Json -Compress)
    $report.dependencies_unchanged=(Hash-Shell $ffmpeg)-ceq$toolHashes[0]-and(Hash-Shell $ffprobe)-ceq$toolHashes[1]-and(Hash-Shell $zipPath)-ceq$ExpectedZipSha256
    $report.harness_unchanged=(Hash-Shell $PSCommandPath)-ceq$harnessBefore[0]-and(Hash-Shell $controllerSource)-ceq$harnessBefore[1]
    Assert-Shell ($report.source_unchanged-and$report.package_unchanged-and$report.dependencies_unchanged-and$report.harness_unchanged-and(Hash-Shell $config)-ceq$configHash) 'Source/package/dependency/harness/config integrity changed.'
    $report.synthetic_sources=$sourceBefore;$report.total_converted=2;$report.status='PASSED';$exitCode=0
}catch{$report.error=$_.Exception.Message.Replace($runRoot,'<OWNED_ROOT>');$report.error_location=$_.ScriptStackTrace.Replace($runRoot,'<OWNED_ROOT>')}
finally{
    $parentUnchanged=$true;foreach($name in $parentBefore.Keys){if([Environment]::GetEnvironmentVariable($name,'Process')-cne$parentBefore[$name]){$parentUnchanged=$false}}
    $report.parent_environment_unchanged=$parentUnchanged
    $afterPolicies=@(Get-ExecutionPolicy -List|ForEach-Object{[pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy}})
    $report.policies_unchanged=($policiesBefore|ConvertTo-Json -Compress)-ceq($afterPolicies|ConvertTo-Json -Compress);$report.descendant_release_proved=$releaseProved
    try{
        Assert-Shell ($parentUnchanged-and$report.policies_unchanged) 'Parent environment/policy changed.'
        if($created-and(Test-Path -LiteralPath $dataRoot)){
            Assert-Shell $releaseProved 'Cleanup refused: process release unproved.';Assert-ShellNoReparse $dataRoot
            $resolved=(Resolve-Path -LiteralPath $dataRoot).ProviderPath.TrimEnd('\','/')
            Assert-Shell ($resolved-ceq$dataRoot-and[IO.Path]::GetDirectoryName($resolved)-ceq$runRoot-and[IO.File]::ReadAllText($marker)-ceq$token) 'Cleanup owner/boundary mismatch.'
            foreach($item in @(Get-ChildItem -LiteralPath $resolved -Recurse -Force)){Assert-Shell (($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq 0) 'Reparse member blocks cleanup.'}
            [IO.Directory]::Delete($resolved,$true);$report.cleanup_verified=-not(Test-Path -LiteralPath $resolved);Assert-Shell $report.cleanup_verified 'Owned data cleanup failed.'
        }
    }catch{$report.status='FAILED';$exitCode=1;$report.cleanup_error=$_.Exception.Message.Replace($runRoot,'<OWNED_ROOT>')}
    $report.ended_utc=[DateTime]::UtcNow.ToString('o')
    if(-not(Test-Path -LiteralPath $evidence)-and[IO.Directory]::Exists($evidenceParent)){Assert-ShellNoReparse $evidenceParent;Write-ShellNew $evidence ($report|ConvertTo-Json -Depth 16)}
}
[pscustomobject]@{status=$report.status;evidence_path=$evidence;cases=$report.cases.Count;native_cases=$report.native_cases.Count;total_converted=$report.total_converted;cleanup_verified=$report.cleanup_verified;error=$report.error}|ConvertTo-Json
exit $exitCode
