#!/usr/bin/env bash
# Eén commando: sync naar /opt, scherm fixen en herstarten.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/.."

echo "==> MeldingsMonitor kiosk scherm toepassen"

if [[ "${SOURCE_DIR}" != /opt/meldingsmonitor-kiosk ]]; then
    bash "${SOURCE_DIR}/scripts/mm-kiosk-update.sh"
fi

bash "${SCRIPT_DIR}/mm-kiosk-fix-lightdm.sh"

echo
echo "Klaar. Herstart nu: sudo reboot"
