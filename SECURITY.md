# Security & Trust

vibekit syncs configuration into `~/.claude/`, `~/.cursor/`, and `~/.kiro/` and
can run optional helpers. This document explains what runs, what it can reach,
and the trade-offs in the shipped defaults so you can make an informed choice
before installing.

## Reporting a vulnerability

Open a private security advisory on the GitHub repository, or contact the
maintainer directly. Please do not file public issues for sensitive reports.

## Trust model

### The install one-liner

```bash
bash -c "$(curl -fsSL timurgaleev.github.io/vibekit/install.sh)"
```

This downloads and executes a script over the network. It is convenient but
gives the host (GitHub Pages) the ability to run code as your user. If you
prefer to inspect before running:

```bash
git clone https://github.com/timurgaleev/vibekit.git
cd vibekit
less install.sh        # review
./install.sh -n        # preview the diff, writes nothing
./install.sh           # apply
```

`-n` (preview) writes nothing — use it first on any machine you care about.

### `Bash(*)` auto-allow + `acceptEdits`

`claude/settings.json` ships `permissions.allow: ["Bash(*)"]` with
`defaultMode: "acceptEdits"`. This is a deliberate low-friction default for the
maintainer's own workflow: Claude can run shell commands and apply edits without
prompting. The `deny` list blocks a set of obviously destructive commands, but a
blocklist is **defense-in-depth, not a sandbox** — it can be bypassed.

If you sync vibekit to your own machine and want tighter control, edit
`~/.claude/settings.json` after install:
- Remove `"Bash(*)"` from `permissions.allow` to be prompted per command.
- Change `defaultMode` from `acceptEdits` to a prompting mode.

The sync deep-merges settings and preserves your `permissions.allow` additions,
but `defaultMode` is taken from the repo — re-apply your preference after a sync,
or fork and change the shipped value.

### Caveman skill (`-C`, opt-in, off by default)

`./install.sh -C` runs a third-party installer
([JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)). To avoid
silently executing whatever lands on the upstream `main` branch, the default
installer URL is **pinned to a specific commit**:

```
https://raw.githubusercontent.com/JuliusBrussee/caveman/25d22f864ad68cc447a4cb93aefde918aa4aec9f/install.sh
```

- Pinning means upstream changes are not pulled in until this repo bumps the SHA.
- To bump: replace the SHA in `install.sh` (`CAVEMAN_INSTALL_URL` default) after
  reviewing the upstream diff between the old and new commit.
- To use a different source (latest `main`, a fork, a mirror), override at runtime:
  `CAVEMAN_INSTALL_URL=<url> ./install.sh -C`.
- Requires Node >= 18; if missing, the step warns and skips without aborting.

Note: Caveman's own installer may self-update on later runs — review upstream
before enabling it on sensitive machines.

### VibeNotif / Vibe Monitor network egress

The status hooks (`hooks/vibenotif.py`) can POST session state to targets in
`~/.vibenotif/config.json` (`http_urls`, `vibenotif_url`). Defaults point at
`localhost`. Only `http`/`https` targets are accepted; the auth token is sent
only to the configured cloud origin (`vibenotif_url`). To disable broadcasting
entirely, install with `-V` (removes the hooks) or omit the config file.

The desktop app (`-M`, off by default) launches `npx vibemon@latest`, which
fetches and runs an npm package. It is disabled unless you opt in.

## What is NOT in this repo

- No secrets, tokens, or API keys are committed. Token references are
  environment-variable lookups or documentation placeholders.
- Personal infrastructure references are kept out of the public config; the
  memory-MCP guidance is generic ("configure your own backend").
