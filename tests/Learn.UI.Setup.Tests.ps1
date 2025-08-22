Describe "Python Setup lesson (beginner + venv/pip)" {
  It "has html mentioning 'What is a terminal?', venv, pip, and has a quiz" {
    $data = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    Test-Path -LiteralPath $data | Should -BeTrue
    $j = Get-Content -Raw -LiteralPath $data | ConvertFrom-Json
    $setup = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-setup-01"){ $setup=$l } } }
    $setup | Should -Not -BeNullOrEmpty
    $setup.html | Should -Match "What is a terminal"
    $setup.html | Should -Match "venv"
    $setup.html | Should -Match "pip"
    ($setup.PSObject.Properties.Name -contains 'quiz') | Should -BeTrue
    $setup.quiz.questions.Count | Should -BeGreaterOrEqual 6
  }
}