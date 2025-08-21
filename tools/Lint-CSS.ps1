param([string[]]\)

if (-not \ -or \.Count -eq 0) {
  \ = @('MythicCore\\www\\portal.standalone.html')
  \ += Get-ChildItem -Recurse -File -Include *.css | ForEach-Object { \.FullName }
}

\ = New-Object System.Collections.Generic.List[object]
function Add-Issue([string]\.\MythicCore\www\data\learn\typescript.json,[int]\,[string]\,[string]\){
  \.Add([pscustomobject]@{ File=\.\MythicCore\www\data\learn\typescript.json; Line=\; Message=\; Text=\ })
}

foreach (\.\MythicCore\www\js\langs.loader.js in \) {
  if (-not (Test-Path \.\MythicCore\www\js\langs.loader.js)) { continue }
  \ = Get-Content -Raw -Path \.\MythicCore\www\js\langs.loader.js -Encoding UTF8

  # Extract inline <style> CSS if HTML, else treat whole file as CSS
  \ = @()
  if (\.\MythicCore\www\js\langs.loader.js -match '\.html?$') {
    [regex]::Matches(\,'(?is)<style[^>]*>(.*?)</style>') | ForEach-Object { \ += \.Groups[1].Value }
  } else {
    \ = ,\
  }

  \ = 1
  foreach (\#lang-root{display:none;max-width:960px;margin:0 auto;padding:24px 20px 64px}
body.route-lang-hasdata #lang-root{display:block}
#lang-root h1{font-size:2rem;line-height:1.2;margin:8px 0 12px}
#lang-root h2{font-size:1.2rem;line-height:1.35;margin:18px 0 8px;opacity:.9}
#lang-root .lang-meta{opacity:.8;margin-bottom:8px}
#lang-root .module{border-top:1px solid var(--line,rgba(255,255,255,.1));padding-top:12px;margin-top:12px}
#lang-root .module.collapsed .lessons{display:none}
#lang-root .module h2{display:flex;align-items:center;gap:8px;cursor:pointer;user-select:none}
#lang-root .module h2::before{content:"▾";display:inline-block;transform:translateY(-1px)}
#lang-root .module.collapsed h2::before{content:"▸"}
#lang-root .lessons{list-style:none;padding:0;margin:6px 0 0}
#lang-root .lesson{display:flex;justify-content:space-between;gap:16px;padding:10px 12px;border:1px solid rgba(255,255,255,.08);border-radius:10px;margin:8px 0;cursor:pointer}
#lang-root .lesson:hover{background:rgba(255,255,255,.05)}
#lang-root .lesson:focus{outline:2px solid rgba(255,255,255,.25);outline-offset:2px}
#lang-root .lesson.active{background:rgba(255,255,255,.08);border-color:rgba(255,255,255,.25)}
#lang-root .lesson .title{font-weight:600}
#lang-root .lesson .mins{opacity:.75}
#lang-content{margin-top:18px;padding:16px 14px;border:1px solid rgba(255,255,255,.1);border-radius:12px}
#lang-content .empty{opacity:.7;font-style:italic}

/* lang-route-visibility: hide legacy siblings + restore purple theme */
body.route-lang-hasdata> *:not(nav):not(#lang-root):not(.footer),
body.route-lang-placeholder> *:not(nav):not(#lang-placeholder):not(#lang-root):not(.footer){display:none!important}

/* lang-route-theme */
body.route-lang-hasdata,body.route-lang-placeholder{
  background:
    radial-gradient(1200px 800px at -10% -10%, rgba(110,60,255,.12) 0%, rgba(110,60,255,0) 60%),
    radial-gradient(1000px 600px at 110% 10%, rgba(0,200,255,.10) 0%, rgba(0,200,255,0) 55%),
    linear-gradient(180deg, rgba(14,11,31,1) 0%, rgba(10,9,24,1) 100%);
  background-attachment:fixed,fixed,fixed;min-height:100vh
} in \) {
    \ = \#lang-root{display:none;max-width:960px;margin:0 auto;padding:24px 20px 64px}
body.route-lang-hasdata #lang-root{display:block}
#lang-root h1{font-size:2rem;line-height:1.2;margin:8px 0 12px}
#lang-root h2{font-size:1.2rem;line-height:1.35;margin:18px 0 8px;opacity:.9}
#lang-root .lang-meta{opacity:.8;margin-bottom:8px}
#lang-root .module{border-top:1px solid var(--line,rgba(255,255,255,.1));padding-top:12px;margin-top:12px}
#lang-root .module.collapsed .lessons{display:none}
#lang-root .module h2{display:flex;align-items:center;gap:8px;cursor:pointer;user-select:none}
#lang-root .module h2::before{content:"▾";display:inline-block;transform:translateY(-1px)}
#lang-root .module.collapsed h2::before{content:"▸"}
#lang-root .lessons{list-style:none;padding:0;margin:6px 0 0}
#lang-root .lesson{display:flex;justify-content:space-between;gap:16px;padding:10px 12px;border:1px solid rgba(255,255,255,.08);border-radius:10px;margin:8px 0;cursor:pointer}
#lang-root .lesson:hover{background:rgba(255,255,255,.05)}
#lang-root .lesson:focus{outline:2px solid rgba(255,255,255,.25);outline-offset:2px}
#lang-root .lesson.active{background:rgba(255,255,255,.08);border-color:rgba(255,255,255,.25)}
#lang-root .lesson .title{font-weight:600}
#lang-root .lesson .mins{opacity:.75}
#lang-content{margin-top:18px;padding:16px 14px;border:1px solid rgba(255,255,255,.1);border-radius:12px}
#lang-content .empty{opacity:.7;font-style:italic}

/* lang-route-visibility: hide legacy siblings + restore purple theme */
body.route-lang-hasdata> *:not(nav):not(#lang-root):not(.footer),
body.route-lang-placeholder> *:not(nav):not(#lang-placeholder):not(#lang-root):not(.footer){display:none!important}

/* lang-route-theme */
body.route-lang-hasdata,body.route-lang-placeholder{
  background:
    radial-gradient(1200px 800px at -10% -10%, rgba(110,60,255,.12) 0%, rgba(110,60,255,0) 60%),
    radial-gradient(1000px 600px at 110% 10%, rgba(0,200,255,.10) 0%, rgba(0,200,255,0) 55%),
    linear-gradient(180deg, rgba(14,11,31,1) 0%, rgba(10,9,24,1) 100%);
  background-attachment:fixed,fixed,fixed;min-height:100vh
} -split "?
"
    for (\=0; \ -lt \.Count; \++) {
      \ = \[\]
      if (\ -match ',\s*\{')      { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Malformed selector: trailing comma before '{'" \ }
      if (\ -match ',\s*,')       { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Malformed selector: double comma" \ }
      if (\ -match ':\s*\{')      { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Malformed selector: colon before '{'" \ }
      if (\ -match '\bbox-sizing\s*:\s*borderbox\b')  { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Invalid value: borderbox (use border-box)" \ }
      if (\ -match '\bbox-sizing\s*:\s*contentbox\b') { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Invalid value: contentbox (use content-box)" \ }
      if (\ -match '\bm-ui\b')     { Add-Issue \.\MythicCore\www\js\langs.loader.js (\+\) "Suspicious token 'm-ui' (did you mean system-ui?)" \ }
    }
  }
}

if (\.Count -gt 0) {
  Write-Host "CSS Lint found issues:" -ForegroundColor Yellow
  \ | Format-Table -AutoSize
  exit 1
} else {
  Write-Host "CSS Lint: no issues found." -ForegroundColor Green
}
