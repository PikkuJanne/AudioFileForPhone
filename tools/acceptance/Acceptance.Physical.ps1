function Assert-AcceptancePhysicalSpelling {
    param([Parameter(Mandatory = $true)][string]$Path)
    # Explorer's direct BAT shortcut route expands %ENV% before BAT can disable
    # evaluation. Refuse this route rather than alter or rename a selected path.
    if ($Path.Contains('%')) { throw 'PHYSICAL_LITERAL_PATH_UNSUPPORTED: a direct BAT shortcut cannot safely preserve percent-containing paths. Keep automated evidence; no physical pass is claimed.' }
}

function Close-AcceptancePhysical {
    [CmdletBinding()]
    param([AllowNull()][object]$Context)
    if ($null -eq $Context) { return }
    if ($null -ne $Context.watcher) {
        $Context.watcher.EnableRaisingEvents = $false
        $Context.watcher.Dispose()
        $Context.watcher = $null
    }
    foreach ($id in @($Context.created_event_id, $Context.error_event_id)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$id)) {
            Unregister-Event -SourceIdentifier $id -ErrorAction SilentlyContinue
            Get-Event -SourceIdentifier $id -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
        }
    }
    $Context.closed = $true
}

function Initialize-AcceptancePhysical {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RuntimeDirectory,
          [Parameter(Mandatory = $true)][string]$SourceDirectory,
          [Parameter(Mandatory = $true)][string]$SessionDirectory)
    $runtime = Assert-AcceptanceLocalPath $RuntimeDirectory -MustExist
    $source = Assert-AcceptanceLocalPath $SourceDirectory -MustExist
    $session = Assert-AcceptanceLocalPath $SessionDirectory -MustExist
    $bat = Assert-AcceptanceLocalPath (Join-Path $runtime 'AudioFileForPhone.bat') -MustExist
    foreach ($path in @($runtime, $source, $session, $bat)) { Assert-AcceptancePhysicalSpelling $path }
    # Use the production Music resolver. Never enumerate, rename or clean Music.
    $music = Assert-AcceptanceLocalPath (Get-OutputParent) -MustExist
    foreach ($directory in @($runtime, $source, $session, $music)) {
        if (-not (Get-Item -LiteralPath $directory -Force -ErrorAction Stop).PSIsContainer) {
            throw 'Physical acceptance requires existing ordinary directories.'
        }
    }
    $shortcutDirectory = Join-Path $session 'physical-shortcut'
    if (Test-Path -LiteralPath $shortcutDirectory) { throw 'Physical shortcut workspace already exists.' }
    $null = [IO.Directory]::CreateDirectory($shortcutDirectory)
    $shortcutPath = Join-Path $shortcutDirectory 'Convert selected collection.lnk'
    $eventToken = [guid]::NewGuid().ToString('N')
    $context = [pscustomobject]@{
        runtime_directory = $runtime; source_directory = $source; music_directory = $music
        shortcut_directory = $shortcutDirectory; shortcut_path = $shortcutPath
        entry_sha256 = Get-AcceptanceHash (Join-Path $runtime 'AudioFileForPhone.ps1')
        helper_sha256 = Get-AcceptanceHash (Join-Path $runtime 'AudioFileForPhone.Helpers.ps1')
        started_utc = [DateTimeOffset]::UtcNow; ended_utc = $null
        created_event_id = 'AFP.Physical.Created.' + $eventToken
        error_event_id = 'AFP.Physical.Error.' + $eventToken
        watcher = $null; closed = $false; captured_paths = @(); candidate_errors = @()
    }
    $shell = $null; $shortcut = $null
    try {
        # The shortcut targets the actual packaged BAT directly. It does not set
        # PATH, switch the host, redirect Music or replace the production launcher.
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $bat
        $shortcut.Arguments = '"' + $source + '"'
        $shortcut.WorkingDirectory = $runtime
        $shortcut.WindowStyle = 1
        $shortcut.Description = 'Convert the selected collection with AudioFileForPhone defaults'
        $shortcut.Save()
        $watcher = New-Object IO.FileSystemWatcher
        $watcher.Path = $music
        $watcher.Filter = 'AudioForPhone_64kbps_*'
        $watcher.IncludeSubdirectories = $false
        $watcher.NotifyFilter = [IO.NotifyFilters]::DirectoryName
        $watcher.InternalBufferSize = 32768
        $context.watcher = $watcher
        $null = Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier $context.created_event_id
        $null = Register-ObjectEvent -InputObject $watcher -EventName Error -SourceIdentifier $context.error_event_id
        $context.started_utc = [DateTimeOffset]::UtcNow
        $watcher.EnableRaisingEvents = $true
        Write-Host ''
        Write-Host 'Double-click Convert selected collection in the opened shortcut folder once.'
        Write-Host 'In AudioFileForPhone, press Enter to use defaults and wait for the final Completed result.'
        Write-Host 'Then return to this acceptance window. Completed Music outputs are kept for you.'
        # These are the two deliberately visible windows for the one human action.
        $explorer = Join-Path $env:SystemRoot 'explorer.exe'
        Start-Process -FilePath $explorer -ArgumentList ('"' + $shortcutDirectory + '"') -ErrorAction Stop
        Start-Process -FilePath $explorer -ArgumentList ('"' + $source + '"') -ErrorAction Stop
        return $context
    }
    catch { Close-AcceptancePhysical $context; throw }
    finally {
        if ($null -ne $shortcut) { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
        if ($null -ne $shell) { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    }
}

function Complete-AcceptancePhysical {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Context,
          [Parameter(Mandatory = $true)][object[]]$SourceBefore,
          [Parameter(Mandatory = $true)][string]$FfmpegPath,
          [Parameter(Mandatory = $true)][string]$FfprobePath)
    $result = [pscustomobject][ordered]@{
        status = 'NOT_TESTED'; observation = 'NOT_TESTED'; matched_run = $false
        evidence_type = 'human_observation'; observer = 'local console user self-report'
        command = 'Explorer launch of exact packaged AudioFileForPhone.bat via prepared shortcut'
        started_utc = $Context.started_utc.ToString('o'); ended_utc = $null
        conversion = $null; run_directory = $null; ownership_token = $null
        raw_exit_captured = $false; captured_exit_code = $null
        issue_code = $null; private_error = $null
    }
    try {
        if ($Context.closed -or $null -eq $Context.watcher) { throw 'Physical watcher is not active.' }
        $answer = (Read-Host 'Did you physically open the prepared shortcut and observe final Completed? [yes/no/not-tested]').Trim().ToLowerInvariant()
        switch ($answer) {
            { $_ -in @('y', 'yes') } { $result.observation = 'PASSED'; break }
            { $_ -in @('n', 'no') } { $result.observation = 'FAILED'; $result.status = 'FAILED'; break }
            { $_ -in @('', 't', 'not-tested', 'not tested', 'not_tested') } { break }
            default { throw 'Physical observation answer was not yes, no or not-tested.' }
        }
        $Context.ended_utc = [DateTimeOffset]::UtcNow
        $Context.watcher.EnableRaisingEvents = $false
        if ($result.observation -cne 'PASSED') { return [pscustomobject]$result }
        $errors = @(Get-Event -SourceIdentifier $Context.error_event_id -ErrorAction SilentlyContinue)
        if ($errors.Count -ne 0) { throw 'The physical output watcher reported an error; exact correlation is unproved.' }
        $events = @(Get-Event -SourceIdentifier $Context.created_event_id -ErrorAction SilentlyContinue)
        if ($events.Count -gt 1000) { throw 'Physical output observation exceeded its event bound.' }
        $paths = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($eventRecord in $events) {
            $path = [string]$eventRecord.SourceEventArgs.FullPath
            $parent = [IO.Path]::GetDirectoryName($path)
            if ($parent.Equals($Context.music_directory, [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFileName($path) -cmatch '^AudioForPhone_64kbps_[0-9]{8}_[0-9]{6}(?:_[1-9][0-9]*)?$') {
                $null = $paths.Add($path)
            }
        }
        $Context.captured_paths = @($paths)
        $matchesFound = @()
        foreach ($path in $paths) {
            try {
                $runPath = Assert-AcceptanceLocalPath $path -MustExist
                $manifest = Read-AcceptanceJson (Join-Path $runPath 'AudioFileForPhone_manifest.json') -MaximumBytes 16777216
                if ($manifest.schema_version -ne 1 -or $manifest.kind -cne 'AudioFileForPhone.RunManifest' -or
                    -not ([string]$manifest.run.input_root).Equals($Context.source_directory, [StringComparison]::OrdinalIgnoreCase) -or
                    -not ([string]$manifest.run.output_root).Equals($runPath, [StringComparison]::OrdinalIgnoreCase) -or
                    $manifest.build.entry_sha256 -cne $Context.entry_sha256 -or
                    $manifest.build.helper_sha256 -cne $Context.helper_sha256) { continue }
                $startValue = $manifest.run.started_utc
                $startText = if ($startValue -is [DateTime] -or $startValue -is [DateTimeOffset]) {
                    $startValue.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
                } else { [string]$startValue }
                $started = [DateTimeOffset]::MinValue
                if (-not [DateTimeOffset]::TryParse($startText, [Globalization.CultureInfo]::InvariantCulture,
                    [Globalization.DateTimeStyles]::None, [ref]$started) -or
                    $started -lt $Context.started_utc -or $started -gt $Context.ended_utc) { continue }
                $marker = Read-AcceptanceJson (Join-Path $runPath '.AudioFileForPhone-output.json') -MaximumBytes 8192
                if ($marker.schema_version -ne 1 -or $marker.kind -cne 'AudioFileForPhone.Output' -or
                    [string]$marker.ownership_token -cnotmatch '^[a-f0-9]{32}$' -or
                    -not ([string]$marker.output_root).Equals($runPath, [StringComparison]::OrdinalIgnoreCase) -or
                    -not ([string]$marker.cleanup_scope).Equals($runPath, [StringComparison]::OrdinalIgnoreCase)) { continue }
                $matchesFound += [pscustomobject]@{ path = $runPath; token = [string]$marker.ownership_token }
            }
            catch { $Context.candidate_errors += $_.Exception.Message }
        }
        if ($matchesFound.Count -ne 1) { throw 'Physical launch did not identify exactly one newly observed source/package run.' }
        $match = $matchesFound[0]
        $conversion = Test-AcceptanceConversion -RunDirectory $match.path -SourceRoot $Context.source_directory `
            -SourceBefore $SourceBefore -RuntimeDirectory $Context.runtime_directory -FfmpegPath $FfmpegPath -FfprobePath $FfprobePath
        $result.conversion = $conversion; $result.run_directory = $match.path
        $result.ownership_token = $match.token; $result.matched_run = $true; $result.status = 'PASSED'
        return [pscustomobject]$result
    }
    catch {
        $result.status = 'BLOCKED'; $result.issue_code = 'PHYSICAL_RUN_UNPROVED'; $result.private_error = $_.Exception.Message
        return [pscustomobject]$result
    }
    finally {
        $result.ended_utc = [DateTimeOffset]::UtcNow.ToString('o')
        Close-AcceptancePhysical $Context
    }
}
