# ADR 0001 — Adopt Pester ≥ 5.5 and dual-Windows CI

- **Status**: accepted
- **Date**: 2025-08-16

## Context
We need reliable tests across both PowerShell 7 and Windows PowerShell 5. Differences (e.g., alias collisions like `sc`, web cmdlet parameter sets, and JSON handling) caused flaky behavior. We also need CI on Windows to match runtime characteristics.

## Decision
- Standardize on **Pester ≥ 5.5** with host-agnostic helpers and fixed matcher names.
- Normalize JSON responses (array-wrapped vs bare objects) inside tests.
- CI workflow `.github/workflows/ci.yml` runs two jobs:
  - **CI / Pester on pwsh** (PowerShell 7)
  - **CI / Pester on powershell** (Windows PowerShell 5)
- Remove alias `sc` and bind health checks to `127.0.0.1:7780`.
- Keep a separate non-blocking **smoke** workflow that runs after CI success and uploads logs on failure.

## Consequences
- Slightly longer CI time (two jobs) but materially more confidence.
- Fewer environment-specific surprises; easier local reproduction.
- Future: optionally add a Linux job if/when scripts become cross-platform.
