# Codex Windows Bootstrap Skill

This skill prepares a Windows machine so Codex can work reliably without constant tool fallback logic.

The key design point: users are **not** expected to pre-install prerequisites.  
The bootstrap process checks what is present and installs what is missing.

## Why This Exists

Codex uses a consistent set of CLI tools repeatedly (`git`, `rg`, `gh`, `node`, `python`, etc.).  
If those tools are missing, Codex has to try alternatives, recover from failures, and re-plan commands. That burns time and tokens.

This skill standardizes the environment up front so Codex can execute the normal fast path:

- fewer failed command attempts
- fewer fallback branches
- lower token use across sessions
- more predictable outcomes

## What The Skill Owns

When you run bootstrap in auto mode, the skill is responsible for:

- checking required prerequisites
- installing missing prerequisites
- checking core tools used by Codex
- installing missing core tools
- checking Python helper modules used by Codex workflows
- installing missing Python helper modules
- validating Git identity and GitHub auth state

You only need to respond to installer/UAC/login prompts when Windows or GitHub requires interaction.

## Required Prerequisites (Checked And Installed By Bootstrap)

The script treats these as baseline requirements and installs missing ones first in `-AutoInstall` mode:

- `python` - Python interpreter (`>= 3.11`; installed via `Python.Python.3.13`)
- `code` - Visual Studio Code CLI (`code --version`; installed via `Microsoft.VisualStudioCode`)

## Core Tools (Checked And Installed By Bootstrap)

The script checks these and installs missing ones in `-AutoInstall` mode:

- `git` - Git version control
- `node` - Node.js runtime
- `npm` - Node package manager
- `gh` - GitHub CLI
- `rg` - ripgrep fast file/text search
- `uv` - Astral `uv` Python/package environment tool

## Python Tooling (Checked And Installed By Bootstrap)

The script checks these and installs missing ones in `-AutoInstall` mode:

- `python -m virtualenv --version` - `virtualenv` Python environment module
- `python -m pylint --version` - `pylint` Python linter module

It also ensures Python user Scripts is on user `PATH` using a `%USERPROFILE%`-based entry.

## Optional Tools

Optional utilities can be installed on request:

- `jq` - command-line JSON processor
- `fd` - fast file finder
- `bat` - `cat` replacement with syntax highlighting
- `Git LFS` - Git Large File Storage support
- `Docker Desktop` - local container runtime and tooling

Use `-PromptOptionalTools` to ask interactively, or `-InstallOptionalTools` to install without prompting.

## Install Skill On A New Machine

1. Copy this folder to `%USERPROFILE%\.codex\skills\codex-windows-bootstrap`
2. Restart Codex (or open a new Codex session)
3. Trigger with `Use $codex-windows-bootstrap to bootstrap this machine.`

## Install And Use After Codex Is Already Installed

If Codex is already installed on the machine, install this skill with these steps:

1. Open PowerShell.
2. Create the skill directory if it does not exist:
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.codex\skills\codex-windows-bootstrap"
```
3. Copy this repo's files into that directory (`README.md`, `SKILL.md`, `agents`, `scripts`).
4. Restart Codex (or start a new Codex session) so it loads the skill.
5. In Codex, run:
```text
Use $codex-windows-bootstrap to bootstrap this machine.
```

## Script Usage

Audit only (read-only check):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1
```

Auto-install missing required tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1 -AutoInstall
```

Auto-install and ask whether optional tools should be installed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1 -AutoInstall -PromptOptionalTools
```

Auto-install including optional tools without prompting:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1 -AutoInstall -InstallOptionalTools
```

Set Git identity:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1 -ConfigureGit -GitUserName "your-name" -GitUserEmail "you@example.com"
```

Combined setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-codex-windows.ps1 -AutoInstall -ConfigureGit -GitUserName "your-name" -GitUserEmail "you@example.com"
```

## Output

The script returns JSON with:

- `Status` (`Ready` or `Not Ready`)
- `Actions` (install/config actions attempted)
- `Installed`
- `Missing`
- `Misconfigured`
- `AllChecks`
