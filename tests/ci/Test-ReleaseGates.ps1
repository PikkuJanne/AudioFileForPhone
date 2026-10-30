<# Pure release-gate contract fixtures and actual-record refusals. No client/phone acceptance is simulated. #>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$EvidencePath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$edition = if ($PSVersionTable.PSEdition -ceq 'Desktop') { 'ps51' } else { 'ps7' }
$full = [IO.Path]::GetFullPath($EvidencePath)
$parent = Join-Path $projectRoot 'docs/codex-v1.0.1/evidence'
if ((Split-Path -Parent $full) -ine $parent -or (Split-Path -Leaf $full) -cnotmatch ('^S12-releasegates-' + $edition + '-(?:(?:attempt|final)[1-9][0-9]*|run[1-9][0-9]*_[1-9][0-9]*)\.json$')) { throw 'Use a fresh active S12-releasegates edition/label report.' }
if (Test-Path -LiteralPath $full) { throw 'Report exists; select a fresh label.' }
. (Join-Path $projectRoot 'tools/ReleaseGates.ps1')
$sourceFiles = @('tools/ReleaseGates.ps1','tools/Test-ReleaseGates.ps1','tests/ci/Test-ReleaseGates.ps1','AudioFileForPhone.ico')
function Get-GateTestInventory { return @($sourceFiles | ForEach-Object { [pscustomobject]@{ path=$_; sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() } }) }
function Assert-GateTest { param([bool]$Condition,[string]$Message); if (-not $Condition) { throw $Message } }
function Copy-GateFixture { param([object]$Value); return $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json }
function Invoke-GateTestCase { param([string]$Name,[scriptblock]$Action); $row=[ordered]@{name=$Name;status='fail'}; try { & $Action $row; $row.status='pass' } finally { $script:gateReport.cases += [pscustomobject]$row } }
function New-GateFixture {
    $source='a'*40; $zip='b'*64; $kit='c'*64
    $runtime=@([pscustomobject]@{path='AudioFileForPhone.ps1';sha256='d'*64})
    $target=[pscustomobject]@{target_version='1.0.1';target_tag='v1.0.1';release_title='AudioFileForPhone v1.0.1';runtime_zip='AudioFileForPhone-v1.0.1.zip'}
    $steps=[ordered]@{}; foreach($n in 1..16){$steps['S'+$n.ToString('00')]=[pscustomobject]@{status='COMPLETED'}}
    $state=[pscustomobject]@{steps=$steps;frozen_release_commit=$source;runtime_zip_sha256=$zip;acceptance_kit_sha256=$kit;publication_authorization=$null}
    $assets=@([pscustomobject]@{name='AudioFileForPhone-v1.0.1.zip';sha256=$zip},[pscustomobject]@{name='release-manifest.json';sha256='e'*64},[pscustomobject]@{name='SHA256SUMS.txt';sha256='f'*64},[pscustomobject]@{name='Acceptance-Kit.zip';sha256=$kit})
    $candidate=[pscustomobject]@{schema_version=1;kind='release_candidate';source_commit=$source;target_version='1.0.1';target_tag='v1.0.1';release_title='AudioFileForPhone v1.0.1';runtime_zip='AudioFileForPhone-v1.0.1.zip';runtime_zip_sha256=$zip;acceptance_kit_sha256=$kit;runtime_hashes=$runtime;assets=$assets}
    $reports=@()
    foreach($id in @('core_windows10_ps51','core_windows10_ps7','core_windows11_ps51','core_windows11_ps7','clean_first_run','online_setup','offline_setup_failure','exact_package','one_file','full_collection','physical_shortcut','phone_play_seek')){
        $win10=$id -match 'windows10'; $ps51=$id -match 'ps51'
        $environment=[pscustomobject]@{os_family=$(if($win10){'Windows10'}else{'Windows11'});os_type='Client';architecture='x64';process_64bit=$true;display_version=$(if($win10){'22H2'}else{'26H2'});build=$(if($win10){'19045.1'}else{'26300.9711'});shell_version=$(if($ps51){'5.1.26100.9711'}else{'7.6.5'})}
        $checkNames = switch -Regex ($id) {
            '^core_' { @('parser','focused','integration'); break }
            '^clean_first_run$' { @('missing_tools','external_selection','saved_fresh_process'); break }
            '^online_setup$' { @('consent','download_pin','installed_conversion'); break }
            '^offline_setup_failure$' { @('no_publication','owned_cleanup'); break }
            '^exact_package$' { @('member_hashes','extracted_conversion','full_decode'); break }
            '^(one_file|full_collection)$' { @('counts','media','source_hashes'); break }
            '^physical_shortcut$' { @('observed_shortcut','matched_run'); break }
            '^phone_play_seek$' { @('play','seek'); break }
        }
        $checks = @($checkNames | ForEach-Object { [pscustomobject]@{ id=$_; status='PASSED'; expected='Synthetic contract input'; observed='Synthetic contract result, never execution evidence' } })
        $record=[pscustomobject]@{schema_version=1;kind='candidate_acceptance';gate_id=$id;status='PASSED';exit_code=0;source_commit=$source;runtime_zip_sha256=$zip;acceptance_kit_sha256=$kit;runtime_hashes=$runtime;started_utc='2026-10-28T12:00:00Z';ended_utc='2026-10-28T12:01:00Z';command='SYNTHETIC GATE FIXTURE ONLY';environment=$environment;coverage='core_application';checks=$checks;source_unchanged=$true;media_validated=$true;input_count=1;converted_count=1;failed_count=0;unprocessed_count=0;evidence_type='human_observation';observer='CONTRACT FIXTURE, NOT A PERSON';observed='PASSED'}
        $reports += [pscustomobject]@{gate_id=$id;digest_verified=$true;record=$record}
    }
    return [pscustomobject]@{State=$state;Target=$target;Candidate=$candidate;Reports=$reports;ActualRuntime=$runtime;ActualAssets=$assets;ActualVersion='1.0.1'}
}
function Invoke-GateFixture { param([object]$Fixture,[string]$Phase='Acceptance'); return Test-ReleaseGateRecords -State $Fixture.State -Target $Fixture.Target -Candidate $Fixture.Candidate -Reports $Fixture.Reports -ActualRuntime $Fixture.ActualRuntime -ActualAssets $Fixture.ActualAssets -ActualVersion $Fixture.ActualVersion -Phase $Phase }
function Invoke-ActualGateCli {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $PSHOME $(if ($edition -ceq 'ps51') { 'powershell.exe' } else { 'pwsh.exe' })
    $cli = Join-Path $projectRoot 'tools/Test-ReleaseGates.ps1'
    if ($cli.Contains('"')) { throw 'Unexpected CLI path quote.' }
    $info.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' + $cli + '" -Phase Acceptance'
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $info.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = New-Object Diagnostics.Process; $process.StartInfo = $info
    $script:gateReport['cli_process_released'] = $false; $script:gateReport['cli_pipe_drain_proved'] = $false
    try {
        if (-not $process.Start()) { throw 'Owned gate CLI did not start.' }
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill(); $process.WaitForExit(5000) | Out-Null
            throw 'Owned gate CLI startup/evidence check exceeded its deadline.'
        }
        if (-not [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),5000)) { throw 'Owned gate CLI pipes did not drain.' }
        $script:gateReport.cli_process_released = $true; $script:gateReport.cli_pipe_drain_proved = $true
        return [pscustomobject]@{ exit_code=$process.ExitCode; stdout=$stdout.Result; stderr=$stderr.Result }
    } finally { $process.Dispose() }
}
$script:gateReport=[ordered]@{schema_version=1;task='S12';mode='release_gate_contracts';command=[Environment]::CommandLine;started_utc=[DateTime]::UtcNow.ToString('o');tested_commit=(& git -C $projectRoot rev-parse HEAD | Out-String).Trim();shell=$PSVersionTable.PSVersion.ToString();shell_edition=$PSVersionTable.PSEdition;source_before=@();source_after=@();source_unchanged=$false;cases=@();fixture_semantics='In-memory contract fixtures only; no Windows client, physical, phone or package acceptance is created.';status='fail';error=$null}
$exitCode=1
try {
    $script:gateReport.source_before=Get-GateTestInventory
    Invoke-GateTestCase 'complete synthetic validator fixture accepts without publication authority' {
        $fixture=Copy-GateFixture (New-GateFixture);$result=Invoke-GateFixture $fixture
        Assert-GateTest ($result.status -ceq 'PASSED' -and -not $result.publication_authority_granted -and -not $result.publication_performed) 'Complete synthetic contract fixture should pass evidence checks only.'
    }
    $mutations=@(
        @{name='missing required report';code='EVIDENCE_MISSING_OR_DUPLICATE';change={param($f)$f.Reports=@($f.Reports|Select-Object -Skip 1)}},
        @{name='duplicate required report';code='EVIDENCE_MISSING_OR_DUPLICATE';change={param($f)$f.Reports+=Copy-GateFixture $f.Reports[0]}},
        @{name='raw report digest changed';code='REPORT_DIGEST';change={param($f)$f.Reports[0].digest_verified=$false}},
        @{name='historical aggregate cannot be candidate report';code='REPORT_SCHEMA';change={param($f)$f.Reports[0].record.kind='historical_step_summary'}},
        @{name='stale frozen source';code='STALE_SOURCE';change={param($f)$f.Candidate.source_commit='0'*40}},
        @{name='stale report source';code='STALE_EVIDENCE';change={param($f)$f.Reports[0].record.source_commit='0'*40}},
        @{name='stale report ZIP';code='STALE_EVIDENCE';change={param($f)$f.Reports[0].record.runtime_zip_sha256='0'*64}},
        @{name='stale report kit';code='STALE_EVIDENCE';change={param($f)$f.Reports[0].record.acceptance_kit_sha256='0'*64}},
        @{name='actual runtime changed';code='RUNTIME_MISMATCH';change={param($f)$f.ActualRuntime[0].sha256='0'*64}},
        @{name='report runtime changed';code='STALE_RUNTIME_EVIDENCE';change={param($f)$f.Reports[0].record.runtime_hashes[0].sha256='0'*64}},
        @{name='missing actual ZIP';code='ASSET_MISSING_OR_DUPLICATE';change={param($f)$f.ActualAssets=@($f.ActualAssets|Select-Object -Skip 1)}},
        @{name='changed actual ZIP';code='ASSET_CHANGED';change={param($f)$f.ActualAssets[0].sha256='0'*64}},
        @{name='duplicate runtime members';code='RUNTIME_INVENTORY';change={param($f)$f.Candidate.runtime_hashes+=Copy-GateFixture $f.Candidate.runtime_hashes[0]}},
        @{name='wrong fixed target';code='TARGET_MISMATCH';change={param($f)$f.Target.target_version='1.0.2'}},
        @{name='runtime1.0.0 cannot release1.0.1';code='RUNTIME_VERSION';change={param($f)$f.ActualVersion='1.0.0'}},
        @{name='Server CI cannot replace client';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.os_type='Server'}},
        @{name='Linux cannot replace client';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.os_family='Linux'}},
        @{name='Win11 cannot replace Win10';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.os_family='Windows11';$f.Reports[0].record.environment.build='26300.9711'}},
        @{name='wrong Win10 build';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.build='19044.1'}},
        @{name='x86 cannot replace x64';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.process_64bit=$false}},
        @{name='string boolean cannot prove x64';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.process_64bit='true'}},
        @{name='wrong recorded shell';code='CLIENT_ENVIRONMENT';change={param($f)$f.Reports[0].record.environment.shell_version='7.6.7'}},
        @{name='startup route is not core coverage';code='CORE_COVERAGE';change={param($f)$f.Reports[0].record.coverage='startup_only'}},
        @{name='missing execution command';code='REPORT_EXECUTION';change={param($f)$f.Reports[0].record.command=''}},
        @{name='end precedes start';code='REPORT_EXECUTION';change={param($f)$f.Reports[0].record.ended_utc='2026-10-27T12:00:00Z'}},
        @{name='missing required checks';code='REQUIRED_CHECK_NOT_PASSED';change={param($f)$f.Reports[0].record.checks=@()}},
        @{name='irrelevant checks cannot prove core coverage';code='REQUIRED_CHECK_NOT_PASSED';change={param($f)$f.Reports[0].record.checks[0].id='version_banner'}},
        @{name='duplicate required check';code='REQUIRED_CHECK_NOT_PASSED';change={param($f)$f.Reports[0].record.checks+=Copy-GateFixture $f.Reports[0].record.checks[0]}},
        @{name='missing expected actual result';code='REQUIRED_CHECK_NOT_PASSED';change={param($f)$f.Reports[0].record.checks[0].observed=''}},
        @{name='NOT_RUN nested required check';code='REQUIRED_CHECK_NOT_PASSED';change={param($f)$f.Reports[0].record.checks[0].status='NOT_RUN'}},
        @{name='partial owner collection';code='COLLECTION_INCOMPLETE';change={param($f)($f.Reports|Where-Object gate_id -eq 'full_collection').record.converted_count=0}},
        @{name='modified owner source';code='COLLECTION_INCOMPLETE';change={param($f)($f.Reports|Where-Object gate_id -eq 'one_file').record.source_unchanged=$false}},
        @{name='string boolean cannot prove source unchanged';code='COLLECTION_INCOMPLETE';change={param($f)($f.Reports|Where-Object gate_id -eq 'one_file').record.source_unchanged='true'}},
        @{name='string boolean cannot prove media validation';code='COLLECTION_INCOMPLETE';change={param($f)($f.Reports|Where-Object gate_id -eq 'full_collection').record.media_validated='true'}},
        @{name='string count cannot prove conversion total';code='COLLECTION_INCOMPLETE';change={param($f)($f.Reports|Where-Object gate_id -eq 'full_collection').record.converted_count='1'}},
        @{name='fabricated phone observation';code='HUMAN_OBSERVATION_MISSING';change={param($f)($f.Reports|Where-Object gate_id -eq 'phone_play_seek').record.evidence_type='simulation'}},
        @{name='missing physical observer';code='HUMAN_OBSERVATION_MISSING';change={param($f)($f.Reports|Where-Object gate_id -eq 'physical_shortcut').record.observer=''}},
        @{name='incomplete required step';code='STEP_INCOMPLETE';change={param($f)$f.State.steps.S15.status='BLOCKED'}}
    )
    foreach($mutation in $mutations){
        Invoke-GateTestCase ('refuses '+$mutation.name) {
            $fixture=Copy-GateFixture (New-GateFixture); & $mutation.change $fixture; $result=Invoke-GateFixture $fixture
            Assert-GateTest ($result.status -ceq 'REFUSED' -and @($result.failures|Where-Object code -ceq $mutation.code).Count -gt 0) ('Expected refusal '+$mutation.code)
        }
    }
    foreach($status in @('NOT_RUN','FAILED','BLOCKED','SKIPPED','PENDING','NOT_TESTED')){
        Invoke-GateTestCase ('refuses required report '+$status) {
            $fixture=Copy-GateFixture (New-GateFixture);$fixture.Reports[0].record.status=$status;$result=Invoke-GateFixture $fixture
            Assert-GateTest (@($result.failures|Where-Object code -ceq 'EVIDENCE_NOT_PASSED').Count -eq 1) 'Only PASSED required evidence satisfies the gate.'
        }
    }
    Invoke-GateTestCase 'publication requires separately started exact-byte authority' {
        $fixture=Copy-GateFixture (New-GateFixture);$result=Invoke-GateFixture $fixture 'Publication'
        Assert-GateTest (@($result.failures|Where-Object code -ceq 'PUBLICATION_AUTHORIZATION').Count -gt 0) 'Passing evidence cannot authorize publication.'
        $publicAssets=@($fixture.Candidate.assets | Where-Object { $_.name -cne 'Acceptance-Kit.zip' })
        $fixture.State.publication_authorization=[pscustomobject]@{step='S17';source_commit=$fixture.Candidate.source_commit;runtime_zip_sha256=$fixture.Candidate.runtime_zip_sha256;target_tag='v1.0.1';owner_started_s17=$true;assets=(Copy-GateFixture $publicAssets)}
        $result=Invoke-GateFixture $fixture 'Publication';Assert-GateTest ($result.status -ceq 'PASSED' -and -not $result.publication_authority_granted) 'Exact synthetic authority fixture validates without granting authority.'
        $fixture.State.publication_authorization.runtime_zip_sha256='0'*64;$result=Invoke-GateFixture $fixture 'Publication'
        Assert-GateTest (@($result.failures|Where-Object code -ceq 'PUBLICATION_AUTHORIZATION').Count -eq 1) 'Authority cannot follow changed bytes.'
        $fixture.State.publication_authorization.runtime_zip_sha256=$fixture.Candidate.runtime_zip_sha256
        $fixture.State.publication_authorization.owner_started_s17='true';$result=Invoke-GateFixture $fixture 'Publication'
        Assert-GateTest (@($result.failures|Where-Object code -ceq 'PUBLICATION_AUTHORIZATION').Count -eq 1) 'String booleans cannot prove human authorization.'
        $fixture.State.publication_authorization.owner_started_s17=$true
        $fixture.Candidate.assets[1].sha256='1'*64; $fixture.ActualAssets[1].sha256='1'*64
        $result=Invoke-GateFixture $fixture 'Publication'
        Assert-GateTest (@($result.failures|Where-Object code -ceq 'PUBLICATION_AUTHORIZATION').Count -gt 0) 'Unchanged ZIP cannot carry authority to a changed manifest asset.'
    }
    Invoke-GateTestCase 'actual frozen source guard accepts current source and binary asset bytes and rejects nonexistent commits' {
        $source=(& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
        $files=@((Read-ReleaseJson (Join-Path $projectRoot 'tools/package-files.json')).files)
        Assert-ReleaseFrozenSource -RepositoryRoot $projectRoot -SourceCommit $source -Paths $files
        $blob=Get-ReleaseGitBlobHash -RepositoryRoot $projectRoot -SourceCommit $source -RelativePath 'AudioFileForPhone.ico'
        $iconHash=(Get-FileHash -LiteralPath (Join-Path $projectRoot 'AudioFileForPhone.ico') -Algorithm SHA256).Hash.ToLowerInvariant()
        Assert-GateTest ($blob -ceq $iconHash) 'Binary Git read must preserve exact current icon bytes.'
        $refused=$false
        try { Assert-ReleaseFrozenSource -RepositoryRoot $projectRoot -SourceCommit ('0'*40) -Paths $files } catch { $refused=$true }
        Assert-GateTest $refused 'An invented frozen source must fail before evidence is evaluated.'
    }
    Invoke-GateTestCase 'external manifest requires exact source target ZIP and binary members' {
        $fixture=Copy-GateFixture (New-GateFixture)
        $manifest=[pscustomobject]@{schema_version=1;repository='PikkuJanne/AudioFileForPhone';app_version='1.0.1';tag='v1.0.1';release_commit=$fixture.Candidate.source_commit;zip=[pscustomobject]@{name='AudioFileForPhone-v1.0.1.zip';bytes=123;sha256=$fixture.Candidate.runtime_zip_sha256};files=[pscustomobject]@{'AudioFileForPhone.ps1'=('d'*64)}}
        Assert-ReleaseManifest $manifest $fixture.Candidate.source_commit $fixture.Candidate.runtime_zip_sha256 123 $fixture.ActualRuntime
        foreach($change in @(
            {param($m)$m.app_version='1.0.0'}, {param($m)$m.release_commit='0'*40},
            {param($m)$m.tag='v1.0.2'}, {param($m)$m.zip.name='other.zip'},
            {param($m)$m.zip.sha256='0'*64}, {param($m)$m.zip.bytes=124},
            {param($m)$m.files.'AudioFileForPhone.ps1'='0'*64}
        )) {
            $changed=Copy-GateFixture $manifest; & $change $changed; $refused=$false
            try { Assert-ReleaseManifest $changed $fixture.Candidate.source_commit $fixture.Candidate.runtime_zip_sha256 123 $fixture.ActualRuntime } catch { $refused=$true }
            Assert-GateTest $refused 'Changed manifest identity or bytes must refuse.'
        }
    }
    Invoke-GateTestCase 'actual historical record digest binding detects changed expected hash' {
        $path=Join-Path $projectRoot 'docs/codex-v1.0.1/evidence/S11.json';$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        $valid=Read-ReleaseBoundReport -Path $path -Sha256 $hash -GateId 'core_windows11_ps51'
        $changed=Read-ReleaseBoundReport -Path $path -Sha256 ('0'*64) -GateId 'core_windows11_ps51'
        Assert-GateTest ($valid.digest_verified -and -not $changed.digest_verified) 'Actual historical bytes must bind only to their actual digest; this is not candidate acceptance.'
        $fixture=Copy-GateFixture (New-GateFixture);$fixture.Reports[2]=$valid;$result=Invoke-GateFixture $fixture
        Assert-GateTest (@($result.failures|Where-Object code -ceq 'REPORT_SCHEMA').Count -gt 0) 'A digest-verified S11 COMPLETED aggregate must not satisfy a candidate client report.'
    }
    Invoke-GateTestCase 'actual repository CLI refuses absent candidate and preserves current evidence identity' {
        param($row)
        $actual=Invoke-ActualGateCli; $code=$actual.exit_code
        $result=$actual.stdout|ConvertFrom-Json -ErrorAction Stop
        $row.exit_code=$code; $row.actual_refusal_codes=@($result.failures|ForEach-Object code); $row.cli_stderr=$actual.stderr
        Assert-GateTest ($code -eq 1 -and $result.status -ceq 'REFUSED' -and @($result.failures|Where-Object code -ceq 'CANDIDATE_MISSING').Count -eq 1) 'Actual current repository cannot release without exact candidate evidence.'
        $row.exit_code=$code;$row.actual_refusal_codes=@($result.failures|ForEach-Object code);$row.publication_performed=$result.publication_performed
    }
    $script:gateReport.status='pass';$exitCode=0
} catch {$script:gateReport.error=$_.Exception.Message;$exitCode=1}
finally {
    $script:gateReport.source_after=Get-GateTestInventory
    $script:gateReport.source_unchanged=(($script:gateReport.source_before | ConvertTo-Json -Compress) -ceq ($script:gateReport.source_after | ConvertTo-Json -Compress))
    if(-not $script:gateReport.source_unchanged){$script:gateReport.status='fail';$script:gateReport.error='Gate source changed during test.';$exitCode=1}
    $script:gateReport.ended_utc=[DateTime]::UtcNow.ToString('o')
    Assert-ReleaseLocalFile (Join-Path $parent '..\RELEASE_TARGET.json')
    $stream=[IO.File]::Open($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {$writer=New-Object IO.StreamWriter($stream,(New-Object Text.UTF8Encoding($false)));try{$writer.WriteLine(($script:gateReport|ConvertTo-Json -Depth 20));$writer.Flush()}finally{$writer.Dispose()}}finally{$stream.Dispose()}
}
exit $exitCode
