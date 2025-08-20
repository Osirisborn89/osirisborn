#requires -Version 7.0
# Run with: pwsh -STA -ExecutionPolicy Bypass -File "$HOME\Osirisborn\MythicCore\scripts\Osirisborn.Gui.ps1"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root    = Join-Path $env:USERPROFILE 'Osirisborn\MythicCore'
$Scripts = Join-Path $Root 'scripts'
$DataDir = Join-Path $Root 'data'
$EventsDir = Join-Path $DataDir 'events'
$WwwDir  = Join-Path $Root 'www'
$CLI     = Join-Path $Scripts 'osirisborn.ps1'
$Mirror  = Join-Path $WwwDir  'mirror.json'
if (-not (Test-Path $EventsDir)) { New-Item -ItemType Directory -Force -Path $EventsDir | Out-Null }
$Events  = Join-Path $EventsDir 'notify.log'

function Invoke-CLI([string[]]$Args) {
  try { (& pwsh -NoProfile -ExecutionPolicy Bypass -File $CLI @Args 2>&1 | Out-String).Trim() } catch { $_ | Out-String }
}
function Read-Mirror {
  if (Test-Path $Mirror) { try { return (Get-Content -Raw -Path $Mirror | ConvertFrom-Json) } catch {} }
  [pscustomobject]@{ user=[pscustomobject]@{ alias='Osirisborn'; rank='Initiate'; xp=0; progressPct=0; badges=0; streakCurrent=0; streakLongest=0 }; updated='' }
}

# ------------- UI -------------
$form                = New-Object Windows.Forms.Form
$form.Text           = "Osirisborn Control Panel"
$form.StartPosition  = "CenterScreen"
$form.Size           = New-Object Drawing.Size(860, 600)
$form.MaximizeBox    = $false
$form.FormBorderStyle= 'FixedDialog'

$tabs = New-Object Windows.Forms.TabControl
$tabs.Location='10,10'; $tabs.Size='840,540'

$tpStatus = New-Object Windows.Forms.TabPage; $tpStatus.Text='Status'
$tpXP     = New-Object Windows.Forms.TabPage; $tpXP.Text='XP Log'
$tpMission= New-Object Windows.Forms.TabPage; $tpMission.Text='Missions'
$tpSet    = New-Object Windows.Forms.TabPage; $tpSet.Text='Settings'
$tabs.TabPages.AddRange(@($tpStatus,$tpXP,$tpMission,$tpSet))
$form.Controls.Add($tabs)

# ----- STATUS -----
$lblAlias = New-Object Windows.Forms.Label; $lblAlias.Location='20,20'; $lblAlias.Size='400,24'; $lblAlias.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold)
$lblRank  = New-Object Windows.Forms.Label; $lblRank.Location='20,52';  $lblRank.Size='400,20'
$lblXP    = New-Object Windows.Forms.Label; $lblXP.Location='20,74';    $lblXP.Size='400,20'
$pb       = New-Object Windows.Forms.ProgressBar; $pb.Location='20,98'; $pb.Size='390,18'; $pb.Minimum=0; $pb.Maximum=100
$lblProg  = New-Object Windows.Forms.Label; $lblProg.Location='20,120'; $lblProg.Size='390,20'
$lblStreak= New-Object Windows.Forms.Label; $lblStreak.Location='430,20'; $lblStreak.Size='370,20'
$lblBadges= New-Object Windows.Forms.Label; $lblBadges.Location='430,42'; $lblBadges.Size='370,20'
$lblGoal  = New-Object Windows.Forms.Label; $lblGoal.Location='430,64'; $lblGoal.Size='370,20'
$lblUpdated=New-Object Windows.Forms.Label; $lblUpdated.Location='430,86'; $lblUpdated.Size='370,20'
$btnRefresh = New-Object Windows.Forms.Button; $btnRefresh.Text='Refresh'; $btnRefresh.Location='20,150'; $btnRefresh.Size='90,32'
$btnBackup  = New-Object Windows.Forms.Button; $btnBackup.Text='Backup'; $btnBackup.Location='120,150'; $btnBackup.Size='90,32'
$btnRestoreLatest = New-Object Windows.Forms.Button; $btnRestoreLatest.Text='Restore Latest'; $btnRestoreLatest.Location='220,150'; $btnRestoreLatest.Size='120,32'
$btnRestorePick   = New-Object Windows.Forms.Button; $btnRestorePick.Text='Restore From File'; $btnRestorePick.Location='350,150'; $btnRestorePick.Size='140,32'
$btnOpenDash      = New-Object Windows.Forms.Button; $btnOpenDash.Text='Open Dashboard'; $btnOpenDash.Location='500,150'; $btnOpenDash.Size='120,32'
$btnOpenData      = New-Object Windows.Forms.Button; $btnOpenData.Text='Open Data'; $btnOpenData.Location='630,150'; $btnOpenData.Size='100,32'

