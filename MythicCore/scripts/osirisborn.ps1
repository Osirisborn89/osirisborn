#requires -Version 7.0
$ErrorActionPreference = 'Stop'

# =========================
# MythicCore CLI (self-contained)
# Store:   %USERPROFILE%\Osirisborn\MythicCore\data\store.plasma
# Mirror:  %USERPROFILE%\Osirisborn\MythicCore\www\mirror.json
# Features: XP, Missions, Streaks, Badges (all ranks), Backup/Restore,
#           Notifications, XP Log Export, Targets, Settings, Repair (schema v2)
# NOTE: No FileSystemWatcher here (GUI handles that)
# =========================

# ---- Paths
$Root        = Join-Path $env:USERPROFILE 'Osirisborn\MythicCore'
$DataDir     = Join-Path $Root 'data'
$ScriptsDir  = Join-Path $Root 'scripts'
$WwwDir      = Join-Path $Root 'www'
$DataPath    = Join-Path $DataDir 'store.plasma'
$MirrorPath  = Join-Path $WwwDir  'mirror.json'
$EventsDir   = Join-Path $DataDir 'events'   # used for fallback notifications

# ---- Ensure folders
foreach ($d in @($Root,$DataDir,$ScriptsDir,$WwwDir,$EventsDir)) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# ---- Rank ladder + thresholds
$Ranks = @("Initiate","Ghost","Signal Diver","Network Phantom","Redline Operative","Shadow Architect","Spectral Engineer","Elite","Voidbreaker","God Tier: Osirisborn")
$RankThresholds = @{
  "Initiate"=0; "Ghost"=200; "Signal Diver"=600; "Network Phantom"=1200; "Redline Operative"=2000;
  "Shadow Architect"=3000; "Spectral Engineer"=4500; "Elite"=6500; "Voidbreaker"=9000; "God Tier: Osirisborn"=12000
}

function Get-Progress([int]$xp,[string]$rank) {
  $idx = [Math]::Max(0, $Ranks.IndexOf($rank))
  $curr = $RankThresholds[$Ranks[$idx]]
  $nextRank = if ($idx -lt $Ranks.Count-1) { $Ranks[$idx+1] } else { $Ranks[$idx] }
  $next = $RankThresholds[$nextRank]
  $span = [Math]::Max(1, $next - $curr)
  $pct = [int][Math]::Clamp(100*($xp-$curr)/$span,0,100)
  [pscustomobject]@{ CurrentRank=$Ranks[$idx]; NextRank=$nextRank; ProgressPct=$pct; ToNext=[Math]::Max(0,$next-$xp) }
}

# ---- Utilities
function ConvertTo-Hashtable([object]$obj) {
  if ($obj -is [hashtable]) { return $obj }
  $ht = @{}
  if ($null -ne $obj) { foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value } }
  return $ht
}
function Ensure-Prop([object]$obj,[string]$name,$default) {
  if ($null -eq $obj) { return }
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p) { Add-Member -InputObject $obj -NotePropertyName $name -NotePropertyValue $default -Force | Out-Null }
  elseif ($null -eq $p.Value) { $p.Value = $default }
}
function Ensure-Array([object]$obj,[string]$name) {
  Ensure-Prop $obj $name @()
  $p = $obj.PSObject.Properties[$name]
  if ($null -eq $p.Value -or -not ($p.Value -is [System.Collections.IList])) { $p.Value = @() }
}
function Today-Stamp { (Get-Date).ToString('yyyy-MM-dd') }

# ---- Store helpers (JSON)
function New-BareStoreObject {
  [pscustomobject]@{
    meta     = [pscustomobject]@{
      version = 2
      xpLog   = @()
      badges  = @()
      streak  = [pscustomobject]@{ current=0; longest=0; lastDate="" }
    }
    user     = [pscustomobject]@{ alias="Osirisborn"; rank="Initiate"; xp=0; progressPct=0 }
    missions = [pscustomobject]@{ catalog=@{}; completed=@(); inProgress=@() }
    settings = [pscustomobject]@{ notify=$true; dailyGoal=200 }
  }
}

