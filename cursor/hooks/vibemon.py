from __future__ import annotations

import fcntl
import glob
import json
import os
import subprocess
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

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
        "auto_launch": ("VIBEMON_AUTO_LAUNCH", lambda v: "1" if v else "0"),
        "http_urls": (
            "VIBEMON_HTTP_URLS",
            lambda v: ",".join(v) if isinstance(v, list) else str(v),
        ),
        "serial_port": ("VIBEMON_SERIAL_PORT", str),
        "vibemon_url": ("VIBEMON_URL", str),
        "vibemon_token": ("VIBEMON_TOKEN", str),
    }

    for config_key, (env_key, converter) in key_mapping.items():
        if config_key in config and config[config_key] is not None:
            value = converter(config[config_key])
            if value:
                os.environ.setdefault(env_key, value)

load_config()

DEBUG = os.environ.get("DEBUG", "0") == "1"

ERR_NO_TARGET = '{"error":"No monitor target available. Set VIBEMON_HTTP_URLS or VIBEMON_SERIAL_PORT"}'
ERR_NO_ESP32 = '{"error":"No ESP32 target available. Set VIBEMON_HTTP_URLS (with ESP32 URL) or VIBEMON_SERIAL_PORT"}'
ERR_INVALID_MODE = (
    '{"error":"Invalid mode: %s. Valid modes: first-project, on-thinking"}'
)

VALID_LOCK_MODES = frozenset(["first-project", "on-thinking"])

SERIAL_DEBOUNCE_MS = 100
SERIAL_LOCK_MAX_RETRIES = 10
SERIAL_LOCK_RETRY_INTERVAL = 0.05
SERIAL_BAUD_RATE = "115200"

HTTP_TIMEOUT_SECONDS = 5

DESKTOP_LAUNCH_WAIT_SECONDS = 3

CHARACTER = "claw"

@dataclass(frozen=True)
class Config:

    http_urls: tuple[str, ...]
    serial_port: str | None
    auto_launch: bool
    vibemon_url: str | None
    vibemon_token: str | None

_config: Config | None = None

def parse_http_urls(urls_str: str | None) -> tuple[str, ...]:
    if not urls_str:
        return ()
    return tuple(url.strip() for url in urls_str.split(",") if url.strip())

def get_config() -> Config:
    global _config
    if _config is None:
        _config = Config(
            http_urls=parse_http_urls(os.environ.get("VIBEMON_HTTP_URLS")),
            serial_port=os.environ.get("VIBEMON_SERIAL_PORT"),
            auto_launch=os.environ.get("VIBEMON_AUTO_LAUNCH", "0") == "1",
            vibemon_url=os.environ.get("VIBEMON_URL"),
            vibemon_token=os.environ.get("VIBEMON_TOKEN"),
        )
    return _config

def debug_log(msg: str) -> None:
    if DEBUG:
        print(f"[DEBUG] {msg}", file=sys.stderr)

def resolve_serial_port(port_pattern: str | None) -> str | None:
    if not port_pattern:
        return None

    if "*" in port_pattern:
        matches = sorted(glob.glob(port_pattern))
        if matches:
            debug_log(f"Found serial ports: {matches}, using: {matches[0]}")
            return matches[0]
        debug_log(f"No serial port found matching: {port_pattern}")
        return None

    return port_pattern

def read_input() -> str:
    try:
        return sys.stdin.read()
    except Exception:
        return ""

def parse_json(data: str) -> dict[str, Any]:
    try:
        return json.loads(data)
    except (json.JSONDecodeError, TypeError):
        return {}

EVENT_STATE_MAP: dict[str, str] = {
    "agentSpawn": "start",
    "sessionStart": "start",
    "promptSubmit": "thinking",
    "userPromptSubmit": "thinking",
    "beforeSubmitPrompt": "thinking",
    "fileCreated": "working",
    "fileDeleted": "working",
    "fileEdited": "working",
    "preToolUse": "working",
    "preCompact": "packing",
    "agentStop": "done",
    "subagentStop": "done",
    "sessionEnd": "done",
    "stop": "done",
}

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

def get_project_name(cwd: str, transcript_path: str) -> str:
    if cwd:
        git_root = get_git_root(cwd)
        if git_root:
            name = os.path.basename(git_root)
            if name:
                return name

    if cwd:
        name = os.path.basename(cwd.rstrip("/"))
        if name:
            return name

    if transcript_path:
        name = os.path.basename(os.path.dirname(transcript_path))
        if name:
            return name

    name = os.path.basename(os.getcwd().rstrip("/"))
    return name if name else "default"

