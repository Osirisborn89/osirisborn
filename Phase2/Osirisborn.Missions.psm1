#requires -Version 7.0
Import-Module (Join-Path $PSScriptRoot "Osirisborn.Store.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Osirisborn.XP.psm1")    -Force

function ConvertTo-Hashtable([object]$obj) {
    if ($obj -is [hashtable]) { return $obj }
    $ht = @{}
    if ($null -ne $obj) {
        foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
    }
    return $ht
}

function Ensure-MissionState([object]$s) {
    if (-not $s.missions) {
        if ($s -is [hashtable]) { $s['missions'] = @{} }
        else { $s | Add-Member -NotePropertyName missions -NotePropertyValue @{} -Force }
    }
    $s.missions = ConvertTo-Hashtable $s.missions
    $s.missions.catalog = ConvertTo-Hashtable $s.missions.catalog
    if (-not $s.missions.completed   -or $s.missions.completed.GetType().GetInterface('IList') -eq $null) { $s.missions.completed  = @() }
    if (-not $s.missions.inProgress  -or $s.missions.inProgress.GetType().GetInterface('IList') -eq $null) { $s.missions.inProgress = @() }
}

function Add-OsMission([string]$Id, [string]$Title, [int]$XP) {
    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    $s.missions.catalog[$Id] = [pscustomobject]@{
        id = $Id; title = $Title; xp = $XP; created = (Get-Date).ToString("o")
    }

    if (-not ($s.missions.inProgress -contains $Id) -and -not ($s.missions.completed -contains $Id)) {
        $s.missions.inProgress = @($s.missions.inProgress + $Id)
    }

    Save-OsStore $s
    [pscustomobject]@{ Id=$Id; Title=$Title; XP=[int]$XP }
}

function Get-OsMissions {
    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    $list = foreach ($k in $s.missions.catalog.Keys) {
        $m = $s.missions.catalog[$k]
        $status = if ($s.missions.completed -contains $k) { "Completed" } elseif ($s.missions.inProgress -contains $k) { "In Progress" } else { "New" }
        [pscustomobject]@{
            Id     = $m.id
            Title  = $m.title
            XP     = [int]$m.xp
            Status = $status
        }
    }

    $list | Sort-Object Status, Id
}

function Complete-OsMission([string]$Id) {
    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    if (-not $s.missions.catalog.ContainsKey($Id)) { throw "Mission not found: $Id" }
    if ($s.missions.completed -contains $Id) { return "Already completed." }

    $s.missions.inProgress = @($s.missions.inProgress | Where-Object { $_ -ne $Id })
    $s.missions.completed  = @($s.missions.completed  + $Id)

    $xpAward = [int]$s.missions.catalog[$Id].xp
    Save-OsStore $s
    $p = Add-OsXP -Points $xpAward -Reason "Mission: $Id"

    "Completed '$Id' (+$xpAward XP) → $($p.CurrentRank) $($p.ProgressPct)% toward $($p.NextRank)"
}

Export-ModuleMember -Function Add-OsMission,Get-OsMissions,Complete-OsMission