function Initialize-Store { if (-not (Test-Path $DataPath)) { (New-BareStoreObject) | ConvertTo-Json -Depth 20 | Set-Content -Path $DataPath -Encoding UTF8 } }

function Migrate-Store([object]$s) {
  # --- meta ---
  Ensure-Prop $s 'meta' ([pscustomobject]@{})
  Ensure-Prop $s.meta 'version' 2
  Ensure-Array $s.meta 'xpLog'
  Ensure-Array $s.meta 'badges'
  Ensure-Prop $s.meta 'streak' ([pscustomobject]@{ current=0; longest=0; lastDate="" })

  # --- user ---
  Ensure-Prop $s 'user' ([pscustomobject]@{ alias="Osirisborn"; rank="Initiate"; xp=0; progressPct=0 })

  # --- missions ---
  Ensure-Prop $s 'missions' ([pscustomobject]@{})
  $s.missions.catalog = ConvertTo-Hashtable $s.missions.catalog
  Ensure-Array $s.missions 'completed'
  Ensure-Array $s.missions 'inProgress'

  # --- settings (create properties before assigning) ---
  Ensure-Prop $s 'settings' ([pscustomobject]@{})
  Ensure-Prop $s.settings 'notify' $true
  Ensure-Prop $s.settings 'dailyGoal' 200
  if ([int]$s.settings.dailyGoal -le 0) { $s.settings.dailyGoal = 200 }

  $s.meta.version = 2
  return $s
}

function Get-Store {
  Initialize-Store
  try {
    $raw = Get-Content -Raw -Path $DataPath -ErrorAction Stop
    if (-not $raw) { throw "empty" }
    $obj = $raw | ConvertFrom-Json
  } catch {
    $obj = New-BareStoreObject
    $obj | ConvertTo-Json -Depth 20 | Set-Content -Path $DataPath -Encoding UTF8
  }
  Migrate-Store $obj | Out-Null
  return $obj
}