def get_state(event_name: str, permission_mode: str = "default") -> str:
    state = EVENT_STATE_MAP.get(event_name, "working")

    if permission_mode == "plan" and state in ("thinking", "working"):
        return "planning"

    return state

def get_terminal_id() -> str:
    iterm_session = os.environ.get("ITERM_SESSION_ID")
    if iterm_session:
        return f"iterm2:{iterm_session}"

    ghostty_pid = os.environ.get("GHOSTTY_PID")
    if ghostty_pid:
        return f"ghostty:{ghostty_pid}"

    return ""

def get_cursor_model() -> str:
    config_path = Path.home() / ".cursor" / "cli-config.json"
    try:
        with open(config_path) as f:
            config = json.load(f)
        return config.get("model", {}).get("displayNameShort", "")
    except (json.JSONDecodeError, IOError, KeyError):
        return ""

def build_payload(state: str, tool: str, project: str) -> dict[str, Any]:
    return {
        "state": state,
        "tool": tool,
        "project": project,
        "model": get_cursor_model(),
        "memory": 0,
        "character": CHARACTER,
        "terminalId": get_terminal_id(),
    }

def _get_serial_lock_path(port: str) -> str:
    return f"/tmp/vibemon-serial-{port.replace('/', '_')}.lock"

def _get_serial_debounce_path(port: str) -> str:
    return f"/tmp/vibemon-serial-{port.replace('/', '_')}.debounce"

def _get_serial_debounce_lock_path(port: str) -> str:
    return f"/tmp/vibemon-serial-{port.replace('/', '_')}.dlock"

def _acquire_lock(lock_fd: int, max_retries: int = SERIAL_LOCK_MAX_RETRIES) -> bool:
    for attempt in range(max_retries):
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            if attempt < max_retries - 1:
                time.sleep(SERIAL_LOCK_RETRY_INTERVAL)
    return False

def send_serial_raw(port: str, data: str) -> bool:
    if not os.path.exists(port):
        return False

    lock_path = _get_serial_lock_path(port)
    lock_fd = None

    try:
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR)

        if not _acquire_lock(lock_fd):
            debug_log(
                f"Failed to acquire serial lock after {SERIAL_LOCK_MAX_RETRIES} attempts"
            )
            return False

        try:
            flag = "-f" if sys.platform == "darwin" else "-F"
            subprocess.run(
                ["stty", flag, port, SERIAL_BAUD_RATE],
                check=False,
                capture_output=True,
            )

            with open(port, "w") as f:
                f.write(data + "\n")
                f.flush()

            time.sleep(SERIAL_LOCK_RETRY_INTERVAL)
            return True
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)

    except (IOError, OSError) as e:
        debug_log(f"Serial send error: {e}")
        return False
    finally:
        if lock_fd is not None:
            try:
                os.close(lock_fd)
            except OSError:
                pass

def send_serial(port: str, data: str) -> bool:
    if not os.path.exists(port):
        return False

    debounce_path = _get_serial_debounce_path(port)
    lock_path = _get_serial_debounce_lock_path(port)
    my_id = str(uuid.uuid4())

    lock_fd = None
    try:
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        try:
            with open(debounce_path, "w") as f:
                json.dump({"id": my_id, "data": data, "time": time.time()}, f)
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
            lock_fd = None

        time.sleep(SERIAL_DEBOUNCE_MS / 1000.0)

        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR)
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        try:
            with open(debounce_path) as f:
                state = json.load(f)

            if state["id"] != my_id:
                debug_log("Serial debounce: skipped (newer update exists)")
                return True

            debug_log("Serial debounce: sending (we have latest)")
            return send_serial_raw(port, state["data"])
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
            lock_fd = None

    except (IOError, OSError, json.JSONDecodeError) as e:
        debug_log(f"Serial debounce error: {e}, falling back to direct send")
        return send_serial_raw(port, data)
    finally:
        if lock_fd is not None:
            try:
                os.close(lock_fd)
            except OSError:
                pass

