$repo = "C:\Users\day_8\dev\osirisborn"
$loader  = Join-Path $repo "MythicCore\www\js\langs.loader.js"
$css     = Join-Path $repo "MythicCore\www\langs.lessons.css"
$data    = Join-Path $repo "MythicCore\www\data\learn\python.json"

Describe "Codepad/Content guards" {
  It "loader contains codepad functions" {
    Test-Path $loader | Should -BeTrue
    $c = Get-Content -Raw $loader
    $c | Should -Match "function codepadHTML"
    $c | Should -Match "function mountCodepad"
    $c | Should -Match "runPython"
    $c | Should -Match "runJavaScript"
  }
  It "CSS defines .codepad styles" {
    Test-Path $css | Should -BeTrue
    (Get-Content -Raw $css) | Should -Match "\.codepad\s*\{"
  }
  It "python intro lesson defines a codepad block" {
    Test-Path $data | Should -BeTrue
    $j = Get-Content -Raw $data | ConvertFrom-Json
    $lesson = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $lesson=$l } } }
    $lesson | Should -Not -BeNullOrEmpty
    $lesson.codepad.lang | Should -Be "python"
    $lesson.html | Should -Match "<h2>Overview</h2>"
    $lesson.html | Should -Match "<h3>Guided task</h3>"
  }
}