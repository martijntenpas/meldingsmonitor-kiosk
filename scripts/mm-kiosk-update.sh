#!/usr/bin/env bash
# Updates an installed kiosk from the current checkout (run after git pull).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
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
    "${SOURCE_DIR}/assets/" "${TARGET_DIR}/assets/"
rsync -a --delete \
    "${SOURCE_DIR}/scripts/" "${TARGET_DIR}/scripts/"
rsync -a --delete \
    --exclude '.venv' \
    "${SOURCE_DIR}/web/" "${TARGET_DIR}/web/"
rsync -a \
    "${SOURCE_DIR}/systemd/" "${TARGET_DIR}/systemd/"

install -m 0644 "${TARGET_DIR}/systemd/mm-kiosk-web.service" /etc/systemd/system/mm-kiosk-web.service

find "${TARGET_DIR}/scripts" -type f -name '*.sh' -exec chmod 0755 {} +

if [[ -x "${TARGET_DIR}/web/.venv/bin/pip" ]]; then
    "${TARGET_DIR}/web/.venv/bin/pip" install -r "${TARGET_DIR}/web/requirements.txt"
fi

PRIMARY_USER="$(cat /etc/meldingsmonitor-kiosk/primary-user 2>/dev/null || detect_primary_user || true)"
if [[ -n "${PRIMARY_USER}" ]]; then
    "${TARGET_DIR}/scripts/mm-kiosk-setup-user-session.sh" "${PRIMARY_USER}"
    "${TARGET_DIR}/scripts/mm-kiosk-set-wallpaper.sh" "${PRIMARY_USER}"
fi

systemctl daemon-reload
systemctl enable mm-kiosk-web.service >/dev/null 2>&1 || true
systemctl restart mm-kiosk-web.service

systemctl disable mm-kiosk.service 2>/dev/null || true
systemctl stop mm-kiosk.service 2>/dev/null || true

echo
echo "Update afgerond. Herstart aanbevolen: sudo reboot"
