# Changelog

All notable changes to vibekit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-05-31

### Changed
- Ignore the `skills-lock.json` and `.agents/` artifacts that the upstream Caveman
  installer writes into the repo root during `./install.sh -C`, so they no longer
  show up as untracked changes after enabling the skill.

## [1.1.0] - 2026-05-31

### Added
- Opt-in `-C` / `CAVEMAN=true` flag for `install.sh` that installs the
  [Caveman](https://github.com/JuliusBrussee/caveman) token-compression skill via
  its official self-updating installer. Off by default, mirroring the `-M` VibeMon
  pattern. Guards on Node >= 18 (warns and skips without aborting the sync), honors
  `-n` preview mode, and supports `CAVEMAN_INSTALL_URL` to override or pin the
  installer source.
- `VERSION` file and this `CHANGELOG.md` so releases are versioned and tagged
  going forward.

## [1.0.0] - 2026-05-18

### Added
- Curated agents pack: 25 agents + manifest.
- Memory Configuration + Search Guidance blocks for memex in `CLAUDE.md`.

### Changed
- Deep-merge `claude/settings.json` on sync to preserve user customizations
  (locally-enabled plugins, permission additions).

## [0.4.0] - 2026-04-26

### Added
- Vibe Monitor auto-launch option in `install.sh` (opt-in via `-M`).
- Obsidian memory rules.

### Removed
- Outdated skills.

## [0.3.0] - 2026-04-20

### Added
- `reroll-buddy` skill.

### Changed
- Statusline enhancements: improved config loading and context usage calculations.
- Improved validation process.

## [0.2.0] - 2026-04-01

### Added
- Skills for documentation sync, PR creation, CodeRabbit resolution, and validation.
- Supamind memory rules for session boot and usage.

### Changed
- Updated `CLAUDE.md` project overview and commands to include Cursor CLI.

## [0.1.0] - 2026-03-10

### Added
- Initial vibekit: config sync for Claude Code, Cursor, and Kiro via `install.sh`.
- VibeNotif / VibeMon status broadcasting.
- Custom statusline.

[1.1.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.1.0
[1.0.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.0.0
[0.4.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.4.0
[0.3.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.3.0
[0.2.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.2.0
[0.1.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.1.0
