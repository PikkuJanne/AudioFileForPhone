# S12 review

This review separates source inspection from executed client and Server evidence.
Final commands, identities, report digests, results and limits are recorded in
S12.json and S12-HANDOVER.md. Runtime remains byte-identical to
`b05b581dc6372cecd99471c53ee2cac72b8267ba`; no conversion policy is changed.

## Dependency and workflow pins

A read-only peer reviewer checked the official GitHub APIs on 2026-10-28,
approximately 18:55-18:57 UTC. The existing tested pins still match:

| Component | Verified identity |
|---|---|
| actions/checkout v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| actions/upload-artifact v7.0.2 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| Gyan 9.0.2 essentials ZIP | 114768076 bytes; SHA256 `60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba` |
| PSScriptAnalyzer 1.25.0 nupkg | 14658674 bytes; SHA256 `14e634c828eb98efb9f40b2918ba90f139ed5eccdf663a2a747736d996995d60` |
| PSScriptAnalyzer source tag | `f05704df81b2aca17dc027ee39b3fce106d418fc` |

Primary endpoints: [checkout tag](https://api.github.com/repos/actions/checkout/git/ref/tags/v7.0.1),
[upload-artifact tag](https://api.github.com/repos/actions/upload-artifact/git/ref/tags/v7.0.2),
[Gyan release](https://api.github.com/repos/GyanD/codexffmpeg/releases/tags/9.0.2),
[analyzer release](https://api.github.com/repos/PowerShell/PSScriptAnalyzer/releases/tags/1.25.0),
[analyzer tag](https://api.github.com/repos/PowerShell/PSScriptAnalyzer/git/ref/tags/1.25.0).
The lock records the original provenance and publisher trust limit; this refresh
does not pretend the same publisher independently authenticates its own bytes.

The workflow keeps ordinary branch-push and pull_request events, read-only
contents permission, exact event-SHA checkout, no persisted credential and no
unsafe PR opt-in. Dependency provisioning is explicit development/CI work.
Conversion and Check do not download. No release action, secret-bearing trigger,
main integration or publication authority is added.

## Source review and corrections

A peer reviewer who did not author the new clean-first and release-gate code
inspected the completed files. The authors supplied patches after their inherited
restricted write calls stalled; root applied, read back and executed the changes.
No child-agent execution pass is inferred from drafting or source inspection.

The new clean-first harness runs seven separate production processes with owned
configuration and sanitized child PATH: empty/stale/malformed no-tool refusals,
explicit external conversion without saving, deliberate production setup saving,
fresh saved selection, and app-local conversion. The three conversions require
actual completed manifests, exact64 stream/artist checks and independent unlimited
full decode. Existing first-run15 remains. Review made unexpected child errors
conservative: release becomes unproved before Start and is restored only after
exit and pipe drain, so exceptional cleanup refuses.

CI keeps its historical T17 paths and S08/S09/S10 contracts. New active reports
use narrow S06/S11/S12 paths. Corpus/online-setup run labels extend the existing
attempt/final contracts. Review corrected the new corpus validator to the exact
existing mode rather than changing the corpus. Actual Server caption/ProductType,
build, shell and supplementary acceptance class are recorded. Real online setup
is distinct from pinned CI dependency provisioning; offline injection remains
distinct from actual network acceptance. Native resource checks remain last.

Gate review required exact frozen source/control paths, literal local reports,
actual report/asset hashes, strict booleans/integer counts, mandatory per-gate
checks with expected/observed values and distinct required client cells. Source C
must exist and remain in history; documentation commits outside package paths may
follow it. Git autocrlf changes checkout bytes, so the CLI hashes binary C blobs,
matching the builder's exact-blob archive semantics. On this checkout, the helper
blob SHA256 is4618b3e2c1f47e92773180a16a7c950bb17f64aebceb536bac174bb0a43f06d1
while raw checkout SHA256 isa0aff73af92f73817b1b4341be6ec81d3326caca5ea37a6a71cc70fe38239b36.
Neither is relabeled as the other. The retained main-script blob/raw hash matches.

The external manifest must match fixed version/tag/C, actual ZIP name/size/digest
and full C member inventory; SHA256SUMS binds ZIP plus manifest. Publication-phase
authority binds all three exact public assets. The acceptance kit remains private.
Human observations do not invent phone or raw Explorer exits. A gate pass validates
trusted captures; it cannot prove that a fabricated experiment happened and grants
no authority. S17's live/main/draft/public-download checks remain separate.

Final read-only audit found no remaining S12 acceptance blocker after the checksum
local-path and frozen allowlist-control guards. Execution, environment acceptance
and exact-head CI outcomes are established by the actual reports in S12.json.

## Newly wired Server ACL fixture

The first exact-source push/PR CI at570ed713129a9800dee2ff5032cdf754ad0e6207
failed all four jobs at the S11 filesystem fixture's exact original-SDDL
restoration assertion. Actual readonly-app conversion and full decode passed.
The outer cleanup stopped at that guard, so child source/fixture/cleanup flags
remain unproved; the wrapper's overall repository source comparison passed.
Original/restored SDDL was not captured, so the particular changed section and
past root cause cannot be asserted.

PowerShell's Set-Acl provider can copy all security sections with a
privilege-dependent fallback. The fixture now persists only the DACL through a
fresh DirectorySecurity object, using the PS5.1 DirectoryInfo API or PS7
FileSystemAclExtensions API. Its owner/group/audit sections are not rewritten.
Full original SDDL equality remains exact: no AI/AR flag stripping, ACE sorting,
effective-permission substitution or redefined baseline. New reports capture
expected/denied/observed descriptors before the assertion; raw descriptors stay
outside public Git. The independent peer reviewer read back this narrow change.

Primary references: [DirectoryInfo.SetAccessControl](https://learn.microsoft.com/en-us/dotnet/api/system.io.directoryinfo.setaccesscontrol?view=netframework-4.7.2),
[FileSystemAclExtensions.SetAccessControl](https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemaclextensions.setaccesscontrol),
and the [PowerShell filesystem security provider](https://github.com/PowerShell/PowerShell/blob/master/src/System.Management.Automation/namespaces/FileSystemSecurity.cs).
The mechanism is a supported hypothesis for the old failure, not an invented
descriptor observation. Source76dab1faa0e883420bbc28b95c0ef2ae530d7f7e passes both
client filesystem307 suites and both analyzer303 reports. That Server rerun
failed again; the captured inheritance difference is recorded below.

## Observed inheritance conversion and pre-baseline fixture

Source76dab1f's four Server push/PR jobs still failed full-SDDL restoration, but
the new captures now show the difference: D: becomes D:AI; owner/group, ACE text/
order and protection flags are unchanged. This supersedes the earlier hypothesis
that copying owner/group sections caused this particular failure. Microsoft
documents that [modern security writes convert inheritance and set AI](https://learn.microsoft.com/en-us/windows/win32/secauthz/automatic-propagation-of-inheritable-aces).
No old failure is reclassified as successful restoration.

Source375adcdfdbc9d70001b21d8d495efb1384b1201d constructs the owned inherited
fixture before saving its immutable pre-deny baseline: persist identical DACL
once, then strictly compare DACL and captured-SACL binary bytes/order, owner/group,
ResourceManagerControl and control flags. Only AI0-to-1 (or unchanged established
AI) is permitted. Permission/ACE/order/protection/other flag changes refuse the
fixture. Initialization descriptors are recorded separately. It never runs during
restoration; restoration still requires the entire saved SDDL exactly.

The peer reviewer audited the applied initializer with no defect found. Client308
filesystem and analyzer304 reports pass. Source375adcd push40759426470 and
PR40759435259 pass all four Server jobs. Four downloaded wrappers and all80 child
digests verify; independent raw-report checks prove strict descriptor preservation
through fixture initialization, two full exact-SDDL restorations per job, source/
fixture immutability and cleanup. Each wrapper records974 checks/3observations.
ACL fixture changes had reviewer design and root readback/execution; this was a
shared design review. New clean-first and release-gate code had separate peer review.
The [obsolete SetFileSecurityW API](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-setfilesecurityw)
does not document an exact AI-off persistence guarantee; no unproved native
interop or flag-stripping workaround was added.

## Available client and release scope

The available client is Windows 11 Pro 26H2, build 26300.9711 x64, with Windows
PowerShell 5.1.26100.9711 and portable PowerShell 7.6.5. Store PowerShell 7.6.7
remains startup-route evidence only. GitHub-hosted Windows Server is supplementary.
No Server or Linux pass fills the required Windows 10 22H2 client cells.

Synthetic fixtures, owned configuration, private raw reports and hidden UTF8
drivers remain separate from ordinary Music, personal media and owner settings.
Current runtime and historical reports are not relabeled as an accepted future
1.0.1 ZIP. Physical/phone, exact ZIP and unavailable storage observations remain
explicit later acceptance requirements.
