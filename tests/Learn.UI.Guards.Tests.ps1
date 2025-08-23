# Learn.UI.Guards.Tests.ps1
# Purpose: stability guards to prevent regressions (duplicate quiz items, missing codepad/attr)
# Notes: Single-quoted regex, absolute -LiteralPath, deep JSON parse.

# Resolve repo root relative to this file
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$jsonPath = Join-Path $repo 'MythicCore\www\data\learn\python.json'

Describe 'Learn UI Guards' {
  It 'loads python.json deeply' {
    $raw = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json -Depth 100
    $obj | Should -Not -BeNullOrEmpty
  }

  # helper to enumerate all lessons
  $raw = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
  $root = $raw | ConvertFrom-Json -Depth 100
  $lessons = @()
  if ($null -ne $root.lessons) { $lessons += $root.lessons }
  foreach ($track in @($root.tracks)) {
    foreach ($sec in @($track.sections)) {
      if ($sec -and $sec.lessons) { $lessons += @($sec.lessons) }
    }
  }

  Context 'quiz duplicate guard' {
    It 'has no duplicate quiz question text within any single lesson' {
      foreach ($l in $lessons) {
        if ($null -ne $l -and $l.quiz -and $l.quiz.items) {
          $set = [System.Collections.Generic.HashSet[string]]::new()
          foreach ($q in $l.quiz.items) {
            $qt = ("$($q.question)").Trim()
            if (-not $set.Add($qt)) {
              throw "Duplicate quiz question in lesson '$($l.id ?? $l.title)': $qt"
            }
          }
        }
      }
      $true | Should -BeTrue
    }
  }

  Context 'codepad presence & attributes' {
    It 'ensures lessons that include a codepad in HTML also define a codepad data-lang' {
      foreach ($l in $lessons) {
        # If HTML includes a codepad div, require data-lang="python"
        $html = $l.html
        if ($html -and ($html -is [string]) -and ($html -match '<div\s+class="codepad"')) {
          $html | Should -Match '<div\s+class="codepad"[^>]*data-lang="python"'
        }
      }
    }
  }
}