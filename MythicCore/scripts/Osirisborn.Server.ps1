#requires -Version 7.0
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root    = Split-Path $ScriptRoot -Parent
$Modules = Join-Path $ScriptRoot 'modules'
$Www     = Join-Path $Root 'www'
$DataDir = Join-Path $Root 'data'
$Mirror  = Join-Path $Www 'mirror.json'

. (Join-Path $Modules 'Osirisborn.Store.psm1')
. (Join-Path $Modules 'Osirisborn.XP.psm1')
. (Join-Path $Modules 'Osirisborn.Missions.psm1')

function Write-Json([System.Net.HttpListenerResponse]$res, $obj, [int]$status=200) {
  try {
    $res.StatusCode = $status
    $json  = ($obj | ConvertTo-Json -Depth 6)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $res.ContentType = 'application/json; charset=utf-8'
    $res.OutputStream.Write($bytes,0,$bytes.Length)
  } finally { $res.Close() }
}
function Write-File([System.Net.HttpListenerResponse]$res, [string]$path, [string]$contentType) {
  try {
    $bytes = [IO.File]::ReadAllBytes($path)
    $res.StatusCode = 200
    $res.ContentType = $contentType
    $res.OutputStream.Write($bytes,0,$bytes.Length)
  } finally { $res.Close() }
}
function Read-Body([System.Net.HttpListenerRequest]$req) {
  $sr   = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
  $text = $sr.ReadToEnd(); $sr.Close()
  if ([string]::IsNullOrWhiteSpace($text)) { return @{} }
  try { return $text | ConvertFrom-Json -Depth 6 } catch { return @{} }
}
function Summarize-XP([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore
  $end = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0, $Days-1))
  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }
  $log = if ($s.meta -and $s.meta.xpLog) { $s.meta.xpLog } else { @() }
  foreach ($e in $log) {
    try {
      $dt = [DateTime]::Parse($e.at)
      $key = $dt.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    } catch {}
  }
  $series = @(); $cum = 0
  foreach ($kv in ($buckets.GetEnumerator() | Sort-Object Name)) {
    $cum += [int]$kv.Value
    $series += [pscustomobject]@{ date=$kv.Key; xp=[int]$kv.Value; cumulative=$cum }
  }
  $nowKey  = (Get-Date).ToString('yyyy-MM-dd')
  $xpToday = if ($buckets.ContainsKey($nowKey)) { [int]$buckets[$nowKey] } else { 0 }
  $goal    = if ($s.settings -and $s.settings.dailyGoal) { [int]$s.settings.dailyGoal } else { 300 }
  $remain  = [Math]::Max(0, $goal - $xpToday)
  $o = Get-OsXP
  return @{
    days   = $Days
    series = $series
    summary = @{
      xpToday     = $xpToday
      dailyGoal   = $goal
      remaining   = $remain
      rank        = $o.Rank
      xp          = $o.XP
      progressPct = $o.ProgressPct
    }
  }
}

# Use 7780 to avoid any 7777 conflicts
$Port = 7780

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://+:$Port/")
$listener.Start()
Start-Process "http://localhost:$Port/"
Write-Host "Osirisborn server running → http://localhost:$Port/  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $req = $ctx.Request; $res = $ctx.Response
      $path = $req.Url.AbsolutePath
# ==== BEGIN LESSONS API GUARD (LESS-002) — SAFE ====
$__p = $path

