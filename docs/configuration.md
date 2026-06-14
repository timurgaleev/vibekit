# Configuration reference

Everything optional lives here. The defaults work out of the box — reach for
this page only when you want to change something.

## Status line

A custom status bar rendered in the Claude Code UI, showing real-time session info:

```
project  feature/xxx *  Opus 4  12.5K / 3.2K  $0.45  2m30s  17:00  +42 -15  62%
```

Shows: project name, git branch, model, token usage, cost, session time, token
reset timer, diff stats, and context-window usage.

## Vibe Monitor

Broadcasts Claude's current state to external displays in real time.

| Target | Details |
|--------|---------|
| Desktop App | Frameless Electron app (macOS) at `localhost:19280` |
| ESP32 Device | ESP32-C6-LCD-1.47 via USB Serial or HTTP |

States sent: `start`, `thinking`, `planning`, `working`, `packing`,
`notification`, `done` — one per stage of a session.

The desktop app (`npx vibemon@latest`) is **disabled by default**. `install.sh`
writes `auto_launch: false` on every run; pass `-M` (or `VIBEMON=true`) to opt in.
Pass `-P` to purge it (kill the process, delete the npx cache and app data).

## VibeNotif config (`~/.vibenotif/config.json`)

Create this file to enable status broadcasting — VibeNotif stays quiet without it.

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
| `auto_launch` | Auto-start the desktop app (managed by `install.sh`; use `-M`) |
| `http_urls` | HTTP(S) targets to send status to (array) |
| `serial_port` | USB serial port for ESP32 (wildcards OK) |
| `vibenotif_url` | VibeNotif cloud API URL |
| `vibenotif_token` | VibeNotif auth token |
| `token_reset_hours` | Rolling token window in hours (`0` = no limit) |

Only `http`/`https` targets are accepted, and the token is sent only to the
configured cloud origin. See [`SECURITY.md`](../SECURITY.md).

## Environment variables (`~/.claude/.env.local`)

Use instead of, or alongside, the config file. The config file takes precedence.

```bash
VIBENOTIF_CACHE_PATH=~/.vibenotif/cache/statusline.json
VIBENOTIF_AUTO_LAUNCH=0
VIBENOTIF_HTTP_URLS=http://127.0.0.1:19280,http://192.168.0.185
VIBENOTIF_SERIAL_PORT=/dev/cu.usbmodem*
VIBENOTIF_TOKEN_RESET_HOURS=5
# VIBENOTIF_URL=https://vibenotif.example.com
# VIBENOTIF_TOKEN=your-token
```

## VibeNotif CLI

```bash
python3 ~/.claude/hooks/vibenotif.py --lock [project]   # Lock display to a project
python3 ~/.claude/hooks/vibenotif.py --unlock           # Unlock
python3 ~/.claude/hooks/vibenotif.py --status           # Show current status
python3 ~/.claude/hooks/vibenotif.py --lock-mode        # Show current lock mode
python3 ~/.claude/hooks/vibenotif.py --reboot           # Reboot ESP32 device
```

## Cursor editor settings

Cursor stores editor settings at an OS-specific path, so `install.sh` doesn't
write them automatically:

```bash
# macOS
cp cursor/settings.json ~/Library/Application\ Support/Cursor/User/settings.json
# Linux
cp cursor/settings.json ~/.config/Cursor/User/settings.json
```

`install.sh` warns you when this file has changed and needs re-applying.

## Caveman skill (`-C`, opt-in)

[Caveman](https://github.com/JuliusBrussee/caveman) compresses agent output
(`/caveman`, `/caveman-commit`, …). It is **not vendored** — `install.sh -C` runs
Caveman's own installer, pinned to a specific upstream commit (override with
`CAVEMAN_INSTALL_URL`). Requires Node >= 18; if missing, the step warns and
skips. See [`SECURITY.md`](../SECURITY.md) for the trust model.
