# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code, Cursor CLI, and Kiro. This repository manages configuration files that are synced to `~/.claude/`, `~/.cursor/`, and `~/.kiro/`.

## Commands

```bash
./install.sh          # Sync all changes (default; vibemon auto-launch OFF)
./install.sh -n       # Dry-run mode (show changes only)
./install.sh -V       # Disable VibeNotif (skip vibenotif.py and hooks)
./install.sh -M       # Enable Vibe Monitor desktop app auto-launch (opt-in)
./install.sh -P       # Purge Vibe Monitor (LaunchAgent, process, cache, app data)
./install.sh -C       # Install the Caveman token-compression skill (opt-in)
./install.sh -Y       # Install the Ponytail minimal-code plugin (opt-in)
./install.sh -R       # Skip RTK (Rust Token Killer; installed by default)
./install.sh -h       # Show help
```

Caveman (`-C` / `CAVEMAN=true`) is opt-in and runs the upstream installer
(`JuliusBrussee/caveman`) via `curl | bash`, **pinned to a specific commit SHA**
(override with `CAVEMAN_INSTALL_URL`) and needs Node >= 18. vibekit does not
vendor its files; if Node is missing the step warns and skips without aborting
the sync. See `SECURITY.md` for the trust model and how to bump the pin.

Ponytail (`-Y` / `PONYTAIL=true`) is opt-in and installs the
`DietrichGebert/ponytail` plugin via the official `claude plugin` CLI
(`marketplace add` + `install`). It steers the agent toward minimal,
stdlib-first code. Override the source with `PONYTAIL_REPO`. Needs the `claude`
CLI; if missing, the step warns and skips without aborting the sync. Unlike
Caveman it tracks the marketplace repo's default branch (no commit-SHA pin).
Restart Claude Code after install to load it.

RTK (`rtk-ai/rtk`, "Rust Token Killer") is **on by default** — it is a
standalone Rust CLI that compresses shell-command output before it reaches the
model. The install is idempotent: if `rtk` is already on `PATH` the binary
download is skipped and only the Claude Code hook is refreshed. Skip it entirely
with `-R` (or `RTK=false`). The installer (`curl | sh`) tracks the latest release
unless `RTK_VERSION` is pinned, and verifies SHA-256 checksums; override the
source with `RTK_INSTALL_URL`. `rtk init -g` writes a `PreToolUse` hook into
`~/.claude/settings.json`; because the settings merge is repo-authoritative for
the hooks map, init runs **after** that merge so the RTK hook survives every
sync. Restart Claude Code after install to load it. See `SECURITY.md`.

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
