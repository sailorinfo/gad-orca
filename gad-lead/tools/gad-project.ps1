#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GadProjectVersion = '0.4.0'
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
    param([string[]]$Tokens, [ref]$Index, [string]$Name)
    if ($Index.Value + 1 -ge $Tokens.Count) { throw "Missing value for $Name." }
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
        Command = $command
        Name = $null
        Parent = $null
        Project = $null
        GadCore = $null
        Package = $null
        Commit = $false
        StartLead = $false
        Mode = 'bootstrap'
        Json = $false
        DryRun = $false
    }

    for ($i = $startAt; $i -lt $Tokens.Count; $i++) {
        $token = $Tokens[$i]

        if ($token -match '^--([^=]+)=(.*)$') {
            $name = $Matches[1].ToLowerInvariant()
            $value = $Matches[2]
            switch ($name) {
                'name' { $options.Name = $value }
                'parent' { $options.Parent = $value }
                'project' { $options.Project = $value }
                'gad-core' { $options.GadCore = $value }
                'package' { $options.Package = $value }
                'mode' { $options.Mode = $value.ToLowerInvariant() }
                default { throw "Unknown option: --$name" }
            }
            continue
        }

        switch ($token.ToLowerInvariant()) {
            '--name'       { $options.Name = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--name' }
            '--parent'     { $options.Parent = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--parent' }
            '--project'    { $options.Project = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--project' }
            '--gad-core'   { $options.GadCore = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--gad-core' }
            '--package'    { $options.Package = Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--package' }
            '--mode'       { $options.Mode = (Get-ArgValue -Tokens $Tokens -Index ([ref]$i) -Name '--mode').ToLowerInvariant() }
            '--commit'     { $options.Commit = $true }
            '--start-lead' { $options.StartLead = $true }
            '--json'       { $options.Json = $true }
            '--dry-run'    { $options.DryRun = $true }
            '--help'       { $options.Command = 'help' }
            default        { throw "Unknown argument: $token" }
        }
    }

    if ($options.Mode -notin @('shadow', 'bootstrap', 'active')) {
        throw "Invalid mode '$($options.Mode)'. Expected shadow, bootstrap or active."
    }

    return [pscustomobject]$options
}

function Invoke-Native {
    param([string]$File, [string[]]$Arguments = @(), [string]$WorkingDirectory)

    $old = $null
    try {
        if ($WorkingDirectory) {
            $old = Get-Location
            Set-Location -LiteralPath $WorkingDirectory
        }

        $lines = @(& $File @Arguments 2>&1)
        $code = $LASTEXITCODE
        $text = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

        return [pscustomobject]@{
            ExitCode = $code
            Text = $text
        }
    }
    finally {
        if ($old) { Set-Location -LiteralPath $old.Path }
    }
}

function Resolve-GadLeadPackage {
    param([string]$Requested)

    if ($Requested) {
        if (-not (Test-Path -LiteralPath $Requested -PathType Container)) {
            throw "Package path does not exist: $Requested"
        }
        $candidate = (Resolve-Path -LiteralPath $Requested).Path
    }
    else {
        $candidate = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    }

    if (Test-Path -LiteralPath (Join-Path $candidate 'GAD_LEAD_OPERATING_MODEL.md') -PathType Leaf) {
        return $candidate
    }

    $nested = Join-Path $candidate 'gad-lead'
    if (Test-Path -LiteralPath (Join-Path $nested 'GAD_LEAD_OPERATING_MODEL.md') -PathType Leaf) {
        return (Resolve-Path -LiteralPath $nested).Path
    }

    throw "Unable to identify a GAD Lead package at: $candidate"
}

function Get-GadCoreRoot {
    param([string]$Requested)

    if ($Requested) {
        if (-not (Test-Path -LiteralPath $Requested -PathType Container)) {
            throw "GAD Core path does not exist: $Requested"
        }
        return (Resolve-Path -LiteralPath $Requested).Path
    }

    if ($env:GAD_CORE_HOME -and (Test-Path -LiteralPath $env:GAD_CORE_HOME -PathType Container)) {
        return (Resolve-Path -LiteralPath $env:GAD_CORE_HOME).Path
    }

    $default = Join-Path $HOME 'gad-core'
    if (Test-Path -LiteralPath $default -PathType Container) {
        return (Resolve-Path -LiteralPath $default).Path
    }

    throw "GAD Core not found. Use --gad-core <path> or set GAD_CORE_HOME."
}

function Assert-Package {
    param([string]$PackageDir)

    foreach ($required in @(
        'README.md',
        'GAD_LEAD_OPERATING_MODEL.md',
        'GAD_AGENT_POLICY.conf',
        'gad-lead.cmd',
        'gad-project.cmd',
        'tools\gad-lead.ps1',
        'tools\gad-project.ps1'
    )) {
        $path = Join-Path $PackageDir $required
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Package file missing: $path"
        }
    }
}

function Assert-GadCore {
    param([string]$GadCore)

    foreach ($skill in $script:RequiredSkills) {
        $skillFile = Join-Path $GadCore "skills\$skill\SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            throw "Required GAD Skill missing: $skillFile"
        }
    }
}

function Get-FileHashValue {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Paths-Equal {
    param([string]$A, [string]$B)

    $aFull = [System.IO.Path]::GetFullPath($A).TrimEnd('\', '/')
    $bFull = [System.IO.Path]::GetFullPath($B).TrimEnd('\', '/')

    return [string]::Equals(
        $aFull,
        $bFull,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Copy-FileSafe {
    param([string]$Source, [string]$Destination, [bool]$DryRun)

    if (Paths-Equal -A $Source -B $Destination) {
        return 'same-path'
    }

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if ((Get-FileHashValue -Path $Source) -eq (Get-FileHashValue -Path $Destination)) {
            return 'same'
        }
        throw "Target file exists with different content: $Destination"
    }

    if (-not $DryRun) {
        $parent = Split-Path -Parent $Destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            [void](New-Item -ItemType Directory -Force -Path $parent)
        }
        Copy-Item -LiteralPath $Source -Destination $Destination
    }

    return 'copied'
}

function Copy-TreeSafe {
    param([string]$SourceRoot, [string]$DestinationRoot, [bool]$DryRun)

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        throw "Source directory missing: $SourceRoot"
    }

    if (Paths-Equal -A $SourceRoot -B $DestinationRoot) {
        return @([pscustomobject]@{
            source = $SourceRoot
            destination = $DestinationRoot
            state = 'same-path'
        })
    }

    $results = @()

    foreach ($file in Get-ChildItem -LiteralPath $SourceRoot -Recurse -File) {
        $relative = $file.FullName.Substring($SourceRoot.Length).TrimStart('\', '/')
        $destination = Join-Path $DestinationRoot $relative
        $state = Copy-FileSafe `
            -Source $file.FullName `
            -Destination $destination `
            -DryRun:$DryRun

        $results += [pscustomobject]@{
            source = $file.FullName
            destination = $destination
            state = $state
        }
    }

    return $results
}

function Resolve-NewProjectPath {
    param($Options)

    if ($Options.Project) {
        return [System.IO.Path]::GetFullPath($Options.Project)
    }

    if ([string]::IsNullOrWhiteSpace($Options.Name)) {
        throw "new requires --name or --project."
    }

    $parent = if ($Options.Parent) { $Options.Parent } else { (Get-Location).Path }
    return [System.IO.Path]::GetFullPath((Join-Path $parent $Options.Name))
}

function Assert-EmptyOrMissing {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Project path is not a directory: $Path"
    }

    if ((Get-ChildItem -LiteralPath $Path -Force | Measure-Object).Count -gt 0) {
        throw "Project directory is not empty: $Path"
    }
}

function Assert-GitProject {
    param([string]$Project)

    if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
        throw "Project path does not exist: $Project"
    }

    $result = Invoke-Native -File 'git' -Arguments @(
        '-C', $Project, 'rev-parse', '--show-toplevel'
    )

    if ($result.ExitCode -ne 0) {
        throw "Existing project is not a Git worktree: $Project"
    }
}

function Test-GitHasHead {
    param([string]$Project)

    $result = Invoke-Native -File 'git' -Arguments @(
        '-C', $Project, 'rev-parse', '--verify', 'HEAD'
    )

    return (
        $result.ExitCode -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($result.Text)
    )
}

function Install-GadLead {
    param(
        [string]$Project,
        [string]$PackageDir,
        [string]$GadCore,
        [bool]$DryRun
    )

    $operations = @()

    $destinationLead = Join-Path $Project 'gad-lead'
    $operations += [pscustomobject]@{
        item = 'gad-lead'
        results = @(
            Copy-TreeSafe `
                -SourceRoot $PackageDir `
                -DestinationRoot $destinationLead `
                -DryRun:$DryRun
        )
    }

    foreach ($skill in $script:RequiredSkills) {
        $source = Join-Path $GadCore "skills\$skill"
        $destination = Join-Path $Project ".agents\skills\$skill"

        $operations += [pscustomobject]@{
            item = ".agents\skills\$skill"
            results = @(
                Copy-TreeSafe `
                    -SourceRoot $source `
                    -DestinationRoot $destination `
                    -DryRun:$DryRun
            )
        }
    }

    return $operations
}

function Show-Help {
    return @'
GAD Project 0.4.0

Usage:
  .\gad-lead\gad-project.cmd <command> [options]

Commands:
  new       Create an empty Git project and install GAD Skills + GAD Lead
  init      Install GAD Skills + GAD Lead into an existing Git project
  doctor    Validate the GAD Lead package and GAD Core source
  help      Show help
  version   Show version

Options:
  --name <name>
  --parent <path>
  --project <path>
  --gad-core <path>
  --package <path>       Path to gad-lead/ or a parent containing gad-lead/
  --commit
  --start-lead
  --mode shadow|bootstrap|active
  --dry-run
  --json

Notes:
  - New projects use one install directory: <project>\gad-lead\
  - --start-lead for a brand-new project requires --commit because Orca needs a Git HEAD.
  - Existing files are never silently overwritten. Identical files are skipped; differing files block.

Examples:
  .\gad-lead\gad-project.cmd doctor --gad-core C:\Users\app\gad-core

  .\gad-lead\gad-project.cmd init `
    --project C:\Users\app\orca\projects\crypto-trading-workbench `
    --gad-core C:\Users\app\gad-core

  .\gad-lead\gad-project.cmd new `
    --name demo `
    --parent C:\Users\app\orca\projects `
    --gad-core C:\Users\app\gad-core `
    --commit `
    --start-lead
'@
}

function Complete {
    param($Data, [bool]$Json, [int]$Code = 0)

    if ($Json) {
        Write-Output ($Data | ConvertTo-Json -Depth 32 -Compress)
    }
    elseif ($Data -is [string]) {
        Write-Output $Data
    }
    else {
        $Data | Format-List | Out-String | Write-Output
    }

    exit $Code
}

try {
    $options = Parse-Arguments -Tokens $args

    if ($options.Command -eq 'help') {
        Complete -Data (Show-Help) -Json:$options.Json -Code 0
    }

    if ($options.Command -eq 'version') {
        Complete -Data ([pscustomobject]@{
            name = 'GAD Project'
            version = $script:GadProjectVersion
        }) -Json:$options.Json -Code 0
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Required command not found: git"
    }

    $packageDir = Resolve-GadLeadPackage -Requested $options.Package
    $gadCore = Get-GadCoreRoot -Requested $options.GadCore

    Assert-Package -PackageDir $packageDir
    Assert-GadCore -GadCore $gadCore

    if ($options.Command -eq 'doctor') {
        Complete -Data ([pscustomobject]@{
            ok = $true
            version = $script:GadProjectVersion
            package = $packageDir
            gadCore = $gadCore
            skills = $script:RequiredSkills
            layout = 'single-directory'
        }) -Json:$options.Json -Code 0
    }

    $project = $null

    if ($options.Command -eq 'new') {
        $project = Resolve-NewProjectPath -Options $options
        Assert-EmptyOrMissing -Path $project

        if ($options.StartLead -and -not $options.Commit) {
            throw "For a brand-new project, --start-lead requires --commit so the repository has a Git HEAD."
        }

        if (-not $options.DryRun) {
            [void](New-Item -ItemType Directory -Force -Path $project)
            $init = Invoke-Native -File 'git' -Arguments @(
                '-C', $project, 'init'
            )

            if ($init.ExitCode -ne 0) {
                throw "git init failed: $($init.Text)"
            }
        }
    }
    elseif ($options.Command -eq 'init') {
        if ([string]::IsNullOrWhiteSpace($options.Project)) {
            throw "init requires --project <path>."
        }

        $project = [System.IO.Path]::GetFullPath($options.Project)
        Assert-GitProject -Project $project
    }
    else {
        throw "Unknown command '$($options.Command)'. Run help."
    }

    $operations = Install-GadLead `
        -Project $project `
        -PackageDir $packageDir `
        -GadCore $gadCore `
        -DryRun:$options.DryRun

    $commitHash = $null

    if ($options.Commit -and -not $options.DryRun) {
        $add = Invoke-Native -File 'git' -Arguments @(
            '-C', $project, 'add', '--',
            '.agents/skills',
            'gad-lead'
        )

        if ($add.ExitCode -ne 0) {
            throw "git add failed: $($add.Text)"
        }

        $staged = Invoke-Native -File 'git' -Arguments @(
            '-C', $project, 'diff', '--cached', '--quiet'
        )

        if ($staged.ExitCode -eq 1) {
            $commit = Invoke-Native -File 'git' -Arguments @(
                '-C', $project,
                'commit',
                '-m', 'chore: initialize project with GAD Lead'
            )

            if ($commit.ExitCode -ne 0) {
                throw "git commit failed: $($commit.Text)"
            }

            $commitHash = (
                Invoke-Native -File 'git' -Arguments @(
                    '-C', $project, 'rev-parse', 'HEAD'
                )
            ).Text.Trim()
        }
        elseif ($staged.ExitCode -ne 0) {
            throw "Unable to inspect staged changes: $($staged.Text)"
        }
    }

    $leadStarted = $false

    if ($options.StartLead -and -not $options.DryRun) {
        if (-not (Test-GitHasHead -Project $project)) {
            throw "Cannot start GAD Lead because the project has no Git HEAD."
        }

        $launcher = Join-Path $project 'gad-lead\gad-lead.cmd'
        $leadResult = Invoke-Native `
            -File $launcher `
            -Arguments @(
                'start',
                '--mode', $options.Mode,
                '--project', $project,
                '--activate'
            ) `
            -WorkingDirectory $project

        if ($leadResult.ExitCode -ne 0) {
            throw "GAD Lead start failed: $($leadResult.Text)"
        }

        $leadStarted = $true
    }

    Complete -Data ([pscustomobject]@{
        ok = $true
        command = $options.Command
        project = $project
        package = $packageDir
        gadCore = $gadCore
        dryRun = $options.DryRun
        committed = [bool]$commitHash
        commit = $commitHash
        gadLeadStarted = $leadStarted
        operations = $operations
    }) -Json:$options.Json -Code 0
}
catch {
    Write-Diagnostic $_.Exception.Message

    if ($args -contains '--json') {
        Write-Output ([pscustomobject]@{
            ok = $false
            error = $_.Exception.Message
            version = $script:GadProjectVersion
        } | ConvertTo-Json -Compress)
    }

    exit 1
}
