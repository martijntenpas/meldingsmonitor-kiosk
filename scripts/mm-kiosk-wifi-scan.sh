#!/usr/bin/env bash
# Scans for nearby WiFi networks (requires NetworkManager).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

WLAN="$(detect_wlan_interface || true)"
if [[ -z "${WLAN}" ]]; then
    echo "[]"
    exit 0
fi

if ! command -v nmcli >/dev/null 2>&1; then
    echo "[]"
    exit 0
fi

"${SCRIPT_DIR}/mm-kiosk-stop-ap.sh" >/dev/null 2>&1 || true
nmcli radio wifi on >/dev/null 2>&1 || true
nmcli device set "${WLAN}" managed yes >/dev/null 2>&1 || true
nmcli device wifi rescan >/dev/null 2>&1 || true
sleep 2

python3 - <<'PY'
import json
import subprocess

result = subprocess.run(
    ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"],
    capture_output=True,
    text=True,
    check=False,
)

networks = []
seen = set()

for line in result.stdout.splitlines():
    parts = line.split(":")
    if len(parts) < 3:
        continue

    ssid = parts[0].strip()
    if not ssid or ssid in seen:
        continue

    seen.add(ssid)
    signal = int(parts[1] or 0)
    security = parts[2] or "OPEN"

    networks.append(
        {
            "ssid": ssid,
            "signal": signal,
            "secured": security not in ("", "--", "OPEN"),
        }
    )

networks.sort(key=lambda item: item["signal"], reverse=True)
print(json.dumps(networks, ensure_ascii=False))
PY
