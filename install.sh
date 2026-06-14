#!/bin/bash

################################################################################
# install.sh - Deploy vibekit settings to local tools
#
# Targets:
#   claude/ -> ~/.claude/
#   kiro/   -> ~/.kiro/
#   cursor/ -> ~/.cursor/
#
# Usage:
#   ./install.sh          # Deploy all changes (default)
#   ./install.sh -n       # Preview mode (show changes, no writes)
#   ./install.sh -V       # Disable VibeNotif (skip vibenotif.py and hooks)
#   ./install.sh -M       # Enable Vibe Monitor desktop app auto-launch
#   ./install.sh -P       # Purge Vibe Monitor (kill process, remove cache + data)
#   ./install.sh -C       # Install the Caveman token-compression skill
#   ./install.sh -h       # Show help
#
# Environment variables:
#   VIBENOTIF=false ./install.sh   # Same as -V flag
#   VIBEMON=true ./install.sh      # Same as -M flag
#   VIBEMON_PURGE=true ./install.sh # Same as -P flag
#   CAVEMAN=true ./install.sh      # Same as -C flag
#   CAVEMAN_INSTALL_URL=<url> ./install.sh   # Override Caveman installer source
#
# Vibe Monitor (the Electron desktop app launched via `npx vibemon@latest`)
# is disabled by default — the install script writes `auto_launch: false`
# into ~/.vibenotif/config.json so it does not start with Claude sessions.
# Pass -M (or VIBEMON=true) to opt in.
#
# Disabling only flips the config flag; it leaves a previously launched app
# running plus its npx cache (~/.npm/_npx/*/node_modules/vibemon) and app data
# (~/Library/Application Support/vibemon on macOS, ~/.config/vibemon on Linux).
# Pass -P (or VIBEMON_PURGE=true) to actively kill the process and delete those
# artifacts. -P implies disabled and honors -n (preview shows what would go).
#
# Caveman (https://github.com/JuliusBrussee/caveman) is an optional Claude Code
# skill that compresses agent output. It is disabled by default and self-updates
# via its own installer; pass -C (or CAVEMAN=true) to run that installer. It
# requires Node >= 18 and auto-detects which agents to install into.
################################################################################

set -e

REPO_URL="https://github.com/timurgaleev/vibekit.git"
REPO_DIR="${HOME}/.vibekit"

DEPLOY_TARGETS=(
  "claude:${HOME}/.claude"
  "kiro:${HOME}/.kiro"
  "cursor:${HOME}/.cursor"
)

