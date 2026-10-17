<#
.SYNOPSIS
Selects and optionally remembers an existing FFmpeg/ffprobe installation.

.DESCRIPTION
With no directory, shows bounded interactive choices for an existing installation,
manual/offline guidance, unavailable future download support or cancellation.
Accepts the exact folder containing both ffmpeg.exe and ffprobe.exe. Validates
startup/libmp3lame and displays paths, versions, architecture and SHA256 hashes.
Interactive setup asks whether to remember the pair. No downloads are implemented
in this step; no PATH, registry, profile or persistent execution-policy changes.

.PARAMETER FfmpegDirectory
Exact existing directory containing both executables. This explicit selection is
validated without prompts. It is not saved unless Remember is also supplied.

.PARAMETER Remember
Deliberately save the explicit directory in the schema-1 user JSON config. Without
FfmpegDirectory, interactive setup asks separately and this switch is rejected.

.PARAMETER ConfigPath
Optional config file for portable or isolated use. Relative paths use the current
PowerShell location. Default: Windows LocalApplicationData\AudioFileForPhone\config.json.
Corrupt/unknown-schema settings are preserved; choose another ConfigPath to save.

.PARAMETER NonInteractive
Never ask for input. Requires FfmpegDirectory; Remember remains explicit consent.

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
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
$setupDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$helperPath = Join-Path $setupDirectory 'AudioFileForPhone.Helpers.ps1'
try {
    if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf -ErrorAction Stop)) {
        throw "Required setup helper is missing: '$helperPath'. Restore the complete application package."
    }
    . $helperPath
    Write-Host ('AudioFileForPhone ' + (Get-AudioAppVersion) + ' existing-tool setup')
    $setupArguments = @{ ScriptDirectory = $setupDirectory; Remember = $Remember; NonInteractive = $NonInteractive }
    if ($PSBoundParameters.ContainsKey('FfmpegDirectory')) { $setupArguments.FfmpegDirectory = $FfmpegDirectory }
    if ($PSBoundParameters.ContainsKey('ConfigPath')) { $setupArguments.ConfigPath = $ConfigPath }
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
