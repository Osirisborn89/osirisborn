#requires -Version 7.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Modules    = Join-Path $ScriptRoot 'modules'
$DataDir    = Join-Path (Split-Path $ScriptRoot -Parent) 'data'
$Mirror     = Join-Path (Split-Path $ScriptRoot -Parent) 'www\mirror.json'
$Www        = Join-Path (Split-Path $ScriptRoot -Parent) 'www'

. (Join-Path $Modules 'Osirisborn.Store.psm1')
. (Join-Path $Modules 'Osirisborn.XP.psm1')
. (Join-Path $Modules 'Osirisborn.Missions.psm1')

function Write-Json([System.Net.HttpListenerResponse]$res, $obj, [int]$status=200) {
  $res.StatusCode = $status
  $json  = ($obj | ConvertTo-Json -Depth 6)
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $res.ContentType = 'application/json; charset=utf-8'
  $res.OutputStream.Write($bytes,0,$bytes.Length)
  $res.Close()
}
function Write-File([System.Net.HttpListenerResponse]$res, [string]$path, [string]$contentType) {
  $bytes = [IO.File]::ReadAllBytes($path)
  $res.StatusCode = 200
  $res.ContentType = $contentType
  $res.OutputStream.Write($bytes,0,$bytes.Length)
  $res.Close()
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
  $end   = (Get-Date).Date
  $start = $end.AddDays(-[Math]::Max(0, $Days-1))
  $buckets = @{}
  for ($d=$start; $d -le $end; $d=$d.AddDays(1)) { $buckets[$d.ToString('yyyy-MM-dd')] = 0 }
  $log = if ($s.meta -and $s.meta.xpLog) { $s.meta.xpLog } else { @() }
  foreach ($e in $log) {
    $dt = [DateTime]::Parse($e.at)
    $key = $dt.ToString('yyyy-MM-dd')
    if ($buckets.ContainsKey($key)) { $buckets[$key] += [int]$e.delta }
  }
  $series = @(); $cum = 0
  foreach ($kv in ($buckets.GetEnumerator() | Sort-Object Name)) {
    $cum += [int]$kv.Value
    $series += [pscustomobject]@{ date=$kv.Key; xp=[int]$kv.Value; cumulative=$cum }
  }
  $nowKey   = (Get-Date).ToString('yyyy-MM-dd')
  $xpToday  = if ($buckets.ContainsKey($nowKey)) { [int]$buckets[$nowKey] } else { 0 }
  $goal     = if ($s.settings -and $s.settings.dailyGoal) { [int]$s.settings.dailyGoal } else { 300 }
  $remain   = [Math]::Max(0, $goal - $xpToday)
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

$Port = 7777
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Osirisborn server running → http://localhost:$Port/  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $req = $ctx.Request; $res = $ctx.Response
      $path = $req.Url.AbsolutePath; $method = $req.HttpMethod.ToUpperInvariant()

      if ($path -eq '/' -or $path -match '^/index\.html$') { Write-File $res (Join-Path $Www 'index.html') 'text/html; charset=utf-8'; continue }
      elseif ($path -match '^/client\.js$')                 { Write-File $res (Join-Path $Www 'client.js') 'application/javascript; charset=utf-8'; continue }
      elseif ($path -match '^/mirror\.json$' -and (Test-Path $Mirror)) { Write-File $res $Mirror 'application/json; charset=utf-8'; continue }

      if     ($path -eq '/diag') {
        $exists = @{
          store    = Test-Path (Join-Path $Modules 'Osirisborn.Store.psm1')
          xp       = Test-Path (Join-Path $Modules 'Osirisborn.XP.psm1')
          missions = Test-Path (Join-Path $Modules 'Osirisborn.Missions.psm1')
        }
        $visible = Get-Command Add-OsMission,Get-OsMissions,Add-OsXP,Get-OsXP -ErrorAction SilentlyContinue |
                   Select-Object Name,ModuleName
        Write-Json $res @{ mode='inline'; modulesPath=$Modules; exists=$exists; visible=$visible }; continue
      }
      if     ($path -eq '/xp.json') {
        $days = 30; try { if ($req.QueryString['days']) { $days = [int]$req.QueryString['days'] } } catch {}
        Write-Json $res (Summarize-XP -Days $days); continue
      }
      if     ($path -eq '/api/missions' -and $method -eq 'GET') {
        Initialize-OsStore
        $items = Get-OsMissions | ForEach-Object {
          [pscustomobject]@{ id="$($_.Id)"; title="$($_.Title)"; xp=[int]$_.XP; status="$($_.Status)" }
        }
        Write-Json $res @{ items = @($items) }; continue
      }
      if     ($path -eq '/api/mission/add' -and $method -eq 'POST') {
        $b = Read-Body $req; $id="$($b.id)"; $title="$($b.title)"; $xp=[int]$b.xp
        if (-not $id)   { Write-Json $res @{ error="Missing id" } 400; continue }
        if (-not $title){ $title='New Mission' }
        Add-OsMission -Id $id -XP $xp -Title $title | Out-Null
        Write-Json $res @{ ok=$true; id=$id }; continue
      }
      if     ($path -eq '/api/mission/complete' -and $method -eq 'POST') {
        $b = Read-Body $req; $id="$($b.id)"
        if (-not $id) { Write-Json $res @{ error='Missing id' } 400; continue }
        $null = Complete-OsMission -Id $id
        $xp = Get-OsXP
        Write-Json $res @{ ok=$true; id=$id; rank=$xp.Rank; xp=$xp.XP; progressPct=$xp.ProgressPct }; continue
      }

      Write-Json $res @{ error = "Not found: $path" } 404
    } catch {
      try { Write-Json $ctx.Response @{ error = $_.Exception.Message } } catch {}
    }
  }
} finally { $listener.Stop(); $listener.Close() }