PREVIEW_ONLY=false
VIBENOTIF=${VIBENOTIF:-true}   # Set to false or use -V flag to skip VibeNotif hooks
VIBEMON=${VIBEMON:-false}      # Set to true or use -M flag to enable vibemon auto-launch
VIBEMON_PURGE=${VIBEMON_PURGE:-false}  # Set to true or use -P flag to remove vibemon entirely
CAVEMAN=${CAVEMAN:-false}      # Set to true or use -C flag to install the Caveman skill
# Pinned to a specific commit (not `main`) so enabling -C never silently runs
# whatever lands upstream. Review the upstream diff before bumping this SHA.
# Override with CAVEMAN_INSTALL_URL=<url> to use latest main, a fork, or a mirror.
CAVEMAN_INSTALL_URL=${CAVEMAN_INSTALL_URL:-https://raw.githubusercontent.com/JuliusBrussee/caveman/25d22f864ad68cc447a4cb93aefde918aa4aec9f/install.sh}

# Counters
ADDED=0
CHANGED=0
SKIPPED=0

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

msg_info()  { echo -e "${BLUE}  > $*${NC}"; }
msg_done()  { echo -e "${GREEN}  + $*${NC}"; }
msg_add()   { echo -e "${CYAN}  * $*${NC}"; }
msg_warn()  { echo -e "${YELLOW}  ! $*${NC}"; }

file_hash() {
  if [[ "$(uname)" == "Darwin" ]]; then
    md5 -q "$1" 2>/dev/null
  else
    md5sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

is_bin() {
  file "$1" | grep -qv "text"
}

deploy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

diff_preview() {
  local src="$1" dst="$2"

  if command -v colordiff >/dev/null 2>&1; then
    diff -u "$dst" "$src" | colordiff | head -30
  else
    diff -u "$dst" "$src" | head -30
  fi

  local total
  total=$(diff -u "$dst" "$src" | wc -l)
  if [[ $total -gt 30 ]]; then
    msg_warn "... (${total} lines total, showing first 30)"
  fi
}


# Parse arguments
while getopts "nVMPCh" opt; do
  case $opt in
    n) PREVIEW_ONLY=true ;;
    V) VIBENOTIF=false ;;
    M) VIBEMON=true ;;
    P) VIBEMON_PURGE=true ;;
    C) CAVEMAN=true ;;
    h)
      echo "Usage: $0 [-n] [-V] [-M] [-P] [-C] [-h]"
      echo "  -n  Preview mode (no changes written)"
      echo "  -V  Disable VibeNotif (skip vibenotif.py and hooks config)"
      echo "  -M  Enable Vibe Monitor desktop app auto-launch (off by default)"
      echo "  -P  Purge Vibe Monitor (kill process, delete npx cache + app data)"
      echo "  -C  Install the Caveman token-compression skill (off by default)"
      echo "  -h  Show this help"
      echo ""
      echo "  VIBENOTIF=false $0    # Same as -V via env var"
      echo "  VIBEMON=true $0       # Same as -M via env var"
      echo "  VIBEMON_PURGE=true $0 # Same as -P via env var"
      echo "  CAVEMAN=true $0       # Same as -C via env var"
      exit 0
      ;;
    *)
      echo "Usage: $0 [-n] [-V] [-M] [-P] [-C] [-h]"
      exit 1
      ;;
  esac
done

# -P implies disabled: purge takes precedence over -M, and forces auto_launch off.
if [[ "$VIBEMON_PURGE" == true ]]; then
  VIBEMON=false
fi

echo -e "\n${CYAN}---------------------------------------------------------------${NC}"
echo -e "${CYAN}                     AI-CONFIG DEPLOY                         ${NC}"
echo -e "${CYAN}---------------------------------------------------------------${NC}"

if [[ "$PREVIEW_ONLY" == true ]]; then
  msg_warn "Preview mode: no files will be written"
fi

if [[ "$VIBENOTIF" == false ]]; then
  msg_warn "VibeNotif disabled: skipping vibenotif.py and hooks config"
fi

if [[ "$VIBEMON_PURGE" == true ]]; then
  msg_warn "Vibe Monitor: purge requested (-P) — process, cache, and data will be removed"
elif [[ "$VIBEMON" == true ]]; then
  msg_info "Vibe Monitor auto-launch: enabled (-M)"
else
  msg_info "Vibe Monitor auto-launch: disabled (default — pass -M to enable, -P to purge)"
fi

if [[ "$CAVEMAN" == true ]]; then
  msg_info "Caveman skill: will install (-C)"
else
  msg_info "Caveman skill: skipped (default — pass -C to install)"
fi

# Clone or pull repository
echo -e "\n${CYAN}> Fetching repository...${NC}"

if [[ ! -d "$REPO_DIR" ]]; then
  msg_info "Cloning: $REPO_URL"
  git clone "$REPO_URL" "$REPO_DIR"
  msg_done "Cloned successfully"
else
  msg_info "Updating: $REPO_DIR"
  git -C "$REPO_DIR" pull
  msg_done "Up to date"
fi

# Vibe Monitor lifecycle helpers (purge_vibemon) live in a sourceable lib. Source
# it from the repo we just cloned/pulled, not from this script's own directory:
# the curl | bash one-liner has no local lib/, and ${BASH_SOURCE[0]} is empty in
# that path. Sourcing from $REPO_DIR works for both the one-liner and a clone.
# msg_* are already defined above, so the lib reuses these colored helpers.
if [[ -f "$REPO_DIR/lib/vibemon.sh" ]]; then
  source "$REPO_DIR/lib/vibemon.sh"
