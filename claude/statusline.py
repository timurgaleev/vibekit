from __future__ import annotations

import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

def load_config() -> None:
    config_file = Path.home() / ".vibemon" / "config.json"
    if not config_file.exists():
        return

    try:
        with open(config_file) as f:
            config = json.load(f)
    except (json.JSONDecodeError, IOError):
        return

    key_mapping = {
        "debug": ("DEBUG", lambda v: "1" if v else "0"),
        "cache_path": ("VIBEMON_CACHE_PATH", str),
        "auto_launch": ("VIBEMON_AUTO_LAUNCH", lambda v: "1" if v else "0"),
        "http_urls": (
            "VIBEMON_HTTP_URLS",
            lambda v: ",".join(v) if isinstance(v, list) else str(v),
        ),
        "serial_port": ("VIBEMON_SERIAL_PORT", str),
        "vibemon_url": ("VIBEMON_URL", str),
        "vibemon_token": ("VIBEMON_TOKEN", str),
        "token_reset_hours": ("VIBEMON_TOKEN_RESET_HOURS", str),
    }

    for config_key, (env_key, converter) in key_mapping.items():
        if config_key in config and config[config_key] is not None:
            value = converter(config[config_key])
            if value:
                os.environ.setdefault(env_key, value)

load_config()

VIBE_MONITOR_MAX_PROJECTS = 10

TOKEN_RESET_HOURS = int(os.environ.get("VIBEMON_TOKEN_RESET_HOURS", "5") or "5")
TOKEN_RESET_MS = TOKEN_RESET_HOURS * 3600 * 1000

LOCK_TIMEOUT_SECONDS = 5
LOCK_RETRY_INTERVAL = 0.05

def read_input() -> str:
    return sys.stdin.read()

def parse_json(data: str) -> dict[str, Any]:
    try:
        return json.loads(data)
    except (json.JSONDecodeError, TypeError):
        return {}

BRANCH_EMOJIS = {
    "main": "🌿",
    "master": "🌿",
    "develop": "🌱",
    "development": "🌱",
    "dev": "🌱",
    "feature": "✨",
    "feat": "✨",
    "fix": "🐛",
    "bugfix": "🐛",
    "hotfix": "🔥",
    "release": "📦",
    "chore": "🧹",
    "refactor": "♻️",
    "docs": "📝",
    "doc": "📝",
    "test": "🧪",
    "experiment": "🧪",
    "exp": "🧪",
}

def get_branch_emoji(branch: str) -> str:
    if not branch:
        return "🌿"

    branch_lower = branch.lower()

    if branch_lower in BRANCH_EMOJIS:
        return BRANCH_EMOJIS[branch_lower]

    if "/" in branch_lower:
        prefix = branch_lower.split("/", 1)[0]
        if prefix in BRANCH_EMOJIS:
            return BRANCH_EMOJIS[prefix]

    return "🌿"

