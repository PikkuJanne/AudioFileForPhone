<#
Focused offline kit-builder contract tests. Synthetic package manifests and runner
stubs never constitute package, conversion, client, physical or phone acceptance.
Fixtures and reports are retained under one exclusively reserved temporary tree.
#>
[CmdletBinding()]
param([string]$EvidencePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $project 'tools/Build-AcceptanceKit.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('AFP-KitBuild-' + [guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $root) { throw 'Unexpected fixture collision.' }
$null = [IO.Directory]::CreateDirectory($root)
[IO.File]::WriteAllText((Join-Path $root '.owner'), [guid]::NewGuid().ToString('N'))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$hostProcess = [Diagnostics.Process]::GetCurrentProcess()
try { $shell = $hostProcess.MainModule.FileName } finally { $hostProcess.Dispose() }
$runner = Join-Path $root 'runner'; $null = [IO.Directory]::CreateDirectory($runner)
$runnerNames = @('Run-Windows-Acceptance.bat','Run-Windows-Acceptance.ps1','Acceptance.Common.ps1','Acceptance.Physical.ps1','Export-AcceptanceReport.ps1','INSTRUCTIONS.txt')
foreach ($name in $runnerNames) { [IO.File]::WriteAllText((Join-Path $runner $name), ('Synthetic builder contract stub: ' + $name), (New-Object Text.UTF8Encoding($false))) }
$allowlist = (Get-Content -LiteralPath (Join-Path $project 'tools/package-files.json') -Raw | ConvertFrom-Json).files
$report = [ordered]@{ schema_version=1; task='S13'; scope='Offline synthetic kit-builder contracts only'; shell_version=$PSVersionTable.PSVersion.ToString(); started_utc=[datetime]::UtcNow.ToString('o'); builder_sha256=(Get-FileHash -LiteralPath $builder).Hash.ToLowerInvariant(); cases=@(); status='FAILED'; fixture_root=$root }

function Assert-KitTest { param([bool]$Condition,[string]$Message) if (-not $Condition) { throw $Message } }
function Get-KitTestHash { param([string]$Path) return (Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-KitTestJson { param([string]$Path,[object]$Object) [IO.File]::WriteAllText($Path,(($Object|ConvertTo-Json -Depth 12)+"`n"),(New-Object Text.UTF8Encoding($false))) }
function Write-KitTestChecksums {
    param([string]$Assets,[string]$ZipName)
    [IO.File]::WriteAllText((Join-Path $Assets 'SHA256SUMS.txt'),((Get-KitTestHash (Join-Path $Assets $ZipName))+'  '+$ZipName+"`n"+(Get-KitTestHash (Join-Path $Assets 'release-manifest.json'))+"  release-manifest.json`n"),(New-Object Text.UTF8Encoding($false)))
}
function New-KitTestFixture {
    param([string]$Name,[string]$Version='1.0.0',[string]$HelperVersion='1.0.0',[string]$ExtraEntry='', [switch]$Duplicate,[switch]$Omit)
    $assets=Join-Path $root $Name; $null=[IO.Directory]::CreateDirectory($assets)
    $zipName='AudioFileForPhone-v'+$Version+'.zip'; $zipPath=Join-Path $assets $zipName
    $files=[ordered]@{}; $sizes=[ordered]@{}
    $archive=[IO.Compression.ZipFile]::Open($zipPath,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $allowlist) {
            $bytes=[IO.File]::ReadAllBytes((Join-Path $project $name))
            if ($name -ceq 'AudioFileForPhone.Helpers.ps1') {
                $text=[Text.Encoding]::UTF8.GetString($bytes)
                $tokens=$null; $parseErrors=$null
                $helperAst=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$parseErrors)
                $versionFunctions=@($helperAst.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Get-AudioAppVersion'},$true))
                Assert-KitTest (@($parseErrors).Count -eq 0 -and $versionFunctions.Count -eq 1) 'Fixture helper must parse and define exactly one version function.'
                $statements=@($versionFunctions[0].Body.EndBlock.Statements)
                Assert-KitTest ($statements.Count -eq 1 -and $statements[0] -is [Management.Automation.Language.ReturnStatementAst]) 'Fixture version function must contain one literal return.'
                $pipeline=$statements[0].Pipeline
                Assert-KitTest ($pipeline -is [Management.Automation.Language.PipelineAst] -and $pipeline.PipelineElements.Count -eq 1 -and $pipeline.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) 'Fixture version return must contain one expression.'
                $literal=$pipeline.PipelineElements[0].Expression
                Assert-KitTest ($literal -is [Management.Automation.Language.StringConstantExpressionAst] -and $literal.Value -cmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -and $HelperVersion -cmatch '^[0-9]+\.[0-9]+\.[0-9]+$') 'Fixture version replacement requires literal semantic versions.'
                $text=$text.Substring(0,$literal.Extent.StartOffset)+("'"+$HelperVersion+"'")+$text.Substring($literal.Extent.EndOffset)
                $bytes=[Text.Encoding]::UTF8.GetBytes($text)
            }
            $sha=[Security.Cryptography.SHA256]::Create()
            try { $files[$name]=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
            $sizes[$name]=[long]$bytes.Length
            if ($Omit -and $name -ceq 'LICENSE') { continue }
            $entry=$archive.CreateEntry($name); $entry.ExternalAttributes=0
            $stream=$entry.Open(); try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
        }
        foreach ($name in @($ExtraEntry, $(if($Duplicate){'LICENSE'}else{''}))) {
            if (-not $name) { continue }
            $entry=$archive.CreateEntry($name);$entry.ExternalAttributes=0
            $stream=$entry.Open();try{$stream.WriteByte(42)}finally{$stream.Dispose()}
        }
    } finally { $archive.Dispose() }
    $manifest=[ordered]@{ schema_version=1;repository='PikkuJanne/AudioFileForPhone';app_version=$Version;tag='v'+$Version;release_commit='1'*40;zip=[ordered]@{name=$zipName;bytes=(Get-Item -LiteralPath $zipPath).Length;sha256=Get-KitTestHash $zipPath};files=$files;file_bytes=$sizes }
    Write-KitTestJson (Join-Path $assets 'release-manifest.json') $manifest
    Write-KitTestChecksums $assets $zipName
    return [pscustomobject]@{assets=$assets;zip_name=$zipName;manifest=$manifest}
}
function ConvertTo-KitTestArgument {
    param([string]$Value)
    return '"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
}
function Invoke-KitTestBuilder {
    param([string]$Name,[object]$Fixture,[bool]$ExpectedSuccess,[switch]$Final,[string]$RunnerPath=$runner,[string]$OutputPath='')
    if (-not $OutputPath) { $OutputPath=Join-Path $root ('output-'+$Name) }
    $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','RemoteSigned','-File',$builder,'-RuntimeAssetsDirectory',$Fixture.assets,'-OutputDirectory',$OutputPath,'-RunnerSourceDirectory',$RunnerPath)
    if (-not $Final) { $arguments+='-Rehearsal' }
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$shell;$info.Arguments=($arguments|ForEach-Object{ConvertTo-KitTestArgument $_})-join ' '
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WorkingDirectory=$root
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.EnvironmentVariables['PATH']=''
    $process=New-Object Diagnostics.Process;$process.StartInfo=$info
    $case=[ordered]@{id=$Name;expected=$(if($ExpectedSuccess){'exit0 and verified kit'}else{'nonzero refusal'});observed='';status='FAILED';exit_code=$null;child_path_empty=$true}
    try {
        Assert-KitTest $process.Start() 'Builder child did not start.'
        $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) { $process.Kill();$null=$process.WaitForExit(5000);throw 'Owned builder child exceeded deadline.' }
        Assert-KitTest ([Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),5000)) 'Builder pipes were not drained.'
        $case.exit_code=$process.ExitCode
        Assert-KitTest (($process.ExitCode -eq 0) -eq $ExpectedSuccess) ('Unexpected builder result for '+$Name+': '+$stdout.Result+$stderr.Result)
        if ($ExpectedSuccess) {
            $result=$stdout.Result|ConvertFrom-Json
            Assert-KitTest ($result.status -ceq 'PASSED' -and $result.acceptance_kit_sha256 -ceq (Get-KitTestHash (Join-Path $OutputPath 'Acceptance-Kit.zip'))) 'Kit digest/result mismatch.'
            $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $OutputPath 'Acceptance-Kit.zip'))
            try {
                Assert-KitTest ($archive.Entries.Count -eq ($runnerNames.Count+4)) 'Kit archive inventory count mismatch.'
                $entry=@($archive.Entries|Where-Object FullName -CEQ 'kit-manifest.json')[0]
                $stream=$entry.Open();$reader=New-Object IO.StreamReader($stream)
                try{$kit=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose();$stream.Dispose()}
                Assert-KitTest ($kit.kind -ceq $(if($Final){'acceptance_kit'}else{'rehearsal_acceptance_kit'})) 'Kit must preserve explicit final/rehearsal scope.'
                Assert-KitTest ($kit.runtime_hashes.Count -eq $allowlist.Count -and $kit.kit_files.Count -eq ($runnerNames.Count+3)) 'Kit manifest inventory differs.'
                Assert-KitTest ($null -eq $kit.PSObject.Properties['acceptance_kit_sha256']) 'Kit manifest must not contain a circular archive digest.'
                $case.kit_sha256=$result.acceptance_kit_sha256
            } finally { $archive.Dispose() }
            $case.observed='exit0; exact output archive digest, inventory and explicit scope verified'
        } else {
            if ($Name -cne 'occupied-output-refused') { Assert-KitTest (-not (Test-Path -LiteralPath $OutputPath)) 'Refusal published an output directory.' }
            $case.observed='nonzero refusal captured; no output published'
        }
        Assert-KitTest (@(Get-ChildItem -LiteralPath $root -Directory -Force|Where-Object Name -Match '^\.afp-kit-').Count -eq 0) 'Builder retained an unexpected stage.'
        $case.status='PASSED'
    } finally {$process.Dispose();$report.cases += [pscustomobject]$case}
}

