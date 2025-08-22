Describe "DEV unlock + clicks" {
  It "loader contains delegated click handler and dev-skip for locks" {
    $p = "C:\Users\day_8\dev\osirisborn\MythicCore\www\js\langs.loader.js"
    $c = Get-Content -Raw -LiteralPath $p
    $c | Should -Match "osbDelegatedClickV1"
    $c | Should -Match "skip locks in dev"
  }
  It "setup quiz exists (>= 5 questions)" {
    $j = Get-Content -Raw -LiteralPath "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json" | ConvertFrom-Json
    $setup = $null; foreach($m in $j.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-setup-01"){ $setup=$l } } }
    $setup | Should -Not -BeNullOrEmpty
    ($setup.PSObject.Properties.Name -contains "quiz") | Should -BeTrue
    $setup.quiz.questions.Count | Should -BeGreaterOrEqual 5
  }
}