# file lock + atomic save
$script:Mutex = [System.Threading.Mutex]::new($false,'Global\OsirisbornStoreLock')
function Save-Store([object]$s) {
  try {
    [void]$script:Mutex.WaitOne(3000)
    $tmp = Join-Path $DataDir ('store.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $s | ConvertTo-Json -Depth 20 | Set-Content -Path $tmp -Encoding UTF8
    Move-Item -Force -Path $tmp -Destination $DataPath
  } finally { $script:Mutex.ReleaseMutex() | Out-Null }

  # compute today's targets for mirror
  $targets = Compute-TodayTargets $s

  $mirror = [pscustomobject]@{
    user    = [pscustomobject]@{
      xp = [int]$s.user.xp; rank = $s.user.rank; alias = $s.user.alias; progressPct = [int]$s.user.progressPct
      streakCurrent = [int]$s.meta.streak.current; streakLongest = [int]$s.meta.streak.longest; badges = [int]$s.meta.badges.Count
    }
    targets = $targets
    updated = (Get-Date).ToString("o")
  }
  $mirror | ConvertTo-Json -Depth 20 | Set-Content -Path $MirrorPath -Encoding UTF8
}

# ---- Badges / Streaks / Notifications
function Award-Badge([object]$s,[string]$id,[string]$title) {
  Ensure-Array $s.meta 'badges'
  if (-not ($s.meta.badges | Where-Object { $_.id -eq $id })) {
    $s.meta.badges = @($s.meta.badges + ([pscustomobject]@{ id=$id; title=$title; at=(Get-Date).ToString("o") }))
  }
}
function Award-RankBadge([object]$s,[string]$rank) {
  $id = 'rank-' + ($rank.ToLower() -replace '[^a-z0-9]+','-')
  Award-Badge $s $id ("Reached " + $rank)
}
function Update-Streak([object]$s,[datetime]$now) {
  Ensure-Prop $s.meta 'streak' ([pscustomobject]@{ current=0; longest=0; lastDate="" })
  $today = $now.Date
  $lastStr = $s.meta.streak.lastDate
  if ([string]::IsNullOrWhiteSpace($lastStr)) {
    $s.meta.streak.current = 1
    $s.meta.streak.longest = [Math]::Max(1,[int]$s.meta.streak.longest)
    $s.meta.streak.lastDate = $today.ToString('yyyy-MM-dd')
    return
  }
  $last = [datetime]::ParseExact($lastStr,'yyyy-MM-dd',$null)
  $delta = ( $today - $last ).Days
  if ($delta -eq 0) { return }
  if ($delta -eq 1) { $s.meta.streak.current++ } else { $s.meta.streak.current = 1 }
  if ($s.meta.streak.current -gt $s.meta.streak.longest) { $s.meta.streak.longest = $s.meta.streak.current }
  $s.meta.streak.lastDate = $today.ToString('yyyy-MM-dd')
  switch ($s.meta.streak.current) {
    3 { Award-Badge $s 'streak-3'  '3-Day Streak' }
    7 { Award-Badge $s 'streak-7'  '7-Day Streak' }
    14 { Award-Badge $s 'streak-14' '14-Day Streak' }
    30 { Award-Badge $s 'streak-30' '30-Day Streak' }
  }
}
function Show-Notification([string]$title,[string]$msg,[switch]$Silent) {
  if ($Silent) { return }
  try { $s = Get-Store; if ($s.settings.notify -ne $true) { return } } catch {}
  try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows, ContentType = WindowsRuntime]
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$msg</text></binding></visual></toast>")
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Osirisborn.MythicCore')
    $notifier.Show($toast); return
  } catch {}
  try {
    $line = ('{0} | {1} | {2}' -f (Get-Date).ToString('o'), $title, $msg)
    Add-Content -Path (Join-Path $EventsDir 'notify.log') -Value $line -Encoding UTF8
  } catch {}
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information
    $ni.Visible = $true
    $ni.BalloonTipTitle = $title
    $ni.BalloonTipText  = $msg
    $ni.ShowBalloonTip(3000)
    Start-Sleep -Milliseconds 500
    $ni.Dispose()
  } catch {}
}

# ---- XP operations
function Add-XP([int]$Points,[string]$Reason="Generic") {
  $s = Get-Store
  Ensure-Prop $s 'user' ([pscustomobject]@{})
  if (-not $s.user.alias) { $s.user.alias = "Osirisborn" }
  if (-not $s.user.rank)  { $s.user.rank  = "Initiate" }
  if ($null -eq $s.user.xp) { $s.user.xp = 0 }
  if ($null -eq $s.user.progressPct) { $s.user.progressPct = 0 }

  $preRank = $s.user.rank
  $s.user.xp = [int]([int]$s.user.xp + $Points)

  for ($i=[Math]::Max(0,$Ranks.IndexOf($s.user.rank)); $i -lt $Ranks.Count; $i++) {
    $r = $Ranks[$i]; if ($s.user.xp -ge $RankThresholds[$r]) { $s.user.rank = $r } else { break }
  }

  $pg = Get-Progress -xp ([int]$s.user.xp) -rank $s.user.rank
  $s.user.progressPct = $pg.ProgressPct

  Ensure-Prop $s 'meta' ([pscustomobject]@{})
  Ensure-Array $s.meta 'xpLog'
  Ensure-Array $s.meta 'badges'
  Ensure-Prop  $s.meta 'streak' ([pscustomobject]@{current=0;longest=0;lastDate=""})

  Update-Streak $s (Get-Date)

  if ($s.user.xp -ge 1) { Award-Badge $s 'first-blood' 'First XP' }
  if ($s.user.rank) { Award-RankBadge $s $s.user.rank }

  $entry = [pscustomobject]@{ at=(Get-Date).ToString("o"); delta=$Points; reason=$Reason; total=$s.user.xp; rank=$s.user.rank }
  $s.meta.xpLog = @($s.meta.xpLog + $entry)

  Save-Store $s

  Show-Notification "XP +$Points" $Reason
  if ($s.user.rank -ne $preRank) { Show-Notification "Rank Up!" "New rank: $($s.user.rank)" }

  return $pg
}

