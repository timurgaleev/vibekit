#!/bin/bash
# lib/vibemon.sh - Vibe Monitor lifecycle helpers, sourced by install.sh.
#
# Kept in a sourceable lib (not inline in install.sh) so the behavior can be
# unit-tested without running the full deploy flow. install.sh sources this
# file; tests source it directly against a sandboxed HOME.
#
# Reads the global PREVIEW_ONLY (true => dry-run, print intent, change nothing).

# Color + message helpers. Defined only if the caller (install.sh) has not
# already provided them, so tests can pre-stub msg_* to stay quiet.
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[0;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

if ! declare -F msg_info >/dev/null 2>&1; then
  msg_info()  { echo -e "${BLUE}  > $*${NC}"; }
fi
if ! declare -F msg_done >/dev/null 2>&1; then
  msg_done()  { echo -e "${GREEN}  + $*${NC}"; }
fi
if ! declare -F msg_add >/dev/null 2>&1; then
  msg_add()   { echo -e "${CYAN}  * $*${NC}"; }
fi
if ! declare -F msg_warn >/dev/null 2>&1; then
  msg_warn()  { echo -e "${YELLOW}  ! $*${NC}"; }
fi

# Guarded recursive delete: refuse unless HOME is set and the target lives under
# it. Prevents a `rm -rf` on a computed path from reaching outside the home dir
# if HOME is empty or a path is built unexpectedly.
_safe_rm_rf() {
  local target="$1"
  if [[ -z "$HOME" || "$target" != "$HOME"/* ]]; then
    msg_warn "Refusing to remove path outside HOME: $target"
    return 1
  fi
  rm -rf "$target"
}

# Purge Vibe Monitor: kill the running Electron app and delete its npx cache and
# app data. Disabling via config only stops future auto-launch; this removes the
# artifacts a prior launch left behind. Honors PREVIEW_ONLY (dry-run).
purge_vibemon() {
  msg_info "Vibe Monitor purge: removing process, npx cache, and app data"

  # 1. Kill running app (best-effort; pkill exits non-zero with no match)
  if command -v pkill >/dev/null 2>&1; then
    if pgrep -f "node_modules/vibemon" >/dev/null 2>&1; then
      if [[ "$PREVIEW_ONLY" == true ]]; then
        msg_add "WOULD kill: running vibemon process(es)"
      else
        pkill -f "node_modules/vibemon" 2>/dev/null || true
        pkill -f "Application Support/vibemon" 2>/dev/null || true
        msg_done "Killed running vibemon process(es)"
      fi
    else
      msg_info "No running vibemon process"
    fi
  fi

  # 2. Remove npx cache (the vibemon npx env, including bundled Electron)
  local found_cache=false
  local d hashdir
  for d in "$HOME"/.npm/_npx/*/node_modules/vibemon; do
    [[ -e "$d" ]] || continue
    found_cache=true
    hashdir="${d%/node_modules/vibemon}"
    if [[ "$PREVIEW_ONLY" == true ]]; then
      msg_add "WOULD remove npx cache: $hashdir"
    else
      _safe_rm_rf "$hashdir"
      msg_done "Removed npx cache: $hashdir"
    fi
  done
  [[ "$found_cache" == false ]] && msg_info "No vibemon npx cache"

  # 3. Remove app data (macOS + Linux locations)
  local dir
  for dir in "$HOME/Library/Application Support/vibemon" "$HOME/.config/vibemon"; do
    [[ -d "$dir" ]] || continue
    if [[ "$PREVIEW_ONLY" == true ]]; then
      msg_add "WOULD remove app data: $dir"
    else
      _safe_rm_rf "$dir"
      msg_done "Removed app data: $dir"
    fi
  done
}
