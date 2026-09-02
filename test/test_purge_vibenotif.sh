#!/bin/bash
# Tests for scripts/purge-vibenotif.sh against a sandboxed HOME.
#
# The script edits shared config files that other tools also write to, so the
# cases that matter are the ones proving it leaves foreign hooks alone and
# refuses to act on a file it cannot parse.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/helpers.sh"

PURGE="$HERE/../scripts/purge-vibenotif.sh"

fixture() {
  local home="$1"
  mkdir -p "$home/.claude/hooks" "$home/.cursor/hooks" "$home/.kiro/hooks" \
           "$home/.kiro/agents" "$home/.vibenotif/cache"

  cat > "$home/.claude/settings.json" <<'JSON'
{
  "permissions": { "allow": ["Bash(*)"] },
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "python3 ~/.claude/hooks/vibenotif.py" } ] } ],
    "PreToolUse": [ { "hooks": [
      { "type": "command", "command": "python3 ~/.claude/hooks/vibenotif.py" },
      { "type": "command", "command": "rtk hook claude" }
    ] } ],
    "Stop": [ { "hooks": [ { "type": "command", "command": "node ~/.claude/hooks/vibemonitor-dashboard.js" } ] } ]
  }
}
JSON

  cat > "$home/.cursor/hooks.json" <<'JSON'
{
  "version": 1,
  "hooks": {
    "sessionStart": [ { "command": "python3 ~/.cursor/hooks/vibenotif.py", "timeout": 10 } ],
    "preToolUse": [
      { "command": "python3 ~/.cursor/hooks/vibenotif.py", "timeout": 10 },
      { "command": "node '/x/.cursor/skills/impeccable/scripts/hook-before-edit.mjs'", "timeout": 5 }
    ]
  }
}
JSON

  cat > "$home/.kiro/agents/default.json" <<'JSON'
{
  "name": "default",
  "description": "Default agent with VibeNotif hooks",
  "hooks": {
    "agentSpawn": [ { "command": "python3", "args": ["~/.kiro/hooks/vibenotif.py", "agentSpawn"] } ],
    "stop": [ { "command": "bash", "args": ["~/.kiro/hooks/other.sh"] } ]
  }
}
JSON

  echo "x" > "$home/.claude/hooks/vibenotif.py"
  echo "x" > "$home/.claude/hooks/caveman-activate.js"
  echo "x" > "$home/.cursor/hooks/vibenotif.py"
  echo "x" > "$home/.kiro/hooks/vibenotif.py"
  echo '{"auto_launch": false}' > "$home/.vibenotif/config.json"
  echo '{"window_start": 1756000000.0}' > "$home/.vibenotif/cache/token_window.json"
  printf 'VIBENOTIF_TOKEN=abc\nOTHER=1\n' > "$home/.claude/.env.local"
}

jq_get() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps(d))" "$1"; }

# --- P1: dry-run changes nothing ---------------------------------------------
SB="$(make_sandbox)"; fixture "$SB"
before="$(find "$SB" -type f -exec md5 -q {} \; 2>/dev/null | sort | md5 -q)"
HOME="$SB" PURGE_SKIP_SYSTEM=1 bash "$PURGE" >/dev/null 2>&1
after="$(find "$SB" -type f -exec md5 -q {} \; 2>/dev/null | sort | md5 -q)"
if [[ "$before" == "$after" ]]; then
  echo "PASS P1: dry-run ничего не меняет"
else
  echo "FAIL P1: dry-run изменил файлы"; FAILED=1
fi

# --- P2: apply removes ours, keeps foreign hooks ------------------------------
SB="$(make_sandbox)"; fixture "$SB"
HOME="$SB" APPLY=1 PURGE_SKIP_SYSTEM=1 PURGE_BACKUP_DIR="$SB/backup" bash "$PURGE" >/dev/null 2>&1

claude_json="$(jq_get "$SB/.claude/settings.json")"
case "$claude_json" in
  *vibenotif.py*) echo "FAIL P2a: хук vibenotif остался в settings.json"; FAILED=1 ;;
  *) echo "PASS P2a: хук vibenotif убран из settings.json" ;;
esac
case "$claude_json" in
  *"rtk hook claude"*) echo "PASS P2b: чужой хук rtk сохранён" ;;
  *) echo "FAIL P2b: чужой хук rtk потерян"; FAILED=1 ;;
esac
case "$claude_json" in
  *vibemonitor-dashboard*) echo "PASS P2c: посторонний vibemonitor-* не тронут" ;;
  *) echo "FAIL P2c: удалён чужой хук с похожим именем"; FAILED=1 ;;
esac
case "$claude_json" in
  *SessionStart*) echo "FAIL P2d: пустое событие SessionStart осталось"; FAILED=1 ;;
  *) echo "PASS P2d: опустевшее событие убрано" ;;
esac

