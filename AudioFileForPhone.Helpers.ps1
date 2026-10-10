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

function Invoke-AudioNativeProcess {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments,
        [ValidateRange(0, 2147483647)][int]$MaxStdoutChars = 1048576,
        [ValidateRange(0, 2147483647)][int]$MaxStderrChars = 65536
    )

    $result = [ordered]@{
        Status = 'StartFailed'; ExecutablePath = $ExecutablePath; Arguments = [string[]]$Arguments.Clone()
        ExitCode = $null; Stdout = ''; Stderr = ''; StdoutTruncated = $false; StderrTruncated = $false
        StdoutTotalChars = [long]0; StderrTotalChars = [long]0; DurationMilliseconds = [long]0; Error = ''
    }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $capture = $null
    try {
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
using System.Threading.Tasks;
namespace AudioFileForPhone {
    public sealed class NativeCapture : IDisposable {
        private sealed class DrainResult {
            public string Text;
            public long TotalChars;
        }
        private Process process;
        private Task<DrainResult> stdoutTask;
        private Task<DrainResult> stderrTask;
        private bool completed;
        public int ExitCode { get; private set; }
        public string Stdout { get; private set; }
        public string Stderr { get; private set; }
        public long StdoutTotalChars { get; private set; }
        public long StderrTotalChars { get; private set; }
        public bool StdoutTruncated { get; private set; }
        public bool StderrTruncated { get; private set; }

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
        private static DrainResult Drain(StreamReader reader, int limit) {
            StringBuilder retained = new StringBuilder(Math.Min(limit, 4096));
            char[] buffer = new char[4096];
            long total = 0;
            int count;
            while ((count = reader.Read(buffer, 0, buffer.Length)) != 0) {
                total += count;
                int keep = Math.Min(count, limit - retained.Length);
                if (keep > 0) retained.Append(buffer, 0, keep);
            }
            return new DrainResult { Text = retained.ToString(), TotalChars = total };
        }
        public NativeCapture(string executablePath, string[] arguments, int stdoutLimit, int stderrLimit) {
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
                StreamReader stdoutReader = process.StandardOutput;
                StreamReader stderrReader = process.StandardError;
                // Reuse pool workers rather than allocate two CLR threads and
                // their native handles for every media item in a long batch.
                stdoutTask = Task.Factory.StartNew(() => Drain(stdoutReader, stdoutLimit), System.Threading.CancellationToken.None, TaskCreationOptions.None, TaskScheduler.Default);
                stderrTask = Task.Factory.StartNew(() => Drain(stderrReader, stderrLimit), System.Threading.CancellationToken.None, TaskCreationOptions.None, TaskScheduler.Default);
                // Observe faults even if an interrupted caller cannot join a drain.
                stdoutTask.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
                stderrTask.ContinueWith(t => { var ignored = t.Exception; }, TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously);
                process.StandardInput.Close();
            } catch {
                Dispose();
                throw;
            }
        }
        public bool WaitForExit(int milliseconds) { return process.WaitForExit(milliseconds); }
        public int CaptureExitCode() { ExitCode = process.ExitCode; return ExitCode; }
        public void Complete() {
            Task.WaitAll(stdoutTask, stderrTask);
            Stdout = stdoutTask.Result.Text;
            Stderr = stderrTask.Result.Text;
            StdoutTotalChars = stdoutTask.Result.TotalChars;
            StderrTotalChars = stderrTask.Result.TotalChars;
            StdoutTruncated = StdoutTotalChars > Stdout.Length;
            StderrTruncated = StderrTotalChars > Stderr.Length;
            completed = true;
        }
        public void Dispose() {
            if (process == null) return;
            // Only this helper's process is owned. Abnormal unwind never searches
            // process names, terminates unrelated children or changes global state.
            if (!completed) {
                try { if (!process.HasExited) process.Kill(); } catch { }
            }
            // Process.Dispose closes its process handle; explicitly own each pipe
            // reader/writer on successful completion and on abnormal unwind.
            try { process.StandardInput.Dispose(); } catch { }
            try { process.StandardOutput.Dispose(); } catch { }
            try { process.StandardError.Dispose(); } catch { }
            // This bounded teardown join is separate from process runtime: normal
            // conversions have no timeout. Killed/closed pipes should promptly end.
            try {
                if (stdoutTask != null && stderrTask != null) Task.WaitAll(new Task[] { stdoutTask, stderrTask }, 1000);
                else if (stdoutTask != null) stdoutTask.Wait(1000);
                else if (stderrTask != null) stderrTask.Wait(1000);
            } catch { }
            if (stdoutTask != null && stdoutTask.IsCompleted) stdoutTask.Dispose();
            if (stderrTask != null && stderrTask.IsCompleted) stderrTask.Dispose();
            process.Dispose();
            process = null;
        }
    }
}
'@ -ErrorAction Stop
        }
        $capture = New-Object AudioFileForPhone.NativeCapture($ExecutablePath, $Arguments, $MaxStdoutChars, $MaxStderrChars)
        # Short polling permits PowerShell interruption; it is not a runtime limit.
        while (-not $capture.WaitForExit(100)) { }
        $result.ExitCode = $capture.CaptureExitCode()
        $result.Status = 'CaptureFailed'
        $capture.Complete()
        $result.Status = 'Completed'
        $result.Stdout = $capture.Stdout
        $result.Stderr = $capture.Stderr
        $result.StdoutTruncated = $capture.StdoutTruncated
        $result.StderrTruncated = $capture.StderrTruncated
        $result.StdoutTotalChars = $capture.StdoutTotalChars
        $result.StderrTotalChars = $capture.StderrTotalChars
    }
    catch { $result.Error = $_.Exception.Message }
    finally {
        if ($null -ne $capture) { $capture.Dispose() }
        $timer.Stop()
        $result.DurationMilliseconds = $timer.ElapsedMilliseconds
    }
    return [pscustomobject]$result
}

