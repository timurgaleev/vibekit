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
#   ./install.sh -h       # Show help
#
# Environment variables:
#   VIBENOTIF=false ./install.sh   # Same as -V flag
#   VIBEMON=true ./install.sh      # Same as -M flag
#
# Vibe Monitor (the Electron desktop app launched via `npx vibemon@latest`)
# is disabled by default — the install script writes `auto_launch: false`
# into ~/.vibenotif/config.json so it does not start with Claude sessions.
# Pass -M (or VIBEMON=true) to opt in.
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
while getopts "nVMh" opt; do
  case $opt in
    n) PREVIEW_ONLY=true ;;
    V) VIBENOTIF=false ;;
    M) VIBEMON=true ;;
    h)
      echo "Usage: $0 [-n] [-V] [-M] [-h]"
      echo "  -n  Preview mode (no changes written)"
      echo "  -V  Disable VibeNotif (skip vibenotif.py and hooks config)"
      echo "  -M  Enable Vibe Monitor desktop app auto-launch (off by default)"
      echo "  -h  Show this help"
      echo ""
      echo "  VIBENOTIF=false $0   # Same as -V via env var"
      echo "  VIBEMON=true $0      # Same as -M via env var"
      exit 0
      ;;
    *)
      echo "Usage: $0 [-n] [-V] [-M] [-h]"
      exit 1
      ;;
  esac
done

echo -e "\n${CYAN}---------------------------------------------------------------${NC}"
echo -e "${CYAN}                     AI-CONFIG DEPLOY                         ${NC}"
echo -e "${CYAN}---------------------------------------------------------------${NC}"

if [[ "$PREVIEW_ONLY" == true ]]; then
  msg_warn "Preview mode: no files will be written"
fi

if [[ "$VIBENOTIF" == false ]]; then
  msg_warn "VibeNotif disabled: skipping vibenotif.py and hooks config"
fi

if [[ "$VIBEMON" == true ]]; then
  msg_info "Vibe Monitor auto-launch: enabled (-M)"
else
  msg_info "Vibe Monitor auto-launch: disabled (default — pass -M to enable)"
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
  done < <(find "$src_path" -type f -not -path '*/.git/*' -not -name 'cli-config.json' -print0 | sort -z)
done

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
