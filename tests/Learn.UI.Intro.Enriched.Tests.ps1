Describe "Python Intro (enriched)" {
  It "has html with What you'll learn, comments, and a codepad; quiz has >=4 Qs" {
    $data = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    Test-Path -LiteralPath $data | Should -BeTrue
    $j = Get-Content -Raw -LiteralPath $data | ConvertFrom-Json
    $intro = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $intro=$l } } }
    $intro | Should -Not -BeNullOrEmpty
    $intro.html | Should -Match "What you'll learn"
    $intro.html | Should -Match "Comments"
    ($intro.PSObject.Properties.Name -contains 'codepad') | Should -BeTrue
    $intro.codepad.lang | Should -Be "python"
    ($intro.PSObject.Properties.Name -contains 'quiz') | Should -BeTrue
    $intro.quiz.questions.Count | Should -BeGreaterOrEqual 4
  }
}