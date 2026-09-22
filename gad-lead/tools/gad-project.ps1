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
        # Windows PowerShell 5.1 otherwise promotes native stderr to a
        # terminating NativeCommandError under the script's Stop preference.
        $ErrorActionPreference = 'Continue'
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
    if (-not (Paths-Equal -A $Project -B $result.Text.Trim())) {
        throw "Project path must be the Git worktree root: $Project"
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

function Invoke-Git {
    param([string]$Project, [string[]]$Arguments, [string]$IndexFile)
    $previous = $env:GIT_INDEX_FILE
    try {
        if ($IndexFile) { $env:GIT_INDEX_FILE = $IndexFile }
        return Invoke-Native -File 'git' -Arguments (@('-C', $Project, '-c', 'core.quotePath=false') + $Arguments)
    }
    finally {
        if ($null -eq $previous) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
        else { $env:GIT_INDEX_FILE = $previous }
    }
}

function Assert-GitSuccess {
    param($Result, [string]$Action)
    if ($Result.ExitCode -ne 0) { throw "$Action failed: $($Result.Text)" }
    return $Result.Text.Trim()
}

function Get-GitHead {
    param([string]$Project)
    $result = Invoke-Git -Project $Project -Arguments @('rev-parse', '--verify', 'HEAD')
    if ($result.ExitCode -ne 0) { return $null }
    return $result.Text.Trim()
}

function Get-InstallManifest {
    param([string]$PackageDir, [string]$GadCore)
    $roots = @([pscustomobject]@{ source=$PackageDir; target='gad-lead' })
    foreach ($skill in $script:RequiredSkills) {
        $roots += [pscustomobject]@{
            source=(Join-Path $GadCore "skills\$skill")
            target=".agents/skills/$skill"
        }
    }
    $manifest = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root.source -PathType Container)) { throw "Source directory missing: $($root.source)" }
        foreach ($item in Get-ChildItem -LiteralPath $root.source -Recurse -Force | Sort-Object FullName) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Unsupported source link or reparse entry: $($item.FullName)"
            }
            if ($item.PSIsContainer) { continue }
            $relative = $item.FullName.Substring($root.source.Length).TrimStart('\', '/').Replace('\', '/')
            $parts = $relative.Split('/')
            if (-not $relative -or @($parts | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
                throw "Invalid source-relative path: $relative"
            }
            $target = "$($root.target)/$relative"
            if (-not $seen.Add($target)) { throw "Case-insensitive destination collision: $target" }
            $manifest += [pscustomobject]@{
                path=$target
                source=$item.FullName
                sha256=(Get-FileHashValue -Path $item.FullName)
            }
        }
    }
    return @($manifest | Sort-Object path)
}

function Get-ManagedIndexEntries {
    param([string]$Project)
    $result = Invoke-Git -Project $Project -Arguments @('ls-files', '--stage', '--', 'gad-lead', '.agents/skills')
    [void](Assert-GitSuccess -Result $result -Action 'Inspect index')
    $entries = @()
    foreach ($line in @($result.Text -split "`r?`n" | Where-Object { $_ })) {
        if ($line -notmatch '^([0-7]{6}) ([0-9a-f]{40,64}) ([0-3])\t(.*)$') { throw 'Unable to parse a managed index entry.' }
        $entries += [pscustomobject]@{ mode=$Matches[1]; oid=$Matches[2]; stage=[int]$Matches[3]; path=$Matches[4] }
    }
    return $entries
}

function Get-IndexFingerprint {
    param([string]$Project, [string]$IndexFile)
    $result = Invoke-Git -Project $Project -IndexFile $IndexFile -Arguments @('ls-files', '--stage', '--debug')
    [void](Assert-GitSuccess -Result $result -Action 'Inspect primary index')
    return $result.Text
}

function Assert-IndexPreserved {
    param([string]$Project, [string]$Before)
    if ((Get-IndexFingerprint -Project $Project) -cne $Before) { throw 'Primary index changed unexpectedly; stop and inspect before retry.' }
}

function Assert-PreexistingIndexEntries {
    param([string]$Project, [string]$Before, [string]$IndexFile)
    if ([string]::IsNullOrEmpty($Before)) { return }
    $after = Get-IndexFingerprint -Project $Project -IndexFile $IndexFile
    foreach ($record in [regex]::Split($Before, '(?m)(?=^[0-7]{6} [0-9a-f]{40,64} [0-3]\t)')) {
        if ($record -and -not $after.Contains($record.TrimEnd("`r", "`n"))) {
            throw 'A preexisting primary-index entry changed; stop and inspect before retry.'
        }
    }
}

