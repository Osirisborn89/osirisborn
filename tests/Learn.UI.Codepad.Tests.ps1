# Learn.UI.Codepad.Tests.ps1 — hard-coded paths, PS5.1-safe
$ErrorActionPreference = 'Stop'

# --- absolute paths on your machine ---
$RepoRoot       = 'C:\Users\day_8\dev\osirisborn'
$LoaderPath     = 'C:\Users\day_8\dev\osirisborn\MythicCore\www\js\langs.loader.js'
$CssPath        = 'C:\Users\day_8\dev\osirisborn\MythicCore\www\langs.lessons.css'
$PythonJsonPath = 'C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json'

Describe 'Codepad/Content guards' {

  It 'path sanity (loader/css/json present)' {
    Test-Path -LiteralPath $LoaderPath     | Should -BeTrue -Because "expected langs.loader.js at $LoaderPath"
    Test-Path -LiteralPath $CssPath        | Should -BeTrue -Because "expected langs.lessons.css at $CssPath"
    Test-Path -LiteralPath $PythonJsonPath | Should -BeTrue -Because "expected python.json at $PythonJsonPath"
  }

  BeforeAll {
    $script:loaderText = Get-Content -LiteralPath $LoaderPath -Raw -Encoding UTF8
    $script:cssText    = Get-Content -LiteralPath $CssPath -Raw -Encoding UTF8
    $script:json       = Get-Content -LiteralPath $PythonJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }

  It 'loader contains codepad functions' {
    $script:loaderText | Should -Match 'function\s+codepadHTML'
    $script:loaderText | Should -Match 'function\s+mountCodepad'
    $script:loaderText | Should -Match 'runPython'
    $script:loaderText | Should -Match 'runJavaScript'
  }

  It 'CSS defines .codepad styles' {
    $script:cssText | Should -Match '\.codepad\s*\{'
  }

  It 'python intro lesson defines a codepad block' {
    $lesson = $null
    foreach ($m in $script:json.modules) {
      foreach ($l in $m.lessons) {
        if ($l.id -eq 'python-intro-01') { $lesson = $l; break }
      }
      if ($lesson) { break }
    }

    $lesson | Should -Not -BeNullOrEmpty
    $lesson.codepad.lang | Should -Be 'python'
    $lesson.html | Should -Match '<h2>\s*(What is Python\?|Overview)\s*</h2>'
    $lesson.html | Should -Match '<h3>Guided task</h3>'
    $lesson.html | Should -Match '<div\s+class="codepad"[^>]*data-lang="python"'
  }
}
