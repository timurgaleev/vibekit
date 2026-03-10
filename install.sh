#!/bin/bash

################################################################################
# install.sh - Deploy vibekit settings to local tools
#
# Targets:
#   claude/ -> ~/.claude/
#   kiro/   -> ~/.kiro/
#
# Usage:
#   ./sync.sh          # Deploy all changes (default)
#   ./sync.sh -n       # Preview mode (show changes, no writes)
#   ./sync.sh -h       # Show help
################################################################################

set -e

REPO_URL="https://github.com/timurgaleev/vibekit.git"
REPO_DIR="${HOME}/.vibekit"

DEPLOY_TARGETS=(
  "claude:${HOME}/.claude"
  "kiro:${HOME}/.kiro"
)

PREVIEW_ONLY=false

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
while getopts "nh" opt; do
  case $opt in
    n) PREVIEW_ONLY=true ;;
    h)
      echo "Usage: $0 [-n] [-h]"
      echo "  -n  Preview mode (no changes written)"
      echo "  -h  Show this help"
      exit 0
      ;;
    *)
      echo "Usage: $0 [-n] [-h]"
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
  done < <(find "$src_path" -type f -not -path '*/.git/*' -print0 | sort -z)
done

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
