<# Inert local release-evidence checks. A passing result grants no publication authority. #>
function Get-ReleaseField {
    param([object]$Record, [string]$Name)
    if ($null -eq $Record) { return $null }
    if ($Record -is [Collections.IDictionary]) { return $Record[$Name] }
    $property = $Record.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}
function Assert-ReleaseLocalFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[*?\x00-\x1f]' -or $Path -match '^[\\/]{2}' -or $Path -match '^[A-Za-z]+:.*:') { throw 'Release evidence requires a literal local file.' }
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Release evidence cannot traverse reparse paths.' }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    if ((Get-Item -LiteralPath $Path -Force).PSIsContainer) { throw 'Release evidence must be a regular file.' }
}
function Read-ReleaseJson {
    param([string]$Path)
    Assert-ReleaseLocalFile $Path
    if ((Get-Item -LiteralPath $Path -Force).Length -gt 4194304) { throw 'Release JSON exceeds 4 MiB.' }
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}
function Get-ReleaseInventoryKey {
    param([object[]]$Inventory)
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $rows = @()
    foreach ($row in @($Inventory)) {
        $path = [string](Get-ReleaseField $row 'path'); $hash = [string](Get-ReleaseField $row 'sha256')
        if ($path -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|tools/ffmpeg-download\.json)$' -or $hash -cnotmatch '^[a-f0-9]{64}$' -or -not $seen.Add($path)) { throw 'Inventory requires unique literal allowlist paths and SHA256s.' }
        $rows += $path + ':' + $hash
    }
    if ($rows.Count -eq 0) { throw 'Runtime inventory is missing.' }
    return (@($rows | Sort-Object) -join "`n")
}
function Read-ReleaseBoundReport {
    param([string]$Path, [string]$Sha256, [string]$GateId)
    $record = Read-ReleaseJson $Path
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    return [pscustomobject]@{ gate_id = $GateId; record = $record; digest_verified = ($Sha256 -cmatch '^[a-f0-9]{64}$' -and $actual -ceq $Sha256) }
}
function Get-ReleaseRequiredChecks {
    param([string]$GateId)
    if ($GateId -cmatch '^core_windows(10|11)_ps(51|7)$') { return @('parser','focused','integration') }
    switch -CaseSensitive ($GateId) {
        'clean_first_run' { return @('missing_tools','external_selection','saved_fresh_process') }
        'online_setup' { return @('consent','download_pin','installed_conversion') }
        'offline_setup_failure' { return @('no_publication','owned_cleanup') }
        'exact_package' { return @('member_hashes','extracted_conversion','full_decode') }
        'one_file' { return @('counts','media','source_hashes') }
        'full_collection' { return @('counts','media','source_hashes') }
        'physical_shortcut' { return @('observed_shortcut','matched_run') }
        'phone_play_seek' { return @('play','seek') }
        default { throw 'Unknown release gate ID.' }
    }
}
function Assert-ReleaseFrozenSource {
    param([string]$RepositoryRoot, [string]$SourceCommit, [string[]]$Paths, [switch]$RequireMain)
    if ($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $Paths.Count -lt 1) { throw 'Exact frozen source and full package allowlist are required.' }
    & git -C $RepositoryRoot cat-file -e ($SourceCommit + '^{commit}') 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Frozen source is not an actual local Git commit.' }
    & git -C $RepositoryRoot merge-base --is-ancestor $SourceCommit HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Frozen source is not in the current checkout history.' }
    if ($RequireMain) {
        & git -C $RepositoryRoot merge-base --is-ancestor $SourceCommit refs/heads/main 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'Publication source is not in local main history; refresh live refs under the release protocol.' }
    }
    foreach ($relative in $Paths) {
        if ($relative -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|tools/(?:ffmpeg-download|package-files)\.json)$') { throw 'Frozen source paths must match the package allowlist/control format.' }
        & git -C $RepositoryRoot cat-file -e ($SourceCommit + ':' + $relative) 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'A package member is not tracked at the frozen source.' }
    }
    & git -C $RepositoryRoot diff --no-ext-diff --no-textconv --quiet $SourceCommit -- @Paths
    if ($LASTEXITCODE -ne 0) { throw 'Packaged working bytes changed from the frozen source; docs-only later commits remain permitted.' }
}
function Get-ReleaseGitBlobHash {
    param([string]$RepositoryRoot, [string]$SourceCommit, [string]$RelativePath)
    if ($SourceCommit -cnotmatch '^[a-f0-9]{40}$' -or $RelativePath -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9._-]*|tools/ffmpeg-download\.json)$') { throw 'Exact source and package member are required for binary blob hashing.' }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = @(Get-Command git -CommandType Application -ErrorAction Stop)[0].Source
    $info.WorkingDirectory = $RepositoryRoot
    $info.Arguments = 'cat-file blob ' + $SourceCommit + ':' + $RelativePath
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    $sha = [Security.Cryptography.SHA256]::Create()
    $sink = [Security.Cryptography.CryptoStream]::new([IO.Stream]::Null, $sha, [Security.Cryptography.CryptoStreamMode]::Write)
    try {
        if (-not $process.Start()) { throw 'Owned exact-blob reader did not start.' }
        $copy = $process.StandardOutput.BaseStream.CopyToAsync($sink)
        $errors = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill(); $process.WaitForExit(5000) | Out-Null
            throw 'Owned exact-blob reader exceeded its deadline.'
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($copy,$errors),5000) -or $process.ExitCode -ne 0) { throw 'Exact-blob read/drain/release did not complete successfully.' }
        $sink.FlushFinalBlock()
        return ([BitConverter]::ToString($sha.Hash)).Replace('-', '').ToLowerInvariant()
    } finally { $sink.Dispose(); $sha.Dispose(); $process.Dispose() }
}
function Assert-ReleaseManifest {
    param([object]$Manifest, [string]$SourceCommit, [string]$ZipHash, [long]$ZipBytes, [object[]]$Runtime)
    if ((Get-ReleaseField $Manifest 'schema_version') -ne 1 -or (Get-ReleaseField $Manifest 'repository') -cne 'PikkuJanne/AudioFileForPhone' -or
        (Get-ReleaseField $Manifest 'app_version') -cne '1.0.1' -or (Get-ReleaseField $Manifest 'tag') -cne 'v1.0.1' -or
        (Get-ReleaseField $Manifest 'release_commit') -cne $SourceCommit) { throw 'External release manifest identity differs from the fixed target/frozen source.' }
    $zip = Get-ReleaseField $Manifest 'zip'
    $bytes = Get-ReleaseField $zip 'bytes'
    if ((Get-ReleaseField $zip 'name') -cne 'AudioFileForPhone-v1.0.1.zip' -or (Get-ReleaseField $zip 'sha256') -cne $ZipHash -or
        ($bytes -isnot [int] -and $bytes -isnot [long]) -or $bytes -ne $ZipBytes -or $ZipBytes -lt 1) { throw 'External release manifest ZIP identity differs from actual bytes.' }
    $files = Get-ReleaseField $Manifest 'files'; $inventory = @()
    if ($files -is [Collections.IDictionary]) {
        $inventory = @($files.Keys | ForEach-Object { [pscustomobject]@{ path=[string]$_; sha256=[string]$files[$_] } })
    } elseif ($null -ne $files) {
        $inventory = @($files.PSObject.Properties | ForEach-Object { [pscustomobject]@{ path=$_.Name; sha256=[string]$_.Value } })
    }
    if ((Get-ReleaseInventoryKey $inventory) -cne (Get-ReleaseInventoryKey $Runtime)) { throw 'External release manifest members differ from exact frozen source blobs.' }
}
function Test-ReleaseGateRecords {
    [CmdletBinding()]
    param([object]$State, [object]$Target, [AllowNull()][object]$Candidate,
        [object[]]$Reports = @(), [object[]]$ActualRuntime = @(), [object[]]$ActualAssets = @(), [string]$ActualVersion,
        [ValidateSet('Acceptance', 'Publication')][string]$Phase = 'Acceptance')
    $failures = New-Object 'Collections.Generic.List[object]'
    function Add-ReleaseRefusal { param([string]$Code, [string]$Detail); $failures.Add([pscustomobject]@{ code = $Code; detail = $Detail }) }
    foreach ($pair in @(@('target_version','1.0.1'), @('target_tag','v1.0.1'), @('release_title','AudioFileForPhone v1.0.1'), @('runtime_zip','AudioFileForPhone-v1.0.1.zip'))) {
        if ((Get-ReleaseField $Target $pair[0]) -cne $pair[1]) { Add-ReleaseRefusal 'TARGET_MISMATCH' ('Fixed target differs: ' + $pair[0]) }
    }
    if ($ActualVersion -cne '1.0.1') { Add-ReleaseRefusal 'RUNTIME_VERSION' 'Actual source runtime version is not 1.0.1.' }
    $steps = Get-ReleaseField $State 'steps'; $last = if ($Phase -ceq 'Publication') { 16 } else { 15 }
    foreach ($n in 1..$last) {
        $step = 'S' + $n.ToString('00')
        if ((Get-ReleaseField (Get-ReleaseField $steps $step) 'status') -cne 'COMPLETED') { Add-ReleaseRefusal 'STEP_INCOMPLETE' ($step + ' is not COMPLETED.') }
    }
    $source = [string](Get-ReleaseField $State 'frozen_release_commit')
    if ($source -cnotmatch '^[a-f0-9]{40}$') { Add-ReleaseRefusal 'SOURCE_NOT_FROZEN' 'STATE has no exact frozen source commit.' }
    if ($null -eq $Candidate) { Add-ReleaseRefusal 'CANDIDATE_MISSING' 'No exact candidate record exists; historical step completion is not package acceptance.' }
    else {
        if ((Get-ReleaseField $Candidate 'schema_version') -ne 1 -or (Get-ReleaseField $Candidate 'kind') -cne 'release_candidate') { Add-ReleaseRefusal 'CANDIDATE_SCHEMA' 'Candidate requires release_candidate/schema1.' }
        foreach ($name in @('target_version','target_tag','release_title','runtime_zip')) { if ([string](Get-ReleaseField $Candidate $name) -cne [string](Get-ReleaseField $Target $name)) { Add-ReleaseRefusal 'CANDIDATE_TARGET' ('Candidate differs: ' + $name) } }
        if ([string](Get-ReleaseField $Candidate 'source_commit') -cne $source -or $source -cnotmatch '^[a-f0-9]{40}$') { Add-ReleaseRefusal 'STALE_SOURCE' 'Candidate source differs from STATE frozen source.' }
        $zip = [string](Get-ReleaseField $Candidate 'runtime_zip_sha256'); $kit = [string](Get-ReleaseField $Candidate 'acceptance_kit_sha256')
        if ($zip -cnotmatch '^[a-f0-9]{64}$' -or $zip -cne [string](Get-ReleaseField $State 'runtime_zip_sha256')) { Add-ReleaseRefusal 'STALE_ZIP' 'ZIP differs from STATE accepted bytes.' }
        if ($kit -cnotmatch '^[a-f0-9]{64}$' -or $kit -cne [string](Get-ReleaseField $State 'acceptance_kit_sha256')) { Add-ReleaseRefusal 'STALE_KIT' 'Kit differs from STATE accepted bytes.' }
        $runtimeKey = $null
        if (@(Get-ReleaseField $Candidate 'assets').Count -ne 4 -or $ActualAssets.Count -ne 4) { Add-ReleaseRefusal 'ASSET_MISSING_OR_DUPLICATE' 'Exactly four declared and actual local assets are required.' }
        try { $runtimeKey = Get-ReleaseInventoryKey @(Get-ReleaseField $Candidate 'runtime_hashes'); if ($runtimeKey -cne (Get-ReleaseInventoryKey $ActualRuntime)) { Add-ReleaseRefusal 'RUNTIME_MISMATCH' 'Actual allowlisted source bytes differ from candidate.' } }
        catch { Add-ReleaseRefusal 'RUNTIME_INVENTORY' $_.Exception.Message }
        foreach ($name in @('AudioFileForPhone-v1.0.1.zip','release-manifest.json','SHA256SUMS.txt','Acceptance-Kit.zip')) {
            $declared = @((Get-ReleaseField $Candidate 'assets') | Where-Object { (Get-ReleaseField $_ 'name') -ceq $name })
            $actual = @($ActualAssets | Where-Object { (Get-ReleaseField $_ 'name') -ceq $name })
            if ($declared.Count -ne 1 -or $actual.Count -ne 1) { Add-ReleaseRefusal 'ASSET_MISSING_OR_DUPLICATE' ($name + ' needs exactly one actual and declared asset.'); continue }
            $hash = [string](Get-ReleaseField $actual[0] 'sha256')
            if ($hash -cnotmatch '^[a-f0-9]{64}$' -or $hash -cne [string](Get-ReleaseField $declared[0] 'sha256') -or
                ($name -ceq 'AudioFileForPhone-v1.0.1.zip' -and $hash -cne $zip) -or ($name -ceq 'Acceptance-Kit.zip' -and $hash -cne $kit)) { Add-ReleaseRefusal 'ASSET_CHANGED' ($name + ' bytes differ from accepted record.') }
        }
        $required = @('core_windows10_ps51','core_windows10_ps7','core_windows11_ps51','core_windows11_ps7','clean_first_run','online_setup','offline_setup_failure','exact_package','one_file','full_collection','physical_shortcut','phone_play_seek')
        if ($Reports.Count -ne $required.Count) { Add-ReleaseRefusal 'EVIDENCE_MISSING_OR_DUPLICATE' 'Exactly the twelve required digest-bound reports are required.' }
        foreach ($id in $required) {
            $rows = @($Reports | Where-Object { (Get-ReleaseField $_ 'gate_id') -ceq $id })
            if ($rows.Count -ne 1) { Add-ReleaseRefusal 'EVIDENCE_MISSING_OR_DUPLICATE' ($id + ' needs one digest-verified report.'); continue }
            if ((Get-ReleaseField $rows[0] 'digest_verified') -isnot [bool] -or -not (Get-ReleaseField $rows[0] 'digest_verified')) { Add-ReleaseRefusal 'REPORT_DIGEST' ($id + ' bytes are unverified.'); continue }
            $report = Get-ReleaseField $rows[0] 'record'
            if ((Get-ReleaseField $report 'schema_version') -ne 1 -or (Get-ReleaseField $report 'kind') -cne 'candidate_acceptance' -or (Get-ReleaseField $report 'gate_id') -cne $id) { Add-ReleaseRefusal 'REPORT_SCHEMA' ($id + ' report identity is invalid.'); continue }
            $reportExit = Get-ReleaseField $report 'exit_code'
            $humanObservation = $id -in @('physical_shortcut','phone_play_seek')
            if ((Get-ReleaseField $report 'status') -cne 'PASSED' -or (-not $humanObservation -and (($reportExit -isnot [int] -and $reportExit -isnot [long]) -or $reportExit -ne 0))) { Add-ReleaseRefusal 'EVIDENCE_NOT_PASSED' ($id + ' is not PASSED with actual required execution/observation evidence.'); continue }
            if ([string](Get-ReleaseField $report 'source_commit') -cne $source -or [string](Get-ReleaseField $report 'runtime_zip_sha256') -cne $zip -or [string](Get-ReleaseField $report 'acceptance_kit_sha256') -cne $kit) { Add-ReleaseRefusal 'STALE_EVIDENCE' ($id + ' source/ZIP/kit differs from final candidate.') }
            try { if ((Get-ReleaseInventoryKey @(Get-ReleaseField $report 'runtime_hashes')) -cne $runtimeKey) { Add-ReleaseRefusal 'STALE_RUNTIME_EVIDENCE' ($id + ' runtime inventory differs.') } } catch { Add-ReleaseRefusal 'REPORT_RUNTIME_INVENTORY' ($id + ' lacks a valid runtime inventory.') }
            $start = [DateTimeOffset]::MinValue; $end = [DateTimeOffset]::MinValue
            $startValue = Get-ReleaseField $report 'started_utc'; $endValue = Get-ReleaseField $report 'ended_utc'
            $startText = if ($startValue -is [DateTime] -or $startValue -is [DateTimeOffset]) { $startValue.ToString('o', [Globalization.CultureInfo]::InvariantCulture) } else { [string]$startValue }
            $endText = if ($endValue -is [DateTime] -or $endValue -is [DateTimeOffset]) { $endValue.ToString('o', [Globalization.CultureInfo]::InvariantCulture) } else { [string]$endValue }
            if (-not [DateTimeOffset]::TryParse($startText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$start) -or
                -not [DateTimeOffset]::TryParse($endText, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$end) -or $end -lt $start -or [string]::IsNullOrWhiteSpace([string](Get-ReleaseField $report 'command'))) { Add-ReleaseRefusal 'REPORT_EXECUTION' ($id + ' lacks actual command/start/end.') }
            $environment = Get-ReleaseField $report 'environment'
            if ($id -cmatch '^core_(windows10|windows11)_(ps51|ps7)$') {
                $os = if ($Matches[1] -ceq 'windows10') { 'Windows10' } else { 'Windows11' }; $shell = if ($Matches[2] -ceq 'ps51') { '^5\.1\.[0-9]+\.[0-9]+$' } else { '^7\.[0-9]+\.[0-9]+(?:\.[0-9]+)?$' }
                $build = [string](Get-ReleaseField $environment 'build')
                if ((Get-ReleaseField $environment 'os_family') -cne $os -or (Get-ReleaseField $environment 'os_type') -cne 'Client' -or (Get-ReleaseField $environment 'architecture') -cne 'x64' -or
                    (Get-ReleaseField $environment 'process_64bit') -isnot [bool] -or (Get-ReleaseField $environment 'process_64bit') -ne $true -or [string](Get-ReleaseField $environment 'shell_version') -cnotmatch $shell -or $build -cnotmatch '^[0-9]+\.[0-9]+$' -or
                    ($os -ceq 'Windows10' -and ((Get-ReleaseField $environment 'display_version') -cne '22H2' -or $build -cnotmatch '^19045\.')) -or
                    ($os -ceq 'Windows11' -and $build -match '^[0-9]+\.' -and [int]($build.Split('.')[0]) -lt 22000)) { Add-ReleaseRefusal 'CLIENT_ENVIRONMENT' ($id + ' requires the actual client/build/x64/recorded shell. Server/Linux cannot substitute.') }
                if ((Get-ReleaseField $report 'coverage') -cne 'core_application') { Add-ReleaseRefusal 'CORE_COVERAGE' ($id + ' startup-only is not core acceptance.') }
            }
            $checks = @(Get-ReleaseField $report 'checks')
            if ($checks.Count -eq 0 -or @($checks | Where-Object { (Get-ReleaseField $_ 'status') -cne 'PASSED' -or [string]::IsNullOrWhiteSpace([string](Get-ReleaseField $_ 'id')) }).Count -ne 0) { Add-ReleaseRefusal 'REQUIRED_CHECK_NOT_PASSED' ($id + ' has missing/failed/NOT_RUN checks.') }
            foreach ($checkId in @(Get-ReleaseRequiredChecks $id)) {
                $checkRows = @($checks | Where-Object { (Get-ReleaseField $_ 'id') -ceq $checkId })
                if ($checkRows.Count -ne 1 -or (Get-ReleaseField $checkRows[0] 'status') -cne 'PASSED' -or
                    [string]::IsNullOrWhiteSpace([string](Get-ReleaseField $checkRows[0] 'expected')) -or
                    [string]::IsNullOrWhiteSpace([string](Get-ReleaseField $checkRows[0] 'observed'))) { Add-ReleaseRefusal 'REQUIRED_CHECK_NOT_PASSED' ($id + ' lacks one actual passing expected/observed check: ' + $checkId) }
            }
            if ($id -in @('one_file','full_collection')) {
                $inputCount = Get-ReleaseField $report 'input_count'
                $validCounts = $true
                foreach ($countName in @('input_count','converted_count','failed_count','unprocessed_count')) {
                    $count = Get-ReleaseField $report $countName
                    if (($count -isnot [int] -and $count -isnot [long]) -or $count -lt 0) { $validCounts = $false }
                }
                if ((Get-ReleaseField $report 'source_unchanged') -isnot [bool] -or (Get-ReleaseField $report 'source_unchanged') -ne $true -or
                    (Get-ReleaseField $report 'media_validated') -isnot [bool] -or (Get-ReleaseField $report 'media_validated') -ne $true -or -not $validCounts -or $inputCount -lt 1 -or
                    (Get-ReleaseField $report 'converted_count') -ne $inputCount -or (Get-ReleaseField $report 'failed_count') -ne 0 -or (Get-ReleaseField $report 'unprocessed_count') -ne 0) { Add-ReleaseRefusal 'COLLECTION_INCOMPLETE' ($id + ' requires counts, media validation and unchanged sources.') }
            }
            if ($id -in @('physical_shortcut','phone_play_seek')) { if ((Get-ReleaseField $report 'evidence_type') -cne 'human_observation' -or [string]::IsNullOrWhiteSpace([string](Get-ReleaseField $report 'observer')) -or (Get-ReleaseField $report 'observed') -cne 'PASSED') { Add-ReleaseRefusal 'HUMAN_OBSERVATION_MISSING' ($id + ' requires an actual observation on final candidate output.') } }
        }
        if ($Phase -ceq 'Publication') {
            $authority = Get-ReleaseField $State 'publication_authorization'
            if ((Get-ReleaseField $authority 'step') -cne 'S17' -or [string](Get-ReleaseField $authority 'source_commit') -cne $source -or [string](Get-ReleaseField $authority 'runtime_zip_sha256') -cne $zip -or (Get-ReleaseField $authority 'target_tag') -cne 'v1.0.1' -or
                (Get-ReleaseField $authority 'owner_started_s17') -isnot [bool] -or (Get-ReleaseField $authority 'owner_started_s17') -ne $true) { Add-ReleaseRefusal 'PUBLICATION_AUTHORIZATION' 'Separate owner-started S17 authority must name these exact accepted bytes.' }
            $authorizedAssets = @(Get-ReleaseField $authority 'assets')
            if ($authorizedAssets.Count -ne 3) { Add-ReleaseRefusal 'PUBLICATION_AUTHORIZATION' 'Exact authority must bind all three public asset digests.' }
            foreach ($assetName in @('AudioFileForPhone-v1.0.1.zip','release-manifest.json','SHA256SUMS.txt')) {
                $authorizedRows = @($authorizedAssets | Where-Object { (Get-ReleaseField $_ 'name') -ceq $assetName })
                $acceptedRows = @((Get-ReleaseField $Candidate 'assets') | Where-Object { (Get-ReleaseField $_ 'name') -ceq $assetName })
                if ($authorizedRows.Count -ne 1 -or $acceptedRows.Count -ne 1 -or (Get-ReleaseField $authorizedRows[0] 'sha256') -cne (Get-ReleaseField $acceptedRows[0] 'sha256')) { Add-ReleaseRefusal 'PUBLICATION_AUTHORIZATION' ($assetName + ' differs from exact owner-authorized public bytes.') }
            }
        }
    }
    return [pscustomobject]@{ schema_version = 1; kind = 'release_gate_result'; phase = $Phase; status = $(if ($failures.Count -eq 0) { 'PASSED' } else { 'REFUSED' }); publication_performed = $false; publication_authority_granted = $false; failures = @($failures.ToArray()) }
}
