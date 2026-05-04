# Project Handoff

Last Updated Local: 2026-05-04 07:54 PDT
Last Updated UTC: 2026-05-04T14:54:13Z
Stale After Hours: 24
Staleness: FRESH

## Project

- Path: `C:\Users\georg\Codex_Projects\codex-windows-bootstrap`
- Branch: `master`
- Remote: `origin` -> `https://github.com/neusse/codex-windows-bootstrap.git`
- Last known commit: `f373bb8 Sync global skill updates`

## Current State

- Added repo-level agent policy file:
  - `AGENTS.md`
- Added project-local skill package structure:
  - `.codex\skills\codex-windows-bootstrap\SKILL.md`
  - `.codex\skills\codex-windows-bootstrap\README.md`
  - `.codex\skills\codex-windows-bootstrap\scripts\bootstrap-codex-windows.ps1`
  - `.codex\skills\codex-windows-bootstrap\docs\assets\codex-windows-bootstrap-banner.svg`
- Updated root `README.md` with a centered hero/banner block and badges.
- Root skill files were moved out of the repository root into project-level `.codex` structure:
  - `SKILL.md` deleted from root
  - `scripts\bootstrap-codex-windows.ps1` deleted from root
- Added root docs asset path:
  - `docs\assets\codex-windows-bootstrap-banner.svg`

## Validation Status

- Passed: project-local skill tree exists under `.codex\skills\codex-windows-bootstrap`.
- Passed: `AGENTS.md` exists and now uses portable repo-relative skill path (`.codex/skills/codex-windows-bootstrap`).
- Not run this session: bootstrap script execution from new project-local skill path.
- Pending: review final repo layout intent (keep or remove duplicated root `docs/` banner asset).

## Resume Steps

1. Review changed/deleted/untracked files:
   ```powershell
   git status --short --branch
   ```
2. Inspect full diff and confirm desired final structure:
   ```powershell
   git diff
   ```
3. If keeping project-local skill packaging, stage and commit:
   ```powershell
   git add AGENTS.md README.md .codex docs HANDOFF.md
   git add -u
   git commit -m "Add project-level Codex skill packaging and startup agent policy"
   git push origin master
   ```
4. Optional validation run from project-local skill copy:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\.codex\skills\codex-windows-bootstrap\scripts\bootstrap-codex-windows.ps1
   ```

## Blockers

- None known.

## Open Questions

- Should root `README.md` continue to include the hero/banner section, or should it be reverted to a plain technical README?
- Keep both root `docs\assets` and `.codex\skills\...\docs\assets`, or consolidate to one location?

## Change Log

- 2026-05-04 07:54 PDT: Added `AGENTS.md`, created project-level `.codex\skills\codex-windows-bootstrap` package, and updated handoff for dropoff.