function Get-AcceptanceReportProperty {
    param([AllowNull()][object]$Value, [string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains($Name)) { return $Value[$Name] }
        return $Default
    }
    if ($null -ne $Value.PSObject.Properties[$Name]) { return $Value.$Name }
    return $Default
}

function Get-AcceptanceReportText {
    param([AllowNull()][object]$Value, [int]$MaximumLength = 200)
    $text = [string]$Value
    if ($text.Length -gt $MaximumLength -or $text -match '[\x00-\x1f]|[A-Za-z]:[\\/]|\\\\|(?i:password|token|secret|bearer)\s*[:=]') { return '<redacted>' }
    return $text
}

function Get-AcceptanceReportStatus {
    param([AllowNull()][object]$Value)
    $status = [string]$Value
    if ($status -cnotin @('PASSED', 'FAILED', 'BLOCKED', 'NOT_TESTED', 'NOT_RUN', 'PENDING', 'REFUSED', 'REHEARSAL', 'IN_PROGRESS', 'AUTOMATED_PASSED_ACCEPTANCE_INCOMPLETE', 'CANCELLED')) { return 'NOT_TESTED' }
    return $status
}

function Export-AcceptanceReport {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Report, [Parameter(Mandatory = $true)][string]$OutputDirectory)
    $directory = Assert-AcceptanceLocalPath $OutputDirectory -MustExist
    $environment = Get-AcceptanceReportProperty $Report 'environment'
    $safeEnvironment = [ordered]@{}
    foreach ($field in @('os', 'caption', 'os_caption', 'os_family', 'os_product_type', 'product_type', 'build', 'revision', 'display_version', 'architecture', 'shell_version', 'shell_edition', 'acceptance_class')) {
        $value = Get-AcceptanceReportProperty $environment $field
        if ($null -ne $value) { $safeEnvironment[$field] = Get-AcceptanceReportText $value }
    }
    $is64 = Get-AcceptanceReportProperty $environment 'process_64bit'
    if ($is64 -is [bool]) { $safeEnvironment.process_64bit = $is64 }
    $hosts = @()
    foreach ($hostRow in @(Get-AcceptanceReportProperty $Report 'hosts' @())) {
        $hosts += [ordered]@{
            host_id = Get-AcceptanceReportText (Get-AcceptanceReportProperty $hostRow 'host_id')
            shell_version = Get-AcceptanceReportText (Get-AcceptanceReportProperty $hostRow 'shell_version')
            shell_edition = Get-AcceptanceReportText (Get-AcceptanceReportProperty $hostRow 'shell_edition')
            status = Get-AcceptanceReportStatus (Get-AcceptanceReportProperty $hostRow 'status')
        }
    }
    $dependencies = @()
    foreach ($dependency in @(Get-AcceptanceReportProperty $Report 'dependencies' @())) {
        $dependencies += [ordered]@{
            name = Get-AcceptanceReportText (Get-AcceptanceReportProperty $dependency 'name')
            version = Get-AcceptanceReportText (Get-AcceptanceReportProperty $dependency 'version') 512
            origin = Get-AcceptanceReportText (Get-AcceptanceReportProperty $dependency 'origin')
        }
    }
    $cases = @()
    foreach ($case in @(Get-AcceptanceReportProperty $Report 'cases' @())) {
        $result = Get-AcceptanceReportProperty $case 'result' $case
        $row = [ordered]@{
            id = Get-AcceptanceReportText (Get-AcceptanceReportProperty $case 'id')
            status = Get-AcceptanceReportStatus (Get-AcceptanceReportProperty $case 'status')
            exit_code = $null
        }
        $exitCode = Get-AcceptanceReportProperty $result 'captured_exit_code' (Get-AcceptanceReportProperty $case 'exit_code')
        if ($exitCode -is [int] -or $exitCode -is [long]) { $row.exit_code = $exitCode }
        $row.raw_exit_captured = $null -ne $exitCode
        foreach ($field in @('input_count', 'converted_count', 'failed_count', 'unprocessed_count')) {
            $value = Get-AcceptanceReportProperty $result $field
            if (($value -is [int] -or $value -is [long]) -and $value -ge 0) { $row[$field] = $value }
        }
        foreach ($field in @('source_unchanged', 'media_validated', 'full_decode', 'raw_exit_captured')) {
            $value = Get-AcceptanceReportProperty $result $field
            if ($value -is [bool]) { $row[$field] = $value }
        }
        $checks = @()
        foreach ($check in @(Get-AcceptanceReportProperty $case 'checks' (Get-AcceptanceReportProperty $result 'checks' @()))) {
            $checks += [ordered]@{
                id = Get-AcceptanceReportText (Get-AcceptanceReportProperty $check 'id')
                status = Get-AcceptanceReportStatus (Get-AcceptanceReportProperty $check 'status')
                expected = Get-AcceptanceReportText (Get-AcceptanceReportProperty $check 'expected')
                observed = Get-AcceptanceReportText (Get-AcceptanceReportProperty $check 'observed')
            }
        }
        if ($checks.Count -gt 0) { $row.checks = $checks }
        $media = @()
        foreach ($item in @(Get-AcceptanceReportProperty $result 'media' @())) {
            $mediaRow = [ordered]@{}
            foreach ($field in @('sequence', 'bitrate_bps', 'sample_rate', 'channels', 'input_duration_seconds', 'output_duration_seconds', 'decoded_duration_seconds')) {
                $value = Get-AcceptanceReportProperty $item $field
                if (($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal]) -and [double]$value -ge 0 -and -not [double]::IsInfinity([double]$value)) { $mediaRow[$field] = $value }
            }
            $mediaRow.format = Get-AcceptanceReportText (Get-AcceptanceReportProperty $item 'format')
            $mediaRow.full_decode = (Get-AcceptanceReportProperty $item 'full_decode') -is [bool] -and (Get-AcceptanceReportProperty $item 'full_decode')
            $media += $mediaRow
        }
        if ($media.Count -gt 0) { $row.media = $media }
        $cases += $row
    }
    $human = [ordered]@{}
    $observations = Get-AcceptanceReportProperty $Report 'human_observations'
    foreach ($field in @('physical_shortcut', 'physical_run_verification', 'phone_play', 'phone_seek')) {
        $value = Get-AcceptanceReportProperty $observations $field 'NOT_TESTED'
        $human[$field] = Get-AcceptanceReportStatus $value
    }
    $identity = [ordered]@{}
    foreach ($field in @('source_commit', 'runtime_zip_sha256', 'acceptance_kit_sha256')) {
        $value = [string](Get-AcceptanceReportProperty $Report $field)
        $pattern = if ($field -ceq 'source_commit') { '^[a-f0-9]{40}$' } else { '^[a-f0-9]{64}$' }
        $identity[$field] = if ($value -cmatch $pattern) { $value } else { $null }
    }
    $issueCode = [string](Get-AcceptanceReportProperty $Report 'issue_code')
    if ($issueCode -cnotmatch '^(?:[A-Za-z][A-Za-z0-9._-]{0,79})?$') { $issueCode = 'PrivateDiagnosticRetained' }
    $runtimeHashes = @()
    $runtimeAllowlist = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.ManagedSetup.ps1',
        'AudioFileForPhone.Launcher.ps1', 'AudioFileForPhone.HostProbe.ps1', 'AudioFileForPhone.Diagnostics.ps1',
        'AudioFileForPhone.Checks.ps1', 'Check-AudioFileForPhone.ps1', 'Check-AudioFileForPhone.bat',
        'tools/ffmpeg-download.json', 'Setup-AudioFileForPhone.ps1', 'Setup-AudioFileForPhone.bat',
        'AudioFileForPhone.bat', 'README.md', 'SUPPORT.md', 'CHANGELOG.md', 'SECURITY.md', 'LICENSE')
    foreach ($row in @(Get-AcceptanceReportProperty $Report 'runtime_hashes' @())) {
        $path = [string](Get-AcceptanceReportProperty $row 'path')
        $hash = [string](Get-AcceptanceReportProperty $row 'sha256')
        if ($runtimeAllowlist -ccontains $path -and $hash -cmatch '^[a-f0-9]{64}$') { $runtimeHashes += [ordered]@{ path = $path; sha256 = $hash } }
    }
    $safe = [ordered]@{
        schema_version = 1; kind = Get-AcceptanceReportText (Get-AcceptanceReportProperty $Report 'kind')
        status = Get-AcceptanceReportStatus (Get-AcceptanceReportProperty $Report 'status')
        started_utc = Get-AcceptanceReportText (Get-AcceptanceReportProperty $Report 'started_utc')
        ended_utc = Get-AcceptanceReportText (Get-AcceptanceReportProperty $Report 'ended_utc')
        source_commit = $identity.source_commit; runtime_version = Get-AcceptanceReportText (Get-AcceptanceReportProperty $Report 'runtime_version')
        runtime_zip_sha256 = $identity.runtime_zip_sha256; acceptance_kit_sha256 = $identity.acceptance_kit_sha256
        runtime_hashes = $runtimeHashes
        environment = $safeEnvironment; hosts = $hosts; dependencies = $dependencies; cases = $cases; human_observations = $human
        issue_code = $issueCode
        private_data_exported = $false; uploaded = $false
    }
    $json = ($safe | ConvertTo-Json -Depth 16) + "`r`n"
    if ([Text.Encoding]::UTF8.GetByteCount($json) -gt 4194304) { throw 'Redacted report exceeds its bound.' }
    $text = New-Object 'Collections.Generic.List[string]'
    $text.Add('AudioFileForPhone Windows acceptance report')
    $text.Add('Status: ' + $safe.status + ' | Runtime: ' + $safe.runtime_version + ' | Scope: ' + $safe.kind)
    $text.Add('Source: ' + $safe.source_commit); $text.Add('Runtime ZIP SHA256: ' + $safe.runtime_zip_sha256)
    $text.Add('Acceptance kit SHA256: ' + $safe.acceptance_kit_sha256)
    foreach ($key in $safeEnvironment.Keys) { $text.Add('Environment ' + $key + ': ' + [string]$safeEnvironment[$key]) }
    foreach ($hostRow in $hosts) { $text.Add('Host: ' + $hostRow.host_id + ' | ' + $hostRow.shell_version + ' | ' + $hostRow.status) }
    foreach ($dependency in $dependencies) { $text.Add('Dependency: ' + $dependency.name + ' | ' + $dependency.origin + ' | ' + $dependency.version) }
    foreach ($case in $cases) {
        $line = 'Case ' + $case.id + ': ' + $case.status + ' | captured exit: ' + [string]$case.exit_code
        foreach ($field in @('input_count', 'converted_count', 'failed_count', 'unprocessed_count', 'source_unchanged', 'media_validated', 'full_decode')) {
            if ($case.Contains($field)) { $line += ' | ' + $field + '=' + [string]$case[$field] }
        }
        $text.Add($line)
        if ($case.Contains('media')) {
            $exact64 = @($case.media | Where-Object { $_.bitrate_bps -eq 64000 }).Count
            $fullDecode = @($case.media | Where-Object { $_.full_decode }).Count
            $text.Add('  Media: exact 64000 bps=' + $exact64 + '/' + $case.media.Count + '; full decode=' + $fullDecode + '/' + $case.media.Count + '; duration tolerance=0.35 seconds')
        }
    }
    foreach ($key in $human.Keys) { $text.Add('Human ' + $key + ': ' + $human[$key]) }
    if (-not [string]::IsNullOrWhiteSpace($safe.issue_code)) { $text.Add('Issue: ' + $safe.issue_code) }
    $text.Add('No source paths, media hashes, audio or private logs are exported. No upload was performed.')
    $text.Add('This report records the observed scope; release gates and publication authority remain separate.')
    $staged = New-Object 'Collections.Generic.List[object]'
    try {
        foreach ($pair in @(@('REPORT.json', $json), @('REPORT.txt', (($text.ToArray() -join "`r`n") + "`r`n")))) {
            $path = Join-Path $directory $pair[0]
            if (Test-Path -LiteralPath $path) { throw 'A report already exists; retain it and select a new report directory.' }
            $partial = Join-Path $directory ('.afp-report-' + [guid]::NewGuid().ToString('N') + '.partial')
            $stream = [IO.File]::Open($partial, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $staged.Add([pscustomobject]@{ path = $partial; final = $path })
            try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes([string]$pair[1]); $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
            finally { $stream.Dispose() }
        }
        foreach ($row in $staged) {
            $null = Assert-AcceptanceLocalPath $directory -MustExist
            $null = Assert-AcceptanceLocalPath $row.path -MustExist
            [IO.File]::Move($row.path, $row.final)
        }
    } finally {
        foreach ($row in $staged) {
            if (Test-Path -LiteralPath $row.path) {
                $null = Assert-AcceptanceLocalPath $row.path -MustExist
                [IO.File]::Delete($row.path)
            }
        }
    }
    return [pscustomobject]@{ text_path = Join-Path $directory 'REPORT.txt'; json_path = Join-Path $directory 'REPORT.json'; report = [pscustomobject]$safe }
}