def send_http_post(
    url: str, endpoint: str, data: str | None = None
) -> tuple[bool, str | None]:
    try:
        full_url = f"{url}{endpoint}"
        if data:
            req = Request(
                full_url,
                data=data.encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
        else:
            req = Request(full_url, method="POST")

        with urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as response:
            return True, response.read().decode("utf-8")
    except (URLError, TimeoutError, OSError):
        return False, None

def send_http_get(url: str, endpoint: str) -> tuple[bool, str | None]:
    try:
        with urlopen(f"{url}{endpoint}", timeout=HTTP_TIMEOUT_SECONDS) as response:
            return True, response.read().decode("utf-8")
    except (URLError, TimeoutError, OSError):
        return False, None

def send_vibemon_api(url: str, token: str, payload: dict[str, Any]) -> bool:
    try:
        api_url = f"{url.rstrip('/')}/status"
        api_payload = json.dumps(
            {
                "state": payload.get("state", ""),
                "project": payload.get("project", ""),
                "tool": payload.get("tool", ""),
                "model": payload.get("model", ""),
                "memory": payload.get("memory", 0),
                "character": payload.get("character", CHARACTER),
            }
        )

        req = Request(
            api_url,
            data=api_payload.encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {token}",
            },
            method="POST",
        )

        with urlopen(req, timeout=HTTP_TIMEOUT_SECONDS) as response:
            debug_log(f"VibeMon API response: {response.status}")
            return response.status == 200
    except (URLError, TimeoutError, OSError) as e:
        debug_log(f"VibeMon API error: {e}")
        return False

def _send_http_request(
    url: str, endpoint: str, data: str | None, method: str
) -> tuple[bool, str | None]:
    if method == "POST":
        return send_http_post(url, endpoint, data)
    return send_http_get(url, endpoint)

def is_localhost_url(url: str) -> bool:
    return "127.0.0.1" in url or "localhost" in url

def try_http_targets(
    endpoint: str,
    data: str | None = None,
    method: str = "POST",
    include_localhost: bool = True,
) -> tuple[bool, str | None]:
    config = get_config()

    for url in config.http_urls:
        if not include_localhost and is_localhost_url(url):
            continue
        debug_log(f"Trying HTTP: {url}")
        success, result = _send_http_request(url, endpoint, data, method)
        if success:
            return True, result

    return False, None

def try_serial_target(command_data: str) -> tuple[bool, str | None]:
    config = get_config()

    if not config.serial_port:
        return False, None

    resolved_port = resolve_serial_port(config.serial_port)
    if not resolved_port:
        return False, None

    debug_log(f"Trying Serial: {resolved_port}")
    if send_serial(resolved_port, command_data):
        return True, resolved_port

    return False, None

def try_all_targets(
    endpoint: str,
    http_data: str | None,
    serial_command: str,
    include_localhost: bool = True,
) -> tuple[bool, str | None]:
    success, result = try_http_targets(endpoint, http_data, "POST", include_localhost)
    if success:
        return True, result

    success, _ = try_serial_target(serial_command)
    if success:
        return True, None

    return False, None

def _print_result(result: str | None, fallback: str) -> None:
    print(result if result else fallback)

def send_lock(project: str) -> bool:
    debug_log(f"Locking project: {project}")

    http_data = json.dumps({"project": project})
    serial_data = json.dumps({"command": "lock", "project": project})

    success, result = try_all_targets("/lock", http_data, serial_data)

    if success:
        _print_result(result, f'{{"success":true,"locked":"{project}"}}')
        return True

    debug_log("No monitor target available")
    print(ERR_NO_TARGET)
    return False

def send_unlock() -> bool:
    debug_log("Unlocking")

    serial_data = json.dumps({"command": "unlock"})
    success, result = try_all_targets("/unlock", None, serial_data)

    if success:
        _print_result(result, '{"success":true,"locked":null}')
        return True

    debug_log("No monitor target available")
    print(ERR_NO_TARGET)
    return False

def get_status() -> bool:
    success, result = try_http_targets("/status", method="GET")
    if success:
        print(result)
        return True

    serial_data = json.dumps({"command": "status"})
    success, _ = try_serial_target(serial_data)
    if success:
        print('{"info":"Status command sent via serial. Check device output."}')
        return True

    debug_log("No monitor target available")
    print(ERR_NO_TARGET)
    return False

def get_lock_mode() -> bool:
    success, result = try_http_targets("/lock-mode", method="GET")
    if success:
        print(result)
        return True

    serial_data = json.dumps({"command": "lock-mode"})
    success, _ = try_serial_target(serial_data)
    if success:
        print('{"info":"Lock-mode command sent via serial. Check device output."}')
        return True

    debug_log("No monitor target available")
    print(ERR_NO_TARGET)
    return False

def set_lock_mode(mode: str) -> bool:
    if mode not in VALID_LOCK_MODES:
        print(ERR_INVALID_MODE % mode)
        return False

    debug_log(f"Setting lock mode: {mode}")

    http_data = json.dumps({"mode": mode})
    serial_data = json.dumps({"command": "lock-mode", "mode": mode})

    success, result = try_all_targets("/lock-mode", http_data, serial_data)

    if success:
        _print_result(result, f'{{"success":true,"lockMode":"{mode}"}}')
        return True

    debug_log("No monitor target available")
    print(ERR_NO_TARGET)
    return False

