# Use the folder this test file lives in to find the repo root reliably
$repo = Split-Path $PSScriptRoot -Parent
$loader = Join-Path $repo "MythicCore\www\js\langs.loader.js"
$data   = Join-Path $repo "MythicCore\www\data\learn\python.json"

Describe "Lesson + Codepad sanity" {
  It "paths resolve to files" {
    $loader | Should -Not -BeNullOrEmpty
    $data   | Should -Not -BeNullOrEmpty
    Test-Path $loader | Should -BeTrue
    Test-Path $data   | Should -BeTrue
  }

  It "loader exposes codepad hooks" {
    $c = Get-Content -Raw $loader
    $c | Should -Match "function codepadHTML"
    $c | Should -Match "function mountCodepad"
  }

  It "intro teaches indentation and has a codepad" {
    $j = Get-Content -Raw $data | ConvertFrom-Json
    $lesson = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $lesson=$l } } }
    $lesson | Should -Not -BeNullOrEmpty
    $lesson.html | Should -Match "Blocks in Python"
    $lesson.html | Should -Match "indentation"
    ($lesson.PSObject.Properties.Name -contains 'codepad') | Should -BeTrue
    $lesson.codepad.lang | Should -Be "python"
  }

  It "codepad starter is truly multi-line" {
    $j = Get-Content -Raw $data | ConvertFrom-Json
    $lesson = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $lesson=$l } } }
    (($lesson.codepad.starter -split "(`r`n|`n|`r)").Count) | Should -BeGreaterThan 1
  }
}