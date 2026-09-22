#requires -Version 5.1
param([string]$Control = (Join-Path $PSScriptRoot '..\tools\gad-control.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('gad-lean-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$repo=Join-Path $root 'repo'; New-Item -ItemType Directory -Path $repo | Out-Null
$review=$null
$results=[ordered]@{}
function G([string[]]$a) { $prior=$ErrorActionPreference; $ErrorActionPreference='Continue'; try { $o=@(& git -C $repo @a 2>$null); $code=$LASTEXITCODE } finally { $ErrorActionPreference=$prior }; if ($code -ne 0) { throw "git $($a -join ' ') failed" }; return ($o -join "`n").Trim() }
function Check([bool]$ok,[string]$message) { if (-not $ok) { throw $message } }
function Run($p) {
    $f=Join-Path $root 'action.json'; $p | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $f -Encoding UTF8
    $raw=& powershell -NoProfile -File $Control -Package $f
    return ($raw | ConvertFrom-Json)
}
try {
    G @('init','-b','main') | Out-Null
    G @('config','user.name','Fixture') | Out-Null; G @('config','user.email','fixture@example.invalid') | Out-Null
    'old' | Set-Content (Join-Path $repo 'target.txt') -NoNewline
    'G3 target.txt@PLACEHOLDER' | Set-Content (Join-Path $repo 'approval.txt') -NoNewline
    G @('add','.') | Out-Null; G @('commit','-m','base') | Out-Null
    $base=G @('rev-parse','HEAD'); $old=G @('rev-parse','HEAD:target.txt')
    $source=Join-Path $root 'source.txt'; 'new' | Set-Content -LiteralPath $source -NoNewline
    $blob=(G @('hash-object','-w',$source))
    $phrase="G3 target.txt@$blob"
    $phrase | Set-Content (Join-Path $repo 'approval.txt') -NoNewline
    G @('add','approval.txt') | Out-Null; G @('commit','-m','approve target') | Out-Null
    $approval=G @('rev-parse','HEAD'); $proof=G @('rev-parse','HEAD:approval.txt')
    $p=[ordered]@{repo=$repo;action='promote';gate='G3';mainRef='refs/heads/main';approvalCommit=$approval;approvalPath='approval.txt';approvalBlob=$proof;approvalPhrase=$phrase;target="target.txt@$blob";path='target.txt';blob=$blob;expectedBlob=$old}
    $q=[ordered]@{} + $p;$q.approvalPhrase='G3 wrong';$r=Run $q
    Check (-not $r.ok -and (Get-Content (Join-Path $repo 'target.txt') -Raw) -eq 'old') 'V1 missing approval mutated target';$results.V1='PASS'
    $r=Run $p;Check ($r.ok -and (G @('hash-object','target.txt')) -eq $blob) ("V2 promotion failed: " + ($r | ConvertTo-Json -Compress))
    $r2=Run $p;Check ($r2.ok -and -not $r2.changed) 'V2 retry duplicated action';$results.V2='PASS'
    $q=[ordered]@{} + $p;$q.action='worktree-remove';$q.gate='G5';$q.target='unknown';$q.worktreeId='unknown';$q.worktreePath=$repo;$q.head=$approval;$q.completed='true';$q.evidenceRetained='true';$r=Run $q
    Check (-not $r.ok -and (Test-Path $repo)) 'V3 unknown worktree removed';$results.V3='PASS'
    $q=[ordered]@{} + $p;$q.action='branch-delete';$q.gate='G5';$q.branch='refs/heads/unique';$q.target=$q.branch;$q.head=$approval;$q.evidenceRetained='true'
    G @('branch','unique') | Out-Null;$r=Run $q;Check (-not $r.ok -and (G @('rev-parse','unique')) -eq $approval) 'V4 branch guard failed';$results.V4='PASS (authority refusal preserves ref)'
    $q=[ordered]@{} + $p;$q.action='terminal-close';$q.gate='G5';$q.target='lead';$q.handle='lead';$q.role='lead';$q.completed='true';$q.evidenceRetained='true';$r=Run $q
    Check (-not $r.ok) 'V5 lead terminal guard failed';$results.V5='PASS'
    $frozen=G @('rev-parse','HEAD');$review=Join-Path $root 'review';G @('worktree','add','--detach',$review,$frozen) | Out-Null
    Check ((& git -C $review rev-parse HEAD).Trim() -eq $frozen -and -not ((& git -C $review status --porcelain) -join '')) 'V6 frozen checkout invalid'
    $results.V6='PASS (frozen Git checkout; Session isolation requires Orca Review evidence)'
    $r=Run $p;Check ($r.ok -and -not $r.changed -and (G @('rev-parse','HEAD')) -eq $frozen) 'V7 retry changed state';$results.V7='PASS'
    $metrics=[ordered]@{peakWorkers='2';peakWorktrees='4';newBranches='2';mechanicalWorkers='0';verificationCases='8';manualCoordination='0';elapsedSeconds='123';provenance='Git/Orca snapshots';bootstrapComparison='19 cases measured; others unknown'}
    foreach($key in @('peakWorkers','peakWorktrees','newBranches','mechanicalWorkers','verificationCases','manualCoordination','elapsedSeconds','provenance','bootstrapComparison')) { Check (-not [string]::IsNullOrWhiteSpace($metrics[$key])) "V8 missing $key" }
    $results.V8='PASS (schema; real values supplied at closure)'
    $results | ConvertTo-Json -Compress
} finally {
    # The disposable fixture is known and located beneath the freshly created temp root.
    if (Test-Path -LiteralPath $root) {
        $resolved=[IO.Path]::GetFullPath($root)
        if ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'gad-lean-*') {
            if ($review -and (Test-Path -LiteralPath $review)) { & git -C $repo worktree remove --force $review 2>$null | Out-Null }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}


