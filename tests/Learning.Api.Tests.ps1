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
Describe "Learning API" {
  BeforeAll {
    $base = "http://127.0.0.1:7780"

    function Get-200 {
      param([string]$Url, [int]$Tries = 25, [int]$DelayMs = 200)
      for ($i=1; $i -le $Tries; $i++) {
        try {
          $r = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 5
          if ($r.StatusCode -eq 200) { return $r }
        } catch { }
        Start-Sleep -Milliseconds $DelayMs
      }
      throw "Timeout waiting for 200: $Url"
    }

    try {
      $null = Get-200 ("$base/index.html?sw=off&bust=" + (Get-Date -Format yyyyMMddHHmmss))
    } catch {
      & .\tools\Reset-Server.ps1 | Out-Null
      Start-Sleep -Milliseconds 500
      $null = Get-200 ("$base/index.html?sw=off&bust=" + (Get-Date -Format yyyyMMddHHmmss))
    }

    Set-Variable -Name BaseUrl -Scope Script -Value $base
  }

  It "serves tracks.json and extensionless tracks" {
    (Get-200 "$script:BaseUrl/api/lessons/tracks.json").StatusCode | Should -Be 200
    (Get-200 "$script:BaseUrl/api/lessons/tracks").StatusCode      | Should -Be 200
  }

  $cases = @(
    @{ ep = "coding_python" }, @{ ep = "coding_js" }, @{ ep = "coding_cpp" },
    @{ ep = "cyber_foundations" }, @{ ep = "cyber_web" }, @{ ep = "cyber_network" }, @{ ep = "cyber_bounty" },
    @{ ep = "ctf_wargames" }, @{ ep = "ctf_crypto" }, @{ ep = "ctf_rev" }, @{ ep = "ctf_pwn" }
  )

  It "serves <ep>.json" -TestCases $cases {
    param([string]$ep)
    $r = Get-200 ("$script:BaseUrl/api/lessons/{0}.json" -f $ep)
    $r.StatusCode | Should -Be 200
    ($r.Content -match '"modules"') | Should -BeTrue
  }
}
