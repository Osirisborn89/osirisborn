param(
  [int]$Port = 7780,
  [switch]$Debug
)
$ErrorActionPreference = 'SilentlyContinue'
$repo   = (Resolve-Path ".").Path
$server = Join-Path $repo "MythicCore\scripts\Osirisborn.Server.ps1"

# Free the port & kill old processes
Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { try { Stop-Process -Id $_.OwningProcess -Force } catch {} }
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'Osirisborn\.Server\.ps1|Run-MythicCore\.ps1' } |
  ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force } catch {} }

# Start headless (CI-safe)
$env:OSIRISBORN_DEBUG = if ($Debug) { '1' } else { '0' }
$ci = $env:GITHUB_ACTIONS -eq 'true'

# No UI, no -NoExit on CI
$argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$server")
if (-not $ci) { $argList = @('-NoExit') + $argList }
$ws = if ($ci) { 'Hidden' } else { 'Normal' }

$proc = Start-Process pwsh -WorkingDirectory $repo -ArgumentList $argList -WindowStyle $ws -PassThru

# Health gate (slightly longer for CI) against 127.0.0.1
$ok = $false
foreach ($i in 1..60) {
  try {
    $r = Invoke-WebRequest "http://127.0.0.1:$Port/" -TimeoutSec 2
    if ($r.StatusCode -eq 200) { $ok = $true; break }
  } catch {}
  Start-Sleep -Milliseconds 500
}
if (-not $ok) {
  Write-Error "❌ Server failed health check on port $Port"
  try { Stop-Process -Id $proc.Id -Force } catch {}
  exit 1
}
"✅ Server healthy on http://127.0.0.1:$Port/ (pid:$($proc.Id))"
