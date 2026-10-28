<#
.SYNOPSIS
Checks the local AudioFileForPhone environment, with an optional synthetic test.
.DESCRIPTION
The default check runs the selected local FFmpeg/ffprobe binaries for bounded
version and capability queries. It uses production dependency resolution with a
local-only boundary, reads no audio, contacts no network, and creates no persistent
application files, settings, media or diagnostics. PowerShell/.NET may use transient
compiler files while initializing the production native helper.
Failures are console-only. Explicit SelfTest creates and cleans only a uniquely
owned temporary synthetic fixture tree and uses production encoding/full decode.
Explicit ExportPath saves the redacted text displayed for review; nothing uploads.
.PARAMETER FfmpegDirectory
Exact existing directory containing both tools. An invalid selection never falls
back. The directory is used for this command only and is never remembered.
.PARAMETER ConfigPath
Optional portable/isolated JSON config. Default is the production user config.
The check only reads configuration and never repairs or saves it.
.PARAMETER SelfTest
Explicitly permit a short synthetic MP3 fixture and conversion in a unique TEMP
tree. Ordinary Music, personal media and conversion destinations are untouched.
SELF_TEST_UNAVAILABLE means fixture capability was missing; it does not prove
ordinary conversion is broken. Unproved ownership/release retains the tiny tree.
.PARAMETER ExportPath
Explicit new text report filename in an existing directory. Does not overwrite.
Review the displayed whitelist report before sharing; redaction is not a guarantee
that all identifying content has been removed. No automatic upload or network.
.PARAMETER DiagnosticPath
Read one existing PRIVATE schema-1 startup report, at most 64 KiB, and display its
whitelist support export. This separate parameter set runs no native tools, reads
no configuration or media, and works without the converter helper. Only explicit
ExportPath writes a new report. Reparse points and unsupported records are refused.
.NOTES
Exit 0: check/self-test passed; 1: failed or self-test unavailable; 130: cancelled.
Windows PowerShell 5.1 / PowerShell 7. Respect organization execution policy.
#>
[CmdletBinding(DefaultParameterSetName = 'Environment')]
param(
    [Parameter(ParameterSetName = 'Environment')]
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$FfmpegDirectory,
    [Parameter(ParameterSetName = 'Environment')]
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$ConfigPath,
    [Parameter(ParameterSetName = 'Environment')]
    [switch]$SelfTest,
    [Parameter(Mandatory = $true, ParameterSetName = 'Support')]
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$DiagnosticPath,
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })][string]$ExportPath
)
$ErrorActionPreference = 'Stop'
$checkDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$stage = 'CheckBootstrap'; $code = 'HelperMissing'; $message = ''; $selection = $null; $context = $null; $native = $null
$exitCode = 1; $check = $null; $synthetic = $null; $record = $null; $cancellation = $null
if ($PSCmdlet.ParameterSetName -eq 'Support') { Write-Host '[CHECK] Reading one bounded PRIVATE report for whitelist review. No native tools, configuration, media or network.' }
else { Write-Host '[CHECK] Default check executes the selected trusted tools for version/capability queries. No network, audio scan or settings writes.' }
if ($SelfTest) { Write-Host '[CHECK] Explicit self-test permits only a uniquely owned TEMP fixture tree and production conversion/full decode.' }
try {
    $requiredFiles = if ($PSCmdlet.ParameterSetName -eq 'Support') { @('AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.Checks.ps1') }
        else { @('AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Checks.ps1') }
    foreach ($name in $requiredFiles) {
        $path = Join-Path $checkDirectory $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop)) { throw ('Required runtime file is missing: ' + $name + '. Restore the complete application package.') }
        . $path
    }
    if ($PSCmdlet.ParameterSetName -eq 'Support') {
        $stage = 'SupportReview'; $code = 'DiagnosticInvalid'
        $record = Import-AudioDiagnosticRecord -Path $DiagnosticPath
        $code = 'SupportReviewReady'; $message = 'Private diagnostic record was read for whitelist review.'; $exitCode = 0
    }
    else {
        $stage = 'EnvironmentCheck'; $code = 'DependencyMissing'
        $cancellation = New-AudioCancellationContext -CaptureConsole:$SelfTest
        $options = @{ ScriptDirectory = $checkDirectory; ConfigPath = $ConfigPath; Cancellation = $cancellation }
        if ($PSBoundParameters.ContainsKey('FfmpegDirectory')) { $options.FfmpegDirectory = $FfmpegDirectory }
        $check = Invoke-AudioEnvironmentCheck @options
        $selection = $check.Selection; $context = $check.Context; $native = $check.NativeResult
        $stage = $check.Stage; $code = $check.Code; $message = $check.Message
        if ($check.Status -eq 'Cancelled') { $exitCode = 130 }
        elseif ($check.Status -eq 'Success') {
            $exitCode = 0
            Write-Host ('[CHECK] libmp3lame sample rates (Hz): ' + ($check.SampleRates -join ', '))
            if ($SelfTest) {
                $stage = 'SyntheticSelfTest'
                $synthetic = Invoke-AudioSyntheticSelfTest -Selection $selection -SupportedSampleRates $check.SampleRates -Cancellation $cancellation
                if (@($synthetic.NativeResults).Count -gt 0) { $native = @($synthetic.NativeResults)[-1] }
                $code = $synthetic.Code; $exitCode = $synthetic.ExitCode
                $message = if ($synthetic.Status -eq 'Success') { 'Synthetic 64 kbps MP3 passed production planning, encode, full decode, source hash and owned cleanup.' } else { $synthetic.Error }
                Write-Host ('[SELF_TEST] ' + $code + ': ' + $message)
            }
        }
        Write-Host ('[CHECK] ' + $code + ': ' + $message)
    }
}
catch {
    $message = $_.Exception.Message
    if ($_.Exception.GetBaseException() -is [OperationCanceledException]) { $code = 'Cancelled'; $exitCode = 130 }
    Write-Host ('[CHECK] ' + $code + ': ' + $message)
}
finally {
    if ($null -ne $cancellation) {
        if (Test-AudioCancellation -Cancellation $cancellation) {
            $code = 'Cancelled'; $exitCode = 130; $message = 'Cancellation was preserved at the final check boundary.'
            if ($null -ne $synthetic) { $synthetic.Status = 'Cancelled'; $synthetic.Code = 'Cancelled'; $synthetic.ExitCode = 130 }
            Write-Host ('[CHECK] ' + $code + ': ' + $message)
        }
        $cancellation.Dispose()
    }
}
try {
    if ($PSCmdlet.ParameterSetName -eq 'Support' -and $null -eq $record) {
        Write-Host '[CHECK] No supported private record was loaded; export was not created.'
    }
    elseif (Get-Command New-AudioDiagnosticRecord -CommandType Function -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ParameterSetName -ne 'Support') {
        $totals = [pscustomobject]@{ total = $(if ($SelfTest) { 1 } else { 0 }); converted = $(if ($null -ne $synthetic -and $synthetic.Status -eq 'Success') { 1 } else { 0 })
            failed = $(if ($exitCode -eq 1) { 1 } else { 0 }); exit_code = $exitCode
            status = $(if ($exitCode -eq 0) { 'Completed' } elseif ($exitCode -eq 130) { 'Cancelled' } else { 'Failed' }) }
        $record = New-AudioDiagnosticRecord -ScriptDirectory $checkDirectory -Stage $stage -Code $code -Message $message `
            -ConfigPath $ConfigPath -Selection $selection -Context $context -NativeResult $native -Counts $totals
        $record | Add-Member -MemberType NoteProperty -Name check -Value ([pscustomobject]@{
            status = $(if ($exitCode -eq 0) { 'Success' } elseif ($exitCode -eq 130) { 'Cancelled' } else { 'Failed' })
            sample_rates_hz = $(if ($null -ne $check) { @($check.SampleRates) } else { @() })
            self_test = $(if ($null -ne $synthetic) { [pscustomobject]@{
                status = $synthetic.Status; code = $synthetic.Code; exit_code = $synthetic.ExitCode
                source_unchanged = $synthetic.SourceUnchanged; cleanup_verified = $synthetic.CleanupVerified
                process_released = $synthetic.ProcessReleased; pipe_drain_completed = $synthetic.PipeDrainCompleted
                bitrate = $synthetic.OutputBitrate; sample_rate = $synthetic.OutputSampleRate; channels = $synthetic.OutputChannels
            } } else { $null })
        }) -Force
        }
        Write-Host (ConvertTo-AudioSupportReport -Record $record)
        if ($PSBoundParameters.ContainsKey('ExportPath')) {
            $saved = Export-AudioSupportReport -Record $record -Path $ExportPath
            Write-Host ('[CHECK] Reviewable support export: ' + $saved)
        }
    }
    elseif ($PSBoundParameters.ContainsKey('ExportPath')) {
        throw 'The independent diagnostics helper is unavailable. Console cause above is preserved; restore the complete package before requesting export.'
    }
}
catch {
    Write-Host ('[CHECK] Support export/identity could not be completed: ' + $_.Exception.Message)
    if ($exitCode -eq 0) { $code = 'SupportExportFailed'; $stage = 'SupportExport' }
    if ($exitCode -ne 130) { $exitCode = 1 }
}
$summary = [ordered]@{
    code = $code; stage = $stage; exit_code = $exitCode
    self_test = $(if ($null -ne $synthetic) { [ordered]@{
        status = $synthetic.Status; source_unchanged = $synthetic.SourceUnchanged
        cleanup_verified = $synthetic.CleanupVerified; process_released = $synthetic.ProcessReleased
    } } else { $null })
}
Write-Host ('[CHECK_RESULT] ' + ($summary | ConvertTo-Json -Depth 4 -Compress))
exit $exitCode
