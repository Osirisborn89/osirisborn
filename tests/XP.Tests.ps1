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
Describe "Osirisborn XP API" {
  BeforeAll {
    $Port = 7780
    $script:BaseUri = [System.UriBuilder]::new('http','127.0.0.1',$Port,'/').Uri

    function Invoke-OsbWeb {
      param([string]$Path,[int]$TimeoutSec=5)
      $u = [Uri]::new($script:BaseUri, $Path)
      if ($PSVersionTable.PSVersion.Major -ge 6) {
        Invoke-WebRequest -Uri $u -TimeoutSec $TimeoutSec
      } else {
        Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec $TimeoutSec
      }
    }
    function Convert-OsbJson($raw) {
      $o = $raw | ConvertFrom-Json
      if ($o -is [System.Array]) { $o = $o[-1] }
      $o
    }

    # Ensure server is up on THIS port
    $healthy = $false
    try { if ((Invoke-OsbWeb '').StatusCode -eq 200) { $healthy = $true } } catch {}
    if (-not $healthy) {
      pwsh -NoProfile -File .\tools\Stop-Server.ps1 -Port $Port | Out-Null
      pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\Run-Server.ps1 -Port $Port | Out-Null
    }
  }

  It "base uri is well formed and uses port 7780" {
    $script:BaseUri.IsAbsoluteUri | Should -BeTrue
    $script:BaseUri.Host          | Should -Be '127.0.0.1'
    $script:BaseUri.Port          | Should -Be 7780
  }

  It "health is 200" {
    (Invoke-OsbWeb '').StatusCode | Should -Be 200
  }

  It "diag endpoint ok; ensure store initialized" {
    $diagRaw = (Invoke-OsbWeb 'diag').Content
    Write-Host "diag raw >>>`n$diagRaw`n<<< diag raw end"
    $d = Convert-OsbJson $diagRaw

    # Minimal shape checks (robust on clean runners)
    ($d.PSObject.Properties.Name -contains 'exists') | Should -BeTrue
    ($d.PSObject.Properties.Name -contains 'mode')   | Should -BeTrue

    if (-not $d.exists.store) {
      # Create the store by adding 1 XP, then re-check
      $addUri = [Uri]::new($script:BaseUri, 'api/xp/add')
      $body   = @{ delta=1; reason='init-store' } | ConvertTo-Json -Compress
      Invoke-RestMethod -Uri $addUri -Method Post -ContentType 'application/json' -Body $body | Out-Null
      Start-Sleep -Milliseconds 150
      $d2 = Convert-OsbJson (Invoke-OsbWeb 'diag').Content
      $d2.exists.store | Should -BeTrue
    }
  }

  It "xp.json returns expected shape" {
    $raw = (Invoke-OsbWeb 'xp.json?days=7').Content
    $raw | Should -Not -Match '"error"\s*:'
    $xp = Convert-OsbJson $raw
    $xp.series  | Should -Not -BeNullOrEmpty
    $xp.summary | Should -Not -BeNullOrEmpty
  }

  It "xp.debug returns ok:true" {
    $raw = (Invoke-OsbWeb 'xp.debug?days=7').Content
    $dbg = $raw | ConvertFrom-Json
    if ($dbg -is [System.Array]) { $dbg = $dbg[-1] }
    $dbg.ok | Should -BeTrue
    $res = $dbg.result
    if ($res -is [System.Array]) { $res = $res[-1] }
    [int]$res.summary.xp | Should -BeGreaterOrEqual 0
  }

  It "xpToday increments after adding XP" {
    $pre = Convert-OsbJson (Invoke-OsbWeb 'xp.json?days=7').Content
    $preToday = [int]$pre.summary.xpToday

    $delta = 3
    $addUri = [Uri]::new($script:BaseUri, 'api/xp/add')
    $body   = @{ delta=$delta; reason='pester' } | ConvertTo-Json -Compress
    Invoke-RestMethod -Uri $addUri -Method Post -ContentType 'application/json' -Body $body | Out-Null
    Start-Sleep -Milliseconds 150

    $post = Convert-OsbJson (Invoke-OsbWeb 'xp.json?days=7').Content
    ([int]$post.summary.xpToday) | Should -BeGreaterOrEqual ($preToday + $delta)
  }
}
