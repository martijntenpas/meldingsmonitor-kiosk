#!/usr/bin/env bash
# Herstelt lightdm + X11 zodat Chromium op het fysieke scherm kan starten.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

KIOSK_USER="${MM_KIOSK_USER:-kiosk}"

echo "==> MeldingsMonitor kiosk scherm herstellen"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    xserver-xorg \
    x11-xserver-utils \
    openbox \
    lightdm \
    unclutter \
    xauth \
    x11-utils

if grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
    apt-get install -y chromium-browser 2>/dev/null || apt-get install -y chromium
else
    apt-get install -y chromium 2>/dev/null || apt-get install -y chromium-browser
fi

if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${KIOSK_USER}"
fi

usermod -aG video,render,input,tty "${KIOSK_USER}" 2>/dev/null || true

mkdir -p /etc/lightdm/lightdm.conf.d

for conf in /etc/lightdm/lightdm.conf.d/*.conf; do
    [[ -f "${conf}" ]] || continue
    [[ "${conf}" == */50-mm-kiosk.conf ]] && continue
    [[ "${conf}" == *.disabled-by-mm-kiosk ]] && continue

    if grep -qE 'autologin-(user|session)|^user-session=' "${conf}" 2>/dev/null; then
        log "Conflicterende lightdm-config uitgeschakeld: ${conf}"
        mv "${conf}" "${conf}.disabled-by-mm-kiosk"
    fi
done

cat > /etc/lightdm/lightdm.conf.d/50-mm-kiosk.conf <<EOF
[Seat:*]
autologin-user=${KIOSK_USER}
autologin-session=openbox
user-session=openbox
autologin-user-timeout=0
EOF

"${SCRIPT_DIR}/mm-kiosk-configure-openbox-autostart.sh"

if [[ -f /usr/share/xsessions/openbox.desktop ]]; then
    log "Openbox-sessie gevonden."
else
    log "Waarschuwing: openbox.desktop ontbreekt in /usr/share/xsessions/."
fi

if [[ -d /etc/systemd/system/getty@tty1.service.d ]]; then
    for dropin in /etc/systemd/system/getty@tty1.service.d/*.conf; do
        if [[ -f "${dropin}" ]] && grep -q "autologin" "${dropin}"; then
            log "Console-autologin uitgeschakeld: ${dropin}"
            mv "${dropin}" "${dropin}.disabled-by-mm-kiosk"
        fi
    done
    systemctl daemon-reload
fi

echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
systemctl set-default graphical.target
systemctl enable lightdm.service

log "lightdm herstarten."
systemctl restart lightdm.service

for _ in $(seq 1 30); do
    if sudo -u "${KIOSK_USER}" DISPLAY=:0 xdpyinfo >/dev/null 2>&1; then
        log "X11 op :0 is beschikbaar voor ${KIOSK_USER}."
        systemctl restart mm-kiosk.service
        echo
        echo "Scherm hersteld. Chromium zou nu moeten starten."
        exit 0
    fi
    sleep 1
done

log "X11 start nog niet. lightdm-log:"
journalctl -u lightdm.service -n 20 --no-pager || true
echo
echo "Herstart het apparaat: sudo reboot"
exit 1
