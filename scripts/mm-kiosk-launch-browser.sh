#!/usr/bin/env bash
# Starts Chromium in kiosk mode inside the openbox user session.

set -euo pipefail

KIOSK_ROOT="${MM_KIOSK_ROOT:-/opt/meldingsmonitor-kiosk}"
CONFIG="${MM_KIOSK_CONFIG:-/etc/meldingsmonitor-kiosk/config.json}"
WEB_DIR="${KIOSK_ROOT}/web"
LOG_FILE="${MM_KIOSK_BROWSER_LOG:-/var/log/mm-kiosk-browser.log}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

exec >> "${LOG_FILE}" 2>&1

log_line() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_line "Browser-opstart gestart (user=$(whoami), pid=$$)."

export GNOME_KEYRING_CONTROL=""
export SECRET_SERVICE_BUS_NAME=""

if [[ -S "${RUNTIME_DIR}/wayland-0" ]]; then
    export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    unset DISPLAY
    log_line "Wayland-sessie gedetecteerd (${WAYLAND_DISPLAY})."
elif [[ -z "${DISPLAY:-}" ]]; then
    export DISPLAY=:0
    log_line "X11-sessie gebruikt (${DISPLAY})."
fi

if [[ ! -f "${CONFIG}" ]]; then
    log_line "Config ontbreekt: ${CONFIG}"
    exit 0
fi

CHROMIUM="$(command -v chromium-browser 2>/dev/null || command -v chromium 2>/dev/null || true)"
if [[ -z "${CHROMIUM}" ]]; then
    log_line "Chromium niet gevonden."
    exit 1
fi

WEB_PORT="$(python3 - <<PY
import json
with open("${CONFIG}", encoding="utf-8") as handle:
    print(json.load(handle).get("web_port", 80))
PY
)"

for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:${WEB_PORT}/api/health" >/dev/null 2>&1; then
        log_line "Provisioning-server bereikbaar op poort ${WEB_PORT}."
        break
    fi
    sleep 1
done

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

log_line "Open URL: ${TARGET_URL}"

if command -v xset >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
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
        --password-store=basic
        --use-mock-keychain
    )

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        CHROMIUM_ARGS+=(--ozone-platform=wayland)
    fi

    log_line "Chromium starten..."
    "${CHROMIUM}" "${CHROMIUM_ARGS[@]}" "${TARGET_URL}" || log_line "Chromium afgesloten met foutcode $?."
    sleep 5
done
