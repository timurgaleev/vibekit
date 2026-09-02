# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI-assisted development environment settings for Claude Code, Cursor CLI, and Kiro. This repository manages configuration files that are synced to `~/.claude/`, `~/.cursor/`, and `~/.kiro/`.

## Commands

```bash
./install.sh          # Sync all changes (default)
./install.sh -n       # Dry-run mode (show changes only)
./install.sh -C       # Install the Caveman token-compression skill (opt-in)
./install.sh -Y       # Install the Ponytail minimal-code plugin (opt-in)
./install.sh -R       # Skip RTK (Rust Token Killer; installed by default)
./install.sh -h       # Show help

bash scripts/purge-vibenotif.sh          # Preview the VibeNotif/VibeMon cleanup
APPLY=1 bash scripts/purge-vibenotif.sh  # Apply it
```

`scripts/purge-vibenotif.sh` removes VibeNotif and VibeMon from a machine that
was configured before v1.7.0. Sync prunes the hook *files*, but hook *entries*
inside `~/.claude/settings.json`, `~/.cursor/hooks.json` and
`~/.kiro/agents/default.json` are merged rather than deleted, so an upgrade
alone leaves registrations pointing at scripts that are gone. The script matches
only hooks whose command names `vibenotif.py` or `vibemon.py`, backs up every
file it edits, and is safe to run twice. `install.sh` detects leftover entries
and points at it; it never deletes them itself.

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
├── cursor/  ──sync──>  ~/.cursor/
└── codex/   ──sync──>  ~/.codex/
```

The `install.sh` script:
1. Clones/pulls from `https://github.com/timurgaleev/vibekit.git` to `~/.vibekit`
   (three attempts, exponential backoff; a failed pull deploys the existing checkout)
2. Compares files using MD5 hashes
3. Shows diffs for changed files
4. Syncs all changes automatically
5. Prunes files a previous sync deployed that the repo no longer ships

### Merge vs overwrite

Most files are copied. Files that the target app rewrites at runtime are merged
so local state survives — the helpers live in `lib/sync.sh`:

| File | Strategy |
|------|----------|
| `claude/settings.json` | Deep merge, repo-authoritative for scalars; `permissions.*` arrays are unioned, and `enabledPlugins` + `extraKnownMarketplaces` are deep-merged so a machine's own plugins and marketplaces survive |
| `codex/config.toml` | Add missing tables/keys only |
| `codex/hooks.json`, `cursor/hooks.json`, `kiro/agents/default.json` | Add missing keys only |
| `codex/rules/default.rules` | Replace only the `# BEGIN/END vibekit managed codex rules` block |
| `cursor/cli-config.json` | Copy `permissions`, `approvalMode`, `version` only |

### Plugins and marketplaces

`claude/settings.json` declares the plugins and their marketplaces, so a fresh
machine ends up with the same set instead of whatever was added by hand there.
Caveman and Ponytail are declared alongside the official plugins.

Declaring a plugin is not installing it. `-C` and `-Y` still run the upstream
installers, and they stay opt-in — the settings entry only records the decision
and where the plugin comes from. On a new machine, run `./install.sh -C -Y` if
you want those two present.

The merge is additive in both directions: a marketplace or plugin a machine
added on its own is never dropped, and a repo entry is never overwritten by the
machine. `test/test_settings_merge.sh` extracts the merge program out of
`install.sh` and asserts both halves.

### Instruction sources: one hub, one generated mirror

Claude Code loads `CLAUDE.md` **and** every `rules/*.md`, so the hub stays thin
and each rule's body lives in exactly one spoke. Codex loads a single
`AGENTS.md` and has no `rules/` directory, so the same content must arrive
inlined.

`claude/CLAUDE.md` + `claude/rules/` is the single source.
`scripts/gen-codex-agents.py` expands the hub's `Full rule: \`rules/X.md\``
pointers into the rule bodies and writes `codex/AGENTS.md`.

```bash
python3 scripts/gen-codex-agents.py            # rebuild codex/AGENTS.md
python3 scripts/gen-codex-agents.py --check    # exit 1 if it is stale
```

After editing `claude/CLAUDE.md` or any `claude/rules/*.md`, regenerate.
`test/test_codex_agents.sh` fails the suite otherwise.

Three knobs live at the top of the generator:

| Knob | Purpose |
|------|---------|
| `OVERRIDES` | Swap a hub section for a Codex-specific one (`Claude Code Usage` → `Codex Usage`, sourced from `scripts/codex-sections/`) |
| `NO_INLINE` | Rules whose body is Claude-only (`claude-code-usage`); Codex gets the hub summary instead |
| `APPEND` | Rules the hub never points at but Codex should still receive (`patterns.md`) |

A rule referenced from several sections is inlined once, at its first mention;
later mentions become a cross-reference. Adding a rule that nothing points at is
caught by test G4.

Cursor is a third shape again: `cursor/rules/*.mdc` mirror the `claude/rules/`
bodies with YAML frontmatter, kept in step by hand — the wording differs
slightly per file on purpose.

### Prune

Each sync writes the files it manages to `~/.local/state/vibekit/manifest_<target>`.
The next sync deletes anything present in the previous manifest but absent from
the repo. Files not in the manifest are user-installed and never touched. Adding
a file to `find_excludes` also removes it from the manifest — such a file will
never be pruned.

### Claude Code Settings (`claude/`)

| Component | Purpose |
|-----------|---------|
| `CLAUDE.md` | Global instructions — an index; each rule's body lives in one `rules/` file |
| `settings.json` | Permissions, env, plugins, statusline |
| `agents/*.md` | Specialized sub-agents (planner, builder, debugger, etc.) |
| `rules/*.md` | Always-loaded guidelines (language, security, testing, …) |
| `statusline.py` | Custom status line showing usage, cost, context, token reset timer |

Skills are not shipped here — `rules/skills.md` routes each task to the matching
[vibestack](https://github.com/timurgaleev/vibestack) skill.

### Codex Settings (`codex/`)

| Component | Purpose |
|-----------|---------|
| `AGENTS.md` | **Generated** — do not edit. Built from `claude/CLAUDE.md` + `claude/rules/` by `scripts/gen-codex-agents.py` |
| `config.toml` | Approval policy, permissions, feature flags |
| `hooks.json` | Hook wiring |
| `rules/default.rules` | Command-approval prefix rules (managed block only) |

### Kiro Settings (`kiro/`)

| Component | Purpose |
|-----------|---------|
| `agents/default.json` | Default agent configuration |

## Testing Changes

1. Make edits in this repository
2. Run `bash test/run.sh` — unit tests for `lib/` against a sandboxed `HOME`
3. Run `./install.sh -n` to preview changes (including what would be pruned)
4. Run `./install.sh` to apply changes
5. Test in a new Claude Code session

Changes to `claude/settings.json` need a matching case in
`test/test_settings_merge.sh` when they add a key whose merge behavior matters.

`.github/workflows/test.yml` runs the same suite on every pull request, so a
missing local run is caught before merge.

Changes to `lib/sync.sh` need a matching case in `test/test_sync.sh`. Its tests
run against a fake `HOME`, so they never touch real config. Changes to
`scripts/purge-vibenotif.sh` need one in `test/test_purge_vibenotif.sh`; set
`PURGE_SKIP_SYSTEM=1` there so a test never reaches launchd or the process
table.
