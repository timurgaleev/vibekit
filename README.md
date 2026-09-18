# vibekit has moved into vibestack

**This repository is archived.** Everything it shipped — `CLAUDE.md`, the
behaviour rules, the sub-agents, the statusline, and the Cursor, Kiro and Codex
payloads — now lives in **[vibestack](https://github.com/timurgaleev/vibestack)**
and installs from the same command as the skills.

Two repositories meant two clones and two installers for one setup, and the
skills' own routing rule had to describe half the product as something that
might not be installed. One repository ends that.

## Install

```bash
git clone https://github.com/timurgaleev/vibestack ~/vibestack
~/vibestack/install --with-config
```

`--with-config` is the half this repository used to be. Without it you get the
skills alone; `--only=config` gets you this half alone; `--with-config -n`
previews every change and writes nothing.

The one-liner still works and does the same thing — it clones vibestack and runs
its installer:

```bash
bash -c "$(curl -fsSL timurgaleev.github.io/vibekit/install.sh)"
```

## What changed for you

| Before | Now |
|---|---|
| `./install.sh` | `./install --with-config` |
| `./install.sh -n` | `./install --with-config -n` |
| `./install.sh -C` / `-Y` / `-D` / `-R` | the same flags, on `./install` |
| `CAVEMAN=true`, `RTK=false`, … | unchanged |
| nothing | `./uninstall --with-config` removes what it installed |

Your existing installation keeps working and upgrades in place. The markers in
`~/.claude/CLAUDE.md` and the manifests under `~/.local/state/vibekit/` were
deliberately left alone: they identify what is already on your machine, and
renaming them would have orphaned it.

Three ways the old installer could destroy a configuration file were found and
fixed during the move — a failed JSON merge writing an empty file over your
settings, a failed run pruning the files it had just installed, and a TOML merge
producing a file Codex could not read. See
[vibestack's CHANGELOG](https://github.com/timurgaleev/vibestack/blob/main/CHANGELOG.md)
for v1.39.0.

## This repository

Left in place, read-only, for its history and for the URL above. The payload
directories below are the last version that shipped from here; the maintained
copies are in `config/` in vibestack.

[MIT](LICENSE) · [CHANGELOG](CHANGELOG.md) · [SECURITY](SECURITY.md)
