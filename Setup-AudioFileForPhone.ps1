<#
.SYNOPSIS
Selects an existing FFmpeg/ffprobe pair or installs a reviewed pinned vendor build.

.DESCRIPTION
With no directory, shows bounded interactive choices for an existing installation,
manual/offline guidance, optional consent-based managed download or cancellation.
Accepts the exact folder containing both ffmpeg.exe and ffprobe.exe. Validates
startup/libmp3lame and displays paths, versions, architecture and SHA256 hashes.
Interactive setup asks whether to remember the pair. Downloads occur only after
affirmative consent in this separate helper. No PATH, registry, profile or
persistent execution-policy changes.

.PARAMETER FfmpegDirectory
Exact existing directory containing both executables. This explicit selection is
validated without prompts. It is not saved unless Remember is also supplied.

.PARAMETER Remember
Deliberately save the explicit directory in the schema-1 user JSON config. Without
FfmpegDirectory or Download, interactive setup asks separately.

.PARAMETER Download
Request the exact reviewed Windows x64 ZIP in tools/ffmpeg-download.json. Requires
Consent; cannot be combined with FfmpegDirectory. No automatic updates.

.PARAMETER Consent
Affirmative consent for explicit Download. Review provider, bytes, destination,
license and source details in the manifest before unattended use.

.PARAMETER ManagedRoot
Optional private dependency storage for portable/isolated use. Default: managed
beside the selected ConfigPath. Each install uses a new owned versioned directory.

.PARAMETER ConfigPath
Optional config file for portable or isolated use. Relative paths use the current
PowerShell location. Default: Windows LocalApplicationData\AudioFileForPhone\config.json.
Corrupt/unknown-schema settings are preserved; choose another ConfigPath to save.

.PARAMETER NonInteractive
Never ask for input. Requires FfmpegDirectory or Download plus Consent.
Remember remains a separate explicit choice to persist the selection.

.EXAMPLE
.\Setup-AudioFileForPhone.ps1

Select an existing bin folder and decide whether to remember it.

.EXAMPLE
.\Setup-AudioFileForPhone.ps1 -FfmpegDirectory 'C:\my tools\ffmpeg\bin' -Remember

Validate and deliberately remember an existing pair, without prompts or downloads.

.NOTES
Exit codes: 0 selected/validated; 1 failed/not configured (including failed requested
save); 130 cancelled. A standalone current-run-only selection is shown as an exact
conversion command because this helper does not itself convert any source files.
Windows PowerShell 5.1 and PowerShell 7. Review unsigned scripts and respect managed
policy. A blocked host or execution policy is not authorization to bypass controls.
#>
[CmdletBinding()]
param(
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$FfmpegDirectory,
    [switch]$Remember,
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$ConfigPath,
    [switch]$NonInteractive,
    [switch]$Download,
    [switch]$Consent,
    [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
    [string]$ManagedRoot
)

$ErrorActionPreference = 'Stop'
$setupDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $setupDirectory 'AudioFileForPhone.Helpers.ps1'
try {
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf -ErrorAction Stop)) {
        throw "Required setup helper is missing: '$helperPath'. Restore the complete application package."
    }
    . $helperPath
    Write-Host ('AudioFileForPhone ' + (Get-AudioAppVersion) + ' dependency setup')
    $setupArguments = @{ ScriptDirectory = $setupDirectory; Remember = $Remember; NonInteractive = $NonInteractive; AllowManagedDownload = $true; Download = $Download; Consent = $Consent }
    if ($PSBoundParameters.ContainsKey('FfmpegDirectory')) { $setupArguments.FfmpegDirectory = $FfmpegDirectory }
    if ($PSBoundParameters.ContainsKey('ConfigPath')) { $setupArguments.ConfigPath = $ConfigPath }
    if ($PSBoundParameters.ContainsKey('ManagedRoot')) { $setupArguments.ManagedRoot = $ManagedRoot }
    $setup = Invoke-AudioToolSetup @setupArguments
    if ($setup.Status -eq 'Cancelled') {
        Write-Host ('Cancelled: ' + $setup.Error)
        exit 130
    }
    if ($setup.Status -ne 'Ready') {
        Write-Host ('Setup did not configure FFmpeg: ' + $setup.Error)
        Write-Host ('Existing-tool repair: ' + (Get-AudioSetupRepairCommand -ScriptDirectory $setupDirectory -ConfigPath $ConfigPath))
        exit 1
    }
    if ($setup.Remembered) {
        Write-Host 'Setup completed. Future launches using this config will validate the remembered pair.'
        exit 0
    }
    $conversionPath = Join-Path $setupDirectory 'AudioFileForPhone.ps1'
    $conversionCommand = "& '" + $conversionPath.Replace("'", "''") + "' -InputFolder '<source folder>' -FfmpegDirectory '" + $setup.Selection.Directory.Replace("'", "''") + "'"
    if ($PSBoundParameters.ContainsKey('ConfigPath')) { $conversionCommand += " -ConfigPath '" + $ConfigPath.Replace("'", "''") + "'" }
    Write-Host 'Validated, but NOT remembered. Use this explicit selection for a conversion:'
    Write-Host $conversionCommand
    if ($setup.SaveError) { exit 1 }
    exit 0
}
catch [OperationCanceledException] {
    Write-Host ('Cancelled: ' + $_.Exception.Message)
    exit 130
}
catch {
    Write-Host ('Setup failed: ' + $_.Exception.Message)
    exit 1
}
