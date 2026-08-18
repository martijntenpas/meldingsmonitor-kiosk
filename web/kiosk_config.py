"""Shared kiosk configuration helpers."""

from __future__ import annotations

import json
import socket
from pathlib import Path

PLACEHOLDER_MARKERS = (
    "VUL_ACCESS_KEY_IN",
    "YOUR_",
    "CHANGE_ME",
    "example.com",
)


def is_homepage_configured(homepage: str | None) -> bool:
    value = (homepage or "").strip()

    if not value.startswith("https://"):
        return False

    if "kazernescherm" not in value and "meldingsmonitor" not in value:
        return False

    upper = value.upper()
    for marker in PLACEHOLDER_MARKERS:
        if marker.upper() in upper:
            return False

    return True


def load_default_config(example_path: Path) -> dict:
    return json.loads(example_path.read_text(encoding="utf-8"))


def detect_local_ip() -> str:
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        probe.connect(("10.255.255.255", 1))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def build_setup_url(
    *,
    web_port: int,
    setup_ap_ip: str,
    ap_active: bool,
    local_ip: str | None = None,
) -> str:
    host = setup_ap_ip if ap_active else (local_ip or detect_local_ip())

    if web_port == 80:
        return f"http://{host}"

    return f"http://{host}:{web_port}"


def is_setup_needed(config: dict, *, online: bool) -> bool:
    if bool(config.get("force_setup")):
        return True

    if not bool(config.get("setup_completed")):
        return True

    if not is_homepage_configured(config.get("homepage")):
        return True

    if not online:
        return True

    return False
