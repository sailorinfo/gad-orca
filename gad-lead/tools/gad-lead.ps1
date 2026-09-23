#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GadLeadVersion = '0.4.0'
$script:LeadWorktreeName = 'gad-lead'
$script:ActiveApprovalMarker = 'GAD Lead Active Mode: APPROVED'
$script:AgentPolicyFileName = 'GAD_AGENT_POLICY.conf'
$script:AgentPolicyDefaultTokens = @('', 'default', 'system', 'auto')
$script:SupportedOrcaAgentIds = @(
    'claude',
    'claude-agent-teams',
    'openclaude',
    'codex',
    'autohand',
    'ante',
    'trae',
    'opencode',
    'mimo-code',
    'pi',
    'omp',
    'prime-agent',
    'gemini',
    'antigravity',
    'aider',
    'goose',
    'amp',
    'kilo',
    'kiro',
    'crush',
    'aug',
    'cline',
    'codebuff',
    'command-code',
    'continue',
    'cursor',
    'droid',
    'kimi',
    'mistral-vibe',
    'qwen-code',
    'rovo',
    'hermes',
    'openclaw',
    'copilot',
    'grok',
    'devin'
)
$script:RequiredSkills = @(
    'gad-governance',
    'gad-project-inception',
    'gad-system-architecture',
    'gad-implementation-readiness',
    'gad-solution-research'
)

function Write-Diagnostic {
    param([Parameter(Mandatory=$true)][string]$Message)
    [Console]::Error.WriteLine($Message)
}

function Get-ArgValue {
    param(
        [string[]]$Tokens,
        [ref]$Index,
        [string]$Name
    )
    if ($Index.Value + 1 -ge $Tokens.Count) {
        throw "Missing value for $Name."
    }
    $Index.Value++
    return $Tokens[$Index.Value]
}

