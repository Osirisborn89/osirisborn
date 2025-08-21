param([string[]]$Paths)

if (-not $Paths -or $Paths.Count -eq 0) {
  $Paths = @('MythicCore\www\portal.standalone.html')
  $Paths += Get-ChildItem -Recurse -File -Include *.css | ForEach-Object { $_.FullName }
}

$bad = New-Object System.Collections.Generic.List[object]
function Add-Issue([string]$File,[int]$Line,[string]$Msg,[string]$Text){
  $bad.Add([pscustomobject]@{ File=$File; Line=$Line; Message=$Msg; Text=$Text })
}

foreach ($p in $Paths) {
  if (-not (Test-Path $p)) { continue }
  $text = Get-Content -Raw -Path $p -Encoding UTF8

  # Extract inline <style> CSS if HTML, else treat whole file as CSS
  $cssBlocks = @()
  if ($p -match '\.html?$') {
    [regex]::Matches($text,'(?is)<style[^>]*>(.*?)</style>') | ForEach-Object { $cssBlocks += $_.Groups[1].Value }
  } else {
    $cssBlocks = ,$text
  }

  $ln = 1
  foreach ($css in $cssBlocks) {
    $lines = $css -split "?
"
    for ($i=0; $i -lt $lines.Count; $i++) {
      $L = $lines[$i]
      if ($L -match ',\s*\{')      { Add-Issue $p ($ln+$i) "Malformed selector: trailing comma before '{'" $L }
      if ($L -match ',\s*,')       { Add-Issue $p ($ln+$i) "Malformed selector: double comma" $L }
      if ($L -match ':\s*\{')      { Add-Issue $p ($ln+$i) "Malformed selector: colon before '{'" $L }
      if ($L -match '\bbox-sizing\s*:\s*borderbox\b')  { Add-Issue $p ($ln+$i) "Invalid value: borderbox (use border-box)" $L }
      if ($L -match '\bbox-sizing\s*:\s*contentbox\b') { Add-Issue $p ($ln+$i) "Invalid value: contentbox (use content-box)" $L }
      if ($L -match '\bm-ui\b')     { Add-Issue $p ($ln+$i) "Suspicious token 'm-ui' (did you mean system-ui?)" $L }
    }
  }
}

if ($bad.Count -gt 0) {
  Write-Host "CSS Lint found issues:" -ForegroundColor Yellow
  $bad | Format-Table -AutoSize
  exit 1
} else {
  Write-Host "CSS Lint: no issues found." -ForegroundColor Green
}
