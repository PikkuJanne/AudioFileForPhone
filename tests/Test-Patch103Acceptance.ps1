<#
Focused exact-ZIP acceptance for the discovery/metadata/presentation patch.
The real packaged BAT/PS1 run under guarded native Windows consoles. Synthetic
inputs, config and default Music stay in a proved owned child profile. Console
keys and the actual cover dialog are driven automatically; no UI adapter is
replaced. Internet marks are deterministic ADS fixtures, not browser extraction.
Raw evidence and synthetic data stay outside Git. No persistent settings change.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RuntimeZipPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedZipSha256,
    [Parameter(Mandatory=$true)][string]$EvidencePath,
    [Parameter(Mandatory=$true)][string]$FfmpegDirectory,
    [Parameter(Mandatory=$true)][string]$PowerShell7Path,
    [string]$ExpectedAppVersion='1.0.3'
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$evidence=[IO.Path]::GetFullPath($EvidencePath);$parent=[IO.Path]::GetDirectoryName($evidence)
$root=Join-Path $parent ('patch103-'+[guid]::NewGuid().ToString('N'))
$data=Join-Path $root 'owned-data';$raw=Join-Path $root 'raw';$work=Join-Path $data 'unrelated working directory'
$profileRoot=Join-Path $data 'owned-profile';$music=Join-Path $profileRoot 'Music'
$package=Join-Path $data ('extracted application '+[char]0x00e4)
$marker=Join-Path $root '.patch-owner';$token=[guid]::NewGuid().ToString('N')
$winps=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$cmd=Join-Path $env:SystemRoot 'System32/cmd.exe';$csc=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$controller=Join-Path $data 'console-controller.exe';$controllerSource=Join-Path $PSScriptRoot 'DirectLauncher.Console.cs'
$ffmpeg=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffmpeg.exe';$ffprobe=Join-Path ([IO.Path]::GetFullPath($FfmpegDirectory)) 'ffprobe.exe'
$releaseProved=$true;$code=1;$created=$false;$counter=0
$report=[ordered]@{schema_version=1;kind='patch103_exact_package_native_console_acceptance';status='FAILED';started_utc=[DateTime]::UtcNow.ToString('o');runtime_zip_sha256=$ExpectedZipSha256;app_version=$ExpectedAppVersion;environment=$null;cases=@();native=@();outputs=@();sources_unchanged=$false;package_unchanged=$false;ordinary_music_access=$false;owner_media_access=$false;persistent_settings_changed=$false;owner_testing_required='none';internet_marks='ZIP and extracted PS1 Zone.Identifier=3, deterministically added; not browser extraction.';delivery_method='Windows native cmd/BAT argument delivery. Shortcut shell invocation recorded separately when exercised. No physical Explorer drag/drop claim.';raw_root=$raw;data_retained=$true}
function Assert-Patch([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Hash-Patch([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Patch([string]$Path,[string]$Text){$stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}
function Quote-Patch([AllowEmptyString()][string]$Value){$q='"';$slashes=0;foreach($c in $Value.ToCharArray()){if($c-eq'\'){$slashes++;continue};if($c-eq'"'){$q+=('\'*($slashes*2+1))+'"'}else{$q+=('\'*$slashes)+$c};$slashes=0};$q+('\'*($slashes*2))+'"'}
function Inventory-Patch([string]$Path){@(Get-ChildItem -LiteralPath $Path -Recurse -File|Sort-Object FullName|ForEach-Object{[pscustomobject]@{path=$_.FullName.Substring($Path.Length+1);hash=Hash-Patch $_.FullName}})}
function Run-Patch([string]$Exe,[string[]]$Arguments,[hashtable]$Environment=@{},[int[]]$Allowed=@(0),[int]$Deadline=90000){
    $si=New-Object Diagnostics.ProcessStartInfo;$si.FileName=$Exe;$si.Arguments=(@($Arguments|ForEach-Object{Quote-Patch $_})-join' ');$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.WorkingDirectory=$work
    $si.RedirectStandardInput=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
    $si.StandardOutputEncoding=New-Object Text.UTF8Encoding($false);$si.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    foreach($key in $Environment.Keys){$si.EnvironmentVariables[$key]=[string]$Environment[$key]}
    $p=New-Object Diagnostics.Process;$p.StartInfo=$si
    try{Assert-Patch ($p.Start()) 'Owned process did not start.';$p.StandardInput.Close();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
        if(-not$p.WaitForExit($Deadline)){$script:releaseProved=$false;$p.Kill();$null=$p.WaitForExit(5000);throw ('Owned process deadline: '+$Exe)}
        Assert-Patch ($stdout.Wait(5000)-and$stderr.Wait(5000)) 'Owned pipes did not drain.'
        $result=[pscustomobject]@{stdout=$stdout.GetAwaiter().GetResult();stderr=$stderr.GetAwaiter().GetResult();exit=$p.ExitCode}
        $script:counter++;Write-Patch (Join-Path $raw ('process-'+$counter+'.txt')) ($result|ConvertTo-Json -Compress)
        Assert-Patch ($Allowed-contains$result.exit) ('Unexpected exit '+$result.exit+' from '+$Exe+': '+$result.stderr);return $result
    }finally{$p.Dispose()}
}
function Add-PatchCase([string]$Name,[string]$Observed){$report.cases+=[pscustomobject]@{name=$Name;status='PASSED';observed=$Observed}}
function New-PatchEnvironment([string]$Name){
    $profile=Join-Path $data $Name
    $values=@{USERPROFILE=$profile;LOCALAPPDATA=(Join-Path $profile 'AppData/Local');APPDATA=(Join-Path $profile 'AppData/Roaming');TEMP=(Join-Path $profile 'Temp');TMP=(Join-Path $profile 'Temp');PATH='';FFMPEG='';PSModulePath=(Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/Modules');NO_COLOR='';TERM=''}
    foreach($p in @($profile,(Join-Path $profile 'Music'),$values.LOCALAPPDATA,$values.APPDATA,$values.TEMP)){[IO.Directory]::CreateDirectory($p)|Out-Null};return $values
}
function Copy-PatchEnvironment([hashtable]$Values){$copy=@{};foreach($k in $Values.Keys){$copy[$k]=$Values[$k]};return $copy}
function Run-PatchNative([string]$Label,[string]$Exe,[string[]]$Arguments,[string[]]$Steps,[int]$Expected,[hashtable]$Environment,[bool]$Bat=$false,[string]$Cover=''){
    $stepsPath=Join-Path $raw ($Label+'-steps.tsv');Write-Patch $stepsPath ($Steps-join"`r`n")
    $envCase=Copy-PatchEnvironment $Environment;$envCase.AFP_CONSOLE_STEPS=$stepsPath;$envCase.AFP_CONSOLE_COVER=$Cover
    $nativePath=Join-Path $raw ($Label+'-console.json');$mode=if($Bat){'Script'}else{'DirectScript'}
    $line=if($Exe-ieq$cmd){'/d /v:off /s /c '+$Arguments[-1]}else{(@($Arguments|ForEach-Object{Quote-Patch $_})-join' ')}
    $null=Run-Patch $controller @($Exe,$line,$work,$nativePath,'180000',$mode) $envCase @(0) 205000
    $native=Get-Content -LiteralPath $nativePath -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not$native.owned_tree_released){$script:releaseProved=$false}
    Assert-Patch ([string]::IsNullOrEmpty($native.error)-and$native.owned_tree_released-and$native.exit_code-eq$Expected-and$native.script_steps_sent-eq$Steps.Count) ('Native flow failed '+$Label+': '+$native.error)
    if($Bat){Assert-Patch ($native.pause_seen-and$native.still_waiting_before_key-and$native.key_injected) 'BAT pause/wait/key contract missing.'}
    Assert-Patch ($native.text.IndexOf([char]27)-lt 0) 'Raw escape in native console.'
    $report.native+=[pscustomobject]@{label=$Label;exit=$native.exit_code;script_steps=$native.script_steps_sent;cover_picker_supplied=$native.cover_picker_supplied;color_attributes=$native.color_attributes;report_sha256=Hash-Patch $nativePath;owned_tree_released=$native.owned_tree_released}
    return $native
}
function New-PatchRunRoot([string]$Path){@(Get-ChildItem -LiteralPath $Path -Directory|ForEach-Object{$_.FullName})}
function Verify-PatchOutputs([string]$Label,[string]$Destination,[string[]]$Before,[int]$Count,[string]$Artist,[string]$Album,[bool]$Cover,[bool]$Keep=$false){
    $new=@(Get-ChildItem -LiteralPath $Destination -Directory|Where-Object{$Before-cnotcontains$_.FullName});Assert-Patch ($new.Count-eq 1) ('Expected one new run: '+$Label)
    $run=$new[0].FullName;$manifest=Get-Content -LiteralPath (Join-Path $run 'AudioFileForPhone_manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-Patch ($manifest.app_version-ceq$ExpectedAppVersion-and$manifest.run.exit_code-eq 0-and$manifest.totals.converted-eq$Count-and$manifest.totals.failed-eq 0-and$manifest.policies.bitrate_kbps-eq64) 'Manifest/count/default/version mismatch.'
    $files=@(Get-ChildItem -LiteralPath $run -Recurse -File|Where-Object{$_.Extension-eq'.mp3'});Assert-Patch ($files.Count-eq$Count) 'Output count mismatch.'
    foreach($file in $files){
        $probe=(Run-Patch $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$file.FullName)).stdout|ConvertFrom-Json
        $audio=@($probe.streams|Where-Object{$_.codec_type-eq'audio'});$art=@($probe.streams|Where-Object{$_.codec_type-eq'video'-and$_.disposition.attached_pic-eq1})
        Assert-Patch ($audio.Count-eq1-and$audio[0].codec_name-eq'mp3'-and[long]$audio[0].bit_rate-eq64000-and($art.Count-eq1)-eq$Cover) 'Audio bitrate or cover mismatch.'
        if($Keep){$number=if($file.Name.Contains('Second')){'2'}else{'1'};$expectedArtist='Original artist '+$number;$expectedAlbum='Original album '+$number}else{$expectedArtist=$Artist;$expectedAlbum=$Album}
        if($null-ne$Artist-or$Keep){Assert-Patch ([string]$probe.format.tags.artist-ceq$expectedArtist) ('Artist mismatch in '+$Label)}
        if($null-ne$Album-or$Keep){Assert-Patch ([string]$probe.format.tags.album-ceq$expectedAlbum) ('Album mismatch in '+$Label)}
        $null=Run-Patch $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-err_detect','explode','-i',$file.FullName,'-map','0:a:0','-f','null','NUL')
        $report.outputs+=[pscustomobject]@{case=$Label;file=$file.Name;sha256=Hash-Patch $file.FullName;artist=[string]$probe.format.tags.artist;album=[string]$probe.format.tags.album;cover=$Cover;full_decode=$true;bitrate=64000}
    }
    return $run
}
try{
    Assert-Patch ([Environment]::OSVersion.Platform-eq[PlatformID]::Win32NT) 'Windows required.'
    Assert-Patch ([IO.Directory]::Exists($parent)-and-not(Test-Path -LiteralPath $evidence)-and-not$evidence.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Fresh evidence must stay outside Git.'
    Assert-Patch ((Hash-Patch $RuntimeZipPath)-ceq$ExpectedZipSha256) 'ZIP hash mismatch.'
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=New-Object Security.Principal.WindowsPrincipal($identity)
    Assert-Patch (-not$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'Run unelevated.'
    $os=Get-CimInstance Win32_OperatingSystem;$cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Assert-Patch ($os.ProductType-eq1) 'Actual Windows client required.'
    $report.environment=[ordered]@{caption=$os.Caption;version=$os.Version;build=$os.BuildNumber+'.'+$cv.UBR;architecture=$os.OSArchitecture;is_admin=$false;orchestrator=$PSVersionTable.PSVersion.ToString();winps=$winps;pwsh=$PowerShell7Path}
    Assert-Patch (-not(Test-Path -LiteralPath $root)) 'Root collision.';[IO.Directory]::CreateDirectory($root)|Out-Null;$created=$true;Write-Patch $marker $token
    foreach($p in @($data,$raw,$work)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $markedZip=Join-Path $data 'downloaded.zip';[IO.File]::Copy([IO.Path]::GetFullPath($RuntimeZipPath),$markedZip,$false)
    Set-Content -LiteralPath $markedZip -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
    [IO.Compression.ZipFile]::ExtractToDirectory($markedZip,$package)
    foreach($file in @(Get-ChildItem -LiteralPath $package -Recurse -File|Where-Object{$_.Extension-eq'.ps1'})){Set-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII}
    $packageBefore=Inventory-Patch $package
    & $csc /nologo /target:exe ('/out:'+$controller) $controllerSource;Assert-Patch ($LASTEXITCODE-eq0) 'Controller compile failed.'
    $child=New-PatchEnvironment 'owned-profile';$child.FFMPEG=$FfmpegDirectory
    $identityCommand='[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);[ordered]@{music=[Environment]::GetFolderPath([Environment+SpecialFolder]::MyMusic,[Environment+SpecialFolderOption]::DoNotVerify);profile=$env:USERPROFILE;local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,[Environment+SpecialFolderOption]::DoNotVerify);cwd=(Get-Location).ProviderPath}|ConvertTo-Json -Compress'
    $i=(Run-Patch $winps @('-NoLogo','-NoProfile','-NonInteractive','-Command',$identityCommand) $child).stdout|ConvertFrom-Json
    Assert-Patch ($i.music-ceq$music-and$i.profile-ceq$profileRoot-and$i.local-ceq$child.LOCALAPPDATA-and$i.cwd-ceq$work) 'Default folders are not owned; refusing real BAT.'
    $single=Join-Path $data 'metadata synthetic';$batch=Join-Path $data '2027 Term 1 Week 8';[IO.Directory]::CreateDirectory($single)|Out-Null;[IO.Directory]::CreateDirectory($batch)|Out-Null
    foreach($n in 1,2){$name=if($n-eq1){'First'}else{'Second'};$null=Run-Patch $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i','sine=frequency=440:sample_rate=44100:duration=2','-c:a','aac','-metadata',('artist=Original artist '+$n),'-metadata',('album=Original album '+$n),(Join-Path $single ('2027-01-0'+$n+' '+$name+'.m4a')))}
    $template=Join-Path $single '2027-01-01 First.m4a';foreach($n in 1..29){[IO.File]::Copy($template,(Join-Path $batch ('2027-02-{0:D2} Lesson.m4a'-f$n)),$false)}
    Add-Type -AssemblyName System.Drawing;$cover=Join-Path $data 'synthetic cover.png';$bitmap=New-Object Drawing.Bitmap(32,32);try{$graphics=[Drawing.Graphics]::FromImage($bitmap);try{$graphics.Clear([Drawing.Color]::Cyan)}finally{$graphics.Dispose()};$bitmap.Save($cover,[Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()}
    $sourceBefore=@(Inventory-Patch $single;Inventory-Patch $batch)
    $app=Join-Path $package 'app/AudioFileForPhone.ps1';$bat=Join-Path $package 'AudioFileForPhone.bat'
    $preview=Run-Patch $winps @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$single,'-DryRun') $child
    Assert-Patch ($preview.stdout.Contains($music)-and@(Get-ChildItem -LiteralPath $music -Force).Count-eq0) 'DryRun default Music not proved write-free.'
    $artist="O'Neil & "+[char]0x00e4+[char]0x4e2d
    $before=New-PatchRunRoot $music
    $steps=@("Selection`t1`twrong","Use Enter, M or Q.`t1`tM","Add cover art?`t1`twrong","Use Y, N or Q.`t1`tY","Artist [Enter = keep existing]`t1`t$artist","Album [Enter = keep existing]`t1`t2027 Term 1 Week 8")
    $n=Run-PatchNative 'reported-metadata-bat' $cmd @('/d','/v:off','/s','/c',('""'+$bat+'" "'+$single+'""')) $steps 0 $child $true $cover
    Assert-Patch $n.cover_picker_supplied 'Actual cover dialog was not supplied.'
    $null=Verify-PatchOutputs 'reported-metadata-bat' $music $before 2 $artist '2027 Term 1 Week 8' $true
    Assert-Patch (@($n.color_attributes.PSObject.Properties).Count-ge3-and$n.text-match'1.0.3'-and$n.text-match'READY'-and$n.text-match'RESULT') 'Native colored presentation missing.'
    Add-PatchCase 'reported-metadata-real-bat' 'Invalid ready and cover choices recover; actual cover dialog/Artist/Album produce two ffprobe-verified tagged covered MP3s; native color attributes captured.'
    $before=New-PatchRunRoot $music
    $n=Run-PatchNative '29-defaults-bat' $cmd @('/d','/v:off','/s','/c',('""'+$bat+'" "'+$batch+'""')) @("Selection`t1`t") 0 $child $true
    $null=Verify-PatchOutputs '29-defaults-bat' $music $before 29 $null $null $false
    Add-PatchCase '29-defaults-bat' 'Actual BAT receives folder, Enter uses defaults, exit0, 29 validated 64kbps MP3s fully decoded in owned default Music.'
    # First prove the exact ShellExecute/.lnk/BAT route inherits the owned profile.
    # This inert target only records special-folder identities; no Music access.
    $shellIdentity=Join-Path $raw 'shell-identity.json';$probeScript=Join-Path $data 'shell-identity.ps1';$probeBat=Join-Path $data 'shell-identity.bat'
    Write-Patch $probeScript ($identityCommand+' | Set-Content -LiteralPath '+"'"+$shellIdentity.Replace("'","''")+"' -Encoding UTF8")
    Write-Patch $probeBat ("@echo off`r`n"+'"'+$winps+'" -NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "'+$probeScript+"`"`r`npause`r`nexit /b 0`r`n")
    $shell=New-Object -ComObject WScript.Shell;$linkPath=Join-Path $data 'AudioFileForPhone shortcut.lnk'
    try{$shortcut=$shell.CreateShortcut($linkPath);$shortcut.TargetPath=$probeBat;$shortcut.WorkingDirectory=$work;$shortcut.IconLocation=(Join-Path $package 'AudioFileForPhone.ico');$shortcut.WindowStyle=7;$shortcut.Save()}finally{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)}
    $null=Run-PatchNative 'inert-shell-identity' ('shell:'+$linkPath) @() @() 0 $child $true
    $shellI=Get-Content -LiteralPath $shellIdentity -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-Patch ($shellI.music-ceq$music-and$shellI.profile-ceq$profileRoot-and$shellI.local-ceq$child.LOCALAPPDATA-and$shellI.cwd-ceq$work) 'Windows shell default folders not owned; actual shortcut conversion refused.'
    $shell=New-Object -ComObject WScript.Shell
    try{$shortcut=$shell.CreateShortcut($linkPath);$shortcut.TargetPath=$bat;$shortcut.Save()}finally{[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)}
    $before=New-PatchRunRoot $music
    $n=Run-PatchNative '29-defaults-shell-shortcut' ('shell:'+$linkPath) @($batch) @("Selection`t1`t") 0 $child $true
    Assert-Patch $n.shell_shortcut_invoked 'Real Windows shell shortcut delivery missing.'
    $null=Verify-PatchOutputs '29-defaults-shell-shortcut' $music $before 29 $null $null $false
    Add-PatchCase '29-defaults-shell-shortcut' 'ShellExecuteEx open of actual .lnk targeting unchanged BAT delivers folder argument from unrelated cwd; 29 defaults fully decoded; no physical Explorer drag/drop claim.'
    $before=New-PatchRunRoot $music
    $plain=Copy-PatchEnvironment $child;$plain.NO_COLOR='1';$plain.AFP_CONSOLE_WIDTH='50'
    $n=Run-PatchNative 'ps7-blank-keep-narrow-plain' $PowerShell7Path @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$single,'-Interactive') @("Selection`t1`tM","Add cover art?`t1`tN","Artist`t1`t   ","Album`t1`t") 0 $plain
    $null=Verify-PatchOutputs 'ps7-blank-keep-narrow-plain' $music $before 2 '' '' $false $true
    Assert-Patch ($n.text-match'Artist'-and$n.text-match'Album'-and$n.text.IndexOf([char]27)-lt0) 'Narrow plain prompts unreadable.'
    Add-PatchCase 'ps7-blank-keep-narrow-plain' 'Direct NoProfile PS7 console, NO_COLOR and 50 columns; whitespace/Enter retain each file own Artist/Album; plain output has no escapes.'
    $before=New-PatchRunRoot $music
    $n=Run-PatchNative 'free-q-tags' $winps @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$single,'-Interactive') @("Selection`t1`tM","Add cover art?`t1`tN","Artist [Enter = keep existing]`t1`tQ","Album [Enter = keep existing]`t1`tY") 0 $child
    $null=Verify-PatchOutputs 'free-q-tags' $music $before 2 'Q' 'Y' $false
    Add-PatchCase 'free-q-y-tags' 'Q and Y at free-text fields become actual tags.'
    foreach($cancel in @(@{label='ready-cancel';steps=@("Selection`t1`tQ")},@{label='ready-eof';steps=@("Selection`t1`t~EOF~")})){
        $before=New-PatchRunRoot $music
        $null=Run-PatchNative $cancel.label $winps @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$single,'-Interactive') $cancel.steps 130 $child
        Assert-Patch ((@(New-PatchRunRoot $music)|ConvertTo-Json -Compress)-ceq(@($before)|ConvertTo-Json -Compress)) 'Cancellation/EOF created output.'
        Add-PatchCase $cancel.label 'Interactive termination preserves130 and creates no run.'
    }
    $saved=[Environment]::GetEnvironmentVariable('FFMPEG','User')
    if(-not[string]::IsNullOrWhiteSpace($saved)){
        $stale=Copy-PatchEnvironment $child;$stale.FFMPEG='';$before=New-PatchRunRoot $music
        $null=Run-Patch $winps @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$app,'-InputFolder',$single) $stale
        $null=Verify-PatchOutputs 'saved-user-ffmpeg-stale-child' $music $before 2 $null $null $false
        Add-PatchCase 'saved-user-ffmpeg-stale-child' 'Inherited FFMPEG and PATH empty; existing saved User FFMPEG read-only fallback converts without setup. No registry write.'
    }else{Add-PatchCase 'saved-user-ffmpeg-stale-child' 'NOT_RUN: no existing saved User FFMPEG; never write persistent settings just for a fixture.'}
    $report.sources_unchanged=($sourceBefore|ConvertTo-Json -Compress)-ceq(@(Inventory-Patch $single;Inventory-Patch $batch)|ConvertTo-Json -Compress)
    $report.package_unchanged=($packageBefore|ConvertTo-Json -Compress)-ceq((Inventory-Patch $package)|ConvertTo-Json -Compress)
    Assert-Patch ($report.sources_unchanged-and$report.package_unchanged-and(Hash-Patch $RuntimeZipPath)-ceq$ExpectedZipSha256) 'Source/package/ZIP changed.'
    $report.status='PASSED';$code=0
}catch{$report.error=$_.Exception.Message;$report.location=$_.ScriptStackTrace}
finally{
    $report.descendant_release_proved=$releaseProved;$report.ended_utc=[DateTime]::UtcNow.ToString('o')
    if($created-and[IO.Directory]::Exists($parent)-and-not(Test-Path -LiteralPath $evidence)){Write-Patch $evidence ($report|ConvertTo-Json -Depth 16)}
}
[pscustomobject]@{status=$report.status;evidence_path=$evidence;cases=$report.cases.Count;outputs=$report.outputs.Count;error=$report.error}|ConvertTo-Json
exit $code
