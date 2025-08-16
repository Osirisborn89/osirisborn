![CI](https://github.com/Osirisborn89/osirisborn/actions/workflows/ci.yml/badge.svg)
# Osirisborn (Proprietary)

**Copyright © 2025 Osirisborn89. All rights reserved.**  
This is proprietary software. **No redistribution, copying, sublicensing, or public publishing** is permitted without written permission from the owner.

> By using this software you agree to the terms in **EULA.txt**.

---

## What’s in here
- `MythicCore/scripts/` PowerShell CLI, GUI, and mini server
- `MythicCore/www/` local dashboard (served by the mini server)
- `scripts/modules/` data store, XP, missions modules

**Not versioned:** runtime data in `MythicCore/data/` and the live mirror file `MythicCore/www/mirror.json` (see `.gitignore`).

---

## Quick start (local)
```powershell
# CLI
$cli = Join-Path $env:USERPROFILE 'Osirisborn\MythicCore\scripts\osirisborn.ps1'
& $cli xp 1 "hello world"

# Dashboard server
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Osirisborn\MythicCore\scripts\Osirisborn.Server.ps1"
# then open http://localhost:7777/

