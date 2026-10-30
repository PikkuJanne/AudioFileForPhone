<#
Focused repair R1: unmodified production BATs in an isolated native console.
Inert unsigned PS1 fixtures verify literal argument transport and exit contracts;
real converter startup is separately exercised with an intentionally missing helper.
All Internet marks are deterministic ADS fixtures, not browser-extraction evidence.
The policy adapter requests real process-only AllSigned to reproduce a File-entry
denial; it neither changes nor establishes MachinePolicy/UserPolicy coverage.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath,
      [ValidateSet('R1')][string]$Task = 'R1', [string]$RunLabel = 'local')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$evidence = [IO.Path]::GetFullPath($EvidencePath)
if ([IO.File]::Exists($evidence)) { throw 'Use a fresh EvidencePath.' }
if (-not [IO.Directory]::Exists((Split-Path -Parent $evidence))) { throw 'Evidence parent must already exist.' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('AFP-R1-' + [guid]::NewGuid().ToString('N'))
$token = [guid]::NewGuid().ToString('N')
$owner = Join-Path $testRoot '.r1-owner'
$cmdPath = Join-Path $env:SystemRoot 'System32/cmd.exe'
$realHost = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$runtimeNames = @('AudioFileForPhone.bat', 'Setup-AudioFileForPhone.bat', 'AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1', 'tests/Test-DirectLauncher.ps1', 'tests/DirectLauncher.Console.cs')
$policyBefore = @(Get-ExecutionPolicy -List | ForEach-Object { [ordered]@{ scope = [string]$_.Scope; policy = [string]$_.ExecutionPolicy } })
$os = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$report = [ordered]@{
    schema_version = 1; task = $Task; run_label = $RunLabel; mode = 'native_console_direct_bat'; status = 'fail'; error = $null
    command = [Environment]::CommandLine; started_utc = [datetime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = [string]$PSVersionTable.PSVersion; edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $os.CurrentBuildNumber + '.' + $os.UBR
    policies_before = $policyBefore; policies_after = @(); policies_unchanged = $false
    source_hashes = @(); source_before = @(); source_after = @(); source_unchanged = $false
    parent_path_unchanged = $false; parent_module_path_unchanged = $false; descendant_release_proved = $false
    cases = @(); fixture_root = $testRoot
    internet_marks = 'Deterministically applied Zone.Identifier ZoneId=3 to disposable unsigned PS1 fixtures on NTFS.'
    managed_policy_coverage = 'NOT_RUN: no real MachinePolicy/UserPolicy configured; workstation policies unchanged.'
    policy_denial_fixture = 'Disposable selected-host adapter requests real AllSigned or RemoteSigned at process scope; genuine unsigned File-entry PSSecurityException reaches unchanged production BAT and final console pause. RemoteSigned baseline specifically refuses the Internet-marked unsigned fixture.'
    audio_conversion = 'NOT_RUN in this inert/startup suite; no Music resolver or personal audio is used.'
    explorer_drag_drop = 'NOT_RUN: native console command argument transport is not Explorer drag/drop.'
    owner_testing_required = 'none'; cleanup_verified = $false
}

function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Write-NewText {
    param([string]$Path, [string]$Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding($true)
        $bytes = $encoding.GetPreamble() + $encoding.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}
function Mark-Internet {
    param([string]$Path)
    Set-Content -LiteralPath $Path -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3`r`n" -Encoding ASCII
    Assert-True ((Get-Content -LiteralPath $Path -Stream Zone.Identifier -Raw).Contains('ZoneId=3')) 'Internet mark was not created.'
}
function Get-Policy { return @(Get-ExecutionPolicy -List | ForEach-Object { [ordered]@{ scope = [string]$_.Scope; policy = [string]$_.ExecutionPolicy } }) }
function Get-Inventory { return @($runtimeNames | ForEach-Object { [pscustomobject]@{ path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() } }) }
function Quote-Native {
    param([AllowEmptyString()][string]$Value)
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}
function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse fixture ancestor refused.'
        $item = $item.Parent
    }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse fixture child refused.'
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
        }
    }
}

