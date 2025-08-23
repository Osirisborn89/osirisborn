# Post-merge smoke + issues (2025-08-23)

## Known pitfalls and fixes
- Intro enriched heading test expected **What you'll learn** but manifest had an escaped apostrophe. Fixed by normalizing the heading in \data/learn/python.json\.
- XP test failure came from missing/wrong \id\/\path\ for the first Python lesson. Ensured \id: python-intro-01\, non-empty \path\, and HTML includes \data-lesson-id\.
- Loader checks: tests look for tokens like \mountCodepad\ / \unJavaScript\. We exposed \mountCodepad(target, opts)\ and kept codepad runner hooks (\osbInitCodepadsSafe\, \osbRunPython\).
- Dev unlock for QA: use \?dev=unlock\ or \localStorage.__osb_unlock_all="1"\; clear with \localStorage.removeItem("__osb_unlock_all")\.
- API tests can hang if server isn’t up. Use the mock job on \http://127.0.0.1:7780\ during local test runs.
- Pester v5 output flags: use \-Output Detailed\ (not \-Output Summary\).

## Backup
C:\Users\day_8\dev\osirisborn\backups\stable-20250823-144442.zip