function Parse-Arguments {
    param([string[]]$Tokens)

    $command = 'help'
    $startAt = 0
    if ($Tokens.Count -gt 0 -and -not $Tokens[0].StartsWith('--')) {
        $command = $Tokens[0].ToLowerInvariant()
        $startAt = 1
    }

    $options = [ordered]@{
        Command  = $command
        Project  = $null
        Mode     = 'shadow'
        Json     = $false
        DryRun   = $false
        Activate = $false
        Strict   = $false
        Role     = $null
        Preference = $null
        Input    = $null
        EvidenceRoot = $null
    }

    for ($i = $startAt; $i -lt $Tokens.Count; $i++) {
        $token = $Tokens[$i]
        if ($token -match '^--([^=]+)=(.*)$') {
            $name = $Matches[1].ToLowerInvariant()
            $value = $Matches[2]
            switch ($name) {
                'project' { $options.Project = $value }
                'mode'    { $options.Mode = $value.ToLowerInvariant() }
                'role'    { $options.Role = $value.ToLowerInvariant() }
                'preference' { $options.Preference = $value.ToLowerInvariant() }
                'input' { $options.Input = $value }
                'evidence-root' { $options.EvidenceRoot = $value }
                default   { throw "Unknown option: --$name" }
            }
            continue
        }

        switch ($token.ToLowerInvariant()) {
            '--project'  { $options.Project = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--project' }
            '--mode'     { $options.Mode = (Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--mode').ToLowerInvariant() }
            '--json'     { $options.Json = $true }
            '--dry-run'  { $options.DryRun = $true }
            '--activate' { $options.Activate = $true }
            '--strict'   { $options.Strict = $true }
            '--role'     { $options.Role = (Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--role').ToLowerInvariant() }
            '--preference' { $options.Preference = (Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--preference').ToLowerInvariant() }
            '--input' { $options.Input = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--input' }
            '--evidence-root' { $options.EvidenceRoot = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--evidence-root' }
            '--help'     { $options.Command = 'help' }
            default      { throw "Unknown argument: $token" }
        }
    }

    if ($options.Mode -notin @('shadow', 'bootstrap', 'active')) {
        throw "Invalid mode '$($options.Mode)'. Expected shadow, bootstrap or active."
    }

    return [pscustomobject]$options
}

function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$File,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory
    )

    $oldLocation = $null
    try {
        if ($WorkingDirectory) {
            $oldLocation = Get-Location
            Set-Location -LiteralPath $WorkingDirectory
        }
        $lines = @(& $File @Arguments 2>&1)
        $code = $LASTEXITCODE
        $text = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        return [pscustomobject]@{ ExitCode = $code; Text = $text }
    }
    finally {
        if ($oldLocation) {
            Set-Location -LiteralPath $oldLocation.Path
        }
    }
}

function Invoke-OrcaJson {
    param(
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$WorkingDirectory
    )

    $result = Invoke-Native -File 'orca' -Arguments $Arguments -WorkingDirectory $WorkingDirectory
    if ([string]::IsNullOrWhiteSpace($result.Text)) {
        throw "Orca returned no JSON. Exit code: $($result.ExitCode)"
    }

    try {
        $json = $result.Text | ConvertFrom-Json
    }
    catch {
        throw "Unable to parse Orca JSON output. Exit=$($result.ExitCode). Output:`n$($result.Text)"
    }

    if ($result.ExitCode -ne 0) {
        $message = $result.Text
        if ($json.error -and $json.error.message) { $message = $json.error.message }
        throw "Orca command failed: $message"
    }

    if ($null -ne $json.ok -and -not [bool]$json.ok) {
        $message = if ($json.error -and $json.error.message) { $json.error.message } else { $result.Text }
        throw "Orca command failed: $message"
    }

    return $json
}

function Get-AgentPolicy {
    param([string]$ProjectRoot)

    $path = Join-Path $ProjectRoot "gad-lead\$script:AgentPolicyFileName"
    $values = [ordered]@{
        lead = 'default'
        implementation = 'default'
        review = 'default'
        other = 'default'
    }
    $warnings = @()

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $warnings += "Agent policy file missing; all roles use Orca Default Agent."
        return [pscustomobject]@{ path = $path; found = $false; values = [pscustomobject]$values; warnings = $warnings }
    }

    foreach ($rawLine in Get-Content -LiteralPath $path -Encoding UTF8) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }
        if ($line -notmatch '^([^=]+)=(.*)$') {
            $warnings += "Ignored malformed policy line: $rawLine"
            continue
        }

        $key = $Matches[1].Trim().ToLowerInvariant()
        $value = $Matches[2].Trim().ToLowerInvariant()
        if ($key -notin @('lead','implementation','review','other')) {
            $warnings += "Ignored unknown policy key '$key'."
            continue
        }
        $values[$key] = $value
    }

    return [pscustomobject]@{ path = $path; found = $true; values = [pscustomobject]$values; warnings = $warnings }
}

function Get-OrcaSettingsSnapshot {
    $candidates = @()

    if ($env:GAD_ORCA_SETTINGS_PATH) {
        $candidates += $env:GAD_ORCA_SETTINGS_PATH
    }

    if ($env:APPDATA) {
        $candidates += (Join-Path $env:APPDATA 'orca\profiles\local-default\orca-data.json')
        $candidates += (Join-Path $env:APPDATA 'orca\orca-data.json')
    }

    if ($HOME) {
        $candidates += (Join-Path $HOME 'Library/Application Support/orca/profiles/local-default/orca-data.json')
        $xdg = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
        $candidates += (Join-Path $xdg 'orca/profiles/local-default/orca-data.json')
    }

    $path = $null
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $path = (Resolve-Path -LiteralPath $candidate).Path
            break
        }
    }

    if (-not $path) {
        return [pscustomobject]@{
            found = $false
            path = $null
            defaultAgent = $null
            disabledAgents = @()
            agentCmdOverrides = $null
            agentDefaultArgs = $null
            agentDefaultEnv = $null
            warning = 'Orca settings store was not found; concrete system-default agent could not be resolved.'
        }
    }

    try {
        $store = Get-Content -LiteralPath $path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        return [pscustomobject]@{
            found = $false
            path = $path
            defaultAgent = $null
            disabledAgents = @()
            agentCmdOverrides = $null
            agentDefaultArgs = $null
            agentDefaultEnv = $null
            warning = "Unable to parse Orca settings store: $($_.Exception.Message)"
        }
    }

    $settings = Get-PropertyValue -Object $store -Name 'settings'
    if (-not $settings) {
        return [pscustomobject]@{
            found = $false
            path = $path
            defaultAgent = $null
            disabledAgents = @()
            agentCmdOverrides = $null
            agentDefaultArgs = $null
            agentDefaultEnv = $null
            warning = 'Orca settings store has no settings object.'
        }
    }

    $defaultAgent = Get-PropertyValue -Object $settings -Name 'defaultTuiAgent'
    $disabled = Get-PropertyValue -Object $settings -Name 'disabledTuiAgents'
    $overrides = Get-PropertyValue -Object $settings -Name 'agentCmdOverrides'
    $defaultArgs = Get-PropertyValue -Object $settings -Name 'agentDefaultArgs'
    $defaultEnv = Get-PropertyValue -Object $settings -Name 'agentDefaultEnv'

    return [pscustomobject]@{
        found = $true
        path = $path
        defaultAgent = $(if ($null -eq $defaultAgent) { $null } else { ([string]$defaultAgent).ToLowerInvariant() })
        disabledAgents = @($disabled | ForEach-Object { ([string]$_).ToLowerInvariant() })
        agentCmdOverrides = $overrides
        agentDefaultArgs = $defaultArgs
        agentDefaultEnv = $defaultEnv
        warning = $null
    }
}

function Get-AgentSettingValue {
    param($Map, [string]$Agent)
    if ($null -eq $Map) { return $null }
    $property = $Map.PSObject.Properties[$Agent]
    if ($property) { return $property.Value }
    return $null
}

function Get-FirstCommandToken {
    param([string]$CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return $null }
    $trimmed = $CommandText.Trim()
    if ($trimmed -match '^"([^"]+)"') { return $Matches[1] }
    if ($trimmed -match "^'([^']+)'") { return $Matches[1] }
    return ($trimmed -split '\s+', 2)[0]
}

function Get-OrcaAgentMetadata {
    param([string]$Agent)

    $id = $Agent.ToLowerInvariant()

    # Narrow compatibility snapshot of Orca's built-in TUI agent ids/launch names.
    # Orca still owns actual launching. A future/new id not in this snapshot
    # safely falls back to Orca Default Agent rather than being guessed.
    switch ($id) {
        'claude-agent-teams' {
            return [pscustomobject]@{
                detectAny = @('orca','orca-dev','orca-ide')
                required = @('claude')
                launch = 'orca claude-teams'
                unsupportedOnWindows = $true
            }
        }
        'trae' { return [pscustomobject]@{ detectAny=@('traecli'); required=@(); launch='traecli'; unsupportedOnWindows=$false } }
        'mimo-code' { return [pscustomobject]@{ detectAny=@('mimo'); required=@(); launch='mimo'; unsupportedOnWindows=$false } }
        'antigravity' { return [pscustomobject]@{ detectAny=@('agy'); required=@(); launch='agy'; unsupportedOnWindows=$false } }
        'kiro' { return [pscustomobject]@{ detectAny=@('kiro-cli'); required=@(); launch='kiro-cli chat --tui'; unsupportedOnWindows=$false } }
        'aug' { return [pscustomobject]@{ detectAny=@('auggie'); required=@(); launch='auggie'; unsupportedOnWindows=$false } }
        'command-code' { return [pscustomobject]@{ detectAny=@('command-code'); required=@(); launch='command-code --trust'; unsupportedOnWindows=$false } }
        'continue' { return [pscustomobject]@{ detectAny=@('cn'); required=@(); launch='cn'; unsupportedOnWindows=$false } }
        'cursor' { return [pscustomobject]@{ detectAny=@('cursor-agent'); required=@(); launch='cursor-agent'; unsupportedOnWindows=$false } }
        'mistral-vibe' { return [pscustomobject]@{ detectAny=@('vibe','mistral-vibe'); required=@(); launch='vibe'; unsupportedOnWindows=$false } }
        'qwen-code' { return [pscustomobject]@{ detectAny=@('qwen'); required=@(); launch='qwen'; unsupportedOnWindows=$false } }
        'hermes' { return [pscustomobject]@{ detectAny=@('hermes'); required=@(); launch='hermes --tui'; unsupportedOnWindows=$false } }
        default { return [pscustomobject]@{ detectAny=@($id); required=@(); launch=$id; unsupportedOnWindows=$false } }
    }
}

function Test-AnyCommandAvailable {
    param([object[]]$Commands)

    foreach ($command in @($Commands)) {
        if ($command -and (Get-Command ([string]$command) -ErrorAction SilentlyContinue)) {
            return $true
        }
    }
    return $false
}

function Test-AllCommandsAvailable {
    param([object[]]$Commands)

    foreach ($command in @($Commands)) {
        if (-not $command -or -not (Get-Command ([string]$command) -ErrorAction SilentlyContinue)) {
            return $false
        }
    }
    return $true
}

function Test-AgentPreferenceAvailable {
    param([string]$Agent, $OrcaSettings)

    if ([string]::IsNullOrWhiteSpace($Agent)) {
        return [pscustomobject]@{ available=$false; reason='empty'; commands=@(); terminalCommand=$null }
    }

    $agentId = $Agent.ToLowerInvariant()

    if ($script:AgentPolicyDefaultTokens -contains $agentId -or $agentId -eq 'blank') {
        return [pscustomobject]@{ available=$false; reason='system-default-token'; commands=@(); terminalCommand=$null }
    }

    if ($script:SupportedOrcaAgentIds -notcontains $agentId) {
        return [pscustomobject]@{ available=$false; reason='unsupported-by-orca-catalog-snapshot'; commands=@(); terminalCommand=$null }
    }

    if (@($OrcaSettings.disabledAgents) -contains $agentId) {
        return [pscustomobject]@{ available=$false; reason='disabled-in-orca'; commands=@(); terminalCommand=$null }
    }

    $metadata = Get-OrcaAgentMetadata -Agent $agentId

    if ($metadata.unsupportedOnWindows -and $env:OS -eq 'Windows_NT') {
        return [pscustomobject]@{ available=$false; reason='unsupported-on-windows'; commands=@($metadata.detectAny); terminalCommand=$null }
    }

    $override = Get-AgentSettingValue -Map $OrcaSettings.agentCmdOverrides -Agent $agentId
    $terminalCommand = $null
    $detectAny = @($metadata.detectAny)
    $required = @($metadata.required)

    if ($override) {
        $terminalCommand = [string]$override
        $overrideToken = Get-FirstCommandToken -CommandText $terminalCommand
        $detectAny = @($overrideToken)
        $required = @()
    }
    else {
        $terminalCommand = [string]$metadata.launch
    }

    if (-not (Test-AnyCommandAvailable -Commands $detectAny)) {
        return [pscustomobject]@{
            available=$false
            reason='agent-command-unavailable'
            commands=$detectAny
            terminalCommand=$null
        }
    }

    if (-not (Test-AllCommandsAvailable -Commands $required)) {
        return [pscustomobject]@{
            available=$false
            reason='required-agent-command-unavailable'
            commands=@($detectAny + $required)
            terminalCommand=$null
        }
    }

    $args = Get-AgentSettingValue -Map $OrcaSettings.agentDefaultArgs -Agent $agentId
    if ($args) {
        if ($args -is [System.Array]) { $argsText = (@($args) -join ' ') }
        else { $argsText = [string]$args }

        if (-not [string]::IsNullOrWhiteSpace($argsText)) {
            $terminalCommand = "$terminalCommand $argsText"
        }
    }

    return [pscustomobject]@{
        available=$true
        reason='available'
        commands=@($detectAny + $required)
        terminalCommand=$terminalCommand
    }
}

function Resolve-GadAgentPreference {
    param(
        [string]$ProjectRoot,
        [string]$Role,
        [string]$PreferenceOverride
    )

    $roleKey = if ($Role -in @('lead','implementation','review')) { $Role } else { 'other' }
    $policy = Get-AgentPolicy -ProjectRoot $ProjectRoot
    $settings = Get-OrcaSettingsSnapshot
    $configured = [string](Get-PropertyValue -Object $policy.values -Name $roleKey)
    $requested = if (-not [string]::IsNullOrWhiteSpace($PreferenceOverride)) { $PreferenceOverride.ToLowerInvariant() } else { $configured.ToLowerInvariant() }
    $source = if (-not [string]::IsNullOrWhiteSpace($PreferenceOverride)) { 'user-override' } elseif ($roleKey -eq 'other') { 'other-policy' } else { 'role-policy' }
    $warnings = @($policy.warnings)

    $preferenceUsesDefault = ([string]::IsNullOrWhiteSpace($requested) -or $script:AgentPolicyDefaultTokens -contains $requested)
    if (-not $preferenceUsesDefault) {
        $availability = Test-AgentPreferenceAvailable -Agent $requested -OrcaSettings $settings
        if ($availability.available) {
            return [pscustomobject]@{
                role = $Role
                policyRole = $roleKey
                configuredPreference = $configured
                requestedPreference = $requested
                resolvedAgent = $requested
                resolutionSource = $source
                fallback = $false
                fallbackReason = $null
                terminalCommand = $availability.terminalCommand
                orcaDefaultAgent = $settings.defaultAgent
                orcaSettingsPath = $settings.path
                warnings = $warnings
            }
        }
        $warnings += "Agent preference '$requested' is $($availability.reason); falling back to Orca Default Agent."
        $fallbackReason = $availability.reason
    }
    else {
        $fallbackReason = 'system-default-requested'
    }

    $defaultAgent = $settings.defaultAgent
    if (-not [string]::IsNullOrWhiteSpace($defaultAgent) -and $defaultAgent -ne 'blank') {
        $defaultAvailability = Test-AgentPreferenceAvailable -Agent $defaultAgent -OrcaSettings $settings
        if ($defaultAvailability.available) {
            return [pscustomobject]@{
                role = $Role
                policyRole = $roleKey
                configuredPreference = $configured
                requestedPreference = $requested
                resolvedAgent = $defaultAgent
                resolutionSource = 'orca-default'
                fallback = $true
                fallbackReason = $fallbackReason
                terminalCommand = $defaultAvailability.terminalCommand
                orcaDefaultAgent = $defaultAgent
                orcaSettingsPath = $settings.path
                warnings = $warnings
            }
        }
        $warnings += "Orca Default Agent '$defaultAgent' is $($defaultAvailability.reason)."
    }
    else {
        $warnings += 'Orca Default Agent is Auto/blank/unset; the public CLI does not expose a concrete default agent id for agent-first launch.'
    }

    if ($settings.warning) { $warnings += $settings.warning }

    return [pscustomobject]@{
        role = $Role
        policyRole = $roleKey
        configuredPreference = $configured
        requestedPreference = $requested
        resolvedAgent = $null
        resolutionSource = 'orca-default-unresolved'
        fallback = $true
        fallbackReason = $fallbackReason
        terminalCommand = $null
        orcaDefaultAgent = $defaultAgent
        orcaSettingsPath = $settings.path
        warnings = $warnings
    }
}

function Get-ProjectRoot {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath -PathType Container)) {
            throw "Project path does not exist: $RequestedPath"
        }
        $candidate = (Resolve-Path -LiteralPath $RequestedPath).Path
    }
    else {
        $git = Invoke-Native -File 'git' -Arguments @('rev-parse', '--show-toplevel')
        if ($git.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($git.Text)) {
            throw "Current directory is not inside a Git repository. Use --project <path>."
        }
        $candidate = $git.Text.Trim()
    }

    $root = Invoke-Native -File 'git' -Arguments @('-C', $candidate, 'rev-parse', '--show-toplevel')
    if ($root.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($root.Text)) {
        throw "Not a valid Git worktree: $candidate"
    }
    return (Resolve-Path -LiteralPath $root.Text.Trim()).Path
}

