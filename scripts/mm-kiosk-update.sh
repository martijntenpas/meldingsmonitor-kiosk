#!/usr/bin/env bash
# Updates an installed kiosk from the current checkout (run after git pull).

set -euo pipefail

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Voer dit update-script uit als root (sudo)." >&2
        exit 1
    fi
}

require_root

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="/opt/meldingsmonitor-kiosk"

echo "==> MeldingsMonitor kiosk update"
echo "    Bron: ${SOURCE_DIR}"
echo "    Doel: ${TARGET_DIR}"

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "Installatie niet gevonden op ${TARGET_DIR}. Voer eerst scripts/install.sh uit." >&2
    exit 1
fi

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

install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk-web.service" /etc/systemd/system/mm-kiosk-web.service
install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk.service" /etc/systemd/system/mm-kiosk.service

find "${TARGET_DIR}/scripts" -type f -name '*.sh' -exec chmod 0755 {} +

if [[ -x "${TARGET_DIR}/web/.venv/bin/pip" ]]; then
    "${TARGET_DIR}/web/.venv/bin/pip" install -r "${TARGET_DIR}/web/requirements.txt"
fi

systemctl daemon-reload
systemctl enable mm-kiosk-web.service >/dev/null 2>&1 || true
systemctl restart mm-kiosk-web.service
sleep 2
systemctl restart mm-kiosk.service

echo
echo "Update afgerond. De instellingenpagina is opnieuw gestart."
