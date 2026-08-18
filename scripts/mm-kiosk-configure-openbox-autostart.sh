#!/usr/bin/env bash
# Installeert openbox-autostart zodat Chromium in de gebruikerssessie start.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

KIOSK_USER="${MM_KIOSK_USER:-kiosk}"
KIOSK_HOME="$(getent passwd "${KIOSK_USER}" | cut -d: -f6)"
LAUNCHER="${SCRIPT_DIR}/mm-kiosk-launch-browser.sh"

if [[ ! -x "${LAUNCHER}" ]]; then
    chmod 0755 "${LAUNCHER}"
fi

mkdir -p /etc/xdg/openbox
cat > /etc/xdg/openbox/autostart <<EOF
#!/bin/sh
xset s off
xset s noblank
xset -dpms
xset dpms 0 0 0
unclutter -idle 0 &
${LAUNCHER} &
EOF
chmod 0755 /etc/xdg/openbox/autostart

if [[ -n "${KIOSK_HOME}" ]]; then
    mkdir -p "${KIOSK_HOME}/.config/openbox"
    cp /etc/xdg/openbox/autostart "${KIOSK_HOME}/.config/openbox/autostart"
    chown -R "${KIOSK_USER}:${KIOSK_USER}" "${KIOSK_HOME}/.config"
fi

log "Openbox-autostart geconfigureerd voor ${KIOSK_USER}."