$captureStub = @'
[CmdletBinding()]
param([switch]$FromBatchLauncher)
if (-not $FromBatchLauncher) { throw 'Expected direct BAT switch.' }
$process = [Diagnostics.Process]::GetCurrentProcess()
$record = [ordered]@{
 input = $env:AUDIOFILEFORPHONE_INPUT; extra = @($args | Where-Object { $null -ne $_ }); from_batch = [bool]$FromBatchLauncher
 edition = $PSVersionTable.PSEdition; version = [string]$PSVersionTable.PSVersion
 host_path = $process.MainModule.FileName; x64 = [Environment]::Is64BitProcess
 apartment = [string][Threading.Thread]::CurrentThread.ApartmentState; cwd = (Get-Location).ProviderPath
 policy = [string](Get-ExecutionPolicy); internet_mark = [string](Get-Content -LiteralPath $PSCommandPath -Stream Zone.Identifier -Raw)
}
[IO.File]::AppendAllText($env:AFP_R1_ENTRIES, "entered`n")
[IO.File]::WriteAllText($env:AFP_R1_CAPTURE, ($record | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
Write-Host 'R1 inert runtime entered.'
exit ([int]$env:AFP_R1_EXIT)
'@
$setupStub = @'
[CmdletBinding()]
param()
[IO.File]::AppendAllText($env:AFP_R1_ENTRIES, "entered`n")
[IO.File]::WriteAllText($env:AFP_R1_CAPTURE, '{"setup":true}', (New-Object Text.UTF8Encoding($false)))
Write-Host 'R1 inert setup entered.'
exit ([int]$env:AFP_R1_EXIT)
'@
function New-Fixture {
    param([string]$Name, [switch]$MissingRuntime, [switch]$ParseError, [switch]$RealMissingHelper)
    $directory = Join-Path $testRoot $Name
    $null = [IO.Directory]::CreateDirectory($directory)
    foreach ($name in @('AudioFileForPhone.bat', 'Setup-AudioFileForPhone.bat')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination (Join-Path $directory $name)
        Assert-True ((Get-FileHash -LiteralPath (Join-Path $directory $name)).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'BAT fixture changed production bytes.'
    }
    if (-not $MissingRuntime) {
        foreach ($name in @('AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.ps1')) {
            $path = Join-Path $directory $name
            if ($RealMissingHelper) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $path }
            else { $text = if ($ParseError) { 'param( [broken' } elseif ($name -ceq 'AudioFileForPhone.ps1') { $captureStub } else { $setupStub }; Write-NewText $path $text }
            Mark-Internet $path
        }
    }
    return $directory
}
function Invoke-BatCase {
    param([string]$Name, [string]$Directory, [string[]]$Folders = @(), [int]$ExitCode = 0,
          [string]$Entry = 'AudioFileForPhone.bat', [hashtable]$ExtraEnvironment = @{},
          [int]$ExpectedExit = $ExitCode, [bool]$ExpectEntry = $true, [string]$ExpectedText = '')
    $case = [ordered]@{ name = $Name; status = 'fail'; entry = $Entry; expected_exit = $ExpectedExit; native = $null; capture = $null }
    $old = @{}
    $pathBefore = $env:PATH
    $modulePathBefore = $env:PSModulePath
    try {
        $capture = Join-Path $testRoot ($Name + '-capture.json')
        $entries = Join-Path $testRoot ($Name + '-entries.txt')
        $nativeReport = Join-Path $testRoot ($Name + '-console.json')
        $environment = @{
            AFP_R1_BAT = Join-Path $Directory $Entry; AFP_R1_CAPTURE = $capture; AFP_R1_ENTRIES = $entries
            AFP_R1_EXIT = [string]$ExitCode; AFP_R1_REAL_HOST = $realHost
            AFP_R1_REAL_SYSTEMROOT = $env:SystemRoot
            AFP_R1_SENTINEL = 'SHOULD_NOT_EXPAND'; PATH = ''; LOCALAPPDATA = $localData
        }
        $command = '"%AFP_R1_BAT%"'
        for ($i = 0; $i -lt $Folders.Count; $i++) {
            if ($Folders[$i].Length -eq 0) { $command += ' ""' }
            else { $environment['AFP_R1_ARG' + $i] = $Folders[$i]; $command += ' "%AFP_R1_ARG' + $i + '%"' }
        }
        foreach ($key in $ExtraEnvironment.Keys) { $environment[$key] = [string]$ExtraEnvironment[$key] }
        foreach ($key in $environment.Keys) { $old[$key] = [Environment]::GetEnvironmentVariable($key, 'Process'); [Environment]::SetEnvironmentVariable($key, [string]$environment[$key], 'Process') }
        $info = New-Object Diagnostics.ProcessStartInfo
        $info.FileName = $controller; $info.UseShellExecute = $false; $info.CreateNoWindow = $true
        $info.Arguments = (@($cmdPath, ('/d /v:off /s /c "' + $command + '"'), $working, $nativeReport, '25000') | ForEach-Object { Quote-Native $_ }) -join ' '
        $process = New-Object Diagnostics.Process; $process.StartInfo = $info
        try {
            Assert-True $process.Start() 'Could not start isolated console controller.'
            if (-not $process.WaitForExit(45000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw 'Controller timed out; owned test tree is guarded by job object.' }
            $controllerExit = $process.ExitCode
        } finally { $process.Dispose() }
        Assert-True ([IO.File]::Exists($nativeReport)) 'Console report missing.'
        $native = Get-Content -LiteralPath $nativeReport -Raw -Encoding UTF8 | ConvertFrom-Json
        $case.native = $native
        Assert-True ($controllerExit -eq 0 -and [string]::IsNullOrEmpty($native.error)) ('Console controller failed: ' + $native.error + '; ' + $native.text)
        Assert-True ($native.pause_seen -and $native.still_waiting_before_key -and $native.key_injected -and $native.owned_tree_released) 'Real BAT pause/key/release contract failed.'
        Assert-True ($native.exit_code -eq $ExpectedExit) ('Expected exit ' + $ExpectedExit + ', got ' + $native.exit_code + '; ' + $native.text)
        if ($ExpectedText) { Assert-True ($native.text -match $ExpectedText) ('Expected console diagnostic missing: ' + $ExpectedText + '; ' + $native.text) }
        $entryCount = if ([IO.File]::Exists($entries)) { [IO.File]::ReadAllLines($entries).Count } else { 0 }
        Assert-True ($entryCount -eq $(if ($ExpectEntry) { 1 } else { 0 })) ('Unexpected runtime entry count: ' + $entryCount)
        if ($ExpectEntry) {
            $case.capture = Get-Content -LiteralPath $capture -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($Entry -ceq 'AudioFileForPhone.bat') {
                $record = $case.capture
                Assert-True ($record.input -ceq $Folders[0] -and $record.from_batch -and @($record.extra | Where-Object { $null -ne $_ }).Count -eq 0) 'Literal input/switch transport failed.'
                Assert-True ($record.edition -ceq 'Desktop' -and $record.x64 -and $record.apartment -ceq 'STA' -and $record.host_path -ieq $realHost) 'BAT did not choose exact built-in x64 WinPS STA.'
                Assert-True ($record.cwd -ieq $working -and $record.policy -ceq 'Bypass' -and $record.internet_mark.Contains('ZoneId=3')) 'CWD/process policy/Internet-mark contract failed.'
            }
        }
        $case.status = 'pass'
    } catch {
        $case['error'] = $_.Exception.Message
        throw
    } finally {
        foreach ($key in $old.Keys) { [Environment]::SetEnvironmentVariable($key, $old[$key], 'Process') }
        $case['parent_path_unchanged'] = $pathBefore -ceq $env:PATH
        $case['parent_module_path_unchanged'] = $modulePathBefore -ceq $env:PSModulePath
        $report.cases += [pscustomobject]$case
    }
}

$created = $false
try {
    Assert-True ([Environment]::Is64BitProcess -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) 'Run this suite on x64 Windows.'
    Assert-True ([IO.File]::Exists($realHost) -and [IO.File]::Exists($csc)) 'Built-in x64 WinPS and .NET test compiler required.'
    Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class R1Reserve { [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool CreateDirectoryW(string path,IntPtr attributes); }
'@
    $created = [R1Reserve]::CreateDirectoryW($testRoot, [IntPtr]::Zero)
    Assert-True $created 'Test TEMP root must be exclusively reserved.'
    Write-NewText $owner $token
    $working = Join-Path $testRoot 'unrelated working directory'; $null = [IO.Directory]::CreateDirectory($working)
    $localData = Join-Path $testRoot 'local data'; $null = [IO.Directory]::CreateDirectory($localData)
    $report.source_hashes = Get-Inventory
    $report.source_before = $report.source_hashes
    $controller = Join-Path $testRoot 'console-controller.exe'
    & $csc /nologo /target:exe ('/out:' + $controller) (Join-Path $PSScriptRoot 'DirectLauncher.Console.cs')
    Assert-True ($LASTEXITCODE -eq 0 -and [IO.File]::Exists($controller)) 'Test console controller did not compile.'
    $ordinary = New-Fixture 'application'
    $inputs = @('plain', 'spaces and (parentheses)', 'ampersand & safe', 'percent %AFP_R1_SENTINEL%', 'bang ! safe', "apostrophe's", ('Unicode ' + [char]0x00e4 + [char]0x00f6 + [char]0x4e2d), 'all & (%) ! apostrophe''s')
    $folders = @($inputs | ForEach-Object { $path = Join-Path $testRoot $_; $null = [IO.Directory]::CreateDirectory($path); $path })
    foreach ($code in @(0, 1, 2, 130, 37)) { Invoke-BatCase ('exit-' + $code) $ordinary @($folders[0]) -ExitCode $code }
    for ($i = 0; $i -lt $folders.Count; $i++) { Invoke-BatCase ('input-' + $i) $ordinary @($folders[$i]) }
    Invoke-BatCase 'trailing-separator' $ordinary @($folders[0] + '\')
    $strangeApp = New-Fixture ('app & (%) ! apostrophe''s ' + [char]0x00e4 + [char]0x4e2d)
    Invoke-BatCase 'application-location' $strangeApp @($folders[6])
    Invoke-BatCase 'contaminated-parent-modules' $ordinary @($folders[0]) -ExtraEnvironment @{ PSModulePath = (Join-Path $testRoot 'incompatible caller modules') }
    $invalids = @(@(), @(''), @($folders[0], $folders[1]), @('', $folders[0]), @($folders[0], ''), @($folders[0], '', $folders[1]))
    for ($i = 0; $i -lt $invalids.Count; $i++) { Invoke-BatCase ('invalid-' + $i) $ordinary $invalids[$i] -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'exactly one (audio )?folder' }
    $missing = New-Fixture 'missing-runtime' -MissingRuntime
    $parse = New-Fixture 'parse-error' -ParseError
    $helper = New-Fixture 'real-missing-helper' -RealMissingHelper
    foreach ($entry in @('AudioFileForPhone.bat', 'Setup-AudioFileForPhone.bat')) {
        $prefix = if ($entry -ceq 'AudioFileForPhone.bat') { 'converter' } else { 'setup' }
        $argsForEntry = if ($prefix -ceq 'converter') { @($folders[0]) } else { @() }
        Invoke-BatCase ($prefix + '-missing-runtime') $missing $argsForEntry -Entry $entry -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'missing'
        Invoke-BatCase ($prefix + '-missing-host') $ordinary $argsForEntry -Entry $entry -ExtraEnvironment @{ SystemRoot = (Join-Path $testRoot 'missing-system-root') } -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'PowerShell'
        Invoke-BatCase ($prefix + '-parse-error') $parse $argsForEntry -Entry $entry -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'ParserError|Missing|Unexpected'
        Invoke-BatCase ($prefix + '-real-missing-helper') $helper $argsForEntry -Entry $entry -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'HelperMissing|missing|required'
    }
    foreach ($code in @(0, 1, 130)) { Invoke-BatCase ('setup-exit-' + $code) $ordinary @() -Entry 'Setup-AudioFileForPhone.bat' -ExitCode $code }
    Invoke-BatCase 'setup-extra' $ordinary @($folders[0]) -Entry 'Setup-AudioFileForPhone.bat' -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'no arguments'
    Invoke-BatCase 'setup-empty' $ordinary @('') -Entry 'Setup-AudioFileForPhone.bat' -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'no arguments'

    $adapterRoot = Join-Path $testRoot 'policy-system-root'
    $adapterDirectory = Join-Path $adapterRoot 'System32/WindowsPowerShell/v1.0'
    $null = [IO.Directory]::CreateDirectory($adapterDirectory)
    $adapterSource = Join-Path $testRoot 'policy-host.cs'
    Write-NewText $adapterSource @'
using System; using System.Diagnostics; using System.IO; using System.Text;
internal static class PolicyHost {
 static string Quote(string value) { return "\""+value.Replace("\\", "\\").Replace("\"","\\\"")+"\""; }
 static int Main(string[] args) {
  File.AppendAllText(Environment.GetEnvironmentVariable("AFP_R1_HOST_ENTRIES"),"host\n");
  for(int i=0;i<args.Length-1;i++) if(args[i].Equals("-ExecutionPolicy",StringComparison.OrdinalIgnoreCase)) args[i+1]=Environment.GetEnvironmentVariable("AFP_R1_DENIAL_POLICY");
  StringBuilder command=new StringBuilder(); foreach(string arg in args) command.Append(Quote(arg)).Append(' ');
  ProcessStartInfo info=new ProcessStartInfo(Environment.GetEnvironmentVariable("AFP_R1_REAL_HOST"),command.ToString()); info.UseShellExecute=false;
  info.EnvironmentVariables["SystemRoot"]=Environment.GetEnvironmentVariable("AFP_R1_REAL_SYSTEMROOT");
  info.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetEnvironmentVariable("AFP_R1_REAL_SYSTEMROOT"),@"System32\WindowsPowerShell\v1.0\Modules");
  using(Process process=Process.Start(info)) { process.WaitForExit(); return process.ExitCode; }
 }
}
'@
    $adapter = Join-Path $adapterDirectory 'powershell.exe'
    & $csc /nologo /target:exe ('/out:' + $adapter) $adapterSource
    Assert-True ($LASTEXITCODE -eq 0 -and [IO.File]::Exists($adapter)) 'Policy-denial test adapter did not compile.'
    foreach ($entry in @('AudioFileForPhone.bat', 'Setup-AudioFileForPhone.bat')) {
        $prefix = if ($entry -ceq 'AudioFileForPhone.bat') { 'converter' } else { 'setup' }
        $argsForEntry = if ($prefix -ceq 'converter') { @($folders[0]) } else { @() }
        $hostEntries = Join-Path $testRoot ($prefix + '-host-entries.txt')
        Invoke-BatCase ($prefix + '-policy-denial') $ordinary $argsForEntry -Entry $entry -ExtraEnvironment @{ SystemRoot = $adapterRoot; AFP_R1_HOST_ENTRIES = $hostEntries; AFP_R1_DENIAL_POLICY = 'AllSigned' } -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'PSSecurityException|not digitally signed'
        Assert-True ([IO.File]::ReadAllLines($hostEntries).Count -eq 1) 'Policy refusal must not trigger another host attempt.'
        $remoteEntries = Join-Path $testRoot ($prefix + '-remotesigned-host-entries.txt')
        Invoke-BatCase ($prefix + '-remotesigned-internet-denial') $ordinary $argsForEntry -Entry $entry -ExtraEnvironment @{ SystemRoot = $adapterRoot; AFP_R1_HOST_ENTRIES = $remoteEntries; AFP_R1_DENIAL_POLICY = 'RemoteSigned' } -ExpectedExit 1 -ExpectEntry $false -ExpectedText 'PSSecurityException|not digitally signed'
        Assert-True ([IO.File]::ReadAllLines($remoteEntries).Count -eq 1) 'Internet-mark refusal must not trigger another host attempt.'
    }
    $report.status = 'pass'
} catch { $report.error = $_.Exception.Message }
finally {
    $report.policies_after = Get-Policy
    $report.policies_unchanged = (($policyBefore | ConvertTo-Json -Compress) -ceq ($report.policies_after | ConvertTo-Json -Compress))
    if (-not $report.policies_unchanged) { $report.status = 'fail'; $report.error = 'Workstation execution-policy state changed.' }
    if ($report.source_hashes.Count -gt 0) {
        $report.source_after = Get-Inventory
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        if (-not $report.source_unchanged) { $report.status = 'fail'; $report.error = [string]$report.error + ' Production source changed during tests.' }
    }
    $report.parent_path_unchanged = @($report.cases | Where-Object { -not $_.parent_path_unchanged }).Count -eq 0
    $report.parent_module_path_unchanged = @($report.cases | Where-Object { -not $_.parent_module_path_unchanged }).Count -eq 0
    $report.descendant_release_proved = @($report.cases | Where-Object { $null -eq $_.native -or -not $_.native.owned_tree_released }).Count -eq 0
    if ($created -and [IO.Directory]::Exists($testRoot)) {
        try {
            Assert-True $report.descendant_release_proved 'Owned descendant release unproved; retaining fixture tree without recursive cleanup.'
            Assert-True ([IO.Path]::GetFullPath($testRoot).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) 'Cleanup escaped TEMP.'
            Assert-True ([IO.File]::ReadAllText($owner) -ceq $token) 'Cleanup ownership marker mismatch.'
            Assert-NoReparse $testRoot
            Remove-Item -LiteralPath $testRoot -Recurse -Force
            $report.cleanup_verified = -not [IO.Directory]::Exists($testRoot)
        } catch { $report.status = 'fail'; $report.error = [string]$report.error + ' Cleanup: ' + $_.Exception.Message }
    }
    $report.finished_utc = [datetime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText($evidence, ($report | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
if ($report.status -eq 'pass') { Write-Host ('R1 direct BAT: ' + $report.cases.Count + ' cases passed; actual pause/key/exit observed. Owner testing required: none.'); exit 0 }
Write-Error ('R1 direct BAT failed: ' + $report.error) -ErrorAction Continue
exit 1
