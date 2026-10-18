# Functions-only policy for the deliberately small Windows test workflow.
# This is a review regression gate. GitHub read permissions and the absence of
# secret-bearing triggers are the execution boundary for untrusted PR code.

function Remove-CiYamlComment {
    param([string]$Text)
    $quote = [char]0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $character = $Text[$i]
        if ($quote -eq [char]0) {
            if ($character -eq [char]39 -or $character -eq [char]34) { $quote = $character }
            elseif ($character -eq '#' -and ($i -eq 0 -or [char]::IsWhiteSpace($Text[$i - 1]))) { return $Text.Substring(0, $i).TrimEnd() }
        } elseif ($character -eq $quote) {
            if ($quote -eq [char]39 -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq [char]39) { $i++ }
            else { $quote = [char]0 }
        } elseif ($quote -eq [char]34 -and $character -eq '\') { throw 'Escaped YAML double-quoted scalars are outside the reviewed subset.' }
    }
    if ($quote -ne [char]0) { throw 'Unterminated YAML quote.' }
    return $Text.TrimEnd()
}

function Convert-CiYamlScalar {
    param([string]$Value)
    $valueTrimmed = $Value.Trim()
    if ($valueTrimmed.StartsWith('[')) {
        if (-not $valueTrimmed.EndsWith(']')) { throw 'Invalid YAML flow sequence.' }
        $middle = $valueTrimmed.Substring(1, $valueTrimmed.Length - 2)
        if ([string]::IsNullOrWhiteSpace($middle)) { return ,@() }
        $items = New-Object 'Collections.Generic.List[object]'
        foreach ($part in $middle.Split(',')) {
            if ($part -match '[\[\]{}]') { throw 'Nested YAML flow collections are outside the reviewed subset.' }
            $items.Add((Convert-CiYamlScalar -Value $part))
        }
        return ,$items.ToArray()
    }
    if ($valueTrimmed.StartsWith("'")) {
        if (-not $valueTrimmed.EndsWith("'") -or $valueTrimmed.Length -lt 2) { throw 'Invalid YAML single-quoted scalar.' }
        return $valueTrimmed.Substring(1, $valueTrimmed.Length - 2).Replace("''", "'")
    }
    if ($valueTrimmed.StartsWith('"')) {
        if (-not $valueTrimmed.EndsWith('"') -or $valueTrimmed.Length -lt 2 -or $valueTrimmed.Contains('\')) { throw 'Unsupported YAML double-quoted scalar.' }
        return $valueTrimmed.Substring(1, $valueTrimmed.Length - 2)
    }
    if ($valueTrimmed -ceq 'true') { return $true }
    if ($valueTrimmed -ceq 'false') { return $false }
    if ($valueTrimmed -match '^(0|[1-9][0-9]*)$') { return [long]$valueTrimmed }
    if ([string]::IsNullOrEmpty($valueTrimmed) -or $valueTrimmed -match '^[&*!{>]|^---$|^\.\.\.$|^~$|^(?i:null|yes|no|on|off)$' -or $valueTrimmed.Contains(': ')) {
        throw 'Unsupported or ambiguous YAML scalar.'
    }
    return $valueTrimmed
}

function Read-CiYamlBlock {
    param([object[]]$Lines, [ref]$Index, [int]$Indent)
    if ($Index.Value -ge $Lines.Count -or $Lines[$Index.Value].indent -ne $Indent) { throw 'Invalid YAML indentation.' }
    if ($Lines[$Index.Value].text.StartsWith('- ')) {
        $sequence = New-Object 'Collections.Generic.List[object]'
        while ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -eq $Indent) {
            $line = $Lines[$Index.Value]
            if (-not $line.text.StartsWith('- ')) { throw 'Mixed YAML mapping and sequence.' }
            $header = $line.text.Substring(2)
            $Index.Value++
            if ($header -match '^[A-Za-z][A-Za-z0-9_-]*:') {
                $localLines = New-Object 'Collections.Generic.List[object]'
                $localLines.Add([pscustomobject]@{ indent = $Indent + 2; text = $header })
                while ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -gt $Indent) {
                    $localLines.Add($Lines[$Index.Value]); $Index.Value++
                }
                $localIndex = 0
                $value = Read-CiYamlBlock -Lines $localLines.ToArray() -Index ([ref]$localIndex) -Indent ($Indent + 2)
                if ($localIndex -ne $localLines.Count) { throw 'Incomplete YAML sequence item.' }
                $sequence.Add($value)
            } else {
                if ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -gt $Indent) { throw 'Nested scalar sequence item is unsupported.' }
                $sequence.Add((Convert-CiYamlScalar $header))
            }
        }
        return ,$sequence.ToArray()
    }
    $mapping = [ordered]@{}
    while ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -eq $Indent) {
        $line = $Lines[$Index.Value]
        if ($line.text -notmatch '^([A-Za-z][A-Za-z0-9_-]*):(?:\s+(.*))?$') { throw 'Unsupported YAML mapping key or construct.' }
        $key = $Matches[1]; $valueText = $Matches[2]
        if ($mapping.Contains($key)) { throw "Duplicate YAML key: $key" }
        $Index.Value++
        if ([string]::IsNullOrEmpty($valueText)) {
            if ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -gt $Indent) {
                if ($Lines[$Index.Value].indent -ne $Indent + 2) { throw 'YAML child indentation must use two spaces.' }
                $mapping[$key] = Read-CiYamlBlock -Lines $Lines -Index $Index -Indent ($Indent + 2)
            } else { $mapping[$key] = $null }
        } elseif ($valueText -ceq '|') {
            $body = New-Object 'Collections.Generic.List[string]'
            while ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -gt $Indent) {
                $bodyLine = $Lines[$Index.Value]
                if ($bodyLine.indent -lt $Indent + 2) { throw 'Invalid YAML literal block indentation.' }
                $body.Add((' ' * ($bodyLine.indent - $Indent - 2)) + $bodyLine.text)
                $Index.Value++
            }
            if ($body.Count -eq 0) { throw 'Empty YAML literal block is unsupported.' }
            $mapping[$key] = [string]::Join("`n", $body.ToArray())
        } else {
            $mapping[$key] = Convert-CiYamlScalar $valueText
            if ($Index.Value -lt $Lines.Count -and $Lines[$Index.Value].indent -gt $Indent) { throw 'Scalar YAML value cannot contain nested keys.' }
        }
    }
    return $mapping
}

