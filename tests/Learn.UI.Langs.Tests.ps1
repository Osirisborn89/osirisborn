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
$repo = "C:\Users\day_8\dev\osirisborn"

Describe "Learn UI — Loader & CSS guards" {
  $loader  = Join-Path $repo "MythicCore\www\js\langs.loader.js"
  $css     = Join-Path $repo "MythicCore\www\langs.lessons.css"

  It "has hardened loader present and DOM-ready guards" {
    Test-Path $loader | Should -BeTrue
    $c = Get-Content -Raw $loader
    $c | Should -Match "RESERVED"
    $c | Should -Match "DOMContentLoaded"
    $c | Should -Match "hashchange"
  }
  It "has gated CSS with #lang-root rules and LANG badge" {
    Test-Path $css | Should -BeTrue
    $k = Get-Content -Raw $css
    $k | Should -Match "#lang-root"
    $k | Should -Match "route-lang-hasdata"
    $k | Should -Match "lang-debug-badge"
  }
}

Describe "Learn UI — Track JSONs" {
  $dataDir = Join-Path $repo "MythicCore\www\data\learn"

  It "JSON file exists for <_>" -ForEach $Langs {
    $L = $_
    $path = Join-Path $dataDir "$L.json"
    Test-Path $path | Should -BeTrue
  }

  It "parses and has >=1 module (>=3 lessons) for <_>" -ForEach $Langs {
    $L = $_
    $path = Join-Path $dataDir "$L.json"
    $j = Get-Content -Raw $path | ConvertFrom-Json
    $j.lang | Should -Be $L
    $j.modules.Count | Should -BeGreaterOrEqual 1
    $j.modules[0].lessons.Count | Should -BeGreaterOrEqual 3
  }

  It "is reachable (soft) for <_>" -ForEach $Langs {
    $L = $_
    # quick early skip if server not running on 127.0.0.1:7780
    $serverUp = $false
    try {
      $ping = Invoke-WebRequest -Uri "http://127.0.0.1:7780/portal.standalone.html" -UseBasicParsing -TimeoutSec 1
      if ($ping.StatusCode -ge 200 -and $ping.StatusCode -lt 500) { $serverUp = $true }
    } catch {}
    if (-not $serverUp) {
      Set-ItResult -Skipped -Because "Server not reachable"
      return
    }

    $b   = Get-Date -Format "yyyyMMddHHmmss"
    $url = "http://127.0.0.1:7780/data/learn/$L.json?bust=$b"
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
    $r.StatusCode | Should -Be 200

    $pattern = '"lang"\s*:\s*"' + [regex]::Escape($L) + '"'
    ($r.Content) | Should -Match $pattern
  }
}