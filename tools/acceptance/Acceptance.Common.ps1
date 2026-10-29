function Assert-AcceptanceLocalPath {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$MustExist)
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path -match '[\x00-\x1f<>"|?*]' -or
        $Path.Substring(2) -match ':' -or $Path -match '(?:^|[\\/])[^\\/]*[. ](?:[\\/]|$)') {
        throw 'Acceptance requires an ordinary absolute local path without aliases, streams or wildcard characters.'
    }
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full -ne $root) { $full = $full.TrimEnd('\', '/') }
    $cursor = $full
    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw 'Acceptance does not traverse reparse points; this storage path remains untested.'
            }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    if ($MustExist -and -not (Test-Path -LiteralPath $full)) { throw 'The selected acceptance path does not exist.' }
    return $full
}

function Test-AcceptanceWithin {
    param([string]$Path, [string]$Root)
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Root.TrimEnd('\', '/') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Get-AcceptanceMemberPath {
    param([string]$Root, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath -match '^[\\/]|[:\x00-\x1f<>"|?*]' -or
        $RelativePath -match '(?:^|[\\/])(?:\.|\.\.)(?:[\\/]|$)|[. ](?:[\\/]|$)|[\\/]$|[\\/]{2}' -or
        $RelativePath -match '(?:^|[\\/])(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|[\\/]|$)') {
        throw 'Unsafe relative acceptance member.'
    }
    $path = Assert-AcceptanceLocalPath (Join-Path $Root $RelativePath)
    if (-not (Test-AcceptanceWithin $path $Root) -or $path -eq $Root) { throw 'Acceptance member escaped its root.' }
    return $path
}

function Get-AcceptanceHash {
    param([string]$Path)
    $null = Assert-AcceptanceLocalPath $Path -MustExist
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Read-AcceptanceJson {
    param([string]$Path, [int]$MaximumBytes = 16777216)
    $null = Assert-AcceptanceLocalPath $Path -MustExist
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -gt $MaximumBytes) { throw 'Acceptance JSON must be a bounded regular file.' }
    return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
}

function Get-AcceptanceSourceInventory {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Root, [switch]$IncludeUnsupported)
    $rootPath = Assert-AcceptanceLocalPath $Root -MustExist
    if (-not (Get-Item -LiteralPath $rootPath -Force).PSIsContainer) { throw 'Select a source folder.' }
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $result = New-Object 'Collections.Generic.List[object]'
    $productionSnapshot = $null
    if (Get-Command Get-AudioInputSnapshot -CommandType Function -ErrorAction SilentlyContinue) {
        # Windows PS5.1 can return no object and no ItemNotFound exception for an
        # absent literal child below a bracket/Unicode path. The unchanged
        # production identity reader runs without StrictMode in the application.
        # This local adapter preserves its missing-file meaning under the kit's
        # StrictMode, including the existing literal/error/reparse guards. It
        # disappears with this inventory call; production conversion is separate.
        function Get-AudioIdentityFile {
            param([string]$Path)
            try { $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
            catch [Management.Automation.ItemNotFoundException] { return $null }
            if ($null -eq $item) { return $null }
            if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $null
            }
            return $item
        }
        $productionSnapshot = Get-AudioInputSnapshot -InputFolder $rootPath -OutputRoot (Join-Path $rootPath ('.acceptance-plan-' + [guid]::NewGuid().ToString('N')))
        if (@($productionSnapshot.Skipped | Where-Object { $_.Reason -match 'reparse' }).Count -gt 0) {
            throw 'Selected source has reparse exclusions; this storage evidence remains untested.'
        }
    }
    $pending.Push($rootPath)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            $null = Assert-AcceptanceLocalPath $item.FullName -MustExist
            if ($item.PSIsContainer) {
                if ($null -ne $productionSnapshot -and (Get-AudioGeneratedRootReason $item.FullName)) { continue }
                $pending.Push($item.FullName); continue
            }
            $supported = @('.mp3', '.m4a', '.ogg') -contains $item.Extension.ToLowerInvariant()
            if (-not $supported -and -not $IncludeUnsupported) { continue }
            if ($result.Count -ge 100000) { throw 'The selected source inventory exceeds the bounded acceptance limit.' }
            $result.Add([pscustomobject]@{
                relative_path = $item.FullName.Substring($rootPath.Length).TrimStart('\', '/')
                path = $item.FullName; sha256 = Get-AcceptanceHash $item.FullName
                length = [long]$item.Length; supported = [bool]$supported; inventory_includes_unsupported = [bool]$IncludeUnsupported
            })
        }
    }
    return @($result.ToArray() | Sort-Object relative_path)
}

