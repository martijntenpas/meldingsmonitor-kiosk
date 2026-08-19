#!/usr/bin/env bash
# Wrapper zodat Chromium maar één keer start (labwc, autostart, systemd).

set -euo pipefail

LAUNCHER="${MM_KIOSK_ROOT:-/opt/meldingsmonitor-kiosk}/scripts/mm-kiosk-launch-browser.sh"
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mm-kiosk-browser.lock"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
    exit 0
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

exec "${LAUNCHER}"
