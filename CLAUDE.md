# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code and Kiro. This repository manages configuration files that are synced to `~/.claude/` and `~/.kiro/`.

## Commands

```bash
./install.sh          # Sync all changes (default)
./install.sh -n       # Dry-run mode (show changes only)
./install.sh -h       # Show help
```

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
| `hooks/vibemon.py` | VibeMon status updates |
| `rules/*.md` | Always-loaded guidelines (language, security, testing) |
| `skills/*/SKILL.md` | User-invokable skills via `/skill-name` |
| `statusline.py` | Custom status line showing usage, cost, context, token reset timer |

### Hook Events

| Event | Script | Purpose |
|-------|--------|---------|
| SessionStart | vibemon.py | Initialize status |
| UserPromptSubmit | vibemon.py | Update to thinking state |
| PreToolUse | vibemon.py | Update to working state |
| PreCompact | vibemon.py | Update to compacting state |
| Notification | vibemon.py | Alert user for input |
| SubagentStart | vibemon.py | Update to working state |
| SessionEnd | vibemon.py | Done state |
| Stop | vibemon.py | Done state |

### Kiro Settings (`kiro/`)

| Component | Purpose |
|-----------|---------|
| `agents/default.json` | Default agent configuration |
| `hooks/vibemon.py` | VibeMon status updates |

## Testing Changes

1. Make edits in this repository
2. Run `./install.sh -n` to preview changes
3. Run `./install.sh` to apply changes
4. Test in a new Claude Code session
