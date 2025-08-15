#requires -Version 7.0
$ErrorActionPreference = 'Stop'

# --- Paths ---
$Script:Root     = Split-Path $PSScriptRoot -Parent       # ...\MythicCore
$Script:Modules  = Join-Path $PSScriptRoot 'modules'      # ...\scripts\modules
$Script:WWW      = Join-Path $Script:Root  'www'          # ...\www
$Script:Data     = Join-Path $Script:Root  'data'         # ...\data
$Script:Mirror   = Join-Path $Script:WWW   'mirror.json'
$Script:Port     = 7777

# --- Import modules with explicit paths (and dot-source fallback) ---
$importsOk = $true
function Try-Import([string]$name){
  $p = Join-Path $Script:Modules $name
  try {
    Import-Module $p -Force -ErrorAction Stop
  } catch {
    try {
      . $p   # dot-source fallback
    } catch {
      $script:importsOk = $false
    }
  }
}
Try-Import 'Osirisborn.Store.psm1'
Try-Import 'Osirisborn.XP.psm1'
Try-Import 'Osirisborn.Missions.psm1'

# ---------- Helpers ----------
function Write-Bytes {
  param(
    [Parameter(Mandatory)][System.Net.HttpListenerContext]$ctx,
    [Parameter(Mandatory)][byte[]]$Bytes,
    [int]$Code = 200,
    [string]$ContentType = 'text/plain; charset=utf-8'
  )
  $ctx.Response.StatusCode  = $Code
  $ctx.Response.ContentType = $ContentType
  $ctx.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
  $ctx.Response.Close()
}
function Write-Text {
  param(
    [Parameter(Mandatory)][System.Net.HttpListenerContext]$ctx,
    [Parameter(Mandatory)][string]$Text,
    [int]$Code = 200,
    [string]$ContentType = 'text/plain; charset=utf-8'
  )
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  Write-Bytes -ctx $ctx -Bytes $bytes -Code $Code -ContentType $ContentType
}
function Write-Json {
  param(
    [Parameter(Mandatory)][System.Net.HttpListenerContext]$ctx,
    [Parameter(Mandatory)]$Obj,
    [int]$Code = 200
  )
  $json = ($Obj | ConvertTo-Json -Depth 10)
  Write-Text -ctx $ctx -Text $json -Code $Code -ContentType 'application/json; charset=utf-8'
}
function Read-JsonBody {
  param([Parameter(Mandatory)][System.Net.HttpListenerRequest]$req)
  if (-not $req.HasEntityBody) { return @{} }
  $sr = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
  $txt = $sr.ReadToEnd(); $sr.Close()
  if ([string]::IsNullOrWhiteSpace($txt)) { return @{} }
  try { $txt | ConvertFrom-Json } catch { @{} }
}
function Parse-Query {
  param([Parameter(Mandatory)][uri]$uri)
  $q = @{}
  $raw = $uri.Query
  if ([string]::IsNullOrEmpty($raw)) { return $q }
  $raw.TrimStart('?').Split('&', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
    $kv = $_.Split('=',2)
    $k  = [uri]::UnescapeDataString($kv[0])
    $v  = if ($kv.Length -gt 1) { [uri]::UnescapeDataString($kv[1]) } else { '' }
    $q[$k] = $v
  }
  $q
}

# ---------- XP series (primary: store; fallback: mirror.json) ----------
function Get-XpSeries {
  param([int]$Days = 30)

  $to   = (Get-Date).Date
  $from = $to.AddDays(-[Math]::Max(0,$Days-1))

  # accumulate XP by day from the real store if possible
  $map  = @{}
  $summary = $null

  try {
    # requires Osirisborn.Store + data shape
    $s = Get-OsStore
    $log = @($s.meta.xpLog)
    foreach($e in $log){
      $d = (Get-Date $e.at).ToString('yyyy-MM-dd')
      $map[$d] = [int]($map[$d] + [int]$e.delta)
    }
    $todayKey = $to.ToString('yyyy-MM-dd')
    $xpToday  = [int]($map[$todayKey] ?? 0)
    $goal     = [int]($s.targets.dailyGoal ?? 0)
    $summary  = [pscustomobject]@{
      xpToday     = $xpToday
      dailyGoal   = $goal
      remaining   = [int]([Math]::Max(0, $goal - $xpToday))
      rank        = $s.user.rank
      xp          = [int]$s.user.xp
      progressPct = [int]$s.user.progressPct
    }
  } catch {
    # fallback: mirror.json (has summary + today's XP/goal)
    try {
      $m = Get-Content $Script:Mirror -Raw | ConvertFrom-Json
      $xpToday = [int]($m.targets.xpToday ?? 0)
      $summary = [pscustomobject]@{
        xpToday     = $xpToday
        dailyGoal   = [int]($m.targets.dailyGoal ?? 0)
        remaining   = [int]($m.targets.xpRemaining ?? 0)
        rank        = $m.user.rank
        xp          = [int]$m.user.xp
        progressPct = [int]$m.user.progressPct
      }
      # put xpToday into the last day so the chart isn’t flat
      $map[$to.ToString('yyyy-MM-dd')] = $xpToday
    } catch {
      $summary = $null
    }
  }

  $series = @()
  $cum = 0
  for($d=$from; $d -le $to; $d=$d.AddDays(1)){
    $key = $d.ToString('yyyy-MM-dd')
    $xp  = [int]($map[$key] ?? 0)
    $cum += $xp
    $series += [pscustomobject]@{ date=$key; xp=$xp; cumulative=$cum }
  }
  [pscustomobject]@{ days=$Days; series=$series; summary=$summary }
}

