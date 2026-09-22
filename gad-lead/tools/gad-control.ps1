#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$Package)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Mechanical execution only. Lead must reconcile the actual Human Gate and
# review evidence outside this tool; package fields never authenticate either.
function Native([string]$exe, [string[]]$argv, [string]$cwd) {
    Push-Location -LiteralPath $cwd
    try {
        $binary = (Get-Command $exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $prior=$ErrorActionPreference; $ErrorActionPreference='Continue'
        try { $out = @(& $binary @argv 2>&1); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference=$prior }
        return [pscustomobject]@{ code=$code; text=($out -join "`n").Trim() }
    } finally { Pop-Location }
}
function Git([string[]]$argv) { Native 'git' $argv $script:repo }
function Require([bool]$ok, [string]$why) { if (-not $ok) { throw $why } }
function GitValue([string[]]$argv) {
    $r = Git $argv
    Require ($r.code -eq 0) "git $($argv[0]) failed: $($r.text)"
    return $r.text
}
function ExactSha([string]$value) { Require ($value -cmatch '^[0-9a-f]{40}$') 'Expected a full lowercase SHA-1.' }
function Field($obj, [string]$name) {
    $p = $obj.PSObject.Properties[$name]
    Require ($null -ne $p -and -not [string]::IsNullOrWhiteSpace([string]$p.Value)) "Missing $name."
    return [string]$p.Value
}
function Clean([string]$path) {
    $r = Native 'git' @('status','--porcelain=v1','--untracked-files=all') $path
    Require ($r.code -eq 0 -and -not $r.text) "Dirty or unknown checkout: $path"
}
function Orca([string[]]$argv) {
    $r = Native 'orca' ($argv + @('--json')) $script:repo
    Require ($r.code -eq 0) "Orca failed: $($r.text)"
    $j = $r.text | ConvertFrom-Json
    Require ($j.ok -eq $true) "Orca refused: $($r.text)"
    return $j
}
function Snapshot {
    $head = GitValue @('rev-parse','HEAD')
    $status = GitValue @('status','--porcelain=v1','--untracked-files=all')
    return [ordered]@{ head=$head; status=$status }
}
function WriteBlob([string]$blob, [string]$path) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'; $psi.Arguments = "cat-file blob $blob"
    $psi.WorkingDirectory = $script:repo; $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true
    $proc = [Diagnostics.Process]::Start($psi)
    $dest = Join-Path $script:repo $path
    $parent = Split-Path -Parent $dest
    Require (Test-Path -LiteralPath $parent -PathType Container) 'Target parent absent.'
    $stream = [IO.File]::Create($dest)
    try { $proc.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose(); $proc.WaitForExit() }
    Require ($proc.ExitCode -eq 0) 'Blob copy failed.'
}