# Targets box
$grpTargets = New-Object Windows.Forms.GroupBox; $grpTargets.Text='Today''s Targets'; $grpTargets.Location='20,200'; $grpTargets.Size='780,280'
$lblTGoal   = New-Object Windows.Forms.Label; $lblTGoal.Location='20,28'; $lblTGoal.Size='300,20'
$lblTProg   = New-Object Windows.Forms.Label; $lblTProg.Location='20,50'; $lblTProg.Size='300,20'
$lstSuggest = New-Object Windows.Forms.ListView; $lstSuggest.Location='20,80'; $lstSuggest.Size='740,170'; $lstSuggest.View='Details'; $lstSuggest.FullRowSelect=$true
$null = $lstSuggest.Columns.Add('Id',120); $null = $lstSuggest.Columns.Add('Title',480); $null = $lstSuggest.Columns.Add('XP',80)
$grpTargets.Controls.AddRange(@($lblTGoal,$lblTProg,$lstSuggest))
$tpStatus.Controls.AddRange(@($lblAlias,$lblRank,$lblXP,$pb,$lblProg,$lblStreak,$lblBadges,$lblGoal,$lblUpdated,$btnRefresh,$btnBackup,$btnRestoreLatest,$btnRestorePick,$btnOpenDash,$btnOpenData,$grpTargets))

# ----- XP LOG -----
$btnExport = New-Object Windows.Forms.Button; $btnExport.Text='Export CSV'; $btnExport.Location='20,16'; $btnExport.Size='110,30'
$btnLoadXP = New-Object Windows.Forms.Button; $btnLoadXP.Text='Refresh Log'; $btnLoadXP.Location='140,16'; $btnLoadXP.Size='110,30'
$txtXP     = New-Object Windows.Forms.TextBox; $txtXP.Location='20,56'; $txtXP.Size='780,380'; $txtXP.Multiline=$true; $txtXP.ScrollBars='Vertical'; $txtXP.Font=New-Object Drawing.Font('Consolas',9); $txtXP.ReadOnly=$true
$tpXP.Controls.AddRange(@($btnExport,$btnLoadXP,$txtXP))

# ----- MISSIONS -----
$tbMid    = New-Object Windows.Forms.TextBox; $tbMid.Location='20,16'; $tbMid.Size='80,24'; $tbMid.PlaceholderText='Id (m##)'
$tbMxp    = New-Object Windows.Forms.TextBox; $tbMxp.Location='110,16'; $tbMxp.Size='60,24'; $tbMxp.PlaceholderText='XP'
$tbMtitle = New-Object Windows.Forms.TextBox; $tbMtitle.Location='180,16'; $tbMtitle.Size='360,24'; $tbMtitle.PlaceholderText='Title'
$btnAddM  = New-Object Windows.Forms.Button; $btnAddM.Text='Add'; $btnAddM.Location='550,14'; $btnAddM.Size='60,28'
$btnListM = New-Object Windows.Forms.Button; $btnListM.Text='List'; $btnListM.Location='620,14'; $btnListM.Size='60,28'
$btnCompM = New-Object Windows.Forms.Button; $btnCompM.Text='Complete'; $btnCompM.Location='690,14'; $btnCompM.Size='80,28'

$tbEditId = New-Object Windows.Forms.TextBox; $tbEditId.Location='20,52'; $tbEditId.Size='80,24'; $tbEditId.PlaceholderText='Id'
$tbEditXP = New-Object Windows.Forms.TextBox; $tbEditXP.Location='110,52'; $tbEditXP.Size='60,24'; $tbEditXP.PlaceholderText='XP'
$tbEditTitle = New-Object Windows.Forms.TextBox; $tbEditTitle.Location='180,52'; $tbEditTitle.Size='360,24'; $tbEditTitle.PlaceholderText='New title'
$btnUpdateM = New-Object Windows.Forms.Button; $btnUpdateM.Text='Update'; $btnUpdateM.Location='550,50'; $btnUpdateM.Size='60,28'
$btnRemoveM = New-Object Windows.Forms.Button; $btnRemoveM.Text='Remove'; $btnRemoveM.Location='620,50'; $btnRemoveM.Size='60,28'
$btnRefreshM = New-Object Windows.Forms.Button; $btnRefreshM.Text='Refresh'; $btnRefreshM.Location='690,50'; $btnRefreshM.Size='80,28'

