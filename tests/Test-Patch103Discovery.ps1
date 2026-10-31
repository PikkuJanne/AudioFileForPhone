<#
Exact-ZIP discovery acceptance using the existing packaged native-process runner.
Process PATH/FFMPEG are real inherited environment values. A test loader replaces
only saved User/Machine environment reads with null so the desktop cannot repair
intentional missing-tool cases. Packaged application/helper bytes stay unchanged.
All media, copied tools, configuration and private reports stay outside Git.
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
function Assert-Discovery([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash-Discovery([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Literal-Discovery([string]$Value){"'"+$Value.Replace("'","''")+"'"}
function Write-Discovery([string]$Path,[string]$Text,[switch]$Bom){
    $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$writer=New-Object IO.StreamWriter($stream,(New-Object Text.UTF8Encoding([bool]$Bom)));try{$writer.Write($Text);$writer.Flush()}finally{$writer.Dispose()}}finally{$stream.Dispose()}
}
function Safe-DiscoveryPath([string]$Path){
    $cursor=[IO.Path]::GetFullPath($Path)
    while($cursor){if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;Assert-Discovery (($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Reparse ancestor refused.'};$cursor=[IO.Path]::GetDirectoryName($cursor)}
}
function Inventory-Discovery([string]$Path){@(Get-ChildItem -LiteralPath $Path -Recurse -File|Sort-Object FullName|ForEach-Object{[pscustomobject]@{path=$_.FullName.Substring($Path.Length+1);sha256=Hash-Discovery $_.FullName}})}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
$evidence=[IO.Path]::GetFullPath($EvidencePath);$parent=[IO.Path]::GetDirectoryName($evidence)
$zip=[IO.Path]::GetFullPath($RuntimeZipPath);$tools=[IO.Path]::GetFullPath($FfmpegDirectory)
foreach($path in @($parent,$zip,$tools,$PowerShell7Path)){Safe-DiscoveryPath $path}
Assert-Discovery ([IO.Directory]::Exists($parent)-and-not(Test-Path -LiteralPath $evidence)-and-not$evidence.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'Use fresh evidence outside Git.'
Assert-Discovery ((Hash-Discovery $zip)-ceq$ExpectedZipSha256) 'ZIP digest mismatch.'
$root=Join-Path $parent ('patch103-discovery-'+[guid]::NewGuid().ToString('N'))
Assert-Discovery (-not(Test-Path -LiteralPath $root)) 'Owned directory collision.'
[IO.Directory]::CreateDirectory($root)|Out-Null
Write-Discovery (Join-Path $root '.discovery-owner') ([guid]::NewGuid().ToString('N'))
$raw=Join-Path $root 'raw';$inputRoot=Join-Path $root 'synthetic input';$work=Join-Path $root 'unrelated working directory';$package=Join-Path $root 'exact extracted package'
$installation=Join-Path $root ('Independent tools '+[char]0x00e4+[char]0x4e2d);$pair=Join-Path $installation 'bin';$partial=Join-Path $root 'incomplete tools'
$profile=Join-Path $root 'owned profile';$local=Join-Path $profile 'AppData/Local';$temp=Join-Path $profile 'Temp'
foreach($path in @($raw,$inputRoot,$work,$pair,$partial,$local,$temp,(Join-Path $profile 'Music'))){[IO.Directory]::CreateDirectory($path)|Out-Null}
$report=[ordered]@{schema_version=1;kind='patch103_exact_zip_discovery';status='FAILED';started_utc=[DateTime]::UtcNow.ToString('o');runtime_zip_sha256=$ExpectedZipSha256;app_version=$ExpectedAppVersion;environment=$null;cases=@();processes=@();package_unchanged=$false;source_unchanged=$false;parent_environment_unchanged=$false;ordinary_music_access=$false;owner_media_access=$false;persistent_environment_writes=$false;owner_testing_required='none';adapter='Only User/Machine Get-AudioEnvironmentSetting reads return null in a test loader. Process calls the original packaged reader; exact application/helper files are unchanged.';saved_user_coverage='Real saved User fallback is exercised separately by native package acceptance.';raw_root=$root;data_retained=$true}
$exitCode=1;$counter=0;$parentValues=@{}
$ffmpeg=Join-Path $tools 'ffmpeg.exe';$ffprobe=Join-Path $tools 'ffprobe.exe'
function Run-Discovery([string]$Executable,[string[]]$Arguments,[string]$Label,[int[]]$Allowed=@(0)){
    $result=Invoke-AudioNativeProcess -ExecutablePath $Executable -Arguments $Arguments -Operation $Label
    $script:counter++;Write-Discovery (Join-Path $raw ('{0:D3}-{1}.json'-f$counter,$Label)) ($result|ConvertTo-Json -Depth 8)
    $report.processes+=[pscustomobject]@{operation=$Label;status=$result.Status;exit_code=$result.ExitCode;process_released=$result.ProcessReleased;pipe_drain_completed=$result.PipeDrainCompleted}
    Assert-Discovery ($result.Status-eq'Completed'-and$result.ProcessReleased-and$result.PipeDrainCompleted-and-not$result.StdoutTruncated-and-not$result.StderrTruncated-and$Allowed-contains$result.ExitCode) ('Native operation failed: '+$Label+' / '+$result.Error+' / '+$result.Stderr)
    return $result
}
try{
    $os=Get-CimInstance Win32_OperatingSystem;$cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{$principal=New-Object Security.Principal.WindowsPrincipal($identity);$admin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}finally{$identity.Dispose()}
    Assert-Discovery ($os.ProductType-eq1-and[Environment]::Is64BitProcess-and-not$admin) 'Use an unelevated x64 Windows client.'
    $report.environment=[ordered]@{caption=$os.Caption;build=$os.BuildNumber+'.'+$cv.UBR;architecture=$os.OSArchitecture;is_admin=$admin}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $marked=Join-Path $root 'downloaded.zip';[IO.File]::Copy($zip,$marked,$false)
    Set-Content -LiteralPath $marked -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
    [IO.Compression.ZipFile]::ExtractToDirectory($marked,$package)
    foreach($file in @(Get-ChildItem -LiteralPath $package -Recurse -File|Where-Object{$_.Extension-eq'.ps1'})){Set-Content -LiteralPath $file.FullName -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII}
    $packageBefore=Inventory-Discovery $package
    $app=Join-Path $package 'app/AudioFileForPhone.ps1';$helper=Join-Path $package 'app/AudioFileForPhone.Helpers.ps1'
    # Functions only: reuse the production package's contained process runner.
    . $helper
    Assert-Discovery ((Get-AudioAppVersion)-ceq$ExpectedAppVersion) 'Packaged version mismatch.'
    foreach($name in @('ffmpeg.exe','ffprobe.exe')){[IO.File]::Copy((Join-Path $tools $name),(Join-Path $pair $name),$false);Assert-Discovery ((Hash-Discovery (Join-Path $tools $name))-ceq(Hash-Discovery (Join-Path $pair $name))) 'Tool copy mismatch.'}
    [IO.File]::Copy($ffmpeg,(Join-Path $partial 'ffmpeg.exe'),$false)
    $source=Join-Path $inputRoot '2027-01-02 Synthetic.m4a'
    $null=Run-Discovery $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i','sine=frequency=610:sample_rate=44100:duration=0.4','-c:a','aac','-metadata','artist=Discovery synthetic artist',$source) 'fixture'
    $sourceHash=Hash-Discovery $source
    $loader=Join-Path $raw 'saved-environment-loader.ps1'
    $loaderText=@'
. $global:DiscoveryOriginalHelper
$script:DiscoveryOriginalEnvironmentReader=${function:Get-AudioEnvironmentSetting}
function Get-AudioEnvironmentSetting {
    param([string]$Name,[string]$Target='Process')
    if($Target-eq'Process'){return & $script:DiscoveryOriginalEnvironmentReader @PSBoundParameters}
    return $null
}
'@
    Write-Discovery $loader $loaderText -Bom
    $rows=@(
        @{name='path-quoted-expanded';path=($partial+';"%AFP_DISCOVERY_TOOLS%"');hint='';origin='PATH';success=$true},
        @{name='ffmpeg-directory';path='';hint=$pair;origin='FFMPEG';success=$true},
        @{name='ffmpeg-installation-root';path='';hint=$installation;origin='FFMPEG';success=$true},
        @{name='ffmpeg-executable';path='';hint=('"'+(Join-Path $pair 'ffmpeg.exe')+'"');origin='FFMPEG';success=$true},
        @{name='invalid-hint-valid-path';path=$pair;hint=(Join-Path $root 'missing hint');origin='PATH';success=$true},
        @{name='incomplete-pair-no-alternative';path=$partial;hint='';origin='';success=$false;diagnostic='(?s)found but unusable.*Missing ffprobe\.exe'},
        @{name='no-tools-not-found';path='';hint='';origin='';success=$false;diagnostic='FFmpeg not found'}
    )
    $shells=@(@{name='ps51';path=(Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe')},@{name='ps7';path=$PowerShell7Path})
    foreach($shell in $shells){foreach($row in $rows){
        $label=$shell.name+'-'+$row.name;$destination=Join-Path $root ($label+' output');$config=Join-Path $root ($label+' absent.json');$driver=Join-Path $raw ($label+'.ps1')
        $driverCode=@(
            '[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);$ErrorActionPreference=''Stop'';$ProgressPreference=''SilentlyContinue''',
            ('$global:DiscoveryOriginalHelper='+(Literal-Discovery $helper)),('$global:DiscoveryLoader='+(Literal-Discovery $loader)),
            @'
function global:Join-Path {
    [CmdletBinding()]param([Parameter(Position=0)][string]$Path,[Parameter(Position=1)][string]$ChildPath,[switch]$Resolve)
    $actual=Microsoft.PowerShell.Management\Join-Path @PSBoundParameters
    if($actual-ieq$global:DiscoveryOriginalHelper){return $global:DiscoveryLoader}
    return $actual
}
'@,
            ('& '+(Literal-Discovery $app)+' -InputFolder '+(Literal-Discovery $inputRoot)+' -OutputParent '+(Literal-Discovery $destination)+' -ConfigPath '+(Literal-Discovery $config)+' -Album ''2027 Term 1 Week 8'''),
            'exit $LASTEXITCODE'
        )-join"`r`n"
        Write-Discovery $driver $driverCode -Bom
        $values=@{PATH=$row.path;FFMPEG=$row.hint;AFP_DISCOVERY_TOOLS=$pair;USERPROFILE=$profile;LOCALAPPDATA=$local;APPDATA=(Join-Path $profile 'AppData/Roaming');TEMP=$temp;TMP=$temp;PSModulePath=(Join-Path (Split-Path -Parent $shell.path) 'Modules')}
        foreach($key in $values.Keys){$parentValues[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}
        try{foreach($key in $values.Keys){[Environment]::SetEnvironmentVariable($key,[string]$values[$key],'Process')};$allowed=if($row.success){@(0)}else{@(1)};$native=Run-Discovery $shell.path @('-NoLogo','-NoProfile','-NonInteractive','-STA','-ExecutionPolicy','Bypass','-File',$driver) $label $allowed}
        finally{foreach($key in $parentValues.Keys){[Environment]::SetEnvironmentVariable($key,$parentValues[$key],'Process')}}
        $text=$native.Stdout+"`n"+$native.Stderr
        Assert-Discovery (-not(Test-Path -LiteralPath $config)) 'Automatic discovery wrote config.'
        if($row.success){
            Assert-Discovery ($text-notmatch'S = select existing|Remember this directory|FFmpeg setup is needed') 'Valid automatic pair entered Setup.'
            $runs=@(Get-ChildItem -LiteralPath $destination -Directory);Assert-Discovery ($runs.Count-eq1) 'Expected one output run.'
            $manifest=Get-Content -LiteralPath (Join-Path $runs[0].FullName 'AudioFileForPhone_manifest.json') -Raw -Encoding UTF8|ConvertFrom-Json
            Assert-Discovery ($manifest.app_version-ceq$ExpectedAppVersion-and$manifest.run.exit_code-eq0-and$manifest.totals.converted-eq1-and$manifest.totals.failed-eq0-and$manifest.tools.selection_origin-ceq$row.origin-and$manifest.tools.ffmpeg.path-ceq(Join-Path $pair 'ffmpeg.exe')-and$manifest.tools.ffprobe.path-ceq(Join-Path $pair 'ffprobe.exe')) 'Manifest/origin/pair mismatch.'
            $output=Join-Path $runs[0].FullName $manifest.records[0].output_relative_path
            $probe=(Run-Discovery $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$output) ($label+'-probe')).Stdout|ConvertFrom-Json
            $audio=@($probe.streams|Where-Object{$_.codec_type-eq'audio'})
            Assert-Discovery ($audio.Count-eq1-and$audio[0].codec_name-eq'mp3'-and[long]$audio[0].bit_rate-eq64000-and$probe.format.tags.album-ceq'2027 Term 1 Week 8'-and$probe.format.tags.artist-ceq'Discovery synthetic artist') 'Independent audio/tag probe mismatch.'
            $null=Run-Discovery $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL') ($label+'-decode')
            Assert-Discovery (@(Get-ChildItem -LiteralPath $destination -Recurse -File|Where-Object{$_.Name-like'*.partial*'}).Count-eq0) 'Partial output remains.'
            $report.cases+=[pscustomobject]@{shell=$shell.name;name=$row.name;status='PASSED';exit_code=0;origin=$row.origin;converted=1;output_sha256=Hash-Discovery $output;full_decode=$true}
        }else{
            Assert-Discovery (-not(Test-Path -LiteralPath $destination)-and$text-match$row.diagnostic-and$text-match'FfmpegDirectory') 'Missing/incomplete pair did not fail readably before output.'
            $report.cases+=[pscustomobject]@{shell=$shell.name;name=$row.name;status='PASSED';exit_code=1;converted=0;diagnostic=$row.diagnostic}
        }
    }}
    $report.source_unchanged=(Hash-Discovery $source)-ceq$sourceHash
    $report.package_unchanged=($packageBefore|ConvertTo-Json -Compress)-ceq((Inventory-Discovery $package)|ConvertTo-Json -Compress)
    $report.parent_environment_unchanged=$true;foreach($key in $parentValues.Keys){if([Environment]::GetEnvironmentVariable($key,'Process')-cne$parentValues[$key]){$report.parent_environment_unchanged=$false}}
    Assert-Discovery ($report.source_unchanged-and$report.package_unchanged-and$report.parent_environment_unchanged-and(Hash-Discovery $zip)-ceq$ExpectedZipSha256) 'Source/package/ZIP or parent environment changed.'
    $report.status='PASSED';$exitCode=0
}catch{$report.error=$_.Exception.Message;$report.location=$_.ScriptStackTrace}
finally{$report.completed_utc=[DateTime]::UtcNow.ToString('o');Write-Discovery $evidence ($report|ConvertTo-Json -Depth 14)}
[pscustomobject]@{status=$report.status;cases=$report.cases.Count;evidence_path=$evidence;error=$report.error}|ConvertTo-Json
exit $exitCode
