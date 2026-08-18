#!/usr/bin/env bash
# Resets kiosk configuration and saved WiFi profiles to factory defaults.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

EXAMPLE_CONFIG="${SCRIPT_DIR}/../config/config.example.json"

if [[ ! -f "${EXAMPLE_CONFIG}" ]]; then
    log "Voorbeeldconfig ontbreekt: ${EXAMPLE_CONFIG}"
    exit 1
fi

log "Factory reset gestart."

install -d "$(dirname "${MM_KIOSK_CONFIG}")"
install -m 0644 "${EXAMPLE_CONFIG}" "${MM_KIOSK_CONFIG}"

if command -v nmcli >/dev/null 2>&1; then
    while IFS= read -r connection; do
        [[ -z "${connection}" ]] && continue
        nmcli connection delete "${connection}" >/dev/null 2>&1 || true
        log "WiFi-profiel verwijderd: ${connection}"
    done < <(nmcli -t -f NAME connection show | grep '^mm-kiosk-' || true)
fi

"${SCRIPT_DIR}/mm-kiosk-stop-ap.sh" || true

rm -f "${MM_KIOSK_STATE_DIR}/setup-ssid" 2>/dev/null || true

log "Factory reset afgerond."
