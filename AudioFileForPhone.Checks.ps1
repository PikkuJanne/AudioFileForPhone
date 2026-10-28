# Functions-only environment check and explicit synthetic self-test. No downloads.

function Import-AudioDiagnosticRecord {
    param([Parameter(Mandatory = $true)][string]$Path)
    $provider = $null; $drive = $null
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'FileSystem') { throw 'DiagnosticPath must name one regular filesystem report.' }
    $full = [IO.Path]::GetFullPath($full)
    $full = Assert-AudioLocalDiagnosticPath -Path $full
    Assert-AudioDiagnosticStoragePath -Path $full
    $stream = $null
    try {
        # Hold a read handle without write/delete sharing during the bounded read.
        $stream = New-Object IO.FileStream($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        if ($stream.Length -lt 1 -or $stream.Length -gt 65536) { throw 'DiagnosticPath must contain a nonempty report no larger than 64 KiB.' }
        $bytes = New-Object byte[] ([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $count = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($count -le 0) { throw 'DiagnosticPath changed or ended during reading.' }
            $offset += $count
        }
        $text = (New-Object Text.UTF8Encoding($false, $true)).GetString($bytes).TrimStart([char]0xfeff)
        if (-not $text.TrimStart().StartsWith('{')) { throw 'DiagnosticPath must contain one JSON object.' }
        $record = ConvertFrom-Json -InputObject $text -ErrorAction Stop
        if ($record -isnot [pscustomobject] -or
            ($record.schema_version -isnot [int] -and $record.schema_version -isnot [long]) -or
            $record.schema_version -ne 1 -or $record.kind -cne 'AudioFileForPhone.Diagnostic' -or
            $record.stage -isnot [string] -or $record.code -isnot [string]) {
            throw 'DiagnosticPath is not a supported schema-1 AudioFileForPhone diagnostic record.'
        }
        return $record
    }
    finally { if ($null -ne $stream) { $stream.Dispose() } }
}

function Invoke-AudioEnvironmentCheck {
    param([Parameter(Mandatory = $true)][string]$ScriptDirectory,
          [string]$FfmpegDirectory, [string]$ConfigPath,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    $context = @{ Code = 'DependencyMissing'; Stage = 'DependencyResolution'; Attempts = @(); NativeResult = $null }
    $result = [ordered]@{
        Status = 'Failed'; Code = 'DependencyMissing'; Stage = 'DependencyResolution'; Message = ''
        Selection = $null; SampleRates = @(); Context = $context; NativeResult = $null
    }
    try {
        $options = @{ ScriptDirectory = $ScriptDirectory; ConfigPath = $ConfigPath; Cancellation = $Cancellation; DiagnosticContext = $context; LocalOnly = $true }
        if ($PSBoundParameters.ContainsKey('FfmpegDirectory')) { $options.FfmpegDirectory = $FfmpegDirectory }
        $selection = Resolve-AudioToolSelection @options
        $result.Selection = $selection
        $result.Stage = 'EncoderCapabilities'; $result.Code = 'CapabilityMissing'
        $capabilities = Get-AudioEncoderSampleRates -FfmpegPath $selection.Ffmpeg.Path -Cancellation $Cancellation
        $result.NativeResult = $capabilities.NativeResult
        if ($capabilities.Status -ne 'Success') {
            if ($capabilities.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException($capabilities.Error)) }
            if ($null -ne $capabilities.NativeResult -and $capabilities.NativeResult.Status -eq 'Timeout') { $result.Code = 'StartupTimeout' }
            throw $capabilities.Error
        }
        $result.SampleRates = [int[]]$capabilities.SampleRates
        $result.Status = 'Success'; $result.Code = 'EnvironmentReady'; $result.Stage = 'EnvironmentCheck'
        $result.Message = 'Selected tools passed production version, encoder and sample-rate checks. No media was read or written.'
    }
    catch {
        if ($_.Exception.GetBaseException() -is [OperationCanceledException]) {
            $result.Status = 'Cancelled'; $result.Code = 'Cancelled'
        }
        elseif ($result.Stage -eq 'DependencyResolution') {
            if (-not [string]::IsNullOrEmpty([string]$context.Code)) { $result.Code = $context.Code }
            if (-not [string]::IsNullOrEmpty([string]$context.Stage)) { $result.Stage = $context.Stage }
            $result.NativeResult = $context.NativeResult
        }
        $result.Message = Get-AudioBoundedText -Value $_.Exception.Message
    }
    return [pscustomobject]$result
}

function New-AudioSelfTestScope {
    # Reserve the exact tree exclusively. No pre-existing path grants ownership.
    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    if ($parent -cmatch '^[A-Za-z]:$') { $parent += '\' }
    $null = Assert-AudioLocalToolPath -Path $parent
    Assert-AudioNoReparseAncestor -Path $parent
    $root = [IO.Path]::Combine($parent, 'AFP-SelfTest-' + [guid]::NewGuid().ToString('N'))
    Assert-AudioPathBudget -Path ([IO.Path]::Combine($root, 'output', '.AudioFileForPhone-' + ('0' * 32) + '.partial')) -Kind File
    Initialize-AudioDirectoryInterop
    if (-not [AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($root, [IntPtr]::Zero)) {
        throw ('Could not reserve synthetic self-test tree (Win32 ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error() + ').')
    }
    $scope = [pscustomobject]@{
        Root = $root; Parent = $parent; Token = [guid]::NewGuid().ToString('N')
        MarkerPath = [IO.Path]::Combine($root, '.self-test-owner'); MarkerIdentity = $null; MarkerStream = $null
        InputPath = [IO.Path]::Combine($root, 'input'); OutputPath = [IO.Path]::Combine($root, 'output')
        FixturePath = [IO.Path]::Combine($root, 'input', 'synthetic.mp3')
        ResultPath = [IO.Path]::Combine($root, 'output', 'synthetic-result.mp3'); WorkingPath = $null
    }
    try {
        Assert-AudioNoReparseAncestor -Path $root
        $scope.MarkerStream = New-Object IO.FileStream($scope.MarkerPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
        $bytes = [Text.Encoding]::UTF8.GetBytes($scope.Token)
        $scope.MarkerStream.Write($bytes, 0, $bytes.Length); $scope.MarkerStream.Flush()
        $scope.MarkerIdentity = Get-AudioWorkingFileIdentity -Stream $scope.MarkerStream
        [IO.Directory]::CreateDirectory($scope.InputPath) | Out-Null
        [IO.Directory]::CreateDirectory($scope.OutputPath) | Out-Null
        Assert-AudioNoReparseAncestor -Path $scope.InputPath
        Assert-AudioNoReparseAncestor -Path $scope.OutputPath
        return $scope
    }
    catch {
        # Construction did not return a complete ownership proof. Never recurse.
        $setupError = New-Object InvalidOperationException('Synthetic scope setup failed; retained exact scope ' + $root + ': ' + $_.Exception.Message)
        $setupError.Data['SelfTestScope'] = $scope
        throw $setupError
    }
}

function Remove-AudioSelfTestScope {
    param([Parameter(Mandatory = $true)][object]$Scope,
          [Parameter(Mandatory = $true)][bool]$ProcessReleased,
          [Parameter(Mandatory = $true)][bool]$PipeDrainCompleted)
    if (-not $ProcessReleased -or -not $PipeDrainCompleted) { throw 'Native release or pipe completion is unproved; self-test files were retained.' }
    $root = [IO.Path]::GetFullPath($Scope.Root).TrimEnd('\', '/')
    $parent = [IO.Path]::GetFullPath($Scope.Parent).TrimEnd('\', '/')
    if ($parent -cmatch '^[A-Za-z]:$') { $parent += '\' }
    if ([IO.Path]::GetDirectoryName($root) -ine $parent -or
        [IO.Path]::GetFileName($root) -cnotmatch '^AFP-SelfTest-[0-9a-f]{32}$' -or
        $Scope.MarkerPath -ine [IO.Path]::Combine($root, '.self-test-owner') -or
        $Scope.InputPath -ine [IO.Path]::Combine($root, 'input') -or
        $Scope.OutputPath -ine [IO.Path]::Combine($root, 'output') -or
        $Scope.FixturePath -ine [IO.Path]::Combine($root, 'input', 'synthetic.mp3') -or
        $Scope.ResultPath -ine [IO.Path]::Combine($root, 'output', 'synthetic-result.mp3') -or
        $null -eq $Scope.MarkerStream -or $Scope.Token -cnotmatch '^[0-9a-f]{32}$') {
        throw 'Synthetic scope ownership boundary is invalid; files were retained.'
    }
    Assert-AudioNoReparseAncestor -Path $root
    $markerBytes = New-Object byte[] 32
    $Scope.MarkerStream.Position = 0
    $markerRead = $Scope.MarkerStream.Read($markerBytes, 0, $markerBytes.Length)
    if ((Get-AudioWorkingFileIdentity -Stream $Scope.MarkerStream) -cne $Scope.MarkerIdentity -or
        (Get-AudioWorkingFileIdentity -Path $Scope.MarkerPath) -cne $Scope.MarkerIdentity -or
        $Scope.MarkerStream.Length -ne 32 -or $markerRead -ne 32 -or
        [Text.Encoding]::UTF8.GetString($markerBytes) -cne $Scope.Token) { throw 'Synthetic scope marker identity changed; files were retained.' }
    # Delete only a fixed inventory, refusing unexpected descendants. This needs
    # no recursive deletion and cannot reclaim another invocation's scope.
    $allowedFiles = @($Scope.MarkerPath, $Scope.FixturePath, $Scope.ResultPath)
    if ($null -ne $Scope.WorkingPath) {
        if ([IO.Path]::GetDirectoryName($Scope.WorkingPath) -ine $Scope.OutputPath -or
            [IO.Path]::GetFileName($Scope.WorkingPath) -cnotmatch '^\.AudioFileForPhone-[0-9a-f]{32}\.partial$') {
            throw 'Synthetic working-file boundary changed; files were retained.'
        }
        $allowedFiles += $Scope.WorkingPath
    }
    foreach ($directory in @($root, $Scope.InputPath, $Scope.OutputPath)) {
        Assert-AudioNoReparseAncestor -Path $directory
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Synthetic tree contains a reparse point; files were retained.' }
            if ($item.PSIsContainer) {
                if ($directory -ine $root -or $item.FullName -inotmatch ('^' + [regex]::Escape($root) + '\\(?:input|output)$')) {
                    throw 'Synthetic tree contains an unexpected directory; files were retained.'
                }
            }
            elseif ($allowedFiles -inotcontains $item.FullName) { throw 'Synthetic tree contains an unexpected file; files were retained.' }
        }
    }
    # Keep the non-delete-sharing marker guard until all descendant checks pass.
    foreach ($path in @($allowedFiles | Where-Object { $_ -ine $Scope.MarkerPath })) {
        Assert-AudioNoReparseAncestor -Path $path
        if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
    }
    [IO.Directory]::Delete($Scope.InputPath, $false)
    [IO.Directory]::Delete($Scope.OutputPath, $false)
    $Scope.MarkerStream.Dispose(); $Scope.MarkerStream = $null
    [IO.File]::Delete($Scope.MarkerPath)
    [IO.Directory]::Delete($root, $false)
    if ([IO.Directory]::Exists($root)) { throw 'Synthetic tree cleanup could not be verified.' }
}

function Invoke-AudioSyntheticSelfTest {
    param([Parameter(Mandatory = $true)][object]$Selection,
          [Parameter(Mandatory = $true)][int[]]$SupportedSampleRates,
          [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext))
    $result = [ordered]@{
        Status = 'Failed'; Code = 'SelfTestFailed'; ExitCode = 1; Error = ''; RootPath = $null
        SourceUnchanged = $false; CleanupVerified = $false; ProcessReleased = $true; PipeDrainCompleted = $true
        FixtureSha256 = $null; OutputBitrate = $null; OutputSampleRate = $null; OutputChannels = $null
        NativeResults = @(); Validation = $null
    }
    $scope = $null; $before = $null
    try {
        # Missing fixture-only capability does not mean ordinary conversion is broken.
        foreach ($query in @(
            @{ Arguments = @('-nostdin', '-hide_banner', '-demuxers'); Pattern = '(?m)^\s*D\s+(?:d\s+)?lavfi\s'; Name = 'lavfi demuxer' },
            @{ Arguments = @('-nostdin', '-hide_banner', '-h', 'filter=sine'); Pattern = '(?m)^Filter sine\s*$'; Name = 'sine filter' }
        )) {
            $result.ProcessReleased = $false; $result.PipeDrainCompleted = $false
            $native = Invoke-AudioNativeProcess -ExecutablePath $Selection.Ffmpeg.Path -Arguments $query.Arguments -Cancellation $Cancellation `
                -Operation ('Self-test fixture capability: ' + $query.Name) -TimeoutMilliseconds 15000
            $result.NativeResults += $native
            $result.ProcessReleased = [bool]$native.ProcessReleased; $result.PipeDrainCompleted = [bool]$native.PipeDrainCompleted
            if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { throw 'Fixture capability process release was not established; no further native operation was started.' }
            if ($native.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Synthetic self-test cancelled.')) }
            if ($native.Status -eq 'Timeout') { $result.Code = 'StartupTimeout'; throw 'Synthetic fixture capability query timed out. Ordinary source conversion was not tested.' }
            if ($native.Status -ne 'Completed' -or $native.ExitCode -ne 0 -or $native.StdoutTruncated -or $native.StderrTruncated -or
                ($native.Stdout + "`n" + $native.Stderr) -notmatch $query.Pattern) {
                $result.Status = 'Unavailable'; $result.Code = 'SELF_TEST_UNAVAILABLE'
                throw ('Synthetic fixture capability is unavailable (' + $query.Name + '). Ordinary source conversion was not tested; select a build with lavfi and sine to run self-test.')
            }
        }
        $scope = New-AudioSelfTestScope
        $result.RootPath = $scope.Root
        $result.ProcessReleased = $false; $result.PipeDrainCompleted = $false
        $fixture = Invoke-AudioNativeProcess -ExecutablePath $Selection.Ffmpeg.Path -Arguments @(
            '-nostdin', '-hide_banner', '-v', 'error', '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=44100:duration=0.75',
            '-ac', '1', '-c:a', 'libmp3lame', '-b:a', '64k', '-n', $scope.FixturePath
        ) -Cancellation $Cancellation -Operation 'Self-test synthetic fixture' -TimeoutMilliseconds 15000
        $result.NativeResults += $fixture
        $result.ProcessReleased = [bool]$fixture.ProcessReleased; $result.PipeDrainCompleted = [bool]$fixture.PipeDrainCompleted
        if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { throw 'Synthetic fixture process release was not established; files were retained.' }
        if ($fixture.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Synthetic self-test cancelled.')) }
        if ($fixture.Status -eq 'Timeout') { $result.Code = 'StartupTimeout'; throw 'Synthetic fixture generation timed out. Ordinary source conversion was not tested.' }
        if ($fixture.Status -ne 'Completed' -or $fixture.ExitCode -ne 0 -or $fixture.StdoutTruncated -or $fixture.StderrTruncated) {
            $result.Status = 'Unavailable'; $result.Code = 'SELF_TEST_UNAVAILABLE'
            throw 'Synthetic fixture could not be generated by this build. Ordinary source conversion was not tested. Select a build supporting lavfi sine and MP3 fixture generation.'
        }
        $before = (Get-FileHash -LiteralPath $scope.FixturePath -Algorithm SHA256 -ErrorAction Stop).Hash
        $result.FixtureSha256 = $before.ToLowerInvariant()
        $result.ProcessReleased = $false; $result.PipeDrainCompleted = $false
        $media = Get-AudioMediaInfo -Path $scope.FixturePath -FfprobePath $Selection.Ffprobe.Path -Cancellation $Cancellation
        if ($null -ne $media.NativeResult) {
            $result.NativeResults += $media.NativeResult
            $result.ProcessReleased = [bool]$media.NativeResult.ProcessReleased; $result.PipeDrainCompleted = [bool]$media.NativeResult.PipeDrainCompleted
        }
        if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { throw 'Synthetic source probe release was not established; files were retained.' }
        if ($media.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Synthetic self-test cancelled.')) }
        if ($media.Status -ne 'Success' -or $media.DurationStatus -ne 'Valid') { throw ('Synthetic source probe failed: ' + $media.Error) }
        $plan = Get-AudioOutputPlan -Media $media -BitrateKbps 64 -SupportedSampleRates $SupportedSampleRates
        if ($plan.Status -ne 'Success') { throw ('Synthetic output planning failed: ' + $plan.Reason) }
        $metadata = Get-AudioMetadataPlan -Media $media -FallbackTitle 'Synthetic self-test'
        $arguments = New-AudioEncodeArguments -InputPath $scope.FixturePath -Media $media -OutputPlan $plan -MetadataArguments $metadata.Arguments
        $result.ProcessReleased = $false; $result.PipeDrainCompleted = $false
        $transaction = Invoke-AudioOutputTransaction -OutputPath $scope.ResultPath -OutputRoot $scope.OutputPath -SourcePath $scope.FixturePath `
            -SourceDurationSeconds $media.DurationSeconds -BitrateKbps 64 -FfmpegPath $Selection.Ffmpeg.Path -FfprobePath $Selection.Ffprobe.Path `
            -EncodeArguments $arguments -OutputPlan $plan -Cancellation $Cancellation
        $scope.WorkingPath = $transaction.WorkingPath
        $transactionNative = @($transaction.EncoderResult)
        if ($null -ne $transaction.ValidationResult) {
            $transactionNative += @($transaction.ValidationResult.ProbeResult, $transaction.ValidationResult.DecodeResult)
        }
        $transactionNative = @($transactionNative | Where-Object { $null -ne $_ })
        $result.NativeResults += $transactionNative
        # No returned encoder means no proof that a native operation was never
        # started. Conservatively retain the tiny scope on that ambiguous result.
        $result.ProcessReleased = $transactionNative.Count -gt 0 -and @($transactionNative | Where-Object { -not $_.ProcessReleased }).Count -eq 0
        $result.PipeDrainCompleted = $transactionNative.Count -gt 0 -and @($transactionNative | Where-Object { -not $_.PipeDrainCompleted }).Count -eq 0
        if (-not $result.ProcessReleased -or -not $result.PipeDrainCompleted) { throw 'Synthetic transaction release was not established; files were retained.' }
        if ($transaction.Status -eq 'Cancelled') { throw (New-Object OperationCanceledException('Synthetic self-test cancelled.')) }
        if ($transaction.Status -ne 'Success') { throw ('Synthetic conversion failed: ' + $transaction.Error) }
        $validation = $transaction.ValidationResult
        $result.Validation = $validation
        $result.OutputBitrate = $validation.Bitrate; $result.OutputSampleRate = $validation.SampleRate; $result.OutputChannels = $validation.Channels
        $result.SourceUnchanged = (Get-FileHash -LiteralPath $scope.FixturePath -Algorithm SHA256 -ErrorAction Stop).Hash -ceq $before
        if (-not $result.SourceUnchanged) { throw 'Synthetic source hash changed during conversion.' }
        if (-not [IO.File]::Exists($scope.ResultPath) -or $validation.Status -ne 'Success' -or
            $validation.DecodeResult.TimeoutMilliseconds -ne 0 -or $transaction.EncoderResult.TimeoutMilliseconds -ne 0) {
            throw 'Synthetic conversion did not satisfy publication, full decode or unlimited encode/decode policy.'
        }
        Assert-AudioNotCancelled -Cancellation $Cancellation
        $result.Status = 'Success'; $result.Code = 'SelfTestPassed'; $result.ExitCode = 0
    }
    catch {
        if ($null -eq $scope -and $null -ne $_.Exception.Data['SelfTestScope']) {
            $scope = $_.Exception.Data['SelfTestScope']; $result.RootPath = $scope.Root
        }
        if ($_.Exception.GetBaseException() -is [OperationCanceledException]) { $result.Status = 'Cancelled'; $result.Code = 'Cancelled'; $result.ExitCode = 130 }
        $result.Error = Get-AudioBoundedText -Value $_.Exception.Message
    }
    finally {
        if ($null -ne $scope) {
            try {
                if ($null -ne $before -and [IO.File]::Exists($scope.FixturePath)) {
                    $result.SourceUnchanged = (Get-FileHash -LiteralPath $scope.FixturePath -Algorithm SHA256 -ErrorAction Stop).Hash -ceq $before
                    if (-not $result.SourceUnchanged) { throw 'Synthetic source hash changed before cleanup; files were retained.' }
                }
                Remove-AudioSelfTestScope -Scope $scope -ProcessReleased $result.ProcessReleased -PipeDrainCompleted $result.PipeDrainCompleted
                $result.CleanupVerified = -not [IO.Directory]::Exists($scope.Root)
            }
            catch {
                $result.Error = Get-AudioBoundedText -Value ($result.Error + ' Cleanup retained ' + $scope.Root + ': ' + $_.Exception.Message)
                if ($result.Status -ne 'Cancelled') { $result.Status = 'Failed'; $result.Code = 'SelfTestCleanupRetained'; $result.ExitCode = 1 }
            }
            finally { if ($null -ne $scope.MarkerStream) { $scope.MarkerStream.Dispose(); $scope.MarkerStream = $null } }
        }
        else { $result.CleanupVerified = $true }
        # A request after publication/cleanup is still cancellation; successful
        # completed output and cleanup do not override the process exit contract.
        if (Test-AudioCancellation -Cancellation $Cancellation) {
            $result.Status = 'Cancelled'; $result.Code = 'Cancelled'; $result.ExitCode = 130
            if ([string]::IsNullOrEmpty($result.Error)) { $result.Error = 'Synthetic self-test cancellation was requested at the final boundary.' }
        }
    }
    return [pscustomobject]$result
}
