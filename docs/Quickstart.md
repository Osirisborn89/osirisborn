# Quickstart

## Prereqs
- Windows runner or local Windows
- PowerShell 7 (recommended) and/or Windows PowerShell 5
- Pester (the CI installs it automatically; locally we import/install as needed)
- Git

## Clone
~~~powershell
git clone https://github.com/Osirisborn89/osirisborn.git
Set-Location .\osirisborn
~~~

## Run tests and smoke locally
~~~powershell
# Always from repo root
pwsh -NoProfile -File .\tools\Reset-Server.ps1
Import-Module Pester -MinimumVersion 5.5 -Force
Invoke-Pester -Path .\tests -Output Detailed

# Quick smoke
pwsh -NoProfile -File .\tools\Smoke.ps1 -Port 7780 -AddXP
~~~

## CI
- CI runs on pushes to `main` and `less-**`, and on PRs to `main`.
- Required checks: **CI / Pester on pwsh**, **CI / Pester on powershell**.
- Smoke runs after CI success and uploads logs on failure.

## Troubleshooting
- If you see errors involving `sc` in PS5, ensure we remove the alias before scripts (CI already does this).
- Ensure port **7780** is free locally.
- If `/diag` shows no files exist in CI, tests will bootstrap the store automatically.
