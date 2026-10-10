# Functions only: safe to dot-source for focused tests. No prompts or conversion on load.

function Assert-AudioParameters {
    param([int]$BitrateKbps, [int]$MaxBaseLength)
    $rates = @(8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 192, 224, 256, 320)
    if ($rates -notcontains $BitrateKbps) {
        throw "Unsupported BitrateKbps '$BitrateKbps'. Use one of: $($rates -join ', ') kbps."
    }
    if ($MaxBaseLength -lt 24 -or $MaxBaseLength -gt 180) {
        throw "MaxBaseLength must be between 24 and 180 (received $MaxBaseLength)."
    }
}

function Get-InputDirectory {
    param([string]$InputFolder)
    if ([string]::IsNullOrWhiteSpace($InputFolder)) {
        throw 'InputFolder must be a non-empty filesystem directory.'
    }
    $provider = $null
    $drive = $null
    try {
        $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $InputFolder, [ref]$provider, [ref]$drive
        )
        if ($provider.Name -ne 'FileSystem') {
            throw 'InputFolder must be a filesystem directory.'
        }
        $path = [IO.Path]::GetFullPath($path)
        if ($path.StartsWith('\\?\') -or $path.StartsWith('\\.\')) {
            throw 'Extended/device InputFolder paths are not supported.'
        }
        $root = [IO.Path]::GetPathRoot($path)
        # Compare without losing the actual root spelling in the diagnostic.
        # This also rejects a UNC share root before touching the network.
        if ($path.TrimEnd('\', '/') -ieq $root.TrimEnd('\', '/')) {
            throw "InputFolder root directories are not supported: '$InputFolder' (root '$root'). Select a folder below the root."
        }
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if (-not $item.PSIsContainer) { throw 'InputFolder must be a directory, not a file.' }
        # Enumerate just this directory to detect access denial before prompting.
        # Recursive discovery/reparse policy is handled separately in T06.
        Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop | Out-Null
        return $item.FullName.TrimEnd('\', '/')
    }
    catch { throw "Invalid or unreadable InputFolder '$InputFolder': $($_.Exception.Message)" }
}

function Test-OutputWritable {
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$SkipWriteProbe)
    # Preview callers can resolve a destination without creating/probing anything.
    if ($SkipWriteProbe) { return }
    $probeDirectory = $null
    $probeFile = $null
    $reserved = $false
    $stream = $null
    try {
        [IO.Directory]::CreateDirectory($Path) | Out-Null
        if (-not ('AudioFileForPhone.PreflightDirectory' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace AudioFileForPhone {
    public static class PreflightDirectory {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, ExactSpelling = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateDirectoryW(string path, IntPtr securityAttributes);
    }
}
'@ -ErrorAction Stop
        }
        $probeDirectory = Join-Path $Path ('.AudioFileForPhone-write-' + [guid]::NewGuid().ToString('N'))
        $reserved = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($probeDirectory, [IntPtr]::Zero)
        if (-not $reserved) {
            $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw "Could not create an exclusive output write probe (Win32 $code)."
        }
        $candidateFile = $probeDirectory + '.tmp'
        $stream = New-Object IO.FileStream($candidateFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $probeFile = $candidateFile
        $stream.WriteByte(0)
        $stream.Flush()
    }
    catch { throw "OutputParent is not writable '$Path': $($_.Exception.Message)" }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
        # Delete only the reserved probe file and empty directory, never recurse.
        if ($probeFile) { [IO.File]::Delete($probeFile) }
        if ($reserved) { [IO.Directory]::Delete($probeDirectory, $false) }
    }
}

function Get-ToolPath {
    param([Parameter(Mandatory = $true)][string]$ExeName,
          [Parameter(Mandatory = $true)][string]$ScriptDirectory)
    $localPath = Join-Path $ScriptDirectory $ExeName
    if (Test-Path -LiteralPath $localPath -ErrorAction Stop) {
        if (-not (Test-Path -LiteralPath $localPath -PathType Leaf -ErrorAction Stop)) {
            throw "$ExeName next to the script must be an executable file: $localPath"
        }
        return (Get-Item -LiteralPath $localPath -ErrorAction Stop).FullName
    }
    $command = Get-Command $ExeName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw "Could not find $ExeName. Put it next to this script or add it to PATH."
    }
    return $command.Source
}

function Assert-ToolPrerequisites {
    param([string]$FfmpegPath, [string]$FfprobePath)
    # Small startup checks only. T05 owns the shared native execution wrapper.
    $ErrorActionPreference = 'Continue'
    foreach ($tool in @(@{ Name = 'ffmpeg'; Path = $FfmpegPath }, @{ Name = 'ffprobe'; Path = $FfprobePath })) {
        try {
            $global:LASTEXITCODE = $null
            $version = @(& $tool.Path '-version' 2>&1)
            $code = $global:LASTEXITCODE
            if ($null -eq $code -or $code -ne 0 -or $version.Count -eq 0 -or [string]$version[0] -notmatch ('^' + $tool.Name + ' version ')) {
                throw 'Expected a successful tool version response.'
            }
            Write-Host ("[INFO] {0}: {1}" -f $tool.Path, $version[0])
        }
        catch { throw "Invalid $($tool.Name) executable '$($tool.Path)': $($_.Exception.Message)" }
    }
    $global:LASTEXITCODE = $null
    $encoders = @(& $FfmpegPath '-hide_banner' '-encoders' 2>&1)
    $code = $global:LASTEXITCODE
    if ($null -eq $code -or $code -ne 0 -or ($encoders -join "`n") -notmatch '(?m)^\s*A\S*\s+libmp3lame\s') {
        throw "ffmpeg does not provide the required libmp3lame encoder: $FfmpegPath"
    }
}

function Get-ValidatedCoverPath {
    param([string]$Path, [string]$FfmpegPath)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'CoverPath must be a readable JPEG or PNG file.' }
    try {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        if ($resolved.Provider.Name -ne 'FileSystem') { throw 'CoverPath must be a filesystem file.' }
        $item = Get-Item -LiteralPath $resolved.ProviderPath -Force -ErrorAction Stop
        if ($item.PSIsContainer -or @('.jpg', '.jpeg', '.png') -notcontains $item.Extension.ToLowerInvariant()) {
            throw 'CoverPath must be a JPEG or PNG file (.jpg, .jpeg, .png).'
        }
        # Verify actual image format/readability; FromFile alone can accept GIF
        # renamed to .jpg. Dispose handles before FFmpeg checks decodeability.
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop | Out-Null
        $image = [Drawing.Image]::FromFile($item.FullName)
        try {
            if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Jpeg.Guid -and
                $image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid) {
                throw 'CoverPath content must be JPEG or PNG.'
            }
        }
        finally { $image.Dispose() }
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        $diagnostic = @(& $FfmpegPath '-nostdin' '-hide_banner' '-v' 'error' '-xerror' '-i' $item.FullName '-map' '0:v:0' '-frames:v' '1' '-c:v' 'mjpeg' '-f' 'null' '-' 2>&1)
        $code = $global:LASTEXITCODE
        if ($null -eq $code -or $code -ne 0) { throw "FFmpeg could not decode the cover (exit $code): $($diagnostic -join ' ')" }
        return $item.FullName
    }
    catch { throw "Invalid CoverPath '$Path': $($_.Exception.Message)" }
}

