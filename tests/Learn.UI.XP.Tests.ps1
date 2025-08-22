$repo = "C:\Users\day_8\dev\osirisborn"
$loader  = Join-Path $repo "MythicCore\www\js\langs.loader.js"
$css     = Join-Path $repo "MythicCore\www\langs.lessons.css"
$dataDir = Join-Path $repo "MythicCore\www\data\learn"

Describe "LMS XP/Progress guards" {
  It "loader has XP helpers + awardOnce" {
    Test-Path $loader | Should -BeTrue
    $c = Get-Content -Raw $loader
    $c | Should -Match "function osbGetXP"
    $c | Should -Match "function osbAwardOnce"
    $c | Should -Match "function osbMarkComplete"
  }
  It "CSS defines xp hud + completed lesson style" {
    Test-Path $css | Should -BeTrue
    $k = Get-Content -Raw $css
    $k | Should -Match "#xp-hud"
    $k | Should -Match "\.lesson\.complete"
  }
  It "python lesson has an id to mark complete" {
    $p = Join-Path $dataDir "python.json"
    Test-Path $p | Should -BeTrue
    $j = Get-Content -Raw $p | ConvertFrom-Json
    $j.modules[0].lessons[0].id | Should -Match "python-intro-01"
  }
}