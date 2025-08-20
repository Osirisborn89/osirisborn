#requires -Version 7.0
param(
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(Position=1)]
    [string]$Subcommand,
    [Parameter(Position=2)]
    [string]$Arg1,
    [Parameter(Position=3)]
    [string]$Arg2,
    [Parameter(Position=4)]
    [string]$Arg3
)

$modules = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modules "Osirisborn.Store.psm1")    -Force
Import-Module (Join-Path $modules "Osirisborn.XP.psm1")       -Force
Import-Module (Join-Path $modules "Osirisborn.Missions.psm1") -Force

switch -Regex ($Command) {

    # XP commands
    '^xp$' {
        if ($Subcommand -match '^\d+$') {
            $delta  = [int]$Subcommand
            $reason = if ($Arg1) { "$Arg1 $Arg2 $Arg3" } else { "Generic" }
            $p = Add-OsXP -Points $delta -Reason $reason
            "XP +$delta ($reason) → $($p.CurrentRank) → $($p.ProgressPct)% toward $($p.NextRank) (to next: $($p.ToNext))"
        }
        else {
            $o = Get-OsXP
            "$($o.Alias) — Rank: $($o.Rank), XP: $($o.XP), $($o.ProgressPct)% toward $($o.Next) (to next: $($o.ToNext))"
        }
    }

    # Mission commands
    '^mission$' {
        switch -Regex ($Subcommand) {
            '^add$' {
                if (-not $Arg1 -or -not $Arg2 -or -not $Arg3) { throw "Usage: mission add <id> <xp> <title>" }
                $id    = $Arg1
                $xp    = [int]$Arg2
                $title = "$Arg3"
                Add-OsMission -Id $id -Title $title -XP $xp
            }
            '^list$' {
                Get-OsMissions
            }
            '^complete$' {
                if (-not $Arg1) { throw "Usage: mission complete <id>" }
                Complete-OsMission -Id $Arg1
            }
            default { throw "Unknown mission subcommand: $Subcommand" }
        }
    }

    default {
        "Unknown command: $Command"
    }
}
