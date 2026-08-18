#!/usr/bin/env bash
# Main boot orchestrator: setup mode or kiosk mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
ensure_state_dir

if [[ ! -f "${MM_KIOSK_CONFIG}" ]]; then
    install -d "$(dirname "${MM_KIOSK_CONFIG}")"
    install -m 0644 "${SCRIPT_DIR}/../config/config.example.json" "${MM_KIOSK_CONFIG}"
    log "Standaardconfig aangemaakt op ${MM_KIOSK_CONFIG}."
fi

ONLINE=0
if "${SCRIPT_DIR}/mm-kiosk-network-check.sh"; then
    ONLINE=1
fi

NEEDS_SETUP=0
if ! python3 - <<PY
import json
import sys

sys.path.insert(0, "${SCRIPT_DIR}/../web")
from kiosk_config import is_setup_needed

with open("${MM_KIOSK_CONFIG}", encoding="utf-8") as handle:
    config = json.load(handle)

sys.exit(0 if is_setup_needed(config, online=bool(${ONLINE})) else 1)
PY
then
    NEEDS_SETUP=1
fi

if [[ "${NEEDS_SETUP}" -eq 1 ]]; then
    log "Setup-modus actief."

    if [[ "${ONLINE}" -eq 0 ]]; then
        "${SCRIPT_DIR}/mm-kiosk-setup-ap.sh" || log "Kon setup access point niet starten."
    fi

    "${SCRIPT_DIR}/mm-kiosk-start-provisioning.sh"
    "${SCRIPT_DIR}/mm-kiosk-power-settings.sh" || true
    exec "${SCRIPT_DIR}/mm-kiosk-start-setup-display.sh"
fi

log "Online; kiosk-modus starten."
"${SCRIPT_DIR}/mm-kiosk-start-provisioning.sh"
"${SCRIPT_DIR}/mm-kiosk-power-settings.sh" || true
exec "${SCRIPT_DIR}/mm-kiosk-start-kiosk.sh"
