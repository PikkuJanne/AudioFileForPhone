<#
Exact-package Windows batch acceptance and direct native comparison. Generated
media, tools, isolated profiles and raw argv stay outside Git. The first runs use
the unchanged packaged PS1 and the real selected pair. One additional forwarding
instrumentation run captures argv; direct launches replay those exact vectors,
including the transaction's private output paths and options, on the same pair.
Instrumentation changes the native parent process, so it is reported separately.
This test does not download, change persistent settings or read owner recordings.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RuntimeZipPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedZipSha256,
    [Parameter(Mandatory=$true)][string]$EvidencePath,
    [Parameter(Mandatory=$true)][string]$FfmpegDirectory,
    [Parameter(Mandatory=$true)][string]$PowerShell7Path,
    [string]$ExpectedAppVersion='1.0.5',
    [string]$FixtureDirectory,
    [ValidateRange(3,10)][int]$BatchRuns=3,
    [ValidateRange(3,10)][int]$DirectRepeats=3
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$evidence=[IO.Path]::GetFullPath($EvidencePath);$parent=[IO.Path]::GetDirectoryName($evidence)
$root=Join-Path $parent ('patch105-batch-'+[guid]::NewGuid().ToString('N'))
$data=Join-Path $root 'data';$raw=Join-Path $root 'raw';$work=Join-Path $data 'cwd'
$package=Join-Path $data 'package';$inputRoot=Join-Path $data 'batch29'
$ffmpeg=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffmpeg.exe'
$ffprobe=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffprobe.exe'
$winps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$csc=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$artist='Patch105 batch artist';$album='Patch105 batch album'
$created=$false;$released=$true;$code=1;$counter=0
$fixtures=New-Object 'Collections.Generic.List[object]'
$report=[ordered]@{
    schema_version=1;task='PATCH105';kind='exact_package_29_file_batch_and_direct_native_comparison'
    status='FAILED';started_utc=[DateTime]::UtcNow.ToString('o');app_version=$ExpectedAppVersion
    runtime_zip_sha256=$ExpectedZipSha256;test_script_sha256=$null;environment=$null;dependencies=$null
    media='Generated representative media; not the original owner batch.';fixture_count=29
    batch_runs=@();direct_runs=@();instrumentation_run=$null;source_unchanged=$false
    package_unchanged=$false;dependencies_unchanged=$false;natural_crash_observed=$false
    descendant_release_proved=$false;owner_media_access=$false;ordinary_music_access=$false
    persistent_settings_changed=$false;owner_testing_required='none';data_retained=$true;raw_root=$raw
    fixture_directory=$null
}
function Assert-P105([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Hash-P105([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-P105([string]$Path,[string]$Text){$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$b=(New-Object Text.UTF8Encoding($false)).GetBytes($Text);$s.Write($b,0,$b.Length)}finally{$s.Dispose()}}
function Inventory-P105([string]$Path){@(Get-ChildItem -LiteralPath $Path -Recurse -File -Force|Sort-Object FullName|ForEach-Object{[pscustomobject]@{path=$_.FullName.Substring($Path.Length+1);bytes=$_.Length;sha256=Hash-P105 $_.FullName}})}
function Safe-P105([string]$Path){$p=[IO.Path]::GetFullPath($Path);while($p){if(Test-Path -LiteralPath $p){Assert-P105 (((Get-Item -LiteralPath $p -Force).Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Reparse path refused.'};$p=[IO.Path]::GetDirectoryName($p)}}
function Quote-P105([AllowEmptyString()][string]$Value){$q='"';$n=0;foreach($c in $Value.ToCharArray()){if($c-eq'\'){$n++;continue};if($c-eq'"'){$q+=('\'*($n*2+1))+'"'}else{$q+=('\'*$n)+$c};$n=0};$q+('\'*($n*2))+'"'}
function Run-P105([string]$Exe,[string[]]$Arguments,[hashtable]$Environment=@{},[int[]]$Allowed=@(0),[int]$Deadline=120000){
    $si=New-Object Diagnostics.ProcessStartInfo;$si.FileName=$Exe;$si.Arguments=(@($Arguments|ForEach-Object{Quote-P105 $_})-join' ')
    $si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.WorkingDirectory=$work
    $si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
    $si.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$si.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    foreach($k in $Environment.Keys){if($null-eq$Environment[$k]){$si.EnvironmentVariables.Remove($k)}else{$si.EnvironmentVariables[$k]=[string]$Environment[$k]}}
    $p=New-Object Diagnostics.Process;$p.StartInfo=$si
    try{
        Assert-P105 ($p.Start()) 'Process did not start.';$p.StandardInput.Close()
        $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
        if(-not$p.WaitForExit($Deadline)){$script:released=$false;$p.Kill();$null=$p.WaitForExit(5000);throw ('Owned process deadline: '+[IO.Path]::GetFileName($Exe))}
        Assert-P105 ($stdout.Wait(5000)-and$stderr.Wait(5000)) 'Owned process pipes did not drain.'
        $r=[pscustomobject]@{exit=$p.ExitCode;stdout=$stdout.GetAwaiter().GetResult();stderr=$stderr.GetAwaiter().GetResult()}
        $script:counter++;$record=[ordered]@{executable=$Exe;arguments=$Arguments;exit=$r.exit;stdout=$r.stdout;stderr=$r.stderr}
        Write-P105 (Join-Path $raw ('process-{0:D4}.json'-f$counter)) ($record|ConvertTo-Json -Depth 6)
        if($r.exit-eq-1073740791-or$r.stderr-match'stack smashing detected'){$report.natural_crash_observed=$true}
        Assert-P105 ($Allowed-contains$r.exit) ('Native exit '+$r.exit+' from '+[IO.Path]::GetFileName($Exe)+'; capture process-'+$counter+'. '+$r.stderr)
        return $r
    }finally{$p.Dispose()}
}
function Child-P105([string]$Name,[string]$Tools){
    $profile=Join-Path $data $Name
    $values=@{USERPROFILE=$profile;LOCALAPPDATA=(Join-Path $profile 'AppData/Local');APPDATA=(Join-Path $profile 'AppData/Roaming');TEMP=(Join-Path $profile 'Temp');TMP=(Join-Path $profile 'Temp');PATH='';FFMPEG=$Tools;PSModulePath=(Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/Modules');NO_COLOR=$null;TERM=$null;CLICOLOR=$null}
    foreach($p in @($profile,(Join-Path $profile 'Music'),$values.LOCALAPPDATA,$values.APPDATA,$values.TEMP)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $identityCommand='[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);[ordered]@{music=[Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic,[Environment+SpecialFolderOption]::DoNotVerify);profile=$env:USERPROFILE;local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,[Environment+SpecialFolderOption]::DoNotVerify);cwd=(Get-Location).ProviderPath}|ConvertTo-Json -Compress'
    foreach($hostPath in @($winps,$PowerShell7Path)){
        $i=(Run-P105 $hostPath @('-NoLogo','-NoProfile','-NonInteractive','-Command',$identityCommand) $values).stdout|ConvertFrom-Json
        Assert-P105 ($i.music-ceq(Join-Path $profile 'Music')-and$i.profile-ceq$profile-and$i.local-ceq$values.LOCALAPPDATA-and$i.cwd-ceq$work) 'Child special folders are not owned; refusing conversion.'
    }
    return $values
}
function Verify-P105File([string]$Path,[object]$Fixture){
    $m=(Run-P105 $ffprobe @('-v','error','-show_streams','-show_format','-of','json','-i',$Path)).stdout|ConvertFrom-Json
    $audio=@($m.streams|Where-Object{$_.codec_type-eq'audio'});$art=@($m.streams|Where-Object{$_.disposition.attached_pic-eq1})
    Assert-P105 ($audio.Count-eq1-and$audio[0].codec_name-eq'mp3'-and[long]$audio[0].bit_rate-eq64000) 'Output is not one 64kbps MP3 audio stream.'
    Assert-P105 ($art.Count-eq1-and$art[0].codec_name-eq'mjpeg'-and$art[0].width-eq225-and$art[0].height-eq225) 'Expected 225x225 JPEG cover missing.'
    Assert-P105 ($m.format.tags.title-ceq$Fixture.title-and$m.format.tags.artist-ceq$artist-and$m.format.tags.album-ceq$album) 'Output metadata mismatch.'
    $duration=[double]::Parse([string]$audio[0].duration,[Globalization.CultureInfo]::InvariantCulture)
    Assert-P105 ([math]::Abs($duration-$Fixture.duration)-le0.35) 'Independent output duration mismatch.'
    $decode=Run-P105 $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-err_detect','explode','-i',$Path,'-map',('0:'+$audio[0].index),'-vn','-sn','-dn','-af','asetpts=N/SR/TB','-progress','pipe:1','-stats_period','86400','-f','null','-') @{} @(0) 300000
    Assert-P105 ([string]::IsNullOrWhiteSpace($decode.stderr)) 'Independent full decode emitted an error.'
    $times=@([regex]::Matches($decode.stdout,'(?m)^out_time_us=(\d+)\s*$')|ForEach-Object{[long]$_.Groups[1].Value})
    Assert-P105 ($decode.stdout-match'(?m)^progress=end\s*$'-and$times.Count-gt0-and[math]::Abs(([double]$times[-1]/1000000)-$Fixture.duration)-le0.35) 'Independent full decoded duration mismatch.'
    return [pscustomobject]@{source=$Fixture.relative;output=[IO.Path]::GetFileName($Path);sha256=Hash-P105 $Path;bitrate=64000;duration=$duration;full_decode=$true;tags=$true;jpeg_225x225=$true}
}
function Verify-P105Run([string]$Label,[string]$Destination,[string]$ConsoleText){
    $manifests=@(Get-ChildItem -LiteralPath $Destination -Recurse -File|Where-Object{$_.Name-ceq'AudioFileForPhone_manifest.json'})
    Assert-P105 ($manifests.Count-eq1) 'Expected one run manifest.'
    $manifest=Get-Content -LiteralPath $manifests[0].FullName -Raw -Encoding UTF8|ConvertFrom-Json
    $report.batch_runs+=[pscustomobject]@{label=$Label;status='VERIFYING';exit=$manifest.run.exit_code;converted=$manifest.totals.converted;failed=$manifest.totals.failed;expected=29;outputs=@()}
    $entry=$report.batch_runs[-1]
    Assert-P105 ($manifest.app_version-ceq$ExpectedAppVersion-and$manifest.run.exit_code-eq0-and$manifest.totals.converted-eq29-and$manifest.totals.failed-eq0-and$manifest.policies.bitrate_kbps-eq64-and$manifest.records.Count-eq29) 'Manifest version/count/default/exit mismatch.'
    Assert-P105 ($ConsoleText-match'converted=29; failed=0') 'Console counts are missing or dishonest.'
    $outputs=@(Get-ChildItem -LiteralPath $Destination -Recurse -File|Where-Object{$_.Extension-ieq'.mp3'})
    Assert-P105 ($outputs.Count-eq29-and@($outputs.FullName|Select-Object -Unique).Count-eq29) 'Expected 29 distinct published MP3 paths.'
    Assert-P105 (@(Get-ChildItem -LiteralPath $Destination -Recurse -Force|Where-Object{$_.Name-like'*.partial'-or$_.Name-like'.AudioFileForPhone-recovery-*'}).Count-eq0) 'Owned temporary output leaked.'
    $run=[IO.Path]::GetDirectoryName($manifests[0].FullName)
    foreach($record in $manifest.records){
        $fixture=@($fixtures|Where-Object{$_.relative-ceq$record.source_relative_path.Replace('\','/')})
        Assert-P105 ($record.status-ceq'Converted'-and$fixture.Count-eq1) 'Unexpected source or unconverted record.'
        $entry.outputs+=Verify-P105File (Join-Path $run $record.output_relative_path) $fixture[0]
    }
    Copy-Item -LiteralPath $manifests[0].FullName -Destination (Join-Path $raw ($Label+'-manifest.json'))
    $log=Join-Path $run 'AudioFileForPhone_log.txt';Copy-Item -LiteralPath $log -Destination (Join-Path $raw ($Label+'-log.txt'))
    $logText=Get-Content -LiteralPath $log -Raw -Encoding UTF8
    if($logText-match'stack smashing detected|exit -1073740791'){$report.natural_crash_observed=$true}
    Assert-P105 ($logText-match'Summary: total=29, converted=29, failed=0') 'Local log counts mismatch.'
    $entry.status='PASSED';return $manifest
}
function App-P105([string]$Label,[string]$Shell,[hashtable]$Environment,[string]$Tools){
    $destination=Join-Path $Environment.USERPROFILE 'Music';$app=Join-Path $package 'app/AudioFileForPhone.ps1'
    $a=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$inputRoot,'-OutputParent',$destination,'-ConfigPath',(Join-Path $Environment.LOCALAPPDATA 'absent.json'),'-FfmpegDirectory',$Tools,'-Artist',$artist,'-Album',$album,'-CoverPath',$cover)
    $r=Run-P105 $Shell $a $Environment @(0) 600000
    return Verify-P105Run $Label $destination $r.stdout
}
try{
    Assert-P105 ([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT) 'Windows required.'
    Safe-P105 $parent;Assert-P105 ([IO.Directory]::Exists($parent)-and-not(Test-Path -LiteralPath $evidence)-and-not$evidence.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Fresh evidence must stay outside Git.'
    Assert-P105 ((Hash-P105 $RuntimeZipPath)-ceq$ExpectedZipSha256) 'ZIP hash mismatch.'
    Assert-P105 (-not(Test-Path -LiteralPath $root)) 'Root collision.'
    foreach($p in @($root,$data,$raw,$work,$inputRoot)){[IO.Directory]::CreateDirectory($p)|Out-Null};$created=$true
    Write-P105 (Join-Path $root '.patch105-owner') ([guid]::NewGuid().ToString('N'))
    $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion';$os=Get-CimInstance Win32_OperatingSystem
    $report.environment=[ordered]@{caption=$os.Caption;version=$os.Version;build=$os.BuildNumber+'.'+$cv.UBR;architecture=$os.OSArchitecture;product_type=$os.ProductType;orchestrator=$PSVersionTable.PSVersion.ToString();winps=(Run-P105 $winps @('-NoLogo','-NoProfile','-NonInteractive','-Command','$PSVersionTable.PSVersion.ToString()')).stdout.Trim();pwsh=(Run-P105 $PowerShell7Path @('-NoLogo','-NoProfile','-NonInteractive','-Command','$PSVersionTable.PSVersion.ToString()')).stdout.Trim()}
    Assert-P105 ($os.ProductType-eq1) 'Actual Windows client required.'
    $toolBefore=@(foreach($p in @($ffmpeg,$ffprobe)){[pscustomobject]@{name=[IO.Path]::GetFileName($p);sha256=Hash-P105 $p;version=(Run-P105 $p @('-version')).stdout.Split([char]10)[0].Trim()}});$report.dependencies=$toolBefore
    $report.test_script_sha256=Hash-P105 $PSCommandPath
    Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($RuntimeZipPath),$package)
    $packageBefore=Inventory-P105 $package
    Add-Type -AssemblyName System.Drawing;$cover=Join-Path $data 'cover225.jpg';$bitmap=New-Object Drawing.Bitmap(225,225)
    if([string]::IsNullOrWhiteSpace($FixtureDirectory)){
        try{$g=[Drawing.Graphics]::FromImage($bitmap);try{$g.Clear([Drawing.Color]::Cyan);$g.FillRectangle([Drawing.Brushes]::Navy,30,40,100,120)}finally{$g.Dispose()};$bitmap.Save($cover,[Drawing.Imaging.ImageFormat]::Jpeg)}finally{$bitmap.Dispose()}
        foreach($n in 1..29){
            $relative='2024-01-{0:D2} - Lesson {0:D2}.m4a'-f$n;$path=Join-Path $inputRoot $relative
            $duration=if($n-eq29){1800}else{2+($n%3)};$fragmented=($n%2-eq0);$title='Patch105 source {0:D2}'-f$n
            $a=@('-nostdin','-hide_banner','-v','error','-f','lavfi','-i',('sine=frequency='+(400+$n*11)+':sample_rate=44100:duration='+$duration),'-ac','2','-c:a','aac','-b:a','64k','-metadata',('title='+$title),'-metadata','artist=Original source artist','-metadata','album=Original source album','-metadata','creation_time=2024-01-02T03:04:05.000000Z')
            if($fragmented){$a+=@('-movflags','frag_keyframe+empty_moov+default_base_moof')}
            $null=Run-P105 $ffmpeg ($a+@($path)) @{} @(0) 300000
            $fixtures.Add([pscustomobject]@{relative=$relative;path=$path;duration=$duration;fragmented=$fragmented;title=$title;sha256=Hash-P105 $path})
        }
        Write-P105 (Join-Path $data 'fixtures.json') ($fixtures.ToArray()|ConvertTo-Json -Depth 5)
        $report.fixture_directory=$data
    }else{
        $bitmap.Dispose();$FixtureDirectory=[IO.Path]::GetFullPath($FixtureDirectory);Safe-P105 $FixtureDirectory
        Assert-P105 (-not$FixtureDirectory.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Fixture reuse must stay outside Git.'
        $inputRoot=Join-Path $FixtureDirectory 'batch29';$cover=Join-Path $FixtureDirectory 'cover225.jpg'
        $saved=Get-Content -LiteralPath (Join-Path $FixtureDirectory 'fixtures.json') -Raw -Encoding UTF8|ConvertFrom-Json
        Assert-P105 (@($saved).Count-eq29) 'Reused fixture inventory must contain 29 entries.'
        foreach($f in $saved){Assert-P105 ($f.path-ceq(Join-Path $inputRoot $f.relative)-and(Hash-P105 $f.path)-ceq$f.sha256) 'Reused fixture bytes/path mismatch.';$fixtures.Add($f)}
        $report.fixture_directory=$FixtureDirectory
    }
    $coverBefore=Hash-P105 $cover
    $sourceBefore=Inventory-P105 $inputRoot
    Write-Host ('PATCH105 fixtures ready; 29 generated M4As, long=1800s; app='+$ExpectedAppVersion)
    foreach($n in 1..$BatchRuns){Write-Host ('PATCH105 packaged PS5.1 batch '+$n+' starting');$null=App-P105 ('ps51-29-'+$n) $winps (Child-P105 ('profile-ps51-'+$n) $FfmpegDirectory) $FfmpegDirectory;Write-Host ('PATCH105 packaged PS5.1 batch '+$n+' verified 29/29')}
    # Real PS7 process with explicit paths is a compatibility comparison, separate
    # from the three packaged Windows PowerShell 5.1 executions above. The native
    # BAT contract has its own focused launcher tests; these media tests bypass
    # interactive cover selection by supplying the same explicit JPEG parameter.
    $child=Child-P105 'profile-ps7' $FfmpegDirectory;$destination=Join-Path $child.USERPROFILE 'Music'
    $app=Join-Path $package 'app/AudioFileForPhone.ps1'
    $a=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$inputRoot,'-OutputParent',$destination,'-ConfigPath',(Join-Path $child.LOCALAPPDATA 'absent.json'),'-FfmpegDirectory',$FfmpegDirectory,'-Artist',$artist,'-Album',$album,'-CoverPath',$cover)
    $r=Run-P105 $PowerShell7Path $a $child @(0) 600000
    $null=Verify-P105Run 'ps7-29' $destination $r.stdout
    # This test-only shim records complete argv while streaming pipes unchanged.
    # The uninstrumented runs above remain the primary package acceptance.
    $shim=Join-Path $data 'argv-tools';[IO.Directory]::CreateDirectory($shim)|Out-Null
    $shimSource=Join-Path $data 'argv-shim.cs'
    Write-P105 $shimSource @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
internal static class ArgvRecorder {
    private static string Quote(string value) {
        StringBuilder b=new StringBuilder("\""); int n=0;
        foreach(char c in value) { if(c=='\\'){n++;continue;} b.Append('\\', c=='"' ? n*2+1 : n); b.Append(c); n=0; }
        b.Append('\\',n*2);b.Append('"');return b.ToString();
    }
    public static int Main(string[] args) {
        string role=Path.GetFileNameWithoutExtension(Process.GetCurrentProcess().MainModule.FileName);
        string exe=Path.Combine(Environment.GetEnvironmentVariable("AFP_P105_REAL_TOOLS"),role+".exe");
        string[] quoted=Array.ConvertAll<string,string>(args,Quote);
        ProcessStartInfo si=new ProcessStartInfo(exe,String.Join(" ",quoted));si.UseShellExecute=false;si.CreateNoWindow=true;
        si.RedirectStandardInput=true;si.RedirectStandardOutput=true;si.RedirectStandardError=true;
        using(Process p=Process.Start(si)) {
            p.StandardInput.Close();Task stdout=p.StandardOutput.BaseStream.CopyToAsync(Console.OpenStandardOutput());Task stderr=p.StandardError.BaseStream.CopyToAsync(Console.OpenStandardError());
            p.WaitForExit();Task.WaitAll(stdout,stderr);
            File.AppendAllText(Environment.GetEnvironmentVariable("AFP_P105_ARGV_LOG"),new JavaScriptSerializer().Serialize(new {role=role,arguments=args,exit=p.ExitCode})+Environment.NewLine,new UTF8Encoding(false));
            return p.ExitCode;
        }
    }
}
'@
    $null=Run-P105 $csc @('/nologo','/platform:x64','/target:exe','/reference:System.Web.Extensions.dll',('/out:'+(Join-Path $shim 'ffmpeg.exe')),$shimSource)
    [IO.File]::Copy((Join-Path $shim 'ffmpeg.exe'),(Join-Path $shim 'ffprobe.exe'),$false)
    $child=Child-P105 'profile-argv' $shim;$argvLog=Join-Path $raw 'actual-argv.jsonl';$child.AFP_P105_REAL_TOOLS=$FfmpegDirectory;$child.AFP_P105_ARGV_LOG=$argvLog
    $null=App-P105 'instrumented-ps51-29' $winps $child $shim
    $report.instrumentation_run=[ordered]@{label='instrumented-ps51-29';parent_process='test-only forwarding shim';real_pair=$toolBefore;argv_log_sha256=Hash-P105 $argvLog;full_argv_recorded=$true}
    $vectors=@(Get-Content -LiteralPath $argvLog -Encoding UTF8|ForEach-Object{$_|ConvertFrom-Json})
    $encodeVectors=@($vectors|Where-Object{$_.role-ceq'ffmpeg'-and$_.arguments[-1]-like'*.partial'})
    Assert-P105 ($encodeVectors.Count-eq29) 'Expected 29 complete transaction encoder vectors.'
    foreach($v in $encodeVectors){Assert-P105 ($v.arguments-contains'-y'-and$v.arguments-contains'-f'-and$v.arguments-contains'mp3'-and$v.arguments-contains'-progress') 'Transaction-added options were not captured.'}
    $workingPaths=@($encodeVectors|ForEach-Object{[string]$_.arguments[-1]})
    foreach($p in $workingPaths){Assert-P105 ($p.StartsWith((Join-Path $child.USERPROFILE 'Music')+'\',[StringComparison]::OrdinalIgnoreCase)-and-not(Test-Path -LiteralPath $p)) 'Direct replay output is occupied or outside captured owned run.';Safe-P105 $p}
    foreach($n in 1..$DirectRepeats){
        $entry=[ordered]@{iteration=$n;status='RUNNING';argv_sha256=Hash-P105 $argvLog;exact_vectors_replayed=$true;operations=0;outputs=@()};$report.direct_runs+=[pscustomobject]$entry;$entry=$report.direct_runs[-1]
        foreach($v in $vectors){
            # Version/capability and cover-check invocations are replayed too.
            $exe=Join-Path $FfmpegDirectory ($v.role+'.exe')
            $null=Run-P105 $exe ([string[]]$v.arguments) $child @(0) 300000;$entry.operations++
        }
        foreach($v in $encodeVectors){
            $source=[string]$v.arguments[[Array]::IndexOf([string[]]$v.arguments,'-i')+1]
            $fixture=@($fixtures|Where-Object{$_.path-ceq$source});Assert-P105 ($fixture.Count-eq1) 'Captured encoder source is not a known fixture.'
            $p=[string]$v.arguments[-1];$entry.outputs+=Verify-P105File $p $fixture[0]
        }
        Assert-P105 ($entry.outputs.Count-eq29) 'Direct replay did not validate 29 outputs.'
        # Only these exact freshly produced private working paths are deleted;
        # published app MP3s stay in place. No glob, tree move or recursive delete.
        foreach($p in $workingPaths){Safe-P105 $p;[IO.File]::Delete($p);Assert-P105 (-not(Test-Path -LiteralPath $p)) 'Direct private output was not released.'}
        $entry.status='PASSED'
    }
    $report.source_unchanged=($sourceBefore|ConvertTo-Json -Compress)-ceq((Inventory-P105 $inputRoot)|ConvertTo-Json -Compress)
    $report.package_unchanged=($packageBefore|ConvertTo-Json -Compress)-ceq((Inventory-P105 $package)|ConvertTo-Json -Compress)
    $report.dependencies_unchanged=((@($toolBefore|ForEach-Object{$_.sha256})-join',')-ceq(@(@($ffmpeg,$ffprobe)|ForEach-Object{Hash-P105 $_})-join','))
    Assert-P105 ($report.source_unchanged-and$report.package_unchanged-and$report.dependencies_unchanged-and(Hash-P105 $cover)-ceq$coverBefore-and(Hash-P105 $RuntimeZipPath)-ceq$ExpectedZipSha256) 'Source/package/cover/tool/ZIP integrity changed.'
    $report.status='PASSED';$code=0
}catch{$report.error=$_.Exception.Message;$report.location=$_.ScriptStackTrace}
finally{
    $report.descendant_release_proved=$released;$report.finished_utc=[DateTime]::UtcNow.ToString('o')
    if($created-and-not(Test-Path -LiteralPath $evidence)){Write-P105 $evidence ($report|ConvertTo-Json -Depth 20)}
}
[pscustomobject]@{status=$report.status;app_version=$ExpectedAppVersion;packaged_runs=$report.batch_runs.Count;direct_runs=$report.direct_runs.Count;natural_crash_observed=$report.natural_crash_observed;error=$report.error;evidence_path=$evidence}|ConvertTo-Json
exit $code