def get_git_root(directory: str) -> str | None:
    if not directory:
        return None
    try:
        result = subprocess.run(
            ["git", "-C", directory, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    return None

def get_project_name(directory: str) -> str:
    if not directory:
        return ""

    git_root = get_git_root(directory)
    if git_root:
        name = os.path.basename(git_root)
        if name:
            return name

    return os.path.basename(directory)

def get_git_info(directory: str) -> str:
    if not directory:
        return ""

    try:
        result = subprocess.run(
            [
                "git",
                "--no-optional-locks",
                "-C",
                directory,
                "status",
                "--porcelain=v1",
                "--branch",
            ],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode != 0:
            return ""

        lines = result.stdout.splitlines()
        if not lines:
            return ""

        header = lines[0]
        if not header.startswith("## "):
            return ""

        branch_part = header[3:]
        branch = branch_part.split("...")[0].split()[0]

        if not branch or branch == "HEAD":
            return ""

        has_changes = len(lines) > 1

        if has_changes:
            return f" git:({branch} *)"
        return f" git:({branch})"

    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ""

def get_context_usage(data: dict[str, Any]) -> str:
    context_window = data.get("context_window", {})
    if not isinstance(context_window, dict):
        return ""

    used_pct = context_window.get("used_percentage", 0)

    if used_pct and used_pct != "null":
        try:
            pct = float(used_pct)
            if pct > 0:
                return f"{int(pct)}%"
        except (ValueError, TypeError):
            pass

    try:
        context_size = int(context_window.get("context_window_size", 0) or 0)
        if context_size <= 0:
            return ""

        current_usage = context_window.get("current_usage", {})
        if not isinstance(current_usage, dict):
            return ""

        input_tokens = int(current_usage.get("input_tokens", 0) or 0)
        cache_creation = int(current_usage.get("cache_creation_input_tokens", 0) or 0)
        cache_read = int(current_usage.get("cache_read_input_tokens", 0) or 0)

        current_tokens = input_tokens + cache_creation + cache_read
        if current_tokens > 0:
            return f"{current_tokens * 100 // context_size}%"
    except (ValueError, TypeError):
        pass

    return ""

def get_cache_path() -> str:
    cache_path = os.environ.get(
        "VIBEMON_CACHE_PATH", "~/.vibemon/cache/statusline.json"
    )
    return os.path.expanduser(cache_path)

def save_to_cache(project: str, model: str, memory: int) -> None:
    if not project:
        return

    cache_path = get_cache_path()
    cache_dir = os.path.dirname(cache_path)

    os.makedirs(cache_dir, exist_ok=True)

    lockfile = f"{cache_path}.lock"
    timestamp = int(time.time())
    lock_fd = None

    try:
        lock_fd = os.open(lockfile, os.O_CREAT | os.O_WRONLY, 0o644)

        start_time = time.monotonic()
        while True:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except (IOError, OSError):
                if time.monotonic() - start_time > LOCK_TIMEOUT_SECONDS:
                    return
                time.sleep(LOCK_RETRY_INTERVAL)

        cache: dict[str, Any] = {}
        if os.path.exists(cache_path):
            try:
                with open(cache_path) as f:
                    cache = json.load(f)
            except (json.JSONDecodeError, IOError):
                cache = {}

        if project not in cache and len(cache) >= VIBE_MONITOR_MAX_PROJECTS:
            sorted_items = sorted(
                cache.items(),
                key=lambda x: x[1].get("ts", 0) if isinstance(x[1], dict) else 0,
                reverse=True,
            )
            cache = dict(sorted_items[: VIBE_MONITOR_MAX_PROJECTS - 1])

        cache[project] = {"model": model, "memory": memory, "ts": timestamp}

        tmpfile = f"{cache_path}.tmp.{os.getpid()}"
        with open(tmpfile, "w") as f:
            json.dump(cache, f)
        os.replace(tmpfile, cache_path)

    except (IOError, OSError):
        pass
    finally:
        if lock_fd is not None:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
                os.close(lock_fd)
            except OSError:
                pass

C_RESET = "\033[0m"
C_DIM = "\033[2m"
C_CYAN = "\033[36m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_RED = "\033[31m"
C_MAGENTA = "\033[35m"
C_BLUE = "\033[34m"
C_ORANGE = "\033[38;5;208m"

def format_number(num: int | float | str | None) -> str:
    if num is None or num == "null" or num == 0:
        return "0"

    try:
        num_float = float(num)
        int_num = int(num_float)

        if int_num >= 1_000_000:
            return f"{num_float / 1_000_000:.1f}M"
        if int_num >= 1_000:
            return f"{num_float / 1_000:.1f}K"
        return str(int_num)
    except (ValueError, TypeError):
        return "0"

def format_duration(ms: int | float | str | None) -> str:
    if ms is None or ms == "null" or ms == 0:
        return "0s"

    try:
        total_seconds = int(ms) // 1000
        hours, remainder = divmod(total_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)

        if hours > 0:
            return f"{hours}h{minutes}m"
        if minutes > 0:
            return f"{minutes}m{seconds}s"
        return f"{seconds}s"
    except (ValueError, TypeError):
        return "0s"

def format_cost(cost: float | str | None) -> str:
    if cost is None or cost == "null":
        return "$0.00"

    try:
        return f"${float(cost):.2f}"
    except (ValueError, TypeError):
        return "$0.00"

def get_token_window_path() -> str:
    cache_dir = os.path.dirname(get_cache_path())
    return os.path.join(cache_dir, "token_window.json")

def load_window_start() -> float | None:
    try:
        with open(get_token_window_path()) as f:
            data = json.load(f)
            return data.get("window_start")
    except (FileNotFoundError, json.JSONDecodeError, IOError):
        return None

def save_window_start(window_start: float) -> None:
    window_file = get_token_window_path()
    try:
        os.makedirs(os.path.dirname(window_file), exist_ok=True)
        tmpfile = f"{window_file}.tmp.{os.getpid()}"
        with open(tmpfile, "w") as f:
            json.dump({"window_start": window_start}, f)
        os.replace(tmpfile, window_file)
    except (IOError, OSError):
        pass

def get_token_reset_info(duration_ms: int | float | str | None) -> tuple[int, str]:
    if TOKEN_RESET_MS <= 0:
        return (0, "")

    if duration_ms is None or duration_ms == "null" or duration_ms == 0:
        return (0, "")

    try:
        now = time.time()
        token_reset_seconds = TOKEN_RESET_MS // 1000

        window_start = load_window_start()

        if window_start is not None:
            window_start = window_start - (window_start % 3600)

        if window_start is None or (now - window_start) >= token_reset_seconds:
            window_start = now - (now % 3600)
            save_window_start(window_start)

        remaining_seconds = int(token_reset_seconds - (now - window_start))

        if remaining_seconds <= 0:
            return (0, "")

        remaining_ms = remaining_seconds * 1000

        reset_timestamp = now + remaining_seconds
        reset_local = time.localtime(reset_timestamp)
        reset_time_str = time.strftime("%H:%M", reset_local)

        return (remaining_ms, reset_time_str)
    except (ValueError, TypeError):
        return (0, "")

def format_token_reset(remaining_ms: int, reset_time_str: str) -> str:
    if remaining_ms <= 0:
        return ""

    total_minutes = remaining_ms // 60000
    hours = total_minutes // 60
    minutes = total_minutes % 60

    if hours > 0:
        remaining_display = f"{hours}h{minutes}m"
    else:
        remaining_display = f"{minutes}m"

    if TOKEN_RESET_MS > 0:
        remaining_pct = remaining_ms * 100 // TOKEN_RESET_MS
    else:
        remaining_pct = 100

    if remaining_pct <= 10:
        color = C_RED
    elif remaining_pct <= 33:
        color = C_ORANGE
    else:
        color = C_DIM

    return f"{color}⏳ {remaining_display}{C_RESET}"

def build_progress_bar(percent_str: str | int | float, width: int = 10) -> str:
    cleaned = str(percent_str).rstrip("%").strip()

    if not cleaned:
        return ""

    try:
        percent = int(float(cleaned))
    except (ValueError, TypeError):
        return ""

    percent = max(0, min(100, percent))

    filled = percent * width // 100
    empty = width - filled

    if percent >= 90:
        color = C_RED
    elif percent >= 75:
        color = C_YELLOW
    else:
        color = C_GREEN

    filled_bar = "━" * filled
    empty_bar = "╌" * empty

    return f"{color}{filled_bar}{C_RESET}{C_DIM}{empty_bar}{C_RESET} {percent}%"

def build_statusline(
    model: str,
    dir_name: str,
    git_info: str,
    context_usage: str,
    input_tokens: int | str,
    output_tokens: int | str,
    cost: float | str,
    duration: int | str,
    lines_added: int | str,
    lines_removed: int | str,
    token_reset: str = "",
) -> str:
    SEP = " │ "
    parts: list[str] = []

    parts.append(f"{C_BLUE}📂 {dir_name}{C_RESET}")

    if git_info:
        branch_info = git_info.replace(" git:(", "").rstrip(")")
        branch_name = branch_info.rstrip(" *")
        emoji = get_branch_emoji(branch_name)
        parts.append(f"{C_GREEN}{emoji} {branch_info}{C_RESET}")

    short_model = model.removeprefix("Claude ")
    parts.append(f"{C_MAGENTA}🤖 {short_model}{C_RESET}")

    if input_tokens and str(input_tokens) != "0":
        in_fmt = format_number(input_tokens)
        out_fmt = format_number(output_tokens)
        parts.append(f"{C_CYAN}📥 {in_fmt} 📤 {out_fmt}{C_RESET}")

    if cost and str(cost) != "0" and cost != "null":
        cost_fmt = format_cost(cost)
        parts.append(f"{C_YELLOW}💰 {cost_fmt}{C_RESET}")

    if duration and str(duration) != "0" and duration != "null":
        duration_fmt = format_duration(duration)
        duration_part = f"{C_DIM}⏱️ {duration_fmt}{C_RESET}"
        if token_reset:
            duration_part += f" {token_reset}"
        parts.append(duration_part)

    if lines_added and str(lines_added) != "0":
        lines_part = f"{C_GREEN}+{lines_added}{C_RESET}"
        if lines_removed and str(lines_removed) != "0":
            lines_part += f" {C_RED}-{lines_removed}{C_RESET}"
        parts.append(lines_part)

    if context_usage:
        progress_bar = build_progress_bar(context_usage)
        if progress_bar:
            parts.append(f"🧠 {progress_bar}")

    return SEP.join(parts)

def save_cache_background(project: str, model: str, memory: int) -> None:
    if not hasattr(os, "fork"):
        save_to_cache(project, model, memory)
        return

    try:
        pid = os.fork()
        if pid == 0:
            try:
                save_to_cache(project, model, memory)
            except Exception:
                pass
            os._exit(0)
    except OSError:
        save_to_cache(project, model, memory)

def main() -> None:
    entrypoint = os.environ.get("CLAUDE_CODE_ENTRYPOINT", "cli")
    if entrypoint == "local-agent" or os.environ.get("STATUSLINE_DISABLED") == "1":
        return

    input_raw = read_input()

    data = parse_json(input_raw)

    model_data = data.get("model", {})
    model_display = (
        model_data.get("display_name", "Claude")
        if isinstance(model_data, dict)
        else "Claude"
    )

    workspace_data = data.get("workspace", {})
    current_dir = (
        workspace_data.get("current_dir", "")
        if isinstance(workspace_data, dict)
        else ""
    )
    dir_name = get_project_name(current_dir) if current_dir else ""

    git_info = get_git_info(current_dir)
    context_usage = get_context_usage(data)

    context_window = data.get("context_window", {})
    if isinstance(context_window, dict):
        input_tokens = context_window.get("total_input_tokens", 0)
        output_tokens = context_window.get("total_output_tokens", 0)
    else:
        input_tokens = output_tokens = 0

    cost_data = data.get("cost", {})
    if isinstance(cost_data, dict):
        cost = cost_data.get("total_cost_usd", 0)
        duration = cost_data.get("total_duration_ms", 0)
        lines_added = cost_data.get("total_lines_added", 0)
        lines_removed = cost_data.get("total_lines_removed", 0)
    else:
        cost = duration = lines_added = lines_removed = 0

    remaining_ms, reset_time_str = get_token_reset_info(duration)
    token_reset = format_token_reset(remaining_ms, reset_time_str)

    memory_int = int(context_usage.rstrip("%")) if context_usage else 0
    save_cache_background(dir_name, model_display, memory_int)

    print(
        build_statusline(
            model_display,
            dir_name,
            git_info,
            context_usage,
            input_tokens,
            output_tokens,
            cost,
            duration,
            lines_added,
            lines_removed,
            token_reset,
        ),
        end="",
    )

if __name__ == "__main__":
    main()
