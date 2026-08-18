#!/usr/bin/env bash
# Shared helpers for MeldingsMonitor station-screen kiosk tooling.

set -euo pipefail

MM_KIOSK_CONFIG="${MM_KIOSK_CONFIG:-/etc/meldingsmonitor-kiosk/config.json}"
MM_KIOSK_STATE_DIR="${MM_KIOSK_STATE_DIR:-/run/mm-kiosk}"
MM_KIOSK_LOG="${MM_KIOSK_LOG:-/var/log/mm-kiosk.log}"

log() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] ${message}" | tee -a "${MM_KIOSK_LOG}"
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Dit script moet als root worden uitgevoerd." >&2
        exit 1
    fi
}

json_value() {
    local key="$1"
    python3 - <<PY
import json
import sys

path = "${MM_KIOSK_CONFIG}"
key = "${key}"

try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except FileNotFoundError:
    sys.exit(1)

value = data.get(key)
if value is None:
    sys.exit(1)

if isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (int, float)):
    print(value)
else:
    print(value)
PY
}

write_json_config() {
    local payload="$1"
    python3 - <<PY
import json
import os

path = "${MM_KIOSK_CONFIG}"
payload = json.loads("""${payload}""")

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=4)
    handle.write("\n")
PY
}

detect_wlan_interface() {
    if [[ -n "${MM_KIOSK_WLAN:-}" ]]; then
        echo "${MM_KIOSK_WLAN}"
        return 0
    fi

    local iface
    iface="$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2 == "wifi" { print $1; exit }')"

    if [[ -n "${iface}" ]]; then
        echo "${iface}"
        return 0
    fi

    for candidate in wlan0 wlp2s0 wlp3s0 wlxc0; do
        if [[ -d "/sys/class/net/${candidate}" ]]; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

detect_chromium_binary() {
    local candidate
    for candidate in chromium-browser chromium google-chrome stable-chromium; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            command -v "${candidate}"
            return 0
        fi
    done

    return 1
}

is_raspberry_pi() {
    if [[ -f /proc/device-tree/model ]] && grep -qi raspberry /proc/device-tree/model; then
        return 0
    fi

    return 1
}

ensure_state_dir() {
    mkdir -p "${MM_KIOSK_STATE_DIR}"
}
