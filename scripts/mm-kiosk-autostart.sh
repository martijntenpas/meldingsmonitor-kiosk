#!/usr/bin/env bash
# Wrapper zodat Chromium maar één keer start (labwc, autostart, systemd).

set -uo pipefail

LAUNCHER="${MM_KIOSK_ROOT:-/opt/meldingsmonitor-kiosk}/scripts/mm-kiosk-launch-browser.sh"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -d "${RUNTIME_DIR}" ]]; then
    LOCK_FILE="${RUNTIME_DIR}/mm-kiosk-browser.lock"
else
    LOCK_FILE="${HOME}/.cache/mm-kiosk-browser.lock"
    mkdir -p "$(dirname "${LOCK_FILE}")"
fi

export XDG_RUNTIME_DIR="${RUNTIME_DIR}"

if ! command -v flock >/dev/null 2>&1; then
    exec "${LAUNCHER}"
fi

exec 9>"${LOCK_FILE}" || exec "${LAUNCHER}"

if ! flock -n 9; then
    exit 0
fi

exec "${LAUNCHER}"