function Get-RawBlobId {
    param([string]$Project, [string]$Path, [bool]$Write)
    $arguments = @('hash-object')
    if ($Write) { $arguments += '-w' }
    $arguments += @('--no-filters', '--', $Path)
    return Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments $arguments) -Action 'Hash manifest bytes'
}

function Get-PrimaryIndexPath {
    param([string]$Project)
    $gitDirectory = Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments @('rev-parse', '--absolute-git-dir')) -Action 'Locate Git index'
    return Join-Path $gitDirectory 'index'
}

function Prepare-RootIndex {
    param([string]$Project, [object[]]$Manifest, [string]$Before, [object[]]$ExistingEntries)
    $primary = Get-PrimaryIndexPath -Project $Project
    $candidate = Join-Path (Split-Path -Parent $primary) ('gad-project-index-' + [guid]::NewGuid().ToString('N'))
    $ready = $false
    try {
        if (Test-Path -LiteralPath $primary -PathType Leaf) {
            [System.IO.File]::Copy($primary, $candidate)
        }
        else {
            [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $candidate -Arguments @('read-tree', '--empty')) -Action 'Prepare primary index')
        }
        $existingPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($entry in $ExistingEntries) { [void]$existingPaths.Add($entry.path) }
        foreach ($entry in $Manifest) {
            $oid = Get-RawBlobId -Project $Project -Path $entry.source -Write:$false
            if (-not $existingPaths.Contains($entry.path)) {
                [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $candidate -Arguments @('update-index', '--add', '--cacheinfo', '100644', $oid, $entry.path)) -Action "Prepare primary-index entry $($entry.path)")
            }
            $indexed = Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $candidate -Arguments @('ls-files', '--stage', '--', $entry.path)) -Action 'Verify prepared index'
            if ($indexed -ne "100644 $oid 0`t$($entry.path)") {
                throw "Prepared primary index differs from manifest: $($entry.path)"
            }
        }
        Assert-PreexistingIndexEntries -Project $Project -Before $Before -IndexFile $candidate
        $ready = $true
        return $candidate
    }
    finally {
        if (-not $ready) { Remove-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue }
    }
}