function Get-XP {
  $s = Get-Store
  Ensure-Prop $s 'user' ([pscustomobject]@{ alias="Osirisborn"; rank="Initiate"; xp=0; progressPct=0 })
  $pg = Get-Progress -xp ([int]$s.user.xp) -rank $s.user.rank
  [pscustomobject]@{ Alias=$s.user.alias; Rank=$s.user.rank; XP=[int]$s.user.xp; Next=$pg.NextRank; ProgressPct=[int]$pg.ProgressPct; ToNext=[int]$pg.ToNext }
}

# ---- Missions
function Ensure-MissionState([object]$s) {
  Ensure-Prop $s 'missions' ([pscustomobject]@{})
  $s.missions.catalog = ConvertTo-Hashtable $s.missions.catalog
  Ensure-Array $s.missions 'completed'
  Ensure-Array $s.missions 'inProgress'
}
function Add-Mission([string]$Id,[string]$Title,[int]$XP) {
  $s = Get-Store
  Ensure-MissionState $s
  $s.missions.catalog[$Id] = [pscustomobject]@{ id=$Id; title=$Title; xp=$XP; created=(Get-Date).ToString("o") }
  if (-not ($s.missions.completed -contains $Id) -and -not ($s.missions.inProgress -contains $Id)) {
    $s.missions.inProgress = @($s.missions.inProgress + $Id)
  }
  Save-Store $s
  [pscustomobject]@{ Id=$Id; Title=$Title; XP=[int]$XP }
}
function Update-Mission([string]$Id,[int]$XP,[string]$Title) {
  $s = Get-Store
  Ensure-MissionState $s
  $key = ($s.missions.catalog.Keys | Where-Object { $_ -ieq $Id } | Select-Object -First 1)
  if (-not $key) { throw "Mission not found: $Id" }
  $m = $s.missions.catalog[$key]
  if ($XP -gt 0) { $m.xp = [int]$XP }
  if ($Title) { $m.title = $Title }
  $s.missions.catalog[$key] = $m
  Save-Store $s
  [pscustomobject]@{ Id=$key; Title=$m.title; XP=[int]$m.xp }
}
function Remove-Mission([string]$Id) {
  $s = Get-Store
  Ensure-MissionState $s
  $key = ($s.missions.catalog.Keys | Where-Object { $_ -ieq $Id } | Select-Object -First 1)
  if (-not $key) { return "Not found." }
  $null = $s.missions.catalog.Remove($key)
  $s.missions.completed  = @($s.missions.completed  | Where-Object { $_ -ne $key })
  $s.missions.inProgress = @($s.missions.inProgress | Where-Object { $_ -ne $key })
  Save-Store $s
  "Removed '$key'."
}
function Get-Missions {
  $s = Get-Store
  Ensure-MissionState $s
  $items = foreach ($k in $s.missions.catalog.Keys) {
    $m = $s.missions.catalog[$k]
    $status = if ($s.missions.completed -contains $k) { "Completed" }
              elseif ($s.missions.inProgress -contains $k) { "In Progress" }
              else { "New" }
    [pscustomobject]@{ Id=$m.id; Title=$m.title; XP=[int]$m.xp; Status=$status }
  }
  $items | Sort-Object Status, Id
}
function Complete-Mission([string]$Id) {
  $s = Get-Store
  Ensure-MissionState $s
  $key = ($s.missions.catalog.Keys | Where-Object { $_ -ieq $Id } | Select-Object -First 1)
  if (-not $key) {
    if ($s.missions.completed -icontains $Id) { return "Already completed." }
    throw "Mission not found: $Id"
  }
  if ($s.missions.completed -contains $key) { return "Already completed." }

  $preCount = $s.missions.completed.Count
  $s.missions.inProgress = @($s.missions.inProgress | Where-Object { $_ -ne $key })
  $s.missions.completed  = @($s.missions.completed  + $key)
  if ($preCount -eq 0) { Award-Badge $s 'first-mission' 'Mission Accomplished' }
  $xpAward = [int]$s.missions.catalog[$key].xp
  Save-Store $s
  $p = Add-XP -Points $xpAward -Reason "Mission: $key"
  Show-Notification "Mission Complete" "$key +$xpAward XP"
  "Completed '$key' (+$xpAward XP) → $($p.CurrentRank) $($p.ProgressPct)% toward $($p.NextRank)"
}

