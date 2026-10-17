# Functions only. Loaded exclusively by the separately invoked setup flow.

function Assert-AudioManagedRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('/') -or $Path.Contains('\') -or $Path.Length -gt 220) {
        throw "Unsafe managed archive path '$Path'."
    }
    foreach ($component in $Path.Split('/')) {
        if ([string]::IsNullOrEmpty($component) -or $component -eq '.' -or $component -eq '..' -or
            $component -match '[\x00-\x1f<>:"|?*]' -or $component -match '[. ]$' -or
            $component -match '^(?i:CON|PRN|AUX|NUL|CLOCK\$|CONIN\$|CONOUT\$|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3])(?:\.|$)') {
            throw "Unsafe managed archive component in '$Path'."
        }
    }
}

function Assert-AudioManagedDownloadManifest {
    param([Parameter(Mandatory = $true)][object]$Manifest)
    foreach ($name in @('provider', 'build', 'url', 'sha256', 'archive_root', 'bin_relative_path', 'source_url', 'license_url')) {
        $value = $Manifest.$name
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value) -or $value.Length -gt 2048 -or $value -match '[\x00-\x1f]') {
            throw "Invalid pinned download manifest field '$name'."
        }
    }
    if (($Manifest.schema_version -isnot [int] -and $Manifest.schema_version -isnot [long]) -or
        $Manifest.schema_version -ne 1 -or $Manifest.sha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid pinned download manifest schema or SHA256.' }
    foreach ($name in @('archive_size_bytes', 'max_download_bytes', 'max_expanded_bytes', 'max_entries', 'connect_timeout_seconds', 'download_timeout_seconds')) {
        $value = $Manifest.$name
        if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 1) { throw "Invalid positive integral manifest bound '$name'." }
    }
    if ($Manifest.archive_size_bytes -gt $Manifest.max_download_bytes -or $Manifest.max_download_bytes -gt 1073741824 -or
        $Manifest.max_expanded_bytes -gt 4294967296 -or $Manifest.max_entries -gt 20000 -or
        $Manifest.connect_timeout_seconds -gt 120 -or $Manifest.download_timeout_seconds -gt 1800 -or
        $Manifest.connect_timeout_seconds -gt $Manifest.download_timeout_seconds) { throw 'Pinned download manifest bounds exceed setup policy.' }
    $hosts = @($Manifest.allowed_redirect_hosts)
    if ($hosts.Count -eq 0 -or $hosts.Count -gt 16) { throw 'The pinned manifest must declare scoped HTTPS redirect hosts.' }
    foreach ($hostName in $hosts) {
        if ($hostName -isnot [string] -or $hostName -notmatch '^[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?$' -or
            [Uri]::CheckHostName($hostName) -ne [UriHostNameType]::Dns) { throw 'Invalid pinned HTTPS redirect host.' }
    }
    foreach ($name in @('url', 'source_url', 'license_url')) {
        $uri = $null
        if (-not [Uri]::TryCreate($Manifest.$name, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -cne 'https' -or
            $uri.UserInfo -or -not $uri.IsDefaultPort -or $uri.Fragment) { throw "Manifest '$name' must be an absolute public HTTPS URL." }
        if ($name -eq 'url' -and $hosts -inotcontains $uri.DnsSafeHost) { throw 'The pinned download host is outside its allowed host scope.' }
    }
    Assert-AudioManagedRelativePath -Path $Manifest.archive_root
    if ($Manifest.archive_root.Contains('/')) { throw 'archive_root must name one exact vendor directory.' }
    Assert-AudioManagedRelativePath -Path $Manifest.bin_relative_path
    $notices = @($Manifest.notices)
    if ($notices.Count -eq 0 -or $notices.Count -gt 32) { throw 'The pinned manifest must declare retained vendor notices.' }
    foreach ($notice in $notices) {
        if ($notice -isnot [string]) { throw 'Vendor notices must be literal relative paths.' }
        Assert-AudioManagedRelativePath -Path $notice
    }
}

function Get-AudioManagedDownloadManifest {
    param([string]$ManifestPath)
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        $sourceDirectory = Split-Path -Parent (Get-Command Get-AudioManagedDownloadManifest).ScriptBlock.File
        $ManifestPath = [IO.Path]::Combine($sourceDirectory, 'tools', 'ffmpeg-download.json')
    }
    $path = Get-AudioSelectionPath -Path $ManifestPath
    Assert-AudioNoReparseAncestor -Path $path
    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -gt 65536) { throw 'Pinned download manifest must be a regular JSON file of at most 64 KiB.' }
    $json = [IO.File]::ReadAllText($path, (New-Object Text.UTF8Encoding($false, $true)))
    Assert-AudioConfigJsonNames -Json $json
    $manifest = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    Assert-AudioManagedDownloadManifest -Manifest $manifest
    return $manifest
}

function Wait-AudioManagedTask {
    param([Parameter(Mandatory = $true)][object]$Task,
          [Parameter(Mandatory = $true)][Diagnostics.Stopwatch]$Timer,
          [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
          [AllowNull()][object]$CancellationState,
          [AllowNull()][object]$CancellationSource,
          [string]$Operation = 'Managed download')
    try {
        while (-not $Task.IsCompleted) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            if ($Timer.ElapsedMilliseconds -ge ([long]$TimeoutSeconds * 1000)) { throw (New-Object TimeoutException("$Operation exceeded its bounded deadline.")) }
            Start-Sleep -Milliseconds 50
        }
        Assert-AudioNotCancelled -Cancellation $CancellationState
        if ($Timer.ElapsedMilliseconds -ge ([long]$TimeoutSeconds * 1000)) { throw (New-Object TimeoutException("$Operation exceeded its bounded deadline.")) }
        return $Task.GetAwaiter().GetResult()
    }
    catch {
        if ($null -ne $CancellationSource) { $CancellationSource.Cancel() }
        throw
    }
}

