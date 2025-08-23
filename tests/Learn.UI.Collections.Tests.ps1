# Learn.UI.Collections.Tests.ps1
# Purpose: Verify the Collections lesson exists, has correct heading, codepad lang, and a sane quiz.
# Conventions: single-quoted regex; absolute -LiteralPath; deep JSON parse.

$repo     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repo 'MythicCore\www\data\learn\python.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }

Describe 'Collections lesson' {
  It 'exists and is parseable' {
    $raw = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json -Depth 100
    $obj | Should -Not -BeNullOrEmpty

    # enumerate lessons
    $lessons = @()
    if ($null -ne $obj.lessons) { $lessons += $obj.lessons }
    foreach ($track in @($obj.tracks)) {
      foreach ($sec in @($track.sections)) {
        if ($sec -and $sec.lessons) { $lessons += @($sec.lessons) }
      }
    }

    $lesson = $lessons | Where-Object { $_.id -eq 'python-collections-07' } | Select-Object -First 1
    $lesson | Should -Not -BeNullOrEmpty

    # Heading tolerant: allow 'Collections in Python' or 'Collections'
    if ($lesson.html -and ($lesson.html -is [string])) {
      $lesson.html | Should -Match '<h2>\s*(Collections in Python|Collections)\s*</h2>'
      # Codepad presence + data-lang="python"
      $lesson.html | Should -Match '<div\s+class="codepad"[^>]*data-lang="python"'
    }

    # codepad object present and lang = python
    if ($lesson.codepad) {
      "$($lesson.codepad.lang)" | Should -Be 'python'
    }

    # Quiz sanity
    ($lesson.quiz -and $lesson.quiz.items.Count -ge 5) | Should -BeTrue

    # No duplicate quiz question text
    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($q in $lesson.quiz.items) {
      $qt = ("$($q.question)").Trim()
      if (-not $set.Add($qt)) { throw "Duplicate quiz question: $qt" }
    }
  }
}