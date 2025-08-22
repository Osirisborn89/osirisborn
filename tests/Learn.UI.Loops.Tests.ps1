Describe "Python Loops lesson" {
  It "exists with codepad and quiz" {
    $j = Get-Content -Raw -LiteralPath "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json" | ConvertFrom-Json
    $loops = $null; foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-loops-04"){ $loops=$l } } }
    $loops | Should -Not -BeNullOrEmpty
    ($loops.PSObject.Properties.Name -contains "codepad") | Should -BeTrue
    $loops.codepad.lang | Should -Be "python"
    $loops.quiz.questions.Count | Should -BeGreaterOrEqual 6
    $loops.html | Should -Match "for"
    $loops.html | Should -Match "range"
    $loops.html | Should -Match "list"
  }
}