function _bpGetRes {
  foreach ($n in 'context','ctx','httpContext','httpCtx') {
    $v = Get-Variable -Name $n -ErrorAction SilentlyContinue
    if ($v) { try { if ($v.Value -and $v.Value.Response) { return $v.Value.Response } } catch {} }
  }
  foreach ($n in 'Response','response','res') {
    $v = Get-Variable -Name $n -ErrorAction SilentlyContinue
    if ($v -and $v.Value) { return $v.Value }
  }
  return $null
}
function _bpSetProp($o,$name,$val){
  if ($null -ne $o -and ($o.PSObject.Properties.Name -contains $name)) {
    try { $o.$name = $val } catch {}
  }
}
function _bpWriteJson($obj, [int]$code = 200) {
  try { $json = $obj | ConvertTo-Json -Depth 12 } catch { $json = '{"error":"serialization"}' }
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $r = _bpGetRes
  _bpSetProp $r 'ContentType' 'application/json; charset=utf-8'
  _bpSetProp $r 'ContentLength64' $bytes.Length
  _bpSetProp $r 'StatusCode' $code
  try {
    if ($r -and $r.OutputStream) {
      $r.OutputStream.Write($bytes,0,$bytes.Length)
      $r.OutputStream.Close()
    } else {
      # last resort for unknown hosts: write to console/stdout
      [Console]::Out.WriteLine([Text.Encoding]::UTF8.GetString($bytes))
    }
  } catch {}
}

function _bpDataDir {
  if ($PSScriptRoot) { $root = $PSScriptRoot } else { $root = Split-Path -Parent $PSCommandPath }
  [IO.Path]::GetFullPath((Join-Path $root "..\data"))
}

if ($__p -eq "/api/lessons/summary") {
  try {
    $dataDir = _bpDataDir
    $currPath = Join-Path $dataDir "curriculum.json"
    $progPath = Join-Path $dataDir "progress.lessons.json"
    $tracks = @()

    if (Test-Path $currPath) {
      $curr = Get-Content $currPath -Raw | ConvertFrom-Json
      $prog = if (Test-Path $progPath) { Get-Content $progPath -Raw | ConvertFrom-Json } else { $null }

      foreach ($t in $curr.tracks) {
        $lessonsCount = 0
        foreach ($m in $t.modules) { $lessonsCount += @($m.lessons).Count }
        $completed = 0
        if ($prog -and ($prog.PSObject.Properties.Name -contains $t.id)) {
          $completed = @($prog.$($t.id).completedLessons).Count
        }
        $progress = if ($lessonsCount -gt 0) { [Math]::Round(($completed*100.0)/$lessonsCount) } else { 0 }
        $tracks += [PSCustomObject]@{
          id        = $t.id
          title     = $t.title
          lessons   = $lessonsCount
          completed = $completed
          progress  = $progress
        }
      }
    }

    _bpWriteJson ([PSCustomObject]@{ totalTracks = @($tracks).Count; tracks = $tracks })
    continue
  } catch {
    _bpWriteJson @{ error = "lessons-summary-failed" } 500
    continue
  }
}
elseif ($__p -like "/api/lessons/track/*") {
  try {
    $tid = $__p.Substring("/api/lessons/track/".Length)
    if ([string]::IsNullOrWhiteSpace($tid)) { _bpWriteJson @{ error="missing-track-id" } 400; continue }

    $dataDir = _bpDataDir
    $currPath = Join-Path $dataDir "curriculum.json"
    $progPath = Join-Path $dataDir "progress.lessons.json"

    if (!(Test-Path $currPath)) { _bpWriteJson @{ error="no-curriculum" } 404; continue }

    $curr = Get-Content $currPath -Raw | ConvertFrom-Json
    $track = $curr.tracks | Where-Object { $_.id -eq $tid }
    if (-not $track) { _bpWriteJson @{ error="track-not-found" } 404; continue }

    $prog = if (Test-Path $progPath) { Get-Content $progPath -Raw | ConvertFrom-Json } else { $null }
    $completedSet = @{}
    if ($prog -and ($prog.PSObject.Properties.Name -contains $tid)) {
      foreach ($lid in $prog.$tid.completedLessons) { $completedSet[$lid] = $true }
    }

    $total = 0; $done = 0
    foreach ($m in $track.modules) {
      foreach ($l in $m.lessons) {
        $total++
        if ($completedSet.ContainsKey($l.id)) { $done++; $l | Add-Member -NotePropertyName completed -NotePropertyValue $true -Force }
        else                                   {        $l | Add-Member -NotePropertyName completed -NotePropertyValue $false -Force }
      }
    }
    $progress = if ($total -gt 0) { [Math]::Round(($done*100.0)/$total) } else { 0 }

    _bpWriteJson ([PSCustomObject]@{
      id       = $track.id
      title    = $track.title
      progress = $progress
      modules  = $track.modules
      totals   = @{ lessons = $total; completed = $done }
    })
    continue
  } catch {
    _bpWriteJson @{ error = "lessons-track-failed" } 500
    continue
  }
}
# ==== END LESSONS API GUARD (LESS-002) ====
      $method = $req.HttpMethod.ToUpperInvariant()

      # Static
