#!/bin/bash
#
# This project has moved. Its configuration — CLAUDE.md, the behaviour rules,
# the sub-agents, the statusline, and the Cursor/Kiro/Codex payloads — is now
# part of vibestack, which installs it alongside the skills from one command:
#
#   https://github.com/timurgaleev/vibestack
#
# This script stays here so the published one-liner keeps working. It is a
# bootstrap, not a redirect: vibestack's installer reads the payload from its
# own checkout, so there has to be a checkout before it can run.
#
#   bash -c "$(curl -fsSL timurgaleev.github.io/vibekit/install.sh)"
#
# It clones (or updates) vibestack and runs its installer with the
# configuration phase on, which is what this one-liner always did. Every
# argument you pass is forwarded, so the old flags still work:
#
#   ... install.sh) " -- -n      # preview, write nothing
#   ... install.sh) " -- -C      # also install the Caveman skill
#   ... install.sh) " -- -R      # skip RTK
#
# Override where it clones with VIBESTACK_DIR. An existing checkout is updated,
# never replaced, and a checkout with local modifications is left alone.

set -euo pipefail

REPO_URL="${VIBESTACK_REPO_URL:-https://github.com/timurgaleev/vibestack.git}"
DEST="${VIBESTACK_DIR:-$HOME/vibestack}"

say()  { printf '  %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

printf '\n%s\n' "vibekit is now part of vibestack — installing from $REPO_URL"
printf '%s\n\n' "Skills and configuration, one command. See $DEST after this finishes."

command -v git >/dev/null 2>&1 || die "git is required."

if [ -d "$DEST/.git" ]; then
  say "Updating the existing checkout at $DEST"
  # A dirty checkout is someone's work in progress. Deploy what is there rather
  # than pulling over the top of it.
  if [ -n "$(git -C "$DEST" status --porcelain 2>/dev/null)" ]; then
    say "Local changes present — skipping the pull, installing what is checked out"
  else
    git -C "$DEST" pull --ff-only || say "Pull failed — installing the checkout as it stands"
  fi
elif [ -e "$DEST" ]; then
  die "$DEST exists and is not a git checkout. Move it, or set VIBESTACK_DIR."
else
  say "Cloning into $DEST"
  git clone --depth 1 "$REPO_URL" "$DEST" || die "Clone failed."
fi

[ -x "$DEST/install" ] || die "$DEST/install is missing — the clone looks incomplete."

# vibestack's installer needs bash 4+ for associative arrays, and macOS still
# ships 3.2 as /bin/bash. Find a newer one rather than failing on a machine that
# already has it.
BASH_BIN="bash"
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$candidate" ] && [ "$("$candidate" -c 'echo ${BASH_VERSINFO[0]}')" -ge 4 ]; then
      BASH_BIN="$candidate"
      break
    fi
  done
  if [ "$BASH_BIN" = "bash" ]; then
    die "vibestack's installer needs bash 4+, and this shell is ${BASH_VERSION:-unknown}.
       On macOS: brew install bash, then re-run."
  fi
  say "Using $BASH_BIN ($("$BASH_BIN" -c 'echo $BASH_VERSION'))"
fi

# --with-config keeps the behaviour of this one-liner: it always installed the
# configuration. Anything the caller passes comes after, so it can override.
printf '\n'
exec "$BASH_BIN" "$DEST/install" --with-config "$@"
