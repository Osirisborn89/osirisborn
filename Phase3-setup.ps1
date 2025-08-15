# One-shot Phase 3 setup
$pwsh = (Get-Command pwsh).Source
$root = Join-Path $env:USERPROFILE 'Osirisborn\MythicCore'
$scripts = Join-Path $root 'scripts'
$cli  = Join-Path $scripts 'osirisborn.ps1'
$gui  = Join-Path $scripts 'Osirisborn.Gui.ps1'

# Start Menu launcher (.cmd)
$programs = [Environment]::GetFolderPath('Programs')
$cmdPath  = Join-Path $programs 'Osirisborn Control Panel.cmd'
@"
@echo off
start "" "$pwsh" -STA -ExecutionPolicy Bypass -File "$gui"
"@ | Set-Content -Path $cmdPath -Encoding ASCII

# Daily backup @ 09:00
try {
  $act  = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -File `"$cli`" backup"
  $trig = New-ScheduledTaskTrigger -Daily -At 9:00
  Register-ScheduledTask -TaskName "OsirisbornDailyBackup" -Action $act -Trigger $trig -Description "Daily backup of Osirisborn store" -Force | Out-Null
  "Scheduled daily backup: 09:00"
} catch { "Could not schedule backup: $($_.Exception.Message)" }

"Setup complete. Shortcut: $cmdPath"
