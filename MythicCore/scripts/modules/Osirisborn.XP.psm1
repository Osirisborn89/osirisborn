#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot "Osirisborn.Store.psm1") -Force -ErrorAction Stop

# ---- Rank ladder ----
$Script:Ranks = @(
  "Initiate","Ghost","Signal Diver","Network Phantom","Redline Operative",
  "Shadow Architect","Spectral Engineer","Elite","Voidbreaker","God Tier: Osirisborn"
)

function Get-RankThresholds {
    @{
      "Initiate"=0
      "Ghost"=200
      "Signal Diver"=600
      "Network Phantom"=1200
      "Redline Operative"=2000
      "Shadow Architect"=3000
      "Spectral Engineer"=4500
      "Elite"=6500
      "Voidbreaker"=9000
      "God Tier: Osirisborn"=12000
    }
}

function Get-CurrentProgress([int]$xp,[string]$rank) {
    $th = Get-RankThresholds
    $idx = $Script:Ranks.IndexOf($rank); if ($idx -lt 0) { $idx = 0 }
    $currReq = $th[$Script:Ranks[$idx]]
    $nextRank = if ($idx -lt $Script:Ranks.Count-1) { $Script:Ranks[$idx+1] } else { $Script:Ranks[$idx] }
    $nextReq = $th[$nextRank]
    $span = [Math]::Max(1, $nextReq - $currReq)
    $pct = [Math]::Clamp([int](100*($xp-$currReq)/$span),0,100)
    [pscustomobject]@{
        CurrentRank=$Script:Ranks[$idx]
        NextRank=$nextRank
        ProgressPct=$pct
        ToNext= [Math]::Max(0,$nextReq-$xp)
    }
}

function Add-OsXP([int]$Points,[string]$Reason="Generic") {
    Initialize-OsStore
    $s = Get-OsStore

    # Ensure user object exists
    if (-not $s.user) {
        if ($s -is [hashtable]) { $s['user'] = @{} }
        else { $s | Add-Member -NotePropertyName user -NotePropertyValue @{} -Force }
    }
    if (-not $s.user.alias) { $s.user.alias = "Osirisborn" }
    if (-not $s.user.rank)  { $s.user.rank  = "Initiate" }
    if ($null -eq $s.user.xp) { $s.user.xp = 0 }
    if ($null -eq $s.user.progressPct) { $s.user.progressPct = 0 }

    # Add XP
    $s.user.xp = [int]$s.user.xp + $Points

    # Rank up if needed
    $th = Get-RankThresholds
    $currentIndex = $Script:Ranks.IndexOf($s.user.rank); if ($currentIndex -lt 0) { $currentIndex = 0 }
    for ($i=$currentIndex; $i -lt $Script:Ranks.Count; $i++) {
        $r = $Script:Ranks[$i]
        if ($s.user.xp -ge $th[$r]) { $s.user.rank = $r } else { break }
    }

    # Progress
    $prog = Get-CurrentProgress -xp $s.user.xp -rank $s.user.rank
    $s.user.progressPct = $prog.ProgressPct

    # Ensure meta/xpLog exist
    if (-not $s.meta) {
        if ($s -is [hashtable]) { $s['meta'] = @{} }
        else { $s | Add-Member -NotePropertyName meta -NotePropertyValue @{} -Force }
    }
    if (-not $s.meta.xpLog) {
        if ($s.meta -is [hashtable]) { $s.meta['xpLog'] = @() }
        else { $s.meta | Add-Member -NotePropertyName xpLog -NotePropertyValue @() -Force }
    }

    # Append log entry (avoid fixed-size errors)
    $entry = [pscustomobject]@{
        at=(Get-Date).ToString("o"); delta=$Points; reason=$Reason; total=$s.user.xp; rank=$s.user.rank
    }
    $s.meta.xpLog = @($s.meta.xpLog + $entry)

    Save-OsStore $s
    return $prog
}

function Get-OsXP {
    Initialize-OsStore
    $s = Get-OsStore
    if (-not $s.user) {
        return [pscustomobject]@{ Alias="Osirisborn"; Rank="Initiate"; XP=0; Next="Ghost"; ProgressPct=0; ToNext=200 }
    }
    $prog = Get-CurrentProgress -xp [int]$s.user.xp -rank $s.user.rank
    [pscustomobject]@{
        Alias=$s.user.alias
        Rank=$s.user.rank
        XP=[int]$s.user.xp
        Next=$prog.NextRank
        ProgressPct=[int]$prog.ProgressPct
        ToNext=[int]$prog.ToNext
    }
}

Export-ModuleMember -Function Add-OsXP,Get-OsXP,Get-RankThresholds
