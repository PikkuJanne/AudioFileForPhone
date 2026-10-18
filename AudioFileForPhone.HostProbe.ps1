# Side-effect-free startup identity. Invoke only with -NoProfile -STA -File.
# Keep this bootstrap independent of the application and its helpers.
$ErrorActionPreference = 'Stop'
$languageMode = [string]$ExecutionContext.SessionState.LanguageMode
if ($languageMode -ne 'FullLanguage') {
    # Emit this before using managed APIs that constrained language may reject.
    Write-Output ('AUDIOFILEFORPHONE_POLICY_REFUSAL:' + $languageMode)
    exit 1
}

$identity = [ordered]@{
    SchemaVersion = 1
    Path = $null
    Version = [string]$PSVersionTable.PSVersion
    Edition = [string]$PSVersionTable.PSEdition
    ProcessArchitecture = $null
    OSArchitecture = $null
    ApartmentState = $null
    LanguageMode = $languageMode
    MachinePolicy = $null
    UserPolicy = $null
    Error = $null
}
function Write-AudioHostIdentity {
    param([object]$Identity)
    # The native reader uses UTF8. ASCII escapes also preserve an exact Unicode
    # executable path when Windows PowerShell inherits an OEM console encoding.
    $json = $Identity | ConvertTo-Json -Compress
    $json = [regex]::Replace($json, '[^\x00-\x7f]', {
        param($match)
        '\u{0:x4}' -f [int][char]$match.Value
    })
    Write-Output $json
}
$hostProcess = $null
try {
    $hostProcess = [Diagnostics.Process]::GetCurrentProcess()
    $identity.Path = $hostProcess.MainModule.FileName
    $identity.ProcessArchitecture = [string][Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    $identity.OSArchitecture = [string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    $identity.ApartmentState = [string][Threading.Thread]::CurrentThread.ApartmentState
    # A PS7 caller can leave its module directory in the inherited PSModulePath.
    # Read policy using this host's built-in module, never a different host's copy.
    Import-Module -Name ($PSHOME + '\Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -Scope Local -ErrorAction Stop
    $identity.MachinePolicy = [string](Get-ExecutionPolicy -Scope MachinePolicy)
    $identity.UserPolicy = [string](Get-ExecutionPolicy -Scope UserPolicy)
    Write-AudioHostIdentity -Identity $identity
    exit 0
}
catch {
    $identity.Error = $_.Exception.Message
    Write-AudioHostIdentity -Identity $identity
    exit 1
}
finally {
    if ($null -ne $hostProcess) { $hostProcess.Dispose() }
}
