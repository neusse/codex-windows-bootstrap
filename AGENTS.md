# AGENTS.md

## Purpose

This repository is a Codex Windows bootstrap skill project.

## Startup Behavior (Required)

When this project is opened, the agent must do the following before other work:

1. Ask the user:
   `Do you want me to bootstrap this Windows machine for Codex by installing and configuring required packages now?`
2. Wait for explicit user confirmation.
3. Only if the user answers yes, execute the local project skill:
   `codex-windows-bootstrap`

If the user answers no, do not run bootstrap automatically. Continue with other requested work.

## Skill Location

Use the project-level skill copy in this repository:

`.codex/skills/codex-windows-bootstrap`

Do not default to the system-level skill copy unless the user explicitly asks for it.

## Execution Notes

- Use the skill workflow as defined in the local `SKILL.md`.
- Report audit/install results clearly (`Installed`, `Missing`, `Misconfigured`, readiness status).
- Do not make destructive system changes outside the bootstrap workflow unless the user asks.
