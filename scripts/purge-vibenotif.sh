#!/usr/bin/env bash
# Removes VibeNotif and VibeMon from this machine.
#
# Surgical by design: it deletes only files this project installed and only
# hook entries whose command points at vibenotif.py / vibemon.py. Every other
# hook (rtk, caveman, impeccable, anything else) is preserved, and no hooks
# directory or shared config file is ever deleted as a whole.
#
#   bash purge-vibenotif.sh          # show what would happen, change nothing
#   APPLY=1 bash purge-vibenotif.sh  # do it
#
# Backups of every edited or deleted config land in
# ~/.vibekit-purge-backup-<timestamp>. Re-running is safe.
set -uo pipefail

APPLY=${APPLY:-0}
[[ "$APPLY" == 1 ]] && MODE="APPLY" || MODE="DRY-RUN"

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="${PURGE_BACKUP_DIR:-$HOME/.vibekit-purge-backup-$STAMP}"
FAILED=0

say()  { echo "  $*"; }
todo() { echo "  [would] $*"; }
err()  { echo "  ОШИБКА: $*" >&2; FAILED=1; }

command -v python3 >/dev/null 2>&1 || { echo "нужен python3" >&2; exit 2; }

echo "== VibeNotif / VibeMon purge — $MODE =="
echo

# Physical-path guard: a lexical "$HOME/..." check cannot see a symlinked path
# component, so resolve both sides before deleting anything.
under_home() {
  APPLY=0 python3 - "$1" <<'PY'
import os, sys
target = os.path.realpath(os.path.expanduser(sys.argv[1]))
home = os.path.realpath(os.path.expanduser("~"))
sys.exit(0 if target != home and (target + os.sep).startswith(home + os.sep) else 1)
PY
}

backup_of() {
  local src="$1"
  [[ "$APPLY" == 1 ]] || return 0
  mkdir -p "$BACKUP" || return 1
  # Flatten the path so ~/.claude/settings.json and ~/.cursor/settings.json
  # cannot overwrite one another in the backup directory.
  local flat="${src#$HOME/}"
  cp -p "$src" "$BACKUP/${flat//\//_}"
}

rm_path() {
  local p="$1" what="${2:-}"
  # -e is false for a dangling symlink, which would otherwise survive the purge.
  [[ -e "$p" || -L "$p" ]] || return 0
  if ! under_home "$p"; then
    err "ПРОПУСК, путь ведёт за пределы \$HOME: $p"
    return 1
  fi
  if [[ "$APPLY" != 1 ]]; then
    todo "удалить $p${what:+ ($what)}"
    return 0
  fi
  if rm -rf "$p"; then
    say "удалён $p${what:+ ($what)}"
  else
    err "не удалось удалить $p"
    return 1
  fi
}