function Install-RootIndex {
    param([string]$Project, [string]$Candidate)
    $primary = Get-PrimaryIndexPath -Project $Project
    if (Test-Path -LiteralPath $primary -PathType Leaf) {
        $backup = Join-Path (Split-Path -Parent $primary) ('gad-project-index-backup-' + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::Replace($Candidate, $primary, $backup)
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
    else {
        [System.IO.File]::Move($Candidate, $primary)
    }
}

function Invoke-Init {
    param($Options, [string]$Project, [string]$PackageDir, [string]$GadCore)
    $state = [ordered]@{
        ok=$false; command='init'; project=$Project; dryRun=[bool]$Options.DryRun
        phase='validate'; headBefore=$null; headAfter=$null; installed=$false
        committed=$false; rootCommitCreated=$false; commit=$null; reusedHead=$false
        commitRequired=$false; leadLaunchAttempted=$false; leadStarted=$false
        gadLeadStarted=$false; indexPreserved=$true; copied=@(); reused=@()
        conflicting=@(); manifest=@(); plannedCommit=$false; neededCommit=$false; plannedLaunch=[bool]$Options.StartLead
        nextAction=$null; error=$null; stopRequired=$false
    }
    $indexBefore = $null
    try {
        $state.headBefore = Get-GitHead -Project $Project
        $state.headAfter = $state.headBefore
        $indexBefore = Get-IndexFingerprint -Project $Project
        $manifest = @(Get-InstallManifest -PackageDir $PackageDir -GadCore $GadCore)
        $state.manifest = @($manifest | ForEach-Object { [pscustomobject]@{ path=$_.path; sha256=$_.sha256 } })
        $byPath = @{}
        foreach ($entry in $manifest) { $byPath[$entry.path] = $entry }
        if ((Get-Item -LiteralPath $PackageDir).Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw 'Package root is a link or reparse entry.' }
        foreach ($skill in $script:RequiredSkills) {
            $skillRoot = Join-Path $GadCore "skills\$skill"
            if ((Get-Item -LiteralPath $skillRoot).Attributes -band [System.IO.FileAttributes]::ReparsePoint) { throw "Skill root is a link or reparse entry: $skill" }
        }

        # Validate every destination before copying any file. Root commits reject
        # extras in the managed trees, including ignored and staged-only paths.
        $managedRoots = @('gad-lead') + @($script:RequiredSkills | ForEach-Object { ".agents/skills/$_" })
        foreach ($root in $managedRoots) {
                $directory = Join-Path $Project ($root.Replace('/', '\'))
                if (Test-Path -LiteralPath $directory) {
                    foreach ($item in Get-ChildItem -LiteralPath $directory -Recurse -Force) {
                        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unsupported destination link or reparse entry: $($item.FullName)" }
                        if ($item.PSIsContainer) { continue }
                        $relative = $item.FullName.Substring($Project.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
                        if (-not $state.headBefore -and -not $byPath.ContainsKey($relative)) { $state.conflicting += $relative }
                    }
                }
        }
        foreach ($entry in $manifest) {
            $destination = Join-Path $Project ($entry.path.Replace('/', '\'))
            if (Test-Path -LiteralPath $destination) {
                if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
                    (Get-FileHashValue -Path $destination) -ne $entry.sha256) {
                    $state.conflicting += $entry.path
                }
                else { $state.reused += $entry.path }
            }
        }
        $managedEntries = @(Get-ManagedIndexEntries -Project $Project)
        foreach ($indexed in $managedEntries) {
            $managedIndexPath = $indexed.path -eq 'gad-lead' -or $indexed.path.StartsWith('gad-lead/')
            foreach ($skill in $script:RequiredSkills) {
                if ($indexed.path.StartsWith(".agents/skills/$skill/")) { $managedIndexPath = $true }
            }
            if (-not $managedIndexPath) { continue }
            if ($indexed.stage -ne 0) { $state.conflicting += $indexed.path; continue }
            if (-not $byPath.ContainsKey($indexed.path)) {
                if (-not $state.headBefore) { $state.conflicting += $indexed.path }
                continue
            }
            $expectedOid = Get-RawBlobId -Project $Project -Path $byPath[$indexed.path].source -Write:$false
            if ($indexed.oid -ne $expectedOid) { $state.conflicting += $indexed.path }
        }
        if ($state.conflicting.Count -gt 0) {
            $state.conflicting = @($state.conflicting | Sort-Object -Unique)
            throw 'Managed destination or staged entry conflicts with the install manifest.'
        }

        $needsCommit = [bool]($Options.Commit -or ($Options.StartLead -and -not $state.headBefore))
        $state.plannedCommit = $needsCommit
        $state.neededCommit = -not [bool]$state.headBefore
        if ($state.headBefore) {
            foreach ($entry in $manifest) {
                $oid = Get-RawBlobId -Project $Project -Path $entry.source -Write:$false
                $headEntry = Invoke-Git -Project $Project -Arguments @('ls-tree', 'HEAD', '--', $entry.path)
                if ($headEntry.ExitCode -ne 0 -or $headEntry.Text -notmatch ('^100644 blob ' + [regex]::Escape($oid) + "`t")) { $state.neededCommit = $true; break }
            }
        }
        if ($Options.DryRun) {
            $state.ok = $true
            $state.nextAction = 'Run the same command without --dry-run to apply the plan.'
            return [pscustomobject]$state
        }

        $state.phase = 'copy'
        foreach ($entry in $manifest) {
            $destination = Join-Path $Project ($entry.path.Replace('/', '\'))
            if ((Get-FileHashValue -Path $entry.source) -ne $entry.sha256) { throw "Source changed during installation: $($entry.path)" }
            if (Test-Path -LiteralPath $destination -PathType Leaf) { continue }
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Force -Path $parent) }
            $partial = Join-Path $parent ('.gad-project-copy-' + [guid]::NewGuid().ToString('N'))
            try {
                [System.IO.File]::Copy($entry.source, $partial)
                if ((Get-FileHashValue -Path $partial) -ne $entry.sha256) { throw "Copied file hash mismatch: $($entry.path)" }
                [System.IO.File]::Move($partial, $destination)
            }
            finally { Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue }
            $state.copied += $entry.path
        }
        $state.installed = $true

        if ($needsCommit) {
            $state.phase = 'stage'
            $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("gad-project-index-" + [guid]::NewGuid().ToString('N'))
            $rootIndexCandidate = $null
            try {
                if ($state.headBefore) {
                    [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $temporary -Arguments @('read-tree', 'HEAD')) -Action 'Read HEAD into isolated index')
                }
                else {
                    [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $temporary -Arguments @('read-tree', '--empty')) -Action 'Initialize isolated index')
                }
                foreach ($entry in $manifest) {
                    if ((Get-FileHashValue -Path $entry.source) -ne $entry.sha256) { throw "Source changed during staging: $($entry.path)" }
                    $destination = Join-Path $Project ($entry.path.Replace('/', '\'))
                    if ((Get-FileHashValue -Path $destination) -ne $entry.sha256) { throw "Destination changed during staging: $($entry.path)" }
                    $oid = Get-RawBlobId -Project $Project -Path $entry.source -Write:$true
                    [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $temporary -Arguments @('update-index', '--add', '--cacheinfo', '100644', $oid, $entry.path)) -Action "Stage $($entry.path) in isolated index")
                }
                $tree = Assert-GitSuccess -Result (Invoke-Git -Project $Project -IndexFile $temporary -Arguments @('write-tree')) -Action 'Write isolated tree'
                foreach ($entry in $manifest) {
                    $oid = Get-RawBlobId -Project $Project -Path $entry.source -Write:$false
                    $treeEntry = Invoke-Git -Project $Project -Arguments @('ls-tree', $tree, '--', $entry.path)
                    if ($treeEntry.ExitCode -ne 0 -or $treeEntry.Text -notmatch ('^100644 blob ' + [regex]::Escape($oid) + "`t")) {
                        throw "Isolated tree differs from manifest: $($entry.path)"
                    }
                }
                if (-not $state.headBefore) {
                    $listing = Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments @('ls-tree', '-r', $tree)) -Action 'Inspect root tree'
                    $lines = @($listing -split "`r?`n" | Where-Object { $_ })
                    if ($lines.Count -ne $manifest.Count) { throw 'Isolated root tree does not contain exactly the manifest.' }
                    foreach ($line in $lines) {
                        if ($line -notmatch '^100644 blob [0-9a-f]{40,64}\t(.*)$' -or -not $byPath.ContainsKey($Matches[1])) { throw 'Isolated root tree contains an unauthorized path or mode.' }
                    }
                    $rootIndexCandidate = Prepare-RootIndex -Project $Project -Manifest $manifest -Before $indexBefore -ExistingEntries $managedEntries
                }
                $oldTree = if ($state.headBefore) { Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments @('rev-parse', 'HEAD^{tree}')) -Action 'Read HEAD tree' } else { $null }
                if ($tree -ne $oldTree) {
                    $state.phase = 'commit'
                    $commitArgs = @('commit-tree', $tree, '-m', 'chore: initialize project with GAD Lead')
                    if ($state.headBefore) { $commitArgs += @('-p', $state.headBefore) }
                    $newCommit = Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments $commitArgs) -Action 'Create isolated commit'
                    $oldRef = if ($state.headBefore) { $state.headBefore } else { '0' * 40 }
                    [void](Assert-GitSuccess -Result (Invoke-Git -Project $Project -Arguments @('update-ref', 'HEAD', $newCommit, $oldRef)) -Action 'Advance HEAD')
                    $state.headAfter = $newCommit
                    $state.commit = $newCommit
                    $state.committed = $true
                    $state.rootCommitCreated = -not [bool]$state.headBefore
                    if ($state.rootCommitCreated) {
                        try { Install-RootIndex -Project $Project -Candidate $rootIndexCandidate }
                        catch {
                            $state.stopRequired = $true
                            throw "Root HEAD advanced but primary index could not be completed. STOP; inspect retained index candidate $rootIndexCandidate. $($_.Exception.Message)"
                        }
                    }
                }
                else { $state.reusedHead = $true }
            }
            finally {
                Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
                if ($rootIndexCandidate -and -not $state.stopRequired) {
                    Remove-Item -LiteralPath $rootIndexCandidate -Force -ErrorAction SilentlyContinue
                }
            }
        }
        else { $state.reusedHead = [bool]$state.headBefore }

        if ($state.rootCommitCreated) { Assert-PreexistingIndexEntries -Project $Project -Before $indexBefore -IndexFile $null }
        else { Assert-IndexPreserved -Project $Project -Before $indexBefore }
        if ($Options.StartLead) {
            $state.phase = 'launch'
            if (-not $state.headAfter) { throw 'Cannot launch GAD Lead without a Git HEAD.' }
            if (-not $needsCommit) {
                foreach ($entry in $manifest) {
                    $show = Invoke-Git -Project $Project -Arguments @('ls-tree', '-r', 'HEAD', '--', $entry.path)
                    $oid = Get-RawBlobId -Project $Project -Path $entry.source -Write:$false
                    if ($show.ExitCode -ne 0 -or $show.Text -notmatch ('^100644 blob ' + [regex]::Escape($oid) + "`t")) {
                        $state.commitRequired = $true
                        throw 'Existing HEAD does not contain the exact installed manifest; rerun with --commit.'
                    }
                }
            }
            $state.leadLaunchAttempted = $true
            $launcher = Join-Path $Project 'gad-lead\gad-lead.cmd'
            $lead = Invoke-Native -File $launcher -Arguments @('start', '--mode', $Options.Mode, '--project', $Project, '--activate') -WorkingDirectory $Project
            [void](Assert-GitSuccess -Result $lead -Action 'GAD Lead start')
            $state.leadStarted = $true
            $state.gadLeadStarted = $true
        }
        $state.ok = $true
        $state.nextAction = if (-not $state.headAfter) { 'Run init --commit or init --start-lead --mode bootstrap to create the root commit.' } else { 'Installation complete.' }
    }
    catch {
        $state.error = $_.Exception.Message
        $state.nextAction = if ($state.stopRequired) {
            'STOP: preserve the repository and retained index candidate for manual inspection; do not retry automatically.'
        } elseif ($state.commitRequired) {
            'Rerun init with --commit --start-lead --mode bootstrap.'
        } elseif ($state.phase -eq 'commit' -and $state.error -match 'identity|ident name|auto-detect email|user\.name|user\.email') {
            'Configure Git user.name and user.email for this repository, then retry the same command.'
        } elseif ($state.phase -eq 'launch') {
            'Repair the Orca or Agent launch prerequisite and retry; the completed commit is retained.'
        } else {
            'Repair the reported conflict or prerequisite and retry the same command.'
        }
        $state.headAfter = Get-GitHead -Project $Project
        if ($null -ne $indexBefore) {
            try {
                if ($state.rootCommitCreated) {
                    Assert-PreexistingIndexEntries -Project $Project -Before $indexBefore -IndexFile $null
                    $state.indexPreserved = $true
                }
                else { $state.indexPreserved = ((Get-IndexFingerprint -Project $Project) -ceq $indexBefore) }
            }
            catch { $state.indexPreserved = $false }
        }
    }
    return [pscustomobject]$state
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

    if ($options.Command -eq 'init') {
        if ($options.StartLead -and $options.Mode -ne 'bootstrap') {
            throw 'Only --mode bootstrap is approved for init --start-lead.'
        }
        $result = Invoke-Init -Options $options -Project $project -PackageDir $packageDir -GadCore $gadCore
        Complete -Data $result -Json:$options.Json -Code $(if ($result.ok) { 0 } else { 1 })
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
        $failureProject = $null
        $failureHead = $null
        if ($null -ne (Get-Variable options -ErrorAction SilentlyContinue) -and $options.Project) {
            $failureProject = [System.IO.Path]::GetFullPath($options.Project)
            if (Test-Path -LiteralPath $failureProject -PathType Container) {
                try { $failureHead = Get-GitHead -Project $failureProject } catch { }
            }
        }
        Write-Output ([pscustomobject]@{
            ok = $false
            error = $_.Exception.Message
            version = $script:GadProjectVersion
            phase = 'validate'
            project = $failureProject
            headBefore = $failureHead
            headAfter = $failureHead
            rootCommitCreated = $false
            copied = @()
            reused = @()
            conflicting = @()
            indexPreserved = $true
            leadLaunchAttempted = $false
            leadStarted = $false
            nextAction = 'Correct the reported input or prerequisite and retry.'
        } | ConvertTo-Json -Compress)
    }

    exit 1
}
