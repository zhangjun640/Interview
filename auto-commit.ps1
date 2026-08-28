$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "run.log"
$ReposRoot = Join-Path $ScriptDir "repos"
$CommitMessage = "chore: update activity log"

$Repositories = @(
    @{ Name = "AI-interviewers"; Path = Join-Path $ReposRoot "AI-interviewers" },
    @{ Name = "Hospital-Medical-Management-System"; Path = Join-Path $ReposRoot "Hospital-Medical-Management-System" },
    @{ Name = "zhangjun640.github.io"; Path = Join-Path $ReposRoot "zhangjun640.github.io" },
    @{ Name = "Interview"; Path = Join-Path $ReposRoot "Interview" }
)

function Write-RunLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryPath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = & git -C $RepositoryPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) {
        Write-RunLog ([string]$line)
    }
    return $exitCode
}

$AvailableRepositories = @(
    $Repositories | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.Path ".git")
    }
)

if ($AvailableRepositories.Count -eq 0) {
    Write-RunLog "[ERROR] No configured repository clone is available under $ReposRoot"
    exit 1
}

$Selected = Get-Random -InputObject $AvailableRepositories
$RepositoryPath = $Selected.Path
Write-RunLog "Selected repository: $($Selected.Name)"

if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("pull", "--ff-only")) -ne 0) {
    Write-RunLog "[ERROR] Pull failed for $($Selected.Name); no local file was changed"
    exit 1
}

$ActivityDirectory = Join-Path $RepositoryPath ".github"
$ActivityFile = Join-Path $ActivityDirectory "activity-log.txt"
New-Item -ItemType Directory -Path $ActivityDirectory -Force | Out-Null
Add-Content -LiteralPath $ActivityFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss K") -Encoding UTF8

if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("add", "--", ".github/activity-log.txt")) -ne 0) {
    Write-RunLog "[ERROR] Could not stage activity log for $($Selected.Name)"
    exit 1
}

if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("commit", "-m", $CommitMessage)) -ne 0) {
    Write-RunLog "[ERROR] Commit failed for $($Selected.Name)"
    exit 1
}

if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("push", "origin", "HEAD")) -eq 0) {
    Write-RunLog "[OK] Pushed $($Selected.Name)"
    exit 0
}

Write-RunLog "[WARN] Push failed; retry with proxy 127.0.0.1:7897"
if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("-c", "http.proxy=http://127.0.0.1:7897", "-c", "https.proxy=http://127.0.0.1:7897", "push", "origin", "HEAD")) -eq 0) {
    Write-RunLog "[OK] Pushed $($Selected.Name) using proxy"
    exit 0
}

Write-RunLog "[WARN] Push failed; retry without proxy"
if ((Invoke-Git -RepositoryPath $RepositoryPath -Arguments @("-c", "http.proxy=", "-c", "https.proxy=", "push", "origin", "HEAD")) -eq 0) {
    Write-RunLog "[OK] Pushed $($Selected.Name) without proxy"
    exit 0
}

Write-RunLog "[ERROR] Push failed for $($Selected.Name); check network or GitHub authentication"
exit 1