try {
    $fixture=New-KitTestFixture 'base'
    Invoke-KitTestBuilder 'rehearsal-no-developer-path' $fixture $true
    Invoke-KitTestBuilder 'runtime100-refuses-final-mode' $fixture $false -Final
    $final=New-KitTestFixture 'synthetic-final' '1.0.1' '1.0.1'
    Invoke-KitTestBuilder 'synthetic-final-contract' $final $true -Final
    $mismatch=New-KitTestFixture 'mismatch' '1.0.1' '1.0.0'
    Invoke-KitTestBuilder 'packaged-version-mismatch' $mismatch $false -Final
    $duplicate=New-KitTestFixture 'duplicate' -Duplicate
    Invoke-KitTestBuilder 'duplicate-runtime-member' $duplicate $false
    $traversal=New-KitTestFixture 'traversal' -ExtraEntry '../escape.ps1'
    Invoke-KitTestBuilder 'traversal-runtime-member' $traversal $false
    $binary=New-KitTestFixture 'binary' -ExtraEntry 'ffmpeg.exe'
    Invoke-KitTestBuilder 'unexpected-binary' $binary $false
    $omitted=New-KitTestFixture 'omitted' -Omit
    Invoke-KitTestBuilder 'omitted-runtime-member' $omitted $false
    $badHash=New-KitTestFixture 'bad-hash'
    $badHash.manifest.files['LICENSE']='0'*64
    Write-KitTestJson (Join-Path $badHash.assets 'release-manifest.json') $badHash.manifest
    Write-KitTestChecksums $badHash.assets $badHash.zip_name
    Invoke-KitTestBuilder 'runtime-member-hash-mismatch' $badHash $false
    $duplicateJson=New-KitTestFixture 'duplicate-json'
    $manifestPath=Join-Path $duplicateJson.assets 'release-manifest.json'
    $text=[IO.File]::ReadAllText($manifestPath)
    $text=[regex]::Replace($text,'("files"\s*:\s*\{)',('$1"LICE\u004eSE":"'+$duplicateJson.manifest.files['LICENSE']+'",'))
    [IO.File]::WriteAllText($manifestPath,$text,(New-Object Text.UTF8Encoding($false)))
    Write-KitTestChecksums $duplicateJson.assets $duplicateJson.zip_name
    Invoke-KitTestBuilder 'escaped-duplicate-json-member' $duplicateJson $false
    $badChecksums=New-KitTestFixture 'bad-checksums'
    [IO.File]::AppendAllText((Join-Path $badChecksums.assets 'SHA256SUMS.txt'),"unexpected`n")
    Invoke-KitTestBuilder 'extra-checksum-row' $badChecksums $false
    $occupied=Join-Path $root 'occupied';$null=[IO.Directory]::CreateDirectory($occupied)
    $sentinel=Join-Path $occupied 'preserve.txt';[IO.File]::WriteAllText($sentinel,'preserve')
    Invoke-KitTestBuilder 'occupied-output-refused' $fixture $false -OutputPath $occupied
    Assert-KitTest ([IO.File]::ReadAllText($sentinel) -ceq 'preserve') 'Occupied output sentinel changed.'
    $missingRunner=Join-Path $root 'missing-runner';$null=[IO.Directory]::CreateDirectory($missingRunner)
    Invoke-KitTestBuilder 'missing-runner-refused' $fixture $false -RunnerPath $missingRunner
    $report.status='PASSED'
    Assert-KitTest ((Get-KitTestHash $builder) -ceq $report.builder_sha256) 'Builder changed during the contract run.'
} finally {
    $report.ended_utc=[datetime]::UtcNow.ToString('o')
    $report.fixture_retained=$true
    if ($EvidencePath) {
        $evidence=[IO.Path]::GetFullPath($EvidencePath)
        if (Test-Path -LiteralPath $evidence) { throw 'EvidencePath must be new.' }
        Write-KitTestJson $evidence $report
    }
    $report|ConvertTo-Json -Depth 8
}
