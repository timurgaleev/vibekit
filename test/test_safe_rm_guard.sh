#!/bin/bash
# Behavior tests for _safe_rm_rf (lib/vibemon.sh).
# Verifies the guarded delete refuses paths outside HOME and an empty HOME.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/helpers.sh"
LIB="$HERE/../lib/vibemon.sh"

# G1: deletes a path that lives under HOME.
test_deletes_under_home() {
  local HOME; HOME="$(make_sandbox)"
  local target="$HOME/.npm/_npx/abc/node_modules/vibemon"
  mkdir -p "$target"

  source "$LIB"
  _safe_rm_rf "$target"

  assert_absent "$target" "G1: path under HOME removed"
  rm -rf "$HOME"
}

# G2: refuses a path outside HOME and leaves it intact.
test_refuses_outside_home() {
  local HOME; HOME="$(make_sandbox)"
  local outside; outside="$(make_sandbox)/keep"
  mkdir -p "$outside"

  source "$LIB"
  if _safe_rm_rf "$outside"; then _fail "G2: returned success for outside path"; else _pass "G2: refused outside path"; fi
  assert_present "$outside" "G2: outside path preserved"
  rm -rf "$HOME" "$(dirname "$outside")"
}

# G3: refuses when HOME is empty.
test_refuses_empty_home() {
  local sandbox; sandbox="$(make_sandbox)"
  local target="$sandbox/data"
  mkdir -p "$target"

  source "$LIB"
  local HOME=""
  if _safe_rm_rf "$target"; then _fail "G3: returned success with empty HOME"; else _pass "G3: refused with empty HOME"; fi
  assert_present "$target" "G3: target preserved with empty HOME"
  rm -rf "$sandbox"
}

test_deletes_under_home
test_refuses_outside_home
test_refuses_empty_home
echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