$script:repo=$null
$result = [ordered]@{ ok=$false; action=$null; package=$Package; before=$null; after=$null; changed=$false; error=$null }
try {
    $p = Get-Content -LiteralPath $Package -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:repo = (Resolve-Path -LiteralPath (Field $p 'repo')).Path
    Require ((GitValue @('rev-parse','--show-toplevel')) -eq ($script:repo -replace '\\','/')) 'Package repo is not Git root.'
    $action = Field $p 'action'; $result.action = $action
    Require ($action -in @('promote','integrate','status','terminal-close','worktree-remove','branch-delete','remote-check','close')) 'Unknown action.'
    $gate = Field $p 'gate'
    Require ($gate -in @('G3','G4','G5')) 'Invalid gate.'
    $main = Field $p 'mainRef'
    Require ($main -eq 'refs/heads/main') 'Only local main is an authority ref.'
    $mainSha = GitValue @('rev-parse','--verify',$main)
    $target = Field $p 'target'
    $result.before = Snapshot
    switch ($action) {
        'promote' {
            Require ($gate -in @('G3','G4')) 'Promotion requires G3/G4.'
            $path = Field $p 'path'; Require ($path -cmatch '^[A-Za-z0-9_./-]+$' -and -not $path.Contains('..')) 'Unsafe target path.'
            $blob = Field $p 'blob'; ExactSha $blob
            Require ($target -ceq "$path@$blob") 'Promotion target mismatch.'
            Require ((GitValue @('cat-file','-t',$blob)) -eq 'blob') 'Source is not a blob.'
            $expected = Field $p 'expectedBlob'; ExactSha $expected
            $actual = GitValue @('rev-parse',"HEAD:$path")
            Require ($actual -ceq $expected -or $actual -ceq $blob) 'Target blob drift.'
            $working = GitValue @('hash-object','--',$path)
            if ($working -cne $blob) {
                Clean $script:repo
                WriteBlob $blob $path
                $result.changed = $true
            }
            Require ((GitValue @('hash-object','--',$path)) -ceq $blob) 'Promotion postcondition failed.'
        }
        'integrate' {
            Require ($gate -eq 'G5') 'Integration requires G5.'
            $sha = Field $p 'reviewedSha'; ExactSha $sha
            Require ($target -ceq $sha) 'Reviewed SHA target mismatch.'
            Require ((GitValue @('rev-parse','HEAD')) -ceq (Field $p 'expectedHead')) 'Main HEAD drift.'
            Require ((GitValue @('symbolic-ref','HEAD')) -ceq $main) 'Checkout is not main.'
            Clean $script:repo
            Require ((Git @('merge-base','--is-ancestor','HEAD',$sha)).code -eq 0) 'Non-fast-forward integration.'
            # A caller's PASS string is not independent Review evidence.
            # Lead reconciles the actual frozen-SHA review before invocation.
            if ((GitValue @('rev-parse','HEAD')) -cne $sha) {
                $r = Git @('merge','--ff-only',$sha); Require ($r.code -eq 0) "Fast-forward failed: $($r.text)"; $result.changed=$true
            }
            Require ((GitValue @('rev-parse','HEAD')) -ceq $sha) 'Integration postcondition failed.'
        }
        'status' {
            Require ($gate -eq 'G5') 'Status sync requires G5.'
            $path='PROJECT_STATUS.md'; $blob=Field $p 'blob'; ExactSha $blob
            Require ($target -ceq "$path@$blob") 'Status target mismatch.'
            Require ((GitValue @('cat-file','-t',$blob)) -eq 'blob') 'Status source absent.'
            $actual=GitValue @('rev-parse',"HEAD:$path")
            Require ($actual -ceq (Field $p 'expectedBlob') -or $actual -ceq $blob) 'Status base drift.'
            $working=GitValue @('hash-object','--',$path)
            if ($working -cne $blob) {
                Clean $script:repo
                WriteBlob $blob $path
                $result.changed=$true
            }
            Require ((GitValue @('hash-object','--',$path)) -ceq $blob) 'Status postcondition failed.'
        }
        'terminal-close' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $handle=Field $p 'handle'; Require ($target -ceq $handle) 'Handle mismatch.'
            throw 'Terminal completion, exact Orca ownership, and retained output are not demonstrable by this tool.'
            Orca @('terminal','close','--terminal',$handle) | Out-Null; $result.changed=$true
            $r=Native 'orca' @('terminal','show','--terminal',$handle,'--json') $script:repo
            Require ($r.code -ne 0 -or -not $r.text.Contains('"ok": true')) 'Terminal remains live.'
        }
        'worktree-remove' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $id=Field $p 'worktreeId'; Require ($target -ceq $id -and $id -ne 'active') 'Worktree mismatch.'
            $path=(Resolve-Path -LiteralPath (Field $p 'worktreePath')).Path
            Require ($path -ne $script:repo) 'Cannot remove main.'
            Clean $path
            throw 'Worktree completion and retained evidence are not demonstrable by this tool.'
            $sha=Field $p 'head'; ExactSha $sha
            Require ((Native 'git' @('rev-parse','HEAD') $path).text -ceq $sha) 'Worktree HEAD drift.'
            Require ((Git @('merge-base','--is-ancestor',$sha,$mainSha)).code -eq 0) 'Unique commit must be retained.'
            $terms=Orca @('terminal','list','--worktree',"id:$id")
            Require ($null -ne $terms.result -and $null -ne $terms.result.terminals -and -not $terms.result.truncated -and @($terms.result.terminals).Count -eq 0) 'Terminals or incomplete listing block removal.'
            $listed=Orca @('worktree','show','--worktree',"id:$id")
            Require (($listed | ConvertTo-Json -Depth 30).Contains($path)) 'Orca worktree identity drift.'
            $branch=Field $p 'branch'; Require ($branch -cmatch '^refs/heads/[A-Za-z0-9_./-]+$') 'Unsafe branch.'
            Require ((GitValue @('rev-parse','--verify',$branch)) -ceq $sha) 'Branch ref drift.'
            Orca @('worktree','rm','--worktree',"id:$id") | Out-Null; $result.changed=$true
            Require (-not (Test-Path -LiteralPath $path)) 'Worktree still present.'
            $ref=Git @('show-ref','--verify','--hash',$branch)
            $result.branchDisposition=if ($ref.code -eq 0) { "retained:$($ref.text)" } else { 'removed' }
        }
        'branch-delete' {
            Require ($gate -eq 'G5') 'Cleanup requires G5.'
            $branch=Field $p 'branch'; Require ($branch -cmatch '^refs/heads/[A-Za-z0-9_./-]+$' -and $branch -ne $main) 'Unsafe branch.'
            Require ($target -ceq $branch) 'Branch mismatch.'
            $sha=Field $p 'head'; ExactSha $sha
            $r=Git @('show-ref','--verify','--hash',$branch)
            if ($r.code -eq 0) {
                Require ($r.text -ceq $sha) 'Branch ref drift.'
                Require ((Git @('merge-base','--is-ancestor',$sha,$mainSha)).code -eq 0) 'Unique commit must be retained.'
                throw 'Retained branch evidence is not demonstrable by this tool.'
                $used=GitValue @('worktree','list','--porcelain')
                Require (-not $used.Contains("branch $branch")) 'Branch checked out.'
                $r=Git @('branch','-d',($branch -replace '^refs/heads/',''))
                Require ($r.code -eq 0) "Branch delete refused: $($r.text)"; $result.changed=$true
            }
            Require ((Git @('show-ref','--verify',$branch)).code -ne 0) 'Branch still present.'
        }
        'remote-check' {
            $remote=Field $p 'remote'; $ref=Field $p 'remoteRef'; $sha=Field $p 'expectedSha'; ExactSha $sha
            Require ($target -ceq "$remote/$ref@$sha") 'Remote target mismatch.'
            Require ($ref -cmatch '^refs/heads/[A-Za-z0-9_./-]+$') 'Unsafe remote ref.'
            $r=Git @('ls-remote','--exit-code',$remote,$ref)
            Require ($r.code -eq 0) "Remote ref unavailable: $($r.text)"
            $actual=($r.text -split '\s+')[0]
            $result.remote=[ordered]@{ expected=$sha; actual=$actual; match=($sha -ceq $actual) }
            Require ($sha -ceq $actual) 'Remote SHA mismatch.'
        }
        'close' {
            Require ($gate -eq 'G5') 'Closure requires G5.'
            Require ($target -ceq (Field $p 'batch')) 'Batch target mismatch.'
            throw 'GREEN review, retention, and object dispositions are not demonstrable by this tool.'
            $metrics=$p.metrics
            foreach($key in @('peakWorkers','peakWorktrees','newBranches','mechanicalWorkers','verificationCases','manualCoordination','elapsedSeconds','provenance','bootstrapComparison')) { [void](Field $metrics $key) }
            $result.metrics=$metrics
            # Closure is a checked result; a governed status writer records CLOSED.
        }
    }
    $result.after=Snapshot; $result.ok=$true
} catch { $result.error=$_.Exception.Message; if ($script:repo) { try { $result.after=Snapshot } catch {} } }
$result | ConvertTo-Json -Depth 30 -Compress
if (-not $result.ok) { exit 2 }
