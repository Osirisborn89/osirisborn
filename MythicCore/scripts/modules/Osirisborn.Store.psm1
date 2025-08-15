#requires -Version 7.0
$ErrorActionPreference = 'Stop'

# --- Paths (modules lives in scripts\modules) ---
$Script:ModulesDir = $PSScriptRoot
$Script:ScriptsDir = Split-Path -Parent $Script:ModulesDir
$Script:RootDir    = Split-Path -Parent $Script:ScriptsDir
$Script:DataDir    = Join-Path $Script:RootDir 'data'
$Script:WwwDir     = Join-Path $Script:RootDir 'www'
$Script:StoreFile  = Join-Path $Script:DataDir 'store.plasma'
$Script:MirrorFile = Join-Path $Script:WwwDir  'mirror.json'
$Script:EventsFile = Join-Path $Script:DataDir 'notify.log'

function Ensure-Dir([string]$Path){
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function New-DefaultStore {
  [pscustomobject]@{
    meta     = [pscustomobject]@{ xpLog = @() }
    user     = [pscustomobject]@{
      alias       = 'Osirisborn'
      rank        = 'Initiate'
      xp          = 0
      progressPct = 0
    }
    missions = [pscustomobject]@{
      catalog    = @{}
      completed  = @()
      inProgress = @()
    }
    settings = [pscustomobject]@{
      dailyGoal = 200
      notify    = $true
    }
  }
}

function Initialize-OsStore {
  Ensure-Dir $Script:RootDir
  Ensure-Dir $Script:DataDir
  Ensure-Dir $Script:WwwDir

  if (-not (Test-Path $Script:StoreFile)) {
    $s = New-DefaultStore
    Save-OsStore -Store $s | Out-Null
  } else {
    # heal structure if older file exists
    $s = Get-OsStore
    if (-not $s.meta)     { $s | Add-Member -NotePropertyName meta     -NotePropertyValue ([pscustomobject]@{ xpLog=@() }) -Force }
    if (-not $s.meta.xpLog){ $s.meta | Add-Member -NotePropertyName xpLog -NotePropertyValue @() -Force }
    if (-not $s.user)     { $s | Add-Member -NotePropertyName user     -NotePropertyValue ([pscustomobject]@{ alias='Osirisborn'; rank='Initiate'; xp=0; progressPct=0 }) -Force }
    if ($null -eq $s.user.progressPct) { $s.user.progressPct = 0 }
    if (-not $s.missions) { $s | Add-Member -NotePropertyName missions -NotePropertyValue ([pscustomobject]@{ catalog=@{}; completed=@(); inProgress=@() }) -Force }
    if (-not $s.settings) { $s | Add-Member -NotePropertyName settings -NotePropertyValue ([pscustomobject]@{ dailyGoal=200; notify=$true }) -Force }
    Save-OsStore -Store $s | Out-Null
  }
  return Get-OsStore
}

function Get-OsStore {
  if (-not (Test-Path $Script:StoreFile)) { Initialize-OsStore | Out-Null }
  $raw = Get-Content -Raw -Path $Script:StoreFile
  $obj = if ($raw) { $raw | ConvertFrom-Json } else { New-DefaultStore }
  # Normalize common fields to avoid type surprises
  if ($null -eq $obj.user.xp) { $obj.user.xp = 0 }
  if ($null -eq $obj.user.rank) { $obj.user.rank = 'Initiate' }
  if ($null -eq $obj.user.progressPct) { $obj.user.progressPct = 0 }
  if (-not $obj.meta) { $obj | Add-Member -NotePropertyName meta -NotePropertyValue ([pscustomobject]@{ xpLog=@() }) -Force }
  if (-not $obj.meta.xpLog) { $obj.meta | Add-Member -NotePropertyName xpLog -NotePropertyValue @() -Force }
  if (-not $obj.missions) { $obj | Add-Member -NotePropertyName missions -NotePropertyValue ([pscustomobject]@{ catalog=@{}; completed=@(); inProgress=@() }) -Force }
  if (-not $obj.settings) { $obj | Add-Member -NotePropertyName settings -NotePropertyValue ([pscustomobject]@{ dailyGoal=200; notify=$true }) -Force }
  return $obj
}

function Write-Mirror([psobject]$Store){
  # Compute today's XP for the mirror
  $byDay = @{}
  foreach($e in @($Store.meta.xpLog)){
    try{
      $d = [datetime]::Parse($e.at).ToString('yyyy-MM-dd')
      $byDay[$d] = [int]($byDay[$d] + [int]$e.delta)
    }catch{}
  }
  $today = (Get-Date).ToString('yyyy-MM-dd')
  $xpToday = [int]($byDay[$today] ?? 0)
  $goal = [int]($Store.settings.dailyGoal ?? 200)

  $mirror = [pscustomobject]@{
    user = [pscustomobject]@{
      xp          = [int]$Store.user.xp
      rank        = $Store.user.rank
      alias       = $Store.user.alias
      progressPct = [int]$Store.user.progressPct
      streakCurrent = [int]($Store.user.streakCurrent ?? 0)
      streakLongest = [int]($Store.user.streakLongest ?? 0)
      badges        = [int](@($Store.meta.badges).Count)
    }
    targets = [pscustomobject]@{
      dailyGoal   = $goal
      xpToday     = $xpToday
      xpRemaining = [Math]::Max(0, $goal - $xpToday)
      suggestions = @()
    }
    updated = (Get-Date).ToString('o')
  }

  $mirror | ConvertTo-Json -Depth 30 | Set-Content -Path $Script:MirrorFile -Encoding UTF8
}

function Save-OsStore {
  param(
    [Parameter(Mandatory=$true, Position=0)]
    [psobject]$Store
  )
  Ensure-Dir $Script:DataDir
  Ensure-Dir $Script:WwwDir
  $json = $Store | ConvertTo-Json -Depth 50
  Set-Content -Path $Script:StoreFile -Value $json -Encoding UTF8
  Write-Mirror -Store $Store
  # lightweight notify hook
  "$(Get-Date -Format o) saved" | Add-Content -Path $Script:EventsFile -Encoding UTF8
  return $Store
}

function Backup-OsStore {
  Initialize-OsStore | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $dest  = Join-Path $Script:DataDir "store.$stamp.json"
  Copy-Item $Script:StoreFile $dest -Force
  Write-Output $dest
}

function Restore-OsStore {
  param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile
  )
  if ($BackupFile -eq 'latest') {
    $latest = Get-ChildItem $Script:DataDir -Filter 'store.*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { throw "No backups found in $Script:DataDir" }
    $BackupFile = $latest.FullName
  }
  if (-not (Test-Path $BackupFile)) { throw "Backup not found: $BackupFile" }
  Copy-Item $BackupFile $Script:StoreFile -Force
  $s = Get-OsStore
  Save-OsStore -Store $s | Out-Null
  Write-Output $BackupFile
}

Export-ModuleMember -Function Initialize-OsStore,Get-OsStore,Save-OsStore,Backup-OsStore,Restore-OsStore