function Get-MainlineFacts {
    param([string]$ProjectRoot)

    $branch = (Invoke-Native -File 'git' -Arguments @('-C', $ProjectRoot, 'branch', '--show-current')).Text.Trim()
    $head = (Invoke-Native -File 'git' -Arguments @('-C', $ProjectRoot, 'rev-parse', 'HEAD')).Text.Trim()
    $status = (Invoke-Native -File 'git' -Arguments @('-C', $ProjectRoot, 'status', '--short', '--branch')).Text
    return [pscustomobject]@{
        Path = $ProjectRoot
        Branch = $branch
        Head = $head
        Status = $status
    }
}

function Get-OrcaCurrentWorktree {
    param([string]$ProjectRoot)
    $json = Invoke-OrcaJson -Arguments @('worktree', 'current', '--json') -WorkingDirectory $ProjectRoot
    return $json.result.worktree
}

function Get-OrcaWorktrees {
    param([string]$ProjectRoot)
    $json = Invoke-OrcaJson -Arguments @('worktree', 'list', '--json') -WorkingDirectory $ProjectRoot
    if ($json.result -and $json.result.worktrees) { return @($json.result.worktrees) }
    if ($json.worktrees) { return @($json.worktrees) }
    if ($json.result -is [System.Array]) { return @($json.result) }
    return @()
}

function Get-OrcaTerminals {
    param(
        [string]$ProjectRoot,
        [string]$WorktreeId
    )
    $selector = "id:$WorktreeId"
    $json = Invoke-OrcaJson -Arguments @('terminal', 'list', '--worktree', $selector, '--json') -WorkingDirectory $ProjectRoot
    if ($json.result -and $json.result.terminals) { return @($json.result.terminals) }
    if ($json.terminals) { return @($json.terminals) }
    if ($json.result -is [System.Array]) { return @($json.result) }
    return @()
}


function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Get-TerminalTitle {
    param($Terminal)
    $value = Get-PropertyValue -Object $Terminal -Name 'title'
    if ($null -eq $value) { return '' }
    return [string]$value
}

function Test-TerminalLive {
    param($Terminal)

    $connected = Get-PropertyValue -Object $Terminal -Name 'connected'
    if ($null -ne $connected -and -not [bool]$connected) { return $false }

    $writable = Get-PropertyValue -Object $Terminal -Name 'writable'
    if ($null -ne $writable -and -not [bool]$writable) { return $false }

    $status = Get-PropertyValue -Object $Terminal -Name 'status'
    if ($null -ne $status) {
        $s = ([string]$status).ToLowerInvariant()
        if ($s -in @('exited', 'closed', 'stopped', 'dead', 'terminated')) { return $false }
    }

    return $true
}

function Test-TerminalOrphaned {
    param($Terminal)
    $value = Get-PropertyValue -Object $Terminal -Name 'orphaned'
    return ($null -ne $value -and [bool]$value)
}

function Get-GadLeadTerminals {
    param([object[]]$Terminals)

    return @($Terminals | Where-Object {
        (Get-TerminalTitle -Terminal $_) -match '^GAD Lead \[(shadow|bootstrap|active)\]$'
    })
}

