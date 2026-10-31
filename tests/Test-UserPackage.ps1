<#
.SYNOPSIS
Verify the extracted user distribution without ordinary Music or personal media.
.DESCRIPTION
Creates short synthetic fixtures in a new marker-owned evidence directory. Runs
the real app/ PS1 entry points in Windows PowerShell 5.1 and PowerShell 7, probes
and fully decodes outputs, and checks setup/config behavior. The existing native
console controller observes the relocated production BAT's pause, supplies its
key and verifies exits. An inert copy tests literal transport, not conversion.
Raw captures stay beside EvidencePath, outside the repository. No downloads or
persistent host changes. The final report binds ZIP bytes, not the outer manifest,
so the builder can subsequently attach this report without a circular hash.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PackageDirectory,
    [Parameter(Mandatory = $true)][Alias('OriginalRuntimeZipPath')][string]$CoreRuntimeZipPath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegDirectory = 'C:\ffmpeg\bin',
    [string]$PowerShell7Path
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-TestHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-TestBytesHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Assert-Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Assert-TestPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            Assert-Test (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse ancestor refused.'
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function ConvertTo-TestArgument([AllowEmptyString()][string]$Value) {
    Assert-Test ($Value.IndexOf([char]0) -lt 0) 'NUL argument refused.'
    $quoted = '"'; $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { $quoted += ('\' * ($slashes * 2 + 1)) + '"' }
        else { $quoted += ('\' * $slashes) + $character }
        $slashes = 0
    }
    $quoted + ('\' * ($slashes * 2)) + '"'
}
function Get-TestInventory([string]$Root) {
    @((Get-ChildItem -LiteralPath $Root -File -Recurse | Sort-Object FullName) | ForEach-Object {
        [pscustomobject]@{path=$_.FullName.Substring($Root.TrimEnd('\','/').Length + 1).Replace('\','/');bytes=$_.Length;sha256=Get-TestHash $_.FullName}
    })
}

$PackageDirectory = [IO.Path]::GetFullPath($PackageDirectory)
$CoreRuntimeZipPath = [IO.Path]::GetFullPath($CoreRuntimeZipPath)
$EvidencePath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetDirectoryName($EvidencePath)
foreach ($path in @($PackageDirectory, $CoreRuntimeZipPath, $evidenceParent)) { Assert-TestPath $path }
Assert-Test (-not (Test-Path -LiteralPath $EvidencePath)) 'EvidencePath must be new.'
Assert-Test (Test-Path -LiteralPath $evidenceParent -PathType Container) 'Evidence parent must exist.'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\','/')
Assert-Test (-not $EvidencePath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Keep raw evidence outside the repository.'
$runRoot = Join-Path $evidenceParent ('user-package-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
$packageRoot = Join-Path $runRoot ('relocated application & (safe)! ' + [char]0x00e4 + [char]0x4e2d)
$rawRoot = Join-Path $runRoot 'raw'
$inputRoot = Join-Path $runRoot ('input [synthetic] ' + [char]0x00f6)
foreach ($path in @($packageRoot,$rawRoot,$inputRoot,(Join-Path $inputRoot 'nested'))) { [IO.Directory]::CreateDirectory($path) | Out-Null }
[IO.File]::WriteAllText((Join-Path $runRoot 'ownership.json'), ('{"kind":"AudioFileForPhone.UserPackageTests","token":"' + [guid]::NewGuid().ToString('N') + '"}'))
$report = [ordered]@{schema_version=1;kind='user_package_verification';package_revision=3;app_version='1.0.5';artifact_kind='corrective_release_candidate';status='RUNNING';started_utc=[DateTime]::UtcNow.ToString('o');runtime_zip_sha256=$null;original_runtime_zip_sha256=Get-TestHash $CoreRuntimeZipPath;test_script_sha256=Get-TestHash $PSCommandPath;cases=@();shell_results=@();processes=@();native_cases=@();ordinary_music_access=$false;physical_observation=$false;windows10_observation=$false;phone_observation=$false;publication_performed=$false;internet_marks='Deterministic Zone.Identifier ADS on disposable copies; not browser extraction.';successful_bat_encoding=$false;raw_evidence_root=$runRoot}
$policiesBefore=@(Get-ExecutionPolicy -List | ForEach-Object { [pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy} })

function Invoke-TestProcess {
    param([string]$Exe,[string[]]$Arguments,[string]$Label,[int[]]$AllowedCodes=@(0),[string]$RawArguments,[hashtable]$Environment)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Exe; $info.WorkingDirectory=$runRoot
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.StandardOutputEncoding=New-Object Text.UTF8Encoding($false)
    $info.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    $info.EnvironmentVariables['PATH']=''
    if ($PSBoundParameters.ContainsKey('RawArguments')) { $info.Arguments=$RawArguments }
    else { $info.Arguments=(@($Arguments | ForEach-Object { ConvertTo-TestArgument $_ }) -join ' ') }
    # Never inherit PS7 module precedence into native Windows PowerShell children.
    if ([IO.Path]::GetFileName($Exe) -ieq 'powershell.exe' -or [IO.Path]::GetFileName($Exe) -ieq 'cmd.exe') {
        $info.EnvironmentVariables['PSModulePath']=(Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules') + ';' + (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules')
    }
    if ($null -ne $Environment) { foreach ($key in $Environment.Keys) { $info.EnvironmentVariables[$key]=[string]$Environment[$key] } }
    $process = New-Object Diagnostics.Process
    $process.StartInfo=$info; $row=$null
    try {
        Assert-Test ($process.Start()) 'Owned child did not start.'
        $ownedPid=$process.Id; $process.StandardInput.Close()
        $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
        # Encoding and full decode retain their natural completion semantics.
        $process.WaitForExit()
        $stdout=$stdoutTask.GetAwaiter().GetResult(); $stderr=$stderrTask.GetAwaiter().GetResult(); $exitCode=$process.ExitCode
        $stem=('{0:D3}-{1}' -f ($report.processes.Count + 1),$Label)
        $outFile=Join-Path $rawRoot ($stem+'.stdout.txt'); $errFile=Join-Path $rawRoot ($stem+'.stderr.txt')
        [IO.File]::WriteAllText($outFile,$stdout,(New-Object Text.UTF8Encoding($false))); [IO.File]::WriteAllText($errFile,$stderr,(New-Object Text.UTF8Encoding($false)))
        $row=[pscustomobject]@{label=$Label;owned_pid=$ownedPid;exit_code=$exitCode;natural_exit=$true;pipes_drained=$true;handle_closed=$false;stdout_sha256=Get-TestHash $outFile;stderr_sha256=Get-TestHash $errFile}
        $report.processes += $row
    } finally { $process.Dispose(); if ($null -ne $row) { $row.handle_closed=$true } }
    Assert-Test ($AllowedCodes -contains $exitCode) ('Unexpected '+$Label+' exit '+$exitCode+'; see private capture '+$stem)
    [pscustomobject]@{stdout=$stdout;stderr=$stderr;exit_code=$exitCode}
}
function Add-TestCase([string]$Id,[string]$Expected,[string]$Observed) {
    $report.cases += [pscustomobject]@{id=$Id;status='PASSED';expected=$Expected;observed=$Observed}
}
function Get-TestZipMembers([string]$Path) {
    $zip=[IO.Compression.ZipFile]::OpenRead($Path); $members=@{}
    try {
        foreach ($entry in $zip.Entries) {
            Assert-Test ($entry.FullName -cmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -and $entry.FullName -notmatch '(^|/)\.\.?(/|$)|//|/$' -and $entry.FullName -notmatch '\\|:') 'Unsafe ZIP path.'
            Assert-Test (-not $members.ContainsKey($entry.FullName)) 'Duplicate ZIP member.'
            Assert-Test ($entry.Length -le 4194304) 'Excessive member.'
            $stream=$entry.Open(); $buffer=New-Object IO.MemoryStream
            try { $stream.CopyTo($buffer); $bytes=$buffer.ToArray() } finally { $buffer.Dispose(); $stream.Dispose() }
            $members[$entry.FullName]=[pscustomobject]@{path=$entry.FullName;bytes=$entry.Length;sha256=Get-TestBytesHash $bytes;content=$bytes}
        }
    } finally { $zip.Dispose() }
    $members
}
function Set-TestInternetMark([string]$Path) {
    Set-Content -LiteralPath $Path -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
    Assert-Test ((Get-Content -LiteralPath $Path -Stream Zone.Identifier -Raw).Contains('ZoneId=3')) 'Disposable Internet mark missing.'
}
function Invoke-TestNativeBat {
    param([string]$Label,[string]$Bat,[string[]]$Folders=@(),[int]$ExpectedExit=1,[string]$ExpectedText,[hashtable]$Environment=@{})
    $nativePath=Join-Path $rawRoot ($Label+'-console.json')
    $before=@{}; $parentPath=$env:PATH; $parentModules=$env:PSModulePath
    $variables=@{AFP_PACKAGE_BAT=$Bat;PATH='';LOCALAPPDATA=(Join-Path $runRoot 'native-local-data');TEMP=(Join-Path $runRoot 'native-temp');PSModulePath=(Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/Modules')}
    $command='"%AFP_PACKAGE_BAT%"'
    for ($index=0;$index -lt $Folders.Count;$index++) {
        $variables['AFP_PACKAGE_ARG'+$index]=$Folders[$index]
        $command+=' "%AFP_PACKAGE_ARG'+$index+'%"'
    }
    foreach ($key in $Environment.Keys) { $variables[$key]=$Environment[$key] }
    try {
        foreach ($key in $variables.Keys) { $before[$key]=[Environment]::GetEnvironmentVariable($key,'Process'); [Environment]::SetEnvironmentVariable($key,[string]$variables[$key],'Process') }
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=$controller; $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $info.Arguments=(@($cmd,('/d /v:off /s /c "'+$command+'"'),$runRoot,$nativePath,'25000') | ForEach-Object {ConvertTo-TestArgument $_}) -join ' '
        $child=New-Object Diagnostics.Process; $child.StartInfo=$info
        try {
            Assert-Test ($child.Start()) 'Native controller could not start.'
            if (-not $child.WaitForExit(45000)) { $child.Kill(); $null=$child.WaitForExit(5000); throw 'Native controller exceeded bounded startup deadline; its owned job guards descendants.' }
            $controllerExit=$child.ExitCode
        } finally { $child.Dispose() }
        Assert-Test (Test-Path -LiteralPath $nativePath) 'Native console report missing.'
        $native=Get-Content -LiteralPath $nativePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $report.native_cases += [pscustomobject]@{label=$Label;expected_exit=$ExpectedExit;native=$native;report_sha256=Get-TestHash $nativePath}
        Assert-Test ($controllerExit -eq 0 -and [string]::IsNullOrEmpty($native.error) -and $native.pause_seen -and $native.still_waiting_before_key -and $native.key_injected -and $native.owned_tree_released) ('Production pause/key/owned-release failed: '+$native.error)
        Assert-Test ($native.exit_code -eq $ExpectedExit) ('BAT exit mismatch: '+$native.text)
        if ($ExpectedText) { Assert-Test ($native.text -match $ExpectedText) ('Visible BAT diagnostic missing: '+$ExpectedText) }
        return $native
    } finally {
        foreach ($key in $before.Keys) { [Environment]::SetEnvironmentVariable($key,$before[$key],'Process') }
        Assert-Test ($env:PATH -ceq $parentPath -and $env:PSModulePath -ceq $parentModules) 'Native test changed parent environment.'
    }
}
function Test-Conversion([string]$Shell,[string]$Label,[string]$Source,[string]$Output,[string]$Config,[switch]$Saved,[switch]$AppLocal,[string]$EntryRoot=$packageRoot) {
    $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $EntryRoot 'app/AudioFileForPhone.ps1'),'-InputFolder',$Source,'-OutputParent',$Output,'-ConfigPath',$Config)
    if (-not $Saved -and -not $AppLocal) { $arguments += @('-FfmpegDirectory',$FfmpegDirectory) }
    $run=Invoke-TestProcess $Shell $arguments ($Label+'-conversion')
    $dirs=@(Get-ChildItem -LiteralPath $Output -Directory)
    Assert-Test ($dirs.Count -eq 1) 'One owned output run required.'
    $manifestPath=Join-Path $dirs[0].FullName 'AudioFileForPhone_manifest.json'
    $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Test ([regex]::Matches($run.stdout,'(?m)^\[ AUDIOFILEFORPHONE :: 1\.0\.5 \] -- AUDIO CONSOLE\s*$').Count -eq 1) 'One concise application heading required.'
    Assert-Test ([regex]::Matches($run.stdout,'(?m)^\[RESULT\]').Count -eq 1) 'Exactly one final result required.'
    Assert-Test ($run.stdout -notmatch '\[DEBUG\]|(?m)^[-=]{12,}|Script path\s*:|Raw input\s*:|ffmpeg encoding arguments|ffmpeg\.exe.+-') 'Normal console contains debug, command or banner clutter.'
    Assert-Test ($run.stdout -match 'Input:' -and $run.stdout -match '\[INFO\] Output root' -and $run.stdout -match 'Log file\s*:' -and $run.stdout -match 'converted=4; failed=0') 'Input/destination/count/log console context missing.'
    $localLog=Join-Path $dirs[0].FullName 'AudioFileForPhone_log.txt'
    Assert-Test (Test-Path -LiteralPath $localLog -PathType Leaf) 'Detailed local log missing.'
    $logText=Get-Content -LiteralPath $localLog -Raw -Encoding UTF8
    Assert-Test ($logText -match 'Summary: total=4, converted=4, failed=0' -and $logText -match 'Source|Mapping|ffprobe|Probing') 'Detailed successful diagnostics missing from local log.'
    $expected=@(Get-ChildItem -LiteralPath $Source -File -Recurse).Count
    Assert-Test ($manifest.app_version -ceq '1.0.5' -and $manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.policies.bitrate_kbps -eq 64 -and $manifest.totals.converted -eq $expected -and $manifest.totals.failed -eq 0 -and $manifest.records.Count -eq $expected) 'Manifest version/default/count/result mismatch.'
    $expectedOrigin=if ($AppLocal) { 'AppLocal' } elseif ($Saved) { 'Saved' } else { 'Explicit' }
    Assert-Test ($manifest.tools.selection_origin -ceq $expectedOrigin) 'Tool selection origin changed.'
    Assert-Test (@(Get-ChildItem -LiteralPath $dirs[0].FullName -File -Recurse | Where-Object {$_.Name -like '*.partial*'}).Count -eq 0) 'Partial output remains.'
    foreach ($record in $manifest.records) {
        Assert-Test ($record.status -ceq 'Converted') 'Manifest record unconverted.'
        $outputPath=Join-Path $dirs[0].FullName $record.output_relative_path
        $relative=$record.source_relative_path.Replace('\','/')
        $fixture=@($fixtures | Where-Object {$_.path -ceq $relative})
        Assert-Test ($fixture.Count -eq 1) 'Unknown source mapping.'
        $expectedRelative=[IO.Path]::GetFileName($Source)+'/'+($relative -replace '[^/]+$','')+'2026-10-30 - '+[IO.Path]::GetFileNameWithoutExtension($relative).Substring(11)+'.mp3'
        Assert-Test ($record.output_relative_path.Replace('\','/') -ceq $expectedRelative) 'Date-first names/relative layout changed.'
        $probe=Invoke-TestProcess $ffprobe @('-v','error','-show_streams','-show_format','-of','json',$outputPath) ($Label+'-probe')
        $media=$probe.stdout | ConvertFrom-Json; $audio=@($media.streams | Where-Object {$_.codec_type -ceq 'audio'})
        Assert-Test ($audio.Count -eq 1 -and $audio[0].codec_name -ceq 'mp3' -and [int64]$audio[0].bit_rate -eq 64000 -and [double]$media.format.duration -ge 1.9 -and [double]$media.format.duration -le 2.35) 'Actual codec/64kbps/duration mismatch.'
        Assert-Test ($media.format.tags.title -ceq $fixture[0].title -and $media.format.tags.artist -ceq 'Package Artist' -and $media.format.tags.album -ceq 'Package Album') 'Metadata changed.'
        $null=Invoke-TestProcess $ffmpeg @('-nostdin','-hide_banner','-v','error','-xerror','-i',$outputPath,'-map','0:a:0','-f','null','-') ($Label+'-decode')
    }
    Add-TestCase $Label 'Real default64 conversion, metadata/layout, probe/full decode and raw exit0.' ($expected.ToString()+' real outputs validated.')
    [pscustomobject]@{label=$Label;exit_code=$run.exit_code;converted=$expected;failed=0;selection_origin=$manifest.tools.selection_origin;manifest_sha256=Get-TestHash $manifestPath}
}

try {
    $os=Get-CimInstance Win32_OperatingSystem; $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $report.environment=[ordered]@{caption=$os.Caption;product_type=$os.ProductType;build=$os.BuildNumber+'.'+$cv.UBR;display_version=$cv.DisplayVersion;architecture=$os.OSArchitecture;orchestrator_ps=$PSVersionTable.PSVersion.ToString()}
    Assert-Test ($os.ProductType -eq 1 -and [Environment]::Is64BitProcess) 'Actual Windows x64 client required.'
    $manifest=Get-Content -LiteralPath (Join-Path $PackageDirectory 'release-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $zipPath=Join-Path $PackageDirectory 'AudioFileForPhone-v1.0.5.zip'
    $zipHash=Get-TestHash $zipPath; $report.runtime_zip_sha256=$zipHash
    Assert-Test ($manifest.package_revision -eq 3 -and $manifest.app_version -ceq '1.0.5' -and $manifest.tag -ceq 'v1.0.5' -and $manifest.corrective_release_version -ceq '1.0.5' -and $manifest.artifact_kind -ceq 'corrective_release_candidate' -and $manifest.publication_authorized -eq $false -and $manifest.zip.name -ceq 'AudioFileForPhone-v1.0.5.zip' -and $manifest.zip.sha256 -ceq $zipHash -and $manifest.zip.bytes -eq (Get-Item -LiteralPath $zipPath).Length) 'Corrective candidate manifest identity mismatch.'
    $report.source_commit=$manifest.release_commit
    Assert-Test ($manifest.original_runtime_zip_sha256 -ceq $report.original_runtime_zip_sha256) 'Original payload binding mismatch.'
    $members=Get-TestZipMembers $zipPath; $original=Get-TestZipMembers $CoreRuntimeZipPath
    $rootFiles=@('AudioFileForPhone.bat','AudioFileForPhone.ico','README.txt')
    $appFiles=@('AudioFileForPhone.ps1','AudioFileForPhone.Helpers.ps1','AudioFileForPhone.ManagedSetup.ps1','AudioFileForPhone.Diagnostics.ps1','AudioFileForPhone.Checks.ps1','Check-AudioFileForPhone.ps1','tools/ffmpeg-download.json','Setup-AudioFileForPhone.ps1','Setup-AudioFileForPhone.bat','README.md','SUPPORT.md','CHANGELOG.md','SECURITY.md','LICENSE')
    $expectedMembers=@($rootFiles)+@($appFiles | ForEach-Object {'app/'+$_})
    Assert-Test ($members.Count -eq 17 -and $original.Count -eq 18 -and @($members.Keys | Where-Object { $_ -cnotin $expectedMembers }).Count -eq 0) 'Unexpected distribution inventory.'
    $actualRoot=@($members.Keys | Where-Object { $_ -notmatch '/' })
    Assert-Test ($actualRoot.Count -eq 3 -and @($actualRoot | Where-Object { $_ -cnotin $rootFiles }).Count -eq 0) 'Root contains unexpected internals.'
    Assert-Test (@($manifest.files.PSObject.Properties).Count -eq $members.Count) 'Manifest inventory count mismatch.'
    foreach ($name in $members.Keys) {
        Assert-Test ($manifest.files.$name -ceq $members[$name].sha256 -and $manifest.file_bytes.$name -eq $members[$name].bytes) 'Manifest member hash/length mismatch.'
    }
    foreach ($name in $appFiles) {
        if ($name -ceq 'Setup-AudioFileForPhone.bat') {
            $expected=([Text.Encoding]::UTF8.GetString($original[$name].content)).Replace("`r`n","`n").Replace("`n","`r`n")
            Assert-Test ([Text.Encoding]::UTF8.GetString($members['app/'+$name].content) -ceq $expected) 'Setup BAT differs beyond required CRLF normalization.'
        } else {
            Assert-Test ($members['app/'+$name].sha256 -ceq $original[$name].sha256) 'Retained implementation changed.'
        }
    }
    $batText=[Text.Encoding]::UTF8.GetString($members['AudioFileForPhone.bat'].content)
    $expectedBat=([Text.Encoding]::UTF8.GetString($original['AudioFileForPhone.bat'].content)).Replace('set "AFP_SCRIPT=%~dp0AudioFileForPhone.ps1"','set "AFP_SCRIPT=%~dp0app\AudioFileForPhone.ps1"').Replace("`r`n","`n").Replace("`n","`r`n")
    Assert-Test ($batText -ceq $expectedBat -and $batText -notmatch '(?im)^\s*call\s' -and $batText -match '-File "%AFP_SCRIPT%" -FromBatchLauncher') 'BAT must directly invoke app converter with original transport/exit contract.'
    $report.icon_sha256=$members['AudioFileForPhone.ico'].sha256
    Assert-Test ($report.icon_sha256 -ceq (Get-TestHash (Join-Path $projectRoot 'AudioFileForPhone.ico'))) 'Existing repository icon bytes changed.'
    $checksums=@(Get-Content -LiteralPath (Join-Path $PackageDirectory 'SHA256SUMS.txt') -Encoding UTF8)
    Assert-Test ($checksums.Count -eq 2 -and $checksums[0] -ceq ($zipHash+'  AudioFileForPhone-v1.0.5.zip') -and $checksums[1] -ceq ((Get-TestHash (Join-Path $PackageDirectory 'release-manifest.json'))+'  release-manifest.json')) 'External checksums do not match.'
    [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$packageRoot)
    $visible=@(Get-ChildItem -LiteralPath $packageRoot | Select-Object -ExpandProperty Name)
    Assert-Test ($visible.Count -eq 4 -and @($visible | Where-Object { $_ -cnotin @('AudioFileForPhone.bat','AudioFileForPhone.ico','README.txt','app') }).Count -eq 0) 'Extraction must expose exactly the intended four root entries.'
    Add-Type -AssemblyName System.Drawing
    $icon=New-Object Drawing.Icon((Join-Path $packageRoot 'AudioFileForPhone.ico'))
    try { Assert-Test ($icon.Width -gt 0 -and $icon.Height -gt 0) 'Relocated icon could not be decoded.' } finally { $icon.Dispose() }
    $readme=Get-Content -LiteralPath (Join-Path $packageRoot 'README.txt') -Raw -Encoding UTF8
    Assert-Test ($readme -match 'app[\\/]LICENSE' -and $readme -match 'app[\\/]SUPPORT' -and $readme -match 'Bypass' -and $readme -match 'MachinePolicy|managed polic' -and $readme -match '(?i)application.*(asset|zip)|release.*asset') 'Root guide lacks license, support, process policy or correct download guidance.'
    Add-TestCase 'layout-and-provenance' 'Exactly BAT/unchanged ICO/README.txt/app;17 allowlisted files; CRLF BATs; exact checksums.' 'Inventory, byte mappings, relocated icon load and direct BAT target verified.'
    $packageBefore=Get-TestInventory $packageRoot
    foreach ($script in @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'app') -File -Recurse | Where-Object { $_.Extension -ceq '.ps1' })) { Set-TestInternetMark $script.FullName }
    foreach ($entry in @('AudioFileForPhone.ps1','Setup-AudioFileForPhone.ps1')) {
        $tokens=$null; $errors=$null
        $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $packageRoot ('app/'+$entry)),[ref]$tokens,[ref]$errors)
        Assert-Test ($errors.Count -eq 0 -and $null -ne $ast.ParamBlock -and $null -ne $ast.GetHelpContent()) 'Retained PS1 contract must parse with comment help.'
    }
    Add-TestCase 'ps1-contract' 'App entrypoints retain exact core bytes, parameters and help.' 'Both actual entrypoints parse; no root PS1 wrappers are shipped.'
    $ffmpeg=Join-Path $FfmpegDirectory 'ffmpeg.exe'; $ffprobe=Join-Path $FfmpegDirectory 'ffprobe.exe'
    foreach ($file in @($ffmpeg,$ffprobe)) { Assert-TestPath $file }
    $dependenciesBefore=@(Get-TestHash $ffmpeg; Get-TestHash $ffprobe)
    $fixtures=@(@{path='2026-10-30 MP3.mp3';codec='libmp3lame';rate='44100';title='Synthetic MP3'},@{path='nested/2026-10-30 AAC.m4a';codec='aac';rate='44100';title='Synthetic AAC'},@{path='nested/2026-10-30 Vorbis.ogg';codec='libvorbis';rate='44100';title='Synthetic Vorbis'},@{path='nested/2026-10-30 Opus.ogg';codec='libopus';rate='48000';title='Synthetic Opus'})
    foreach ($fixture in $fixtures) {
        $null=Invoke-TestProcess $ffmpeg @('-nostdin','-hide_banner','-v','error','-f','lavfi','-i',('sine=frequency=440:sample_rate='+$fixture.rate+':duration=2'),'-c:a',$fixture.codec,'-b:a','128k','-metadata',('title='+$fixture.title),'-metadata','artist=Package Artist','-metadata','album=Package Album',(Join-Path $inputRoot $fixture.path)) 'fixture'
    }
    $sourcesBefore=Get-TestInventory $inputRoot
    if ([string]::IsNullOrWhiteSpace($PowerShell7Path)) { $PowerShell7Path=(Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source }
    $shells=@(@{label='ps51';path=(Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')},@{label='ps7';path=$PowerShell7Path})
    foreach ($shell in $shells) {
        $version=(Invoke-TestProcess $shell.path @('-NoProfile','-NonInteractive','-Command','$PSVersionTable.PSVersion.ToString()') ($shell.label+'-version')).stdout.Trim()
        $config=Join-Path $runRoot ($shell.label+'-config.json')
        $report.shell_results += Test-Conversion $shell.path ($shell.label+'-explicit') $inputRoot (Join-Path $runRoot ($shell.label+'-outputs')) $config
        Assert-Test (-not (Test-Path -LiteralPath $config)) 'Ordinary conversion saved config.'
        $null=Invoke-TestProcess $shell.path @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/AudioFileForPhone.ps1'),'-InputFolder',$inputRoot,'-OutputParent',(Join-Path $runRoot ($shell.label+'-preview')),'-ConfigPath',$config,'-DryRun','-Interactive') ($shell.label+'-preview')
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $runRoot ($shell.label+'-preview'))) -and -not (Test-Path -LiteralPath $config)) 'DryRun wrote output/config.'
        $null=Invoke-TestProcess $shell.path @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/Setup-AudioFileForPhone.ps1'),'-FfmpegDirectory',$FfmpegDirectory,'-ConfigPath',$config,'-Remember','-NonInteractive') ($shell.label+'-setup')
        Assert-Test (Test-Path -LiteralPath $config -PathType Leaf) 'Explicit remembered setup did not save owned config.'
        $configHash=Get-TestHash $config
        $report.shell_results += Test-Conversion $shell.path ($shell.label+'-saved') $inputRoot (Join-Path $runRoot ($shell.label+'-saved-outputs')) $config -Saved
        Assert-Test ((Get-TestHash $config) -ceq $configHash) 'Saved config changed during conversion.'
        $null=Invoke-TestProcess $shell.path @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $packageRoot 'app/Check-AudioFileForPhone.ps1'),'-FfmpegDirectory',$FfmpegDirectory,'-ConfigPath',$config) ($shell.label+'-check')
        Add-TestCase ($shell.label+'-setup-preview-check') 'Remembered setup/fresh saved conversion; no-write preview/check.' ('Actual '+$version+' cases passed; config unchanged after conversion/check.')
    }
    $localRoot=Join-Path $runRoot 'app-local-package'
    [IO.Compression.ZipFile]::ExtractToDirectory($zipPath,$localRoot)
    Copy-Item -LiteralPath $ffmpeg -Destination (Join-Path $localRoot 'app/ffmpeg.exe')
    Copy-Item -LiteralPath $ffprobe -Destination (Join-Path $localRoot 'app/ffprobe.exe')
    $localBefore=Get-TestInventory $localRoot
    $report.shell_results += Test-Conversion -Shell $shells[1].path -Label 'ps7-app-local' -Source $inputRoot -Output (Join-Path $runRoot 'app-local-outputs') -Config (Join-Path $runRoot 'app-local-absent-config.json') -AppLocal -EntryRoot $localRoot
    Assert-Test (($localBefore | ConvertTo-Json -Compress) -ceq ((Get-TestInventory $localRoot) | ConvertTo-Json -Compress)) 'Application-local package/tools changed.'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $runRoot 'app-local-absent-config.json'))) 'Application-local conversion wrote config.'
    $cmd=Join-Path $env:SystemRoot 'System32/cmd.exe'
    $controller=Join-Path $runRoot 'console-controller.exe'
    $csc=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    & $csc /nologo /target:exe ('/out:'+$controller) (Join-Path $PSScriptRoot 'DirectLauncher.Console.cs') | Out-Null
    Assert-Test ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $controller)) 'Existing native test controller did not compile.'
    foreach ($path in @((Join-Path $runRoot 'native-local-data'),(Join-Path $runRoot 'native-temp'))) { [IO.Directory]::CreateDirectory($path) | Out-Null }
    $null=Invoke-TestNativeBat -Label 'real-packaged-bat-zero-arguments' -Bat (Join-Path $packageRoot 'AudioFileForPhone.bat') -ExpectedText 'exactly one audio folder'
    $null=Invoke-TestNativeBat -Label 'real-packaged-bat-extra-arguments' -Bat (Join-Path $packageRoot 'AudioFileForPhone.bat') -Folders @($inputRoot,'extra') -ExpectedText 'exactly one audio folder'
    Add-TestCase 'relocated-real-bat-refusals' 'Actual relocated production BAT rejects invalid arity; visible pause/key/exit1 from unrelated CWD.' 'Both unmodified BAT cases passed with original exit and owned process release.'
    # Only this owned copy is instrumented. It does not claim real UI conversion.
    $transportRoot=Join-Path $runRoot 'transport [test] & (literal)!'
    [IO.Directory]::CreateDirectory((Join-Path $transportRoot 'app')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $packageRoot 'AudioFileForPhone.bat') -Destination (Join-Path $transportRoot 'AudioFileForPhone.bat')
    $capture=Join-Path $runRoot 'transport-capture.json'
    $instrument=@'
param([switch]$FromBatchLauncher)
$record=@{input=$env:AUDIOFILEFORPHONE_INPUT;from_batch=[bool]$FromBatchLauncher;policy=[string](Get-ExecutionPolicy);internet_mark=[string](Get-Content -LiteralPath $PSCommandPath -Stream Zone.Identifier -Raw)}
[IO.File]::WriteAllText($env:AFP_PACKAGE_TEST_CAPTURE,($record | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
exit 37
'@
    $instrumentPath=Join-Path $transportRoot 'app/AudioFileForPhone.ps1'
    [IO.File]::WriteAllText($instrumentPath,$instrument,(New-Object Text.UTF8Encoding($false)))
    Set-TestInternetMark $instrumentPath
    $bat=Join-Path $transportRoot 'AudioFileForPhone.bat'; $literal=Join-Path $runRoot ('source [test] & (literal)! %AFP_PACKAGE_SENTINEL% apostrophe''s '+[char]0x00e4+[char]0x4e2d)
    $null=Invoke-TestNativeBat -Label 'bat-instrumented-literal' -Bat $bat -Folders @($literal) -ExpectedExit 37 -Environment @{AFP_PACKAGE_TEST_CAPTURE=$capture;AFP_PACKAGE_SENTINEL='MUST_NOT_EXPAND'}
    $captured=Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Test ($captured.input -ceq $literal -and $captured.from_batch -eq $true -and $captured.policy -ceq 'Bypass' -and $captured.internet_mark.Contains('ZoneId=3')) 'BAT literal folder/process-policy transport changed.'
    Add-TestCase 'bat-instrumented-transport' 'Internet-marked inert converter receives literal metacharacters and Unicode; pause/key/original exit37.' 'Actual root BAT dispatch passed in owned copy; not Explorer or successful BAT encoding evidence.'
    $missingRoot=Join-Path $runRoot 'missing-implementation'
    [IO.Directory]::CreateDirectory((Join-Path $missingRoot 'app')) | Out-Null
    Copy-Item -LiteralPath (Join-Path $packageRoot 'AudioFileForPhone.bat') -Destination (Join-Path $missingRoot 'AudioFileForPhone.bat')
    $null=Invoke-TestNativeBat -Label 'real-packaged-bat-missing-runtime' -Bat (Join-Path $missingRoot 'AudioFileForPhone.bat') -Folders @($inputRoot) -ExpectedText 'missing'
    Copy-Item -LiteralPath (Join-Path $packageRoot 'app/AudioFileForPhone.ps1') -Destination (Join-Path $missingRoot 'app/AudioFileForPhone.ps1')
    Set-TestInternetMark (Join-Path $missingRoot 'app/AudioFileForPhone.ps1')
    $null=Invoke-TestNativeBat -Label 'real-packaged-bat-missing-helper' -Bat (Join-Path $missingRoot 'AudioFileForPhone.bat') -Folders @($inputRoot) -ExpectedText 'HelperMissing|missing|required'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $runRoot 'missing-output'))) 'Missing implementation created final output.'
    Add-TestCase 'missing-implementation' 'Real packaged BAT missing runtime/helper errors remain visible before conversion; exit1/pause/key.' 'Actual relocated bytes and marked runtime refused without output; native owned processes released.'
    Assert-Test (($sourcesBefore | ConvertTo-Json -Compress) -ceq ((Get-TestInventory $inputRoot) | ConvertTo-Json -Compress)) 'Synthetic sources changed.'
    Assert-Test (($packageBefore | ConvertTo-Json -Compress) -ceq ((Get-TestInventory $packageRoot) | ConvertTo-Json -Compress)) 'Extracted package changed.'
    Assert-Test ((Get-TestHash $ffmpeg) -ceq $dependenciesBefore[0] -and (Get-TestHash $ffprobe) -ceq $dependenciesBefore[1]) 'External tools changed.'
    Assert-Test ((Get-TestHash $zipPath) -ceq $zipHash) 'Input ZIP changed.'
    $policiesAfter=@(Get-ExecutionPolicy -List | ForEach-Object { [pscustomobject]@{scope=[string]$_.Scope;policy=[string]$_.ExecutionPolicy} })
    Assert-Test (($policiesBefore | ConvertTo-Json -Compress) -ceq ($policiesAfter | ConvertTo-Json -Compress)) 'Execution policy scopes changed.'
    $report.policies_unchanged=$true
    $report.source_unchanged=$true; $report.package_unchanged=$true; $report.dependencies_unchanged=$true
    $report.total_outputs=(@($report.shell_results | Measure-Object -Property converted -Sum).Sum)
    $report.status='PASSED'
} catch { $report.status='FAILED'; $report.error=$_.Exception.Message; throw }
finally {
    $report.ended_utc=[DateTime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText($EvidencePath,($report | ConvertTo-Json -Depth 15),(New-Object Text.UTF8Encoding($false)))
    [pscustomobject]@{status=$report.status;evidence_path=$EvidencePath;sha256=Get-TestHash $EvidencePath;total_outputs=$report.total_outputs} | ConvertTo-Json
}
