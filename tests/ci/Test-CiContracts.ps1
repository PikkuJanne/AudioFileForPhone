<# Focused pure contracts against the actual functions-only runtime helper. No media or TEMP fixture tree is created. #>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^T17-unit-(ps51|ps7)-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$') {
    throw 'EvidencePath must name fresh T17-unit-ps51/ps7-attemptN/finalN/runID_attempt.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
$originalUiCulture = [Threading.Thread]::CurrentThread.CurrentUICulture
$sourceFiles = @('AudioFileForPhone.Helpers.ps1', '.github/scripts/Invoke-CiChecks.ps1', 'tests/ci/Test-CiContracts.ps1',
    '.github/scripts/Test-CiPolicy.ps1', '.github/workflows/windows-ci.yml', '.github/dependencies.json')
$report = [ordered]@{
    schema_version = 1; task = 'T17'; mode = 'pure_runtime_and_ci_contracts'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    cases = @(); status = 'fail'; error = $null
    fixture_tree_created = $false; media_or_test_processes_started = $false; progress_parser_compiled = $false
}

function Assert-CiTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Assert-CiThrows {
    param([scriptblock]$Action, [string]$Pattern)
    $message = $null
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert-CiTest ($null -ne $message -and $message -match $Pattern) "Expected refusal matching '$Pattern'; got '$message'."
}
function Invoke-CiPureCase {
    param([string]$Name, [scriptblock]$Action)
    $row = [ordered]@{ name = $Name; status = 'fail' }
    try { & $Action $row; $row.status = 'pass' } finally { $report.cases += [pscustomobject]$row }
}
function Get-CiTestSource {
    return @($sourceFiles | ForEach-Object {
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Get-CiActualFunction {
    param([string]$Path, [string]$Name)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    Assert-CiTest ($errors.Count -eq 0) 'Actual source must parse before function extraction.'
    $definitions = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $Name }, $false))
    Assert-CiTest ($definitions.Count -eq 1) "Actual source must contain exactly one $Name function."
    return [scriptblock]::Create($definitions[0].Extent.Text)
}

