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

HOMEPAGE="$(json_value homepage 2>/dev/null || true)"
if [[ -z "${HOMEPAGE}" ]]; then
    log "Geen homepage geconfigureerd."
    exit 1
fi

if ! python3 - <<PY
import sys
sys.path.insert(0, "${SCRIPT_DIR}/../web")
from kiosk_config import is_homepage_configured
sys.exit(0 if is_homepage_configured("""${HOMEPAGE}""") else 1)
PY
then
    log "Kazernescherm-URL is nog niet geldig geconfigureerd."
    exec "${SCRIPT_DIR}/mm-kiosk-start-setup-display.sh"
fi

CHROMIUM="$(detect_chromium_binary || true)"
if [[ -z "${CHROMIUM}" ]]; then
    log "Chromium/Chrome niet gevonden."
    exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
KIOSK_USER="${MM_KIOSK_USER:-kiosk}"

display_ready=0
for _ in $(seq 1 60); do
    if sudo -u "${KIOSK_USER}" DISPLAY="${DISPLAY}" xdpyinfo >/dev/null 2>&1; then
        display_ready=1
        break
    fi
    sleep 1
done

if [[ "${display_ready}" -eq 0 ]]; then
    log "Geen grafische sessie op ${DISPLAY} voor ${KIOSK_USER}. Controleer lightdm (sudo bash ${SCRIPT_DIR}/mm-kiosk-diagnose.sh)."
    exit 1
fi

log "Kiosk starten voor ${HOMEPAGE} als ${KIOSK_USER}."

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
        "${HOMEPAGE}"

    log "Browser afgesloten; over 5 seconden opnieuw starten."
    sleep 5
done