else
  msg_warn "lib/vibemon.sh missing in $REPO_DIR — Vibe Monitor purge (-P) unavailable"
fi

# Deploy each target
for entry in "${DEPLOY_TARGETS[@]}"; do
  src_subdir="${entry%%:*}"
  dst_dir="${entry#*:}"
  src_path="$REPO_DIR/$src_subdir"

  if [[ ! -d "$src_path" ]] || [[ -z "$(ls -A "$src_path" 2>/dev/null)" ]]; then
    msg_info "Skipping $src_subdir/ (empty or missing)"
    continue
  fi

  echo -e "\n${CYAN}> Deploying $src_subdir/ -> $dst_dir/${NC}"

  if [[ ! -d "$dst_dir" ]] && [[ "$PREVIEW_ONLY" == false ]]; then
    mkdir -p "$dst_dir"
  fi

  # claude/settings.json is merged separately below to preserve user customizations
  # (locally-enabled plugins, additions to permissions.allow, etc.).
  find_excludes=("-not" "-path" "*/.git/*" "-not" "-name" "cli-config.json")
  if [[ "$src_subdir" == "claude" ]]; then
    find_excludes+=("-not" "-name" "settings.json")
  fi

  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#$src_path/}"
    dst_file="$dst_dir/$rel_path"

    # VibeNotif: skip deploying vibenotif.py and cursor hooks.json (removal handled below)
    if [[ "$VIBENOTIF" == false ]]; then
      if [[ "$(basename "$src_file")" == "vibenotif.py" ]]; then
        continue
      fi
      if [[ "$rel_path" == "hooks.json" ]]; then
        continue
      fi
    fi

    if [[ ! -f "$dst_file" ]]; then
      msg_add "NEW: $rel_path"
      if [[ "$PREVIEW_ONLY" == false ]]; then
        deploy_file "$src_file" "$dst_file"
      fi
      ADDED=$((ADDED + 1))
    else
      src_hash=$(file_hash "$src_file")
      dst_hash=$(file_hash "$dst_file")

      if [[ "$src_hash" == "$dst_hash" ]]; then
        SKIPPED=$((SKIPPED + 1))
      else
        msg_done "UPDATE: $rel_path"
        if ! is_bin "$src_file"; then
          diff_preview "$src_file" "$dst_file"
        fi
        if [[ "$PREVIEW_ONLY" == false ]]; then
          deploy_file "$src_file" "$dst_file"
        fi
        CHANGED=$((CHANGED + 1))
      fi
    fi
  done < <(find "$src_path" -type f "${find_excludes[@]}" -print0 | sort -z)
done