function Copy-AudioManagedResponseStream {
    param([Parameter(Mandatory = $true)][IO.Stream]$Stream,
          [Parameter(Mandatory = $true)][IO.Stream]$DestinationStream,
          [Parameter(Mandatory = $true)][object]$Manifest,
          [Parameter(Mandatory = $true)][Diagnostics.Stopwatch]$Timer,
          [AllowNull()][object]$CancellationState,
          [AllowNull()][object]$CancellationSource)
    $buffer = New-Object byte[] 65536
    $total = [long]0
    while ($true) {
        Assert-AudioNotCancelled -Cancellation $CancellationState
        $token = [Threading.CancellationToken]::None
        if ($null -ne $CancellationSource) { $token = $CancellationSource.Token }
        $task = $Stream.ReadAsync($buffer, 0, $buffer.Length, $token)
        $read = Wait-AudioManagedTask -Task $task -Timer $Timer -TimeoutSeconds $Manifest.download_timeout_seconds -CancellationState $CancellationState -CancellationSource $CancellationSource -Operation 'Managed download body'
        if ($read -eq 0) { break }
        $total += $read
        if ($total -gt $Manifest.max_download_bytes -or $total -gt $Manifest.archive_size_bytes) { throw 'Managed download exceeds its pinned byte bound.' }
        $DestinationStream.Write($buffer, 0, $read)
    }
    if ($total -ne $Manifest.archive_size_bytes) { throw "Managed download size mismatch: expected $($Manifest.archive_size_bytes), received $total bytes." }
    return $total
}

function Invoke-AudioManagedDownload {
    param([Parameter(Mandatory = $true)][object]$Manifest,
          [Parameter(Mandatory = $true)][string]$DestinationPath,
          [AllowNull()][object]$CancellationState)
    Assert-AudioManagedDownloadManifest -Manifest $Manifest
    Assert-AudioNotCancelled -Cancellation $CancellationState
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    # Normal platform certificate validation is deliberately retained.
    $client = New-Object Net.Http.HttpClient($handler)
    $client.Timeout = [Threading.Timeout]::InfiniteTimeSpan
    $client.DefaultRequestHeaders.UserAgent.ParseAdd('AudioFileForPhone-managed-setup/1')
    $cancel = New-Object Threading.CancellationTokenSource
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $response = $null; $stream = $null; $output = $null
    try {
        $uri = [Uri]$Manifest.url
        for ($redirects = 0; $redirects -le 5; $redirects++) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            if ($uri.Scheme -cne 'https' -or $uri.UserInfo -or -not $uri.IsDefaultPort -or $uri.Fragment -or
                @($Manifest.allowed_redirect_hosts) -inotcontains $uri.DnsSafeHost) { throw 'Managed download redirect is outside the pinned HTTPS host scope.' }
            $headerTimer = [Diagnostics.Stopwatch]::StartNew()
            $request = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancel.Token)
            # Each connection/header wait is bounded, including redirects; the
            # overall transfer deadline also applies while waiting for headers.
            while (-not $request.IsCompleted) {
                Assert-AudioNotCancelled -Cancellation $CancellationState
                if ($headerTimer.ElapsedMilliseconds -ge ([long]$Manifest.connect_timeout_seconds * 1000) -or
                    $timer.ElapsedMilliseconds -ge ([long]$Manifest.download_timeout_seconds * 1000)) { throw (New-Object TimeoutException('Managed download connection/header deadline expired.')) }
                Start-Sleep -Milliseconds 50
            }
            $response = Wait-AudioManagedTask -Task $request -Timer $timer -TimeoutSeconds $Manifest.download_timeout_seconds -CancellationState $CancellationState -CancellationSource $cancel -Operation 'Managed download headers'
            $status = [int]$response.StatusCode
            if ($status -in @(301, 302, 303, 307, 308)) {
                if ($redirects -eq 5 -or $null -eq $response.Headers.Location) { throw 'Managed download exceeded its redirect bound or omitted Location.' }
                $uri = New-Object Uri($uri, $response.Headers.Location)
                $response.Dispose(); $response = $null
                continue
            }
            if ($status -ne 200) { throw "Managed download HTTP failure: $status." }
            if ($response.Content.Headers.ContentEncoding.Count -gt 0) { throw 'Encoded HTTP bodies are outside the pinned archive transfer contract.' }
            $length = $response.Content.Headers.ContentLength
            if ($null -ne $length -and $length -ne $Manifest.archive_size_bytes) { throw 'Managed download Content-Length differs from the exact pinned artifact size.' }
            $stream = Wait-AudioManagedTask -Task ($response.Content.ReadAsStreamAsync()) -Timer $timer -TimeoutSeconds $Manifest.download_timeout_seconds -CancellationState $CancellationState -CancellationSource $cancel -Operation 'Managed download stream'
            $output = New-Object IO.FileStream($DestinationPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $count = Copy-AudioManagedResponseStream -Stream $stream -DestinationStream $output -Manifest $Manifest -Timer $timer -CancellationState $CancellationState -CancellationSource $cancel
            $output.Flush($true)
            return [pscustomobject]@{ FinalUrl = $uri.AbsoluteUri; Bytes = $count }
        }
        throw 'Managed download did not obtain the pinned artifact.'
    }
    finally {
        $cancel.Cancel()
        if ($null -ne $output) { $output.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
        if ($null -ne $response) { $response.Dispose() }
        $client.Dispose(); $handler.Dispose(); $cancel.Dispose()
    }
}