# ---- XP: add (module-first, with safe fallback)
if ($path -eq '/api/xp/add' -and $method -eq 'POST') {
  $b = Read-Body $req
  $delta  = [int]$b.delta
  $reason = [string]$b.reason
  if (-not $delta) { Write-Json $res @{ error="delta must be non-zero" } 400; continue }
  if ([string]::IsNullOrWhiteSpace($reason)) { $reason = 'Manual XP' }

  $usedModules = $false
  try {
    if (Get-Command Add-OsXP -ErrorAction SilentlyContinue) {
      Add-OsXP -Amount $delta -Reason $reason | Out-Null
      $usedModules = $true
    }
  } catch {}

  if (-not $usedModules) {
    # ---- minimal self-contained fallback (no Initialize-OsStore dependency)
    if (!(Test-Path $DataDir)) { New-Item -ItemType Directory -Force -Path $DataDir | Out-Null }
    $storePath = Join-Path $DataDir 'store.plasma'
    if (!(Test-Path $storePath)) {
      $default = [pscustomobject]@{
        user = [pscustomobject]@{ xp=0; rank='Initiate'; alias='Osirisborn'; progressPct=0 }
        missions = [pscustomobject]@{ catalog=@{}; completed=@() }
        meta = [pscustomobject]@{ xpLog=@() }
        settings = [pscustomobject]@{ dailyGoal=300; notify=$true }
      }
      Set-Content -Path $storePath -Value ($default | ConvertTo-Json -Depth 6) -Encoding UTF8
    }
    $s = Get-Content $storePath -Raw | ConvertFrom-Json
    $s.user.xp = [int]($s.user.xp) + $delta

    # rank & progress (same thresholds as CLI)
    $threshold = @{
      'Initiate'=0; 'Ghost'=200; 'Signal Diver'=600; 'Network Phantom'=1200; 'Redline Operative'=2000;
      'Shadow Architect'=3000; 'Spectral Engineer'=4500; 'Elite'=6500; 'Voidbreaker'=9000; 'God Tier: Osirisborn'=12000
    }
    $ranks = @('Initiate','Ghost','Signal Diver','Network Phantom','Redline Operative','Shadow Architect','Spectral Engineer','Elite','Voidbreaker','God Tier: Osirisborn')
    foreach($r in $ranks){ if ($s.user.xp -ge $threshold[$r]) { $s.user.rank=$r } }
    $curr = $threshold[$s.user.rank]
    $next = $threshold[$ranks[[Math]::Min($ranks.IndexOf($s.user.rank)+1, $ranks.Count-1)]]
    $span = [Math]::Max(1, $next-$curr)
    $s.user.progressPct = [int][Math]::Clamp(100*($s.user.xp-$curr)/$span,0,100)

    # log entry
    if (-not $s.meta) { $s | Add-Member meta ([pscustomobject]@{}) -Force }
    if (-not $s.meta.xpLog){ $s.meta | Add-Member xpLog @() -Force }
    $s.meta.xpLog = @($s.meta.xpLog + [pscustomobject]@{
      at=(Get-Date).ToString('o'); delta=$delta; reason=$reason; total=[int]$s.user.xp; rank=$s.user.rank
    })

    Set-Content $storePath ($s | ConvertTo-Json -Depth 6) -Encoding UTF8
  }

  # respond with current xp/rank
  $xp = $null
  if (Get-Command Get-OsXP -ErrorAction SilentlyContinue) { $xp = Get-OsXP }
  if (-not $xp) {
    $storePath = Join-Path $DataDir 'store.plasma'
    $s = Get-Content $storePath -Raw | ConvertFrom-Json
    $xp = [pscustomobject]@{ Rank=$s.user.rank; XP=[int]$s.user.xp; ProgressPct=[int]($s.user.progressPct) }
  }
  Write-Json $res @{ ok=$true; rank=$xp.Rank; xp=$xp.XP; progressPct=[int]($xp.ProgressPct) }; continue
}
      
