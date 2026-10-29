<#
T16 A42: exercise retained cleanup decisions on exclusively owned TEMP fixtures.
Functions and cleanup IfStatements come from the actual harness ASTs. The only
cleanup-body instrumentation records entry into the original delete statement.
No conversion host, FFmpeg process, personal media or ordinary Music is used.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EvidencePath)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$evidenceParent = Join-Path $projectRoot 'docs\codex-v1\evidence'
$evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
if ((Split-Path -Parent $evidenceFullPath) -ine $evidenceParent -or
    (Split-Path -Leaf $evidenceFullPath) -notmatch '^T16-cleanup-(ps51|ps7)-(attempt|final)[1-9][0-9]*\.json$') {
    throw 'EvidencePath must be a fresh T16-cleanup-<edition>-attempt/finalN.json directly in docs/codex-v1/evidence.'
}
if (Test-Path -LiteralPath $evidenceFullPath) { throw 'Evidence already exists; use a fresh label.' }

$harnessNames = @('Test-AudioFileForPhone.ps1', 'Invoke-IsolatedBaseline.ps1', 'Test-Preflight.ps1', 'Test-Discovery.ps1',
    'Test-NamingPlan.ps1', 'Test-RunReservation.ps1', 'Test-NativeProcess.ps1',
    'Test-TransactionalOutput.ps1', 'Test-ScriptResults.ps1', 'Test-LauncherResults.ps1',
    'Test-Cancellation.ps1', 'Test-Preview.ps1', 'Test-Progress.ps1',
    'Test-Diagnostics.ps1', 'Test-Metadata.ps1', 'Test-OutputParent.ps1')
$sourceFiles = @('AudioFileForPhone.ps1', 'AudioFileForPhone.Helpers.ps1', 'AudioFileForPhone.Diagnostics.ps1', 'AudioFileForPhone.bat',
    'tests/Test-BaselineCharacterization.ps1', 'tests/Test-CleanupSafety.ps1') +
    @($harnessNames | ForEach-Object { 'tests/' + $_ })
$suiteRoot = $null; $suiteReserved = $false; $suiteToken = [guid]::NewGuid().ToString('N')
$suiteOwner = $null; $policies = @(); $registeredLinks = New-Object 'System.Collections.Generic.List[object]'
$protectedFiles = @(); $exitCode = 1
$report = [ordered]@{
    schema_version = 1; task = 'T16'; mode = 'retained_cleanup_guard_faults'
    command = [Environment]::CommandLine; started_utc = [DateTime]::UtcNow.ToString('o')
    shell = $PSVersionTable.PSVersion.ToString(); shell_edition = $PSVersionTable.PSEdition
    os = [Environment]::OSVersion.Version.ToString()
    windows_build = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber + '.' +
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)
    tested_commit = (& git -C $projectRoot rev-parse HEAD | Out-String).Trim()
    source_before = @(); source_after = @(); source_unchanged = $false
    synthetic_before = @(); synthetic_after = @(); synthetic_unchanged = $false
    synthetic_inventory_scope = 'Protected source/unrelated text sentinels; negative cases additionally compare their whole owned case inventory.'
    owned_temp_root = $null; temp_exclusively_reserved = $false; marker_create_new = $false; owner_marker_sha256 = $null
    policies = @(); cases = @(); media_or_controlled_native_children_started = 0; children_disposed = $true
    ordinary_music_access = $false; physical_manual_evidence = $false
    links_removed = $false; cleanup_verified = $false; status = 'fail'; error = $null
}

