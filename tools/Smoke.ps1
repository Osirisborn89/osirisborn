param([int]$Port = 7780, [switch]$AddXP)
$fail = @()

function Step($name,[scriptblock]$b){
  try { & $b; "✅ $name" } catch { "❌ $name -> $($_.Exception.Message)"; $global:fail += $name }
}

Step "Health" { if ((iwr "http://localhost:$Port/" -UseBasicParsing).StatusCode -ne 200) { throw "not 200" } }

Step "Diag" {
  $d = (iwr "http://localhost:$Port/diag" -UseBasicParsing).Content | ConvertFrom-Json
  if (-not $d.exists.store) { throw "store.plasma missing" }
}

Step "XP JSON" {
  $raw = (iwr "http://localhost:$Port/xp.json?days=7" -UseBasicParsing).Content
  if ($raw -match '"error"\s*:\s*"') { throw "xp.json error: $raw" }
  $xp = $raw | ConvertFrom-Json
  if (-not $xp.summary -or -not $xp.series) { throw "shape mismatch" }
}

if ($AddXP) {
  Step "Add XP (+1)" {
    $r = irm "http://localhost:$Port/api/xp/add" -Method Post -ContentType "application/json" -Body '{"delta":1,"reason":"smoke"}'
    if (-not $r.ok) { throw "api/xp/add failed" }
  }
  Step "XP reflects change" {
    $xp = (iwr "http://localhost:$Port/xp.json?days=7" -UseBasicParsing).Content | ConvertFrom-Json
    if ($xp.summary.xp -lt 1) { throw "xp not increasing" }
  }
}

if ($fail.Count) { "-----`nFAILED: $($fail -join ', ')"; exit 1 } else { "-----`nALL GREEN" }