function ConvertFrom-CiRestrictedYaml {
    param([Parameter(Mandatory = $true)][string]$Text)
    if ($Text.Contains("`t") -or $Text -match "`r(?!`n)") { throw 'YAML tabs and lone CR characters are unsupported.' }
    $lines = New-Object 'Collections.Generic.List[object]'
    foreach ($line in ($Text.Replace("`r`n", "`n") -split "`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) { continue }
        $content = Remove-CiYamlComment $line.TrimStart(' ')
        $indent = $line.Length - $line.TrimStart(' ').Length
        if ($indent % 2 -ne 0) { throw 'YAML indentation must use two spaces.' }
        $lines.Add([pscustomobject]@{ indent = $indent; text = $content })
    }
    if ($lines.Count -eq 0 -or $lines[0].indent -ne 0) { throw 'Workflow must be a top-level YAML mapping.' }
    $index = 0
    $document = Read-CiYamlBlock -Lines $lines.ToArray() -Index ([ref]$index) -Indent 0
    if ($index -ne $lines.Count -or $document -isnot [Collections.IDictionary]) { throw 'Entire workflow must use the reviewed YAML subset.' }
    return $document
}

function Assert-CiMapKeys {
    param($Value, [string[]]$Keys, [string]$Context)
    if ($Value -isnot [Collections.IDictionary] -or $Value.Count -ne $Keys.Count) { throw "Unexpected mapping shape: $Context" }
    foreach ($key in $Keys) { if (-not $Value.Contains($key)) { throw "Missing approved key $key at $Context" } }
    foreach ($key in $Value.Keys) { if ($Keys -cnotcontains [string]$key) { throw "Unapproved key $key at $Context" } }
}

function Assert-CiJsonUniqueKeys {
    param([string]$Text)
    $scopes = New-Object 'Collections.Generic.Stack[object]'
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $character = $Text[$i]
        if ($character -eq '"') {
            $start = ++$i
            while ($i -lt $Text.Length -and $Text[$i] -ne '"') { if ($Text[$i] -eq '\') { $i++ }; $i++ }
            if ($i -ge $Text.Length) { throw 'Unterminated JSON string.' }
            $stringValue = $Text.Substring($start, $i - $start)
            $next = $i + 1
            while ($next -lt $Text.Length -and [char]::IsWhiteSpace($Text[$next])) { $next++ }
            if ($next -lt $Text.Length -and $Text[$next] -eq ':') {
                if ($stringValue -notmatch '^[A-Za-z][A-Za-z0-9_]*$' -or $scopes.Count -eq 0 -or $null -eq $scopes.Peek()) { throw 'Unsupported JSON property name.' }
                if (-not $scopes.Peek().Add($stringValue)) { throw "Duplicate JSON property: $stringValue" }
            }
        } elseif ($character -eq '{') { $scopes.Push((New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase))) }
        elseif ($character -eq '[') { $scopes.Push($null) }
        elseif ($character -eq '}' -or $character -eq ']') { if ($scopes.Count -eq 0) { throw 'Unbalanced JSON.' }; [void]$scopes.Pop() }
    }
    if ($scopes.Count -ne 0) { throw 'Unbalanced JSON.' }
}

function Assert-CiLock {
    param([Parameter(Mandatory = $true)][string]$ManifestText)
    Assert-CiJsonUniqueKeys $ManifestText
    $lock = $ManifestText | ConvertFrom-Json -ErrorAction Stop
    if ($lock.schema_version -ne 1) { throw 'Unapproved dependency lock schema.' }
    $pins = @{
        ffmpeg = @{
            version = '9.0.2-essentials_build-www.gyan.dev'
            archive_url = 'https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip'
            archive_sha256 = '60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba'
            archive_bytes = [long]114768076; archive_file_count = 45
            inventory_sha256 = 'b8f58fcec6dfdff852e65404198bde4b4dcdb31e8865e99bfffe42d87b331bb5'
            ffmpeg_member = 'ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
            ffmpeg_sha256 = '3256173f3f8bffd7df12227c68adf68025edb1832273a9530688a7bb1ed8edec'
            ffprobe_member = 'ffmpeg-9.0.2-essentials_build/bin/ffprobe.exe'
            ffprobe_sha256 = 'f0d36ecbbdd3bcfac3efa078c96c7271c2e68b3810595552ac3b7f17e9a65c52'
            required_decoder = 'mp3'
        }
        analyzer = @{
            version = '1.25.0'; source_commit = 'f05704df81b2aca17dc027ee39b3fce106d418fc'
            archive_url = 'https://github.com/PowerShell/PSScriptAnalyzer/releases/download/1.25.0/PSScriptAnalyzer.1.25.0.nupkg'
            archive_sha256 = '14e634c828eb98efb9f40b2918ba90f139ed5eccdf663a2a747736d996995d60'
            archive_bytes = [long]14658674; archive_file_count = 53
            inventory_sha256 = '09b36e241037a55426a5b19820a8e251cf175b61956927af41c1f35a5910d2cb'
            module_member = 'PSScriptAnalyzer.psd1'
            module_manifest_sha256 = '2b219f688bcdd67101040f845e530b22907d39bbf49089b4b5b2afaba7996791'
            module_script_sha256 = 'b69773fc9080cfb958dc13c95e42a625553e9bca5dcbedc27231e5c183a4e869'
        }
    }
    foreach ($dependency in @('ffmpeg', 'analyzer')) {
        if ($null -eq $lock.$dependency) { throw "Missing dependency: $dependency" }
        foreach ($property in $pins[$dependency].Keys) {
            if ($null -eq $lock.$dependency.$property -or $lock.$dependency.$property -cne $pins[$dependency][$property]) { throw "Unapproved dependency pin: $dependency.$property" }
        }
    }
    if (($lock.ffmpeg.required_encoders -join ',') -cne 'libmp3lame,aac,libvorbis,libopus') { throw 'Unapproved encoder capability inventory.' }
    return $lock
}

function Assert-CiPolicy {
    param(
        [Parameter(Mandatory = $true)][string]$WorkflowText,
        [Parameter(Mandatory = $true)][string]$ManifestText,
        [Parameter(Mandatory = $true)][string[]]$WorkflowFiles
    )
    if ($WorkflowFiles.Count -ne 1 -or $WorkflowFiles[0].Replace('\', '/') -cne '.github/workflows/windows-ci.yml') { throw 'Only the reviewed Windows test workflow is authorized by this policy.' }
    if ($WorkflowText -match '\bsecrets\s*(?:\.|\[)') { throw 'Secret contexts are forbidden in test CI.' }
    foreach ($expression in [regex]::Matches($WorkflowText, '\$\{\{\s*(.*?)\s*\}\}')) {
        if (@('github.sha', 'github.run_id', 'github.run_attempt', 'matrix.shell', 'matrix.edition') -cnotcontains $expression.Groups[1].Value.Trim()) { throw 'Unapproved workflow expression.' }
    }
    $document = ConvertFrom-CiRestrictedYaml $WorkflowText
    Assert-CiMapKeys $document @('name', 'on', 'permissions', 'jobs') 'workflow'
    if ($document.name -isnot [string] -or [string]::IsNullOrWhiteSpace($document.name)) { throw 'Workflow name must be plain nonempty text.' }
    Assert-CiMapKeys $document.on @('push', 'pull_request') 'events'
    Assert-CiMapKeys $document.on.push @('branches') 'push'
    if (@($document.on.push.branches).Count -ne 1 -or $document.on.push.branches[0] -cne '**' -or $null -ne $document.on.pull_request) { throw 'Only all-branch pushes and ordinary unfiltered PR checks are approved; no tag or privileged trigger.' }
    Assert-CiMapKeys $document.permissions @('contents') 'permissions'
    if ($document.permissions.contents -cne 'read') { throw 'Test token requires read-only contents permissions.' }
    Assert-CiMapKeys $document.jobs @('windows') 'jobs'
    $job = $document.jobs.windows
    Assert-CiMapKeys $job @('runs-on', 'timeout-minutes', 'strategy', 'defaults', 'steps') 'windows job'
    if ($job['runs-on'] -cne 'windows-2025' -or $job['timeout-minutes'] -ne 20) { throw 'Only bounded GitHub-hosted Windows jobs are approved.' }
    Assert-CiMapKeys $job.strategy @('fail-fast', 'matrix') 'strategy'
    if ($job.strategy['fail-fast'] -isnot [bool] -or $job.strategy['fail-fast']) { throw 'Both supported shell jobs must report independently.' }
    Assert-CiMapKeys $job.strategy.matrix @('include') 'matrix'
    $matrix = @($job.strategy.matrix.include)
    if ($matrix.Count -ne 2) { throw 'Both supported shell/edition pairs are required.' }
    Assert-CiMapKeys $matrix[0] @('shell', 'edition') 'Desktop matrix'
    Assert-CiMapKeys $matrix[1] @('shell', 'edition') 'Core matrix'
    if ($matrix[0].shell -cne 'powershell' -or $matrix[0].edition -cne 'ps51' -or $matrix[1].shell -cne 'pwsh' -or $matrix[1].edition -cne 'ps7') { throw 'Supported shell matrix changed.' }
    Assert-CiMapKeys $job.defaults @('run') 'defaults'
    Assert-CiMapKeys $job.defaults.run @('shell') 'default shell'
    if ($job.defaults.run.shell -cne '${{ matrix.shell }}') { throw 'Every run step must select its matrix shell.' }
    $steps = @($job.steps)
    if ($steps.Count -ne 3) { throw 'Only checkout, verified checks and evidence upload steps are approved.' }
    Assert-CiMapKeys $steps[0] @('name', 'uses', 'with') 'checkout step'
    if ($steps[0].uses -cne 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1') { throw 'Checkout must use its reviewed official full commit SHA.' }
    Assert-CiMapKeys $steps[0].with @('ref', 'persist-credentials', 'fetch-depth', 'clean', 'submodules', 'lfs', 'allow-unsafe-pr-checkout') 'checkout inputs'
    if ($steps[0].with.ref -cne '${{ github.sha }}' -or $steps[0].with['fetch-depth'] -ne 1) { throw 'Checkout must use the exact event integration SHA.' }
    foreach ($inputName in @('persist-credentials', 'clean', 'submodules', 'lfs', 'allow-unsafe-pr-checkout')) {
        if ($steps[0].with[$inputName] -isnot [bool] -or $steps[0].with[$inputName]) { throw "Unsafe checkout input: $inputName" }
    }
    Assert-CiMapKeys $steps[1] @('name', 'env', 'run') 'check step'
    Assert-CiMapKeys $steps[1].env @('CI_RUN_LABEL', 'CI_EDITION') 'check environment'
    if ($steps[1].env.CI_RUN_LABEL -cne 'run${{ github.run_id }}_${{ github.run_attempt }}' -or $steps[1].env.CI_EDITION -cne '${{ matrix.edition }}') { throw 'Check run labels must derive only from trusted run IDs and the fixed matrix.' }
    $tokens = $null; $errors = $null
    $runAst = [Management.Automation.Language.Parser]::ParseInput([string]$steps[1].run, [ref]$tokens, [ref]$errors)
    $approvedStatements = @(
        '$ErrorActionPreference = ''Stop'''
        '$destination = Join-Path $env:RUNNER_TEMP (''AFP-CI-'' + [guid]::NewGuid().ToString(''N''))'
        '$evidence = Join-Path $env:GITHUB_WORKSPACE (''docs/codex-v1/evidence/T17-dependencies-'' + $env:CI_EDITION + ''-'' + $env:CI_RUN_LABEL + ''.json'')'
        '& (Join-Path $env:GITHUB_WORKSPACE ''.github/scripts/Initialize-CiDependencies.ps1'') -DestinationPath $destination -EvidencePath $evidence'
        '& (Join-Path $env:GITHUB_WORKSPACE ''.github/scripts/Invoke-CiChecks.ps1'') -DependenciesPath $evidence -RunLabel $env:CI_RUN_LABEL'
    )
    if ($errors.Count -ne 0 -or $null -ne $runAst.BeginBlock -or $null -ne $runAst.ProcessBlock -or $runAst.EndBlock.Statements.Count -ne $approvedStatements.Count) { throw 'Unapproved CI command structure.' }
    for ($i = 0; $i -lt $approvedStatements.Count; $i++) {
        if ($runAst.EndBlock.Statements[$i].Extent.Text.Trim() -cne $approvedStatements[$i]) { throw 'CI run blocks can only invoke the reviewed dependency and test entry chain.' }
    }
    Assert-CiMapKeys $steps[2] @('name', 'if', 'uses', 'with') 'artifact step'
    if ($steps[2].if -cne 'always()' -or $steps[2].uses -cne 'actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9') { throw 'Evidence upload must use the reviewed official full SHA and run after failed checks.' }
    Assert-CiMapKeys $steps[2].with @('name', 'path', 'retention-days', 'if-no-files-found', 'include-hidden-files') 'artifact inputs'
    $approvedArtifactPaths = [string]::Join("`n", @(
        'docs/codex-v1/evidence/T17-*-${{ matrix.edition }}-run${{ github.run_id }}_${{ github.run_attempt }}.json'
        'docs/codex-v1.0.1/evidence/S08-launcher-${{ matrix.edition }}-run${{ github.run_id }}_${{ github.run_attempt }}.json'
    ))
    if ($steps[2].with.name -cne 'windows-ci-${{ matrix.edition }}-${{ github.run_id }}-${{ github.run_attempt }}' -or
        $steps[2].with.path -cne $approvedArtifactPaths -or
        $steps[2].with['retention-days'] -ne 14 -or $steps[2].with['if-no-files-found'] -cne 'warn' -or
        $steps[2].with['include-hidden-files'] -isnot [bool] -or $steps[2].with['include-hidden-files']) { throw 'Artifact upload must contain only current-run JSON, bounded retention and no hidden files or overwrites.' }
    $lock = Assert-CiLock $ManifestText
    return [pscustomobject]@{
        status = 'pass'; workflow = $WorkflowFiles[0]; permissions = 'contents: read'
        events = @('branch push', 'pull_request merge integration'); shells = @('powershell/ps51', 'pwsh/ps7')
        checkout_commit = '3d3c42e5aac5ba805825da76410c181273ba90b1'
        artifact_commit = 'cf430e030ddbb5b0abf93d22962f4752f3646cd9'
        ffmpeg_version = $lock.ffmpeg.version; analyzer_version = $lock.analyzer.version
        release_write_path = $false; secret_contexts = $false
    }
}

function Test-CiPolicyMutations {
    param([string]$WorkflowText, [string]$ManifestText, [string[]]$WorkflowFiles)
    [void](Assert-CiPolicy -WorkflowText $WorkflowText -ManifestText $ManifestText -WorkflowFiles $WorkflowFiles)
    $mutations = @(
        @{ name = 'release-write token refused'; needle = 'contents: read'; replacement = 'contents: write' }
        @{ name = 'job permission override refused'; needle = '    runs-on: windows-2025'; replacement = "    permissions:`n      contents: write`n    runs-on: windows-2025" }
        @{ name = 'privileged PR trigger refused'; needle = '  pull_request:'; replacement = '  pull_request_target:' }
        @{ name = 'workflow_run trigger refused'; needle = '  pull_request:'; replacement = '  workflow_run:' }
        @{ name = 'tag trigger refused'; needle = "    branches: ['**']"; replacement = "    tags: ['**']" }
        @{ name = 'secret-bearing environment refused'; needle = '        env:'; replacement = "        env:`n          TOKEN: `${{ secrets.RELEASE_TOKEN }}" }
        @{ name = 'mutable action version refused'; needle = 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'; replacement = 'actions/checkout@v7' }
        @{ name = 'fork head checkout refused'; needle = '${{ github.sha }}'; replacement = '${{ github.event.pull_request.head.sha }}' }
        @{ name = 'persisted checkout credential refused'; needle = 'persist-credentials: false'; replacement = 'persist-credentials: true' }
        @{ name = 'unsafe checkout opt-out refused'; needle = 'allow-unsafe-pr-checkout: false'; replacement = 'allow-unsafe-pr-checkout: true' }
        @{ name = 'self-hosted execution refused'; needle = 'runs-on: windows-2025'; replacement = 'runs-on: self-hosted' }
        @{ name = 'hidden artifact upload refused'; needle = 'include-hidden-files: false'; replacement = 'include-hidden-files: true' }
        @{ name = 'artifact overwrite capability refused'; needle = '          retention-days: 14'; replacement = "          overwrite: true`n          retention-days: 14" }
        @{ name = 'release command injection refused'; needle = "          `$ErrorActionPreference = 'Stop'"; replacement = "          gh release create v1.0.0`n          `$ErrorActionPreference = 'Stop'" }
        @{ name = 'duplicate YAML permission key refused'; needle = 'permissions:'; replacement = "permissions:`n  contents: write`npermissions:" }
        @{ name = 'YAML anchor unsupported and refused'; needle = 'name: Windows CI'; replacement = 'name: &trusted Windows CI' }
        @{ name = 'dependency mutable URL refused'; lock = $true; needle = '/download/9.0.2/'; replacement = '/download/latest/' }
        @{ name = 'dependency wrong digest refused'; lock = $true; needle = '60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba'; replacement = ('0' * 64) }
        @{ name = 'duplicate JSON digest key refused'; lock = $true; needle = '"archive_bytes": 114768076'; replacement = '"archive_bytes": 1, "archive_bytes": 114768076' }
    )
    $results = New-Object 'Collections.Generic.List[object]'
    foreach ($mutation in $mutations) {
        $workflow = $WorkflowText; $manifest = $ManifestText
        if ($mutation.lock) {
            if (-not $manifest.Contains($mutation.needle)) { throw 'Policy negative lock fixture no longer matches reviewed data.' }
            $manifest = $manifest.Replace($mutation.needle, $mutation.replacement)
        } else {
            if (-not $workflow.Contains($mutation.needle)) { throw 'Policy negative workflow fixture no longer matches reviewed data.' }
            $workflow = $workflow.Replace($mutation.needle, $mutation.replacement)
        }
        $refusal = $null
        try { [void](Assert-CiPolicy -WorkflowText $workflow -ManifestText $manifest -WorkflowFiles $WorkflowFiles) } catch { $refusal = $_.Exception.Message }
        if ([string]::IsNullOrEmpty($refusal)) { throw "Unsafe policy mutation accepted: $($mutation.name)" }
        $results.Add([pscustomobject]@{ name = $mutation.name; status = 'pass'; refusal = $refusal; source_mutated = $false })
    }
    $extraRefusal = $null
    try { [void](Assert-CiPolicy -WorkflowText $WorkflowText -ManifestText $ManifestText -WorkflowFiles @($WorkflowFiles + '.github/workflows/release.yml')) } catch { $extraRefusal = $_.Exception.Message }
    if ([string]::IsNullOrEmpty($extraRefusal)) { throw 'Additional unreviewed workflow accepted.' }
    $results.Add([pscustomobject]@{ name = 'additional release workflow refused'; status = 'pass'; refusal = $extraRefusal; source_mutated = $false })
    return $results.ToArray()
}