# Claude settings.json: deep merge so user customizations survive sync.
#   - Source wins for scalar/object keys (repo authoritative for shared policy)
#   - permissions.allow/deny/ask/additionalDirectories: array union (user additions kept)
#   - enabledPlugins: deep merge (user-enabled plugins not in repo preserved)
#   - Destination-only top-level keys preserved (e.g. user-set skipAutoPermissionPrompt)
CLAUDE_SETTINGS_SRC="$REPO_DIR/claude/settings.json"
CLAUDE_SETTINGS_DST="${HOME}/.claude/settings.json"
if [[ -f "$CLAUDE_SETTINGS_SRC" ]]; then
  echo -e "\n${CYAN}> Merging claude/settings.json -> $CLAUDE_SETTINGS_DST${NC}"
  if [[ ! -f "$CLAUDE_SETTINGS_DST" ]]; then
    msg_add "NEW: claude/settings.json"
    if [[ "$PREVIEW_ONLY" == false ]]; then
      deploy_file "$CLAUDE_SETTINGS_SRC" "$CLAUDE_SETTINGS_DST"
    fi
    ADDED=$((ADDED + 1))
  elif command -v python3 >/dev/null 2>&1; then
    merged=$(python3 - "$CLAUDE_SETTINGS_SRC" "$CLAUDE_SETTINGS_DST" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    src = json.load(f)
with open(sys.argv[2]) as f:
    dst = json.load(f)

PERMISSION_ARRAY_KEYS = ("allow", "deny", "ask", "additionalDirectories")

def deep_merge(s, d):
    if not isinstance(s, dict) or not isinstance(d, dict):
        return s
    out = dict(d)
    for k, v in s.items():
        if k in d and isinstance(v, dict) and isinstance(d[k], dict):
            out[k] = deep_merge(v, d[k])
        else:
            out[k] = v
    return out

def union_dedup(*arrays):
    seen = set()
    result = []
    for arr in arrays:
        if not isinstance(arr, list):
            continue
        for item in arr:
            key = item if isinstance(item, (str, int, float, bool, type(None))) else repr(item)
            if key in seen:
                continue
            seen.add(key)
            result.append(item)
    return result

merged = deep_merge(src, dst)

if isinstance(src.get("permissions"), dict) and isinstance(dst.get("permissions"), dict):
    merged.setdefault("permissions", {})
    for k in PERMISSION_ARRAY_KEYS:
        s_list = src["permissions"].get(k)
        d_list = dst["permissions"].get(k)
        if isinstance(s_list, list) or isinstance(d_list, list):
            merged["permissions"][k] = union_dedup(s_list or [], d_list or [])

print(json.dumps(merged, indent=2))
PYEOF
)
    merged_hash=$(echo "$merged" | md5 -q 2>/dev/null || echo "$merged" | md5sum | awk '{print $1}')
    dst_hash=$(file_hash "$CLAUDE_SETTINGS_DST")
    if [[ "$merged_hash" != "$dst_hash" ]]; then
      msg_done "MERGE: claude/settings.json (preserved user customizations)"
      if [[ "$PREVIEW_ONLY" == false ]]; then
        echo "$merged" > "$CLAUDE_SETTINGS_DST"
      fi
      CHANGED=$((CHANGED + 1))
    else
      msg_info "no changes after merge"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    msg_warn "python3 not found — falling back to full overwrite of claude/settings.json"
    if [[ "$PREVIEW_ONLY" == false ]]; then
      deploy_file "$CLAUDE_SETTINGS_SRC" "$CLAUDE_SETTINGS_DST"
    fi
    CHANGED=$((CHANGED + 1))
  fi
fi

# VibeNotif: remove installed files and strip hooks from settings when disabled
if [[ "$VIBENOTIF" == false ]]; then
  echo -e "\n${CYAN}> Disabling VibeNotif...${NC}"

  VIBENOTIF_FILES=(
    "${HOME}/.claude/hooks/vibenotif.py"
    "${HOME}/.cursor/hooks/vibenotif.py"
    "${HOME}/.kiro/hooks/vibenotif.py"
    "${HOME}/.cursor/hooks.json"
  )
  for f in "${VIBENOTIF_FILES[@]}"; do
    if [[ -f "$f" ]]; then
      msg_warn "REMOVE: $f"
      if [[ "$PREVIEW_ONLY" == false ]]; then
        rm -f "$f"
      fi
    fi
  done

  # Strip hooks section from ~/.claude/settings.json
  CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
  if [[ -f "$CLAUDE_SETTINGS" ]] && command -v python3 >/dev/null 2>&1; then
    stripped=$(python3 - "$CLAUDE_SETTINGS" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
data.pop("hooks", None)
print(json.dumps(data, indent=2))
PYEOF
)
    stripped_hash=$(echo "$stripped" | md5 -q 2>/dev/null || echo "$stripped" | md5sum | awk '{print $1}')
    dst_hash=$(file_hash "$CLAUDE_SETTINGS")
    if [[ "$stripped_hash" != "$dst_hash" ]]; then
      msg_warn "STRIP hooks: ~/.claude/settings.json"
      if [[ "$PREVIEW_ONLY" == false ]]; then
        echo "$stripped" > "$CLAUDE_SETTINGS"
      fi
    else
      msg_info "hooks already absent: ~/.claude/settings.json"
    fi
  fi