function Find-FirstPropertyValue {
    param(
        $Object,
        [string[]]$Names
    )
    if ($null -eq $Object) { return $null }

    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($property -and $null -ne $property.Value -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return $property.Value
        }
    }

    foreach ($property in $Object.PSObject.Properties) {
        $value = $property.Value
        if ($null -eq $value -or $value -is [string] -or $value.GetType().IsPrimitive) { continue }
        if ($value -is [System.Collections.IEnumerable]) {
            foreach ($item in $value) {
                $found = Find-FirstPropertyValue -Object $item -Names $Names
                if ($null -ne $found) { return $found }
            }
        }
        else {
            $found = Find-FirstPropertyValue -Object $value -Names $Names
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Get-GadLeadWorktrees {
    param(
        [object[]]$Worktrees,
        [string]$RepoId
    )

    return @($Worktrees | Where-Object {
        $leaf = ''
        if ($_.path) {
            $normalized = ([string]$_.path).Replace('/', '\')
            $leaf = [System.IO.Path]::GetFileName($normalized)
        }

        $candidateRepoId = Get-PropertyValue -Object $_ -Name 'repoId'
        if (-not $candidateRepoId) {
            $id = Get-PropertyValue -Object $_ -Name 'id'
            if ($id -and ([string]$id).Contains('::')) {
                $candidateRepoId = ([string]$id).Split('::')[0]
            }
        }

        (($null -eq $RepoId) -or ([string]$candidateRepoId -eq $RepoId)) -and (
            ([string]$_.displayName).ToLowerInvariant() -eq $script:LeadWorktreeName -or
            $leaf.ToLowerInvariant() -eq $script:LeadWorktreeName
        )
    })
}

function Test-ActiveApproved {
    param([string]$ProjectRoot)
    foreach ($file in @('PROJECT_RULES.md', 'DEVELOPMENT_WORKFLOW.md')) {
        $path = Join-Path $ProjectRoot $file
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $content = [System.IO.File]::ReadAllText($path)
            if ($content.Contains($script:ActiveApprovalMarker)) { return $true }
        }
    }
    return $false
}

function Get-ProjectStatusText {
    param([string]$ProjectRoot)
    $path = Join-Path $ProjectRoot 'PROJECT_STATUS.md'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return [System.IO.File]::ReadAllText($path)
}

function Get-LeadPrompt {
    param(
        [string]$ProjectRoot,
        [string]$Mode
    )

    $modelPath = Join-Path $ProjectRoot 'gad-lead\GAD_LEAD_OPERATING_MODEL.md'
    $readmePath = Join-Path $ProjectRoot 'gad-lead\README.md'

    return @"
你是本项目唯一的 GAD Lead。

主线项目绝对路径：
$ProjectRoot

本次运行模式：
$Mode

开始前必须读取：

1. $modelPath
2. $readmePath
3. $ProjectRoot\gad-lead\GAD_AGENT_POLICY.conf
4. 主线正式 Baseline
5. 主线 PROJECT_STATUS.md
6. Git 与 Orca 的实时状态

必须按照 GAD_LEAD_OPERATING_MODEL.md 的 Recovery Protocol：

RECONCILE
→ REFLECT
→ DECIDE

Shadow 模式只读，不创建普通 Worker、不发送任务、不修改文件、不推进 Gate。

Bootstrap 模式仅用于：
- 新项目在正式 Project Baseline 建立前的 GAD Lead 引导；
- 已存在项目正式采用 GAD Lead 的治理迁移。
Bootstrap 可编排 Inception / Architecture / Governance / Adoption Worker，
但不得启动产品实现、当前 Delivery Batch Rework、Review、Integration 或 Promotion。
G1/G2/G4 等 Human Gate 仍必须由用户明确批准。

Active 模式也不得直接修改项目文件或自我批准；文件变更必须派发给专用 Worker。

不要把当前 gad-lead Worktree 的快照或聊天摘要当成当前项目事实。
所有需要用户介入的内容都必须由你整理成 Decision Package。
其他 Worker 只对你汇报，不直接与用户沟通。

关键执行规则：
- Shadow：完成 RECONCILE → REFLECT → DECIDE 后输出报告并停止。
- Bootstrap / Active：DECIDE 之后，如果下一合法动作在当前模式权限内、无需 Human Gate、没有 blocker，就必须立即执行，不得停在“下一步应该……”或“我会……”。
- 允许执行时，先形成 Worktree Decision，再创建/恢复 Worker，发送完整合同，等待 Worker，核对结果和 Git/Orca 证据，然后重新进入 RECONCILE → REFLECT → DECIDE。
- Bootstrap / Active 必须持续这个闭环，直到遇到 Human Gate、真正 blocker、模式边界或当前目标完成。
- 不要要求用户手工创建 Worktree、复制 Prompt 或转发 Worker 输出。
- 每次 Worktree Decision 都必须先通过 `gad-lead\gad-lead.cmd agent --role <lead|implementation|review|other> --json` 解析 Agent Preference；不要自己维护另一套 Agent 默认值。
- implementation 用于 Implementer/Rework/Fix；review 用于 Independent Reviewer/Re-review；其他 Worker 一律使用 other。
- resolvedAgent 有值时使用 Orca agent-aware 启动（例如 `--agent <id>`）；若 preference 无效、禁用或不可用，resolver 自动回退到 Orca Default Agent。
- 每个普通 Batch 在派发前冻结 C/R/P、执行 Profile、风险→测试→证据→停止映射和严格资源预算，并以 `gad-control.ps1` 的只读 `governance-check` 做确定性校验。
- 默认三 Worktree；仅当 STRICT/CRITICAL Review 缺少 Orca 文件系统隔离证据时使用第四 Review Worktree。不得削弱独立 Review。
- 先区分 product/fixture/harness/environment/evidence-control，再决定修复；覆盖矩阵缺失或不可达即 REVIEW_FAIL。预算超限、第二次 Review 失败或分类不确定立即停止。
- `SIMPLIFY` 不得降低 Human Gate、Independent Review 或 Evidence；可选 hardening 与派生状态更新留到当前 Batch 之外或获授权的集成点。
"@
}



function Get-ContinuationPrompt {
    param(
        [string]$ProjectRoot,
        [string]$Mode
    )

    $modelPath = Join-Path $ProjectRoot 'gad-lead\GAD_LEAD_OPERATING_MODEL.md'

    return @"
GAD Lead CONTINUE COORDINATION

Mode: $Mode
Mainline: $ProjectRoot

Re-read:
$modelPath
$ProjectRoot\gad-lead\GAD_AGENT_POLICY.conf

Resume from current mainline / Git / Orca facts.

Execution rule:
- Do not stop after RECONCILE → REFLECT → DECIDE when the next legal action is permitted in the current mode.
- If no Human Gate, blocker, or mode boundary is reached, execute the Worktree Decision immediately.
- Create/resume the required Worker yourself, send the Worker Contract, wait for completion, verify commit/status/tests/scope, then loop again.
- Other Workers report only to you.
- Do not ask the user to create Worktrees, copy prompts, or relay Worker output.
- Stop and communicate with the user only for a required Human Gate/product decision, a real blocker, or completion of the current coordination objective.
- You still may not directly modify project files or self-approve any Gate.
- Revalidate the frozen C/R/P/Profile, risk/test/evidence/stop mapping, coverage matrix, and resource budget before dispatch or review; stop on uncertainty or overrun.
- Use a fourth Review Worktree only when required Review lacks proven fresh-Session file-system isolation. Keep optional hardening and derived status outside the current Batch.

Begin now with RECONCILE → REFLECT → DECIDE and continue the closed loop.
"@
}

function Get-ModeTransitionPrompt {
    param(
        [string]$ProjectRoot,
        [string]$FromMode,
        [string]$ToMode
    )

    $modelPath = Join-Path $ProjectRoot 'gad-lead\GAD_LEAD_OPERATING_MODEL.md'

    if ($ToMode -eq 'bootstrap') {
        return @"
GAD Lead MODE TRANSITION

From: $FromMode
To: bootstrap

主线项目：
$ProjectRoot

立即重新读取：
$modelPath

按照其中 Bootstrap Mode 和 Recovery Protocol 工作。

本次 Bootstrap 的首要目标：
- 如果这是已有 ACTIVE 项目：为“正式采用 GAD Lead”准备独立的项目级治理变更，不触碰当前 Delivery Batch；
- 如果这是新 IDEA 项目：通过 GAD Lead 协调 Project Inception / Architecture / Governance，建立正式项目基线。

Bootstrap 模式允许编排治理类 Worker，但禁止启动产品实现、当前 Batch Rework、Review、Integration、Promotion。
你仍不得直接修改项目文件，不得自我批准任何 Gate。
所有需要用户介入的内容都由你整理成 Decision Package。
先 RECONCILE → REFLECT → DECIDE，再采取任何编排动作。
"@
    }

    if ($ToMode -eq 'active') {
        return @"
GAD Lead MODE TRANSITION

From: $FromMode
To: active

主线项目：
$ProjectRoot

主线正式规则已经允许 Active Mode。
立即重新读取：
$modelPath

重新执行 RECONCILE → REFLECT → DECIDE，
然后按照 Active Mode 继续日常协调。
不得直接修改项目文件，不得自我批准 Gate。
"@
    }

    return @"
GAD Lead MODE TRANSITION

From: $FromMode
To: shadow

主线项目：
$ProjectRoot

立即重新读取：
$modelPath

进入只读 Shadow Mode。
只允许 RECONCILE → REFLECT → DECIDE；
不得创建或恢复 Worker、不得发送任务、不得修改文件、不得推进 Gate。
"@
}

function Transition-LeadMode {
    param(
        [string]$ProjectRoot,
        [string]$TargetMode,
        [bool]$Activate,
        [bool]$DryRun
    )

    if ($TargetMode -eq 'active' -and -not (Test-ActiveApproved -ProjectRoot $ProjectRoot)) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = "Active Mode is not approved. Add '$script:ActiveApprovalMarker' through formal project governance."
        }
    }

    $current = Get-OrcaCurrentWorktree -ProjectRoot $ProjectRoot
    $worktrees = @(Get-OrcaWorktrees -ProjectRoot $ProjectRoot)

    $repoId = Get-PropertyValue -Object $current -Name 'repoId'
    if (-not $repoId) {
        $currentId = Get-PropertyValue -Object $current -Name 'id'
        if ($currentId -and ([string]$currentId).Contains('::')) {
            $repoId = ([string]$currentId).Split('::')[0]
        }
    }

    $leads = @(Get-GadLeadWorktrees -Worktrees $worktrees -RepoId $repoId)

    if ($leads.Count -ne 1) {
        return [pscustomobject]@{
            ok = $false
            conflict = $true
            exitCode = 3
            message = "Mode transition requires exactly one gad-lead Worktree. Found $($leads.Count)."
            worktrees = $leads
        }
    }

    $lead = $leads[0]
    $terminals = @(Get-OrcaTerminals -ProjectRoot $ProjectRoot -WorktreeId $lead.id)
    $leadTerminals = @(Get-GadLeadTerminals -Terminals $terminals)
    $live = @($leadTerminals | Where-Object { Test-TerminalLive -Terminal $_ })
    $orphaned = @($live | Where-Object { Test-TerminalOrphaned -Terminal $_ })

    if ($orphaned.Count -gt 0) {
        return [pscustomobject]@{
            ok = $false
            conflict = $true
            exitCode = 3
            message = 'An orphaned live GAD Lead terminal exists. Resolve it before transition.'
            terminals = $orphaned
        }
    }

    if ($live.Count -ne 1) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = "Mode transition requires exactly one live GAD Lead terminal. Found $($live.Count). Use resume if none exists."
            terminals = $live
        }
    }

    $terminal = $live[0]
    $handle = Find-FirstPropertyValue -Object $terminal -Names @('handle', 'terminalHandle')
    $title = Get-TerminalTitle -Terminal $terminal

    if ($title -notmatch '^GAD Lead \[(shadow|bootstrap|active)\]$') {
        return [pscustomobject]@{
            ok = $false
            conflict = $true
            exitCode = 3
            message = "Unable to determine current GAD Lead mode from terminal title: $title"
        }
    }

    $fromMode = $Matches[1]

    if ($fromMode -eq $TargetMode) {
        if ($Activate -and $handle -and -not $DryRun) {
            [void](Invoke-OrcaJson -Arguments @(
                'terminal', 'switch',
                '--terminal', [string]$handle,
                '--json'
            ) -WorkingDirectory $ProjectRoot)
        }

        return [pscustomobject]@{
            ok = $true
            exitCode = 0
            action = 'no-op'
            fromMode = $fromMode
            toMode = $TargetMode
            terminalHandle = $handle
            dryRun = $DryRun
        }
    }

    $allowed = (
        ($fromMode -eq 'shadow' -and $TargetMode -eq 'bootstrap') -or
        ($fromMode -eq 'bootstrap' -and $TargetMode -eq 'active') -or
        ($TargetMode -eq 'shadow')
    )

    if (-not $allowed) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = "Unsupported mode transition: $fromMode -> $TargetMode. Supported forward path is shadow -> bootstrap -> active."
        }
    }

    if ($DryRun) {
        return [pscustomobject]@{
            ok = $true
            exitCode = 0
            action = 'transition'
            fromMode = $fromMode
            toMode = $TargetMode
            terminalHandle = $handle
            dryRun = $true
        }
    }

    $wait = Invoke-OrcaJson -Arguments @(
        'terminal', 'wait',
        '--terminal', [string]$handle,
        '--for', 'tui-idle',
        '--timeout-ms', '60000',
        '--json'
    ) -WorkingDirectory $ProjectRoot

    $satisfied = Find-FirstPropertyValue -Object $wait -Names @('satisfied')
    if ($satisfied -ne $true) {
        $wait = Invoke-OrcaJson -Arguments @(
            'terminal', 'wait',
            '--terminal', [string]$handle,
            '--for', 'tui-idle',
            '--timeout-ms', '180000',
            '--json'
        ) -WorkingDirectory $ProjectRoot
        $satisfied = Find-FirstPropertyValue -Object $wait -Names @('satisfied')
    }

    if ($satisfied -ne $true) {
        throw 'GAD Lead terminal did not reach tui-idle; mode transition was not sent.'
    }

    $prompt = Get-ModeTransitionPrompt `
        -ProjectRoot $ProjectRoot `
        -FromMode $fromMode `
        -ToMode $TargetMode

    $sent = Invoke-OrcaJson -Arguments @(
        'terminal', 'send',
        '--terminal', [string]$handle,
        '--text', $prompt,
        '--enter',
        '--wait-submit', '10',
        '--json'
    ) -WorkingDirectory $ProjectRoot

    $accepted = Find-FirstPropertyValue -Object $sent -Names @('accepted')
    if ($accepted -ne $true) {
        throw 'GAD Lead mode-transition prompt was not confirmed as accepted.'
    }

    [void](Invoke-OrcaJson -Arguments @(
        'terminal', 'rename',
        '--terminal', [string]$handle,
        '--title', "GAD Lead [$TargetMode]",
        '--json'
    ) -WorkingDirectory $ProjectRoot)

    if ($Activate) {
        [void](Invoke-OrcaJson -Arguments @(
            'terminal', 'switch',
            '--terminal', [string]$handle,
            '--json'
        ) -WorkingDirectory $ProjectRoot)
    }

    return [pscustomobject]@{
        ok = $true
        exitCode = 0
        action = 'transition'
        fromMode = $fromMode
        toMode = $TargetMode
        terminalHandle = $handle
        dryRun = $false
    }
}

function Get-StatusObject {
    param([string]$ProjectRoot)

    $main = Get-MainlineFacts -ProjectRoot $ProjectRoot
    $current = Get-OrcaCurrentWorktree -ProjectRoot $ProjectRoot
    $worktrees = @(Get-OrcaWorktrees -ProjectRoot $ProjectRoot)
    $repoId = Get-PropertyValue -Object $current -Name 'repoId'
    if (-not $repoId) {
        $currentId = Get-PropertyValue -Object $current -Name 'id'
        if ($currentId -and ([string]$currentId).Contains('::')) {
            $repoId = ([string]$currentId).Split('::')[0]
        }
    }
    $leads = @(Get-GadLeadWorktrees -Worktrees $worktrees -RepoId $repoId)

    $leadDetails = @()
    foreach ($lead in $leads) {
        $terminals = @()
        try { $terminals = @(Get-OrcaTerminals -ProjectRoot $ProjectRoot -WorktreeId $lead.id) } catch {}
        $leadTerminals = @(Get-GadLeadTerminals -Terminals $terminals)
        $liveLeadTerminals = @($leadTerminals | Where-Object { Test-TerminalLive -Terminal $_ })
        $orphanedLeadTerminals = @($liveLeadTerminals | Where-Object { Test-TerminalOrphaned -Terminal $_ })
        $leadDetails += [pscustomobject]@{
            id = $lead.id
            path = $lead.path
            branch = $lead.branch
            head = $lead.head
            parentWorktreeId = $lead.parentWorktreeId
            terminalCount = $terminals.Count
            gadLeadTerminalCount = $leadTerminals.Count
            liveGadLeadTerminalCount = $liveLeadTerminals.Count
            orphanedGadLeadTerminalCount = $orphanedLeadTerminals.Count
            terminals = $terminals
        }
    }

    return [pscustomobject]@{
        version = $script:GadLeadVersion
        project = $main
        orcaMain = $current
        projectStatus = Get-ProjectStatusText -ProjectRoot $ProjectRoot
        worktreeCount = $worktrees.Count
        worktrees = $worktrees
        gadLeadCount = $leads.Count
        gadLeads = $leadDetails
        activeModeApproved = Test-ActiveApproved -ProjectRoot $ProjectRoot
        agentPolicy = Get-AgentPolicy -ProjectRoot $ProjectRoot
        agentResolution = [pscustomobject]@{
            lead = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role 'lead'
            implementation = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role 'implementation'
            review = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role 'review'
            other = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role 'other'
        }
    }
}

function Write-HumanStatus {
    param($Status)
    Write-Output "GAD Lead $($Status.version)"
    Write-Output "Project : $($Status.project.Path)"
    Write-Output "Branch  : $($Status.project.Branch)"
    Write-Output "HEAD    : $($Status.project.Head)"
    Write-Output "Lead(s) : $($Status.gadLeadCount)"
    foreach ($lead in $Status.gadLeads) {
        Write-Output "  - $($lead.path)"
        Write-Output "    branch=$($lead.branch) head=$($lead.head) terminals=$($lead.terminalCount) gadLeadLive=$($lead.liveGadLeadTerminalCount) orphaned=$($lead.orphanedGadLeadTerminalCount)"
    }
    Write-Output "Active mode approved: $($Status.activeModeApproved)"
    Write-Output "Agent policy: lead=$($Status.agentPolicy.values.lead) implementation=$($Status.agentPolicy.values.implementation) review=$($Status.agentPolicy.values.review) other=$($Status.agentPolicy.values.other)"
    Write-Output "Resolved agents: lead=$($Status.agentResolution.lead.resolvedAgent) implementation=$($Status.agentResolution.implementation.resolvedAgent) review=$($Status.agentResolution.review.resolvedAgent) other=$($Status.agentResolution.other.resolvedAgent)"
    Write-Output ""
    Write-Output "Orca Worktrees:"
    foreach ($worktree in @($Status.worktrees | Sort-Object displayName, path)) {
        Write-Output ("  - {0}" -f $worktree.displayName)
        Write-Output ("    path={0}" -f $worktree.path)
        Write-Output ("    branch={0} head={1}" -f $worktree.branch, $worktree.head)
        Write-Output ("    parent={0}" -f $worktree.parentWorktreeId)
    }
    if ($Status.projectStatus) {
        Write-Output ""
        Write-Output "PROJECT_STATUS.md:"
        Write-Output $Status.projectStatus.TrimEnd()
    }
}

function Complete {
    param(
        $Data,
        [bool]$AsJson,
        [int]$ExitCode = 0
    )
    if ($AsJson) {
        Write-Output ($Data | ConvertTo-Json -Depth 32 -Compress)
    }
    elseif ($Data -is [string]) {
        Write-Output $Data
    }
    else {
        $Data | Format-List | Out-String | Write-Output
    }
    exit $ExitCode
}

function Show-Help {
    return @'
GAD Lead 0.4.0

Usage:
  gad-lead\gad-lead.cmd <command> [options]

Commands:
  start      Create or idempotently resume GAD Lead
  resume     Resume an existing gad-lead Worktree
  transition Transition the existing live GAD Lead mode
  status     Show project / Worktree / Terminal state
  agent      Resolve one role's Agent Preference (primarily for GAD Lead itself)
  scenario   Execute one bounded S1/S2/S3 behavior and retain content-addressed Evidence
  doctor     Read-only prerequisite and conflict checks
  help       Show this help
  version    Show version

Options:
  --project <path>
  --mode shadow|bootstrap|active
  --activate
  --dry-run
  --json
  --strict          doctor only
  --role <role>     agent only: lead|implementation|review|other (other for all unlisted roles)
  --preference <id> agent only: one-time explicit preference; invalid/unavailable falls back to Orca Default
  --input <path>     scenario only: exact JSON fixture or controlled input
  --evidence-root <path> scenario only: test override; default is shared git-common-dir/gad-evidence

Examples:
  .\gad-lead\gad-lead.cmd doctor
  .\gad-lead\gad-lead.cmd agent --role implementation --json
  .\gad-lead\gad-lead.cmd start --mode shadow --activate
  .\gad-lead\gad-lead.cmd transition --mode bootstrap --activate
  .\gad-lead\gad-lead.cmd status --json
  .\gad-lead\gad-lead.cmd transition --mode active --activate
'@
}

function Invoke-Doctor {
    param(
        [string]$ProjectRoot,
        [bool]$Strict
    )

    $checks = @()
    $errors = 0
    $warnings = 0

    foreach ($command in @('git', 'orca')) {
        $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
        $checks += [pscustomobject]@{ name = "command:$command"; status = $(if ($exists) { 'pass' } else { 'fail' }); detail = '' }
        if (-not $exists) { $errors++ }
    }

    foreach ($file in @(
        'gad-lead\README.md',
        'gad-lead\GAD_LEAD_OPERATING_MODEL.md',
        'gad-lead\GAD_AGENT_POLICY.conf',
        'gad-lead\gad-lead.cmd',
        'gad-lead\tools\gad-lead.ps1'
    )) {
        $exists = Test-Path -LiteralPath (Join-Path $ProjectRoot $file) -PathType Leaf
        $checks += [pscustomobject]@{ name = "file:$file"; status = $(if ($exists) { 'pass' } else { 'fail' }); detail = '' }
        if (-not $exists) { $errors++ }
    }

    foreach ($skill in $script:RequiredSkills) {
        $path = Join-Path $ProjectRoot ".agents\skills\$skill\SKILL.md"
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $checks += [pscustomobject]@{ name = "skill:$skill"; status = $(if ($exists) { 'pass' } else { 'fail' }); detail = $path }
        if (-not $exists) { $errors++ }
    }

    foreach ($controlled in @(
        'PROJECT.md',
        'ARCHITECTURE.md',
        'PROJECT_RULES.md',
        'DEVELOPMENT_WORKFLOW.md',
        'PROJECT_STATUS.md'
    )) {
        $path = Join-Path $ProjectRoot $controlled
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        if ($exists) {
            $checks += [pscustomobject]@{ name = "controlled:$controlled"; status = 'pass'; detail = $path }
        }
        else {
            $checks += [pscustomobject]@{ name = "controlled:$controlled"; status = 'warn'; detail = 'May be valid for a new IDEA-stage project.' }
            $warnings++
        }
    }

    $status = $null
    if ($errors -eq 0) {
        try {
            $status = Get-StatusObject -ProjectRoot $ProjectRoot
            if ($status.gadLeadCount -gt 1) {
                $checks += [pscustomobject]@{ name = 'single-gad-lead'; status = 'fail'; detail = "Found $($status.gadLeadCount)" }
                $errors++
            }
            else {
                $checks += [pscustomobject]@{ name = 'single-gad-lead'; status = 'pass'; detail = "Found $($status.gadLeadCount)" }
            }

            $liveLeadSessions = @()
            $orphanedLeadSessions = @()
            foreach ($lead in @($status.gadLeads)) {
                if ($lead.liveGadLeadTerminalCount -gt 0) { $liveLeadSessions += $lead }
                if ($lead.orphanedGadLeadTerminalCount -gt 0) { $orphanedLeadSessions += $lead }
            }

            if ($liveLeadSessions.Count -gt 1 -or ($liveLeadSessions.Count -eq 1 -and $liveLeadSessions[0].liveGadLeadTerminalCount -gt 1)) {
                $checks += [pscustomobject]@{ name = 'single-live-gad-lead-session'; status = 'fail'; detail = 'More than one live GAD Lead terminal found.' }
                $errors++
            }
            else {
                $checks += [pscustomobject]@{ name = 'single-live-gad-lead-session'; status = 'pass'; detail = "Live session groups: $($liveLeadSessions.Count)" }
            }

            if ($orphanedLeadSessions.Count -gt 0) {
                $checks += [pscustomobject]@{ name = 'gad-lead-orphaned-terminal'; status = 'fail'; detail = 'An orphaned live GAD Lead terminal exists; resolve it manually before starting another.' }
                $errors++
            }
            else {
                $checks += [pscustomobject]@{ name = 'gad-lead-orphaned-terminal'; status = 'pass'; detail = '' }
            }

            if (-not $status.activeModeApproved) {
                $checks += [pscustomobject]@{ name = 'active-mode-approval'; status = 'warn'; detail = $script:ActiveApprovalMarker }
                $warnings++
            }
            else {
                $checks += [pscustomobject]@{ name = 'active-mode-approval'; status = 'pass'; detail = '' }
            }
        }
        catch {
            $checks += [pscustomobject]@{ name = 'orca-project-state'; status = 'fail'; detail = $_.Exception.Message }
            $errors++
        }
    }

    if ($errors -eq 0) {
        foreach ($role in @('lead','implementation','review','other')) {
            $resolution = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role $role
            if ($resolution.resolvedAgent) {
                $detail = "configured=$($resolution.configuredPreference) resolved=$($resolution.resolvedAgent) source=$($resolution.resolutionSource)"
                if ($resolution.fallback -and $resolution.fallbackReason -ne 'system-default-requested') {
                    $checks += [pscustomobject]@{ name = "agent-policy:$role"; status = 'warn'; detail = "$detail fallback=$($resolution.fallbackReason)" }
                    $warnings++
                }
                else {
                    $checks += [pscustomobject]@{ name = "agent-policy:$role"; status = 'pass'; detail = $detail }
                }
            }
            else {
                $checks += [pscustomobject]@{ name = "agent-policy:$role"; status = 'warn'; detail = "configured=$($resolution.configuredPreference) resolved=ORCA_DEFAULT_UNRESOLVED" }
                $warnings++
            }
        }
    }

    $exit = 0
    if ($errors -gt 0) { $exit = 1 }
    elseif ($Strict -and $warnings -gt 0) { $exit = 1 }

    return [pscustomobject]@{
        version = $script:GadLeadVersion
        project = $ProjectRoot
        errors = $errors
        warnings = $warnings
        checks = $checks
        status = $status
        exitCode = $exit
    }
}

function Start-Or-ResumeLead {
    param(
        [string]$ProjectRoot,
        [string]$Mode,
        [bool]$ResumeOnly,
        [bool]$Activate,
        [bool]$DryRun
    )

    if ($Mode -eq 'active' -and -not (Test-ActiveApproved -ProjectRoot $ProjectRoot)) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = "Active Mode is not approved. Add '$script:ActiveApprovalMarker' through formal project governance."
        }
    }

    $agentResolution = Resolve-GadAgentPreference -ProjectRoot $ProjectRoot -Role 'lead'
    if (-not $agentResolution.resolvedAgent) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = 'GAD Lead Agent Preference could not resolve a concrete enabled Orca Default Agent. Set a concrete Default Agent in Orca Settings or a valid lead preference.'
            agentResolution = $agentResolution
        }
    }

    $modelPath = Join-Path $ProjectRoot 'gad-lead\GAD_LEAD_OPERATING_MODEL.md'
    if (-not (Test-Path -LiteralPath $modelPath -PathType Leaf)) {
        throw "Missing Operating Model: $modelPath"
    }

    $current = Get-OrcaCurrentWorktree -ProjectRoot $ProjectRoot
    $worktrees = @(Get-OrcaWorktrees -ProjectRoot $ProjectRoot)
    $repoId = Get-PropertyValue -Object $current -Name 'repoId'
    if (-not $repoId) {
        $currentId = Get-PropertyValue -Object $current -Name 'id'
        if ($currentId -and ([string]$currentId).Contains('::')) {
            $repoId = ([string]$currentId).Split('::')[0]
        }
    }
    $leads = @(Get-GadLeadWorktrees -Worktrees $worktrees -RepoId $repoId)

    if ($leads.Count -gt 1) {
        return [pscustomobject]@{
            ok = $false
            conflict = $true
            exitCode = 3
            message = "Multiple gad-lead Worktrees found. Run doctor and resolve manually."
            worktrees = $leads
        }
    }

    $prompt = Get-LeadPrompt -ProjectRoot $ProjectRoot -Mode $Mode

    if ($leads.Count -eq 1) {
        $lead = $leads[0]
        $terminals = @(Get-OrcaTerminals -ProjectRoot $ProjectRoot -WorktreeId $lead.id)
        $leadTerminals = @(Get-GadLeadTerminals -Terminals $terminals)
        $liveLeadTerminals = @($leadTerminals | Where-Object { Test-TerminalLive -Terminal $_ })
        $orphaned = @($liveLeadTerminals | Where-Object { Test-TerminalOrphaned -Terminal $_ })

        if ($orphaned.Count -gt 0) {
            return [pscustomobject]@{
                ok = $false
                conflict = $true
                exitCode = 3
                message = 'An orphaned live GAD Lead terminal exists. Resolve it manually before creating or resuming another GAD Lead session.'
                worktree = $lead
                terminals = $orphaned
            }
        }

        if ($liveLeadTerminals.Count -gt 1) {
            return [pscustomobject]@{
                ok = $false
                conflict = $true
                exitCode = 3
                message = 'Multiple live GAD Lead terminals found in the gad-lead Worktree.'
                worktree = $lead
                terminals = $liveLeadTerminals
            }
        }

        if ($liveLeadTerminals.Count -eq 1) {
            $terminal = $liveLeadTerminals[0]
            $handle = Find-FirstPropertyValue -Object $terminal -Names @('handle', 'terminalHandle')
            $title = Get-TerminalTitle -Terminal $terminal
            $expectedTitle = "GAD Lead [$Mode]"

            if ($title -ne $expectedTitle) {
                return [pscustomobject]@{
                    ok = $false
                    blocked = $true
                    exitCode = 2
                    message = 'A live GAD Lead session already exists in a different mode. Finish or close it before changing mode.'
                    existingTitle = $title
                    requestedTitle = $expectedTitle
                    worktree = $lead
                    terminalHandle = $handle
                }
            }

            if ($Activate -and $handle -and -not $DryRun) {
                [void](Invoke-OrcaJson -Arguments @(
                    'terminal', 'switch',
                    '--terminal', [string]$handle,
                    '--json'
                ) -WorkingDirectory $ProjectRoot)
            }

            # resume = wake an idle existing GAD Lead and continue the coordinator loop.
            # start = idempotent visibility only; never inject duplicate instructions.
            if ($ResumeOnly -and -not $DryRun) {
                $wait = Invoke-OrcaJson -Arguments @(
                    'terminal', 'wait',
                    '--terminal', [string]$handle,
                    '--for', 'tui-idle',
                    '--timeout-ms', '2500',
                    '--json'
                ) -WorkingDirectory $ProjectRoot

                $satisfied = Find-FirstPropertyValue -Object $wait -Names @('satisfied')

                if ($satisfied -eq $true) {
                    $continuePrompt = Get-ContinuationPrompt `
                        -ProjectRoot $ProjectRoot `
                        -Mode $Mode

                    $sent = Invoke-OrcaJson -Arguments @(
                        'terminal', 'send',
                        '--terminal', [string]$handle,
                        '--text', $continuePrompt,
                        '--enter',
                        '--wait-submit', '10',
                        '--json'
                    ) -WorkingDirectory $ProjectRoot

                    $accepted = Find-FirstPropertyValue -Object $sent -Names @('accepted')
                    if ($accepted -ne $true) {
                        return [pscustomobject]@{
                            ok = $false
                            blocked = $true
                            exitCode = 2
                            action = 'existing-idle-prompt-not-accepted'
                            mode = $Mode
                            worktree = $lead
                            terminalHandle = $handle
                            terminalTitle = $title
                            message = 'Existing GAD Lead was idle, but Orca did not confirm the continuation prompt as accepted.'
                            dryRun = $false
                        }
                    }

                    return [pscustomobject]@{
                        ok = $true
                        exitCode = 0
                        action = 'continue-existing'
                        mode = $Mode
                        requestedMode = $Mode
                        worktree = $lead
                        terminalHandle = $handle
                        terminalTitle = $title
                        continuationSent = $true
                        dryRun = $false
                    }
                }

                return [pscustomobject]@{
                    ok = $true
                    exitCode = 0
                    action = 'already-running'
                    mode = $Mode
                    requestedMode = $Mode
                    worktree = $lead
                    terminalHandle = $handle
                    terminalTitle = $title
                    continuationSent = $false
                    message = 'Existing GAD Lead did not reach tui-idle during the short probe, so no duplicate continuation prompt was sent.'
                    dryRun = $false
                }
            }

            return [pscustomobject]@{
                ok = $true
                exitCode = 0
                action = 'reuse-active'
                mode = $Mode
                requestedMode = $Mode
                worktree = $lead
                terminalHandle = $handle
                terminalTitle = $title
                dryRun = $DryRun
            }
        }

        if ($DryRun) {
            return [pscustomobject]@{
                ok = $true
                exitCode = 0
                action = 'resume-existing'
                mode = $Mode
                worktree = $lead
                dryRun = $true
            }
        }

        $created = Invoke-OrcaJson -Arguments @(
            'terminal', 'create',
            '--worktree', "id:$($lead.id)",
            '--title', "GAD Lead [$Mode]",
            '--command', [string]$agentResolution.terminalCommand,
            '--json'
        ) -WorkingDirectory $ProjectRoot

        $handle = Find-FirstPropertyValue -Object $created -Names @('handle', 'terminalHandle')
        if (-not $handle) { throw "Unable to determine resumed GAD Lead terminal handle." }

        # Reveal the terminal before readiness waiting. This makes any Codex workspace-trust,
        # update, login, or startup blocker visible instead of making the launcher appear idle.
        if ($Activate) {
            [void](Invoke-OrcaJson -Arguments @(
                'terminal', 'switch',
                '--terminal', [string]$handle,
                '--json'
            ) -WorkingDirectory $ProjectRoot)
        }

        $wait = Invoke-OrcaJson -Arguments @(
            'terminal', 'wait',
            '--terminal', [string]$handle,
            '--for', 'tui-idle',
            '--timeout-ms', '60000',
            '--json'
        ) -WorkingDirectory $ProjectRoot

        $satisfied = Find-FirstPropertyValue -Object $wait -Names @('satisfied')
        if ($satisfied -ne $true) {
            $wait = Invoke-OrcaJson -Arguments @(
                'terminal', 'wait',
                '--terminal', [string]$handle,
                '--for', 'tui-idle',
                '--timeout-ms', '180000',
                '--json'
            ) -WorkingDirectory $ProjectRoot
            $satisfied = Find-FirstPropertyValue -Object $wait -Names @('satisfied')
        }

        if ($satisfied -ne $true) {
            return [pscustomobject]@{
                ok = $false
                blocked = $true
                exitCode = 2
                action = 'terminal-created-not-ready'
                mode = $Mode
                worktree = $lead
                terminalHandle = $handle
                message = 'A new GAD Lead terminal was created but did not reach tui-idle. The prompt was NOT sent. Inspect the visible terminal for workspace trust, login, update, startup, or other blocking UI; resolve it, then rerun resume.'
                dryRun = $false
            }
        }

        $sent = Invoke-OrcaJson -Arguments @(
            'terminal', 'send',
            '--terminal', [string]$handle,
            '--text', $prompt,
            '--enter',
            '--wait-submit', '10',
            '--json'
        ) -WorkingDirectory $ProjectRoot

        $accepted = Find-FirstPropertyValue -Object $sent -Names @('accepted')
        if ($accepted -ne $true) {
            return [pscustomobject]@{
                ok = $false
                blocked = $true
                exitCode = 2
                action = 'terminal-ready-prompt-not-accepted'
                mode = $Mode
                worktree = $lead
                terminalHandle = $handle
                message = 'The GAD Lead terminal reached tui-idle, but Orca did not confirm prompt acceptance. No retry was sent automatically.'
                dryRun = $false
            }
        }

        return [pscustomobject]@{
            ok = $true
            exitCode = 0
            action = 'resume-existing'
            mode = $Mode
            worktree = $lead
            terminalHandle = $handle
            agentResolution = $agentResolution
            dryRun = $false
        }
    }

    if ($ResumeOnly) {
        return [pscustomobject]@{
            ok = $false
            blocked = $true
            exitCode = 2
            message = 'No gad-lead Worktree exists. Use start.'
        }
    }

    $main = Get-MainlineFacts -ProjectRoot $ProjectRoot
    if ([string]::IsNullOrWhiteSpace($main.Head)) { throw "Unable to read mainline HEAD." }

    if ($DryRun) {
        return [pscustomobject]@{
            ok = $true
            exitCode = 0
            action = 'create'
            mode = $Mode
            baseCommit = $main.Head
            parent = $current.id
            name = $script:LeadWorktreeName
            agentResolution = $agentResolution
            dryRun = $true
        }
    }

    $arguments = @(
        'worktree', 'create',
        '--name', $script:LeadWorktreeName,
        '--base-branch', $main.Head,
        '--parent-worktree', 'active',
        '--agent', [string]$agentResolution.resolvedAgent,
        '--prompt', $prompt,
        '--setup', 'skip'
    )
    if ($Activate) { $arguments += '--activate' }
    $arguments += '--json'

    $created = Invoke-OrcaJson -Arguments $arguments -WorkingDirectory $ProjectRoot
    $worktree = $created.result.worktree
    $handle = Find-FirstPropertyValue -Object $created -Names @('agentTerminalHandle', 'startupTerminalHandle', 'handle', 'terminalHandle')
    if (-not $handle) {
        throw 'Orca created the gad-lead Worktree but did not return an agent terminal handle. Run doctor/status before retrying.'
    }
    if ($handle) {
        try {
            [void](Invoke-OrcaJson -Arguments @(
                'terminal', 'rename',
                '--terminal', [string]$handle,
                '--title', "GAD Lead [$Mode]",
                '--json'
            ) -WorkingDirectory $ProjectRoot)
        }
        catch {
            Write-Diagnostic "Warning: GAD Lead started but terminal title could not be set: $($_.Exception.Message)"
        }
    }

    return [pscustomobject]@{
        ok = $true
        exitCode = 0
        action = 'create'
        mode = $Mode
        worktree = $worktree
        terminalHandle = $handle
        agentResolution = $agentResolution
        dryRun = $false
    }
}

try {
    $options = Parse-Arguments -Tokens $args

    if ($options.Command -eq 'help') {
        Complete -Data (Show-Help) -AsJson:$options.Json -ExitCode 0
    }

    if ($options.Command -eq 'version') {
        Complete -Data ([pscustomobject]@{ name = 'GAD Lead'; version = $script:GadLeadVersion }) -AsJson:$options.Json -ExitCode 0
    }

    foreach ($required in @('git', 'orca')) {
        if (-not (Get-Command $required -ErrorAction SilentlyContinue)) {
            throw "Required command not found: $required"
        }
    }

    $projectRoot = Get-ProjectRoot -RequestedPath $options.Project

    switch ($options.Command) {
        'status' {
            $status = Get-StatusObject -ProjectRoot $projectRoot
            if ($options.Json) { Complete -Data $status -AsJson:$true -ExitCode $(if ($status.gadLeadCount -gt 1) { 3 } else { 0 }) }
            Write-HumanStatus -Status $status
            exit $(if ($status.gadLeadCount -gt 1) { 3 } else { 0 })
        }
        'doctor' {
            $doctor = Invoke-Doctor -ProjectRoot $projectRoot -Strict:$options.Strict
            if ($options.Json) { Complete -Data $doctor -AsJson:$true -ExitCode $doctor.exitCode }
            Write-Output "GAD Lead doctor: errors=$($doctor.errors) warnings=$($doctor.warnings)"
            foreach ($check in $doctor.checks) {
                Write-Output ("[{0}] {1} {2}" -f $check.status.ToUpperInvariant(), $check.name, $check.detail)
            }
            exit $doctor.exitCode
        }
        'agent' {
            $role = if ($options.Role) { $options.Role } else { 'other' }
            $result = Resolve-GadAgentPreference -ProjectRoot $projectRoot -Role $role -PreferenceOverride $options.Preference
            Complete -Data $result -AsJson:$options.Json -ExitCode 0
        }
        'scenario' {
            if (-not $options.Input) { throw 'scenario requires --input <json-file>.' }
            $scenarioTool = Join-Path $projectRoot 'gad-lead\tools\gad-scenario.ps1'
            if (-not (Test-Path -LiteralPath $scenarioTool -PathType Leaf)) { throw "Missing scenario tool: $scenarioTool" }
            $scenarioArgs = @('-Project', $projectRoot, '-InputPath', $options.Input)
            if ($options.EvidenceRoot) { $scenarioArgs += @('-EvidenceRoot', $options.EvidenceRoot) }
            $result = Invoke-Native -File 'powershell' -Arguments (@('-NoProfile', '-File', $scenarioTool) + $scenarioArgs) -WorkingDirectory $projectRoot
            if (-not [string]::IsNullOrWhiteSpace($result.Text)) { Write-Output $result.Text }
            exit $result.ExitCode
        }
        'start' {
            $result = Start-Or-ResumeLead -ProjectRoot $projectRoot -Mode $options.Mode -ResumeOnly:$false -Activate:$options.Activate -DryRun:$options.DryRun
            Complete -Data $result -AsJson:$options.Json -ExitCode $result.exitCode
        }
        'resume' {
            $result = Start-Or-ResumeLead -ProjectRoot $projectRoot -Mode $options.Mode -ResumeOnly:$true -Activate:$options.Activate -DryRun:$options.DryRun
            Complete -Data $result -AsJson:$options.Json -ExitCode $result.exitCode
        }
        'transition' {
            $result = Transition-LeadMode -ProjectRoot $projectRoot -TargetMode $options.Mode -Activate:$options.Activate -DryRun:$options.DryRun
            Complete -Data $result -AsJson:$options.Json -ExitCode $result.exitCode
        }
        default {
            throw "Unknown command '$($options.Command)'. Run help."
        }
    }
}
catch {
    Write-Diagnostic $_.Exception.Message
    if ($args -contains '--json') {
        Write-Output ([pscustomobject]@{ ok = $false; error = $_.Exception.Message; version = $script:GadLeadVersion } | ConvertTo-Json -Compress)
    }
    exit 1
}
