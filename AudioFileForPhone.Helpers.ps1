# Functions only: safe to dot-source for focused tests. No prompts or conversion on load.

function Get-AudioAppVersion {
    # Authoritative application version; banner, manifest and package metadata consume this.
    return '1.0.0'
}

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
        Assert-AudioPathComponents -Path $item.FullName
        Assert-AudioNoReparseAncestor -Path $item.FullName
        # Enumerate just this directory to detect access denial before prompting.
        # Full discovery completes before prompting or creating the run.
        Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop | Out-Null
        return $item.FullName.TrimEnd('\', '/')
    }
    catch { throw "Invalid or unreadable InputFolder '$InputFolder': $($_.Exception.Message)" }
}

function Initialize-AudioDirectoryInterop {
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
        Initialize-AudioDirectoryInterop
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

function Get-AudioSelectionPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A non-empty filesystem path is required.' }
    # Check the original spelling before Windows canonicalization can trim it.
    Assert-AudioOutputParentSpelling -Path $Path
    $full = Get-AudioPath -Path $Path
    Assert-AudioPathComponents -Path $full
    Assert-AudioNoReparseAncestor -Path $full
    return $full
}

function Get-AudioConfigPath {
    param([string]$ConfigPath)
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData,
            [Environment+SpecialFolderOption]::DoNotVerify)
        if ([string]::IsNullOrWhiteSpace($local)) { throw 'Windows could not resolve the current user LocalApplicationData folder. Specify -ConfigPath.' }
        $ConfigPath = [IO.Path]::Combine($local, 'AudioFileForPhone', 'config.json')
    }
    $full = Get-AudioSelectionPath -Path $ConfigPath
    if (Test-Path -LiteralPath $full -ErrorAction Stop) {
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if ($item.PSIsContainer) { throw "ConfigPath must name a regular JSON file, not a directory: '$full'." }
    }
    return $full
}

function Read-AudioToolConfig {
    param([string]$ConfigPath)
    $path = Get-AudioConfigPath -ConfigPath $ConfigPath
    $reader = $null
    try {
        if (-not (Test-Path -LiteralPath $path -ErrorAction Stop)) { return $null }
        # FileShare.Read prevents modification/deletion while bounded bytes are read.
        $reader = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($reader.Length -gt 65536) { throw 'Configuration exceeds the 64 KiB limit.' }
        $bytes = New-Object byte[] ([int]$reader.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $reader.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -eq 0) { throw 'Configuration changed or ended during its read.' }
            $offset += $count
        }
        $encoding = New-Object Text.UTF8Encoding($false, $true)
        $json = $encoding.GetString($bytes).TrimStart([char]0xfeff)
        if (-not $json.TrimStart().StartsWith('{')) { throw 'Configuration must be a JSON object.' }
        Assert-AudioConfigJsonNames -Json $json
        $config = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        if ($null -eq $config -or $config -is [array] -or $config -isnot [pscustomobject]) { throw 'Configuration must be a JSON object.' }
        $names = @($config.PSObject.Properties.Name)
        if ($names -cnotcontains 'schema_version' -or
            ($config.schema_version -isnot [int] -and $config.schema_version -isnot [long]) -or
            $config.schema_version -ne 1) {
            throw 'Unsupported schema_version. The file is preserved; choose another -ConfigPath or use a compatible application.'
        }
        if ($names -cnotcontains 'ffmpeg_directory' -or $config.ffmpeg_directory -isnot [string] -or
            [string]::IsNullOrWhiteSpace($config.ffmpeg_directory) -or
            $config.ffmpeg_directory -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') {
            throw 'ffmpeg_directory must be an absolute Windows directory string.'
        }
        # Validate spelling without requiring saved tools still to exist.
        Assert-AudioOutputParentSpelling -Path $config.ffmpeg_directory
        Assert-AudioPathComponents -Path $config.ffmpeg_directory
        return $config
    }
    catch { throw "Invalid tool configuration '$path': $($_.Exception.Message) The file was not changed. Use -FfmpegDirectory for this run or choose another -ConfigPath to repair the selection." }
    finally { if ($null -ne $reader) { $reader.Dispose() } }
}

function Assert-AudioConfigJsonNames {
    param([Parameter(Mandatory = $true)][string]$Json, [switch]$PassThruDirectoryToken)
    # PowerShell 5.1 silently collapses duplicate JSON properties, while newer
    # shells reject some case collisions. Reject both consistently before parsing
    # so unrelated settings cannot be lost on a later save.
    $objects = New-Object 'Collections.Generic.Stack[object]'
    $directoryToken = $null
    for ($index = 0; $index -lt $Json.Length; $index++) {
        $character = $Json[$index]
        if ($character -eq '{') {
            $objects.Push((New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)))
        }
        elseif ($character -eq '}') { if ($objects.Count -gt 0) { $null = $objects.Pop() } }
        elseif ($character -eq '/') { throw 'JSON comments are not supported in configuration.' }
        elseif ($character -eq ',') {
            $next = $index + 1
            while ($next -lt $Json.Length -and [char]::IsWhiteSpace($Json[$next])) { $next++ }
            if ($next -lt $Json.Length -and ($Json[$next] -eq '}' -or $Json[$next] -eq ']')) {
                throw 'Trailing JSON commas are not supported in configuration.'
            }
        }
        elseif ($character -eq '"') {
            $start = $index; $index++
            while ($index -lt $Json.Length) {
                if ($Json[$index] -eq '\') { $index += 2; continue }
                if ($Json[$index] -eq '"') { break }
                $index++
            }
            if ($index -ge $Json.Length) { throw 'Configuration has an unterminated JSON string.' }
            $next = $index + 1
            while ($next -lt $Json.Length -and [char]::IsWhiteSpace($Json[$next])) { $next++ }
            if ($next -lt $Json.Length -and $Json[$next] -eq ':' -and $objects.Count -gt 0) {
                $token = $Json.Substring($start, $index - $start + 1)
                $name = ConvertFrom-Json -InputObject ('[' + $token + ']') -ErrorAction Stop
                if (-not $objects.Peek().Add([string]$name)) { throw "Duplicate or case-colliding JSON property '$name'." }
                if ($PassThruDirectoryToken -and $objects.Count -eq 1 -and $name -ceq 'ffmpeg_directory') {
                    $valueStart = $next + 1
                    while ($valueStart -lt $Json.Length -and [char]::IsWhiteSpace($Json[$valueStart])) { $valueStart++ }
                    if ($valueStart -ge $Json.Length -or $Json[$valueStart] -ne '"') { throw 'ffmpeg_directory must contain a JSON string.' }
                    $valueEnd = $valueStart + 1
                    while ($valueEnd -lt $Json.Length) {
                        if ($Json[$valueEnd] -eq '\') { $valueEnd += 2; continue }
                        if ($Json[$valueEnd] -eq '"') { break }
                        $valueEnd++
                    }
                    if ($valueEnd -ge $Json.Length) { throw 'ffmpeg_directory has an unterminated JSON string.' }
                    $directoryToken = [pscustomobject]@{ Start = $valueStart; Length = $valueEnd - $valueStart + 1 }
                }
            }
        }
    }
    if ($PassThruDirectoryToken) {
        if ($null -eq $directoryToken) { throw 'Configuration has no ffmpeg_directory property.' }
        return $directoryToken
    }
}

function Get-AudioToolPairPaths {
    param([Parameter(Mandatory = $true)][string]$Directory)
    $full = Get-AudioSelectionPath -Path $Directory
    $folder = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if (-not $folder.PSIsContainer) { throw "FFmpeg selection must be a filesystem directory: '$full'." }
    $paths = @{}
    foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
        $path = [IO.Path]::Combine($full, $name)
        $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "The selected pair must contain regular executable files: '$path'."
        }
        $paths[$name] = $item.FullName
    }
    return [pscustomobject]@{ Directory = $full; FfmpegPath = $paths['ffmpeg.exe']; FfprobePath = $paths['ffprobe.exe'] }
}

function Get-AudioPathTool {
    param([Parameter(Mandatory = $true)][ValidateSet('ffmpeg.exe', 'ffprobe.exe')][string]$ExeName)
    # Resolve only exact .exe files under absolute PATH entries. Get-Command also
    # searches the process working directory on Windows; source folders never gain
    # executable-selection authority through that implicit search (or PATH '.').
    foreach ($entry in @($env:PATH -split ';')) {
        $directory = $entry.Trim().Trim('"')
        if ($directory -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') { continue }
        try { $full = Get-AudioSelectionPath -Path $directory }
        catch { continue }
        $candidate = [IO.Path]::Combine($full, $ExeName)
        if (-not (Test-Path -LiteralPath $candidate -ErrorAction Stop)) { continue }
        $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "PATH candidate is not a regular executable file: '$candidate'."
        }
        return $item.FullName
    }
    throw "Could not find $ExeName in absolute PATH directories. Use -FfmpegDirectory <directory containing ffmpeg.exe and ffprobe.exe>."
}

function Resolve-AudioToolSelection {
    param([string]$FfmpegDirectory, [string]$ConfigPath,
          [Parameter(Mandatory = $true)][string]$ScriptDirectory,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    $configFile = Get-AudioConfigPath -ConfigPath $ConfigPath
    $origin = $null; $pair = $null
    if ($PSBoundParameters.ContainsKey('FfmpegDirectory') -and [string]::IsNullOrWhiteSpace($FfmpegDirectory)) {
        throw 'Invalid explicit FFmpeg selection: -FfmpegDirectory must be a non-empty directory.'
    }
    if (-not [string]::IsNullOrWhiteSpace($FfmpegDirectory)) {
        $origin = 'Explicit'
        try { $pair = Get-AudioToolPairPaths -Directory $FfmpegDirectory }
        catch { throw "Invalid explicit FFmpeg selection '$FfmpegDirectory': $($_.Exception.Message) No fallback was attempted." }
    }
    else {
        $config = Read-AudioToolConfig -ConfigPath $configFile
        if ($null -ne $config) {
            $origin = 'Saved'
            try { $pair = Get-AudioToolPairPaths -Directory $config.ffmpeg_directory }
            catch { throw "Saved FFmpeg selection is unavailable '$($config.ffmpeg_directory)': $($_.Exception.Message) Use -FfmpegDirectory for this run or deliberately save a repaired selection. No fallback was attempted." }
        }
        else {
            $scriptPath = Get-AudioSelectionPath -Path $ScriptDirectory
            $localFfmpeg = [IO.Path]::Combine($scriptPath, 'ffmpeg.exe')
            $localFfprobe = [IO.Path]::Combine($scriptPath, 'ffprobe.exe')
            if ((Test-Path -LiteralPath $localFfmpeg -ErrorAction Stop) -or (Test-Path -LiteralPath $localFfprobe -ErrorAction Stop)) {
                $origin = 'AppLocal'
                try { $pair = Get-AudioToolPairPaths -Directory $scriptPath }
                catch { throw "Incomplete or invalid application-local FFmpeg pair '$scriptPath': $($_.Exception.Message) A local/PATH pair will not be mixed." }
            }
            else {
                $origin = 'PATH'
                $ffmpeg = Get-AudioPathTool -ExeName 'ffmpeg.exe'
                $ffprobe = Get-AudioPathTool -ExeName 'ffprobe.exe'
                $directory = [IO.Path]::GetDirectoryName($ffmpeg)
                if (-not [StringComparer]::OrdinalIgnoreCase.Equals($directory, [IO.Path]::GetDirectoryName($ffprobe))) { $directory = $null }
                $pair = [pscustomobject]@{ Directory = $directory; FfmpegPath = $ffmpeg; FfprobePath = $ffprobe }
            }
        }
    }
    try { $tools = Assert-ToolPrerequisites -FfmpegPath $pair.FfmpegPath -FfprobePath $pair.FfprobePath -Cancellation $Cancellation }
    catch [OperationCanceledException] { throw }
    catch { throw "$origin FFmpeg selection failed validation: $($_.Exception.Message) Use -FfmpegDirectory <directory containing ffmpeg.exe and ffprobe.exe> to select a valid pair. No fallback was attempted." }
    Write-Host ("[INFO] FFmpeg selection origin: {0}" -f $origin)
    return [pscustomobject]@{ Ffmpeg = $tools.Ffmpeg; Ffprobe = $tools.Ffprobe; Origin = $origin; ConfigPath = $configFile; Directory = $pair.Directory }
}

function Save-AudioToolSelection {
    param([Parameter(Mandatory = $true)][string]$FfmpegDirectory, [string]$ConfigPath)
    # This is the only persistence API. Only deliberate setup calls it; ordinary
    # conversion, preview and default load never save a choice. Validation completes
    # before creating any config storage.
    $pair = Get-AudioToolPairPaths -Directory $FfmpegDirectory
    $tools = Assert-ToolPrerequisites -FfmpegPath $pair.FfmpegPath -FfprobePath $pair.FfprobePath
    $path = Get-AudioConfigPath -ConfigPath $ConfigPath
    $parent = [IO.Path]::GetDirectoryName($path)
    $lock = $null; $existingGuard = $null; $temporaryGuard = $null
    $temporary = $null; $temporaryIdentity = $null
    try {
        Assert-AudioNoReparseAncestor -Path $parent
        [IO.Directory]::CreateDirectory($parent) | Out-Null
        Assert-AudioNoReparseAncestor -Path $parent
        # Exclusive creation + DeleteOnClose serializes cooperating writers and
        # does not delete/reclaim an unrelated pre-existing lock file.
        $lockPath = $path + '.lock'
        $lock = New-Object IO.FileStream($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose)
        $config = $null
        $existingIdentity = $null
        if (Test-Path -LiteralPath $path -ErrorAction Stop) {
            $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) { throw 'Configuration is read-only. Choose a writable -ConfigPath.' }
            $existingGuard = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
            $existingIdentity = Get-AudioWorkingFileIdentity -Stream $existingGuard
            $config = Read-AudioToolConfig -ConfigPath $path
            if ($existingGuard.Length -gt 65536) { throw 'Configuration exceeds the 64 KiB limit.' }
            $existingBytes = New-Object byte[] ([int]$existingGuard.Length)
            $offset = 0
            while ($offset -lt $existingBytes.Length) {
                $count = $existingGuard.Read($existingBytes, $offset, $existingBytes.Length - $offset)
                if ($count -eq 0) { throw 'Configuration ended during its guarded read.' }
                $offset += $count
            }
            $existingJson = (New-Object Text.UTF8Encoding($false, $true)).GetString($existingBytes)
            $existingHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash
            if ((Get-AudioWorkingFileIdentity -Path $path) -cne $existingIdentity) { throw 'Configuration identity changed during its read; selection was not saved.' }
        }
        if ($null -ne $existingIdentity) {
            # Preserve unknown JSON values exactly, including numeric precision,
            # date-like strings, whitespace and any UTF-8 BOM. Round-tripping the
            # whole object through PowerShell would normalize these differently
            # between 5.1 and 7. Only the deliberately owned string token changes.
            $token = Assert-AudioConfigJsonNames -Json $existingJson -PassThruDirectoryToken
            $directoryJson = ConvertTo-Json -InputObject $pair.Directory -Compress -ErrorAction Stop
            $json = $existingJson.Substring(0, $token.Start) + $directoryJson + $existingJson.Substring($token.Start + $token.Length)
        }
        else { $json = (ConvertTo-Json -InputObject ([ordered]@{ schema_version = 1; ffmpeg_directory = $pair.Directory })) + "`r`n" }
        $bytes = (New-Object Text.UTF8Encoding($false, $true)).GetBytes($json)
        if ($bytes.Length -gt 65536) { throw 'Resulting configuration exceeds the 64 KiB limit.' }
        $temporary = [IO.Path]::Combine($parent, '.AudioFileForPhone-config-' + [guid]::NewGuid().ToString('N') + '.tmp')
        $temporaryGuard = New-Object IO.FileStream($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::Read -bor [IO.FileShare]::Delete))
        $temporaryIdentity = Get-AudioWorkingFileIdentity -Stream $temporaryGuard
        $temporaryGuard.Write($bytes, 0, $bytes.Length)
        $temporaryGuard.Flush($true)
        # Windows ReplaceFile requires closed writer/target guards. Keep them
        # through serialization, then recheck identities and bytes immediately
        # before the atomic publication under the cooperating-writer lock.
        $temporaryGuard.Dispose(); $temporaryGuard = $null
        if ($null -ne $existingGuard) { $existingGuard.Dispose(); $existingGuard = $null }
        Assert-AudioNoReparseAncestor -Path $path
        if ((Get-AudioWorkingFileIdentity -Path $temporary) -cne $temporaryIdentity) { throw 'Temporary configuration identity changed; preserving that path.' }
        if ($null -ne $existingIdentity) {
            if ((Get-AudioWorkingFileIdentity -Path $path) -cne $existingIdentity) { throw 'Configuration identity changed concurrently; selection was not saved.' }
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash -cne $existingHash) { throw 'Configuration content changed concurrently; selection was not saved.' }
            [IO.File]::Replace($temporary, $path, [NullString]::Value)
        }
        else { [IO.File]::Move($temporary, $path) }
        if ((Get-AudioWorkingFileIdentity -Path $path) -cne $temporaryIdentity) { throw 'Published configuration identity changed concurrently. Verify -ConfigPath before using it.' }
        $temporary = $null
    }
    catch { throw "FFmpeg selection was not remembered in '$path': $($_.Exception.Message) The validated pair can still be used for this run with -FfmpegDirectory." }
    finally {
        if ($null -ne $temporaryGuard) { $temporaryGuard.Dispose() }
        if ($null -ne $existingGuard) { $existingGuard.Dispose() }
        if ($null -ne $temporary -and [IO.File]::Exists($temporary)) {
            try { if ((Get-AudioWorkingFileIdentity -Path $temporary) -ceq $temporaryIdentity) { [IO.File]::Delete($temporary) } }
            catch { Write-Warning "Could not remove owned incomplete config '$temporary': $($_.Exception.Message)" }
        }
        if ($null -ne $lock) { $lock.Dispose() }
    }
    Write-Host ("[INFO] Remembered FFmpeg directory in {0}" -f $path)
    return [pscustomobject]@{ Ffmpeg = $tools.Ffmpeg; Ffprobe = $tools.Ffprobe; Origin = 'Saved'; ConfigPath = $path; Directory = $pair.Directory }
}