fi

# Vibe Monitor auto-launch: manage only the `auto_launch` key in ~/.vibenotif/config.json
# so the Electron desktop app (`npx vibemon@latest`) does not start with every
# Claude session unless the user explicitly opts in with -M.
if [[ "$VIBENOTIF" == true ]] && command -v python3 >/dev/null 2>&1; then
  VIBENOTIF_CONFIG="${HOME}/.vibenotif/config.json"
  VIBEMON_DESIRED="$VIBEMON"

  patched=$(VIBEMON_DESIRED="$VIBEMON_DESIRED" python3 - "$VIBENOTIF_CONFIG" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
desired = os.environ["VIBEMON_DESIRED"] == "true"
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
        if not isinstance(data, dict):
            data = {}
    except (json.JSONDecodeError, IOError):
        data = {}
data["auto_launch"] = desired
print(json.dumps(data, indent=2))
PYEOF
)

  if [[ ! -f "$VIBENOTIF_CONFIG" ]]; then
    msg_add "NEW: ~/.vibenotif/config.json (auto_launch=${VIBEMON})"
    if [[ "$PREVIEW_ONLY" == false ]]; then
      mkdir -p "$(dirname "$VIBENOTIF_CONFIG")"
      echo "$patched" > "$VIBENOTIF_CONFIG"
    fi
  else
    patched_hash=$(echo "$patched" | md5 -q 2>/dev/null || echo "$patched" | md5sum | awk '{print $1}')
    dst_hash=$(file_hash "$VIBENOTIF_CONFIG")
    if [[ "$patched_hash" != "$dst_hash" ]]; then
      msg_done "UPDATE: ~/.vibenotif/config.json (auto_launch=${VIBEMON})"
      if [[ "$PREVIEW_ONLY" == false ]]; then
        echo "$patched" > "$VIBENOTIF_CONFIG"
      fi
    else
      msg_info "auto_launch already ${VIBEMON}: ~/.vibenotif/config.json"
    fi
  fi
fi

# Vibe Monitor purge: remove the process and on-disk artifacts a prior launch
# left behind (runs after auto_launch is set false above). Independent of
# VIBENOTIF so it works even with -V.
if [[ "$VIBEMON_PURGE" == true ]]; then
  if declare -F purge_vibemon >/dev/null 2>&1; then
    purge_vibemon
  else
    msg_warn "Purge requested but lib/vibemon.sh was not loaded — skipping"
  fi
fi

# Cursor cli-config.json: merge only non-personal keys (permissions, approvalMode)
# to avoid overwriting personal data (authInfo, model, etc.)
CURSOR_CLI_CONFIG_SRC="$REPO_DIR/cursor/cli-config.json"
CURSOR_CLI_CONFIG_DST="${HOME}/.cursor/cli-config.json"
if [[ -f "$CURSOR_CLI_CONFIG_SRC" ]]; then
  if [[ ! -f "$CURSOR_CLI_CONFIG_DST" ]]; then
    msg_add "NEW: cursor/cli-config.json"
    if [[ "$PREVIEW_ONLY" == false ]]; then
      deploy_file "$CURSOR_CLI_CONFIG_SRC" "$CURSOR_CLI_CONFIG_DST"
    fi
    ADDED=$((ADDED + 1))
  else
    if command -v python3 >/dev/null 2>&1; then
      merged=$(python3 - "$CURSOR_CLI_CONFIG_SRC" "$CURSOR_CLI_CONFIG_DST" <<'PYEOF'
import json, sys
src = json.load(open(sys.argv[1]))
dst = json.load(open(sys.argv[2]))
for key in ("permissions", "approvalMode", "version"):
    if key in src:
        dst[key] = src[key]
print(json.dumps(dst, indent=2))
PYEOF
)
      merged_hash=$(echo "$merged" | md5 -q 2>/dev/null || echo "$merged" | md5sum | awk '{print $1}')
      dst_hash=$(file_hash "$CURSOR_CLI_CONFIG_DST")
      if [[ "$merged_hash" != "$dst_hash" ]]; then
        msg_done "MERGE: cursor/cli-config.json (permissions, approvalMode)"
        if [[ "$PREVIEW_ONLY" == false ]]; then
          echo "$merged" > "$CURSOR_CLI_CONFIG_DST"
        fi
        CHANGED=$((CHANGED + 1))
      else
        SKIPPED=$((SKIPPED + 1))
      fi
    else
      msg_warn "python3 not found — skipping cursor/cli-config.json merge"
    fi
  fi