if     ($path -eq '/' -or $path -match '^/index\.html$') { Write-File $res (Join-Path $Www 'index.html') 'text/html; charset=utf-8'; continue }
      elseif ($path -match '^/client\.js$')                    { Write-File $res (Join-Path $Www 'client.js') 'application/javascript; charset=utf-8'; continue }
      elseif ($path -match '^/mirror\.json$' -and (Test-Path $Mirror)) { Write-File $res $Mirror 'application/json; charset=utf-8'; continue }

      # DIAG
      if ($path -eq '/diag') {
        $exists = @{
          store    = Test-Path (Join-Path $Modules 'Osirisborn.Store.psm1')
          xp       = Test-Path (Join-Path $Modules 'Osirisborn.XP.psm1')
          missions = Test-Path (Join-Path $Modules 'Osirisborn.Missions.psm1')
        }
        $visible = Get-Command Add-OsMission,Get-OsMissions,Complete-OsMission,Add-OsXP,Get-OsXP -ErrorAction SilentlyContinue |
                   Select-Object Name,ModuleName
        Write-Json $res @{ mode='module'; modulesPath=$Modules; exists=$exists; visible=$visible }; continue
      }

      # XP
      if ($path -eq '/xp.json') {
        $days = 30; try { if ($req.QueryString['days']) { $days = [int]$req.QueryString['days'] } } catch {}
        Write-Json $res (Summarize-XP -Days $days); continue
      }
      if ($path -eq '/api/xp/add' -and $method -eq 'POST') {
        $b = Read-Body $req; $delta=[int]$b.delta; $reason="$($b.reason)"
        if (-not $delta) { Write-Json $res @{ error="delta must be non-zero" } 400; continue }
        if (-not $reason) { $reason = 'Manual XP' }
        if (Get-Command Add-OsXP -ErrorAction SilentlyContinue) {
          Add-OsXP -Amount $delta -Reason $reason | Out-Null
        } else {
          Initialize-OsStore
          $s = Get-OsStore
          $s.user.xp = [int]$s.user.xp + $delta
          Save-OsStore $s
        }
        $xp = Get-OsXP
        Write-Json $res @{ ok=$true; rank=$xp.Rank; xp=$xp.XP; progressPct=$xp.ProgressPct }; continue
      }

      # Missions
      if ($path -eq '/api/missions' -and $method -eq 'GET') {
        Initialize-OsStore
        $items = Get-OsMissions | ForEach-Object {
          [pscustomobject]@{ id="$($_.Id)"; title="$($_.Title)"; xp=[int]$_.XP; status="$($_.Status)" }
        }
        Write-Json $res @{ items = @($items) }; continue
      }
      if ($path -eq '/api/mission/add' -and $method -eq 'POST') {
        $b = Read-Body $req; $id="$($b.id)"; $title="$($b.title)"; $xp=[int]$b.xp
        if (-not $id)    { Write-Json $res @{ error="Missing id" } 400; continue }
        if (-not $title) { $title='New Mission' }
        Add-OsMission -Id $id -XP $xp -Title $title | Out-Null
        Write-Json $res @{ ok=$true; id=$id }; continue
      }
      if ($path -eq '/api/mission/complete' -and $method -eq 'POST') {
        $b = Read-Body $req; $id="$($b.id)"
        if (-not $id) { Write-Json $res @{ error='Missing id' } 400; continue }
        $null = Complete-OsMission -Id $id
        $xp = Get-OsXP
        Write-Json $res @{ ok=$true; id=$id; rank=$xp.Rank; xp=$xp.XP; progressPct=$xp.ProgressPct }; continue
      }

      # 404
      Write-Json $res @{ error = "Not found: $path" } 404
    } catch {
      try { Write-Json $ctx.Response @{ error = $_.Exception.Message } } catch {}
    }
  }
} finally { try { $listener.Stop(); $listener.Close() } catch {} }



