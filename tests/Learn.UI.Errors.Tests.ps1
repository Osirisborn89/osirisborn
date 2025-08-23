# Learn.UI.Errors.Tests.ps1
# Validates the Errors & Exceptions lesson (exists, heading, codepad.lang, quiz sanity).
### OSIRISBORN TEST HEADER (do not remove) ###
$repo     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jsonPath = Join-Path $repo 'MythicCore\www\data\learn\python.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }
### /OSIRISBORN TEST HEADER ###

Describe 'Errors & Exceptions lesson' {
  It 'exists and is parseable' {
    $raw = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json -Depth 100
    $obj | Should -Not -BeNullOrEmpty

    $lessons = @()
    if ($null -ne $obj.lessons) { $lessons += $obj.lessons }
    foreach ($track in @($obj.tracks)) {
      foreach ($sec in @($track.sections)) {
        if ($sec -and $sec.lessons) { $lessons += @($sec.lessons) }
      }
    }

    $lesson = $lessons | Where-Object { $_.id -eq 'python-errors-08' } | Select-Object -First 1
    $lesson | Should -Not -BeNullOrEmpty

    if ($lesson.html -and ($lesson.html -is [string])) {
      $lesson.html | Should -Match '<h2>\s*(Errors\s*&\s*Exceptions|Errors and Exceptions)\s*</h2>'
      $lesson.html | Should -Match '<div\s+class="codepad"[^>]*data-lang="python"'
    }

    if ($lesson.codepad) { "$($lesson.codepad.lang)" | Should -Be 'python' }
    ($lesson.quiz -and $lesson.quiz.items.Count -ge 5) | Should -BeTrue

    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($q in $lesson.quiz.items) {
      $qt = ("$($q.question)").Trim()
      if (-not $set.Add($qt)) { throw "Duplicate quiz question: $qt" }
    }
  }
}