def send_reboot() -> bool:
    debug_log("Rebooting ESP32")

    serial_data = json.dumps({"command": "reboot"})

    success, result = try_all_targets(
        "/reboot", None, serial_data, include_localhost=False
    )

    if success:
        _print_result(result, '{"success":true,"rebooting":true}')
        return True

    debug_log("No ESP32 target available")
    print(ERR_NO_ESP32)
    return False

def is_monitor_running(url: str) -> bool:
    success, _ = send_http_get(url, "/health")
    return success

def show_monitor_window(url: str) -> None:
    send_http_post(url, "/show")

def get_user_shell() -> str:
    shell = os.environ.get("SHELL")
    if shell:
        return shell

    try:
        import pwd

        return pwd.getpwuid(os.getuid()).pw_shell
    except Exception:
        pass

    return "/bin/sh"

def launch_desktop() -> None:
    debug_log("Launching Desktop App via npx")
    try:
        shell = get_user_shell()
        debug_log(f"Using shell: {shell}")
        subprocess.Popen(
            [shell, "-l", "-c", "npx vibemon@latest"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        time.sleep(DESKTOP_LAUNCH_WAIT_SECONDS)
    except Exception as e:
        debug_log(f"Failed to launch Desktop App: {e}")

def get_desktop_url(http_urls: tuple[str, ...]) -> str | None:
    for url in http_urls:
        if is_localhost_url(url):
            return url
    return None

def send_to_all(payload: dict[str, Any], is_start: bool = False) -> None:
    config = get_config()

    desktop_url = get_desktop_url(config.http_urls)
    if desktop_url and is_start and config.auto_launch:
        if not is_monitor_running(desktop_url):
            debug_log("Desktop App not running, launching...")
            launch_desktop()
        show_monitor_window(desktop_url)

    payload_str = json.dumps(payload)

    resolved_port: str | None = None
    if config.serial_port:
        resolved_port = resolve_serial_port(config.serial_port)
        if not resolved_port:
            debug_log(f"No serial port found for pattern: {config.serial_port}")

    tasks: list[tuple[str, Any]] = []

    for url in config.http_urls:
        u = url
        label = "Desktop App" if is_localhost_url(url) else f"HTTP ({url})"
        tasks.append((label, lambda u=u: send_http_post(u, "/status", payload_str)[0]))

    if resolved_port:
        port = resolved_port
        tasks.append(("USB serial", lambda p=port: send_serial(p, payload_str)))

    if config.vibemon_url and config.vibemon_token and payload.get("project"):
        tasks.append(
            (
                "VibeMon API",
                lambda: send_vibemon_api(
                    config.vibemon_url, config.vibemon_token, payload
                ),
            )
        )

    if not tasks:
        return

    with ThreadPoolExecutor(max_workers=len(tasks)) as executor:
        future_to_name = {executor.submit(task): name for name, task in tasks}
        for future in as_completed(future_to_name):
            name = future_to_name[future]
            try:
                success = future.result()
                debug_log(f"Sent to {name}" if success else f"{name} failed")
            except Exception as e:
                debug_log(f"{name} failed with error: {e}")

COMMAND_HANDLERS: dict[str, Any] = {
    "--lock": lambda args: send_lock(
        args[0] if args else os.path.basename(os.getcwd())
    ),
    "--unlock": lambda args: send_unlock(),
    "--status": lambda args: get_status(),
    "--lock-mode": lambda args: set_lock_mode(args[0]) if args else get_lock_mode(),
    "--reboot": lambda args: send_reboot(),
}

def handle_command(cmd: str, args: list[str]) -> bool | None:
    handler = COMMAND_HANDLERS.get(cmd)
    if handler:
        return handler(args)
    return None

def main() -> None:
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        args = sys.argv[2:]
        result = handle_command(cmd, args)
        if result is not None:
            sys.exit(0 if result else 1)

    input_raw = read_input()
    data = parse_json(input_raw)

    event_name = data.get("hook_event_name", "Unknown")
    tool_name = data.get("tool_name", "")
    workspace_roots = data.get("workspace_roots", [])
    cwd = workspace_roots[0] if workspace_roots else data.get("cwd", "")
    transcript_path = data.get("transcript_path", "")
    permission_mode = data.get("permission_mode", "default")

    project_name = get_project_name(cwd, transcript_path)
    state = get_state(event_name, permission_mode)

    debug_log(f"Event: {event_name}, Tool: {tool_name}, Project: {project_name}")

    payload = build_payload(state, tool_name, project_name)
    debug_log(f"Payload: {json.dumps(payload)}")

    is_start = event_name in ("promptSubmit", "sessionStart")
    send_to_all(payload, is_start)

if __name__ == "__main__":
    main()
    sys.exit(0)
