# Learn.UI.Intro.Coverage.Tests.ps1 — robust intro coverage (absolute paths, PS7-safe)
$ErrorActionPreference = "Stop"

$pythonJson = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
if (-not (Test-Path -LiteralPath $pythonJson)) { throw "Not found: $pythonJson" }

Describe "Intro content coverage (standalone)" {
  It "loads python.json and validates Intro heading + codepad" {
    $raw = Get-Content -LiteralPath $pythonJson -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json -Depth 200
    $obj | Should -Not -BeNullOrEmpty

    # Collect all lessons across possible shapes
    $lessons = New-Object System.Collections.Generic.List[object]
    if ($null -ne $obj.lessons) { $lessons.AddRange([object[]]$obj.lessons) }
    if ($null -ne $obj.modules) { foreach ($m in $obj.modules) { if ($m.lessons) { $lessons.AddRange([object[]]$m.lessons) } } }
    if ($null -ne $obj.tracks)  {
      foreach ($t in $obj.tracks) {
        if ($t.sections) {
          foreach ($s in $t.sections) {
            if ($s.lessons) { $lessons.AddRange([object[]]$s.lessons) }
          }
        }
      }
    }

    function S($v){ if ($null -eq $v) { "" } else { "$v" } }

    # Heuristics for Intro
    $intro = $lessons | Where-Object {
      $id = S($_.id); $title = S($_.title)
      $id -match "python[-_]?intro" -or
      $title -match "^\s*intro\b" -or
      $title -match "what\s+is\s+python" -or
      $id -match "intro-0*1$"
    } | Select-Object -First 1

    if (-not $intro) {
      $intro = $lessons | Where-Object { S($_.html) -match "<h2>\s*(What is Python\?|Overview)\s*</h2>" } | Select-Object -First 1
    }
    if (-not $intro) {
      $intro = $lessons | Where-Object { $_.codepad -and (S($_.codepad.lang)) -match "^python$" } | Select-Object -First 1
    }

    if (-not $intro) {
      $ids    = ($lessons | ForEach-Object { S($_.id) }    | Where-Object { $_ -ne "" }) -join ", "
      $titles = ($lessons | ForEach-Object { S($_.title) } | Where-Object { $_ -ne "" }) -join ", "
      throw "Could not locate Intro lesson. Saw lesson ids: [$ids]; titles: [$titles]"
    }

    $html = S($intro.html)
    if ($html -ne "") {
      $html | Should -Match "<h2>\s*(What is Python\?|Overview)\s*</h2>"
      $html | Should -Match "<div\s+class=""codepad"""
    } else {
      # If no inline HTML, at least require a python codepad
      ($intro.codepad -and (S($intro.codepad.lang)) -match "^python$") | Should -BeTrue
    }
  }
}