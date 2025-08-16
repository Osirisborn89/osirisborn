param([int]$Port=7780,[switch]$Debug)
pwsh -NoProfile -File .\tools\Stop-Server.ps1 -Port $Port | Out-Null
pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\Run-Server.ps1 -Port $Port -Debug:$Debug
