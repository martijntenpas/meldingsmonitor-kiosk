#!/usr/bin/env bash
# Installs MeldingsMonitor station-screen kiosk tooling on Debian / Raspberry Pi OS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="/opt/meldingsmonitor-kiosk"
CONFIG_DIR="/etc/meldingsmonitor-kiosk"
PRIMARY_USER="$(detect_primary_user || true)"

if [[ -z "${PRIMARY_USER}" ]]; then
    echo "Geen gebruikersaccount gevonden. Maak eerst een gebruiker aan in Raspberry Pi Imager." >&2
    exit 1
fi

echo "==> MeldingsMonitor kiosk installer"
echo "    Bron: ${SOURCE_DIR}"
echo "    Doel: ${TARGET_DIR}"
echo "    Scherm-gebruiker: ${PRIMARY_USER}"

echo "==> Systeempakketten installeren"
export DEBIAN_FRONTEND=noninteractive
apt-get update

BASE_PACKAGES=(
    curl
    dnsmasq
    hostapd
    network-manager
    python3
    python3-pip
    python3-venv
    unclutter
)

apt-get install -y "${BASE_PACKAGES[@]}"

if is_pi_desktop; then
    echo "==> Raspberry Pi OS Desktop gedetecteerd: bestaande desktop blijft actief"
else
    echo "==> Lite/headless gedetecteerd: minimale grafische omgeving installeren"
    apt-get install -y xserver-xorg x11-xserver-utils openbox lightdm
    systemctl enable lightdm.service 2>/dev/null || true
    systemctl set-default graphical.target 2>/dev/null || true

    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/zz-mm-kiosk.conf <<EOF
[Seat:*]
autologin-user=${PRIMARY_USER}
autologin-session=openbox
user-session=openbox
autologin-user-timeout=0
EOF

    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager

    mkdir -p /etc/xdg/openbox
    cat > /etc/xdg/openbox/autostart <<'EOF'
#!/bin/sh
xset s off
xset s noblank
xset -dpms
xset dpms 0 0 0
unclutter -idle 0 &
EOF
    chmod 0755 /etc/xdg/openbox/autostart
fi

if grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
    apt-get install -y chromium-browser 2>/dev/null || apt-get install -y chromium
else
    apt-get install -y chromium 2>/dev/null || apt-get install -y chromium-browser
fi

systemctl disable --now hostapd.service 2>/dev/null || true
systemctl disable --now dnsmasq.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true

usermod -aG video,render,input,tty "${PRIMARY_USER}" 2>/dev/null || true

echo "==> Bestanden kopiëren"
install -d "${TARGET_DIR}"
rsync -a --delete \
    --exclude '.venv' \
    "${SOURCE_DIR}/config/" "${TARGET_DIR}/config/"
rsync -a --delete \
    "${SOURCE_DIR}/scripts/" "${TARGET_DIR}/scripts/"
rsync -a --delete \
    --exclude '.venv' \
    "${SOURCE_DIR}/web/" "${TARGET_DIR}/web/"
rsync -a \
    "${SOURCE_DIR}/systemd/" "${TARGET_DIR}/systemd/"

find "${TARGET_DIR}/scripts" -type f -name '*.sh' -exec chmod 0755 {} +

if [[ ! -f "${CONFIG_DIR}/config.json" ]]; then
    install -d "${CONFIG_DIR}"
    install -m 0644 "${TARGET_DIR}/config/config.example.json" "${CONFIG_DIR}/config.json"
fi

echo "==> Python dependencies installeren"
python3 -m venv "${TARGET_DIR}/web/.venv"
"${TARGET_DIR}/web/.venv/bin/pip" install --upgrade pip
"${TARGET_DIR}/web/.venv/bin/pip" install -r "${TARGET_DIR}/web/requirements.txt"

cat > /usr/local/bin/mm-kiosk-provision <<EOF
#!/usr/bin/env bash
exec ${TARGET_DIR}/web/.venv/bin/python ${TARGET_DIR}/web/app.py "\$@"
EOF
chmod 0755 /usr/local/bin/mm-kiosk-provision

echo "==> Opstartsequence voor ${PRIMARY_USER}"
"${TARGET_DIR}/scripts/mm-kiosk-setup-user-session.sh" "${PRIMARY_USER}"

install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk-web.service" /etc/systemd/system/mm-kiosk-web.service

systemctl daemon-reload
systemctl enable mm-kiosk-web.service
systemctl restart mm-kiosk-web.service

"${TARGET_DIR}/scripts/mm-kiosk-power-settings.sh" || true

echo
echo "Installatie afgerond."
echo
echo "Volgende stappen:"
echo "  1. Herstart: sudo reboot"
echo "  2. HDMI toont daarna setup-QR of kazernescherm (via gebruiker ${PRIMARY_USER})"
echo "  3. Instellen via http://$(hostname -I | awk '{print $1}') of:"
echo "     sudo bash ${TARGET_DIR}/scripts/mm-kiosk-set-homepage.sh \"JOUW_URL\" complete"
echo
