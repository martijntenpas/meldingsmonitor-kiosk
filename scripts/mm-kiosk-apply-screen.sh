#!/usr/bin/env bash
# Eén commando: sync naar /opt, sessie opnieuw configureren en herstarten.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/.."
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root

echo "==> MeldingsMonitor kiosk opstart toepassen"

if [[ "${SOURCE_DIR}" != /opt/meldingsmonitor-kiosk ]]; then
    bash "${SOURCE_DIR}/scripts/mm-kiosk-update.sh"
fi

PRIMARY_USER="$(detect_primary_user || cat /etc/meldingsmonitor-kiosk/primary-user 2>/dev/null || true)"
bash "${SCRIPT_DIR}/mm-kiosk-setup-user-session.sh" "${PRIMARY_USER:-}"

systemctl restart mm-kiosk-web.service 2>/dev/null || true

echo
echo "Klaar. Herstart nu: sudo reboot"
