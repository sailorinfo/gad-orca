#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$Package)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Mechanical execution only. Lead must reconcile the actual Human Gate and
# review evidence outside this tool; package fields never authenticate either.
function Native([string]$exe, [string[]]$argv, [string]$cwd) {
    Push-Location -LiteralPath $cwd
    try {
        $binary = (Get-Command $exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $prior=$ErrorActionPreference; $ErrorActionPreference='Continue'
        try { $out = @(& $binary @argv 2>&1); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference=$prior }
        return [pscustomobject]@{ code=$code; text=($out -join "`n").Trim() }
    } finally { Pop-Location }
}
function Git([string[]]$argv) { Native 'git' $argv $script:repo }
function Require([bool]$ok, [string]$why) { if (-not $ok) { throw $why } }
function GitValue([string[]]$argv) {
    $r = Git $argv
    Require ($r.code -eq 0) "git $($argv[0]) failed: $($r.text)"
    return $r.text
}
function ExactSha([string]$value) { Require ($value -cmatch '^[0-9a-f]{40}$') 'Expected a full lowercase SHA-1.' }
function CanonicalPath([string]$value) { return (([IO.Path]::GetFullPath($value)) -replace '\\','/').TrimEnd('/') }
function Field($obj, [string]$name) {
    $p = $obj.PSObject.Properties[$name]
    Require ($null -ne $p -and -not [string]::IsNullOrWhiteSpace([string]$p.Value)) "Missing $name."
    return [string]$p.Value
}
function BoolField($obj, [string]$name) {
    $p = $obj.PSObject.Properties[$name]
    Require ($null -ne $p -and $p.Value -is [bool]) "Missing or invalid Boolean $name."
    return [bool]$p.Value
}
function CountField($obj, [string]$name) {
    $value=Field $obj $name
    Require ($value -cmatch '^(0|[1-9][0-9]*)$') "Invalid count $name."
    return [int]$value
}
function Items($obj, [string]$name) {
    $p=$obj.PSObject.Properties[$name]
    Require ($null -ne $p) "Missing $name."
    return @($p.Value)
}
function NonEmptyUnique($obj, [string]$name) {
    $values=Items $obj $name
    Require ($values.Count -gt 0) "$name must not be empty."
    foreach($value in $values) { Require (-not [string]::IsNullOrWhiteSpace([string]$value)) "Blank $name item." }
    Require (@($values | Select-Object -Unique).Count -eq $values.Count) "Duplicate $name item."
    return ,$values
}
function GovernanceCheck($p) {
    $classification=$p.classification
    $change=Field $classification 'changeClass'; Require ($change -in @('C0','C1','C2','C3','C4')) 'Invalid change class.'
    $risk=Field $classification 'risk'; Require ($risk -in @('R0','R1','R2','R3','R4')) 'Invalid risk.'
    $governanceProfile=Field $classification 'governanceProfile'; Require ($governanceProfile -in @('P0','P1','P2','P3')) 'Invalid governance profile.'
    $profile=Field $classification 'profile'; Require ($profile -in @('QUICK','STANDARD','STRICT','CRITICAL')) 'Invalid profile.'
    $strength=@{QUICK=0;STANDARD=1;STRICT=2;CRITICAL=3}
    $minimum=@{P0='QUICK';P1='STANDARD';P2='STRICT';P3='CRITICAL'}[$governanceProfile]
    if (($change -in @('C2','C3') -or $risk -eq 'R3' -or (BoolField $classification 'humanAuthorityRisk') -or (BoolField $classification 'evidenceIntegrityRisk') -or (BoolField $classification 'recoveryRisk')) -and $strength[$minimum] -lt 2) { $minimum='STRICT' }
    elseif (($change -eq 'C1' -or $risk -eq 'R2') -and $strength[$minimum] -lt 1) { $minimum='STANDARD' }
    if ($change -in @('C3','C4') -or $risk -eq 'R4' -or (BoolField $classification 'criticalControlFailure')) { $minimum='CRITICAL' }
    if (BoolField $classification 'ambiguous') { $minimum=@{QUICK='STANDARD';STANDARD='STRICT';STRICT='CRITICAL';CRITICAL='CRITICAL'}[$minimum] }
    Require ($strength[$profile] -ge $strength[$minimum]) "Profile below required minimum $minimum."
    Require (-not (BoolField $classification 'automaticDowngrade')) 'Automatic Profile downgrade refused.'
    $upgrade=[bool](BoolField $classification 'materialRiskUpgrade')
    if ($upgrade) { Require (BoolField $classification 'stopForGate') 'Material risk upgrade must stop for Gate.'; Require (-not (BoolField $classification 'expandedAuthorization')) 'Material risk cannot expand authorization before Gate.' }

    $baseline=$p.baseline
    Require (BoolField $baseline 'frozen') 'G3 baseline must be frozen.'
    $risks=NonEmptyUnique $baseline 'risks'; $tests=NonEmptyUnique $baseline 'requiredTests'
    [void](NonEmptyUnique $baseline 'requiredEvidence'); [void](NonEmptyUnique $baseline 'stopConditions')
    $declared=Items $baseline 'declaredTests'
    Require ($tests.Count -eq 8 -and @('V1','V2','V3','V4','V5','V6','V7','V8' | Where-Object { $tests -cnotcontains $_ }).Count -eq 0) 'Required tests must be exactly V1-V8.'
    Require ($declared.Count -eq $tests.Count -and @($declared | Where-Object { $tests -cnotcontains $_ }).Count -eq 0) 'Unapproved required test or missing frozen test.'
    Require (-not (BoolField $baseline 'addedRole') -and -not (BoolField $baseline 'addedCase')) 'Unapproved case or role refused.'
    $budgets=$baseline.budgets
    $fixed=[ordered]@{implementationWorkers=1;reviewerSessions=1;implementationWorktrees=1;mechanicalWorkers=0;reviewRounds=1;reworkRounds=1;dispatchRecords=4;newBranches=1;defaultTotalWorktrees=3;maximumTotalWorktrees=4}
    foreach($key in $fixed.Keys) { Require ((CountField $budgets $key) -eq $fixed[$key]) "Frozen budget mismatch: $key." }

    $verification=$p.verification
    $minimums=@{QUICK=@('risk-check','trusted-smoke');STANDARD=@('risk-check','trusted-smoke','affected-integration');STRICT=@('risk-check','trusted-smoke','affected-integration','coverage','independent-review');CRITICAL=@('risk-check','trusted-smoke','affected-integration','coverage','independent-review','independent-gate-audit','failure-recovery')}
    $kinds=Items $verification 'kinds'
    foreach($kind in $minimums[$profile]) { Require ($kinds -ccontains $kind) "Missing $profile verification: $kind." }
    $riskChecks=Items $verification 'riskChecks'
    foreach($declaredRisk in $risks) { Require (@($riskChecks | Where-Object { (Field $_ 'risk') -ceq [string]$declaredRisk -and (Field $_ 'test') -in $tests }).Count -gt 0) "Risk lacks a frozen verification case: $declaredRisk." }
    $smoke=$verification.trustedSmoke
    Require ((BoolField $smoke 'cleanFixture') -and (BoolField $smoke 'repeatable') -and (CountField $smoke 'exitCode') -eq 0 -and (BoolField $smoke 'expectedAssertion') -and -not (BoolField $smoke 'skippedRequiredAssertion') -and (BoolField $smoke 'retainedInput') -and (BoolField $smoke 'retainedOutput') -and (BoolField $smoke 'retainedStatus')) 'Trusted smoke contract not satisfied.'
    foreach($k in @('fixtureId','command','expectedOutput','retainedEvidenceId')) { [void](Field $smoke $k) }

    $failure=$p.failure
    $failureClass=Field $failure 'classification'; Require ($failureClass -in @('product','fixture','harness','environment','evidence-control')) 'Invalid failure classification.'
    Require (-not (BoolField $failure 'uncertain')) 'Failure classification uncertainty requires stop.'
    if ($failureClass -in @('fixture','harness')) { Require (-not (BoolField $failure 'productFailure') -and -not (BoolField $failure 'expandTests') -and -not (BoolField $failure 'trustedPathReproduced')) 'Fixture/harness failure cannot become product failure or expand scope.' }

    $coverage=Items $p 'coverage'
    Require ($coverage.Count -ge $tests.Count) 'Coverage matrix must cover every frozen test.'
    $coverageRequirements=@($coverage | ForEach-Object { [string](Field $_ 'requirement') })
    Require (@($coverageRequirements | Select-Object -Unique).Count -eq $coverageRequirements.Count) 'Coverage requirements must be unique.'
    foreach($row in $coverage) { [void](Field $row 'requirement'); [void](Field $row 'implementation'); [void](Field $row 'evidence'); Require ((BoolField $row 'reachable') -and (Field $row 'verdict') -ceq 'PASS') 'Missing or unreachable implementation is REVIEW_FAIL.' }

    $runtime=$p.runtime
    Require ((CountField $runtime 'implementationWorkers') -le 1 -and (CountField $runtime 'reviewerSessions') -le 2 -and (CountField $runtime 'implementationWorktrees') -le 1 -and (CountField $runtime 'mechanicalWorkers') -eq 0 -and (CountField $runtime 'dispatchRecords') -le 4 -and (CountField $runtime 'reviewRounds') -le 2 -and (CountField $runtime 'reworkRounds') -le 1 -and (CountField $runtime 'newBranches') -le 1) 'LEAN-02 resource budget exceeded.'
    Require ((CountField $runtime 'reviewFailures') -le 1) 'Second review failure stops the Batch.'
    $reason=Field $runtime 'reReviewReason'; Require ($reason -in @('NONE','REVIEW_FAIL','APPROVED_MATERIAL_REWORK')) 'Re-review lacks an allowed trigger.'
    if ((CountField $runtime 'reviewRounds') -gt 1) {
        Require ($reason -cne 'NONE' -and (CountField $runtime 'reviewerSessions') -eq 2 -and (CountField $runtime 'reviewFailures') -eq 1 -and (CountField $runtime 'reworkRounds') -eq 1) 'Re-review requires one actual failure, bounded rework, and a fresh Session.'
        [void](Field $runtime 'freshReviewerSessionId'); Require (BoolField $runtime 'reviewIndependenceEvidence') 'Fresh re-review independence evidence required.'
    }
    $total=CountField $runtime 'totalWorktrees'; $isolation=BoolField $runtime 'isolationEvidence'; $fallback=BoolField $runtime 'reviewWorktreeFallback'
    Require ($total -ge 3 -and $total -le 4) 'Default topology requires three Worktrees.'
    if ($profile -in @('STRICT','CRITICAL') -and -not $isolation) { Require ($fallback -and $total -eq 4) 'Fourth Review Worktree required when isolation evidence is absent.' }
    else { Require (-not $fallback -and $total -le 3) 'Fourth Review Worktree is conditional, not default.' }
    Require (BoolField $runtime 'reviewIndependent') 'Review independence cannot be weakened.'
    Require (-not (BoolField $runtime 'optionalHardeningInBatch')) 'Optional hardening remains outside the Batch.'
    Require (-not (BoolField $runtime 'derivedStatusUpdate')) 'Derived status updates are deferred until authorized integration.'
    Require (-not (BoolField $runtime 'lowerHumanGate') -and -not (BoolField $runtime 'lowerIndependentReview') -and -not (BoolField $runtime 'lowerEvidence')) 'Mandatory controls cannot be lowered.'
    return [ordered]@{classification="$change/$risk/$governanceProfile/$profile";minimumProfile=$minimum;risks=$risks;tests=$tests;coverageRows=$coverage.Count;budgets=$fixed;stop='PASS'}
}
function Clean([string]$path) {
    $r = Native 'git' @('status','--porcelain=v1','--untracked-files=all') $path
    Require ($r.code -eq 0 -and -not $r.text) "Dirty or unknown checkout: $path"
}
function Orca([string[]]$argv) {
    $r = Native 'orca' ($argv + @('--json')) $script:repo
    Require ($r.code -eq 0) "Orca failed: $($r.text)"
    $j = $r.text | ConvertFrom-Json
    Require ($j.ok -eq $true) "Orca refused: $($r.text)"
    return $j
}
function Snapshot {
    $head = GitValue @('rev-parse','HEAD')
    $status = GitValue @('status','--porcelain=v1','--untracked-files=all')
    $worktrees = GitValue @('worktree','list','--porcelain')
    return [ordered]@{ head=$head; status=$status; worktrees=$worktrees }
}
function Evidence($p) {
    $items=@($p.evidence)
    Require ($items.Count -gt 0) 'Retained evidence is required.'
    $checked=@()
    foreach ($item in $items) {
        $commit=Field $item 'commit'; ExactSha $commit
        $path=Field $item 'path'
        Require ($path -cmatch '^[A-Za-z0-9_./-]+$' -and -not $path.Contains('..')) 'Unsafe evidence path.'
        $blob=Field $item 'blob'; ExactSha $blob
        Require ((Git @('merge-base','--is-ancestor',$commit,$script:mainSha)).code -eq 0) 'Evidence commit is not retained on main.'
        Require ((GitValue @('rev-parse',"${commit}:$path")) -ceq $blob) 'Evidence blob drift.'
        $checked+=@{commit=$commit;path=$path;blob=$blob}
    }
    return ,$checked
}
function ExactWorktree($p) {
    $id=Field $p 'worktreeId'; Require ($id -cne 'active' -and $id.Contains('::')) 'Explicit worktree ID required.'
    $path=Field $p 'worktreePath'
    $w=(Orca @('worktree','show','--worktree',"id:$id")).result.worktree
    Require ($null -ne $w -and $w.id -ceq $id -and $w.path -ceq $path -and $w.git.path -ceq $path) 'Orca worktree identity drift.'
    Require ($w.workspaceStatus -ceq 'completed' -and @($w.childWorktreeIds).Count -eq 0) 'Worktree incomplete or has children.'
    Require ($w.head -ceq (Field $p 'head') -and $w.git.head -ceq $w.head) 'Orca HEAD drift.'
    return $w
}
function NoTerminals([string]$id) {
    $list=(Orca @('terminal','list','--worktree',"id:$id")).result
    Require ($null -ne $list -and $null -ne $list.terminals -and $list.truncated -eq $false -and @($list.hostScope.omittedHostIds).Count -eq 0 -and $list.totalCount -eq 0 -and @($list.terminals).Count -eq 0) 'Live or unknown dependent terminal.'
}
function WriteBlob([string]$blob, [string]$path) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'; $psi.Arguments = "cat-file blob $blob"
    $psi.WorkingDirectory = $script:repo; $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $dest = Join-Path $script:repo $path
    $parent = Split-Path -Parent $dest
    Require (Test-Path -LiteralPath $parent -PathType Container) 'Target parent absent.'
    $stream = [IO.File]::Create($dest)
    try { $proc.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose(); $proc.WaitForExit() }
    Require ($proc.ExitCode -eq 0) 'Blob copy failed.'
}

