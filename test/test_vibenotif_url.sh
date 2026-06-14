#!/bin/bash
# Validates is_valid_http_url in the VibeNotif hooks: only http/https targets
# are accepted, so the status payload and bearer token never go to a non-http
# scheme. Runs against both the Claude and Cursor copies of the hook.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/helpers.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "  skip: python3 not available"
  echo "----"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 0
fi

check_hook() {
  local hook="$1" name="$2"
  if [[ ! -f "$hook" ]]; then _fail "$name (hook missing: $hook)"; return; fi
  if python3 - "$hook" <<'PY'
import importlib.util, sys

spec = importlib.util.spec_from_file_location("vibenotif_hook", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
sys.modules["vibenotif_hook"] = mod  # dataclass resolution needs the module registered
spec.loader.exec_module(mod)

ok = [
    mod.is_valid_http_url("http://127.0.0.1:19280"),
    mod.is_valid_http_url("https://example.com"),
]
bad = [
    mod.is_valid_http_url("ftp://example.com"),
    mod.is_valid_http_url("file:///etc/passwd"),
    mod.is_valid_http_url("javascript:alert(1)"),
    mod.is_valid_http_url(""),
    mod.is_valid_http_url(None),
]
sys.exit(0 if all(ok) and not any(bad) else 1)
PY
  then _pass "$name"; else _fail "$name (scheme validation wrong)"; fi
}

check_hook "$HERE/../claude/hooks/vibenotif.py" "U1: claude hook accepts http(s), rejects others"
check_hook "$HERE/../cursor/hooks/vibenotif.py" "U2: cursor hook accepts http(s), rejects others"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
