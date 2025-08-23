publish/fix-intro-h2-and-content-path-20250823-202457
### OSIRISBORN HEADER — DO NOT REMOVE ###
# PS7-safe absolute paths for this repo; prevents $jsonPath nulls
$repo     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repo 'MythicCore\www\data\learn\python.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }
### /OSIRISBORN HEADER ###

# Learn.UI.Content.Tests.ps1 — hard-coded path, PS5.1-safe
$ErrorActionPreference = 'Stop'

# absolute path to your python.json
$PythonJsonPath = 'C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json'

=======
﻿# Learn.UI.Content.Tests.ps1 — hard-coded path, PS5.1-safe
$ErrorActionPreference = 'Stop'

# absolute path to your python.json
$PythonJsonPath = 'C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json'

main
Describe 'Content — Python Intro has real lesson HTML' {

  It 'python.json exists' {
    Test-Path -LiteralPath $PythonJsonPath | Should -BeTrue -Because "expected python.json at $PythonJsonPath"
  }

  BeforeAll {
    $script:json = Get-Content -LiteralPath $PythonJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  }

  It 'intro lesson contains required heading & codepad' {
    $lesson = $null
    foreach ($m in $script:json.modules) {
      foreach ($l in $m.lessons) {
        if ($l.id -eq 'python-intro-01') { $lesson = $l; break }
      }
      if ($lesson) { break }
    }

    $lesson      | Should -Not -BeNullOrEmpty
    $lesson.html | Should -Match '<h2>\s*(What is Python\?|Overview)\s*</h2>'
    $lesson.html | Should -Match '<h3>Guided task</h3>'
    $lesson.html | Should -Match '(?s)<pre><code class="language-python">.*?</code></pre>'
    $lesson.html | Should -Match '<div\s+class="codepad"[^>]*data-lang="python"'
  }
}
