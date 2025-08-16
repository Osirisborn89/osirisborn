# ==== BEGIN __XP_Summary_Run (self-contained fallback) ====
function __XP_Summary_Run([int]$Days) {
  # --- normalize legacy array shape to a single object ---
  function __xp_norm($r) {
    if ($r -is [array] -and $r.Length -ge 2 -and $r[0] -is [bool]) { return $r[1] }
    return $r
  }

  try {
    if (Get-Command Summarize-XP-LocalV5 -ErrorAction SilentlyContinue) {
      return (__xp_norm (Summarize-XP-LocalV5 -Days $Days))
    }
  } catch {}

  # Inline fallback: merge meta.xpLog + xp.events and bucket by local day
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp   -and $s.xp.events) { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at=$_.ts; delta=$_.delta } }) }

  $ciUS  = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
  $ciIV  = [System.Globalization.CultureInfo]::InvariantCulture
  $off   = [System.Globalization.DateTimeStyles]::None
  $dtLoc = [System.Globalization.DateTimeStyles]::AssumeLocal
  $fmt = @(
    'o','yyyy-MM-ddTHH:mm:ssK','yyyy-MM-ddTHH:mm:ss.FFFFFFFK','u','s',
    'MM/dd/yyyy HH:mm:ss','M/d/yyyy H:mm:ss','MM/dd/yyyy H:mm:ss','M/d/yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss','d/M/yyyy H:mm:ss'
  )

  foreach ($e in $events) {
    $raw = [string]$e.at
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $tmp = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($raw, $ciIV, $off, [ref]$tmp)) {
      foreach ($f in $fmt) {
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciUS, $off, [ref]$tmp)) { break }
        if ($tmp -ne [DateTimeOffset]::MinValue) { break }
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciIV, $off, [ref]$tmp)) { break }
      }
      if ($tmp -eq [DateTimeOffset]::MinValue) {
        $dt = Get-Date
        if ([DateTime]::TryParse($raw, $ciUS, $dtLoc, [ref]$dt) -or [DateTime]::TryParse($raw, $ciIV, $dtLoc, [ref]$dt)) {
          $tmp = [DateTimeOffset]::new([DateTime]::SpecifyKind($dt, [DateTimeKind]::Local))
        }
      }
    }

    if ($tmp -ne [DateTimeOffset]::MinValue) {
      $dto = $tmp.ToLocalTime()
      $key = $dto.Date.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    }
  }

  $series=@(); $cum=0
  foreach ($kv in ($buckets.GetEnumerator() | Sort-Object Name)) {
    $cum += [int]$kv.Value
    $series += [pscustomobject]@{ date=$kv.Key; xp=[int]$kv.Value; cumulative=$cum }
  }

  $nowKey  = (Get-Date).ToString('yyyy-MM-dd')
  $xpToday = if ($buckets.ContainsKey($nowKey)) { [int]$buckets[$nowKey] } else { 0 }
  $goal    = if ($s.settings -and $s.settings.dailyGoal) { [int]$s.settings.dailyGoal } else { 300 }
  $remain  = [Math]::Max(0, $goal - $xpToday)
  $o = Get-OsXP

  # normalize array returns
  if ($dto -and $false) { }  # placeholder
@{
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
# ==== END __XP_Summary_Run ====
#requires -Version 5.1
[Console]::OutputEncoding = [Text.Encoding]::UTF8

# --- Resolve paths safely ---
$ScriptRoot = $null
try {
  if ($PSScriptRoot) { $ScriptRoot = $PSScriptRoot }
  elseif ($PSCommandPath) { $ScriptRoot = (Split-Path -Parent $PSCommandPath) }
  elseif ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $ScriptRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
  }
} catch {}
if (-not $ScriptRoot) { try { $ScriptRoot = (Split-Path -Parent $PSCommandPath) } catch { $ScriptRoot = "." } }

$Root    = Split-Path $ScriptRoot -Parent
$Modules = Join-Path $ScriptRoot 'modules'
$Www     = Join-Path $Root 'www'
$DataDir = Join-Path $Root 'data'