function Get-AudioSetupRepairCommand {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory, [string]$ConfigPath)
    # Single-quoted PowerShell arguments are display text, never evaluated here.
    $setupPath = [IO.Path]::Combine((Get-AudioSelectionPath -Path $ScriptDirectory), 'Setup-AudioFileForPhone.ps1')
    $command = "& '" + $setupPath.Replace("'", "''") + "' -FfmpegDirectory '<directory containing ffmpeg.exe and ffprobe.exe>' -Remember"
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $command += " -ConfigPath '" + $ConfigPath.Replace("'", "''") + "'"
    }
    return $command
}

function Test-AudioSetupInteractionAvailable {
    # Read-Host can conceal EOF/redirected-input loops. Interactive setup supports
    # an ordinary console only; explicit-directory setup needs no console.
    try {
        return ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive -and
            -not [Console]::IsInputRedirected)
    }
    catch { return $false }
}

function Read-AudioSetupResponse {
    param([Parameter(Mandatory = $true)][string]$Prompt)
    if (-not (Test-AudioSetupInteractionAvailable)) {
        throw 'Interactive setup requires console input. Use the explicit -FfmpegDirectory setup command instead.'
    }
    Write-Host ($Prompt + ': ') -NoNewline
    # Use host input rather than Console.ReadLine so PowerShell -NonInteractive
    # retains authority even with an attached console. Preserve null at EOF.
    # Each stage reads once: invalid input/cancellation never create retry loops.
    return $Host.UI.ReadLine()
}

function Select-AudioSetupDirectory {
    # Keep GUI interaction behind a small adapter. A cancelled dialog is distinct
    # from an unavailable dialog and must never trigger another surprise prompt.
    $dialog = $null
    try {
        if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne [Threading.ApartmentState]::STA) {
            throw 'The current host is not STA.'
        }
        if (-not [Environment]::UserInteractive) { throw 'A Windows desktop is unavailable.' }
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop | Out-Null
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Choose the existing bin folder containing ffmpeg.exe and ffprobe.exe.'
        $dialog.ShowNewFolderButton = $false
        $answer = $dialog.ShowDialog()
        if ($answer -ne [Windows.Forms.DialogResult]::OK) {
            return [pscustomobject]@{ Status = 'Cancelled'; Directory = $null; Error = $null }
        }
        return [pscustomobject]@{ Status = 'Selected'; Directory = $dialog.SelectedPath; Error = $null }
    }
    catch {
        return [pscustomobject]@{ Status = 'Unavailable'; Directory = $null; Error = $_.Exception.Message }
    }
    finally { if ($null -ne $dialog) { $dialog.Dispose() } }
}

function Write-AudioSetupManualInstructions {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory, [string]$ConfigPath)
    Write-Host 'Manual/offline setup: obtain a Windows FFmpeg build with libmp3lame from a source you trust.'
    Write-Host 'Extract it using your normal tools. Keep its vendor notices and choose the exact bin folder containing both ffmpeg.exe and ffprobe.exe.'
    Write-Host 'An existing offline copy is sufficient. No download, administrator access or PATH change is required.'
    Write-Host 'Run this command after replacing the directory placeholder:'
    Write-Host (Get-AudioSetupRepairCommand -ScriptDirectory $ScriptDirectory -ConfigPath $ConfigPath)
}

function Invoke-AudioToolSetup {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptDirectory,
        [string]$ConfigPath,
        [string]$Reason,
        [string]$FfmpegDirectory,
        [switch]$Remember,
        [switch]$NonInteractive,
        [switch]$AllowManagedDownload,
        [switch]$Download,
        [switch]$Consent,
        [string]$ManagedRoot
    )
    $result = [ordered]@{ Status = 'NotConfigured'; Selection = $null; Remembered = $false; SaveError = $null; Error = $null }
    $guards = New-Object 'Collections.Generic.List[IDisposable]'
    try {
        Assert-AudioNotCancelled
        $explicit = $PSBoundParameters.ContainsKey('FfmpegDirectory')
        $downloadRequested = [bool]$Download
        if ($Download -and (-not $AllowManagedDownload -or $explicit)) { throw '-Download is available only in the separate setup entry and cannot be combined with -FfmpegDirectory.' }
        if ($Consent -and -not $Download) { throw '-Consent requires explicit -Download.' }
        if ($Download -and -not $Consent) { throw 'Download refused: explicit -Download requires -Consent. No files were downloaded or installed.' }
        if ($ManagedRoot -and -not $AllowManagedDownload) { throw '-ManagedRoot is available only in the separate setup entry.' }
        if ($explicit -and [string]::IsNullOrWhiteSpace($FfmpegDirectory)) {
            throw '-FfmpegDirectory must be a non-empty directory containing ffmpeg.exe and ffprobe.exe.'
        }
        if (-not $explicit -and -not $Download) {
            if ($Remember) { throw '-Remember requires an explicit -FfmpegDirectory. Interactive setup asks whether to remember the selected pair.' }
            if ($NonInteractive -or -not (Test-AudioSetupInteractionAvailable)) {
                throw ('Setup requires an explicit existing-tool directory when console input is unavailable. Repair action: ' +
                    (Get-AudioSetupRepairCommand -ScriptDirectory $ScriptDirectory -ConfigPath $ConfigPath))
            }
            if (-not [string]::IsNullOrWhiteSpace($Reason)) { Write-Host ('FFmpeg setup is needed: ' + $Reason) }
            Write-Host 'No conversion has started. Select an existing FFmpeg pair to continue this launch.'
            Write-Host 'S = select existing folder | M = manual/offline instructions | D = optional managed setup | Q = cancel'
            $answer = Read-AudioSetupResponse -Prompt 'Setup selection'
            if ($null -eq $answer -or [string]::IsNullOrWhiteSpace($answer) -or $answer.Trim() -ieq 'Q') {
                $result.Status = 'Cancelled'; $result.Error = 'FFmpeg setup was cancelled; no selection was changed.'
                return [pscustomobject]$result
            }
            switch ($answer.Trim().ToUpperInvariant()) {
                'M' {
                    Write-AudioSetupManualInstructions -ScriptDirectory $ScriptDirectory -ConfigPath $ConfigPath
                    $result.Error = 'Manual/offline instructions displayed; FFmpeg has not been configured. Run setup again when the pair is available.'
                    return [pscustomobject]$result
                }
                'D' {
                    if (-not $AllowManagedDownload) {
                        $setupCommand = "& '" + ([IO.Path]::Combine((Get-AudioSelectionPath -Path $ScriptDirectory), 'Setup-AudioFileForPhone.ps1')).Replace("'", "''") + "'"
                        if ($ConfigPath) { $setupCommand += " -ConfigPath '" + $ConfigPath.Replace("'", "''") + "'" }
                        Write-Host 'Conversion never downloads tools. Run separate setup and choose D to review the optional download:'
                        Write-Host $setupCommand
                        $result.Error = 'Optional download requires separate setup. No files were downloaded or installed.'
                        return [pscustomobject]$result
                    }
                    $downloadRequested = $true
                }
                'S' {
                    $picked = Select-AudioSetupDirectory
                    if ($picked.Status -eq 'Cancelled') {
                        $result.Status = 'Cancelled'; $result.Error = 'FFmpeg folder selection was cancelled; no selection was changed.'
                        return [pscustomobject]$result
                    }
                    if ($picked.Status -eq 'Unavailable') {
                        Write-Warning ('Folder dialog is unavailable; use the typed path instead. ' + $picked.Error)
                        $FfmpegDirectory = Read-AudioSetupResponse -Prompt 'Type the exact bin folder containing both executables (empty = cancel)'
                        if ($null -eq $FfmpegDirectory -or [string]::IsNullOrWhiteSpace($FfmpegDirectory)) {
                            $result.Status = 'Cancelled'; $result.Error = 'FFmpeg typed-path selection was cancelled; no selection was changed.'
                            return [pscustomobject]$result
                        }
                        $FfmpegDirectory = $FfmpegDirectory.Trim()
                        if ($FfmpegDirectory.Length -ge 2 -and $FfmpegDirectory.StartsWith('"') -and $FfmpegDirectory.EndsWith('"')) {
                            $FfmpegDirectory = $FfmpegDirectory.Substring(1, $FfmpegDirectory.Length - 2)
                        }
                    }
                    elseif ($picked.Status -eq 'Selected') { $FfmpegDirectory = $picked.Directory }
                    else { throw 'Folder selection returned an unsupported result; no selection was changed.' }
                }
                default { throw 'Invalid setup selection. Run setup again and choose S, M, D or Q; no selection was changed.' }
            }
        }
        if ($downloadRequested) {
            $managedHelper = [IO.Path]::Combine((Get-AudioSelectionPath -Path $ScriptDirectory), 'AudioFileForPhone.ManagedSetup.ps1')
            if (-not (Test-Path -LiteralPath $managedHelper -PathType Leaf)) { throw 'Managed setup helper is missing. Restore the complete application package or select an existing pair.' }
            . $managedHelper
            $manifest = Get-AudioManagedDownloadManifest -ManifestPath ([IO.Path]::Combine($ScriptDirectory, 'tools', 'ffmpeg-download.json'))
            $storage = $ManagedRoot
            if ([string]::IsNullOrWhiteSpace($storage)) { $storage = [IO.Path]::Combine([IO.Path]::GetDirectoryName((Get-AudioConfigPath -ConfigPath $ConfigPath)), 'managed') }
            $storage = Get-AudioSelectionPath -Path $storage
            Write-Host ('Optional download: ' + $manifest.provider + ' / ' + $manifest.build)
            Write-Host ('Publisher URL: ' + $manifest.url)
            Write-Host ('Transfer: ' + $manifest.archive_size_bytes + ' bytes; destination: ' + $storage)
            Write-Host ('SHA256: ' + $manifest.sha256)
            Write-Host ('Vendor license/notices: ' + $manifest.license_url + '; source: ' + $manifest.source_url)
            Write-Host 'Downloads executable code directly from this publisher. The pin verifies the reviewed bytes; review the publisher and its GPL terms. All vendor files/notices are retained. No global install or automatic updates.'
            if (-not $Consent) {
                $answer = Read-AudioSetupResponse -Prompt 'Download and install this exact build? Y = consent | N/Enter/Q = cancel'
                if ($null -eq $answer -or $answer.Trim() -ine 'Y') {
                    $result.Status = 'Cancelled'; $result.Error = 'Download consent was not granted. No files were downloaded or installed.'
                    return [pscustomobject]$result
                }
            }
            Assert-AudioNotCancelled
            # Polling console capture owns keys only during work, never while a
            # menu/consent/remember ReadLine owns input. Reuse injected caller
            # cancellation where present; standalone setup creates a scoped owner.
            $priorCancellation = Get-AudioCancellationContext
            $managedCancellation = $null
            try {
                if ($null -eq $priorCancellation) {
                    $managedCancellation = New-AudioCancellationContext -CaptureConsole
                    $script:AudioCancellationContext = $managedCancellation
                }
                $installed = Invoke-AudioManagedToolInstall -Manifest $manifest -ConfigPath $ConfigPath -ManagedRoot $storage -Consent -CancellationState (Get-AudioCancellationContext)
            }
            finally {
                if ($null -ne $managedCancellation) {
                    $managedCancellation.Dispose()
                    $script:AudioCancellationContext = $priorCancellation
                }
            }
            $FfmpegDirectory = $installed.ToolSelection.Directory
        }
        Assert-AudioNotCancelled
        # The exact explicitly selected directory is accepted; no recursive search
        # or automatic installation-root/bin guessing grants execution authority.
        $pair = Get-AudioToolPairPaths -Directory $FfmpegDirectory
        foreach ($path in @($pair.FfmpegPath, $pair.FfprobePath)) {
            # Hold read guards through validation/hash/consent/save so the displayed
            # selected bytes cannot be replaced by cooperating filesystem writes.
            $guards.Add((New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)))
        }
        $selection = Resolve-AudioToolSelection -FfmpegDirectory $pair.Directory -ConfigPath $ConfigPath -ScriptDirectory $ScriptDirectory
        Write-Host ('Accepted FFmpeg directory: ' + $selection.Directory)
        foreach ($tool in @($selection.Ffmpeg, $selection.Ffprobe)) {
            Assert-AudioNotCancelled
            $hash = (Get-FileHash -LiteralPath $tool.Path -Algorithm SHA256 -ErrorAction Stop).Hash
            $tool | Add-Member -NotePropertyName SHA256 -NotePropertyValue $hash -Force
            Write-Host ('SHA256 ' + $tool.Path + ': ' + $hash)
        }
        Write-Host 'Capability checks and these hashes identify the selected files; they do not prove publisher authenticity.'
        if (-not $explicit -and -not $Download) {
            $answer = Read-AudioSetupResponse -Prompt 'Remember this directory for future launches? Y = yes | N/Enter = this launch only | Q = cancel'
            if ($null -eq $answer -or $answer.Trim() -ieq 'Q') {
                $result.Status = 'Cancelled'; $result.Error = 'FFmpeg setup was cancelled before remembering or using the selection.'
                return [pscustomobject]$result
            }
            if ($answer.Trim() -ieq 'Y') { $Remember = $true }
            elseif (-not [string]::IsNullOrWhiteSpace($answer) -and $answer.Trim() -ine 'N') {
                throw 'Invalid remember selection. Run setup again and choose Y, N/Enter or Q; no selection was changed.'
            }
        }
        Assert-AudioNotCancelled
        if ($Remember) {
            try {
                $saved = Save-AudioToolSelection -FfmpegDirectory $selection.Directory -ConfigPath $ConfigPath
                $result.Remembered = $true
                $selection.Origin = $saved.Origin
            }
            catch [OperationCanceledException] { throw }
            catch {
                $result.SaveError = $_.Exception.Message
                Write-Warning ('This directory was NOT remembered. The validated pair can continue in the current launch only. ' + $result.SaveError)
            }
        }
        if (-not $result.Remembered -and -not $result.SaveError) {
            Write-Host 'This directory was not remembered. The validated pair is available for this launch only.'
        }
        $result.Status = 'Ready'; $result.Selection = $selection
    }
    catch [OperationCanceledException] {
        $result.Status = 'Cancelled'; $result.Error = $_.Exception.Message
    }
    catch { $result.Error = $_.Exception.Message }
    finally { foreach ($guard in $guards) { $guard.Dispose() } }
    return [pscustomobject]$result
}

