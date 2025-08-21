BeforeAll { Set-Location (Join-Path $PSScriptRoot "..") }
Describe "Learn Pages — Guardrails" {
  It "Portal includes lessons CSS/JS and inline boot/css" {
    $html = Get-Content -Raw -Path .\MythicCore\www\portal.standalone.html -Encoding UTF8
    $html | Should -Match 'langs\.lessons\.css'
    $html | Should -Match 'js/langs\.loader\.js'
    $html | Should -Match 'id="lang-route-boot"'
    $html | Should -Match 'id="lang-hardmask-inline"'
  }
  It "Loader defines RESERVED routes" {
    $js = Get-Content -Raw -Path .\MythicCore\www\js\langs.loader.js -Encoding UTF8
    $js | Should -Match 'var RESERVED = \{'
    $js | Should -Match "'coding'"
  }
  It "CSS lint passes" {
    pwsh -NoProfile -File .\tools\Lint-CSS.ps1
    $LASTEXITCODE | Should -Be 0
  }
}