# --- Try modules, but we have fallbacks below ---
try { Import-Module (Join-Path $Modules 'Osirisborn.Store.psm1')    -ErrorAction Stop } catch {}
try { Import-Module (Join-Path $Modules 'Osirisborn.XP.psm1')       -ErrorAction Stop } catch {}
try { Import-Module (Join-Path $Modules 'Osirisborn.Missions.psm1') -ErrorAction Stop } catch {}

# --- Store fallbacks ---
if (-not (Get-Command Initialize-OsStore -ErrorAction SilentlyContinue)) {
  function Initialize-OsStore {
    try {
      if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
      $storePath = Join-Path $DataDir 'store.plasma'
      if (-not (Test-Path $storePath)) {
        '{"user":{"alias":"Osirisborn"},"xp":{"events":[]},"missions":{"catalog":{},"completed":[]},"meta":{"xpLog":[]},"settings":{"dailyGoal":300,"notify":true}}' |
          Set-Content -Path $storePath -Encoding UTF8
      }
      return $true
    } catch { return $false }
  }
}
if (-not (Get-Command Get-OsStore -ErrorAction SilentlyContinue)) {
  function Get-OsStore {
    param([switch]$Ensure)
    $storePath = Join-Path $DataDir 'store.plasma'
    if ($Ensure) { Initialize-OsStore | Out-Null }
    if (-not (Test-Path $storePath)) { Initialize-OsStore | Out-Null }
    try {
      $raw = Get-Content $storePath -Raw -ErrorAction Stop
      $obj = $raw | ConvertFrom-Json -Depth 64
    } catch {
      $obj = ConvertFrom-Json '{"user":{"alias":"Osirisborn"},"xp":{"events":[]},"missions":{"catalog":{},"completed":[]},"meta":{"xpLog":[]},"settings":{"dailyGoal":300,"notify":true}}'
    }
    if (-not $obj.xp)       { $obj | Add-Member -NotePropertyName xp       -NotePropertyValue ([pscustomobject]@{ events=@() }) -Force }
    if (-not $obj.meta)     { $obj | Add-Member -NotePropertyName meta     -NotePropertyValue ([pscustomobject]@{ xpLog=@()  }) -Force }
    if (-not $obj.settings) { $obj | Add-Member -NotePropertyName settings -NotePropertyValue ([pscustomobject]@{ dailyGoal=300; notify=$true }) -Force }
    return $obj
  }
}
if (-not (Get-Command Save-OsStore -ErrorAction SilentlyContinue)) {
  function Save-OsStore {
    param([Parameter(Mandatory=$true)]$Store)
    $storePath = Join-Path $DataDir 'store.plasma'
    Initialize-OsStore | Out-Null
    $Store | ConvertTo-Json -Depth 64 | Set-Content -Path $storePath -Encoding UTF8
    return $true
  }
}

# --- XP fallbacks ---
if (-not (Get-Command Get-OsXP -ErrorAction SilentlyContinue)) {
  function Get-OsXP {
    $s = Get-OsStore -Ensure
    $total = 0
    if ($s.meta -and $s.meta.xpLog) { foreach ($e in $s.meta.xpLog) { $total += [int]$e.delta } }
    $rank = "Initiate"
    $progress = [int]([math]::Round(($total % 100) / 100 * 100))
    [pscustomobject]@{ XP = $total; Rank = $rank; ProgressPct = $progress }
  }
}
if (-not (Get-Command Add-OsXP -ErrorAction SilentlyContinue)) {
  function Add-OsXP {
    param([Parameter(Mandatory=$true)][int]$Amount, [string]$Reason="")
    $s = Get-OsStore -Ensure
    $now = Get-Date
    if (-not $s.meta)      { $s | Add-Member -NotePropertyName meta  -NotePropertyValue ([pscustomobject]@{ xpLog=@() }) -Force }
    if (-not $s.meta.xpLog){ $s.meta | Add-Member -NotePropertyName xpLog -NotePropertyValue @() -Force }
    $total = 0; foreach ($e in $s.meta.xpLog) { $total += [int]$e.delta }
    $total += $Amount
    $entry = [pscustomobject]@{ at=$now.ToString("o"); delta=$Amount; reason=$Reason; total=$total; rank="Initiate" }
    $s.meta.xpLog = @($s.meta.xpLog + $entry)
    Save-OsStore -Store $s | Out-Null
    return $entry
  }
}