function Test-AcceptanceSourceInventory {
    param([string]$Root, [object[]]$Before, [switch]$IncludeUnsupported)
    if (@($Before | Where-Object { $null -ne $_.PSObject.Properties['inventory_includes_unsupported'] -and $_.inventory_includes_unsupported }).Count -gt 0) { $IncludeUnsupported = $true }
    $after = @(Get-AcceptanceSourceInventory -Root $Root -IncludeUnsupported:$IncludeUnsupported)
    if ($after.Count -ne @($Before).Count) { return $false }
    $map = @{}
    foreach ($row in @($Before)) {
        if ($map.ContainsKey([string]$row.relative_path)) { return $false }
        $map[[string]$row.relative_path] = $row
    }
    foreach ($row in $after) {
        if (-not $map.ContainsKey([string]$row.relative_path)) { return $false }
        $old = $map[[string]$row.relative_path]
        if ($old.sha256 -cne $row.sha256 -or $old.length -ne $row.length) { return $false }
    }
    return $true
}

function Get-AcceptanceZipHash {
    param([object]$Entry)
    $stream = $Entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Test-AcceptanceZip {
    param([string]$ZipPath, [object[]]$Expected, [string]$ExtractDirectory, [long]$MaximumBytes = 67108864)
    $null = Assert-AcceptanceLocalPath $ZipPath -MustExist
    if ((Get-Item -LiteralPath $ZipPath).Length -gt $MaximumBytes) { throw 'Acceptance ZIP exceeds the bounded package limit.' }
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    $expectedMap = @{}
    foreach ($row in $Expected) {
        $name = [string]$row.path
        $null = Get-AcceptanceMemberPath -Root ([IO.Path]::GetDirectoryName($ZipPath)) -RelativePath $name
        if ($name.Contains('\') -or $expectedMap.ContainsKey($name) -or [string]$row.sha256 -cnotmatch '^[a-f0-9]{64}$') {
            throw 'Acceptance expected ZIP inventory is invalid.'
        }
        $expectedMap[$name] = $row
    }
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    $found = @{}; $total = [long]0
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if (-not $expectedMap.ContainsKey($name) -or $found.ContainsKey($name) -or $entry.ExternalAttributes -ne 0) {
                throw 'Unexpected, duplicate or nonregular acceptance ZIP member.'
            }
            $total += $entry.Length
            if ($entry.Length -gt 16777216 -or $total -gt $MaximumBytes) { throw 'Acceptance ZIP expansion exceeds its bound.' }
            $expectedRow = $expectedMap[$name]
            if ([string]$expectedRow.path -cne $name) { throw 'Acceptance ZIP member spelling differs from the exact inventory.' }
            if ((Get-AcceptanceZipHash $entry) -cne [string]$expectedRow.sha256) { throw 'Acceptance ZIP member hash mismatch.' }
            if ($null -ne $expectedRow.PSObject.Properties['bytes'] -and $entry.Length -ne [long]$expectedRow.bytes) {
                throw 'Acceptance ZIP member size mismatch.'
            }
            $found[$name] = $true
        }
        if ($found.Count -ne $expectedMap.Count) { throw 'Acceptance ZIP omits a required member.' }
        if (-not [string]::IsNullOrWhiteSpace($ExtractDirectory)) {
            $extract = Assert-AcceptanceLocalPath $ExtractDirectory
            if (Test-Path -LiteralPath $extract) { throw 'Runtime extraction requires a new owned directory.' }
            $parent = [IO.Path]::GetDirectoryName($extract)
            $null = Assert-AcceptanceLocalPath $parent -MustExist
            $null = [IO.Directory]::CreateDirectory($extract)
            foreach ($entry in $archive.Entries) {
                $path = Get-AcceptanceMemberPath $extract $entry.FullName
                $directory = [IO.Path]::GetDirectoryName($path)
                $null = [IO.Directory]::CreateDirectory($directory)
                $null = Assert-AcceptanceLocalPath $directory -MustExist
                $inputStream = $entry.Open()
                $outputStream = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose(); $inputStream.Dispose() }
                if ((Get-AcceptanceHash $path) -cne [string]$expectedMap[$entry.FullName].sha256) { throw 'Extracted acceptance member hash mismatch.' }
            }
        }
    } finally { $archive.Dispose() }
}

