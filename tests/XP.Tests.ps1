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

  It "diag shows store exists" {
    $d = Convert-OsbJson (Invoke-OsbWeb 'diag').Content
    $d.exists.store | Should -BeTrue
  }

  It "xp.json returns expected shape" {
    $raw = (Invoke-OsbWeb 'xp.json?days=7').Content
    $raw | Should -Not -Match '"error"\s*:'
    $xp = Convert-OsbJson $raw
    $xp.series  | Should -Not -BeNullOrEmpty
    $xp.summary | Should -Not -BeNullOrEmpty
  }

  It "xp.debug returns ok:true" {
    # avoid nested call → assign then parse
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
    # Call IRM directly with the simplest param set
    $resp = Invoke-RestMethod -Uri $addUri -Method Post -ContentType 'application/json' -Body $body
    Start-Sleep -Milliseconds 150

    $post = Convert-OsbJson (Invoke-OsbWeb 'xp.json?days=7').Content
    ([int]$post.summary.xpToday) | Should -BeGreaterOrEqual ($preToday + $delta)
  }
}

