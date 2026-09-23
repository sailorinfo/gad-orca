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
    $q=[ordered]@{} + $p;$q.target='wrong';$r=Run $q
    Check (-not $r.ok -and (Get-Content (Join-Path $repo 'target.txt') -Raw) -eq 'old') 'V1 wrong target mutated bytes';$results.V1='PASS (wrong target; bytes unchanged)'
    $q=[ordered]@{} + $p;$q.blob=$old;$r=Run $q
    Check (-not $r.ok -and (G @('rev-parse','HEAD')) -eq $approval) 'V2 wrong blob was accepted'
    $r=Run $p;Check ($r.ok -and (G @('hash-object','target.txt')) -eq $blob) ("V2 promotion failed: " + ($r | ConvertTo-Json -Compress))
    $r2=Run $p;Check ($r2.ok -and -not $r2.changed) 'V2 promotion retry duplicated action'
    G @('add','target.txt') | Out-Null;G @('commit','-m','promoted target') | Out-Null
    $ffBase=G @('rev-parse','HEAD')
    G @('switch','-c','reviewed') | Out-Null
    'reviewed' | Set-Content (Join-Path $repo 'review.txt') -NoNewline
    G @('add','review.txt') | Out-Null;G @('commit','-m','reviewed change') | Out-Null
    $reviewed=G @('rev-parse','HEAD')
    G @('switch','main') | Out-Null
    G @('switch','-c','gate-ff') | Out-Null
    "G5 $reviewed" | Set-Content (Join-Path $repo 'approval.txt') -NoNewline
    G @('add','approval.txt') | Out-Null;G @('commit','-m','fixture gate package') | Out-Null
    $gateCommit=G @('rev-parse','HEAD');$gateBlob=G @('rev-parse','HEAD:approval.txt')
    G @('switch','main') | Out-Null
    $ip=[ordered]@{} + $p;$ip.action='integrate';$ip.gate='G5';$ip.target=$reviewed;$ip.approvalCommit=$gateCommit;$ip.approvalBlob=$gateBlob;$ip.approvalPhrase="G5 $reviewed";$ip.reviewedSha=$reviewed;$ip.expectedHead=$ffBase;$ip.reviewEvidenceSha=$reviewed;$ip.verification='PASS'
    $r=Run $ip;Check ($r.ok -and $r.changed -and (G @('rev-parse','HEAD')) -eq $reviewed) 'V2 exact fast-forward failed'
    G @('switch','-c','diverged',$ffBase) | Out-Null
    'diverged' | Set-Content (Join-Path $repo 'diverged.txt') -NoNewline
    G @('add','diverged.txt') | Out-Null;G @('commit','-m','diverged change') | Out-Null
    $diverged=G @('rev-parse','HEAD')
    G @('switch','main') | Out-Null
    G @('switch','-c','gate-diverged') | Out-Null
    "G5 $diverged" | Set-Content (Join-Path $repo 'approval.txt') -NoNewline
    G @('add','approval.txt') | Out-Null;G @('commit','-m','fixture diverged package') | Out-Null
    $ip.target=$diverged;$ip.reviewedSha=$diverged;$ip.reviewEvidenceSha=$diverged;$ip.approvalCommit=G @('rev-parse','HEAD');$ip.approvalBlob=G @('rev-parse','HEAD:approval.txt');$ip.approvalPhrase="G5 $diverged";$ip.expectedHead=$reviewed
    G @('switch','main') | Out-Null
    $r=Run $ip;Check (-not $r.ok -and $r.error -match 'Non-fast-forward' -and (G @('rev-parse','HEAD')) -eq $reviewed) 'V2 non-fast-forward was accepted or moved HEAD'
    $results.V2='PASS (wrong blob refused; promotion and exact fast-forward succeeded; divergent target refused)'
    'G5 unknown refs/heads/unique lead' | Set-Content (Join-Path $repo 'approval.txt') -NoNewline
    G @('add','approval.txt') | Out-Null;G @('commit','-m','fixture cleanup package') | Out-Null
    $cleanupApproval=G @('rev-parse','HEAD');$cleanupBlob=G @('rev-parse','HEAD:approval.txt')
    $q=[ordered]@{} + $p;$q.action='worktree-remove';$q.gate='G5';$q.target='unknown';$q.worktreeId='unknown';$q.worktreePath=$repo;$q.head=$approval;$q.completed='true';$q.evidenceRetained='true';$q.approvalCommit=$cleanupApproval;$q.approvalBlob=$cleanupBlob;$q.approvalPhrase='G5 unknown';$r=Run $q
    Check (-not $r.ok -and $r.error -match 'Cannot remove main' -and (Test-Path $repo)) 'V3 main worktree guard failed';$results.V3='PASS (main Worktree removal refused; live Orca removal deferred)'
    $q=[ordered]@{} + $p;$q.action='branch-delete';$q.gate='G5';$q.branch='refs/heads/unique';$q.target=$q.branch;$q.head=$approval;$q.evidenceRetained='true';$q.approvalCommit=$cleanupApproval;$q.approvalBlob=$cleanupBlob;$q.approvalPhrase='G5'
    G @('branch','unique') | Out-Null;$r=Run $q;Check (-not $r.ok -and $r.error -match 'Branch ref drift' -and (G @('rev-parse','unique')) -eq $cleanupApproval) 'V4 branch SHA guard failed'
    $q.head=$cleanupApproval;$q.evidence=@(@{commit=$cleanupApproval;path='approval.txt';blob=$cleanupBlob})
    $r=Run $q;Check ($r.ok -and $r.changed -and (G @('branch','--list','unique')) -eq '') ("V4 branch deletion failed: $($r.error)")
    $results.V4='PASS (branch SHA drift refused; retained branch deleted)'
    $q=[ordered]@{} + $p;$q.action='terminal-close';$q.gate='G5';$q.target='lead';$q.handle='lead';$q.role='lead';$q.completed='true';$q.evidenceRetained='true';$q.approvalCommit=$cleanupApproval;$q.approvalBlob=$cleanupBlob;$q.approvalPhrase='G5';$r=Run $q
    Check (-not $r.ok -and $r.error -match 'Missing worktreeId|Explicit worktree ID required') 'V5 exact identity guard failed'
    $q.worktreeId="fixture::$($repo.Replace('\','/'))";$q.worktreePath=$repo.Replace('\','/');$q.head=G @('rev-parse','HEAD')
    $fake=[ordered]@{ok=$true;result=@{worktree=@{id=$q.worktreeId;path=$q.worktreePath;git=@{path=$q.worktreePath;head=$q.head};workspaceStatus='completed';childWorktreeIds=@();head=$q.head}}}
    $env:GAD_FAKE_ORCA_FILE=Join-Path $root 'orca-response.json';$fake | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $env:GAD_FAKE_ORCA_FILE -Encoding ASCII
    '@echo off' + "`r`ntype `"%GAD_FAKE_ORCA_FILE%`"" | Set-Content -LiteralPath (Join-Path $root 'orca.cmd') -Encoding ASCII
    $priorPath=$env:PATH;$env:PATH="$root;$priorPath"
    try { 'dirty' | Set-Content -LiteralPath (Join-Path $repo 'dirty.txt');$r=Run $q;Check (-not $r.ok -and $r.error -match 'Dirty or unknown checkout' -and (Test-Path (Join-Path $repo 'dirty.txt'))) 'V5 dirty terminal checkout accepted' }
    finally { $env:PATH=$priorPath;Remove-Item -LiteralPath (Join-Path $repo 'dirty.txt');Remove-Item Env:GAD_FAKE_ORCA_FILE }
    $results.V5='PASS (exact identity and dirty terminal checkout refused; live Orca close deferred)'
    $frozen=G @('rev-parse','HEAD');$review=Join-Path $root 'review';G @('worktree','add','--detach',$review,$frozen) | Out-Null
    Check ((& git -C $review rev-parse HEAD).Trim() -eq $frozen -and -not ((& git -C $review status --porcelain) -join '')) 'V6 frozen checkout invalid'
    $results.V6='FIXTURE (frozen Git checkout; Orca Review isolation pending)'
    $r=Run $p;Check ($r.ok -and -not $r.changed -and (G @('rev-parse','HEAD')) -eq $frozen) 'V7 retry changed state';$results.V7='PASS (promotion retry idempotent; interrupted Orca lifecycle deferred)'
    $metrics=[ordered]@{peakWorkers='2';peakWorktrees='4';newBranches='2';mechanicalWorkers='0';verificationCases='8';manualCoordination='0';elapsedSeconds='123';provenance='Git/Orca snapshots';bootstrapComparison='19 cases measured; others unknown'}
    foreach($key in @('peakWorkers','peakWorktrees','newBranches','mechanicalWorkers','verificationCases','manualCoordination','elapsedSeconds','provenance','bootstrapComparison')) { Check (-not [string]::IsNullOrWhiteSpace($metrics[$key])) "V8 missing $key" }
    $c=[ordered]@{repo=$repo;action='close';gate='G5';mainRef='refs/heads/main';target='LEAN-01';batch='LEAN-01';reviewVerdict='GREEN';evidence=@(@{commit=$cleanupApproval;path='approval.txt';blob=$cleanupBlob});objects=@();metrics=$metrics}
    & git -C $repo worktree remove --force $review 2>$null | Out-Null
    $refs=(G @('for-each-ref','--format=%(refname:short)','refs/heads')).Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -cne 'main' }
    foreach($b in @($refs)) { G @('branch','-D',$b) | Out-Null }
    $c.objects=@()
    $fakeList=[ordered]@{ok=$true;result=[ordered]@{worktrees=@([ordered]@{id="fixture::$($repo.Replace('\','/'))";repoId='fixture';path=$repo.Replace('\','/');isMainWorktree=$true;branch='refs/heads/main';git=@{path=$repo.Replace('\','/');branch='refs/heads/main';head=(G @('rev-parse','HEAD'))}});truncated=$false;hostScope=@{omittedHostIds=@()}}}
    $env:GAD_FAKE_ORCA_FILE=Join-Path $root 'orca-response.json';$fakeList | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $env:GAD_FAKE_ORCA_FILE -Encoding ASCII
    $priorPath=$env:PATH;$env:PATH="$root;$priorPath"
    try { $r=Run $c; Check ($r.ok -and -not $r.changed -and $r.metrics.verificationCases -eq '8') 'V8 canonical path closure failed'; $c.objects=@(@{kind='branch';name='refs/heads/unique';disposition='removed'}); $r=Run $c; Check (-not $r.ok -and $r.error -match 'Removed closure object') 'V8 removed history was accepted' }
    finally { $env:PATH=$priorPath;Remove-Item Env:GAD_FAKE_ORCA_FILE }
    $c.metrics.elapsedSeconds='unknown';$r=Run $c;Check (-not $r.ok -and $r.error -match 'Invalid metric') 'V8 invalid metric accepted'
    $results.V8='PASS (caller GREEN and incomplete inventory refused; invalid metric refused; real G5 evidence deferred)'
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
