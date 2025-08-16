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
