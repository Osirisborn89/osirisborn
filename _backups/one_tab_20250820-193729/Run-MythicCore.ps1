param()
$ErrorActionPreference = "Stop"
$RepoDir = "C:\Users\day_8\dev\osirisborn"
$env:BP_REPO = $RepoDir

# Guard
if (-not (Test-Path (Join-Path $RepoDir "MythicCore\www\index.html"))) {
  Write-Error "❌ Repo missing at $RepoDir"; exit 1
}

# Load fallbacks into THIS session
. (Join-Path $RepoDir "MythicCore\tools\BP-Fallbacks.ps1")

# Start the server in THIS session (so it sees the fallbacks)
Set-Location $RepoDir
$server = Join-Path $RepoDir "MythicCore\scripts\Osirisborn.Server.ps1"
& $server
