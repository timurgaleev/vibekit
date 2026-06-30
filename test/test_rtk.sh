#!/bin/bash
# Guards the RTK integration in install.sh.
#
# RTK installs by default (skip with -R). Two regressions this locks down:
#  - `rtk init -g` must run AFTER the settings.json merge, or the merge (which is
#    repo-authoritative for the hooks map) clobbers the RTK PreToolUse hook every
#    sync.
#  - the installer must be downloaded to a file before running, not piped
#    straight to `sh` — `curl | sh` reports the shell's exit status, not curl's
#    (no pipefail), so a failed download would look like a successful install.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/helpers.sh"
INSTALL="$HERE/../install.sh"

# R1: -R flag is parsed and disables RTK.
test_skip_flag() {
  if grep -q 'R) RTK=false' "$INSTALL"; then
    _pass "R1: -R flag sets RTK=false"
  else
    _fail "R1: -R flag does not disable RTK"
  fi
}

# R2: rtk init runs AFTER the settings.json merge (hook survives each sync).
test_init_after_merge() {
  local merge_line init_line
  merge_line=$(grep -n 'Merging claude/settings.json' "$INSTALL" | head -1 | cut -d: -f1)
  init_line=$(grep -n '"$rtk_bin" init -g' "$INSTALL" | head -1 | cut -d: -f1)
  if [[ -n "$merge_line" && -n "$init_line" && "$init_line" -gt "$merge_line" ]]; then
    _pass "R2: rtk init ($init_line) comes after settings merge ($merge_line)"
  else
    _fail "R2: rtk init must run after the settings merge (merge=$merge_line init=$init_line)"
  fi
}

# R3: installer is downloaded to a file, never piped straight to sh.
test_no_pipe_to_sh() {
  if grep -q 'curl -fsSL "$RTK_INSTALL_URL" -o "$rtk_installer"' "$INSTALL"; then
    _pass "R3: RTK installer downloaded to a file before running"
  else
    _fail "R3: RTK installer is not downloaded to a file first"
  fi
}

# R4: an already-installed rtk skips the binary download (idempotent).
test_idempotent_skip() {
  if grep -q 'RTK already installed' "$INSTALL"; then
    _pass "R4: existing rtk binary skips re-install"
  else
    _fail "R4: no idempotency skip for an existing rtk binary"
  fi
}

test_skip_flag
test_init_after_merge
test_no_pipe_to_sh
test_idempotent_skip
echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