function Assert-Safety { param([bool]$Condition, [string]$Message); if (-not $Condition) { throw "FAIL: $Message" } }
function Get-TextHash {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Read-TestAst {
    param([string]$Name)
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $Name), [ref]$tokens, [ref]$errors)
    Assert-Safety (@($errors).Count -eq 0) "Retained harness must parse: $Name"
    return $ast
}
function Get-TestFunction {
    param([object]$Ast, [string]$Name)
    $functions = @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        Where-Object { $_.Name -ceq $Name })
    Assert-Safety ($functions.Count -eq 1) "Expected one actual function: $Name"
    return $functions[0].Extent.Text
}
function Get-RetainedPolicy {
    param([string]$Name)
    $ast = Read-TestAst $Name
    $deletes = @($ast.FindAll({ param($node)
        ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $node.Static -and
            $node.Member.Value -eq 'Delete' -and $node.Expression.Extent.Text -match 'Directory') -or
        ($node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Remove-Item')
    }, $true) | Where-Object { $_.Extent.Text -match '\$resolved' })
    $choices = @()
    foreach ($delete in $deletes) {
        $parent = $delete.Parent; $guard = $null
        while ($null -ne $parent) {
            if ($parent -is [Management.Automation.Language.IfStatementAst] -and
                $parent.Clauses[0].Item1.Extent.Text -match '\$(ownedRootCreated|tempRootReserved)') { $guard = $parent }
            $parent = $parent.Parent
        }
        if ($null -ne $guard) { $choices += [pscustomobject]@{ guard = $guard; delete = $delete } }
    }
    Assert-Safety ($choices.Count -eq 1) "Expected one actual TEMP cleanup body: $Name"
    $choice = $choices[0]
    $statement = $choice.delete
    while ($statement -isnot [Management.Automation.Language.PipelineAst]) { $statement = $statement.Parent }
    $original = $choice.guard.Extent.Text
    $offset = $statement.Extent.StartOffset - $choice.guard.Extent.StartOffset
    $observer = '$deletionFlag.Reached = $true; '
    $instrumented = $original.Insert($offset, $observer)
    Assert-Safety ($instrumented.Remove($offset, $observer.Length) -ceq $original) 'Only a delete-entry observer may be inserted.'
    $functions = @()
    foreach ($functionName in @('Assert-True', 'Assert-NoReparse', 'Get-SafeTree', 'Assert-NoReparseTree', 'Get-FixtureInventory')) {
        $found = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) |
            Where-Object { $_.Name -ceq $functionName })
        if ($found.Count -eq 1) { $functions += $found[0].Extent.Text }
    }
    return [pscustomobject]@{
        name = $Name; original = $original; body = [scriptblock]::Create($instrumented)
        definitions = [scriptblock]::Create(($functions -join [Environment]::NewLine))
        line = $choice.guard.Extent.StartLineNumber; original_sha256 = Get-TextHash $original
        children_gate = ($original -match '\$(childrenStopped|childrenReleased|allChildrenStopped|nativeReleaseProved)')
        acl_gate = ($original -match '\$aclRestoreSuccess')
        verification_field = ($original -match '\$report\.(cleanup_verified|temp_cleanup_verified)')
    }
}
function Invoke-RetainedCleanup {
    param([object]$Policy, [string]$Root, [string]$ExpectedParent, [string]$ExpectedName,
        [string]$Marker, [string]$Token, [bool]$Reserved = $true,
        [bool]$ReleaseProved = $true, [bool]$AclRestored = $true)
    # These are the retained body variables, with empty registrations because this
    # harness owns no child processes, native long-path fixtures or registered links
    # inside the candidate tree. Reparse negatives remain unregistered intentionally.
    $testRoot = $Root; $tempParent = $ExpectedParent; $testName = $ExpectedName
    $ownerFile = $Marker; $ownerToken = $Token; $ownedRootCreated = $Reserved
    $tempRootReserved = $Reserved; $tempMarkerCreated = $Reserved
    $childrenStopped = $ReleaseProved; $childrenReleased = $ReleaseProved
    $allChildrenStopped = $ReleaseProved; $nativeReleaseProved = $ReleaseProved
    $aclRestoreSuccess = $AclRestored
    $nativeFiles = @(); $nativeDirectories = @(); $ownedRuns = @(); $links = @(); $fixtures = @()
    $report = [ordered]@{ cleanup_verified = $false; temp_cleanup_verified = $false; fixtures_before = $null; status = 'pass' }
    $deletionFlag = [pscustomobject]@{ Reached = $false }; $errorText = $null
    try { . $Policy.definitions; & $Policy.body | Out-Null }
    catch { $errorText = $_.Exception.Message }
    return [pscustomobject]@{
        delete_reached = $deletionFlag.Reached; refused_exception = $errorText
        removed = -not (Test-Path -LiteralPath $Root)
        cleanup_verified = $(if ($Policy.verification_field) { $report.cleanup_verified -or $report.temp_cleanup_verified } else { $null })
    }
}
function Write-OwnedText {
    param([string]$Path, [string]$Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes($Text); $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}
function New-OwnedDirectory {
    param([string]$Path)
    New-ExclusiveDirectory $Path
    return $Path
}
function Get-Inventory {
    param([string]$Root)
    $pending = New-Object 'System.Collections.Generic.Stack[string]'; $pending.Push($Root)
    $items = @()
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            $item.Refresh(); $reparse = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            $items += [pscustomobject]@{
                relative_path = $item.FullName.Substring($Root.Length + 1); directory = $item.PSIsContainer
                attributes = [int]$item.Attributes; last_write_utc = $item.LastWriteTimeUtc.ToString('o')
                length = $(if (-not $item.PSIsContainer -and -not $reparse) { $item.Length } else { $null })
                sha256 = $(if (-not $item.PSIsContainer -and -not $reparse) { (Get-FileHash -LiteralPath $item.FullName).Hash.ToLowerInvariant() } else { $null })
            }
            if ($item.PSIsContainer -and -not $reparse) { $pending.Push($item.FullName) }
        }
    }
    return @($items | Sort-Object relative_path)
}
function Get-SourceInventory {
    return @($sourceFiles | ForEach-Object { [pscustomobject]@{
        relative_path = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_)).Hash.ToLowerInvariant()
    } })
}
function Get-ProtectedInventory {
    return @($protectedFiles | ForEach-Object { [pscustomobject]@{
        relative_path = $_.Substring($suiteRoot.Length + 1); sha256 = (Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()
    } })
}
function New-RegisteredJunction {
    param([string]$Path, [string]$Target)
    Assert-Safety ($Path.StartsWith($suiteRoot + '\', [StringComparison]::OrdinalIgnoreCase) -and
        $Target.StartsWith($suiteRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Junction fixtures must remain inside the owned suite.'
    New-Item -ItemType Junction -Path $Path -Target $Target -ErrorAction Stop | Out-Null
    $registeredLinks.Add([pscustomobject]@{ path = $Path; directory = $true })
    Assert-Safety (((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Real junction required.'
}
function Remove-RegisteredLinks {
    foreach ($link in $registeredLinks.ToArray()) {
        Assert-Safety ($link.path.StartsWith($suiteRoot + '\', [StringComparison]::OrdinalIgnoreCase)) 'Only registered owned links may be removed.'
        Assert-NoReparse (Split-Path -Parent $link.path)
        $item = Get-Item -LiteralPath $link.path -Force -ErrorAction Stop
        Assert-Safety (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Registered link must remain a reparse entry.'
        if ($link.directory) { [IO.Directory]::Delete($link.path, $false) } else { [IO.File]::Delete($link.path) }
        Assert-Safety (-not (Test-Path -LiteralPath $link.path)) 'Link removal must be nonrecursive and complete.'
    }
    $registeredLinks.Clear()
}
function Add-Case {
    param([string]$Name, [string]$Harness, [scriptblock]$Body)
    $case = [ordered]@{ name = $Name; retained_harness = $Harness; acceptance_case = 'A42'; status = 'fail' }
    try { & $Body $case; $case.status = 'pass' }
    finally { $report.cases += [pscustomobject]$case }
}

try {
    # Import inert, actual reservation/reparse/evidence helpers, without running
    # any retained harness top-level code or its production entry.
    $baselineAst = Read-TestAst 'Invoke-IsolatedBaseline.ps1'
    . ([scriptblock]::Create((Get-TestFunction $baselineAst 'Assert-NoReparse')))
    . ([scriptblock]::Create((Get-TestFunction $baselineAst 'Write-NewEvidence')))
    $nativeAst = Read-TestAst 'Test-NativeProcess.ps1'
    . ([scriptblock]::Create((Get-TestFunction $nativeAst 'New-ExclusiveDirectory')))
    Assert-NoReparse $evidenceParent
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
    Assert-NoReparse $tempParent
    $suiteRoot = Join-Path $tempParent ('AFP-Cleanup-' + [guid]::NewGuid().ToString('N'))
    New-OwnedDirectory $suiteRoot | Out-Null; $suiteReserved = $true
    $suiteOwner = Join-Path $suiteRoot '.t16-owner'; Write-OwnedText $suiteOwner $suiteToken
    $report.owned_temp_root = $suiteRoot; $report.temp_exclusively_reserved = $true; $report.marker_create_new = $true
    $report.owner_marker_sha256 = (Get-FileHash -LiteralPath $suiteOwner).Hash.ToLowerInvariant()
    $report.source_before = Get-SourceInventory
    $protectedRoot = New-OwnedDirectory (Join-Path $suiteRoot 'Protected')
    foreach ($name in @('source-one.bin', 'source-two.bin', 'unrelated-one.bin', 'unrelated-two.bin')) {
        $path = Join-Path $protectedRoot $name; Write-OwnedText $path ('T16 immutable synthetic sentinel: ' + $name); $protectedFiles += $path
    }
    $report.synthetic_before = Get-ProtectedInventory
    $policies = @($harnessNames | ForEach-Object { Get-RetainedPolicy $_ })
    $report.policies = @($policies | ForEach-Object { [pscustomobject]@{
        retained_harness = $_.name; cleanup_start_line = $_.line; cleanup_ast_sha256 = $_.original_sha256
        instrumentation = 'Only an observer before the unchanged recursive delete statement.'
        scope = 'Actual TEMP cleanup IfStatement; parent finalizer statements are not executed.'
        descendant_release_gate = $_.children_gate; acl_restore_gate = $_.acl_gate
        retained_cleanup_verified_field = $_.verification_field
    } })

    foreach ($policy in $policies) {
        $modes = @('valid-exclusive', 'preexisting-unreserved', 'outside-parent', 'prefix-sibling',
            'missing-marker', 'wrong-marker', 'root-junction', 'ancestor-junction', 'child-junction', 'file-reparse')
        if ($policy.children_gate) { $modes += 'unproved-release' }
        if ($policy.acl_gate) { $modes += 'unrestored-acl' }
        foreach ($mode in $modes) {
            Add-Case $mode $policy.name {
                param($case)
                $world = New-OwnedDirectory (Join-Path $suiteRoot ([guid]::NewGuid().ToString('N')))
                $case['owned_case_relative_path'] = Split-Path -Leaf $world
                $target = New-OwnedDirectory (Join-Path $world 'Root')
                $outside = New-OwnedDirectory (Join-Path $world 'Root-sibling')
                Write-OwnedText (Join-Path $outside 'sentinel.bin') 'Outside candidate cleanup scope.'
                $marker = Join-Path $target '.owner'; $token = [guid]::NewGuid().ToString('N')
                Write-OwnedText $marker $token; Write-OwnedText (Join-Path $target 'payload.bin') 'Owned candidate payload.'
                $expectedParent = $world; $expectedName = 'Root'; $reserved = $true; $release = $true; $acl = $true
                switch ($mode) {
                    'preexisting-unreserved' { $reserved = $false }
                    'outside-parent' { $expectedParent = New-OwnedDirectory (Join-Path $world 'Expected-parent') }
                    'prefix-sibling' { $expectedName = 'Roo' }
                    'missing-marker' { [IO.File]::Delete($marker) }
                    'wrong-marker' { [IO.File]::WriteAllText($marker, 'wrong synthetic token') }
                    'root-junction' {
                        $link = Join-Path $world 'Root-link'; New-RegisteredJunction $link $target
                        $target = $link; $marker = Join-Path $target '.owner'; $expectedName = 'Root-link'
                    }
                    'ancestor-junction' {
                        $link = Join-Path $world 'Ancestor-link'; New-RegisteredJunction $link $world
                        $target = Join-Path $link 'Root'; $marker = Join-Path $target '.owner'; $expectedParent = $link
                    }
                    'child-junction' { New-RegisteredJunction (Join-Path $target 'Child-link') $outside }
                    'file-reparse' {
                        if (-not ('AudioFileForPhoneT06.NativeFixture' -as [type])) {
                            $discoveryAst = Read-TestAst 'Test-Discovery.ps1'
                            $compile = @($discoveryAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and
                                $node.GetCommandName() -eq 'Add-Type' -and $node.Extent.Text -match 'CreateCustomFileReparse' }, $true))
                            Assert-Safety ($compile.Count -eq 1) 'Use the actual retained file-reparse fixture implementation.'
                            & ([scriptblock]::Create($compile[0].Extent.Text)) | Out-Null
                        }
                        $fileLink = Join-Path $target 'File-link.bin'; $fileTarget = Join-Path $outside 'sentinel.bin'
                        $created = [AudioFileForPhoneT06.NativeFixture]::CreateSymbolicLinkW($fileLink, $fileTarget, 2)
                        $unprivilegedError = [Runtime.InteropServices.Marshal]::GetLastWin32Error(); $ordinaryError = 0
                        if (-not $created) {
                            $created = [AudioFileForPhoneT06.NativeFixture]::CreateSymbolicLinkW($fileLink, $fileTarget, 0)
                            $ordinaryError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                        }
                        $case['file_symlink_available'] = $created; $case['unprivileged_error'] = $unprivilegedError; $case['ordinary_error'] = $ordinaryError
                        if (-not $created) {
                            Assert-Safety ([AudioFileForPhoneT06.NativeFixture]::CreateCustomFileReparse($fileLink) -eq 0) 'Actual inert file-reparse fallback must be created.'
                        }
                        $registeredLinks.Add([pscustomobject]@{ path = $fileLink; directory = $false })
                        Assert-Safety (((Get-Item -LiteralPath $fileLink -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Actual file reparse attribute required.'
                        $case['file_reparse_kind'] = $(if ($created) { 'symbolic link' } else { 'retained inert custom name-surrogate tag 0x2000A06E' })
                    }
                    'unproved-release' { $release = $false }
                    'unrestored-acl' { $acl = $false }
                }
                $before = Get-Inventory $world
                $outcome = Invoke-RetainedCleanup $policy $target $expectedParent $expectedName $marker $token $reserved $release $acl
                $case['delete_reached'] = $outcome.delete_reached; $case['guard_reason'] = $outcome.refused_exception
                if ($mode -eq 'valid-exclusive') {
                    Assert-Safety ($outcome.delete_reached -and $outcome.removed -and -not $outcome.refused_exception -and
                        (-not $policy.verification_field -or $outcome.cleanup_verified)) 'Actual guard must delete the valid exact owned candidate.'
                    Assert-Safety ([IO.File]::ReadAllText((Join-Path $outside 'sentinel.bin')) -ceq 'Outside candidate cleanup scope.') 'Sibling sentinel must survive positive cleanup.'
                    $case['exact_owned_target_removed'] = $true
                } else {
                    Assert-Safety (-not $outcome.delete_reached -and -not $outcome.removed) 'Guard refusal must precede the original delete statement.'
                    $after = Get-Inventory $world
                    Assert-Safety (($before | ConvertTo-Json -Depth 5 -Compress) -ceq ($after | ConvertTo-Json -Depth 5 -Compress)) 'Refused cleanup must preserve whole case inventory and unrelated sentinels.'
                    $case['whole_case_inventory_unchanged'] = $true
                }
                Remove-RegisteredLinks
            }
        }
    }

    foreach ($name in @('Invoke-IsolatedBaseline.ps1', 'Test-Preflight.ps1')) {
        $ast = Read-TestAst $name
        $definition = [scriptblock]::Create((Get-TestFunction $ast 'Assert-NoReparse') + [Environment]::NewLine + (Get-TestFunction $ast 'Write-NewEvidence'))
        foreach ($mode in @('unique-json-disposed', 'preexisting-evidence', 'outside-evidence-parent', 'reparse-evidence-ancestor')) {
            Add-Case $mode $name {
                param($case)
                $world = New-OwnedDirectory (Join-Path $suiteRoot ([guid]::NewGuid().ToString('N')))
                $case['owned_case_relative_path'] = Split-Path -Leaf $world
                $approved = New-OwnedDirectory (Join-Path $world 'Evidence'); $other = New-OwnedDirectory (Join-Path $world 'Other')
                $path = Join-Path $approved 'new.json'; $evidenceParent = $approved
                if ($mode -eq 'preexisting-evidence') { Write-OwnedText $path 'existing evidence sentinel' }
                if ($mode -eq 'outside-evidence-parent') { $path = Join-Path $other 'new.json' }
                if ($mode -eq 'reparse-evidence-ancestor') {
                    $link = Join-Path $world 'Evidence-link'; New-RegisteredJunction $link $approved
                    $evidenceParent = $link; $path = Join-Path $link 'new.json'
                }
                $before = Get-Inventory $world; $refused = $false
                $roundTripValue = 'quoted "Unicode" ' + [char]0x00e9 + [char]0x4e2d
                try { . $definition; Write-NewEvidence -Path $path -Document ([ordered]@{ status = 'pass'; value = $roundTripValue }) -Depth 5 }
                catch { $refused = $true; $case['guard_reason'] = $_.Exception.Message }
                if ($mode -eq 'unique-json-disposed') {
                    Assert-Safety (-not $refused) 'Actual writer must accept a unique approved evidence file.'
                    Assert-Safety ((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).value -ceq $roundTripValue) 'Actual evidence JSON must round-trip.'
                    $handle = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                    $handle.Dispose(); $case['exclusive_reopen_after_write'] = $true
                } else {
                    Assert-Safety $refused 'Actual writer must refuse existing/outside/reparse evidence.'
                    Assert-Safety (($before | ConvertTo-Json -Depth 5 -Compress) -ceq ((Get-Inventory $world) | ConvertTo-Json -Depth 5 -Compress)) 'Refused writer must preserve whole evidence fixture inventory.'
                    $case['whole_case_inventory_unchanged'] = $true
                }
                Remove-RegisteredLinks
            }
        }
    }
    $report.status = 'pass'; $exitCode = 0
}
catch { $report.error = $_.Exception.Message; $report['error_location'] = $_.ScriptStackTrace; Write-Warning $report.error }
finally {
    $linksSafe = -not $suiteReserved
    try {
        if ($suiteReserved) {
            Remove-RegisteredLinks; $report.links_removed = $true; $linksSafe = $true
        }
    } catch { $report.status = 'fail'; $exitCode = 1; $report['link_cleanup_error'] = $_.Exception.Message }
    try {
        if ($suiteReserved) {
            $report.synthetic_after = Get-ProtectedInventory
            $report.synthetic_unchanged = (($report.synthetic_before | ConvertTo-Json -Compress) -ceq ($report.synthetic_after | ConvertTo-Json -Compress))
            Assert-Safety $report.synthetic_unchanged 'Protected source/unrelated synthetic sentinel hashes must remain exact.'
        }
    } catch { $report.status = 'fail'; $exitCode = 1; $report['synthetic_verification_error'] = $_.Exception.Message }
    try {
        $report.source_after = Get-SourceInventory
        $report.source_unchanged = (($report.source_before | ConvertTo-Json -Compress) -ceq ($report.source_after | ConvertTo-Json -Compress))
        Assert-Safety $report.source_unchanged 'Production and tested harness bytes must remain unchanged during execution.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['source_verification_error'] = $_.Exception.Message }
    try {
        if ($suiteReserved -and $linksSafe) {
            Assert-Safety ((Get-FileHash -LiteralPath $suiteOwner).Hash -ieq $report.owner_marker_sha256) 'Recorded exact marker hash must still agree before suite cleanup.'
            $ownPolicy = Get-RetainedPolicy 'Test-Metadata.ps1'
            $outcome = Invoke-RetainedCleanup $ownPolicy $suiteRoot (Split-Path -Parent $suiteRoot) (Split-Path -Leaf $suiteRoot) $suiteOwner $suiteToken
            $report.cleanup_verified = $outcome.delete_reached -and $outcome.removed -and $outcome.cleanup_verified
            Assert-Safety $report.cleanup_verified ('Exact owned suite cleanup must be proved: ' + $outcome.refused_exception)
        }
        Assert-Safety $report.cleanup_verified 'Exact owned suite cleanup must be verified; uncertain registered links preserve the suite.'
    } catch { $report.status = 'fail'; $exitCode = 1; $report['cleanup_error'] = $_.Exception.Message }
    $report['finished_utc'] = [DateTime]::UtcNow.ToString('o')
    # Restore approved repository evidence scope after the writer-negative calls.
    $evidenceParent = Join-Path $projectRoot 'docs\codex-v1\evidence'
    . ([scriptblock]::Create((Get-TestFunction (Read-TestAst 'Invoke-IsolatedBaseline.ps1') 'Assert-NoReparse')))
    . ([scriptblock]::Create((Get-TestFunction (Read-TestAst 'Invoke-IsolatedBaseline.ps1') 'Write-NewEvidence')))
    Write-NewEvidence -Path $evidenceFullPath -Document $report -Depth 16
}
Write-Host "T16 cleanup: $($report.status); cases=$($report.cases.Count); sources/sentinels=$($report.source_unchanged)/$($report.synthetic_unchanged); cleanup=$($report.cleanup_verified)"
exit $exitCode
