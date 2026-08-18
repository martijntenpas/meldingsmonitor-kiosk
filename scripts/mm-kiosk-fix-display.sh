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

"${SCRIPT_DIR}/mm-kiosk-fix-lightdm.sh"

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

log "lightdm is geconfigureerd via mm-kiosk-fix-lightdm.sh."
systemctl restart mm-kiosk.service 2>/dev/null || true

echo
echo "Scherm hersteld. Herstart aanbevolen: sudo reboot"