function Get-AudioMediaInfo {
    param([string]$Path, [string]$FfprobePath)
    $result = [ordered]@{
        Status = 'InvalidProbeData'; TitleStatus = 'Unknown'; Title = $null
        StreamIndex = $null; MetadataSource = $null; NativeResult = $null; Error = ''
    }
    try {
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
            'stream=index,codec_type:stream_tags:format_tags', '-of', 'json', '-i', $localPath
        )
        $result.NativeResult = $native
        if ($native.Status -ne 'Completed') {
            $result.Status = $native.Status
            $result.Error = $native.Error
            return [pscustomobject]$result
        }
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
        # Keep baseline truthiness: an empty title falls back to the filename;
        # whitespace and all other nonempty title strings remain intact.
        if ($null -ne $tags -and -not [string]::IsNullOrEmpty($tags.title)) {
            $result.TitleStatus = 'Present'
            $result.Title = $tags.title
        }
        else { $result.TitleStatus = 'Absent' }
        $result.Status = 'Success'
    }
    catch { $result.Error = $_.Exception.Message }
    return [pscustomobject]$result
}

function Assert-ToolPrerequisites {
    param([string]$FfmpegPath, [string]$FfprobePath)
    $tools = [ordered]@{}
    foreach ($tool in @(@{ Name = 'ffmpeg'; Path = $FfmpegPath }, @{ Name = 'ffprobe'; Path = $FfprobePath })) {
        try {
            $arguments = if ($tool.Name -eq 'ffmpeg') { @('-nostdin', '-version') } else { @('-version') }
            $native = Invoke-AudioNativeProcess -ExecutablePath $tool.Path -Arguments $arguments
            $version = ($native.Stdout -split '\r?\n' | Select-Object -First 1)
            if ($native.Status -ne 'Completed') { throw "$($native.Status): $($native.Error)" }
            if ($native.ExitCode -ne 0 -or $native.StdoutTruncated -or $version -notmatch ('^' + $tool.Name + ' version \S')) {
                throw 'Expected a successful tool version response.'
            }
            $tools[$tool.Name] = [pscustomobject]@{ Path = $tool.Path; Version = $version }
            Write-Host ("[INFO] {0}: {1}" -f $tool.Path, $version)
        }
        catch { throw "Invalid $($tool.Name) executable '$($tool.Path)': $($_.Exception.Message)" }
    }
    $encoders = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments @('-nostdin', '-hide_banner', '-encoders')
    if ($encoders.Status -ne 'Completed' -or $encoders.ExitCode -ne 0 -or $encoders.StdoutTruncated -or
        ($encoders.Stdout + "`n" + $encoders.Stderr) -notmatch '(?m)^\s*A\S*\s+libmp3lame\s') {
        throw "ffmpeg does not provide the required libmp3lame encoder: $FfmpegPath"
    }
    return [pscustomobject]@{ Ffmpeg = $tools['ffmpeg']; Ffprobe = $tools['ffprobe'] }
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
        $native = Invoke-AudioNativeProcess -ExecutablePath $FfmpegPath -Arguments @(
            '-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $item.FullName,
            '-map', '0:v:0', '-frames:v', '1', '-c:v', 'mjpeg', '-f', 'null', '-'
        )
        if ($native.Status -ne 'Completed') { throw "FFmpeg could not decode the cover ($($native.Status)): $($native.Error)" }
        if ($native.ExitCode -ne 0) { throw "FFmpeg could not decode the cover (exit $($native.ExitCode)): $($native.Stderr)" }
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