function Initialize-AudioManagedZipInterop {
    if ('AudioFileForPhone.ManagedZipReadStream' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
namespace AudioFileForPhone {
    // Exposes only one previously bounded compressed payload. DeflateStream must
    // never read into the next local header or the central directory.
    public sealed class ManagedZipReadStream : Stream {
        private readonly Stream source;
        private readonly long start;
        private readonly long length;
        private long position;
        public ManagedZipReadStream(Stream source, long start, long length) {
            if (source == null || !source.CanRead || !source.CanSeek || start < 0 || length < 0 || start > source.Length - length)
                throw new InvalidDataException("Invalid bounded ZIP payload.");
            this.source = source; this.start = start; this.length = length;
        }
        public override bool CanRead { get { return true; } }
        public override bool CanSeek { get { return false; } }
        public override bool CanWrite { get { return false; } }
        public override long Length { get { return length; } }
        public override long Position { get { return position; } set { throw new NotSupportedException(); } }
        public override int Read(byte[] buffer, int offset, int count) {
            if (buffer == null || offset < 0 || count < 0 || offset > buffer.Length - count) throw new ArgumentOutOfRangeException();
            if (position >= length) return 0;
            source.Position = start + position;
            int read = source.Read(buffer, offset, (int)Math.Min((long)count, length - position));
            if (read == 0 && position != length) throw new EndOfStreamException("Bounded ZIP payload ended early.");
            position += read;
            return read;
        }
        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) { throw new NotSupportedException(); }
        public override void SetLength(long value) { throw new NotSupportedException(); }
        public override void Write(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
    }
    public sealed class ManagedZipCrc32 {
        private static readonly uint[] table = CreateTable();
        private uint crc = 0xffffffff;
        private static uint[] CreateTable() {
            uint[] result = new uint[256];
            for (uint index = 0; index < 256; index++) {
                uint value = index;
                for (int bit = 0; bit < 8; bit++) value = (value & 1) != 0 ? 0xedb88320 ^ (value >> 1) : value >> 1;
                result[index] = value;
            }
            return result;
        }
        public void Append(byte[] bytes, int count) {
            if (bytes == null || count < 0 || count > bytes.Length) throw new ArgumentOutOfRangeException();
            for (int index = 0; index < count; index++) crc = table[(crc ^ bytes[index]) & 255] ^ (crc >> 8);
        }
        public uint Value { get { return ~crc; } }
    }
}
'@ -ErrorAction Stop
}

function Assert-AudioManagedZipDirectory {
    param([Parameter(Mandatory = $true)][IO.Stream]$Stream,
          [Parameter(Mandatory = $true)][object]$Manifest,
          [AllowNull()][object]$CancellationState)
    # Inspect bounded fixed ZIP headers before ZipArchive can materialize entry
    # objects. This reviewed small vendor ZIP needs neither ZIP64 nor multivolume
    # support. A forged EOCD count cannot hide a huge central directory.
    $reader = New-Object IO.BinaryReader($Stream, [Text.Encoding]::UTF8, $true)
    try {
        if ($Stream.Length -lt 22) { throw 'Archive has no complete ZIP end record.' }
        $tailLength = [int][Math]::Min([long]65557, $Stream.Length)
        $tailStart = $Stream.Length - $tailLength
        $Stream.Position = $tailStart
        $tail = $reader.ReadBytes($tailLength)
        if ($tail.Length -ne $tailLength) { throw 'Archive ended during bounded ZIP directory inspection.' }
        $endIndex = -1
        for ($index = $tail.Length - 22; $index -ge 0; $index--) {
            if ([BitConverter]::ToUInt32($tail, $index) -eq 0x06054b50 -and
                $index + 22 + [BitConverter]::ToUInt16($tail, $index + 20) -eq $tail.Length) {
                $endIndex = $index; break
            }
        }
        if ($endIndex -lt 0) { throw 'Archive has no bounded terminal ZIP directory record.' }
        $disk = [BitConverter]::ToUInt16($tail, $endIndex + 4)
        $directoryDisk = [BitConverter]::ToUInt16($tail, $endIndex + 6)
        $diskEntries = [BitConverter]::ToUInt16($tail, $endIndex + 8)
        $declaredEntries = [BitConverter]::ToUInt16($tail, $endIndex + 10)
        $directoryBytes = [BitConverter]::ToUInt32($tail, $endIndex + 12)
        $directoryOffset = [BitConverter]::ToUInt32($tail, $endIndex + 16)
        if ($disk -ne 0 -or $directoryDisk -ne 0 -or $diskEntries -ne $declaredEntries -or
            $declaredEntries -eq 65535 -or $directoryBytes -eq [uint32]::MaxValue -or $directoryOffset -eq [uint32]::MaxValue) {
            throw 'ZIP64 or multivolume managed archives are not supported.'
        }
        if ($declaredEntries -eq 0 -or $declaredEntries -gt $Manifest.max_entries) { throw 'Archive entry count exceeds its pinned bound or is empty.' }
        $directoryEnd = [long]$directoryOffset + [long]$directoryBytes
        if ($directoryEnd -ne $tailStart + $endIndex -or $directoryOffset -gt $Stream.Length -or
            $directoryBytes -lt ([long]$declaredEntries * 46)) { throw 'Archive central directory bounds are inconsistent.' }
        $Stream.Position = $directoryOffset
        $actualEntries = 0
        $records = New-Object 'Collections.Generic.List[object]'
        while ($Stream.Position -lt $directoryEnd) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            if ($actualEntries -ge $Manifest.max_entries -or $directoryEnd - $Stream.Position -lt 46) { throw 'Archive actual central entry count or header exceeds its bound.' }
            $header = $reader.ReadBytes(46)
            if ($header.Length -ne 46 -or [BitConverter]::ToUInt32($header, 0) -ne 0x02014b50) { throw 'Archive has an invalid central directory header.' }
            $flags = [BitConverter]::ToUInt16($header, 8)
            $method = [BitConverter]::ToUInt16($header, 10)
            $crc = [BitConverter]::ToUInt32($header, 16)
            $compressedBytes = [BitConverter]::ToUInt32($header, 20)
            $expandedBytes = [BitConverter]::ToUInt32($header, 24)
            $nameBytes = [BitConverter]::ToUInt16($header, 28)
            $extraBytes = [BitConverter]::ToUInt16($header, 30)
            $commentBytes = [BitConverter]::ToUInt16($header, 32)
            $startDisk = [BitConverter]::ToUInt16($header, 34)
            $localOffset = [BitConverter]::ToUInt32($header, 42)
            if (($flags -band 0xf7f9) -ne 0 -or $compressedBytes -eq [uint32]::MaxValue -or
                $expandedBytes -eq [uint32]::MaxValue -or $localOffset -eq [uint32]::MaxValue -or $startDisk -ne 0) {
                throw 'Encrypted, data-descriptor, ZIP64, multivolume or unsupported-flag managed archive entries are refused.'
            }
            $next = $Stream.Position + [long]$nameBytes + [long]$extraBytes + [long]$commentBytes
            if ($nameBytes -eq 0 -or $next -gt $directoryEnd -or $localOffset -ge $directoryOffset) { throw 'Archive central entry lengths or local offset are inconsistent.' }
            if ($method -ne 0 -and $method -ne 8) { throw 'Only stored/deflate members of the reviewed vendor ZIP are supported.' }
            if ($method -eq 0 -and $compressedBytes -ne $expandedBytes) { throw 'Stored archive size metadata is inconsistent.' }
            $centralName = $reader.ReadBytes($nameBytes)
            $Stream.Position = $localOffset
            if ($directoryOffset - $Stream.Position -lt 30) { throw 'Archive local header exceeds its data boundary.' }
            $local = $reader.ReadBytes(30)
            if ($local.Length -ne 30 -or [BitConverter]::ToUInt32($local, 0) -ne 0x04034b50 -or
                [BitConverter]::ToUInt16($local, 6) -ne $flags -or [BitConverter]::ToUInt16($local, 8) -ne $method -or
                [BitConverter]::ToUInt32($local, 14) -ne $crc -or [BitConverter]::ToUInt32($local, 18) -ne $compressedBytes -or
                [BitConverter]::ToUInt32($local, 22) -ne $expandedBytes -or [BitConverter]::ToUInt16($local, 26) -ne $nameBytes) {
                throw 'Archive local and central metadata differ in names, flags, compression, CRC or size.'
            }
            $localExtraBytes = [BitConverter]::ToUInt16($local, 28)
            $dataOffset = [long]$localOffset + 30 + [long]$nameBytes + [long]$localExtraBytes
            $dataEnd = $dataOffset + [long]$compressedBytes
            if ($dataEnd -gt $directoryOffset) { throw 'Archive compressed data exceeds its local data boundary.' }
            $localName = $reader.ReadBytes($nameBytes)
            if ([Convert]::ToBase64String($localName) -cne [Convert]::ToBase64String($centralName)) { throw 'Archive local and central names differ.' }
            foreach ($record in $records) {
                if ([long]$localOffset -lt $record.DataEnd -and $dataEnd -gt $record.LocalOffset) { throw 'Archive local payload/header ranges overlap.' }
            }
            $records.Add([pscustomobject]@{ LocalOffset = [long]$localOffset; DataOffset = $dataOffset; DataEnd = $dataEnd
                CompressedBytes = [long]$compressedBytes; ExpandedBytes = [long]$expandedBytes; Crc32 = $crc; Method = [int]$method })
            $Stream.Position = $next
            $actualEntries++
        }
        if ($actualEntries -ne $declaredEntries) { throw 'Archive declared and actual central entry counts differ.' }
        return [pscustomobject]@{ Count = $actualEntries; Records = @($records.ToArray()) }
    }
    finally { $reader.Dispose(); $Stream.Position = 0 }
}