$exitCode = 1
try {
    $report.source_before = Get-CiTestSource
    $helperPath = Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'
    $tokens = $null; $errors = $null
    $helperAst = [Management.Automation.Language.Parser]::ParseFile($helperPath, [ref]$tokens, [ref]$errors)
    Assert-CiTest ($errors.Count -eq 0 -and $null -eq $helperAst.BeginBlock -and $null -eq $helperAst.ProcessBlock) 'Runtime helper must parse as an inert functions-only file.'
    Assert-CiTest (@($helperAst.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count -eq 0) 'Runtime helper cannot execute top-level statements.'
    . $helperPath
    . (Get-CiActualFunction (Join-Path $projectRoot '.github/scripts/Invoke-CiChecks.ps1') 'Assert-CiRunLabel')
    . (Get-CiActualFunction (Join-Path $projectRoot '.github/scripts/Invoke-CiChecks.ps1') 'Assert-CiDependencyRecord')
    . (Get-CiActualFunction (Join-Path $projectRoot '.github/scripts/Invoke-CiChecks.ps1') 'Assert-CiEncodingReport')
    $policyPath = Join-Path $projectRoot '.github/scripts/Test-CiPolicy.ps1'
    $tokens = $null; $errors = $null
    $policyAst = [Management.Automation.Language.Parser]::ParseFile($policyPath, [ref]$tokens, [ref]$errors)
    Assert-CiTest ($errors.Count -eq 0 -and @($policyAst.EndBlock.Statements | Where-Object { $_ -isnot [Management.Automation.Language.FunctionDefinitionAst] }).Count -eq 0) 'CI policy helper must be inert functions-only source.'
    . $policyPath
    $workflowText = Get-Content -LiteralPath (Join-Path $projectRoot '.github/workflows/windows-ci.yml') -Raw -Encoding UTF8
    $manifestText = Get-Content -LiteralPath (Join-Path $projectRoot '.github/dependencies.json') -Raw -Encoding UTF8
    $workflowFiles = @(& git -C $projectRoot ls-files --cached --others --exclude-standard -- '.github/workflows')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate actual workflow inventory.' }
    $workflowFiles = @($workflowFiles | Where-Object { $_ -match '\.(yml|yaml)$' } | Sort-Object -Unique)
    Invoke-CiPureCase 'actual workflow lock and inventory enforce the reviewed read-only CI boundary' {
        $policy = Assert-CiPolicy -WorkflowText $workflowText -ManifestText $manifestText -WorkflowFiles $workflowFiles
        Assert-CiTest ($policy.status -ceq 'pass' -and -not $policy.release_write_path -and -not $policy.secret_contexts) 'Actual CI policy must enforce read-only tests and no release credentials.'
    }
    $policyCases = @(Test-CiPolicyMutations -WorkflowText $workflowText -ManifestText $manifestText -WorkflowFiles $workflowFiles)
    Assert-CiTest ($policyCases.Count -gt 0 -and @($policyCases | Where-Object { $_.status -cne 'pass' }).Count -eq 0) 'Every actual unsafe in-memory policy mutation must be refused.'
    $report.cases += $policyCases

    Invoke-CiPureCase 'ci labels reject traversal metacharacters and zero before writes' {
        Assert-CiRunLabel 'attempt1'; Assert-CiRunLabel 'final12'; Assert-CiRunLabel 'run999999_2'
        foreach ($value in @('', 'attempt0', 'final01', '..\run1', 'run1*', 'run1;exit', 'run1.json', 'run1 run2', 'run1', 'run1_0')) {
            Assert-CiThrows { Assert-CiRunLabel $value } 'label|positive'
        }
    }
    Invoke-CiPureCase 'numeric defaults and unsupported rates are actual runtime preflight contracts' {
        Assert-AudioParameters -BitrateKbps 64 -MaxBaseLength 60
        foreach ($rate in @(7, 63, 65, 321)) { Assert-CiThrows { Assert-AudioParameters -BitrateKbps $rate -MaxBaseLength 60 } 'BitrateKbps' }
        foreach ($length in @(23, 181)) { Assert-CiThrows { Assert-AudioParameters -BitrateKbps 64 -MaxBaseLength $length } 'MaxBaseLength' }
    }
    Invoke-CiPureCase 'dependency records reject changed pins failed status and invented extraction hashes' {
        $lock = Get-Content -LiteralPath (Join-Path $projectRoot '.github/dependencies.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $valid = [pscustomobject]@{
            schema_version = 1; task = 'T17'; status = 'pass'
            ffmpeg = [pscustomobject]@{ version = $lock.ffmpeg.version; archive_url = $lock.ffmpeg.archive_url; archive_sha256 = $lock.ffmpeg.archive_sha256
                ffmpeg_sha256 = $lock.ffmpeg.ffmpeg_sha256; ffprobe_sha256 = $lock.ffmpeg.ffprobe_sha256
                extraction = [pscustomobject]@{ file_count = $lock.ffmpeg.archive_file_count; inventory_sha256 = $lock.ffmpeg.inventory_sha256 } }
            analyzer = [pscustomobject]@{ version = $lock.analyzer.version; archive_url = $lock.analyzer.archive_url; archive_sha256 = $lock.analyzer.archive_sha256
                module_manifest_sha256 = $lock.analyzer.module_manifest_sha256
                extraction = [pscustomobject]@{ file_count = $lock.analyzer.archive_file_count; inventory_sha256 = $lock.analyzer.inventory_sha256 } }
        }
        Assert-CiDependencyRecord -Record $valid -Lock $lock
        foreach ($mutation in @({ param($r) $r.status = 'fail' }, { param($r) $r.ffmpeg.archive_sha256 = '0' * 64 },
            { param($r) $r.analyzer.version = '0.0.0' }, { param($r) $r.analyzer.extraction.inventory_sha256 = '0' * 64 },
            { param($r) $r.ffmpeg.ffmpeg_sha256 = '0' * 64 }, { param($r) $r.analyzer.module_manifest_sha256 = '0' * 64 })) {
            $changed = $valid | ConvertTo-Json -Depth 10 | ConvertFrom-Json
            & $mutation $changed
            Assert-CiThrows { Assert-CiDependencyRecord -Record $changed -Lock $lock } 'contract|lock'
        }
    }
    Invoke-CiPureCase 'encoding CI reports require complete exact planned results actual app groups and release integrity' {
        # In-memory report fixtures exercise the CI gate only, never conversion.
        $rows = @(); $ordinal = 0
        foreach ($group in @(@{name='required';count=252}, @{name='extra';count=180}, @{name='multichannel';count=36}, @{name='codec';count=25}, @{name='artwork';count=2})) {
            for ($index=0; $index -lt $group.count; $index++) {
                $rows += [pscustomobject]@{ id=('pure-' + $ordinal); group=$group.name; status='pass'; full_decode=$true
                    requested_bitrate_kbps=64; planned_sample_rate=44100; planned_channels=2
                    observed_bitrate_bps=64000; observed_sample_rate=44100; observed_channels=2 }
                $ordinal++
            }
        }
        $valid = [pscustomobject]@{
            schema_version=1; task='S09'; status='pass'; mode='real_windows_encoding_compatibility'
            source_unchanged=$true; synthetic_unchanged=$true; descendant_release_proved=$true; cleanup_verified=$true
            copied_bytes_unchanged=$true; parent_path_unchanged=$true; temp_exclusively_reserved=$true; marker_create_new=$true
            matrix=$rows; app_runs=@(8,64,144,192 | ForEach-Object { [pscustomobject]@{rate=$_;status='pass';converted=1;manifest_audio_plans_verified=$true;observed_audio_verified=$true;full_decode=$true;PATH='empty';config_created=$false} })
        }
        Assert-CiEncodingReport -Record $valid
        foreach ($mutation in @(
            { param($r) $r.matrix = @($r.matrix | Select-Object -First 494) },
            { param($r) $r.app_runs = @($r.app_runs | Select-Object -First 3) },
            { param($r) $r.matrix[0].observed_bitrate_bps = 32000 },
            { param($r) $r.matrix[0].observed_sample_rate = 48000 },
            { param($r) $r.matrix[0].observed_channels = 1 },
            { param($r) $r.matrix[0].id = $r.matrix[1].id },
            { param($r) $r.matrix[0].full_decode = $false },
            { param($r) $r.matrix[0].group = 'extra' },
            { param($r) $r.app_runs[0].manifest_audio_plans_verified = $false },
            { param($r) $r.app_runs[0].converted = 0 },
            { param($r) $r.app_runs[0].rate = 16 },
            { param($r) $r.app_runs[0].config_created = $true },
            { param($r) $r.source_unchanged = $false },
            { param($r) $r.synthetic_unchanged = $false },
            { param($r) $r.descendant_release_proved = $false },
            { param($r) $r.cleanup_verified = $false }
        )) {
            $changed = $valid | ConvertTo-Json -Depth 8 | ConvertFrom-Json
            & $mutation $changed
            Assert-CiThrows { Assert-CiEncodingReport -Record $changed } 'Encoding|encoding'
        }
    }
    Invoke-CiPureCase 'real calendar dates and fallback remain invariant across cultures' {
        $fallback = [datetime]'2031-03-04T12:00:00'
        foreach ($culture in @('en-US', 'de-DE', 'ar-SA')) {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($culture)
            foreach ($row in @(@{ source = '2024-02-29 - Leap.mp3'; expected = '2024-02-29 - Leap' },
                @{ source = '1900-02-29 - False.mp3'; expected = '2031-03-04 - 1900-02-29 - False' },
                @{ source = 'Undated.mp3'; expected = '2031-03-04 - Undated' })) {
                $plan = Get-AudioNamePlan -SourceRelativePath $row.source -LastWriteTime $fallback
                Assert-CiTest ($plan.BaseName -ceq $row.expected) 'Actual name date/fallback differs from the calendar contract.'
            }
        }
    }
    Invoke-CiPureCase 'Unicode normalization and filtering keep equivalent source titles equivalent' {
        $composed = [string][char]0xE9; $decomposed = 'e' + [char]0x301
        $one = Get-AudioNamePlan -SourceRelativePath ('2024-01-02 - ' + $composed + '.mp3') -LastWriteTime ([datetime]'2031-03-04')
        $two = Get-AudioNamePlan -SourceRelativePath ('2024-01-02 - ' + $decomposed + '.m4a') -LastWriteTime ([datetime]'2031-03-04')
        Assert-CiTest ($one.BaseName -ceq $two.BaseName -and @($two.Warnings).Count -gt 0) 'Actual NFC equivalence must preserve allocation warnings.'
        $filtered = Get-AudioNamePlan -SourceRelativePath '2024-01-02 - O''Brien & [x].mp3' -LastWriteTime ([datetime]'2031-03-04')
        Assert-CiTest ($filtered.BaseName -ceq '2024-01-02 - OBrien x') 'Actual punctuation policy changed.'
        Assert-CiThrows { Get-AudioNamePlan -SourceRelativePath ('Bad' + [char]0xD800 + '.mp3') -LastWriteTime ([datetime]'2031-03-04') } 'Unicode'
    }
    Invoke-CiPureCase 'collision suffix and supplementary scalars fit the complete UTF16 budget' {
        $letter = [char]::ConvertFromUtf32(0x10400)
        $plan = Get-AudioNamePlan -SourceRelativePath ('2024-01-02 - abcdefghij' + $letter + '.mp3') -LastWriteTime ([datetime]'2031-03-04') -MaxBaseLength 24
        Assert-CiTest ($plan.BaseName -ceq '2024-01-02 - abcdefghij') 'Actual clipping cannot split a surrogate pair.'
        $collision = Get-AudioNamePlan -SourceRelativePath ('2024-01-02 - ' + ('x' * 100) + '.mp3') -LastWriteTime ([datetime]'2031-03-04') -MaxBaseLength 24 -Counter 100
        Assert-CiTest ($collision.BaseName.Length -eq 24 -and $collision.BaseName.EndsWith(' (100)')) 'Complete collision suffix must fit the requested budget.'
    }
    Invoke-CiPureCase 'pure batch plans are deterministic and never create their virtual trees' {
        $virtualInput = 'C:\AFP-CI-virtual-' + [guid]::NewGuid().ToString('N')
        $virtualOutput = 'C:\AFP-CI-output-' + [guid]::NewGuid().ToString('N')
        $files = @('2024-01-02 - Same.mp3', '2024-01-02 - Same.m4a', 'sub\2024-01-02 - Same.ogg') | ForEach-Object {
            [pscustomobject]@{ FullName = Join-Path $virtualInput $_; LastWriteTime = [datetime]'2031-03-04' }
        }
        $first = @(Get-AudioBatchNamePlan -Files $files -InputFolder $virtualInput -OutputRoot $virtualOutput)
        [Array]::Reverse($files)
        $second = @(Get-AudioBatchNamePlan -Files $files -InputFolder $virtualInput -OutputRoot $virtualOutput)
        $mapping1 = @($first | Select-Object SourceRelativePath,OutputRelativePath) | ConvertTo-Json -Compress
        $mapping2 = @($second | Select-Object SourceRelativePath,OutputRelativePath) | ConvertTo-Json -Compress
        Assert-CiTest ($mapping1 -ceq $mapping2 -and @($first | Where-Object { $_.BaseName.EndsWith(' (2)') }).Count -eq 1) 'Actual mappings must allocate case/extension collisions deterministically.'
        Assert-CiTest (-not (Test-Path -LiteralPath $virtualInput) -and -not (Test-Path -LiteralPath $virtualOutput)) 'Pure planning cannot create its virtual input/output roots.'
        Assert-CiThrows { Get-AudioBatchNamePlan -Files @($files[0], $files[0]) -InputFolder $virtualInput -OutputRoot $virtualOutput } 'Duplicate'
    }
    Invoke-CiPureCase 'path boundaries reject prefix siblings traversal device and reserved components' {
        Assert-CiTest (Test-AudioPathWithin -Path 'C:\CI\Input\sub\a.mp3' -Parent 'C:\CI\Input') 'Actual contained path must be accepted.'
        Assert-CiTest (-not (Test-AudioPathWithin -Path 'C:\CI\Input2\a.mp3' -Parent 'C:\CI\Input')) 'Prefix sibling cannot be accepted as contained.'
        foreach ($value in @('..\a.mp3', '.\a.mp3', 'C:\a.mp3', '\a.mp3')) {
            Assert-CiThrows { Get-AudioNamePlan -SourceRelativePath $value -LastWriteTime ([datetime]'2031-03-04') } 'relative|traversal'
        }
        foreach ($value in @('C:\CI\CON\a.mp3', 'C:\CI\bad.\a.mp3', '\\?\C:\CI\a.mp3')) { Assert-CiThrows { Assert-AudioPathComponents -Path $value } 'component|device' }
    }
    Invoke-CiPureCase 'machine progress waits for complete records and recovers after bounded overflow' {
        $parser = New-AudioProgressParser
        $report.progress_parser_compiled = $true
        $parser.Add('out_time_us=1250000'); Assert-CiTest ($null -eq $parser.Snapshot) 'Partial records cannot publish progress.'
        $parser.Add("`r`nprogress=continue`r`n")
        Assert-CiTest ($parser.Snapshot.MediaSeconds -eq 1.25 -and $parser.Snapshot.Sequence -eq 1) 'Actual chunked record must parse microseconds.'
        $parser.Add(('X' * 20000) + "`nprogress=end`n")
        Assert-CiTest ($parser.DroppedRecords -gt 0 -and $parser.MaximumBufferedChars -le 8192) 'Actual overflow must discard without unbounded storage.'
        $parser.Add("out_time=02:15:45.125`nprogress=end`n")
        Assert-CiTest ($parser.Snapshot.MediaSeconds -eq 8145.125) 'Actual parser must recover and retain hour-plus timestamps.'
    }
    Invoke-CiPureCase 'unknown durations stay indeterminate and encoder end stays below publication100' {
        $parser = New-AudioProgressParser; $parser.Add("out_time_us=3605000000`nprogress=end`n")
        foreach ($value in @($null, 'N/A', 0, -1, [double]::NaN, [double]::PositiveInfinity)) {
            Assert-CiTest ((Get-AudioProgressState -Record $parser.Snapshot -DurationSeconds $value).PercentComplete -eq -1) 'Invalid durations cannot invent numeric progress.'
        }
        Assert-CiTest ((Get-AudioProgressState -Record $parser.Snapshot -DurationSeconds 3605).PercentComplete -eq 99) 'Encoder end cannot establish validated publication success.'
        Assert-CiTest ((Get-AudioProgressState -Record $parser.Snapshot -DurationSeconds 7210).PercentComplete -eq 50) 'Actual media progress must compute against trustworthy duration.'
    }
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message }
finally {
    [Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
    [Threading.Thread]::CurrentThread.CurrentUICulture = $originalUiCulture
    $report.source_after = Get-CiTestSource
    $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
    if (-not $report.source_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    $report.completed_utc = [DateTime]::UtcNow.ToString('o')
    $item = Get-Item -LiteralPath $evidenceParent -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Refusing evidence through a reparse ancestor.' }
        $item = $item.Parent
    }
    $stream = [IO.File]::Open($evidenceFullPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = New-Object IO.StreamWriter($stream, [Text.Encoding]::UTF8)
        try { $writer.WriteLine(($report | ConvertTo-Json -Depth 12)); $writer.Flush() } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}
Write-Host "T17 pure contracts: $($report.status); cases=$($report.cases.Count); sources unchanged=$($report.source_unchanged)"
exit $exitCode
