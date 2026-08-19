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
AUTOSTART_WRAPPER="${TARGET_DIR}/scripts/mm-kiosk-autostart.sh"

install -d /etc/meldingsmonitor-kiosk
echo "${PRIMARY_USER}" > /etc/meldingsmonitor-kiosk/primary-user

touch /var/log/mm-kiosk-browser.log
chown "${PRIMARY_USER}:${PRIMARY_USER}" /var/log/mm-kiosk-browser.log

bash "${SCRIPT_DIR}/mm-kiosk-disable-keyring.sh" "${PRIMARY_USER}"

if is_pi_desktop; then
    bash "${SCRIPT_DIR}/mm-kiosk-configure-labwc-cursor.sh" "${PRIMARY_USER}"
fi

bash "${SCRIPT_DIR}/mm-kiosk-set-wallpaper.sh" "${PRIMARY_USER}"

mkdir -p "${USER_HOME}/.config/autostart" "${USER_HOME}/.config/systemd/user"

cat > "${USER_HOME}/.config/autostart/mm-kiosk-browser.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MeldingsMonitor Kazernescherm
Exec=/bin/bash -lc 'sleep 3; exec ${AUTOSTART_WRAPPER}'
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF

cat > "${USER_HOME}/.config/systemd/user/mm-kiosk-browser.service" <<EOF
[Unit]
Description=MeldingsMonitor kazernescherm
After=network-online.target graphical-session.target
Wants=network-online.target

[Service]
Type=simple
Environment=XDG_RUNTIME_DIR=/run/user/${USER_ID}
ExecStartPre=/bin/sleep 5
ExecStart=${AUTOSTART_WRAPPER}
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

if is_pi_desktop; then
    for dir in \
        "${USER_HOME}/.config/labwc/autostart" \
        "/etc/xdg/labwc/autostart"; do
        mkdir -p "${dir}"
        cat > "${dir}/20-mm-kiosk-browser" <<EOF
#!/bin/sh
sleep 3
exec ${AUTOSTART_WRAPPER}
EOF
        chmod 0755 "${dir}/20-mm-kiosk-browser"
        rm -f "${dir}/mm-kiosk-browser" 2>/dev/null || true
        if [[ "${dir}" == "${USER_HOME}"* ]]; then
            chown -R "${PRIMARY_USER}:${PRIMARY_USER}" "$(dirname "${dir}")"
        fi
    done

    LXSESSION_DIR="${USER_HOME}/.config/lxsession/LXDE-pi"
    mkdir -p "${LXSESSION_DIR}"
    LXSESSION_FILE="${LXSESSION_DIR}/autostart"

    if [[ -d "${LXSESSION_FILE}" ]]; then
        rm -rf "${LXSESSION_FILE}"
    fi

    if [[ -f "${LXSESSION_FILE}" ]] && ! grep -q 'mm-kiosk-autostart.sh' "${LXSESSION_FILE}"; then
        echo "@${AUTOSTART_WRAPPER}" >> "${LXSESSION_FILE}"
    elif [[ ! -e "${LXSESSION_FILE}" ]]; then
        echo "@${AUTOSTART_WRAPPER}" > "${LXSESSION_FILE}"
    fi

    rm -rf "${LXSESSION_DIR}/autostart/mm-kiosk-browser" 2>/dev/null || true
else
    cat > "${USER_HOME}/.config/systemd/user/mm-kiosk-browser.service" <<EOF
[Unit]
Description=MeldingsMonitor kazernescherm
After=network-online.target graphical-session.target
Wants=network-online.target

[Service]
Type=simple
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/${USER_ID}
ExecStartPre=/bin/sleep 8
ExecStart=${AUTOSTART_WRAPPER}
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
fi

loginctl enable-linger "${PRIMARY_USER}" 2>/dev/null || true

if [[ -d "/run/user/${USER_ID}" ]]; then
    sudo -u "${PRIMARY_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        systemctl --user daemon-reload 2>/dev/null || true
    sudo -u "${PRIMARY_USER}" \
        XDG_RUNTIME_DIR="/run/user/${USER_ID}" \
        systemctl --user enable --now mm-kiosk-browser.service 2>/dev/null || true
fi

chown -R "${PRIMARY_USER}:${PRIMARY_USER}" "${USER_HOME}/.config"

log "Kiosk-opstart geconfigureerd voor gebruiker ${PRIMARY_USER}."