function Expand-AudioManagedArchive {
    param([Parameter(Mandatory = $true)][string]$ArchivePath,
          [Parameter(Mandatory = $true)][string]$DestinationPath,
          [Parameter(Mandatory = $true)][object]$Manifest,
          [AllowNull()][object]$CancellationState)
    Assert-AudioManagedDownloadManifest -Manifest $Manifest
    Assert-AudioNotCancelled -Cancellation $CancellationState
    Assert-AudioNoReparseAncestor -Path $ArchivePath
    Assert-AudioNoReparseAncestor -Path $DestinationPath
    $destination = Get-AudioSelectionPath -Path $DestinationPath
    if (Test-Path -LiteralPath $destination) {
        if (-not [IO.Directory]::Exists($destination) -or [IO.Directory]::GetFileSystemEntries($destination).Length -ne 0) { throw 'Managed extraction requires an empty owned destination.' }
    }
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    $file = $null; $zip = $null; $sha = $null
    try {
        # The same read guard covers size/hash and ZIP consumption. Another writer
        # cannot replace the verified bytes between integrity check and extraction.
        $file = New-Object IO.FileStream($ArchivePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($file.Length -ne $Manifest.archive_size_bytes -or $file.Length -gt $Manifest.max_download_bytes) { throw 'Pinned archive size mismatch.' }
        $sha = [Security.Cryptography.SHA256]::Create()
        $hash = [BitConverter]::ToString($sha.ComputeHash($file)).Replace('-', '')
        if ($hash -ine $Manifest.sha256) { throw 'Pinned archive SHA256 mismatch. No archive entries were opened or executed.' }
        Assert-AudioNotCancelled -Cancellation $CancellationState
        $file.Position = 0
        $directoryInfo = Assert-AudioManagedZipDirectory -Stream $file -Manifest $Manifest -CancellationState $CancellationState
        $zip = New-Object IO.Compression.ZipArchive($file, [IO.Compression.ZipArchiveMode]::Read, $true)
        if ($zip.Entries.Count -ne $directoryInfo.Count -or $zip.Entries.Count -gt $Manifest.max_entries) { throw 'Archive parsed entry count differs from its bounded ZIP directory.' }
        $names = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $kinds = New-Object 'Collections.Generic.Dictionary[string,bool]' ([StringComparer]::OrdinalIgnoreCase)
        $spellings = New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
        $plans = New-Object 'Collections.Generic.List[object]'
        $expanded = [long]0
        $recordIndex = 0
        foreach ($entry in $zip.Entries) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            $record = $directoryInfo.Records[$recordIndex]; $recordIndex++
            if ($entry.Length -ne $record.ExpandedBytes -or $entry.CompressedLength -ne $record.CompressedBytes) { throw 'Archive entry size differs from independently read central metadata.' }
            $raw = $entry.FullName
            $directory = $raw.EndsWith('/')
            $name = if ($directory) { $raw.Substring(0, $raw.Length - 1) } else { $raw }
            Assert-AudioManagedRelativePath -Path $name
            if ($directory -and ($record.Method -ne 0 -or $record.CompressedBytes -ne 0 -or $record.ExpandedBytes -ne 0 -or $record.Crc32 -ne 0)) {
                throw 'Archive directory entries must be empty stored records without payload or CRC.'
            }
            if (-not $name.Equals($Manifest.archive_root, [StringComparison]::Ordinal) -and
                -not $name.StartsWith($Manifest.archive_root + '/', [StringComparison]::Ordinal)) { throw 'Archive entry is outside the exact pinned vendor root.' }
            if (-not $names.Add($name)) { throw "Duplicate or case-colliding archive entry '$name'." }
            # Low DOS reparse bit and upper Unix type bits cover junction/symlink
            # encodings, including ZIPs produced outside Windows.
            $attributes = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$entry.ExternalAttributes), 0)
            $unixType = ($attributes -shr 16) -band 0xf000
            if (($attributes -band 0x400) -ne 0 -or ($unixType -ne 0 -and $unixType -ne 0x8000 -and $unixType -ne 0x4000) -or
                ($directory -and $unixType -eq 0x8000) -or (-not $directory -and $unixType -eq 0x4000)) { throw "Reparse/symlink or special archive entry '$name' is refused." }
            if ($entry.Length -lt 0 -or ($directory -and $entry.Length -ne 0)) { throw 'Invalid archive expanded size.' }
            $expanded += $entry.Length
            if ($expanded -gt $Manifest.max_expanded_bytes) { throw 'Archive expanded size exceeds its pinned bound.' }
            $components = $name.Split('/')
            $current = ''
            for ($index = 0; $index -lt $components.Length; $index++) {
                $current = if ($current) { $current + '/' + $components[$index] } else { $components[$index] }
                $isDirectory = $index -lt $components.Length - 1 -or $directory
                if ($kinds.ContainsKey($current)) {
                    if ($kinds[$current] -ne $isDirectory) { throw "Archive file/directory collision '$current'." }
                    if ($spellings[$current] -cne $current) { throw "Case-colliding archive path component '$current'." }
                }
                else { $kinds.Add($current, $isDirectory); $spellings.Add($current, $current) }
            }
            $target = [IO.Path]::GetFullPath([IO.Path]::Combine($destination, $name.Replace('/', '\')))
            if (-not $target.StartsWith($destination.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive canonical containment check failed.' }
            if ($target.Length -gt 245) { throw 'Managed archive path exceeds the supported Windows path budget; choose a shorter -ManagedRoot.' }
            $plans.Add([pscustomobject]@{ Entry = $entry; Record = $record; Path = $target; Directory = $directory })
        }
        $vendorRoot = $Manifest.archive_root
        foreach ($required in @(($Manifest.bin_relative_path + '/ffmpeg.exe'), ($Manifest.bin_relative_path + '/ffprobe.exe')) + @($Manifest.notices)) {
            $name = $vendorRoot + '/' + $required
            if (-not $kinds.ContainsKey($name) -or $kinds[$name]) { throw "Pinned vendor archive omits required regular file '$name'." }
        }
        # All metadata preflight completes before the first extraction write.
        [IO.Directory]::CreateDirectory($destination) | Out-Null
        Initialize-AudioManagedZipInterop
        $buffer = New-Object byte[] 65536
        $written = [long]0
        foreach ($plan in $plans) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            Assert-AudioNoReparseAncestor -Path $plan.Path
            if ($plan.Directory) { [IO.Directory]::CreateDirectory($plan.Path) | Out-Null; continue }
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($plan.Path)) | Out-Null
            Assert-AudioNoReparseAncestor -Path $plan.Path
            $entryInput = $null; $boundedInput = $null; $output = $null
            try {
                # ZipArchive.Open can truncate a forged deflate member to its
                # declared length on some runtimes. Drain raw bounded compressed
                # bytes ourselves and check real emitted length plus CRC instead.
                $boundedInput = New-Object AudioFileForPhone.ManagedZipReadStream($file, $plan.Record.DataOffset, $plan.Record.CompressedBytes)
                if ($plan.Record.Method -eq 8) { $entryInput = New-Object IO.Compression.DeflateStream($boundedInput, [IO.Compression.CompressionMode]::Decompress, $true) }
                else { $entryInput = $boundedInput }
                $crc = New-Object AudioFileForPhone.ManagedZipCrc32
                $output = New-Object IO.FileStream($plan.Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                $entryWritten = [long]0
                while (($read = $entryInput.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    Assert-AudioNotCancelled -Cancellation $CancellationState
                    $entryWritten += $read; $written += $read
                    if ($entryWritten -gt $plan.Entry.Length -or $written -gt $Manifest.max_expanded_bytes) { throw 'Actual archive expansion exceeds its verified metadata bound.' }
                    $crc.Append($buffer, $read)
                    $output.Write($buffer, 0, $read)
                }
                if ($entryWritten -ne $plan.Entry.Length) { throw 'Archive entry ended before its declared expanded size.' }
                if ($crc.Value -ne $plan.Record.Crc32 -or $boundedInput.Position -ne $plan.Record.CompressedBytes) { throw 'Archive CRC or actual compressed consumption differs from its verified metadata.' }
                $output.Flush($true)
            }
            finally { if ($null -ne $entryInput) { $entryInput.Dispose() }; if ($null -ne $boundedInput) { $boundedInput.Dispose() }; if ($null -ne $output) { $output.Dispose() } }
        }
        return [pscustomobject]@{ Root = [IO.Path]::Combine($destination, $Manifest.archive_root); Entries = $plans.Count; ExpandedBytes = $written; SHA256 = $hash }
    }
    finally { if ($null -ne $zip) { $zip.Dispose() }; if ($null -ne $file) { $file.Dispose() }; if ($null -ne $sha) { $sha.Dispose() } }
}

function Remove-AudioManagedOwnedStage {
    param([Parameter(Mandatory = $true)][string]$Path,
          [Parameter(Mandatory = $true)][string]$ManagedRoot,
          [Parameter(Mandatory = $true)][string]$OwnerToken)
    if (-not [IO.Directory]::Exists($Path)) { return }
    $full = Get-AudioSelectionPath -Path $Path
    $root = Get-AudioSelectionPath -Path $ManagedRoot
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetDirectoryName($full), $root) -or
        [IO.Path]::GetFileName($full) -cne ('.AudioFileForPhone-staging-' + $OwnerToken)) { throw 'Refusing cleanup outside the exact owned managed staging directory.' }
    Assert-AudioNoReparseAncestor -Path $full
    $marker = [IO.Path]::Combine($full, '.owner')
    Assert-AudioNoReparseAncestor -Path $marker
    if (-not [IO.File]::Exists($marker) -or [IO.File]::ReadAllText($marker) -cne $OwnerToken) { throw 'Refusing cleanup without the matching managed staging ownership marker.' }
    $directories = New-Object 'Collections.Generic.List[string]'
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($full)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        Assert-AudioNoReparseAncestor -Path $directory
        $directories.Add($directory)
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing managed cleanup of a reparse entry.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    # No recursive delete: recheck each literal member and delete only regular
    # files, then empty directories. Never follow an inserted link.
    for ($index = $directories.Count - 1; $index -ge 0; $index--) {
        $directory = $directories[$index]
        Assert-AudioNoReparseAncestor -Path $directory
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            Assert-AudioNoReparseAncestor -Path $item.FullName
            if ($item.PSIsContainer) { throw 'Managed stage changed during cleanup; preserving remaining content.' }
            [IO.File]::Delete($item.FullName)
        }
        [IO.Directory]::Delete($directory, $false)
    }
}

