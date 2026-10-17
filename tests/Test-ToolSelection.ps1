<#
S04 deterministic selection, deliberate config persistence and real fresh-process
conversion. All config, copied tools/runtime, synthetic audio and raw child
diagnostics stay in one exclusively reserved token-owned TEMP tree. The active
S04 and historical T17 CI evidence contracts are create-new. No user config,
ordinary Music folder, source media, persistent PATH or registry is changed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [string]$FfmpegPath = 'C:\ffmpeg\bin\ffmpeg.exe',
    [string]$FfprobePath = 'C:\ffmpeg\bin\ffprobe.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$edition = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'ps51' } else { 'ps7' }
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = Split-Path -Parent $evidenceFullPath
$leaf = Split-Path -Leaf $evidenceFullPath
$activeReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1.0.1/evidence') -and $leaf -cmatch "^S04-toolselection-$edition-(attempt|final)[1-9][0-9]*\.json$"
$ciReport = $evidenceParent -ieq (Join-Path $projectRoot 'docs/codex-v1/evidence') -and $leaf -cmatch "^T17-toolselection-$edition-((attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$"
if (-not ($activeReport -or $ciReport)) { throw 'Use a fresh S04-toolselection active report or the historical T17-toolselection CI report.' }
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; select a fresh label.' }
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AFP-S04-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerFile = Join-Path $testRoot '.s04-owner'; $ownerToken = [guid]::NewGuid().ToString('N')
$created = $false; $releaseProved = $true; $exitCode = 1
$originalPath = $env:PATH
$fixtures = New-Object 'System.Collections.Generic.List[string]'
$sourcePaths = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-ToolSelection.ps1', '.github/scripts/Invoke-CiChecks.ps1')
$nativeRuns = New-Object 'System.Collections.Generic.List[object]'
$originalNative = $null
$windows = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$shellPath = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
$report = [ordered]@{
    schema_version = 1; task = $(if ($ciReport) { 'T17' } else { 'S04' }); mode = 'real_windows_tool_selection_and_config'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString(); windows_build = $windows.CurrentBuildNumber + '.' + $windows.UBR
    windows_edition = $windows.EditionID; display_version = $windows.DisplayVersion; process_64bit = [Environment]::Is64BitProcess
    inherited_console_output_codepage = [Console]::OutputEncoding.CodePage
    ordinary_music_access = $false; owner_media_access = $false; user_config_read_or_written = $false; physical_manual_evidence = $false
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    temp_exclusively_reserved = $false; marker_create_new = $false; copied_bytes_unchanged = $false
    cleanup_verified = $false; descendant_release_proved = $false; native_runs = @(); tools = @(); cases = @()
    status = 'fail'; error = $null
}
function Assert-True { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw $Message } }
function Assert-NoReparse {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while (-not [string]::IsNullOrEmpty($cursor)) {
        $item = Get-Item -LiteralPath $cursor -Force
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
}
function Assert-SafeTree {
    param([string]$Root)
    Assert-NoReparse $Root
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse child refused.'
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
}
function New-Directory { param([string]$Name); $path = Join-Path $testRoot $Name; [IO.Directory]::CreateDirectory($path) | Out-Null; return $path }
function Write-NewText {
    param([string]$Path, [string]$Text, [switch]$Utf8Bom)
    Assert-NoReparse (Split-Path -Parent $Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $encoding = New-Object Text.UTF8Encoding($Utf8Bom.IsPresent)
        $preamble = $encoding.GetPreamble(); $stream.Write($preamble, 0, $preamble.Length)
        $bytes = $encoding.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length)
    }
    finally { $stream.Dispose() }
}
function Get-Inventory {
    param([string[]]$Paths, [string]$Root)
    return @($Paths | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Root $_ }
        [pscustomobject]@{ relative_path = $path.Substring($Root.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}
function Add-Fixture {
    param([string]$Path)
    $fixtures.Add($Path)
    $report.synthetic_before += Get-Inventory @($Path) $testRoot
}
function Invoke-Case {
    param([string]$Name, [string]$Acceptance, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; acceptance_case = $Acceptance; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' } finally { $report.cases += [pscustomobject]$case }
}
function Assert-Throws {
    param([scriptblock]$Body, [string]$Pattern)
    $message = $null
    try { & $Body | Out-Null } catch { $message = $_.Exception.Message }
    Assert-True (-not [string]::IsNullOrWhiteSpace($message) -and $message -match $Pattern) ('Expected bounded failure /' + $Pattern + '/; observed: ' + $message)
    return $message.Replace($testRoot, '<OWNED_TEMP>')
}
function Invoke-WithPath {
    param([string]$PathValue, [scriptblock]$Body)
    $saved = $env:PATH
    try { $env:PATH = $PathValue; & $Body } finally { $env:PATH = $saved }
}
function Invoke-TrackedNative {
    param(
        [Parameter(Mandatory = $true)][string]$ExecutablePath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Arguments,
        [int]$MaxStdoutChars = 1048576, [int]$MaxStderrChars = 65536,
        [AllowNull()][object]$Cancellation = (Get-AudioCancellationContext),
        [AllowNull()][scriptblock]$ProgressCallback, [AllowNull()][object]$ProgressDurationSeconds,
        [AllowNull()][object]$ProgressParser, [AllowNull()][object]$ProgressCallbackState,
        [int]$TimeoutMilliseconds = 0, [string]$Operation = 'Native operation', [int]$PipeDrainTimeoutMilliseconds = 5000
    )
    try {
        $native = & $script:originalNative @PSBoundParameters
        if ($native.ProcessReleased -isnot [bool] -or -not $native.ProcessReleased) { $script:releaseProved = $false }
        $nativeRuns.Add([pscustomobject]@{
            operation = $native.Operation; status = $native.Status; exit_code = $native.ExitCode
            elapsed_ms = $native.ElapsedMilliseconds; timeout_ms = $native.TimeoutMilliseconds
            process_released = $native.ProcessReleased; pipe_drain_completed = $native.PipeDrainCompleted
        })
        return $native
    } catch { $script:releaseProved = $false; throw }
}
function Assert-NativeSuccess {
    param([object]$Result)
    Assert-True ($Result.Status -ceq 'Completed' -and $Result.ExitCode -eq 0 -and $Result.ProcessReleased -and $Result.PipeDrainCompleted -and -not $Result.StdoutTruncated -and -not $Result.StderrTruncated) ('Expected successful fully drained process: ' + $Result.Status + ' ' + $Result.Error + ' ' + $Result.Stderr)
}
function Get-Literal { param([string]$Value); return "'" + $Value.Replace("'", "''") + "'" }
function Invoke-Child {
    param([string]$Label, [string]$Code, [string]$Path = '')
    $driver = Join-Path $testRoot ($Label + '.ps1')
    # BOM-marked UTF-8 preserves PS5.1 source characters; -File uses ordinary
    # text streams instead of EncodedCommand's serialized information stream.
    Write-NewText $driver $Code -Utf8Bom; Add-Fixture $driver
    $native = Invoke-WithPath $Path { Invoke-AudioNativeProcess -ExecutablePath $shellPath -Arguments @('-NoLogo', '-NoProfile', '-NonInteractive', '-OutputFormat', 'Text', '-ExecutionPolicy', 'RemoteSigned', '-File', $driver) -TimeoutMilliseconds 120000 -Operation ('S04 child ' + $Label) -MaxStdoutChars 1048576 -MaxStderrChars 65536 }
    Assert-NativeSuccess $native
    Write-NewText (Join-Path $testRoot ($Label + '.log')) ($native.Stdout + "`n" + $native.Stderr)
    return $native
}
function New-PairCopy {
    param([string]$Directory)
    foreach ($row in @(@{source=$ffmpeg;name='ffmpeg.exe'}, @{source=$ffprobe;name='ffprobe.exe'})) {
        $destination = Join-Path $Directory $row.name
        Copy-Item -LiteralPath $row.source -Destination $destination
        Assert-True ((Get-FileHash -LiteralPath $destination).Hash -ceq (Get-FileHash -LiteralPath $row.source).Hash) 'Copied external executable must retain exact bytes.'
        Add-Fixture $destination
    }
}
try {
    Assert-NoReparse $evidenceParent; Assert-NoReparse $tempParent
    $report.source_before = Get-Inventory $sourcePaths $projectRoot
    . (Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1')
    Initialize-AudioDirectoryInterop
    Assert-True ([AudioFileForPhone.PreflightDirectory]::CreateDirectoryW($testRoot, [IntPtr]::Zero)) 'Exact TEMP directory must be reserved exclusively.'
    $created = $true; $report.temp_exclusively_reserved = $true
    Write-NewText $ownerFile $ownerToken; Add-Fixture $ownerFile; $report.marker_create_new = $true
    $appRoot = New-Directory 'App [literal]'; $emptyApp = New-Directory 'EmptyApp'; $configRoot = New-Directory 'Config [literal]'
    foreach ($name in @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1')) {
        $copy = Join-Path $appRoot $name; Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $copy
        Assert-True ((Get-FileHash -LiteralPath $copy).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $projectRoot $name)).Hash) 'Runtime copies must preserve source bytes.'
        Add-Fixture $copy
    }
    $report.copied_bytes_unchanged = $true
    . (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')
    $script:originalNative = (Get-Command Invoke-AudioNativeProcess -CommandType Function).ScriptBlock
    Set-Item -LiteralPath Function:script:Invoke-AudioNativeProcess -Value ${function:Invoke-TrackedNative}
    $ffmpeg = (Resolve-Path -LiteralPath $FfmpegPath).ProviderPath; $ffprobe = (Resolve-Path -LiteralPath $FfprobePath).ProviderPath
    foreach ($tool in @($ffmpeg, $ffprobe)) {
        Assert-NoReparse $tool
        $identity = Invoke-AudioNativeProcess -ExecutablePath $tool -Arguments @('-version') -TimeoutMilliseconds 15000 -Operation 'S04 external fixture identity'
        Assert-NativeSuccess $identity
        $report.tools += [pscustomobject]@{ name = [IO.Path]::GetFileName($tool); sha256 = (Get-FileHash -LiteralPath $tool).Hash.ToLowerInvariant(); version = ($identity.Stdout -split '\r?\n')[0] }
    }
    $selected = New-Directory ("Selected tools [x] O'Brien " + [char]0xE4 + [char]0x65E5)
    New-PairCopy $selected
    $absentConfig = Join-Path $configRoot 'Absent [x].json'; $config = Join-Path $configRoot 'Remember [x].json'
    $pathDirectory = Split-Path -Parent $ffmpeg
    Assert-True ((Split-Path -Parent $ffprobe) -ieq $pathDirectory) 'Real fixture tools must share one supplied external directory.'
    Invoke-Case 'explicit config location is public deterministic and read-only when absent' 'S04-A3' {
        param($case)
        $default = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'AudioFileForPhone\config.json'
        Assert-True ((Get-AudioConfigPath -ConfigPath $absentConfig) -ceq $absentConfig) 'ConfigPath must select the explicit owned config location.'
        Assert-True ($null -eq (Read-AudioToolConfig -ConfigPath $absentConfig) -and -not (Test-Path -LiteralPath $absentConfig)) 'An absent config read must not create settings.'
        $case['default_path_from_Windows_API_only_not_accessed'] = $default; $case['explicit_config_exists'] = $false
    }
    Invoke-Case 'explicit external Unicode literal pair works without PATH and never remembers implicitly' 'S04-A1,S04-A2,S04-A3' {
        param($case)
        $selection = Invoke-WithPath '' { Resolve-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $absentConfig -ScriptDirectory $emptyApp }
        Assert-True ($selection.Origin -ceq 'Explicit' -and $selection.Directory -ceq $selected -and $selection.Ffmpeg.Path -ceq (Join-Path $selected 'ffmpeg.exe') -and $selection.Ffprobe.Path -ceq (Join-Path $selected 'ffprobe.exe')) 'Explicit literal directory must provide the exact validated pair and disclosed origin.'
        Assert-True (-not (Test-Path -LiteralPath $absentConfig)) 'Resolution must not persist the explicit selection.'
        $case['origin'] = $selection.Origin; $case['path_edge_cases'] = @('spaces','brackets','apostrophe','Unicode'); $case['PATH'] = 'empty'
    }
    Invoke-Case 'deliberate validated atomic save preserves unrelated fields and fresh process loads it' 'S04-A2,S04-A3' {
        param($case)
        Write-NewText $config ([ordered]@{schema_version=1;ffmpeg_directory=$selected;unrelated=[ordered]@{keep=@(1,'two')}} | ConvertTo-Json -Depth 5)
        $saved = Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $config
        $document = Read-AudioToolConfig -ConfigPath $config
        Assert-True ($saved.Origin -ceq 'Saved' -and $document.ffmpeg_directory -ceq $selected -and ($document.unrelated.keep -join '|') -ceq '1|two') 'Deliberate save must validate and preserve unrelated schema1 settings.'
        Assert-True (@(Get-ChildItem -LiteralPath $configRoot -File).Count -eq 1) 'Atomic save must leave no staging file.'
        $firstSavePath = Join-Path $configRoot 'FirstSave\config.json'
        $firstSave = Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $firstSavePath
        $firstDocument = Read-AudioToolConfig -ConfigPath $firstSavePath
        Assert-True ($firstSave.Origin -ceq 'Saved' -and $firstDocument.schema_version -eq 1 -and $firstDocument.ffmpeg_directory -ceq $selected -and @($firstDocument.PSObject.Properties).Count -eq 2) 'A first deliberate save must create a missing owned config parent and only the minimal schema1 tool selection.'
        $code = '$ErrorActionPreference="Stop"' + "`n. " + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.Helpers.ps1')) + "`n" +
            '$choice=Resolve-AudioToolSelection -ConfigPath ' + (Get-Literal $config) + ' -ScriptDirectory ' + (Get-Literal $emptyApp) + "`n" +
            'if($choice.Origin -cne "Saved" -or $choice.Directory -cne ' + (Get-Literal $selected) + '){throw "Fresh process lost selection"}' + "`n" +
            'Write-Output "S04_FRESH_SAVED_PASS"'
        $native = Invoke-Child 'FreshSaved' $code
        Assert-True ($native.Stdout.Contains('S04_FRESH_SAVED_PASS')) 'Fresh independent shell must load the deliberate persisted choice.'
        $case['fresh_process_exit'] = $native.ExitCode; $case['unrelated_fields_preserved'] = $true; $case['atomic_staging_remaining'] = 0; $case['first_save_created_minimal_owned_config'] = $true
    }
    Invoke-Case 'explicit valid selection overrides stale corrupt and newer saved state without mutation' 'S04-A1,S04-A3' {
        param($case)
        $observations = @()
        foreach ($row in @(@{name='Corrupt';text='{"broken"'}, @{name='Newer';text='{"schema_version":2,"ffmpeg_directory":"C:\\unused"}'}, @{name='Stale';text=([ordered]@{schema_version=1;ffmpeg_directory=(Join-Path $testRoot 'NotInstalled')} | ConvertTo-Json)})) {
            $path = Join-Path $configRoot ($row.name + '.json'); Write-NewText $path $row.text
            $before = (Get-FileHash -LiteralPath $path).Hash
            $choice = Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path -ScriptDirectory $appRoot }
            Assert-True ($choice.Origin -ceq 'Explicit' -and (Get-FileHash -LiteralPath $path).Hash -ceq $before) 'Valid explicit choice must recover the current run without rewriting saved state.'
            $observations += [pscustomobject]@{condition=$row.name;origin=$choice.Origin;bytes_unchanged=$true}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'invalid explicit selection and stale saved selection never fall back' 'S04-A1,S04-A3' {
        param($case)
        $invalid = Join-Path $testRoot 'Missing explicit'
        $case['explicit_failure'] = Assert-Throws { Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -FfmpegDirectory $invalid -ConfigPath $config -ScriptDirectory $appRoot } } 'Invalid explicit FFmpeg selection'
        $stale = Join-Path $configRoot 'Stale.json'; $before = (Get-FileHash -LiteralPath $stale).Hash
        $case['saved_failure'] = Assert-Throws { Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -ConfigPath $stale -ScriptDirectory $appRoot } } 'Saved FFmpeg selection is unavailable'
        Assert-True ((Get-FileHash -LiteralPath $stale).Hash -ceq $before) 'A stale choice failure must preserve its bytes.'
        $case['failed_save'] = Assert-Throws { Save-AudioToolSelection -FfmpegDirectory $invalid -ConfigPath $config } 'Invalid|missing|directory|selection'
        Assert-True ((Read-AudioToolConfig -ConfigPath $config).ffmpeg_directory -ceq $selected) 'An invalid save must leave the previous successful choice.'
    }
    Invoke-Case 'corrupt newer schema invalid types and oversize configs are preserved and actionable' 'S04-A3' {
        param($case)
        $observations = @()
        $rows = @(
            @{name='BadJson';text='{"schema_version":'}, @{name='NewSchema';text='{"schema_version":99,"ffmpeg_directory":"C:\\future","future":true}'},
            @{name='StringSchema';text='{"schema_version":"1","ffmpeg_directory":"C:\\tool"}'}, @{name='BooleanSchema';text='{"schema_version":true,"ffmpeg_directory":"C:\\tool"}'},
            @{name='DirectoryArray';text='{"schema_version":1,"ffmpeg_directory":["C:\\tool"]}'}, @{name='DirectoryNumber';text='{"schema_version":1,"ffmpeg_directory":12}'},
            @{name='Relative';text='{"schema_version":1,"ffmpeg_directory":"relative"}'}, @{name='Null';text='null'}, @{name='Array';text='[]'}, @{name='Oversize';text=(' ' * 65537)},
            @{name='DuplicateKey';text='{"schema_version":1,"schema_version":1,"ffmpeg_directory":"C:\\tool"}'}, @{name='EscapedKey';text='{"schema_version":1,"schema\u005fversion":1,"ffmpeg_directory":"C:\\tool"}'},
            @{name='CaseCollision';text='{"schema_version":1,"ffmpeg_directory":"C:\\tool","unrelated":{"name":1,"Name":2}}'},
            @{name='JsonComment';text='{"schema_version":1,/* invalid JSON comment */"ffmpeg_directory":"C:\\tool"}'},
            @{name='TrailingComma';text='{"schema_version":1,"ffmpeg_directory":"C:\\tool",}'}, @{name='ArrayTrailingComma';text='{"schema_version":1,"ffmpeg_directory":"C:\\tool","unknown":[1,] }'}
        )
        foreach ($row in $rows) {
            $path = Join-Path $configRoot ($row.name + '.json'); Write-NewText $path $row.text
            $before = (Get-FileHash -LiteralPath $path).Hash
            $read = Assert-Throws { Read-AudioToolConfig -ConfigPath $path } 'Invalid tool configuration|configuration|schema|65536|64'
            $save = Assert-Throws { Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path } 'Invalid tool configuration|configuration|schema|65536|64'
            Assert-True ((Get-FileHash -LiteralPath $path).Hash -ceq $before) 'Invalid config must survive read/save unchanged.'
            $observations += [pscustomobject]@{condition=$row.name;read_failure=$read;save_failure=$save;bytes_unchanged=$true}
        }
        $case['observations'] = $observations
    }
    Invoke-Case 'read-only config refuses persistence while explicit current-run choice stays valid' 'S04-A2,S04-A3' {
        param($case)
        $path = Join-Path $configRoot 'ReadOnly.json'; Copy-Item -LiteralPath $config -Destination $path
        $before = (Get-FileHash -LiteralPath $path).Hash; $attributes = [IO.File]::GetAttributes($path)
        try {
            [IO.File]::SetAttributes($path, ($attributes -bor [IO.FileAttributes]::ReadOnly))
            $case['failure'] = Assert-Throws { Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path } 'remember|writ|read.only|persist|configuration|save'
            $choice = Invoke-WithPath '' { Resolve-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path -ScriptDirectory $emptyApp }
            Assert-True ($choice.Origin -ceq 'Explicit' -and (Get-FileHash -LiteralPath $path).Hash -ceq $before) 'Read-only persistence failure must leave a usable explicit selection and unchanged stored bytes.'
            $case['current_run_origin'] = $choice.Origin; $case['bytes_unchanged'] = $true
        } finally { [IO.File]::SetAttributes($path, $attributes) }
    }
    Invoke-Case 'external edit survives save and a destination held against replacement fails unchanged' 'S04-A3' {
        param($case)
        $path = Join-Path $configRoot 'ExternallyEdited.json'
        Write-NewText $path ([ordered]@{schema_version=1;ffmpeg_directory=$selected;external_setting='newest external edit';nested=[ordered]@{keep=$true}} | ConvertTo-Json -Depth 5)
        Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path | Out-Null
        $document = Read-AudioToolConfig -ConfigPath $path
        Assert-True ($document.external_setting -ceq 'newest external edit' -and $document.nested.keep -eq $true) 'A deliberate save must preserve the existing external settings.'
        $before = (Get-FileHash -LiteralPath $path).Hash
        $guard = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try { $case['locked_destination_failure'] = Assert-Throws { Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path } 'remember|writ|persist|configuration|save|sharing|access|another process' }
        finally { $guard.Dispose() }
        Assert-True ((Get-FileHash -LiteralPath $path).Hash -ceq $before) 'A destination replacement failure must preserve complete previous config bytes.'
        Assert-True (@(Get-ChildItem -LiteralPath $configRoot -File | Where-Object {$_.Name -like '*.lock' -or $_.Name -like '*.tmp'}).Count -eq 0) 'Failed atomic persistence must release its lock and temporary file.'
        $case['external_fields_preserved'] = $true; $case['locked_bytes_unchanged'] = $true
    }
    Invoke-Case 'remembering one field preserves unknown JSON dates precision escapes and exact lexemes' 'S04-A3' {
        param($case)
        $path = Join-Path $configRoot 'ExactUnknownLexemes.json'
        $oldToken = ConvertTo-Json -InputObject $pathDirectory -Compress
        $newToken = ConvertTo-Json -InputObject $selected -Compress
        $prefix = '{"schema_version":1, "ffmpeg_directory" : '
        $suffix = ',"untouched":{"date":"2024-01-02T03:04:05.1234567+05:30","number":123456789.12345678901234567890,"string":"keep \\ \u00e4 \/ \" exactly","ffmpeg_directory":' + $oldToken + '},"array":[null,true,1e-09]}'
        Write-NewText $path ($prefix + $oldToken + $suffix)
        Save-AudioToolSelection -FfmpegDirectory $selected -ConfigPath $path | Out-Null
        $savedText = [IO.File]::ReadAllText($path).TrimEnd([char]13,[char]10)
        Assert-True ($savedText -ceq ($prefix + $newToken + $suffix)) 'Saving the top-level directory must preserve every unrelated JSON character including offset/fraction date, decimal precision, escaping and nested identically named field.'
        Assert-True ((Read-AudioToolConfig -ConfigPath $path).ffmpeg_directory -ceq $selected) 'Exact lexical preservation must still produce a readable validated saved directory.'
        $case['exact_unknown_characters_preserved'] = $true; $case['changed_top_level_field_only'] = $true
    }
    Invoke-Case 'saved app-local and PATH precedence is deterministic and incomplete local pairs fail' 'S04-A1' {
        param($case)
        New-PairCopy $appRoot
        $saved = Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -ConfigPath $config -ScriptDirectory $appRoot }
        $local = Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $appRoot }
        $pathChoice = Invoke-WithPath ($pathDirectory + ';' + $selected) { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $emptyApp }
        Assert-True ($saved.Origin -ceq 'Saved' -and $saved.Directory -ceq $selected -and $local.Origin -ceq 'AppLocal' -and $local.Directory -ceq $appRoot -and $pathChoice.Origin -ceq 'PATH' -and $pathChoice.Ffmpeg.Path -ceq $ffmpeg -and $pathChoice.Ffprobe.Path -ceq $ffprobe) 'Saved then root app-local then first PATH executable pair must be selected and disclosed.'
        $partial = New-Directory 'PartialApp'; Copy-Item -LiteralPath $ffmpeg -Destination (Join-Path $partial 'ffmpeg.exe'); Add-Fixture (Join-Path $partial 'ffmpeg.exe')
        $case['incomplete_local_failure'] = Assert-Throws { Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $partial } } 'local|pair|ffprobe|missing'
        $case['origins'] = @($saved.Origin,$local.Origin,$pathChoice.Origin); $case['duplicate_PATH_first_pair_wins'] = $true
    }
    Invoke-Case 'no tools one missing and invalid executable fail before conversion' 'S04-A1,S04-A3' {
        param($case)
        $case['missing'] = Assert-Throws { Invoke-WithPath '' { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $emptyApp } } 'find|missing|FFmpeg|ffmpeg|setup'
        $partial = Join-Path $testRoot 'PartialApp'
        $case['one_missing'] = Assert-Throws { Resolve-AudioToolSelection -FfmpegDirectory $partial -ConfigPath $absentConfig -ScriptDirectory $emptyApp } 'Invalid explicit FFmpeg selection'
        $bad = New-Directory 'BadExecutable'
        foreach ($name in @('ffmpeg.exe','ffprobe.exe')) { $path = Join-Path $bad $name; Write-NewText $path 'S04 independent non-executable fixture'; Add-Fixture $path }
        $case['startup_failure'] = Assert-Throws { Resolve-AudioToolSelection -FfmpegDirectory $bad -ConfigPath $absentConfig -ScriptDirectory $emptyApp } 'Invalid explicit FFmpeg selection|Explicit FFmpeg selection.*validation'
        $case['fixture_scope'] = 'Real Windows CreateProcess failure for synthetic invalid executable bytes; no actual missing-DLL or incompatible-machine hardware pass claimed.'
    }
    Invoke-Case 'current-directory input-directory aliases functions and wrappers are never executable discovery sources' 'S04-A1' {
        param($case)
        $decoy = New-Directory 'Decoy CWD'; $inputDecoy = New-Directory 'Decoy input'; $marker = Join-Path $testRoot 'DECOY-EXECUTED.txt'
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        $source = Join-Path $testRoot 'Decoy.cs'; $binary = Join-Path $testRoot 'Decoy.exe'
        $csPath = $marker.Replace('\','\\').Replace('"','\"')
        Write-NewText $source ('using System;using System.IO;using System.Diagnostics; class Decoy {static int Main(string[] args){string exe=Process.GetCurrentProcess().MainModule.FileName,name=Path.GetFileNameWithoutExtension(exe);if(Path.GetDirectoryName(exe).IndexOf("Mismatch",StringComparison.OrdinalIgnoreCase)>=0){if(Array.IndexOf(args,"-version")>=0)Console.WriteLine(name+" version "+(name=="ffmpeg"?"fixture-A":"fixture-B"));else Console.WriteLine(" A....D libmp3lame MP3");return 0;}File.WriteAllText("' + $csPath + '","unexpected execution");return 89;}}'); Add-Fixture $source
        $compile = Invoke-AudioNativeProcess -ExecutablePath $compiler -Arguments @('/nologo','/target:exe',('/out:'+$binary),$source) -TimeoutMilliseconds 20000 -Operation 'compile independent discovery sentinel'
        Assert-NativeSuccess $compile; Add-Fixture $binary
        foreach ($folder in @($decoy,$inputDecoy)) {
            foreach ($name in @('ffmpeg.exe','ffprobe.exe')) { $path = Join-Path $folder $name; Copy-Item -LiteralPath $binary -Destination $path; Add-Fixture $path }
        }
        $wrapperDir = New-Directory 'Wrappers'
        foreach ($name in @('ffmpeg.exe.cmd','ffprobe.exe.cmd','ffmpeg.cmd','ffprobe.cmd')) { $path = Join-Path $wrapperDir $name; Write-NewText $path '@exit /b 88'; Add-Fixture $path }
        $location = Get-Location
        try {
            Set-Location -LiteralPath $decoy
            function ffmpeg.exe { throw 'Unexpected function ffmpeg execution' }
            function ffprobe.exe { throw 'Unexpected function ffprobe execution' }
            Set-Alias -Name ffmpeg -Value ffmpeg.exe; Set-Alias -Name ffprobe -Value ffprobe.exe
            $case['decoy_failure'] = Assert-Throws { Invoke-WithPath $wrapperDir { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $emptyApp } } 'find|missing|FFmpeg|ffmpeg|setup'
            $choice = Invoke-WithPath $pathDirectory { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $emptyApp }
            Assert-True ($choice.Origin -ceq 'PATH' -and $choice.Ffmpeg.Path -ceq $ffmpeg -and -not (Test-Path -LiteralPath $marker)) 'Only real executable PATH candidates may be invoked; CWD/input decoys and shell commands must remain inert.'
        } finally { Set-Location -LiteralPath $location.ProviderPath; Remove-Item -LiteralPath Alias:ffmpeg,Alias:ffprobe -ErrorAction SilentlyContinue; Remove-Item -LiteralPath Function:ffmpeg.exe,Function:ffprobe.exe -ErrorAction SilentlyContinue }
        $case['decoy_execution_marker_absent'] = $true; $case['independent_compiled_sentinel'] = $true
    }
    Invoke-Case 'independent synthetic differing PATH build identities warn while preserving separate paths' 'S04-A1' {
        param($case)
        $mpegDirectory = New-Directory 'Mismatch ffmpeg'; $probeDirectory = New-Directory 'Mismatch ffprobe'
        foreach ($row in @(@{directory=$mpegDirectory;name='ffmpeg.exe'},@{directory=$probeDirectory;name='ffprobe.exe'})) {
            $destination = Join-Path $row.directory $row.name; Copy-Item -LiteralPath (Join-Path $testRoot 'Decoy.exe') -Destination $destination; Add-Fixture $destination
        }
        $script:mismatchWarnings = @()
        $choice = Invoke-WithPath ($mpegDirectory + ';' + $probeDirectory) { Resolve-AudioToolSelection -ConfigPath $absentConfig -ScriptDirectory $emptyApp -WarningVariable script:mismatchWarnings }
        Assert-True ($choice.Origin -ceq 'PATH' -and $choice.Ffmpeg.Path -ceq (Join-Path $mpegDirectory 'ffmpeg.exe') -and $choice.Ffprobe.Path -ceq (Join-Path $probeDirectory 'ffprobe.exe') -and $null -eq $choice.Directory -and @($script:mismatchWarnings).Count -gt 0) 'Legacy separate PATH directories with usable capabilities must remain selected with differing-build warning.'
        $case['coverage_kind'] = 'Independent compiled native fixtures, real resolver and Windows process transport; no genuine mixed FFmpeg release conversion claimed.'
        $case['warnings'] = @($script:mismatchWarnings | ForEach-Object {[string]$_}); $case['origin'] = $choice.Origin
    }
    Invoke-Case 'fresh processes convert with explicit and remembered external pair on empty PATH' 'S04-A1,S04-A2,S04-A3' {
        param($case)
        $inputDir = New-Directory 'Synthetic input [x]'; $audio = Join-Path $inputDir '2024-02-03 - Tiny.mp3'
        foreach ($name in @('ffmpeg.exe','ffprobe.exe')) {
            $destination = Join-Path $inputDir $name; Copy-Item -LiteralPath (Join-Path $testRoot 'Decoy.exe') -Destination $destination; Add-Fixture $destination
        }
        $generated = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-f','lavfi','-i','sine=frequency=440:duration=0.25','-c:a','libmp3lame','-metadata','artist=S04 synthetic artist',$audio) -TimeoutMilliseconds 15000 -Operation 'generate synthetic input'
        Assert-NativeSuccess $generated; Add-Fixture $audio
        $configBefore = (Get-FileHash -LiteralPath $config).Hash
        $runs = @()
        foreach ($mode in @('Explicit','Saved')) {
            $parent = New-Directory ($mode + ' output [x]')
            $entryConfig = if ($mode -ceq 'Explicit') { $absentConfig } else { $config }
            $code = '$ErrorActionPreference="Stop"' + "`n& " + (Get-Literal (Join-Path $appRoot 'AudioFileForPhone.ps1')) + ' -InputFolder ' + (Get-Literal $inputDir) + ' -OutputParent ' + (Get-Literal $parent) + ' -ConfigPath ' + (Get-Literal $entryConfig)
            if ($mode -ceq 'Explicit') { $code += ' -FfmpegDirectory ' + (Get-Literal $selected) }
            $code += "`nexit `$LASTEXITCODE"
            $native = Invoke-Child ('Convert' + $mode) $code
            $roots = @(Get-ChildItem -LiteralPath $parent -Directory)
            Assert-True ($roots.Count -eq 1) 'Conversion must create exactly one owned run.'
            $manifestPath = Join-Path $roots[0].FullName 'AudioFileForPhone_manifest.json'; $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
            Assert-True ($manifest.run.status -ceq 'Completed' -and $manifest.run.exit_code -eq 0 -and $manifest.totals.converted -eq 1 -and $manifest.totals.failed -eq 0 -and $manifest.policies.bitrate_kbps -eq 64 -and $manifest.tools.ffmpeg.path -ceq (Join-Path $selected 'ffmpeg.exe') -and $manifest.tools.ffprobe.path -ceq (Join-Path $selected 'ffprobe.exe') -and $manifest.tools.selection_origin -ceq $mode) 'Real conversion must retain default64 CBR, complete one file and identify exact selected binaries and origin.'
            $output = Join-Path $roots[0].FullName $manifest.records[0].output_relative_path
            $probed = Invoke-AudioNativeProcess -ExecutablePath $ffprobe -Arguments @('-v','error','-show_streams','-show_format','-of','json',$output) -TimeoutMilliseconds 15000 -Operation 'independent converted output probe'; Assert-NativeSuccess $probed
            $probe = $probed.Stdout | ConvertFrom-Json; $stream = @($probe.streams | Where-Object {$_.codec_type -ceq 'audio'})
            Assert-True ($stream.Count -eq 1 -and $stream[0].codec_name -ceq 'mp3' -and [int]$stream[0].bit_rate -eq 64000 -and $probe.format.tags.artist -ceq 'S04 synthetic artist') 'Independent output probe must verify default CBR MP3 and preserved metadata.'
            $decode = Invoke-AudioNativeProcess -ExecutablePath $ffmpeg -Arguments @('-nostdin','-v','error','-xerror','-i',$output,'-map','0:a:0','-f','null','NUL') -Operation 'independent complete converted output decode'; Assert-NativeSuccess $decode
            Assert-True ($decode.TimeoutMilliseconds -eq 0) 'Complete decoding must preserve the unlimited runtime default.'
            Assert-True ($native.Stdout -match $mode) 'Console must disclose the selection origin.'
            Assert-True (@(Get-ChildItem -LiteralPath $roots[0].FullName -Recurse -File | Where-Object {$_.Name.EndsWith('.partial',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0) 'Successful conversion must retain no partial files.'
            $runs += [pscustomobject]@{mode=$mode;exit_code=$native.ExitCode;converted=$manifest.totals.converted;bitrate_kbps=64;fully_decoded=$true;output_sha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()}
        }
        Assert-True (-not (Test-Path -LiteralPath $absentConfig) -and (Get-FileHash -LiteralPath $config).Hash -ceq $configBefore) 'Conversion must neither create nor rewrite selection state.'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testRoot 'DECOY-EXECUTED.txt'))) 'Actual entry input-folder executable sentinels must remain inert in both fresh conversions.'
        $case['runs'] = $runs; $case['PATH'] = 'empty'; $case['config_bytes_unchanged'] = $true; $case['actual_input_executable_sentinels_inert'] = $true
    }
    $report.status = 'pass'; $exitCode = 0
} catch { $report.error = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>'); $report['error_location'] = $_.ScriptStackTrace.Replace($testRoot,'<OWNED_TEMP>'); Write-Warning $report.error }
finally {
    $env:PATH = $originalPath
    $report.native_runs = $nativeRuns.ToArray(); $report.descendant_release_proved = $releaseProved
    try {
        $report.source_after = Get-Inventory $sourcePaths $projectRoot
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-True $report.source_unchanged 'Repository source bytes changed during focused tests.'
        $report.synthetic_after = Get-Inventory $fixtures.ToArray() $testRoot
        $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
        Assert-True $report.synthetic_unchanged 'Owned immutable source/runtime/fixture bytes changed.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['hash_verification_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    try {
        Assert-True $releaseProved 'Cleanup refused because exact native process release is unproved.'
        if ($created -and (Test-Path -LiteralPath $testRoot)) {
            $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\','/')
            Assert-True ($resolved -ceq $testRoot -and (Split-Path -Parent $resolved) -ieq $tempParent -and (Split-Path -Leaf $resolved) -ceq $testName) 'Cleanup must stay in exact directly owned TEMP tree.'
            Assert-True ([IO.File]::ReadAllText($ownerFile) -ceq $ownerToken) 'Cleanup requires unchanged create-new owner marker.'
            Assert-SafeTree $resolved
            Remove-Item -LiteralPath $resolved -Recurse -Force
            $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
        }
        Assert-True $report.cleanup_verified 'Exact owned cleanup must be verified.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message.Replace($testRoot,'<OWNED_TEMP>') }
    $report['completed_utc'] = [DateTime]::UtcNow.ToString('o'); Assert-NoReparse $evidenceParent
    Write-NewText $evidenceFullPath ($report | ConvertTo-Json -Depth 18)
}
Write-Host "$($report.task) tool selection: $($report.status); cases=$($report.cases.Count); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)/$($report.synthetic_unchanged)"
exit $exitCode
