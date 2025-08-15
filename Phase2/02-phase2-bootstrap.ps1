# Requires PowerShell 7+
$ErrorActionPreference = 'Stop'

# --- Paths ---
$root = Join-Path $env:USERPROFILE "Osirisborn\MythicCore"
$scripts = Join-Path $root "scripts"
$modules = Join-Path $scripts "modules"
$dataDir = Join-Path $root "data"
$backupDir = Join-Path $root "backups"
$www = Join-Path $root "www"

# --- Create structure ---
$paths = @($root,$scripts,$modules,$dataDir,$backupDir,$www)
$paths | ForEach-Object { if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null } }

# --- .gitignore (optional if you use git) ---
$gitignore = @"
# Sensitive / runtime
data/
backups/
.secrets/
.env
*.log
"@
$giPath = Join-Path $root ".gitignore"
if (-not (Test-Path $giPath)) { $gitignore | Out-File -FilePath $giPath -Encoding UTF8 }

# --- Secrets folder ---
$secrets = Join-Path $root ".secrets"
if (-not (Test-Path $secrets)) { New-Item -ItemType Directory -Force -Path $secrets | Out-Null }

# --- Generate 256-bit key & salt if missing ---
$keyPath = Join-Path $secrets "store.key"     # raw 32 bytes (base64)
$saltPath = Join-Path $secrets "store.salt"   # 16 bytes (base64)
if (-not (Test-Path $keyPath)) {
    $key = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($key)
    [Convert]::ToBase64String($key) | Out-File $keyPath -Encoding ASCII
}
if (-not (Test-Path $saltPath)) {
    $salt = New-Object byte[] 16; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    [Convert]::ToBase64String($salt) | Out-File $saltPath -Encoding ASCII
}

# --- Seed store (encrypted JSON) placeholder; real content created by module on first save ---
$seedPath = Join-Path $dataDir "store.plasma"  # encrypted blob file
if (-not (Test-Path $seedPath)) { "{}" | Out-File $seedPath -Encoding UTF8 }

# --- Drop module & CLI files from Phase2 folder if present ---
try {
  Copy-Item -Path (Join-Path $PSScriptRoot 'Osirisborn.Store.psm1') -Destination (Join-Path $modules "Osirisborn.Store.psm1") -Force
  Copy-Item -Path (Join-Path $PSScriptRoot 'Osirisborn.XP.psm1')    -Destination (Join-Path $modules "Osirisborn.XP.psm1")    -Force
  Copy-Item -Path (Join-Path $PSScriptRoot 'osirisborn.ps1')        -Destination (Join-Path $scripts "osirisborn.ps1")        -Force
} catch { }

if (-not (Test-Path (Join-Path $modules "Osirisborn.Store.psm1"))) { Write-Host ">> Put Osirisborn.Store.psm1 next to this bootstrap and re-run." -ForegroundColor Yellow }
if (-not (Test-Path (Join-Path $modules "Osirisborn.XP.psm1")))    { Write-Host ">> Put Osirisborn.XP.psm1 next to this bootstrap and re-run." -ForegroundColor Yellow }
if (-not (Test-Path (Join-Path $scripts "osirisborn.ps1")))        { Write-Host ">> Put osirisborn.ps1 next to this bootstrap and re-run." -ForegroundColor Yellow }

# --- Minimal dashboard shell placeholder (served locally later) ---
$indexHtml = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Osirisborn Dashboard — Mythic Core</title>
<style>
  body { margin:0; font-family: ui-sans-serif, system-ui; background:#0a0014; color:#eae6ff; }
  .topbar { display:flex; align-items:center; gap:12px; padding:12px 16px; background:linear-gradient(90deg,#170033,#23004d); position:sticky; top:0; }
  .xpbar { flex:1; height:10px; background:#1a1030; border-radius:999px; overflow:hidden; box-shadow:0 0 12px rgba(162,103,255,.35) inset; }
  .xpfill { height:100%; width:0%; background:linear-gradient(90deg,#A267FF,#B388FF); box-shadow:0 0 16px #A267FF; }
  .grid { display:grid; grid-template-columns:240px 1fr; gap:0; min-height:calc(100dvh - 56px); }
  .nav { background:#0f0720; border-right:1px solid #1f0d3a; padding:16px; }
  .nav a { display:block; padding:10px 12px; margin-bottom:8px; text-decoration:none; color:#d9ccff; background:#140a2b; border-radius:12px; }
  .main { padding:24px; }
</style>
</head>
<body>
  <div class="topbar">
    <div id="rank">Rank: Initiate</div>
    <div class="xpbar"><div class="xpfill" id="xpfill"></div></div>
    <div id="xptext">0 XP</div>
  </div>
  <div class="grid">
    <nav class="nav">
      <a href="#">XP Tracker</a>
      <a href="#">Missions</a>
      <a href="#">Tools Vault</a>
      <a href="#">Journal</a>
      <a href="#">Downtime Lounge</a>
    </nav>
    <main class="main">
      <h1>Osirisborn Black Pyramid — Mythic Core</h1>
      <p>Phase 2: Persistent Store + XP backbone wired. PowerShell controls the data; this shell reflects it.</p>
      <p>Use <code>.\scripts\osirisborn.ps1</code> to add XP and this bar will update next refresh (Phase 3 wires live updates).</p>
    </main>
  </div>
  <script>
    // Placeholder: reads a lightweight mirror file if present
    fetch("./mirror.json").then(r=>r.json()).then(d=>{
      document.getElementById("rank").textContent = "Rank: " + (d?.user?.rank ?? "Initiate");
      document.getElementById("xptext").textContent = (d?.user?.xp ?? 0) + " XP";
      const pct = d?.user?.progressPct ?? 0;
      document.getElementById("xpfill").style.width = pct + "%";
    }).catch(()=>{});
  </script>
</body>
</html>
"@
$indexPath = Join-Path $www "index.html"
if (-not (Test-Path $indexPath)) { $indexHtml | Out-File $indexPath -Encoding UTF8 }

Write-Host ">> Phase 2 bootstrap folders ready at $root" -ForegroundColor Cyan
