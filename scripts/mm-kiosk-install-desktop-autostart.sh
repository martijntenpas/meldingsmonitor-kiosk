#!/usr/bin/env bash
# Installeert browser-autostart voor Pi-desktop (labwc/LXDE) als fallback.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_USER="${1:-}"
KIOSK_ROOT="/opt/meldingsmonitor-kiosk"
LAUNCHER="${KIOSK_ROOT}/scripts/mm-kiosk-launch-browser.sh"

if [[ -z "${TARGET_USER}" ]]; then
    TARGET_USER="$(who | awk 'NR==1 {print $1}')"
fi

if [[ -z "${TARGET_USER}" ]] || ! id "${TARGET_USER}" >/dev/null 2>&1; then
    echo "Geen geldige gebruiker opgegeven." >&2
    exit 1
fi

USER_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
DESKTOP_FILE="${USER_HOME}/.config/autostart/mm-kiosk-browser.desktop"

mkdir -p "${USER_HOME}/.config/autostart"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=MeldingsMonitor Kazernescherm
Exec=${LAUNCHER}
X-GNOME-Autostart-enabled=true
EOF

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}/.config/autostart"

for dir in \
    "${USER_HOME}/.config/labwc/autostart" \
    "/etc/xdg/labwc/autostart" \
    "${USER_HOME}/.config/lxsession/LXDE-pi/autostart" \
    "/etc/xdg/lxsession/LXDE-pi/autostart"; do
    if [[ -d "$(dirname "${dir}")" ]] || [[ "${dir}" == /etc/xdg/* ]]; then
        mkdir -p "${dir}"
        cat > "${dir}/mm-kiosk-browser" <<EOF
#!/bin/sh
${LAUNCHER} &
EOF
        chmod 0755 "${dir}/mm-kiosk-browser"
        if [[ "${dir}" == "${USER_HOME}"* ]]; then
            chown -R "${TARGET_USER}:${TARGET_USER}" "$(dirname "${dir}")"
        fi
    fi
done

log "Desktop-autostart geinstalleerd voor ${TARGET_USER}."
