# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code, Cursor CLI, and Kiro. This repository manages configuration files that are synced to `~/.claude/`, `~/.cursor/`, and `~/.kiro/`.

## Commands

```bash
./install.sh          # Sync all changes (default; vibemon auto-launch OFF)
./install.sh -n       # Dry-run mode (show changes only)
./install.sh -V       # Disable VibeNotif (skip vibenotif.py and hooks)
./install.sh -M       # Enable Vibe Monitor desktop app auto-launch
./install.sh -C       # Install the Caveman token-compression skill (opt-in)
./install.sh -h       # Show help
```

Caveman (`-C` / `CAVEMAN=true`) is opt-in and runs the upstream installer
(`JuliusBrussee/caveman`) via `curl | bash`, which self-updates from `main` and
needs Node >= 18. vibekit does not vendor its files; if Node is missing the step
warns and skips without aborting the sync.

## Architecture

### Sync Flow

```
vibekit/
├── claude/  ──sync──>  ~/.claude/
├── kiro/    ──sync──>  ~/.kiro/
└── cursor/  ──sync──>  ~/.cursor/
```

The `install.sh` script:
1. Clones/pulls from `https://github.com/timurgaleev/vibekit.git` to `~/.vibekit`
2. Compares files using MD5 hashes
3. Shows diffs for changed files
4. Syncs all changes automatically

### Claude Code Settings (`claude/`)

| Component | Purpose |
|-----------|---------|
| `CLAUDE.md` | Global instructions loaded for all projects |
| `settings.json` | Permissions, hooks, model (opus), plugins |
| `agents/*.md` | Specialized sub-agents (planner, builder, debugger, etc.) |
| `hooks/vibenotif.py` | VibeNotif status updates |
| `rules/*.md` | Always-loaded guidelines (language, security, testing) |
| `skills/*/SKILL.md` | User-invokable skills via `/skill-name` |
| `statusline.py` | Custom status line showing usage, cost, context, token reset timer |

### Hook Events

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | vibenotif.py | Initialize status |
| UserPromptSubmit | vibenotif.py | Update to thinking state |
| PreToolUse | vibenotif.py | Update to working state |
| PreCompact | vibenotif.py | Update to compacting state |
| Notification | vibenotif.py | Alert user for input |
| SubagentStart | vibenotif.py | Update to working state |
| SessionEnd | vibenotif.py | Done state |
| Stop | vibenotif.py | Done state |

### Kiro Settings (`kiro/`)

| Component | Purpose |
|-----------|---------|
| `agents/default.json` | Default agent configuration |
| `hooks/vibenotif.py` | VibeNotif status updates |

## Testing Changes

1. Make edits in this repository
2. Run `./install.sh -n` to preview changes
3. Run `./install.sh` to apply changes
4. Test in a new Claude Code session
