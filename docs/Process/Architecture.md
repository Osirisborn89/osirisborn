# Architecture (High Level)

- **App Shell:** Windows-first (local server + web UI), Tauri desktop later, PWA optional.
- **Modules:** UI (Dashboard, Lessons, Vault, Lounge), Services (XP/Missions, Storage, Encryption),
  Engines (Curriculum, Gamification, Flashcards), Cyber Range (sim), Anubis (assistant).
- **Data:** Local-first (JSON/SQLite later), encrypted vault option, .bpkg signed content packs.
- **Extensibility:** Module loader, rank-gated unlocks, expansion packs.
