<#
S08 real Windows CMD/bootstrap/selected-host tests. The production launcher,
probe, BAT and helper are copied byte-for-byte. Only the application is replaced
by an inert create-new capture/exit child; no media, Music or owner config is
opened. Production function extraction covers injected startup failures without
adding a production test switch. Explicit UTF8 CMD/PS drivers stay token-owned.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S08-launcher-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-launcher-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S08-launcher active report or historical T17-launcher CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence exists; choose a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S08-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerToken = [guid]::NewGuid().ToString('N'); $ownerFile = Join-Path $testRoot '.s08-owner'
$created = $false; $releaseProved = $true
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourcePaths = @('AudioFileForPhone.bat', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'tests/Test-Launcher.ps1')
$systemDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
$cmdPath = Join-Path $systemDirectory 'cmd.exe'
$ps51Path = Join-Path $systemDirectory 'WindowsPowerShell\v1.0\powershell.exe'
$ps7Paths = @(Get-Command pwsh.exe -CommandType Application -All -ErrorAction Stop | ForEach-Object { $_.Source } | Select-Object -Unique)
$ps7Path = $ps7Paths[0]
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S08' }); mode = 'real_windows_launchers_inert_app_and_injected_preentry_failures'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false
    physical_manual_evidence = $false; explorer_or_physical_shortcut_evidence = 'NOT_RUN'
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    parent_path_unchanged = $false; persistent_environment_writes = $false
    cleanup_verified = $false; descendant_release_proved = $false; cases = @(); exercised_hosts = @()
    limitations = @('Inert application exit130 verifies forwarding only; real conversion/cancellation remains covered by retained suites.', 'Caller-expanded text cannot be recovered; percent paths use one explicit environment expansion.', 'Injected policy/architecture/refusal cases exercise decision functions; no real enterprise policy is changed.')
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Assert-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$NoBom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding(-not $NoBom.IsPresent)
        $preamble = $encoding.GetPreamble(); $stream.Write($preamble, 0, $preamble.Length)
        $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
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
function Invoke-Owned {
    param([string]$Executable, [string]$NativeArguments, [hashtable]$EnvironmentValues, [string]$WorkingDirectory, [int]$DeadlineMilliseconds = 30000)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable; $info.Arguments = $NativeArguments; $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false); $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    foreach ($name in @($info.EnvironmentVariables.Keys)) {
        if ([string]$name -ieq 'PSModulePath' -or [string]$name -like 'AUDIOFILEFORPHONE_*') { $info.EnvironmentVariables.Remove($name) }
    }
    $info.EnvironmentVariables['LOCALAPPDATA'] = $localData
    foreach ($name in $EnvironmentValues.Keys) { $info.EnvironmentVariables[$name] = [string]$EnvironmentValues[$name] }
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        Assert-True $process.Start() 'Owned launcher did not start.'
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        # Deliberately leave redirected stdin OPEN and never supply a pause key.
        if (-not $process.WaitForExit($DeadlineMilliseconds)) {
            $script:releaseProved = $false
            $process.Kill(); $process.WaitForExit(5000) | Out-Null
            throw 'Owned launcher exceeded harness deadline with unreadable input; descendant release unproved, owned fixtures retained.'
        }
        $process.StandardInput.Close()
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)) {
            $script:releaseProved = $false; throw 'Owned launcher pipes held after exit; release unproved, fixtures retained.'
        }
        return [pscustomobject]@{ exit_code = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result; elapsed_ms = $timer.ElapsedMilliseconds; redirected_stdin_held_open = $true }
    } finally { $timer.Stop(); $process.Dispose() }
}
$captureStub = @'
[CmdletBinding()]
param([Parameter(Position=0)][AllowEmptyString()][string]$InputFolder,[switch]$Interactive)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($env:AFP_S08_ROOT).TrimEnd('\','/')
$capture=[IO.Path]::GetFullPath($env:AFP_S08_CAPTURE)
if((Split-Path -Parent $capture) -ine $root -or [IO.File]::ReadAllText((Join-Path $root '.s08-owner')) -cne $env:AFP_S08_TOKEN){throw 'Capture ownership refused.'}
[IO.File]::AppendAllText(($capture+'.entries'), "entered`n", [Text.Encoding]::UTF8)
$process=[Diagnostics.Process]::GetCurrentProcess()
$record=[ordered]@{input_folder=$InputFolder;interactive=[bool]$Interactive;extra_arguments=@($args);cwd=(Get-Location).ProviderPath;process_cwd=[Environment]::CurrentDirectory;path=$process.MainModule.FileName;version=$PSVersionTable.PSVersion.ToString();edition=$PSVersionTable.PSEdition;process_64bit=[Environment]::Is64BitProcess;os_64bit=[Environment]::Is64BitOperatingSystem;apartment=[Threading.Thread]::CurrentThread.ApartmentState.ToString();output_codepage=[Console]::OutputEncoding.CodePage;requested_exit=[int]$env:AFP_S08_EXIT}
$stream=[IO.File]::Open($capture,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$bytes=[Text.Encoding]::UTF8.GetBytes(($record|ConvertTo-Json -Depth 5));$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose();$process.Dispose()}
exit ([int]$env:AFP_S08_EXIT)
'@
function New-LaunchCopy {
    param([string]$Name, [string]$Missing = '')
    $directory = New-Directory $Name
    foreach ($file in @('AudioFileForPhone.bat', 'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1')) {
        if ($file -ceq $Missing) { continue }
        $destination = Join-Path $directory $file
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $destination
        Assert-True ((Get-FileHash -LiteralPath $destination).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $file)).Hash) 'Copied runtime must be byte-identical.'
        Add-Fixture $destination
    }
    if ($Missing -cne 'AudioFileForPhone.ps1') { $stub = Join-Path $directory 'AudioFileForPhone.ps1'; Write-NewText $stub $captureStub; Add-Fixture $stub }
    return $directory
}
function Invoke-Bat {
    param([string]$Name, [string]$Directory, [string[]]$Folders, [string]$HostChoice, [int]$ChildExit = 0, [string]$PathValue = $originalPath, [string]$ProgramFilesRoot = $env:ProgramW6432)
    $capture = Join-Path $testRoot ('capture-' + $Name + '.json')
    $driver = Join-Path $testRoot ('driver-' + $Name + '.cmd')
    $arguments = @(); $environment = @{
        AFP_S08_BAT = Join-Path $Directory 'AudioFileForPhone.bat'; AFP_S08_CAPTURE = $capture
        AFP_S08_ROOT = $testRoot; AFP_S08_TOKEN = $ownerToken; AFP_S08_EXIT = [string]$ChildExit
        AUDIOFILEFORPHONE_HOST = $HostChoice; PATH = $PathValue; ProgramW6432 = $ProgramFilesRoot; AFP_S08_PERCENT_SENTINEL = 'CALLER_EXPANDED'
    }
    for ($i = 0; $i -lt $Folders.Count; $i++) { $environment['AFP_S08_ARG' + $i] = $Folders[$i]; $arguments += '"%AFP_S08_ARG' + $i + '%"' }
    $code = "@echo off`r`nsetlocal DisableDelayedExpansion`r`nchcp 65001 >nul`r`n" + '"%AFP_S08_BAT%" ' + ($arguments -join ' ') + "`r`n"
    Write-NewText $driver $code -NoBom; Add-Fixture $driver
    $native = Invoke-Owned $cmdPath ('/d /v:off /s /c ""' + $driver + '""') $environment $workingDirectory
    $captureRecord = if (Test-Path -LiteralPath $capture) { Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $entries = if (Test-Path -LiteralPath ($capture + '.entries')) { @([IO.File]::ReadAllLines(($capture + '.entries'))).Count } else { 0 }
    return [pscustomobject]@{ native = $native; capture = $captureRecord; capture_path = $capture; app_entries = $entries }
}
function Assert-Launch {
    param([object]$Result, [string]$ExpectedFolder, [int]$ExpectedExit, [string]$ExpectedEdition, [string]$ExpectedActualHost)
    Assert-True ($Result.native.exit_code -eq $ExpectedExit) ('Wrong launcher exit: ' + $Result.native.exit_code + '; ' + $Result.native.stdout + '; ' + $Result.native.stderr)
    Assert-True ($null -ne $Result.capture) ('Application was not entered: ' + $Result.native.stdout + '; ' + $Result.native.stderr)
    Assert-True ($Result.app_entries -eq 1) 'Every outcome must enter the application exactly once; never retry another host.'
    Assert-True ($Result.capture.input_folder -ceq $ExpectedFolder -and $Result.capture.interactive -and @($Result.capture.extra_arguments | Where-Object { $null -ne $_ }).Count -eq 0) ('Literal folder and Interactive must survive exactly. Expected=' + $ExpectedFolder + '; observed=' + ($Result.capture | ConvertTo-Json -Compress))
    Assert-True ($Result.capture.edition -ceq $ExpectedEdition -and $Result.capture.apartment -ceq 'STA' -and $Result.capture.process_64bit) 'Selected edition must execute in exact x64 STA host.'
    Assert-True ($Result.capture.path -ieq $ExpectedActualHost) ('Executed host must match independently observed exact expected executable: ' + $ExpectedActualHost + '; actual=' + $Result.capture.path)
    $report['last_launch_observation'] = [pscustomobject]@{ expected_working_directory = $workingDirectory; capture = $Result.capture }
    Assert-True ($Result.capture.cwd -ceq $workingDirectory -and $Result.capture.process_cwd -ceq $workingDirectory) ('Unrelated caller working directory must be preserved. Expected=' + $workingDirectory + '; observed PowerShell=' + $Result.capture.cwd + '; observed process=' + $Result.capture.process_cwd)
    Assert-True ($Result.capture.output_codepage -eq 65001) 'Explicit UTF8 CMD driver must preserve CP65001.'
    Assert-True (-not $Result.native.stdout.Contains('Press any key')) 'Redirected stdin must not reach a mandatory pause.'
    Assert-True ($Result.native.stdout.Contains($Result.capture.path) -and $Result.native.stdout.Contains($Result.capture.version) -and $Result.native.stdout.Contains('STA')) 'Selection banner must display exact executed host/version/STA.'
}
function Invoke-DirectLauncher {
    param([string]$Name, [string]$Directory, [string]$Folder, [string]$DirectHost, [string]$EnvironmentHost)
    $capture = Join-Path $testRoot ('capture-' + $Name + '.json')
    $psDriver = Join-Path $testRoot ('direct-' + $Name + '.ps1')
    $driver = Join-Path $testRoot ('direct-' + $Name + '.cmd')
    $psCode = '& ' + (Get-Literal (Join-Path $Directory 'AudioFileForPhone.Launcher.ps1')) + ' -InputFolder ' + (Get-Literal $Folder) + ' -HostPath ' + (Get-Literal $DirectHost) + "`r`nexit `$LASTEXITCODE`r`n"
    Write-NewText $psDriver $psCode; Add-Fixture $psDriver
    $cmdCode = "@echo off`r`nsetlocal DisableDelayedExpansion`r`nchcp 65001 >nul`r`n" + '"%AFP_S08_PS%" -NoLogo -NoProfile -NonInteractive -Sta -ExecutionPolicy RemoteSigned -File "%AFP_S08_DRIVER%"' + "`r`nexit /b %ERRORLEVEL%`r`n"
    Write-NewText $driver $cmdCode -NoBom; Add-Fixture $driver
    $environment = @{ AFP_S08_PS = $ps51Path; AFP_S08_DRIVER = $psDriver; AFP_S08_CAPTURE = $capture; AFP_S08_ROOT = $testRoot; AFP_S08_TOKEN = $ownerToken; AFP_S08_EXIT = '0'; AUDIOFILEFORPHONE_HOST = $EnvironmentHost; PATH = $originalPath }
    $native = Invoke-Owned $cmdPath ('/d /v:off /s /c ""' + $driver + '""') $environment $workingDirectory
    $captureRecord = if (Test-Path -LiteralPath $capture) { Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
    $entries = if (Test-Path -LiteralPath ($capture + '.entries')) { @([IO.File]::ReadAllLines(($capture + '.entries'))).Count } else { 0 }
    return [pscustomobject]@{ native = $native; capture = $captureRecord; capture_path = $capture; app_entries = $entries }
}
function Get-LauncherFunction {
    param([string]$Name)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'AudioFileForPhone.Launcher.ps1'), [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) 'Launcher must parse before production function extraction.'
    $nodes = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name }, $false))
    Assert-True ($nodes.Count -eq 1) ('Expected exactly one production function ' + $Name)
    return [scriptblock]::Create($nodes[0].Extent.Text)
}

