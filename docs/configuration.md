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

Two environment variables tune it:

| Variable | Default | Meaning |
|----------|---------|---------|
| `CLAUDE_TOKEN_RESET_HOURS` | `5` | Length of the token window; `0` disables the timer |
| `CLAUDE_STATUSLINE_STATE_DIR` | `~/.claude/statusline` | Where the window-start timestamp is kept |

## Removing VibeNotif and VibeMon (pre-1.7.0 machines)

vibekit stopped shipping status hooks in v1.7.0. A machine configured before
that still carries their registrations: sync prunes the hook *files*, but hook
*entries* in `~/.claude/settings.json`, `~/.cursor/hooks.json` and
`~/.kiro/agents/default.json` are merged rather than deleted.

```bash
bash scripts/purge-vibenotif.sh          # show what would change
APPLY=1 bash scripts/purge-vibenotif.sh  # apply
```

It only removes hooks whose command names `vibenotif.py` or `vibemon.py`, so
RTK, Caveman and anything else sharing those files survive. Backups land in
`~/.vibekit-purge-backup-<timestamp>`. It also migrates the status line's
token-window state out of `~/.vibenotif/` and, on macOS, removes the VibeMon
LaunchAgent, npx cache and app data. Running it twice is a no-op.

If your old `~/.vibenotif/config.json` held a `vibenotif_token`, revoke it at
the service — deleting the file does not.

## Plugins

`claude/settings.json` ships the plugin set and the marketplaces they come from,
so the same plugins are declared on every machine you sync:

| Plugin | Marketplace |
|--------|-------------|
| `context7`, `superpowers`, `telegram` | `claude-plugins-official` |
| `caveman` | `JuliusBrussee/caveman` |
| `ponytail` | `DietrichGebert/ponytail` |

Declaring is not installing. Caveman and Ponytail are still opt-in: run
`./install.sh -C -Y` on a machine where you want them actually installed. The
settings entry records the choice and the source; the flags fetch the code.

Plugins and marketplaces you add yourself are never removed by a sync — both
keys are deep-merged, not replaced.

## Codex CLI

`codex/` deploys to `~/.codex/`. Codex loads no `rules/` directory, so
`AGENTS.md` has to be self-contained — every rule inlined, not pointed at. It is
**generated** from `claude/CLAUDE.md` + `claude/rules/` by
`scripts/gen-codex-agents.py`; edit those, not `AGENTS.md`. A project-root
`AGENTS.md` still wins over it.

Two files there are rewritten by Codex itself, so the sync merges instead of
overwriting:

| File | How it syncs |
|------|--------------|
| `config.toml` | Adds only tables and keys you do not already have. Project trust, TUI state, and any value you changed are preserved. |
| `rules/default.rules` | Replaces only the region between `# BEGIN vibekit managed codex rules` and `# END …`. Prefix rules Codex appended when you approved a command live outside the markers and survive. |
| `hooks.json` | Adds only missing keys. |

`kiro/agents/default.json` uses the same add-only-missing merge.

## Pruning removed files

Every sync writes the list of files it manages to
`~/.local/state/vibekit/manifest_<target>`. The next sync deletes anything that
was in the previous manifest but is no longer in the repo — so a rule dropped upstream
stops loading on your machine instead of lingering forever.

Files that are not in the manifest were installed by you (hand-written skills,
vendored packs) and are never touched. `./install.sh -n` lists what would be
pruned without deleting anything.

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

## Ponytail plugin (`-Y`, opt-in)

[Ponytail](https://github.com/DietrichGebert/ponytail) steers the agent toward
minimal, stdlib-first code (the "best code is the code you never wrote"). It is
**not vendored** — `install.sh -Y` installs it through the official
`claude plugin` CLI (`marketplace add DietrichGebert/ponytail` + `install
ponytail@ponytail`). Override the source with `PONYTAIL_REPO`. Requires the
`claude` CLI; if missing, the step warns and skips. Unlike Caveman it tracks the
marketplace repo's default branch (no commit-SHA pin). Restart Claude Code after
install to load it.

## RTK (`-R` to skip, on by default)

[RTK](https://github.com/rtk-ai/rtk) ("Rust Token Killer") is a standalone Rust
CLI that compresses shell-command output before it reaches the model. Unlike
Caveman and Ponytail it is **on by default** — `install.sh` installs it via
`curl | sh` and runs `rtk init -g` to apply the Claude Code `PreToolUse` hook.
The install is idempotent: if `rtk` is already on `PATH` the binary download is
skipped and only the hook is refreshed. Init runs **after** the `settings.json`
merge so the RTK hook survives every sync (the merge is repo-authoritative for
the hooks map and would otherwise clobber it).

- Skip entirely with `-R` (or `RTK=false`).
- The installer tracks the latest tagged release and verifies SHA-256
  checksums. Pin with `RTK_VERSION=vX.Y.Z`; override the source with
  `RTK_INSTALL_URL`.
- Restart Claude Code after install to load the hook. Remove it with
  `rtk init -g --uninstall`. See [`SECURITY.md`](../SECURITY.md) for the trust
  model.
