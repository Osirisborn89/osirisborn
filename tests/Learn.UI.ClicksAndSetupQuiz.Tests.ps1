### OSIRISBORN TEST HEADER (PS7 ABSOLUTE) — DO NOT REMOVE ###
# PowerShell 7-safe header: uses env override with absolute fallback.
\\$repo\\ \\ \\ \\ \\ =\\ \\$env:OSIR_REPO;\\ if\\ \\(\\[string]::IsNullOrWhiteSpace\\(\\$repo\\)\\)\\ \\{\\ \\$repo\\ =\\ 'C:\\\\Users\\\\day_8\\\\dev\\\\osirisborn'\\ }
if ([string]::IsNullOrWhiteSpace($repo)) { $repo = 'C:\Users\day_8\dev\osirisborn' }
\\$jsonPath\\ =\\ Join-Path\\ \\$repo\\ 'MythicCore\\\\www\\\\data\\\\learn\\\\python\\.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }
### /OSIRISBORN TEST HEADER ###

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