try {
    Assert-NoReparse $tempParent; Assert-NoReparse $evidenceParent
    Assert-True ([Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) 'S08 real client tests require x64.'
    Add-Type -TypeDefinition @'
using System; using System.IO; using System.Text; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
namespace AFPS08 { public static class DirectoryOwner {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 [return:MarshalAs(UnmanagedType.Bool)] public static extern bool CreateDirectoryW(string path,IntPtr security);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 private static extern SafeFileHandle CreateFileW(string path,uint access,uint share,IntPtr security,uint mode,uint flags,IntPtr template);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
 private static extern uint GetFinalPathNameByHandleW(SafeFileHandle file,StringBuilder path,uint capacity,uint flags);
 public static string FinalDirectoryPath(string path) {
  using(SafeFileHandle handle=CreateFileW(path,0,7,IntPtr.Zero,3,0x02000000,IntPtr.Zero)) {
   if(handle.IsInvalid)throw new IOException("Owned CWD identity open failed",Marshal.GetLastWin32Error());
   StringBuilder result=new StringBuilder(32768);
   uint length=GetFinalPathNameByHandleW(handle,result,(uint)result.Capacity,0);
   if(length==0 || length>=result.Capacity)throw new IOException("Owned CWD final path failed",Marshal.GetLastWin32Error());
   string final=result.ToString();
   if(!final.StartsWith(@"\\?\",StringComparison.Ordinal) || final.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))throw new IOException("Owned CWD must resolve to a local drive path");
   return final.Substring(4);
  }
 }
}}
'@
    Assert-True ([AFPS08.DirectoryOwner]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'TEMP root must be exclusively reserved.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; $report.marker_create_new = $true
    $localData = New-Directory 'localdata'; $workingDirectory = New-Directory 'unrelated working directory'
    # The OS may canonicalize ancestor casing (TEMP -> Temp) when starting a process.
    # Use the opened owned directory's native spelling; keep exact child CWD assertions.
    Assert-NoReparse $workingDirectory
    $requestedWorkingDirectory = $workingDirectory
    $workingDirectory = [AFPS08.DirectoryOwner]::FinalDirectoryPath($workingDirectory)
    Assert-True ($workingDirectory.Equals($requestedWorkingDirectory, [StringComparison]::OrdinalIgnoreCase)) 'Native CWD canonicalization must change casing only.'
    $report['working_directory_fixture'] = [pscustomobject]@{ requested = $requestedWorkingDirectory; native_final_path = $workingDirectory; case_only_canonicalization = $true }
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    $normalCopy = New-LaunchCopy 'normal'
    $edgeCopy = New-LaunchCopy "launch ! & [brackets] (round) apostrophe's %AFP_S08_PERCENT_SENTINEL% äö"
    $edgeNames = @('folder with spaces', '[brackets]', 'ampersand & folder', "apostrophe's", '(parentheses)', 'exclamation!', 'percent %AFP_S08_PERCENT_SENTINEL%', 'Suomi äö Å ß Größe', ('decomposed a' + [char]0x0308))
    $folders = @($edgeNames | ForEach-Object { New-Directory $_ })
    $hosts = @(@{ name = 'ps51'; path = $ps51Path; edition = 'Desktop' }, @{ name = 'ps7'; path = $ps7Path; edition = 'Core' })
    $alias = @($ps7Paths | Where-Object { $_ -match '\\Microsoft\\WindowsApps\\pwsh\.exe$' } | Select-Object -First 1)
    if ($alias.Count -eq 1) { $hosts += @{ name = 'store-alias'; path = $alias[0]; edition = 'Core' } }
    foreach ($selectedHost in $hosts) {
        $probeArguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'RemoteSigned', '-File', (Join-Path $projectRoot 'AudioFileForPhone.HostProbe.ps1'))
        $baseline = Invoke-Owned $selectedHost.path (($probeArguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ') @{} $workingDirectory
        Assert-True ($baseline.exit_code -eq 0) ('Independent host identity failed: ' + $baseline.stderr)
        $selectedHost.actual = ($baseline.stdout | ConvertFrom-Json).Path
        foreach ($exitCode in @(0, 1, 2, 130)) {
            $name = $selectedHost.name + '-exit-' + $exitCode
            Invoke-Case $name 'S08-A2/S08-A3' {
                param($case)
                $result = Invoke-Bat $name $normalCopy @($folders[0]) $selectedHost.path $exitCode
                Assert-Launch $result $folders[0] $exitCode $selectedHost.edition $selectedHost.actual
                $case.observed_exit = $result.native.exit_code; $case.capture = $result.capture
                $case.elapsed_ms = $result.native.elapsed_ms; $case.no_second_app_entry = $true
            }
        }
        for ($i = 0; $i -lt $folders.Count; $i++) {
            $name = $selectedHost.name + '-literal-' + $i
            Invoke-Case $name 'S08-A1/S08-A3' {
                param($case)
                $folder = $folders[$i]; if ($i -eq 0) { $folder += '\' }
                $result = Invoke-Bat $name $edgeCopy @($folder) $selectedHost.path
                Assert-Launch $result $folder 0 $selectedHost.edition $selectedHost.actual
                $case.capture = $result.capture; $case.elapsed_ms = $result.native.elapsed_ms
            }
        }
    }
    foreach ($invalid in @(@{ name = 'zero'; args = @() }, @{ name = 'empty'; args = @('') }, @{ name = 'multiple'; args = @($folders[0], $folders[1]) }, @{ name = 'empty-second'; args = @($folders[0], '') }, @{ name = 'empty-second-extra'; args = @($folders[0], '', $folders[1]) })) {
        Invoke-Case ('arguments-' + $invalid.name) 'S08-A3' {
            param($case)
            $result = Invoke-Bat ('args-' + $invalid.name) $normalCopy $invalid.args $ps7Path
            Assert-True ($result.native.exit_code -eq 1 -and $null -eq $result.capture -and $result.native.stdout -match 'exactly one folder') 'Invalid folder count must reject before application entry and finish without pause input.'
            $case.observed_exit = $result.native.exit_code; $case.elapsed_ms = $result.native.elapsed_ms
        }
    }
    Invoke-Case 'direct-HostPath-overrides-environment' 'S08-A1/S08-A3' {
        param($case)
        $result = Invoke-DirectLauncher 'host-precedence' $edgeCopy ($folders[0] + '\') $ps7Path $ps51Path
        Assert-Launch $result ($folders[0] + '\') 0 'Core' $ps7Path
        $case.capture = $result.capture; $case.elapsed_ms = $result.native.elapsed_ms
    }
    Invoke-Case 'auto-prefers-usable-PS7' 'S08-A1' {
        param($case)
        $result = Invoke-Bat 'auto-ps7' $normalCopy @($folders[0]) ''
        Assert-Launch $result $folders[0] 0 'Core' $ps7Path
        $case.capture = $result.capture; $case.elapsed_ms = $result.native.elapsed_ms
    }
    Invoke-Case 'auto-PS7-discovery-absent-real-PS51' 'S08-A1/S08-A2' {
        param($case)
        $emptyInstallRoot = New-Directory 'process-only-empty-ProgramW6432'
        $result = Invoke-Bat 'auto-ps51' $normalCopy @($folders[0]) '' 0 ($systemDirectory + ';' + (Split-Path -Parent $ps51Path)) $emptyInstallRoot
        Assert-Launch $result $folders[0] 0 'Desktop' $ps51Path
        $case.capture = $result.capture; $case.elapsed_ms = $result.native.elapsed_ms; $case.discovery_absence_process_environment_simulated = $true
    }
    Invoke-Case 'real-owned-Windows-shortcut-route' 'S08-A1/S08-A3' {
        param($case)
        $capture = Join-Path $testRoot 'capture-shortcut.json'
        $shortcutPath = Join-Path $testRoot 'AudioFileForPhone owned shortcut.lnk'
        $driver = Join-Path $testRoot 'shortcut-driver.cmd'
        $stdoutPath = Join-Path $testRoot 'shortcut.stdout.txt'; $stderrPath = Join-Path $testRoot 'shortcut.stderr.txt'
        $lines = @('@echo off', 'setlocal DisableDelayedExpansion', 'chcp 65001 >nul',
            ('set "AFP_S08_ROOT=' + $testRoot + '"'), ('set "AFP_S08_TOKEN=' + $ownerToken + '"'),
            ('set "AFP_S08_CAPTURE=' + $capture + '"'), 'set "AFP_S08_EXIT=0"',
            ('set "AUDIOFILEFORPHONE_HOST=' + $ps7Path + '"'), ('set "LOCALAPPDATA=' + $localData + '"'),
            ('"' + (Join-Path $normalCopy 'AudioFileForPhone.bat') + '" "' + $folders[0] + '" <nul >"' + $stdoutPath + '" 2>"' + $stderrPath + '"'))
        Write-NewText $driver ($lines -join "`r`n") -NoBom; Add-Fixture $driver
        $shell = $null; $shortcut = $null; $process = $null
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $cmdPath; $shortcut.Arguments = '/d /v:off /s /c ""' + $driver + '""'
            $shortcut.WorkingDirectory = $workingDirectory; $shortcut.WindowStyle = 7; $shortcut.Save()
            Add-Fixture $shortcutPath
            $info = New-Object Diagnostics.ProcessStartInfo
            $info.FileName = $shortcutPath; $info.UseShellExecute = $true; $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden; $info.WorkingDirectory = $workingDirectory
            $process = [Diagnostics.Process]::Start($info)
            Assert-True ($null -ne $process) 'Shell shortcut must return an owned process handle.'
            if (-not $process.WaitForExit(30000)) { $script:releaseProved = $false; $process.Kill(); $process.WaitForExit(5000) | Out-Null; throw 'Owned shortcut route exceeded deadline; descendant release unproved.' }
            $record = Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json
            $native = [pscustomobject]@{ exit_code = $process.ExitCode; stdout = [IO.File]::ReadAllText($stdoutPath); stderr = [IO.File]::ReadAllText($stderrPath) }
            $result = [pscustomobject]@{ native = $native; capture = $record; app_entries = @([IO.File]::ReadAllLines(($capture + '.entries'))).Count }
            Assert-Launch $result $folders[0] 0 'Core' $ps7Path
            $case.capture = $record; $case.actual_lnk_shell_execute = $true; $case.physical_Desktop_or_Explorer_input = $false
        } finally {
            if ($null -ne $process) { $process.Dispose() }
            if ($null -ne $shortcut) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) | Out-Null }
            if ($null -ne $shell) { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null }
        }
    }
    foreach ($missing in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Launcher.ps1')) {
        $missingCopy = New-LaunchCopy ('missing-' + $missing.Replace('.', '-')) $missing
        Invoke-Case ('missing-' + $missing) 'S08-A3' {
            param($case)
            $result = Invoke-Bat ('missing-' + $missing.Replace('.', '-')) $missingCopy @($folders[0]) $ps7Path
            Assert-True ($result.native.exit_code -eq 1 -and $null -eq $result.capture -and ($result.native.stdout + $result.native.stderr).Contains($missing)) 'Missing runtime must identify exact file, exit1 and never enter application.'
            $case.observed_exit = $result.native.exit_code; $case.elapsed_ms = $result.native.elapsed_ms
        }
    }
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    . (Get-LauncherFunction 'Invoke-AudioHostProbe')
    . (Get-LauncherFunction 'Select-AudioLaunchHost')
    $realNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    $realProbe = (Get-Command Invoke-AudioHostProbe -CommandType Function).ScriptBlock
    $identity = [ordered]@{ SchemaVersion = 1; Path = $ps7Path; Version = '7.6.5'; Edition = 'Core'; OSArchitecture = 'X64'; ProcessArchitecture = 'X64'; ApartmentState = 'STA'; LanguageMode = 'FullLanguage'; MachinePolicy = 'Undefined'; UserPolicy = 'Undefined' }
    $script:injectedNative = $null
    function Invoke-InjectedNative { return $script:injectedNative }
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-InjectedNative}
    try {
        foreach ($scenario in @(
            @{ name = 'unknown-execution-refusal'; status = 'StartFailed'; exit = 1; expected = 'PolicyBlocked' },
            @{ name = 'nonzero-health'; status = 'Completed'; exit = 1; expected = 'PolicyBlocked' },
            @{ name = 'missing-executable'; status = 'MissingExecutable'; exit = $null; expected = 'Unavailable' },
            @{ name = 'released-timeout'; status = 'Timeout'; exit = $null; expected = 'Timeout' },
            @{ name = 'unreleased-timeout'; status = 'Timeout'; exit = $null; expected = 'ReleaseUnproved'; released = $false },
            @{ name = 'held-pipe-timeout'; status = 'Timeout'; exit = $null; expected = 'ReleaseUnproved'; drained = $false },
            @{ name = 'malformed-identity'; status = 'Completed'; exit = 0; expected = 'PolicyBlocked'; malformed = $true },
            @{ name = 'truncated-identity'; status = 'Completed'; exit = 0; expected = 'PolicyBlocked'; truncated = $true },
            @{ name = 'managed-language'; status = 'Completed'; exit = 0; expected = 'PolicyBlocked'; property = 'LanguageMode'; value = 'ConstrainedLanguage' },
            @{ name = 'machine-signing-policy'; status = 'Completed'; exit = 0; expected = 'PolicyBlocked'; property = 'MachinePolicy'; value = 'AllSigned' },
            @{ name = 'user-restricted-policy'; status = 'Completed'; exit = 0; expected = 'PolicyBlocked'; property = 'UserPolicy'; value = 'Restricted' },
            @{ name = 'x86-host'; status = 'Completed'; exit = 0; expected = 'Unavailable'; property = 'ProcessArchitecture'; value = 'X86' },
            @{ name = 'arm64-OS'; status = 'Completed'; exit = 0; expected = 'Unavailable'; property = 'OSArchitecture'; value = 'Arm64' },
            @{ name = 'MTA-host'; status = 'Completed'; exit = 0; expected = 'Unavailable'; property = 'ApartmentState'; value = 'MTA' },
            @{ name = 'unsupported-version'; status = 'Completed'; exit = 0; expected = 'Unavailable'; property = 'Version'; value = '8.0.1' }
        )) {
            Invoke-Case ('probe-classification-' + $scenario.name) 'S08-A1/S08-A2' {
                param($case)
                $copy = [ordered]@{}; foreach ($key in $identity.Keys) { $copy[$key] = $identity[$key] }
                if ($scenario.ContainsKey('property')) { $copy[$scenario.property] = $scenario.value }
                $json = if ($scenario.malformed) { '{bad json' } else { $copy | ConvertTo-Json -Compress }
                $script:injectedNative = [pscustomobject]@{ Status = $scenario.status; ExitCode = $scenario.exit; Stdout = $json; Stderr = ''; Error = 'injected startup condition'; ProcessReleased = (-not $scenario.ContainsKey('released') -or $scenario.released); PipeDrainCompleted = (-not $scenario.ContainsKey('drained') -or $scenario.drained); StdoutTruncated = [bool]$scenario.truncated; StderrTruncated = $false }
                $result = Invoke-AudioHostProbe -HostPath $ps7Path -StartupTimeoutSeconds 1 -ProbePath (Join-Path $normalCopy 'AudioFileForPhone.HostProbe.ps1')
                Assert-True ($result.Status -ceq $scenario.expected) ('Incorrect startup classification: ' + $scenario.name + ' -> ' + $result.Status)
                $case.injected = $true; $case.expected = $scenario.expected; $case.observed = $result.Status
            }
        }
    } finally { Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value $realNative }
    function Get-AudioHostCandidates { return @('C:\owned-preferred.exe', 'C:\owned-fallback.exe') }
    $script:selectionProbes = New-Object 'System.Collections.Generic.List[string]'
    $script:firstProbe = $null
    function Invoke-SelectionProbe {
        param([string]$HostPath, [int]$StartupTimeoutSeconds)
        $script:selectionProbes.Add($HostPath)
        if ($script:selectionProbes.Count -eq 1) { return $script:firstProbe }
        $copy = [ordered]@{}; foreach ($key in $identity.Keys) { $copy[$key] = $identity[$key] }; $copy.Path = $HostPath
        return [pscustomobject]@{ Status = 'Ready'; Identity = [pscustomobject]$copy; Error = ''; ProcessReleased = $true; PipeDrainCompleted = $true }
    }
    Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value ${function:Invoke-SelectionProbe}
    try {
        foreach ($scenario in @(
            @{ name = 'missing-preferred-fallback'; status = 'Unavailable'; released = $true; drained = $true; count = 2; throws = $false },
            @{ name = 'safe-timeout-fallback'; status = 'Timeout'; released = $true; drained = $true; count = 2; throws = $false },
            @{ name = 'blocked-no-fallback'; status = 'PolicyBlocked'; released = $true; drained = $true; count = 1; throws = $true },
            @{ name = 'unproved-no-fallback'; status = 'ReleaseUnproved'; released = $false; drained = $false; count = 1; throws = $true },
            @{ name = 'timeout-held-pipe-no-fallback'; status = 'Timeout'; released = $true; drained = $false; count = 1; throws = $true },
            @{ name = 'explicit-broken-no-fallback'; status = 'Unavailable'; released = $true; drained = $true; count = 1; throws = $true; explicit = $true }
        )) {
            Invoke-Case ('selection-' + $scenario.name) 'S08-A2' {
                param($case)
                $script:selectionProbes.Clear()
                $script:firstProbe = [pscustomobject]@{ Status = $scenario.status; Identity = $null; Error = 'injected preentry condition'; ProcessReleased = $scenario.released; PipeDrainCompleted = $scenario.drained }
                $thrown = $false; $selected = $null
                try { $selected = Select-AudioLaunchHost -HostPath $(if ($scenario.explicit) { 'C:\owned-explicit.exe' } else { '' }) -StartupTimeoutSeconds 1 } catch { $thrown = $true }
                Assert-True ($thrown -eq $scenario.throws -and $script:selectionProbes.Count -eq $scenario.count) 'Fallback count/refusal must match safe preentry policy.'
                if (-not $thrown) { Assert-True ($selected.Path -ceq 'C:\owned-fallback.exe') 'Only the proved fallback may be selected.' }
                $case.injected = $true; $case.probe_count = $script:selectionProbes.Count; $case.refused = $thrown
            }
        }
    } finally { Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value $realProbe }
    Invoke-Case 'real-missing-preferred-before-entry-falls-back' 'S08-A1/S08-A2' {
        param($case)
        $script:missingHost = Join-Path $testRoot 'never-created-host.exe'
        $script:missingProbePath = Join-Path $normalCopy 'AudioFileForPhone.HostProbe.ps1'
        $result = Invoke-AudioHostProbe -HostPath $script:missingHost -StartupTimeoutSeconds 1 -ProbePath $script:missingProbePath
        Assert-True ($result.Status -ceq 'Unavailable' -and $result.ProcessReleased -and $result.PipeDrainCompleted -and $result.NativeResult.Status -ceq 'MissingExecutable') 'A real missing executable creates no child/pipes and must permit preentry fallback.'
        function Get-AudioHostCandidates { return @($script:missingHost, $ps51Path) }
        function Invoke-RealMissingProbe {
            param([string]$HostPath, [int]$StartupTimeoutSeconds)
            $script:selectionProbes.Add($HostPath)
            return & $realProbe -HostPath $HostPath -StartupTimeoutSeconds $StartupTimeoutSeconds -ProbePath $script:missingProbePath
        }
        $script:selectionProbes.Clear()
        Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value ${function:Invoke-RealMissingProbe}
        try { $selected = Select-AudioLaunchHost -StartupTimeoutSeconds 15 } finally { Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value $realProbe }
        Assert-True ($script:selectionProbes.Count -eq 2 -and $selected.Path -ieq $ps51Path) 'A missing preferred path must select actual PS51 once.'
        $case.native_status = $result.NativeResult.Status; $case.fallback_identity = $selected
    }
    Invoke-Case 'real-startup-deadline-and-released-fallback' 'S08-A2' {
        param($case)
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        $childSource = Join-Path $testRoot 'HangingHost.cs'; $child = Join-Path $testRoot 'HangingHost.exe'
        Write-NewText $childSource 'using System; using System.Threading; class HangingHost { static int Main(string[] args) { Console.Out.Write("startup waiting"); Thread.Sleep(60000); return 0; } }'
        Add-Fixture $childSource
        $compiled = Invoke-AudioNativeProcess -ExecutablePath $compiler -Arguments @('/nologo', '/target:exe', ('/out:' + $child), $childSource) -TimeoutMilliseconds 20000 -Operation 'compile independent S08 hanging host'
        Assert-True ($compiled.Status -ceq 'Completed' -and $compiled.ExitCode -eq 0 -and $compiled.ProcessReleased -and $compiled.PipeDrainCompleted) ('Owned host fixture compile failed: ' + $compiled.Stderr)
        Add-Fixture $child
        $result = Invoke-AudioHostProbe -HostPath $child -StartupTimeoutSeconds 1 -ProbePath (Join-Path $normalCopy 'AudioFileForPhone.HostProbe.ps1')
        if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { $script:releaseProved = $false }
        Assert-True ($result.Status -ceq 'Timeout' -and $result.ProcessReleased -and $result.PipeDrainCompleted) 'Real never-exiting startup must time out and prove owned child/pipe release.'
        Assert-True ($result.NativeResult.ElapsedMilliseconds -ge 900 -and $result.NativeResult.ElapsedMilliseconds -lt 9000) 'One-second startup deadline must finish within bounded teardown allowance.'
        $case.timeout_ms = 1000; $case.elapsed_ms = $result.NativeResult.ElapsedMilliseconds; $case.process_released = $result.ProcessReleased; $case.pipe_drain_completed = $result.PipeDrainCompleted
        $script:deadlineChild = $child; $script:deadlineProbePath = Join-Path $normalCopy 'AudioFileForPhone.HostProbe.ps1'
        function Get-AudioHostCandidates { return @($script:deadlineChild, $ps51Path) }
        function Invoke-RealDeadlineProbe {
            param([string]$HostPath, [int]$StartupTimeoutSeconds)
            $script:selectionProbes.Add($HostPath)
            $observed = & $realProbe -HostPath $HostPath -StartupTimeoutSeconds $StartupTimeoutSeconds -ProbePath $script:deadlineProbePath
            if (-not $observed.ProcessReleased -or -not $observed.PipeDrainCompleted) { $script:releaseProved = $false }
            return $observed
        }
        $script:selectionProbes.Clear()
        Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value ${function:Invoke-RealDeadlineProbe}
        $fallbackTimer = [Diagnostics.Stopwatch]::StartNew()
        try { $selected = Select-AudioLaunchHost -StartupTimeoutSeconds 5 } finally { $fallbackTimer.Stop(); Set-Item -LiteralPath Function:script:Invoke-AudioHostProbe -Value $realProbe }
        Assert-True ($script:selectionProbes.Count -eq 2 -and $selected.Path -ieq $ps51Path -and $selected.Edition -ceq 'Desktop' -and $selected.ApartmentState -ceq 'STA') 'Actual startup timeout must safely release and select actual x64 STA Windows PowerShell.'
        Assert-True ($fallbackTimer.ElapsedMilliseconds -ge 4900 -and $fallbackTimer.ElapsedMilliseconds -lt 14000) 'Actual fallback must include the configured five-second deadline and bounded teardown/healthy-host startup.'
        $case.fallback_probe_timeout_ms = 5000; $case.fallback_elapsed_ms = $fallbackTimer.ElapsedMilliseconds
        $case.fallback_identity = $selected
    }
    Invoke-Case 'identity-JSON-ASCII-lossless-Unicode' 'S08-A1/S08-A3' {
        param($case)
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'AudioFileForPhone.HostProbe.ps1'), [ref]$tokens, [ref]$errors)
        Assert-True ($errors.Count -eq 0) 'Probe must parse before serializer extraction.'
        $nodes = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Write-AudioHostIdentity' }, $false))
        Assert-True ($nodes.Count -eq 1) 'Expected exactly one production probe serializer.'
        . ([scriptblock]::Create($nodes[0].Extent.Text))
        $path = 'C:\Suomi äö Å\Größe\decomposed a' + [char]0x0308 + [char]0xd83c + [char]0xdfb5 + '\pwsh.exe'
        $encoded = Write-AudioHostIdentity ([ordered]@{ Path = $path; Version = '7.6.5' })
        Assert-True ($encoded -notmatch '[^\x00-\x7f]' -and ($encoded | ConvertFrom-Json).Path -ceq $path) 'Probe stdout must roundtrip all UTF16 units through ASCII-only JSON, independently of PS51 console encoding.'
        $case.injected = $true; $case.ASCII_only = $true; $case.literal_UTF16_roundtrip = $true
    }
    $report.exercised_hosts = @($report.cases | Where-Object { $null -ne $_.PSObject.Properties['capture'] } | ForEach-Object { $_.capture } | Select-Object path, version, edition, process_64bit, apartment -Unique)
    $report.copied_bytes_unchanged = $true
    $report.status = 'pass'
} catch { $report.error = $_.Exception.Message; Write-Warning $report.error }
finally {
    $report.source_after = Get-Inventory $sourcePaths $projectRoot
    $report.source_unchanged = (($report.source_before | ConvertTo-Json -Depth 5 -Compress) -ceq ($report.source_after | ConvertTo-Json -Depth 5 -Compress))
    $report.parent_path_unchanged = $env:PATH -ceq $originalPath
    if (-not $report.source_unchanged -or -not $report.parent_path_unchanged) { $report.status = 'fail'; $report.error = 'Source bytes or parent PATH changed during S08 tests.' }
    if ($created) {
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Depth 5 -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Depth 5 -Compress))
        if (-not $report.synthetic_unchanged) { $report.status = 'fail'; $report.error = 'Owned runtime/driver fixture bytes changed during execution.' }
        $report.descendant_release_proved = $releaseProved
        if ($releaseProved) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName -and [IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Exact cleanup root/name/token refused.'
            Assert-SafeTree $resolved; Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
    }
    if (-not $report.cleanup_verified -or -not $report.descendant_release_proved) { $report.status = 'fail' }
    $report.finished_utc = [DateTime]::UtcNow.ToString('o')
    Assert-NoReparse $evidenceParent; Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 20)
}
if ($report.status -ceq 'pass') { Write-Host ('S08 launcher: ' + $report.cases.Count + ' groups passed with real Windows CMD/hosts.'); exit 0 }
exit 1
