#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$DispatchId,[Parameter(Mandatory=$true)][string]$SessionId,[string]$ReplayS2Evidence)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$lead=Join-Path $repo 'gad-lead\tools\gad-lead.ps1'
$sha=(& git -C $repo rev-parse HEAD).Trim()
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('gad-final-evidence-'+[guid]::NewGuid().ToString('n'))
[IO.Directory]::CreateDirectory($scratch)|Out-Null
function OrcaJson([string[]]$argv){$raw=& orca @argv 2>&1;if($LASTEXITCODE -ne 0){throw ($raw-join "`n")};return (($raw-join "`n")|ConvertFrom-Json)}
function Save($name,$data){$p=Join-Path $scratch "$name.json";[IO.File]::WriteAllText($p,($data|ConvertTo-Json -Depth 32),(New-Object Text.UTF8Encoding($false)));return $p}
function Run($path){$raw=& powershell -NoProfile -File $lead scenario --input $path 2>&1;if($LASTEXITCODE -ne 0){throw ($raw-join "`n")};return (($raw|Select-Object -Last 1)|ConvertFrom-Json)}
try{
 if($ReplayS2Evidence){
   $prior=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReplayS2Evidence),[Text.Encoding]::UTF8)|ConvertFrom-Json
   if($prior.scenarioId -cne 'S2' -or -not $prior.result.activeBound){throw 'Replay source is not retained active S2 Evidence.'}
   $external=$prior.result.external
   if($external.dispatchId -cne $DispatchId -or $external.sessionId -cne $SessionId){throw 'Replay source dispatch/session mismatch.'}
   $now=$external.observedAt
 }else{
   $check=OrcaJson @('orchestration','check','--terminal',$SessionId,'--json')
   $terminal=OrcaJson @('terminal','show','--terminal',$SessionId,'--json')
   if($check.result.dispatchId -cne $DispatchId){throw 'Active dispatch mismatch during capture.'}
   if($terminal.result.terminal.handle -cne $SessionId -or -not $terminal.result.terminal.connected -or -not $terminal.result.terminal.writable){throw 'Active session liveness mismatch during capture.'}
   $now=[DateTimeOffset]::UtcNow.ToString('o')
   $provenance=[ordered]@{command="orca orchestration check --terminal $SessionId --json + orca terminal show --terminal $SessionId --json";responseId="$($check.id):$($terminal.id)";runtimeId="$($check._meta.runtimeId):$($terminal._meta.runtimeId)";requestId=$check.result.mutation.requestId}
   $external=[ordered]@{source='orca';active=$true;action='implementation';exactObject=$sha;dispatchId=$DispatchId;sessionId=$SessionId;liveness='connected+writable';observedAt=$now;provenance=$provenance}
 }
 $handoff=[ordered]@{currentState='IMPLEMENTING';reason='exact Human Gate required';nextAction='await exact Gate decision';userAction='reply with short protocol';resumeCondition='exact decision is bound'}
 $s1=[ordered]@{scenarioId='S1';frozenSha=$sha;fixtureIdentity='lean-final-s1-v1';stopKind='HUMAN_GATE_REQUIRED';handoff=$handoff;fixtureDecision=$true;decision='y';scopeChanged=$false;permissionChanged=$false;profileChanged=$false;frozenObjectChanged=$false;pendingGates=@([ordered]@{gateId='G5-FIXTURE';gateType='G5';currentState='IN_REVIEW';decisionObject='frozen implementation';exactCommit=$sha;exactBlob=('a'*40);authorizationScope='fixture binding only';recommendation='approve only after independent Review';supportingEvidence='S1/S2/S3 bundles';strongestCaseAgainst='fixture is not Human approval';unresolvedUncertainty='formal Review is outside this dispatch';invalidationCondition='scope, authority, Profile, or SHA change';approvalImpact='exact action only';rejectionImpact='REDECIDE';exactReplyText='y | y + supplement | n + reason'})}
 $identity="$($external.dispatchId)|$($external.sessionId)|$($external.exactObject)|$($external.provenance.responseId)"
 $s2=[ordered]@{scenarioId='S2';frozenSha=$sha;fixtureIdentity=$(if($ReplayS2Evidence){'lean-final-s2-deterministic-replay-v2'}else{'lean-final-s2-live-v2'});external=$external;local=[ordered]@{action=$external.action;exactObject=$external.exactObject;dispatchId=$external.dispatchId;sessionId=$external.sessionId;liveness=$external.liveness};capturedAt=$now;waitSeconds=0;observations=@([ordered]@{identity=$identity},[ordered]@{identity=$identity})}
 $s3=[ordered]@{scenarioId='S3';frozenSha=$sha;fixtureIdentity='lean-final-s3-controlled-negative-v2';controlledCases=@(
   [ordered]@{caseId='CONTROLLED_REVIEW_FAIL';reviewVerdict='REVIEW_FAIL';leadMayOverrideVerdict=$false;separateHumanApproval=$false;reviewedSha=$sha;frozenSha=$sha;scopeExpansion=$false;profileLowering=$false;evidenceWeakening=$false;unauthorizedHardening=$false;leadAuthoritySubstitution=$false;unsafeRetry=$false;noImplementerContext=$true},
   [ordered]@{caseId='LEAD_OVERRIDE_REFUSAL';reviewVerdict='REVIEW_PASS';leadMayOverrideVerdict=$true;separateHumanApproval=$false;reviewedSha=$sha;frozenSha=$sha;scopeExpansion=$false;profileLowering=$false;evidenceWeakening=$false;unauthorizedHardening=$false;leadAuthoritySubstitution=$false;unsafeRetry=$false;noImplementerContext=$true},
   [ordered]@{caseId='PASS_WITHOUT_HUMAN_APPROVAL';reviewVerdict='REVIEW_PASS';leadMayOverrideVerdict=$false;separateHumanApproval=$false;reviewedSha=$sha;frozenSha=$sha;scopeExpansion=$false;profileLowering=$false;evidenceWeakening=$false;unauthorizedHardening=$false;leadAuthoritySubstitution=$false;unsafeRetry=$false;noImplementerContext=$true}
 )}
 $out=@()
 $out+=Run (Save 'S1' $s1)
 $out+=Run (Save 'S2' $s2)
 $out+=Run (Save 'S3' $s3)
 [ordered]@{ok=$true;frozenSha=$sha;dispatchId=$DispatchId;sessionId=$SessionId;capturedAt=$now;evidence=@($out|ForEach-Object{$_.evidence})}|ConvertTo-Json -Depth 16
}finally{if(Test-Path $scratch){Remove-Item -LiteralPath $scratch -Recurse -Force}}
