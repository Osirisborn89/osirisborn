param([int]$Port = 7780)
$killed = 0
Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { try { Stop-Process -Id $_.OwningProcess -Force; $killed++ } catch {} }
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -match 'Osirisborn\.Server\.ps1|Run-MythicCore\.ps1' } |
  ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force; $killed++ } catch {} }
"Stopped $killed process(es)."
