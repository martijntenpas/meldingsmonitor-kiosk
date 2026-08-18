#!/usr/bin/env bash
# Launches Chromium in kiosk mode for the configured kazernescherm URL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

if [[ ! -f "${MM_KIOSK_CONFIG}" ]]; then
    log "Config ontbreekt: ${MM_KIOSK_CONFIG}"
    exit 1
fi

HOMEPAGE="$(json_value homepage || true)"
if [[ -z "${HOMEPAGE}" ]]; then
    log "Geen homepage geconfigureerd."
    exit 1
fi

CHROMIUM="$(detect_chromium_binary || true)"
if [[ -z "${CHROMIUM}" ]]; then
    log "Chromium/Chrome niet gevonden."
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

log "Kiosk starten voor ${HOMEPAGE} als ${KIOSK_USER}."

if command -v xset >/dev/null 2>&1; then
    sudo -u "${KIOSK_USER}" xset s off || true
    sudo -u "${KIOSK_USER}" xset -dpms || true
    sudo -u "${KIOSK_USER}" xset s noblank || true
fi

while true; do
    sudo -u "${KIOSK_USER}" "${CHROMIUM}" \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --autoplay-policy=no-user-gesture-required \
        --check-for-update-interval=31536000 \
        "${HOMEPAGE}"

    log "Browser afgesloten; over 5 seconden opnieuw starten."
    sleep 5
done
