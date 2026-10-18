<#
.SYNOPSIS
Selects a healthy STA PowerShell host before starting one interactive conversion.
.DESCRIPTION
No profiles, downloads, settings writes or persistent policy changes. The BAT
transports its single folder through process-local environment. Direct callers
can supply InputFolder and HostPath. StartupTimeoutSeconds bounds each health
probe, never a conversion.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$InputFolder,
    [string]$HostPath,
    [ValidateRange(1, 60)][int]$StartupTimeoutSeconds = 15,
    [switch]$ShowUsage
)

$ErrorActionPreference = 'Stop'

function ConvertTo-AudioLaunchArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.IndexOf([char]0) -ge 0) { throw 'A native argument cannot contain NUL.' }
    # Windows CRT quoting, including a directory's trailing backslashes.
    $quoted = '"'; $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { $quoted += ('\' * ($slashes * 2 + 1)) + '"' }
        else { $quoted += ('\' * $slashes) + $character }
        $slashes = 0
    }
    return $quoted + ('\' * ($slashes * 2)) + '"'
}

function Get-AudioHostCandidates {
    $paths = @()
    # Only absolute PATH directories grant host-selection authority. Do not use
    # Get-Command's implicit current-directory search or relative PATH entries.
    # Absolute PATH=CWD remains an intentional, compatible choice.
    foreach ($entry in @($env:PATH -split ';')) {
        $directory = $entry.Trim().Trim('"')
        if ($directory -notmatch '^[A-Za-z]:[\\/]' -or $directory.StartsWith('\\')) { continue }
        $candidate = [IO.Path]::Combine($directory, 'pwsh.exe')
        if ([IO.File]::Exists($candidate)) {
            $paths += $candidate
            if ($paths.Count -ge 3) { break }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramW6432)) {
        $paths += Join-Path $env:ProgramW6432 'PowerShell\7\pwsh.exe'
    }
    $system = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) { 'Sysnative' } else { 'System32' }
    $paths += Join-Path $env:SystemRoot ($system + '\WindowsPowerShell\v1.0\powershell.exe')
    return @($paths | Select-Object -Unique)
}

function Invoke-AudioHostProbe {
    param([string]$HostPath, [int]$StartupTimeoutSeconds = 15,
        [string]$ProbePath = (Join-Path $PSScriptRoot 'AudioFileForPhone.HostProbe.ps1'))
    $result = [ordered]@{ Status = 'Unavailable'; Identity = $null; Error = ''; ProcessReleased = $true; PipeDrainCompleted = $true; NativeResult = $null }
    if ($HostPath -notmatch '^[A-Za-z]:[\\/].*\.exe$' -or $HostPath.IndexOf([char]0) -ge 0) {
        $result.Error = 'Choose an absolute local .exe host path.'
        return [pscustomobject]$result
    }
    $native = Invoke-AudioNativeProcess -ExecutablePath $HostPath -Arguments @(
        '-NoLogo', '-NoProfile', '-NonInteractive', '-STA', '-ExecutionPolicy', 'RemoteSigned',
        '-File', $ProbePath
    ) -TimeoutMilliseconds ($StartupTimeoutSeconds * 1000) -Operation 'PowerShell startup health' -MaxStdoutChars 32768 -MaxStderrChars 8192
    $result.NativeResult = $native
    $result.ProcessReleased = $native.ProcessReleased
    $result.PipeDrainCompleted = $native.PipeDrainCompleted
    $result.Error = $native.Error
    if (-not $native.ProcessReleased -or ($native.Status -eq 'Timeout' -and -not $native.PipeDrainCompleted)) {
        $result.Status = 'ReleaseUnproved'
    }
    elseif ($native.Status -eq 'MissingExecutable') {
        $result.Status = 'Unavailable'
        # No child or pipes were created for this known pre-start failure.
        $result.PipeDrainCompleted = $true
    }
    elseif ($native.Status -eq 'Timeout') { $result.Status = 'Timeout' }
    elseif ($native.Status -ne 'Completed' -or $native.ExitCode -ne 0 -or $native.StdoutTruncated -or $native.StderrTruncated) {
        # Unstructured/localized refusal might be application control. Never
        # interpret it as permission to try another engine.
        $result.Status = 'PolicyBlocked'
        $result.Error = 'Host refused its health check or did not start safely. Use an allowed direct host; respect organization policy. ' + $native.Error + ' ' + $native.Stderr
    }
    else {
        try {
            $identity = ConvertFrom-Json -InputObject $native.Stdout -ErrorAction Stop
            if ($identity.SchemaVersion -ne 1 -or $identity.Path -notmatch '^[A-Za-z]:[\\/].*\.exe$') { throw 'Host identity is incomplete.' }
            $result.Identity = $identity
            if ($identity.LanguageMode -cne 'FullLanguage' -or $identity.MachinePolicy -in @('Restricted', 'AllSigned') -or $identity.UserPolicy -in @('Restricted', 'AllSigned')) {
                $result.Status = 'PolicyBlocked'; $result.Error = 'Managed language or signing policy requires an allowed direct launch. No host fallback.'
            }
            elseif ($identity.OSArchitecture -cne 'X64' -or $identity.ProcessArchitecture -cne 'X64' -or $identity.ApartmentState -cne 'STA') {
                $result.Error = 'This launcher requires an x64 Windows OS, x64 host process and STA. Select a supported host.'
            }
            elseif (($identity.Edition -ceq 'Core' -and ([version]$identity.Version).Major -eq 7) -or
                ($identity.Edition -ceq 'Desktop' -and ([version]$identity.Version).Major -eq 5 -and ([version]$identity.Version).Minor -ge 1)) {
                $result.Status = 'Ready'
            }
            else { $result.Error = 'Host must be PowerShell 7 or Windows PowerShell 5.1.' }
        }
        catch { $result.Status = 'PolicyBlocked'; $result.Error = 'Could not verify host identity; no fallback. ' + $_.Exception.Message }
    }
    return [pscustomobject]$result
}

function Select-AudioLaunchHost {
    param([string]$HostPath, [int]$StartupTimeoutSeconds = 15)
    $explicitHost = -not [string]::IsNullOrEmpty($HostPath)
    $candidates = if ($explicitHost) { @($HostPath) } else { @(Get-AudioHostCandidates) }
    foreach ($candidate in $candidates) {
        $probe = Invoke-AudioHostProbe -HostPath $candidate -StartupTimeoutSeconds $StartupTimeoutSeconds
        if ($probe.Status -eq 'Ready') {
            # Pin aliases to their real executable and verify that exact target.
            if ($probe.Identity.Path -ine $candidate) {
                $aliasIdentity = $probe.Identity
                $resolvedPath = $aliasIdentity.Path
                $probe = Invoke-AudioHostProbe -HostPath $resolvedPath -StartupTimeoutSeconds $StartupTimeoutSeconds
                if ($probe.Status -ne 'Ready' -or $probe.Identity.Path -ine $resolvedPath) { throw ('Resolved host verification failed. ' + $probe.Error) }
                foreach ($field in @('Version', 'Edition', 'ProcessArchitecture', 'OSArchitecture', 'ApartmentState', 'LanguageMode', 'MachinePolicy', 'UserPolicy')) {
                    if ($probe.Identity.$field -cne $aliasIdentity.$field) { throw ('Resolved host identity changed: ' + $field + '. No application was started.') }
                }
            }
            return $probe.Identity
        }
        Write-Host ('[HOST] ' + $candidate + ': ' + $probe.Status + '. ' + $probe.Error)
        if ($explicitHost -or $probe.Status -notin @('Unavailable', 'Timeout') -or -not $probe.ProcessReleased -or -not $probe.PipeDrainCompleted) {
            throw 'Host selection stopped before application entry. No alternate host was started.'
        }
    }
    throw 'No healthy supported PowerShell host was found. Select an allowed x64 PowerShell 7 or Windows PowerShell 5.1 executable.'
}

function Wait-AudioLaunchClose {
    try {
        if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) {
            Write-Host 'Press any key to close.'
            $null = [Console]::ReadKey($true)
        }
    } catch { }
}

$childExit = 1
try {
    if ($ShowUsage) {
        Write-Host 'Drag exactly one folder onto AudioFileForPhone.bat to convert audio for phone.'
        Write-Host 'Zero, empty or multiple folder arguments are not accepted.'
    }
    else {
        if (-not $PSBoundParameters.ContainsKey('InputFolder')) { $InputFolder = $env:AUDIOFILEFORPHONE_INPUT }
        if ([string]::IsNullOrWhiteSpace($InputFolder)) { throw 'Supply exactly one nonempty input folder.' }
        if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') { throw 'Managed language policy prevents this launcher. Use an allowed direct route; no fallback.' }
        foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.HostProbe.ps1')) {
            if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw ('Required runtime file is missing: ' + $name + '. Restore the complete application package.') }
        }
        . (Join-Path $PSScriptRoot 'AudioFileForPhone.Helpers.ps1')
        if (-not $PSBoundParameters.ContainsKey('HostPath')) { $HostPath = $env:AUDIOFILEFORPHONE_HOST }
        if ($PSBoundParameters.ContainsKey('HostPath') -and [string]::IsNullOrWhiteSpace($HostPath)) { throw 'HostPath cannot be empty.' }
        $identity = Select-AudioLaunchHost -HostPath $HostPath -StartupTimeoutSeconds $StartupTimeoutSeconds
        Write-Host ('[HOST] Selected: ' + $identity.Path)
        Write-Host ('[HOST] PowerShell ' + $identity.Version + ' (' + $identity.Edition + '); OS=' + $identity.OSArchitecture + '; process=' + $identity.ProcessArchitecture + '; apartment=' + $identity.ApartmentState)
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.FileName = $identity.Path
        $start.UseShellExecute = $false
        $start.WorkingDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.')
        $start.EnvironmentVariables['PSModulePath'] = (Join-Path (Split-Path -Parent $identity.Path) 'Modules') + ';' + $env:PSModulePath
        $arguments = @('-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'RemoteSigned', '-File',
            (Join-Path $PSScriptRoot 'AudioFileForPhone.ps1'), '-InputFolder', $InputFolder, '-Interactive')
        $start.Arguments = ($arguments | ForEach-Object { ConvertTo-AudioLaunchArgument $_ }) -join ' '
        $application = New-Object Diagnostics.Process
        $application.StartInfo = $start
        try {
            if (-not $application.Start()) { throw 'Application host did not start.' }
            # One start site, unlimited application runtime, no retry from here.
            $application.WaitForExit()
            $childExit = $application.ExitCode
        }
        finally { $application.Dispose() }
        switch ($childExit) {
            0 { Write-Host 'Completed. Check the output and log paths printed above.' }
            1 { Write-Host 'Failed. Review the error and any output or log paths printed above.' }
            2 { Write-Host 'Completed with failures. Review the output and log paths printed above.' }
            130 { Write-Host 'Cancelled. Completed outputs are preserved; review the paths printed above.' }
            default { Write-Host ('Failed with exit code ' + $childExit + '. Review the error printed above.') }
        }
    }
}
catch { Write-Host ('Startup failed: ' + $_.Exception.Message) }
Wait-AudioLaunchClose
exit $childExit
