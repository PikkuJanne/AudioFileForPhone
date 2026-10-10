<#
.SYNOPSIS
Read-only check of local HEAD versus live GitHub refs for AudioFileForPhone.
.DESCRIPTION
No fetch/pull/push/commit/checkout occurs. This does not establish CI/manual-test
success. Network/ref/auth errors are failures. Validate on both Windows shells T01.
.EXAMPLE
.\Test-GitSync.ps1 -RepoPath 'C:\projects\AudioFileForPhone'
.EXAMPLE
.\Test-GitSync.ps1 -RepoPath 'C:\projects\AudioFileForPhone' -RequireMain -AsJson
#>
[CmdletBinding()]
param([string]$RepoPath = '.', [switch]$RequireMain, [switch]$AsJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Read-Git {
    param([string[]]$GitArguments)
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $text = @(& git --no-optional-locks -C $script:Repo @GitArguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $saved }
    if ($code -ne 0) { throw "Git read failed (exit $code); remote or local state was not verified." }
    return @($text | ForEach-Object { [string]$_ })
}
function Check-OriginUrl {
    param([string]$Url)
    return $Url -match '^(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)PikkuJanne/AudioFileForPhone(?:\.git)?/?$'
}
function Read-LiveRef {
    param([string]$RefName)
    $rows = @(Read-Git @('ls-remote','--exit-code','origin',$RefName))
    $hits = @($rows | Where-Object { ($_ -split '\s+').Count -eq 2 -and ($_ -split '\s+')[1] -ceq $RefName })
    if ($hits.Count -ne 1) { throw 'Expected exactly one matching live ref.' }
    $sha = ($hits[0] -split '\s+')[0]
    if ($sha -notmatch '^[a-f0-9]{40}$') { throw 'Unexpected live commit identifier.' }
    return $sha
}
$oldPrompt = $env:GIT_TERMINAL_PROMPT
try {
    $env:GIT_TERMINAL_PROMPT = '0'
    $null = Get-Command git -CommandType Application -ErrorAction Stop
    $script:Repo = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
    $fetch = @(Read-Git @('remote','get-url','--all','origin'))
    $push = @(Read-Git @('remote','get-url','--push','--all','origin'))
    if ($fetch.Count -ne 1 -or $push.Count -ne 1 -or
        -not (Check-OriginUrl $fetch[0]) -or -not (Check-OriginUrl $push[0])) {
        throw 'Unexpected origin fetch/push identity; no synchronization assertion is valid.'
    }
    $branchRows = @(Read-Git @('symbolic-ref','--quiet','--short','HEAD'))
    if ($branchRows.Count -ne 1) { throw 'A named active branch is required.' }
    $branch = $branchRows[0]
    $headRows = @(Read-Git @('rev-parse','--verify','HEAD'))
    if ($headRows.Count -ne 1 -or $headRows[0] -notmatch '^[a-f0-9]{40}$') { throw 'Invalid local HEAD.' }
    $head = $headRows[0]
    $dirty = @(Read-Git @('status','--porcelain=v1','--untracked-files=all'))
    if ($dirty.Count -gt 0) { throw 'Working tree has changes/untracked files; checkpoint is not clean.' }
    $sym = @(Read-Git @('ls-remote','--symref','origin','HEAD'))
    $defaults = @($sym | Where-Object { $_ -match '^ref:\s+refs/heads/[^\s]+\s+HEAD$' })
    if ($defaults.Count -ne 1 -or $defaults[0] -notmatch '^ref:\s+refs/heads/main\s+HEAD$') {
        throw 'Live default branch is not the expected main; reconcile the project plan.'
    }
    $liveBranch = Read-LiveRef ('refs/heads/' + $branch)
    $liveMain = Read-LiveRef 'refs/heads/main'
    if ($head -cne $liveBranch) { throw 'Local HEAD differs from the live active branch ref.' }
    if ($RequireMain -and ($branch -cne 'main' -or $head -cne $liveMain)) {
        throw 'Final check requires active main and HEAD equal to live main.'
    }
    $result = [ordered]@{
        status='pass'; repository='PikkuJanne/AudioFileForPhone'; branch=$branch;
        local_head=$head; live_branch=$liveBranch; live_main=$liveMain;
        active_branch_synchronized=$true; active_head_equals_main=($head -ceq $liveMain);
        clean=$true; verified_at_utc=[DateTime]::UtcNow.ToString('o');
        note='Observed live refs only; main integration/CI/manual acceptance are separate.'
    }
    if ($AsJson) { $result | ConvertTo-Json -Depth 4 } else { [pscustomobject]$result | Format-List | Out-Host }
    exit 0
} catch {
    if ($AsJson) { [ordered]@{status='fail'; reason=[string]$_.Exception.Message} | ConvertTo-Json }
    else { Write-Host ('FAIL: ' + $_.Exception.Message) }
    exit 1
} finally { $env:GIT_TERMINAL_PROMPT = $oldPrompt }
