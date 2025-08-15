#requires -Version 7.0
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot "Osirisborn.Store.psm1") -Force -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot "Osirisborn.XP.psm1")    -Force -ErrorAction Stop

function ConvertTo-Hashtable {
    param([object]$obj)
    if ($null -eq $obj) { return @{} }
    if ($obj -is [hashtable]) { return $obj }
    $ht = @{}
    foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
    return $ht
}

function Ensure-MissionState {
    param([object]$s)

    # ensure missions exists
    if (-not $s.missions) {
        if ($s -is [hashtable]) { $s['missions'] = @{} }
        else { $s | Add-Member -NotePropertyName missions -NotePropertyValue @{} -Force }
    }

    # coerce shapes each call (catalog => hashtable; arrays => IList)
    $s.missions         = ConvertTo-Hashtable $s.missions
    $s.missions.catalog = ConvertTo-Hashtable $s.missions.catalog

    if (-not ($s.missions.completed  -is [System.Collections.IList])) { $s.missions.completed  = @() }
    if (-not ($s.missions.inProgress -is [System.Collections.IList])) { $s.missions.inProgress = @() }
}

function Add-OsMission {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][int]$XP
    )
    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    # add/update catalog entry (catalog is hashtable now)
    $s.missions.catalog[$Id] = [pscustomobject]@{
        id      = $Id
        title   = $Title
        xp      = $XP
        created = (Get-Date).ToString("o")
    }

    # track as in-progress unless already completed
    if (-not ($s.missions.completed -contains $Id) -and -not ($s.missions.inProgress -contains $Id)) {
        $s.missions.inProgress = @($s.missions.inProgress + $Id)
    }

    Save-OsStore $s
    [pscustomobject]@{ Id=$Id; Title=$Title; XP=[int]$XP }
}

function Get-OsMissions {
    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    $keys = $s.missions.catalog.Keys  # guaranteed hashtable now
    $list = foreach ($k in $keys) {
        $m = $s.missions.catalog[$k]
        $status = if ($s.missions.completed -contains $k) { "Completed" }
                  elseif ($s.missions.inProgress -contains $k) { "In Progress" }
                  else { "New" }
        [pscustomobject]@{
            Id     = $m.id
            Title  = $m.title
            XP     = [int]$m.xp
            Status = $status
        }
    }

    $list | Sort-Object Status, Id
}

function Complete-OsMission {
    param([Parameter(Mandatory)][string]$Id)

    Initialize-OsStore
    $s = Get-OsStore
    Ensure-MissionState $s

    $keys = $s.missions.catalog.Keys  # hashtable, so Keys works
    if (-not ($keys -contains $Id)) { throw "Mission not found: $Id" }
    if ($s.missions.completed -contains $Id) { return "Already completed." }

    # move to completed
    $s.missions.inProgress = @($s.missions.inProgress | Where-Object { $_ -ne $Id })
    $s.missions.completed  = @($s.missions.completed  + $Id)

    $xpAward = [int]$s.missions.catalog[$Id].xp

    # save mission state first
    Save-OsStore $s

    # award XP and mirror
    $p = Add-OsXP -Points $xpAward -Reason "Mission: $Id"
    "Completed '$Id' (+$xpAward XP) → $($p.CurrentRank) $($p.ProgressPct)% toward $($p.NextRank)"
}

Export-ModuleMember -Function Add-OsMission,Get-OsMissions,Complete-OsMission
