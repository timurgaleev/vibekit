# Changelog

All notable changes to vibekit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-08-17

### Added
- Codex CLI is now a deploy target: `codex/` → `~/.codex/`. Ships `AGENTS.md`
  (self-contained global instructions, since Codex loads no `rules/` directory),
  `config.toml`, `hooks.json`, and `rules/default.rules`.
- Manifest-based prune. Each sync records the files it manages in
  `~/.local/state/vibekit/manifest_<target>`; the next sync deletes deployed
  files the repo has since dropped. Files absent from the manifest were installed by the
  user and are never touched.
- Fill-missing merges for configuration the target app rewrites at runtime:
  `codex/config.toml` (TOML), `codex/hooks.json` and `kiro/agents/default.json`
  (JSON), and `codex/rules/default.rules` (only the region between
  `# BEGIN/END vibekit managed codex rules`). Local values always win; only
  absent entries are added.
- Exponential-backoff retry (5s → 10s → 20s, three attempts) around the repo
  clone and pull. A failed pull now warns and deploys the existing checkout
  instead of aborting the sync.
- New always-on rules: `claude-code-usage` (plan mode, subagents, task tracking,
  parallel tool calls, risky-action confirmation, context-window management),
  `problem-solving` (think before coding, goal-driven execution, root cause
  analysis), and `anti-patterns` (trap catalog plus a "Working If" self-check).
  Cursor mirrors ship for the two tool-agnostic ones.
- `ENABLE_TOOL_SEARCH` in `claude/settings.json`, and `curl … | sh` / `curl … |
  bash` added to the Bash deny list.
- `.mergify.yml` — auto-merge on one approving review, with branch cleanup.
- `scripts/gen-codex-agents.py` generates `codex/AGENTS.md` from
  `claude/CLAUDE.md` + `claude/rules/`. Claude Code loads the hub *and* the
  rules directory so the hub can stay thin; Codex loads one file and has no
  rules directory, so the generator inlines each rule body in place of its
  pointer. A rule referenced from several sections is inlined once, at its first
  mention. `--check` and `test/test_codex_agents.sh` fail the suite when the two
  drift, when a `rules/*.md` link survives into the single-file document, when a
  Claude-only tool name leaks in, when a new rule is added that nothing points
  at, or when a rule filename falls outside the grammar the generator matches.
  Parsing is fence-aware throughout, so a fenced example that quotes a
  `rules/…` path keeps its literal text instead of being expanded.

### Changed
- `claude/CLAUDE.md` is now an index rather than a monolith. Each rule's body
  lives in exactly one `rules/` file and the hub carries the summary plus a
  pointer, removing the duplication that shipped the same text twice into every
  session's context. Adds an Instruction Hierarchy (which source wins on
  conflict) and a Priority list (which behavioral rule wins). `cursor/rules/core.mdc`
  follows the same split.
- `rules/style.md` gains the Surgical Changes MUST / MUST NOT checklist,
  `rules/git.md` gains an explicit destructive-operations list, and
  `rules/security.md` scopes its checklist to security-relevant changes instead
  of every commit, plus a confirm-before-acting list.

### Security
- Merge-managed paths come from a static `MERGE_MANAGED` declaration that also
  drives the merge strategy, instead of being collected from the files the repo
  currently ships. Deriving the protected set from current contents dropped the
  protection at exactly the moment it was needed — the release that stops
  shipping one of those files.
- The failed-pull fallback additionally requires a valid git worktree and a
  clean tree. A non-git `$REPO_DIR`, or one with locally deleted source files,
  previously passed the guard; the latter would make the manifest read those
  files as removed and prune the deployed copies. The worktree check compares
  against the literal `true` (a bare repository prints `false` and still exits
  0) and the status check tests its exit code separately from its output (a
  failing `git status` returns an empty string an emptiness test would read as
  "clean").
- `sync_managed_block` validates the source markers' *order*, not just their
  count. One END followed by one BEGIN passed the count check while the
  extractor emitted from BEGIN to EOF with no terminator. Regression test R9.
- Merge-managed paths are passed to prune as an explicit protected list, not
  merely omitted from the current manifest. Omission alone is not enough: a
  manifest written before a file became merge-managed still names it, and prune
  would read that as "dropped from the repo". Regression test R7.
- The legacy cleanup matches the SHA-256 of the exact bytes vibekit shipped
  (recovered from the removal commit), not a substring. A file edited by the
  user — even lightly — is kept and reported.
- The failed-pull guard also covers `rebase-apply`, `CHERRY_PICK_HEAD` and
  `REVERT_HEAD`, and resolves each marker through `git rev-parse --git-path` so
  it works in a linked worktree where `.git` is a file. With the apply rebase
  backend a resolved-but-uncontinued rebase leaves no unmerged index entries,
  so checking `ls-files --unmerged` alone missed it.
- First-time creation of a merge-managed file goes through the atomic write
  path too. It previously used a bare `cp` and reported success unconditionally,
  so an interrupted copy could leave a partial config for the next sync to merge
  into.
- `sync_managed_block` validates the *source* markers as well. An END-only or
  duplicated-marker source passed the extractor and would have replaced the
  destination's managed region with nothing. Regression test R8.
