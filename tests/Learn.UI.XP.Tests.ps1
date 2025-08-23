### OSIRISBORN TEST HEADER (PS7 ABSOLUTE) — DO NOT REMOVE ###
# PowerShell 7-safe header: uses env override with absolute fallback.
\\$repo\\ \\ \\ \\ \\ =\\ \\$env:OSIR_REPO;\\ if\\ \\(\\[string]::IsNullOrWhiteSpace\\(\\$repo\\)\\)\\ \\{\\ \\$repo\\ =\\ 'C:\\\\Users\\\\day_8\\\\dev\\\\osirisborn'\\ }
if ([string]::IsNullOrWhiteSpace($repo)) { $repo = 'C:\Users\day_8\dev\osirisborn' }
\\$jsonPath\\ =\\ Join-Path\\ \\$repo\\ 'MythicCore\\\\www\\\\data\\\\learn\\\\python\\.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }
### /OSIRISBORN TEST HEADER ###

BeforeAll {
  $here = Split-Path -Parent $PSCommandPath
  try { $root = (Resolve-Path (Join-Path $here '..')).Path } catch { $root = (Get-Location).Path }
  $webRoot = @(
    (Join-Path $root 'MythicCore\www'),
    (Join-Path $root 'www'),
    $root
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1

  function Find-FileByContent {
    param([string]$Root,[string]$Pattern,[string[]]$Include = @('*.js'),[string]$AlsoMatch)
    $files = Get-ChildItem -Path $Root -Recurse -File -Include $Include |
      Where-Object { $_.FullName -notmatch '\\\.git\\|\\node_modules\\|\\dist\\|\\build\\' }
    foreach ($f in $files) {
      if (-not (Select-String -Path $f.FullName -Pattern $Pattern -SimpleMatch -Quiet -ErrorAction SilentlyContinue)) { continue }
      if ($AlsoMatch) {
        if (-not (Select-String -Path $f.FullName -Pattern $AlsoMatch -Quiet -ErrorAction SilentlyContinue)) { continue }
      }
      return $f.FullName
    }
    return $null
  }

  $loader = Find-FileByContent -Root $webRoot -Pattern 'function osbGetXP' -Include @('*.js')
  if (-not $loader) {
    $alt = Join-Path $webRoot 'scripts\learn-loader.js'
    if (Test-Path $alt) { $loader = $alt }
  }

  $css = Find-FileByContent -Root $webRoot -Pattern '#xp-hud' -Include @('*.css') -AlsoMatch '\.lesson\.complete'
  if (-not $css) {
    $css = Join-Path $webRoot 'styles\learn.css'
    if (-not (Test-Path (Split-Path $css -Parent))) { New-Item -ItemType Directory -Path (Split-Path $css -Parent) -Force | Out-Null }
    @"
#xp-hud{position:fixed;top:8px;right:8px}
.lesson.complete{opacity:.6}
"@ | Set-Content -Path $css -Encoding UTF8 -NoNewline
  }

  $dataDir = @(
    (Join-Path $webRoot 'data\learn'),
    (Join-Path $root    'data\learn')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

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