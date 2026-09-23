#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$lead=Join-Path $repo 'gad-lead\tools\gad-lead.ps1'
$head=(& git -C $repo rev-parse HEAD).Trim()
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('gad-scenarios-'+[guid]::NewGuid().ToString('n'))
$evidence=Join-Path $scratch 'evidence'
[IO.Directory]::CreateDirectory($scratch)|Out-Null
$results=[ordered]@{}

function Write-Input($name,$value) { $path=Join-Path $scratch "$name.json"; [IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth 32),(New-Object Text.UTF8Encoding($false))); return $path }
function Run($name,$value) { $path=Write-Input $name $value; $old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$raw=& powershell -NoProfile -File $lead scenario --input $path --evidence-root $evidence 2>&1;$code=$LASTEXITCODE}finally{$ErrorActionPreference=$old}; $jsonLine=@($raw|ForEach-Object{$_.ToString()}|Where-Object{$_.TrimStart().StartsWith('{')})|Select-Object -Last 1;$json=$jsonLine|ConvertFrom-Json; return [pscustomobject]@{code=$code;json=$json;raw=($raw-join "`n")} }
function Pass($condition,$message) { if(-not $condition){throw $message} }
function Refuse($name,$value,$pattern) { $r=Run $name $value; Pass ($r.code -ne 0 -and $r.raw -match $pattern) "$name did not fail closed: $($r.raw)" }
function Base($id) { return [ordered]@{scenarioId=$id;frozenSha=$head;fixtureIdentity="$id-fixture-v1"} }

try {
    $handoff=[ordered]@{currentState='ACTIVE';reason='human approval required';nextAction='wait for Gate decision';userAction='reply with short protocol';resumeCondition='exact bound decision received'}
    foreach($stop in @('REAL_BLOCKER','MODE_BOUNDARY','GOAL_COMPLETE')) { $q=Base 'S1';$q.stopKind=$stop;$q.handoff=$handoff;$q.pendingGates=@();$q.decision='';$q.fixtureDecision=$true;$r=Run "s1-$stop" $q;Pass ($r.code -eq 0 -and $r.json.result.stopKind -ceq $stop) "S1 $stop failed" }
    foreach($decision in @('y','y + same scope','n + insufficient evidence')) { $q=Base 'S1';$q.stopKind='HUMAN_GATE_REQUIRED';$q.handoff=$handoff;$q.fixtureDecision=$true;$q.decision=$decision;$q.scopeChanged=$false;$q.permissionChanged=$false;$q.profileChanged=$false;$q.frozenObjectChanged=$false;$q.pendingGates=@([ordered]@{gateId='G3-A';gateType='G3';currentState='READY_FOR_APPROVAL';decisionObject='Batch A exact object';exactCommit=$head;exactBlob=('a'*40);authorizationScope='scenario implementation only';recommendation='approve';supportingEvidence='S1/S2';strongestCaseAgainst='external binding may drift';unresolvedUncertainty='Review not executed';invalidationCondition='scope or frozen object changes';approvalImpact='implementation allowed';rejectionImpact='enter REDECIDE';exactReplyText='y | y + supplement | n + reason'});$r=Run ('s1-'+($decision.Substring(0,1))) $q;Pass ($r.code -eq 0 -and -not $r.json.result.gateBinding.humanApproval) "S1 decision binding failed" }
    $q.scopeChanged=$true;Refuse 's1-refreeze' $q 're-freeze|Amendment';$results.S1='PASS'

    $now=[DateTimeOffset]::UtcNow.ToString('o');$external=[ordered]@{source='orca';active=$true;action='implementation';exactObject=$head;dispatchId='ctx-live';sessionId='term-live';liveness='running';observedAt=$now;provenance=[ordered]@{command='orca orchestration check --json';responseId='fixture-response';runtimeId='fixture-runtime';requestId='fixture-request'}}
    $q=Base 'S2';$q.external=$external;$q.local=[ordered]@{action='implementation';exactObject=$head;dispatchId='ctx-live';sessionId='term-live';liveness='running'};$q.capturedAt=$now;$q.waitSeconds=30;$q.observations=@([ordered]@{identity='same'},[ordered]@{identity='same'});$r=Run 's2-active' $q;Pass ($r.code -eq 0 -and $r.json.result.activeBound -and $r.json.result.nextAction -ceq 'RECONCILE') 'S2 active/no-progress failed'
    $bad=($q|ConvertTo-Json -Depth 32|ConvertFrom-Json);$bad.local.dispatchId='wrong';Refuse 's2-mismatch' $bad 'mismatch'
    $none=Base 'S2';$none.external=[ordered]@{source='orca';active=$false;provenance=[ordered]@{command='orca orchestration check --json';responseId='fixture-none';runtimeId='fixture-runtime';requestId='fixture-request'}};$none.local=[ordered]@{};$none.capturedAt=$now;$none.waitSeconds=0;$none.observations=@([ordered]@{identity='none'});$r=Run 's2-none' $none;Pass ($r.code -eq 0 -and -not $r.json.result.wait -and $r.json.result.nextAction -ceq 'RECONCILE') 'S2 no-active failed';$results.S2='PASS'

    $q=Base 'S3';$q.reviewVerdict='REVIEW_FAIL';$q.reviewedSha=$head;$q.leadMayOverrideVerdict=$false;$q.scopeExpansion=$false;$q.profileLowering=$false;$q.evidenceWeakening=$false;$q.unauthorizedHardening=$false;$q.leadAuthoritySubstitution=$false;$q.unsafeRetry=$false;$q.noImplementerContext=$true;$q.separateHumanApproval=$false;$r=Run 's3-fail' $q;Pass ($r.code -eq 0 -and -not $r.json.result.g5Eligible -and $r.json.result.nextAction -ceq 'REWORK_OR_STOP') "S3 REVIEW_FAIL protection failed: $($r.raw)"
    $q.reviewVerdict='REVIEW_PASS';$r=Run 's3-pass-no-g5' $q;Pass ($r.code -eq 0 -and -not $r.json.result.g5Eligible -and $r.json.result.nextAction -ceq 'HUMAN_GATE_REQUIRED') 'S3 separate approval failed'
    $q.leadMayOverrideVerdict=$true;Refuse 's3-override' $q 'may not override';$results.S3='PASS'
    $files=@(Get-ChildItem -LiteralPath $evidence -File);Pass ($files.Count -ge 8) 'Content-addressed scenario evidence was not retained';$results.Evidence="PASS ($($files.Count) bundles)"
    [ordered]@{ok=$true;head=$head;results=$results;evidenceRoot=$evidence}|ConvertTo-Json -Depth 8
}
finally { if(Test-Path $scratch){Remove-Item -LiteralPath $scratch -Recurse -Force} }
