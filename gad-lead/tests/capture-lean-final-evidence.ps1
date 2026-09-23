#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$DispatchId,[Parameter(Mandatory=$true)][string]$SessionId)
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
 $check=OrcaJson @('orchestration','check','--terminal',$SessionId,'--json')
 $terminal=OrcaJson @('terminal','show','--terminal',$SessionId,'--json')
 if($check.result.dispatchId -cne $DispatchId){throw 'Active dispatch mismatch during capture.'}
 if($terminal.result.terminal.handle -cne $SessionId -or -not $terminal.result.terminal.connected -or -not $terminal.result.terminal.writable){throw 'Active session liveness mismatch during capture.'}
 $now=[DateTimeOffset]::UtcNow.ToString('o')
 $handoff=[ordered]@{currentState='IMPLEMENTING';reason='exact Human Gate required';nextAction='await exact Gate decision';userAction='reply with short protocol';resumeCondition='exact decision is bound'}
 $s1=[ordered]@{scenarioId='S1';frozenSha=$sha;fixtureIdentity='lean-final-s1-v1';stopKind='HUMAN_GATE_REQUIRED';handoff=$handoff;fixtureDecision=$true;decision='y';scopeChanged=$false;permissionChanged=$false;profileChanged=$false;frozenObjectChanged=$false;pendingGates=@([ordered]@{gateId='G5-FIXTURE';gateType='G5';currentState='IN_REVIEW';decisionObject='frozen implementation';exactCommit=$sha;exactBlob=('a'*40);authorizationScope='fixture binding only';recommendation='approve only after independent Review';supportingEvidence='S1/S2/S3 bundles';strongestCaseAgainst='fixture is not Human approval';unresolvedUncertainty='formal Review is outside this dispatch';invalidationCondition='scope, authority, Profile, or SHA change';approvalImpact='exact action only';rejectionImpact='REDECIDE';exactReplyText='y | y + supplement | n + reason'})}
 $provenance=[ordered]@{command="orca orchestration check --terminal $SessionId --json + orca terminal show --terminal $SessionId --json";responseId="$($check.id):$($terminal.id)";runtimeId="$($check._meta.runtimeId):$($terminal._meta.runtimeId)";requestId=$check.result.mutation.requestId}
 $external=[ordered]@{source='orca';active=$true;action='implementation';exactObject=$sha;dispatchId=$DispatchId;sessionId=$SessionId;liveness='connected+writable';observedAt=$now;provenance=$provenance}
 $s2=[ordered]@{scenarioId='S2';frozenSha=$sha;fixtureIdentity='lean-final-s2-live-v1';external=$external;local=[ordered]@{action='implementation';exactObject=$sha;dispatchId=$DispatchId;sessionId=$SessionId;liveness='connected+writable'};capturedAt=$now;waitSeconds=0;observations=@([ordered]@{identity="$DispatchId|$SessionId|$sha"})}
 $s3=[ordered]@{scenarioId='S3';frozenSha=$sha;fixtureIdentity='lean-final-s3-controlled-pass-v1';reviewVerdict='REVIEW_PASS';reviewedSha=$sha;leadMayOverrideVerdict=$false;scopeExpansion=$false;profileLowering=$false;evidenceWeakening=$false;unauthorizedHardening=$false;leadAuthoritySubstitution=$false;unsafeRetry=$false;noImplementerContext=$true;separateHumanApproval=$false}
 $out=@()
 $out+=Run (Save 'S1' $s1)
 $out+=Run (Save 'S2' $s2)
 $out+=Run (Save 'S3' $s3)
 [ordered]@{ok=$true;frozenSha=$sha;dispatchId=$DispatchId;sessionId=$SessionId;capturedAt=$now;evidence=@($out|ForEach-Object{$_.evidence})}|ConvertTo-Json -Depth 16
}finally{if(Test-Path $scratch){Remove-Item -LiteralPath $scratch -Recurse -Force}}
