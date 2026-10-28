<# Read-only local evidence gates. Exit0=accepted evidence, exit1=refused. No upload, tag or release. #>
[CmdletBinding()]
param(
    [string]$PlanRoot,
    [string]$CandidateRecordPath,
    [ValidateSet('Acceptance','Publication')][string]$Phase = 'Acceptance'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ReleaseGates.ps1')
try {
    if ([string]::IsNullOrWhiteSpace($PlanRoot)) { $PlanRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/codex-v1.0.1' }
    $state = Read-ReleaseJson (Join-Path $PlanRoot 'STATE.json')
    $target = Read-ReleaseJson (Join-Path $PlanRoot 'RELEASE_TARGET.json')
    $candidate = $null; $reports = @(); $actualAssets = @(); $runtime = @()
    $root = Split-Path -Parent $PSScriptRoot
    $tokens = $null; $errors = $null
    $helperAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'AudioFileForPhone.Helpers.ps1'), [ref]$tokens, [ref]$errors)
    $definitions = @($helperAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-AudioAppVersion' }, $false))
    if ($errors.Count -ne 0 -or $definitions.Count -ne 1) { throw 'Exact source version function must parse unambiguously.' }
    . ([scriptblock]::Create($definitions[0].Extent.Text))
    $version = Get-AudioAppVersion
    if ($version -isnot [string] -or $version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Exact source version is invalid.' }
    if (-not [string]::IsNullOrWhiteSpace($CandidateRecordPath)) {
        $candidatePath = [IO.Path]::GetFullPath($CandidateRecordPath)
        $candidate = Read-ReleaseJson $candidatePath
        $recordRoot = Split-Path -Parent $candidatePath
        foreach ($reference in @(Get-ReleaseField $candidate 'reports')) {
            $relative = [string](Get-ReleaseField $reference 'path')
            if ($relative -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*\.json$' -or $relative -match '(^|/)\.\.?(/|$)') { throw 'Report references must be safe relative JSON paths.' }
            $path = Join-Path $recordRoot $relative
            $reports += Read-ReleaseBoundReport -Path $path -Sha256 ([string](Get-ReleaseField $reference 'sha256')) -GateId ([string](Get-ReleaseField $reference 'gate_id'))
        }
        foreach ($asset in @(Get-ReleaseField $candidate 'assets')) {
            $name = [string](Get-ReleaseField $asset 'name')
            if ($name -cnotin @('AudioFileForPhone-v1.0.1.zip','release-manifest.json','SHA256SUMS.txt','Acceptance-Kit.zip')) { throw 'Unexpected candidate asset name.' }
            $path = Join-Path $recordRoot $name
            Assert-ReleaseLocalFile $path
            $actualAssets += [pscustomobject]@{ name = $name; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
        }
        $allowlist = Read-ReleaseJson (Join-Path $PSScriptRoot 'package-files.json')
        Assert-ReleaseFrozenSource -RepositoryRoot $root -SourceCommit ([string](Get-ReleaseField $candidate 'source_commit')) -Paths (@('tools/package-files.json') + @($allowlist.files)) -RequireMain:($Phase -ceq 'Publication')
        foreach ($relative in @($allowlist.files)) {
            $path = Join-Path $root $relative
            Assert-ReleaseLocalFile $path
            $runtime += [pscustomobject]@{ path = $relative; sha256 = Get-ReleaseGitBlobHash -RepositoryRoot $root -SourceCommit ([string](Get-ReleaseField $candidate 'source_commit')) -RelativePath $relative }
        }
        $zipAsset = @($actualAssets | Where-Object { $_.name -ceq 'AudioFileForPhone-v1.0.1.zip' })
        $manifestAsset = @($actualAssets | Where-Object { $_.name -ceq 'release-manifest.json' })
        if ($zipAsset.Count -ne 1 -or $manifestAsset.Count -ne 1) { throw 'Actual runtime ZIP and external manifest must be unique.' }
        $manifest = Read-ReleaseJson (Join-Path $recordRoot 'release-manifest.json')
        Assert-ReleaseManifest -Manifest $manifest -SourceCommit ([string](Get-ReleaseField $candidate 'source_commit')) -ZipHash $zipAsset[0].sha256 -ZipBytes (Get-Item -LiteralPath (Join-Path $recordRoot 'AudioFileForPhone-v1.0.1.zip')).Length -Runtime $runtime
        $checksumsPath = Join-Path $recordRoot 'SHA256SUMS.txt'
        Assert-ReleaseLocalFile $checksumsPath
        if ((Get-Item -LiteralPath $checksumsPath).Length -gt 4096) { throw 'External checksum file is unexpectedly large.' }
        $checksumRows = @(Get-Content -LiteralPath $checksumsPath -Encoding UTF8)
        if ($checksumRows.Count -ne 2 -or $checksumRows[0] -cne ($zipAsset[0].sha256 + '  AudioFileForPhone-v1.0.1.zip') -or
            $checksumRows[1] -cne ($manifestAsset[0].sha256 + '  release-manifest.json')) { throw 'External checksum file does not bind the actual ZIP and manifest.' }
    }
    $result = Test-ReleaseGateRecords -State $state -Target $target -Candidate $candidate -Reports $reports -ActualRuntime $runtime -ActualAssets $actualAssets -ActualVersion $version -Phase $Phase
    $result | ConvertTo-Json -Depth 12
    if ($result.status -ceq 'PASSED') { exit 0 }
    exit 1
} catch {
    [pscustomobject]@{ schema_version = 1; kind = 'release_gate_result'; phase = $Phase; status = 'REFUSED'; publication_performed = $false; publication_authority_granted = $false; failures = @([pscustomobject]@{ code = 'EVIDENCE_READ_REFUSED'; detail = $_.Exception.Message }) } | ConvertTo-Json -Depth 8
    exit 1
}