# ---- Targets (daily goal + suggestions)
function Compute-TodayTargets([object]$s) {
  $goal = [int]$s.settings.dailyGoal
  if ($goal -le 0) { $goal = 200 }
  $today = Today-Stamp
  $xpToday = 0
  foreach ($e in $s.meta.xpLog) {
    try { if ([datetime]::Parse($e.at).ToString('yyyy-MM-dd') -eq $today) { $xpToday += [int]$e.delta } } catch {}
  }
  $remain = [Math]::Max(0, $goal - $xpToday)
  $suggest = @()
  if ($remain -gt 0) {
    $sum = 0
    $cands = @()
    foreach ($k in $s.missions.inProgress) {
      if ($s.missions.catalog.ContainsKey($k)) { $cands += $s.missions.catalog[$k] }
    }
    $cands = $cands | Sort-Object xp -Descending
    foreach ($m in $cands) {
      $suggest += [pscustomobject]@{ id=$m.id; title=$m.title; xp=[int]$m.xp }
      $sum += [int]$m.xp
      if ($sum -ge $remain) { break }
    }
  }
  [pscustomobject]@{ dailyGoal=$goal; xpToday=[int]$xpToday; xpRemaining=[int]$remain; suggestions=$suggest }
}

# ---- Settings
function Get-Settings { (Get-Store).settings }
function Set-Settings([string[]]$kv) {
  $s = Get-Store
  # make sure settings has the properties we will set
  Ensure-Prop $s 'settings' ([pscustomobject]@{})
  Ensure-Prop $s.settings 'dailyGoal' 200
  Ensure-Prop $s.settings 'notify' $true

  for ($i=0; $i -lt $kv.Count; $i+=2) {
    $name = ($kv[$i]).ToLowerInvariant()
    $val  = if ($i+1 -lt $kv.Count) { $kv[$i+1] } else { $null }
    switch ($name) {
      'alias'     { if ($val) { $s.user.alias = $val } }
      'dailygoal' { if ($val -match '^\d+$') { $s.settings.dailyGoal = [int]$val } }
      'notify'    { if ($val) { $s.settings.notify = [bool]::Parse($val) } }
    }
  }

  Save-Store $s
  $s.settings
}

# ---- Backup / Restore / Export / Repair
function Backup-Store {
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $dest = Join-Path $DataDir "store.$stamp.json"
  Copy-Item -Path $DataPath -Destination $dest -Force; $dest
}
function Restore-Store([string]$BackupSpec) {
  $file = $null
  if ([string]::IsNullOrWhiteSpace($BackupSpec) -or $BackupSpec.ToLower() -eq 'latest') {
    $file = Get-ChildItem (Join-Path $DataDir 'store.*.json') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $file) { throw "No backups found in $DataDir" }
    $file = $file.FullName
  } else { $file = $BackupSpec }
  if (-not (Test-Path $file)) { throw "Backup not found: $file" }
  Copy-Item -Path $file -Destination $DataPath -Force
  $s = Get-Store; Save-Store $s
  "Restored from $file"
}
function Export-XpCsv([string]$Path) {
  $s = Get-Store
  $out = if ($Path) { $Path } else { Join-Path $DataDir ('xp-log-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.csv') }
  $s.meta.xpLog | Select-Object at,delta,reason,total,rank | Export-Csv -Path $out -NoTypeInformation -Encoding UTF8
  $out
}
function Repair-Store {
  $s = Get-Store
  Migrate-Store $s | Out-Null
  Save-Store $s
  "Repair OK (schema v2)"
}

