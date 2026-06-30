#!/bin/bash
# Behavior tests for purge_vibemon (lib/vibemon.sh).
# Each test runs in an isolated fake HOME so real user data is never touched.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/helpers.sh"
LIB="$HERE/../lib/vibemon.sh"

# B1: an npx cache for vibemon is removed.
test_removes_npx_cache() {
  local HOME; HOME="$(make_sandbox)"
  local cache="$HOME/.npm/_npx/abc123/node_modules/vibemon"
  mkdir -p "$cache"

  PREVIEW_ONLY=false
  source "$LIB"
  purge_vibemon

  assert_absent "$HOME/.npm/_npx/abc123" "B1: npx cache hashdir removed"
  rm -rf "$HOME"
}

# B2: app data dirs are removed (macOS + Linux locations).
test_removes_app_data() {
  local HOME; HOME="$(make_sandbox)"
  mkdir -p "$HOME/Library/Application Support/vibemon"
  mkdir -p "$HOME/.config/vibemon"

  PREVIEW_ONLY=false
  source "$LIB"
  purge_vibemon

  assert_absent "$HOME/Library/Application Support/vibemon" "B2: macOS app data removed"
  assert_absent "$HOME/.config/vibemon" "B2: Linux app data removed"
  rm -rf "$HOME"
}

# B3: preview mode changes nothing on disk.
test_preview_deletes_nothing() {
  local HOME; HOME="$(make_sandbox)"
  local cache="$HOME/.npm/_npx/abc123/node_modules/vibemon"
  mkdir -p "$cache"
  mkdir -p "$HOME/Library/Application Support/vibemon"

  PREVIEW_ONLY=true
  source "$LIB"
  purge_vibemon

  assert_present "$HOME/.npm/_npx/abc123" "B3: npx cache survives preview"
  assert_present "$HOME/Library/Application Support/vibemon" "B3: app data survives preview"
  rm -rf "$HOME"
}

# B4: no artifacts present -> still succeeds (exit 0), deletes nothing.
test_graceful_when_empty() {
  local HOME; HOME="$(make_sandbox)"  # empty sandbox

  PREVIEW_ONLY=false
  source "$LIB"
  if purge_vibemon; then _pass "B4: exit 0 on empty"; else _fail "B4: non-zero exit on empty"; fi
  rm -rf "$HOME"
}

# B5: multiple npx hashdirs containing vibemon -> all removed.
test_removes_multiple_hashdirs() {
  local HOME; HOME="$(make_sandbox)"
  mkdir -p "$HOME/.npm/_npx/aaa/node_modules/vibemon"
  mkdir -p "$HOME/.npm/_npx/bbb/node_modules/vibemon"
  mkdir -p "$HOME/.npm/_npx/ccc/node_modules/other"  # unrelated, must stay

  PREVIEW_ONLY=false
  source "$LIB"
  purge_vibemon

  assert_absent "$HOME/.npm/_npx/aaa" "B5: first vibemon hashdir removed"
  assert_absent "$HOME/.npm/_npx/bbb" "B5: second vibemon hashdir removed"
  assert_present "$HOME/.npm/_npx/ccc" "B5: unrelated hashdir preserved"
  rm -rf "$HOME"
}

# B6: the self-installed LaunchAgent plist is removed (real culprit behind
# the app relaunching after auto_launch is disabled).
test_removes_launchagent() {
  local HOME; HOME="$(make_sandbox)"
  local plist="$HOME/Library/LaunchAgents/com.vibemon.autostart.plist"
  mkdir -p "$(dirname "$plist")"
  : > "$plist"

  PREVIEW_ONLY=false
  source "$LIB"
  purge_vibemon

  assert_absent "$plist" "B6: LaunchAgent plist removed"
  rm -rf "$HOME"
}

# B7: preview mode leaves the LaunchAgent plist in place.
test_preview_keeps_launchagent() {
  local HOME; HOME="$(make_sandbox)"
  local plist="$HOME/Library/LaunchAgents/com.vibemon.autostart.plist"
  mkdir -p "$(dirname "$plist")"
  : > "$plist"

  PREVIEW_ONLY=true
  source "$LIB"
  purge_vibemon

  assert_present "$plist" "B7: LaunchAgent survives preview"
  rm -rf "$HOME"
}

test_removes_npx_cache
test_removes_app_data
test_preview_deletes_nothing
test_graceful_when_empty
test_removes_multiple_hashdirs
test_removes_launchagent
test_preview_keeps_launchagent
echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