# ---------- HTTP listener ----------
$listener = [System.Net.HttpListener]::new()
$prefix   = "http://localhost:$($Script:Port)/"
$listener.Prefixes.Clear(); $listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Osirisborn server running → $prefix  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    try {
      $req  = $ctx.Request
      $path = $req.Url.AbsolutePath
      $qs   = Parse-Query $req.Url

      # --- Static files ---
      if ($path -eq '/' -or $path -match '^/index\.html$') {
        $html = Get-Content (Join-Path $Script:WWW 'index.html') -Raw
        Write-Text -ctx $ctx -Text $html -ContentType 'text/html; charset=utf-8'
        continue
      }
      elseif ($path -match '^/client\.js$') {
        $js = Get-Content (Join-Path $Script:WWW 'client.js') -Raw
        Write-Text -ctx $ctx -Text $js -ContentType 'application/javascript; charset=utf-8'
        continue
      }
      elseif ($path -match '^/mirror\.json$' -and (Test-Path $Script:Mirror)) {
        $json = Get-Content $Script:Mirror -Raw
        Write-Text -ctx $ctx -Text $json -ContentType 'application/json; charset=utf-8'
        continue
      }

      # --- Diagnostics ---
      if ($path -eq '/diag') {
        $visible = @()
        try {
          $visible = Get-Command Add-OsMission,Get-OsMissions,Add-OsXP,Get-OsXP -ErrorAction SilentlyContinue |
                     Select-Object Name,ModuleName
        } catch {}
        Write-Json -ctx $ctx @{
          modulesPath = $Script:Modules
          exists      = @{
            missions = Test-Path (Join-Path $Script:Modules 'Osirisborn.Missions.psm1')
            xp       = Test-Path (Join-Path $Script:Modules 'Osirisborn.XP.psm1')
            store    = Test-Path (Join-Path $Script:Modules 'Osirisborn.Store.psm1')
          }
          mode        = 'inline'
          visible     = $visible
        }
        continue
      }

      # --- XP ---
      if ($path -eq '/xp.json') {
        $days = 30
        if ($qs.ContainsKey('days')) { [void][int]::TryParse($qs['days'], [ref]$days) }
        Write-Json -ctx $ctx (Get-XpSeries -Days $days)
        continue
      }

      # --- Missions (filter nulls/empties) ---
      if ($path -eq '/api/missions' -and $req.HttpMethod -eq 'GET') {
        if (-not (Get-Command Get-OsMissions -ErrorAction SilentlyContinue)) {
          throw "Missions module not loaded."
        }
        $items = @(Get-OsMissions |
          Where-Object { $_ -and ($_.id ?? $_.Id) } |
          Select-Object @{n='id';e={$_.id ?? $_.Id}},
                        @{n='title';e={$_.title ?? $_.Title}},
                        @{n='xp';e={[int]($_.xp ?? $_.XP)}},
                        @{n='status';e={$_.status ?? $_.Status}})
        Write-Json -ctx $ctx @{ items = $items }
        continue
      }

      if ($path -eq '/api/mission/add' -and $req.HttpMethod -eq 'POST') {
        $b = Read-JsonBody -req $req
        if (-not (Get-Command Add-OsMission -ErrorAction SilentlyContinue)) {
          throw "Missions module not loaded."
        }
        Add-OsMission -Id $b.id -XP ([int]$b.xp) -Title $b.title | Out-Null
        Write-Json -ctx $ctx @{ ok = $true }
        continue
      }

      if ($path -eq '/api/mission/complete' -and $req.HttpMethod -eq 'POST') {
        $b = Read-JsonBody -req $req
        if (-not (Get-Command Complete-OsMission -ErrorAction SilentlyContinue)) {
          throw "Missions module not loaded."
        }
        Complete-OsMission -Id $b.id | Out-Null
        Write-Json -ctx $ctx @{ ok = $true }
        continue
      }

      # Fallback
      Write-Json -ctx $ctx @{ error = "Not found: $path" } 404
    }
    catch {
      Write-Json -ctx $ctx @{ error = $_.Exception.Message } 500
    }
  }
}
finally {
  $listener.Stop(); $listener.Close()
}
