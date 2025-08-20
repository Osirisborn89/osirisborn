# Phase 3: make the dashboard live-update by polling mirror.json every 2s
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:USERPROFILE "Osirisborn\MythicCore"
$www  = Join-Path $root "www"
$index = Join-Path $www "index.html"

if (-not (Test-Path $index)) { throw "Dashboard not found: $index" }

# Add/update the polling script block
$content = Get-Content -Raw -Path $index

$patch = @"
<script>
(function(){
  const rankEl = document.getElementById("rank");
  const xpText = document.getElementById("xptext");
  const fill   = document.getElementById("xpfill");

  async function load() {
    try {
      const r = await fetch("./mirror.json?ts="+Date.now());
      if (!r.ok) return;
      const d = await r.json();
      const rank = d?.user?.rank ?? "Initiate";
      const xp   = d?.user?.xp ?? 0;
      const pct  = d?.user?.progressPct ?? 0;
      rankEl.textContent = "Rank: " + rank;
      xpText.textContent = xp + " XP";
      fill.style.width = pct + "%";
    } catch(e) { /* ignore */ }
  }
  load();
  setInterval(load, 2000);
})();
</script>
"@

if ($content -notmatch "setInterval\(load, 2000\)") {
  $content = $content -replace "</body>","$patch`r`n</body>"
  Set-Content -Path $index -Value $content -Encoding UTF8
  Write-Host "Dashboard upgraded for live updates." -ForegroundColor Green
} else {
  Write-Host "Dashboard already has live updates. Skipped." -ForegroundColor Yellow
}