$txtList = New-Object Windows.Forms.TextBox; $txtList.Location='20,86'; $txtList.Size='750,350'; $txtList.Multiline=$true; $txtList.ScrollBars='Vertical'; $txtList.Font=New-Object Drawing.Font('Consolas',9); $txtList.ReadOnly=$true
$tpMission.Controls.AddRange(@($tbMid,$tbMxp,$tbMtitle,$btnAddM,$btnListM,$btnCompM,$tbEditId,$tbEditXP,$tbEditTitle,$btnUpdateM,$btnRemoveM,$btnRefreshM,$txtList))

# ----- SETTINGS -----
$lblAliasS = New-Object Windows.Forms.Label; $lblAliasS.Text='Alias'; $lblAliasS.Location='20,20'; $lblAliasS.Size='80,20'
$tbAlias   = New-Object Windows.Forms.TextBox; $tbAlias.Location='120,18'; $tbAlias.Size='220,24'

$lblGoalS  = New-Object Windows.Forms.Label; $lblGoalS.Text='Daily goal (XP)'; $lblGoalS.Location='20,52'; $lblGoalS.Size='100,20'
$tbGoal    = New-Object Windows.Forms.TextBox; $tbGoal.Location='120,50'; $tbGoal.Size='80,24'

$cbNotify  = New-Object Windows.Forms.CheckBox; $cbNotify.Text='Enable notifications'; $cbNotify.Location='20,82'; $cbNotify.Size='200,22'

$btnLoadSet= New-Object Windows.Forms.Button; $btnLoadSet.Text='Load'; $btnLoadSet.Location='20,120'; $btnLoadSet.Size='80,30'
$btnSaveSet= New-Object Windows.Forms.Button; $btnSaveSet.Text='Save'; $btnSaveSet.Location='110,120'; $btnSaveSet.Size='80,30'
$btnRepair = New-Object Windows.Forms.Button; $btnRepair.Text='Repair Store'; $btnRepair.Location='200,120'; $btnRepair.Size='110,30'

$tpSet.Controls.AddRange(@($lblAliasS,$tbAlias,$lblGoalS,$tbGoal,$cbNotify,$btnLoadSet,$btnSaveSet,$btnRepair))

# ----- FUNCTIONS -----
function Refresh-Status {
  $j = Read-Mirror
  $u = $j.user
  $pb.Value = [Math]::Min(100,[Math]::Max(0,[int]$u.progressPct))
  $lblAlias.Text  = "Alias: $($u.alias)"
  $lblRank.Text   = "Rank:  $($u.rank)"
  $lblXP.Text     = "XP:    $([int]$u.xp)"
  $lblProg.Text   = "Progress: $([int]$u.progressPct)%"
  $lblStreak.Text = "Streak: $([int]$u.streakCurrent) (best $([int]$u.streakLongest))"
  $lblBadges.Text = "Badges: $([int]$u.badges)"
  $lblUpdated.Text= "Updated: $($j.updated)"

  $t = $j.targets
  if ($t) {
    $lblGoal.Text = "Daily goal: $([int]$t.dailyGoal) XP"
    $lblTGoal.Text = "Goal: $([int]$t.dailyGoal) XP"
    $lblTProg.Text = "Today: $([int]$t.xpToday)  |  Remaining: $([int]$t.xpRemaining)"
    $lstSuggest.Items.Clear()
    foreach ($sug in $t.suggestions) {
      $it = New-Object Windows.Forms.ListViewItem($sug.id)
      $null = $it.SubItems.Add($sug.title)
      $null = $it.SubItems.Add([string][int]$sug.xp)
      $null = $lstSuggest.Items.Add($it)
    }
  }
}

function Load-Log {
  $txtXP.Text = Invoke-CLI @('badges') + "`r`n---- XP ----`r`n" + (Get-Content -Raw (Join-Path $DataDir 'store.plasma'))
}
function Alert([string]$title,[string]$body) { [Windows.Forms.MessageBox]::Show($body,$title,'OK','Information') | Out-Null }

# ----- EVENTS -----
$btnRefresh.Add_Click({ Refresh-Status })
$btnBackup.Add_Click({ Alert 'Backup' (Invoke-CLI @('backup')) ; Refresh-Status })
$btnRestoreLatest.Add_Click({ Alert 'Restore Latest' (Invoke-CLI @('restore','latest')) ; Refresh-Status })
$btnRestorePick.Add_Click({
  $dlg = New-Object Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $DataDir
  $dlg.Filter = "Backup (*.json)|store*.json|All files (*.*)|*.*"
  if ($dlg.ShowDialog() -eq 'OK') { Alert 'Restore From File' (Invoke-CLI @('restore', $dlg.FileName)); Refresh-Status }
})
$btnOpenDash.Add_Click({ Start-Process (Join-Path $WwwDir 'index.html') })
$btnOpenData.Add_Click({ Start-Process $DataDir })