# ---- Command router
$cmd = if ($args.Count -ge 1) { ([string]$args[0]).ToLowerInvariant() } else { 'xp' }

switch ($cmd) {

  'xp' {
    if ($args.Count -ge 2 -and $args[1] -match '^\-?\d+$') {
      $delta  = [int]$args[1]
      $reason = if ($args.Count -ge 3) { ($args[2..($args.Count-1)] -join ' ') } else { 'Manual Adjust' }
      $p = Add-XP -Points $delta -Reason $reason
      Write-Host "XP +$delta ($reason) → $($p.CurrentRank) → $($p.ProgressPct)% toward $($p.NextRank) (to next: $($p.ToNext))" -ForegroundColor Cyan
    } else {
      $o = Get-XP
      "{0} — Rank: {1}, XP: {2}, {3}% toward {4} (to next: {5})" -f $o.Alias,$o.Rank,$o.XP,$o.ProgressPct,$o.Next,$o.ToNext
    }
    break
  }

  'mission' {
    if ($args.Count -lt 2) { throw "Usage: mission <add|list|complete|update|remove> ..." }
    $sub = ([string]$args[1]).ToLowerInvariant()
    switch ($sub) {
      'add'      { if ($args.Count -lt 5) { throw "Usage: mission add <id> <xp> <title...>" }
                   $id=$args[2]; $xp=[int]$args[3]; $ttl=($args[4..($args.Count-1)] -join ' ')
                   Add-Mission -Id $id -Title $ttl -XP $xp | Format-List; break }
      'list'     { Get-Missions | Format-Table -AutoSize; break }
      'complete' { if ($args.Count -lt 3) { throw "Usage: mission complete <id>" }
                   $id=$args[2]; Complete-Mission -Id $id | Out-Host; break }
      'update'   { if ($args.Count -lt 5) { throw "Usage: mission update <id> <xp> <title...>" }
                   $id=$args[2]; $xp=[int]$args[3]; $ttl=($args[4..($args.Count-1)] -join ' ')
                   Update-Mission -Id $id -XP $xp -Title $ttl | Format-List; break }
      'remove'   { if ($args.Count -lt 3) { throw "Usage: mission remove <id>" }
                   $id=$args[2]; Remove-Mission -Id $id | Out-Host; break }
      default    { "Usage: mission <add|list|complete|update|remove> ..." }
    }
    break
  }

  'rank'     { Get-XP | Format-List; break }
  'badges'   { (Get-Store).meta.badges | Sort-Object at | Format-Table id,title,at -AutoSize; break }
  'streak'   { (Get-Store).meta.streak | Format-List; break }
  'backup'   {
    if ($args.Count -ge 2 -and ($args[1]).ToLowerInvariant() -eq 'list') {
      Get-ChildItem (Join-Path $DataDir 'store.*.json') | Sort-Object LastWriteTime -Descending | Select-Object LastWriteTime,Length,FullName | Format-Table -AutoSize
    } else { $p = Backup-Store; "Backup created: $p" }
    break
  }
  'restore'  { $spec = if ($args.Count -ge 2) { $args[1] } else { 'latest' }; Restore-Store $spec | Out-Host; break }
  'export'   { $dest = if ($args.Count -ge 2) { $args[1] } else { '' }; $p = Export-XpCsv $dest; "XP log exported: $p" }
  'settings' {
    if ($args.Count -lt 2) { Get-Settings | Format-List; break }
    $sub = ($args[1]).ToLowerInvariant()
    switch ($sub) {
      'get' { Get-Settings | Format-List; break }
      'set' { if ($args.Count -lt 4) { throw "Usage: settings set alias <name> dailyGoal <n> notify <true|false> (any order)" }
              $res = Set-Settings -kv $args[2..($args.Count-1)]
              $res | Format-List; break }
      default { Get-Settings | Format-List }
    }
    break
  }
  'repair'  { Repair-Store | Out-Host; break }
  'open'    { Start-Process (Join-Path $WwwDir 'index.html'); break }
  default   { "Unknown command: $cmd" }
}