- Prune now resolves each candidate physically before deleting. A symlinked
  directory component (a config directory linked into a dotfiles repo, say)
  previously carried the delete outside the deploy target — the lexical `..`
  check could not see it. Refused and reported instead. Regression test R1.
- Merge-managed files (`codex/config.toml`, `codex/hooks.json`,
  `codex/rules/default.rules`, `kiro/agents/default.json`) are no longer
  recorded in the manifest, so prune can never delete them. They are co-owned
  with the target app; dropping one from the repo would otherwise have taken the
  user's runtime state with it.
- The legacy cleanup verifies content before deleting. Each entry carries a
  fingerprint from the version vibekit shipped, so a file the user wrote at the
  same path is kept and reported rather than removed on the strength of its name.
- Merges write through a temporary file and rename into place. A failing or
  short write previously truncated the destination while the run reported
  success. On failure the destination is left unchanged. Regression test R5.
- `sync_managed_block` validates that the destination has exactly one correctly
  ordered marker pair. A duplicated `BEGIN`, or an `END` before its `BEGIN`,
  made the replacement pass swallow every line to EOF and delete rules the tool
  itself had appended. Regression tests R3, R4.
- A failed `git pull` no longer falls back to a checkout with unresolved merge
  conflicts, which would have deployed half-updated files and driven prune from
  an incomplete file list.
- Filenames containing a newline are skipped rather than written to the
  newline-delimited manifest, where they would have split into entries matching
  unrelated files.

### Fixed
- `json_fill_missing` reported every unchanged file as updated and rewrote it on
  each sync: it compared a hash of a command substitution (trailing newline
  stripped) against a hash of the file (trailing newline present), so the two
  never matched. Comparison is now byte-for-byte via `cmp`. Regression test R2.
- Files removed from the repo stayed on disk forever. `~/.claude/rules/obsidian.md`
  was dropped in v1.5.4 but kept loading into every session, contradicting the
  memex rule that replaced it. Prune now handles this generally, and a one-time
  cleanup removes that specific leftover on the next sync.
- `.pyc` files and `__pycache__` directories are no longer deployed.

## [1.5.4] - 2026-07-27

### Changed
- Persistent memory now runs on the memex MCP server. New `claude/rules/memex.md`
  and `cursor/rules/memex.mdc` describe the read (search, recall, entity recall,
  chronicle) and write (facts, pages, timeline events) paths. The global
  `CLAUDE.md` Memory section names memex as the only backend.

### Removed
- Obsidian memory rules (`claude/rules/obsidian.md`, `cursor/rules/obsidian.mdc`).
  The vault is a personal app, not the assistant's memory store — memex replaces
  it for cross-session context.

## [1.5.3] - 2026-06-30

### Fixed
- Hero graphic (`docs/assets/hero.svg`) clipped its own text. The four feature
  cards were 140px wide but several labels and titles rendered wider
  (`CODES TO YOUR STYLE`, `Plans before coding`, `Reviews every change`), so the
  words crossed or spilled past the card borders. Widened each card to 170px and
  re-spaced them evenly across the canvas (margins 40, gaps 40), moving the text
  centers and the connector wire endpoints to match. All labels now sit inside
  their boxes; colors, the breathing pulse, and the traveling-dot animation are
  unchanged.

## [1.5.2] - 2026-06-30

### Fixed
- Vibe Monitor came back after `auto_launch` was disabled. The app self-installs
  a `com.vibemon.autostart` LaunchAgent (`RunAtLoad` + `KeepAlive`) that
  relaunches `npx vibemon@latest` at login and after every exit, and
  `purge_vibemon` never removed it — so `install.sh -P` left the restart loop
  alive. Purge now boots the job out of launchd and deletes the plist before
  killing the process and clearing the npx cache and app data. Guarded by new
  `test/test_purge_vibemon.sh` assertions (B6, B7).

### Changed
- Documented the LaunchAgent persistence and the full scope of `-P` in
  `install.sh` (header, `-h`, inline comments), `CLAUDE.md` (added the `-P`
  line), and `docs/configuration.md`.

## [1.5.1] - 2026-06-30

### Fixed
- `install.sh` hung on every sync after installing RTK. `rtk init -g` prompts
  before patching `~/.claude/settings.json`, and the install step both ran it
  without `--auto-patch` and redirected its output to `/dev/null`, so the prompt
  was invisible and blocked the `curl | bash` one-liner on a live TTY. Now runs
  `rtk init -g --auto-patch </dev/null` (non-interactive). Guarded by a new
  `test/test_rtk.sh` assertion (R5).

## [1.5.0] - 2026-06-30

