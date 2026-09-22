#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$installer = Join-Path $PSScriptRoot '..\tools\gad-project.ps1'
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ("gad-bootstrap-tests-" + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $scratch)
$package = Join-Path $scratch 'source\gad-lead'
$core = Join-Path $scratch 'core'
$skills = @('gad-governance','gad-project-inception','gad-system-architecture','gad-implementation-readiness','gad-solution-research')

function Put-File([string]$Path, [string]$Text) {
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path))
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Run-Git([string]$Repo, [string[]]$Argv) {
    $result = @(& git.exe -C $Repo -c core.quotePath=false @Argv 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git repo=$Repo argv=$($Argv -join ',') failed: $($result -join ' ')" }
    return ($result -join "`n").Trim()
}
function New-Repo([string]$Name, [bool]$HasHead = $false) {
    $repo = Join-Path $scratch $Name
    [void](New-Item -ItemType Directory -Path $repo)
    [void](Run-Git -Repo $repo -Argv @('init','-q'))
    [void](Run-Git -Repo $repo -Argv @('config','user.name','Test'))
    [void](Run-Git -Repo $repo -Argv @('config','user.email','test@example.invalid'))
    if ($HasHead) {
        Put-File (Join-Path $repo 'base.txt') 'base'
        [void](Run-Git -Repo $repo -Argv @('add','base.txt'))
        [void](Run-Git -Repo $repo -Argv @('commit','-qm','base'))
    }
    return $repo
}
function Head([string]$Repo) {
    $ErrorActionPreference = 'Continue'
    $result = @(& git.exe -C $Repo rev-parse --verify HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($result -join '').Trim()
}
function IndexBytes([string]$Repo) {
    $path = Join-Path $repo '.git\index'
    if (-not (Test-Path -LiteralPath $path)) { return '<absent>' }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
function Check-InstalledIndex([string]$Repo, $Manifest) {
    foreach ($entry in $Manifest) {
        $oid = Run-Git -Repo $Repo -Argv @('hash-object','--no-filters','--',(Join-Path $Repo ($entry.path.Replace('/','\'))))
        $indexed = Run-Git -Repo $Repo -Argv @('ls-files','--stage','--',$entry.path)
        Assert ($indexed -eq "100644 $oid 0`t$($entry.path)") "Installed path missing from primary index: $($entry.path)"
    }
    $stagedInstall = Run-Git -Repo $Repo -Argv @('diff','--cached','--name-only','HEAD','--','gad-lead','.agents/skills')
    Assert (-not $stagedInstall) 'Committed install appears as a staged deletion or modification.'
    $status = Run-Git -Repo $Repo -Argv @('status','--porcelain=v1','--untracked-files=all','--','gad-lead','.agents/skills')
    foreach ($line in @($status -split "`n" | Where-Object { $_ })) {
        $path = $line.Substring(3)
        if (@($Manifest | Where-Object { $_.path -ceq $path }).Count -gt 0) {
            Assert ($line -notmatch '^(D |\?\?)') "Committed install appears staged-deleted or untracked: $path"
        }
    }
}
function Run-Init([string]$Repo, [string[]]$Flags) {
    $lines = @(& $installer init --project $Repo --package $package --gad-core $core @Flags --json)
    $code = $LASTEXITCODE
    Assert ($lines.Count -eq 1) "Expected one JSON line for $($Flags -join ' '): $($lines -join ' ')"
    return [pscustomobject]@{ code=$code; data=($lines[0] | ConvertFrom-Json) }
}
function Check-Root([string]$Repo, $Manifest) {
    $head = Head $Repo
    Assert ([bool]$head) 'Root HEAD missing.'
    Assert (-not (Run-Git -Repo $Repo -Argv @('log','-1','--format=%P'))) 'Root commit has a parent.'
    $listing = Run-Git -Repo $Repo -Argv @('ls-tree','-r','--name-only','HEAD')
    $actual = @($listing -split "`n" | Where-Object { $_ })
    $expected = @($Manifest | ForEach-Object { $_.path })
    Assert ($actual.Count -eq $expected.Count) 'Root tree path count differs from manifest.'
    foreach ($entry in $Manifest) {
        Assert ($actual -contains $entry.path) "Missing root path $($entry.path)"
        $mode = Run-Git -Repo $Repo -Argv @('ls-tree','HEAD','--',$entry.path)
        Assert ($mode -match '^100644 blob ') "Incorrect root mode: $($entry.path)"
        $blob = ($mode -split ' ')[2].Split("`t")[0]
        $path = Join-Path $Repo ($entry.path.Replace('/','\'))
        Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $entry.sha256) "Worktree byte mismatch: $($entry.path)"
        $oid = Run-Git -Repo $Repo -Argv @('hash-object','--no-filters','--',$path)
        Assert ($oid -eq $blob) "Tree blob mismatch: $($entry.path)"
    }
}

foreach ($file in @('README.md','GAD_LEAD_OPERATING_MODEL.md','GAD_AGENT_POLICY.conf','gad-project.cmd','tools\gad-lead.ps1','tools\gad-project.ps1')) {
    Put-File (Join-Path $package $file) "fixture $file"
}
Put-File (Join-Path $package 'gad-lead.cmd') ("@echo off`r`nexit /b 17`r`n")
Put-File (Join-Path $package 'gad-project.cmd') ("@echo off`r`nexit /b 0`r`n")
Put-File (Join-Path $package '.hidden') 'hidden payload'
Put-File (Join-Path $package "$([char]0x8BF4)$([char]0x660E).txt") 'unicode payload'
foreach ($skill in $skills) { Put-File (Join-Path $core "skills\$skill\SKILL.md") "skill $skill" }

$count = 0
try {
    $repo = New-Repo 'nohead-install'
    $before = IndexBytes $repo
    $run = Run-Init $repo @()
    Assert ($run.code -eq 0 -and $run.data.installed -and -not $run.data.committed -and -not (Head $repo)) 'No-HEAD init row failed.'
    Assert ((IndexBytes $repo) -eq $before) 'No-HEAD init changed index.'
    $count++

    $repo = New-Repo 'nohead-dry'
    [void](Run-Git -Repo $repo -Argv @('config','user.name',' '))
    [void](Run-Git -Repo $repo -Argv @('config','user.email',' '))
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--dry-run','--start-lead','--mode','bootstrap')
    Assert ($run.code -eq 0 -and $run.data.neededCommit -and $run.data.plannedLaunch -and -not $run.data.installed -and -not (Head $repo)) 'No-HEAD dry-run row failed.'
    Assert ((IndexBytes $repo) -eq $before -and -not (Test-Path (Join-Path $repo 'gad-lead'))) 'Dry run mutated repository.'
    $count++

    $repo = New-Repo 'nohead-commit'
    [void](Run-Git -Repo $repo -Argv @('config','core.autocrlf','true'))
    Put-File (Join-Path $repo 'outside.txt') 'staged user file'
    [void](Run-Git -Repo $repo -Argv @('add','outside.txt'))
    Put-File (Join-Path $repo 'ignored.txt') 'ignored user file'
    Put-File (Join-Path $repo '.gitignore') "ignored.txt`ngad-lead/`n.agents/`n"
    Put-File (Join-Path $repo '.agents\skills\unmanaged\keep.txt') 'outside managed roots'
    $before = IndexBytes $repo
    $outsideBefore = Run-Git -Repo $repo -Argv @('ls-files','--stage','--','outside.txt')
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -eq 0 -and $run.data.rootCommitCreated -and $run.data.indexPreserved) 'No-HEAD commit row failed.'
    Assert ((Run-Git -Repo $repo -Argv @('ls-files','--stage','--','outside.txt')) -eq $outsideBefore) 'Root commit changed preexisting index entry.'
    Check-Root $repo $run.data.manifest
    Check-InstalledIndex $repo $run.data.manifest
    Assert ((Get-Content -LiteralPath (Join-Path $repo '.agents\skills\unmanaged\keep.txt') -Raw) -eq 'outside managed roots') 'Unmanaged skill changed.'
    $evidence = [pscustomobject]@{
        repository=$repo
        command='init --commit --json'
        exitCode=$run.code
        head=$run.data.headAfter
        indexSha256Before=$before
        indexSha256After=(IndexBytes $repo)
        outsideIndexEntryBefore=$outsideBefore
        outsideIndexEntryAfter=(Run-Git -Repo $repo -Argv @('ls-files','--stage','--','outside.txt'))
        manifest=$run.data.manifest
        porcelainV2=(Run-Git -Repo $repo -Argv @('status','--porcelain=v2'))
        indexStage=(Run-Git -Repo $repo -Argv @('ls-files','--stage'))
        tree=(Run-Git -Repo $repo -Argv @('ls-tree','-r','HEAD'))
        parents=(Run-Git -Repo $repo -Argv @('log','-1','--format=%P'))
    }
    [System.IO.File]::WriteAllText((Join-Path $scratch 'root-evidence.json'), ($evidence | ConvertTo-Json -Depth 32), (New-Object System.Text.UTF8Encoding($false)))
    $first = Head $repo
    $retry = Run-Init $repo @('--commit')
    Assert ($retry.code -eq 0 -and -not $retry.data.committed -and (Head $repo) -eq $first) 'Identical retry created another commit.'
    $count++

    $repo = New-Repo 'nohead-commit-launch-failure'
    $run = Run-Init $repo @('--commit','--start-lead','--mode','bootstrap')
    Assert ($run.code -ne 0 -and $run.data.rootCommitCreated -and $run.data.phase -eq 'launch' -and $run.data.leadLaunchAttempted) 'Explicit commit plus no-HEAD launch row failed.'
    Check-Root $repo $run.data.manifest
    Check-InstalledIndex $repo $run.data.manifest
    $count++

    $repo = New-Repo 'nohead-launch-failure'
    $run = Run-Init $repo @('--start-lead','--mode','bootstrap')
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'launch' -and $run.data.rootCommitCreated -and $run.data.leadLaunchAttempted -and -not $run.data.leadStarted) 'Launch failure postcondition failed.'
    Check-Root $repo $run.data.manifest
    Check-InstalledIndex $repo $run.data.manifest
    $first = Head $repo
    $retry = Run-Init $repo @('--start-lead','--mode','bootstrap')
    Assert ($retry.code -ne 0 -and -not $retry.data.committed -and (Head $repo) -eq $first) 'Launch retry duplicated root commit.'
    $count++

    $repo = New-Repo 'existing-install' $true
    $beforeHead = Head $repo
    $run = Run-Init $repo @()
    Assert ($run.code -eq 0 -and $run.data.installed -and (Head $repo) -eq $beforeHead) 'Existing HEAD init row failed.'
    $block = Run-Init $repo @('--start-lead','--mode','bootstrap')
    Assert ($block.code -ne 0 -and $block.data.commitRequired -and -not $block.data.leadLaunchAttempted -and (Head $repo) -eq $beforeHead) 'Incomplete HEAD launch guard failed.'
    $count++

    $repo = New-Repo 'existing-commit' $true
    Put-File (Join-Path $repo 'outside.txt') 'staged user file'
    [void](Run-Git -Repo $repo -Argv @('add','outside.txt'))
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -eq 0 -and $run.data.committed -and -not $run.data.rootCommitCreated) 'Existing HEAD commit row failed.'
    Assert ((IndexBytes $repo) -eq $before) 'Existing HEAD commit changed caller index bytes.'
    Assert (-not (Run-Git -Repo $repo -Argv @('ls-tree','HEAD','--','outside.txt'))) 'Existing HEAD commit absorbed unrelated staged file.'
    $count++

    $repo = New-Repo 'existing-dry' $true
    $beforeHead = Head $repo
    $run = Run-Init $repo @('--dry-run','--commit','--start-lead','--mode','bootstrap')
    Assert ($run.code -eq 0 -and $run.data.neededCommit -and -not $run.data.committed -and (Head $repo) -eq $beforeHead) 'Existing HEAD dry run failed.'
    $count++

    $repo = New-Repo 'existing-commit-launch' $true
    $run = Run-Init $repo @('--commit','--start-lead','--mode','bootstrap')
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'launch' -and $run.data.committed -and (Head $repo) -eq $run.data.headAfter) 'Existing HEAD commit and launch failure failed.'
    $count++

    $repo = New-Repo 'managed-extra'
    Put-File (Join-Path $repo 'gad-lead\extra.txt') 'user file'
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'validate' -and $run.data.conflicting -contains 'gad-lead/extra.txt' -and -not (Head $repo)) 'Managed extra file was not blocked.'
    Assert ((IndexBytes $repo) -eq $before -and -not (Test-Path (Join-Path $repo 'gad-lead\README.md'))) 'Managed extra conflict copied files.'
    $count++

    $repo = New-Repo 'managed-differing'
    Put-File (Join-Path $repo 'gad-lead\README.md') 'different'
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -ne 0 -and $run.data.conflicting -contains 'gad-lead/README.md' -and -not (Head $repo)) 'Differing target was not blocked.'
    $count++

    $repo = New-Repo 'identity'
    [void](Run-Git -Repo $repo -Argv @('config','user.name',' '))
    [void](Run-Git -Repo $repo -Argv @('config','user.email',' '))
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'commit' -and -not (Head $repo) -and $run.data.installed -and $run.data.indexPreserved) 'Missing identity postcondition failed.'
    Assert ((IndexBytes $repo) -eq $before) 'Missing identity changed index.'
    [void](Run-Git -Repo $repo -Argv @('config','user.name','Test'))
    [void](Run-Git -Repo $repo -Argv @('config','user.email','test@example.invalid'))
    $retry = Run-Init $repo @('--commit')
    Assert ($retry.code -eq 0 -and $retry.data.rootCommitCreated) 'Identity repair retry failed.'
    $count++

    $repo = New-Repo 'staged-identical'
    $destination = Join-Path $repo 'gad-lead\README.md'
    [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination))
    Copy-Item -LiteralPath (Join-Path $package 'README.md') -Destination $destination
    [void](Run-Git -Repo $repo -Argv @('add','gad-lead/README.md'))
    Put-File (Join-Path $repo 'intent.txt') 'intent-to-add user file'
    [void](Run-Git -Repo $repo -Argv @('add','-N','intent.txt'))
    $intentBefore = Run-Git -Repo $repo -Argv @('ls-files','--stage','--debug','--','intent.txt')
    $before = Run-Git -Repo $repo -Argv @('ls-files','--stage','--','gad-lead/README.md')
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -eq 0 -and $run.data.rootCommitCreated -and (Run-Git -Repo $repo -Argv @('ls-files','--stage','--','gad-lead/README.md')) -eq $before) 'Identical staged destination was not preserved.'
    Assert ((Run-Git -Repo $repo -Argv @('ls-files','--stage','--debug','--','intent.txt')) -eq $intentBefore) 'Intent-to-add user entry changed.'
    Check-Root $repo $run.data.manifest
    Check-InstalledIndex $repo $run.data.manifest
    $count++

    $repo = New-Repo 'staged-conflict'
    $destination = Join-Path $repo 'gad-lead\README.md'
    Put-File $destination 'staged conflicting version'
    [void](Run-Git -Repo $repo -Argv @('add','gad-lead/README.md'))
    Copy-Item -LiteralPath (Join-Path $package 'README.md') -Destination $destination -Force
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'validate' -and $run.data.conflicting -contains 'gad-lead/README.md' -and -not (Head $repo)) 'Conflicting staged destination was not blocked.'
    Assert ((IndexBytes $repo) -eq $before -and -not (Test-Path (Join-Path $repo 'gad-lead\gad-lead.cmd'))) 'Staged conflict changed user state.'
    $count++

    $repo = New-Repo 'staged-unmerged'
    $destination = Join-Path $repo 'gad-lead\README.md'
    Put-File $destination 'unmerged'
    $oid = Run-Git -Repo $repo -Argv @('hash-object','-w','--',$destination)
    $lines = "100644 $oid 1`tgad-lead/README.md`n100644 $oid 2`tgad-lead/README.md`n"
    $inputPath = Join-Path $scratch 'index-info.txt'
    [System.IO.File]::WriteAllText($inputPath, $lines, [System.Text.Encoding]::ASCII)
    $process = Start-Process -FilePath (Get-Command git.exe).Source -ArgumentList @('-C', $repo, 'update-index', '--index-info') -RedirectStandardInput $inputPath -NoNewWindow -Wait -PassThru
    Assert ($process.ExitCode -eq 0) 'Could not create unmerged fixture.'
    $before = IndexBytes $repo
    $run = Run-Init $repo @('--commit')
    Assert ($run.code -ne 0 -and $run.data.conflicting -contains 'gad-lead/README.md' -and (IndexBytes $repo) -eq $before -and -not (Head $repo)) 'Unmerged destination was not blocked.'
    $count++

    $repo = New-Repo 'stage-failure'
    $realGit = (Get-Command git.exe).Source
    $shimDir = Join-Path $scratch 'git-shim'
    [void](New-Item -ItemType Directory -Path $shimDir)
    $shim = "@echo off`r`nif not `"%GIT_INDEX_FILE%`"==`"`" if `"%6`"==`"update-index`" exit /b 44`r`n`"$realGit`" %*`r`n"
    [System.IO.File]::WriteAllText((Join-Path $shimDir 'git.cmd'), $shim, [System.Text.Encoding]::ASCII)
    $oldPath = $env:PATH
    try {
        $env:PATH = "$shimDir;$oldPath"
        $before = IndexBytes $repo
        $run = Run-Init $repo @('--commit')
    }
    finally { $env:PATH = $oldPath }
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'stage' -and $run.data.installed -and -not (Head $repo)) 'Isolated stage failure postcondition failed.'
    Assert ((IndexBytes $repo) -eq $before) 'Stage failure changed primary index.'
    $retry = Run-Init $repo @('--commit')
    Assert ($retry.code -eq 0 -and $retry.data.rootCommitCreated) 'Stage failure retry failed.'
    $count++

    $repo = New-Repo 'copy-failure'
    $locked = Join-Path $repo 'gad-lead'
    [void](New-Item -ItemType Directory -Path $locked)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $deny = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, [System.Security.AccessControl.FileSystemRights]::CreateFiles, [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None, [System.Security.AccessControl.AccessControlType]::Deny)
    $acl = Get-Acl -LiteralPath $locked
    [void]$acl.AddAccessRule($deny)
    Set-Acl -LiteralPath $locked -AclObject $acl
    $before = IndexBytes $repo
    try { $run = Run-Init $repo @('--commit') }
    finally {
        $acl = Get-Acl -LiteralPath $locked
        [void]$acl.RemoveAccessRule($deny)
        Set-Acl -LiteralPath $locked -AclObject $acl
    }
    Assert ($run.code -ne 0 -and $run.data.phase -eq 'copy' -and -not (Head $repo) -and (IndexBytes $repo) -eq $before) 'Copy failure postcondition failed.'
    Assert (-not (Get-ChildItem -LiteralPath $locked -Force -File)) 'Copy failure left a partial destination file.'
    $retry = Run-Init $repo @('--commit')
    Assert ($retry.code -eq 0 -and $retry.data.rootCommitCreated) 'Copy failure retry failed.'
    $count++

    $newPath = Join-Path $scratch 'new-regression'
    $newLines = @(& $installer new --project $newPath --package $package --gad-core $core --start-lead --json)
    Assert ($LASTEXITCODE -ne 0 -and $newLines.Count -eq 1 -and -not (Test-Path $newPath)) 'new --start-lead without --commit regression.'
    $count++

    Write-Output "PASS $count bootstrap matrix cases; scratch=$scratch"
}
catch {
    Write-Error "FAIL after $count cases: $($_.Exception.Message); scratch=$scratch"
    exit 1
}