# --- 1. hook entries in shared JSON configs ----------------------------------
# Matching is by hook command, resolved to a basename of vibenotif.py or
# vibemon.py. A substring match on "vibemon" would also hit an unrelated
# "vibemonitor" hook or a description that merely mentions the product.
clean_json() {
  local file="$1" kind="$2"
  if [[ ! -f "$file" ]]; then say "нет файла: $file"; return 0; fi
  local out rc
  out=$(APPLY="$APPLY" python3 - "$file" "$kind" <<'PY'
import json, os, re, sys

path, kind = sys.argv[1], sys.argv[2]
apply_ = os.environ.get("APPLY") == "1"
OWNED = ("vibenotif.py", "vibemon.py")
KIRO_KNOWN_DESC = "Default agent with VibeNotif hooks"

try:
    with open(path) as f:
        data = json.load(f)
except (OSError, ValueError) as exc:
    print(f"НЕЧИТАЕМЫЙ JSON: {path}: {exc}")
    sys.exit(3)

if not isinstance(data, dict):
    print(f"НЕОЖИДАННАЯ СТРУКТУРА (ожидался объект): {path}")
    sys.exit(3)

def owned(entry):
    """True only when a hook's own command/args name one of our scripts."""
    if not isinstance(entry, dict):
        return False
    words = []
    cmd = entry.get("command")
    if isinstance(cmd, str):
        words += re.split(r"[\s'\"]+", cmd)
    args = entry.get("args")
    if isinstance(args, list):
        words += [a for a in args if isinstance(a, str)]
    for w in words:
        if os.path.basename(w.strip().rstrip("'\"")) in OWNED:
            return True
    return False

removed = []

def clean(evmap, nested):
    """nested=True  -> Claude: event -> [ {hooks:[...]}, ... ]
       nested=False -> Cursor/Kiro: event -> [ hook, ... ]"""
    if not isinstance(evmap, dict):
        return
    for event in list(evmap):
        groups = evmap[event]
        if not isinstance(groups, list):
            continue
        kept_groups, touched = [], False
        for g in groups:
            if nested and isinstance(g, dict) and isinstance(g.get("hooks"), list):
                kept = [h for h in g["hooks"] if not owned(h)]
                dropped = len(g["hooks"]) - len(kept)
                if dropped:
                    touched = True
                    removed.append(f"{event}: убрано записей — {dropped}")
                    # An emptied group is ours to drop; a group that was already
                    # empty belongs to someone else and stays as it was.
                    if not kept:
                        continue
                    g = dict(g, hooks=kept)
                kept_groups.append(g)
            else:
                if owned(g):
                    touched = True
                    removed.append(f"{event}: убрана запись")
                else:
                    kept_groups.append(g)
        if kept_groups:
            evmap[event] = kept_groups
        elif touched:
            del evmap[event]
            removed.append(f"{event}: событие опустело и убрано")

hooks = data.get("hooks")
if kind == "claude":
    clean(hooks, nested=True)
    if isinstance(hooks, dict) and not hooks:
        del data["hooks"]
elif kind == "cursor":
    clean(hooks, nested=False)          # key kept, Cursor expects it present
elif kind == "kiro":
    clean(hooks, nested=False)
    if isinstance(hooks, dict) and not hooks:
        del data["hooks"]
    desc = data.get("description")
    if isinstance(desc, str) and desc == KIRO_KNOWN_DESC:
        data["description"] = "Default agent"
        removed.append("description: приведено к «Default agent»")
    elif isinstance(desc, str) and re.search(r"vibenotif|vibemon", desc, re.I):
        print(f"ВНИМАНИЕ: описание изменено вручную, правь сам: {desc!r}")

if not removed:
    print(f"чисто, менять нечего: {path}")
    sys.exit(0)

print(f"{path}")
for r in removed:
    print(f"  - {r}")

if apply_:
    import shutil, tempfile
    backup = os.environ.get("BACKUP_DIR")
    if backup:
        os.makedirs(backup, exist_ok=True)
        flat = os.path.relpath(path, os.path.expanduser("~")).replace(os.sep, "_")
        shutil.copy2(path, os.path.join(backup, flat))
    d = os.path.dirname(path) or "."
    # mkstemp: exclusive create in the same directory, so a planted symlink at a
    # predictable .tmp path cannot redirect the write.
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".purge-", suffix=".json")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        shutil.copymode(path, tmp)      # a 0600 settings file stays 0600
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    print("  записано" + (f", бэкап в {backup}" if backup else ""))
else:
    print("  [would] переписать файл, бэкап рядом")
PY
  ) ; rc=$?
  printf '%s\n' "$out" | sed 's/^/  /'
  if [[ $rc -ne 0 ]]; then
    err "правка $file не выполнена (код $rc)"
    return 1
  fi
  return 0
}

echo "1. Записи хуков в общих конфигах (чужие хуки сохраняются):"
export BACKUP_DIR="$BACKUP"
clean_json "$HOME/.claude/settings.json"      claude
clean_json "$HOME/.cursor/hooks.json"         cursor
clean_json "$HOME/.kiro/agents/default.json"  kiro
echo

# Fail closed: leaving a hook registration behind while deleting the script it
# points at is worse than doing nothing, so stop before any file is removed.
if [[ "$FAILED" == 1 ]]; then
  echo "ОСТАНОВЛЕНО: конфиги не приведены в порядок, файлы не трогаю." >&2
  echo "Почини JSON вручную и запусти снова." >&2
  exit 1
fi

# --- 2. our own files ---------------------------------------------------------
echo "2. Файлы скриптов (каталоги hooks не трогаем):"
for f in \
  "$HOME/.claude/hooks/vibenotif.py" \
  "$HOME/.claude/hooks/vibemon.py" \
  "$HOME/.cursor/hooks/vibenotif.py" \
  "$HOME/.cursor/hooks/vibemon.py" \
  "$HOME/.kiro/hooks/vibenotif.py" \
  "$HOME/.kiro/hooks/vibemon.py"
do
  rm_path "$f"
done
echo

# --- 3. state directory -------------------------------------------------------
echo "3. Каталог состояния ~/.vibenotif:"
BACKUP_OK=1
CFG="$HOME/.vibenotif/config.json"
if [[ -f "$CFG" ]]; then
  if grep -q '"vibenotif_token"' "$CFG" 2>/dev/null; then
    echo "  ВНИМАНИЕ: в конфиге есть vibenotif_token — отзови его на стороне сервиса."
  fi
  backup_of "$CFG" || { BACKUP_OK=0; err "не удалось сохранить бэкап $CFG"; }
fi
if [[ -d "$HOME/.vibenotif" ]]; then
  # The status line kept its token-window timestamp in here. Carry it over
  # instead of resetting the user's 5-hour window to zero.
  OLD_WIN="$HOME/.vibenotif/cache/token_window.json"
  NEW_WIN="${CLAUDE_STATUSLINE_STATE_DIR:-$HOME/.claude/statusline}/token_window.json"
  if [[ -f "$OLD_WIN" ]]; then
    if [[ "$APPLY" == 1 ]]; then
      mkdir -p "$(dirname "$NEW_WIN")" 2>/dev/null
      if [[ -f "$NEW_WIN" ]]; then
        say "состояние таймера уже перенесено"
      elif cp -p "$OLD_WIN" "$NEW_WIN"; then
        say "состояние таймера перенесено в $NEW_WIN"
      else
        err "не удалось перенести состояние таймера"
      fi
    else
      todo "перенести состояние таймера в $NEW_WIN"
    fi
  fi
  if [[ "$BACKUP_OK" != 1 ]]; then
    err "бэкап конфига не сделан — каталог ~/.vibenotif оставлен нетронутым"
  else
    rm_path "$HOME/.vibenotif" "конфиг, кэш и остальное состояние"
  fi
