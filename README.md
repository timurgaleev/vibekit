# vibekit

Personal configuration for AI coding tools — Claude Code, Kiro, and Cursor. Keeps your settings versioned and synced across machines via a single script.

```
vibekit/claude/  →  ~/.claude/
vibekit/kiro/    →  ~/.kiro/
vibekit/cursor/  →  ~/.cursor/
```

---

## Install

```bash
# One-liner (clones repo and syncs everything)
bash -c "$(curl -fsSL timurgaleev.github.io/vibekit/install.sh)"

# Or if you already cloned the repo
./install.sh

# Preview changes without writing anything
./install.sh -n
```

---

## What's inside

### Agents

Specialized sub-agents Claude can delegate work to:

| Agent | What it does |
|-------|-------------|
| `task-planner` | Breaks down complex features into step-by-step plans |
| `system-designer` | Architecture and system design decisions |
| `build-doctor` | Fixes lint, typecheck, and build errors automatically |
| `quality-guard` | Reviews code for quality, security, and maintainability |
| `bug-hunter` | Debugs errors and failing tests |
| `code-shaper` | Refactors code without changing behavior |
| `spec-writer` | Writes unit and integration tests |
| `docs-crafter` | Creates and updates documentation |

### Rules

Always-loaded guidelines that shape how Claude behaves:

| File | What it enforces |
|------|-----------------|
| `style.md` | Code style and file organization |
| `git.md` | Commit format and PR process |
| `language.md` | Always respond in English |
| `patterns.md` | API patterns and conventions |
| `perf.md` | Model selection strategy |
| `security.md` | Security best practices |
| `tests.md` | TDD workflow, 80% coverage target |
| `obsidian.md` | Obsidian vault memory — read context, suggest saves |

### Cursor

Cursor gets the same treatment as Claude and Kiro. Three types of config:

**Rules** (`~/.cursor/rules/*.mdc`) — always-applied AI behavior:

| File | What it enforces |
|------|-----------------|
| `language.mdc` | Always respond in English |
| `style.mdc` | Code style and file organization |
| `git.mdc` | Commit format and PR process |
| `security.mdc` | Security best practices |
| `tests.mdc` | TDD workflow, 80% coverage target |
| `patterns.mdc` | API patterns and conventions |
| `perf.mdc` | Incremental changes and build troubleshooting |
| `obsidian.mdc` | Obsidian vault memory — read context, suggest saves |

Copy rules into any project to activate them:
```bash
cp -r ~/.cursor/rules .cursor/rules
```

**Context ignore** (`~/.cursor/ignore`) — files excluded from AI indexing (dependencies, build outputs, secrets, generated files).

**Settings** (`cursor/settings.json`) — Cursor/VS Code editor settings. Applied manually since Cursor stores these at a different path:

```bash
# macOS
cp cursor/settings.json ~/Library/Application\ Support/Cursor/User/settings.json

# Linux
cp cursor/settings.json ~/.config/Cursor/User/settings.json
```

`install.sh` will warn you if the file has changed and needs to be re-applied.

---

### Status Line

A custom status bar rendered in the Claude Code UI, showing real-time session info:

```
project  feature/xxx *  Opus 4  12.5K / 3.2K  $0.45  2m30s  17:00  +42 -15  62%
```

Shows: project name, git branch, model, token usage, cost, session time, token reset timer, diff stats, and context window usage.

### Vibe Monitor

Broadcasts Claude's current state to external displays in real-time.

**Supported targets:**

| Target | Details |
|--------|---------|
| Desktop App | Frameless Electron app (macOS) at `localhost:19280` |
| ESP32 Device | ESP32-C6-LCD-1.47 via USB Serial or HTTP |

**States sent:**

| State | When |
|-------|------|
| `start` | Session begins |
| `thinking` | Processing a prompt |
| `planning` | Plan mode active |
| `working` | Executing a tool |
| `packing` | Compacting context |
| `notification` | Waiting for user input |
| `done` | Task complete |

See [vibenotif]() for the Desktop app and ESP32 firmware.

---

## Configuration

### VibeNotif config (`~/.vibenotif/config.json`)

This file must be created manually — VibeNotif will not send status updates without it.

```bash
mkdir -p ~/.vibenotif
cat > ~/.vibenotif/config.json << 'EOF'
{
  "cache_path": "~/.vibenotif/cache/statusline.json",
  "auto_launch": false,
  "http_urls": ["http://127.0.0.1:19280"]
}
EOF
```

The Vibe Monitor desktop app (`npx vibemon@latest`) is **disabled by default**.
`install.sh` writes `auto_launch: false` into this config on every run; pass
`-M` (or `VIBEMON=true`) to opt in and auto-start the Electron app with every
Claude session.

Full config with all options:

```json
{
  "cache_path": "~/.vibenotif/cache/statusline.json",
  "auto_launch": false,
  "http_urls": ["http://127.0.0.1:19280"],
  "serial_port": "/dev/cu.usbmodem*",
  "vibenotif_url": "https://vibenotif.example.com",
  "vibenotif_token": "your-token",
  "token_reset_hours": 5
}
```

| Key | Description |
|-----|-------------|
| `auto_launch` | Auto-start Desktop App when Claude starts (managed by `install.sh`; use `-M` to enable) |
| `http_urls` | HTTP targets to send status to (array) |
| `serial_port` | USB serial port for ESP32 (wildcards OK) |
| `vibenotif_url` | VibeNotif cloud API URL |
| `vibenotif_token` | VibeNotif auth token |
| `token_reset_hours` | Rolling token window in hours (`0` = Enterprise, no limit) |

### Environment variables (`~/.claude/.env.local`)

You can use env vars instead of (or alongside) the config file. Config file takes precedence.

```bash
VIBENOTIF_CACHE_PATH=~/.vibenotif/cache/statusline.json
VIBENOTIF_AUTO_LAUNCH=0
VIBENOTIF_HTTP_URLS=http://127.0.0.1:19280,http://192.168.0.185
VIBENOTIF_SERIAL_PORT=/dev/cu.usbmodem*
VIBENOTIF_TOKEN_RESET_HOURS=5
# VIBENOTIF_URL=https://vibenotif.example.com
# VIBENOTIF_TOKEN=your-token
```

### VibeNotif CLI

```bash
python3 ~/.claude/hooks/vibenotif.py --lock [project]   # Lock display to a project
python3 ~/.claude/hooks/vibenotif.py --unlock            # Unlock
python3 ~/.claude/hooks/vibenotif.py --status            # Show current status
python3 ~/.claude/hooks/vibenotif.py --lock-mode         # Show current lock mode
python3 ~/.claude/hooks/vibenotif.py --lock-mode first-project  # Set lock mode
python3 ~/.claude/hooks/vibenotif.py --reboot            # Reboot ESP32 device
```
