---
name: codex-windows-bootstrap
description: Bootstrap and verify a Windows Codex development environment for new machines. Use when Codex needs to check what is installed, identify missing or broken tooling, install core developer tools (Node.js, GitHub CLI, ripgrep, uv) with winget, optionally install extra quality-of-life and PDF tools, ensure Python virtualenv support and pylint are installed, configure global Git identity, verify GitHub CLI auth, and produce a clear ready/not-ready report.
---

# Codex Windows Bootstrap

## Workflow

1. Run a local readiness audit script:
   `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1`
2. For one-shot setup on a new machine, run v2 auto mode:
   `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall`
2. Report findings with three sections:
   `Installed`, `Missing`, `Misconfigured`.
3. If core tools are missing, install with `winget`:
   `OpenJS.NodeJS.LTS`, `GitHub.cli`, `BurntSushi.ripgrep.MSVC`, `astral-sh.uv`.
4. Ensure Python tooling support is available:
   `python -m virtualenv --version` and `python -m pylint --version`, and if either is missing run `python -m pip install --user <package>`.
5. Ensure the Python user Scripts directory is available on `PATH` using a `%USERPROFILE%`-based entry.
6. Ask whether optional tools should also be installed:
   `jqlang.jq`, `sharkdp.fd`, `sharkdp.bat`, `GitHub.GitLFS`, `Docker.DockerDesktop`.
7. When PDF creation, extraction, or rendering is expected, install PDF tools with:
   `powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall -InstallPdfTools`.
8. If Git identity is missing, ask for:
   `user.name` and `user.email`, then set global config.
9. If GitHub auth is missing, run:
   `gh auth login --hostname github.com --git-protocol https --web`.
10. Re-run the audit script and confirm readiness.

## Required Checks

Check these commands:
- `git --version`
- `python --version`
- `node --version`
- `npm --version`
- `gh --version`
- `rg --version`
- `uv --version`
- `python -m virtualenv --version`
- `python -m pylint --version`
- Python imports for optional PDF readiness: `reportlab`, `pypdf`, `pdfplumber`, `pdf2image`, `PIL`
- PDF system commands for optional PDF readiness: `pdftoppm -v`, `pdfinfo -v`, `qpdf --version`
- `gh auth status`
- `git config --global --get user.name`
- `git config --global --get user.email`

Treat these as pass/fail gates:
- `node`, `npm`, `gh`, `rg`, `uv` must execute successfully.
- `python -m virtualenv --version` must execute successfully.
- `python -m pylint --version` must execute successfully.
- `gh auth status` must report an active account.
- global Git name/email must be set.
- PDF checks are reported under `PdfMissing`; they are only pass/fail gates when the user explicitly requests PDF tooling or runs with `-InstallPdfTools`.

## Installation Commands

Use these commands when tools are missing:

```powershell
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
winget install --id BurntSushi.ripgrep.MSVC -e --accept-package-agreements --accept-source-agreements
winget install --id astral-sh.uv -e --accept-package-agreements --accept-source-agreements
python -m pip install --user virtualenv
python -m pip install --user pylint
```

If installer needs elevation or user confirmation, request it and continue after approval.

The bundled script can do this automatically with `-AutoInstall`.

Optional tool install modes:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall -PromptOptionalTools
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall -InstallOptionalTools
```

PDF tool install modes:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall -PromptPdfTools
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -AutoInstall -InstallPdfTools
```

PDF tooling installed by `-InstallPdfTools`:

```powershell
python -m pip install --user reportlab
python -m pip install --user pypdf
python -m pip install --user pdfplumber
python -m pip install --user pdf2image
python -m pip install --user pillow
winget install --id oschwartz10612.Poppler -e --accept-package-agreements --accept-source-agreements
winget install --id QPDF.QPDF -e --accept-package-agreements --accept-source-agreements
```

Advanced PDF packages can be added manually when needed for specialized workflows:

```powershell
python -m pip install --user pymupdf pikepdf
```

## Git Configuration

After receiving values from the user:

```powershell
git config --global user.name "<name>"
git config --global user.email "<email>"
```

Then verify:

```powershell
git config --global --get user.name
git config --global --get user.email
```

Script shortcut:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap-codex-windows.ps1 -ConfigureGit -GitUserName "<name>" -GitUserEmail "<email>"
```

## Output Format

When done, provide:
- A short status line: `Ready` or `Not Ready`.
- A compact checklist of each required check and pass/fail result.
- Any optional PDF gaps reported in `PdfMissing`.
- The exact remaining actions, if any.