else
  say "нет каталога"
fi
for lock in "${TMPDIR:-/tmp}"/vibenotif*.lock "${TMPDIR:-/tmp}"/vibenotif*.debounce; do
  [[ -e "$lock" ]] || continue
  if [[ "$APPLY" == 1 ]]; then rm -f "$lock" && say "удалён $lock"; else todo "удалить $lock"; fi
done
echo

# --- 4. environment file ------------------------------------------------------
echo "4. Переменные VIBENOTIF_* в ~/.claude/.env.local:"
ENVF="$HOME/.claude/.env.local"
if [[ -f "$ENVF" ]] && grep -qE '^[[:space:]]*#?[[:space:]]*VIBENOTIF_' "$ENVF"; then
  n=$(grep -cE '^[[:space:]]*#?[[:space:]]*VIBENOTIF_' "$ENVF")
  if [[ "$APPLY" == 1 ]]; then
    backup_of "$ENVF" || err "не удалось сохранить бэкап $ENVF"
    tmp="$(mktemp "$(dirname "$ENVF")/.purge-env.XXXXXX")" || tmp=""
    if [[ -n "$tmp" ]] && grep -vE '^[[:space:]]*#?[[:space:]]*VIBENOTIF_' "$ENVF" > "$tmp"; then
      chmod "$(stat -f %Lp "$ENVF" 2>/dev/null || echo 600)" "$tmp" 2>/dev/null
      mv "$tmp" "$ENVF" && say "убрано строк: $n"
    else
      [[ -n "$tmp" ]] && rm -f "$tmp"
      err "не удалось почистить $ENVF"
    fi
  else
    todo "убрать строк: $n из $ENVF"
  fi
else
  say "нечего убирать"
fi
echo

# --- 5. VibeMon desktop app ---------------------------------------------------
# PURGE_SKIP_SYSTEM=1 keeps this section out of automated tests: everything below
# reaches outside the sandboxed HOME (launchd, the process table, /tmp).
if [[ "${PURGE_SKIP_SYSTEM:-0}" == 1 ]]; then
  echo "5. Приложение VibeMon: пропущено (PURGE_SKIP_SYSTEM=1)"
  echo
  if [[ "$FAILED" == 1 ]]; then
    echo "== завершено с ошибками ($MODE) =="
    exit 1
  fi
  echo "== готово ($MODE) =="
  exit 0
fi
echo "5. Приложение VibeMon:"
PLIST="$HOME/Library/LaunchAgents/com.vibemon.autostart.plist"
LABEL="com.vibemon.autostart"
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || [[ -f "$PLIST" ]]; then
  if [[ "$APPLY" == 1 ]]; then
    # Unconditional: a KeepAlive job can still be loaded after its plist is gone,
    # and a surviving job would relaunch the app right after we kill it.
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null ||
      launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
      err "служба $LABEL всё ещё загружена — сними её вручную"
    else
      say "автозапуск снят, plist удалён"
    fi
  else
    todo "снять службу $LABEL и удалить $PLIST"
  fi
else
  say "автозапуска нет"
fi

# Narrow on purpose: `pkill -f vibemon` would also match this script, an editor
# with the word open, or any shell whose command line mentions it.
PIDS=()
while IFS= read -r _pid; do
  [[ -n "$_pid" ]] && PIDS+=("$_pid")
done < <(pgrep -f "node_modules/vibemon|vibemon@latest|Application Support/vibemon" 2>/dev/null || true)
if [[ ${#PIDS[@]} -gt 0 ]]; then
  if [[ "$APPLY" == 1 ]]; then
    kill "${PIDS[@]}" 2>/dev/null || true
    say "остановлено процессов: ${#PIDS[@]}"
  else
    todo "остановить процессы: ${PIDS[*]}"
  fi
else
  say "процесс не запущен"
fi

for d in "$HOME"/.npm/_npx/*/node_modules/vibemon; do
  [[ -e "$d" ]] || continue
  # Remove the whole npx env, not just the package: the bundled Electron in the
  # sibling directories is the part that actually takes up space.
  rm_path "${d%/node_modules/vibemon}" "npx-окружение vibemon"
done
rm_path "$HOME/Library/Application Support/vibemon" "данные приложения"
rm_path "$HOME/.config/vibemon" "данные приложения"
echo

if [[ "$FAILED" == 1 ]]; then
  echo "== завершено с ошибками ($MODE) — разбери сообщения выше =="
  exit 1
fi
echo "== готово ($MODE) =="
[[ "$APPLY" == 1 ]] || echo "Ничего не изменено. Для применения: APPLY=1 bash $0"
