#!/usr/bin/env bash
# Configureert browser-autostart voor de primaire gebruiker (Pi desktop én Lite).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

TARGET_DIR="/opt/meldingsmonitor-kiosk"
PRIMARY_USER="${1:-}"

if [[ -z "${PRIMARY_USER}" ]]; then
    PRIMARY_USER="$(detect_primary_user || true)"
fi

if [[ -z "${PRIMARY_USER}" ]] || ! id "${PRIMARY_USER}" >/dev/null 2>&1; then
    echo "Geen geldige gebruiker gevonden voor kiosk-autostart." >&2
    exit 1
fi

USER_HOME="$(getent passwd "${PRIMARY_USER}" | cut -d: -f6)"
USER_ID="$(id -u "${PRIMARY_USER}")"
LAUNCHER="${TARGET_DIR}/scripts/mm-kiosk-launch-browser.sh"

install -d /etc/meldingsmonitor-kiosk
echo "${PRIMARY_USER}" > /etc/meldingsmonitor-kiosk/primary-user

mkdir -p "${USER_HOME}/.config/systemd/user"
cat > "${USER_HOME}/.config/systemd/user/mm-kiosk-browser.service" <<EOF
[Unit]
Description=MeldingsMonitor kazernescherm
After=network-online.target graphical-session.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 8
ExecStart=${LAUNCHER}
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

mkdir -p "${USER_HOME}/.config/autostart"
cat > "${USER_HOME}/.config/autostart/mm-kiosk-browser.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MeldingsMonitor Kazernescherm
Exec=${LAUNCHER}
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF

for dir in \
    "${USER_HOME}/.config/labwc/autostart" \
    "${USER_HOME}/.config/lxsession/LXDE-pi/autostart"; do
    mkdir -p "${dir}"
    cat > "${dir}/mm-kiosk-browser" <<EOF
#!/bin/sh
${LAUNCHER} &
EOF
    chmod 0755 "${dir}/mm-kiosk-browser"
done

chown -R "${PRIMARY_USER}:${PRIMARY_USER}" "${USER_HOME}/.config"

loginctl enable-linger "${PRIMARY_USER}" 2>/dev/null || true

if [[ -d "/run/user/${USER_ID}" ]]; then
    sudo -u "${PRIMARY_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "${PRIMARY_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        systemctl --user enable mm-kiosk-browser.service 2>/dev/null || true
fi

log "Kiosk-opstart geconfigureerd voor gebruiker ${PRIMARY_USER}."
