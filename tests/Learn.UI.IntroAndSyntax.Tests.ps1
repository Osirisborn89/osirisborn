Describe "Python Intro & Syntax lessons sanity (pinned paths)" {

  It "python.json exists at absolute path" {
    $data = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    if (-not (Test-Path -LiteralPath $data)) {
      Write-Host "DEBUG: Could not find $data" -ForegroundColor Yellow
      Write-Host "DEBUG: Listing dir contents:" -ForegroundColor Yellow
      Get-ChildItem -LiteralPath "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn" -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_.FullName }
    }
    Test-Path -LiteralPath $data | Should -BeTrue
  }

  It "Intro teaches print and has codepad" {
    $data  = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    $json  = Get-Content -Raw -LiteralPath $data | ConvertFrom-Json
    $intro = $null
    foreach($m in $json.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-intro-01"){ $intro=$l } } }
    $intro | Should -Not -BeNullOrEmpty
    $intro.html | Should -Match "print\("
    ($intro.PSObject.Properties.Name -contains 'codepad') | Should -BeTrue
    $intro.codepad.lang | Should -Be "python"
  }

  It "Syntax Primer has HTML about indentation and has codepad" {
    $data   = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    $json   = Get-Content -Raw -LiteralPath $data | ConvertFrom-Json
    $syntax = $null
    foreach($m in $json.modules){ foreach($l in $m.lessons){ if($l.id -eq "python-syntax-03"){ $syntax=$l } } }
    $syntax | Should -Not -BeNullOrEmpty
    $syntax.html | Should -Match "indentation"
    ($syntax.PSObject.Properties.Name -contains 'codepad') | Should -BeTrue
  }
}