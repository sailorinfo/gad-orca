#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [Parameter(Mandatory=$true)][string]$InputPath,
    [string]$EvidenceRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Property($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function Require($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Text($Object, [string]$Name) {
    $value = Property $Object $Name
    Require ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) "Missing $Name."
    return [string]$value
}

function Bool($Object, [string]$Name) {
    $value = Property $Object $Name
    Require ($null -ne $value) "Missing $Name."
    return [bool]$value
}

function Same($Left, $Right, [string]$Name) {
    Require ((Text $Left $Name) -ceq (Text $Right $Name)) "External active record mismatch: $Name."
}

function CanonicalJson($Object) {
    return ($Object | ConvertTo-Json -Depth 32 -Compress)
}

function Sha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Resolve-EvidenceRoot([string]$Root, [string]$Repo) {
    if ($Root) { return [IO.Path]::GetFullPath($Root) }
    $common = (& git -C $Repo rev-parse --git-common-dir 2>&1)
    Require ($LASTEXITCODE -eq 0) 'Unable to resolve git common directory.'
    $commonPath = [string]$common
    if (-not [IO.Path]::IsPathRooted($commonPath)) { $commonPath = Join-Path $Repo $commonPath }
    return (Join-Path ([IO.Path]::GetFullPath($commonPath)) 'gad-evidence')
}

function Invoke-S1($Data) {
    $allowedStops = @('HUMAN_GATE_REQUIRED','REAL_BLOCKER','MODE_BOUNDARY','GOAL_COMPLETE')
    $stop = Text $Data 'stopKind'
    Require ($allowedStops -ccontains $stop) 'Unsupported stop kind.'
    $handoff = Property $Data 'handoff'
    foreach ($field in @('currentState','reason','nextAction','userAction','resumeCondition')) { [void](Text $handoff $field) }
    $gates = @(Property $Data 'pendingGates')
    $decisionValue = Property $Data 'decision'
    $decision = if ($null -eq $decisionValue) { '' } else { [string]$decisionValue }
    if ($stop -ceq 'HUMAN_GATE_REQUIRED') {
        Require ($gates.Count -eq 1) 'Human Gate stop requires exactly one pending Gate.'
        $gate = $gates[0]
        foreach ($field in @('gateId','gateType','currentState','decisionObject','exactCommit','exactBlob','authorizationScope','recommendation','supportingEvidence','strongestCaseAgainst','unresolvedUncertainty','invalidationCondition','approvalImpact','rejectionImpact','exactReplyText')) { [void](Text $gate $field) }
        Require ((Bool $Data 'fixtureDecision') -eq $true) 'Scenario decision must be explicitly marked as fixture input.'
        if ($decision -ceq 'y') { $binding = 'APPROVE_EXACT' }
        elseif ($decision -cmatch '^y \+\s*\S') { $binding = 'APPROVE_WITH_SUPPLEMENT' }
        elseif ($decision -cmatch '^n \+\s*\S') { $binding = 'REJECT_REDECIDE' }
        else { throw 'Decision must be y, y + <supplement>, or n + <reason>.' }
        foreach ($changed in @('scopeChanged','permissionChanged','profileChanged','frozenObjectChanged')) {
            if ((Property $Data $changed) -eq $true) { throw 'Gate object changed; re-freeze or Amendment is required.' }
        }
        $gateBinding = [ordered]@{ gateId=$gate.gateId; exactCommit=$gate.exactCommit; exactBlob=$gate.exactBlob; authorizationScope=$gate.authorizationScope; disposition=$binding; humanApproval=$false }
    }
    else {
        Require ($gates.Count -eq 0) 'Non-Gate stop cannot carry a pending Gate.'
        Require ([string]::IsNullOrWhiteSpace($decision)) 'Non-Gate stop cannot bind a Gate decision.'
        $gateBinding = $null
    }
    $prefix = -join @([char]0x534f,[char]0x8c03,[char]0x5df2,[char]0x5230,[char]0x8fbe,[char]0x5408,[char]0x6cd5,[char]0x505c,[char]0x6b62,[char]0x70b9,[char]0xff1a)
    $suffix = -join @([char]0x3002,[char]0x5f53,[char]0x524d,[char]0x72b6,[char]0x6001,[char]0x3001,[char]0x539f,[char]0x56e0,[char]0x3001,[char]0x4e0b,[char]0x4e00,[char]0x6b65,[char]0x3001,[char]0x7528,[char]0x6237,[char]0x52a8,[char]0x4f5c,[char]0x548c,[char]0x6062,[char]0x590d,[char]0x6761,[char]0x4ef6,[char]0x5747,[char]0x5df2,[char]0x63d0,[char]0x4f9b,[char]0x3002)
    return [ordered]@{ scenarioId='S1'; ok=$true; stopKind=$stop; continuedUntilApprovedStop=$true; pendingGateCount=$gates.Count; gateBinding=$gateBinding; handoff=$handoff; userOutput="$prefix$stop$suffix" }
}

function Invoke-S2($Data) {
    $external = Property $Data 'external'
    $local = Property $Data 'local'
    Require ($null -ne $external) 'External Orca structured record is required.'
    Require ((Text $external 'source') -ceq 'orca') 'External record must be sourced from Orca.'
    $provenance = Property $external 'provenance'
    foreach ($field in @('command','responseId','runtimeId','requestId')) { [void](Text $provenance $field) }
    $active = Bool $external 'active'
    $waitSeconds = [int](Property $Data 'waitSeconds')
    Require ($waitSeconds -ge 0 -and $waitSeconds -le 30) 'Structured wait must be between 0 and 30 seconds.'
    if (-not $active) {
        return [ordered]@{ scenarioId='S2'; ok=$true; activeBound=$false; wait=$false; nextAction='RECONCILE'; reason='NO_ACTIVE_EXECUTION'; terminalRead='NOT_USED' }
    }
    foreach ($field in @('action','exactObject','dispatchId','sessionId','liveness')) { Same $external $local $field }
    $observed = [DateTimeOffset]::Parse((Text $external 'observedAt'))
    $captured = [DateTimeOffset]::Parse((Text $Data 'capturedAt'))
    Require ([Math]::Abs(($captured - $observed).TotalSeconds) -le 120) 'External active record is stale.'
    $observations = @(Property $Data 'observations')
    Require ($observations.Count -ge 1 -and $observations.Count -le 2) 'One or two structured observations are required.'
    $unchanged = $false
    if ($observations.Count -eq 2) { $unchanged = ((Text $observations[0] 'identity') -ceq (Text $observations[1] 'identity')) }
    return [ordered]@{ scenarioId='S2'; ok=$true; activeBound=$true; external=[ordered]@{action=$external.action;exactObject=$external.exactObject;dispatchId=$external.dispatchId;sessionId=$external.sessionId;liveness=$external.liveness;observedAt=$external.observedAt;provenance=$provenance}; wait=(-not $unchanged); waitSeconds=$waitSeconds; nextAction=$(if($unchanged){'RECONCILE'}else{'WAIT'}); unchangedObservations=$observations.Count; terminalRead='DIAGNOSTIC_FALLBACK_ONLY' }
}

function Invoke-S3($Data) {
    $verdict = Text $Data 'reviewVerdict'
    Require ($verdict -in @('REVIEW_PASS','REVIEW_FAIL')) 'Unsupported Review verdict.'
    Require ((Bool $Data 'leadMayOverrideVerdict') -eq $false) 'Lead may not override Reviewer verdict.'
    foreach ($field in @('scopeExpansion','profileLowering','evidenceWeakening','unauthorizedHardening','leadAuthoritySubstitution','unsafeRetry')) {
        Require ((Bool $Data $field) -eq $false) "Unsafe review condition: $field."
    }
    Require ((Bool $Data 'noImplementerContext') -eq $true) 'Independent Review context separation is required.'
    $reviewedSha = Text $Data 'reviewedSha'
    $frozenSha = Text $Data 'frozenSha'
    Require ($reviewedSha -ceq $frozenSha) 'Reviewer SHA does not match frozen implementation SHA.'
    $humanApproval = Bool $Data 'separateHumanApproval'
    $eligible = ($verdict -ceq 'REVIEW_PASS' -and $humanApproval)
    return [ordered]@{ scenarioId='S3'; ok=$true; reviewVerdict=$verdict; reviewedSha=$reviewedSha; verdictImmutable=$true; g5Eligible=$eligible; nextAction=$(if($eligible){'G5_AUTHORIZED_ACTION'}elseif($verdict -ceq 'REVIEW_FAIL'){'REWORK_OR_STOP'}else{'HUMAN_GATE_REQUIRED'}) }
}

try {
    $repo = (Resolve-Path -LiteralPath $Project).Path
    $inputPath = (Resolve-Path -LiteralPath $InputPath).Path
    $data = [IO.File]::ReadAllText($inputPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    $scenarioId = Text $data 'scenarioId'
    $frozenSha = Text $data 'frozenSha'
    Require ($frozenSha -cmatch '^[0-9a-f]{40}$') 'frozenSha must be an exact lowercase Git SHA.'
    $head = (& git -C $repo rev-parse HEAD 2>&1)
    Require ($LASTEXITCODE -eq 0 -and ([string]$head).Trim() -ceq $frozenSha) 'frozenSha does not match checkout HEAD.'
    $result = switch ($scenarioId) { 'S1' { Invoke-S1 $data } 'S2' { Invoke-S2 $data } 'S3' { Invoke-S3 $data } default { throw 'scenarioId must be S1, S2, or S3.' } }
    $command = "powershell -NoProfile -File gad-lead/tools/gad-lead.ps1 scenario --input $InputPath"
    $bundle = [ordered]@{ scenarioId=$scenarioId; frozenSha=$frozenSha; command=$command; fixtureIdentity=(Text $data 'fixtureIdentity'); result=$result; exitStatus=0; provenance=[ordered]@{ source='gad-lead.ps1 scenario'; inputSha256=(Sha256 ([IO.File]::ReadAllText($inputPath, [Text.Encoding]::UTF8))) } }
    $canonical = CanonicalJson $bundle
    $digest = Sha256 $canonical
    $root = Resolve-EvidenceRoot $EvidenceRoot $repo
    [IO.Directory]::CreateDirectory($root) | Out-Null
    $locator = Join-Path $root "$digest.json"
    [IO.File]::WriteAllText($locator, $canonical, (New-Object Text.UTF8Encoding($false)))
    [ordered]@{ ok=$true; scenarioId=$scenarioId; result=$result; evidence=[ordered]@{ locator=$locator; sha256=$digest } } | ConvertTo-Json -Depth 32 -Compress
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    [ordered]@{ ok=$false; error=$_.Exception.Message } | ConvertTo-Json -Compress
    exit 1
}