# --- Helpers ---
function Write-Json([System.Net.HttpListenerResponse]$res, $obj, [int]$status=200) {
  try {
    $json  = $obj | ConvertTo-Json -Depth 60
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $res.StatusCode = $status
    $res.ContentType = 'application/json; charset=utf-8'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes,0,$bytes.Length)
  } finally { $res.Close() }
}
function Write-File([System.Net.HttpListenerResponse]$res, [string]$path, [string]$contentType) {
  try {
    $bytes = [IO.File]::ReadAllBytes($path)
    $res.StatusCode = 200
    $res.ContentType = $contentType
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes,0,$bytes.Length)
  } finally { $res.Close() }
}
function Read-Body([System.Net.HttpListenerRequest]$req) {
  $sr   = New-Object IO.StreamReader($req.InputStream, $req.ContentEncoding)
  $text = $sr.ReadToEnd(); $sr.Close()
  if ([string]::IsNullOrWhiteSpace($text)) { return @{} }
  try { return $text | ConvertFrom-Json -Depth 20 } catch { return @{} }
}

# --- XP summary (object form; counts xpLog + xp.events) ---
function Summarize-XP-Fixed([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore
  $end = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0, $Days-1))
  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp -and $s.xp.events)   { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  foreach ($e in $events) {
    try {
      $dt = [DateTime]::Parse([string]$e.at)
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

  [pscustomobject]@{
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

# --- Lessons helpers ---
function Get-LessonsSummary {
  $currPath = Join-Path $DataDir 'curriculum.json'
  $progPath = Join-Path $DataDir 'progress.lessons.json'
  $tracks=@()
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
      $tracks += [pscustomobject]@{
        id        = $t.id
        title     = $t.title
        lessons   = $lessonsCount
        completed = $completed
        progress  = $progress
      }
    }
  }
  [pscustomobject]@{ totalTracks = @($tracks).Count; tracks = $tracks }
}
function Get-LessonsTrack([string]$TrackId) {
  $currPath = Join-Path $DataDir 'curriculum.json'
  $progPath = Join-Path $DataDir 'progress.lessons.json'
  if (-not (Test-Path $currPath)) { return $null }
  $curr = Get-Content $currPath -Raw | ConvertFrom-Json
  $track = $curr.tracks | Where-Object { $_.id -eq $TrackId }
  if (-not $track) { return $null }
  $prog = if (Test-Path $progPath) { Get-Content $progPath -Raw | ConvertFrom-Json } else { $null }
  $completedSet = @{}
  if ($prog -and ($prog.PSObject.Properties.Name -contains $TrackId)) {
    foreach ($lid in $prog.$TrackId.completedLessons) { $completedSet[$lid] = $true }
  }
  $total = 0; $done = 0
  foreach ($m in $track.modules) {
    foreach ($l in $m.lessons) {
      $total++
      if ($completedSet.ContainsKey($l.id)) { $done++; $l | Add-Member -NotePropertyName completed -NotePropertyValue $true  -Force }
      else                                  {        $l | Add-Member -NotePropertyName completed -NotePropertyValue $false -Force }
    }
  }
  $progress = if ($total -gt 0) { [Math]::Round(($done*100.0)/$total) } else { 0 }
  [pscustomobject]@{
    id       = $track.id
    title    = $track.title
    progress = $progress
    modules  = $track.modules
    totals   = @{ lessons = $total; completed = $done }
  }
}
function Complete-Lesson([string]$TrackId, [string]$LessonId) {
  $currPath = Join-Path $DataDir 'curriculum.json'
  $progPath = Join-Path $DataDir 'progress.lessons.json'
  if (-not (Test-Path $currPath)) { return @{ error="no-curriculum" } }
  $curr = Get-Content $currPath -Raw | ConvertFrom-Json
  $track = $curr.tracks | Where-Object { $_.id -eq $TrackId }
  if (-not $track) { return @{ error="track-not-found" } }

  $prog = if (Test-Path $progPath) { Get-Content $progPath -Raw | ConvertFrom-Json } else { ConvertFrom-Json '{}' }
  if (-not ($prog.PSObject.Properties.Name -contains $TrackId)) {
    $prog | Add-Member -NotePropertyName $TrackId -NotePropertyValue ([pscustomobject]@{ completedLessons=@() }) -Force
  }
  $completed = @($prog.$TrackId.completedLessons)
  if ($completed -contains $LessonId) {
    $total = 0; foreach ($m in $track.modules) { $total += @($m.lessons).Count }
    $done  = $completed.Count
    $progress = if ($total -gt 0) { [Math]::Round(($done*100.0)/$total) } else { 0 }
    return @{ status="exists"; trackId=$TrackId; lessonId=$LessonId; awarded=0; totals=@{lessons=$total;completed=$done}; progress=$progress }
  }

  # mark complete
  $prog.$TrackId.completedLessons = @($completed + $LessonId)
  $prog | ConvertTo-Json -Depth 40 | Set-Content -Path $progPath -Encoding UTF8

  # award XP
  $xp = 10
  foreach ($m in $track.modules) {
    foreach ($l in $m.lessons) {
      if ($l.id -eq $LessonId -and $l.PSObject.Properties.Name -contains "xp") { $xp = [int]$l.xp }
    }
  }
  try { Add-OsXP -Amount $xp -Reason ("Lesson "+$TrackId+"/"+$LessonId) | Out-Null } catch {}

  $total2 = 0; foreach ($m in $track.modules) { $total2 += @($m.lessons).Count }
  $done2  = @($prog.$TrackId.completedLessons).Count
  $progress2 = if ($total2 -gt 0) { [Math]::Round(($done2*100.0)/$total2) } else { 0 }
  return @{ status="ok"; trackId=$TrackId; lessonId=$LessonId; awarded=$xp; totals=@{lessons=$total2;completed=$done2}; progress=$progress2 }
}

# --- HTTP listener ---
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
# ==== BEGIN XP NORMALIZER INTERCEPT ====
if ($path -eq "/xp.json") {
  $days = 30
  if ($req.Url.Query -match 'days=(\d+)') { $days = [int]$Matches[1] }
  Write-Json $res (__XP_Summary_Run -Days $days)
  continue
}
# ==== END XP NORMALIZER INTERCEPT ====
  elseif ($path -eq "/xp.debug") {
    try {
      $days = 30
      if ($req.Url.Query -match 'days=(\d+)') { $days = [int]$Matches[1] }
      $r = __XP_Summary_Run -Days $days
      Write-Json $res @{ ok = $true; result = $r }
    } catch {
      $err = $_
      Write-Json $res @{ ok = $false; error = ($err | Out-String); stack = $err.ScriptStackTrace }
    }
    continue
  }

      switch -Regex ($path) {
        '^/$' {
          $idx = Join-Path $Www 'index.html'
          if (Test-Path $idx) { Write-File $res $idx 'text/html; charset=utf-8' } else { Write-Json $res @{ error="Missing index.html" } 404 }
          continue
        }
        '^/client\.js$' {
          $p = Join-Path $Www 'client.js'
          if (Test-Path $p) { Write-File $res $p 'application/javascript; charset=utf-8' } else { Write-Json $res @{ error="Missing client.js" } 404 }
          continue
        }
        '^/mirror\.json$' {
          $p = Join-Path $Www 'mirror.json'
          if (Test-Path $p) { Write-File $res $p 'application/json; charset=utf-8' } else { Write-Json $res @{ error="Not found: /mirror.json" } 404 }
          continue
        }
        '^/diag$' {
          $visible = Get-Command Add-OsXP,Get-OsXP,Initialize-OsStore,Get-OsStore,Save-OsStore -ErrorAction SilentlyContinue | Select-Object Name,ModuleName
          $exists  = @{
            store      = (Test-Path (Join-Path $DataDir 'store.plasma'))
            curriculum = (Test-Path (Join-Path $DataDir 'curriculum.json'))
            progress   = (Test-Path (Join-Path $DataDir 'progress.lessons.json'))
          }
          Write-Json $res @{ mode="module"; exists=$exists; visible=$visible; modulesPath=$Modules }
          continue
        }
        '^/xp\.json$' {
          $days = 30
          if ($req.Url.Query -match 'days=(\d+)') { $days = [int]$Matches[1] }
          Write-Json $res (__XP_Summary_Run -Days $days)
          continue
        }
        '^/api/xp/add$' {
          $b = Read-Body $req
          $delta  = [int]($b.delta)
          $reason = [string]($b.reason)
          $delta  = if ($delta) { $delta } else { 0 }
          $entry  = Add-OsXP -Amount $delta -Reason $reason
          $o = Get-OsXP
          Write-Json $res @{ ok=$true; xp=$o.XP; rank=$o.Rank; progressPct=$o.ProgressPct }
          continue
        }
        '^/api/lessons/summary$' {
          Write-Json $res (Get-LessonsSummary)
          continue
        }
        '^/api/lessons/track/([^/]+)$' {
          $tid = $Matches[1]
          $t = Get-LessonsTrack -TrackId $tid
          if ($t) { Write-Json $res $t } else { Write-Json $res @{ error="track-not-found" } 404 }
          continue
        }
        '^/api/lessons/complete$' {
          $b = Read-Body $req
          $tid = [string]$b.trackId
          $lid = [string]$b.lessonId
          if ([string]::IsNullOrWhiteSpace($tid) -and $req.Url.Query -match 'trackId=([^&]+)') { $tid = [Uri]::UnescapeDataString($Matches[1]) }
          if ([string]::IsNullOrWhiteSpace($lid) -and $req.Url.Query -match 'lessonId=([^&]+)') { $lid = [Uri]::UnescapeDataString($Matches[1]) }
          if ([string]::IsNullOrWhiteSpace($tid) -or [string]::IsNullOrWhiteSpace($lid)) { Write-Json $res @{ error="missing-track-or-lesson" } 400; continue }
          $result = Complete-Lesson -TrackId $tid -LessonId $lid
          if ($result.error) { Write-Json $res $result 400 } else { Write-Json $res $result }
          continue
        }
        default {
          # serve from /www or 404
          $p = $path.TrimStart('/')
          $f = Join-Path $Www $p
          if (Test-Path $f) {
            $ct = 'text/plain'
            switch -Regex ($f) {
              '\.html?$' { $ct='text/html; charset=utf-8' }
              '\.js$'    { $ct='application/javascript; charset=utf-8' }
              '\.css$'   { $ct='text/css; charset=utf-8' }
              '\.json$'  { $ct='application/json; charset=utf-8' }
              '\.(png|jpg|jpeg|gif|webp|svg)$' { $ct='application/octet-stream' }
            }
            Write-File $res $f $ct
          } else {
            Write-Json $res @{ error=("Not found: " + $path) } 404
          }
          continue
        }
      }
    } catch {
      try { Write-Json $res @{ error="server-fault" } 500 } catch {}
    }
  }
} finally {
  try { $listener.Stop() } catch {}
}

