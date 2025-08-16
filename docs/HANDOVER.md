# Black Pyramid — Handover

## Repo
Repo: https://github.com/Osirisborn89/osirisborn

## Current State (Windows dev)
- Server: PowerShell HTTP server at `MythicCore/scripts/Osirisborn.Server.ps1`
- Port: 7780 (auto-opens browser on start)
- Static UI: `MythicCore/www/index.html` + `client.js`
- Data store: `MythicCore/data/store.plasma` (JSON content)
- URL ACL configured for your Windows user

## HTTP Endpoints
- GET /                → index.html
- GET /client.js       → client script
- GET /diag            → diagnostics (module visibility)
- GET /xp.json?days=N  → daily XP series + summary
- POST /api/xp/add           { delta, reason } → adds XP
- GET  /api/missions         → list missions
- POST /api/mission/add      { id, title, xp }
- POST /api/mission/complete { id } → awards XP

## What’s Working
- XP ring & progress in UI
- Missions list/add/complete → XP increments
- Quick-add XP buttons in UI

## Next Up (in order)
1) Lessons skeleton (server-first):
   - Endpoints: GET /api/tracks, GET /api/lessons, POST /api/lesson/add, POST /api/lesson/complete (awards XP)
   - Seed a few lessons (Python 101, Networking basics)
   - Minimal “Lessons” table in UI
2) Dashboard shell & mode toggles (tabs: Dashboard / Missions / Lessons / Lounge)
3) Flashcards core (local decks + /api/flashcards/*)

## Branching
- main = stable
- Feature flow: `feature/lessons-skeleton` → PR → merge

## Run
- Start: `pwsh -NoProfile -ExecutionPolicy Bypass -File "$HOME\Osirisborn\MythicCore\scripts\Osirisborn.Server.ps1"`
- Visit: http://localhost:7780/

## Decisions
- Proprietary project (LICENSE removed; EULA/COPYRIGHT present)
- Theme: neon cyberpunk w/ Egyptian vibes (Anubis voice ≈ Ian McKellen/Gandalf)
- LESS-001: Lessons entrypoint
  - Dashboard tile linking to /lessons
  - SPA routing with history/pushState
  - Stub Curriculum Hub view with Python Mastery (0%) track card
