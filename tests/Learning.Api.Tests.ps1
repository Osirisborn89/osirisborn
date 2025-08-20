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
