# osbCompatGlobalsV3
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot "MythicCore\www\js\langs.loader.js" }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot "MythicCore\www\langs.lessons.css" }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot "MythicCore\www\data\learn\python.json" }
  $global:loader = $LoaderPath
  $global:css    = $CssPath
  $global:data   = $PythonJsonPath
} catch {}
# osbCompatGlobalsV2
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  $global:loader = $LoaderPath
  $global:css    = $CssPath
  $global:data   = $PythonJsonPath
} catch {}
# osbTestPathGuardV2 (safe after Param)
try {
  if (-not (Test-Path variable:\RepoRoot) -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
  }
} catch {}


# osbTestCompatVarsV1
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  if (-not $loader) { $script:loader = $LoaderPath }
  if (-not $css)    { $script:css    = $CssPath }
  if (-not $data)   { $script:data   = $PythonJsonPath }
} catch {}
try {
  if (-not $LoaderPath -or -not (Test-Path $LoaderPath)) {
    $LoaderPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\js\langs.loader.js"
    if (-not (Test-Path $LoaderPath)) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  }
  if (-not $CssPath -or -not (Test-Path $CssPath)) {
    $CssPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\langs.lessons.css"
    if (-not (Test-Path $CssPath)) { $CssPath = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  }
  if (-not $PythonJsonPath -or -not (Test-Path $PythonJsonPath)) {
    $PythonJsonPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    if (-not (Test-Path $PythonJsonPath)) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  }
} catch {}
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