function Read-AcceptanceKit {
    [CmdletBinding()]
    param([string]$KitRoot, [string]$KitArchivePath, [string]$ExtractDirectory)
    $kit = Assert-AcceptanceLocalPath $KitRoot -MustExist
    $archivePath = Assert-AcceptanceLocalPath $KitArchivePath -MustExist
    $manifestPath = Join-Path $kit 'kit-manifest.json'
    $manifest = Read-AcceptanceJson $manifestPath -MaximumBytes 1048576
    if ($manifest.schema_version -ne 1 -or $manifest.kind -cnotin @('acceptance_kit', 'rehearsal_acceptance_kit') -or
        [string]$manifest.source_commit -cnotmatch '^[a-f0-9]{40}$' -or
        [string]$manifest.runtime_zip_sha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'The kit manifest identity is invalid.' }
    $kitExpected = @($manifest.kit_files) + @([pscustomobject]@{ path = 'kit-manifest.json'; sha256 = Get-AcceptanceHash $manifestPath })
    Test-AcceptanceZip -ZipPath $archivePath -Expected $kitExpected
    foreach ($file in @($manifest.kit_files)) {
        $path = Get-AcceptanceMemberPath $kit ([string]$file.path)
        if ((Get-AcceptanceHash $path) -cne [string]$file.sha256) { throw 'An extracted kit member differs from the tested ZIP.' }
    }
    $runtimeZip = Get-AcceptanceMemberPath $kit ([string]$manifest.runtime_zip)
    if ((Get-AcceptanceHash $runtimeZip) -cne [string]$manifest.runtime_zip_sha256) { throw 'Runtime ZIP digest mismatch.' }
    $runtimeManifestPath = Join-Path $kit 'runtime\release-manifest.json'
    $runtimeManifest = Read-AcceptanceJson $runtimeManifestPath -MaximumBytes 1048576
    if ($runtimeManifest.schema_version -ne 1 -or $runtimeManifest.release_commit -cne $manifest.source_commit -or
        $runtimeManifest.app_version -cne $manifest.runtime_version -or
        $runtimeManifest.tag -cne ('v' + $manifest.runtime_version) -or
        $runtimeManifest.zip.name -cne [IO.Path]::GetFileName($runtimeZip) -or
        $runtimeManifest.zip.sha256 -cne $manifest.runtime_zip_sha256 -or
        $runtimeManifest.zip.bytes -ne (Get-Item -LiteralPath $runtimeZip).Length) { throw 'Runtime manifest identity mismatch.' }
    if ($manifest.kind -ceq 'acceptance_kit' -and ($manifest.runtime_version -cne '1.0.1' -or
        [IO.Path]::GetFileName($runtimeZip) -cne 'AudioFileForPhone-v1.0.1.zip')) { throw 'Final acceptance kit must match the fixed v1.0.1 target.' }
    $checksumRows = @([IO.File]::ReadAllLines((Join-Path $kit 'runtime\SHA256SUMS.txt')) | Where-Object { $_.Length -gt 0 })
    if ($checksumRows.Count -ne 2 -or $checksumRows -cnotcontains ($manifest.runtime_zip_sha256 + '  ' + [IO.Path]::GetFileName($runtimeZip)) -or
        $checksumRows -cnotcontains ((Get-AcceptanceHash $runtimeManifestPath) + '  release-manifest.json')) { throw 'Runtime external checksums mismatch.' }
    $runtimeExpected = @()
    foreach ($property in $runtimeManifest.files.PSObject.Properties) {
        $runtimeExpected += [pscustomobject]@{ path = $property.Name; sha256 = [string]$property.Value; bytes = $runtimeManifest.file_bytes.($property.Name) }
    }
    $requiredRuntime = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.ManagedSetup.ps1',
        'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Diagnostics.ps1',
        'AudioFileForPhone.Checks.ps1', 'Check-AudioFileForPhone.ps1', 'Check-AudioFileForPhone.bat',
        'tools/ffmpeg-download.json', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat',
        'AudioFileForPhone.bat', 'README.md', 'SUPPORT.md', 'CHANGELOG.md', 'SECURITY.md', 'LICENSE')
    if ($runtimeExpected.Count -ne $requiredRuntime.Count -or
        @($runtimeExpected | Where-Object { $requiredRuntime -cnotcontains $_.path }).Count -gt 0) {
        throw 'Runtime manifest does not contain the reviewed complete package inventory.'
    }
    $runtimeMap = @{}
    foreach ($row in @($manifest.runtime_hashes)) {
        if ($runtimeMap.ContainsKey([string]$row.path)) { throw 'Duplicate runtime kit identity.' }
        $runtimeMap[[string]$row.path] = [string]$row.sha256
    }
    if ($runtimeMap.Count -ne $runtimeExpected.Count) { throw 'Kit runtime inventory differs from runtime manifest.' }
    foreach ($row in $runtimeExpected) { if ($runtimeMap[[string]$row.path] -cne $row.sha256) { throw 'Kit runtime hash differs from runtime manifest.' } }
    Test-AcceptanceZip -ZipPath $runtimeZip -Expected $runtimeExpected -ExtractDirectory $ExtractDirectory
    return [pscustomobject]@{
        manifest = $manifest; runtime_directory = $ExtractDirectory; source_commit = [string]$manifest.source_commit
        runtime_version = [string]$manifest.runtime_version; runtime_zip_sha256 = [string]$manifest.runtime_zip_sha256
        acceptance_kit_sha256 = Get-AcceptanceHash $archivePath; runtime_hashes = @($manifest.runtime_hashes)
    }
}

