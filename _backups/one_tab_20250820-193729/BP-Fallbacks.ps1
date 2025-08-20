# --- Black Pyramid: external fallbacks (store + XP) ---
function _bpRepoPath {
  if ($env:BP_REPO -and (Test-Path (Join-Path $env:BP_REPO "MythicCore\www\index.html"))) { return $env:BP_REPO }
  $here = $PSScriptRoot
  while ($here -and -not (Test-Path (Join-Path $here "MythicCore\www\index.html"))) {
    $parent = Split-Path $here -Parent
    if ($parent -eq $here) { break } else { $here = $parent }
  }
  return $here
}
function _bpDataPaths {
  $repo  = _bpRepoPath
  $data  = Join-Path $repo "MythicCore\data"
  $store = Join-Path $data "store.plasma"
  [PSCustomObject]@{ repo=$repo; data=$data; store=$store }
}
if (-not (Get-Command Initialize-OsStore -ErrorAction SilentlyContinue)) {
  function Initialize-OsStore {
    try {
      $p = _bpDataPaths
      if (-not (Test-Path $p.data))  { New-Item -Type Directory $p.data -Force | Out-Null }
      if (-not (Test-Path $p.store)) { '{"xp":{"events":[]}}' | Set-Content -Path $p.store -Encoding UTF8 }
      return $true
    } catch { return $false }
  }
}
if (-not (Get-Command Get-OsStore -ErrorAction SilentlyContinue)) {
  function Get-OsStore {
    param([switch]$Ensure)
    if ($Ensure) { Initialize-OsStore | Out-Null }
    $p = _bpDataPaths
    if (-not (Test-Path $p.store)) { Initialize-OsStore | Out-Null }
    try { $obj = (Get-Content $p.store -Raw) | ConvertFrom-Json } catch { $obj = ConvertFrom-Json '{"xp":{"events":[]}}' }
    if (-not $obj.xp)        { $obj | Add-Member -NotePropertyName xp -NotePropertyValue ([PSCustomObject]@{ events=@() }) -Force }
    if (-not $obj.xp.events) { $obj.xp | Add-Member -NotePropertyName events -NotePropertyValue @() -Force }
    return $obj
  }
}
if (-not (Get-Command Save-OsStore -ErrorAction SilentlyContinue)) {
  function Save-OsStore {
    param([Parameter(Mandatory=$true)]$Store)
    $p = _bpDataPaths
    Initialize-OsStore | Out-Null
    ($Store | ConvertTo-Json -Depth 50) | Set-Content -Path $p.store -Encoding UTF8
    return $true
  }
}
if (-not (Get-Command Get-OsXP -ErrorAction SilentlyContinue)) {
  function Get-OsXP {
    param([int]$Days)
    $s = Get-OsStore -Ensure
    if (-not $s.xp)        { $s | Add-Member -NotePropertyName xp -NotePropertyValue ([PSCustomObject]@{ events=@() }) -Force }
    if (-not $s.xp.events) { $s.xp | Add-Member -NotePropertyName events -NotePropertyValue @() -Force }
    return $s.xp
  }
}
if (-not (Get-Command Add-OsXP -ErrorAction SilentlyContinue)) {
  function Add-OsXP {
    param(
      [Parameter(Mandatory=$true)][Alias("Amount")][int]$Delta,
      [string]$Reason = "",
      [datetime]$At = (Get-Date)
    )
    $s = Get-OsStore -Ensure
    if (-not $s.xp)        { $s | Add-Member -NotePropertyName xp -NotePropertyValue ([PSCustomObject]@{ events=@() }) -Force }
    if (-not $s.xp.events) { $s.xp | Add-Member -NotePropertyName events -NotePropertyValue @() -Force }
    $evt = [PSCustomObject]@{ ts = $At.ToString("o"); delta = $Delta; reason = $Reason }
    $s.xp.events = @($s.xp.events + $evt)
    Save-OsStore -Store $s | Out-Null
    return $evt
  }
}
# --- end fallbacks ---
