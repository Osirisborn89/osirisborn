param([int]$Port=7780,[switch]$AddXP,[switch]$Debug)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path ".\MythicCore\www\index.html")) { throw "Not in repo root" }

# Pre-commit guard (parser + wiring)
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\Precommit.ps1

# Restart cleanly
pwsh -NoProfile -File .\tools\Stop-Server.ps1 -Port $Port | Out-Null
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\Run-Server.ps1 -Port $Port -Debug:$Debug | Out-Null

# Smoke (optionally add XP)
& pwsh -NoProfile -File .\tools\Smoke.ps1 -Port $Port -AddXP:$AddXP
exit $LASTEXITCODE
