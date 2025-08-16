param()
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverPath = Join-Path $repo "MythicCore\scripts\Osirisborn.Server.ps1"

# Find backup candidates
$candidates = Get-ChildItem -Path $repo -Filter "Osirisborn.Server.ps1" -Recurse |
  Where-Object { $_.FullName -match "\\backup-" } |
  Sort-Object LastWriteTime -Descending

if (-not $candidates) { Write-Error "No backups found under backup-*"; exit 1 }

# Choose the first that parses cleanly
$good = $null
foreach ($c in $candidates) {
  $tokens=$null; $ast=$null; $errors=$null
  [System.Management.Automation.Language.Parser]::ParseFile($c.FullName, [ref]$tokens, [ref]$ast, [ref]$errors) | Out-Null
  if (-not $errors -or $errors.Count -eq 0) { $good = $c; break }
}

if (-not $good) { Write-Error "No parseable backup found."; exit 1 }

# Safety backup current
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
if (Test-Path $serverPath) { Copy-Item $serverPath "$serverPath.broken-$ts" -Force }

# Restore
Copy-Item $good.FullName $serverPath -Force
Write-Host "✅ Restored server from:`n$($good.FullName)"