# ==== BEGIN XP SUMMARY v2 (robust local bucketing) ====
function Summarize-XP2([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore
  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))
  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString("yyyy-MM-dd")] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp   -and $s.xp.events)  { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  foreach ($e in $events) {
    try {
      $dto = [DateTimeOffset]::Parse([string]$e.at)
      $localDate = $dto.ToLocalTime().Date
      if ($localDate -ge $start -and $localDate -le $end) {
        $key = $localDate.ToString('yyyy-MM-dd')
        $buckets[$key] += [int]$e.delta
      }
    } catch {}
  }

  $series = @(); $cum = 0
  foreach ($kv in ($buckets.GetEnumerator() | Sort-Object Name)) {
    $cum += [int]$kv.Value
    $series += [pscustomobject]@{ date=$kv.Key; xp=[int]$kv.Value; cumulative=$cum }
  }

  $nowKey   = (Get-Date).ToString('yyyy-MM-dd')
  $xpToday  = if ($buckets.ContainsKey($nowKey)) { [int]$buckets[$nowKey] } else { 0 }
  $goal     = if ($s.settings -and $s.settings.dailyGoal) { [int]$s.settings.dailyGoal } else { 300 }
  $remaining= [Math]::Max(0,$goal - $xpToday)
  $o = Get-OsXP

  @($true, [pscustomobject]@{
    days   = $Days
    series = $series
    summary = @{
      xpToday     = $xpToday
      dailyGoal   = $goal
      remaining   = $remaining
      rank        = $o.Rank
      xp          = $o.XP
      progressPct = $o.ProgressPct
    }
  })
}
# ==== END XP SUMMARY v2 ====