function Get-AudioFiles {
    param([string]$InputFolder)
    Get-ChildItem -LiteralPath $InputFolder -Recurse -File -ErrorAction Stop |
        Where-Object { @('.mp3', '.m4a', '.ogg') -contains $_.Extension.ToLowerInvariant() }
}

function Get-SanitizedAudioBaseName {
    param([string]$OriginalBase, [datetime]$LastWriteTime, [int]$MaxBaseLength)
    # Preserve existing naming here. Calendar/Unicode allocation changes are T07.
    if ($OriginalBase -match '^(?<date>\d{4}-\d{2}-\d{2})\s*-?\s*(?<rest>.*)$') {
        $datePart = $matches['date']
        $titlePart = $matches['rest']
    }
    else {
        $datePart = $LastWriteTime.ToString('yyyy-MM-dd')
        $titlePart = $OriginalBase
    }
    $safeTitle = $titlePart -replace '[^\p{L}\p{Nd}\s\-_]', ''
    $safeTitle = ($safeTitle -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($safeTitle)) { $safeTitle = 'Episode' }
    $base = "$datePart - $safeTitle"
    if ($base.Length -gt $MaxBaseLength) { $base = $base.Substring(0, $MaxBaseLength).Trim() }
    return $base
}

function Get-CoverDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $diag = [ordered]@{
        Path      = $Path
        SizeBytes = $null
        SizeMB    = $null
        Width     = $null
        Height    = $null
        Warnings  = @()
    }

    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        $diag.SizeBytes = [int64]$fi.Length
        $diag.SizeMB    = [Math]::Round(($fi.Length / 1MB), 2)

        # Size heuristic: warn if > 2MB (can bloat every MP3)
        if ($diag.SizeMB -gt 2.0) {
            $diag.Warnings += ("Cover is {0} MB. Consider a smaller JPG to avoid bloating every output MP3." -f $diag.SizeMB)
        }

        # Dimension heuristic: best-effort only (System.Drawing)
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop | Out-Null
            $img = [System.Drawing.Image]::FromFile($Path)
            try {
                $diag.Width  = $img.Width
                $diag.Height = $img.Height

                if (($diag.Width -gt 1200) -or ($diag.Height -gt 1200)) {
                    $diag.Warnings += ("Cover dimensions are {0}x{1}. Consider ~800x800 to keep file sizes sane." -f $diag.Width, $diag.Height)
                }
            }
            finally {
                $img.Dispose()
            }
        }
        catch {
            # Ignore, dimensions are optional
        }
    }
    catch {
        $diag.Warnings += ("Could not read cover file info: {0}" -f $_)
    }

    return [pscustomobject]$diag
}

function Get-OutputParent {
    param(
        [string]$OutputParent,
        [scriptblock]$MusicResolver = {
            [Environment]::GetFolderPath(
                [Environment+SpecialFolder]::MyMusic,
                [Environment+SpecialFolderOption]::DoNotVerify
            )
        }
    )

    $candidate = $OutputParent
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = & $MusicResolver
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            throw "Could not resolve the current user's Music folder."
        }
    }

    # Resolve literally through PowerShell so relative paths and FileSystem
    # drives work even when the destination has not been created yet.
    $provider = $null
    $drive = $null
    $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $candidate, [ref]$provider, [ref]$drive
    )
    if ($provider.Name -ne 'FileSystem') {
        throw 'OutputParent must be a filesystem directory.'
    }
    $path = [IO.Path]::GetFullPath($path)
    if ($path.StartsWith('\\?\') -or $path.StartsWith('\\.\')) {
        throw 'Extended/device OutputParent paths are not supported.'
    }
    if (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop) {
        throw "OutputParent is an existing file: $path"
    }
    return $path
}