cursor_json="$(jq_get "$SB/.cursor/hooks.json")"
case "$cursor_json" in
  *impeccable*) echo "PASS P2e: чужой хук impeccable сохранён" ;;
  *) echo "FAIL P2e: чужой хук impeccable потерян"; FAILED=1 ;;
esac
case "$cursor_json" in
  *vibenotif*) echo "FAIL P2f: хук vibenotif остался в hooks.json"; FAILED=1 ;;
  *) echo "PASS P2f: хук vibenotif убран из hooks.json" ;;
esac

kiro_json="$(jq_get "$SB/.kiro/agents/default.json")"
case "$kiro_json" in
  *other.sh*) echo "PASS P2g: чужой хук Kiro сохранён" ;;
  *) echo "FAIL P2g: чужой хук Kiro потерян"; FAILED=1 ;;
esac
case "$kiro_json" in
  *VibeNotif*) echo "FAIL P2h: описание Kiro не приведено в порядок"; FAILED=1 ;;
  *) echo "PASS P2h: описание Kiro приведено в порядок" ;;
esac

[[ -f "$SB/.claude/hooks/caveman-activate.js" ]] \
  && echo "PASS P2i: соседний файл Caveman не тронут" \
  || { echo "FAIL P2i: удалён посторонний файл в hooks/"; FAILED=1; }
[[ -d "$SB/.claude/hooks" ]] \
  && echo "PASS P2j: каталог hooks на месте" \
  || { echo "FAIL P2j: удалён каталог hooks"; FAILED=1; }
[[ ! -f "$SB/.claude/hooks/vibenotif.py" && ! -d "$SB/.vibenotif" ]] \
  && echo "PASS P2k: наши файлы и каталог состояния удалены" \
  || { echo "FAIL P2k: наши артефакты остались"; FAILED=1; }
grep -q VIBENOTIF_ "$SB/.claude/.env.local" \
  && { echo "FAIL P2l: переменные VIBENOTIF_ остались"; FAILED=1; } \
  || echo "PASS P2l: переменные VIBENOTIF_ убраны"
grep -q "OTHER=1" "$SB/.claude/.env.local" \
  && echo "PASS P2m: посторонние переменные сохранены" \
  || { echo "FAIL P2m: посторонние переменные потеряны"; FAILED=1; }
[[ -f "$SB/backup/.claude_settings.json" || -n "$(ls "$SB/backup" 2>/dev/null)" ]] \
  && echo "PASS P2n: бэкапы созданы" \
  || { echo "FAIL P2n: бэкапов нет"; FAILED=1; }

# --- P2o: statusline token window is migrated, not lost ---------------------
if [[ -f "$SB/.claude/statusline/token_window.json" ]]; then
  echo "PASS P2o: состояние таймера перенесено"
else
  echo "FAIL P2o: состояние таймера потеряно"; FAILED=1
fi

# --- P3: idempotent -----------------------------------------------------------
snapshot_before="$(jq_get "$SB/.claude/settings.json")"
HOME="$SB" APPLY=1 PURGE_SKIP_SYSTEM=1 PURGE_BACKUP_DIR="$SB/backup2" bash "$PURGE" >/dev/null 2>&1
rc=$?
snapshot_after="$(jq_get "$SB/.claude/settings.json")"
if [[ $rc -eq 0 && "$snapshot_before" == "$snapshot_after" ]]; then
  echo "PASS P3: повторный запуск безопасен и ничего не меняет"
else
  echo "FAIL P3: повторный запуск изменил состояние или упал (rc=$rc)"; FAILED=1
fi

# --- P4: malformed JSON aborts before deleting files --------------------------
SB="$(make_sandbox)"; fixture "$SB"
echo '{ broken json' > "$SB/.claude/settings.json"
HOME="$SB" APPLY=1 PURGE_SKIP_SYSTEM=1 PURGE_BACKUP_DIR="$SB/backup" bash "$PURGE" >/dev/null 2>&1
rc=$?
if [[ $rc -ne 0 && -f "$SB/.claude/hooks/vibenotif.py" ]]; then
  echo "PASS P4: битый JSON останавливает скрипт до удаления файлов"
else
  echo "FAIL P4: скрипт продолжил работу при битом JSON (rc=$rc)"; FAILED=1
fi

# --- P5: custom Kiro description is left for a human --------------------------
SB="$(make_sandbox)"; fixture "$SB"
python3 - "$SB/.kiro/agents/default.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["description"] = "My agent, used to talk to VibeNotif, KEEPME note"
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
HOME="$SB" APPLY=1 PURGE_SKIP_SYSTEM=1 PURGE_BACKUP_DIR="$SB/backup" bash "$PURGE" >/dev/null 2>&1
if grep -q "KEEPME" "$SB/.kiro/agents/default.json"; then
  echo "PASS P5: правленое вручную описание сохранено"
else
  echo "FAIL P5: перезаписано пользовательское описание"; FAILED=1
fi

exit "${FAILED:-0}"
