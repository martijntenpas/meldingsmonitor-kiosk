#!/usr/bin/env bash
# Installs MeldingsMonitor station-screen kiosk tooling on Debian / Raspberry Pi OS.

set -euo pipefail

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Voer dit installatiescript uit als root (sudo)." >&2
        exit 1
    fi
}

require_root

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="/opt/meldingsmonitor-kiosk"
CONFIG_DIR="/etc/meldingsmonitor-kiosk"
KIOSK_USER="${MM_KIOSK_USER:-kiosk}"

echo "==> MeldingsMonitor kiosk installer"
echo "    Bron: ${SOURCE_DIR}"
echo "    Doel: ${TARGET_DIR}"

echo "==> Systeempakketten installeren"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    curl \
    dnsmasq \
    hostapd \
    network-manager \
    python3 \
    python3-pip \
    python3-venv \
    xorg \
    openbox \
    lightdm \
    unclutter \
    x11-xserver-utils

if grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
    apt-get install -y chromium-browser || apt-get install -y chromium
else
    apt-get install -y chromium || apt-get install -y chromium-browser
fi

systemctl disable --now hostapd.service 2>/dev/null || true
systemctl disable --now dnsmasq.service 2>/dev/null || true
systemctl enable NetworkManager.service

if ! id "${KIOSK_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${KIOSK_USER}"
fi

usermod -aG video,render,input "${KIOSK_USER}" || true

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

mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-mm-kiosk.conf <<EOF
[Seat:*]
autologin-user=${KIOSK_USER}
autologin-session=openbox
EOF

cat > /etc/xdg/openbox/autostart <<EOF
#!/bin/sh
# mm-kiosk power settings
xset s off
xset s noblank
xset -dpms
xset dpms 0 0 0
unclutter -idle 0 &
EOF
chmod 0755 /etc/xdg/openbox/autostart

install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk.service" /etc/systemd/system/mm-kiosk.service
install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk-web.service" /etc/systemd/system/mm-kiosk-web.service

mkdir -p /etc/systemd/system/mm-kiosk.service.d
cat > /etc/systemd/system/mm-kiosk.service.d/override.conf <<EOF
[Service]
Environment=MM_KIOSK_USER=${KIOSK_USER}
Environment=MM_KIOSK_CONFIG=${CONFIG_DIR}/config.json
Environment=MM_KIOSK_SCRIPTS=${TARGET_DIR}/scripts
ExecStart=
ExecStart=${TARGET_DIR}/scripts/mm-kiosk-boot.sh
EOF

systemctl daemon-reload
systemctl enable mm-kiosk-web.service
systemctl enable mm-kiosk.service
systemctl enable lightdm.service 2>/dev/null || true
systemctl set-default graphical.target 2>/dev/null || true

"${TARGET_DIR}/scripts/mm-kiosk-power-settings.sh"

echo
echo "Installatie afgerond."
echo
echo "Volgende stappen:"
echo "  1. Herstart het apparaat: sudo reboot"
echo "  2. Geen internet? Verbind met WiFi-netwerk MeldingsMonitor-Setup-XXXX"
echo "  3. Open http://192.168.4.1 in je browser"
echo "  4. Koppel WiFi en plak de kazernescherm-link"
echo
echo "Setup opnieuw openen:"
echo "  sudo sed -i 's/\"force_setup\": false/\"force_setup\": true/' ${CONFIG_DIR}/config.json"
echo "  sudo systemctl restart mm-kiosk"
