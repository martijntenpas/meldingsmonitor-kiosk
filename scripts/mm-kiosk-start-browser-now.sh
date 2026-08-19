#!/usr/bin/env bash
# Start het kazernescherm handmatig (test na installatie of fix).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTOSTART="${SCRIPT_DIR}/mm-kiosk-autostart.sh"

if [[ ! -x "${AUTOSTART}" ]]; then
    echo "Autostart-script niet gevonden: ${AUTOSTART}" >&2
    exit 1
fi

echo "Browser starten via ${AUTOSTART} ..."
exec "${AUTOSTART}"
