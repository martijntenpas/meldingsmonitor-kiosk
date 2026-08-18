#!/usr/bin/env bash
# Connects the device to a WiFi network using NetworkManager when available.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

SSID="${1:-}"
PASSWORD="${2:-}"

if [[ -z "${SSID}" ]]; then
    echo "Usage: $0 <ssid> [password]" >&2
    exit 1
fi

WLAN="$(detect_wlan_interface || true)"
if [[ -z "${WLAN}" ]]; then
    log "Geen WiFi-interface gevonden."
    exit 1
fi

"${SCRIPT_DIR}/mm-kiosk-stop-ap.sh" || true

if ! command -v nmcli >/dev/null 2>&1; then
    log "NetworkManager (nmcli) is vereist voor WiFi-koppeling."
    exit 1
fi

nmcli radio wifi on || true
nmcli device set "${WLAN}" managed yes || true

CONNECTION_NAME="mm-kiosk-${SSID}"

if [[ -n "${PASSWORD}" ]]; then
    nmcli connection delete "${CONNECTION_NAME}" >/dev/null 2>&1 || true
    nmcli device wifi connect "${SSID}" password "${PASSWORD}" ifname "${WLAN}" name "${CONNECTION_NAME}"
else
    nmcli connection delete "${CONNECTION_NAME}" >/dev/null 2>&1 || true
    nmcli device wifi connect "${SSID}" ifname "${WLAN}" name "${CONNECTION_NAME}"
fi

for _ in $(seq 1 20); do
    if nmcli -t -f DEVICE,STATE device status | grep -q "^${WLAN}:connected"; then
        log "WiFi verbonden met ${SSID}."
        exit 0
    fi
    sleep 1
done

log "WiFi-koppeling mislukt voor ${SSID}."
exit 1
