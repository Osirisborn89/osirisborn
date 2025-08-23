### OSIRISBORN TEST HEADER (PS7 ABSOLUTE) — DO NOT REMOVE ###
# PowerShell 7-safe header: uses env override with absolute fallback.
\\$repo\\ \\ \\ \\ \\ =\\ \\$env:OSIR_REPO;\\ if\\ \\(\\[string]::IsNullOrWhiteSpace\\(\\$repo\\)\\)\\ \\{\\ \\$repo\\ =\\ 'C:\\\\Users\\\\day_8\\\\dev\\\\osirisborn'\\ }
if ([string]::IsNullOrWhiteSpace($repo)) { $repo = 'C:\Users\day_8\dev\osirisborn' }
\\$jsonPath\\ =\\ Join-Path\\ \\$repo\\ 'MythicCore\\\\www\\\\data\\\\learn\\\\python\\.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { throw "Not found: $jsonPath" }
### /OSIRISBORN TEST HEADER ###

# osbCompatGlobalsV3
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot "MythicCore\www\js\langs.loader.js" }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot "MythicCore\www\langs.lessons.css" }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot "MythicCore\www\data\learn\python.json" }
  $global:loader = $LoaderPath
  $global:css    = $CssPath
  $global:data   = $PythonJsonPath
} catch {}
# osbCompatGlobalsV2
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  $global:loader = $LoaderPath
  $global:css    = $CssPath
  $global:data   = $PythonJsonPath
} catch {}
# osbTestPathGuardV2 (safe after Param)
try {
  if (-not (Test-Path variable:\RepoRoot) -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
  }
} catch {}


# osbTestCompatVarsV1
try {
  if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
  if (-not $LoaderPath) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  if (-not $CssPath)    { $CssPath    = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  if (-not $PythonJsonPath) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  if (-not $loader) { $script:loader = $LoaderPath }
  if (-not $css)    { $script:css    = $CssPath }
  if (-not $data)   { $script:data   = $PythonJsonPath }
} catch {}
try {
  if (-not $LoaderPath -or -not (Test-Path $LoaderPath)) {
    $LoaderPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\js\langs.loader.js"
    if (-not (Test-Path $LoaderPath)) { $LoaderPath = Join-Path $RepoRoot 'MythicCore\www\js\langs.loader.js' }
  }
  if (-not $CssPath -or -not (Test-Path $CssPath)) {
    $CssPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\langs.lessons.css"
    if (-not (Test-Path $CssPath)) { $CssPath = Join-Path $RepoRoot 'MythicCore\www\langs.lessons.css' }
  }
  if (-not $PythonJsonPath -or -not (Test-Path $PythonJsonPath)) {
    $PythonJsonPath = "C:\Users\day_8\dev\osirisborn\MythicCore\www\data\learn\python.json"
    if (-not (Test-Path $PythonJsonPath)) { $PythonJsonPath = Join-Path $RepoRoot 'MythicCore\www\data\learn\python.json' }
  }
} catch {}
[CmdletBinding()]
param([ValidateSet("Local","CI")]$Mode="Local")

$ErrorActionPreference = "Stop"
function Fail($m){ Write-Host "❌ $m"; exit 1 }
function Pass($m){ Write-Host "✅ $m" }

# paths
$root = Split-Path -Parent $PSScriptRoot
$www  = Join-Path $root "MythicCore\www"

if (!(Test-Path $www)) { Fail "Missing $www" }

# standalone portal must exist and be the polished purple we expect
$standalone = Join-Path $www "portal.standalone.html"
if (!(Test-Path $standalone)) { Fail "Missing portal.standalone.html (our canonical UI)" }
$html = Get-Content $standalone -Raw
if ($html.Length -lt 3000) { Fail "portal.standalone.html is suspiciously short (len=$($html.Length))" }
if ($html -notmatch '<template id="tpl-home">') { Fail "tpl-home missing in portal.standalone.html" }
if ($html -notmatch 'Black Pyramid — Portal') { Fail "title/brand missing in portal.standalone.html" }
if ($html -notmatch 'Build:\s*portal-standalone') { Fail "Build marker missing in portal.standalone.html" }
if ($html -notmatch 'BP PORTAL \(inline, immutable\)') { Fail "inline CSS marker missing in portal.standalone.html" }
if ($html -match 'runner\.css|xp-panel\.js|sw-register\.js') { Fail "Legacy references present in portal.standalone.html (runner/xp/sw)" }
Pass "Standalone portal looks structurally correct."

# SW unregister page should exist (so we can always nuke SW)
$unreg = Join-Path $www "_hotfix_sw_unregister.html"
if (!(Test-Path $unreg)) { Fail "Missing _hotfix_sw_unregister.html (SW kill page)" }
Pass "SW unregister page present."

# Must NOT have raw runner.css in webroot
$runner = Join-Path $www "runner.css"
if (Test-Path $runner) { Fail "runner.css exists in webroot (rename to runner.css.disabled or move under legacy/)" }
Pass "No runner.css in webroot."

# index.html must not point at old UI
$idxPath = Join-Path $www "index.html"
if (Test-Path $idxPath) {
  $idx = Get-Content $idxPath -Raw
  if ($idx -match 'runner\.css|xp-panel\.js') { Fail "index.html references legacy UI (runner/xp)" }
  if ($idx -match 'Osirisborn — Control Panel') { Fail "index.html contains old dashboard strings" }
  Pass "index.html free of legacy references."
}

# Optional HTTP smoke (only when Mode=Local and server is up)
if ($Mode -eq "Local") {
  try {
    if ((Test-NetConnection 127.0.0.1 -Port 7780).TcpTestSucceeded) {
      $ts = Get-Date -Format yyyyMMddHHmmss
      $resp = Invoke-WebRequest "http://127.0.0.1:7780/portal.standalone.html?bust=$ts" -UseBasicParsing -TimeoutSec 5
      if ($resp.StatusCode -ne 200) { Fail "HTTP $($resp.StatusCode) for portal.standalone.html" }
      if ($resp.Content -notmatch 'Build:\s*portal-standalone') { Fail "HTTP content missing Build marker" }
      Pass "HTTP smoke OK."
    } else {
      Write-Host "ℹ️ Server not running; HTTP smoke skipped."
    }
  } catch {
    Fail "HTTP smoke failed: $($_.Exception.Message)"
  }
}

Write-Host "🎉 Portal UI guard passed."
exit 0