### Added
- RTK ([rtk-ai/rtk](https://github.com/rtk-ai/rtk), "Rust Token Killer")
  integration, **on by default**. A standalone Rust CLI that compresses
  shell-command output before it reaches the model. `install.sh` installs it via
  `curl | sh` (tracks the latest release, verifies SHA-256) and then runs
  `rtk init -g` to apply the Claude Code `PreToolUse` hook. Install is
  idempotent — skips the binary download when `rtk` is already on `PATH`. Init
  runs after the `settings.json` merge so the RTK hook survives every sync.
  Skip with `-R` / `RTK=false`; pin with `RTK_VERSION`; override the source with
  `RTK_INSTALL_URL`. Documented in `CLAUDE.md` and `SECURITY.md`.

## [1.4.0] - 2026-06-15

### Added
- Opt-in Ponytail plugin install via `install.sh -Y` (or `PONYTAIL=true`).
  Installs [`DietrichGebert/ponytail`](https://github.com/DietrichGebert/ponytail)
  — a minimal, stdlib-first coding framework — through the official
  `claude plugin` CLI (`marketplace add` + `install`). Off by default; the
  source is overridable with `PONYTAIL_REPO`. If the `claude` CLI is missing the
  step warns and skips without aborting the sync. Documented in
  `docs/configuration.md`; restart Claude Code after install to load it.

## [1.3.3] - 2026-06-14

### Fixed
- `install.sh` failed under the `curl | bash` one-liner with
  `lib/vibemon.sh: No such file or directory`. It sourced the lib from the
  script's own directory before the repo was cloned; in the one-liner path
  `${BASH_SOURCE[0]}` is empty, so the path resolved to `$HOME/lib/...`. The lib
  is now sourced from the cloned repo (`$REPO_DIR`) after the clone/pull step,
  and the purge call site is guarded if the lib is missing.

## [1.3.2] - 2026-06-14

### Changed
- Refocused the README on **what vibekit does**, not how it installs. Added a
  "What it does" section describing the habits the assistant gains (codes to
  your style, plans first, reviews changes, writes in your voice, routes to the
  right workflow), reframed the "What's inside" tables around outcomes, and
  shrank install to a couple of lines.
- Reworked the hero animation to show those capabilities instead of the
  file-sync pipeline, and removed the install/flow diagrams so the page leads
  with substance.

## [1.3.1] - 2026-06-14

### Changed
- Rewrote the README as an open-source landing page: an animated hero diagram
  (`docs/assets/hero.svg`), a dual-audience "What is this?" intro for both
  non-technical and technical readers, badges, and Mermaid diagrams for the sync
  flow and session-state lifecycle. Mirrors the vibestack README style.
- Moved the detailed configuration reference (statusline, Vibe Monitor, VibeNotif
  config, env vars, Cursor settings, Caveman) into `docs/configuration.md` so the
  README stays short and approachable.

## [1.3.0] - 2026-06-14

### Added
- `skills` routing rule (`claude/rules/skills.md`, `cursor/rules/skills.mdc`,
  pointer in `claude/CLAUDE.md`): maps each task to the matching
  [vibestack](https://github.com/timurgaleev/vibestack) slash-command workflow
  (`/plan-eng-review` to plan, `/investigate` to debug, `/code-review` before
  merge, `/ship` to ship, and more), so the assistant reaches for the right
  skill instead of improvising. Skills are treated as optional — if one isn't
  installed, work proceeds normally.

## [1.2.0] - 2026-06-14

### Added
- `authorship` rule (`claude/rules/authorship.md`, `cursor/rules/authorship.mdc`,
  pointer in `claude/CLAUDE.md`): code comments, commit messages, and PR
  descriptions are written in the author's voice with no AI attribution — no
  `Co-Authored-By: Claude` trailer, no "Generated with Claude Code" footer.
- `SECURITY.md` documenting the trust model (install one-liner, `Bash(*)`
  auto-allow default, Caveman supply chain, VibeNotif network egress) and how to
  tighten each. README gains a "Security & trust" section linking to it.
- Tests for the `lib/vibemon.sh` delete guard and the VibeNotif URL-scheme check.

### Changed
- Model-selection guidance in the `perf` rules is now tier-based ("latest Opus /
  Sonnet / Haiku") instead of pinned version numbers, so it stops going stale.
- Genericized the memory-MCP guidance in `claude/CLAUDE.md` — removed personal
  backend references; the public config no longer names a specific provider.

### Security
- Pinned the Caveman installer to a specific upstream commit SHA instead of
  `main`, so `-C` never silently runs newly pushed upstream code. Override with
  `CAVEMAN_INSTALL_URL` to use latest `main`, a fork, or a mirror.
- VibeNotif hooks validate that each target URL uses an `http`/`https` scheme
  before sending; the auth token is only sent to a valid http(s) origin.
- `lib/vibemon.sh` guards its `rm -rf` calls to refuse any path outside `$HOME`.

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

[1.3.3]: https://github.com/timurgaleev/vibekit/releases/tag/v1.3.3
[1.3.2]: https://github.com/timurgaleev/vibekit/releases/tag/v1.3.2
[1.3.1]: https://github.com/timurgaleev/vibekit/releases/tag/v1.3.1
[1.3.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.3.0
[1.2.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.2.0
[1.1.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.1.0
[1.0.0]: https://github.com/timurgaleev/vibekit/releases/tag/v1.0.0
[0.4.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.4.0
[0.3.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.3.0
[0.2.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.2.0
[0.1.0]: https://github.com/timurgaleev/vibekit/releases/tag/v0.1.0