$script:repo=$null
$result = [ordered]@{ ok=$false; action=$null; package=$Package; before=$null; after=$null; changed=$false; error=$null }
try {
    $p = Get-Content -LiteralPath $Package -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:repo = (Resolve-Path -LiteralPath (Field $p 'repo')).Path
    Require ((GitValue @('rev-parse','--show-toplevel')) -eq ($script:repo -replace '\\','/')) 'Package repo is not Git root.'
    $action = Field $p 'action'; $result.action = $action
    Require ($action -in @('governance-check','promote','integrate','status','terminal-close','worktree-remove','branch-delete','remote-check','close')) 'Unknown action.'
    $gate = Field $p 'gate'
    Require ($gate -in @('G3','G4','G5')) 'Invalid gate.'
    $main = Field $p 'mainRef'
    Require ($main -eq 'refs/heads/main') 'Only local main is an authority ref.'
    $mainSha = GitValue @('rev-parse','--verify',$main)
    $script:mainSha=$mainSha
    $target = Field $p 'target'
    $result.before = Snapshot
    switch ($action) {
        'governance-check' {
            Require ($gate -eq 'G3') 'Governance baseline check requires G3.'
            Require ($target -ceq (Field $p 'batch')) 'Batch target mismatch.'
            $result.governance=GovernanceCheck $p
        }
        'promote' {
            Require ($gate -in @('G3','G4')) 'Promotion requires G3/G4.'
            $path = Field $p 'path'; Require ($path -cmatch '^[A-Za-z0-9_./-]+$' -and -not $path.Contains('..')) 'Unsafe target path.'
            $blob = Field $p 'blob'; ExactSha $blob
            Require ($target -ceq "$path@$blob") 'Promotion target mismatch.'
            Require ((GitValue @('cat-file','-t',$blob)) -eq 'blob') 'Source is not a blob.'
            $expected = Field $p 'expectedBlob'; ExactSha $expected
            $actual = GitValue @('rev-parse',"HEAD:$path")
            Require ($actual -ceq $expected -or $actual -ceq $blob) 'Target blob drift.'
            $working = GitValue @('hash-object','--',$path)
            if ($working -cne $blob) {
                Clean $script:repo
                WriteBlob $blob $path
                $result.changed = $true
            }
            Require ((GitValue @('hash-object','--',$path)) -ceq $blob) 'Promotion postcondition failed.'
        }
        'integrate' {
            Require ($gate -eq 'G5') 'Integration requires G5.'
            $sha = Field $p 'reviewedSha'; ExactSha $sha
            Require ($target -ceq $sha) 'Reviewed SHA target mismatch.'
            Require ((GitValue @('rev-parse','HEAD')) -ceq (Field $p 'expectedHead')) 'Main HEAD drift.'
            Require ((GitValue @('symbolic-ref','HEAD')) -ceq $main) 'Checkout is not main.'
            Clean $script:repo
            Require ((Git @('merge-base','--is-ancestor','HEAD',$sha)).code -eq 0) 'Non-fast-forward integration.'
            # A caller's PASS string is not independent Review evidence.
            # Lead reconciles the actual frozen-SHA review before invocation.
            if ((GitValue @('rev-parse','HEAD')) -cne $sha) {
                $r = Git @('merge','--ff-only',$sha); Require ($r.code -eq 0) "Fast-forward failed: $($r.text)"; $result.changed=$true
            }
            Require ((GitValue @('rev-parse','HEAD')) -ceq $sha) 'Integration postcondition failed.'
        }
        'status' {
            Require ($gate -eq 'G5') 'Status sync requires G5.'
            $path='PROJECT_STATUS.md'; $blob=Field $p 'blob'; ExactSha $blob
            Require ($target -ceq "$path@$blob") 'Status target mismatch.'
            Require ((GitValue @('cat-file','-t',$blob)) -eq 'blob') 'Status source absent.'
            $actual=GitValue @('rev-parse',"HEAD:$path")
            Require ($actual -ceq (Field $p 'expectedBlob') -or $actual -ceq $blob) 'Status base drift.'
            $working=GitValue @('hash-object','--',$path)
            if ($working -cne $blob) {
                Clean $script:repo
                WriteBlob $blob $path
                $result.changed=$true
            }
            Require ((GitValue @('hash-object','--',$path)) -ceq $blob) 'Status postcondition failed.'
        }
        'terminal-close' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $handle=Field $p 'handle'; Require ($target -ceq $handle) 'Handle mismatch.'
            $w=ExactWorktree $p
            Clean $w.path
            $t=(Orca @('terminal','show','--terminal',$handle)).result.terminal
            Require ($null -ne $t -and $t.handle -ceq $handle -and $t.worktreeId -ceq $w.id -and $t.worktreePath -ceq $w.path -and $t.branch -ceq $w.branch) 'Terminal ownership drift.'
            Require ($t.incarnationId -ceq (Field $p 'incarnationId') -and $t.ptyId -ceq (Field $p 'ptyId')) 'Terminal incarnation drift.'
            Require ($t.connected -eq $false -and $t.writable -eq $false -and $t.orphaned -eq $false) 'Terminal process is live or unknown.'
            $result.evidence=Evidence $p
            $result.targetBefore=$t
            Orca @('terminal','close','--terminal',$handle) | Out-Null; $result.changed=$true
            $list=(Orca @('terminal','list','--worktree',"id:$($w.id)")).result
            Require ($list.truncated -eq $false -and @($list.hostScope.omittedHostIds).Count -eq 0 -and @($list.terminals | Where-Object { $_.handle -ceq $handle }).Count -eq 0) 'Terminal remains listed or listing incomplete.'
            $result.targetAfter=@{handle=$handle;listed=$false}
        }
        'worktree-remove' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $id=Field $p 'worktreeId'; Require ($target -ceq $id -and $id -ne 'active') 'Worktree mismatch.'
            $path=Field $p 'worktreePath'
            Require ([IO.Path]::GetFullPath($path) -ne [IO.Path]::GetFullPath($script:repo)) 'Cannot remove main.'
            $w=ExactWorktree $p
            Require ($w.isMainWorktree -eq $false -and (Test-Path -LiteralPath $path -PathType Container)) 'Worktree absent or main.'
            Clean $path
            $sha=Field $p 'head'; ExactSha $sha
            Require ((Native 'git' @('rev-parse','HEAD') $path).text -ceq $sha) 'Worktree HEAD drift.'
            Require ((Git @('merge-base','--is-ancestor',$sha,$mainSha)).code -eq 0) 'Unique commit must be retained.'
            NoTerminals $id
            $branch=Field $p 'branch'; Require ($branch -cmatch '^refs/heads/[A-Za-z0-9_./-]+$') 'Unsafe branch.'
            Require ($w.branch -ceq $branch -and $w.git.branch -ceq $branch) 'Worktree branch drift.'
            Require ((GitValue @('rev-parse','--verify',$branch)) -ceq $sha) 'Branch ref drift.'
            $result.evidence=Evidence $p
            $result.targetBefore=@{worktree=$w;branch=$branch;ref=$sha}
            Orca @('worktree','rm','--worktree',"id:$id") | Out-Null; $result.changed=$true
            Require (-not (Test-Path -LiteralPath $path)) 'Worktree still present.'
            Require (-not (GitValue @('worktree','list','--porcelain')).Contains("worktree $path")) 'Git worktree still listed.'
            $ref=Git @('show-ref','--verify','--hash',$branch)
            Require ($ref.code -ne 0 -or $ref.text -ceq $sha) 'Branch ref changed during removal.'
            $result.branchDisposition=if ($ref.code -eq 0) { "retained:$($ref.text)" } else { 'removed' }
            $result.targetAfter=@{worktreePresent=$false;branchDisposition=$result.branchDisposition}
        }
        'branch-delete' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $branch=Field $p 'branch'; Require ($branch -cmatch '^refs/heads/[A-Za-z0-9_./-]+$' -and $branch -ne $main) 'Unsafe branch.'
            Require ($target -ceq $branch) 'Branch mismatch.'
            $sha=Field $p 'head'; ExactSha $sha
            Clean $script:repo
            $r=Git @('show-ref','--verify','--hash',$branch)
            Require ($r.code -eq 0) 'Branch absent; reconcile before retry.'
            if ($r.code -eq 0) {
                Require ($r.text -ceq $sha) 'Branch ref drift.'
                Require ((Git @('merge-base','--is-ancestor',$sha,$mainSha)).code -eq 0) 'Unique commit must be retained.'
                $result.evidence=Evidence $p
                $used=GitValue @('worktree','list','--porcelain')
                Require (-not (($used -split "`n") -ccontains "branch $branch")) 'Branch checked out.'
                $result.targetBefore=@{branch=$branch;ref=$sha;worktrees=$used}
                $r=Git @('branch','-d',($branch -replace '^refs/heads/',''))
                Require ($r.code -eq 0) "Branch delete refused: $($r.text)"; $result.changed=$true
            }
            Require ((Git @('show-ref','--verify',$branch)).code -ne 0) 'Branch still present.'
            $result.targetAfter=@{branch=$branch;present=$false}
        }
        'remote-check' {
            $remote=Field $p 'remote'; $ref=Field $p 'remoteRef'; $sha=Field $p 'expectedSha'; ExactSha $sha
            Require ($target -ceq "$remote/$ref@$sha") 'Remote target mismatch.'
            Require ($ref -cmatch '^refs/heads/[A-Za-z0-9_./-]+$') 'Unsafe remote ref.'
            $r=Git @('ls-remote','--exit-code',$remote,$ref)
            Require ($r.code -eq 0) "Remote ref unavailable: $($r.text)"
            $actual=($r.text -split '\s+')[0]
            $result.remote=[ordered]@{ expected=$sha; actual=$actual; match=($sha -ceq $actual) }
            Require ($sha -ceq $actual) 'Remote SHA mismatch.'
        }
        'close' {
            Require ($gate -eq 'G5') 'Closure requires G5.'
            Require ($target -ceq (Field $p 'batch')) 'Batch target mismatch.'
            Require ((Field $p 'reviewVerdict') -ceq 'GREEN') 'GREEN review required.'
            $result.evidence=Evidence $p
            $metrics=$p.metrics
            foreach($key in @('peakWorkers','peakWorktrees','newBranches','mechanicalWorkers','verificationCases','manualCoordination','elapsedSeconds','provenance','bootstrapComparison')) { [void](Field $metrics $key) }
            foreach($key in @('peakWorkers','peakWorktrees','newBranches','mechanicalWorkers','verificationCases','manualCoordination','elapsedSeconds')) { Require ((Field $metrics $key) -cmatch '^(0|[1-9][0-9]*)$') "Invalid metric $key." }
            $objects=@($p.objects)
            Require ($null -ne $p.objects) 'Reconciled objects field required.'
            # A current inventory can prove retained objects. Removed objects have no
            # current identity to verify, so this tool cannot certify their history.
            $gitTrees=GitValue @('worktree','list','--porcelain')
            $gitBranches=GitValue @('for-each-ref','--format=%(refname)','refs/heads')
            $allTrees=(Orca @('worktree','list')).result
            Require ($allTrees.truncated -eq $false -and $null -ne $allTrees.worktrees -and @($allTrees.hostScope.omittedHostIds).Count -eq 0) 'Complete Orca Worktree inventory unavailable.'
            $mainTrees=@($allTrees.worktrees | Where-Object { $_.isMainWorktree -eq $true -and (CanonicalPath $_.path) -ceq (CanonicalPath $script:repo) })
            Require ($mainTrees.Count -eq 1) 'Repository Orca identity unavailable.'
            $repoId=$mainTrees[0].repoId
            $tracked=@($allTrees.worktrees | Where-Object { $_.repoId -ceq $repoId })
            $actual=@()
            foreach($w in $tracked) {
                Require ($w.id -ceq "${repoId}::$($w.path)" -and (CanonicalPath $w.git.path) -ceq (CanonicalPath $w.path) -and $w.git.branch -ceq $w.branch) 'Orca Worktree inventory drift.'
                Require (($gitTrees -split "`n") -ccontains "worktree $($w.path)") 'Git/Orca Worktree inventory mismatch.'
                if (-not $w.isMainWorktree -and $w.branch -cne 'refs/heads/gad-lead') {
                    $actual+= "worktree|$($w.path)"
                    $terms=(Orca @('terminal','list','--worktree',"id:$($w.id)")).result
                    Require ($terms.truncated -eq $false -and $null -ne $terms.terminals -and @($terms.hostScope.omittedHostIds).Count -eq 0 -and $terms.totalCount -eq @($terms.terminals).Count) 'Complete Orca Terminal inventory unavailable.'
                    foreach($t in $terms.terminals) {
                        Require ($t.worktreeId -ceq $w.id -and $t.worktreePath -ceq $w.path -and $t.branch -ceq $w.branch) 'Orca Terminal inventory drift.'
                        $actual+= "terminal|$($t.handle)"
                    }
                }
            }
            foreach($line in ($gitTrees -split "`n")) {
                if ($line -like 'worktree *') {
                    $path=$line.Substring(9)
                    Require (@($tracked | Where-Object { (CanonicalPath $_.path) -ceq (CanonicalPath $path) }).Count -eq 1) 'Untracked Git Worktree in repository inventory.'
                }
            }
            foreach($branch in ($gitBranches -split "`n")) {
                if ($branch -and $branch -cne $main -and $branch -cne 'refs/heads/gad-lead') { $actual+= "branch|$branch" }
            }
            Require ($actual.Count -eq @($actual | Select-Object -Unique).Count) 'Duplicate current inventory entry.'
            $supplied=@()
            foreach($o in $objects) {
                $kind=Field $o 'kind'; $name=Field $o 'name'; $disposition=Field $o 'disposition'
                Require ($disposition -ceq 'retained' -or $disposition -ceq 'removed') 'Unknown object disposition.'
                Require ($disposition -ceq 'retained') 'Removed closure object cannot be verified from current inventory.'
                if ($kind -ceq 'branch') { Require ($name -cmatch '^refs/heads/[A-Za-z0-9_./-]+$') 'Unsafe closure branch.'; $exists=(Git @('show-ref','--verify',$name)).code -eq 0 }
                elseif ($kind -ceq 'worktree') { $list=GitValue @('worktree','list','--porcelain'); $exists=($list -split "`n") -ccontains "worktree $name" }
                elseif ($kind -ceq 'terminal') { $exists=($actual -ccontains "terminal|$name") }
                else { throw 'Unknown closure object kind.' }
                Require ($exists -eq ($disposition -ceq 'retained')) 'Closure object drift.'
                $supplied+= "$kind|$name"
            }
            Require ($supplied.Count -eq @($supplied | Select-Object -Unique).Count -and $supplied.Count -eq $actual.Count -and @($actual | Where-Object { $supplied -cnotcontains $_ }).Count -eq 0) 'Closure disposition omits or adds repository objects.'
            $result.metrics=$metrics
            $result.objects=$objects
            $result.targetBefore=@{batch=$target;objects=$objects;reviewVerdict='GREEN'}
            $result.targetAfter=$result.targetBefore
            # Closure is a checked result; a governed status writer records CLOSED.
        }
    }
    $result.after=Snapshot; $result.ok=$true
} catch { $result.error=$_.Exception.Message; if ($script:repo) { try { $result.after=Snapshot } catch {} } }
$result | ConvertTo-Json -Depth 30 -Compress
if (-not $result.ok) { exit 2 }
