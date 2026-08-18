#!/usr/bin/env bash
# Starts Chromium in kiosk mode inside the openbox user session.

set -euo pipefail

KIOSK_ROOT="${MM_KIOSK_ROOT:-/opt/meldingsmonitor-kiosk}"
CONFIG="${MM_KIOSK_CONFIG:-/etc/meldingsmonitor-kiosk/config.json}"
WEB_DIR="${KIOSK_ROOT}/web"

export DISPLAY="${DISPLAY:-:0}"

if [[ ! -f "${CONFIG}" ]]; then
    exit 0
fi

CHROMIUM="$(command -v chromium-browser 2>/dev/null || command -v chromium 2>/dev/null || true)"
if [[ -z "${CHROMIUM}" ]]; then
    echo "Chromium niet gevonden." >&2
    exit 1
fi

TARGET_URL="$(python3 - <<PY
import json
import sys
import urllib.request

sys.path.insert(0, "${WEB_DIR}")
from kiosk_config import is_homepage_configured, is_setup_needed

with open("${CONFIG}", encoding="utf-8") as handle:
    config = json.load(handle)

web_port = int(config.get("web_port", 80))
online = False

try:
    with urllib.request.urlopen(f"http://127.0.0.1:{web_port}/api/health", timeout=2) as response:
        online = response.status == 200
except OSError:
    online = False

if is_setup_needed(config, online=online) or not is_homepage_configured(config.get("homepage")):
    print(f"http://127.0.0.1:{web_port}/display")
else:
    print(config.get("homepage", f"http://127.0.0.1:{web_port}/display"))
PY
)"

if command -v xset >/dev/null 2>&1; then
    xset s off || true
    xset s noblank || true
    xset -dpms || true
    xset dpms 0 0 0 || true
fi

while true; do
    CHROMIUM_ARGS=(
        --kiosk
        --no-first-run
        --no-default-browser-check
        --noerrdialogs
        --disable-infobars
        --disable-session-crashed-bubble
        --disable-restore-session-state
        --disable-features=TranslateUI
        --autoplay-policy=no-user-gesture-required
        --check-for-update-interval=31536000
    )

    if [[ -n "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
        CHROMIUM_ARGS+=(--ozone-platform=wayland)
    fi

    "${CHROMIUM}" "${CHROMIUM_ARGS[@]}" "${TARGET_URL}"

    sleep 5
done
