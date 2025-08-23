# Recovery Notes — 2025-08-23 14:17:29

## Current good state
- Web root: $(Resolve-Path MythicCore\www)
- Dev server we use: http://127.0.0.1:5521/ (served from web root above)
- Learn router base: #/learn/...
- Mock API (for tests): http://127.0.0.1:7780

## Issues we hit & fixes that worked
1) **Intro (enriched) heading mismatch**
   - Symptom: test expected "What you'll learn" but JSON/HTML had What you\'ll learn.
   - Fix: literal replace to **What you'll learn** in data/learn/python.json.

2) **Codepad hooks expectation**
   - Symptom: tests looked for mountCodepad / runner in loader.
   - Fix: exported window.mountCodepad(...) and ensured codepadHTML + osbInitCodepadsSafe(...) exist.

3) **XP test failing with Path null**
   - Symptom: Cannot bind argument to parameter 'Path' because it is null.
   - Root cause: a lesson had missing .path, or HTML missing data-lesson-id.
   - Fix: normalized python.json lessons to have id + path; created/updated HTML to include data-lesson-id.

4) **Locked lessons in UI**
   - Symptom: couldn't click lesson 6/7; ?dev=unlock was dropped by router.
   - Fix: set localStorage.__osb_unlock_all = "1" on same origin via dev-unlock.html, then navigate to the lesson.
   - Helper file: $(Join-Path MythicCore\www 'dev-unlock.html')

5) **Port/host confusion**
   - We standardized on **127.0.0.1:5521** for the site, **127.0.0.1:7780** for the mock API.
   - Avoid random ports like 8080/9000 unless the tests explicitly require them.

## Quick ops
- **Run tests:** Invoke-Pester .\tests -Output Detailed
- **Serve site (Python):** python -m http.server 5521 -d "MythicCore\www"
- **Unlock (if router drops query):** open /dev-unlock.html once

-- end --