fi

# Cursor settings.json requires a manual step (different path per OS)
CURSOR_SETTINGS_SRC="$REPO_DIR/cursor/settings.json"
if [[ -f "$CURSOR_SETTINGS_SRC" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    CURSOR_SETTINGS_DST="$HOME/Library/Application Support/Cursor/User/settings.json"
  else
    CURSOR_SETTINGS_DST="$HOME/.config/Cursor/User/settings.json"
  fi
  if [[ ! -f "$CURSOR_SETTINGS_DST" ]]; then
    msg_add "NOTE: Cursor settings.json not applied automatically."
    msg_info "  To apply: cp \"$CURSOR_SETTINGS_SRC\" \"$CURSOR_SETTINGS_DST\""
  else
    src_hash=$(file_hash "$CURSOR_SETTINGS_SRC")
    dst_hash=$(file_hash "$CURSOR_SETTINGS_DST")
    if [[ "$src_hash" != "$dst_hash" ]]; then
      msg_warn "Cursor settings.json has changes — merge manually:"
      msg_info "  Source:      $CURSOR_SETTINGS_SRC"
      msg_info "  Destination: $CURSOR_SETTINGS_DST"
    fi
  fi
fi

# Caveman skill: opt-in install via its official installer (self-updating).
# Off by default; enabled with -C or CAVEMAN=true. Requires Node >= 18 — if it
# is missing we warn and skip rather than aborting the whole sync.
if [[ "$CAVEMAN" == true ]]; then
  echo -e "\n${CYAN}> Installing Caveman skill...${NC}"

  node_major=""
  if command -v node >/dev/null 2>&1; then
    node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo "")
  fi

  if [[ -z "$node_major" ]]; then
    msg_warn "Node not found — skipping Caveman (needs Node >= 18)"
    msg_info "Install Node, then re-run: $0 -C"
  elif [[ "$node_major" -lt 18 ]]; then
    msg_warn "Node $(node -v 2>/dev/null) is too old — skipping Caveman (needs Node >= 18)"
    msg_info "Upgrade Node, then re-run: $0 -C"
  elif [[ "$PREVIEW_ONLY" == true ]]; then
    msg_warn "Preview mode: would run Caveman installer:"
    msg_info "  curl -fsSL \"$CAVEMAN_INSTALL_URL\" | bash"
  else
    msg_info "Running Caveman installer: $CAVEMAN_INSTALL_URL"
    if curl -fsSL "$CAVEMAN_INSTALL_URL" | bash; then
      msg_done "Caveman installed"
    else
      msg_warn "Caveman installer failed — skipping (sync continues)"
    fi
  fi
fi

# Summary
echo -e "\n${GREEN}---------------------------------------------------------------${NC}"
echo -e "${GREEN}                       DEPLOY COMPLETE                        ${NC}"
echo -e "${GREEN}---------------------------------------------------------------${NC}"
echo
msg_info "Results:"
msg_add  "  New:       $ADDED"
msg_done "  Updated:   $CHANGED"
msg_info "  Unchanged: $SKIPPED"
echo
