$repo = "C:\Users\day_8\dev\osirisborn"
$data = Join-Path $repo "MythicCore\www\data\learn\python.json"

Describe "Content — Python Intro has real lesson HTML" {
  It "python.json exists" { Test-Path $data | Should -BeTrue }
  It "intro lesson contains hello world snippet and headings" {
    $j = Get-Content -Raw $data | ConvertFrom-Json
    $lesson = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $lesson=$l } } }
    $lesson | Should -Not -BeNullOrEmpty
    $lesson.html | Should -Match "<h2>What is Python\?</h2>"
    $lesson.html | Should -Match "print\(\"Hello, world!\"\)"
  }
}