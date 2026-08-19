#!/usr/bin/env bash
# Verbergt de muiscursor op Pi OS Desktop (labwc / Wayland).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_USER="${1:-$(detect_primary_user || true)}"

if [[ -z "${TARGET_USER}" ]] || ! id "${TARGET_USER}" >/dev/null 2>&1; then
    exit 0
fi

if ! is_pi_desktop || ! command -v labwc >/dev/null 2>&1; then
    exit 0
fi

USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
LABWC_DIR="${USER_HOME}/.config/labwc"
RC_FILE="${LABWC_DIR}/rc.xml"
AUTOSTART_DIR="${LABWC_DIR}/autostart"

mkdir -p "${LABWC_DIR}" "${AUTOSTART_DIR}"

if [[ ! -f "${RC_FILE}" ]]; then
    if [[ -f /etc/xdg/labwc/rc.xml ]]; then
        cp /etc/xdg/labwc/rc.xml "${RC_FILE}"
    else
        log "Geen labwc rc.xml gevonden; cursor-hide overgeslagen."
        exit 0
    fi
fi

if ! grep -q 'name="HideCursor"' "${RC_FILE}"; then
    sed -i.bak '/<keyboard>/a\
    <keybind key="A-W-h">\
      <action name="HideCursor" />\
      <action name="WarpCursor" x="-1" y="-1" />\
    </keybind>' "${RC_FILE}"
fi

cat > "${AUTOSTART_DIR}/mm-kiosk-hide-cursor" <<'EOF'
#!/bin/sh
sleep 4
if command -v wtype >/dev/null 2>&1; then
    wtype -M alt -M logo h -m alt -m logo 2>/dev/null || true
fi
if command -v unclutter >/dev/null 2>&1; then
    DISPLAY="${DISPLAY:-:0}" unclutter -idle 0 -root -noevents &
fi
EOF

chmod 0755 "${AUTOSTART_DIR}/mm-kiosk-hide-cursor"
chown -R "${TARGET_USER}:${TARGET_USER}" "${LABWC_DIR}"

log "Labwc cursor-hide geconfigureerd voor ${TARGET_USER}."