function Invoke-AudioManagedToolInstall {
    param([Parameter(Mandatory = $true)][object]$Manifest,
          [string]$ConfigPath,
          [switch]$Consent,
          [AllowNull()][object]$CancellationState = (Get-AudioCancellationContext),
          [string]$ManagedRoot)
    # No network, directory creation, archive processing or executable start can
    # precede affirmative consent, including unattended callers.
    if (-not $Consent) { throw 'Managed FFmpeg download requires affirmative -Consent. Manual/existing-tool setup remains available.' }
    Assert-AudioManagedDownloadManifest -Manifest $Manifest
    Assert-AudioNotCancelled -Cancellation $CancellationState
    $configFile = Get-AudioConfigPath -ConfigPath $ConfigPath
    if ([string]::IsNullOrWhiteSpace($ManagedRoot)) { $ManagedRoot = [IO.Path]::Combine([IO.Path]::GetDirectoryName($configFile), 'managed') }
    $root = Get-AudioSelectionPath -Path $ManagedRoot
    Assert-AudioNoReparseAncestor -Path $root
    [IO.Directory]::CreateDirectory($root) | Out-Null
    Assert-AudioNoReparseAncestor -Path $root
    $token = [guid]::NewGuid().ToString('N')
    $stage = [IO.Path]::Combine($root, '.AudioFileForPhone-staging-' + $token)
    $created = $false
    $guards = New-Object 'Collections.Generic.List[IDisposable]'
    try {
        Initialize-AudioDirectoryInterop
        if (-not [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($stage, [IntPtr]::Zero)) { throw 'Could not reserve an exclusive managed staging directory.' }
        $created = $true
        [IO.File]::WriteAllText([IO.Path]::Combine($stage, '.owner'), $token, (New-Object Text.UTF8Encoding($false)))
        $archive = [IO.Path]::Combine($stage, 'vendor.download.partial')
        $transfer = Invoke-AudioManagedDownload -Manifest $Manifest -DestinationPath $archive -CancellationState $CancellationState
        Assert-AudioNotCancelled -Cancellation $CancellationState
        $unpacked = Expand-AudioManagedArchive -ArchivePath $archive -DestinationPath ([IO.Path]::Combine($stage, 'payload')) -Manifest $Manifest -CancellationState $CancellationState
        $bin = [IO.Path]::Combine($unpacked.Root, $Manifest.bin_relative_path.Replace('/', '\'))
        $pair = Get-AudioToolPairPaths -Directory $bin
        foreach ($path in @($pair.FfmpegPath, $pair.FfprobePath)) {
            $guards.Add((New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)))
        }
        $selection = Resolve-AudioToolSelection -FfmpegDirectory $bin -ConfigPath $configFile -ScriptDirectory $unpacked.Root -Cancellation $CancellationState
        if ($selection.Ffmpeg.Architecture -cne 'x64' -or $selection.Ffprobe.Architecture -cne 'x64') { throw 'The pinned managed archive did not supply the required Windows x64 executable pair.' }
        $hashes = [ordered]@{}
        foreach ($tool in @($selection.Ffmpeg, $selection.Ffprobe)) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            $hash = (Get-FileHash -LiteralPath $tool.Path -Algorithm SHA256 -ErrorAction Stop).Hash
            $hashes[[IO.Path]::GetFileName($tool.Path)] = $hash
        }
        $smoke = [IO.Path]::Combine($stage, 'smoke.partial.mp3')
        $operations = @(
            @{ Path = $selection.Ffmpeg.Path; Name = 'Managed synthetic MP3 smoke encode'; Args = @('-nostdin', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', 'sine=frequency=880:duration=0.2:sample_rate=44100', '-map', '0:a:0', '-c:a', 'libmp3lame', '-b:a', '64k', '-write_xing', '0', '-y', $smoke) },
            @{ Path = $selection.Ffprobe.Path; Name = 'Managed smoke probe'; Args = @('-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=codec_name,bit_rate', '-of', 'json', $smoke) },
            @{ Path = $selection.Ffmpeg.Path; Name = 'Managed smoke full decode'; Args = @('-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-i', $smoke, '-map', '0:a:0', '-f', 'null', '-') }
        )
        foreach ($operation in $operations) {
            $native = Invoke-AudioNativeProcess -ExecutablePath $operation.Path -Arguments $operation.Args -Cancellation $CancellationState -TimeoutMilliseconds 15000 -Operation $operation.Name
            if ($native.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Managed dependency setup was cancelled.')) }
            if ($native.Status -ne 'Completed' -or $native.ExitCode -ne 0 -or -not $native.ProcessReleased -or $native.StdoutTruncated -or $native.StderrTruncated) { throw "$($operation.Name) failed: $($native.Status) $($native.Error)" }
            if ($operation.Name -eq 'Managed smoke probe') {
                $probe = ConvertFrom-Json -InputObject $native.Stdout -ErrorAction Stop
                if (@($probe.streams).Count -ne 1 -or $probe.streams[0].codec_name -cne 'mp3' -or $probe.streams[0].bit_rate -ne '64000') { throw 'Managed smoke probe did not confirm one 64 kbps MP3 stream.' }
            }
        }
        Assert-AudioNotCancelled -Cancellation $CancellationState
        foreach ($notice in @($Manifest.notices)) {
            $noticePath = [IO.Path]::Combine($unpacked.Root, $notice.Replace('/', '\'))
            Assert-AudioNoReparseAncestor -Path $noticePath
            if (-not [IO.File]::Exists($noticePath) -or (Get-Item -LiteralPath $noticePath -Force).Length -eq 0) { throw "Required vendor notice is missing or empty: '$notice'." }
        }
        $provenance = [ordered]@{
            schema_version = 1; manifest = $Manifest; archive_sha256 = $unpacked.SHA256
            archive_entries = $unpacked.Entries; expanded_bytes = $unpacked.ExpandedBytes
            final_download_url = if ($null -ne $transfer) { $transfer.FinalUrl } else { $null }
            tool_sha256 = $hashes; smoke = '64 kbps MP3 encode, probe and full decode passed'
            installed_utc = [DateTime]::UtcNow.ToString('o')
        }
        $provenancePath = [IO.Path]::Combine($unpacked.Root, 'AudioFileForPhone-provenance.json')
        if ([IO.File]::Exists($provenancePath) -or [IO.Directory]::Exists($provenancePath)) { throw 'Vendor archive conflicts with the managed provenance filename.' }
        [IO.File]::WriteAllText($provenancePath, (ConvertTo-Json -InputObject $provenance -Depth 8) + "`r`n", (New-Object Text.UTF8Encoding($false)))
        foreach ($guard in $guards) { $guard.Dispose() }; $guards.Clear()
        Assert-AudioNoReparseAncestor -Path $unpacked.Root
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            if ((Get-FileHash -LiteralPath ([IO.Path]::Combine($bin, $name)) -Algorithm SHA256).Hash -cne $hashes[$name]) { throw 'Managed executable identity changed before publication.' }
        }
        Assert-AudioNotCancelled -Cancellation $CancellationState
        $buildName = [regex]::Replace($Manifest.build, '[^A-Za-z0-9._-]', '-')
        if ($buildName.Length -gt 48) { $buildName = $buildName.Substring(0, 48) }
        $installed = [IO.Path]::Combine($root, $buildName + '-' + $Manifest.sha256.Substring(0, 12).ToLowerInvariant() + '-' + $token)
        # Same-volume unique rename publishes the complete validated directory;
        # no existing managed or user-maintained installation is overwritten.
        $publicationIdentities = @{}
        foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
            $publicationIdentities[$name] = Get-AudioWorkingFileIdentity -Path ([IO.Path]::Combine($bin, $name))
        }
        $publicationTimer = [Diagnostics.Stopwatch]::StartNew()
        $publicationAttempts = 0
        while ($true) {
            Assert-AudioNotCancelled -Cancellation $CancellationState
            Assert-AudioNoReparseAncestor -Path $stage
            Assert-AudioNoReparseAncestor -Path $unpacked.Root
            Assert-AudioNoReparseAncestor -Path $installed
            if ([IO.File]::ReadAllText([IO.Path]::Combine($stage, '.owner')) -cne $token -or
                -not [StringComparer]::OrdinalIgnoreCase.Equals([IO.Path]::GetDirectoryName($stage), $root) -or
                (Test-Path -LiteralPath $installed)) { throw 'Managed publication ownership or unique destination changed; no directory was replaced.' }
            foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
                $toolPath = [IO.Path]::Combine($bin, $name)
                Assert-AudioNoReparseAncestor -Path $toolPath
                if ((Get-AudioWorkingFileIdentity -Path $toolPath) -cne $publicationIdentities[$name] -or
                    (Get-FileHash -LiteralPath $toolPath -Algorithm SHA256).Hash -cne $hashes[$name]) {
                    throw 'Managed executable identity changed during publication; no directory was selected.'
                }
            }
            Assert-AudioNotCancelled -Cancellation $CancellationState
            if ($publicationAttempts -gt 0 -and $publicationTimer.ElapsedMilliseconds -ge 5000) { throw (New-Object TimeoutException('Managed directory publication remained blocked after its 5 second retry deadline. The previous selection was preserved.')) }
            $publicationAttempts++
            try { [IO.Directory]::Move($unpacked.Root, $installed); break }
            catch {
                $cause = $_.Exception
                while ($null -ne $cause.InnerException) { $cause = $cause.InnerException }
                $code = $cause.HResult -band 0xffff
                if (($cause -isnot [IO.IOException] -and $cause -isnot [UnauthorizedAccessException]) -or
                    $code -notin @(5, 32, 33) -or $publicationTimer.ElapsedMilliseconds -ge 5000) { throw }
                if ($publicationAttempts -eq 1) { Write-Host '[INFO] A file handle briefly blocked managed publication; retrying the same unique rename within 5 seconds.' }
                Start-Sleep -Milliseconds 100
            }
            if ($publicationTimer.ElapsedMilliseconds -ge 5000) { throw (New-Object TimeoutException('Managed directory publication remained blocked after its 5 second retry deadline. The previous selection was preserved.')) }
        }
        $installedBin = [IO.Path]::Combine($installed, $Manifest.bin_relative_path.Replace('/', '\'))
        $selection.Directory = $installedBin
        $selection.Ffmpeg.Path = [IO.Path]::Combine($installedBin, 'ffmpeg.exe')
        $selection.Ffprobe.Path = [IO.Path]::Combine($installedBin, 'ffprobe.exe')
        $selection.Origin = 'ManagedSetup'
        foreach ($tool in @($selection.Ffmpeg, $selection.Ffprobe)) { $tool | Add-Member -NotePropertyName SHA256 -NotePropertyValue $hashes[[IO.Path]::GetFileName($tool.Path)] -Force }
        return [pscustomobject]@{ ToolSelection = $selection; InstalledDirectory = $installed; Provenance = [pscustomobject]$provenance; ProvenancePath = [IO.Path]::Combine($installed, 'AudioFileForPhone-provenance.json'); PersistenceSucceeded = $false; PublicationAttempts = $publicationAttempts }
    }
    finally {
        foreach ($guard in $guards) { $guard.Dispose() }
        if ($created) {
            try { Remove-AudioManagedOwnedStage -Path $stage -ManagedRoot $root -OwnerToken $token }
            catch { Write-Warning ('Owned incomplete staging was preserved because safe cleanup could not be proved: ' + $_.Exception.Message) }
        }
    }
}
