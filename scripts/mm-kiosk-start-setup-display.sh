#!/usr/bin/env bash
# Shows the setup QR page fullscreen until the kazernescherm is configured.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

WEB_PORT="$(json_value web_port 2>/dev/null || echo "80")"
SETUP_URL="http://127.0.0.1:${WEB_PORT}/display"

CHROMIUM="$(detect_chromium_binary || true)"
if [[ -z "${CHROMIUM}" ]]; then
    log "Chromium/Chrome niet gevonden voor setup-scherm."
    exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
KIOSK_USER="${MM_KIOSK_USER:-$(logname 2>/dev/null || echo kiosk)}"

for _ in $(seq 1 45); do
    if sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xdpyinfo >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

log "Setup-scherm starten op ${SETUP_URL}."

if command -v xset >/dev/null 2>&1; then
    sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xset s off || true
    sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xset s noblank || true
    sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xset -dpms || true
    sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xset dpms 0 0 0 || true
fi

while true; do
    sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" "${CHROMIUM}" \
        --kiosk \
        --no-first-run \
        --no-default-browser-check \
        --noerrdialogs \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --disable-features=TranslateUI \
        --autoplay-policy=no-user-gesture-required \
        --check-for-update-interval=31536000 \
        "${SETUP_URL}"

    log "Setup-scherm afgesloten; over 5 seconden opnieuw starten."
    sleep 5
done