$btnExport.Add_Click({ $dest = Invoke-CLI @('export'); Alert 'Export XP' $dest })
$btnLoadXP.Add_Click({ Load-Log })

$btnAddM.Add_Click({
  $id=$tbMid.Text; $xp=0; [void][int]::TryParse($tbMxp.Text,[ref]$xp); $title=$tbMtitle.Text
  if ([string]::IsNullOrWhiteSpace($id) -or $xp -le 0 -or [string]::IsNullOrWhiteSpace($title)) { Alert 'Add Mission' 'Fill Id, XP (>0), and Title.'; return }
  Alert 'Add Mission' (Invoke-CLI @('mission','add',$id,"$xp",$title))
  $tbMid.Clear(); $tbMxp.Clear(); $tbMtitle.Clear()
  Refresh-Status
})
$btnListM.Add_Click({ $txtList.Text = Invoke-CLI @('mission','list') })
$btnCompM.Add_Click({
  $id = if ($lstSuggest.SelectedItems.Count -gt 0) { $lstSuggest.SelectedItems[0].Text } else { $tbMid.Text }
  if ([string]::IsNullOrWhiteSpace($id)) { Alert 'Complete' 'Enter Id or select from suggestions.'; return }
  Alert 'Complete Mission' (Invoke-CLI @('mission','complete',$id))
  Refresh-Status
})
$btnUpdateM.Add_Click({
  $id=$tbEditId.Text; $xp=0; [void][int]::TryParse($tbEditXP.Text,[ref]$xp); $title=$tbEditTitle.Text
  if ([string]::IsNullOrWhiteSpace($id) -or ($xp -le 0 -and [string]::IsNullOrWhiteSpace($title))) { Alert 'Update Mission' 'Provide Id and either XP (>0) and/or Title.'; return }
  if ($xp -le 0) { $xp = 0 }
  Alert 'Update Mission' (Invoke-CLI @('mission','update',$id,"$xp",$title))
  Refresh-Status
})
$btnRemoveM.Add_Click({
  $id=$tbEditId.Text
  if ([string]::IsNullOrWhiteSpace($id)) { Alert 'Remove Mission' 'Enter Id.'; return }
  Alert 'Remove Mission' (Invoke-CLI @('mission','remove',$id))
  Refresh-Status
})
$btnRefreshM.Add_Click({ $txtList.Text = Invoke-CLI @('mission','list') })

$btnLoadSet.Add_Click({
  $s = Invoke-CLI @('settings','get')
  $tbAlias.Text = ($s -split "`n" | Where-Object { $_ -match 'alias\s*:\s*' } | ForEach-Object { ($_ -split ':',2)[1].Trim() }) | Select-Object -First 1
  $tbGoal.Text  = ($s -split "`n" | Where-Object { $_ -match 'dailyGoal\s*:\s*' } | ForEach-Object { ($_ -split ':',2)[1].Trim() }) | Select-Object -First 1
  $cbNotify.Checked = (($s -split "`n" | Where-Object { $_ -match 'notify\s*:\s*' } | ForEach-Object { ($_ -split ':',2)[1].Trim() }) | Select-Object -First 1) -eq 'True'
})
$btnSaveSet.Add_Click({
  $alias = $tbAlias.Text; $goal=0; [void][int]::TryParse($tbGoal.Text,[ref]$goal); $notify = if ($cbNotify.Checked) { 'true' } else { 'false' }
  if ($goal -le 0) { $goal = 200 }
  $out = Invoke-CLI @('settings','set','alias',$alias,'dailyGoal',"$goal",'notify',$notify)
  Alert 'Settings' $out
  Refresh-Status
})
$btnRepair.Add_Click({ Alert 'Repair' (Invoke-CLI @('repair')); Refresh-Status })

# auto-refresh timer
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({ Refresh-Status })
$timer.Start()

# event watcher (fixed constructor & path)
$fsw = New-Object IO.FileSystemWatcher
$fsw.Path = $EventsDir
$fsw.Filter = 'notify.log'
$fsw.IncludeSubdirectories = $false
$fsw.EnableRaisingEvents = $true
$fsw.add_Changed({
  try {
    $last = Get-Content -Tail 1 -Path $Events
    if ($last) {
      $parts = $last -split '\s\|\s',3
      [Windows.Forms.MessageBox]::Show($parts[2],$parts[1]) | Out-Null
    }
  } catch {}
})

Refresh-Status
[void][Windows.Forms.Application]::Run($form)