function ConvertTo-AcceptanceNativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($null -eq $Value -or $Value.IndexOf([char]0) -ge 0) { throw 'Invalid native argument.' }
    $builder = New-Object Text.StringBuilder
    $null = $builder.Append('"'); $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { $null = $builder.Append('\', ($slashes * 2 + 1)); $null = $builder.Append('"') }
        else { $null = $builder.Append('\', $slashes); $null = $builder.Append($character) }
        $slashes = 0
    }
    $null = $builder.Append('\', ($slashes * 2)); $null = $builder.Append('"')
    return $builder.ToString()
}

function Initialize-AcceptanceCapture {
    if ('AudioFileForPhoneAcceptance.PipeCapture' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace AudioFileForPhoneAcceptance {
  public sealed class PipeCapture : IDisposable {
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool PeekNamedPipe(SafeFileHandle p, IntPtr b, uint s, IntPtr r, out uint a, IntPtr l);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ReadFile(SafeFileHandle p, byte[] b, uint s, out uint r, IntPtr o);
    readonly StringBuilder text = new StringBuilder(); readonly Task worker;
    volatile bool stop; public bool EndOfPipe; public bool Truncated; public string Error = "";
    public string Text { get { lock(text) return text.ToString(); } }
    public PipeCapture(StreamReader reader, int limit) {
      worker = Task.Factory.StartNew(() => {
        try {
          SafeFileHandle handle = ((FileStream)reader.BaseStream).SafeFileHandle;
          byte[] bytes = new byte[4096]; char[] chars = new char[4097];
          Decoder decoder = new UTF8Encoding(false,false).GetDecoder();
          while(!stop) {
            uint available; bool end = false;
            if(!PeekNamedPipe(handle,IntPtr.Zero,0,IntPtr.Zero,out available,IntPtr.Zero)) {
              int code = Marshal.GetLastWin32Error(); if(code != 109) throw new IOException("Pipe peek failed."); end=true;
            }
            if(!end && available==0) { Thread.Sleep(10); continue; }
            uint read=0;
            if(!end && !ReadFile(handle,bytes,Math.Min((uint)bytes.Length,available),out read,IntPtr.Zero)) {
              int code=Marshal.GetLastWin32Error(); if(code != 109) throw new IOException("Pipe read failed."); end=true;
            }
            int count=decoder.GetChars(bytes,0,(int)read,chars,0,end);
            lock(text) { int keep=Math.Min(count,limit-text.Length); if(keep>0) text.Append(chars,0,keep); if(keep<count) Truncated=true; }
            if(end) { EndOfPipe=true; break; }
          }
        } catch(Exception error) { Error=error.GetType().Name; }
      },CancellationToken.None,TaskCreationOptions.None,TaskScheduler.Default);
      worker.ContinueWith(t => { var ignored=t.Exception; },TaskContinuationOptions.OnlyOnFaulted);
    }
    public bool Wait(int milliseconds) { return worker.Wait(milliseconds) && EndOfPipe && Error.Length==0; }
    public void Dispose() { stop=true; worker.Wait(1000); }
  }
}
'@ -ErrorAction Stop
}

function Invoke-AcceptanceChild {
    [CmdletBinding()]
    param([string]$Executable, [AllowEmptyCollection()][string[]]$Arguments, [hashtable]$Environment = @{},
          [AllowNull()][string]$StandardInput, [string]$WorkingDirectory)
    $null = Assert-AcceptanceLocalPath $Executable -MustExist
    Initialize-AcceptanceCapture
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable; $start.Arguments = (@($Arguments | ForEach-Object { ConvertTo-AcceptanceNativeArgument $_ }) -join ' ')
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $start.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) { $start.WorkingDirectory = Assert-AcceptanceLocalPath $WorkingDirectory -MustExist }
    foreach ($key in $Environment.Keys) { $start.EnvironmentVariables[[string]$key] = [string]$Environment[$key] }
    $process = New-Object Diagnostics.Process; $process.StartInfo = $start
    $output = $null; $errors = $null; $release = $false; $drained = $false
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) { throw 'The owned acceptance child did not start.' }
        $output = New-Object AudioFileForPhoneAcceptance.PipeCapture($process.StandardOutput, 1048576)
        $errors = New-Object AudioFileForPhoneAcceptance.PipeCapture($process.StandardError, 262144)
        if ($null -ne $StandardInput) { $process.StandardInput.Write($StandardInput) }
        $process.StandardInput.Close()
        # Encoding and complete decode are intentionally unlimited.
        while (-not $process.WaitForExit(250)) { }
        $drained = $output.Wait(5000) -and $errors.Wait(5000)
        $release = $process.HasExited -and $drained
        return [pscustomobject]@{
            exit_code = $process.ExitCode; stdout = $output.Text; stderr = $errors.Text
            stdout_truncated = $output.Truncated; stderr_truncated = $errors.Truncated
            process_released = [bool]$release; pipe_drain_completed = [bool]$drained
            elapsed_ms = $timer.ElapsedMilliseconds
        }
    } finally {
        $timer.Stop()
        if ($null -ne $output) { $output.Dispose() }
        if ($null -ne $errors) { $errors.Dispose() }
        $process.Dispose()
        # No process is killed and no fixture is removed on an unproved release.
    }
}

function Test-AcceptanceConversion {
    [CmdletBinding()]
    param([string]$RunDirectory, [string]$SourceRoot, [object[]]$SourceBefore,
          [string]$RuntimeDirectory, [string]$FfmpegPath, [string]$FfprobePath,
          [AllowNull()][Nullable[int]]$CapturedExitCode)
    $run = Assert-AcceptanceLocalPath $RunDirectory -MustExist
    $source = Assert-AcceptanceLocalPath $SourceRoot -MustExist
    $runtime = Assert-AcceptanceLocalPath $RuntimeDirectory -MustExist
    $manifestPath = Join-Path $run 'AudioFileForPhone_manifest.json'
    $manifest = Read-AcceptanceJson $manifestPath
    if ($manifest.schema_version -ne 1 -or $manifest.kind -cne 'AudioFileForPhone.RunManifest' -or
        $manifest.run.status -cne 'Completed' -or $manifest.run.exit_code -ne 0 -or
        $manifest.checkpoint -cne 'Final' -or $manifest.policies.bitrate_kbps -ne 64 -or
        -not ([string]$manifest.run.input_root).Equals($source, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([string]$manifest.run.output_root).Equals($run, [StringComparison]::OrdinalIgnoreCase)) { throw 'The exact production run did not complete successfully for the selected source.' }
    if ($null -ne $CapturedExitCode -and $CapturedExitCode -ne 0) { throw 'The controlled production process returned a nonzero raw exit.' }
    if ($manifest.build.entry_sha256 -cne (Get-AcceptanceHash (Join-Path $runtime 'AudioFileForPhone.ps1')) -or
        $manifest.build.helper_sha256 -cne (Get-AcceptanceHash (Join-Path $runtime 'AudioFileForPhone.Helpers.ps1'))) { throw 'Production manifest package identity mismatch.' }
    $supported = @($SourceBefore | Where-Object { $null -eq $_.PSObject.Properties['supported'] -or $_.supported })
    if ($supported.Count -le 0 -or @($manifest.records).Count -ne $supported.Count -or
        $manifest.totals.supported -ne $supported.Count -or $manifest.totals.converted -ne $supported.Count -or
        $manifest.totals.failed -ne 0 -or $manifest.totals.not_completed -ne 0) { throw 'The production batch did not convert every supported source.' }
    $sourceMap = @{}; $outputMap = @{}; $media = @()
    foreach ($row in $supported) {
        $key = ([string]$row.relative_path).Replace('/', '\')
        if ($sourceMap.ContainsKey($key)) { throw 'Duplicate source identity in acceptance inventory.' }
        $sourceMap[$key] = $row
    }
    # Load only the hash-verified packaged shared native runner. No alternative resolver.
    . (Join-Path $runtime 'AudioFileForPhone.Helpers.ps1')
    foreach ($record in @($manifest.records)) {
        $key = ([string]$record.source_relative_path).Replace('/', '\')
        if (-not $sourceMap.ContainsKey($key) -or $record.status -cne 'Converted' -or $record.code -cne 'Success') { throw 'Production record/source correlation failed.' }
        $sourceRow = $sourceMap[$key]; $sourceMap.Remove($key)
        $inputPath = Get-AcceptanceMemberPath $source $key
        if ((Get-AcceptanceHash $inputPath) -cne [string]$sourceRow.sha256) { throw 'A selected source changed.' }
        $outputPath = Get-AcceptanceMemberPath $run ([string]$record.output_relative_path)
        if ($outputMap.ContainsKey($outputPath)) { throw 'Production records reuse an output.' }
        $outputMap[$outputPath] = $true
        $null = Assert-AcceptanceLocalPath $outputPath -MustExist
        $plan = [pscustomobject]@{
            Status = 'Success'; BitrateKbps = 64
            OutputSampleRate = [int]$record.audio_plan.output_sample_rate; OutputChannels = [int]$record.audio_plan.output_channels
        }
        $hasCover = -not [string]::IsNullOrWhiteSpace([string]$manifest.policies.metadata.cover_path)
        $validated = Get-AudioOutputValidation -Path $outputPath -SourceDurationSeconds $record.input_duration_seconds -BitrateKbps 64 -HasCover:$hasCover -FfprobePath $FfprobePath -FfmpegPath $FfmpegPath -OutputPlan $plan
        if ($validated.Status -cne 'Success' -or -not $validated.ProcessReleased -or
            -not $validated.ProbeResult.PipeDrainCompleted -or -not $validated.DecodeResult.PipeDrainCompleted -or
            $validated.DecodeResult.TimeoutMilliseconds -ne 0) { throw 'Independent complete media verification failed or release is unproved.' }
        $media += [pscustomobject]@{
            sequence = $media.Count + 1; format = 'mp3'; bitrate_bps = [long]$validated.Bitrate
            sample_rate = [int]$validated.SampleRate; channels = [int]$validated.Channels
            input_duration_seconds = [double]$record.input_duration_seconds
            output_duration_seconds = [double]$validated.DurationSeconds; decoded_duration_seconds = [double]$validated.DecodedDurationSeconds
            full_decode = $true
        }
    }
    if ($sourceMap.Count -ne 0) { throw 'The production run left sources uncorrelated.' }
    $runPending = New-Object 'Collections.Generic.Stack[string]'; $runPending.Push($run)
    $outputMediaCount = 0
    while ($runPending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $runPending.Pop() -Force -ErrorAction Stop)) {
            $null = Assert-AcceptanceLocalPath $item.FullName -MustExist
            if ($item.PSIsContainer) { $runPending.Push($item.FullName) }
            elseif ($item.Name -match '\.partial$') { throw 'A completed run retains a partial file.' }
            elseif ($item.Extension -ieq '.mp3') {
                if (-not $outputMap.ContainsKey($item.FullName)) { throw 'An output media file has no production record.' }
                $outputMediaCount++
            }
        }
    }
    if ($outputMediaCount -ne $supported.Count) { throw 'Actual output media count does not match the exact source inventory.' }
    $includeUnsupported = @($SourceBefore | Where-Object { $null -ne $_.PSObject.Properties['supported'] -and -not $_.supported }).Count -gt 0
    if (-not (Test-AcceptanceSourceInventory -Root $source -Before $SourceBefore -IncludeUnsupported:$includeUnsupported)) { throw 'The source inventory changed during acceptance.' }
    return [pscustomobject]@{
        run_id = [IO.Path]::GetFileName($run); manifest_sha256 = Get-AcceptanceHash $manifestPath; outcome_source = 'exact_production_manifest'
        captured_exit_code = $CapturedExitCode; manifest_exit_code = [int]$manifest.run.exit_code
        input_count = $supported.Count; converted_count = [int]$manifest.totals.converted
        failed_count = [int]$manifest.totals.failed; unprocessed_count = [int]$manifest.totals.not_completed
        source_unchanged = $true; media_validated = $true; full_decode = $true; media = $media
        tool_origin = [string]$manifest.tools.selection_origin
    }
}
