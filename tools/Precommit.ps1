$ErrorActionPreference = "SilentlyContinue"
$Srv = ".\MythicCore\scripts\Osirisborn.Server.ps1"
# Parse check
$tokens=$null;$errs=$null
$null=[System.Management.Automation.Language.Parser]::ParseInput((Get-Content $Srv -Raw),[ref]$tokens,[ref]$errs)
if ($errs -and $errs.Count) {
  "❌ Parser errors:"; $errs | ForEach-Object { $_.Message + " @ line " + $_.Extent.StartLineNumber }; exit 2
}
# Route sanity (xp.json uses wrapper)
$text = Get-Content $Srv -Raw
if ($text -notmatch '__XP_Summary_Run' -or $text -notmatch 'Write-Json\s+\$res\s+\(__XP_Summary_Run') {
  "❌ xp.json is not wired to __XP_Summary_Run"; exit 3
}
"✅ Precommit checks passed."
# --- Guard against old Pester matcher ---
if (Select-String -Path .\tests\*.ps1 -Pattern 'BeGreaterThanOrEqual' -Quiet) {
  "❌ Found invalid Pester matcher 'BeGreaterThanOrEqual'"; exit 7
}

# Ensure Pester v5+ present
if (-not (Get-Module Pester -ListAvailable | Where-Object { $_.Version -ge [Version]'5.5' })) {
  Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.5
}

# Run tests in CI mode (fast, non-verbose)
$test = Invoke-Pester -Path .\tests -CI -PassThru
if ($test.FailedCount -gt 0) { "❌ Tests failed"; exit 8 }
"✅ Precommit tests passed."
less-003-server-cleanup
# OSB:GUARD-INDEX-DUPES
try {
  $index = Join-Path $PSScriptRoot "..\MythicCore\www\index.html"
  if (Test-Path $index) {
    $html = Get-Content -Raw $index
    $violations = @()

    function CountMatches([string]$text, [string]$pattern) {
      return ([regex]::Matches($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
    }

    $countEarly = CountMatches $html '<!--\s*OSB:DEV-TOGGLE-EARLY\s*-->'
    if ($countEarly -ne 1) { $violations += "DEV-TOGGLE-EARLY blocks: $countEarly (expected 1)" }

    $countOldToggle = CountMatches $html '<!--\s*OSB:DEV-TOGGLE-START\s*-->'
    if ($countOldToggle -gt 0) { $violations += "Found legacy DEV-TOGGLE block(s): $countOldToggle (should be 0)" }

    $countDevStyle = CountMatches $html '<!--\s*OSB:DEV-STYLE-START\s*-->'
    if ($countDevStyle -gt 0) { $violations += "Found legacy DEV-STYLE block(s): $countDevStyle (should be 0)" }

    $countLessonsCss = CountMatches $html 'href=["'']/lessons\.css["'']'
    if ($countLessonsCss -ne 1) { $violations += "lessons.css links: $countLessonsCss (expected 1)" }

    $countLessonsJs = CountMatches $html 'import\s+["'']/lessons\.js["'']'
    if ($countLessonsJs -ne 1) { $violations += "lessons.js imports: $countLessonsJs (expected 1)" }

    $countBackupJs = CountMatches $html 'import\s+["'']/js/backup\.js["'']'
    if ($countBackupJs -ne 1) { $violations += "js/backup.js imports: $countBackupJs (expected 1)" }

    if ($violations.Count -gt 0) {
      Write-Error ("Index.html guards failed:`n - " + ($violations -join "`n - "))
      exit 1
    } else {
      Write-Host "Index.html guards passed."
    }
  }
} catch {
  Write-Warning "Index guard check threw: $($_.Exception.Message)"
}
# END OSB:GUARD-INDEX-DUPES
main
