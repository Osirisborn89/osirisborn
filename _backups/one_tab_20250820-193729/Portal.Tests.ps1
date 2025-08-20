$ErrorActionPreference='Stop'

BeforeAll {
  & "$PSScriptRoot/../tools/Reset-Server.ps1" | Out-Null
  Start-Sleep -Milliseconds 250
}

Describe "Purple portal shell" {
  It "serves canonical assets (200)" {
    foreach ($p in '/portal.css','/js/portal.routes.js','/js/sw-register.js','/js/boot.portal.js') {
      (Invoke-WebRequest ("http://127.0.0.1:7780$($p)") -UseBasicParsing).StatusCode | Should -Be 200
    }
  }

  It "index.html is the purple shell (not legacy)" {
    $html = (Invoke-WebRequest "http://127.0.0.1:7780/" -UseBasicParsing).Content
    $html | Should -Match 'data-nav.*Home'
    $html | Should -Match 'id="view-home"'
    $html | Should -Match 'js/portal\.routes\.js\?v=\d+'
    $html | Should -NotMatch 'xp-panel'
    $html | Should -NotMatch 'src=["'']/=\d+'   # catches the bad =123 tags
  }
}