function New-AudioCancellationContext {
    param([switch]$CaptureConsole)
    if (-not ('AudioFileForPhone.CancellationContext' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
namespace AudioFileForPhone {
    public sealed class CancellationContext : IDisposable {
        private static readonly object consoleGate = new object();
        private static CancellationContext consoleOwner;
        private readonly object publicationGate = new object();
        private int requested;
        private int activeProcessId;
        private bool previousControlCAsInput;
        private bool disposed;
        public bool ConsoleCaptureEnabled { get; private set; }
        public string ConsoleCaptureError { get; private set; }
        public bool IsCancellationRequested { get { return Interlocked.CompareExchange(ref requested, 0, 0) != 0; } }
        public int ActiveProcessId { get { return Interlocked.CompareExchange(ref activeProcessId, 0, 0); } }
        public CancellationContext(bool captureConsole) {
            ConsoleCaptureError = "";
            if (!captureConsole) return;
            lock (consoleGate) {
                if (consoleOwner != null) {
                    ConsoleCaptureError = "Another context owns this process's console input scope.";
                    return;
                }
                bool changed = false;
                try {
                    if (Console.IsInputRedirected) {
                        ConsoleCaptureError = "Standard input is redirected; controlled console Ctrl+C is unavailable.";
                        return;
                    }
                    previousControlCAsInput = Console.TreatControlCAsInput;
                    Console.TreatControlCAsInput = true;
                    changed = true;
                    // This verifies that the host actually provides a console
                    // input buffer; a host name alone is not evidence of that.
                    bool available = Console.KeyAvailable;
                    consoleOwner = this;
                    ConsoleCaptureEnabled = true;
                } catch (Exception error) {
                    ConsoleCaptureError = "Controlled console Ctrl+C is unavailable: " + error.Message;
                    if (changed) {
                        try { Console.TreatControlCAsInput = previousControlCAsInput; }
                        catch (Exception restoreError) { ConsoleCaptureError += "; restoring console mode failed: " + restoreError.Message; }
                    }
                }
            }
        }
        public void Request() {
            // A request and final publication have one ordering point: if the
            // request wins, File.Move cannot publish; if publication wins, the
            // already completed output remains a successful outcome.
            lock (publicationGate) { Interlocked.Exchange(ref requested, 1); }
        }
        public void SetActiveProcessId(int processId) { Interlocked.Exchange(ref activeProcessId, processId); }
        public void ClearActiveProcessId(int processId) { Interlocked.CompareExchange(ref activeProcessId, 0, processId); }
        public void Poll() {
            lock (consoleGate) {
                if (!ConsoleCaptureEnabled || disposed || consoleOwner != this) return;
                try {
                    // Bound keyboard processing as well as native wait intervals.
                    // Conversion has no prompts while this input scope is active.
                    for (int count = 0; count < 32 && Console.KeyAvailable; count++) {
                        ConsoleKeyInfo key = Console.ReadKey(true);
                        if (key.KeyChar == '\u0003' ||
                            (key.Key == ConsoleKey.C && (key.Modifiers & ConsoleModifiers.Control) != 0)) Request();
                    }
                } catch (Exception error) {
                    ConsoleCaptureError = "Console cancellation polling failed: " + error.Message;
                    RestoreConsole();
                }
            }
        }
        public void ThrowIfCancellationRequested() {
            if (IsCancellationRequested) throw new OperationCanceledException("Audio conversion was cancelled by the user.");
        }
        public void Publish(string workingPath, string outputPath) {
            lock (publicationGate) {
                ThrowIfCancellationRequested();
                File.Move(workingPath, outputPath);
            }
        }
        private void RestoreConsole() {
            if (consoleOwner != this) return;
            try { Console.TreatControlCAsInput = previousControlCAsInput; }
            catch (Exception error) { ConsoleCaptureError += "; restoring console mode failed: " + error.Message; }
            finally { consoleOwner = null; ConsoleCaptureEnabled = false; }
        }
        public void Dispose() {
            lock (consoleGate) {
                if (disposed) return;
                RestoreConsole();
                disposed = true;
            }
        }
    }
}
'@ -ErrorAction Stop
    }
    return New-Object AudioFileForPhone.CancellationContext([bool]$CaptureConsole)
}

function Get-AudioCancellationContext {
    return Get-Variable -Name AudioCancellationContext -Scope Script -ValueOnly -ErrorAction SilentlyContinue
}

function Test-AudioCancellation {
    param([AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    if ($null -eq $Cancellation) { return $false }
    $Cancellation.Poll()
    return [bool]$Cancellation.IsCancellationRequested
}

function Assert-AudioNotCancelled {
    param([AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    if (Test-AudioCancellation -Cancellation $Cancellation) {
        throw (New-Object OperationCanceledException('Audio conversion was cancelled by the user.'))
    }
}

function New-AudioProgressParser {
    # Compile only for an actual progress consumer, never for a preview.
    if (-not ('AudioFileForPhone.ProgressParser' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
namespace AudioFileForPhone {
    public sealed class ProgressRecord {
        public long Sequence { get; private set; }
        public double? MediaSeconds { get; private set; }
        public string ProgressState { get; private set; }
        public ProgressRecord(long sequence, double? seconds, string state) {
            Sequence = sequence; MediaSeconds = seconds; ProgressState = state;
        }
    }
    public sealed class ProgressParser {
        private const int lineLimit = 1024;
        private const int recordLimit = 8192;
        private readonly object gate = new object();
        private readonly StringBuilder line = new StringBuilder();
        private string microseconds, legacyMicroseconds, timestamp;
        private int recordChars, maximumBufferedChars;
        private bool lineOverflow, invalidRecord;
        private long sequence, droppedRecords;
        private ProgressRecord snapshot;
        public Action<char[], int> Consumer { get { return Feed; } }
        public ProgressRecord Snapshot { get { lock (gate) { return snapshot; } } }
        public int BufferedChars { get { lock (gate) { return Buffered(); } } }
        public int MaximumBufferedChars { get { lock (gate) { return maximumBufferedChars; } } }
        public long DroppedRecords { get { lock (gate) { return droppedRecords; } } }
        private int Buffered() {
            return line.Length + (microseconds == null ? 0 : microseconds.Length) +
                (legacyMicroseconds == null ? 0 : legacyMicroseconds.Length) +
                (timestamp == null ? 0 : timestamp.Length);
        }
        private void ObserveBuffer() { maximumBufferedChars = Math.Max(maximumBufferedChars, Buffered()); }
        private void Feed(char[] chars, int count) {
            lock (gate) { for (int i = 0; i < count; i++) AddCharacter(chars[i]); }
        }
        public void Add(string chunk) {
            if (chunk == null) return;
            lock (gate) { foreach (char c in chunk) AddCharacter(c); }
        }
        private void AddCharacter(char c) {
            // Count the whole record without retaining arbitrary FFmpeg fields.
            if (recordChars <= recordLimit) recordChars++;
            if (recordChars > recordLimit) invalidRecord = true;
            if (c == '\n') { EndLine(); return; }
            if (c == '\r') return;
            if (lineOverflow) return;
            if (line.Length == lineLimit) {
                lineOverflow = true; invalidRecord = true; line.Clear(); return;
            }
            line.Append(c); ObserveBuffer();
        }
        private static double? ParseMicroseconds(string value) {
            long time;
            if (value != null && Int64.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out time))
                return (double)time / 1000000.0;
            return null;
        }
        private static double? ParseTimestamp(string value) {
            if (value == null || !Regex.IsMatch(value, @"^[0-9]{2,}:[0-5][0-9]:[0-5][0-9](\.[0-9]{1,9})?$")) return null;
            string[] parts = value.Split(':');
            long hours; double seconds;
            if (!Int64.TryParse(parts[0], NumberStyles.None, CultureInfo.InvariantCulture, out hours) ||
                !Double.TryParse(parts[2], NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out seconds)) return null;
            double time = hours * 3600.0 + Int32.Parse(parts[1], CultureInfo.InvariantCulture) * 60.0 + seconds;
            return Double.IsNaN(time) || Double.IsInfinity(time) ? (double?)null : time;
        }
        private void ResetRecord() {
            microseconds = legacyMicroseconds = timestamp = null;
            recordChars = 0; invalidRecord = false;
        }
        private void EndLine() {
            if (lineOverflow) { lineOverflow = false; line.Clear(); return; }
            string text = line.ToString(); line.Clear();
            if (text.Length == 0) return;
            int separator = text.IndexOf('=');
            if (separator <= 0) { invalidRecord = true; return; }
            string key = text.Substring(0, separator), value = text.Substring(separator + 1);
            if (key == "progress") {
                if (!invalidRecord && (value == "continue" || value == "end")) {
                    // FFmpeg's historical out_time_ms field also uses microseconds.
                    double? seconds = ParseMicroseconds(microseconds) ?? ParseMicroseconds(legacyMicroseconds) ?? ParseTimestamp(timestamp);
                    snapshot = new ProgressRecord(++sequence, seconds, value);
                } else { droppedRecords++; }
                ResetRecord();
            } else if (key == "out_time_us" || key == "out_time_ms" || key == "out_time") {
                if (value.Length > 128) { invalidRecord = true; return; }
                if (key == "out_time_us") microseconds = value;
                else if (key == "out_time_ms") legacyMicroseconds = value;
                else timestamp = value;
            }
            ObserveBuffer();
        }
        public void Complete() { lock (gate) { if (line.Length != 0 || lineOverflow) EndLine(); } }
    }
}
'@ -ErrorAction Stop
    }
    return New-Object AudioFileForPhone.ProgressParser
}

function Get-AudioProgressState {
    param([AllowNull()][object]$Record, [AllowNull()][object]$DurationSeconds, [string]$Phase = 'Encoding')
    $duration = $null; $mediaSeconds = $null; $sequence = [long]0; $progressState = $null
    try { $duration = ConvertTo-AudioPositiveSeconds -Value $DurationSeconds } catch { }
    if ($null -ne $Record) {
        $sequence = $Record.Sequence; $progressState = $Record.ProgressState
        if ($null -ne $Record.MediaSeconds) {
            $candidate = [double]$Record.MediaSeconds
            if (-not [double]::IsNaN($candidate) -and -not [double]::IsInfinity($candidate) -and $candidate -ge 0) { $mediaSeconds = $candidate }
        }
    }
    $percent = -1
    if ($null -ne $duration -and $null -ne $mediaSeconds) {
        # Encoding completion is not validated, published file completion.
        $fraction = [math]::Min(1.0, [math]::Max(0.0, $mediaSeconds / $duration))
        $percent = [int][math]::Min(99, [math]::Floor(100 * $fraction))
    }
    return [pscustomobject]@{
        Phase = $Phase; PercentComplete = $percent; MediaSeconds = $mediaSeconds
        DurationSeconds = $duration; RecordSequence = $sequence; ProgressState = $progressState
    }
}

function New-AudioProgressCallbackState {
    return [pscustomobject]@{ Enabled = $true; LastPhase = ''; LastTimestamp = [long]0; LastRecordSequence = [long]0 }
}

function Invoke-AudioProgressCallback {
    param([AllowNull()][scriptblock]$Callback, [object]$State, [object]$Progress)
    if ($null -eq $Callback -or -not $State.Enabled) { return $false }
    $now = [Diagnostics.Stopwatch]::GetTimestamp()
    if ($State.LastPhase -ceq $Progress.Phase -and
        ($now - $State.LastTimestamp) / [double][Diagnostics.Stopwatch]::Frequency -lt 0.5) { return $false }
    try {
        # The caller is the PowerShell polling thread; worker drains never run
        # scriptblocks. Discard display output so it cannot change result shape.
        & $Callback $Progress | Out-Null
        $State.LastPhase = $Progress.Phase; $State.LastTimestamp = $now
        return $true
    }
    catch {
        $State.Enabled = $false
        Write-Warning "Progress callback failed and was disabled: $($_.Exception.Message)" -ErrorAction Continue
        return $false
    }
}

function Send-AudioNativeProgress {
    param([object]$Parser, [AllowNull()][scriptblock]$Callback, [object]$State, [AllowNull()][object]$DurationSeconds)
    if ($null -eq $Parser -or $null -eq $Callback -or -not $State.Enabled) { return }
    $record = $Parser.Snapshot
    if ($null -eq $record -or $record.Sequence -le $State.LastRecordSequence) { return }
    $progress = Get-AudioProgressState -Record $record -DurationSeconds $DurationSeconds
    if (Invoke-AudioProgressCallback -Callback $Callback -State $State -Progress $progress) {
        $State.LastRecordSequence = $record.Sequence
    }
}

function Invoke-AudioNativeProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments,
        [ValidateRange(0, 2147483647)][int]$MaxStdoutChars = 1048576,
        [ValidateRange(0, 2147483647)][int]$MaxStderrChars = 65536,
        [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
        [AllowNull()][scriptblock]$ProgressCallback,
        [AllowNull()][object]$ProgressDurationSeconds,
        [AllowNull()][object]$ProgressParser,
        [AllowNull()][object]$ProgressCallbackState,
        [ValidateRange(0, 2147483647)][int]$TimeoutMilliseconds = 0,
        [ValidateNotNullOrEmpty()][string]$Operation = 'Native operation',
        [ValidateRange(1, 2147483647)][int]$PipeDrainTimeoutMilliseconds = 5000
    )

    $result = [ordered]@{
        Status = 'StartFailed'; ExecutablePath = $ExecutablePath; Arguments = [string[]]$Arguments.Clone()
        ExitCode = $null; Stdout = ''; Stderr = ''; StdoutTruncated = $false; StderrTruncated = $false
        StdoutTotalChars = [long]0; StderrTotalChars = [long]0; DurationMilliseconds = [long]0; Error = ''
        ProcessReleased = $true; ProgressError = ''; Operation = $Operation
        TimeoutMilliseconds = $TimeoutMilliseconds; ElapsedMilliseconds = [long]0; PipeDrainCompleted = $false
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $capture = $null
    try {
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($null -ne $ProgressCallback -and $null -eq $ProgressParser) { $ProgressParser = New-AudioProgressParser }
        if ($null -eq $ProgressCallbackState) { $ProgressCallbackState = New-AudioProgressCallbackState }
        # A rooted drive-relative path such as C:tool.exe is not an absolute path.
        # FileName is passed directly to Process, never to a command interpreter.
        if (-not [IO.Path]::IsPathRooted($ExecutablePath) -or
            $ExecutablePath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])' -or
            $ExecutablePath.IndexOf([char]0) -ge 0 -or
            $ExecutablePath.StartsWith('\\?\') -or $ExecutablePath.StartsWith('\\.\')) {
            $result.Status = 'InvalidExecutablePath'
            $result.Error = 'ExecutablePath must be an absolute filesystem executable path.'
            $result.DurationMilliseconds = $timer.ElapsedMilliseconds
            return [pscustomobject]$result
        }
        if ([IO.Directory]::Exists($ExecutablePath)) {
            $result.Status = 'InvalidExecutablePath'
            $result.Error = 'ExecutablePath must name an executable file, not a directory.'
            $result.DurationMilliseconds = $timer.ElapsedMilliseconds
            return [pscustomobject]$result
        }
        if (-not [IO.File]::Exists($ExecutablePath)) {
            $result.Status = 'MissingExecutable'
            $result.Error = 'The executable file does not exist or is not readable.'
            $result.DurationMilliseconds = $timer.ElapsedMilliseconds
            return [pscustomobject]$result
        }
        # Compile only on first invocation. Dot-sourcing remains functions-only.
        # This implementation uses APIs available in .NET Framework/PowerShell 5.1.
        if (-not ('AudioFileForPhone.NativeCapture' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace AudioFileForPhone {
    public sealed class NativeCapture : IDisposable {
        private sealed class DrainResult {
            public readonly object Gate = new object();
            public readonly StringBuilder Text = new StringBuilder();
            public long TotalChars;
            public string ConsumerError = "";
            public bool EndOfPipe;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool PeekNamedPipe(SafeFileHandle pipe, IntPtr buffer, uint size, IntPtr read, out uint available, IntPtr left);
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ReadFile(SafeFileHandle pipe, byte[] buffer, uint size, out uint read, IntPtr overlapped);
        private Process process;
        private Task<DrainResult> stdoutTask;
        private Task<DrainResult> stderrTask;
        private readonly DrainResult stdoutState = new DrainResult();
        private readonly DrainResult stderrState = new DrainResult();
        private volatile bool stopDrains;
        private bool completed;
        private bool started;
        public bool Released { get; private set; }
        public bool PipeDrainCompleted { get; private set; }
        public int ExitCode { get; private set; }
        public string Stdout { get; private set; }
        public string Stderr { get; private set; }
        public long StdoutTotalChars { get; private set; }
        public long StderrTotalChars { get; private set; }
        public bool StdoutTruncated { get; private set; }
        public bool StderrTruncated { get; private set; }
        public string ProgressConsumerError { get; private set; }
        public int ProcessId { get { return process.Id; } }

        // Quote every argument using the Windows CRT rules: backslashes preceding
        // a quote or the closing quote are doubled; other backslashes stay literal.
        private static string Quote(string value) {
            if (value == null) throw new ArgumentException("Native arguments cannot be null.");
            if (value.IndexOf('\0') >= 0) throw new ArgumentException("Native arguments cannot contain NUL characters.");
            StringBuilder quoted = new StringBuilder();
            quoted.Append('"');
            int slashes = 0;
            foreach (char c in value) {
                if (c == '\\') { slashes++; continue; }
                if (c == '"') {
                    quoted.Append('\\', slashes * 2 + 1);
                    quoted.Append('"');
                } else {
                    quoted.Append('\\', slashes);
                    quoted.Append(c);
                }
                slashes = 0;
            }
            quoted.Append('\\', slashes * 2);
            quoted.Append('"');
            return quoted.ToString();
        }
        private DrainResult Drain(StreamReader reader, int limit, Action<char[], int> consumer, DrainResult state) {
            // One worker owns each anonymous read handle. Peek and ReadFile use
            // that handle sequentially, and read only bytes already available.
            // No worker blocks in StreamReader.Read/Dispose waiting for a writer
            // inherited by another process. Use a decoder across UTF-8 fragments.
            SafeFileHandle pipe = ((FileStream)reader.BaseStream).SafeFileHandle;
            byte[] bytes = new byte[4096];
            char[] chars = new char[4097];
            Decoder decoder = new UTF8Encoding(false, false).GetDecoder();
            bool first = true;
            while (!stopDrains) {
                uint available;
                bool eof = false;
                if (!PeekNamedPipe(pipe, IntPtr.Zero, 0, IntPtr.Zero, out available, IntPtr.Zero)) {
                    int error = Marshal.GetLastWin32Error();
                    if (error != 109) throw new IOException("Native pipe peek failed (Win32 " + error + ").");
                    eof = true;
                }
                uint read = 0;
                if (!eof && available == 0) { Thread.Sleep(10); continue; }
                if (!eof && !ReadFile(pipe, bytes, Math.Min((uint)bytes.Length, available), out read, IntPtr.Zero)) {
                    int error = Marshal.GetLastWin32Error();
                    if (error != 109) throw new IOException("Native pipe read failed (Win32 " + error + ").");
                    eof = true;
                }
                int count = decoder.GetChars(bytes, 0, (int)read, chars, 0, eof);
                if (first && count > 0) {
                    first = false;
                    if (chars[0] == '\uFEFF') { Array.Copy(chars, 1, chars, 0, --count); }
                }
                lock (state.Gate) {
                    state.TotalChars += count;
                    int keep = Math.Min(count, limit - state.Text.Length);
                    if (keep > 0) state.Text.Append(chars, 0, keep);
                    if (eof) state.EndOfPipe = true;
                }
                if (consumer != null) {
                    try { consumer(chars, count); }
                    catch (Exception error) {
                        string consumerError = error.GetType().Name + ": " + error.Message;
                        lock (state.Gate) { state.ConsumerError = consumerError.Substring(0, Math.Min(1024, consumerError.Length)); }
                        // A failed optional observer cannot stop pipe drainage
                        // and leave the owned child blocked on its stdout pipe.
                        consumer = null;
                    }
                }
                if (eof) break;
            }
            return state;
        }
        public NativeCapture(string executablePath, string[] arguments, int stdoutLimit, int stderrLimit)
            : this(executablePath, arguments, stdoutLimit, stderrLimit, null) { }
        public NativeCapture(string executablePath, string[] arguments, int stdoutLimit, int stderrLimit, Action<char[], int> stdoutConsumer) {
            try {
                StringBuilder commandLine = new StringBuilder();
                foreach (string argument in arguments) {
                    if (commandLine.Length != 0) commandLine.Append(' ');
                    commandLine.Append(Quote(argument));
                }
                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = executablePath;
                start.Arguments = commandLine.ToString();
                start.UseShellExecute = false;
                start.CreateNoWindow = true;
                start.RedirectStandardInput = true;
                start.RedirectStandardOutput = true;
                start.RedirectStandardError = true;
                start.StandardOutputEncoding = new UTF8Encoding(false, false);
                start.StandardErrorEncoding = new UTF8Encoding(false, false);
                process = new Process();
                process.StartInfo = start;
                if (!process.Start()) throw new IOException("The native process did not start.");
                started = true;
                StreamReader stdoutReader = process.StandardOutput;
                StreamReader stderrReader = process.StandardError;
                // Reuse pool workers rather than allocate two CLR threads and
                // their native handles for every media item in a long batch.
                stdoutTask = Task.Factory.StartNew(() => Drain(stdoutReader, stdoutLimit, stdoutConsumer, stdoutState), CancellationToken.None, TaskCreationOptions.None, TaskScheduler.Default);
                stderrTask = Task.Factory.StartNew(() => Drain(stderrReader, stderrLimit, null, stderrState), CancellationToken.None, TaskCreationOptions.None, TaskScheduler.Default);
                // Observe faults even if an interrupted caller cannot join a drain.
                stdoutTask.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
                stderrTask.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
                process.StandardInput.Close();
            } catch (Exception error) {
                Dispose();
                error.Data["AudioFileForPhone.ProcessReleased"] = Released;
                throw;
            }
        }
        public bool WaitForExit(int milliseconds) { return process.WaitForExit(milliseconds); }
        public int CaptureExitCode() { ExitCode = process.ExitCode; return ExitCode; }
        private void Snapshot() {
            lock (stdoutState.Gate) {
                Stdout = stdoutState.Text.ToString(); StdoutTotalChars = stdoutState.TotalChars;
                ProgressConsumerError = stdoutState.ConsumerError;
            }
            lock (stderrState.Gate) { Stderr = stderrState.Text.ToString(); StderrTotalChars = stderrState.TotalChars; }
            StdoutTruncated = StdoutTotalChars > Stdout.Length;
            StderrTruncated = StderrTotalChars > Stderr.Length;
            PipeDrainCompleted = stdoutState.EndOfPipe && stderrState.EndOfPipe;
        }
        public bool Complete(int milliseconds) {
            if (!Task.WaitAll(new Task[] { stdoutTask, stderrTask }, milliseconds)) return false;
            Snapshot();
            completed = true;
            return true;
        }
        public void Dispose() {
            if (process == null) { Released = true; return; }
            // Only this helper's process is owned. Abnormal unwind never searches
            // process names, terminates unrelated children or changes global state.
            bool exited = !started;
            if (started) {
                if (!completed) {
                    try { if (!process.HasExited) process.Kill(); } catch { }
                }
                // Kill requests termination; wait for the owned child before
                // returning authority to remove its working file. If termination
                // fails, retain an explicit non-released result so the caller
                // preserves the incomplete working path. This bounded teardown
                // wait is separate from the unlimited normal conversion wait.
                try { exited = process.WaitForExit(5000); } catch { }
            }
            // Allow EOF after killing our child; a surviving inherited writer
            // cannot extend teardown indefinitely. Stop polling before disposing
            // readers, so stream closure never races a blocked managed read.
            try {
                if (stdoutTask != null && stderrTask != null) Task.WaitAll(new Task[] { stdoutTask, stderrTask }, 1000);
            } catch { }
            stopDrains = true;
            try {
                if (stdoutTask != null && stderrTask != null) Task.WaitAll(new Task[] { stdoutTask, stderrTask }, 1000);
                else if (stdoutTask != null) stdoutTask.Wait(1000);
                else if (stderrTask != null) stderrTask.Wait(1000);
            } catch { }
            bool joined = (stdoutTask == null || stdoutTask.IsCompleted) && (stderrTask == null || stderrTask.IsCompleted);
            Snapshot();
            bool closed = true;
            if (started) {
                try { process.StandardInput.Dispose(); } catch { closed = false; }
                try { process.StandardOutput.Dispose(); } catch { closed = false; }
                try { process.StandardError.Dispose(); } catch { closed = false; }
            }
            if (stdoutTask != null && stdoutTask.IsCompleted) stdoutTask.Dispose();
            if (stderrTask != null && stderrTask.IsCompleted) stderrTask.Dispose();
            process.Dispose();
            process = null;
            Released = exited && joined && closed && (!started || PipeDrainCompleted);
        }
    }
}
'@ -ErrorAction Stop
        }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($TimeoutMilliseconds -gt 0 -and $timer.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
            throw (New-Object TimeoutException('Operation deadline expired before native start.'))
        }
        $result.ProcessReleased = $false
        if ($null -eq $ProgressParser) {
            $capture = New-Object AudioFileForPhone.NativeCapture($ExecutablePath, $Arguments, $MaxStdoutChars, $MaxStderrChars)
        }
        else {
            $capture = New-Object AudioFileForPhone.NativeCapture($ExecutablePath, $Arguments, $MaxStdoutChars, $MaxStderrChars, $ProgressParser.Consumer)
        }
        if ($null -ne $Cancellation) { $Cancellation.SetActiveProcessId($capture.ProcessId) }
        # Zero means unlimited process runtime (encoding/full decode). Only
        # callers for short operations opt into an operation-wide deadline.
        while (-not $capture.WaitForExit(50)) {
            Assert-AudioNotCancelled -Cancellation $Cancellation
            if ($TimeoutMilliseconds -gt 0 -and $timer.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
                throw (New-Object TimeoutException('Native process exceeded its operation deadline.'))
            }
            Send-AudioNativeProgress -Parser $ProgressParser -Callback $ProgressCallback -State $ProgressCallbackState -DurationSeconds $ProgressDurationSeconds
        }
        $result.ExitCode = $capture.CaptureExitCode()
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'CaptureFailed'
        $drainTimer = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
            Assert-AudioNotCancelled -Cancellation $Cancellation
            if (($TimeoutMilliseconds -gt 0 -and $timer.ElapsedMilliseconds -ge $TimeoutMilliseconds) -or
                $drainTimer.ElapsedMilliseconds -ge $PipeDrainTimeoutMilliseconds) {
                throw (New-Object TimeoutException('Native output pipes did not finish within the operation/drain deadline.'))
            }
            if ($capture.Complete(50)) { break }
            Send-AudioNativeProgress -Parser $ProgressParser -Callback $ProgressCallback -State $ProgressCallbackState -DurationSeconds $ProgressDurationSeconds
        }
        if ($null -ne $ProgressParser) {
            $ProgressParser.Complete()
            Send-AudioNativeProgress -Parser $ProgressParser -Callback $ProgressCallback -State $ProgressCallbackState -DurationSeconds $ProgressDurationSeconds
        }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'Completed'
        $result.Stdout = $capture.Stdout
        $result.Stderr = $capture.Stderr
        $result.StdoutTruncated = $capture.StdoutTruncated
        $result.StderrTruncated = $capture.StderrTruncated
        $result.StdoutTotalChars = $capture.StdoutTotalChars
        $result.StderrTotalChars = $capture.StderrTotalChars
        $result.ProgressError = $capture.ProgressConsumerError
        if ($result.ProgressError) { Write-Warning "Progress parsing failed and was disabled: $($result.ProgressError)" -ErrorAction Continue }
    }
    catch {
        $result.Error = $_.Exception.Message
        $nativeError = $_.Exception.GetBaseException()
        if ($nativeError -is [OperationCanceledException]) { $result.Status = 'Cancelled' }
        elseif ($nativeError -is [TimeoutException]) { $result.Status = 'Timeout' }
        if ($nativeError.Data.Contains('AudioFileForPhone.ProcessReleased')) {
            $result.ProcessReleased = [bool]$nativeError.Data['AudioFileForPhone.ProcessReleased']
        }
    }
    finally {
        if ($null -ne $capture) {
            $ownedProcessId = $capture.ProcessId
            $capture.Dispose()
            $result.ProcessReleased = $capture.Released
            $result.PipeDrainCompleted = $capture.PipeDrainCompleted
            # Snapshot bounded diagnostics even on cancellation/timeout.
            $result.Stdout = $capture.Stdout; $result.Stderr = $capture.Stderr
            $result.StdoutTruncated = $capture.StdoutTruncated; $result.StderrTruncated = $capture.StderrTruncated
            $result.StdoutTotalChars = $capture.StdoutTotalChars; $result.StderrTotalChars = $capture.StderrTotalChars
            $result.ProgressError = $capture.ProgressConsumerError
            if ($capture.Released -and $null -ne $Cancellation) { $Cancellation.ClearActiveProcessId($ownedProcessId) }
        }
        $timer.Stop()
        $result.DurationMilliseconds = $timer.ElapsedMilliseconds
        $result.ElapsedMilliseconds = $timer.ElapsedMilliseconds
        if ($result.Status -eq 'Timeout') {
            $result.Error = "Timeout during $Operation using '$ExecutablePath' after $($result.ElapsedMilliseconds) ms (operation limit $TimeoutMilliseconds ms; pipe limit $PipeDrainTimeoutMilliseconds ms; process released=$($result.ProcessReleased)). $($result.Error) Retry with a responsive trusted executable; for slow media increase -ProbeTimeoutSeconds."
        }
    }
    return [pscustomobject]$result
}

function Get-AudioMediaInfo {
    param([string]$Path, [string]$FfprobePath,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
          [ValidateRange(1, 2147483)][int]$ProbeTimeoutSeconds = 60)
    $result = [ordered]@{
        Status = 'InvalidProbeData'; TitleStatus = 'Unknown'; Title = $null
        StreamIndex = $null; MetadataSource = $null; NativeResult = $null; Error = ''
        DurationSeconds = $null; DurationStatus = 'Missing'; DurationOrigin = $null
    }
    try {
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $provider = $null
        $drive = $null
        $localPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $Path, [ref]$provider, [ref]$drive
        )
        if ($provider.Name -ne 'FileSystem' -or [string]::IsNullOrWhiteSpace($Path)) {
            throw 'Media input must be a local filesystem path.'
        }
        $localPath = [IO.Path]::GetFullPath($localPath)
        $result.MetadataSource = if ([IO.Path]::GetExtension($localPath) -ieq '.ogg') { '0:s:a:0' } else { '0' }
        $native = Invoke-AudioNativeProcess -ExecutablePath $FfprobePath -Arguments @(
            '-v', 'error', '-select_streams', 'a:0', '-show_entries',
            'stream=index,codec_type,duration:stream_tags:format=duration:format_tags', '-of', 'json', '-i', $localPath
        ) -Cancellation $Cancellation -Operation 'Source media probe' -TimeoutMilliseconds ($ProbeTimeoutSeconds * 1000)
        $result.NativeResult = $native
        if ($native.Status -ne 'Completed') {
            $result.Status = $native.Status
            $result.Error = $native.Error
            return [pscustomobject]$result
        }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($native.ExitCode -ne 0) {
            $result.Status = 'ProbeFailed'
            $result.Error = "ffprobe exited with code $($native.ExitCode): $($native.Stderr)"
            return [pscustomobject]$result
        }
        if ($native.StdoutTruncated) {
            $result.Status = 'OutputTruncated'
            $result.Error = 'ffprobe JSON exceeded the retained output limit.'
            return [pscustomobject]$result
        }
        try {
            if ([string]::IsNullOrWhiteSpace($native.Stdout)) { throw 'ffprobe returned empty JSON output.' }
            $meta = ConvertFrom-Json -InputObject $native.Stdout -ErrorAction Stop
        }
        catch {
            $result.Status = 'InvalidJson'
            $result.Error = "ffprobe did not return valid JSON: $($_.Exception.Message)"
            return [pscustomobject]$result
        }
        # ConvertFrom-Json can unwrap a singleton root array into an object.
        # The ffprobe root must be an object regardless of shell enumeration.
        if (-not $native.Stdout.TrimStart().StartsWith('{')) { throw 'ffprobe JSON root must be an object.' }
        if ($null -eq $meta -or $meta -isnot [pscustomobject] -or
            $null -eq $meta.PSObject.Properties['streams'] -or $meta.streams -isnot [array]) {
            throw 'ffprobe JSON must contain a streams array.'
        }
        if ($meta.streams.Count -eq 0) {
            $result.Status = 'NoAudio'
            $result.Error = 'ffprobe found no selected audio stream.'
            return [pscustomobject]$result
        }
        if ($meta.streams.Count -ne 1) { throw 'ffprobe must return exactly the selected first audio stream.' }
        $audio = $meta.streams[0]
        if ($null -eq $audio -or $audio -isnot [pscustomobject] -or
            $audio.codec_type -cne 'audio' -or
            ($audio.index -isnot [int] -and $audio.index -isnot [long]) -or
            $audio.index -lt 0 -or $audio.index -gt [int]::MaxValue) {
            throw 'The selected stream must be audio with a nonnegative integer index.'
        }
        # Preserve the format-specific metadata map: Ogg comments belong to
        # the selected a:0 stream; MP3/M4A use container tags without merging
        # conflicting stream tags into them.
        $tags = $null
        if ($result.MetadataSource -eq '0:s:a:0') {
            $tags = $audio.tags
        }
        elseif ($null -ne $meta.PSObject.Properties['format']) {
            if ($meta.format -isnot [pscustomobject]) { throw 'ffprobe format data must be an object.' }
            $tags = $meta.format.tags
        }
        if ($null -ne $tags) {
            if ($tags -isnot [pscustomobject]) { throw 'ffprobe tags must be a JSON object.' }
            foreach ($tag in $tags.PSObject.Properties) {
                if ($tag.Value -isnot [string]) { throw 'ffprobe tag values must be strings.' }
            }
        }
        $result.StreamIndex = [int]$audio.index
        # Keep metadata inspection independent from duration policy. The caller
        # rejects a missing/invalid duration before it starts a transaction.
        $durationValue = $audio.duration
        $result.DurationOrigin = 'Stream'
        if ($null -eq $durationValue -or $durationValue -ceq 'N/A') {
            $durationValue = if ($null -ne $meta.PSObject.Properties['format']) { $meta.format.duration } else { $null }
            $result.DurationOrigin = 'Format'
        }
        if ($null -eq $durationValue -or $durationValue -ceq 'N/A') { $result.DurationOrigin = $null }
        else {
            try {
                $result.DurationSeconds = ConvertTo-AudioPositiveSeconds -Value $durationValue
                $result.DurationStatus = 'Valid'
            }
            catch { $result.DurationStatus = 'Invalid' }
        }
        # Keep baseline truthiness: an empty title falls back to the filename;
        # whitespace and all other nonempty title strings remain intact.
        if ($null -ne $tags -and -not [string]::IsNullOrEmpty($tags.title)) {
            $result.TitleStatus = 'Present'
            $result.Title = $tags.title
        }
        else { $result.TitleStatus = 'Absent' }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'Success'
    }
    catch {
        if ($_.Exception.GetBaseException() -is [OperationCanceledException]) { $result.Status = 'Cancelled' }
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Get-AudioMetadataPlan {
    param([Parameter(Mandatory = $true)][object]$Media,
          [string]$FallbackTitle, [AllowNull()][string]$Artist, [AllowNull()][string]$Album)
    # Get-AudioMediaInfo preserves the existing title truthiness: only absent
    # or empty titles fall back; nonempty whitespace titles remain unchanged.
    $hasSourceTitle = $Media.TitleStatus -eq 'Present'
    $title = if ($hasSourceTitle) { [string]$Media.Title } else { $FallbackTitle }
    $metadataArgs = @('-map_metadata', [string]$Media.MetadataSource, '-id3v2_version', '3')
    if (-not $hasSourceTitle) { $metadataArgs += @('-metadata', "title=$title") }
    $artistOverride = $null; $albumOverride = $null
    # Explicit nonblank batch overrides come last, after the source map and
    # fallback title, so the original tags cannot replace them.
    if (-not [string]::IsNullOrWhiteSpace($Artist)) {
        $artistOverride = $Artist
        $metadataArgs += @('-metadata', "artist=$Artist")
    }
    if (-not [string]::IsNullOrWhiteSpace($Album)) {
        $albumOverride = $Album
        $metadataArgs += @('-metadata', "album=$Album")
    }
    return [pscustomobject]@{
        Arguments = [string[]]$metadataArgs; MetadataSource = [string]$Media.MetadataSource
        HasSourceTitle = $hasSourceTitle; Title = $title
        ArtistOverride = $artistOverride; AlbumOverride = $albumOverride
    }
}

function ConvertTo-AudioPositiveSeconds {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [bool] -or
        ($Value -isnot [string] -and $Value -isnot [ValueType])) { throw 'Duration is missing or invalid.' }
    $seconds = [double]0
    $text = [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
    if (-not [double]::TryParse($text, [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture, [ref]$seconds) -or
        [double]::IsNaN($seconds) -or [double]::IsInfinity($seconds) -or $seconds -le 0) {
        throw 'Duration must be a finite positive number of seconds.'
    }
    return $seconds
}

function Get-AudioWorkingFileIdentity {
    param([IO.FileStream]$Stream, [string]$Path)
    if (-not ('AudioFileForPhone.WorkingFileIdentity' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace AudioFileForPhone {
    public static class WorkingFileIdentity {
        [StructLayout(LayoutKind.Sequential)]
        private struct Information {
            public uint Attributes;
            public System.Runtime.InteropServices.ComTypes.FILETIME Creation;
            public System.Runtime.InteropServices.ComTypes.FILETIME Access;
            public System.Runtime.InteropServices.ComTypes.FILETIME Write;
            public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle file, out Information info);
        public static string Get(FileStream stream) {
            Information info;
            if (!GetFileInformationByHandle(stream.SafeFileHandle, out info))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return info.Volume.ToString("X8", CultureInfo.InvariantCulture) + ":" +
                info.IndexHigh.ToString("X8", CultureInfo.InvariantCulture) +
                info.IndexLow.ToString("X8", CultureInfo.InvariantCulture);
        }
    }
}
'@ -ErrorAction Stop
    }
    if ($null -ne $Stream) { return [AudioFileForPhone.WorkingFileIdentity]::Get($Stream) }
    $reader = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { return [AudioFileForPhone.WorkingFileIdentity]::Get($reader) }
    finally { $reader.Dispose() }
}

function Get-AudioOutputValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowNull()][object]$SourceDurationSeconds,
        [int]$BitrateKbps = 64, [bool]$HasCover = $false,
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
        [ValidateRange(1, 2147483)][int]$ProbeTimeoutSeconds = 60
    )
    $result = [ordered]@{
        Status = 'InvalidOutput'; Error = ''; ProbeResult = $null; DecodeResult = $null
        DurationSeconds = $null; DecodedDurationSeconds = $null; DurationToleranceSeconds = 0.35
        ProcessReleased = $true
    }
    try {
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $sourceSeconds = ConvertTo-AudioPositiveSeconds -Value $SourceDurationSeconds
        Assert-AudioNoReparseAncestor -Path $Path
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.PSIsContainer -or $item.Length -le 0) { throw 'Working output is not a nonempty regular file.' }
        # An abrupt host unwind may prevent a native result from returning.
        # Only a returned release proof reauthorizes working-file cleanup.
        $result.ProcessReleased = $false
        $probe = Invoke-AudioNativeProcess -ExecutablePath $FfprobePath -Arguments @(
            '-v', 'error', '-show_entries',
            'stream=index,codec_type,codec_name,bit_rate,duration:stream_disposition=attached_pic:format=format_name',
            '-of', 'json', '-i', $Path
        ) -Cancellation $Cancellation -Operation 'Output media probe' -TimeoutMilliseconds ($ProbeTimeoutSeconds * 1000)
        $result.ProbeResult = $probe
        $result.ProcessReleased = $null -ne $probe.PSObject.Properties['ProcessReleased'] -and $probe.ProcessReleased
        if ($probe.Status -eq 'Cancelled') { $result.Status = 'Cancelled'; throw $probe.Error }
        if ($probe.Status -eq 'Timeout') { $result.Status = 'Timeout'; throw $probe.Error }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($probe.Status -ne 'Completed' -or $probe.ExitCode -ne 0 -or -not $result.ProcessReleased) {
            $result.Status = 'ProbeFailed'
            throw "Output probe failed ($($probe.Status), exit $($probe.ExitCode)): $($probe.Error); $($probe.Stderr)"
        }
        $result.Status = 'InvalidProbeData'
        if ($probe.StdoutTruncated -or [string]::IsNullOrWhiteSpace($probe.Stdout) -or
            -not $probe.Stdout.TrimStart().StartsWith('{')) { throw 'Output probe JSON is missing, truncated or has an invalid root.' }
        $meta = ConvertFrom-Json -InputObject $probe.Stdout -ErrorAction Stop
        if ($meta -isnot [pscustomobject] -or $meta.streams -isnot [array] -or
            $meta.format -isnot [pscustomobject] -or $meta.format.format_name -cne 'mp3') {
            throw 'Working output must be an MP3 container with an explicit streams array.'
        }
        $audio = $null; $coverCount = 0
        $indexes = New-Object 'Collections.Generic.HashSet[int]'
        foreach ($stream in $meta.streams) {
            if ($stream -isnot [pscustomobject] -or
                ($stream.index -isnot [int] -and $stream.index -isnot [long]) -or
                $stream.index -lt 0 -or $stream.index -gt [int]::MaxValue -or
                -not $indexes.Add([int]$stream.index)) { throw 'Output has an invalid or duplicated stream index.' }
            if ($stream.codec_type -ceq 'audio') {
                if ($null -ne $audio -or $stream.codec_name -cne 'mp3') { throw 'Output must contain exactly one MP3 audio stream.' }
                $audio = $stream
            }
            elseif ($stream.codec_type -ceq 'video' -and $HasCover -and
                $stream.codec_name -ceq 'mjpeg' -and $stream.disposition -is [pscustomobject] -and
                ($stream.disposition.attached_pic -is [int] -or $stream.disposition.attached_pic -is [long]) -and
                $stream.disposition.attached_pic -eq 1) { $coverCount++ }
            else { throw 'Output contains an unexpected stream; only the selected MP3 audio and explicit JPEG cover are allowed.' }
        }
        if ($null -eq $audio -or $coverCount -ne [int]$HasCover) { throw 'Output does not have the expected audio/cover stream shape.' }
        $audioRate = [long]0
        if (-not [long]::TryParse([string]$audio.bit_rate, [Globalization.NumberStyles]::None,
                [Globalization.CultureInfo]::InvariantCulture, [ref]$audioRate) -or
            $audioRate -ne ([long]$BitrateKbps * 1000)) { throw 'Output audio-stream bitrate does not match the selected bitrate.' }
        $result.DurationSeconds = ConvertTo-AudioPositiveSeconds -Value $audio.duration
        # A fixed bound avoids permitting minutes of loss in a multi-hour source.
        # 350ms covers low-sample-rate MP3 encoder padding as well as AAC/Opus
        # duration rounding; short real fixtures establish the actual margin.
        if ([math]::Abs($result.DurationSeconds - $sourceSeconds) -gt $result.DurationToleranceSeconds) {
            throw 'Output audio duration is outside the 0.35-second source tolerance.'
        }
        # Headers (including Xing) can retain a plausible duration after payload
        # truncation. Decode the selected audio without re-encoding or writing a
        # media file, then compare its actual media time. Progress is emitted only
        # at start/end for ordinary files; all native capture remains bounded.
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'DecodeFailed'
        $result.ProcessReleased = $false
        $decode = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments @(
            '-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-err_detect', 'explode',
            '-i', $Path, '-map', ('0:{0}' -f $audio.index), '-vn', '-sn', '-dn',
            '-af', 'asetpts=N/SR/TB',
            '-progress', 'pipe:1', '-stats_period', '86400', '-f', 'null', '-'
        ) -Cancellation $Cancellation
        $result.DecodeResult = $decode
        $result.ProcessReleased = $null -ne $decode.PSObject.Properties['ProcessReleased'] -and $decode.ProcessReleased
        if ($decode.Status -eq 'Cancelled') { $result.Status = 'Cancelled'; throw $decode.Error }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($decode.Status -ne 'Completed' -or $decode.ExitCode -ne 0 -or $decode.StdoutTruncated -or
            $decode.StderrTruncated -or -not [string]::IsNullOrWhiteSpace($decode.Stderr) -or -not $result.ProcessReleased) {
            throw "Output audio decode failed ($($decode.Status), exit $($decode.ExitCode)): $($decode.Error); $($decode.Stderr)"
        }
        $mediaTime = $null; $endTime = $null
        foreach ($line in ($decode.Stdout -split '\r?\n')) {
            if ($line -cmatch '^out_time_us=(\d+)$') { $mediaTime = [long]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture) }
            elseif ($line -ceq 'progress=end') { $endTime = $mediaTime }
        }
        if ($null -eq $endTime) { throw 'Output decode did not report a completed media duration.' }
        $result.DecodedDurationSeconds = ConvertTo-AudioPositiveSeconds -Value ([double]$endTime / 1000000)
        if ([math]::Abs($result.DecodedDurationSeconds - $sourceSeconds) -gt $result.DurationToleranceSeconds -or
            [math]::Abs($result.DecodedDurationSeconds - $result.DurationSeconds) -gt $result.DurationToleranceSeconds) {
            throw 'Decoded output duration is outside the 0.35-second source/header tolerance.'
        }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'Success'
    }
    catch {
        if ($_.Exception.GetBaseException() -is [OperationCanceledException]) { $result.Status = 'Cancelled' }
        $result.Error = $_.Exception.Message
    }
    return [pscustomobject]$result
}

function Publish-AudioWorkingOutput {
    param([string]$WorkingPath, [string]$OutputPath,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    # The two-argument API refuses an occupied destination on both supported
    # runtimes. Do not replace it with overwrite-enabled Move-Item/FFmpeg output.
    Assert-AudioNotCancelled -Cancellation $Cancellation
    if ($null -ne $Cancellation) { $Cancellation.Publish($WorkingPath, $OutputPath) }
    else { [IO.File]::Move($WorkingPath, $OutputPath) }
}

function Invoke-AudioOutputTransaction {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][AllowNull()][object]$SourceDurationSeconds,
        [int]$BitrateKbps = 64, [bool]$HasCover = $false,
        [Parameter(Mandatory = $true)][string]$FfmpegPath,
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$EncodeArguments,
        [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
        [AllowNull()][scriptblock]$ProgressCallback,
        [ValidateRange(1, 2147483)][int]$ProbeTimeoutSeconds = 60
    )
    $result = [ordered]@{
        Status = 'InvalidSourceDuration'; Error = ''; OutputPath = $OutputPath; WorkingPath = $null
        EncoderResult = $null; ValidationResult = $null; CleanupError = ''
    }
    $guard = $null; $ownedIdentity = $null; $canCleanup = $true
    $progressCallbackState = New-AudioProgressCallbackState
    try {
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $sourceSeconds = ConvertTo-AudioPositiveSeconds -Value $SourceDurationSeconds
        $result.Status = 'StageFailed'
        $OutputPath = Get-AudioPath -Path $OutputPath
        $OutputRoot = Get-AudioPath -Path $OutputRoot
        $SourcePath = Get-AudioPath -Path $SourcePath
        $result.OutputPath = $OutputPath
        if (-not (Test-AudioPathWithin -Path $OutputPath -Parent $OutputRoot) -or
            $OutputPath.Equals($OutputRoot, [StringComparison]::OrdinalIgnoreCase) -or
            (Test-AudioPathWithin -Path $SourcePath -Parent $OutputRoot)) {
            throw 'The planned final output must be inside the output run and the source must be outside it.'
        }
        if ([IO.Path]::GetExtension($OutputPath) -ine '.mp3') { throw 'The planned final output must have the .mp3 extension.' }
        Assert-AudioPathBudget -Path $OutputPath -Kind File
        Assert-AudioNoReparseAncestor -Path $SourcePath
        Assert-AudioNoReparseAncestor -Path $OutputPath
        if (-not [IO.Directory]::Exists($OutputRoot)) { throw 'The reserved output run root does not exist.' }
        if (Test-Path -LiteralPath $OutputPath -ErrorAction Stop) { throw 'The planned final output already exists; refusing to overwrite it.' }
        if ($EncodeArguments -contains '-y' -or $EncodeArguments -contains '-n') { throw 'Encoder overwrite policy belongs to the working-file transaction.' }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $outDir = [IO.Path]::GetDirectoryName($OutputPath)
        Assert-AudioPathBudget -Path $outDir -Kind Directory
        [IO.Directory]::CreateDirectory($outDir) | Out-Null
        Assert-AudioNoReparseAncestor -Path $outDir
        $working = [IO.Path]::Combine($outDir, '.AudioFileForPhone-' + [guid]::NewGuid().ToString('N') + '.partial')
        Assert-AudioPathBudget -Path $working -Kind File
        $guard = New-Object IO.FileStream($working, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
        $result.WorkingPath = $working
        # Keep the CreateNew handle without Delete sharing until both encoder
        # and validation processes are disposed; another writer cannot replace
        # this invocation's exact working pathname in that interval.
        $ownedIdentity = Get-AudioWorkingFileIdentity -Stream $guard
        $result.Status = 'EncodeFailed'
        $nativeArguments = $EncodeArguments
        if ($null -ne $ProgressCallback) {
            $nativeArguments += @('-progress', 'pipe:1', '-stats_period', '0.5', '-nostats')
            $encodingProgress = Get-AudioProgressState -Record $null -DurationSeconds $sourceSeconds
            Invoke-AudioProgressCallback -Callback $ProgressCallback -State $progressCallbackState -Progress $encodingProgress | Out-Null
        }
        $canCleanup = $false
        if ($null -eq $ProgressCallback) {
            $native = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments ($nativeArguments + @('-y', '-f', 'mp3', $working)) -Cancellation $Cancellation
        }
        else {
            $native = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments ($nativeArguments + @('-y', '-f', 'mp3', $working)) `
                -MaxStdoutChars 8192 -Cancellation $Cancellation -ProgressCallback $ProgressCallback `
                -ProgressDurationSeconds $sourceSeconds -ProgressCallbackState $progressCallbackState
        }
        $result.EncoderResult = $native
        $canCleanup = $null -ne $native.PSObject.Properties['ProcessReleased'] -and $native.ProcessReleased
        if ($native.Status -eq 'Cancelled') { $result.Status = 'Cancelled'; throw $native.Error }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($native.Status -ne 'Completed' -or $native.ExitCode -ne 0 -or -not $canCleanup) {
            throw "Encoder failed ($($native.Status), exit $($native.ExitCode)): $($native.Error); $($native.Stderr)"
        }
        $result.Status = 'ValidationFailed'
        Invoke-AudioProgressCallback -Callback $ProgressCallback -State $progressCallbackState `
            -Progress (Get-AudioProgressState -Record $null -DurationSeconds $sourceSeconds -Phase 'Validating') | Out-Null
        $canCleanup = $false
        $validation = Get-AudioOutputValidation -Path $working -SourceDurationSeconds $sourceSeconds -BitrateKbps $BitrateKbps `
            -HasCover $HasCover -FfprobePath $FfprobePath -FfmpegPath $FfmpegPath -Cancellation $Cancellation -ProbeTimeoutSeconds $ProbeTimeoutSeconds
        $result.ValidationResult = $validation
        $canCleanup = $validation.ProcessReleased
        if ($validation.Status -eq 'Cancelled') { $result.Status = 'Cancelled'; throw $validation.Error }
        if ($validation.Status -eq 'Timeout') { $result.Status = 'Timeout'; throw $validation.Error }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        if ($validation.Status -ne 'Success') { throw "Output validation failed ($($validation.Status)): $($validation.Error)" }
        $result.Status = 'PromotionFailed'
        Invoke-AudioProgressCallback -Callback $ProgressCallback -State $progressCallbackState `
            -Progress (Get-AudioProgressState -Record $null -DurationSeconds $sourceSeconds -Phase 'Promoting') | Out-Null
        $guard.Dispose(); $guard = $null
        Assert-AudioNoReparseAncestor -Path $working
        Assert-AudioNoReparseAncestor -Path $OutputPath
        if ((Get-AudioWorkingFileIdentity -Path $working) -cne $ownedIdentity) { throw 'Working-file ownership changed before publication; preserving that path.' }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        Publish-AudioWorkingOutput -WorkingPath $working -OutputPath $OutputPath -Cancellation $Cancellation
        $result.Status = 'Success'
    }
    catch {
        if ($_.Exception.GetBaseException() -is [OperationCanceledException]) { $result.Status = 'Cancelled' }
        $result.Error = $_.Exception.Message
    }
    finally {
        if ($null -ne $guard) { $guard.Dispose() }
        if ($null -ne $result.WorkingPath -and $result.Status -ne 'Success') {
            try {
                if (-not $canCleanup) { throw 'Owned native process exit was not established; leaving the incomplete working path.' }
                Assert-AudioNoReparseAncestor -Path $result.WorkingPath
                if (Test-Path -LiteralPath $result.WorkingPath -ErrorAction Stop) {
                    if ($null -eq $ownedIdentity -or (Get-AudioWorkingFileIdentity -Path $result.WorkingPath) -cne $ownedIdentity) {
                        throw 'Working-file ownership changed; preserving that path.'
                    }
                    [IO.File]::Delete($result.WorkingPath)
                }
            }
            catch { $result.CleanupError = $_.Exception.Message }
        }
    }
    return [pscustomobject]$result
}

function Get-AudioExecutableArchitecture {
    param([Parameter(Mandatory = $true)][string]$Path)
    $reader = $null
    try {
        # Read only the DOS/PE headers, never load the executable as an assembly.
        $reader = New-Object IO.BinaryReader([IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read))
        if ($reader.BaseStream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { return 'Unknown' }
        $reader.BaseStream.Position = 60
        $offset = $reader.ReadUInt32()
        if ($offset -gt 1048576 -or $offset + 6 -gt $reader.BaseStream.Length) { return 'Unknown' }
        $reader.BaseStream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { return 'Unknown' }
        switch ($reader.ReadUInt16()) {
            0x8664 { return 'x64' }
            0x014c { return 'x86' }
            0xaa64 { return 'ARM64' }
            0x01c4 { return 'ARM' }
            default { return 'Unknown' }
        }
    }
    catch { return 'Unknown' }
    finally { if ($null -ne $reader) { $reader.Dispose() } }
}

function Assert-ToolPrerequisites {
    param([string]$FfmpegPath, [string]$FfprobePath,
          [ValidateRange(1, 2147483647)][int]$TimeoutMilliseconds = 15000,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    $tools = [ordered]@{}
    foreach ($tool in @(@{ Name = 'ffmpeg'; Path = $FfmpegPath }, @{ Name = 'ffprobe'; Path = $FfprobePath })) {
        try {
            $arguments = if ($tool.Name -eq 'ffmpeg') { @('-nostdin', '-version') } else { @('-version') }
            $native = Invoke-AudioNativeProcess -ExecutablePath $tool.Path -Arguments $arguments -Operation ($tool.Name + ' version check') -TimeoutMilliseconds $TimeoutMilliseconds -Cancellation $Cancellation
            Assert-AudioNotCancelled -Cancellation $Cancellation
            $version = ($native.Stdout -split '\r?\n' | Select-Object -First 1)
            if ($native.Status -ne 'Completed') { throw "$($native.Status): $($native.Error)" }
            if ($native.ExitCode -ne 0 -or -not $native.ProcessReleased -or $native.StdoutTruncated -or $version -notmatch ('^' + $tool.Name + ' version \S')) {
                throw 'Expected a successful tool version response.'
            }
            $architecture = Get-AudioExecutableArchitecture -Path $tool.Path
            $tools[$tool.Name] = [pscustomobject]@{ Path = $tool.Path; Version = $version; Architecture = $architecture }
            Write-Host ("[INFO] {0}: {1} (PE architecture: {2})" -f $tool.Path, $version, $architecture)
        }
        catch [OperationCanceledException] { throw }
        catch { throw "Invalid $($tool.Name) executable '$($tool.Path)': $($_.Exception.Message)" }
    }
    $encoders = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments @('-nostdin', '-hide_banner', '-encoders') -Operation 'ffmpeg encoder capability check' -TimeoutMilliseconds $TimeoutMilliseconds -Cancellation $Cancellation
    Assert-AudioNotCancelled -Cancellation $Cancellation
    if ($encoders.Status -ne 'Completed') { throw "ffmpeg encoder capability check failed ($($encoders.Status)): $($encoders.Error)" }
    if ($encoders.Status -ne 'Completed' -or $encoders.ExitCode -ne 0 -or -not $encoders.ProcessReleased -or $encoders.StdoutTruncated -or
        ($encoders.Stdout + "`n" + $encoders.Stderr) -notmatch '(?m)^\s*A\S*\s+libmp3lame\s') {
        throw "ffmpeg does not provide the required libmp3lame encoder: $FfmpegPath"
    }
    $ffmpegBuild = [regex]::Match($tools['ffmpeg'].Version, '^ffmpeg version (\S+)').Groups[1].Value
    $ffprobeBuild = [regex]::Match($tools['ffprobe'].Version, '^ffprobe version (\S+)').Groups[1].Value
    if ($ffmpegBuild -cne $ffprobeBuild) {
        Write-Warning ("FFmpeg/ffprobe build IDs differ ('{0}' and '{1}'). Capabilities passed; both selected paths are disclosed above." -f $ffmpegBuild, $ffprobeBuild)
    }
    if ($tools['ffmpeg'].Architecture -ne 'Unknown' -and $tools['ffprobe'].Architecture -ne 'Unknown' -and
        $tools['ffmpeg'].Architecture -cne $tools['ffprobe'].Architecture) {
        Write-Warning ("FFmpeg/ffprobe PE architectures differ ('{0}' and '{1}'). Both selected executables passed startup validation." -f $tools['ffmpeg'].Architecture, $tools['ffprobe'].Architecture)
    }
    return [pscustomobject]@{ Ffmpeg = $tools['ffmpeg']; Ffprobe = $tools['ffprobe'] }
}

function Get-ValidatedCoverPath {
    param([string]$Path, [string]$FfmpegPath, [switch]$PassThru)
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
            $diagnostics = New-AudioCoverDiagnostics -Path $item.FullName -SizeBytes $item.Length `
                -Width $image.Width -Height $image.Height
        }
        finally { $image.Dispose() }
        $native = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments @(
            '-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $item.FullName,
            '-map', '0:v:0', '-frames:v', '1', '-c:v', 'mjpeg', '-f', 'null', '-'
        )
        if ($native.Status -ne 'Completed') { throw "FFmpeg could not decode the cover ($($native.Status)): $($native.Error)" }
        if ($native.ExitCode -ne 0) { throw "FFmpeg could not decode the cover (exit $($native.ExitCode)): $($native.Stderr)" }
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) {
            throw 'FFmpeg cover process release was not established; cover validation cannot be accepted.'
        }
        if ($PassThru) {
            return [pscustomobject]@{ Path = $item.FullName; Diagnostics = $diagnostics; NativeResult = $native }
        }
        return $item.FullName
    }
    catch { throw "Invalid CoverPath '$Path': $($_.Exception.Message)" }
}

function Get-AudioPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $provider = $null; $drive = $null
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $Path, [ref]$provider, [ref]$drive
    )
    if ($provider.Name -ne 'FileSystem') { throw 'An audio path must use the FileSystem provider.' }
    $full = [IO.Path]::GetFullPath($full).Replace('/', '\')
    if ($full.StartsWith('\\?\') -or $full.StartsWith('\\.\')) {
        throw 'Extended/device audio paths are not supported.'
    }
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Length -gt $root.Length) { $full = $full.TrimEnd('\') }
    return $full
}

function Test-AudioPathWithin {
    param([Parameter(Mandatory = $true)][string]$Path,
          [Parameter(Mandatory = $true)][string]$Parent)
    $child = Get-AudioPath $Path
    $ancestor = Get-AudioPath $Parent
    return $child.Equals($ancestor, [StringComparison]::OrdinalIgnoreCase) -or
        $child.StartsWith($ancestor.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-AudioNoReparseAncestor {
    param([Parameter(Mandatory = $true)][string]$Path)
    $current = Get-AudioPath $Path
    while ($current) {
        try { $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop }
        catch [Management.Automation.ItemNotFoundException] { $item = $null }
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points in selected input/output paths are not supported: '$current'."
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function Assert-AudioOutputBoundary {
    param([Parameter(Mandatory = $true)][string]$InputFolder,
          [Parameter(Mandatory = $true)][string]$OutputRoot)
    Assert-AudioNoReparseAncestor $InputFolder
    Assert-AudioNoReparseAncestor $OutputRoot
    if (Test-AudioPathWithin -Path $InputFolder -Parent $OutputRoot) {
        throw "The output run root must not equal or contain the input directory: '$OutputRoot'."
    }
}

function Get-AudioIdentityFile {
    param([string]$Path)
    try { $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
    catch [Management.Automation.ItemNotFoundException] { return $null }
    if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        return $null
    }
    return $item
}

function Read-AudioIdentityPrefix {
    param([string]$Path, [int]$Limit)
    # Bound reads even for a large legacy batch log. Access/read errors propagate.
    $reader = New-Object IO.StreamReader($Path, [Text.Encoding]::UTF8, $true)
    try {
        $buffer = New-Object char[] ($Limit + 1)
        $count = $reader.ReadBlock($buffer, 0, $buffer.Length)
        return [pscustomobject]@{
            Text = (New-Object string($buffer, 0, [Math]::Min($count, $Limit)))
            Truncated = $count -gt $Limit
        }
    }
    finally { $reader.Dispose() }
}

function Get-AudioGeneratedRootReason {
    param([Parameter(Mandatory = $true)][string]$Path)
    $root = Get-AudioPath $Path
    $marker = Get-AudioIdentityFile (Join-Path $root '.AudioFileForPhone-output.json')
    if ($null -ne $marker) {
        $prefix = Read-AudioIdentityPrefix -Path $marker.FullName -Limit 8192
        if (-not $prefix.Truncated) {
            # Invalid marker content does not confer identity; unreadability aborts.
            try { $identity = ConvertFrom-Json -InputObject $prefix.Text -ErrorAction Stop }
            catch { $identity = $null }
            if ($null -ne $identity -and ($identity.schema_version -is [int] -or $identity.schema_version -is [long]) -and
                $identity.schema_version -eq 1 -and
                $identity.kind -ceq 'AudioFileForPhone.Output' -and
                $identity.output_root -is [string] -and
                [string]::Equals($identity.output_root, $root, [StringComparison]::OrdinalIgnoreCase)) {
                return 'Marked AudioFileForPhone output root'
            }
        }
    }

    # A name alone is never identity. Legacy roots need the exact log prefix and
    # mirrored input-leaf directory as well as a valid timestamp/rate root name.
    $leaf = [IO.Path]::GetFileName($root)
    if ($leaf -notmatch '^AudioForPhone_(8|16|24|32|40|48|56|64|80|96|112|128|144|160|192|224|256|320)kbps_(\d{8}_\d{6})$') {
        return $null
    }
    $rate = $matches[1]; $stamp = $matches[2]; $date = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($stamp, 'yyyyMMdd_HHmmss', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$date)) { return $null }
    $log = Get-AudioIdentityFile (Join-Path $root 'AudioFileForPhone_log.txt')
    if ($null -eq $log) { return $null }
    $prefix = Read-AudioIdentityPrefix -Path $log.FullName -Limit 65536
    $lines = $prefix.Text -split '\r?\n'
    if ($lines.Count -lt 6 -or $lines[0] -cne '==== AudioFileForPhone Log ====' -or
        $lines[1] -notmatch '^Start time    : .+$' -or
        $lines[2] -notmatch '^Input folder  : (.+)$' -or
        $lines[3] -notmatch '^Output root   : .+$' -or
        $lines[4] -cne ('Bitrate (kbps): ' + $rate) -or
        $lines[5] -notmatch '^Max base len  : \d+$') { return $null }
    $sourcePath = $lines[2].Substring('Input folder  : '.Length)
    $recordedRoot = $lines[3].Substring('Output root   : '.Length)
    try {
        if ($recordedRoot -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])' -or
            -not [string]::Equals((Get-AudioPath $recordedRoot), $root, [StringComparison]::OrdinalIgnoreCase)) {
            return $null
        }
    }
    catch { return $null } # Malformed historical path content, no filesystem read.
    # Do not resolve or touch the historical source path. Only use its leaf.
    if ($sourcePath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])') { return $null }
    try { $sourceLeaf = [IO.Path]::GetFileName($sourcePath.TrimEnd('\', '/')) }
    catch { return $null }
    if ([string]::IsNullOrWhiteSpace($sourceLeaf) -or $sourceLeaf -eq '.' -or $sourceLeaf -eq '..' -or
        $sourceLeaf.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return $null }
    try { $base = Get-Item -LiteralPath (Join-Path $root $sourceLeaf) -Force -ErrorAction Stop }
    catch [Management.Automation.ItemNotFoundException] { return $null }
    if ($base.PSIsContainer -and ($base.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return 'Recognized legacy AudioFileForPhone output root (log and layout)'
    }
    return $null
}

function Write-AudioOutputMarker {
    param([Parameter(Mandatory = $true)][string]$OutputRoot,
          [string]$OwnerToken = ([guid]::NewGuid().ToString('N')))
    if ($OwnerToken -cnotmatch '^[0-9a-f]{32}$') { throw 'Invalid run ownership token.' }
    $markerPath = Join-Path $OutputRoot '.AudioFileForPhone-output.json'
    $json = [ordered]@{
        schema_version = 1; kind = 'AudioFileForPhone.Output'; output_root = (Get-AudioPath $OutputRoot)
        ownership_token = $OwnerToken; cleanup_scope = (Get-AudioPath $OutputRoot)
    } | ConvertTo-Json -Compress
    $stream = New-Object IO.FileStream($markerPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally { $stream.Dispose() }
}

function Get-AudioRunCandidate {
    param([Parameter(Mandatory = $true)][string]$OutputParent,
          [int]$BitrateKbps,
          [Parameter(Mandatory = $true)][string]$Timestamp,
          [ValidateRange(1, 2147483647)][int]$Counter = 1)
    Assert-AudioParameters -BitrateKbps $BitrateKbps -MaxBaseLength 120
    $date = [datetime]::MinValue
    if ($Timestamp -cnotmatch '^\d{8}_\d{6}$' -or -not [datetime]::TryParseExact(
        $Timestamp, 'yyyyMMdd_HHmmss', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref]$date)) { throw 'Invalid run timestamp.' }
    Assert-AudioPathComponents -Path $OutputParent
    $parent = Get-AudioPath $OutputParent
    $leaf = 'AudioForPhone_{0}kbps_{1}' -f $BitrateKbps, $Timestamp
    if ($Counter -gt 1) { $leaf += '_' + $Counter.ToString([Globalization.CultureInfo]::InvariantCulture) }
    return (Get-AudioPath (Join-Path $parent $leaf))
}

function Assert-AudioRunCandidateBoundary {
    param([string]$InputFolder, [string]$OutputParent, [string]$OutputRoot)
    # Check the parent, not an occupied candidate that could itself be a junction.
    Assert-AudioPathComponents -Path $OutputParent
    Assert-AudioNoReparseAncestor -Path $OutputParent
    Assert-AudioNoReparseAncestor -Path $InputFolder
    if (Test-AudioPathWithin -Path $InputFolder -Parent $OutputRoot) {
        throw "The output run root must not equal or contain the input directory: '$OutputRoot'."
    }
}

function Get-AudioAvailableRunCandidate {
    param([string]$OutputParent, [string]$InputFolder, [int]$BitrateKbps,
          [string]$Timestamp,
          [ValidateRange(1, 2147483647)][int]$StartCounter = 1,
          [ValidateRange(1, 100000)][int]$MaximumAttempts = 1000)
    for ($attempt = 0; $attempt -lt $MaximumAttempts; $attempt++) {
        $counter = [long]$StartCounter + $attempt
        if ($counter -gt [int]::MaxValue) { throw 'Run collision counter exhausted.' }
        $candidate = Get-AudioRunCandidate -OutputParent $OutputParent -BitrateKbps $BitrateKbps -Timestamp $Timestamp -Counter $counter
        Assert-AudioRunCandidateBoundary -InputFolder $InputFolder -OutputParent $OutputParent -OutputRoot $candidate
        if (-not (Test-Path -LiteralPath $candidate -ErrorAction Stop)) {
            # Read-only selection for discovery/planning; this does not claim ownership.
            return [pscustomobject]@{ OutputRoot = $candidate; Counter = [int]$counter }
        }
    }
    throw "No available run candidate after $MaximumAttempts attempts under '$OutputParent'."
}

function New-AudioRunLog {
    param([Parameter(Mandatory = $true)][string]$OutputRoot)
    $logPath = Join-Path $OutputRoot 'AudioFileForPhone_log.txt'
    $stream = New-Object IO.FileStream($logPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        # BOM lets PS5.1 and PS7 append consistent UTF-8 without truncating the file.
        $bytes = (New-Object Text.UTF8Encoding($true)).GetPreamble()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally { $stream.Dispose() }
    return $logPath
}

function Get-AudioBoundedText {
    param([AllowNull()][object]$Value, [ValidateRange(0, 65536)][int]$MaximumChars = 2048)
    $text = [string]$Value
    if ($text.Length -le $MaximumChars) { return $text }
    $suffix = ' [truncated; see local native diagnostics]'
    if ($MaximumChars -lt $suffix.Length) { return $text.Substring(0, $MaximumChars) }
    return $text.Substring(0, $MaximumChars - $suffix.Length) + $suffix
}

function Get-AudioNativeDiagnosticLines {
    param([string]$Stage, [AllowNull()][object]$NativeResult, [ValidateRange(0, 65536)][int]$MaxStderrChars = 16384)
    if ($null -eq $NativeResult) { return }
    $stderr = [string]$NativeResult.Stderr
    $retained = [math]::Min($stderr.Length, $MaxStderrChars)
    $truncated = [bool]$NativeResult.StderrTruncated -or $retained -lt $stderr.Length
    $summary = [ordered]@{
        stage = $Stage; status = $NativeResult.Status; exit_code = $NativeResult.ExitCode
        process_released = $NativeResult.ProcessReleased; elapsed_ms = $NativeResult.DurationMilliseconds
        stdout_total_chars = $NativeResult.StdoutTotalChars; stdout_truncated = $NativeResult.StdoutTruncated
        stderr_total_chars = $NativeResult.StderrTotalChars; stderr_retained_chars = $retained; stderr_truncated = $truncated
        error = (Get-AudioBoundedText -Value $NativeResult.Error)
    }
    '[NATIVE] ' + ($summary | ConvertTo-Json -Compress)
    if ($retained -gt 0) { '[NATIVE_STDERR] ' + $Stage + "`n" + $stderr.Substring(0, $retained) }
}

function New-AudioRunManifest {
    param([object]$Run, [object]$Snapshot, [string]$InputFolder, [string]$ScriptPath,
          [object]$ToolInfo, [int]$BitrateKbps, [int]$MaxBaseLength,
          [AllowNull()][string]$CoverPath, [AllowNull()][string]$Artist, [AllowNull()][string]$Album)
    $path = Join-Path $Run.OutputRoot 'AudioFileForPhone_manifest.json'
    Assert-AudioPathBudget -Path $path -Kind File
    $records = @($Run.Plans | ForEach-Object {
        $plan = $_; $inputBytes = $null; $measurementError = ''
        try {
            Assert-AudioNoReparseAncestor -Path $plan.SourcePath
            $source = Get-Item -LiteralPath $plan.SourcePath -Force -ErrorAction Stop
            if ($source.PSIsContainer) { throw 'Source is no longer a regular file.' }
            $inputBytes = [long]$source.Length
        }
        catch { $measurementError = Get-AudioBoundedText -Value $_.Exception.Message -MaximumChars 512 }
        [pscustomobject]@{
            source_relative_path = [string]$plan.SourceRelativePath; output_relative_path = [string]$plan.OutputRelativePath
            status = 'NotProcessed'; code = 'NotProcessed'; reason = 'Not started'
            input_duration_seconds = $null; output_duration_seconds = $null; decoded_duration_seconds = $null
            input_bytes = $inputBytes; output_bytes = [long]0; elapsed_seconds = [double]0
            source_title = $null; measurement_error = $measurementError
        }
    })
    $data = [pscustomobject][ordered]@{
        schema_version = 1; kind = 'AudioFileForPhone.RunManifest'; app_version = (Get-AudioAppVersion)
        build = [ordered]@{
            entry_sha256 = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            helper_sha256 = (Get-FileHash -LiteralPath (Join-Path ([IO.Path]::GetDirectoryName($ScriptPath)) 'AudioFileForPhone.Helpers.ps1') -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        }
        tools = [ordered]@{
            selection_origin = $(if ($null -ne $ToolInfo.PSObject.Properties['Origin']) { $ToolInfo.Origin } else { $null })
            ffmpeg = [ordered]@{ path = $ToolInfo.Ffmpeg.Path; version = $ToolInfo.Ffmpeg.Version }
            ffprobe = [ordered]@{ path = $ToolInfo.Ffprobe.Path; version = $ToolInfo.Ffprobe.Version }
        }
        policies = [ordered]@{
            bitrate_kbps = $BitrateKbps; max_base_length = $MaxBaseLength
            supported_extensions = @('.mp3', '.m4a', '.ogg'); recursive_relative_layout = $true
            source_duration_policy = 'finite positive selected audio duration required'
            output_duration_tolerance_seconds = 0.35; full_output_decode_required = $true
            overwrite_policy = 'publish validated output without overwriting an occupied final path'
            metadata = [ordered]@{ artist = $Artist; album = $Album; cover_path = $CoverPath; title_policy = 'preserve existing title; otherwise use planned base name' }
        }
        run = [pscustomobject]@{
            input_root = $InputFolder; output_root = $Run.OutputRoot; status = 'Running'; exit_code = $null
            elapsed_seconds = [double]0; started_utc = [datetime]::UtcNow.ToString('o'); updated_utc = [datetime]::UtcNow.ToString('o')
            diagnostic_error = ''
        }
        checkpoint = 'Initial'; revision = 0; totals = $null
        scan_exclusions = @($Snapshot.Skipped | ForEach-Object { [pscustomobject]@{ path = $_.Path; reason = $_.Reason } })
        records = $records
    }
    return [pscustomobject]@{
        Path = $path; OutputRoot = $Run.OutputRoot; Data = $data
        Guard = $null; Identity = $null; UnsupportedCount = [int]$Snapshot.UnsupportedCount
    }
}

function Set-AudioManifestRecord {
    param([object]$Record, [string]$Status, [string]$Code, [AllowNull()][string]$Reason,
          [string]$SourcePath, [string]$OutputPath, [AllowNull()][object]$Media,
          [AllowNull()][object]$Transaction, [double]$ElapsedSeconds)
    # Commit the outcome before optional measurements, which cannot reclassify
    # an already published output. Missing measurements are explicit nulls.
    $Record.status = $Status; $Record.code = $Code
    $Record.reason = Get-AudioBoundedText -Value $Reason
    $Record.elapsed_seconds = [math]::Round($ElapsedSeconds, 3)
    $Record.measurement_error = ''; $Record.input_bytes = $null
    try {
        Assert-AudioNoReparseAncestor -Path $SourcePath
        $source = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
        if ($source.PSIsContainer) { throw 'Source is no longer a regular file.' }
        $Record.input_bytes = [long]$source.Length
    }
    catch { $Record.measurement_error = Get-AudioBoundedText -Value $_.Exception.Message -MaximumChars 512 }
    if ($null -ne $Media) {
        try { $Record.input_duration_seconds = ConvertTo-AudioPositiveSeconds -Value $Media.DurationSeconds } catch { }
        if ($Media.TitleStatus -eq 'Present') { $Record.source_title = [string]$Media.Title }
    }
    $Record.output_bytes = [long]0; $Record.output_duration_seconds = $null; $Record.decoded_duration_seconds = $null
    if ($Status -eq 'Converted') {
        $Record.output_bytes = $null
        try {
            Assert-AudioNoReparseAncestor -Path $OutputPath
            $output = Get-Item -LiteralPath $OutputPath -Force -ErrorAction Stop
            if ($output.PSIsContainer) { throw 'Published output is no longer a regular file.' }
            $Record.output_bytes = [long]$output.Length
            $Record.output_duration_seconds = ConvertTo-AudioPositiveSeconds -Value $Transaction.ValidationResult.DurationSeconds
            $Record.decoded_duration_seconds = ConvertTo-AudioPositiveSeconds -Value $Transaction.ValidationResult.DecodedDurationSeconds
        }
        catch {
            $Record.measurement_error = Get-AudioBoundedText -Value $_.Exception.Message -MaximumChars 512
            throw "Published output '$OutputPath' could not be measured for the run manifest: $($_.Exception.Message)"
        }
        if ($null -eq $Record.input_bytes) { throw "Published output '$OutputPath' has an unavailable source-byte measurement: $($Record.measurement_error)" }
    }
}

function Update-AudioRunManifest {
    param([object]$Manifest, [string]$Status, [AllowNull()][object]$ExitCode, [double]$ElapsedSeconds,
          [AllowNull()][string]$DiagnosticError)
    $data = $Manifest.Data
    $data.run.status = $Status; $data.run.exit_code = $ExitCode
    $data.run.elapsed_seconds = [math]::Round($ElapsedSeconds, 3)
    $data.run.updated_utc = [datetime]::UtcNow.ToString('o')
    $data.run.diagnostic_error = Get-AudioBoundedText -Value $DiagnosticError
    $converted = 0; $failed = 0; $cancelled = 0; $pending = 0
    $inputBytes = [long]0; $outputBytes = [long]0; $inputUnknown = 0; $outputUnknown = 0
    $inputDuration = [double]0; $outputDuration = [double]0; $durationUnknown = 0
    foreach ($record in $data.records) {
        switch ($record.status) {
            'Converted' { $converted++ }
            'Failed' { $failed++ }
            'Cancelled' { $cancelled++ }
            'NotProcessed' { $pending++ }
            default { throw "Unknown manifest outcome '$($record.status)'." }
        }
        if ($null -ne $record.input_bytes) { $inputBytes += [long]$record.input_bytes } else { $inputUnknown++ }
        if ($null -ne $record.output_bytes) { $outputBytes += [long]$record.output_bytes } else { $outputUnknown++ }
        if ($null -ne $record.input_duration_seconds) { $inputDuration += [double]$record.input_duration_seconds } else { $durationUnknown++ }
        if ($null -ne $record.output_duration_seconds) { $outputDuration += [double]$record.output_duration_seconds }
        if ($Status -ne 'Running' -and $record.status -eq 'NotProcessed') { $record.reason = "Run ended with $Status before this candidate was processed." }
    }
    $data.totals = [ordered]@{
        supported = @($data.records).Count; processed = $converted + $failed; converted = $converted; failed = $failed
        cancelled = $cancelled; not_processed = $pending; not_completed = $cancelled + $pending
        scan_excluded = @($data.scan_exclusions).Count; unsupported = $Manifest.UnsupportedCount
        input_bytes = $inputBytes; output_bytes = $outputBytes
        input_bytes_unknown_count = $inputUnknown; output_bytes_unknown_count = $outputUnknown
        input_duration_seconds = $inputDuration; output_duration_seconds = $outputDuration
        input_duration_unknown_count = $durationUnknown
    }
}

function Write-AudioRunManifest {
    param([object]$Manifest, [ValidateSet('Initial', 'FileBoundary', 'Cancelled', 'Final')][string]$Checkpoint)
    $working = $null; $workingGuard = $null; $workingIdentity = $null; $published = $false
    try {
        Assert-AudioNoReparseAncestor -Path $Manifest.OutputRoot
        Assert-AudioNoReparseAncestor -Path $Manifest.Path
        if (-not (Test-AudioPathWithin -Path $Manifest.Path -Parent $Manifest.OutputRoot)) { throw 'Manifest is outside its owned run.' }
        Assert-AudioPathBudget -Path $Manifest.Path -Kind File
        $working = Join-Path $Manifest.OutputRoot ('.AudioFileForPhone-' + [guid]::NewGuid().ToString('N') + '.partial')
        Assert-AudioPathBudget -Path $working -Kind File
        $workingGuard = New-Object IO.FileStream($working, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
        $workingIdentity = Get-AudioWorkingFileIdentity -Stream $workingGuard
        $Manifest.Data.checkpoint = $Checkpoint; $Manifest.Data.revision++
        $text = $Manifest.Data | ConvertTo-Json -Depth 10 -Compress
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text + "`n")
        $workingGuard.Write($bytes, 0, $bytes.Length); $workingGuard.Flush($true)
        if ($null -ne $Manifest.Identity) {
            # A prior promotion may have succeeded before guard acquisition
            # failed. Reacquire only that recorded live identity for a truthful
            # failed/cancelled final snapshot, never trust a parsed JSON marker.
            if ($null -eq $Manifest.Guard) {
                $Manifest.Guard = New-Object IO.FileStream($Manifest.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            }
            if ((Get-AudioWorkingFileIdentity -Stream $Manifest.Guard) -cne $Manifest.Identity) { throw 'Manifest ownership guard changed.' }
            $Manifest.Guard.Dispose(); $Manifest.Guard = $null
        }
        $workingGuard.Dispose(); $workingGuard = $null
        Assert-AudioNoReparseAncestor -Path $working
        Assert-AudioNoReparseAncestor -Path $Manifest.Path
        if ((Get-AudioWorkingFileIdentity -Path $working) -cne $workingIdentity) { throw 'Manifest working-file identity changed; preserving that path.' }
        if ($null -eq $Manifest.Identity) { [IO.File]::Move($working, $Manifest.Path) }
        else {
            if ((Get-AudioWorkingFileIdentity -Path $Manifest.Path) -cne $Manifest.Identity) { throw 'Published manifest identity changed; refusing to replace it.' }
            # Replace only the manifest created by this live invocation, never an
            # arbitrary occupied path. The complete sibling snapshot is atomic.
            [IO.File]::Replace($working, $Manifest.Path, [NullString]::Value)
        }
        $published = $true
        $Manifest.Identity = $workingIdentity
        $Manifest.Guard = New-Object IO.FileStream($Manifest.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ((Get-AudioWorkingFileIdentity -Stream $Manifest.Guard) -cne $Manifest.Identity) { throw 'Manifest identity changed after publication.' }
    }
    catch { throw "Required run manifest '$($Manifest.Path)' could not be written ($Checkpoint): $($_.Exception.Message)" }
    finally {
        if ($null -ne $workingGuard) { $workingGuard.Dispose() }
        if ($working -and -not $published -and $workingIdentity) {
            try {
                Assert-AudioNoReparseAncestor -Path $working
                if ([IO.File]::Exists($working) -and (Get-AudioWorkingFileIdentity -Path $working) -ceq $workingIdentity) { [IO.File]::Delete($working) }
            }
            catch { Write-Warning "Manifest working path retained '$working': $($_.Exception.Message)" -ErrorAction Continue }
        }
    }
}

function Close-AudioRunManifest {
    param([AllowNull()][object]$Manifest)
    if ($null -ne $Manifest -and $null -ne $Manifest.Guard) { $Manifest.Guard.Dispose(); $Manifest.Guard = $null }
}

function New-AudioRunReservation {
    param([string]$OutputParent, [string]$InputFolder,
          [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Files,
          [int]$BitrateKbps, [int]$MaxBaseLength,
          [string]$Timestamp = ([datetime]::Now.ToString('yyyyMMdd_HHmmss', [Globalization.CultureInfo]::InvariantCulture)),
          [ValidateRange(1, 2147483647)][int]$StartCounter = 1,
          [ValidateRange(1, 100000)][int]$MaximumAttempts = 1000)
    Assert-AudioParameters -BitrateKbps $BitrateKbps -MaxBaseLength $MaxBaseLength
    $InputFolder = Get-InputDirectory -InputFolder $InputFolder
    Assert-AudioPathComponents -Path $OutputParent
    $OutputParent = Get-AudioPath $OutputParent
    Initialize-AudioDirectoryInterop
    for ($attempt = 0; $attempt -lt $MaximumAttempts; $attempt++) {
        $counter = [long]$StartCounter + $attempt
        if ($counter -gt [int]::MaxValue) { throw 'Run collision counter exhausted.' }
        $candidate = Get-AudioRunCandidate -OutputParent $OutputParent -BitrateKbps $BitrateKbps -Timestamp $Timestamp -Counter $counter
        Assert-AudioRunCandidateBoundary -InputFolder $InputFolder -OutputParent $OutputParent -OutputRoot $candidate
        # Validate the entire actual suffix/path budget before claiming this root.
        $plans = @(Get-AudioBatchNamePlan -Files $Files -InputFolder $InputFolder -OutputRoot $candidate -MaxBaseLength $MaxBaseLength)
        $created = [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($candidate, [IntPtr]::Zero)
        if (-not $created) {
            $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($code -eq 80 -or $code -eq 183) { continue }
            throw "Could not reserve run root '$candidate' (Win32 $code)."
        }
        $ownerToken = [guid]::NewGuid().ToString('N')
        try {
            Assert-AudioOutputBoundary -InputFolder $InputFolder -OutputRoot $candidate
            Write-AudioOutputMarker -OutputRoot $candidate -OwnerToken $ownerToken
            $logPath = New-AudioRunLog -OutputRoot $candidate
            return [pscustomobject]@{
                OutputRoot = $candidate; LogPath = $logPath; OwnerToken = $ownerToken
                Plans = $plans; Counter = [int]$counter
            }
        }
        catch {
            # Leave setup failures visible. Never infer recursive cleanup authority
            # from a name/marker or reclaim a pre-existing candidate.
            throw "Reserved run setup failed. Exact owned scope '$candidate', token '$ownerToken': $($_.Exception.Message)"
        }
    }
    throw "Could not reserve a run after $MaximumAttempts occupied candidates under '$OutputParent'."
}

function Get-AudioInputSnapshot {
    param([Parameter(Mandatory = $true)][string]$InputFolder,
          [Parameter(Mandatory = $true)][string]$OutputRoot)
    $inputPath = Get-AudioPath (Get-InputDirectory -InputFolder $InputFolder)
    $outputPath = Get-AudioPath $OutputRoot
    Assert-AudioOutputBoundary -InputFolder $inputPath -OutputRoot $outputPath
    # Selecting any part of a recognized run tree is an explicit input error.
    $ancestor = $inputPath
    while ($ancestor -and $ancestor -ne [IO.Path]::GetPathRoot($ancestor)) {
        $reason = Get-AudioGeneratedRootReason $ancestor
        if ($reason) { throw "InputFolder is inside generated output: '$ancestor' ($reason)." }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $found = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $skipped = New-Object 'System.Collections.Generic.List[object]'
    $unsupported = 0
    $pending.Push($inputPath)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        try {
            # Explicit recursion avoids following any directory/file reparse point.
            foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
                $path = Get-AudioPath $item.FullName
                if (-not (Test-AudioPathWithin -Path $path -Parent $inputPath)) {
                    throw "Discovered a path outside InputFolder: '$path'."
                }
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                    $kind = if ($item.PSIsContainer) { 'directory' } else { 'file' }
                    $skipped.Add([pscustomobject]@{ Path = $path; Reason = "Skipped $kind reparse point" })
                    continue
                }
                if (Test-AudioPathWithin -Path $path -Parent $outputPath) {
                    $skipped.Add([pscustomobject]@{ Path = $path; Reason = 'Planned output run root' })
                    continue
                }
                if ($item.PSIsContainer) {
                    $reason = Get-AudioGeneratedRootReason $path
                    if ($reason) { $skipped.Add([pscustomobject]@{ Path = $path; Reason = $reason }) }
                    else { $pending.Push($path) }
                }
                elseif (@('.mp3', '.m4a', '.ogg') -contains $item.Extension.ToLowerInvariant()) {
                    $found.Add($path, $item)
                }
                else { $unsupported++ }
            }
        }
        catch { throw "Audio scan failed at '$directory'; no conversion started: $($_.Exception.Message)" }
    }
    # Sort with an explicit Windows comparer, independent of shell/culture.
    $paths = [string[]]@($found.Keys)
    [Array]::Sort($paths, (Get-AudioSourceComparer))
    $files = @($paths | ForEach-Object { $found[$_] })
    return [pscustomobject]@{ Files = $files; Skipped = $skipped.ToArray(); UnsupportedCount = $unsupported }
}

function Get-AudioFiles {
    param([string]$InputFolder, [string]$OutputRoot)
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $OutputRoot = Join-Path $InputFolder ('.AudioFileForPhone-planned-' + [guid]::NewGuid().ToString('N'))
    }
    $snapshot = Get-AudioInputSnapshot -InputFolder $InputFolder -OutputRoot $OutputRoot
    foreach ($skip in $snapshot.Skipped) { Write-Warning ("{0}: {1}" -f $skip.Reason, $skip.Path) }
    return $snapshot.Files
}

function Get-AudioSourceComparer {
    # Case-only neighbours need a stable tie-break on case-sensitive directories.
    return [Collections.Generic.Comparer[string]]::Create([Comparison[string]]{
        param($left, $right)
        $result = [StringComparer]::OrdinalIgnoreCase.Compare($left, $right)
        if ($result -eq 0) { $result = [StringComparer]::Ordinal.Compare($left, $right) }
        return $result
    })
}

function Assert-AudioOutputParentSpelling {
    param([Parameter(Mandatory = $true)][string]$Path)
    # Preserve relative paths, navigation and filesystem PSDrive/provider syntax.
    # The existing resolver determines the provider and canonical destination.
    # Check raw physical components before that resolver can trim trailing dots.
    $spelling = $Path.Replace('/', '\') -replace '^.*?::', '' -replace '^[^\\:]+:', ''
    foreach ($component in $spelling.Split('\')) {
        if ($component.Length -eq 0 -or $component -ceq '.' -or $component -ceq '..') { continue }
        Assert-AudioPathComponents -Path ('C:\' + $component)
    }
}

function Assert-AudioPathComponents {
    param([Parameter(Mandatory = $true)][string]$Path)

    # Inspect original spelling BEFORE GetFullPath can trim or resolve it.
    $spelling = $Path.Replace('/', '\')
    if ($spelling.StartsWith('\\?\') -or $spelling.StartsWith('\\.\')) {
        throw "Extended/device paths are not supported: '$Path'."
    }
    if ($spelling -match '^[A-Za-z]:\\') { $tail = $spelling.Substring(3) }
    elseif ($spelling -match '^\\\\[^\\]+\\[^\\]+\\?') { $tail = $spelling.Substring(2) }
    else { throw "A fully qualified Windows path is required: '$Path'." }

    foreach ($component in $tail.Split('\')) {
        if ($component.Length -eq 0) { continue }
        try { $null = $component.Normalize([Text.NormalizationForm]::FormC) }
        catch { throw "Invalid Unicode in path component '$component' in '$Path'." }
        if ($component.Length -gt 255 -or $component -match '[\x00-\x1f<>:"/\\|?*]' -or
            $component.EndsWith('.') -or $component.EndsWith(' ') -or
            $component -match '^(?i:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])(?:\.|$)') {
            throw "Unsupported preserved path component '$component' in '$Path'. Choose a compatible source folder or a shorter output parent; folder names are not changed."
        }
    }
}

function Assert-AudioPathBudget {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][ValidateSet('File', 'Directory')][string]$Kind
    )
    Assert-AudioPathComponents -Path $Path
    $canonical = Get-AudioPath -Path $Path
    $limit = if ($Kind -eq 'Directory') { 248 } else { 260 }
    if ($canonical.Length -ge $limit) {
        throw "$Kind path is $($canonical.Length) UTF-16 units; the supported limit is $($limit - 1): '$Path'. Choose a shallower input folder or shorter OutputParent."
    }
}

function Get-AudioNamePlan {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRelativePath,
        [datetime]$LastWriteTime,
        [int]$MaxBaseLength = 60,
        [int]$Counter = 1
    )
    if ($MaxBaseLength -lt 24 -or $MaxBaseLength -gt 180) { throw 'MaxBaseLength must be between 24 and 180.' }
    if ($Counter -lt 1) { throw 'Collision Counter must be positive.' }
    $relative = $SourceRelativePath.Replace('/', '\')
    if ($relative.StartsWith('\') -or $relative -match '^[A-Za-z]:' -or $relative.Split('\') -contains '..' -or
        $relative.Split('\') -contains '.' -or $relative.EndsWith('\')) {
        throw "SourceRelativePath must be a relative file path without traversal: '$SourceRelativePath'."
    }
    # String operations also allow pure tests of characters Windows cannot store.
    $separator = $relative.LastIndexOf('\')
    $sourceName = $relative.Substring($separator + 1)
    $dot = $sourceName.LastIndexOf('.')
    $originalBase = if ($dot -ge 0) { $sourceName.Substring(0, $dot) } else { $sourceName }
    $titlePart = $originalBase
    $warnings = New-Object 'System.Collections.Generic.List[string]'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $datePart = $LastWriteTime.ToString('yyyy-MM-dd', $culture)
    $prefix = [regex]::Match($originalBase, '^(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})\s*-?\s*(?<rest>[\s\S]*)$')
    if ($prefix.Success) {
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($prefix.Groups['date'].Value, 'yyyy-MM-dd', $culture,
                [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            $datePart = $parsed.ToString('yyyy-MM-dd', $culture)
            $titlePart = $prefix.Groups['rest'].Value
        }
        else { $warnings.Add('Invalid leading date; using LastWriteTime and retaining the full original basename as title input.') }
    }
    try { $normalized = $titlePart.Normalize([Text.NormalizationForm]::FormC) }
    catch { throw "Invalid Unicode in source name '$SourceRelativePath'." }
    if (-not [StringComparer]::Ordinal.Equals($normalized, $titlePart)) { $warnings.Add('Title normalized to NFC.') }

    $builder = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $normalized.Length;) {
        $width = if ([char]::IsHighSurrogate($normalized[$i])) { 2 } else { 1 }
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($normalized, $i)
        if ($category -in @([Globalization.UnicodeCategory]::UppercaseLetter,
                [Globalization.UnicodeCategory]::LowercaseLetter, [Globalization.UnicodeCategory]::TitlecaseLetter,
                [Globalization.UnicodeCategory]::ModifierLetter, [Globalization.UnicodeCategory]::OtherLetter,
                [Globalization.UnicodeCategory]::DecimalDigitNumber) -or
            [char]::IsWhiteSpace($normalized[$i]) -or $normalized[$i] -eq '-' -or $normalized[$i] -eq '_') {
            $null = $builder.Append($normalized.Substring($i, $width))
        }
        $i += $width
    }
    $safeTitle = $builder.ToString()
    if (-not [StringComparer]::Ordinal.Equals($safeTitle, $normalized)) { $warnings.Add('Characters outside the letters/digits/whitespace/hyphen/underscore whitelist removed.') }
    $safeTitle = ($safeTitle -replace '\s+', ' ').Trim()
    # Removing punctuation can join letters that compose (for example Hangul).
    $composedTitle = $safeTitle.Normalize([Text.NormalizationForm]::FormC)
    if (-not [StringComparer]::Ordinal.Equals($composedTitle, $safeTitle)) { $warnings.Add('Filtered title normalized to NFC.') }
    $safeTitle = $composedTitle
    if ([string]::IsNullOrWhiteSpace($safeTitle)) { $safeTitle = 'Episode' }
    $suffix = if ($Counter -eq 1) { '' } else { ' (' + $Counter.ToString($culture) + ')' }
    $prefixText = "$datePart - "
    $titleBudget = $MaxBaseLength - $prefixText.Length - $suffix.Length
    if ($titleBudget -lt 1) { throw "Collision suffix '$suffix' cannot fit MaxBaseLength $MaxBaseLength with the complete date and a title." }
    $title = $safeTitle
    if ($title.Length -gt $titleBudget) {
        $cut = $titleBudget
        if ([char]::IsHighSurrogate($title[$cut - 1])) { $cut-- }
        $title = $title.Substring(0, $cut).TrimEnd()
        $warnings.Add('Title shortened within the UTF-16 basename budget.')
    }
    if ($title.Length -eq 0) { throw "Collision suffix '$suffix' cannot fit MaxBaseLength $MaxBaseLength with one complete title scalar." }
    $baseName = $prefixText + $title + $suffix
    $relativeDir = if ($separator -ge 0) { $relative.Substring(0, $separator) } else { '' }
    if ($relativeDir) { Assert-AudioPathComponents -Path ('C:\' + $relativeDir) }
    $outputRelativePath = if ($relativeDir) { [IO.Path]::Combine($relativeDir, "$baseName.mp3") } else { "$baseName.mp3" }
    return [pscustomobject]@{
        OriginalBase = $originalBase; DatePart = $datePart; Title = $title; BaseName = $baseName
        OutputRelativePath = $outputRelativePath; Warnings = [string[]]$warnings.ToArray()
    }
}

function Get-AudioBatchNamePlan {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Files,
        [Parameter(Mandatory = $true)][string]$InputFolder,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [int]$MaxBaseLength = 60
    )
    # Pure lexical planning: no enumeration, probes, prompts or writes here.
    if ($MaxBaseLength -lt 24 -or $MaxBaseLength -gt 180) { throw 'MaxBaseLength must be between 24 and 180.' }
    Assert-AudioPathComponents -Path $InputFolder
    Assert-AudioPathBudget -Path $OutputRoot -Kind Directory
    $inputPath = Get-AudioPath -Path $InputFolder
    $rootPath = Get-AudioPath -Path $OutputRoot
    $inputLeaf = [IO.Path]::GetFileName($inputPath)
    if (-not $inputLeaf) { throw 'The input folder must have a preserved leaf name.' }
    $outputBase = [IO.Path]::Combine($rootPath, $inputLeaf)
    Assert-AudioPathBudget -Path $outputBase -Kind Directory
    Assert-AudioPathBudget -Path ([IO.Path]::Combine($rootPath, '.AudioFileForPhone-output.json')) -Kind File
    Assert-AudioPathBudget -Path ([IO.Path]::Combine($rootPath, 'AudioFileForPhone_log.txt')) -Kind File
    Assert-AudioPathBudget -Path ([IO.Path]::Combine($rootPath, 'AudioFileForPhone_manifest.json')) -Kind File
    Assert-AudioPathBudget -Path ([IO.Path]::Combine($rootPath, '.AudioFileForPhone-' + ('0' * 32) + '.partial')) -Kind File

    $sources = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($file in $Files) {
        $sourcePath = [string]$file.FullName
        Assert-AudioPathComponents -Path ([IO.Path]::GetDirectoryName($sourcePath))
        $canonicalSource = Get-AudioPath -Path $sourcePath
        if (-not (Test-AudioPathWithin -Path $canonicalSource -Parent $inputPath) -or
            [StringComparer]::OrdinalIgnoreCase.Equals($canonicalSource, $inputPath)) {
            throw "Source lies outside the input folder: '$sourcePath'."
        }
        if ($sources.ContainsKey($canonicalSource)) { throw "Duplicate source in naming inventory: '$sourcePath'." }
        $sources.Add($canonicalSource, $file)
    }
    $paths = [string[]]@($sources.Keys)
    [Array]::Sort($paths, (Get-AudioSourceComparer))
    $destinations = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $plans = New-Object 'System.Collections.Generic.List[object]'
    foreach ($sourcePath in $paths) {
        $file = $sources[$sourcePath]
        $relative = $sourcePath.Substring($inputPath.Length).TrimStart('\', '/')
        $counter = 1
        while ($true) {
            $name = Get-AudioNamePlan -SourceRelativePath $relative -LastWriteTime $file.LastWriteTime -MaxBaseLength $MaxBaseLength -Counter $counter
            $outputRelative = [IO.Path]::Combine($inputLeaf, $name.OutputRelativePath)
            if ($destinations.Add($outputRelative)) { break }
            if ($counter -eq [int]::MaxValue) { throw "Collision counter exhausted for '$sourcePath'." }
            $counter++
        }
        $outputPath = [IO.Path]::Combine($rootPath, $outputRelative)
        $outDir = [IO.Path]::GetDirectoryName($outputPath)
        Assert-AudioPathBudget -Path $outDir -Kind Directory
        Assert-AudioPathBudget -Path $outputPath -Kind File
        # T09 must use a fixed-length working name, independent of title/suffix.
        $working = [IO.Path]::Combine($outDir, '.AudioFileForPhone-' + ('0' * 32) + '.partial')
        Assert-AudioPathBudget -Path $working -Kind File
        $plans.Add([pscustomobject]@{
            SourcePath = $sourcePath; SourceFile = $file; SourceRelativePath = $relative; OriginalBase = $name.OriginalBase
            OutputRelativePath = $outputRelative; OutputPath = $outputPath; OutputDirectory = $outDir
            BaseName = $name.BaseName; Warnings = $name.Warnings; WorkingPathTemplate = $working
        })
    }
    return $plans.ToArray()
}

function Get-SanitizedAudioBaseName {
    param([string]$OriginalBase, [datetime]$LastWriteTime, [int]$MaxBaseLength)
    return (Get-AudioNamePlan -SourceRelativePath ($OriginalBase + '.mp3') -LastWriteTime $LastWriteTime -MaxBaseLength $MaxBaseLength).BaseName
}

function New-AudioCoverDiagnostics {
    param([string]$Path, [AllowNull()][object]$SizeBytes,
          [AllowNull()][object]$Width, [AllowNull()][object]$Height)
    $diag = [ordered]@{
        Path = $Path; SizeBytes = $null; SizeMB = $null
        Width = $Width; Height = $Height; Warnings = @()
    }
    if ($null -ne $SizeBytes) {
        $diag.SizeBytes = [int64]$SizeBytes
        $diag.SizeMB = [Math]::Round(($SizeBytes / 1MB), 2)
        if ($diag.SizeMB -gt 2.0) {
            $diag.Warnings += ("Cover is {0} MB. Consider a smaller JPG to avoid bloating every output MP3." -f $diag.SizeMB)
        }
    }
    if (($null -ne $Width -and $Width -gt 1200) -or ($null -ne $Height -and $Height -gt 1200)) {
        $diag.Warnings += ("Cover dimensions are {0}x{1}. Consider ~800x800 to keep file sizes sane." -f $Width, $Height)
    }
    return [pscustomobject]$diag
}

function Get-CoverDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sizeBytes = $null; $width = $null; $height = $null; $warning = $null

    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        $sizeBytes = [int64]$fi.Length

        # Dimension heuristic: best-effort only (System.Drawing)
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction Stop | Out-Null
            $img = [System.Drawing.Image]::FromFile($Path)
            try {
                $width = $img.Width
                $height = $img.Height
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
        $warning = "Could not read cover file info: {0}" -f $_
    }
    $diag = New-AudioCoverDiagnostics -Path $Path -SizeBytes $sizeBytes -Width $width -Height $height
    if ($warning) { $diag.Warnings += $warning }
    return $diag
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