# ==== BEGIN XP SUMMARY LOCAL (robust) ====
function Summarize-XP-Local([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp -and $s.xp.events)   { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at=$_.ts; delta=$_.delta } }) }

  foreach ($e in $events) {
    try {
      $dt  = [DateTimeOffset]::Parse([string]$e.at).ToLocalTime().Date
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

  return [pscustomobject]@{
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
# ==== END XP SUMMARY LOCAL ====



# ==== BEGIN XP SUMMARY LOCAL V2 (super-robust) ====
function Summarize-XP-LocalV2([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp -and $s.xp.events)   { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  $formats = @('o','yyyy-MM-ddTHH:mm:ssK','yyyy-MM-ddTHH:mm:ss.FFFFFFFK','u','s')

  foreach ($e in $events) {
    $raw = [string]$e.at
    $dto = $null
    try { $dto = [DateTimeOffset]::Parse($raw).ToLocalTime() } catch {
      foreach ($f in $formats) {
        try { $dto = [DateTimeOffset]::ParseExact($raw,$f,$null).ToLocalTime(); break } catch {}
      }
      if (-not $dto) { try { $dto = ([DateTime]::Parse($raw)).ToLocalTime() } catch {} }
    }
    if ($dto) {
      $key = $dto.Date.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    }
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

  [pscustomobject]@{
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
# ==== END XP SUMMARY LOCAL V2 ====



# ==== BEGIN XP SUMMARY LOCAL V3 (handles US/EU slash dates) ====
function Summarize-XP-LocalV3([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp -and $s.xp.events)   { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  $ciUS = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
  $ciIV = [System.Globalization.CultureInfo]::InvariantCulture
  $styles = [System.Globalization.DateTimeStyles]::AssumeLocal
  $fmt = @(
    'o','yyyy-MM-ddTHH:mm:ssK','yyyy-MM-ddTHH:mm:ss.FFFFFFFK','u','s',
    'MM/dd/yyyy HH:mm:ss','M/d/yyyy H:mm:ss','MM/dd/yyyy H:mm:ss','M/d/yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss','d/M/yyyy H:mm:ss'
  )

  foreach ($e in $events) {
    $raw = [string]$e.at
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }
    $dto = $null

    try { $dto = [DateTimeOffset]::Parse($raw, $ciUS, $styles) } catch {
      try { $dto = [DateTimeOffset]::Parse($raw, $ciIV, $styles) } catch {
        foreach ($f in $fmt) { try { $dto = [DateTimeOffset]::ParseExact($raw, $f, $ciUS, $styles); break } catch {} }
        if (-not $dto) { foreach ($f in $fmt) { try { $dto = [DateTimeOffset]::ParseExact($raw, $f, $ciIV, $styles); break } catch {} } }
        if (-not $dto) {
          try {
            $dt = [DateTime]::Parse($raw, $ciUS, $styles)
            if ($dt) { $dto = [DateTimeOffset]::new([DateTime]::SpecifyKind($dt, [DateTimeKind]::Local)) }
          } catch {}
        }
      }
    }

    if ($dto) {
      $key = $dto.Date.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    }
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

  [pscustomobject]@{
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
# ==== END XP SUMMARY LOCAL V3 ====



# ==== BEGIN XP SUMMARY LOCAL V4 (bulletproof parse) ====
function Summarize-XP-LocalV4([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString("yyyy-MM-dd")] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp   -and $s.xp.events) { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  $ciUS = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
  $ciIV = [System.Globalization.CultureInfo]::InvariantCulture
  $styles = [System.Globalization.DateTimeStyles]::AssumeLocal
  $fmt = @(
    'o','yyyy-MM-ddTHH:mm:ssK','yyyy-MM-ddTHH:mm:ss.FFFFFFFK','u','s',
    'MM/dd/yyyy HH:mm:ss','M/d/yyyy H:mm:ss','MM/dd/yyyy H:mm:ss','M/d/yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss','d/M/yyyy H:mm:ss'
  )

  foreach ($e in $events) {
    $raw = [string]$e.at
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $dto = $null
    # TryParse (invariant), then TryParseExact (US & invariant), then DateTime fallback
    $tmp = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($raw, $ciIV, $styles, [ref]$tmp)) {
      foreach ($f in $fmt) {
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciUS, $styles, [ref]$tmp)) { break }
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciIV, $styles, [ref]$tmp)) { break }
      }
      if ($tmp -eq [DateTimeOffset]::MinValue) {
        $dt = Get-Date
        if ([DateTime]::TryParse($raw, $ciUS, $styles, [ref]$dt) -or [DateTime]::TryParse($raw, $ciIV, $styles, [ref]$dt)) {
          $tmp = [DateTimeOffset]::new([DateTime]::SpecifyKind($dt, [DateTimeKind]::Local))
        }
      }
    }
    if ($tmp -ne [DateTimeOffset]::MinValue) { $dto = $tmp.ToLocalTime() }

    if ($dto) {
      $key = $dto.Date.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    }
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

  [pscustomobject]@{
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
# ==== END XP SUMMARY LOCAL V4 ====



# ==== BEGIN XP SUMMARY LOCAL V5 (safe DateTimeStyles) ====
function Summarize-XP-LocalV5([int]$Days=30) {
  Initialize-OsStore
  $s = Get-OsStore

  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0,$Days-1))

  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString("yyyy-MM-dd")] = 0 }

  $events = @()
  if ($s.meta -and $s.meta.xpLog) { $events += $s.meta.xpLog }
  if ($s.xp   -and $s.xp.events) { $events += ($s.xp.events | ForEach-Object { [pscustomobject]@{ at = $_.ts; delta = $_.delta } }) }

  $ciUS  = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
  $ciIV  = [System.Globalization.CultureInfo]::InvariantCulture
  $off   = [System.Globalization.DateTimeStyles]::None          # for DateTimeOffset
  $dtLoc = [System.Globalization.DateTimeStyles]::AssumeLocal   # ONLY for DateTime fallback
  $fmt = @(
    'o','yyyy-MM-ddTHH:mm:ssK','yyyy-MM-ddTHH:mm:ss.FFFFFFFK','u','s',
    'MM/dd/yyyy HH:mm:ss','M/d/yyyy H:mm:ss','MM/dd/yyyy H:mm:ss','M/d/yyyy HH:mm:ss',
    'dd/MM/yyyy HH:mm:ss','d/M/yyyy H:mm:ss'
  )

  foreach ($e in $events) {
    $raw = [string]$e.at
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $dto = $null

    # 1) Invariant TryParse (no exceptions)
    $tmp = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($raw, $ciIV, $off, [ref]$tmp)) {
      # 2) TryParseExact with our formats (US first, then invariant)
      foreach ($f in $fmt) {
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciUS, $off, [ref]$tmp)) { break }
        if ($tmp -ne [DateTimeOffset]::MinValue) { break }
        if ([DateTimeOffset]::TryParseExact($raw, $f, $ciIV, $off, [ref]$tmp)) { break }
      }
      # 3) DateTime fallback (AssumeLocal)
      if ($tmp -eq [DateTimeOffset]::MinValue) {
        $dt = Get-Date
        if ([DateTime]::TryParse($raw, $ciUS, $dtLoc, [ref]$dt) -or [DateTime]::TryParse($raw, $ciIV, $dtLoc, [ref]$dt)) {
          $tmp = [DateTimeOffset]::new([DateTime]::SpecifyKind($dt, [DateTimeKind]::Local))
        }
      }
    }
    if ($tmp -ne [DateTimeOffset]::MinValue) { $dto = $tmp.ToLocalTime() }

    if ($dto) {
      $key = $dto.Date.ToString('yyyy-MM-dd')
      if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
    }
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

  [pscustomobject]@{
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
# ==== END XP SUMMARY LOCAL V5 ====








