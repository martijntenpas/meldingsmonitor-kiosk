#!/usr/bin/env bash
# Stops the temporary setup access point.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

for pid_file in hostapd dnsmasq; do
    if [[ -f "${MM_KIOSK_STATE_DIR}/${pid_file}.pid" ]]; then
        kill "$(cat "${MM_KIOSK_STATE_DIR}/${pid_file}.pid")" 2>/dev/null || true
        rm -f "${MM_KIOSK_STATE_DIR}/${pid_file}.pid"
    fi
done

WLAN="$(detect_wlan_interface || true)"
if [[ -n "${WLAN}" ]] && command -v nmcli >/dev/null 2>&1; then
    nmcli device set "${WLAN}" managed yes || true
fi

log "Setup access point gestopt."
rm -f "${MM_KIOSK_STATE_DIR}/setup-ssid" 2>/dev/null || true
