[CmdletBinding(DefaultParameterSetName = 'Window')]
param(
    [Parameter(Mandatory)][string]$RepositoryPath,
    [Parameter(ParameterSetName = 'Window')][string]$Since = '2 months ago',
    [Parameter(ParameterSetName = 'Window')][string]$Until,
    [Parameter(Mandatory, ParameterSetName = 'Commits')][ValidateCount(1, 3)][string[]]$Commit,
    [Parameter(ParameterSetName = 'Commits')][ValidateNotNullOrEmpty()][string[]]$Path = @(),
    [ValidateRange(1, 200)][int]$MaxCommits = 50,
    [ValidateRange(1, 1000)][int]$MaxFilesPerCommit = 100,
    [ValidateRange(1, 1000)][int]$MaxStatusEntries = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = & git -C $repository --no-pager @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)"
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function Get-ChangedFiles {
    param(
        [Parameter(Mandatory)][string]$Revision,
        [string[]]$SelectedPaths = @()
    )

    return @(Invoke-Git (@('--literal-pathspecs', 'diff-tree', '--root', '--no-commit-id', '--name-status', '-r', $Revision, '--') + $SelectedPaths) |
        Where-Object { $_ } |
        ForEach-Object {
            $parts = $_ -split "`t"
            [ordered]@{
                status = $parts[0]
                paths = @($parts[1..($parts.Count - 1)])
            }
        })
}

$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$insideWorkTree = @(Invoke-Git @('rev-parse', '--is-inside-work-tree'))
if ($insideWorkTree[0] -ne 'true') {
    throw "Not a Git worktree: $repository"
}

$revision = @(Invoke-Git @('rev-parse', 'HEAD'))[0]
$dirtyEntries = @(Invoke-Git @('status', '--short', '--untracked-files=all'))
$dirtyTruncated = $dirtyEntries.Count -gt $MaxStatusEntries
$dirty = @($dirtyEntries | Select-Object -First $MaxStatusEntries)
$commits = @()
$truncated = $false
$evidenceDirectory = $null

if ($PSCmdlet.ParameterSetName -eq 'Window') {
    $logArguments = @(
        'log',
        '--first-parent',
        "--max-count=$($MaxCommits + 1)",
        '--date=short',
        '--format=%H%x1f%ad%x1f%s',
        "--since=$Since"
    )
    if ($Until) {
        $logArguments += "--until=$Until"
    }

    $logLines = @(Invoke-Git $logArguments | Where-Object { $_ })
    $truncated = $logLines.Count -gt $MaxCommits
    foreach ($line in $logLines | Select-Object -First $MaxCommits) {
        $parts = $line -split [char]0x1f, 3
        $changedFiles = @(Get-ChangedFiles $parts[0])
        $commits += [ordered]@{
            revision = $parts[0]
            date = $parts[1]
            subject = $parts[2]
            changedFiles = @($changedFiles | Select-Object -First $MaxFilesPerCommit)
            changedFilesTruncated = $changedFiles.Count -gt $MaxFilesPerCommit
        }
    }
} else {
    foreach ($requestedRevision in $Commit) {
        if ($requestedRevision -notmatch '^[0-9a-fA-F]{7,40}$') {
            throw "Commit must be a 7-40 character hexadecimal revision: $requestedRevision"
        }

        $resolvedRevision = @(Invoke-Git @('rev-parse', "$requestedRevision^{commit}"))[0]
        $metadata = @(Invoke-Git @('show', '-s', '--date=short', '--format=%H%x1f%ad%x1f%s', $resolvedRevision))[0] -split [char]0x1f, 3
        $patchLines = @(Invoke-Git (@('--literal-pathspecs', 'show', '--format=', '--no-color', '--no-ext-diff', '--no-textconv', '--unified=3', $resolvedRevision, '--') + $Path))
        $patch = if ($patchLines.Count -gt 0) { ($patchLines -join "`n") + "`n" } else { '' }
        if (-not $evidenceDirectory) {
            $evidenceDirectory = Join-Path ([IO.Path]::GetTempPath()) "history-seeder-evidence-$([guid]::NewGuid().ToString('N'))"
            $null = [IO.Directory]::CreateDirectory($evidenceDirectory)
        }
        $patchPath = Join-Path $evidenceDirectory "$resolvedRevision.diff"
        [IO.File]::WriteAllText($patchPath, $patch, [Text.UTF8Encoding]::new($false))
        $changedFiles = @(Get-ChangedFiles $resolvedRevision $Path)
        $commits += [ordered]@{
            revision = $metadata[0]
            date = $metadata[1]
            subject = $metadata[2]
            changedFiles = @($changedFiles | Select-Object -First $MaxFilesPerCommit)
            changedFilesTruncated = $changedFiles.Count -gt $MaxFilesPerCommit
            selectedPaths = @($Path)
            patchPath = $patchPath
            patchLineCount = $patchLines.Count
            patchCharacterCount = $patch.Length
        }
    }
}

[ordered]@{
    schemaVersion = 2
    mode = if ($PSCmdlet.ParameterSetName -eq 'Window') { 'inventory' } else { 'commits' }
    revision = $revision
    dirty = $dirty
    dirtyTruncated = $dirtyTruncated
    truncated = $truncated
    evidenceDirectory = $evidenceDirectory
    commits = $commits
} | ConvertTo-Json -Depth 8