<#
Isolated baseline runner for the retained real-FFmpeg integration suite.
Copies preserve application bytes and use the public OutputParent parameter.
Use -ValidateOnly to prove copy/parameter/cleanup guards without conversion.
Requires locally installed FFmpeg/ffprobe for execution; never downloads tools.
#>
[CmdletBinding()]
param(
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$testName = 'AudioFileForPhone-T03-' + [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $tempParent $testName
$ownerToken = [guid]::NewGuid().ToString('N')
$ownerFile = Join-Path $testRoot '.t03-owner'
$ownedRootCreated = $false
$originalPath = $env:PATH
# New task reports preserve historical evidence and never replace source or control documents.
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
$evidenceParent = [IO.Path]::GetFullPath((Join-Path $projectRoot 'docs/codex-v1/evidence')).TrimEnd('\', '/')
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^(T03|T04|T05)-[A-Za-z0-9_-]+\.json$') {
    throw 'EvidencePath must name T03/T04/T05-<label>.json directly in docs/codex-v1/evidence; T02 evidence is historical.'
}
$evidenceTask = (Split-Path -Leaf $evidenceFullPath).Substring(0, 3)
$report = [ordered]@{
    schema_version = 1
    task = $evidenceTask
    mode = $(if ($ValidateOnly) { 'isolation_validation' } else { 'real_ffmpeg_baseline' })
    started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString()
    os = [Environment]::OSVersion.Version.ToString()
    windows_build = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber + '.' + (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    harness_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    isolation = [ordered]@{ replacements_per_copy = 0; copied_bytes_unchanged = $false; output_parameter = 'OutputParent'; verified = $false }
    source_before = @()
    source_after = @()
    source_unchanged = $false
    legacy = [ordered]@{ status = 'not_run'; exit_code = $null }
    characterization = $null
    cleanup_verified = $false
    status = $(if ($ValidateOnly) { 'fail' } else { 'blocked' })
    error = $null
}
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.bat', 'tests/Test-AudioFileForPhone.ps1',
    'tests/Invoke-IsolatedBaseline.ps1', 'tests/Test-BaselineCharacterization.ps1')

function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object {
        $path = Join-Path $projectRoot $_
        [pscustomobject]@{ relative_path = $_; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
    })
}

function Assert-NoReparse {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing a reparse point in the owned test path: $($item.FullName)"
        }
        $item = $item.Parent
    }
}

function Copy-UnchangedScript {
    param([string]$SourcePath, [string]$Destination)
    Copy-Item -LiteralPath $SourcePath -Destination $Destination
    if ((Get-FileHash -LiteralPath $SourcePath).Hash -cne (Get-FileHash -LiteralPath $Destination).Hash) {
        throw 'Disposable script copy must preserve all source bytes.'
    }
    $tokens = $null; $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($Destination, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -ne 0) { throw "Isolated copy has parser errors: $parseErrors" }
}

function Assert-NoReparseTree {
    param([string]$Path)
    Assert-NoReparse $Path
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        foreach ($child in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Refusing a reparse point in the owned test tree: $($child.FullName)"
            }
            if ($child.PSIsContainer) { $pending.Push($child.FullName) }
        }
    }
}

function Find-LocalTool {
    param([string]$ExplicitPath, [string]$Name)
    if ($ExplicitPath) {
        $path = (Resolve-Path -LiteralPath $ExplicitPath).ProviderPath
    }
    elseif (Test-Path -LiteralPath (Join-Path $projectRoot $Name) -PathType Leaf) {
        $path = Join-Path $projectRoot $Name
    }
    else {
        $path = (Get-Command $Name -CommandType Application -ErrorAction Stop).Source
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.Path]::GetFileName($path) -ine $Name) {
        throw "Expected a local executable named $Name."
    }
    return [IO.Path]::GetFullPath($path)
}

function Invoke-TestChild {
    param([string]$ScriptPath, [string[]]$Options)
    $shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
    $shell = Join-Path $PSHOME $shellName
    $ErrorActionPreference = 'Continue'
    $output = @(& $shell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File $ScriptPath @Options 2>&1)
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    # Raw diagnostics stay only in the disposable directory. Committed evidence
    # uses generated relative names and structured outcomes instead of private logs.
    $output | ForEach-Object { "$_" } | Set-Content -LiteralPath (Join-Path $testRoot ((Split-Path -Leaf $ScriptPath) + '.log')) -Encoding UTF8
    return [pscustomobject]@{ ExitCode = $code; Output = $output }
}

