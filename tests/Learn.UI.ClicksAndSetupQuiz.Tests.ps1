Describe "Setup quiz + click handler" {
  It "setup quiz exists with >= 3 questions" {
    $data = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    Test-Path -LiteralPath $data | Should -BeTrue
    $j = Get-Content -Raw -LiteralPath $data | ConvertFrom-Json
    $setup = $null
    foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-setup-01"){ $setup = $l } } }
    $setup | Should -Not -BeNullOrEmpty
    ($setup.PSObject.Properties.Name -contains 'quiz') | Should -BeTrue
    $setup.quiz.questions.Count | Should -BeGreaterOrEqual 3
  }
  It "loader uses location.hash in click handler" {
    $loader = "C:\Users\day_8\dev\osirisborn\MythicCore\www\js\langs.loader.js"
    (Get-Content -Raw -LiteralPath $loader) | Should -Match "location\.hash"
  }
}