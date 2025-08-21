# Pester 5 basic integrity tests for Learn pages (no CSS literals here)
BeforeAll {
  Set-Location (Join-Path $PSScriptRoot '..')
}

Describe 'Learn Pages — Integrity' {
  It 'Portal includes lessons CSS/JS' {
    $html = Get-Content -Raw -Path .\MythicCore\www\portal.standalone.html -Encoding UTF8
    $html | Should -Match 'langs\.lessons\.css'
    $html | Should -Match 'js/langs\.loader\.js'
  }

  It 'CSS lint passes' {
    pwsh -NoProfile -File .\tools\Lint-CSS.ps1
    $LASTEXITCODE | Should -Be 0
  }
}