$exitCode = 1
try {
    $report.source_before = Get-SourceInventory
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    Assert-NoReparse $tempParent
    if (Test-Path -LiteralPath $testRoot) { throw 'Unique test root already exists; refusing reuse.' }
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $ownedRootCreated = $true
    $marker = [IO.File]::Open($ownerFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = [Text.Encoding]::ASCII.GetBytes($ownerToken)
        $marker.Write($bytes, 0, $bytes.Length)
    }
    finally { $marker.Dispose() }
    $legacyRoot = Join-Path $testRoot 'Legacy app'
    $legacyTests = Join-Path $legacyRoot 'tests'
    $characterRoot = Join-Path $testRoot 'Characterization app'
    $characterOutput = Join-Path $testRoot 'Characterization outputs'
    foreach ($path in @($legacyRoot, $legacyTests, $characterRoot, $characterOutput)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
    $application = Join-Path $projectRoot 'AudioFileForPhone.ps1'
    $helpers = Join-Path $projectRoot 'AudioFileForPhone.Helpers.ps1'
    $legacyScript = Join-Path $legacyRoot 'AudioFileForPhone.ps1'
    $legacySuite = Join-Path $legacyTests 'Test-AudioFileForPhone.ps1'
    $characterScript = Join-Path $characterRoot 'AudioFileForPhone.ps1'
    Copy-UnchangedScript $application $legacyScript
    Copy-UnchangedScript $helpers (Join-Path $legacyRoot 'AudioFileForPhone.Helpers.ps1')
    Copy-UnchangedScript (Join-Path $PSScriptRoot 'Test-AudioFileForPhone.ps1') $legacySuite
    Copy-UnchangedScript $application $characterScript
    Copy-UnchangedScript $helpers (Join-Path $characterRoot 'AudioFileForPhone.Helpers.ps1')
    $appTokens = $null; $appErrors = $null
    $appAst = [Management.Automation.Language.Parser]::ParseFile($characterScript, [ref]$appTokens, [ref]$appErrors)
    if (@($appAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'OutputParent' }).Count -ne 1) {
        throw 'Application must expose the OutputParent parameter before any conversion is launched.'
    }
    $report.isolation.copied_bytes_unchanged = $true
    $companion = Join-Path $PSScriptRoot 'Test-BaselineCharacterization.ps1'
    $companionTokens = $null; $companionErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($companion, [ref]$companionTokens, [ref]$companionErrors) | Out-Null
    if ($companionErrors.Count -ne 0) { throw "Companion has parser errors: $companionErrors" }
    $report['companion_sha256'] = (Get-FileHash -LiteralPath $companion -Algorithm SHA256).Hash.ToLowerInvariant()
    $report.isolation['companion_syntax_valid'] = $true
    Assert-NoReparse $testRoot
    $report.isolation.verified = $true
    if ($ValidateOnly) {
        $report.status = 'pass'
        $exitCode = 0
    }
    else {
        $ffmpeg = Find-LocalTool $FfmpegPath 'ffmpeg.exe'
        $ffprobe = Find-LocalTool $FfprobePath 'ffprobe.exe'
        $env:PATH = (Split-Path -Parent $ffmpeg) + ';' + (Split-Path -Parent $ffprobe) + ';' + $originalPath
        foreach ($selection in @(@{ Name = 'ffmpeg.exe'; Path = $ffmpeg }, @{ Name = 'ffprobe.exe'; Path = $ffprobe })) {
            $firstCandidate = $null
            foreach ($directory in ($env:PATH -split ';' | Where-Object { $_ })) {
                $candidate = Join-Path $directory $selection.Name
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $firstCandidate = [IO.Path]::GetFullPath($candidate)
                    break
                }
            }
            if ($firstCandidate -ine $selection.Path) { throw 'Legacy PATH discovery would select a different dependency from the reported executable.' }
        }
        $report['ffmpeg'] = @(& $ffmpeg -version)[0]
        if ($LASTEXITCODE -ne 0) { throw 'FFmpeg version check failed.' }
        $report['ffprobe'] = @(& $ffprobe -version)[0]
        if ($LASTEXITCODE -ne 0) { throw 'ffprobe version check failed.' }
        $legacy = Invoke-TestChild $legacySuite @()
        $report.legacy.exit_code = $legacy.ExitCode
        $report.legacy.status = $(if ($legacy.ExitCode -eq 0) { 'pass' } else { 'fail' })
        $characterResult = Join-Path $testRoot 'characterization-results.json'
        $characterization = Invoke-TestChild (Join-Path $PSScriptRoot 'Test-BaselineCharacterization.ps1') @(
            '-ApplicationScript', $characterScript, '-WorkRoot', (Join-Path $testRoot 'Fixtures'),
            '-OutputParent', $characterOutput, '-FfmpegPath', $ffmpeg, '-FfprobePath', $ffprobe,
            '-ResultPath', $characterResult)
        if (Test-Path -LiteralPath $characterResult -PathType Leaf) {
            $report.characterization = Get-Content -LiteralPath $characterResult -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        if ($legacy.ExitCode -ne 0 -or $characterization.ExitCode -ne 0 -or $null -eq $report.characterization) {
            $report.status = 'fail'
            throw "Baseline checks failed (legacy=$($legacy.ExitCode), characterization=$($characterization.ExitCode))."
        }
        $report.status = 'pass'
        $exitCode = 0
    }
}
catch {
    $report.error = $_.Exception.Message
    Write-Warning $report.error
}
finally {
    $env:PATH = $originalPath
    $report.source_after = Get-SourceInventory
    $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
    if (-not $report.source_unchanged) { $report.status = 'fail'; $exitCode = 1 }
    if ($ownedRootCreated -and (Test-Path -LiteralPath $testRoot)) {
        # Verify the absolute target, its exclusive marker and the whole tree
        # immediately before deletion. Never clean by wildcard or output name.
        $resolved = (Resolve-Path -LiteralPath $testRoot).ProviderPath.TrimEnd('\', '/')
        if ($resolved -cne $testRoot -or (Split-Path -Parent $resolved) -ine $tempParent -or
            (Split-Path -Leaf $resolved) -cne $testName -or
            [IO.File]::ReadAllText($ownerFile) -cne $ownerToken) {
            throw "Refusing cleanup without exact owned TEMP boundary: $resolved"
        }
        Assert-NoReparseTree $resolved
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $report.cleanup_verified = -not (Test-Path -LiteralPath $resolved)
    }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $evidenceFullPath) -PathType Container)) {
        throw 'Evidence parent must already exist.'
    }
    Assert-NoReparse $evidenceParent
    if (Test-Path -LiteralPath $evidenceFullPath) { Assert-NoReparse $evidenceFullPath }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidenceFullPath -Encoding UTF8
}
Write-Host "$evidenceTask $($report.mode): $($report.status); owned cleanup=$($report.cleanup_verified); sources unchanged=$($report.source_unchanged)"
exit $exitCode
